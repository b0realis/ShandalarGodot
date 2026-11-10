extends GutTest
## THE OPTIONAL LAND'S WORDS AND A PAD'S LOG LINE (the 0.60.13 bug campaign,
## X1; ported for adventure plugins, 2026-11-10: the launch flag the h4-2
## words named is retired, so they are gone, and what they guarded is held
## by the plugin-era words).
## - h4-3: the tester's teleport (Ctrl+Shift+2 with `--debug-win`) says the
##   tester's own line, never the island's words — now: no plugin ticked,
##   its card pack not chosen, or not enabled.
## - The owner's ruling of 2026-11-03, as the lead's of 2026-11-10 keeps it:
##   a campaign whose ticked land cannot sail is told why on the mainland
##   ([method AdventureExpansions.mainland_note]; the screen says it once a
##   launch — tests/ui/test_c26_X1_expansion_screen.gd).
## - h4-4: the pad's "connected" line goes to stderr: the PadControls
##   autoload runs inside every tool, whose stdout is its report.
var _pack_before: bool


class Catch extends Logger:
	var lines: Array = []    # [message, to stderr]
	func _log_message(message: String, error: bool) -> void:
		if message.begins_with("pad "):
			lines.append([message, error])


func before_each() -> void:
	_pack_before = CardPacks.is_enabled(FallenEmpiresPack.ID)
	CardPacks.set_enabled(FallenEmpiresPack.ID, true)


func after_each() -> void:
	CardPacks.set_enabled(FallenEmpiresPack.ID, _pack_before)


## A hero of a campaign that ticked the Refuge ([param island]) or an
## ordinary one.
func _hero(island := true) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.adventures.assign(["refuge"] if island else [])
	if island:
		setup.packs = ["pack-2"]
	setup.seed_text = "48271"
	setup.player_name = "Wayfarer"
	var record := setup.resolve({"pack-2": "1"} if island else {})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	AdventureExpansions.initialize(hero)
	return hero


# ------------------------------------------------- the retired flag --

func test_the_retired_flag_is_named_nowhere_a_player_reads() -> void:
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	var port: Array = hero.world.expansion["port"]
	var place := _refuge().describe(hero, Vector2i(port[0], port[1]))
	assert_false(" ".join(place["lines"]).contains("--expanded-adventure"), "the harbor's words")
	assert_false(MainScreen.launch_help("1.2.3").contains("--expanded-adventure"), "the launch help's")
	var source := FileAccess.get_file_as_string("res://game/adventure/expansions/adventure_expansions.gd")
	assert_false(source.contains("launch_enabled") or source.contains("LAUNCH_"), "no switch left to read")


# --------------------------------------------------------------- h4-3 --

func test_the_teleport_on_a_mainland_without_a_plugin_says_the_testers_line() -> void:
	var hero := _hero(false)
	var said := WorldScreen.debug_port_refusal(hero)
	assert_false(said.contains("sail home"), said)
	assert_eq(said, "Debug: tick an adventure plugin when embarking first.")


func test_the_teleports_refusals_name_only_what_is_missing() -> void:
	var island := _hero()
	assert_eq(WorldScreen.debug_port_land(island), "refuge")
	assert_eq(WorldScreen.debug_port_refusal(island), "", "plugin and pack: it goes")
	var no_pack := _hero()
	no_pack.packs.clear()
	assert_eq(WorldScreen.debug_port_refusal(no_pack), "Debug: select %s when embarking first." % AdventurePacks.title("pack-2"))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(WorldScreen.debug_port_refusal(island), "Debug: enable %s in Options first." % AdventurePacks.title("pack-2"))


# ------------------------------------------- the owner's ruling, 2026-11-03 --

func test_a_ticked_land_that_cannot_sail_is_told_on_the_mainland() -> void:
	var hero := _hero()
	assert_eq(AdventureExpansions.mainland_note(hero), "", "everything there: the anchorage is there")
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
	assert_eq(AdventureExpansions.mainland_note(hero),
		"Ships to The Last Refuge do not sail: the plugin %s needs %s." % [AdventurePlugins.row("refuge")["name"],
			AdventurePacks.title("pack-2")])


func test_no_note_where_nothing_is_hidden() -> void:
	assert_eq(AdventureExpansions.mainland_note(_hero(false)), "", "a campaign without the island")
	var hero := _hero()
	assert_true(_refuge().travel(hero))
	CardPacks.set_enabled(FallenEmpiresPack.ID, false)
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


## The Last Refuge's content, the plugin's own [DataRegion] (adventure
## plugins, 2026-11-10: the built-in scripts it replaced are gone).
func _refuge() -> DataRegion:
	return AdventureExpansions.provider("refuge") as DataRegion
