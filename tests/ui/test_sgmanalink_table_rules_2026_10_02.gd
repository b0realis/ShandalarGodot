extends GutTest
## THE TABLE RULES (2026-10-02). The owner's word: *"establish a
## togglable, modifiable basic table rules when you host the game"*. A
## host chooses the starting life and the seven implemented rules forks
## for their table; the choice crosses the wire as one validated
## dictionary (SgTableRules), reaches the listings as a one-line brief,
## the room view whole, and the referee's game as life and forks. The
## standard table is exactly what every host opened before: 20 life
## under modern rules with mana burn on. One editor (SgTableRulesSetup)
## serves the duel host page and the tournament setup, and remembers the
## host's last table on this device.

var server: SgLocalServer
var scanner: SgLanDiscovery
var clients: Array = []
var refusals: Array = []
var _had_rules := false
var _saved_rules: Variant
var _had_folder := false
var _saved_folder: Variant


func before_each() -> void:
	_had_rules = Settings.has_value(SgTableRulesSetup.KEY)
	_saved_rules = Settings.get_value(SgTableRulesSetup.KEY, {})
	Settings.clear_value(SgTableRulesSetup.KEY)
	_had_folder = Settings.has_value(GamePaths.KEY_TOURNAMENTS)
	_saved_folder = Settings.get_value(GamePaths.KEY_TOURNAMENTS, null) if _had_folder else null
	refusals.clear()


func after_each() -> void:
	for client: SgLocalClient in clients:
		if is_instance_valid(client): client.forget()
	clients.clear()
	if scanner != null: scanner.stop()
	if server != null: server.stop()
	scanner = null
	server = null
	if _had_rules: Settings.set_value(SgTableRulesSetup.KEY, _saved_rules)
	else: Settings.clear_value(SgTableRulesSetup.KEY)
	if _had_folder: Settings.set_value(GamePaths.KEY_TOURNAMENTS, _saved_folder)
	else: Settings.clear_value(GamePaths.KEY_TOURNAMENTS)
	for i in 3: await get_tree().process_frame


func _until(predicate: Callable, frames := 600) -> bool:
	for i in frames:
		if predicate.call(): return true
		await get_tree().process_frame
	assert_true(false, "the LAN exchange exceeded its frame budget")
	return false


func _host() -> void:
	server = SgLocalServer.new()
	add_child_autofree(server)
	scanner = SgLanDiscovery.new()
	add_child_autofree(scanner)
	assert_eq(server.start_lan("127.0.0.1", 0, true, "Forest Fox", 0, true), OK)
	assert_eq(server.discovery_error, OK)
	assert_eq(scanner.scan(), OK)


func _advert() -> Dictionary:
	server.poll()
	scanner.hosts.clear()
	scanner.query("127.0.0.1", server.discovery._socket.get_local_port())
	await _until(func() -> bool: return scanner.hosts.size() == 1)
	return scanner.hosts.values()[0].host if scanner.hosts.size() == 1 else {}


func _client(nickname: String) -> SgLocalClient:
	var client := SgLocalClient.new()
	add_child_autofree(client)
	clients.append(client)
	client.refused.connect(func(reason: String) -> void: refusals.append(reason))
	assert_eq(client.connect_invitation(server.invitation(), nickname), OK)
	await _until(func() -> bool: return client.online)
	return client


func _act(client: SgLocalClient, action: Dictionary) -> void:
	assert_true(client.command(action), client.command_error)
	await _until(func() -> bool: return not client.busy())
	for i in 3: await get_tree().process_frame


## A 1997 table at thirty life: every fork the Fifth Edition way.
func _fifth_thirty() -> Dictionary:
	var options := RulesOptions.new()
	options.set_preset("fifth")
	return SgTableRules.from_options(30, options)


## A table that crossed the wire comes back with JSON's sorted keys and
## an integral float for its life; the same table all the same.
func _same_table(got: Variant, expected: Dictionary, context: String) -> void:
	assert_true(SgTableRules.valid(got), context + ": a valid table: " + str(got))
	assert_true(SgTableRules.normalize(got) == expected, context + ": " + str(got))


func test_the_standard_table_is_the_table_every_host_opened_before() -> void:
	var standard := SgTableRules.standard()
	assert_eq(standard.life, 20)
	assert_eq(standard.forks.keys(), Array(RulesOptions.IMPLEMENTED), "exactly the implemented forks, in their order")
	assert_true(standard.forks.mana_burn, "the old fixed table burned mana")
	assert_true(standard.forks.free_damage_assignment, "and divided combat damage freely")
	assert_eq(SgTableRules.options(standard).preset(), RulesOptions.DEFAULT_PRESET)
	assert_eq(SgTableRules.brief(standard), "Modern rules, mana burn on  ·  20 life")
	assert_eq(SgTableRules.summary(standard), "Full implemented card pool  ·  40–250 cards  ·  20 life\nModern rules, mana burn on  ·  Single duel")
	var duel := SgPracticeMatch.new(42)
	assert_eq(duel.game.players[0].life, 20)
	assert_eq(duel.game.rules.preset(), RulesOptions.DEFAULT_PRESET, "a match without table rules plays the standard table")
	# Validation: the exact shape, nothing a sender's build knows beyond it.
	assert_true(SgTableRules.valid(standard))
	assert_true(SgTableRules.valid(_fifth_thirty()))
	var json_life := standard.duplicate(true)
	json_life.life = 20.0
	assert_true(SgTableRules.valid(json_life), "a JSON-decoded life is an integral float")
	for broken in [null, "standard", [], {}, {"life": 20}, {"forks": standard.forks},
			{"life": 20, "forks": standard.forks, "ante": false},
			{"life": 0, "forks": standard.forks}, {"life": 401, "forks": standard.forks},
			{"life": 20.5, "forks": standard.forks}, {"life": "20", "forks": standard.forks},
			{"life": 20, "forks": "fifth"}, {"life": 20, "forks": {}},
			{"life": 20, "forks": standard.forks.merged({"ante": true})},
			{"life": 20, "forks": standard.forks.merged({"mana_burn": 1}, true)}]:
		assert_false(SgTableRules.valid(broken), str(broken))
		assert_eq(SgTableRules.normalize(broken), standard, "anything invalid means the standard table")
	var copy := SgTableRules.normalize(_fifth_thirty())
	copy.forks.mana_burn = false
	assert_true(_fifth_thirty().forks.mana_burn, "normalize hands out a private copy")
	# The readouts of a 1997 table and of a custom one.
	var fifth := _fifth_thirty()
	assert_eq(SgTableRules.brief(fifth), "1997 — Fifth Edition  ·  30 life")
	assert_false(SgTableRules.summary(fifth).contains("Mana burn: on"), "a named preset needs no fork list")
	var custom := SgTableRules.standard()
	custom.forks.damage_prevention_window = true
	assert_eq(SgTableRules.preset_label(custom), RulesOptions.CUSTOM_LABEL)
	assert_eq(SgTableRules.brief(custom), "Custom  ·  20 life")
	assert_string_contains(SgTableRules.summary(custom), "Damage prevention step: on")
	assert_string_contains(SgTableRules.summary(custom), "Mana burn: on")
	assert_eq(SgTableRules.detail(custom).split("  ·  ").size(), 7, "every implemented fork is named")
	assert_lte(SgTableRules.brief(custom).length(), 64, "a brief fits a listing row")
	for entry in RulesOptions.PRESETS:
		var options := RulesOptions.new()
		options.set_preset(entry["id"])
		assert_lte(SgTableRules.brief(SgTableRules.from_options(SgTableRules.MAX_LIFE, options)).length(), 64, String(entry["label"]))
	# apply() sets a game's forks; life is setup's.
	var game := MtgGame.new()
	SgTableRules.apply(game, fifth)
	assert_eq(game.rules.preset(), "fifth")
	assert_true(game.rules.damage_prevention_window)
	assert_false(game.rules.attackers_revocable)


func test_a_hosted_table_plays_under_its_rules_and_the_wire_carries_them() -> void:
	_host()
	var fox := await _client("Fox")
	var owl := await _client("Owl")
	var fifth := _fifth_thirty()
	await _act(fox, {"op": "host", "name": "The 1997 table", "decks": "own", "deck": {}, "rules": fifth})
	assert_eq(refusals, [])
	_same_table(fox.state.room.rules, fifth, "the room view carries the table whole")
	assert_eq(String(fox.state.rooms[0].rules), "1997 — Fifth Edition  ·  30 life", "the listing carries the brief")
	assert_eq(String(owl.state.rooms[0].rules), "1997 — Fifth Edition  ·  30 life")
	var advert := await _advert()
	if advert.is_empty(): return
	assert_eq(advert.tables, [{"name": "The 1997 table", "decks": "own", "deck": "", "open": true,
		"rules": "1997 — Fifth Edition  ·  30 life"}], "the advert names the table's rules before anyone connects")
	assert_true(SgLanDiscovery.valid_advert(advert))
	assert_true(JSON.stringify(advert).length() <= SgLanDiscovery.MAX_PACKET)
	# A host that sends an impossible table is refused as a bad command,
	# and a host without the field opens the standard table.
	var hare := await _client("Hare")
	assert_false(hare.command({"op": "host", "name": "Zero life", "decks": "own", "deck": {}, "rules": {"life": 0, "forks": fifth.forks}}),
		"the client's own protocol check refuses it first")
	await _act(hare, {"op": "host", "name": "Plain table", "decks": "own", "deck": {}})
	_same_table(hare.state.room.rules, SgTableRules.standard(), "no field means the standard table")
	assert_eq(String(hare.state.rooms[1].rules if hare.state.rooms.size() > 1 else ""), SgTableRules.brief(SgTableRules.standard()))
	await _act(hare, {"op": "leave"})
	# The duel: both seats start at thirty under every 1997 fork, on the
	# referee and in each seat's view.
	await _act(owl, {"op": "join", "room": String(owl.state.rooms[0].id)})
	_same_table(owl.state.room.rules, fifth, "the guest sees the table before readying")
	await _act(fox, {"op": "ready", "value": true})
	await _act(owl, {"op": "ready", "value": true})
	await _until(func() -> bool: return not fox.state.room.get("game", {}).is_empty() and not owl.state.room.get("game", {}).is_empty())
	var room: Dictionary = server._rooms.values()[0]
	assert_eq(room.rules, fifth)
	assert_eq(room.match.game.players[0].life, 30)
	assert_eq(room.match.game.players[1].life, 30)
	assert_eq(room.match.game.rules.preset(), "fifth")
	assert_true(room.match.game.rules.damage_prevention_window)
	assert_true(room.match.game.rules.mana_burn)
	assert_false(room.match.game.rules.attackers_revocable)
	for client: SgLocalClient in [fox, owl]:
		var game: Dictionary = client.state.room.game
		assert_eq(int(game.players[0].life), 30)
		assert_eq(int(game.players[1].life), 30)
		assert_true(bool(game.presentation.rules.damage_prevention_window))
		assert_false(bool(game.presentation.rules.attackers_revocable))
		_same_table(client.state.room.rules, fifth, "the view keeps the table while the duel runs")


func test_the_editor_builds_a_table_and_remembers_it_on_this_device() -> void:
	var setup := SgTableRulesSetup.new()
	add_child_autofree(setup)
	setup.build()
	var heard: Array = []
	setup.changed.connect(func(rules: Dictionary) -> void: heard.append(rules))
	assert_eq(setup.value(), SgTableRules.standard(), "a fresh device opens the standard table")
	var life := setup.find_child("TableLife", true, false) as SpinBox
	var preset := setup.find_child("TablePreset", true, false) as OptionButton
	var readout := setup.find_child("TableReadout", true, false) as Label
	assert_not_null(life)
	assert_not_null(preset)
	if life == null or preset == null: return
	assert_eq(life.min_value, 1.0)
	assert_eq(life.max_value, 400.0)
	assert_eq(preset.item_count, RulesOptions.PRESETS.size() + 1, "every Options preset and the Custom readout")
	assert_eq(preset.get_item_text(preset.item_count - 1), RulesOptions.CUSTOM_LABEL)
	assert_eq(preset.get_item_text(preset.selected), "Modern rules, mana burn on")
	assert_eq(readout.text, "Modern rules, mana burn on  ·  20 life")
	for key: String in RulesOptions.IMPLEMENTED:
		var box := setup.find_child("TableRule_" + key, true, false) as CheckButton
		assert_not_null(box, key)
		if box == null: continue
		assert_eq(box.button_pressed, bool(SgTableRules.standard().forks[key]), key)
		assert_string_contains(box.tooltip_text, "1997: ")
	# Life: the spin box, clamped by its own bounds.
	life.value = 30
	assert_eq(setup.value().life, 30)
	assert_eq(heard.size(), 1)
	assert_eq(readout.text, "Modern rules, mana burn on  ·  30 life")
	# A fork switch makes the table Custom; the preset box says so.
	var prevention := setup.find_child("TableRule_damage_prevention_window", true, false) as CheckButton
	prevention.button_pressed = true
	assert_eq(preset.get_item_text(preset.selected), RulesOptions.CUSTOM_LABEL)
	assert_true(setup.value().forks.damage_prevention_window)
	assert_eq(readout.text, "Custom  ·  30 life")
	# A preset sets every switch.
	var fifth_index := -1
	for i in preset.item_count:
		if preset.get_item_text(i) == "1997 — Fifth Edition": fifth_index = i
	assert_gt(fifth_index, -1)
	preset.select(fifth_index)
	preset.item_selected.emit(fifth_index)
	assert_eq(setup.value(), _fifth_thirty())
	var burn := setup.find_child("TableRule_mana_burn", true, false) as CheckButton
	var revocable := setup.find_child("TableRule_attackers_revocable", true, false) as CheckButton
	assert_true(burn.button_pressed)
	assert_true(prevention.button_pressed)
	assert_false(revocable.button_pressed, "1997 never let an attacker step back")
	# Choosing the Custom row is a readout, not a command.
	preset.select(preset.item_count - 1)
	preset.item_selected.emit(preset.item_count - 1)
	assert_eq(setup.value(), _fifth_thirty())
	assert_eq(preset.get_item_text(preset.selected), "1997 — Fifth Edition")
	# Remembered on this device: a second editor opens the same table.
	assert_eq(SgTableRulesSetup.remembered(), _fifth_thirty())
	assert_eq(Settings.get_value(SgTableRulesSetup.KEY, {}), _fifth_thirty())
	var again := SgTableRulesSetup.new()
	add_child_autofree(again)
	again.build()
	assert_eq(again.value(), _fifth_thirty())
	# Standard table clears the memory so a fresh file stays as it was.
	var standard := setup.find_child("TableStandard", true, false) as Button
	standard.pressed.emit()
	assert_eq(setup.value(), SgTableRules.standard())
	assert_eq(preset.get_item_text(preset.selected), "Modern rules, mana burn on")
	assert_true(burn.button_pressed)
	assert_false(prevention.button_pressed)
	assert_true(revocable.button_pressed)
	assert_eq(life.value, 20.0)
	assert_false(Settings.has_value(SgTableRulesSetup.KEY))
	assert_eq(SgTableRulesSetup.remembered(), SgTableRules.standard())
	# A damaged memory is the standard table too.
	Settings.set_value(SgTableRulesSetup.KEY, {"life": 999})
	assert_eq(SgTableRulesSetup.remembered(), SgTableRules.standard())


func _lobby() -> SgLobby:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var lobby := SgLobby.new()
	viewport.add_child(lobby)
	return lobby


func _button(root: Node, text: String) -> Button:
	for node in root.find_children("*", "Button", true, false):
		if node.text == text and node.is_visible_in_tree(): return node
	assert_true(false, "missing visible button: " + text)
	return null


func test_the_host_page_and_the_tournament_setup_carry_the_editor_into_their_commands() -> void:
	SgTableRulesSetup.remember(_fifth_thirty())
	var lobby := _lobby()
	lobby._show_page("host")
	for i in 4: await get_tree().process_frame
	var readout := lobby.find_child("HostRulesReadout", true, false) as Label
	assert_not_null(readout)
	if readout == null: return
	assert_true(readout.is_visible_in_tree(), "the table's rules are front and centre")
	assert_eq(readout.text, "1997 — Fifth Edition  ·  30 life", "the host page opens the remembered table")
	assert_false(lobby._window_open())
	var change := _button(lobby, "Table rules…")
	if change == null: return
	change.pressed.emit()
	for i in 3: await get_tree().process_frame
	assert_true(SgLobbyStyle.window_open(lobby._rules_window))
	var life := lobby._rules_window.find_child("TableLife", true, false) as SpinBox
	assert_true(life.is_visible_in_tree())
	life.value = 25
	assert_eq(readout.text, "1997 — Fifth Edition  ·  25 life", "the page's readout follows the editor")
	var expected := _fifth_thirty()
	expected.life = 25
	assert_eq(lobby._rules_setup.value(), expected)
	assert_eq(SgTableRulesSetup.remembered(), expected)
	lobby._show_page("home")
	assert_false(lobby._window_open())
	# The tournament setup: the same editor, its own summary, and the
	# options the organiser opens registration with.
	lobby._show_page("tournament")
	for i in 6: await get_tree().process_frame
	var panel := lobby._tournament_panel
	var summary := panel.find_child("TournamentRulesSummary", true, false) as Label
	assert_not_null(summary)
	if summary == null: return
	assert_true(summary.is_visible_in_tree())
	assert_eq(summary.text, "1997 — Fifth Edition  ·  25 life")
	assert_false(panel.find_child("TournamentRules", true, false).is_visible_in_tree(), "the editor waits in a window")
	var rules_button := _button(panel, "Table rules…")
	if rules_button == null: return
	rules_button.pressed.emit()
	for i in 3: await get_tree().process_frame
	assert_true(panel.window_open())
	assert_true(panel.find_child("TournamentRules", true, false).is_visible_in_tree())
	var standard := panel.find_child("TournamentRules", true, false).find_child("TableStandard", true, false) as Button
	standard.pressed.emit()
	assert_eq(summary.text, SgTableRules.brief(SgTableRules.standard()))
	panel.close_windows()
	# Open registration: the options the organiser hands the host carry
	# the table. The lobby's own handler would start a LAN host here, so
	# the test takes the signal instead.
	var heard: Array = []
	panel.host_requested.disconnect(lobby._host_tournament)
	panel.host_requested.connect(func(options: Dictionary, _path: String) -> void: heard.append(options))
	panel._name_edit.text = "Rules Cup"
	var open := panel.find_child("TournamentOpenRegistration", true, false) as Button
	assert_false(open.disabled, "an offline lobby may host")
	open.pressed.emit()
	for i in 2: await get_tree().process_frame
	assert_eq(heard.size(), 1, panel._notice.text)
	if heard.size() != 1: return
	assert_eq(heard[0].get("rules"), SgTableRules.standard(), "the organiser's options carry the table")
	assert_true(SgTournament.valid_config(heard[0]))
	assert_null(lobby.service)
	assert_false(lobby.client._wanted)


class SeededServer extends SgLocalServer:
	func _create_match(decks: Array, names: Array, rules: Dictionary = {}) -> SgPracticeMatch:
		return SgPracticeMatch.new(4242, decks, names, rules)


func test_a_tournament_opens_every_table_under_its_rules_and_a_checkpoint_keeps_them() -> void:
	server = SeededServer.new()
	add_child_autofree(server)
	assert_eq(server.start_lan("127.0.0.1", 0, false), OK)
	var scratch := "user://table-rules-tests/" + Crypto.new().generate_random_bytes(8).hex_encode()
	var fifth := _fifth_thirty()
	var organiser := await _client("Organiser")
	var options := {"name": "Rules Cup", "limit": 4, "wins": 1, "policy": "fixed", "rules": fifth,
		"decks": [{"name": "Knights", "cards": Array(StarterDecks.WHITE_KNIGHTS), "sideboard": []}]}
	assert_eq(server.open_tournament(options, organiser._resume, scratch), "")
	await _until(func() -> bool: return organiser.state.has("tournament"))
	_same_table(organiser.state.tournament.config.rules, fifth, "the event's view names the table")
	assert_true(SgTournamentProtocol.view(organiser.state.tournament))
	var entrants: Array = []
	for i in 2:
		var client := await _client("Entrant %d" % (i + 1))
		entrants.append(client)
		await _act(client, {"op": "t_join", "event": server.tournament.event.id})
		await _act(client, {"op": "t_ready", "event": server.tournament.event.id, "value": true})
	await _act(organiser, {"op": "t_start", "event": server.tournament.event.id})
	assert_eq(server.tournament.event.phase, "running")
	for client: SgLocalClient in entrants:
		await _act(client, {"op": "t_ready", "event": server.tournament.event.id, "value": true})
	await _until(func() -> bool: return not entrants[0].state.room.get("game", {}).is_empty())
	assert_eq(server._rooms.size(), 1)
	if server._rooms.is_empty(): return
	var room: Dictionary = server._rooms.values()[0]
	assert_eq(room.rules, fifth, "a tournament table is opened under the event's rules")
	assert_eq(room.match.game.players[0].life, 30)
	assert_eq(room.match.game.rules.preset(), "fifth")
	_same_table(entrants[0].state.room.rules, fifth, "a tournament seat sees the table")
	assert_eq(int(entrants[0].state.room.game.players[1].life), 30)
	# The checkpoint keeps the table; a restored event opens the same one.
	var path := scratch.path_join(String(server.tournament.event.id) + ".json")
	var checkpoint := SgTournamentStore.read_checkpoint(path)
	assert_true(SgTournamentProtocol.checkpoint(checkpoint))
	_same_table(checkpoint.config.get("rules", {}), fifth, "the saved event names the table")
	var old := checkpoint.duplicate(true)
	old.config.erase("rules")
	assert_true(SgTournamentProtocol.checkpoint(old), "a checkpoint from before table rules still restores (the standard table)")
	var restored := SgTournament.new()
	restored.restore(checkpoint)
	_same_table(restored.config.get("rules", {}), fifth, "a restored event keeps the table")
	await _act(entrants[1], {"op": "concede"})
	for client: SgLocalClient in clients: client.forget()
	clients.clear()
	server.stop()
	for i in 2: await get_tree().process_frame
	var dir := DirAccess.open(scratch)
	if dir != null:
		for filename in dir.get_files(): dir.remove(filename)
		DirAccess.remove_absolute(scratch)
