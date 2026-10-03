extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Sengir Autocrat":
			c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _serfs, "Create three 0/1 black Serf creature tokens.", F._self_enter))
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _clear_tokens.bind("serf", true), "Exile all Serf tokens.", _self_left))
		"Drudge Spell":
			var effect := CreateTokenEffect.new("Skeleton", 1, 1, Mtg.ManaColor.B, "skeleton")
			effect.token.activated(F._ability("{B}", false, RegenerateEffect.new()))
			var a := F._ability("{B}", false, effect).with_exile_from_graveyard("creature card", _creature)
			a.graveyard_exile_count = 2
			c.activated(a)
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _clear_tokens.bind("skeleton", false), "Destroy all Skeleton tokens without regeneration.", _self_left))
		"Coral Reef":
			c.with_enters_counters("polyp", 4)
			c.activated(F._ability("", false, F.Action.new(_polyp, "put two polyp counters on this enchantment")).with_sacrifice_of("Island", _island))
			var a := F._ability("{U}", false, CounterMarkerEffect.new("+0/+1")).with_counter_cost("polyp")
			a.tap_permanent_count = 1
			a.tap_permanent_filter = _blue_creature
			c.activated(a)
		"Didgeridoo": c.activated(F._ability("{3}", false, F.Action.new(_put_tribe.bind("minotaur"), "you may put a Minotaur permanent card from your hand onto the battlefield", null, true)))
		"Willow Priestess":
			c.activated(F._ability("", true, F.Action.new(_put_tribe.bind("faerie"), "you may put a Faerie permanent card from your hand onto the battlefield", null, true)))
			c.activated(F._ability("{2}{G}", false, F.Action.new(_protect, "target green creature gains protection from black this turn", TargetSpec.creature("target green creature", F._color.bind(Mtg.ManaColor.G)), true)))
		"Wall of Kelp":
			var effect := CreateTokenEffect.new("Kelp", 0, 1, Mtg.ManaColor.U, "plant")
			effect.token.with_subtypes(["plant", "wall"]).with_keywords([Mtg.Keyword.DEFENDER])
			c.activated(F._ability("{U}{U}", true, effect))
		"Serrated Arrows":
			c.with_enters_counters("arrowhead", 3)
			c.activated(F._ability("", true, CounterMarkerEffect.new("-1/-1")).with_counter_cost("arrowhead"))
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _arrows_empty, "Sacrifice this artifact if it has no arrowhead counters.", _empty_upkeep))
		"Trade Caravan":
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, F._counter_upkeep.bind("currency"), "Put a currency counter on this creature.", F._your_upkeep))
			c.activated(F._ability("", false, UntapEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target basic land", _basic))).with_counter_cost("currency", 2).during_step(Mtg.Step.UPKEEP).opponents_turn_only())
		"Black Carriage":
			c.static_ability(StaticAbility.new(_no_untap, "Doesn't untap during your untap step."))
			c.activated(F._ability("", false, F.Action.new(_untap_self, "untap this creature", null, true)).with_sacrifice_of("creature", _creature).may_sacrifice_itself().during_step(Mtg.Step.UPKEEP).your_turn_only())
		"Reveka, Wizard Savant": c.activated(F._ability("", true, Reveka.new()))
		"Samite Alchemist": c.activated(F._ability("{W}{W}", true, Alchemist.new()))
		"Serra Paladin":
			c.activated(F._ability("", true, PreventDamageEffect.new(1).any_target()))
			c.activated(F._ability("{1}{W}{W}", true, PumpEffect.new(0, 0, [Mtg.Keyword.VIGILANCE])))
		"Dwarven Pony": c.activated(F._ability("{1}{R}", true, F.Action.new(_pony, "target Dwarf creature gains mountainwalk this turn", TargetSpec.creature("target Dwarf creature", F._subtype.bind("dwarf")), true)))
		"Veldrane of Sengir": c.activated(F._ability("{1}{B}{B}", false, F.Action.new(_veldrane, "this creature gets -3/-0 and forestwalk until end of turn", null, true)))
		"Dark Maze": c.activated(F._ability("", false, F.Action.new(_maze, "this creature may attack with defender this turn; exile it at the next end step", null, true)))
		_: return false
	return true

static func _creature(i: CardInstance) -> bool: return i.is_creature()
static func _island(i: CardInstance) -> bool: return i.is_land() and i.has_subtype("island")
static func _basic(i: CardInstance) -> bool: return i.is_land() and (i.cur_supertypes & Mtg.Supertype.BASIC) != 0
static func _blue_creature(i: CardInstance) -> bool: return i.is_creature() and (i.cur_colors & Mtg.ManaColor.U) != 0
static func _self_left(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return e.data.instance == s
static func _serfs(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	CreateTokenEffect.new("Serf", 0, 1, Mtg.ManaColor.B, "serf", 3).resolve(g, s, int(g.trigger_context(s).controller), null)
static func _clear_tokens(g: MtgGame, _s: CardInstance, _e: GameEvent, subtype: String, exile: bool) -> void:
	var victims: Array[CardInstance] = []
	for i in g.all_battlefield():
		if i.is_token and i.has_subtype(subtype): victims.append(i)
	g.begin_simultaneous()
	for i in victims:
		if exile: g.exile_permanent(i)
		else: g.destroy(i, false)
	g.end_simultaneous()
static func _polyp(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if C.same_activation(g, s): g.add_counters(s, "polyp", 2)
static func _put_tribe(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int, type: String) -> void:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].hand:
		if i.has_subtype(type) and (i.cur_types & (Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT | Mtg.CardType.ENCHANTMENT | Mtg.CardType.LAND)) != 0: choices.append(i)
	var pick := g.agents[pid].choose_card(g, pid, choices, "Put a %s permanent from your hand onto the battlefield" % type, true)
	if pick != null and choices.has(pick): g.put_from_hand_into_play(pick, pid)
static func _protect(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_until_eot_protection(t.instance_id, Mtg.ManaColor.B)
	g.recalculate()
static func _empty_upkeep(g: MtgGame, s: CardInstance, e: GameEvent) -> bool: return F._your_upkeep(g, s, e) and int(s.counters.get("arrowhead", 0)) == 0
static func _arrows_empty(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and int(s.counters.get("arrowhead", 0)) == 0: g.sacrifice_permanent(s)
static func _no_untap(_g: MtgGame, s: CardInstance) -> void: s.cur_skips_untap = true
static func _untap_self(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if C.same_activation(g, s): g.untap_permanent(s)
static func _pony(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_until_eot_landwalk(t.instance_id, ["mountain"])
	g.recalculate()
static func _veldrane(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s) or not g.is_present(s): return   # CR 702.26e
	g.continuous.add_until_eot_pump(s.id, -3, 0)
	g.continuous.add_until_eot_landwalk(s.id, ["forest"])
	g.recalculate()
static func _maze(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if not C.same_activation(g, s): return
	# Phased out: no attack permission (CR 702.26e); the exile below is
	# still scheduled — it is a delayed trigger, guarded at the end step.
	if g.is_present(s): g.continuous.add_floating_static(s, StaticAbility.new(_can_attack.bind(s.id), "Can attack as though it didn't have defender."), ContinuousEffects.Duration.END_OF_TURN, -1, false, s.id)
	g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.END_STEP_START, _exile.bind(s.id, s.layer_timestamp), "Exile this creature."), pid, s)
	g.recalculate()
static func _can_attack(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: i.cur_can_attack_with_defender = true
static func _exile(g: MtgGame, _s: CardInstance, _e: GameEvent, id: int, stamp: int) -> void:
	var i := g.find_instance(id)
	if i != null and i.zone == Mtg.Zone.BATTLEFIELD and i.layer_timestamp == stamp: g.exile_permanent(i)

class Reveka extends DamageEffect:
	func _init() -> void:
		super(2)
		any_target()
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		if C.same_activation(g, s):
			g.skip_untap_during_next_step(s, pid)
	func describe() -> String: return "deal 2 damage to any target; this creature skips your next untap step"

class Alchemist extends PreventDamageEffect:
	func _init() -> void:
		super(4)
		target_creature("target creature you control")
		target_spec.with_source_filter(F._own)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		super(g, s, pid, t, x)
		var i := g.find_instance(t.instance_id)
		g.tap_permanent(i)
		g.skip_untap_during_next_step(i, pid)
	func describe() -> String: return "prevent the next 4 damage to target creature you control; tap it and skip your next untap"
