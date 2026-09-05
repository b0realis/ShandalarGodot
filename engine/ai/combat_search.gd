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
##      is the half both rejected approximations got wrong. Since
##      2026-09-05 a body may join a GANG on one attacker rather than
##      taking it alone ([method resolve_block]), which is the half of the
##      one-blocker-per-attacker ledger row that measured its way out.
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
## WHY A MODEL RATHER THAN `MtgGame.make_mark()`, and the answer is no
## longer the one this file was written with. The journal's boundary WAS
## the turn machinery; since 2026-09-05 it covers that too
## (`MtgGame._rec_turn`), and a search node may cross a step boundary. It
## still cannot carry THIS search, and the reason is a cost rather than a
## gap: the journal is proportional to the MOVE, and this search's move is
## a whole turn — our combat, their untap, their combat. Measured
## (`tools/bench_undo.gd` section I): ONE boundary is 11-19x cheaper than
## a `GameSnapshot`, a whole TURN is 0.8-1.1x, i.e. no cheaper at all,
## because untap writes seven fields on every permanent and cleanup
## twenty-six. At ~4 ms a node a 3,000-node budget would be twelve seconds
## per declaration. So the model stays, and what the journal opened is a
## search whose node is one step or a few (docs/ROADMAP.md, "The journal
## across a step boundary").
##
## SIMPLIFIED (docs/ROADMAP.md, "the AI's combat maths blocks ONE creature
## per attacker"), NARROWED 2026-09-05: the model now lets US put several
## bodies on one of their attackers when it answers the crack-back (ply 4,
## [method resolve_block] and `gang_defence`). What is still flat is the
## FORWARD combat — ply 2 here, and `AiPlayer._cohort_value` /
## `_damage_through_blocks` before it — where the defender still answers
## one blocker per attacker. That half was built and rejected on
## measurement rather than left undone; the numbers are in the ledger row
## and in docs/ROADMAP.md, "The gang block".
##
## SIMPLIFIED (docs/ROADMAP.md, "The crack-back search"): neither player's
## hand is modelled. Deliberate, and it is a fairness rule rather than a
## shortcut — the AI does not look at cards it may not see. What the
## search DOES read is the model in [method AiPlayer._build_combat_model]
## and nothing else: both battlefields, both life totals, which permanents
## are tapped, and the engine's own predicates over those. Pinned from
## both ends by `tests/ai/test_ai_crack_back_2026_09_05.gd` — replace every
## card in the opponent's hand, or reverse their whole library, and the
## declaration does not move by a body; and every field of this class is a
## flat array of numbers sized one per creature or one per pair, so there
## is nowhere in it to put a card nobody has seen.

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

## GANG BLOCKS (2026-09-05). How many bodies may be put on one attacker.
## [method AiPlayer.order_blockers]' own note — the agent that announces
## the damage order for the live game — says a gang block is two or three
## bodies; three is where the enumeration stops.
const GANG_LIMIT := 3

## ...and a gang is only ever formed out of the best few blockers on the
## board, so a wide board cannot make the move list exponential. The
## blocker list is already sorted best-first, and a SINGLE block is still
## considered for every legal body — only the gangs are drawn from the
## head of it.
const GANG_POOL := 6


## Does OUR side get to put several bodies on one of THEIR attackers when
## it answers the crack-back (ply 4)? `false` is the model as it stood
## before 2026-09-05 — one blocker per attacker — and it is how
## `tests/ai/test_ai_gang_blocks_2026_09_05.gd` states the change and how
## the Deck Lab's null arm was run.
##
## THE OTHER HALF IS NOT HERE, and that is a measurement rather than an
## omission (docs/ROADMAP.md, "The gang block"). Widening the DEFENDER's
## answer to our forward attack — ply 2 — was built and measured on the
## same instrument: it changed 19.0% of searched declarations against this
## half's 15.1%, but it changed them the wrong way (120 narrower against
## 92 wider, where this half is 134 wider against 47), which is the
## pessimism the 2026-09-04 attack audit had just spent a pass removing.
## Both measured +0.1 on the win rate, so the direction is what decides.
var gang_defence := true


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

# --- the GANG-BLOCK arithmetic (2026-09-05) --------------------------------
#
# A gang divides one attacker's power between several blockers, so the two
# pair matrices below are not enough on their own: `we_kill` asks "does a
# kill d with its WHOLE power", and inside a gang it rarely gets to spend
# all of it on one body. These carry the pieces the division needs — the
# raw damage each side lands (prevention applied,
# [method AiPlayer._damage_after_prevention]), who strikes first, and who
# cannot be killed by damage at all — and [method resolve_block] puts them
# back together. For a gang of ONE the answer it gives is `we_kill` /
# `they_kill` exactly, which is what pins it to the engine's own
# [method AiPlayer._dies_to].

## Our creature has first strike (CR 510.4).
var a_first: PackedByteArray = PackedByteArray()
var d_first: PackedByteArray = PackedByteArray()
## Damage cannot finish this creature: indestructible, or a regeneration
## shield its controller can still pay for.
var a_immune: PackedByteArray = PackedByteArray()
var d_immune: PackedByteArray = PackedByteArray()
## What their d lands on our a, and our a on their d, if it strikes at all
## (row a, column d).
var hit_ours: PackedInt32Array = PackedInt32Array()
var hit_theirs: PackedInt32Array = PackedInt32Array()

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


# ------------------------------------------------------- one blocked body --

## ONE ATTACKER against the whole GANG blocking it, resolved the way the
## live game resolves it (CR 509.2 damage order, CR 510.1c lethal-first
## assignment, CR 702.19b trample spill). Returns
## `[attacker dies, bitmask of blockers that die, damage that gets past]`.
##
## THE ORDER IS [method AiPlayer.order_blockers]' OWN, restated over the
## model: the attacking player announces it, and that agent picks the
## max-WORTH subset of blockers whose lethal damage fits inside the power
## on offer, puts those first (worth-descending) and the rest after. A
## body nothing can be gained from — one damage cannot kill — is worth
## zero and sorts to the back, so damage is never spent burying something
## that gets up again. Modelling any other order would be modelling an
## attacker this AI does not play.
##
## [param attacker] indexes OUR side and [param blockers] THEIRS when
## [param ours_attacks] is true; the two sides are mirror images, so the
## same routine serves our combat and their crack-back.
func resolve_block(attacker: int, blockers: Array, ours_attacks: bool) -> Array:
	var atk_pow := a_pow[attacker] if ours_attacks else d_pow[attacker]
	var atk_soak := a_soak[attacker] if ours_attacks else d_soak[attacker]
	var atk_first := a_first[attacker] if ours_attacks else d_first[attacker]
	var atk_immune := a_immune[attacker] if ours_attacks else d_immune[attacker]
	var atk_trample := a_trample[attacker] if ours_attacks else d_trample[attacker]
	if blockers.is_empty():
		return [false, 0, atk_pow]
	# --- 1. does the attacker even live to strike? A blocker with first
	# strike that it does not share kills it before it assigns anything
	# (CR 510.4), which is exactly what `_damage_from`'s own first clause
	# says for a gang of one.
	var pre := 0
	var total := 0
	for b in blockers:
		var raw := _raw_onto(attacker, b, ours_attacks)
		total += raw
		if _blocker_first(b, ours_attacks) != 0 and atk_first == 0:
			pre += raw
	var struck_down := atk_immune == 0 and pre > 0 and pre >= atk_soak
	if struck_down:
		return [true, 0, 0]
	# --- 2. the damage order, then lethal-first down it (CR 510.1c).
	var order := _damage_order(attacker, blockers, atk_pow, ours_attacks)
	var remaining := atk_pow
	var dead := 0
	for b in order:
		var need: int = _soak_of(b, ours_attacks)
		var give := mini(remaining, maxi(need, 0))
		remaining -= give
		if _immune_of(b, ours_attacks) != 0:
			continue
		if _raw_onto_blocker(attacker, b, ours_attacks) <= 0:
			continue      # protection or a prevention shield: the damage lands as 0
		if give >= maxi(need, 1):
			dead |= 1 << b
	# --- 3. what the blockers land back. One killed by first strike never
	# strikes at all.
	var back := 0
	for b in blockers:
		if atk_first != 0 and _blocker_first(b, ours_attacks) == 0 \
				and (dead & (1 << b)) != 0:
			continue
		back += _raw_onto(attacker, b, ours_attacks)
	var atk_dies := atk_immune == 0 and back > 0 and back >= atk_soak
	# --- 4. trample: only what is left after EVERY blocker has been
	# assigned lethal damage spills to the face (CR 702.19b).
	var through := remaining if atk_trample != 0 else 0
	return [atk_dies, dead, through]


## The CR 509.2 damage-assignment order for one gang — see
## [method resolve_block], and [method AiPlayer.order_blockers] for the
## agent whose answer this restates. Ties break on model index, which is
## battlefield order (CONTRIBUTING.md rule 7: no RNG anywhere in here).
func _damage_order(attacker: int, blockers: Array, budget: int,
		ours_attacks: bool) -> Array[int]:
	var entries: Array[int] = []
	for b in blockers:
		entries.append(b)
	if entries.size() == 1:
		return entries
	var worth := {}
	for b in entries:
		var w := _value_of(b, ours_attacks)
		if _soak_of(b, ours_attacks) <= 0 or _immune_of(b, ours_attacks) != 0 \
				or _raw_onto_blocker(attacker, b, ours_attacks) <= 0:
			w = 0.0
		worth[b] = w
	var best_mask := 0
	var best_worth := -1.0
	var best_cost := 0
	if entries.size() <= 6:
		for mask in 1 << entries.size():
			var cost := 0
			var sum := 0.0
			for i in entries.size():
				if (mask & (1 << i)) != 0:
					cost += maxi(_soak_of(entries[i], ours_attacks), 0)
					sum += float(worth[entries[i]])
			if cost > budget:
				continue
			if sum > best_worth + 1e-9 \
					or (absf(sum - best_worth) <= 1e-9 and cost < best_cost):
				best_worth = sum
				best_mask = mask
				best_cost = cost
	var head: Array[int] = []
	var tail: Array[int] = []
	for i in entries.size():
		if (best_mask & (1 << i)) != 0:
			head.append(entries[i])
		else:
			tail.append(entries[i])
	var by_worth := func(x: int, y: int) -> bool:
		var wx := float(worth[x])
		var wy := float(worth[y])
		if absf(wx - wy) > 1e-9:
			return wx > wy
		return x < y
	head.sort_custom(by_worth)
	tail.sort_custom(by_worth)
	head.append_array(tail)
	return head


# The six accessors the mirror needs. `ours_attacks` picks the side, and
# nothing else in `resolve_block` has to know which combat it is in.

func _raw_onto(attacker: int, blocker: int, ours_attacks: bool) -> int:
	# damage the BLOCKER lands on the attacker
	return hit_ours[attacker * _m + blocker] if ours_attacks \
		else hit_theirs[blocker * _m + attacker]


func _raw_onto_blocker(attacker: int, blocker: int, ours_attacks: bool) -> int:
	# damage the ATTACKER lands on that blocker
	return hit_theirs[attacker * _m + blocker] if ours_attacks \
		else hit_ours[blocker * _m + attacker]


func _soak_of(blocker: int, ours_attacks: bool) -> int:
	return d_soak[blocker] if ours_attacks else a_soak[blocker]


func _immune_of(blocker: int, ours_attacks: bool) -> int:
	return d_immune[blocker] if ours_attacks else a_immune[blocker]


func _blocker_first(blocker: int, ours_attacks: bool) -> int:
	return d_first[blocker] if ours_attacks else a_first[blocker]


func _value_of(blocker: int, ours_attacks: bool) -> float:
	return d_val[blocker] if ours_attacks else a_val[blocker]


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
	var blocked_by: Dictionary = {}   # our index -> Array[int] of theirs
	var spent: Dictionary = {}
	for pair in pairs:
		var a: int = pair[1]
		var d: int = pair[2]
		if spent.has(d) or blocked_by.has(a):
			continue
		spent[d] = true
		var solo: Array[int] = [d]
		blocked_by[a] = solo
	# ONE BLOCKER PER ATTACKER, still, on this side of the table — see
	# `gang_defence` for the measurement that keeps it here and
	# docs/ROADMAP.md's ledger row for what lifting it would take.
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
		var gang: Array = blocked_by[a]
		var outcome := resolve_block(a, gang, true)
		if bool(outcome[0]):
			value -= a_val[a]
			my_dead |= 1 << a
		var dead: int = outcome[1]
		for d in gang:
			if (dead & (1 << d)) != 0:
				value += d_val[d]
				their_dead |= 1 << d
		through += int(outcome[2])
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
## met by nobody, by one free body, or — since 2026-09-05 — by a GANG of
## up to [constant GANG_LIMIT] of them. Returns the best value WE can get
## from here; [param acc] is the value already committed and
## [param damage] the face damage already let through. Cut as soon as the
## running best beats [param cutoff], which is a value THEY would never
## choose.
##
## THE MOVE ORDER IS NONE, THEN SINGLES, THEN GANGS, and that is
## load-bearing twice over. Alpha-beta wants its bound from the move the
## shipped policy would make, and a truncated line (the budget ran out
## mid-way) then degrades to exactly the one-blocker-per-attacker answer
## this used to give rather than to something arbitrary.
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
	# Options 2..n: every legal block of it, narrowest first.
	var legal: Array[int] = []
	for entry in free:
		var a: int = entry
		if (used & (1 << a)) != 0:
			continue
		if block_theirs[a * _m + d] == 0:
			continue
		legal.append(a)
	for gang in _gangs_of(legal):
		var mask := 0
		for a in gang:
			mask |= 1 << a
		var outcome := resolve_block(d, gang, false)
		var value := acc
		if bool(outcome[0]):
			value += d_val[d]           # the attacker dies to the block
		var dead: int = outcome[1]
		for a in gang:
			if (dead & (1 << a)) != 0:
				value -= a_val[a]
		var score := _assign(swing, index + 1, free, used | mask, value,
			damage + int(outcome[2]), cutoff, slice)
		if score > best:
			best = score
		if best > cutoff:
			return best
	return best


## Every block that may be declared against one attacker, given the bodies
## [param legal] that could legally take it: each ONE of them first (which
## is the whole of the pre-2026-09-05 move list), then the gangs, smallest
## first. Deterministic — the pool is already in a fixed order and the
## masks are walked ascending.
func _gangs_of(legal: Array[int]) -> Array:
	var out: Array = []
	for a in legal:
		var one: Array[int] = [a]
		out.append(one)
	if not gang_defence or legal.size() < 2:
		return out
	var pool: Array[int] = legal.slice(0, mini(legal.size(), GANG_POOL))
	for size in range(2, mini(GANG_LIMIT, pool.size()) + 1):
		for combo in 1 << pool.size():
			var members: Array[int] = []
			for i in pool.size():
				if (combo & (1 << i)) != 0:
					members.append(pool[i])
			if members.size() == size:
				out.append(members)
	return out


# ------------------------------------------------------------------ leaf --

## [method AiPlayer._face_damage_value] over the model: one point of life
## per point of damage, scaled up by the share of the REMAINING total the
## hit takes, so two damage is worth 2.2 against 20 life and 4.0 against 4.
static func _fdv(dmg: int, life: int) -> float:
	if dmg <= 0:
		return 0.0
	return float(dmg) * Evaluator.W_LIFE \
		* (1.0 + float(dmg) / float(maxi(life, 1)))
