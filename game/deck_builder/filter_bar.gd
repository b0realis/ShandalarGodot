class_name FilterBar
extends HBoxContainer
## THE FILTER STRIP — the original's four Filter groups on ONE ROW of
## medallions, which is how the 1997 program actually drew them. The manual
## (ch.10) names the groups and places the strip: *"Between the Inventory
## and Deck areas are four sets of Filter buttons. These determine which
## cards are displayed in the inventory."* — Color Filters, Set Filters,
## Type Filters, Other Filters.
##
## THE SCREENSHOT PASS (2026-08-31) RESTYLED THIS BAR to the owner's own
## 1997 screenshot of the in-Shandalar Deck screen, and the screenshot
## settled four things the earlier passes had had to infer:
##
## 1. ONE ROW, NOT FOUR LABELLED COLUMNS. 40x40 medallions in a single
##    strip, groups told apart by a wider gap and nothing else. The group
##    HEADINGS the building pass drew are not in the original; the groups
##    survive as structure ([constant GROUPS], [method group_names]) and in
##    each button's cue card, which is where 1997 put the words. (The
##    screenshot's own strip is eighteen wide because it is the
##    in-Shandalar screen and carries no Set Filters; ours is twenty-three,
##    which is the manual's four groups — see [constant TYPE_CELL].)
## 2. THE COLOURS ARE MEDALLIONS TOO — W/U/B/R/G as coloured glyphs on
##    black discs, cells (2,8) (0,7) (1,6) (2,4) (1,5) of the same sheet.
##    The big carved `Bldr_sheet` plaques the building pass put here are
##    not filter buttons at all; they are the DECK AREA's empty-slot
##    watermarks (tools/import_original.py, `deck_slot_plaques`).
## 3. WHICH SHEET IS "ON". Every filter in the screenshot is depressed —
##    its Inventory starts at Abu Ja'far and runs on alphabetically, so
##    nothing is being hidden — and every medallion matches the NORMAL
##    sheet's luminance and not the `_pressed` sheet's. The second audit
##    pass re-measured all eighteen against their own matched cells: the
##    screenshot reads 85.6-138.9, `sprite_sheet` 68.3-128.0 and
##    `sprite_sheet_pressed` 38.0-71.8, i.e. the capture tracks the normal
##    sheet within a few points and the pressed sheet at half. So ON is the
##    plain medallion and OFF is the dark sunken one, a 2:1 split that
##    needs no tint. The invented warm/cool `ON_TINT`/`OFF_TINT` pair is
##    retired.
## 4. ENCHANTMENTS AND SORCERIES — see [constant TYPE_CELL], which also
##    records the second audit pass's independent re-verification.
##
## THE MINI-MENUS. *"You can also right-click on some of the filter
## buttons to open a mini-menu of options. These represent sub-groups of
## that filter."* Right-clicking Land, Artifacts, Gold, Casting Cost,
## Power or Toughness opens that button's own menu, with the string
## table's entries verbatim (`@LAND`, `@ARTIFACT`, `@GOLD`, `@CASTCOST`,
## `@POWER`, `@TOUGHNESS`). The five sub-filters that are LISTS —
## `@CREATURE`, `@ENCHANTMENT`, `@ABILITY`, `@RARITY`, `@ARTIST` — are
## the pages of the FILTER WINDOW (2026-09-06), opened by the funnel
## medallion that closes the Other Filters group and by a right-click on
## Creatures or Enchantments; see [method window_pages].
##
## THE TAIL OF THE ROW IS [QoL] and is described at [method _search_group]:
## the type-ahead the manual promises and the Inventory's sort. Both set
## fields on the same [DeckFilter], so they belong on the same strip;
## putting them here also deleted the separate Inventory header strip the
## restyle had no room for.
##
## Without the skin every toggle falls back to a lettered 1997 button, so
## the bar still works and still reads.

signal changed

## A right-click on a filter button that owns a mini-menu — the screen
## puts the dialog up, because it owns the modal layer. The request
## carries `title`, `lines` (already marked with the current state),
## `pick` (Callable taking the chosen index) and, when the filter compares
## against a number, `amount` / `set_amount`. A menu of INDEPENDENT checks
## also carries `relabel` (Callable -> the lines as they now read), so the
## screen can keep it open and tick several. The FILTER WINDOW's request
## is the other shape, [method window_request]'s.
signal menu_requested(request: Dictionary)

## The Showcase's `Expand` toggle was flipped. The bar does not own the
## Showcase, so it says so and the screen re-applies it.
signal expand_toggled(on: bool)

const CELL := 40
## Displayed medallion size. 34 rather than the art's 40: twenty-four
## medallions, four group gaps and the [QoL] tail have to fit the 1280
## window the game opens in (tests/ui/test_deck_builder.gd pins it).
const ICON_SIZE := Vector2(34, 34)
## Separation inside a group, and the wider gap that tells two groups
## apart — the original's only grouping cue on this row.
const IN_GROUP := 2
const BETWEEN_GROUPS := 12

## The manual's four names, in its own order. Kept as data because the
## groups are real — the filters are additive within one and exclusive
## between them (DeckFilter.matches) — even though 1997 draws no headings.
const GROUPS: Array[String] = [
	"Color Filters", "Set Filters", "Type Filters", "Other Filters",
]

## The five COLOUR medallions, read off the owner's 1997 screenshot: a
## coloured glyph on a black disc, the only cells drawn that way.
const COLOR_CELL := {
	Mtg.ManaColor.W: [2, 8],
	Mtg.ManaColor.U: [0, 7],
	Mtg.ManaColor.B: [1, 6],
	Mtg.ManaColor.R: [2, 4],
	Mtg.ManaColor.G: [1, 5],
}

## Cells of `filter_icons`, as [row, col]. Decoded against Manalink's
## DBArt icon files (see tools/import_original.py) and then CHECKED
## AGAINST A RENDER OF THE REAL PROGRAM.
##
## The 2026-08-31 audit pass, matching silhouettes, moved Sorcery to (0,5)
## and Enchantment to (2,6). The screenshot pass overturns both. The
## owner's 1997 screenshot shows the type group in the manual's own order
## — Land, Artifacts, Creatures, Enchantments, Instants, Interrupts,
## Sorceries — and each medallion, cut out and correlated against all 27
## cells, lands on:
##
##   Land (2,0) mountains · Artifacts (0,4) chalice · Creatures (1,1) bat
##   Enchantments (1,3) crescent · Instants (1,7) bolt
##   Interrupts (1,8) open hand · Sorceries (2,6)
##
## The discriminator the screenshot pass used was THE GOLD RING: every SET
## medallion wears one and no type button does. (1,2) is a crescent WITH
## the ring (The Dark); (1,3) is the same crescent WITHOUT it, and it is
## Enchantments — not the "spare set medallion" two passes called it.
## (2,5)'s exclamation mark does wear the ring, so the audit was right that
## it is a set and wrong that Enchantment was ever near it. (0,5) goes back
## to unassigned.
##
## THE SECOND AUDIT PASS (2026-08-31) VERIFIED THIS MAP INDEPENDENTLY AND
## IT IS RIGHT — three revisions is a sign the question is hard, not a
## licence to move it a fourth time. The check did not reuse the earlier
## reasoning: the strip in the owner's screenshot was located by its bevel
## (eighteen buttons on a 39px pitch, 40px tall, drawn 1:1), a single
## global (dx, dy) alignment was fitted across all eighteen at once, and
## each was then correlated against all 27 cells of all three sheets.
## Every one has a UNIQUE top match, and the two contested cells are not
## close calls:
##
##   Enchantments -> (1,3)  r=0.635, runner-up 0.437
##   Sorceries    -> (2,6)  r=0.651, runner-up 0.529
##
## Two footnotes to the record, both from the same check:
##
## - THE GOLD RING IS NOT A RULE. (0,1) is `Gold`, a COLOUR filter, and it
##   wears one. It happens to separate the type run from the sets, which is
##   all the screenshot pass needed it for.
## - THE SCREENSHOT'S STRIP HAS NO SET GROUP. Its eighteen medallions are
##   six colours, the seven types and the five Other Filters; no button
##   matches the anvil, the scimitar, the ringed crescent, the IV, the
##   column or the comet. That capture is the IN-SHANDALAR Deck screen. The
##   Set Filters the manual lists as one of its four groups — and the six
##   ringed set medallions the sheet carries for them — belong to the
##   STANDALONE Deck Builder, which is the screen this file draws, so this
##   strip carries twenty-three medallions and not eighteen.
const TYPE_CELL := {
	Mtg.CardType.LAND: [2, 0],
	Mtg.CardType.ARTIFACT: [0, 4],
	Mtg.CardType.CREATURE: [1, 1],
	Mtg.CardType.ENCHANTMENT: [1, 3],
	Mtg.CardType.INSTANT: [1, 7],
	Mtg.CardType.SORCERY: [2, 6],
}
## `@POWER`'s sword and `@TOUGHNESS`'s quartered shield, both confirmed in
## place by the screenshot's Other Filters run (X, sword, shield, eye, gem).
const POWER_CELL := [2, 2]
const TOUGHNESS_CELL := [2, 7]
## `@ABILITY`'s eye and `@RARITY`'s gem, both in the screenshot's Other
## Filters run, and `@ARTIST`'s palette — the one cell left unassigned by
## the audits, and the sheet's only glyph that is a painter's tool. Not
## medallions here (the strip has no room for three more — the owner,
## 2026-09-06) but the tabs of their pages in the filter window.
const ABILITY_CELL := [0, 0]
const RARITY_CELL := [2, 3]
const ARTIST_CELL := [0, 5]
## [QoL] The funnel that opens the filter window — not on the 1997 sheet,
## so [method sheet_cell] composes it from the `X` medallion's disc in
## the sheet's own inks ([method _funnel_cell]). The owner asked for a
## funnel by name.
const FUNNEL_CELL := [-1, -1]
const FUNNEL_CENTRE := Vector2(20, 19)
const FUNNEL_RADIUS := 13.5
## The six sets the original drew a filter medallion for. Unlimited and
## the promos have none — as the printed cards have no set symbol either
## (game/skin.gd SET_LABELS) — so those two toggles are lettered.
const SET_CELL := {
	"atq": [0, 2], "arn": [0, 3], "past": [0, 6],
	"drk": [1, 2], "4ed": [1, 4], "leg": [2, 1],
}
const GOLD_CELL := [0, 1]
const COST_CELL := [0, 8]

# ------------------------------------------------------- the mini-menus --
# The string table's own entries (`s30/assets/text/Menus.txt` — the 1997
# copy; `shandalar-src/Program/Menus.txt` is Manalink-updated and renames
# Gold to Multicolored), minus the Windows accelerator markers.

## `@LAND` (Menus.txt:320).
const LAND_MENU: Array[String] = ["Land and Mana", "Land only", "Mana only"]
## `@ARTIFACT` (Menus.txt:326) — independent toggles, not a pick-one.
const ARTIFACT_MENU: Array[String] = ["All Creatures", "All Non-Creatures"]
## `@GOLD` (Menus.txt:314).
const GOLD_MENU: Array[String] = ["All gold cards",
	"Matching all selected color buttons", "Matching any selected color button"]
## `@CASTCOST` (Menus.txt:347), minus its OFF state, which is the button up.
const COST_MENU: Array[String] = ["Greater than or equal to",
	"Less than or equal to", "Equal to", "X cost"]
## `@POWER` / `@TOUGHNESS` (Menus.txt:354, :360) — the same three.
const RANK_MENU: Array[String] = ["Greater than or equal to",
	"Less than or equal to", "Equal to"]
## `@LONGLIST` (Menus.txt:19-23) minus its first entry: the 1997 list
## window's own "Enable Filter / Select All / Clear All". `Enable Filter`
## is the window's master switch and this strip has none — the medallions
## ARE the filter — but the other two are the answer to a strip of
## twenty-four toggles with no way back, and they are the ORIGINAL's own
## words for it. Every medallion that has no sub-menu of its own opens
## this one on a right-click, which is the manual's own promise that
## *"you can also right-click on some of the filter buttons"* extended to
## the rest of them, in the era's language.
##
## The third line is [QoL] and says so on the menu: the rules-text switch
## for the type-ahead ([member DeckFilter.search_rules]). It lived on the
## eye medallion while that one had no filter of its own; `@ABILITY` has
## it back, and the switch is a property of the box, so it sits with the
## box's other commands and on a right-click of the box itself.
const ALL_MENU: Array[String] = ["Select All", "Clear All"]
const RULES_LINE := "Search card text too  [QoL]"
## [QoL] The Inventory's own order, offered through the same mini-menu
## idiom rather than a dropdown, so the row stays 1997 furniture.
const SORT_MENU: Array[String] = ["Name", "Casting cost", "Card Type",
	"Color", "Set"]
const SORT_ID: Array[int] = [DeckFilter.Sort.NAME, DeckFilter.Sort.COST,
	DeckFilter.Sort.TYPE, DeckFilter.Sort.COLOR, DeckFilter.Sort.SET]

## [QoL] THE SCREEN'S SOUND, so a medallion can grind when it goes down —
## the owner's playtest, 2026-09-04: *"A quick stone grinding sound when
## pressing the stone filter buttons, based on my sample."* Null until the
## screen sets it, and a null one is simply silence: this strip is built
## in tests and in the Deck Lab without a screen around it.
##
## IT IS PLAYED ON THE PRESS AND NOT ON [signal changed], because `changed`
## is also what the sort menu and `Select All` emit and neither of those is
## a stone button.
var sound: DeckAudio = null

var filter: DeckFilter

## [QoL] The type-ahead box and the Sort button, both live on this row.
var search_field: LineEdit
var sort_button: Button
## The Showcase's `Expand` toggle — see `_flip_expand`.
var expand_button: Button

var _buttons: Array[Button] = []
## Group name -> its buttons, so [method group_names] can prove the
## manual's four groups are all still on the strip.
var _groups: Dictionary = {}
static var _cell_cache: Dictionary = {}


func _init(p_filter: DeckFilter) -> void:
	filter = p_filter
	add_theme_constant_override("separation", BETWEEN_GROUPS)
	add_child(_color_group())
	add_child(_set_group())
	add_child(_type_group())
	add_child(_other_group())
	add_child(_search_group())
	# `@LONGLIST` on every medallion that has no sub-menu of its own, so a
	# right-click anywhere on the strip reaches Select All / Clear All.
	for button in _buttons:
		if not button.has_meta("has_menu"):
			_with_all_menu(button)
	refresh()


## `Select All` / `Clear All` — the strip's own [constant ALL_MENU].
func _with_all_menu(button: Button) -> void:
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not event.pressed \
				or event.button_index != MOUSE_BUTTON_RIGHT:
			return
		button.accept_event()
		open_all_menu())


## Put the strip's `@LONGLIST` mini-menu up. Public so the screen's own
## mini-menu can reach the same two commands.
func open_all_menu() -> void:
	var lines: Array[String] = ALL_MENU.duplicate()
	lines.append(_checked(filter.search_rules, RULES_LINE))
	menu_requested.emit({
		"title": "Filters",
		"lines": lines,
		"pick": func(index: int) -> void:
			match index:
				0:
					filter.select_all()
				1:
					filter.clear_all()
				_:
					filter.search_rules = not filter.search_rules
			refresh()
			changed.emit(),
		"amount": Callable(),
		"set_amount": Callable(),
	})


## A menu line that shows its own state, in the convention the screen's
## own mini-menu uses for its checked commands.
static func _checked(on: bool, text: String) -> String:
	return ("[x] " if on else "[  ] ") + text


## The manual's four group names, in its order — the structure that
## survived the restyle to one unlabelled row.
func group_names() -> Array[String]:
	return GROUPS.duplicate()


## The toggles of one group, by the manual's name for it.
func group_buttons(name: String) -> Array:
	return _groups.get(name, [])


## One group of the strip: a tight run of medallions. The wider
## [constant BETWEEN_GROUPS] gap around it is this bar's own separation.
func _group(title: String) -> HBoxContainer:
	var strip := HBoxContainer.new()
	strip.name = title.replace(" ", "")
	strip.add_theme_constant_override("separation", IN_GROUP)
	_groups[title] = []
	return strip


func _add(strip: HBoxContainer, title: String, button: Button) -> void:
	strip.add_child(button)
	_groups[title].append(button)


func _color_group() -> Control:
	var strip := _group(GROUPS[0])
	for color in DeckFilter.COLOR_ORDER:
		var label: String = DeckFilter.COLOR_LABELS[color]
		var button := _toggle(label,
			func() -> bool: return filter.color_on(color),
			func() -> void: filter.toggle_color(color))
		_dress_icon(button, COLOR_CELL[color])
		_add(strip, GROUPS[0], button)
	# `@GOLD` — the sixth Color Filter, with its own mini-menu.
	var gold := _toggle("Gold",
		func() -> bool: return filter.gold,
		func() -> void: filter.gold = not filter.gold)
	_dress_icon(gold, GOLD_CELL)
	_with_menu(gold, "Gold", GOLD_MENU,
		func() -> int: return filter.gold_mode,
		func(index: int) -> void: filter.gold_mode = index)
	_add(strip, GROUPS[0], gold)
	return strip


func _set_group() -> Control:
	var strip := _group(GROUPS[1])
	for code in CardRegistry.SET_ORDER:
		var label: String = DeckFilter.SET_LABELS.get(code, code.to_upper())
		var button := _toggle(label,
			func() -> bool: return filter.set_on(code),
			func() -> void: filter.toggle_set(code))
		if SET_CELL.has(code):
			_dress_icon(button, SET_CELL[code])
		else:
			_dress_text(button, GameSkin.set_label(code))
		_add(strip, GROUPS[1], button)
	return strip


func _type_group() -> Control:
	var strip := _group(GROUPS[2])
	for type_flag in DeckFilter.TYPE_ORDER:
		var label: String = DeckFilter.TYPE_LABELS[type_flag]
		var button := _toggle(label,
			func() -> bool: return filter.type_on(type_flag),
			func() -> void: filter.toggle_type(type_flag))
		_dress_icon(button, TYPE_CELL[type_flag])
		if type_flag == Mtg.CardType.LAND:
			# `@LAND` — three mutually exclusive options.
			_with_menu(button, "Land", LAND_MENU,
				func() -> int: return filter.land_mode,
				func(index: int) -> void: filter.land_mode = index)
		elif type_flag == Mtg.CardType.ARTIFACT:
			# `@ARTIFACT` — two INDEPENDENT toggles, so this menu ticks
			# rather than picks.
			_with_checks(button, "Artifacts", ARTIFACT_MENU,
				func() -> Array: return [filter.artifact_creatures,
					filter.artifact_noncreatures],
				func(index: int) -> void:
					if index == 0:
						filter.artifact_creatures = not filter.artifact_creatures
					else:
						filter.artifact_noncreatures = not filter.artifact_noncreatures)
		elif type_flag == Mtg.CardType.CREATURE:
			# `@CREATURE` — its page of the filter window.
			_with_window(button, "creatures")
		elif type_flag == Mtg.CardType.ENCHANTMENT:
			# `@ENCHANTMENT` — likewise.
			_with_window(button, "enchantments")
		_add(strip, GROUPS[2], button)
	return strip


## `Other Filters` — the original's group of six (Casting Cost, Power,
## Toughness, Ability, Rarity, Artist). The first three are here as the
## original drew them, buttons with right-click mini-menus that compare
## against a number, each menu ending with that number so one gesture
## sets both halves of "power >= 4". The last three were ENABLE switches
## whose right-click was a window of checks; they are the pages of ONE
## filter window here, behind the funnel that closes the group — see
## [method window_pages].
func _other_group() -> Control:
	var strip := _group(GROUPS[3])

	var cost := _toggle("cast cost",
		func() -> bool: return filter.cost_mode != DeckFilter.Cost.OFF,
		func() -> void: filter.cost_mode = DeckFilter.Cost.OFF \
			if filter.cost_mode != DeckFilter.Cost.OFF else DeckFilter.Cost.LE,
		true)
	_dress_icon(cost, COST_CELL)
	_with_menu(cost, "Casting Cost", COST_MENU,
		func() -> int: return filter.cost_mode - 1,
		func(index: int) -> void: filter.cost_mode = index + 1,
		func() -> int: return filter.cost_value,
		func(value: int) -> void: filter.cost_value = value)
	_add(strip, GROUPS[3], cost)

	var power := _toggle("power",
		func() -> bool: return filter.power_mode != DeckFilter.Rank.OFF,
		func() -> void: filter.power_mode = DeckFilter.Rank.OFF \
			if filter.power_mode != DeckFilter.Rank.OFF else DeckFilter.Rank.GE,
		true)
	_dress_icon(power, POWER_CELL)
	_with_menu(power, "Power", RANK_MENU,
		func() -> int: return filter.power_mode - 1,
		func(index: int) -> void: filter.power_mode = index + 1,
		func() -> int: return filter.power_value,
		func(value: int) -> void: filter.power_value = value)
	_add(strip, GROUPS[3], power)

	var toughness := _toggle("toughness",
		func() -> bool: return filter.toughness_mode != DeckFilter.Rank.OFF,
		func() -> void: filter.toughness_mode = DeckFilter.Rank.OFF \
			if filter.toughness_mode != DeckFilter.Rank.OFF else DeckFilter.Rank.GE,
		true)
	_dress_icon(toughness, TOUGHNESS_CELL)
	_with_menu(toughness, "Toughness", RANK_MENU,
		func() -> int: return filter.toughness_mode - 1,
		func(index: int) -> void: filter.toughness_mode = index + 1,
		func() -> int: return filter.toughness_value,
		func(value: int) -> void: filter.toughness_value = value)
	_add(strip, GROUPS[3], toughness)

	# [QoL] THE FUNNEL — the door to the filter window, closing the group
	# where the 1997 strip went on to Ability, Rarity and Artist. It is
	# lit while any of the window's pages is narrowing the list, and a
	# click with either button opens the window — the original's three
	# medallions were enable switches whose right-click was the window,
	# and this one is the same door for all five pages.
	var funnel := _toggle("the Filter window",
		func() -> bool: return filter.lists_active(),
		func() -> void: menu_requested.emit(window_request("")),
		true)
	_dress_icon(funnel, FUNNEL_CELL)
	_with_window(funnel, "")
	_add(strip, GROUPS[3], funnel)
	return strip


# ---------------------------------------------------- the filter window --

## THE FILTER WINDOW's five pages, one per 1997 sub-filter of
## [constant DeckFilter.SHIPPED]: the `@LONGLIST` shape (Menus.txt:19) —
## "Enable Filter" at the head, a long multi-select list, "Select All" /
## "Clear All", OK and Cancel — with the five lists side by side as pages
## of ONE window rather than five windows behind three medallions the
## strip had no room for. The strip only DESCRIBES the pages; the screen
## owns the modal layer and draws the window
## ([method DeckBuilderScreen._open_filter_window]).
##
## A page is `key`, `title`, `icon` (the medallion cell the 1997 program
## gave the same filter, so the page tab wears it), `heads` (the check
## lines above the list, a `{}` being a rule between them), `entries` /
## `labels` / `ticked` / `tick` (the list itself — `entries` are the
## filter's own keys, `labels` what the window writes for them: the
## registry keeps creature types in lower case, `@CREATURENAMES` wrote
## them capitalised) and `finder`, on for the two lists long enough to
## need a type-ahead. Every Callable edits the [DeckFilter] live and
## re-reads the strip, so the Inventory re-lists under the window as
## checks are ticked; `snapshot` / `restore` are what Cancel puts back.
func window_request(page: String) -> Dictionary:
	return {
		"window": true,
		"page": page,
		"pages": window_pages(),
		"snapshot": func() -> Dictionary: return filter.window_snapshot(),
		"restore": func(kept: Dictionary) -> void:
			filter.window_restore(kept)
			refresh()
			changed.emit(),
	}


func window_pages() -> Array[Dictionary]:
	var ability_labels: Array = []
	for i in DeckAbilities.LABELS.size():
		var label: String = DeckAbilities.LABELS[i]
		if DeckAbilities.MODERN.has(i):
			label += "  (%s)" % DeckAbilities.MODERN[i]
		ability_labels.append(label)
	var creature_labels: Array = []
	for subtype in creature_types():
		creature_labels.append(String(subtype).capitalize())
	return [
		# `@CREATURE` — Summon and Artifact tick, "Summon from list" is
		# the list's own enable, and the list is an OR term on top of
		# the two (DeckFilter.creature_summon).
		_page("creatures", "Creatures", TYPE_CELL[Mtg.CardType.CREATURE], [
			_head("Summon",
				func() -> bool: return filter.creature_summon,
				func(on: bool) -> void: filter.creature_summon = on),
			_head("Artifact",
				func() -> bool: return filter.creature_artifact,
				func(on: bool) -> void: filter.creature_artifact = on),
			{},
			_head("Summon from list",
				func() -> bool: return filter.creature_list_on,
				func(on: bool) -> void: filter.creature_list_on = on),
		], creature_types(), creature_labels,
			func(key: Variant) -> bool: return filter.creature_type_on(String(key)),
			func(key: Variant, on: bool) -> void:
				filter.tick_creature_type(String(key), on),
			true),
		# `@ENCHANTMENT` — six independent checks, no master switch.
		_page("enchantments", "Enchantments", TYPE_CELL[Mtg.CardType.ENCHANTMENT], [],
			DeckFilter.Aura.values(), _labels(DeckFilter.Aura.values(), DeckFilter.AURA_LABELS),
			func(key: Variant) -> bool: return filter.enchantment_on(int(key)),
			func(key: Variant, on: bool) -> void: filter.tick_enchantment(int(key), on)),
		# `@ABILITY` — Native, Gives, then the thirteen.
		_page("abilities", "Abilities", ABILITY_CELL, [
			_head("Enable Filter",
				func() -> bool: return filter.ability_on,
				func(on: bool) -> void: filter.ability_on = on),
			{},
			_head("Native",
				func() -> bool: return filter.ability_native,
				func(on: bool) -> void: filter.ability_native = on),
			_head("Gives",
				func() -> bool: return filter.ability_gives,
				func(on: bool) -> void: filter.ability_gives = on),
		], range(DeckAbilities.LABELS.size()), ability_labels,
			func(key: Variant) -> bool: return filter.ability_ticked(int(key)),
			func(key: Variant, on: bool) -> void: filter.tick_ability(int(key), on)),
		# `@RARITY` — five checks, ORed.
		_page("rarity", "Rarity", RARITY_CELL, [
			_head("Enable Filter",
				func() -> bool: return filter.rarity_on,
				func(on: bool) -> void: filter.rarity_on = on),
		], DeckFilter.Rarity.values(), _labels(DeckFilter.Rarity.values(), DeckFilter.RARITY_LABELS),
			func(key: Variant) -> bool: return filter.rarity_ticked(int(key)),
			func(key: Variant, on: bool) -> void: filter.tick_rarity(int(key), on)),
		# `@ARTIST` — `@ARTISTNAMES` from the pool itself rather than a
		# fixed table, so a card that arrives with a new painter lists it.
		_page("artists", "Artists", ARTIST_CELL, [
			_head("Enable Filter",
				func() -> bool: return filter.artist_on,
				func(on: bool) -> void: filter.artist_on = on),
		], artists(), artists(),
			func(key: Variant) -> bool: return filter.artist_ticked(String(key)),
			func(key: Variant, on: bool) -> void: filter.tick_artist(String(key), on),
			true),
	]


## One check line above a page's list.
func _head(text: String, get_on: Callable, set_on: Callable) -> Dictionary:
	return {
		"text": text,
		"get": get_on,
		"set": func(on: bool) -> void:
			set_on.call(on)
			refresh()
			changed.emit(),
	}


func _page(key: String, title: String, icon: Array, heads: Array,
		entries: Array, labels: Array, ticked: Callable, tick: Callable,
		finder := false) -> Dictionary:
	return {
		"key": key,
		"title": title,
		"icon": sheet_cell("filter_icons", icon[0], icon[1]),
		"heads": heads,
		"entries": entries,
		"labels": labels,
		"ticked": ticked,
		"tick": func(entry: Variant, on: bool) -> void:
			tick.call(entry, on)
			refresh()
			changed.emit(),
		"finder": finder,
	}


static func _labels(kinds: Array, table: Dictionary) -> Array:
	var out: Array = []
	for kind in kinds:
		out.append(table[kind])
	return out


## Every creature type the pool knows, sorted, computed once; and every
## painter.
static var _creature_types: Array = []
static var _artists: Array = []


static func creature_types() -> Array:
	if _creature_types.is_empty():
		var seen := {}
		for card_name in CardRegistry.all_names():
			var d := CardRegistry.get_card(card_name)
			if d.is_creature():
				for subtype in d.subtypes:
					seen[subtype] = true
		_creature_types = seen.keys()
		_creature_types.sort()
	return _creature_types


static func artists() -> Array:
	if _artists.is_empty():
		var seen := {}
		for card_name in CardRegistry.all_names():
			var artist := CardRegistry.get_card(card_name).artist
			if artist != "":
				seen[artist] = true
		_artists = seen.keys()
		_artists.sort()
	return _artists


## A right-click that opens the filter window on [param page].
func _with_window(button: Button, page: String) -> void:
	button.set_meta("has_menu", true)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not event.pressed \
				or event.button_index != MOUSE_BUTTON_RIGHT:
			return
		button.accept_event()
		menu_requested.emit(window_request(page)))


## [QoL] THE TAIL OF THE STRIP. Controls that all write to the same
## [DeckFilter] the medallions do, so this is where they belong once the
## restyle takes the Inventory's own header strip away:
##
## - the TYPE-AHEAD box the manual promises: *"you can type in the first
##   few letters of the name of any card you want to see"*. Sunken 1997
##   stone, not a modern field. Its rules-text switch is on the Filters
##   menu ([constant RULES_LINE]), which a right-click on the box opens.
##   (The switch wore the eye medallion until `@ABILITY` took it back.)
## - SORT, as a bevelled button with a mini-menu rather than a dropdown —
##   the same idiom the filter buttons use for their sub-groups.
func _search_group() -> Control:
	var strip := HBoxContainer.new()
	strip.name = "Search"
	strip.add_theme_constant_override("separation", 6)
	strip.size_flags_horizontal = Control.SIZE_EXPAND_FILL

	# `panel_dark_stone` ([method OriginalDialog.text_field]), not the
	# Situation Bar's Telluser: Telluser is red-brown and put a salmon box
	# in the middle of a blue strip. The placeholder is SHORT on purpose:
	# the field is the one thing on the strip that gives way when the
	# twenty-odd medallions ask for their width, and at 1280 the older
	# "type the first letters" was cut to *"type the first let"*.
	# [QoL] `clears`: the × that empties the box. The box IS the filter —
	# there is no medallion to put up — and the owner's question was the
	# right one (2026-09-07): *"How do we now turn on or off the type-ahead
	# filter? It has no button"*. Escape and Select All both did it; neither
	# is written on the box. Now the box says so itself.
	search_field = OriginalDialog.text_field("type a name",
		Vector2(100, ICON_SIZE.y), true)
	search_field.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	search_field.tooltip_text = "type a name — the cross or Escape clears it; right-click for the card-text switch"
	search_field.text_changed.connect(func(value: String) -> void:
		filter.text = value
		changed.emit())
	search_field.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			search_field.accept_event()
			open_all_menu())
	strip.add_child(search_field)

	sort_button = OriginalDialog.button(_sort_label(), Vector2(96, ICON_SIZE.y))
	sort_button.pressed.connect(_open_sort_menu)
	sort_button.tooltip_text = "[QoL] the order the Inventory is listed in"
	strip.add_child(sort_button)

	# THE EXPAND TOGGLE, GIVEN A DOOR YOU CAN SEE. The 1997 game put it
	# behind a right-click on the Showcase's text area (`@MENU_FULLCARD`
	# entry 1, `Duel.hlp`: *"Right-click on the text area, then click on
	# the Expand toggle"*) — a gesture nobody finds, which is why the
	# 2026-09-05 playtest reported long card text clipping rather than
	# reporting a toggle that was off. Same setting, same behaviour;
	# this is a second door, not a second feature, and it shows its state
	# so the Showcase's mode is readable at a glance.
	expand_button = OriginalDialog.button(_expand_label(), Vector2(96, ICON_SIZE.y))
	expand_button.toggle_mode = true
	expand_button.button_pressed = CardPreview.expand_wanted()
	expand_button.pressed.connect(_flip_expand)
	expand_button.tooltip_text = "[QoL] grow a card's text box when the " \
		+ "text does not fit — the original's own Expand toggle"
	strip.add_child(expand_button)
	return strip


## The Showcase's `Expand` state, as a label that says which way it is.
func _expand_label() -> String:
	return "Text: full" if CardPreview.expand_wanted() else "Text: 1997"


func _flip_expand() -> void:
	var on := not CardPreview.expand_wanted()
	CardPreview.set_expand(on)
	expand_button.button_pressed = on
	expand_button.text = _expand_label()
	expand_toggled.emit(on)


func _sort_label() -> String:
	return "Sort: %s" % SORT_MENU[maxi(SORT_ID.find(filter.sort_mode), 0)]


func _open_sort_menu() -> void:
	var at := maxi(SORT_ID.find(filter.sort_mode), 0)
	var lines: Array[String] = []
	for i in SORT_MENU.size():
		lines.append(("• " if i == at else "    ") + SORT_MENU[i])
	menu_requested.emit({
		"title": "Sort",
		"lines": lines,
		"pick": func(index: int) -> void:
			filter.sort_mode = SORT_ID[index]
			refresh()
			changed.emit(),
		"amount": Callable(),
		"set_amount": Callable(),
	})


## A toggle whose look is driven by [param is_on] and whose click runs
## [param flip]. The whole bar re-reads itself afterwards, because the
## Gold button's meaning depends on which colours are lit.
## [param ranged] picks the cue card's other sentence — Cuecards.txt gives
## the Other Filters "Cards are filtered by cast cost", not "Cast cost
## cards are in the list".
func _toggle(cue_label: String, is_on: Callable, flip: Callable,
		ranged := false) -> Button:
	var button := Button.new()
	button.toggle_mode = true
	button.focus_mode = Control.FOCUS_ALL
	button.set_meta("is_on", is_on)
	button.set_meta("cue", cue_label)
	button.set_meta("ranged", ranged)
	button.pressed.connect(func() -> void:
		if sound != null:
			sound.play(DeckAudio.CUE_FILTER)
		flip.call()
		refresh()
		changed.emit())
	_buttons.append(button)
	return button


## The cue card this button shows, in whichever of Cuecards.txt's two
## sentences its group uses.
static func _cue_for(button: Button, on: bool) -> String:
	var label := String(button.get_meta("cue"))
	if bool(button.get_meta("ranged", false)):
		return DeckFilter.filtered_by_cue_card(label, on)
	return DeckFilter.cue_card(label, on)


## Re-read every toggle's state onto its button — the plain medallion for a
## depressed (ON) filter, the dark sunken one for a raised (OFF) filter.
##
## THERE IS NOTHING TO REPAINT HERE ANY MORE, and that is the 2026-09-03
## press fix rather than an optimisation: both looks are bound to the
## button's own draw states once, at dress time, so LATCHING IT IS
## DRAWING IT. See the head of "the paint" below. (The pass this replaces
## repainted from here, which is also why the press was invisible: this
## runs off `pressed`, and a toggle in Godot's default
## ACTION_MODE_BUTTON_RELEASE emits that on the mouse coming UP.)
func refresh() -> void:
	if sort_button != null:
		sort_button.text = _sort_label()
	if search_field != null and search_field.text != filter.text:
		search_field.text = filter.text
	for button in _buttons:
		var on: bool = button.get_meta("is_on").call()
		button.set_pressed_no_signal(on)
		button.tooltip_text = _cue_for(button, on)


# ------------------------------------------------------- the mini-menus --

## Give [param button] a right-click mini-menu of mutually exclusive
## options — *"You can also right-click on some of the filter buttons to
## open a mini-menu of options."* The current pick is ticked.
## [param amount] / [param set_amount], when given, add the comparison's
## number to the same menu, which is where `@CASTCOST` and `@POWER` need
## it: choosing "Greater than or equal to" is half an answer on its own.
func _with_menu(button: Button, title: String, entries: Array[String],
		chosen: Callable, pick: Callable,
		amount := Callable(), set_amount := Callable()) -> void:
	button.set_meta("has_menu", true)
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not event.pressed \
				or event.button_index != MOUSE_BUTTON_RIGHT:
			return
		button.accept_event()
		var lines: Array[String] = []
		var at: int = chosen.call()
		for i in entries.size():
			lines.append(("• " if i == at else "    ") + entries[i])
		menu_requested.emit({
			"title": title,
			"lines": lines,
			"pick": func(index: int) -> void:
				pick.call(index)
				refresh()
				changed.emit(),
			"amount": amount,
			"set_amount": func(value: int) -> void:
				if set_amount.is_valid():
					set_amount.call(value)
				refresh()
				changed.emit(),
		}))


## The `@ARTIFACT` shape: entries that tick independently, so the menu
## STAYS OPEN and every line shows its own state — `relabel` is how the
## screen re-reads the lines after each tick. [param enabled] /
## [param set_enabled], when given, put the 1997 window's "Enable Filter"
## at the head of the menu, for the three Other Filters whose medallion
## is that switch.
func _with_checks(button: Button, title: String, entries: Array[String],
		states: Callable, flip: Callable,
		enabled := Callable(), set_enabled := Callable()) -> void:
	button.set_meta("has_menu", true)
	var lines_now := func() -> Array[String]:
		var on: Array = states.call()
		var lines: Array[String] = []
		for i in entries.size():
			lines.append(_checked(bool(on[i]), entries[i]))
		return lines
	button.gui_input.connect(func(event: InputEvent) -> void:
		if not (event is InputEventMouseButton) or not event.pressed \
				or event.button_index != MOUSE_BUTTON_RIGHT:
			return
		button.accept_event()
		menu_requested.emit({
			"title": title,
			"lines": lines_now.call(),
			"relabel": lines_now,
			"pick": func(index: int) -> void:
				flip.call(index)
				refresh()
				changed.emit(),
			"enabled": enabled,
			"set_enabled": func(on: bool) -> void:
				if set_enabled.is_valid():
					set_enabled.call(on)
				refresh()
				changed.emit(),
			"amount": Callable(),
			"set_amount": Callable(),
		}))


# ------------------------------------------------------------ the paint --
#
# THE PRESS, AND WHY IT WAS INVISIBLE. The 2026-09-03 playtest: *"Filter
# buttons do not feel responsive — on click an immediate press sprite
# should be displayed!"* It was NOT the `hover_pressed` hole that
# [method OriginalDialog.button], [method OriginalDialog.dress_bar_button]
# and [method UiChrome.menu_button] were fixed for the same day — this
# file already named `hover_pressed`. It was two other things, both
# MEASURED on the pinned 4.7.2 build rather than reasoned about:
#
# 1. ONE BOX ON ALL FIVE STATES. `_apply_texture` bound the same
#    StyleBoxTexture to `normal`, `pressed`, `hover`, `focus` and
#    `hover_pressed` and chose WHICH art by the latched value, so no draw
#    mode could differ from any other. A capture of the Creatures
#    medallion held down was pixel-identical to the same medallion at
#    rest — max channel difference 0 — in BOTH latch states.
# 2. AN OPAQUE `focus` BOX, PAINTED OVER EVERYTHING. Godot draws the focus
#    stylebox ON TOP of the draw-mode box (probed: a toggle with five
#    differently-coloured boxes reads the focus colour whatever its state
#    or its latch), and these toggles are FOCUS_ALL, so the first click on
#    a medallion froze it at its resting art for good.
#
# THE FIX IS GODOT'S OWN TOGGLE ARITHMETIC, not another sprite.
# `BaseButton::get_draw_mode` INVERTS `pressing` when the button is
# latched, so a held toggle draws the box of the state it is ABOUT TO
# BECOME. Probed on 4.7.2, with the pointer on the button:
#
#     latched OFF, held  ->  `pressed`        latched OFF, hover -> `hover`
#     latched ON,  held  ->  `normal`         latched ON,  hover -> `hover_pressed`
#
# So bind the OFF medallion to `normal` and the ON medallion to `pressed`
# and one pair carries BOTH jobs: the latch at rest, and an immediate
# press sprite under the finger — the medallion goes down on mouse-DOWN
# and commits on mouse-UP, with no repaint anywhere. `hover` and
# `hover_pressed` are those same two latch states under the pointer and
# must therefore stay apart as well, or releasing a click lands back on
# the exact look it started from and the click reads as lost.

## The era's own hover lift, measured off the sheets rather than invented:
## `sprite_sheet_hover` runs 151-160 mean luminance where `sprite_sheet`
## runs 120-127 (PIL, cells (1,1) (2,0) (0,4)), i.e. x1.26. The original
## cut ONE hover sheet and it is the lit RAISED medallion, so the SUNKEN
## one borrows the same measured ratio for its own pointer cue.
const HOVER_LIFT := 1.26
## The lettered toggles' OFF tint — the dimming this bar has always used
## for Unlimited and the promos, moved off the node's `modulate` (which is
## one value for all five states, so a press cannot move it) and onto the
## OFF stylebox, where the draw mode can.
const LETTER_OFF := Color(0.55, 0.60, 0.72)
## No skin at all: the two flat faces the bar has always fallen back to.
const FLAT_ON := Color(0.62, 0.63, 0.66)
const FLAT_OFF := Color(0.19, 0.21, 0.26)


func _dress_icon(button: Button, cell: Array) -> void:
	button.set_meta("icon_cell", cell)
	button.custom_minimum_size = ICON_SIZE
	_paint_icon(button)


## ON wears the plain medallion, OFF the dark sunken one — the polarity
## the owner's 1997 screenshot fixes (see the class doc). No tint: the
## sheets themselves are 2:1 in luminance, which is what makes the state
## read at 34px without inventing a colour the original never used.
##
## Bound ONCE, across the four draw states that a toggle actually visits,
## so `set_pressed_no_signal` alone says which one shows and a held button
## previews its flip. See the head of this section for the arithmetic.
func _paint_icon(button: Button) -> void:
	var cell: Array = button.get_meta("icon_cell")
	var on_art := sheet_cell("filter_icons", cell[0], cell[1])
	var off_art := sheet_cell("filter_icons_pressed", cell[0], cell[1])
	if on_art == null or off_art == null:
		_paint_fallback(button, String(button.get_meta("cue")).substr(0, 2))
		return
	button.text = ""
	button.add_theme_stylebox_override("normal", _box_for(off_art))
	button.add_theme_stylebox_override("pressed", _box_for(on_art))
	# The ORIGINAL's own hover cut IS the lit raised medallion, so it goes
	# on `hover_pressed` as it was drawn; the sunken one has no cut of its
	# own and takes the same lift by arithmetic. Both latch states are then
	# exactly [constant HOVER_LIFT] brighter under the pointer than at
	# rest, and neither hover can be mistaken for the other's rest.
	var hover_art := sheet_cell("filter_icons_hover", cell[0], cell[1])
	button.add_theme_stylebox_override("hover_pressed",
		_box_for(hover_art) if hover_art != null \
			else _box_for(on_art, HOVER_LIFT))
	button.add_theme_stylebox_override("hover", _box_for(off_art, HOVER_LIFT))
	_focus_ring(button)


## A lettered toggle for Unlimited and the promos — the two sets the
## ORIGINAL drew no symbol for either, on the cards or in DBArt, so they
## letter themselves exactly as the enlarged card letters them
## (GameSkin.set_label). Same stone, same on/off split as the medallions —
## across the same four draw states, so these go down under the finger
## too — so the row still reads as one strip.
func _dress_text(button: Button, letters: String) -> void:
	button.set_meta("lettered", true)
	button.custom_minimum_size = ICON_SIZE
	button.text = letters
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _stone(LETTER_OFF))
	# Multiplying a Color by a float takes the ALPHA with it, and a
	# modulate alpha above 1 is not a brighter stone, it is undefined.
	button.add_theme_stylebox_override("hover",
		_stone(Color(LETTER_OFF.r * HOVER_LIFT, LETTER_OFF.g * HOVER_LIFT,
			LETTER_OFF.b * HOVER_LIFT)))
	button.add_theme_stylebox_override("pressed", _stone(Color.WHITE))
	button.add_theme_stylebox_override("hover_pressed",
		_stone(Color(HOVER_LIFT, HOVER_LIFT, HOVER_LIFT)))
	_focus_ring(button)
	for state in ["font_color", "font_hover_color"]:
		button.add_theme_color_override(state,
			OriginalDialog.HIGHLIGHT * LETTER_OFF)
	for state in ["font_pressed_color", "font_hover_pressed_color",
			"font_focus_color"]:
		button.add_theme_color_override(state, OriginalDialog.HIGHLIGHT)
	button.add_theme_color_override("font_shadow_color", OriginalDialog.INK)
	button.add_theme_constant_override("shadow_offset_x", 1)
	button.add_theme_constant_override("shadow_offset_y", 1)


## `panel_dark_stone` under [param tint], cached per tint. Texture and
## flat grounds both take the tint, so the skinless stone splits its
## states exactly as the skinned one does.
static var _stone_cache: Dictionary = {}

static func _stone(tint: Color) -> StyleBox:
	var id := str(tint)
	if _stone_cache.has(id):
		return _stone_cache[id]
	var box := OriginalDialog.panel_style("panel_dark_stone", 2.0)
	if box is StyleBoxTexture:
		box.modulate_color = tint
	elif box is StyleBoxFlat:
		box.bg_color = box.bg_color * tint
	_stone_cache[id] = box
	return box


## THE FOCUS BOX IS A RING, NOT A FACE. Godot paints `focus` ON TOP of
## whatever the draw mode chose, so an opaque one hides the button whole —
## and since every toggle here is FOCUS_ALL and a click focuses it, the
## opaque medallion this used to carry froze the first medallion clicked
## at its resting art. A hollow rectangle in the era's own highlight keeps
## the keyboard cue and covers nothing.
static var _ring: StyleBoxFlat = null

static func _focus_ring(button: Button) -> void:
	if _ring == null:
		_ring = StyleBoxFlat.new()
		_ring.draw_center = false
		_ring.border_color = OriginalDialog.HIGHLIGHT
		_ring.set_border_width_all(1)
	button.add_theme_stylebox_override("focus", _ring)


## One StyleBoxTexture per texture AND tint, shared by every button that
## wears it — the medallions are dressed once now, but the strip has
## twenty-three of them and most share a sheet cell with nothing.
static var _box_cache: Dictionary = {}

static func _box_for(art: Texture2D, lift := 1.0) -> StyleBoxTexture:
	var id := "%d:%.2f" % [art.get_instance_id(), lift]
	if _box_cache.has(id):
		return _box_cache[id]
	var box := StyleBoxTexture.new()
	box.texture = art
	if lift != 1.0:
		box.modulate_color = Color(lift, lift, lift)
	_box_cache[id] = box
	return box


## No skin: the era's own bevel geometry in flat colour, lettered — and
## split across the same four draw states, so the strip still goes down
## under the finger on a machine with no original art at all.
func _paint_fallback(button: Button, letters: String) -> void:
	button.text = letters
	button.add_theme_font_size_override("font_size", 12)
	button.add_theme_stylebox_override("normal", _flat_face(FLAT_OFF))
	button.add_theme_stylebox_override("hover",
		_flat_face(FLAT_OFF.lightened(0.20)))
	button.add_theme_stylebox_override("pressed", _flat_face(FLAT_ON))
	button.add_theme_stylebox_override("hover_pressed",
		_flat_face(FLAT_ON.lightened(0.14)))
	_focus_ring(button)
	for state in ["font_color", "font_hover_color"]:
		button.add_theme_color_override(state, OriginalDialog.HIGHLIGHT)
	for state in ["font_pressed_color", "font_hover_pressed_color"]:
		button.add_theme_color_override(state, OriginalDialog.INK)


static var _flat_cache: Dictionary = {}

static func _flat_face(face: Color) -> StyleBoxFlat:
	var id := str(face)
	if _flat_cache.has(id):
		return _flat_cache[id]
	var box := StyleBoxFlat.new()
	box.bg_color = face
	box.border_color = OriginalDialog.INK
	box.set_border_width_all(1)
	_flat_cache[id] = box
	return box


## One 40x40 cell of a filter sheet, cached. Null without the skin.
static func sheet_cell(key: String, row: int, col: int) -> Texture2D:
	var id := "%s:%d:%d" % [key, row, col]
	if _cell_cache.has(id):
		return _cell_cache[id]
	var result: Texture2D = null
	if row < 0:
		result = _funnel_cell(key)
	else:
		var sheet := GameSkin.texture(key)
		if sheet != null:
			var image := sheet.get_image()
			if image.get_width() >= (col + 1) * CELL and image.get_height() >= (row + 1) * CELL:
				result = ImageTexture.create_from_image(
					image.get_region(Rect2i(col * CELL, row * CELL, CELL, CELL)))
	_cell_cache[id] = result
	return result


## [QoL] THE FUNNEL MEDALLION, which the 1997 sheet does not have: the
## `X` medallion's disc with its glyph rubbed out and a funnel cut in its
## place, in the sheet's own two inks — the darkest and the brightest
## pixel of the disc, which are the X's groove and the light on its lower
## edge — so it sits in the row as one of them. Built from whichever
## sheet [param key] names, so the sunken and lit versions come out of
## the sunken and lit sheets and keep their 2:1 split.
static func _funnel_cell(key: String) -> Texture2D:
	var base := sheet_cell(key, COST_CELL[0], COST_CELL[1])
	if base == null:
		return null
	var img: Image = base.get_image().duplicate()
	img.convert(Image.FORMAT_RGBA8)
	var ink := Color.WHITE
	var gleam := Color.BLACK
	var face: Array[Color] = []
	for y in CELL:
		for x in CELL:
			var r := Vector2(x, y).distance_to(FUNNEL_CENTRE)
			if r > FUNNEL_RADIUS:
				continue
			var c := img.get_pixel(x, y)
			if c.get_luminance() < ink.get_luminance():
				ink = c
			if c.get_luminance() > gleam.get_luminance():
				gleam = c
			# The face is the ring the X's arms stop short of.
			if r > FUNNEL_RADIUS - 2.5:
				face.append(c)
	face.sort_custom(func(a: Color, b: Color) -> bool:
		return a.get_luminance() < b.get_luminance())
	# Drop the ring's own rim shading at both ends and speckle the disc
	# with the middle of it, so the stone reads as the same stone.
	var rng := RandomNumberGenerator.new()
	rng.seed = 1997
	var lo := face.size() / 5
	var hi := face.size() - lo
	for y in CELL:
		for x in CELL:
			if Vector2(x, y).distance_to(FUNNEL_CENTRE) <= FUNNEL_RADIUS - 1.0:
				img.set_pixel(x, y, face[rng.randi_range(lo, hi - 1)])
	# The funnel: a bowl eight rows deep narrowing from seventeen wide to
	# three, then a stem of the same three down to the disc's lower rim.
	var cut := {}
	for y in range(11, 19):
		var half := 8.0 - (y - 11) * 6.0 / 7.0
		for x in range(int(FUNNEL_CENTRE.x - half), int(FUNNEL_CENTRE.x + half) + 1):
			cut[Vector2i(x, y)] = true
	for y in range(19, 28):
		for x in range(int(FUNNEL_CENTRE.x) - 1, int(FUNNEL_CENTRE.x) + 2):
			cut[Vector2i(x, y)] = true
	# The X's groove catches the light on its lower-right edge; so does
	# this one.
	for at in cut:
		var below: Vector2i = at + Vector2i(1, 1)
		if not cut.has(below):
			img.set_pixel(below.x, below.y, gleam)
	for at in cut:
		img.set_pixel(at.x, at.y, ink)
	return ImageTexture.create_from_image(img)
