class_name AdventurePlugins
extends RefCounted
## ADVENTURE PLUGINS — THE REGISTRY (adventure plugins, 2026-11-10; the
## owner: *"The expanded adventure … will be a small package players can
## download and plugin to the vanilla shandalar adventure game … found in
## 'expanded_adventure' folder in game folder where also card packs reside.
## Player can tick/enable individual adventure plugins"*).
##
## A plugin is DATA ONLY — JSON, text, pictures, music — found in an
## `expanded_adventure/` folder ([method folders]) as a `.zip` or an
## unpacked folder. Nothing in a plugin is ever loaded as a resource, run as
## a script or mounted: its files are read as bytes ([PluginPackage]) and
## decoded from buffers ([method texture], [method stream]), and every
## behaviour is the res:// interpreter [DataRegion] reading the data
## [PluginSchema] validated.
##
## WHERE, in order, the first copy of an id winning (a later one is listed
## in the winner's `shadowed`, never read further):
##  1. [method GamePaths.expanded_adventure_folder] (`expanded_adventure_folder`
##     in settings.cfg; `user://expanded_adventure` by default);
##  2. `expanded_adventure/` beside the game (on Android, in the app's
##     corner of the shared storage, as the card packs);
##  3. in a development run (not an exported game): the repository's own
##     `res://expanded_adventure/` (it carries a `.gdignore` and is not
##     exported) and `../shandalar-packs/expanded_adventure/`.
## In each folder every `.zip` and every subfolder holding `plugin.json`,
## by name; anything else there (the guide, a README) is passed over.
##
## THE CHECKS, in stages; the first stage with a problem refuses the plugin
## and the later ones are not run (the plugin tool runs the same stages):
##  1. the package ([method PluginPackage.read]: paths, kinds, limits);
##  2. the manifest, `plugin.json` ([method manifest_problems]);
##  3. its `files` list, when it has one ([method integrity_problems]);
##  4. the content ([method PluginSchema.read], card names included).
## A refused plugin is still a row of [method all], with its problems, so
## the Embark's list can say why.
##
## Scanned once, on first use; [method scan] again rescans (the Embark's
## list). [member revision] counts the scans.

## The plugin API this game reads. A plugin asking for a newer one is refused.
## API 2 (2026-11-21) brings the sites plugins ([constant KIND_SITES]):
## places of their own on the mainland and on other plugins' islands; every
## API 1 plugin reads as before.
const API_VERSION := 2
## A plugin's kind (the manifest's `kind`, API 2): an island reached by ship
## ([constant KIND_ISLAND], the default and API 1's only kind), or places that
## stand on the lands a campaign has ([constant KIND_SITES], [AdventureSites]).
const KIND_ISLAND := "island"
const KIND_SITES := "sites"
const KINDS: Array[String] = [KIND_ISLAND, KIND_SITES]
## The first API a sites plugin may declare.
const SITES_API := 2
## The manifest's own format.
const PLUGIN_FORMAT := 1
## The folder's name, beside the game and in the repository.
const FOLDER_NAME := "expanded_adventure"
## A plugin's id: lower-case letters, digits and `_`, a letter first, at
## most 40; never a region the game has itself.
const ID_PATTERN := "^[a-z][a-z0-9_]{0,39}$"
const RESERVED_IDS: Array[String] = ["mainland"]
## The manifest's fields: those a plugin must give, and every one it may.
## `region` is required of an island alone ([method manifest_problems]).
const REQUIRED_FIELDS: Array[String] = ["plugin_format", "api_version", "id", "name", "version",
	"authors", "description", "region"]
const FIELDS: Array[String] = ["plugin_format", "api_version", "kind", "id", "name", "version",
	"minimum_game_version", "authors", "license", "description", "learning_note", "requires",
	"region", "files"]
const REGION_FIELDS: Array[String] = ["title", "castle_name", "salt", "mana_links", "palette"]
## The longest a manifest's words may be (a line of the Embark's list, a
## name, the learning note and the license).
const MAX_NAME := 100
const MAX_LINE := 300
const MAX_TEXT := 4000
const MAX_AUTHORS := 16
const MAX_PACKS := 16

## Bumped whenever the set of plugins or their data changes (a rescan).
static var revision := 0
## [Tests] When not empty, the only folders searched ([method folders]).
static var folders_override: Array[String] = []
## [Tests] The content stage ([method PluginSchema.read]'s signature) when
## valid: a test of the loader's own stages stands in for the schema; its
## answer's `descriptor` stands in for [method PluginSchema.descriptor].
static var content_reader: Callable = Callable()

static var _scanned := false
static var _rows: Array[Dictionary] = []
## id -> {row, manifest, data, descriptor, path, kind, top, hashes}
static var _plugins := {}
static var _textures := {}
static var _streams := {}


## THE FOLDERS SEARCHED, in order ([member folders_override] when a test
## set it): each once, by where it is on the disk.
static func folders() -> Array[String]:
	var out: Array[String] = []
	if not folders_override.is_empty():
		out.assign(folders_override)
		return out
	var places: Array[String] = [GamePaths.expanded_adventure_folder()]
	var beside := GamePaths.android_files_dir()
	if beside == "":
		beside = GamePaths.executable_dir(OS.get_executable_path(), OS.has_feature("macos"))
	places.append(beside.path_join(FOLDER_NAME))
	if not OS.has_feature("standalone"):
		places.append("res://" + FOLDER_NAME)
		var checkout := ProjectSettings.globalize_path("res://").trim_suffix("/")
		places.append(checkout.get_base_dir().path_join("shandalar-packs").path_join(FOLDER_NAME))
	var seen := {}
	for place in places:
		var key := ProjectSettings.globalize_path(place).simplify_path()
		if seen.has(key):
			continue
		seen[key] = true
		out.append(place)
	return out


## Search the plugin folders again and rebuild the registry. Pictures and
## tunes decoded before are let go.
static func scan() -> void:
	_rows.clear()
	_plugins.clear()
	_textures.clear()
	_streams.clear()
	for folder in folders():
		for candidate in candidates(folder):
			_add(candidate)
	_scanned = true
	revision += 1
	AdventureExpansions.refresh()


## The plugins in [param folder] to look at: its `.zip` files and its
## subfolders holding `plugin.json`, by name.
static func candidates(folder: String) -> Array[String]:
	var out: Array[String] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.include_hidden = false
	var names: Array[String] = []
	names.assign(dir.get_files())
	names.sort()
	for name in names:
		if name.get_extension().to_lower() == "zip" and not PluginPackage.ignored(name):
			out.append(folder.path_join(name))
	names.assign(dir.get_directories())
	names.sort()
	for name in names:
		if not PluginPackage.ignored(name) and FileAccess.file_exists(folder.path_join(name).path_join(PluginPackage.MANIFEST)):
			out.append(folder.path_join(name))
	return out


static func _ensure() -> void:
	if not _scanned:
		scan()


## Every plugin found, valid or not, in the order found: rows `{id, name,
## version, api, path, kind ("zip"/"folder"), description, authors, license,
## learning_note, requires, problems: Array[String], shadowed: Array[String],
## pack_status}` — `pack_status` the card packs it needs as they stand now
## ([method pack_status]). Copies: changing one changes nothing here.
static func all() -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	for row in _rows:
		var copy: Dictionary = row.duplicate(true)
		# The packs as they stand now, not as they stood at the scan.
		copy["pack_status"] = pack_status(String(row["id"])) if String(row["id"]) != "" \
			and _plugins.has(String(row["id"])) and _plugins[String(row["id"])]["row"] == row else ([] as Array[Dictionary])
		out.append(copy)
	return out


## The ids of every valid plugin, in the order found.
static func ids() -> Array[String]:
	_ensure()
	var out: Array[String] = []
	for row in _rows:
		if valid(String(row["id"])):
			out.append(String(row["id"]))
	return out


## Whether [param id] is an installed plugin that passed every check.
static func valid(id: String) -> bool:
	_ensure()
	return _plugins.has(id) and (_plugins[id]["row"]["problems"] as Array).is_empty()


## [param id]'s row of [method all] (a copy), {} when none was found.
static func row(id: String) -> Dictionary:
	_ensure()
	return (_plugins[id]["row"] as Dictionary).duplicate(true) if _plugins.has(id) else {}


## Why [param id] is refused: its first problem, "" when it is valid or
## was never found.
static func refusal(id: String) -> String:
	_ensure()
	if not _plugins.has(id):
		return ""
	var problems: Array = _plugins[id]["row"]["problems"]
	return String(problems[0]) if not problems.is_empty() else ""


## [param id]'s manifest as read, {} when it is unknown or invalid.
static func manifest(id: String) -> Dictionary:
	return _plugins[id]["manifest"] if valid(id) else {}


## [param id]'s normalized content ([method PluginSchema.read]'s `data`),
## {} when unknown or invalid.
static func data(id: String) -> Dictionary:
	return _plugins[id]["data"] if valid(id) else {}


## [param id]'s descriptor in the shape [AdventureExpansions] reads
## ([method PluginSchema.descriptor], the manifest's word where the schema
## gives none), {} when unknown or invalid.
static func descriptor(id: String) -> Dictionary:
	return _plugins[id]["descriptor"] if valid(id) else {}


## The card packs [param id] needs, by id, in the manifest's order ([] for
## a plugin never found).
static func pack_ids(id: String) -> Array[String]:
	_ensure()
	var out: Array[String] = []
	if not _plugins.has(id):
		return out
	for need: Variant in (_plugins[id]["row"]["requires"] as Dictionary).get("card_packs", []):
		if need is Dictionary and need.get("id") is String:
			out.append(String(need["id"]))
	return out


## THE CARD PACKS PLUGIN [param id] NEEDS, AS THIS COMPUTER HAS THEM NOW,
## in the manifest's order: `{id, title, min_version, installed, version,
## new_enough, enabled}` — `version` the installed pack's ("" when it is not
## installed), `new_enough` false only for an installed pack older than the
## plugin's `min_version` (compared as the game compares pack versions,
## `CardPacks._version_less`). A pack too old refuses nothing — the plugin is
## whole — but its ships do not sail ([method AdventureExpansions.enabled]),
## as for a pack missing or off. [] for a plugin never found.
static func pack_status(id: String) -> Array[Dictionary]:
	_ensure()
	var out: Array[Dictionary] = []
	if not _plugins.has(id):
		return out
	var service := AdventureExpansions.packs()
	for need: Variant in (_plugins[id]["row"]["requires"] as Dictionary).get("card_packs", []):
		if not need is Dictionary:
			continue
		var pack := String(need.get("id", ""))
		var least := String(need.get("min_version", ""))
		var installed: bool = service != null and service.has_pack(pack)
		var info: Dictionary = service.info(pack) if installed else {}
		var version := String(info.get("version", ""))
		out.append({"id": pack, "title": AdventurePacks.title(pack), "min_version": least, "installed": installed,
			"version": version, "new_enough": least == "" or not installed or not _pack_older(service, version, least),
			"enabled": service != null and service.is_enabled(pack)})
	return out


## Whether pack version [param version] is older than [param least], as the
## card packs compare their own (`CardPacks._version_less`, found through the
## service: this file is model-side).
static func _pack_older(service: Node, version: String, least: String) -> bool:
	if service != null and service.has_method(&"_version_less"):
		return bool(service.call(&"_version_less", version, least))
	return compare_versions(version, least) < 0


## The picture at [param rel] inside plugin [param id], decoded from its
## bytes and cached; null when absent, changed since the scan, or not a
## picture.
static func texture(id: String, rel: String) -> Texture2D:
	var key := id + "/" + rel
	if _textures.has(key):
		return _textures[key]
	var image := _image_of(rel, _bytes(id, rel))
	var out: Texture2D = ImageTexture.create_from_image(image) if image != null else null
	if out != null:
		# Its painted part, measured on the pixels just decoded: a marker on
		# the world is cut to it ([method AdventureSites.map_op]), and
		# asking the texture for its pixels again read them back off the
		# graphics card, stalling the frame a harbor first came into view
		# (the review of 2026-11-21).
		out.set_meta(USED_RECT, Rect2(image.get_used_rect()))
	_textures[key] = out
	return out


## The meta a plugin's texture carries its painted part under ([method
## texture]): a Rect2 in its own pixels.
const USED_RECT := &"used_rect"


## The picture [param bytes] hold, read as the kind their first bytes say
## (never as [param rel]'s name says); null for no picture. Touches nothing
## shared: [method texture] and a warm-up's worker ([method warm]) both
## decode here.
static func _image_of(rel: String, bytes: PackedByteArray) -> Image:
	if not rel.get_extension().to_lower() in PluginPackage.PICTURES or bytes.is_empty():
		return null
	var image := Image.new()
	var kind := PluginPackage.picture_kind(bytes)
	var made := ERR_FILE_UNRECOGNIZED
	if kind == "png":
		made = image.load_png_from_buffer(bytes)
	elif kind == "jpg":
		made = image.load_jpg_from_buffer(bytes)
	elif kind == "webp":
		made = image.load_webp_from_buffer(bytes)
	return image if made == OK and not image.is_empty() else null


## The looping OGG [param bytes] hold, null for none ([method stream], and
## a warm-up's worker).
static func _tune_of(rel: String, bytes: PackedByteArray) -> AudioStream:
	if rel.get_extension().to_lower() != "ogg" or not PluginPackage.is_vorbis(bytes):
		return null
	var ogg := AudioStreamOggVorbis.load_from_buffer(bytes)
	if ogg != null:
		ogg.loop = true
	return ogg


# ------------------------------------------------- warmed off the frame --

## How long a frame may spend keeping what a warm-up made (a texture from
## its decoded picture), and the most decoded pixels one warm-up makes —
## the rest are decoded as they are asked for, as before.
const WARM_BUDGET_US := 2000
const MOST_WARM_BYTES := 48 * 1024 * 1024

## One warm-up's work ([method warm]), shared with its worker as
## [SkinWarmer]'s rule has it (`lock`, `stop`, `started`): the worker reads
## only the private copies in its entries (a path, a name, a hash — no
## registry) and writes only into the entry in hand and [member done], under
## the lock; the main thread reads an entry once [member done] has passed it.
class WarmJob extends RefCounted:
	var entries: Array[Dictionary] = []
	var done := 0
	var stop := false
	var started := false
	var lock := Mutex.new()
	var revision := 0
	var task := -1
	var kept := 0
	var most := 0

	func run() -> void:
		lock.lock()
		started = true
		lock.unlock()
		var made := 0
		for entry in entries:
			lock.lock()
			var halt := stop
			lock.unlock()
			if halt:
				break
			var rel := String(entry["rel"])
			var bytes := PluginPackage.read_one(String(entry["path"]), String(entry["kind"]), String(entry["top"]), rel)
			if not bytes.is_empty() and PluginPackage.sha256(bytes) == String(entry["hash"]):
				if bool(entry["tune"]):
					entry["stream"] = AdventurePlugins._tune_of(rel, bytes)
				elif made < most:
					var image := AdventurePlugins._image_of(rel, bytes)
					if image != null:
						entry["image"] = image
						entry["used"] = Rect2(image.get_used_rect())
						made += image.get_width() * image.get_height() * 4
			lock.lock()
			done += 1
			lock.unlock()


## The warm-ups at work, what was asked for already (by key, the registry's
## revision it was asked in), what is still being made, and who waits for a
## tune (by key: callables). Main thread only.
static var _warming: Array[WarmJob] = []
static var _warm_asked := {}
static var _warm_pending := {}
static var _warm_then := {}
## How many pictures and tunes the warm-ups have kept (the tests).
static var warmed := 0


## PLUGIN [param id]'S PICTURES AND MUSIC MADE BEFORE THEY ARE ASKED FOR
## (the review of 2026-11-21: the first pane of a plugin's place opened, the
## first marker drawn and a land's track begun each read the plugin's
## archive, hashed and decoded on the thread that draws — tens of ms a
## picture, far more for a track on a handheld). With [param pictures],
## every picture file of the plugin; with [param tune], that OGG, ahead of
## the background work — and [param then] called once it is kept or given
## up. One worker task reads, checks (the scan's hash, as [method _bytes])
## and decodes; each frame the main thread keeps what is made for at most
## [constant WARM_BUDGET_US] where [method texture] and [method stream]
## look first. Nothing is lost when it is cut short or the plugins are
## scanned again meanwhile: what it did not keep is made on demand, as
## before. True when [param then] will be called — the tune is being made;
## false when nothing waits (kept already, not a tune of this plugin, or no
## worker may decode here: [method SkinWarmer.runs_here]).
static func warm(id: String, pictures := true, tune := "", then := Callable()) -> bool:
	if not valid(id) or not SkinWarmer.runs_here():
		return false
	var plugin: Dictionary = _plugins[id]
	var hashes: Dictionary = plugin["hashes"]
	var rels: Array[String] = []
	if tune != "" and hashes.has(tune) and tune.get_extension().to_lower() == "ogg":
		rels.append(tune)
	if pictures:
		for rel: String in hashes:
			if rel.get_extension().to_lower() in PluginPackage.PICTURES:
				rels.append(rel)
	var job := WarmJob.new()
	job.revision = revision
	job.most = MOST_WARM_BYTES
	var waits := false
	for rel in rels:
		var key := id + "/" + rel
		var is_tune := rel == tune
		if (_streams if is_tune else _textures).has(key):
			continue
		if int(_warm_asked.get(key, -1)) != revision:
			_warm_asked[key] = revision
			_warm_pending[key] = true
			job.entries.append({"key": key, "rel": rel, "tune": is_tune, "path": String(plugin["path"]),
				"kind": String(plugin["kind"]), "top": String(plugin["top"]), "hash": String(hashes[rel])})
		if is_tune and then.is_valid() and _warm_pending.has(key):
			if not _warm_then.has(key):
				_warm_then[key] = []
			(_warm_then[key] as Array).append(then)
			waits = true
	if job.entries.is_empty():
		return waits
	job.task = SkinWarmer.track(job, WorkerThreadPool.add_task(job.run, tune != "", "Adventure plugin warm-up"))
	_warming.append(job)
	var tree := Engine.get_main_loop() as SceneTree
	if tree != null and not tree.process_frame.is_connected(_keep_warm):
		tree.process_frame.connect(_keep_warm)
	return waits


## Whether the tune at [param rel] of plugin [param id] is decoded and kept.
static func stream_kept(id: String, rel: String) -> bool:
	return _streams.has(id + "/" + rel)


## What the warm-ups have made kept, a frame's share of it ([param all]:
## every warm-up waited for and all of it kept, now — a test).
static func _keep_warm(all := false) -> void:
	var began := Time.get_ticks_usec()
	for job: WarmJob in _warming.duplicate():
		if all:
			SkinWarmer.claim(job.task)
		var ended := WorkerThreadPool.is_task_completed(job.task) if not all else true
		job.lock.lock()
		var done := job.done
		job.lock.unlock()
		while job.kept < done:
			_keep_one(job, job.entries[job.kept])
			job.kept += 1
			if not all and Time.get_ticks_usec() - began >= WARM_BUDGET_US:
				return
		if ended:
			# What it never reached (told to stop) is given up: made on demand.
			while job.kept < job.entries.size():
				_keep_one(job, job.entries[job.kept])
				job.kept += 1
			if not all:
				SkinWarmer.release(job, job.task)
			_warming.erase(job)
	if _warming.is_empty():
		var tree := Engine.get_main_loop() as SceneTree
		if tree != null and tree.process_frame.is_connected(_keep_warm):
			tree.process_frame.disconnect(_keep_warm)


## One entry of a warm-up kept where [method texture] and [method stream]
## look — unless the plugins were scanned again since it was asked, or the
## thing was made on demand meanwhile — and whoever waited for it told.
static func _keep_one(job: WarmJob, entry: Dictionary) -> void:
	var key := String(entry["key"])
	_warm_pending.erase(key)
	if job.revision == revision:
		if bool(entry["tune"]):
			if entry.get("stream") != null and not _streams.has(key):
				_streams[key] = entry["stream"]
				warmed += 1
		elif entry.get("image") != null and not _textures.has(key):
			var made := ImageTexture.create_from_image(entry["image"])
			made.set_meta(USED_RECT, entry["used"])
			_textures[key] = made
			warmed += 1
	entry.erase("image")
	entry.erase("stream")
	var waiting: Array = _warm_then.get(key, [])
	_warm_then.erase(key)
	for then: Callable in waiting:
		if then.is_valid():
			then.call()


## The OGG music at [param rel] inside plugin [param id], decoded from its
## bytes, set to loop, cached; null when absent or changed since the scan.
static func stream(id: String, rel: String) -> AudioStream:
	var key := id + "/" + rel
	if _streams.has(key):
		return _streams[key]
	var out := _tune_of(rel, _bytes(id, rel))
	_streams[key] = out
	return out


## The bytes of [param rel] of valid plugin [param id], read again and held
## to the hash the scan took: empty when they are not the same bytes.
static func _bytes(id: String, rel: String) -> PackedByteArray:
	if not valid(id):
		return PackedByteArray()
	var plugin: Dictionary = _plugins[id]
	var hashes: Dictionary = plugin["hashes"]
	if not hashes.has(rel):
		return PackedByteArray()
	var bytes := PluginPackage.read_one(String(plugin["path"]), String(plugin["kind"]), String(plugin["top"]), rel)
	if bytes.is_empty() or PluginPackage.sha256(bytes) != String(hashes[rel]):
		return PackedByteArray()
	return bytes


# ------------------------------------------------------------ the scan --

static func _row(path: String, kind: String) -> Dictionary:
	var problems: Array[String] = []
	var shadowed: Array[String] = []
	var authors: Array[String] = []
	return {"id": "", "name": path.get_file().get_basename() if kind == "zip" else path.get_file(),
		"version": "", "api": 0, "path": path, "kind": kind, "plugin_kind": KIND_ISLAND, "description": "", "authors": authors,
		"license": "", "learning_note": "", "requires": {"card_packs": []}, "problems": problems,
		"shadowed": shadowed}


## One plugin of a folder read, checked and filed (or its path listed as
## shadowed by the copy found first).
static func _add(path: String) -> void:
	var read := PluginPackage.read(path)
	var row := _row(path, String(read["kind"]))
	var problems: Array[String] = row["problems"]
	var files: Dictionary = read["files"]
	var parsed: Variant = null
	if files.has(PluginPackage.MANIFEST):
		var json := PluginPackage.json(PluginPackage.MANIFEST, files[PluginPackage.MANIFEST])
		parsed = json["value"]
		if String(json["problem"]) != "" and (read["problems"] as Array).is_empty():
			problems.append(String(json["problem"]))
	var manifest: Dictionary = parsed if parsed is Dictionary else {}
	_fill(row, manifest)
	var id := String(row["id"])
	if id != "" and _plugins.has(id):
		(_plugins[id]["row"]["shadowed"] as Array[String]).append(path)
		return
	_rows.append(row)
	if id != "":
		_plugins[id] = {"row": row, "manifest": manifest, "data": {}, "descriptor": {}, "path": path,
			"kind": String(read["kind"]), "top": String(read["top"]), "hashes": {}}
	# The stages, the first with a problem the last run.
	problems.append_array(read["problems"])
	if not problems.is_empty():
		return
	if parsed == null:
		problems.append("%s could not be read." % PluginPackage.MANIFEST)
		return
	problems.append_array(manifest_problems(parsed))
	if not problems.is_empty():
		return
	problems.append_array(integrity_problems(manifest, files))
	if not problems.is_empty():
		return
	var content: Dictionary = content_reader.call(manifest, files) if content_reader.is_valid() \
		else PluginSchema.read(manifest, files)
	for problem: Variant in content.get("problems", []):
		problems.append(String(problem))
	if not problems.is_empty():
		return
	var hashes := {}
	for rel: String in files:
		hashes[rel] = PluginPackage.sha256(files[rel])
	var plugin: Dictionary = _plugins[id]
	plugin["hashes"] = hashes
	plugin["data"] = content.get("data", {})
	if manifest_kind(manifest) == KIND_SITES:
		var sites: Dictionary = content.get("descriptor", {}) if content_reader.is_valid() \
			else PluginSchema.site_descriptor(manifest, plugin["data"])
		plugin["descriptor"] = _site_descriptor(manifest, sites)
		return
	var schema: Dictionary = content.get("descriptor", {}) if content_reader.is_valid() \
		else PluginSchema.descriptor(manifest, plugin["data"])
	plugin["descriptor"] = _descriptor(manifest, schema)


## The row's words from [param manifest], each only when of its kind (a
## refused plugin's manifest may be anything).
static func _fill(row: Dictionary, manifest: Dictionary) -> void:
	var id: Variant = manifest.get("id")
	if id is String and valid_id(id):
		row["id"] = id
	for key in ["name", "version", "description", "license", "learning_note"]:
		var value: Variant = manifest.get(key)
		if value is String and String(value).length() <= MAX_TEXT:
			row[key] = value
	var api: Variant = manifest.get("api_version")
	if _whole(api):
		row["api"] = int(api)
	if manifest.get("kind") is String and String(manifest["kind"]) in KINDS:
		row["plugin_kind"] = String(manifest["kind"])
	var authors: Variant = manifest.get("authors")
	if authors is Array:
		for author: Variant in authors:
			if author is String:
				(row["authors"] as Array[String]).append(author)
	var requires: Variant = manifest.get("requires")
	if requires is Dictionary and requires.get("card_packs", []) is Array:
		var packs: Array = []
		for need: Variant in requires.get("card_packs", []):
			if need is Dictionary and need.get("id") is String:
				packs.append({"id": String(need["id"]), "min_version": String(need.get("min_version", "")) if need.get("min_version", "") is String else ""})
		row["requires"] = {"card_packs": packs}


## THE DESCRIPTOR [AdventureExpansions] reads: [param schema]'s
## ([method PluginSchema.descriptor]; a test's [member content_reader] gives
## its own), and the manifest's word for every field it leaves out.
static func _descriptor(manifest: Dictionary, schema: Dictionary) -> Dictionary:
	var out: Dictionary = schema.duplicate(true)
	var region: Dictionary = manifest.get("region", {})
	var packs: Array[String] = []
	for need: Variant in (manifest.get("requires", {}) as Dictionary).get("card_packs", []):
		packs.append(String(need["id"]))
	var defaults := {"id": String(manifest["id"]), "version": String(manifest["version"]),
		"name": String(manifest["name"]), "title": String(region.get("title", manifest["name"])),
		"castle_name": String(region.get("castle_name", "Castle")), "salt": int(region.get("salt", 0)),
		"mana_links": bool(region.get("mana_links", false)),
		"palette": region.get("palette", WorldTerrainPalette.SHANDALAR) if region.get("palette") is String else WorldTerrainPalette.SHANDALAR,
		"packs": packs, "pack": packs[0] if not packs.is_empty() else "",
		"required_markers": ["port", "castle"], "required_sites": [],
		"pictures": {}, "sprites": {}, "generator": "plugin %s %s" % [manifest["id"], manifest["version"]]}
	for key in defaults:
		if not out.has(key):
			out[key] = defaults[key]
	out["plugin"] = true
	out["id"] = String(manifest["id"])
	out.erase("provider")
	out.erase("cards_unlock")
	return out


## A SITES PLUGIN'S DESCRIPTOR ([AdventureSites] reads it):
## [param schema]'s ([method PluginSchema.site_descriptor]) with the
## manifest's word for what it leaves out — never a land's (no title, no
## port, no progress schema): `kind` "sites", `id`, `version`, `name`,
## `packs`, `pack`, `salt`, `pictures`, `sprites` (`{site: [file, width]}`),
## `sites` (`{site: {name, where, gap}}`), `plugin: true`.
static func _site_descriptor(manifest: Dictionary, schema: Dictionary) -> Dictionary:
	var out: Dictionary = schema.duplicate(true)
	var packs: Array[String] = []
	for need: Variant in (manifest.get("requires", {}) as Dictionary).get("card_packs", []):
		packs.append(String(need["id"]))
	var defaults := {"version": String(manifest["version"]), "name": String(manifest["name"]),
		"packs": packs, "pack": packs[0] if not packs.is_empty() else "", "salt": 0,
		"pictures": {}, "sprites": {}, "sites": {}}
	for key in defaults:
		if not out.has(key):
			out[key] = defaults[key]
	out["plugin"] = true
	out["kind"] = KIND_SITES
	out["id"] = String(manifest["id"])
	return out


## The kind [param manifest] declares ([constant KINDS]); an island when it
## names none.
static func manifest_kind(manifest: Dictionary) -> String:
	var kind: Variant = manifest.get("kind", KIND_ISLAND)
	return String(kind) if kind is String and String(kind) in KINDS else KIND_ISLAND


## The kind of plugin [param id] ([constant KIND_ISLAND] or [constant
## KIND_SITES]), "" for one this game does not hold valid.
static func kind(id: String) -> String:
	return manifest_kind(manifest(id)) if valid(id) else ""


## The valid island plugins (the lands [AdventureExpansions] knows), in the
## order found.
static func land_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if kind(id) == KIND_ISLAND:
			out.append(id)
	return out


## The valid sites plugins ([AdventureSites]), in the order found.
static func site_ids() -> Array[String]:
	var out: Array[String] = []
	for id in ids():
		if kind(id) == KIND_SITES:
			out.append(id)
	return out


# ------------------------------------------------------ the manifest --

## WHAT IS WRONG WITH A MANIFEST (§2 of the plugin spec), one problem a
## line, [] for none. Every field of its kind, nothing unknown (a typo is
## named, not ignored), the game new enough, the API and format this
## game's, the card packs ones this game knows.
static func manifest_problems(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if not value is Dictionary:
		out.append("plugin.json: must be one JSON object { ... }.")
		return out
	var manifest: Dictionary = value
	for key: Variant in manifest:
		if not key is String or not key in FIELDS:
			out.append("plugin.json: unknown field \"%s\"." % str(key))
	var sites := manifest.get("kind") is String and String(manifest["kind"]) == KIND_SITES
	for key in REQUIRED_FIELDS:
		if not manifest.has(key) and not (sites and key == "region"):
			out.append("plugin.json: the field \"%s\" is missing." % key)
	if not out.is_empty():
		return out
	if manifest.has("kind") and (not manifest["kind"] is String or not String(manifest["kind"]) in KINDS):
		out.append("plugin.json: kind must be one of %s." % ", ".join(KINDS))
	if sites:
		if manifest.has("region"):
			out.append("plugin.json: a sites plugin has no region; its places are described in sites.json.")
		if _whole(manifest["api_version"]) and int(manifest["api_version"]) < SITES_API:
			out.append("plugin.json: a sites plugin needs api_version %d or newer." % SITES_API)
	if not _whole(manifest["plugin_format"]) or int(manifest["plugin_format"]) != PLUGIN_FORMAT:
		out.append("plugin.json: plugin_format must be %d." % PLUGIN_FORMAT)
	if not _whole(manifest["api_version"]) or int(manifest["api_version"]) < 1:
		out.append("plugin.json: api_version must be a whole number from 1.")
	elif int(manifest["api_version"]) > API_VERSION:
		out.append("This plugin needs plugin API %d; this game reads API %d. A newer game is needed." % [int(manifest["api_version"]), API_VERSION])
	var id: Variant = manifest["id"]
	if not id is String or not valid_id(id):
		out.append("plugin.json: id must be 1 to 40 lower-case letters, digits or _, a letter first (not \"mainland\").")
	_text_problem(out, manifest, "name", MAX_NAME, true)
	_text_problem(out, manifest, "description", MAX_LINE, false)
	_text_problem(out, manifest, "license", MAX_TEXT, false)
	_text_problem(out, manifest, "learning_note", MAX_TEXT, false)
	if not manifest["version"] is String or not valid_version(manifest["version"]):
		out.append("plugin.json: version must be numbers and dots, like \"1.0.0\".")
	if manifest.has("minimum_game_version"):
		var least: Variant = manifest["minimum_game_version"]
		if not least is String or not valid_version(least):
			out.append("plugin.json: minimum_game_version must be numbers and dots, like \"0.60.19\".")
		elif game_version() != "" and compare_versions(least, game_version()) > 0:
			out.append("This plugin needs game version %s or newer; this is %s." % [least, game_version()])
	var authors: Variant = manifest["authors"]
	if not authors is Array or (authors as Array).is_empty() or (authors as Array).size() > MAX_AUTHORS \
			or not (authors as Array).all(func(a: Variant) -> bool: return a is String and String(a).strip_edges() != "" and String(a).length() <= MAX_NAME):
		out.append("plugin.json: authors must be a list of 1 to %d names." % MAX_AUTHORS)
	if manifest.has("requires"):
		out.append_array(_requires_problems(manifest["requires"]))
	if not sites:
		out.append_array(_region_problems(manifest["region"]))
	if manifest.has("files"):
		var files: Variant = manifest["files"]
		if not files is Dictionary:
			out.append("plugin.json: files must be an object of file -> SHA-256.")
		else:
			for rel: Variant in files:
				var hash: Variant = files[rel]
				if not rel is String or not hash is String or String(hash).length() != 64 or not String(hash).is_valid_hex_number() \
						or String(hash) != String(hash).to_lower():
					out.append("plugin.json: files: \"%s\" needs its SHA-256 as 64 lower-case hex digits." % str(rel))
	return out


static func _text_problem(out: Array[String], manifest: Dictionary, key: String, most: int, needed: bool) -> void:
	if not manifest.has(key):
		return
	var value: Variant = manifest[key]
	if not value is String or String(value).length() > most or (needed and String(value).strip_edges() == ""):
		out.append("plugin.json: %s must be %stext of at most %d characters." % [key, "" if not needed else "non-empty ", most])


static func _requires_problems(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if not value is Dictionary:
		out.append("plugin.json: requires must be an object.")
		return out
	for key: Variant in value:
		if key != "card_packs":
			out.append("plugin.json: requires: unknown field \"%s\"." % str(key))
	var packs: Variant = (value as Dictionary).get("card_packs", [])
	if not packs is Array or (packs as Array).size() > MAX_PACKS:
		out.append("plugin.json: requires.card_packs must be a list of at most %d packs." % MAX_PACKS)
		return out
	var service := AdventureExpansions.packs()
	var known: Array = service.known_ids() if service != null else []
	var seen := {}
	for need: Variant in packs:
		if not need is Dictionary or not need.get("id") is String:
			out.append("plugin.json: each of requires.card_packs is {\"id\": \"pack-N\", \"min_version\": \"1.0\"}.")
			continue
		for key: Variant in need:
			if not key in ["id", "min_version"]:
				out.append("plugin.json: requires.card_packs: unknown field \"%s\"." % str(key))
		var pack := String(need["id"])
		if pack in AdventureSetup.IGNORED_PACKS:
			out.append("plugin.json: %s is never part of an adventure." % pack)
		elif service != null and not pack in known:
			out.append("plugin.json: this game knows no card pack \"%s\"." % pack)
		if seen.has(pack):
			out.append("plugin.json: %s is named twice in requires.card_packs." % pack)
		seen[pack] = true
		if need.has("min_version") and (not need["min_version"] is String or not valid_version(need["min_version"])):
			out.append("plugin.json: %s's min_version must be numbers and dots, like \"1.0\"." % pack)
	return out


static func _region_problems(value: Variant) -> Array[String]:
	var out: Array[String] = []
	if not value is Dictionary:
		out.append("plugin.json: region must be an object.")
		return out
	var region: Dictionary = value
	for key: Variant in region:
		if not key is String or not key in REGION_FIELDS:
			out.append("plugin.json: region: unknown field \"%s\"." % str(key))
	if not region.get("title") is String or String(region["title"]).strip_edges() == "" or String(region["title"]).length() > MAX_NAME:
		out.append("plugin.json: region.title must be non-empty text of at most %d characters." % MAX_NAME)
	if region.has("castle_name") and (not region["castle_name"] is String or String(region["castle_name"]).length() > MAX_NAME):
		out.append("plugin.json: region.castle_name must be text of at most %d characters." % MAX_NAME)
	if region.has("salt") and (not _whole(region["salt"]) or int(region["salt"]) < 0 or int(region["salt"]) > 0x7FFFFFFF):
		out.append("plugin.json: region.salt must be a whole number from 0 to 2147483647.")
	if region.has("mana_links") and not region["mana_links"] is bool:
		out.append("plugin.json: region.mana_links must be true or false.")
	if region.has("palette"):
		var palette: Variant = region["palette"]
		if palette is String:
			if not WorldTerrainPalette.PROFILES.has(palette):
				out.append("plugin.json: region.palette \"%s\" is not one of the game's palettes (%s), nor a palette object." % [palette,
					", ".join(WorldTerrainPalette.PROFILES.keys())])
		elif not palette is Dictionary:
			out.append("plugin.json: region.palette must be a palette's name or a palette object.")
	return out


## WHAT IS WRONG WITH THE MANIFEST'S `files` LIST (when it has one) for the
## [param files] read: every file listed there, with its SHA-256, and every
## file but the manifest listed. Integrity, not authorship.
static func integrity_problems(manifest: Dictionary, files: Dictionary) -> Array[String]:
	var out: Array[String] = []
	if not manifest.has("files"):
		return out
	var listed: Dictionary = manifest["files"]
	var rels: Array = listed.keys()
	rels.sort()
	for rel: String in rels:
		if not files.has(rel):
			out.append("%s: listed in plugin.json's files but not in the plugin." % rel)
		elif PluginPackage.sha256(files[rel]) != String(listed[rel]):
			out.append("%s: its SHA-256 is not the one plugin.json's files list gives (the file changed after export)." % rel)
	var present: Array = files.keys()
	present.sort()
	for rel: String in present:
		if rel != PluginPackage.MANIFEST and not listed.has(rel):
			out.append("%s: not in plugin.json's files list." % rel)
	return out


# --------------------------------------------------------------- words --

## Whether [param text] is a plugin id ([constant ID_PATTERN], not reserved).
static func valid_id(text: String) -> bool:
	if text in RESERVED_IDS:
		return false
	var pattern := RegEx.create_from_string(ID_PATTERN)
	return pattern.search(text) != null


## Whether [param text] is a version: 1 to 4 numbers joined by dots.
static func valid_version(text: String) -> bool:
	var parts := text.split(".")
	if text.length() > 24 or parts.size() > 4:
		return false
	for part in parts:
		if part == "" or not part.is_valid_int() or part.begins_with("+") or part.begins_with("-"):
			return false
	return true


## [param a] against [param b], number by number: −1, 0 or 1.
static func compare_versions(a: String, b: String) -> int:
	var left := a.split(".")
	var right := b.split(".")
	for i in maxi(left.size(), right.size()):
		var x := int(left[i]) if i < left.size() and left[i].is_valid_int() else 0
		var y := int(right[i]) if i < right.size() and right[i].is_valid_int() else 0
		if x != y:
			return -1 if x < y else 1
	return 0


## The game's own version, "" when unknown.
static func game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


## A whole number as JSON reads one (a float with nothing after the point).
static func _whole(value: Variant) -> bool:
	if value is int:
		return true
	return value is float and is_finite(value) and is_equal_approx(value, roundf(value)) and absf(value) < 9.0e15
