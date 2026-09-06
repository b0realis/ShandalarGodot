class_name OpeningWindow
extends Control
## THE 1997 OPENING WINDOW — one panel, on the classical line-art ground,
## carrying everything `@DIALOG_MULLIGAN` (`Program/UIStrings.txt:499`)
## lists: who takes the first turn, what the opponent just did about their
## hand, BOTH ANTES as full cards, and the two buttons `Take mulligan` /
## `Start the duel` (docs/duel-todo.md §6.2, §6.19).
##
## THE COMPOSITION is the owner's 1997 screenshot, region for region:
##
##     ┌──────────────────────────────────────────────────────────┐
##     │ You will take the first turn   Cromer has no land and    │
##     │                                chose to take a mulligan  │
##     │   Your ante:      Cromer ante:                           │
##     │ ┌───────────┐   ┌───────────┐                            │
##     │ │  Animate  │   │  Mountain │      the two standing      │
##     │ │   Dead    │   │           │      figures, uncovered    │
##     │ └───────────┘   └───────────┘                            │
##     │            [ Take mulligan ]  [ Start the duel ]         │
##     └──────────────────────────────────────────────────────────┘
##
## ONE WINDOW, not two — and that is OURS, `[QoL]`. 1997 had two: DIALOG
## resource 244 (`@DIALOG_PLAYORDRAW`, `Play first` / `Draw first`, no OK)
## on `Winbk_Startduel2.pic`, then resource 227 (`@DIALOG_MULLIGAN`, both
## antes, `Mulligan`, `Start the duel` as IDOK) on the ground below. We
## compose a single window that opens after the coin toss and asks each
## question in its own button row while the antes stay on screen the whole
## time — which is what makes the ante *visible before the first card is
## played*, §6.19's whole point, from the first frame rather than from the
## second window. Because they are up all along, choosing the order ends
## the opening (docs/duel-todo.md §6.2, "THE COMPOSITION CLAIM ABOVE IS
## WRONG"); `Start the duel` is still the row for every other ending.
##
## THE GROUND is `Winbk_Startduel.pic` (imported as `versus_background`,
## 659x394) — the four classical mourning figures. It is a PICTURE, so its
## middle stretches rather than tiles, and the window is sized to the
## picture's OWN ASPECT (1.672) so that stretch is uniform and the figures
## are never squashed. See [constant SIZE].
##
## THE CARDS ARE NEVER RESCALED (the one-card-size rule, design doc
## fortieth pass): each ante is a full [CardPreview] at its own
## `CardPreview.SIZE`, and the panel is sized around them.

## The ground's native pixels, measured on `assets/original/versus_background.png`:
## 659x394, with a 3px dithered highlight along top+left and 3px of shadow
## along bottom+right (hence OriginalDialog.PANELS' patch margin of 4).
const GROUND := Vector2(659.0, 394.0)

## The head band: two lines of 15px type, so the window never changes
## height when the opponent's status line arrives or wraps.
const HEAD_HEIGHT := 44.0
## The `Your ante:` / `%s ante:` caption above each card.
const CAPTION_HEIGHT := 20.0
## Between the caption and its card, and between the two cards.
const CAPTION_GAP := 4.0
const CARD_GAP := 28.0
## OriginalDialog.create's own column: 16px margin all round, 10px between
## body and button row. The button row is a 26px button plus its 6px
## content margins.
const COLUMN_MARGIN := 16.0
const COLUMN_SEPARATION := 10.0
const BODY_SEPARATION := 8.0
## THE BUTTON AT ITS OWN NATIVE SIZE. `Winbk_Startduelbutton*.pic` is
## 131x36 — the era's only generic button art and therefore the era's
## button size (OriginalDialog's header measures it). A dialog button
## defaults to 96x26 and `Take mulligan` then crowds its own bevel; this
## window is the one place that art is at home, so it uses the full plate.
const BUTTON_SIZE := Vector2(131.0, 36.0)
const BUTTON_ROW_HEIGHT := 38.0

## THE WINDOW'S SIZE, derived — nothing here is a taste decision.
##
## HEIGHT is what the content costs, and the content is dominated by a
## full-size card that may not shrink:
##   16 margin + 44 head + 8 + (20 caption + 4 + 428 card) + 10 + 38 button
##   + 16 margin = 584.
## WIDTH is then whatever keeps the ground's aspect (584 * 659/394 = 977),
## which is comfortably more than the 660 the two cards and their margins
## actually need, and the picture scales uniformly (1.48x) instead of being
## stretched into a different shape.
##
## WHERE THE SLACK GOES — all of it to the RIGHT. The two cards are packed
## against the left margin rather than centred, because the ground is not
## a symmetrical picture: `Winbk_Startduel.pic`'s upper-left quadrant is
## bare speckle, and its subject — the two standing mourning women, the
## best-drawn things in the file — is in the right third. Centring split
## the 317px of slack into two 152px slivers and buried both women behind
## the ante cards; packing left spends the whole 317 on the one side that
## has something to show, and covers only the empty corner. The reclining
## figure at bottom-left goes under the cards either way (she is 193-534
## and a centred left card already started at 320).
##
## 977x584 fits inside BOTH supported window sizes with room to spare:
## 1280x800 leaves 151px each side and 108 above and below; 1280x720 leaves
## the same 151 and 68. Pinned by tests/ui/test_opening_hand.gd.
const SIZE := Vector2(
	roundf((COLUMN_MARGIN * 2.0 + HEAD_HEIGHT + BODY_SEPARATION
		+ CAPTION_HEIGHT + CAPTION_GAP + CardPreview.SIZE.y
		+ COLUMN_SEPARATION + BUTTON_ROW_HEIGHT) * GROUND.x / GROUND.y),
	COLUMN_MARGIN * 2.0 + HEAD_HEIGHT + BODY_SEPARATION
		+ CAPTION_HEIGHT + CAPTION_GAP + CardPreview.SIZE.y
		+ COLUMN_SEPARATION + BUTTON_ROW_HEIGHT)

## Which button ended the wait.
enum Answer { PLAY_FIRST, DRAW_FIRST, TAKE_MULLIGAN, START }

## Emitted every time a button is pressed, with an [enum Answer].
signal answered(answer: int)

var _dialog: OriginalDialog = null
var _lead: Label = null
var _status: Label = null
var _captions: Array[Label] = []
var _cards: Array[CardPreview] = []
var _buttons: Array[Button] = []
## What each slot is currently showing, or null for a card back.
var _shown: Array = [null, null]
var _pressed := -1

## Bumped by every [method set_status] — the caller uses it to tell "the
## opponent has done something since your last press" from "nothing has
## happened", which decides whether the window owes you a last look.
var status_serial := 0


func _init() -> void:
	name = "OpeningWindow"
	set_anchors_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	_dialog = OriginalDialog.create("", SIZE, "versus_background")
	add_child(_dialog)

	# --- the head band: who leads (left), what they just did (right) ---
	var head := HBoxContainer.new()
	head.custom_minimum_size.y = HEAD_HEIGHT
	head.add_theme_constant_override("separation", 24)
	_lead = OriginalDialog.ink_label("", 16)
	_lead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_lead.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_lead.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	head.add_child(_lead)
	_status = OriginalDialog.ink_label("", 16)
	_status.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_status.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	head.add_child(_status)
	_dialog.body().add_child(head)

	# --- the two antes, side by side, each a full card ---
	# PACKED LEFT, not centred: see [constant SIZE]'s note on the ground.
	var antes := HBoxContainer.new()
	antes.alignment = BoxContainer.ALIGNMENT_BEGIN
	antes.add_theme_constant_override("separation", int(CARD_GAP))
	antes.size_flags_vertical = Control.SIZE_EXPAND_FILL
	for _seat in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", int(CAPTION_GAP))
		var caption := OriginalDialog.ink_label("", 15)
		caption.custom_minimum_size = Vector2(CardPreview.SIZE.x, CAPTION_HEIGHT)
		caption.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		column.add_child(caption)
		_captions.append(caption)
		var card := CardPreview.new()
		# Docked: the preview must sit where this layout puts it and stay
		# there — an undocked one re-centres itself on the viewport every
		# time it is filled.
		card.docked = true
		card.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		card.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		column.add_child(card)
		_cards.append(card)
		antes.add_child(column)
	_dialog.body().add_child(antes)


## Fill the two ante slots from [param viewer]'s point of view — the seat
## sitting at this screen, whose pile is the one that says `Your`.
## `@DIALOG_MULLIGAN` entries 3-4 (identical to `@DIALOG_VIEWANTES`,
## `UIStrings.txt:588`) are the only two captions the original has.
##
## An empty ante (a duel not played for ante) shows the card BACK and no
## caption, so the window still reads as the original's window.
func show_antes(game: MtgGame, viewer: int) -> void:
	for seat in 2:
		var pid := viewer if seat == 0 else game.opponent_of(viewer)
		var pile: Array[CardInstance] = game.players[pid].ante
		var caption: Label = _captions[seat]
		var card: CardPreview = _cards[seat]
		if pile.is_empty():
			caption.text = ""
			_shown[seat] = null
			card.show_back()
			continue
		caption.text = OpeningHand.MULLIGAN["your_ante"] if pid == viewer \
			else OpeningHand.MULLIGAN["their_ante"] % game.players[pid].player_name
		# The stake is one card in every duel we deal; a bigger stake shows
		# its top card here and the rest through `View both antes`.
		_shown[seat] = pile[0]
		card.show_card(pile[0])


## `@DIALOG_MULLIGAN` entries 1-2 — the window's first line.
func set_lead(text: String) -> void:
	_lead.text = text


## The opponent's latest word (entries 5-10), in the head band's right half.
func set_status(text: String) -> void:
	_status.text = text
	status_serial += 1


## Put a fresh button row up and wait for a press, returning the [enum
## Answer] that was pressed. Each entry of [param answers] is
## `{"answer": <Answer>, "label": <1997 string>, "disabled": <bool>}` — a
## button the player may not use is DISABLED rather than removed, because
## the original's window always shows both of its buttons.
func ask(answers: Array) -> int:
	# Un-parent BEFORE queueing: a queue_free'd child is still in the tree
	# for the rest of the frame, so the old row would lay out beside the
	# new one for a frame (the same trap CardPreview documents).
	for btn in _buttons:
		btn.get_parent().remove_child(btn)
		btn.queue_free()
	_buttons.clear()
	_pressed = -1
	for entry in answers:
		var answer: int = entry["answer"]
		var btn := _dialog.add_button(entry["label"])
		btn.custom_minimum_size = BUTTON_SIZE
		btn.disabled = bool(entry.get("disabled", false))
		btn.pressed.connect(func() -> void:
			_pressed = answer
			answered.emit(answer))
		_buttons.append(btn)
	while _pressed < 0 and is_inside_tree():
		await get_tree().process_frame
	return _pressed


## The window is done; fade it away rather than snapping it off.
func close() -> void:
	if not is_inside_tree():
		queue_free()
		return
	var fade := create_tween()
	fade.tween_property(self, "modulate:a", 0.0, 0.2)
	await fade.finished
	queue_free()


## Test seam: the two ante captions, viewer's slot first.
func caption_texts() -> PackedStringArray:
	var out := PackedStringArray()
	for caption in _captions:
		out.append(caption.text)
	return out


## Test seam: the card in each ante slot, "" for a card back.
func card_names() -> PackedStringArray:
	var out := PackedStringArray()
	for inst in _shown:
		out.append("" if inst == null else (inst as CardInstance).data.card_name)
	return out


## Test seam: the head band's two halves.
func lead_text() -> String:
	return _lead.text


func status_text() -> String:
	return _status.text


## Test seam: the live button labels, in order.
func button_labels() -> PackedStringArray:
	var out := PackedStringArray()
	for btn in _buttons:
		out.append(btn.text)
	return out


## Test seam: press the button carrying [param label]. Returns false when
## no such button is up.
func press(label: String) -> bool:
	for btn in _buttons:
		if btn.text == label and not btn.disabled:
			btn.pressed.emit()
			return true
	return false
