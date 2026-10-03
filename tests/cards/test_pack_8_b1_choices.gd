extends GameTest
## Pack 8, batch B1: the Mirage block's hidden-zone and resolution-time
## choices (cards/sets/mir|vis|wth/_choices.gd) — the four to-the-top
## tutors, Rampant Growth, Tithe, Natural Balance, Doomsday and Three
## Wishes read only the searching seat's own library (or its own face-down
## exile); Illicit Auction, Forbidden Ritual and Tariff ask each seat its
## own question in turn. Driven through the cast API with scripted seats
## that record what they were offered.


class Scripted extends DecisionAgent:
	var options: Array = []
	var answers: Array = []
	var picks: Array = []
	var asked: Array[String] = []
	var seen: Array = []   # the candidate names of every card question

	func answer_option(_g: MtgGame, _p: int, prompt: String,
			labels: Array[String], hint: int) -> int:
		asked.append(prompt)
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower().contains(String(want).to_lower()):
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		var names: Array = []
		for c in candidates: names.append(c.data.card_name)
		seen.append(names)
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		if want == null:
			return null
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]


var p0: Scripted
var p1: Scripted
var reveals: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	p0 = seat(0)
	p1 = seat(1)
	reveals = []
	g.information_revealed.connect(func(viewer: int, title: String, names: Array) -> void:
		reveals.append([viewer, title, names]))
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


func fund(pid: int, card: CardInstance) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)


func cast(name: String, targets: Array = [], pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card


func on_top(pid: int, name: String) -> CardInstance:
	var inst := give_hand(pid, name)
	g.put_from_hand_on_top_of_library(inst)
	return inst


func bury(pid: int, name: String) -> CardInstance:
	var inst := put_battlefield(pid, name)
	g.destroy(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst


func lands_of(pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_land(): n += 1
	return n


func public_reveals() -> Array:
	return reveals.filter(func(r: Array) -> bool: return int(r[0]) == -1)


# ------------------------------------------------------------------ tutors --

func test_enlightened_tutor_puts_a_revealed_artifact_or_enchantment_on_top() -> void:
	on_top(0, "Grizzly Bears")
	var ring := on_top(0, "Sol Ring")
	on_top(0, "Holy Strength")
	on_top(0, "Lightning Bolt")
	p0.picks = ["Sol Ring"]
	cast("Enlightened Tutor")
	assert_eq(g.players[0].library.back(), ring, "shuffled, then put on top")
	assert_true(p0.seen[0].has("Holy Strength"))
	assert_false(p0.seen[0].has("Grizzly Bears"), "only artifact or enchantment cards")
	assert_false(p0.seen[0].has("Lightning Bolt"))
	assert_eq(public_reveals().size(), 1)
	assert_eq(public_reveals()[0][2], ["Sol Ring"], "revealed to both players")


func test_mystical_tutor_finds_an_instant_or_sorcery() -> void:
	on_top(0, "Grizzly Bears")
	var wrath := on_top(0, "Wrath of God")
	on_top(0, "Lightning Bolt")
	p0.picks = ["Wrath of God"]
	cast("Mystical Tutor")
	assert_eq(g.players[0].library.back(), wrath)
	assert_true(p0.seen[0].has("Lightning Bolt"))
	assert_false(p0.seen[0].has("Grizzly Bears"))


func test_worldly_tutor_finds_a_creature_or_fails_to_find() -> void:
	var bear := on_top(0, "Grizzly Bears")
	on_top(0, "Lightning Bolt")
	var size := g.players[0].library.size()
	p0.picks = [null]
	cast("Worldly Tutor")
	assert_eq(g.players[0].library.size(), size, "a search with a stated quality may fail to find")
	assert_eq(public_reveals().size(), 0)
	p0.picks = ["Grizzly Bears"]
	cast("Worldly Tutor")
	assert_eq(g.players[0].library.back(), bear)
	assert_eq(p0.seen[1], ["Grizzly Bears"], "only creature cards")


func test_vampiric_tutor_finds_any_card_privately_and_costs_two_life() -> void:
	var bolt := on_top(0, "Lightning Bolt")
	on_top(0, "Grizzly Bears")
	p0.picks = ["Lightning Bolt"]
	cast("Vampiric Tutor")
	assert_eq(g.players[0].library.back(), bolt)
	assert_eq(g.players[0].life, 18, "You lose 2 life")
	assert_eq(public_reveals().size(), 0, "not revealed")


func test_vampiric_tutor_must_find_a_card() -> void:
	p0.picks = [null]
	var bottom: CardInstance = g.players[0].library[0]
	var size := g.players[0].library.size()
	cast("Vampiric Tutor")
	assert_eq(g.players[0].library.back(), bottom, "\"a card\" has no stated quality: it must be found (CR 701.19b)")
	assert_eq(g.players[0].library.size(), size)


# ---------------------------------------------------------- Rampant Growth --

func test_rampant_growth_puts_a_basic_land_onto_the_battlefield_tapped() -> void:
	var island := on_top(0, "Island")
	on_top(0, "Teferi's Isle")
	p0.picks = ["Island"]
	cast("Rampant Growth")
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(island.tapped, "onto the battlefield tapped")
	assert_false(p0.seen[0].has("Teferi's Isle"), "basic land cards only")
	assert_true(p0.seen[0].has("Forest"))


# ---------------------------------------------------------- Illicit Auction --

func test_illicit_auction_high_bidder_pays_and_takes_the_creature() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	p1.options = [3, 0]   # P1 bids 3; later passes
	p0.options = [1]      # P0 tops it by one: 4
	cast("Illicit Auction", [TargetRef.card(angel)])
	assert_eq(angel.controller_id, 0, "the high bidder gains control")
	assert_eq(g.players[0].life, 16, "and loses life equal to the high bid")
	assert_eq(g.players[1].life, 20, "the outbid player pays nothing")
	advance_to_next_turn()
	assert_eq(angel.controller_id, 0, "indefinitely")


func test_illicit_auction_unopposed_opening_bid_of_zero_wins() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	p1.options = [0]
	cast("Illicit Auction", [TargetRef.card(angel)])
	assert_eq(angel.controller_id, 0)
	assert_eq(g.players[0].life, 20)


func test_illicit_auction_outbid_caster_gets_nothing() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	p1.options = [2]
	p0.options = [0]
	cast("Illicit Auction", [TargetRef.card(angel)])
	assert_eq(angel.controller_id, 1)
	assert_eq(g.players[1].life, 18, "the defender paid to keep it")
	assert_eq(g.players[0].life, 20)


func test_illicit_auction_offers_bids_up_to_all_of_the_bidders_life() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	g.adjust_life(1, -17)   # P1 at 3
	p1.options = [3, 0]     # 3: all of it
	p0.options = [0]
	cast("Illicit Auction", [TargetRef.card(angel)])
	assert_eq(g.players[1].life, 0)
	assert_true(g.players[1].has_lost or g.game_over)


# ---------------------------------------------------------- Natural Balance --

func test_natural_balance_trims_to_five_and_fills_to_five() -> void:
	for i in 7: put_battlefield(0, "Plains" if i % 2 == 0 else "Island")
	for i in 3: put_battlefield(1, "Mountain")
	cast("Natural Balance")
	assert_eq(lands_of(0), 5, "six or more: keep five, sacrifice the rest")
	assert_eq(g.players[0].graveyard.size(), 3, "the two lands and the spell")
	assert_eq(lands_of(1), 5, "four or fewer: search for five minus that many basics")
	for i in g.players[1].battlefield:
		if i.data.card_name == "Forest": assert_false(i.tapped, "they enter untapped")


func test_natural_balance_leaves_five_alone_and_the_search_may_be_declined() -> void:
	for i in 5: put_battlefield(0, "Plains")
	for i in 2: put_battlefield(1, "Mountain")
	p1.answers = [false]
	var size := g.players[0].library.size()
	cast("Natural Balance")
	assert_eq(lands_of(0), 5)
	assert_eq(g.players[0].library.size(), size, "a player with five neither sacrifices nor searches")
	assert_eq(lands_of(1), 2, "may search")


# ----------------------------------------------------------------- Tithe --

func test_tithe_finds_two_plains_when_the_opponent_has_more_lands() -> void:
	on_top(0, "Plains")
	on_top(0, "Plains")
	put_battlefield(1, "Forest")
	cast("Tithe", [TargetRef.player(1)])
	var plains := g.players[0].hand.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Plains")
	assert_eq(plains.size(), 2)
	assert_eq(public_reveals().size(), 1)
	assert_eq(public_reveals()[0][2], ["Plains", "Plains"])


func test_tithe_finds_one_plains_on_equal_lands() -> void:
	on_top(0, "Plains")
	on_top(0, "Plains")
	put_battlefield(1, "Forest")
	put_battlefield(0, "Forest")
	cast("Tithe", [TargetRef.player(1)])
	assert_eq(g.players[0].hand.size(), 1)
	assert_false(p0.seen[0].has("Forest"), "Plains cards only")


# ----------------------------------------------------------- Three Wishes --

func test_three_wishes_exiles_three_face_down_for_its_owner_alone() -> void:
	var land := on_top(0, "Mountain")
	var bolt := on_top(0, "Lightning Bolt")
	var bear := on_top(0, "Grizzly Bears")
	cast("Three Wishes")
	for card in [land, bolt, bear]:
		assert_eq(card.zone, Mtg.Zone.EXILE)
		assert_true(card.face_down)
		assert_true(g.can_play_from_exile(0, card), "you may play those cards")
		assert_false(g.can_play_from_exile(1, card), "the opponent can neither see nor play them")
	assert_ok(g.play_land(0, land))
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()   # P1's turn: an instant still may be cast
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(1))
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	advance_to_next_turn()   # P0's upkeep: what wasn't played goes to the graveyard
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_false(bear.face_down)


func test_three_wishes_permission_ends_at_the_next_upkeep() -> void:
	var bear := on_top(0, "Grizzly Bears")
	cast("Three Wishes")
	advance_to_next_turn()
	assert_true(g.can_play_from_exile(0, bear))
	advance_to_next_turn()
	assert_false(g.can_play_from_exile(0, bear))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------- Forbidden Ritual --

func test_forbidden_ritual_repeats_with_the_opponent_choosing_each_toll() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var forest := put_battlefield(0, "Forest")
	var token: CardInstance = g.create_token(0, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	put_battlefield(1, "Hill Giant")
	var kept := give_hand(1, "Lightning Bolt")
	p0.picks = ["Grizzly Bears", "Forest"]
	p0.answers = [true]
	p1.options = ["Lose 2", "Discard"]
	cast("Forbidden Ritual", [TargetRef.player(1)])
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(token.zone, Mtg.Zone.BATTLEFIELD, "a token is not a nontoken permanent")
	assert_false(p0.seen[0].has("Saproling"))
	assert_eq(g.players[1].life, 18, "the first toll: 2 life")
	assert_eq(kept.zone, Mtg.Zone.GRAVEYARD, "the second: a discard")
	assert_eq(p0.answers.size(), 0)
	assert_eq(p0.asked.filter(func(q: String) -> bool: return q.contains("repeat")).size(), 2,
		"asked after each round; the second answer (the hint) stops it")


func test_forbidden_ritual_opponent_may_sacrifice_instead() -> void:
	put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	p1.options = ["Sacrifice"]
	p1.picks = ["Hill Giant"]
	cast("Forbidden Ritual", [TargetRef.player(1)])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


func test_forbidden_ritual_with_nothing_to_sacrifice_does_nothing() -> void:
	cast("Forbidden Ritual", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 20)
	assert_true(p1.asked.is_empty())


# ----------------------------------------------------------------- Tariff --

func test_tariff_each_player_pays_or_sacrifices_their_biggest_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var angel := put_battlefield(0, "Serra Angel")
	var giants := [put_battlefield(1, "Hill Giant"), put_battlefield(1, "Hill Giant")]
	for i in 4: put_battlefield(1, "Mountain")
	p1.picks = [giants[1]]
	p1.answers = [true]
	cast("Tariff")
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD, "P0 couldn't pay {3}{W}{W}")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "only the greatest mana value")
	assert_eq(giants[0].zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giants[1].zone, Mtg.Zone.BATTLEFIELD, "paid {3}{R}")
	assert_true(p1.asked.any(func(q: String) -> bool: return q.contains("tied")), "a tie is its controller's choice")


func test_tariff_declined_payment_sacrifices_the_chosen_tied_creature() -> void:
	var giants := [put_battlefield(1, "Hill Giant"), put_battlefield(1, "Hill Giant")]
	for i in 4: put_battlefield(1, "Mountain")
	p1.picks = [giants[1]]
	p1.answers = [false]
	cast("Tariff")
	assert_eq(giants[1].zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giants[0].zone, Mtg.Zone.BATTLEFIELD)


func test_tariff_a_token_has_no_mana_cost_to_pay() -> void:
	var token: CardInstance = g.create_token(1, CardData.new("Saproling", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	cast("Tariff")
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD, "unpayable (CR 118.6): sacrificed")
	assert_true(p1.asked.is_empty(), "never offered")


# --------------------------------------------------------------- Doomsday --

func test_doomsday_builds_a_five_card_library_and_exiles_the_rest() -> void:
	var angel := bury(0, "Serra Angel")
	var bolt := on_top(0, "Lightning Bolt")
	var bear := on_top(0, "Grizzly Bears")
	var pool := g.players[0].library.size() + g.players[0].graveyard.size()
	p0.picks = ["Serra Angel", "Lightning Bolt", "Grizzly Bears", "Forest", "Forest",
		"Lightning Bolt", "Serra Angel"]   # the five, then the top two in order
	cast("Doomsday")
	var library := g.players[0].library
	assert_eq(library.size(), 5)
	assert_eq(library.back(), bolt, "the first one ordered is the top card")
	assert_eq(library[library.size() - 2], angel)
	assert_true(library.has(bear))
	assert_eq(angel.zone, Mtg.Zone.LIBRARY, "graveyard cards may be chosen")
	assert_eq(g.players[0].graveyard.size(), 1, "only Doomsday itself")
	assert_eq(g.players[0].exile.size(), pool - 5, "the rest of both zones")
	assert_eq(g.players[0].life, 10, "half your life, rounded up")


func test_doomsday_rounds_the_life_loss_up_and_takes_what_there_is() -> void:
	g.adjust_life(0, -5)   # 15
	cast("Doomsday")
	assert_eq(g.players[0].life, 7, "lose 8")
	assert_eq(g.players[0].library.size(), 5)
