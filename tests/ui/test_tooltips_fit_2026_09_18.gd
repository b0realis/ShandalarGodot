extends GutTest
## HOVER TEXT THAT FITS THE WINDOW (2026-09-18). The owner's playtest: *"In
## options menu if you have a mouse on the setting there is hover text.
## But sometimes this hovertext overflows the window size and cannot be
## read. Fix this."* Godot's stock tooltip is one unwrapped line, and the
## engine only clamps its position; [method UiChrome.fit_tooltip] now
## wraps it as it enters the tree. A headless test cannot make the engine
## hover, so each popup here is built the way `Viewport::_gui_show_tooltip`
## builds one — a `TooltipLabel` inside a `TooltipPanel` hung on the
## control it describes — and measured the way the engine measures it,
## after the tree's `node_added` has had its say.

## The engine keeps this much of the window free around a tooltip.
const MARGIN := 32.0


func _popup(holder: Control, text: String) -> PopupPanel:
	var popup := PopupPanel.new()
	popup.theme_type_variation = &"TooltipPanel"
	popup.transparent_bg = true
	var label := Label.new()
	label.theme_type_variation = &"TooltipLabel"
	label.text = text
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	popup.transient = true
	popup.unfocusable = true
	popup.popup_window = false
	popup.mouse_passthrough = true
	popup.wrap_controls = true
	popup.add_child(label)
	holder.add_child(popup)
	return popup


func _label(popup: PopupPanel) -> Label:
	return popup.get_child(0) as Label


## Every hover text a screen can show: the controls' own, and the rows of
## their drop-down lists.
func _tooltips(root: Node) -> Array[String]:
	var found: Array[String] = []
	for node in root.find_children("*", "Control", true, false):
		if not String(node.tooltip_text).is_empty():
			found.append(node.tooltip_text)
		if node is OptionButton:
			for i in node.item_count:
				if not node.get_item_tooltip(i).is_empty():
					found.append(node.get_item_tooltip(i))
		if node is ItemList:
			for i in node.item_count:
				if not node.get_item_tooltip(i).is_empty():
					found.append(node.get_item_tooltip(i))
	return found


func _room(dimensions: Vector2i) -> Control:
	var viewport := SubViewport.new()
	viewport.size = dimensions
	add_child_autofree(viewport)
	var holder := Button.new()
	viewport.add_child(holder)
	return holder


func test_the_process_shapes_every_stock_tooltip() -> void:
	assert_true(get_tree().node_added.is_connected(UiChrome.fit_tooltip),
		"Lifecycle hangs the shaper on the tree at start")


func test_every_options_tooltip_fits_a_small_window_whole() -> void:
	var holder := _room(Vector2i(640, 480))
	var screen: Control = load("res://game/options_screen.tscn").instantiate()
	holder.get_parent().add_child(screen)
	await get_tree().process_frame
	var texts := _tooltips(screen)
	texts.append(AutoDeckWindow.POWER_TIP)
	assert_gt(texts.size(), 15, "the Options screen explains itself on hover")
	for text in texts:
		var popup := _popup(holder, text)
		var required := popup.get_contents_minimum_size()
		assert_lte(required.x, 640.0 - MARGIN, text.left(48))
		assert_lte(required.y, 480.0 - MARGIN, text.left(48))
		var label := _label(popup)
		assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, text.left(48))
		assert_eq(label.text, text, "the text is kept whole")
		assert_eq(label.max_lines_visible, -1, "no hover text of ours is long enough to shorten")
		popup.free()


func test_a_sentence_that_used_to_run_off_the_screen_wraps() -> void:
	var holder := _room(Vector2i(1280, 800))
	var sentence := "Cast the game's music at the volume the 1997 mixer would have, or mute " \
		+ "it; the duel's own sound effects have a slider of their own further down, and " \
		+ "the title screen's fanfare follows this one."
	var popup := _popup(holder, sentence)
	var label := _label(popup)
	var required := popup.get_contents_minimum_size()
	assert_lte(required.x, 420.0 + popup.get_theme_stylebox("panel").get_minimum_size().x,
		"a column, not a line")
	assert_gt(label.custom_minimum_size.y, 3.0 * label.get_line_height(), "several lines of it")
	assert_lte(required.y, 800.0 - MARGIN)


func test_pathological_text_is_widened_then_shortened_to_the_window() -> void:
	var holder := _room(Vector2i(320, 240))
	for text in ["Proxy " + "unbroken".repeat(400),
			"Long text\n" + "Another line of rules.\n".repeat(200)]:
		var popup := _popup(holder, text)
		var required := popup.get_contents_minimum_size()
		assert_lte(required.x, 320.0 - MARGIN, "including long unbroken names")
		assert_lte(required.y, 240.0 - MARGIN, "including many explicit newlines")
		var label := _label(popup)
		assert_eq(label.text, text, "the underlying text is kept intact")
		assert_gt(label.max_lines_visible, 0, "as many lines as fit")
		assert_eq(label.text_overrun_behavior, TextServer.OVERRUN_TRIM_ELLIPSIS)
		popup.free()


func test_a_tooltip_a_control_shaped_for_itself_is_left_alone() -> void:
	var holder := _room(Vector2i(640, 480))
	var popup := PopupPanel.new()
	popup.theme_type_variation = &"TooltipPanel"
	var label := Label.new()
	label.theme_type_variation = &"TooltipLabel"
	label.text = "Shaped by its owner " + "already ".repeat(40)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD
	label.custom_minimum_size = Vector2(200, 30)
	popup.add_child(label)
	holder.add_child(popup)
	assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD, "its own wrapping kept")
	assert_eq(label.custom_minimum_size, Vector2(200, 30), "its own column kept")
	# And a plain label wearing the tooltip theme somewhere else is no
	# tooltip at all.
	var elsewhere := Label.new()
	elsewhere.theme_type_variation = &"TooltipLabel"
	elsewhere.text = "A caption " + "long ".repeat(200)
	holder.add_child(elsewhere)
	assert_eq(elsewhere.autowrap_mode, TextServer.AUTOWRAP_OFF)
	assert_eq(elsewhere.custom_minimum_size, Vector2.ZERO)


func test_campaign_card_rule_help_fits_whole_on_small_and_large_windows() -> void:
	for room in [Vector2i(640, 480), Vector2i(1280, 800)]:
		var holder := _room(room)
		var screen: EmbarkScreen = load("res://game/adventure/embark_screen.tscn").instantiate()
		holder.add_child(screen)
		var choice := screen.find_child("CardRule", true, false) as OptionButton
		var summary := screen.find_child("CardRuleLine", true, false) as Label
		# Model the internal item control inside Godot's short dropdown
		# viewport. The tooltip must fit the game, not those three rows.
		var menu := choice.get_popup()
		menu.size = Vector2i(480, 80)
		var item := Control.new()
		menu.add_child(item)
		for rule in AdventurePlayer.CARD_RULES:
			screen.choose_card_rule(rule)
			item.tooltip_text = choice.get_item_tooltip(AdventurePlayer.CARD_RULES.find(rule))
			for control in [choice, summary, item]:
				var popup := _popup(control, control.tooltip_text)
				var required := popup.get_contents_minimum_size()
				assert_lte(required.x, float(room.x) - MARGIN, rule)
				assert_lte(required.y, float(room.y) - MARGIN, rule)
				assert_eq(_label(popup).max_lines_visible, -1, rule + ": every rule is readable, no ellipsis")
				popup.free()
