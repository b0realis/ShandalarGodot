extends RefCounted
## Stand-ins for the card pack builder's tests (campaign 2026-11-23): a
## transport that answers from a table instead of a socket, and a host
## whose card folder, cache and clock are the test's own. Nothing here
## touches the network, the real catalogue or a mounted zip.


## A whole JPEG as far as the builder looks: the two marks and, between
## them, [param text] — so every address gives its own bytes.
static func jpeg(text: String) -> PackedByteArray:
	return Transport.jpeg(text)


static func answer(status: int, body: PackedByteArray = PackedByteArray(),
		headers: Dictionary = {}, error := "") -> Dictionary:
	return Transport.answer(status, body, headers, error)


## The card Scryfall would answer [param job]'s question [param url] with.
static func card(job: Dictionary, url: String) -> PackedByteArray:
	return Transport.card(job, url)


## SCRYFALL, AS FAR AS THE BUILDER ASKS. Taught a recipe's jobs ([method
## teach]), it answers each job's questions with that card and each
## picture address with a small JPEG; a batched question is answered from
## the same jobs, found ones in another order than asked. [member
## scripted] overrides: the first key an address (or a batch's body)
## contains gives the next answer of its queue (the last one stays).
class Transport extends PackTransport:
	var log: Array[String] = []
	var asked_at: Array[int] = []
	var scripted := {}
	## The body each request carried ("" for a GET), beside [member log].
	var bodies: Array[String] = []
	## Job keys a batched question does not find (they come back in
	## `not_found`); a single question still finds them.
	var absent := {}
	## Job key -> the card a batched question answers with instead.
	var instead := {}
	var _fake_body := ""
	var _fake_keys := {}
	## Every header line any request carried.
	var sent := {}
	var cancelled := 0
	var closed := 0
	## Polls a request stays busy before its answer is there.
	var busy_polls := 0
	var clock := Callable()
	var _fake_cards := {}
	var _fake_pending := {}
	var _fake_result := {}
	var _fake_left := 0
	var _fake_busy := false

	static func jpeg(text: String) -> PackedByteArray:
		var out := PackedByteArray([0xFF, 0xD8])
		out.append_array(text.to_utf8_buffer())
		out.append_array(PackedByteArray([0xFF, 0xD9]))
		return out

	static func answer(status: int, body: PackedByteArray = PackedByteArray(),
			headers: Dictionary = {}, error := "") -> Dictionary:
		return {"error": error, "status": status, "headers": headers, "body": body}

	static func card(job: Dictionary, url: String) -> PackedByteArray:
		return JSON.stringify(card_of(job, url)).to_utf8_buffer()

	## The card as Scryfall's JSON has it; [param salt] makes its pictures'
	## addresses (a single question's is its own address, a batch's the
	## job's key).
	static func card_of(job: Dictionary, salt: String) -> Dictionary:
		var key := str(salt.hash())
		var out := {"object": "card", "name": job["name"], "set": job["set"],
			"collector_number": job["number"] if String(job["number"]) != "" else "7",
			"image_uris": {
				"art_crop": "https://cards.scryfall.io/art_crop/%s.jpg?1" % key,
				"border_crop": "https://cards.scryfall.io/border_crop/%s.jpg?1" % key}}
		if (job["ask"] as Dictionary).has("id"):
			out["id"] = job["ask"]["id"]
		return out

	## The answer to a batched question: the cards found — in another order
	## than they were asked in — and the identifiers not found.
	func _collection(body: String) -> PackedByteArray:
		var asked: Variant = JSON.parse_string(body)
		var data: Array = []
		var not_found: Array = []
		if asked is Dictionary and asked.get("identifiers") is Array:
			for identifier: Variant in asked["identifiers"]:
				var key := ""
				if identifier is Dictionary and identifier.has("id"):
					key = PackRecipes.id_key(String(identifier["id"]))
				elif identifier is Dictionary and identifier.has("name") and identifier.has("set"):
					key = PackRecipes.named_key(String(identifier["name"]), String(identifier["set"]))
				if instead.has(key):
					data.push_front(instead[key])
				elif key == "" or absent.has(key) or not _fake_keys.has(key):
					not_found.append(identifier)
				else:
					data.push_front(card_of(_fake_keys[key], key))
		return JSON.stringify({"object": "list", "not_found": not_found, "data": data}).to_utf8_buffer()

	func teach(jobs: Array) -> void:
		for job: Dictionary in jobs:
			var lookups: Array = job["lookups"]
			for i in lookups.size():
				_fake_cards[String(lookups[i])] = job
			_fake_keys[String(job["key"])] = job

	func request(url: String, headers: PackedStringArray, max_bytes: int, _timeout: int,
			body := "") -> void:
		log.append(url)
		bodies.append(body)
		for header: String in headers:
			sent[header] = true
		_fake_body = body
		asked_at.append(int(clock.call()) if clock.is_valid() else 0)
		_fake_pending = _answer_for(url)
		if (_fake_pending["body"] as PackedByteArray).size() > max_bytes:
			_fake_pending = answer(0, PackedByteArray(), {}, "too_big")
		_fake_left = busy_polls
		_fake_busy = true

	func poll() -> bool:
		if not _fake_busy:
			return false
		if _fake_left > 0:
			_fake_left -= 1
			return true
		_fake_result = _fake_pending
		_fake_busy = false
		return false

	func result() -> Dictionary:
		return _fake_result

	func cancel() -> void:
		cancelled += 1
		_fake_busy = false

	func close() -> void:
		closed += 1
		_fake_busy = false

	func api_calls() -> Array[int]:
		var out: Array[int] = []
		for i in log.size():
			if log[i].begins_with("https://api.scryfall.com/"):
				out.append(asked_at[i])
		return out

	## When the requests to addresses beginning [param prefix] were sent.
	func times(prefix: String) -> Array[int]:
		var out: Array[int] = []
		for i in log.size():
			if log[i].begins_with(prefix):
				out.append(asked_at[i])
		return out

	## The identifiers of every batched question, in the order asked.
	func batches() -> Array:
		var out: Array = []
		for i in log.size():
			if log[i] == PackFetch.COLLECTION:
				out.append(JSON.parse_string(bodies[i])["identifiers"])
		return out

	## How many requests went to addresses containing [param part].
	func count(part: String) -> int:
		var n := 0
		for url: String in log:
			if url.contains(part):
				n += 1
		return n

	## The address of the artwork a batch gives [param job].
	static func art_of(job: Dictionary) -> String:
		return String(card_of(job, String(job["key"]))["image_uris"]["art_crop"])

	func _answer_for(url: String) -> Dictionary:
		for key: String in scripted:
			if url.contains(key) or _fake_body.contains(key):
				var queue: Array = scripted[key]
				return queue[0] if queue.size() == 1 else queue.pop_front()
		if url == PackFetch.COLLECTION:
			return answer(200, _collection(_fake_body))
		if _fake_cards.has(url):
			return answer(200, card(_fake_cards[url], url))
		if url.begins_with("https://cards.scryfall.io/"):
			return answer(200, jpeg(url))
		return answer(404)


## THE GAME, AS FAR AS THE BUILDER ASKS, in a scratch folder: its card
## folder and cache under [member root], a clock that moves on by itself,
## the pack contracts' real checks, and no rescan, seal or mount.
class Host extends PackBuildHost:
	var root := ""
	var net: Transport = null
	var locked := ""
	var free := -1
	var now := 1000
	## How far the clock moves each time it is read.
	var tick := 40
	var states := {}
	var settled: Array = []
	var worn := 0
	var restart := true
	var judged: Array[String] = []
	## The "go easy" tick as the settings would keep it.
	var gentle_kept := true

	func refusal() -> String:
		return locked

	func gentle() -> bool:
		return gentle_kept

	func set_gentle(on: bool) -> void:
		gentle_kept = on

	func folder() -> String:
		return root.path_join("cardpacks")

	func cache_root() -> String:
		return root.path_join("cache")

	func transport() -> PackTransport:
		return net

	func now_msec() -> int:
		now += tick
		return now

	## The clock read without moving it.
	func peek() -> int:
		return now

	func free_bytes() -> int:
		return free

	func status(id: String) -> Dictionary:
		if states.has(id):
			return states[id]
		var file := folder().path_join(String(PackRecipes.about(id)["file_name"]))
		return {"state": "installed" if FileAccess.file_exists(file) else "absent", "note": ""}

	func judge(id: String, path: String) -> Dictionary:
		judged.append(id)
		return super.judge(id, path)

	func place(_id: String, staged: String) -> String:
		var final := folder().path_join(staged.get_file())
		return "" if DirAccess.rename_absolute(staged, final) == OK else "could not be put in place"

	func settle(ids: Array) -> void:
		settled.append(ids.duplicate())

	func art_needs_restart() -> bool:
		return restart

	func wear_art() -> void:
		worn += 1


static func host(root: String) -> Host:
	var out := Host.new()
	out.root = root
	out.net = Transport.new()
	out.net.clock = out.peek
	DirAccess.make_dir_recursive_absolute(out.folder())
	return out


## [param payload] written to [param path] and the file closed — a file
## opened in passing can stay open, and empty, to the end of the test.
static func write(path: String, payload: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(payload)
	file.close()


## Everything under [param folder], gone.
static func wipe(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir():
			if entry != "." and entry != "..":
				wipe(folder.path_join(entry))
		else:
			DirAccess.remove_absolute(folder.path_join(entry))
		entry = dir.get_next()
	dir.list_dir_end()
	DirAccess.remove_absolute(folder)


## Step [param build] to its end (a bound on the steps, never on time).
static func run(build: PackBuild, most := 400000) -> int:
	var steps := 0
	while build.step() and steps < most:
		steps += 1
	return steps
