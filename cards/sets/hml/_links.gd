extends RefCounted
const F := preload("res://cards/sets/fem/_rules.gd")
const A := preload("res://cards/sets/ice/_auras.gd")
const C := preload("res://cards/sets/ice/_creatures.gd")
const R := preload("res://cards/sets/hml/_resources.gd")
const TYPES := preload("res://engine/core/creature_types.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Funeral March":
			c.enchants(TargetSpec.creature())
			c.triggered(TriggeredAbility.new(Mtg.EventType.LEAVES_BATTLEFIELD, _funeral, "That creature's controller sacrifices a creature.", _host_left))
		"Orcish Mine":
			c.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", A._land)).with_enters_counters("ore", 3)
			c.triggered(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _ore, "Remove an ore counter.", F._your_upkeep))
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECAME_TAPPED, _ore, "Remove an ore counter.", A._host_tapped))
			c.triggered(TriggeredAbility.new(Mtg.EventType.COUNTERS_REMOVED, _mine, "Destroy enchanted land and deal 2 damage to its controller.", _last_ore).capturing(A._host_context))
		"Mammoth Harness":
			c.enchants(TargetSpec.creature())
			c.static_ability(StaticAbility.new(_no_flying, "Enchanted creature loses flying.").changing_abilities())
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _harness, "The other creature gains first strike this turn.", _host_fought).capturing(_other_context))
		"An-Zerrin Ruins":
			c.as_it_enters(_choose_type).with_chosen_type("hml_type")
			c.static_ability(StaticAbility.new(_type_lock, "Creatures of the chosen type don't untap during their controllers' untap steps."))
		"Marjhan":
			c.static_ability(StaticAbility.new(R._no_untap, "Doesn't untap during your untap step."))
			c.with_attack_needs_defender_land("island")
			c.triggered(TriggeredAbility.new(Mtg.EventType.STATE_CHECK, _marjhan_sacrifice, "Sacrifice this creature.", _no_island))
			c.activated(F._ability("{U}{U}", false, F.Action.new(R._untap_self, "untap this creature", null, true)).with_sacrifice_of("creature", R._creature).may_sacrifice_itself().during_step(Mtg.Step.UPKEEP).your_turn_only())
			c.activated(F._ability("{U}{U}", false, MarjhanDamage.new()))
		"Joven's Tools":
			c.activated(F._ability("{4}", true, F.Action.new(_tools, "target creature can't be blocked except by Walls this turn", TargetSpec.creature(), true)))
		_: return false
	return true

static func _host_left(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var id := s.attached_to if s.zone == Mtg.Zone.BATTLEFIELD else s.last_attached_to
	return e.data.instance.id == id
static func _funeral(g: MtgGame, _s: CardInstance, e: GameEvent) -> void:
	var who := int(e.data.from_controller)
	var choices: Array[CardInstance] = []
	for i in g.players[who].battlefield:
		if i.is_creature(): choices.append(i)
	if choices.is_empty(): return
	var pick := g.agents[who].choose_card(g, who, choices, "Funeral March: sacrifice a creature", false, true)
	if pick != null and choices.has(pick): g.sacrifice_permanent(pick)
static func _ore(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s): g.remove_counters(s, "ore")
static func _last_ore(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.instance == s and e.data.kind == "ore" and int(e.data.remaining) == 0
static func _mine(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var context := g.trigger_context(s)
	var i := A._trigger_host(g, s)
	# If it is still here, use its CURRENT controller; otherwise use the
	# attachment's last known controller captured when the ability triggered.
	var who := i.controller_id if i != null else int(context.get("host_controller", -1))
	if i != null: g.destroy(i)
	if who >= 0: g.deal_damage(s, TargetRef.player(who), 2)
static func _no_flying(g: MtgGame, s: CardInstance) -> void:
	var i := A.host(g, s)
	if i != null: i.cur_keywords.erase(Mtg.Keyword.FLYING)
static func _host_fought(g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var i := A.host(g, s)
	return i != null and (e.data.attacker == i or e.data.blocker == i)
static func _other_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var i: CardInstance = e.data.blocker if e.data.attacker == A.host(g, s) else e.data.attacker
	return {"id": i.id, "stamp": i.layer_timestamp}
static func _harness(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var ctx := g.trigger_context(s)
	var i := g.find_instance(int(ctx.id))
	if g.is_present(i) and i.layer_timestamp == int(ctx.stamp):   # CR 702.26e
		g.continuous.add_until_eot_pump(i.id, 0, 0, [Mtg.Keyword.FIRST_STRIKE])
		g.recalculate()
static func _choose_type(g: MtgGame, s: CardInstance, _pid: int) -> void:
	# Only public battlefield characteristics inform the default. The whole
	# legal catalogue remains available to a human, even with an empty board.
	var counts := {}
	for i in g.players[1 - s.controller_id].battlefield:
		if i.is_creature():
			for type in i.cur_subtypes: counts[type] = int(counts.get(type, 0)) + 1
	var best := 0
	var score := -1
	for index in TYPES.ALL.size():
		var count := int(counts.get(TYPES.ALL[index].to_lower(), 0))
		if count > score:
			best = index
			score = count
	var pick := g.agents[s.controller_id].choose_option(g, s.controller_id, TYPES.ALL, "An-Zerrin Ruins: choose a creature type", best)
	g._rec(s, &"memory")
	s.memory["hml_type"] = TYPES.ALL[clampi(pick, 0, TYPES.ALL.size() - 1)].to_lower()
static func _type_lock(g: MtgGame, s: CardInstance) -> void:
	var type := String(s.memory.get("hml_type", ""))
	for i in g.all_battlefield():
		if i.is_creature() and i.has_subtype(type): i.cur_skips_untap = true
static func _tools(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	g.continuous.add_floating_static(s, StaticAbility.new(_walls_only.bind(t.instance_id), "Can't be blocked except by Walls."), ContinuousEffects.Duration.END_OF_TURN, -1, false, t.instance_id)
	g.recalculate()
static func _walls_only(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: i.cur_block_restrictions.append({"desc": "Wall", "filter": F._subtype.bind("wall")})
static func _no_island(g: MtgGame, s: CardInstance, _e: GameEvent) -> bool:
	for i in g.players[s.controller_id].battlefield:
		if R._island(i): return false
	return true
static func _marjhan_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if F._same_trigger_source(g, s) and s.controller_id == int(g.trigger_context(s).controller): g.sacrifice_permanent(s)
class MarjhanDamage extends DamageEffect:
	func _init() -> void:
		super(1)
		target_creature("target attacking creature without flying")
		target_spec.with_game_filter(_ground_attacker)
	static func _ground_attacker(g: MtgGame, i: CardInstance) -> bool:
		return g.combat.attackers.has(i.id) and not i.has_keyword(Mtg.Keyword.FLYING)
	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, x := 0) -> void:
		if C.same_activation(g, s) and g.is_present(s):   # CR 702.26e
			g.continuous.add_until_eot_pump(s.id, -1, 0)
			g.recalculate()
		super(g, s, pid, t, x)
	func describe() -> String: return "this creature gets -1/-0 this turn and deals 1 damage to target attacking creature without flying"
