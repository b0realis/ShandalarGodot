extends RefCounted
## Shared one-shot families. Hidden zones are read only during legally
## instructed look/search resolutions, never to decide whether to cast.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")
const T := preload("res://cards/sets/por/_triggers.gd")
const B := preload("res://cards/sets/p02/_simple.gd")
const P := preload("res://cards/sets/ice/_patterns.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Coastal Wizard": c.activated(B.early(CoastalReturn.new()))
		"Norwood Priestess": c.activated(B.early(F.Action.new(_priestess, "you may put a green creature card from your hand onto the battlefield", null, true).with_ai_role(&"green_creature_from_hand")))
		"Goblin Matron": T.enter(c, GoblinSearch.new(), true)
		"Sleight of Hand": c.spell(F.Action.new(_sleight, "look at two cards; keep one and put the other on the bottom", null, true).with_ai_role(&"select_one_of_two"))
		"Eye Spy": c.spell(F.Action.new(_eye, "look at target player's top card; you may put it into their graveyard", TargetSpec.player()).with_ai_role(&"look_and_mill_one"))
		"Goblin Lore": c.spell(DrawEffect.new(4)).spell(F.Action.new(_lore, "discard three cards at random"))
		"Salvage": c.spell(GraveTop.new().any_card())
		"Renewing Touch": c.spell(GraveShuffle.new())
		"Righteous Fury": c.spell(CountedDestruction.new(true))
		"Rain of Daggers": c.spell(CountedDestruction.new(false))
		"Return of the Nightstalkers": c.spell(F.Action.new(_nightstalkers, "return your Nightstalker permanent cards, then destroy your Swamps", null, true).with_ai_role(&"return_nightstalkers"))
		"Wildfire": c.spell(F.Action.new(_wildfire, "each player sacrifices four lands; deal 4 damage to each creature").with_ai_role(&"sacrifice_lands_sweep"))
		"Harmony of Nature": c.spell(F.Action.new(_harmony, "tap any number of untapped creatures you control; gain 4 life for each", null, true).with_ai_role(&"tap_creatures_for_life"))
		"Goblin War Cry": c.spell(F.Action.new(_war_cry, "target opponent chooses their only creature that can block this turn", TargetSpec.opponent()).with_ai_role(&"one_enemy_blocker"))
		"Dakmor Sorceress", "Nightstalker Engine", "Swarm of Rats", "Sylvan Yeti":
			var kind: String = {"Dakmor Sorceress": "swamps", "Nightstalker Engine": "graveyard", "Swarm of Rats": "rats", "Sylvan Yeti": "hand"}[c.card_name]
			c.static_ability(StaticAbility.new(_power.bind(kind), c.oracle_text).setting_base_pt())
			c.characteristic_definition = _power.bind(kind)
		_: return false
	return true

class CoastalReturn extends ReturnToHandEffect:
	func _init() -> void:
		super(TargetSpec.creature("another target creature").with_source_filter(_other))
	func resolve(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.begin_simultaneous()
		g.return_to_hand(g.find_instance(t.instance_id))
		if s.zone == Mtg.Zone.BATTLEFIELD and s.layer_timestamp == int(g.cost_paid("_source_timestamp", -1)): g.return_to_hand(s)
		g.end_simultaneous()
	static func _other(_g: MtgGame, s: CardInstance, i: CardInstance) -> bool: return s != i
	func describe() -> String: return "return this creature and another target creature to their owners' hands"

class GoblinSearch extends SearchLibraryEffect:
	func _init() -> void: super("a Goblin card", S._subtype.bind("goblin"))
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		g.search_library(pid, filter, "Search for a Goblin card", false, true, "Goblin Matron — revealed card")

class GraveTop extends ReturnFromGraveyardEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x := 0) -> void:
		g.return_from_graveyard_to_library_top(g.find_instance(t.instance_id))
	func describe() -> String: return "put target card from your graveyard on top of your library"

class GraveShuffle extends ReturnFromGraveyardEffect:
	func _init() -> void:
		super()
		target_min = 0
		target_max = -1
		resolves_untargeted = true
		with_ai_role(&"shuffle_grave_creatures")
	func resolve_multi(g: MtgGame, _s: CardInstance, pid: int, targets: Array, _x := 0) -> void:
		for t in targets: g.return_from_graveyard_to_library_top(g.find_instance(t.instance_id))
		g.shuffle_library(pid)
	func describe() -> String: return "shuffle any number of target creature cards from your graveyard into your library"

class CountedDestruction extends EffectBase:
	var gain: bool
	func _init(gains: bool) -> void:
		gain = gains
		if not gain: target_spec = TargetSpec.opponent()
		with_ai_role(&"destroy_tapped_gain_life" if gain else &"destroy_enemy_lose_life")
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var count := 0
		var bodies: Array[CardInstance] = []
		for body in g.all_battlefield():
			if body.is_creature() and ((gain and body.tapped) or (not gain and body.controller_id == t.player_id)): bodies.append(body)
		g.begin_simultaneous()
		for i in bodies:
			g.destroy(i)
			if i.zone != Mtg.Zone.BATTLEFIELD: count += 1
		g.adjust_life(pid, count * (2 if gain else -2))
		g.end_simultaneous()
	func describe() -> String:
		return "destroy tapped creatures; gain 2 life per creature destroyed" if gain else "destroy target opponent's creatures; lose 2 life per creature destroyed"

static func _priestess(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var choices: Array[CardInstance] = []
	for i in g.players[pid].hand:
		if S._colored_creature(i, Mtg.ManaColor.G): choices.append(i)
	var pick := g.agents[pid].choose_card(g, pid, choices, "Put a green creature onto the battlefield (or decline)", true)
	if pick != null and choices.has(pick): g.put_from_hand_into_play(pick, pid)

static func _sleight(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards := P.top(g, pid, 2)
	if cards.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, cards, "Choose a card to put into your hand")
	if pick == null or not cards.has(pick): pick = cards[0]
	cards.erase(pick)
	g.library_card_to_hand(pick)
	for i in cards: g.put_on_bottom_of_library(i)

static func _eye(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var cards := P.top(g, t.player_id, 1)
	if cards.is_empty(): return
	g.reveal_information(pid, "Eye Spy — top card", [cards[0].data.card_name])
	# The looked-at card is legal information now, not a planning peek.
	var hint: bool = t.player_id != pid
	if g.agents[pid].choose_yes_no(g, pid, "Put %s into its owner's graveyard?" % cards[0].data.card_name, hint): g.mill(t.player_id, 1)

static func _lore(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void: g.discard_random(pid, 3)

static func _nightstalkers(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards: Array[CardInstance] = []
	for i in g.players[pid].graveyard:
		if i.has_subtype("nightstalker") and i.data.is_permanent_type(): cards.append(i)
	g.begin_simultaneous()
	for i in cards: g.reanimate(i, pid)
	for i in g.players[pid].battlefield.duplicate():
		if i.has_subtype("swamp"): g.destroy(i)
	g.end_simultaneous()

static func _wildfire(g: MtgGame, s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var picks: Array[CardInstance] = []
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		var cards: Array[CardInstance] = []
		for i in g.players[who].battlefield:
			if i.is_land(): cards.append(i)
		for n in mini(4, cards.size()):
			var pick := g.agents[who].choose_card(g, who, cards, "Wildfire: choose a land to sacrifice", false, true)
			if pick == null or not cards.has(pick): pick = cards[0]
			picks.append(pick)
			cards.erase(pick)
	g.begin_simultaneous()
	for i in picks: g.sacrifice_permanent(i)
	for i in g.all_battlefield():
		if i.is_creature(): g.deal_damage(s, TargetRef.card(i), 4)
	g.end_simultaneous()

static func _harmony(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards: Array[CardInstance] = []
	for i in g.players[pid].creatures():
		if not i.tapped: cards.append(i)
	var hint := mini(cards.size(), maxi(0, ceili(float(16 - g.players[pid].life) / 4.0)))
	var amount := clampi(g.agents[pid].choose_number(g, pid, 0, cards.size(), "How many creatures will you tap for 4 life each?", hint), 0, cards.size())
	var picks: Array[CardInstance] = []
	for n in amount:
		var pick := g.agents[pid].choose_card(g, pid, cards, "Choose a creature to tap", false, true)
		if pick == null or not cards.has(pick): pick = cards[0]
		picks.append(pick)
		cards.erase(pick)
	g.begin_simultaneous()
	for i in picks: g.tap_permanent(i)
	g.adjust_life(pid, 4 * picks.size())
	g.end_simultaneous()

static func _war_cry(g: MtgGame, s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void:
	var cards := g.players[t.player_id].creatures()
	var pick := g.agents[t.player_id].choose_card(g, t.player_id, cards, "Choose the creature that may block this turn")
	if pick == null and not cards.is_empty(): pick = cards[0]
	# Freeze the affected objects on resolution (CR 611.2c); later arrivals
	# are not in this continuous effect and can block normally.
	for i in cards:
		if i == pick: continue
		g.continuous.add_floating_static(s, StaticAbility.new(_no_block.bind(i.id), "Can't block this turn."), ContinuousEffects.Duration.END_OF_TURN, -1, false, i.id)
	g.recalculate()

static func _no_block(g: MtgGame, _s: CardInstance, id: int) -> void:
	var i := g.find_instance(id)
	if i != null: S._no_block(g, i)

static func _power(g: MtgGame, s: CardInstance, kind: String) -> void:
	var me := g.players[s.controller_id if s.zone in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.STACK] else s.owner_id]
	var value := 0
	if kind == "hand": value = me.hand.size()
	elif kind == "graveyard":
		for i in me.graveyard:
			if i.is_creature(): value += 1
	else:
		for i in me.battlefield:
			if i.has_subtype("swamp" if kind == "swamps" else "rat"): value += 1
	s.cur_power = value
