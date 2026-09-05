class_name DuelIntro
extends VersusPanel
## THE PRE-DUEL SPLASH — who is about to play whom, with what.
##
## The 1997 game shows this between "Go" and the coin toss: two portraits
## in sunken wells on brown marble, `vs.` between them, each duelist's
## name under their face and *"playing with <deck>"* under that. The board
## itself — the art, the wells, the lettering, the portrait fallback — is
## [VersusPanel], which the Q/Esc [DuelPause] window shares; what is left
## here is this window's own two buttons and its five-second timer.
##
## WHAT IT SAYS. Everything comes off the [DuelConfig] the setup screen
## built: the names the player typed (an AI seat is HAL unless renamed),
## the decks they chose, and the portrait each seat picked. A seat with no
## chosen portrait falls back to its DUELIST face, which is derived from
## the deck's dominant colour — so the frame is never empty.
##
## HOW IT LEAVES, three ways: `Go!`, `Reconfigure duel` (back to the
## battle-setup screen), or five seconds of nobody touching anything,
## which is what keeps an AI demo — and the soak — moving.

## Seconds before it goes on by itself (the owner's number). THE ONLY
## CLOCK: it lives here and not in [VersusPanel], because the Pause window
## must never dismiss itself.
const TIMEOUT := 5.0

signal go_pressed
signal reconfigure_pressed

var _left := TIMEOUT


func build(config: DuelConfig) -> void:
	var board := build_panel(config)

	# The two ways out that are not a timer. `Reconfigure duel` is the
	# door back to the screen that set this up — the owner's ask, and the
	# only chance to change your mind after "Go".
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.position = Vector2(60, 345)
	buttons.size = Vector2(380, 40)
	var back := UiChrome.menu_button("Reconfigure duel", Vector2(190, 34), 15)
	back.pressed.connect(func() -> void: reconfigure_pressed.emit())
	buttons.add_child(back)
	var go := UiChrome.menu_button("Go!", Vector2(120, 34), 15)
	go.pressed.connect(func() -> void: go_pressed.emit())
	buttons.add_child(go)
	board.add_child(buttons)
	# Only when this screen is already in the tree — focus is a tree-wide
	# thing and asking for it outside one is an engine error, not a
	# no-op. The caller adds first for exactly this reason; the guard is
	# so a caller that forgets gets a splash rather than a red line.
	if is_inside_tree():
		go.grab_focus()
	set_process(true)


## The five-second timer. Kept here rather than in a SceneTreeTimer so a
## test can run it forward without waiting.
func _process(delta: float) -> void:
	_left -= delta
	if _left <= 0.0:
		set_process(false)
		go_pressed.emit()


## For tests: how long is left before it goes on by itself.
func seconds_left() -> float:
	return _left
