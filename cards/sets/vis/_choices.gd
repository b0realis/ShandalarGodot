extends RefCounted
## Visions (_choices, Pack 8). Choices on entry or resolution: colours, players, land types, hidden-zone picks.
##
## Same conventions as the Mirage module (cards/sets/mir/_choices.gd, whose
## TopTutor and predicates class Q this one shares): a hidden zone is read
## only by the seat the rules let look, while the card resolves, and every
## other choice is the right seat's question with a public hint.
const MC := preload("res://cards/sets/mir/_choices.gd")
const PH := preload("res://cards/sets/mir/_phasing.gd")
const F := preload("res://cards/sets/fem/_rules.gd")

const TOLLS: Array[String] = ["Sacrifice a permanent", "Discard a card", "Lose 2 life"]


static func configure(c: CardData) -> bool:
	match c.card_name:
		"Vampiric Tutor":
			c.spell(MC.TopTutor.new("a card", Callable(), false))
			c.spell(GainLifeEffect.new(-2))   # "You lose 2 life."
		"Tithe":
			c.spell(TitheSearch.new())
		"Three Wishes":
			c.spell(ThreeWishes.new())
		"Forbidden Ritual":
			c.spell(F.Action.new(_ritual,
				"sacrifice a nontoken permanent; target opponent loses 2 life unless they sacrifice a permanent or discard a card; repeat any number of times",
				TargetSpec.opponent()))
		_:
			return false
	return true


# ==================================================================== Tithe

## "Search your library for a Plains card. If target opponent controls more
## lands than you, you may search your library for an additional Plains
## card. Reveal those cards, put them into your hand, then shuffle." The
## land counts are taken as it resolves; both finds may fail (a stated
## quality, CR 701.19b).
class TitheSearch extends SearchLibraryEffect:
	func _init() -> void:
		super("a Plains card", MC.Q.plains_card)
		target_spec = TargetSpec.opponent()

	func resolve(g: MtgGame, s: CardInstance, pid: int, t: TargetRef, _x := 0) -> void:
		var found: Array[CardInstance] = []
		var pick := _one(g, pid, found, "Tithe: search your library for a Plains card")
		if pick != null: found.append(pick)
		if t != null and t.is_player and MC.Q.land_count(g, t.player_id) > MC.Q.land_count(g, pid):
			var second := _one(g, pid, found, "Tithe: you may search your library for an additional Plains card")
			if second != null: found.append(second)
		if not found.is_empty():
			var names: Array = []
			for i in found: names.append(i.data.card_name)
			g.reveal_information(-1, "%s reveals" % s.data.card_name, names)
			for i in found: g.library_card_to_hand(i)
		g.shuffle_library(pid)

	func _one(g: MtgGame, pid: int, taken: Array[CardInstance], prompt: String) -> CardInstance:
		var cards: Array[CardInstance] = []
		for i in g.players[pid].library:
			if filter.call(i) and not taken.has(i): cards.append(i)
		var pick := g.agents[pid].choose_card(g, pid, cards, prompt, true)
		return pick if pick != null and cards.has(pick) else null

	func describe() -> String:
		return "search for a Plains card (and another if target opponent controls more lands), reveal them, put them into your hand, then shuffle"


# ============================================================= Three Wishes

## "Exile the top three cards of your library face down. You may look at
## those cards for as long as they remain exiled. Until your next turn, you
## may play those cards. At the beginning of your next upkeep, put any of
## those cards you didn't play into your graveyard." (engine E7:
## exile_top_of_library with its owner as the one viewer, grant_exile_play
## until that seat's next upkeep — no priority passes between the turn's
## beginning and its upkeep, so that is the same moment as "until your next
## turn" — and a delayed upkeep trigger naming each card by id and exile
## entry, CR 400.7). To the AI it is three cards to play: a draw of three.
class ThreeWishes extends DrawEffect:
	func _init() -> void:
		super(3)
		with_ai_role(&"impulse_exile")

	func resolve(g: MtgGame, s: CardInstance, pid: int, _t: TargetRef, _x := 0) -> void:
		var cards: Array = []
		for n in 3:
			var card := g.exile_top_of_library(pid, true, pid)
			if card == null: break
			g.grant_exile_play(card, pid, true)
			cards.append([card.id, card.exile_entry])
		if cards.is_empty(): return
		g.schedule_delayed_trigger(TriggeredAbility.new(Mtg.EventType.UPKEEP_START, _expire,
			"At the beginning of your next upkeep, put any of those cards you didn't play into your graveyard.",
			_upkeep_of.bind(pid)), pid, s, false, {"cards": cards})

	static func _upkeep_of(_g: MtgGame, _s: CardInstance, e: GameEvent, pid: int) -> bool:
		return int(e.data.get("player", -1)) == pid

	static func _expire(g: MtgGame, _s: CardInstance, _e: GameEvent) -> void:
		var memory: Dictionary = g.current_delayed().get("memory", {})
		for row in memory.get("cards", []):
			var card := g.find_instance(int(row[0]))
			if card != null and card.zone == Mtg.Zone.EXILE and card.exile_entry == int(row[1]):
				g.return_from_exile_to_graveyard(card)

	func describe() -> String:
		return "exile the top three cards of your library face down; you may play them until your next turn"


# ========================================================= Forbidden Ritual

## "Sacrifice a nontoken permanent. If you do, target opponent loses 2 life
## unless that player sacrifices a permanent of their choice or discards a
## card. You may repeat this process any number of times." The first
## sacrifice is not optional when there is one to make; every repeat is.
## The opponent picks the toll from what they can pay — their own hand and
## board, which they may see.
static func _ritual(g: MtgGame, _s: CardInstance, pid: int, t: TargetRef, _x: int) -> void:
	if t == null or not t.is_player: return
	var them := t.player_id
	var guard := 0
	while guard < 200 and not g.game_over:
		guard += 1
		var mine: Array[CardInstance] = []
		for i in g.players[pid].battlefield:
			if not i.is_token: mine.append(i)
		if mine.is_empty(): return
		var ranked := PH.H.best_first(mine)
		ranked.reverse()   # the least valuable first
		var victim := g.agents[pid].choose_card(g, pid, ranked,
			"Forbidden Ritual: choose a nontoken permanent to sacrifice", false, false, true)
		if victim == null or not ranked.has(victim): victim = ranked[0]
		g.sacrifice_permanent(victim)
		if g.is_present(victim): return   # not sacrificed: "if you do" fails
		_toll(g, them)
		if g.game_over: return
		if not g.agents[pid].choose_yes_no(g, pid,
				"Forbidden Ritual: sacrifice another nontoken permanent and repeat?", _repeat_hint(g, pid, them)):
			return


static func _toll(g: MtgGame, who: int) -> void:
	var labels: Array[String] = []
	var codes: Array[int] = []
	if not g.players[who].battlefield.is_empty():
		labels.append(TOLLS[0])
		codes.append(0)
	if not g.players[who].hand.is_empty():
		labels.append(TOLLS[1])
		codes.append(1)
	labels.append(TOLLS[2])
	codes.append(2)
	var pick := g.agents[who].choose_option(g, who, labels,
		"Forbidden Ritual: sacrifice a permanent, discard a card, or lose 2 life", codes.find(_toll_hint(g, who, codes)))
	var code := codes[clampi(pick, 0, codes.size() - 1)]
	match code:
		0:
			var ranked := PH.H.best_first(g.players[who].battlefield)
			ranked.reverse()
			var gone := g.agents[who].choose_card(g, who, ranked,
				"Forbidden Ritual: choose a permanent to sacrifice", false, false, true)
			if gone == null or not ranked.has(gone): gone = ranked[0]
			g.sacrifice_permanent(gone)
		1:
			g.discard_cards(who, g.agents[who].choose_discard(g, who, 1))
		_:
			g.adjust_life(who, -2)


## The paying seat's own view: life while it is comfortable, then a card
## from hand, then a permanent.
static func _toll_hint(g: MtgGame, who: int, codes: Array[int]) -> int:
	if g.players[who].life > 6: return 2
	if codes.has(1): return 1
	if codes.has(0): return 0
	return 2


## Repeat only when every repeat is a sure 2 life — the opponent has no
## card and no permanent to pay with — and enough of ours remain to finish.
static func _repeat_hint(g: MtgGame, pid: int, them: int) -> bool:
	if not g.players[them].hand.is_empty() or not g.players[them].battlefield.is_empty(): return false
	var fuel := 0
	for i in g.players[pid].battlefield:
		if not i.is_token: fuel += 1
	return fuel * 2 >= g.players[them].life
