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
## Where the skins folder's zips wait while a test stores its own there.
const ASIDE := SCRATCH + "/aside"
## The card folder, pointed at scratch through its own key so a pack the
## owner keeps never counts as a test's.
const PACKS := SCRATCH + "/cardpacks"
## The keys a test may write; remembered and put back, never written
## back as a default (see tests/ui/test_game_audio.gd on why).
const KEYS: Array[String] = [GamePaths.KEY_CARDPACKS, GamePaths.KEY_SKIN_ZIP,
	GamePaths.KEY_USE_SKIN_FOLDER, GamePaths.KEY_SKIN_FOLDER]

var _was_mounted := false
var _aside: Array[String] = []
var _saved: Dictionary = {}


func before_each() -> void:
	_was_mounted = GameSkin.pack_mounted
	DirAccess.make_dir_recursive_absolute(SCRATCH)
	DirAccess.make_dir_recursive_absolute(ASIDE)
	DirAccess.make_dir_recursive_absolute(PACKS)
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)
	Settings.set_value(GamePaths.KEY_CARDPACKS, PACKS)
	_aside = []
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.rename_absolute(path, ASIDE.path_join(path.get_file()))
		_aside.append(path)
	_write_probe()


func after_each() -> void:
	GameSkin.pack_mounted = _was_mounted
	GameSkin.clear_caches()
	PortraitLibrary.refresh()
	MusicLibrary.refresh()
	SkinPack._hide_notice()
	for path in SkinPack._zips_in(SkinPack.USER_DIR):
		DirAccess.remove_absolute(path)
	for path in _aside:
		DirAccess.rename_absolute(ASIDE.path_join(path.get_file()), path)
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])
	for folder in [PACKS, ASIDE, SCRATCH + "/old_skin", SCRATCH + "/theirs"]:
		if not DirAccess.dir_exists_absolute(folder):
			continue
		for name in DirAccess.get_files_at(folder):
			DirAccess.remove_absolute(folder.path_join(name))
		DirAccess.remove_absolute(folder)
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
	assert_eq(SkinPack.user_zip("skin"), "user://skins/original_skin.zip",
		"the skins folder")
	assert_eq(SkinPack.user_zip("cardart"), PACKS + "/cardart.zip",
		"the card folder, wherever the key points")
	Settings.clear_value(GamePaths.KEY_CARDPACKS)
	assert_eq(SkinPack.user_zip("cardart"), "user://cardpacks/cardart.zip",
		"user://cardpacks by default")


## The owner, 2026-09-08: *"point to skin zip in skins folder … Card
## folder (therein cardpacks as zip are placed; support for future card
## packs)"* — a zip that arrives is kept under its own name in the
## folder of its kind, and a name a browser might report that is no
## file name at all falls back to the kind's own.
func test_an_arriving_zip_is_kept_under_its_own_name_in_the_folder_of_its_kind() -> void:
	assert_eq(SkinPack.home_for("skin", "/home/me/Downloads/my_skin.zip"),
		"user://skins/my_skin.zip")
	assert_eq(SkinPack.home_for("cardart", "more_art.zip"), PACKS + "/more_art.zip")
	assert_eq(SkinPack.home_for("skin", "notes.txt"), "user://skins/original_skin.zip",
		"not a zip name: the kind's own")
	assert_eq(SkinPack.home_for("cardart", ""), PACKS + "/cardart.zip")
	assert_eq(SkinPack.home_for("skin", "a:b?.zip"), "user://skins/original_skin.zip",
		"not a file name: the kind's own")


func test_every_zip_in_the_card_folder_is_a_pack_by_name() -> void:
	assert_eq(SkinPack.cardpacks(), [] as Array[String], "an empty folder")
	DirAccess.copy_absolute(ART, PACKS + "/zebra.zip")
	DirAccess.copy_absolute(ART, PACKS + "/apple.zip")
	DirAccess.copy_absolute(ART, PACKS + "/fetching.zip")
	var notes := FileAccess.open(PACKS + "/README.txt", FileAccess.WRITE)
	notes.store_string("not a zip")
	notes.close()
	assert_eq(SkinPack.cardpacks(), [PACKS + "/apple.zip", PACKS + "/zebra.zip"] as Array[String],
		"by name, zips only, a transfer in flight left out")
	Settings.set_value(GamePaths.KEY_CARDPACKS, SCRATCH + "/nowhere")
	assert_eq(SkinPack.cardpacks(), [] as Array[String], "a folder that is not there")


## The `skin_zip` key names the skin worn; a missing file falls back to
## the player's own default, and the default to the shipped one.
func test_the_skin_zip_key_names_the_zip_worn() -> void:
	assert_eq(SkinPack.own_skin_zip(), SkinPack.USER_ZIP, "no key: the default")
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, GOOD)
	assert_eq(SkinPack.own_skin_zip(), GOOD)
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, SCRATCH + "/gone.zip")
	assert_eq(SkinPack.own_skin_zip(), SkinPack.USER_ZIP, "a key naming nothing is ignored")


## The first two-zip build kept both zips in `user://skin/`; the next
## start moves them where this build looks, once, and never over a newer one.
func test_the_first_builds_zips_are_moved_to_the_new_folders_once() -> void:
	var old := SCRATCH + "/old_skin"
	DirAccess.make_dir_recursive_absolute(old)
	# The autoload's own OLD_USER_DIR is the player's real folder, which a
	# test must not touch; the move is exercised through its pieces.
	assert_eq(SkinPack.OLD_USER_DIR, "user://skin")
	assert_eq(SkinPack.USER_DIR, "user://skins")
	DirAccess.copy_absolute(ART, old + "/cardart.zip")
	assert_eq(DirAccess.rename_absolute(old + "/cardart.zip", SkinPack.user_zip("cardart")), OK,
		"a rename inside user:// is what _migrate does")
	assert_true(FileAccess.file_exists(PACKS + "/cardart.zip"))


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
	var kept := SkinPack.USER_DIR + "/probe.zip"
	assert_true(FileAccess.file_exists(kept), "copied into the skins folder, under its own name")
	assert_has(SkinPack.mounted, kept)
	assert_eq(String(Settings.get_value(GamePaths.KEY_SKIN_ZIP, "")), kept,
		"and the key names it, so it is the one worn from now on")
	assert_eq(SkinPack.own_skin_zip(), kept)
	assert_eq(String(SkinPack.describe("skin")["source"]), "yours")
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
	assert_true(FileAccess.file_exists(PACKS + "/art.zip"),
		"kept in the card folder under its own name, by what it holds")
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP), "not as the skin")
	assert_has(SkinPack.mounted, PACKS + "/art.zip")
	assert_true(SkinPack.has_own())
	assert_eq(String(SkinPack.describe("cardart")["source"]), "yours")
	assert_false(Settings.has_value(GamePaths.KEY_SKIN_ZIP), "a card pack needs no key")
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
	DirAccess.copy_absolute(GOOD, SkinPack.USER_DIR + "/other.zip")
	DirAccess.copy_absolute(ART, SkinPack.user_zip("cardart"))
	Settings.set_value(GamePaths.KEY_SKIN_ZIP, SkinPack.USER_DIR + "/other.zip")
	assert_true(SkinPack.has_own())
	assert_eq(SkinPack.own_zips().size(), 3, "both folders, every zip")
	var told := [0]   # a lambda captures a number by value, an array by reference
	var count := func(_kind: String) -> void:
		told[0] += 1
	SkinPack.changed.connect(count)
	SkinPack.forget()
	SkinPack.changed.disconnect(count)
	assert_false(FileAccess.file_exists(SkinPack.USER_ZIP))
	assert_false(FileAccess.file_exists(SkinPack.USER_DIR + "/other.zip"))
	assert_false(FileAccess.file_exists(SkinPack.user_zip("cardart")))
	assert_false(SkinPack.has_own())
	assert_false(Settings.has_value(GamePaths.KEY_SKIN_ZIP), "the key goes with the zip")
	assert_eq(told[0], 1, "the rows are told once")
	assert_not_null(SkinPack.notice())
	if SkinPack.notice() != null:
		assert_not_null(SkinPack.notice().find_child("Restart", true, false),
			"what is mounted stays mounted this run")


func test_a_forgotten_zip_is_worn_until_the_restart_and_the_row_says_so() -> void:
	var pack := SkinPack.user_zip("cardart")
	DirAccess.copy_absolute(ART, pack)
	assert_true(SkinPack.mount(pack, true))
	assert_eq(String(SkinPack.describe("cardart")["source"]), "yours")
	SkinPack.forget()
	assert_has(SkinPack.mounted, pack, "still mounted this run")
	assert_eq(String(SkinPack.describe("cardart")["source"]), "forgotten",
		"the file is gone, the mount is not — the row must not say 'your own'")


## A card folder the player pointed OUTSIDE the game's home is theirs:
## its packs are worn, but "Forget my zips" does not delete them.
func test_forgetting_leaves_a_card_folder_outside_the_games_home_alone() -> void:
	var theirs := ProjectSettings.globalize_path(SCRATCH).path_join("theirs")
	DirAccess.make_dir_recursive_absolute(theirs)
	Settings.set_value(GamePaths.KEY_CARDPACKS, theirs)
	assert_eq(SkinPack.cardpacks().size(), 0)
	DirAccess.copy_absolute(ART, theirs.path_join("keep.zip"))
	assert_eq(SkinPack.cardpacks(), [theirs.path_join("keep.zip")] as Array[String],
		"worn all the same")
	assert_false(SkinPack.has_own(), "but not the game's to delete")
	SkinPack.forget()
	assert_true(FileAccess.file_exists(theirs.path_join("keep.zip")))
	assert_null(SkinPack.notice())


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
## [method SkinPack.describe] can find. The owner, 2026-09-08: *"it
## should just say 'skin', point to skin zip in skins folder"* — the row
## names the zip by its path, and the card row names the folder and
## every pack in it.
func test_the_status_lines_say_what_dresses_the_game() -> void:
	assert_eq(SkinPack.status_line("skin", {"source": "none", "name": "", "files": 0}),
		"Skin: none — the game draws its own")
	assert_eq(SkinPack.status_line("skin",
		{"source": "yours", "name": "/home/me/.local/share/godot/app_userdata/Shandalar/skins/original_skin.zip",
		"files": 235}),
		"Skin: /home/me/.local/share/godot/app_userdata/Shandalar/skins/original_skin.zip — 235 files, your own")
	assert_eq(SkinPack.status_line("skin",
		{"source": "shipped", "name": "/opt/shandalar/skin/original_skin.zip", "files": 1}),
		"Skin: /opt/shandalar/skin/original_skin.zip — 1 file, shipped with the game")
	assert_eq(SkinPack.status_line("skin",
		{"source": "folder", "name": "/home/me/original_skin", "files": 236}),
		"Skin: a loose folder, /home/me/original_skin — 236 files")
	assert_eq(SkinPack.status_line("skin",
		{"source": "missing", "name": "/home/me/original_skin", "files": 0}),
		"Skin: none — /home/me/original_skin is not there; the game draws its own")
	assert_eq(SkinPack.status_line("skin",
		{"source": "forgotten", "name": "/x/skins/original_skin.zip", "files": 2}),
		"Skin: /x/skins/original_skin.zip — 2 files, forgotten, worn until the restart")
	var folder := "/home/me/.local/share/godot/app_userdata/Shandalar/cardpacks"
	assert_eq(SkinPack.status_line("cardart",
		{"source": "none", "name": "", "files": 0, "folder": folder, "packs": []}),
		"Card folder: %s — no card pack yet; cards show a plain art window" % folder)
	assert_eq(SkinPack.status_line("cardart",
		{"source": "folder", "name": "/dev/assets/cardart", "files": 0, "folder": folder, "packs": []}),
		"Card folder: %s — no card pack; a loose folder, /dev/assets/cardart" % folder)
	assert_eq(SkinPack.status_line("cardart",
		{"source": "yours", "name": "cardart.zip", "files": 1795, "folder": folder, "packs": [
			{"name": "cardart.zip", "files": 1795, "source": "yours"},
			{"name": "more.zip", "files": 1, "source": "forgotten"},
			{"name": "cardart.zip", "files": 1795, "source": "shipped"}]}),
		"Card folder: %s — cardart.zip (1795 pictures, your own); " % folder
		+ "more.zip (1 picture, forgotten, worn until the restart); "
		+ "cardart.zip (1795 pictures, shipped with the game)")


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
	assert_eq(String(SkinPack.describe("skin")["name"]), GamePaths.shown(GOOD),
		"named by a path a player can open")


## The card row lists every mounted pack, in precedence order, and
## names the card folder whatever is in it.
func test_the_card_row_names_the_folder_and_every_pack() -> void:
	var about := SkinPack.describe("cardart")
	assert_eq(String(about["folder"]), GamePaths.shown(PACKS))
	var before: int = about["packs"].size()
	DirAccess.copy_absolute(ART, PACKS + "/zz_probe_pack.zip")
	assert_true(SkinPack.mount(PACKS + "/zz_probe_pack.zip", true))
	about = SkinPack.describe("cardart")
	assert_eq(about["packs"].size(), before + 1)
	assert_eq(about["packs"][0], {"name": "zz_probe_pack.zip", "files": 1, "source": "yours"},
		"a replacing mount goes to the front")
	assert_eq(String(about["source"]), "yours")
	assert_string_contains(SkinPack.status_line("cardart", about),
		"zz_probe_pack.zip (1 picture, your own)")


## Options > Skin > "Use the skin folder instead of the zip": with the
## key on and no zip mounted, the row names the folder — or says it is
## not there. The owner: *"(The user wants to use this and not zip!)"*
func test_the_skin_folder_instead_of_the_zip_is_what_the_row_says() -> void:
	if not SkinPack.mounted.is_empty():
		pass_test("a zip is mounted for the run; the folder rows are pinned in test_options_skin")
		return
	Settings.set_value(GamePaths.KEY_USE_SKIN_FOLDER, true)
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SCRATCH + "/no_such_folder")
	var about := SkinPack.describe("skin")
	if DirAccess.dir_exists_absolute(ProjectSettings.globalize_path("res://assets/original")):
		assert_eq(String(about["source"]), "folder", "a checkout's own folder is still found")
	else:
		assert_eq(String(about["source"]), "missing")
		assert_eq(String(about["name"]), GamePaths.shown(SCRATCH + "/no_such_folder"))
	Settings.set_value(GamePaths.KEY_SKIN_FOLDER, SCRATCH)
	about = SkinPack.describe("skin")
	assert_eq(String(about["source"]), "folder")
	assert_eq(String(about["name"]), GamePaths.shown(SCRATCH))
	assert_eq(int(about["files"]), SkinPack.files_at(SCRATCH), "the probes lie flat in it")
	assert_true(int(about["files"]) >= 7)


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
