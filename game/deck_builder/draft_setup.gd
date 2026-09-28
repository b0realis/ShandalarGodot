class_name DraftSetup
extends Control
## [QoL] In-game sealed-style draft setup. No launcher or terminal required.

var window: OriginalDialog
var fields: Dictionary = {}
var folder: LineEdit
var pool_summary: Label
var status: Label
var launching := false
var _previous: Control
var _previous_process: Node.ProcessMode
var _returning := false


static func open_on(previous: Control) -> DraftSetup:
	var setup := DraftSetup.new()
	setup._previous = previous
	setup._previous_process = previous.process_mode
	previous.hide()
	previous.process_mode = Node.PROCESS_MODE_DISABLED
	previous.get_parent().add_child(setup)
	ShellMusic.play()
	return setup


func close_setup() -> void:
	_returning = true
	queue_free()


func _exit_tree() -> void:
	if is_instance_valid(_previous) and _previous.is_inside_tree() and not _previous.is_queued_for_deletion():
		_previous.show()
		_previous.process_mode = _previous_process
		# Only an explicit Back restarts audio, never scene/process teardown.
		if _returning:
			if _previous is DeckBuilderScreen:
				ShellMusic.stop()
				_previous._apply_music_switch()
			else:
				ShellMusic.play()


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var ground := ColorRect.new()
	ground.color = Color("171c21")
	ground.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(ground)
	window = OriginalDialog.create("Booster Draft", Vector2(700, 650))
	add_child(window)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	window.body().add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation", 14)
	scroll.add_child(body)
	var intro := OriginalDialog.label("Open random packs. Build the best deck you can before the clock runs out.", 18, true)
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var pool_button := OriginalDialog.button("Card pool…", Vector2(130, 32))
	pool_button.name = "DraftCardPool"
	pool_button.pressed.connect(_open_pool)
	body.add_child(pool_button)
	pool_summary = OriginalDialog.label("", 14)
	pool_summary.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(pool_summary)
	var saved: Variant = Settings.get_value(DraftPoolConfig.OPTIONS, DraftPoolConfig.defaults())
	if not saved is Dictionary: saved = DraftPoolConfig.defaults()
	for spec in [["boosters", "Boosters", "15 cards · 1 rare, 3 uncommon, 10 common, 1 basic land", 12],
		["starters", "Starter / tournament packs", "60 cards · 3 rare, 9 uncommon, 26 common, 22 basic lands", 12],
		["free_lands", "Extra lands of each basic type", "This many Plains, Islands, Swamps, Mountains and Forests", 30],
		["extras", "Extra random cards", "Any rarity from your eligible pool, without duplicates", 60],
		["minutes", "Building time (minutes)", "The clock starts after the pack-opening animation", 1440]]:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var labels := VBoxContainer.new()
		labels.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		labels.add_child(OriginalDialog.label(spec[1], 16, true))
		var hint := OriginalDialog.label(spec[2], 13)
		hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		labels.add_child(hint)
		row.add_child(labels)
		var spin := OriginalDialog.field(88)
		spin.min_value = 1 if spec[0] == "minutes" else 0
		spin.max_value = spec[3]
		spin.step = 1
		var old: Variant = saved.get(spec[0], DraftPoolConfig.defaults()[spec[0]])
		spin.value = float(old) if (old is int or old is float) and is_finite(float(old)) else float(DraftPoolConfig.defaults()[spec[0]])
		spin.name = "Draft_" + String(spec[0])
		fields[spec[0]] = spin
		spin.value_changed.connect(func(_value: float) -> void: _refresh())
		row.add_child(spin)
		body.add_child(row)
	body.add_child(OriginalDialog.label("Save deck and dealt pool to", 16, true))
	var file_row := HBoxContainer.new()
	folder = OriginalDialog.text_field()
	folder.name = "DraftSaveFolder"
	folder.text = GamePaths.drafts_folder()
	folder.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	folder.editable = not OS.has_feature("web")
	folder.text_changed.connect(func(_typed: String) -> void: _refresh())
	file_row.add_child(folder)
	var browse := OriginalDialog.button("Browse…")
	browse.disabled = OS.has_feature("web")
	browse.pressed.connect(_browse)
	file_row.add_child(browse)
	var reset := OriginalDialog.button("Default")
	reset.pressed.connect(func() -> void: folder.text = GamePaths.DEFAULT_DRAFTS)
	file_row.add_child(reset)
	body.add_child(file_row)
	status = OriginalDialog.label("", 14)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(status)
	var hint := OriginalDialog.label("Done or time up saves exactly what you built, even an unfinished deck. Your unused cards remain in the pool file. This is sealed-style building, not a pass-the-pack draft.", 14)
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(hint)
	if OS.has_feature("web"):
		folder.text = GamePaths.DEFAULT_DRAFTS
		var web_hint := OriginalDialog.label("Web: saved in this browser. Download your deck and pool on the results screen to keep external copies.", 14)
		web_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		body.add_child(web_hint)
	window.add_button("Launch draft").pressed.connect(_launch)
	var verify := window.add_button("Verify saved deck…")
	verify.name = "VerifyDraftDeck"
	verify.pressed.connect(_open_verifier)
	window.add_button("Back").pressed.connect(close_setup)
	_refresh()


func options() -> Dictionary:
	var out: Dictionary = {}
	for key in fields:
		fields[key].apply()
		out[key] = int(fields[key].value)
	return out


func _refresh() -> void:
	if pool_summary == null or status == null or folder == null: return
	var names := DraftPoolConfig.selected()
	var sets: Dictionary = {}
	for card_name in names: sets[CardRegistry.get_card(card_name).set_code] = true
	pool_summary.text = "%d eligible cards from %d sets · remembered for next time" % [names.size(), sets.size()]
	var config := options()
	var refusal := DraftPoolConfig.validate(config, names)
	var total := int(config.boosters) * 15 + int(config.starters) * 60 + int(config.free_lands) * 5 + int(config.extras)
	status.text = refusal if refusal != "" else "%d cards to build with · aim for at least %d cards in your deck" % [total, DeckModel.MIN_CARDS]
	if refusal == "" and not _folder_the_deck_pickers_read():
		status.text += "\nLoad deck lists only %s. A draft saved elsewhere is opened with Import deck." % DeckStore.USER_DIR


## `Load deck` walks [constant DeckStore.SHIPPED_DIR] and the top level of
## [constant DeckStore.USER_DIR] and nothing else, so a draft sent to any
## other folder is a real file that neither the builder's list nor Magic
## Battle ever shows. Say it here rather than let the result screen's
## "Saved to:" imply otherwise (2026-09-17).
func _folder_the_deck_pickers_read() -> bool:
	return _resolved(GamePaths.expand(folder.text.strip_edges())) == _resolved(DeckStore.USER_DIR)


static func _resolved(path: String) -> String:
	return ProjectSettings.globalize_path(path.replace("\\", "/")).simplify_path().trim_suffix("/")


## One chooser at a time, for the reason [method _open_verifier] states:
## `Card pool…` keeps the keyboard under the overlay, so Enter again put a
## second chooser on the first — and the two then saved over each other.
func _open_pool() -> void:
	for child in get_children():
		if child is DraftPoolDialog and not child.is_queued_for_deletion(): return
	var chooser := DraftPoolDialog.new()
	add_child(chooser)
	chooser.closed.connect(_refresh)


## One verifier at a time: the button keeps keyboard focus under the
## overlay, and Enter again would stack a second window on the first.
func _open_verifier() -> void:
	for child in get_children():
		if child is DraftVerifier and not child.is_queued_for_deletion(): return
	add_child(DraftVerifier.new())


func _browse() -> void:
	var picker := FileDialog.new()
	picker.file_mode = FileDialog.FILE_MODE_OPEN_DIR
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.use_native_dialog = true
	picker.title = "Draft save folder"
	var path := ProjectSettings.globalize_path(GamePaths.expand(folder.text))
	picker.current_dir = path if DirAccess.dir_exists_absolute(path) else OS.get_user_data_dir()
	picker.dir_selected.connect(func(chosen: String) -> void:
		folder.text = chosen
		picker.queue_free())
	picker.canceled.connect(picker.queue_free)
	add_child(picker)
	picker.popup_centered(Vector2i(760, 520))


func _launch() -> void:
	if launching: return
	var config := options()
	var names := DraftPoolConfig.selected()
	var refusal := DraftPoolConfig.validate(config, names)
	if refusal == "": refusal = GamePaths.draft_folder_refusal(folder.text)
	if refusal != "":
		status.text = refusal
		return
	var pool := DraftPoolConfig.deal(config, names)
	if pool == null:
		status.text = "Randomness is unavailable. Please try again."
		return
	var store := DraftStore.new()
	refusal = store.prepare(folder.text, pool, config)
	if refusal != "":
		status.text = refusal
		return
	GamePaths.set_drafts_folder(folder.text)
	Settings.set_value(DraftPoolConfig.OPTIONS, config)
	launching = true
	window.hide()
	var session := DraftSession.new()
	session.pool = pool
	session.store = store
	session.seconds = int(config.minutes) * 60
	add_child(session)
	session.tree_exiting.connect(func() -> void:
		launching = false
		window.show()
		if session.returning_to_setup: ShellMusic.play())
