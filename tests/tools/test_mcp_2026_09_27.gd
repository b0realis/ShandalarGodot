extends GutTest
## THE MCP SERVER (2026-09-27): tools/shandalar_mcp.py, the one door's
## `mcp` verb — every tool of the Lab, the AutoDeck CLI, the deck query
## and the referee for a program that speaks the Model Context Protocol
## on stdio, the referee's pipe kept as a game across calls. Its
## self-test, tools/test_shandalar_mcp.py, drives the server against a
## FAKE door with no engine (the Python gate runs that half: the
## protocol, the catalogue, the refusals, the deck files, the path rule,
## the session, the pilot). The half that needs the REAL engine — a deck
## written and checked by the card pool, the Lab's plan, a duel played
## to its end through the pilot — is its `LiveTest`, skipped without
## SHANDALAR_MCP_LIVE=1. This script runs that half inside the gate,
## with THIS engine as the door's Godot, reads the catalogue the server
## prints for a program, and pins the doors, the release and the pages.

const SERVER := "res://tools/shandalar_mcp.py"
const SELF_TEST := "tools.test_shandalar_mcp"
const TOOLS := ["status", "contract", "play_guide", "manual", "packs", "cards", "list_decks",
	"read_deck", "write_deck", "check_deck", "convert_deck", "autodeck", "lab",
	"lab_resume", "read_run", "lab_next", "referee_start", "referee_join", "referee_host",
	"referee_act", "referee_autoplay", "referee_wait", "referee_stop", "referee_resume"]


func _root() -> String:
	return ProjectSettings.globalize_path("res://").rstrip("/")


func _python() -> bool:
	var probe: Array = []
	return OS.execute("python3", ["--version"], probe, true) == 0


## The server's self-test, live half: the real door, the real engine —
## this one, handed down as GODOT so the gate's engine is the door's.
## The module is named through PYTHONPATH, so the engine's working
## directory is not assumed; unittest writes its report on stderr, and
## the tail of it is the message of a failed assertion. (OS.execute
## with an output array goes through a shell that expands `$` — hence
## `env` and plain words, never a `bash -c` script with positionals.)
func test_the_live_half_runs_against_this_engine() -> void:
	if not _python():
		pending("no python3 here — the Python gate runs the server's self-test")
		return
	var output: Array = []
	var status := OS.execute("env", [
		"PYTHONPATH=" + _root(), "GODOT=" + OS.get_executable_path(), "SHANDALAR_MCP_LIVE=1",
		"python3", "-m", "unittest", "-v", SELF_TEST + ".LiveTest"], output, true)
	var report := "".join(PackedStringArray(output))
	assert_eq(status, 0, "the live half passes:\n" + report.right(6000))
	assert_true(report.contains("Ran 7 tests"), "the seven live tests ran:\n" + report.right(2000))
	assert_false(report.contains("skipped"), "nothing was skipped: SHANDALAR_MCP_LIVE reached the test")
	assert_true(report.contains("test_duel_to_the_end"), "the duel was played")
	assert_true(report.contains("test_a_kept_duel_is_taken_up_by_another_server_and_passed_until"),
		"the kept duel was taken up and passed until")
	assert_true(report.contains("test_a_hosted_table_is_joined_by_a_guest_and_played"),
		"the hosted table was joined and played")


## The catalogue a program reads before it acts, printed by the server
## without a protocol round-trip: every tool by name, each with a
## description and an object schema whose every property is described
## and which takes nothing it does not name.
func test_the_catalogue_is_printed_for_a_program() -> void:
	if not _python():
		pending("no python3 here — the Python gate reads the catalogue")
		return
	var output: Array = []
	var status := OS.execute("python3", [ProjectSettings.globalize_path(SERVER), "--catalogue"], output, false)
	assert_eq(status, 0)
	var catalogue = JSON.parse_string("".join(PackedStringArray(output)))
	assert_true(catalogue is Dictionary, "one JSON document")
	if not catalogue is Dictionary:
		return
	var names: Array = []
	for tool in catalogue.get("tools", []):
		names.append(tool.name)
		assert_true(tool.description.length() >= 40, tool.name + " has a description a program can act on")
		var schema: Dictionary = tool.inputSchema
		assert_eq(schema.type, "object", tool.name)
		assert_false(bool(schema.additionalProperties), tool.name + " takes only what it names")
		for key in schema.properties:
			var property: Dictionary = schema.properties[key]
			assert_true(property.has("type"), "%s.%s has a type" % [tool.name, key])
			assert_true(String(property.get("description", "")).length() > 0, "%s.%s is described" % [tool.name, key])
		for key in schema.get("required", []):
			assert_true(schema.properties.has(key), "%s requires %s, which it names" % [tool.name, key])
	assert_eq(names, TOOLS, "the tools, in the order the manual lists them")
	var uris: Array = []
	for resource in catalogue.get("resources", []):
		uris.append(resource.uri)
	assert_true(uris.has("shandalar://contract"), "the contract page is a resource")
	assert_true(uris.has("shandalar://play-guide"), "the play guide is a resource")
	assert_true(uris.has("shandalar://manual/referee"), "the manuals are resources")


# ------------------------------------------------------- the doors --

func test_the_doors_and_the_pages_know_the_server() -> void:
	var door := FileAccess.get_file_as_string("res://shandalar.sh")
	assert_true(door.contains('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;'))
	assert_true(door.contains("referee, convert, mcp"), "the unknown-verb line lists it")
	assert_true(door.contains("./shandalar.sh mcp"))
	var release := FileAccess.get_file_as_string("res://build_release.sh")
	assert_true(release.contains('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;'))
	var package := FileAccess.get_file_as_string("res://tools/package_release.py")
	assert_true(package.contains('"shandalar_mcp.py"'), "the release ships the server")
	assert_true(package.contains('mcp) exec python3 tools/shandalar_mcp.py "$@" ;;'))
	var agents := FileAccess.get_file_as_string("res://AGENTS.md")
	assert_true(agents.contains("## The MCP server"))
	for tool in TOOLS:
		assert_true(agents.contains("`%s`" % tool), "AGENTS.md names " + tool)
	var readme := FileAccess.get_file_as_string("res://DeckLab/README.md")
	assert_true(readme.contains("## The MCP server"))
	assert_true(readme.contains("shandalar_mcp.py"))
	var server := FileAccess.get_file_as_string(SERVER)
	assert_true(server.contains("THE RULES IT KEEPS"), "the header states the rules")
	assert_true(server.contains('SERVER_NAME = "shandalar"'))
	for tool in TOOLS:
		assert_true(server.contains('"%s"' % tool), "the server has " + tool)
	var ignore := FileAccess.get_file_as_string("res://.gitignore")
	assert_true(ignore.contains("workspace/"), "the server's workspace is never tracked")
