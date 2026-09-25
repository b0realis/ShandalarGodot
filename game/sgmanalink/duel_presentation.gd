class_name SgDuelPresentation
extends RefCounted
## A deliberate allowlist for the existing duel renderer. Never a snapshot.
## References are viewer-local capabilities, not engine ids. Even the host's
## UI consumes this filtered representation instead of its referee object.

const FLAGS := ["cur_extra_blocks", "extra_blocks_this_turn", "cur_cant_attack",
	"cur_attacks_as_if_hasty", "cur_must_be_blocked", "must_attack_this_turn",
	"cur_indestructible", "cur_skips_untap", "skip_next_untap", "skip_untaps"]
## The rows of [constant FLAGS] that carry a COUNT rather than a yes/no.
## `-1` is "any number" on either block permission — the static one and
## Blaze of Glory's grant for the turn.
const COUNTED_FLAGS := ["cur_extra_blocks", "extra_blocks_this_turn", "skip_untaps"]
const RULES := ["mana_burn", "attackers_revocable", "tapped_artifacts_stop",
	"life_checked_at_phase_end", "pool_empties_on_attack", "free_damage_assignment",
	"damage_prevention_window"]
const CUES := ["sfx_cast", "sfx_land", "sfx_draw", "sfx_tap", "sfx_attack",
	"sfx_block", "sfx_life_loss", "sfx_damage", "sfx_mana_burn", "sfx_buried", "sfx_discard",
	"sfx_summon", "sfx_cast_artifact", "sfx_cast_enchantment", "sfx_cast_sorcery",
	"sfx_cast_interrupt", "sfx_cast_instant", "sfx_land_grey"]


static func object_handle(match_state: SgPracticeMatch, pid: int, kind: String, id: int) -> String:
	var key := kind + str(id)
	var handles: Dictionary = match_state._object_handles[pid]
	match_state._used_objects[pid][key] = true
	if not handles.has(key):
		match_state._object_serial[pid] += 1
		handles[key] = "o%d" % match_state._object_serial[pid]
	return handles[key]


static func target_reference(m: SgPracticeMatch, pid: int, target: TargetRef) -> Dictionary:
	if target == null: return {}
	if target.is_player: return {"kind": "player", "id": str(target.player_id), "amount": target.amount}
	if target.is_ability:
		return {"kind": "ability", "id": object_handle(m, pid, "ability", target.ability_id), "amount": target.amount}
	if target.is_damage:
		return {"kind": "damage", "id": object_handle(m, pid, "damage", target.packet_id), "amount": target.amount}
	var card := m.game.find_instance(target.instance_id)
	if not m._visible(pid, card): return {}
	return {"kind": "card", "id": m._handle(pid, card), "amount": target.amount}


static func build(m: SgPracticeMatch, pid: int, view: Dictionary) -> Dictionary:
	var g := m.game
	var sources := ManaPlanner.sources(g, pid)
	var budgets := {}
	var result := {"priority": g.priority_player, "toss": m.toss_winner, "order": m.order_chosen,
		"rules": {}, "cues": m.cues.duplicate(true), "events": m.visual_events[pid].duplicate(true), "cards": [], "players": [],
		"chain": [], "packets": [], "bands": [], "blocks": [], "blocked": [],
		"attackable": [], "blockable": [], "assignment": {}, "targets": [],
		"prevention": g.awaiting_damage_prevention, "regeneration": g.awaiting_regeneration,
		"doomed": [], "draft": {}, "respond": false, "floating": false,
		"untap_capped": not g.untap_caps.is_empty()}
	for key in RULES: result.rules[key] = g.rules.get(key)
	for seat in 2:
		var p := g.players[seat]
		# The land drop as the whole rule, not just the counter: a seat's
		# allowance (Storm Cauldron's extra play, Fastbond's "any number")
		# is what MtgGame.land_drop_available reads beside it, and without
		# both the other end can only ever offer the turn's first land.
		result.players.append({"poison": p.poison, "lands": p.lands_played_this_turn,
			"extra_lands": int(g.extra_land_plays.get(seat, 0)),
			"unlimited_lands": g.unlimited_land_plays.has(seat),
			"hand_revealed": p.hand_revealed, "color": m.panel_colors[seat],
			"damage_effects": g.player_damage_effects(seat)})
		var visible: Array = p.battlefield + p.graveyard + p.exile + p.ante
		for card in p.hand:
			if m._visible(pid, card): visible.append(card)
		for card: CardInstance in visible:
			var row := {"id": m._handle(pid, card), "flags": {}, "abilities": [], "castable": false}
			for key in FLAGS:
				row.flags[key] = (0 if key in COUNTED_FLAGS else false) if card.face_down and card.zone != Mtg.Zone.BATTLEFIELD else card.get(key)
			if (card.zone == Mtg.Zone.HAND and card.owner_id == pid) or g.can_play_from_exile(pid, card):
				row.castable = g.cast_timing_refusal(pid, card).is_empty() and SgPayment.affordable(g, pid, card, true)
				if card.data.is_type(Mtg.CardType.INSTANT):
					result.floating = result.floating or SgPayment.affordable(g, pid, card)
					result.respond = result.respond or (SgPayment.affordable(g, pid, card, true) and has_aim(g, card))
			for option in ([] if card.face_down else SgDuelActions.options(card, pid, g)):
				var cost: ManaCost = card.data.cost if option.kind == "spell" else ManaCost.new()
				if option.kind == "ability": cost = card.cur_activated_abilities[option.index].cost
				var budget := 0
				if option.x:
					var key := card.data.card_name if option.kind == "spell" else "%d/%d" % [card.id, option.index]
					if not budgets.has(key): budgets[key] = SgPayment.budget(g, pid, card, option.kind, option.index, sources)
					budget = budgets[key]
				row.abilities.append({"kind": option.kind, "index": option.index, "cost": str(cost), "budget": budget})
				if option.kind == "ability":
					var ability: ActivatedAbility = card.cur_activated_abilities[option.index]
					if DuelScreen._ability_usable(card, ability) and g.can_afford_cost(pid, cost):
						result.respond = true
						result.floating = true
			result.cards.append(row)
			if card.zone == Mtg.Zone.BATTLEFIELD and card.controller_id == pid:
				if CombatState.attack_illegality(g, card, 1 - pid).is_empty(): result.attackable.append(row.id)
			if card.zone == Mtg.Zone.BATTLEFIELD and card.controller_id == 1 - g.active_player and g.block_chooser() == pid:
				var legal: Array = []
				for attacker_id in g.combat.attackers:
					var attacker := g.find_instance(attacker_id)
					# The VIEWER, not the defender: Melee hands the declaration to
					# the attacker, and a blocking tax (Hipparion, Awesome Presence)
					# is a mana question mana in a hand can answer. Rule 8 — this
					# seat may not be told what the other one holds; its own seat
					# reads its own hand exactly as the rules-exact check does.
					if attacker != null and CombatState.block_illegality(g, card, attacker, card.controller_id, true, pid).is_empty():
						legal.append(m._handle(pid, attacker))
				if not legal.is_empty(): result.blockable.append([row.id, legal])
	for item in g.stack:
		var card := item.card
		# A source can have left for a private zone while its ability remains.
		# Give that chain item only its already-public name, not a hidden-zone card.
		var face: Dictionary = m._cards(pid, [card])[0] if m._visible(pid, card) else {}
		var refs: Array = []
		if not item.target_held:
			for target in item.targets:
				var ref := target_reference(m, pid, target)
				if not ref.is_empty(): refs.append(ref)
		result.chain.append({"id": object_handle(m, pid, "ability", item.id), "kind": item.kind,
			"face": face, "refs": refs})
	for packet in g.damage_pending:
		result.packets.append({"id": object_handle(m, pid, "damage", packet.id),
			"source": m._handle(pid, packet.source) if m._visible(pid, packet.source) else "",
			"target": target_reference(m, pid, packet.target), "amount": packet.remaining(), "combat": packet.is_combat})
	for band in g.combat.bands:
		var members: Array = []
		for id in band: members.append(m._handle(pid, g.find_instance(id)))
		result.bands.append(members)
	for id in g.combat.blocks:
		var blocker := g.find_instance(id)
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD: continue
		var linked := false
		for attacker in [g.combat.blocks[id]] + g.combat.extra_blocks.get(id, []):
			var card := g.find_instance(attacker)
			if card == null or card.zone != Mtg.Zone.BATTLEFIELD or not g.combat.attackers.has(attacker): continue
			result.blocks.append([m._handle(pid, blocker), m._handle(pid, card)])
			linked = true
		# Empty destination means "still blocking, no remaining attacker".
		# Preserve that public status without a link to a private/ceased object.
		if not linked: result.blocks.append([m._handle(pid, blocker), ""])
	for id in g.combat.blocked_attackers:
		var card := g.find_instance(id)
		if card != null: result.blocked.append(m._handle(pid, card))
	# WHO THE OPEN REGENERATION WINDOW IS ABOUT. The bool alone says a
	# window is open; the doomed creatures are the question it asks, and
	# they are public — they are standing on a battlefield holding lethal
	# damage. Empty whenever no window is open, so this costs nothing.
	for id in g.regeneration_candidates:
		var card := g.find_instance(id)
		if m._visible(pid, card): result.doomed.append(m._handle(pid, card))
	if g.awaiting_damage_assignment:
		var request := g.damage_assignment_request()
		var assigned: Array = []
		for id in request.assigned:
			var card := g.find_instance(id)
			if card != null: assigned.append([m._handle(pid, card), int(request.assigned[id])])
		# The division's AMOUNT and its TARGETS are public — the source's
		# power and the creatures blocking or blocked, all of them already
		# on the board — so the watching seat's own board can paint the
		# groups the assigner has answered. The per-target "lethal" hint
		# stays private, in `damage_request`, for the assigner alone.
		var targets: Array = []
		for id: int in request.targets:
			var target := g.find_instance(id)
			if target != null: targets.append(m._handle(pid, target))
		result.assignment = {"source": m._handle(pid, request.source), "assigner": int(request.assigner),
			"amount": int(request.amount), "targets": targets,
			"trample": bool(request.trample), "assigned": assigned,
			"special": String(request.get("special", "")), "normal_assigner": int(request.get("normal_assigner", request.assigner)),
			"free_order": bool(request.get("free_order", false))}
	if not view.announcement.is_empty():
		for slot in view.announcement.slots:
			for target in slot.targets:
				result.targets.append({"token": target.id, "ref": target_reference(m, pid, m.actions._targets[target.id])})
		var d := m.actions.draft
		result.draft = {"card": m._handle(pid, d.card), "kind": d.kind, "index": d.index, "x": d.x, "mode": d.mode,
			"reachable": m.actions.payment_reachable()}
	return result


static func has_aim(g: MtgGame, card: CardInstance) -> bool:
	if card.data.is_modal(): return true
	for effect in card.data.spell_effects:
		if effect.target_spec == null or effect.target_min <= 0 or effect.target_count_is_x: continue
		if effect.target_spec.legal_targets(g, card).is_empty(): return false
	return true
