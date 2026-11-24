extends GutTest
## THE PACK BUILDER WHERE ONLY THE EXPORTED GAME IS (bug pass 2026-11-24).
## A player with the game's binary and nothing else must get every pack.
##
##   * Pack 1's trusted files lie in a folder with a `.gdignore`, which an
##     export passes over: no exported game carries them, and Pack 1 read
##     "Not in this build" in every one. [PackRecipes] carries the three
##     small files itself and reads its own copy where the files are not —
##     the same recipe to the byte, and the copy held to the files here.
##   * What stops one pack and would stop the next the same way (no
##     connection, a card folder that takes no file) says so in its outcome
##     (`halts`), so the window does not begin the rest; a card Scryfall
##     lacks is that pack's alone.
##   * A card folder that cannot be written is said before a request is
##     made, not after the whole download.
## No test here opens a socket (`tests/support/c1123_pack_fakes.gd`).

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1123_pack_export"
const PACK_ONE := "res://packaging/card_packs/pack_1_dotp_complete/"

var _host: Fakes.Host


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_host = Fakes.host(SCRATCH)


func after_each() -> void:
	PackRecipes.without = []
	PackRecipes.packaging = PackRecipes.PACKAGING
	Fakes.wipe(SCRATCH)


func _build(id: String) -> PackBuild:
	var build := PackBuild.new()
	build.frame_usec = 0
	build.start(id, _host)
	return build


func _as_an_export() -> void:
	var gone: Array[String] = []
	for name: String in PackRecipes.PACK_ONE_OWN:
		gone.append(PACK_ONE + name)
	PackRecipes.without = gone


func test_the_copy_in_the_script_is_the_trusted_files_byte_for_byte() -> void:
	assert_eq(PackRecipes.PACK_ONE_OWN.size(), 3)
	for name: String in PackRecipes.PACK_ONE_OWN:
		assert_true(PackRecipes.sources("pack-1").has(PACK_ONE + name), name + " is one of Pack 1's sources")
		var on_disk := FileAccess.get_file_as_bytes(PACK_ONE + name).get_string_from_utf8() \
			.replace("\r\n", "\n").replace("\r", "\n")
		assert_gt(on_disk.length(), 500, name)
		assert_eq(String(PackRecipes.PACK_ONE_OWN[name]), on_disk, name)


func test_pack_1_is_the_same_recipe_where_an_export_left_its_folder_out() -> void:
	var whole := PackRecipes.recipe("pack-1")
	assert_true(bool(whole.get("ok", false)), str(whole.get("why")))
	_as_an_export()
	assert_eq(PackRecipes.lacking("pack-1"), "", "the build's own copy stands in")
	var own := PackRecipes.recipe("pack-1")
	assert_true(bool(own.get("ok", false)), str(own.get("why")))
	assert_eq((own["jobs"] as Array).size(), 373)
	for part: String in ["file_name", "prefix", "jobs", "entries", "manifest", "max_entries", "max_bytes"]:
		assert_eq(own[part], whole[part], part)
	for name: String in ["catalog.json", "cards.json", "README.txt"]:
		assert_eq(PackWriter.sha256(own["metadata"][name]), PackWriter.sha256(whole["metadata"][name]), name)


func test_only_pack_1_has_a_copy_and_only_under_the_game_s_own_folder() -> void:
	var manifest := "res://packaging/card_packs/pack_7_fifth_edition/manifest.json"
	PackRecipes.without = [manifest]
	assert_eq(PackRecipes.lacking("pack-7"), manifest.trim_prefix("res://"))
	assert_false(bool(PackRecipes.recipe("pack-7").get("ok", true)))
	PackRecipes.without = []
	PackRecipes.packaging = "res://packaging/no_such_folder/"
	assert_eq(PackRecipes.lacking("pack-1"), "packaging/no_such_folder/pack_1_dotp_complete/manifest.json")
	assert_false(bool(PackRecipes.recipe("pack-1").get("ok", true)))


func test_pack_1_built_from_the_copy_passes_the_game_s_own_check() -> void:
	_as_an_export()
	_host.net.teach(PackRecipes.recipe("pack-1")["jobs"])
	var build := _build("pack-1")
	Fakes.run(build)
	assert_eq(build.state, "done", str(build.outcome))
	var report := CardPacks.inspect(_host.folder().path_join("Pack-1-DotP-complete.zip"))
	assert_true(bool(report.get("ok", false)), str(report.get("why")))


func test_what_would_stop_the_next_pack_too_says_so() -> void:
	_host.net.scripted["scryfall"] = [Fakes.answer(0, PackedByteArray(), {}, "connect")]
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.outcome.get("kind"), "network")
	assert_true(bool(build.outcome.get("halts")), "no connection")
	before_each()
	_host.net.scripted["api.scryfall.com"] = [Fakes.answer(429)]
	build = _build("pack-2")
	Fakes.run(build)
	assert_true(bool(build.outcome.get("halts")), "a server that stays busy")
	before_each()
	_host.locked = "Close the table first."
	build = _build("pack-2")
	assert_true(bool(build.outcome.get("halts")), "a locked catalogue")
	before_each()
	# A card Scryfall lacks is this pack's alone.
	var jobs: Array = PackRecipes.recipe("pack-2")["jobs"]
	_host.net.teach(jobs)
	_host.net.absent[jobs[0]["key"]] = true
	_host.net.scripted[String(jobs[0]["lookups"][1])] = [Fakes.answer(404)]
	build = _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_string_contains(String(build.outcome.get("text")), "1 card could not be fetched")
	assert_false(bool(build.outcome.get("halts")), "the next pack may still be whole")
	before_each()
	_host.net.teach(jobs)
	build = _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "done")
	assert_false(bool(build.outcome.get("halts")))


func test_a_card_folder_that_takes_no_file_is_said_before_anything_is_asked() -> void:
	assert_eq(_host.unwritable(), "", "the scratch folder takes a file")
	assert_false(DirAccess.dir_exists_absolute(_host.folder().path_join(PackBuildHost.BUILDING)),
		"and the try leaves nothing behind")
	assert_eq(DirAccess.get_files_at(_host.cache_root()), PackedStringArray())
	# A file where the card folder should be: nothing can be made in it.
	Fakes.write(SCRATCH.path_join("blocked"), "x".to_utf8_buffer())
	_host.root = SCRATCH.path_join("blocked")
	assert_string_contains(_host.unwritable(), "The game cannot write in ")
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var build := _build("pack-2")
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "disk")
	assert_string_contains(String(build.outcome.get("text")), "cannot write in")
	assert_true(bool(build.outcome.get("halts")))
	assert_eq(_host.net.log, [] as Array[String], "nothing was asked")
	assert_engine_error_count(0, "and the engine was not made to complain")
