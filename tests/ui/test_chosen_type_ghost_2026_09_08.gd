extends GutTest
## THE JAGUAR'S CHOICE — the creature type an Aswan Jaguar rolled as it
## came into play, drawn behind it like an aura for as long as it stands.
## The owner's request of 2026-09-08:
##
## *"When "aswan jaguar" comes into play, it chooses a random creature
## type from opponent deck. The chosen creature type name should be
## present as a back mini card like aura - with creature type as it name
## on the aura card top, so player quickly knows which type was randomly
## chosen!"*
##
## WHAT IS PINNED. A card whose definition names the memory key its
## choice lives under ([member CardData.chosen_type_key]) wears a ghost
## card titled with the choice as the INNERMOST step of its fan
## (`DuelScreen._chosen_ghost`, `_make_widget`): an aura in the chooser's
## colour, built for the purpose — no id, no click, hover previews it —
## standing nearest the host, with the auras beyond it and the shield
## ghost outermost; the free layer's footprint counts it as a step;
## no choice yet shows nothing; a resolved empty choice says "No creatures";
## Phantasmal Terrain, which keeps a land type under the same key, grows
## no ghost; and the engine's own roll is what the ghost shows.

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


## A Jaguar that has already made its choice, as the engine leaves it.
func _jaguar(pid: int, chosen: String) -> CardInstance:
	var jaguar := _summon("Aswan Jaguar", pid)
	screen.game.stack.clear()   # the trigger, which would roll for itself
	jaguar.memory["type"] = chosen
	return jaguar


func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := _mk(card_name, pid)
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


func _shield(inst: CardInstance, pool: int, from: String) -> void:
	inst.prevention = pool
	inst.prevention_source = CardRegistry.get_card(from)


func _redraw() -> void:
	screen.game.recalculate()
	screen._refresh()
	await get_tree().process_frame


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


## Every [MiniCard] on the screen with a real instance, by instance id.
func _drawn() -> Dictionary:
	var out := {}
	for card in _cards():
		if card.instance != null and card.instance.id >= 0:
			out[card.instance.id] = card
	return out


## The ghosts on the screen named [param node_name] — cards with no id.
func _ghosts(node_name := "ChosenGhost") -> Array[MiniCard]:
	var out: Array[MiniCard] = []
	for card in _cards():
		if card.name == node_name:
			out.append(card)
	return out


func _step(n: float) -> Vector2:
	return Vector2(DuelScreen.AURA_PEEK.x, -DuelScreen.AURA_PEEK.y) * n


# ============================================= THE CHOICE BEHIND --

func test_the_jaguar_wears_its_choice_behind_it() -> void:
	var jaguar := _jaguar(0, "elf")
	await _redraw()
	var host_w: MiniCard = _drawn().get(jaguar.id)
	assert_not_null(host_w)
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1, "one ghost, for one choice")
	var ghost: MiniCard = ghosts[0]
	assert_eq(ghost.instance.data.card_name, "Elf", "the type, as the card's title")
	assert_eq(ghost.instance.id, -1, "built for the purpose, no instance behind it")
	assert_eq(ghost.get_parent(), host_w.get_parent(), "in the host's fan")
	assert_lt(ghost.get_index(), host_w.get_index(), "behind the host")
	assert_eq(ghost.size, MiniCard.SIZE, "a whole card, like an aura")
	assert_eq(ghost.position, host_w.position + _step(1.0),
		"one fan step out, exactly where an aura would stand")
	assert_eq(host_w.z_index, 0, "the host covers it by child order, as it does an aura")


func test_the_ghost_is_an_aura_in_the_jaguars_colour() -> void:
	var jaguar := _jaguar(0, "elf")
	var data := screen._chosen_ghost_data(jaguar)
	assert_not_null(data)
	assert_true(data.is_type(Mtg.CardType.ENCHANTMENT))
	assert_true(data.subtypes.has("aura"), "an aura, the shape the owner named")
	assert_eq(CardPreview._type_line(data), "Enchantment — Aura")
	assert_eq(data.color_mask(), Mtg.ManaColor.G, "green, like the Jaguar")
	assert_eq(MiniCard.frame_color(data),
		MiniCard.frame_color(CardRegistry.get_card("Regeneration")),
		"framed like a green aura")
	assert_eq(data.cost.mana_value(), 0, "no cost on its face")
	assert_string_contains(data.oracle_text, "Aswan Jaguar chose this creature type")


func test_the_ghost_takes_no_click_and_hovers_into_the_sidebar() -> void:
	_jaguar(0, "elf")
	await _redraw()
	var ghost: MiniCard = _ghosts()[0]
	assert_true(ghost.disabled, "never presses")
	assert_eq(ghost.focus_mode, Control.FOCUS_NONE)
	assert_eq(ghost.mouse_filter, Control.MOUSE_FILTER_PASS,
		"...but its title band still hovers, so the sidebar can show the choice")
	ghost.mouse_entered.emit()
	assert_eq(screen._card_preview._shown, ghost.instance,
		"hovering the ghost docks it in the sidebar")


func test_no_choice_no_ghost() -> void:
	var jaguar := _summon("Aswan Jaguar", 0)
	screen.game.stack.clear()   # the trigger still pending: nothing chosen yet
	await _redraw()
	var host_w: MiniCard = _drawn().get(jaguar.id)
	assert_eq(_ghosts().size(), 0, "no choice yet, nothing to show")
	assert_eq(host_w.z_index, 0, "a plain card, at rest")
	assert_eq(screen._fan_steps(jaguar), 0)


func test_a_choice_of_nothing_shows_no_creatures(
		pid = use_parameters([0, 1])) -> void:
	var jaguar := _jaguar(pid, "")
	await _redraw()
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1, "an empty result is different from a pending trigger")
	if ghosts.size() != 1:
		return
	var ghost: MiniCard = ghosts[0]
	assert_eq(ghost.instance.data.card_name, "No creatures")
	assert_eq(ghost._name_label.text, "No creatures", "the whole title fits")
	assert_eq(ghost.instance.controller_id, pid)
	assert_eq(ghost.instance.id, -1, "a reminder, not another permanent")
	assert_true(ghost.disabled)
	assert_eq(ghost.get_parent(), _drawn()[jaguar.id].get_parent())
	assert_eq(ghost.position, _drawn()[jaguar.id].position + _step(1.0))
	assert_string_contains(ghost.tooltip_text, "opponent's library")
	assert_string_contains(ghost.tooltip_text, "No creature type was chosen")
	ghost.mouse_entered.emit()
	assert_eq(screen._card_preview._shown, ghost.instance)
	assert_eq(screen._fan_steps(jaguar), 1)
	assert_eq(String(jaguar.memory["type"]), "", "the rules result stays empty")
	assert_true(jaguar.attachments.is_empty(), "the reminder is not a real Aura")


func test_an_empty_library_choice_appears_when_the_trigger_resolves(
		pid = use_parameters([0, 1])) -> void:
	var g: MtgGame = screen.game
	var opponent := g.opponent_of(pid)
	g.players[opponent].library.clear()
	var forest := _mk("Forest", opponent)
	forest.zone = Mtg.Zone.LIBRARY
	g.players[opponent].library.append(forest)
	_summon("Grizzly Bears", opponent)  # in play is not in the library
	var jaguar := _summon("Aswan Jaguar", pid)
	assert_false(jaguar.memory.has("type"), "the trigger has not resolved yet")
	assert_null(screen._chosen_ghost_data(jaguar), "do not announce an empty result early")
	var guard := 0
	while not g.stack.is_empty() and guard < 10:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1
	await get_tree().process_frame  # engine signal only; no forced redraw
	assert_true(g.stack.is_empty())
	assert_true(jaguar.memory.has("type"))
	assert_eq(String(jaguar.memory["type"]), "")
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1)
	if ghosts.size() != 1:
		return
	assert_eq(ghosts[0]._name_label.text, "No creatures")
	assert_true(ghosts[0]._name_label.is_visible_in_tree())


func test_the_opponents_jaguar_shows_its_choice_too() -> void:
	# Theirs chose from YOUR deck; which of your creatures it hunts is the
	# thing you most want to know.
	var jaguar := _jaguar(1, "bear")
	await _redraw()
	var host_w: MiniCard = _drawn().get(jaguar.id)
	assert_not_null(host_w)
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1)
	assert_eq(ghosts[0].instance.data.card_name, "Bear")
	assert_eq(ghosts[0].instance.controller_id, 1, "theirs, like the Jaguar")
	assert_eq(ghosts[0].get_parent(), host_w.get_parent())


# ============================================= ITS PLACE IN THE FAN --

func test_the_choice_stands_nearest_the_host_and_an_aura_outside() -> void:
	var jaguar := _jaguar(0, "elf")
	var regen := _enchant("Regeneration", jaguar, 0)
	await _redraw()
	var drawn := _drawn()
	var host_w: MiniCard = drawn.get(jaguar.id)
	var aura_w: MiniCard = drawn.get(regen.id)
	var ghost: MiniCard = _ghosts()[0]
	var corner: Vector2 = host_w.position
	assert_eq(ghost.position, corner + _step(1.0),
		"the choice keeps the step next to the host — it was there first")
	assert_eq(aura_w.position, corner + _step(2.0),
		"the aura, cast later, lands outside it and moves nothing")
	assert_lt(aura_w.get_index(), ghost.get_index(), "the aura is drawn first, so under the choice")
	assert_lt(ghost.get_index(), host_w.get_index())
	var wrap: Control = host_w.get_parent()
	assert_eq(wrap.custom_minimum_size.x,
		MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x * 2.0,
		"and the fan reserves width for both steps")


func test_the_shield_ghost_stays_outermost() -> void:
	var jaguar := _jaguar(0, "elf")
	var regen := _enchant("Regeneration", jaguar, 0)
	_shield(jaguar, 3, "Healing Salve")
	await _redraw()
	var drawn := _drawn()
	var host_w: MiniCard = drawn.get(jaguar.id)
	var aura_w: MiniCard = drawn.get(regen.id)
	var choice: MiniCard = _ghosts()[0]
	var shield: MiniCard = _ghosts("ShieldGhost")[0]
	var corner: Vector2 = host_w.position
	assert_eq(choice.position, corner + _step(1.0), "the choice, nearest")
	assert_eq(aura_w.position, corner + _step(2.0), "the aura")
	assert_eq(shield.position, corner + _step(3.0), "the Salve, briefest, outermost")
	assert_lt(shield.get_index(), aura_w.get_index())
	assert_lt(aura_w.get_index(), choice.get_index())
	assert_lt(choice.get_index(), host_w.get_index())
	assert_eq(screen._fan_steps(jaguar), 3)


func test_the_free_layer_counts_the_choice_as_a_step() -> void:
	var jaguar := _summon("Aswan Jaguar", 0)
	screen.game.stack.clear()
	var plain := screen._placement_span(jaguar)
	jaguar.memory["type"] = "elf"
	var chosen := screen._placement_span(jaguar)
	assert_eq(chosen.position.y, -DuelScreen.AURA_PEEK.y,
		"one step of overflow above the host")
	assert_eq(chosen.size.x, maxf(plain.size.x,
		(MiniCard.TURN_HOLDER_SIZE.x - MiniCard.SIZE.y) / 2.0
			+ MiniCard.SIZE.x + DuelScreen.AURA_PEEK.x),
		"one step of width to the right")
	assert_eq(screen._fan_steps(jaguar), 1)
	_enchant("Regeneration", jaguar, 0)
	assert_eq(screen._fan_steps(jaguar), 2, "an aura and the choice")
	_shield(jaguar, 1, "Healing Salve")
	assert_eq(screen._fan_steps(jaguar), 3, "...and the shield")


# ================================================== THE DECLARATION --

func test_only_a_card_that_declares_its_choice_grows_a_ghost() -> void:
	assert_eq(CardRegistry.get_card("Aswan Jaguar").chosen_type_key, "type",
		"the key the Jaguar's ability reads its type back from")
	# Phantasmal Terrain keeps a LAND type under the very same key.
	var terrain := CardRegistry.get_card("Phantasmal Terrain")
	assert_eq(terrain.chosen_type_key, "", "it declares no creature type")
	var inst := _mk("Phantasmal Terrain", 0)
	inst.memory["type"] = "forest"
	assert_null(screen._chosen_ghost_data(inst), "no ghost for a land type")
	var bear := _summon("Grizzly Bears", 0)
	bear.memory["type"] = "elf"   # a stray key on a card that chooses nothing
	assert_null(screen._chosen_ghost_data(bear))
	assert_eq(screen._fan_steps(bear), 0)


func test_one_card_per_choice_so_the_sidebar_keeps_its_art() -> void:
	var a := _jaguar(0, "elf")
	var b := _jaguar(0, "elf")
	var c := _jaguar(1, "wall")
	assert_same(screen._chosen_ghost_data(a), screen._chosen_ghost_data(a),
		"the same definition on every redraw")
	assert_same(screen._chosen_ghost_data(a), screen._chosen_ghost_data(b),
		"two Jaguars, one choice, one card")
	assert_ne(screen._chosen_ghost_data(a), screen._chosen_ghost_data(c))
	assert_eq(screen._chosen_ghost_data(c).card_name, "Wall")


func test_the_ghost_shows_the_engines_own_roll() -> void:
	# Through the trigger: the opponent's library holds one creature type
	# (a Bear, not an Elf Druid), so the roll can only land there, and
	# the ghost says so.
	var g: MtgGame = screen.game
	g.players[1].library.clear()   # the screen dealt a whole deck
	var bears := _mk("Grizzly Bears", 1)
	bears.zone = Mtg.Zone.LIBRARY
	g.players[1].library.append(bears)
	var jaguar := _summon("Aswan Jaguar", 0)
	var guard := 0
	while not g.stack.is_empty() and guard < 10:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_true(g.stack.is_empty(), "the trigger resolved")
	assert_eq(String(jaguar.memory.get("type", "")), "bear")
	# Let the engine's normal state_changed signal repaint the choice.
	# A forced redraw here could conceal a missing live update.
	await get_tree().process_frame
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1)
	assert_eq(ghosts[0].instance.data.card_name, "Bear")


func test_casting_a_jaguar_shows_its_choice_without_a_manual_redraw(
		pid = use_parameters([0, 1])) -> void:
	var g: MtgGame = screen.game
	var opponent := g.opponent_of(pid)
	g.players[opponent].library.clear()
	var bears := _mk("Grizzly Bears", opponent)
	bears.zone = Mtg.Zone.LIBRARY
	g.players[opponent].library.append(bears)
	var jaguar := _mk("Aswan Jaguar", pid)
	jaguar.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(jaguar)
	g.active_player = pid
	g.priority_player = pid
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.MAIN1)
	g.players[pid].mana_pool.add(Mtg.ManaColor.G, 3)
	assert_eq(g.cast_spell(pid, jaguar, []), "")
	var guard := 0
	while not g.stack.is_empty() and guard < 10:
		assert_eq(g.pass_priority(g.priority_player), "")
		guard += 1
	await get_tree().process_frame
	assert_eq(jaguar.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(String(jaguar.memory.get("type", "")), "bear")
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1)
	if ghosts.size() != 1:
		return
	assert_eq(ghosts[0]._name_label.text, "Bear")
	assert_true(ghosts[0]._name_label.is_visible_in_tree())
	assert_eq(ghosts[0].get_parent(), _drawn()[jaguar.id].get_parent())


func test_the_chosen_title_stays_visible_when_the_jaguar_attacks(
		pid = use_parameters([0, 1])) -> void:
	var jaguar := _jaguar(pid, "elf")
	var g: MtgGame = screen.game
	g.active_player = pid
	g.priority_player = pid
	g._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS)
	g.awaiting_attackers = true
	assert_eq(g.declare_attackers(pid, [jaguar.id]), "")
	# Let the nested flow containers settle before reading screen bounds.
	for frame in 5:
		await get_tree().process_frame
	assert_true(jaguar.tapped)
	var ghosts := _ghosts()
	assert_eq(ghosts.size(), 1)
	if ghosts.size() != 1:
		return
	var ghost: MiniCard = ghosts[0]
	assert_true(screen._combat_window.is_ancestor_of(ghost))
	assert_eq(ghost._name_label.text, "Elf")
	assert_true(ghost._name_label.is_visible_in_tree())
	assert_eq(ghost.rotation, 0.0, "the reminder's title stays upright")
	var host: MiniCard = _drawn()[jaguar.id]
	var title_rect := ghost._name_label.get_global_rect()
	var holder: Control = host.get_parent()
	var turned_size := Vector2(MiniCard.SIZE.y, MiniCard.SIZE.x)
	var host_top := holder.global_position.y + (holder.size.y - turned_size.y) / 2.0
	assert_lte(title_rect.end.y, host_top,
		"the chosen type's entire title band is above the tapped Jaguar")
