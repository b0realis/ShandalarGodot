extends RefCounted
## Weatherlight (_creatures, Pack 8). Creatures with activated, static or characteristic-defining abilities.
##
## Every listed name implements its whole Oracle text with typed effects
## where one exists (the fair AI reads them — engine/ai/effect_intent.gd);
## tests/cards/test_pack_8_b9_creatures.gd pins each card's distinguishing
## clause.
const F := preload("res://cards/sets/fem/_rules.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Benalish Knight":
			# Flash (CR 702.8a); the scaffold already prints first strike.
			c.with_keywords([Mtg.Keyword.FLASH])
		"Avizoa":
			# "You" is the ability's controller; the skip is spent on the
			# first untap step that would happen (CR 614.10).
			c.activated(ActivatedAbility.new("{0}", false, [PumpEffect.new(2, 2).self_buff(),
				F.Action.new(_skip_untap, "you skip your next untap step")],
				"{0}: This creature gets +2/+2 until end of turn. You skip your next untap step. Activate only once each turn.").per_turn(1))
		"Benalish Missionary":
			# CR 509.1h: "blocked" lasts the rest of combat even if every
			# blocker is gone, so the filter asks the combat's blocked set.
			var spec := TargetSpec.creature("target blocked creature").with_game_filter(_blocked)
			c.activated(F._ability("{1}{W}", true, PreventCombatDamageEffect.new().by_target_creature(spec)))
		"Heavy Ballista":
			var shot := DamageEffect.new(2).target_creature("target attacking or blocking creature")
			shot.target_spec.with_game_filter(_in_combat)
			c.activated(F._ability("", true, shot))
		"Master of Arms":
			# "Blocking this creature" — a creature blocking one member of a
			# band blocks the whole band (CR 702.22j), which is the question
			# Combat.opposing_attackers answers.
			var spec := TargetSpec.creature("target creature blocking this creature").with_source_filter(_blocking_source)
			c.activated(F._ability("{1}{W}", false, TapEffect.new(spec)))
		"Soul Shepherd":
			c.activated(F._ability("{W}", false, GainLifeEffect.new(1)).with_exile_from_graveyard("creature card", F._creature))
		"Southern Paladin":
			c.activated(F._ability("{W}{W}", true, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target red permanent", _red))))
		"Mischievous Poltergeist":
			# The life is a COST (CR 118.3, 119.4): paid on activation.
			c.activated(ActivatedAbility.new("", false, [RegenerateEffect.new()],
				"Pay 1 life: Regenerate this creature.").with_life_cost(1))
		"Dwarven Thaumaturgist":
			c.activated(F._ability("", true, SwitchPowerToughnessEffect.new(TargetSpec.creature())))
		"Maraxus of Keld":
			# CR 604.3: a characteristic-defining ability works in every zone;
			# its battlefield half is a layer-7a static like any other.
			c.static_ability(StaticAbility.new(_maraxus, "Power and toughness equal to the number of untapped artifacts, creatures, and lands you control.").setting_base_pt())
			c.characteristic_definition = _maraxus
		"Orcish Settlers":
			# {X}{X}{R}: ManaCost counts both X pips (x_count), so X = 2
			# costs {4}{R}; X = 0 is legal and names no target.
			var raze := DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", F._land)).x_targets()
			c.activated(F._ability("{X}{X}{R}", true, raze).with_sacrifice_cost())
		"Fungus Elemental":
			c.as_it_enters(_stamp_entry)
			var grow := F._ability("{G}", false, SelfCounter.new("+2/+2")).with_sacrifice_of("Forest", F._subtype.bind("forest")).only_if(_entered_this_turn)
			grow.text = "{G}, Sacrifice a Forest: Put a +2/+2 counter on this creature. Activate only if this creature entered this turn."
			c.activated(grow)
		"Llanowar Behemoth":
			# "Tap an untapped creature you control" is not {T}: it may tap
			# the Behemoth itself, and summoning sickness does not apply
			# (CR 302.6 restricts only {T}/{Q} costs).
			var surge := F._ability("", false, PumpEffect.new(1, 1).self_buff())
			surge.tap_permanent_filter = F._creature
			surge.tap_permanent_count = 1
			surge.text = "Tap an untapped creature you control: This creature gets +1/+1 until end of turn."
			c.activated(surge)
		"Llanowar Druid":
			c.activated(F._ability("", true, F.Action.new(_untap_forests, "untap all Forests", null, true)).with_sacrifice_cost())
		"Serrated Biskelion":
			var both := ActivatedAbility.new("", true, [SelfCounter.new("-1/-1"), CounterMarkerEffect.new("-1/-1")],
				"{T}: Put a -1/-1 counter on this creature and a -1/-1 counter on target creature.")
			c.activated(both)
		"Steel Golem":
			c.bans_playing(_golem_ban)
		_: return false
	return true


## "Put a <kind> counter on THIS creature" — untargeted, so it never needs
## a target slot; it lands only on the same object that paid the cost
## (CR 400.7: a permanent that left and returned is a new object).
class SelfCounter extends CounterMarkerEffect:
	func _init(counter_kind: String, number := 1) -> void:
		super(counter_kind, number)
		target_spec = null
	func resolve(game: MtgGame, source: CardInstance, _controller: int, _target: TargetRef, _x := 0) -> void:
		if source.zone == Mtg.Zone.BATTLEFIELD and source.layer_timestamp == int(game.cost_paid("_source_timestamp", source.layer_timestamp)):
			game.add_counters(source, kind, count)
	func describe() -> String:
		return "put %d %s counter(s) on this creature" % [count, kind]


static func _skip_untap(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.skip_next_untap_step(pid)

static func _blocked(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) and g.combat.blocked_attackers.has(i.id)

static func _in_combat(g: MtgGame, i: CardInstance) -> bool:
	return g.combat.attackers.has(i.id) or g.combat.blocks.has(i.id)

static func _blocking_source(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
	return s != null and g.combat.opposing_attackers(i.id).has(s.id)

static func _red(i: CardInstance) -> bool:
	return (i.cur_colors & Mtg.ManaColor.R) != 0

## Each untapped permanent counts once, whichever of the three types it has.
static func _maraxus(g: MtgGame, s: CardInstance) -> void:
	var me := g.players[s.controller_id if s.zone in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.STACK] else s.owner_id]
	var count := 0
	for i in me.battlefield:
		if not i.tapped and (i.cur_types & (Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE | Mtg.CardType.LAND)) != 0:
			count += 1
	s.cur_power = count
	s.cur_toughness = count

static func _stamp_entry(g: MtgGame, s: CardInstance, _pid: int) -> void:
	g._rec(s, &"memory")
	s.memory["entered_turn"] = g.turn_number

static func _entered_this_turn(g: MtgGame, s: CardInstance) -> String:
	return "" if int(s.memory.get("entered_turn", -1)) == g.turn_number else "activate only if this creature entered this turn"

## Every Forest on the battlefield, whoever controls it.
static func _untap_forests(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	for i in g.all_battlefield():
		if i.is_land() and i.has_subtype("forest") and i.tapped: g.untap_permanent(i)

## "You can't cast creature spells": the ban is radiated by every Golem on
## the battlefield, and each one stops only ITS controller — asked live, so
## a stolen Golem stops its new controller. A Golem whose abilities are
## silenced bans nothing.
static func _golem_ban(g: MtgGame, pid: int, data: CardData) -> bool:
	if not data.is_creature(): return false
	for i in g.players[pid].battlefield:
		if i.data.play_ban.is_valid() and i.data.play_ban.get_method() == &"_golem_ban" and not i.cur_abilities_silenced: return true
	return false
