extends GutTest
## THE PRE-DUEL SPLASH — who is playing whom, with what.
##
## The 1997 game puts this between "Go" and the coin toss, and so do we
## ([DuelScreen._run_coin_toss]). What these pin is everything a player
## reads off it and the three ways it ends.

func _config() -> DuelConfig:
	var config := DuelConfig.new()
	config.player_names = ["b0realis", "HAL 9000"]
	config.deck_names = ["High Priest", "Kiska-Ra - White Dragon"]
	config.panel_colors = ["red", "black"]
	return config


func _intro(config: DuelConfig) -> DuelIntro:
	var host := Control.new()
	host.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child_autofree(host)
	var intro := DuelIntro.new()
	host.add_child(intro)
	intro.build(config)
	return intro


func _texts(node: Node) -> Array[String]:
	var out: Array[String] = []
	for child in node.find_children("*", "Label", true, false):
		out.append((child as Label).text)
	return out


func test_it_names_both_duelists_and_both_decks() -> void:
	var intro := _intro(_config())
	await get_tree().process_frame
	var said := _texts(intro)
	assert_true(said.has("b0realis"), "the player's name")
	assert_true(said.has("HAL 9000"), "and the opponent's")
	assert_true(said.has("playing with High Priest"), "with the deck")
	assert_true(said.has("playing with Kiska-Ra - White Dragon"))
	assert_true(said.has("vs."), "the original's own word between them")


func test_a_seat_with_no_deck_name_says_nothing_rather_than_guessing() -> void:
	# A scene run or a test builds a config with no deck names; the splash
	# still introduces the duelists and simply omits the line.
	var config := _config()
	config.deck_names = ["", ""]
	var intro := _intro(config)
	await get_tree().process_frame
	for said in _texts(intro):
		assert_false(said.begins_with("playing with"), said)


func test_a_seat_that_chose_no_portrait_wears_its_duelist_face() -> void:
	# The face above the deck picker is derived from the deck's colour;
	# with no chosen portrait that is what the splash shows, so the well
	# is never empty.
	var config := _config()
	config.portraits = ["", ""]
	assert_eq(DuelIntro.portrait_for(config, 0),
		DuelistFace.portrait("red"))
	assert_eq(DuelIntro.portrait_for(config, 1),
		DuelistFace.portrait("black"))


func test_five_seconds_and_it_goes_on_by_itself() -> void:
	var intro := _intro(_config())
	await get_tree().process_frame
	assert_almost_eq(intro.seconds_left(), DuelIntro.TIMEOUT, 0.5)
	var went := [false]
	intro.go_pressed.connect(func() -> void: went[0] = true)
	intro._process(DuelIntro.TIMEOUT - 0.1)
	assert_false(went[0], "not yet")
	intro._process(0.2)
	assert_true(went[0], "and then it does, with nobody touching anything")


func test_the_two_buttons_are_the_two_answers() -> void:
	var intro := _intro(_config())
	await get_tree().process_frame
	var labels: Array[String] = []
	for button in intro.find_children("*", "Button", true, false):
		labels.append((button as Button).text)
	assert_true(labels.has("Go!"), "start the duel")
	assert_true(labels.has("Reconfigure duel"),
		"or go back and change your mind — the owner's ask")


func test_reconfigure_says_so_rather_than_starting_the_duel() -> void:
	var intro := _intro(_config())
	await get_tree().process_frame
	var heard: Array[String] = []
	intro.go_pressed.connect(func() -> void: heard.append("go"))
	intro.reconfigure_pressed.connect(func() -> void: heard.append("back"))
	for button in intro.find_children("*", "Button", true, false):
		if (button as Button).text == "Reconfigure duel":
			(button as Button).pressed.emit()
	assert_eq(heard, ["back"])
