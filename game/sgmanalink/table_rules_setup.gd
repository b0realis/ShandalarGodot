class_name SgTableRulesSetup
extends VBoxContainer
## THE TABLE RULES EDITOR (2026-10-02). The host's controls for the table
## they are about to open — a duel or a tournament, the same column in
## either page's "Table rules…" window: the starting life, the preset
## list the Options screen uses, and one switch per implemented fork,
## each explaining both editions in its tooltip. What the host leaves
## here is remembered on this device ([constant KEY]) and comes back the
## next time they host; "Standard table" puts everything back to what
## every host opened before table rules existed. The value is always an
## [SgTableRules] dictionary ([method value]); [signal changed] carries
## it at every gesture.

signal changed(rules: Dictionary)

const KEY := "sgmanalink_table_rules"

var _life: SpinBox
var _preset: OptionButton
var _boxes: Dictionary = {}
var _live := RulesOptions.new()
var _readout: Label


## The host's remembered table, or the standard one.
static func remembered() -> Dictionary:
	return SgTableRules.normalize(Settings.get_value(KEY, {}))


## Keep [param rules] for the next host page; the standard table clears
## the key so a fresh install's file stays as it was.
static func remember(rules: Dictionary) -> void:
	var clean := SgTableRules.normalize(rules)
	if clean == SgTableRules.standard(): Settings.clear_value(KEY)
	else: Settings.set_value(KEY, clean)


func build(rules: Dictionary = remembered()) -> void:
	var start := SgTableRules.normalize(rules)
	_live = SgTableRules.options(start)
	add_theme_constant_override("separation", 10)
	add_child(SgLobbyStyle.label("Every seat at this table plays under these rules; the guest sees them in the room and again at the duel's opening.", 15))
	var life_row := SgLobbyStyle.row(self)
	_life = SpinBox.new()
	_life.name = "TableLife"
	_life.min_value = SgTableRules.MIN_LIFE
	_life.max_value = SgTableRules.MAX_LIFE
	_life.value = SgTableRules.life(start)
	_life.prefix = "Starting life: "
	_life.tooltip_text = "Both players start at this life total (1–%d)." % SgTableRules.MAX_LIFE
	_life.custom_minimum_size.x = 190
	SgLobbyStyle.field(_life.get_line_edit())
	_life.value_changed.connect(func(_value: float) -> void: _announce())
	life_row.add_child(_life)
	var standard := SgLobbyStyle.button("Standard table", func() -> void:
		set_rules(SgTableRules.standard())
		_announce(), Vector2(160, 38))
	standard.name = "TableStandard"
	standard.tooltip_text = "20 life, modern rules with mana burn on."
	life_row.add_child(standard)
	add_child(SgLobbyStyle.label("RULES — 1997 (FIFTH EDITION) OR MODERN", 13))
	_preset = OptionButton.new()
	_preset.name = "TablePreset"
	for entry in RulesOptions.PRESETS: _preset.add_item(entry["label"])
	_preset.add_item(RulesOptions.CUSTOM_LABEL)
	_preset.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	SgLobbyStyle.option(_preset)
	_preset.item_selected.connect(func(index: int) -> void:
		# "Custom" is a readout, not a command: the box goes back to
		# naming what the switches say.
		if index >= RulesOptions.PRESETS.size():
			_sync_readout()
			return
		_live.set_preset(RulesOptions.PRESETS[index]["id"])
		for key: String in _boxes: _boxes[key].set_pressed_no_signal(_live.get_fork(key))
		_announce())
	add_child(_preset)
	for fork in RulesOptions.FORKS:
		var key: String = fork["key"]
		if not SgTableRules.FORKS.has(key): continue
		var row := CheckButton.new()
		row.name = "TableRule_" + key
		row.text = fork["label"]
		row.tooltip_text = "1997: %s\nModern: %s" % [fork["fifth"], fork["modern"]]
		row.button_pressed = _live.get_fork(key)
		SgLobbyStyle.check(row)
		row.add_theme_font_size_override("font_size", 16)
		var font := GameSkin.font("font_body")
		if font != null: row.add_theme_font_override("font", font)
		row.toggled.connect(func(on: bool) -> void:
			_live.set_fork(key, on)
			_announce())
		add_child(row)
		_boxes[key] = row
	_readout = SgLobbyStyle.label("", 15)
	_readout.name = "TableReadout"
	add_child(_readout)
	_sync_readout()


## The table as a wire dictionary.
func value() -> Dictionary:
	return SgTableRules.from_options(int(_life.value), _live)


## Put the controls to [param rules] without announcing.
func set_rules(rules: Dictionary) -> void:
	var clean := SgTableRules.normalize(rules)
	_live = SgTableRules.options(clean)
	_life.set_value_no_signal(SgTableRules.life(clean))
	for key: String in _boxes: _boxes[key].set_pressed_no_signal(_live.get_fork(key))
	_sync_readout()


func _sync_readout() -> void:
	_preset.selected = _preset_index(_live.preset())
	_readout.text = SgTableRules.brief(value())


func _announce() -> void:
	_sync_readout()
	var rules := value()
	remember(rules)
	changed.emit(rules)


## The preset box's row for a RulesOptions.preset() id: the preset's
## place in PRESETS, or the "Custom" row after them.
static func _preset_index(id: String) -> int:
	for i in RulesOptions.PRESETS.size():
		if RulesOptions.PRESETS[i]["id"] == id: return i
	return RulesOptions.PRESETS.size()
