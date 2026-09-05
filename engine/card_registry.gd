class_name CardRegistry
extends RefCounted
## The card database: every registered CardData, keyed by exact card name.
##
## Cards register themselves by existing as files: [method load_all_sets]
## scans every folder under res://cards/sets/, instantiates each .gd card
## file (they all extend CardScript), calls build(), and stores the result.
## The folder name becomes CardData.set_code, so "what set is this card in"
## is answered by the filesystem — one obvious place per card, no manifest
## to keep in sync.
##
## Loading is idempotent and lazy: MtgGame.setup calls
## [method ensure_loaded] so tests and tools never need explicit init.
## Everything here is static — the registry is process-global, like
## mage-go's card registry.

## name -> CardData
static var _cards: Dictionary = {}
static var _loaded: bool = false

## Root folder scanned for set subfolders.
const SETS_ROOT := "res://cards/sets"


## Load every set once per process. Safe to call repeatedly.
##
## It also builds the PRINTING INDEX up front ([method _ensure_printings]).
## That is not an optimisation: the index used to be built lazily on the
## first ask, and the first ask can come from a WORKER THREAD — City in a
## Bottle and Golgothian Sylex consult it mid-game and the Deck Lab runs
## games on a [WorkerThreadPool]. See _ensure_printings for what that cost.
static func ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_ensure_printings()
	var root := DirAccess.open(SETS_ROOT)
	if root == null:
		push_error("CardRegistry: cannot open %s" % SETS_ROOT)
		return
	root.list_dir_begin()
	var entry := root.get_next()
	while entry != "":
		if root.current_is_dir() and not entry.begins_with("."):
			_load_set(entry)
		entry = root.get_next()
	root.list_dir_end()


## DROP EVERY CARD BEFORE THE PROCESS ENDS — and the reason is a crash.
##
## Every headless run of this project used to end in SIGABRT (exit 134,
## `double free or corruption` / `corrupted size vs. prev_size`), and the
## windowed game aborted the same way on Exit. It was written off for
## weeks as the Compatibility renderer's GL teardown. It was not: a
## headless process has no GL, and a bisect (2026-09-02) showed an empty
## script exits 0, `MtgGame.new()` exits 0, and the first `get_card()`
## turns the exit into an abort. What corrupts the heap is THIS
## dictionary being destroyed during static-variable teardown, after the
## card scripts whose lambdas its [CardData]s hold Callables into have
## already been unloaded. Clearing it while the scripts are still alive
## is the whole fix.
##
## Called once, at the end of the process, by the `Lifecycle` autoload
## (`game/lifecycle.gd`) as the tree finalises — which covers the game,
## the test runner and every `extends SceneTree` tool without any of
## them having to remember. Safe to call twice, and [method ensure_loaded]
## rebuilds after it, so a test may call it too.
##
## THE RULE THIS IMPLIES FOR EVERY OTHER `static var`: none may hold a
## [CardData] (or a [CardInstance], or anything else carrying a card's
## Callables), because it would outlive this clear and abort the same
## way. The second review of 2026-09-02 found exactly one that did —
## `DeckFilter`'s facts table, keyed by the card objects — and every
## run that had opened the Deck Builder was still exiting 134 for it.
## Key such a cache by name or instance id, or clear it from `Lifecycle`.
static func unload() -> void:
	_cards.clear()
	_original_set.clear()
	_artists.clear()
	_loaded = false
	_printings_loaded = false
	ProxyCard.unload()


## The card-script names a raw directory listing stands for — deduped,
## in listing order, each one the path [method load] wants.
##
## A CHECKOUT and an EXPORTED BUILD do not list the same names for the
## same card. A checkout has `terror.gd` (and a `terror.gd.uid` sidecar);
## a `.pck` has `terror.gdc` AND `terror.gd.remap` and **no `terror.gd`
## at all** — Godot compiles every script into the pack and leaves the
## remap behind to redirect `load("res://cards/sets/2ed/terror.gd")`.
## Loading is therefore unaffected; only the LISTING changes, and a
## filter of `ends_with(".gd")` matches neither exported name.
##
## That is not a hypothetical: the first exported build (2026-09-03) ran
## with an EMPTY POOL. Every deck read as all-proxy and refused to start
## a duel, and the Deck Builder showed no cards — the registry had
## scanned all eight set folders and registered nothing.
static func card_files_in(entries: PackedStringArray) -> PackedStringArray:
	var seen := {}
	var out := PackedStringArray()
	for entry in entries:
		var name := entry
		if name.ends_with(".remap"):
			name = name.trim_suffix(".remap")
		elif name.ends_with(".gdc"):
			name = name.trim_suffix(".gdc") + ".gd"
		# `_shared.gd` is a helper, `terror.gd.uid` is a sidecar.
		if not name.ends_with(".gd") or name.begins_with("_"):
			continue
		if seen.has(name):
			continue
		seen[name] = true
		out.append(name)
	return out


## Load one set folder (e.g. "limited"): every card script inside is one
## card — see [method card_files_in] for what "card script" means in an
## exported build.
static func _load_set(set_code: String) -> void:
	var dir_path := "%s/%s" % [SETS_ROOT, set_code]
	var dir := DirAccess.open(dir_path)
	if dir == null:
		push_error("CardRegistry: cannot open set folder %s" % dir_path)
		return
	dir.list_dir_begin()
	var entries := PackedStringArray()
	var entry := dir.get_next()
	while entry != "":
		if not dir.current_is_dir():
			entries.append(entry)
		entry = dir.get_next()
	dir.list_dir_end()
	var files := card_files_in(entries)
	# A set folder with no cards in it is never a real state: it means the
	# listing shape changed under us again. Say so instead of shipping an
	# empty pool - `run_tests.sh` and `build_release.sh` both fail on an
	# ERROR line, so this cannot pass silently a second time.
	if files.is_empty():
		push_error("CardRegistry: no card scripts in %s (%d entries listed)"
			% [dir_path, entries.size()])
		return
	for file in files:
		var script: GDScript = load("%s/%s" % [dir_path, file])
		var card_script: CardScript = script.new()
		var data: CardData = card_script.build()
		if data == null:
			push_error("CardRegistry: %s/%s built null" % [set_code, file])
			continue
		data.set_code = set_code
		data.artist = artist_of(data.card_name, set_code)
		register(data)
		if data.oracle_text == "" and not data.is_land() \
				and data.spell_effects.is_empty() \
				and data.activated_abilities.is_empty() \
				and data.triggered_abilities.is_empty() \
				and data.static_abilities.is_empty() \
				and not data.is_creature():
			push_warning("CardRegistry: '%s' has no oracle text and no behavior" % data.card_name)


## Register one card. Registering the same name twice is an authoring error
## (two files claim one card) and fails loudly.
static func register(data: CardData) -> void:
	if _cards.has(data.card_name):
		push_error("CardRegistry: duplicate registration of '%s'" % data.card_name)
		return
	_cards[data.card_name] = data


## Fetch a card definition by exact name; errors (and returns null) on
## unknown names so deck typos surface immediately.
static func get_card(card_name: String) -> CardData:
	ensure_loaded()
	if not _cards.has(card_name):
		push_error("CardRegistry: unknown card '%s'" % card_name)
		return null
	return _cards[card_name]


## Quiet existence check (get_card errors loudly on unknown names —
## deck loaders that collect their own error reports use this instead).
static func has_card(card_name: String) -> bool:
	ensure_loaded()
	return _cards.has(card_name)


## All registered names, sorted — for deck validators, tools, and tests.
static func all_names() -> Array:
	ensure_loaded()
	var names := _cards.keys()
	names.sort()
	return names


## Number of registered cards.
static func size() -> int:
	ensure_loaded()
	return _cards.size()


# ------------------------------------------------- original printings (CR 201) --
# "A name originally printed in the Antiquities expansion" (Golgothian
# Sylex) / "in the Arabian Nights expansion" (City in a Bottle) is a
# statement about the CARD NAME's first printing, not about which folder our
# implementation happens to live in — Millstone is an Antiquities card that
# ships in cards/sets/4ed/, and Mountain appears in the Arabian Nights data
# but was printed in Alpha. The answer therefore comes from the Scryfall
# snapshot in cards/data/, read once and cached.

## The pool's expansions in PRINTING order (1993 → 1998). A name belongs to
## the first set in this list that contains it, which is why Mountain — in
## the Arabian Nights data as a basic land — resolves to 2ed and is not
## bottled by City in a Bottle. 4ed is an all-reprint set, so it only ever
## claims a name no earlier set has.
const SET_ORDER: Array[String] = ["2ed", "arn", "atq", "leg", "drk", "4ed", "past", "phpr"]

## card name -> set code of its first printing. Filled by
## [method _ensure_printings], which [method ensure_loaded] runs.
static var _original_set: Dictionary = {}


## Was [param card_name] originally printed in [param set_code]?
static func originally_printed_in(card_name: String, set_code: String) -> bool:
	_ensure_printings()
	return _original_set.get(card_name, "") == set_code


## THE ILLUSTRATOR CREDIT for [param card_name] — `Illus. <name>` on the
## enlarged card, part 6 of `Duel.hlp`'s "Parts of the Card".
##
## It comes from the same `cards/data/` Scryfall snapshot the printing
## order does, and for the same reason: it is a fact about a PRINTING, not
## behaviour, so it does not belong in a card's `build()`. Asking here
## keeps all 897 card files (and the generator that writes most of them)
## out of it entirely.
##
## [param set_code] is the folder the implementation ships in, and it wins
## when the snapshot has it: Fourth Edition reprints were often redrawn, so
## a card in `cards/sets/4ed/` must credit 4ed's artist and not Alpha's.
## A name the folder's own set does not list falls back to the first
## printing that does, in [constant SET_ORDER]. **A name nothing lists
## returns `""`**, which every caller must render as no credit at all.
static func artist_of(card_name: String, set_code := "") -> String:
	_ensure_printings()
	if set_code != "":
		var exact: String = _artists.get("%s|%s" % [set_code, card_name], "")
		if exact != "":
			return exact
	return _artists.get(card_name, "")


## card name -> artist, and "<set>|<name>" -> that printing's artist.
static var _artists: Dictionary = {}


## THE ONE PASS over `cards/data/` that fills both indexes, run from
## [method ensure_loaded] so it is complete before anything else can ask.
##
## THREAD SAFETY, and the bug that put this comment here. This was two
## lazy builders, each of which set its "loaded" flag BEFORE filling its
## dictionary. Two worker threads reaching one at the same time is a real
## Deck Lab shape (`tools/simulate.gd` fans games out over a
## WorkerThreadPool, and City in a Bottle / Golgothian Sylex ask
## `originally_printed_in` mid-game), and the second thread sailed past
## the flag and read an EMPTY index. Measured 2026-09-01 with an 8-thread
## probe on a cold index: **7 of 8 threads answered `false` for a card
## that is an Arabian Nights original**, and the process **segfaulted**
## within ten cold starts — two threads writing one Dictionary.
##
## Two things fix it, and both are here on purpose: `ensure_loaded()`
## builds the index on whatever thread loads the registry, so no worker
## ever finds it cold; and the build fills LOCALS and publishes them
## before flipping the flag, so a flag that reads true always means data
## that is complete.
static var _printings_loaded: bool = false


static func _ensure_printings() -> void:
	if _printings_loaded:
		return
	var artists := {}
	var original := {}
	for code in SET_ORDER:
		var path := "res://cards/data/%s.json" % code
		if not FileAccess.file_exists(path):
			continue
		var parsed: Variant = JSON.parse_string(
			FileAccess.get_file_as_string(path))
		if not (parsed is Array):
			push_error("CardRegistry: cannot read %s" % path)
			continue          # a snapshot we cannot read simply has no credits
		for entry in parsed:
			var name: String = String(entry.get("name", ""))
			if name == "":
				continue
			if not original.has(name):
				original[name] = code   # first set in printing order wins
			var who: String = String(entry.get("artist", ""))
			if who == "":
				continue
			artists["%s|%s" % [code, name]] = who
			if not artists.has(name):
				artists[name] = who   # first printing wins, as SET_ORDER runs
	_artists = artists
	_original_set = original
	_printings_loaded = true
