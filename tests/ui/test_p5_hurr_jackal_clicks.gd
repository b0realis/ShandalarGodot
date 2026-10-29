extends GutTest
## THE HURR JACKAL REPORT, FOUND OUT (the polish pass, 2026-10-28).
##
## The owner, 2026-09-06: *"I have a Hurr Jackal — it has Firebreathing and
## The Brute enchantments on it. I attack with it, no blocker, no other
## cards in play. My attack does not go through to lower the life point of
## the opponent."* The investigation of that day could not reproduce it
## and left one question open — did life not move at all, or drop by 2? —
## and one gap: *nothing in this project exercised real mouse
## hit-testing*; every UI test called the click handler directly, so a
## click that a real pointer would have put somewhere else could never
## fail one.
##
## THIS FILE CLOSES THE GAP. The duel screen sits in its own SubViewport
## and is driven by REAL pointer events pushed into that viewport — a move,
## a press and a release at the widget's own position on the screen — so
## Godot's own GUI picking decides which control the click lands on, as it
## does for the player: the Done button, and the band of the OUTER aura
## standing proud of the creature (the band a pointer meets first). Played
## so, under both damage timings (the modern one, and the 1997
## damage-prevention window, `RulesOptions.damage_prevention_window`), the
## report's board takes the opponent from 20 to 18: Hurr Jackal is 1/1,
## The Brute adds +1/+0, and Firebreathing pumps only when {R} is paid.
## Life drops by 2.

const BOARD_SIZE := Vector2i(1280, 800)

var port: SubViewport
var screen: DuelScreen


func before_each() -> void:
	port = SubViewport.new()
	port.size = BOARD_SIZE
	port.gui_disable_input = false
	port.handle_input_locally = true
	add_child_autofree(port)
	var p := DuelPosition.new()
	for n in ["Mountain", "Mountain", "Mountain", "Hurr Jackal"]:
		p.add(0, DuelPosition.TABLE, n)
	for n in ["Swamp", "Swamp", "Swamp"]:
		p.add(1, DuelPosition.TABLE, n)
	p.active_player = 0
	p.step = Mtg.Step.MAIN1
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.hotseat_default().for_test(p, 4242)
	screen.config.pilots = [null, AiProfile.wizard()]
	screen.config.pace = 0.05   # the computer's pause between actions
	port.add_child(screen)
	for _i in 12:
		await get_tree().process_frame


func _jackal() -> CardInstance:
	for inst in screen.game.players[0].battlefield:
		if inst.data.card_name == "Hurr Jackal":
			return inst
	return null


func _dress(jackal: CardInstance) -> CardInstance:
	var g: MtgGame = screen.game
	var outer: CardInstance = null
	for n in ["Firebreathing", "The Brute"]:
		var aura := CardInstance.new(CardRegistry.get_card(n), g._next_instance_id, 0)
		g._next_instance_id += 1
		g._instances[aura.id] = aura
		aura.zone = Mtg.Zone.HAND
		g.players[0].hand.append(aura)
		g.attach_aura_from_anywhere(aura, jackal, 0)
		outer = aura
	screen._refresh()
	return outer


func _frames(n: int) -> void:
	for _i in n:
		await get_tree().process_frame


## The computer seat acts on the screen's own timer, in real time: wait
## for it as the player does.
func _settle() -> void:
	await get_tree().create_timer(0.4).timeout
	await _frames(2)


## A real click: the pointer moves there, presses, releases — pushed into
## the board's own viewport, where Godot picks the control under it.
func _click_at(at: Vector2) -> void:
	var move := InputEventMouseMotion.new()
	move.position = at
	move.global_position = at
	port.push_input(move)
	await _frames(2)
	for pressed in [true, false]:
		var ev := InputEventMouseButton.new()
		ev.button_index = MOUSE_BUTTON_LEFT
		ev.pressed = pressed
		ev.position = at
		ev.global_position = at
		port.push_input(ev)
		await _frames(2)


func _widget_of(inst: CardInstance) -> Control:
	var nodes: Array = [screen]
	while not nodes.is_empty():
		var n: Node = nodes.pop_back()
		if n is MiniCard and (n as MiniCard).instance == inst \
				and (n as Control).is_visible_in_tree():
			return n
		nodes.append_array(n.get_children())
	return null


func _play_the_report(window: bool) -> void:
	var g: MtgGame = screen.game
	g.rules.damage_prevention_window = window
	var jackal := _jackal()
	var outer := _dress(jackal)
	assert_eq(jackal.cur_power, 2, "1/1 and The Brute's +1/+0; Firebreathing unpaid")
	await _frames(6)
	var guard := 0
	while screen.mode != DuelScreen.Mode.ATTACKERS and guard < 8 and not g.game_over:
		await _click_at(screen._pass_button.get_global_rect().get_center())
		await _settle()
		guard += 1
	assert_eq(screen.mode, DuelScreen.Mode.ATTACKERS, "Done reached the attack")
	var band: Control = _widget_of(outer)
	assert_not_null(band, "the outer aura is on the table")
	if band == null:
		return
	var rect := band.get_global_rect()
	await _click_at(Vector2(rect.get_center().x, rect.position.y + 5))
	assert_true(screen._selected_attackers.has(jackal.id),
		"a real click on the outer band declares the creature")
	await _click_at(screen._pass_button.get_global_rect().get_center())
	await _settle()
	assert_true(g.combat != null and g.combat.attackers.has(jackal.id), "the engine has the attacker")
	guard = 0
	while g.current_step() != Mtg.Step.MAIN2 and guard < 20 and not g.game_over:
		await _click_at(screen._pass_button.get_global_rect().get_center())
		await _settle()
		guard += 1
	assert_eq(g.players[1].life, 18, "the attack went through: 20 to 18")


func test_the_report_through_real_clicks_modern_timing() -> void:
	await _play_the_report(false)


func test_the_report_through_real_clicks_with_the_1997_prevention_window() -> void:
	await _play_the_report(true)
