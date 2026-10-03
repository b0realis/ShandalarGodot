extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const SNOW := preload("res://cards/sets/ice/_snow.gd")
const SPELLS := preload("res://cards/sets/ice/_spells.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Blinking Spirit", "Foul Familiar":
			var a := F._ability("" if c.card_name == "Blinking Spirit" else "{B}", false, SelfBounce.new())
			if c.card_name == "Foul Familiar":
				a.with_life_cost(1)
				c.static_ability(StaticAbility.new(_cant_block, "This creature can't block."))
			c.activated(a)
		"Abyssal Specter":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DAMAGE_DEALT, _specter, "Damaged player discards a card.", _hit_player))
		"Brine Shaman":
			c.activated(F._ability("", true, PumpEffect.new(2, 2)).with_sacrifice_of("creature", _creature).may_sacrifice_itself())
			c.activated(F._ability("{1}{U}{U}", false, CounterEffect.new("target creature spell", _creature)).with_sacrifice_of("creature", _creature).may_sacrifice_itself())
		"Brown Ouphe":
			c.activated(F._ability("{1}{G}", true, CounterAbilityEffect.new("target artifact activated ability", CounterAbilityEffect.from_an_artifact)))
		"Soldevi Machinist": c.mana(ManaAbility.new(Mtg.ManaColor.C, 2).with_restriction("artifact_ability"))
		"Kjeldoran Dead":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _dead, "Sacrifice a creature.", F._self_enter))
			c.activated(F._ability("{B}", false, RegenerateEffect.new()))
		"Skeleton Ship":
			c.with_sacrifice_if_no_land("island")
			c.activated(F._ability("", true, CounterMarkerEffect.new("-1/-1")))
		"Gorilla Pack": c.with_attack_needs_defender_land("forest").with_sacrifice_if_no_land("forest")
		"Minion of Tevesh Szat":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _tevesh, "Pay {B}{B} or take 2 damage.", F._your_upkeep))
			c.activated(F._ability("", true, PumpEffect.new(3, -2)))
		"Mistfolk":
			var counter := CounterEffect.new("target spell targeting this creature")
			counter.target_spec.with_source_filter(_targets_source)
			c.activated(F._ability("{U}", false, counter))
		"Tinder Wall":
			c.mana(ManaAbility.new(Mtg.ManaColor.R, 2).without_tap().with_sacrifice())
			var ping := DamageEffect.new(2).target_creature("target creature this is blocking")
			ping.target_spec.with_source_filter(_blocking_it)
			c.activated(F._ability("{R}", false, ping).with_sacrifice_cost())
		"Snow Hound":
			c.activated(F._ability("{1}", true, SnowHound.new()))
		"Goblin Snowman":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _snowman, "Prevent combat damage to and from this creature this turn.", _source_blocks))
			var ping := DamageEffect.new(1).target_creature("target creature this is blocking")
			ping.target_spec.with_source_filter(_blocking_it)
			c.activated(F._ability("", true, ping))
		"Goblin Mutant":
			c.with_cant_block_power_ge(3)
			c.static_ability(StaticAbility.new(_mutant, "Can't attack into an untapped creature with power 3 or greater.").reading_pt())
		"Flow of Maggots", "Stone Spirit":
			c.static_ability(StaticAbility.new(_evasion.bind(c.card_name), "Restricted blockers."))
		"Grizzled Wolverine":
			c.activated(F._ability("{R}", false, PumpEffect.new(2, 0).self_buff()).per_turn(1).during_step(Mtg.Step.DECLARE_BLOCKERS).only_if(_is_blocked))
		"Lhurgoyf", "Pestilence Rats", "Lost Order of Jarkeld":
			if c.card_name == "Lost Order of Jarkeld": c.as_it_enters(_choose_opponent)
			c.static_ability(StaticAbility.new(_variable_stats.bind(c.card_name), "Variable power and toughness.").setting_base_pt())
		"Dire Wolves":
			c.static_ability(StaticAbility.new(_wolves, "Banding while you control a Plains.").changing_abilities())
		"Aurochs":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _aurochs, "+1/+0 for each other attacking Aurochs.", F._self_attack))
		"Chub Toad":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _chub, "+2/+2 when this blocks or becomes blocked.", _first_block))
		"Woolly Spider":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _spider, "+0/+2 when this blocks a flyer.", _blocks_flyer))
		"Sibilant Spirit":
			c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _sibilant, "Defending player may draw a card.", F._self_attack))
		"Balduvian Hydra":
			c.as_it_enters(_hydra_enter)
			c.activated(F._ability("", false, PreventDamageEffect.new(1).to_source()).with_counter_cost("+1/+0"))
			c.activated(F._ability("{R}{R}{R}", false, F.Action.new(_hydra_grow, "put a +1/+0 counter on this creature")).during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Walking Wall":
			c.activated(ActivatedAbility.new("{3}", false, [PumpEffect.new(3, -1).self_buff(),
				F.Action.new(_walk, "this creature can attack as though it didn't have defender")], "{3}: +3/-1 and may attack this turn.").per_turn(1))
		"Orcish Healer":
			c.activated(F._ability("{R}{R}", true, F.Action.new(SPELLS._ban_regeneration, "target creature can't regenerate this turn", TargetSpec.creature())))
			for cost in ["{B}{B}{R}", "{R}{G}{G}"]:
				var regen := RegenerateEffect.new().target_creature()
				regen.target_spec = TargetSpec.creature("target black or green creature", _black_green)
				c.activated(F._ability(cost, true, regen))
		"Elvish Healer": c.activated(F._ability("", true, Healer.new()))
		"Freyalise Supplicant":
			c.activated(F._ability("", true, Supplicant.new()).with_sacrifice_of("red or white creature", _red_white_creature).may_sacrifice_itself())
		"Karplusan Yeti": c.activated(F._ability("", true, Fight.new()))
		"Elder Druid":
			c.activated(F._ability("{3}{G}", true, F.Action.new(_elder, "you may tap or untap target artifact, creature, or land", TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact, creature, or land", _acl))))
		"Giant Trap Door Spider":
			c.activated(F._ability("{1}{R}{G}", true, TrapDoor.new()))
		"Johtull Wurm":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKERS_DECLARED, _johtull, "-2/-1 for each blocker beyond the first.", _wurm_blocked))
		_: return false
	return true

static func same_activation(g: MtgGame, s: CardInstance) -> bool:
	return s != null and s.zone == Mtg.Zone.BATTLEFIELD and s.layer_timestamp == int(g.cost_paid("_source_timestamp", s.layer_timestamp))
static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _black_green(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.B | Mtg.ManaColor.G)) != 0
static func _red_white_creature(i: CardInstance) -> bool: return i.is_creature() and (i.cur_colors & (Mtg.ManaColor.R | Mtg.ManaColor.W)) != 0
static func _acl(i: CardInstance) -> bool: return i.is_creature() or i.is_land() or i.is_type(Mtg.CardType.ARTIFACT)
static func _cant_block(_g: MtgGame, s: CardInstance) -> void: s.cur_cant_block_filter = func(_i: CardInstance) -> bool: return true
static func _hit_player(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.get("source") == s and e.data.has("to_player")
static func _specter(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.to_player)
	g.discard_cards(who, g.agents[who].choose_discard(g, who, mini(1, g.players[who].hand.size())))
static func _dead(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).controller)
	var choices: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature(): choices.append(i)
	if choices.is_empty(): return
	var chosen := g.agents[who].choose_card(g, who, choices, "Kjeldoran Dead: sacrifice a creature", false, true)
	if chosen != null and choices.has(chosen): g.sacrifice_permanent(chosen)
static func _tevesh(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).controller)
	if not EffectBase.unless_paid(g, who, ManaCost.parse("{B}{B}"), "Pay {B}{B} to prevent Minion of Tevesh Szat's 2 damage?"):
		g.deal_damage(s, TargetRef.player(who), 2)
static func _targets_source(g: MtgGame, s: CardInstance, spell: CardInstance) -> bool:
	var item := g.find_stack_item(spell)
	if item == null: return false
	for ref in item.targets:
		if not ref.is_player and ref.instance_id == s.id: return true
	return false
# BANDING (2026-10-03): a creature blocking one member of a band blocks every
# member (CR 702.22h), so "it's blocking" / "blocking it" read the whole band
# — opposing_attackers() on the blocking side, blockers_of_band(band_of())
# on the attacking side — not just the attacker the block was declared on.
static func _blocking_it(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return g.combat.opposing_attackers(s.id).has(i.id)
static func _band_blockers(g: MtgGame, s: CardInstance) -> Array[int]: return g.combat.blockers_of_band(g.combat.band_of(s.id))
## "Whenever this creature blocks": once per block, though a blocker of a
## band hears a BLOCKED event per member — only the first answers (bug pass
## 2026-10-03, the guard [method _first_block] keeps for Chub Toad).
static func _source_blocks(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	if e.data.get("blocker") != s:
		return false
	var blocked := g.combat.attackers_blocked_by(s.id)
	return blocked.is_empty() or blocked.front() == e.data.attacker.id
static func _snowman(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_combat_prevention(s.id, true, true)
		g.recalculate()
static func _mutant(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[1 - s.controller_id].battlefield:
		if i.is_creature() and not i.tapped and i.cur_power >= 3: s.cur_cant_attack = true
static func _evasion(_g: MtgGame, s: CardInstance, name: String) -> void:
	var allowed := func(blocker: CardInstance) -> bool:
		return blocker.has_subtype("wall") if name == "Flow of Maggots" else not blocker.has_keyword(Mtg.Keyword.FLYING)
	s.cur_block_restrictions.append({"desc": name, "filter": allowed})
static func _is_blocked(g: MtgGame, s: CardInstance) -> String:
	return "" if not _band_blockers(g, s).is_empty() else "This creature must be blocked"
static func _choose_opponent(g: MtgGame, s: CardInstance, pid: int) -> void: s.memory["opponent"] = g.opponent_of(pid)
static func _variable_stats(g: MtgGame, s: CardInstance, name: String) -> void:
	var count := 0
	match name:
		"Lhurgoyf":
			for p in g.players:
				for i in p.graveyard:
					if i.is_creature(): count += 1
			s.cur_toughness = count + 1
		"Pestilence Rats":
			for i in g.all_battlefield():
				if i != s and i.has_subtype("rat"): count += 1
		"Lost Order of Jarkeld":
			count = 1
			for i in g.players[int(s.memory.get("opponent", 1 - s.controller_id))].battlefield:
				if i.is_creature(): count += 1
			s.cur_toughness = count
	s.cur_power = count
static func _wolves(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_land() and i.has_subtype("plains"):
			if not s.cur_keywords.has(Mtg.Keyword.BANDING): s.cur_keywords.append(Mtg.Keyword.BANDING)
			return
static func _aurochs(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var n := 0
	for id in g.combat.attackers:
		var i := g.find_instance(id)
		if i != null and i != s and i.has_subtype("aurochs"): n += 1
	g.continuous.add_until_eot_pump(s.id, n, 0)
	g.recalculate()
static func _first_block(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	# One trigger per block: the attacker hears a BLOCKED event per blocker of
	# its band, the blocker one per band member it blocks — each answers only
	# the first.
	if e.data.get("attacker") == s:
		var blockers := _band_blockers(g, s)
		return not blockers.is_empty() and blockers.front() == e.data.blocker.id
	if e.data.get("blocker") == s:
		return g.combat.attackers_blocked_by(s.id).front() == e.data.attacker.id
	return false
static func _chub(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_pump(s.id, 2, 2)
		g.recalculate()
static func _blocks_flyer(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("blocker") == s and e.data.attacker.has_keyword(Mtg.Keyword.FLYING)
static func _spider(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		g.continuous.add_until_eot_pump(s.id, 0, 2)
		g.recalculate()
static func _sibilant(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := 1 - int(g.trigger_context(s).controller)
	if g.agents[who].choose_yes_no(g, who, "Sibilant Spirit: draw a card?", not g.players[who].library.is_empty()): g.draw_cards(who, 1)
static func _hydra_enter(g: MtgGame, s: CardInstance, _pid: int) -> void: g.add_counters(s, "+1/+0", int(s.memory.get("x_value", 0)))
static func _hydra_grow(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if same_activation(g, s): g.add_counters(s, "+1/+0")
static func _walk(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if same_activation(g, s):
		g.continuous.add_floating_static(s, StaticAbility.new(_can_walk.bind(s.id), "Can attack with defender."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
		g.recalculate()
static func _can_walk(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: i.cur_can_attack_with_defender = true
static func _elder(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null: return
	var option := g.agents[pid].choose_option(g, pid, ["Tap", "Untap", "Leave unchanged"], "Elder Druid", 1 if i.controller_id == pid else 0)
	if option == 0: g.tap_permanent(i)
	elif option == 1: g.untap_permanent(i)
static func _wurm_blocked(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool: return not _band_blockers(g, s).is_empty()
static func _johtull(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s):
		var count := maxi(0, _band_blockers(g, s).size() - 1)
		g.continuous.add_until_eot_pump(s.id, -2 * count, -count)
		g.recalculate()

class SelfBounce extends ReturnToHandEffect:
	func _init() -> void: target_spec = null
	func resolve(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x := 0) -> void:
		if load("res://cards/sets/ice/_creatures.gd").same_activation(g, s): g.return_to_hand(s)
	func describe() -> String: return "return this creature to its owner's hand"

class SnowHound extends ReturnToHandEffect:
	func _init() -> void:
		super(TargetSpec.creature("target green or blue creature you control", func(i: CardInstance) -> bool: return (i.cur_colors & (Mtg.ManaColor.G | Mtg.ManaColor.U)) != 0).with_source_filter(F._own))
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		g.begin_simultaneous()
		if load("res://cards/sets/ice/_creatures.gd").same_activation(g, s): g.return_to_hand(s)
		super(g, s, pid, t, x)
		g.end_simultaneous()

class Healer extends PreventDamageEffect:
	func _init() -> void:
		super(1)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var i := null if t.is_player else g.find_instance(t.instance_id)
		var count := 2 if i != null and i.is_creature() and (i.cur_colors & Mtg.ManaColor.G) != 0 else 1
		PreventDamageEffect.new(count).any_target().resolve(g, s, pid, t)

class Supplicant extends DamageEffect:
	func _init() -> void:
		super(0)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.deal_damage(s, t, maxi(0, int(g.cost_paid("_sacrificed_power"))) / 2)

class Fight extends DamageEffect:
	func _init() -> void:
		super(0)
		target_creature()
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		var i := g.find_instance(t.instance_id)
		if i == null: return
		var active: bool = load("res://cards/sets/ice/_creatures.gd").same_activation(g, s)
		var power := s.cur_power if active else s.last_power
		var return_power := i.cur_power
		g.begin_simultaneous()
		g.deal_damage(s, t, maxi(0, power))
		if active: g.deal_damage(i, TargetRef.card(s), maxi(0, return_power))
		g.end_simultaneous()

class TrapDoor extends ExileEffect:
	func _init() -> void:
		super(TargetSpec.creature("target nonflying creature attacking you").with_source_filter(_victim))
	static func _victim(g: MtgGame, s: CardInstance, i: CardInstance) -> bool:
		return not i.has_keyword(Mtg.Keyword.FLYING) and i.controller_id != s.controller_id and g.combat.attackers.has(i.id)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		g.begin_simultaneous()
		if load("res://cards/sets/ice/_creatures.gd").same_activation(g, s): g.exile_permanent(s)
		super(g, s, pid, t, x)
		g.end_simultaneous()
