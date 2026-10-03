class_name SgDuelPresentation
extends RefCounted
## A deliberate allowlist for the existing duel renderer. Never a snapshot.
## References are viewer-local capabilities, not engine ids. Even the host's
## UI consumes this filtered representation instead of its referee object.

## `phased_out` / `phased_indirectly` (Pack 8): public, like the table they
## lie on (CR 702.26); the board ghosts the card and its tooltip says how
## it comes back (MiniCard.phase_note). A holder rides in `phase_holds`.
const FLAGS := ["cur_extra_blocks", "extra_blocks_this_turn", "cur_cant_attack",
	"cur_attacks_as_if_hasty", "cur_must_be_blocked", "must_attack_this_turn",
	"cur_indestructible", "cur_skips_untap", "skip_next_untap", "skip_untaps",
	"phased_out", "phased_indirectly"]
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
		"untap_capped": not g.untap_caps.is_empty(), "block_taxes": [], "phase_holds": []}
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
		# The PHASED-OUT permanents lie on the table too (Pack 8, CR 702.26):
		# public, and rows of their own for the two phasing flags.
		var visible: Array = p.battlefield + p.graveyard + p.exile + p.ante + p.phased_out
		for card in p.hand:
			if m._visible(pid, card): visible.append(card)
		for card: CardInstance in visible:
			var row := {"id": m._handle(pid, card), "flags": {}, "abilities": [], "castable": false}
			for key in FLAGS:
				row.flags[key] = (0 if key in COUNTED_FLAGS else false) if card.face_down and card.zone != Mtg.Zone.BATTLEFIELD else card.get(key)
			if card.phased_out and card.phase_hold >= 0:
				var holder := g.find_instance(card.phase_hold)
				if m._visible(pid, holder): result.phase_holds.append([row.id, m._handle(pid, holder)])
			# Where this seat may cast from (Pack 8): its hand, an exiled card
			# it may play — a Three Wishes card face down to everyone else —
			# and the top of its graveyard under Bösium Strip, the engine's
			# own permissions, as MtgGame.playable_cards reads them.
			if (card.zone == Mtg.Zone.HAND and card.owner_id == pid) or g.can_play_from_exile(pid, card) \
					or g.can_cast_from_graveyard(pid, card):
				row.castable = g.cast_timing_refusal(pid, card).is_empty() and SgPayment.affordable(g, pid, card, true)
				# A FAST EFFECT is anything castable now although a sorcery
				# could not be (Pack 8): an instant, FLASH, the Mirage flash
				# rider or a Winding Canyons grant — the engine's own
				# question, the one the local screen asks (DuelScreen
				# ._fast_spells). It asked `is_type(INSTANT)` until then, so a
				# networked King Cheetah never held a window.
				if g.casts_at_instant_speed(pid, card):
					# FLOATING is the printed row only, as the local screen's
					# _has_affordable_fast_effect asks it: a free ALTERNATIVE
					# row (Fireblast's two Mountains) would otherwise stop
					# every Done and auto-pass of the duel. RESPOND weighs
					# every row, like the local _payable_now.
					result.floating = result.floating or SgPayment.affordable(g, pid, card, false, false)
					result.respond = result.respond or (SgPayment.affordable(g, pid, card, true) and has_aim(g, card))
			# A face-down card this seat may LOOK at (Three Wishes) offers its
			# actions to that seat; every other face-down card offers none.
			var hidden := card.face_down and not (card.zone == Mtg.Zone.EXILE and card.exile_visible_to == pid)
			for option in ([] if hidden else SgDuelActions.options(card, pid, g)):
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
					if DuelScreen._ability_usable(card, ability) and g.ability_timing_refusal(pid, card, ability).is_empty() and g.can_afford_cost(pid, cost):
						result.respond = true
						result.floating = true
			result.cards.append(row)
			# Nothing about a phased-out permanent attacks or blocks (702.26b).
			if card.phased_out: continue
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
						# A LIFE TAX ON BLOCKING (Heat Wave, Pack 8 — CR 509.1d):
						# what this blocker would owe for this attacker, per
						# imposing source, so the seat's own screen prices the
						# pencilled declaration (DuelScreen._block_life_fee)
						# as the referee will charge it. Public: the taxes
						# come from permanents on the table and the blocker's
						# own colour. The filter itself never crosses.
						for tax in attacker.cur_blocked_by_life_taxes:
							var filter: Callable = tax.get("filter", Callable())
							if filter.is_valid() and not bool(filter.call(card)): continue
							result.block_taxes.append([row.id, m._handle(pid, attacker),
								object_handle(m, pid, "tax", int(tax.source)), int(tax.life)])
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
	# An Aura's one target is what it will enchant (CR 303.4a): a flash-rider
	# Aura with no creature on the table has nothing to be cast at.
	if card.data.is_aura():
		return card.data.aura_target == null \
			or not card.data.aura_target.legal_targets(g, card).is_empty()
	for effect in card.data.spell_effects:
		if effect.target_spec == null or effect.target_min <= 0 or effect.target_count_is_x: continue
		if effect.target_spec.legal_targets(g, card).is_empty(): return false
	return true
