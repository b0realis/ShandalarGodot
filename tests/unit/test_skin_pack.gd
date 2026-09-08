extends GutTest
## THE SKIN PACKS — [SkinPack] (2026-09-08, `[QoL]`): the skin as two
## zips mounted at `res://skin` — the 1997 art and, apart from it, the
## card pictures — read by [GameSkin], [PortraitLibrary] and
## [MusicLibrary] in place. Tiny zips are built here with [ZIPPacker]
## (a 4x6 PNG, a portrait, a sidecar; a card picture alone), so the
## contract is tested in a checkout with no 1997 art at all: what a
## valid zip is and of which kind, what happens when one is mounted,
## where the browser looks, what a drop or a chosen file keeps, and what
## the Options screen's rows say.
##
## A mount is for the life of the process (the engine has no unmount),
## so the probe's keys are `zz_`-prefixed and the world is put back
## through [member GameSkin.pack_mounted], which is what makes the
## mounted folder visible to the searches at all.

const SCRATCH := "user://skin_pack_test"
const GOOD := SCRATCH + "/probe.zip"
## Card pictures alone — the second kind of zip.
const ART := SCRATCH + "/art.zip"
## A skin that carries its own card pictures — still a skin.
const BOTH := SCRATCH + "/both.zip"
const OUTSIDE := SCRATCH + "/outside.zip"
const CLIMBING := SCRATCH + "/climbing.zip"
const EMPTY := SCRATCH + "/empty.zip"
const NOT_A_ZIP := SCRATCH + "/not_a_zip.zip"
## Kept aside while a test stores its own zips where the player's go.
const ASIDE := SCRATCH + "/aside_%s.zip"

var _was_mounted := false
var _had_user_zip: Dictionary = {}


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	for kind in SkinPack.KINDS:
		_had_user_zip[kind] = FileAccess.file_exists(SkinPack.user_zip(kind))
		if _had_user_zip[kind]:
			DirAccess.rename_absolute(SkinPack.user_zip(kind), ASIDE % kind)
	_write_probe()


func after_each() -> void:
	GameSkin.pack_mounted = _was_mounted
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	SkinPack._hide_notice()
	for kind in SkinPack.KINDS:
		if FileAccess.file_exists(SkinPack.user_zip(kind)):
			DirAccess.remove_absolute(SkinPack.user_zip(kind))
		if _had_user_zip[kind]:
			DirAccess.rename_absolute(ASIDE % kind, SkinPack.user_zip(kind))
	for name in DirAccess.get_files_at(SCRATCH):
		DirAccess.remove_absolute(SCRATCH.path_join(name))
	DirAccess.remove_absolute(SCRATCH)


## The notice's headline: the first label under it.
static func _first_label(node: Node) -> Label:
	if node is Label:
		return node
	for child in node.get_children():
		var found := _first_label(child)
		if found != null:
			return found
	return null


## A 4x6 picture, so a texture read back through the mount is measurable.
static func _png() -> PackedByteArray:
	var img := Image.create(4, 6, false, Image.FORMAT_RGBA8)
	img.fill(Color.ORANGE_RED)
	return img.save_png_to_buffer()


static func _zip(path: String, entries: Dictionary) -> void:
	var packer := ZIPPacker.new()
	assert(packer.open(path) == OK)
	for name in entries:
		packer.start_file(name)
		var body: Variant = entries[name]
		packer.write_file(body if body is PackedByteArray else String(body).to_utf8_buffer())
		packer.close_file()
	packer.close()


func _write_probe() -> void:
	_zip(GOOD, {
		"skin/zz_pack_probe.png": _png(),
		"skin/zz_pack_probe.json": '{"cols": 7, "rows": 9}',
		"skin/portraits/zz_probe_face.png": _png(),
		"skin/music/README.txt": "not a tune",
	})
	_zip(ART, {"skin/cardart/zz_probe_card.png": _png()})
	_zip(BOTH, {"skin/zz_pack_probe.png": _png(),
		"skin/cardart/zz_probe_card.png": _png()})
	_zip(OUTSIDE, {"skin/zz_x.png": _png(), "readme.txt": "loose"})
	_zip(CLIMBING, {"skin/../zz_escape.png": _png()})
	_zip(EMPTY, {"skin/": PackedByteArray()})
	var file := FileAccess.open(NOT_A_ZIP, FileAccess.WRITE)
	file.store_string("<html>404 Not Found</html>")
	file.close()


# ---------------------------------------------------------- the contract --

func test_a_zip_with_everything_under_skin_is_a_skin() -> void:
	var report := SkinPack.inspect(GOOD)
	assert_true(report["ok"], String(report["why"]))
	assert_eq(int(report["files"]), 4, "four files, no folder entries")
	assert_eq(String(report["kind"]), "skin")
	assert_eq(int(report["art"]), 0)


## The owner, 2026-09-08: *"the skin assets should be a separate zip,
## card art pack should be separate!"* — and a zip is what it HOLDS,
## whatever it is called.
func test_a_zip_of_card_pictures_alone_is_card_art() -> void:
	var report := SkinPack.inspect(ART)
	assert_true(report["ok"], String(report["why"]))
	assert_eq(String(report["kind"]), "cardart")
	assert_eq(int(report["files"]), 1)
	assert_eq(int(report["art"]), 1)


func test_a_skin_that_carries_card_pictures_is_still_a_skin() -> void:
	var report := SkinPack.inspect(BOTH)
	assert_eq(String(report["kind"]), "skin", "the 277 MB zip of the first build")
	assert_eq(int(report["files"]), 2)
	assert_eq(int(report["art"]), 1, "and its pictures count")


func test_the_zips_are_named_for_their_kind() -> void:
	assert_eq(SkinPack.file_name("skin"), "original_skin.zip")
	assert_eq(SkinPack.file_name("cardart"), "cardart.zip")
	assert_eq(SkinPack.user_zip("cardart"), "user://skin/cardart.zip")
	assert_eq(SkinPack.USER_ART_ZIP, "user://skin/cardart.zip")


func test_an_entry_outside_skin_refuses_the_whole_zip() -> void:
	var report := SkinPack.inspect(OUTSIDE)
	assert_false(report["ok"])
	assert_string_contains(String(report["why"]), "readme.txt")


func test_a_climbing_entry_refuses_the_zip() -> void:
	assert_false(SkinPack.inspect(CLIMBING)["ok"])


func test_an_empty_zip_is_not_a_skin() -> void:
	var report := SkinPack.inspect(EMPTY)
	assert_false(report["ok"])
	assert_string_contains(String(report["why"]), "no skin/ folder")


func test_a_404_page_saved_as_a_zip_is_not_a_skin() -> void:
	var report := SkinPack.inspect(NOT_A_ZIP)
	assert_false(report["ok"])
	assert_eq(String(report["why"]), "not a zip file")


func test_a_missing_file_is_not_a_skin() -> void:
	assert_false(SkinPack.inspect(SCRATCH + "/nowhere.zip")["ok"])


# ------------------------------------------------------------- the mount --

func test_a_mounted_pack_is_read_by_the_skin_in_place() -> void:
	assert_true(SkinPack.mount(GOOD, true), "the probe mounts")
	assert_true(GameSkin.pack_mounted)
	assert_has(GameSkin.search_dirs(), GameSkin.PACK_DIR)
	assert_true(GameSkin.is_present(), "a mounted pack counts as a skin")
	GameSkin.clear_caches()
	var tex := GameSkin.texture("zz_pack_probe")
	assert_not_null(tex, "the PNG inside the zip, as a texture")
	if tex != null:
		assert_eq(tex.get_width(), 4)
		assert_eq(tex.get_height(), 6)
	var meta := GameSkin.metadata("zz_pack_probe")
	assert_eq(int(meta.get("cols", 0)), 7, "the sidecar beside it")
	assert_null(GameSkin.texture("zz_not_in_the_zip"))


func test_the_pack_sits_after_the_players_own_folder_and_before_a_checkout() -> void:
	GameSkin.pack_mounted = true
	var dirs := GameSkin.search_dirs()
	assert_eq(dirs[0], GameSkin.SEARCH_DIRS[0], "user://original_skin first")
	assert_eq(dirs[dirs.size() - 1], GameSkin.SEARCH_DIRS[1], "res://assets/original last")
	assert_lt(dirs.find(GameSkin.PACK_DIR), dirs.size() - 1)
	GameSkin.pack_mounted = false
	assert_does_not_have(GameSkin.search_dirs(), GameSkin.PACK_DIR,
		"invisible until a pack is mounted")


func test_the_mounted_pack_supplies_portraits() -> void:
	assert_true(SkinPack.mount(GOOD, true))
	assert_has(PortraitLibrary.portable_dirs(), GameSkin.PACK_DIR.path_join("portraits"))
	PortraitLibrary.refresh()
	var ids := PackedStringArray()
	for face in PortraitLibrary.all():
		ids.append(String(face["id"]))
	assert_has(ids, "zz_probe_face", "the portrait inside the zip is in the chooser")
	# And it DRAWS: read at its `res://skin/` name, not at a globalized
	# path beside the binary that does not exist (2026-09-08 — the pack's
	# portraits were listed and blank, in the package and the browser).
	var tex := PortraitLibrary.texture("zz_probe_face")
	assert_not_null(tex, "the portrait inside the zip, as a texture")
	if tex != null:
		assert_eq(tex.get_width(), 4)
		assert_eq(tex.get_height(), 6)
	GameSkin.pack_mounted = false
	assert_does_not_have(PortraitLibrary.portable_dirs(), GameSkin.PACK_DIR.path_join("portraits"))


func test_the_mounted_pack_is_searched_for_music() -> void:
	GameSkin.pack_mounted = true
	assert_has(MusicLibrary._search_dirs(), GameSkin.PACK_DIR.path_join("music"))
	GameSkin.pack_mounted = false
	assert_does_not_have(MusicLibrary._search_dirs(), GameSkin.PACK_DIR.path_join("music"))


func test_the_mounted_art_pack_supplies_card_art() -> void:
	assert_true(SkinPack.mount(ART, true), "the card art probe mounts")
	assert_true(SkinPack.has("cardart"))
	GameSkin.clear_caches()
	var tex := GameSkin.card_art("Zz Probe Card")
	assert_not_null(tex, "the picture inside the zip, by the card's name")
	if tex != null:
		assert_eq(tex.get_width(), 4)
		assert_eq(tex.get_height(), 6)
	assert_null(GameSkin.card_art("Zz Not In The Zip"))
	var about := SkinPack.describe("cardart")
	assert_eq(String(about["source"]), "mounted", "from a path that is neither the player's nor the shipped one")
	assert_eq(String(about["name"]), "art.zip")
	assert_eq(int(about["files"]), 1)


func test_a_mounted_skin_does_not_count_as_card_art_nor_the_reverse() -> void:
	assert_true(SkinPack.mount(GOOD, true))
	assert_true(SkinPack.has("skin"))
	assert_eq(SkinPack._holds(GOOD, "cardart"), 0, "no pictures in the skin probe")
	assert_true(SkinPack.mount(ART, true))
	assert_eq(SkinPack._holds(ART, "skin"), 0, "no skin in the art probe")
	assert_true(SkinPack.mount(BOTH, true))
	assert_eq(SkinPack._holds(BOTH, "skin"), 1)
	assert_eq(SkinPack._holds(BOTH, "cardart"), 1, "a skin with pictures serves both")


func test_a_zip_that_is_not_a_skin_does_not_mount() -> void:
	var before := SkinPack.mounted.size()
	assert_false(SkinPack.mount(OUTSIDE, true))
	assert_false(SkinPack.mount(NOT_A_ZIP, true))
	assert_eq(SkinPack.mounted.size(), before)


# ------------------------------------------------------------- the drop --

func test_a_dropped_zip_is_kept_as_the_players_own_and_mounted() -> void:
	# The arrival plan reads the tree's current scene, and an earlier suite
	# may have left the title there (a "back" button on the setup or
	# options screen changes to main.tscn for the rest of the run). Pin
	# the scene to a stand-in, so this is "any other screen" every time.
	var was := get_tree().current_scene
	var elsewhere := Node.new()
	get_tree().root.add_child(elsewhere)
	get_tree().current_scene = elsewhere
	SkinPack._on_files_dropped(PackedStringArray([
		ProjectSettings.globalize_path(SCRATCH + "/notes.txt"),
		ProjectSettings.globalize_path(GOOD)]))
	assert_true(FileAccess.file_exists(SkinPack.USER_ZIP), "copied where the player's zip lives")
	assert_has(SkinPack.mounted, SkinPack.USER_ZIP)
	assert_true(GameSkin.pack_mounted)
	assert_not_null(SkinPack.notice(), "off the title screen, the game offers a restart")
	var later := SkinPack.notice().find_child("Later", true, false) as Button
	assert_not_null(later)
	if later != null:
		later.pressed.emit()
	assert_null(SkinPack.notice(), "Later takes the notice down")
	get_tree().current_scene = was
	elsewhere.queue_free()


func test_a_dropped_card_art_zip_is_kept_as_the_players_card_art() -> void:
	var was := get_tree().current_scene
	var elsewhere := Node.new()
	get_tree().root.add_child(elsewhere)
	get_tree().current_scene = elsewhere
	SkinPack._on_files_dropped(PackedStringArray([ProjectSettings.globalize_path(ART)]))
	assert_true(FileAccess.file_exists(SkinPack.USER_ART_ZIP), "kept as cardart.zip, by what it holds")
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP), "not as the skin")
	assert_has(SkinPack.mounted, SkinPack.USER_ART_ZIP)
	assert_true(SkinPack.has_own())
	assert_eq(String(SkinPack.describe("cardart")["source"]), "yours")
	assert_not_null(SkinPack.notice())
	if SkinPack.notice() != null:
		var head := _first_label(SkinPack.notice())
		assert_eq(head.text if head != null else "", "The card art is in.",
			"the notice names the kind that arrived")
		assert_not_null(SkinPack.notice().find_child("Restart", true, false))
	get_tree().current_scene = was
	elsewhere.queue_free()


func test_forgetting_deletes_the_players_zips_and_offers_a_restart() -> void:
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	DirAccess.copy_absolute(GOOD, SkinPack.USER_ZIP)
	DirAccess.copy_absolute(ART, SkinPack.USER_ART_ZIP)
	assert_true(SkinPack.has_own())
	var told := [0]   # a lambda captures a number by value, an array by reference
	var count := func(_kind: String) -> void:
		told[0] += 1
	SkinPack.changed.connect(count)
	SkinPack.forget()
	SkinPack.changed.disconnect(count)
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP))
	assert_false(FileAccess.file_exists(SkinPack.USER_ART_ZIP))
	assert_false(SkinPack.has_own())
	assert_eq(told[0], 1, "the rows are told once")
	assert_not_null(SkinPack.notice())
	if SkinPack.notice() != null:
		assert_not_null(SkinPack.notice().find_child("Restart", true, false),
			"what is mounted stays mounted this run")


func test_a_forgotten_zip_is_worn_until_the_restart_and_the_row_says_so() -> void:
	DirAccess.make_dir_recursive_absolute(SkinPack.USER_DIR)
	DirAccess.copy_absolute(ART, SkinPack.USER_ART_ZIP)
	assert_true(SkinPack.mount(SkinPack.USER_ART_ZIP, true))
	assert_eq(String(SkinPack.describe("cardart")["source"]), "yours")
	SkinPack.forget()
	assert_has(SkinPack.mounted, SkinPack.USER_ART_ZIP, "still mounted this run")
	assert_eq(String(SkinPack.describe("cardart")["source"]), "forgotten",
		"the file is gone, the mount is not — the row must not say 'your own'")


func test_forgetting_with_nothing_kept_says_nothing() -> void:
	SkinPack.forget()
	assert_null(SkinPack.notice())


func test_a_dropped_zip_that_is_not_a_skin_is_refused_and_said_so() -> void:
	SkinPack._on_files_dropped(PackedStringArray([ProjectSettings.globalize_path(OUTSIDE)]))
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP), "nothing kept")
	assert_not_null(SkinPack.notice(), "and the player is told")
	var ok := SkinPack.notice().find_child("Later", true, false) as Button
	assert_not_null(ok)
	if ok != null:
		assert_eq(ok.text, "OK")
		assert_null(SkinPack.notice().find_child("Restart", true, false),
			"no restart offered for a refused zip")


func test_a_drop_without_a_zip_does_nothing() -> void:
	SkinPack._on_files_dropped(PackedStringArray([
		ProjectSettings.globalize_path(SCRATCH + "/notes.txt")]))
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP))
	assert_null(SkinPack.notice())


# ------------------------------------------------------- the options rows --

## The words the Options screen's `Skin:` rows say, for each thing
## [method SkinPack.describe] can find.
func test_the_status_lines_say_what_dresses_the_game() -> void:
	assert_eq(SkinPack.status_line("skin", {"source": "none", "name": "", "files": 0}),
		"1997 art: none — the game draws its own")
	assert_eq(SkinPack.status_line("cardart", {"source": "none", "name": "", "files": 0}),
		"Card art: none — cards show a plain art window")
	assert_eq(SkinPack.status_line("skin",
		{"source": "yours", "name": "original_skin.zip", "files": 235}),
		"1997 art: original_skin.zip — 235 files, your own")
	assert_eq(SkinPack.status_line("cardart",
		{"source": "shipped", "name": "cardart.zip", "files": 1795}),
		"Card art: cardart.zip — 1795 pictures, shipped with the game")
	assert_eq(SkinPack.status_line("skin",
		{"source": "folder", "name": "res://assets/original", "files": 0}),
		"1997 art: a loose folder, res://assets/original")
	assert_eq(SkinPack.status_line("cardart",
		{"source": "forgotten", "name": "cardart.zip", "files": 1}),
		"Card art: cardart.zip — 1 picture, forgotten, worn until the restart")


func test_the_rows_read_the_mounted_zips_first_and_the_folders_after() -> void:
	# Under the editor nothing is mounted and the checkout's own folders
	# are what the search finds (or nothing at all, in a bare checkout).
	var skin := SkinPack.describe("skin")
	assert_true(String(skin["source"]) in ["folder", "none", "mounted", "yours", "forgotten"],
		"a source the line can say: " + String(skin["source"]))
	assert_true(SkinPack.mount(GOOD, true))
	assert_eq(String(SkinPack.describe("skin")["source"]), "mounted",
		"a mounted zip outranks a folder")
	assert_eq(int(SkinPack.describe("skin")["files"]), 4)


func test_nothing_is_in_flight_under_the_editor() -> void:
	assert_false(SkinPack.busy())
	assert_false(SkinPack.picking)
	assert_eq(SkinPack.transfer_line(-1.0), "", "no line when nothing is on its way")
	assert_eq(SkinPack.pick_progress(), -1.0)


func test_the_file_box_opens_somewhere_real() -> void:
	var start := SkinPack.pick_start_dir()
	assert_ne(start, "")
	assert_true(DirAccess.dir_exists_absolute(start), start)


# ------------------------------------------------------------ the browser --

func test_the_browser_looks_beside_its_page() -> void:
	assert_eq(SkinPack.pack_url("http://localhost:8000/"),
		"http://localhost:8000/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("http://localhost:8000/", "cardart"),
		"http://localhost:8000/skin/cardart.zip", "the card art beside the skin")
	assert_eq(SkinPack.pack_url("http://localhost:8000/index.html"),
		"http://localhost:8000/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("https://b0realis.github.io/shandalar/index.html?v=3#top"),
		"https://b0realis.github.io/shandalar/skin/original_skin.zip")
	assert_eq(SkinPack.pack_url("https://example.org/play/"),
		"https://example.org/play/skin/original_skin.zip")


func test_the_fetch_progress_is_unknown_when_nothing_is_in_flight() -> void:
	assert_eq(SkinPack.fetch_progress(), -1.0)
	assert_false(SkinPack.fetching)


## The web client never says how big a body is, so the size comes from
## the host's HEAD answer — read case-blind, and -1 when it is missing.
func test_the_zips_size_is_read_off_the_hosts_head_answer() -> void:
	assert_eq(SkinPack.content_length(PackedStringArray([
		"content-type:application/zip", "Content-Length: 277089881"])), 277089881)
	assert_eq(SkinPack.content_length(PackedStringArray(["content-type:application/zip"])), -1)
	assert_eq(SkinPack.content_length(PackedStringArray(["content-length: 0"])), -1)


func test_the_shipped_zip_has_no_place_under_the_editor() -> void:
	assert_eq(SkinPack.portable_zip(), "", "no executable to be beside")
	assert_eq(SkinPack.portable_zip("cardart"), "")


func test_the_title_is_rebuilt_and_any_other_screen_offered_a_restart() -> void:
	assert_eq(SkinPack.plan_after_arrival(SkinPack.TITLE_SCENE), "reload")
	assert_eq(SkinPack.plan_after_arrival("res://game/duel/duel_screen.tscn"), "restart")
	assert_eq(SkinPack.plan_after_arrival(""), "restart")
