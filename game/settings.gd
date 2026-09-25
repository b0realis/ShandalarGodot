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


static func _ensure() -> void:
	if _config == null:
		_config = ConfigFile.new()
		_config.load(PATH)   # missing file is fine — defaults apply
		_migrate_rules()


## The marker a file carries once [method _migrate_rules] has looked at it.
const RULES_REVISION_KEY := "rules_revision"
const RULES_REVISION := 2

## ONE fork changed its modern answer (2026-09-18): free combat damage
## division is now what modern Magic does too (Foundations, 2024), so a
## stored `rule_free_damage_assignment = false` written by an older
## build's "Modern rules" preset would keep the 2009-2024 order in force
## and show the preset as "Custom". If the other stored forks all read
## modern, that false was the preset's, not the player's, and it moves
## with the preset; a mixed file is a custom choice and is left alone.
## The marker means each file is looked at once.
static func _migrate_rules() -> void:
	if int(_config.get_value("options", RULES_REVISION_KEY, 1)) >= RULES_REVISION:
		return
	if not _config.has_section_key("options", "rule_free_damage_assignment"):
		return       # nothing stored: the built-in default applies
	var all_modern := not bool(_config.get_value("options", "rule_free_damage_assignment", true))
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		if key == "free_damage_assignment":
			continue
		# An unstored fork already reads modern; a stored one has to —
		# and "modern" here is the OLD answer, `not fifth_value` for every
		# fork, because that is what a revision-1 file was written under.
		if _config.has_section_key("options", "rule_" + key) \
				and bool(_config.get_value("options", "rule_" + key)) == bool(fork["fifth_value"]):
			all_modern = false
	if all_modern:
		_config.set_value("options", "rule_free_damage_assignment", true)
	_config.set_value("options", RULES_REVISION_KEY, RULES_REVISION)
	_save()


static func get_value(key: String, default_value):
	_ensure()
	return _config.get_value("options", key, default_value)


static func set_value(key: String, value, persist := true) -> void:
	_ensure()
	_config.set_value("options", key, value)
	if persist:
		_save()
	else:
		_dirty = true


static func _save() -> void:
	# [QoL] A failed write is still pending. Before this guard a blocked
	# settings.cfg reported `dirty=false counted_writes=1` (2026-09-13),
	# so leaving the options screen could never retry the player's change.
	var err := _config.save(PATH)
	_dirty = err != OK
	if err == OK:
		write_count += 1
	else:
		printerr("settings: cannot save %s (%s); changes remain pending" % [
			PATH, error_string(err)])


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
static func reload() -> void:
	_config = ConfigFile.new()
	_config.load(PATH)
	_dirty = false
	_migrate_rules()


## Remove a key so the built-in default applies again. Tests use this to
## leave no trace (writing the old value back would MATERIALIZE a default
## into the player's file — that bug shipped a "fan" hand once).
static func clear_value(key: String) -> void:
	_ensure()
	if _config.has_section_key("options", key):
		_config.erase_section_key("options", key)
		_save()


static func has_value(key: String) -> bool:
	_ensure()
	return _config.has_section_key("options", key)


# Typed accessors for the options the game actually has.

## Numbered gameplay card packs the player has switched on. Availability
## is deliberately NOT part of this value: keeping an id here means a pack
## the player enabled comes back on automatically when its ZIP returns.
static func enabled_card_packs() -> Array[String]:
	var raw: Variant = get_value("enabled_card_packs", [])
	var out: Array[String] = []
	if raw is Array or raw is PackedStringArray:
		for value in raw:
			var id := String(value).strip_edges()
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

## Seconds between AI actions in vs-AI play (demo mode has its own knob
## on the battle-setup screen).
static func ai_pace() -> float:
	return get_value("ai_pace", 0.35)


## [QoL] `Full screen` on the Options screen — see [GameDisplay] for what
## 1997 had instead (nothing but `M&inimize` and a frameless-window
## config key). Off by default: the shipped window is what the game has
## always opened into, and a default that changed under the owner would
## be a surprise, not a setting.
static func fullscreen() -> bool:
	return get_value("fullscreen", false)


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
## the Options screen's preset sets seven forks in one gesture and writes
## the file once, through [method flush].
static func set_rule(key: String, value: bool, persist := true) -> void:
	set_value("rule_" + key, value, persist)


## Last dragged position of the stacked-hand window (see StackHand).
## Default per the owner's screenshots: right side, its title bar just
## BELOW the seam (the board's midpoint), growing downward.
static func hand_stack_pos() -> Vector2:
	return get_value("hand_stack_pos", Vector2(1062, 412))
