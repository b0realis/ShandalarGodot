extends GameTest
## Pack 10 (the Urza block), batch B13: the mana cards on Pack 10 E8 —
## Thran Turbine (mana that can't be spent to cast spells), Contamination
## (every land makes one {B}; the upkeep's creature or the enchantment),
## Metalworker (reveal artifact cards to pay) — and the Pack 10 E9 cards,
## Storage Matrix (one kind untaps) and Damping Engine (the crowded player
## can't play lands or cast permanents unless they sacrifice to ignore it).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G
const C := Mtg.ManaColor.C

const CLAIMED := ["Thran Turbine", "Contamination", "Metalworker", "Storage Matrix", "Damping Engine"]


## A seat whose answers a test scripts: yes/no (-1 the hint), an option by
## its text (else the hint), and the first card offered.
class Seat extends DecisionAgent:
	var yes := -1
	var option := ""
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_option(_game: MtgGame, _pid: int, prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(prompt)
		var at := options.find(option)
		return at if at >= 0 else hint

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


## Walk to P0's next upkeep, its triggers on the stack and resolved.
func _to_my_upkeep() -> void:
	advance_to_next_turn()   # the opponent's turn
	advance_to_step(Mtg.Step.UPKEEP)
	assert_eq(g.active_player, 0)
	resolve_stack()


# ------------------------------------------------------------- Thran Turbine --

func test_thran_turbine_adds_two_colorless_that_no_spell_may_spend() -> void:
	put_battlefield(0, "Thran Turbine")
	me.yes = 1
	_to_my_upkeep()
	var pool := g.players[0].mana_pool
	assert_eq(pool.total_of(C), 2)
	assert_false(pool.can_pay(ManaCost.parse("{2}"), 0, ["spell"]), "not for spells")
	assert_true(pool.can_pay(ManaCost.parse("{2}"), 0, []), "an ability may")


func test_thran_turbine_is_optional() -> void:
	put_battlefield(0, "Thran Turbine")
	me.yes = 0
	_to_my_upkeep()
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(me.asked.size(), 1)


func test_thran_turbine_only_in_your_upkeep() -> void:
	put_battlefield(1, "Thran Turbine")
	_to_my_upkeep()   # through the opponent's upkeep, then into ours
	assert_eq(foe.asked.size(), 1, "asked once: in its controller's upkeep, not in ours")
	assert_true(me.asked.is_empty())


# ------------------------------------------------------------- Contamination --

func test_contamination_makes_every_land_produce_one_black() -> void:
	put_battlefield(0, "Contamination")
	var forest := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.total_of(B), 1)
	assert_eq(g.players[0].mana_pool.total_of(G), 0)
	_priority(1)
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(g.players[1].mana_pool.total_of(B), 1, "every land, both players'")


func test_contamination_leaves_other_mana_sources_alone() -> void:
	put_battlefield(0, "Contamination")
	var ring := put_battlefield(0, "Sol Ring")
	assert_ok(g.tap_for_mana(0, ring))
	assert_eq(g.players[0].mana_pool.total_of(C), 2)


func test_contamination_eats_a_creature_each_upkeep_or_goes() -> void:
	var contamination := put_battlefield(0, "Contamination")
	var bear := put_battlefield(0, "Grizzly Bears")
	_to_my_upkeep()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a creature sacrificed")
	assert_eq(contamination.zone, Mtg.Zone.BATTLEFIELD)
	_to_my_upkeep()
	assert_eq(contamination.zone, Mtg.Zone.GRAVEYARD, "no creature: sacrificed itself")


func test_contamination_may_be_let_go() -> void:
	var contamination := put_battlefield(0, "Contamination")
	var bear := put_battlefield(0, "Grizzly Bears")
	me.yes = 0
	_to_my_upkeep()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(contamination.zone, Mtg.Zone.GRAVEYARD)


func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)


# --------------------------------------------------------------- Metalworker --

func test_metalworker_adds_two_per_revealed_artifact() -> void:
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Rocket Launcher")
	give_hand(0, "Grizzly Bears")
	var seen: Array = []
	g.information_revealed.connect(func(viewer: int, _title: String, names: Array) -> void:
		seen.append([viewer, names.duplicate()]))
	assert_ok(g.tap_for_mana(0, worker))
	assert_eq(g.players[0].mana_pool.total_of(C), 4)
	assert_eq(seen.size(), 1, "the revealed cards are shown to both players")
	assert_eq(int(seen[0][0]), -1)


func test_metalworker_reveals_as_many_as_its_controller_chooses() -> void:
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Sol Ring")
	give_hand(0, "Rocket Launcher")
	me.option = "1"
	assert_ok(g.tap_for_mana(0, worker))
	assert_eq(g.players[0].mana_pool.total_of(C), 2)


func test_metalworker_with_no_artifact_in_hand_makes_nothing() -> void:
	var worker := put_battlefield(0, "Metalworker")
	give_hand(0, "Grizzly Bears")
	assert_ok(g.tap_for_mana(0, worker))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_metalworker_is_a_creature_and_needs_to_have_been_there() -> void:
	var worker := put_battlefield(0, "Metalworker", true)
	give_hand(0, "Sol Ring")
	assert_refused(g.tap_for_mana(0, worker))


# ------------------------------------------------------------ Storage Matrix --

func test_storage_matrix_untaps_only_the_chosen_kind() -> void:
	put_battlefield(1, "Storage Matrix")
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	forest.tapped = true
	bear.tapped = true
	me.option = "Creature"
	advance_to_next_turn()
	advance_to_next_turn()   # P0's untap step chose
	assert_false(bear.tapped)
	assert_true(forest.tapped, "only creatures untapped this step")


func test_a_tapped_storage_matrix_restricts_nothing() -> void:
	var matrix := put_battlefield(1, "Storage Matrix")
	matrix.tapped = true
	g.recalculate()
	var forest := put_battlefield(0, "Forest")
	var bear := put_battlefield(0, "Grizzly Bears")
	forest.tapped = true
	bear.tapped = true
	advance_to_next_turn()   # P1 untaps the Matrix in their untap step
	matrix.tapped = true     # ...tap it again for P0's step (setup)
	g.recalculate()
	advance_to_next_turn()
	assert_false(forest.tapped)
	assert_false(bear.tapped)


# ------------------------------------------------------------ Damping Engine --

func test_damping_engine_holds_back_the_player_with_the_most_permanents() -> void:
	put_battlefield(1, "Damping Engine")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	assert_refused(g.play_land(0, give_hand(0, "Forest")))
	add_mana(0, G, 2)
	assert_refused(g.cast_spell(0, give_hand(0, "Grizzly Bears")))
	add_mana(0, R)
	var bolt := give_hand(0, "Lightning Bolt")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


func test_damping_engine_with_equal_counts_bans_nobody() -> void:
	put_battlefield(1, "Damping Engine")
	put_battlefield(0, "Forest")
	assert_ok(g.play_land(0, give_hand(0, "Forest")))


func test_damping_engine_may_be_ignored_for_a_sacrifice() -> void:
	var engine := put_battlefield(1, "Damping Engine")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var rows: Array = []
	for row in g.special_actions(0):
		if String(row["kind"]) == "ignore_effect":
			rows.append(row)
	assert_eq(rows.size(), 1)
	assert_ok(g.take_special_action(0, rows[0]))
	assert_true(g.effect_ignored_by(engine, 0))
	assert_ok(g.play_land(0, give_hand(0, "Forest")))
