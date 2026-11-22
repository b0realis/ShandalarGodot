extends GutTest
## THE COMMUNITY CARDS' FOLDER ([CommunityCards]): a card's zip, data only,
## becomes a card of the Community cards set; a broken, unsafe or second
## copy is refused with its reason; the art and the creator's own set icon
## come from the zip and follow the guidelines; the art is cut to the art
## window by the card's crop; the set's name is in the tooltip; and at a
## LAN table both players need the same community cards.

const ROOT := "user://community_cards_test"

var _root := ""


func before_each() -> void:
	_root = ProjectSettings.globalize_path(ROOT)
	_wipe(_root)
	DirAccess.make_dir_recursive_absolute(_root.path_join("a"))
	DirAccess.make_dir_recursive_absolute(_root.path_join("b"))
	CommunityCards.folders_override = [_root.path_join("a"), _root.path_join("b")]


func after_each() -> void:
	CommunityCards.folders_override = []
	CommunityCards.clear_draft()
	_wipe(_root)
	CommunityCards.refresh()


func _wipe(dir: String) -> void:
	if not dir.contains("community_cards_test") or not DirAccess.dir_exists_absolute(dir):
		return
	var here := DirAccess.open(dir)
	here.include_hidden = true
	for sub in here.get_directories():
		_wipe(dir.path_join(sub))
	for name in here.get_files():
		DirAccess.remove_absolute(dir.path_join(name))
	DirAccess.remove_absolute(dir)


func _spec(name: String, extra := {}) -> Dictionary:
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": name, "cost": "{G}",
		"types": ["creature"], "power": 1, "toughness": 1, "rarity": "uncommon",
		"artist": "A. Painter", "set_name": "Test set",
		"look": {"border": "white", "frame": "gold"}, "abilities": []}
	spec.merge(extra, true)
	return spec


func _picture(w: int, h: int, kind := "png") -> Dictionary:
	var image := Image.create(w, h, false, Image.FORMAT_RGBA8)
	image.fill(Color(0.2, 0.6, 0.3))
	return {"bytes": image.save_png_to_buffer() if kind == "png" else image.save_webp_to_buffer(), "kind": kind}


## A zip made by hand (one card's top folder), past the writer's checks.
func _raw_zip(path: String, entries: Array) -> void:
	var zip := ZIPPacker.new()
	zip.open(path)
	for entry in entries:
		zip.start_file("raw/" + String(entry[0]))
		zip.write_file(entry[1])
		zip.close_file()
	zip.close()


func _art() -> Dictionary:
	return _picture(510, 396)


func _icon() -> Dictionary:
	return _picture(64, 64)


func test_a_card_zip_becomes_a_card_of_the_community_set() -> void:
	assert_eq(CommunityCards.write_zip(_root.path_join("a/moss.zip"), _spec("Moss Sprite"), _art(), _icon()), "")
	CommunityCards.refresh()
	assert_true(CardRegistry.has_card("Moss Sprite"))
	assert_eq(CardRegistry.get_card("Moss Sprite").set_code, CommunityCard.SET_CODE)
	assert_true(CardRegistry.extra_set_order().has(CommunityCard.SET_CODE))
	assert_eq(CardRegistry.names_in_set(CommunityCard.SET_CODE), ["Moss Sprite"] as Array[String])
	assert_true(CardRegistry.card_in_set("Moss Sprite", CommunityCard.SET_CODE))
	assert_eq(CardRegistry.rarity_of("Moss Sprite", CommunityCard.SET_CODE), "uncommon")
	assert_eq(CardRegistry.get_card("Moss Sprite").artist, "A. Painter")
	var art := CardPacks.art_texture("Moss Sprite", CommunityCard.SET_CODE)
	assert_not_null(art, "the art comes from the zip")
	assert_almost_eq(art.get_width() / float(art.get_height()), CommunityCards.ART_ASPECT, 0.01,
		"cut to the art window's shape")
	var icon := CommunityCards.icon_texture("Moss Sprite")
	assert_not_null(icon, "the creator's own set icon")
	assert_eq([icon.get_width(), icon.get_height()], [64, 64])
	assert_eq(MiniCard.frame_skin_key(CardRegistry.get_card("Moss Sprite")), "card_frame_gold")
	assert_eq(CommunityCards.border_color("Moss Sprite"), Color8(236, 232, 222))
	assert_eq(CommunityCards.tooltip_extra(CardRegistry.get_card("Moss Sprite")),
		"\nSet: Test set (community card)", "the set's name, in the tooltip only")
	assert_eq(CommunityCards.tooltip_extra(CardRegistry.get_card("Grizzly Bears")), "")


func test_broken_unsafe_and_second_copies_are_refused_with_their_reason() -> void:
	CommunityCards.write_zip(_root.path_join("a/one.zip"), _spec("Twin Moth"), _art(), _icon())
	CommunityCards.write_zip(_root.path_join("b/two.zip"), _spec("Twin Moth"), _art(), _icon())
	var bad := ZIPPacker.new()
	bad.open(_root.path_join("a/code.zip"))
	for entry in [["evil/card.json", JSON.stringify(_spec("Evil Card"))], ["evil/run.gd", "extends Node"]]:
		bad.start_file(entry[0])
		bad.write_file(String(entry[1]).to_utf8_buffer())
		bad.close_file()
	bad.close()
	var broken := ZIPPacker.new()
	broken.open(_root.path_join("a/broken.zip"))
	broken.start_file("broken/card.json")
	broken.write_file(JSON.stringify(_spec("Broken Card", {"cost": "{Q}"})).to_utf8_buffer())
	broken.close_file()
	broken.close()
	_raw_zip(_root.path_join("a/no_icon.zip"), [["card.json", JSON.stringify(_spec("Iconless")).to_utf8_buffer()],
		["art.png", _art()["bytes"]]])
	CommunityCards.refresh()
	var rows := {}
	for row in CommunityCards.all():
		rows[String(row["path"]).get_file()] = row
	assert_eq(rows["one.zip"]["problems"], [] as Array[String])
	assert_string_contains(String(rows["two.zip"]["problems"][0]), "was found first")
	assert_string_contains(" ".join(rows["code.zip"]["problems"]), "run.gd")
	assert_string_contains(" ".join(rows["broken.zip"]["problems"]), "mana cost")
	assert_string_contains(" ".join(rows["no_icon.zip"]["problems"]), "set icon is missing")
	assert_eq(CardRegistry.names_in_set(CommunityCard.SET_CODE), ["Twin Moth"] as Array[String])
	assert_false(CardRegistry.has_card("Evil Card"), "nothing of a refused zip is played")


func test_the_pictures_follow_the_guidelines() -> void:
	assert_eq(CommunityCards.art_problem(_art()["bytes"], "png"), "")
	assert_eq(CommunityCards.art_problem(_picture(765, 594)["bytes"], "png"), "", "the ideal size")
	assert_string_contains(CommunityCards.art_problem(_picture(100, 80)["bytes"], "png"), "pixels")
	assert_string_contains(CommunityCards.art_problem(_picture(2400, 1800)["bytes"], "png"), "pixels",
		"no ultra-large picture")
	assert_string_contains(CommunityCards.art_problem(_picture(900, 300)["bytes"], "png"), "9:7")
	assert_string_contains(CommunityCards.art_problem(PackedByteArray([1, 2, 3]), "png"), "could not be read")
	assert_string_contains(CommunityCards.art_problem(_art()["bytes"], "gif"), "PNG, JPG or WEBP")
	assert_eq(CommunityCards.icon_problem(_icon()["bytes"], "png"), "")
	assert_eq(CommunityCards.icon_problem(_picture(32, 32, "webp")["bytes"], "webp"), "")
	assert_string_contains(CommunityCards.icon_problem(_picture(512, 512)["bytes"], "png"), "32 to 128",
		"a set icon is small")
	assert_string_contains(CommunityCards.icon_problem(_picture(96, 48)["bytes"], "png"), "square")
	assert_string_contains(CommunityCards.icon_problem(_icon()["bytes"], "jpg"), "PNG or WEBP")
	assert_string_contains(CommunityCards.write_zip(_root.path_join("a/huge.zip"), _spec("Huge Icon"), _art(),
		_picture(512, 512)), "32 to 128", "never written off the guidelines")
	_raw_zip(_root.path_join("a/huge.zip"), [["card.json", JSON.stringify(_spec("Huge Icon")).to_utf8_buffer()],
		["icon.png", _picture(512, 512)["bytes"]]])
	CommunityCards.refresh()
	assert_false(CardRegistry.has_card("Huge Icon"), "a zip with a picture off the guidelines is refused")
	var refused := CommunityCards.all().filter(func(row: Dictionary) -> bool:
		return String(row["path"]).ends_with("huge.zip"))
	assert_string_contains(" ".join(refused[0]["problems"]), "32 to 128")


func test_the_crop_cuts_the_art_window_and_moves_and_zooms() -> void:
	var wide := CommunityCards.crop_region(Vector2(1000, 400), 1.0, 0.5, 0.5)
	assert_almost_eq(wide.size.x / wide.size.y, CommunityCards.ART_ASPECT, 0.001)
	assert_eq(wide.size.y, 400.0, "the whole height of a wide picture")
	assert_almost_eq(wide.position.x, (1000 - wide.size.x) / 2.0, 0.01, "centred")
	var left := CommunityCards.crop_region(Vector2(1000, 400), 1.0, 0.0, 0.5)
	assert_eq(left.position.x, 0.0)
	var zoomed := CommunityCards.crop_region(Vector2(510, 396), 2.0, 1.0, 1.0)
	assert_almost_eq(zoomed.size.x, 255.0, 0.5, "twice as close")
	assert_almost_eq(zoomed.end.x, 510.0, 0.5, "to the right edge")
	assert_almost_eq(zoomed.end.y, 396.0, 0.5, "to the bottom edge")
	assert_false(CommunityCard.problems(_spec("Bad Crop", {"look": {"art": {"zoom": 5.0, "x": 2.0}}})).is_empty())


func test_a_name_the_game_already_has_is_left_out() -> void:
	CommunityCards.write_zip(_root.path_join("a/bolt.zip"), _spec("Lightning Bolt"), _art(), _icon(), true)
	CommunityCards.refresh()
	assert_eq(CardRegistry.community_skipped(), ["Lightning Bolt"] as Array[String])
	assert_eq(CardRegistry.get_card("Lightning Bolt").set_code, "2ed", "the game's own card stays")


func test_save_and_delete_stay_in_the_own_folder() -> void:
	CommunityCards.folders_override = [CommunityCards.ensure_own_folder()]
	assert_eq(CommunityCards.save(_spec("Own Card"), _art(), _icon()), "")
	CommunityCards.refresh()
	assert_eq(CommunityCards.own_names(), ["Own Card"] as Array[String])
	assert_eq(CommunityCards.files_of("Own Card")["icon"]["kind"], "png")
	assert_true(CommunityCards.delete_own("Own Card"))
	assert_false(CommunityCards.delete_own("Own Card"), "nothing left to delete")
	CommunityCards.refresh()
	assert_false(CardRegistry.has_card("Own Card"))
	assert_eq(CommunityCards.file_name("Ash's Hound, Jr."), "ash_s_hound_jr")


# ------------------------------------------------------ at a LAN table --

func test_at_a_lan_table_both_players_need_the_same_community_cards() -> void:
	var none := SgCompatibility.stamp()
	assert_false(none.has("community"), "a game without them sends the stamp it always did")
	CommunityCards.write_zip(_root.path_join("a/moss.zip"), _spec("Moss Sprite"), _art(), _icon())
	CommunityCards.refresh()
	var mine := SgCompatibility.stamp()
	assert_true(SgCompatibility.valid_stamp(mine))
	assert_string_contains(String(mine["community"]), "1-")
	var why := SgCompatibility.difference(mine, none)
	assert_true(why.begins_with(SgCompatibility.COMMUNITY_WORDS), why)
	assert_string_contains(why, "The host has no community cards; you have 1 community card")
	assert_eq(SgCompatibility.brief(mine, none), "Community cards")
	var other := none.duplicate()
	other["community"] = "1-000000000000"
	assert_string_contains(SgCompatibility.difference(mine, other), "as you do, but not the same ones")
	assert_eq(SgCompatibility.difference(mine, mine), "")
	var odd := mine.duplicate()
	odd["community"] = "one card!"
	assert_false(SgCompatibility.valid_stamp(odd))
	var deck := {"name": "Moss", "cards": ["Moss Sprite", "Forest", "Moss Sprite"], "sideboard": []}
	assert_eq(SgDeckCatalog.community_cards(deck), ["Moss Sprite"] as Array[String])
	assert_true(SgDeckCatalog.community_cards({"name": "Plain", "cards": ["Forest"], "sideboard": []}).is_empty())
	var room := {"id": "r1", "name": "Table", "seat": 0, "names": ["One", "Two"], "revision": 1,
		"ready": [true, false], "connected": [true, true], "game": {}, "deck_names": ["Moss", "Forest practice"],
		"deck": {}, "community": [true, false]}
	assert_true(SgViewProtocol.room(room), "the seats' community marks travel in the room view")
	room["community"] = ["yes", false]
	assert_false(SgViewProtocol.room(room))
	var tag := SgLobbyStyle.community_tag()
	assert_eq((tag.get_child(0) as Label).text, "community")
	tag.free()


# ------------------------------------------- the bug pass (2026-11-17) --

func test_one_broken_zip_never_drops_the_others() -> void:
	_raw_zip(_root.path_join("a/aaa.zip"), [["card.json", JSON.stringify(_spec("Odd", {"name": 5})).to_utf8_buffer()],
		["icon.png", _icon()["bytes"]]])
	_raw_zip(_root.path_join("a/bbb.zip"), [["card.json", JSON.stringify(_spec("Nulled", {"flavor": null})).to_utf8_buffer()],
		["icon.png", _icon()["bytes"]]])
	CommunityCards.write_zip(_root.path_join("a/zzz.zip"), _spec("Last Moss"), _art(), _icon())
	CommunityCards.refresh()
	assert_true(CardRegistry.has_card("Last Moss"), "the good card is in")
	var refused := CommunityCards.all().filter(func(row: Dictionary) -> bool:
		return not (row["problems"] as Array).is_empty())
	assert_eq(refused.size(), 2, "both broken zips are refused with their reasons")
	assert_string_contains(" ".join(refused[0]["problems"]), "name must be text")


func test_saving_goes_over_the_card_s_own_zip_and_never_over_another_card() -> void:
	CommunityCards.folders_override = [CommunityCards.ensure_own_folder()]
	var own := CommunityCards.ensure_own_folder()
	CommunityCards.write_zip(own.path_join("cool.zip"), _spec("Fire Moss"), _art(), _icon())
	CommunityCards.refresh()
	assert_eq(CommunityCards.save(_spec("Fire Moss", {"power": 5}), _art(), _icon()), "")
	CommunityCards.refresh()
	assert_eq(CardRegistry.get_card("Fire Moss").power, 5, "saved over cool.zip")
	assert_false(FileAccess.file_exists(own.path_join("fire_moss.zip")), "no second copy")
	assert_true(CommunityCards.delete_own("Fire Moss"))
	assert_false(FileAccess.file_exists(own.path_join("cool.zip")), "its own zip deleted")
	assert_eq(CommunityCards.save(_spec("Elf-Lord"), _art(), _icon()), "")
	CommunityCards.refresh()
	assert_eq(CommunityCards.save(_spec("Elf Lord"), _art(), _icon()), "")
	CommunityCards.refresh()
	assert_true(CardRegistry.has_card("Elf-Lord") and CardRegistry.has_card("Elf Lord"), "both kept")
	assert_true(FileAccess.file_exists(own.path_join("elf_lord_2.zip")))
	CommunityCards.delete_own("Elf-Lord")
	CommunityCards.delete_own("Elf Lord")


func test_names_are_told_apart_in_any_case() -> void:
	CommunityCards.write_zip(_root.path_join("a/one.zip"), _spec("Elf Lord"), _art(), _icon())
	CommunityCards.write_zip(_root.path_join("b/two.zip"), _spec("ELF LORD"), _art(), _icon())
	CommunityCards.write_zip(_root.path_join("a/bolt.zip"), _spec("lightning bolt"), _art(), _icon(), true)
	CommunityCards.refresh()
	assert_true(CardRegistry.has_card("Elf Lord"))
	assert_false(CardRegistry.has_card("ELF LORD"), "the second spelling is refused")
	assert_false(CardRegistry.has_card("lightning bolt"), "a game card's name in any case stays the game's")
	assert_eq(CardRegistry.game_name_like("LIGHTNING BOLT"), "Lightning Bolt")
	assert_eq(CardRegistry.game_name_like("Elf Lord"), "", "a community card is not a game card")


func test_no_card_passes_for_one_of_the_game_s_however_it_is_spelled() -> void:
	# Accents written plain, other spacing, other signs: the game's card.
	for pair in [["Dandan", "Dandân"], ["serra-angel", "Serra Angel"],
			["SerraAngel", "Serra Angel"], ["Will o the Wisp", "Will-o'-the-Wisp"], ["Lightning, Bolt", "Lightning Bolt"]]:
		if not CardRegistry.has_card(String(pair[1])):
			continue
		assert_eq(CardRegistry.game_name_like(String(pair[0])), String(pair[1]))
		assert_eq(CommunityCards.game_card_like(String(pair[0])), String(pair[1]))
		# Its file is never written by the game...
		var path := _root.path_join("a/like.zip")
		assert_eq(CommunityCards.write_zip(path, _spec(String(pair[0])), _art(), _icon()),
			"A card named %s is already in the game." % String(pair[1]))
		assert_false(FileAccess.file_exists(path))
		# ...and one made elsewhere is left out of the pool.
		CommunityCards.write_zip(path, _spec(String(pair[0])), _art(), _icon(), true)
		CommunityCards.refresh()
		assert_false(CardRegistry.has_community(String(pair[0])), String(pair[0]))
		assert_true(CardRegistry.community_skipped().has(String(pair[0])))
		DirAccess.remove_absolute(path)
	CommunityCards.refresh()
	# The game's card is the object it was, with its own cost.
	var bolt := CardRegistry.get_card("Lightning Bolt")
	assert_eq([bolt.card_name, bolt.cost.text], ["Lightning Bolt", "{R}"])
	assert_eq(CardRegistry.game_name_like("Serra Angle"), "", "another name is another card")


func test_a_zip_named_like_a_game_card_tags_nothing() -> void:
	CommunityCards.write_zip(_root.path_join("a/bears.zip"), _spec("Grizzly Bears"), _art(), _icon(), true)
	CommunityCards.refresh()
	assert_false(CommunityCards.is_community("Grizzly Bears"))
	assert_false(CardRegistry.extra_set_order().has(CommunityCard.SET_CODE), "no empty Community row")
	assert_true(SgDeckCatalog.community_cards({"name": "Bears", "cards": ["Grizzly Bears"], "sideboard": []}).is_empty())


func test_picture_sizes_are_read_from_their_headers() -> void:
	var image := Image.create(300, 230, false, Image.FORMAT_RGB8)
	image.fill(Color(0.4, 0.5, 0.6))
	assert_eq(CommunityCards.picture_size(image.save_png_to_buffer(), "png"), Vector2i(300, 230))
	assert_eq(CommunityCards.picture_size(image.save_jpg_to_buffer(), "jpg"), Vector2i(300, 230))
	assert_eq(CommunityCards.picture_size(image.save_webp_to_buffer(false), "webp"), Vector2i(300, 230))
	assert_eq(CommunityCards.picture_size(image.save_webp_to_buffer(true), "webp"), Vector2i(300, 230))
	assert_eq(CommunityCards.picture_size(PackedByteArray([1, 2, 3]), "png"), Vector2i(-1, -1))


func test_a_texture_is_kept_while_its_zip_stays_the_same() -> void:
	CommunityCards.write_zip(_root.path_join("a/moss.zip"), _spec("Kept Moss"), _art(), _icon())
	CommunityCards.refresh()
	var art := CommunityCards.art_texture("Kept Moss")
	CommunityCards.refresh()
	assert_same(CommunityCards.art_texture("Kept Moss"), art, "not decoded again")


func test_the_lan_mark_tells_cards_apart_by_what_plays() -> void:
	CommunityCards.write_zip(_root.path_join("a/chief.zip"), _spec("Moss Chief", {"subtypes": ["goblin"]}), _art(), _icon())
	CommunityCards.refresh()
	var goblin := SgCompatibility.community_mark()
	var print_goblin := SgCompatibility.fingerprint()
	CommunityCards.write_zip(_root.path_join("a/chief.zip"), _spec("Moss Chief", {"subtypes": ["elf"]}), _art(), _icon())
	CommunityCards.refresh()
	assert_ne(SgCompatibility.community_mark(), goblin, "a subtype is another card")
	assert_ne(SgCompatibility.fingerprint(), print_goblin, "and another catalogue")
	var elf := SgCompatibility.community_mark()
	CommunityCards.write_zip(_root.path_join("a/chief.zip"), _spec("Moss Chief", {"subtypes": ["elf"],
		"flavor": "Another flavor.", "artist": "Someone else"}), _art(), _icon())
	CommunityCards.refresh()
	assert_eq(SgCompatibility.community_mark(), elf, "flavor and artist do not play")


func test_a_set_zip_plays_each_of_its_cards_and_a_card_saved_alone_wins() -> void:
	var cards := [{"spec": _spec("Set Elf"), "art": _art(), "icon": _icon()},
		{"spec": _spec("Set Bear", {"power": 2, "toughness": 2}), "art": {}, "icon": _icon()}]
	var path := _root.path_join("a/test_set.zip")
	assert_eq(CommunityCards.write_set_zip(path, "Test set", cards), "")
	assert_true(CommunityCards.is_set_zip(path))
	assert_false(CommunityCards.is_set_zip(_root.path_join("a/none.zip")))
	CommunityCards.refresh()
	assert_true(CardRegistry.has_card("Set Elf") and CardRegistry.has_card("Set Bear"), "each card of the set plays")
	assert_eq(CommunityCards.own_path_of("Set Elf"), "", "a card of a set is never saved over alone")
	assert_not_null(CommunityCards.art_texture("Set Elf"), "its art from its own folder of the zip")
	var bytes := CommunityCards.zip_bytes_of("Set Bear")
	assert_false(bytes.is_empty(), "one card of a set, packed alone to share")
	var alone := FileAccess.open(_root.path_join("a/zz_bear.zip"), FileAccess.WRITE)
	alone.store_buffer(bytes)
	alone.close()
	CommunityCards.refresh()
	var plays := CommunityCards.playable().filter(func(r: Dictionary) -> bool: return r["name"] == "Set Bear")
	assert_eq(plays.size(), 1)
	assert_true(String(plays[0]["path"]).ends_with("zz_bear.zip"), "the card saved alone plays, though named later")
	var shadowed := CommunityCards.all().filter(func(r: Dictionary) -> bool:
		return r["name"] == "Set Bear" and not (r["problems"] as Array).is_empty())
	assert_eq(shadowed.size(), 1, "the set's own copy is found second")
	assert_eq(CommunityCards.write_set_zip(_root.path_join("b/none.zip"), "Test set", []), "The set has no card.")
	assert_string_contains(CommunityCards.write_set_zip(_root.path_join("b/none.zip"), "Test set",
		[{"spec": _spec("No Icon"), "art": {}, "icon": {}}]), "no set icon")
	_raw_zip(_root.path_join("a/bad_set.zip"), [["set.json", "{\"format\": \"nope\"}".to_utf8_buffer()]])
	CommunityCards.refresh()
	var bad := CommunityCards.all().filter(func(r: Dictionary) -> bool: return String(r["path"]).ends_with("bad_set.zip"))
	assert_eq(bad.size(), 1)
	assert_false((bad[0]["problems"] as Array).is_empty(), "a set.json that is not a set refuses the zip")


func test_the_example_card_ships_whole() -> void:
	var rows := CommunityCards.examples()
	assert_eq(rows.size(), 1, "the Battle Apothecary Cart")
	var spec: Dictionary = rows[0]["spec"]
	assert_eq(String(spec["name"]), "Battle Apothecary Cart")
	assert_eq(String(spec["artist"]), "Caduceus")
	assert_eq(String(spec["flavor"]), "Even the bravest need help sometimes.")
	var data := CommunityCard.build(spec)
	assert_true(data.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(data.cost.mana_value(), 2)
	assert_eq(data.oracle_text, "{T}: Prevent the next 1 damage that would be dealt to target creature this turn.")
	assert_eq(CommunityCards.art_problem(rows[0]["files"]["art"]["bytes"], "jpg"), "", "the art by the guidelines")
	assert_eq(CommunityCards.icons_problem(rows[0]["files"]["icon"]), "")
	assert_eq(CommunityCards.icon_tiers(rows[0]["files"]["icon"]).keys(), CommunityCards.ICON_TIERS as Array,
		"its wheel colored for each rarity")
	assert_false(CardRegistry.has_card("Battle Apothecary Cart"), "an example is not in the pool until saved")


# ------------------------------------------------------------ four icons --

func _icon_of(color: Color) -> Dictionary:
	var picture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	picture.fill(color)
	return {"bytes": picture.save_png_to_buffer(), "kind": "png"}


func test_one_icon_is_every_rarity_s_and_four_set_rarities_apart() -> void:
	var red := _icon_of(Color.RED)
	var blue := _icon_of(Color.BLUE)
	var gold := _icon_of(Color.GOLD)
	assert_eq(CommunityCards.icon_for_tier(red, "rare"), red, "one icon: every rarity")
	var two := {"uncommon": blue, "legendary": gold}
	assert_eq(CommunityCards.icon_for_tier(two, "common"), blue, "no own: the first given")
	assert_eq(CommunityCards.icon_for_tier(two, "rare"), blue)
	assert_eq(CommunityCards.icon_for_tier(two, "legendary"), gold)
	assert_eq(CommunityCards.icon_for_tier(two, "mythic"), gold, "a mythic wears the legendary one")
	assert_eq(CommunityCards.icon_pack({"rare": red}), red, "one given is kept as one")
	assert_eq(CommunityCards.icon_entries({"rare": red}).map(func(e: Array) -> String: return String(e[0])),
		["icon.png"], "and written as every card was")
	assert_eq(CommunityCards.icon_entries(two).map(func(e: Array) -> String: return String(e[0])),
		["icon_uncommon.png", "icon_legendary.png"])
	assert_true(CommunityCards.is_icon_file("icon_rare.webp"))
	assert_false(CommunityCards.is_icon_file("icon_mythic.png"), "the tiers are the set symbol's")


func test_a_card_of_four_icons_is_written_and_read_whole() -> void:
	var dir := "user://four_icons_test"
	DirAccess.make_dir_recursive_absolute(dir)
	var path := dir.path_join("four.zip")
	var spec := {"format": CommunityCard.FORMAT, "version": 1, "name": "Zyx Four Icons", "cost": "{1}{G}",
		"types": ["creature"], "power": 2, "toughness": 2, "rarity": "rare", "abilities": []}
	var icons := {"common": _icon_of(Color.WHITE), "uncommon": _icon_of(Color.SILVER),
		"rare": _icon_of(Color.GOLD), "legendary": _icon_of(Color.PURPLE)}
	assert_eq(CommunityCards.write_zip(path, spec, {}, icons), "")
	var listed := PluginPackage.zip_entries(path)
	var names: Array = (listed["entries"] as Array).map(func(e: Dictionary) -> String:
		return String(e["name"]).get_file())
	for tier in CommunityCards.ICON_TIERS:
		assert_true(names.has("icon_%s.png" % tier), tier)
	var row := CommunityCards.read(path)
	assert_eq(row["problems"], [] as Array[String])
	assert_eq(CommunityCards.icon_tiers(row["files"]["icon"]).size(), 4)
	assert_eq(CommunityCards.icon_for_tier(row["files"]["icon"], "uncommon"), icons["uncommon"])
	assert_eq(CommunityCards.write_zip(path, spec, {}, {}), "Choose the set icon first.")
	DirAccess.remove_absolute(path)
	DirAccess.remove_absolute(dir)


## A set icon drawn white with a black outline: a white disc in a black ring.
func _outline_icon() -> Dictionary:
	var picture := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	picture.fill(Color(0, 0, 0, 0))
	for y in 64:
		for x in 64:
			var d := Vector2(x - 31.5, y - 31.5).length()
			if d <= 22.0:
				picture.set_pixel(x, y, Color.WHITE)
			elif d <= 27.0:
				picture.set_pixel(x, y, Color.BLACK)
	return {"bytes": picture.save_png_to_buffer(), "kind": "png"}


func test_a_black_and_white_icon_is_colored_for_each_rarity() -> void:
	var drawn := _outline_icon()
	assert_true(CommunityCards.is_outline_picture(drawn["bytes"], "png"))
	assert_false(CommunityCards.is_outline_picture(_icon_of(Color(0.8, 0.2, 0.1))["bytes"], "png"),
		"a picture in color is used as it is")
	assert_false(CommunityCards.is_outline_picture(_icon_of(Color.BLACK)["bytes"], "png"),
		"all black has no white to color")
	var made := CommunityCards.rarity_icons(drawn["bytes"], "png")
	assert_eq(made.keys(), CommunityCards.ICON_TIERS as Array)
	var middle := {}
	for tier in made:
		assert_eq(CommunityCards.icon_problem(made[tier]["bytes"], "png"), "", tier + " follows the guidelines")
		var image := CommunityCards.image_from(made[tier]["bytes"], "png")
		middle[tier] = image.get_pixel(32, 20)
		assert_lt(image.get_pixel(32, 7).get_luminance(), 0.2, tier + ": the outline stays dark")
		assert_eq(image.get_pixel(0, 0).a, 0.0, "the ground stays clear")
	assert_gt(middle["common"].get_luminance(), 0.9, "common: white")
	assert_gt(middle["rare"].r, middle["rare"].b + 0.3, "rare: gold")
	assert_gt(middle["legendary"].b, middle["legendary"].g + 0.2, "legendary: purple")
	assert_gt(middle["uncommon"].b, middle["uncommon"].r, "uncommon: a cool silver")

