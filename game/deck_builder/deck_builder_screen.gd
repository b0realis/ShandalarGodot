class_name DeckBuilderScreen
extends Control
## THE DECK BUILDER — `@SHELLSCREEN_TOOLS` (`Program/UIStrings.txt:13`):
## *"&Deck Builder:Build or Modify decks."*
##
## The 1997 Deck Builder was a separate module (`Program/Deckdll.dll`), so
## unlike the duel there is no C source to read. What survives is the
## ART (imported by tools/import_original.py), the STRING TABLES and the
## MANUAL's chapter 10, "Building Your Decks" — and between them they
## specify the screen completely. s30's `game/screens/edit_deck.go` is the
## structural reference: its collection/deck split, its count badges, its
## filter toggles and its deck statistics are all ported here.
##
## WHERE THE STRINGS COME FROM, corrected by the audit pass (2026-08-31):
## every deck-builder tag this screen quotes lives in **Menus.txt**, not
## in `UIStrings.txt`, and the genuine 1997 copy is
## `s30/assets/text/Menus.txt` — `shandalar-src/Program/Menus.txt` is
## Manalink-updated (it renames Gold to Multicolored, rewrites `@ABILITY`
## into modern keywords and deletes `@ARTISTNAMES`). The two exceptions
## are `@SHELLSCREEN_TOOLS` and `@GAUNTLETERRORS`, which really are in
## `UIStrings.txt`. `Program/Text.res` is Manalink-modified too and is not
## a 1997 witness for any of this.
##
## THE REGIONS, in the manual's own words and its figure's callouts:
##
##   Deck Header  "At the top left corner of the screen is the Deck Header
##                box… the title of your deck is displayed."
##   Showcase     "Off to the left — the giant card — is the Showcase.
##                Whatever card the mouse cursor is hovering over is
##                displayed here."
##   Deck         "The largest area of the screen contains the deck you're
##                working on. Cards are represented in miniature."
##   Filters      "Between the Inventory and Deck areas are four sets of
##                Filter buttons."
##   Inventory    "Along the bottom of the screen, in the Inventory area,
##                is every card you can put into a deck — every Magic: The
##                Gathering card included in the game!"
##
## Every component here is one the project already had: [MiniCard] draws
## every small card, [CardPreview] is the Showcase, [OriginalDialog]
## supplies the 1997 buttons, labels and modal chrome, and [CardArea] is
## the shared surface the Deck and the Inventory both are.
##
## WHAT WE DELIBERATELY DID NOT PORT FROM s30: its card COLLECTION and its
## gold economy (`Drop to Sell`, `SalePrice`) — those belong to the
## adventure layer, which does not exist yet, and the standalone Deck
## Builder never had them either: *"there are few restrictions on the
## contents of your dueling deck. Any deck you can dream up, you can build
## and play."* Our Inventory is the whole implemented pool.
##
## THE INVENTORY THEREFORE DOES NOT DEPEND ON THE DECK, and the audit pass
## made the screen act like it: [method refresh] redraws the deck, and
## [method _refresh_inventory] walks the 800-card pool only when
## [member DeckFilter.revision] has moved. Putting a card in the deck used
## to re-filter and re-sort the whole pool and rebuild the page — 30 ms a
## click.
##
## ------------------------------------------------------------------------
## THE SCREENSHOT PASS (2026-08-31) restyled every region of this screen to
## the owner's own 1997 screenshot of the in-Shandalar Deck screen. What
## the screenshot changed, region by region:
##
##   ground        the whole screen is `deck_tile_slate` (Dektile4's navy
##                 weave), not the olive Dektile1 s30 tiles. The olive tile
##                 stays imported: it is the ground the WARM row of
##                 `deck_slot_plaques` belongs on, and the two pair up.
##   Deck area     a QUILT — every slot carries a carved 1997 mana
##                 watermark (CardArea.slot_plaques)
##   command bar   moved from the top of the screen to the BOTTOM of the
##                 deck area, where the screenshot puts it, and cut to the
##                 five buttons that fit there
##   Filters       ONE row of medallions, not four labelled columns
##   Inventory     ONE row of cards at 1:1, not two rows of miniatures
##
## WHAT THE SCREENSHOT COULD NOT SETTLE, and how it was resolved: the 1997
## bar is `Stats (60 cards) | Deck1 | Deck2 | * Deck3 * | Done` and this
## screen has thirteen commands. Rather than drop nine of them or bolt a
## modern toolbar on, the bar keeps its five 1997 buttons and the rest go
## behind `Deck` — the era's own right-click mini-menu, which the deck
## surface has always offered and which `@FILTERS` proves the original
## itself could show or hide ("Main menu buttons On/Off").
##
## ------------------------------------------------------------------------
## THE SECOND AUDIT PASS (2026-08-31) drove the restyled screen end to end.
## What it found, all of it pinned by a test that failed first
## (tests/ui/test_deck_builder.gd, "SECOND AUDIT PASS"):
##
##   `@SAVE`'s YES DID NOT SAVE, and could write the wrong deck to disk.
##     `Save deck` is not one step — it can stop to ask `@DECKEXISTS` or
##     to send the player to `Deck Info` for a name — and
##     [method _confirm_discard] called it, got nothing back and threw the
##     deck away immediately. It now takes a continuation and runs it only
##     once the file is written ([method _save_deck]).
##   DIALOGS STACKED AND WERE NOT MODAL. Five openers had no one-at-a-time
##     guard, and [OriginalDialog] draws no blocker of its own, so a click
##     that missed the panel landed on the cards underneath. Every dialog
##     now goes up through [method _show_dialog].
##   `Exit deck builder` THREW AWAY THE OTHER SLOTS. Three decks are held
##     and every prompt looked only at the one on the surface
##     ([method _confirm_discard_all]).
##   A REFUSED CHANGE ATE THE UNDO STEP ([method _remember]).
##
## and it recovered TWO 1997 COMMANDS from the deck-builder tags BESIDE
## `@DECKSURFACE_STANDALONE` — `Extra Cards` (`@EXTRACARDSDIALOG`) and
## `Move by color out of deck` (`@DECKSURFACE_ADVENTURE` + `@GROUPMOVE`).
## See [constant MENU_COMMANDS].
##
## [QoL] MARKS EVERY DIVERGENCE FROM 1997 in this file, per the project's
## standing convention. The list, with the reasoning at each site: the deck
## SLOTS' in-memory switching and `Copy deck to`, UNDO, ADD BASIC LANDS,
## the extended STATS graphs, the two EXPORT formats, deck NOTES, the
## Inventory's already-in-deck badge, `Filters` (`@LONGLIST`'s Select All /
## Clear All on a strip the original gave no such button), the CLICKABLE
## legality line, the keyboard shortcuts, and — since the proxy pass
## (2026-09-01) — `Import deck` and `Add proxy card`.
##
## ------------------------------------------------------------------------
## THE PROXY PASS (2026-09-01). A deck can now name a card this game does
## not implement and still be read, built, saved and LOOKED AT: the name
## becomes a [ProxyCard], drawn as a card-sized piece of plain paper
## ([ProxyFace]) with the word `proxy` where its rules text goes. Two new
## mini-menu entries reach it — `Import deck` (a file, or a pasted
## decklist) and `Add proxy card` (the deliberate stand-in) — and they end
## in the same [method DeckModel.add_proxy] as each other.
##
## SUCH A DECK CANNOT BE DUELLED WITH, and this screen says so before
## anything else it might say: [method _refresh_legality] leads with
## [method DeckModel.proxy_problem], naming every card that has to be
## replaced. The refusal that MATTERS is not here, though — it is at the
## duel's own doors (`game/setup_screen.gd`, `DeckLab/simulate.gd`), and
## [ProxyCard]'s class doc lists all of them.

## `@DECKSURFACE_STANDALONE` (`s30/assets/text/Menus.txt:169`) — the deck
## surface's mini-menu, verbatim minus its Windows accelerator markers and
## minus the one entry that is application chrome rather than a setting
## (`Minimize`). `Clear deck` swaps to `Restore deck` once something has
## been cleared, exactly as `@DECKCLEAR_RESTORE` provides for.
##
## **`Music` AND `Sound Effects` ARE BACK** (2026-09-02). They were dropped
## here as "application chrome" along with `Minimize`, which was wrong:
## `Minimize` is a window command, but these two are the 1997 game's ONLY
## audio settings and this menu is the ONLY place it put them — there is no
## options screen anywhere in the original, and the deck builder persists
## them by name (`cfg_write_int(global_cfg_music ? 1 : 0, "Music")`,
## `shandalar-src/src/deck/deckdll.cpp:1296`). They tick like the checked
## menu items they are (`CHECKMENU_IF(popup, RES_MAINMENU_MUSIC,
## global_cfg_music)`, `deckdll.cpp:6085`) and they write the same two
## [Settings] keys the `[QoL]` Options screen shows — one value, one
## storage, two views.
##
## `Stats` is the one entry NOT from that tag: the original reached the
## statistics window from a button under the deck area (*"Clicking on the
## leftmost button gives you a rundown of quite a few useful statistics
## about the deck you're working with"*), and named it `@STATSDIALOG` —
## "Stats". We put it in the same row as the rest.
## [constant EXTRA_COMMANDS] are [QoL] and are marked as such in the
## mini-menu itself, so a player can see at a glance which entries the 1997
## program had and which it did not.
const COMMANDS: Array[String] = [
	"New deck", "Load deck", "Save deck", "Consolidate duplicate cards",
	"Clear deck", "Sort deck", "Stats", "Music", "Sound Effects",
	"Exit deck builder",
]

## The two entries above that are SETTINGS rather than commands: they show
## their state and toggle it, the way `CHECKMENU_IF` marked them in 1997.
const CHECKED_COMMANDS := {
	"Music": "music_enabled",
	"Sound Effects": "sound_enabled",
}
## TWO MORE 1997 COMMANDS, from the deck-builder tags NEXT TO
## `@DECKSURFACE_STANDALONE` rather than inside it — which is why they are
## a list of their own and not an edit to the verbatim one above. The
## second audit pass (2026-08-31) found both by reading the whole
## deck-builder run of `s30/assets/text/Menus.txt` instead of only the one
## tag, and neither is a [QoL] invention:
##
## - `Extra Cards` — `@EXTRACARDSDIALOG` (Menus.txt:36-40) is a DIALOG with
##   an action: *"Extra Cards / There are too many of the following Cards
##   in your deck. / Remove Extra Cards / Edit Deck"*. The screen already
##   said the sentence on its legality line and then left the player to
##   find and cut every stack by hand; the 1997 dialog cuts them.
## - `Move by color out of deck` — `@DECKSURFACE_ADVENTURE` (:194-197) with
##   `@GROUPMOVE`'s own picker (:25-32, *"Select Which Color(s) to Move"*,
##   Black / Blue / Green / Red / White / Artifact). The `into deck` half of
##   that pair belongs to the adventure, where the Inventory is a
##   COLLECTION; ours is the whole 800-card pool, so moving a colour in
##   would try to add two hundred cards. Out transfers exactly, and
##   recolouring a deck is the gesture it exists for.
const MENU_COMMANDS: Array[String] = [
	"Extra Cards", "Move by color out of deck",
]
## [QoL] The commands this screen adds. They share the mini-menu with
## [constant COMMANDS] and are listed after it.
##
## `Filters` opens `@LONGLIST`'s own `Select All` / `Clear All`
## ([constant FilterBar.ALL_MENU]) — 1997 WORDS for a control the 1997
## filter strip did not have, which is a divergence and marked like one.
## It is on the strip too, on a right-click over any medallion that has no
## sub-menu of its own; it is here as well because a command a player
## cannot find is a command they do not have.
## `Import deck` and `Add proxy card` are the proxy pass's two entries
## (2026-09-01) and both are `[QoL]` on the same evidence: `grep -a` over
## `Program/UIStrings.txt`, `Program/Text.res`, `Program/prompts*.txt` and
## the genuine 1997 `s30/assets/text/Menus.txt` finds neither "import" nor
## "paste" nor "proxy" anywhere. The original moved decks by copying
## `.dck` files in DOS — which is exactly why `@DECKLOADERROR` and
## `@DECKEXISTS` are about file names — and its Inventory was the cards
## the game HAS, so it had nothing to stand in for a card it did not.
const EXTRA_COMMANDS: Array[String] = [
	"Undo", "Filters", "Add basic land", "Add proxy card", "Copy deck to",
	"Deck notes", "Sideboard", "Import deck", "Export deck",
]

## [QoL] The heading over the format analysis, in the three places that
## report it: the legality line, the Stats window and the save dialog. Ours
## — the 1997 program had no equivalent, since it classified a deck and
## printed the answer rather than saying what was wrong with it.
const FORMAT_WARNING := "%d cards break the tournament rules (four copies, the restricted list, the banned list):"

const MARGIN := 8.0
const HEADER_H := 50.0
const LEFT_W := 252.0
## The well's lettering ([method _well_label], [method _say]): the dark
## inset under the Showcase takes pale text, and its warning is a light
## warm red rather than the deep red that read on the old pale face.
const WELL_INK := Color(0.96, 0.96, 0.93)
const WELL_WARNING := Color8(244, 150, 128)
const SHOWCASE_SCALE := 0.80
## The Inventory: ONE row of cards plus its scroll bar, which is what the
## 1997 screenshot shows and roughly a fifth of its screen. Every card on
## this screen is [constant MiniCard.SIZE] — the deck area's 0.85 came out
## in the third audit pass (see [CardArea]'s header), so there is no scale
## constant here any more.
const INVENTORY_H := MiniCard.SIZE.y + CardArea.BAR_THICKNESS + 12.0
## The command bar along the bottom of the deck area.
const COMMAND_BAR_H := 26.0
## [QoL] THE SIDEBOARD STRIP — one row of cards with its scroll bar,
## carved out of the bottom of the deck area and named on its own bar row
## ([member CardArea.title]), so naming it costs no card height at all.
##
## WHAT IT COSTS, stated rather than hidden, in the same voice the deck
## area's own 1:1 decision is stated in ([CardArea]): at 1280x800 the deck
## area drops from 7x5 = 35 slots to 7x4 = 28. A forty-card deck is a
## dozen distinct cards and still fits on one page; a two-hundred-unique
## deck is eight pages instead of six. The alternative was a MODE — one
## surface showing either pile — and a mode is exactly the thing the
## owner's first rule forbids: *"a card in the sideboard must never be
## confusable at a glance with a card in the main deck."*
const SIDEBOARD_H := MiniCard.SIZE.y + CardArea.BAR_THICKNESS + 4.0
## `@DECKNUMBERS` — how many deck slots the 1997 bar carries.
const SLOTS := 3

var deck := DeckModel.new()
var filter := DeckFilter.new()

## How many times the whole pool has been walked. The Inventory costs a
## filter + a sort over 800 cards, so this is the number a performance
## test watches (tests/ui/test_deck_builder.gd).
var filter_passes := 0

var _pool: Array[CardData] = []
## `Restore deck` — *"brings back the last deck you cleared."* Null until
## something has been cleared.
var _cleared: DeckModel = null
## `Sort deck` — until it is pressed the Deck area shows cards in the
## order they went in (GDScript Dictionaries keep insertion order).
var _sorted := false
## Has this deck changed since it was last saved or loaded? `@SAVE` —
## "Do you wish to save %s?" — is only asked when it has.
var _dirty := false
## The [member DeckFilter.revision] the Inventory currently shows.
var _drawn_revision := -1

## [QoL] THE THREE DECK SLOTS the 1997 command bar carries
## (`@DECKNUMBERS`, and `Dekbtn1-3` is their art). In Shandalar they are
## the three decks the adventure lets you carry; here they are three
## WORKING decks you can flip between without a save-and-load round trip,
## which is the gesture a builder repeats most while trying a variant. The
## slots live for the session only — `Save deck` is still what writes a
## file, and switching a MODIFIED slot away asks `@SAVE` first, exactly as
## every other way of leaving a deck does.
var _slots: Array[DeckModel] = []
var _slot_dirty: Array[bool] = []
var _slot := 0
var _slot_buttons: Array[Button] = []

## [QoL] ONE STEP OF UNDO over the deck's contents. The screen's most
## destructive gesture is a right-click, which takes a whole column out at
## once — twenty-nine Black Lotus in one click, with nothing but a status
## line to say so. This is the answer to that, and it is deliberately one
## step deep: a builder wants "put that back", not a history.
var _undo: DeckModel = null
var _undo_label := ""

var _showcase: CardPreview
## [QoL] The Showcase's proxy face — the enlarged [ProxyFace], stacked in
## the same slot as [member _showcase] and shown instead of it.
var _proxy_showcase: ProxyFace
var _deck_area: CardArea
## [QoL] The third card surface — see [constant SIDEBOARD_H].
var _sideboard_area: CardArea
var _inventory: CardArea
var _header_slab: Button
var _header_label: Label
var _command_row: HBoxContainer
## The bar's `Stats (N cards)` button. Held rather than looked up by name:
## [method refresh] runs on every card click and did a scene-tree search
## for it every time.
var _stats_button: Button
var _left_column: VBoxContainer
var _stats_label: Label
## A flat 1997 choice line, not a Label — it is clickable ([QoL], see
## [method _open_the_complaint]).
var _legality_label: Button
var _count_label: Label
var _status_label: Label
var _clear_button: Button
var _filter_bar: FilterBar
## [QoL] This screen's own sound and its own bed — see [DeckAudio] for the
## five 1997 slots and for which switch wins.
var _audio: DeckAudio
var _music: MusicPlayer
## The Q/Esc menu ([method _open_deck_menu]) while it is up.
var _menu: OriginalDialog = null
var _bar_ground: Control
var _side_ground: Control
var _status_timer := 0.0


func _ready() -> void:
	set_anchors_preset(Control.PRESET_FULL_RECT)
	CardRegistry.ensure_loaded()
	for card_name in CardRegistry.all_names():
		_pool.append(CardRegistry.get_card(card_name))
	for _i in SLOTS:
		_slots.append(DeckModel.new())
		_slot_dirty.append(false)
	deck = _slots[0]
	# BEFORE ANY REGION THAT MAKES A NOISE — the Filter strip takes a
	# reference to it as it is built.
	_audio = DeckAudio.new()
	add_child(_audio)
	_build_grounds()
	_build_header()
	_build_showcase()
	_build_deck_area()
	_build_sideboard_area()
	_build_command_bar()
	_build_filters()
	_build_inventory()
	_layout()
	refresh()
	_refresh_inventory()
	_start_music()
	set_process(true)


## THE DECK BUILDER HAS MUSIC, AND IT IS ONE BED, LOOPING.
## `init_sounds_and_music` (`shandalar-src/src/deck/deckdll.cpp:2040-2056`)
## opens the deck builder by loading one track —
##
##     sprintf(path, "Sound\\LocMus%d.wav", RANDRANGE(1, 19));
##     sound_init(path, 1);          // slot 1, and set_sound_loop(1, 1)
##
## — and loops it (`sound_init` calls `SND_SetSndMarker(num, 1)` at
## `:2029`). `RANDRANGE` is inclusive at both ends (`:746`), so the range
## is LocMus1..LocMus19; LocMus0 belongs to the adventure's own preload
## list, which is why the manifest stops at 19.
##
## **WHAT CHANGED ON 2026-09-04, and why the random pick went.** The
## owner's playtest: *"Deck builder: only the first song you now use
## should loop over."* This screen used to draw one of the nineteen at
## random and hand it to [method MusicPlayer.play_key], which under the
## default `shuffle` choice then played that bed and twenty-six others
## after it. Two things were wrong with that at once — the bed was a
## different tune every time the screen opened, and it did not stay.
##
## So the bed is [method MusicLibrary.single_for]'s: the FIRST of the
## nineteen the player actually has, in the library's own order, looped
## for as long as the screen is up. "First" is the library's order and not
## the shuffle's, because a shuffle's first track names nothing you can
## come back to. A player who picked one track under Options -> Music
## still gets that track — the choice is honoured, and it is the only
## thing that can displace the default bed.
##
## Silent for a player who has not imported the original's `Sound/` folder
## — [MusicPlayer] treats a missing id as silence — and silent headless.
func _start_music() -> void:
	_music = MusicPlayer.new()
	add_child(_music)
	_apply_music_switch()


## Start or stop the bed to match the two switches ([DeckAudio.music_on]).
## Called on every change of either, so unticking the box stops the tune
## that is playing behind the menu rather than at the next screen.
func _apply_music_switch() -> void:
	if _music == null:
		return
	if not DeckAudio.music_on():
		_music.stop_music()
		return
	_music.play_one(MusicLibrary.single_for(MusicLibrary.deck_builder_beds()))


## Every region is positioned from the CURRENT size, so the screen follows
## the window instead of freezing at whatever size it first saw. Laid out
## from the bottom up, because the Inventory's height is fixed and
## everything above it takes what is left — which is also why the Filter
## bar's real minimum height is measured rather than assumed.
func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED and _inventory != null:
		_layout()


## The 1997 order, read off the screenshot from the bottom up: the
## Inventory band, the Filter strip above it, then the command bar that
## closes the deck area, then the deck area itself — with the Deck Header,
## the Showcase and the status bar stacked down the left.
func _layout() -> void:
	var inv := _inventory_rect()
	_inventory.position = inv.position
	_inventory.size = inv.size
	_bar_ground.position = inv.grow(4.0).position
	_bar_ground.size = inv.grow(4.0).size

	_filter_bar.position = Vector2(MARGIN, inv.position.y - _filter_height() - 5.0)
	_filter_bar.size = Vector2(maxf(0.0, size.x - 2 * MARGIN), _filter_height())

	var deck_rect := _deck_rect()
	_deck_area.position = deck_rect.position
	_deck_area.size = deck_rect.size

	# The sideboard strip closes the deck area's bottom edge, on the
	# Inventory's own teal field rather than the deck's navy quilt — the
	# second of the three cues that say which pile a card is in. Its field
	# has the DECK AREA'S OWN LEFT AND RIGHT EDGES: the quilt above it is
	# laid from the area's edge ([method CardArea._lead]), and two panels
	# stacked on one column read as one column only if their edges agree.
	# (It grows only up and down, a margin for the strip's cards; grown
	# sideways as well it stood three pixels proud of the quilt.)
	var side_rect := _sideboard_rect()
	_sideboard_area.position = side_rect.position
	_sideboard_area.size = side_rect.size
	_side_ground.position = Vector2(side_rect.position.x, side_rect.position.y - 3.0)
	_side_ground.size = Vector2(side_rect.size.x, side_rect.size.y + 6.0)

	# The command bar closes the deck area along its bottom edge — which is
	# now the SIDEBOARD STRIP's bottom edge, not the deck's. Taking it from
	# `deck_rect` put the bar straight through the middle of the strip and
	# hid every `SB` tag behind it; a screenshot caught it and no test
	# could have, which is why this pass took one.
	_command_row.position = Vector2(side_rect.position.x,
		side_rect.position.y + side_rect.size.y + 3.0)
	_command_row.size = Vector2(side_rect.size.x, COMMAND_BAR_H)

	_header_slab.position = Vector2(MARGIN, MARGIN)
	# AS WIDE AS THE CARD UNDER IT, not the column. The slab took the
	# column's 252 and the Showcase is 240 (a card at [constant
	# SHOWCASE_SCALE]), so the title stood twelve pixels proud of the
	# picture it names — the owner's own crop of 2026-09-06 shows the
	# marble's right edge past the card's. The two are one stack now.
	_header_slab.size = Vector2(CardPreview.SIZE.x * SHOWCASE_SCALE, HEADER_H)

	_showcase.position = Vector2(MARGIN, MARGIN + HEADER_H + 6.0)
	_proxy_showcase.position = _showcase.position
	_left_column.position = Vector2(MARGIN,
		_showcase.position.y + CardPreview.SIZE.y * SHOWCASE_SCALE + 6.0)
	_left_column.size.x = LEFT_W
	_fit_the_well()


## THE WELL YIELDS ITS SECOND LINE BEFORE THE COLUMN OVERRUNS THE STRIP.
## The column under the Showcase is the Stats (up to three lines), the
## complaint (clipped to three) and the well; at the shipping 800 the
## well holds the count line and two lines of message, at 720 it cannot,
## and a message with no room is cut at the baseline — which is what the
## 42px floor did at EVERY height (2026-09-06). Decided on the column at
## its FULLEST rather than on the text of the moment, so the well does
## not grow and shrink as the complaint comes and goes.
func _fit_the_well() -> void:
	if _status_label == null or _filter_bar == null:
		return
	var room := _filter_bar.position.y - 5.0 - _left_column.position.y
	var line := _status_label.get_line_height()
	var complaint: float = _legality_label.get_theme_font("font").get_height(
		_legality_label.get_theme_font_size("font_size"))
	var separation := _left_column.get_theme_constant("separation")
	var fullest := _stats_label.get_line_height() * 3 + complaint * 3 \
		+ separation * 2 + _count_label.custom_minimum_size.y + 12.0
	var lines := 2 if fullest + line * 2 <= room else 1
	_status_label.max_lines_visible = lines
	_status_label.custom_minimum_size.y = line * lines


func _filter_height() -> float:
	return maxf(_filter_bar.get_combined_minimum_size().y, FilterBar.ICON_SIZE.y)


## The deck area runs from the top of the screen to the SIDEBOARD strip,
## and from the right edge of the left column to the right margin.
func _deck_rect() -> Rect2:
	var top := MARGIN
	var left := MARGIN + LEFT_W + 10.0
	var bottom := _sideboard_rect().position.y - 6.0
	return Rect2(left, top, maxf(0.0, size.x - left - MARGIN),
		maxf(0.0, bottom - top))


## [QoL] The sideboard strip: the deck area's width, one card tall, sitting
## directly above the command bar.
## THE SIDEBOARD SHARES THE DECK'S EDGES, and derives nothing.
##
## An earlier pass put a fourteen-pixel inset here because the deck's
## CARDS appear to start that far right of the deck's GROUND. They do —
## and it is not a constant: `CardArea` CENTRES its block of columns in
## whatever width it is given (`card_area.gd`, `inset := (inner - block)
## / 2`), so the margin is a function of the resolution. Fourteen was
## measured at 1280x800 and is wrong at every other size, which is what a
## 4K television showed (2026-09-06).
##
## So nothing is derived from it. The two GROUNDS take the same left and
## the same width, each area centres its own cards inside its own ground,
## and the seam is straight at any resolution because the two rects are
## the same expression.


func _sideboard_rect() -> Rect2:
	var left := MARGIN + LEFT_W + 10.0
	var bottom := _filter_bar.position.y - COMMAND_BAR_H - 8.0
	return Rect2(left, maxf(MARGIN, bottom - SIDEBOARD_H),
		maxf(0.0, size.x - left - MARGIN), SIDEBOARD_H)


func _inventory_rect() -> Rect2:
	return Rect2(MARGIN, size.y - INVENTORY_H - MARGIN,
		maxf(0.0, size.x - 2 * MARGIN), INVENTORY_H)


# ------------------------------------------------------------ the grounds --

## The screen's own tiled grounds, all 1997. The whole screen is
## `Dektile4`'s navy weave — the screenshot's ground everywhere outside the
## Inventory, including behind the Deck Header and the Showcase — and the
## Deck area's edge is its QUILT's edge ([method CardArea._draw] lays the
## carvings to the area's own bounds). Dekbar1, the dithered teal field, is
## the Inventory's own ground and always was.
##
## (There used to be a second copy of the weave under the deck area, grown
## three pixels past it "so the area reads as a panel with an edge". A
## 32x32 tile laid from a second origin repeats on a different phase from
## the one under it, so the edge it drew was a SEAM — a hard vertical
## line three pixels off the quilt, in the owner's photo of 2026-09-06 —
## and the quilt now reaches the edge on its own.)
##
## (s30 tiles the OLIVE `Dektile1` over its whole edit-deck screen. The
## screenshot is of the real program and it is navy, so navy wins; the
## olive tile stays imported because it is the ground the warm row of
## `deck_slot_plaques` was carved for.)
func _build_grounds() -> void:
	_ground("deck_tile_slate", Color(0.11, 0.13, 0.17), true)
	_bar_ground = _ground("deck_bar_ground", Color(0.16, 0.32, 0.36), false)
	# The sideboard strip wears Dekbar1 — the INVENTORY's teal field, not
	# the deck's navy weave — because a pile that is not the deck should
	# not be standing on the deck's ground.
	_side_ground = _ground("deck_bar_ground", Color(0.16, 0.32, 0.36), false)


func _ground(key: String, fallback: Color, full_rect: bool) -> Control:
	var art := GameSkin.texture(key)
	var node: Control
	if art != null:
		var tile := TextureRect.new()
		tile.texture = art
		# A TILE TILES; A PANEL STRETCHES, and the two are told apart by
		# size rather than by name. `deck_tile_slate` is 32x32 — a scrap
		# of weave meant to repeat, and stretching it to 1150 would be a
		# smear. `Dekbar1` is 1006x198 — a whole painted panel, and TILING
		# it repeats at 1006, which is invisible at the 1280 the screen was
		# built against (the strip is 1002 wide there, just under one tile)
		# and shows as a seam on anything wider. Measured on a 2560-wide
		# window, 2026-09-06: a column-to-column jump of 7.2 exactly at the
		# repeat, against 1.4 typical.
		tile.stretch_mode = TextureRect.STRETCH_TILE if art.get_width() <= 128 \
			else TextureRect.STRETCH_SCALE
		# A TextureRect's MINIMUM SIZE IS ITS TEXTURE unless it is told
		# otherwise, so `_layout`'s `.size = ...` is a request the node can
		# refuse. `Dekbar1` is 1006x198 and the sideboard's strip is 994
		# wide, so that ground came out twelve pixels too wide and hung
		# past the screen's right edge — the deck's own ground never showed
		# it because `deck_tile_slate` is 32x32 and no layout is smaller
		# than that. Found 2026-09-05 by measuring the two grounds against
		# each other after they stopped agreeing on their right edge.
		tile.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		node = tile
	else:
		var flat := ColorRect.new()
		flat.color = fallback
		node = flat
	node.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if full_rect:
		node.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(node)
	return node


# ------------------------------------------------------- the Deck Header --

## The Deck Header on `Dektit1` — the original's veined marble title slab.
## Clicking it opens the Deck Info dialog, which is the 1997 gesture
## (*"Right-click on the box when you want to change that"*); we accept
## either button, since a left click on a title box is what a player
## reaches for today.
func _build_header() -> void:
	_header_slab = Button.new()
	_header_slab.flat = true
	var art := GameSkin.texture("deck_title_slab")
	if art != null:
		var patch := NinePatchRect.new()
		patch.texture = art
		patch.patch_margin_left = 6
		patch.patch_margin_right = 6
		patch.patch_margin_top = 6
		patch.patch_margin_bottom = 6
		patch.set_anchors_preset(Control.PRESET_FULL_RECT)
		patch.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_header_slab.add_child(patch)
	else:
		_header_slab.add_theme_stylebox_override("normal",
			OriginalDialog.panel_style("panel_dark_stone", 4.0))
	_header_label = OriginalDialog.label(deck.deck_name, 18, true)
	_header_label.set_anchors_preset(Control.PRESET_FULL_RECT)
	_header_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_header_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_header_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# A LONG NAME IS TRIMMED, NOT LET OUT OF THE SLAB. Deck names run to
	# 71 characters in the shipped lists ("Råde — Worlds 1996
	# (Erhnamgeddon)"), and the marble title slab is a fixed width: a name
	# that does not fit used to run past both its ends. `..._FORCE` is the
	# variant that actually draws the ellipsis — plain TRIM drops the dots
	# (a lesson from the setup screen's deck picker).
	_header_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS_FORCE
	_header_label.clip_text = true
	_header_slab.add_child(_header_label)
	# ...AND THE WHOLE NAME IS ONE HOVER AWAY. A trimmed name the player
	# cannot read in full is worse than a name that overflows, so the slab
	# carries it as a tooltip — at the pointer, in Godot's own tooltip
	# font, which is larger than the 18px the slab letters it in.
	_header_slab.tooltip_text = "%s\n\nDeck Info — name this deck" % deck.deck_name
	_header_slab.pressed.connect(_open_deck_info)
	add_child(_header_slab)


## THE COMMAND BAR along the bottom of the deck area, on the 1997
## screenshot's own five buttons:
##
##   `Stats (60 cards)` | `Deck1` | `Deck2` | `* Deck3 *` | `Done`
##
## with one substitution. The screenshot's bar has no room for thirteen
## commands, and the original did not need it to: `@DECKSURFACE_STANDALONE`
## lived on a right-click mini-menu over the deck surface, which this
## screen still offers. So the bar keeps `Stats`, the three deck slots and
## `Done`, and gains a `Deck` button that opens that same mini-menu —
## the era's own idiom rather than a second row of buttons or nine
## deletions. `@FILTERS`' "Main menu buttons On/Off" is the 1997 evidence
## that the original itself treated this bar as optional chrome over a
## menu that was always there.
##
## `Stats` carries its own count the way the screenshot letters it, and
## the active slot is starred — `* Deck3 *` — which is how the screenshot
## marks it.
func _build_command_bar() -> void:
	_command_row = HBoxContainer.new()
	_command_row.add_theme_constant_override("separation", 4)

	_stats_button = OriginalDialog.button("", Vector2(140, COMMAND_BAR_H))
	_stats_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_stats_button.pressed.connect(_run_command.bind("Stats"))
	_stats_button.name = "StatsButton"
	_command_row.add_child(_stats_button)

	var menu := OriginalDialog.button("Deck", Vector2(72, COMMAND_BAR_H))
	menu.tooltip_text = "@DECKSURFACE_STANDALONE — the deck surface's mini-menu"
	menu.pressed.connect(_open_mini_menu)
	_command_row.add_child(menu)

	# [QoL] A DOOR TO THE DECKS, ON THE BAR. The owner's playtest,
	# 2026-09-04: *"A button to load existing decks from our collection, or
	# any other from the disk for that matter."* `&Load deck` has always
	# been on the mini-menu and on Ctrl+O, which is two places a player who
	# has never opened the mini-menu will not look. The dialog it opens is
	# the one that was already there — the 318 shipped and saved decks
	# under [constant DeckGroups.ORDER]'s headings — and it now carries the
	# other half of the ask as well ([method _open_deck_file_browser]).
	var load_button := OriginalDialog.button("Load", Vector2(72, COMMAND_BAR_H))
	load_button.name = "LoadButton"
	load_button.tooltip_text = "@LOADDECKDIALOG — a deck of ours, or any file on disk"
	load_button.pressed.connect(_run_command.bind("Load deck"))
	_command_row.add_child(load_button)

	for i in SLOTS:
		var slot := _deck_slot_button(i)
		_command_row.add_child(slot)
		_slot_buttons.append(slot)

	# `@DIALOGBUTTONS`' third word, and the screenshot's last button.
	var done := OriginalDialog.button("Done", Vector2(120, COMMAND_BAR_H))
	done.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	done.pressed.connect(_run_command.bind("Exit deck builder"))
	_command_row.add_child(done)
	add_child(_command_row)

	# The mini-menu is where `Clear deck` lives now, so the button whose
	# label flips to `Restore deck` is a plain hidden Button that the
	# mini-menu reads its text off — the same contract the tests use.
	_clear_button = Button.new()
	_clear_button.text = "Clear deck"
	_clear_button.visible = false
	_clear_button.pressed.connect(_run_command.bind("Clear deck"))
	add_child(_clear_button)


## [QoL] One deck-slot button. LETTERED, not glyphed: `Dekbtn1-3` is the
## 1997 art for a deck-slot button (78x23 of stone carrying a fan-of-cards
## glyph and the numeral) but the screenshot's bar does not use it — its
## three slots are plain lettered buttons reading `Deck1`, `Deck2` and
## `* Deck3 *`, and the star on the active one is the whole state cue. So
## these are `OriginalDialog.button`s and the art stays surveyed rather
## than imported (tools/import_original.py records where it went).
func _deck_slot_button(index: int) -> Button:
	var button := OriginalDialog.button(_slot_label(index),
		Vector2(76, COMMAND_BAR_H))
	button.tooltip_text = "[QoL] deck slot %d — three decks in hand at once" \
		% (index + 1)
	button.pressed.connect(_switch_slot.bind(index))
	return button


## `Deck1` normally, `* Deck1 *` for the slot in the deck area — the
## screenshot's own marking.
func _slot_label(index: int) -> String:
	return "* Deck%d *" % (index + 1) if index == _slot else "Deck%d" % (index + 1)


# ---------------------------------------------------------- the Showcase --

func _build_showcase() -> void:
	_showcase = CardPreview.new()
	_showcase.docked = true
	_showcase.scale = Vector2(SHOWCASE_SCALE, SHOWCASE_SCALE)
	# THE EXPAND TOGGLE REACHES THIS SHOWCASE TOO. It did not until
	# 2026-09-05: the duel screen restored `ExpandTextBoxOnBigCard` onto
	# its own preview and this one had no reader at all, so a long card
	# clipped here with nothing the player could do about it — which is
	# where the playtest saw it, since this is the Showcase you sit in
	# front of while building. Same widget, same setting, same answer.
	_showcase.set_text_expanded(CardPreview.expand_wanted())
	_showcase.show_back()
	add_child(_showcase)
	# [QoL] THE SHOWCASE'S OTHER FACE. *"Whatever card the mouse cursor is
	# hovering over is displayed here"* — and a PROXY is one of the things
	# the cursor can be over, so it needs an enlarged form too. It is a
	# second widget rather than a mode of [CardPreview] because a proxy is
	# not a [CardInstance] and `CardPreview.show_card` takes one (and
	# because `game/duel/` is not this screen's to change).
	#
	# Same slot, same [constant SHOWCASE_SCALE]: the two are stacked and
	# exactly one is visible, so the pointer crossing from a card to a
	# proxy swaps the picture without moving it.
	_proxy_showcase = ProxyFace.new("", true)
	_proxy_showcase.scale = Vector2(SHOWCASE_SCALE, SHOWCASE_SCALE)
	_proxy_showcase.disabled = true
	_proxy_showcase.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_proxy_showcase.focus_mode = Control.FOCUS_NONE
	_proxy_showcase.visible = false
	add_child(_proxy_showcase)

	_left_column = VBoxContainer.new()
	_left_column.custom_minimum_size.x = LEFT_W
	_left_column.add_theme_constant_override("separation", 2)
	_stats_label = OriginalDialog.label("", 12)
	_stats_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_stats_label.custom_minimum_size.x = LEFT_W
	_left_column.add_child(_stats_label)
	# The legality line has to stay INSIDE the strip between the Showcase
	# and the Filter bar, so it is clipped to three lines with the whole
	# text on its cue card. `Stats` shows it in full.
	#
	# [QoL] IT IS A BUTTON, not a label: it is the only place the screen
	# ever complains, and until this pass the complaint was inert text.
	# Clicking it opens whichever dialog answers it — `Extra Cards` when
	# the deck is over the Shandalar duplicate allowance (that dialog can
	# fix it in one press), `Stats` otherwise, where the whole problem list
	# is written out rather than clipped to three lines. It still LOOKS
	# like the line it was: flat, left-aligned, wrapped, no bevel.
	_legality_label = OriginalDialog.choice_line("")
	_legality_label.add_theme_font_size_override("font_size", 11)
	_legality_label.alignment = HORIZONTAL_ALIGNMENT_LEFT
	_legality_label.custom_minimum_size.x = LEFT_W
	_legality_label.pressed.connect(_open_the_complaint)
	_left_column.add_child(_legality_label)

	# THE NARROW BAR UNDER THE SHOWCASE. The screenshot has one — a thin
	# ruled strip, empty in that capture — and it is the natural home for
	# the two lines the Inventory's own header used to carry: how long the
	# filtered list is, and the screen's last word to the player.
	# Grey, not the Situation Bar's red-brown Telluser stone: the
	# screenshot's bar is the same pale speckle as the command buttons, and
	# `bar_style` put a salmon slab down the left of the first capture.
	var bar := PanelContainer.new()
	# A WELL, NOT A BUTTON. This strip carries the game's line TO the
	# player — how long the filtered list is, and the screen's last word —
	# and it wore `button_normal`, the original's raised button face. Two
	# things followed from that, both reported on 2026-09-05: tiled across
	# a strip four times the 131px source the centre repeated and the
	# seams read as *"two buttons under with text over"*, and even seamless
	# a RAISED BEVEL READS AS CLICKABLE. It is not clickable, and a control
	# that does nothing when pressed is worse than a plain panel.
	#
	# So it is inset instead: raised means press me, sunken means read me,
	# which is the same distinction the era drew when it carved the
	# end-of-duel window IN rather than raising it
	# ([constant OriginalDialog.PANELS] `panel_end_duel`). Flat colour
	# rather than art, because there is no 1997 sprite for "a well" and
	# inventing one out of a button's pixels is how this started.
	var bar_style := StyleBoxFlat.new()
	bar_style.bg_color = Color(0.06, 0.07, 0.10, 0.55)
	bar_style.border_color = Color(0.62, 0.66, 0.72, 0.45)
	bar_style.set_border_width_all(1)
	bar_style.set_corner_radius_all(2)
	bar_style.set_content_margin_all(6.0)
	bar.add_theme_stylebox_override("panel", bar_style)
	bar.custom_minimum_size = Vector2(LEFT_W, 42)
	# THE HEIGHT IS THE LINES', NOT A NUMBER'S. A Label that wraps AND
	# trims reports a minimum height of one pixel (it can always show
	# less), so this floor of 42 was the well's whole height: six pixels
	# of margin twice, the count line, and about ten pixels left for a
	# status line allowed two — which cut every message off at the
	# baseline (caught by screenshotting it, 2026-09-06). Each line now
	# asks for its own height below, and the well is as tall as they are.
	# EXACTLY [constant LEFT_W], not "at least". `custom_minimum_size` is a
	# floor and a VBox child fills the column, so this strip stretched to
	# 268 and its right edge crossed x=267 — where the deck area's ground
	# above and the sideboard's ground below both begin. The overlap was
	# reported as the sideboard being too far left (2026-09-05); it is not,
	# the two grounds share that edge exactly. It was this well overrunning
	# them, so the well is pinned instead of the layout being moved.
	bar.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	var lines := VBoxContainer.new()
	lines.add_theme_constant_override("separation", 0)
	# PALE ON THE WELL, AND NO OUTLINE. [method OriginalDialog.ink_label]
	# is dark ink under a 4px pale outline — right for the sandstone it
	# was written for, and wrong the moment this strip became a dark inset
	# (2026-09-05): the outline reads as a border around every glyph and
	# the owner reported the line "hardly readable with its border". The
	# ground changed, so the lettering changes with it, which is the same
	# rule [UiChrome] settled for the sand panels in the other direction.
	_count_label = _well_label(15, true)
	# THE TEXT MUST NOT SET THE WIDTH. A Label's minimum size is its whole
	# string, and a PanelContainer is at least its content — so the count
	# line, once it grew to 15px bold, pushed this strip from 252 to 268
	# and over the x=267 edge the deck and sideboard grounds share. Capped
	# here and allowed to wrap, so the panel's width is the LAYOUT's
	# decision and the line's length is not.
	_count_label.custom_minimum_size.x = LEFT_W - 16
	_count_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_count_label.max_lines_visible = 1
	_count_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_count_label.custom_minimum_size.y = _count_label.get_line_height()
	lines.add_child(_count_label)
	_status_label = _well_label(13, false)
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.custom_minimum_size.x = LEFT_W - 16
	_status_label.max_lines_visible = 2
	_status_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	# Two lines when the column has the room, one when it does not —
	# [method _fit_the_well] decides at every layout.
	_status_label.custom_minimum_size.y = _status_label.get_line_height() * 2
	lines.add_child(_status_label)
	bar.add_child(lines)
	_left_column.add_child(bar)
	add_child(_left_column)


# --------------------------------------------------------- the Deck area --

func _build_deck_area() -> void:
	_deck_area = CardArea.new(true)
	_deck_area.source_name = "deck"
	# The quilt: every slot, filled or empty, carries a carved 1997 mana
	# watermark. It is what makes this area read as a deck's worth of
	# places rather than a blue field with some cards on it.
	_deck_area.slot_plaques = true
	_deck_area.card_activated.connect(_remove_one)
	_deck_area.card_bulk.connect(_remove_all)
	_deck_area.card_shifted.connect(_move_to_sideboard)
	_deck_area.card_hovered.connect(_show_in_showcase)
	_deck_area.card_dropped.connect(_dropped_on_deck)
	add_child(_deck_area)

	# The 1997 gesture: *"You can also right-click anywhere in this area to
	# open a mini-menu."* Right-clicking the SURFACE (not a card) opens the
	# deck-surface mini-menu; a card's own right-click is taken by its
	# widget, which accepts the event, so the two never fire together.
	_deck_area.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			_open_mini_menu())


# ---------------------------------------------------- [QoL] the sideboard --

## THE SIDEBOARD STRIP. The 1997 Deck Builder had no such surface — the
## word does not occur in `shandalar-src/src/deck/deckdll.cpp` and the
## `.dck` file's `.v<Colour>` sections are the adventure AI's swaps, not a
## tournament sideboard — so every part of this is [QoL] and marked so.
## It exists because `Side&board between duels` (`Program/Text.res:2863`)
## now PLAYS the `SB:` lines between the duels of a best-of-N match, and
## the ROADMAP's own objection to building it (*"the screen would have
## been editing a field nothing reads"*) died with that.
##
## THREE CUES SAY WHICH PILE A CARD IS IN, because one is not enough on a
## screen that shows two decks' worth of cards at once:
##
##   the GRID   a strip of its own, below the deck, on the Inventory's
##              teal field instead of the deck's navy quilt
##   the COUNT  its own heading — `Sideboard (15)` — on its own bar row,
##              and a `Sideboard: 15` line in the left column beside the
##              deck's own numbers
##   the CARD   an `SB` plate on the top-left corner of every tile
##              ([member CardArea.corner_tag]), the opposite corner from
##              the count disc so the two can never be confused
##
## THE GESTURES, all four of them the same in both directions:
##   click        take one copy OUT of the sideboard (the deck area's own
##                click, on the other pile)
##   right-click  take the whole stack out
##   SHIFT-click  send one copy to the other pile — Inventory to
##                sideboard, deck to sideboard, sideboard to deck
##   drag         the manual's own gesture, between any two surfaces
func _build_sideboard_area() -> void:
	_sideboard_area = CardArea.new(false)
	_sideboard_area.source_name = "sideboard"
	_sideboard_area.corner_tag = "SB"
	_sideboard_area.card_activated.connect(_remove_one_side)
	_sideboard_area.card_bulk.connect(_remove_all_side)
	_sideboard_area.card_shifted.connect(_move_to_deck)
	_sideboard_area.card_hovered.connect(_show_in_showcase)
	_sideboard_area.card_dropped.connect(_dropped_on_sideboard)
	add_child(_sideboard_area)
	# The strip's own right-click on EMPTY felt opens the same mini-menu
	# the deck surface does, so the gesture means one thing on this screen.
	_sideboard_area.gui_input.connect(func(event: InputEvent) -> void:
		if event is InputEventMouseButton and event.pressed \
				and event.button_index == MOUSE_BUTTON_RIGHT:
			_open_mini_menu())


# --------------------------------------------------------- the Filter bar --

func _build_filters() -> void:
	_filter_bar = FilterBar.new(filter)
	# *"A quick stone grinding sound when pressing the stone filter
	# buttons"* — the strip plays it itself, on the press, because the
	# `changed` signal it emits afterwards is also emitted by the sort menu
	# and by `Select All`, which are not stone buttons.
	_filter_bar.sound = _audio
	_filter_bar.changed.connect(_refresh_inventory)
	_filter_bar.menu_requested.connect(_open_filter_menu)
	_filter_bar.expand_toggled.connect(func(on: bool) -> void:
		_showcase.set_text_expanded(on))
	add_child(_filter_bar)


# ---------------------------------------------------------- the Inventory --

## ONE ROW OF CARDS AT 1:1 on Dekbar1's teal field, with the scroll bar
## along the bottom — the screenshot's Inventory exactly. The type-ahead
## and the sort that used to head this area now ride on the Filter strip
## (FilterBar._search_group), which is what freed the height for the cards
## to be full size.
##
## THE TRADE THIS MAKES, stated rather than hidden: one row of cards shows
## nine at a time where two rows of miniatures showed twenty, so a raw walk
## of the whole pool is a longer walk. The filters, the sort,
## the type-ahead and PageUp/PageDown are what the 1997 screen expected you
## to reach for instead, and [member _count_label] now says where in the
## list you are ([QoL]) so the walk is at least legible.
func _build_inventory() -> void:
	_inventory = CardArea.new(false)
	_inventory.source_name = "inventory"
	# [QoL] *"Add arrows to the left and right of cards to help scroll,
	# beside the scrollbar at the bottom."* (owner's playtest, 2026-09-04)
	# On the INVENTORY and not on the deck: this is the row the owner
	# pointed at, it is the row that is eighty-eight pages long, and the
	# deck area is scrolled by a bar down its own side where an arrow
	# column would have to stand.
	_inventory.scroll_arrows = true
	# [QoL] The badge on an Inventory card is how many copies are ALREADY
	# in the deck — the question a builder asks on every single card, and
	# the one that used to need a scan of the deck area to answer. It is
	# read per visible cell, so it costs ten dictionary lookups per deck
	# change and never re-walks the pool.
	_inventory.badge_min = 1
	_inventory.count_source = func(card_name: String) -> int:
		return deck.count_of(card_name)
	_inventory.card_activated.connect(_add_one)
	_inventory.card_bulk.connect(_add_playset)
	_inventory.card_shifted.connect(_add_one_side)
	_inventory.card_hovered.connect(_show_in_showcase)
	_inventory.card_dropped.connect(_dropped_on_inventory)
	_inventory.scrolled.connect(_update_count_line)
	add_child(_inventory)


# ------------------------------------------------------------- behaviour --

## *"Whatever card the mouse cursor is hovering over is displayed here."*
## A PROXY goes in the other face ([member _proxy_showcase]) — it has no
## [CardInstance] to hand [method CardPreview.show_card], and it would be
## drawn in a coloured frame if it had.
func _show_in_showcase(data: CardData) -> void:
	if ProxyCard.is_proxy_data(data):
		_proxy_showcase.set_proxy_name(data.card_name)
		_proxy_showcase.visible = true
		_showcase.visible = false
		return
	_proxy_showcase.visible = false
	_showcase.show_card(CardInstance.new(data, -1, 0))


func _add_one(card_name: String) -> bool:
	var before := deck.duplicate_model()
	var refusal := deck.add(card_name)
	if refusal != "":
		_say(refusal, true)
		return false
	_remember(before, "Add %s" % card_name)
	_dirty = true
	# `Draw.wav`, the 1997 deck surface's own slot 2 — see [DeckAudio].
	_audio.play(DeckAudio.CUE_ADD)
	refresh()
	return true


## The whole playset at once (right-click in the Inventory) — the
## builder's own convenience, since the 1997 screen dragged copies one at
## a time out of a collection that limited them and ours does not. It
## reports what it ACTUALLY added, which it did not before: a full deck
## refused every copy and the screen still said "Added 4".
func _add_playset(card_name: String) -> void:
	var before := deck.duplicate_model()
	var added := 0
	var refusal := ""
	for _i in 4:
		refusal = deck.add(card_name)
		if refusal != "":
			break
		added += 1
	if added == 0:
		# The refusal from the attempt that FAILED. It used to call add()
		# again purely to fetch the message, which is a mutating call in an
		# error path — harmless only because every refusal here is stable.
		_say(refusal, true)
		return
	_remember(before, "Add %d %s" % [added, card_name])
	_dirty = true
	refresh()
	_say("Added %d %s" % [added, card_name])


func _remove_one(card_name: String) -> void:
	var before := deck.duplicate_model()
	var refusal := deck.remove(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Remove %s" % card_name)
	_dirty = true
	# `Discard.wav`, the 1997 deck surface's own slot 3.
	_audio.play(DeckAudio.CUE_REMOVE)
	refresh()


## The whole column at once (right-click in the Deck area). It says how
## many it took, because taking twenty copies out in one click with no
## word about it is not something a player can undo.
func _remove_all(card_name: String) -> void:
	var before := deck.duplicate_model()
	var had := deck.count_of(card_name)
	var refusal := deck.remove_all(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Remove all %s" % card_name)
	_dirty = true
	_audio.play(DeckAudio.CUE_REMOVE)
	refresh()
	_say("Removed %d %s" % [had, card_name])


# ------------------------------------------------ [QoL] the sideboard --
# One handler per gesture, each one MUTATION + UNDO STEP + refresh, in the
# same shape as the deck's own handlers above — so a sideboard change is
# undoable exactly like a deck change ([method DeckModel.duplicate_model]
# copies both piles, which is why Undo can put either back).

## SHIFT-click in the Inventory: a copy straight into the sideboard,
## without a detour through the deck.
func _add_one_side(card_name: String) -> void:
	var before := deck.duplicate_model()
	var refusal := deck.add_side(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Add %s to the sideboard" % card_name)
	_dirty = true
	refresh()
	_say("%s to the sideboard (%d)" % [card_name, deck.side_total()])


func _remove_one_side(card_name: String) -> void:
	var before := deck.duplicate_model()
	var refusal := deck.remove_side(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Remove %s from the sideboard" % card_name)
	_dirty = true
	refresh()


func _remove_all_side(card_name: String) -> void:
	var before := deck.duplicate_model()
	var had := deck.side_count_of(card_name)
	var refusal := deck.remove_all_side(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Remove all %s from the sideboard" % card_name)
	_dirty = true
	refresh()
	_say("Removed %d %s from the sideboard" % [had, card_name])


## Deck -> sideboard, one copy. The refusal is the DECK's own
## ("There is no X in this deck"), so a shift-click on a card that is not
## there says the true thing rather than a sideboard error.
func _move_to_sideboard(card_name: String) -> void:
	var before := deck.duplicate_model()
	var refusal := deck.to_sideboard(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Move %s to the sideboard" % card_name)
	_dirty = true
	refresh()
	_say("%s to the sideboard (%d)" % [card_name, deck.side_total()])


## Sideboard -> deck, one copy. [method DeckModel.to_deck] puts nothing
## back when the DECK refuses (a deck already at the 1997 500-card
## ceiling), so a refused move loses no card.
func _move_to_deck(card_name: String) -> void:
	var before := deck.duplicate_model()
	var refusal := deck.to_deck(card_name)
	if refusal != "":
		_say(refusal, true)
		return
	_remember(before, "Move %s into the deck" % card_name)
	_dirty = true
	refresh()
	# "TO THE", NOT AN ARROW. `MPlantin` has no U+2192 and the well drew
	# the move as "Circle of Protection: Red    sideboard (18)" — a gap
	# where the direction was (caught by screenshotting it, 2026-09-06).
	_say("%s to the deck (%d)" % [card_name, deck.total()])


# THE DROP ROUTING. Every surface accepts a drop from every OTHER surface
# ([method CardArea._can_drop_data]), and with three of them the source
# decides what the drop MEANS: dragging a card out of the deck onto the
# sideboard moves it, dragging it onto the Inventory throws it away.

func _dropped_on_deck(card_name: String, from: String) -> void:
	if from == "sideboard":
		_move_to_deck(card_name)
	else:
		_add_one(card_name)


func _dropped_on_sideboard(card_name: String, from: String) -> void:
	if from == "deck":
		_move_to_sideboard(card_name)
	else:
		_add_one_side(card_name)


func _dropped_on_inventory(card_name: String, from: String) -> void:
	if from == "sideboard":
		_remove_one_side(card_name)
	else:
		_remove_one(card_name)


## Redraw everything that depends on the DECK. The Inventory is not on
## that list — it shows the whole pool through the filter and changes only
## when the filter does.
func refresh() -> void:
	_header_label.text = deck.deck_name
	if _header_slab != null:
		_header_slab.tooltip_text = "%s\n\nDeck Info — name this deck" % deck.deck_name
	# ONE WALK for the four numbers this method letters, not five
	# ([method DeckModel.headline_counts] — third audit pass, 2026-09-01).
	var tally := deck.headline_counts()
	# The command bar letters its own count, as the screenshot does.
	if _stats_button != null:
		_stats_button.text = "Stats (%d cards)" % int(tally["total"])
	for i in _slot_buttons.size():
		_slot_buttons[i].text = _slot_label(i)
	# [QoL] the Inventory's badges follow the deck — page-sized work only.
	if _inventory != null:
		_inventory.refresh_counts()
	var order: Array = deck.names() if _sorted else deck.counts.keys()
	_deck_area.set_entries(_entries_for(order, deck.counts))
	_refresh_sideboard_area()
	# `Stats (%d cards)` (`@STATS`) is the original's own heading for these
	# numbers; the second line is s30's land/creature/spell split
	# (drawDeckStats).
	_stats_label.text = "Stats (%d cards)\nLand: %d   Creatures: %d   Spells: %d" % [
		int(tally["total"]), int(tally["land"]), int(tally["creature"]),
		int(tally["spell"])]
	# [QoL] The sideboard's own count, on the line that already carries the
	# deck's — the first of the three cues that say which pile is which.
	if deck.side_total() > 0:
		_stats_label.text += "\nSideboard: %d" % deck.side_total()
	_refresh_legality()


## [QoL] The sideboard strip's entries and its heading. Always drawn, even
## empty: a surface a player is expected to DRAG onto has to be there
## before there is anything in it.
## ...and only when it has MOVED. [method refresh] runs on every card
## click and the sideboard is the pile that changes least, so the strip
## keeps a signature of what it is showing and rebuilds its page only when
## that changes. Without the guard, adding a Mountain to the deck sorted
## and rebound the sideboard's widgets too.
var _side_signature := "-"

func _refresh_sideboard_area() -> void:
	if _sideboard_area == null:
		return
	var side_total := deck.side_total()
	var signature := "%d/%d" % [side_total, deck.sideboard.size()]
	for card_name in deck.sideboard:
		signature += "|%s%d" % [card_name, int(deck.sideboard[card_name])]
	if signature == _side_signature:
		return
	_side_signature = signature
	_sideboard_area.set_entries(_entries_for(deck.side_names(), deck.sideboard))
	_sideboard_area.title = "Sideboard (%d)" % side_total


## ONE PILE AS `[[CardData, count], ...]` — what [method CardArea.set_entries]
## takes, in [param order].
##
## A PROXY GETS A [CardData] TOO, from [method ProxyCard.data_for], which
## builds one and never registers it. That is what lets a proxy travel
## through the surfaces on exactly the same rails as a card — the entry
## list, the cell, the badge, the drag payload, the Showcase — while the
## face that draws it is a [ProxyFace] and not a [MiniCard]. It also means
## a card the registry somehow cannot produce is DRAWN AS A PROXY rather
## than silently dropped, which is what the old loop did: it skipped every
## name `CardRegistry.get_card` returned null for, so a proxy in the deck
## was a card the player could not see and could not remove.
func _entries_for(order: Array, pile: Dictionary) -> Array:
	var entries: Array = []
	entries.resize(order.size())
	for i in order.size():
		var card_name := String(order[i])
		var data: CardData = CardRegistry.get_card(card_name) \
			if CardRegistry.has_card(card_name) else ProxyCard.data_for(card_name)
		entries[i] = [data, int(pile.get(card_name, 0))]
	return entries


## The one line on which the screen complains. `problems()` is the DUEL's
## own two refusals in the string table's words; the duplicate advice is
## SHANDALAR's and is never a refusal.
##
## The whole text goes on the cue card and into whichever dialog the line
## opens; the line itself is CLIPPED here rather than by
## `max_lines_visible`, because it is a Button now ([QoL], see
## `_build_showcase`) and a wrapping Button grows its container instead of
## trimming — which would push the left column into the Filter strip.
const LEGALITY_CHARS := 118

## What the line last said, so a card click that does not change the
## complaint does not repaint it. Five theme overrides and two string
## builds were a fifth of the cost of every click, and the line changes
## perhaps four times in a whole session (third audit pass, 2026-09-01).
var _legality_said := ""
var _legality_color := Color(0, 0, 0, 0)

func _refresh_legality() -> void:
	var problems := deck.problems()
	var color := OriginalDialog.HIGHLIGHT
	var full := "This deck can be used in the duel."
	# [QoL] THE PROXIES COME FIRST, ahead of the two 1997 refusals, because
	# they are the only complaint on this line that no amount of adding or
	# cutting cards can answer: a deck of forty proxies is the right SIZE
	# and still cannot be duelled with. It is deliberately not one of
	# [method DeckModel.problems] — see [method DeckModel.proxy_problem]
	# for why our sentence stays out of a list of 1997 quotations.
	var proxied := deck.proxy_problem()
	if proxied != "":
		full = proxied
		color = Color8(232, 176, 96)
	elif not problems.is_empty():
		full = " ".join(problems)
		color = Color8(232, 176, 96)
	else:
		var advice := deck.over_duplicate_limit()
		if not advice.is_empty():
			full = "There are too many of the following Cards in your deck: " \
				+ ", ".join(advice)
			color = OriginalDialog.CHOICE
		else:
			# [QoL] THE TOURNAMENT RULES, when nothing more urgent is
			# wrong. They sit BELOW Shandalar's duplicate allowance because
			# the two overlap on copies and Shandalar's is usually the
			# TIGHTER of the two (three copies in a 40-59 card deck against
			# the DCI's four), so where both fire the Shandalar line is the
			# more useful sentence. What this adds that nothing else on
			# this screen says is the RESTRICTED and BANNED half.
			#
			# Asked only HERE, in the branch that can use the answer: this
			# method runs on every card click.
			var offences := deck.format_offences()
			if not offences.is_empty():
				full = FORMAT_WARNING % offences.size() \
					+ " " + " ".join(offences)
				color = OriginalDialog.CHOICE
	# [QoL] THE SIDEBOARD SIZE RULE, stated in the one place this screen
	# states its main-deck rule. It rides after whatever else the line
	# says, because it is the least of the three and never a refusal — see
	# [method DeckModel.sideboard_advice] for why fifteen is fifteen.
	var side := deck.sideboard_advice()
	if not side.is_empty():
		full += "  " + " ".join(side)
		if problems.is_empty():
			color = OriginalDialog.CHOICE
	if full == _legality_said and color == _legality_color:
		return
	_legality_said = full
	_legality_color = color
	_legality_label.text = full if full.length() <= LEGALITY_CHARS \
		else full.substr(0, LEGALITY_CHARS - 1).strip_edges() + "…"
	_legality_label.tooltip_text = full
	for state in ["font_color", "font_hover_color", "font_focus_color",
			"font_pressed_color"]:
		_legality_label.add_theme_color_override(state, color)
	_legality_label.add_theme_color_override("font_hover_color",
		color.lightened(0.35))


## [QoL] Clicking the complaint opens whatever answers it: `Extra Cards`
## when Shandalar would call some stack too big — that dialog cuts them —
## and `Stats` otherwise, which writes the whole problem list out instead
## of clipping it to the strip.
func _open_the_complaint() -> void:
	if deck.problems().is_empty() and not deck.over_duplicate_limit().is_empty():
		_open_extra_cards()
		return
	_open_stats()


## Re-run the filter over the pool — but only when the filter has actually
## moved. A new list starts at its first card, which is the one place
## s30 resets its carousel too (`edit_deck.go:391-396`).
func _refresh_inventory() -> void:
	if filter.revision == _drawn_revision:
		return
	_drawn_revision = filter.revision
	filter_passes += 1
	var shown := filter.apply(_pool)
	var entries: Array = []
	entries.resize(shown.size())
	for i in shown.size():
		entries[i] = [shown[i], 1]
	_inventory.set_entries(entries)
	_inventory.reset_scroll()
	_update_count_line()
	_filter_bar.refresh()


## `X cards are in the list` is the 1997 cue card. The range after it is
## [QoL]: one row of nine cards is eighty-eight pages of the whole pool,
## and a player walking it deserves to know where they are.
##
## [QoL] AND THE SAME COUNT AGAIN IN THE INVENTORY'S OWN BOTTOM-RIGHT
## CORNER ([member CardArea.tally]), which is the 2026-09-03 playtest's
## ask: *"The number of cards in the bottom row should be displayed in the
## bottom right — if you filter you immediately see this number get
## smaller and see the effect of the filter!"* The line above says the
## same thing in the 1997 sentence, but it stands in the LEFT COLUMN,
## three regions away from the row it counts, so the filter's effect had
## to be looked up rather than seen. The corner is where the eye already
## is when it is on the cards.
##
## WHAT IT COUNTS, and it is not the obvious thing: [b]every card the
## filter leaves standing[/b] — the whole list — and not the nine on the
## page. The number is there to be watched while the filters and the
## type-ahead move, and a page-sized number would sit at "9 cards" from
## Abu Ja'far to Zombie Master and report nothing. `entry_count()` is the
## filtered list's length; where in it the player is standing is the
## `(first-last)` range on the line above, which is a different question.
func _update_count_line() -> void:
	var total := _inventory.entry_count()
	var first: int = mini(_inventory.offset() + 1, total)
	var last: int = mini(_inventory.offset() + _inventory.page_size(), total)
	# SHORT ENOUGH TO SURVIVE THE COLUMN. The 1997 cue-card phrasing
	# ("X cards are in the list", `Cuecards.txt`) is 38 characters with the
	# range on it, and at the 15px bold the owner asked for that needs
	# ~256px in a 236px column — so it ellipsised away the very range it
	# was there to show (caught by screenshotting it, 2026-09-05). The
	# echo of the era's voice is worth less than the number, so the number
	# stays and the sentence goes: both figures fit at full size.
	_count_label.text = "%d cards" % total
	if total > _inventory.page_size():
		_count_label.text += " — showing %d-%d" % [first, last]
	_inventory.tally = "%d card%s" % [total, "" if total == 1 else "s"]


## A line ON THE DARK WELL: white, no outline, and emboldened when it is
## the count — the owner asked for *"white text, larger and bold on that
## inset"*. `MPlantin` ships one cut, so the weight is synthesised by
## growing the outline the way [method UiChrome.menu_button] does for the
## shell buttons; there is no bold companion to ask for.
func _well_label(size: int, heavy: bool) -> Label:
	var lab := Label.new()
	lab.add_theme_font_size_override("font_size", size)
	lab.add_theme_color_override("font_color", WELL_INK)
	# A one-pixel dark seat, not a four-pixel ring: enough to hold the
	# letters off a busy ground, invisible as an edge.
	lab.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.65))
	lab.add_theme_constant_override("shadow_offset_x", 1)
	lab.add_theme_constant_override("shadow_offset_y", 1)
	lab.add_theme_constant_override("outline_size", 0)
	var body: Font = GameSkin.font("font_body")
	if body != null:
		if heavy:
			var thick := FontVariation.new()
			thick.base_font = body
			thick.variation_embolden = 0.05
			lab.add_theme_font_override("font", thick)
		else:
			lab.add_theme_font_override("font", body)
	return lab


## A line in the era's voice, cleared after a few seconds — the duel
## screen's warningMsg treatment, on the builder's own header.
func _say(text: String, warning := false) -> void:
	_status_label.text = text.replace("\n", "  ")
	# PALE ON THE WELL. This line was lettered in dark ink, the way the
	# original letters its light-faced buttons, from when the strip WAS a
	# light face; the strip became a dark inset on 2026-09-05 and the
	# owner asked for white on it, which [method _well_label] gave the
	# count line — but every message written here put the ink back, so
	# "Added 4 Lightning Bolt" was near-black on near-black (caught by
	# screenshotting it, 2026-09-06). The voice is the well's own pale
	# now, and a warning is a light warm red that reads on the dark ground
	# rather than the deep red that read on the pale one.
	_status_label.add_theme_color_override("font_color",
		WELL_WARNING if warning else WELL_INK)
	_status_timer = 4.0


func _process(delta: float) -> void:
	if _status_timer > 0.0:
		_status_timer -= delta
		if _status_timer <= 0.0:
			_status_label.text = ""


# -------------------------------------------------------- the mini-menu --

func _run_command(label: String) -> void:
	# `Button.wav`, the 1997 deck surface's own slot 4 — every command
	# arrives here, from the bar and from both menus, so this is the one
	# place a button cue belongs.
	_audio.play(DeckAudio.CUE_BUTTON)
	match label:
		"New deck": _new_deck()
		"Load deck": _open_load_dialog()
		"Save deck": _save_deck()
		"Consolidate duplicate cards": _toggle_consolidate()
		"Clear deck": _clear_deck()
		"Restore deck": _restore_deck()
		"Sort deck": _sort_deck()
		"Stats": _open_stats()
		"Music", "Sound Effects": _toggle_sound_setting(label)
		"Exit deck builder": _exit()
		"Extra Cards": _open_extra_cards()
		"Move by color out of deck": _open_group_move()
		"Filters": _filter_bar.open_all_menu()
		"Undo": _undo_last()
		"Add basic land": _open_land_dialog()
		"Add proxy card": _open_proxy_dialog()
		"Copy deck to": _open_copy_dialog()
		"Deck notes": _open_notes_dialog()
		"Sideboard": _open_sideboard_dialog()
		"Import deck": _open_import_dialog()
		"Export deck": _open_export_dialog()


# ------------------------------------------------- [QoL] the deck slots --

## Put the deck in this slot on the surface. Nothing is saved and nothing
## is prompted for: the deck you leave stays in its slot, in memory, ready
## to come back to — that is what makes this cheaper than save-and-load and
## therefore worth having. `Save deck` still writes the file.
func _switch_slot(index: int) -> void:
	if index == _slot or index >= _slots.size():
		return
	_slots[_slot] = deck
	_slot_dirty[_slot] = _dirty
	_slot = index
	deck = _slots[index]
	_dirty = _slot_dirty[index]
	_side_signature = "-"
	# The undo and the cleared deck belong to the deck that was on the
	# surface, not to this one.
	_cleared = null
	_undo = null
	_sorted = false
	_clear_button.text = "Clear deck"
	refresh()
	_say("Deck%d — %s" % [index + 1, deck.deck_name])


## Point the surface at a different model, keeping the slot in step. Every
## command that REPLACES the deck (New, Load, Restore) goes through this,
## or the slot would still hold the model the screen has stopped showing.
func _set_deck(model: DeckModel) -> void:
	deck = model
	_slots[_slot] = model
	# The strip's cheap-redraw guard compares CONTENTS, and two different
	# decks can hold the same sideboard, so nothing here needs forcing —
	# but a slot switch DOES need it, because `_sideboard_area` may be
	# showing a pile the new model happens to match by signature only
	# after the entries were built from the old one. Cheapest correct
	# answer: forget what the strip is showing whenever the model changes.
	_side_signature = "-"


## [QoL] `Copy deck to…` — FORK the deck on the surface into another slot.
##
## The slots were shipped for *"trying a variant"* and only half did it:
## you could hold three decks at once but not start the second one from
## the first, so a variant meant building forty cards again or a save, a
## load and a rename. One copy, and Deck2 is the deck you were just
## looking at, with `(copy)` on its title so `Save deck` cannot overwrite
## the original by accident.
func _open_copy_dialog() -> void:
	if _dialog_busy():
		return
	if deck.total() + deck.side_total() == 0:
		_say("There is nothing to copy", true)
		return
	var dialog := OriginalDialog.create("Copy deck to", Vector2(400, 260))
	dialog.body().add_child(OriginalDialog.label(
		"Put a copy of %s in which deck?" % deck.deck_name, 14))
	for i in SLOTS:
		if i == _slot:
			continue
		var target := i
		# `@DECKNUMBERS`' own names for the slots.
		var line := _menu_line("Deck%d%s" % [i + 1,
			"" if _slots[i].total() == 0 else "  (holds %d cards)" % _slots[i].total()])
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			_copy_deck_to(target))
		dialog.body().add_child(line)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


func _copy_deck_to(index: int) -> void:
	var copy := deck.duplicate_model()
	copy.deck_name = "%s (copy)" % deck.deck_name
	_slots[index] = copy
	_slot_dirty[index] = true
	refresh()
	_say("Copied to Deck%d as %s" % [index + 1, copy.deck_name])


# ------------------------------------------------------ [QoL] the undo --

## Keep [param before] — the deck as it was — as the step [param what]
## can be undone to. Taken by every mutation, and KEPT ONLY WHEN THE
## MUTATION SUCCEEDED: the second audit pass (2026-08-31) found that a
## refused change (a fifth copy in a full deck, a Remove with nothing to
## remove) snapshotted the deck anyway and so quietly ate the step the
## player actually wanted back. One Dictionary copy of at most 200 keys.
func _remember(before: DeckModel, what: String) -> void:
	_undo = before
	_undo_label = what


## `Undo` — put back what the last change took away. Deliberately ONE step:
## the gesture this exists for is a mistaken right-click that emptied a
## column, and "put that back" is the whole of what a builder wants.
## (A deeper history is a written proposal in docs/ROADMAP.md; the toggle
## below is what the screenshot pass chose and it is pinned by a test.)
func _undo_last() -> void:
	if _undo == null:
		_say("There is nothing to undo", true)
		return
	var undone := _undo_label
	var redo := deck.duplicate_model()
	_set_deck(_undo)
	_undo = redo
	_undo_label = "Undo"
	_dirty = true
	# `_sorted` is NOT touched: `Sort deck` is the DISPLAY's order and undo
	# is about the deck's contents. Resetting it threw the area back into
	# insertion order on every undo and made `Sort deck` a click you had to
	# repeat (third audit pass, 2026-09-01).
	refresh()
	_say("Undone: %s" % undone if undone != "" else "Undone")


## [QoL] What the mini-menu writes on the `Undo` line — the change that
## will come back, not just the word. `_undo_label` was recorded by every
## mutation and then read by nothing at all until this pass.
func _undo_menu_label() -> String:
	if _undo == null:
		return "Undo"
	return "Undo" if _undo_label in ["", "Undo"] else "Undo %s" % _undo_label


# ------------------------------------------- [QoL] add basic land --

## `Add basic land` — the pool's most repeated action, and the one the
## screen made most expensive. A 40-card deck wants seventeen or so basic
## lands; every one of them was a separate click on the Inventory, after
## a filter or a search to find the land in the first place. This asks for
## a colour and a number once.
##
## It is not 1997, but it is not foreign to it either: Shandalar itself
## adds basic lands to an under-sized deck (manual ch.10 — *"the Shandalar
## Dueling Commission temporarily adds random basic lands"*), and the
## duplicate rule the same chapter states exempts basics precisely because
## a deck is expected to be full of them.
const BASIC_LANDS: Array = [
	["Plains", Mtg.ManaColor.W], ["Island", Mtg.ManaColor.U],
	["Swamp", Mtg.ManaColor.B], ["Mountain", Mtg.ManaColor.R],
	["Forest", Mtg.ManaColor.G],
]


func _open_land_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Add basic land", Vector2(400, 320))
	dialog.body().add_child(OriginalDialog.label(
		"How many, and of which land?", 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(OriginalDialog.label("Number", 14))
	# `OriginalDialog.field` — the era's sunken box. A bare SpinBox put a
	# modern widget in the middle of a 1997 dialog.
	var spin := OriginalDialog.field(80.0)
	spin.min_value = 1
	spin.max_value = 40
	spin.value = 4
	row.add_child(spin)
	dialog.body().add_child(row)
	for entry in BASIC_LANDS:
		var card_name := String(entry[0])
		if not CardRegistry.has_card(card_name):
			continue
		var line := _menu_line(card_name)
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			_add_basic_land(card_name, int(spin.value)))
		dialog.body().add_child(line)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


func _add_basic_land(card_name: String, wanted: int) -> void:
	var before := deck.duplicate_model()
	var added := 0
	var refusal := ""
	for _i in wanted:
		refusal = deck.add(card_name)
		if refusal != "":
			break
		added += 1
	if added == 0:
		_say(refusal, true)
		return
	_remember(before, "Add %d %s" % [added, card_name])
	_dirty = true
	refresh()
	_say("Added %d %s" % [added, card_name])


# ------------------------------------------ the two recovered 1997 commands --

## `@EXTRACARDSDIALOG` (`s30/assets/text/Menus.txt:36-40`), all four of its
## lines: *"Extra Cards"*, *"There are too many of the following Cards in
## your deck."*, and its two buttons — *"Remove Extra Cards"* and *"Edit
## Deck"*.
##
## This is the one mistake the screen could REPORT and not repair. The
## legality line has always said the sentence; the 1997 dialog is what
## acts on it, and cutting eleven stacks back to the Shandalar allowance by
## hand — find the card, right-click it out, put the allowance back — is
## the most tedious thing this screen can ask of a player. It is one undo
## step, like every other bulk change here.
##
## The limit is SHANDALAR's, scaled by deck size (DeckModel.DUPLICATE_TABLE),
## so this is advice the player asked for and never a refusal: the Deck
## Builder itself allows any number.
func _open_extra_cards() -> void:
	if _dialog_busy():
		return
	var over := deck.over_duplicate_limit()
	var dialog := OriginalDialog.create("Extra Cards",
		Vector2(520, 200.0 + 24.0 * mini(over.size(), 8)))
	if over.is_empty():
		dialog.body().add_child(OriginalDialog.label(
			"No card is over the Shandalar limit for a deck this size.", 14))
		dialog.add_button("OK").pressed.connect(dialog.dismiss)
		_show_dialog(dialog)
		return
	dialog.body().add_child(OriginalDialog.label(
		"There are too many of the following Cards in your deck.", 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(460, mini(over.size(), 8) * 24)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for line in over:
		column.add_child(OriginalDialog.label(line, 13))
	scroll.add_child(column)
	dialog.body().add_child(scroll)
	dialog.add_button("Remove Extra Cards").pressed.connect(func() -> void:
		dialog.dismiss()
		_trim_duplicates())
	dialog.add_button("Edit Deck").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


func _trim_duplicates() -> void:
	var before := deck.duplicate_model()
	var removed := deck.trim_duplicates()
	if removed == 0:
		_say("There are no extra cards", true)
		return
	_remember(before, "Remove Extra Cards")
	_dirty = true
	refresh()
	_say("Removed %d extra card%s" % [removed, "" if removed == 1 else "s"])


## `Move by color o&ut of deck` (`@DECKSURFACE_ADVENTURE`, Menus.txt:197)
## through `@GROUPMOVE`'s own picker (:25-32) — *"Select Which Color(s) to
## Move"*, and its six entries in its own order: Black, Blue, Green, Red,
## White, Artifact. They tick INDEPENDENTLY, because "move black and blue
## out" is one gesture in the original and two here otherwise.
##
## Recolouring a deck is what this is for, and doing it by hand means
## finding every card of a colour in a deck area that pages. `Artifact` is
## `@GROUPMOVE`'s own sixth entry and means the colourless cards.
const GROUP_MOVE: Array = [
	["Black", Mtg.ManaColor.B], ["Blue", Mtg.ManaColor.U],
	["Green", Mtg.ManaColor.G], ["Red", Mtg.ManaColor.R],
	["White", Mtg.ManaColor.W], ["Artifact", 0],
]


func _open_group_move() -> void:
	if _dialog_busy():
		return
	var picked := {}
	var dialog := OriginalDialog.create("", Vector2(420, 400))
	dialog.body().add_child(OriginalDialog.label(
		"Select Which Color(s) to Move", 15))
	var lines: Array[Button] = []
	for entry in GROUP_MOVE:
		var color := int(entry[1])
		var label := String(entry[0])
		var line := _menu_line("[  ] " + label)
		line.pressed.connect(func() -> void:
			picked[color] = not bool(picked.get(color, false))
			line.text = ("[x] " if picked[color] else "[  ] ") + label)
		lines.append(line)
		dialog.body().add_child(line)
	dialog.add_button("OK").pressed.connect(func() -> void:
		dialog.dismiss()
		var colors: Array = []
		for color in picked:
			if picked[color]:
				colors.append(color)
		_move_out_by_color(colors))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


func _move_out_by_color(colors: Array) -> void:
	if colors.is_empty():
		_say("No colors were selected", true)
		return
	var before := deck.duplicate_model()
	var removed := deck.remove_by_color(colors)
	if removed == 0:
		_say("There are no such cards in this deck", true)
		return
	_remember(before, "Move by color out of deck")
	_dirty = true
	refresh()
	_say("Moved %d card%s out of the deck" % [removed, "" if removed == 1 else "s"])


# ------------------------------------------------ [QoL] notes and export --

## `Deck notes` — the free text saved with the deck (DeckModel.notes). The
## 1997 `@TITLEDIALOG` collected a Comments field beside the Title, so the
## idea is the era's; the file format that carries it is ours, and it
## carries it as `# note:` comment lines so that a deck with notes still
## loads everywhere a deck without them did.
func _open_notes_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Deck notes", Vector2(520, 400))
	dialog.body().add_child(OriginalDialog.label(
		"Why these cards, what it fears, what to swap:", 14))
	var edit := TextEdit.new()
	edit.text = deck.notes
	edit.custom_minimum_size = Vector2(460, 220)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_BOUNDARY
	edit.add_theme_stylebox_override("normal",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_stylebox_override("focus",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
	dialog.body().add_child(edit)
	dialog.add_button("OK").pressed.connect(func() -> void:
		if edit.text.strip_edges() != deck.notes:
			deck.notes = edit.text.strip_edges()
			_dirty = true
		dialog.dismiss()
		_say("Deck notes kept — they save with the deck"))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)
	edit.grab_focus()


## [QoL] `Sideboard` — the strip's own menu. It exists for two reasons and
## the first is DISCOVERABILITY: shift-click is not a 1997 gesture and a
## gesture a player cannot find is a gesture they do not have, so the one
## place this screen lists its commands says what the strip is and how to
## fill it. The second is the two bulk moves, which are fifteen clicks
## each by hand and one undo step here.
##
## The size rule is stated HERE as well as on the legality line, in the
## same words and with the same disclaimer — [constant
## DeckModel.SIDEBOARD_SIZE] is modern Magic's number, not the 1997
## game's, and this screen never pretends otherwise.
func _open_sideboard_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Sideboard", Vector2(540, 340))
	var count := OriginalDialog.label(
		"%d cards in the sideboard." % deck.side_total(), 15)
	dialog.body().add_child(count)
	var how := OriginalDialog.label(
		"Shift-click a card to send one copy across — from the Inventory or"
		+ " the deck into the sideboard, from the sideboard into the deck."
		+ " Dragging between the three areas does the same.", 13)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 480
	dialog.body().add_child(how)
	var rule := OriginalDialog.label(
		"Fifteen cards is the usual size. That number is modern Magic's"
		+ " convention, not a 1997 rule — the original's Deck Builder had"
		+ " no sideboard at all — so it is advice here and never a refusal.",
		12)
	rule.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rule.custom_minimum_size.x = 480
	dialog.body().add_child(rule)
	var into_deck := _menu_line("Move the whole sideboard into the deck")
	into_deck.pressed.connect(func() -> void:
		dialog.dismiss()
		_sideboard_bulk(true))
	dialog.body().add_child(into_deck)
	var empty := _menu_line("Empty the sideboard")
	empty.pressed.connect(func() -> void:
		dialog.dismiss()
		_sideboard_bulk(false))
	dialog.body().add_child(empty)
	dialog.add_button("Done").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## Both bulk moves, in one undo step. [param into_deck] false empties the
## pile instead of moving it across.
func _sideboard_bulk(into_deck: bool) -> void:
	if deck.side_total() == 0:
		_say("The sideboard is empty", true)
		return
	var before := deck.duplicate_model()
	var moved := 0
	var refusal := ""
	for card_name in deck.side_names():
		for _i in deck.side_count_of(card_name):
			refusal = deck.to_deck(card_name) if into_deck \
				else deck.remove_side(card_name)
			if refusal != "":
				break
			moved += 1
		if refusal != "":
			break
	if moved == 0:
		_say(refusal, true)
		return
	_remember(before, "Move the sideboard into the deck" if into_deck
		else "Empty the sideboard")
	_dirty = true
	refresh()
	_say("%d card%s %s" % [moved, "" if moved == 1 else "s",
		"moved into the deck" if into_deck else "taken out of the sideboard"])
	if refusal != "":
		_say(refusal, true)


## `Export deck` — the two formats a deck is worth sending somewhere else
## in (DeckStore.EXPORT_FORMATS says which and why), offered through the
## same mini-menu shape every other list on this screen uses.
func _open_export_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Export deck", Vector2(520, 240))
	dialog.body().add_child(OriginalDialog.label(
		"Write %s to user://decks/export as:" % deck.deck_name, 14))
	for entry in DeckStore.EXPORT_FORMATS:
		var line := _menu_line(String(entry[0]))
		var extension := String(entry[1])
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			_export_deck(extension))
		dialog.body().add_child(line)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


func _export_deck(extension: String) -> void:
	var written: Array = []
	var refusal := DeckStore.export_deck(deck, extension, written)
	if refusal != "":
		_say(refusal, true)
		return
	_say(DeckStore.EXPORTED % String(written[0]).get_file())


# ------------------------------------------------------- [QoL] import --
# `Import deck` is the other end of the `Export deck` road: a deck from
# ANYWHERE, in any of the three formats [DeckList] reads, with every name
# this game does not implement becoming a PROXY instead of an error.
#
# BOTH DOORS ARE OFFERED, and the reason is that a decklist travels two
# genuinely different ways:
#
#   From a file…      the deck the player POINTS AT — a `.dck` out of a
#                     real 1997 install's Decks folder, a `.dec` another
#                     program exported, a `.deck` a friend sent. It is the
#                     only door that reaches a path outside this game's
#                     two deck directories, and routing by EXTENSION is
#                     free there, which is how `.dck` finds the MicroProse
#                     parser without anyone being asked which format they
#                     have.
#   Paste a decklist… how a decklist actually moves TODAY: out of a forum
#                     post, a Discord message, or another site's export
#                     box, as text with no file anywhere in the story.
#                     There is no extension to route on, so the format is
#                     SNIFFED ([method DeckStore.looks_like_dck]).
#
# Neither is a superset of the other, both are two dozen lines, and both
# end in the same [method _take_import] — one code path from the fold
# onwards, exactly like the two ways of getting a proxy.

## `FileDialog` is Godot's, not the era's, and this is the one place this
## screen shows a control it did not draw. The alternative was to build a
## 1997-styled directory browser, which is a filesystem widget's worth of
## work to reach a file the player already knows the path of — and the
## paste box beside it is the door most players will actually use.
## ASKS FIRST, like `Load deck`. An import REPLACES the deck on the
## surface ([method _take_import]) and this door walked straight into that
## — `@SAVE` never came up, so an hour's unsaved building was gone the
## moment a file was picked. `Load deck` has asked since the second audit
## pass and *"From disk…"* inherits it by going through the load dialog;
## this was the one door left, noted in `docs/ROADMAP.md` ("Left open by
## this pass") and fixed here because the same pass owns every other door
## that can lose a deck.
func _open_import_dialog() -> void:
	_confirm_discard(_show_import_dialog)


func _show_import_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Import deck", Vector2(520, 300))
	var how := OriginalDialog.label(
		"Read a deck in any format this game knows — .deck, .dec, or the"
		+ " original's .dck. A card this game does not implement becomes a"
		+ " proxy: you can see the deck and build with it, but not duel"
		+ " with it.", 13)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 460
	dialog.body().add_child(how)
	var from_file := _menu_line("From a file…")
	from_file.pressed.connect(func() -> void:
		dialog.dismiss()
		_open_import_file_browser())
	dialog.body().add_child(from_file)
	var paste := _menu_line("Paste a decklist…")
	paste.pressed.connect(func() -> void:
		dialog.dismiss()
		_open_paste_dialog())
	dialog.body().add_child(paste)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## The file half. `ACCESS_FILESYSTEM` because the whole point is a file
## OUTSIDE `res://decks` and `user://decks` — `Load deck` already lists
## those two.
func _open_import_file_browser() -> void:
	_open_deck_file_browser("Import deck", _import_file)


## THE ONE FILE BROWSER, for both doors that reach outside this game's own
## two deck folders: `Import deck`'s *"From a file…"* and `Load Deck`'s
## *"From disk…"*. They differ only in what they do with the path, so they
## differ only in [param then].
##
## `FileDialog` is Godot's, not the era's, and this is the one place this
## screen shows a control it did not draw. The alternative was to build a
## 1997-styled directory browser, which is a filesystem widget's worth of
## work to reach a file the player already knows the path of.
func _open_deck_file_browser(title: String, then: Callable) -> void:
	var picker := FileDialog.new()
	picker.name = "DeckFileBrowser"
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.title = title
	picker.use_native_dialog = false
	for entry in DeckStore.IMPORT_FILTERS:
		picker.add_filter(String(entry).split(" ; ")[0],
			String(entry).split(" ; ")[1])
	picker.size = Vector2i(640, 460)
	# Modal like every other dialog on this screen — [method _dialog_busy]
	# only sees [OriginalDialog]s, and this is the one control that is not
	# one, so it enforces its own.
	picker.exclusive = true
	picker.file_selected.connect(func(path: String) -> void:
		then.call(path)
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	add_child(picker)
	picker.popup_centered()


func _import_file(path: String) -> void:
	var report: Array = []
	var imported := DeckStore.import_file(path, report)
	if imported == null:
		_refuse_file(path, report)
		return
	# A deck file's own `name:` header wins, and a file that has none is
	# named after itself — the same fallback [method DeckList.load_file]
	# already applies, which is why nothing is done here for it.
	_take_import(imported, report)


## The paste half — a text box in the era's own chrome, the same shape
## `Deck notes` uses. `Import` reads whatever is in it.
func _open_paste_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Paste a decklist", Vector2(560, 460))
	var how := OriginalDialog.label(
		"Paste a decklist — `4 Lightning Bolt` lines, with `SB:` for the"
		+ " sideboard and `// NAME :` or `name:` for the title. The 1997"
		+ " .dck format is read too.", 13)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 500
	dialog.body().add_child(how)
	var edit := TextEdit.new()
	edit.custom_minimum_size = Vector2(500, 260)
	edit.wrap_mode = TextEdit.LINE_WRAPPING_NONE
	edit.add_theme_stylebox_override("normal",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_stylebox_override("focus",
		OriginalDialog.panel_style("panel_dark_stone", 6.0))
	edit.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
	dialog.body().add_child(edit)
	dialog.add_button("Import").pressed.connect(func() -> void:
		dialog.dismiss()
		_import_pasted(edit.text))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)
	edit.grab_focus()


func _import_pasted(text: String) -> void:
	if text.strip_edges() == "":
		_say("There is nothing to import", true)
		return
	var report: Array = []
	var imported := DeckStore.import_text(text, DeckModel.DEFAULT_NAME, report)
	if imported == null:
		_say(String(report[0]) if not report.is_empty()
			else DeckStore.PASTE_ERROR, true)
		return
	_take_import(imported, report)


## PUT AN IMPORTED DECK ON THE SURFACE. Shared by both doors, and it is
## the same landing [method _load_deck] makes: the slot follows the model
## ([method _set_deck]), the undo and the cleared deck belong to the deck
## that has just left, and nothing is written to disk — an import is a
## deck on the surface until `Save deck` says otherwise, which is what
## keeps `user://decks` the player's own and not a scrapbook of every file
## they have looked at.
##
## `_dirty` is TRUE, unlike a load: an imported deck has no file of ours
## behind it, so leaving without saving really would lose it, and `@SAVE`
## must ask.
func _take_import(model: DeckModel, report: Array) -> void:
	_set_deck(model)
	_cleared = null
	_undo = null
	_sorted = false
	_dirty = true
	_clear_button.text = "Clear deck"
	refresh()
	var line := "%s imported (%d cards)" % [deck.deck_name, deck.total()]
	if report.is_empty():
		_say(line)
	else:
		_say("%s — %s" % [line, String(report[0])], true)


# -------------------------------------------- [QoL] the deliberate proxy --

## `Add proxy card` — a stand-in for a card the player MEANS to have,
## typed rather than imported. The same object either way: this is
## [method DeckModel.add_proxy], and so is the importer's fold
## ([method DeckStore._fold]) — one dictionary entry, one count, one code
## path, which is the whole reason a proxy is defined as *a name the
## registry does not know* rather than as a flag somebody has to set.
##
## It REFUSES A NAME THE POOL ALREADY HAS, and that refusal is the point:
## if the card is implemented there is nothing to stand in for, and adding
## the real card is both what the player wants and one click away in the
## Inventory. Saying so is more useful than silently adding it.
func _open_proxy_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Add proxy card", Vector2(480, 340))
	var how := OriginalDialog.label(
		"A proxy is a paper stand-in for a card this game does not"
		+ " implement — the name on plain card stock, with `proxy` where"
		+ " the rules text goes. A deck holding one can be built, saved and"
		+ " looked at, but not duelled with.", 13)
	how.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	how.custom_minimum_size.x = 420
	dialog.body().add_child(how)
	dialog.body().add_child(OriginalDialog.label("Card name", 14))
	var edit := LineEdit.new()
	edit.custom_minimum_size = Vector2(420, 28)
	edit.placeholder_text = "Shivan Dragon"
	dialog.body().add_child(edit)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(OriginalDialog.label("Number", 14))
	var spin := OriginalDialog.field(80.0)
	spin.min_value = 1
	spin.max_value = 40
	spin.value = 1
	row.add_child(spin)
	dialog.body().add_child(row)
	dialog.add_button("OK").pressed.connect(func() -> void:
		dialog.dismiss()
		_add_proxy(edit.text.strip_edges(), int(spin.value)))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)
	edit.grab_focus()


## [param wanted] copies of one proxy, in ONE undo step — the shape every
## bulk change on this screen has ([method _add_basic_land] is the model).
func _add_proxy(card_name: String, wanted: int) -> void:
	if card_name == "":
		_say("A proxy needs a name", true)
		return
	if CardRegistry.has_card(card_name):
		_say("%s is in the card pool — add the card itself" % card_name, true)
		return
	var before := deck.duplicate_model()
	var added := 0
	var refusal := ""
	for _i in wanted:
		refusal = deck.add_proxy(card_name)
		if refusal != "":
			break
		added += 1
	if added == 0:
		_say(refusal, true)
		return
	_remember(before, "Add %d %s (proxy)" % [added, card_name])
	_dirty = true
	refresh()
	_say("Added %d %s — %s" % [added, card_name, ProxyCard.RULES_TEXT])


## Every dialog currently on the screen, front-most last.
func open_dialogs() -> Array[OriginalDialog]:
	var out: Array[OriginalDialog] = []
	for child in get_children():
		if child is OriginalDialog and not child.is_queued_for_deletion():
			out.append(child)
	return out


## Is a dialog already up? Every opener asks first — a 1997 dialog is
## modal, and two of them on screen at once is not a state the original
## could reach. Some openers checked and some did not, so a second click
## on `Stats`, on the Deck Header or on `Load deck` stacked a second copy.
func _dialog_busy() -> bool:
	return not open_dialogs().is_empty()


## PUT A DIALOG UP, MODALLY. [OriginalDialog] is a panel and nothing more —
## it draws no blocker — so before this every click that MISSED the panel
## went straight through to whatever was under it: with the Stats window
## open you could still right-click a column out of the deck, and with the
## save prompt up you could still edit the deck it was asking about. The
## scrim is a full-screen [Control] that swallows those clicks, added just
## under the dialog and freed with it.
##
## It is not a dim overlay: the 1997 dialogs do not darken the screen
## behind them, and a Control with no drawing of its own is invisible.
## [param blocker_z] is the scrim's layer, one under the dialog's own. It
## is a parameter for exactly one caller: the Q/Esc menu opens OVER
## whatever was already on screen ([method _open_deck_menu]), so its
## blocker has to sit over that dialog and not under it.
func _show_dialog(dialog: OriginalDialog, blocker_z := 199) -> void:
	var scrim := Control.new()
	scrim.name = "DialogScrim"
	scrim.set_anchors_preset(Control.PRESET_FULL_RECT)
	scrim.mouse_filter = Control.MOUSE_FILTER_STOP
	scrim.z_index = blocker_z
	add_child(scrim)
	add_child(dialog)
	dialog.tree_exited.connect(func() -> void:
		if is_instance_valid(scrim):
			scrim.queue_free())


## The same commands as a right-click mini-menu on the deck surface —
## `docs/glossary-1997.md` fixes "mini-menu" as the original's word for
## a right-click context menu. One at a time: a mini-menu is modal in
## spirit, and rapid right-clicks used to stack them.
func _open_mini_menu() -> void:
	if _dialog_busy():
		return
	# `panel_dark_stone`, not the knot: a list of choices in CHOICE colour
	# reads as grey on grey over the knot pattern, which a screenshot pass
	# caught. The knot stays where it belongs, on the duel's card popup.
	# The height follows the list rather than being a number: the menu grew
	# from twelve entries to fourteen and a fixed 430 put `Export deck`
	# under the Cancel button.
	# 24 for the line, 8 for the VBox's separation, and 72 for the margins,
	# the Cancel button and the gap above it — measured, because a fixed
	# 430 put the last two entries under the button when the menu grew.
	var labels := _command_labels()
	var dialog := OriginalDialog.create("",
		Vector2(380, 72.0 + 32.0 * labels.size()))
	for label in labels:
		var line := _menu_line(_menu_text(label))
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			_run_command(label))
		dialog.body().add_child(line)
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## A filter button's own mini-menu (see [signal FilterBar.menu_requested]),
## with the string table's entries and, when the filter compares against a
## number, the number too.
func _open_filter_menu(request: Dictionary) -> void:
	if _dialog_busy():
		return
	var lines: Array = request["lines"]
	var dialog := OriginalDialog.create(String(request["title"]),
		Vector2(400, 130.0 + 26.0 * lines.size()))
	for i in lines.size():
		var line := _menu_line(String(lines[i]))
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			request["pick"].call(i))
		dialog.body().add_child(line)
	var amount: Callable = request.get("amount", Callable())
	if amount.is_valid():
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 8)
		row.add_child(OriginalDialog.label("Number", 14))
		var spin := OriginalDialog.field(80.0)
		spin.min_value = 0
		spin.max_value = 20
		spin.value = amount.call()
		spin.value_changed.connect(func(value: float) -> void:
			request["set_amount"].call(int(value)))
		row.add_child(spin)
		dialog.body().add_child(row)
		# `Done`, not `Cancel` (`@DIALOGBUTTONS` has all three): the number
		# is applied as it is turned — the Inventory re-lists under the
		# dialog — so a button promising to undo it would be lying.
		dialog.add_button("Done").pressed.connect(dialog.dismiss)
	else:
		dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## A clickable list line for the mini-menu and the Load Deck list. The
## explicit minimum size matters: OriginalDialog.choice_line word-wraps,
## and a wrapping Button whose width nothing constrains reports a minimum
## size of zero — which is how the Load Deck list first shipped empty.
func _menu_line(text: String) -> Button:
	var line := OriginalDialog.choice_line(text)
	line.custom_minimum_size = Vector2(280, 24)
	line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	return line


## The mini-menu's lines: `@DECKSURFACE_STANDALONE` first, the two 1997
## commands from the tags beside it ([constant MENU_COMMANDS]), then this
## screen's own additions marked `[QoL]` so the three are never confused.
func _command_labels() -> Array[String]:
	var out: Array[String] = []
	for label in COMMANDS:
		out.append("Restore deck" if label == "Clear deck" and _cleared != null else label)
	out.append_array(MENU_COMMANDS)
	out.append_array(EXTRA_COMMANDS)
	return out


## What the mini-menu writes on a line — the extras carry their marker in
## the menu itself, never in the command name the tests and `_run_command`
## use. `Undo` also carries WHAT it would undo ([QoL]).
func _menu_text(label: String) -> String:
	if CHECKED_COMMANDS.has(label):
		# A checked menu item, in the convention this screen already uses
		# for `Move by color out of deck`'s colour list.
		return "%s %s" % [
			"[x]" if Settings.get_value(CHECKED_COMMANDS[label], true) else "[  ]",
			label]
	var text := _undo_menu_label() if label == "Undo" else label
	return "%s  [QoL]" % text if EXTRA_COMMANDS.has(label) else text


## `&Music` / `Sound &Effects`. The 1997 home for these two switches, and
## the same [Settings] keys the Options screen shows — never a copy of
## them. Applying to the buses immediately is what makes turning the music
## off here silence the tune that is playing behind this menu.
func _toggle_sound_setting(label: String) -> void:
	var key: String = CHECKED_COMMANDS[label]
	Settings.set_value(key, not bool(Settings.get_value(key, true)))
	GameAudio.apply_settings()
	# ...and the GLOBAL music switch decides this screen's bed too (see
	# [DeckAudio] for the precedence), so turning it back on has to start
	# a tune that was never begun rather than only unmute the bus.
	_apply_music_switch()


## `@SAVE` — *"Do you wish to save %s?"* The manual asks it in exactly the
## place this does: *"If you've created another deck since clearing the
## one you're trying to restore, you're prompted to save the current deck
## before the cleared one is restored."* An untouched deck is thrown away
## without a word.
##
## `Yes` RUNS [param then] ONLY ONCE THE FILE IS WRITTEN, which is the
## second audit pass's correction (2026-08-31) and it was a data-loss bug.
## `Save deck` is not one step: it can stop to ask `@DECKEXISTS` — *"%s
## already exists. Do you wish to over write?"* — or to send the player to
## `Deck Info` for a name. The old code called it and then discarded the
## deck immediately, so the answer "yes, save it" meant the save never
## happened, and confirming the overwrite afterwards wrote whatever deck
## had replaced it. Now a save that does not complete leaves everything
## exactly where it was.
func _confirm_discard(then: Callable) -> void:
	# ONE AT A TIME, like every other opener. This was the one that had no
	# such guard, and the third audit pass (2026-09-01) found it stacking:
	# `Load deck`, `New deck` and `Done` all come through here, and while
	# the prompt is up the scrim under it stops the MOUSE but not the
	# KEYBOARD — a command-bar button that still holds focus answers the
	# space bar and puts a second `@SAVE` on top of the first, each one
	# holding its own continuation.
	if _dialog_busy():
		return
	# `deck.total()` was the whole test until the sideboard existed. A deck
	# that is fifteen sideboard cards and nothing else is still work, and
	# throwing it away without asking would be the same data loss this
	# method exists to prevent.
	if not _dirty or deck.total() + deck.side_total() == 0:
		then.call()
		return
	var dialog := OriginalDialog.create("", Vector2(430, 180))
	dialog.body().add_child(OriginalDialog.label(
		DeckStore.SAVE_QUESTION % deck.deck_name, 15))
	dialog.add_button("Yes").pressed.connect(func() -> void:
		dialog.dismiss()
		_save_deck(then))
	dialog.add_button("No").pressed.connect(func() -> void:
		dialog.dismiss()
		then.call())
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## Which deck SLOTS hold work that has been changed and not saved — the
## one on the surface included. [QoL], and the answer to a [QoL] hole: the
## slots let a player keep three decks in hand, and `Exit deck builder`
## then threw two of them away without a word, because every prompt on
## this screen only ever looked at the deck it could see.
func _unsaved_slots() -> Array[int]:
	var out: Array[int] = []
	for i in _slots.size():
		var model: DeckModel = deck if i == _slot else _slots[i]
		var touched: bool = _dirty if i == _slot else _slot_dirty[i]
		if touched and model.total() + model.side_total() > 0:
			out.append(i)
	return out


## Ask about EVERY slot that has unsaved work, one after another, bringing
## each one onto the surface first so the question is about a deck the
## player can see. [param then] runs when none is left; `Cancel` at any
## point abandons the whole thing and leaves the builder open.
func _confirm_discard_all(then: Callable) -> void:
	var pending := _unsaved_slots()
	if pending.is_empty():
		then.call()
		return
	var index: int = pending[0]
	if index != _slot:
		_switch_slot(index)
	_confirm_discard(func() -> void:
		# Answered — saved or waved off. Either way this slot is settled,
		# or the walk would ask about it again for ever.
		_dirty = false
		_slot_dirty[_slot] = false
		_confirm_discard_all(then))


func _new_deck() -> void:
	_confirm_discard(func() -> void:
		_set_deck(DeckModel.new())
		_sorted = false
		_dirty = false
		_undo = null
		# The cleared deck belonged to the deck that was on the surface —
		# the same reasoning `Load deck` and the slot switch already
		# applied, and the third audit pass (2026-09-01) found this one
		# missing: the mini-menu went on offering `Restore deck` after
		# `New deck`, and pressing it threw the new deck away for one
		# cleared before it existed.
		_cleared = null
		_clear_button.text = "Clear deck"
		refresh()
		_say("New Deck"))


## `C&lear deck` / `&Restore deck` (`@DECKCLEAR_RESTORE`). No save prompt:
## a cleared deck is not a lost deck — that is what Restore is for.
func _clear_deck() -> void:
	if _cleared != null:
		_restore_deck()
		return
	if deck.total() == 0:
		_say("There is nothing to clear", true)
		return
	_cleared = deck.duplicate_model()
	deck.clear()
	_clear_button.text = "Restore deck"
	refresh()
	_say("Deck cleared")


func _restore_deck() -> void:
	if _cleared == null:
		return
	_set_deck(_cleared)
	_cleared = null
	_dirty = true
	_clear_button.text = "Clear deck"
	refresh()
	_say("Deck restored")


## `S&ort deck` — *"rearranges the cards in order by color, putting like
## cards together. Lands are always at the beginning."*
func _sort_deck() -> void:
	_sorted = true
	refresh()
	_say("Deck sorted")


## `&Consolidate duplicate cards` — *"toggles whether multiple copies of
## the same card are displayed separately or grouped together."*
func _toggle_consolidate() -> void:
	_deck_area.consolidated = not _deck_area.consolidated
	# The SIDEBOARD follows it. It is one command about how duplicates are
	# DISPLAYED, and a screen that grouped one pile and split the other
	# would be answering the question twice.
	_sideboard_area.consolidated = _deck_area.consolidated
	refresh()
	_say("Duplicate cards %s" % ("grouped" if _deck_area.consolidated else "shown separately"))


## `E&xit deck builder`. Asks about EVERY slot with unsaved work, not just
## the one on the surface — see [method _unsaved_slots].
func _exit() -> void:
	_confirm_discard_all(func() -> void:
		get_tree().change_scene_to_file("res://game/main.tscn"))


# ------------------------------------------------------------- dialogs --

## `@TITLEDIALOG` (`Menus.txt:47`) — "Deck Info" / "Title". The original's
## dialog also collects Description, Name, E-Mail, Date, Face, Comments
## and Version. Ours asks for the Title here and keeps `Comments` as its
## own `Deck notes` command ([QoL]), because a notes field wants a text
## box and this dialog wants to stay the size the header slab implies.
## [param then] runs only if the dialog really NAMED the deck, which is
## what makes `Save deck` on an untitled deck a command that finishes: it
## sends the player here for a name and the save waits on that name rather
## than being dropped (third audit pass, 2026-09-01 — before it, `@SAVE`'s
## "Yes" on a `New Deck` said "You must name your deck before saving", took
## the name, and then did nothing at all).
## [param reason] is a paragraph shown ABOVE the field when the dialog was
## opened by a refusal rather than by the player — the provenance guard's
## own words ([method DeckStore.shipped_reason]). [param suggested]
## pre-fills the field with a name that will actually work, so the answer
## to *"you must save your version under a new name"* is one keystroke and
## not a puzzle.
func _open_deck_info(then := Callable(), reason := "",
		suggested := "") -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Deck Info",
		Vector2(460, 190.0 if reason == "" else 330.0))
	if reason != "":
		var why := OriginalDialog.label(reason, 13)
		why.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		why.custom_minimum_size.x = 400
		dialog.body().add_child(why)
	dialog.body().add_child(OriginalDialog.label("Title", 14))
	var edit := LineEdit.new()
	edit.text = suggested if suggested != "" else deck.deck_name
	edit.custom_minimum_size = Vector2(360, 28)
	# The era's sunken stone, not a bare Godot field — the same box the
	# Filter strip's type-ahead wears (FilterBar._search_group).
	for state in ["normal", "focus"]:
		edit.add_theme_stylebox_override(state,
			OriginalDialog.panel_style("panel_dark_stone", 5.0))
	edit.add_theme_color_override("font_color", OriginalDialog.CHOICE_LIT)
	dialog.body().add_child(edit)
	dialog.add_button("OK").pressed.connect(func() -> void:
		var wanted := edit.text.strip_edges()
		var named := false
		if wanted == "":
			_say(DeckModel.NAME_YOUR_DECK, true)
		elif wanted != deck.deck_name:
			deck.deck_name = wanted
			_dirty = true
			named = true
		dialog.dismiss()
		refresh()
		if named and then.is_valid():
			then.call())
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)
	edit.grab_focus()
	edit.select_all()


## `@LOADDECKDIALOG` (`Menus.txt:35`) — "Load Deck" / "Player deck:". The
## list is every deck file the project ships plus everything the player
## has saved. Each of the player's own carries a `Delete` — ours, not
## 1997's, where deck files were managed in DOS; a deck the game ships
## refuses, because *"If you load and change one of the creature decks
## used in the full game, you must save your version of the deck under a
## new name."*
func _open_load_dialog() -> void:
	_confirm_discard(_show_load_dialog)


func _show_load_dialog() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Load Deck", Vector2(560, 440))
	dialog.body().add_child(OriginalDialog.label("Player deck:", 14))
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(500, 250)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	dialog.body().add_child(scroll)
	var paths := DeckStore.all_deck_paths()
	if paths.is_empty():
		column.add_child(OriginalDialog.label("(no deck files)", 14))
	# [QoL] Under a heading per provenance group ([DeckGroups.ORDER]), the
	# same headings the battle setup screen's picker uses — the list grew
	# from five files to nearly two hundred with the 2026-09-02 port of the
	# 1997 deck groups (`docs/decks-1997.md`), and a flat list of that
	# many was no longer a list a player could find a deck in.
	var grouped := DeckGroups.grouped(paths)
	for group in grouped:
		column.add_child(OriginalDialog.label(group, 14, true))
		_fill_load_rows(column, dialog, grouped[group])
	# [QoL] THE OTHER HALF OF THE OWNER'S ASK — *"or any other from the
	# disk for that matter"* (2026-09-04). The list above is the decks this
	# game knows; this is every other file on the machine, in any of the
	# three formats [DeckList] reads. It is a button on THIS dialog rather
	# than a fourteenth entry on the mini-menu because "load a deck" is one
	# intention with two places to look, and a player who opened this list
	# and did not find their deck is exactly the player who wants it.
	dialog.add_button("From disk…").pressed.connect(func() -> void:
		dialog.dismiss()
		_open_deck_file_browser("Load Deck", _load_from_disk))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## A DECK FILE FROM ANYWHERE ON THE MACHINE, read the lenient way — the
## same fold `Import deck` uses ([method DeckStore.import_file]), so a
## `.dck` out of a real 1997 install opens here, and a name this game does
## not implement becomes a [ProxyCard] instead of an error.
##
## IT LANDS LIKE AN IMPORT AND NOT LIKE A LOAD, and that is deliberate:
## there is no file of OURS behind it, so `@SAVE` has to ask before the
## deck can be thrown away ([method _take_import]).
func _load_from_disk(path: String) -> void:
	var report: Array = []
	var loaded := DeckStore.import_file(path, report)
	if loaded == null:
		_refuse_file(path, report)
		return
	# A FILE WITH NO CARDS IN IT IS A REFUSAL, not a load. The text parser
	# is lenient by design — a file of comments, or an empty one, is not an
	# ERROR to it — but putting that on the surface would silently replace
	# the deck the player was looking at with nothing at all, which is the
	# one outcome this door must not have. (`Import deck`'s paste box
	# already refuses empty text in the same voice.)
	if loaded.total() + loaded.sideboard.size() == 0:
		_refuse_file(path, [DeckStore.LOAD_ERROR % path.get_file(),
			"There are no cards in it."])
		return
	_take_import(loaded, report)


## SAY WHY, IN A WINDOW. *"Refuse nothing silently — a file that will not
## parse must say why."* The status line under the Showcase is four
## seconds long and three regions away from the file dialog the player was
## just looking at, so a refusal goes in a dialog and carries the parser's
## own reasons under `@DECKLOADERROR`'s sentence, not just the sentence.
func _refuse_file(path: String, report: Array) -> void:
	_say(String(report[0]) if not report.is_empty()
		else DeckStore.LOAD_ERROR % path.get_file(), true)
	if _dialog_busy():
		return
	var lines: Array = report if not report.is_empty() \
		else [DeckStore.LOAD_ERROR % path.get_file()]
	var dialog := OriginalDialog.create("Load Deck",
		Vector2(520, 130.0 + 26.0 * mini(lines.size() + 1, 8)))
	for line in lines:
		var item := OriginalDialog.label(String(line), 13)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.custom_minimum_size.x = 460
		dialog.body().add_child(item)
	var where := OriginalDialog.label(path, 11)
	where.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	where.custom_minimum_size.x = 460
	dialog.body().add_child(where)
	dialog.add_button("OK").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## One clickable line per deck of one group of the Load Deck list, plus a
## `Delete` for each of the player's own.
func _fill_load_rows(column: VBoxContainer, dialog: OriginalDialog,
		paths: Array) -> void:
	for path in paths:
		var row := HBoxContainer.new()
		row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		# [QoL] The deck's OWN title and size, not just its file name. The
		# 1997 list showed eight-character DOS names because that was all a
		# `.dck` had; ours carry a title inside, and a player with a dozen
		# decks should not have to load one to find out which it is.
		var line := _menu_line(DeckStore.describe(path))
		line.pressed.connect(func() -> void:
			dialog.dismiss()
			_load_deck(path))
		row.add_child(line)
		if DeckStore.is_user_deck(path):
			# `OriginalDialog.button`, not `bar_button`: the bar button is
			# the Situation Bar's red-brown Telluser stone and it put a
			# salmon slab on a dark-stone dialog with its letters lost in it.
			var drop := OriginalDialog.button("Delete", Vector2(70, 24))
			drop.size_flags_horizontal = Control.SIZE_SHRINK_END
			drop.pressed.connect(func() -> void:
				var refusal := DeckStore.delete_deck(path)
				dialog.dismiss()
				if refusal != "":
					_say(refusal, true)
				else:
					_say("%s deleted" % path.get_file())
					_show_load_dialog())
			row.add_child(drop)
		column.add_child(row)


func _load_deck(path: String) -> void:
	var report: Array = []
	var loaded := DeckStore.load_deck(path, report)
	if loaded == null:
		_say(String(report[0]) if not report.is_empty() else DeckStore.LOAD_ERROR, true)
		return
	_set_deck(loaded)
	_cleared = null
	_undo = null
	_sorted = false
	_dirty = false
	_clear_button.text = "Clear deck"
	refresh()
	if report.is_empty():
		_say("%s loaded (%d cards)" % [deck.deck_name, deck.total()])
	else:
		_say("%s loaded (%d cards) — %s" % [
			deck.deck_name, deck.total(), String(report[0])], true)


## `&Save deck`, with the original's own three messages: `@NAMEYOURDECK`,
## `@DECKEXISTS` and `@SAVED`.
##
## [param then] runs ONLY IF THE FILE IS ACTUALLY WRITTEN. A save can stop
## twice on the way — for a name and for `@DECKEXISTS` — and every caller
## that goes on to throw the deck away has to wait for both. See
## [method _confirm_discard], where not waiting was a data-loss bug.
func _save_deck(then := Callable()) -> void:
	if deck.deck_name.strip_edges() == "" or deck.deck_name == DeckModel.DEFAULT_NAME:
		_say(DeckModel.NAME_YOUR_DECK, true)
		# ...and go on with the save once it HAS a name. Cancel, or an OK
		# that renamed nothing, leaves everything exactly where it was.
		_open_deck_info(func() -> void: _save_deck(then))
		return
	# PROVENANCE, BEFORE ANYTHING IS WRITTEN. *"Default decks of the game
	# should not be overwritable by the deck builder!"* (owner,
	# 2026-09-04), which is the 1997 manual's own rule at p.148. A save
	# under a shipped deck's name becomes a SAVE-AS rather than a refusal
	# — see [method _save_under_a_new_name] and the provenance block in
	# [DeckStore].
	if DeckStore.is_shipped_name(deck.deck_name):
		_save_under_a_new_name(then)
		return
	if DeckStore.exists(deck.deck_name):
		var file := DeckStore.path_for(deck.deck_name).get_file()
		var dialog := OriginalDialog.create("", Vector2(430, 170))
		dialog.body().add_child(OriginalDialog.label(
			DeckStore.DECK_EXISTS % file, 15))
		dialog.add_button("OK").pressed.connect(func() -> void:
			dialog.dismiss()
			_write_deck(then))
		dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
		_show_dialog(dialog)
		return
	_write_deck(then)


## A SAVE THAT WOULD TAKE A SHIPPED DECK'S NAME, TURNED INTO A SAVE-AS.
##
## *"Saving one has to become a save-as under a new name, with the
## manual's own reason said plainly — not a silent failure and not a
## cryptic refusal."* So all three happen: the status line carries the
## one-line refusal, `Deck Info` opens carrying the manual's sentence and
## the page it is on, and the field is already holding a name that works
## ([method DeckStore.suggest_name]).
##
## It then runs the SAME [method _save_deck] again rather than writing
## directly, which is what keeps `@DECKEXISTS` in front of the new name
## too — *"My Cleric"* may already be one of the player's own decks, and
## that is a different question with a different 1997 answer.
##
## An OK that changes nothing does not save ([method _open_deck_info] only
## calls [param then] when the deck was really renamed), so the one thing
## this cannot do is write the shipped name anyway.
func _save_under_a_new_name(then := Callable()) -> void:
	var name_now := deck.deck_name
	_say(DeckStore.shipped_name_refusal(name_now), true)
	_open_deck_info(func() -> void: _save_deck(then),
		DeckStore.shipped_reason(name_now),
		DeckStore.suggest_name(name_now))


func _write_deck(then := Callable()) -> void:
	var refusal := DeckStore.save(deck)
	if refusal != "":
		_say(refusal, true)
		return
	_dirty = false
	_slot_dirty[_slot] = false
	_say(DeckStore.saved_message(deck))
	if then.is_valid():
		then.call()
	_warn_about_legality()


## [QoL] `@SAVED`, AND THEN WHAT IS WRONG WITH WHAT WAS JUST SAVED — every
## card over the four-of limit, every restricted card past its one copy,
## every banned card, each named ([method DeckModel.format_offences]).
##
## **IT WARNS, IT NEVER REFUSES**, and the ORDER is what guarantees that:
## the file is already on disk before this dialog exists. There is no
## branch here that can stop a save, no `Cancel` to press by accident, and
## no way for a future edit to turn one into a gate. A deck under
## construction is illegal most of the time and a builder that would not
## save half-built work would be broken — the same reasoning
## [method DeckModel.sideboard_advice] is written under, and Shandalar's
## own duplicate allowance before it.
##
## WHY AT SAVE. The legality line has said this in passing for a while, but
## the line is three clipped lines beside a 900-card Inventory and a player
## deep in building does not read it. Save is the moment of consequence —
## the deck has just become a file that the battle-setup screen will offer
## and that the `--format` flag will judge — so it is the one moment worth
## interrupting for. It is also the moment the 1997 program interrupts:
## `@SAVE`, `@DECKEXISTS` and `@DECKSAVEERROR` are all save-time dialogs.
##
## Nothing is shown for a clean deck, which is the common case, so an
## ordinary save is silent apart from `@SAVED` on the status line.
func _warn_about_legality() -> void:
	var offences := deck.format_offences()
	if offences.is_empty() or _dialog_busy():
		return
	# 26 a line (a wrapped one costs its second line out of the slack),
	# plus 150 for the title bar, the two-line footer, the button and the
	# margins — measured off a screenshot rather than guessed, the way the
	# mini-menu's height was. Capped so a deck with thirty offences gets a
	# dialog that still fits the screen; the Stats window lists them all.
	var dialog := OriginalDialog.create("Deck legality",
		Vector2(560, 150.0 + 26.0 * mini(offences.size() + 2, 10)))
	var head := OriginalDialog.label(FORMAT_WARNING % offences.size(), 14)
	head.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	head.custom_minimum_size.x = 500
	dialog.body().add_child(head)
	for line in offences:
		var item := OriginalDialog.label(line, 13)
		item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		item.custom_minimum_size.x = 500
		dialog.body().add_child(item)
	var tail := OriginalDialog.label(
		"The deck is saved either way — this is the deck builder, not a"
		+ " tournament. It is Unrestricted, and the battle-setup screen"
		+ " will refuse it under any of the other four formats.", 12)
	tail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	tail.custom_minimum_size.x = 500
	dialog.body().add_child(tail)
	# ONE button, and it says OK rather than asking anything: there is no
	# question here to answer. `@EXTRACARDSDIALOG` is the 1997 dialog of
	# this shape and it offers `Remove Extra Cards` — deliberately not
	# copied, because cutting a fifth Lightning Bolt is a choice about
	# which card to keep and the dialog cannot make it.
	dialog.add_button("OK").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)


## `Stats (%d cards)` (`@STATS`) — the original's own statistics window.
## `@STATSSCREEN` gives its rows and columns: a Card Type x colour matrix
## with a Total column, a Mana Sources row and a Non-Creature row, plus
## the mana curve s30 draws (`drawDeckStats`).
func _open_stats() -> void:
	if _dialog_busy():
		return
	var dialog := OriginalDialog.create("Stats (%d cards)" % deck.total(),
		Vector2(620, 660))
	# [QoL] PAGES. The 1997 window is one screen of numbers and it answers
	# "what is in here". The owner asked for the other questions —
	# *"chance predictions on one/two/three/four/five/six lands in hand,
	# any specific anti-colour cards, speed"* (2026-09-05) — and they do
	# not fit on that screen, nor should they crowd it: a player opening
	# Stats to check a card count should not have to scroll past a
	# probability table to find it. So the era's page stays FIRST and
	# unchanged, and the new ones sit behind named buttons beside it.
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", 4)
	dialog.body().add_child(tabs)
	var scroll := ScrollContainer.new()
	scroll.custom_minimum_size = Vector2(560, 490)
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var page := VBoxContainer.new()
	page.add_theme_constant_override("separation", 6)
	page.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(page)
	dialog.body().add_child(scroll)
	_stats_pages = page
	for i in STATS_PAGES.size():
		var tab := OriginalDialog.button(String(STATS_PAGES[i]), Vector2(96, 24))
		tab.toggle_mode = true
		tab.button_pressed = i == 0
		tab.pressed.connect(_show_stats_page.bind(i, tabs))
		tabs.add_child(tab)
	_stats_page_deck(page)
	dialog.add_button("OK").pressed.connect(dialog.dismiss)
	_show_dialog(dialog)



## [QoL] PAGE ONE: the era's own window, unchanged. Extracted from
## [method _open_stats] when the pages went in (2026-09-05) and not
## otherwise touched — this is the screen a 1997 player would recognise
## and it stays first and complete.
func _stats_page_deck(page: VBoxContainer) -> void:
	var grid := GridContainer.new()
	grid.columns = DeckModel.STAT_COLUMNS.size() + 2
	grid.add_theme_constant_override("h_separation", 12)
	grid.add_child(OriginalDialog.label("Card Type", 13, true))
	for column in DeckModel.STAT_COLUMNS:
		grid.add_child(_stat_head(String(column[0])))
	grid.add_child(_stat_head("Total"))
	# ONE walk of the deck for all thirty-six cells, not thirty-six walks
	# ([method DeckModel.type_color_matrix] — third audit pass).
	var matrix := deck.type_color_matrix()
	for r in DeckModel.STAT_ROWS.size():
		grid.add_child(OriginalDialog.label(String(DeckModel.STAT_ROWS[r][0]), 13))
		var total := 0
		var line: Array = matrix[r]
		for c in DeckModel.STAT_COLUMNS.size():
			total += int(line[c])
			grid.add_child(_stat_cell(int(line[c])))
		grid.add_child(_stat_cell(total))
	# `Mana Sources` and `Non-Creature`, the two rows that are not types.
	grid.add_child(OriginalDialog.label("Mana Sources", 13))
	var sources := deck.mana_sources()
	var source_total := 0
	for column in DeckModel.STAT_COLUMNS:
		var count := int(sources.get(int(column[1]), 0))
		source_total += count
		grid.add_child(_stat_cell(count))
	grid.add_child(_stat_cell(source_total))
	page.add_child(grid)

	page.add_child(OriginalDialog.label(
		"Non-Creature: %d       Total: %d" % [deck.non_creature_count(), deck.total()], 13))

	# THE DECK TYPE — the one thing the 1997 Stats window showed that this
	# one did not. MicroProse's own ManaLink 1.3 readme (Readme13.txt:
	# 142-144): *"The Deck Builder displays your deck name and deck type
	# (Unrestricted, Wild, Restricted, Tournament or Highlander) in the
	# title bar when you click the Stats button."* Our title bar already
	# carries `Stats (%d cards)`, which is `@STATSDIALOG`'s own wording and
	# is what the owner's screenshot letters on the command-bar button, so
	# the answer goes in the window instead of displacing it. It counts the
	# SIDEBOARD with the deck, because [method DeckFormat.legal] does and a
	# type the setup screen then refuses would be worse than no type.
	page.add_child(OriginalDialog.label("Deck type: %s"
		% deck.deck_type(), 13, true))
	# [QoL] ...AND WHAT KEEPS IT OUT OF THE STRICTER FOUR: every card over
	# the four-of limit, every restricted card past its one copy, every
	# banned card ([method DeckModel.format_offences]). The `Deck type:`
	# line above has said which format a deck IS since the second pass; it
	# has never said WHY, and "Unrestricted" is the catch-all a deck lands
	# in when it has broken something, so the one word most in need of an
	# explanation was the one with none.
	var offences := deck.format_offences()
	if not offences.is_empty():
		var head := OriginalDialog.label(FORMAT_WARNING % offences.size(), 13)
		head.add_theme_color_override("font_color", Color8(232, 176, 96))
		page.add_child(head)
		for line in offences:
			var item := OriginalDialog.label("   " + line, 12)
			item.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			item.custom_minimum_size.x = 500
			item.add_theme_color_override("font_color", Color8(232, 176, 96))
			page.add_child(item)

	# [QoL] THE SIDEBOARD, listed. The strip shows it as cards; this is the
	# written list, beside the numbers it belongs with.
	if deck.side_total() > 0:
		page.add_child(OriginalDialog.label(
			"Sideboard (%d)" % deck.side_total(), 13, true))
		var side_lines := PackedStringArray()
		for card_name in deck.side_names():
			side_lines.append("%d %s" % [deck.side_count_of(card_name), card_name])
		var listed := OriginalDialog.label("   ".join(side_lines), 12)
		listed.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		listed.custom_minimum_size.x = 500
		page.add_child(listed)

	# [QoL] THE GRAPHS. The 1997 window is a matrix of numbers, and a
	# matrix says what is in the deck without saying whether the deck will
	# work. These four are the questions a builder actually asks of a
	# finished list, in the order they ask them: can I cast it (the curve
	# and the average), is the mana right (colours against mana sources),
	# what is it made of (types), and is there enough land.
	page.add_child(OriginalDialog.label("Casting costs", 13, true))
	page.add_child(_curve_row())
	page.add_child(OriginalDialog.label(
		"Average casting cost %.2f  (spells only — a land has no cost)"
		% deck.average_cost(), 12))

	page.add_child(OriginalDialog.label("Colors", 13, true))
	var colors := deck.color_counts()
	var sources_by_color := deck.mana_sources()
	for column in DeckModel.STAT_COLUMNS:
		var color := int(column[1])
		if color == 0:
			continue
		page.add_child(_bar_row(String(column[0]),
			int(colors.get(color, 0)), deck.total(), MANA_BAR.get(color, Color.GRAY),
			"%d mana sources" % int(sources_by_color.get(color, 0))))

	page.add_child(OriginalDialog.label("Card types", 13, true))
	var types := deck.type_counts()
	for row in DeckModel.STAT_ROWS:
		page.add_child(_bar_row(String(row[0]), int(types.get(int(row[1]), 0)),
			deck.total(), Color8(150, 158, 186)))

	page.add_child(OriginalDialog.label("Land", 13, true))
	page.add_child(_bar_row("Land", deck.land_count(), deck.total(),
		Color8(146, 171, 176),
		"%.0f%% of the deck" % (deck.land_ratio() * 100.0)))
	page.add_child(_bar_row("Spells", deck.total() - deck.land_count(),
		deck.total(), Color8(180, 180, 220)))

	# The complaints, in the order the legality line states them — the
	# proxies first, because the strip clips its own text to three lines
	# and this window is where the whole list is meant to be readable.
	var complaints: Array[String] = []
	if deck.proxy_problem() != "":
		complaints.append(deck.proxy_problem())
	complaints.append_array(deck.problems())
	complaints.append_array(deck.sideboard_advice())
	for problem in complaints:
		var warn := OriginalDialog.label(problem, 13)
		warn.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		warn.custom_minimum_size.x = 500
		warn.add_theme_color_override("font_color", Color8(232, 176, 96))
		page.add_child(warn)

## [QoL] The pages the Stats window carries. The first is the era's own
## and is built by [method _open_stats] itself; the rest are this
## project's, and every number on them comes from [DeckStats], which is
## pure and tested so the window stays a view.
const STATS_PAGES: Array[String] = ["Deck", "Draws", "Mana", "Speed", "Matchups"]

## The Stats window's page holder, while it is open.
var _stats_pages: VBoxContainer = null


## Swap to page [param index], and let the tab row show which one it is.
func _show_stats_page(index: int, tabs: HBoxContainer) -> void:
	if _stats_pages == null or not is_instance_valid(_stats_pages):
		return
	for i in tabs.get_child_count():
		var tab := tabs.get_child(i) as Button
		if tab != null:
			tab.set_pressed_no_signal(i == index)
	for child in _stats_pages.get_children():
		child.queue_free()
	match index:
		0: _stats_page_deck(_stats_pages)
		1: _stats_page_draws(_stats_pages)
		2: _stats_page_mana(_stats_pages)
		3: _stats_page_speed(_stats_pages)
		4: _stats_page_matchups(_stats_pages)


## A heading inside a page.
func _stats_head(text: String) -> Label:
	var head := OriginalDialog.label(text, 14, true)
	head.add_theme_color_override("font_color", OriginalDialog.HIGHLIGHT)
	return head


## One `label ....... value` line, which is most of what these pages are.
func _stats_line(text: String, value: String) -> HBoxContainer:
	var row := HBoxContainer.new()
	var left := OriginalDialog.label(text, 13)
	left.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(left)
	row.add_child(OriginalDialog.label(value, 13, true))
	return row


## A percentage, written the way a player reads one.
static func _pct(p: float) -> String:
	return "%.1f%%" % (p * 100.0)



## [QoL] PAGE TWO: the opening hand, exactly.
##
## *"Chance predictions on the one/two/three/four/five/six lands in
## hand"* — the owner's own list, and the reason this page leads with the
## whole row rather than a summary. Every figure is a hypergeometric
## computed in [DeckStats], not a simulation: two builds differing by one
## Forest must differ in the second decimal because the DECK differs, not
## because the dice did.
func _stats_page_draws(page: VBoxContainer) -> void:
	if deck.total() == 0:
		page.add_child(OriginalDialog.label("Add some cards first.", 13))
		return
	page.add_child(_stats_head("Lands in your opening seven"))
	var odds := DeckStats.land_odds(deck)
	for k in odds.size():
		var row := _bar_row("%d land%s" % [k, "" if k == 1 else "s"],
			int(round(odds[k] * 1000.0)), 1000,
			Color8(196, 176, 120) if k >= 2 and k <= 5 else Color8(150, 120, 110),
			_pct(odds[k]), false)
		page.add_child(row)
	page.add_child(_stats_line("Keepable (2-5 lands)",
		_pct(DeckStats.keepable(deck))))
	# The two ways a hand fails, named rather than left as arithmetic.
	page.add_child(_stats_line("   too few (0-1)",
		_pct(odds[0] + odds[1])))
	var flooded := 0.0
	for k in range(6, odds.size()):
		flooded += odds[k]
	page.add_child(_stats_line("   too many (6-7)", _pct(flooded)))

	page.add_child(_stats_head("Making every land drop"))
	page.add_child(OriginalDialog.label(
		"The chance you have seen enough land by that turn.", 12))
	for turn in range(1, DeckStats.HORIZON + 1):
		page.add_child(_stats_line("   by turn %d" % turn,
			"%s on the play,  %s on the draw" % [
				_pct(DeckStats.land_drop_odds(deck, turn, true)),
				_pct(DeckStats.land_drop_odds(deck, turn, false))]))


## [QoL] PAGE THREE: whether the mana can actually cast the deck.
##
## Colour counts say what is in the deck; PIPS say what it asks for, and
## the two come apart badly in a deck whose splash is double-costed.
func _stats_page_mana(page: VBoxContainer) -> void:
	if deck.total() == 0:
		page.add_child(OriginalDialog.label("Add some cards first.", 13))
		return
	var pips := DeckStats.color_pips(deck)
	var sources := deck.mana_sources()
	page.add_child(_stats_head("What the deck asks for, and what it has"))
	page.add_child(OriginalDialog.label(
		"Pips are mana SYMBOLS in costs: {B}{B} asks twice.", 12))
	for column in DeckModel.STAT_COLUMNS:
		var color := int(column[1])
		var pip := int(pips.get(color, 0))
		var src := int(sources.get(color, 0))
		if pip == 0 and src == 0:
			continue
		page.add_child(_stats_line("   %s" % String(column[0]),
			"%d pip%s from %d source%s" % [pip, "" if pip == 1 else "s",
				src, "" if src == 1 else "s"]))

	page.add_child(_stats_head("Having the colour when you need it"))
	for column in DeckModel.STAT_COLUMNS:
		var color := int(column[1])
		if int(pips.get(color, 0)) == 0:
			continue
		var by := PackedStringArray()
		for turn in range(1, 4):
			by.append("T%d %s" % [turn, _pct(DeckStats.color_by_turn(deck, color, turn))])
		page.add_child(_stats_line("   %s" % String(column[0]), "   ".join(by)))

	var worst := DeckStats.hardest_cast(deck)
	if not worst.is_empty():
		page.add_child(_stats_head("The hardest thing to cast"))
		page.add_child(_stats_line("   %s" % String(worst["card"]),
			"%d pips of one colour, mana value %d" % [
				int(worst["pips"]), int(worst["cost"])]))


## [QoL] PAGE FOUR: how fast the deck actually does something.
##
## Creature cost and spell cost are reported APART — they answer "when
## does the board start" and "when can I answer something", and an
## average over both hides both.
func _stats_page_speed(page: VBoxContainer) -> void:
	if deck.total() == 0:
		page.add_child(OriginalDialog.label("Add some cards first.", 13))
		return
	var s := DeckStats.speed(deck)
	# [QoL] RARITY, because in Shandalar a rare is something you have to go
	# and win rather than something you buy. A deck leaning on four of them
	# is a deck you may not be able to build yet, and that is a fact about
	# the deck worth knowing beside its speed.
	var rarity := DeckStats.rarity_counts(deck)
	if not rarity.is_empty():
		page.add_child(_stats_head("Rarity"))
		for key in ["common", "uncommon", "rare", "special", "unknown"]:
			var n := int(rarity.get(key, 0))
			if n > 0:
				page.add_child(_stats_line("   %s" % key, "%d" % n))

	page.add_child(_stats_head("Cost"))
	page.add_child(_stats_line("   average creature", "%.2f" % float(s["creature_cost"])))
	page.add_child(_stats_line("   average other spell", "%.2f" % float(s["spell_cost"])))
	page.add_child(_stats_line("   cheapest creature", "%d" % int(s["cheapest_creature"])))
	page.add_child(_stats_line("   average power", "%.2f" % float(s["average_power"])))

	page.add_child(_stats_head("A creature in hand you can cast"))
	for turn in range(1, DeckStats.HORIZON + 1):
		page.add_child(_stats_line("   by turn %d" % turn,
			_pct(DeckStats.creature_by_turn(deck, turn))))

	var evasive := DeckStats.evasion(deck)
	page.add_child(_stats_head("Creatures a blocker struggles with"))
	if evasive.is_empty():
		page.add_child(OriginalDialog.label(
			"   None — this deck attacks into whatever is there.", 12))
	else:
		for key in evasive:
			page.add_child(_stats_line("   %s" % _evasion_name(key),
				"%d" % int(evasive[key])))


## The player's word for each way past a blocker.
func _evasion_name(key: Variant) -> String:
	if key is String:
		return "landwalk" if key == "landwalk" else "cannot be blocked"
	match int(key):
		Mtg.Keyword.FLYING: return "flying"
		Mtg.Keyword.TRAMPLE: return "trample"
		Mtg.Keyword.FEAR: return "fear"
	return "evasion"


## [QoL] PAGE FIVE: which colours this deck is built to punish.
##
## THE 1997 POOL IS FULL OF COLOUR HATE and the opponents in this game
## have known colours, so "what does this beat" is a real build question
## rather than a curiosity. Read off the oracle text — including the
## cards that name a BASIC LAND rather than a colour, which is how the
## era usually wrote it (Karma says Swamps, not black).
func _stats_page_matchups(page: VBoxContainer) -> void:
	if deck.total() == 0:
		page.add_child(OriginalDialog.label("Add some cards first.", 13))
		return
	var hate := DeckStats.color_hate(deck)
	page.add_child(_stats_head("Cards that name a colour"))
	if hate.is_empty():
		page.add_child(OriginalDialog.label(
			"   None. This deck plays the same against every colour.", 12))
	else:
		# Which colours the deck cares about at all, first — that is the
		# one-line answer, and the list underneath is the evidence.
		var by_color := {}
		for row in hate:
			for color in (row["colors"] as Array):
				by_color[int(color)] = int(by_color.get(int(color), 0)) + int(row["count"])
		var summary := PackedStringArray()
		for column in DeckModel.STAT_COLUMNS:
			var n := int(by_color.get(int(column[1]), 0))
			if n > 0:
				summary.append("%s %d" % [String(column[0]), n])
		page.add_child(_stats_line("   cards aimed at", "   ".join(summary)))
		for row in hate:
			var names := PackedStringArray()
			for color in (row["colors"] as Array):
				for column in DeckModel.STAT_COLUMNS:
					if int(column[1]) == int(color):
						names.append(String(column[0]))
			page.add_child(_stats_line("      %d %s" % [int(row["count"]),
				String(row["card"])], "   ".join(names)))

	var ante := DeckStats.ante_cards(deck)
	if not ante.is_empty():
		page.add_child(_stats_head("Played for the ante"))
		page.add_child(OriginalDialog.label(
			"   Duels here are played for a card; these change what a loss costs.", 12))
		for row in ante:
			page.add_child(_stats_line("      %d %s" % [int(row["count"]),
				String(row["card"])], ""))


## [QoL] The mana palette the bars are drawn in — the duel's own colours
## (game/duel/mana_icons.gd draws the same five), so a graph on this screen
## and a symbol on a card agree about what blue looks like.
const MANA_BAR := {
	Mtg.ManaColor.W: Color8(232, 226, 196),
	Mtg.ManaColor.U: Color8(110, 158, 214),
	Mtg.ManaColor.B: Color8(126, 118, 128),
	Mtg.ManaColor.R: Color8(206, 102, 80),
	Mtg.ManaColor.G: Color8(120, 168, 116),
}


## [QoL] ONE HORIZONTAL BAR: a name, a sunken 1997 track, the bar itself,
## and the number. The track is `OriginalDialog.ruled_style` INVERTED —
## the era's own sunken rule, the same one the search box wears — so a
## graph on this screen is built out of the same furniture as everything
## else and not out of a charting widget.
## [param show_value] draws the raw count beside the bar. The counting
## graphs want it; the PROBABILITY graphs do not, because their "value" is
## a per-mille integer that exists only to size the bar and printing it
## next to the percentage gives the reader two numbers for one fact
## (13 and 1.3%, which invites the question of what 13 counts).
func _bar_row(name: String, value: int, total: int, color: Color,
		note := "", show_value := true) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var caption := OriginalDialog.label(name, 12)
	caption.custom_minimum_size.x = 96
	row.add_child(caption)
	var track := PanelContainer.new()
	track.add_theme_stylebox_override("panel",
		OriginalDialog.panel_style("panel_dark_stone", 2.0))
	track.custom_minimum_size = Vector2(240, 16)
	var fill := ColorRect.new()
	fill.color = color
	fill.custom_minimum_size = Vector2(
		maxf(0.0, 232.0 * value / maxi(total, 1)), 10)
	fill.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	track.add_child(fill)
	row.add_child(track)
	if show_value:
		var number := OriginalDialog.label(str(value), 12)
		number.custom_minimum_size.x = 34
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(number)
	if note != "":
		row.add_child(OriginalDialog.label(note, 11))
	return row


func _stat_head(text: String) -> Label:
	var label := OriginalDialog.label(text, 13, true)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size.x = 58
	return label


func _stat_cell(count: int) -> Label:
	var label := OriginalDialog.label(str(count) if count > 0 else "·", 13)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.custom_minimum_size.x = 58
	return label


## s30's mana-curve histogram, eight buckets, 0 through 7+.
func _curve_row() -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 6)
	var curve := deck.mana_curve()
	var peak := 1
	for count in curve:
		peak = maxi(peak, count)
	for i in curve.size():
		var column := VBoxContainer.new()
		column.alignment = BoxContainer.ALIGNMENT_END
		var number := OriginalDialog.label(str(curve[i]), 11)
		number.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(number)
		var bar := ColorRect.new()
		bar.color = Color8(180, 180, 220)
		bar.custom_minimum_size = Vector2(22, maxf(2.0, 46.0 * curve[i] / peak))
		column.add_child(bar)
		var tick := OriginalDialog.label("7+" if i == 7 else str(i), 11)
		tick.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(tick)
		row.add_child(column)
	return row


# ------------------------------------------- [QoL] the Q/Esc menu --
#
# The owner's playtest, 2026-09-04: *"Upon press of Q or Esc you should be
# presented with a blue slab styled menu with: return to main menu, save
# current deck, open existing deck, exit game"*, and then *"Deck builder
# menu on Q or Esc should turn off if you press Q or Esc again. The menu
# should contain also deck builder SFX and music checkboxes, as a user may
# be annoyed by SFX or music while deck building."*
#
# `[QoL]`, and squarely so: the 1997 Deck Builder has no such window on
# any key. What it has is the deck surface's own right-click mini-menu
# (`@DECKSURFACE_STANDALONE`), which this screen still offers and which
# still holds every 1997 command — this window is a SHORT LIST of the four
# ways out plus the two switches, on a key, for a player whose hands are
# on the keyboard.
#
# IT IS THE DUEL'S PAUSE WINDOW'S SHAPE, deliberately ([DuelPause] on
# [VersusPanel]): a modal slab, the harmless entry first and focused, the
# two keys toggling it, and Esc keeping its 1997 cancel duty ahead of it.
# The GROUND it wears is [constant MENU_PANEL] — see there for the day the
# knot went.
#
# THE KEY CONTRACT, and Esc keeps its own job first. *"Esc is just like
# Cancel"* (manual p.116):
#
#   1. the menu is OPEN               -> Esc (or Q) closes it;
#   2. a dialog or the type-ahead is  -> Esc cancels that ([method
#      pending                           _on_escape]);
#   3. nothing pending                -> Esc opens the menu.
#
# `Q` carries no duty on this screen at all, so it toggles unconditionally
# — including over an open dialog, which is why the window and its blocker
# are given a layer of their own ([method _show_dialog]'s `blocker_z`) and
# why closing it puts the player back where they were.

## The title on the slab. The screen's own name, because this window is
## the screen's menu and the player may have arrived on it by accident.
const MENU_TITLE := "Deck Builder"
## The harmless entry, first and focused — a reflex Return goes back to
## the cards rather than out of the builder ([DuelPause]'s own rule).
const MENU_BACK := "Return to deck builder"
## The owner's four, with [constant MENU_BACK] in front of them.
const MENU_ENTRIES: Array[String] = [
	MENU_BACK,
	"Save current deck",
	"Open existing deck",
	"Return to main menu",
	"Exit game",
]
## The two checkboxes, and the [Settings] key each one writes. NAMED FOR
## THIS SCREEN — they are not the mini-menu's `Music` / `Sound Effects`,
## which are the game-wide 1997 switches ([constant CHECKED_COMMANDS]);
## these silence the Deck Builder and nothing else. See [DeckAudio] for
## which of the two wins when they disagree.
const MENU_SWITCHES := {
	"Deck builder music": DeckAudio.MUSIC_SETTING,
	"Deck builder sound effects": DeckAudio.SFX_SETTING,
}
## Measured off the screenshot, not guessed, the way the mini-menu's height
## is: the heading and the seven lines occupy 240px between the top of the
## title and the bottom of the last box (measured at 1280x800 with the
## original font), plus 10 for the column's separation above the (empty)
## button row and 32 for the margins — 282, in 300. A literal rather than
## arithmetic over the two lists above, because a GDScript `const` may not
## call `size()`; the test that counts the lines against the panel is what
## keeps it honest.
const MENU_SIZE := Vector2(420, 340)

## One entry's box, and one switch's. Both are SHRINK_CENTER inside the
## body, which is what "centered in the GUI window" means for a column
## whose entries are no longer full-width text.
const SLAB_ENTRY := Vector2(268, 30)
## A switch is sized by its CONTENTS, not by the entry width: a tick box
## pinned to the left of a 268-wide control with its label centred reads
## as two unrelated things. Only the height is fixed.
const SLAB_SWITCH := Vector2(0, 26)

## THE GROUND, AND THE DAY THE KNOT WENT.
##
## This window shipped on `panel_knot` — *"a blue slab styled menu"*,
## `Winbk_Changetext.pic`, which the owner named. The agent that built it
## had already found the era's tan list colour illegible on that ground
## and answered by changing the INK: pale letters under a hard dark
## outline. The owner drove it the next day and still could not read it:
## *"Deck builder — window upon Q or Esc key-press: texture makes the text
## unreadable. Change to sand from the main menu!"* (2026-09-04).
##
## SO THE GROUND WAS WRONG, NOT THE INK, and no lettering was going to
## rescue it. A knot is a PATTERN — light and dark inside a single glyph —
## which is the same finding that kept the mini-menu off this ground
## ([method _open_mini_menu]) and which the outline was papering over.
##
## `panel_stone` is the original's `Winbk_Options` sandstone: the face the
## main menu, the Options screen, the Help screen and [method
## UiChrome.explain_popup] all wear, 183/255 mean luminance (PIL,
## 2026-09-03). Its lettering rule is the one this project settled the day
## before this window was built — [constant UiChrome.INK] on the light
## face, [constant UiChrome.ACCENT] for emphasis — and the PALE voice went
## with the pattern, because a pale letter on sandstone is the exact bug
## the first exported build was playtested for (*"all white text is
## unreadable on sand-colored menu boxes"*, `UiChrome`'s class doc).
const MENU_PANEL := "panel_stone"


## A MENU LINE ON SANDSTONE: [constant UiChrome.INK] on its pale seat,
## which is what every other line of text on this ground in the game
## wears, turning [constant UiChrome.ACCENT] under the pointer and under
## the keyboard.
##
## The dark-purple hover is the era's own gesture in this project's
## sandstone voice: the 1997 list lightens its tan line under the pointer
## ([constant OriginalDialog.CHOICE_LIT]), which is a move you can only
## make on a DARK ground. On a light one the line has to go the other way,
## and ACCENT is the colour this project already reserves for "the word a
## sentence turns on".
## THE INK RULE, applied to whatever widget the line is. Split out of
## `_slab_line` when the entries stopped being text (2026-09-04): the
## colours are the panel's, so an entry, a switch and the heading cannot
## drift apart no matter which Control draws them.
func _dress_slab(line: Button) -> Button:
	UiChrome.shadowed_button(line)
	line.add_theme_color_override("font_color", UiChrome.INK)
	for state in ["font_hover_color", "font_focus_color",
			"font_pressed_color", "font_hover_pressed_color"]:
		line.add_theme_color_override(state, UiChrome.ACCENT)
	line.add_theme_font_size_override("font_size", 15)
	line.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	line.custom_minimum_size = SLAB_ENTRY
	line.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	return line


## AN ENTRY IS A BUTTON NOW, in the era's own dialog button art
## (`button_normal/pressed/disabled`, the face every 1997 dialog wears —
## [method OriginalDialog.button]) rather than a line of text that
## happened to be clickable. The owner drove the text version and said
## so: *"only clickable text — make that GUI composed of buttons and of
## switches, more beautiful and centered in the GUI window"* (2026-09-04).
##
## The art is a COOL GREY (mean 166,172,176, measured) on a WARM sandstone
## panel (183), which is why a button reads as a button here without a
## border being invented for it: the two grounds differ in hue, not just
## in value, so the shape survives a player who cannot tell them apart by
## brightness.
func _slab_button(text: String) -> Button:
	return _dress_slab(OriginalDialog.button(text, SLAB_ENTRY))


## A SWITCH IS A TICK BOX, drawn by [method UiChrome.check_icon] because
## the era shipped no checkbox sprite. It is a real [CheckBox], so its
## state lives in `button_pressed` where a screen reader, a test and the
## eye all find the same answer — the `[x]`/`[  ]` text prefix it wore
## until today was a state that only the string knew.
func _slab_switch(label: String) -> CheckBox:
	var box := CheckBox.new()
	box.text = label
	box.button_pressed = bool(Settings.get_value(
		String(MENU_SWITCHES[label]), true))
	box.add_theme_icon_override("checked", UiChrome.check_icon(true))
	box.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
	# The engine theme paints its own hover/pressed plate behind a
	# CheckBox; on sandstone that is a grey smear, and the tick box is
	# the only thing that should be saying "state".
	for state in ["normal", "hover", "pressed", "focus"]:
		box.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_dress_slab(box)
	box.custom_minimum_size = SLAB_SWITCH
	box.add_theme_constant_override("h_separation", 10)
	box.alignment = HORIZONTAL_ALIGNMENT_LEFT
	# PRESSED IS NOT EMPHASIS ON A TOGGLE. `_dress_slab` gives every slab
	# line [constant UiChrome.ACCENT] while it is held, which is right for
	# a button that springs back — but a CheckBox is "pressed" for as long
	# as it is TICKED, so the accent became the resting colour of both
	# labels and only the tick was left saying anything.
	box.add_theme_color_override("font_pressed_color", UiChrome.INK)
	box.add_theme_color_override("font_hover_pressed_color", UiChrome.ACCENT)
	return box


## THE SKINLESS GROUND HAS TO BE SANDSTONE TOO. [method
## OriginalDialog.create] falls back to its OWN flat box when the art is
## absent, and that box is near-black (`panel_style`) — right for the dark
## grounds it was written for, and it would put this window's dark ink on
## a dark face for every player who has imported no original art.
##
## [UiChrome] settled that on 2026-09-03 by making its own skinless panel
## sandstone as well, so ONE ink colour serves both grounds and neither
## can drift ([method UiChrome.flat_panel], pinned by
## `tests/ui/test_ui_chrome_contrast.gd`). This borrows that box for the
## one window on this screen that is lettered in ink.
func _seat_on_sandstone(dialog: OriginalDialog) -> void:
	if GameSkin.texture(MENU_PANEL) != null:
		return
	for child in dialog.get_children():
		if child is Panel:
			(child as Panel).add_theme_stylebox_override("panel",
				UiChrome.flat_panel(0.0))


## The window's own name, in the sandstone voice.
##
## It goes in the BODY rather than through [method OriginalDialog.create]'s
## title, because that one letters itself in the pale-on-dark voice
## ([method OriginalDialog.label]) that this window has just stopped
## wearing. [constant UiChrome.ACCENT] rather than [constant UiChrome.INK]
## for the same reason [method UiChrome.explain_popup] gives its heading
## the title font: it is the one emphasised line on the panel.
func _menu_heading() -> Label:
	var heading := UiChrome.body_label(MENU_TITLE, 18)
	var title_font := GameSkin.font("font_title")
	if title_font != null:
		heading.add_theme_font_override("font", title_font)
	heading.add_theme_color_override("font_color", UiChrome.ACCENT)
	heading.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	return heading


## The hairline between the commands and the switches, in the panel's own
## ink at a quarter strength — a rule, not a border.
func _slab_rule() -> Control:
	var rule := Panel.new()
	rule.custom_minimum_size = Vector2(SLAB_ENTRY.x, 1)
	rule.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var box := StyleBoxFlat.new()
	box.bg_color = Color(UiChrome.INK, 0.28)
	rule.add_theme_stylebox_override("panel", box)
	rule.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rule


## Is the Q/Esc menu up? Public — it is what "this screen is standing
## still" means, and the tests read it.
func is_menu_open() -> bool:
	return _menu != null and is_instance_valid(_menu) \
		and not _menu.is_queued_for_deletion()


## Q, and Esc with nothing to cancel.
func _toggle_deck_menu() -> void:
	if is_menu_open():
		_close_deck_menu()
	else:
		_open_deck_menu()


func _open_deck_menu() -> void:
	if is_menu_open():
		return
	var dialog := OriginalDialog.create("", MENU_SIZE, MENU_PANEL)
	_seat_on_sandstone(dialog)
	# OVER WHATEVER WAS ALREADY THERE. `Q` is unconditional, so this window
	# can open on top of a dialog; 210/209 puts both it and its blocker
	# above [method _show_dialog]'s usual 200/199, and closing it hands the
	# dialog underneath back intact.
	dialog.z_index = 210
	dialog.body().add_child(_menu_heading())
	var first: Button = null
	for label in MENU_ENTRIES:
		var line := _slab_button(label)
		line.pressed.connect(_run_menu_entry.bind(label))
		dialog.body().add_child(line)
		if first == null:
			first = line
	# A rule between the commands and the settings: the five DO something
	# and close the window, the two only remember a preference.
	dialog.body().add_child(_slab_rule())
	# THE TWO SWITCHES ARE ONE BLOCK, centred together rather than each on
	# its own. Centred separately they shrink to their own labels, so the
	# shorter one's tick box sits 30px right of the longer one's and the
	# pair reads as two accidents instead of a column.
	var switches := VBoxContainer.new()
	switches.add_theme_constant_override("separation", 8)
	switches.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	dialog.body().add_child(switches)
	for label in MENU_SWITCHES:
		var box := _slab_switch(String(label))
		box.size_flags_horizontal = Control.SIZE_FILL
		box.pressed.connect(func() -> void:
			_toggle_deck_switch(String(label), box))
		switches.add_child(box)
	_menu = dialog
	_show_dialog(dialog, 209)
	# Focus is tree-wide, so it can only be taken once the window is in —
	# the same order [DuelPause] needs for its own `Return to game`.
	if first != null:
		first.grab_focus()


func _close_deck_menu() -> void:
	if is_menu_open():
		_menu.dismiss()
	_menu = null


## One entry. The window comes down FIRST in every case — the commands
## behind these labels open dialogs of their own, and [method
## _dialog_busy] would refuse them under an open menu.
func _run_menu_entry(label: String) -> void:
	_close_deck_menu()
	match label:
		MENU_BACK:
			pass
		"Save current deck":
			_run_command("Save deck")
		"Open existing deck":
			_run_command("Load deck")
		"Return to main menu":
			# `Exit deck builder` — which asks about EVERY slot that holds
			# unsaved work before it changes scene ([method
			# _confirm_discard_all]). The way out must not be the one way
			# out that loses a deck.
			_run_command("Exit deck builder")
		"Exit game":
			_quit_game()


## `Exit game`, and it asks first. The same walk `Return to main menu`
## takes: every slot with unsaved work is brought onto the surface and
## offered `@SAVE` before the process ends. Quitting is the one action
## with no undo at all, so it is the last one that should be allowed to
## drop work silently.
func _quit_game() -> void:
	_audio.play(DeckAudio.CUE_BUTTON)
	_confirm_discard_all(func() -> void:
		get_tree().quit())




## Flip one of the two switches, and MAKE IT TRUE AT ONCE: the bed stops
## on the line the box is unticked, and the next filter press is silent.
## A setting that took effect at the next screen would be no answer at all
## to *"a user may be annoyed by SFX or music while deck building"*.
func _toggle_deck_switch(label: String, line: Button) -> void:
	var key := String(MENU_SWITCHES[label])
	var on := not bool(Settings.get_value(key, true))
	if key == DeckAudio.MUSIC_SETTING:
		DeckAudio.set_music(on)
		_apply_music_switch()
	else:
		DeckAudio.set_sfx(on)
	line.button_pressed = on
	# The tick is audible when it turns sound ON and silent when it turns
	# it off, which is the cue the box is asking for.
	_audio.play(DeckAudio.CUE_BUTTON)


# ------------------------------------------------------------ keyboard --

## *"Esc is just like clicking the Cancel button"* (manual p.116). With a
## dialog on screen the Cancel button is the DIALOG's, so Escape dismisses
## it; with nothing to cancel it opens the Q/Esc menu (see that section
## above for the whole ladder). It used to leave the screen out from under
## an open dialog.
## [QoL] THE SHORTCUTS. Nothing here is 1997 — the original was a mouse
## program — but every one of them is a command a builder runs dozens of
## times a session, and none of them takes a key the screen already uses.
## They stand down while a dialog is open, because a dialog owns the
## keyboard.
const SHORTCUTS := {
	KEY_S: "Save deck", KEY_O: "Load deck", KEY_N: "New deck",
	KEY_Z: "Undo", KEY_L: "Add basic land", KEY_E: "Export deck",
}


func _unhandled_key_input(event: InputEvent) -> void:
	# NOT AN AUTO-REPEAT. A held Q would otherwise toggle the menu sixty
	# times a second, and a held Ctrl+S would save that often.
	if not (event is InputEventKey and event.pressed) or event.is_echo():
		return
	if event.keycode == KEY_ESCAPE:
		_on_escape()
		accept_event()
		return
	if event.keycode == KEY_Q and not event.ctrl_pressed \
			and not event.alt_pressed and not event.meta_pressed:
		# Q CARRIES NO OTHER DUTY ON THIS SCREEN, so unlike Esc it toggles
		# whatever else is going on. It never reaches here while a text
		# field has the keyboard — a focused [LineEdit] eats the key — so
		# typing `q` into the type-ahead cannot open a menu.
		_toggle_deck_menu()
		accept_event()
		return
	if _dialog_busy():
		return
	if event.ctrl_pressed and SHORTCUTS.has(event.keycode):
		_run_command(String(SHORTCUTS[event.keycode]))
		accept_event()
	elif event.ctrl_pressed and event.keycode == KEY_F:
		# The type-ahead is the fastest way through 800 cards; this is the
		# key every program in the world puts it on.
		_filter_bar.search_field.grab_focus()
		_filter_bar.search_field.select_all()
		accept_event()


## `Esc` in order of what is in the way: the Q/Esc menu first, then an
## open dialog, then a type-ahead that is holding the keyboard, and only
## then the menu itself.
##
## [QoL] THE MIDDLE STEP. The box is on Ctrl+F and a player who has typed
## into it and changed their mind reaches for Escape — which used to walk
## straight past the box and start leaving the Deck Builder, save prompt
## and all. One Escape now empties the box and gives the keyboard back;
## a second leaves, exactly as before.
func _on_escape() -> void:
	# 1. THE MENU OWNS THE KEY WHILE IT IS UP — *"Deck builder menu on Q or
	#    Esc should turn off if you press Q or Esc again."*
	if is_menu_open():
		_close_deck_menu()
		return
	var dialogs := open_dialogs()
	if not dialogs.is_empty():
		dialogs[-1].dismiss()
		return
	var box := _filter_bar.search_field
	if box != null and (box.has_focus() or filter.text != ""):
		var had_text := filter.text != ""
		filter.text = ""
		box.text = ""
		box.release_focus()
		_refresh_inventory()
		if had_text:
			_say("Type-ahead cleared")
		return
	# 4. NOTHING PENDING — the menu, not the door. Escape used to start
	#    leaving the Deck Builder outright (save prompt and all); it now
	#    offers the four ways out instead, which is the owner's ask and is
	#    also the safer key.
	_open_deck_menu()
