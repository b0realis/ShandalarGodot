extends GutTest
## THE HOST'S COMMUNITY CARDS AT A LAN TABLE (2026-11-17, [SgCardTransfer]).
## Both players need the same community cards. A guest whose cards differ
## asks the host for its list — each card's name, playing digest and zip
## size — and works out what to add, replace and set aside; the zips come
## in chunks, only the host's own cards and only by name; the guest's own
## cards are set aside, never deleted, and put back when an install fails;
## and afterwards the two community marks agree. Real loopback sockets, in
## one process: the host's cards are its `community_rows`, the guest's the
## scan of a scratch own folder and a scratch "beside the game" folder.

const ROOT := "user://community_transfer_test"

var server: CountingServer
var transfer: SgCardTransfer
var _root := ""
var _own := ""
var _stash := ""
## Whether the own folder holds only what this test made.
var _own_free := false
var _got: Dictionary = {}


## Counts the chunks the host sends and the zips it packs (reads) to send
## them; with [member hold_lists] it never answers a list.
class CountingServer extends SgLocalServer:
	var chunks := 0
	var packs := 0
	var hold_lists := false
	func _send(id: int, message: Dictionary) -> void:
		if SgProtocol.literal(message.get("type"), "card") and String(message.get("data", "")) != "":
			chunks += 1
		super._send(id, message)
	func _transfer(id: int, message: Dictionary) -> void:
		if hold_lists and SgProtocol.literal(message.get("type"), "cards"):
			return
		super._transfer(id, message)
	func _sending_bytes(row: Dictionary) -> PackedByteArray:
		var kept := _sending.any(func(k: Dictionary) -> bool: return String(k["name"]) == String(row.get("name", "")))
		if not kept and SgCardTransfer.sendable(row):
			packs += 1
		return super._sending_bytes(row)


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root.path_join("host"))
	DirAccess.make_dir_recursive_absolute(_root.path_join("beside"))
	# The profile's own folder waits aside, untouched, while the test runs.
	_own = ProjectSettings.globalize_path(CommunityCards.own_folder())
	_stash = _root + "_stash"
	_own_free = not DirAccess.dir_exists_absolute(_own)
	if not _own_free and not DirAccess.dir_exists_absolute(_stash):
		_own_free = DirAccess.rename_absolute(_own, _stash) == OK
	assert_true(_own_free, "the own folder waits aside")
	CommunityCards.ensure_own_folder()
	CommunityCards.folders_override = [_own, _root.path_join("beside")]
	SgCardTransfer.chunk_bytes = SgCardTransfer.CHUNK
	server = CountingServer.new()
	add_child_autofree(server)
	assert_eq(server.start_local(0), OK)
	transfer = SgCardTransfer.new()
	add_child_autofree(transfer)
	_got = {}
	transfer.listed.connect(func(p: Dictionary) -> void: _got["plan"] = p)
	transfer.downloaded.connect(func(zips: Dictionary) -> void: _got["zips"] = zips)
	transfer.failed.connect(func(reason: String) -> void: _got["failed"] = reason)


func after_each() -> void:
	transfer.cancel()
	server.stop()
	SgCardTransfer.chunk_bytes = SgCardTransfer.CHUNK
	CommunityCards.folders_override = []
	# What the test made in the own folder goes; the profile's comes back.
	if _own_free:
		_wipe(_own, true)
	if DirAccess.dir_exists_absolute(_stash) and not DirAccess.dir_exists_absolute(_own):
		DirAccess.rename_absolute(_stash, _own)
	_wipe(_root)
	CommunityCards.refresh()


func _wipe(dir: String, own := false) -> void:
	if not (own or dir.contains("community_transfer_test")) or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub), own)
	for file in here.get_files():
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _until(predicate: Callable, frames := 1200) -> bool:
	for i in frames:
		if predicate.call():
			return true
		await get_tree().process_frame
	assert_true(false, "the transfer did not finish within its frame budget")
	return false


func _spec(card: String, extra := {}) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": card, "cost": "{G}",
		"types": ["creature"], "power": 1, "toughness": 1, "rarity": "common",
		"artist": "A. Painter", "set_name": "Test set", "look": {"border": "black"}, "abilities": []}
	spec.merge(extra, true)
	return spec


func _picture(w: int, h: int) -> Dictionary:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.3, 0.5, 0.2))
	return {"bytes": image.save_png_to_buffer(), "kind": "png"}


## Art within the guidelines that no zip can shrink: noise, 765 x 594.
func _large_art() -> Dictionary:
	var noise := Crypto.new().generate_random_bytes(765 * 594 * 3)
	var image := Image.create_from_data(765, 594, false, Image.FORMAT_RGB8, noise)
	return {"bytes": image.save_png_to_buffer(), "kind": "png"}


func _zip(folder: String, file: String, spec: Dictionary, art := {}) -> String:
	var path := folder.path_join(file)
	assert_eq(CommunityCards.write_zip(path, spec, art if not art.is_empty() else _picture(510, 396),
		_picture(64, 64)), "", "wrote " + file)
	return path


func _host(file: String, spec: Dictionary, art := {}) -> String:
	return _zip(_root.path_join("host"), file, spec, art)


## The host's cards: every zip in its folder, as its own scan reads them.
func _host_rows() -> Array:
	var rows: Array = []
	var folder := _root.path_join("host")
	for file in DirAccess.get_files_at(folder):
		var row := CommunityCards.read(folder.path_join(file))
		if (row["problems"] as Array).is_empty():
			rows.append({"name": row["name"], "path": row["path"], "spec": row["spec"]})
	return rows


func _target(access := "") -> Dictionary:
	return {"address": "127.0.0.1", "port": server.port,
		"access": access if access != "" else server.access_code, "tls": null}


func _list() -> Dictionary:
	_got.erase("plan")
	_got.erase("failed")
	server.community_rows = _host_rows()
	assert_eq(transfer.ask_list(_target()), OK)
	await _until(func() -> bool: return _got.has("plan") or _got.has("failed"))
	assert_false(_got.has("failed"), String(_got.get("failed", "")))
	return _got.get("plan", {})


func _download(p: Dictionary) -> Dictionary:
	_got.erase("zips")
	_got.erase("failed")
	assert_eq(transfer.download(_target(), p), OK)
	await _until(func() -> bool: return _got.has("zips") or _got.has("failed"))
	assert_false(_got.has("failed"), String(_got.get("failed", "")))
	return _got.get("zips", {})


## A zip made by hand: [param entries] are `[path in the zip, bytes]`.
func _raw_zip(path: String, entries: Array) -> PackedByteArray:
	var zip := ZIPPacker.new()
	assert_eq(zip.open(path), OK)
	for entry in entries:
		zip.start_file(String(entry[0]))
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()
	return FileAccess.get_file_as_bytes(path)


func _json(value: Variant) -> PackedByteArray:
	return JSON.stringify(value, "\t").to_utf8_buffer()


## A card's digest as both computers read its spec from a zip.
func _digest(spec: Dictionary) -> String:
	return SgCompatibility.card_digest(JSON.parse_string(JSON.stringify(spec)))


## A raw connection to the host, as any LAN player holding the access code.
func _raw() -> WebSocketPeer:
	var ws := WebSocketPeer.new()
	ws.supported_protocols = SgProtocol.subprotocols()
	ws.inbound_buffer_size = SgProtocol.MAX_BYTES * 2
	assert_eq(ws.connect_to_url("ws://127.0.0.1:%d" % server.port), OK)
	await _until(func() -> bool:
		ws.poll()
		return ws.get_ready_state() == WebSocketPeer.STATE_OPEN)
	return ws


func _ask(ws: WebSocketPeer, message: Dictionary) -> void:
	var full := {"v": SgProtocol.VERSION, "access": server.access_code}
	full.merge(message)
	ws.send_text(SgProtocol.encode(full))


## The host's answers over [param ms] milliseconds.
func _answers(ws: WebSocketPeer, ms: int) -> Array:
	var got: Array = []
	var until := Time.get_ticks_msec() + ms
	while Time.get_ticks_msec() < until:
		ws.poll()
		while ws.get_available_packet_count() > 0:
			got.append(SgProtocol.decode_payload(ws.get_packet(), 4))
		await get_tree().process_frame
	return got


func _files(folder: String) -> Array:
	var names := Array(DirAccess.get_files_at(folder)) if DirAccess.dir_exists_absolute(folder) else []
	names.sort()
	return names


# ------------------------------------------------------ the list, the diff --

func test_the_guest_reads_the_host_s_list_and_works_out_the_difference() -> void:
	_host("same.zip", _spec("Same Moss"))
	_host("new.zip", _spec("New Moss"))
	_host("fire.zip", _spec("Fire Moss", {"power": 5}))
	_host("beside.zip", _spec("Beside Moss", {"power": 3}))
	_zip(_own, "same.zip", _spec("Same Moss", {"flavor": "Other words.", "artist": "Someone else"}))
	_zip(_own, "fire.zip", _spec("Fire Moss"))
	_zip(_own, "extra.zip", _spec("Own Extra"))
	_zip(_root.path_join("beside"), "beside.zip", _spec("Beside Moss"))
	_zip(_root.path_join("beside"), "beside_extra.zip", _spec("Beside Extra"))
	CommunityCards.refresh()
	var p: Dictionary = await _list()
	assert_false(transfer.busy(), "the list's connection is closed")
	assert_eq(p["add"], ["New Moss"])
	assert_eq(p["replace"], ["Fire Moss"])
	assert_eq(p["set_aside"], ["Own Extra"])
	assert_eq(p["stuck"], ["Beside Moss", "Beside Extra"], "beside the game: reported, never moved")
	assert_eq(int(p["same"]), 1, "flavor and artist do not play")
	var wanted := (p["want"] as Array).map(func(row: Array) -> String: return String(row[0]))
	assert_eq(wanted, ["Fire Moss", "New Moss"], "in the order of their names")
	var host := SgCardTransfer.shelf(_host_rows())
	var specs: Array = host.map(func(row: Dictionary) -> Dictionary: return row["spec"])
	assert_eq(String(p["mark"]), SgCompatibility.mark_of(specs), "the host's mark, made the way the stamp's is")
	# The digest of the spec as read from the zip, as both computers read it.
	var host_fire := CommunityCards.read(_root.path_join("host/fire.zip"))
	assert_eq(String((p["want"] as Array)[0][1]), SgCompatibility.card_digest(host_fire["spec"]))
	assert_eq(int((p["want"] as Array)[1][2]), FileAccess.get_file_as_bytes(_root.path_join("host/new.zip")).size())
	assert_ne(String(p["mark"]), SgCompatibility.community_mark())
	var text := SgCardTransfer.plan_text(p)
	assert_true(text.begins_with("Add 1 card, replace 1, set aside 1 of yours."), text)
	assert_string_contains(text, "set_aside")
	assert_string_contains(text, "never deleted")
	assert_string_contains(text, "can't be set aside: Beside Moss, Beside Extra")
	# The list on the wire, checked as untrusted data.
	var reply := SgCardTransfer.list_reply(host)
	assert_true(SgCardTransfer.valid_list(reply))
	var twins := reply.duplicate(true)
	(twins["cards"] as Array).append(["SAME MOSS", "0".repeat(64), 10])
	assert_false(SgCardTransfer.valid_list(twins), "one card a name, in any case")
	var odd := reply.duplicate(true)
	var first: Array = odd["cards"][0]
	first[1] = "not a digest"
	assert_false(SgCardTransfer.valid_list(odd))
	odd = reply.duplicate(true)
	odd["path"] = "/etc"
	assert_false(SgCardTransfer.valid_list(odd), "no field but its own")


# ------------------------------------------------- a zip of many chunks --

func test_a_large_zip_comes_in_chunks_whole() -> void:
	var big := _host("big.zip", _spec("Big Moss"), _large_art())
	_host("small.zip", _spec("Small Moss"))
	CommunityCards.refresh()
	var p: Dictionary = await _list()
	assert_eq(p["add"], ["Big Moss", "Small Moss"])
	var zips: Dictionary = await _download(p)
	var whole := FileAccess.get_file_as_bytes(big)
	assert_gt(whole.size(), 2 * SgCardTransfer.CHUNK, "the art makes the zip several chunks")
	assert_lt(whole.size(), CommunityCards.MAX_ZIP)
	assert_eq(zips["Big Moss"], whole, "every byte, in order")
	assert_eq(zips["Small Moss"], FileAccess.get_file_as_bytes(_root.path_join("host/small.zip")))
	assert_eq(server.chunks, ceili(whole.size() / float(SgCardTransfer.CHUNK)) + 1, "one request a chunk")
	assert_false(transfer.busy())
	# A forged chunk is refused before a byte of it is kept.
	var chunk := SgCardTransfer.chunk_reply(SgCardTransfer.shelf_row(SgCardTransfer.shelf(_host_rows()), "Big Moss"),
		"Big Moss", 0, whole)
	assert_true(SgCardTransfer.valid_chunk(chunk))
	assert_eq(String(chunk["data"]).length(), 4 * ceili(SgCardTransfer.CHUNK / 3.0))
	var forged := chunk.duplicate()
	forged["total"] = CommunityCards.MAX_ZIP + 1
	assert_false(SgCardTransfer.valid_chunk(forged), "past the largest card zip")
	forged = chunk.duplicate()
	forged["data"] = "x".repeat(4 * ((SgCardTransfer.MAX_CHUNK + 2) / 3) + 4)
	assert_false(SgCardTransfer.valid_chunk(forged), "past the largest chunk")


# --------------------------------------------- set aside, and put back --

func test_set_aside_cards_come_back_when_an_install_fails() -> void:
	_host("fire.zip", _spec("Fire Moss", {"power": 5}))
	_host("new.zip", _spec("New Moss"))
	_host("zed.zip", _spec("Zed Moss"))
	var fire := _zip(_own, "fire.zip", _spec("Fire Moss"))
	var extra := _zip(_own, "extra.zip", _spec("Own Extra"))
	var fire_bytes := FileAccess.get_file_as_bytes(fire)
	CommunityCards.refresh()
	var p: Dictionary = await _list()
	var zips: Dictionary = await _download(p)
	assert_eq(zips.keys().size(), 3)
	assert_string_contains(SgCardTransfer.apply(p, zips)["problem"], "SGManalink",
		"nothing is installed while a connection is open")
	# The host is another computer: its lock was never this game's.
	server.stop()
	# A zip that is not the card the list named changes nothing.
	var forged := p.duplicate(true)
	for row: Array in forged["want"]:
		if row[0] == "New Moss": row[2] = (zips["Zed Moss"] as PackedByteArray).size()
	var swapped := zips.duplicate()
	swapped["New Moss"] = zips["Zed Moss"]
	var refused := SgCardTransfer.apply(forged, swapped)
	assert_string_contains(String(refused["problem"]), "holds another card (Zed Moss)")
	assert_string_contains(String(refused["problem"]), "Nothing was changed")
	assert_eq(_files(_own), ["extra.zip", "fire.zip"])
	assert_eq(_files(SgCardTransfer.aside_folder()), [])
	# A Zed Moss turns up beside the game while the cards came: its install
	# fails after the others went in, and the batch is undone.
	_zip(_root.path_join("beside"), "zed.zip", _spec("Zed Moss", {"power": 2}))
	var pool := CardRegistry.revision
	var result := SgCardTransfer.apply(p, zips)
	assert_gt(CardRegistry.revision, pool, "an undo rebuilds the pool from the folders as they are")
	assert_false(SgCardTransfer.left_batch(), "an undone batch leaves no record")
	assert_string_contains(String(result["problem"]), "Zed Moss could not be installed")
	assert_string_contains(String(result["problem"]), "Your cards are as they were.")
	assert_eq(_files(_own), ["extra.zip", "fire.zip"], "this batch's installs are out again")
	assert_eq(FileAccess.get_file_as_bytes(fire), fire_bytes, "the own Fire Moss is back")
	assert_true(FileAccess.file_exists(extra))
	assert_eq(_files(SgCardTransfer.aside_folder()), [], "nothing left set aside")
	assert_eq(CommunityCards.own_path_of("Fire Moss"), fire)
	assert_eq(CardRegistry.get_card("Fire Moss").power, 1, "the pool is the one from before")
	assert_false(CardRegistry.has_card("New Moss"))


# ---------------------------------------------- what the host refuses --

func test_the_host_never_sends_an_over_size_zip() -> void:
	_host("moss.zip", _spec("Moss One"))
	var huge := _root.path_join("host/huge.zip")
	var file := FileAccess.open(huge, FileAccess.WRITE)
	file.store_buffer(Crypto.new().generate_random_bytes(CommunityCards.MAX_ZIP + 1))
	file.close()
	var p: Dictionary = await _list()
	# The host lists what its scan found: a row of its own stands in for a huge zip.
	server.community_rows.append({"name": "Huge Moss", "path": huge, "spec": _spec("Huge Moss")})
	_got.erase("plan")
	assert_eq(transfer.ask_list(_target()), OK)
	await _until(func() -> bool: return _got.has("plan"))
	p = _got["plan"]
	assert_eq(p["too_large"], ["Huge Moss"], "listed, never fetched")
	assert_eq((p["want"] as Array).map(func(row: Array) -> String: return String(row[0])), ["Moss One"])
	assert_string_contains(SgCardTransfer.plan_text(p), "a card zip is at most 6 MB): Huge Moss")
	# Asked anyway, the host says no and sends nothing.
	var forged := p.duplicate(true)
	forged["want"] = [["Huge Moss", SgCardTransfer.shelf_row(SgCardTransfer.shelf(server.community_rows), "Huge Moss")["digest"],
		CommunityCards.MAX_ZIP + 1]]
	assert_eq(transfer.download(_target(), forged), OK)
	await _until(func() -> bool: return _got.has("failed"))
	assert_string_contains(String(_got["failed"]), "too large to send")
	assert_eq(server.chunks, 0)
	server.stop()
	assert_string_contains(SgCardTransfer.apply(forged, {"Huge Moss": PackedByteArray([1, 2, 3])})["problem"],
		"not the size it listed", "nor does the guest install one")


func test_the_host_refuses_a_name_it_does_not_have() -> void:
	_host("moss.zip", _spec("Moss One"))
	var p: Dictionary = await _list()
	for ghost in ["Ghost Moss", "../../moss.zip", "host/moss.zip"]:
		_got.erase("failed")
		var forged := p.duplicate(true)
		forged["want"] = [[ghost, "0".repeat(64), 100]]
		assert_eq(transfer.download(_target(), forged), OK)
		await _until(func() -> bool: return _got.has("failed"))
		assert_eq(String(_got.get("failed", "")), "The host has no community card named %s." % ghost,
			"a name, never a path: " + ghost)
	assert_eq(server.chunks, 0)
	# Without the access code the host answers nothing about its cards.
	_got.erase("failed")
	assert_eq(transfer.ask_list(_target("0".repeat(64))), OK)
	await _until(func() -> bool: return _got.has("failed"))
	assert_eq(String(_got["failed"]), SgLocalServer.INVALID_INVITATION)
	# The requests themselves are checked as every message is.
	var ask := {"v": SgProtocol.VERSION, "type": "card", "access": "0".repeat(64), "name": "Moss One", "offset": 0}
	assert_true(SgProtocol.valid(ask))
	for bad: Dictionary in [{"offset": CommunityCards.MAX_ZIP + 1}, {"offset": -1}, {"name": ""},
			{"name": "Moss\u0001One"}, {"name": " Moss One"}, {"name": "x".repeat(65)}, {"access": "nope"}]:
		var wrong := ask.duplicate()
		wrong.merge(bad, true)
		assert_false(SgProtocol.valid(wrong), str(bad))
	var extra := ask.duplicate()
	extra["path"] = "/etc/passwd"
	assert_false(SgProtocol.valid(extra), "no path field")
	assert_true(SgProtocol.valid({"v": SgProtocol.VERSION, "type": "cards", "access": "0".repeat(64)}))


# ------------------------------------------------------ the marks agree --

func test_after_the_transfer_the_marks_agree() -> void:
	_host("same.zip", _spec("Same Moss"))
	_host("new.zip", _spec("New Moss"))
	_host("fire.zip", _spec("Fire Moss", {"power": 5}))
	_zip(_own, "same.zip", _spec("Same Moss", {"flavor": "Other words."}))
	var fire := _zip(_own, "fire.zip", _spec("Fire Moss"))
	var extra := _zip(_own, "extra.zip", _spec("Own Extra"))
	var fire_bytes := FileAccess.get_file_as_bytes(fire)
	var extra_bytes := FileAccess.get_file_as_bytes(extra)
	CommunityCards.refresh()
	var p: Dictionary = await _list()
	assert_ne(SgCompatibility.community_mark(), String(p["mark"]))
	var zips: Dictionary = await _download(p)
	server.stop()
	var result := SgCardTransfer.apply(p, zips)
	assert_eq(String(result["problem"]), "")
	assert_true(bool(result["matched"]), String(result["message"]))
	assert_eq(SgCompatibility.community_mark(), String(p["mark"]), "this game's mark is now the host's")
	assert_string_contains(String(result["message"]), "now match the host's")
	assert_eq(CardRegistry.get_card("Fire Moss").power, 5, "the host's Fire Moss plays")
	assert_true(CardRegistry.has_card("New Moss"))
	assert_false(CardRegistry.has_card("Own Extra"))
	var aside := SgCardTransfer.aside_folder()
	assert_eq(_files(aside), ["extra.zip", "fire.zip"], "set aside, not deleted")
	assert_eq(FileAccess.get_file_as_bytes(aside.path_join("fire.zip")), fire_bytes)
	assert_eq(FileAccess.get_file_as_bytes(aside.path_join("extra.zip")), extra_bytes)
	assert_false(_files(_own).has("extra.zip"))
	assert_false(SgCardTransfer.left_batch(), "a finished batch leaves no record")
	assert_eq(SgCardTransfer.plan(SgCardTransfer.list_reply(SgCardTransfer.shelf(_host_rows()))["cards"],
		String(p["mark"]), SgCardTransfer.mine())["same"], 3, "nothing is left to fetch")


# ------------------------------------------------------- from the lobby --

func test_the_lobby_offers_the_host_s_cards_and_joins_again() -> void:
	_host("new.zip", _spec("New Moss"))
	server.community_rows = _host_rows()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	await get_tree().process_frame
	assert_false(lobby._community_row.visible, "no community difference, no button")
	assert_eq(lobby.client.connect_local(server.port, server.access_code), OK)
	# This guest's game says it holds a community card the host lacks.
	lobby.client.build_fingerprint = "0".repeat(64)
	lobby.client.build_stamp["community"] = "1-000000000000"
	await _until(func() -> bool: return lobby.client.status.begins_with(SgCompatibility.COMMUNITY_WORDS))
	await _until(func() -> bool: return lobby._community_row.visible)
	assert_true(lobby._notice.text.begins_with(SgCompatibility.COMMUNITY_WORDS), lobby._notice.text)
	assert_false(lobby._community_button.disabled)
	lobby._community_button.pressed.emit()
	await _until(func() -> bool: return UiChrome.open_popup(lobby) != null)
	var popup := UiChrome.open_popup(lobby)
	var words := ""
	for label in popup.find_children("*", "Label", true, false):
		words += (label as Label).text + "\n"
	assert_string_contains(words, "Add 1 card, replace 0, set aside 0 of yours.")
	# The host is another computer: its lock was never this game's.
	CardPacks.unlock_catalogue(server)
	(popup.find_child("GetCards", true, false) as Button).pressed.emit()
	await _until(func() -> bool: return lobby.client.online, 3000)
	assert_true(CardRegistry.has_card("New Moss"), "installed from the host's zip")
	assert_true(_files(_own).has("new_moss.zip"))
	assert_eq(SgCompatibility.community_mark(), String(SgCardTransfer.list_reply(SgCardTransfer.shelf(server.community_rows))["mark"]))
	assert_false(lobby._community_row.visible)
	assert_string_contains(lobby._notice.text, "now match the host's")
	lobby.client.forget()


# ---------------------------------- the bug hunt's findings (2026-11-17) --

## 1 and 4: a host's "card zip" holds one card's own files and nothing else
## — no set.json and other cards' folders, no padding, nothing that unpacks
## past a card's size — refused before anything moves.
func test_a_card_zip_holds_one_card_s_own_files_only() -> void:
	# No host here: nothing holds the catalogue.
	server.stop()
	var own_fire := _zip(_own, "fire.zip", _spec("Fire Moss"))
	CommunityCards.refresh()
	var icon: PackedByteArray = _picture(64, 64)["bytes"]
	var evil := _raw_zip(_root.path_join("host/evil.zip"), [
		["foo_moss/card.json", _json(_spec("Foo Moss"))], ["foo_moss/icon.png", icon],
		["foo_moss/set.json", _json({"format": CommunityCards.SET_FORMAT, "version": 1, "name": "Evil",
			"cards": ["evil_a"]})],
		["foo_moss/evil_a/card.json", _json(_spec("Evil Alpha", {"power": 9}))], ["foo_moss/evil_a/icon.png", icon]])
	var zeros := PackedByteArray()
	zeros.resize(8 * 1024 * 1024)
	var notes := icon.slice(0, 33)
	notes.append_array(zeros)
	var padded := _raw_zip(_root.path_join("host/pad.zip"), [
		["pad_moss/card.json", _json(_spec("Pad Moss"))], ["pad_moss/icon.png", icon], ["pad_moss/notes.png", notes]])
	var spaces := " ".repeat(7 * 1024 * 1024).to_utf8_buffer()
	var wide := _json(_spec("Wide Moss"))
	wide.append_array(spaces)
	var bloated := _raw_zip(_root.path_join("host/wide.zip"), [
		["wide_moss/card.json", wide], ["wide_moss/icon.png", icon]])
	var two := _raw_zip(_root.path_join("host/two.zip"), [
		["a/card.json", _json(_spec("Two Moss"))], ["a/icon.png", icon], ["b/icon.png", icon]])
	assert_lt(padded.size(), 1024 * 1024, "small on the wire")
	for case: Array in [["Foo Moss", evil, "set.json"], ["Pad Moss", padded, "notes.png"],
			["Wide Moss", bloated, "unpacks to"], ["Two Moss", two, "top folder"]]:
		var card := String(case[0])
		var bytes: PackedByteArray = case[1]
		var why := SgCardTransfer._check(card, _digest(_spec(card)), bytes.size(), bytes)
		assert_string_contains(why, "not a plain card zip", card)
		assert_string_contains(why, String(case[2]), card)
		var p := SgCardTransfer.plan([[card, _digest(_spec(card)), bytes.size()]], "", SgCardTransfer.mine())
		var result := SgCardTransfer.apply(p, {card: bytes})
		assert_string_contains(String(result["problem"]), "Nothing was changed", card)
	assert_false(CardRegistry.has_card("Evil Alpha"), "no card the guest never asked for")
	assert_eq(_files(_own), ["fire.zip"])
	assert_true(FileAccess.file_exists(own_fire))
	# A plain card zip still passes, art and all.
	var plain := FileAccess.get_file_as_bytes(_host("plain.zip", _spec("Plain Moss")))
	assert_eq(SgCardTransfer._check("Plain Moss", _digest(_spec("Plain Moss")), plain.size(), plain), "")


## 2: tiny chunk requests, card after card: each card's zip is read (or a
## set's card packed) once, and each request costs a whole chunk of the
## connection's budget.
func test_tiny_requests_neither_repack_nor_outlast_their_budget() -> void:
	var names: Array[String] = ["Tiny A", "Tiny B", "Tiny C"]
	for card in names:
		_host(card.to_lower().replace(" ", "_") + ".zip", _spec(card))
	server.community_rows = _host_rows()
	var shelf := SgCardTransfer.shelf(server.community_rows)
	var ws: WebSocketPeer = await _raw()
	for i in 30:
		var row := SgCardTransfer.shelf_row(shelf, names[i % names.size()])
		_ask(ws, {"type": "card", "name": row["name"], "offset": int(row["size"]) - 1})
		await _answers(ws, 30)
	await _answers(ws, 200)
	assert_eq(server.packs, 3, "one read a card, whatever the requests")
	assert_eq(server._peers.size(), 1)
	assert_eq(int((server._peers.values()[0] as Dictionary).get("served", 0)), 30 * SgCardTransfer.CHUNK,
		"a one-byte request costs a whole chunk")
	ws.close()


## 3: a connection that has spent its lists is told so and let go; one
## whose requests are refused is not kept past the hello's deadline.
func test_a_connection_with_nothing_left_to_ask_is_let_go() -> void:
	_host("moss.zip", _spec("Moss One"))
	server.community_rows = _host_rows()
	var ws: WebSocketPeer = await _raw()
	for i in SgCardTransfer.MAX_LISTS + 1:
		_ask(ws, {"type": "cards"})
		await _answers(ws, 60)
	await _answers(ws, 1500)
	assert_eq(server._peers.size(), 0, "its lists spent, the connection is let go")
	ws.close()
	var asker: WebSocketPeer = await _raw()
	var started := Time.get_ticks_msec()
	while Time.get_ticks_msec() - started < SgLocalServer.HELLO_MS + 2000 and not server._peers.is_empty():
		_ask(asker, {"type": "card", "name": "Ghost Moss", "offset": 0})
		await _answers(asker, 400)
	assert_eq(server._peers.size(), 0, "refused requests do not keep a connection that never says hello")
	asker.close()


## 5: every copy of a card counts, those the scan refused as found later
## too. A replaced card's own zip is copied aside and saved over, so a copy
## beside the game stays behind it unused; every own copy of an extra card
## is set aside; an extra card with a copy beside the game stays, said so.
func test_every_copy_of_a_card_is_seen() -> void:
	server.stop()
	_host("fire.zip", _spec("Fire Moss", {"power": 5}))
	var fire := _zip(_own, "fire.zip", _spec("Fire Moss"))
	var beside_fire := _zip(_root.path_join("beside"), "fire.zip", _spec("Fire Moss", {"power": 2}))
	_zip(_own, "extra.zip", _spec("Own Extra"))
	_zip(_own, "extra_old.zip", _spec("Own Extra", {"power": 4}))
	var odd := _zip(_own, "odd.zip", _spec("Odd Moss"))
	_zip(_root.path_join("beside"), "odd.zip", _spec("Odd Moss", {"power": 3}))
	CommunityCards.refresh()
	var shelf := SgCardTransfer.shelf(_host_rows())
	var reply := SgCardTransfer.list_reply(shelf)
	var p := SgCardTransfer.plan(reply["cards"], String(reply["mark"]), SgCardTransfer.mine())
	assert_eq(p["replace"], ["Fire Moss"])
	assert_eq(p["shadowed"], ["Fire Moss"])
	assert_eq(p["set_aside"], ["Own Extra"])
	assert_eq(p["stuck"], ["Odd Moss"], "a copy beside the game would play once the own one went")
	assert_string_contains(SgCardTransfer.plan_text(p), "Other copies of Fire Moss")
	var result := SgCardTransfer.apply(p, {"Fire Moss": SgCardTransfer.bytes_of(SgCardTransfer.shelf_row(shelf, "Fire Moss"))})
	assert_eq(String(result["problem"]), "")
	assert_eq(CardRegistry.get_card("Fire Moss").power, 5, "the host's, saved over the own zip, plays")
	assert_false(CardRegistry.has_card("Own Extra"), "neither own copy is left to play")
	assert_true(CardRegistry.has_card("Odd Moss"))
	assert_eq(_files(SgCardTransfer.aside_folder()), ["extra.zip", "extra_old.zip", "fire.zip"])
	assert_true(FileAccess.file_exists(fire) and FileAccess.file_exists(beside_fire) and FileAccess.file_exists(odd),
		"nothing beside the game and nothing stuck is moved")
	assert_true(String(result["message"]).begins_with(SgCompatibility.COMMUNITY_WORDS), String(result["message"]))
	assert_string_contains(String(result["message"]), "Odd Moss")


## 6: a host that dribbles is let go: a chunk under the least a chunk may be,
## unless it is the zip's last, and the whole download's deadline.
func test_a_host_that_dribbles_is_let_go() -> void:
	_host("big.zip", _spec("Big Moss"), _large_art())
	var p: Dictionary = await _list()
	SgCardTransfer.chunk_bytes = 1000
	assert_eq(transfer.download(_target(), p), OK)
	assert_eq(transfer._give_up_at - transfer._opened,
		SgCardTransfer.GRACE_MS + int(p["bytes"]) * 1000 / SgCardTransfer.MIN_RATE, "the whole download's time")
	await _until(func() -> bool: return _got.has("failed") or _got.has("zips"))
	assert_eq(String(_got.get("failed", "")), SgCardTransfer.SLOW)
	assert_eq(server.chunks, 1, "given up at the first small chunk")
	assert_false(transfer.busy())
	# The last chunk of a zip may be small; a small zip is all last chunk.
	SgCardTransfer.chunk_bytes = SgCardTransfer.CHUNK
	_got.erase("failed")
	_host("small.zip", _spec("Small Moss"))
	var again: Dictionary = await _list()
	var small := again.duplicate(true)
	small["want"] = (again["want"] as Array).filter(func(row: Array) -> bool: return row[0] == "Small Moss")
	var zips: Dictionary = await _download(small)
	assert_lt((zips["Small Moss"] as PackedByteArray).size(), SgCardTransfer.MIN_CHUNK)


## 6 and 7 in the lobby: Cancel while the host's cards come; and the offer
## goes when the player turns to another host.
func test_the_lobby_cancels_and_forgets_the_last_host() -> void:
	server.hold_lists = true
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	await get_tree().process_frame
	assert_eq(lobby.client.connect_local(server.port, server.access_code), OK)
	lobby.client.build_fingerprint = "0".repeat(64)
	lobby.client.build_stamp["community"] = "1-000000000000"
	await _until(func() -> bool: return lobby._community_row.visible)
	assert_false(lobby._community_cancel.visible, "nothing to cancel yet")
	lobby._community_button.pressed.emit()
	assert_true(lobby._transfer.busy())
	await get_tree().process_frame
	assert_true(lobby._community_cancel.visible)
	assert_true(lobby._community_button.disabled)
	lobby._community_cancel.pressed.emit()
	assert_false(lobby._transfer.busy())
	assert_string_contains(lobby._notice.text, "cancelled")
	assert_true(lobby._notice.text.begins_with(SgCompatibility.COMMUNITY_WORDS))
	assert_true(lobby._community_row.visible and not lobby._community_cancel.visible, "the offer stays, to try again")
	# The player turns to host B, another version: A's offer goes for good.
	var stamp := SgCompatibility.stamp()
	stamp["game"] = "9.9.9"
	lobby._join_advert({"address": "192.168.1.77", "port": 17897, "name": "Host B", "fingerprint": "1".repeat(64),
		"rooms": 1, "build": "2".repeat(64), "stamp": stamp, "access": "invite", "tables": []}, "B's table")
	var said := lobby._notice.text
	assert_string_contains(said, "9.9.9")
	lobby._refresh()
	assert_eq(lobby._notice.text, said, "B's answer stays")
	assert_false(lobby._community_row.visible, "no offer of host A's cards")
	lobby.client.forget()


## 8: listing packs nothing — a set's card is listed at the most its zip can
## be — the list is made once a pool, and a set's card comes packed alone,
## a plain card zip of its own.
func test_the_list_packs_nothing_and_a_set_s_card_comes_alone() -> void:
	var art := _picture(510, 396)
	var icon := _picture(64, 64)
	assert_eq(CommunityCards.write_set_zip(_own.path_join("set.zip"), "Moss set", [
		{"spec": _spec("Set Moss A"), "art": art, "icon": icon},
		{"spec": _spec("Set Moss B", {"power": 2}), "art": art, "icon": icon}]), "")
	var single := _zip(_own, "single.zip", _spec("Single Moss"))
	CommunityCards.refresh()
	assert_eq(CardRegistry.community_names().size(), 3)
	var ws: WebSocketPeer = await _raw()
	_ask(ws, {"type": "cards"})
	var got: Array = await _answers(ws, 300)
	assert_eq(got.size(), 1)
	assert_true(SgCardTransfer.valid_list(got[0]))
	assert_eq(server.packs, 0, "nothing packed to list the cards")
	assert_true(server._sending.is_empty())
	var sizes := {}
	for row: Array in got[0]["cards"]:
		sizes[String(row[0])] = int(row[2])
	assert_eq(sizes["Single Moss"], FileAccess.get_file_as_bytes(single).size(), "a single zip's exact size")
	for card in ["Set Moss A", "Set Moss B"]:
		assert_gte(sizes[card], CommunityCards.zip_bytes_of(card).size(), "at most: " + card)
	assert_true(is_same(server._card_list(), server._card_list()), "made once a pool")
	ws.close()
	var p := SgCardTransfer.plan(got[0]["cards"], String(got[0]["mark"]), {})
	var zips: Dictionary = await _download(p)
	assert_eq(server.packs, 3, "each card read or packed once")
	for card in ["Set Moss A", "Set Moss B", "Single Moss"]:
		var row: Array = (p["want"] as Array).filter(func(r: Array) -> bool: return r[0] == card)[0]
		var bytes: PackedByteArray = zips[card]
		assert_eq(SgCardTransfer._check(card, String(row[1]), int(row[2]), bytes), "", card + " is a plain card zip")
	# Past the most cards a host lists, nothing is measured and the list is refused.
	var many: Array = []
	for i in SgCardTransfer.MAX_LIST + 1:
		many.append({"name": "Card %d" % i, "digest": "0".repeat(64), "size": 0, "spec": {}})
	assert_string_contains(String(SgCardTransfer.list_reply(many)["error"]), "more than 512")


## 9: an undo names what it could not put back, and rebuilds the pool.
func test_an_undo_names_what_it_leaves_behind() -> void:
	var mine := _zip(_own, "mine.zip", _spec("Mine Moss"))
	DirAccess.make_dir_recursive_absolute(SgCardTransfer.aside_folder())
	var aside := SgCardTransfer.aside_folder().path_join("mine.zip")
	DirAccess.copy_absolute(mine, aside)
	var pool := CardRegistry.revision
	# Its place was taken meanwhile: the set-aside card stays, and is named.
	var words := SgCardTransfer._undo([[mine, aside, "move"]], [])
	assert_string_contains(words, "Left behind: yours, mine.zip")
	assert_true(FileAccess.file_exists(aside) and FileAccess.file_exists(mine), "nothing lost, nothing overwritten")
	assert_gt(CardRegistry.revision, pool, "the pool rebuilt")


## 10: a batch a crash cut short is offered back when the lobby opens, and
## put back as it was; a record naming places outside the own folder is
## not followed.
func test_a_cut_short_batch_is_put_back_from_the_lobby() -> void:
	var fire := _zip(_own, "fire.zip", _spec("Fire Moss"))
	var extra := _zip(_own, "extra.zip", _spec("Own Extra"))
	var fire_bytes := FileAccess.get_file_as_bytes(fire)
	var aside := SgCardTransfer.aside_folder()
	var new_moss := _own.path_join("new_moss.zip")
	var moves := [[extra, aside.path_join("extra.zip"), "move"], [fire, aside.path_join("fire.zip"), "copy"]]
	assert_true(SgCardTransfer._write_batch(moves, [fire, new_moss]))
	# The batch got this far: both set aside, Fire Moss saved over, New Moss in.
	DirAccess.rename_absolute(extra, aside.path_join("extra.zip"))
	DirAccess.copy_absolute(fire, aside.path_join("fire.zip"))
	_zip(_own, "fire.zip", _spec("Fire Moss", {"power": 5}))
	_zip(_own, "new_moss.zip", _spec("New Moss"))
	CommunityCards.refresh()
	assert_true(SgCardTransfer.left_batch())
	# No host here: nothing holds the catalogue.
	server.stop()
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	await _until(func() -> bool: return UiChrome.open_popup(lobby) != null)
	(UiChrome.open_popup(lobby).find_child("RestoreCards", true, false) as Button).pressed.emit()
	assert_string_contains(lobby._notice.text, "Your cards are as they were.")
	assert_eq(_files(_own), ["extra.zip", "fire.zip"])
	assert_eq(FileAccess.get_file_as_bytes(fire), fire_bytes, "the own Fire Moss is back")
	assert_eq(_files(aside), [])
	assert_false(SgCardTransfer.left_batch())
	assert_eq(CardRegistry.get_card("Fire Moss").power, 1)
	assert_false(CardRegistry.has_card("New Moss"))
	# A record that names a place outside the own folder moves nothing.
	var outside := _root.path_join("beside/elsewhere.zip")
	_zip(_root.path_join("beside"), "elsewhere.zip", _spec("Far Moss"))
	assert_true(SgCardTransfer._write_batch([[outside, aside.path_join("elsewhere.zip"), "move"]], [outside]))
	DirAccess.copy_absolute(outside, aside.path_join("elsewhere.zip"))
	assert_string_contains(SgCardTransfer.restore_batch(), "could not be read")
	assert_true(FileAccess.file_exists(outside), "not removed")
	assert_false(SgCardTransfer.left_batch())
