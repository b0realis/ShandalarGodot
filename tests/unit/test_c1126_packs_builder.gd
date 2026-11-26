extends GutTest
## THE PACK BUILDER, SMOOTHER AND TIDIER (campaign 2026-11-26): a pack's
## card list is read on a thread when the window asks for that, the card
## pool takes new packs in on a thread ([method CardPacks.rescan]), and
## the pictures kept for a pack that is installed are removed — safely.
## No socket, no real catalogue changed, everything in the test profile.

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1126_packs_builder"

var _host: Fakes.Host


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_host = Fakes.host(SCRATCH)


func after_each() -> void:
	Fakes.wipe(SCRATCH)


func _threads() -> bool:
	return OS.has_feature("threads") and not OS.has_feature("web")


## Step to the end, giving the thread time rather than spinning on it.
func _run(build: PackBuild, most := 400000) -> void:
	var steps := 0
	while build.step() and steps < most:
		steps += 1
		if build.phase == "preparing":
			OS.delay_msec(1)


func _final(id: String) -> String:
	return _host.folder().path_join(String(PackRecipes.about(id)["file_name"]))


func test_the_card_list_is_read_aside_and_the_pack_is_built_all_the_same() -> void:
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var build := PackBuild.new()
	build.frame_usec = 0
	build.aside = true
	var started := Time.get_ticks_usec()
	build.start("pack-2", _host)
	var took := Time.get_ticks_usec() - started
	if _threads():
		assert_eq(build.phase, "preparing", "start comes back before the list is read")
		assert_eq(build.fetch.state, "idle", "the fetch is there, not begun")
		assert_eq(build.line(), "reading the card list")
		assert_eq(build.fraction(), 0.0)
		gut.p("start with the list read aside: %.1f ms" % (took / 1000.0))
	assert_eq(build.state, "working")
	_run(build)
	assert_eq(build.state, "done", str(build.outcome))
	assert_true(bool(build.outcome["ok"]))
	assert_true(FileAccess.file_exists(_final("pack-2")))
	assert_false(DirAccess.dir_exists_absolute(_host.cache_root().path_join("pack-2")), "its cache went")


func test_without_aside_start_is_what_it_was() -> void:
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var build := PackBuild.new()
	build.frame_usec = 0
	build.start("pack-2", _host)
	assert_eq(build.phase, "downloading")
	assert_not_null(build.fetch)
	build.stop()


func test_what_start_refuses_is_still_refused_aside() -> void:
	# A locked catalogue is said at once, thread or no thread.
	_host.locked = "A LAN table is open."
	var build := PackBuild.new()
	build.aside = true
	build.start("pack-2", _host)
	assert_eq(build.state, "failed")
	assert_eq(String(build.outcome["kind"]), "locked")
	_host.locked = ""
	# Too little room is said once the list is read.
	_host.free = 1024 * 1024
	build = PackBuild.new()
	build.aside = true
	build.start("pack-2", _host)
	_run(build)
	assert_eq(build.state, "failed")
	assert_eq(String(build.outcome["kind"]), "disk")
	# A pack this build has no list for.
	_host.free = -1
	build = PackBuild.new()
	build.aside = true
	build.start("pack-99", _host)
	_run(build)
	assert_eq(build.state, "failed")
	assert_eq(String(build.outcome["kind"]), "refused")


func test_stop_while_the_list_is_read_ends_cleanly() -> void:
	var build := PackBuild.new()
	build.aside = true
	build.start("pack-8", _host)
	build.stop()
	assert_eq(build.state, "stopped")
	assert_null(build._thread, "the thread was joined")
	assert_false(build.step())


# ------------------------------------------------------- the stale cache --

func _cache_of(id: String, pictures: int) -> String:
	var folder := _host.cache_root().path_join(id)
	for n in pictures:
		Fakes.write(folder.path_join("set%d" % (n % 3)).path_join("card_%d.jpg" % n), Fakes.jpeg("p%d" % n))
	Fakes.write(folder.path_join("answers.json"), "{}".to_utf8_buffer())
	return folder


func _sweep_all() -> int:
	var steps := 0
	while _host.sweep_step() and steps < 1000:
		steps += 1
	return steps


func test_the_cache_of_an_installed_pack_goes_and_no_other() -> void:
	var installed := _cache_of("pack-2", 450)
	var unfinished := _cache_of("pack-4", 7)
	var elsewhere := _cache_of("pack-5", 3)
	var refused := _cache_of("pack-6", 3)
	_host.states["pack-2"] = {"state": "installed", "note": ""}
	_host.states["pack-5"] = {"state": "elsewhere", "note": ""}
	_host.states["pack-6"] = {"state": "refused", "note": "x"}
	# Installed, and nothing cached: not named.
	_host.states["pack-3"] = {"state": "installed", "note": ""}
	# A folder that is no pack's is never looked at.
	Fakes.write(_host.cache_root().path_join("holiday").path_join("photo.jpg"), Fakes.jpeg("mine"))
	var stale := _host.stale_caches()
	assert_eq(stale, ["pack-2"] as Array[String])
	_host.sweep(stale)
	assert_true(_host.sweep_step(), "451 files are more than one step's worth")
	assert_true(DirAccess.dir_exists_absolute(installed), "a step removes a little")
	_sweep_all()
	assert_false(DirAccess.dir_exists_absolute(installed), "the installed pack's pictures are gone")
	for kept: String in [unfinished, elsewhere, refused]:
		assert_true(FileAccess.file_exists(kept.path_join("answers.json")), kept)
		assert_true(FileAccess.file_exists(kept.path_join("set0/card_0.jpg")), kept)
	assert_true(FileAccess.file_exists(_host.cache_root().path_join("holiday/photo.jpg")))
	assert_eq(_host.stale_caches(), [] as Array[String])
	assert_false(_host.sweep_step(), "nothing more to do")


func test_the_sweep_takes_only_names_it_knows() -> void:
	var outside := SCRATCH.path_join("outside")
	Fakes.write(outside.path_join("keep.txt"), "keep".to_utf8_buffer())
	_cache_of("pack-2", 2)
	var asked: Array[String] = ["../outside", "holiday", "", ".", "pack-2/../../outside"]
	_host.sweep(asked)
	_sweep_all()
	assert_true(FileAccess.file_exists(outside.path_join("keep.txt")))
	assert_true(DirAccess.dir_exists_absolute(_host.cache_root().path_join("pack-2")))
	assert_true(DirAccess.dir_exists_absolute(_host.cache_root()), "the cache's own folder stays")


func test_a_link_in_the_cache_is_removed_and_never_followed() -> void:
	if OS.get_name() == "Windows":
		pass_test("links need rights there")
		return
	var outside := SCRATCH.path_join("outside")
	Fakes.write(outside.path_join("keep.txt"), "keep".to_utf8_buffer())
	Fakes.write(outside.path_join("deep/keep.txt"), "keep".to_utf8_buffer())
	var folder := _cache_of("pack-2", 2)
	var dir := DirAccess.open(folder)
	var made := dir.create_link(ProjectSettings.globalize_path(outside), ProjectSettings.globalize_path(folder.path_join("away")))
	var made_file := dir.create_link(ProjectSettings.globalize_path(outside.path_join("keep.txt")),
		ProjectSettings.globalize_path(folder.path_join("away.txt")))
	if made != OK or made_file != OK:
		pass_test("this disk makes no links")
		return
	_host.states["pack-2"] = {"state": "installed", "note": ""}
	_host.sweep(_host.stale_caches())
	_sweep_all()
	assert_true(FileAccess.file_exists(outside.path_join("keep.txt")), "what the link pointed at stays")
	assert_true(FileAccess.file_exists(outside.path_join("deep/keep.txt")))
	assert_false(DirAccess.dir_exists_absolute(folder), "and the cache, links and all, is gone")


# ----------------------------------------------------------- the rescan --

func test_rescan_in_the_background_comes_back_before_the_pool() -> void:
	if not _threads():
		pass_test("no threads here: the pool is built in place")
		return
	CardRegistry.ensure_loaded()
	var cards := CardRegistry.size()
	var seen := [0]
	var count := func() -> void: seen[0] += 1
	CardPacks.rescanned.connect(count)
	CardPacks.rescan(true)
	CardPacks.rescanned.disconnect(count)
	assert_eq(seen[0], 1)
	assert_true(CardRegistry.is_loading(), "the pool is being built on its thread")
	var host := PackBuildHost.new()
	assert_true(host.settling())
	var waited := 0
	while host.settling() and waited < 20000:
		OS.delay_msec(1)
		waited += 1
	assert_false(host.settling())
	assert_eq(CardRegistry.size(), cards, "the same pool as before")
	# And the plain rescan is what it was: done when it returns.
	CardPacks.rescan()
	assert_false(CardRegistry.is_loading())
	assert_eq(CardRegistry.size(), cards)
