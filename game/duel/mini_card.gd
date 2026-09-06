class_name MiniCard
extends Button
## THE SMALL CARD — every large CardPreview has this counterpart, and it
## is the single generator for every card on the table: the battlefield,
## the piles, and the hand stack all render MiniCards, so a played card
## is never a different size or style from one in hand.
##
## What it draws (the owner's specification, matching the original):
## - a border of the card's own frame texture, with its TOP BORDER as the
##   title bar,
## - the card's art, smaller,
## - the name on that top bar — YELLOW when the card can be cast right
##   now, WHITE when it can't,
## - diagonal mana stripes for every colour the card can produce,
## - the SUMMONING-SICKNESS SPIRAL (the original's Summon.pic) over the
##   art of a creature that can't act yet,
## - power/toughness at the art's bottom-right corner,
## - the 1997 SMALL-CARD STATE overlays (see [enum State]),
## - and, when the card it draws is DESTROYED, the `Dying` cracks over the
##   square it is swept from — [DeathMark], raised from this widget's own
##   [method _on_game_event] because by the next frame there is no widget
##   left to raise it.
##
## Deliberately a Button: free hover/focus/press behavior and gamepad
## focus navigation for the console/TV target.

## What the frame says about this card RIGHT NOW. The colour code is the
## MANUAL's, not s30's — p.128: *"Mandatory effects are highlighted in
## orange, while optional effects are in yellow."* p.115/p.120/p.126 use
## one word, *highlighted*, for every "you may act on this" cue (a
## castable hand card, an attack-eligible creature, an eligible blocker, a
## legal target, an activatable permanent), which is why they all collapse
## into one OPTIONAL state instead of s30's four separate yellows and
## oranges (`duel.go:3302-3377`). GREEN for "committed" is [s30]'s hue —
## the original leaves no evidence either way, and green-means-locked-in
## is what our old SELECTED already meant.
##
## CASTABLE / TARGET / SELECTED are kept as ALIASES of the states that
## replaced them so in-flight callers keep compiling.
enum Highlight {
	NONE,
	OPTIONAL,        ## you MAY act on this (manual p.115/p.120/p.126)
	MANDATORY,       ## you MUST act on this (manual p.128)
	COMMITTED,       ## already chosen: a pending attacker, an assigned blocker
	TARGET_LEGAL,    ## a legal target for the spell being aimed
	TARGET_CHOSEN,   ## a target you have already picked for it
	CASTABLE = OPTIONAL,
	TARGET = TARGET_LEGAL,
	SELECTED = COMMITTED,
}

## EIGHT of the ten states `@CUECARD_SMALLCARD` (`UIStrings.txt:732`) says
## a card on the table can be in — the original's own vocabulary, and the
## reason this widget draws overlays at all. [constant STATE_CUE] carries
## the verbatim strings; [constant STATE_SPRITE] the skin key of the art
## that ships for each. The other two — `Damage to player` and `Phased` —
## are NOT here because this engine cannot answer them, and the reasons are
## written out at [method active_states] so nobody goes hunting.
enum State {
	SUMMONING_SICK,   ## "Summoning sickness"           — Summon.pic spiral
	DAMAGE,           ## "Damage: %d"                   — Damage.pic dagger
	DYING,            ## "Dying"                        — Dying.pic cracks
	WILL_UNTAP,       ## "This card will untap"         — WillUntap.pic arrow
	NOT_OWNED,        ## "Card is not controlled by owner" — no art shipped
	IS_TARGET,        ## "Is a target"                  — Target.pic crosshair
	CANT_TARGET,      ## "Can't target this"            — CantTarget.pic slash
	TARGET_AGAIN,     ## "Is a target, can't target again"
}

## The engine card this widget shows. The widget never mutates it.
var instance: CardInstance

## OPTIONAL game reference, set by whoever builds the widget when it has
## one (the duel screen does; the deck builder, the help screen and the
## pile views do not). Two of the 1997 card states — "Is a target" and the
## Winter-Orb caveat on "This card will untap" — are questions about the
## GAME, not about the card, and they simply do not draw without it. The
## widget still never mutates anything.
var game: MtgGame = null:
	set(value):
		if game == value:
			return
		# THE CARD HEARS ITS OWN DEATH. `MtgGame.event_occurred` is the one
		# thing on the engine side a widget may listen to (the class docs
		# on [signal MtgGame.event_occurred] say so: *"the UI layer
		# receives the same events ... so animations can mirror exactly
		# what the rules saw"*), and it is what raises the 1997 `Dying`
		# mark — see [method _on_game_event]. Probes never reach here:
		# `dispatch_event` emits the signal only `if not _probing`, so the
		# AI's search cannot leave marks on the table.
		if game != null and game.event_occurred.is_connected(_on_game_event):
			game.event_occurred.disconnect(_on_game_event)
		game = value
		if game != null and not game.event_occurred.is_connected(_on_game_event):
			game.event_occurred.connect(_on_game_event)
		if _name_label != null:
			refresh()

## Face-down rendering: the original card back when the 1997 skin is
## imported, a plain dark frame otherwise. A face-down widget shows no
## name, no art, no mana stripes, no tooltip and no state overlay.
##
## TWO DIFFERENT QUESTIONS REACH THIS ONE FLAG, and the builder answers
## both before it sets it:
##
## * **The card is face down IN THE GAME** — [member
##   CardInstance.face_down], an Illusionary Mask creature. Until
##   2026-09-04 nothing carried that onto the widget, so a masked creature
##   was drawn with its NAME, its ART, its oracle text and its printed
##   mana stripes on show: precisely what the card exists to hide
##   (`docs/card-states.md` §5.1). [method DuelScreen._make_card] and
##   [method CardPile._make_card] copy it now.
## * **This VIEWER may not see the card** — the hidden-hand rule. That is
##   why the flag lives on the WIDGET and not on the instance: the same
##   card is open to one seat and shut to the other.
##
## **WHO MAY LOOK IS NOT A QUESTION THIS ENGINE ANSWERS.** There is no
## per-seat visibility model in `engine/` — no `may_look_at(pid, inst)`,
## no viewer on [MtgGame] — and [member CardInstance.face_down] is a
## single global bool that `recalculate()` uses to blank the card's
## characteristics for EVERYBODY (CR 708.2: a 2/2 colourless creature with
## no name and no abilities). So a face-down permanent is drawn as a card
## back **to every seat, its controller's included** — the one reading
## that cannot leak. CR 708.2 would let a controller look at their own;
## the day the engine grows a viewer that can be relaxed here, and until
## then the ID tag (`Show ID tags`, which a face-down card still draws on
## purpose) is what tells two masked creatures apart.
var face_down := false:
	set(value):
		if face_down == value:
			return
		face_down = value
		# Same guard as [member castable]: during `_init` the face does
		# not exist yet and the constructor's own `refresh()` is coming.
		if _name_label != null:
			refresh()

## Wear [constant State.DYING] regardless of what the instance says.
##
## Set on ONE widget only — the ghost inside a [DeathMark], the card that
## has just been destroyed, held over its square for a beat. The state it
## forces is a fact about a permanent that is no longer on the battlefield
## at all, so no predicate here could derive it; the alternative was to
## make [method _state_active] read the graveyard, which would put the
## cracks on every card in it.
var force_dying := false

var _highlight: int = Highlight.NONE

# Child controls of the mini-card face (built once in _init): the original
# renders every battlefield permanent as a REAL little card — name strip,
# ART, P/T — so we do too (art via GameSkin.card_art, fetched by
# tools/fetch_card_art.py; a quiet identity color when absent).
var _name_label: Label = null
var _name_band: ColorRect = null
var _band_texture: TextureRect = null
var _art: TextureRect = null
var _art_frame: Panel = null
var _art_placeholder: ColorRect = null
var _pt_label: Label = null
var _status_label: Label = null
var _sick_spiral: TextureRect = null
var _damage_icon: TextureRect = null
var _damage_count: Label = null
## The `Show ID tags` overlay — see [constant DuelOptions.MENU_TOGGLES].
var _id_tag: Label = null
var _badges: HBoxContainer = null
var _stripes: Control = null
## THE TWO LETTERED HALVES OF THE TAP CUE — the dark title bar and the
## [constant TAPPED_MARK] on it. See [method shows_tap_mark].
var _tap_wash: ColorRect = null
var _tap_mark: Label = null
## State overlay -> its TextureRect (see [enum State]). Built once.
var _overlays: Dictionary = {}
## The targeting states the DUEL SCREEN pushes down (they are questions
## about the prompt in progress, not about the card): one of
## [constant State.CANT_TARGET], [constant State.TARGET_AGAIN] or -1.
var _target_state: int = -1

## Can its controller cast this right now? Drives the name colour
## (yellow vs white) exactly as the original's hand list does.
var castable := false:
	set(value):
		castable = value
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", name_color())

## Is the pointer on this card's ROW? In a pile the widget is
## mouse-transparent (the row's holder Button takes the click), so the
## pile pushes the state here. The original's hand list LIGHTENS the row
## under the pointer and turns its name YELLOW — the owner's zoomed
## screenshot, where "Disenchant" reads lighter and gold.
var hovered := false:
	set(value):
		if hovered == value:
			return
		hovered = value
		if _name_label != null:
			_name_label.add_theme_color_override("font_color", name_color())
		_apply_modulate()

## Card frame tints per color mask (single colors; gold for multicolor,
## grey for colorless, brown for lands) — evoking the original's frames.
const FRAME_COLORS := {
	Mtg.ManaColor.W: Color(0.85, 0.82, 0.68),
	Mtg.ManaColor.U: Color(0.35, 0.50, 0.78),
	Mtg.ManaColor.B: Color(0.30, 0.26, 0.32),
	Mtg.ManaColor.R: Color(0.72, 0.32, 0.22),
	Mtg.ManaColor.G: Color(0.30, 0.52, 0.34),
}
const FRAME_GOLD := Color(0.78, 0.65, 0.25)
## The rule around a card's art window — the frames' own gold/tan bevel.
const ART_BEVEL := Color8(198, 170, 116)
const FRAME_ARTIFACT := Color(0.55, 0.55, 0.58)
const FRAME_LAND := Color(0.52, 0.42, 0.30)

const HIGHLIGHT_COLORS := {
	Highlight.NONE: Color(0.10, 0.09, 0.08),
	Highlight.OPTIONAL: Color(0.95, 0.80, 0.25),        # yellow — you MAY
	Highlight.MANDATORY: Color(0.95, 0.55, 0.10),       # orange — you MUST
	Highlight.COMMITTED: Color(0.35, 0.85, 0.35),       # green — locked in
	Highlight.TARGET_LEGAL: Color(0.95, 0.80, 0.25),
	Highlight.TARGET_CHOSEN: Color(0.35, 0.85, 0.35),
}
## Border width per state. s30 makes exactly one width distinction and it
## is worth keeping: a CHOSEN target draws thicker than a legal one
## (`duel.go:3302-3377`, block 5 — w3 selected, w2 legal).
const HIGHLIGHT_WIDTH := {
	Highlight.NONE: 1,
	Highlight.OPTIONAL: 2,
	Highlight.MANDATORY: 2,
	Highlight.COMMITTED: 2,
	Highlight.TARGET_LEGAL: 2,
	Highlight.TARGET_CHOSEN: 3,
}

## `@CUECARD_SMALLCARD` VERBATIM (`UIStrings.txt:732`, latin-1 — GNU grep
## prints nothing without `-a`). These are the words the original used, and
## they are what this widget's tooltip says. Do not paraphrase them.
const STATE_CUE := {
	State.SUMMONING_SICK: "Summoning sickness",
	State.DAMAGE: "Damage: %d",
	State.DYING: "Dying",
	State.WILL_UNTAP: "This card will untap",
	State.NOT_OWNED: "Card is not controlled by owner",
	State.IS_TARGET: "Is a target",
	State.CANT_TARGET: "Can't target this",
	State.TARGET_AGAIN: "Is a target, can't target again",
}
## Skin key of the 1997 art for each state that ships one. "Card is not
## controlled by owner" has NO art in the original's set — it is drawn as a
## mark on the status line instead, so nothing here is invented.
## `Target.pic` serves two masters and is imported ONCE, under
## `target_cursor`: the duel screen's targeting cursor takes its raw image
## half, this takes the decoded sprite.
const STATE_SPRITE := {
	State.SUMMONING_SICK: "summon_sick",
	State.DAMAGE: "damage_marker",
	State.DYING: "state_dying",
	State.WILL_UNTAP: "state_will_untap",
	State.IS_TARGET: "target_cursor",
	State.CANT_TARGET: "state_cant_target",
	State.TARGET_AGAIN: "target_cursor",
}
## The status line's two lettered marks. **THEY ARE ASCII ON PURPOSE**, and
## the reason was measured in the thirty-eighth pass rather than guessed:
## `Font.get_glyph_index` was asked for every symbol this widget might
## want, in all three fonts it can end up with, and
##   * U+27F3 ⟳ (the tap glyph this line used to carry) is **glyph 0 —
##     missing — in ALL THREE**, including `ThemeDB.fallback_font`. It has
##     been drawing a tofu box on every tapped card since it landed;
##   * U+21C4 ⇄, U+2194 ↔, U+25CF ● and U+25B2 ▲ are missing from the
##     fallback font too, so a no-skin build boxes them as well;
##   * `font_title` (MagicMedieval) carries LETTERS AND LITTLE ELSE — even
##     `«` and `*` come back as glyph 0.
## The intersection that renders everywhere is plain ASCII, so plain ASCII
## is what the small card letters. The 1997 cue card carries the full
## sentence one hover away, which is where the vocabulary belongs.
const TAPPED_MARK := "(T)"
## **THE DARK TITLE BAR OF A TAPPED CARD** — one of the three cues every
## tapped permanent now wears, alongside the 90° turn and [constant
## TAPPED_MARK]. It began (2026-09-03) as a SUBSTITUTE for a turn a
## clipped `CardPile` row could not perform; the pile turns its rows now,
## and the owner kept the bar anyway: *"Cards should tap even in the stack
## — and show tapped symbol along with being darker."* See
## [method shows_tap_mark] for what each of the three is for.
##
## A wash rather than a heavier `modulate`: the bar's background is the
## card's own frame TEXTURE (tan marble, and light), so what the eye picks
## out down a stack of five overlapping cards is the two dark bars among
## the pale ones. Dimming the whole widget by another quarter cannot do
## that — it was already dimming by a quarter when the owner reported the
## cards "do not tap visually".
const TAPPED_WASH := Color(0.02, 0.02, 0.04, 0.55)
## Room [constant TAPPED_MARK] takes at the left end of the title bar. The
## name gives way by exactly this much while the mark is up, so every
## name in a pile still starts on the same left rule and the marked rows
## line up as a COLUMN — which is what makes them readable as a group.
## (On a TURNED card the same column runs down the card's right edge; the
## mark rotates with everything else it rides on.)
const TAP_MARK_W := 17.0
## "Card is not controlled by owner" — the one state on the original's list
## with no art of its own, so it is lettered rather than invented.
const NOT_OWNED_MARK := "stolen"
## The three CENTRE stamps are mutually exclusive: the original draws ONE
## over a card's art, and this is the order it wins in (a refusal beats a
## re-pick beats a plain target).
const CENTRE_STAMPS: Array[int] = [State.CANT_TARGET, State.TARGET_AGAIN,
	State.IS_TARGET]


## Battlefield mini-card size — measured off the owner's reference
## screenshot: ~11.6% x 14.6% of the screen (nearly square, art-dominant).
##
## **THIS IS THE ONLY CARD SIZE IN THE GAME.** Table, hand, piles,
## graveyard, exile, ante, the deck builder's grid: one dimension
## everywhere, never rescaled, and the only transform a card may wear is
## the 90° TAP ROTATION (which keeps the size and merely swaps the
## FOOTPRINT its holder reserves). `tests/ui/test_card_dimensions.gd`
## measures that on real widgets after a real layout pass.
const SIZE := Vector2(132, 106)

## One font size for EVERY card name (table cards and hand rows alike);
## names that don't fit are ellipsized, never scaled down.
const NAME_FONT_SIZE := 11

## Width the title bar has for letters: [constant SIZE].x less the name
## label's own insets (6 left, 4 right; see [method _build_face]).
const NAME_ROOM := SIZE.x - 10.0


## [QoL] THE NAME AS THE BAR CAN CARRY IT. A long name is trimmed with an
## ellipsis and the font never shrinks — right for the twenty-odd names
## in the pool that overrun the bar on their own, and useless for a
## FAMILY: every Circle of Protection trimmed to *"Circle of Protection:
## …"* and the 2026-09-06 playtest could not tell the six apart on the
## Inventory row. A family name ("Circle of Protection: Red") that will
## not fit keeps its distinguishing half whole and shortens the family to
## its initials — *CoP: Red*, which is what the era's players wrote
## anyway. A name that fits, or has no family, is untouched.
static func bar_title(card_name: String, font: Font,
		room := NAME_ROOM) -> String:
	var colon := card_name.find(": ")
	if colon <= 0 or font == null:
		return card_name
	if font.get_string_size(card_name, HORIZONTAL_ALIGNMENT_LEFT, -1,
			NAME_FONT_SIZE).x <= room:
		return card_name
	var initials := ""
	for word in card_name.left(colon).split(" ", false):
		initials += word[0]
	return "%s:%s" % [initials, card_name.substr(colon + 1)]

## SIZE OF THE POWER/TOUGHNESS PAIR, and it is a MEASURED RATIO rather
## than a taste. The owner, 2026-09-03: *"The power and defense numbers on
## mini cards should be a bit more prominent (mini card builder) — like
## original"*, with a photograph of the 1997 table where a tapped Avenging
## Ghoul's **6/4** reads across the room from the card's bottom-right
## corner. Ours was 14 on a 106px card and did not.
##
## **[s30]** for the number, because it is the only source that states one:
## its battlefield card is 100x83 and it letters the pair at **20**
## (`duel.go:1360-1364`, `battlefieldCreatureStatsSize`), right-padded 3
## and standing 2 clear of the bottom edge. That is **0.241 of the card's
## HEIGHT**; on our [constant SIZE] of 132x106 the same share is 25, and
## the padding and clearance scale to 4 and 2. The eighth pass (owner's
## table-card reference) had already put the pair *"white-on-art at the
## bottom-right corner"* — this pass only makes it the size the corner was
## always meant to carry.
##
## The 1997 exe gives the shape of the card rather than the type on it:
## `set_smallcard_size` is `mainwindow_width / 8`
## (`shandalar-src/src/functions/windows.c:1088`, and the original code it
## replaces is a literal `sar eax, 3` at `Magic.exe:494d3c`), so a small
## card is an eighth of the window wide however big the window is — which
## is why a RATIO, not a pixel count, is the thing to port.
const PT_FONT_SIZE := 25

## The pair is OUTLINED, not shadowed — the zone column's finding of the
## same day, arrived at on the same evidence: the numbers sit on whatever
## art the card happens to carry, and a 1px shadow disappears on a pale
## one (`DuelScreen.PILE_COUNT_OUTLINE_SIZE`, also 4). The 1997 renderer
## backs its card text the same way in spirit — `draw_text_with_shadow`
## paints a dark copy of the glyphs before the light ones
## (`shandalar-src/src/drawcardlib/drawcardlib.c:1280-1332`) — and an
## outline is that idea made symmetric, which is what a number standing on
## four different card arts needs.
const PT_OUTLINE_SIZE := 4

## The box the pair is right-aligned inside, and it is sized for the
## WIDEST pair the pool can print (`12/12` on a pumped Craw Wurm) plus its
## outline, so the numbers never overflow the card they belong to. The
## badge row stops here — see `_build_face`.
const PT_BOX := Vector2(70, 32)
## How far the box stands off the card's right and bottom edges — s30's
## own 3 and 2 on its 100x83 card, scaled to ours.
const PT_INSET := Vector2(4, 2)


## [param p_game] is optional and is the SAME reference [member game]
## takes — but handing it in here saves a whole extra [method refresh].
## The setter refreshes when the game changes, and the duel screen used to
## assign it one line after construction, so every card on the board was
## re-derived from scratch twice before it was ever shown (measured on the
## fortieth pass: 49µs of the 254µs a card cost to build). Set before
## [method _build_face], the setter sees `_name_label == null` and stays
## quiet; the single `refresh()` at the end then does the work once.
func _init(p_instance: CardInstance, p_game: MtgGame = null) -> void:
	instance = p_instance
	game = p_game
	custom_minimum_size = SIZE
	# SHRINK_CENTER ON BOTH AXES, AND IT IS NOT COSMETIC — it is what keeps
	# the one-size rule true inside a CONTAINER.
	#
	# Godot's `FlowContainer` and `BoxContainer` STRETCH a child carrying
	# the default `SIZE_FILL` to the height of its line
	# (`flow_container.cpp`: `if (child->get_v_size_flags() & SIZE_FILL)
	# child_size.height = line_height`). The battlefield rows are
	# `HFlowContainer`s that also hold things TALLER than a card — a tapped
	# card's holder (`SIZE.y + 8` = 140) and a five-card `CardPile` (174) —
	# so every plain card beside one of those was being stretched to 140 or
	# 174 pixels tall. (An enchanted card used to be a third such offender,
	# 106 + 16 per aura; since the forty-first pass its attachments overflow
	# UPWARD out of a wrap the size of a plain card, so it no longer makes a
	# line taller at all — see `DuelScreen.AURA_PEEK`.) Nothing
	# in this file said so and no constant carried the wrong number: the
	# card simply came out the wrong shape, with the name band, the mana
	# stripes, the badges and the P/T (all anchored as FRACTIONS of the
	# face) dragged out of place with it. That is the "the Crusade card on
	# the table looks a different height" the owner reported, measured at
	# 140 vs 106 in `test_the_whole_table_is_one_card_size`.
	#
	# Shrinking also gives a row ONE CENTRE LINE: a card pivots in place
	# when it taps instead of jumping as its holder changes shape.
	size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	size_flags_vertical = Control.SIZE_SHRINK_CENTER
	text = ""
	clip_text = false
	focus_mode = Control.FOCUS_ALL
	_apply_style()   # while there are no children to notify — see _apply_style
	_build_face()
	_tint_face()     # ...and now the face parts that call could not reach
	refresh()


## WHICH CARD'S ART THIS PERMANENT SHOWS (§2.12).
##
## Normally its own. But a land whose live basic subtype no longer matches
## the printed one — Evil Presence on a Tundra, Blood Moon over a Strip
## Mine, Magical Hack rewriting "Forest" — is, in play, that other land,
## and the picture should say so. s30 does this in `permanentArtName`
## (`duel.go:337-371`, pinned by `duel_land_art_test.go`): collect the live
## basic land subtypes, compare them with the printed set, and on any
## difference draw the first live subtype the printed card did not have.
##
## The ORIGINAL supports it from the other end. `Duel.hlp`, topic
## **Territory**, lists a card mini-menu entry for exactly this situation:
## *"**Original Type** shows you what this card was when it was cast,
## before any spells and effects changed it."* An entry that shows you what
## a card USED to be only earns its place on a table where the card in play
## already shows what it has BECOME.
##
## Nothing else changes: the NAME band still reads the printed name (the
## card is still called Tundra), and only the art window follows the type.
## CR 305.7 is why the change is worth drawing at all — a land retuned to a
## basic type loses its rules text and really is just that land.
static func art_name(inst: CardInstance) -> String:
	if inst == null:
		return ""
	if not inst.is_land():
		return inst.data.card_name
	var live: Array[String] = []
	for subtype in inst.cur_subtypes:
		if Mtg.BASIC_LAND_COLORS.has(subtype) and not live.has(subtype):
			live.append(subtype)
	if live.is_empty():
		return inst.data.card_name
	var printed: Array[String] = []
	for subtype in inst.data.subtypes:
		if Mtg.BASIC_LAND_COLORS.has(subtype):
			printed.append(subtype)
	# The sets match: nothing has retuned this land, so it is itself.
	var changed := live.size() != printed.size()
	if not changed:
		for subtype in live:
			if not printed.has(subtype):
				changed = true
				break
	if not changed:
		return inst.data.card_name
	# The first live type the printed card did NOT have is the interesting
	# one — a Bayou turned into a Forest should not go on drawing the
	# Forest half of a card it already had (s30 makes the same choice).
	for subtype in live:
		if not printed.has(subtype):
			return subtype.capitalize()
	return live[0].capitalize()


## The mini-card face, built once: name strip (top), art window (middle),
## status line (bottom-left) and P/T (bottom-right).
func _build_face() -> void:
	# TITLE BAR in the card's OWN colour across the top (the reference:
	# King Suleiman on blue, Dwarven Warriors on red, Savannah Lions on
	# tan) — never black. The name reads light or dark to suit the bar.
	_name_band = ColorRect.new()
	_name_band.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_band.offset_left = 3
	_name_band.offset_right = -3
	_name_band.offset_top = 2
	_name_band.offset_bottom = 18
	_name_band.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_band)
	# With the 1997 skin the bar IS the card's own top-border texture;
	# the ColorRect underneath stays as the no-skin fallback.
	_band_texture = TextureRect.new()
	_band_texture.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_band_texture.offset_left = 3
	_band_texture.offset_right = -3
	_band_texture.offset_top = 2
	_band_texture.offset_bottom = 18
	_band_texture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_band_texture.stretch_mode = TextureRect.STRETCH_SCALE
	_band_texture.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_band_texture)
	_name_label = Label.new()
	_name_label.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_name_label.offset_left = 6
	_name_label.offset_right = -4
	_name_label.offset_top = 2
	_name_label.offset_bottom = 18
	_name_label.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_name_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_name_label.add_theme_constant_override("shadow_offset_x", 1)
	_name_label.add_theme_constant_override("shadow_offset_y", 1)
	_name_label.add_theme_constant_override("shadow_outline_size", 3)
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	# Never shrink the font — a long name is TRIMMED with an ellipsis so
	# every card name on screen reads at the same size.
	_name_label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	_name_label.z_index = 2
	_name_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_name_label)
	# THE LETTERED HALF of the flat tap cue, in the name's own ink and
	# wearing the name's outline so it reads on a pale marble bar as well
	# as on a dark one. Same z as the name: both sit over the wash.
	_tap_mark = Label.new()
	_tap_mark.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_tap_mark.offset_left = 6
	_tap_mark.offset_top = 2
	_tap_mark.offset_right = 6 + TAP_MARK_W
	_tap_mark.offset_bottom = 18
	_tap_mark.text = TAPPED_MARK
	_tap_mark.add_theme_font_size_override("font_size", NAME_FONT_SIZE)
	_tap_mark.add_theme_color_override("font_color", Color(0.95, 0.95, 0.92))
	_tap_mark.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.95))
	_tap_mark.add_theme_constant_override("shadow_offset_x", 1)
	_tap_mark.add_theme_constant_override("shadow_offset_y", 1)
	_tap_mark.add_theme_constant_override("shadow_outline_size", 3)
	_tap_mark.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_tap_mark.z_index = 2
	_tap_mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_mark.visible = false
	add_child(_tap_mark)
	_art_placeholder = ColorRect.new()
	_art_placeholder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_art_region(_art_placeholder)
	add_child(_art_placeholder)
	_art = TextureRect.new()
	_art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	# THE ART IS ALWAYS MINIFIED — a ~582x467 Scryfall crop into a ~110px
	# window, better than 5:1 — and a plain LINEAR filter samples one
	# source pixel per screen pixel at that ratio, which lays a regular
	# diamond lattice over fur, chainmail, foliage and lettering
	# (`docs/card-states.md` §5.6). `GameSkin.card_art` builds the chain;
	# this is what asks for it. It is the small card's own filter and
	# nothing else's: the [CardPreview] draws the same texture near its
	# native size and wants mip 0.
	_art.texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS
	_art.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_set_art_region(_art)
	add_child(_art)
	# The art window's own BEVEL — the 1997 frames draw a light rule round
	# the picture, and at mini-card size the stretched frame art loses it.
	# Redrawn here so the inset reads as a frame on all four sides.
	_art_frame = Panel.new()
	_set_art_region(_art_frame)
	_art_frame.offset_left = -1
	_art_frame.offset_top = -1
	_art_frame.offset_right = 1
	_art_frame.offset_bottom = 1
	var bevel := StyleBoxFlat.new()
	bevel.bg_color = Color(0, 0, 0, 0)
	bevel.border_color = ART_BEVEL
	bevel.set_border_width_all(2)
	_art_frame.add_theme_stylebox_override("panel", bevel)
	_art_frame.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_art_frame)
	# KEYWORD BADGES along the card's bottom edge, left to right — s30
	# draws them at exactly this spot (pos.Y + cardH - iconSize).
	_badges = HBoxContainer.new()
	# BOTTOM_WIDE with a RIGHT LIMIT, not BOTTOM_LEFT: the row shares the
	# card's bottom edge with the P/T, and once the pair letters at
	# [constant PT_FONT_SIZE] the two really can meet on a card wearing
	# four badges. The precedence is stated rather than hoped for — the
	# NUMBERS own the corner, because they are the thing the owner asked
	# to be able to read across the table, and the row is CLIPPED at their
	# edge rather than drawn under them. A clipped fifth badge is a cost;
	# an unreadable 6/4 is the defect.
	_badges.set_anchors_preset(Control.PRESET_BOTTOM_WIDE)
	_badges.offset_left = 4
	_badges.offset_right = -(PT_BOX.x + PT_INSET.x)
	_badges.offset_top = -(BADGE + 3)
	_badges.offset_bottom = -3
	_badges.clip_contents = true
	_badges.add_theme_constant_override("separation", 1)
	_badges.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_badges)

	# Status text (damage, counters) rides just under the title bar so it
	# never collides with the badges.
	_status_label = Label.new()
	_status_label.set_anchors_preset(Control.PRESET_TOP_LEFT)
	_status_label.offset_left = 5
	_status_label.offset_top = 21
	_status_label.add_theme_font_size_override("font_size", 9)
	_status_label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_status_label.add_theme_constant_override("shadow_offset_x", 1)
	_status_label.add_theme_constant_override("shadow_offset_y", 1)
	_status_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_status_label)
	# DAMAGE MARKER (original: Damage.pic) at the art's bottom-right,
	# above the P/T, with the amount beside it.
	_damage_icon = TextureRect.new()
	_damage_icon.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_damage_icon.offset_left = -58
	_damage_icon.offset_top = -(PT_BOX.y + PT_INSET.y + 18)
	_damage_icon.offset_right = -30
	# THE STACK IN THIS CORNER IS DECIDED, not accidental: the dagger and
	# its number ride directly ABOVE the P/T box, so growing the pair
	# (2026-09-03) pushed them up rather than letting them cross it.
	_damage_icon.offset_bottom = -(PT_BOX.y + PT_INSET.y)
	_damage_icon.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_damage_icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	_damage_icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_damage_icon.visible = false
	add_child(_damage_icon)
	_damage_count = Label.new()
	_damage_count.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_damage_count.offset_left = -30
	_damage_count.offset_top = -(PT_BOX.y + PT_INSET.y + 20)
	_damage_count.offset_right = -6
	_damage_count.offset_bottom = -(PT_BOX.y + PT_INSET.y)
	_damage_count.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_damage_count.add_theme_font_size_override("font_size", 12)
	_damage_count.add_theme_color_override("font_color", Color(1.0, 0.45, 0.35))
	_damage_count.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	_damage_count.add_theme_constant_override("shadow_offset_x", 1)
	_damage_count.add_theme_constant_override("shadow_offset_y", 1)
	_damage_count.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_damage_count)

	# THE ID TAG — `Show ID tags\tCtrl+T` (`@MENU_TERRITORY` entry 18 and
	# `@MENU_SMALLCARD` entry 5, `docs/duel-todo.md` §6.3/§6.12), off by
	# default. `Duel.hlp`, **Territory**: *"toggles the display of each
	# card's unique ID code. This can be useful when you need to determine
	# exactly which of several otherwise identical cards is the target of
	# a specific spell or effect."* The 1997 executable calls it an
	# `IDTag`; the code it shows is our [member CardInstance.id], which is
	# unique for the whole duel and is what a bug report needs to quote.
	# TOP-RIGHT OF THE ART, just under the title bar — the mirror of
	# [member _status_label] and the one corner of the card nothing else
	# claims (badges bottom-left, damage marker and P/T bottom-right, the
	# mana stripes along the title bar itself). It was over the title bar's
	# left end first, and there it crowded the card's NAME, which is the
	# one thing a player must always be able to read.
	_id_tag = Label.new()
	_id_tag.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	_id_tag.offset_left = -40
	_id_tag.offset_top = 20
	_id_tag.offset_right = -4
	_id_tag.offset_bottom = 34
	_id_tag.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_id_tag.add_theme_font_size_override("font_size", 10)
	_id_tag.add_theme_color_override("font_color", Color(1.0, 0.95, 0.6))
	_id_tag.add_theme_color_override("font_shadow_color", Color(0, 0, 0))
	_id_tag.add_theme_constant_override("shadow_offset_x", 1)
	_id_tag.add_theme_constant_override("shadow_offset_y", 1)
	_id_tag.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_id_tag.visible = false
	add_child(_id_tag)

	# SUMMONING-SICKNESS SPIRAL over the art (original: Summon.pic).
	_sick_spiral = TextureRect.new()
	_set_art_region(_sick_spiral)
	_sick_spiral.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	_sick_spiral.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	# The reference draws the effect at FULL strength over the art, not
	# faded — it should read at a glance across the table.
	_sick_spiral.modulate = Color.WHITE
	_sick_spiral.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_sick_spiral.visible = false
	add_child(_sick_spiral)
	# The two overlays that were here before the state machine existed join
	# it as first-class members, cue cards and all.
	_sick_spiral.tooltip_text = STATE_CUE[State.SUMMONING_SICK]
	_damage_icon.tooltip_text = STATE_CUE[State.DAMAGE]
	_overlays[State.SUMMONING_SICK] = _sick_spiral
	_overlays[State.DAMAGE] = _damage_icon
	# The other five overlays are NOT built here — see _ensure_overlay.

	# MANA STRIPES: each colour owns a FIXED SLOT along the title bar, so
	# a card that makes several colours shows several slashes at once,
	# each in its own place (Black Lotus wears all five).
	_stripes = Control.new()
	_stripes.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_stripes.offset_top = 2
	_stripes.offset_bottom = 2 + STRIPE_H
	_stripes.offset_left = 3
	_stripes.offset_right = -3
	_stripes.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# z 1: above the lazily added state overlays (z 0, and they land after
	# this in the child list), below the name (z 2). See _ensure_overlay.
	_stripes.z_index = 1
	add_child(_stripes)
	# THE TAP WASH goes over the bar AND over the mana stripes — same z as
	# the stripes and added after them, so it wins — while the name (z 2)
	# stays bright and readable. Dimming the slashes is the point rather
	# than an accident: `Duel.hlp`, topic **Tap**, calls a tapped card one
	# whose *"effects have been temporarily used up"*, and the slashes are
	# exactly the effect a land has spent. An untapped Mountain shows a
	# bright red slash and a tapped one a dull one, which is a colour
	# difference the eye finds without being asked.
	_tap_wash = ColorRect.new()
	_tap_wash.set_anchors_preset(Control.PRESET_TOP_WIDE)
	_tap_wash.offset_left = 3
	_tap_wash.offset_right = -3
	_tap_wash.offset_top = 2
	_tap_wash.offset_bottom = 18
	_tap_wash.color = TAPPED_WASH
	_tap_wash.z_index = 1
	_tap_wash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_tap_wash.visible = false
	add_child(_tap_wash)

	# P/T as the original draws it: WHITE with a black shadow, overlapping
	# the art's bottom-right corner ("2/2" on Onulet in the reference).
	_pt_label = Label.new()
	_pt_label.set_anchors_preset(Control.PRESET_BOTTOM_RIGHT)
	_pt_label.offset_left = -(PT_BOX.x + PT_INSET.x)
	_pt_label.offset_top = -(PT_BOX.y + PT_INSET.y)
	_pt_label.offset_right = -PT_INSET.x
	_pt_label.offset_bottom = -PT_INSET.y
	_pt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	# BOTTOM, not the default TOP: the pair is anchored to the card's
	# bottom edge and grows UPWARD as the type grows, so the corner it
	# stands in is fixed and the box above it is what gives way.
	_pt_label.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	_pt_label.add_theme_font_size_override("font_size", PT_FONT_SIZE)
	_pt_label.add_theme_color_override("font_color", Color.WHITE)
	# OUTLINED rather than shadowed — see [constant PT_OUTLINE_SIZE]. The
	# 1px shadow this used to carry is gone with it: an outline already
	# backs the glyph on all four sides, and the two together only muddy
	# the numbers they are there to make legible.
	_pt_label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1))
	_pt_label.add_theme_constant_override("outline_size", PT_OUTLINE_SIZE)
	_pt_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pt_label.z_index = 1   # over the DYING cracks, as it always was
	add_child(_pt_label)


## Size of a CENTRE stamp (crosshair / circle-slash) over the art, and of
## the WILL UNTAP arrow in the art's top-right corner. Both are read off
## the 1997 sprites' own proportion to a card: `Target.pic`'s 61px image
## against the original's ~100px field card is 0.6 of the card's width, so
## a 132px card takes ~40; the arrow is a corner mark and takes half that.
const STAMP := 40
const CORNER_MARK := 22


## THE FIVE RARE OVERLAYS ARE BUILT ON DEMAND — and this is a MEASURED
## decision, not a style one. `_build_face` used to make nineteen child
## nodes for every card; five of them (the DYING cracks, the WILL UNTAP
## arrow and the three CENTRE stamps) are invisible on a card that is not
## dying and not being targeted, which is nearly every card nearly all of
## the time. The board is immediate-mode and rebuilds every `_refresh`, so
## those five were being made and thrown away by the thousand. Building
## them the first time a card actually enters one of those states took a
## card from 222 to 173 microseconds (fortieth pass).
##
## Z-ORDER STILL MATTERS AND IS STILL DECIDED HERE, not by accident of
## creation order: a creature can legitimately be sick AND dying AND
## targeted at once. Bottom to top: spiral, cracks (the whole art), the
## corner arrow, then the centre stamp — the transient targeting news, on
## top. Lazily added children land at the END of the child list, so the
## two face parts that would otherwise fall UNDER them — the mana stripes
## and the P/T — carry an explicit `z_index` of 1 (see `_build_face`), and
## the name keeps its 2. Everything else was already before the overlays
## in the child list and stays there.
##
## THE THREE CENTRE STAMPS COME AS A SET. They share one spot and are
## mutually exclusive, so any one of them means the card is in a targeting
## moment and the other two are one frame away.
const LAZY_OVERLAYS: Array[int] = [State.DYING, State.WILL_UNTAP,
	State.CANT_TARGET, State.TARGET_AGAIN, State.IS_TARGET]


func _ensure_overlay(state: int) -> void:
	if _overlays.has(state):
		return
	if CENTRE_STAMPS.has(state):
		for stamp_state in CENTRE_STAMPS:
			var stamp := TextureRect.new()
			stamp.set_anchors_preset(Control.PRESET_CENTER)
			stamp.offset_left = -STAMP / 2.0
			stamp.offset_top = -STAMP / 2.0
			stamp.offset_right = STAMP / 2.0
			stamp.offset_bottom = STAMP / 2.0
			stamp.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
			stamp.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
			_add_overlay(stamp_state, stamp)
		return
	if state == State.DYING:
		var cracks := TextureRect.new()
		_set_art_region(cracks)
		cracks.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		cracks.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_add_overlay(state, cracks)
		return
	if state == State.WILL_UNTAP:
		var arrow := TextureRect.new()
		arrow.set_anchors_preset(Control.PRESET_TOP_RIGHT)
		arrow.offset_left = -(CORNER_MARK + 8)
		arrow.offset_top = 22
		arrow.offset_right = -8
		arrow.offset_bottom = 22 + CORNER_MARK
		arrow.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		arrow.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		_add_overlay(state, arrow)


func _add_overlay(state: int, rect: TextureRect) -> void:
	# MOUSE_FILTER_IGNORE on purpose: this is a Button and the whole card
	# has to stay clickable and hoverable (the sidebar preview rides on
	# `mouse_entered`). The cue-card string still lives on each overlay's
	# own `tooltip_text` so it can be read back one by one, AND is folded
	# into the card's tooltip, which is what the player actually sees.
	rect.tooltip_text = STATE_CUE[state]
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.visible = false
	add_child(rect)
	_overlays[state] = rect


## The art WINDOW, as a fraction of the card — measured on the 1997 frame
## art (Cardbk_*.pic, 228x325): the stone surround runs 7.5% in from each
## side and the bottom border starts at 91.7% (docs/duel-screen-design.md,
## seventh and eleventh passes; CardPreview insets its art to the same
## 0.075/0.925). The art used to run to 0.03/0.965, i.e. straight over
## those borders, so a table card looked like a picture with a hairline
## round it instead of a picture INSIDE a frame.
const ART_LEFT := 0.075
const ART_TOP := 0.19
const ART_RIGHT := 0.925
const ART_BOTTOM := 0.917


static func _set_art_region(c: Control) -> void:
	# Art fills everything below the title bar, INSET so the card's own
	# frame shows all the way round it (the reference's field cards are
	# title bar + framed art, with P/T overlaid at the corner).
	c.anchor_left = ART_LEFT
	c.anchor_top = ART_TOP
	c.anchor_right = ART_RIGHT
	c.anchor_bottom = ART_BOTTOM
	c.offset_left = 0
	c.offset_top = 0
	c.offset_right = 0
	c.offset_bottom = 0


## Re-derive the whole visual from engine state. Cheap; called on every
## board refresh.
func refresh() -> void:
	# `Show ID tags` — off by default, and shown even on a face-down card:
	# the ID is what tells two identical face-down cards apart, which is
	# the whole reason the original offers it.
	if _id_tag != null:
		_id_tag.visible = DuelOptions.toggle("ShowIDTagsOnCards") \
			and instance != null
		if _id_tag.visible:
			_id_tag.text = str(instance.id)
	if face_down:
		tooltip_text = ""
		# **A FACE-DOWN PERMANENT IS STILL A PERMANENT.** It attacks, it
		# blocks, it is a legal target and it can be given damage — and
		# every one of those is a CLICK on this widget. Only a card back
		# the player cannot act on at all — a hidden hand row, a card
		# exiled face down — takes no clicks. This branch disabled every
		# face-down card flatly while nothing in the shipped game ever set
		# the flag; the moment §5.1's fix set it, a masked creature would
		# have become undeclarable as an attacker.
		disabled = instance == null or instance.zone != Mtg.Zone.BATTLEFIELD
		# `_stripes` IS IN THIS LIST. A card built face-down never gets
		# stripes (`_rebuild_stripes` runs only on the face-up path below),
		# but a widget FLIPPED face-down keeps the ones it already had —
		# and the mana a card taps for is exactly the information a card
		# back exists to withhold. Same reason the state overlays are
		# hidden two lines down.
		for child in [_name_label, _name_band, _band_texture, _art, _art_frame, _art_placeholder, _pt_label, _status_label, _badges, _damage_count, _stripes, _tap_wash, _tap_mark]:
			if child != null:
				child.visible = false
		# EVERY state overlay too (the dagger and the spiral included): a
		# face-down card tells the table nothing about itself.
		for state in _overlays:
			(_overlays[state] as TextureRect).visible = false
		# ...through [method _apply_style], which is the one door: it
		# routes a face-down card to the back for itself, so the frame
		# cannot be re-derived face-up by a later `set_highlight`.
		_apply_style()
		return
	var d := instance.data
	# ...and the face-down branch's `disabled = true` is undone here. It
	# was not, so a widget flipped back face up stayed permanently
	# unclickable — the one piece of face-down state that was set and
	# never restored.
	disabled = false
	for child in [_name_label, _name_band, _art_frame, _art_placeholder,
			_pt_label, _status_label, _stripes]:
		child.visible = true
	_name_label.text = bar_title(d.card_name, _name_label.get_theme_font("font"))
	# NO mana cost on cards in play or in hand — the reference shows the
	# cost only on the enlarged card in the sidebar. (Three branches that
	# tore down a `_cost_row` stood here and on the face-down path; nothing
	# had built one since that rule landed, so `refresh` was testing a
	# member that could not be non-null. Removed in the fortieth pass.)
	# The ART window — real art when fetched, identity color otherwise.
	# art_name, not card_name: a land whose SUBTYPE has been changed wears
	# the new basic land's art (§2.12).
	var art := GameSkin.card_art(art_name(instance))
	_art.texture = art
	_art.visible = art != null
	_art_placeholder.color = frame_color(d).darkened(0.35)
	# `Show power/toughness on small cards` (§6.4) — *"determines whether
	# or not the current power and toughness of each creature is displayed
	# on the card in play. (The Showcase always shows the original power
	# and toughness.)"* (`Duel.hlp`, **Dueling Options**), which is why the
	# switch lives here and not on [CardPreview].
	if d.is_creature() and DuelOptions.toggle("ShowPowerToughnessOnCards"):
		_pt_label.text = "%d/%d" % [instance.cur_power, instance.cur_toughness]
		_pt_label.add_theme_color_override("font_color", pt_color())
	else:
		_pt_label.text = ""
	_rebuild_stripes(d)
	_rebuild_badges()
	# The DAMAGE state's number rides beside its dagger.
	var wounded := _state_active(State.DAMAGE)
	_damage_count.text = str(instance.damage) if wounded else ""
	_damage_count.visible = wounded
	var states := active_states()
	_apply_states(states)
	_refresh_status(states)
	_refresh_tap_mark()
	# The card's tooltip is name + rules + THE 1997 CUE CARDS for whatever
	# it is currently wearing. The overlays are mouse-transparent so the
	# card stays clickable, which makes this the only place the player
	# actually reads them.
	tooltip_text = "%s\n%s" % [d.card_name, d.oracle_text]
	# `Show cue cards` (§6.4) — *"controls the appearance of the tiny hints
	# that pop up when you position the mouse cursor over an active
	# location. If you don't like the little tips, toggle the cue cards
	# off."* (`Duel.hlp`, **Dueling Options**.) The card's own NAME and
	# rules text are not a cue card and stay.
	if DuelOptions.toggle("ShowCueCards"):
		for line in state_cues(states):
			tooltip_text += "\n" + line
	_apply_modulate()
	_apply_style()


## The 1997 cue-card line for each state, in [enum State] order, with
## `Damage: %d` filled in. Exact `@CUECARD_SMALLCARD` wording.
func state_cues(states: Array[int]) -> PackedStringArray:
	var out := PackedStringArray()
	for state in states:
		var cue: String = STATE_CUE[state]
		out.append(cue % instance.damage if cue.contains("%d") else cue)
	return out


## Show/hide every overlay for the states this card is in. The three
## CENTRE stamps share one spot, so only the first of them wins.
func _apply_states(states: Array[int]) -> void:
	var centre := -1
	for state in CENTRE_STAMPS:
		if states.has(state):
			centre = state
			break
	# Whatever this card is actually in, make sure it HAS an overlay for it
	# (see _ensure_overlay); a state it is not in never costs a node.
	for state in states:
		if LAZY_OVERLAYS.has(state):
			_ensure_overlay(state)
	for state in _overlays:
		var rect: TextureRect = _overlays[state]
		var on: bool = states.has(state)
		if CENTRE_STAMPS.has(state):
			on = state == centre
		if on and STATE_SPRITE.has(state) and rect.texture == null:
			rect.texture = masked_sprite(STATE_SPRITE[state])
		rect.visible = on and rect.texture != null


## Every `@CUECARD_SMALLCARD` state this card is in right now, in
## [enum State] order.
##
## TWO OF THE ORIGINAL'S TEN ARE ABSENT FROM THIS WIDGET, and only one of
## them is unanswerable:
##
## * **`Damage to player`** is not a state of a CARD — but it is a state of
##   a small card, and that card is the DAMAGE MARKER: manual p.119's
##   *"yellow 'card' on or near the target of that damage"*, aimed at a
##   player rather than at a permanent. [DamageMarker] carries it, with
##   `Damage: %d` for the other direction.
##   CORRECTION (2026-09-01) of what stood here — *"it is the LIFE
##   REGISTER's, `@CUECARD_LIFE`"*. That table (`UIStrings.txt:678`)
##   declares eight entries and this is not among them; the state was in
##   `@CUECARD_SMALLCARD` all along because the object it describes is a
##   small card (docs/duel-todo.md §2.10, §6.20b).
## * **`Phased`** cannot happen to a widget. `MtgGame.phase_out` moves the
##   instance OUT of `players[pid].battlefield` into `phased_out` while
##   leaving `zone == BATTLEFIELD`, and there is no `Mtg.Zone.PHASED_OUT`,
##   so a phased permanent is never handed to this widget in the first
##   place. It becomes answerable the day the board draws phased-out cards.
func active_states() -> Array[int]:
	var out: Array[int] = []
	for state in State.values():
		if _state_active(state):
			out.append(state)
	return out


func _state_active(state: int) -> bool:
	if face_down or instance == null:
		return false
	var on_table: bool = instance.zone == Mtg.Zone.BATTLEFIELD
	match state:
		State.SUMMONING_SICK:
			# Instill Energy lifts only the ATTACK gate, not {T} costs, so
			# it sets cur_attacks_as_if_hasty rather than granting HASTE —
			# a creature that can legally swing must not be drawn as sick
			# either way.
			#
			# `Show all cards' summoning sickness` (`@MENU_TERRITORY` entry
			# 20, `ShowAllCardsSummonSickness` in the 1997 exe) is what the
			# creature test is: sickness reaches EVERY permanent in this
			# engine (CR 302.6 — and the original played under the
			# pre-Sixth rule where an artifact's {T} ability was sick too),
			# so the mark is filtered to creatures unless the player asks
			# for all cards. §6.3 read the entry as an on/off switch for
			# the spiral; the key says otherwise.
			if not on_table or not instance.summoning_sick:
				return false
			if not instance.is_creature() \
					and not DuelOptions.toggle("ShowAllCardsSummonSickness"):
				return false
			return not instance.has_keyword(Mtg.Keyword.HASTE) \
				and not instance.cur_attacks_as_if_hasty
		State.DAMAGE:
			return on_table and instance.damage > 0
		State.DYING:
			# THE ORIGINAL'S OWN PREDICATE IS `kill_code == KILL_DESTROY`
			# — a permanent marked to be destroyed and not reaped yet
			# (`shandalar-src/src/functions/windows.c:724`, the small
			# card's tooltip handler; `Duel.hlp`, **Regeneration**: *"You
			# can use regeneration ONLY at the time when a creature is
			# about to go to the graveyard."*). This engine has no such
			# flag: `MtgGame.destroy` decides and moves in one call. So the
			# state is answered from BOTH ends of that call.
			#
			# BEFORE: lethal damage marked, i.e. this goes at the next
			# state-based check. Real and visible whenever the engine holds
			# the moment open — `MtgGame.awaiting_regeneration`, the 1997
			# regeneration step, keeps exactly these creatures on the
			# battlefield with the sweep deferred. Indestructible is
			# excluded: it is not dying, and saying so would be a lie.
			#
			# AFTER: [member force_dying], set by the [DeathMark] raised
			# over a permanent that HAS been destroyed. Under the default
			# modern ruleset that is the only one of the two a player ever
			# sees, because the step above has no duration there.
			if force_dying:
				return true
			return on_table and instance.is_creature() \
				and instance.damage > 0 \
				and instance.damage >= instance.cur_toughness \
				and not instance.cur_indestructible
		State.WILL_UNTAP:
			# The INVERSE of a Meekstone lock: a tapped permanent that
			# nothing is holding down. Three instance-level locks
			# (`MtgGame._enter_step`'s untap branch) plus, when we have a
			# game to ask, the global throttles — Winter Orb and Smoke cap
			# how many untap at all, and while one is out this widget
			# cannot promise anything, so it stays quiet.
			if not on_table or not instance.tapped:
				return false
			if instance.skip_next_untap or instance.skip_untaps > 0 \
					or instance.cur_skips_untap:
				return false
			return game == null or game.untap_caps.is_empty()
		State.NOT_OWNED:
			return on_table and instance.controller_id != instance.owner_id
		State.IS_TARGET:
			return on_table and _is_on_the_stacks_targets()
		State.CANT_TARGET, State.TARGET_AGAIN:
			return _target_state == state
	return false


## Is this permanent named by any live stack item? `TargetRef` holds an
## ID, never a pointer (`engine/core/target_ref.gd`), so the comparison is
## by id — the same walk `target_arrows.gd` does to draw the arrows.
func _is_on_the_stacks_targets() -> bool:
	if game == null:
		return false
	for item in game.stack:
		for ref in item.targets:
			if not ref.is_player and ref.instance_id == instance.id:
				return true
	return false


## The duel screen's own targeting news, pushed down: one of
## [constant State.CANT_TARGET] (the current spec refuses this card),
## [constant State.TARGET_AGAIN] (already picked for this slot) or -1.
## Both are questions about the PROMPT IN PROGRESS, which lives in the
## screen, not in the engine — so they cannot be derived here.
func set_target_state(state: int) -> void:
	if _target_state == state:
		return
	_target_state = state
	refresh()


## THE CARD HEARS ITS OWN DEATH — and raises the 1997 `Dying` mark over the
## square it is about to be swept from. See [DeathMark] for what the
## original's `Dying` state is and for the three readings this takes from
## it; the short version is that the mark hangs off the DEATH rather than
## off the damage, so a creature that regenerated can never wear it.
##
## Hung on [constant Mtg.EventType.DIES] rather than derived in
## [method _state_active] because by the time a widget could ask, there is
## nothing left to ask: the permanent is out of `players[pid].battlefield`
## and the very next `state_changed` frees this widget
## (`DuelScreen._rebuild_field`). The event fires one step earlier, while
## the card is still laid out where the player is looking, which is the
## only moment a mark can be placed on the right square.
##
## SACRIFICE IS NOT DESTRUCTION and gets no mark: 1997 keeps them as
## separate kill codes and only `KILL_DESTROY` reads `Dying`, which is the
## same line `MtgGame.sacrifice_permanent` draws by never entering
## `MtgGame.destroy`. The event carries the flag; this is what reads it.
func _on_game_event(event: GameEvent) -> void:
	if event == null or event.type != Mtg.EventType.DIES:
		return
	if instance == null or force_dying or face_down:
		return
	if event.data.get("instance") != instance:
		return
	if bool(event.data.get("sacrificed", false)):
		return
	DeathMark.raise_over(self)


## P/T ink. **[s30]**, `duel.go:3402-3416` / `3780-3786`: compare the LIVE
## stats against the PRINTED ones and letter the pair green when pumped,
## red when weakened, white otherwise. Note it is an OR across both stats
## and PUMPED IS TESTED FIRST, so a +2/-2 reads as pumped — that is s30's
## rule, kept deliberately.
##
## Comparing against `data.power` is right by construction for a token or
## a copy: `become_copy` repoints `CardInstance.data` (CR 707), so `data`
## IS the printed card afterwards. Never cache the printed values.
func pt_color() -> Color:
	if instance.zone != Mtg.Zone.BATTLEFIELD:
		return Color.WHITE      # a card in hand has no live values to differ
	var d := instance.data
	if instance.cur_power > d.power or instance.cur_toughness > d.toughness:
		return Color8(100, 255, 100)
	if instance.cur_power < d.power or instance.cur_toughness < d.toughness:
		return Color8(255, 100, 100)
	return Color.WHITE


## Tapped cards dim; the row under the pointer lifts (see [member hovered]).
func _apply_modulate() -> void:
	if instance == null:
		return
	var base := Color(0.75, 0.75, 0.8) if instance.tapped else Color.WHITE
	# A MULTIPLY, not lightened(): the resting modulate is already white,
	# and lightening white leaves it exactly where it was.
	modulate = base * 1.25 if hovered else base


## Should this widget render sideways (1997 tapped rotation)? The parent
## decides WHERE — see the block below — but WHETHER is the card's own
## question, and so is the turn itself ([method tap_turn]).
func wants_rotation() -> bool:
	return instance.zone == Mtg.Zone.BATTLEFIELD and instance.tapped \
		and not face_down


## Is this widget the one that TURNS when its card taps? The parent
## declares it by giving the card a CENTRE PIVOT — see the block below
## [method wants_rotation], and [method turn_holder], which is the only
## thing in the game that gives one.
func turns_when_tapped() -> bool:
	return pivot_offset == SIZE / 2.0


## Does this card wear the DARK BAR and the [constant TAPPED_MARK] letters?
## **Every tapped permanent does, turned or not.**
##
## This used to read `wants_rotation() and not turns_when_tapped()` — the
## letters were a SUBSTITUTE for a turn that a clipped [CardPile] row could
## not perform, and a card that turned was deliberately left unlettered.
## Two things retired that rule on 2026-09-04. A pile row can turn now
## ([CardPile] gives its tapped rows a centre pivot like any other parent),
## so there is no longer a placement the substitute exists for; and the
## owner, shown the turn, asked for all three at once: *"Cards should tap
## even in the stack — and show tapped symbol along with being darker."*
##
## They do different work at different distances, which is why asking for
## all three is not belt-and-braces: the 90° turn reads across the table,
## the wash reads down a column of overlapping rows (a dull mana slash
## against five bright ones), and the letters read when a card is
## half-covered and only its title bar is showing. All three rotate WITH
## the card, so a turned card carries its bar down its right-hand edge.
func shows_tap_mark() -> bool:
	return wants_rotation()


## THE STATUS LINE under the title bar. [param states] is the caller's
## already-computed [method active_states] — this runs on every board
## refresh and the walk is not worth doing twice.
func _refresh_status(states: Array[int]) -> void:
	var status := PackedStringArray()
	if instance.zone == Mtg.Zone.BATTLEFIELD:
		# NO TAPPED MARK ON THIS LINE, and there is no branch left that
		# could put one here. It sat at `offset_top = 21` until 2026-09-03,
		# which is off the bottom of a card covered to its top [constant
		# CardPile.OVERLAP] pixels, so it moved into the TITLE BAR
		# ([method shows_tap_mark]) where a covered card still shows it.
		# Every tapped permanent wears it there now — turned or flat,
		# piled or loose — and the only card that does not is a FACE-DOWN
		# one, which draws no status line either ([method refresh] hides
		# the whole face: a card back tells the table nothing about
		# itself). One mark, one place, never two.
		#
		# "Card is not controlled by owner" is the one state in
		# `@CUECARD_SMALLCARD` with no art in the original's set, so it is
		# lettered rather than drawn — a Control Magic'd creature used to
		# look exactly like one of your own.
		if states.has(State.NOT_OWNED):
			status.append(NOT_OWNED_MARK)
		# NO "+N aura" CHIP HERE ANY MORE — the forty-first pass. It was
		# written across the host's ART, which the reference leaves clear,
		# and it only ever existed because the attachments themselves were
		# drawn as an unrecognisable grey band. Now that
		# `DuelScreen._make_widget` peeks a WHOLE CARD out from behind the
		# host per attachment, the picture says it better than the chip did
		# and says WHICH card, hoverable and clickable
		# (`DuelScreen.AURA_PEEK`).
	_status_label.text = "  ".join(status)


## Put the flat cue up or take it down. Called from [method refresh] and
## again from [method _ready], because a parent sets the pivot AFTER the
## constructor — at `_init` time every card still looks flat.
func _refresh_tap_mark() -> void:
	if _tap_wash == null or face_down:
		return
	var flat := shows_tap_mark()
	_tap_wash.visible = flat
	_tap_mark.visible = flat
	# The name gives way to the mark, and takes the room straight back
	# when the card untaps.
	_name_label.offset_left = 6.0 + (TAP_MARK_W if flat else 0.0)


# ------------------------------------------------------- THE TAP TURN --
#
# **THE ANGLE LIVES HERE.** A tapped permanent is drawn sideways.
# `Duel.hlp`, topic **Tap**, says it in as many words: *"Tapping a card
# means turning it sideways. This indicates to you and your opponent that
# the card effects have been temporarily used up."* Both RESTING looks are
# 1997's; the sweep between them is `[QoL]`, because no source we hold
# shows an in-between frame. The card is the thing that knows whether it
# is tapped, so the card owns the angle, the timing and the tween.
#
# **The parent still decides WHERE, and it has to.** `Container` zeroes a
# child's transform on every sort — `fit_child_in_rect` calls
# `set_rotation(0)` and `set_scale(1, 1)` outright — so a turning card
# needs a plain holder of [constant TURN_HOLDER_SIZE] between it and the
# battlefield row, which is what [method turn_holder] builds.
#
# **A parent says "you are the thing that turns" by giving the card a
# CENTRE PIVOT**, and [method aim_turn] is the only thing in the game that
# gives one. Two parents call it: [method turn_holder], for a lone card in
# a battlefield row or on the free layer, and [CardPile], which since
# 2026-09-04 turns its tapped rows in place inside the box the cascade
# reserved for them. [FanHand] does NOT — it tilts about a card's
# bottom-middle, which is a different transform — so a fanned card stays
# flat however tapped its instance claims to be. A card whose pivot is not
# its centre is drawn where it is drawn and left alone. See the `[QoL]`
# sections on the tap turn and on the pile cascade in `docs/ROADMAP.md`.

## How long the turn takes, and this number is the whole of its taste.
## 0.22s is the shortest span in which a 90° sweep still reads AS a sweep
## on a 60Hz screen (13 frames of it); much shorter and the eye takes it
## for a jump, much longer and tapping five lands for one spell becomes a
## wait. `EASE_OUT` puts most of the travel in the first third, so the
## card LEAVES its resting angle the instant it is clicked — the click
## feels answered — and settles into the stop instead of arriving at it.
##
## `TRANS_QUAD` is the mildest curve that does that, and, unlike the
## `TRANS_BACK` this used to use, it is MONOTONE. That matters more than
## the look: the board is immediate-mode and rebuilds its widgets under
## the animation, so a turn has to be RESUMED from a part-turned angle,
## and an overshoot resumed from inside its own overshoot wobbles.
const TAP_TURN_SECONDS := 0.22

## Clockwise. `rotation_degrees` is positive-clockwise in Godot's y-down
## screen space, so this turns the card to the RIGHT — the way a
## right-handed player taps one, and the way the 1997 sprite is drawn.
const TAP_TURN_DEGREES := 90.0

## The footprint a turning card sweeps out: its own [constant SIZE] with
## the axes swapped, plus 4px of slack on every side. The holder reserves
## this from the start, so a row makes room for the turn BEFORE it begins
## and nothing shuffles sideways halfway through.
const TURN_HOLDER_SIZE := Vector2(SIZE.y + 8.0, SIZE.x + 8.0)

## Sweep [member _turn_book] once it is bigger than any real board.
const TURN_BOOK_SWEEP := 32

## WHEN EACH CARD'S TURN BEGAN — `CardInstance` object id -> the
## `Time.get_ticks_msec()` at the tap.
##
## The widget cannot remember this itself, because the widget does not
## survive: the board is immediate-mode, and tapping a land for mana fires
## several rebuilds inside the 0.22s the turn takes (the tap, the mana
## pool, the spell that spent it). Each one FREES the turning card and
## builds another. Reading the start time here is what lets the
## replacement pick the animation up at the angle its predecessor had
## reached — the difference between a turn and a jump — and what stops a
## card that has been tapped for a minute from turning again on every
## refresh.
##
## **This `static` is safe because it holds nothing but ints** (CONTRIBUTING.md:
## no `static var` may hold a `CardData`/`CardInstance` — that rule was
## paid for twice). The key is the instance's OBJECT id rather than its
## game id, so a second duel that reuses game id 7 cannot inherit the
## first duel's turn, and entries whose object is gone are swept.
static var _turn_book: Dictionary = {}

## The turn this widget is running, if any. Killed before another starts.
var _turn: Tween = null

## Does the turn animate, or land at once? **A headless run draws no
## frames**, and a tween there is state half-applied: the angle becomes
## whatever the first frame's delta happens to land on. Measured
## 2026-09-03 on the live screen — 0° immediately after the refresh, 79.9°
## one frame later, 87.5° after two, and 90° only once a frame longer than
## the turn had gone by. The suite has been reading that lottery and
## passing on luck. Off headless, the FINAL angle is applied at once and
## is true whether or not anything is ever drawn.
##
## Tests turn it back on to exercise the tween itself.
var animate_turn := DisplayServer.get_name() != "headless"


## The angle a turn that began [param elapsed] seconds ago stands at.
## PURE — the resume is arithmetic, testable without a frame.
static func turn_angle(elapsed: float) -> float:
	if elapsed >= TAP_TURN_SECONDS:
		return TAP_TURN_DEGREES
	return Tween.interpolate_value(0.0, TAP_TURN_DEGREES, maxf(elapsed, 0.0),
		TAP_TURN_SECONDS, Tween.TRANS_QUAD, Tween.EASE_OUT)


## **THE ONE PLACE A CARD IS GIVEN ITS CENTRE PIVOT**, which is the whole
## of the contract in the block above: [param card] keeps [constant SIZE]
## (a tapped card is TURNED, never resized), turns about its own middle,
## and is centred in the [param box] its parent has reserved for the
## sweep. Every parent that wants a card to turn goes through here —
## [method turn_holder] with [constant TURN_HOLDER_SIZE], and [CardPile]
## with the swapped-axis box its cascade laid out — so there is exactly
## one definition of "this is the widget that turns" to keep true.
##
## The card is placed on its box's CENTRE rather than its corner, so its
## turned silhouette lands exactly on the box whatever the box's shape.
## For a box narrower than the card that means a NEGATIVE x offset, which
## is correct and is why nothing in the chain may clip: the card is 132
## wide flat and 106 wide square, and it is only ever square once the
## sweep has finished.
static func aim_turn(card: MiniCard, box: Vector2) -> void:
	card.size = SIZE
	card.pivot_offset = SIZE / 2.0
	card.position = (box - SIZE) / 2.0


## The plain holder a turning card needs, with [param card] centred inside
## it and pivoting on its own middle.
##
## SHRINK on both axes, like the card itself ([method _init]): the holder
## is the tallest thing in a creatures row, and a container STRETCHES a
## `SIZE_FILL` child to the line height — a stretched holder would slide
## the turning card off the row's centre line.
##
## **IGNORE, and deliberately.** A bare `Control` defaults to
## `MOUSE_FILTER_STOP`, so this spacer used to eat every press that landed
## in the 4px of slack around the card — a ring of dead pixels round every
## tapped permanent on the board, and the same default that killed the
## lettered set badges. The holder is geometry and nothing else; the card
## inside it is a `Button` and takes the mouse itself, and a press that
## misses the card belongs to the board underneath.
static func turn_holder(card: MiniCard) -> Control:
	var holder := Control.new()
	holder.custom_minimum_size = TURN_HOLDER_SIZE
	holder.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	holder.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	holder.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aim_turn(card, TURN_HOLDER_SIZE)
	holder.add_child(card)
	return holder


## Take up the turn. Called from [method _ready] — the moment the card
## reaches the tree, which is after whatever built it has finished
## placing it — and safe to call again at any time.
func tap_turn() -> void:
	if not wants_rotation():
		# Untapped, or gone from the table. The guard is `wants_rotation`
		# and NOT `zone == BATTLEFIELD`, because a creature bounced to
		# hand while tapped and recast must animate again rather than
		# arrive at 90° with no turn at all. The angle itself is left
		# alone: a card that does not TURN may still be TILTED by
		# something else (the fan), and this is not that transform.
		_turn_book.erase(instance.get_instance_id())
		_kill_turn()
		return
	if pivot_offset != SIZE / 2.0:
		# Drawn here, but not the thing that turns: a [FanHand] card, a
		# [DeathMark] ghost, a combat lineup. See the block above.
		return
	if _turn_book.size() > TURN_BOOK_SWEEP:
		_sweep_turn_book()
	var key := instance.get_instance_id()
	# `has`, not a sentinel: the book's values are clock readings, and a
	# clock reading is not a value a sentinel can be carved out of.
	var began: int = Time.get_ticks_msec()
	if _turn_book.has(key):
		began = _turn_book[key]
	else:
		_turn_book[key] = began
	var elapsed := float(Time.get_ticks_msec() - began) / 1000.0
	# INTERRUPTIBLE, AND NEVER TWO TWEENS ON ONE ANGLE. Whatever this
	# widget was running stops here and the new turn starts from where the
	# card actually stands, so a card tapped and untapped inside the 0.22s
	# — or a board that re-flows mid-turn — retargets instead of stacking,
	# and cannot be left sitting at 47°.
	_kill_turn()
	rotation_degrees = turn_angle(elapsed)
	if not animate_turn or elapsed >= TAP_TURN_SECONDS or not is_inside_tree():
		# Nothing left to travel, or nothing to travel it in: land it. A
		# card that has been tapped since before this widget existed
		# appears already turned, which is what stops the table spinning
		# on every state change.
		rotation_degrees = TAP_TURN_DEGREES
		return
	_turn = create_tween()
	_turn.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_QUAD)
	_turn.tween_property(self, "rotation_degrees", TAP_TURN_DEGREES,
		TAP_TURN_SECONDS - elapsed)


## Stop the turn this widget is running. A tween bound to a freed node is
## killed by Godot itself, so this is about the LIVE widget: it is what
## makes a second [method tap_turn] a retarget rather than a second hand
## on the same dial.
func _kill_turn() -> void:
	if _turn != null and _turn.is_valid():
		_turn.kill()
	_turn = null


## Drop turns whose card object is gone. The book outlives a duel, so
## without this a finished game's entries are dead weight — and, worse, a
## later card landing on a recycled object id would arrive already turned.
static func _sweep_turn_book() -> void:
	for key in _turn_book.keys():
		if not is_instance_id_valid(key):
			_turn_book.erase(key)


func _ready() -> void:
	# NOTHING ELSE TO DO HERE ANY MORE. This used to re-derive the tap cue
	# as well, because [method shows_tap_mark] asked whether the parent had
	# given the card a centre pivot and the parent sets that BETWEEN the
	# constructor and here — so a card built flat and turned a moment later
	# came out lettered. The cue no longer depends on the pivot (every
	# tapped permanent wears it, turned or not), so `_init`'s own `refresh`
	# already got it right and a second pass over the face would be work
	# for nothing on every card the board builds.
	tap_turn()


func set_highlight(mode: int) -> void:
	if _highlight != mode:
		_highlight = mode
		_apply_style()


func _frame_color() -> Color:
	return frame_color(instance.data)


## Frame tint for a card (STATIC — StackHand strips and the CardPreview
## reuse the same identity colors).
static func frame_color(d: CardData) -> Color:
	if d.is_land():
		return FRAME_LAND
	var mask := d.color_mask()
	if mask == 0:
		return FRAME_ARTIFACT
	var colors: Array = []
	for c in Mtg.WUBRG:
		if mask & c:
			colors.append(c)
	if colors.size() > 1:
		return FRAME_GOLD
	return FRAME_COLORS[colors[0]]


func _frame_skin_key() -> String:
	return frame_skin_key(instance.data)


## The card frame's TOP BORDER as a texture — the strip the original uses
## as the background of a card's title bar and of its row in a hand pile
## ("each card represented by its top border"). Null without the skin.
static var _strip_cache: Dictionary = {}

static func frame_strip(d: CardData) -> Texture2D:
	var key := frame_skin_key(d)
	if _strip_cache.has(key):
		return _strip_cache[key]
	var result: Texture2D = null
	var frame := GameSkin.texture(key)
	if frame != null:
		# Top border of Cardbk_*.pic: the first 5.5% of the card's height.
		var strip := AtlasTexture.new()
		strip.atlas = frame
		strip.region = Rect2(0, 0, frame.get_width(),
			maxf(6.0, frame.get_height() * 0.055))
		result = strip
	_strip_cache[key] = result
	return result


## Which original-skin frame key fits this card (see the importer
## MANIFEST). STATIC so the CardPreview shares the mapping.
static func frame_skin_key(d: CardData) -> String:
	if d.is_land():
		# Land frames come per produced color in the original; duals show
		# their first ability's color (a faithful-enough pick).
		if not d.mana_abilities.is_empty():
			var color: int = d.mana_abilities[0].produces[0][0]
			var names := {Mtg.ManaColor.W: "white", Mtg.ManaColor.U: "blue",
				Mtg.ManaColor.B: "black", Mtg.ManaColor.R: "red",
				Mtg.ManaColor.G: "green"}
			if names.has(color):
				return "card_frame_land_" + names[color]
		return "card_frame_artifact"
	var mask := d.color_mask()
	if mask == 0:
		return "card_frame_artifact"
	var single := {Mtg.ManaColor.W: "card_frame_white", Mtg.ManaColor.U: "card_frame_blue",
		Mtg.ManaColor.B: "card_frame_black", Mtg.ManaColor.R: "card_frame_red",
		Mtg.ManaColor.G: "card_frame_green"}
	return single.get(mask, "card_frame_gold")


## THE FRAME STYLES ARE SHARED, NOT REBUILT PER CARD.
##
## `_apply_style` used to allocate two to four `StyleBox` resources on
## every call, and `refresh()` calls it — so a twenty-card board rebuild
## (which happens several times per click, the board being immediate-mode)
## threw away sixty-odd resources it had just made. There are only ever
## `frames x highlights` distinct looks, none of them mutated after
## construction, so they are built once and handed out by reference.
## Measured on the fortieth pass: `_apply_style` fell from 14.6 to 1.6
## microseconds per card.
##
## Keyed by the same string `_style_key` compares against, so a cache hit
## and a no-op re-apply are the same test.
static var _box_cache: Dictionary = {}
## The look currently applied to THIS widget, so a `refresh()` that changes
## nothing about the frame does not re-push four theme overrides.
var _style_key := ""


## [member _style_key] while the card back is on. Any face-up look is
## `"<frame>|<highlight>"` and so can never collide with it, which is what
## makes a card turning over re-derive its frame by itself.
const FACE_DOWN_KEY := "down"


func _apply_face_down_style() -> void:
	var back := GameSkin.texture("card_back")
	# THE RING STILL GOES ON. It is a question about the PROMPT — "you may
	# act on this", "this is a legal target" — not about the card, so a
	# masked creature that is a legal target is ringed like any other and
	# says nothing about what it is.
	_refresh_highlight_ring(back != null)
	if _style_key == FACE_DOWN_KEY:
		return
	_style_key = FACE_DOWN_KEY
	var pair := _boxes_for(FACE_DOWN_KEY, back != null)
	for state in ["normal", "hover", "pressed", "focus", "disabled"]:
		add_theme_stylebox_override(state, pair[0])


func _apply_style() -> void:
	# A FACE-DOWN CARD WEARS THE BACK, whatever else it is asked for, and
	# this guard is what makes the widget order-independent. The duel
	# screen sets `face_down` and THEN pushes the highlight down; without
	# it that second call re-derived the face-UP frame and put the card's
	# own 1997 border back over the card back it had just been given.
	if face_down:
		_apply_face_down_style()
		return
	# Original-skin frame when the player has imported the 1997 art
	# (tools/import_original.py); clean flat frame otherwise.
	var skin_key := _frame_skin_key()
	var skinned := GameSkin.texture(skin_key) != null
	var key := "%s|%d" % [skin_key if skinned
		else _frame_color().to_html(false), _highlight]
	if key == _style_key:
		return   # nothing about the frame changed; the overrides still hold
	# THE FOUR OVERRIDES ARE THE EXPENSIVE PART, and not because of the
	# StyleBoxes (those are cached above): `add_theme_stylebox_override`
	# raises NOTIFICATION_THEME_CHANGED and Godot propagates it to every
	# descendant, so pushing four of them onto a finished card is four
	# walks of its fourteen children. `_init` therefore calls this ONCE
	# before `_build_face`, while the card is still childless.
	_style_key = key
	var pair := _boxes_for(key, skinned)
	add_theme_stylebox_override("normal", pair[0])
	add_theme_stylebox_override("hover", pair[1])
	add_theme_stylebox_override("pressed", pair[1])
	add_theme_stylebox_override("focus", pair[1])
	# The width half of the highlight, which a textured frame cannot carry
	# in a border of its own — see [member _highlight_ring].
	_refresh_highlight_ring(skinned)
	_tint_face()


## The `[normal, hover]` pair for the look [param key] names, built on first
## request and shared by every card that wears it. Everything the look
## depends on is already in the key, so a cache hit is exactly the test
## [method _apply_style] makes before deciding it has nothing to do.
func _boxes_for(key: String, skinned: bool) -> Array:
	if _box_cache.has(key):
		return _box_cache[key]
	var pair: Array = []
	if key == "down":
		if skinned:
			var tex := StyleBoxTexture.new()
			tex.texture = GameSkin.texture("card_back")
			pair = [tex, tex]
		else:
			var flat := StyleBoxFlat.new()
			flat.bg_color = Color(0.16, 0.10, 0.22)   # deep purple — a card back
			flat.border_color = Color(0.35, 0.28, 0.15)
			flat.set_border_width_all(2)
			flat.set_corner_radius_all(6)
			pair = [flat, flat]
	elif skinned:
		var tex_box := StyleBoxTexture.new()
		tex_box.texture = GameSkin.texture(_frame_skin_key())
		tex_box.set_content_margin_all(6)
		tex_box.modulate_color = Color.WHITE if _highlight == Highlight.NONE \
			else HIGHLIGHT_COLORS[_highlight].lightened(0.5)
		var tex_hover: StyleBoxTexture = tex_box.duplicate()
		tex_hover.modulate_color = tex_box.modulate_color.lightened(0.15)
		pair = [tex_box, tex_hover]
	else:
		var box := StyleBoxFlat.new()
		box.bg_color = _frame_color().darkened(0.45)
		box.border_color = HIGHLIGHT_COLORS[_highlight]
		box.set_border_width_all(HIGHLIGHT_WIDTH[_highlight])
		box.set_corner_radius_all(6)
		box.set_content_margin_all(4)
		var hover: StyleBoxFlat = box.duplicate()
		hover.bg_color = _frame_color().darkened(0.25)
		pair = [box, hover]
	_box_cache[key] = pair
	return pair


## **THE HIGHLIGHT RING — how [constant HIGHLIGHT_WIDTH] survives a
## TEXTURED frame.**
##
## The highlight is a colour AND a width, and the unskinned frame carries
## both: a `StyleBoxFlat` has `border_color` and `set_border_width_all`.
## The skinned frame is a `StyleBoxTexture` — the card's own 1997
## `Cardbk_*.pic` — and **a `StyleBoxTexture` has no border width at all**.
## [method _boxes_for] could therefore apply only the colour, as
## `modulate_color`, and with the original art imported the one width
## distinction the code went out of its way to keep — s30's *w3 selected,
## w2 legal* (`duel.go:3302-3377`, block 5) — vanished. The catalogue
## proved it by rendering: `22_highlight_committed.png` and
## `24_highlight_target_chosen.png` came out as BYTE-IDENTICAL files, two
## states of the board that no longer looked different
## (`docs/card-states.md` §5.2).
##
## So the width is drawn as a RING OVER the frame instead — the same
## device [CardPile] already rings a piled card with (`glow_actionable`),
## at the state's own [constant HIGHLIGHT_WIDTH] and in its own
## [constant HIGHLIGHT_COLORS]. Three properties of it are load-bearing:
##
## * **A resting card is untouched.** The node is built the first time a
##   highlight actually asks for one, so `Highlight.NONE` — which is
##   nearly every card nearly all of the time — costs no node, no draw and
##   no theme propagation, and renders exactly the pixels it always did.
## * **It never eats a click.** A [Panel] is a [Control] and a [Control]
##   defaults to `MOUSE_FILTER_STOP`; a ring across the whole card at STOP
##   would swallow the press that taps the land underneath it.
## * **Only the TEXTURED frame gets one.** The flat frame already draws
##   its widths, and doubling them would move the unskinned look that
##   `37`/`38`/`39` pin.
var _highlight_ring: Panel = null
## The highlight the ring currently draws, so a `refresh()` that changes
## nothing about it does not re-push a theme override (and NONE means
## there is nothing to draw).
var _ring_mode: int = Highlight.NONE
## Shared like [member _box_cache], and for the same reason: there are six
## possible rings in the whole game and the board rebuilds constantly.
static var _ring_cache: Dictionary = {}


static func _ring_box(mode: int) -> StyleBoxFlat:
	if _ring_cache.has(mode):
		return _ring_cache[mode]
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = HIGHLIGHT_COLORS[mode]
	box.set_border_width_all(HIGHLIGHT_WIDTH[mode])
	# SQUARE, like [CardPile]'s ring and unlike the flat frame's rounded
	# corners: this one traces a 1997 card frame, which has none.
	_ring_cache[mode] = box
	return box


## Put the width ring up, take it down, or leave it exactly where it is.
## [param textured] is whether the frame under it is a `StyleBoxTexture` —
## the only frame that cannot draw the width itself.
func _refresh_highlight_ring(textured: bool) -> void:
	var mode: int = _highlight if textured else Highlight.NONE
	if mode == _ring_mode:
		return
	_ring_mode = mode
	if mode == Highlight.NONE:
		if _highlight_ring != null:
			_highlight_ring.visible = false
		return
	if _highlight_ring == null:
		_highlight_ring = Panel.new()
		_highlight_ring.set_anchors_preset(Control.PRESET_FULL_RECT)
		# See the class note above: a Panel defaults to STOP.
		_highlight_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Over everything the face draws. The name and the `(T)` carry z 2
		# and the ring shares it, winning on child order because it is
		# added last — and it only ever paints the card's outermost three
		# pixels, which nothing else claims.
		_highlight_ring.z_index = 2
		add_child(_highlight_ring)
	_highlight_ring.add_theme_stylebox_override("panel", _ring_box(mode))
	_highlight_ring.visible = true


func _tint_face() -> void:
	# The title bar wears the card's colour, and TWO DIFFERENT RULES letter
	# what stands on it. This comment used to state only the second one and
	# attach it to the first, which is the drift `docs/card-states.md` §5.4
	# caught (that section quotes the old sentence in full): it hung the
	# light-bar/dark-bar contrast rule on the NAME, which the code has
	# never done and must not do.
	#
	# * **The name follows the CASTABLE rule and nothing else** — yellow
	#   when you can cast or use the card right now (or the pointer is on
	#   its row), white when you cannot: [method name_color],
	#   unconditionally. That rule is the original's own hand list and it
	#   outranks contrast, because it is INFORMATION rather than styling —
	#   a name that went dark on a marble bar would be saying "not
	#   castable" in the one place the player reads castability. What keeps
	#   it legible on a pale bar instead is its 3px shadow OUTLINE
	#   (`_build_face`), which backs the glyphs on all four sides.
	# * **The status line takes the bar's ink** — dark on a light bar,
	#   gold on a dark one. It is the contrast rule, it applies to
	#   [member _status_label], and `light_bar` below is where it lives.
	#
	# P/T stays white-on-art, outlined for the same reason.
	var bar := frame_color(instance.data)
	if _name_band != null:
		_name_band.color = bar
	var strip := MiniCard.frame_strip(instance.data)
	if _band_texture != null:
		_band_texture.texture = strip
		_band_texture.visible = strip != null
	# The imported marble strips are light; the flat bars follow identity.
	if _name_label != null:
		_name_label.add_theme_color_override("font_color", name_color())
	var light_bar := true if strip != null else bar.get_luminance() > 0.52
	if _status_label != null:
		_status_label.add_theme_color_override("font_color",
			Color(0.12, 0.09, 0.06) if light_bar else Color(0.97, 0.87, 0.45))


# ---------------------------------------------------- mana stripes & sick --

## One diagonal mana stripe, drawn at the sheet's NATIVE size.
## Sized so the band runs CORNER TO CORNER: traced in the sheet, it goes
## from (21,0) to (1,20), i.e. ~1:1, so a 17x16 window has its cut edges
## meeting the top and bottom of the card's title bar. The sheet's own
## orientation is the right one — the band leans bottom-left to
## top-right; mirroring it turned the slash the wrong way.
const STRIPE_W := 17.0
const STRIPE_H := 16.0
## Row order in Manastripes.pic: W U B R G, colourless last.
const STRIPE_SLOT := {
	Mtg.ManaColor.W: 0, Mtg.ManaColor.U: 1, Mtg.ManaColor.B: 2,
	Mtg.ManaColor.R: 3, Mtg.ManaColor.G: 4, Mtg.ManaColor.C: 5,
}
const STRIPE_SLOT_COUNT := 6
## Distance between neighbouring colour slots. Smaller than a stripe, so
## the slashes interleave the way the original's do.
const STRIPE_PITCH := 9.0
static var _stripe_cache: Dictionary = {}


## Every colour this card can produce, in the stripe sheet's order.
static func mana_colors(d: CardData) -> Array[int]:
	var out: Array[int] = []
	for ability in d.mana_abilities:
		for pair in ability.produces:
			if not out.has(pair[0]):
				out.append(pair[0])
	return out


## Pixel width the stripes occupy on this card's title bar.
## How wide the slot strip is from its leftmost used slot to the bar end.
static func stripes_width(d: CardData) -> float:
	var colors := mana_colors(d)
	if colors.is_empty():
		return 0.0
	var leftmost := STRIPE_SLOT_COUNT
	for color in colors:
		leftmost = mini(leftmost, int(STRIPE_SLOT.get(color, 5)))
	return STRIPE_W + (STRIPE_SLOT_COUNT - 1 - leftmost) * STRIPE_PITCH


func _rebuild_stripes(d: CardData) -> void:
	for child in _stripes.get_children():   # detach first — see _rebuild_badges
		_stripes.remove_child(child)
		child.queue_free()
	var colors := mana_colors(d)
	if colors.is_empty():
		_name_label.offset_right = -4
		return
	# Slots run W U B R G C from left to right, each PITCH apart, the
	# last one flush with the bar's right end. Every colour therefore
	# lands in the SAME place on every card, and five of them coexist.
	var leftmost := STRIPE_SLOT_COUNT
	for color in colors:
		var slot: int = STRIPE_SLOT.get(color, 5)
		leftmost = mini(leftmost, slot)
		var stripe := TextureRect.new()
		stripe.texture = stripe_texture(color)
		stripe.stretch_mode = TextureRect.STRETCH_KEEP   # native size, no blur
		stripe.size = Vector2(STRIPE_W, STRIPE_H)
		stripe.position = Vector2(_stripe_x(slot), 0)
		stripe.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_stripes.add_child(stripe)
	# The name stops short of the LEFTMOST slot actually used, so a
	# single-colour card keeps its room.
	_name_label.offset_right = _stripe_x(leftmost) - (SIZE.x - 6.0) - 4.0


## X of a colour slot inside the stripe strip (slot 5 sits flush right).
static func _stripe_x(slot: int) -> float:
	var strip_w := SIZE.x - 6.0
	return strip_w - STRIPE_W - (STRIPE_SLOT_COUNT - 1 - slot) * STRIPE_PITCH


## One cell of Manastripes.pic (6 cells of 54x21: W U B R G C), cropped
## 1:1 — NOT scaled. The band is a 2px diagonal, so squeezing the cell
## into a 14px stripe dissolved it into a smudge; the original drew these
## at native size onto rows about as tall as ours, so a native-size
## window centred on the band keeps it bold. The backdrop is KEYED OUT:
## the reference draws a bare diagonal slash straight onto the card's own
## top-border texture, with no block behind it. The key threshold is
## below the BLACK-mana band's own grey (0.18) so that band survives.
static func stripe_texture(color: int) -> Texture2D:
	if _stripe_cache.has(color):
		return _stripe_cache[color]
	var result: Texture2D = null
	var sheet := GameSkin.texture("mana_stripes")
	var slot: int = STRIPE_SLOT.get(color, 5)
	if sheet != null:
		var cell_h := sheet.get_height() / 6
		var full := sheet.get_image()
		var img := full.get_region(Rect2i(4, slot * cell_h + 2,
			int(STRIPE_W), int(STRIPE_H)))
		img.convert(Image.FORMAT_RGBA8)
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				if px.r < 0.10 and px.g < 0.10 and px.b < 0.10:
					px.a = 0.0
					img.set_pixel(x, y, px)
		result = ImageTexture.create_from_image(img)
	_stripe_cache[color] = result
	return result


## The original's summoning-sickness spiral (Summon.pic): 254x127, the
## left half the image and the right half its MASK, where black marks
## the opaque pixels. Built once, cached.
static func sick_spiral_texture() -> Texture2D:
	return masked_sprite("summon_sick")


## The original's damage marker (Damage.pic), drawn on a wounded creature.
static func damage_marker_texture() -> Texture2D:
	return masked_sprite("damage_marker")


## Decode one of the original's IMAGE+MASK sprites: half the file is the
## picture and the other half its mask. The split is normally LEFT/RIGHT;
## pass [param vertical] for the files that stack TOP image over BOTTOM
## mask (`Winbk_Attackbones`).
##
## Three variants exist in the shipped art and all three are handled:
##   * the converted files carry real ALPHA in the mask half (`Summon.pic`);
##   * the raw 1997 files store a two-tone silhouette, and the POLARITY is
##     not constant — `Damage.pic` masks its background WHITE while the
##     Combat window's sword, shield and bone strip mask theirs BLACK. The
##     mask's own top-left pixel is by construction part of the
##     background, so it tells us which tone means "transparent" without
##     a per-file table.
## Cached per key and axis.
static var _masked_cache: Dictionary = {}

static func masked_sprite(key: String, vertical := false) -> Texture2D:
	var cache_key := key + ("|v" if vertical else "")
	if _masked_cache.has(cache_key):
		return _masked_cache[cache_key]
	var result: Texture2D = null
	var sheet := GameSkin.texture(key)
	if sheet != null:
		var full := sheet.get_image()
		var w: int = full.get_width()
		var h: int = full.get_height()
		var img: Image
		var mask: Image
		if vertical:
			var half_h: int = h / 2
			img = full.get_region(Rect2i(0, 0, w, half_h))
			mask = full.get_region(Rect2i(0, half_h, w, half_h))
		else:
			var half_w: int = w / 2
			img = full.get_region(Rect2i(0, 0, half_w, h))
			mask = full.get_region(Rect2i(half_w, 0, half_w, h))
		img.convert(Image.FORMAT_RGBA8)
		mask.convert(Image.FORMAT_RGBA8)
		var mask_has_alpha := false
		for y in range(0, mask.get_height(), 4):
			for x in range(0, mask.get_width(), 4):
				if mask.get_pixel(x, y).a < 0.5:
					mask_has_alpha = true
					break
			if mask_has_alpha:
				break
		# The corner is background: whichever tone it wears is the one that
		# must come out transparent.
		var clear_is_bright := mask.get_pixel(0, 0).r > 0.5
		for y in img.get_height():
			for x in img.get_width():
				var px := img.get_pixel(x, y)
				var m := mask.get_pixel(x, y)
				if mask_has_alpha:
					px.a = m.a
				else:
					px.a = (1.0 - m.r) if clear_is_bright else m.r
				img.set_pixel(x, y, px)
		result = ImageTexture.create_from_image(img)
	_masked_cache[cache_key] = result
	return result


## Name colour: the reference's rule — YELLOW when castable now OR while
## the pointer rests on the row, else WHITE.
func name_color() -> Color:
	return Color(1.0, 0.90, 0.30) if castable or hovered \
		else Color(0.95, 0.95, 0.92)


# ------------------------------------------------------- keyword badges --

## Badge size on a table card.
const BADGE := 17
## Ability-sheet cell per keyword — s30's keywordIconIndex, verified
## against the imported sheet at 4x (11 wing/flying, 12 red foot/trample,
## 13 blue cross/banding, 14 sword-and-shield/first strike, 16 pale
## star/reach).
##
## **CELL 17 IS BLANK — 484/484 px of solid black, one unique colour**, on
## both the s30 conversion and our own import. s30 maps Menace there
## (`duel.go:1047-1121`); the 1997 game had no menace keyword and no icon
## for it, so that mapping blits a black square. `duel-todo.md` §3.4
## records that no card in this pool needs menace. Do not "complete" the
## map — `test_menace_is_not_badged` pins it.
const BADGE_SLOT := {
	Mtg.Keyword.FLYING: 11,
	Mtg.Keyword.TRAMPLE: 12,
	Mtg.Keyword.BANDING: 13,
	Mtg.Keyword.FIRST_STRIKE: 14,
	Mtg.Keyword.REACH: 16,
}
## PROTECTION badges, also from s30 (protectionColorIconIndex): the
## shield for each colour a permanent is protected from.
const PROTECTION_SLOT := {
	Mtg.ManaColor.G: 5, Mtg.ManaColor.R: 6, Mtg.ManaColor.U: 7,
	Mtg.ManaColor.B: 8, Mtg.ManaColor.W: 9,
}
## Cell 15, the GREEN TRIDENT — REGENERATION. It is not in
## [constant BADGE_SLOT] because **there is no `Mtg.Keyword.REGENERATION`**:
## regeneration in this pool is an ACTIVATED ABILITY ({B}: Regenerate) whose
## effect is a `RegenerateEffect` shield builder, never a keyword. The
## predicate is [method regenerates_itself].
const REGENERATION_SLOT := 15
## Cell 10, the BROWN SHIELD — PROTECTION FROM ARTIFACTS. Also outside
## [constant PROTECTION_SLOT], because `CardInstance.cur_protection` is a
## `Mtg.ManaColor` bitmask with no room for a non-colour entry. The
## predicate is [method warded_from_artifacts].
const ARTIFACT_PROTECTION_SLOT := 10
static var _badge_cache: Dictionary = {}


## One cell of the ability sheet (22px squares, already transparent).
static func badge_texture(keyword: int) -> Texture2D:
	return badge_from_slot(BADGE_SLOT.get(keyword, -1))


## One cell of the ability sheet by slot index (s30's icon numbering),
## MASKED TO ITS INSCRIBED CIRCLE.
##
## The sheet stores every icon as a disc on an OPAQUE NEAR-BLACK SQUARE, so
## the old bare `AtlasTexture` drew a dark 22px block behind every badge —
## the same class of bug the eleventh pass hit on the set symbols and
## `ManaIcons.symbol` hit on the mana sheet. Keying every achromatic pixel
## (the set-symbol fix) is NOT available here: the protection-white shield
## and the reach star are achromatic themselves.
##
## So the cells were MEASURED rather than assumed. Across all 18, the
## furthest non-black pixel from the centre sits at r = 11.068 and the
## nearest black one at r = 11.34, in a 22px cell — the backdrop is
## exactly the four corners outside the disc and nothing else. A cut at
## `cell * 0.51` (11.22) therefore separates icon from backdrop with no
## judgement call, and black pixels INSIDE the disc (the skull, every
## icon's outline) survive untouched. The last pixel of the rim is
## feathered so it does not alias, as `ManaIcons.symbol` does.
static func badge_from_slot(slot: int) -> Texture2D:
	if _badge_cache.has(slot):
		return _badge_cache[slot]
	var result: Texture2D = null
	var sheet := GameSkin.texture("ability_icons")
	if sheet != null and slot >= 0:
		var cell := sheet.get_width()   # the sheet is one column wide
		if (slot + 1) * cell <= sheet.get_height():
			var img := sheet.get_image().get_region(
				Rect2i(0, slot * cell, cell, cell))
			img.convert(Image.FORMAT_RGBA8)
			var centre := (cell - 1) / 2.0
			var radius := cell * 0.51
			for y in cell:
				for x in cell:
					var dist := Vector2(x - centre, y - centre).length()
					if dist <= radius - 1.0:
						continue
					var px := img.get_pixel(x, y)
					px.a = maxf(0.0, radius - dist) if dist < radius else 0.0
					img.set_pixel(x, y, px)
			result = ImageTexture.create_from_image(img)
	_badge_cache[slot] = result
	return result


## Does this permanent regenerate ITSELF? There is no regeneration
## keyword in this engine, so the honest question is "has it an activated
## ability whose effect is a `RegenerateEffect` with no target spec" — a
## spec would mean it regenerates something ELSE (Ragnar, Elephant
## Graveyard), which is not a badge about this card.
##
## Reads `cur_activated_abilities`, never `data.activated_abilities`:
## Zombie Master GRANTS regeneration at runtime, and Titania's Song takes
## every activated ability away.
func regenerates_itself() -> bool:
	if instance.zone != Mtg.Zone.BATTLEFIELD:
		return false
	for ability in instance.cur_activated_abilities:
		for effect in ability.effects:
			if effect is RegenerateEffect and effect.target_spec == null:
				return true
	return false


## Does this permanent have PROTECTION FROM ARTIFACTS?
##
## The engine has no typed answer: `cur_protection` is a colour bitmask and
## `CardData.protection_from` is the same bitmask, so the one card in the
## pool that grants it — Artifact Ward (`cards/sets/atq/artifact_ward.gd`)
## — expresses it as the three CLAUSES protection is made of, on the live
## lists that already existed for them. We ask for the two that define
## protection as the badge means it: damage from artifact sources is
## prevented AND artifact sources may not target it.
##
## Matching on the engine's own human-readable `desc` is the coupling this
## costs, and it is deliberate: the day `cur_protection` grows a non-colour
## entry, this becomes one lookup in [constant PROTECTION_SLOT].
func warded_from_artifacts() -> bool:
	if instance.zone != Mtg.Zone.BATTLEFIELD:
		return false
	return _names_artifacts(instance.cur_damage_immunity) \
		and _names_artifacts(instance.cur_target_bans)


static func _names_artifacts(entries: Array) -> bool:
	for entry in entries:
		if String(entry.get("desc", "")).contains("artifact"):
			return true
	return false


func _rebuild_badges() -> void:
	# remove_child BEFORE queue_free: a freed-but-not-yet-collected child is
	# still in get_children() for the rest of the frame, so two refreshes in
	# one frame (the duel screen sets `game` after building) used to leave
	# every badge on the card twice.
	for child in _badges.get_children():
		_badges.remove_child(child)
		child.queue_free()
	if instance.zone != Mtg.Zone.BATTLEFIELD:
		return   # the original badges what is IN PLAY
	# `Show abilities on small cards` (§6.4) — *"determines whether each
	# creature's abilities (flying and such) are marked on the card by
	# ability icons."* (`Duel.hlp`, **Dueling Options**.) In Manalink the
	# same switch also gates their tooltips (`windows.c:353,491`); ours are
	# on the icons themselves, so removing the icons removes those too.
	if not DuelOptions.toggle("ShowAbilitiesOnCards"):
		return
	# ACTIVATION COST first — the reference puts a small mana symbol at a
	# permanent's bottom-left for the ability you can use (Urza's Avenger
	# wears the "0" of its "{0}:" ability there).
	for ability in instance.cur_activated_abilities if \
			"cur_activated_abilities" in instance else instance.data.activated_abilities:
		var cost_text: String = ability.cost.text
		var row := ManaIcons.cost_row(cost_text if cost_text != "" else "{0}", BADGE - 3)
		if row != null:
			row.mouse_filter = Control.MOUSE_FILTER_IGNORE
			for icon in row.get_children():
				icon.size_flags_vertical = Control.SIZE_SHRINK_CENTER
			_badges.add_child(row)
		break   # one cost badge is enough; the big card lists them all
	var slots: Array[int] = []
	for keyword in instance.cur_keywords:
		if BADGE_SLOT.has(keyword) and not slots.has(BADGE_SLOT[keyword]):
			slots.append(BADGE_SLOT[keyword])
	if regenerates_itself() and not slots.has(REGENERATION_SLOT):
		slots.append(REGENERATION_SLOT)
	for color in PROTECTION_SLOT:
		if (instance.cur_protection & color) != 0 \
				and not slots.has(PROTECTION_SLOT[color]):
			slots.append(PROTECTION_SLOT[color])
	if warded_from_artifacts() and not slots.has(ARTIFACT_PROTECTION_SLOT):
		slots.append(ARTIFACT_PROTECTION_SLOT)
	for slot in slots:
		var tex := badge_from_slot(slot)
		if tex == null:
			continue
		var badge := TextureRect.new()
		badge.texture = tex
		badge.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		badge.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		badge.custom_minimum_size = Vector2(BADGE, BADGE)
		badge.mouse_filter = Control.MOUSE_FILTER_IGNORE
		_badges.add_child(badge)
