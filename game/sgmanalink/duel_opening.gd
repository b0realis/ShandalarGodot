class_name SgDuelOpening
extends OpeningWindow
## Public match information on the shared opening-hand ground. No stakes,
## hidden deck analysis, ranking claims or timed dismissal.

signal go_pressed
signal reconfigure_pressed

## The slot the panel takes over from the two antes — the ground's own
## caption, gap and card height. The introduction has to fit in it, or
## whatever sits last in the column leaves the paper.
const SLOT := CAPTION_HEIGHT + CAPTION_GAP + CardPreview.SIZE.y

var _panel: PanelContainer
var _column: VBoxContainer
## The two deck titles, the one part of the column that gives way — see
## [method _fit_titles].
var _deck_titles: Array[Label] = []


func build_match(config: DuelConfig, rules: RulesOptions, tournament: Dictionary = {}) -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size.x = CardPreview.SIZE.x * 2.0 + CARD_GAP
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL
	panel.add_theme_stylebox_override("panel", UiChrome.flat_panel(16))
	replace_antes(panel)
	_panel = panel
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 10)
	panel.add_child(column)
	_column = column
	column.sort_children.connect(_fit_titles)
	var title := _wrapped("SGManalink · LAN duel" if tournament.is_empty() else String(tournament.name), 22, 1)
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(title)
	# EACH SEAT IS A ROW — the portrait BESIDE the name and deck, portraits
	# on the outside and the two names facing each other across the `vs.`.
	# Stacked (portrait above name above deck) the page did not fit the slot
	# under the shipped body font even with one-line titles: its line is
	# taller than a skin's, and the column stood 45 px over the room with
	# nothing left to give. Beside, a seat is the portrait's height, and a
	# name and a title of two lines each stand within it under either font.
	var seats := HBoxContainer.new()
	seats.add_theme_constant_override("separation", 12)
	column.add_child(seats)
	for pid in 2:
		if pid == 1:
			var versus := OriginalDialog.ink_label("vs.", 18)
			versus.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
			seats.add_child(versus)
		var seat := HBoxContainer.new()
		seat.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		seat.add_theme_constant_override("separation", 8)
		seats.add_child(seat)
		var face := TextureRect.new()
		face.texture = VersusPanel.portrait_for(config, pid)
		face.custom_minimum_size = Vector2(100, 110)
		face.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
		face.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		face.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		var words := VBoxContainer.new()
		words.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		words.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		words.add_theme_constant_override("separation", 4)
		words.add_child(_wrapped(config.player_names[pid], 18, 2))
		var deck_title := _wrapped(config.deck_names[pid], 16, 3)
		_deck_titles.append(deck_title)
		words.add_child(deck_title)
		for part in ([face, words] if pid == 0 else [words, face]): seat.add_child(part)
	column.add_child(HSeparator.new())
	column.add_child(_wrapped("Unrated friendly duel · No ante" if tournament.is_empty() else
		"Round %d · Game %d · Series %d–%d · First to %d" % [int(tournament.round), int(tournament.game),
		int(tournament.wins[0]), int(tournament.wins[1]), int(tournament.target)], 17, 2))
	column.add_child(_wrapped("Unrestricted decks · %d starting life" % config.lives[0], 16, 1))
	var details := GridContainer.new()
	details.columns = 2
	details.add_theme_constant_override("h_separation", 16)
	details.add_theme_constant_override("v_separation", 4)
	column.add_child(details)
	for fork in RulesOptions.FORKS:
		var on := bool(rules.get(fork.key))
		var label := OriginalDialog.ink_label("%s: %s" % [fork.label, "On" if on else "Off"], 13)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.tooltip_text = fork.fifth if on == bool(fork.fifth_value) else fork.modern
		label.mouse_filter = Control.MOUSE_FILTER_PASS
		details.add_child(label)
	var notice := "Temporary player names · No ranking points are recorded.\nGood luck to both players!"
	if not config.challenge_label().is_empty(): notice = "Unfair challenge · Computer sees the opponent's current hand.\nNo ranking points are recorded."
	var note := _wrapped(notice, 14, 2)
	note.size_flags_vertical = Control.SIZE_EXPAND_FILL
	note.vertical_alignment = VERTICAL_ALIGNMENT_BOTTOM
	column.add_child(note)


func show_introduction() -> void:
	set_lead("Your online match")
	set_status("Review the players and rules, then continue to the coin toss.")
	set_answers([{"answer": 0, "label": "Leave duel", "disabled": false},
		{"answer": 1, "label": "Continue", "disabled": false}])
	answered.connect(func(answer: int) -> void:
		if answer == 0: reconfigure_pressed.emit()
		else: go_pressed.emit())
	_buttons[1].grab_focus()


## A deck title gives way a line at a time until the column fits its slot.
## How many lines a title takes is only known once it has its width, so
## this runs on the column's sort pass, not at build time — and not on the
## first pass either, where the labels are still a pixel wide and every
## title measures at its cap. Only ever shorter, so it converges; the
## tooltip on every title keeps the whole name.
func _fit_titles() -> void:
	for title in _deck_titles:
		if title.size.x <= 1.0: return
	var room: float = SLOT - _panel.get_theme_stylebox("panel").get_minimum_size().y
	while _column.get_combined_minimum_size().y > room:
		var trimmed := false
		for title in _deck_titles:
			if title.max_lines_visible > 1:
				title.max_lines_visible -= 1
				# The line cap alone does not refresh the label's minimum.
				title.update_minimum_size()
				trimmed = true
		if not trimmed: return


func _wrapped(text: String, font_size: int, lines: int) -> Label:
	var label := OriginalDialog.ink_label(text, font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.max_lines_visible = lines
	label.text_overrun_behavior = TextServer.OVERRUN_TRIM_ELLIPSIS
	label.tooltip_text = text
	label.mouse_filter = Control.MOUSE_FILTER_PASS
	return label
