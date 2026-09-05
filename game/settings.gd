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
	_config.save(PATH)
	_dirty = false
	write_count += 1


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


## How the player's own hand renders on the duel screen:
## "stack" — the ORIGINAL's draggable list window, one name+cost strip per
##           card, enlarged card in the sidebar dock on hover (DEFAULT —
##           the faithful mode), or
## "fan"   — the arc of overlapping cards.
static func hand_style() -> String:
	return get_value("hand_style", "stack")


## One RULES FORK, by its RulesOptions key ("mana_burn",
## "attackers_revocable", ...). Where the 1997 ruleset and modern Magic
## disagree, the player chooses; the default is whatever RulesOptions
## itself defaults to, so this never invents an answer of its own.
static func rule(key: String) -> bool:
	return get_value("rule_" + key, RulesOptions.new().get_fork(key))


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
