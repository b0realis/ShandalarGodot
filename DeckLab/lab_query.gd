extends SceneTree
## LAB QUERY — the questions a program asks BEFORE it spends a run
## (2026-09-27), each answered as ONE JSON document on stdout and
## nothing else there:
##
##   DeckLab/lab_query.sh check DECK [DECK...] [--packs LIST] [--format NAME]
##   DeckLab/lab_query.sh packs
##   DeckLab/lab_query.sh cards NAME [NAME...]
##   DeckLab/lab_query.sh -h | --help
##
## `check` is the Lab's own deck loader as a REPORT rather than a
## refusal: every name the registry does not know, the pack that would
## supply it (or none — unimplemented or misspelled, with the nearest
## real names), the packs the deck needs and which of them are off, and
## whether it meets a format. `packs` is every pack this build knows —
## found or not, on or not, and why not. `cards` is a card's record:
## cost, types, text, the sets it is printed in, the pack it comes in.
##
## THE EXIT CODE says whether the question was answered, not what the
## answer was: 0 for an answer (a deck that cannot be played is an
## answer — `playable: false`), 2 for a line that could not be answered
## (no such deck file, an unknown verb, a bad --packs), 1 when the
## answer could not be written. A refusal is the Lab's envelope,
## `{"error": {...}}` ([method LabConsole.error_line]).

const Lab := preload("res://DeckLab/simulate.gd")

const VERBS := ["check", "packs", "cards"]

const HELP := """Lab Query — the questions a program asks before it spends a run
=================================================================
Each answers with one JSON document on stdout, and nothing else there.

USAGE
  DeckLab/lab_query.sh check DECK [DECK...] [--packs LIST] [--format NAME]
  DeckLab/lab_query.sh packs
  DeckLab/lab_query.sh cards NAME [NAME...]
  DeckLab/lab_query.sh -h | --help

VERBS
  check   Load each DECK the way the Deck Lab would (a path, tried as
          typed and then under decks/) and report instead of refusing:
            name, cards, sideboard  the deck as parsed
            errors                  lines that are not 'COUNT Card Name'
            unknown                 names the card pool does not know —
                                    each with its count, the pack that
                                    supplies it (`pack`, "" for none:
                                    unimplemented or misspelled) and, for
                                    those, the nearest real names (`near`)
            packs_needed            the packs the deck's cards come in
            packs_missing           those of them not in play
            format                  {name, ok, problem} with --format
            playable                no errors, no unknown names, the
                                    format met — what the Lab would play
          plus `playable` over every deck. --packs is the Lab's own
          switch (all|none|LIST) and holds for this one answer.
  packs   Every card pack this build knows: id, label, whether the zip
          was found (`available`, with `path` and `rejection`), whether
          it is on (`enabled`), and for a found pack its sets and card
          count. `available`, `enabled` and `known` are the id lists.
  cards   One record per NAME: known or not; for a known card its cost,
          mana value, colors, types, power/toughness, keywords, text,
          set, the sets it is printed in, rarity and the pack it comes
          in; for an unknown one the pack that would supply it and the
          nearest real names.

EXIT CODES
  0  answered (a deck that cannot be played is an answer: playable false)
  2  the line could not be answered: unknown verb, no such deck file, a
     bad --packs or --format — {"error": {...}} on stdout, the Lab's own
  1  the answer could not be written
"""

var last_error: Dictionary = {}
var last_answer: Dictionary = {}
var _packs_in_force: Variant = null


func _initialize() -> void:
	# THE AUTOLOADS ARE NOT READY YET (the AutoDeck CLI's own note): the
	# answer waits a frame for CardPacks to have had its `_ready`.
	_run.call_deferred()


func _run() -> void:
	quit(Lab.exit_code_of(_main(OS.get_cmdline_user_args())))


func _refuse(exit: int, message: String, detail: Dictionary = {}) -> int:
	printerr("lab_query: %s" % message)
	last_error = LabConsole.error_record("lab_query", exit, message, detail)
	print(JSON.stringify({"error": last_error}))
	return exit


func _answer(answer: Dictionary) -> int:
	last_answer = answer
	print(JSON.stringify(answer, "  "))
	return 0


func _main(argv: PackedStringArray) -> int:
	if argv.is_empty() or argv[0] == "-h" or argv[0] == "--help":
		print(HELP)
		return 0
	var verb := String(argv[0])
	if not VERBS.has(verb):
		var near := LabConsole.closest(verb, PackedStringArray(VERBS), 1, 0.4)
		var detail := {"kind": "option", "verb": verb}
		if not near.is_empty():
			detail["suggestions"] = Array(near)
		return _refuse(2, "unknown query '%s' — the verbs are %s" % [verb, ", ".join(VERBS)],
			detail)
	# THE SWITCHES, the Lab's own two: --packs first, since a deck of Ice
	# Age cards is a deck of proxies until the pack is in the registry.
	var words: Array = []
	var format := ""
	var i := 1
	while i < argv.size():
		var arg := String(argv[i])
		if arg == "--packs" or arg == "--format":
			if i + 1 >= argv.size():
				return _refuse(2, "%s needs a value" % arg, {"kind": "option", "flag": arg})
			var value := String(argv[i + 1])
			i += 2
			if arg == "--packs":
				var chosen: Dictionary = Lab.parse_packs(value, Lab.available_packs())
				if chosen.has("error"):
					return _refuse(2, chosen.error, {"kind": "packs", "flag": "--packs"})
				var refusal: String = Lab.enable_packs(chosen.ids)
				if refusal != "":
					return _refuse(2, refusal, {"kind": "packs", "flag": "--packs"})
				_packs_in_force = chosen.ids
			else:
				format = String(Lab.FORMAT_FLAGS.get(value.to_lower(), ""))
				if format == "":
					return _refuse(2, "unknown format '%s' (try %s)" % [value,
						", ".join(Lab.FORMAT_FLAGS.keys())], {"kind": "option", "flag": "--format"})
			continue
		if arg.begins_with("--"):
			return _refuse(2, "unknown option '%s' — %s takes --packs and --format" % [arg, verb],
				{"kind": "option", "flag": arg})
		words.append(arg)
		i += 1
	CardRegistry.ensure_loaded()
	match verb:
		"check":
			if words.is_empty():
				return _refuse(2, "check needs at least one deck file", {"kind": "option"})
			return _check(words, format)
		"packs":
			return _answer(_packs())
		"cards":
			if words.is_empty():
				return _refuse(2, "cards needs at least one card name", {"kind": "option"})
			return _cards(words)
	return 2


# ------------------------------------------------------------- check --

func _check(paths: Array, format: String) -> int:
	var lab = Lab.new()
	var rows: Array = []
	var every_playable := true
	for typed in paths:
		var path := String(typed)
		var tries := [path, "decks/" + path, "res://decks/" + path]
		var found := ""
		for candidate in tries:
			if FileAccess.file_exists(candidate):
				found = candidate
				break
		if found == "":
			var near: PackedStringArray = Lab.suggest_decks(path, lab._every_shipped_deck())
			var detail := {"kind": "deck", "path": path, "tried": tries,
				"folder": DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(path))}
			if not near.is_empty():
				detail["suggestions"] = Array(near)
			lab.free()
			return _refuse(2, "deck file not found: '%s'" % path, detail)
		var row := deck_report(found, format)
		row["file"] = path
		every_playable = every_playable and bool(row.playable)
		rows.append(row)
	lab.free()
	return _answer({"tool": "lab_query", "query": "check",
		"packs": _packs_in_force, "packs_on": Lab.packs_on(),
		"format": format, "decks": rows, "playable": every_playable})


## One deck's report — the Lab's loader as data. Lenient, so the names
## the registry does not know are listed rather than refused.
static func deck_report(path: String, format: String) -> Dictionary:
	var deck := DeckList.load_file(path, false)
	var packs := Lab.card_packs()
	var distinct: Array[String] = []
	var counts := {}
	var sides := {}
	for name in deck.cards:
		counts[name] = int(counts.get(name, 0)) + 1
		if not distinct.has(name):
			distinct.append(name)
	for name in deck.sideboard:
		sides[name] = int(sides.get(name, 0)) + 1
		if not distinct.has(name):
			distinct.append(name)
	var unknown: Array = []
	for name in deck.proxies:
		var where := "main" if not sides.has(name) else ("sideboard" if not counts.has(name) else "both")
		var entry := {"name": name, "count": int(counts.get(name, 0)) + int(sides.get(name, 0)),
			"where": where, "pack": pack_of_name(name, packs)}
		if entry.pack == "":
			entry["near"] = Array(near_names(name))
		unknown.append(entry)
	var needed: Array = []
	if packs != null:
		needed = Array(packs.packs_required_by(distinct))
	for id in deck.required_packs:
		if not needed.has(id):
			needed.append(id)
	var missing: Array = []
	for id in needed:
		if packs == null or not packs.is_enabled(String(id)):
			missing.append(id)
	var row := {"path": path, "name": deck.deck_name,
		"cards": deck.cards.size(), "sideboard": deck.sideboard.size(),
		"errors": Array(deck.errors), "unknown": unknown,
		"packs_needed": needed, "packs_missing": missing}
	var format_ok := true
	if format != "":
		var problem := DeckFormat.legal(deck.cards, format, deck.sideboard)
		format_ok = problem == ""
		row["format"] = {"name": format, "ok": format_ok, "problem": problem}
	row["playable"] = deck.errors.is_empty() and unknown.is_empty() and format_ok
	return row


## The pack that supplies [param name], or "" when none does — then the
## name is unimplemented or misspelled.
static func pack_of_name(name: String, packs: Node) -> String:
	if packs == null:
		return ""
	var one: Array[String] = [name]
	var ids: Array = packs.packs_required_by(one)
	return "" if ids.is_empty() else String(ids[0])


## The nearest real names to a misspelt one, by the parser's own
## measure — three at most, none below half a match.
static func near_names(name: String) -> PackedStringArray:
	return LabConsole.closest(name, PackedStringArray(CardRegistry.all_names()), 3, 0.5, 0.15)


# ------------------------------------------------------------- packs --

func _packs() -> Dictionary:
	var packs := Lab.card_packs()
	var rows: Array = []
	var known: Array = []
	var available: Array = Lab.available_packs()
	var enabled: Array = []
	if packs != null:
		known = Array(packs.known_ids())
		for id in known:
			var status: Dictionary = packs.status(String(id))
			var row := {"id": id, "label": packs.label_for(String(id)),
				"available": bool(status.get("available", false)),
				"enabled": bool(status.get("enabled", false)),
				"path": ProjectSettings.globalize_path(String(status.get("path", ""))),
				"rejection": String(status.get("rejection", ""))}
			if row.available:
				var sets: Array = []
				var entries: Array = packs.entry_records(String(id))
				for entry in entries:
					var code := String(entry.get("set", ""))
					if code != "" and not sets.has(code):
						sets.append(code)
				sets.sort()
				row["sets"] = sets
				row["cards"] = entries.size()
			if row.enabled:
				enabled.append(id)
			rows.append(row)
	return {"tool": "lab_query", "query": "packs", "known": known,
		"available": available, "enabled": enabled, "packs": rows}


# ------------------------------------------------------------- cards --

func _cards(names: Array) -> int:
	var rows: Array = []
	for name in names:
		rows.append(card_report(String(name)))
	return _answer({"tool": "lab_query", "query": "cards",
		"packs": _packs_in_force, "packs_on": Lab.packs_on(), "cards": rows})


static func card_report(name: String) -> Dictionary:
	var packs := Lab.card_packs()
	if not CardRegistry.has_card(name):
		return {"name": name, "known": false, "pack": pack_of_name(name, packs),
			"near": Array(near_names(name))}
	var data: CardData = CardRegistry.get_card(name)
	var types: Array = []
	for label in Mtg.CardType:
		if data.types & int(Mtg.CardType[label]):
			types.append(String(label).capitalize())
	var supertypes: Array = []
	for label in Mtg.Supertype:
		if data.supertypes & int(Mtg.Supertype[label]):
			supertypes.append(String(label).capitalize())
	var colors: Array = []
	var mask := data.cost.color_mask() if data.cost != null else 0
	for color in Mtg.WUBRG:
		if mask & color:
			colors.append(String(Mtg.COLOR_NAMES[color]))
	var keywords: Array = []
	for keyword in data.keywords:
		keywords.append(String(Mtg.Keyword.keys()[int(keyword)]).capitalize())
	var sets: Array = []
	for code in CardRegistry.active_set_order():
		if CardRegistry.card_in_set(name, code):
			sets.append(code)
	var row := {"name": data.card_name, "known": true,
		"cost": str(data.cost) if data.cost != null else "",
		"mana_value": data.cost.mana_value() if data.cost != null else 0,
		"colors": colors, "types": types, "supertypes": supertypes,
		"subtypes": Array(data.subtypes), "keywords": keywords,
		"text": data.oracle_text, "set": data.set_code, "sets": sets,
		"rarity": CardRegistry.rarity_of(name),
		"pack": pack_of_name(name, packs)}
	if data.types & Mtg.CardType.CREATURE:
		row["power"] = data.power
		row["toughness"] = data.toughness
	return row
