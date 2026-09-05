class_name CombatSearch
extends RefCounted
## THE CRACK-BACK SEARCH (M4 phase 3's first landing, 2026-09-05) — an
## alpha-beta minimax over the two combats that decide whether an attack
## kills us, run at declare-attackers.
##
## WHY IT EXISTS. An attacker is tapped through the opponent's whole turn,
## so at low life a swing can hand them a lethal counter-swing. Two
## approximations of that were built and both were REJECTED on measurement
## (docs/ROADMAP.md): a heuristic brake (50.9% against a 50.5% null,
## Mountain Artillery 2.3 points worse) and a one-ply lookahead running
## `_damage_through_blocks` with the roles swapped (+0.3 over 5,000 games,
## Big Green 1.1 points worse). Both fail the same way: they are
## PESSIMISTIC. They assume the opponent attacks with everything and that
## we block it greedily, and they price the danger with a threshold rather
## than against what the attack was worth — so they hold bodies home in
## positions that were survivable, which is exactly what costs a deck that
## wants to attack. The standing conclusion was that the gap is not the
## approximation's fault and the answer is search.
##
## WHAT IS SEARCHED, AND WHAT IS NOT. Four decision layers, of which three
## are enumerated and backed up:
##
##   1. OUR attack (MAX)   — enumerated: every subset of the cohort
##      [AiPlayer._choose_attack_cohort] already chose, so the search can
##      only ever hold bodies BACK, never send one the cohort rejected.
##   2. THEIR blocks (min) — NOT searched: the shipped one-blocker-per-
##      attacker greedy model, the same one `_cohort_value` and
##      `_damage_through_blocks` use. Deliberate. The search's job is the
##      crack-back; if it re-litigated the forward combat with a second
##      model the two halves would disagree about the same board and the
##      measurement would be of two changes, not one.
##   3. THEIR crack-back attack (max, theirs) — enumerated over their
##      SURVIVORS, all of which untap before their combat, tapped ones
##      included. That is the whole premise of the problem.
##   4. OUR blocks (min, theirs) — enumerated over the bodies this attack
##      would leave us: our untapped creatures that did NOT attack, plus
##      the vigilant ones that did. Searched rather than assumed, and this
##      is the half both rejected approximations got wrong.
##
## The leaf is the position DELTA in [AiPlayer]'s own currency — the
## clock-scaled face damage of `_face_damage_value` plus
## `Evaluator.permanent_value` for every body that dies on either side —
## so a value the search backs up is comparable with the one
## `_cohort_value` produced, and holding a creature home is PRICED against
## what its attack was worth rather than tested against a threshold. Our
## own death is -[constant LOSS] and theirs is +[constant LOSS], which is
## what makes "survive" dominate everything else without a special case.
##
## NO ENGINE MUTATION, NO RNG, NO HIDDEN INFORMATION. The whole tree runs
## over a MODEL built once per decision out of the engine's own
## predicates: `CombatState.block_illegality` for every legality, and
## [AiPlayer]'s own `_dies_to` for every kill, precomputed into matrices
## (see [method AiPlayer._build_combat_model]). Nothing in here reads the
## opponent's hand or library, nothing rolls, and nothing is written back
## — so a seeded duel replays identically and `results.json` cannot move
## with `--jobs`.
##
## WHY A MODEL RATHER THAN `MtgGame.make_mark()`. The undo journal
## (`engine/undo_log.gd`) makes a search node cheap — 21x a `GameSnapshot`
## — but its documented boundary is the TURN MACHINERY: `_advance_step`,
## the untap sweep and combat damage journal nothing, "so a search must
## not cross a step boundary until they do". This search crosses two step
## boundaries and a turn boundary by construction, so the journal cannot
## carry it today. What it CAN carry is a search inside one step, which is
## the next increment and is recorded as such in docs/ROADMAP.md.
##
## SIMPLIFIED (docs/ROADMAP.md, "The crack-back search"): one blocker per
## attacker on both sides of both combats, and neither player's hand is
## modelled — the same two simplifications the rest of the combat maths
## carries, measured at 4.5% of combats for gang blocks and deliberate for
## the hand (the AI does not look at cards it may not see).

## The value of losing the game, in stat points. Large enough to dominate
## any board, small enough that arithmetic on it stays exact in a float.
const LOSS := 1.0e6

## Full powerset up to this many bodies; above it the move list is the
## strongest-first CHAIN (attack with the top k, k = 0..n), which is the
## axis the crack-back question actually lives on.
const FULL_SUBSET_LIMIT := 5

## Hard stop on leaf evaluations for ONE decision. The tree is enumerated
## in a fixed order, so hitting the budget is deterministic: the same board
## always explores the same nodes and returns the same move.
const DEFAULT_BUDGET := 3000

## No candidate attack is ever given less than this, however many there
## are: a slice too thin to see the crack-back at all would compare two
## moves on noise.
const MIN_SLICE := 96


# ------------------------------------------------------------- the model --
#
# Everything the tree needs, flat and precomputed. `a_` is us, `d_` is
# them; the matrices are row-major over (ours x theirs).

var a_pow: PackedInt32Array = PackedInt32Array()
var a_val: PackedFloat32Array = PackedFloat32Array()
var a_id: PackedInt32Array = PackedInt32Array()
## Our creature may be declared an attacker this turn (the cohort said so).
var a_can_attack: PackedByteArray = PackedByteArray()
## Our creature is FORCED to attack (CR 508.1d) — in every move list.
var a_forced: PackedByteArray = PackedByteArray()
## Our creature is untapped now, so it can block during their turn unless
## this attack taps it.
var a_free: PackedByteArray = PackedByteArray()
## Our creature has vigilance: attacking does not cost us its block.
var a_vigilant: PackedByteArray = PackedByteArray()
## Our creature has trample: what a blocker cannot soak goes to the face.
var a_trample: PackedByteArray = PackedByteArray()
## Toughness left on our creature, for the trample arithmetic.
var a_soak: PackedInt32Array = PackedInt32Array()

var d_pow: PackedInt32Array = PackedInt32Array()
var d_val: PackedFloat32Array = PackedFloat32Array()
## Their creature is untapped NOW, so it can block our attack this turn.
var d_free: PackedByteArray = PackedByteArray()
## Their creature could attack US next turn: they untap first, so this is
## the durable half of `CombatState.attack_illegality` only.
var d_can_attack: PackedByteArray = PackedByteArray()
var d_trample: PackedByteArray = PackedByteArray()
var d_soak: PackedInt32Array = PackedInt32Array()

## d blocks a legally, this turn (row a, column d).
var block_ours: PackedByteArray = PackedByteArray()
## a blocks d legally, next turn (row a, column d).
var block_theirs: PackedByteArray = PackedByteArray()
## our a kills their d in combat (row a, column d).
var we_kill: PackedByteArray = PackedByteArray()
## their d kills our a in combat (row a, column d).
var they_kill: PackedByteArray = PackedByteArray()

var my_life := 20
var their_life := 20

## Leaf evaluations spent on the CURRENT candidate attack, the ceiling for
## the whole decision, and what the last decision actually cost (for the
## cost measurement — nothing reads it in play).
var nodes := 0
var budget := DEFAULT_BUDGET
var total_nodes := 0

var _n := 0   # our creatures
var _m := 0   # theirs


func size_ours() -> int:
	return _n


func size_theirs() -> int:
	return _m


## Called by [method AiPlayer._build_combat_model] once the arrays are
## filled: caches the two counts the tree indexes with.
func seal() -> void:
	_n = a_pow.size()
	_m = d_pow.size()


# ------------------------------------------------------------- the entry --

## WHICH of our creatures should attack, as a bitmask over our model
## indices. [param cohort_mask] is what
## [method AiPlayer._choose_attack_cohort] chose; the search returns that
## mask or a SUBSET of it.
##
## The move list is the cohort's subsets, ordered so the widest attack is
## tried first — it is what the shipped policy would do, so alpha-beta
## gets its best bound immediately and a tie goes to attacking.
func best_attack(cohort_mask: int) -> int:
	nodes = 0
	total_nodes = 0
	var forced_mask := 0
	for i in _n:
		if a_forced[i] != 0:
			forced_mask |= 1 << i
	var moves := _subsets_of(cohort_mask, forced_mask)
	# THE BUDGET IS SHARED OUT, not spent first-come. A global counter
	# would give the widest attack the whole tree and leave the narrow ones
	# truncated, which is a bias in favour of attacking dressed up as a
	# result. Each candidate attack gets the same slice, so the comparison
	# between them is like for like — and the slice is a fixed function of
	# the move count, so it is as deterministic as the rest.
	var slice := maxi(MIN_SLICE, budget / maxi(moves.size(), 1))
	var best := cohort_mask
	var best_score := -INF
	for mask in moves:
		nodes = 0
		var score := _after_our_attack(mask, slice)
		total_nodes += nodes
		if score > best_score + 1e-9:
			best_score = score
			best = mask
	return best


## Every candidate attack, widest first. [param keep] is always included
## (the must-attackers). The full powerset while the optional bodies are
## few — that is a real enumeration, and the counts measured over gauntlet
## duels (mean 2 attackers, max 16) say it usually is the whole list — and
## the strongest-first chain above that, so the branching cannot blow up
## on a wide board.
func _subsets_of(mask: int, keep: int) -> Array[int]:
	var optional: Array[int] = []
	for i in _n:
		var bit := 1 << i
		if (mask & bit) != 0 and (keep & bit) == 0:
			optional.append(i)
	# Best DEFENDER last: the body whose block is worth most is the one the
	# chain should hold back first, and inside the powerset this ordering
	# only decides ties.
	optional.sort_custom(_defender_first)
	var out: Array[int] = []
	if optional.size() <= FULL_SUBSET_LIMIT:
		var count := 1 << optional.size()
		# Descending, so the FULL attack is move zero.
		for combo in range(count - 1, -1, -1):
			var m := keep
			for j in optional.size():
				if (combo & (1 << j)) != 0:
					m |= 1 << optional[j]
			out.append(m)
		return out
	var running := keep
	for i in optional.size():
		running |= 1 << optional[i]
	out.append(running)
	# ...and the chain drops them in that same order, BEST DEFENDER FIRST:
	# when a body has to stay home it is the one whose block is worth most,
	# which is the axis the crack-back question lives on.
	for i in optional.size():
		running &= ~(1 << optional[i])
		out.append(running)
	return out


## Sort helper: the creature whose defensive worth is HIGHEST comes first,
## so the chain drops it from the attack first. Ties break on model index,
## which is battlefield order — stable, and no RNG (CONTRIBUTING.md rule 7).
func _defender_first(x: int, y: int) -> bool:
	var vx := a_val[x] + float(a_pow[x])
	var vy := a_val[y] + float(a_pow[y])
	if absf(vx - vy) > 1e-6:
		return vx > vy
	return x < y


# --------------------------------------------------- ply 1 -> plies 2..4 --

## Play out OUR combat for [param attack_mask] under the shipped greedy
## defence, then hand the surviving board to the crack-back search and add
## the two halves up.
func _after_our_attack(attack_mask: int, slice: int) -> float:
	# --- ply 2: their blocks, the shipped one-blocker-per-attacker model.
	var pairs: Array = []
	for d in _m:
		if d_free[d] == 0:
			continue
		for a in _n:
			if (attack_mask & (1 << a)) == 0:
				continue
			if block_ours[a * _m + d] == 0:
				continue
			var soaked := a_pow[a]
			if a_trample[a] != 0:
				soaked = mini(soaked, maxi(d_soak[d], 0))
			var gain := _fdv(soaked, their_life)
			if they_kill[a * _m + d] != 0:
				gain += a_val[a]
			if we_kill[a * _m + d] != 0:
				gain -= d_val[d]
			if gain <= 0.0:
				continue   # they would rather take the hit
			pairs.append([gain, a, d])
	pairs.sort_custom(func(x: Array, y: Array) -> bool:
		if absf(float(x[0]) - float(y[0])) > 1e-6:
			return float(x[0]) > float(y[0])
		return int(x[1]) * 64 + int(x[2]) < int(y[1]) * 64 + int(y[2]))
	var blocked_by: Dictionary = {}   # our index -> their index
	var spent: Dictionary = {}
	for pair in pairs:
		var a: int = pair[1]
		var d: int = pair[2]
		if spent.has(d) or blocked_by.has(a):
			continue
		spent[d] = true
		blocked_by[a] = d
	# --- resolve our combat on the model.
	var value := 0.0
	var through := 0
	var my_dead := 0        # bitmask over our indices
	var their_dead := 0
	for a in _n:
		if (attack_mask & (1 << a)) == 0:
			continue
		if not blocked_by.has(a):
			through += a_pow[a]
			continue
		var d: int = blocked_by[a]
		if a_trample[a] != 0:
			through += maxi(a_pow[a] - maxi(d_soak[d], 0), 0)
		if they_kill[a * _m + d] != 0:
			value -= a_val[a]
			my_dead |= 1 << a
		if we_kill[a * _m + d] != 0:
			value += d_val[d]
			their_dead |= 1 << d
	value += _fdv(through, their_life)
	if through >= their_life:
		return LOSS     # they are dead before the crack-back happens
	# --- plies 3 and 4: the crack-back, over what is left.
	# Our blockers next turn: alive, untapped now, and either left home or
	# vigilant. Their attackers next turn: alive — they UNTAP first, which
	# is the whole point.
	var my_free := 0
	for a in _n:
		if (my_dead & (1 << a)) != 0 or a_free[a] == 0:
			continue
		if (attack_mask & (1 << a)) != 0 and a_vigilant[a] == 0:
			continue
		my_free |= 1 << a
	var their_live := 0
	for d in _m:
		if (their_dead & (1 << d)) == 0 and d_can_attack[d] != 0:
			their_live |= 1 << d
	return value + _crack_back(their_live, my_free, slice)


# ------------------------------------------- plies 3 and 4: the crack-back --

## Their best counter-swing against the blockers this attack would leave
## us, as a value from OUR side of the table (so it is normally negative).
## [param their_mask] is the board they will untap; [param my_mask] the
## bodies we can still block with.
func _crack_back(their_mask: int, my_mask: int, slice: int) -> float:
	var attackers: Array[int] = []
	for d in _m:
		if (their_mask & (1 << d)) != 0:
			attackers.append(d)
	if attackers.is_empty():
		return 0.0
	# Their move list: strongest first, so the alpha-beta bound comes from
	# the swing they are most likely to make.
	attackers.sort_custom(func(x: int, y: int) -> bool:
		if d_pow[x] != d_pow[y]:
			return d_pow[x] > d_pow[y]
		return x < y)
	var moves := _their_subsets(attackers)
	# DECLINING IS ALWAYS ON THEIR LIST and it is worth exactly nothing, so
	# it is the starting bound rather than a move: a swing that costs them
	# more than it gains is one they simply do not make, and both rejected
	# approximations went wrong by assuming they always attack anyway.
	var worst := 0.0
	for swing in moves:
		if nodes >= slice:
			break
		# Alpha-beta: `worst` is the value they have already secured, so a
		# swing our blocks can push above it can be cut the moment they do.
		var score := _our_best_defence(swing, my_mask, worst, slice)
		if score < worst:
			worst = score
	return worst


## Their candidate swings: the powerset while they are few, the
## strongest-first chain when they are many.
func _their_subsets(attackers: Array[int]) -> Array[Array]:
	var out: Array[Array] = []
	if attackers.size() <= FULL_SUBSET_LIMIT:
		var count := 1 << attackers.size()
		for combo in range(count - 1, 0, -1):
			var swing: Array[int] = []
			for j in attackers.size():
				if (combo & (1 << j)) != 0:
					swing.append(attackers[j])
			out.append(swing)
		return out
	for k in range(attackers.size(), 0, -1):
		out.append(attackers.slice(0, k))
	return out


## OUR best block of [param swing], as a value from our side (higher is
## better for us). [param cutoff] is the alpha-beta bound: their caller
## already has a swing worth [param cutoff] to them, so the moment our
## defence pushes this one above it the branch cannot be their choice.
func _our_best_defence(swing: Array, my_mask: int, cutoff: float,
		slice: int) -> float:
	var free: Array[int] = []
	for a in _n:
		if (my_mask & (1 << a)) != 0:
			free.append(a)
	# Our best blocker first: a body that kills what it blocks and lives
	# is the move that most often produces the cut.
	free.sort_custom(func(x: int, y: int) -> bool:
		if absf(a_val[x] - a_val[y]) > 1e-6:
			return a_val[x] > a_val[y]
		return x < y)
	return _assign(swing, 0, free, 0, 0.0, 0, cutoff, slice)


## Recursive block assignment: attacker [param index] of [param swing] is
## blocked by one of the free bodies not in [param used], or by nobody.
## Returns the best value WE can get from here; [param acc] is the value
## already committed and [param damage] the face damage already let
## through. Cut as soon as the running best beats [param cutoff], which is
## a value THEY would never choose.
func _assign(swing: Array, index: int, free: Array, used: int,
		acc: float, damage: int, cutoff: float, slice: int) -> float:
	if index >= swing.size():
		nodes += 1
		if damage >= my_life:
			return -LOSS
		return acc - _fdv(damage, my_life)
	if nodes >= slice:
		# Budget spent: finish this line with everything unblocked rather
		# than half a plan. Deterministic, and the pessimistic direction.
		var rest := damage
		for i in range(index, swing.size()):
			rest += d_pow[swing[i]]
		nodes += 1
		if rest >= my_life:
			return -LOSS
		return acc - _fdv(rest, my_life)
	var d: int = swing[index]
	var best := -INF
	# Option 1: let it through.
	best = _assign(swing, index + 1, free, used, acc, damage + d_pow[d],
		cutoff, slice)
	if best > cutoff:
		return best
	# Option 2: each free body that may legally block it.
	for entry in free:
		var a: int = entry
		var bit := 1 << a
		if (used & bit) != 0:
			continue
		if block_theirs[a * _m + d] == 0:
			continue
		var value := acc
		var spill := 0
		if d_trample[d] != 0:
			spill = maxi(d_pow[d] - maxi(a_soak[a], 0), 0)
		if they_kill[a * _m + d] != 0:
			value -= a_val[a]
		if we_kill[a * _m + d] != 0:
			value += d_val[d]
		var score := _assign(swing, index + 1, free, used | bit, value,
			damage + spill, cutoff, slice)
		if score > best:
			best = score
		if best > cutoff:
			return best
	return best


# ------------------------------------------------------------------ leaf --

## [method AiPlayer._face_damage_value] over the model: one point of life
## per point of damage, scaled up by the share of the REMAINING total the
## hit takes, so two damage is worth 2.2 against 20 life and 4.0 against 4.
static func _fdv(dmg: int, life: int) -> float:
	if dmg <= 0:
		return 0.0
	return float(dmg) * Evaluator.W_LIFE \
		* (1.0 + float(dmg) / float(maxi(life, 1)))
