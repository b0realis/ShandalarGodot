class_name SaveSlots
extends RefCounted
## THE SAVE SLOTS (the owner, 2026-10-23: *"Add 10 named slots"*) — 1997's
## ten named save files beside the autosave (1.3 `SaveGameToSlot`,
## adventure_save.c 31; `RunLoadSaveMenu`, openingMenu.c 1614): slot 3 was
## the autosave ("Resume Game"), slots 4–13 the ten the player named.
##
## OURS, PER ADVENTURE: `<id>.autosave.json` — written when the adventure
## begins, on leaving a town or any place, before and after a lair, and as
## the hero quits — and `<id>.slot01.json` … `<id>.slot10.json`, each
## carrying its own name (`adventure.slot_name`; 1997 kept the names in a
## file of their own, `saveDescs`, which could fall out of step with the
## saves). A slot is saved into from [SaveSlotsPane], loaded from
## [LoadAdventureScreen]. A save written by an older version as
## `<id>.save.json` becomes the first free slot, "Saved game" ([method
## migrate]). Each save keeps its last good version beside it as `.bak`
## ([method AdventurePlayer.save]).

const SLOTS := 10
const EMPTY := "(Empty)"
## A slot whose file is there but cannot be read (damaged, or from a newer
## version of the game): not empty — saving into it replaces the file.
const DAMAGED := "(Cannot be read)"
const LEGACY := "save"
const LEGACY_NAME := "Saved game"


## A slot's file kind: "slot01" … "slot10".
static func kind(slot: int) -> String:
	return "slot%02d" % clampi(slot, 1, SLOTS)


## The slot of a file kind, 0 for the autosave or none.
static func slot_of(file_kind: String) -> int:
	return int(file_kind.trim_prefix("slot")) if file_kind.begins_with("slot") else 0


## The file of slot [param slot] of adventure [param id] in [param folder].
static func path_of(id: String, slot: int, folder: String) -> String:
	return folder.path_join("%s.%s.json" % [id, kind(slot)])


## THE SLOTS OF ADVENTURE [param id]: ten `{slot, path, name, saved, empty,
## damaged}` — the empty ones "(Empty)", one whose file cannot be read
## "(Cannot be read)".
##
## The ten files are read by their own names (campaign of 2026-10-23: the
## slots were picked out of a list of every save in the folder — one odd
## file there showed all ten "(Empty)", so a slot was saved over unseen,
## and a copy of a slot's file could take its row); and a file is parsed
## only when its bytes changed ([method AdventurePlayer.save_at]).
static func slots_of(id: String, folder := "") -> Array[Dictionary]:
	if folder == "":
		folder = AdventurePlayer.saves_folder
	migrate(folder)
	var out: Array[Dictionary] = []
	for slot in range(1, SLOTS + 1):
		var path := path_of(id, slot, folder)
		var save := AdventurePlayer.save_at(path)
		var row := {"slot": slot, "path": path, "name": EMPTY, "saved": "", "empty": save.is_empty(),
			"damaged": bool(save.get("unreadable", false))}
		if row["damaged"]:
			row["name"] = DAMAGED
		elif not save.is_empty():
			row["name"] = String(save["slot_name"])
			row["saved"] = String(save["saved"])
		out.append(row)
	return out


## SAVE [param player] into slot [param slot] (1–10) by the name
## [param slot_name] (a day and a place when it is blank): the path
## written, or "".
static func save_into(player: AdventurePlayer, slot: int, slot_name: String) -> String:
	var called := slot_name.strip_edges()
	if called == "" or called == EMPTY or called == DAMAGED:
		called = default_name(player)
	player.slot_name = called
	return player.save(player.save_path(kind(slot)))


## A blank slot's name: "Day 12 near Kraag Temple".
static func default_name(player: AdventurePlayer) -> String:
	var near := ""
	var best := 0x7FFF
	var hero := player.tile()
	for slot in player.world.sites.size():
		var site: Dictionary = player.world.sites[slot]
		if int(site["type"]) <= 0:
			continue
		var distance := WorldGenerator.distance(int(site["x"]) - hero.x, int(site["y"]) - hero.y)
		if distance < best:
			best = distance
			near = WorldNames.site_name(player.world, slot)
	return "Day %d near %s" % [WorldStatus.days_on_road(player), near] if near != "" \
		else "Day %d" % WorldStatus.days_on_road(player)


## The first slot of adventure [param id] with no file (nor a `.bak`), 0
## when all ten are taken.
static func first_free(id: String, folder: String) -> int:
	for slot in range(1, SLOTS + 1):
		var path := path_of(id, slot, folder)
		if not FileAccess.file_exists(path) and not FileAccess.file_exists(AdventurePlayer.backup_path(path)):
			return slot
	return 0


## AN OLDER SAVE (`<id>.save.json`, before the slots) becomes the first
## free slot of its adventure — slot 1 unless it is taken — named "Saved
## game". The old file goes only once its slot is written and read back
## whole (campaign of 2026-10-23: it went whatever happened — when it could
## not be read, when the slot's write failed, and when slot 1 was taken,
## so the older adventure was lost). One that cannot be read (damaged, or
## from a newer version), or with all ten slots taken, is left as it is;
## a write that failed is tried again on the next look.
static func migrate(folder: String) -> void:
	var dir := DirAccess.open(folder)
	if dir == null:
		return
	for file_name in dir.get_files():
		if not file_name.ends_with("." + LEGACY + ".json"):
			continue
		var old := folder.path_join(file_name)
		if AdventurePlayer.save_at(old).get("unreadable", false):
			continue
		var player := AdventurePlayer.load_from(old)
		var id := file_name.trim_suffix("." + LEGACY + ".json")
		var slot := first_free(id, folder)
		if player == null or slot == 0:
			continue
		player.slot_name = LEGACY_NAME
		if player.save(path_of(id, slot, folder)) != "":
			DirAccess.remove_absolute(old)
