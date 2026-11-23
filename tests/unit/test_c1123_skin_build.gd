extends GutTest
## THE SKIN BUILT IN THE GAME FROM A 1997 INSTALL (builders 2026-11-23):
## the walk of the player's folders ([SkinSourceIndex]), the check before
## a build ([SkinInstallCheck]) and the build itself ([SkinBuildJob]), on
## a small made-up install laid out by the test ([C1123SkinFixtures]) —
## never on a real copy of the game. What these hold:
##
##   1. A file is found whatever its case, the first folder named wins,
##      and inside a folder the shallowest file.
##   2. The check says what a folder is, and counts what it would give.
##   3. A build gives the zip the Python tool gives: the names, the pixels
##      of each kind of picture, the lists, the sounds byte for byte —
##      every entry under `skin/`, so the game takes it ([method
##      SkinPack.inspect]).
##   4. A file that will not decode is left out, named, and the build goes
##      on; a later remake's file under a 1997 name is not taken.
##   5. A build stopped, or one that cannot write, leaves no file.

const F := preload("res://tests/support/c1123_skin_fixtures.gd")
const SCRATCH := "user://test_c1123_skin_build"

var root := ""
var install := ""
var zip := ""


func before_each() -> void:
	root = ProjectSettings.globalize_path(SCRATCH)
	F.remove_tree(root)
	install = root.path_join("MagicTG")
	zip = root.path_join("out/original_skin.zip")


func after_each() -> void:
	F.remove_tree(root)


## The zip's files by name (the packer's own folder entries left out).
func _entries(path: String) -> Dictionary:
	var out := F.read_zip(path)
	for name: String in out.keys():
		if name.ends_with("/"):
			out.erase(name)
	return out


# ------------------------------------------------------------ 1. the walk --

func test_a_file_is_found_whatever_its_case_and_by_its_folder() -> void:
	F.write_file(install.path_join("Duelsounds/Button.wav"), F.bytes([1]))
	F.write_file(install.path_join("autoplay/Button.wav"), F.bytes([2]))
	F.write_file(install.path_join("Title.PIC"), F.bytes([3]))
	var index := SkinSourceIndex.of([install])
	assert_true(index.done)
	assert_eq(index.file_count, 3)
	assert_eq(index.find("title.pic"), install.path_join("Title.PIC"))
	assert_eq(index.find("TITLE.pic"), install.path_join("Title.PIC"))
	assert_eq(index.find("DuelSounds/BUTTON.WAV"), install.path_join("Duelsounds/Button.wav"))
	assert_eq(index.find("autoplay/button.wav"), install.path_join("autoplay/Button.wav"))
	assert_eq(index.find("button.wav"), install.path_join("autoplay/Button.wav"),
		"of two of one depth, the first by its lower-case path — why a recipe names the folder")
	assert_eq(index.find("nothing.pic"), "")
	assert_eq(index.first_of(["no.pic", "Title.pic"]), install.path_join("Title.PIC"))
	assert_true(index.has_name("duelsounds") and index.has_name("TITLE.PIC"))
	assert_false(index.has_name("sound"))


func test_the_shallowest_file_wins_inside_a_folder() -> void:
	F.write_file(install.path_join("a/deep/Sound/Tune.wav"), F.bytes([1]))
	F.write_file(install.path_join("z/Sound/Tune.wav"), F.bytes([2]))
	F.write_file(install.path_join("Program/Sound/Tune.wav"), F.bytes([3]))
	var index := SkinSourceIndex.of([install])
	assert_eq(index.find("sound/tune.wav"), install.path_join("Program/Sound/Tune.wav"),
		"depth first, then the path")
	assert_eq(index.find("deep/sound/tune.wav"), install.path_join("a/deep/Sound/Tune.wav"))


func test_the_first_folder_named_wins() -> void:
	var cd := root.path_join("CD")
	F.write_file(install.path_join("Title.pic"), F.bytes([1]))
	F.write_file(cd.path_join("deep/Title.pic"), F.bytes([2]))
	F.write_file(cd.path_join("Only.pic"), F.bytes([3]))
	assert_eq(SkinSourceIndex.of([install, cd]).find("title.pic"), install.path_join("Title.pic"))
	assert_eq(SkinSourceIndex.of([cd, install]).find("title.pic"), cd.path_join("deep/Title.pic"))
	var both := SkinSourceIndex.of([install, cd, root.path_join("nowhere")])
	assert_eq(both.find("only.pic"), cd.path_join("Only.pic"))
	assert_eq(both.sources, [install, cd] as Array[String])
	assert_eq(both.not_folders, [root.path_join("nowhere")] as Array[String])
	assert_true(both.has_name("only.pic", cd) and not both.has_name("only.pic", install))


func test_the_walk_is_paced_bounded_and_can_be_stopped() -> void:
	for i in 30:
		F.write_file(install.path_join("d%d/f%d.pic" % [i % 5, i]), F.bytes([i]))
	var paced := SkinSourceIndex.new()
	paced.begin([install])
	var steps := 0
	while paced.step(0):
		steps += 1
	assert_gt(steps, 3, "a folder a step")
	assert_eq(paced.file_count, 30)
	var bounded := SkinSourceIndex.new()
	bounded.max_files = 7
	bounded.begin([install])
	bounded.step()
	assert_eq(bounded.file_count, 7)
	assert_true(bounded.cut_short)
	var shallow := SkinSourceIndex.new()
	shallow.max_depth = 1
	shallow.begin([install])
	shallow.step()
	assert_eq(shallow.file_count, 0, "no deeper than told")
	assert_true(shallow.cut_short)
	var stopped := SkinSourceIndex.new()
	stopped.begin([install])
	stopped.step(0)
	stopped.cancel()
	assert_false(stopped.step())
	assert_true(stopped.done)
	assert_lt(stopped.file_count, 30)


func test_a_folder_that_is_a_link_is_not_walked_into() -> void:
	if OS.has_feature("windows"):
		pass_test("links are made another way there")
		return
	F.write_file(install.path_join("Title.pic"), F.bytes([1]))
	var made := DirAccess.open(install).create_link(install, install.path_join("loop"))
	if made != OK:
		pass_test("this file system makes no links")
		return
	var index := SkinSourceIndex.of([install])
	assert_eq(index.file_count, 1, "a link back to the folder itself would never end")
	assert_true(index.has_name("loop"))


# ----------------------------------------------------------- 2. the check --

func test_the_check_says_what_a_folder_is() -> void:
	F.make_install(install)
	var report := SkinInstallCheck.survey(SkinSourceIndex.of([install]))
	assert_eq(report["kind"], SkinInstallCheck.INSTALL)
	assert_true(report["buildable"])
	assert_true((report["found"] as Array).has("the sounds"))
	assert_true((report["found"] as Array).has("the portraits"))
	assert_true((report["lacking"] as Array).has("the counter stones"))
	assert_eq(report["strangers"], [] as Array[String])
	# title, summon, the strip, the world sheet, two sounds, the font, the
	# laid sheet and the two drawn from it (the six set symbols are there
	# too, and the game does not read them).
	assert_eq(report["files"], 10)
	assert_eq(report["screens"], 2, "the wizards' hall and a figure")
	assert_eq(report["files_wanted"], SkinRecipes.MANIFEST.size() - SkinRecipes.NOT_READ.size())
	assert_eq(report["portraits"], 2 + 1 + 2, "two of the sheet's frames, the Facemaker's, two named rogues")
	assert_eq(report["movies"], 1)
	var said := "\n".join(PackedStringArray(report["lines"]))
	assert_string_contains(said, "installed copy of the 1997 game")
	assert_string_contains(said, "Not found: ")
	assert_string_contains(said, "10 of the %d skin files" % report["files_wanted"])
	assert_string_contains(said, "movies will be left out")


func test_a_copy_without_its_program_and_a_cd() -> void:
	F.make_install(install)
	DirAccess.remove_absolute(install.path_join("Shandalar.exe"))
	var partial := SkinInstallCheck.survey(SkinSourceIndex.of([install]))
	assert_eq(partial["kind"], SkinInstallCheck.PARTIAL)
	assert_true(partial["buildable"])
	F.write_file(install.path_join("AUTORUN.INF"), F.bytes([1]))
	assert_eq(SkinInstallCheck.survey(SkinSourceIndex.of([install]))["kind"], SkinInstallCheck.CD)


func test_a_folder_that_is_no_copy_is_said_so() -> void:
	var other := root.path_join("Holiday")
	F.write_file(other.path_join("photo.png"), F.noise(50, 1))
	F.write_file(other.path_join("notes/todo.txt"), F.noise(50, 2))
	var index := SkinSourceIndex.of([other])
	assert_false(SkinInstallCheck.is_copy(index, other))
	var report := SkinInstallCheck.survey(index)
	assert_eq(report["kind"], SkinInstallCheck.NOTHING)
	assert_false(report["buildable"])
	assert_eq(report["strangers"], [other] as Array[String])
	assert_eq((report["lines"] as Array).size(), 1)
	assert_string_contains(report["lines"][0], "not a copy of the 1997 game")
	# And beside a real one, it is the stranger.
	F.make_install(install)
	var both := SkinSourceIndex.of([install, other])
	assert_true(SkinInstallCheck.is_copy(both, install))
	assert_eq(SkinInstallCheck.survey(both)["strangers"], [other] as Array[String])


func test_a_later_remake_s_files_are_counted_out() -> void:
	F.make_install(install)
	# A PNG under a 1997 name, and a sound in a Program/ tree.
	F.write_file(install.path_join("Program/CardArt/Cardbk_White.pic"),
		F.bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]))
	F.write_file(install.path_join("Program/Sound/Dueltune.wav"), F.bytes([9, 9]))
	F.write_file(install.path_join("Program/Sound/LocMus3.wav"), F.bytes([9, 9]))
	var index := SkinSourceIndex.of([install])
	var planned := SkinBuildJob.plan(index)
	assert_eq((planned["refused_png"] as Array).size(), 1)
	assert_eq(planned["refused_png"][0][0], "card_frame_white")
	assert_eq((planned["refused_program"] as Array).size(), 1, "the tune only a Program/ tree holds")
	assert_true((planned["missing"] as Array).has("music_location_3.wav"))
	assert_true((planned["missing"] as Array).has("card_frame_white"))
	assert_true(SkinBuildJob.is_later_sound_copy("/x/Program/DuelSounds/Tap.wav"))
	assert_false(SkinBuildJob.is_later_sound_copy("/x/Game/DuelSounds/Tap.wav"))
	var report := SkinInstallCheck.survey(index)
	assert_eq(report["later_art"] + report["later_sounds"], 2)
	assert_string_contains("\n".join(PackedStringArray(report["lines"])), "2 files here come from a later remake")


# ----------------------------------------------------------- 3. the build --

func test_a_build_gives_the_python_tool_s_skin() -> void:
	var made := F.make_install(install)
	var result := SkinBuildJob.build([install], zip)
	assert_true(result["ok"], String(result["why"]))
	assert_eq(result["skipped"], [])
	assert_false(FileAccess.file_exists(zip + SkinBuildJob.PART_TAIL), "the .part took the zip's name")
	var entries := _entries(zip)
	var names: Array = entries.keys()
	names.sort()
	var wanted := ["adventure_cards.json", "adventure_hints.json", "adventure_wise_words.json",
		"character_select_background.png", "filter_icons.png", "filter_icons_hover.png",
		"filter_icons_pressed.png", "font_title.ttf", "movies/cointoss_heads.avi",
		"music_duel.wav", "portraits/facemaker_face.png", "portraits/melody_whisp.png",
		"portraits/rogue_undead_knight.png", "portraits/rogue_witch.png",
		"portraits/sir_van_popple.png", "set_icon_4ed.png", "set_icon_arn.png", "set_icon_atq.png",
		"set_icon_drk.png", "set_icon_leg.png", "set_icon_past.png", "sfx_button.wav",
		"stat_buttons.png", "summon_sick.png",
		"title_background.png", "wizards_figure_blue.png", "wizards_ground.png",
		"world_landtile.json", "world_landtile.png"]
	assert_eq(names, wanted.map(func(name: String) -> String: return "skin/" + name))
	assert_eq(result["files"], wanted.size())
	assert_eq(result["left_out"], ["coin_toss_heads"] as Array[String])
	assert_true((result["missing"] as Array).has("deck_slot_plaques"))
	assert_false((result["missing"] as Array).has("filter_icons_hover"))

	# The game takes it.
	var seen: Dictionary = SkinPack.inspect(zip)
	assert_true(seen["ok"], String(seen["why"]))
	assert_eq(seen["kind"], "skin")
	assert_eq(seen["files"], wanted.size())

	# Copied byte for byte — the duel's own click, not the CD's namesake.
	assert_eq(entries["skin/music_duel.wav"], made["wav"])
	assert_eq(entries["skin/font_title.ttf"], made["ttf"])
	assert_eq(entries["skin/sfx_button.wav"], F.noise(64, 18))
	assert_eq(entries["skin/movies/cointoss_heads.avi"], F.noise(700, 25))

	# A screen with its own palette: opaque, 255 a colour like any other.
	var world: PackedByteArray = made["world_palette"]
	var title := F.png(entries["skin/title_background.png"])
	assert_eq([title["width"], title["height"], title["alpha"]], [12, 8, false])
	assert_eq(title["rgba"], SkinPicCodec.paint(made["title"], SkinPicCodec.pixel_table(world)))

	# A bare picture: the duel palette, index 255 clear.
	var palette: PackedByteArray = made["palette"]
	var summon := F.png(entries["skin/summon_sick.png"])
	assert_eq([summon["width"], summon["height"], summon["alpha"]], [10, 5, true])
	var summon_rgba: PackedByteArray = summon["rgba"]
	var indices: PackedByteArray = made["summon"]
	for i in indices.size():
		var index_here := indices[i]
		assert_eq(summon_rgba.slice(i * 4, i * 4 + 4), F.bytes([palette[index_here * 3],
			palette[index_here * 3 + 1], palette[index_here * 3 + 2], 0 if index_here == 255 else 255]))
	assert_eq(summon_rgba[7 * 4 + 3], 0)

	# The strip: one row of sixteen cells in the adventure's palette.
	var strip := F.png(entries["skin/stat_buttons.png"])
	assert_eq([strip["width"], strip["height"], strip["alpha"]], [16 * 48, 48, true])
	var first_cell := F.noise(48 * 48, 20, 250)
	var strip_rgba: PackedByteArray = strip["rgba"]
	for x in 48:
		var value := first_cell[x]
		assert_eq(strip_rgba.slice(x * 4, x * 4 + 4), F.bytes([world[value * 3], world[value * 3 + 1],
			world[value * 3 + 2], 0 if value == 0 else 255]))

	# The world sheet and its grid.
	var sheet := F.png(entries["skin/world_landtile.png"])
	assert_eq([sheet["width"], sheet["height"]], [6 * 128, 64])
	var layout: Dictionary = JSON.parse_string((entries["skin/world_landtile.json"] as PackedByteArray).get_string_from_utf8())
	assert_eq(layout, {"cols": 6.0, "rows": 1.0, "frames": 6.0, "frame_width": 128.0,
		"frame_height": 64.0, "tops": [60.0, -1.0, -1.0, -1.0, -1.0, -1.0], "source": "Landtile.spr"})

	# The wizards' window: the hall opaque, the figure clear where pure green.
	var hall := F.png(entries["skin/wizards_ground.png"])
	assert_eq([hall["width"], hall["height"], hall["alpha"]], [6, 4, false])
	var figure := F.png(entries["skin/wizards_figure_blue.png"])
	assert_true(figure["alpha"])
	var figure_rgba: PackedByteArray = figure["rgba"]
	assert_eq(figure_rgba.slice(0, 4), F.bytes([0, 255, 0, 0]))
	assert_eq(figure_rgba.slice(12 * 4, 12 * 4 + 4), F.bytes([0, 255, 0, 0]))
	assert_eq(figure_rgba[4 + 3], 255)

	# The faces: index 0 clear on the sheet's; the mask's edge on the rest,
	# whichever value it uses; the end cap that repeats a face dropped.
	var face := F.png(entries["skin/portraits/melody_whisp.png"])
	assert_eq([face["width"], face["height"], face["alpha"]], [137, 169, true])
	for name: String in ["facemaker_face", "rogue_witch", "rogue_undead_knight"]:
		var cut := F.png(entries["skin/portraits/%s.png" % name])
		var w := 137 if name == "facemaker_face" else 138
		assert_eq([cut["width"], cut["height"]], [w, w + 32], name)
		var cut_rgba: PackedByteArray = cut["rgba"]
		assert_eq(cut_rgba[3], 0, name + ": the edge is clear")
		assert_eq(cut_rgba[(w + 1) * 4 + 3], 255, name + ": the inside is not")
	assert_false(entries.has("skin/portraits/rogue_face_00.png"))

	# The sheet laid from cells, and the two drawn from it.
	var icons := F.png(entries["skin/filter_icons.png"])
	assert_eq([icons["width"], icons["height"], icons["alpha"]], [9 * 40, 3 * 40, false])
	var icons_rgba: PackedByteArray = icons["rgba"]
	var tenth := F.noise(1600, 100 + 9, 250)   # the cell at column 0, row 1
	var at := (40 * 360) * 4
	assert_eq(icons_rgba.slice(at, at + 3), F.bytes([palette[tenth[0] * 3], palette[tenth[0] * 3 + 1],
		palette[tenth[0] * 3 + 2]]))
	var pressed: PackedByteArray = F.png(entries["skin/filter_icons_pressed.png"])["rgba"]
	var hover: PackedByteArray = F.png(entries["skin/filter_icons_hover.png"])["rgba"]
	for i in range(0, 4000, 7):
		if i % 4 == 3:
			continue
		var value := icons_rgba[i]
		assert_eq(pressed[i], _python_round(value * 0.5), "half of %d" % value)
		assert_eq(hover[i], mini(255, _python_round(value * 1.26)), "1.26 of %d" % value)

	# The lists.
	var cards: Dictionary = JSON.parse_string((entries["skin/adventure_cards.json"] as PackedByteArray).get_string_from_utf8())
	assert_eq(cards["source"], "Shandalar.exe")
	assert_eq((cards["cards"] as Dictionary).keys(), ["Air Elemental, the \"Great\"", "Forest", "Island",
		"Mountain", "Plains", "Swamp"], "sorted, the row no list names left out")
	assert_eq(cards["cards"]["Swamp"], {"id": 1.0, "type": 1.0, "color": 2.0, "cc0": 1.0, "cc1": -1.0,
		"power": 3.0, "tough": -1.0, "static": 2147483649.0, "extra": 512.0, "exp": 4.0, "ai": 0.0,
		"vanilla": true, "rarity": 1.0})
	var air: Dictionary = cards["cards"]["Air Elemental, the \"Great\""]
	assert_eq([air["vanilla"], air["rarity"], air["ai"], air["type"]], [false, 2.0, -2.0, 2.0])
	var hints: Dictionary = JSON.parse_string((entries["skin/adventure_hints.json"] as PackedByteArray).get_string_from_utf8())
	assert_eq(hints, {"source": "Hints.txt", "hints": [
		{"first": "Air Elemental, the \"Great\"", "second": "Island", "levels": 3.0,
			"text": "The Elemental flies over Islands."},
		{"first": "Swamp", "second": "", "levels": 8.0, "text": "Swamps are black."}]})
	var words: Dictionary = JSON.parse_string((entries["skin/adventure_wise_words.json"] as PackedByteArray).get_string_from_utf8())
	assert_eq(words["city"], ["News 0 first.\nNews 0 second.", "News 1 first.\nNews 1 second.",
		"News 2 first.\nNews 2 second.", "News 3 first.\nNews 3 second."])
	assert_eq(words["tales"], [["A tale, page one.", "Page two."]])


## Python's `round`: a half goes to the even number.
static func _python_round(x: float) -> int:
	var low := int(floorf(x))
	var part := x - low
	if part > 0.5 or (part == 0.5 and low % 2 == 1):
		return low + 1
	return low


func test_a_half_rounds_to_even_in_the_sheets_of_ours() -> void:
	assert_eq(_python_round(75 * 1.26), 94, "94.5 is 94 in the Python tool, not 95")
	assert_eq(_python_round(25 * 1.26), 32)
	assert_eq(_python_round(5 * 0.5), 2)
	assert_eq(_python_round(7 * 0.5), 4)


func test_the_same_build_on_a_thread() -> void:
	F.make_install(install)
	var job := SkinBuildJob.new()
	assert_true(job.open(SkinSourceIndex.of([install]), zip))
	var before: Dictionary = job.progress()
	assert_eq(before["done"], 0)
	assert_gt(before["total"], 20)
	assert_true(job.start_thread())
	var waited := 0
	while not bool(job.progress()["finished"]) and waited < 2000:
		await get_tree().process_frame
		waited += 1
	job.wait()
	var after: Dictionary = job.progress()
	assert_true(after["finished"])
	assert_eq(after["done"], after["total"], "every task counted")
	assert_true(job.result()["ok"])
	assert_eq(_entries(zip).size(), 29)


func test_two_folders_and_the_first_wins() -> void:
	var made := F.make_install(install)
	var cd := root.path_join("CD")
	F.write_file(cd.path_join("Sound/Dueltune.wav"), F.bytes([1, 2, 3]))
	F.write_file(cd.path_join("Sound/LocMus0.wav"), F.bytes([4, 5, 6]))
	var result := SkinBuildJob.build([install, cd], zip)
	assert_true(result["ok"])
	var entries := _entries(zip)
	assert_eq(entries["skin/music_duel.wav"], made["wav"], "the install's, named first")
	assert_eq(entries["skin/music_location_0.wav"], F.bytes([4, 5, 6]), "what only the CD has")


# ---------------------------------------------------- 4. what is left out --

func test_a_file_that_will_not_decode_is_left_out_and_the_build_goes_on() -> void:
	F.make_install(install)
	F.write_file(install.path_join("Title.PIC"), F.noise(300, 5))
	var cut := FileAccess.get_file_as_bytes(install.path_join("Statbutt.spr"))
	F.write_file(install.path_join("Statbutt.spr"), cut.slice(0, cut.size() - 900))
	F.write_file(install.path_join("Statwin/Wizbg.bmp"), F.make_bmp(3, 3, F.noise(27, 1), false, 8))
	F.write_file(install.path_join("Faces/002.pic"), F.noise(200, 6))
	F.write_file(install.path_join("Hints.txt"), "no hints in here\r\n".to_ascii_buffer())
	var result := SkinBuildJob.build([install], zip)
	assert_true(result["ok"], "a broken file is not a broken build")
	var skipped := {}
	for row: Dictionary in result["skipped"]:
		skipped[row["name"]] = row
		assert_ne(String(row["why"]), "")
	assert_eq(skipped.keys(), ["title_background.png", "stat_buttons.png",
		"portraits/rogue_undead_knight.png", "wizards_ground.png", "adventure_hints.json"],
		"in the order they were come to")
	assert_eq(skipped["title_background.png"]["file"], "Title.PIC")
	assert_string_contains(skipped["stat_buttons.png"]["why"], "length")
	assert_true((result["missing"] as Array).has("title_background"))
	assert_true((result["missing"] as Array).has("stat_buttons"))
	var entries := _entries(zip)
	assert_false(entries.has("skin/title_background.png"))
	assert_false(entries.has("skin/portraits/rogue_undead_knight.png"))
	assert_true(entries.has("skin/portraits/rogue_witch.png"), "the next face is still cut")
	assert_true(entries.has("skin/summon_sick.png"))
	assert_true(entries.has("skin/adventure_cards.json"))
	assert_true(bool(SkinPack.inspect(zip)["ok"]))


func test_a_picture_with_no_palette_to_wear_is_left_out() -> void:
	F.make_install(install)
	DirAccess.remove_absolute(install.path_join("Duelpalall.tr"))
	DirAccess.remove_absolute(install.path_join("Pedstls.pic"))
	var result := SkinBuildJob.build([install], zip)
	assert_true(result["ok"])
	var names: Array = (result["skipped"] as Array).map(func(row: Dictionary) -> String: return row["name"])
	assert_true(names.has("summon_sick.png"))
	assert_true(names.has("portraits/"), "the faces say it once")
	assert_eq(names.count("portraits/"), 2, "the sheet's faces and the rogues")
	assert_true(_entries(zip).has("skin/title_background.png"), "a picture with its own palette needs none")


func test_a_file_far_too_large_is_not_opened() -> void:
	F.make_install(install)
	var job := SkinBuildJob.new()
	job.max_art_file = 6000   # the palettes are under it, the strip is not
	job.max_copy_file = 1000
	assert_true(job.open(SkinSourceIndex.of([install]), zip))
	job.step()
	var result := job.result()
	assert_true(result["ok"])
	var why := {}
	for row: Dictionary in result["skipped"]:
		why[row["name"]] = row["why"]
	assert_string_contains(why["stat_buttons.png"], "larger")
	assert_string_contains(why["music_duel.wav"], "larger")
	assert_false(why.has("sfx_button.wav"), "a small one is taken")


func test_a_later_remake_s_png_is_not_taken() -> void:
	F.make_install(install)
	F.write_file(install.path_join("Cardart/Summon.pic"),
		F.bytes([0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A, 1, 2, 3]))
	var result := SkinBuildJob.build([install], zip)
	assert_true(result["ok"])
	assert_eq(result["later_art"], 1)
	assert_true((result["missing"] as Array).has("summon_sick"))
	assert_false(_entries(zip).has("skin/summon_sick.png"))


# -------------------------------------------------------- 5. whole or not --

func test_a_build_stopped_leaves_no_file() -> void:
	F.make_install(install)
	var job := SkinBuildJob.new()
	assert_true(job.open(SkinSourceIndex.of([install]), zip))
	assert_true(job.step(0), "one task done, more to do")
	assert_true(FileAccess.file_exists(zip + SkinBuildJob.PART_TAIL))
	job.cancel()
	assert_false(job.step())
	var result := job.result()
	assert_false(result["ok"])
	assert_true(result["stopped"])
	assert_true(job.progress()["finished"])
	assert_false(FileAccess.file_exists(zip), "no zip")
	assert_false(FileAccess.file_exists(zip + SkinBuildJob.PART_TAIL), "and no .part")


func test_a_build_stopped_keeps_the_zip_that_was_there() -> void:
	F.make_install(install)
	F.write_file(zip, F.bytes([1, 2, 3]))
	var job := SkinBuildJob.new()
	job.open(SkinSourceIndex.of([install]), zip)
	job.step(0)
	job.cancel()
	job.step()
	assert_eq(FileAccess.get_file_as_bytes(zip), F.bytes([1, 2, 3]))
	# And a build that ends well takes its place.
	assert_true(SkinBuildJob.build([install], zip)["ok"])
	assert_true(bool(SkinPack.inspect(zip)["ok"]))


func test_a_folder_with_nothing_of_the_game_builds_nothing() -> void:
	F.write_file(install.path_join("photo.png"), F.noise(50, 1))
	var result := SkinBuildJob.build([install], zip)
	assert_false(result["ok"])
	assert_string_contains(result["why"], "Nothing of the 1997 game")
	assert_false(FileAccess.file_exists(zip))
	assert_false(FileAccess.file_exists(zip + SkinBuildJob.PART_TAIL))
	# Files under 1997 names that are all noise: nothing reads, nothing is kept.
	F.write_file(install.path_join("Title.pic"), F.noise(50, 2))
	F.write_file(install.path_join("Statbutt.spr"), F.noise(50, 3))
	result = SkinBuildJob.build([install], zip)
	assert_false(result["ok"])
	assert_eq((result["skipped"] as Array).size(), 2)
	assert_false(FileAccess.file_exists(zip))
	assert_false(FileAccess.file_exists(zip + SkinBuildJob.PART_TAIL))


func test_a_place_that_cannot_be_written_is_said_and_leaves_nothing() -> void:
	F.make_install(install)
	# A file where the zip's folder should be.
	F.write_file(root.path_join("blocked"), F.bytes([1]))
	var result := SkinBuildJob.build([install], root.path_join("blocked/original_skin.zip"))
	assert_false(result["ok"])
	assert_string_contains(result["why"], "could not be written")
	assert_false(result["stopped"])


func test_no_two_recipes_write_one_file() -> void:
	var names := {}
	for key: String in SkinRecipes.MANIFEST:
		names[key if key.ends_with(".wav") or key.ends_with(".ttf") else key + ".png"] = true
	var count := SkinRecipes.MANIFEST.size()
	for key: String in SkinRecipes.PIC_SCREENS:
		names[key + ".png"] = true
	count += SkinRecipes.PIC_SCREENS.size()
	for key: String in SkinRecipes.SIDECAR_SHEETS:
		names[key + ".json"] = true
	count += SkinRecipes.SIDECAR_SHEETS.size()
	assert_eq(names.size(), count, "each entry of the zip is written once")
	for key: String in SkinRecipes.SIDECAR_SHEETS:
		assert_true(SkinRecipes.SPR_SHEETS.has(key) and SkinRecipes.MANIFEST.has(key), key)
	for key: String in SkinRecipes.DERIVED_SHEETS:
		assert_true(SkinRecipes.PIC_SHEETS.has(SkinRecipes.DERIVED_SHEETS[key][0]))
