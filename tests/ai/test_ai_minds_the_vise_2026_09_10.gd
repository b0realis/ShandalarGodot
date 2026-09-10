extends GameTest
## THE HAND UNDER A SQUEEZE AND THE BOARD UNDER A PRISON (2026-09-10,
## [member AiProfile.minds_the_vise]; `docs/forge/casting.md` P4,
## `docs/arzakon.strategy` §4 items 2 and 3).
##
## Reproduced at HEAD before a line was written, a Wizard in seat 0 with a
## Black Vise across the table:
##
##     our hand 7, their Black Vise squeezes for 3 a turn
##       _draw_need(7)        = -3.00      _hand_room(MAIN) = 2
##     our hand 5, their Black Vise squeezes for 1 a turn
##       the Jayemdae Tome's tick is OFFERED, at 2.50
##     their Black Vise + their Jayemdae Tome, one Disenchant in hand
##       _victim_value(Black Vise) = 1.00   _victim_value(Tome) = 4.20
##       _best_victim -> Jayemdae Tome
##     their Moat, our two Craw Wurms
##       _victim_value(Moat) = 3.20 -> the Disenchant takes the Tome again
##
## So the three damage a turn reached no decision at all, and neither did
## the twelve power the Moat was holding at home.
##
## THE NOTE'S RACK CLAUSE DOES NOT ADD UP, and that is recorded here
## rather than argued. `docs/forge/casting.md` P4 ends *"The Rack shares
## (a)-(c) with the threshold at three"*, but The Rack's X is THREE MINUS
## the hand: at a hand of seven the Vise deals 3 and the Rack deals 0, and
## at a hand of nothing the Vise deals 0 and the Rack deals 3. Emptying a
## hand under a Rack is the worst play at the table, so the reading is the
## SLOPE and not a threshold, and `test_the_rack_is_the_other_slope` is
## that subtraction.
##
## Every behaviour below is pinned with the knob ON and with it OFF, and
## the OFF arm is the pilot as it was.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.minds_the_vise = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.minds_the_vise = false
	return profile


func _fill_hand(pid: int, count: int) -> void:
	for i in count:
		give_hand(pid, "Forest")


## What the one Disenchant in hand would destroy.
func _disenchant_pick(ai: AiPlayer) -> String:
	var dis := give_hand(0, "Disenchant")
	var intent := EffectIntent.read(dis.data.spell_effects, dis.data.card_name)
	var victim := ai._best_victim(g, dis, intent, 0)
	return "" if victim == null else victim.data.card_name


# ----------------------------------------------------- the printed reading --

func test_the_pool_holds_exactly_three_hand_tolls() -> void:
	# The census that says what the reading covers, the way
	# `test_ai_wheels_2026_09_10.gd` says what the wheel field covers.
	var found: Array = []
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		for trig in data.triggered_abilities:
			if not EffectIntent.hand_toll_of_line(trig.text).is_empty():
				found.append(card_name)
	found.sort()
	assert_eq(found, ["Black Vise", "Storm World", "The Rack"],
		"the whole of the shape in this pool")


func test_the_vise_and_the_rack_point_opposite_ways() -> void:
	var vise := EffectIntent.hand_toll_of_line(
		"At the beginning of the chosen player's upkeep, Black Vise deals X "
		+ "damage to that player, where X is the number of cards in their hand minus 4.")
	assert_eq(vise, {"slope": 1, "threshold": 4})
	var rack := EffectIntent.hand_toll_of_line(
		"At the beginning of the chosen player's upkeep, The Rack deals X "
		+ "damage to that player, where X is 3 minus the number of cards in their hand.")
	assert_eq(rack, {"slope": -1, "threshold": 3})
	assert_eq(EffectIntent.hand_toll_damage(vise, 7), 3, "a full hand is the Vise's meal")
	assert_eq(EffectIntent.hand_toll_damage(vise, 0), 0)
	assert_eq(EffectIntent.hand_toll_damage(rack, 7), 0)
	assert_eq(EffectIntent.hand_toll_damage(rack, 0), 3, "an empty hand is the Rack's")


func test_a_discard_that_never_deals_damage_is_not_a_toll() -> void:
	# Nicol Bolas is the pool's other trigger that names a hand.
	assert_true(EffectIntent.hand_toll_of_line(
		"Whenever Nicol Bolas deals damage to an opponent, that player "
		+ "discards their hand.").is_empty())


# ---------------------------------------------------------------- the room --

func test_the_room_stops_at_the_vise_threshold() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Black Vise")
	_fill_hand(0, 7)
	assert_eq(ai._vise_room(g), 0, "every card is already being counted")
	assert_eq(ai._hand_room(g, AiPlayer.Moment.MAIN), 0, "so nothing is drawn into it")


func test_off_the_room_is_the_hand_size_alone() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "Black Vise")
	_fill_hand(0, 7)
	assert_eq(ai._hand_room(g, AiPlayer.Moment.MAIN), 2,
		"7 + 2 - 7: the maximum hand size and its allowance, the Vise unread")


func test_the_room_below_the_threshold_is_free() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Black Vise")
	_fill_hand(0, 2)
	assert_eq(ai._vise_room(g), 2, "two more cards before the Vise charges for one")


func test_the_tome_does_not_tick_under_a_vise() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Black Vise")
	var tome := put_battlefield(0, "Jayemdae Tome")
	for i in 8:
		put_battlefield(0, "Island")
	_fill_hand(0, 5)
	assert_true(ai._ability_option(g, tome, 0, AiPlayer.Moment.SINK).is_empty(),
		"a card drawn here is a point of damage at our own upkeep")


func test_off_the_tome_ticks_into_the_squeeze() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "Black Vise")
	var tome := put_battlefield(0, "Jayemdae Tome")
	for i in 8:
		put_battlefield(0, "Island")
	_fill_hand(0, 5)
	assert_false(ai._ability_option(g, tome, 0, AiPlayer.Moment.SINK).is_empty(),
		"offered, because _draw_need returns exactly 0.00 at a hand of five")


func test_a_board_with_no_toll_leaves_the_room_alone() -> void:
	# THE NULL: with the knob ON and no such permanent anywhere, every
	# number is the number it was.
	var on := _ai(_on())
	_fill_hand(0, 5)
	assert_eq(on._vise_room(g), 1 << 20)
	assert_eq(on._hand_room(g, AiPlayer.Moment.MAIN),
		AiPlayer.new(0, _off())._hand_room(g, AiPlayer.Moment.MAIN),
		"7 + 2 - 5 on both arms")


# -------------------------------------------------------------- the relief --

func test_a_cast_is_worth_the_point_it_takes_off_the_upkeep() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "Black Vise")
	for i in 4:
		put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	_fill_hand(0, 5)
	# Half a point per point of life at twenty (AiPlayer._life_price).
	assert_almost_eq(ai._cast_value(g, bears, [], 0), 4.5, 0.001,
		"the printed 4.00 and the point the Vise no longer deals")


func test_off_the_cast_is_the_printed_card() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "Black Vise")
	for i in 4:
		put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	_fill_hand(0, 5)
	assert_almost_eq(ai._cast_value(g, bears, [], 0), 4.0, 0.001)


func test_the_rack_is_the_other_slope() -> void:
	# The note's own clause, with the subtraction done: under a Rack the
	# cast is CHARGED, not credited.
	var ai := _ai(_on())
	put_battlefield(1, "The Rack")
	for i in 4:
		put_battlefield(0, "Forest")
	var bears := give_hand(0, "Grizzly Bears")
	assert_almost_eq(ai._cast_value(g, bears, [], 0), 3.5, 0.001,
		"emptying the last card of the hand hands the Rack a point")


func test_the_rack_never_shortens_the_room() -> void:
	# One-directional: this reading may refuse a draw and can never demand
	# one, so a card whose damage FALLS as the hand fills leaves the room
	# where it found it.
	var ai := _ai(_on())
	put_battlefield(1, "The Rack")
	_fill_hand(0, 2)
	assert_eq(ai._hand_room(g, AiPlayer.Moment.MAIN), 7,
		"7 + 2 - 2, exactly as with no Rack on the table")


func test_a_wheel_is_charged_for_the_refill_and_not_credited_for_the_cast() -> void:
	# `docs/arzakon.strategy` §4: never Wheel or Twister into a Vise. As
	# arithmetic: the hand it leaves us with is seven, not one fewer.
	var ai := _ai(_on())
	put_battlefield(1, "Black Vise")
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	assert_eq(EffectIntent.read(wheel.data.spell_effects, wheel.data.card_name).wheels, 7)
	assert_almost_eq(ai._cast_value(g, wheel, [], 0), 2.5, 0.001,
		"4.00 printed, less the three the refill hands the Vise, at half a point each")


func test_off_the_wheel_into_a_vise_is_the_printed_card() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "Black Vise")
	for i in 5:
		put_battlefield(0, "Mountain")
	var wheel := give_hand(0, "Wheel of Fortune")
	assert_almost_eq(ai._cast_value(g, wheel, [], 0), 4.0, 0.001)


# --------------------------------------------------------------- the price --

func test_the_disenchant_takes_the_vise_and_not_the_tome() -> void:
	var ai := _ai(_on())
	var vise := put_battlefield(1, "Black Vise")
	var tome := put_battlefield(1, "Jayemdae Tome")
	_fill_hand(0, 7)
	assert_almost_eq(ai._victim_value(g, vise), 4.45, 0.001,
		"1.00 printed and the next beat's three at our own face")
	assert_almost_eq(ai._victim_value(g, tome), 4.20, 0.001, "the Tome is unmoved")
	assert_eq(_disenchant_pick(ai), "Black Vise")


func test_off_the_disenchant_takes_the_tome() -> void:
	var ai := _ai(_off())
	var vise := put_battlefield(1, "Black Vise")
	put_battlefield(1, "Jayemdae Tome")
	_fill_hand(0, 7)
	assert_almost_eq(ai._victim_value(g, vise), 1.00, 0.001,
		"a one-mana artifact's cost times 0.8, floored at 1.0")
	assert_eq(_disenchant_pick(ai), "Jayemdae Tome")


func test_a_vise_that_is_not_charging_is_worth_its_printed_card() -> void:
	# The choice is right when the hand is empty too: with nothing to
	# squeeze there is no relief, and the Tome is the better answer.
	var ai := _ai(_on())
	var vise := put_battlefield(1, "Black Vise")
	put_battlefield(1, "Jayemdae Tome")
	_fill_hand(0, 3)
	assert_almost_eq(ai._victim_value(g, vise), 1.00, 0.001)
	assert_eq(_disenchant_pick(ai), "Jayemdae Tome")


func test_a_symmetric_toll_is_worth_only_the_difference() -> void:
	# Storm World stretches BOTH seats. Destroying it relieves both, so
	# with the hands level it is worth nothing beyond its printed card —
	# the subtraction the TOLL_BEATS census (2026-09-10) said it did not
	# have, and has here because both halves are one beat.
	var ai := _ai(_on())
	var world := put_battlefield(1, "Storm World")
	_fill_hand(0, 1)
	_fill_hand(1, 1)
	assert_almost_eq(ai._victim_value(g, world), 1.0, 0.001,
		"a {R} enchantment's printed worth, and no net relief with the hands level")


func test_a_symmetric_toll_is_worth_the_half_we_pay_more_of() -> void:
	var ai := _ai(_on())
	var world := put_battlefield(1, "Storm World")
	_fill_hand(1, 4)
	assert_almost_eq(ai._victim_value(g, world), 5.8, 0.001,
		"four damage at our own empty-handed upkeep and none at theirs")


func test_a_stolen_vise_keeps_squeezing_the_player_it_chose() -> void:
	# The condition is put a probe naming the seat, the way _own_toll asks
	# its own — so the reading follows the CR 614.1c choice rather than
	# the controller. A Vise WE control that chose them is not our problem.
	var ai := _ai(_on())
	var ours := put_battlefield(0, "Black Vise")
	_fill_hand(0, 7)
	_fill_hand(1, 7)
	assert_eq(ai._hand_toll_of(g, ours, 0, 7), 0, "it chose the other seat")
	assert_eq(ai._hand_toll_of(g, ours, 1, 7), 3)
	assert_eq(ai._vise_room(g), 1 << 20, "so our own hand is not being counted")


# ------------------------------------------------------------- the prison --

func test_the_disenchant_takes_the_moat_over_the_tome() -> void:
	var ai := _ai(_on())
	var moat := put_battlefield(1, "Moat")
	var tome := put_battlefield(1, "Jayemdae Tome")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	assert_gt(ai._victim_value(g, moat), ai._victim_value(g, tome),
		"twelve power held at home outprices a card a turn")
	assert_eq(_disenchant_pick(ai), "Moat")


func test_off_the_moat_is_a_four_mana_enchantment() -> void:
	var ai := _ai(_off())
	var moat := put_battlefield(1, "Moat")
	put_battlefield(1, "Jayemdae Tome")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Craw Wurm")
	assert_almost_eq(ai._victim_value(g, moat), 3.20, 0.001,
		"{2}{W}{W} times 0.8, whatever it is holding back")
	assert_eq(_disenchant_pick(ai), "Jayemdae Tome")


func test_a_moat_holding_nothing_back_is_worth_its_printed_card() -> void:
	var ai := _ai(_on())
	var moat := put_battlefield(1, "Moat")
	put_battlefield(0, "Scryb Sprites")   # it flies; the Moat never stopped it
	assert_almost_eq(ai._victim_value(g, moat), 3.20, 0.001)


func test_the_prison_reading_stands_down_with_a_second_static_on_the_table() -> void:
	# [method AiPlayer._ground_the_sweep_opens]' own bound, borrowed:
	# cur_cant_attack is set by a static and by nothing else, so with two
	# static sources standing this reader cannot say which one is doing
	# the work and does not guess.
	var ai := _ai(_on())
	var moat := put_battlefield(1, "Moat")
	put_battlefield(1, "Crusade")
	put_battlefield(0, "Craw Wurm")
	assert_almost_eq(ai._victim_value(g, moat), 3.20, 0.001)


func test_our_own_moat_is_never_priced_as_their_prison() -> void:
	var ai := _ai(_on())
	var moat := put_battlefield(0, "Moat")
	put_battlefield(0, "Craw Wurm")
	assert_almost_eq(ai._prison_relief(g, moat), 0.0, 0.001,
		"the relief is about a permanent of THEIRS")
