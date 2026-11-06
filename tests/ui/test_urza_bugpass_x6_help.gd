extends GameTest
## THE 0.60.19 BUG PASS OVER THE URZA BLOCK'S HELP (h9-4, h9-5, h9-10, and
## Show and Tell's hidden choices): each entry says what the rules do,
## checked here against the game itself where the words name a result.
## - Opalescence: Glorious Anthem is a 3/3 by its mana value and its own
##   +1/+1 makes it a 4/4 (it said "a 3/3").
## - Temporal Aperture: ANY shuffle of the library ends the offer, even one
##   that leaves the card on top (it said "a shuffle that moves it").
## - Damping Engine: a player sacrifices a permanent of their own, so the
##   Engine itself only when it is theirs (it said "itself included").
## - Echo after a change: a Clone entering as a copy owes echo; a
##   permanent that only becomes a copy (Vesuvan Doppelganger) owes none.
## - Defense Grid, Thran Lens and Memory Crystal: a tapped one does
##   nothing unless it has become a creature (it said "like every tapped
##   artifact's").
## - Serra Avatar: shuffled into its OWNER's library.
## - Show and Tell: the opponent chooses without seeing the active
##   player's choice; both are revealed together (CR 101.4a).

const GLOSSARY := preload("res://game/help/ability_glossary.gd")
const U := Mtg.ManaColor.U


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


## The words of the glossary entry headed [param heading].
func _entry(heading: String) -> String:
	for page in GLOSSARY.pages():
		var blocks: Array = page.get("blocks", [])
		for i in blocks.size():
			if String(blocks[i].get("kind", "")) == "heading" and String(blocks[i].get("text", "")) == heading:
				return String(blocks[i + 1].get("text", "")) if i + 1 < blocks.size() else ""
	return ""


func _in_library(pid: int, card_name: String) -> CardInstance:
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.append(inst)
	return inst


func test_glorious_anthem_under_opalescence_is_a_four_four() -> void:
	var anthem := put_battlefield(0, "Glorious Anthem")
	put_battlefield(1, "Opalescence")
	g.recalculate()
	assert_true(anthem.is_creature())
	assert_eq([anthem.cur_power, anthem.cur_toughness], [4, 4], "its mana value, and its own bonus")
	var words := _entry("Opalescence")
	assert_string_contains(words, "Glorious Anthem is a 3/3, and its own +1/+1 makes it a 4/4")


func test_any_shuffle_ends_temporal_apertures_offer() -> void:
	g.players[0].library.clear()
	var bear := _in_library(0, "Grizzly Bears")
	var aperture := put_battlefield(0, "Temporal Aperture")
	add_mana(0, U, 5)
	assert_ok(g.activate_ability(0, aperture, 0))
	resolve_stack()
	assert_true(g.can_play_from_zone(0, bear), "offered")
	g.shuffle_library(0)
	assert_eq(g.players[0].library.back(), bear, "a one-card library: the card is on top again")
	assert_false(g.can_play_from_zone(0, bear), "and the offer is over")
	var words := _entry("Temporal Aperture")
	assert_string_contains(words, "Drawing it, putting another card on top or any shuffle of your library ends the offer for good, even if the card is on top again afterwards")
	assert_false(words.contains("a shuffle that moves it"))


func test_damping_engine_is_sacrificed_only_by_its_own_controller() -> void:
	var engine := put_battlefield(1, "Damping Engine")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	assert_eq(g._ignore_payer(engine), 0, "the crowded player may ignore it")
	assert_false(g._ignore_bodies(0, engine).has(engine), "but not by sacrificing the opponent's Engine")
	var words := _entry("Damping Engine")
	assert_string_contains(words, "That player may sacrifice a permanent they control, Damping Engine itself if it is theirs, to ignore it until end of turn")
	assert_false(words.contains("itself included"))


func test_echo_on_a_copy_is_owed_only_by_one_that_enters() -> void:
	var words := _entry("Echo after a change")
	assert_string_contains(words, "A Clone that enters as a copy of a permanent with echo has echo too and owes it")
	assert_string_contains(words, "a permanent that becomes a copy later, as Vesuvan Doppelganger can at the beginning of your upkeep, has echo but owes nothing")
	assert_false(words.contains("A copy of a permanent with echo has echo too and owes it."))


func test_a_tapped_artifact_creature_keeps_working() -> void:
	for heading in ["Defense Grid and Thran Lens", "Memory Crystal"]:
		var words := _entry(heading)
		assert_string_contains(words, "unless it has become a creature", heading)
		assert_false(words.contains("like every tapped artifact"), heading)


func test_serra_avatar_goes_to_its_owners_library() -> void:
	var words := _entry("Serra Avatar")
	assert_string_contains(words, "it is shuffled back into its owner's library, even when another player controlled it")
	assert_false(words.contains("shuffled back into your library"))


func test_show_and_tell_keeps_the_first_choice_hidden() -> void:
	var words := _entry("Show and Tell")
	assert_string_contains(words, "The active player chooses first, then the opponent, without seeing that choice")
	assert_string_contains(words, "neither card is shown until both players have chosen")
	assert_string_contains(words, "then both are revealed and arrive together, each under its owner's control")
	assert_false(words.contains("shown to both players before the opponent decides"))
