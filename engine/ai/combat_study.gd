class_name AiCombatStudy
extends RefCounted
## [QoL] A bounded combat study over a public, precomputed CombatSearch model.
## Whole assignments compete: damage, casualties, gang blocks, first strike,
## trample and the survivors' counterattack. No hidden zones or game RNG.

var model: CombatSearch
var budget := 1500
var nodes := 0
var ours_attacks := true
var counterattack := true
var chump_threshold := 6
var damage_only := false
## At most one affordable, known pump from our own hand, on one body.
## Each alternative is a flat model; no game or hidden-card references.
var responses: Array[Dictionary] = []
var _limit := 0
var _best: Dictionary = {}
var _outcomes: Dictionary = {}
var _orders: Dictionary = {}


func _init(p_model: CombatSearch) -> void:
	model = p_model


func best_attack() -> int:
	nodes = 0
	ours_attacks = true
	var eligible := 0
	var forced := 0
	for i in model.size_ours():
		if model.a_can_attack[i] != 0 and model.a_pow[i] > 0: eligible |= 1 << i
		if model.a_forced[i] != 0: forced |= 1 << i
	var moves := model._subsets_of(eligible, forced)
	var best_mask := forced
	var best_value := -INF
	var slice := maxi(1, budget / maxi(moves.size(), 1))
	for mask in moves:
		if nodes >= budget: break
		var result := blocks(mask, mini(slice, budget - nodes))
		if float(result["value"]) > best_value + 0.000001:
			best_value = float(result["value"])
			best_mask = mask
	return best_mask


## Block maps use model indices: defender -> attacker. Their best answer
## minimises the attacking side's gain, rather than ranking each body alone.
func blocks(attack_mask: int, allowance := -1) -> Dictionary:
	_limit = mini(budget, nodes + (budget if allowance < 0 else allowance))
	var fallback := _exchange_result(attack_mask, {})
	_best = {"value": INF}
	var attackers: Array[int] = []
	var n := model.size_ours() if ours_attacks else model.size_theirs()
	for i in n:
		if attack_mask & (1 << i): attackers.append(i)
	_assign(attackers, 0, 0, {}, attack_mask)
	return (fallback if is_inf(float(_best["value"])) else _best).duplicate(true)


func _assign(attackers: Array[int], index: int, used: int,
		assignments: Dictionary, mask: int) -> void:
	if nodes >= _limit: return
	if index >= attackers.size():
		var result := _evaluate(mask, assignments, true)
		if is_inf(float(_best["value"])) or _prefers(result, _best, false) \
				or (is_equal_approx(float(result["value"]), float(_best["value"]))
					and int(result["damage"]) == int(_best.get("damage", -1))
					and assignments.size() < _best.get("blocks", {}).size()):
			_best = result
		return
	var attacker := attackers[index]
	var legal: Array[int] = []
	var count := model.size_theirs() if ours_attacks else model.size_ours()
	for defender in count:
		if used & (1 << defender): continue
		var free := model.d_free[defender] if ours_attacks else model.a_free[defender]
		var cell := attacker * model.size_theirs() + defender if ours_attacks \
			else defender * model.size_theirs() + attacker
		var valid := model.block_ours[cell] if ours_attacks else model.block_theirs[cell]
		if free != 0 and valid != 0: legal.append(defender)
	var choices := _ordered_gangs(attacker, legal)
	# Visit promising exchanges first, but score complete assignments. Every
	# blocker has one shared bit: it cannot answer two attackers at once.
	for gang in choices:
		if nodes >= _limit: break
		var taken := used
		for defender in gang:
			taken |= 1 << int(defender)
			assignments[int(defender)] = attacker
		_assign(attackers, index + 1, taken, assignments, mask)
		for defender in gang: assignments.erase(int(defender))


func _ordered_gangs(attacker: int, legal: Array[int]) -> Array:
	var key := _exchange_key(attacker, legal)
	if _orders.has(key): return _orders[key]
	var choices: Array = [[]]
	choices.append_array(model._gangs_of(legal, model.gang_bounds(attacker, ours_attacks)))
	var ranked: Array = []
	for gang in choices: ranked.append({"gang": gang, "value": _exchange(attacker, gang)})
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return float(a["value"]) < float(b["value"]))
	choices = ranked.map(func(entry: Dictionary) -> Array: return entry["gang"])
	_orders[key] = choices
	return choices


func _exchange_key(attacker: int, gang: Array) -> String:
	var mask := 0
	for defender in gang: mask |= 1 << int(defender)
	return "%d:%d:%d:%d" % [model.get_instance_id(), int(ours_attacks), attacker, mask]


func _outcome(attacker: int, gang: Array) -> Array:
	var key := _exchange_key(attacker, gang)
	if not _outcomes.has(key): _outcomes[key] = model.resolve_block(attacker, gang, ours_attacks)
	return _outcomes[key]


func _exchange(attacker: int, gang: Array) -> float:
	var outcome := _outcome(attacker, gang)
	var value := -_attacker_value(attacker) if bool(outcome[0]) else 0.0
	for defender in gang:
		if int(outcome[1]) & (1 << int(defender)):
			value += _defender_value(int(defender))
	return value + CombatSearch._fdv(int(outcome[2]), _defender_life())


func _evaluate(mask: int, assignments: Dictionary, count_node: bool) -> Dictionary:
	if count_node: nodes += 1
	var result := _exchange_result(mask, assignments)
	var base := model
	for response in responses:
		if nodes >= _limit: break
		var target := int(response["target"])
		if ours_attacks and not (mask & (1 << target)): continue
		if not ours_attacks and not assignments.has(target): continue
		nodes += 1
		model = response["model"]
		var alternative := _exchange_result(mask, assignments)
		# A card is spent only when it changes the exchange enough to pay
		# for it. Winning now outranks that opportunity cost.
		if absf(float(alternative["value"])) < CombatSearch.LOSS:
			alternative["value"] += -float(response["cost"]) if ours_attacks \
				else float(response["cost"])
		if _prefers(alternative, result, ours_attacks):
			result = alternative
			result["trick_target"] = target
	model = base
	# Pump spells expire before the reply. Only casualties carry forward;
	# the counterattack reads the unmodified public model.
	if ours_attacks and counterattack and count_node and nodes < _limit \
			and int(result["damage"]) < _defender_life():
		var ours := 0
		var theirs := 0
		for i in model.size_ours():
			if not (int(result["attacker_dead"]) & (1 << i)) and model.a_free[i] != 0 \
					and (not (mask & (1 << i)) or model.a_vigilant[i] != 0):
				ours |= 1 << i
		for i in model.size_theirs():
			if not (int(result["defender_dead"]) & (1 << i)) and model.d_can_attack[i] != 0:
				theirs |= 1 << i
		result["value"] += _counterattack_value(theirs, ours, mini(24, _limit - nodes))
	return result


func _prefers(a: Dictionary, b: Dictionary, maximize: bool) -> bool:
	if damage_only and int(a["damage"]) != int(b["damage"]):
		return int(a["damage"]) > int(b["damage"]) if maximize \
			else int(a["damage"]) < int(b["damage"])
	return float(a["value"]) > float(b["value"]) + 0.000001 if maximize \
		else float(a["value"]) < float(b["value"]) - 0.000001


func _exchange_result(mask: int, assignments: Dictionary) -> Dictionary:
	var value := 0.0
	var damage := 0
	var attacker_dead := 0
	var defender_dead := 0
	var chump_damage := 0
	var chump_value := 0.0
	var count := model.size_ours() if ours_attacks else model.size_theirs()
	for attacker in count:
		if not (mask & (1 << attacker)): continue
		var gang: Array[int] = []
		for defender in assignments:
			if int(assignments[defender]) == attacker: gang.append(int(defender))
		var outcome := _outcome(attacker, gang)
		if bool(outcome[0]):
			attacker_dead |= 1 << attacker
			value -= _attacker_value(attacker)
		defender_dead |= int(outcome[1])
		damage += int(outcome[2])
		# Throwaway blocks are a last resort, not a way to cash every
		# small body in for life while comfortably ahead of lethal.
		if not bool(outcome[0]) and not gang.is_empty() \
				and gang.all(func(d: int) -> bool: return int(outcome[1]) & (1 << d)):
			chump_damage += maxi(int(_outcome(attacker, [])[2])
				- int(outcome[2]), 0)
			for d in gang: chump_value += _defender_value(d)
	for defender in (model.size_theirs() if ours_attacks else model.size_ours()):
		if defender_dead & (1 << defender): value += _defender_value(defender)
	value += CombatSearch._fdv(damage, _defender_life())
	if _defender_life() - damage - chump_damage > chump_threshold:
		value += chump_value * 2.0
		# ...AND THE LIFE IT SAVED IS NO SAVING up here (bug hunt
		# 2026-10-21): the surcharge alone left a small body cheaper than
		# a big hit — a Soul Warden (3 x 2.0) against a Craw Wurm's 6 at
		# 20 life (7.8) — and the Sorcerer and the Wizard chump-blocked
		# with it, "a way to cash every small body in for life" exactly.
		# Above the panic line the face damage a throwaway block stops is
		# counted as taken, so the block is never the better line.
		value += CombatSearch._fdv(damage + chump_damage, _defender_life()) \
			- CombatSearch._fdv(damage, _defender_life())
	if damage >= _defender_life():
		value = CombatSearch.LOSS
	return {"value": value, "damage": damage, "blocks": assignments.duplicate(),
		"attacker_dead": attacker_dead, "defender_dead": defender_dead}


func _counterattack_value(theirs: int, ours: int, allowance: int) -> float:
	var attackers: Array[int] = []
	for i in model.size_theirs():
		if theirs & (1 << i): attackers.append(i)
	if attackers.is_empty() or allowance <= 0: return 0.0
	var old_free := model.a_free.duplicate()
	for i in model.size_ours(): model.a_free[i] = 1 if ours & (1 << i) else 0
	var reply := AiCombatStudy.new(model)
	# The model's damage characteristics are fixed for this study. Share
	# public exchange/order memo tables across reply searches, not across
	# real game decisions. Legality keys include the available blocker mask.
	reply._outcomes = _outcomes
	reply._orders = _orders
	reply.ours_attacks = false
	reply.counterattack = false
	reply.chump_threshold = chump_threshold
	reply.budget = allowance
	var moves := model._their_subsets(attackers)
	var slice := maxi(1, allowance / maxi(moves.size(), 1))
	var worst := 0.0
	for move in moves:
		if reply.nodes >= allowance: break
		var mask := 0
		for i in move: mask |= 1 << int(i)
		var answer := reply.blocks(mask, slice)
		worst = maxf(worst, float(answer["value"]))
	model.a_free = old_free
	nodes += reply.nodes
	return -worst


func _attacker_value(index: int) -> float:
	return model.a_val[index] if ours_attacks else model.d_val[index]


func _defender_value(index: int) -> float:
	return model.d_val[index] if ours_attacks else model.a_val[index]


func _defender_life() -> int:
	return model.their_life if ours_attacks else model.my_life
