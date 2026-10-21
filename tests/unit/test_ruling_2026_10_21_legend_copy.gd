extends GameTest
## THE OWNER'S RULING OF 2026-10-21 ON THE 1997 LEGEND RULE AND A COPY,
## verbatim: *"the 1997 legend rule when a Vesuvan Doppelganger becomes a
## copy of a newer legend (rule as per 1997 and document it)"*.
##
## The rule of the era is "first in time, first in right": of two legends
## with one name, the NEWER is buried — and newer means newer AS THAT
## LEGEND, "the legend with the same name that has been a legend a shorter
## time than the other legend" (the Classic Sixth Edition rule 420.5e as a
## judge applied it to this very case in 2002; the sources are quoted at
## [method MtgGame._newest_duplicate_legend] and in docs/mechanics.md).
##
## WAS: the order read was battlefield ENTRY, so a Vesuvan Doppelganger that
## entered before a legend and later became a copy of it buried the
## ORIGINAL legend — a removal spell the rules of 1997 never allowed.
## NOW: the permanent that most recently BECAME that legend
## ([method MtgGame.legend_since]: entry, or a copy, or turning face up) is
## the one buried. Two legends that entered as themselves are unchanged.


## Names the shape it wants (an arrival copy and the upkeep target) and
## says yes to every "may".
class Shaper extends DecisionAgent:
	var want := ""

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == want:
				return inst
		return null if candidates.is_empty() else candidates[0]


const LEGEND := "Sir Shandlar of Eberyn"


func _cast_doppelganger(shaper: Shaper, shape: String) -> CardInstance:
	shaper.want = shape
	var doppel := give_hand(0, "Vesuvan Doppelganger")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, doppel, []))
	resolve_stack()
	assert_eq(doppel.data.card_name, shape, "the Doppelganger arrived as a " + shape)
	return doppel


## Two turns on: our upkeep, where the Doppelganger's shift asks.
func _to_our_next_upkeep() -> void:
	advance_to_next_turn()
	advance_to_next_turn()
	resolve_stack()


# --------------------------------------------- the plain case, unchanged --

func test_the_second_of_two_legends_is_buried() -> void:
	var first := put_battlefield(0, LEGEND)
	g.check_state_based_actions()
	var second := put_battlefield(1, LEGEND)
	g.check_state_based_actions()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD, "first in time, first in right")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "the newcomer is buried")


func test_a_cast_second_legend_is_buried_on_arrival() -> void:
	var first := put_battlefield(1, LEGEND)
	var second := give_hand(0, LEGEND)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, second, []))
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------- a Doppelganger in play shifts --

func test_doppelganger_becoming_a_copy_of_a_newer_legend_is_the_one_buried() -> void:
	# THE OWNER'S CASE: the Doppelganger entered FIRST (as a Grizzly Bears);
	# the legend entered after it; at our upkeep the Doppelganger becomes a
	# copy of the legend. It has been that legend for no time at all.
	var shaper := Shaper.new()
	g.set_agent(0, shaper)
	put_battlefield(1, "Grizzly Bears")
	var doppel := _cast_doppelganger(shaper, "Grizzly Bears")
	var legend := put_battlefield(1, LEGEND)     # entered AFTER the Doppelganger
	shaper.want = LEGEND
	_to_our_next_upkeep()
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD, "the original legend stays")
	assert_eq(doppel.zone, Mtg.Zone.GRAVEYARD, "the copy is the newer legend and is buried")


func test_doppelganger_becoming_a_copy_of_an_older_legend_is_the_one_buried() -> void:
	var shaper := Shaper.new()
	g.set_agent(0, shaper)
	var legend := put_battlefield(1, LEGEND)     # entered BEFORE the Doppelganger
	put_battlefield(1, "Grizzly Bears")
	var doppel := _cast_doppelganger(shaper, "Grizzly Bears")
	shaper.want = LEGEND
	_to_our_next_upkeep()
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(doppel.zone, Mtg.Zone.GRAVEYARD)


func test_a_copy_made_by_the_engine_counts_from_the_copy() -> void:
	# The same through MtgGame.become_copy directly (the door Unstable
	# Shapeshifter's copy uses too), our own legend this time.
	var shifter := put_battlefield(0, "Grizzly Bears")
	var legend := put_battlefield(0, LEGEND)
	g.check_state_based_actions()
	assert_lt(g.legend_since(shifter), g.legend_since(legend), "the Bears entered first")
	g.become_copy(shifter, g.copiable_data(legend))
	assert_gt(g.legend_since(shifter), g.legend_since(legend), "but became the legend last")
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD)


func test_a_copy_that_keeps_its_name_keeps_its_time() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var since := g.legend_since(bear)
	g.become_copy(bear, CardRegistry.get_card("Grizzly Bears"))
	assert_eq(g.legend_since(bear), since, "no new name, no new start")


# --------------------------------------------- a Clone entering as a copy --

func test_a_clone_entering_as_a_copy_of_a_legend_is_buried() -> void:
	var shaper := Shaper.new()
	shaper.want = LEGEND
	g.set_agent(0, shaper)
	var legend := put_battlefield(1, LEGEND)
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, clone, []))
	resolve_stack()
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD, "the original stays")
	assert_eq(clone.zone, Mtg.Zone.GRAVEYARD, "the Clone entered as the newer legend")


func test_a_doppelganger_entering_as_a_copy_of_a_legend_is_buried() -> void:
	var shaper := Shaper.new()
	g.set_agent(0, shaper)
	var legend := put_battlefield(1, LEGEND)
	shaper.want = LEGEND
	var doppel := give_hand(0, "Vesuvan Doppelganger")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.cast_spell(0, doppel, []))
	resolve_stack()
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(doppel.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------- a face-down legend turned face up --

func test_a_legend_turned_face_up_is_the_newer_legend() -> void:
	# Masked first (no name, no legend, CR 708.2), the other entered
	# meanwhile: turned up, the masked one has been that legend no time.
	var masked := put_battlefield(0, LEGEND)
	g.turn_face_down(masked)
	var other := put_battlefield(1, LEGEND)
	g.check_state_based_actions()
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD, "a face-down permanent is no duplicate")
	g.turn_face_up(masked)
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(masked.zone, Mtg.Zone.GRAVEYARD)


# ----------------------------------------------------- the heuristic --

func test_the_heuristic_never_shifts_the_doppelganger_into_a_legend() -> void:
	# A legend is a shape that buries the Doppelganger at once: the
	# heuristic seat (the hint) declines it however big it is.
	var shaper := Shaper.new()
	g.set_agent(0, shaper)
	put_battlefield(1, "Grizzly Bears")
	var doppel := _cast_doppelganger(shaper, "Grizzly Bears")
	var legend := put_battlefield(1, LEGEND)     # 4/7: the biggest body
	g.set_agent(0, DecisionAgent.new())          # the heuristic answers now
	_to_our_next_upkeep()
	assert_eq(doppel.zone, Mtg.Zone.BATTLEFIELD, "it did not kill itself")
	assert_ne(doppel.data.card_name, LEGEND)
	assert_eq(legend.zone, Mtg.Zone.BATTLEFIELD)
