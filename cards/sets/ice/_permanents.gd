extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const SNOW := preload("res://cards/sets/ice/_snow.gd")
const CREATURES := preload("res://cards/sets/ice/_creatures.gd")
const TALISMANS := {"Hematite Talisman": Mtg.ManaColor.R, "Lapis Lazuli Talisman": Mtg.ManaColor.U,
	"Malachite Talisman": Mtg.ManaColor.G, "Nacre Talisman": Mtg.ManaColor.W, "Onyx Talisman": Mtg.ManaColor.B}

static func configure(c: CardData) -> bool:
	if TALISMANS.has(c.card_name):
		c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _talisman, "You may pay {3} to untap target permanent.",
			_colored_spell.bind(int(TALISMANS[c.card_name]))).targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent")))
		return true
	match c.card_name:
		"Arenson's Aura":
			c.activated(F._ability("{W}", false, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target enchantment", _enchantment))).with_sacrifice_of("enchantment", _enchantment).may_sacrifice_itself())
			c.activated(F._ability("{3}{U}{U}", false, CounterEffect.new("target enchantment spell", _enchantment)))
		"Arcum's Sleigh":
			c.activated(F._ability("{2}", true, PumpEffect.new(0, 0, [Mtg.Keyword.VIGILANCE])).combat_only().only_if(_defending_snow))
		"Despotic Scepter":
			c.activated(F._ability("", true, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent you own").with_source_filter(_owned), false)))
		"Pit Trap":
			c.activated(F._ability("{2}", true, DestroyEffect.new(TargetSpec.creature("target attacking creature without flying", _ground).with_game_filter(_attacker), false)).with_sacrifice_cost())
		"Runed Arch":
			c.with_enters_tapped()
			var pump := PumpEffect.new(0, 0, [Mtg.Keyword.UNBLOCKABLE])
			pump.target_spec = TargetSpec.creature("target creature with power 2 or less", _small)
			pump.x_targets()
			c.activated(F._ability("{X}", true, pump).with_sacrifice_cost())
		"Infinite Hourglass":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._counter_upkeep.bind("time"), "Put a time counter on this artifact.", F._your_upkeep))
			c.static_ability(StaticAbility.new(_hourglass, "All creatures get +1/+0 for each time counter."))
			c.activated(F._ability("{3}", false, F.Action.new(_remove_time, "remove a time counter from this artifact")).anyone_activated().during_step(Mtg.Step.UPKEEP))
		"Vibrating Sphere": c.static_ability(StaticAbility.new(_sphere, "Your creatures get +2/+0 during your turn or -0/-2 otherwise."))
		"Illusions of Grandeur":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _grandeur.bind(20), "Gain 20 life.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _grandeur.bind(-20), "Lose 20 life.", F._self_enter))
		"Thoughtleech":
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _leech, "You may gain 1 life.", _enemy_island))
		"Mystic Remora":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _remora, "Draw a card unless the caster pays {4}.", _enemy_noncreature))
		"Soul Barrier":
			c.triggered(TriggeredAbility.new(Mtg.EventType.SPELL_CAST, _barrier, "Deal 2 damage unless the caster pays {2}.", _enemy_creature))
		"Breath of Dreams":
			c.static_ability(StaticAbility.new(_breath.bind(CumulativeUpkeep.ability("{1}")), "Green creatures have cumulative upkeep {1}.").changing_abilities().granting_triggers([Mtg.EventType.UPKEEP_START]))
		"Musician":
			c.activated(F._ability("", true, F.Action.new(_music, "add a music counter and grant its upkeep payment", TargetSpec.creature())))
		"Illusionary Presence":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _presence, "Choose a landwalk type for this turn.", F._your_upkeep))
		"Lim-Dûl's Hex":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _hex, "Each player may pay {B} or {3} to prevent 1 damage.", F._your_upkeep))
		"Mole Worms", "Ice Floe":
			c.with_may_skip_untap()
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _land) if c.card_name == "Mole Worms" else TargetSpec.creature("target nonflying creature attacking you", _ground).with_source_filter(_attacking_you)
			c.activated(F._ability("", true, Freeze.new(spec)))
		"Soldevi Golem":
			c.static_ability(StaticAbility.new(_skip_untap, "This creature doesn't untap during your untap step."))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _golem, "You may untap target tapped enemy creature to untap this creature.", F._your_upkeep).targeting(TargetSpec.creature("target tapped creature an opponent controls", _tapped).with_source_filter(_enemy)))
		_: return false
	return true

static func _enchantment(i: CardInstance) -> bool: return i.is_type(Mtg.CardType.ENCHANTMENT)
static func _ground(i: CardInstance) -> bool: return not i.has_keyword(Mtg.Keyword.FLYING)
static func _small(i: CardInstance) -> bool: return i.cur_power <= 2
static func _land(i: CardInstance) -> bool: return i.is_land()
static func _tapped(i: CardInstance) -> bool: return i.tapped
static func _enemy(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id != s.controller_id
static func _owned(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.owner_id == s.controller_id
static func _attacker(g: MtgGame, i: CardInstance) -> bool: return g.combat.attackers.has(i.id)
static func _attacking_you(g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id != s.controller_id and _attacker(g, i)
static func _defending_snow(g: MtgGame, _s: CardInstance) -> String:
	return "" if SNOW.snow_count(g, 1 - g.active_player) > 0 else "Defending player must control a snow land"
static func _hourglass(g: MtgGame, s: CardInstance) -> void:
	for i in g.all_battlefield():
		if i.is_creature(): i.cur_power += int(s.counters.get("time", 0))
static func _remove_time(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if CREATURES.same_activation(g, s): g.remove_counters(s, "time")
static func _sphere(g: MtgGame, s: CardInstance) -> void:
	for i in g.players[s.controller_id].battlefield:
		if i.is_creature():
			if g.active_player == s.controller_id: i.cur_power += 2
			else: i.cur_toughness -= 2
static func _grandeur(g: MtgGame, s: CardInstance, e: GameEvent, amount: int) -> void:
	g.adjust_life(int(e.data.get("from_controller", g.trigger_context(s).controller)), amount)
static func _enemy_island(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i: CardInstance = e.data.get("instance")
	return i != null and i.is_land() and i.has_subtype("island") and int(e.data.controller) != s.controller_id
static func _leech(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var who := int(g.trigger_context(s).controller)
	if g.agents[who].choose_yes_no(g, who, "Thoughtleech: gain 1 life?", true): g.adjust_life(who, 1)
static func _enemy_noncreature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.controller) != s.controller_id and not e.data.instance.is_creature()
static func _enemy_creature(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return int(e.data.controller) != s.controller_id and e.data.instance.is_creature()
static func _remora(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	if EffectBase.unless_paid(g, int(e.data.controller), ManaCost.parse("{4}"), "Pay {4} to stop Mystic Remora's draw?"): return
	var who := int(g.trigger_context(s).controller)
	if g.agents[who].choose_yes_no(g, who, "Mystic Remora: draw a card?", not g.players[who].library.is_empty()): g.draw_cards(who, 1)
static func _barrier(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.controller)
	if not EffectBase.unless_paid(g, who, ManaCost.parse("{2}"), "Pay {2} to prevent Soul Barrier's damage?"): g.deal_damage(s, TargetRef.player(who), 2)
static func _breath(g: MtgGame, _s: CardInstance, upkeep: TriggeredAbility) -> void:
	for i in g.all_battlefield():
		if i.is_creature() and (i.cur_colors & Mtg.ManaColor.G) != 0: i.cur_triggered_abilities.append(upkeep)
static func _music(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var i := g.find_instance(t.instance_id)
	if i == null: return
	g.add_counters(i, "music")
	for trigger in i.cur_triggered_abilities:
		if trigger.text == "Music upkeep: pay {1} per music counter or destroy this creature.": return
	var upkeep := TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _music_upkeep,
		"Music upkeep: pay {1} per music counter or destroy this creature.", F._your_upkeep).capturing(F._source_context)
	g.continuous.add_floating_static(s, StaticAbility.new(_grant_music.bind(i.id, upkeep), "Music upkeep.").changing_abilities(), ContinuousEffects.Duration.INDEFINITE, -1, false, i.id)
	g.recalculate()
static func _grant_music(g: MtgGame, _s: CardInstance, id: int, upkeep: TriggeredAbility) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD: i.cur_triggered_abilities.append(upkeep)
static func _music_upkeep(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s): return
	var who := int(g.trigger_context(s).controller)
	var n := int(s.counters.get("music", 0))
	if not EffectBase.unless_paid(g, who, ManaCost.parse("{%d}" % n), "Pay {%d} for %s's music upkeep?" % [n, s.data.card_name]): g.destroy(s)
static func _presence(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not F._same_trigger_source(g, s) or not g.is_present(s): return   # CR 702.26e
	var who := int(g.trigger_context(s).controller)
	var types: Array[String] = ["plains", "island", "swamp", "mountain", "forest", "desert", "gate", "lair", "locus", "mine", "power-plant", "sphere", "tower", "urza's"]
	var hint := 0
	for land in g.players[1 - who].battlefield:
		if not land.is_land(): continue
		for type in land.cur_subtypes:
			if types.has(type): hint = types.find(type)
	var choice := g.agents[who].choose_option(g, who, types, "Illusionary Presence: choose a land type", hint)
	g.continuous.add_until_eot_landwalk(s.id, [types[choice]])
	g.recalculate()
static func _hex(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	for who in [g.active_player, 1 - g.active_player]:
		var paid := EffectBase.unless_paid(g, who, ManaCost.parse("{B}"), "Pay {B} to prevent Lim-Dûl's Hex's damage?")
		if not paid: paid = EffectBase.unless_paid(g, who, ManaCost.parse("{3}"), "Pay {3} instead to prevent Lim-Dûl's Hex's damage?")
		if not paid: g.deal_damage(s, TargetRef.player(who), 1)
static func _colored_spell(_g: MtgGame, _s: CardInstance, e: GameEvent, color: int) -> bool: return (e.data.instance.cur_colors & color) != 0
static func _talisman(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var who := int(g.trigger_context(s).controller)
	var i := g.find_instance(targets[0].instance_id)
	if EffectBase.unless_paid(g, who, ManaCost.parse("{3}"), "%s: pay {3} to untap %s?" % [s.data.card_name, i.data.card_name], i.tapped and i.controller_id == who): g.untap_permanent(i)
static func _skip_untap(_g: MtgGame, s: CardInstance) -> void: s.cur_skips_untap = true
static func _golem(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var targets := g.current_targets()
	if targets.is_empty(): return
	var who := int(g.trigger_context(s).controller)
	if not g.agents[who].choose_yes_no(g, who, "Untap that creature to untap Soldevi Golem?", s.tapped): return
	g.untap_permanent(g.find_instance(targets[0].instance_id))
	if F._same_trigger_source(g, s): g.untap_permanent(s)
static func _freeze(g: MtgGame, s: CardInstance, target_id: int, stamp: int, untaps: int) -> void:
	# A phased-out source can't be seen to "remain tapped" (CR 702.26f).
	if not g.is_present(s) or s.layer_timestamp != stamp or not s.tapped or s.untap_sequence != untaps: return
	var i := g.find_instance(target_id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD: i.cur_skips_untap = true

class Freeze extends TapEffect:
	func _init(spec: TargetSpec) -> void: super(spec)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var stamp := int(g.cost_paid("_source_timestamp", s.layer_timestamp))
		var untaps := int(g.cost_paid("_source_untap_sequence", s.untap_sequence))
		if not CREATURES.same_activation(g, s) or not g.is_present(s) or not s.tapped or s.untap_sequence != untaps: return   # CR 611.2b, 702.26f
		g._rec(s, &"memory")
		s.memory["holding"] = t.instance_id
		g.continuous.add_floating_static(s, StaticAbility.new(load("res://cards/sets/ice/_permanents.gd")._freeze.bind(t.instance_id, stamp, untaps), "Doesn't untap while its source stays tapped."), ContinuousEffects.Duration.INDEFINITE, -1, false, t.instance_id)
		g.recalculate()
