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
##
## OUTDOORS IT ONLY LOOKS (the owner, 2026-10-23: *"Implement the same
## 1997 here … it could only be edited in towns, or outdoors with
## Conjurer's Will"*). 1997 opened the builder three ways
## (`DeckBuilderMain(…, 1, flags)`, flag 1 letting cards move, flag 2
## selling): the spellbook, F1, with neither (`adventure_input.c` 368) —
## the decks to look at, nothing to change; Conjurer's Will with cards
## moving (444); a town's Edit deck/Sell cards with both (visitLocation.c
## 1030). [member looking] is the first: every change — a card in or out,
## a drag, Clear, Restore, Copy deck to, the name and the notes — says where
## the deck is changed instead, and Done writes nothing back. [Ours: 1997's
## F1 cast Conjurer's Will itself when the hero owned it, risking an amulet
## unasked; here the spellbook only looks, and the cast is the World
## Magic's own (its key, 1, or its icon).]
##
## OPENED IN A TOWN ("Edit deck/Sell cards", [member sell_site]) it also
## sells, as the 1997 builder did there (`DeckBuilderMain` with selling,
## `SellPrice` 004f1bcc): Sell takes one copy of the card on show — one in
## no deck first, never the deck's own — for the town's price
## ([method CardShop.sell_price_at]), the gold on the title slab at once.

## The builder is done: the decks are written back to the hero.
signal closed
## The game is to end (Exit game, the window's close): the decks written
## back, the world saves and quits.
signal exit_requested

const ALLOWED: Array[String] = ["Consolidate duplicate cards", "Clear deck", "Restore deck",
	"Sort deck", "Stats", "Music", "Sound Effects", "Extra Cards", "Move by color out of deck",
	"Filters", "Undo", "Big cards", "Copy deck to", "Deck notes", "Save deck", "Exit deck builder"]
## What the builder offers when it only looks: the views, nothing that
## changes a deck.
const LOOK_ALLOWED: Array[String] = ["Consolidate duplicate cards", "Sort deck", "Stats", "Music",
	"Sound Effects", "Filters", "Big cards", "Exit deck builder"]
## Said when a change is asked of a builder that only looks, and kept in
## the well while it does ([method _resting_line]). One line at the shipping
## 1280 × 800: 283 of the well's 292 px, measured in the running game — the
## whole sentence ran off the well's edge.
const LOOK_ONLY := "Look only: edit in a town or with Conjurer's Will."
## The whole reason, on the well's tooltip (and in the Help's "Your deck").
const LOOK_WHY := "Out here you may only look at your decks: change them in a town's Edit deck/Sell cards, or with Conjurer's Will."
const BACK_TO_WORLD := "Return to the world"
const NOT_HERE := "The adventure's decks are built from your own cards."
## Said when an artwork is chosen: the hero's decks keep no printing.
const NO_ARTWORK := "The adventure's decks keep no choice of artwork."
## The 1997 adventure builder's title field (`@GOLDTITLE`).
const GOLD_TITLE := "GOLD: %d"
## The worth strip before a card is pointed at.
const WORTH_HEADING := "What a card is worth"
const WORTH_PROMPT := "Point at a card to see what the places pay for it."
## The strip's lettering in from its field's edges.
const WORTH_INSET := 10.0

var player: AdventurePlayer
## The town the builder was opened in, which buys cards; -1 for none.
var sell_site := -1
## Opened outdoors with the spellbook (F1): the decks to look at only.
var looking := false
var _gold: Label
var _written := false
var _sell_button: Button
## The worth strip ([method _build_sideboard_area]): its card's name and
## its lines, and the card it tells of ("" for none yet).
var _worth: VBoxContainer
var _worth_title: Label
var _worth_lines: Array[Label] = []
var _worth_card := ""


func _ready() -> void:
	# Made in code, not from the builder's full-rect .tscn: offsets too, or
	# the surface stays 0 × 0.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	super._ready()
	if looking:
		_say(LOOK_ONLY)
		_status_label.tooltip_text = LOOK_WHY
		_status_label.mouse_filter = Control.MOUSE_FILTER_PASS
	else:
		_say("Your cards: %d · in this deck %d" % [player.cards.size(), deck.total()])


## THE HERO'S DECKS AND CARDS GO IN BEFORE THE FIRST FILL (the fix pass of
## 2026-10-23, h5-10: each F1 froze the world for 0.2-0.5 s). Put in place
## after `super._ready()`, as they were, they came after the builder had
## filtered, sorted and drawn the WHOLE LIBRARY — every card the game has,
## 120 ms with every card pack on — and the hero's cards were then walked
## twice more. Here the deck area and the Inventory are each filled once,
## by the screen's own first [method refresh], from the hero's decks and
## the hero's cards.
func _before_first_fill() -> void:
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
	# In force, not drawn: the first fill draws it.
	_put_pool_in_force(pool)
	for door in ["LoadButton", "ExtrasButton"]:
		var button := _command_row.get_node_or_null(door) as Control
		if button != null:
			button.hide()
	_dice_button.hide()
	_pool_button.hide()
	_variant_button.hide()
	_build_gold()
	if sell_site >= 0:
		_sell_button = OriginalDialog.button("Sell", Vector2(150, COMMAND_BAR_H))
		_sell_button.name = "SellButton"
		_sell_button.pressed.connect(func() -> void:
			if _showcase._shown != null:
				sell(_showcase._shown.data.card_name))
		_command_row.add_child(_sell_button)
		_command_row.move_child(_sell_button, _command_row.get_node("DoneButton").get_index())


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
	if looking:
		return
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
	# After every change to the decks the worth strip's counts, and the Sell
	# button beside them, are read again (a card taken out may be sold now).
	if _worth_card != "":
		_show_worth(_worth_card)
		_price_sell(_worth_card)


func gold_text() -> String:
	return _gold.text if _gold != null else ""


# ------------------------------------------------------------ selling --

## The card on show — the one under the mouse — and what it is worth: on
## the Sell button in a town, and on the worth strip.
func _show_in_showcase(data: CardData) -> void:
	super._show_in_showcase(data)
	# The hero's decks keep no printing ([method _choose_printing]): the
	# artwork picker the Showcase offers elsewhere stays away.
	_variant_button.visible = false
	_price_sell(data.card_name)
	_show_worth(data.card_name)


func _price_sell(card_name: String) -> void:
	if _sell_button == null:
		return
	var spare := _spare_copy(card_name) >= 0
	_sell_button.text = "Sell for %d" % CardShop.sell_price_at(player, sell_site, card_name) if spare else "Sell"
	_sell_button.disabled = not spare


## SELL one copy of [param card_name] to the town: one in no deck first,
## else one in another deck (it leaves that deck), never one the deck on
## the surface holds. The gold it brings, 0 when nothing was sold.
func sell(card_name: String) -> int:
	if sell_site < 0:
		return 0
	var at := _spare_copy(card_name)
	if at < 0:
		_say("Every %s you own is in this deck: take one out to sell it." % card_name, true)
		return 0
	var price := CardShop.sell_price_at(player, sell_site, card_name)
	player.cards.remove_at(at)
	player.gold += price
	var left := 0
	for card in player.cards:
		if String((card as Dictionary).get("card", "")) == card_name:
			left += 1
	if left > 0:
		sealed.counts[card_name] = left
	else:
		sealed.counts.erase(card_name)
	# Every deck that holds more than the copies left gives one up — the
	# decks in the slots, and the deck Undo or Restore deck would put back
	# (else a sold card came back on the surface until Done).
	var models: Array[DeckModel] = []
	for slot in SLOTS:
		models.append(deck if slot == _slot else _slots[slot])
	for kept in [_undo, _cleared]:
		if kept != null:
			models.append(kept)
	for model in models:
		while model.count_of(card_name) > left:
			model.remove(card_name)
	_drawn_revision = -1
	refresh()
	_refresh_inventory()
	_price_sell(card_name)
	_show_worth(card_name)
	_say("Sold %s for %d gold." % [card_name, price])
	return price


## The index in the hero's cards of a copy of [param card_name] that may be
## sold: in no deck first, else in a deck other than the one on show, so
## the surface keeps every copy it holds; -1 for none.
func _spare_copy(card_name: String) -> int:
	var held := deck.count_of(card_name)
	var owned: Array[int] = []
	for i in player.cards.size():
		if String((player.cards[i] as Dictionary).get("card", "")) == card_name:
			owned.append(i)
	if owned.size() <= held:
		return -1
	for i in owned:
		if ((player.cards[i] as Dictionary).get("decks", []) as Array).is_empty():
			return i
	for i in owned:
		if not ((player.cards[i] as Dictionary).get("decks", []) as Array).has(_slot):
			return i
	return owned[owned.size() - 1]


# -------------------------------------------- what the adventure keeps --

## `Clear deck` empties the deck and keeps its name ([method
## DeckModel.clear] would call it `New Deck`).
func _clear_deck() -> void:
	if _refuse_change():
		return
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
	return LOOK_ALLOWED.duplicate() if looking else ALLOWED.duplicate()


func _run_command(label: String) -> void:
	if looking and not LOOK_ALLOWED.has(label) and ALLOWED.has(label):
		_say(LOOK_ONLY, true)
		return
	if not ALLOWED.has(label):
		_say(NOT_HERE, true)
		return
	super._run_command(label)


# ------------------------------------------------------- the worth strip --

## THE WORTH STRIP (the owner, 2026-10-23: *"leave the sideboard empty -
## maybe we can use it to display card under the mouse value for selling?
## (In adventure)"*). The adventure's decks have no sideboard, so the
## sideboard's strip, on its own teal field, tells what the card under the
## mouse is worth [ours]:
##  - in a town (Edit deck/Sell cards) what this place pays for one
##    ([method CardShop.sell_price_at]); out in the wilds (the spellbook,
##    Conjurer's Will) the least and the most the places pay
##    ([method CardShop.sell_range], which reads no world);
##  - the best price among the places the hero has been to, when it is
##    better than here ([method CardShop.best_known_sale]);
##  - how many the hero owns, how many are in this deck, and in a town how
##    many may be sold (all but the deck's own, as [method sell] sells).
## The sideboard's own area stays built, hidden, so the screen's common
## code finds it.
func _build_sideboard_area() -> void:
	super._build_sideboard_area()
	_sideboard_area.hide()
	_worth = VBoxContainer.new()
	_worth.name = "WorthStrip"
	_worth.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worth.add_theme_constant_override("separation", 2)
	_worth_title = _well_label(17, true)
	_worth_title.clip_text = true
	_worth.add_child(_worth_title)
	for i in 3:
		var line := _well_label(15, false)
		line.clip_text = true
		_worth.add_child(line)
		_worth_lines.append(line)
	add_child(_worth)
	_show_worth("")


func _layout() -> void:
	super._layout()
	if _worth != null:
		var strip := _sideboard_rect()
		_worth.position = strip.position + Vector2(WORTH_INSET, WORTH_INSET / 2.0)
		_worth.size = Vector2(maxf(0.0, strip.size.x - 2.0 * WORTH_INSET),
			maxf(0.0, strip.size.y - WORTH_INSET))


## The strip told of [param card_name]; "" (or a card the registry lacks)
## puts the prompt back.
func _show_worth(card_name: String) -> void:
	if _worth == null:
		return
	var lines := worth_lines(card_name)
	_worth_card = card_name if not lines.is_empty() else ""
	_worth_title.text = card_name if not lines.is_empty() else WORTH_HEADING
	if lines.is_empty():
		lines = [WORTH_PROMPT]
	for i in _worth_lines.size():
		_worth_lines[i].text = lines[i] if i < lines.size() else ""


## What the strip says of [param card_name], a line each; empty for a card
## the registry lacks.
func worth_lines(card_name: String) -> Array[String]:
	var lines: Array[String] = []
	if card_name == "" or not CardRegistry.has_card(card_name):
		return lines
	var here := -1
	if sell_site >= 0 and player.world != null:
		here = CardShop.sell_price_at(player, sell_site, card_name)
		lines.append("%s pays %d gold for one." % [WorldNames.site_name(player.world, sell_site), here])
	else:
		var paid := CardShop.sell_range(card_name)
		lines.append("The places pay %d gold for one." % paid.x if paid.x == paid.y
			else "The places pay %d to %d gold for one." % [paid.x, paid.y])
	var best := CardShop.best_known_sale(player, card_name)
	if not best.is_empty() and int(best["price"]) > here and int(best["slot"]) != sell_site:
		lines.append("The best you know of: %d gold at %s." % [int(best["price"]), String(best["name"])])
	var owned := int(owned_counts(player).get(card_name, 0))
	var held := deck.count_of(card_name)
	var words := "You own %d · in this deck %d" % [owned, held]
	if sell_site >= 0:
		words += " · to sell %d" % maxi(owned - held, 0)
	lines.append(words)
	return lines


# ------------------------------------------------- looking only (F1) --

## A builder that only looks keeps saying so after any other message.
func _resting_line() -> String:
	return LOOK_ONLY if looking else ""


## True — and the reason said — when the builder only looks.
func _refuse_change() -> bool:
	if looking:
		_say(LOOK_ONLY, true)
	return looking


## Remove Extra Cards (the complaint line's Extra Cards list): a change.
func _trim_duplicates() -> void:
	if _refuse_change():
		return
	super._trim_duplicates()


## No artwork is chosen here: the hero's decks have nowhere to keep it, so
## a choice would be confirmed and then forgotten.
func _choose_printing(_card_name: String, _id: String) -> void:
	if _refuse_change():
		return
	_say(NO_ARTWORK, true)


func _add_one(card_name: String) -> bool:
	if _refuse_change():
		return false
	return super._add_one(card_name)


func _add_playset(card_name: String) -> void:
	if not _refuse_change():
		super._add_playset(card_name)


func _remove_one(card_name: String) -> void:
	if not _refuse_change():
		super._remove_one(card_name)


func _remove_all(card_name: String) -> void:
	if not _refuse_change():
		super._remove_all(card_name)


func _move_out_by_color(colors: Array) -> void:
	if not _refuse_change():
		super._move_out_by_color(colors)


func _copy_deck_to(index: int) -> void:
	if not _refuse_change():
		super._copy_deck_to(index)


func _open_deck_info(then := Callable(), reason := "", suggested := "") -> void:
	if not _refuse_change():
		super._open_deck_info(then, reason, suggested)


func _open_notes_dialog() -> void:
	if not _refuse_change():
		super._open_notes_dialog()


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
