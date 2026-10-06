extends RefCounted
## Whole-declaration restrictions. An individually legal creature does not
## imply a legal army; requirements must maximize what restrictions allow.

static func mandatory(i: CardInstance) -> bool:
	return i.must_attack_this_turn or i.has_keyword(Mtg.Keyword.MUST_ATTACK)

static func attack_error(g: MtgGame, pid: int, ids: Array, requirements := true) -> String:
	var seen := {}
	var met := 0
	for id in ids:
		if seen.has(id): return "a creature can attack only once"
		seen[id] = true
		var i := g.find_instance(id)
		if i.cur_attacks_alone and ids.size() != 1: return "%s can attack only alone" % i.data.card_name
		if ids.size() < i.cur_min_attack_group: return "%s needs at least %d attacking creatures" % [i.data.card_name, i.cur_min_attack_group]
		if mandatory(i): met += 1
	if requirements and met < required_attacks(g, pid):
		for i in g.players[pid].battlefield:
			if seen.has(i.id) or not mandatory(i): continue
			if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
			if not i.cur_attack_costs.is_empty() or i.cur_attack_land_sacrifices > 0: continue
			if i.must_attack_this_turn: return "%s must attack this turn if able" % i.data.card_name
			return "%s attacks each combat if able" % i.data.card_name
		return "declare as many required attackers as the combat restrictions allow"
	if requirements and not ids.is_empty():
		var why := _conditional_error(g, pid, seen, met)
		if why != "": return why
	return ""


## The creatures [param pid] controls whose CONDITIONAL requirement
## applies to this declaration — "if a creature you control attacks, this
## creature also attacks if able" (Ekundu Cyclops,
## [member CardInstance.cur_attacks_if_others_attack]) — and that are ABLE:
## no restriction stops them, and they carry no attack cost, which no
## player is ever required to pay (CR 508.1d).
static func conditional_attackers(g: MtgGame, pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if not i.cur_attacks_if_others_attack or i.cur_attacks_alone: continue
		if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
		if not i.cur_attack_costs.is_empty() or i.cur_attack_land_sacrifices > 0: continue
		out.append(i)
	return out


## CR 508.1d with conditional requirements: a declaration must obey as
## many requirements as any legal declaration could. Declaring NOBODY
## obeys every conditional one (the condition never arises); a declaration
## of anybody obeys a conditional one only by including that creature. So
## with nothing stopping it, a Cyclops attacks beside whoever attacks — and
## under an attacker cap (Caverns of Despair) the declaration that fills
## the cap with the most requirements wins, which may be the Cyclops alone.
## [param seen] / [param met]: the declared ids and how many mandatory
## attackers among them, as [method attack_error] counted them.
##
## PREDICATE requirements (Pack 9 E4 — Magnetic Web,
## [member CardInstance.cur_attack_requirements]) join the same count: a
## declaration obeys one when its creature is in it OR its condition does
## not hold for it ("if a creature with a magnet counter attacks" — a
## declaration without one asks nothing). With none on the battlefield
## this is exactly the Cyclops-only count it always was.
static func _conditional_error(g: MtgGame, pid: int, seen: Dictionary, met: int) -> String:
	var cond := conditional_attackers(g, pid)
	var pred := predicate_attackers(g, pid)
	if cond.is_empty() and pred.is_empty(): return ""
	var obeyed := met
	for i in cond:
		if seen.has(i.id): obeyed += 1
	var declared := _instances(g, seen.keys())
	var unmet: Array[CardInstance] = []
	for i in pred:
		if seen.has(i.id) or not requirement_applies(g, i, declared): obeyed += 1
		else: unmet.append(i)
	var everyone: Array[CardInstance] = cond.duplicate()
	everyone.append_array(pred)
	if obeyed >= _most_requirements(g, pid, everyone): return ""
	for i in cond:
		if not seen.has(i.id):
			return "%s attacks if able when a creature you control attacks" % i.data.card_name
	for i in unmet:
		return "%s attacks if able when %s" % [i.data.card_name, _requirement_desc(g, i, declared)]
	return "declare as many required attackers as the combat restrictions allow"


## The most requirements — mandatory and conditional together — that a
## declaration by [param pid] could obey (CR 508.1d), given the able
## conditional attackers [param cond]: the empty declaration's
## `cond.size()`, or the best set of attackers the cap allows, each
## weighing one per requirement it obeys.
static func _most_requirements(g: MtgGame, pid: int, cond: Array[CardInstance]) -> int:
	var weights: Array[int] = []
	for i in g.players[pid].battlefield:
		if i.cur_attacks_alone: continue
		if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
		if not i.cur_attack_costs.is_empty() or i.cur_attack_land_sacrifices > 0: continue
		var weight := (1 if mandatory(i) else 0) + (1 if cond.has(i) else 0)
		if weight > 0: weights.append(weight)
	weights.sort()
	weights.reverse()
	var slots := weights.size() if g.max_attackers <= 0 else mini(weights.size(), g.max_attackers)
	var best := 0
	for k in slots: best += weights[k]
	return maxi(cond.size(), best)

static func required_attacks(g: MtgGame, pid: int) -> int:
	if g.no_attacks_this_turn: return 0
	var ordinary: Array[CardInstance] = []
	var alone := 0
	for i in g.players[pid].battlefield:
		if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
		# CR 508.1d: no player is forced to pay an attack cost.
		if not i.cur_attack_costs.is_empty() or i.cur_attack_land_sacrifices > 0: continue
		if i.cur_attacks_alone:
			if mandatory(i) and i.cur_min_attack_group <= 1: alone = 1
		else: ordinary.append(i)
	var cap := ordinary.size() if g.max_attackers <= 0 else mini(ordinary.size(), g.max_attackers)
	var needed := 0
	for i in ordinary:
		if mandatory(i) and i.cur_min_attack_group <= cap: needed += 1
	return maxi(alone, mini(needed, cap))

static func block_fee(g: MtgGame, blocks: Dictionary) -> int:
	var total := 0
	for id in blocks:
		var i := g.find_instance(id)
		for target in blocks[id]:
			var a := g.find_instance(target)
			if a != null: total += a.cur_blocked_by_tax
			if a != null and a.cur_power >= i.cur_block_power_tax_threshold: total += i.cur_block_power_tax
	return total

## The LIFE the whole block declaration costs (CR 509.1d — Heat Wave's
## "1 life for each blocking creature"): per blocking creature, each
## imposing source once ([method CombatState.block_life_owed]).
static func block_life_fee(g: MtgGame, blocks: Dictionary) -> int:
	var total := 0
	for id in blocks:
		var blocker := g.find_instance(int(id))
		var against: Array = []
		var value: Variant = blocks[id]
		for target in (value if value is Array else [value]):
			against.append(g.find_instance(int(target)))
		total += CombatState.block_life_owed(blocker, against)
	return total

static func block_error(g: MtgGame, blocks: Dictionary) -> String:
	var counts := {}
	for id in blocks:
		var i := g.find_instance(id)
		if blocks.size() < i.cur_min_block_group: return "%s needs at least %d blocking creatures" % [i.data.card_name, i.cur_min_block_group]
		for target in blocks[id]:
			counts[target] = int(counts.get(target, 0)) + 1
			var attacker := g.find_instance(target)
			if attacker.cur_max_blockers > 0 and counts[target] > attacker.cur_max_blockers:
				return "%s can't be blocked by more than %d creature(s)" % [attacker.data.card_name, attacker.cur_max_blockers]
	return ""

## Repair a proposed AI army, retaining its preferred attackers whenever
## possible and obeying mandatory attackers before optimizing damage.
static func repair_attacks(g: MtgGame, pid: int, proposed: Array) -> Array:
	if attack_error(g, pid, proposed) == "": return proposed
	var candidates: Array = []
	var ordinary: Array = []
	for i in g.players[pid].battlefield:
		if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
		# A land-taxed attacker (Exalted Dragon, CR 508.1g) is a voluntary
		# resource cost: never ADDED by the repair, but one the plan itself
		# volunteered (the planner priced its land, AiPlayer._add_taxed_attackers)
		# stays — dropping it whenever a requirement asked for a repair meant
		# a Dragon beside a magnet companion never attacked (Pack 9).
		if i.cur_attack_land_sacrifices > 0 and not proposed.has(i.id): continue
		if i.cur_attacks_alone:
			if i.cur_min_attack_group <= 1: candidates.append([i.id])
		else: ordinary.append(i.id)
	# A CONDITIONAL attacker (Ekundu Cyclops) is required as soon as anyone
	# attacks, so beside a non-empty plan it ranks with the mandatory ones.
	var conditional: Array = []
	if not proposed.is_empty():
		for i in conditional_attackers(g, pid): conditional.append(i.id)
		# Pack 9 E4: the PREDICATE requirements the plan sets off (a magnet
		# creature in it brings the other magnet creatures along).
		conditional.append_array(predicate_companions(g, pid, proposed))
	ordinary.sort_custom(func(a: int, b: int) -> bool:
		var left := g.find_instance(a)
		var right := g.find_instance(b)
		var lv := (10000 if mandatory(left) or conditional.has(a) else 0) + (1000 if proposed.has(a) else 0) + left.cur_power
		var rv := (10000 if mandatory(right) or conditional.has(b) else 0) + (1000 if proposed.has(b) else 0) + right.cur_power
		return lv > rv)
	var base: Array = []
	for id in ordinary:
		if g.max_attackers > 0 and base.size() >= g.max_attackers: break
		var i := g.find_instance(id)
		if proposed.has(id) or mandatory(i) or conditional.has(id): base.append(id)
	# A required Conscripts may need volunteers; an optional one never
	# conscripts bad attacks merely to preserve the initial plan.
	var minimum := 1
	for id in base:
		var i := g.find_instance(id)
		if mandatory(i): minimum = maxi(minimum, i.cur_min_attack_group)
	for id in ordinary:
		if base.size() >= minimum or (g.max_attackers > 0 and base.size() >= g.max_attackers): break
		if not base.has(id): base.append(id)
	for id in base.duplicate():
		if g.find_instance(id).cur_min_attack_group > base.size(): base.erase(id)
	candidates.append(base)
	candidates.append([])
	var best: Array = []
	var value := -INF
	for option in candidates:
		if attack_error(g, pid, option) != "": continue
		var score := 0.0
		for id in option:
			var i := g.find_instance(id)
			score += 10000.0 if mandatory(i) else 0.0
			score += 100.0 + float(i.cur_power) if proposed.has(id) else -10.0
		if score > value:
			value = score
			best = option
	return best

static func repair_blocks(g: MtgGame, pid: int, proposed: Dictionary) -> Dictionary:
	var out := g._normalise_block_map(proposed)
	var counts := {}
	for id in out.keys():
		for target in out[id].duplicate():
			var attacker := g.find_instance(target)
			if attacker == null or (attacker.cur_max_blockers > 0 and int(counts.get(target, 0)) >= attacker.cur_max_blockers): out[id].erase(target)
			else: counts[target] = int(counts.get(target, 0)) + 1
		if out[id].is_empty(): out.erase(id)
	for id in out.keys():
		if g.find_instance(id).cur_min_block_group > out.size(): out.erase(id)
	# Optional block fees must fit the ENTIRE declaration. Prefer keeping
	# free blocks to consuming the same floating mana twice.
	while block_fee(g, out) > 0 and not g.can_afford_cost(pid, ManaCost.parse("{%d}" % block_fee(g, out))):
		var removed := false
		for id in out.keys():
			if block_fee(g, {id: out[id]}) > 0:
				out.erase(id)
				removed = true
				break
		if not removed: break
	# LIFE taxes (Heat Wave) likewise — and never the last point: paying
	# down to 0 is legal (CR 119.4) but loses the game at once.
	while block_life_fee(g, out) > 0 and block_life_fee(g, out) >= g.players[pid].life:
		var dropped := false
		for id in out.keys():
			if block_life_fee(g, {id: out[id]}) > 0:
				out.erase(id)
				dropped = true
				break
		if not dropped: break
	for id in out.keys():
		if g.find_instance(id).cur_min_block_group > out.size(): out.erase(id)
	# A maximum-one restriction combined with menace cannot be satisfied
	# by trimming a two-creature block to one; that attacker is unblocked.
	counts.clear()
	for id in out:
		for target in out[id]: counts[target] = int(counts.get(target, 0)) + 1
	for id in out.keys():
		for target in out[id].duplicate():
			if int(counts[target]) < g.find_instance(target).cur_min_blockers: out[id].erase(target)
		if out[id].is_empty(): out.erase(id)
	# Pack 9 E4: the blocks a requirement orders (Watchdog, Invasion Plans,
	# Provoke — and since the Pack 9 bug pass every Lure and Blaze of Glory,
	# counted together as the engine counts them) go in last, over the
	# trimmed plan, so nothing above can take one out again.
	return _add_forced_blocks(g, pid, out)


# --- Pack 9 E4: Combat requirements ---

## The ABLE creatures [param pid] controls with a PREDICATE attack
## requirement ([member CardInstance.cur_attack_requirements], Magnetic
## Web) — the predicate twin of [method conditional_attackers], with the
## same exclusions (a restriction stops it, it attacks only alone, or it
## carries an attack cost no player is required to pay, CR 508.1d). A
## creature that also has the Cyclops requirement is counted there.
static func predicate_attackers(g: MtgGame, pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.cur_attack_requirements.is_empty() or i.cur_attacks_if_others_attack or i.cur_attacks_alone: continue
		if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
		if not i.cur_attack_costs.is_empty() or i.cur_attack_land_sacrifices > 0: continue
		out.append(i)
	return out


## Does one of [param i]'s predicate requirements hold for a declaration
## of the CardInstances [param declared]?
static func requirement_applies(g: MtgGame, i: CardInstance, declared: Array) -> bool:
	for entry in i.cur_attack_requirements:
		var condition: Callable = entry["condition"]
		if condition.is_valid() and bool(condition.call(g, declared)):
			return true
	return false


## The ids of the predicate-bound creatures a plan of [param ids] sets off
## and that are not in it — followed to a fixpoint, since each one added
## may set off another (the plan's mandatory and Cyclops companions count
## as declared). What [method repair_attacks] adds beside a non-empty plan;
## an AI pricing its attack may ask it too.
static func predicate_companions(g: MtgGame, pid: int, ids: Array) -> Array:
	var pred := predicate_attackers(g, pid)
	if pred.is_empty() or ids.is_empty(): return []
	var plan: Array = ids.duplicate()
	for i in conditional_attackers(g, pid):
		if not plan.has(i.id): plan.append(i.id)
	for i in g.players[pid].battlefield:
		if mandatory(i) and not plan.has(i.id) and CombatState.attack_illegality(g, i, 1 - pid) == "":
			plan.append(i.id)
	var out: Array = []
	var grew := true
	while grew:
		grew = false
		var declared := _instances(g, plan)
		for i in pred:
			if plan.has(i.id) or not requirement_applies(g, i, declared): continue
			plan.append(i.id)
			out.append(i.id)
			grew = true
	return out


static func _requirement_desc(g: MtgGame, i: CardInstance, declared: Array) -> String:
	for entry in i.cur_attack_requirements:
		var condition: Callable = entry["condition"]
		if condition.is_valid() and bool(condition.call(g, declared)):
			return String(entry["desc"])
	return "its condition is met"


static func _instances(g: MtgGame, ids: Array) -> Array:
	var out: Array = []
	for id in ids:
		var inst := g.find_instance(int(id))
		if inst != null: out.append(inst)
	return out


## Is [param i] under an order to make ONE block if able — the static
## "blocks each combat if able" (Watchdog, Invasion Plans:
## [member CardInstance.cur_must_block]) or the one-turn "blocks this turn
## if able" (Provoke: [member CardInstance.must_block_this_turn_any])?
## Blaze of Glory's "blocks EACH attacking creature"
## ([member CardInstance.must_block_this_turn]) is counted per attacker by
## [method obeyed_by].
static func must_block(i: CardInstance) -> bool:
	return i.cur_must_block or i.must_block_this_turn_any


## The attackers [param blocker] could block as part of [param blocks] (a
## normalised map, {blocker id: Array of attacker ids}) WITHOUT paying a
## cost and without breaking a restriction — the blocks a requirement may
## ask of it (CR 509.1c-d): block legality as the engine checks it
## ([method CombatState.block_illegality], which is where shadow, flying,
## protection and the rest are), no mana or life tax on the block, room
## under the attacker's maximum, and enough possible blockers for its
## minimum (menace) among the creatures [param blocks] has not already
## sent elsewhere. Empty when the creature is tapped or not a creature.
## The duel screen's "must block" cue reads it; the engine's own verdict is
## [method must_block_error], which counts the whole declaration.
static func forced_block_targets(g: MtgGame, pid: int, blocker: CardInstance,
		blocks: Dictionary) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	if blocker == null or not blocker.is_creature() or blocker.tapped: return out
	var others := blocks.duplicate()
	others.erase(blocker.id)
	for id in g.combat.attackers:
		var a := g.find_instance(int(id))
		if a == null: continue
		if a.cur_blocked_by_tax > 0: continue
		if blocker.cur_block_power_tax > 0 and a.cur_power >= blocker.cur_block_power_tax_threshold: continue
		if CombatState.block_life_owed(blocker, [a]) > 0: continue
		if a.cur_max_blockers > 0:
			var taken := 0
			for other in others:
				if (others[other] as Array).has(a.id): taken += 1
			if taken >= a.cur_max_blockers: continue
		if not g.can_meet_minimum_blockers(a, pid, others): continue
		if CombatState.block_illegality(g, blocker, a, pid) != "": continue
		out.append(a)
	return out


# --- Pack 9 bug pass (fix-combat): block requirements, counted ---
#
# CR 509.1c: "The defending player checks each creature they control to see
# whether it's affected by any requirements … The number of requirements
# being obeyed must be maximized without violating any restrictions." The
# engine used to ask each requirement on its own — "is there an attacker
# this creature could block?" — and refused a declaration whenever one said
# yes. Two requirements needing the SAME menace partner then refused every
# declaration (a human seat could never leave the step, the AI conceded),
# a full blocker cap excused every unmet requirement whatever the creatures
# in it obeyed, and a narrowed Lure counted as a Lure for every creature.
# Now a declaration is held to the best any legal, cost-free declaration
# could do: a bounded branch-and-bound search over the creatures under a
# requirement (their partners found by matching), like [method
# _most_requirements] does for attacks.

## How many search nodes one question may spend. A board past it (a dozen
## creatures under orders against menace attackers) is answered leniently:
## the declaration in hand stands, so no seat can ever be left without one.
const SEARCH_BUDGET := 8000


## Does the Lure on [param attacker] bind [param blocker]? "All creatures
## able to block it" ([member CardInstance.cur_must_be_blocked_by_all], or
## a Lure with no filter) binds every creature; a NARROWED one (Marble
## Priest's Walls, Trumpeting Armodon's chosen creature, Magnetic Web's
## magnet creatures — [member CardInstance.cur_must_be_blocked_filter])
## only those it names. The one answer the engine, the AI and the cards
## share (CR 509.1c).
static func lure_binds(attacker: CardInstance, blocker: CardInstance) -> bool:
	if attacker == null or blocker == null or not attacker.cur_must_be_blocked:
		return false
	if attacker.cur_must_be_blocked_by_all or not attacker.cur_must_be_blocked_filter.is_valid():
		return true
	return bool(attacker.cur_must_be_blocked_filter.call(blocker))


## The requirements [param blocker] obeys by blocking the attacker ids
## [param against]: its orders to block at all (Watchdog / Invasion Plans,
## Provoke — one each, obeyed by any block) and, per attacker blocked, each
## Lure binding it and Blaze of Glory's "blocks each attacking creature".
static func obeyed_by(g: MtgGame, blocker: CardInstance, against: Array) -> int:
	if blocker == null or against.is_empty(): return 0
	var total := (1 if blocker.cur_must_block else 0) + (1 if blocker.must_block_this_turn_any else 0)
	for id in against:
		total += _pair_weight(blocker, g.find_instance(int(id)))
	return total


## The requirements a whole declaration ([param declared]: {blocker id:
## attacker id or Array of them}) obeys.
static func requirements_obeyed(g: MtgGame, declared: Dictionary) -> int:
	var total := 0
	for id in declared:
		var against: Variant = declared[id]
		total += obeyed_by(g, g.find_instance(int(id)), against if against is Array else [against])
	return total


static func _pair_weight(blocker: CardInstance, a: CardInstance) -> int:
	if a == null: return 0
	return (1 if lure_binds(a, blocker) else 0) + (1 if blocker.must_block_this_turn else 0)


## Is any block requirement on the table at all? The common case answers
## no at once, so a declaration without one costs nothing more.
static func _has_block_requirements(g: MtgGame, pid: int) -> bool:
	for id in g.combat.attackers:
		var a := g.find_instance(int(id))
		if a != null and a.cur_must_be_blocked: return true
	for c in g.players[pid].battlefield:
		if c.cur_must_block or c.must_block_this_turn_any or c.must_block_this_turn: return true
	return false


## A block a requirement may ask for: legal (CR 509.1b — every restriction
## is in [method CombatState.block_illegality]) and free — no requirement
## makes a player pay a cost (CR 509.1d).
static func _free_block(g: MtgGame, pid: int, blocker: CardInstance, a: CardInstance) -> bool:
	if a.cur_blocked_by_tax > 0: return false
	if blocker.cur_block_power_tax > 0 and a.cur_power >= blocker.cur_block_power_tax_threshold: return false
	if CombatState.block_life_owed(blocker, [a]) > 0: return false
	return CombatState.block_illegality(g, blocker, a, pid) == ""


## THE ENGINE'S CHECK (CR 509.1c), called by MtgGame.declare_blockers with
## the normalised declaration once every restriction has passed: "" when it
## obeys as many block requirements — every Lure binding a creature
## ([method lure_binds]), "blocks each combat / this turn if able"
## ([method must_block]), Blaze of Glory's "each attacking creature" — as
## any legal declaration that pays no cost could; otherwise a reason naming
## a creature the better declaration uses. A cap on blocking creatures
## (Caverns of Despair), an attacker's maximum and a menace attacker's
## minimum are restrictions, so they shape what "could" means: two orders
## that need the same partner are obeyed one at a time, and a full cap is
## an excuse only when its places went where they obey the most. Under
## Camouflage the blocks are the spell's procedure, not a declaration, and
## nothing is checked.
static func must_block_error(g: MtgGame, pid: int, declared: Dictionary) -> String:
	if g.camouflage_this_turn or not _has_block_requirements(g, pid): return ""
	var obeyed := requirements_obeyed(g, declared)
	var s := _search_state(g, pid, declared, true, false)
	if obeyed >= int(s["upper"]): return ""
	s["threshold"] = obeyed
	_search_from(s, 0, 0, 0)
	var better: Dictionary = s["best"]
	if better.is_empty(): return ""
	return _requirement_message(g, declared, better)


## The reason for a refusal: the first creature [param better] has obeying
## more than [param declared] lets it, in the words of its requirement.
static func _requirement_message(g: MtgGame, declared: Dictionary, better: Dictionary) -> String:
	for id in better:
		var c := g.find_instance(int(id))
		var mine: Array = better[id]
		var theirs: Variant = declared.get(id, [])
		var had: Array = theirs if theirs is Array else [theirs]
		if obeyed_by(g, c, mine) <= obeyed_by(g, c, had): continue
		for t in mine:
			if had.has(int(t)): continue
			var a := g.find_instance(int(t))
			if lure_binds(a, c) or c.must_block_this_turn:
				return "%s must block %s if able" % [c.data.card_name,
					"a face-down creature" if a.face_down else a.data.card_name]
		if c.cur_must_block:
			return "%s blocks each combat if able" % c.data.card_name
		if c.must_block_this_turn_any:
			return "%s must block this turn if able" % c.data.card_name
	return "declare as many required blocks as the combat restrictions allow"


## The search's state for [param pid]'s declaration: the creatures under a
## requirement ("req", each with its block options, best first), the free
## creatures that may only partner ("spare"), what each may block for free
## ("reach"), and the bound ("upper": the most requirements any
## declaration could obey, the blocker cap counted). [param plan]'s choice
## leads each creature's options, so the declaration found is the nearest
## better one; [param by_preference] ranks equal options by the chooser's
## taste ([method _forced_score]) — the AI's repair — instead of by id.
static func _search_state(g: MtgGame, pid: int, plan: Dictionary, first_only: bool,
		by_preference: bool) -> Dictionary:
	var cap := g.max_blockers
	var attackers: Array[CardInstance] = []
	for id in g.combat.attackers:
		var a := g.find_instance(int(id))
		if a == null: continue
		# An attacker no legal declaration can block (a minimum above its
		# own maximum, or above the cap) is no block anyone owes.
		if a.cur_max_blockers > 0 and a.cur_min_blockers > a.cur_max_blockers: continue
		if cap > 0 and a.cur_min_blockers > cap: continue
		attackers.append(a)
	var attacker_side := g.block_chooser() != pid
	var reach := {}
	var spare: Array = []
	var req: Array = []
	for c in g.players[pid].battlefield:
		if not c.is_creature() or c.tapped: continue
		var can: Array = []
		for a in attackers:
			if _free_block(g, pid, c, a): can.append(a)
		if can.is_empty(): continue
		reach[c.id] = can
		var opts := _block_options(g, c, can, plan.get(c.id), attacker_side, by_preference)
		var top := 0
		for o in opts: top = maxi(top, int(o[0]))
		if top > 0: req.append({"inst": c, "opts": opts, "ub": top})
		else: spare.append(c)
	req.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		if int(x["ub"]) != int(y["ub"]): return int(x["ub"]) > int(y["ub"])
		return (x["inst"] as CardInstance).id < (y["inst"] as CardInstance).id)
	var prefix: Array[int] = [0]
	for e in req: prefix.append(prefix[-1] + int(e["ub"]))
	var choice: Array = []
	choice.resize(req.size())
	return {"g": g, "pid": pid, "cap": cap, "req": req, "spare": spare, "reach": reach,
		"prefix": prefix, "upper": prefix[(mini(req.size(), cap) if cap > 0 else req.size())],
		"threshold": 0, "first_only": first_only, "best": {}, "nodes": 0, "choice": choice,
		"count": {}}


## The block sets the search tries for [param c] among the attackers
## [param can] it may block for free, each as [requirements obeyed, ids]:
## [param planned]'s own first (when it is still free), then the rest by
## requirements obeyed; "no block" last. One attacker each for most
## creatures; for one that may block several (CR 509.1b — Two-Headed Giant
## of Foriys, Blaze of Glory) also the most-requirements set and that set
## without menace attackers.
static func _block_options(g: MtgGame, c: CardInstance, can: Array, planned: Variant,
		attacker_side: bool, by_preference: bool) -> Array:
	var order := (1 if c.cur_must_block else 0) + (1 if c.must_block_this_turn_any else 0)
	var allowed := g.blocks_allowed(c)
	var ranked := can.duplicate()
	ranked.sort_custom(func(x: CardInstance, y: CardInstance) -> bool:
		var wx := _pair_weight(c, x)
		var wy := _pair_weight(c, y)
		if wx != wy: return wx > wy
		if by_preference:
			var px := _forced_score(c, x, attacker_side)
			var py := _forced_score(c, y, attacker_side)
			if px != py: return px > py
		return x.id < y.id)
	var sets: Array = []
	if allowed != 1:
		var most: Array = []
		var lone: Array = []
		for a in ranked:
			if allowed < 0 or most.size() < allowed: most.append(a.id)
			if a.cur_min_blockers <= 1 and (allowed < 0 or lone.size() < allowed): lone.append(a.id)
		sets.append(most)
		sets.append(lone)
	for a in ranked: sets.append([a.id])
	var mine: Array = []
	if planned != null:
		for t in (planned if planned is Array else [planned]):
			for a in ranked:
				if a.id == int(t) and (allowed < 0 or mine.size() < allowed): mine.append(a.id)
	var out: Array = []
	var seen := {}
	for ids in [mine] + sets:
		if ids.is_empty(): continue
		var key: Array = (ids as Array).duplicate()
		key.sort()
		if seen.has(str(key)): continue
		seen[str(key)] = true
		var score := order
		for id in ids: score += _pair_weight(c, g.find_instance(int(id)))
		out.append([score, ids, out.size()])
	var first := 1 if not mine.is_empty() else 0
	var rest := out.slice(first)
	rest.sort_custom(func(x: Array, y: Array) -> bool:
		if int(x[0]) != int(y[0]): return int(x[0]) > int(y[0])
		return int(x[2]) < int(y[2]))
	out = out.slice(0, first) + rest
	out.append([0, [], out.size()])
	return out


## Depth-first over the creatures under a requirement, best options first,
## cut wherever even the best remaining choices could not beat
## "threshold". True stops the search (a better declaration found when
## only one is wanted, the bound reached, or the budget spent).
static func _search_from(s: Dictionary, i: int, score: int, blocking: int) -> bool:
	s["nodes"] = int(s["nodes"]) + 1
	if int(s["nodes"]) > SEARCH_BUDGET: return true
	var req: Array = s["req"]
	var cap: int = s["cap"]
	var prefix: Array[int] = s["prefix"]
	var k := req.size() - i
	if cap > 0: k = mini(k, maxi(cap - blocking, 0))
	if score + prefix[i + k] - prefix[i] <= int(s["threshold"]): return false
	if i == req.size(): return _leaf(s)
	var g: MtgGame = s["g"]
	var count: Dictionary = s["count"]
	var choice: Array = s["choice"]
	for opt in req[i]["opts"]:
		var ids: Array = opt[1]
		if not ids.is_empty():
			if cap > 0 and blocking >= cap: continue
			var fits := true
			for id in ids:
				var a := g.find_instance(int(id))
				if a.cur_max_blockers > 0 and int(count.get(id, 0)) >= a.cur_max_blockers:
					fits = false
					break
			if not fits: continue
		for id in ids: count[id] = int(count.get(id, 0)) + 1
		choice[i] = ids
		var stop := _search_from(s, i + 1, score + int(opt[0]), blocking + (0 if ids.is_empty() else 1))
		for id in ids: count[id] = int(count[id]) - 1
		if stop: return true
	choice[i] = []
	return false


## A complete choice for the creatures under a requirement: give every
## menace attacker its partners (CR 509.1b — a matching over the creatures
## not yet blocking, so one partner never serves two attackers), fill any
## "blocks only with others" group, and keep the declaration if it is
## legal as a whole and obeys more than "threshold".
static func _leaf(s: Dictionary) -> bool:
	var g: MtgGame = s["g"]
	var req: Array = s["req"]
	var choice: Array = s["choice"]
	var count: Dictionary = s["count"]
	var reach: Dictionary = s["reach"]
	var out := {}
	var idle: Array = []
	for i in req.size():
		var ids: Array = choice[i]
		if ids.is_empty(): idle.append(req[i]["inst"])
		else: out[(req[i]["inst"] as CardInstance).id] = ids.duplicate()
	idle.append_array(s["spare"])
	var slots: Array = []
	for id in count:
		var on := int(count[id])
		if on <= 0: continue
		var a := g.find_instance(int(id))
		for _n in maxi(a.cur_min_blockers - on, 0): slots.append(a)
	if not slots.is_empty():
		var owner: Array = []
		owner.resize(slots.size())
		owner.fill(-1)
		var taken := {}
		for si in slots.size():
			if not _augment(si, slots, idle, reach, owner, taken, {}): return false
		var used: Array = []
		for si in slots.size():
			var partner: CardInstance = idle[int(owner[si])]
			out[partner.id] = [(slots[si] as CardInstance).id]
			used.append(partner)
		for p in used: idle.erase(p)
	if not _fill_groups(g, out, idle, reach): return false
	if not _legal_whole(g, out): return false
	var score := requirements_obeyed(g, out)
	if score <= int(s["threshold"]): return false
	s["best"] = out
	s["threshold"] = score
	return bool(s["first_only"]) or score >= int(s["upper"])


## Kuhn's augmenting path: find slot [param si] a partner among [param idle]
## that may block its attacker for free, moving earlier partners if needed.
static func _augment(si: int, slots: Array, idle: Array, reach: Dictionary, owner: Array,
		taken: Dictionary, seen: Dictionary) -> bool:
	for pi in idle.size():
		if seen.has(pi): continue
		if not (reach[(idle[pi] as CardInstance).id] as Array).has(slots[si]): continue
		seen[pi] = true
		if not taken.has(pi) or _augment(int(taken[pi]), slots, idle, reach, owner, taken, seen):
			taken[pi] = si
			owner[si] = pi
			return true
	return false


## A blocker that blocks only beside others (`cur_min_block_group`) needs
## that many blocking creatures: add free blocks that break no minimum.
static func _fill_groups(g: MtgGame, out: Dictionary, idle: Array, reach: Dictionary) -> bool:
	var need := 1
	for id in out: need = maxi(need, g.find_instance(int(id)).cur_min_block_group)
	while out.size() < need:
		var added: CardInstance = null
		for c in idle:
			for a in reach[(c as CardInstance).id]:
				var on := 0
				for id in out:
					if (out[id] as Array).has((a as CardInstance).id): on += 1
				if a.cur_min_blockers > 1 and on == 0: continue
				if a.cur_max_blockers > 0 and on >= a.cur_max_blockers: continue
				out[(c as CardInstance).id] = [(a as CardInstance).id]
				added = c
				break
			if added != null: break
		if added == null: return false
		idle.erase(added)
		need = maxi(need, added.cur_min_block_group)
	return true


## The restrictions on a declaration as a whole, as MtgGame.declare_blockers
## checks them: the blocker cap, each attacker's maximum and minimum, each
## blocker's group.
static func _legal_whole(g: MtgGame, out: Dictionary) -> bool:
	if g.max_blockers > 0 and out.size() > g.max_blockers: return false
	if block_error(g, out) != "": return false
	var counts := {}
	for id in out:
		for t in out[id]: counts[t] = int(counts.get(t, 0)) + 1
	for t in counts:
		if int(counts[t]) < g.find_instance(int(t)).cur_min_blockers: return false
	return true


## THE AI'S HALF: [param out] (a normalised map, the AI's trimmed plan)
## made to obey as many block requirements as any legal declaration could
## — the declaration [method must_block_error] accepts. The plan stands
## when it already does; otherwise the search's answer (the plan's own
## choices first, then the cheapest for the chooser: for the defender a
## block the creature survives and then one that kills, reversed when the
## ATTACKING player chooses — Invasion Plans, Melee, [method
## MtgGame.block_chooser]), with the plan's other blocks put back wherever
## they still fit. Public board only (rule 8): power, toughness, damage.
static func _add_forced_blocks(g: MtgGame, pid: int, out: Dictionary) -> Dictionary:
	if g.camouflage_this_turn or not _has_block_requirements(g, pid): return out
	var obeyed := requirements_obeyed(g, out)
	var s := _search_state(g, pid, out, false, true)
	if obeyed >= int(s["upper"]): return out
	s["threshold"] = obeyed
	_search_from(s, 0, 0, 0)
	var best: Dictionary = s["best"]
	if best.is_empty(): return out
	var merged := best.duplicate(true)
	# The plan's other blocks, a gang on one attacker together, then alone.
	var groups := {}
	for id in out:
		if merged.has(int(id)): continue
		var key := str(out[id])
		if not groups.has(key): groups[key] = []
		(groups[key] as Array).append(int(id))
	for key in groups:
		var trial := merged.duplicate(true)
		for id in groups[key]: trial[id] = (out[id] as Array).duplicate()
		if _legal_whole(g, trial):
			merged = trial
			continue
		for id in groups[key]:
			var one := merged.duplicate(true)
			one[id] = (out[id] as Array).duplicate()
			if _legal_whole(g, one): merged = one
	if must_block_error(g, pid, merged) != "": return best
	return merged


## How good forcing [param blocker] onto [param a] is for the chooser: for
## the defender, surviving first and killing second; for an attacking
## chooser the reverse. A gang block costs a partner, so it comes last.
static func _forced_score(blocker: CardInstance, a: CardInstance, attacker_side: bool) -> int:
	var dies := a.cur_power >= blocker.cur_toughness - blocker.damage
	var kills := blocker.cur_power >= a.cur_toughness - a.damage
	var score := (0 if dies else 2) + (1 if kills else 0)
	if attacker_side: score = -score
	if a.cur_min_blockers > 1: score -= 10
	return score
