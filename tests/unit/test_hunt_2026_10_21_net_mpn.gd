extends GameTest
## THE MPN READER, HUNTED (second bug hunt, 2026-10-21) — the game history
## that arrived in 804a991 the same day, read against its own specification
## (docs/mpn-specification.md) with crafted files.
##
## - A file from another writer that sends the optional `token` field as a
##   number, a string or an object passed the parser and then stopped the
##   graphical player with a script error at every observation holding it
##   (`1 == true` raises in GDScript rather than answering false): Watch
##   duel showed a half-built table.
## - Invalid UTF-8 was decoded with replacement characters and shown, where
##   the specification says "Invalid UTF-8 is an error" (§2) and "decode
##   UTF-8 strictly" (§9): a damaged recording opened as if it were whole.

func _example_bytes() -> PackedByteArray:
	return FileAccess.get_file_as_bytes("res://docs/mpn-examples/finished-game.mpn")


func _row(token: Variant) -> Dictionary:
	return {"id": "o2", "name": "Uncatalogued token", "zone": "battlefield", "owner": 0, "controller": 0,
		"power": 1, "toughness": 1, "damage": 0, "tapped": false, "face_down": false, "creature": true,
		"counters": {}, "token": token}


func test_a_token_field_of_any_type_never_breaks_the_graphical_table() -> void:
	var parsed := MpnCodec.parse(_example_bytes().get_string_from_utf8())
	for token: Variant in [1, 0, "yes", {"x": 1}, [true], null, 2.5, true, false]:
		var state := MpnCodec.state_at(parsed.records, 0)
		state.objects.o2 = _row(token)
		var projection := MpnProjection.new()
		projection.ingest(state, parsed.headers)
		var card := projection.find_instance(projection.local_id("o2"))
		assert_not_null(card, "the row is on the table: %s" % str(token))
		if card == null: continue
		assert_eq(card.is_token, token is bool and token, "only a boolean true is a token: %s" % str(token))
		assert_true(projection.players[0].battlefield.has(card))


func test_invalid_utf8_is_refused_everywhere_a_record_is_read() -> void:
	var bytes := _example_bytes()
	assert_eq(MpnCodec.parse_bytes(bytes).error, "", "the example itself is valid")
	var at := bytes.get_string_from_utf8().find("Red Wizard")
	var broken := bytes.duplicate()
	broken[bytes.get_string_from_utf8().substr(0, at).to_utf8_buffer().size()] = 0x80   # a lone continuation byte
	assert_ne(MpnCodec.parse_bytes(broken).error, "")
	var folder := "user://mpn-hunt-" + MpnArchive.new_id()
	DirAccess.make_dir_recursive_absolute(folder)
	var path := folder.path_join("broken.mpn")
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer(broken)
	file.close()
	assert_ne(MpnArchive.read(path).error, "", "the archive reader refuses it")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(folder)
	# The LAN download assembles bytes, then validates them the same way.
	var download := MpnDownload.new()
	var failures: Array = []
	download.failed.connect(func(message: String) -> void: failures.append(message))
	download.start("r1", "")
	assert_false(download.next(0).is_empty())
	download.receive({"type": "mpn", "record": "abc", "offset": 0, "total": broken.size(),
		"data": Marshalls.raw_to_base64(broken), "error": ""})
	assert_eq(failures.size(), 1)
	assert_false(download.active)


func test_a_byte_order_mark_is_passed_over_as_before() -> void:
	var bytes := _example_bytes()
	var marked := PackedByteArray([0xEF, 0xBB, 0xBF])
	marked.append_array(bytes)
	var parsed := MpnCodec.parse_bytes(marked)
	assert_eq(parsed.error, "")
	assert_eq(parsed.records, MpnCodec.parse_bytes(bytes).records)


func test_valid_multibyte_text_still_reads() -> void:
	var text := _example_bytes().get_string_from_utf8().replace("Red Wizard", "Éowyn — 🐉 �")
	var parsed := MpnCodec.parse_bytes(text.to_utf8_buffer())
	assert_eq(parsed.error, "")
	assert_eq(parsed.headers["Player.P1"], "Éowyn — 🐉 �", "a literal U+FFFD in the file is text, not damage")
