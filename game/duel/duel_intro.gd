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
## which is what keeps an AI demo — and the soak — moving. Inside a
## best-of match or a Gauntlet the second button asks first, and in a
## Gauntlet it reads `Quit Gauntlet` (review 2026-10-21, ui-1: [member
## DuelScreen.leave_question]); this window only says it was pressed.

## Seconds before it goes on by itself (the owner's number). THE ONLY
## CLOCK: it lives here and not in [VersusPanel], because the Pause window
## must never dismiss itself.
const TIMEOUT := 5.0

## [QoL] One shared reminder before a private duel, never a phase prompt.
const HOTSEAT_NOTICE := "Dear players, only show your hand when your opponent looks away. Good luck!"

## [QoL] Adventure's start action stays prominent even without keyboard focus.
const GO_ACCENT := Color(0.98, 0.81, 0.32)

signal go_pressed
signal reconfigure_pressed

var _left := TIMEOUT


func build(config: DuelConfig, back_label := "Reconfigure duel") -> void:
	var board := build_panel(config)
	if config.private_hotseat():
		# Use the spare title band above the portraits. A fixed-width holder
		# lets the sentence wrap without moving the faces, names or buttons.
		var band := Control.new()
		band.position = Vector2(18, 8)
		band.size = Vector2(SPLASH.x - 36, 44)
		band.mouse_filter = Control.MOUSE_FILTER_IGNORE
		board.add_child(band)
		var notice := make_label(HOTSEAT_NOTICE, 15)
		notice.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
		notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		notice.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		notice.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		band.add_child(notice)

	# The two ways out that are not a timer. `Reconfigure duel` is the
	# door back to the screen that set this up — the owner's ask, and the
	# only chance to change your mind after "Go".
	var buttons := HBoxContainer.new()
	buttons.add_theme_constant_override("separation", 14)
	buttons.alignment = BoxContainer.ALIGNMENT_CENTER
	buttons.position = Vector2(60, 345)
	buttons.size = Vector2(380, 40)
	# Adventure replaces Reconfigure with Concede. Its destructive action
	# must not inherit the wider button intended for that longer caption.
	var adventure := back_label == "Concede"
	var back := UiChrome.menu_button(back_label, Vector2(120 if adventure else 190, 34), 15)
	back.pressed.connect(func() -> void: reconfigure_pressed.emit())
	buttons.add_child(back)
	var go := UiChrome.menu_button("Go!", Vector2(190 if adventure else 120, 34),
		18 if adventure else 15, 0.4 if adventure else 0.0)
	if adventure:
		_highlight_go(go)
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


## Warm stone and a permanent gold rim, separate from the keyboard's focus
## ring. The rim ignores the mouse; the button keeps its pressed feedback.
static func _highlight_go(button: Button) -> void:
	button.add_theme_font_size_override("font_size", 18)
	var face := button.get_theme_stylebox("normal").duplicate() as StyleBox
	if face is StyleBoxTexture:
		face.modulate_color = Color(1.10, 1.03, 0.84)
	elif face is StyleBoxFlat:
		face.bg_color = UiChrome.FACE.lightened(0.13)
	button.add_theme_stylebox_override("normal", face)
	var focus := OriginalDialog.focus_ring().duplicate() as StyleBoxFlat
	focus.set_expand_margin_all(3.0)
	button.add_theme_stylebox_override("focus", focus)
	var rim := StyleBoxFlat.new()
	rim.draw_center = false
	rim.border_color = GO_ACCENT
	rim.set_border_width_all(2)
	var highlight := Panel.new()
	highlight.name = "PrimaryHighlight"
	highlight.mouse_filter = Control.MOUSE_FILTER_IGNORE
	highlight.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	highlight.add_theme_stylebox_override("panel", rim)
	button.add_child(highlight)


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
