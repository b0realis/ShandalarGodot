class_name MpnRecorder
extends RefCounted
## [QoL] Neutral observer. No raw logs, RNG, deck lists, private choices,
## CardInstance.memory or engine IDs leave this boundary. Value copies only.
## This is an observational prototype, NOT a complete rules replay.

signal recorded(kind: String, data: Dictionary)
var game: MtgGame
var finished := false
var _last := {}
var _handles := {}
var _stack_handles := {}
var _next_object := 0
var _next_stack := 0

func _init(source: MtgGame) -> void:
	game = source
	game.state_changed.connect(observe)
	game.event_occurred.connect(_event)
	game.information_revealed.connect(_reveal)
	game.game_ended.connect(_ended)

func detach() -> void:
	if game == null: return
	for pair in [[game.state_changed, observe], [game.event_occurred, _event],
		[game.information_revealed, _reveal], [game.game_ended, _ended]]:
		if pair[0].is_connected(pair[1]): pair[0].disconnect(pair[1])
	game = null

func _emit(kind: String, data: Dictionary) -> void:
	if not finished: recorded.emit(kind, data.duplicate(true))

func _public_cards() -> Array:
	var out: Array = []
	for player in game.players:
		out.append_array(player.battlefield)
		out.append_array(player.graveyard)
		out.append_array(player.exile)
		out.append_array(player.ante)
		out.append_array(player.phased_out)
		for card in player.hand:
			if card.revealed_in_hand or player.hand_revealed: out.append(card)
		var top := game.revealed_top_card(player.id)
		if top != null: out.append(top)
	for item in game.stack:
		if item.kind == Mtg.StackKind.SPELL and item.card != null and not out.has(item.card): out.append(item.card)
	return out

func _sync_handles(cards: Array) -> void:
	var live := {}
	for card: CardInstance in cards:
		live[card.id] = true
		# A public-to-public move is a new object too. Battlefield stamps
		# distinguish a blink even if no intermediate state was observed.
		var stamp := "%d/%d" % [card.zone, card.layer_timestamp]
		if not _handles.has(card.id) or _handles[card.id].stamp != stamp:
			_next_object += 1
			_handles[card.id] = {"id": "o%d" % _next_object, "stamp": stamp}
	for id in _handles.keys():
		if not live.has(id): _handles.erase(id)
	var stack_live := {}
	for item in game.stack:
		stack_live[item.id] = true
		if not _stack_handles.has(item.id):
			_next_stack += 1
			_stack_handles[item.id] = "s%d" % _next_stack
	for id in _stack_handles.keys():
		if not stack_live.has(id): _stack_handles.erase(id)

func _ref(card: CardInstance) -> String:
	return "" if card == null else String(_handles.get(card.id, {}).get("id", ""))

func _card(card: CardInstance) -> Dictionary:
	var zone: String = Mtg.Zone.keys()[card.zone].to_lower()
	if card.phased_out: zone = "phased_out"
	# A face-down exiled card still carries its printed characteristics in
	# the engine. Even its type or power would disclose hidden information.
	var masked := card.face_down and zone not in ["battlefield", "phased_out", "stack"]
	var row := {"id": _ref(card), "name": "Face-down card" if card.face_down else card.data.card_name,
		"owner": card.owner_id, "controller": card.controller_id, "zone": zone,
		"face_down": card.face_down, "tapped": false if masked else card.tapped, "creature": false if masked else card.is_creature(),
		"power": 0 if masked else card.cur_power, "toughness": 0 if masked else card.cur_toughness, "damage": 0 if masked else card.damage,
		"counters": {} if masked else card.counters.duplicate(), "attached_to": "", "token": false if masked else card.is_token}
	if card.attached_to >= 0: row.attached_to = _ref(game.find_instance(card.attached_to))
	if not card.face_down:
		row["definition_set"] = card.data.set_code
		row["printing"] = String(card.get_meta(&"card_printing", ""))
		row["rules_text"] = card.data.oracle_text
		var types: Array = []
		for key in Mtg.CardType:
			if card.cur_types & Mtg.CardType[key]: types.append(String(key).to_lower())
		row["types"] = types
		row["subtypes"] = Array(card.cur_subtypes)
		var keywords: Array = []
		for key in card.cur_keywords: keywords.append(String(Mtg.Keyword.keys()[key]).to_lower())
		row["keywords"] = keywords
	return row

func _target(target: TargetRef) -> Dictionary:
	if target.is_player: return {"player": "P%d" % (target.player_id + 1), "amount": target.amount}
	if target.is_ability: return {"stack": String(_stack_handles.get(target.ability_id, "")), "amount": target.amount}
	if target.is_damage: return {"damage": "pending", "amount": target.amount}
	return {"object": _ref(game.find_instance(target.instance_id)), "amount": target.amount}

func snapshot() -> Dictionary:
	var cards := _public_cards()
	_sync_handles(cards)
	var objects := {}
	for card: CardInstance in cards: objects[_ref(card)] = _card(card)
	var players: Array = []
	for player in game.players:
		var mana := {}
		for key in Mtg.ManaColor: mana[key] = player.mana_pool.total_of(Mtg.ManaColor[key])
		players.append({"life": player.life, "poison": player.poison, "hand": player.hand.size(), "library": player.library.size(), "mana": mana})
	var stack: Array = []
	for item in game.stack:
		var row := {"id": _stack_handles[item.id], "kind": String(Mtg.StackKind.keys()[item.kind]).to_lower(),
			"controller": item.controller, "source": _ref(item.card), "targets": [],
			"name": "Ability" if item.card == null or _ref(item.card).is_empty() else ("Face-down card" if item.card.face_down else item.card.data.card_name)}
		# Provisional targets/modes are not announced until the choice is made.
		if not item.target_held:
			row["x"] = item.x_value
			row["mode"] = item.mode
			for target in item.targets: row.targets.append(_target(target))
		stack.append(row)
	var attackers: Array = []
	for id in game.combat.attackers:
		var handle := _ref(game.find_instance(id))
		if handle != "": attackers.append(handle)
	var blocks: Array = []
	for id in game.combat.blocks:
		var blocker := _ref(game.find_instance(id))
		var attacker := _ref(game.find_instance(game.combat.blocks[id]))
		if blocker != "" and attacker != "": blocks.append([blocker, attacker])
	return {"turn": game.turn_number, "active": game.active_player,
		"step": "pregame" if game.turn_number == 0 else String(Mtg.Step.keys()[game.current_step()]).to_lower(),
		"players": players, "objects": objects, "stack": stack,
		"combat": {"attackers": attackers, "blocks": blocks}}

func observe() -> void:
	if game == null or finished or game.is_probing() or game.players.size() != 2: return
	var state := snapshot()
	var patch := {}
	for key in state:
		if key != "objects" and _last.get(key) != state[key]: patch[key] = state[key]
	var changed: Array = []
	var removed: Array = []
	var old: Dictionary = _last.get("objects", {})
	for id in state.objects:
		if old.get(id) != state.objects[id]: changed.append(state.objects[id])
	for id in old:
		if not state.objects.has(id): removed.append(id)
	if not changed.is_empty() or _last.is_empty(): patch["objects"] = changed
	if not removed.is_empty(): patch["removed"] = removed
	_last = state.duplicate(true)
	if not patch.is_empty(): _emit("state", patch)

func _event(event: GameEvent) -> void:
	if finished or game.is_probing(): return
	observe()
	var data := event.data
	var body := {}
	var kind := ""
	var pid := int(data.get("player", data.get("controller", -1)))
	if pid in [0, 1]: body["player"] = "P%d" % (pid + 1)
	var card: CardInstance = data.get("instance")
	if card != null and _ref(card) != "": body["object"] = _ref(card)
	match event.type:
		Mtg.EventType.LAND_PLAYED: kind = "land"
		Mtg.EventType.SPELL_CAST: kind = "cast"
		Mtg.EventType.ABILITY_ACTIVATED: kind = "activate"
		Mtg.EventType.CARD_DRAWN:
			kind = "draw"
			body["count"] = 1
		Mtg.EventType.CARD_DISCARDED: kind = "discard"
		Mtg.EventType.ENTERS_BATTLEFIELD: kind = "enter"
		Mtg.EventType.LEAVES_BATTLEFIELD: kind = "leave"
		Mtg.EventType.DIES: kind = "die"
		Mtg.EventType.TAPPED_FOR_MANA: kind = "mana"
		Mtg.EventType.MANA_BURN:
			kind = "mana_burn"
			body["amount"] = int(data.amount)
		Mtg.EventType.BECAME_TAPPED: kind = "tap"
		Mtg.EventType.BECAME_UNTAPPED: kind = "untap"
		Mtg.EventType.REGENERATED: kind = "regenerate"
		Mtg.EventType.DECLARED_ATTACKERS:
			kind = "attack"
			body["player"] = "P%d" % (game.active_player + 1)
			body["objects"] = _last.combat.attackers.duplicate()
		Mtg.EventType.BLOCKED:
			kind = "block"
			body["attacker"] = _ref(data.attacker)
			body["blocker"] = _ref(data.blocker)
		Mtg.EventType.DAMAGE_DEALT:
			kind = "damage"
			body["amount"] = int(data.amount)
			body["source"] = _ref(data.get("source"))
			body["target"] = "P%d" % (int(data.to_player) + 1) if data.has("to_player") else _ref(data.get("to_instance"))
	if kind != "": _emit(kind, body)

func _reveal(viewer: int, _title: String, names: Array) -> void:
	if finished or game.is_probing() or viewer != -1: return
	# Titles can contain effect-authored prose; only the explicitly public
	# card names cross this boundary. Do not invent persistent hidden IDs.
	_emit("reveal", {"cards": names.duplicate()})
	observe()

func _ended(_winner: int) -> void:
	if finished or game.is_probing(): return
	observe()
	_emit("result", {"result": "1/2-1/2" if game.is_draw else ("1-0" if game.winner == 0 else "0-1")})
	finished = true
