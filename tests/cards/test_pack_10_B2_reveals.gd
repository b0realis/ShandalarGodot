extends GameTest
## Pack 10 (the Urza block), batch B2: the "reveal any number of <color>
## cards in your hand" cards of cards/sets/uds/_choices.gd — the five Seers
## of Urza's Destiny, the five Scents and Rofellos's Gift.
##
## The revealing seat is asked HOW MANY, then WHICH, through its own agent
## (a human seat is held on the number and on each card), only cards of the
## named color are offered, and the revealed names are shown to BOTH seats
## (viewer -1) once the reveal happens — never while the question is open.

const CLAIMED := ["Jasmine Seer", "Scent of Jasmine", "Brine Seer", "Scent of Brine",
	"Nightshade Seer", "Scent of Nightshade", "Cinder Seer", "Scent of Cinder", "Ivy Seer",
	"Rofellos's Gift", "Scent of Ivy"]


## Every information_revealed row, in order.
class Recorder:
	var rows: Array = []
	func on_reveal(viewer: int, title: String, names: Array) -> void:
		rows.append({"viewer": viewer, "title": title, "names": names.duplicate()})


## Scripted answers. A number: the next of [member numbers], else the hint.
## A card: by name from [member picks], else the first candidate. Yes/no:
## [member says]. Remembers prompts and offered cards.
class Seat extends DecisionAgent:
	var numbers: Array[int] = []
	var picks: Array[String] = []
	var says := true
	var asked: Array[String] = []
	var offered: Array[String] = []
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		if not numbers.is_empty():
			var at := options.find(str(numbers.pop_front()))
			if at >= 0: return at
		return hint
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for c in candidates: offered.append(c.data.card_name)
		while not picks.is_empty():
			var want: String = picks.pop_front()
			for c in candidates:
				if c.data.card_name == want: return c
		return null if candidates.is_empty() else candidates[0]
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return says


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _recorder() -> Recorder:
	var rec := Recorder.new()
	g.information_revealed.connect(rec.on_reveal)
	return rec

func _pay(pid: int, card_name: String) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func _cast(pid: int, card_name: String, targets: Array = []) -> CardInstance:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name)
	assert_ok(g.cast_spell(pid, card, targets))
	return card

## Activate [param seer]'s ability, paying its printed {2}{C}.
func _activate(seer: CardInstance, color: int, targets: Array = []) -> String:
	add_mana(seer.controller_id, color)
	add_mana(seer.controller_id, Mtg.ManaColor.C, 2)
	return g.activate_ability(seer.controller_id, seer, 0, targets)

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

## Both players pass once: the top of the stack resolves (or is held).
func _pass_round() -> void:
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))

func _human(pid: int) -> HumanAgent:
	var seat := HumanAgent.new()
	g.set_agent(pid, seat)
	g.interactive_choices = true
	return seat

func _release(pid: int) -> void:
	g.interactive_choices = false
	g.set_agent(pid, DecisionAgent.new())


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)

func test_the_seers_are_one_one_wizards_with_one_tap_ability() -> void:
	for card_name in ["Jasmine Seer", "Brine Seer", "Nightshade Seer", "Cinder Seer", "Ivy Seer"]:
		var c := CardRegistry.get_card(card_name)
		assert_eq(c.power, 1, card_name)
		assert_eq(c.toughness, 1, card_name)
		assert_true(c.subtypes.has("wizard"), card_name)
		assert_eq(c.activated_abilities.size(), 1, card_name)
		assert_true(c.activated_abilities[0].tap_cost, card_name)
		assert_eq(c.activated_abilities[0].cost.mana_value(), 3, card_name)


# ------------------------------------------------------------ Scent of Jasmine --

func test_scent_of_jasmine_reveals_every_white_card_by_default_and_gains_two_each() -> void:
	var rec := _recorder()
	give_hand(0, "Savannah Lions")
	give_hand(0, "Serra Angel")
	give_hand(0, "Grizzly Bears")
	_cast(0, "Scent of Jasmine")
	resolve_stack()
	assert_eq(g.players[0].life, 24)
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq(int(rec.rows[0]["viewer"]), -1, "revealed to both seats")
	var names: Array = rec.rows[0]["names"]
	names.sort()
	assert_eq(names, ["Savannah Lions", "Serra Angel"])

func test_scent_of_jasmine_may_reveal_fewer_and_offers_only_white_cards() -> void:
	var rec := _recorder()
	give_hand(0, "Savannah Lions")
	give_hand(0, "Serra Angel")
	give_hand(0, "Grizzly Bears")
	var seat := _seat(0)
	seat.numbers = [1]
	seat.picks = ["Serra Angel"]
	_cast(0, "Scent of Jasmine")
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_false(seat.offered.has("Grizzly Bears"), "only white cards may be revealed")
	assert_true(seat.offered.has("Savannah Lions"))
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq(rec.rows[0]["names"], ["Serra Angel"])

func test_scent_of_jasmine_reveals_nothing_and_asks_nothing_without_white_cards() -> void:
	var rec := _recorder()
	give_hand(0, "Grizzly Bears")
	var seat := _seat(0)
	_cast(0, "Scent of Jasmine")
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_true(seat.asked.is_empty())
	assert_true(rec.rows.is_empty())

func test_revealing_zero_is_a_legal_answer() -> void:
	var rec := _recorder()
	give_hand(0, "Serra Angel")
	var seat := _seat(0)
	seat.numbers = [0]
	_cast(0, "Scent of Jasmine")
	resolve_stack()
	assert_eq(g.players[0].life, 20)
	assert_true(rec.rows.is_empty())
	assert_eq(g.players[0].hand.size(), 1, "a revealed card stays in the hand")


# ------------------------------------------------------------ the human seat --

func test_a_human_is_held_on_the_number_then_on_each_card_and_both_seats_see_the_reveal() -> void:
	var rec := _recorder()
	var lions := give_hand(0, "Savannah Lions")
	var angel := give_hand(0, "Serra Angel")
	var bear := give_hand(0, "Grizzly Bears")
	_human(0)
	_cast(0, "Scent of Jasmine")
	_pass_round()
	var asked := g.awaiting_choice
	assert_not_null(asked, "the number is held for the human")
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["0", "1", "2"] as Array[String])
	assert_true(rec.rows.is_empty(), "nothing is revealed while the question is open")
	assert_ok(g.answer_choice(1))
	asked = g.awaiting_choice
	assert_not_null(asked, "then the card is held")
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.candidates.has(lions) and asked.candidates.has(angel))
	assert_false(asked.candidates.has(bear))
	assert_true(asked.hand_candidates.has(angel.id), "picked from the hand")
	assert_true(rec.rows.is_empty())
	assert_ok(g.answer_choice(angel.id))
	assert_null(g.awaiting_choice)
	_release(0)
	resolve_stack()
	assert_eq(g.players[0].life, 22)
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq(int(rec.rows[0]["viewer"]), -1)
	assert_eq(rec.rows[0]["names"], ["Serra Angel"])

func test_a_human_revealing_all_is_asked_only_the_number() -> void:
	give_hand(0, "Savannah Lions")
	give_hand(0, "Serra Angel")
	_human(0)
	_cast(0, "Scent of Jasmine")
	_pass_round()
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(2))
	assert_null(g.awaiting_choice, "every white card is revealed: there is no which")
	_release(0)
	resolve_stack()
	assert_eq(g.players[0].life, 24)


# --------------------------------------------------------------- Jasmine Seer --

func test_jasmine_seer_taps_to_reveal_and_gain_life() -> void:
	var seer := put_battlefield(0, "Jasmine Seer")
	give_hand(0, "Serra Angel")
	assert_ok(_activate(seer, Mtg.ManaColor.W))
	assert_true(seer.tapped)
	resolve_stack()
	assert_eq(g.players[0].life, 22)

func test_a_summoning_sick_seer_cannot_tap() -> void:
	var seer := put_battlefield(0, "Jasmine Seer", true)
	give_hand(0, "Serra Angel")
	assert_refused(_activate(seer, Mtg.ManaColor.W))
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------------- Brine Seer / Scent --

## P1 casts a Lightning Bolt at P0 and passes: P0 holds priority over it.
func _their_bolt() -> CardInstance:
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return bolt

func test_scent_of_brine_counters_a_spell_whose_controller_cannot_pay() -> void:
	give_hand(0, "Air Elemental")
	give_hand(0, "Counterspell")
	var bolt := _their_bolt()
	_cast(0, "Scent of Brine", [TargetRef.card(bolt)])
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)

func test_scent_of_brine_asks_one_per_revealed_card_and_the_spell_survives_a_payment() -> void:
	give_hand(0, "Air Elemental")
	give_hand(0, "Counterspell")
	var bolt := _their_bolt()
	add_mana(1, Mtg.ManaColor.C, 2)
	var them := _seat(1)
	_cast(0, "Scent of Brine", [TargetRef.card(bolt)])
	resolve_stack()
	assert_eq(them.asked.size(), 1, "the bolt's controller is asked to pay")
	if them.asked.size() == 1: assert_string_contains(them.asked[0], "{2}")
	assert_eq(g.players[0].life, 17, "paid {2}: the bolt resolves")
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 0)

func test_scent_of_brine_revealing_nothing_counters_nothing() -> void:
	give_hand(0, "Grizzly Bears")
	var bolt := _their_bolt()
	_cast(0, "Scent of Brine", [TargetRef.card(bolt)])
	resolve_stack()
	assert_eq(g.players[0].life, 17, "unless its controller pays {0}")

func test_brine_seer_targets_a_spell_as_it_is_activated() -> void:
	var seer := put_battlefield(0, "Brine Seer")
	give_hand(0, "Air Elemental")
	assert_refused(_activate(seer, Mtg.ManaColor.U, [TargetRef.player(1)]))
	var bolt := _their_bolt()
	assert_ok(_activate(seer, Mtg.ManaColor.U, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------- Nightshade Seer / Scent --

func test_scent_of_nightshade_shrinks_by_the_black_cards_revealed() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	give_hand(0, "Dark Ritual")
	give_hand(0, "Bad Moon")
	give_hand(0, "Lightning Bolt")
	_cast(0, "Scent of Nightshade", [TargetRef.card(giant)])
	resolve_stack()
	assert_eq(giant.cur_power, 1)
	assert_eq(giant.cur_toughness, 1)
	advance_to_next_turn()
	assert_eq(giant.cur_toughness, 3, "until end of turn")

func test_nightshade_seer_kills_with_enough_black_cards() -> void:
	var seer := put_battlefield(0, "Nightshade Seer")
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Dark Ritual")
	give_hand(0, "Bad Moon")
	assert_ok(_activate(seer, Mtg.ManaColor.B, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------- Cinder Seer / Scent --

func test_scent_of_cinder_deals_one_per_red_card_to_any_target() -> void:
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Hill Giant")
	give_hand(0, "Serra Angel")
	_cast(0, "Scent of Cinder", [TargetRef.player(1)])
	resolve_stack()
	assert_eq(g.players[1].life, 18)

func test_scent_of_cinder_is_a_sorcery() -> void:
	give_hand(0, "Lightning Bolt")
	var bolt := _their_bolt()
	var scent := give_hand(0, "Scent of Cinder")
	_pay(0, "Scent of Cinder")
	assert_refused(g.cast_spell(0, scent, [TargetRef.player(1)]))
	assert_eq(bolt.zone, Mtg.Zone.STACK)

func test_cinder_seer_is_the_source_of_its_damage() -> void:
	var seer := put_battlefield(0, "Cinder Seer")
	var bear := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Hill Giant")
	assert_ok(_activate(seer, Mtg.ManaColor.R, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	var line := ""
	for l in g.log_lines:
		if l.contains("Cinder Seer") and l.contains("damage"): line = l
	assert_ne(line, "", "the Seer deals the damage")


# ---------------------------------------------------------- Ivy Seer / Scent --

func test_scent_of_ivy_pumps_by_the_green_cards_revealed() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")
	give_hand(0, "Llanowar Elves")
	give_hand(0, "Lightning Bolt")
	_cast(0, "Scent of Ivy", [TargetRef.card(bear)])
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	assert_eq(bear.cur_toughness, 4)

func test_ivy_seer_pumps_target_creature() -> void:
	var seer := put_battlefield(0, "Ivy Seer")
	var bear := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")
	assert_ok(_activate(seer, Mtg.ManaColor.G, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 3)


# ------------------------------------------------------------ Rofellos's Gift --

func test_rofellos_s_gift_returns_one_enchantment_card_per_green_card() -> void:
	var growth := _grave(0, "Wild Growth")
	var crusade := _grave(0, "Crusade")
	var moon := _grave(0, "Bad Moon")
	var bear := _grave(0, "Grizzly Bears")
	give_hand(0, "Giant Growth")
	give_hand(0, "Llanowar Elves")
	var seat := _seat(0)
	seat.picks = ["Bad Moon", "Wild Growth"]
	_cast(0, "Rofellos's Gift")
	resolve_stack()
	assert_eq(moon.zone, Mtg.Zone.HAND)
	assert_eq(growth.zone, Mtg.Zone.HAND)
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_false(seat.offered.has("Grizzly Bears"), "enchantment cards only")

func test_rofellos_s_gift_hint_reveals_no_more_than_it_can_return() -> void:
	var rec := _recorder()
	var crusade := _grave(0, "Crusade")
	give_hand(0, "Giant Growth")
	give_hand(0, "Llanowar Elves")
	give_hand(0, "Craw Wurm")
	_cast(0, "Rofellos's Gift")
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.HAND)
	assert_eq(rec.rows.size(), 1)
	if rec.rows.is_empty(): return
	assert_eq((rec.rows[0]["names"] as Array).size(), 1, "one enchantment card: one green card shown")

func test_a_human_casting_rofellos_s_gift_chooses_the_number_the_card_and_the_enchantment() -> void:
	var crusade := _grave(0, "Crusade")
	var moon := _grave(0, "Bad Moon")
	var elves := give_hand(0, "Llanowar Elves")
	give_hand(0, "Giant Growth")
	_human(0)
	_cast(0, "Rofellos's Gift")
	_pass_round()
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(1))
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(elves.id))
	var asked := g.awaiting_choice
	assert_not_null(asked, "then which enchantment card comes back")
	if asked == null: return
	assert_true(asked.candidates.has(crusade) and asked.candidates.has(moon))
	assert_ok(g.answer_choice(crusade.id))
	assert_null(g.awaiting_choice)
	_release(0)
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.HAND)
	assert_eq(moon.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------- fair play --

## The count the heuristic reveals reads the revealing seat's own hand and
## the public board only: the opponent's hidden hand does not move it.
func test_the_reveal_hint_does_not_read_the_opponents_hand() -> void:
	var lives: Array[int] = []
	for their in [["Lightning Bolt"], ["Shivan Dragon", "Fireball", "Hill Giant"]]:
		before_each()
		for card_name in their: give_hand(1, card_name)
		give_hand(0, "Hill Giant")
		give_hand(0, "Lightning Bolt")
		_cast(0, "Scent of Cinder", [TargetRef.player(1)])
		resolve_stack()
		lives.append(g.players[1].life)
	assert_eq(lives, [18, 18] as Array[int])
