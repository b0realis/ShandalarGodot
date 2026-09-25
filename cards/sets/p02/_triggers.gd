extends RefCounted
## Targets are announced on the stack; choices and source incarnations use
## the same replay-safe decision funnel as the original Portal cards.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")
const T := preload("res://cards/sets/por/_triggers.gd")
const B := preload("res://cards/sets/p02/_simple.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Angel of Mercy", "Temple Acolyte": T.enter(c, GainLifeEffect.new(3))
		"Vampiric Spirit": T.enter(c, GainLifeEffect.new(-4))
		"Magma Giant": T.enter(c, DamageAllEffect.new(2).and_each_player())
		"Ogre Arsonist": T.enter(c, DestroyEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", S._land)))
		"Alaborn Cavalier": c.triggered(T.trigger(TapEffect.new(TargetSpec.creature()), Mtg.EventType.DECLARED_ATTACKERS, F._self_attack, true))
		"Talas Explorer": T.enter(c, F.Action.new(T._look, "look at target opponent's hand", TargetSpec.opponent()))
		"Ravenous Rats", "Brutal Nightstalker": T.enter(c, F.Action.new(T._discard, "target opponent discards a card", TargetSpec.opponent()), c.card_name == "Brutal Nightstalker")
		"Predatory Nightstalker": T.enter(c, B.Edict.new(), true)
		"Screeching Drake": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, T._owl, "Draw a card, then discard a card.", F._self_enter))
		"Angel of Fury": c.triggered(TriggeredAbility.new(Mtg.EventType.DIES, _angel, c.oracle_text, F._self_enter).capturing(T._death_context))
		"Hidden Horror": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _horror, c.oracle_text, F._self_enter))
		"Foul Spirit": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _land_sacrifice, c.oracle_text, F._self_enter))
		"Denizen of the Deep": c.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _denizen, c.oracle_text, F._self_enter))
		"Sea Drake":
			var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land you control", S._land).with_source_filter(_ours)
			var trigger := TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _sea_drake, c.oracle_text, F._self_enter).targeting(spec)
			trigger.target_min = 2
			trigger.target_max = 2
			c.triggered(trigger)
		"Lurking Nightstalker": c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, T._charge.bind(2, 0), c.oracle_text, F._self_attack))
		"Town Sentry": c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKER, T._charge.bind(0, 2), c.oracle_text, F._self_enter))
		"Norwood Warrior", "Razorclaw Bear":
			var amount := 1 if c.card_name == "Norwood Warrior" else 2
			c.triggered(TriggeredAbility.new(Mtg.EventType.BECOMES_BLOCKED, T._charge.bind(amount, amount), c.oracle_text, F._self_enter))
		"Abyssal Nightstalker": c.triggered(TriggeredAbility.new(Mtg.EventType.UNBLOCKED_ATTACKER, T._toad, c.oracle_text, F._self_enter))
		"Goblin General": c.triggered(TriggeredAbility.new(Mtg.EventType.DECLARED_ATTACKERS, _general, c.oracle_text, F._self_attack))
		"Alaborn Zealot", "Sylvan Basilisk":
			var zealot := c.card_name == "Alaborn Zealot"
			c.triggered(TriggeredAbility.new(Mtg.EventType.BLOCKED, _kill_pair.bind(zealot), c.oracle_text, _fights.bind(zealot)).capturing(_fight_context))
		_: return false
	return true

static func _ours(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return i.controller_id == s.controller_id
static func _fights(_g: MtgGame, s: CardInstance, e: GameEvent, blocking: bool) -> bool: return (e.data.blocker if blocking else e.data.attacker) == s

static func _fight_context(g: MtgGame, s: CardInstance, e: GameEvent) -> Dictionary:
	var context := F._source_context(g, s, e)
	var other: CardInstance = e.data.attacker if e.data.blocker == s else e.data.blocker
	context["other"] = other.id
	context["other_stamp"] = other.layer_timestamp
	return context

static func _kill_pair(g: MtgGame, s: CardInstance, _e: GameEvent, both: bool) -> void:
	var context := g.trigger_context(s)
	var other := g.find_instance(int(context.other))
	g.begin_simultaneous()
	if other != null and other.zone == Mtg.Zone.BATTLEFIELD and other.layer_timestamp == int(context.other_stamp): g.destroy(other)
	if both and F._same_trigger_source(g, s): g.destroy(s)
	g.end_simultaneous()

static func _general(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	for i in g.players[pid].creatures():
		if i.has_subtype("goblin"): g.continuous.add_until_eot_pump(i.id, 1, 1)
	g.recalculate()

static func _angel(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	if not g.agents[int(g.trigger_context(s).controller)].choose_yes_no(g, int(g.trigger_context(s).controller), "Angel of Fury: shuffle it into its owner's library?", true): return
	if s.zone == Mtg.Zone.GRAVEYARD and s.graveyard_entry == int(g.trigger_context(s).entry): g.return_from_graveyard_to_library_top(s)
	g.shuffle_library(s.owner_id)

static func _horror(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var choices: Array[CardInstance] = []
	for i in g.players[pid].hand:
		if i.is_creature(): choices.append(i)
	var pick := g.agents[pid].choose_card(g, pid, choices, "Discard a creature card, or sacrifice Hidden Horror", true, true)
	if pick != null and choices.has(pick): g.discard_cards(pid, [pick])
	elif F._same_trigger_source(g, s): g.sacrifice_permanent(s)

static func _land_sacrifice(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	var choices: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.is_land(): choices.append(i)
	if choices.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, choices, "Sacrifice a land", false, true)
	if pick == null or not choices.has(pick): pick = choices[0]
	g.sacrifice_permanent(pick)

static func _denizen(g: MtgGame, s: CardInstance, _e: GameEvent) -> void:
	var pid := int(g.trigger_context(s).controller)
	g.begin_simultaneous()
	for i in g.players[pid].creatures():
		if i != s or not F._same_trigger_source(g, s): g.return_to_hand(i)
	g.end_simultaneous()

static func _sea_drake(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
	g.begin_simultaneous()
	for target in g.current_targets(): g.return_to_hand(g.find_instance(target.instance_id))
	g.end_simultaneous()
