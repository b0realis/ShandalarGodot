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


## May [param pid] cast [param card] from where it lies — the engine's
## permission ([param referee] null: a projection's own reading).
static func casts_from(referee: MtgGame, pid: int, card: CardInstance) -> bool:
	return (card.zone == Mtg.Zone.HAND and card.owner_id == pid) \
		or (referee != null and (referee.can_play_from_exile(pid, card) or referee.can_cast_from_graveyard(pid, card))) \
		or (referee == null and card.zone == Mtg.Zone.EXILE and not card.face_down and card.exile_playable_by == pid)


static func options(card: CardInstance, pid: int, referee: MtgGame = null) -> Array:
	var result: Array = []
	# A PHASED-OUT permanent is treated as though it does not exist (CR
	# 702.26b): nothing of it is activated, whatever its lists still hold.
	if card.phased_out: return result
	# Where a spell may be cast from is the ENGINE's permission (Pack 8),
	# the one MtgGame.playable_cards reads: the hand; an exiled card this
	# seat may play — a Three Wishes card face down to everyone but its
	# viewer included (MtgGame.can_play_from_exile); the top of the
	# graveyard under Bösium Strip (MtgGame.can_cast_from_graveyard).
	var spell_source := casts_from(referee, pid, card)
	# The SPELL ROW stays whatever the moment (its cost is read off it by
	# every board); whether it may be cast now is the presentation's
	# `castable` (SgDuelPresentation.build), and `prepare` refuses what
	# the cast would ([method spell_refusal]).
	if spell_source and not card.is_land():
		var modes: Array = []
		if referee != null:
			# THE REFEREE'S PAYMENT ROWS (Pack 9, MtgGame.payment_rows): the
			# card's modes and printed rows — a BUYBACK row among them, said
			# as one (DuelScreen.payment_row_label) — then the rows a
			# permanent GRANTS it (Dream Halls, Aluren), so a plain spell
			# under Dream Halls has two. `mode` indexes this list.
			var rows := referee.payment_rows(pid, card)
			if card.data.is_modal() or rows.size() > 1:
				for row: Dictionary in rows:
					modes.append(DuelScreen.payment_row_label(row).left(128))
		else:
			for mode in card.data.modes:
				modes.append(String(mode.get("label", mode.get("name", "Mode"))))
		result.append({"kind": "spell", "index": 0, "label": "Cast " + card.data.card_name,
			"x": card.data.cost.has_x or not card.data.repeated_additional_cost.is_empty(), "modes": modes})
	var borrowed := referee != null and referee.may_tap_foreign_land(pid, card)
	if borrowed or (card.zone == Mtg.Zone.BATTLEFIELD and card.controller_id == pid) or (card.zone == Mtg.Zone.HAND and card.owner_id == pid):
		for i in card.cur_mana_abilities.size():
			if borrowed and not referee.may_tap_foreign_land(pid, card, i): continue
			if card.cur_mana_abilities[i].activation_zone != card.zone: continue
			# ONLY A SOURCE THE ENGINE WOULD TAP (2026-10-04): a tapped land,
			# a summoning-sick Elf, a Wall of Roots used this turn, a banned
			# Mox — MtgGame.mana_ability_refusal, the head of tap_for_mana.
			# A TAPPED LAND WAS LISTED as a mana source to every program.
			if referee != null and referee.mana_ability_refusal(pid, card, i) != "": continue
			result.append({"kind": "mana", "index": i, "label": str(referee.mana_ability_for(pid, card, i) if referee != null else card.cur_mana_abilities[i]), "x": false, "modes": []})
	if card.zone not in [Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD]: return result
	for i in card.cur_activated_abilities.size():
		var ability: ActivatedAbility = card.cur_activated_abilities[i]
		if ability.activation_zone != card.zone: continue
		# USABLE ONLY (2026-10-04, the MCP play-through): with the referee at
		# hand, an ability is offered when the engine would take it now —
		# [method ability_refusal]: its own announce-time refusal (the
		# once-a-turn limit, timing, a ban, a tapped or sick {T} source,
		# who may activate it), something to aim at, and mana the seat can
		# reach. A Knight of Valor's used ability stayed listed, a program's
		# auto-pay tapped two lands for it, and only the submit was refused.
		if referee != null:
			if ability_refusal(referee, pid, card, i).is_empty():
				result.append({"kind": "ability", "index": i, "label": str(ability),
					"x": ability.cost.has_x, "modes": []})
			continue
		var permitted := ability.any_player_may_activate \
			or (ability.only_owner_may_activate and card.owner_id == pid) \
			or (ability.only_opponents_may_activate and card.controller_id != pid) \
			or (not ability.only_owner_may_activate and not ability.only_opponents_may_activate and card.controller_id == pid)
		if permitted:
			result.append({"kind": "ability", "index": i, "label": str(ability),
				"x": ability.cost.has_x, "modes": []})
	return result


## Why the engine would refuse [param card]'s activated ability
## [param index] for [param pid] right now, before any target is named or
## any mana is made — "" when it would take it. Three questions, each the
## engine's own: [method MtgGame.ability_announce_refusal] (the holds, the
## zone, phasing, who may activate it, the damage window, the printed
## timing and the bans, "activate only once each turn", a tapped or
## summoning-sick {T} source); something to aim at for every slot that
## demands a target; and the mana — floating, or a plan over the very
## sources the auto-pay taps ([method autopay]), never the source of a {T}
## ability itself. What [method options] offers and what [method prepare]
## refuses with, so an option is never a payment the submit refuses.
##
## [param x] is the X the targets are judged at — the announced one; -1
## (none announced yet) is any X the seat could pay for ([method aimed]).
static func ability_refusal(g: MtgGame, pid: int, card: CardInstance, index: int, x := -1) -> String:
	var why := g.ability_announce_refusal(pid, card, index)
	if not why.is_empty(): return why
	var ability: ActivatedAbility = card.cur_activated_abilities[index]
	if not aimed(g, pid, card, ability.effects, null, x, ability.cost.has_x, "ability", index, 0):
		return "nothing to aim %s at" % card.data.card_name
	var due := g.ability_payment(pid, card, index, 0)
	if ManaPlanner.cost_is_free(due.cost) and int(due.extra) <= 0: return ""
	if SgPayment.can_pay_now(g, pid, due, "ability"): return ""
	var plan := ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(g, pid, source_excluded(card, ability)),
		due.cost, int(due.extra), due.usage)
	if not plan.is_empty(): return ""
	return "not enough mana (%s)" % ability.cost.text


## The source of a {T} ability pays its own cost by tapping: it is no mana
## source for that payment (a Llanowar Elves with a {G}{T} ability can't
## tap for the {G} too).
static func source_excluded(card: CardInstance, ability: ActivatedAbility, excluded: Dictionary = {}) -> Dictionary:
	if not ability.tap_cost: return excluded
	var out := excluded.duplicate()
	out[card.id] = true
	return out


## Why casting [param card] in payment row [param mode] at [param x] would
## be refused for a reason no mana can fix: the clock and the zone
## ([method MtgGame.cast_timing_refusal]), nothing to aim at
## ([method spell_aimed]), and the engine's own pre-mana
## reading of the rest ([method MtgGame.spell_announce_refusal]: the mode,
## the damage window, the row's object costs, card to exile and life, an
## additional sacrifice's body). "" otherwise.
##
## [param x] is the announced X; -1 (none yet: the options, `castable`)
## asks whether SOME X the seat could pay for has a target ([method aimed]).
static func spell_refusal(g: MtgGame, pid: int, card: CardInstance, mode: int, x: int) -> String:
	var why := g.cast_timing_refusal(pid, card)
	if not why.is_empty(): return why
	if not spell_aimed(g, pid, card, mode, x): return "nothing to aim %s at" % card.data.card_name
	return g.spell_announce_refusal(pid, card, maxi(0, x), mode)


## Has [param card], cast in [param mode], something to aim at — every
## slot that demands a target ([method aimed]) — at X = [param x], or with
## [param x] -1 at some X [param pid] could pay for? A modal spell's or
## payment row's own effects ([member CardData.modes]); an Aura's one
## target is what it will enchant (CR 303.4a).
static func spell_aimed(g: MtgGame, pid: int, card: CardInstance, mode: int, x := -1) -> bool:
	var effects: Array = card.data.spell_effects
	var aura: TargetSpec = null
	if card.data.is_aura():
		effects = []
		aura = card.data.aura_target
	elif card.data.is_modal() or mode > 0:
		# A mode, or a payment row (Pack 9 — a buyback row, a row a
		# permanent grants): the effects the row casts.
		if mode < 0: return false
		if pid >= 0:
			if mode >= g.payment_rows(pid, card).size(): return false
			effects = SgPayment.row_effects(g, pid, card, mode)
		else:
			if mode >= card.data.modes.size(): return false
			effects = card.data.modes[mode].get("effects", [])
	var has_x := row_cost(g, pid, card, mode).has_x or card.data.cost.has_x \
		or not card.data.repeated_additional_cost.is_empty()
	return aimed(g, pid, card, effects, aura, x, has_x, "spell", 0, mode)


## The MANA of payment row [param mode] of [param card] as it is printed
## or granted — the printed cost, a mode's or an alternative row's own, a
## BUYBACK row's printed cost plus its buyback, a granted row's (Pack 9:
## [method MtgGame.payment_option_for]). Cost modifiers are the payment's
## business ([method SgPayment.due]).
static func row_cost(g: MtgGame, pid: int, card: CardInstance, mode: int) -> ManaCost:
	if g == null or pid < 0:
		return card.data.payment_base(mode)
	var cost: Variant = g.payment_option_for(pid, card.data, mode, card).get("cost", card.data.cost)
	return cost if cost is ManaCost else card.data.cost


## Does every slot of [param effects] that demands a target (and
## [param aura], an Aura's enchant target) have a legal one at X =
## [param x] — the engine's own reading at that X
## ([method MtgGame.legal_targets_at], which proposes it, so "target
## artifact with mana value X" is judged at the X it will be cast for)?
##
## WITH NO X ANNOUNCED ([param x] -1, 2026-10-04): an X action
## ([param has_x]) has something to aim at when SOME X from 0 to the most
## [param pid] could pay for ([method SgPayment.budget]) has — a Detonate
## with a Sol Ring across the table is castable for X = 1, never X = 0.
## The budget is searched only when X = 0 finds nothing.
static func aimed(g: MtgGame, pid: int, card: CardInstance, effects: Array, aura: TargetSpec,
		x: int, has_x: bool, kind: String, index: int, mode: int) -> bool:
	if _aimed_at(g, card, effects, aura, maxi(0, x)): return true
	if x >= 0 or not has_x or pid < 0: return false
	var budget := SgPayment.budget(g, pid, card, kind, index, ManaPlanner.sources(g, pid), 1, mode)
	for each in range(1, budget + 1):
		if _aimed_at(g, card, effects, aura, each): return true
	return false


static func _aimed_at(g: MtgGame, card: CardInstance, effects: Array, aura: TargetSpec, x: int) -> bool:
	if aura != null and g.legal_targets_at(aura, card, x).is_empty(): return false
	for effect in effects:
		if effect.target_spec == null or effect.target_min <= 0 or effect.target_count_is_x: continue
		if g.legal_targets_at(effect.target_spec, card, x).is_empty(): return false
	return true


## The modes (payment rows, "Choose one —" modes) of [param card] the seat
## could cast now: [method spell_refusal] at any X finds nothing, and the
## row's own payment is in reach ([method SgPayment.mode_affordable] —
## its life, card to exile, object costs and mana). Fireblast with one
## Mountain has only its {4}{R}{R} row, and only with six mana in reach;
## a Force of Will with no other blue card has no pitch row. [] for a
## spell without modes.
static func open_modes(g: MtgGame, pid: int, card: CardInstance) -> Array:
	var out: Array = []
	for mode in g.payment_rows(pid, card).size():
		if spell_refusal(g, pid, card, mode, -1).is_empty() and SgPayment.mode_affordable(g, pid, card, mode, true):
			out.append(mode)
	return out


## The announcement. REFUSED BEFORE ANY MANA IS MADE (2026-10-04) for
## every reason payment cannot change: an ability's [method ability_refusal]
## (in the engine's own words — "activate only once each turn"), a spell's
## [method spell_refusal]. [param aim] off defers a spell's target and
## object-cost reading to [method auto_prepare], which raises X first.
func prepare(pid: int, card: CardInstance, action: Dictionary, aim := true) -> String:
	if card == null or game.priority_player != pid or game.awaiting_choice != null:
		return "This action is unavailable."
	if action.kind == "ability" and int(action.index) >= 0 and int(action.index) < card.cur_activated_abilities.size():
		var refusal := ability_refusal(game, pid, card, int(action.index), int(action.x) if aim else -1)
		if not refusal.is_empty(): return refusal
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
		if aim:
			error = spell_refusal(game, pid, card, int(action.mode), int(action.x))
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
	# Auto-cast may spend mana, never choose how much life the player loses
	# — nor how many of their cards or permanents an X takes (Pack 8:
	# Infernal Harvest, Haunting Misery, Firestorm), as the local double-
	# click never decides it either (DuelScreen._auto_cast).
	if card != null and action.kind == "spell" and card.data.additional_life_is_x:
		return "Choose the life payment explicitly."
	if card != null and SgPayment.object_x(card, String(action.kind), int(action.index), int(action.mode), game, pid):
		return "Choose X explicitly: it counts cards or permanents, not mana."
	var request_data := action.duplicate()
	request_data.x = 0
	var error := prepare(pid, card, request_data, false)
	if not error.is_empty(): return error
	var cost: ManaCost = row_cost(game, pid, card, int(draft.mode)) if draft.kind == "spell" else card.cur_activated_abilities[draft.index].cost
	if cost.has_x or (draft.kind == "spell" and not card.data.repeated_additional_cost.is_empty()):
		draft.x = SgPayment.budget(game, pid, card, draft.kind, draft.index, ManaPlanner.sources(game, pid, excluded), action.count, draft.mode)
	# The spell's targets and object costs at the X it will be cast for,
	# before a land is tapped (2026-10-04: refused before paying, never
	# after) — an ability's targets likewise.
	if draft.kind == "spell":
		error = spell_refusal(game, pid, card, int(draft.mode), int(draft.x))
	else:
		error = ability_refusal(game, pid, card, int(draft.index), int(draft.x))
	if not error.is_empty():
		clear()
		return error
	return autopay(pid, excluded, action.count)


## The seat's SPECIAL ACTIONS, the `special` op's list (its `index`):
## Channel, a paid point of prevention, a ransom — and Pack 9's two that
## belong to a permanent, from the engine's own list ([method
## MtgGame.special_actions]): a licid's "pay {end} to end this effect"
## (`licid_end`) and Volrath's Curse's sacrifice to ignore it
## (`ignore_effect`). Those two are listed only while the engine would
## take them now ([method MtgGame.special_action_refusal] — USABLE ONLY,
## as every option a program reads): an ignore is on offer every moment a
## cursed creature's controller holds priority, and a list a program must
## stop for should never hold a payment it cannot make. `card` is the
## permanent an entry belongs to (the presentation's `special_rows`).
## THE OTHER THREE ARE USABLE ONLY TOO (whole-game campaign 2026-10-07):
## Channel while the seat has a life to pay, a point of prevention and a
## ransom while the engine would take them now and the seat's mana —
## floating, or the sources it could still tap — reaches the cost
## ([method special_refusal]). An unpayable ransom was offered, and the
## `special` op then refused it ("not enough mana to pay {2}").
func special_entries(pid: int) -> Array:
	var entries: Array = []
	if game.players[pid].life_for_mana:
		entries.append({"label": "Channel — pay 1 life for one colorless mana", "kind": "channel"})
	for entry in game.players[pid].paid_prevention:
		var shielded: CardInstance = null if entry.target.is_player else game.find_instance(entry.target.instance_id)
		entries.append({"label": "Pay {1}: prevent 1 damage to " + target_label(entry.target, pid),
			"kind": "prevention", "target": entry.target, "card": shielded})
	for entry in game.settleable_delayed_triggers(pid):
		entries.append({"label": "Pay %s: %s" % [entry.settle_cost, entry.desc], "kind": "settle", "id": entry.id,
			"card": _existing(entry.get("source")), "cost": entry.settle_cost})
	entries = entries.filter(func(entry: Dictionary) -> bool: return special_refusal(pid, entry).is_empty())
	for row: Dictionary in game.special_actions(pid):
		if String(row.kind) not in ["licid_end", "ignore_effect"]: continue
		if not game.special_action_refusal(pid, row).is_empty(): continue
		entries.append({"label": String(row.label), "kind": String(row.kind), "id": int(row.id),
			"card": _existing(row.get("card")), "row": row})
	return entries


## [param card] when it STILL EXISTS — the game's own object of that id —
## else null (Pack 9 bug pass). A ransom's `source` is the Sabertooth Cobra
## that bit, kept by reference: a TOKEN Cobra (Echo Chamber's copy) has
## ceased to exist since (CR 111.7), and a row naming it named a card no
## zone of the view carries.
func _existing(card: Variant) -> CardInstance:
	if not card is CardInstance: return null
	var live := game.find_instance((card as CardInstance).id)
	return live if live == card else null


## Why [param entry] — a Channel, a paid point of prevention or a ransom
## of [method special_entries] — cannot be taken by [param pid] now, in the
## engine's own words ([method MtgGame.pay_life_for_mana], [method
## MtgGame.pay_for_prevention], [method MtgGame.settle_delayed_trigger]),
## or "". Nothing is touched: the mana is priced by the engine's own plan,
## the way the local screen greys the same three (DuelScreen
## ._special_action_refusal).
func special_refusal(pid: int, entry: Dictionary) -> String:
	if game.game_over: return "the game is over"
	if game.awaiting_choice != null: return "waiting for a choice to be made"
	match String(entry.get("kind", "")):
		"channel":
			return "" if game.players[pid].life >= 1 else "not enough life to pay 1"
		"settle", "prevention":
			if game.awaiting_attackers or game.awaiting_blockers or game.awaiting_discard \
					or game.awaiting_damage_assignment:
				return "a declaration is waiting"
			if game.priority_player != pid: return "you don't have priority"
			var cost: ManaCost = entry.get("cost") if entry.get("cost") is ManaCost else ManaCost.parse("{1}")
			if String(entry.kind) == "prevention":
				if game.awaiting_regeneration: return "only regeneration effects may be used now"
				var target: TargetRef = entry.target
				if not target.is_player:
					var inst := game.find_instance(target.instance_id)
					if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD: return "that is no longer on the battlefield"
			var pool: ManaPool = game.players[pid].mana_pool
			if not pool.can_pay(cost, 0, [], game.players[pid].mana_substitutions) and not game.can_afford_cost(pid, cost):
				return "not enough mana to pay %s" % str(cost)
	return ""


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
		"prevention":
			# The engine spends the POOL for a point of prevention; the
			# referee taps for it first, as the local screen does
			# (DuelScreen._take_special_action) — an offered point is one
			# the seat's sources reach ([method special_refusal]).
			var one := ManaCost.parse("{1}")
			if not ManaPlanner.plan_and_pay(game, pid, one):
				return "not enough mana to pay {1}"
			return game.pay_for_prevention(pid, entry.target)
		"settle": return game.settle_delayed_trigger(pid, entry.id)
		# The engine's one door (Pack 9): a licid's end is paid by the
		# referee itself; an ignore holds its sacrifice as a cost question
		# the seat answers with `choice` or withdraws with `cancel`.
		"licid_end", "ignore_effect": return game.take_special_action(pid, entry.row)
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
			# The chosen PAYMENT ROW's effects (Pack 9: a row a permanent
			# grants casts the printed row it is built on).
			effects = SgPayment.row_effects(game, pid, source, int(draft.mode))
	elif draft.kind == "ability":
		if draft.index >= source.cur_activated_abilities.size(): return {}
		effects = source.cur_activated_abilities[draft.index].effects
	for effect in effects:
		if effect.target_spec == null or not effect.target_spec.is_supplied_by_caster(): continue
		var span: Vector2i = effect.target_range(draft.x)
		slots.append({"spec": effect.target_spec, "min": span.x, "max": span.y,
			"clamp": effect.target_count_is_x, "divided": maxi(0, effect.divided_amount(draft.x)),
			"effect": effect})
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
		var counts := _counted_slot(source, slot, result, candidates.size())
		if not counts.is_empty():
			# The slot's own range is the widest any earlier pick allows;
			# the seat's screen narrows it to the pick it makes.
			minimum = int(counts[0][1])
			maximum = int(counts[0][2])
			for row in counts:
				minimum = mini(minimum, int(row[1]))
				maximum = maxi(maximum, int(row[2]))
		result.append({"label": slot.spec.description, "kind": slot.spec.kind, "min": minimum, "max": maximum,
			"divided": slot.divided, "targets": candidates, "counts": counts})
	return {"name": source.data.card_name, "kind": draft.kind, "x": draft.x, "slots": result}


## A TARGET COUNT ANOTHER TARGET SETS (Pack 9 — Reap: "up to X target
## cards …, where X is the number of black permanents target opponent
## controls", CR 601.2c): `[token, min, max]` per candidate of the ONE
## earlier target the count reads — [method EffectBase.target_range_at]
## asked with that candidate as the earlier ref, the maximum bounded by
## the [param available] candidates of this slot — so the seat's screen
## narrows the slot to the opponent it picks (SgDuelView._counted_range)
## and the referee judges the submit as the cast will (TargetPlan).
## [] for an ordinary slot, and when the slots before it hold anything
## but exactly one target (no card in the pool reads more).
func _counted_slot(source: CardInstance, slot: Dictionary, earlier_slots: Array, available: int) -> Array:
	var effect: Variant = slot.get("effect")
	if not effect is EffectBase or not (effect as EffectBase).target_count_fn.is_valid():
		return []
	if earlier_slots.size() != 1 or int(earlier_slots[0].min) != 1 or int(earlier_slots[0].max) != 1:
		return []
	var out: Array = []
	for candidate in earlier_slots[0].targets:
		var ref: TargetRef = _targets.get(candidate.id)
		if ref == null: continue
		var span := (effect as EffectBase).target_range_at(game, source, int(draft.x), [ref])
		var most := available if span.y < 0 else mini(span.y, available)
		out.append([String(candidate.id), mini(span.x, most), most])
	return out


func target_label(target: TargetRef, pid: int) -> String:
	if target.is_player: return "You" if target.player_id == pid else "Opponent"
	if target.is_damage:
		var packet := game.find_packet(target.packet_id)
		if packet == null: return "Damage no longer pending"
		return "Damage %d: %s" % [packet.amount, target_label(packet.target, pid)]
	if target.is_ability:
		# An activated ability, or — for "target spell or ability" (Pack 9,
		# Silver Wyvern) — a TRIGGERED one (MtgGame.find_stack_object).
		var item := game.find_stack_object(target.ability_id)
		if item == null: return "Ability no longer on stack"
		return ("Triggered ability: " if item.kind == Mtg.StackKind.TRIGGER else "Ability: ") \
			+ (item.card.data.card_name if item.card != null and not item.card.face_down else "Face-down card")
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
	# The named targets stay with the draft: a spell aimed at a Kaervek's
	# Torch costs {2} more (Pack 8, MtgGame.targets_surcharge), and a cast
	# refused for its mana is paid by the auto-tap with that {2} in it.
	draft["targets"] = refs
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
		return game.spell_payment(draft.pid, draft.card.data, draft.x, count, draft.card, draft.mode,
			draft.get("targets", []))
	return game.ability_payment(draft.pid, draft.card, draft.index, draft.x)


func autopay(pid: int, excluded: Dictionary, count: int) -> String:
	if draft.is_empty() or draft.pid != pid: return "No announcement is waiting."
	if game.awaiting_choice != null: return "Answer the pending question first."
	_auto_payment.clear()
	var due := payment(count)
	if due.is_empty(): return "This action has no mana payment."
	# The source of a {T} ability is never tapped for its own mana: the
	# submit would then find it tapped, with the rest of the mana floating.
	var sources_out := excluded
	if draft.kind == "ability" and int(draft.index) < draft.card.cur_activated_abilities.size():
		sources_out = source_excluded(draft.card, draft.card.cur_activated_abilities[draft.index], excluded)
	# The auto-tap's own view of the sources: a Fellwar Stone with several
	# colours on offer is generic-only here, so its tap asks the seat what
	# kind of mana instead of picking a colour for them (2026-09-17).
	var plan := ManaPlanner.plan_from(ManaPlanner.auto_tap_sources(game, pid, sources_out),
		due.cost, int(due.extra), due.usage)
	# THE ANNOUNCEMENT BRACKET (whole-game campaign 2026-10-07, w7-5): the
	# seat is paying for its announced spell or ability (CR 601.2g), so
	# what its mana abilities trigger — City of Brass, Manabarbs — waits
	# until the object is on the stack (CR 603.3; MtgGame
	# .begin_announcement). A creature paid for with City of Brass was
	# refused "main phase with an empty stack" at its submit.
	if not plan.is_empty(): game.begin_announcement(pid)
	for step in plan:
		# COVERED ALREADY (whole-game campaign 2026-10-07, fix-mana's w1-1):
		# a mana trigger's bonus (Mana Flare, Wild Growth) can fill the pool
		# before the plan's last step — a land per pip tapped on and the
		# spare mana burned. Stop once the pool pays the bill.
		if game.players[pid].mana_pool.can_pay(due.cost, int(due.extra), due.usage): break
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
				entries.append({"label": decline_label(question), "answer": ""})
			# ONE PICK OF AN "IN ANY ORDER" SEQUENCE (Pack 8 — Teferi's Puzzle
			# Box, PlayerChoice.in_order) ends in one click with the local
			# screen's own line: the rest go in the order LISTED here
			# ([method _keep_order]).
			if question.kind == PlayerChoice.Kind.CARD and question.in_order and entries.size() > 1:
				entries.append({"label": DuelScreen.KEEP_ORDER_LINE, "answer": KEEP_ORDER})
	return entries


## The decline line of an optional CARD question. A LAND'S ENTRY PAYMENT
## (Mirage bug pass, 2026-10-04 — Lotus Vale, Scorched Ruins, the
## Alliances entry lands) holds the land drop on a card question that is a
## cost and optional (MtgGame.play_land): declining is the Oracle's *"If
## you don't, put it into its owner's graveyard"* — the land lost and the
## drop spent — while the `cancel` op WITHDRAWS the play (the land back in
## hand, MtgGame.cancel_choice). "Choose none" read like the withdrawal, so
## that line says what it does, as the local screen's does
## (DuelScreen._decline_label): the question names the land, which is in
## the seat's hand or is an exiled card it may play (Three Wishes).
## Display text only — the answer is still "".
func decline_label(question: PlayerChoice) -> String:
	if question.kind != PlayerChoice.Kind.CARD or not question.is_cost or not question.optional \
			or question.source == "" or question.pid < 0 or question.pid >= game.players.size():
		return "Choose none"
	var places: Array = game.players[question.pid].hand.duplicate()
	for p in game.players:
		for inst in p.exile:
			if game.can_play_from_exile(question.pid, inst): places.append(inst)
	for inst: CardInstance in places:
		if inst.data.card_name == question.source and inst.data.is_land():
			return "Put %s into its owner's graveyard." % question.source
	return "Choose none"


## The answer of the `Done — keep this order.` line; no card is a Dictionary.
const KEEP_ORDER := {"keep_order": true}


## `Done — keep this order.` (Pack 8): this pick and every further pick of
## [param question]'s sequence take the FIRST line listed — the order the
## seat was shown, which here is the sorted list, never a hidden order —
## each answered through the engine as the seat's own, until the sequence
## asks no more. Any order is legal and the cards go where nobody sees
## them, so this is a complete answer (HumanAgent.keep_order_for is the
## local screen's form of the same click).
func _keep_order(pid: int, question: PlayerChoice) -> String:
	var source := question.source
	for i in SgProtocol.MAX_CARDS:
		var asking := game.awaiting_choice
		if asking == null or asking.pid != pid or not asking.in_order or asking.source != source \
			or asking.kind != PlayerChoice.Kind.CARD:
			break
		var entries := _choice_entries()
		if entries.is_empty() or entries[0].answer is Dictionary: break
		var error := game.answer_choice(entries[0].answer)
		if not error.is_empty(): return error
	return ""


## The open question for [param pid], as the wire carries it. `cards`
## (protocol 29, whole-game campaign 2026-10-07): per line, the handle of
## the board card it stands for — [param handle] turns a card into the
## seat's handle — or "" (a yes/no, a colour, a named or hidden card). A
## line between two Grizzly Bears said only "Grizzly Bears — yours
## [choice 1]": nothing tied it to a card on the board (the local screen
## names namesakes by their ID tags, DuelScreen.choice_card_lines). Such a
## line now ends in its handle instead of the sort ordinal ("Grizzly
## Bears — yours [c12]"), the name a program reads on its board; the
## networked screen shows the card's ID tag there (SgDuelProjection
## .choice_lines).
func choice_view(pid: int, handle: Callable = Callable()) -> Dictionary:
	var question := game.awaiting_choice
	if question == null or question.pid != pid: return {}
	var labels: Array = []
	var cards: Array = []
	for entry in _choice_entries():
		var card: CardInstance = game.find_instance(int(entry.answer)) if entry.answer is int \
			and question.kind in [PlayerChoice.Kind.CARD, PlayerChoice.Kind.DISCARD] else null
		var key := String(handle.call(card)) if card != null and handle.is_valid() else ""
		var line := String(entry.label)
		if key != "":
			var ordinal := line.rfind(" [choice ")
			if ordinal >= 0: line = line.left(ordinal)
			line += " [%s]" % key
		labels.append(line)
		cards.append(key)
	var shown: Array = []
	for info in question.information:
		if info.viewer in [-1, pid]: shown.append({"title": info.title, "cards": info.cards.duplicate()})
	return {"prompt": question.prompt, "source": question.source, "options": labels, "information": shown,
		"count": mini(question.count, labels.size()) if question.kind == PlayerChoice.Kind.DISCARD else 1,
		"cancel": question.is_cost and not question.adverse, "cards": cards}


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
	var error := ""
	if question.kind == PlayerChoice.Kind.CARD and answers[0] is Dictionary:
		error = _keep_order(pid, question)
	else:
		error = game.answer_choice(answers if question.kind == PlayerChoice.Kind.DISCARD else answers[0])
	if error.is_empty() and game.awaiting_choice == null and not _auto_payment.is_empty():
		var resume := _auto_payment.duplicate(true)
		return autopay(resume.pid, resume.excluded, resume.count)
	return error
