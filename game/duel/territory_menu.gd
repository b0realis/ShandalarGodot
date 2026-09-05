class_name TerritoryMenu
extends RefCounted
## THE TERRITORY MENU — `@MENU_TERRITORY`
## (`shandalar-src/Program/UIStrings.txt:908`), the 25-entry mini-menu a
## right-click on either territory opens, and the 1997 duel's master
## control.
##
## `Duel.hlp`, topic **Territory**: *"The largest areas of the dueling
## table are your territory and your opponent's territory… When you
## right-click on either territory, a mini-menu pops open. **Depending on
## the situation, one or more of these options is available.**"* That last
## sentence is why this class carries the whole table and marks which
## entries are live: the original greys what it cannot offer, it does not
## shorten its menu.
##
## `Duel Options...` (entry 17) became live on 2026-09-01 — see
## [DuelOptions], which carries `@DIALOG_DUELOPTIONS`'s own nineteen
## strings and the settings behind them (§6.4).
##
## THE `Go to:` LIST landed first (2026-08-31) — the fourteen
## destinations, which are the half of the original's fast-forward that
## **Run to** (§6.1) did not cover. Run to reaches any of them by clicking
## a Phase Bar icon; this reaches the same stops by NAME, *"for players
## who would rather read than aim"*. The two `Arrange` entries came with
## §2.3 and `Duel Options...` with §6.4.
##
## THE REST OF THE TABLE went live on 2026-09-01: **Concede** and its
## confirmation, **Minimize**, and two of the three display toggles.
## `Show invisible effects` and `Help...` stay greyed — we have no
## invisible effect cards and no help window — on §6.1's own precedent for
## `@MENU_PHASEBAR`'s two Help entries.
##
## ONE ENTRY IS DELIBERATELY ABSENT. `Save game...\tCtrl+S` is in the table
## but the manual is explicit (p.112) that it *"appears **only** if you are
## playing in the **Duel** (a separate program described later)"* — the
## string exists because one binary served both products. There is no
## mid-duel save in Shandalar and we must not invent one.
##
## The table writes its accelerators into the strings themselves
## (`Arrange your cards\tDblClk`, `Show ID tags\tCtrl+T`). They are dropped
## from the labels here, the way `@MENU_PHASEBAR`'s were in §6.1: a menu
## that advertises a shortcut it does not honour is worse than one that
## stays quiet. The three `Ctrl+` keys ARE honoured since 2026-09-02
## (§6.3a) and are drawn back on as real accelerators by the screen
## ([method DuelOptions.menu_toggle_accelerator]); `DblClk` is still not.

## Which strip a destination sits on, and where. `half` is filled in by the
## caller: every `Go to:` runs inside the turn in progress, exactly as
## clicking the same icon on the Phase Bar does, except
## [constant NEXT_TURN] which crosses into the other half.
enum Where { HERE, NEXT_TURN, NEXT_PHASE }

## The fourteen `Go to:` entries, verbatim and in the table's own order
## (`UIStrings.txt:910-923`), each resolved to the [PhaseStops.Bar] icon
## our two strips light in that phase.
##
## THREE MAPPINGS ARE WORTH THE INK:
##
##  * `Main phase (combat)` is the original's name for the moment the
##    attack is announced (`Duel.hlp`, **Combat**), so it lands on the
##    Combat Bar's first icon rather than the Phase Bar's combat crescent
##    — which no step of ours ever lights on its own, because
##    [method CombatBar.covers_step] hands every combat step to the
##    smaller bar.
##  * `Discard phase` and `Cleanup phase` are slots 6 and 7 of the Phase
##    Bar in the ORIGINAL's order; ours light them from CLEANUP and END
##    respectively (see `DuelScreen._phase_icon_slot` and
##    `docs/glossary-1997.md` §3, where the two rulesets' end-of-turn
##    disagree). The icons are the contract, not the step names.
##  * `Resolve first strike damage` only exists when something in combat
##    has first strike (CR 510.5); asking for it in a duel without any is
##    a run that never arrives and comes to rest on the first thing that
##    stops it, which is what the original's own destination-forgetting
##    rule describes (*"your original 'destination' phase is forgotten"*).
const GO_TO: Array[Dictionary] = [
	{"label": "Go to: Upkeep phase",
		"bar": PhaseStops.Bar.PHASE, "slot": 1, "where": Where.HERE},
	{"label": "Go to: Draw phase",
		"bar": PhaseStops.Bar.PHASE, "slot": 2, "where": Where.HERE},
	{"label": "Go to: Main phase (precombat)",
		"bar": PhaseStops.Bar.PHASE, "slot": 3, "where": Where.HERE},
	{"label": "Go to: Main phase (combat)",
		"bar": PhaseStops.Bar.COMBAT, "slot": 0, "where": Where.HERE},
	{"label": "Go to: Attack Fast Effects phase",
		"bar": PhaseStops.Bar.COMBAT, "slot": 1, "where": Where.HERE},
	{"label": "Go to: Choose Defenders phase",
		"bar": PhaseStops.Bar.COMBAT, "slot": 2, "where": Where.HERE},
	{"label": "Go to: Block Fast Effects phase",
		"bar": PhaseStops.Bar.COMBAT, "slot": 3, "where": Where.HERE},
	{"label": "Go to: Resolve first strike damage",
		"bar": PhaseStops.Bar.COMBAT, "slot": 4, "where": Where.HERE},
	{"label": "Go to: Resolve combat",
		"bar": PhaseStops.Bar.COMBAT, "slot": 5, "where": Where.HERE},
	{"label": "Go to: Main phase (postcombat)",
		"bar": PhaseStops.Bar.PHASE, "slot": 5, "where": Where.HERE},
	{"label": "Go to: Discard phase",
		"bar": PhaseStops.Bar.PHASE, "slot": 6, "where": Where.HERE},
	{"label": "Go to: Cleanup phase",
		"bar": PhaseStops.Bar.PHASE, "slot": 7, "where": Where.HERE},
	{"label": "Go to: Start of next turn",
		"bar": PhaseStops.Bar.PHASE, "slot": 0, "where": Where.NEXT_TURN},
	# The one verb we had no equivalent for. `Duel.hlp`, **Territory**:
	# *"**Go to** ends the current phase and moves you on to the next
	# one."* Our Done passes priority exactly once, which is finer-grained
	# than either 1997 verb; this is the coarser one.
	{"label": "Go to: next phase",
		"bar": PhaseStops.Bar.PHASE, "slot": 0, "where": Where.NEXT_PHASE},
]

## The rest of the table, verbatim (`UIStrings.txt:924-934`), minus
## `Save game...` — see the class note. `live` says whether this pass
## wires it; the rest are shown DISABLED so the menu reads as complete and
## the feature reads as missing, which is the call §6.1 already made for
## `@MENU_PHASEBAR`'s two Help entries.
##
## The three DISPLAY TOGGLES (entries 18-20) carry a `toggle` key instead
## of a label: they are check items reading [DuelOptions], and the same
## three appear again on `@MENU_SMALLCARD` ([CardMenu]), which is why the
## table of them lives with the settings rather than here.
const REST: Array[Dictionary] = [
	{"label": "Arrange your cards", "live": true, "todo": ""},
	{"label": "Arrange opponent's cards", "live": true, "todo": ""},
	{"label": "Duel Options...", "live": true, "todo": ""},
	{"toggle": "ShowIDTagsOnCards"},
	{"toggle": "ShowInvisibleEffectCards"},
	{"toggle": "ShowAllCardsSummonSickness"},
	{"label": "Minimize", "live": true, "todo": ""},
	{"label": "Help...", "live": false, "todo": "§6.20l"},
	{"label": "Concede", "live": true, "todo": ""},
]

## The confirmation `Concede` opens onto — entry 25 of the table, and not
## a sibling of `Concede` but the second half of it. `Duel.hlp`,
## **Territory**: *"**Concede** announces to your opponent that you're
## giving up, accepting a loss rather than continue this duel. **You must
## confirm this decision.**"*
const CONCEDE_CONFIRM := "Yes, I'm sure"

## The window that asks it. One line — the menu entry, restated as the
## question the original's own confirmation asks — and the table's own two
## words as the button that answers yes. `Cancel` is `@DIALOGBUTTONS`
## entry 2 (`UIStrings.txt:172`), the whole 1997 vocabulary for "no".
static func concede_window() -> OriginalDialog:
	var dialog := OriginalDialog.create("Concede", Vector2(360, 168),
		"panel_dark_stone")
	var ask := OriginalDialog.label(
		"Give up this duel and accept a loss?", 15)
	ask.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.body().add_child(ask)
	return dialog


## Which entries of [constant REST] this pass wires. A row with a `toggle`
## asks [DuelOptions] whether that switch is honoured yet.
static func rest_is_live(row: Dictionary) -> bool:
	if row.has("toggle"):
		return DuelOptions.menu_toggle_live(String(row["toggle"]))
	return bool(row.get("live", false))


## The label a [constant REST] row shows.
static func rest_label(row: Dictionary) -> String:
	if row.has("toggle"):
		for spec in DuelOptions.MENU_TOGGLES:
			if spec["key"] == row["toggle"]:
				return String(spec["label"])
	return String(row.get("label", ""))


## Which half of the Phase Bar a `Go to:` entry runs in, given the half the
## duel is standing in now.
static func half_for(entry: Dictionary, here: int) -> int:
	if int(entry["where"]) == Where.NEXT_TURN:
		return PhaseStops.Half.YOURS if here == PhaseStops.Half.OPPONENTS \
			else PhaseStops.Half.OPPONENTS
	return here
