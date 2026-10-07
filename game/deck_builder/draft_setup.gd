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
## True while this setup turned `auto_accept_quit` off for the Deck Builder
## it covers ([method _enter_tree]).
var _holds_window_close := false
## The pool half of [member status], kept for [method _refresh_folder_note].
var _pool_status := ""
var _pool_ok := false


## The draft session a setup starts. Its window close is the session's as
## ever — it finishes and saves the draft, and keeps the window once for
## `Retry save` when that fails — and then the quit is handed to the setup,
## which asks about the unsaved decks of a Deck Builder under it first
## ([method _session_quit]).
class Session extends DraftSession:
	var setup: DraftSetup

	func _quit_game() -> void:
		if is_instance_valid(setup) and setup.is_inside_tree():
			setup._session_quit()
		else:
			super._quit_game()


## [param into] is the setup to open — a test's counting subclass; a new
## [DraftSetup] when null.
static func open_on(previous: Control, into: DraftSetup = null) -> DraftSetup:
	var setup := into if into != null else DraftSetup.new()
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


# --- campaign 2026-10 fix-persist (wave 2): the window's close button ---
## THE X OVER A DECK BUILDER ASKS FIRST (whole-game campaign 2026-10).
## `Booster Draft` hides the builder under this screen, and a hidden
## builder lets the window's close go ([method
## DeckBuilderScreen._claim_window_close]) — so the X here, or during the
## draft session started here, quit at once over the builder's unsaved
## slots. While this setup covers a builder it holds the close for it; the
## session it starts holds it in turn while it runs and puts this hold
## back when it goes.
func _enter_tree() -> void:
	if _previous is DeckBuilderScreen and get_tree().auto_accept_quit:
		get_tree().auto_accept_quit = false
		_holds_window_close = true


func _release_window_close() -> void:
	if _holds_window_close:
		_holds_window_close = false
		get_tree().auto_accept_quit = true


## A close while the session runs is the session's: it is notified after
## this screen, saves the draft, and hands the quit to [method _session_quit].
func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST and _holds_window_close and is_inside_tree() \
			and not launching:
		_hand_close_to_builder()


## The draft is saved (or the player closed again over a failed save): the
## builder's unsaved decks are the last thing to ask about.
func _session_quit() -> void:
	_hand_close_to_builder()


## Nothing unsaved in the builder underneath: the window goes. Otherwise
## this screen closes — the builder back on show at once, so the question
## is never asked on a hidden screen — and the builder walks its `@SAVE`
## questions as `Exit game` does; `Cancel` leaves the player in it.
func _hand_close_to_builder() -> void:
	if not is_instance_valid(_previous) or not (_previous is DeckBuilderScreen):
		_end_process()
		return
	var builder := _previous as DeckBuilderScreen
	if builder._unsaved_slots().is_empty():
		_end_process()
		return
	# Hand the hold over before the builder shows, so it takes it.
	_release_window_close()
	builder.show()
	builder.process_mode = _previous_process
	close_setup()
	builder._on_window_close_request()


## Ends the process; a seam so a test can count the close instead.
func _end_process() -> void:
	get_tree().quit()
# --- end campaign fix-persist (wave 2) ---


func _exit_tree() -> void:
	# Before the builder shows again, so it takes the close back.
	_release_window_close()
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
	# A keystroke here changes only the folder note (campaign 2026-10).
	folder.text_changed.connect(func(_typed: String) -> void: _refresh_folder_note())
	file_row.add_child(folder)
	var browse := OriginalDialog.button("Browse…")
	browse.disabled = OS.has_feature("web")
	browse.pressed.connect(_browse)
	file_row.add_child(browse)
	var reset := OriginalDialog.button("Default")
	# Setting the text from code emits no `text_changed`: refresh the note.
	reset.pressed.connect(func() -> void:
		folder.text = GamePaths.DEFAULT_DRAFTS
		_refresh_folder_note())
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


## The counts as they will launch: a number typed into a box without Enter
## is committed first ([param commit]). A refresh passes false (campaign
## 2026-10): it runs inside a box's `value_changed`, while that box's line
## edit still shows the OLD number, and committing it undid the step at
## once — an arrow click on Boosters left it at 3.
func options(commit := true) -> Dictionary:
	var out: Dictionary = {}
	for key in fields:
		if commit:
			fields[key].apply()
		out[key] = int(fields[key].value)
	return out


func _refresh() -> void:
	if pool_summary == null or status == null or folder == null: return
	var names := DraftPoolConfig.selected()
	var sets: Dictionary = {}
	for card_name in names: sets[CardRegistry.get_card(card_name).set_code] = true
	pool_summary.text = "%d eligible cards from %d sets · remembered for next time" % [names.size(), sets.size()]
	var config := options(false)
	var refusal := DraftPoolConfig.validate(config, names)
	var total := int(config.boosters) * 15 + int(config.starters) * 60 + int(config.free_lands) * 5 + int(config.extras)
	_pool_ok = refusal == ""
	_pool_status = refusal if refusal != "" else "%d cards to build with · aim for at least %d cards in your deck" % [total, DeckModel.MIN_CARDS]
	_refresh_folder_note()


## THE STATUS LINE'S FOLDER HALF ON ITS OWN (whole-game campaign 2026-10).
## A keystroke in the save-folder field re-read and re-validated the whole
## eligible pool (3,093 cards with every pack on) through [method
## _refresh]; the folder decides only the note below the pool line, so a
## keystroke — and `Default`, and `Browse…` — refresh only that.
func _refresh_folder_note() -> void:
	if status == null or folder == null: return
	status.text = _pool_status
	if _pool_ok and not _folder_the_deck_pickers_read():
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
		_refresh_folder_note()
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
	# The quit after a close goes through this setup ([class Session]).
	var session := Session.new()
	session.setup = self
	session.pool = pool
	session.store = store
	session.seconds = int(config.minutes) * 60
	add_child(session)
	session.tree_exiting.connect(func() -> void:
		launching = false
		window.show()
		if session.returning_to_setup: ShellMusic.play())
