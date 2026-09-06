class_name DeckFilter
extends RefCounted
## WHICH CARDS THE INVENTORY SHOWS — the 1997 Deck Builder's four Filter
## groups, ported from s30's `collectionFilter`
## (`game/screens/edit_deck_filter.go`) but with the ORIGINAL's polarity,
## which is the opposite of s30's and is stated outright in the manual
## (ch.10, "Filters Galore"):
##
## > *"Every one of these buttons is a toggle switch; when the button is
## > depressed, it is on, and the cards that correspond to that filter are
## > displayed. When the button is up, it's off, and cards represented by
## > that button are eliminated (temporarily, of course) from those shown."*
##
## So a fresh filter has EVERY button ON and shows the whole pool; you
## switch things OFF. s30 inverts this (nothing lit = everything, light
## red = only red). The owner's rule is that the original wins on
## behaviour and s30 on structure, so the toggles, the grouping and
## [method apply] are s30's and the polarity is 1997's.
##
## And the combination rule, also verbatim:
##
## > *"Within each set of buttons, the filters are additive… Between sets,
## > however, the filters are exclusive. That means, for example, that if
## > you have Green and Instants both depressed, you'll see only green
## > instants… if you chose an odd filter combination, like Enchantments
## > and Trample, no cards would show up at all."*
##
## Two 1997 exemptions fall out of the manual and are implemented as
## written: a LAND ignores the Color Filters entirely (*"so long as the
## Land filter is active, all lands are displayed, regardless of which
## Color Filters are on — and no matter what color mana the lands
## produce"*), and so does any colourless card (*"there's no Color Filter
## for colorless cards. In order to see land, artifacts, and any other
## cards which have no color, you must use the next group of filters."*).
##
## THE MINI-MENUS. *"You can also right-click on some of the filter buttons
## to open a mini-menu of options. These represent sub-groups of that
## filter."* The audit pass (2026-08-31) added the three the string table
## spells out and our card data can answer — `@LAND`, `@ARTIFACT` and the
## `@POWER`/`@TOUGHNESS` pair — on top of the `@GOLD` and `@CASTCOST` the
## building pass shipped. The fourth pass (2026-09-06) built the last five
## — `@CREATURE`, `@ENCHANTMENT`, `@ABILITY`, `@RARITY` and `@ARTIST` —
## on the `@LONGLIST` window the first two needed; see [constant SHIPPED].
##
## Pure logic, no Nodes: the screen owns one of these and the tests drive
## it directly (tests/ui/test_deck_filter.gd).
##
## EVERY MUTATION BUMPS [member revision]. The screen filters 800 cards to
## fill the Inventory and must not do that on every card click, so it
## re-runs [method apply] only when this number moves — and the cached
## colour/type bit masks this class matches on are rebuilt from the same
## number, so a mutation that did not bump it would filter by the state
## before the click.
##
## `Select All` / `Clear All` (`@LONGLIST`) are [method select_all] and
## [method clear_all], recovered by the second audit pass: a strip of
## twenty-three toggles needs a way back from them.
##
## THE FILTER WINDOW (2026-09-06). The five sub-filters of [constant
## SHIPPED] are long lists — ninety creature types, fifty painters — and
## the strip had no room for three more medallions, so they live in ONE
## window with a page each, opened by the funnel medallion that closes
## the Other Filters group ([method FilterBar.window_pages]). The state
## is all here; [method lists_active], [method window_snapshot] and
## [method window_restore] are what the window and its Cancel need.

## Sort orders the builder offers. `Sort deck` itself is the DECK's order
## and lives on [DeckModel]; this is the INVENTORY's.
enum Sort { NAME, COST, TYPE, COLOR, SET }

## `@GOLD` (`s30/assets/text/Menus.txt:314`) — the Gold button's right-click
## mini-menu, in its own words: "All &gold cards" / "&Matching all selected
## color buttons" / "Matching &any selected color button".
enum Gold { ALL, MATCH_ALL, MATCH_ANY }

## `@CASTCOST` (`s30/assets/text/Menus.txt:347`) — "&Greater than or equal
## to" / "&Less than or equal to" / "&Equal to" / "&X cost". OFF is ours:
## the original's Casting Cost button is itself a toggle, and OFF is that
## button up.
##
## The string table wins over the manual here. The manual's prose calls
## these "Greater than" and "Less than" (*"limits the displayed cards to
## those with a casting cost larger than the number you choose"*), but the
## menu the program actually drew says "or equal to" — so the comparison
## is inclusive and the labels are the table's.
enum Cost { OFF, GE, LE, EQ, HAS_X }

## `@POWER` / `@TOUGHNESS` (`Menus.txt:354`, `:360`) — both are the same
## three: "&Greater than or equal to" / "&Less than or equal to" /
## "&Equal to". OFF is the button up.
enum Rank { OFF, GE, LE, EQ }

## `@LAND` (`Menus.txt:320`) — the Land button's mini-menu: "&Land and
## Mana" / "Land &only" / "&Mana only", *"three mutually exclusive
## options"*. The first is the default and the manual says exactly what it
## does: *"this filters in all land and all other cards capable of
## producing mana."*
enum Land { LAND_AND_MANA, LAND_ONLY, MANA_ONLY }

## `@ENCHANTMENT` (`Menus.txt:338`) — the Enchantments button's mini-menu:
## "&Enchantments / &World / &Land / &Creature / &Artifact / E&nchant",
## six independent checks, all on to begin with. The first is the plain
## global enchantment (neither an Aura nor a World); the other five are
## what an Aura is cast on, read from [member CardData.aura_target] —
## `check_enchantments`, `deckdll.cpp:7015`.
enum Aura { ENCHANTMENTS, WORLD, LAND, CREATURE, ARTIFACT, ENCHANT }

const AURA_LABELS := {
	Aura.ENCHANTMENTS: "Enchantments", Aura.WORLD: "World", Aura.LAND: "Land",
	Aura.CREATURE: "Creature", Aura.ARTIFACT: "Artifact", Aura.ENCHANT: "Enchant",
}

## `@RARITY` (`Menus.txt:384`) — "&Common / &Uncommon / &Rare / R&estricted /
## &Banned", ORed while the filter is enabled (`check_rarity`,
## `deckdll.cpp:7107`). Restricted and Banned are the two tournament lists
## ([constant DeckFormat.RESTRICTED], [constant DeckFormat.BANNED]).
enum Rarity { COMMON, UNCOMMON, RARE, RESTRICTED, BANNED }

const RARITY_LABELS := {
	Rarity.COMMON: "Common", Rarity.UNCOMMON: "Uncommon", Rarity.RARE: "Rare",
	Rarity.RESTRICTED: "Restricted", Rarity.BANNED: "Banned",
}

## The five 1997 sub-filters the first three passes could not build and
## the fourth (2026-09-06) did, kept as the record the `OWED` list
## used to be:
##
## - `@CREATURE` "&Summon / &Token / &Artifact / Summon from &list..." —
##   [member creature_summon], [member creature_artifact] and the
##   [member creature_types] list. TOKEN IS DROPPED: the pool has no token
##   cards, so the check could never admit anything, and a switch that
##   does nothing is worse than none (the Interrupts precedent,
##   [constant TYPE_ORDER]).
## - `@ENCHANTMENT` — [enum Aura] and [member enchantments].
## - `@ABILITY` — [member ability_on], the Native/Gives pair and
##   [member abilities]; the profile is [DeckAbilities]'.
## - `@RARITY` — [enum Rarity] and [member rarities]; the printed rarity
##   comes from [method DeckStats.rarity_of].
## - `@ARTIST` — [member artist_on] and [member artists] over
##   [member CardData.artist].
const SHIPPED := ["@CREATURE", "@ENCHANTMENT", "@ABILITY", "@RARITY", "@ARTIST"]

## The Color Filter buttons, in the mana pool's own order.
const COLOR_ORDER: Array[int] = [
	Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B,
	Mtg.ManaColor.R, Mtg.ManaColor.G,
]

## The Type Filter buttons. The original's row is Land, Artifacts,
## Creatures, Enchantments, Instants, Interrupts, Sorceries; `Interrupts`
## is dropped because our engine has no interrupt tier and every 1997
## interrupt in the pool is registered as an Instant — see
## docs/glossary-1997.md §5, which forbids reintroducing the word.
const TYPE_ORDER: Array[int] = [
	Mtg.CardType.LAND, Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE,
	Mtg.CardType.ENCHANTMENT, Mtg.CardType.INSTANT, Mtg.CardType.SORCERY,
]

## Type Filter labels — the original's plurals (`@STATSSCREEN` and the
## manual's own callouts), not our enum names.
const TYPE_LABELS := {
	Mtg.CardType.LAND: "Land",
	Mtg.CardType.ARTIFACT: "Artifacts",
	Mtg.CardType.CREATURE: "Creatures",
	Mtg.CardType.ENCHANTMENT: "Enchantments",
	Mtg.CardType.INSTANT: "Instants",
	Mtg.CardType.SORCERY: "Sorceries",
}

## The Set Filter buttons: one per implemented set, named as the 1997 cue
## cards name them (`s30/assets/text/Cuecards.txt` — note the original's
## lowercase "Arabian nights"). The order is CardRegistry.SET_ORDER, i.e.
## the order the sets were printed in.
const SET_LABELS := {
	"2ed": "Unlimited",
	"arn": "Arabian nights",
	"atq": "Antiquities",
	"leg": "Legends",
	"drk": "The Dark",
	"4ed": "Fourth Edition",
	"past": "Astral",
	"phpr": "Promotional",
}

## Colour Filter labels, as the manual's figure calls them out.
const COLOR_LABELS := {
	Mtg.ManaColor.W: "White", Mtg.ManaColor.U: "Blue",
	Mtg.ManaColor.B: "Black", Mtg.ManaColor.R: "Red",
	Mtg.ManaColor.G: "Green",
}

## Type order used by [constant Sort.TYPE].
const TYPE_SORT_RANK: Array[int] = [
	Mtg.CardType.CREATURE, Mtg.CardType.ARTIFACT, Mtg.CardType.ENCHANTMENT,
	Mtg.CardType.INSTANT, Mtg.CardType.SORCERY, Mtg.CardType.LAND,
]

## The five colour bits together — [method matches_color] counts a card's
## colours with bit arithmetic and must not count `ManaColor.C`.
const WUBRG_MASK: int = Mtg.ManaColor.W | Mtg.ManaColor.U | Mtg.ManaColor.B \
	| Mtg.ManaColor.R | Mtg.ManaColor.G

## [method _facts_for]'s columns, and which one each [enum Sort] reads.
## These REPLACED a `sort_key(d, mode) -> String` that formatted a fresh
## string per card per comparison; the third audit pass (2026-09-01) left
## the old function behind unused when it moved the sort onto these
## integers, and it was deleted rather than kept as a second answer to the
## same question.
const FACT_NAME := 0
const FACT_COLOR_MASK := 1
const FACT_TEXT := 6
const SORT_COLUMN := {
	Sort.NAME: FACT_NAME, Sort.COST: 2, Sort.TYPE: 3, Sort.COLOR: 4, Sort.SET: 5,
}

# ------------------------------------------------------------- the state --

## Bumped by every change. Read-only to callers; the screen compares it
## against the revision it last drew and skips the whole 800-card pass
## when nothing moved.
var revision := 0

## Mtg.ManaColor -> is its button depressed. All true to begin with.
var colors: Dictionary = {}
## The Gold button and its mini-menu mode (`@GOLD`).
var gold := true:
	set(value):
		if gold != value:
			gold = value
			revision += 1
var gold_mode: int = Gold.ALL:
	set(value):
		if gold_mode != value:
			gold_mode = value
			revision += 1
## Mtg.CardType -> depressed.
var types: Dictionary = {}
## set code -> depressed.
var sets: Dictionary = {}
## The Inventory's type-ahead: *"you can type in the first few letters of
## the name of any card you want to see"* (manual ch.10). Matched as a
## PREFIX first, then anywhere in the name, so "light" finds Lightning
## Bolt and "bolt" still finds it too.
var text := "":
	set(value):
		if text != value:
			text = value
			_needle = value.strip_edges().to_lower()
			revision += 1
## [QoL] Also match the type-ahead against a card's RULES TEXT. Not 1997:
## the original's box searched names only, because in 1997 you had the
## printed cards in front of you. Building from an 800-card pool on a
## screen you cannot leave, "which cards gain life" is a question the
## player currently has to answer somewhere else, and it is the single
## most repeated reason to reach past the filters. Off by default, so the
## box behaves exactly as the manual describes until it is switched on.
var search_rules := false:
	set(value):
		if search_rules != value:
			search_rules = value
			revision += 1
## `text` folded once (stripped, lower-cased) — [method matches_text] runs
## per card and must not redo that work 800 times.
var _needle := ""
## The Casting Cost filter (`@CASTCOST`).
var cost_mode: int = Cost.OFF:
	set(value):
		if cost_mode != value:
			cost_mode = value
			revision += 1
var cost_value := 0:
	set(value):
		if cost_value != value:
			cost_value = value
			revision += 1
## The Power filter (`@POWER`).
var power_mode: int = Rank.OFF:
	set(value):
		if power_mode != value:
			power_mode = value
			revision += 1
var power_value := 0:
	set(value):
		if power_value != value:
			power_value = value
			revision += 1
## The Toughness filter (`@TOUGHNESS`).
var toughness_mode: int = Rank.OFF:
	set(value):
		if toughness_mode != value:
			toughness_mode = value
			revision += 1
var toughness_value := 0:
	set(value):
		if toughness_value != value:
			toughness_value = value
			revision += 1
## The Land button's mini-menu (`@LAND`).
var land_mode: int = Land.LAND_AND_MANA:
	set(value):
		if land_mode != value:
			land_mode = value
			revision += 1
## `@ARTIFACT` — "All &Creatures" / "All &Non-Creatures", *"both of which
## are independent toggles… The default setting has both of these options
## turned on — all artifacts are displayed."*
var artifact_creatures := true:
	set(value):
		if artifact_creatures != value:
			artifact_creatures = value
			revision += 1
var artifact_noncreatures := true:
	set(value):
		if artifact_noncreatures != value:
			artifact_noncreatures = value
			revision += 1
## `@CREATURE` — "&Summon" admits a creature that is not an artifact,
## "&Artifact" an artifact creature, and the list, once enabled, admits
## any creature of a ticked type ON TOP of those two (`check_creatures`,
## `deckdll.cpp:6995`: the list is an OR term, not a narrowing). So "only
## the Elves" is Summon and Artifact off, the list on, Elf ticked — which
## is how the original did it, and the window says so
## ([constant DeckBuilderScreen.LIST_HINT]) when the list goes on with
## Summon still down.
var creature_summon := true:
	set(value):
		if creature_summon != value:
			creature_summon = value
			revision += 1
var creature_artifact := true:
	set(value):
		if creature_artifact != value:
			creature_artifact = value
			revision += 1
## "Summon from &list..." — is the list in force at all.
var creature_list_on := false:
	set(value):
		if creature_list_on != value:
			creature_list_on = value
			revision += 1
## creature subtype (the registry's own spelling, lower case) -> ticked.
## Absent means ticked, so a fresh list has every type selected.
var creature_types: Dictionary = {}
## `@ENCHANTMENT` — [enum Aura] -> ticked; absent means ticked.
var enchantments: Dictionary = {}
## `@ABILITY` — the filter is a whole ("Enable Filter"); Native and Gives
## are its two scopes and [member abilities] the thirteen it looks for.
## Ticking everything while the filter is off is the 1997 default.
var ability_on := false:
	set(value):
		if ability_on != value:
			ability_on = value
			revision += 1
var ability_native := true:
	set(value):
		if ability_native != value:
			ability_native = value
			revision += 1
var ability_gives := true:
	set(value):
		if ability_gives != value:
			ability_gives = value
			revision += 1
## [enum DeckAbilities.Ability] -> ticked; absent means ticked.
var abilities: Dictionary = {}
## `@RARITY` — enabled, and [enum Rarity] -> ticked (absent means ticked).
var rarity_on := false:
	set(value):
		if rarity_on != value:
			rarity_on = value
			revision += 1
var rarities: Dictionary = {}
## `@ARTIST` — enabled, and artist name -> ticked (absent means ticked).
var artist_on := false:
	set(value):
		if artist_on != value:
			artist_on = value
			revision += 1
var artists: Dictionary = {}
## Which order [method apply] returns the survivors in.
var sort_mode: int = Sort.NAME:
	set(value):
		if sort_mode != value:
			sort_mode = value
			revision += 1


func _init() -> void:
	reset()


## Every button depressed, every extra filter off — the screen's opening
## state, in which the whole pool is displayed.
func reset() -> void:
	colors.clear()
	for color in COLOR_ORDER:
		colors[color] = true
	types.clear()
	for type_flag in TYPE_ORDER:
		types[type_flag] = true
	sets.clear()
	for code in CardRegistry.SET_ORDER:
		sets[code] = true
	gold = true
	gold_mode = Gold.ALL
	text = ""
	cost_mode = Cost.OFF
	cost_value = 0
	power_mode = Rank.OFF
	power_value = 0
	toughness_mode = Rank.OFF
	toughness_value = 0
	land_mode = Land.LAND_AND_MANA
	artifact_creatures = true
	artifact_noncreatures = true
	search_rules = false
	_reset_lists()
	revision += 1


## The five 1997 sub-filters back to their opening state: the three
## enabled flags up, every check ticked.
func _reset_lists() -> void:
	creature_summon = true
	creature_artifact = true
	creature_list_on = false
	creature_types.clear()
	enchantments.clear()
	ability_on = false
	ability_native = true
	ability_gives = true
	abilities.clear()
	rarity_on = false
	rarities.clear()
	artist_on = false
	artists.clear()


## The type-ahead's text, as a method for callers that want the intent to
## read at the call site. Setting [member text] does the same thing.
func set_text(value: String) -> void:
	text = value


## `Select All` (`@LONGLIST`, `s30/assets/text/Menus.txt:22`) — every
## medallion depressed, which in the ORIGINAL's polarity means the whole
## pool is displayed. The Other Filters and the type-ahead go with it,
## because a player who asks to see everything means everything.
##
## Recovered by the second audit pass (2026-08-31): the strip has
## twenty-three toggles and there was no way back from them. Switching
## eight filters off and wanting the pool again was eight more clicks, and
## the far commoner question — *"show me only white creatures"* — cost
## twenty-one, because it is `Clear All` and then two.
func select_all() -> void:
	for color in COLOR_ORDER:
		colors[color] = true
	for type_flag in TYPE_ORDER:
		types[type_flag] = true
	for code in CardRegistry.SET_ORDER:
		sets[code] = true
	gold = true
	cost_mode = Cost.OFF
	power_mode = Rank.OFF
	toughness_mode = Rank.OFF
	land_mode = Land.LAND_AND_MANA
	artifact_creatures = true
	artifact_noncreatures = true
	text = ""
	_reset_lists()
	revision += 1


## `Clear All` (`@LONGLIST`, :23) — every COLOUR and TYPE medallion up. On
## its own it shows nothing, which is exactly what the original's own pair
## does; it is the FIRST half of picking a few filters out of twenty-three.
##
## TWO GROUPS ARE LEFT ALONE, and the third audit pass (2026-09-01) added
## the second of them because leaving it in was a bug:
##
## - the OTHER FILTERS, because they are comparisons rather than members of
##   the all-or-nothing run, and turning one "off" is already what up means.
## - the SET FILTERS. A set is a card's PRINTING, not what the card is, and
##   the set group is ANDed against the rest ([method matches]) — so a strip
##   with every set up shows nothing whatever else is pressed. Clearing them
##   made the command's own reason for existing impossible: *"show me only
##   white creatures"* is Clear All, White, Creatures, and it produced an
##   EMPTY Inventory with no cue at all saying which of the twenty-three
##   buttons was to blame. (`Select All` still lights them, so the group is
##   not one-way.)
func clear_all() -> void:
	for color in COLOR_ORDER:
		colors[color] = false
	for type_flag in TYPE_ORDER:
		types[type_flag] = false
	gold = false
	revision += 1


## Is anything hiding cards right now? (Used to letter the screen — the
## filter itself needs no such flag.)
func active() -> bool:
	for color in colors:
		if not colors[color]:
			return true
	for type_flag in types:
		if not types[type_flag]:
			return true
	for code in sets:
		if not sets[code]:
			return true
	return not gold or _needle != "" or cost_mode != Cost.OFF \
		or power_mode != Rank.OFF or toughness_mode != Rank.OFF \
		or land_mode != Land.LAND_AND_MANA \
		or not artifact_creatures or not artifact_noncreatures \
		or lists_active()


## Whether any of the FILTER WINDOW's five pages ([constant SHIPPED]) is
## narrowing the list — what lights the funnel medallion
## ([constant FilterBar.FUNNEL_CELL]).
func lists_active() -> bool:
	return not creature_summon or not creature_artifact or creature_list_on \
		or enchantments.values().has(false) \
		or ability_on or rarity_on or artist_on


## The window's whole state, for its Cancel button: every tick in the
## window edits this filter live (the Inventory re-lists under it), so
## Cancel has to put back what was there when the window opened.
func window_snapshot() -> Dictionary:
	return {
		"creature_summon": creature_summon,
		"creature_artifact": creature_artifact,
		"creature_list_on": creature_list_on,
		"creature_types": creature_types.duplicate(),
		"enchantments": enchantments.duplicate(),
		"ability_on": ability_on,
		"ability_native": ability_native,
		"ability_gives": ability_gives,
		"abilities": abilities.duplicate(),
		"rarity_on": rarity_on,
		"rarities": rarities.duplicate(),
		"artist_on": artist_on,
		"artists": artists.duplicate(),
	}


func window_restore(kept: Dictionary) -> void:
	for key in kept:
		set(key, kept[key].duplicate() if kept[key] is Dictionary else kept[key])
	revision += 1


func toggle_color(color: int) -> void:
	colors[color] = not color_on(color)
	revision += 1


func toggle_type(type_flag: int) -> void:
	types[type_flag] = not type_on(type_flag)
	revision += 1


func toggle_set(code: String) -> void:
	sets[code] = not set_on(code)
	revision += 1


func color_on(color: int) -> bool:
	return bool(colors.get(color, true))


func type_on(type_flag: int) -> bool:
	return bool(types.get(type_flag, true))


func set_on(code: String) -> bool:
	return bool(sets.get(code, true))


## The five lists share one shape — absent means ticked — so the windows
## and mini-menus that edit them go through these.
func creature_type_on(subtype: String) -> bool:
	return bool(creature_types.get(subtype, true))


func enchantment_on(kind: int) -> bool:
	return bool(enchantments.get(kind, true))


func ability_ticked(ability: int) -> bool:
	return bool(abilities.get(ability, true))


func rarity_ticked(rarity: int) -> bool:
	return bool(rarities.get(rarity, true))


func artist_ticked(name: String) -> bool:
	return bool(artists.get(name, true))


func tick_creature_type(subtype: String, on: bool) -> void:
	_tick(creature_types, subtype, on)


func tick_enchantment(kind: int, on: bool) -> void:
	_tick(enchantments, kind, on)


func tick_ability(ability: int, on: bool) -> void:
	_tick(abilities, ability, on)


func tick_rarity(rarity: int, on: bool) -> void:
	_tick(rarities, rarity, on)


func tick_artist(name: String, on: bool) -> void:
	_tick(artists, name, on)


func _tick(list: Dictionary, key: Variant, on: bool) -> void:
	if on == not list.has(key):
		return
	if on:
		list.erase(key)
	else:
		list[key] = false
	revision += 1


## `X cards are in the list` / `X cards are filtered out` — the 1997 cue
## card for a COLOUR, SET or TYPE button (`s30/assets/text/Cuecards.txt`,
## which is the genuine 1997 copy; `shandalar-src/Program/CueCards.txt` is
## Manalink-updated and renames Gold to Multicolored).
static func cue_card(label: String, on: bool) -> String:
	return "%s cards are %s" % [label, "in the list" if on else "filtered out"]


## `Cards are filtered by X` / `Cards are not filtered by X` — the OTHER
## sentence in the same file, and the one the four "Other Filters" use
## (`@CASTCOST`, `@POWER`, `@TOUGHNESS`, `@ABILITY`, `@RARITY`, `@ARTIST`
## at Cuecards.txt:126-151). [param subject] is the table's own lowercase
## noun: "cast cost", "power", "toughness".
static func filtered_by_cue_card(subject: String, on: bool) -> String:
	return "Cards are %sfiltered by %s" % ["" if on else "not ", subject]


# --------------------------------------------------- the per-card facts --
# THE SECOND AUDIT PASS'S OPTIMISATION (2026-08-31). Filtering the pool was
# measured at 4.0 ms of a 6.4 ms Inventory rebuild, and almost none of it
# was decisions: it was the same immutable facts recomputed for 800 cards
# on every pass — `card_name.to_lower()`, `oracle_text.to_lower()`,
# `cost.color_mask()` (which walks the pips) and four sort ranks, two of
# them built as format strings.
#
# A card's name, colour and cost never change, so they are worked out ONCE
# per [CardData] and kept. The table is static and keyed by the card's
# INSTANCE ID rather than the object, so it holds no reference: a static
# that keeps a [CardData] alive past [method CardRegistry.unload] destroys
# it during static-variable teardown, after the card scripts its
# Callables point into are gone, and the process aborts with a corrupted
# heap (the registry's own history, `engine/card_registry.gd`; found
# again here 2026-09-02 by `tests/ui/test_deck_filter.gd` exiting 134).
# An id is never reused within a process, so a stale row is dead weight,
# not a wrong answer.

## CardData instance id -> [folded name, colour mask, cost rank, type
## rank, colour rank, set rank, folded rules text].
static var _facts: Dictionary = {}

static func _facts_for(d: CardData) -> Array:
	var key := d.get_instance_id()
	var got: Array = _facts.get(key, [])
	if got.is_empty():
		got = [
			d.card_name.to_lower(),
			d.color_mask(),
			mini(d.cost.mana_value(), 99),
			type_rank(d),
			color_rank(d),
			maxi(CardRegistry.SET_ORDER.find(d.set_code), 0),
			d.oracle_text.to_lower(),
		]
		_facts[key] = got
	return got


## Which colours and types are DEPRESSED, as bit masks, so the two group
## checks are integer arithmetic instead of eleven Dictionary look-ups per
## card. Rebuilt whenever [member revision] moves — which is every
## mutation, by this class's own contract.
var _mask_revision := -1
var _color_on_mask := 0
var _type_on_mask := 0


func _sync_masks() -> void:
	if _mask_revision == revision:
		return
	_mask_revision = revision
	_color_on_mask = 0
	for color in COLOR_ORDER:
		if color_on(color):
			_color_on_mask |= color
	_type_on_mask = 0
	for type_flag in TYPE_ORDER:
		if type_on(type_flag):
			_type_on_mask |= type_flag


# ------------------------------------------------------------ the rules --

## Does [param d] survive every group? The four groups are ANDed
## ("between sets… exclusive"); inside each, the buttons are ORed.
func matches(d: CardData) -> bool:
	# Ordered cheapest-first: the set check is a dictionary hit, the text
	# check is usually a no-op, and matches_type is the only one that can
	# walk a sub-menu.
	_sync_masks()
	return matches_set(d) and matches_text(d) and matches_cost(d) \
		and matches_power(d) and matches_toughness(d) \
		and matches_rarity(d) and matches_artist(d) and matches_ability(d) \
		and matches_color(d) and matches_type(d)


## The Color Filters, with the manual's two exemptions: a LAND and a
## COLOURLESS card are not filtered by colour at all.
func matches_color(d: CardData) -> bool:
	if d.is_land():
		return true
	_sync_masks()
	var mask: int = _facts_for(d)[FACT_COLOR_MASK]
	if mask == 0:
		return true
	var lit := mask & WUBRG_MASK
	# More than one bit set — a GOLD card, and the Gold button answers for it.
	if lit & (lit - 1):
		return _matches_gold(mask)
	return (lit & _color_on_mask) != 0


## A GOLD (multicolour) card, per the Gold button's mini-menu.
func _matches_gold(mask: int) -> bool:
	if not gold:
		return false
	match gold_mode:
		Gold.MATCH_ALL:
			# "Matching all selected color buttons": every depressed colour
			# must be on the card.
			for color in COLOR_ORDER:
				if color_on(color) and not (mask & color):
					return false
			return true
		Gold.MATCH_ANY:
			for color in COLOR_ORDER:
				if color_on(color) and (mask & color):
					return true
			return false
	return true    # Gold.ALL — "All gold cards"


## The Type Filters: one check per button, ORed — a card is shown if ANY
## depressed button admits it (`deckdll.cpp:7356-7364`, the seven `&&
## !check_*` in a row). Instants and Sorceries are the button alone; the
## other four ask their mini-menu.
##
## LAND (`@LAND`) is not only a type filter: *"The Land filter adds in all
## mana-producing cards (mana sources)"*, so with `Land and Mana` (the
## default) or `Mana only` a depressed Land button also admits Birds of
## Paradise and Sol Ring. Those extra sources are NOT exempt from the
## other groups — *"Which lands are displayed is not affected by the Color
## Filters or Other Filters, but the same is not true for other mana
## sources"* — and they are not, because [method matches] ANDs the groups
## and only [method matches_color] exempts an actual land.
##
## ARTIFACTS (`@ARTIFACT`) splits into two independent toggles, *"All
## Creatures"* and *"All Non-Creatures"*. CREATURES (`@CREATURE`) and
## ENCHANTMENTS (`@ENCHANTMENT`) are [method _admits_creature] and
## [method _admits_enchantment].
func matches_type(d: CardData) -> bool:
	_sync_masks()
	var lit := d.types & _type_on_mask
	if lit & (Mtg.CardType.INSTANT | Mtg.CardType.SORCERY):
		return true
	if (lit & Mtg.CardType.LAND) and land_mode != Land.MANA_ONLY:
		return true
	if lit & Mtg.CardType.ARTIFACT:
		if artifact_creatures if d.is_creature() else artifact_noncreatures:
			return true
	if (lit & Mtg.CardType.CREATURE) and _admits_creature(d):
		return true
	if (lit & Mtg.CardType.ENCHANTMENT) and _admits_enchantment(d):
		return true
	# `Land and Mana` / `Mana only`: the Land button reaches past its own
	# type to every other card that taps for mana.
	if (_type_on_mask & Mtg.CardType.LAND) and land_mode != Land.LAND_ONLY \
			and not d.is_land() and not d.mana_abilities.is_empty():
		return true
	return false


## `check_creatures` (`deckdll.cpp:6995`): Summon is a creature that is
## not an artifact (in 1997 the type line read "Summon Elf"; an artifact
## creature's read "Artifact Creature"), Artifact the other kind, and the
## list an OR term over the card's creature types.
func _admits_creature(d: CardData) -> bool:
	var artifact := (d.types & Mtg.CardType.ARTIFACT) != 0
	if creature_summon and not artifact:
		return true
	if creature_artifact and artifact:
		return true
	if creature_list_on:
		for subtype in d.subtypes:
			if creature_type_on(subtype):
				return true
	return false


## `check_enchantments` (`deckdll.cpp:7015`): a World is its own kind, an
## Aura is the kind of thing it is cast on, and "Enchantments" is what is
## left — the plain global enchantment.
func _admits_enchantment(d: CardData) -> bool:
	return enchantment_on(aura_kind(d))


## Which [enum Aura] check answers for [param d]. A Wall is a creature to
## the 1997 check (`creature_or_wall`), and so is Animate Dead's creature
## card in a graveyard — it ends up on a creature.
static func aura_kind(d: CardData) -> int:
	if d.supertypes & Mtg.Supertype.WORLD:
		return Aura.WORLD
	var target := d.aura_target
	if target == null:
		return Aura.ENCHANTMENTS
	var what := target.description.to_lower()
	if what.contains("artifact"):
		return Aura.ARTIFACT
	if what.contains("land"):
		return Aura.LAND
	if what.contains("enchantment"):
		return Aura.ENCHANT
	return Aura.CREATURE


func matches_set(d: CardData) -> bool:
	return set_on(d.set_code)


## The type-ahead. Empty box = everything. With [member search_rules] on
## the same needle is also tried against the card's rules text ([QoL]).
func matches_text(d: CardData) -> bool:
	if _needle == "":
		return true
	var facts := _facts_for(d)
	if String(facts[FACT_NAME]).contains(_needle):
		return true
	return search_rules and String(facts[FACT_TEXT]).contains(_needle)


## `@CASTCOST` — *"The casting cost filter treats mana cost as a simple
## number"*, i.e. mana value, not the pips.
func matches_cost(d: CardData) -> bool:
	match cost_mode:
		Cost.GE:
			return d.cost.mana_value() >= cost_value
		Cost.LE:
			return d.cost.mana_value() <= cost_value
		Cost.EQ:
			return d.cost.mana_value() == cost_value
		Cost.HAS_X:
			return d.cost.has_x
	return true


## `@POWER` — *"Power gives you a method of ranking creatures according to
## attack strength."* A card with no power is not a creature and cannot
## answer the question, so it is filtered out, exactly as a Power filter
## on a collection of spells shows nothing.
## (The OFF test is here rather than only inside [method _matches_rank]
## because `d.power` was evaluated as an argument on every card in the
## pool even when the filter was off.)
func matches_power(d: CardData) -> bool:
	if power_mode == Rank.OFF:
		return true
	return _matches_rank(power_mode, power_value, d, d.power)


## `@TOUGHNESS` — the same three options *"based solely on their defensive
## damage-absorbing capability"*.
func matches_toughness(d: CardData) -> bool:
	if toughness_mode == Rank.OFF:
		return true
	return _matches_rank(toughness_mode, toughness_value, d, d.toughness)


static func _matches_rank(mode: int, limit: int, d: CardData, value: int) -> bool:
	if mode == Rank.OFF:
		return true
	if not d.is_creature():
		return false
	match mode:
		Rank.GE:
			return value >= limit
		Rank.LE:
			return value <= limit
		Rank.EQ:
			return value == limit
	return true


## `@RARITY` — `check_rarity` (`deckdll.cpp:7107`): off is everything;
## on is an OR over the ticked kinds. A card can be both a rare and
## restricted (Sol Ring is uncommon and restricted), so each tick is
## asked in turn.
func matches_rarity(d: CardData) -> bool:
	if not rarity_on:
		return true
	var kinds := rarity_kinds(d)
	for kind in kinds:
		if rarity_ticked(kind):
			return true
	return false


## Every [enum Rarity] that describes [param d]: its printed rarity
## ([method DeckStats.rarity_of]) and the tournament lists it is on.
static func rarity_kinds(d: CardData) -> Array[int]:
	var kinds: Array[int] = []
	match DeckStats.rarity_of(d.card_name):
		"common":
			kinds.append(Rarity.COMMON)
		"uncommon":
			kinds.append(Rarity.UNCOMMON)
		"rare":
			kinds.append(Rarity.RARE)
	if DeckFormat.RESTRICTED.has(d.card_name):
		kinds.append(Rarity.RESTRICTED)
	if DeckFormat.BANNED.has(d.card_name):
		kinds.append(Rarity.BANNED)
	return kinds


## `@ARTIST` — off is everything; on shows the ticked artists' cards.
func matches_artist(d: CardData) -> bool:
	return not artist_on or artist_ticked(d.artist)


## `@ABILITY` — `check_abilities` (`deckdll.cpp:7126`): off is everything;
## on with neither scope is nothing; otherwise a card is shown if any
## ticked ability is on it natively (Native) or handed out by it (Gives).
func matches_ability(d: CardData) -> bool:
	if not ability_on:
		return true
	if not ability_native and not ability_gives:
		return false
	var wanted := _ability_mask()
	if ability_native and (DeckAbilities.native(d) & wanted):
		return true
	return ability_gives and (DeckAbilities.gives(d) & wanted) != 0


## The ticked abilities as a mask over [enum DeckAbilities.Ability],
## rebuilt with the other masks whenever [member revision] moves.
var _ability_mask_revision := -1
var _ability_on_mask := 0


func _ability_mask() -> int:
	if _ability_mask_revision != revision:
		_ability_mask_revision = revision
		_ability_on_mask = 0
		for ability in DeckAbilities.Ability.values():
			if ability_ticked(ability):
				_ability_on_mask |= 1 << ability
	return _ability_on_mask


## The survivors of [param pool], in [member sort_mode] order. A name
## PREFIX match sorts ahead of a mid-name match, so typing the first few
## letters of a card puts it at the front of the Inventory — which is
## what the manual promises that box does.
##
## The sort keys are computed ONCE per survivor rather than inside the
## comparator: 800 cards is ~7000 comparisons, and building two format
## strings in each of them was most of what this screen spent its time on
## (measured 8.3 ms per call before, 1.6 ms after).
##
## The SECOND audit pass took the remaining allocation out too: the key is
## now an INT read from [method _facts_for]'s per-card table rather than a
## freshly formatted String, so the comparator compares two integers and
## only falls through to the name on a tie.
##
## The THIRD audit pass (2026-09-01) took the SORT out of this call
## altogether. What is sorted is the POOL, which never changes and whose
## order depends only on [member sort_mode] — so it is sorted once per
## order and kept ([method _pool_in_order]), and a filter change becomes a
## walk of that order splitting the survivors into the prefix matches and
## the rest. Concatenating the two lists reproduces the old
## `[prefix, rank, name]` order exactly, because each list is already in
## `[rank, name]` order. Measured on 829 cards: 3.52 ms -> 2.29 ms, and the
## sort itself 1.23 ms -> 0.08 ms.
func apply(pool: Array) -> Array[CardData]:
	var ordered := _pool_in_order(pool)
	var needle := _needle
	var lead: Array[CardData] = []
	var rest: Array[CardData] = []
	for d in ordered:
		if not matches(d):
			continue
		# A name PREFIX match leads, which is what the manual promises the
		# type-ahead does.
		if needle != "" and String(_facts_for(d)[FACT_NAME]).begins_with(needle):
			lead.append(d)
		else:
			rest.append(d)
	lead.append_array(rest)
	return lead


## THE POOL IN [member sort_mode] ORDER, sorted once and kept.
##
## The cache is only used for the SAME ARRAY INSTANCE — `is_same` is
## reference identity for an Array — and only while its length still
## matches, so a caller passing a different list (a test with two cards,
## say) gets a fresh sort and never another list's cards. The order itself
## depends on nothing but the card facts, which never change, and on
## [member sort_mode].
var _order: Array[CardData] = []
var _order_pool: Array = []
var _order_mode := -1


func _pool_in_order(pool: Array) -> Array[CardData]:
	if _order_mode == sort_mode and _order.size() == pool.size() \
			and is_same(_order_pool, pool):
		return _order
	var column: int = SORT_COLUMN.get(sort_mode, FACT_NAME)
	var keyed: Array = []
	keyed.resize(pool.size())
	for i in pool.size():
		var facts := _facts_for(pool[i])
		# Sort.NAME has no rank of its own; the name below decides it.
		keyed[i] = [0 if column == FACT_NAME else int(facts[column]),
			facts[FACT_NAME], pool[i]]
	keyed.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] != b[0]:
			return a[0] < b[0]
		return a[1] < b[1])
	var out: Array[CardData] = []
	out.resize(keyed.size())
	for i in keyed.size():
		out[i] = keyed[i][2]
	_order = out
	_order_pool = pool
	_order_mode = sort_mode
	return out


## Creatures first, lands last — how a decklist is written.
static func type_rank(d: CardData) -> int:
	for i in TYPE_SORT_RANK.size():
		if d.types & TYPE_SORT_RANK[i]:
			return i
	return TYPE_SORT_RANK.size()


## WUBRG, then gold, then colourless — the order the mana pool and the
## mana stripes are already drawn in (Mtg.WUBRG).
static func color_rank(d: CardData) -> int:
	var mask := d.color_mask()
	if mask == 0:
		return 7
	var lit := 0
	var first := 6
	for i in Mtg.WUBRG.size():
		if mask & Mtg.WUBRG[i]:
			lit += 1
			first = mini(first, i)
	return 6 if lit > 1 else first
