class_name TreasureSwapBuilder
extends AdventureBuilder
## A CARD FOUND WITH THE BAG FULL (part C, stage C2) — [ours, the owner's
## ruling D12 of 2026-10-27: *"Ask to swap — offer to leave one of the
## hero's cards behind for it, in the deck builder"*]. 1997 wrote a card
## found in a dungeon's dead end past a full bag (500 cards) and it was lost
## to the game for good — one of the 28 unique treasures (`AddCardToDeck-
## Sorted`, duel.c 1859–1867; [DungeonBoard]'s slip N5). Here the board's
## pane ([DungeonPane]) opens the adventure's deck builder over the world
## ([AdventureBuilder]) to choose the card to leave in its place:
##  - it only looks, as the spellbook does (nothing moves between the decks
##    inside a dungeon — 1997 opened no builder there at all); the well's
##    line says what it is for ([constant PICK]);
##  - "Leave it here", by Done on the command row, acts on the card on
##    show (the one under the pointer): pressed once it asks "Sure? Leave
##    it" and the well names the card, pressed again — a press of its own,
##    never a double click's second (part C stage C3, h5-1) — the card is
##    left — [signal swapped] with the copy's place in the hero's
##    cards ([method give_up_index]: a copy in no deck first, then one the
##    deck on show does not hold, else the last), which the pane hands to
##    [method DungeonBoard.treasure_swap] (the card left STAYS IN THE
##    DUNGEON as its treasure, the owner's ruling of round C1);
##  - Done, or its menu's "Keep my cards", closes it with nothing left
##    ([signal AdventureBuilder.closed]): the pane asks again;
##  - the window closed from it ends the game unsaved ([signal
##    AdventureBuilder.exit_requested]), as the world's own close on the
##    board: the adventure was saved at the door.

## The card at [param give_up] in the hero's cards is left in the dungeon.
signal swapped(give_up: int)

## The well's line while the builder is up (it fits the well, as the
## spellbook's: measured in the running game).
const PICK := "Bag full: leave a card here for %s."
## The button's words, and asking once more; the line then.
const LEAVE_IT := "Leave it here"
const SURE := "Sure? Leave it"
const PRESS_AGAIN := "Leave %s here for %s? Press again."
## The menu's way back to the board.
const KEEP := "Keep my cards"
## The button's width: the town builder's Sell button's, so Done stays on
## the row.
const BUTTON_WIDE := 150.0

## The card found, waiting.
var found_card := ""
var _leave_button: Button
## The card the button asks "Sure?" about ("" none).
var _armed := ""
var _left := false


func _ready() -> void:
	looking = true
	super._ready()
	_say(PICK % found_card)
	_status_label.tooltip_text = PICK % found_card


func _before_first_fill() -> void:
	super._before_first_fill()
	_leave_button = OriginalDialog.button(LEAVE_IT, Vector2(BUTTON_WIDE, COMMAND_BAR_H))
	_leave_button.name = "LeaveButton"
	_leave_button.disabled = true
	_leave_button.pressed.connect(func() -> void: leave(_shown_card()))
	# A double click's second press is no second press (part C stage C3,
	# h5-1: it left the card without the player ever reading "Press
	# again."), as on the panes' own buttons (part B's q2-2).
	_leave_button.gui_input.connect(func(input: InputEvent) -> void:
		var press := input as InputEventMouseButton
		if press != null and press.double_click:
			_leave_button.accept_event())
	_command_row.add_child(_leave_button)
	_command_row.move_child(_leave_button, _command_row.get_node("DoneButton").get_index())


## The card on show ("" none).
func _shown_card() -> String:
	return _showcase._shown.data.card_name if _showcase != null and _showcase._shown != null else ""


func _show_in_showcase(data: CardData) -> void:
	super._show_in_showcase(data)
	_point_at(data.card_name)


## The button made for [param card_name]: ready for a card the hero owns,
## asking "Sure?" for the one it asked about.
func _point_at(card_name: String) -> void:
	if _leave_button == null:
		return
	if card_name != _armed:
		_armed = ""
	var owned := give_up_index(player, card_name, _slot) >= 0
	_leave_button.disabled = not owned
	_leave_button.text = SURE if owned and _armed == card_name else LEAVE_IT
	_leave_button.tooltip_text = ("Leave %s here" % card_name) if owned else ""


## LEAVE [param card_name] HERE (the button): once it asks, the second time
## it is left — [signal swapped] with the copy's place. False while asking,
## or for a card the hero does not own.
func leave(card_name: String) -> bool:
	if _left or card_name == "":
		return false
	var at := give_up_index(player, card_name, _slot)
	if at < 0:
		return false
	if _armed != card_name:
		_armed = card_name
		_point_at(card_name)
		_say(PRESS_AGAIN % [card_name, found_card])
		return false
	_left = true
	swapped.emit(at)
	return true


## THE COPY OF [param card_name] TO LEAVE among [param hero]'s cards: one in
## no deck first, then one deck [param slot] does not hold, else the last;
## −1 for a card the hero does not own.
static func give_up_index(hero: AdventurePlayer, card_name: String, slot: int) -> int:
	var owned: Array[int] = []
	for i in hero.cards.size():
		if String((hero.cards[i] as Dictionary).get("card", "")) == card_name:
			owned.append(i)
	if owned.is_empty():
		return -1
	for i in owned:
		if ((hero.cards[i] as Dictionary).get("decks", []) as Array).is_empty():
			return i
	for i in owned:
		if not ((hero.cards[i] as Dictionary).get("decks", []) as Array).has(slot):
			return i
	return owned[owned.size() - 1]


## The line kept in the well: what the builder is for.
func _resting_line() -> String:
	return PICK % found_card


## Nothing moves here: the line again instead of the spellbook's.
func _refuse_change() -> bool:
	_say(PICK % found_card, true)
	return true


func _menu_entries() -> Array[String]:
	return [MENU_BACK, KEEP]


func _run_menu_entry(label: String) -> void:
	if label == KEEP:
		_close_deck_menu()
		_exit()
		return
	super._run_menu_entry(label)
