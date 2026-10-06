class_name SgDuelView
extends DuelScreen
## Transport adapter for the actual duel screen, not a second interface.
## All gameplay state comes from a filtered view; no client rules simulation.

signal action_requested(action: Dictionary)
signal reconnect_requested
signal exit_requested
## OK on a friendly duel's result: leave this room for the lobby, keeping
## the connection — and, on a host, every other table (2026-10-03).
signal leave_requested
signal hall_requested
signal tournament_requested

var projection := SgDuelProjection.new()
var _room: Dictionary = {}
var _online := false
var _busy := false
var _built := false
var _presenting := false
var _sent_revision := -1
var _awaiting_ack := false
var _sent_op := ""
var _prepared_key := ""
var _auto_pay_requested := false
var _last_cue := -1
var _last_visual_event := -1
var _network_badge: Button
var _connection_banner: PanelContainer
var _banner_text: Label
var _network_opening: SgDuelOpening
var _network_dialog: OriginalDialog
var _connection_status: Label
var _opening_snapshot: Dictionary = {}
var _opening_started := false
var _intro_seen := false
var _shown_choice: Dictionary = {}
var _result_seen := false
var _hosting := false
var _announcement_refused := false
var _tournament_panel_open := false


func _ready() -> void:
	# Never run the parent's local _new_game/setup. Wait for the filtered view.
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)


func present(room: Dictionary, online: bool, busy: bool, hosting := false) -> void:
	_hosting = hosting
	_online = online
	_busy = busy
	if _presenting:
		projection.locked = true
		return
	if not SgViewProtocol.room(room):
		# NEVER DROPPED WITHOUT A WORD (bug pass 2026-10-04): protocol 26's
		# Heat Wave rows outgrew the validator on a legal board and the
		# table simply froze. The last valid table stays; the log and the
		# prompt say why.
		push_warning("SGManalink: a view of room %s at revision %s failed the protocol check and was not shown." % [
			str(room.get("id", "?")), str(room.get("revision", "?"))])
		if _built: _report("The host's latest table could not be shown (it failed the protocol check); the last valid table stays.")
		return
	if room.is_empty() or room.game.is_empty(): return
	_presenting = true
	_room = room.duplicate(true)
	if _awaiting_ack and int(room.revision) > _sent_revision and not busy: _awaiting_ack = false
	projection.locked = not online or busy or _awaiting_ack or not (room.connected[0] and room.connected[1]) \
		or String(room.get("tournament", {}).get("hold", "")) != ""
	projection.ingest(_room)
	hidden_hands.assign([] if projection.players[1].hand_revealed else [1])
	if not _built:
		game = projection
		config = DuelConfig.new()
		# THE TABLE RULES: the opening card names the table's starting life.
		config.lives = [SgTableRules.life(room.get("rules", {})), SgTableRules.life(room.get("rules", {}))]
		for remote in 2:
			var pid := projection.local_seat(remote)
			config.player_names[pid] = room.names[remote]
			config.deck_names[pid] = room.deck_names[remote]
			config.panel_colors[pid] = room.game.presentation.players[remote].color
			var bot: Dictionary = room.get("bots", [{}, {}])[remote]
			if not bot.is_empty():
				# Presentation metadata only. No computer player runs on a client.
				config.pilots[pid] = SgBotPlayer.create(pid, bot).profile
				config.unfair[pid] = bot.unfair
		config.decks[0] = room.deck.cards.duplicate() if not room.deck.is_empty() else []
		_humans[0] = HumanAgent.new()
		projection.action_requested.connect(_dispatch)
		projection.log_appended.connect(_on_log_line)
		_build_ui()
		_build_network_controls()
		_built = true
		# Rejoining a finished duel has no previous painted total to animate.
		for pid in 2: _last_life[pid] = game.players[pid].life
		_play_music()
	if _shown_choice != room.game.choice:
		_close_choice_overlay()
		_choice_picks.clear()
		_shown_choice = room.game.choice.duplicate(true)
	_present_visual_events()
	if not projection.locked: _sync_announcement()
	if game.game_over and not _result_seen:
		_result_seen = true
		# The shared death countdown starts from the last PAINTED life.
		# A refresh here would overwrite it with the final remote total.
		_on_game_over(game.winner)
		if is_instance_valid(_intro_overlay): _intro_overlay.go_pressed.emit()
	_refresh()
	_present_cues()
	if game.mulligan_open and not game.game_over and not _opening_started:
		_opening_started = true
		_play_sfx("sfx_shuffle")
		_run_coin_toss(projection.local_seat(int(room.game.presentation.toss)))
	_update_opening()
	_presenting = false


func _dispatch(action: Dictionary) -> void:
	if action.op != "submit": _announcement_refused = false
	_sent_revision = int(_room.revision)
	_awaiting_ack = true
	_sent_op = action.op
	action_requested.emit(action)


func _send(action: Dictionary) -> void:
	var error := projection.send(action)
	if not error.is_empty(): _report(error)


func _is_human(pid: int) -> bool:
	return pid == 0


func _network_opponent() -> bool:
	return true


func _waiting_for_action() -> bool:
	return projection.locked


func _maybe_schedule_ai() -> void:
	pass


func _refresh() -> void:
	if not _built: return
	# A received view can cross several engine transitions at once. Drop the
	# previous declaration before the shared refresh enters the next one.
	var gates := {Mode.ATTACKERS: "attack", Mode.BLOCKERS: "block", Mode.DISCARD: "discard", Mode.DAMAGE: "damage"}
	if gates.has(mode) and projection.view.mode != gates[mode]:
		mode = Mode.NORMAL
		_clear_attack_lineup()
		_block_map.clear()
		_selected_blocker = -1
		_discard_picks.clear()
		_damage_picks.clear()
	super._refresh()
	_pass_button.disabled = projection.locked or game.game_over
	# Transport state belongs beside the table controls, never on top of a
	# combat/target/payment instruction. Even a brief ACK wait used to flash
	# over the phase message on every action.
	_network_badge.text = "Tournament" if _room.has("tournament") else "Online"
	if not _online: _network_badge.text = "Reconnect"
	elif not _room.connected[0] or not _room.connected[1]: _network_badge.text = "Suspended"
	elif _busy or _awaiting_ack: _network_badge.text = "Sending…"
	_network_badge.tooltip_text = _connection_message() + ("\nClick for the Tournament Hall and duel controls.\n" if _room.has("tournament") else "\nClick for connection controls.\n") \
		+ "Friendly, unrated player-hosted duel. Hidden opponent cards are not sent to this client; the host runs the referee."
	if is_instance_valid(_connection_status): _connection_status.text = _connection_message()
	_update_banner()


## A lost or suspended connection deserves more than a badge: one calm line
## over the table, out of the way of the phase prompt and the hand.
func _update_banner() -> void:
	if not is_instance_valid(_connection_banner): return
	var suspended: bool = _online and not (_room.connected[0] and _room.connected[1])
	_connection_banner.visible = not _online or suspended or String(_room.get("tournament", {}).get("hold", "")) != ""
	if not _connection_banner.visible: return
	_banner_text.text = _connection_message() + ("\nThe game reconnects by itself; Reconnect tries at once." if not _online
		else ("\nThe referee keeps the table exactly as it stands." if String(_room.get("tournament", {}).get("hold", "")) != ""
		else "\nThe referee keeps the table; play resumes when both seats are back."))
	_connection_banner.reset_size()
	var area := _board_area()
	var origin := get_global_rect().position
	_connection_banner.position = Vector2(area.position.x + (area.size.x - _connection_banner.size.x) * 0.5, area.position.y + 12) - origin


func _connection_message() -> String:
	if not _online: return "Reconnecting to the host. Your last confirmed table is shown."
	var hold := String(_room.get("tournament", {}).get("hold", ""))
	if hold == "storage": return "Tournament paused: the organiser must retry saving progress."
	if hold == "organiser": return "Tournament paused by the organiser. Play resumes when they continue the event."
	if not _room.connected[int(_room.seat)]:
		return "Restoring your seat. The duel is suspended."
	if not _room.connected[1 - int(_room.seat)]:
		return "Waiting for %s to reconnect. The duel is suspended." % config.player_names[1]
	if _busy or _awaiting_ack: return "Waiting for the host to confirm your action."
	return "Connected to the host."


func _drive_advance() -> void:
	if projection.locked or game.mulligan_open: return
	super._drive_advance()


func _auto_pass_applies() -> bool:
	return not projection.locked and not game.mulligan_open and super._auto_pass_applies()


func _could_respond(pid: int) -> bool:
	return pid == 0 and projection.presentation.respond


func _has_affordable_fast_effect(pid: int) -> bool:
	return pid == 0 and projection.presentation.floating


func _attack_refusal(inst: CardInstance) -> String:
	return projection.attack_refusal(inst)


func _block_refusal(blocker: CardInstance, attacker: CardInstance, _defender: int) -> String:
	return projection.block_refusal(blocker, attacker)


func _on_done() -> void:
	if not projection.locked: super._on_done()


func _on_card_clicked(inst: CardInstance) -> void:
	if not projection.locked: _announcement_refused = false
	if projection.locked: return
	# A PHASED-OUT permanent is read, never used (Pack 8): the shared screen
	# says so and when it comes back, and sends nothing.
	if mode == Mode.NORMAL and inst.zone == Mtg.Zone.BATTLEFIELD and not inst.phased_out \
			and not _modal_open() and not _toss_active:
		_click_permanent(inst)
		return
	super._on_card_clicked(inst)


func _on_life_clicked(pid: int) -> void:
	if not projection.locked: _announcement_refused = false
	if not projection.locked: super._on_life_clicked(pid)


func _click_hand_card(inst: CardInstance) -> void:
	if projection.locked or game.priority_player != 0: return
	if not _castable_source(inst): return
	if inst.is_land():
		_report(game.play_land(0, inst))
		return
	# A hand card with a SPECIAL ACTION too (Pack 8 — Circling Vultures)
	# asks Cast or Discard, as at a local table; the discard is a message
	# (SgDuelProjection.discard_as_special_action).
	if inst.zone == Mtg.Zone.HAND and inst.data.discard_special_action:
		_open_hand_action_menu(inst)
		return
	_start_cast(inst)


## Where this seat may cast from (Pack 8): its hand, an exiled card it may
## play (a Three Wishes card it alone may look at) and the graveyard card
## the referee offers a cast for (Bösium Strip).
func _castable_source(inst: CardInstance) -> bool:
	return (inst.zone == Mtg.Zone.HAND and inst.owner_id == 0) or game.can_play_from_exile(0, inst) \
		or game.can_cast_from_graveyard(0, inst)


## The cast chain of a card the seat has chosen to CAST — the click's, the
## hand menu's Cast line's and the double-click's. Its announcement is the
## referee's ([method _prepare]); nothing is cast on the projection.
func _start_cast(inst: CardInstance) -> void:
	if projection.locked or game.priority_player != 0 or not _castable_source(inst) or inst.is_land(): return
	_pending_card = inst
	_pending_pid = 0
	_pending_ability_index = -1
	_pending_targets = []
	_pending_x = 0
	_pending_mode = 0
	_prepared_key = ""
	# THE REFEREE'S ROWS (Pack 9): more than one — a modal spell, a buyback
	# row, a row Dream Halls or Aluren grants — is a question
	# (SgDuelProjection.payment_rows reads them off the face).
	if game.payment_rows(0, inst).size() > 1: _open_mode_menu(inst)
	else: _continue_cast_chain()


func _continue_cast_chain() -> void:
	# Searches wait for a rule-authorized question from the referee. The X
	# is asked as at a local table ([method DuelScreen._pending_wants_x]):
	# not for an ALTERNATIVE row without {X} (Pack 9 — Dream Halls'
	# discard, Aluren's free cast, CR 107.3b), whose cost the referee's
	# row names (SgDuelProjection.payment_rows).
	if _pending_wants_x(): _open_x_dialog()
	else: _prepare()


func _prepare() -> void:
	if _pending_card == null: return
	_send({"op": "prepare", "card": projection.handle(_pending_card.id),
		"kind": "spell" if _pending_ability_index < 0 else "ability",
		"index": maxi(0, _pending_ability_index), "x": _pending_x, "mode": _pending_mode})


func _sync_announcement() -> void:
	var announcement: Dictionary = projection.view.announcement
	var draft: Dictionary = projection.presentation.draft
	if announcement.is_empty():
		if not _prepared_key.is_empty():
			_clear_pending(true)
			_prepared_key = ""
		return
	# A mana source can suspend payment for a colour/cost question. Do not
	# submit the draft until that question (and any subsequent one) is done.
	if game.awaiting_choice != null or _announcement_refused: return
	if mode == Mode.PAYING and not draft.reachable:
		_clear_pending()
		_send({"op": "cancel"})
		_report("Not enough available mana for this action.")
		return
	var key := "%s/%s/%d/%d/%d" % [draft.card, draft.kind, draft.index, draft.x, draft.mode]
	var starting := key != _prepared_key
	if starting:
		var target_count := _pending_target_count
		_clear_pending()
		_pending_target_count = target_count
		_pending_card = game.find_instance(projection.local_id(draft.card))
		if _pending_card == null: return
		_pending_pid = 0
		_pending_ability_index = -1 if draft.kind == "spell" else int(draft.index)
		_pending_x = int(draft.x)
		_pending_mode = int(draft.mode)
		_prepared_key = key
	var refs := {}
	for entry in projection.presentation.targets: refs[entry.token] = entry.ref
	_pending_slots.clear()
	_pending_specs.clear()
	for slot in announcement.slots:
		var spec := SgTargetSpec.new(int(slot.kind), slot.label)
		for candidate in slot.targets:
			var ref: Dictionary = refs.get(candidate.id, {})
			if ref.is_empty(): continue
			spec.candidates.append(projection.target(ref))
			spec.tokens.append(candidate.id)
		var minimum := int(slot.min)
		var maximum := int(slot.max)
		if _pending_target_count > 0 and maximum > 1:
			minimum = _pending_target_count
			maximum = _pending_target_count
		# A count an earlier target sets (Pack 9 — Reap): the referee's
		# range per candidate of that target ([method _counted_range]).
		var counts := {}
		for row in slot.get("counts", []):
			counts[String(row[0])] = Vector2i(int(row[1]), int(row[2]))
		_pending_slots.append({"spec": spec, "min": minimum, "max": maximum, "divided": int(slot.divided),
			"counts": counts})
		_pending_specs.append(spec)
	if starting:
		_pending_groups.clear()
		for slot in _pending_slots: _pending_groups.append([])
		_pending_slot = 0
		if _auto_pay_requested:
			_auto_pay_requested = false
			_auto_tap_for_pending()
		else: _advance_pending()
	elif mode == Mode.NORMAL and _pending_card != null: _advance_pending()


func _submit_pending() -> void:
	if projection.locked or _pending_card == null or game.awaiting_choice != null or _announcement_refused: return
	var targets: Array = []
	for i in _pending_groups.size():
		for ref in _pending_groups[i]:
			var token := (_pending_slots[i].spec as SgTargetSpec).token_for(ref)
			if token.is_empty():
				_report("That target is no longer available. Choose again.")
				_pending_groups[i] = []
				_pending_slot = i
				_advance_pending()
				return
			targets.append([token, ref.amount])
	_send({"op": "submit", "targets": targets})


func show_notice(message: String) -> void:
	_awaiting_ack = false
	projection.locked = false
	if _sent_op == "submit" and MtgGame.is_unpaid_refusal(message) and _pending_card != null:
		mode = Mode.PAYING
		_paying_pool = _payment_pool_state()
		_set_target_cursor(false)
		var ask := GRAB_MANA_PROMPT % _pending_card.data.card_name
		# [QoL] What the TARGET adds (Pack 8 — a spell aimed at a Kaervek's
		# Torch costs {2} more), said as the local screen says it; the
		# referee's own payment and auto-tap include it.
		var fee := game.targets_surcharge(_flatten_pending_targets(), _pending_card) \
			if _pending_ability_index < 0 else 0
		if fee > 0: ask += " ({%d} more for its target)" % fee
		_set_prompt(ask)
		return
	if _sent_op in ["prepare", "autoprepare"]: _clear_pending()
	if _sent_op == "submit":
		_announcement_refused = true
		_pending_slot = 0
		_pending_groups.clear()
		for slot in _pending_slots: _pending_groups.append([])
		mode = Mode.TARGETING if not _pending_slots.is_empty() else Mode.NORMAL
		_set_target_cursor(mode == Mode.TARGETING)
	if _sent_op == "choice" and game.awaiting_choice != null and game.awaiting_choice.pid == 0:
		# A refused answer was never spent and the SAME question is still
		# open — present() only drops the picks when the question's own DTO
		# changes, and a refusal changes nothing. Keeping them made the next
		# click toggle the standing pick off instead of answering.
		_choice_picks = PackedInt32Array()
		_close_choice_overlay()
		_build_choice_overlay(game.awaiting_choice)
	_report(message)


func _retry_payment() -> void:
	if not projection.locked: super._retry_payment()


func _auto_cast(inst: CardInstance) -> void:
	if _pending_card != inst:
		if projection.locked: return
		# The gesture is a CAST: a card with a second hand action (Circling
		# Vultures) goes straight to the cast chain, as at a local table.
		if inst.is_land(): _click_hand_card(inst)
		else: _start_cast(inst)
	if _pending_card != inst: return
	if _x_dialog != null:
		if _pending_ability_index < 0 and _pending_card.data.additional_life_is_x: return
		# ...nor a count of the seat's cards or permanents (Pack 8): an
		# object-counted X is always asked (the referee refuses it too).
		if not _object_x_groups().is_empty(): return
		var count := int(_x_dialog.get_meta("targets").value) if _x_dialog.has_meta("targets") else 1
		_pending_target_count = count if _pending_card.data.extra_cost_per_target > 0 else -1
		_x_dialog.dismiss()
		_x_dialog = null
		_send({"op": "autoprepare", "card": projection.handle(inst.id),
			"kind": "spell" if _pending_ability_index < 0 else "ability", "index": maxi(0, _pending_ability_index),
			"mode": _pending_mode, "excluded": _excluded_sources(), "count": count})
		return
	if projection.locked:
		_auto_pay_requested = true
		return
	_auto_tap_for_pending()


func _auto_tap_for_pending() -> void:
	if projection.locked or _prepared_key.is_empty():
		_auto_pay_requested = true
		return
	_send({"op": "autopay", "excluded": _excluded_sources(), "count": maxi(maxi(1, _pending_target_count), _flatten_pending_targets().size())})


func _excluded_sources() -> Array:
	var excluded: Array = []
	for id in _no_auto_tap:
		var handle := projection.handle(id)
		if not handle.is_empty(): excluded.append(handle)
	return excluded


## The referee's row for the pending cast or activation. A spell's FIRST
## spell row is its printed cost; one more follows for each mode or
## payment row it may be cast in now (SgDuelPresentation.build,
## 2026-10-04), so a chosen mode reads its own row's cost and X budget
## when there is one, else the first.
func _option_detail() -> Dictionary:
	if _pending_card == null: return {}
	var detail: Dictionary = projection.details.get(projection.handle(_pending_card.id), {})
	var first := {}
	var spells := 0
	for option in detail.get("abilities", []):
		if option.kind == "ability" and _pending_ability_index >= 0 and option.index == _pending_ability_index: return option
		if option.kind != "spell" or _pending_ability_index >= 0: continue
		spells += 1
		if spells == 1: first = option
		elif int(option.index) == _pending_mode: return option
	return first


func _open_x_dialog() -> void:
	var option := _option_detail()
	var cost := ManaCost.parse(option.get("cost", ""))
	var per_x := maxi(1, cost.x_count)
	var per_target := _pending_card.data.extra_cost_per_target if _pending_ability_index < 0 else 0
	var life_x := _pending_ability_index < 0 and _pending_card.data.additional_life_is_x
	var prompt := "Life to pay (X):" if life_x else FireballDialog.ASK_MANA
	if _pending_ability_index < 0 and not _pending_card.data.repeated_additional_cost.is_empty():
		prompt = "Number of additional %s payments:" % _pending_card.data.repeated_additional_cost
	# X COUNTS OBJECTS (Pack 8 — Infernal Harvest, Haunting Misery,
	# Firestorm): the cost's own words, never pre-filled. The bound is the
	# referee's (SgPayment.budget asks AdditionalObjectCosts.max_x).
	var object_x := _object_x_groups()
	if not object_x.is_empty(): prompt = object_x_prompt(object_x)
	# The referee reports maximum X; the shared dialog dials X payment units.
	_x_dialog = FireballDialog.window(_pending_card.data.card_name, int(option.get("budget", 0)) * per_x, per_target, SgProtocol.MAX_CARDS, per_x, prompt)
	_x_spin = _x_dialog.get_meta("mana")
	if life_x or not object_x.is_empty(): _x_spin.value = 0
	_x_dialog.add_button("OK").pressed.connect(_on_x_confirmed)
	_x_dialog.add_button("Cancel").pressed.connect(_on_x_canceled)
	add_child(_x_dialog)


func _on_x_confirmed() -> void:
	if _pending_card == null: return
	var per_x := maxi(1, ManaCost.parse(_option_detail().get("cost", "")).x_count)
	var per_target := _pending_card.data.extra_cost_per_target if _pending_ability_index < 0 else 0
	var count := int(_x_dialog.get_meta("targets").value) if _x_dialog.has_meta("targets") else 1
	var plan := FireballDialog.plan(int(_x_spin.value), int(_x_spin.value), count, per_target, per_x)
	_pending_x = int(plan.x)
	_pending_target_count = count if per_target > 0 else -1
	_x_dialog.dismiss()
	_x_dialog = null
	_prepare()


## A TARGET COUNT AN EARLIER TARGET SETS (Pack 9 — Reap): the referee's
## `counts` for the slot, read at the token of the one earlier target the
## seat picked — the opponent whose black permanents X counts. (-1, -1)
## for every other slot, which keeps its own range.
func _counted_range(slot: Dictionary, earlier: Array) -> Vector2i:
	var counts: Dictionary = slot.get("counts", {})
	if counts.is_empty() or earlier.size() != 1:
		return Vector2i(-1, -1)
	for other in _pending_slots:
		if not other.spec is SgTargetSpec: continue
		var token := (other.spec as SgTargetSpec).token_for(earlier[0])
		if counts.has(token): return counts[token]
	return Vector2i(-1, -1)


## Magnetic Web's companions (Pack 9): the referee's rows for this seat's
## attackers, followed for the pencilled plan
## (SgDuelProjection.attack_companions_for).
func _attack_companions() -> Array:
	if not game.awaiting_attackers or _selected_attackers.is_empty(): return []
	return projection.attack_companions_for(_selected_attackers)


## A blocker under orders (Pack 9 — Watchdog, Invasion Plans, Provoke):
## the referee's flags say it must block, its block matrix that it has an
## attacker to block. The matrix counts a block with a cost as well, which
## a requirement never asks for (CR 509.1d) — the light is then a hint
## and the referee's declaration check is the judge.
func _must_block_now(inst: CardInstance) -> bool:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.tapped or inst.phased_out \
			or inst.controller_id == game.active_player or _block_map.has(inst.id):
		return false
	if not (inst.cur_must_block or inst.must_block_this_turn_any): return false
	return not projection._block_matrix.get(projection.handle(inst.id), {}).is_empty()


## Heat Wave's life tax on the pencilled blocks (Pack 8): the referee's
## rows, priced as it will charge them, so the shared block lineup refuses
## a block the seat cannot pay for and notes what the rest cost.
func _block_life_fee(blocks: Dictionary) -> int:
	return projection.block_life_fee(blocks)


func _click_permanent(inst: CardInstance) -> void:
	if inst.phased_out: return
	var options: Array = projection.faces.get(projection.handle(inst.id), {}).get("actions", [])
	if options.size() == 1 and options[0].kind == "mana": _report(game.tap_for_mana(0, inst, int(options[0].index)))
	elif not options.is_empty(): _open_ability_menu(inst)


func _tap_for_payment(inst: CardInstance) -> void:
	_open_ability_menu(inst, true)


func _on_graveyard_card(inst: CardInstance) -> void:
	if projection.locked: return
	if mode == Mode.TARGETING:
		super._on_graveyard_card(inst)
		return
	if inst.face_down:
		if _card_preview != null: _card_preview.show_back()
		return
	if _card_preview != null: _card_preview.show_card(inst)
	if game.priority_player != 0: return
	# Only a quiet table starts something from a pile (the local rule).
	if mode != Mode.NORMAL or _pending_card != null: return
	# An exiled card this seat may play (Three Wishes, the Bottle) and the
	# graveyard card the referee offers a cast for (Bösium Strip, Pack 8).
	if game.can_play_from_exile(0, inst) or game.can_cast_from_graveyard(0, inst):
		_close_graveyard()
		_click_hand_card(inst)
	elif not projection.faces.get(projection.handle(inst.id), {}).get("actions", []).is_empty():
		_close_graveyard()
		_open_ability_menu(inst)


func _open_ability_menu(inst: CardInstance, mana_only := false) -> void:
	_ability_menu.clear()
	var options: Array = []
	for option in projection.faces.get(projection.handle(inst.id), {}).get("actions", []):
		if not mana_only or option.kind == "mana": options.append(option)
	if mana_only and options.size() == 1:
		_report(game.tap_for_mana(0, inst, int(options[0].index)))
		return
	if options.is_empty(): return
	for i in options.size(): _ability_menu.add_item(options[i].label, i)
	_ability_menu.set_meta("network_options", options)
	_ability_menu.set_meta("instance_id", inst.id)
	_ability_menu.position = Vector2i(_pointer())
	_ability_menu.popup()


func _on_ability_chosen(index: int) -> void:
	if projection.locked: return
	var inst := game.find_instance(int(_ability_menu.get_meta("instance_id")))
	var options: Array = _ability_menu.get_meta("network_options", [])
	if inst == null or index < 0 or index >= options.size(): return
	var option: Dictionary = options[index]
	if option.kind == "mana":
		_report(game.tap_for_mana(0, inst, int(option.index)))
		return
	_pending_card = inst
	_pending_pid = 0
	_pending_ability_index = int(option.index)
	_pending_x = 0
	_pending_mode = 0
	_prepared_key = ""
	if option.x: _open_x_dialog()
	else: _prepare()


func _on_cancel() -> void:
	if projection.locked: return
	if _pending_card != null and not _prepared_key.is_empty(): _send({"op": "cancel"})
	super._on_cancel()
	_prepared_key = ""
	_auto_pay_requested = false


## THE GRAVEYARD/EXILE RING AT A NETWORKED TABLE (Mirage bug pass,
## 2026-10-04, H8-6): the referee's own answer, never the projection's
## timing-only reading, which rang an exiled Three Wishes land on the
## opponent's turn — and the click was refused. A LAND rings on the face's
## `playable` (SgPracticeMatch._playable: the seat's main phase, an empty
## stack, a land drop unspent); a spell as a hand card lights
## ([method _highlight_for]): `playable`, or the row's `castable` (its
## timing allows it and the mana the seat could still tap pays for it).
func _pile_card_playable(_seat: int, inst: CardInstance) -> bool:
	var key := projection.handle(inst.id)
	var face: Dictionary = projection.faces.get(key, {})
	if inst.is_land() or bool(face.get("land", false)): return bool(face.get("playable", false))
	return bool(face.get("playable", false)) or bool(projection.details.get(key, {}).get("castable", false))


func _highlight_for(inst: CardInstance) -> int:
	if mode == Mode.NORMAL and inst.zone == Mtg.Zone.HAND:
		var face: Dictionary = projection.faces.get(projection.handle(inst.id), {})
		var detail: Dictionary = projection.details.get(projection.handle(inst.id), {})
		return MiniCard.Highlight.OPTIONAL if face.get("playable", false) or detail.get("castable", false) else MiniCard.Highlight.NONE
	return super._highlight_for(inst)


## THE PAYMENT CUE READS THE LIVE LIST, like everything else the board
## lights. `cur_mana_abilities` is the one list [SgCardPresentation] leaves
## PRINTED at a guest, so a Titania's Song-silenced Sol Ring kept lighting
## in [constant DuelScreen.Mode.PAYING] — a promise that clicking it makes
## mana, where [method _click_permanent] reads the referee's own options
## and finds none. The host sends those options per face; this asks them.
func _has_payment_mana(inst: CardInstance) -> bool:
	for option in projection.faces.get(projection.handle(inst.id), {}).get("actions", []):
		if option.kind != "mana": continue
		# A live index past the printed list has no conflict to read.
		if int(option.index) >= inst.cur_mana_abilities.size(): return true
		if not _pending_mana_conflicts(inst, int(option.index)): return true
	return false


func _can_act_on(inst: CardInstance) -> bool:
	if game.priority_player != 0: return false
	for option in projection.faces.get(projection.handle(inst.id), {}).get("actions", []):
		if option.kind == "ability": return true
	return false


func _open_choice_overlay() -> void:
	if _choice_overlay == null and game.awaiting_choice != null and game.awaiting_choice.pid == 0:
		_build_choice_overlay(game.awaiting_choice)


func _on_choice_option(index: int) -> void:
	if projection.locked or projection.view.choice.is_empty(): return
	var choice: Dictionary = projection.view.choice
	if index < 0 or index >= choice.options.size(): return
	if _choice_picks.has(index): _choice_picks.remove_at(_choice_picks.find(index))
	else: _choice_picks.append(index)
	if _choice_picks.size() == int(choice.count): _report(game.answer_choice(Array(_choice_picks)))
	else:
		_close_choice_overlay()
		_build_choice_overlay(game.awaiting_choice)


func _run_coin_toss(first: int) -> void:
	_toss_active = true
	await _run_intro()
	if not is_inside_tree(): return
	# A restored snapshot or an opponent conceding may finish the opening
	# while this player reads. Never replay it over an active/finished duel.
	if game.mulligan_open and not game.game_over and DisplayServer.get_name() != "headless":
		_play_sfx("sfx_toss")
		var toss := CoinToss.new()
		toss.z_index = 250
		if _audio != null: toss.video_skipped.connect(_audio.stop.bind("sfx_toss"))
		add_child(toss)
		_toss_overlay = toss
		await toss.run(config, first, _is_human(first), _human_seat())
		if is_instance_valid(toss): toss.queue_free()
		_toss_overlay = null
	if game.mulligan_open and not game.game_over: _run_opening_hand(first)
	_toss_active = false
	_refresh()


## Once per new duel; reconnecting an active table never replays the intro.
func _run_intro() -> void:
	if _intro_seen: return
	_intro_seen = true
	var intro := SgDuelOpening.new()
	intro.z_index = 260
	add_child(intro)
	intro.build_match(config, game.rules, _room.get("tournament", {}))
	intro.show_introduction()
	_intro_overlay = intro
	intro.reconfigure_pressed.connect(_request_exit)
	await intro.go_pressed
	if is_instance_valid(intro): intro.queue_free()
	_intro_overlay = null


func _run_opening_hand(_winner: int) -> void:
	_opening_snapshot.clear()
	_network_opening = SgDuelOpening.new()
	_network_opening.z_index = 230
	add_child(_network_opening)
	_network_opening.build_match(config, game.rules, _room.get("tournament", {}))
	_network_opening.answered.connect(_opening_answer)
	_update_opening()
	_toss_active = false


func _update_opening() -> void:
	for row in _hand_rows: row.visible = not game.mulligan_open and not _toss_active
	if _network_opening == null: return
	if not game.mulligan_open or game.game_over:
		_network_opening.close()
		_network_opening = null
		return
	var deciding := projection.local_seat(int(projection.view.actor)) == 0
	var hand_view := {"cards": projection.view.hand, "color": config.panel_colors[0]}
	if hand_view != _opening_snapshot:
		_network_opening.show_hand(game, 0, config.panel_colors[0])
		_opening_snapshot = hand_view.duplicate(true)
	var ordered: bool = projection.presentation.order
	_network_opening.set_lead(("You will take the first turn" if projection.local_seat(int(projection.view.first)) == 0 else "%s will take the first turn" % config.player_names[1]) \
		if ordered else ("You won the coin toss" if deciding else "%s won the coin toss" % config.player_names[1]))
	_network_opening.set_status("" if deciding else "Waiting for %s" % config.player_names[1])
	_network_opening.set_answers([
		{"answer": 0, "label": "Take mulligan" if ordered else "Play first", "disabled": not deciding or projection.locked or (ordered and game.players[0].hand.is_empty())},
		{"answer": 1, "label": "Start the duel" if ordered else "Draw first", "disabled": not deciding or projection.locked}])


func _opening_answer(answer: int) -> void:
	if _intro_overlay != null or _toss_active or not is_instance_valid(_network_opening): return
	if int(projection.view.actor) != projection.seat or projection.locked: return
	if not projection.presentation.order: _send({"op": "order", "play": answer == 0})
	else: _send({"op": "mulligan" if answer == 0 else "keep"})


func _present_cues() -> void:
	for item in projection.presentation.cues:
		if _last_cue >= 0 and int(item.serial) > _last_cue: _play_sfx(item.cue)
	var cues: Array = projection.presentation.cues
	_last_cue = maxi(_last_cue, int(cues.back().serial)) if not cues.is_empty() else maxi(_last_cue, 0)


func _present_visual_events() -> void:
	for event in projection.presentation.events:
		if int(event.serial) <= _last_visual_event or _last_visual_event < 0: continue
		var card := game.find_instance(projection.local_id(event.card))
		if card == null: continue
		if event.kind == "draw" and card.owner_id == 0 and game.turn_number > 0:
			_card_preview.show_card(card)
		elif event.kind == "dies":
			game.event_occurred.emit(GameEvent.new(Mtg.EventType.DIES, {"instance": card, "sacrificed": event.sacrificed}))
	var events: Array = projection.presentation.events
	_last_visual_event = maxi(_last_visual_event, int(events.back().serial)) if not events.is_empty() else maxi(_last_visual_event, 0)


func _build_network_controls() -> void:
	# A restored snapshot may already be in combat before containers have
	# their first layout. Fit again when the board settles or resizes; a full
	# refresh here would needlessly rebuild the live combat card widgets.
	for rows in _half_rows:
		rows.get_parent().resized.connect(_refit_network_combat, CONNECT_DEFERRED)
	_network_badge = Button.new()
	_network_badge.text = "Online"
	_network_badge.custom_minimum_size = Vector2(105, 30)
	OriginalDialog.dress_bar_button(_network_badge)
	_network_badge.position = Vector2(4, 4)
	_network_badge.tooltip_text = "Unrated player-hosted duel. Your opponent's hidden hand and library are not sent to this client. The host runs the referee."
	_network_badge.pressed.connect(func() -> void:
		if _room.has("tournament"): tournament_requested.emit()
		else: _show_connection())
	_qol_reserve.add_child(_network_badge)
	_connection_banner = PanelContainer.new()
	_connection_banner.name = "ConnectionBanner"
	_connection_banner.add_theme_stylebox_override("panel", OriginalDialog.panel_style("panel_dark_stone", 12))
	_connection_banner.z_index = 150
	_connection_banner.hide()
	var line := HBoxContainer.new()
	line.add_theme_constant_override("separation", 14)
	_connection_banner.add_child(line)
	_banner_text = OriginalDialog.label("", 15)
	_banner_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_banner_text.custom_minimum_size.x = 520
	_banner_text.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	line.add_child(_banner_text)
	var retry := OriginalDialog.button("Reconnect", Vector2(110, 30))
	retry.size_flags_vertical = Control.SIZE_SHRINK_CENTER
	retry.pressed.connect(reconnect_requested.emit)
	line.add_child(retry)
	add_child(_connection_banner)
	resized.connect(func() -> void: _update_banner())


func _refit_network_combat() -> void:
	if not _built or not is_inside_tree(): return
	if is_instance_valid(_combat_window) and _combat_window.visible:
		_combat_window.fit(_board_area())


func _show_connection() -> void:
	var dialog := _network_window("SGManalink · " + String(_room.get("name", "Friendly duel")), Vector2(560, 330))
	var column := VBoxContainer.new()
	column.position = Vector2(24, 54)
	column.custom_minimum_size.x = 510
	column.add_theme_constant_override("separation", 6)
	_connection_status = OriginalDialog.label(_connection_message(), 16)
	_connection_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_connection_status.custom_minimum_size.x = 510
	column.add_child(_connection_status)
	var seat := int(_room.seat)
	var facts := OriginalDialog.label("You: %s  ·  Opponent: %s\n%s  ·  %s" % [_room.names[seat], _room.names[1 - seat],
		"You host this table" if _hosting else "Hosted by your opponent's computer",
		"Tournament duel" if _room.has("tournament") else "Friendly duel, unrated"], 14)
	facts.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	facts.custom_minimum_size.x = 510
	facts.add_theme_color_override("font_color", OriginalDialog.CHOICE)
	column.add_child(facts)
	column.add_child(Control.new())
	for entry in [["Revealed information", _show_information], ["Special actions", _show_specials],
		["Reconnect", reconnect_requested.emit], ["Duel menu", _toggle_pause]]:
		var button := OriginalDialog.choice_line(entry[0])
		var callback: Callable = entry[1]
		button.pressed.connect(func() -> void:
			dialog.dismiss()
			callback.call())
		column.add_child(button)
	dialog.add_child(column)


func _show_information() -> void:
	var dialog := _network_window("Revealed information")
	var lines: Array[String] = []
	for player in projection.view.players:
		if not player.top.is_empty(): lines.append("%s — revealed library top: %s" % [_room.names[int(player.seat)], player.top])
		if not player.revealed.is_empty():
			var names: Array[String] = []
			for card in player.revealed: names.append(card.name)
			lines.append("%s — currently revealed hand cards\n%s" % [_room.names[int(player.seat)], ", ".join(names)])
	for info in projection.view.information: lines.append(info.title + "\n" + ", ".join(info.cards))
	if lines.is_empty(): lines.append("No cards have been revealed by an effect.")
	var text := OriginalDialog.label("\n\n".join(lines), 14)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var scroll := ScrollContainer.new()
	scroll.position = Vector2(24, 54)
	scroll.size = Vector2(510, 300)
	text.custom_minimum_size.x = 490
	scroll.add_child(text)
	dialog.add_child(scroll)


func _show_specials() -> void:
	var dialog := _network_window("Special actions")
	var column := VBoxContainer.new()
	column.position = Vector2(24, 54)
	column.size = Vector2(510, 280)
	for i in projection.view.specials.size():
		var button := OriginalDialog.choice_line(projection.view.specials[i])
		button.disabled = projection.locked or game.priority_player != 0
		button.pressed.connect(func() -> void:
			dialog.dismiss()
			_send({"op": "special", "index": i}))
		column.add_child(button)
	if column.get_child_count() == 0: column.add_child(OriginalDialog.label("No special actions available.", 14))
	dialog.add_child(column)


func _network_window(title: String, size := Vector2(560, 420)) -> OriginalDialog:
	if is_instance_valid(_network_dialog): _network_dialog.dismiss()
	_network_dialog = OriginalDialog.create(title, size)
	_network_dialog.z_index = 280
	_network_dialog.add_button("Close").pressed.connect(_network_dialog.dismiss)
	add_child(_network_dialog)
	return _network_dialog


func _modal_open() -> bool:
	return _tournament_panel_open or is_instance_valid(_intro_overlay) or is_instance_valid(_network_dialog) or is_instance_valid(_network_opening) or super._modal_open()


## THE TOP RUNG OF THE CANCEL LADDER IS THE WINDOW THAT IS OPEN, and the
## Manalink windows are bare [OriginalDialog]s exactly as `Give up this
## duel?` and `Duel Options...` are — so [method DuelScreen._dialogs_open]
## is already true for them and Escape was routed into the ladder. With no
## rung of their own it peeled a layer of the duel UNDERNEATH instead: one
## press over the connection window un-declared the attackers the player
## had lined up while they were looking at a different window.
func _on_escape() -> void:
	if is_instance_valid(_network_dialog):
		_network_dialog.dismiss()
		return
	# The opening and the introduction own the screen and carry their own
	# answers; there is nothing under them for Escape to peel.
	if is_instance_valid(_intro_overlay) or is_instance_valid(_network_opening):
		return
	super._on_escape()


func toggle_menu() -> void:
	_toggle_pause()


func focus_action() -> void:
	if _built and not _pass_button.disabled: _pass_button.grab_focus()


func _on_pause_chosen(action: int) -> void:
	if action in [DuelPause.Action.EXIT_DUEL, DuelPause.Action.MAIN_MENU, DuelPause.Action.QUIT]:
		_close_pause()
		_request_exit()
	else: super._on_pause_chosen(action)


func _request_exit() -> void:
	if _room.has("tournament"):
		var dialog := _network_window("Tournament duel")
		var info := OriginalDialog.label("A concession ends this game, not the entire series. To withdraw from the tournament, use the Tournament Hall. The organiser must keep the host running.", 16)
		info.position = Vector2(24, 60)
		info.size = Vector2(510, 180)
		info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		dialog.add_child(info)
		dialog.add_button("Tournament").pressed.connect(func() -> void:
			dialog.dismiss()
			tournament_requested.emit())
		if not game.game_over:
			dialog.add_button("Concede game").pressed.connect(func() -> void:
				dialog.dismiss()
				_send({"op": "concede"}))
		else: dialog.add_button("Return to hall").pressed.connect(hall_requested.emit)
		return
	var dialog := _network_window("Leave SGManalink?")
	var label := OriginalDialog.label("Closing the host disconnects both players and ends this hosted session." if _hosting else "Closing forgets this seat. Concede first if you want to record a result.", 16)
	label.position = Vector2(24, 60)
	label.size = Vector2(510, 180)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	dialog.add_child(label)
	dialog.add_button("Confirm close").pressed.connect(exit_requested.emit)


## OK LEAVES THE ROOM, NOT SGMANALINK (bug pass 2026-10-03). It emitted
## exit_requested, which frees the whole lobby: the guest lost its seat
## and connection, and a host's server stopped with every other table's
## running duel — past the confirmation [method _request_exit] asks for.
## A finished room is left like any other; the referee allows it once the
## game is over, and the lobby comes back with its connection.
func _on_game_over_dismissed() -> void:
	super._on_game_over_dismissed()
	if _room.has("tournament"): hall_requested.emit()
	else: leave_requested.emit()
