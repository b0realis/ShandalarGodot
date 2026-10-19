extends GutTest
## THE LOOP LIMIT's message on the duel screen (2026-10-19,
## [constant MtgGame.LOOP_LIMIT], [method DuelScreen.loop_limit_message]).
## The owner: *"Yes all infinity loops should be accompanied by a message -
## You created and infinity loop - stopping at 1000 steps."* — held on the
## Situation Bar in the refusal's ink, "You" to the player at this screen
## and the seat's name for the computer.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = DuelConfig.vs_ai_default(AiProfile.wizard())
	add_child_autofree(screen)
	await get_tree().process_frame
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))


## Trip the limit for [param seat] — the thousandth step is that seat's.
func _trip(seat: int) -> void:
	var g: MtgGame = screen.game
	g.loop_stopped_by = -1
	g.loop_steps = MtgGame.LOOP_LIMIT - 1
	g._count_loop_step(seat)


func test_the_player_reads_you_created_an_infinite_loop() -> void:
	_trip(0)
	assert_eq(screen._prompt_label.text, "You created an infinite loop — stopping at 1000 steps.")
	assert_eq(screen._prompt_label.get_theme_color("font_color"), DuelScreen.WARNING,
		"held in the refusal's ink")


func test_the_computers_loop_is_named() -> void:
	_trip(1)
	var name: String = screen.game.players[1].player_name
	assert_eq(screen._prompt_label.text, "%s created an infinite loop — stopping at 1000 steps." % name)
	assert_true(Array(screen.game.log_lines).has(
		"%s created an infinite loop — stopping at 1000 steps." % name), "and in the duel log")


func test_the_message_is_said_once_a_step() -> void:
	var g: MtgGame = screen.game
	_trip(0)
	var lines := g.log_lines.size()
	g._count_loop_step(0)
	g._count_loop_step(1)
	assert_eq(g.log_lines.size(), lines, "the loop is stopped already")
	assert_eq(DuelScreen.loop_limit_message("Black Wizard", false),
		"Black Wizard created an infinite loop — stopping at 1000 steps.")
