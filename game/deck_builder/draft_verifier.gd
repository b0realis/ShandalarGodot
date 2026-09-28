class_name DraftVerifier
extends Control
## [QoL] In-game, read-only comparison with an organiser's retained pool receipt.

var window: OriginalDialog
var pool_path := ""
var deck_path := ""
var paths: Dictionary = {}
var report: Label
var fingerprint: LineEdit


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	window = OriginalDialog.create("Verify draft deck", Vector2(700, 520))
	add_child(window)
	var intro := OriginalDialog.label("Compare with the original pool, or reconstruct from the recipe saved in the deck. Main deck and sideboard count together.", 17, true)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window.body().add_child(intro)
	for kind in ["pool", "deck"]:
		var row := HBoxContainer.new()
		var button := OriginalDialog.button("Choose %s…" % kind, Vector2(150, 32))
		button.pressed.connect(_browse.bind(kind))
		row.add_child(button)
		var path := OriginalDialog.label("No file selected", 14)
		path.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		path.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(path)
		paths[kind] = path
		window.body().add_child(row)
	fingerprint = OriginalDialog.text_field()
	fingerprint.placeholder_text = "Judge's pre-draft SHA-256 fingerprint (optional)"
	fingerprint.tooltip_text = "Paste the fingerprint retained before deck building, not one newly supplied by the player."
	fingerprint.max_length = 64
	window.body().add_child(fingerprint)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.body().add_child(scroll)
	report = OriginalDialog.label("Check deck uses both files. Reconstruct deck needs only the .deck and its embedded recipe.", 16)
	report.name = "DraftAuditReport"
	report.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	report.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(report)
	var trust := OriginalDialog.label(DraftAudit.TRUST_NOTE, 14)
	trust.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	window.body().add_child(trust)
	var check := window.add_button("Check deck")
	check.pressed.connect(verify)
	window.add_button("Reconstruct deck").pressed.connect(reconstruct)
	window.add_button("Back").pressed.connect(queue_free)
	# Take the keyboard from the setup beneath: its Verify button would
	# otherwise keep focus and answer the next Enter.
	check.grab_focus()


func _browse(kind: String) -> void:
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.access = FileDialog.ACCESS_USERDATA if OS.has_feature("web") else FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = not OS.has_feature("web")
	picker.title = "Choose saved draft " + kind
	picker.filters = PackedStringArray(["*.json ; Dealt pool"] if kind == "pool" else ["*.deck,*.dec ; Text deck"])
	var folder := GamePaths.drafts_folder()
	if not OS.has_feature("web"): folder = ProjectSettings.globalize_path(GamePaths.expand(folder))
	picker.current_dir = folder if DirAccess.dir_exists_absolute(folder) else "user://"
	picker.file_selected.connect(func(path: String) -> void:
		select_file(kind, path)
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	add_child(picker)
	picker.popup_centered(Vector2i(760, 520))


func select_file(kind: String, path: String) -> void:
	if kind == "pool": pool_path = path
	else: deck_path = path
	paths[kind].text = path.get_file()
	paths[kind].tooltip_text = path
	report.text = "Ready to check." if pool_path != "" and deck_path != "" else "Choose the other file to continue."


func verify() -> void:
	var result := DraftAudit.check_files(pool_path, deck_path, fingerprint.text.strip_edges())
	_show_report(result)


func reconstruct() -> void:
	_show_report(DraftAudit.reconstruct_file(deck_path, fingerprint.text.strip_edges()))


func _show_report(result: Dictionary) -> void:
	report.text = result.message
	report.modulate = Color("a9df9b") if result.ok else Color("ffba91")
