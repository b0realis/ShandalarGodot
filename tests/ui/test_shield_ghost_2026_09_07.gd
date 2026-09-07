extends GutTest
## THE SHIELD GHOST — a Healing Salve drawn behind the creature it
## shields, for the turn the shield lasts, with the amount on the
## creature's face. The owner's request of 2026-09-07:
##
## *"Cast Healing Salve on a creature should be like an aura (mini card
## behind a creature) just last only one turn. To know that that
## creature has healing salve on it. (Now it goes to graveyard). Also
## mini card should have some symbol like "prevent 3" red letter in
## center of the card so player knows. This mechanic can be reused on
## other preventions cards in the future."*
##
## WHAT IS PINNED. A creature with a prevention pool wears the card that
## filled it ([member CardInstance.prevention_source]) as the OUTERMOST
## step of its aura fan (`DuelScreen._shield_ghost`, `_make_widget`),
## built from the definition — no id, no click, hover previews it — and
## the words "prevent 3" in [constant MiniCard.SHIELD_INK] over its own
## art, following the pool and gone with it; the free layer's footprint
## counts the ghost as a step; a creature shielding itself (Rock Hydra's
## `{R}`) gets the words and not a copy of itself behind it; a targeting
## stamp takes the centre for as long as it is up.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func _mk(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


func _summon(card_name: String, pid: int) -> CardInstance:
	var inst := _mk(card_name, pid)
	screen.game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := _mk(card_name, pid)
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


## The pool as the engine leaves it after a shield resolves.
func _shield(inst: CardInstance, pool: int, from: String) -> void:
	inst.prevention = pool
	inst.prevention_source = CardRegistry.get_card(from)


func _redraw() -> void:
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame


## Every [MiniCard] on the screen with a real instance, by instance id.
func _drawn() -> Dictionary:
	var out := {}
	for card in _cards():
		if card.instance != null and card.instance.id >= 0:
			out[card.instance.id] = card
	return out


func _cards() -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MiniCard:
			out.append(n)
		for c in n.get_children():
			stack.append(c)
	return out


## The ghosts on the screen — cards with no id, named by the widget.
func _ghosts() -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	for card in _cards():
		if card.name == "ShieldGhost":
			out.append(card)
	return out


func _fan_corner(host_w: MiniCard) -> Vector2:
	# An untapped host stands at the wrap's own origin.
	return host_w.position


# ================================================== THE SALVE BEHIND --

func test_a_salved_creature_wears_the_salve_behind_it() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	assert_not_null(host_w)
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1, "one ghost, for one shield")
	var ghost: MiniCard = ghosts[0]
	assert_eq(ghost.instance.data.card_name, "Healing Salve")
	assert_eq(ghost.instance.id, -1, "built from the definition, not an instance")
	assert_eq(ghost.get_parent(), host_w.get_parent(), "in the host's fan")
	assert_lt(ghost.get_index(), host_w.get_index(), "behind the host")
	assert_eq(ghost.size, MiniCard.SIZE, "a whole card, like an aura")
	assert_eq(ghost.position, _fan_corner(host_w)
		+ Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y),
		"one fan step out, exactly where an aura would stand")
	assert_eq(host_w.z_index, DuelScreen.HOST_Z, "the host covers it, as it does an aura")


func test_the_ghost_takes_no_click_and_no_focus() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var ghost: MiniCard = _ghosts()[0]
	assert_true(ghost.disabled, "never presses")
	assert_eq(ghost.focus_mode, Control.FOCUS_NONE)
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_PASS,
		"...but its title band still hovers, so the sidebar can show the Salve")
	ghost.mouse_entered.emit()
	assert_eq(screen._card_preview._shown, ghost.instance,
		"hovering the ghost docks the Salve in the sidebar")


func test_no_shield_no_ghost() -> void:
	var bear := _summon("Grizzly Bears", 0)
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	assert_eq(_ghosts().size(), 0)
	assert_null(host_w._shield_words, "and no words were ever built")
	assert_eq(host_w.z_index, 0, "a plain card, at rest")


func test_a_drained_pool_shows_nothing_though_the_name_lingers() -> void:
	# The engine leaves `prevention_source` set while the pool drains to
	# 0 and clears both at cleanup; the table reads the pool.
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 0, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	assert_eq(_ghosts().size(), 0, "no pool, no ghost")
	assert_null(host_w._shield_words, "no pool, no words")


func test_the_ghost_stands_outside_the_auras() -> void:
	var bear := _summon("Grizzly Bears", 0)
	var strength := _enchant("Holy Strength", bear, 0)
	_shield(bear, 1, "Samite Healer")
	await _redraw()
	var drawn := _drawn()
	var host_w: MiniCard = drawn.get(bear.id)
	var aura_w: MiniCard = drawn.get(strength.id)
	var ghost: MiniCard = _ghosts()[0]
	var corner := _fan_corner(host_w)
	assert_eq(aura_w.position, corner
		+ Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y),
		"the aura keeps its step next to the host")
	assert_eq(ghost.position, corner
		+ Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y) * 2.0,
		"the ghost is the outermost step")
	assert_lt(ghost.get_index(), aura_w.get_index(), "drawn first, so under the aura")
	assert_lt(aura_w.get_index(), host_w.get_index())
	var wrap: Control = host_w.get_parent()
	assert_eq(wrap.custom_minimum_size.x,
		MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x * 2.0,
		"and the fan reserves width for both steps")


func test_the_free_layer_counts_the_ghost_as_a_step() -> void:
	var bear := _summon("Grizzly Bears", 0)
	var plain := screen._placement_span(bear)
	_shield(bear, 3, "Healing Salve")
	var shielded := screen._placement_span(bear)
	assert_eq(shielded.position.y, -DuelScreen.AURA_PEEK.y,
		"one step of overflow above the host")
	assert_eq(shielded.size.x, maxf(plain.size.x,
		(MiniCard.TURN_HOLDER_SIZE.x - MiniCard.SIZE.y) / 2.0
			+ MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x),
		"one step of width to the right")
	assert_eq(screen._fan_steps(bear), 1)
	_enchant("Holy Strength", bear, 0)
	assert_eq(screen._fan_steps(bear), 2, "an aura and the ghost")


func test_a_creature_shielding_itself_wears_no_ghost() -> void:
	var hydra := _summon("Rock Hydra", 0)
	screen.game.add_counters(hydra, "+1/+1", 2)
	hydra.prevention = 1
	hydra.prevention_source = hydra.data
	await _redraw()
	var host_w: MiniCard = _drawn().get(hydra.id)
	assert_eq(_ghosts().size(), 0, "a Hydra is not drawn behind the Hydra")
	assert_eq(host_w._shield_words.text, "prevent 1", "the words still say so")
	assert_eq(host_w.z_index, 0, "no fan, so no host lift")


# ============================================== THE WORDS ON THE FACE --

func test_the_words_are_red_in_the_middle_of_the_art() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	var words: Label = host_w._shield_words
	assert_not_null(words)
	assert_true(words.visible)
	assert_eq(words.text, "prevent 3")
	assert_eq(words.get_theme_color("font_color"), MiniCard.SHIELD_INK, "red letters")
	assert_eq(words.get_theme_constant("outline_size"), MiniCard.PT_OUTLINE_SIZE,
		"outlined like the P/T, so they read on any art")
	assert_eq(words.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER)
	assert_eq(words.vertical_alignment, VERTICAL_ALIGNMENT_CENTER)
	# Anchors are stored as float32; the constants are doubles.
	assert_almost_eq(words.anchor_left, MiniCard.ART_LEFT, 0.001)
	assert_almost_eq(words.anchor_right, MiniCard.ART_RIGHT, 0.001)
	assert_almost_eq(words.anchor_top, MiniCard.ART_TOP, 0.001)
	assert_almost_eq(words.anchor_bottom, MiniCard.ART_BOTTOM, 0.001)
	assert_eq(words.mouse_filter, Control.MOUSE_FILTER_IGNORE, "the card stays clickable")
	assert_string_contains(host_w.tooltip_text,
		"Prevents the next 3 damage to this creature this turn (Healing Salve)")


func test_the_words_follow_the_pool() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	assert_eq(host_w._shield_words.text, "prevent 3")
	bear.prevention = 1   # two of the three soaked
	host_w.refresh()
	assert_eq(host_w._shield_words.text, "prevent 1")
	bear.prevention = 0
	host_w.refresh()
	assert_false(host_w._shield_words.visible, "drained: the words go")
	bear.prevention = MiniCard.SHIELD_ALL   # Indestructible Aura
	host_w.refresh()
	assert_true(host_w._shield_words.visible)
	assert_eq(host_w._shield_words.text, "prevent all")
	assert_string_contains(host_w.tooltip_text, "Prevents all damage to this creature")


func test_shield_words() -> void:
	assert_eq(MiniCard.shield_words(1), "prevent 1")
	assert_eq(MiniCard.shield_words(12), "prevent 12")
	assert_eq(MiniCard.shield_words(9999), "prevent all")
	assert_eq(MiniCard.shield_words(20000), "prevent all")


func test_a_targeting_stamp_takes_the_centre_while_it_is_up() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	assert_true(host_w._shield_words.visible)
	host_w.set_target_state(MiniCard.State.CANT_TARGET)
	assert_false(host_w._shield_words.visible, "the slash has the centre")
	host_w.set_target_state(-1)
	assert_true(host_w._shield_words.visible, "and gives it back")


func test_a_face_down_card_tells_nothing() -> void:
	var bear := _summon("Grizzly Bears", 0)
	_shield(bear, 3, "Healing Salve")
	await _redraw()
	var host_w: MiniCard = _drawn().get(bear.id)
	host_w.face_down = true
	assert_false(host_w._shield_words.visible)
