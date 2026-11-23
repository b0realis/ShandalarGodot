extends GutTest
## THE PACK BUILDER'S VIEW OF THE REAL GAME (campaign 2026-11-23):
## [PackBuildHost] itself, which the other tests replace. Read-only against
## the running game — how each pack stands, the lock's words, the free room
## — and its two writes (a zip put in place, the work folder cleared) in a
## scratch card folder. No rescan, no mount, no socket.

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1123_pack_host"


## The real host with its card folder and cache moved into the scratch.
class Scratch extends PackBuildHost:
	func folder() -> String:
		return SCRATCH.path_join("cardpacks")

	func cache_root() -> String:
		return SCRATCH.path_join("cache")


var _seals := PackedByteArray()
var _had_seals := false


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_had_seals = FileAccess.file_exists(PackSeal.FILE)
	_seals = FileAccess.get_file_as_bytes(PackSeal.FILE) if _had_seals else PackedByteArray()


func after_each() -> void:
	Fakes.wipe(SCRATCH)
	if _had_seals:
		FileAccess.open(PackSeal.FILE, FileAccess.WRITE).store_buffer(_seals)
	else:
		PackSeal.clear()


func test_the_real_host_answers_for_all_eleven() -> void:
	var host := PackBuildHost.new()
	assert_eq(host.folder(), GamePaths.cardpacks_folder())
	assert_eq(host.refusal(), CardPacks.change_refusal())
	assert_eq(host.cache_root(), "user://cardpack_build")
	assert_true(host.transport() is PackTransport)
	for id: String in PackRecipes.ids():
		var status := host.status(id)
		assert_true(String(status.get("state", "")) in ["installed", "elsewhere", "refused", "absent"], id)
		assert_true(status.get("note") is String, id)
	var free := host.free_bytes()
	assert_true(free == -1 or free > 0, "the free room, or -1 where the platform cannot say")
	var owner := Node.new()
	CardPacks.lock_catalogue(owner)
	assert_eq(host.refusal(), "Close SGManalink connections and stop hosting before changing or rescanning card packs.")
	CardPacks.unlock_catalogue(owner)
	owner.free()
	assert_eq(host.refusal(), "")


func test_the_go_easy_tick_is_on_until_unticked_and_is_kept_in_the_settings() -> void:
	var had := Settings.has_value(PackBuildHost.GENTLE_KEY)
	var old: Variant = Settings.get_value(PackBuildHost.GENTLE_KEY, true)
	Settings.clear_value(PackBuildHost.GENTLE_KEY)
	var host := PackBuildHost.new()
	assert_true(host.gentle(), "a fresh profile goes easy")
	host.set_gentle(false)
	assert_eq(Settings.get_value("card_packs_gentle", true), false)
	assert_false(PackBuildHost.new().gentle(), "another window, another start: still unticked")
	host.set_gentle(true)
	assert_true(PackBuildHost.new().gentle())
	if had:
		Settings.set_value(PackBuildHost.GENTLE_KEY, old)
	else:
		Settings.clear_value(PackBuildHost.GENTLE_KEY)


func test_a_built_pack_is_judged_by_its_contract_put_in_place_and_sealed() -> void:
	var fake := Fakes.host(SCRATCH)
	fake.net.teach(PackRecipes.recipe("pack-4")["jobs"])
	var build := PackBuild.new()
	build.frame_usec = 0
	build.start("pack-4", fake)
	# Put in place by the fake; taken back to the work folder for the real one.
	Fakes.run(build)
	assert_eq(build.state, "done", str(build.outcome))
	var host := Scratch.new()
	var final := host.folder().path_join("Pack-4-Homelands.zip")
	var work := host.folder().path_join(PackBuildHost.BUILDING)
	DirAccess.make_dir_recursive_absolute(work)
	var staged := work.path_join("Pack-4-Homelands.zip")
	assert_eq(DirAccess.rename_absolute(final, staged), OK)
	assert_true(bool(host.judge("pack-4", staged).get("ok", false)), "its own contract says yes")
	assert_false(bool(host.judge("pack-5", staged).get("ok", true)), "it is not Pack 5")
	assert_false(bool(host.judge("base", staged).get("ok", true)), "nor the 1997 pictures")
	assert_false(PackSeal.sealed(PackSeal.fingerprint(staged)))
	assert_eq(host.place("pack-4", staged), "")
	assert_true(FileAccess.file_exists(final))
	assert_false(FileAccess.file_exists(staged))
	assert_true(PackSeal.sealed(PackSeal.fingerprint(final)), "the rescan need not read its pictures again")
	# A file of that name already there (a refused one) is replaced.
	Fakes.write(staged, "newer".to_utf8_buffer())
	assert_eq(host.place("base", staged), "")
	assert_eq(FileAccess.get_file_as_string(final), "newer")


func test_the_art_zip_rule_judges_the_1997_pictures() -> void:
	var host := Scratch.new()
	DirAccess.make_dir_recursive_absolute(host.folder())
	var art := host.folder().path_join("cardart.zip")
	var packer := ZIPPacker.new()
	packer.open(art)
	packer.start_file("skin/cardart/air_elemental.jpg")
	packer.write_file(Fakes.jpeg("air"))
	packer.close_file()
	packer.close()
	var report := host.judge("base", art)
	assert_true(bool(report.get("ok", false)), String(report.get("why", "")))
	assert_eq(host.judge("base", host.folder().path_join("other.zip")).get("why"),
		"it is not named as base must be")
	var skin := host.folder().path_join("a_skin/cardart.zip")
	DirAccess.make_dir_recursive_absolute(skin.get_base_dir())
	packer = ZIPPacker.new()
	packer.open(skin)
	packer.start_file("skin/title.png")
	packer.write_file(Fakes.jpeg("not art"))
	packer.close_file()
	packer.close()
	assert_false(bool(host.judge("base", skin).get("ok", true)), "a skin is not card art")
	assert_eq(host.judge("base", skin).get("why"), "it is not a card art zip")


func test_the_zip_writer_s_entries_are_what_the_engine_reads() -> void:
	# The deflate stream and CRC cut out of the engine's gzip are a zip
	# entry's: the engine's own reader gives the bytes back.
	var payload := Fakes.jpeg("the same bytes ".repeat(500))
	var packed := PackWriter.deflated(payload)
	assert_eq(packed.size(), 2)
	assert_lt((packed[1] as PackedByteArray).size(), payload.size())
	assert_eq(PackWriter.deflated(PackedByteArray()), [0, PackedByteArray([0x03, 0x00])])
	assert_gt(payload.size(), 7000)
	var recipe := {"file_name": "cardart.zip", "prefix": "", "manifest": {}, "metadata": {},
		"entries": [["skin/cardart/a.jpg", "a.jpg"], ["skin/cardart/b.jpg", "b.jpg"]], "max_bytes": 0}
	var cache := SCRATCH.path_join("cache")
	DirAccess.make_dir_recursive_absolute(cache)
	Fakes.write(cache.path_join("a.jpg"), payload)
	Fakes.write(cache.path_join("b.jpg"), Fakes.jpeg(""))
	var writer := PackWriter.new()
	writer.start(recipe, cache, SCRATCH.path_join("out"))
	while writer.step():
		pass
	assert_eq(writer.state, "done", writer.problem_text)
	var reader := ZIPReader.new()
	assert_eq(reader.open(writer.path), OK)
	assert_eq(Array(reader.get_files()), ["skin/cardart/a.jpg", "skin/cardart/b.jpg"],
		"two entries and no folder entry")
	assert_true(reader.read_file("skin/cardart/a.jpg") == payload, "the first comes back whole")
	assert_true(reader.read_file("skin/cardart/b.jpg") == Fakes.jpeg(""), "and the second")
	reader.close()
	assert_true(PortalPack.bounded_zip(writer.path, 2), "the pack contracts' own directory guard reads it")
	writer.abandon()
	assert_false(FileAccess.file_exists(SCRATCH.path_join("out/cardart.zip")), "abandoned, it leaves nothing")
