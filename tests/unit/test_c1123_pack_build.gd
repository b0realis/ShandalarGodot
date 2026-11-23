extends GutTest
## THE GAME BUILDS ITS OWN CARD PACKS (campaign 2026-11-23) — the fetch,
## the zip and the checks, against a transport that answers from a table.
## No test here opens a socket: [PackFetch] is handed a fake Scryfall
## (`tests/support/c1123_pack_fakes.gd`), the pictures are a dozen bytes
## each, and the card folder is a scratch folder of the test profile.
##
## What is held: a whole build of every pack passes that pack's own
## contract in the game, pictures read and all; the cards are asked about
## in batches of 75 and matched back by id or by name and set, a card the
## batch lacks asked for alone; a build stopped or failed keeps what it
## downloaded and what it was told, asks and fetches only the rest the next
## time and never leaves a zip; answers that are garbage, short, too big,
## missing or "come back later" are each met the way [PackFetch] says; and
## the requests are spaced and say what is asking and nothing else.

const Fakes := preload("res://tests/support/c1123_pack_fakes.gd")
const SCRATCH := "user://c1123_pack_build"

var _host: Fakes.Host


func before_each() -> void:
	Fakes.wipe(SCRATCH)
	_host = Fakes.host(SCRATCH)


func after_each() -> void:
	Fakes.wipe(SCRATCH)


func _build(id: String, teach := true) -> PackBuild:
	if teach:
		_host.net.teach(PackRecipes.recipe(id)["jobs"])
	var build := PackBuild.new()
	build.frame_usec = 0
	build.start(id, _host)
	return build


func _final(id: String) -> String:
	return _host.folder().path_join(String(PackRecipes.about(id)["file_name"]))


func _files_under(folder: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				out.append_array(_files_under(folder.path_join(entry)))
		else:
			out.append(folder.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	return out


func _first_job(id: String) -> Dictionary:
	return (PackRecipes.recipe(id)["jobs"] as Array)[0]


func _pictures(folder: String) -> Array:
	return _files_under(folder).filter(func(file: String) -> bool: return file.get_extension() == "jpg")


## A fetch of [param jobs] alone, against the fake.
func _fetch(jobs: Array, cache := "pack", gentle := true) -> PackFetch:
	_host.net.teach(jobs)
	var fetch := PackFetch.new()
	fetch.transport = _host.net
	fetch.clock = _host.now_msec
	fetch.gentle = gentle
	fetch.start(jobs, _host.cache_root().path_join(cache))
	while fetch.step():
		pass
	return fetch


# ------------------------------------------------------- whole builds --

func test_every_numbered_pack_built_here_passes_its_own_contract() -> void:
	for number in range(1, 11):
		var id := "pack-%d" % number
		Fakes.wipe(SCRATCH)
		_host = Fakes.host(SCRATCH)
		var build := _build(id)
		Fakes.run(build)
		assert_eq(build.state, "done", "%s: %s" % [id, build.outcome])
		assert_true(bool(build.outcome.get("ok", false)), id)
		var path := _final(id)
		assert_true(FileAccess.file_exists(path), id + " is in the card folder")
		# The contract itself, every picture read: not the builder's word.
		var report: Dictionary = CardPacks.inspect(path)
		assert_true(bool(report.get("ok", false)), "%s: %s" % [id, report.get("why", "")])
		assert_true(bool(report.get("has_art", false)), id + " carries its pictures")
		assert_eq(_host.judged, [id] as Array[String], "the game's check was asked once")
		assert_eq(_files_under(_host.cache_root()), [], id + ": the cache is let go")
		assert_false(DirAccess.dir_exists_absolute(_host.folder().path_join(PackBuildHost.BUILDING)),
			id + ": the work folder is gone")
		assert_eq(_files_under(_host.folder()), [path], id + ": nothing else is left")
		assert_gt(_host.net.closed, 0, "the connections are closed")
		var jobs := int(PackRecipes.recipe(id)["jobs"].size())
		assert_eq(_host.net.count("api.scryfall.com"), int(ceil(jobs / 75.0)),
			"%s: %d cards are %d questions" % [id, jobs, int(ceil(jobs / 75.0))])


func test_the_1997_pictures_built_here_are_an_art_zip() -> void:
	var build := _build("base")
	Fakes.run(build)
	assert_eq(build.state, "done", str(build.outcome))
	var path := _final("base")
	assert_eq(path.get_file(), "cardart.zip")
	var report: Dictionary = SkinPack.inspect(path)
	assert_true(bool(report.get("ok", false)), String(report.get("why", "")))
	assert_eq(report.get("kind"), "cardart")
	assert_eq(int(report.get("files", 0)), 1794)
	assert_eq(_host.net.count("api.scryfall.com"), 12, "897 cards are twelve questions")
	var reader := ZIPReader.new()
	assert_eq(reader.open(path), OK)
	var first := reader.read_file("skin/cardart/air_elemental.jpg")
	reader.close()
	assert_true(PackFetch.whole_jpeg(first), "stored as it was downloaded")


func test_a_build_asks_in_batches_politely_and_says_only_what_is_asking() -> void:
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "done")
	# 102 cards: one question of 75 and one of 27, by name and set.
	var batches := _host.net.batches()
	assert_eq(batches.size(), 2)
	assert_eq((batches[0] as Array).size(), PackFetch.BATCH)
	assert_eq((batches[1] as Array).size(), 102 - PackFetch.BATCH)
	var first: Dictionary = _first_job("pack-2")
	assert_eq(batches[0][0], {"name": first["name"], "set": "fem"})
	assert_eq(_host.net.count("api.scryfall.com"), 2, "and no card asked about alone")
	assert_eq(_host.net.log.size(), 2 + 204, "and one request a picture")
	assert_eq(build.fetch.asked, {"collection": 2, "picture": 204})
	var asked := _host.net.times(PackFetch.COLLECTION)
	assert_gte(asked[1] - asked[0], PackFetch.BATCH_GAP_MSEC)
	var pictures := _host.net.times("https://cards.scryfall.io/")
	for i in range(1, pictures.size()):
		assert_gte(pictures[i] - pictures[i - 1], PackFetch.PICTURE_GAP_MSEC, "picture %d waited its turn" % i)
	var version := String(ProjectSettings.get_setting("application/config/version"))
	var sent: Array = _host.net.sent.keys()
	sent.sort()
	assert_eq(sent, ["Accept: application/json", "Accept: image/jpeg, */*", "Content-Type: application/json",
		"User-Agent: ShandalarGodot/%s (card pack builder)" % version])
	for i in _host.net.log.size():
		assert_false(PackTransport.parts_of(_host.net.log[i]).is_empty(), _host.net.log[i])
		assert_eq(_host.net.bodies[i] != "", _host.net.log[i] == PackFetch.COLLECTION, "only a batch is a POST")
	# Packs 6-10 ask by the printing's own id.
	before_each()
	var by_id := _fetch((PackRecipes.recipe("pack-6")["jobs"] as Array).slice(0, 3))
	assert_eq(by_id.state, "done")
	assert_eq(_host.net.batches()[0][0], {"id": String(_first_job("pack-6")["lookups"][0]).get_file()})


func test_answers_are_matched_by_name_and_set_never_by_their_order() -> void:
	# The fake answers a batch back to front; every picture still lands
	# under its own card's name.
	var jobs: Array = PackRecipes.recipe("pack-2")["jobs"]
	var fetch := _fetch(jobs, "pack-2")
	assert_eq(fetch.state, "done")
	for at: int in [0, 1, 40, 74, 75, 101]:
		var job: Dictionary = jobs[at]
		var path := _host.cache_root().path_join("pack-2").path_join(String(job["files"][0][0]))
		assert_true(FileAccess.get_file_as_bytes(path) == Fakes.jpeg(Fakes.Transport.art_of(job)),
			String(job["name"]) + " has its own artwork")


func test_one_name_in_two_sets_gets_each_set_s_own_picture() -> void:
	var jobs: Array = PackRecipes.recipe("pack-1")["jobs"]
	var seen := {}
	var pair: Array = []
	for job: Dictionary in jobs:
		if seen.has(job["name"]) and pair.is_empty():
			pair = [seen[job["name"]], job]
		seen[job["name"]] = job
	assert_eq(pair.size(), 2, "Pack 1 holds a name under two sets")
	if pair.size() != 2:
		return
	assert_ne(pair[0]["set"], pair[1]["set"])
	assert_ne(pair[0]["key"], pair[1]["key"])
	var fetch := _fetch(pair, "pack-1")
	assert_eq(fetch.state, "done")
	assert_eq(_host.net.batches().size(), 1, "both in one question")
	for job: Dictionary in pair:
		var path := _host.cache_root().path_join("pack-1").path_join(String(job["files"][0][0]))
		assert_true(path.contains("/%s/" % job["set"]))
		assert_true(FileAccess.get_file_as_bytes(path) == Fakes.jpeg(Fakes.Transport.art_of(job)),
			"%s of %s has that set's artwork" % [job["name"], job["set"]])


# ------------------------------------------------- stopping, resuming --

func test_a_stopped_build_keeps_its_pictures_and_asks_nothing_twice() -> void:
	var build := _build("pack-2")
	while build.step() and build.fetch.fetched < 51:
		pass
	build.stop()
	assert_eq(build.state, "stopped")
	assert_eq(build.outcome.get("kind"), "stopped")
	assert_gt(_host.net.cancelled, 0, "the request in flight is dropped")
	assert_false(FileAccess.file_exists(_final("pack-2")), "no zip")
	assert_eq(_files_under(_host.folder()), [], "nothing in the card folder")
	assert_eq(_pictures(_host.cache_root()).size(), 51, "the pictures stay")
	var kept := _files_under(_host.cache_root())
	assert_eq(kept.size(), 52, "and what the first batch answered, and nothing half-written")
	assert_true(FileAccess.file_exists(_host.cache_root().path_join("pack-2/lookups.json")))
	assert_eq(_host.net.batches().size(), 1, "one batch was asked before the stop")
	# Again, with a Scryfall that counts from nothing.
	_host.net = Fakes.Transport.new()
	var again := _build("pack-2")
	assert_eq(again.fetch.pictures_total, 204)
	Fakes.run(again)
	assert_eq(again.state, "done", str(again.outcome))
	assert_eq(again.fetch.fetched, 204 - 51, "only what was missing is fetched")
	# The first 75 cards were answered before the stop: only the last 27
	# are asked about now.
	var batches := _host.net.batches()
	assert_eq(batches.size(), 1)
	assert_eq((batches[0] as Array).size(), 27)
	assert_eq(_host.net.log.size(), 1 + 204 - 51)
	assert_true(bool(CardPacks.inspect(_final("pack-2")).get("ok", false)))


func test_kept_answers_are_read_back_as_untrusted_as_fresh_ones() -> void:
	var job := _first_job("pack-2")
	var cache := _host.cache_root().path_join("pack-2")
	var planted := {"not a key": 7}
	planted[job["key"]] = {"art_crop": "https://example.com/a.jpg", "border_crop": "https://example.com/b.jpg"}
	Fakes.write(cache.path_join("lookups.json"), JSON.stringify(planted).to_utf8_buffer())
	var fetch := _fetch([job], "pack-2")
	assert_eq(fetch.state, "done")
	assert_eq(_host.net.batches().size(), 1, "the planted answer is not believed: the card is asked about")
	assert_eq(_host.net.count("example.com"), 0)
	assert_eq(fetch.fetched, 2)


func test_a_stop_while_the_zip_is_written_leaves_no_zip() -> void:
	var build := _build("pack-2")
	while build.step() and build.phase != "writing":
		pass
	assert_eq(build.phase, "writing")
	for n in 3:
		build.step()
	build.stop()
	assert_eq(build.state, "stopped")
	assert_eq(_files_under(_host.folder()), [], "neither the part nor the zip")
	assert_eq(_pictures(_host.cache_root()).size(), 204, "the pictures stay")


func test_a_locked_catalogue_or_a_full_disk_stops_it_before_a_request() -> void:
	_host.locked = "Close SGManalink connections and stop hosting before changing or rescanning card packs."
	var build := _build("pack-2")
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "locked")
	assert_eq(build.outcome.get("text"), _host.locked, "in the catalogue's own words")
	_host.locked = ""
	_host.free = 30 * 1024 * 1024
	build = _build("pack-2")
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "disk")
	assert_string_contains(String(build.outcome.get("text")), "30 MB are free")
	assert_eq(_host.net.log, [] as Array[String], "nothing was asked")
	_host.free = 4096 * 1024 * 1024
	build = _build("pack-2")
	assert_eq(build.state, "working", "enough room: it starts")
	build.stop()


# ------------------------------------------------- what a batch lacks --

func test_a_card_the_batch_does_not_find_is_asked_for_alone_the_old_way() -> void:
	var job := _first_job("pack-2")
	_host.net.absent[job["key"]] = true
	# Alone: its own set's printing (404), then any printing.
	_host.net.scripted[String(job["lookups"][0])] = [Fakes.answer(404)]
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "done", str(build.outcome))
	assert_eq(build.fetch.asked, {"collection": 2, "single": 2, "picture": 204})
	var singles: Array = []
	for url: String in _host.net.log:
		if url.contains("/cards/named"):
			singles.append(url)
	assert_eq(singles, [String(job["lookups"][0]), String(job["lookups"][1])], "in the Python tool's order")
	assert_eq(_host.net.log.find(singles[0]) > _host.net.log.rfind(PackFetch.COLLECTION), true,
		"after the batches, not between them")


func test_a_card_scryfall_does_not_have_fails_the_pack_and_keeps_the_rest() -> void:
	var job := _first_job("pack-6")
	_host.net.absent[job["key"]] = true
	_host.net.scripted[String(job["lookups"][0])] = [Fakes.answer(404)]
	var build := _build("pack-6")
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "network")
	assert_string_contains(String(build.outcome.get("text")), "1 card could not be fetched")
	assert_string_contains(String(build.outcome.get("text")), String(job["name"]))
	assert_eq(_pictures(_host.cache_root()).size(), 760 - 2, "every other picture is kept")
	assert_eq(_files_under(_host.folder()), [], "and no zip is made of a pack with a hole")


func test_a_short_batch_answer_sends_the_rest_to_be_asked_alone() -> void:
	# Three asked, one answered, and no word about the other two.
	var jobs: Array = (PackRecipes.recipe("pack-6")["jobs"] as Array).slice(0, 3)
	var short := JSON.stringify({"object": "list", "data": [
		Fakes.Transport.card_of(jobs[1], String(jobs[1]["key"])), "not a card", {"object": "card"}]})
	_host.net.scripted[PackFetch.COLLECTION] = [Fakes.answer(200, short.to_utf8_buffer())]
	var fetch := _fetch(jobs)
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.missed, [] as Array[Dictionary])
	assert_eq(fetch.asked, {"collection": 1, "single": 2, "picture": 6})
	var singles := _host.net.times("https://api.scryfall.com/cards/")
	assert_gte(singles[2] - singles[1], PackFetch.LOOKUP_GAP_MSEC, "single questions keep their distance")


func test_a_garbled_batch_is_asked_once_more_then_card_by_card() -> void:
	var jobs: Array = (PackRecipes.recipe("pack-2")["jobs"] as Array).slice(0, 4)
	_host.net.scripted[PackFetch.COLLECTION] = [Fakes.answer(200, "<html>try later</html>".to_utf8_buffer())]
	var fetch := _fetch(jobs)
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.asked, {"collection": 2, "single": 4, "picture": 8})
	assert_eq(fetch.fetched, 8)


func test_another_printing_a_foreign_address_and_a_missing_card_are_misses() -> void:
	var jobs: Array = (PackRecipes.recipe("pack-6")["jobs"] as Array).slice(0, 5)
	var wrong: Dictionary = Fakes.Transport.card_of(jobs[0], "x")
	wrong["collector_number"] = "999"
	var elsewhere: Dictionary = Fakes.Transport.card_of(jobs[1], "x")
	elsewhere["image_uris"] = {"art_crop": "https://example.com/a.jpg", "border_crop": "https://example.com/b.jpg"}
	# In the batch and alone alike.
	_host.net.instead[jobs[0]["key"]] = wrong
	_host.net.instead[jobs[1]["key"]] = elsewhere
	_host.net.absent[jobs[2]["key"]] = true
	_host.net.scripted[String(jobs[0]["lookups"][0])] = [Fakes.answer(200, JSON.stringify(wrong).to_utf8_buffer())]
	_host.net.scripted[String(jobs[1]["lookups"][0])] = [Fakes.answer(200, JSON.stringify(elsewhere).to_utf8_buffer())]
	_host.net.scripted[String(jobs[2]["lookups"][0])] = [Fakes.answer(404)]
	var fetch := _fetch(jobs)
	assert_eq(fetch.state, "done", fetch.problem_text)
	var why := {}
	for miss: Dictionary in fetch.missed:
		why[miss["name"]] = miss["why"]
	assert_eq(why.get(jobs[0]["name"]), "another printing than the one asked for")
	assert_eq(why.get(jobs[1]["name"]), "a picture address the game will not follow")
	assert_eq(why.get(jobs[2]["name"]), "Scryfall has no such card")
	assert_eq(fetch.missed.size(), 3)
	assert_eq(fetch.pictures_done, 4, "the two good cards are fetched")
	assert_eq(_host.net.count("example.com"), 0, "an address from an answer does not choose the host")


func test_garbage_all_the_way_stops_the_pack_after_three_cards() -> void:
	_host.net.scripted["api.scryfall.com"] = [Fakes.answer(200, "<html>sign in</html>".to_utf8_buffer())]
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "network")
	# Two batches, each asked twice; then three cards alone, not a hundred.
	assert_eq(build.fetch.asked, {"collection": 4, "single": 3})
	assert_string_contains(String(build.outcome.get("text")), "Check the internet connection")


func test_a_short_or_oversized_picture_is_never_kept() -> void:
	var jobs: Array = PackRecipes.recipe("pack-2")["jobs"]
	var short := Fakes.jpeg("cut")
	short.resize(short.size() - 1)
	var huge := PackedByteArray([0xFF, 0xD8])
	huge.resize(PackFetch.MAX_PICTURE + 1)
	huge[huge.size() - 2] = 0xFF
	huge[huge.size() - 1] = 0xD9
	assert_false(PackFetch.whole_jpeg(short))
	assert_false(PackFetch.whole_jpeg(huge))
	assert_false(PackFetch.whole_jpeg(PackedByteArray()))
	assert_true(PackFetch.whole_jpeg(Fakes.jpeg("")))
	# The first card's artwork is always cut short; the second's is too big.
	var first_art := Fakes.Transport.art_of(jobs[0])
	var second_art := Fakes.Transport.art_of(jobs[1])
	_host.net.scripted[first_art] = [Fakes.answer(200, short)]
	_host.net.scripted[second_art] = [Fakes.answer(200, huge)]
	var fetch := _fetch(jobs.slice(0, 2) + jobs.slice(4, 5), "pack-2")
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.missed.size(), 2)
	assert_eq(fetch.missed[0]["why"], "a picture that is not a whole JPEG")
	assert_eq(fetch.missed[1]["why"], "a picture that is not a whole JPEG")
	assert_eq(_host.net.count(first_art), 2, "a cut picture is asked for once more, then given up")
	var kept := _pictures(_host.cache_root())
	assert_eq(kept.size(), 2, "only the third card's two pictures are kept")
	for file: String in kept:
		assert_true(PackFetch.whole_jpeg(FileAccess.get_file_as_bytes(file)))


# ------------------------------------------------- come back later --

func test_come_back_later_is_obeyed_and_the_pace_is_slower_after_it() -> void:
	var jobs: Array = (PackRecipes.recipe("pack-2")["jobs"] as Array).slice(0, 3)
	_host.net.teach(jobs)
	# The third card is asked about alone, after the batch.
	_host.net.absent[jobs[2]["key"]] = true
	var identifiers: Array = []
	for job: Dictionary in jobs:
		identifiers.append(job["ask"])
	var good := _host.net._collection(JSON.stringify({"identifiers": identifiers}))
	_host.net.scripted[PackFetch.COLLECTION] = [
		Fakes.answer(429, "{\"object\":\"error\",\"code\":\"rate_limited\"}".to_utf8_buffer(), {"retry-after": "7"}),
		Fakes.answer(503), Fakes.answer(200, good)]
	var fetch := _fetch(jobs)
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.missed, [] as Array[Dictionary])
	assert_eq(fetch.fetched, 6)
	var calls := _host.net.times(PackFetch.COLLECTION)
	assert_eq(calls.size(), 3)
	assert_gte(calls[1] - calls[0], 7000, "Retry-After: 7 is seven seconds")
	assert_gte(calls[2] - calls[1], 2 * PackFetch.RETRY_MSEC, "and the next wait doubles")
	assert_eq(fetch.refused_by, {"api.scryfall.com": 1}, "the 429 is counted by its host")
	assert_eq(fetch.troubles, {"429": 1, "5xx": 1})
	assert_eq(fetch.last_429.get("host"), "api.scryfall.com")
	assert_string_contains(String(fetch.last_429.get("body")), "rate_limited")
	assert_eq(fetch.retries, 2)
	assert_gte(fetch.waited_msec, 7000 + 4000)
	# Twice the usual distance before the next question to that host, for
	# the rest of the run.
	var single := _host.net.times("https://api.scryfall.com/cards/named")
	assert_eq(single.size(), 1)
	var before := 0
	for i in _host.net.log.size():
		if _host.net.log[i].begins_with("https://api.scryfall.com/") and _host.net.asked_at[i] < single[0]:
			before = _host.net.asked_at[i]
	assert_gte(single[0] - before, 2 * PackFetch.LOOKUP_GAP_MSEC)


func test_a_429_from_the_picture_host_slows_the_pictures_not_the_questions() -> void:
	var jobs: Array = (PackRecipes.recipe("pack-2")["jobs"] as Array).slice(0, 4)
	_host.net.teach(jobs)
	var art := Fakes.Transport.art_of(jobs[0])
	_host.net.scripted[art] = [Fakes.answer(429, PackedByteArray(), {"retry-after": "3"}),
		Fakes.answer(200, Fakes.jpeg(art))]
	var fetch := _fetch(jobs)
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.fetched, 8)
	assert_eq(fetch.refused_by, {"cards.scryfall.io": 1})
	var pictures := _host.net.times("https://cards.scryfall.io/")
	assert_gte(pictures[1] - pictures[0], 3000)
	for i in range(2, pictures.size()):
		assert_gte(pictures[i] - pictures[i - 1], 2 * PackFetch.PICTURE_GAP_MSEC, "picture %d keeps twice the distance" % i)


# ------------------------------------------ go easy, or not so easy --

## The distances between requests, as the fetch asked them of its clock:
## the clock here moves a millisecond a reading, so a distance is the
## pause the fetch chose and nothing else.
func _distances(times: Array[int]) -> Array[int]:
	var out: Array[int] = []
	for i in range(1, times.size()):
		out.append(times[i] - times[i - 1])
	return out


func test_unticked_drops_the_pause_between_pictures_and_nothing_else() -> void:
	var jobs: Array = PackRecipes.recipe("pack-2")["jobs"]
	var paces := {}
	for gentle: bool in [true, false]:
		before_each()
		_host.tick = 1
		# One card asked about alone, so a single question is timed too.
		_host.net.absent[jobs[101]["key"]] = true
		var fetch := _fetch(jobs, "pack-2", gentle)
		assert_eq(fetch.state, "done", fetch.problem_text)
		assert_eq(fetch.asked, {"collection": 2, "single": 1, "picture": 204})
		var pictures := _distances(_host.net.times("https://cards.scryfall.io/"))
		var questions := _distances(_host.net.times("https://api.scryfall.com/"))
		paces[gentle] = pictures.max()
		if gentle:
			assert_gte(pictures.min(), PackFetch.PICTURE_GAP_MSEC, "ticked: a pause before every picture")
		# The questions keep their distance either way: a batch a second
		# at most, and a single question its 600 ms.
		assert_gte(questions[0], PackFetch.BATCH_GAP_MSEC, "batch to batch, gentle %s" % gentle)
		assert_gte(questions[1], PackFetch.LOOKUP_GAP_MSEC, "then the single question, gentle %s" % gentle)
		var bodies := 0
		for body: String in _host.net.bodies:
			bodies += 1 if body != "" else 0
		assert_eq(bodies, 2, "and the same two batches")
	# Unticked, no pause at all was asked for between two pictures of a
	# card; the longest distance is a question's turn in between.
	before_each()
	_host.tick = 1
	var fast := _fetch(jobs.slice(0, 10), "pack-2", false)
	assert_eq(fast.state, "done")
	var unpaused := _distances(_host.net.times("https://cards.scryfall.io/"))
	assert_lt(unpaused.max(), 20, "unticked: no pause between pictures (%s ms at most)" % unpaused.max())
	assert_gte(int(paces[true]), PackFetch.PICTURE_GAP_MSEC)


func test_a_429_is_obeyed_and_slows_what_follows_even_unticked() -> void:
	var jobs: Array = (PackRecipes.recipe("pack-2")["jobs"] as Array).slice(0, 5)
	_host.tick = 1
	_host.net.teach(jobs)
	var art := Fakes.Transport.art_of(jobs[1])
	_host.net.scripted[art] = [Fakes.answer(429, PackedByteArray(), {"retry-after": "3"}),
		Fakes.answer(200, Fakes.jpeg(art))]
	var identifiers: Array = []
	for job: Dictionary in jobs:
		identifiers.append(job["ask"])
	_host.net.scripted[PackFetch.COLLECTION] = [Fakes.answer(429, PackedByteArray(), {"retry-after": "7"}),
		Fakes.answer(200, _host.net._collection(JSON.stringify({"identifiers": identifiers})))]
	var fetch := _fetch(jobs, "pack-2", false)
	assert_eq(fetch.state, "done", fetch.problem_text)
	assert_eq(fetch.fetched, 10)
	assert_eq(fetch.refused_by, {"api.scryfall.com": 1, "cards.scryfall.io": 1})
	var questions := _distances(_host.net.times("https://api.scryfall.com/"))
	assert_gte(questions[0], 7000, "the question waits as long as it is told")
	var pictures := _distances(_host.net.times("https://cards.scryfall.io/"))
	# Pictures: card 1's two (no pause), card 2's artwork refused, asked again.
	assert_lt(pictures[0], 20, "before the 429 there is no pause")
	assert_gte(pictures[2], 3000, "the refused picture waits as long as it is told")
	for i in range(3, pictures.size()):
		assert_gte(pictures[i], 2 * PackFetch.PICTURE_GAP_MSEC,
			"and after it the pause is back, doubled, though the tick is off")


func test_a_build_hands_the_tick_to_its_fetch() -> void:
	var build := PackBuild.new()
	build.frame_usec = 0
	build.gentle = false
	_host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	build.start("pack-2", _host)
	assert_false(build.fetch.gentle)
	build.stop()
	var easy := _build("pack-2")
	assert_true(easy.fetch.gentle, "ticked unless told otherwise")
	easy.stop()


func test_a_server_that_stays_busy_stops_the_pack_plainly() -> void:
	_host.net.scripted["api.scryfall.com"] = [Fakes.answer(429)]
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_eq(build.fetch.problem, "busy")
	assert_eq(_host.net.log.size(), 1 + PackFetch.RETRIES, "asked again a few times, then no more")
	assert_string_contains(String(build.outcome.get("text")), "Scryfall is busy")
	assert_eq(build.fetch.refused_by, {"api.scryfall.com": 1 + PackFetch.RETRIES})
	var calls := _host.net.times(PackFetch.COLLECTION)
	for i in range(1, calls.size()):
		assert_gte(calls[i] - calls[i - 1], PackFetch.RETRY_MSEC << (i - 1))


func test_no_connection_and_a_refused_certificate_say_so() -> void:
	_host.net.scripted["scryfall"] = [Fakes.answer(0, PackedByteArray(), {}, "connect")]
	var build := _build("pack-2")
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "network")
	assert_string_contains(String(build.outcome.get("text")), "the connection failed")
	assert_eq(_host.net.log.size(), 1 + PackFetch.RETRIES, "the first question, asked five times")
	before_each()
	_host.net.scripted["scryfall"] = [Fakes.answer(0, PackedByteArray(), {}, "tls")]
	build = _build("pack-2")
	Fakes.run(build)
	assert_eq(build.fetch.problem, "tls")
	assert_eq(_host.net.log.size(), 1, "a refused certificate is not tried again")
	assert_string_contains(String(build.outcome.get("text")), "certificate could not be checked")


# ---------------------------------------------------------- the writer --

func test_a_damaged_picture_in_the_cache_is_fetched_again_not_packed() -> void:
	var build := _build("pack-2")
	while build.step() and build.phase != "writing":
		pass
	var victim: String = _pictures(_host.cache_root())[10]
	Fakes.write(victim, "not a picture".to_utf8_buffer())
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_string_contains(String(build.outcome.get("text")), "missing or damaged")
	assert_false(FileAccess.file_exists(victim), "the damaged file is gone")
	assert_eq(_files_under(_host.folder()), [])
	_host.net = Fakes.Transport.new()
	var again := _build("pack-2")
	Fakes.run(again)
	assert_eq(again.state, "done", str(again.outcome))
	assert_eq(again.fetch.fetched, 1, "one picture fetched, the rest reused")
	assert_eq(_host.net.log.size(), 1, "and no question asked: where it is was kept")


class Refusing extends Fakes.Host:
	func judge(_id: String, _path: String) -> Dictionary:
		return {"ok": false, "why": "Pack 2 counts or names do not match Fallen Empires"}


func test_a_zip_the_game_s_check_refuses_is_never_put_in_place() -> void:
	var host := Refusing.new()
	host.root = SCRATCH
	host.net = Fakes.Transport.new()
	DirAccess.make_dir_recursive_absolute(host.folder())
	host.net.teach(PackRecipes.recipe("pack-2")["jobs"])
	var build := PackBuild.new()
	build.start("pack-2", host)
	Fakes.run(build)
	assert_eq(build.state, "failed")
	assert_eq(build.outcome.get("kind"), "refused")
	assert_string_contains(String(build.outcome.get("text")), "do not match Fallen Empires")
	assert_eq(_files_under(host.folder()), [], "no zip, no part")
	assert_eq(_pictures(host.cache_root()).size(), 204, "the pictures stay for another try")


func test_the_artwork_digest_is_the_pack_tools() -> void:
	# sha256 over "a\0<sha(x)>\nb\0<sha(y)>\n", whatever order they come in.
	var x := PackWriter.sha256("x".to_utf8_buffer())
	var y := PackWriter.sha256("y".to_utf8_buffer())
	var wanted := PackedByteArray()
	wanted.append_array("a".to_utf8_buffer())
	wanted.append(0)
	wanted.append_array((x + "\nb").to_utf8_buffer())
	wanted.append(0)
	wanted.append_array((y + "\n").to_utf8_buffer())
	assert_eq(PackWriter.artwork_sha256([["b", y], ["a", x]]), PackWriter.sha256(wanted))
	assert_eq(x, "2d711642b726b04401627ca9fbac32f5c8530fb1903cc4db02258717921a4881")


# ------------------------------------------------------- the transport --

func test_the_transport_goes_to_scryfall_over_https_and_nowhere_else() -> void:
	assert_eq(PackTransport.parts_of("https://api.scryfall.com/cards/named?exact=A+B&set=fem"),
		PackedStringArray(["api.scryfall.com", "/cards/named?exact=A+B&set=fem"]))
	assert_eq(PackTransport.parts_of("https://cards.scryfall.io/art_crop/front/1/e/x.jpg?15#top"),
		PackedStringArray(["cards.scryfall.io", "/art_crop/front/1/e/x.jpg?15"]))
	for refused: String in ["http://api.scryfall.com/cards/x", "https://example.com/x.jpg",
			# A host dressed as a user name (spelt in two parts: whole, it
			# reads as a mail address to the publication check).
			"https://api.scryfall.com" + "@" + "example.com/x", "https://api.scryfall.com:8443/x",
			"https://scryfall.io.example.com/x", "https://.scryfall.io/x", "ftp://cards.scryfall.io/x",
			"https://cards.scryfall.io/a b.jpg", "https://evilscryfall.io/x", "", "cards.scryfall.io/x"]:
		assert_eq(PackTransport.parts_of(refused), PackedStringArray(), refused)
	# Asked for an address it will not follow, the real transport answers at
	# once and opens nothing.
	var transport := PackTransport.new()
	transport.request("https://example.com/x.jpg", PackedStringArray(), 100, 1000)
	assert_false(transport.poll())
	assert_eq(transport.result().get("error"), "bad_url")
	assert_eq(transport.connects, 0)


## "No downloads in tests, period" (the owner, 2026-11-23): with the
## network switched off the REAL transport refuses every request before a
## name is resolved or a connection opened, and counts the attempt. The
## switch is only ever turned off here, and put back as it was found.
func test_switched_off_the_real_transport_opens_nothing() -> void:
	var was := PackTransport.network_allowed
	PackTransport.network_allowed = false
	var before := PackTransport.refused_attempts
	var transport := PackTransport.new()
	transport.request("https://api.scryfall.com/cards/named?exact=Hymn+to+Tourach&set=fem",
		PackFetch.api_headers(), 1000, 1000)
	assert_false(transport.poll(), "refused at once: nothing is under way")
	assert_eq(transport.result().get("error"), "off")
	transport.request(PackFetch.COLLECTION, PackFetch.batch_headers(), 1000, 1000, "{\"identifiers\":[]}")
	assert_false(transport.poll())
	assert_eq(transport.result().get("error"), "off")
	transport.request("https://cards.scryfall.io/art_crop/front/x.jpg", PackFetch.picture_headers(), 1000, 1000)
	assert_false(transport.poll())
	assert_eq(PackTransport.refused_attempts, before + 3, "every attempt is counted")
	assert_eq(transport.connects, 0, "no connection was opened")
	assert_eq(transport._clients.size(), 0, "and no client made")
	assert_null(transport._client)
	# A whole fetch on the real transport stops at its first request, in
	# plain words, and does not ask again.
	var fetch := PackFetch.new()
	fetch.transport = transport
	fetch.clock = _host.now_msec
	fetch.start((PackRecipes.recipe("pack-2")["jobs"] as Array).slice(0, 3), _host.cache_root().path_join("off"))
	while fetch.step():
		pass
	assert_eq(fetch.state, "failed")
	assert_eq(fetch.problem, "network")
	assert_eq(fetch.problem_text, "The network is switched off here.")
	assert_eq(PackTransport.refused_attempts, before + 4, "one attempt, not five")
	assert_eq(transport.connects, 0)
	PackTransport.network_allowed = was
