extends GameTest
## A FACE-DOWN PERMANENT IN A QUESTION AND IN THE SHOWCASE (gap review
## 2026-11-10, r3-2 and the owner's default for its question).
##
##  * r3-2 — a CARD question listed a face-down battlefield candidate by its
##    real name: a Clone's "copy which creature?" named the computer's
##    Illusionary Mask creature ("Serra Angel"), and a face-up namesake
##    beside it grew an ID tag that gave the secret away as well. Another
##    seat's face-down creature is now "Face-down creature #id".
##  * CR 708.5-708.6 (the owner's default): the CONTROLLER of a face-down
##    permanent may look at it, so its own question names it and the
##    Showcase shows its face to it — never to another seat, and at a
##    private hotseat only while that seat is the one looking (after Show
##    hand). The table keeps the card back for everyone.

var screen: DuelScreen


func after_each() -> void:
	await get_tree().process_frame
	await get_tree().process_frame


func _open(config: DuelConfig) -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	await get_tree().process_frame
	g = screen.game


func _vs_ai(seed := 93810) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	config.rng_seed = seed
	return config


func _private(seed := 93811) -> DuelConfig:
	var config := DuelConfig.hotseat_default()
	config.hotseat_privacy = true
	config.rng_seed = seed
	return config


func _stand(pid: int) -> void:
	g.active_player = pid
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = pid
	screen.mode = DuelScreen.Mode.NORMAL
	screen._refresh()


func _face_down(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	g.turn_face_down(inst)
	return inst


## Seat 0 casts a Clone and the copy question is held open for it.
func _clone_question() -> PlayerChoice:
	_stand(0)
	var clone := give_hand(0, "Clone")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, clone, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice, "control: the Clone asks its human")
	return g.awaiting_choice


func _mini_for(node: Node, inst: CardInstance) -> MiniCard:
	if node is MiniCard and (node as MiniCard).instance == inst:
		return node
	for child in node.get_children():
		var found := _mini_for(child, inst)
		if found != null:
			return found
	return null


## Hover [param inst]'s table widget, as the pointer does.
func _hover(inst: CardInstance) -> void:
	var widget := screen._make_widget(inst)
	add_child_autofree(widget)
	screen._card_preview.show_back()
	var card := _mini_for(widget, inst)
	assert_not_null(card, "control: the widget draws the card")
	if card != null:
		card.mouse_entered.emit()


func _shows_face(inst: CardInstance) -> bool:
	return not screen._card_preview._back.visible and screen._card_preview._shown == inst


# ================================================ r3-2: another seat's ---

func test_a_clone_question_does_not_name_the_computers_face_down_creature() -> void:
	await _open(_vs_ai())
	var angel := _face_down(1, "Serra Angel")
	var asked := _clone_question()
	if asked == null:
		return
	var labels := DuelScreen.choice_options(asked)
	for label in labels:
		assert_false(String(label).contains("Serra Angel"),
			"the line must not name the face-down creature: %s" % [labels])
	assert_true(labels.has("Face-down creature #%d" % angel.id),
		"it is listed as a face-down creature, told apart by its ID tag: %s" % [labels])


## THE HIDDEN-INFORMATION PERMUTATION: the lines a seat reads are the same
## whatever the other seat's face-down creature really is — a face-up
## namesake beside it included.
func test_the_lines_are_the_same_whatever_the_face_down_card_is() -> void:
	var seen: Array = []
	for secret in ["Serra Angel", "Grizzly Bears"]:
		var open := CardInstance.new(CardRegistry.get_card("Serra Angel"), 501, 1)
		open.zone = Mtg.Zone.BATTLEFIELD
		var masked := CardInstance.new(CardRegistry.get_card(secret), 502, 1)
		masked.zone = Mtg.Zone.BATTLEFIELD
		masked.face_down = true
		var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "Select creature to copy.")
		choice.candidates.assign([open, masked])
		seen.append(DuelScreen.choice_options(choice))
	assert_eq(seen[0], seen[1], "the lines do not depend on the hidden card")
	assert_eq(seen[0], ["Serra Angel", "Face-down creature #502"])


# ======================================== CR 708.5: the controller's own ---

func test_the_controller_reads_its_own_face_down_creature_in_its_question() -> void:
	await _open(_vs_ai(93812))
	var bears := _face_down(0, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	var asked := _clone_question()
	if asked == null:
		return
	var labels := DuelScreen.choice_options(asked)
	assert_true(labels.has("Grizzly Bears (face down) #%d" % bears.id),
		"its controller reads its name, and that it is face down: %s" % [labels])
	assert_true(labels.has("Serra Angel"), "control: the face-up creature as ever")


func test_the_controller_sees_its_own_face_down_creature_in_the_showcase() -> void:
	await _open(_vs_ai(93813))
	var mine := _face_down(0, "Grizzly Bears")
	var theirs := _face_down(1, "Serra Angel")
	_stand(0)
	assert_true(screen._may_show_face(mine), "its controller may look at it")
	assert_false(screen._may_show_face(theirs), "never at the computer's")
	_hover(mine)
	assert_true(_shows_face(mine), "the hover shows its controller the card")
	_hover(theirs)
	assert_true(screen._card_preview._back.visible, "and the computer's stays a back")
	# The card menu's `Show full card` reads the same rule.
	screen._card_preview.show_back()
	screen._card_menu_inst = mine
	screen._on_card_menu_chosen(0)
	assert_true(_shows_face(mine), "Show full card shows its own")
	screen._card_menu_inst = theirs
	screen._on_card_menu_chosen(0)
	assert_true(screen._card_preview._back.visible, "and not the computer's")
	# The table itself keeps the back for every seat.
	var widget := screen._make_widget(mine)
	add_child_autofree(widget)
	assert_true(_mini_for(widget, mine).face_down, "the table draws its back")


## A hidden hand's card is a back on the WIDGET only (the hand rebuild sets
## [member MiniCard.face_down] on a card that is face up in the game): the
## controller's look never opens it, by hover or by a right-press.
func test_a_hidden_hand_card_stays_a_back_in_the_showcase() -> void:
	await _open(_vs_ai(93816))
	_stand(0)
	var secret := give_hand(1, "Serra Angel")
	var mine := give_hand(0, "Grizzly Bears")
	for inst in [secret, mine]:
		var card := screen._make_card(inst)
		card.face_down = true
		add_child_autofree(card)
		screen._card_preview.show_back()
		card.mouse_entered.emit()
		assert_true(screen._card_preview._back.visible,
			"the hover keeps %s's card a back" % inst.data.card_name)
		var press := InputEventMouseButton.new()
		press.button_index = MOUSE_BUTTON_RIGHT
		press.pressed = true
		screen._on_card_look(press, card, inst)
		assert_true(screen._card_preview._back.visible,
			"and so does a right-press on %s" % inst.data.card_name)
		var release := InputEventMouseButton.new()
		release.button_index = MOUSE_BUTTON_RIGHT
		release.pressed = false
		screen._on_card_look(release, card, inst)
		screen._card_menu.hide()


func test_the_choice_windows_big_card_follows_the_same_rule() -> void:
	await _open(_vs_ai(93814))
	var mine := _face_down(0, "Grizzly Bears")
	var theirs := _face_down(1, "Serra Angel")
	_stand(0)
	var face := CardPreview.new()
	add_child_autofree(face)
	screen._preview_choice_line(face, mine)
	assert_false(face._back.visible, "its own line shows its card")
	screen._preview_choice_line(face, theirs)
	assert_true(face._back.visible, "the other seat's line shows a back")


func test_at_a_private_hotseat_only_while_its_seat_is_looking() -> void:
	await _open(_private())
	var mine := _face_down(0, "Grizzly Bears")
	_stand(0)
	assert_false(screen._may_show_face(mine), "before Show hand nobody is known to be looking")
	screen._toggle_hotseat_hand(0)
	assert_true(screen._may_see_hand(0), "control: seat 0 has shown its hand")
	assert_true(screen._may_show_face(mine), "now its controller looks at it")
	_hover(mine)
	assert_true(_shows_face(mine), "and the hover shows it")
	_stand(1)
	screen._toggle_hotseat_hand(1)
	assert_true(screen._may_see_hand(1), "control: seat 1 is at the screen")
	assert_false(screen._may_show_face(mine), "never to the other seat")
	_hover(mine)
	assert_true(screen._card_preview._back.visible, "the hover shows seat 1 a back")


func test_a_demo_shows_no_face_down_face() -> void:
	# Two computer seats: no controller of the card sits at the screen.
	var config := DuelConfig.demo_default()
	config.pace = 1000.0
	config.rng_seed = 93815
	await _open(config)
	var masked := _face_down(0, "Grizzly Bears")
	assert_false(screen._may_show_face(masked), "a seat nobody sits at shows no face")
