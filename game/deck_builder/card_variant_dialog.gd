class_name CardVariantDialog
extends RefCounted
## A printing preference is shared by every copy of a name in this deck.
static func create(card_name: String, current: String, chosen: Callable) -> OriginalDialog:
	var dialog := OriginalDialog.create("Card variant — " + card_name, Vector2(700, 530))
	var note := OriginalDialog.label("Choose artwork for this deck. Rules and copy limits stay the same.", 13)
	note.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.body().add_child(note)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 16)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	dialog.body().add_child(row)
	var holder := Control.new()
	holder.custom_minimum_size = CardPreview.SIZE * 0.8
	row.add_child(holder)
	var preview := CardPreview.new()
	preview.docked = true
	preview.scale = Vector2(0.8, 0.8)
	holder.add_child(preview)
	var scroll := ScrollContainer.new()
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.follow_focus = true
	row.add_child(scroll)
	var column := VBoxContainer.new()
	column.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(column)
	var group := ButtonGroup.new()
	var selected := {"id": current}
	var rows := CardPrintings.choices(card_name)
	var resolved := CardPrintings.resolve(card_name, current)
	if resolved.is_empty() and not rows.is_empty(): selected.id = rows[0].id
	elif not resolved.is_empty(): selected.id = resolved.id
	for printing in rows:
		var id: String = printing.id
		var button := OriginalDialog.choice_line(CardPrintings.label(printing))
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.custom_minimum_size = Vector2(0, 58)
		button.toggle_mode = true
		button.button_group = group
		button.button_pressed = id == selected.id
		button.set_meta("printing_id", id)
		button.pressed.connect(func() -> void:
			selected.id = id
			preview.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0), id))
		column.add_child(button)
	preview.show_card(CardInstance.new(CardRegistry.get_card(card_name), -1, 0), selected.id)
	dialog.add_button("Use variant").pressed.connect(func() -> void:
		chosen.call(selected.id)
		dialog.dismiss())
	dialog.add_button("Automatic").pressed.connect(func() -> void:
		chosen.call("")
		dialog.dismiss())
	dialog.add_button("Cancel").pressed.connect(dialog.dismiss)
	return dialog
