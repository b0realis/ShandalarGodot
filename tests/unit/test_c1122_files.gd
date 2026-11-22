extends GutTest
## CARD ZIPS, THE SCAN AND THE SHARED ZIP READER (campaign 2026-11-22).
## One list of entries whoever reads a zip ([PluginPackage]: a zip of two
## end records, a zip64 record, bytes after the list, a header that names
## another size — all refused before anything is unpacked, for card zips
## and for adventure plugin zips alike); pictures kept as places, not
## bytes; the scan's memory kept between starts and never trusted; the
## words of a card held to one plain line; the set-aside shelf; a name a
## switched-off card pack has; file names; and what Import says card by card.

const ZIPS := preload("res://tests/support/plugin_zips.gd")
const ROOT := "user://community_cards_test_c1122"

var _root := ""
var _own := ""
var _stash := ""
var _own_free := false


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root.path_join("beside"))
	DirAccess.make_dir_recursive_absolute(_root.path_join("decks"))
	# The profile's own folder waits aside, untouched, while a test runs.
	_own = ProjectSettings.globalize_path(CommunityCards.own_folder())
	_stash = _root + "_stash"
	_own_free = not DirAccess.dir_exists_absolute(_own)
	if not _own_free and not DirAccess.dir_exists_absolute(_stash):
		_own_free = DirAccess.rename_absolute(_own, _stash) == OK
	assert_true(_own_free, "the own folder waits aside")
	CommunityCards.ensure_own_folder()
	CommunityCards.folders_override = [_own, _root.path_join("beside")]
	CommunityCards.cache_file_override = ""
	CommunityCards.forget_scan_memory()
	CommunityCards.refresh()


func after_each() -> void:
	CommunityCards.folders_override = []
	CommunityCards.cache_file_override = ""
	SgCardTransfer.decks_folder_override = ""
	AdventureTransfer.on_android = OS.has_feature("android")
	if _own_free:
		_wipe(_own, true)
	if DirAccess.dir_exists_absolute(_stash) and not DirAccess.dir_exists_absolute(_own):
		DirAccess.rename_absolute(_stash, _own)
	_wipe(_root)
	CommunityCards.forget_scan_memory()
	CommunityCards.refresh()


func _wipe(dir: String, own := false) -> void:
	if not (own or dir.contains("community_cards_test_c1122")) or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub), own)
	for file in here.get_files():
		DirAccess.remove_absolute(dir.path_join(file))
	DirAccess.remove_absolute(dir)


func _spec(card: String, extra := {}) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": card, "cost": "{G}",
		"types": ["creature"], "power": 1, "toughness": 1, "rarity": "common",
		"artist": "A. Painter", "set_name": "Test set", "look": {"border": "black"}, "abilities": []}
	spec.merge(extra, true)
	return spec


func _png(w: int, h: int, color := Color(0.2, 0.6, 0.3)) -> PackedByteArray:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(color)
	return image.save_png_to_buffer()


func _icon() -> Dictionary:
	return {"bytes": _png(64, 64), "kind": "png"}


func _art() -> Dictionary:
	return {"bytes": _png(255, 198, Color(0.5, 0.2, 0.2)), "kind": "png"}


func _store(path: String, bytes: PackedByteArray) -> void:
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(bytes)
	file.close()


## A zip packed by the engine: [param entries] `[name under top, bytes]`.
func _packed(entries: Array, top := "top") -> PackedByteArray:
	var path := _root.path_join("packed.tmp")
	var zip := ZIPPacker.new()
	zip.open(path)
	for entry in entries:
		zip.start_file(top + "/" + String(entry[0]))
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()
	var bytes := FileAccess.get_file_as_bytes(path)
	DirAccess.remove_absolute(path)
	return bytes


func _card_entries(card: String) -> Array:
	return [["card.json", JSON.stringify(_spec(card)).to_utf8_buffer()], ["icon.png", _png(64, 64)]]


func _plugin_entries() -> Array:
	var out: Array = []
	for rel in ZIPS.files_of(ZIPS.FIXTURE):
		out.append([rel, FileAccess.get_file_as_bytes(ZIPS.FIXTURE.path_join(rel))])
	return out


func _end_of(bytes: PackedByteArray) -> int:
	var at := bytes.size() - 22
	while at >= 0 and bytes.decode_u32(at) != 0x06054b50:
		at -= 1
	return at


## THE REVIEWER'S ZIP of two end records: the one whose comment reaches the
## file's end lists [param good] — small, harmless files — and the LAST
## end mark in the file, inside that comment, lists entries of the same
## names that unpack to [param big] bytes each.
func _two_faced(good_entries: Array, top: String, big: int) -> PackedByteArray:
	var zeros := PackedByteArray()
	zeros.resize(big)
	var evil := _packed([[String(good_entries[0][0]), zeros]], top)
	var good := _packed(good_entries, top)
	var e_end := _end_of(evil)
	var e_dir := evil.decode_u32(e_end + 16)
	var e_count := evil.decode_u16(e_end + 10)
	var prefix := evil.slice(0, e_end)
	var shift := prefix.size()
	var g_end := _end_of(good)
	var g_dir := good.decode_u32(g_end + 16)
	var g_size := good.decode_u32(g_end + 12)
	var g_count := good.decode_u16(g_end + 10)
	var body := good.slice(0, g_end)
	var at := g_dir
	for n in g_count:
		body.encode_u32(at + 42, body.decode_u32(at + 42) + shift)
		at += 46 + body.decode_u16(at + 28) + body.decode_u16(at + 30) + body.decode_u16(at + 32)
	var real := PackedByteArray()
	real.resize(22)
	real.encode_u32(0, 0x06054b50)
	real.encode_u16(8, g_count)
	real.encode_u16(10, g_count)
	real.encode_u32(12, g_size)
	real.encode_u32(16, g_dir + shift)
	real.encode_u16(20, 22)
	var fake_at := shift + body.size() + 22
	var fake := PackedByteArray()
	fake.resize(22)
	fake.encode_u32(0, 0x06054b50)
	fake.encode_u16(8, e_count)
	fake.encode_u16(10, e_count)
	fake.encode_u32(12, fake_at - e_dir)
	fake.encode_u32(16, e_dir)
	return prefix + body + real + fake


## A raw zip of stored entries: `{name, bytes}` and optionally `size` (what
## the zip's list says it unpacks to), `local_size` and `local_packed`
## (what the entry's own header says), `method`; then a [param comment] in
## the end record and [param after] the whole zip.
func _raw(entries: Array, comment := PackedByteArray(), after := PackedByteArray()) -> PackedByteArray:
	var out := PackedByteArray()
	var central := PackedByteArray()
	for entry: Dictionary in entries:
		var name := String(entry["name"]).to_utf8_buffer()
		var data: PackedByteArray = entry["bytes"]
		var size := int(entry.get("size", data.size()))
		var crc: int = ZIPS.crc32(data)
		var offset := out.size()
		var local := PackedByteArray()
		local.resize(30)
		local.encode_u32(0, 0x04034b50)
		local.encode_u16(4, 20)
		local.encode_u16(8, int(entry.get("method", 0)))
		local.encode_u32(14, crc)
		local.encode_u32(18, int(entry.get("local_packed", data.size())))
		local.encode_u32(22, int(entry.get("local_size", size)))
		local.encode_u16(26, name.size())
		out.append_array(local)
		out.append_array(name)
		out.append_array(data)
		var record := PackedByteArray()
		record.resize(46)
		record.encode_u32(0, 0x02014b50)
		record.encode_u16(4, 20)
		record.encode_u16(6, 20)
		record.encode_u16(10, int(entry.get("method", 0)))
		record.encode_u32(16, crc)
		record.encode_u32(20, data.size())
		record.encode_u32(24, size)
		record.encode_u16(28, name.size())
		record.encode_u32(42, offset)
		central.append_array(record)
		central.append_array(name)
	var directory_at := out.size()
	out.append_array(central)
	var end := PackedByteArray()
	end.resize(22)
	end.encode_u32(0, 0x06054b50)
	end.encode_u16(8, entries.size())
	end.encode_u16(10, entries.size())
	end.encode_u32(12, central.size())
	end.encode_u32(16, directory_at)
	end.encode_u16(20, comment.size())
	out.append_array(end)
	out.append_array(comment)
	out.append_array(after)
	return out


func _raw_card(card: String, top := "top") -> Array:
	return [{"name": top + "/card.json", "bytes": JSON.stringify(_spec(card)).to_utf8_buffer()},
		{"name": top + "/icon.png", "bytes": _png(64, 64)}]


func _raw_plugin() -> Array:
	return ZIPS.fixture_entries()


## Every way a zip's bytes reach this game, tried on [param bytes] as a
## card zip: none may unpack an entry, each must refuse.
func _refused_as_card_unread(bytes: PackedByteArray, what: String) -> void:
	var path := _root.path_join("hostile.zip")
	_store(path, bytes)
	var calls := PluginPackage.unpack_calls
	var allowed := PluginPackage.unpack_bytes
	assert_ne(String(PluginPackage.zip_entries(path)["problem"]), "", what + ": the list is refused")
	assert_false((CommunityCards.read(path)["problems"] as Array).is_empty(), what + ": the scan's reader refuses it")
	assert_ne(String(CommunityCards.install(bytes)["problem"]), "", what + ": Import and the LAN install refuse it")
	assert_ne(SgCardTransfer._check("Two Face", "0".repeat(64), bytes.size(), bytes), "", what + ": the LAN check refuses it")
	assert_ne(SgCardTransfer._plain_card_zip(path), "", what + ": the LAN's plain-zip check refuses it")
	assert_eq((CommunityCards.read_set(path)[0]["problems"] as Array).is_empty(), false, what + ": no set either")
	assert_eq(PluginPackage.read_one(path, "zip", "top", "card.json").size(), 0, what + ": no single entry is read")
	# In a scanned folder, at a start.
	_store(_own.path_join("hostile.zip"), bytes)
	CommunityCards.scan()
	assert_eq(CommunityCards.playable().size(), 0, what + ": the scan takes no card of it")
	DirAccess.remove_absolute(_own.path_join("hostile.zip"))
	CommunityCards.scan()
	assert_eq(PluginPackage.unpack_calls, calls, what + ": NOTHING was unpacked")
	assert_eq(PluginPackage.unpack_bytes, allowed, what + ": no room was made for any entry")


func _refused_as_plugin_unread(bytes: PackedByteArray, what: String) -> void:
	var path := _root.path_join("hostile_plugin.zip")
	_store(path, bytes)
	var calls := PluginPackage.unpack_calls
	var read := PluginPackage.read(path)
	assert_false((read["problems"] as Array).is_empty(), what + ": the plugin is refused")
	assert_true((read["files"] as Dictionary).is_empty(), what + ": no file of it is held")
	assert_eq(PluginPackage.read_one(path, "zip", "tiny_isle", "plugin.json").size(), 0, what + ": no single entry")
	assert_eq(PluginPackage.unpack_calls, calls, what + ": NOTHING was unpacked")


# ------------------------------------------------- bug 1: one list of entries --

func test_a_zip_of_two_end_records_is_refused_before_anything_is_unpacked() -> void:
	# The reviewer's bytes: under 60 KB on disk, 8 MiB behind the last end mark.
	var card := _two_faced(_card_entries("Two Face"), "top", 8 * 1024 * 1024)
	assert_lt(card.size(), CommunityCards.MAX_ZIP)
	_refused_as_card_unread(card, "two end records (card)")
	var plugin := _two_faced(_plugin_entries(), "tiny_isle", 8 * 1024 * 1024)
	_refused_as_plugin_unread(plugin, "two end records (plugin)")
	# The last end mark is the one record there is: its "list" — the big
	# entry's, with the small zip behind it — is not a list of rows alone.
	var path := _root.path_join("two.zip")
	_store(path, card)
	assert_string_contains(String(PluginPackage.zip_entries(path)["problem"]), "damaged")


func test_bytes_after_the_zip_and_a_comment_holding_an_end_record_are_refused() -> void:
	var garbage := "trailing garbage, not a zip's own".to_utf8_buffer()
	_refused_as_card_unread(_raw(_raw_card("Two Face"), PackedByteArray(), garbage), "bytes after the zip (card)")
	_refused_as_plugin_unread(_raw(_raw_plugin(), PackedByteArray(), garbage), "bytes after the zip (plugin)")
	# A comment that holds a whole end record of its own, then more comment.
	var fake := PackedByteArray()
	fake.resize(22)
	fake.encode_u32(0, 0x06054b50)
	fake.encode_u16(8, 1)
	fake.encode_u16(10, 1)
	fake.encode_u32(12, 46)
	var comment := "see: ".to_utf8_buffer() + fake + " :end".to_utf8_buffer()
	_refused_as_card_unread(_raw(_raw_card("Two Face"), comment), "an end record in the comment (card)")
	_store(_root.path_join("commented_twice.zip"), _raw(_raw_card("Two Face"), comment))
	assert_string_contains(String(PluginPackage.zip_entries(_root.path_join("commented_twice.zip"))["problem"]),
		"second end record")
	_refused_as_plugin_unread(_raw(_raw_plugin(), comment), "an end record in the comment (plugin)")
	# The same mark as the comment's very last bytes: no room for a record.
	var cut := "x".to_utf8_buffer() + fake.slice(0, 4)
	_refused_as_card_unread(_raw(_raw_card("Two Face"), cut), "an end mark at the file's end (card)")
	# An honest comment is no trouble.
	var path := _root.path_join("commented.zip")
	_store(path, _raw(_raw_card("Plain Comment"), "made with care".to_utf8_buffer()))
	assert_eq((CommunityCards.read(path)["problems"] as Array).size(), 0, "a zip with a plain comment still reads")


func test_a_zip64_record_behind_the_list_is_refused() -> void:
	# A zip64 end record and its locator in the comment: the engine's reader
	# would take that list, not the classic one.
	var entries := _raw_card("Two Face")
	var plain := _raw(entries)
	var record := PackedByteArray()
	record.resize(56)
	record.encode_u32(0, 0x06064b50)
	var locator := PackedByteArray()
	locator.resize(20)
	locator.encode_u32(0, 0x07064b50)
	locator.encode_s64(8, plain.size())
	locator.encode_u32(16, 1)
	_refused_as_card_unread(_raw(entries, record + locator), "a zip64 record (card)")
	_refused_as_plugin_unread(_zip64_plugin(), "a zip64 record (plugin)")


func _zip64_plugin() -> PackedByteArray:
	var plain := _raw(_raw_plugin())
	var record := PackedByteArray()
	record.resize(56)
	record.encode_u32(0, 0x06064b50)
	var locator := PackedByteArray()
	locator.resize(20)
	locator.encode_u32(0, 0x07064b50)
	locator.encode_s64(8, plain.size())
	locator.encode_u32(16, 1)
	return _raw(_raw_plugin(), record + locator)


func test_an_entry_whose_own_header_names_another_size_is_never_read() -> void:
	# The list says card.json is its honest size; the entry's own header
	# says 50 MB (and the other way round).
	for sizes: Array in [[-1, 50 * 1024 * 1024], [64, -1]]:
		var entries := _raw_card("Two Face")
		if int(sizes[0]) >= 0:
			entries[0]["size"] = int(sizes[0])
			entries[0]["local_size"] = (entries[0]["bytes"] as PackedByteArray).size()
		if int(sizes[1]) >= 0:
			entries[0]["local_size"] = int(sizes[1])
		var path := _root.path_join("lying.zip")
		_store(path, _raw(entries))
		var calls := PluginPackage.unpack_calls
		var listed := PluginPackage.zip_entries(path)
		assert_eq(String(listed["problem"]), "", "the list itself is whole")
		var got := PluginPackage.entry_bytes(FileAccess.open(path, FileAccess.READ), listed, listed["entries"][0], 1 << 20)
		assert_false(bool(got["ok"]), "the entry is refused")
		assert_eq(PluginPackage.unpack_calls, calls, "and not unpacked")
		assert_false((CommunityCards.read(path)["problems"] as Array).is_empty(), "the card is refused")
		assert_eq(PluginPackage.read_one(path, "zip", "top", "card.json").size(), 0)
	# The same for a plugin: its manifest's header disagrees with the list.
	var plugin := _raw_plugin()
	for entry: Dictionary in plugin:
		if String(entry["name"]).ends_with("/plugin.json"):
			entry["local_size"] = 40 * 1024 * 1024
	var plugin_path := _root.path_join("lying_plugin.zip")
	_store(plugin_path, _raw(plugin))
	var read := PluginPackage.read(plugin_path)
	assert_true((read["problems"] as Array).any(func(p: String) -> bool: return p.contains("could not be read whole")))
	assert_false((read["files"] as Dictionary).has("plugin.json"), "the lying entry is not held")


func test_an_entry_is_never_given_more_room_than_its_checked_size() -> void:
	var path := _root.path_join("whole.zip")
	var art := _png(255, 198)
	_store(path, _packed([["card.json", JSON.stringify(_spec("Roomy")).to_utf8_buffer()], ["icon.png", _png(64, 64)],
		["art.png", art]]))
	var listed := PluginPackage.zip_entries(path)
	var entry: Dictionary = (listed["entries"] as Array).filter(
		func(e: Dictionary) -> bool: return String(e["name"]) == "top/art.png")[0]
	var calls := PluginPackage.unpack_calls
	var allowed := PluginPackage.unpack_bytes
	# A cap below the entry's size: refused, nothing unpacked.
	var got := PluginPackage.entry_bytes(FileAccess.open(path, FileAccess.READ), listed, entry, art.size() - 1)
	assert_false(bool(got["ok"]))
	assert_eq(PluginPackage.unpack_calls, calls)
	assert_eq(PluginPackage.read_one(path, "zip", "top", "art.png", 100).size(), 0, "read_one holds to its cap")
	# Its own size: read whole, and the room made is exactly that.
	got = PluginPackage.entry_bytes(FileAccess.open(path, FileAccess.READ), listed, entry, art.size())
	assert_true(bool(got["ok"]))
	assert_eq(got["bytes"], art)
	assert_eq(PluginPackage.unpack_bytes - allowed, art.size(), "room for the checked size, no more")
	assert_eq(PluginPackage.read_one(path, "zip", "top", "art.png"), art)
	# A claim no deflate stream can honor is refused unread: 2 MiB from 20 bytes.
	var claim := entry.duplicate()
	claim["size"] = 2 * 1024 * 1024
	claim["packed"] = 20
	calls = PluginPackage.unpack_calls
	assert_false(bool(PluginPackage.entry_bytes(FileAccess.open(path, FileAccess.READ), listed, claim, 1 << 30)["ok"]))
	assert_eq(PluginPackage.unpack_calls, calls)
	# A list read from another file (a zip swapped since) unpacks nothing.
	_store(path, _packed(_card_entries("Swapped")))
	assert_false(bool(PluginPackage.entry_bytes(FileAccess.open(path, FileAccess.READ), listed, entry, 1 << 30)["ok"]))
	assert_eq(PluginPackage.unpack_calls, calls)


func test_whole_zips_read_as_ever_stored_or_deflated() -> void:
	var stored := _root.path_join("stored.zip")
	_store(stored, _raw(_raw_card("Stored Card")))
	var row := CommunityCards.read(stored)
	assert_eq((row["problems"] as Array).size(), 0, str(row["problems"]))
	assert_eq(row["name"], "Stored Card")
	var deflated := _root.path_join("deflated.zip")
	_store(deflated, _packed(_card_entries("Deflated Card") + [["art.png", _png(255, 198)]]))
	row = CommunityCards.read(deflated)
	assert_eq((row["problems"] as Array).size(), 0, str(row["problems"]))
	assert_eq(row["files"]["art"]["bytes"], _png(255, 198))
	var plugin := _root.path_join("plugin.zip")
	ZIPS.zip_folder(ZIPS.FIXTURE, plugin)
	var read := PluginPackage.read(plugin)
	assert_eq((read["problems"] as Array).size(), 0, str(read["problems"]))
	for rel in ZIPS.files_of(ZIPS.FIXTURE):
		assert_eq(read["files"][rel], FileAccess.get_file_as_bytes(ZIPS.FIXTURE.path_join(rel)), rel)
	ZIPS.write(plugin, ZIPS.fixture_entries())
	assert_eq((PluginPackage.read(plugin)["problems"] as Array).size(), 0, "a stored plugin zip too")


# ------------------------------------------------ bug 5: the words of a card --

func test_control_characters_line_breaks_and_direction_marks_are_refused() -> void:
	assert_eq(CommunityCards.text_problems(_spec("Plain Words", {"flavor": "One line.\nAnother."})), [] as Array[String])
	var bad := {
		"artist with a line break": {"artist": "A.\nPainter"},
		"artist with a bell": {"artist": "A." + char(7) + "Painter"},
		"set name with a tab": {"set_name": "Test\tset"},
		"set name turned right to left": {"set_name": "Test" + char(0x202E) + "tes"},
		"artist with an isolate": {"artist": char(0x2066) + "A. Painter"},
		"flavor with a tab": {"flavor": "A\tB"},
		"flavor turned right to left": {"flavor": char(0x202E) + "sdrawkcab"},
		"flavor of 150 lines": {"flavor": "\n".repeat(150) + "{T}: Draw three cards."},
		"flavor of 7 lines": {"flavor": "a\nb\nc\nd\ne\nf\ng"},
		"author with a line break": {"author": "Me\nYou"},
	}
	for what: String in bad:
		var spec := _spec("Odd Words", bad[what])
		assert_false(CommunityCards.text_problems(spec).is_empty(), what)
		var path := _root.path_join("odd.zip")
		_store(path, _packed([["card.json", JSON.stringify(spec).to_utf8_buffer()], ["icon.png", _png(64, 64)]]))
		assert_false((CommunityCards.read(path)["problems"] as Array).is_empty(), what + ": refused when read")
		assert_ne(CommunityCards.write_zip(_root.path_join("odd_out.zip"), spec, {}, _icon()), "", what + ": refused when saved")
		assert_ne(String(CommunityCards.install(FileAccess.get_file_as_bytes(path))["problem"]), "", what + ": not installed")
	assert_eq(CommunityCards.text_problems(_spec("Six Lines", {"flavor": "a\nb\nc\nd\ne\nf"})), [] as Array[String])


# --------------------------------------- feature: author, card_version, id --

func test_the_optional_maker_keys_are_checked_and_change_nothing_else() -> void:
	var plain := _spec("Maker Card")
	var signed := _spec("Maker Card", {"author": "A. Maker", "card_version": 3, "id": "maker-card.v3_x"})
	assert_eq(CommunityCard.problems(signed), [] as Array[String])
	assert_eq(CommunityCards.text_problems(signed), [] as Array[String])
	assert_eq(CommunityCards.save(signed, {}, _icon()), "")
	CommunityCards.refresh()
	assert_eq(CommunityCards.saved_spec("Maker Card").get("author"), "A. Maker")
	assert_eq(int(CommunityCards.saved_spec("Maker Card").get("card_version")), 3)
	for bad: Dictionary in [{"id": ""}, {"id": "has space"}, {"id": "x".repeat(65)}, {"id": 7}, {"card_version": 0},
			{"card_version": 1.5}, {"card_version": "2"}, {"card_version": 10000}, {"author": 5},
			{"author": "x".repeat(61)}]:
		assert_false(CommunityCards.text_problems(_spec("Maker Card", bad)).is_empty(), str(bad))
	# The verdict an import shows.
	assert_eq(CommunityCards.compare(plain, plain.duplicate(true)), "identical")
	assert_eq(CommunityCards.compare(plain, signed), "look", "the maker's keys do not play")
	assert_eq(CommunityCards.compare(plain, _spec("Maker Card", {"flavor": "New words.", "rarity": "rare"})), "look")
	assert_eq(CommunityCards.compare(plain, _spec("Maker Card", {"power": 2})), "plays")
	# A card without the keys has the digest it ever had: what plays, all
	# but the look ([SgCompatibility.card_digest] is untouched).
	var playing := plain.duplicate(true)
	for key in ["look", "flavor", "artist", "set_name", "rarity", "format", "version"]:
		playing.erase(key)
	assert_eq(SgCompatibility.card_digest(plain), JSON.stringify(playing, "", true).sha256_text())
	# The maker's keys are no part of what plays: the same card at a LAN table.
	assert_eq(SgCompatibility.card_digest(signed), SgCompatibility.card_digest(plain))
	assert_eq(SgCompatibility.card_digest(_spec("Maker Card", {"author": "Another", "card_version": 9, "id": "z"})),
		SgCompatibility.card_digest(signed))
	assert_ne(SgCompatibility.card_digest(_spec("Maker Card", {"author": "A. Maker", "power": 2})),
		SgCompatibility.card_digest(signed))
	# Import says how a card already here differs.
	var incoming := _root.path_join("incoming.zip")
	assert_eq(CommunityCards.write_zip(incoming, _spec("Maker Card", {"power": 4}), {}, _icon()), "")
	var done := CommunityCards.import_file(incoming)
	assert_eq(done["here"], ["Maker Card"] as Array[String])
	assert_eq(done["cards"], [{"name": "Maker Card", "result": "here", "problem": "", "differs": "plays"}] as Array[Dictionary])


# ------------------------------------- bug 6: pictures kept as places, not bytes --

func _holds_bytes(value: Variant) -> bool:
	if value is PackedByteArray:
		return true
	if value is Dictionary:
		for key: Variant in value:
			if _holds_bytes(value[key]):
				return true
	if value is Array:
		for item: Variant in value:
			if _holds_bytes(item):
				return true
	return false


func test_the_scan_keeps_where_a_picture_is_and_reads_it_when_wanted() -> void:
	var art := _art()
	var tiers := {"common": _icon(), "rare": {"bytes": _png(48, 48, Color.GOLD), "kind": "png"}}
	assert_eq(CommunityCards.save(_spec("Picture Card"), art, tiers), "")
	assert_eq(CommunityCards.save(_spec("Plain Card"), {}, _icon()), "")
	assert_eq(CommunityCards.write_set_zip(_root.path_join("beside").path_join("a_set.zip"), "Test set", [
		{"spec": _spec("Set Card"), "art": art, "icon": _icon()}]), "")
	CommunityCards.refresh()
	assert_false(_holds_bytes(CommunityCards._files), "no picture is held after a scan")
	assert_false(_holds_bytes(CommunityCards._read_cache), "nor in the scan's memory")
	assert_false(_holds_bytes(CommunityCards._rows))
	# Asked for, the pictures are the card's own, in the shape they ever had.
	var files := CommunityCards.files_of("Picture Card")
	assert_eq(files["art"], art)
	assert_eq(files["icon"], tiers)
	assert_eq(CommunityCards.files_of("Plain Card"), {"icon": _icon()})
	assert_eq(CommunityCards.files_of("Set Card"), {"art": art, "icon": _icon()}, "a set's card too")
	assert_eq(CommunityCards.file_sizes_of("Picture Card").size(), 3)
	assert_eq(CommunityCards.file_sizes_of("Plain Card"), [(_icon()["bytes"] as PackedByteArray).size()] as Array[int])
	# One decode a picture: the texture is made once and kept.
	var calls := PluginPackage.unpack_calls
	var first := CommunityCards.art_texture("Picture Card")
	assert_not_null(first)
	assert_eq(PluginPackage.unpack_calls, calls + 1, "the art is read when first shown")
	assert_same(CommunityCards.art_texture("Picture Card"), first)
	assert_not_null(CommunityCards.icon_texture("Picture Card", "rare"))
	assert_same(CommunityCards.icon_texture("Picture Card", "rare"), CommunityCards.icon_texture("Picture Card", "rare"))
	assert_not_null(CommunityCards.art_texture("Set Card"))
	calls = PluginPackage.unpack_calls
	CommunityCards.art_texture("Picture Card")
	CommunityCards.scan()
	CommunityCards.art_texture("Picture Card")
	assert_eq(PluginPackage.unpack_calls, calls, "kept over a scan while the zip stays the same")
	# A zip swapped since the scan for one whose art breaks the guidelines:
	# the picture is checked again when read, and not shown.
	var path := CommunityCards.own_path_of("Plain Card")
	_store(path, _packed([["card.json", JSON.stringify(_spec("Plain Card")).to_utf8_buffer()],
		["icon.png", _png(700, 700)]], "plain_card"))
	assert_eq(CommunityCards.files_of("Plain Card"), {}, "a picture past the guidelines is not handed out")
	# The LAN shelf sizes a card without reading a picture.
	calls = PluginPackage.unpack_calls
	assert_gt(SgCardTransfer._bound_of("Picture Card", _spec("Picture Card")), (art["bytes"] as PackedByteArray).size())
	assert_eq(PluginPackage.unpack_calls, calls)


# -------------------------------------------------- polish: the kept scan memory --

func _rows_now() -> Array:
	var out: Array = []
	for row in CommunityCards.all():
		out.append(row.duplicate(true))
	return out


func test_the_scan_memory_kept_on_disk_equals_a_fresh_scan_and_is_never_trusted() -> void:
	var cache := _root.path_join("scan_cache.json")
	CommunityCards.cache_file_override = cache
	assert_eq(CommunityCards.save(_spec("Kept One", {"flavor": "Line one.\nLine two."}), _art(), _icon()), "")
	assert_eq(CommunityCards.save(_spec("Kept Two"), {}, {"common": _icon(), "rare": _icon()}), "")
	_store(_own.path_join("refused.zip"), _packed([["card.json", "{}".to_utf8_buffer()], ["icon.png", _png(64, 64)]]))
	assert_eq(CommunityCards.write_set_zip(_own.path_join("kept_set.zip"), "Test set", [
		{"spec": _spec("Kept Three"), "art": {}, "icon": _icon()}]), "")
	CommunityCards.forget_scan_memory()
	CommunityCards.scan()
	var fresh := _rows_now()
	var fresh_files := CommunityCards.files_of("Kept One")
	assert_true(FileAccess.file_exists(cache), "the memory is written")
	assert_eq(fresh.size(), 4)
	# A new start: nothing is unpacked, and every row is the fresh one.
	CommunityCards.forget_scan_memory()
	var calls := PluginPackage.unpack_calls
	CommunityCards.scan()
	assert_eq(PluginPackage.unpack_calls, calls, "a start with the memory unpacks no zip")
	assert_eq(_rows_now(), fresh, "the kept rows equal the fresh ones")
	assert_eq(CommunityCards.files_of("Kept One"), fresh_files)
	assert_eq(CommunityCards.spec_of("Kept One"), fresh[0]["spec"])
	# A zip that changed is read again; the others are not.
	assert_eq(CommunityCards.save(_spec("Kept Two", {"power": 5}), {}, _icon()), "")
	CommunityCards.forget_scan_memory()
	calls = PluginPackage.unpack_calls
	CommunityCards.scan()
	assert_gt(PluginPackage.unpack_calls, calls, "the changed zip is read")
	assert_lt(PluginPackage.unpack_calls - calls, 4, "only that one")
	assert_eq(int(CommunityCards.spec_of("Kept Two")["power"]), 5)
	fresh = _rows_now()
	# A zip deleted is gone from the pool whatever the memory says.
	DirAccess.remove_absolute(CommunityCards.own_path_of("Kept One"))
	CommunityCards.forget_scan_memory()
	CommunityCards.scan()
	assert_false(CommunityCards.found("Kept One"))
	# NEVER TRUSTED: a memory edited to pass a card that breaks the rules,
	# or to point a picture elsewhere, is dropped and the zip read anew.
	var text := FileAccess.get_file_as_string(cache)
	assert_string_contains(text, "Kept Two")
	for edit: Array in [["\"power\":5.0", "\"power\":500.0"], ["\"icon.png\"", "\"../../secret.png\""],
			["\"Kept Two\"", "\"Kept\\nTwo\""], [CommunityCards.CACHE_FORMAT, "another-format"]]:
		var edited := text.replace(String(edit[0]), String(edit[1]))
		assert_ne(edited, text, "the edit took: %s" % [edit[0]])
		_store(cache, edited.to_utf8_buffer())
		CommunityCards.forget_scan_memory()
		calls = PluginPackage.unpack_calls
		CommunityCards.scan()
		assert_gt(PluginPackage.unpack_calls, calls, "%s: the zip is read again" % [edit[1]])
		assert_eq(int(CommunityCards.spec_of("Kept Two")["power"]), 5, "%s: the card is the zip's" % [edit[1]])
		assert_eq(CommunityCards.files_of("Kept Two"), {"icon": _icon()})
	# Rubbish for a memory is no memory.
	_store(cache, "not json at all {".to_utf8_buffer())
	CommunityCards.forget_scan_memory()
	CommunityCards.scan()
	assert_true(CommunityCards.found("Kept Two"))
	assert_true(CommunityCards.found("Kept Three"))


func test_a_number_too_large_for_json_is_refused_quietly() -> void:
	var parsed := PluginPackage.json("card.json", "{\n\"power\": 1e999}".to_utf8_buffer())
	assert_eq(String(parsed["problem"]), "card.json: line 2: a number is too large.")
	assert_ne(String(PluginPackage.json("a.json", ("[" + "9".repeat(400) + "]").to_utf8_buffer())["problem"]), "")
	assert_ne(String(PluginPackage.json("a.json", "[2E+0400]".to_utf8_buffer())["problem"]), "")
	# Honest numbers, and the same digits inside a text, are as ever.
	var fine := PluginPackage.json("a.json", "{\"t\": \"1e999 \\\" 5e500\", \"n\": 1e3, \"m\": 2.5E-300, \"k\": 12e100}".to_utf8_buffer())
	assert_eq(String(fine["problem"]), "")
	assert_eq(fine["value"]["t"], "1e999 \" 5e500")
	assert_eq(fine["value"]["n"], 1000.0)


# ------------------------------------------------------- bug 7: file names --

func test_a_card_left_as_zip_old_is_put_back_and_device_names_are_avoided() -> void:
	assert_eq(CommunityCards.save(_spec("Cut Short"), {}, _icon()), "")
	CommunityCards.refresh()
	var path := CommunityCards.own_path_of("Cut Short")
	# A save cut short between its two renames: only x.zip.old is left.
	assert_eq(DirAccess.rename_absolute(path, path + ".old"), OK)
	CommunityCards.refresh()
	assert_true(CommunityCards.found("Cut Short"), "the card is back")
	assert_true(FileAccess.file_exists(path))
	assert_false(FileAccess.file_exists(path + ".old"))
	# Beside a whole zip, an .old one is left alone (a save under way).
	_store(path + ".old", "old".to_utf8_buffer())
	CommunityCards.refresh()
	assert_true(FileAccess.file_exists(path + ".old"))
	assert_true(CommunityCards.found("Cut Short"))
	DirAccess.remove_absolute(path + ".old")
	for device in ["Con", "PRN", "aux", "Nul", "COM1", "lpt9"]:
		assert_eq(CommunityCards.file_name(device), "card_" + device.to_lower(), device)
	for fine in ["Conn", "Com0", "Com10", "Lpt", "Console", "Elf Lord"]:
		assert_false(CommunityCards.file_name(fine).begins_with("card_"), fine)
	assert_eq(CommunityCards.file_name("Elf Lord"), "elf_lord")
	assert_eq(CommunityCards.save(_spec("Con"), {}, _icon()), "")
	CommunityCards.refresh()
	assert_eq(CommunityCards.own_path_of("Con").get_file(), "card_con.zip")


# ------------------------------------------- bug 4: a switched-off pack's name --

func test_a_name_of_any_card_pack_is_refused_and_a_left_out_card_is_said() -> void:
	# Every pack's names are known, in play or not.
	var packs: Array = [FallenEmpiresPack.names(), IceAgePack.names(), HomelandsPack.names(), AlliancesPack.names(),
		PortalPack.names(), FifthEditionPack.names(), MirageBlockPack.names(), TempestBlockPack.names(),
		UrzaBlockPack.names()]
	var off := ""
	for names: Array in packs:
		assert_gt(names.size(), 50)
		assert_eq(CommunityCards.game_card_like(String(names[0]).to_upper()), String(names[0]))
		for each in names:
			if off == "" and not CardRegistry.has_card(String(each)) and CommunityCard.problems(_spec(String(each))).is_empty():
				off = String(each)
	assert_eq(CommunityCards.game_card_like("No Such Card Anywhere"), "")
	if off != "":
		# A card of a pack that is switched off now: not in the pool, refused all the same.
		assert_eq(CardRegistry.game_name_like(off), "")
		var zip := _root.path_join("clash.zip")
		assert_eq(CommunityCards.write_zip(zip, _spec(off), {}, _icon()), "")
		var done := CommunityCards.import_file(zip)
		assert_eq(done["names"], [] as Array[String])
		assert_string_contains(String(done["problems"][0]), "already in the game")
		assert_string_contains(SgCardTransfer._check(off, "0".repeat(64), 1 << 20, FileAccess.get_file_as_bytes(zip)),
			"already in the game")
	else:
		pass_test("every card pack is in play in this profile: the pool check covers them")
	# A card the pool leaves out for a game card of its name is said in one line.
	assert_eq(CommunityCards.skipped_notice(), "")
	var bolt := _spec("Lightning Bolt")
	CardRegistry.configure_community([bolt, _spec("Fine Card")], [
		{"name": "Lightning Bolt", "set": CommunityCard.SET_CODE, "rarity": "common", "artist": ""},
		{"name": "Fine Card", "set": CommunityCard.SET_CODE, "rarity": "common", "artist": ""}])
	CardRegistry.ensure_loaded()
	assert_eq(CardRegistry.community_skipped(), ["Lightning Bolt"] as Array[String])
	var notice := CommunityCards.skipped_notice()
	assert_string_contains(notice, "Lightning Bolt")
	assert_false(notice.contains("\n"), "one line")
	assert_false(notice.contains("Fine Card"))
	CommunityCards.refresh()
	assert_eq(CommunityCards.skipped_notice(), "")


# ---------------------------------------------------------- the set-aside shelf --

func test_set_aside_cards_are_listed_put_back_and_deleted() -> void:
	assert_eq(CommunityCards.SET_ASIDE, SgCardTransfer.SET_ASIDE, "one folder, named in both classes")
	assert_eq(CommunityCards.ASIDE_BATCH, SgCardTransfer.BATCH)
	assert_eq(CommunityCards.aside_folder(), SgCardTransfer.aside_folder())
	assert_eq(CommunityCards.set_aside_list(), [] as Array[Dictionary])
	assert_eq(CommunityCards.set_aside_count(), 0)
	assert_eq(CommunityCards.set_aside_size(), 0)
	var aside := CommunityCards.aside_folder()
	var shelf_zip := _root.path_join("shelf.zip")
	assert_eq(CommunityCards.write_zip(shelf_zip, _spec("Shelf Card"), _art(), _icon()), "")
	var bytes := FileAccess.get_file_as_bytes(shelf_zip)
	_store(aside.path_join("shelf_card.zip"), bytes)
	_store(aside.path_join("broken.zip"), _packed([["card.json", "{}".to_utf8_buffer()], ["icon.png", _png(64, 64)]]))
	_store(aside.path_join(".batch.json.bak"), "x".to_utf8_buffer())
	var rows := CommunityCards.set_aside_list()
	assert_eq(rows.size(), 2, "the zips, nothing else")
	assert_eq(rows[1]["name"], "Shelf Card")
	assert_eq(rows[1]["file"], "shelf_card.zip")
	assert_eq(rows[1]["bytes"], bytes.size())
	assert_gt(int(rows[1]["when"]), 1600000000)
	assert_eq(rows[1]["problem"], "")
	assert_ne(rows[0]["problem"], "", "a zip that would be refused says why")
	assert_eq(CommunityCards.set_aside_count(), 2)
	assert_eq(CommunityCards.set_aside_size(), int(rows[0]["bytes"]) + int(rows[1]["bytes"]))
	assert_eq(CommunityCards.set_aside_list(), rows, "listed again from memory, the same")
	assert_false(CommunityCards.found("Shelf Card"), "a set-aside card is not in play")
	# Only a zip of the folder itself, by name.
	for bad in ["", "../shelf_card.zip", "nope.zip", ".batch.json", "sub/shelf_card.zip", aside.path_join("shelf_card.zip")]:
		assert_ne(CommunityCards.put_back(bad), "", bad)
		assert_false(CommunityCards.delete_aside(bad), bad)
	# Put back: through every install check.
	assert_ne(CommunityCards.put_back("broken.zip"), "", "a refused zip stays set aside")
	assert_true(FileAccess.file_exists(aside.path_join("broken.zip")))
	assert_eq(CommunityCards.put_back("shelf_card.zip"), "")
	assert_true(CommunityCards.found("Shelf Card"))
	assert_true(CardRegistry.has_community("Shelf Card"), "and in the pool")
	assert_false(FileAccess.file_exists(aside.path_join("shelf_card.zip")))
	# The same card set aside again while one is here: kept on the shelf.
	_store(aside.path_join("shelf_card.zip"), bytes)
	assert_string_contains(CommunityCards.put_back("shelf_card.zip"), "here already")
	assert_true(FileAccess.file_exists(aside.path_join("shelf_card.zip")))
	# A cut-short transfer is settled first.
	_store(aside.path_join(".batch.json"), "{}".to_utf8_buffer())
	assert_string_contains(CommunityCards.put_back("shelf_card.zip"), "cut short")
	DirAccess.remove_absolute(aside.path_join(".batch.json"))
	assert_true(CommunityCards.delete_aside("shelf_card.zip"))
	assert_true(CommunityCards.delete_aside("broken.zip"))
	assert_eq(CommunityCards.set_aside_count(), 0)
	# A set zip on the shelf comes back as Import takes a set.
	assert_eq(CommunityCards.write_set_zip(aside.path_join("old_set.zip"), "Old set", [
		{"spec": _spec("Old One"), "art": {}, "icon": _icon()}, {"spec": _spec("Old Two"), "art": {}, "icon": _icon()}]), "")
	assert_true(bool(CommunityCards.set_aside_list()[0]["set"]))
	assert_eq(CommunityCards.put_back("old_set.zip"), "")
	assert_true(CardRegistry.has_community("Old One") and CardRegistry.has_community("Old Two"))
	assert_eq(CommunityCards.set_aside_count(), 0)


func test_a_save_names_its_missing_community_cards() -> void:
	var names: Array[String] = ["Zzyx the Unprinted"]
	assert_eq(MatchSaves.cards_refusal(names, "This match"),
		"This match holds cards this game does not have: Zzyx the Unprinted.", "a card nobody knows: as ever")
	var zip := _root.path_join("gone.zip")
	assert_eq(CommunityCards.write_zip(zip, _spec("Gone Aside"), {}, _icon()), "")
	_store(CommunityCards.aside_folder().path_join("gone_aside.zip"), FileAccess.get_file_as_bytes(zip))
	_store(_own.path_join("refused_here.zip"), _packed([
		["card.json", JSON.stringify(_spec("Refused Here", {"power": 500})).to_utf8_buffer()], ["icon.png", _png(64, 64)]]))
	CommunityCards.refresh()
	assert_eq(CommunityCards.known_missing(["Gone Aside", "refused_here", "Zzyx the Unprinted"]),
		{"Gone Aside": true, "refused_here": false})
	names = ["Gone Aside", "Zzyx the Unprinted"]
	var text := MatchSaves.cards_refusal(names, "This match")
	assert_string_contains(text, "This match holds community cards that are not in play now: Gone Aside.")
	assert_string_contains(text, "Set aside in ")
	assert_string_contains(text, CommunityCards.SET_ASIDE)
	assert_string_contains(text, "And cards this game does not have: Zzyx the Unprinted.")


# --------------------------------------------------------- import, card by card --

func test_import_says_each_card_and_counts_unlisted_folders() -> void:
	assert_eq(CommunityCards.save(_spec("Here Already"), {}, _icon()), "")
	CommunityCards.refresh()
	# A set zip by hand: two listed cards (one here already, one new), one
	# listed folder that is no card, one refused card — and two folders
	# set.json does not list.
	var entries: Array = [["set.json", JSON.stringify({"format": CommunityCards.SET_FORMAT, "version": 1,
		"name": "Hand set", "cards": ["new_one", "here_already", "empty_one", "bad_one"]}).to_utf8_buffer()]]
	for pair: Array in [["new_one", _spec("New One")], ["here_already", _spec("Here Already", {"flavor": "Other."})],
			["bad_one", _spec("Bad One", {"power": 500})], ["stray_one", _spec("Stray One")], ["stray_two", _spec("Stray Two")]]:
		entries.append([String(pair[0]) + "/card.json", JSON.stringify(pair[1]).to_utf8_buffer()])
		entries.append([String(pair[0]) + "/icon.png", _png(64, 64)])
	var path := _root.path_join("hand_set.zip")
	_store(path, _packed(entries, "hand_set"))
	var rows := CommunityCards.read_set(path)
	assert_eq(rows.size(), 4, "the listed folders only")
	assert_eq(CommunityCards.set_unlisted(rows), 2)
	var done := CommunityCards.import_file(path)
	assert_eq(done["names"], ["New One"] as Array[String])
	assert_eq(done["here"], ["Here Already"] as Array[String])
	assert_eq((done["problems"] as Array).size(), 2)
	assert_eq((done["notes"] as Array).size(), 1)
	assert_string_contains(String(done["notes"][0]), "2 folders")
	var cards: Array = done["cards"]
	assert_eq(cards.size(), 4, "a result for each listed card, in the set's order")
	assert_eq(cards[0], {"name": "New One", "result": "taken", "problem": "", "differs": ""})
	assert_eq(cards[1], {"name": "Here Already", "result": "here", "problem": "", "differs": "look"})
	assert_eq(cards[2]["result"], "refused")
	assert_string_contains(String(cards[2]["problem"]), "missing")
	assert_eq(cards[3]["result"], "refused")
	assert_ne(String(cards[3]["problem"]), "")
	# A set whose every folder is listed says nothing more.
	var whole := _root.path_join("whole_set.zip")
	assert_eq(CommunityCards.write_set_zip(whole, "Whole", [{"spec": _spec("Whole One"), "art": {}, "icon": _icon()}]), "")
	assert_eq(CommunityCards.set_unlisted(CommunityCards.read_set(whole)), 0)
	assert_eq(CommunityCards.import_file(whole)["notes"], [] as Array[String])
	# One card: the same shape.
	var single := _root.path_join("single.zip")
	assert_eq(CommunityCards.write_zip(single, _spec("Single One"), {}, _icon()), "")
	assert_eq(CommunityCards.import_file(single)["cards"],
		[{"name": "Single One", "result": "taken", "problem": "", "differs": ""}] as Array[Dictionary])
	assert_eq(CommunityCards.import_file(_root.path_join("nothing.txt"))["problems"].size(), 1)


func test_a_file_that_takes_no_neighbour_is_written_in_place() -> void:
	# Where the chosen file takes no `.part` beside it (a phone's document
	# picker), the zip is made aside and written over the file in place.
	var dest := _root.path_join("export_here.zip")
	_store(dest, "the picker made this empty file".to_utf8_buffer())
	DirAccess.make_dir_recursive_absolute(dest + ".part")   # no neighbour can be written
	assert_ne(CommunityCards.write_zip(dest, _spec("Exported"), _art(), _icon()), "", "refused on a desktop, as ever")
	AdventureTransfer.on_android = true
	assert_eq(CommunityCards.write_zip(dest, _spec("Exported"), _art(), _icon()), "")
	var row := CommunityCards.read(dest)
	assert_eq((row["problems"] as Array).size(), 0, str(row["problems"]))
	assert_eq(row["name"], "Exported")
	assert_eq(row["files"]["art"], _art())
	assert_eq(CommunityCards.write_set_zip(dest, "Out set", [{"spec": _spec("Exported"), "art": {}, "icon": _icon()}]), "")
	assert_true(CommunityCards.is_set_zip(dest))
	assert_false(FileAccess.file_exists(_own.path_join(".incoming").path_join("outgoing.zip.part")), "no litter aside")
	# An address is told from a path; a path that is no zip is refused as ever.
	assert_true(AdventureTransfer.is_uri("content://com.android.providers/document/42"))
	assert_string_contains(String(CommunityCards.import_file("content://nowhere/document/42")["problems"][0]), "could not be read")
	assert_string_contains(String(CommunityCards.import_file(_root.path_join("card.txt"))["problems"][0]), "not a .zip file")


# ------------------------------------------------------- sets at a LAN table --

func test_a_card_of_an_own_set_zip_is_replaced_or_set_aside_as_a_single() -> void:
	var digest := "a".repeat(64)
	var in_set := {"digest": "b".repeat(64), "where": "set", "own": [], "stays": "set"}
	# As ever without the set's place: it stays, still different.
	var p := SgCardTransfer.plan([["Set Card", digest, 1000]], "1-x", {"Set Card": in_set.duplicate()})
	assert_eq(p["in_set"], ["Set Card"])
	assert_eq(p["unpack"], [])
	# A set zip of the own folder is unpacked: its card is replaced like any other.
	var mine := in_set.duplicate()
	mine["sets"] = ["/own/a_set.zip"]
	mine["set_else"] = false
	var other := mine.duplicate()
	other["digest"] = "c".repeat(64)
	p = SgCardTransfer.plan([["Set Card", digest, 1000]], "1-x", {"Set Card": mine, "Set Extra": other})
	assert_eq(p["replace"], ["Set Card"])
	assert_eq(p["set_aside"], ["Set Extra"], "its other card the host lacks is set aside")
	assert_eq(p["in_set"], [])
	assert_eq(p["shadowed"], [])
	assert_eq(p["unpack"], ["/own/a_set.zip"])
	assert_string_contains(SgCardTransfer.plan_text(p), "a_set.zip")
	# A copy in a set zip elsewhere still blocks.
	mine["set_else"] = true
	p = SgCardTransfer.plan([["Set Card", digest, 1000]], "1-x", {"Set Card": mine})
	assert_eq(p["in_set"], ["Set Card"])
	assert_eq(p["unpack"], [])
	# An own single that plays is replaced as it is: its set is left alone.
	var single := {"digest": "b".repeat(64), "where": "own", "own": ["/own/set_card.zip"], "stays": "set",
		"sets": ["/own/a_set.zip"], "set_else": false}
	p = SgCardTransfer.plan([["Set Card", digest, 1000]], "1-x", {"Set Card": single})
	assert_eq(p["replace"], ["Set Card"])
	assert_eq(p["shadowed"], ["Set Card"])
	assert_eq(p["unpack"], [])


func test_an_own_set_zip_is_unpacked_into_singles_that_play_the_same() -> void:
	var set_path := _own.path_join("lan_set.zip")
	assert_eq(CommunityCards.write_set_zip(set_path, "Lan set", [
		{"spec": _spec("Lan One"), "art": _art(), "icon": _icon()},
		{"spec": _spec("Lan Two", {"power": 3}), "art": {}, "icon": _icon()}]), "")
	# Lan Two also has a single of its own, which is the copy that plays.
	assert_eq(CommunityCards.save(_spec("Lan Two", {"power": 4}), {}, _icon()), "")
	CommunityCards.refresh()
	var mark := SgCompatibility.community_mark()
	var have := SgCardTransfer.mine()
	assert_eq(have["Lan One"]["where"], "set")
	assert_eq(have["Lan One"]["sets"], [set_path])
	assert_false(bool(have["Lan One"]["set_else"]))
	assert_eq(have["Lan Two"]["where"], "own")
	var p := SgCardTransfer.plan([], "", have)
	assert_eq(p["set_aside"], ["Lan One", "Lan Two"], "both can go once the set is unpacked")
	assert_eq(p["unpack"], [set_path])
	# A path outside the own folder is never unpacked.
	assert_ne(SgCardTransfer._unpack_sets([_root.path_join("beside").path_join("lan_set.zip")]), "")
	assert_ne(String(CommunityCards.unpack_set(_root.path_join("beside").path_join("x.zip"))["problem"]), "")
	assert_eq(SgCardTransfer._unpack_sets([set_path]), "")
	assert_false(FileAccess.file_exists(set_path), "the set zip is moved")
	assert_true(FileAccess.file_exists(CommunityCards.aside_folder().path_join("lan_set.zip")), "to the set-aside folder")
	CommunityCards.refresh()
	assert_eq(SgCompatibility.community_mark(), mark, "the same cards play")
	have = SgCardTransfer.mine()
	assert_eq(have["Lan One"]["where"], "own")
	assert_eq(have["Lan One"]["stays"], "")
	assert_eq(have["Lan Two"]["stays"], "")
	assert_eq(int(CommunityCards.saved_spec("Lan Two")["power"]), 4, "the single that played still does")
	assert_eq(CommunityCards.files_of("Lan One")["art"], _art(), "with its pictures")
	assert_eq(CommunityCards.own_names(), ["Lan One", "Lan Two"] as Array[String])


func test_the_plan_names_the_saved_decks_that_use_the_cards() -> void:
	var decks := _root.path_join("decks")
	SgCardTransfer.decks_folder_override = decks
	_store(decks.path_join("uses_it.deck"), "name: Uses It\n4 Changed Card\n20 Forest\n".to_utf8_buffer())
	_store(decks.path_join("side_only.deck"), "name: Side Only\n20 Forest\nSB: 1 Gone Card\n".to_utf8_buffer())
	_store(decks.path_join("clean.deck"), "name: Clean\n20 Forest\n".to_utf8_buffer())
	var using := SgCardTransfer.decks_using(["Changed Card", "Gone Card"])
	assert_eq(using, ["Side Only", "Uses It"] as Array[String])
	assert_eq(SgCardTransfer.decks_using([]), [] as Array[String])
	var own := {"digest": "b".repeat(64), "where": "own", "own": ["/own/x.zip"], "stays": ""}
	var p := SgCardTransfer.plan([["Changed Card", "a".repeat(64), 1000]], "1-x",
		{"Changed Card": own.duplicate(), "Gone Card": own.duplicate()})
	var text := SgCardTransfer.plan_text(p)
	assert_string_contains(text, "Your saved decks that use these cards: %s." % ", ".join(using))
	# Nothing replaced or set aside: no such line.
	p = SgCardTransfer.plan([["New Card", "a".repeat(64), 1000]], "1-x", {})
	assert_false(SgCardTransfer.plan_text(p).contains("saved decks"))
