class_name TargetPlan
extends RefCounted
## Turns the FLAT list of TargetRefs a caller supplies into the per-effect
## GROUPS the resolution code needs, and validates the whole choice in one
## place (CR 601.2c/d — "choose targets", then "divide" — both locked in as
## the spell is put on the stack).
##
## Why a separate class: every targeting effect used to take exactly one
## target, so a flat array indexed by effect position was enough. The 1997
## pool wants three more shapes —
##   "Tap X target creatures"                  (Word of Binding)
##   "One or more target creatures become red" (Dwarven Song)
##   "4 damage divided as you choose among any number of targets" (Pyrotechnics)
## — so the number of refs an effect consumes is no longer 1, and for
## divided effects each ref also carries an [member TargetRef.amount].
## TargetPlan owns that arithmetic; MtgGame just asks for a plan and either
## refuses with [member error] or stores [member groups] on the stack item.
##
## Grouping rule: walk the targeting effects in order; each takes at least
## its minimum, and a variable-count effect absorbs whatever is left over
## after reserving the later effects' minimums. No card in the pool has two
## variable-count effects, so this is unambiguous in practice.

## One Array[TargetRef] per TARGETING effect, in effect order.
var groups: Array = []

## The specs, parallel to [member groups] — for error messages and the UI.
var specs: Array[TargetSpec] = []

## Empty on success; a human-readable refusal otherwise.
var error: String = ""

## Indices into [member groups] of the specs an OPPONENT chooses
## ([member TargetSpec.chosen_by_opponent]). Each is built EMPTY — the
## activator supplies no ref for it — and filled by
## [method MtgGame._fill_adverse_targets] once every refusal has been
## checked, so the opponent is never asked about an activation that then
## fails on mana.
var adverse_groups: Array[int] = []

## Indices into [member groups] of the specs the GAME rolls
## ([member TargetSpec.chosen_at_random]). Built EMPTY like an opponent's
## slot, and filled by [method MtgGame._fill_random_targets] once every
## refusal and every cost question is behind, so the roll is made once
## per announcement and never for a cast that then fails.
var random_groups: Array[int] = []

## Parallel to [member random_groups]: the count range each roll must
## honour ([method EffectBase.target_range] at the announced X; -1 = any
## number, which the roll bounds by what exists).
var random_spans: Array[Vector2i] = []

## Parallel to [member random_groups]: the DIVIDED total the roll also
## splits among what it picks (Orcish Catapult's X counters — CR 601.2d,
## every target at least one), or -1 for an effect that divides nothing.
var random_totals: Array[int] = []


## Flatten back to the ref list (what StackItem.targets keeps holding, so
## the fizzle check and the UI keep working unchanged).
func flat() -> Array[TargetRef]:
	var out: Array[TargetRef] = []
	for group in groups:
		for ref in group:
			out.append(ref)
	return out


## Total number of refs this plan consumed.
func count() -> int:
	var n := 0
	for group in groups:
		n += group.size()
	return n


## Plan for a spell: an Aura's enchant target, or its effects' specs.
static func for_spell(game: MtgGame, data: CardData, mode: int, targets: Array,
		x_value: int, source: CardInstance) -> TargetPlan:
	if data.is_aura():
		var plan := TargetPlan.new()
		plan.specs = [data.aura_target]
		if targets.size() != 1:
			plan.error = "%s needs 1 target (%s), got %d" % [
				data.card_name, data.aura_target.description, targets.size()]
			return plan
		plan.groups = [[targets[0]]]
		plan._validate(game, source, [null])
		return plan
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	return _build(game, effects, targets, x_value, source, data.card_name)


## Plan for an activated ability.
static func for_ability(game: MtgGame, ability: ActivatedAbility, targets: Array,
		x_value: int, source: CardInstance) -> TargetPlan:
	return _build(game, ability.effects, targets, x_value, source, "that ability")


## The shared planner behind [method for_spell] and [method for_ability]:
## work out how many refs each targeting effect wants (clamped to what is
## actually legal), slice [param targets] into groups accordingly, then
## validate. [param what] names the source in refusals ("Pyrotechnics",
## "that ability"), so the message reads the same for spells and abilities.
static func _build(game: MtgGame, effects: Array, targets: Array, x_value: int,
		source: CardInstance, what: String) -> TargetPlan:
	var plan := TargetPlan.new()
	var targeting: Array = []
	for e in effects:
		if e.target_spec != null:
			targeting.append(e)
	# Requirements, with the "as many as possible" clamp: a spell that asks
	# for X targets but sees only two legal ones asks for two (CR 601.2c).
	var reqs: Array = []
	# The refs the EARLIER slots hold, for a census whose spec reads its
	# siblings (Drafna's "from target player's graveyard"): known exactly
	# while every slot before it is fixed-count, unknown (empty) after the
	# first variable one — no card in the pool has two.
	var earlier_known := true
	var earlier_count := 0
	for e in targeting:
		var span: Vector2i = e.target_range(x_value)
		var lo: int = span.x
		var hi: int = span.y
		var rolled: bool = e.target_spec.chosen_at_random
		if e.target_spec.chosen_by_opponent:
			# "… of an opponent's choice": not the activator's to supply,
			# so the slice takes nothing here and the group waits for the
			# opponent's answer (see [member adverse_groups]).
			lo = 0
			hi = 0
			plan.adverse_groups.append(reqs.size())
		elif rolled:
			# "… random target creatures": the game's to roll, not the
			# activator's to supply — the slice takes nothing and the group
			# waits for the roll (see [member random_groups]), which
			# honours the range and the divided total recorded here.
			plan.random_groups.append(reqs.size())
			plan.random_spans.append(span)
			plan.random_totals.append(e.divided_amount(x_value)
				if (e.divided_uses_x or e.divided_total > 0) else -1)
			lo = 0
			hi = 0
		# Only VARIABLE-count effects need the legal-target census; the
		# single-target majority skips the scan entirely.
		if not rolled and (e.target_count_is_x or hi < 0):
			var earlier: Array = []
			if earlier_known:
				earlier = targets.slice(0, mini(earlier_count, targets.size()))
			var available: int = e.target_spec.legal_targets(
				game, source, earlier).size()
			if e.target_count_is_x:
				# SIMPLIFIED (docs/ROADMAP.md): "X target creatures" with
				# fewer than X legal targets takes as many as exist instead
				# of forcing a smaller X — the 1997 engine was equally
				# forgiving and it keeps the AI from stalling on its own
				# X choice.
				lo = mini(lo, available)
				hi = mini(hi, available)
			else:
				hi = available   # "any number" is bounded by what exists
		reqs.append({"effect": e, "spec": e.target_spec, "min": lo, "max": hi})
		plan.specs.append(e.target_spec)
		if lo != hi:
			earlier_known = false
		earlier_count += lo
	# Reserve each later effect's minimum, then let this one take the rest.
	var i := 0
	for k in reqs.size():
		var req: Dictionary = reqs[k]
		var later_min := 0
		for j in range(k + 1, reqs.size()):
			later_min += int(reqs[j]["min"])
		var spare: int = targets.size() - i - later_min
		var take: int = clampi(spare, int(req["min"]), int(req["max"]))
		if take < int(req["min"]) or i + take > targets.size():
			plan.error = "%s needs %d target(s) for '%s', got %d" % [
				what, int(req["min"]), req["spec"].description, maxi(spare, 0)]
			return plan
		var group: Array = []
		for n in take:
			group.append(targets[i + n])
		plan.groups.append(group)
		i += take
	if i != targets.size():
		# The usual cause is a ref that isn't legal for the last spec at all
		# (a creature offered to "target land"), so say THAT — it is what the
		# player did wrong, and it keeps the message identical to the
		# single-target path's.
		if not reqs.is_empty():
			var last: Dictionary = reqs[reqs.size() - 1]
			# Judged with the earlier slots' refs in hand, as _validate
			# would: a card from the wrong graveyard is refused for its
			# `owner`, not for being one too many.
			var last_start: int = i - plan.groups.back().size()
			var late_why: String = last["spec"].refusal_reason(
				game, targets[i], source, targets.slice(0, last_start))
			if late_why != "":
				plan.error = "Illegal target (%s)." % late_why
				return plan
		plan.error = "%s takes %d target(s), got %d" % [what, i, targets.size()]
		return plan
	var effect_list: Array = []
	for req in reqs:
		effect_list.append(req["effect"])
	plan._validate(game, source, effect_list, x_value)
	return plan


## Legality, the no-duplicate rule, and the divided-amount arithmetic.
func _validate(game: MtgGame, source: CardInstance, effects: Array,
		x_value: int = 0) -> void:
	# THE REFUSAL IS THE ORIGINAL'S (§6.10). `@PROMPT_ILLEGALTARGET`
	# (`UIStrings.txt:1145`) is `Illegal target (%s).`, and what goes in
	# the brackets is one of `@PROMPT_ILLEGALTARGETWHY`'s 29 reasons —
	# see [constant TargetSpec.WHY]. What stood here named the
	# REQUIREMENT ("illegal target for 'target creature'"), which is the
	# prompt the player was already reading when they clicked; the
	# original names what is WRONG instead.
	# A slot may be stated relative to the ones before it ("… that shares
	# one of those types with it" — [member TargetSpec.sibling_filter]), so
	# each group is judged with the earlier groups' refs in hand.
	var earlier: Array = []
	for gi in groups.size():
		for ref in groups[gi]:
			var why: String = specs[gi].refusal_reason(game, ref, source, earlier)
			if why != "":
				error = "Illegal target (%s)." % why
				return
		earlier.append_array(groups[gi])
	# "Two target creatures" means two DIFFERENT ones (CR 601.2c) — and the
	# rule spans the whole spell, so a divided spell can't double-dip either.
	var all := flat()
	for i in all.size():
		for j in range(i + 1, all.size()):
			var a: TargetRef = all[i]
			var b: TargetRef = all[j]
			# One identity test for the whole TargetRef union: comparing
			# `instance_id` by hand read -1 == -1 for two DIFFERENT damage
			# packets (§6.8 slice 3).
			if a.same_object(b):
				error = "can't choose the same target twice"
				return
	# DIVISION (CR 601.2d): every chosen target gets at least 1, and the
	# shares add up to the stated total. A single chosen target absorbs the
	# whole total, so callers may pass a plain TargetRef for the common case.
	for gi in effects.size():
		var effect: EffectBase = effects[gi]
		if effect == null:
			continue
		var total: int = effect.divided_amount(x_value)
		if total <= 0:
			continue
		var group: Array = groups[gi]
		if group.is_empty():
			continue
		if group.size() == 1:
			groups[gi] = [group[0].with_amount(total)]
			continue
		if group.size() > total:
			error = "can't divide %d among %d targets" % [total, group.size()]
			return
		var sum := 0
		for ref in group:
			if ref.amount < 1:
				error = "each target must be assigned at least 1"
				return
			sum += ref.amount
		if sum != total:
			error = "divided amounts must add up to %d (got %d)" % [total, sum]
			return
