class_name AdventureBuilder
extends DeckBuilderScreen
## THE ADVENTURE'S DECK BUILDER (the owner, 2026-10-23: *"deckbuilder for
## the player — the deck builder should be adapted to adventure mode where
## cards on the bottom are player stack accumulated during play! (Extras
## button absent, and any other conflicting buttons). We should add
## information to the top left deck name pane in the adventure deck builder
## with GOLD and amount of player gold"*). The ordinary builder over the
## hero's own cards, as the 1997 game opened its deck builder in the
## adventure (`DeckBuilderMain`, `DBFLAGS_SHANDALAR`):
##  - the Inventory is the hero's collection ([member AdventurePlayer.cards]),
##    less the copies the deck on the surface holds — the sealed pool's
##    machinery ([SealedPool]), so no deck holds more copies than the hero
##    owns;
##  - the three slots are the hero's three decks (1997 marks each owned
##    copy with the decks it is in, so a copy may be in more than one); the
##    deck in use is the one on the surface when the builder closes;
##  - no door to a card the hero does not own: no Extras, Load, sealed
##    dice, AutoDeck pool, proxies, import, new decks, drafts or sideboard;
##  - the title slab says the deck's name — a click renames it (the owner:
##    *"the deck 1 name can also be renamed"*), and the hero keeps the name
##    with the deck — and the hero's gold in words, "GOLD: %d", as the 1997
##    builder's title field said it (`@GOLDTITLE`);
##  - the duplicate limit counts Tome of Enlightenment.
## Done, or Escape's Return to the world, writes the decks back to the
## hero ([method write_back]) and closes it ([signal closed]).

## The builder is done: the decks are written back to the hero.
signal closed
## The game is to end (Exit game, the window's close): the decks written
## back, the world saves and quits.
signal exit_requested

const ALLOWED: Array[String] = ["Consolidate duplicate cards", "Clear deck", "Restore deck",
	"Sort deck", "Stats", "Music", "Sound Effects", "Extra Cards", "Move by color out of deck",
	"Filters", "Undo", "Big cards", "Copy deck to", "Deck notes", "Save deck", "Exit deck builder"]
const BACK_TO_WORLD := "Return to the world"
const NOT_HERE := "The adventure's decks are built from your own cards."
## The 1997 adventure builder's title field (`@GOLDTITLE`).
const GOLD_TITLE := "GOLD: %d"

var player: AdventurePlayer
var _gold: Label
var _written := false


func _ready() -> void:
	# Made in code, not from the builder's full-rect .tscn: offsets too, or
	# the surface stays 0 × 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	super._ready()
	var pool := SealedPool.new()
	pool.counts = owned_counts(player)
	for i in SLOTS:
		var model := DeckModel.new()
		model.deck_name = deck_title(player, i)
		model.notes = player.deck_notes[i] if i < player.deck_notes.size() else ""
		var held := in_deck(player, i)
		for card_name in held:
			for copy in int(held[card_name]):
				model.add(card_name)
		_slots[i] = model
		_slot_dirty[i] = false
	_slot = clampi(player.current_deck, 0, SLOTS - 1)
	deck = _slots[_slot]
	_dirty = false
	_enter_sealed(pool, false)
	for door in ["LoadButton", "ExtrasButton"]:
		var button := _command_row.get_node_or_null(door) as Control
		if button != null:
			button.hide()
	_dice_button.hide()
	_pool_button.hide()
	_build_gold()
	refresh()
	_say("Your cards: %d · in this deck %d" % [player.cards.size(), deck.total()])


# --------------------------------------------------- the hero's cards --

## `{name: copies}` the hero owns.
static func owned_counts(hero: AdventurePlayer) -> Dictionary:
	var counts := {}
	for card in hero.cards:
		var card_name := String((card as Dictionary).get("card", ""))
		if card_name != "":
			counts[card_name] = int(counts.get(card_name, 0)) + 1
	return counts


## `{name: copies}` in the hero's deck [param slot] (0–2).
static func in_deck(hero: AdventurePlayer, slot: int) -> Dictionary:
	var counts := {}
	for card in hero.cards:
		var entry := card as Dictionary
		if (entry.get("decks", []) as Array).has(slot):
			var card_name := String(entry.get("card", ""))
			counts[card_name] = int(counts.get(card_name, 0)) + 1
	return counts


## The name deck [param slot] goes by.
static func deck_title(hero: AdventurePlayer, slot: int) -> String:
	var titled := String(hero.deck_names[slot]) if slot < hero.deck_names.size() else ""
	return titled if titled != "" else "Deck %d" % (slot + 1)


## THE DECKS BACK TO THE HERO: each owned copy marked with the decks that
## hold it (the first copies of a card go to the decks first), the deck on
## the surface the deck in use, the names kept.
func write_back() -> void:
	_slots[_slot] = deck
	var copies := {}
	for i in player.cards.size():
		var card_name := String((player.cards[i] as Dictionary).get("card", ""))
		if not copies.has(card_name):
			copies[card_name] = []
		(copies[card_name] as Array).append(i)
	for card_name in copies:
		# A card the game does not know now (its pack switched off) was
		# never on the surface: its copies keep the decks they were in.
		if not CardRegistry.has_card(card_name):
			continue
		var held: Array = copies[card_name]
		for k in held.size():
			var decks: Array[int] = []
			for slot in SLOTS:
				if k < (_slots[slot] as DeckModel).count_of(card_name):
					decks.append(slot)
			player.cards[held[k]]["decks"] = decks
	player.current_deck = _slot
	for slot in SLOTS:
		var title := (_slots[slot] as DeckModel).deck_name
		player.deck_names[slot] = "" if title == "Deck %d" % (slot + 1) else title
		player.deck_notes[slot] = (_slots[slot] as DeckModel).notes
	_written = true


# ------------------------------------------------------- the gold --

## The hero's gold on the title slab, under the deck's name, in words
## only (the owner: *"remove the gold icon from deck builder — only
## writing"*).
func _build_gold() -> void:
	_header_label.anchor_bottom = 0.62
	_header_label.offset_bottom = 0
	_header_label.add_theme_font_size_override("font_size", 16)
	_gold = OriginalDialog.label("", 15, true)
	_gold.name = "Gold"
	_gold.anchor_top = 0.56
	_gold.anchor_right = 1.0
	_gold.anchor_bottom = 1.0
	_gold.offset_bottom = -3
	_gold.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_gold.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_gold.add_theme_color_override("font_color", WorldHud.GOLD)
	_gold.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_header_slab.add_child(_gold)


func refresh() -> void:
	super.refresh()
	if _gold != null and player != null:
		_gold.text = GOLD_TITLE % player.gold
		_header_slab.tooltip_text = "%s\nGold: %d\n\nDeck Info — name this deck" % [deck.deck_name, player.gold]


func gold_text() -> String:
	return _gold.text if _gold != null else ""


# -------------------------------------------- what the adventure keeps --

## `Clear deck` empties the deck and keeps its name ([method
## DeckModel.clear] would call it `New Deck`).
func _clear_deck() -> void:
	var title := deck.deck_name
	super._clear_deck()
	if deck.deck_name != title:
		deck.deck_name = title
		refresh()


func _restore_extras() -> void:
	_saved_extras = _extras_state()


func _remember_extras() -> void:
	pass


func _with_tome() -> bool:
	return player != null and player.owns("Tome of Enlightenment")


## The adventure's decks answer to Shandalar's duplicate limit only: no
## tournament lists, no word on Gauntlets (1997's adventure builder asked
## no minimum either).
func _format_offences() -> Array[String]:
	var none: Array[String] = []
	return none


func _size_advice(_count: int) -> String:
	return ""


func _pool_caption() -> String:
	return "of your cards to add"


func _command_labels() -> Array[String]:
	return ALLOWED.duplicate()


func _run_command(label: String) -> void:
	if not ALLOWED.has(label):
		_say(NOT_HERE, true)
		return
	super._run_command(label)


func _menu_entries() -> Array[String]:
	return [MENU_BACK, BACK_TO_WORLD, "Exit game"]


func _run_menu_entry(label: String) -> void:
	if label == BACK_TO_WORLD:
		_close_deck_menu()
		_exit()
		return
	super._run_menu_entry(label)


func _sealed_refusal(card_name: String) -> String:
	if sealed == null:
		return ""
	var held := sealed.copies_of(card_name)
	if held == 0:
		return "You own no %s" % card_name
	if deck.copies_of(card_name) >= held:
		return "You own only one %s" % card_name if held == 1 \
			else "You own only %d %s" % [held, card_name]
	return ""


## The adventure's decks have no sideboard.
func _add_one_side(_card_name: String) -> void:
	_say("The adventure's decks have no sideboard.", true)


func _move_to_sideboard(_card_name: String) -> void:
	_say("The adventure's decks have no sideboard.", true)


func _on_dice_pressed() -> void:
	_dice_button.set_pressed_no_signal(false)


func _leave_sealed() -> void:
	pass


## Nothing to ask on the way out: the decks go back to the hero.
func _unsaved_slots() -> Array[int]:
	var none: Array[int] = []
	return none


func _save_deck(then := Callable()) -> void:
	write_back()
	_say("Your decks are kept with your adventure.")
	if then.is_valid():
		then.call()


func _exit() -> void:
	write_back()
	closed.emit()


func _quit_game() -> void:
	write_back()
	exit_requested.emit()


func _end_process() -> void:
	write_back()
	exit_requested.emit()
