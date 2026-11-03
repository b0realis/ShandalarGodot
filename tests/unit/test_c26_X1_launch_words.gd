extends GutTest
## THE OPTIONAL LAND'S LAUNCH WORDS AND A PAD'S LOG LINE (the 0.60.13 bug
## campaign, X1).
## - h4-2: every message names the flag as a launch must give it, after the
##   engine's own `--` — the bare flag, followed literally, left the
##   prototype off without a word.
## - h4-3: the tester's teleport (Ctrl+Shift+2 with `--debug-win`) without the
##   flag says the tester's line, not the island's "… You can still sail
##   home." on a mainland with no island.
## - The owner's ruling of 2026-11-03: a campaign that chose the island but
##   was launched without the flag is told on the mainland how to reach it
##   ([method AdventureExpansions.mainland_note]; the screen says it once a
##   launch — tests/ui/test_c26_X1_expansion_screen.gd).
## - h4-4: the pad's "connected" line goes to stderr: the PadControls
##   autoload runs inside every tool, whose stdout is its report.

var _launch_before: bool
var _pack_before: bool


class Catch extends Logger:
	var lines: Array = []    # [message, to stderr]
	func _log_message(message: String, error: bool) -> void:
		if message.begins_with("pad "):
			lines.append([message, error])


func before_each() -> void:
	_launch_before = AdventureExpansions.launch_enabled
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]) if _launch_before else PackedStringArray())
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


## A hero begun with the flag given: a campaign that chose the island
## ([param island]) or an ordinary one.
func _hero(island := true) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.expanded_adventure = island
	if island:
		setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"} if island else {})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


# --------------------------------------------------------------- h4-2 --

func test_the_restart_words_give_the_flag_after_the_engines_own_dashes() -> void:
	assert_string_contains(AdventureExpansions.LAUNCH_HELP, "Restart with -- --expanded-adventure ")
	assert_eq(AdventureExpansions.LAUNCH_ARGS, "-- " + AdventureExpansions.LAUNCH_FLAG)
	# What follows the engine's `--` is what a launch reads.
	var words := AdventureExpansions.LAUNCH_ARGS.split(" ")
	assert_eq(words[0], "--", "the engine's own separator first")
	AdventureExpansions.read_launch(PackedStringArray())
	AdventureExpansions.read_launch(words.slice(1))
	assert_true(AdventureExpansions.launch_enabled, "the rest is the user argument a launch reads")


func test_the_island_harbor_without_the_flag_gives_the_whole_flag() -> void:
	var hero := _hero()
	assert_true(RefugeCampaign.travel(hero))
	AdventureExpansions.read_launch(PackedStringArray())
	var port: Array = hero.world.expansion["port"]
	var place := RefugeJourney.describe(hero, Vector2i(port[0], port[1]))
	assert_string_contains(String(place["lines"][0]), "-- --expanded-adventure",
		"the harbor's own words (the shared LAUNCH_HELP)")


# --------------------------------------------------------------- h4-3 --

func test_the_teleport_on_a_mainland_without_the_flag_says_the_testers_line() -> void:
	var hero := _hero(false)
	AdventureExpansions.read_launch(PackedStringArray())
	var said := WorldScreen.debug_port_refusal(hero)
	assert_ne(said, AdventureExpansions.LAUNCH_HELP, "not the island's words")
	assert_false(said.contains("sail home"), said)
	assert_eq(said, "Debug: launch with -- --expanded-adventure and select Pack 2 when embarking first.")


func test_the_teleports_refusals_name_only_what_is_missing() -> void:
	var island := _hero()
	assert_eq(WorldScreen.debug_port_refusal(island), "", "flag, island and pack: it goes")
	AdventureExpansions.read_launch(PackedStringArray())
	assert_eq(WorldScreen.debug_port_refusal(island), "Debug: launch with -- --expanded-adventure first.")
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	assert_eq(WorldScreen.debug_port_refusal(_hero(false)), "Debug: select Pack 2 when embarking first.")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(WorldScreen.debug_port_refusal(island), "Debug: enable Pack 2: Fallen Empires in Options first.")


# ------------------------------------------- the owner's ruling, 2026-11-03 --

func test_an_island_campaign_without_the_flag_is_told_the_way_on_the_mainland() -> void:
	var hero := _hero()
	assert_eq(AdventureExpansions.mainland_note(hero), "", "the flag given: the anchorage is there")
	AdventureExpansions.read_launch(PackedStringArray())
	assert_eq(AdventureExpansions.mainland_note(hero),
		"Ships to The Last Refuge sail only when the game is started with -- --expanded-adventure.")


func test_no_note_where_nothing_is_hidden_by_the_flag() -> void:
	AdventureExpansions.read_launch(PackedStringArray())
	assert_eq(AdventureExpansions.mainland_note(_hero(false)), "", "a campaign without the island")
	AdventureExpansions.read_launch(PackedStringArray([AdventureExpansions.LAUNCH_FLAG]))
	var hero := _hero()
	assert_true(RefugeCampaign.travel(hero))
	AdventureExpansions.read_launch(PackedStringArray())
	assert_eq(AdventureExpansions.mainland_note(hero), "", "on the island its harbor says it")
	assert_eq(AdventureExpansions.mainland_note(null), "")


# --------------------------------------------------------------- h4-4 --

func test_a_pads_coming_and_going_is_logged_on_stderr() -> void:
	var pads := get_tree().root.get_node(^"PadControls")
	var catch := Catch.new()
	OS.add_logger(catch)
	pads._on_pads_changed(7, false)
	OS.remove_logger(catch)
	assert_eq(catch.lines.size(), 1, "one line for the playtest log")
	if catch.lines.size() == 1:
		assert_eq(String(catch.lines[0][0]).strip_edges(), "pad 7 gone: -")
		assert_true(catch.lines[0][1], "on stderr, never in a tool's report")
