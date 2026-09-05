extends GutTest
## ONE CARD SIZE, EVERYWHERE — the owner's standing rule, pinned.
##
## *"Didn't we say we keep only ONE dimension of mini cards (the same,
## just rotated smoothly for tapping) — the same mini card dimension for
## table and hand, graveyards, exile, etc etc etc."*
##
## Every card anywhere in the duel is a [MiniCard] and every [MiniCard] is
## [constant MiniCard.SIZE] — 132x106 — at scale 1. The only transform a
## card may wear is the 90° TAP ROTATION, and that keeps the size and
## merely swaps the FOOTPRINT its holder reserves.
##
## This file measures REAL widgets after a real layout pass, because every
## way a card has ever come out the wrong size has been invisible to code
## reading:
##
##   * `FanHand` forced its own `Vector2(96, 120)` onto every card it
##     dealt — taller than wide, where a mini card is wider than tall;
##   * `GraveyardView` forced `Vector2(96, 134)` the same way (fixed in
##     the thirty-third pass);
##   * and the subtle one, which no constant anywhere spells out:
##     **`FlowContainer` STRETCHES a child with `SIZE_FILL` to the height
##     of its line.** A row holding a tapped card (whose holder is
##     `SIZE.y + 8` tall) or a five-card `CardPile` (174px) therefore
##     stretched every plain card beside it — which is exactly why "the
##     Crusade card on the table looks a different height".

const TOLERANCE := 0.01


func _mini_cards(root: Node, out: Array[MiniCard] = []) -> Array[MiniCard]:
	if root is MiniCard:
		out.append(root)
	for child in root.get_children():
		_mini_cards(child, out)
	return out


## Every mini card under [param root] is the one size, unscaled, and turned
## only by the tap rotation. [param max_tilt] opens the rotation check up
## for the FAN, whose whole design is an arc of tilted cards — a tilt is
## not a resize, and the fan's cards are the one size like every other.
func _assert_all_one_size(root: Node, where: String, max_tilt := 0.0) -> void:
	var cards := _mini_cards(root)
	assert_gt(cards.size(), 0, "%s: nothing to measure" % where)
	for card in cards:
		assert_almost_eq(card.size.x, MiniCard.SIZE.x, TOLERANCE,
			"%s: %s width" % [where, card.instance.data.card_name])
		assert_almost_eq(card.size.y, MiniCard.SIZE.y, TOLERANCE,
			"%s: %s height" % [where, card.instance.data.card_name])
		assert_almost_eq(card.scale.x, 1.0, TOLERANCE,
			"%s: %s is scaled" % [where, card.instance.data.card_name])
		assert_almost_eq(card.scale.y, 1.0, TOLERANCE,
			"%s: %s is scaled" % [where, card.instance.data.card_name])
		var turn := absf(card.rotation_degrees)
		assert_true(turn <= max_tilt + TOLERANCE
				or absf(turn - 90.0) < TOLERANCE,
			"%s: %s is turned %.2f° — only the tap's 90° is legal"
				% [where, card.instance.data.card_name, turn])


# ------------------------------------------------------- the constants --

func test_no_widget_declares_a_card_size_of_its_own() -> void:
	# The fan used to carry `Vector2(96, 120)`. Whatever a layout calls its
	# card size, it must BE the card size.
	assert_eq(FanHand.CARD_SIZE, MiniCard.SIZE,
		"the fan deals MiniCards, so it measures in MiniCard.SIZE")
	assert_eq(CardPile.WIDTH, MiniCard.SIZE.x, "a pile is one card wide")
	assert_eq(CardPile.COMPACT_FACE_HEIGHT, MiniCard.SIZE.y,
		"a pile's front card is exactly a table card")
	assert_eq(GraveyardView.ARROW_SIZE.y, MiniCard.SIZE.y,
		"the shelf arrows are one card tall")


# ------------------------------------------------------------ the table --

func _duel() -> DuelScreen:
	var screen: DuelScreen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	return screen


func _summon(screen: DuelScreen, card_name: String, pid := 0) -> CardInstance:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, screen.game._next_instance_id, pid)
	screen.game._next_instance_id += 1
	screen.game._instances[inst.id] = inst
	screen.game._put_on_battlefield(inst, pid)
	return inst


func test_the_whole_table_is_one_card_size() -> void:
	# THE BOARD THE OWNER WAS LOOKING AT, staged in one frame: a lone
	# enchantment (Crusade) beside a five-card land PILE, an untapped
	# creature beside a TAPPED one, and a creature wearing an aura. Every
	# one of those neighbours is taller than a card, and every one of them
	# used to stretch the cards next to it.
	var screen := await _duel()
	for filler in ["Mountain", "Forest", "Plains", "Island", "Swamp"]:
		_summon(screen, filler)
	_summon(screen, "Crusade")
	_summon(screen, "Grizzly Bears")
	var tapped := _summon(screen, "Hill Giant")
	tapped.tapped = true
	var host := _summon(screen, "Savannah Lions")
	var ward := CardRegistry.get_card("Holy Strength")
	if ward != null:
		var aura := CardInstance.new(ward, screen.game._next_instance_id, 0)
		screen.game._next_instance_id += 1
		screen.game._instances[aura.id] = aura
		screen.game.attach_aura_from_anywhere(aura, host, 0)
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_all_one_size(screen, "battlefield")


func test_a_tapped_card_turns_a_right_angle_and_keeps_its_size() -> void:
	# The tap is a ROTATION, never a resize: the card keeps 132x106 and its
	# HOLDER reserves the swapped footprint the turn sweeps out.
	var screen := await _duel()
	var giant := _summon(screen, "Hill Giant")
	giant.tapped = true
	screen._refresh()
	await get_tree().process_frame
	var turned: MiniCard = null
	for card in _mini_cards(screen):
		if card.instance.id == giant.id:
			turned = card
	assert_not_null(turned, "the tapped card is on the board")
	assert_eq(turned.size, MiniCard.SIZE, "a tapped card is not resized")
	assert_eq(turned.pivot_offset, MiniCard.SIZE / 2.0,
		"it turns about its own centre")
	var holder: Control = turned.get_parent()
	assert_eq(holder.custom_minimum_size,
		Vector2(MiniCard.SIZE.y + 8, MiniCard.SIZE.x + 8),
		"the holder reserves the ROTATED footprint")


# ------------------------------------------------------ hand, both ways --

func test_the_hand_stack_deals_cards_at_the_one_size() -> void:
	var hand := StackHand.new()
	add_child_autofree(hand)
	var game := MtgGame.new()
	var deck: Array = []
	for _i in 30:
		deck.append("Forest")
	game.setup(deck, deck, "P0", "P1", 20, 20, 7)
	game.start(0)
	var cards: Array = []
	for card_name in ["Disintegrate", "Fork", "Regrowth", "Disenchant"]:
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		var inst := CardInstance.new(data, game._next_instance_id, 0)
		game._next_instance_id += 1
		inst.zone = Mtg.Zone.HAND
		cards.append(inst)
	hand.populate(cards, false, func(_c: CardInstance) -> void: pass,
		func(_c: CardInstance) -> int: return MiniCard.Highlight.NONE)
	await get_tree().process_frame
	_assert_all_one_size(hand, "hand stack")


func test_the_fan_deals_cards_at_the_one_size() -> void:
	var fan := FanHand.new()
	fan.size = Vector2(620, 220)
	add_child_autofree(fan)
	var game := MtgGame.new()
	var deck: Array = []
	for _i in 30:
		deck.append("Forest")
	game.setup(deck, deck, "P0", "P1", 20, 20, 7)
	game.start(0)
	for card_name in ["Disintegrate", "Fork", "Regrowth", "Disenchant",
			"Grizzly Bears", "Hill Giant"]:
		var data := CardRegistry.get_card(card_name)
		if data == null:
			continue
		var inst := CardInstance.new(data, game._next_instance_id, 0)
		game._next_instance_id += 1
		inst.zone = Mtg.Zone.HAND
		fan.add_child(MiniCard.new(inst))
	fan.relayout()
	await get_tree().process_frame
	_assert_all_one_size(fan, "fan hand", FanHand.MAX_TILT_DEGREES)


# ------------------------------------------- graveyard, exile and ante --

func test_the_graveyard_shelves_are_the_one_size() -> void:
	var screen := await _duel()
	for dead in ["Grizzly Bears", "Hill Giant", "Lightning Bolt",
			"Savannah Lions", "Black Lotus", "Bad Moon", "Braingeyser"]:
		var data := CardRegistry.get_card(dead)
		if data == null:
			continue
		var inst := CardInstance.new(data, screen.game._next_instance_id, 0)
		screen.game._next_instance_id += 1
		screen.game._instances[inst.id] = inst
		inst.zone = Mtg.Zone.GRAVEYARD
		screen.game.players[0].graveyard.append(inst)
	for gone in ["Fireball", "Healing Salve"]:
		var data := CardRegistry.get_card(gone)
		if data == null:
			continue
		var inst := CardInstance.new(data, screen.game._next_instance_id, 0)
		screen.game._next_instance_id += 1
		screen.game._instances[inst.id] = inst
		inst.zone = Mtg.Zone.EXILE
		screen.game.players[0].exile.append(inst)
	screen._refresh()
	screen._on_grave_pile_clicked(0)
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_all_one_size(screen._grave_view, "graveyard / exile shelves")


# ---------------------------------------------- attachments (§41 pass) --

func _enchant(screen: DuelScreen, host: CardInstance,
		aura_name: String) -> CardInstance:
	var data := CardRegistry.get_card(aura_name)
	assert_not_null(data, aura_name)
	var aura := CardInstance.new(data, screen.game._next_instance_id, 0)
	screen.game._next_instance_id += 1
	screen.game._instances[aura.id] = aura
	screen.game.attach_aura_from_anywhere(aura, host, 0)
	return aura


## AN ATTACHED CARD IS A CARD — the forty-first pass. It used to be a 16px
## `Button` band glued on TOP of the host, which is why the owner's
## Savannah Lions read as "a grey title bar on a card" rather than as the
## reference's two cards stacked. It is now a whole [MiniCard] BEHIND the
## host, offset by [constant DuelScreen.AURA_PEEK] per attachment so its
## title band shows above and its right edge down the side — and it is
## therefore subject to the one-size rule like everything else.
func test_an_attachment_is_a_whole_card_behind_its_host() -> void:
	var screen := await _duel()
	var host := _summon(screen, "Savannah Lions")
	var auras: Array[CardInstance] = []
	for aura_name in ["Holy Strength", "Firebreathing", "Unholy Strength"]:
		auras.append(_enchant(screen, host, aura_name))
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	_assert_all_one_size(screen, "an enchanted host and its attachments")
	var by_id := {}
	for card in _mini_cards(screen):
		by_id[card.instance.id] = card
	var host_w: MiniCard = by_id.get(host.id)
	assert_not_null(host_w, "the host is on the board")
	assert_eq(host_w.size, MiniCard.SIZE, "the host is still 132x106")
	var wrap: Control = host_w.get_parent()
	# THE FAN OVERFLOWS UPWARD, IT DOES NOT MAKE THE ROW TALLER. Reserving
	# the height would re-centre the whole line and drop the enchanted host
	# below its neighbours (27px with three auras), which is the very class
	# of defect the rest of this file exists to catch.
	assert_eq(wrap.custom_minimum_size.y, MiniCard.SIZE.y,
		"an enchanted card reserves a plain card's height")
	assert_eq(wrap.custom_minimum_size.x,
		MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x * auras.size(),
		"...and reserves the fan's width, so the next card is not overlapped")
	assert_eq(host_w.position, Vector2.ZERO,
		"the host sits exactly where an unenchanted card would")
	for j in auras.size():
		var back: MiniCard = by_id.get(auras[j].id)
		var where := "%s behind %s" % [auras[j].data.card_name,
			host.data.card_name]
		assert_not_null(back, where)
		assert_eq(back.size, MiniCard.SIZE, "%s: an attachment is a CARD, "
			% where + "full size, never shrunk to a band")
		assert_eq(back.get_parent(), wrap, "%s: same wrap as the host" % where)
		var step := float(j + 1)
		assert_eq(back.position,
			Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y) * step,
			"%s: one step out, right and UP" % where)
		assert_lt(back.get_index(), host_w.get_index(),
			"%s: drawn BEFORE the host, so the host overlaps it" % where)
		# The band was clickable and it drove the sidebar's enlarged view.
		# A peeking card keeps BOTH or it is a regression.
		assert_gt(back.pressed.get_connections().size(), 0,
			"%s: still clickable" % where)
		assert_gt(back.mouse_entered.get_connections().size(), 0,
			"%s: still opens the Showcase on hover" % where)
	# ...and the "+N aura" chip that stood in for all this is gone from the
	# host's art, where the reference leaves the picture clear.
	assert_false(host_w._status_label.text.contains("aura"),
		"the peeking cards say it; the chip on the art does not repeat it")


## THE SAME, TAPPED. The host is inside its rotation holder then, which is
## wider and taller than a card and holds the turning card centred in it —
## so the fan is anchored to the CARD's visible corner, not the holder's,
## or the attachment floats 17px of empty holder above the picture.
func test_an_attachment_follows_a_tapped_host_to_its_turned_corner() -> void:
	var screen := await _duel()
	var host := _summon(screen, "Hill Giant")
	host.tapped = true
	var aura := _enchant(screen, host, "Holy Strength")
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	_assert_all_one_size(screen, "a tapped enchanted host", 90.0)
	var back: MiniCard = null
	var host_w: MiniCard = null
	for card in _mini_cards(screen):
		if card.instance.id == aura.id:
			back = card
		elif card.instance.id == host.id:
			host_w = card
	assert_not_null(back, "the attachment is on the board")
	assert_not_null(host_w, "so is the tapped host")
	assert_eq(back.size, MiniCard.SIZE, "still a full-size card")
	# The holder is SIZE.y+8 x SIZE.x+8 and centres the turned card, so the
	# card's visible corner is 4,4 inside it.
	var corner := Vector2(4, 4)
	assert_eq(back.position,
		corner + Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y),
		"one step out from the TURNED card's corner, not the holder's")
	var wrap: Control = back.get_parent()
	assert_eq(wrap.custom_minimum_size.x,
		corner.x + MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x,
		"the wrap reserves the ATTACHMENT's width — it is 132 wide even "
			+ "behind a host turned down to 106")
	assert_eq(wrap.custom_minimum_size.y, MiniCard.SIZE.x + 8,
		"and the tapped holder's height (the ROTATED footprint), which is "
			+ "the host's own — the fan adds none of its own")


## THE PEEK IS THE HANDLE. The band it replaced was clickable and it drove
## the sidebar's enlarged view; a card that only LOOKS right but cannot be
## examined is a regression. Driven with a real mouse event through the
## real board, because the exposed strip is drawn OUTSIDE its wrap's
## rectangle and inside a `clip_contents` board half — the two things that
## could have stopped Godot's picker from ever reaching it.
func test_the_peeking_strip_of_an_attachment_still_answers_the_mouse() -> void:
	var screen := await _duel()
	var host := _summon(screen, "Savannah Lions")
	var aura := _enchant(screen, host, "Holy Strength")
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	var back: MiniCard = null
	for card in _mini_cards(screen):
		if card.instance.id == aura.id:
			back = card
	assert_not_null(back, "the attachment is on the board")
	# A point in the strip that peeks ABOVE the host: half a card in, and
	# 9px down — inside the 18px band, above the host's own top edge.
	var point := back.get_global_rect().position \
		+ Vector2(MiniCard.SIZE.x / 2.0, DuelScreen.AURA_PEEK.y / 2.0)
	var move := InputEventMouseMotion.new()
	move.position = point
	move.global_position = point
	get_tree().root.push_input(move, true)
	await get_tree().process_frame
	assert_eq(get_viewport().gui_get_hovered_control(), back,
		"the mouse reaches the attachment where it peeks out")
	assert_eq(screen._card_preview._name_label.text, aura.data.card_name,
		"...and hovering it docks ITS card in the Showcase, not the host's")


# ------------------------------------------------------- the spell chain --

## Put one object on the chain and hand back the [StackItem].
func _push_chain(screen: DuelScreen, card_name: String, kind: int,
		controller := 0, x := 0) -> StackItem:
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, screen.game._next_instance_id,
		controller)
	screen.game._next_instance_id += 1
	screen.game._instances[inst.id] = inst
	var item := StackItem.new()
	item.kind = kind
	item.controller = controller
	item.card = inst
	item.x_value = x
	item.description = "%s (test)" % card_name
	screen.game.stack.append(item)
	return item


## THE CHAIN WAS THE LAST PLACE ON THE BOARD WHERE A CARD WAS NOT A CARD —
## the forty-second pass. It drew the Scryfall scan PORTRAIT at 104px with
## a `CardPreview` scaled to `104/300` as the fallback, and the earlier
## dimension audit let that stand as "an icon in a strip". The owner's 1997
## reference overruled it: a chain object is a SMALL CARD, exactly as
## `windows.c` draws every one of them through `DrawSmallCard` off the one
## global `smallcard_width` (`set_smallcard_size`, `:1088`).
func test_the_spell_chain_is_made_of_whole_cards() -> void:
	var screen := await _duel()
	# A spell, an ability in RESPONSE to it, and an X spell on top — the
	# deepest thing ordinary play builds, and the case that measures the
	# strip.
	_push_chain(screen, "Lightning Bolt", Mtg.StackKind.SPELL, 0)
	_push_chain(screen, "Prodigal Sorcerer", Mtg.StackKind.ABILITY, 1)
	var fireball := _push_chain(screen, "Fireball", Mtg.StackKind.SPELL, 0, 3)
	screen._refresh()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_true(screen._chain_box.visible, "the chain shows while it is not empty")
	var cards := _mini_cards(screen._chain_box)
	assert_eq(cards.size(), 3, "one small card per chain object")
	_assert_all_one_size(screen._chain_box, "spell chain")
	for entry in screen._chain_box.get_children():
		assert_eq((entry as Control).size.x, MiniCard.SIZE.x,
			"a chain entry is exactly one card wide — the caption wraps "
				+ "inside it, it never widens the strip")
	# The behaviour the caption box used to carry alone: the targets line,
	# the Showcase hover, and the click a counterspell takes its target
	# with (`_on_card_clicked` → `_try_take_target`).
	for card in cards:
		assert_true(card.tooltip_text.contains("(test)"),
			"%s: the chain object's description survives on the card"
				% card.instance.data.card_name)
		assert_gt(card.pressed.get_connections().size(), 0,
			"%s: a chain object is still clickable" % card.instance.data.card_name)
		assert_gt(card.mouse_entered.get_connections().size(), 0,
			"%s: ...and still opens the Showcase on hover"
				% card.instance.data.card_name)
	# THE 1997 WORDS, from the tags the original captions chain objects
	# with — `@PROMPT_CAST1` / `@PROMPT_TAP1` / `@PROMPT_PROC1`
	# (`Program/UIStrings.txt:1118,1123,1134`), whose `%s` is the player
	# (`src/functions/events.c:563` fills PROC1 with `opponent_name`).
	var names := screen.game.players
	assert_eq(screen._chain_caption(screen.game.stack[0]),
		"%s casts..." % names[0].player_name, "@PROMPT_CAST1")
	assert_eq(screen._chain_caption(screen.game.stack[1]),
		"%s activates..." % names[1].player_name, "@PROMPT_TAP1")
	assert_eq(screen._chain_caption(fireball),
		"%s casts...\nX is 3." % names[0].player_name,
		"@PROMPT_CAST1's second line carries the chosen X")
	# ...and the name is NOT repeated in the band: the small card titles
	# itself, which is what `DrawSmallCardTitle` does.
	for entry in screen._chain_box.get_children():
		var band: Label = entry.get_child(0).get_child(0)
		assert_false(band.text.contains("Fireball"),
			"the card's own title bar names it, not the caption")
	screen.game.stack.clear()
	screen._refresh()
	await get_tree().process_frame
	assert_false(screen._chain_box.visible, "an empty chain shows nothing")


## A TRIGGER is the chain's third kind and the original has its own word
## for it — `%s processes...` — where ours said "Triggered Ability".
func test_a_triggered_ability_on_the_chain_says_processes() -> void:
	var screen := await _duel()
	var item := _push_chain(screen, "Grizzly Bears", Mtg.StackKind.TRIGGER, 1)
	screen._refresh()
	await get_tree().process_frame
	assert_eq(screen._chain_caption(item),
		"%s processes..." % screen.game.players[1].player_name,
		"@PROMPT_PROC1 (Program/UIStrings.txt:1134)")
	_assert_all_one_size(screen._chain_box, "a trigger on the chain")
