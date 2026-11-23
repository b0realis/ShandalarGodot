class_name PackFetch
extends RefCounted
## THE PICTURES OF ONE PACK, FETCHED POLITELY AND RESUMABLY — what
## `tools/fetch_card_art.py` (and the `fetch-art` of Packs 6–10) fetch, by
## the game itself, on the engine alone.
##
## It is given a recipe's `jobs` ([PackRecipes]) and a cache folder, and is
## stepped once a frame ([method step]) until [member state] leaves
## "working". A job is one card; Scryfall is asked where its pictures are,
## and each picture the cache lacks is downloaded.
##
## THE QUESTIONS GO IN BATCHES. Asked a card at a time — `/cards/named`,
## as the Python tools ask — a pack is hundreds of questions, and the real
## runs of 2026-11-23 were told to wait (HTTP 429) five times a pack,
## three quarters of a minute each. So up to [constant BATCH] cards are
## asked in one `POST /cards/collection`, by Scryfall id (Packs 6–10) or by
## name and set (the rest), and the answers are matched back to their jobs
## by that id or by name and set — never by their order. A pack is then a
## dozen questions instead of several hundred. A card the batch does not
## find — or answers wrongly, or without artwork — is asked for alone, the
## old way and slowly: its `lookups` in order, the next only on a 404 (its
## own set's printing, then any printing), exactly as the Python tools do.
##
## RESUMABLE. A picture reaches the cache only whole and checked — written
## beside its name and renamed onto it — so a file that is there is good.
## Where a card's pictures are is kept too ([constant LOOKUPS_FILE] in the
## cache), so a fetch stopped, failed or cut off by a closed game goes on
## from where it was and asks nothing twice.
##
## POLITE. One request at a time. At least [constant BATCH_GAP_MSEC]
## between two batches, [constant LOOKUP_GAP_MSEC] before a single
## question, [constant PICTURE_GAP_MSEC] between two pictures (the player
## may drop this last one, [member gentle]; nothing else). A 429 or a
## 5xx waits — as long as `Retry-After` says when it says — and is asked
## again a few times before the pack gives up; and after a 429 the gaps to
## that host are doubled for the rest of the run. The requests say what is
## asking ([method user_agent]) and nothing about who: no name, no machine.
##
## UNTRUSTED. Everything that comes back is data: an answer is bounded,
## must parse, each card in it must be the card asked for — the right set
## and collector number where the job pins them, the right name and set
## otherwise — with https addresses on Scryfall's own hosts; a picture is
## at most [constant MAX_PICTURE] and must begin and end as a JPEG does.
## Cache names come from the recipe, never from an answer; the kept
## answers are read back under the same checks.
##
## WHAT STOPS A PACK. A card Scryfall does not have, or an answer that is
## not right, fails that card and the fetch goes on — the summary counts
## them. The network itself failing (no connection, a refused certificate,
## a full disk, a server that stays busy) stops the pack at once with
## [member problem] set: "network", "tls", "disk" or "busy".

const COLLECTION := "https://api.scryfall.com/cards/collection"
## Cards in one batched question: the endpoint's own limit.
const BATCH := 75
const BATCH_GAP_MSEC := 1000
const LOOKUP_GAP_MSEC := 600
const PICTURE_GAP_MSEC := 100
## After a 429 the gaps to that host are multiplied by two, up to this.
const SLOWEST := 16
const MAX_JSON := 1024 * 1024
const MAX_BATCH_JSON := 8 * 1024 * 1024
const MAX_PICTURE := 8 * 1024 * 1024
const API_TIMEOUT_MSEC := 30000
const BATCH_TIMEOUT_MSEC := 60000
const PICTURE_TIMEOUT_MSEC := 60000
## A request that failed for the moment (429, 5xx, a dropped connection)
## is asked this many more times, the wait doubling from two seconds.
const RETRIES := 4
const RETRY_MSEC := 2000
const RETRY_AFTER_MAX_MSEC := 300000
## This many cards in a row failing for the network's sake stop the pack.
const FAILURES_IN_A_ROW := 3
## Cache files looked at per step while reading what is already there.
const SKIM := 400
const TAIL := ".download"
const LOOKUPS_FILE := "lookups.json"

enum {PLAN, PICK, BATCHED, LOOKUP, PICTURE, WAIT}

var transport: PackTransport
## Go easy on the picture host: pause [constant PICTURE_GAP_MSEC] between
## two pictures. False drops that pause and nothing else — the questions
## to the API keep their gaps, a 429 is obeyed and slows what follows, and
## there is still one request at a time.
var gentle := true
## The clock, in milliseconds — the tests' own, so no test waits.
var clock := Callable(Time, "get_ticks_msec")
## "idle", "working", "done", "stopped" or "failed".
var state := "idle"
## Why it failed: "network", "tls", "disk", "busy" — and in words.
var problem := ""
var problem_text := ""
## Pictures the pack has, of how many; cards that could not be fetched.
var pictures_done := 0
var pictures_total := 0
var missed: Array[Dictionary] = []
## This run: pictures downloaded, their bytes, questions asked of the API.
var fetched := 0
var fetched_bytes := 0
var questions := 0
var started_msec := 0
## This run, for whoever measures one. [member asked]: requests by kind
## ("collection", "single", "picture"). [member retries], [member
## waited_msec]: requests asked again and the milliseconds spent waiting to.
## [member troubles]: how often each cause came ("429", "5xx", "connect",
## "timeout"). [member refused_by]: the 429s by host. [member last_429]:
## the last one's host, headers and the start of its body.
var asked := {}
var retries := 0
var waited_msec := 0
var troubles := {}
var refused_by := {}
var last_429 := {}
## While waiting to ask again: until when, and "" or why ("busy" — the
## server said to come back later — or "retry").
var pause_until := 0
var pause_why := ""
## Whether the last [method step] could only wait — on the network or on
## the clock — so a caller with time left in its frame need not ask again.
var waiting := false

var _jobs: Array = []
var _cache := ""
var _stage := PLAN
var _plan_at := 0
## Job numbers: still to be asked about in a batch; answered, pictures to
## come; to be asked about alone.
var _todo: Array[int] = []
var _ready: Array[int] = []
var _singles: Array[int] = []
## Job key -> {picture kind: address}: every answer so far, kept on disk.
var _known := {}
var _batch: Array[int] = []
var _job := {}
var _job_at := -1
var _from_batch := false
var _lookup := 0
var _wanted: Array = []
var _uris := {}
var _row := 0
var _tries := 0
var _garbled := 0
var _in_a_row := 0
var _refused := ""
var _url := ""
var _wait_until := 0
var _after_wait := PICK
var _last_api_at := -1000000
var _last_picture_at := -1000000
var _slow_api := 1
var _slow_pictures := 1
var _made := {}


## `ShandalarGodot/<version> (card pack builder)` — the project and what is
## asking, as Scryfall's API asks every client to say.
static func user_agent() -> String:
	return "ShandalarGodot/%s (card pack builder)" % String(
		ProjectSettings.get_setting("application/config/version", "0"))


static func api_headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + user_agent(), "Accept: application/json"])


static func batch_headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + user_agent(), "Accept: application/json",
		"Content-Type: application/json"])


static func picture_headers() -> PackedStringArray:
	return PackedStringArray(["User-Agent: " + user_agent(), "Accept: image/jpeg, */*"])


## How many of [param jobs]' pictures [param cache] already holds.
static func cached_count(jobs: Array, cache: String) -> int:
	var count := 0
	for job: Dictionary in jobs:
		for file: Array in job["files"]:
			if FileAccess.file_exists(cache.path_join(String(file[0]))):
				count += 1
	return count


## Whether [param payload] is a whole JPEG of a size a pack may hold.
static func whole_jpeg(payload: PackedByteArray) -> bool:
	var size := payload.size()
	return size >= 4 and size <= MAX_PICTURE and payload[0] == 0xFF and payload[1] == 0xD8 \
		and payload[size - 2] == 0xFF and payload[size - 1] == 0xD9


## Begin (or go on with) the fetch of [param jobs] into [param cache].
func start(jobs: Array, cache: String) -> void:
	_jobs = jobs
	_cache = cache
	_stage = PLAN
	_plan_at = 0
	_todo.clear()
	_ready.clear()
	_singles.clear()
	_batch.clear()
	_made.clear()
	missed.clear()
	problem = ""
	problem_text = ""
	fetched = 0
	fetched_bytes = 0
	questions = 0
	asked = {}
	retries = 0
	waited_msec = 0
	troubles = {}
	refused_by = {}
	last_429 = {}
	pause_why = ""
	pictures_done = 0
	pictures_total = 0
	_in_a_row = 0
	_tries = 0
	_garbled = 0
	_slow_api = 1
	_slow_pictures = 1
	for job: Dictionary in jobs:
		pictures_total += (job["files"] as Array).size()
	_known = _read_known()
	started_msec = int(clock.call())
	state = "working"


## One frame's worth. True while there is more to do.
func step() -> bool:
	if state != "working":
		return false
	waiting = false
	match _stage:
		PLAN:
			_plan()
		PICK:
			_pick()
		WAIT:
			if int(clock.call()) >= _wait_until:
				pause_why = ""
				_stage = _after_wait
				_ask()
			else:
				waiting = true
		BATCHED:
			if transport.poll():
				waiting = true
			else:
				_batch_answered(transport.result())
		LOOKUP:
			if transport.poll():
				waiting = true
			else:
				_looked_up(transport.result())
		PICTURE:
			if transport.poll():
				waiting = true
			else:
				_pictured(transport.result())
	return state == "working"


## Stop cleanly: the request in flight is dropped, what is cached stays.
func stop() -> void:
	if state != "working":
		return
	if transport != null:
		transport.cancel()
	state = "stopped"


## Whole seconds until a request that failed for the moment is asked
## again; 0 when the fetch is not waiting for that.
func pause_seconds() -> int:
	if state != "working" or pause_why == "":
		return 0
	return maxi(1, int(ceil(float(pause_until - int(clock.call())) / 1000.0)))


## Rough seconds left, from this run's pace; -1 before there is one.
func seconds_left() -> int:
	if fetched < 4:
		return -1
	var elapsed := float(int(clock.call()) - started_msec) / 1000.0
	return int(ceil(elapsed / float(fetched) * float(pictures_total - pictures_done)))


# ------------------------------------------------------------- the plan --

## Read what the cache holds: the cards whose pictures are all there are
## done; of the rest, the ones already answered go straight to their
## pictures and the others wait for a batch.
func _plan() -> void:
	var looked := 0
	while _plan_at < _jobs.size() and looked < SKIM:
		var job: Dictionary = _jobs[_plan_at]
		var lacking := 0
		for file: Array in job["files"]:
			looked += 1
			if FileAccess.file_exists(_cache.path_join(String(file[0]))):
				pictures_done += 1
			else:
				lacking += 1
		if lacking > 0:
			if _known.has(String(job["key"])):
				_ready.append(_plan_at)
			else:
				_todo.append(_plan_at)
		_plan_at += 1
	if _plan_at >= _jobs.size():
		_stage = PICK


## What next: the pictures of a card already answered; else the next
## batch of questions; else a card to be asked about alone; else done.
func _pick() -> void:
	_tries = 0
	_garbled = 0
	if not _ready.is_empty():
		_job_at = _ready.pop_front()
		_job = _jobs[_job_at]
		_from_batch = true
		_uris = _known.get(String(_job["key"]), {})
		_wanted = _lacking(_job)
		_row = 0
		if _wanted.is_empty():
			return
		_stage = PICTURE
		_ask()
	elif not _todo.is_empty():
		_batch = _todo.slice(0, BATCH)
		_todo = _todo.slice(BATCH)
		_stage = BATCHED
		_ask()
	elif not _singles.is_empty():
		_job_at = _singles.pop_front()
		_job = _jobs[_job_at]
		_from_batch = false
		_wanted = _lacking(_job)
		_lookup = 0
		_uris = {}
		if _wanted.is_empty():
			return
		_stage = LOOKUP
		_ask()
	else:
		state = "done"


func _lacking(job: Dictionary) -> Array:
	var out: Array = []
	for file: Array in job["files"]:
		if not FileAccess.file_exists(_cache.path_join(String(file[0]))):
			out.append(file)
	return out


## Send the request the stage is for, once its gap has passed.
func _ask() -> void:
	var now := int(clock.call())
	match _stage:
		BATCHED:
			var due := _last_api_at + BATCH_GAP_MSEC * _slow_api
			if now < due:
				_pause(due - now, BATCHED)
				return
			var identifiers: Array = []
			for at: int in _batch:
				identifiers.append((_jobs[at] as Dictionary)["ask"])
			_last_api_at = now
			_send("collection", COLLECTION, batch_headers(), MAX_BATCH_JSON, BATCH_TIMEOUT_MSEC,
				JSON.stringify({"identifiers": identifiers}))
		LOOKUP:
			var due := _last_api_at + LOOKUP_GAP_MSEC * _slow_api
			if now < due:
				_pause(due - now, LOOKUP)
				return
			_last_api_at = now
			_send("single", String((_job["lookups"] as Array)[_lookup]), api_headers(),
				MAX_JSON, API_TIMEOUT_MSEC)
		PICTURE:
			# The pause between pictures is the one thing [member gentle]
			# decides — and after a 429 from the picture host it is kept
			# (doubled) whichever way that stands.
			var gap := PICTURE_GAP_MSEC * _slow_pictures if gentle or _slow_pictures > 1 else 0
			var due := _last_picture_at + gap
			if now < due:
				_pause(due - now, PICTURE)
				return
			var file: Array = _wanted[_row]
			_send("picture", String(_uris.get(String(file[1]), "")), picture_headers(),
				MAX_PICTURE, PICTURE_TIMEOUT_MSEC)


func _send(kind: String, url: String, headers: PackedStringArray, most: int, timeout: int,
		body := "") -> void:
	asked[kind] = int(asked.get(kind, 0)) + 1
	if kind != "picture":
		questions += 1
	_url = url
	transport.request(url, headers, most, timeout, body)


func _pause(msec: int, then: int) -> void:
	_wait_until = int(clock.call()) + msec
	_after_wait = then
	_stage = WAIT


# ------------------------------------------------------------ a batch --

func _batch_answered(answer: Dictionary) -> void:
	var error := String(answer.get("error", "connect"))
	var status := int(answer.get("status", 0))
	if error != "" or status == 429 or status >= 500:
		_again(answer, BATCHED)
		return
	_tries = 0
	var cards: Variant = _list_in(answer.get("body", PackedByteArray())) if status == 200 else null
	if not (cards is Array):
		# Not a list of cards at all (a page of HTML, half an answer, a
		# status that is no answer): asked once more, and then each of its
		# cards is asked about alone — where three failures in a row stop
		# the pack.
		if _garbled < 1:
			_garbled += 1
			_ask()
			return
		_singles.append_array(_batch)
		_batch.clear()
		_stage = PICK
		return
	# The answers back to their jobs: by id, or by name and set. Never by
	# their order, and a card nobody asked for is passed over.
	var by_key := {}
	for at: int in _batch:
		by_key[String((_jobs[at] as Dictionary)["key"])] = at
	var answered := {}
	for card: Variant in cards:
		if not (card is Dictionary):
			continue
		for key: String in _keys_of(card):
			if not by_key.has(key) or answered.has(key):
				continue
			var at: int = by_key[key]
			var uris := _uris_of(card, _jobs[at])
			if not uris.is_empty():
				answered[key] = true
				_known[key] = uris
				_ready.append(at)
	# Not found, answered wrongly or without artwork: alone, the old way.
	for at: int in _batch:
		if not answered.has(String((_jobs[at] as Dictionary)["key"])):
			_singles.append(at)
	_ready.sort()
	_batch.clear()
	if not answered.is_empty() and not _write_known():
		_fail("disk", "The download's notes could not be written (%s). Is the disk full?" % GamePaths.shown(_cache))
		return
	_stage = PICK


## The cards of a batched answer — its `data` — or null when the answer is
## not the list it should be.
static func _list_in(body: Variant) -> Variant:
	if not (body is PackedByteArray):
		return null
	var bytes: PackedByteArray = body
	var json := JSON.new()
	if bytes.is_empty() or bytes.size() > MAX_BATCH_JSON or bytes[0] != 0x7B \
			or json.parse(bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return null
	var list: Dictionary = json.data
	if String(list.get("object", "")) != "list" or not (list.get("data") is Array):
		return null
	return list["data"]


## What a card in an answer may be known by: its id, and its name and set.
static func _keys_of(card: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if card.get("id") is String:
		out.append(PackRecipes.id_key(String(card["id"])))
	if card.get("name") is String and card.get("set") is String:
		out.append(PackRecipes.named_key(String(card["name"]), String(card["set"])))
	return out


# ------------------------------------------------------ a single card --

func _looked_up(answer: Dictionary) -> void:
	var error := String(answer.get("error", "connect"))
	var status := int(answer.get("status", 0))
	if error != "" or status == 429 or status >= 500:
		_again(answer, LOOKUP)
		return
	_tries = 0
	var lookups: Array = _job["lookups"]
	if status == 404:
		# No printing in that set: ask for any printing, if the job allows.
		if _lookup + 1 < lookups.size():
			_lookup += 1
			_ask()
		else:
			_miss("Scryfall has no such card", false)
		return
	if status != 200:
		_miss("Scryfall answered %d" % status, true)
		return
	var uris := {}
	_refused = "an answer that is not a card"
	var body: Variant = answer.get("body", PackedByteArray())
	var json := JSON.new()
	# A card is a JSON object: anything that does not open as one (a
	# picture, a page of HTML) is not even read as text.
	if body is PackedByteArray and not (body as PackedByteArray).is_empty() \
			and (body as PackedByteArray).size() <= MAX_JSON and (body as PackedByteArray)[0] == 0x7B \
			and json.parse((body as PackedByteArray).get_string_from_utf8()) == OK \
			and json.data is Dictionary and String(json.data.get("object", "")) == "card":
		uris = _uris_of(json.data, _job)
	if uris.is_empty():
		# The Python tool falls through to the next question when an
		# answer has no artwork; a wrong card is simply a failure.
		if _refused == "" and _lookup + 1 < lookups.size():
			_lookup += 1
			_ask()
		else:
			_miss(_refused if _refused != "" else "Scryfall has no picture of it", true)
		return
	_uris = uris
	_known[String(_job["key"])] = uris
	if not _write_known():
		_fail("disk", "The download's notes could not be written (%s). Is the disk full?" % GamePaths.shown(_cache))
		return
	_row = 0
	_stage = PICTURE
	_ask()


## The addresses of [param job]'s pictures as a card gives them, {picture
## kind: https address} — empty when it is not the card the job asks for
## ([member _refused] says why) or names no artwork ([member _refused] is
## then ""). A printing asked by its id must be of the job's set and
## collector number, as the Python tools check; a card asked by name must
## bear that name — its set is the batch's to match (the key holds it),
## and a single question's second try is for any printing.
func _uris_of(card: Dictionary, job: Dictionary) -> Dictionary:
	_refused = ""
	var number := String(job.get("number", ""))
	if number != "":
		if str(card.get("set", "")) != String(job["set"]) \
				or str(card.get("collector_number", "")) != number:
			_refused = "another printing than the one asked for"
			return {}
	elif not (card.get("name") is String) \
			or PackRecipes.snake(String(card["name"])) != PackRecipes.snake(String(job["name"])):
		_refused = "another card than the one asked for"
		return {}
	var uris: Variant = card.get("image_uris", null)
	if not (uris is Dictionary) or not (uris.get("art_crop") is String) \
			or String(uris["art_crop"]) == "":
		return {}
	var out := {}
	for file: Array in job["files"]:
		var kind := String(file[1])
		var address: Variant = uris.get(kind, null)
		if not (address is String) or PackTransport.parts_of(String(address)).is_empty():
			_refused = "a picture address the game will not follow"
			return {}
		out[kind] = String(address)
	return out


# ------------------------------------------------------------ pictures --

func _pictured(answer: Dictionary) -> void:
	_last_picture_at = int(clock.call())
	var error := String(answer.get("error", "connect"))
	var status := int(answer.get("status", 0))
	if (error != "" and error != "too_big") or status == 429 or status >= 500:
		_again(answer, PICTURE)
		return
	var payload: PackedByteArray = answer.get("body", PackedByteArray())
	if error == "too_big" or status != 200 or not whole_jpeg(payload):
		# Cut short in a way the transport could not see, or not a picture
		# at all: once more, then the card is a miss.
		if status == 200 and error == "" and _tries < 1:
			_tries += 1
			_ask()
			return
		# The address came from an earlier answer and is no more: the card
		# is asked about again, alone.
		if _from_batch and (status == 404 or status == 410):
			_known.erase(String(_job["key"]))
			_singles.append(_job_at)
			_stage = PICK
			return
		_miss("a picture that is not a whole JPEG" if status == 200 or error == "too_big" \
			else "Scryfall answered %d for a picture" % status, status != 404)
		return
	_tries = 0
	var file: Array = _wanted[_row]
	if not _keep(String(file[0]), payload):
		_fail("disk", "A picture could not be written (%s). Is the disk full?" % GamePaths.shown(_cache))
		return
	fetched += 1
	fetched_bytes += payload.size()
	pictures_done += 1
	_in_a_row = 0
	_row += 1
	if _row < _wanted.size():
		_ask()
	else:
		_stage = PICK


## [param payload] into the cache as [param name]: beside it, then onto it.
func _keep(name: String, payload: PackedByteArray) -> bool:
	var path := _cache.path_join(name)
	var folder := path.get_base_dir()
	if not _made.has(folder):
		DirAccess.make_dir_recursive_absolute(folder)
		_made[folder] = true
	var pending := path + TAIL
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_buffer(payload)
	file.flush()
	var err := file.get_error()
	file.close()
	if not stored or err != OK or DirAccess.rename_absolute(pending, path) != OK:
		DirAccess.remove_absolute(pending)
		return false
	return true


# ------------------------------------------------- the answers, kept --

## The answers an earlier run kept, each read under the same rule a fresh
## one is: picture kinds this build knows, https addresses on Scryfall's
## own hosts. Anything else in the file is passed over.
func _read_known() -> Dictionary:
	var out := {}
	var path := _cache.path_join(LOOKUPS_FILE)
	if not FileAccess.file_exists(path):
		return out
	var bytes := FileAccess.get_file_as_bytes(path)
	var json := JSON.new()
	if bytes.is_empty() or bytes.size() > MAX_BATCH_JSON or bytes[0] != 0x7B \
			or json.parse(bytes.get_string_from_utf8()) != OK or not (json.data is Dictionary):
		return out
	for key: Variant in json.data:
		var uris: Variant = json.data[key]
		if not (key is String) or not (uris is Dictionary):
			continue
		var good := {}
		for variant: Array in PackRecipes.VARIANTS:
			var address: Variant = uris.get(String(variant[1]), null)
			if address is String and not PackTransport.parts_of(String(address)).is_empty():
				good[String(variant[1])] = String(address)
		if good.size() == PackRecipes.VARIANTS.size():
			out[key] = good
	return out


func _write_known() -> bool:
	DirAccess.make_dir_recursive_absolute(_cache)
	var path := _cache.path_join(LOOKUPS_FILE)
	var pending := path + TAIL
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		return false
	var stored := file.store_string(JSON.stringify(_known))
	file.flush()
	var err := file.get_error()
	file.close()
	if not stored or err != OK or DirAccess.rename_absolute(pending, path) != OK:
		DirAccess.remove_absolute(pending)
		return false
	return true


# ------------------------------------------------------------ troubles --

## The request failed for the moment: wait and ask it again, or — after
## [constant RETRIES] — give up on the pack (the server stayed busy, or a
## batch could not be asked at all) or on the card (the connection kept
## failing; three cards so stop the pack). A 429 is counted by its host
## and slows every later request to that host.
func _again(answer: Dictionary, stage: int) -> void:
	var error := String(answer.get("error", ""))
	var status := int(answer.get("status", 0))
	if error == "off":
		_fail("network", PackTransport.OFF_TEXT)
		return
	if error == "tls":
		_fail("tls", "The secure connection to Scryfall was refused: its certificate could not be checked. Check this device's date and time, and its system certificates.")
		return
	if error == "bad_url" or error == "redirect" or error == "too_big":
		if stage == BATCHED:
			# The whole batch could not be asked: each card alone.
			_singles.append_array(_batch)
			_batch.clear()
			_stage = PICK
		else:
			_miss("an address the game will not follow" if error != "too_big" \
				else "an answer that is too big", true)
		return
	if status == 429:
		var parts := PackTransport.parts_of(_url)
		var host := String(parts[0]) if not parts.is_empty() else "?"
		refused_by[host] = int(refused_by.get(host, 0)) + 1
		var body: Variant = answer.get("body", PackedByteArray())
		last_429 = {"host": host, "headers": answer.get("headers", {}),
			"body": (body as PackedByteArray).slice(0, 600).get_string_from_ascii() \
				if body is PackedByteArray else ""}
		if stage == PICTURE:
			_slow_pictures = mini(_slow_pictures * 2, SLOWEST)
		else:
			_slow_api = mini(_slow_api * 2, SLOWEST)
	if _tries >= RETRIES:
		if error == "":
			_fail("busy", "Scryfall is busy (it answered %d several times). Try again later." % status)
		elif stage == BATCHED:
			_fail("network", "The pictures could not be fetched (%s). Check the internet connection and try again." % (
				"the connection failed" if error == "connect" else "no answer in time"))
		else:
			_miss("the connection failed" if error == "connect" else "no answer in time", true)
		return
	var wait := RETRY_MSEC << _tries
	var headers: Variant = answer.get("headers", {})
	if headers is Dictionary and String(headers.get("retry-after", "")).is_valid_int():
		wait = clampi(int(String(headers["retry-after"])) * 1000, RETRY_MSEC, RETRY_AFTER_MAX_MSEC)
	_tries += 1
	retries += 1
	waited_msec += wait
	var cause := error if error != "" else ("429" if status == 429 else "5xx")
	troubles[cause] = int(troubles.get(cause, 0)) + 1
	_pause(wait, stage)
	pause_until = _wait_until
	pause_why = "busy" if status == 429 else "retry"


## This card could not be fetched; on to the next. [param counts] when it
## may be the network's fault: enough of those in a row stop the pack.
func _miss(why: String, counts: bool) -> void:
	missed.append({"name": String(_job.get("name", "")), "why": why})
	_tries = 0
	if counts:
		_in_a_row += 1
		if _in_a_row >= FAILURES_IN_A_ROW:
			_fail("network", "The pictures could not be fetched (%s). Check the internet connection and try again." % why)
			return
	_stage = PICK


func _fail(kind: String, text: String) -> void:
	if transport != null:
		transport.cancel()
	problem = kind
	problem_text = text
	state = "failed"
