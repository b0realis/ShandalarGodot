extends GameTest
## Pack 10 (the Urza block), batch B13: Multani's Presence (Pack 10 E4's
## SPELL_COUNTERED), Gilded Drake (E4's "still resolves"), Yawgmoth's Will
## and Temporal Aperture (Pack 10 E5's zone permissions).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

const CLAIMED := ["Multani's Presence", "Gilded Drake", "Yawgmoth's Will", "Temporal Aperture"]

## A seat whose yes/no answers a test scripts (-1 follows the hint).
class Seat extends DecisionAgent:
	var yes := -1
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

var me: Seat
var foe: Seat
var revealed: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	revealed = []
	g.information_revealed.connect(func(viewer: int, title: String, names: Array) -> void:
		revealed.append([viewer, title, names.duplicate()]))
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _flood(pid: int) -> void:
	for color in [W, U, B, R, G]: add_mana(pid, color, 4)

func _named_in(pid: int, card_name: String, zone: int) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = zone
	match zone:
		Mtg.Zone.HAND: g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD: g.players[pid].graveyard.append(inst)
		Mtg.Zone.LIBRARY: g.players[pid].library.append(inst)
	return inst

static func _free_row(rows: Array) -> int:
	for i in rows.size():
		if bool(Dictionary(rows[i].get("payment", {})).get("zone_free", false)):
			return i
	return -1


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------ Multani's Presence --

func _p0_cast_bears_and_p1_counters() -> CardInstance:
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	_priority(1)
	var counter := give_hand(1, "Counterspell")
	add_mana(1, U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(bear)]))
	resolve_stack()
	return bear


func test_multanis_presence_draws_when_your_spell_is_countered() -> void:
	put_battlefield(0, "Multani's Presence")
	var hand := g.players[0].hand.size()
	var bear := _p0_cast_bears_and_p1_counters()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 1)


func test_multanis_presence_ignores_the_opponents_countered_spells() -> void:
	put_battlefield(1, "Multani's Presence")
	var hand := g.players[1].hand.size()
	_p0_cast_bears_and_p1_counters()
	assert_eq(g.players[1].hand.size(), hand, "the Counterspell was given and cast: net 0")


func test_multanis_presence_does_not_draw_for_a_fizzle() -> void:
	put_battlefield(0, "Multani's Presence")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, R)
	var hand := g.players[0].hand.size()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	g.exile_permanent(bear)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand - 1, "CR 608.2b: not countered")


func test_multanis_presence_draws_for_an_unpaid_force_spike() -> void:
	put_battlefield(0, "Multani's Presence")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, G, 2)
	assert_ok(g.cast_spell(0, bear))
	var hand := g.players[0].hand.size()
	_priority(1)
	var spike := give_hand(1, "Force Spike")
	add_mana(1, U)
	assert_ok(g.cast_spell(1, spike, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 1)


# ------------------------------------------------------------ Gilded Drake --

func _cast_drake() -> CardInstance:
	var drake := give_hand(0, "Gilded Drake")
	add_mana(0, U, 2)
	assert_ok(g.cast_spell(0, drake))
	return drake


func test_gilded_drake_exchanges_itself_for_an_opposing_creature() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var drake := _cast_drake()
	resolve_stack()
	assert_eq(drake.controller_id, 1)
	assert_eq(giant.controller_id, 0)
	assert_true(drake.has_keyword(Mtg.Keyword.FLYING))


func test_gilded_drake_without_a_target_is_sacrificed() -> void:
	var drake := _cast_drake()
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)


func test_gilded_drake_whose_target_became_illegal_is_sacrificed() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var drake := _cast_drake()
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Drake resolves; its trigger is aimed
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 1)
	g.return_to_hand(giant)   # in response (setup)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD, "\"still resolves\": can't exchange, sacrificed")


func test_gilded_drake_given_away_first_is_neither_exchanged_nor_sacrificed() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var drake := _cast_drake()
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	g.change_control(drake, 1)   # in response, the opponent takes it (setup)
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "you can't sacrifice what you don't control (CR 701.17a)")
	assert_eq(drake.controller_id, 1)
	assert_eq(giant.controller_id, 1)


func test_gilded_drake_that_left_and_returned_is_a_new_object() -> void:
	var giant := put_battlefield(1, "Hill Giant")
	var drake := _cast_drake()
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.stack.size(), 1, "the first trigger, aimed at the Giant")
	g.return_to_hand(drake)
	g.put_from_hand_into_play(drake, 0)   # back, a new object (setup)
	while g.stack.size() > 1:
		g.stack.pop_back()   # the new object's own trigger is not under test
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.BATTLEFIELD, "the old trigger acts on nothing (CR 400.7)")
	assert_eq(drake.controller_id, 0)
	assert_eq(giant.controller_id, 1)


func test_gilded_drake_cannot_take_a_creature_nobody_may_gain() -> void:
	var guard := CardData.new("Test Guard", "{3}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(func(game: MtgGame, s: CardInstance) -> void:
			for inst in game.players[s.controller_id].battlefield:
				if inst.is_creature(): inst.cur_cant_change_control = true,
			"Creatures you control can't change controllers."))
	put_synthetic(1, guard)
	var giant := put_battlefield(1, "Hill Giant")
	g.recalculate()
	var drake := _cast_drake()
	resolve_stack()
	assert_eq(drake.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.controller_id, 1)


# --------------------------------------------------------- Yawgmoth's Will --

func _cast_will() -> CardInstance:
	var will := give_hand(0, "Yawgmoth's Will")
	add_mana(0, B, 3)
	assert_ok(g.cast_spell(0, will))
	resolve_stack()
	return will


func test_yawgmoths_will_exiles_itself_and_opens_the_graveyard() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	var bolt := _named_in(0, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_named_in(0, "Grizzly Bears", Mtg.Zone.GRAVEYARD)   # on top of both
	assert_false(g.can_play_from_zone(0, forest))
	var will := _cast_will()
	assert_eq(will.zone, Mtg.Zone.EXILE, "the Will is put into a graveyard this turn")
	assert_ok(g.play_land(0, forest))
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].lands_played_this_turn, 1, "the land drop")
	add_mana(0, R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "would go to your graveyard: exiled")


func test_yawgmoths_will_exiles_every_card_headed_for_your_graveyard() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_cast_will()
	g.discard_cards(0, [give_hand(0, "Lightning Bolt")])
	assert_true(g.players[0].graveyard.is_empty())
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	var theirs := give_hand(1, "Lightning Bolt")
	g.discard_cards(1, [theirs])
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")


func test_yawgmoths_will_ends_with_the_turn_after_the_cleanup_discard() -> void:
	var forest := _named_in(0, "Forest", Mtg.Zone.GRAVEYARD)
	_cast_will()
	for i in 9: give_hand(0, "Grizzly Bears")
	advance_to_next_turn()
	assert_eq(g.players[0].graveyard.size(), 1, "the cleanup discards were exiled")
	assert_false(g.can_play_from_zone(0, forest))
	var later := give_hand(0, "Lightning Bolt")
	g.discard_cards(0, [later])
	assert_eq(later.zone, Mtg.Zone.GRAVEYARD, "the replacement is over")


func test_yawgmoths_will_does_not_open_the_opponents_graveyard() -> void:
	var theirs := _named_in(1, "Lightning Bolt", Mtg.Zone.GRAVEYARD)
	_cast_will()
	add_mana(0, R)
	assert_refused(g.cast_spell(0, theirs, [TargetRef.player(1)]))


func test_a_countered_yawgmoths_will_does_nothing() -> void:
	var will := give_hand(0, "Yawgmoth's Will")
	add_mana(0, B, 3)
	assert_ok(g.cast_spell(0, will))
	_priority(1)
	var counter := give_hand(1, "Counterspell")
	add_mana(1, U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(will)]))
	resolve_stack()
	assert_eq(will.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.players[0].graveyard_cast_permissions.is_empty())


# ------------------------------------------------------- Temporal Aperture --

func _activate_aperture() -> CardInstance:
	var aperture := put_battlefield(0, "Temporal Aperture")
	add_mana(0, U, 5)
	assert_ok(g.activate_ability(0, aperture, 0))
	resolve_stack()
	return aperture


func test_temporal_aperture_reveals_the_top_card_and_lets_it_be_played_free() -> void:
	for i in 5: _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_activate_aperture()
	var top: CardInstance = g.players[0].library.back()
	# That card only, judged live (MtgPlayer.top_revealed_card_id; the
	# 0.60.19 bug pass): not the Field of Dreams flag for any top.
	assert_eq(g.players[0].top_revealed_card_id, top.id, "played with the top card revealed")
	assert_eq(g.revealed_top_card(0), top)
	var shown := false
	for row in revealed:
		if int(row[0]) == -1 and (row[2] as Array).has(top.data.card_name): shown = true
	assert_true(shown, "revealed to both players")
	assert_true(g.can_play_from_zone(0, top))
	assert_true(g.playable_cards(0).has(top))


func test_temporal_aperture_casts_a_spell_without_paying_its_mana_cost() -> void:
	g.players[0].library.clear()
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_activate_aperture()
	assert_eq(g.players[0].library.back(), bear)
	var free := _free_row(g.payment_rows(0, bear))
	assert_gt(free, 0)
	assert_string_contains(String(g.payment_rows(0, bear)[free]["label"]), "Temporal Aperture")
	add_mana(0, G, 2)
	assert_refused(g.cast_spell(0, bear, [], 0, 0), "without paying its mana cost")
	assert_ok(g.cast_spell(0, bear, [], 0, free))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.total(), 2, "nothing was paid")
	assert_null(g.revealed_top_card(0), "nothing on top any more")


func test_temporal_aperture_plays_a_land_as_the_land_drop() -> void:
	g.players[0].library.clear()
	var forest := _named_in(0, "Forest", Mtg.Zone.LIBRARY)
	_activate_aperture()
	assert_ok(g.play_land(0, forest))
	assert_eq(g.players[0].lands_played_this_turn, 1)


func test_temporal_aperture_x_is_zero() -> void:
	g.players[0].library.clear()
	var blast := _named_in(0, "Disintegrate", Mtg.Zone.LIBRARY)
	_activate_aperture()
	var free := _free_row(g.payment_rows(0, blast))
	add_mana(0, R, 5)
	assert_refused(g.cast_spell(0, blast, [TargetRef.player(1)], 2, free), "X must be 0")
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, free))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


func test_temporal_aperture_ends_when_the_card_leaves_the_top() -> void:
	g.players[0].library.clear()
	for i in 3: _named_in(0, "Forest", Mtg.Zone.LIBRARY)
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_activate_aperture()
	var top: CardInstance = g.players[0].library.back()
	g.draw_cards(0, 1)
	assert_false(g.can_play_from_zone(0, top), "drawn")
	g.put_from_hand_on_top_of_library(top)
	assert_false(g.can_play_from_zone(0, top), "put back: it did not REMAIN on top")
	assert_null(g.revealed_top_card(0), "the reveal ends with it")
	assert_not_null(bear)


func test_temporal_aperture_ends_on_a_shuffle_even_one_that_leaves_it_on_top() -> void:
	# "For as long as that card remains on top": a shuffle ends it, even one
	# that happens to put it back on top (Forge's ShuffleCheck).
	g.players[0].library.clear()
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_activate_aperture()
	assert_true(g.can_play_from_zone(0, bear))
	g.shuffle_library(0)   # a one-card library: still on top
	assert_eq(g.players[0].library.back(), bear)
	assert_false(g.can_play_from_zone(0, bear), "shuffled: it did not REMAIN on top")
	g.recalculate()   # as the resolution that shuffled it does
	assert_null(g.revealed_top_card(0), "the reveal ends with it")


func test_temporal_aperture_ends_with_the_turn() -> void:
	g.players[0].library.clear()
	var bear := _named_in(0, "Grizzly Bears", Mtg.Zone.LIBRARY)
	_activate_aperture()
	advance_to_next_turn()   # the opponent's turn: P0 draws nothing
	assert_eq(g.players[0].library.back(), bear)
	assert_false(g.can_play_from_zone(0, bear))
	assert_null(g.revealed_top_card(0))


func test_temporal_aperture_needs_five_and_a_tap() -> void:
	var aperture := put_battlefield(0, "Temporal Aperture")
	add_mana(0, U, 4)
	assert_refused(g.activate_ability(0, aperture, 0))
	add_mana(0, U, 1)
	assert_ok(g.activate_ability(0, aperture, 0))
	resolve_stack()
	add_mana(0, U, 5)
	assert_refused(g.activate_ability(0, aperture, 0), "tapped")
