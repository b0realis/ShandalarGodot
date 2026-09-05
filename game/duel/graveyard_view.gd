class_name GraveyardView
extends Control
## THE GRAVEYARD (and exile, and ante) LAID OUT — docs/duel-todo.md §1.2.
##
## Until this existed, a graveyard was a `TextureRect` with a tooltip and
## nothing in it could be clicked, which meant the engine's four graveyard
## target kinds (`engine/core/target.gd`) had no reachable target: casting
## Raise Dead, Animate Dead, Resurrection, Adun Oakenshield or Ashes to
## Ashes put the duel screen into TARGETING with only Cancel available.
## Those cards were literally uncastable through our UI.
##
## THE ORIGINAL'S OWN NAMES. `@MENU_GRAVEYARD` (Program/UIStrings.txt:901)
## is the right-click menu on a graveyard and it has exactly three views:
##
##     View the graveyard / View exiled cards / View both antes / Help...
##
## so all three zones live in this one overlay, in that order, and only the
## non-empty ones are drawn. The section headings are `@CUECARD_OTHER`'s
## (`:667`): `Your graveyard` and `%s graveyard` — the original's second
## person for your own pile. Exile and ante follow the same pattern with
## the menu's own nouns.
##
## THE SHAPE is s30's `graveyardViewLayout` / `drawGraveyardView`
## (`duel.go:2082-2149`, `2946-2995`): a full-screen dim, one titled
## section per player, a row of cards; clicking a pile opens it, clicking
## the same pile again or anywhere outside closes it
## (`3715-3733 handleGraveyardClick`). While the duel is TARGETING, a card
## that is a legal target selects and submits (`2305-2328
## handleGraveyardTargetClick`) and an illegal one is refused with the
## original's `Illegal target (%s).` rather than being silently inert.
##
## ---------------------------------------------------------------------
## [QoL] A SHELF OF FIVE MINI CARDS, NOT A FORMAT OF ITS OWN.
##
## The owner's words, and a DELIBERATE DIVERGENCE from 1997 (which gave
## the graveyard its own separate presentation): *"graveyards should be
## composed of our mini cards, 5 in a row, with arrow on the left and
## arrow on the right to scroll through graveyards if they are extensive.
## And a number which card of all in the graveyard it is, in the center
## card of the 5. Now the graveyard has its own format — no! Only big
## preview and mini cards with names, art, icons, power/defense etc.
## Let's be consistent. This is a divergence from the original but this is
## what we want — enhanced game with old feel and good QoL."*
##
## What that fixes: this file used to force `Vector2(96, 134)` onto every
## card — TALLER than wide, where `MiniCard.SIZE` is `132 x 106`, WIDER
## than tall. The name bar, the mana stripes, the badges, the damage
## marker and the P/T are all anchored as FRACTIONS of that 132x106 face,
## so squashing the widget into the other aspect put every one of them in
## the wrong place: the pile was the one spot in the duel where a card did
## not look like a card. Cards here are now plain `MiniCard`s at their own
## size, laid out by the container — nothing about a card is re-drawn in
## this file, and hovering one fills the same docked `CardPreview` the
## rest of the duel uses.
##
## A CARD IS NEVER SCALED HERE. The owner, when a scale was proposed:
## *"do not make them smaller — if they are too big then let's display
## only 3 at once and have arrows to scroll through graveyard!"* So the
## COUNT gives, never the size: [method cards_across] costs a row out in
## real pixels (`n * 132` + the gaps + both arrows) against the width the
## shelves actually have and answers 5, or 3 when 5 will not fit. On the
## project's 1280x800 canvas the board region leaves 890px and a
## five-card shelf costs 784, so five is what shows; the fallback is there
## for a canvas whose board is narrower than that.
##
## THE ARROWS are the era's own device turned on its side. Manual p.114
## gives an overflowing pile *"scroll arrows at the top"*, and `StackHand`
## wears exactly that ▲/▼ pair on its bar; ours are ◀ / ▶ in the 1997
## three-state button art (`OriginalDialog.button`), one whole page per
## press, DISABLED at the ends and absent altogether from a pile that
## fits, rather than a modern scrollbar. (The manual's scroll *revolves*:
## the top cards cycle to the bottom. Ours clamps, because the position
## counter on the centre card only reads as a position if the ends stay
## put — the QoL half of the same divergence.)

## The dim behind the overlay — s30's `RGBA{0,0,0,160}`, which is 0.63.
const DIM := Color(0, 0, 0, 0.63)
## [QoL] The deeper dim behind the piles themselves (over the board only).
const BACKDROP := Color(0, 0, 0, 0.62)
## How far that backdrop reaches past the piles.
const BACKDROP_BLEED := 8.0
## [QoL] FIVE IN A ROW, and one press of an arrow moves by exactly that.
## THREE is the fallback for a canvas too narrow to hold five FULL-SIZE
## cards — the count gives, the card never does (see [method cards_across]).
const PAGE_WIDE := 5
const PAGE_NARROW := 3
## Space between two cards on the shelf, and between the shelf and its
## arrows. Cards themselves are `MiniCard.SIZE`; nothing here resizes one.
const CARD_GAP := 8
const ARROW_GAP := 12
## The ◀ / ▶ buttons, in the era's own button art: as tall as the cards
## they flank, so the shelf reads as one object.
const ARROW_SIZE := Vector2(34, MiniCard.SIZE.y)
## The piles' inset inside [member board_area], per side.
const INSET := 12.0
## Fallback canvas when the view is asked to lay out before it is on a
## viewport (project.godot, 1280x800).
const CANVAS := Vector2(1280, 800)
## The position plaque on the CENTRE card ("7 / 23"). Sits bottom-centre,
## clear of the P/T at the bottom-right corner (`MiniCard` anchors that at
## x -40..-6, i.e. the last 34px) and of the badge row at bottom-left.
const COUNTER_SIZE := Vector2(48, 16)

## A card in one of the piles was clicked.
signal card_picked(inst: CardInstance)
## The overlay wants to close (a click on the dim, or Escape).
signal dismissed

## The shared enlarged-card preview (owned by the DuelScreen, docked) —
## the SAME big card the hand and the battlefield fill, per the owner's
## "only big preview and mini cards".
var preview: CardPreview = null

## The rectangle (GLOBAL) the piles lay out in: the BOARD, not the whole
## screen. The dim covers everything, s30-style, but the shelves keep off
## the sidebar — the docked `CardPreview` they fill lives there and has to
## stay readable while the pointer walks the pile. The DuelScreen hands
## over its own `_board_area()`; an empty rect means "the whole view".
var board_area := Rect2()

var _backdrop: ColorRect = null
var _scroll: ScrollContainer = null
var _column: VBoxContainer = null
# Last populate() arguments, replayed when an arrow pages a shelf.
var _game: MtgGame = null
var _human := 0
var _legal := Callable()
## Window start index per "zone:pid" shelf, kept across repopulates (a
## taken target rebuilds the view and must not throw the player back to
## the first page). Cleared when the overlay is opened afresh.
var _starts: Dictionary = {}
## Per-shelf render state for the screen and for tests:
## key -> {"start": int, "cards": Array[CardInstance], "widgets": Array,
##         "counter": String, "left": Button, "right": Button}
var _shelves: Dictionary = {}


func _init() -> void:
	name = "GraveyardView"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	z_index = 190          # over the board, under OriginalDialog's 200
	mouse_filter = Control.MOUSE_FILTER_STOP

	var dim := ColorRect.new()
	dim.color = DIM
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(dim)

	# [QoL] A SECOND, deeper dim over the board region alone. s30's single
	# 0.63 black leaves a busy battlefield legible straight through the
	# cards in the pile — the ante shelves in the first capture of this
	# pass sat on top of three summoning-sickness spirals. The sidebar
	# keeps the plain s30 dim so the big card stays where the eye expects.
	_backdrop = ColorRect.new()
	_backdrop.color = BACKDROP
	_backdrop.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_backdrop)

	_scroll = ScrollContainer.new()
	_scroll.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT,
		Control.PRESET_MODE_MINSIZE, INSET)
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	_scroll.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(_scroll)

	_column = VBoxContainer.new()
	_column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_column.add_theme_constant_override("separation", 14)
	_column.mouse_filter = Control.MOUSE_FILTER_PASS
	_scroll.add_child(_column)


## Anywhere outside a card closes the view — s30's "click anywhere outside
## to close" (`duel.go:3715-3733`).
func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed \
			and event.button_index == MOUSE_BUTTON_LEFT:
		dismissed.emit()
		accept_event()


## Forget every shelf's page. The DuelScreen calls this when the overlay is
## OPENED, so a pile always opens on its first five (or, while targeting,
## on the five holding the first legal card) — never wherever the player
## happened to leave it three casts ago.
func reset_paging() -> void:
	_starts.clear()


## Fill the overlay. [param legal] is called per card while the duel is
## targeting and decides whether that card can be picked; pass an invalid
## Callable outside targeting, when every card is merely viewable.
## [param human] is the seat sitting at this screen — the one whose piles
## say "Your".
func populate(game: MtgGame, human: int, legal := Callable()) -> void:
	_game = game
	_human = human
	_legal = legal
	_shelves.clear()
	_place_scroll()
	# Un-parent BEFORE queueing: a queue_free'd child is still in the tree
	# for the rest of the frame, so paging would lay the new shelf out
	# underneath the old one for a frame.
	for child in _column.get_children():
		_column.remove_child(child)
		child.queue_free()
	# @MENU_GRAVEYARD's own order: the graveyard, then exile, then ante.
	for zone in [Mtg.Zone.GRAVEYARD, Mtg.Zone.EXILE, Mtg.Zone.ANTE]:
		for pid in 2:
			var pile := _pile(game, pid, zone)
			if pile.is_empty():
				continue
			_column.add_child(_section(
				section_title(game, pid, human, zone, pile.size())))
			_column.add_child(_shelf(zone, pid, pile, legal))


## `@CUECARD_OTHER` (Program/UIStrings.txt:667) words your own pile in the
## second person and names the opponent's by their name; `@MENU_GRAVEYARD`
## supplies the other two zones' nouns. The count rides in brackets, which
## is how s30 titles its own sections and how our pile labels already read.
static func section_title(game: MtgGame, pid: int, human: int, zone: int,
		count: int) -> String:
	var noun := "graveyard"
	match zone:
		Mtg.Zone.EXILE: noun = "exiled cards"
		Mtg.Zone.ANTE: noun = "ante"
	if pid == human:
		return "Your %s (%d)" % [noun, count]
	return "%s %s (%d)" % [game.players[pid].player_name, noun, count]


static func _pile(game: MtgGame, pid: int, zone: int) -> Array[CardInstance]:
	match zone:
		Mtg.Zone.EXILE:
			return game.players[pid].exile
		Mtg.Zone.ANTE:
			return game.players[pid].ante
	return game.players[pid].graveyard


func _section(text: String) -> Control:
	var head := OriginalDialog.label(text, 16, true)
	head.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	head.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return head


# ------------------------------------------------ the shelf of five [QoL] --

static func _key(zone: int, pid: int) -> String:
	return "%d:%d" % [zone, pid]


## What one shelf of [param count] cards COSTS in pixels, at the cards'
## true `MiniCard.SIZE` — n full cards, the gaps between them, and the two
## arrow buttons with their own gaps. Nothing in this sum is negotiable
## except [param count].
static func shelf_width(count: int) -> float:
	return count * MiniCard.SIZE.x + maxi(count - 1, 0) * CARD_GAP \
		+ 2.0 * (ARROW_SIZE.x + ARROW_GAP)


## How many cards fit across [param available] pixels WITHOUT shrinking
## one: five, or three when five will not fit. Never fewer — three
## full-size cards cost 504, which any canvas we target can hold.
static func cards_across(available: float) -> int:
	return PAGE_WIDE if shelf_width(PAGE_WIDE) <= available else PAGE_NARROW


## Where the shelves actually live (GLOBAL): [member board_area] inset, or
## the whole view when the board is not laid out or is somehow too narrow
## even for three full-size cards.
func _content_rect() -> Rect2:
	var area := board_area
	if area.size.x < shelf_width(PAGE_NARROW) + 2.0 * INSET \
			or area.size.y <= 0.0:
		var whole := CANVAS
		if is_inside_tree() and get_viewport_rect().size.x > 0.0:
			whole = get_viewport_rect().size
		area = Rect2(global_position, whole)
	return Rect2(area.position + Vector2(INSET, INSET),
		area.size - 2.0 * Vector2(INSET, INSET))


## The page size for this view right now, measured off the real width the
## shelves have. FIVE unless that width cannot hold five FULL-SIZE cards.
func page_size() -> int:
	return cards_across(_content_rect().size.x)


## Park the scroll over the board region. Called on every populate, so a
## board that has only just been laid out is picked up.
func _place_scroll() -> void:
	var rect := _content_rect()
	_scroll.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_scroll.position = rect.position - global_position
	_scroll.size = rect.size
	_backdrop.set_anchors_preset(Control.PRESET_TOP_LEFT, true)
	_backdrop.position = _scroll.position - Vector2.ONE * BACKDROP_BLEED
	_backdrop.size = _scroll.size + 2.0 * Vector2.ONE * BACKDROP_BLEED


## Where this shelf's window starts. Clamped so the LAST page is always a
## FULL page (when the pile has that many cards) — a half-empty shelf would
## put the position counter on a hole.
func _window_start(key: String, pile: Array[CardInstance], legal: Callable,
		page: int) -> int:
	var last_start: int = maxi(0, pile.size() - page)
	if _starts.has(key):
		return clampi(int(_starts[key]), 0, last_start)
	# Opening while TARGETING: land on the page that holds the first legal
	# card, in the CENTRE slot, rather than making the player page through
	# thirty corpses looking for the one Raise Dead will take.
	if legal.is_valid():
		for i in pile.size():
			if bool(legal.call(pile[i])):
				return clampi(i - page / 2, 0, last_start)
	return 0


func _shelf(zone: int, pid: int, pile: Array[CardInstance],
		legal: Callable) -> Control:
	var key := _key(zone, pid)
	var page := page_size()
	var start := _window_start(key, pile, legal, page)
	_starts[key] = start
	var shown: Array[CardInstance] = []
	for i in range(start, mini(start + page, pile.size())):
		shown.append(pile[i])
	# The counter rides the MIDDLE of what is on screen, so it is a fixed
	# reading position as the pile pages under it.
	var centre: int = shown.size() / 2
	var counter := "%d / %d" % [start + centre + 1, pile.size()]

	var row := HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation", ARROW_GAP)
	row.mouse_filter = Control.MOUSE_FILTER_PASS

	# ARROWS ONLY WHEN THE PILE OVERFLOWS — manual p.114 gives them to a
	# list with *"too many cards to display all at once"*, and a pile of
	# three has nowhere to go. The one that cannot move is DISABLED rather
	# than missing, so the pair never jumps about while you page.
	var pages := pile.size() > page
	var left: Button = null
	var right: Button = null
	if pages:
		left = _arrow("◀", zone, pid, -1, start > 0)
		row.add_child(left)

	var cards := HBoxContainer.new()
	cards.alignment = BoxContainer.ALIGNMENT_CENTER
	cards.add_theme_constant_override("separation", CARD_GAP)
	cards.mouse_filter = Control.MOUSE_FILTER_PASS
	# A full page's worth of room whatever the shelf holds, so every
	# section's cards line up on the same axis down the overlay.
	cards.custom_minimum_size.x = page * MiniCard.SIZE.x \
		+ maxi(page - 1, 0) * CARD_GAP
	var widgets: Array = []
	for i in shown.size():
		var card := _card(shown[i], legal, counter if i == centre else "")
		widgets.append(card)
		cards.add_child(card)
	row.add_child(cards)

	if pages:
		right = _arrow("▶", zone, pid, 1,
			start < maxi(0, pile.size() - page))
		row.add_child(right)

	_shelves[key] = {"start": start, "cards": shown, "widgets": widgets,
		"counter": counter, "left": left, "right": right}
	return row


## ONE MINI CARD, at MiniCard's own size — the container gives it exactly
## its minimum, and nothing here touches its aspect. [param counter] is the
## position plaque, drawn only on the centre card of the five.
func _card(inst: CardInstance, legal: Callable, counter: String) -> MiniCard:
	# The row must never stretch a card into a shape mini_card.gd did not
	# lay itself out for. That used to be set here, card by card; since the
	# fortieth pass [method MiniCard._init] shrinks on both axes itself, so
	# no caller anywhere can forget it.
	var card := MiniCard.new(inst)
	# THE THIRD PLACE THE FACE-DOWN FLAG HAS TO BE CARRIED, and the one
	# `docs/card-states.md` §5.1 did not name. `MtgGame.exile_top_of_library`
	# (Knowledge Vault) exiles FACE DOWN, and the exile plate and its
	# tooltip already keep it shut — the plate stays a plate, the tooltip
	# reads `(face down)`. Opening the viewer named it anyway. Nobody may
	# look at a card exiled face down, so nobody does.
	card.face_down = inst.face_down
	# s30 OUTLINES a legal target and leaves an illegal one plain
	# (`duel.go:3699-3712`); ours reuses the board's own target tint AND
	# CardPile's 2px ring. The tint alone is a modulate on the imported
	# frame texture, and the capture for this pass showed it reading as
	# almost nothing on a red card — which on the one screen whose whole
	# job is picking a target is the wrong thing to be subtle about.
	if legal.is_valid() and bool(legal.call(inst)):
		card.set_highlight(MiniCard.Highlight.TARGET)
		card.add_child(_target_ring())
	card.pressed.connect(func() -> void: card_picked.emit(inst))
	# The big card in the sidebar, exactly as the hand and the battlefield
	# fill it (CardPile._on_card_hover) — one preview for the whole duel.
	card.mouse_entered.connect(_on_card_hover.bind(inst, card))
	card.mouse_exited.connect(_on_card_leave.bind(card))
	if counter != "":
		card.add_child(_counter_plaque(counter))
	return card


## The 2px ring round a card the pending spell can legally take — s30's
## own outline (`duel.go:3699-3712`), drawn exactly as `CardPile` draws it
## for a target on the battlefield.
func _target_ring() -> Control:
	var ring := Panel.new()
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0)
	box.border_color = MiniCard.HIGHLIGHT_COLORS[MiniCard.Highlight.TARGET]
	box.set_border_width_all(2)
	ring.add_theme_stylebox_override("panel", box)
	ring.set_anchors_preset(Control.PRESET_FULL_RECT)
	ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	ring.z_index = 4
	return ring


## The position plaque: "7 / 23" — which card of the whole pile the CENTRE
## card is. [QoL], and the reason the window pages by exactly five.
func _counter_plaque(text: String) -> Control:
	var plaque := Panel.new()
	plaque.anchor_left = 0.5
	plaque.anchor_right = 0.5
	plaque.anchor_top = 1.0
	plaque.anchor_bottom = 1.0
	plaque.offset_left = -COUNTER_SIZE.x / 2.0
	plaque.offset_right = COUNTER_SIZE.x / 2.0
	plaque.offset_top = -(COUNTER_SIZE.y + 3.0)
	plaque.offset_bottom = -3.0
	var box := StyleBoxFlat.new()
	box.bg_color = Color(0, 0, 0, 0.74)
	box.border_color = MiniCard.ART_BEVEL      # the frames' own gold bevel
	box.set_border_width_all(1)
	box.set_corner_radius_all(3)
	plaque.add_theme_stylebox_override("panel", box)
	plaque.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.z_index = 3                          # over the art and the P/T
	var label := Label.new()
	label.text = text
	label.set_anchors_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size", 11)
	label.add_theme_color_override("font_color", Color(1.0, 0.90, 0.30))
	label.add_theme_color_override("font_shadow_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("shadow_offset_x", 1)
	label.add_theme_constant_override("shadow_offset_y", 1)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	plaque.add_child(label)
	return plaque


## One scroll arrow, in the 1997 three-state button art
## (`OriginalDialog.button` — `button_normal/pressed/disabled.pic`, the
## same face every dialog in the duel wears; the Situation Bar's stone was
## tried first and tiles into a barber pole at this tall, narrow shape).
## DEFERRED because the press rebuilds the shelf the button lives on.
func _arrow(glyph: String, zone: int, pid: int, delta: int,
		enabled: bool) -> Button:
	var btn := OriginalDialog.button(glyph, ARROW_SIZE)
	btn.add_theme_font_size_override("font_size", 20)
	btn.disabled = not enabled
	btn.focus_mode = Control.FOCUS_NONE
	btn.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	btn.pressed.connect(func() -> void: step(zone, pid, delta),
		CONNECT_DEFERRED)
	return btn


## Page one shelf by [param delta] whole pages, clamped. Public so the
## arrows and the tests take the same path.
func step(zone: int, pid: int, delta: int) -> void:
	if _game == null:
		return
	var pile := _pile(_game, pid, zone)
	var page := page_size()
	var last_start: int = maxi(0, pile.size() - page)
	_starts[_key(zone, pid)] = clampi(
		page_start(zone, pid) + delta * page, 0, last_start)
	populate(_game, _human, _legal)


## Index of the first card on screen for a shelf.
func page_start(zone: int, pid: int) -> int:
	return int(_starts.get(_key(zone, pid), 0))


## The cards a shelf is showing right now (at most [method page_size]).
func shown(zone: int, pid: int) -> Array:
	var state: Dictionary = _shelves.get(_key(zone, pid), {})
	return state.get("cards", [])


## The MiniCard widgets a shelf is showing (screenshot checks and tests).
func widgets(zone: int, pid: int) -> Array:
	var state: Dictionary = _shelves.get(_key(zone, pid), {})
	return state.get("widgets", [])


## What the centre card's position plaque reads, e.g. `7 / 23`.
func counter_text(zone: int, pid: int) -> String:
	var state: Dictionary = _shelves.get(_key(zone, pid), {})
	return state.get("counter", "")


## Is there anywhere to page in this direction? (The arrow's enabled state.)
func can_page(zone: int, pid: int, delta: int) -> bool:
	if _game == null:
		return false
	var pile := _pile(_game, pid, zone)
	var start := page_start(zone, pid)
	if delta < 0:
		return start > 0
	return start < maxi(0, pile.size() - page_size())


# ------------------------------------------------------- hover → preview --

## The original's list lights the row under the pointer and fills the
## docked enlarged card with it — CardPile does exactly this, and the pile
## on this screen must behave the same way. [param card] is UNTYPED for
## CardPile's reason: a queued mouse_exited can arrive after a repopulate
## has freed the widget it was bound to.
func _on_card_hover(inst: CardInstance, card: Variant) -> void:
	if is_instance_valid(card):
		card.hovered = true
	if preview != null:
		preview.show_card(inst)


func _on_card_leave(card: Variant = null) -> void:
	if is_instance_valid(card):
		card.hovered = false
	if preview != null and not preview.docked:
		preview.visible = false
