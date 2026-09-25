class_name SgDuelActions
extends RefCounted
## [QoL] Referee-owned announcements and private questions. Only bounded labels
## and opaque target tokens cross the wire; Callables and engine ids never do.

var game: MtgGame
var draft: Dictionary = {}
var _targets: Dictionary = {}
var information: Array = [[], []]
var _auto_payment: Dictionary = {}


func _init(referee: MtgGame) -> void:
	game = referee
	game.information_revealed.connect(_information_received)


func _information_received(viewer: int, title: String, names: Array) -> void:
	for pid in 2:
		if viewer != -1 and viewer != pid: continue
		information[pid].append({"title": title, "cards": names.duplicate()})
		if information[pid].size() > 12: information[pid].pop_front()


static func options(card: CardInstance, pid: int, referee: MtgGame = null) -> Array:
	var result: Array = []
	var spell_source := (card.zone == Mtg.Zone.HAND and card.owner_id == pid) \
		or (card.zone == Mtg.Zone.EXILE and not card.face_down and card.exile_playable_by == pid)
	if spell_source and not card.is_land():
		var modes: Array = []
		for mode in card.data.modes:
			modes.append(String(mode.get("label", mode.get("name", "Mode"))))
		result.append({"kind": "spell", "index": 0, "label": "Cast " + card.data.card_name,
			"x": card.data.cost.has_x or not card.data.repeated_additional_cost.is_empty(), "modes": modes})
	var borrowed := referee != null and referee.may_tap_foreign_land(pid, card)
	if borrowed or (card.zone == Mtg.Zone.BATTLEFIELD and card.controller_id == pid) or (card.zone == Mtg.Zone.HAND and card.owner_id == pid):
		for i in card.cur_mana_abilities.size():
			if borrowed and not referee.may_tap_foreign_land(pid, card, i): continue
			if card.cur_mana_abilities[i].activation_zone != card.zone: continue
			result.append({"kind": "mana", "index": i, "label": str(referee.mana_ability_for(pid, card, i) if referee != null else card.cur_mana_abilities[i]), "x": false, "modes": []})
	if card.zone not in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD]: return result
	for i in card.cur_activated_abilities.size():
		var ability: ActivatedAbility = card.cur_activated_abilities[i]
		if ability.activation_zone != card.zone: continue
		var permitted := ability.any_player_may_activate \
			or (ability.only_owner_may_activate and card.owner_id == pid) \
			or (ability.only_opponents_may_activate and card.controller_id != pid) \
			or (not ability.only_owner_may_activate and not ability.only_opponents_may_activate and card.controller_id == pid)
		if permitted:
			result.append({"kind": "ability", "index": i, "label": str(ability),
				"x": ability.cost.has_x, "modes": []})
	return result


func prepare(pid: int, card: CardInstance, action: Dictionary) -> String:
	if card == null or game.priority_player != pid or game.awaiting_choice != null:
		return "This action is unavailable."
	var found := false
	for option in options(card, pid, game):
		if option.kind == action.kind and option.index == action.index:
			if (not option.x and action.x != 0) or action.mode >= maxi(1, option.modes.size()):
				return "Invalid mode or X."
			found = true
	if not found: return "This action is unavailable."
	if action.kind == "spell":
		var error := game.cast_timing_refusal(pid, card)
		if not error.is_empty(): return error
	draft = {"pid": pid, "card": card, "kind": action.kind, "index": int(action.index),
		"x": int(action.x), "mode": int(action.mode)}
	_auto_payment.clear()
	return ""


func clear() -> void:
	draft.clear()
	_targets.clear()
	_auto_payment.clear()


func auto_prepare(pid: int, card: CardInstance, action: Dictionary, excluded: Dictionary) -> String:
	# Auto-cast may spend mana, never choose how much life the player loses.
	if card != null and action.kind == "spell" and card.data.additional_life_is_x:
		return "Choose the life payment explicitly."
	var request_data := action.duplicate()
	request_data.x = 0
	var error := prepare(pid, card, request_data)
	if not error.is_empty(): return error
	var cost: ManaCost = card.data.payment_base(draft.mode) if draft.kind == "spell" else card.cur_activated_abilities[draft.index].cost
	if cost.has_x or (draft.kind == "spell" and not card.data.repeated_additional_cost.is_empty()):
		draft.x = SgPayment.budget(game, pid, card, draft.kind, draft.index, ManaPlanner.sources(game, pid, excluded), action.count, draft.mode)
	return autopay(pid, excluded, action.count)


func special_entries(pid: int) -> Array:
	var entries: Array = []
	if game.players[pid].life_for_mana:
		entries.append({"label": "Channel — pay 1 life for one colorless mana", "kind": "channel"})
	for entry in game.players[pid].paid_prevention:
		entries.append({"label": "Pay {1}: prevent 1 damage to " + target_label(entry.target, pid),
			"kind": "prevention", "target": entry.target})
	for entry in game.settleable_delayed_triggers(pid):
		entries.append({"label": "Pay %s: %s" % [entry.settle_cost, entry.desc], "kind": "settle", "id": entry.id})
	return entries


func specials(pid: int) -> Array:
	var labels: Array = []
	for entry in special_entries(pid): labels.append(entry.label)
	return labels


func special(pid: int, index: int) -> String:
	var entries := special_entries(pid)
	if index < 0 or index >= entries.size(): return "That special action is no longer available."
	var entry: Dictionary = entries[index]
	match entry.kind:
		"channel": return game.pay_life_for_mana(pid)
		"prevention": return game.pay_for_prevention(pid, entry.target)
		"settle": return game.settle_delayed_trigger(pid, entry.id)
	return "Action unavailable."


func request(pid: int) -> Dictionary:
	if draft.is_empty() or draft.pid != pid: return {}
	var source: CardInstance = draft.card
	var slots: Array = []
	var effects: Array = []
	if draft.kind == "spell":
		if source.data.is_aura():
			slots.append({"spec": source.data.aura_target, "min": 1, "max": 1, "divided": 0})
		else:
			effects = source.data.spell_effects if not source.data.is_modal() else source.data.modes[draft.mode].effects
	elif draft.kind == "ability":
		if draft.index >= source.cur_activated_abilities.size(): return {}
		effects = source.cur_activated_abilities[draft.index].effects
	for effect in effects:
		if effect.target_spec == null or not effect.target_spec.is_supplied_by_caster(): continue
		var span: Vector2i = effect.target_range(draft.x)
		slots.append({"spec": effect.target_spec, "min": span.x, "max": span.y,
			"clamp": effect.target_count_is_x, "divided": maxi(0, effect.divided_amount(draft.x))})
	_targets.clear()
	var result: Array = []
	for slot in slots:
		var candidates: Array = []
		for target: TargetRef in game.legal_targets_at(slot.spec, source, draft.x):
			var token := "t%d" % _targets.size()
			_targets[token] = target
			candidates.append({"id": token, "label": target_label(target, pid)})
		var minimum: int = slot.min
		var maximum: int = slot.max
		if maximum < 0: maximum = candidates.size()
		if slot.get("clamp", false):
			minimum = mini(minimum, candidates.size())
			maximum = mini(maximum, candidates.size())
		result.append({"label": slot.spec.description, "kind": slot.spec.kind, "min": minimum, "max": maximum,
			"divided": slot.divided, "targets": candidates})
	return {"name": source.data.card_name, "kind": draft.kind, "x": draft.x, "slots": result}


func target_label(target: TargetRef, pid: int) -> String:
	if target.is_player: return "You" if target.player_id == pid else "Opponent"
	if target.is_damage:
		var packet := game.find_packet(target.packet_id)
		if packet == null: return "Damage no longer pending"
		return "Damage %d: %s" % [packet.amount, target_label(packet.target, pid)]
	if target.is_ability:
		var item := game.find_stack_ability(target.ability_id)
		if item == null: return "Ability no longer on stack"
		return "Ability: " + (item.card.data.card_name if item.card != null and not item.card.face_down else "Face-down card")
	var card := game.find_instance(target.instance_id)
	if card == null: return "Unavailable"
	if card.zone == Mtg.Zone.LIBRARY: return "Hidden card"
	if card.zone == Mtg.Zone.HAND and card.owner_id != pid \
		and not card.revealed_in_hand and not game.players[card.owner_id].hand_revealed:
		return "Card no longer in a public zone"
	return "%s — %s%s" % ["Face-down creature" if card.face_down else card.data.card_name,
		"yours" if card.controller_id == pid else "opponent's",
		" (tapped)" if card.tapped else ""]


func submit(pid: int, values: Array) -> String:
	if draft.is_empty() or draft.pid != pid: return "No announcement is waiting."
	# Rebuild from the current state: a stale candidate can never become authority.
	request(pid)
	var refs: Array = []
	for pair in values:
		if not _targets.has(pair[0]): return "Target unavailable."
		refs.append((_targets[pair[0]] as TargetRef).with_amount(int(pair[1])))
	draft["count"] = maxi(1, refs.size())
	var error := ""
	match draft.kind:
		"spell": error = game.cast_spell(pid, draft.card, refs, draft.x, draft.mode)
		"ability": error = game.activate_ability(pid, draft.card, draft.index, refs, draft.x)
		"mana":
			if not refs.is_empty(): return "Mana abilities do not take targets."
			error = game.tap_for_mana(pid, draft.card, draft.index)
	if error.is_empty(): clear()
	return error


func payment(count := 1) -> Dictionary:
	if draft.is_empty() or draft.kind == "mana": return {}
	if draft.kind == "spell":
		return game.spell_payment(draft.pid, draft.card.data, draft.x, count, draft.card, draft.mode)
	return game.ability_payment(draft.pid, draft.card, draft.index, draft.x)


func autopay(pid: int, excluded: Dictionary, count: int) -> String:
	if draft.is_empty() or draft.pid != pid: return "No announcement is waiting."
	if game.awaiting_choice != null: return "Answer the pending question first."
	_auto_payment.clear()
	var due := payment(count)
	if due.is_empty(): return "This action has no mana payment."
	# The auto-tap's own view of the sources: a Fellwar Stone with several
	# colours on offer is generic-only here, so its tap asks the seat what
	# kind of mana instead of picking a colour for them (2026-09-17).
	var plan := ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(game, pid, excluded),
		due.cost, int(due.extra), due.usage)
	for step in plan:
		if step[0] == null: continue
		var error := ManaPlanner.run_step(game, pid, step)
		if not error.is_empty(): return error
		if game.awaiting_choice != null:
			_auto_payment = {"pid": pid, "excluded": excluded.duplicate(), "count": count}
			break
	return ""


func payment_reachable() -> bool:
	var due := payment(int(draft.get("count", 1)))
	if due.is_empty(): return true
	return SgPayment.can_pay_now(game, draft.pid, due, draft.kind) \
		or not ManaPlanner.plan(game, draft.pid, due.cost, int(due.extra), due.usage).is_empty()


## Hidden-zone questions disclose only the rule-authorized list, sorted by
## name (never library order). Tokens exist only for this question/revision.
func _choice_entries() -> Array:
	var question := game.awaiting_choice
	var entries: Array = []
	if question == null: return entries
	match question.kind:
		PlayerChoice.Kind.YES_NO:
			entries = [{"label": "Yes", "answer": true}, {"label": "No", "answer": false}]
		PlayerChoice.Kind.COLOR:
			var colors: Array = Array(question.colors) if not question.colors.is_empty() \
				else [Mtg.ManaColor.W, Mtg.ManaColor.U, Mtg.ManaColor.B, Mtg.ManaColor.R, Mtg.ManaColor.G]
			for color in colors: entries.append({"label": Mtg.COLOR_NAMES[color], "answer": color})
		PlayerChoice.Kind.OPTION:
			for i in question.options.size(): entries.append({"label": question.options[i], "answer": i})
		PlayerChoice.Kind.CARD, PlayerChoice.Kind.DISCARD:
			var seen := {}
			for card in question.candidates:
				var public_card: bool = card.zone == Mtg.Zone.BATTLEFIELD
				if question.kind == PlayerChoice.Kind.CARD and not public_card and seen.has(card.data.card_name): continue
				seen[card.data.card_name] = true
				entries.append({"label": target_label(TargetRef.card(card), question.pid) if public_card else card.data.card_name,
					"answer": card.id if public_card else card.data.card_name})
			entries.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.label < b.label)
			for i in entries.size():
				if entries[i].answer is int: entries[i].label += " [choice %d]" % (i + 1)
			if question.kind == PlayerChoice.Kind.CARD and question.optional:
				entries.append({"label": "Choose none", "answer": ""})
	return entries


func choice_view(pid: int) -> Dictionary:
	var question := game.awaiting_choice
	if question == null or question.pid != pid: return {}
	var labels: Array = []
	for entry in _choice_entries(): labels.append(entry.label)
	var shown: Array = []
	for info in question.information:
		if info.viewer in [-1, pid]: shown.append({"title": info.title, "cards": info.cards.duplicate()})
	return {"prompt": question.prompt, "source": question.source, "options": labels, "information": shown,
		"count": mini(question.count, labels.size()) if question.kind == PlayerChoice.Kind.DISCARD else 1,
		"cancel": question.is_cost and not question.adverse}


func answer(pid: int, picks: Array) -> String:
	var question := game.awaiting_choice
	if question == null or question.pid != pid: return "No question is waiting for you."
	var entries := _choice_entries()
	var count := mini(question.count, entries.size()) if question.kind == PlayerChoice.Kind.DISCARD else 1
	if picks.size() != count: return "Choose exactly %d option(s)." % count
	var answers: Array = []
	var seen := {}
	for index in picks:
		if index < 0 or index >= entries.size() or seen.has(int(index)): return "Invalid or repeated choice."
		seen[int(index)] = true
		answers.append(entries[int(index)].answer)
	var error := game.answer_choice(answers if question.kind == PlayerChoice.Kind.DISCARD else answers[0])
	if error.is_empty() and game.awaiting_choice == null and not _auto_payment.is_empty():
		var resume := _auto_payment.duplicate(true)
		return autopay(resume.pid, resume.excluded, resume.count)
	return error
