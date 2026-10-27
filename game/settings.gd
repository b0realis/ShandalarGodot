class_name Settings
extends RefCounted
## Persistent player options — a plain ConfigFile at user://settings.cfg.
## The Options screen writes these; the duel screen reads them at start.
## Static access, loaded lazily, saved on every set (options are rare
## writes; immediate persistence beats a lost setting).
##
## THE ONE EXCEPTION IS A SLIDER: `value_changed` fires on every pixel of
## a drag, and rewriting the file sixty times a second for a volume knob
## is a stall on a slow disk for nothing. So [method set_value] takes a
## `persist` flag — false applies the value in memory and marks the file
## dirty — and [method flush] writes it once, when the drag ends or the
## screen leaves. A caller that never flushes loses nothing but the
## write: the next persisting set saves the whole file, dirty keys and
## all.

const PATH := "user://settings.cfg"

static var _config: ConfigFile = null
## A value was set without being saved. See the class doc.
static var _dirty := false
## How many times the file has been written this session — for tests that
## pin "once per gesture" (a slider drag, the rules preset).
static var write_count := 0


## Set when the file on disk could not be read AND could not be copied
## aside (see [method _load]): nothing is written over it this session.
static var _unwritable_reason := ""
## Where a file that would not parse was copied aside this session
## ([method _keep_aside]), for [method problem]; "" when none was.
static var _kept_aside_as := ""
## Why the last save failed, while its changes are still pending; OK
## once a save goes through. For [method problem].
static var _save_error: Error = OK
## The file's bytes as this instance last read or wrote them, and the
## keys it has changed since — `key -> [value]`, or `key -> []` for a key
## it cleared. See [method _merge_from_disk].
static var _seen := PackedByteArray()
static var _changed: Dictionary = {}
## The [method problem] the title screen has already shown.
static var _told := ""
## The copy aside was of a file changed under a running game
## ([method _merge_from_disk]), not of the one read at start.
static var _kept_while_running := false


static func _ensure() -> void:
	if _config == null:
		_load()


## Read the file into a fresh [ConfigFile]. A missing file is fine —
## defaults apply.
##
## A FILE THAT WILL NOT PARSE IS KEPT BEFORE ANYTHING IS WRITTEN (bug
## pass of 2026-10-03). `setup.txt` and the Options notes invite editing
## the folder keys by hand, and one bad line — an unquoted path, a
## Windows path whose `\U` Godot reads as an escape — stops
## [method ConfigFile.load] there: the keys above it are read, the ones
## below are not, and the next [method set_value] used to rewrite the
## file from that, every key below the bad line gone. So the file is
## copied aside first ([method _keep_aside]) and the player told where;
## the game goes on with what it could read. A file that cannot even be
## READ (its permissions) cannot be copied, and then it is never written
## at all this session — writing would replace it with the defaults.
static func _load() -> void:
	_config = ConfigFile.new()
	_unwritable_reason = ""
	_kept_aside_as = ""
	_kept_while_running = false
	_save_error = OK
	_changed = {}
	_told = ""
	_seen = _read_quietly(PATH)
	var err := _config.load(PATH)
	if err != OK and FileAccess.file_exists(PATH):
		_keep_aside(err)
	_migrate_rules()


## The bytes of [param path], or none for a file that is missing or will
## not open — without the engine error [method FileAccess.get_file_as_bytes]
## prints for a file it cannot open.
static func _read_quietly(path: String) -> PackedByteArray:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


## See [method _load]. Reads the file itself rather than through
## [method DirAccess.copy_absolute], which prints an engine error for a
## file it cannot open; the same broken file is not copied twice (a
## start that saves nothing leaves it as it was), and an older copy is
## never overwritten — the next free name is taken.
static func _keep_aside(err: Error) -> void:
	var source := FileAccess.open(PATH, FileAccess.READ)
	var bytes := PackedByteArray()
	if source != null:
		bytes = source.get_buffer(source.get_length())
		source.close()
	var kept := ""
	if source != null:
		var candidate := PATH + ".bad"
		var n := 2
		while FileAccess.file_exists(candidate):
			if FileAccess.get_file_as_bytes(candidate) == bytes:
				kept = candidate
				break
			candidate = "%s.bad%d" % [PATH, n]
			n += 1
		if kept == "" and write_atomically(candidate, bytes) == OK:
			kept = candidate
	if kept != "":
		_kept_aside_as = kept
		printerr(("settings: %s could not be read (%s) — a copy of it is kept "
			+ "as %s. The game goes on with what it could read and the "
			+ "defaults; fix the line or copy your keys back from the copy.")
			% [ProjectSettings.globalize_path(PATH), error_string(err),
				ProjectSettings.globalize_path(kept)])
		return
	_unwritable_reason = error_string(err)
	printerr(("settings: %s could not be read (%s) and could not be copied "
		+ "aside, so it will not be written this session and nothing in it "
		+ "is lost. Fix or remove it and restart.")
		% [ProjectSettings.globalize_path(PATH), _unwritable_reason])


## The marker a file carries once [method _migrate_rules] has looked at it.
const RULES_REVISION_KEY := "rules_revision"
const RULES_REVISION := 3

## REVISION 2 — ONE fork changed its modern answer (2026-09-18): free combat damage
## division is now what modern Magic does too (Foundations, 2024), so a
## stored `rule_free_damage_assignment = false` written by an older
## build's "Modern rules" preset would keep the 2009-2024 order in force
## and show the preset as "Custom". If the other stored forks all read
## modern, that false was the preset's, not the player's, and it moves
## with the preset; a mixed file is a custom choice and is left alone.
## The marker means each file is looked at once.
##
## The stored forks are read as [method get_value] reads them (robustness
## campaign of 2026-10-12): a fork hand-typed as `"false"` used to stop
## this function with a script error before it could write its marker, so
## it ran — and failed — on every start. A word that is no yes or no is
## not a choice either way and leaves the decision to the others.
##
## REVISION 3 — A FORK ARRIVED (2026-10-12): `damage_effects_fixed_order`,
## after a player may have saved "1997 — Fifth Edition". Unstored, it
## reads the player default (the modern answer: the damaged player is
## asked), and the Options screen would call that player's rules "Custom".
## So a file whose other forks — stored, or their defaults — are exactly
## one preset's answers takes that preset's answer for the new fork too
## ([method RulesOptions.preset_matching]); only the 1997 preset's differs
## from the default, so only such a file is written.
##
## THE NINTH FORK NEEDS NO REVISION (2026-10-13): every preset answers
## `sacrifice_clauses_wait` OFF, and so does the player default, so a file
## from any older build reads the same rules without it, its preset keeps
## its name, and there is nothing to write. A new fork needs a revision only
## when the presets disagree about it, as they do about
## `damage_effects_fixed_order`.
##
## A file with no fork stored at all is not looked at: the built-in
## defaults apply and nothing is written now. But the marker goes into
## memory (repository check 2026-10-13), so the first save carries it.
## Without it, the first rule a player set on this build was read at the
## next start as an older build's file, and the migrations above changed
## it: "Free damage assignment" turned off came back on, and a row left at
## the player default in an otherwise 1997 mix took the 1997 answer.
static func _migrate_rules() -> void:
	var revision := int(coerce(_config.get_value("options", RULES_REVISION_KEY, 1), 1))
	if revision >= RULES_REVISION:
		return
	var stored_any := false
	for fork in RulesOptions.FORKS:
		if _config.has_section_key("options", "rule_" + String(fork["key"])):
			stored_any = true
			break
	if not stored_any:
		# Nothing stored: the built-in defaults apply. The marker waits in
		# memory for the next save, so a rule set on this build is never
		# taken for an older build's.
		_put(RULES_REVISION_KEY, RULES_REVISION)
		return
	if revision < 2:
		_migrate_free_division()
	if revision < 3:
		_migrate_new_forks(["damage_effects_fixed_order"])
	_put(RULES_REVISION_KEY, RULES_REVISION)
	_save()


## Revision 3 (see [method _migrate_rules]): give each of [param added] —
## forks an older build never stored — the answer of the preset the
## file's other forks match, when they match one.
static func _migrate_new_forks(added: Array) -> void:
	var known := {}
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		if not added.has(key):
			known[key] = rule(key)
	var preset := RulesOptions.preset_matching(known)
	if preset == "":
		return       # a custom mix: the new forks keep the player default
	var answers := RulesOptions.new()
	answers.set_preset(preset)
	for key: String in added:
		if not _config.has_section_key("options", "rule_" + key) \
				and answers.get_fork(key) != rule(key):
			_put("rule_" + key, answers.get_fork(key))


## Revision 2 (see [method _migrate_rules]): the division order.
static func _migrate_free_division() -> void:
	if not _config.has_section_key("options", "rule_free_damage_assignment"):
		return       # nothing stored: the built-in default applies
	var free_division: Variant = _yes_or_no(_config.get_value("options", "rule_free_damage_assignment"))
	var all_modern: bool = free_division is bool and not free_division
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		if key == "free_damage_assignment":
			continue
		# An unstored fork already reads modern; a stored one has to —
		# and "modern" here is the OLD answer, `not fifth_value` for every
		# fork, because that is what a revision-1 file was written under.
		if not _config.has_section_key("options", "rule_" + key):
			continue
		var stored: Variant = _yes_or_no(_config.get_value("options", "rule_" + key))
		if stored is bool and stored == bool(fork["fifth_value"]):
			all_modern = false
	if all_modern:
		_put("rule_free_damage_assignment", true)


## The stored value of [param key], or [param default_value] when there is
## none — IN THE DEFAULT'S TYPE (robustness campaign of 2026-10-12).
##
## settings.cfg is a text file the docs invite a player to edit, and an
## older build may have written a key in another type. A `"yes"` where a
## switch is read, a `"fast"` where a number is, a list where the table of
## bindings is, raised a script error on every start — in the typed
## accessors below, in every `bool(Settings.get_value(...))` of the shell,
## in [method Controls.apply] — and left the reader with nothing. So the
## default says the type: a near value is read as meant and anything else
## is the default ([method coerce]). A null default asks for the value
## exactly as stored — for a reader that maps foreign types itself — and
## is null for a key that is not there.
static func get_value(key: String, default_value):
	_ensure()
	if default_value == null and not _config.has_section_key("options", key):
		return null      # ConfigFile prints an error for a missing key with no default
	return coerce(_config.get_value("options", key, default_value), default_value)


## [param value] in the type of [param default_value]:
## - the same type is itself (a float that is not a number — `nan`,
##   `inf` — is not a number a reader can use, and is the default);
## - a switch reads `true`/`yes`/`on`/`1` and `false`/`no`/`off`/`0`, in
##   any case and spacing, and a number as on unless it is 0;
## - a whole number reads a float (cut to its whole part), a switch, or
##   text that is a whole number; a number reads a whole number or text
##   that is a number;
## - text reads a StringName or a NodePath, and the other way round;
## - a position reads its whole-number or fractional twin;
## - a list reads a packed list, and a packed list any list, whose
##   entries its reader checks (the phase stops do);
## - a null default asks for the value as it is.
## Anything else is [param default_value].
static func coerce(value: Variant, default_value: Variant) -> Variant:
	var want := typeof(default_value)
	var have := typeof(value)
	if want == TYPE_NIL:
		return value
	var text := have == TYPE_STRING or have == TYPE_STRING_NAME
	var finite := have != TYPE_FLOAT or is_finite(value)
	if have == want:
		return value if finite else default_value
	match want:
		TYPE_BOOL:
			if (have == TYPE_INT or have == TYPE_FLOAT) and finite:
				return value != 0
			if text and _yes_or_no(value) != null:
				return _yes_or_no(value)
		TYPE_INT:
			if have == TYPE_BOOL or (have == TYPE_FLOAT and finite):
				return int(value)
			if text and String(value).strip_edges().is_valid_int():
				return String(value).strip_edges().to_int()
		TYPE_FLOAT:
			if have == TYPE_INT:
				return float(value)
			if text and String(value).strip_edges().is_valid_float():
				var number := String(value).strip_edges().to_float()
				if is_finite(number):
					return number
		TYPE_STRING:
			if have == TYPE_STRING_NAME or have == TYPE_NODE_PATH:
				return String(value)
		TYPE_STRING_NAME:
			if have == TYPE_STRING or have == TYPE_NODE_PATH:
				return StringName(String(value))
		TYPE_NODE_PATH:
			if text:
				return NodePath(String(value))
		TYPE_VECTOR2:
			if have == TYPE_VECTOR2I:
				return Vector2(value)
		TYPE_VECTOR2I:
			if have == TYPE_VECTOR2 and is_finite(value.x) and is_finite(value.y):
				return Vector2i(value)
		TYPE_ARRAY:
			if _is_packed(have):
				return Array(value)
		_:
			if _is_packed(want) and (have == TYPE_ARRAY or _is_packed(have)):
				return value
	return default_value


static func _is_packed(type: int) -> bool:
	return type >= TYPE_PACKED_BYTE_ARRAY and type <= TYPE_PACKED_VECTOR4_ARRAY


## true or false for a stored switch, or null for a value that is neither
## (see [method coerce]).
static func _yes_or_no(value: Variant) -> Variant:
	match typeof(value):
		TYPE_BOOL:
			return value
		TYPE_INT:
			return value != 0
		TYPE_FLOAT:
			return value != 0.0 if is_finite(value) else null
		TYPE_STRING, TYPE_STRING_NAME:
			var word := String(value).strip_edges().to_lower()
			if word in ["true", "yes", "on", "1"]:
				return true
			if word in ["false", "no", "off", "0"]:
				return false
	return null


static func set_value(key: String, value, persist := true) -> void:
	_ensure()
	_put(key, value)
	if persist:
		_save()
	else:
		_dirty = true


## Set [param key] in memory and remember that this instance set it
## ([method _merge_from_disk]).
static func _put(key: String, value: Variant) -> void:
	_config.set_value("options", key, value)
	_changed[key] = [value]


static func _save() -> void:
	# [QoL] A failed write is still pending. Before this guard a blocked
	# settings.cfg reported `dirty=false counted_writes=1` (2026-09-13),
	# so leaving the options screen could never retry the player's change.
	# A file that could not be read and could not be kept ([method _load])
	# is never written over: the changes stay in memory, pending.
	if _unwritable_reason != "":
		_dirty = true
		printerr("settings: not saving over %s, which could not be read (%s); changes remain pending" % [
			PATH, _unwritable_reason])
		return
	_merge_from_disk()
	if _unwritable_reason != "":
		_dirty = true        # a changed file that could not even be kept aside
		return
	# WHOLE OR NOT AT ALL (bug pass of 2026-10-03): [method ConfigFile.save]
	# truncates the file in place and never says whether the bytes went
	# down, so a full disk left an empty settings.cfg and reported OK.
	var bytes := _config.encode_to_text().to_utf8_buffer()
	var err := write_atomically(PATH, bytes)
	_dirty = err != OK
	_save_error = err
	if err == OK:
		write_count += 1
		_seen = bytes
		_changed = {}
	else:
		printerr("settings: cannot save %s (%s); changes remain pending" % [
			PATH, error_string(err)])


## TWO INSTANCES, ONE FILE (robustness campaign of 2026-10-12). A LAN host
## and its client on one desk share the profile, and each wrote its whole
## cached file — so a pack switched on in one was switched off again by
## the other's next unrelated save. Before a save, a file that is not what
## this instance last read or wrote is read again, and only the keys this
## instance changed since are laid over it: the other's changes stand
## unless this one changed the same key since. A changed file that will
## not parse (a hand edit made while the game ran) is kept aside first,
## exactly as one found at start is ([method _keep_aside]), and this
## instance's own file is what is written.
static func _merge_from_disk() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var bytes := _read_quietly(PATH)
	if bytes == _seen:
		return
	var fresh := ConfigFile.new()
	var err := fresh.parse(bytes.get_string_from_utf8())
	if err != OK:
		_keep_aside(err)
		_kept_while_running = _kept_aside_as != ""
		_seen = bytes
		return
	for key in _changed:
		var change: Array = _changed[key]
		if change.is_empty():
			if fresh.has_section_key("options", key):
				fresh.erase_section_key("options", key)
		else:
			fresh.set_value("options", key, change[0])
	_config = fresh
	_seen = bytes


## The tail of the file [method write_atomically] writes before it is
## renamed into place; [method pending_path] adds whose write it is.
const PENDING_TAIL := ".tmp"


## WRITE [param bytes] TO [param path] WHOLE OR NOT AT ALL (bug pass of
## 2026-10-03) — the player's files ([Settings], [method DeckStore.save]
## and its export, [method PackSeal.seal], the Deck Lab's [EloLedger])
## used to be truncated in place with the write never checked, so a full
## disk or a quota cut a deck short and the game said it had been saved.
## The bytes go to a pending file ([method pending_path]), are checked
## (the write's own error and the length that reached the disk) and only
## then renamed over the old file — the pattern `DraftStore._write` and
## the tournament store already use. Anything but OK leaves the old file
## exactly as it was and no pending file behind.
##
## AND WHERE AND AS THE FILE IS (robustness campaign of 2026-10-12): a
## rename replaces whatever sits at the path, so
## - a LINK (a deck kept in a synced folder, a settings.cfg in a dotfiles
##   repository) is followed to the file it names, and the pending file
##   is written beside THAT file — the link stays a link and the file it
##   names is the one that changes;
## - a file the player made READ-ONLY to keep it as it is is refused
##   ([constant ERR_FILE_NO_PERMISSION]) rather than replaced;
## - a rewritten file keeps its mode (an `rw-------` settings.cfg stays
##   private);
## - two writers of one file at once (two game instances on one profile)
##   never share a pending file: each process and thread has its own, so
##   the file that lands is always one whole version.
static func write_atomically(path: String, bytes: PackedByteArray) -> Error:
	var target := _followed(path)
	var mode := 0
	if FileAccess.file_exists(target):
		if _read_only(target):
			return ERR_FILE_NO_PERMISSION
		mode = _mode_of(target)
	var pending := _pending_beside(target)
	var file := FileAccess.open(pending, FileAccess.WRITE)
	if file == null:
		var why := FileAccess.get_open_error()
		return why if why != OK else ERR_FILE_CANT_WRITE
	var stored := file.store_buffer(bytes)
	file.flush()
	var err := file.get_error()
	file.close()
	if err == OK and not stored:
		err = ERR_FILE_CANT_WRITE
	if err == OK:
		var check := FileAccess.open(pending, FileAccess.READ)
		if check == null or check.get_length() != bytes.size():
			err = ERR_FILE_CANT_WRITE
		if check != null:
			check.close()   # closed before the rename: Windows will not move an open file
	# Only where it differs: a card formatted FAT (a handheld's) gives
	# every file the one mode its mount says and refuses to change it.
	if err == OK and mode != 0 and _mode_of(pending) != mode:
		FileAccess.set_unix_permissions(pending, mode)
	if err == OK:
		err = DirAccess.rename_absolute(pending, target)
	if err != OK and FileAccess.file_exists(pending):
		DirAccess.remove_absolute(pending)
	return err


## The pending file [method write_atomically] writes for [param path]
## from the calling thread: beside the file a link names, tagged with
## this process and thread. Tests take this name with a folder to make a
## write fail on purpose.
static func pending_path(path: String) -> String:
	return _pending_beside(_followed(path))


static func _pending_beside(target: String) -> String:
	return "%s%s.%d.%d" % [target, PENDING_TAIL, OS.get_process_id(), OS.get_thread_caller_id()]


## [param path], or the file it names when it is a link — through a chain
## of links, a relative one read from the link's own folder. Sixteen deep
## at most, as a loop of links must end somewhere.
static func _followed(path: String) -> String:
	var at := path
	for _hop in 16:
		var dir := DirAccess.open(at.get_base_dir())
		if dir == null or not dir.is_link(at.get_file()):
			return at
		var named := dir.read_link(at.get_file())
		if named == "":
			return at
		if named.is_relative_path():
			named = ProjectSettings.globalize_path(at.get_base_dir()).path_join(named).simplify_path()
		at = named
	return at


## The file's owner may not write it: the read-only attribute on Windows,
## the owner's write bit elsewhere. A platform that reports no mode at
## all (0) is not read as read-only.
static func _read_only(target: String) -> bool:
	if OS.get_name() == "Windows":
		return FileAccess.get_read_only_attribute(target)
	var mode := _mode_of(target)
	return mode != 0 and (mode & 128) == 0      # 128 = 0o200, the owner's write bit


## The file's permission bits (0o7777), or 0 where the platform has none.
static func _mode_of(target: String) -> int:
	if OS.get_name() == "Windows":
		return 0
	return FileAccess.get_unix_permissions(target) & 4095


## Write out whatever [method set_value] was asked not to. A no-op when
## nothing is waiting, so it is safe to call from every place a drag
## might end.
static func flush() -> void:
	if not _dirty:
		return
	_ensure()
	_save()


## For tests: is a value waiting to be written?
static func is_dirty() -> bool:
	return _dirty


## Read the file again and forget what is in memory.
##
## For a tool that PUT THE FILE BACK behind this class's back — the duel
## soak restores `user://settings.cfg` byte for byte after fuzzing the
## live options panel — the cached [ConfigFile] would otherwise go on
## answering with what the fuzzer wrote.
##
## NOT `reload` (renamed 2026-10-03): called on the class, `Settings.reload()`
## resolved to Godot's own Script.reload — it RECOMPILED this script, which
## forgot the cache by accident and never ran this body.
static func reload_file() -> void:
	_dirty = false
	_load()


## Remove a key so the built-in default applies again. Tests use this to
## leave no trace (writing the old value back would MATERIALIZE a default
## into the player's file — that bug shipped a "fan" hand once).
static func clear_value(key: String) -> void:
	_ensure()
	if _config.has_section_key("options", key):
		_config.erase_section_key("options", key)
		_changed[key] = []
		_save()


static func has_value(key: String) -> bool:
	_ensure()
	return _config.has_section_key("options", key)


## WHAT WENT WRONG WITH THE FILE, IN THE PLAYER'S WORDS (robustness
## campaign of 2026-10-12), or "" when nothing did. A settings.cfg that
## would not parse, one that could not be read, and a save that failed
## were said on stderr only — which a Steam Deck, an ArkOS handheld or
## the Quest never shows: the options below a bad line quietly started
## from their defaults, and a switch moved on a full or read-only card
## looked saved and was gone at the next start. The title screen shows
## this once ([method untold_problem]); the Options screen carries it as
## a line for as long as it holds.
static func problem() -> String:
	_ensure()
	var lines: Array[String] = []
	if _unwritable_reason != "":
		lines.append(("settings.cfg could not be read (%s), so the game leaves it "
			+ "as it is: options set now are not saved. Fix or remove it "
			+ "(%s) and start the game again.")
			% [_unwritable_reason, ProjectSettings.globalize_path(PATH)])
	elif _dirty and _save_error != OK:
		lines.append("Options could not be saved (%s). Changes made now last until the game closes."
			% _why_not_saved(_save_error))
	if _kept_aside_as != "" and _kept_while_running:
		lines.append(("settings.cfg was changed while the game ran into a file "
			+ "the game could not read, so the game saved its own options over "
			+ "it. The changed file is kept as %s.") % ProjectSettings.globalize_path(_kept_aside_as))
	elif _kept_aside_as != "":
		lines.append(("settings.cfg had a line the game could not read, so the "
			+ "options from that line on started from their defaults. Your file "
			+ "is kept as %s — fix the line there and copy it back, or set "
			+ "those options again.") % ProjectSettings.globalize_path(_kept_aside_as))
	return "\n".join(lines)


## [method problem] the first time it is asked for each problem, and ""
## after — the title screen's notice, once per problem and start.
static func untold_problem() -> String:
	var now := problem()
	if now == "" or now == _told:
		return ""
	_told = now
	return now


static func _why_not_saved(err: Error) -> String:
	match err:
		ERR_FILE_NO_PERMISSION:
			return "settings.cfg or its folder is read-only"
		ERR_FILE_CANT_OPEN, ERR_CANT_CREATE:
			return "its folder cannot be written"
		ERR_FILE_CANT_WRITE:
			return "the disk did not take the file; it may be full"
	return error_string(err)


# Typed accessors for the options the game actually has.

## Numbered gameplay card packs the player has switched on. Availability
## is deliberately NOT part of this value: keeping an id here means a pack
## the player enabled comes back on automatically when its ZIP returns.
static func enabled_card_packs() -> Array[String]:
	var raw: Variant = get_value("enabled_card_packs", [])
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for value in raw:
			# AN ENTRY IS TEXT OR NOTHING (review 2026-10-21, ui-2). A pack
			# id is `pack-N`; `String(8)` is a script error in this engine,
			# and a hand-typed `8` aborted this reader at every start and
			# turned the VALID ids beside it off as well. [method coerce]
			# reads text as text and anything else as "", which is skipped.
			var id := String(coerce(value, "")).strip_edges()
			if id != "" and not out.has(id):
				out.append(id)
	return out


## Persist the enabled-pack ids without materialising an empty default.
static func set_enabled_card_packs(ids: Array[String]) -> void:
	var clean: Array[String] = []
	for value in ids:
		var id := String(value).strip_edges()
		if id != "" and not clean.has(id):
			clean.append(id)
	if clean.is_empty():
		clear_value("enabled_card_packs")
	else:
		set_value("enabled_card_packs", clean)

## `Sound &Effects` — entry 9 of `@DECKSURFACE_STANDALONE`
## (`s30/assets/text/Menus.txt:169-179`) and of `@MAINMENU_STANDALONE`
## (`:218-228`). The 1997 game had no options SCREEN; this switch and the
## one below it lived on the deck builder's own menu, and the deck builder
## still writes them there ([DeckBuilderScreen]). The `[QoL]` Options
## screen is a second VIEW of these two keys, never a second copy.
static func sound_enabled() -> bool:
	return get_value("sound_enabled", true)

## `&Music` — entry 8 of the same two tags, and persisted by the original
## under that literal name: `cfg_write_int(global_cfg_music ? 1 : 0,
## "Music")` (`shandalar-src/src/deck/deckdll.cpp:1296`). Separate from
## [method sound_enabled] because the original separated them — a player
## who wants the table to keep clicking with the tune off could always
## have that.
static func music_enabled() -> bool:
	return get_value("music_enabled", true)

## [QoL] The 1997 game had no volume control of its own — `&Music` and
## `Sound &Effects` are on/off and nothing else. These two ride the
## [GameAudio] buses, so moving one is audible in a duel already running.
static func music_volume_db() -> float:
	return get_value("music_volume_db", -14.0)

## [QoL] See [method music_volume_db].
static func sfx_volume_db() -> float:
	return get_value("sfx_volume_db", -6.0)

## [QoL] `Transitions` on the Options screen (the owner, 2026-10-27, H7):
## the adventure's 1997 picture effects — a town's picture zooming in, a
## castle's and a lair's coming in tile by tile, a creature's face —
## played ([TileReveal]), short and skipped by any click or key. On by
## default; off, every picture is simply there.
static func transitions() -> bool:
	return get_value("transitions", true)

## Seconds between AI actions in vs-AI play (demo mode has its own knob
## on the battle-setup screen).
static func ai_pace() -> float:
	return get_value("ai_pace", 0.35)


# ------------------------------------------------- handheld defaults --

## THE HANDHELD'S OWN DEFAULTS (2026-09-27, the Steam Deck release). A
## launcher that knows the device it runs on — `packaging/handhelds/
## steam-deck.sh`, `arkos.sh` — exports [constant HANDHELD_ENV] with the
## device's name, and a setting the player has NEVER WRITTEN then reads
## the handheld's default instead of the desk's: full screen on (a
## handheld has no desktop to keep a window on), the click-to-enlarge
## card reader on (a 7-inch screen is what that row was made for), and
## the power saver on (a battery). Three keys and nothing else — and
## since 0.50.26 the reader is the desk's default too, so the handheld
## now differs from the desk in two of them: full screen and the power
## saver, the two things a Deck owner would otherwise set by hand on
## first run. The reader stays in the table so the handheld's word on it
## does not hang on the desk's. The file always wins: once the player has
## written a key, the launcher's word on it is never read again — so an
## Options choice made on the Deck is as durable as one made on the desk.
## The desk, with the variable unset, is exactly what it was. An Android
## build (the Meta Quest panel, 2026-09-29) has no launcher to name it and
## IS the handheld: the word there is `android` unless the variable says
## otherwise.
const HANDHELD_ENV := "SHANDALAR_HANDHELD"
const ANDROID_HANDHELD := "android"
const HANDHELD_DEFAULTS := {
	"fullscreen": true,
	"fullscreen_cards": true,
	"power_saver": true,
}


## The handheld the launcher named, `android` on an Android build the
## variable does not name, or "" on a desk.
static func handheld() -> String:
	var named := OS.get_environment(HANDHELD_ENV).strip_edges()
	if named == "" and OS.has_feature("android"):
		return ANDROID_HANDHELD
	return named


## The built-in default for [param key]: the handheld's where the
## launcher named one and [constant HANDHELD_DEFAULTS] has a word,
## [param desktop] everywhere else. A stored value is not consulted
## here — [method get_value] reads the file over whatever this says.
static func default_for(key: String, desktop: Variant) -> Variant:
	if handheld() != "" and HANDHELD_DEFAULTS.has(key):
		return HANDHELD_DEFAULTS[key]
	return desktop


## [QoL] `Full screen` on the Options screen — see [GameDisplay] for what
## 1997 had instead (nothing but `M&inimize` and a frameless-window
## config key). Off by default: the shipped window is what the game has
## always opened into, and a default that changed under the owner would
## be a surprise, not a setting. On by default under a handheld launcher
## ([method default_for]).
static func fullscreen() -> bool:
	return get_value("fullscreen", default_for("fullscreen", false))


## [QoL] Optional click-to-enlarge for the duel and Deck Builder showcases.
## Reading the default never writes it to the player's settings file.
## On by default everywhere since 0.50.26 (the owner, 2026-10-15: *"Full
## screen card on click should be default on"*); before that only under a
## handheld launcher ([method default_for]), which still says on. A player
## who switched it off has `false` written and keeps it.
static func fullscreen_cards() -> bool:
	return get_value("fullscreen_cards", default_for("fullscreen_cards", true))


## [QoL] `Power saver` on the Options screen — [member OS.low_processor_usage_mode]:
## redraw only when something on the screen changed and rest between
## frames. Off by default on a desk, where a card game already costs
## the GPU nothing worth saving; on by default under a handheld
## launcher, where every idle frame is battery ([method default_for]).
## Applied by [GameDisplay].
static func power_saver() -> bool:
	return get_value("power_saver", default_for("power_saver", false))


## [QoL] `Pad pointer` on the Options screen — `auto`, `on` or `off`;
## see the `PadControls` autoload for what each means. `auto` by
## default: a desk with no controller never sees the layer, a Steam
## Deck in its gamepad layout always does, and neither has to be told.
static func pad_pointer() -> String:
	var value: Variant = get_value("pad_pointer", "auto")
	return value if value is String and value in ["auto", "on", "off"] else "auto"


## [QoL] `On-screen keyboard` on the Options screen — `auto`, `on` or
## `off`; see the `ScreenKeyboard` autoload for what each means. `auto`
## by default: a handheld without a keyboard of its own sees the board
## (2026-10-02, the ArkOS tester with no USB keyboard), a desk never.
static func screen_keyboard() -> String:
	var value: Variant = get_value("screen_keyboard", "auto")
	return value if value is String and value in ["auto", "on", "off"] else "auto"


## [QoL] `Touch controls` on the Options screen — `auto`, `on` or `off`;
## see the `TouchControls` autoload for what each means. `auto` by
## default: a desk with a mouse never sees the layer, a tablet always
## does, and neither has to be told.
static func touch_controls() -> String:
	var value: Variant = get_value("touch_controls", "auto")
	return value if value is String and value in ["auto", "on", "off"] else "auto"


## How the player's own hand renders on the duel screen:
## "stack" — the ORIGINAL's draggable list window, one name+cost strip per
##           card, enlarged card in the sidebar dock on hover (DEFAULT —
##           the faithful mode), or
## "fan"   — the arc of overlapping cards.
static func hand_style() -> String:
	return get_value("hand_style", "stack")


## One RULES FORK, by its RulesOptions key ("mana_burn",
## "attackers_revocable", ...). Where the 1997 ruleset and modern Magic
## disagree, the player chooses. The player default is
## RulesOptions.DEFAULT_PRESET — modern with mana burn on (2026-09-13
## playtest); the engine's own fresh state and its explicit Modern preset
## stay modern. An explicit saved false always wins, and reading never
## writes a default.
static func rule(key: String) -> bool:
	var defaults := RulesOptions.new()
	defaults.set_preset(RulesOptions.DEFAULT_PRESET)
	return get_value("rule_" + key, defaults.get_fork(key))


## Set one rules fork (see [method rule]). `persist` is [method set_value]'s:
## the Options screen's preset sets every fork in one gesture and writes
## the file once, through [method flush].
static func set_rule(key: String, value: bool, persist := true) -> void:
	set_value("rule_" + key, value, persist)


## Last dragged position of the stacked-hand window (see StackHand).
## Default per the owner's screenshots: right side, its title bar just
## BELOW the seam (the board's midpoint), growing downward.
static func hand_stack_pos() -> Vector2:
	return get_value("hand_stack_pos", Vector2(1062, 412))


## Last dragged position of the OPPONENT's hand window (the same
## StackHand, bar only while their hand is hidden). Default: where the
## board's own row used to hang the plate — bottom-right of the
## opponent's half, level with their creature row, clear of the player's
## window on the right — so nothing moves until it is dragged.
static func opp_hand_stack_pos() -> Vector2:
	return get_value("opp_hand_stack_pos", Vector2(918, 351))
