class_name CardRegistry
extends RefCounted
## The card database: every registered CardData, keyed by exact card name.
##
## Default cards register themselves by existing as files: [method
## ensure_loaded] scans the fixed eight [constant SET_ORDER] folders,
## instantiates each .gd card file (they all extend CardScript), calls build(),
## and stores the result. Validated numbered packs may explicitly add trusted,
## dormant scripts without allowing executable code from an archive.
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
## Cache invalidation only; never part of a portable gameplay fingerprint.
static var revision := 0

## Pack 1 is DATA-GATED, while its four trusted implementations ship
## dormant in the game. These values contain strings and JSON-like data
## only — never CardData or its Callables (see [method unload]).
static var _optional_enabled := false
static var _optional_sets: Dictionary = {}
static var _optional_membership: Dictionary = {}
static var _optional_scripts: Array = []
static var _optional_records: Array = []
static var _optional_counts: Dictionary = {}
static var _expansion_sets: Dictionary = {}
static var _expansion_scripts: Array = []
static var _expansion_records: Array = []
static var _pack_rarities: Dictionary = {}

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
	# The eight known folders, not every directory someone happens to add
	# under cards/sets. Numbered packs are configured explicitly below.
	for code in SET_ORDER:
		_load_set_at(SETS_ROOT, code)
	if _optional_enabled:
		for spec in _optional_scripts:
			_load_optional_script(spec)
	for spec in _expansion_scripts:
		_load_optional_script(spec)


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
	revision += 1
	_cards.clear()
	_original_set.clear()
	_artists.clear()
	_rarities.clear()
	_pack_rarities.clear()
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
	_load_set_at(SETS_ROOT, set_code)


static func _load_set_at(root_path: String, set_code: String) -> void:
	var dir_path := "%s/%s" % [root_path, set_code]
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


## One dormant card implementation unlocked by a validated metadata pack.
static func _load_optional_script(spec: Dictionary) -> void:
	var path := String(spec.get("path", ""))
	var set_code := String(spec.get("set", ""))
	var expected := String(spec.get("name", ""))
	var loaded: Variant = load(path)
	if not (loaded is GDScript):
		push_error("CardRegistry: optional card script cannot load: %s" % path)
		return
	var card_script: CardScript = loaded.new()
	var data: CardData = card_script.build()
	if data == null:
		push_error("CardRegistry: optional card built null: %s" % path)
		return
	if data.card_name != expected:
		push_error("CardRegistry: optional card expected '%s', script built '%s'" % [
			expected, data.card_name])
		return
	data.set_code = set_code
	data.artist = artist_of(data.card_name, set_code)
	register(data)


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


## Configure the optional pool before the next load. JSON-like values only;
## the registry continues to own and clear every constructed CardData.
static func configure_optional_pack(enabled: bool, sets: Dictionary,
		scripts: Array, records: Array, counts: Dictionary) -> void:
	if _loaded:
		unload()
	_optional_enabled = enabled
	_optional_sets = sets.duplicate(true) if enabled else {}
	_optional_scripts = scripts.duplicate(true) if enabled else []
	_optional_records = records.duplicate(true) if enabled else []
	_optional_counts = counts.duplicate(true) if enabled else {}
	_optional_membership.clear()
	if not enabled:
		return
	for code in _optional_sets:
		var one: Variant = _optional_sets[code]
		if not (one is Dictionary):
			continue
		for value in one.get("names", []):
			var name := String(value)
			if not _optional_membership.has(name):
				_optional_membership[name] = {}
			_optional_membership[name][String(code)] = true


static func optional_pack_enabled() -> bool:
	return _optional_enabled


## New expansions are independent of Pack 1's completion of the base sets.
## All paths come from trusted game code, never from a user-supplied ZIP.
static func configure_expansion_packs(sets: Dictionary, scripts: Array,
		records: Array) -> void:
	if _loaded:
		unload()
	_expansion_sets = sets.duplicate(true)
	_expansion_scripts = scripts.duplicate(true)
	_expansion_records = records.duplicate(true)


static func extra_set_order() -> Array[String]:
	var codes: Array[String] = []
	for code in _expansion_sets:
		codes.append(String(code))
	return codes


static func active_set_order() -> Array[String]:
	var codes := SET_ORDER.duplicate()
	codes.append_array(extra_set_order())
	return codes


## Whether a named rules identity belongs to this displayed set. With no
## pack, the historical one-script/one-set assignment remains unchanged;
## Pack 1 expands it to every published set that printed the name.
static func card_in_set(card_name: String, set_code: String, include_completion := true,
		include_original := true) -> bool:
	ensure_loaded()
	if _expansion_sets.has(set_code):
		return _cards.has(card_name) and _expansion_sets[set_code].get("names", []).has(card_name)
	var data: CardData = _cards.get(card_name)
	if _optional_enabled and include_completion:
		if not bool(_optional_membership.get(card_name, {}).get(set_code, false)):
			return false
		# Pack 1 adds the set/name pairs missing from the shipped assignment.
		# In a pack-only browser, retain those reprints as well as its four
		# new identities, but do not attribute the original printing to it.
		return include_original or is_completion_card(card_name) \
			or (data != null and data.set_code != set_code)
	if not include_original:
		return false
	if not include_completion and is_completion_card(card_name):
		return false
	return data != null and data.set_code == set_code


## Newly playable names from Pack 1, not its reprints of existing cards.
## Browser visibility can exclude these without unloading the game registry.
static func is_completion_card(card_name: String) -> bool:
	for spec in _optional_scripts:
		if spec.get("name", "") == card_name:
			return true
	return false


static func names_in_set(set_code: String) -> Array[String]:
	ensure_loaded()
	var out: Array[String] = []
	if _expansion_sets.has(set_code):
		for name in _expansion_sets[set_code].get("names", []):
			if _cards.has(name):
				out.append(String(name))
		return out
	if _optional_enabled:
		var one: Variant = _optional_sets.get(set_code, {})
		if one is Dictionary:
			for value in one.get("names", []):
				var name := String(value)
				if _cards.has(name):
					out.append(name)
		return out
	for name in _cards:
		var data: CardData = _cards[name]
		if data.set_code == set_code:
			out.append(String(name))
	out.sort()
	return out


## Named set entries count a reprint once in each set, while [method size]
## counts one playable rules identity per name.
static func named_set_entry_count() -> int:
	ensure_loaded()
	var total := int(_optional_counts.get("named_set_entries", _base_identity_count()))
	for code in _expansion_sets:
		total += names_in_set(code).size()
	return total


static func published_printing_count() -> int:
	ensure_loaded()
	var total := int(_optional_counts.get("published_printings", _base_identity_count()))
	for one in _expansion_sets.values():
		total += int(one.get("published_printings", 0))
	return total


# ------------------------------------------------- original printings (CR 201) --
static func _base_identity_count() -> int:
	var total := 0
	for data: CardData in _cards.values():
		if not _expansion_sets.has(data.set_code):
			total += 1
	return total

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
## Printing metadata only: first printing by name, exact printing by set|name.
static var _rarities: Dictionary = {}


## Rarity of the displayed printing, falling back to the first known printing.
## Built eagerly with artist credits; cleared whenever enabled packs change.
static func rarity_of(card_name: String, set_code := "") -> String:
	_ensure_printings()
	return String(_rarities.get("%s|%s" % [set_code, card_name],
		_rarities.get(card_name, "")))


## THE ONE PASS over `cards/data/` that fills the printing indexes, run from
## [method ensure_loaded] so it is complete before anything else can ask.
##
## THREAD SAFETY, and the bug that put this comment here. This was two
## lazy builders, each of which set its "loaded" flag BEFORE filling its
## dictionary. Two worker threads reaching one at the same time is a real
## Deck Lab shape (`DeckLab/simulate.gd` fans games out over a
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
	var pack_rarities := {}
	var rarities := {}
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
			var rarity := String(entry.get("rarity", ""))
			rarities["%s|%s" % [code, name]] = rarity
			if not rarities.has(name):
				rarities[name] = rarity
			var who: String = String(entry.get("artist", ""))
			if who == "":
				continue
			artists["%s|%s" % [code, name]] = who
			if not artists.has(name):
				artists[name] = who   # first printing wins, as SET_ORDER runs
	# The base snapshots intentionally omit the four physical/manual cards.
	# A validated enabled pack provides their printing metadata here, before
	# its dormant implementations ask [method artist_of] during loading.
	if _optional_enabled or not _expansion_records.is_empty():
		for entry in _optional_records + _expansion_records:
			if not (entry is Dictionary):
				continue
			var name := String(entry.get("name", ""))
			var code := String(entry.get("set", ""))
			if name == "" or code == "":
				continue
			if not pack_rarities.has(name):
				pack_rarities[name] = String(entry.get("rarity", ""))
			var rarity := String(entry.get("rarity", ""))
			rarities["%s|%s" % [code, name]] = rarity
			if not rarities.has(name):
				rarities[name] = rarity
			if not original.has(name):
				original[name] = code
			var who := String(entry.get("artist", ""))
			if who != "":
				artists["%s|%s" % [code, name]] = who
				if not artists.has(name):
					artists[name] = who
	_artists = artists
	_rarities = rarities
	_original_set = original
	_pack_rarities = pack_rarities
	_printings_loaded = true


## Validated enabled-pack metadata supplements, never replaces, the base
## deck rarity table. Publish with the eager printing index for worker safety.
static func pack_rarity_of(card_name: String) -> String:
	_ensure_printings()
	return String(_pack_rarities.get(card_name, ""))
