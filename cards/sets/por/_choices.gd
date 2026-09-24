extends RefCounted
## Library/hand access happens only while the card's legal effect resolves.
## Planning never inspects an opponent's hidden cards or a library's order.
const F := preload("res://cards/sets/fem/_rules.gd")
const S := preload("res://cards/sets/por/_simple.gd")
const T := preload("res://cards/sets/por/_triggers.gd")
const P := preload("res://cards/sets/ice/_patterns.gd")

static func configure(c: CardData) -> bool:
	match c.card_name:
		"Ancestral Memories": c.spell(F.Action.new(_memories, "look at seven cards; keep two and put the rest into your graveyard", null, true))
		"Cruel Fate": c.spell(F.Action.new(_fate, "look at five cards of target opponent's library; mill one and order the rest", TargetSpec.opponent()))
		"Omen": c.spell(F.Action.new(_omen, "look at and reorder three cards; you may shuffle, then draw a card", null, true))
		"Personal Tutor": c.spell(Tutor.new("a sorcery card", S._sorcery, true))
		"Sylvan Tutor": c.spell(Tutor.new("a creature card", F._creature, true))
		"Cruel Tutor": c.spell(Tutor.new("a card", Callable(), false)).spell(GainLifeEffect.new(-2))
		"Gift of Estates": c.spell(F.Action.new(_estates, "if an opponent controls more lands, search for up to three Plains cards", null, true))
		"Flux": c.spell(F.Action.new(_flux, "each player may discard cards and draw that many; draw a card", null, true))
		"Temporary Truce": c.spell(F.Action.new(_truce, "each player may draw up to two cards, gaining 2 life per card not drawn", null, true))
		"Prosperity": c.spell(EveryoneDraw.new(0).x_cards())
		"Cruel Bargain": c.spell(DrawEffect.new(4)).spell(F.Action.new(_half_life, "lose half your life, rounded up"))
		"Mind Rot": c.spell(F.Action.new(_mind_rot, "target player discards two cards", TargetSpec.player()).with_ai_role(&"discard", {"count": 2}))
		"Sorcerous Sight": c.spell(F.Action.new(T._look, "look at target opponent's hand", TargetSpec.opponent())).spell(DrawEffect.new(1))
		"Baleful Stare", "Withering Gaze":
			c.spell(F.Action.new(_gaze.bind(c.card_name == "Baleful Stare"), "target opponent reveals their hand; draw for each matching land or colored card", TargetSpec.opponent()))
		"Balance of Power": c.spell(PublicDraw.new("hand"))
		"Theft of Dreams": c.spell(PublicDraw.new("tapped"))
		_: return false
	return true

static func _memories(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var cards := P.top(g, pid, 7)
	var chosen: Array[CardInstance] = []
	for n in mini(2, cards.size()):
		var pick := g.agents[pid].choose_card(g, pid, cards, "Ancestral Memories: choose a card to keep")
		if pick == null or not cards.has(pick): pick = cards[0]
		chosen.append(pick)
		cards.erase(pick)
	for i in chosen: g.library_card_to_hand(i)
	# The remaining top cards go to the graveyard, not discarded or drawn.
	g.mill(pid, cards.size())

static func _fate(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	var cards := P.top(g, t.player_id, 5)
	if cards.is_empty(): return
	var pick := g.agents[pid].choose_card(g, pid, cards, "Cruel Fate: choose a card to put into the graveyard", false)
	if pick == null or not cards.has(pick): pick = cards[0]
	cards.erase(pick)
	g.move_library_card_to_top(pick)
	g.mill(t.player_id, 1)
	P.order(g, pid, t.player_id, cards)

static func _omen(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	P.order(g, pid, pid, P.top(g, pid, 3))
	if g.agents[pid].choose_yes_no(g, pid, "Omen: shuffle your library?", false): g.shuffle_library(pid)
	g.draw_cards(pid, 1)

class Tutor extends SearchLibraryEffect:
	var reveal := false
	func _init(desc: String, predicate: Callable, publicly: bool) -> void:
		super(desc, predicate)
		reveal = publicly
	func resolve(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var cards: Array[CardInstance] = []
		for i in g.players[pid].library:
			if not filter.is_valid() or filter.call(i): cards.append(i)
		var pick := g.agents[pid].choose_card(g, pid, cards, "Search your library for " + description, filter.is_valid())
		if not filter.is_valid() and pick == null and not cards.is_empty(): pick = cards[0]
		if pick != null and cards.has(pick) and reveal:
			g.reveal_information(-1, "Revealed search result", [pick.data.card_name])
		g.shuffle_library(pid)
		if pick != null and cards.has(pick):
			g.move_library_card_to_top(pick)
	func describe() -> String: return "search for %s, shuffle, then put it on top" % description

static func _estates(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	if g.players[g.opponent_of(pid)].battlefield.filter(S._land).size() <= g.players[pid].battlefield.filter(S._land).size(): return
	for n in 3:
		var choices: Array[CardInstance] = []
		for i in g.players[pid].library:
			if i.has_subtype("plains"): choices.append(i)
		if choices.is_empty(): break
		var pick := g.agents[pid].choose_card(g, pid, choices, "Gift of Estates: choose a Plains (or finish)", true)
		if pick == null or not choices.has(pick): break
		g.reveal_information(-1, "Gift of Estates", [pick.data.card_name])
		g.library_card_to_hand(pick)
	g.shuffle_library(pid)

static func _flux(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	var selected := {}
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		var cards: Array[CardInstance] = g.players[who].hand.duplicate()
		var picks: Array[CardInstance] = []
		while not cards.is_empty():
			var pick := g.agents[who].choose_card(g, who, cards, "Flux: discard a card, or finish", true, true)
			if pick == null or not cards.has(pick): break
			picks.append(pick)
			cards.erase(pick)
		selected[who] = picks
	g.begin_simultaneous()
	for who in [g.active_player, g.opponent_of(g.active_player)]: g.discard_cards(who, selected[who])
	for who in [g.active_player, g.opponent_of(g.active_player)]: g.draw_cards(who, selected[who].size())
	g.draw_cards(pid, 1)
	g.end_simultaneous()

static func _truce(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, _x: int) -> void:
	var amounts := {}
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		amounts[who] = clampi(g.agents[who].choose_number(g, who, 0, 2, "Temporary Truce: how many cards to draw?", mini(2, g.players[who].library.size())), 0, 2)
	g.begin_simultaneous()
	for who in [g.active_player, g.opponent_of(g.active_player)]:
		var before := g.players[who].drawn_this_turn.size()
		g.draw_cards(who, amounts[who])
		g.adjust_life(who, 2 * maxi(0, 2 - (g.players[who].drawn_this_turn.size() - before)))
	g.end_simultaneous()

class EveryoneDraw extends DrawEffect:
	func resolve(g: MtgGame, _s: CardInstance, _pid: int, _t: TargetRef, x := 0) -> void:
		g.begin_simultaneous()
		for who in [g.active_player, g.opponent_of(g.active_player)]: g.draw_cards(who, x if use_x else count)
		g.end_simultaneous()
	func describe() -> String: return "each player draws X cards"

static func _half_life(g: MtgGame, _s: CardInstance, pid: int, _t: TargetRef, _x: int) -> void:
	g.adjust_life(pid, -maxi(0, ceili(float(g.players[pid].life) / 2.0)))
static func _mind_rot(g: MtgGame, _s: CardInstance, _pid: int, t: TargetRef, _x: int) -> void: T.discard(g, t.player_id, 2)
static func _gaze(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int, red: bool) -> void:
	var names: Array = []
	var count := 0
	for i in g.players[t.player_id].hand:
		names.append(i.data.card_name)
		if i.has_subtype("mountain" if red else "forest") or (i.cur_colors & (Mtg.ManaColor.R if red else Mtg.ManaColor.G)) != 0: count += 1
	g.reveal_information(-1, "Revealed hand", names)
	g.draw_cards(pid, count)

class PublicDraw extends DrawEffect:
	var kind: String
	func _init(shape: String) -> void:
		super(0)
		kind = shape
		target_spec = TargetSpec.opponent()
	func resolve(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var amount := 0
		if kind == "hand": amount = maxi(0, g.players[t.player_id].hand.size() - g.players[pid].hand.size())
		else:
			for i in g.players[t.player_id].creatures():
				if i.tapped: amount += 1
		g.draw_cards(pid, amount)
	func describe() -> String: return "draw for the opponent's " + ("excess hand size" if kind == "hand" else "tapped creatures")
