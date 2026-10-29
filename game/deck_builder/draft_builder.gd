class_name DraftBuilder
extends DeckBuilderScreen
## [QoL] The ordinary builder with one pool, one slot and no outside-card doors.
## Both colour moves are here (2026-10-28): the dealt pool is a collection,
## so `Move by color into deck` moves the dealt copies, as 1997's adventure
## moved the hero's.

signal finish_requested

const ALLOWED: Array[String] = ["Consolidate duplicate cards", "Clear deck", "Restore deck",
	"Sort deck", "Stats", "Music", "Sound Effects", "Move by color into deck",
	"Move by color out of deck", "Filters", "Undo", "Redo", "Big cards", "Add basic land",
	"Deck notes", "Sideboard", "Save deck", "Exit deck builder"]
var draft_counts: Dictionary = {}
var input_guard := Callable()


func _ready() -> void:
	# This screen is constructed in code, not from the ordinary builder's
	# full-rect .tscn. Set offsets too or the editing surface remains 0×0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	super._ready()
	# The pool's own line, the last word of the opening, as
	# [method DeckBuilderScreen._enter_sealed] says it.
	_say("Sealed Deck — %s" % sealed.summary())


## THE DEALT POOL GOES IN BEFORE THE FIRST FILL (adventure campaign fix
## pass 2026-10-23, h5-10). Put in after `super._ready()`, as it was, it
## came after the builder had filtered, sorted and drawn the whole library
## (120 ms with every card pack on) and was then walked twice more. Here
## the Inventory is filled once, by the screen's own first refresh, from
## the pool. A fresh builder's deck is empty, so there is nothing for
## `_enter_sealed`'s fresh start to clear.
func _before_first_fill() -> void:
	var pool := SealedPool.new()
	pool.counts = draft_counts.duplicate()
	_put_pool_in_force(pool)
	deck.deck_name = "Booster Draft"
	for button in _slot_buttons:
		button.hide()
	_command_row.get_node("LoadButton").hide()
	_dice_button.disabled = true
	_dice_button.tooltip_text = "Your dealt pool is locked for this session."
	_pool_button.disabled = true
	_pool_button.tooltip_text = _dice_button.tooltip_text


# --- campaign 2026-10-12 f-deck: the dealt shelf and the draft's title ---

## THE DEALT POOL IS NOT FILTERED BY THE ORDINARY BUILDER'S EXTRAS. Those
## switches are remembered for the whole-library Inventory
## ([constant DeckBuilderScreen.EXTRAS_SETTING]); restored here they hid
## every dealt card of a source switched off last time ("1997" off: a
## base-set draft showed 0 pool cards while the clock ran, and nothing said
## why). A draft opens with every source on, as an untouched builder does.
func _restore_extras() -> void:
	_saved_extras = _extras_state()


## ...and whatever the Extras window does during a draft stays in the
## draft: the ordinary builder's remembered switches are not written.
func _remember_extras() -> void:
	pass


## `Clear deck` empties the piles and KEEPS THE DRAFT'S TITLE: [method
## DeckModel.clear] renames a cleared deck `New Deck`, and the draft's
## checkpoints then saved it — and Load deck and Magic Battle listed it —
## under that name instead of `Draft <date time>`.
func _clear_deck() -> void:
	var title := deck.deck_name
	super._clear_deck()
	if deck.deck_name == DeckModel.DEFAULT_NAME and title != DeckModel.DEFAULT_NAME:
		deck.deck_name = title
		refresh()


func _deck_rect() -> Rect2:
	var area := super._deck_rect()
	area.position.y += 60.0
	area.size.y = maxf(0, area.size.y - 60.0)
	return area


func _command_labels() -> Array[String]:
	return ALLOWED.duplicate()


func _run_command(label: String) -> void:
	if input_guard.is_valid() and input_guard.call(): return
	if not ALLOWED.has(label):
		_say("This draft uses only your dealt cards and one deck.", true)
		return
	super._run_command(label)


func _input(event: InputEvent) -> void:
	# Godot dispatches child input before the parent's. The Enter handler
	# must check the deadline itself, not wait for DraftSession._input.
	if input_guard.is_valid() and input_guard.call():
		get_viewport().set_input_as_handled()
		return
	super._input(event)


func _sealed_refusal(card_name: String) -> String:
	if input_guard.is_valid() and input_guard.call(): return "The draft is finished."
	return super._sealed_refusal(card_name)


func _switch_slot(_index: int) -> void:
	pass


func _on_dice_pressed() -> void:
	_dice_button.set_pressed_no_signal(true)


func _leave_sealed() -> void:
	pass


func _open_deck_menu() -> void:
	_open_mini_menu()


func _save_deck(_then := Callable()) -> void:
	finish_requested.emit()


func _exit() -> void:
	finish_requested.emit()


func _quit_game() -> void:
	finish_requested.emit()
