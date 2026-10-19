class_name DuelPosition
extends RefCounted
## A HAND-BUILT POSITION A DUEL STARTS FROM — the data behind Magic
## Battle's `Test hands` (2026-10-19). The owner: *"design a tool to start a
## duel with two predefined hands besides decks so a player can instantly
## test a combo … select cards on table (tapped or not for each) and then
## selects whose turn it is and upon "go test" button you are instant in
## the turn"*. `[QoL]`, and squarely ours: the 1997 game had nothing like
## it, and neither has s30.
##
## A MODEL AND NOTHING ELSE. Names, never [CardInstance]s — the screen that
## fills it ([TestHandsScreen]) has no game, the setting it is remembered
## under is a text file a player may edit, and the same position must be
## able to start the duel twice (`Restart test`). The duel it describes is
## made by [method MtgGame.begin_from_position], which reads this and
## nothing else: every card named here is TAKEN out of its seat's shuffled
## library, or MADE when the deck has no copy left (an extra), and put
## where the position says, before turn 1 begins in [member step] of
## [member active_player]'s turn.
##
## Per seat (index 0 is Seat 1, the seat below):
##   hands         the chosen hand;
##   random_cards  how many more cards the hand gets off the top of the
##                 rest of the library (the shuffle is the duel's seed's);
##   table         the permanents already in play, each
##                 `{"name", "tapped", "sick"}`;
##   graveyards    bottom first — the LAST name is the top card, the one
##                 Corpse Dance's "top creature card" reads;
##   library_tops  the cards on top of the library, NEXT DRAW FIRST;
##   lives         the starting life totals.
## and for the duel: [member active_player] and [member step].
##
## Pure engine: RefCounted, headless, no randomness of its own.

## The four places a card can be named into, in the screen's order.
const HAND := "hand"
const TABLE := "table"
const GRAVEYARD := "graveyard"
const LIBRARY_TOP := "library_top"
const ZONES: Array[String] = [HAND, TABLE, GRAVEYARD, LIBRARY_TOP]

## The steps a test may begin in, in turn order. The untap step is not one
## of them: it would untap the permanents the position says are tapped,
## and the turn's first decision is the upkeep's anyway. The combat steps
## after the beginning of combat are not either — an attack is declared
## from a board, and the board is what the position sets.
const STEPS: Array[int] = [Mtg.Step.UPKEEP, Mtg.Step.DRAW, Mtg.Step.MAIN1,
	Mtg.Step.COMBAT_BEGIN, Mtg.Step.MAIN2, Mtg.Step.END]

## The ceiling of a life total — the Magic Battle screen's own spin box.
const MAX_LIFE := 400
## How many cards one place may name, and how many random cards a hand may
## take. Generous for any test and a fence for a hand-edited settings file:
## a deck holds at most 500 cards (`DeckModel.MAX_TOTAL`).
const MAX_CARDS := 120
const MAX_RANDOM := 60

var hands: Array = [[], []]
var random_cards: Array[int] = [0, 0]
var table: Array = [[], []]
var graveyards: Array = [[], []]
var library_tops: Array = [[], []]
var lives: Array[int] = [20, 20]
## Whose turn the test begins in.
var active_player := 0
## Which step of that turn ([constant STEPS]); the first main phase unless
## the player chose otherwise, so a combo can be tried at once.
var step: int = Mtg.Step.MAIN1


## The names [param pid] put into [param zone], in order. The table's
## entries are read by their name; [method table_entry] has the rest.
func names_in(pid: int, zone: String) -> Array[String]:
	var out: Array[String] = []
	for entry in _list(pid, zone):
		out.append(String(entry["name"]) if entry is Dictionary else String(entry))
	return out


## One table entry, `{"name", "tapped", "sick"}`.
func table_entry(pid: int, index: int) -> Dictionary:
	return table[pid][index]


## Name one more card into [param zone]. A table entry starts UNTAPPED and
## NOT summoning sick: it has been there since before the turn, so it can
## be used at once, which is what a combo test wants.
func add(pid: int, zone: String, card_name: String) -> void:
	var list := _list(pid, zone)
	if list.size() >= MAX_CARDS:
		return
	if zone == TABLE:
		list.append({"name": card_name, "tapped": false, "sick": false})
	else:
		list.append(card_name)


func remove_at(pid: int, zone: String, index: int) -> void:
	var list := _list(pid, zone)
	if index >= 0 and index < list.size():
		list.remove_at(index)


func clear_zone(pid: int, zone: String) -> void:
	_list(pid, zone).clear()


func set_tapped(pid: int, index: int, on: bool) -> void:
	if index >= 0 and index < table[pid].size():
		table[pid][index]["tapped"] = on


func set_sick(pid: int, index: int, on: bool) -> void:
	if index >= 0 and index < table[pid].size():
		table[pid][index]["sick"] = on


## How many copies of [param card_name] [param pid] names, in every place
## together — what the picker subtracts from the deck's count.
func count_of(pid: int, card_name: String) -> int:
	var count := 0
	for zone in ZONES:
		count += names_in(pid, zone).count(card_name)
	return count


## Every name [param pid] names, in every place (the hand's random cards
## are not names and are not counted).
func names_of(pid: int) -> Array[String]:
	var out: Array[String] = []
	for zone in ZONES:
		out.append_array(names_in(pid, zone))
	return out


## Nothing named anywhere and no random card either.
func is_empty() -> bool:
	for pid in 2:
		if not names_of(pid).is_empty() or random_cards[pid] > 0:
			return false
	return true


## Why this position cannot start a duel, or "" when it can — said before
## anything is moved ([method MtgGame.begin_from_position] asks it first).
## A name the pool does not hold is the likely one: a test saved while a
## card pack was on, opened after it was turned off.
func refusal() -> String:
	if active_player < 0 or active_player > 1:
		return "Choose whose turn the test begins in."
	if step not in STEPS:
		return "A test begins in the upkeep, the draw step, a main phase, the beginning of combat or the end step."
	for pid in 2:
		if lives[pid] < 1 or lives[pid] > MAX_LIFE:
			return "Seat %d's life must be between 1 and %d." % [pid + 1, MAX_LIFE]
		if random_cards[pid] < 0 or random_cards[pid] > MAX_RANDOM:
			return "Seat %d's random cards must be between 0 and %d." % [pid + 1, MAX_RANDOM]
		var unknown: Array[String] = []
		for card_name in names_of(pid):
			if not CardRegistry.has_card(card_name) and card_name not in unknown:
				unknown.append(card_name)
		if not unknown.is_empty():
			return "Seat %d names %s, which the card pool does not hold. Is its card pack on? (Options, Card packs)" \
				% [pid + 1, ", ".join(unknown)]
	return ""


## The position as plain values — what [Settings] keeps (the last test and
## the saved ones). Lists of names, dictionaries of plain fields: nothing a
## text file cannot hold.
func to_dict() -> Dictionary:
	var rows: Array = [[], []]
	for pid in 2:
		for entry in table[pid]:
			rows[pid].append({"name": String(entry["name"]),
				"tapped": bool(entry.get("tapped", false)), "sick": bool(entry.get("sick", false))})
	return {
		"hands": [_plain(hands[0]), _plain(hands[1])],
		"random_cards": [random_cards[0], random_cards[1]],
		"table": rows,
		"graveyards": [_plain(graveyards[0]), _plain(graveyards[1])],
		"library_tops": [_plain(library_tops[0]), _plain(library_tops[1])],
		"lives": [lives[0], lives[1]],
		"active_player": active_player,
		"step": step,
	}


## The other half of [method to_dict], and DEFENSIVE: what it reads came
## out of `settings.cfg`, which the docs invite a player to edit (the
## robustness campaign of 2026-10-12), so every field is checked for its
## type and range and anything else falls back to the fresh position's
## value. A name is kept as text whether or not the pool holds it — the
## screen marks it and [method refusal] names it — so a test saved under a
## pack is not silently thinned when the pack is off.
static func from_dict(value: Variant) -> DuelPosition:
	var out := DuelPosition.new()
	if not (value is Dictionary):
		return out
	var d: Dictionary = value
	for pid in 2:
		out.hands[pid] = _names(_seat(d.get("hands"), pid))
		out.graveyards[pid] = _names(_seat(d.get("graveyards"), pid))
		out.library_tops[pid] = _names(_seat(d.get("library_tops"), pid))
		var rows: Array = []
		for row in _seat(d.get("table"), pid):
			if rows.size() >= MAX_CARDS:
				break
			if row is Dictionary and _text(row.get("name")) != "":
				rows.append({"name": _text(row["name"]),
					"tapped": _flag(row.get("tapped")), "sick": _flag(row.get("sick"))})
			elif _text(row) != "":
				rows.append({"name": _text(row), "tapped": false, "sick": false})
		out.table[pid] = rows
		out.random_cards[pid] = clampi(_number(_seat_value(d.get("random_cards"), pid), 0), 0, MAX_RANDOM)
		out.lives[pid] = clampi(_number(_seat_value(d.get("lives"), pid), 20), 1, MAX_LIFE)
	out.active_player = clampi(_number(d.get("active_player"), 0), 0, 1)
	var wanted := _number(d.get("step"), Mtg.Step.MAIN1)
	out.step = wanted if wanted in STEPS else Mtg.Step.MAIN1
	return out


## A copy that shares nothing with this one.
func duplicate_position() -> DuelPosition:
	return DuelPosition.from_dict(to_dict())


## The list [param zone] names for [param pid] — the live array.
func _list(pid: int, zone: String) -> Array:
	match zone:
		HAND:
			return hands[pid]
		TABLE:
			return table[pid]
		GRAVEYARD:
			return graveyards[pid]
		LIBRARY_TOP:
			return library_tops[pid]
	return []


## An untyped copy of a list of names: what a text file round-trips.
static func _plain(values: Array) -> Array:
	var out: Array = []
	for value in values:
		out.append(String(value))
	return out


static func _seat(value: Variant, pid: int) -> Array:
	if value is Array and (value as Array).size() > pid and value[pid] is Array:
		return value[pid]
	return []


static func _seat_value(value: Variant, pid: int) -> Variant:
	if value is Array and (value as Array).size() > pid:
		return value[pid]
	return null


static func _names(values: Array) -> Array[String]:
	var out: Array[String] = []
	for value in values:
		if out.size() >= MAX_CARDS:
			break
		var card_name := _text(value)
		if card_name != "":
			out.append(card_name)
	return out


static func _text(value: Variant) -> String:
	if value is String or value is StringName:
		return String(value).strip_edges()
	return ""


static func _flag(value: Variant) -> bool:
	if value is bool:
		return value
	if value is int or value is float:
		return value != 0
	return false


static func _number(value: Variant, fallback: int) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(value)
	if value is String and String(value).strip_edges().is_valid_int():
		return String(value).strip_edges().to_int()
	return fallback
