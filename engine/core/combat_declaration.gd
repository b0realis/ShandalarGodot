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
	return ""

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
		if i.cur_attack_land_sacrifices > 0: continue # voluntary resource cost
		if i.cur_attacks_alone:
			if i.cur_min_attack_group <= 1: candidates.append([i.id])
		else: ordinary.append(i.id)
	ordinary.sort_custom(func(a: int, b: int) -> bool:
		var left := g.find_instance(a)
		var right := g.find_instance(b)
		var lv := (10000 if mandatory(left) else 0) + (1000 if proposed.has(a) else 0) + left.cur_power
		var rv := (10000 if mandatory(right) else 0) + (1000 if proposed.has(b) else 0) + right.cur_power
		return lv > rv)
	var base: Array = []
	for id in ordinary:
		if g.max_attackers > 0 and base.size() >= g.max_attackers: break
		var i := g.find_instance(id)
		if proposed.has(id) or mandatory(i): base.append(id)
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
	return out
