class_name SkinInstallCheck
extends RefCounted
## WHAT A FOLDER IS, BEFORE ANYTHING IS BUILT FROM IT — the in-game
## `--check` of `tools/mtg_assets.py` and `tools/import_original.py`: the
## same landmarks ([constant SkinRecipes.LANDMARKS]) and the same count of
## files the game reads, said in a few plain lines for the skin builder's
## window ([SkinBuilderWindow]).
##
## It looks at names, and at the first eight bytes of each picture (a PNG
## under a 1997 name is a later remake's and is not counted); nothing is
## decoded, so a file counted here can still fail to decode in the build,
## which then leaves it out and says so. Pure functions on an index that
## is done ([SkinSourceIndex]).
##
## A CD IMAGE is checked like a folder ([SkinIsoImage]; the owner,
## 2026-11-23: *"Yes choose iso add it."*) and called what it is. A disc
## may keep some of the game packed inside its installer, which the game
## cannot unpack: when an image, or a CD's folder, has the game's
## landmarks but under half the skin's files, the report says so and asks
## for the installed folder as well ([constant PACKED]).

## What the folders are.
const INSTALL := "install"
const CD := "cd"
const IMAGE := "image"
const PARTIAL := "partial"
const NOTHING := "nothing"
## Names only a CD's top holds.
const CD_MARKS: Array[String] = ["autorun.inf", "setup.exe"]

const HEADLINES := {
	INSTALL: "This is an installed copy of the 1997 game.",
	CD: "This looks like the 1997 game's CD.",
	IMAGE: "This is a CD image of the 1997 game.",
	PARTIAL: "Part of the 1997 game is here, but not its program (Shandalar.exe or Magic.exe).",
	NOTHING: "This is not a copy of the 1997 game: none of its files were found here.",
}
const NOT_AN_IMAGE := "This is not a CD image of the 1997 game: none of its files were found in it."
## Said of a disc that gives far fewer files than an installed game does.
const PACKED := "Some of the game's files may be packed inside the CD's installer; the game cannot unpack those. Install the game and add its folder too."


## The landmark groups found under [param source] ("" for every folder
## walked): group -> whether any of its names is there.
static func landmarks(index: SkinSourceIndex, source := "") -> Dictionary:
	var out := {}
	for group: String in SkinRecipes.LANDMARKS:
		out[group] = false
		for name: String in SkinRecipes.LANDMARKS[group]:
			if index.has_name(name, source):
				out[group] = true
				break
	return out


## Whether [param source], one of the folders walked, holds any landmark.
static func is_copy(index: SkinSourceIndex, source: String) -> bool:
	return landmarks(index, source).values().has(true)


## The whole report: `{kind, buildable, headline, found, lacking, files,
## files_wanted, portraits, portraits_wanted, screens, screens_wanted,
## movies, later_art, later_sounds, strangers, images, packed, lines}` —
## `images` how many of the sources are CD images, `packed` whether the
## disc seems to keep files in its installer ([constant PACKED]), `found` and
## `lacking` the landmark groups, `files` how many of the skin files the
## game reads have a 1997 file to come from, `strangers` the folders that
## hold no landmark at all, `lines` the report in the player's words.
static func survey(index: SkinSourceIndex) -> Dictionary:
	var marks := landmarks(index)
	var found: Array[String] = []
	var lacking: Array[String] = []
	for group: String in marks:
		if marks[group]:
			found.append(group)
		else:
			lacking.append(group)
	var strangers: Array[String] = []
	for source in index.sources:
		if not is_copy(index, source):
			strangers.append(source)
	strangers.append_array(index.not_folders)

	var planned := SkinBuildJob.plan(index)
	var have := {}
	var portraits := 0
	var screens := 0
	for task: Dictionary in planned["tasks"]:
		match String(task["kind"]):
			"texture", "copy":
				if bool(task["manifest"]):
					have[task["key"]] = true
				elif String(task["kind"]) == "texture" \
						and not SkinRecipes.SCREENS_NOT_READ.has(task["key"]):
					screens += 1
			"face":
				portraits += 1
			"rogue":
				if int(task["slot"]) >= 1 and int(task["slot"]) <= SkinRecipes.ROGUE_NAMES.size():
					portraits += 1
			"portraits":
				portraits += _faces_in(index, String(task["path"]))
	for key: String in SkinRecipes.PIC_SHEETS:
		var whole := true
		for cell: String in SkinRecipes.PIC_SHEETS[key][0]:
			if index.find(cell) == "":
				whole = false
				break
		if whole and index.first_of(SkinRecipes.PIC_PALETTE) != "":
			have[key] = true
	for key: String in SkinRecipes.DERIVED_SHEETS:
		if have.has(SkinRecipes.DERIVED_SHEETS[key][0]):
			have[key] = true
	var files := 0
	for key: String in have:
		if not SkinRecipes.NOT_READ.has(key):
			files += 1
	var files_wanted: int = SkinRecipes.MANIFEST.size() - SkinRecipes.NOT_READ.size()
	var screens_wanted: int = SkinRecipes.PIC_SCREENS.size() - SkinRecipes.SCREENS_NOT_READ.size()
	var movies := (planned["left_out"] as Array).size()

	var kind := NOTHING
	if not found.is_empty():
		kind = PARTIAL
		if index.first_of(SkinRecipes.CARD_TABLE_PROGRAMS) != "":
			kind = INSTALL
		for mark in CD_MARKS:
			if index.has_name(mark):
				kind = CD
		# Nothing but images: that is what it is, whatever is on it.
		if index.images.size() == index.sources.size():
			kind = IMAGE
	var buildable := kind != NOTHING and (files + portraits + screens) > 0
	var only_images := not index.sources.is_empty() and index.images.size() == index.sources.size()
	var packed := (kind == IMAGE or kind == CD) and files * 2 < files_wanted
	var headline := String(HEADLINES[kind])
	if kind == NOTHING and only_images:
		headline = NOT_AN_IMAGE

	var lines: Array[String] = [headline]
	if kind != NOTHING:
		lines.append("Found: %s." % ", ".join(PackedStringArray(found)))
		if not lacking.is_empty():
			lines.append("Not found: %s. The game draws those parts itself."
				% ", ".join(PackedStringArray(lacking)))
		lines.append("It can give %d of the %d skin files the game uses, %d of %d portraits and %d of %d adventure pictures."
			% [files, files_wanted, portraits, SkinRecipes.PORTRAITS_WANTED, screens, screens_wanted])
		var later := (planned["refused_png"] as Array).size() + (planned["refused_program"] as Array).size()
		if later > 0:
			lines.append("%d file%s here come%s from a later remake, not the 1997 game, and will not be used."
				% [later, "" if later == 1 else "s", "s" if later == 1 else ""])
		if movies > 0:
			lines.append("The coin-toss and ending movies will be left out: the game cannot convert them. The Python tool that comes with the game (tools/mtg_assets.py; setup.txt, section 5) makes the complete skin with both.")
		if packed:
			lines.append(PACKED)
	var past_end := 0
	for source: String in index.images:
		past_end += (index.images[source] as SkinIsoImage).damaged
	if past_end > 0:
		lines.append("The image is cut short: %d of its files lie past its end and cannot be read."
			% past_end)
	if index.cut_short:
		lines.append("The %s is very large: only its first %d files were looked at."
			% ["image" if only_images else "folder", index.file_count])
	return {"kind": kind, "buildable": buildable, "headline": headline,
		"images": index.images.size(), "packed": packed,
		"found": found, "lacking": lacking, "files": files, "files_wanted": files_wanted,
		"portraits": portraits, "portraits_wanted": SkinRecipes.PORTRAITS_WANTED,
		"screens": screens, "screens_wanted": screens_wanted, "movies": movies,
		"later_art": (planned["refused_png"] as Array).size(),
		"later_sounds": (planned["refused_program"] as Array).size(),
		"strangers": strangers, "lines": lines}


## How many frames of a face's size the sprite file at [param path] holds,
## by its frame headers alone.
static func _faces_in(index: SkinSourceIndex, path: String) -> int:
	var data: PackedByteArray = index.read(path, SkinBuildJob.MAX_ART_FILE)["bytes"]
	var count := 0
	var offset := 0
	var frames := 0
	while offset + 16 <= data.size() and frames < SkinSprCodec.MAX_FRAMES:
		var size := data.decode_u32(offset)
		if size == SkinSprCodec.END or size < 16:
			break
		if data.decode_u16(offset + 4) == int(SkinRecipes.PORTRAIT_CELL[0]) \
				and data.decode_u16(offset + 6) == int(SkinRecipes.PORTRAIT_CELL[1]):
			count += 1
		offset += size
		frames += 1
	return count
