extends GameTest
## Public-only observations: hidden-state substitution, real engine
## casting/combat, stable public references, strict data-only parsing.
var recorder: MpnRecorder
var trace: Array = []

func before_each() -> void:
	super.before_each()
	trace = []

func after_each() -> void:
	if recorder != null: recorder.detach()
	recorder = null

func _watch() -> void:
	recorder = MpnRecorder.new(g)
	recorder.recorded.connect(func(kind: String, data: Dictionary) -> void: trace.append({"kind": kind, "data": data}))
	recorder.observe()

func _text(headers := {}) -> String:
	if headers.is_empty(): headers = MpnArchive.metadata(g, "test", "public-match", 1)
	var text := MpnCodec.header_text(headers)
	for i in trace.size(): text += MpnCodec.record_text(i + 1, trace[i].kind, trace[i].data)
	return text

func _events(kind: String) -> Array:
	return trace.filter(func(row: Dictionary) -> bool: return row.kind == kind)

func _hidden_trace(secret: String, id_offset: int) -> String:
	var game := MtgGame.new()
	game.setup([secret, secret], [secret, secret], "Player One", "Player Two", 20, 20, id_offset)
	game.deal_opening_hands(1)
	game._next_instance_id += id_offset
	var observer := MpnRecorder.new(game)
	var rows: Array = []
	observer.recorded.connect(func(kind: String, data: Dictionary) -> void: rows.append([kind, data]))
	observer.observe()
	# The private hand, opponent deck and face-down exile all differ.
	game.exile_from_hand(game.players[0].hand[0], true, 0)
	observer.observe()
	game.information_revealed.emit(0, "private look", [secret])
	observer.detach()
	return JSON.stringify(rows)

func test_different_hidden_cards_seeds_and_ids_produce_identical_public_history() -> void:
	var one := _hidden_trace("Craw Wurm", 81)
	var two := _hidden_trace("Lightning Bolt", 993)
	assert_eq(one, two)
	assert_false(one.contains("Craw Wurm"))
	assert_false(two.contains("Lightning Bolt"))
	assert_true(one.contains("Face-down card"))

func test_private_reveals_and_probe_branches_are_never_written() -> void:
	_watch()
	var count := trace.size()
	g.information_revealed.emit(0, "Private title", ["Secret Card"])
	assert_eq(trace.size(), count)
	g._probing = true
	g.information_revealed.emit(-1, "Speculative", ["Imaginary Card"])
	g.state_changed.emit()
	assert_eq(trace.size(), count)
	g._probing = false
	g.information_revealed.emit(-1, "Visible reveal", ["Forest"])
	assert_eq(_events("reveal").size(), 1)
	assert_eq(_events("reveal")[0].data.cards, ["Forest"])
	assert_false(_text().contains("Secret Card"))
	assert_false(_text().contains("Imaginary Card"))

func test_public_object_handles_distinguish_duplicates_and_retire_in_hand() -> void:
	var one := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Grizzly Bears")
	_watch()
	var before := recorder._ref(one)
	assert_eq(recorder.snapshot().objects.size(), 2)
	g.return_to_hand(one)
	recorder.observe()
	assert_eq(recorder._ref(one), "")
	g._put_on_battlefield(one, 0)
	recorder.observe()
	assert_ne(recorder._ref(one), before)
	assert_false(recorder.snapshot().objects.has(before))

func test_real_cast_targets_damage_graveyard_and_result_roundtrip() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	_watch()
	var rng_state := g.rng.state
	recorder.observe()
	assert_eq(g.rng.state, rng_state)
	assert_false(_text().contains("Lightning Bolt"), "hidden hand is not recorded")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
	assert_eq(_events("cast").size(), 1)
	var stack: Array = recorder.snapshot().stack
	assert_eq(stack.size(), 1)
	assert_eq(stack[0].targets[0].object, recorder._ref(bear))
	resolve_stack()
	assert_eq(_events("damage")[0].data.amount, 3)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	g.concede(1)
	var parsed := MpnCodec.parse(_text())
	assert_eq(parsed.error, "")
	assert_true(parsed.finished)
	assert_eq(parsed.records.back().data.result, "1-0")
	var end := MpnCodec.state_at(parsed.records, parsed.records.size() - 1)
	assert_eq(end.objects.size(), 2)
	for card in end.objects.values(): assert_eq(card.zone, "graveyard")

func test_combat_observations_keep_attacker_and_blocker_distinct() -> void:
	var attack := put_battlefield(0, "Craw Wurm")
	var block := put_battlefield(1, "Grizzly Bears")
	_watch()
	run_combat([attack.id], {block.id: attack.id})
	assert_eq(_events("attack").size(), 1)
	assert_eq(_events("block").size(), 1)
	var event: Dictionary = _events("block")[0].data
	assert_ne(event.attacker, event.blocker)
	assert_false(event.attacker.is_empty())
	assert_eq(MpnCodec.parse(_text()).error, "")

func test_headers_preserve_unicode_quotes_and_comments_without_line_injection() -> void:
	_watch()
	var headers := MpnArchive.metadata(g, "test", "public-match")
	headers["Player.P1"] = "Éowyn \"One\"\n2 result {}"
	headers.Comments = ["A friendly game; not a verified tournament record."]
	var parsed := MpnCodec.parse(_text(headers))
	assert_eq(parsed.error, "")
	assert_eq(parsed.headers["Player.P1"], headers["Player.P1"])
	assert_eq(parsed.records.size(), trace.size())
	assert_false(parsed.finished)

func test_bad_version_sequence_state_types_and_truncation_fail_closed() -> void:
	_watch()
	var text := _text()
	assert_ne(MpnCodec.parse(text.replace("MPN/0.1", "MPN/99")).error, "")
	assert_ne(MpnCodec.parse(text.replace("[Notation \"MPN/0.1\"]", "[Notation 2]")).error, "")
	assert_ne(MpnCodec.parse(text.replace("1 state", "2 state")).error, "")
	assert_ne(MpnCodec.parse(text + "2 state {\"players\":[{},{}]}\n").error, "")
	assert_ne(MpnCodec.parse(text + "2 state {\"players\":").error, "")
	assert_false(MpnCodec.valid_patch({"players": [{"hand": ["Secret"]}, {}]}))
	assert_false(MpnCodec._id("o+1", "o"))

func test_state_reconstruction_is_reversible_and_never_runs_commands() -> void:
	_watch()
	var initial := MpnCodec.state_at(trace, 0)
	g.adjust_life(0, 4)
	recorder.observe()
	var final := MpnCodec.state_at(trace, trace.size() - 1)
	assert_eq(initial.players[0].life, 20)
	assert_eq(final.players[0].life, 24)
	assert_eq(MpnCodec.state_at(trace, 0), initial)
	assert_false(MpnCodec.parse(_text()).finished)

func test_rule_revealed_cards_become_public_then_lose_their_handle() -> void:
	var card := give_hand(0, "Lightning Bolt")
	_watch()
	assert_false(_text().contains("Lightning Bolt"))
	g.players[0].hand_revealed = true
	recorder.observe()
	var handle := recorder._ref(card)
	assert_ne(handle, "")
	assert_true(_text().contains("Lightning Bolt"))
	g.players[0].hand_revealed = false
	recorder.observe()
	assert_eq(recorder._ref(card), "")
	assert_false(recorder.snapshot().objects.has(handle))
	assert_true(_text().contains("Lightning Bolt"), "public history is not erased")

func test_mana_burn_is_public_life_loss_not_damage() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.rules.mana_burn = true
	_watch()
	add_mana(0, Mtg.ManaColor.R, 2)
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	assert_eq(_events("mana_burn").size(), 1)
	assert_eq(_events("mana_burn")[0].data.amount, 2)
	assert_eq(_events("damage").size(), 0)
	assert_eq(MpnCodec.parse(_text()).error, "")

func test_portable_specification_examples_parse_and_reconstruct() -> void:
	for name in ["finished-game", "stopped-game"]:
		var text := FileAccess.get_file_as_string("res://docs/mpn-examples/" + name + ".mpn")
		assert_false(text.is_empty(), "the published example exists: " + name)
		var parsed := MpnCodec.parse(text)
		assert_eq(parsed.error, "", name)
		if parsed.error != "": continue
		assert_eq(parsed.finished, name == "finished-game")
		assert_eq(MpnCodec.parse(text.replace("\n", "\r\n")).records, parsed.records)
		assert_eq(MpnCodec.parse(text.trim_suffix("\n")).records, parsed.records)
		var first := MpnCodec.state_at(parsed.records, 0)
		var last := MpnCodec.state_at(parsed.records, parsed.records.size() - 1)
		if name == "finished-game":
			assert_eq(int(first.players[1].life), 20)
			assert_eq(int(last.players[1].life), 17, "damage caption is not applied a second time")
			assert_true(last.objects.has("o1"), "upserts retain unrelated public objects")
			assert_false(last.objects.has("o2"), "zone change retires the spell's old handle")
			assert_eq(last.objects.o3.zone, "graveyard")
			assert_eq(last.stack, [])
		else:
			assert_eq(int(first.players[0].hand), 0)
			assert_eq(int(last.players[0].hand), 1)
			assert_eq(last.objects, {}, "draw does not disclose a hidden card")
			assert_eq(parsed.records.back().kind, "close")
		assert_eq(MpnCodec.state_at(parsed.records, 0), first, "seeking back leaves snapshots intact")
