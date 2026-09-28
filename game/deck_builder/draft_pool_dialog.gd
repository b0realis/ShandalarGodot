class_name DraftPoolDialog
extends Control
## [QoL] Check whole implemented sets or individual cards before dealing.

signal closed

var selected_cards: Dictionary = {}
var rows: Dictionary = {}
var groups: Dictionary = {}
var tree: Tree
var summary: Label
var _updating := false
var window: OriginalDialog


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	z_index = 400
	window = OriginalDialog.create("Draft card pool", Vector2(680, 570))
	add_child(window)
	CardRegistry.ensure_loaded()
	var saved := DraftPoolConfig.selected()
	if not Settings.has_value(DraftPoolConfig.SETTING):
		saved.assign(CardRegistry.all_names())
	for card_name in saved:
		selected_cards[card_name] = true
	var intro := OriginalDialog.label("Choose whole sets or expand a set to choose individual cards. Only checked cards can be dealt. Choices for disabled packs are kept until those packs return. Changes here do not limit ordinary duels.", 15)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body().add_child(intro)
	var search := OriginalDialog.text_field()
	search.placeholder_text = "Find a card or set…"
	body().add_child(search)
	tree = Tree.new()
	tree.hide_root = true
	tree.custom_minimum_size = Vector2(0, 160)
	tree.size_flags_vertical = Control.SIZE_EXPAND_FILL
	tree.add_theme_stylebox_override("panel", OriginalDialog.panel_style("panel_dark_stone", 6))
	body().add_child(tree)
	var root := tree.create_item()
	for card_name in CardRegistry.all_names():
		if not SealedPool.SLOT_ORDER.has(SealedPool.slot_of(card_name)):
			selected_cards.erase(card_name)
			continue
		var code := CardRegistry.get_card(card_name).set_code
		if not groups.has(code):
			var group := tree.create_item(root)
			group.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
			group.set_editable(0, true)
			group.set_text(0, String(DeckFilter.SET_LABELS.get(code, code)))
			group.set_metadata(0, {"set": code})
			group.collapsed = true
			groups[code] = group
		var row := tree.create_item(groups[code])
		row.set_cell_mode(0, TreeItem.CELL_MODE_CHECK)
		row.set_editable(0, true)
		row.set_text(0, card_name)
		row.set_metadata(0, {"card": card_name})
		rows[card_name] = row
	summary = OriginalDialog.label("", 14)
	body().add_child(summary)
	tree.item_edited.connect(_edited)
	search.text_changed.connect(_search)
	add_button("All").pressed.connect(func() -> void: choose(rows.keys()))
	add_button("None").pressed.connect(func() -> void: choose([]))
	add_button("Save pool").pressed.connect(_save)
	add_button("Cancel").pressed.connect(dismiss)
	_refresh()
	# Take the keyboard from the setup beneath: its `Card pool…` button
	# would otherwise keep focus and answer the next Enter. The finder is
	# where a hand goes first here, and Enter in it does nothing.
	search.grab_focus()


func body() -> VBoxContainer:
	return window.body()


func add_button(text: String) -> Button:
	return window.add_button(text)


func dismiss() -> void:
	closed.emit()
	queue_free()


func choose(names: Array) -> void:
	selected_cards.clear()
	for card_name in names:
		if rows.has(card_name):
			selected_cards[card_name] = true
	_refresh()


func _edited() -> void:
	if _updating:
		return
	var item := tree.get_edited()
	var data: Dictionary = item.get_metadata(0)
	var targets: Array = [item] if data.has("card") else item.get_children()
	for row: TreeItem in targets:
		var card_name: String = row.get_metadata(0)["card"]
		if item.is_checked(0):
			selected_cards[card_name] = true
		else:
			selected_cards.erase(card_name)
	_refresh()


func _refresh() -> void:
	_updating = true
	var slots := {"rare": 0, "uncommon": 0, "common": 0, "land": 0}
	for card_name in rows:
		rows[card_name].set_checked(0, selected_cards.has(card_name))
		if selected_cards.has(card_name):
			slots[SealedPool.slot_of(card_name)] += 1
	for group: TreeItem in groups.values():
		var checked := 0
		for row in group.get_children():
			checked += int(row.is_checked(0))
		group.set_checked(0, checked == group.get_child_count())
		group.set_indeterminate(0, checked > 0 and checked < group.get_child_count())
	summary.text = "%d cards · %d rare · %d uncommon · %d common · %d basic lands" % [selected_cards.size(), slots.rare, slots.uncommon, slots.common, slots.land]
	_updating = false


func _search(typed: String) -> void:
	var needle := typed.strip_edges().to_lower()
	for group: TreeItem in groups.values():
		var shown := false
		for row in group.get_children():
			row.visible = needle == "" or row.get_text(0).to_lower().contains(needle) or group.get_text(0).to_lower().contains(needle)
			shown = shown or row.visible
		group.visible = shown
		group.collapsed = needle == ""


func _save() -> void:
	if selected_cards.is_empty():
		summary.text = "Choose at least one card before saving."
		return
	var names := selected_cards.keys()
	# Editing the visible pool must not erase choices temporarily hidden by
	# a missing/disabled pack. Only retain known pack identities, not junk.
	var saved: Variant = Settings.get_value(DraftPoolConfig.SETTING, [])
	if saved is Array or saved is PackedStringArray:
		for card_name in saved:
			if card_name is String and not rows.has(card_name) and not names.has(card_name) \
					and not CardPacks.packs_required_by([card_name]).is_empty():
				names.append(card_name)
	names.sort()
	Settings.set_value(DraftPoolConfig.SETTING, names)
	if Settings.is_dirty():
		summary.text = "The pool could not be saved. Check the player settings folder and try again."
		return
	dismiss()
