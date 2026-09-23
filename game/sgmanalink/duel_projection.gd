class_name SgDuelProjection
extends MtgGame
## Render-only implementation of the duel screen's game interface. There is
## no setup, resolution, shuffle or simulation here. Actions are messages;
## only a validated, seat-filtered host view can change the displayed state.

signal action_requested(action: Dictionary)
var _damage_effect_labels: Array = [[], []]
var seat := 0
var locked := false
var view: Dictionary = {}
var presentation: Dictionary = {}
var faces: Dictionary = {}
var details: Dictionary = {}
var _local_ids: Dictionary = {}
var _next_local_id := 1
var _seen: Dictionary = {}
var _block_matrix: Dictionary = {}
var _used_handles: Dictionary = {}
var _hidden_slots: Array = [{}, {}]
var _journal_serial := 0


func player_damage_effects(pid: int) -> Array[String]:
	var out: Array[String] = []
	out.assign(_damage_effect_labels[pid])
	return out


func local_seat(remote: int) -> int:
	return -1 if remote < 0 else (0 if remote == seat else 1)


func all_battlefield() -> Array[CardInstance]:
	var cards: Array[CardInstance] = []
	for player in players: cards.append_array(player.battlefield)
	return cards


func local_id(handle: String) -> int:
	if handle.is_empty(): return -1
	_used_handles[handle] = true
	if not _local_ids.has(handle):
		_local_ids[handle] = _next_local_id
		_next_local_id += 1
	return _local_ids[handle]


func handle(id: int) -> String:
	var card := find_instance(id)
	return String(card.get_meta("sg_handle", "")) if card != null else ""


func ingest(room: Dictionary) -> void:
	seat = int(room.seat)
	view = room.game
	presentation = view.presentation
	untap_caps = {"limited": true} if presentation.untap_capped else {}
	faces.clear()
	details.clear()
	_seen.clear()
	_used_handles.clear()
	_block_matrix.clear()
	for row in presentation.blockable:
		var columns := {}
		for column in row[1]: columns[column] = true
		_block_matrix[row[0]] = columns
	if players.is_empty():
		players = [MtgPlayer.new(0, "", 20), MtgPlayer.new(1, "", 20)]
	for key in SgDuelPresentation.RULES: rules.set(key, presentation.rules[key])
	# Both land-drop containers are rebuilt from the view every present, the
	# way the host's own recalculation rebuilds them, so a grant that has
	# left the battlefield never lingers as a stale allowance here.
	extra_land_plays.clear()
	unlimited_land_plays.clear()
	for remote in 2:
		var pid := local_seat(remote)
		var p := players[pid]
		var dto: Dictionary = view.players[remote]
		p.player_name = room.names[remote]
		p.life = int(dto.life)
		p.poison = int(presentation.players[remote].poison)
		p.lands_played_this_turn = int(presentation.players[remote].lands)
		extra_land_plays[pid] = int(presentation.players[remote].extra_lands)
		if presentation.players[remote].unlimited_lands: unlimited_land_plays[pid] = true
		p.hand_revealed = presentation.players[remote].hand_revealed
		_damage_effect_labels[pid] = presentation.players[remote].damage_effects.duplicate()
		p.deck_names.assign(room.deck.cards if pid == 0 and not room.deck.is_empty() else [])
		p.mana_pool.clear()
		var colors := [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]
		for i in 6: p.mana_pool.add(colors[i], int(dto.mana_colors[i]))
		p.battlefield.assign(_zone(dto.battlefield, Mtg.Zone.BATTLEFIELD))
		p.graveyard.assign(_zone(dto.graveyard, Mtg.Zone.GRAVEYARD))
		p.exile.assign(_zone(dto.exile, Mtg.Zone.EXILE))
		p.ante.assign(_zone(dto.ante, Mtg.Zone.ANTE))
		p.hand.assign(_zone(view.hand if pid == 0 else dto.revealed, Mtg.Zone.HAND))
		p.hand.append_array(_hidden_zone(pid, Mtg.Zone.HAND, maxi(0, int(dto.hand_count) - p.hand.size())))
		p.library.assign(_hidden_zone(pid, Mtg.Zone.LIBRARY, int(dto.library_count)))
		p.top_card_revealed = not dto.top.is_empty()
		if p.top_card_revealed and not p.library.is_empty() and CardRegistry.has_card(dto.top):
			p.library[-1] = CardInstance.new(CardRegistry.get_card(dto.top), -1, pid)
			p.library[-1].zone = Mtg.Zone.LIBRARY
		mulligan_kept[pid] = dto.kept
	for row in presentation.cards:
		details[row.id] = row
		var card := find_instance(local_id(row.id))
		if card == null: continue
		for key in SgDuelPresentation.FLAGS: card.set(key, row.flags[key])
	# BOTH ENDS of every attachment, because the board reads both: a card
	# whose attached_to is set gets no slot of its own, and what draws it
	# again is its HOST's `attachments`. Linking only the aura's own end
	# left an enchanted creature's Aura on nobody's board at either seat.
	for key in faces:
		var card := find_instance(local_id(key))
		card.attachments.clear()
		card.attached_to = local_id(faces[key].attached)
	for key in faces:
		var card := find_instance(local_id(key))
		var host := find_instance(card.attached_to)
		if host != null and host != card: host.attachments.append(card.id)
	stack.clear()
	for i in view.stack.size():
		var item := StackItem.new()
		var row: Dictionary = presentation.chain[i]
		var label: Dictionary = view.stack[i]
		item.id = local_id(row.id)
		item.kind = int(row.kind)
		item.controller = local_seat(int(label.controller))
		item.x_value = int(label.x)
		item.description = label.details
		if not label.targets.is_empty():
			item.description += "\n" + "; ".join(label.targets)
		item.card = _face(row.face, Mtg.Zone.STACK) if not row.face.is_empty() else _unknown(item.controller, Mtg.Zone.STACK, label.name)
		for ref in row.refs: item.targets.append(target(ref))
		stack.append(item)
	combat.clear()
	for key in faces:
		if faces[key].attacking: combat.attackers[local_id(key)] = true
	for band in presentation.bands:
		var ids: Array = []
		for key in band: ids.append(local_id(key))
		combat.bands.append(ids)
	for pair in presentation.blocks:
		var blocker := local_id(pair[0])
		# An empty target maps to -1: still blocking, but its attacker left.
		if not combat.blocks.has(blocker): combat.blocks[blocker] = local_id(pair[1])
		else:
			if not combat.extra_blocks.has(blocker): combat.extra_blocks[blocker] = []
			combat.extra_blocks[blocker].append(local_id(pair[1]))
	for key in presentation.blocked: combat.blocked_attackers[local_id(key)] = true
	damage_pending.clear()
	for row in presentation.packets:
		var packet := DamagePacket.new()
		packet.id = local_id(row.id)
		packet.source = find_instance(local_id(row.source))
		packet.target = target(row.target)
		packet.amount = int(row.amount)
		packet.is_combat = row.combat
		damage_pending.append(packet)
	active_player = local_seat(int(view.active))
	priority_player = local_seat(int(presentation.priority))
	turn_number = int(view.turn)
	_step_index = Mtg.STEP_ORDER.find(Mtg.Step.get(view.step, Mtg.Step.UNTAP))
	mulligan_open = view.mode == "opening"
	awaiting_attackers = view.mode == "attack"
	awaiting_blockers = view.mode == "block"
	block_chooser_override = local_seat(int(view.actor)) if awaiting_blockers else -1
	awaiting_discard = view.mode == "discard"
	discard_count = int(view.discard_count)
	awaiting_damage_assignment = view.mode == "damage"
	awaiting_damage_prevention = presentation.prevention
	awaiting_regeneration = presentation.regeneration
	# The creatures the open regeneration window is about, so this seat's
	# own damage_prevention_request names them as the host's does. Cleared
	# first: the list belongs to one window and no window after it.
	regeneration_candidates.clear()
	for key in presentation.doomed: regeneration_candidates.append(local_id(key))
	awaiting_choice = null
	if view.mode == "choice":
		awaiting_choice = PlayerChoice.new(PlayerChoice.Kind.OPTION, local_seat(int(view.actor)), "Waiting for opponent's choice.")
		if not view.choice.is_empty():
			awaiting_choice.prompt = view.choice.prompt
			awaiting_choice.source = view.choice.source
			awaiting_choice.options.assign(view.choice.options)
			awaiting_choice.count = int(view.choice.count)
			awaiting_choice.is_cost = view.choice.cancel
			for info in view.choice.information:
				awaiting_choice.information.append({"viewer": 0, "title": info.title, "cards": info.cards.duplicate()})
	game_over = view.mode == "finished"
	winner = local_seat(int(view.winner))
	is_draw = view.draw
	# No stale hidden card may survive a bounce, shuffle or concealment.
	for id in _instances.keys():
		if not _seen.has(id): _instances.erase(id)
	for key in _local_ids.keys():
		if not _used_handles.has(key): _local_ids.erase(key)
	_ingest_journal(view.journal)


func _ingest_journal(entries: Array) -> void:
	for entry in entries:
		if int(entry.serial) <= _journal_serial: continue
		var meta := {"turn": int(entry.turn), "step": int(entry.step), "pid": local_seat(int(entry.pid)),
			"kind": entry.kind, "card": "", "colors": 0}
		if int(entry.serial) > _journal_serial + 1:
			log_lines.append("Earlier online history is no longer available on the host.")
			log_meta.append(meta.duplicate())
			log_appended.emit(log_lines[-1], meta)
		_journal_serial = int(entry.serial)
		log_lines.append(entry.text)
		log_meta.append(meta)
		log_appended.emit(entry.text, meta)


func _hidden_zone(pid: int, zone: int, count: int) -> Array:
	# These are interchangeable UI slots, all id -1; never hidden identities.
	var slots: Array = _hidden_slots[pid].get(zone, [])
	while slots.size() > count: slots.pop_back()
	while slots.size() < count: slots.append(_unknown(pid, zone))
	_hidden_slots[pid][zone] = slots
	return slots


func _zone(cards: Array, zone: int) -> Array:
	var result: Array = []
	for card in cards: result.append(_face(card, zone))
	return result


func _face(dto: Dictionary, zone: int) -> CardInstance:
	var id := local_id(dto.id)
	var previous: CardInstance = _instances.get(id)
	var retained_zone := previous.zone if previous != null else zone
	var card := SgCardPresentation.make(dto, local_seat(int(dto.owner)), zone, previous)
	card.id = id
	card.zone = zone if not _seen.has(id) else retained_zone
	card.owner_id = local_seat(int(dto.owner))
	card.controller_id = local_seat(int(dto.controller))
	card.revealed_in_hand = card.owner_id != 0 and zone == Mtg.Zone.HAND
	card.exile_playable_by = 0 if dto.exile_playable else -1
	card.set_meta("sg_handle", dto.id)
	card.memory.clear()
	if not dto.chosen.is_empty() and not card.data.chosen_type_key.is_empty():
		card.memory[card.data.chosen_type_key] = "" if dto.chosen == "No creatures" else dto.chosen.to_lower()
	_instances[id] = card
	_seen[id] = true
	faces[dto.id] = dto
	return card


func _unknown(pid: int, zone: int, label := "Unknown card") -> CardInstance:
	var card := CardInstance.new(CardData.new(label, "", 0), -1, pid)
	card.zone = zone
	card.face_down = label == "Unknown card"
	return card


func target(dto: Dictionary) -> TargetRef:
	var ref := TargetRef.new()
	if dto.is_empty(): return ref
	match dto.kind:
		"player": ref = TargetRef.player(local_seat(int(dto.id)))
		"card": ref.instance_id = local_id(dto.id)
		"ability":
			ref.is_ability = true
			ref.ability_id = local_id(dto.id)
		"damage":
			ref.is_damage = true
			ref.packet_id = local_id(dto.id)
	ref.amount = int(dto.amount)
	return ref


func send(action: Dictionary) -> String:
	if locked: return "Waiting for the host."
	locked = true
	action_requested.emit(action)
	return ""


func play_land(_pid: int, inst: CardInstance) -> String:
	return send({"op": "play", "card": handle(inst.id)})


## A colour never crosses the wire: the host's own plan is what tells a
## Fellwar Stone its colour (SgDuelActions.autopay), and a hand tap from
## this seat is asked through the host's question like any other.
func tap_for_mana(_pid: int, inst: CardInstance, ability_index := 0, _chosen := -1) -> String:
	return send({"op": "mana", "card": handle(inst.id), "index": ability_index})


func pass_priority(_pid: int) -> String:
	return send({"op": "pass"})


func declare_attackers(_pid: int, ids: Array, bands: Array = []) -> String:
	var members: Array = []
	for band in bands: members.append(_handles_for(band))
	return send({"op": "attack_bands", "cards": _handles_for(ids), "bands": members})


func _handles_for(ids: Array) -> Array:
	var result: Array = []
	for id in ids: result.append(handle(int(id)))
	return result


func declare_blockers(_pid: int, blocks: Dictionary) -> String:
	var pairs: Array = []
	for id in blocks:
		for attacker in blocks[id]: pairs.append([handle(id), handle(attacker)])
	return send({"op": "block", "pairs": pairs})


func assign_combat_damage(_pid: int, split: Dictionary) -> String:
	var points: Array = []
	for id in split: points.append(["player" if id == DAMAGE_TO_PLAYER else handle(id), split[id]])
	return send({"op": "damage", "points": points})


func discard_to_hand_size(_pid: int, cards: Array) -> String:
	var ids: Array = []
	for card in cards: ids.append(handle(card.id))
	return send({"op": "discard", "cards": ids})


func answer_choice(value: Variant) -> String:
	return send({"op": "choice", "picks": value if value is Array else [value]})


func cancel_choice() -> String:
	return send({"op": "cancel"})


func concede(_pid: int) -> String:
	return send({"op": "concede"})


func cast_spell(_pid: int, _inst: CardInstance, _targets: Array = [], _x_value := 0, _mode := 0) -> String:
	return "Use a host-authorized announcement."


func activate_ability(_pid: int, _inst: CardInstance, _index: int, _targets: Array = [], _x_value := 0) -> String:
	return "Use a host-authorized announcement."


## The public half of the division under way, which is all of it the board
## needs: the WATCHING seat gets no `damage_request` of its own and used
## to read an empty request here, so the groups the assigner had already
## confirmed were painted on nobody's board. Only the per-target "lethal"
## hint stays private, and the board does not draw it.
func damage_assignment_request() -> Dictionary:
	var a: Dictionary = presentation.get("assignment", {})
	if a.is_empty(): return {}
	var targets: Array = []
	for key in a.targets: targets.append(local_id(key))
	var assigned := {}
	for pair in a.assigned: assigned[local_id(pair[0])] = int(pair[1])
	return {"source": find_instance(local_id(a.source)), "assigner": local_seat(int(a.assigner)),
		"amount": int(a.amount), "targets": targets, "trample": a.trample, "assigned": assigned}


func attack_refusal(card: CardInstance) -> String:
	return "" if presentation.attackable.has(handle(card.id)) else "This creature cannot attack."


func block_refusal(blocker: CardInstance, attacker: CardInstance) -> String:
	return "" if _block_matrix.get(handle(blocker.id), {}).has(handle(attacker.id)) else "This creature cannot block that attacker."
