extends GameTest
## Local protocol/referee boundaries. Tests deliberately substitute hidden state.


func _message(action: Dictionary) -> Dictionary:
	return {"v": SgProtocol.VERSION, "type": "command", "seq": 1, "room": "", "revision": 0, "action": action}


func test_lan_addresses_and_invitations_refuse_public_or_executable_inputs() -> void:
	for address in ["10.0.0.2", "172.16.0.3", "172.31.255.1", "192.168.88.2", "169.254.3.1", "127.0.0.1"]:
		assert_true(SgLanInvite.address(address), address)
	for address in [null, 123, "8.8.8.8", "172.32.0.1", "172.15.0.1", "0.0.0.0", "255.255.255.255",
		"::1", "192.168.001.1", "localhost", "https://192.168.0.1", "192.168.0.1:80", "192.168.0.1/path"]:
		assert_false(SgLanInvite.address(address), str(address))
	for invitation in ["", "sglan1:", "sglan1:@@@=", "sglan1:" + "a".repeat(8192),
		"sglan1:" + Marshalls.utf8_to_base64('{"address":"8.8.8.8"}'),
		"sglan1:" + Marshalls.utf8_to_base64("[".repeat(50))]:
		assert_true(SgLanInvite.parse(invitation).is_empty())


func test_lan_discovery_rejects_spoofed_stale_or_oversized_listings() -> void:
	var scanner := SgLanDiscovery.new()
	add_child_autofree(scanner)
	scanner.scanning = true
	scanner._nonce = "b".repeat(64)
	var response := {"v": SgProtocol.VERSION, "type": "sg-lan-host", "nonce": scanner._nonce,
		"host": {"address": "192.168.0.5", "port": 17897, "name": "Forest Fox", "access": "invitation", "tables": [],
			"fingerprint": "a".repeat(64), "rooms": 1, "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}}
	assert_true(scanner.accept_reply(response, "192.168.0.5", 100))
	assert_false(scanner.accept_reply(response, "192.168.0.6", 100), "no redirected discovery targets")
	response.nonce = "c".repeat(64)
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100), "unrelated search response")
	response.nonce = scanner._nonce
	response.host.name = "[url=bad]host[/url]"
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100))
	response.host.name = "Forest Fox"
	response.host["secret"] = "secret"
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100), "no field outside the advert's shape")
	response.host.erase("secret")
	response.host.invitation = "sglan1:AAAA"
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100), "an invitation-only host never advertises an invitation")
	response.host.erase("invitation")
	response.host.access = "everyone"
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100))
	response.host.access = "invitation"
	response.host.tables = [{"name": "Friendly duel", "decks": "own", "deck": "", "open": true, "secret": 1}]
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100), "a table row has an exact shape")
	response.host.tables = [{"name": "Friendly duel", "decks": "borrowed", "deck": "", "open": true}]
	assert_false(scanner.accept_reply(response, "192.168.0.5", 100))
	response.host.tables = [{"name": "Friendly duel", "decks": "fixed", "deck": "Knights", "open": true}]
	assert_true(scanner.accept_reply(response, "192.168.0.5", 100))
	for i in SgLanDiscovery.MAX_HOSTS + 10:
		response.host.port = 18000 + i
		scanner.accept_reply(response, "192.168.0.5", 100)
	assert_eq(scanner.hosts.size(), SgLanDiscovery.MAX_HOSTS)
	scanner.expire(100 + SgLanDiscovery.EXPIRES_MS)
	assert_true(scanner.hosts.is_empty())
	scanner.stop()


func test_server_dtos_validate_nested_shapes_before_ui_use() -> void:
	var duel := SgPracticeMatch.new(42)
	var view := duel.view(0)
	assert_true(SgViewProtocol.game(view))
	for key in view.keys():
		var broken := view.duplicate(true)
		broken.erase(key)
		assert_false(SgViewProtocol.game(broken), "required game field: " + key)
	for value in [null, [], {"players": []}, {"actor": 999}]:
		assert_false(SgViewProtocol.game(value))
	var broken := view.duplicate(true)
	broken.players[0].battlefield = [null]
	assert_false(SgViewProtocol.game(broken))
	broken = view.duplicate(true)
	broken.hand[0].name = "../../private"
	assert_false(SgViewProtocol.game(broken))
	broken = view.duplicate(true)
	broken.players[1]["hand"] = view.hand
	assert_false(SgViewProtocol.game(broken), "enemy hand is not an allowed field")
	assert_false(SgViewProtocol.valid({"type": "welcome", "v": SgProtocol.VERSION,
		"resume": "a".repeat(64), "seq": {}, "guest": "Fox"}))
	assert_false(SgViewProtocol.valid({"type": "ack", "seq": 1, "ok": "yes", "error": ""}))


func test_player_protection_crosses_the_wire_as_bounded_public_text() -> void:
	var source := put_battlefield(0, "Hill Giant")
	g.players[1].reverse_damage_sources.append(source.id)
	var match_state := SgPracticeMatch.new(42)
	match_state.game = g
	for viewer in 2:
		var view := match_state.view(viewer)
		assert_true(SgViewProtocol.game(view))
		assert_string_contains(str(view.presentation.players[1].damage_effects), "Hill Giant")
		var broken := view.duplicate(true)
		broken.presentation.players[1].damage_effects = [42]
		assert_false(SgViewProtocol.game(broken))
		broken.presentation.players[1].damage_effects = ["x".repeat(4097)]
		assert_false(SgViewProtocol.game(broken))
		broken.presentation.players[1].damage_effects = []
		for i in 65: broken.presentation.players[1].damage_effects.append("shield")
		assert_false(SgViewProtocol.game(broken))
	source.face_down = true
	assert_false(str(match_state.view(1).presentation.players[1].damage_effects).contains("Hill Giant"))


func test_text_effect_snapshots_are_public_detached_and_cleared() -> void:
	var host := put_battlefield(0, "Swamp")
	g.change_text(host, "land_type", "swamp", "island")
	host.memory["private_note"] = "SECRET library choice"
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	var cards := duel._cards(1, [host])
	assert_true(SgViewProtocol.cards(cards))
	assert_eq(cards[0].text_effects, [{"kind": "land_type", "from": "swamp", "to": "island"}])
	assert_false(JSON.stringify(cards).contains("SECRET"))
	cards[0].text_effects[0].to = "forest"
	assert_eq(host.text_changes[0].to, "island", "the snapshot cannot mutate the engine")
	host.face_down = true
	cards = duel._cards(1, [host])
	assert_true(cards[0].text_effects.is_empty(), "a masked snapshot reveals no effect history")
	assert_true(SgViewProtocol.cards(cards))
	cards[0].text_effects = [{"kind": "land_type", "from": "swamp", "to": "island"}]
	assert_false(SgViewProtocol.cards(cards), "the client also rejects masked effect history")
	host.face_down = false
	g.return_to_hand(host)
	assert_true(duel._cards(0, [host])[0].text_effects.is_empty(), "no stale reminder in another zone")


func test_text_effect_protocol_rejects_malformed_or_unbounded_records() -> void:
	var valid := [
		{"kind": "land_type", "from": "swamp", "to": "island"},
		{"kind": "color_word", "from": Mtg.ManaColor.W, "to": Mtg.ManaColor.G},
		{"kind": "mana_color", "from": Mtg.ManaColor.W, "to": Mtg.ManaColor.C},
		{"kind": "circle_color", "to": Mtg.ManaColor.G},
	]
	assert_true(SgViewProtocol.text_effects(valid))
	assert_true(SgViewProtocol.text_effects(JSON.parse_string(JSON.stringify(valid))))
	for invalid in [null, {}, [null], [{}], [{"kind": "unknown", "from": 1, "to": 2}],
		[{"kind": "land_type", "from": "swamp", "to": "../../private"}],
		[{"kind": "land_type", "from": [], "to": "island"}],
		[{"kind": "color_word", "from": true, "to": 2}],
		[{"kind": "color_word", "from": 1, "to": 3}],
		[{"kind": "color_word", "from": 1, "to": Mtg.ManaColor.C}],
		[{"kind": "mana_color", "from": 1, "to": 1.5}],
		[{"kind": "circle_color", "to": 1, "private": "secret"}],
		[{"kind": "circle_color", "to": NAN}]]:
		assert_false(SgViewProtocol.text_effects(invalid), str(invalid))
	var oversized: Array = []
	oversized.resize(SgProtocol.MAX_CARDS + 1)
	oversized.fill(valid[0])
	assert_false(SgViewProtocol.text_effects(oversized))
	var old_hello := {"v": SgProtocol.VERSION - 1, "type": "hello", "access": "0".repeat(64),
		"resume": "", "nickname": "", "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}
	assert_false(SgProtocol.valid(old_hello), "old clients cannot silently drop reminder fields")


func test_temporary_names_are_bounded_display_text_not_credentials() -> void:
	var hello := {"v": SgProtocol.VERSION, "type": "hello", "access": "0".repeat(64),
		"resume": "", "nickname": "", "build": SgCompatibility.fingerprint(), "stamp": SgCompatibility.stamp()}
	for value in ["", "Silver Fox", "Forest-7", "a".repeat(SgProtocol.NICKNAME_LIMIT)]:
		hello.nickname = value
		assert_true(SgProtocol.valid(hello), str(value))
	for value in [123, null, true, " ", " Silver", "Silver ", "a".repeat(21),
		"Fox\nGuest 1", "Fox\t", "Fox (Guest 1)", "[b]Fox[/b]", "Föx"]:
		hello.nickname = value
		assert_false(SgProtocol.valid(hello), str(value))
	hello.nickname = "Fox"
	hello.erase("nickname")
	assert_false(SgProtocol.valid(hello), "old handshake cannot silently omit the new field")


func test_compatibility_stamp_is_bounded_and_names_the_first_difference() -> void:
	var mine := SgCompatibility.stamp()
	assert_true(SgCompatibility.valid_stamp(mine))
	assert_eq(mine.game, ProjectSettings.get_setting("application/config/version", ""))
	assert_eq(mine.rules, SgCompatibility.RULES_REVISION)
	assert_eq(SgCompatibility.difference(mine, mine), "")
	var hello := {"v": SgProtocol.VERSION, "type": "hello", "access": "0".repeat(64),
		"resume": "", "nickname": "", "build": SgCompatibility.fingerprint(), "stamp": mine}
	assert_true(SgProtocol.valid(hello))
	hello.stamp = {"game": "0.32.0", "rules": "r", "packs": []}
	assert_true(SgProtocol.valid(hello), "a minimal readable stamp")
	for bad in [null, {}, "0.32.0", {"game": "0.32.0", "rules": "r", "packs": "pack-1"},
		{"game": "0.32.0", "rules": "r", "packs": [], "extra": 1}, {"game": "", "rules": "r", "packs": []},
		{"game": "0.32.0\n", "rules": "r", "packs": []}, {"game": "0.32.0", "rules": "r", "packs": [1]},
		{"game": "0.32.0", "rules": "r", "packs": ["[b]x[/b]"]}, {"game": "0.32.0", "rules": "r", "packs": ["a".repeat(13)]}]:
		var probe := hello.duplicate(true)
		probe.stamp = bad
		assert_false(SgProtocol.valid(probe), str(bad))
	var oversized := mine.duplicate(true)
	oversized.packs = []
	for i in SgCompatibility.MAX_PACKS + 1: oversized.packs.append("pack-%d" % i)
	assert_false(SgCompatibility.valid_stamp(oversized))
	var older := {"game": "0.31.0", "rules": mine.rules, "packs": mine.packs.duplicate()}
	var why := SgCompatibility.difference(mine, older, "This host")
	assert_string_contains(why, "This host runs Shandalar 0.31.0")
	assert_string_contains(why, "you run " + String(mine.game))
	var more_packs := {"game": mine.game, "rules": mine.rules, "packs": mine.packs + ["pack-9"]}
	assert_string_contains(SgCompatibility.difference(mine, more_packs), "The host has Pack 9 enabled; you do not")
	var fewer := {"game": mine.game, "rules": mine.rules, "packs": ["pack-8"]}
	var mine_with := {"game": mine.game, "rules": mine.rules, "packs": ["pack-7", "pack-8"]}
	assert_string_contains(SgCompatibility.difference(mine_with, fewer), "You have Pack 7 enabled; the host does not")
	var other_rules := {"game": mine.game, "rules": "sgmanalink-packs-2000-01-01-1", "packs": mine.packs.duplicate()}
	assert_string_contains(SgCompatibility.difference(mine, other_rules), "different build")
	assert_string_contains(SgCompatibility.difference(mine, {}), "unknown game build")
	assert_string_contains(SgCompatibility.catalogue_mismatch(), "card catalogue differs")
	assert_eq(SgCompatibility.pack_labels(["pack-1", "pack-3"]), "Packs 1, 3")
	assert_eq(SgCompatibility.pack_labels([]), "no card packs")
	var advert := {"address": "192.168.0.5", "port": 17897, "name": "Forest Fox", "access": "invitation", "tables": [],
		"fingerprint": "a".repeat(64), "rooms": 1, "build": SgCompatibility.fingerprint(), "stamp": mine}
	assert_true(SgLanDiscovery.valid_advert(advert))
	advert.erase("stamp")
	assert_false(SgLanDiscovery.valid_advert(advert), "an advert without the readable stamp is not this protocol")
	advert.stamp = mine
	advert.build = "zz"
	assert_false(SgLanDiscovery.valid_advert(advert))
	advert.build = SgCompatibility.fingerprint()
	advert.stamp = oversized.duplicate(true)
	advert.stamp.packs.resize(SgCompatibility.MAX_PACKS)
	advert.tournament = "T".repeat(SgProtocol.NICKNAME_LIMIT)
	# The worst case is an open host: its invitation, a real certificate
	# inside, and every table named at full length with an assigned deck.
	var crypto := Crypto.new()
	var key := crypto.generate_rsa(2048)
	var certificate := crypto.generate_self_signed_certificate(key, "CN=" + SgLanInvite.COMMON_NAME + ",O=SGManalink,C=XX", "20200101000000", "20400101000000")
	var pem := SgLanInvite.public_pem(certificate)
	advert.access = "open"
	advert.fingerprint = pem.sha256_text()
	advert.invitation = SgLanInvite.create("192.168.0.5", 17897, "a".repeat(64), pem)
	for i in SgLocalServer.MAX_ROOMS:
		advert.tables.append({"name": "T".repeat(32), "decks": "fixed", "deck": "D".repeat(128), "open": i % 2 == 0})
	assert_true(SgLanDiscovery.valid_advert(advert))
	assert_true(SgLanDiscovery.open_host(advert))
	var scanner := SgLanDiscovery.new()
	scanner._nonce = "n".repeat(64)
	scanner.scanning = true
	var reply := JSON.stringify({"v": SgProtocol.VERSION, "type": "sg-lan-host", "nonce": scanner._nonce, "host": advert}).to_ascii_buffer()
	assert_true(reply.size() <= SgLanDiscovery.MAX_PACKET, "the worst-case reply fits one discovery packet: %d" % reply.size())
	# The reply nests root > host > stamp > packs: the discovery decoder must allow that depth.
	assert_true(scanner.accept_reply(SgProtocol.decode_payload(reply, 4), "192.168.0.5", 0), "a full reply round-trips the discovery decoder")
	scanner.free()


func test_protocol_refuses_unknown_fields_methods_types_and_unbounded_payloads() -> void:
	assert_true(SgProtocol.valid(_message({"op": "pass"})))
	for action in [{"op": "win"}, {"op": "pass", "pid": 1},
		{"op": "play", "card": 123}, {"op": "ready", "value": 1},
		{"op": "damage", "points": [["c1", -1]]},
		{"op": "block", "pairs": [["c1", "c2", "c3"]]},
		{"op": "host", "name": "[url=bad]spoof[/url]", "decks": "own", "deck": {}}]:
		assert_false(SgProtocol.valid(_message(action)), str(action))
	for value in [-1, 0, 1.5, INF, NAN, "1", true]:
		var message := _message({"op": "pass"})
		message.seq = value
		assert_false(SgProtocol.valid(message), str(value))
	for text in ["[]", "{}", "{broken", "[".repeat(100), " ".repeat(32769)]:
		assert_eq(SgProtocol.decode(text.to_utf8_buffer()), {})
	assert_eq(SgProtocol.decode(PackedByteArray([255, 254])), {})
	var decoded := SgProtocol.decode(JSON.stringify(_message({"op": "pass"})).to_utf8_buffer())
	assert_true(SgProtocol.valid(decoded), "JSON integer-valued floats are accepted")
	assert_eq(decoded.action, {"op": "pass"})


func test_fixed_practice_pool_has_only_the_supported_card_behaviors() -> void:
	var duel := SgPracticeMatch.new(42)
	assert_eq(duel.game.players[0].deck_names.size(), 40)
	for name in SgPracticeMatch.CREATURES:
		var card := CardRegistry.get_card(name)
		assert_not_null(card)
		assert_true(card.activated_abilities.is_empty(), name)
		assert_true(card.triggered_abilities.is_empty(), name)
		assert_true(card.spell_effects.is_empty(), name)
	assert_true(duel.game.rules.mana_burn)
	assert_true(duel.game.rules.free_damage_assignment)


func test_views_do_not_change_with_opponent_hand_library_order_or_rng() -> void:
	var duel := SgPracticeMatch.new(42)
	var baseline := JSON.stringify(duel.view(0))
	duel.game.players[1].hand[0].data = CardRegistry.get_card("Black Lotus")
	duel.game.players[0].library.reverse()
	duel.game.players[1].library.reverse()
	duel.game.rng.randi()
	assert_eq(JSON.stringify(duel.view(0)), baseline)
	assert_false(baseline.contains("Black Lotus"))
	assert_false(baseline.contains("seed"))
	assert_false(baseline.contains("rng"))
	assert_false(baseline.contains("deck_names"))
	assert_false(duel.view(0).players[1].has("hand"))
	assert_false(duel.view(0).players[0].has("library"))
	assert_eq(duel.view(-1), {})
	duel.game.adjust_life(1, -1)
	assert_ne(JSON.stringify(duel.view(0)), baseline, "public information still updates")


func test_view_is_detached_and_private_handles_cannot_name_opponent_cards() -> void:
	var duel := SgPracticeMatch.new(42)
	var view := duel.view(0)
	view.players[0].life = 999
	view.hand.clear()
	assert_eq(duel.game.players[0].life, 20)
	assert_eq(duel.game.players[0].hand.size(), 7)
	assert_false(duel.view(0).hand[0].id is int)
	assert_ne(duel.act(0, {"op": "play", "card": "999"}), "")


func test_opening_choices_and_stale_hand_handles_are_enforced() -> void:
	var duel := SgPracticeMatch.new(42)
	var actor := duel.first_player
	var old := String(duel.view(actor).hand[0].id)
	assert_ne(duel.act(1 - actor, {"op": "keep"}), "")
	assert_eq(duel.act(actor, {"op": "mulligan"}), "")
	assert_null(duel._card(actor, old))
	assert_eq(duel.view(actor).hand.size(), 6)
	assert_eq(duel.act(actor, {"op": "keep"}), "")
	assert_eq(duel.act(1 - actor, {"op": "keep"}), "")
	assert_false(duel.game.mulligan_open)
	assert_ne(duel.act(actor, {"op": "mulligan"}), "")


func test_referee_uses_real_mana_casting_priority_and_concession() -> void:
	var duel := SgPracticeMatch.new(42)
	# The GameTest harness is the only place allowed to construct test state.
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.rules.free_damage_assignment = true
	advance_to_step(Mtg.Step.MAIN1)
	var forest := give_hand(0, "Forest")
	var bear := give_hand(0, "Grizzly Bears")
	var other_forest := put_battlefield(0, "Forest")
	var view := duel.view(0)
	assert_eq(duel.act(0, {"op": "play", "card": duel._handle(0, forest)}), "")
	assert_false(duel._playable(0, bear), "not enough floating mana yet")
	assert_ne(duel.act(0, {"op": "play", "card": duel._handle(0, bear)}), "")
	assert_eq(duel.act(0, {"op": "tap", "card": duel._handle(0, forest)}), "")
	assert_eq(duel.act(0, {"op": "tap", "card": duel._handle(0, other_forest)}), "")
	assert_true(duel._playable(0, bear))
	assert_false(duel._playable(1, bear), "opposing seat gets no private playability hint")
	assert_eq(duel.act(0, {"op": "play", "card": duel._handle(0, bear)}), "")
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(duel.act(0, {"op": "pass"}), "")
	assert_ne(duel.act(0, {"op": "pass"}), "", "wrong seat cannot act")
	assert_eq(duel.act(1, {"op": "pass"}), "")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_ne(view.hand.size(), duel.view(0).hand.size())
	assert_eq(duel.act(1, {"op": "concede"}), "")
	assert_eq(duel.view(0).winner, 0)


func test_referee_exposes_combat_damage_only_to_its_assigner() -> void:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.rules.free_damage_assignment = true
	var wurm := put_battlefield(0, "Craw Wurm")
	var bear1 := put_battlefield(1, "Grizzly Bears")
	var bear2 := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(duel.act(0, {"op": "attack", "cards": [duel._handle(0, wurm)]}), "")
	for i in 8:
		if g.awaiting_blockers:
			break
		assert_eq(duel.act(g.priority_player, {"op": "pass"}), "")
	assert_true(g.awaiting_blockers)
	assert_eq(duel.act(1, {"op": "block", "pairs": [
		[duel._handle(1, bear1), duel._handle(1, wurm)],
		[duel._handle(1, bear2), duel._handle(1, wurm)]]}), "")
	for i in 8:
		if g.awaiting_damage_assignment:
			break
		assert_eq(duel.act(g.priority_player, {"op": "pass"}), "")
	assert_true(g.awaiting_damage_assignment)
	assert_eq(duel.view(0).damage_request.amount, 6)
	assert_eq(duel.view(1).damage_request, {})
	assert_ne(duel.act(1, {"op": "damage", "points": []}), "")
	assert_ne(duel.act(0, {"op": "damage", "points": [[duel._handle(0, bear1), 99]]}), "")
	assert_eq(duel.act(0, {"op": "damage", "points": [
		[duel._handle(0, bear1), 3], [duel._handle(0, bear2), 3]]}), "")
	assert_eq(bear1.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear2.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "simultaneous combat damage uses the real engine")


func test_cleanup_requires_exactly_the_owners_distinct_cards() -> void:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	for i in 9:
		give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.CLEANUP)
	assert_true(g.awaiting_discard)
	var hand: Array = duel.view(0).hand
	assert_eq(g.discard_count, 2)
	assert_ne(duel.act(1, {"op": "discard", "cards": []}), "")
	assert_ne(duel.act(0, {"op": "discard", "cards": [hand[0].id, hand[0].id]}), "")
	assert_eq(duel.act(0, {"op": "discard", "cards": [hand[0].id, hand[1].id]}), "")
	assert_eq(g.players[0].hand.size(), 7)


func test_protocol_20_pins_the_land_allowance_the_public_division_and_the_dropped_cost() -> void:
	assert_eq(SgProtocol.SUBPROTOCOL, "sgmanalink-local-v%d" % SgProtocol.VERSION)
	var duel := SgPracticeMatch.new(42)
	var view := duel.view(0)
	assert_true(SgViewProtocol.game(view))
	# THE LAND DROP crosses as the whole rule — the turn's counter AND the
	# seat's allowance — because that is what land_drop_available reads.
	# Neither half is optional, and a negative allowance is not a number
	# of land plays.
	for row in view.presentation.players:
		assert_eq(int(row.extra_lands), 0)
		assert_false(row.unlimited_lands)
	for change in [["erase", "extra_lands"], ["erase", "unlimited_lands"],
		["extra_lands", -1], ["extra_lands", "many"], ["unlimited_lands", 1]]:
		var broken := view.duplicate(true)
		if change[0] == "erase": broken.presentation.players[0].erase(change[1])
		else: broken.presentation.players[0][change[0]] = change[1]
		assert_false(SgViewProtocol.game(broken), str(change))
	# A FACE no longer carries its printed cost: nothing read it — the
	# client prices a named card off its own registry — and an unknown key
	# is not this protocol's face.
	assert_false(view.hand[0].has("cost"))
	var extra := view.duplicate(true)
	extra.hand[0]["cost"] = "{1}{G}"
	assert_false(SgViewProtocol.game(extra), "a face with a cost is refused")
	# THE PUBLIC HALF OF A DAMAGE DIVISION reaches both seats. Without the
	# amount or the targets the watching board could paint no group at all.
	var division := {"source": "c1", "assigner": 0, "amount": 6,
		"targets": ["c2", "c3"], "trample": false, "assigned": [["c2", 3]]}
	var shape: Dictionary = view.presentation.duplicate(true)
	shape.assignment = division.duplicate(true)
	assert_true(SgViewProtocol.presentation(shape))
	for key in division.keys():
		shape.assignment = division.duplicate(true)
		shape.assignment.erase(key)
		assert_false(SgViewProtocol.presentation(shape), "required assignment field: " + key)
	for bad in [{"amount": -1}, {"amount": "six"}, {"targets": "c2"}, {"targets": [42]}]:
		shape.assignment = division.duplicate(true)
		shape.assignment.merge(bad, true)
		assert_false(SgViewProtocol.presentation(shape), str(bad))
	# The regeneration window's doomed list is bounded handles, and the key
	# is required whether or not a window is open.
	shape = view.presentation.duplicate(true)
	assert_eq(shape.doomed, [])
	shape.doomed = ["c2"]
	assert_true(SgViewProtocol.presentation(shape))
	for bad_value in [[42], "c2", [""]]:
		shape.doomed = bad_value
		assert_false(SgViewProtocol.presentation(shape), str(bad_value))
	shape = view.presentation.duplicate(true)
	shape.erase("doomed")
	assert_false(SgViewProtocol.presentation(shape))
