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
## A right-click on an Inventory card offers it too, in 1997's words
## (`@SELLCARD`, "Sell Card for %d" — the horizontal list's own mini-menu,
## `wndproc_HorzListClass`, deckdll 0x1002887e in the matching
## decompilation), and asks 1997's "How many to Sell?" (`@NUMBERTOSELL`)
## when more than one copy may go ([method _ask_sell]).
##
## WHAT THE ADVENTURE KEEPS, ALL ON THIS SCREEN (the owner, 2026-10-28:
## *"check that money (gold) and other Adventure relevant functionality is
## in the Adventure deck builder!"*): the gold on the title slab; selling
## and the prices (the worth strip, the Sell button, the card's own menu);
## the copy rule the deck is judged by and, under the Classic MTG rules,
## the Embark's ban list, named at the foot of the worth strip ([method
## rule_line]); the card hold — the bag's count against its 500 under the
## 1997 hold ([method hold_line]); the three decks and the deck in use
## (the starred slot, said on each slot's tooltip); 1997's two colour moves
## of `@DECKSURFACE_ADVENTURE`.

## The builder is done: the decks are written back to the hero.
signal closed
## The game is to end (Exit game, the window's close): the decks written
## back, the world saves and quits.
signal exit_requested

const ALLOWED: Array[String] = ["Consolidate duplicate cards", "Clear deck", "Restore deck",
	"Sort deck", "Stats", "Music", "Sound Effects", "Extra Cards", "Move by color into deck",
	"Move by color out of deck", "Filters", "Undo", "Redo", "Big cards", "Copy deck to", "Deck notes",
	"Save deck", "Exit deck builder"]
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
## The 1997 adventure builder's line on a card's mini-menu in a town
## (`@SELLCARD`), and its question when more than one copy may go
## (`@NUMBERTOSELL`).
const SELL_CARD := "Sell Card for %d"
const NUMBER_TO_SELL := "How many to Sell?"
## The card hold on the worth strip ([method hold_line]): the bag
## against its 500 under the 1997 hold, the count alone without one.
const HOLD_LINE := "Your cards: %d of %d"
const HOLD_LINE_UNLIMITED := "Your cards: %d"
## The copy rule on the worth strip ([method rule_line]): the 1997
## deck builder's (`check_card_count`), with Tome of Enlightenment's, and
## the Classic MTG rules under the Embark's ban list.
const RULE_1997 := "Copies: 3 of a card, 4 from 59 cards"
const RULE_1997_TOME := "Copies: 4 of a card, any from 59 cards"
const RULE_CLASSIC := "Copies: Classic MTG rules, %s list"
## Each slot's tooltip: the deck in use, as 1997's starred slot meant it.
const SLOT_TIP := "Your deck %d of three: the deck on show when you leave is the one you duel with."
const SLOT_TIP_LOOKING := "Your deck %d of three: you duel with Deck%d."
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
## The strip's foot line: the card hold and the copy rule ([method keeps_text]).
var _keeps: Label


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
	# The Rarity filter's Restricted and Banned under the Classic MTG rules
	# are the Embark's ban list, the one the Extra Cards box judges by (the
	# 0.50.65 bug campaign, k6-4); under 1997's copy rule, the tournament
	# lists as everywhere else.
	filter.ban_list = ClassicBans.key_of(player.ban_list) \
		if player.card_rule == AdventurePlayer.RULE_CLASSIC else ""
	for door in ["LoadButton", "ExtrasButton"]:
		var button := _command_row.get_node_or_null(door) as Control
		if button != null:
			button.hide()
	_dice_button.hide()
	_pool_button.hide()
	_variant_button.hide()
	_build_gold()
	for i in _slot_buttons.size():
		_slot_buttons[i].tooltip_text = SLOT_TIP_LOOKING % [i + 1, _slot + 1] if looking \
			else SLOT_TIP % (i + 1)
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
	# The foot of the worth strip: the bag and the rule the deck answers
	# to, always in view.
	if _keeps != null and player != null:
		_keeps.text = keeps_text()
		# Warm from the 450 the spoils warn at ([constant
		# AdventurePlayer.BAG_WARN]): the bag is nearly full.
		_keeps.add_theme_color_override("font_color", WELL_WARNING if bag_nearly_full() else WELL_INK)
	# After every change to the decks the worth strip's counts, and the Sell
	# button beside them, are read again (a card taken out may be sold now).
	if _worth_card != "":
		_show_worth(_worth_card)
		_price_sell(_worth_card)


func gold_text() -> String:
	return _gold.text if _gold != null else ""


## THE CARD HOLD on this screen (the Embark's "1997 card hold limit" /
## "Unlimited card hold", [member AdventurePlayer.card_hold]): every card the
## hero owns against the bag's [constant AdventurePlayer.BAG_MOST], or the
## count alone when the bag has no limit.
func hold_line() -> String:
	if player.bag_limited():
		return HOLD_LINE % [player.cards.size(), AdventurePlayer.BAG_MOST]
	return HOLD_LINE_UNLIMITED % player.cards.size()


## Whether the bag holds the 450 cards from which the spoils warn of a full
## bag (the 1997 card hold only).
func bag_nearly_full() -> bool:
	return player.bag_limited() and player.cards.size() >= AdventurePlayer.BAG_WARN


## The worth strip's foot line: [method hold_line] and [method rule_line].
func keeps_text() -> String:
	return "%s · %s" % [hold_line(), rule_line()]


## THE COPY RULE the decks are judged by ([method _copy_rule]): the 1997
## deck builder's under the first two card rules, with Tome of
## Enlightenment's allowance when the hero owns it; under the Classic MTG
## rules, the Embark's ban list by its Embark name.
func rule_line() -> String:
	if player.card_rule == AdventurePlayer.RULE_CLASSIC:
		return RULE_CLASSIC % String(EmbarkScreen.BAN_NAMES.get(
			ClassicBans.key_of(player.ban_list), player.ban_list))
	return RULE_1997_TOME if _with_tome() else RULE_1997


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


## SELL [param count] copies of [param card_name] to the town, one at a
## time: one in no deck first, else one in another deck (it leaves that
## deck), never one the deck on the surface holds — so fewer go when fewer
## may. The gold they bring, 0 when nothing was sold.
func sell(card_name: String, count := 1) -> int:
	if sell_site < 0:
		return 0
	var gold := 0
	var sold := 0
	for _i in maxi(count, 1):
		var at := _spare_copy(card_name)
		if at < 0:
			break
		var price := CardShop.sell_price_at(player, sell_site, card_name)
		player.cards.remove_at(at)
		player.gold += price
		gold += price
		sold += 1
	if sold == 0:
		_say("Every %s you own is in this deck: take one out to sell it." % card_name, true)
		return 0
	var left := 0
	for card in player.cards:
		if String((card as Dictionary).get("card", "")) == card_name:
			left += 1
	if left > 0:
		sealed.counts[card_name] = left
	else:
		sealed.counts.erase(card_name)
	# Every deck that holds more than the copies left gives one up — the
	# decks in the slots, and every deck Undo, Redo or Restore deck would
	# put back (else a sold card came back on the surface until Done).
	var models: Array[DeckModel] = []
	for slot in SLOTS:
		models.append(deck if slot == _slot else _slots[slot])
	models.append_array(_history_models())
	if _cleared != null:
		models.append(_cleared)
	for model in models:
		while model.count_of(card_name) > left:
			model.remove(card_name)
	# A step the trim left changing nothing goes (the 0.50.65 bug campaign,
	# k2-3): Redo after "Add Mahamoti Djinn", undone and the Djinn sold,
	# said "Redone" and changed nothing.
	_drop_idle_steps()
	_drawn_revision = -1
	refresh()
	_refresh_inventory()
	_price_sell(card_name)
	_show_worth(card_name)
	if sold == 1:
		_say("Sold %s for %d gold." % [card_name, gold])
	else:
		_say("Sold %d %s for %d gold." % [sold, card_name, gold])
	return gold


## How many copies of [param card_name] may be sold here: those the deck on
## show does not hold ([method sell]); 0 outside a town.
func sellable(card_name: String) -> int:
	if sell_site < 0:
		return 0
	return maxi(int(owned_counts(player).get(card_name, 0)) - deck.count_of(card_name), 0)


## SELL FROM THE CARD'S OWN MENU: one copy at once, or — when more than one
## may go — 1997's "How many to Sell?" first (`show_dialog_sellxcards`,
## `@NUMBERTOSELL`), the number from one to every copy outside the deck on
## show, the price of one beside it.
func _ask_sell(card_name: String) -> void:
	var most := sellable(card_name)
	if most <= 1:
		sell(card_name)
		return
	if _dialog_busy():
		return
	var price := CardShop.sell_price_at(player, sell_site, card_name)
	var dialog := OriginalDialog.create(NUMBER_TO_SELL, Vector2(400, 220))
	dialog.set_meta("sell_count", card_name)
	dialog.body().add_child(OriginalDialog.label(
		"%s: %d gold each, %d to sell" % [card_name, price, most], 14))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	row.add_child(OriginalDialog.label("Number", 14))
	var spin := OriginalDialog.field(80.0)
	spin.min_value = 1
	spin.max_value = most
	spin.value = 1
	row.add_child(spin)
	dialog.body().add_child(row)
	var sell_button := dialog.add_button("Sell")
	sell_button.pressed.connect(func() -> void:
		dialog.dismiss()
		sell(card_name, int(spin.value)))
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	# ENTER IN THE NUMBER SELLS (the 0.50.65 bug campaign, k2-4), as 1997's
	# dialog took it for OK (`show_dialog_sellxcards` → `dlgproc_AskX`, a
	# Windows dialog whose OK is its default button): it only set the number
	# and the Sell button still had to be clicked. The number typed is taken
	# first ([method SpinBox.apply]), so "2" and Enter sells two.
	spin.get_line_edit().text_submitted.connect(func(_text: String) -> void:
		spin.apply()
		sell_button.pressed.emit())
	_show_dialog(dialog)
	spin.get_line_edit().grab_focus()


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


## THE 1997 ADVENTURE DECK BUILDER'S COPY RULE (deckdll `check_card_count`,
## [method DeckModel.copies_allowed_1997]): three copies under 59 cards, four
## from 59, Tome of Enlightenment one more (no limit from 59), basic lands
## aside — not the manual's table, which the deck builder never applied. A
## first deck dealt with three copies of a spell is a fair deck (the owner,
## 2026-10-24: the 1997 code is the rule). An adventure begun under the
## Classic MTG rules is judged by them instead ([constant DeckModel.CLASSIC]:
## four of a card, one restricted — four with the Tome —, no banned card),
## under the ban list chosen at its Embark ([member
## AdventurePlayer.ban_list], [method DeckModel.classic_with]), asked about
## as it is left just the same.
func _copy_rule() -> String:
	if player != null and player.card_rule == AdventurePlayer.RULE_CLASSIC:
		return DeckModel.classic_with(player.ban_list)
	return DeckModel.DECK_BUILDER_1997


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
## Its foot line says what the adventure keeps, whatever the pointer is on
## ([method keeps_text]): the card hold and the copy rule — under the deck's
## numbers they pushed the well's own lines out of the left column at
## 1280 × 800 (seen in the running game, 2026-10-28), and the strip has
## the room.
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
	var room := Control.new()
	room.size_flags_vertical = Control.SIZE_EXPAND_FILL
	room.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_worth.add_child(room)
	_keeps = _well_label(15, false)
	_keeps.name = "KeepsLine"
	_keeps.clip_text = true
	_worth.add_child(_keeps)
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


func _move_in_by_color(colors: Array) -> void:
	if not _refuse_change():
		super._move_in_by_color(colors)


## The hero's basic lands are cards the hero owns: a colour brings its own
## in, as 1997's adventure builder did.
func _group_move_brings_lands() -> bool:
	return true


## The card's own menu here: looking only, `View large` alone; in a town,
## 1997's "Sell Card for %d" before it while a copy may go.
func _card_menu_entries(card_name: String) -> Array:
	if looking:
		return [[CARD_VIEW, _view_large.bind(card_name)]]
	var entries := super._card_menu_entries(card_name)
	if sellable(card_name) > 0:
		entries.insert(entries.size() - 1, [SELL_CARD % CardShop.sell_price_at(player,
			sell_site, card_name), _ask_sell.bind(card_name)])
	return entries


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


## DONE, or Return to the world: as 1997's builder was left (`WM_CLOSE`,
## deckdll.c 5695–5728), a deck with too many copies of a card is asked
## about first — the Extra Cards box: Remove Extra Cards takes the extras
## out and goes on, Edit Deck stays ([method _ask_extra_cards]).
func _exit() -> void:
	if _ask_extra_cards(_exit_now):
		return
	_exit_now()


func _exit_now() -> void:
	write_back()
	closed.emit()


func _quit_game() -> void:
	if _ask_extra_cards(_quit_now):
		return
	_quit_now()


func _quit_now() -> void:
	write_back()
	exit_requested.emit()


## True when the deck on show has too many copies of a card and the Extra
## Cards box was put up ([param then] runs once they are removed); a builder
## that only looks has nothing to change and is never asked. The window's
## own close is not asked ([method _end_process]): the deck goes back as it
## is — no duel checks copies (1997 neither) — and the next visit asks.
func _ask_extra_cards(then: Callable) -> bool:
	if looking or deck.over_duplicate_limit(_with_tome(), _copy_rule()).is_empty():
		return false
	_open_extra_cards(then)
	return true


func _end_process() -> void:
	write_back()
	exit_requested.emit()
