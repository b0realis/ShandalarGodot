class_name SgPayment
extends RefCounted
## Referee-only payment estimates. One source enumeration per decision; no
## client simulation. X costs in this engine grow monotonically with X.

const OC := preload("res://engine/additional_object_costs.gd")

static func due(g: MtgGame, pid: int, card: CardInstance, kind: String, index: int, x: int, count := 1, mode := 0) -> Dictionary:
	return g.spell_payment(pid, card.data, x, count, card, mode) if kind == "spell" else g.ability_payment(pid, card, index, x)

static func budget(g: MtgGame, pid: int, card: CardInstance, kind: String, index: int, sources: Array, count := 1, mode := 0) -> int:
	# A row that FIXES X AT 0 (Pack 9 bug pass): an alternative cost
	# without the {X} the card prints — a row Dream Halls or Aluren grants,
	# a pitch (CR 107.3b). It prices every X alike, so the search below ran
	# to its ceiling and published 1000, every X of which the engine refuses.
	if kind == "spell" and fixes_x_at_zero(g, pid, card, mode):
		return 0
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
	var objects := OC.max_x(g, pid, object_groups(card, kind, index, mode, g, pid), card)
	if objects >= 0: low = mini(low, objects)
	# "X TARGETS" (bug pass 2026-10-04 — Firestorm's "each of X targets",
	# Word of Binding, Volcanic Eruption): each target an X asks for is
	# named as the spell is cast (CR 601.2c), so X is bounded by the targets
	# there are to name as well. Firestorm offered X = 4 for four cards in
	# hand with two players to aim at. The local X window's ceiling.
	var targets := x_target_ceiling(g, card, kind, index, mode, low, pid)
	return low if targets < 0 else mini(low, targets)


## Does payment row [param mode] of [param card] fix X at 0 for
## [param pid]? An ALTERNATIVE cost whose mana has no {X}, on a card that
## prints one: "If an alternative cost is being paid that doesn't include
## X, X is 0" (CR 107.3b) — the engine's own test
## (MtgGame._spell_cost_checks; the local screen's _pending_wants_x).
static func fixes_x_at_zero(g: MtgGame, pid: int, card: CardInstance, mode: int) -> bool:
	if card.data.cost.x_count <= 0: return false
	var row := g.payment_option_for(pid, card.data, mode, card)
	var row_cost: Variant = row.get("cost", card.data.cost)
	return MtgGame.is_alternative_payment(row) and row_cost is ManaCost \
		and not (row_cost as ManaCost).has_x


## THE EFFECTS PAYMENT ROW [param mode] OF [param card] CASTS for
## [param pid] (Pack 9): a mode's own; a printed row's (a buyback row
## shares its spell's); a row a permanent GRANTS (Dream Halls, Aluren)
## the printed row it is built on — [method MtgGame.payment_rows]. Empty
## for a row the card does not have.
static func row_effects(g: MtgGame, pid: int, card: CardInstance, mode: int) -> Array:
	if card.data.is_modal() and mode >= 0 and mode < card.data.modes.size():
		return card.data.modes[mode].effects
	if mode == 0 and not card.data.is_modal():
		return card.data.spell_effects
	if g == null or pid < 0 or mode < 0: return []
	var rows := g.payment_rows(pid, card)
	return Dictionary(rows[mode]).get("effects", []) if mode < rows.size() else []


## The most targets the action's caster-chosen "X target" slots can name
## (the fewest legal targets among them), or -1 when no slot's count is X.
## [param x] is the X the targets are judged at (`legal_targets_at`).
static func x_target_ceiling(g: MtgGame, card: CardInstance, kind: String, index: int, mode: int, x: int, pid := -1) -> int:
	var effects: Array = []
	if kind == "spell" and not card.data.is_aura():
		effects = row_effects(g, pid, card, mode)
	elif kind == "ability" and index >= 0 and index < card.cur_activated_abilities.size():
		effects = card.cur_activated_abilities[index].effects
	var ceiling := -1
	for effect in effects:
		if effect.target_spec == null or not effect.target_count_is_x or not effect.target_spec.is_supplied_by_caster(): continue
		var available := g.legal_targets_at(effect.target_spec, card, x).size()
		ceiling = available if ceiling < 0 else mini(ceiling, available)
	return ceiling


## The object-cost groups an action pays (engine/additional_object_costs.gd):
## a spell's additional costs with its chosen payment row's, or an
## activated ability's own. With the referee [param g] and the payer
## [param pid] a row's groups are the engine's own reading
## ([method MtgGame.spell_object_costs] — a buyback's "Sacrifice a land",
## a row a permanent GRANTS: Dream Halls' discard, Pack 9).
static func object_groups(card: CardInstance, kind: String, index: int, mode := 0,
		g: MtgGame = null, pid := -1) -> Array:
	if kind == "spell":
		if g != null and pid >= 0:
			return g.spell_object_costs(card.data, mode, pid, card)
		var alternate: Array = card.data.payment_option(mode).get("object_costs", [])
		return card.data.object_costs if alternate.is_empty() else card.data.object_costs + alternate
	if kind == "ability" and index >= 0 and index < card.cur_activated_abilities.size():
		return card.cur_activated_abilities[index].object_costs
	return []


## Does the action's X count OBJECTS rather than mana — no {X} printed, and
## a count-is-X object group (OC.times_x)? Such an X is always the seat's to
## say: a double-click may spend mana, never a hand or a graveyard.
static func object_x(card: CardInstance, kind: String, index: int, mode := 0,
		g: MtgGame = null, pid := -1) -> bool:
	var printed: ManaCost = null
	if kind == "spell": printed = card.data.cost
	elif kind == "ability" and index >= 0 and index < card.cur_activated_abilities.size():
		printed = card.cur_activated_abilities[index].cost
	return printed != null and printed.x_count <= 0 and OC.uses_x(object_groups(card, kind, index, mode, g, pid))


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
	for mode in maxi(1, g.payment_rows(pid, card).size()):
		if mode_affordable(g, pid, card, mode, potential, alternatives): return true
	return false


## [method affordable] for ONE payment row or mode [param mode] — its life,
## its card to exile, its object costs and its mana with the Torch floor
## (2026-10-04: the referee's options name the payable modes one by one,
## so a Fireblast with one Mountain offers no "sacrifice two Mountains").
##
## THE ENGINE'S OWN QUESTION since Pack 9 ([method
## MtgGame.payment_row_refusal]): the rows are [method
## MtgGame.payment_rows] — a BUYBACK row's added mana, land, cards or life
## and a row a permanent GRANTS (Dream Halls, Aluren) are priced the way
## the cast will price them, with an additional sacrifice's body asked
## too. [param alternatives] off prices the printed row alone.
static func mode_affordable(g: MtgGame, pid: int, card: CardInstance, mode: int, potential := false, alternatives := true) -> bool:
	var option := g.payment_option_for(pid, card.data, mode, card)
	if not alternatives and not option.is_empty(): return false
	return g.payment_row_refusal(pid, card, mode, potential) == ""
