extends GutTest
## THE SITUATION BAR GROWS DOWN FROM ITS TOP EDGE (0.50.66 bug campaign,
## h4-3). At a larger UI scale ([constant DuelScreenOptions.UI_SCALES]) the
## bar grew about its middle row, and at 150% climbed 9 rows over the
## opponent's hand window, whose default corner ([method
## Settings.opp_hand_stack_pos]) hangs its title bar just above the seam:
## "Opponent (n)" and its ↑ half hidden under an ordinary prompt at
## 1280x800, mostly hidden at 2560x1440. Its top edge now stays where it
## stands at 100%, at every scale.

const KEYS: Array[String] = [DuelScreenOptions.UI_SCALE_KEY, "opp_hand_stack_pos",
	"hand_stack_pos", "hand_style"]

var screen: DuelScreen = null
var _saved: Dictionary = {}


func before_each() -> void:
	_saved = {}
	for key in KEYS:
		_saved[key] = Settings.get_value(key, null) if Settings.has_value(key) else null
		Settings.clear_value(key)


func after_each() -> void:
	for key in KEYS:
		if _saved[key] == null:
			Settings.clear_value(key)
		else:
			Settings.set_value(key, _saved[key])


func _duel() -> void:
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 1000.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	screen.set_anchors_preset(Control.PRESET_TOP_LEFT)
	screen.size = Vector2(1280, 800)
	await get_tree().process_frame
	await get_tree().process_frame


## The two hand windows: [the opponent's, the player's].
func _hands() -> Array:
	var out: Array = [null, null]
	for child in screen.get_children():
		if child is StackHand:
			out[0 if (child as StackHand).settings_key == "opp_hand_stack_pos" else 1] = child
	return out


func test_the_bar_keeps_its_top_edge_at_every_scale() -> void:
	await _duel()
	var at_100: Rect2 = screen._situation_bar.get_global_rect()
	for scale in DuelScreenOptions.UI_SCALES:
		DuelScreenOptions.set_ui_scale(scale)
		screen._on_screen_options_closed()
		await get_tree().process_frame
		var drawn: Rect2 = screen._situation_bar.get_global_rect()
		assert_almost_eq(drawn.position.y, at_100.position.y, 0.5,
			"%d%%: the top edge where it stands at 100%%" % roundi(scale * 100))
		assert_almost_eq(drawn.position.x, at_100.position.x, 0.5,
			"%d%%: and the left end" % roundi(scale * 100))


func test_at_150_percent_the_opponents_title_bar_stays_clear() -> void:
	DuelScreenOptions.set_ui_scale(1.5)
	await _duel()
	var hands := _hands()
	assert_not_null(hands[0], "control: the opponent's window")
	if hands[0] == null:
		return
	var bar: Rect2 = screen._situation_bar.get_global_rect()
	assert_almost_eq(screen._situation_bar.scale.y, 1.5, 0.001, "control: scaled")
	var opp: StackHand = hands[0]
	var title_foot: float = opp.global_position.y + StackHand.BAR_TOP + StackHand.BAR_HEIGHT
	assert_lte(title_foot, bar.position.y + 0.5,
		"the opponent's title bar (%s) above the bar (%s), whatever its sentence" % [title_foot, bar])
	assert_almost_eq(bar.position.y, screen._situation_bar.position.y, 0.5,
		"drawn from where it is laid out")
