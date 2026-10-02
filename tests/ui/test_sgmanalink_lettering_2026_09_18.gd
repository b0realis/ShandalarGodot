extends GutTest
## LETTERING WEARS ITS SURFACE (2026-09-18). The owner's playtest: *"In
## SGManalink some menus have black letters on dark (stone looking
## windows). That cannot be read. Please change so all lettering is
## contrasting brighter on dark windows."* Every label, rich text, check
## box and check button the lobby and the tournament hall show — on the
## pages, in the sub-windows, in the deck chooser and on every tab of a
## live hall — is read against the surface it sits on, and the two must
## be far apart in brightness. No skin needed; no socket opens.

## The least gap in luminance between lettering and its ground that reads
## at a glance: pale on stone is ~0.75, ink on parchment ~0.7, the gold of
## a fact on stone ~0.5, an accent warning on parchment ~0.6.
const GAP := 0.4

var _had_name := false
var _saved_name: Variant


func before_each() -> void:
	_had_name = Settings.has_value(SgIdentity.KEY)
	_saved_name = Settings.get_value(SgIdentity.KEY, "")
	Settings.clear_value(SgIdentity.KEY)


func after_each() -> void:
	if _had_name: Settings.set_value(SgIdentity.KEY, _saved_name)
	else: Settings.clear_value(SgIdentity.KEY)


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	return lobby


func _click(root: Node, text: String) -> void:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree():
			node.pressed.emit()
			for i in 3: await get_tree().process_frame
			return
	assert_true(false, "missing visible button: " + text)


func _settle() -> void:
	for i in 4: await get_tree().process_frame


## The open sub-window's own Close — not the lobby's, which ends the visit.
func _close(body: VBoxContainer) -> void:
	(body.get_meta("sg_window").find_child("CloseWindow", true, false) as Button).pressed.emit()
	await _settle()


## The colour behind [param node]: its own well where it has one, else the
## nearest section, frame or window that says what it is painted.
func _surface(node: Control) -> Color:
	for key in ["normal", "panel"]:
		if node.has_theme_stylebox_override(key):
			var own := node.get_theme_stylebox(key)
			if own is StyleBoxFlat and own.bg_color.a > 0.5: return own.bg_color
	var probe := node.get_parent()
	while probe != null:
		if probe is Control and probe.has_theme_stylebox_override("panel"):
			var box: StyleBox = probe.get_theme_stylebox("panel")
			if box is StyleBoxFlat and box.bg_color.a > 0.5: return box.bg_color
		if probe.has_meta("sg_light"):
			return SgLobbyStyle.PAPER if bool(probe.get_meta("sg_light")) else SgLobbyStyle.DARK
		probe = probe.get_parent()
	return SgLobbyStyle.DARK


func _ink(node: Control) -> Color:
	if node is RichTextLabel: return node.get_theme_color("default_color")
	return node.get_theme_color("font_color")


## Every piece of lettering visible under [param root], each read against
## its ground. Returns the ones that cannot be read, for the message.
func _unreadable(root: Node, where: String) -> Array:
	var faults: Array = []
	var seen := 0
	for kind in ["Label", "RichTextLabel", "CheckBox", "CheckButton", "LineEdit", "ItemList", "Tree", "OptionButton"]:
		for node: Control in root.find_children("*", kind, true, false):
			if not node.is_visible_in_tree(): continue
			if node is Label and node.text.strip_edges().is_empty(): continue
			seen += 1
			var ink := _ink(node)
			var ground := _surface(node)
			if absf(ink.get_luminance() - ground.get_luminance()) < GAP:
				faults.append("%s: %s '%s' ink %s on %s" % [where, kind, _name_of(node), ink.to_html(false), ground.to_html(false)])
	assert_gt(seen, 0, where + " shows some lettering")
	return faults


func _name_of(node: Control) -> String:
	if node is Label or node is Button: return String(node.text).left(40)
	return String(node.name)


func _readable(root: Node, where: String) -> void:
	var faults := _unreadable(root, where)
	assert_eq(faults, [], where + ": lettering reads against its ground")


func test_every_lobby_page_and_window_reads() -> void:
	var lobby := _lobby()
	for page in ["home", "identity", "host"]:
		lobby._show_page(page)
		await _settle()
		_readable(lobby, page)
	await _click(lobby, "Network settings…")
	_readable(lobby, "Network settings")
	assert_eq(lobby._advertise.get_theme_color("font_color"), SgLobbyStyle.PALE, "a check button on the stone wears pale")
	await _close(lobby._network_window)
	await _click(lobby, "Table rules…")
	_readable(lobby, "Table rules")
	await _close(lobby._rules_window)
	lobby._host_decks.select(1)
	lobby._host_decks.item_selected.emit(1)
	await get_tree().process_frame
	await _click(lobby, "Choose deck…")
	await _settle()
	var list := lobby.find_child("HostDeckList", true, false) as ItemList
	if list.item_count > 0:
		list.select(0)
		list.item_selected.emit(0)
		await _settle()
	_readable(lobby, "Assigned deck")
	var contents := lobby.find_child("HostDeckContents", true, false) as RichTextLabel
	assert_true(contents.has_theme_stylebox_override("normal"), "a decklist sits in a well of its own")
	lobby._show_page("browser")
	await _settle()
	_readable(lobby, "browser")
	await _click(lobby, "Join by invitation…")
	_readable(lobby, "Join by invitation")
	await _close(lobby._invite_window)
	lobby._discovery = SgLanDiscovery.new()
	lobby.add_child(lobby._discovery)
	var crypto := Crypto.new()
	var certificate := crypto.generate_self_signed_certificate(crypto.generate_rsa(2048),
		"CN=" + SgLanInvite.COMMON_NAME + ",O=SGManalink,C=XX", "20200101000000", "20400101000000")
	var pem := SgLanInvite.public_pem(certificate)
	var fox := {"address": "192.168.0.5", "port": 17897, "name": "Forest Fox", "fingerprint": pem.sha256_text(),
		"rooms": 2, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp(), "access": "open",
		"invitation": SgLanInvite.create("192.168.0.5", 17897, "a".repeat(64), pem), "tables": [
			{"name": "Kitchen table", "decks": "own", "deck": "", "open": true},
			{"name": "Knights only", "decks": "fixed", "deck": "White Knights", "open": false}]}
	var owl := {"address": "192.168.0.6", "port": 17897, "name": "Old Owl", "fingerprint": "b".repeat(64),
		"rooms": 0, "build": "elsewhere", "stamp": SgCompatibility.stamp(), "access": "invitation",
		"tables": [], "tournament": "Friday Cup"}
	for advert in [fox, owl]:
		lobby._discovery.hosts["%s:%d" % [advert.address, advert.port]] = {"host": advert, "seen": Time.get_ticks_msec()}
	lobby._refresh()
	await _settle()
	_readable(lobby, "browser with games")
	lobby.client.state.room = {"id":"r1", "name":"Evening Magic", "seat":0,
		"names":["Azure Fox", "Amber Owl"], "revision":1, "ready":[true,false],
		"connected":[true,true], "game":{}, "deck_names":["Knights","Raiders"], "deck":{}}
	lobby._show_page("room")
	await _settle()
	_readable(lobby, "room")
	lobby._open_decks()
	await _settle()
	var picks := lobby._deck_picker.find_child("NetworkDeckList", true, false) as ItemList
	if picks != null and picks.item_count > 0:
		picks.select(0)
		picks.item_selected.emit(0)
		await _settle()
	_readable(lobby, "room deck chooser")
	assert_null(lobby.service)
	assert_false(lobby.client._wanted)
	# The tournament page is the host's, and a fresh visit's.
	lobby = _lobby()
	lobby._show_page("tournament")
	await _settle()
	_readable(lobby, "tournament setup")
	var panel := lobby._tournament_panel
	for window in ["Change…", "Table rules…", "Welcome message…", "Save folder…"]:
		await _click(panel, window)
		_readable(lobby, window)
		panel.close_windows()
		await _settle()
	assert_null(lobby.service)
	assert_false(lobby.client._wanted)


func test_a_label_takes_the_ink_of_the_surface_it_lands_on_and_keeps_a_colour_of_its_own() -> void:
	var root := VBoxContainer.new()
	add_child_autofree(root)
	var paper := SgLobbyStyle.column(root, "Parchment", true)
	var stone := SgLobbyStyle.column(root, "Stone", false)
	var on_paper := SgLobbyStyle.label("ink", 16, true)
	paper.add_child(on_paper)
	assert_eq(on_paper.get_theme_color("font_color"), UiChrome.INK, "the surface wins over the caller's guess")
	var on_stone := SgLobbyStyle.label("pale")
	stone.add_child(on_stone)
	assert_eq(on_stone.get_theme_color("font_color"), SgLobbyStyle.PALE)
	var fact := SgLobbyStyle.label("a fact in gold")
	fact.add_theme_color_override("font_color", SgLobbyStyle.GOLD)
	stone.add_child(fact)
	assert_eq(fact.get_theme_color("font_color"), SgLobbyStyle.GOLD, "a colour the caller chose is kept")
	paper.remove_child(on_paper)
	stone.add_child(on_paper)
	assert_eq(on_paper.get_theme_color("font_color"), SgLobbyStyle.PALE, "moved to the stone, it turns pale")
	var box := CheckButton.new()
	box.text = "listed"
	SgLobbyStyle.check(box)
	stone.add_child(box)
	for state in SgLobbyStyle.INKS:
		assert_eq(box.get_theme_color(state), SgLobbyStyle.PALE, state)
	assert_eq(box.get_theme_color("font_shadow_color").a, 0.0, "no seat under pale lettering")
	stone.remove_child(box)
	paper.add_child(box)
	assert_eq(box.get_theme_color("font_color"), UiChrome.INK)
	assert_eq(box.get_theme_color("font_shadow_color"), UiChrome.SEAT, "dark lettering keeps its pale seat on parchment")
	var bare := SgLobbyStyle.label("nowhere in particular")
	add_child_autofree(bare)
	assert_eq(bare.get_theme_color("font_color"), SgLobbyStyle.PALE, "no section at all is the stone, as for a button")


func test_the_tournament_hall_reads_on_every_tab() -> void:
	var event := SgTournament.new()
	assert_eq(event.configure({"name": "Lettering Cup", "limit": 8, "wins": 1, "policy": "fixed",
		"decks": [{"name": "White Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}, 4242), "")
	for i in 8:
		var pid := event.register("Player %02d" % (i + 1), str(i).sha256_text())
		event.set_ready(pid, true)
	event.draw_round()
	var server := SgLocalServer.new()
	add_child_autofree(server)
	var host := SgTournamentHost.new()
	host.event = event
	host.organiser = 99
	server.add_child(host)
	var view := host.view(99)
	view.config.welcome = "Welcome, duelists — play fair and have fun."
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var frame := SgLobbyStyle.panel(VBoxContainer.new(), false, 24)
	viewport.add_child(frame)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(900, 540)
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	frame.get_child(0).add_child(scroll)
	var panel := SgTournamentPanel.new()
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(panel)
	panel.present(view, true, false, true)
	await _settle()
	for section in ["advancement", "standings", "players", "entry", "overview"]:
		var button := panel.find_child("TournamentTab_" + section, true, false) as Button
		assert_not_null(button, section)
		if button == null: continue
		button.pressed.emit()
		await _settle()
		_readable(panel, "tab " + section)
	view.organiser = false
	view.you = 1
	panel.present(view, true, false, false)
	await _settle()
	_readable(panel, "an entrant's hall")
