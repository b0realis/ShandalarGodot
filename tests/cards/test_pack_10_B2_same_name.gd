extends GameTest
## Pack 10 (the Urza block), batch B2: the same-name exile family of
## cards/sets/uds/_spells.gd — Scour, Quash, Eradicate, Sowing Salt and
## Splinter.
##
## The target goes first (exiled, or countered for Quash), then every card
## with its name is exiled from its controller's graveyard (public: every
## copy), hand and library — a searched hidden zone may fail to find (CR
## 701.19b), so the searcher answers how many of the copies in the hand,
## then in the library, it exiles, and sees the hand it searches. Then that
## player shuffles.

const CLAIMED := ["Scour", "Quash", "Eradicate", "Sowing Salt", "Splinter"]


class Recorder:
	var rows: Array = []
	func on_reveal(viewer: int, title: String, names: Array) -> void:
		rows.append({"viewer": viewer, "title": title, "names": names.duplicate()})


## Scripted numbers (the next of [member numbers], else the hint);
## remembers the prompts.
class Seat extends DecisionAgent:
	var numbers: Array[int] = []
	var asked: Array[String] = []
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		if not numbers.is_empty():
			var at := options.find(str(numbers.pop_front()))
			if at >= 0: return at
		return hint


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

func _pay(pid: int, card_name: String) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic)

func _try(pid: int, card_name: String, targets: Array = []) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name)
	return g.cast_spell(pid, card, targets)

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

## A fresh card in [param pid]'s library, [param depth] cards under the top.
func _in_library(pid: int, card_name: String, depth := 5) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.LIBRARY
	var library := g.players[pid].library
	library.insert(maxi(0, library.size() - depth), inst)
	return inst

func _count(cards: Array, card_name: String) -> int:
	var n := 0
	for c in cards:
		if c.data.card_name == card_name: n += 1
	return n

## [param card_name] on P1's battlefield, and one copy each in P1's
## graveyard, hand and library: [battlefield, graveyard, hand, library].
func _four_copies(card_name: String) -> Array:
	return [put_battlefield(1, card_name), _grave(1, card_name), give_hand(1, card_name),
		_in_library(1, card_name)]

func _all_exiled(cards: Array) -> void:
	for c in cards:
		assert_eq(c.zone, Mtg.Zone.EXILE, "%s (%d) is exiled" % [c.data.card_name, c.id])


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# -------------------------------------------------------------------- Scour --

func test_scour_exiles_the_enchantment_and_every_copy_its_controller_owns() -> void:
	var copies := _four_copies("Crusade")
	var other := give_hand(1, "Bad Moon")
	var library := g.players[1].library.size()
	assert_ok(_try(0, "Scour", [TargetRef.card(copies[0])]))
	resolve_stack()
	_all_exiled(copies)
	assert_eq(other.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].library.size(), library - 1)
	assert_eq(_count(g.players[1].library, "Crusade"), 0)

func test_scour_targets_only_an_enchantment() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Scour", [TargetRef.card(bear)]))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_the_searcher_may_fail_to_find_in_the_hand_and_library_but_not_the_graveyard() -> void:
	var copies := _four_copies("Crusade")
	var seat := _seat(0)
	seat.numbers = [0, 0]
	assert_ok(_try(0, "Scour", [TargetRef.card(copies[0])]))
	resolve_stack()
	assert_eq(copies[0].zone, Mtg.Zone.EXILE)
	assert_eq(copies[1].zone, Mtg.Zone.EXILE, "the graveyard is public: every copy goes")
	assert_eq(copies[2].zone, Mtg.Zone.HAND)
	assert_eq(copies[3].zone, Mtg.Zone.LIBRARY)
	assert_eq(seat.asked.size(), 2, "one count for the hand, one for the library")

func test_an_empty_hidden_zone_asks_nothing() -> void:
	var crusade := put_battlefield(1, "Crusade")
	var seat := _seat(0)
	assert_ok(_try(0, "Scour", [TargetRef.card(crusade)]))
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.EXILE)
	assert_true(seat.asked.is_empty())

func test_scour_follows_the_enchantments_controller_and_its_hint_spares_the_searchers_own() -> void:
	var mine := put_battlefield(0, "Crusade")
	var in_hand := give_hand(0, "Crusade")
	var theirs := give_hand(1, "Crusade")
	assert_ok(_try(0, "Scour", [TargetRef.card(mine)]))
	resolve_stack()
	assert_eq(mine.zone, Mtg.Zone.EXILE)
	assert_eq(in_hand.zone, Mtg.Zone.HAND, "the caster's own copies: the hint keeps them")
	assert_eq(theirs.zone, Mtg.Zone.HAND, "the other player's cards are not searched")

func test_a_human_searcher_is_held_on_each_count_and_sees_the_hand_it_searches() -> void:
	var copies := _four_copies("Crusade")
	give_hand(1, "Hill Giant")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	assert_ok(_try(0, "Scour", [TargetRef.card(copies[0])]))
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	var asked := g.awaiting_choice
	assert_not_null(asked, "the hand's count is held")
	if asked == null: return
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.options, ["0", "1"] as Array[String])
	var seen := false
	for row in asked.information:
		if int(row.get("viewer", -2)) == 0 and (row.get("cards", []) as Array).has("Hill Giant"):
			seen = true
	assert_true(seen, "the searcher looks at the hand it searches, and only the searcher")
	assert_ok(g.answer_choice(1))
	assert_not_null(g.awaiting_choice, "then the library's count")
	if g.awaiting_choice == null: return
	assert_ok(g.answer_choice(0))
	assert_null(g.awaiting_choice)
	g.interactive_choices = false
	g.set_agent(0, DecisionAgent.new())
	resolve_stack()
	assert_eq(copies[2].zone, Mtg.Zone.EXILE)
	assert_eq(copies[3].zone, Mtg.Zone.LIBRARY)


# -------------------------------------------------------------------- Quash --

## P1 casts a Lightning Bolt at P0 and passes: P0 holds priority over it.
func _their_bolt() -> CardInstance:
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return bolt

func test_quash_counters_and_exiles_the_countered_card_with_every_copy() -> void:
	var grave := _grave(1, "Lightning Bolt")
	var hand := give_hand(1, "Lightning Bolt")
	var deep := _in_library(1, "Lightning Bolt")
	var bolt := _their_bolt()
	assert_ok(_try(0, "Quash", [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "countered")
	_all_exiled([bolt, grave, hand, deep])

func test_quash_targets_only_an_instant_or_sorcery_spell() -> void:
	var bears := give_hand(0, "Grizzly Bears")
	_pay(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, bears))
	assert_refused(_try(0, "Quash", [TargetRef.card(bears)]))
	assert_eq(bears.zone, Mtg.Zone.STACK)


# ---------------------------------------------------------------- Eradicate --

func test_eradicate_exiles_a_nonblack_creature_and_its_namesakes() -> void:
	var copies := _four_copies("Grizzly Bears")
	assert_ok(_try(0, "Eradicate", [TargetRef.card(copies[0])]))
	resolve_stack()
	_all_exiled(copies)

func test_eradicate_cannot_target_a_black_creature() -> void:
	var knight := put_battlefield(1, "Black Knight")
	assert_refused(_try(0, "Eradicate", [TargetRef.card(knight)]))
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- Sowing Salt --

func test_sowing_salt_exiles_a_nonbasic_land_and_its_namesakes() -> void:
	var copies := _four_copies("City of Brass")
	assert_ok(_try(0, "Sowing Salt", [TargetRef.card(copies[0])]))
	resolve_stack()
	_all_exiled(copies)

func test_sowing_salt_cannot_target_a_basic_land() -> void:
	var forest := put_battlefield(1, "Forest")
	assert_refused(_try(0, "Sowing Salt", [TargetRef.card(forest)]))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------------------------------------- Splinter --

func test_splinter_exiles_an_artifact_and_its_namesakes() -> void:
	var copies := _four_copies("Sol Ring")
	assert_ok(_try(0, "Splinter", [TargetRef.card(copies[0])]))
	resolve_stack()
	_all_exiled(copies)

func test_splinter_targets_only_an_artifact() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Splinter", [TargetRef.card(bear)]))
