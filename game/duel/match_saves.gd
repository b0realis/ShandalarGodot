class_name MatchSaves
extends RefCounted
## SAVED BETWEEN DUELS — a best-of match ([MatchScreen]) and a Gauntlet run
## ([GauntletScreen]), each kept in a file of its own after every duel and
## taken up again later. The owner, 2026-10-28 (round "open items"):
## *"Saving: between duels (Gauntlet runs and matches save after each duel
## and resume); no mid-duel save."*
##
## 1997 HAD THE VERBS AND NOT THIS SHAPE. `&Save match` / `&Save gauntlet`
## stood on the between-duels window (`@DIALOG_ENDEXP1DUEL_BUTTONS`,
## `Program/UIStrings.txt:564-571`), `&Load gauntlet...` on the shell page
## and `&Load saved game...` on the startup screen, and the files were
## `MtG Saved Match` / `MtG Saved Gauntlet` (`@SAVEGAMEFILETYPE`,
## `:165-170`; docs/gauntlet-design.md §1.8). Its format was never read out
## of the binary and is not followed. OURS [ours]: no Save button and no
## file box — ONE file for the match and one for the run, written at every
## save point, offered again by the screen the player starts one from
## (`Resume match` on Magic Battle, the Gauntlet's own window).
##
## THE SAVE POINTS — between duels, never inside one:
##  - a match: when a duel is recorded (after the computer has sideboarded),
##    when a player's Sideboard window closes, and when it is taken up again
##    (the resume is counted, see below); a match that is decided drops its
##    file;
##  - a Gauntlet run: its match's points, the run around them, and after
##    each match while the run goes on; a run that ends (a match lost, the
##    last one won, an opponent's deck refused) drops its file. Both at the
##    moment the deciding duel is recorded, before its End of Duel window
##    closes (the bug campaign of 0.50.65, k4-1). An opponent whose deck
##    needs a pack switched off refuses its round and keeps the file (k4-2).
##    `Quit Gauntlet`, `Quit match` and leaving from inside a duel keep the file:
##    the run or the match is taken up from its last save point, and the
##    duel that was in play is not kept.
##
## A NEW MATCH OR RUN REPLACES THE SAVED ONE only when it saves (after its
## first duel), and a finished one drops the file only when the file is its
## own ([method clear_match], by id) — so starting one and leaving before
## its first duel ends loses nothing that was saved.
##
## A RESUMED DUEL IS DEALT AFRESH [ours]. Each duel's seed is drawn from the
## match's stream (and each match's from the run's), so a save point taken
## up twice would deal the same duel twice — the same opening hands, the
## same draws — and a player who quit a duel going badly would know them.
## The file counts how often its point has been taken up (`resumes`) and
## that many seeds are passed over before the next one is drawn: still one
## stream, still reproducible from the file, never the deal that was quit.
##
## WRITTEN WHOLE OR NOT AT ALL: through [method Settings.write_atomically]
## and read back ([method _write]). READ SAFELY ([method match_from_json],
## [method gauntlet_from_json]): field by field; a file that cannot be
## taken up — not JSON, another format, a newer version, a match already
## decided, a deck with no cards — is SET ASIDE as `<file>.bad` (`.bad2`
## …), as the settings file and the Hall of Fame are, and the screen says
## so once ([method set_aside_note]). A save holding a card this game does
## not have now (its pack switched off) is not taken up: [method
## cards_refusal] says which pack (the owner, same round: *"Packs in old
## saves: resume with a notice (a missing pack refuses and says which)"*).

## The two files, and where the tests point them.
const MATCH_FILE := "user://saved_match.json"
const GAUNTLET_FILE := "user://saved_gauntlet.json"
static var match_file := MATCH_FILE
static var gauntlet_file := GAUNTLET_FILE
## Each file's own name and version, first in it.
const MATCH_FORMAT := "shandalar-saved-match"
const GAUNTLET_FORMAT := "shandalar-saved-gauntlet"
const FORMAT_VERSION := 1
const MATCH_ABOUT := "A best-of match from Magic Battle, saved after its last duel: the two seats, their decks as they stand now, the record so far, and the stream the next duel's seed is drawn from. Resume match on Magic Battle takes it up again."
const GAUNTLET_ABOUT := "A Gauntlet run, saved after its last duel: your deck, the opponents in the order they are met, the round, the record, and the match in play if one is. The Gauntlet takes it up again."

## What a read found ([method read_match], [method read_gauntlet]).
const NONE := 0
const READY := 1
const SET_ASIDE := 2

## The four presets a seat can be piloted by — the names [AiProfile] gives
## them, which is all a save writes of a pilot.
const PILOTS: Array[String] = ["Apprentice", "Magician", "Sorcerer", "Wizard"]
## The most a saved life total, a pace or a count is believed.
const MOST_LIFE := 999
const MOST_COUNT := 9999


# --------------------------------------------------------------- reading --

## THE SAVED MATCH at [param path] ([member match_file] when ""):
## `{status, aside, match, summary, game_version}` — [constant NONE] (no
## file), [constant READY] (`match` is [method match_from_json]'s, `summary`
## its lines for the screen) or [constant SET_ASIDE] (a file that could not
## be taken up, moved to `aside` — "" when even that failed).
static func read_match(path := "") -> Dictionary:
	var at := path if path != "" else match_file
	var out := {"status": NONE, "aside": "", "match": {}, "summary": [] as Array[String],
		"game_version": ""}
	if not FileAccess.file_exists(at):
		return out
	var data := _parsed(at, MATCH_FORMAT)
	var taken := match_from_json(data.get("match"))
	if taken.is_empty():
		out["status"] = SET_ASIDE
		out["aside"] = _set_aside(at)
		return out
	out["status"] = READY
	out["match"] = taken
	out["game_version"] = _text(data.get("game_version"))
	out["summary"] = match_summary(taken, String(out["game_version"]))
	return out


## THE SAVED GAUNTLET RUN at [param path] ([member gauntlet_file] when ""),
## as [method read_match] answers, the run under `run`
## ([method gauntlet_from_json]).
static func read_gauntlet(path := "") -> Dictionary:
	var at := path if path != "" else gauntlet_file
	var out := {"status": NONE, "aside": "", "run": {}, "summary": [] as Array[String],
		"game_version": ""}
	if not FileAccess.file_exists(at):
		return out
	var data := _parsed(at, GAUNTLET_FORMAT)
	var taken := gauntlet_from_json(data)
	if taken.is_empty():
		out["status"] = SET_ASIDE
		out["aside"] = _set_aside(at)
		return out
	out["status"] = READY
	out["run"] = taken
	out["game_version"] = _text(data.get("game_version"))
	out["summary"] = gauntlet_summary(taken, String(out["game_version"]))
	return out


## The file at [param path] as JSON of [param format], `{}` when it is not:
## not JSON, another format, or a version this build does not read.
static func _parsed(path: String, format: String) -> Dictionary:
	var bytes := _bytes_at(path)
	if bytes.is_empty():
		return {}
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK or not json.data is Dictionary:
		return {}
	var data: Dictionary = json.data
	if _text(data.get("format")) != format or not _is_number(data.get("version")) \
			or _number(data.get("version")) < 1 or _number(data.get("version")) > FORMAT_VERSION:
		return {}
	return data


## A match taken out of its JSON: `{config: DuelConfig, state: MatchState,
## seeder_state: int, resumes: int, memories: [AiMatchMemory or null, ×2]}`
## — or `{}` when it cannot be taken up (no deck, a length that is not a
## match, a match already decided).
static func match_from_json(value: Variant) -> Dictionary:
	if not value is Dictionary:
		return {}
	var saved := value as Dictionary
	var config := config_from_json(saved.get("config"))
	if config == null or not config.best_of in MatchState.LENGTHS:
		return {}
	var record: Variant = saved.get("record")
	if not record is Dictionary:
		return {}
	var state := MatchState.new()
	state.best_of = config.best_of
	state.sideboard_between_duels = config.sideboard_between_duels
	var wins := _counts((record as Dictionary).get("wins"))
	if wins.is_empty():
		return {}
	state.wins = wins
	state.draws = _count((record as Dictionary).get("draws"))
	var last := _number((record as Dictionary).get("last_winner"))
	state.last_winner = last if last in [MatchState.NO_DUEL, -1, 0, 1] else MatchState.NO_DUEL
	state.human_seat = clampi(_number((record as Dictionary).get("human_seat")), 0, 1)
	if state.duels_played() == 0 or state.is_over():
		return {}
	var seeder: Variant = _big(saved.get("seeder_state"))
	if seeder == null:
		return {}
	var memories: Array = [null, null]
	var minds: Variant = saved.get("memories")
	for pid in 2:
		if not config.is_ai(pid):
			continue
		var memory := AiMatchMemory.new(pid)
		memory.duels = state.duels_played()
		if minds is Array and pid < (minds as Array).size() and (minds as Array)[pid] is Dictionary:
			_memory_from_json(memory, (minds as Array)[pid])
		memories[pid] = memory
	return {"config": config, "state": state, "seeder_state": int(seeder),
		"resumes": _count(saved.get("resumes")), "memories": memories}


## A run taken out of its file's JSON: `{id, state: GauntletState, config:
## DuelConfig, options: GauntletOptions, rng_state: int, resumes: int,
## match: (a [method match_from_json], or `{}` between matches)}` — or `{}`
## when it cannot be taken up (no opponents, a round past the run, a run
## already over).
static func gauntlet_from_json(data: Dictionary) -> Dictionary:
	if data.is_empty():
		return {}
	var run: Variant = data.get("run")
	if not run is Dictionary:
		return {}
	var state := GauntletState.new()
	var order: Variant = (run as Dictionary).get("order")
	if not order is Array or (order as Array).is_empty() \
			or (order as Array).size() > GauntletState.MAX_OPPONENTS:
		return {}
	for path in order:
		if not path is String or String(path) == "":
			return {}
		state.order.append(String(path))
	var names: Variant = (run as Dictionary).get("names")
	if names is Dictionary:
		for path in names:
			if path is String and state.order.has(path) and names[path] is String:
				state.names[String(path)] = String(names[path])
	state.start = _number((run as Dictionary).get("start"))
	state.round_number = _number((run as Dictionary).get("round"))
	if state.start < 0 or state.start >= state.order.size() \
			or state.round_number < 1 or state.round_number > state.order.size():
		return {}
	state.wins = _count((run as Dictionary).get("wins"))
	state.losses = _count((run as Dictionary).get("losses"))
	state.ties = _count((run as Dictionary).get("ties"))
	var config := config_from_json(data.get("config"))
	if config == null or not config.best_of in GauntletOptions.MATCH_SIZES:
		return {}
	var options := _options_from_json(data.get("options"), config)
	var rng: Variant = _big(data.get("rng_state"))
	if rng == null:
		return {}
	var in_play := {}
	if data.get("match") != null:
		in_play = match_from_json(data.get("match"))
		if in_play.is_empty():
			return {}
	var id := _text(data.get("id"))
	if id == "":
		return {}
	return {"id": id, "state": state, "config": config, "options": options,
		"rng_state": int(rng), "resumes": _count(data.get("resumes")), "match": in_play}


## A [DuelConfig] out of [method config_json]'s answer, or null when it has
## no deck to deal to a seat. Every other field is read as its kind, its
## default otherwise.
static func config_from_json(value: Variant) -> DuelConfig:
	if not value is Dictionary:
		return null
	var saved := value as Dictionary
	var config := DuelConfig.new()
	for pid in 2:
		var deck := _names_at(saved.get("decks"), pid)
		if deck.is_empty():
			return null
		config.decks[pid] = deck
		config.sideboards[pid] = _names_at(saved.get("sideboards"), pid)
		var printings: Variant = _at(saved.get("printings"), pid)
		config.printings[pid] = DeckPrintings.keep_present(printings, deck + config.sideboards[pid]) \
			if printings is Dictionary else {}
		var seat_name := _text(_at(saved.get("player_names"), pid)).left(64)
		config.player_names[pid] = seat_name if seat_name != "" else DuelConfig.seat_label(pid)
		config.deck_names[pid] = _text(_at(saved.get("deck_names"), pid)).left(128)
		config.portraits[pid] = _text(_at(saved.get("portraits"), pid)).left(128)
		var life: Variant = _at(saved.get("lives"), pid)
		config.lives[pid] = clampi(_number(life), 1, MOST_LIFE) if _is_number(life) else 20
		var color := _text(_at(saved.get("panel_colors"), pid))
		config.panel_colors[pid] = color if color != "" else DuelConfig.dominant_color(deck)
		config.unfair[pid] = _flag(_at(saved.get("unfair"), pid))
		var pilot: Variant = _at(saved.get("pilots"), pid)
		config.pilots[pid] = null if pilot == null else _pilot(_text(pilot))
	config.hotseat_privacy = _flag(saved.get("hotseat_privacy"))
	var pace: Variant = saved.get("pace")
	config.pace = clampf(float(pace), 0.0, 5.0) if _is_number(pace) else 0.35
	config.ante = clampi(_number(saved.get("ante")), 0, 1)
	var format := _text(saved.get("deck_format"))
	config.deck_format = format if format in DeckFormat.ORDER else DeckFormat.UNRESTRICTED
	config.best_of = _number(saved.get("best_of"))
	config.sideboard_between_duels = _flag(saved.get("sideboard_between_duels"))
	var seed: Variant = _big(saved.get("rng_seed"))
	config.rng_seed = int(seed) if seed != null else 0
	config.record_match = _text(saved.get("record_match")).left(64)
	config.record_started = _text(saved.get("record_started")).left(64)
	return config


## A seat's pilot by its preset's name; a name this build does not know is
## the strongest, as the battle-setup screen's own default.
static func _pilot(profile_name: String) -> AiProfile:
	match profile_name:
		"Apprentice":
			return AiProfile.apprentice()
		"Magician":
			return AiProfile.magician()
		"Sorcerer":
			return AiProfile.sorcerer()
	return AiProfile.wizard()


static func _memory_from_json(memory: AiMatchMemory, saved: Dictionary) -> void:
	var seen: Variant = saved.get("seen")
	if seen is Dictionary:
		for card_name in seen:
			if card_name is String and _is_number(seen[card_name]):
				memory.seen[String(card_name)] = clampi(_number(seen[card_name]), 0, MOST_COUNT)
	var damage: Variant = saved.get("damage_by_color")
	if damage is Dictionary:
		for color in damage:
			if String(color).is_valid_int() and _is_number(damage[color]):
				memory.damage_by_color[String(color).to_int()] = clampi(_number(damage[color]), 0, MOST_COUNT * 100)
	if _is_number(saved.get("duels")):
		memory.duels = clampi(_number(saved.get("duels")), 0, MOST_COUNT)


static func _options_from_json(value: Variant, config: DuelConfig) -> GauntletOptions:
	var options := GauntletOptions.new()
	options.best_of = config.best_of
	options.ante = config.ante > 0
	options.sideboard_between_duels = config.sideboard_between_duels
	options.unfair = config.unfair[1]
	if value is Dictionary:
		var saved := value as Dictionary
		options.enemy_level = clampi(_number(saved.get("enemy_level")), 0, 3) \
			if _is_number(saved.get("enemy_level")) else options.enemy_level
		options.num_opponents = clampi(_number(saved.get("num_opponents")), 0, GauntletState.MAX_OPPONENTS)
		options.your_deck = _text(saved.get("your_deck"))
	return options


# --------------------------------------------------------------- writing --

## [param config] as JSON — what [method config_from_json] reads back.
## Seeds go as text: JSON's numbers are doubles, and a 64-bit seed is not.
static func config_json(config: DuelConfig) -> Dictionary:
	var pilots := []
	for pid in 2:
		var pilot: AiProfile = config.pilots[pid] as AiProfile
		pilots.append(null if pilot == null else pilot.profile_name)
	return {"decks": [_plain(config.decks[0]), _plain(config.decks[1])],
		"sideboards": [_plain(config.sideboards[0]), _plain(config.sideboards[1])],
		"printings": [(config.printings[0] as Dictionary).duplicate(),
			(config.printings[1] as Dictionary).duplicate()],
		"player_names": _plain(config.player_names), "deck_names": _plain(config.deck_names),
		"portraits": _plain(config.portraits), "lives": [config.lives[0], config.lives[1]],
		"pilots": pilots, "hotseat_privacy": config.hotseat_privacy,
		"unfair": [config.unfair[0], config.unfair[1]], "panel_colors": _plain(config.panel_colors),
		"pace": config.pace, "ante": config.ante, "deck_format": config.deck_format,
		"best_of": config.best_of, "sideboard_between_duels": config.sideboard_between_duels,
		"rng_seed": str(config.rng_seed), "record_match": config.record_match,
		"record_started": config.record_started}


## A match as JSON — its config with the decks as they stand now, its
## record, the stream its next duel's seed comes from, how often this point
## has been taken up, and what each computer seat has seen.
static func match_json(config: DuelConfig, state: MatchState, seeder_state: int,
		resumes: int, memories: Array) -> Dictionary:
	var minds := []
	for pid in 2:
		var memory: AiMatchMemory = memories[pid] as AiMatchMemory if pid < memories.size() else null
		if memory == null:
			minds.append(null)
			continue
		var damage := {}
		for color in memory.damage_by_color:
			damage[str(color)] = int(memory.damage_by_color[color])
		minds.append({"seen": memory.seen.duplicate(), "damage_by_color": damage,
			"duels": memory.duels})
	return {"config": config_json(config),
		"record": {"wins": [state.wins[0], state.wins[1]], "draws": state.draws,
			"last_winner": state.last_winner, "human_seat": state.human_seat},
		"seeder_state": str(seeder_state), "resumes": resumes, "memories": minds}


## A run as its file's JSON, [param in_play] the match in play ([method
## match_json]) or `{}` between matches.
static func gauntlet_json(id: String, state: GauntletState, config: DuelConfig,
		options: GauntletOptions, rng_state: int, resumes: int, in_play: Dictionary) -> Dictionary:
	return {"id": id,
		"run": {"order": _plain(state.order), "names": state.names.duplicate(),
			"start": state.start, "round": state.round_number, "wins": state.wins,
			"losses": state.losses, "ties": state.ties},
		"config": config_json(config),
		"options": {"enemy_level": options.enemy_level, "num_opponents": options.num_opponents,
			"your_deck": options.your_deck},
		"rng_state": str(rng_state), "resumes": resumes,
		"match": null if in_play.is_empty() else in_play}


## THE MATCH [param snapshot] ([method match_json]) written at [param path]
## ([member match_file] when ""), whole or not at all. False when it could
## not be (the file then as it was).
static func write_match(snapshot: Dictionary, path := "") -> bool:
	var at := path if path != "" else match_file
	var config: Variant = snapshot.get("config")
	var id := _text((config as Dictionary).get("record_match")) if config is Dictionary else ""
	return _write(at, {"format": MATCH_FORMAT, "version": FORMAT_VERSION, "about": MATCH_ABOUT,
		"game_version": _game_version(), "saved": Time.get_datetime_string_from_system(true) + "Z",
		"id": id, "match": snapshot}, MATCH_FORMAT)


## THE RUN [param snapshot] ([method gauntlet_json]) written at [param path]
## ([member gauntlet_file] when ""), as [method write_match].
static func write_gauntlet(snapshot: Dictionary, path := "") -> bool:
	var at := path if path != "" else gauntlet_file
	var data := snapshot.duplicate()
	data["format"] = GAUNTLET_FORMAT
	data["version"] = FORMAT_VERSION
	data["about"] = GAUNTLET_ABOUT
	data["game_version"] = _game_version()
	data["saved"] = Time.get_datetime_string_from_system(true) + "Z"
	return _write(at, data, GAUNTLET_FORMAT)


## The saved match dropped — only when it is match [param id]'s own: a new
## match that ends before it ever saved leaves the one saved before it.
static func clear_match(id: String, path := "") -> void:
	_clear(path if path != "" else match_file, id, MATCH_FORMAT)


## The saved run dropped — only when it is run [param id]'s own.
static func clear_gauntlet(id: String, path := "") -> void:
	_clear(path if path != "" else gauntlet_file, id, GAUNTLET_FORMAT)


static func _clear(path: String, id: String, format: String) -> void:
	if id == "" or not FileAccess.file_exists(path):
		return
	if _text(_parsed(path, format).get("id")) == id:
		DirAccess.remove_absolute(path)


## [param data] written at [param path] as [param format]'s file: a file
## already there that cannot be read is set aside first, never written
## over; then aside, checked, renamed into place, and read back.
static func _write(path: String, data: Dictionary, format: String) -> bool:
	if FileAccess.file_exists(path) and _parsed(path, format).is_empty():
		_set_aside(path)
	var bytes := JSON.stringify(data, "\t").to_utf8_buffer()
	if not _folder_ready(path.get_base_dir()) or Settings.write_atomically(path, bytes) != OK \
			or _bytes_at(path) != bytes:
		push_warning("MatchSaves: cannot write %s" % path)
		return false
	return true


## The file at [param path], which cannot be taken up, kept aside as
## `<path>.bad` (or `.bad2`, `.bad3` … when that is taken): the name it is
## kept under, "" when it could not be moved.
static func _set_aside(path: String) -> String:
	var aside := path + ".bad"
	var n := 2
	while FileAccess.file_exists(aside):
		aside = "%s.bad%d" % [path, n]
		n += 1
	if DirAccess.rename_absolute(path, aside) != OK:
		push_warning("MatchSaves: cannot set %s aside" % path)
		return ""
	push_warning("MatchSaves: %s could not be read; kept as %s" % [path, aside])
	return aside


## Whether [param folder] is there, or is made now ([method
## HallOfFame._folder_ready]'s rule: quietly false when a file stands where
## a folder of the way should be).
static func _folder_ready(folder: String) -> bool:
	var at := folder
	while not DirAccess.dir_exists_absolute(at):
		if FileAccess.file_exists(at):
			return false
		var up := at.get_base_dir()
		if up == at or up == "":
			break
		at = up
	return DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) == OK


# ------------------------------------------------------------ the words --

## The sentence for a file set aside — what the screen says once, the
## moment it finds it ([param what]: "match", "run").
static func set_aside_note(aside: String, what: String) -> String:
	if aside == "":
		return "Your saved %s could not be read." % what
	return "Your saved %s could not be read. It is kept as %s." % [what,
		ProjectSettings.globalize_path(aside).get_file()]


## WHAT A SAVED MATCH IS, in lines for the screen that offers it: the
## record in the original's own sentence (`@DIALOG_ENDEXP1DUEL_MATCHPROGRESS`,
## [method MatchState.progress_line]), the duel that comes next, and the
## two seats.
static func match_summary(taken: Dictionary, game_version := "") -> Array[String]:
	var state: MatchState = taken["state"]
	var config: DuelConfig = taken["config"]
	var lines: Array[String] = [state.progress_line(), "Next: " + state.duel_heading(),
		"%s against %s" % [_seat(config, 0), _seat(config, 1)]]
	_version_line(lines, game_version)
	return lines


## WHAT A SAVED RUN IS: the round and the record (`@GAUNTLET`'s `Your
## record is %d/%d/%d`, the duels of the match in play counted in, as the
## round window will count them when it ends), then the match in play — its
## opponent and its next duel — or the opponent the next round meets (`Your
## next duel is against %s.`).
static func gauntlet_summary(taken: Dictionary, game_version := "") -> Array[String]:
	var state: GauntletState = taken["state"]
	var record := [state.wins, state.losses, state.ties]
	var in_play: Dictionary = taken["match"]
	if not in_play.is_empty():
		var tally: MatchState = in_play["state"]
		record = [state.wins + tally.wins[tally.human_seat],
			state.losses + tally.wins[1 - tally.human_seat], state.ties + tally.draws]
	var lines: Array[String] = ["Round %d of %d" % [state.round_number, state.length()],
		GauntletState.RECORD % record]
	if in_play.is_empty():
		lines.append(GauntletState.NEXT_IS % state.opponent_name())
	else:
		lines.append("In a match against %s: %s" % [state.opponent_name(),
			(in_play["state"] as MatchState).duel_heading()])
	_version_line(lines, game_version)
	return lines


## A save written by another version of the game says so — the notice the
## owner's ruling asks for; the pack check is [method cards_refusal].
static func _version_line(lines: Array[String], game_version: String) -> void:
	if game_version != "" and game_version != _game_version():
		lines.append("Saved by version %s." % game_version)


static func _seat(config: DuelConfig, pid: int) -> String:
	var who := String(config.player_names[pid])
	var deck := String(config.deck_names[pid])
	return who if deck == "" or deck == who else "%s (%s)" % [who, deck]


## EVERY CARD A SAVED MATCH WOULD DEAL: both decks and both sideboards.
static func match_card_names(taken: Dictionary) -> Array[String]:
	var out: Array[String] = []
	var config: DuelConfig = taken["config"]
	for pid in 2:
		for card_name in config.decks[pid] + config.sideboards[pid]:
			out.append(String(card_name))
	return out


## EVERY CARD A SAVED RUN WOULD DEAL: your deck and sideboard, the match
## in play's, and every opponent still to come, each read from its file as
## its round will deal it — leniently here, so a card of a pack switched
## off is a name to refuse by and not an error (the bug campaign of
## 0.50.65, k4-2: only the match in play was counted, so a run whose next
## opponent needed a pack switched off was offered, met that deck, and was
## ended and its file deleted). An opponent already met is not counted; a
## file that cannot be read at all adds nothing, and its round says so in
## `@GAUNTLETERRORS`' words ([GauntletScreen]).
static func gauntlet_card_names(taken: Dictionary) -> Array[String]:
	var config: DuelConfig = taken["config"]
	var out: Array[String] = []
	for card_name in config.decks[0] + config.sideboards[0]:
		out.append(String(card_name))
	var state: GauntletState = taken["state"]
	var first := state.round_number
	if not (taken["match"] as Dictionary).is_empty():
		out.append_array(match_card_names(taken["match"]))
		first += 1          # this round's opponent is the match's seat 1
	for which in range(first, state.length() + 1):
		var deck := DeckList.load_file(state.order[state.index_for_round(which)], false)
		for card_name in deck.cards + deck.sideboard:
			out.append(String(card_name))
	return out


## WHY A SAVE HOLDING [param names] CANNOT BE TAKEN UP NOW — "" when every
## card is in the pool. A card the pool lacks is almost always a pack
## switched off since the save: the pack is named ([param what] is the
## sentence's subject, "This match" / "This run"); a card no pack explains
## is named itself.
static func cards_refusal(names: Array[String], what: String) -> String:
	var lacking := ProxyCard.names_in(names)
	if lacking.is_empty():
		return ""
	var packs_off := packs_refusal(lacking, what)
	if packs_off != "":
		return packs_off
	return "%s holds cards this game does not have: %s." % [what, ", ".join(lacking)]


## THE PACK HALF OF [method cards_refusal]: the sentence naming the packs
## switched off that [param lacking] (names the pool does not hold) needs,
## or "" when no pack switched off explains them — a card no pack has, or
## no CardPacks to ask. Its own function so a Gauntlet round can tell a
## pack switched off from a broken deck (k4-2, [GauntletScreen]).
static func packs_refusal(lacking: Array[String], what: String) -> String:
	var packs := _card_packs()
	if packs == null or lacking.is_empty():
		return ""
	var missing: Array[String] = packs.missing_requirements(packs.packs_required_by(lacking))
	if missing.is_empty():
		return ""
	var labels := PackedStringArray()
	for id in missing:
		labels.append(String(packs.label_for(id)))
	return "%s needs %s, which is not enabled. Enable it under Options, Card packs, and come back." \
		% [what, ", ".join(labels)]


## The CardPacks autoload, reached through the tree at call time (an
## autoload named in a class a `-s` tool compiles is "Identifier not
## found" — CONTRIBUTING, the gotchas); null where it is not running.
static func _card_packs() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null(^"CardPacks") if tree != null else null


# -------------------------------------------------------------- helpers --

static func _game_version() -> String:
	return String(ProjectSettings.get_setting("application/config/version", ""))


static func _bytes_at(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var opened := FileAccess.open(path, FileAccess.READ)
	if opened == null:
		return PackedByteArray()
	var bytes := opened.get_buffer(opened.get_length())
	opened.close()
	return bytes


## [param list] as a plain Array (a typed one reads back untyped anyway).
static func _plain(list: Array) -> Array:
	var out := []
	for item in list:
		out.append(item)
	return out


## Seat [param pid]'s entry of a two-seat list, null when there is none.
static func _at(list: Variant, pid: int) -> Variant:
	if list is Array and pid < (list as Array).size():
		return (list as Array)[pid]
	return null


## Seat [param pid]'s card names, the non-text entries dropped.
static func _names_at(list: Variant, pid: int) -> Array[String]:
	var out: Array[String] = []
	var pile: Variant = _at(list, pid)
	if pile is Array:
		for card_name in pile:
			if card_name is String and String(card_name).strip_edges() != "" \
					and String(card_name).length() <= 128:
				out.append(String(card_name))
	return out


## Two counts, `[]` when the value is not two numbers.
static func _counts(value: Variant) -> Array[int]:
	if not value is Array or (value as Array).size() != 2 \
			or not _is_number((value as Array)[0]) or not _is_number((value as Array)[1]):
		return []
	return [_count((value as Array)[0]), _count((value as Array)[1])] as Array[int]


static func _count(value: Variant) -> int:
	return clampi(_number(value), 0, MOST_COUNT)


static func _flag(value: Variant) -> bool:
	return value is bool and bool(value)


static func _text(value: Variant) -> String:
	return String(value) if value is String else ""


## A 64-bit number written as text (a seed, a stream's state), or null.
static func _big(value: Variant) -> Variant:
	if value is String and String(value).is_valid_int():
		return String(value).to_int()
	return null


static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


static func _number(value: Variant) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(clampf(roundf(value), -9.0e15, 9.0e15))
	return 0
