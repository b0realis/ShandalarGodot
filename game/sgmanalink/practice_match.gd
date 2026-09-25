class_name SgPracticeMatch
extends RefCounted
## [QoL] Server-side referee for the explicitly limited, unrated local playtest.
## The client component never receives this object. The local host is trusted;
## its process contains the referee. Never serialize the game, agents, logs or RNG.
## The historical class name is retained for local fixtures; live rooms accept
## validated decks from the whole registry. No client paths or rules are loaded.

const CREATURES := ["Grizzly Bears", "Giant Spider", "War Mammoth",
	"Ironroot Treefolk", "Craw Wurm", "Durkwood Boars"]
var game := MtgGame.new()
var _handles: Array = [{}, {}]
var _ids: Array = [{}, {}]
var _next_handle: Array[int] = [1, 1]
var first_player := 0
var toss_winner := 0
var order_chosen := false
var cues: Array = []
var visual_events: Array = [[], []]
var _cue_serial := 0
var _object_handles: Array = [{}, {}]
var _object_serial: Array[int] = [0, 0]
var _used_objects: Array = [{}, {}]
var actions: SgDuelActions
var deck_names: Array = ["Forest practice", "Forest practice"]
var panel_colors: Array[String] = ["green", "green"]
var journal: SgJournal
var state_generation := 0
var bot_options: Array = [{}, {}]
var bots: Dictionary = {}


func set_bot(pid: int, options: Dictionary) -> bool:
	if pid not in [0, 1] or not game.mulligan_open or not SgBotPlayer.valid(options): return false
	var pilot := SgBotPlayer.create(pid, options)
	bot_options[pid] = options.duplicate(true)
	bots[pid] = pilot
	game.set_agent(pid, pilot)
	return true


func _init(seed_value := -1, decks: Array = [{}, {}], names: Array = ["Player 1", "Player 2"]) -> void:
	var deck: Array = []
	for i in 16:
		deck.append("Forest")
	for card_name in CREATURES:
		for i in 4:
			deck.append(card_name)
	var selected: Array = [deck, deck]
	for pid in 2:
		if not decks[pid].is_empty() and SgDeckCatalog.validate(decks[pid].cards, decks[pid].sideboard).is_empty():
			selected[pid] = decks[pid].cards
			deck_names[pid] = decks[pid].name
		# Cosmetic, public match metadata, computed once from the registered
		# list just as local setup does; never infer it from a hidden hand.
		panel_colors[pid] = DuelConfig.dominant_color(selected[pid])
	game.setup(selected[0], selected[1], names[0], names[1], 20, 20, seed_value)
	CardPrintings.apply_game(game, [decks[0].get("printings", {}), decks[1].get("printings", {})])
	actions = SgDuelActions.new(game)
	game.rules.mana_burn = true
	# Free assignment avoids a silent ordering decision by the base agent.
	game.rules.free_damage_assignment = true
	game.interactive_choices = true
	game.set_agent(0, HumanAgent.new())
	game.set_agent(1, HumanAgent.new())
	first_player = game.rng.randi_range(0, 1)
	toss_winner = first_player
	game.deal_opening_hands()
	game.state_changed.connect(_on_state_changed)
	game.event_occurred.connect(_on_event)
	journal = SgJournal.new(game)


func _on_event(event: GameEvent) -> void:
	if game.is_probing(): return
	var cue := DuelAudio.cue_for(event)
	if not cue.is_empty():
		_cue_serial += 1
		cues.append({"serial": _cue_serial, "cue": cue})
		if cues.size() > 64: cues.pop_front()
	if event.type in [Mtg.EventType.DIES, Mtg.EventType.CARD_DRAWN]:
		var card: CardInstance = event.data.get("instance")
		for viewer in 2:
			if not _visible(viewer, card): continue
			visual_events[viewer].append({"serial": _cue_serial,
				"kind": "dies" if event.type == Mtg.EventType.DIES else "draw",
				"card": _handle(viewer, card), "sacrificed": bool(event.data.get("sacrificed", false))})
			if visual_events[viewer].size() > 64: visual_events[viewer].pop_front()
	_retire_hidden()


func _on_state_changed() -> void:
	if game.is_probing(): return
	state_generation += 1
	_retire_hidden()


func _visible(pid: int, card: CardInstance) -> bool:
	return card != null and (card.zone in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD, Mtg.Zone.STACK, Mtg.Zone.EXILE, Mtg.Zone.ANTE] \
		or (card.zone == Mtg.Zone.HAND and (card.owner_id == pid or card.revealed_in_hand \
			or game.players[card.owner_id].hand_revealed)))


func _retire_hidden() -> void:
	if game.is_probing(): return
	for pid in 2:
		for id in _handles[pid].keys():
			var card := game.find_instance(id)
			# Keep continuity across public moves for the shared spell flight.
			# Hidden moves retire the token, including a return to a library.
			if not _visible(pid, card):
				_ids[pid].erase(_handles[pid][id])
				_handles[pid].erase(id)


func _handle(pid: int, card: CardInstance) -> String:
	if not _handles[pid].has(card.id):
		var handle := "c%d" % _next_handle[pid]
		_next_handle[pid] += 1
		_handles[pid][card.id] = handle
		_ids[pid][handle] = card.id
	return _handles[pid][card.id]


func _card(pid: int, handle: String) -> CardInstance:
	var card := game.find_instance(int(_ids[pid].get(handle, -1)))
	return card if _visible(pid, card) else null


func _cards(pid: int, list: Array) -> Array:
	var out: Array = []
	for card: CardInstance in list:
		var blocked := game.find_instance(int(game.combat.blocks.get(card.id, -1)))
		# A blocker stays blocking after its attacker leaves combat. Never turn
		# that historical engine reference into a new hidden-zone card handle.
		var blocking := ""
		if blocked != null and blocked.zone == Mtg.Zone.BATTLEFIELD and game.combat.attackers.has(blocked.id):
			blocking = _handle(pid, blocked)
		var masked := card.face_down and not (card.zone == Mtg.Zone.EXILE and card.exile_visible_to == pid)
		# An attachment is a link between two cards THIS seat holds: the aura
		# gets no slot of its own and its host draws it again. Name a host only
		# while this seat can see it, exactly as the blocking link above does,
		# so a handle is never minted for a card outside this view.
		var host := game.find_instance(card.attached_to)
		var attached := _handle(pid, host) if host != null and _visible(pid, host) else ""
		var chosen := ""
		if not masked and card.data.chosen_type_key != "" and card.memory.has(card.data.chosen_type_key):
			chosen = String(card.memory[card.data.chosen_type_key]).capitalize()
			if chosen.is_empty(): chosen = "No creatures"
		out.append({"id": _handle(pid, card), "name": "Face-down creature" if masked else card.data.card_name,
			"rules": "" if masked else card.data.oracle_text, "land": card.is_land(),
			"printing": "" if masked else CardPrintings.of(card),
			"power": card.cur_power, "toughness": card.cur_toughness,
			# The PRINTED pair beside the live one. A guest reads a named
			# card's print off its own registry, but a TOKEN has no entry
			# there — so without this every token's P/T inked green
			# ("pumped") and its enlarged card read 0/0. A masked face
			# sends zeros: the print is exactly what the mask hides.
			"print_power": 0 if masked else card.data.power,
			"print_toughness": 0 if masked else card.data.toughness,
			"tapped": card.tapped, "sick": card.summoning_sick,
			"damage": card.damage, "attacking": game.combat.attackers.has(card.id),
			"blocking": blocking,
			"playable": _playable(pid, card), "creature": card.is_creature(),
			"owner": card.owner_id, "controller": card.controller_id, "masked": masked,
			"types": card.cur_types, "colors": card.cur_colors, "keywords": Array(card.cur_keywords),
			"subtypes": Array(card.cur_subtypes), "counters": card.counters.duplicate(),
			"protection": card.cur_protection, "landwalk": Array(card.cur_landwalk),
			"rampage": card.cur_rampage, "prevention": card.prevention,
			"regeneration": card.regeneration_shields, "chosen": chosen,
			"warded": false if masked else _warded_from_artifacts(card),
			"shield": "" if card.prevention <= 0 or card.prevention_source == null \
				else card.prevention_source.card_name,
			"text_effects": [] if masked else _text_effects(card),
			"attached": attached,
			"abilities": [] if masked else _abilities(card),
			"actions": [] if masked else SgDuelActions.options(card, pid, game),
			"exile_playable": game.can_play_from_exile(pid, card)})
		if masked and card.zone != Mtg.Zone.BATTLEFIELD:
			var hidden: Dictionary = out.back()
			hidden.name = "Face-down card"
			for key in ["types", "colors", "power", "toughness", "print_power", "print_toughness", "protection", "rampage", "prevention", "regeneration", "damage"]: hidden[key] = 0
			for key in ["keywords", "subtypes", "landwalk", "abilities"]: hidden[key] = []
			hidden.counters = {}
			hidden.shield = ""
			hidden.land = false
			hidden.creature = false
	return out


## PROTECTION FROM ARTIFACTS, as the board's badge asks it: the two
## source-filtered clauses Artifact Ward raises (damage from artifact
## sources is prevented AND artifact sources may not target it), each a
## `desc` and a Callable on the live lists. One bool crosses — the
## filters never do — and the guest's [SgCardPresentation] rebuilds the
## same two descs for [method MiniCard.warded_from_artifacts] to find.
func _warded_from_artifacts(card: CardInstance) -> bool:
	return _names_artifacts(card.cur_damage_immunity) and _names_artifacts(card.cur_target_bans)


static func _names_artifacts(entries: Array) -> bool:
	for entry in entries:
		if String(entry.get("desc", "")).contains("artifact"): return true
	return false


## The LIVE activated abilities as the board badges them — a cost and
## whether it regenerates — so a grant (Zombie Master) or a silence
## (Titania's Song) shows at both seats. Nothing executable crosses.
func _abilities(card: CardInstance) -> Array:
	var out: Array = []
	for ability in card.cur_activated_abilities:
		var regen := false
		for effect in ability.effects:
			if effect is RegenerateEffect and effect.target_spec == null: regen = true
		out.append({"cost": ability.cost.text, "regen": regen})
	return out


func _text_effects(card: CardInstance) -> Array:
	if card.zone not in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.STACK]:
		return []
	# Only public reminder facts, never the card's arbitrary private memory.
	var effects := card.text_changes.duplicate(true)
	if card.memory.has("shaman_circle_color"):
		effects.append({"kind": "circle_color", "to": card.memory.shaman_circle_color})
	return effects.slice(-SgProtocol.MAX_CARDS)


func _playable(pid: int, card: CardInstance) -> bool:
	if not ((card.owner_id == pid and card.zone == Mtg.Zone.HAND) or game.can_play_from_exile(pid, card)) or game.game_over \
		or game.mulligan_open or game.priority_player != pid:
		return false
	if card.is_land():
		return game.active_player == pid and Mtg.is_main_step(game.current_step()) \
			and game.stack.is_empty() and game.land_drop_available(pid) \
			and game.hand_lock_reason(card).is_empty() and game.play_banned(pid, card.data).is_empty() and game.entry_refused(card, pid).is_empty()
	return game.cast_timing_refusal(pid, card).is_empty() and SgPayment.affordable(game, pid, card)


func decision_state() -> Dictionary:
	if game.game_over: return {"mode": "finished", "actor": -1}
	if game.mulligan_open: return {"mode": "opening", "actor": first_player if not game.mulligan_kept[first_player] else 1 - first_player}
	if game.awaiting_choice != null: return {"mode": "choice", "actor": game.awaiting_choice.pid}
	if game.awaiting_attackers: return {"mode": "attack", "actor": game.active_player}
	if game.awaiting_blockers: return {"mode": "block", "actor": game.block_chooser()}
	if game.awaiting_discard: return {"mode": "discard", "actor": game.active_player}
	if game.awaiting_damage_assignment: return {"mode": "damage", "actor": int(game.damage_assignment_request().assigner)}
	return {"mode": "priority", "actor": game.priority_player}


func view(pid: int) -> Dictionary:
	if pid not in [0, 1]:
		return {}
	if actions.game != game: actions = SgDuelActions.new(game)
	if journal == null or journal.game != game: journal = SgJournal.new(game)
	journal.observe()
	if not game.state_changed.is_connected(_on_state_changed): game.state_changed.connect(_on_state_changed)
	if not game.event_occurred.is_connected(_on_event): game.event_occurred.connect(_on_event)
	_retire_hidden()
	_used_objects[pid].clear()
	var players: Array = []
	for seat in 2:
		var player := game.players[seat]
		var mana: Array = []
		for color in [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G, Mtg.ManaColor.C]:
			mana.append(player.mana_pool.total_of(color))
		var revealed: Array = []
		for card in player.hand:
			if player.hand_revealed or card.revealed_in_hand: revealed.append(card)
		var top := game.revealed_top_card(seat)
		players.append({"seat": seat, "life": player.life, "deck_name": deck_names[seat],
			"hand_count": player.hand.size(), "library_count": player.library.size(),
			"mana": player.mana_pool.total(), "kept": game.mulligan_kept[seat],
			"mana_colors": mana, "revealed": _cards(pid, revealed),
			"top": "" if top == null else top.data.card_name,
			"exile": _cards(pid, player.exile), "ante": _cards(pid, player.ante),
			"battlefield": _cards(pid, player.battlefield),
			"graveyard": _cards(pid, player.graveyard)})
	var stack: Array = []
	for item in game.stack:
		var details: String = ["Spell", "Activated ability", "Triggered ability"][item.kind]
		var targets: Array = []
		if not item.target_held:
			var divisions: Array = []
			var group := 0
			for effect in item.effects:
				if effect.target_spec == null: continue
				if effect.divided_amount(item.x_value) > 0 and group < item.target_groups.size():
					divisions.append_array(item.target_groups[group])
				group += 1
			for target in item.targets:
				targets.append(actions.target_label(target, pid) + (" — %d points" % target.amount if divisions.has(target) else ""))
			var modes: Array = item.card.data.modes if item.card != null and item.kind == Mtg.StackKind.SPELL \
				else (item.trigger.modes if item.trigger != null else [])
			if item.mode >= 0 and item.mode < modes.size():
				details += " — " + String(modes[item.mode].get("label", "Chosen mode"))
		else: details += " — choosing mode or targets"
		stack.append({"name": "Effect" if item.card == null else ("Face-down creature" if item.card.face_down else item.card.data.card_name),
			"controller": item.controller, "details": details, "x": item.x_value, "targets": targets})
	var decision := decision_state()
	var mode: String = decision.mode
	var actor: int = decision.actor
	var damage: Dictionary = {}
	if mode == "damage":
		var request := game.damage_assignment_request()
		actor = int(request.assigner)
		if actor == pid:
			var targets: Array = []
			for id: int in request.targets:
				var card := game.find_instance(id)
				if card != null:
					targets.append({"id": _handle(pid, card), "name": "Face-down creature" if card.face_down else card.data.card_name,
						"lethal": maxi(0, card.cur_toughness - card.damage \
							- int(request.assigned.get(id, 0)))})
			if bool(request.trample) or not String(request.get("special", "")).is_empty():
				targets.append({"id": "player", "name": "Opponent", "lethal": 0})
			damage = {"source": "Face-down creature" if request.source.face_down else request.source.data.card_name,
				"amount": int(request.amount), "targets": targets}
	var result := {"players": players, "hand": _cards(pid, game.players[pid].hand),
		"stack": stack, "mode": mode, "actor": actor, "active": game.active_player,
		"turn": game.turn_number, "step": Mtg.Step.keys()[game.current_step()],
		"first": first_player, "winner": game.winner, "draw": game.is_draw,
		"discard_count": game.discard_count, "damage_request": damage,
		"choice": actions.choice_view(pid), "announcement": actions.request(pid),
		"information": actions.information[pid].duplicate(true), "specials": actions.specials(pid),
		"journal": journal.entries[pid].duplicate(true)}
	result.presentation = SgDuelPresentation.build(self, pid, result)
	for key in _object_handles[pid].keys():
		if not _used_objects[pid].has(key): _object_handles[pid].erase(key)
	return result


func act(pid: int, action: Dictionary) -> String:
	if actions.game != game: actions = SgDuelActions.new(game)
	if pid not in [0, 1]:
		return "No such seat."
	var op := String(action.op)
	if op == "concede":
		return game.concede(pid)
	var state := decision_state()
	if state.actor != pid:
		return "Wait for your decision."
	if game.mulligan_open:
		if op == "order":
			if order_chosen or pid != toss_winner: return "The opening order is already decided."
			first_player = pid if action.play else 1 - pid
			order_chosen = true
			return ""
		# Refuse everything else BEFORE the implied order below. Every op is a
		# legal wire command at any moment, and spending the toss winner's
		# play/draw choice on one the referee then refuses left the opening
		# offering neither the order nor a mulligan ever again.
		if op not in ["keep", "mulligan"]:
			return "Keep or redraw your opening hand."
		# Older scripted fixtures may keep directly; live UI always offers the order.
		if not order_chosen:
			order_chosen = true
		if op == "mulligan":
			var result := game.take_mulligan(pid)
			if result.is_empty():
				# Retire hidden-zone handles when the opening hand is shuffled.
				_handles[pid].clear()
				_ids[pid].clear()
			return result
		var kept := game.decline_mulligan(pid)
		if game.mulligan_kept[0] and game.mulligan_kept[1]:
			game.start_duel(first_player)
		return kept
	match op:
		"mana":
			var card := _card(pid, action.card)
			if card == null: return "Card unavailable."
			return game.tap_for_mana(pid, card, int(action.index))
		"autopay", "autoprepare":
			var excluded := {}
			for handle in action.excluded:
				var card := _card(pid, handle)
				if card != null: excluded[card.id] = true
			return actions.autopay(pid, excluded, int(action.count)) if op == "autopay" \
				else actions.auto_prepare(pid, _card(pid, action.card), action, excluded)
		"special":
			if state.mode != "priority": return "Wait for priority."
			return actions.special(pid, int(action.index))
		"choice": return actions.answer(pid, action.picks)
		"cancel":
			if game.awaiting_choice != null:
				var error := game.cancel_choice()
				if not error.is_empty(): return error
			actions.clear()
			return ""
		"prepare": return actions.prepare(pid, _card(pid, action.card), action)
		"submit": return actions.submit(pid, action.targets)
		"pass":
			actions.clear()
			return game.pass_priority(pid)
		"play", "tap":
			var card := _card(pid, action.card)
			if card == null:
				return "Card unavailable."
			if op == "tap":
				if not game.players[pid].battlefield.has(card) or not card.is_land():
					return "Card unavailable."
				return game.tap_for_mana(pid, card)
			if not game.players[pid].hand.has(card) and not game.can_play_from_exile(pid, card):
				return "Card unavailable."
			return game.play_land(pid, card) if card.is_land() else game.cast_spell(pid, card)
		"attack", "attack_bands", "discard":
			var picked: Array = []
			for handle: String in action.cards:
				var card := _card(pid, handle)
				var zone: Array = game.players[pid].hand if op == "discard" \
					else game.players[pid].battlefield
				if card == null or not zone.has(card) or picked.has(card):
					return "Card unavailable or selected twice."
				picked.append(card)
			if op == "discard":
				return game.discard_to_hand_size(pid, picked)
			var ids: Array = []
			for card: CardInstance in picked:
				ids.append(card.id)
			var bands: Array = []
			for band in action.get("bands", []):
				var members: Array = []
				for handle in band:
					var card := _card(pid, handle)
					if card == null or not ids.has(card.id): return "Band member unavailable."
					members.append(card.id)
				bands.append(members)
			return game.declare_attackers(pid, ids, bands)
		"block":
			var blocks := {}
			for pair: Array in action.pairs:
				var blocker := _card(pid, pair[0])
				var attacker := _card(pid, pair[1])
				if blocker == null or attacker == null \
					or not game.players[1 - game.active_player].battlefield.has(blocker) \
					or not game.combat.attackers.has(attacker.id):
					return "Block unavailable or selected twice."
				if not blocks.has(blocker.id): blocks[blocker.id] = []
				if blocks[blocker.id].has(attacker.id): return "Block selected twice."
				blocks[blocker.id].append(attacker.id)
			return game.declare_blockers(pid, blocks)
		"damage":
			if not game.awaiting_damage_assignment:
				return "No damage assignment is waiting."
			var split := {}
			var request := game.damage_assignment_request()
			for pair: Array in action.points:
				var id := MtgGame.DAMAGE_TO_PLAYER
				if pair[0] != "player":
					var card := _card(pid, pair[0])
					if card == null or not request.targets.has(card.id):
						return "Damage target unavailable."
					id = card.id
				if split.has(id):
					return "Duplicate damage target."
				split[id] = int(pair[1])
			return game.assign_combat_damage(pid, split)
	return "Action unavailable in this duel."
