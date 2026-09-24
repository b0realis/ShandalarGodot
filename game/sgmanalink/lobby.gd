class_name SgLobby
extends Control
## [QoL] Separate classic-styled identity, host, browser and waiting-room windows.
## Opening a menu starts no network operation. Only a saved display name persists.

## The referee's fixed table rules (SgPracticeMatch); shown before and inside a room.
const TABLE_RULES := "Full implemented card pool  ·  40–250 cards  ·  20 life\nMana burn on  ·  Free combat damage assignment  ·  Single duel"
var client := SgLocalClient.new()
var service: SgLocalServer
var _port: SpinBox
var _code: LineEdit
var _nickname: LineEdit
var _room_name: LineEdit
var _status: Label
var _notice: Label
var _body: VBoxContainer
var _start: Button
var _connect_button: Button
var _close_button: Button
var _lan_start: Button
var _scan: Button
var _interfaces: OptionButton
var _advertise: CheckButton
var _copy: Button
var _discovery: SgLanDiscovery
var _selected_host: Dictionary = {}
var _connection_controls: VBoxContainer
var _introduction: Label
var _shell: Control
var _window: PanelContainer
var _title: Label
var _pages: Dictionary = {}
var _page := "home"
var _remember: CheckBox
var _identity_summary: Label
var _build_facts: Label
var _address_facts: Label
var _identity_name := ""
var _room_draft := "Friendly duel"
var _redraw_queued := false
var _confirm_close := false
var _host_pending := false
var _room_id := ""
var _duel: SgDuelView
var _browser_connection: VBoxContainer
var _host_controls: VBoxContainer
var _deck_picker: Control
var _catalog: Array = []
var _navigation: Dictionary = {}
var _navigation_bar: HBoxContainer
var _body_snapshot: Dictionary = {}
var _deck_panel: PanelContainer
var _deck_room_id := ""
var _deck_use: Button
var _identity_remember := false
var _deck_selected: Dictionary = {}
var _deck_submission: Dictionary = {}
var _deck_status: Label
var _content_scroll: ScrollContainer
var _tournament_panel: SgTournamentPanel
var _tournament_pending: Dictionary = {}
var _tournament_id := ""
var _master_overlay: Control
var _master_panel: SgTournamentPanel
var _master_notice: Label
var _expand_tournament: Button
var _bot_draft: Dictionary = {}
# THE OPEN TABLE (2026-09-18). The host page keeps its key settings — the
# duel's name, its deck rule, its access — and the rest sits in sub-windows.
var _host_decks: OptionButton
var _host_deck_button: Button
var _host_deck_label: Label
var _host_deck: Dictionary = {}
var _host_deck_window: VBoxContainer
var _invite_only: CheckButton
var _access_hint: Label
var _rules_window: VBoxContainer
var _network_window: VBoxContainer
var _network_button_open: Button
var _invite_window: VBoxContainer
var _invite_prompt: Label
var _pending_join := ""
var _room_copy: Button


func _ready() -> void:
	name = "SGManalinkLobby"
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(client)
	client.changed.connect(_queue_refresh)
	client.refused.connect(func(reason: String) -> void:
		_host_pending = false
		_notice.text = reason
		_report_to_master(reason)
		if is_instance_valid(_duel): _duel.show_notice(reason))
	_shell = Control.new()
	add_child(_shell)
	_shell.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var dim := ColorRect.new()
	dim.color = Color(0.025, 0.035, 0.025, 0.98)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_shell.add_child(dim)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	_window = SgLobbyStyle.panel(column, false, 24)
	_window.add_theme_stylebox_override("panel", OriginalDialog.panel_style("panel_dark_stone", 24))
	_shell.add_child(_window)
	_window.minimum_size_changed.connect(func() -> void: _layout_window.call_deferred())
	var heading := SgLobbyStyle.row(column)
	var globe := ManalinkGlobe.new()
	globe.custom_minimum_size = Vector2(56, 56)
	heading.add_child(globe)
	var masthead := VBoxContainer.new()
	masthead.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	heading.add_child(masthead)
	_title = SgLobbyStyle.label("SGManalink", 30, true)
	masthead.add_child(_title)
	masthead.add_child(SgLobbyStyle.label("Local network only", 16, true))
	_close_button = _button("Close", _close, Vector2(120, 38))
	_close_button.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	heading.add_child(_close_button)
	var navigation := SgLobbyStyle.row(column)
	_navigation_bar = navigation
	for entry in [["Overview", "home"], ["Identity", "identity"], ["Host Game", "host"], ["Game Browser", "browser"], ["Tournament", "tournament"]]:
		var button := _button(entry[0], _show_page.bind(entry[1]), Vector2(100, 36))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.toggle_mode = true
		navigation.add_child(button)
		_navigation[entry[1]] = button
	_status = SgLobbyStyle.label("Not connected", 15, true)
	column.add_child(_status)
	_content_scroll = ScrollContainer.new()
	_content_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_content_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(_content_scroll)
	_connection_controls = VBoxContainer.new()
	_connection_controls.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_connection_controls.add_theme_constant_override("separation", 14)
	_content_scroll.add_child(_connection_controls)
	for key in ["home", "identity", "host", "browser", "tournament"]:
		var page := VBoxContainer.new()
		page.name = key.capitalize() + "Window"
		page.add_theme_constant_override("separation", 14)
		_connection_controls.add_child(page)
		_pages[key] = page
	_build_home(_pages.home)
	_build_identity(_pages.identity)
	_build_host(_pages.host)
	_build_browser(_pages.browser)
	_expand_tournament = SgLobbyStyle.button("Expand Tournament Hall", _open_master)
	_pages.tournament.add_child(_expand_tournament)
	_tournament_panel = SgTournamentPanel.new()
	_tournament_panel.host_requested.connect(_host_tournament)
	_tournament_panel.action_requested.connect(_send)
	_tournament_panel.copy_requested.connect(_copy_invitation)
	_pages.tournament.add_child(_tournament_panel)
	_body = VBoxContainer.new()
	_body.add_theme_constant_override("separation", 12)
	_connection_controls.add_child(_body)
	_notice = SgLobbyStyle.label("", 15, true)
	_notice.custom_minimum_size.y = 20
	column.add_child(_notice)
	var footer := SgLobbyStyle.label("DESKTOP LAN  /  DUELS & TOURNAMENTS  /  UNRATED", 13, true)
	footer.add_theme_color_override("font_color", SgLobbyStyle.GOLD)
	column.add_child(footer)
	resized.connect(_layout_window)
	_layout_window()
	_refresh()
	_layout_window.call_deferred()
	_close_button.grab_focus()
	get_viewport().gui_focus_changed.connect(_keep_focus)

func _layout_window() -> void:
	if _window == null: return
	_window.size = Vector2(minf(980, maxf(0, size.x - 40)), minf(740, maxf(0, size.y - 40)))
	_window.position = (size - _window.size) * 0.5
	if is_instance_valid(_deck_panel):
		_deck_panel.size = Vector2(minf(920, maxf(0, size.x - 48)), maxf(0, size.y - 64))
		_deck_panel.position = (size - _deck_panel.size) * 0.5

func _build_home(page: VBoxContainer) -> void:
	# The Overview carries no buttons of its own (owner's word, 2026-09-17:
	# the tabs above already are the map): what this computer offers, and a
	# sentence for each page so a first visit knows where to click.
	var welcome := SgLobbyStyle.column(page, "", false)
	_introduction = SgLobbyStyle.label("Welcome to SGManalink", 28, true)
	welcome.add_child(_introduction)
	welcome.add_child(SgLobbyStyle.label("Friendly Magic duels and tournaments on your local network. No account, no Internet.", 18, true))
	# What the other computer must match; the game browser compares these.
	var facts := SgLobbyStyle.label("THIS COMPUTER", 13, true)
	facts.add_theme_color_override("font_color", SgLobbyStyle.GOLD)
	welcome.add_child(facts)
	_build_facts = SgLobbyStyle.label(SgCompatibility.summary(), 17, true)
	_build_facts.add_theme_color_override("font_color", SgLobbyStyle.GOLD)
	welcome.add_child(_build_facts)
	_address_facts = SgLobbyStyle.label("", 16, true)
	welcome.add_child(_address_facts)
	_identity_summary = SgLobbyStyle.label("", 16, true)
	welcome.add_child(_identity_summary)
	welcome.add_child(SgLobbyStyle.label("Both players need the same version and packs. Any desktop OS plays together; the web build cannot host or join.", 15, true))
	var guide := SgLobbyStyle.column(page, "How it works")
	var lines := GridContainer.new()
	lines.columns = 2
	lines.add_theme_constant_override("h_separation", 18)
	lines.add_theme_constant_override("v_separation", 8)
	guide.add_child(lines)
	for entry in [["IDENTITY", "Pick a temporary name, or play as a guest. Names are unrated; the host adds a guest number when two match."],
		["HOST", "Host Game opens a table on this computer, open to your LAN unless you tick Invitation only. Keep the game open: your computer runs the referee."],
		["JOIN", "Game Browser lists the tables on your network; one click joins an open one. An invitation-only host needs the invitation they send you. Join only hosts you trust."],
		["TOURNAMENT", "The Tournament hall runs a knockout for up to 20 players on one host, with brackets, live results and standings."]]:
		var caption := _label(entry[0], 13)
		caption.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		caption.size_flags_vertical = Control.SIZE_SHRINK_BEGIN
		caption.custom_minimum_size.x = 110
		caption.add_theme_color_override("font_color", UiChrome.ACCENT)
		lines.add_child(caption)
		lines.add_child(_label(entry[1], 16))

func _build_identity(page: VBoxContainer) -> void:
	var body := SgLobbyStyle.column(page, "Your name at the table")
	body.add_child(_label("Choose a temporary persona, or leave the name blank to play as a guest.", 17))
	body.add_child(_label("PLAYER NAME", 13))
	var row := SgLobbyStyle.row(body)
	_nickname = LineEdit.new()
	_nickname.name = "TemporaryName"
	_nickname.max_length = SgProtocol.NICKNAME_LIMIT
	_nickname.placeholder_text = "Your player name"
	_nickname.text = SgIdentity.remembered_name()
	_identity_name = _nickname.text
	SgLobbyStyle.field(_nickname)
	_nickname.text_submitted.connect(func(_value: String) -> void: _save_identity())
	row.add_child(_nickname)
	row.add_child(_button("Generate name", func() -> void: _nickname.text = SgIdentity.generate_name()))
	_remember = CheckBox.new()
	_remember.text = "Remember this name on this device"
	_remember.button_pressed = not _nickname.text.is_empty()
	_identity_remember = _remember.button_pressed
	SgLobbyStyle.check(_remember)
	body.add_child(_remember)
	body.add_child(_label("Up to 20 letters, numbers, spaces, - or _. No email or SSH key needed.", 15))
	var actions := SgLobbyStyle.row(body)
	actions.add_child(SgLobbyStyle.button("Use this identity", _save_identity))
	actions.add_child(_button("Cancel", _show_page.bind("home")))
	var note := SgLobbyStyle.column(page, "A friendly introduction", false)
	note.add_child(SgLobbyStyle.label("This is a display name, not a verified account. The host adds a guest number so players with the same name can be distinguished.", 16, true))

func _build_host(page: VBoxContainer) -> void:
	var body := SgLobbyStyle.column(page, "Open your table")
	body.add_child(_label("Host a friendly duel. Keep the game open while your opponent plays.", 17))
	body.add_child(_label("DUEL NAME", 13))
	_room_name = LineEdit.new()
	_room_name.name = "RoomName"
	_room_name.text = _room_draft
	_room_name.max_length = 32
	_room_name.text_changed.connect(func(value: String) -> void: _room_draft = value)
	_room_name.text_submitted.connect(func(_value: String) -> void:
		if not _lan_start.disabled: _host_game())
	SgLobbyStyle.field(_room_name)
	body.add_child(_room_name)
	# The deck rule: everyone brings a deck, or the host assigns one to both seats.
	body.add_child(_label("DECKS", 13))
	var decks_row := SgLobbyStyle.row(body)
	_host_decks = OptionButton.new()
	_host_decks.name = "HostDecks"
	_host_decks.custom_minimum_size = Vector2(240, 38)
	_host_decks.add_item("Bring your own deck")
	_host_decks.add_item("Assigned deck")
	UiChrome.shadowed_button(_host_decks)
	SgLobbyStyle.option(_host_decks)
	_host_decks.item_selected.connect(func(_index: int) -> void: _refresh())
	decks_row.add_child(_host_decks)
	_host_deck_button = _button("Choose deck…", func() -> void: SgLobbyStyle.open_window(_host_deck_window), Vector2(150, 38))
	_host_deck_button.name = "HostDeckChoose"
	decks_row.add_child(_host_deck_button)
	_host_deck_label = _label("", 16)
	_host_deck_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_host_deck_label.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	decks_row.add_child(_host_deck_label)
	_host_deck_window = SgLobbyStyle.window(page, "Assigned deck", "HostDeckWindow")
	_host_deck_window.add_child(_label("Both seats play this deck. Browse shipped and saved decks; the guest sees its full list in the room.", 16))
	_deck_chooser(_host_deck_window, "HostDeck", "Assign this deck", func(deck: Dictionary) -> void:
		_host_deck = deck
		SgLobbyStyle.close_window(_host_deck_window)
		_refresh())
	# Access: open by default. Copy invitation sits right beside the switch,
	# so nobody searches for it (owner's word, 2026-09-18).
	body.add_child(_label("ACCESS", 13))
	var access_row := SgLobbyStyle.row(body)
	_invite_only = CheckButton.new()
	_invite_only.name = "InviteOnly"
	_invite_only.text = "Invitation only"
	_invite_only.button_pressed = false
	SgLobbyStyle.check(_invite_only)
	_invite_only.toggled.connect(func(_value: bool) -> void: _refresh())
	access_row.add_child(_invite_only)
	_copy = SgLobbyStyle.button("Copy invitation", _copy_invitation, Vector2(170, 38))
	_copy.name = "CopyInvitation"
	access_row.add_child(_copy)
	_access_hint = _label("", 15)
	body.add_child(_access_hint)
	var actions := SgLobbyStyle.row(body)
	_lan_start = SgLobbyStyle.button("Host on LAN", _host_game)
	_lan_start.name = "StartLan"
	actions.add_child(_lan_start)
	actions.add_child(_button("Back", _show_page.bind("home")))
	# Everything else opens in a sub-window.
	var more := SgLobbyStyle.row(page)
	more.add_child(_button("Table rules…", func() -> void: SgLobbyStyle.open_window(_rules_window)))
	_network_button_open = _button("Network settings…", func() -> void: SgLobbyStyle.open_window(_network_window))
	more.add_child(_network_button_open)
	_rules_window = SgLobbyStyle.window(page, "At this table", "TableRulesWindow")
	_rules_window.add_child(_label(TABLE_RULES, 16))
	_rules_window.add_child(_label("Both players confirm Ready before play begins. Your guest needs the same game version and enabled packs: " + SgCompatibility.summary() + ".", 15))
	_network_window = SgLobbyStyle.window(page, "Network settings", "NetworkWindow")
	_host_controls = VBoxContainer.new()
	_host_controls.add_theme_constant_override("separation", 10)
	_network_window.add_child(_host_controls)
	var row := SgLobbyStyle.row(_host_controls)
	var address_label := _label("LAN address", 16)
	address_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(address_label)
	_interfaces = OptionButton.new()
	_interfaces.name = "LanInterface"
	_interfaces.custom_minimum_size = Vector2(220, 38)
	for address in SgLanInvite.local_addresses(): _interfaces.add_item(address)
	if _interfaces.item_count == 0: _interfaces.add_item("No LAN IPv4 address")
	UiChrome.shadowed_button(_interfaces)
	SgLobbyStyle.option(_interfaces)
	row.add_child(_interfaces)
	var port_label := _label("Port", 16)
	port_label.autowrap_mode = TextServer.AUTOWRAP_OFF
	row.add_child(port_label)
	_port = SpinBox.new()
	_port.name = "LocalPort"
	_port.min_value = 1024
	_port.max_value = 65535
	_port.value = 17897
	SgLobbyStyle.field(_port.get_line_edit())
	row.add_child(_port)
	_advertise = CheckButton.new()
	_advertise.text = "Listed in the LAN game browser"
	_advertise.button_pressed = true
	SgLobbyStyle.check(_advertise)
	_host_controls.add_child(_advertise)
	_host_controls.add_child(_label("Switch off to keep this host off every game browser; only the invitation reaches it then.", 15))
	var advanced := SgLobbyStyle.column(_network_window, "Same-computer testing", false)
	advanced.add_child(SgLobbyStyle.label("A second window on this computer connects with the local access code and port.", 15, true))
	_start = SgLobbyStyle.button("Start local service", _start_service)
	_start.name = "StartService"
	advanced.add_child(_start)


## A deck picker: a search, the list and the complete text, and one button
## that hands the chosen deck to [param choose]. Node names take [param prefix].
func _deck_chooser(parent: Control, prefix: String, caption: String, choose: Callable) -> Button:
	var search := LineEdit.new()
	search.name = prefix + "Search"
	search.placeholder_text = "Search shipped and saved decks"
	SgLobbyStyle.field(search)
	parent.add_child(search)
	var split := SgLobbyStyle.row(parent)
	split.custom_minimum_size.y = 260
	var list := ItemList.new()
	list.name = prefix + "List"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.x = 220
	SgLobbyStyle.deck_list(list)
	split.add_child(list)
	var details := RichTextLabel.new()
	details.name = prefix + "Contents"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size.x = 200
	SgLobbyStyle.rich_text(details)
	split.add_child(details)
	var use := SgLobbyStyle.button(caption, func() -> void:
		var selected := list.get_selected_items()
		if selected.is_empty(): return
		var deck: Dictionary = _catalog[int(list.get_item_metadata(selected[0]))]
		choose.call(SgDeckCatalog.payload(deck)))
	use.name = prefix + "Use"
	use.disabled = true
	use.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	parent.add_child(use)
	list.item_selected.connect(func(index: int) -> void:
		details.text = _deck_text(_catalog[int(list.get_item_metadata(index))])
		use.disabled = false)
	var refill := func(query: String) -> void:
		if _catalog.is_empty(): _catalog = SgDeckCatalog.available()
		list.clear()
		use.disabled = true
		details.text = "Select a deck to review its complete list."
		for index in _catalog.size():
			var deck: Dictionary = _catalog[index]
			if not query.is_empty() and not String(deck.name).to_lower().contains(query.to_lower()): continue
			list.add_item("%s (%d)" % [deck.name, deck.cards.size()])
			list.set_item_metadata(list.item_count - 1, index)
			list.set_item_tooltip(list.item_count - 1, deck.group)
	search.text_changed.connect(refill)
	# The catalogue is read when the window first opens, not when the lobby does.
	var sheet: Control = parent.get_meta("sg_window")
	sheet.visibility_changed.connect(func() -> void:
		if sheet.visible and list.item_count == 0: refill.call(search.text))
	return use


## "" while this computer hosts nothing; "open" or "invitation" for its host.
func _host_access() -> String:
	if service == null: return ""
	return "open" if service.open_to_lan else "invitation"


## The invitation of the host this computer runs: the LAN invitation, or
## the local access code of a same-computer service.
func _invitation_text() -> String:
	if service == null: return ""
	return service.invitation() if not service.lan_address.is_empty() else service.access_code


func _copy_invitation() -> void:
	var text := _invitation_text()
	if text.is_empty():
		_notice.text = "Host a table first; the invitation exists once your host is running."
		return
	DisplayServer.clipboard_set(text)
	_notice.text = "Invitation copied. Send it privately; clipboard history may retain it."


func _build_browser(page: VBoxContainer) -> void:
	var body := SgLobbyStyle.column(page, "Find your next opponent")
	_browser_connection = VBoxContainer.new()
	_browser_connection.add_theme_constant_override("separation", 12)
	body.add_child(_browser_connection)
	_browser_connection.add_child(_label("Tables on your network are listed below. Join an open one with a click; an invitation-only host needs the invitation they send you.", 17))
	var row := SgLobbyStyle.row(_browser_connection)
	_scan = _button("Find LAN games", _scan_lan)
	row.add_child(_scan)
	row.add_child(_button("Join by invitation…", func() -> void: _open_invite_window("")))
	# The invitation path, in its own window: for invitation-only hosts and
	# for same-computer testing with a local access code.
	_invite_window = SgLobbyStyle.window(page, "Join by invitation", "InviteWindow")
	_invite_prompt = _label("Paste the invitation your host sent you.", 16)
	_invite_window.add_child(_invite_prompt)
	var join_row := SgLobbyStyle.row(_invite_window)
	_code = LineEdit.new()
	_code.name = "AccessCode"
	_code.placeholder_text = "Paste the host invitation"
	_code.max_length = SgLanInvite.MAX_LENGTH
	_code.secret = true
	_code.tooltip_text = "Private invitation. Never saved by the game."
	_code.text_submitted.connect(func(_value: String) -> void:
		if not _connect_button.disabled: _connect_local())
	SgLobbyStyle.field(_code)
	join_row.add_child(_code)
	_connect_button = SgLobbyStyle.button("Connect", _connect_local, Vector2(130,40))
	join_row.add_child(_connect_button)
	var local_row := HBoxContainer.new()
	local_row.hide()
	_invite_window.add_child(_button("Same-computer testing", func() -> void: local_row.visible = not local_row.visible))
	_invite_window.add_child(local_row)
	local_row.add_child(_label("Local test port", 15))
	var local_port := SpinBox.new()
	local_port.min_value = 1024
	local_port.max_value = 65535
	local_port.value = _port.value
	SgLobbyStyle.field(local_port.get_line_edit())
	local_port.value_changed.connect(func(value: float) -> void: _port.value = value)
	_port.value_changed.connect(func(value: float) -> void:
		if value >= local_port.min_value: local_port.value = value)
	local_row.add_child(local_port)


func _open_invite_window(host_name: String) -> void:
	_invite_prompt.text = "Paste the invitation your host sent you." if host_name.is_empty() \
		else "%s hosts by invitation only. Ask them for it and paste it here." % host_name
	SgLobbyStyle.open_window(_invite_window)
	_code.grab_focus()


func _close_windows() -> void:
	for window in [_host_deck_window, _rules_window, _network_window, _invite_window]:
		if window != null: SgLobbyStyle.close_window(window)
	if _tournament_panel != null: _tournament_panel.close_windows()


func _save_identity() -> void:
	if client.has_session() or client.online or client.connecting() or service != null:
		_notice.text = "Finish this visit before changing your identity."
		return
	var result := SgIdentity.save_name(_nickname.text, _remember.button_pressed)
	if not result.is_empty():
		_notice.text = result
		return
	_nickname.text = _nickname.text.strip_edges()
	_identity_name = _nickname.text
	_identity_remember = _remember.button_pressed
	_show_page("home")
	_notice.text = "Identity selected. " + ("Name remembered on this device."
		if _remember.button_pressed and not _nickname.text.is_empty() else "Name used for this visit only.")


func _show_page(page: String) -> void:
	if page not in ["home", "identity", "host", "browser", "room", "tournament"]:
		return
	if page == "identity" and (client.has_session() or client.online or client.connecting() or service != null):
		_notice.text = "Your current guest name stays fixed until you disconnect."
		return
	if _page == "identity" and page != "identity":
		_nickname.text = _identity_name
		_remember.button_pressed = _identity_remember
	_page = page
	_content_scroll.scroll_vertical = 0
	_notice.text = ""
	_confirm_close = false
	_close_windows()
	_refresh()
	_close_button.grab_focus()


func _keep_focus(control: Control) -> void:
	if is_inside_tree() and is_visible_in_tree() and not is_queued_for_deletion() \
		and control != null and control != self and not is_ancestor_of(control):
		_restore_focus.call_deferred()


func _restore_focus() -> void:
	if is_inside_tree() and not is_queued_for_deletion():
		if is_instance_valid(_duel):
			_duel.focus_action()
		else:
			_close_button.grab_focus()


func _unhandled_key_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		if is_instance_valid(_master_overlay):
			_close_master()
		elif _window_open():
			_close_windows()
		elif is_instance_valid(_deck_picker):
			_close_decks()
		elif is_instance_valid(_duel):
			_duel.toggle_menu()
		elif _page not in ["home", "room"]:
			_show_page("home")
		else:
			_close()
		get_viewport().set_input_as_handled()


func _window_open() -> bool:
	for window in [_host_deck_window, _rules_window, _network_window, _invite_window]:
		if SgLobbyStyle.window_open(window): return true
	return _tournament_panel != null and _tournament_panel.window_open()


func _button(text: String, callback: Callable, minimum := Vector2(180, 38)) -> Button:
	return SgLobbyStyle.button(text, callback, minimum)


func _label(text: String, font_size := 16) -> Label:
	return SgLobbyStyle.label(text, font_size)


func _address_summary() -> String:
	if service != null and not service.lan_address.is_empty():
		return "Hosting at %s, port %d  ·  %s" % [service.lan_address, service.port,
			("open to the LAN" if service.open_to_lan else "invitation only")
			+ ("" if service.discovery != null and service.discovery.advertising else ", not listed in game browsers")]
	if OS.has_feature("web"):
		return "The browser build cannot host or join. Use the desktop game for LAN play."
	var addresses := SgLanInvite.local_addresses()
	if addresses.is_empty():
		return "No LAN IPv4 address. Connect this computer to your local network to host or join."
	return "LAN address  ·  " + ", ".join(addresses)

func _host_game() -> void:
	if not SgProtocol.short_text(_room_draft.strip_edges()):
		_notice.text = "Room names use up to 32 letters, numbers, spaces, - and _."
		return
	if _host_decks.selected == 1 and _host_deck.is_empty():
		_notice.text = "Choose the deck both players will use, or switch to Bring your own deck."
		SgLobbyStyle.open_window(_host_deck_window)
		return
	if client.online:
		_send(_host_action())
		return
	_host_pending = true
	_start_lan(not _invite_only.button_pressed)
	if service == null:
		_host_pending = false


func _host_action() -> Dictionary:
	var fixed := _host_decks.selected == 1
	return {"op": "host", "name": _room_draft.strip_edges(),
		"decks": "fixed" if fixed else "own", "deck": _host_deck.duplicate(true) if fixed else {}}


func _host_tournament(options: Dictionary, restore_path: String) -> void:
	if client.busy(): return
	_tournament_pending = {"options": options.duplicate(true), "path": restore_path,
		"folder": GamePaths.tournaments_folder()}
	if service == null:
		if client.has_session() or client.online or client.connecting():
			_notice.text = "Disconnect from the other host before hosting your own tournament."
			_tournament_pending.clear()
			return
		_start_lan(not _tournament_panel.invite_only)
		if service == null: _tournament_pending.clear()
	_queue_refresh()


func _close_master() -> void:
	if is_instance_valid(_master_overlay):
		_master_overlay.get_parent().remove_child(_master_overlay)
		_master_overlay.queue_free()
	_master_overlay = null
	_master_panel = null
	_master_notice = null
	if is_instance_valid(_duel):
		_duel._tournament_panel_open = false
		_duel.focus_action()


func _open_master() -> void:
	if client.state.get("tournament", {}).is_empty(): return
	_close_master()
	var dim := ColorRect.new()
	dim.color = Color(0.02, 0.025, 0.02, 1.0)
	dim.z_index = 500
	add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_master_overlay = dim
	var margin := MarginContainer.new()
	dim.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for edge in ["left", "right", "top", "bottom"]: margin.add_theme_constant_override("margin_" + edge, 24)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 14)
	margin.add_child(column)
	var toolbar := SgLobbyStyle.row(column)
	toolbar.add_child(SgLobbyStyle.button("Back to duel" if is_instance_valid(_duel) else "Back to hall", _close_master))
	if is_instance_valid(_duel):
		toolbar.add_child(SgLobbyStyle.button("Duel controls", func() -> void:
			_close_master()
			if is_instance_valid(_duel): _duel._show_connection()))
	toolbar.add_child(SgLobbyStyle.button("Reconnect", client.reconnect))
	# The overlay is opaque and, in a duel, the lobby shell is hidden as well:
	# a refused organiser control had nowhere left to print its reason.
	_master_notice = SgLobbyStyle.label("", 15, true)
	_master_notice.name = "MasterPanelNotice"
	_master_notice.custom_minimum_size.y = 20
	column.add_child(_master_notice)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	column.add_child(scroll)
	_master_panel = SgTournamentPanel.new()
	_master_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_master_panel.action_requested.connect(_send)
	_master_panel.copy_requested.connect(func() -> void:
		_copy_invitation()
		_report_to_master(_notice.text))
	_master_panel.host_access = _host_access()
	scroll.add_child(_master_panel)
	if is_instance_valid(_duel): _duel._tournament_panel_open = true
	_master_panel.present(client.state.tournament, client.online, client.busy(), service != null)


func _start_service() -> void:
	if service != null or not _valid_nickname():
		return
	var candidate := SgLocalServer.new()
	add_child(candidate)
	var result := candidate.start_local(int(_port.value))
	if result != OK:
		candidate.queue_free()
		_notice.text = "Cannot start on this port. Choose a free port."
		return
	service = candidate
	_port.value = service.port
	_code.text = service.access_code
	_selected_host = {}
	SgLobbyStyle.close_window(_network_window)
	_notice.text = "Local service started. Use its access code and port in a second window on this computer."
	_connect_local()


## Start this computer's LAN host; [param open] publishes its invitation in
## the LAN advert so the Game Browser joins without a paste.
func _start_lan(open := true) -> void:
	if service != null or not _valid_nickname():
		return
	var address := _interfaces.get_item_text(_interfaces.selected)
	if not SgLanInvite.local_addresses().has(address):
		_notice.text = "Connect this computer to a private IPv4 LAN first."
		return
	var candidate := SgLocalServer.new()
	add_child(candidate)
	var result := candidate.start_lan(address, int(_port.value), _advertise.button_pressed,
		_nickname.text.strip_edges(), SgLanDiscovery.PORT, open)
	if result != OK:
		candidate.queue_free()
		_notice.text = "Cannot host on this address and port. Check the network or choose another port."
		return
	service = candidate
	_port.value = service.port
	_code.text = service.invitation()
	_selected_host = {}
	_pending_join = ""
	_notice.text = ("LAN host started. Players on your network join from their Game Browser." if service.open_to_lan \
		else "LAN host started. Copy invitation and send it to your opponent.") + " Closing ends all hosted games."
	if service.discovery_error != OK:
		_notice.text += " Discovery is unavailable; the invitation still connects directly."
	_connect_local()


func _scan_lan() -> void:
	if _discovery == null:
		_discovery = SgLanDiscovery.new()
		add_child(_discovery)
		_discovery.changed.connect(_queue_refresh)
	if _discovery.scanning:
		_discovery.stop()
		_selected_host = {}
	else:
		var result := _discovery.scan()
		_notice.text = "Searching the LAN for tables." \
			if result == OK else "Cannot scan this network. Connect by invitation instead."
	_refresh()


## Join from the Game Browser. An open host published its invitation: the
## client connects with it and, once the state arrives, sits at the named
## table. An invitation-only host needs its invitation pasted first.
func _join_advert(advert: Dictionary, table_name: String) -> void:
	if client.online or client.busy() or client.connecting() or client.has_session(): return
	var mismatch := _advert_mismatch(advert)
	if not mismatch.is_empty():
		_notice.text = mismatch
		return
	if not _valid_nickname(): return
	_selected_host = advert.duplicate(true)
	_pending_join = table_name
	if SgLanDiscovery.open_host(advert):
		if client.connect_invitation(String(advert.invitation), _nickname.text) == OK:
			_notice.text = "Connecting to %s…" % advert.name
		else:
			_pending_join = ""
			_notice.text = "Cannot connect to this host. LAN play requires the desktop game."
	else:
		_open_invite_window(String(advert.name))
	_refresh()


func _connect_local() -> void:
	if client.online or client.busy() or client.connecting():
		return
	if client.has_session():
		client.reconnect()
		return
	if not _valid_nickname():
		return
	var invitation := _code.text.strip_edges()
	var result: Error
	if invitation.begins_with(SgLanInvite.PREFIX):
		var data := SgLanInvite.parse(invitation)
		if not _selected_host.is_empty() and (data.is_empty() \
			or data.address != _selected_host.address or data.port != _selected_host.port \
			or data.fingerprint != _selected_host.fingerprint):
			_notice.text = "This invitation does not match the selected host. Clear the selection to join it directly."
			return
		result = client.connect_invitation(invitation, _nickname.text)
	else:
		if not _selected_host.is_empty():
			_notice.text = "Paste the complete LAN invitation from the host, not a local access code."
			return
		result = client.connect_local(int(_port.value), invitation, _nickname.text)
	if result != OK:
		_notice.text = "Paste a complete invitation from the current host. LAN play requires the desktop game."


func _valid_nickname() -> bool:
	if SgProtocol.nickname(_nickname.text.strip_edges()):
		return true
	_notice.text = "Temporary names use up to 20 letters, numbers, spaces, - or _. Leave blank for a guest name."
	return false


func _close() -> void:
	var room: Dictionary = client.state.room
	if not _confirm_close and (service != null or not room.is_empty() or client.has_session()):
		_confirm_close = true
		_close_button.text = "Confirm close"
		_notice.text = "Closing forgets this temporary seat. If you host, all your games end. "
		_notice.text += "Click Confirm close to continue."
		return
	queue_free()


func _queue_refresh() -> void:
	if not _redraw_queued:
		_redraw_queued = true
		_refresh.call_deferred()


func _refresh() -> void:
	_redraw_queued = false
	if not is_inside_tree():
		return
	var room: Dictionary = client.state.room
	if not _tournament_pending.is_empty() and service != null and client.online and not client.busy():
		var pending := _tournament_pending.duplicate(true)
		_tournament_pending.clear()
		var error := service.open_tournament(pending.options, client._resume, pending.folder, pending.path)
		_notice.text = error if not error.is_empty() else ("Tournament opened. Players on your network register from their Game Browser; entrants should save their recovery codes."
			if service.open_to_lan else "Tournament opened. Copy invitation and send it to every entrant; they should save their recovery codes.")
	var event: Dictionary = client.state.get("tournament", {})
	# The host's own seat is the organiser's: a live event on this service
	# whose chair is empty — the earlier session abandoned with its resume
	# code — is taken back with the session this lobby holds now.
	if service != null and client.online and not client.busy() and not event.is_empty() \
			and not bool(event.get("organiser", false)) and String(event.get("phase", "")) in ["registration", "running"]:
		if service.reclaim_tournament(client._resume).is_empty():
			_notice.text = "Tournament controls recovered for this seat."
	if String(event.get("id", "")) != _tournament_id:
		_tournament_id = String(event.get("id", ""))
		_close_master()
		if not event.is_empty(): _page = "tournament"
	if _host_pending and client.online and not client.busy() and room.is_empty():
		_host_pending = false
		_send(_host_action())
	if not _pending_join.is_empty() and client.online and not client.busy() and room.is_empty():
		var wanted := _pending_join
		_pending_join = ""
		var found := false
		for listed: Dictionary in client.state.rooms:
			if listed.name == wanted and listed.open:
				found = true
				_send({"op": "join", "room": listed.id})
				break
		if not found and not wanted.is_empty():
			_notice.text = "The table “%s” is no longer open. Pick another on this host." % wanted
	if not room.is_empty():
		_page = "room"
	elif not _room_id.is_empty():
		_page = "tournament" if not event.is_empty() else "browser"
	if is_instance_valid(_deck_picker) and (String(room.get("id", "")) != _deck_room_id or not room.get("game", {}).is_empty()):
		_close_decks()
	_room_id = String(room.get("id", ""))
	var playing: bool = not room.is_empty() and not room.game.is_empty()
	if is_instance_valid(_duel) and _duel._built and String(_duel._room.get("id", "")) != _room_id:
		_duel.queue_free()
		_duel = null
		_close_master()
	if playing:
		_close_decks()
		if not is_instance_valid(_duel):
			_duel = SgDuelView.new()
			add_child(_duel)
			_duel.action_requested.connect(_send)
			_duel.reconnect_requested.connect(client.reconnect)
			_duel.exit_requested.connect(func() -> void: queue_free())
			_duel.hall_requested.connect(func() -> void: _send({"op": "t_return", "event": client.state.tournament.id}))
			_duel.tournament_requested.connect(_open_master)
		_duel.present(room, client.online, client.busy(), service != null)
	elif is_instance_valid(_duel):
		_duel.queue_free()
		_duel = null
		_close_master()
	_tournament_panel.host_access = _host_access()
	if _page == "tournament":
		_expand_tournament.visible = not event.is_empty()
		_expand_tournament.text = "Expand Master Panel" if event.get("organiser", false) else "Expand Tournament Hall"
		_tournament_panel.present(event, client.online, client.busy(), service != null or not (client.online or client.has_session() or client.connecting() or OS.has_feature("web")))
	if is_instance_valid(_master_panel):
		_master_panel.host_access = _host_access()
		_master_panel.present(event, client.online, client.busy(), service != null)
	_shell.visible = not playing
	_connection_controls.visible = not playing
	_status.text = client.status + ("  ·  " + client.guest if client.online else "")
	_status.add_theme_color_override("font_color", SgLobbyStyle.PALE if client.online else SgLobbyStyle.MUTED)
	_identity_summary.text = "Your name at the table  ·  " + (_identity_name if not _identity_name.is_empty() else "Guest")
	if _page == "home": _address_facts.text = _address_summary()
	var locked := client.online or client.has_session() or client.connecting() or service != null
	_nickname.editable = not locked
	_start.disabled = locked or OS.has_feature("web")
	_lan_start.disabled = client.busy() or OS.has_feature("web") \
		or (not client.online and (locked or not SgLanInvite.address(_interfaces.get_item_text(_interfaces.selected))))
	_lan_start.text = "Host a duel" if client.online else "Host on LAN"
	_interfaces.disabled = locked
	_advertise.disabled = locked
	_invite_only.disabled = locked
	_port.editable = not locked
	_host_controls.visible = not client.online
	_network_button_open.disabled = client.online
	_host_deck_button.visible = _host_decks.selected == 1
	_host_deck_label.visible = _host_decks.selected == 1
	_host_deck_label.text = "No deck chosen yet" if _host_deck.is_empty() else String(_host_deck.name)
	_access_hint.text = "Only players you send the invitation to can join." if _invite_only.button_pressed \
		else "Anyone on your network sees this table in their Game Browser and joins with a click."
	_copy.disabled = _invitation_text().is_empty()
	_copy.tooltip_text = "Available once your host is running." if _copy.disabled else "Copies the invitation to the clipboard."
	_scan.disabled = client.online or client.has_session() or client.connecting() or OS.has_feature("web")
	_scan.text = "Stop LAN search" if _discovery != null and _discovery.scanning else "Find LAN games"
	if (_page != "browser" or client.online) and _discovery != null and _discovery.scanning:
		_discovery.stop()
	_connect_button.disabled = client.online or client.busy() or client.connecting()
	_connect_button.text = "Connected" if client.online else ("Connecting…" if client.connecting() else ("Reconnect" if client.has_session() else "Connect"))
	_code.editable = not locked
	_browser_connection.visible = not client.online
	if client.online: SgLobbyStyle.close_window(_invite_window)
	_close_button.text = "Confirm close" if _confirm_close else "Close"
	_title.text = {"home": "SGManalink", "identity": "Identity", "host": "Host Game",
		"browser": "Game Browser", "room": "Duel room", "tournament": "LAN Tournament"}[_page]
	for key in _pages:
		_pages[key].visible = key == _page
		_navigation[key].set_pressed_no_signal(key == _page)
		_navigation[key].disabled = not room.is_empty() or (key == "identity" and locked)
	_navigation_bar.visible = room.is_empty()
	if is_instance_valid(_deck_picker):
		if not _deck_submission.is_empty() and not client.busy():
			if room.get("deck", {}) == _deck_submission:
				_close_decks()
			else:
				_deck_submission.clear()
				_deck_status.text = _notice.text if not _notice.text.is_empty() else "Deck choice not confirmed. Please try again."
		if is_instance_valid(_deck_picker):
			_deck_use.disabled = not client.online or client.busy() or _deck_selected.is_empty()
			if not client.online: _deck_status.text = "Connection lost. Your selection is kept while you reconnect."
	if playing: return
	# Stable rows avoid focus/scroll churn on ACKs and repeated discoveries.
	var adverts: Array = []
	if _discovery != null:
		var keys := _discovery.hosts.keys()
		keys.sort()
		for key in keys: adverts.append(_discovery.hosts[key].host)
	var room_display := room.duplicate(true)
	room_display.erase("revision")
	var snapshot := {"page":_page, "room":room_display, "rooms":client.state.rooms,
		"hosts":adverts, "selected":_selected_host, "online":client.online, "locked":locked}
	if snapshot == _body_snapshot:
		_update_lobby_actions()
		return
	_body_snapshot = snapshot.duplicate(true)
	for child in _body.get_children():
		_body.remove_child(child)
		child.queue_free()
	if _page == "room":
		_waiting_room(room)
	elif _page == "browser":
		_browser()
	elif _page == "home" and locked:
		_body.add_child(_button("Disconnect", _disconnect))
	_update_lobby_actions()


func _disconnect() -> void:
	if service != null:
		service.stop()
		service.queue_free()
		service = null
	client.forget()
	_code.text = ""
	_selected_host.clear()
	_pending_join = ""
	_host_pending = false
	_tournament_pending.clear()
	_tournament_id = ""
	_show_page("home")


func _waiting_room(room: Dictionary) -> void:
	var fixed: bool = room.get("decks", "own") == "fixed"
	var header := SgLobbyStyle.column(_body, String(room.name), false)
	header.add_child(SgLobbyStyle.label(("Both seats play the assigned deck: %s." % room.get("fixed_deck", "") if fixed
		else "Choose your deck.") + " Confirm when you are ready to play.", 17, true))
	# The host sees how guests reach this table, and Copy invitation right
	# there — nobody hunts for it (owner's word, 2026-09-18).
	if service != null and int(room.seat) == 0:
		var access := SgLobbyStyle.row(header)
		var line := SgLobbyStyle.label("Open table — players on your network see “%s” in their Game Browser." % room.name
			if service.open_to_lan else "Invitation only — send the invitation to your opponent.", 16, true)
		line.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		line.size_flags_vertical = Control.SIZE_SHRINK_CENTER
		access.add_child(line)
		_room_copy = _button("Copy invitation", _copy_invitation, Vector2(170, 38))
		_room_copy.name = "RoomCopyInvitation"
		_room_copy.disabled = _invitation_text().is_empty()
		access.add_child(_room_copy)
	var players := SgLobbyStyle.row(_body)
	for seat in 2:
		var column := VBoxContainer.new()
		column.add_theme_constant_override("separation", 10)
		var card := SgLobbyStyle.panel(column)
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		players.add_child(card)
		column.add_child(_label("YOUR SEAT" if seat == int(room.seat) else "OPPONENT", 13))
		column.add_child(_label(room.names[seat], 21))
		var status := "Waiting for player" if not room.connected[seat] else ("Ready" if room.ready[seat] else "Choosing a deck")
		var state_label := _label(status, 16)
		state_label.add_theme_color_override("font_color", Color8(44,82,38) if room.connected[seat] and room.ready[seat] else UiChrome.ACCENT)
		column.add_child(state_label)
		# The referee's default deck is honest for a player who has not chosen
		# yet; an empty seat has nobody to play it.
		var deck_line := "Deck: " + String(room.deck_names[seat])
		if room.names[seat] == "Empty seat": deck_line = "Deck: —"
		column.add_child(_label(deck_line, 17))
	var rules := SgLobbyStyle.column(_body, "Duel rules")
	rules.add_child(_label(TABLE_RULES, 16))
	var actions := SgLobbyStyle.row(rules)
	actions.add_child(_network_button("Review assigned deck" if fixed else "Choose / review deck", _open_decks))
	actions.add_child(_network_button("Not ready" if room.ready[int(room.seat)] else "Ready", func() -> void:
		_send({"op":"ready", "value":not room.ready[int(room.seat)]})))
	actions.add_child(_network_button("Leave room", func() -> void: _send({"op":"leave"})))
	if int(room.seat) == 0 and not room.connected[1] and room.names[1] != "Empty seat":
		rules.add_child(_network_button("Remove disconnected guest", func() -> void: _send({"op":"remove_guest"})))
	var bots: Array = room.get("bots", [{}, {}])
	if not bots[1].is_empty():
		rules.add_child(_label("Computer opponent: " + SgBotPlayer.label(bots[1]) \
			+ (" — sees your current hand" if bots[1].unfair else " — fair information"), 17))
		if int(room.seat) == 0:
			rules.add_child(_network_button("Remove computer opponent", func() -> void: _send({"op": "remove_bot"})))
	elif int(room.seat) == 0 and room.names[1] == "Empty seat":
		var bot_body := SgLobbyStyle.column(_body, "Play against the computer")
		var setup := SgBotSetup.new()
		bot_body.add_child(setup)
		if _catalog.is_empty(): _catalog = SgDeckCatalog.available()
		setup.changed.connect(func(value: Dictionary) -> void: _bot_draft = value)
		setup.submitted.connect(func(_count: int, options: Dictionary, deck: Dictionary) -> void:
			_send({"op": "add_bot", "bot": options, "deck": deck}))
		setup.build(1, _catalog, _bot_draft)
		setup.find_child("AddBots", true, false).set_meta("network_action", true)
	var note := SgLobbyStyle.column(_body, "", false)
	note.add_child(SgLobbyStyle.label("Deck contents go to the referee, not your opponent. Changing a deck or opponent clears human Ready marks; computer seats stay ready. Disconnected human seats are held for 5 minutes.", 15, true))
	note.add_child(SgLobbyStyle.label("Friendly and unrated. Play with a host you trust: their computer runs the referee.", 15, true))
	if not client.online: note.add_child(_button("Reconnect", client.reconnect))


func _network_button(text: String, callback: Callable, available := true) -> Button:
	var button := SgLobbyStyle.button(text, callback)
	button.set_meta("network_action", true)
	button.set_meta("available", available)
	return button


func _update_lobby_actions() -> void:
	for node in _body.find_children("*", "Button", true, false):
		if node.has_meta("network_action"):
			node.disabled = not client.online or client.busy() or not node.get_meta("available")

func _close_decks() -> void:
	if is_instance_valid(_deck_picker):
		_deck_picker.get_parent().remove_child(_deck_picker)
		_deck_picker.queue_free()
	_deck_picker = null
	_deck_panel = null
	_deck_use = null
	_deck_status = null
	_deck_room_id = ""
	_deck_selected.clear()
	_deck_submission.clear()


func _open_decks() -> void:
	_close_decks()
	if client.state.room.is_empty() or not client.state.room.get("game", {}).is_empty(): return
	_deck_room_id = String(client.state.room.get("id", ""))
	if _catalog.is_empty(): _catalog = SgDeckCatalog.available()
	var overlay := ColorRect.new()
	overlay.color = Color(0, 0, 0, 0.88)
	add_child(overlay)
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_deck_picker = overlay
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation", 12)
	_deck_panel = SgLobbyStyle.panel(column, true, 20)
	overlay.add_child(_deck_panel)
	_layout_window()
	var fixed: bool = client.state.room.get("decks", "own") == "fixed"
	var heading := SgLobbyStyle.row(column)
	heading.add_child(_label("The assigned deck" if fixed else "Choose your deck", 26))
	heading.add_child(_button("Back", _close_decks, Vector2(100,38)))
	if fixed:
		# The table deals this deck to both seats; there is nothing to choose.
		column.add_child(_label("The host assigned this deck to both seats. Review it, then confirm Ready.", 16))
		var contents := RichTextLabel.new()
		contents.name = "NetworkDeckContents"
		contents.size_flags_vertical = Control.SIZE_EXPAND_FILL
		SgLobbyStyle.rich_text(contents)
		contents.text = _deck_text(client.state.room.deck) if not client.state.room.deck.is_empty() else "The deck arrives with the next update."
		column.add_child(contents)
		return
	column.add_child(_label("Browse shipped and saved decks. Only your own full list is shown here.", 16))
	var search := LineEdit.new()
	search.name = "NetworkDeckSearch"
	search.placeholder_text = "Search shipped and saved decks"
	SgLobbyStyle.field(search)
	column.add_child(search)
	var row := SgLobbyStyle.row(column)
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	var list := ItemList.new()
	list.name = "NetworkDeckList"
	list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	list.custom_minimum_size.x = 220
	SgLobbyStyle.deck_list(list)
	row.add_child(list)
	var details := RichTextLabel.new()
	details.name = "NetworkDeckContents"
	details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	details.custom_minimum_size.x = 200
	SgLobbyStyle.rich_text(details)
	row.add_child(details)
	_deck_status = _label("", 15)
	column.add_child(_deck_status)
	_deck_use = SgLobbyStyle.button("Use this deck", func() -> void:
		if _deck_selected.is_empty() or not client.online or client.busy(): return
		if String(client.state.room.get("id", "")) != _deck_room_id:
			_close_decks()
			return
		var deck := _deck_selected.duplicate(true)
		if _send(SgDeckCatalog.payload(deck).merged({"op": "deck"})):
			_deck_submission = deck
			_deck_status.text = "Waiting for the host to confirm your deck…"
			_deck_use.disabled = true)
	_deck_use.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	_deck_use.disabled = true
	column.add_child(_deck_use)
	var show_deck := func(deck: Dictionary) -> void:
		_deck_selected = SgDeckCatalog.payload(deck)
		details.text = _deck_text(deck)
		_deck_use.disabled = not client.online or client.busy()
	list.item_selected.connect(func(index: int) -> void: show_deck.call(_catalog[int(list.get_item_metadata(index))]))
	var refill := func(query: String) -> void:
		list.clear()
		_deck_selected.clear()
		_deck_use.disabled = true
		details.text = "Select a deck to review its complete list."
		for index in _catalog.size():
			var deck: Dictionary = _catalog[index]
			if not query.is_empty() and not String(deck.name).to_lower().contains(query.to_lower()): continue
			list.add_item("%s (%d)" % [deck.name, deck.cards.size()])
			list.set_item_metadata(list.item_count - 1, index)
			list.set_item_tooltip(list.item_count - 1, deck.group)
		_deck_status.text = "%d decks available" % list.item_count if list.item_count > 0 else "No matching decks. Try a shorter name."
	search.text_changed.connect(refill)
	refill.call("")
	if not client.state.room.deck.is_empty(): show_deck.call(client.state.room.deck)
	search.grab_focus()

static func _deck_text(deck: Dictionary) -> String:
	var result := "%s\n%d cards · %d sideboard\n" % [deck.name, deck.cards.size(), deck.sideboard.size()]
	var warning := DeckModel.size_advice(deck.cards.size())
	if not warning.is_empty(): result += warning + "\n"
	for zone in ["cards", "sideboard"]:
		var counts := {}
		for card_name in deck[zone]: counts[card_name] = int(counts.get(card_name, 0)) + 1
		var names := counts.keys()
		names.sort()
		result += "\nMain deck\n" if zone == "cards" else "\nSideboard (not used in a single duel)\n"
		for card_name in names: result += "%d  %s\n" % [counts[card_name], card_name]
	return result


func _browser() -> void:
	if not client.online:
		var nearby := SgLobbyStyle.column(_body, "Tables on your network")
		if _discovery == null or _discovery.hosts.is_empty():
			nearby.add_child(_label("No tables listed yet", 21))
			nearby.add_child(_label("Click Find LAN games. Your friend must keep their host open on the same network; "
				+ "if their table stays unlisted, ask for their invitation.", 16))
			return
		# One row per table, not per host: the duel's name is what a player
		# looks for (owner's word, 2026-09-18). A tournament is one row.
		var table := _table(nearby, ["DUEL", "HOST", "DECKS", "INVITE ONLY", "BUILD", ""])
		var keys := _discovery.hosts.keys()
		keys.sort()
		for key in keys:
			var advert: Dictionary = _discovery.hosts[key].host
			var rows: Array = []
			if advert.has("tournament"):
				rows.append({"name": "Tournament · " + String(advert.tournament), "decks": "", "open": true, "table": ""})
			for entry: Dictionary in advert.get("tables", []):
				rows.append({"name": String(entry.name), "table": String(entry.name), "open": bool(entry.open),
					"decks": "Assigned: " + String(entry.deck) if entry.decks == "fixed" else "Bring your own"})
			if rows.is_empty():
				rows.append({"name": "No table yet", "decks": "", "open": true, "table": ""})
			for entry: Dictionary in rows:
				_cell(table, String(entry.name), true)
				var host := _cell(table, String(advert.name))
				host.tooltip_text = "%s:%d" % [advert.address, int(advert.port)]
				_cell(table, String(entry.decks))
				table.add_child(_invite_only_mark(not SgLanDiscovery.open_host(advert)))
				var brief := _advert_brief(advert)
				var build := _cell(table, brief if not brief.is_empty() else "Same as yours")
				build.add_theme_color_override("font_color", UiChrome.ACCENT if not brief.is_empty() else SgLobbyStyle.GOLD.darkened(0.45))
				var join := _button("Join" if entry.open else "In play", _join_advert.bind(advert.duplicate(true), String(entry.table)), Vector2(100,34))
				join.disabled = not entry.open or client.connecting() or client.has_session()
				table.add_child(join)
		return
	if not client.state.get("tournament", {}).is_empty():
		var event := SgLobbyStyle.column(_body, client.state.tournament.config.name)
		event.add_child(_label("This host is running a LAN tournament. Open the hall to register or follow the results.", 17))
		event.add_child(_button("Open Tournament Hall", _show_page.bind("tournament")))
		return
	var rooms := SgLobbyStyle.column(_body, "Duels on this host")
	if client.state.rooms.is_empty():
		rooms.add_child(_label("No open tables yet", 21))
		rooms.add_child(_label("Open Host Game to create a duel on this host.", 16))
		return
	var table := _table(rooms, ["DUEL", "HOST", "DECKS", "SEAT", ""])
	for room: Dictionary in client.state.rooms:
		_cell(table, String(room.name), true)
		_cell(table, String(room.host))
		_cell(table, "Assigned: " + String(room.deck) if room.get("decks", "own") == "fixed" else "Bring your own")
		_cell(table, "Open" if room.open else "Taken")
		table.add_child(_network_button("Join" if room.open else "In use", func() -> void:
			_send({"op":"join", "room":room.id}), room.open))


## A table of discovered games: a caption row, then one row per game.
## The first column takes the slack; a button column ends each row.
func _table(parent: Node, captions: Array) -> GridContainer:
	var table := GridContainer.new()
	table.columns = captions.size()
	table.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	table.add_theme_constant_override("h_separation", 18)
	table.add_theme_constant_override("v_separation", 6)
	parent.add_child(table)
	for i in captions.size():
		var caption := _cell(table, captions[i], i == 0, 13)
		caption.add_theme_color_override("font_color", UiChrome.ACCENT)
	return table


func _cell(table: GridContainer, text: String, wide := false, font_size := 16) -> Label:
	var cell := _label(text, font_size)
	cell.size_flags_horizontal = Control.SIZE_EXPAND_FILL if wide else Control.SIZE_SHRINK_BEGIN
	cell.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	cell.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART if wide else TextServer.AUTOWRAP_OFF
	table.add_child(cell)
	return cell


## The browser's INVITE ONLY column: a ticked box on a host that asks for
## its invitation before Join, an empty one where Join connects straight
## away (owner's word, 2026-09-18). It reports and takes no clicks; a
## disabled box would fade the tick into the stone.
func _invite_only_mark(ticked: bool) -> CheckBox:
	var mark := CheckBox.new()
	mark.button_pressed = ticked
	mark.mouse_filter = Control.MOUSE_FILTER_IGNORE
	mark.focus_mode = Control.FOCUS_NONE
	mark.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	SgLobbyStyle.check(mark)
	return mark


## An advert is untrusted; it only previews the hello check the host repeats.
func _advert_mismatch(advert: Dictionary) -> String:
	if String(advert.get("build", "")) == client.build_fingerprint: return ""
	var why := SgCompatibility.difference(SgCompatibility.stamp(), advert.get("stamp", {}), "This host")
	return why if not why.is_empty() else SgCompatibility.catalogue_mismatch("This host")


func _advert_brief(advert: Dictionary) -> String:
	if String(advert.get("build", "")) == client.build_fingerprint: return ""
	var why := SgCompatibility.brief(SgCompatibility.stamp(), advert.get("stamp", {}))
	return why if not why.is_empty() else "Modified files"


func _send(action: Dictionary) -> bool:
	_confirm_close = false
	_notice.text = ""
	_report_to_master("")
	if not client.command(action):
		var reason := client.command_error
		_notice.text = reason
		_report_to_master(reason)
		if is_instance_valid(_duel):
			_duel.show_notice(reason)
		return false
	return true


## The host's answer to an organiser control, inside the expanded panel that
## covers every other notice line.
func _report_to_master(reason: String) -> void:
	if is_instance_valid(_master_notice): _master_notice.text = reason
