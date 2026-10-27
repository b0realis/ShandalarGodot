class_name MpnFiles
extends RefCounted
## [QoL] Shared View/Cancel and Export MPN file dialogs. Imported records
## are data, never scripts; validate before opening or writing them.

static func choose(owner: Node, selected: Callable) -> void:
	if OS.has_feature("web"):
		_choose_web(owner, selected)
		return
	var picker := FileDialog.new()
	picker.title = "View past-played games"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	picker.add_filter("*.mpn", "Magic Public Notation")
	picker.ok_button_text = "View"
	picker.cancel_button_text = "Cancel"
	picker.current_dir = ProjectSettings.globalize_path(GamePaths.records_folder())
	owner.add_child(picker)
	picker.canceled.connect(picker.queue_free)
	picker.file_selected.connect(func(path: String) -> void:
		var parsed := MpnArchive.read(path)
		if parsed.error != "": UiChrome.explain_popup(owner, "Cannot view MPN", parsed.error)
		else: selected.call(path)
		picker.queue_free())
	picker.popup_centered(Vector2i(700, 480))

## THE MOVE LIST SAVED as text ([MpnMoveList]): a .txt beside the records,
## or a download on the web.
static func export_text(owner: Node, text: String, filename := "game.txt") -> void:
	var bytes := text.to_utf8_buffer()
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, filename.get_file(), "text/plain")
		return
	var picker := FileDialog.new()
	picker.title = "Save the move list"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.add_filter("*.txt", "Text")
	picker.current_dir = ProjectSettings.globalize_path(GamePaths.records_folder())
	picker.current_file = filename.get_file()
	owner.add_child(picker)
	picker.canceled.connect(picker.queue_free)
	picker.file_selected.connect(func(path: String) -> void:
		var ok := write_whole(path, bytes)
		UiChrome.explain_popup(owner, "Save the move list", "Move list saved." if ok else "Could not save the move list.")
		picker.queue_free())
	picker.popup_centered(Vector2i(700, 480))


static func export_bytes(owner: Node, bytes: PackedByteArray, filename := "game.mpn") -> void:
	var parsed := MpnCodec.parse_bytes(bytes)
	if parsed.error != "":
		UiChrome.explain_popup(owner, "Cannot export MPN", parsed.error)
		return
	if OS.has_feature("web"):
		JavaScriptBridge.download_buffer(bytes, filename.get_file(), "text/plain")
		return
	var picker := FileDialog.new()
	picker.title = "Export MPN — public game record"
	picker.access = FileDialog.ACCESS_FILESYSTEM
	picker.file_mode = FileDialog.FILE_MODE_SAVE_FILE
	picker.add_filter("*.mpn", "Magic Public Notation")
	picker.current_file = filename.get_file()
	owner.add_child(picker)
	picker.canceled.connect(picker.queue_free)
	picker.file_selected.connect(func(path: String) -> void:
		# FileDialog confirms replacement of the exact selected path. Do not
		# append an extension afterwards and overwrite a different file.
		if path.get_extension().to_lower() != "mpn":
			UiChrome.explain_popup(owner, "Export MPN", "Please use a filename ending in .mpn.")
		else:
			var ok := write_whole(path, bytes)
			UiChrome.explain_popup(owner, "Export MPN", "Public game record saved." if ok else "Could not save the recording.")
		picker.queue_free())
	picker.popup_centered(Vector2i(700, 480))

## WHOLE OR NOT AT ALL (the bug campaign c12, h5-7 / h6-3): Export MPN,
## Save text… and a record brought in on the web wrote straight over the
## chosen file, and a full disk after the player confirmed Replace left the
## earlier file cut short — while the buffered write and its flush still
## reported no error, so the popup said "saved". [method
## Settings.write_atomically] writes beside the file, checks the length
## that reached the disk and only then renames it into place; a file the
## player made read-only is refused, a link stays a link. False = nothing
## changed on disk, and the caller says so.
static func write_whole(path: String, bytes: PackedByteArray) -> bool:
	return Settings.write_atomically(path, bytes) == OK

static func _choose_web(owner: Node, selected: Callable) -> void:
	# No server/upload: the browser reads the chosen file locally. Polling
	# is owned by the screen, so closing it cancels the import as well.
	var key := "sg_mpn_" + MpnArchive.new_id()
	JavaScriptBridge.eval("""
	(() => {
	 const key = '%s', input = document.createElement('input');
	 window[key] = null; input.type = 'file'; input.accept = '.mpn';
	 input.oncancel = () => { window[key] = {error:'cancel'}; };
	 input.onchange = async () => {
	  const f = input.files[0];
	  if (!f) { window[key] = {error:'cancel'}; return; }
	  if (f.size > %d) { window[key] = {error:'File exceeds 32 MiB.'}; return; }
	  try { window[key] = {text:await f.text()}; }
	  catch (_) { window[key] = {error:'Could not read this file.'}; }
	 };
	 input.click();
	})();
	""" % [key, MpnCodec.MAX_BYTES], true)
	var timer := Timer.new()
	timer.wait_time = 0.2
	owner.add_child(timer)
	timer.tree_exiting.connect(func() -> void: JavaScriptBridge.eval("delete window['%s']" % key, true))
	timer.timeout.connect(func() -> void:
		var answer: Variant = JavaScriptBridge.eval("window['%s'] ? JSON.stringify(window['%s']) : ''" % [key, key], true)
		if not answer is String or answer.is_empty(): return
		timer.stop()
		var data: Dictionary = JSON.parse_string(answer)
		if data.has("error"):
			if data.error != "cancel": UiChrome.explain_popup(owner, "Cannot view MPN", data.error)
		else:
			var parsed := MpnCodec.parse(data.text)
			if parsed.error != "": UiChrome.explain_popup(owner, "Cannot view MPN", parsed.error)
			else:
				DirAccess.make_dir_recursive_absolute(GamePaths.records_folder())
				var path := GamePaths.records_folder().path_join("import-" + MpnArchive.new_id() + ".mpn")
				if write_whole(path, String(data.text).to_utf8_buffer()):
					selected.call(path)
				else: UiChrome.explain_popup(owner, "Cannot view MPN", "Could not store the imported file.")
		timer.queue_free())
	timer.start()
