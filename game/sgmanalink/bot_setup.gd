class_name SgBotSetup
extends VBoxContainer
## [QoL] Shared computer settings; Unfair stays outside the fair ladder.

signal changed(draft: Dictionary)
signal submitted(count: int, options: Dictionary, deck: Dictionary)
var draft: Dictionary = {}
var _level: OptionButton
var _unfair: CheckBox
var _count: SpinBox
var _pace: OptionButton
var _deck: Dictionary = {}
var _fair_level := 3


func build(maximum: int, decks: Array, previous: Dictionary = {}) -> void:
	draft = previous.duplicate(true)
	var options: Dictionary = draft.get("bot", SgBotPlayer.defaults())
	_fair_level = int(draft.get("fair_level", options.level))
	add_theme_constant_override("separation", 10)
	add_child(SgLobbyStyle.label("Computer players", 22))
	add_child(SgLobbyStyle.label("The same computer opponents as local duels. Standard levels use fair information; the host runs their decisions.", 15))
	var row := SgLobbyStyle.row(self)
	_count = SpinBox.new()
	_count.name = "BotCount"
	_count.min_value = 1
	_count.max_value = maximum
	_count.value = clampi(int(draft.get("count", 1)), 1, maximum)
	_count.prefix = "Seats: "
	_count.tooltip_text = "Number of computer seats to add in this batch. Humans and bots share the entrant limit."
	_count.custom_minimum_size.x = 130
	SgLobbyStyle.field(_count.get_line_edit())
	row.add_child(_count)
	_count.visible = maximum > 1
	_level = OptionButton.new()
	_level.name = "BotLevel"
	_level.tooltip_text = "All four standard difficulties use fair information."
	for level: String in SgBotPlayer.LEVELS: _level.add_item(level)
	_level.select(int(options.level))
	_level.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SgLobbyStyle.option(_level)
	_level.add_theme_color_override("font_disabled_color", UiChrome.INK)
	row.add_child(_level)
	_pace = OptionButton.new()
	_pace.name = "BotPace"
	_pace.tooltip_text = "Delay between computer decisions. Difficulty sets strength; pace only sets speed."
	for pace in [["Quick", 100], ["Normal", 350], ["Leisurely", 700]]: _pace.add_item(pace[0], pace[1])
	_pace.select(1)
	for i in _pace.item_count:
		if _pace.get_item_id(i) == int(options.pace_ms): _pace.select(i)
	SgLobbyStyle.option(_pace)
	row.add_child(_pace)
	add_child(SgLobbyStyle.label("CHALLENGE MODIFIER", 13))
	_unfair = CheckBox.new()
	_unfair.name = "BotUnfair"
	_unfair.text = UnfairPlayer.LABEL
	_unfair.tooltip_text = UnfairPlayer.DESCRIPTION
	_unfair.button_pressed = options.unfair
	_unfair.add_theme_icon_override("checked", UiChrome.check_icon(true))
	_unfair.add_theme_icon_override("unchecked", UiChrome.check_icon(false))
	for state in ["normal", "hover", "pressed", "hover_pressed"]:
		_unfair.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	_unfair.add_theme_stylebox_override("focus", OriginalDialog.focus_ring())
	SgLobbyStyle.check(_unfair)
	_unfair.add_theme_font_size_override("font_size", 17)
	var font := GameSkin.font("font_body")
	if font != null: _unfair.add_theme_font_override("font", font)
	_level.disabled = options.unfair
	add_child(_unfair)
	add_child(SgLobbyStyle.label("Unfair uses Wizard and knows the opponent's current hand. It never reveals that hand to other players. Everyone can see this challenge before starting.", 14))
	_level.item_selected.connect(func(index: int) -> void:
		_fair_level = index
		_remember())
	_unfair.toggled.connect(func(on: bool) -> void:
		_level.disabled = on
		_level.select(3 if on else _fair_level)
		_remember())
	_count.value_changed.connect(func(_value: float) -> void: _remember())
	_pace.item_selected.connect(func(_index: int) -> void: _remember())
	var search := LineEdit.new()
	search.name = "BotDeckSearch"
	search.placeholder_text = "Search computer decks"
	search.text = draft.get("query", "")
	SgLobbyStyle.field(search)
	add_child(search)
	var list := ItemList.new()
	list.name = "BotDeckList"
	list.custom_minimum_size.y = 130
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SgLobbyStyle.deck_list(list)
	add_child(list)
	var detail := RichTextLabel.new()
	detail.name = "BotDeckContents"
	detail.custom_minimum_size.y = 115
	SgLobbyStyle.rich_text(detail)
	add_child(detail)
	var choose := SgLobbyStyle.button("Add computer seat(s)", func() -> void:
		_remember()
		submitted.emit(int(_count.value), draft.bot.duplicate(true), _deck.duplicate(true)))
	choose.name = "AddBots"
	choose.set_meta("available", false)
	choose.disabled = true
	add_child(choose)
	var select := func(index: int) -> void:
		var source: Dictionary = decks[int(list.get_item_metadata(index))]
		_deck = SgDeckCatalog.payload(source)
		detail.text = SgLobby._deck_text(_deck)
		choose.set_meta("available", true)
		choose.disabled = false
		_remember()
	list.item_selected.connect(select)
	var fill := func(query: String) -> void:
		draft.query = query
		list.clear()
		for i in decks.size():
			if not query.is_empty() and not String(decks[i].name).to_lower().contains(query.to_lower()): continue
			list.add_item(decks[i].name)
			list.set_item_metadata(list.item_count - 1, i)
		changed.emit(draft.duplicate(true))
	search.text_changed.connect(fill)
	fill.call(search.text)
	var remembered: Dictionary = previous.get("deck", {})
	for i in list.item_count:
		var source: Dictionary = decks[int(list.get_item_metadata(i))]
		if (remembered.is_empty() and i == 0) or (not remembered.is_empty() and SgTournament.same_list(source, remembered)):
			list.select(i)
			select.call(i)
			break


func _remember() -> void:
	draft.bot = {"level": _level.selected, "unfair": _unfair.button_pressed, "pace_ms": _pace.get_selected_id()}
	draft.count = int(_count.value)
	draft.fair_level = _fair_level
	draft.deck = _deck.duplicate(true)
	changed.emit(draft.duplicate(true))
