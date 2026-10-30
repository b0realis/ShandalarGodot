extends GutTest
## THE CARD ART DECODED BEFORE IT IS ASKED FOR ([CardArtWarmer]; the owner,
## 2026-10-23: the first F1 of a session, "can we do something in the
## background before user even comes to f1 - in parallel?"). Pictures are
## decoded on a worker thread and handed to the art caches a few a frame,
## so the first deck builder finds them kept.
##
## The pictures here are made by the test (no card art ships), and kept
## under names no card has, which are let go after each test.

const FOLDER := "user://card_art_warmer_tests"
const NAMES: Array[String] = ["Warmer Probe One", "Warmer Probe Two", "Warmer Probe Three"]

var holder: Node


func before_each() -> void:
	DirAccess.make_dir_recursive_absolute(FOLDER)
	holder = Node.new()
	add_child_autofree(holder)


func after_each() -> void:
	for card_name in NAMES:
		GameSkin._art_cache.erase("cardart/" + GameSkin._snake(card_name))
		GameSkin._art_missing.erase("cardart/" + GameSkin._snake(card_name))
	var dir := DirAccess.open(FOLDER)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(FOLDER)


## A picture on disk for [param card_name], as a skin's card art would be.
func _picture(card_name: String, size := Vector2i(64, 48)) -> String:
	var image := Image.create(size.x, size.y, false, Image.FORMAT_RGB8)
	image.fill(Color(0.6, 0.2, 0.1))
	var path := ProjectSettings.globalize_path(FOLDER.path_join(GameSkin._snake(card_name) + ".png"))
	image.save_png(path)
	return path


## A job of skin pictures for [param names], as [method CardArtWarmer._job_for]
## makes one.
func _job(names: Array[String]) -> CardArtWarmer.Job:
	var job := CardArtWarmer.Job.new()
	for card_name in names:
		job.paths.append(_picture(card_name))
		job.skin_names.append(card_name)
	job.images.resize(job.paths.size())
	return job


func _until_finished(warmer: CardArtWarmer) -> void:
	for i in 300:
		if not is_instance_valid(warmer) or warmer.finished():
			return
		await get_tree().process_frame


func test_the_pictures_are_decoded_aside_and_kept() -> void:
	var warmer := CardArtWarmer._start(holder, _job(NAMES))
	assert_not_null(warmer, "three pictures to decode")
	# Under the tree's root, joined at the end of the frame (the bug
	# campaign of 0.50.66, h1-3): the caches', not the asker's.
	assert_eq(holder.get_child_count(), 0)
	for card_name in NAMES:
		assert_false(GameSkin.card_art_known(card_name), "not kept before the worker")
	await _until_finished(warmer)
	for card_name in NAMES:
		assert_true(GameSkin.card_art_known(card_name), "%s kept" % card_name)
		var art := GameSkin.card_art(card_name)
		assert_not_null(art, "and handed out from the cache")
		assert_eq(art.get_size(), Vector2(64, 48))
	await get_tree().process_frame
	assert_false(is_instance_valid(warmer), "the warmer frees itself when done")


func test_a_picture_kept_already_wins() -> void:
	var first := GameSkin.keep_card_art(NAMES[0], GameSkin.decode_card_art(_picture(NAMES[0])))
	var warmer := CardArtWarmer._start(holder, _job(NAMES))
	await _until_finished(warmer)
	assert_same(GameSkin.card_art(NAMES[0]), first, "the texture on show is not swapped")


func test_an_empty_job_starts_nothing() -> void:
	assert_null(CardArtWarmer._start(holder, CardArtWarmer.Job.new()))
	assert_eq(holder.get_child_count(), 0)


func test_leaving_stops_the_worker_and_keeps_nothing_half_done() -> void:
	var names: Array[String] = []
	for i in 40:
		names.append("Warmer Probe One %d" % i)
	var job := _job(names)
	var warmer := CardArtWarmer._start(holder, job)
	await get_tree().process_frame      # joined the root
	warmer.get_parent().remove_child(warmer)
	warmer.free()
	assert_true(job.stop, "the worker was asked to stop")
	var done_then := job.done
	for i in 5:
		await get_tree().process_frame
	assert_eq(job.done, done_then, "and has ended: freeing waited for it")
	for card_name in names:
		GameSkin._art_cache.erase("cardart/" + GameSkin._snake(card_name))


func test_a_registry_rebuilt_meanwhile_drops_the_pictures() -> void:
	var warmer := CardArtWarmer._start(holder, _job(NAMES))
	CardRegistry.revision += 1
	await _until_finished(warmer)
	CardRegistry.revision -= 1
	for card_name in NAMES:
		assert_false(GameSkin._art_cache.has("cardart/" + GameSkin._snake(card_name)),
			"%s not kept: its path may be another's now" % card_name)


func test_the_files_found_are_each_once_and_bounded() -> void:
	CardRegistry.ensure_loaded()
	var names: Array[String] = []
	for card_name in CardRegistry.all_names():
		names.append(String(card_name))
		names.append(String(card_name))
	var job := CardArtWarmer._job_for(names)
	assert_true(job.paths.size() <= CardArtWarmer.MOST, "no more than MOST in one warm")
	var seen := {}
	for path in job.paths:
		assert_false(seen.has(path), "each file once: %s" % path)
		seen[path] = true
	assert_eq(job.images.size(), job.paths.size())
	var unknown: Array[String] = ["No Such Card Anywhere"]
	assert_true(CardArtWarmer._job_for(unknown).paths.is_empty(), "a name no card has is passed over")
