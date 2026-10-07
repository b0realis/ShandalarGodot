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
## Pack 9 — Magnetic Web: local attacker id -> the local ids attacking
## with it drags in (SgDuelPresentation.attack_companions).
var _attack_companions: Dictionary = {}


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


## A choice's lines as this seat reads them (protocol 29, whole-game
## campaign 2026-10-07): a line that stands for a board card ends in that
## card's ID tag — "#7", the number `Show ID tags` (Ctrl+T) draws on it —
## in place of the handle the referee ends it with ("[c12]", a program's
## name for the card, nothing a person sees), so two Grizzly Bears are
## told apart as the local screen tells them (DuelScreen
## .choice_card_lines). Display only: a pick is still the line's index.
func choice_lines(choice: Dictionary) -> Array:
	var lines: Array = []
	var cards: Array = choice.get("cards", [])
	for i in choice.options.size():
		var line := String(choice.options[i])
		var key := String(cards[i]) if i < cards.size() else ""
		if key != "":
			var tail := " [%s]" % key
			if line.ends_with(tail): line = line.left(line.length() - tail.length())
			line += " #%d" % local_id(key)
		lines.append(line)
	return lines


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
	_attack_companions.clear()
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
		# Phased out under this seat's control (Pack 8): on the table, not
		# on the battlefield list (CR 702.26b) — DuelScreen._table_cards.
		p.phased_out.assign(_zone(dto.phased_out, Mtg.Zone.BATTLEFIELD))
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
		card.phase_hold = -1
	# "Held by" (Pack 8 — Oubliette, CR 610.4a): the holder this seat sees,
	# so the ghost's tooltip names it (MiniCard.phase_note).
	for pair in presentation.phase_holds:
		var held := find_instance(local_id(pair[0]))
		if held != null: held.phase_hold = local_id(pair[1])
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
	for row in presentation.attack_companions:
		var dragged: Array = []
		for key in row[1]: dragged.append(local_id(key))
		_attack_companions[local_id(row[0])] = dragged
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
			awaiting_choice.options.assign(choice_lines(view.choice))
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


## CASTING FROM THE GRAVEYARD (Pack 8 — Bösium Strip) is the referee's
## permission, read off the face's own actions: the host offers a "spell"
## action on exactly the graveyard card this seat may cast. The local
## screen's graveyard view rings it and its click starts the cast chain.
func can_cast_from_graveyard(pid: int, inst: CardInstance) -> bool:
	if pid != 0 or inst == null or inst.zone != Mtg.Zone.GRAVEYARD: return false
	for option in faces.get(handle(inst.id), {}).get("actions", []):
		if option.kind == "spell": return true
	return false


func playable_cards(pid: int) -> Array[CardInstance]:
	var out := super.playable_cards(pid)
	if pid == 0:
		for inst in players[0].graveyard:
			if can_cast_from_graveyard(0, inst): out.append(inst)
	return out


## A hand card's SPECIAL ACTION (Pack 8 — Circling Vultures) is a message,
## never a discard run on this projection's own copy of the table.
func discard_as_special_action(_pid: int, inst: CardInstance) -> String:
	return send({"op": "discard_special", "card": handle(inst.id)})


## Heat Wave's tax on the pencilled blocks [param blocks] (blocker id ->
## attacker ids), as the referee will charge it: each blocker owes each
## imposing source once, whatever it blocks (CombatState.block_life_owed —
## the first of a source's taxes that applies, attacker by attacker), read
## off the host's rows `[tax, life, attackers, blockers]` (protocol 27).
func block_life_fee(blocks: Dictionary) -> int:
	var rows: Array = presentation.get("block_taxes", [])
	var total := 0
	for id in blocks:
		var blocker := handle(int(id))
		var owed := {}
		var value: Variant = blocks[id]
		for attacker in (value if value is Array else [value]):
			var protected := handle(int(attacker))
			for row in rows:
				if owed.has(row[0]) or not row[2].has(protected) or not row[3].has(blocker): continue
				owed[row[0]] = int(row[1])
		for tax in owed: total += int(owed[tax])
	return total


func may_tap_foreign_land(pid: int, inst: CardInstance, index := -1) -> bool:
	if pid != 0 or inst.controller_id == pid or not inst.is_land(): return false
	for option in faces.get(handle(inst.id), {}).get("actions", []):
		if option.kind == "mana" and (index < 0 or int(option.index) == index): return true
	return false


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
		"amount": int(a.amount), "targets": targets, "trample": a.trample, "assigned": assigned,
		"special": a.get("special", ""), "normal_assigner": local_seat(int(a.get("normal_assigner", a.assigner))),
		"free_order": bool(a.get("free_order", false))}


## THE CREATURES A PENCILLED ATTACK OF [param ids] DRAGS IN (Pack 9 —
## Magnetic Web, CR 508.1d): the referee's per-attacker rows
## (SgDuelPresentation.attack_companions) followed to a fixpoint, each one
## added setting off its own. The referee's own declaration check stays
## the judge; this lights the screen.
func attack_companions_for(ids: Array) -> Array:
	var plan: Array = ids.duplicate()
	var out: Array = []
	var grew := true
	while grew:
		grew = false
		for id in plan.duplicate():
			for other in _attack_companions.get(int(id), []):
				if plan.has(other): continue
				plan.append(other)
				out.append(other)
				grew = true
	return out


## THE SEAT'S SPECIAL ACTIONS (Pack 9), as the referee listed them for
## this seat — `specials`, worded, and `special_rows`, the kind and the
## card each belongs to — in the engine's row shape, so the shared duel
## screen's menus offer a licid's end on the licid and a curse's ignore
## on the cursed creature here too. `id` is the row's place in the
## referee's list (the `special` op's index). Nothing is computed here:
## the projection holds no delayed trigger, licid or curse of its own.
func special_actions(pid: int) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if pid != 0:
		return out
	var labels: Array = view.get("specials", [])
	var rows: Array = presentation.get("special_rows", [])
	for i in mini(labels.size(), rows.size()):
		var key := String(rows[i][1])
		var card: CardInstance = find_instance(int(_local_ids.get(key, -1))) if key != "" else null
		out.append({"kind": String(rows[i][0]), "id": i, "label": String(labels[i]),
			"desc": String(labels[i]), "cost": ManaCost.parse(""), "by": 0, "card": card})
	return out


## The referee listed only what it would take now; this seat waits while a
## message is in flight.
func special_action_refusal(pid: int, row: Dictionary) -> String:
	if pid != 0: return "That special action is not yours."
	if locked: return "Waiting for the host."
	var listed := special_actions(0)
	var at := int(row.get("id", -1))
	if at < 0 or at >= listed.size() or String(listed[at].kind) != String(row.get("kind", "")):
		return "That special action is no longer available."
	return ""


## Taking one is a MESSAGE — `special` with its index — never an action on
## this projection; the referee answers with a new view (a curse's
## sacrifice arrives as the seat's own cost question).
func take_special_action(pid: int, row: Dictionary) -> String:
	var why := special_action_refusal(pid, row)
	if not why.is_empty(): return why
	return send({"op": "special", "index": int(row.get("id", -1))})


## THE PAYMENT ROWS the referee offers this seat for [param inst] (Pack 9):
## the labels its face's Cast action carries (SgDuelActions.options —
## printed modes, buyback rows, rows a permanent grants), on the printed
## rows this end knows. A granted row's effects are the referee's
## business: the announcement it sends back carries its targets.
func payment_rows(pid: int, inst: CardInstance) -> Array:
	var printed := super.payment_rows(pid, inst)
	var labels: Array = []
	for option in faces.get(handle(inst.id), {}).get("actions", []):
		if option.kind == "spell":
			labels = option.modes
			break
	if labels.is_empty():
		return printed
	var rows: Array = []
	for i in labels.size():
		var row: Dictionary = (printed[i] as Dictionary).duplicate() if i < printed.size() \
			else {"effects": (printed[0] as Dictionary).get("effects", []) if not printed.is_empty() else [],
				"payment": _granted_payment(inst, i), "effects_mode": 0, "granted_by": -1}
		row["label"] = String(labels[i])
		rows.append(row)
	return rows


## A GRANTED row's payment as far as this end can know it: an alternative
## cost (CR 118.9) and, while the referee lists the row as open, its mana
## (the presentation's spell row for that mode) — so an X spell cast
## through it is not asked an X the row has not got (CR 107.3b).
func _granted_payment(inst: CardInstance, mode: int) -> Dictionary:
	var pay := {"alt": true}
	for option in details.get(handle(inst.id), {}).get("abilities", []):
		if option.kind == "spell" and int(option.index) == mode and mode > 0:
			pay["cost"] = ManaCost.parse(String(option.cost))
	return pay


## Row [param mode] can be paid now when the referee lists it as an OPEN
## mode — a spell row of the card's presentation after its first
## (SgDuelPresentation.build); a card with one row asks its `castable`.
func payment_row_refusal(_pid: int, inst: CardInstance, mode: int, _potential := true) -> String:
	var detail: Dictionary = details.get(handle(inst.id), {})
	var first := true
	var rowed := false
	for option in detail.get("abilities", []):
		if option.kind != "spell": continue
		if first:
			first = false
			continue
		rowed = true
		if int(option.index) == mode: return ""
	if not rowed and mode == 0 and bool(detail.get("castable", false)): return ""
	return "That way of paying is not open now."


## The ANNOUNCEMENT is the referee's too (Pack 9 bug pass). The local row
## menu greys a row the engine refuses to announce now (DuelScreen.
## _open_mode_menu: the printed row of a small creature at instant speed
## under Aluren); here the referee's open rows already carry that answer
## ([method payment_row_refusal] — SgDuelActions.open_modes asks the
## engine's spell_announce_refusal), and this end never knows a granted
## row's flash, so judging again would grey Aluren's own row.
func spell_announce_refusal(_pid: int, _inst: CardInstance, _x_value := 0, _mode := 0) -> String:
	return ""


func attack_refusal(card: CardInstance) -> String:
	return "" if presentation.attackable.has(handle(card.id)) else "This creature cannot attack."


func block_refusal(blocker: CardInstance, attacker: CardInstance) -> String:
	return "" if _block_matrix.get(handle(blocker.id), {}).has(handle(attacker.id)) else "This creature cannot block that attacker."
