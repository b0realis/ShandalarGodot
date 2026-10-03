class_name SgPayment
extends RefCounted
## Referee-only payment estimates. One source enumeration per decision; no
## client simulation. X costs in this engine grow monotonically with X.

const OC := preload("res://engine/additional_object_costs.gd")

static func due(g: MtgGame, pid: int, card: CardInstance, kind: String, index: int, x: int, count := 1, mode := 0) -> Dictionary:
	return g.spell_payment(pid, card.data, x, count, card, mode) if kind == "spell" else g.ability_payment(pid, card, index, x)

static func budget(g: MtgGame, pid: int, card: CardInstance, kind: String, index: int, sources: Array, count := 1, mode := 0) -> int:
	if kind == "spell" and card.data.additional_life_is_x:
		return clampi(g.players[pid].life, 0, 1000)
	var low := 0
	var high := 1000
	while low < high:
		var middle := (low + high + 1) / 2
		var cost := due(g, pid, card, kind, index, middle, count, mode)
		if can_pay_now(g, pid, cost, kind) \
			or not ManaPlanner.plan_from(sources, cost.cost, cost.extra, cost.usage).is_empty(): low = middle
		else: high = middle - 1
	# X COUNTS OBJECTS (Pack 8 — Infernal Harvest's Swamps, Haunting Misery's
	# creature cards, Firestorm's discards): it costs no mana, so the mana
	# search above finds no bound at all. The bound is how many of those
	# objects the seat could pay with — the engine's own count, the one the
	# local X window uses (DuelScreen._open_x_dialog).
	var objects := OC.max_x(g, pid, object_groups(card, kind, index, mode), card)
	return low if objects < 0 else mini(low, objects)


## The object-cost groups an action pays (engine/additional_object_costs.gd):
## a spell's additional costs with its chosen payment row's, or an
## activated ability's own.
static func object_groups(card: CardInstance, kind: String, index: int, mode := 0) -> Array:
	if kind == "spell":
		var alternate: Array = card.data.payment_option(mode).get("object_costs", [])
		return card.data.object_costs if alternate.is_empty() else card.data.object_costs + alternate
	if kind == "ability" and index >= 0 and index < card.cur_activated_abilities.size():
		return card.cur_activated_abilities[index].object_costs
	return []


## Does the action's X count OBJECTS rather than mana — no {X} printed, and
## a count-is-X object group (OC.times_x)? Such an X is always the seat's to
## say: a double-click may spend mana, never a hand or a graveyard.
static func object_x(card: CardInstance, kind: String, index: int, mode := 0) -> bool:
	var printed: ManaCost = null
	if kind == "spell": printed = card.data.cost
	elif kind == "ability" and index >= 0 and index < card.cur_activated_abilities.size():
		printed = card.cur_activated_abilities[index].cost
	return printed != null and printed.x_count <= 0 and OC.uses_x(object_groups(card, kind, index, mode))


## Use the same floating-pool permissions as the referee's final payment.
## North Star applies to spells only; Sunglasses also applies to abilities.
static func can_pay_now(g: MtgGame, pid: int, payment: Dictionary, kind: String) -> bool:
	var p := g.players[pid]
	return p.mana_pool.can_pay(payment.cost, payment.extra, payment.usage,
		p.mana_substitutions, kind == "spell" and p.any_color_spells > 0)


## Public affordance, not permission to cast. The real cast still validates
## timing, targets and every object cost. Include pitch modes and instance-
## scoped mana restrictions instead of pricing only the printed mana cost.
##
## Pack 8: a payment row's OBJECT costs are asked too — Fireblast's "two
## Mountains" row is no payment without two Mountains — and the floor of a
## Kaervek's Torch's targeting surcharge (`targeting_surcharge_floor`, the
## local screen's MtgGame.could_afford) rides on the mana. With
## [param alternatives] off only the printed row is priced, which is the
## local screen's "floating" question (`_has_affordable_fast_effect`).
static func affordable(g: MtgGame, pid: int, card: CardInstance, potential := false, alternatives := true) -> bool:
	for mode in maxi(1, card.data.modes.size()):
		var option := card.data.payment_option(mode)
		if not alternatives and not option.is_empty(): continue
		if int(option.get("life", 0)) > g.players[pid].life: continue
		if int(option.get("exile_color", 0)) != 0 and g.pitch_candidates(pid, card, mode).is_empty(): continue
		var groups := g.spell_object_costs(card.data, mode)
		if not groups.is_empty() and OC.refusal(g, pid, groups, card, 0) != "": continue
		var cost := due(g, pid, card, "spell", 0, 0, 1, mode)
		var extra := int(cost.extra) + g.targeting_surcharge_floor(pid, card.data, card, mode)
		var p := g.players[pid]
		if p.mana_pool.can_pay(cost.cost, extra, cost.usage, p.mana_substitutions, p.any_color_spells > 0): return true
		if potential and not ManaPlanner.plan(g, pid, cost.cost, extra, cost.usage).is_empty(): return true
	return false
