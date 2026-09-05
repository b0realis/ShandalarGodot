class_name CardMenu
extends RefCounted
## THE MINI-MENUS a right-click opens on everything that is NOT a
## territory — `docs/duel-todo.md` §6.12. The Territory menu has its own
## file ([TerritoryMenu], §6.3); the life register's `@MENU_LIFE` /
## `@MENU_FACE` pair is built into the Duelist's Face (§6.5). What is
## here is the rest of the family.
##
## `Duel.hlp`, topic **Territory**, states the rule these all obey:
## *"Depending on the situation, one or more of these options is
## available."* The original GREYS what it cannot offer; it does not
## shorten its menu. Every table below is therefore complete and verbatim,
## with `live` saying what this pass actually wires.
##
## THE ITEM'S TABLE WAS FOUR MENUS SHORT. §6.12 lists `@MENU_SMALLCARD`,
## `@MENU_GRAVEYARD`, `@MENU_LIBRARY`, `@MENU_MANAPOOL`, `@MENU_FULLCARD`
## and `@MENU_HAND`. `Program/UIStrings.txt:841-947` has fourteen `@MENU_`
## tables, and the four it does not mention are the WINDOW menus —
## `@MENU_ATTACK` and `@MENU_MINIMIZEDATTACK` (`Minimize` / `Restore`,
## each with `Help...`), and `@MENU_SPELLCHAIN` /
## `@MENU_MINIMIZEDSPELLCHAIN`, the same pair for the chain. They are
## [constant ATTACK] and [constant SPELL_CHAIN] here.
##
## Accelerators (`\tCtrl+T`) are carried in the entries rather than in the
## labels: §6.1 dropped `@MENU_PHASEBAR`'s because the gestures were not
## ours, and the three display toggles' gestures still are not — but the
## strings are worth keeping where the work will find them.

## `@MENU_SMALLCARD` (`UIStrings.txt:936`), eight entries in the table's
## own order. What each one is, from `Duel.hlp`'s **Territory** topic
## (which describes the card mini-menu at its end):
##  - **Original Type** — *"shows you what this card was when it was cast,
##    before any spells and effects changed it."* Live: the Showcase
##    already draws the PRINTED card — *"the Showcase always displays the
##    original card, except for the text"* — so this is that view, asked
##    for by name.
##  - **Show full card** — *"displays the card in the Showcase… You can
##    also double-right-click to perform the same function."* Live; the
##    gesture landed with §2.15.
##  - **View in full card** — the Advanced Layout's *"temporary Showcase"*
##    of the same sentence. We have no Advanced Layout (§6.4 lists it and
##    greys it), so this is greyed with it.
##  - **Don't auto tap this card** — *"marks a land to be ignored — not
##    tapped for mana — when you auto-cast any spell or effect. The only
##    way to tap a locked land is manually, by clicking on it."* LIVE
##    since 2026-09-03, when the auto-cast it is the per-card half of
##    landed (`DuelScreen._auto_cast`, `DuelScreen._no_auto_tap`). It is
##    what proved the original had an auto-tap at all, and the
##    decompilation then named the flag: `AUTOTAP_NO_DONT_AUTO_TAP`.
##    Shown as a TICK, because it is a mark that stays on until the
##    player takes it off and the 1997 table ships no "do auto tap"
##    string — the same one-entry-both-ways shape as the Stops'
##    `Mark this phase to always stop`.
##  - the three display toggles — [constant DuelOptions.MENU_TOGGLES].
##  - **Help...** — the Dueling Help window (§6.20l).
const SMALL_CARD: Array[Dictionary] = [
	{"label": "Original type", "live": true},
	{"label": "Show full card", "accel": "R DblClk", "live": true},
	{"label": "View in full card", "live": false},
	{"label": "Don't auto tap this card", "live": true, "check": true},
	{"toggle": "ShowIDTagsOnCards"},
	{"toggle": "ShowInvisibleEffectCards"},
	{"toggle": "ShowAllCardsSummonSickness"},
	{"label": "Help...", "live": false},
]

## `@MENU_LIBRARY` (`:878`). `Duel.hlp`, **Libraries**: *"The number of
## cards left in your library is represented inexactly, as in real life.
## If you must know, you can right-click on a library to find out the
## exact number of cards left in it."* — which is what the one live entry
## does, in the Situation Bar.
const LIBRARY: Array[Dictionary] = [
	{"label": "Count library cards", "live": true},
	{"label": "Help...", "live": false},
]

## `@MENU_HAND` (`:874`) — one entry, and it is the help. The whole menu
## is greyed, which is exactly what the original's own table amounts to
## for us; it is here so the gesture answers rather than doing nothing.
const HAND: Array[Dictionary] = [
	{"label": "Help...", "live": false},
]

## `@MENU_MANAPOOL` (`:890`), eight entries. `Duel.hlp`, **Mana Pool**:
## *"If there is mana in your pool that you wish to use, click on the area
## next to the appropriate color button (or on the button itself) to apply
## that mana one at a time. To use all of a particular color,
## double-click in the area representing that color."*
##
## ALL SEVEN SPENDS ARE GREYED, and this is the honest reason: in the
## original the player pays a cost mana by mana, and `Spend 1 mana: %s` is
## how one goes in. Our engine settles a cost in one call inside
## [method MtgGame.cast_spell] — there is no half-paid spell for a mana to
## be spent INTO — so the entry has nothing to mean yet. Building it is an
## engine change (a held-open payment, the same shape §1.3 gave the
## mid-resolution questions), not a menu.
##
## Note the seventh column: `artifact`. The original tracked restricted
## artifact mana as a pool of its own, which is exactly our
## [ManaPool] restricted pool — so the row is already modelled even though
## the command is not.
const MANA_POOL: Array[Dictionary] = [
	{"label": "Spend 1 mana: black", "live": false},
	{"label": "Spend 1 mana: blue", "live": false},
	{"label": "Spend 1 mana: green", "live": false},
	{"label": "Spend 1 mana: red", "live": false},
	{"label": "Spend 1 mana: white", "live": false},
	{"label": "Spend 1 mana: colorless", "live": false},
	{"label": "Spend 1 mana: artifact", "live": false},
	{"label": "Help...", "live": false},
]

## `@MENU_FULLCARD` (`:868`) — the SHOWCASE's own menu. `Duel.hlp`,
## **Showcase**: *"If the whole text of a card does not fit into the text
## area of the Showcase, you can fix that. Right-click on the text area,
## then click on the Expand toggle. This causes the text area to grow, when
## necessary, to display the entire card text. If the expanded box becomes
## annoying, you can always toggle Expand off again."* The setting is
## persisted under the 1997 executable's own key,
## `ExpandTextBoxOnBigCard`.
const FULL_CARD: Array[Dictionary] = [
	{"label": "Expand text box", "key": "ExpandTextBoxOnBigCard", "live": true},
	{"label": "Help for this card...", "live": false},
	{"label": "Help...", "live": false},
]

## `@MENU_ATTACK` (`:841`) and `@MENU_MINIMIZEDATTACK` (`:846`) — the
## Attack window's menu and the menu of the ICON it shrinks to. Manual
## p.122 describes the same pair for the chain: *"you can minimize the
## Spell Chain window by clicking in its upper right corner. To restore
## the minimized window, click on the window icon in the center area of
## the Phase Bar."* Both actions exist on our Combat window already
## (`DuelScreen._on_combat_minimized`, `_on_window_icon_pressed`).
const ATTACK: Array[Dictionary] = [
	{"label": "Minimize", "live": true},
	{"label": "Help...", "live": false},
]
const MINIMIZED_ATTACK: Array[Dictionary] = [
	{"label": "Restore", "live": true},
	{"label": "Help...", "live": false},
]

## `@MENU_SPELLCHAIN` (`:851`) and `@MENU_MINIMIZEDSPELLCHAIN` (`:856`) —
## the same two words for the chain window. NOT live: our chain has no
## minimised state to restore from, and the 1997 restore route is the
## Phase Bar's window icon, which our icon already spends on the Combat
## window. Listed so the four-menu gap §6.12's table has is on the record.
const SPELL_CHAIN: Array[Dictionary] = [
	{"label": "Minimize", "live": false},
	{"label": "Help...", "live": false},
]
const MINIMIZED_SPELL_CHAIN: Array[Dictionary] = [
	{"label": "Restore", "live": false},
	{"label": "Help...", "live": false},
]


## Fill [param menu] from one of the tables above, ids counting from
## [param base]. A row with a `toggle` key becomes a CHECK item reading
## [DuelOptions]; every other row is a plain item, greyed unless `live`.
static func build(menu: PopupMenu, table: Array[Dictionary],
		base := 0) -> void:
	menu.clear()
	for i in table.size():
		var row: Dictionary = table[i]
		var id: int = base + i
		if row.has("toggle"):
			var key := String(row["toggle"])
			var label := ""
			for spec in DuelOptions.MENU_TOGGLES:
				if spec["key"] == key:
					label = String(spec["label"])
			menu.add_check_item(label, id)
			var at := menu.get_item_index(id)
			menu.set_item_checked(at, DuelOptions.toggle(key))
			menu.set_item_disabled(at, not DuelOptions.menu_toggle_live(key))
			# `Ctrl+T` etc., drawn right-aligned the way the 1997 table
			# wrote them after a tab — for the live toggles only (§6.3a).
			menu.set_item_accelerator(at, DuelOptions.menu_toggle_accelerator(key))
			continue
		if bool(row.get("check", false)):
			# A LASTING MARK the player sets and clears from the same
			# entry (`Don't auto tap this card`). The caller ticks it —
			# only it knows which card the menu was opened on.
			menu.add_check_item(String(row["label"]), id)
		else:
			menu.add_item(String(row["label"]), id)
		if not bool(row.get("live", false)):
			menu.set_item_disabled(menu.get_item_index(id), true)
