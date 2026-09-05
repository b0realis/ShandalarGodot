class_name ManaPool
extends RefCounted
## A player's mana pool: how much mana of each type is currently floating.
##
## Mana enters the pool via mana abilities (see ManaAbility — tapping lands,
## Sol Ring, ...) and leaves it when costs are paid. The pool empties at the
## end of every step (CR 500.4); MtgGame calls [method clear] at step
## boundaries.
##
## RESTRICTED MANA (CR 106.6): "Spend this mana only to cast artifact
## spells" (Mishra's Workshop) and "…only to cast creature spells"
## (Metamorphosis) live in a second, keyed pool. A payment names the
## USAGE KEYS it qualifies for; mana restricted to one of them is spent
## FIRST, because it is the mana that would otherwise be wasted.
##
## Payment algorithm (documented because it is a gameplay-visible choice):
## colored requirements are paid first with exactly-matching mana (falling
## back to any substitution the player has — Sunglasses of Urza's "you may
## spend white mana as though it were red"); the generic portion is then
## paid greedily — restricted mana, then colorless, then whichever color the
## player holds the most of. This is optimal for the 1997 card pool (no
## cost-matters cards); if that ever changes, replace [method pay] with a
## player-choice flow and delete this paragraph.

## Floating mana, keyed by Mtg.ManaColor flag → count.
var _mana: Dictionary = {}

## RESTRICTED floating mana: usage key (String) → {Mtg.ManaColor: count}.
var _restricted: Dictionary = {}


## Add [param amount] mana of [param color] to the pool.
func add(color: int, amount: int = 1) -> void:
	_mana[color] = int(_mana.get(color, 0)) + amount


## Add [param amount] mana of [param color] that may only be spent on
## things matching [param usage_key] ("artifact", "creature").
func add_restricted(color: int, amount: int, usage_key: String) -> void:
	if not _restricted.has(usage_key):
		_restricted[usage_key] = {}
	var bucket: Dictionary = _restricted[usage_key]
	bucket[color] = int(bucket.get(color, 0)) + amount


## How much UNRESTRICTED mana of [param color] is floating.
func amount_of(color: int) -> int:
	return int(_mana.get(color, 0))


## Everything of [param color] that is floating, RESTRICTED mana
## included — what a mana-pool readout should show. Rules code wants
## amount_of() or _spendable() instead; this is the honest total, not the
## amount any one payment may reach.
func total_of(color: int) -> int:
	var sum := int(_mana.get(color, 0))
	for key in _restricted:
		sum += int(_restricted[key].get(color, 0))
	return sum


## How much mana is floating under [param usage_key]'s restriction.
func restricted_total(usage_key: String) -> int:
	var sum := 0
	for c in _restricted.get(usage_key, {}):
		sum += int(_restricted[usage_key][c])
	return sum


## Total floating mana of all types, restricted mana included.
func total() -> int:
	var sum := 0
	for c in _mana:
		sum += _mana[c]
	for key in _restricted:
		sum += restricted_total(key)
	return sum


## A merged {color: count} view of everything spendable on a payment that
## qualifies for [param usage_keys].
func _spendable(usage_keys: Array) -> Dictionary:
	var out: Dictionary = _mana.duplicate()
	var seen: Dictionary = {}
	for key in usage_keys:
		# A key named twice must not count its bucket twice: `can_pay`
		# would say yes to a cost `pay` cannot finish (2026-09-02).
		if seen.has(key):
			continue
		seen[key] = true
		for c in _restricted.get(key, {}):
			out[c] = int(out.get(c, 0)) + int(_restricted[key][c])
	return out


## Can [param cost] (with X already chosen as [param x_value]) be paid from
## this pool right now? Pure check — does not mutate.
## [param usage_keys] names the restrictions this payment satisfies;
## [param substitutions] is a list of {"from": color, "to": color} the payer
## may apply (Sunglasses of Urza); [param any_color] lets ANY mana pay a
## coloured pip (North Star).
func can_pay(cost: ManaCost, x_value: int = 0, usage_keys: Array = [],
		substitutions: Array = [], any_color: bool = false) -> bool:
	var avail := _spendable(usage_keys)
	var pool_total := 0
	for c in avail:
		pool_total += int(avail[c])
	if any_color:
		return pool_total >= cost.mana_value() + x_value
	for c in cost.colored:
		var need: int = int(cost.colored[c])
		var take: int = mini(int(avail.get(c, 0)), need)
		avail[c] = int(avail.get(c, 0)) - take
		need -= take
		if need > 0:
			for sub in substitutions:
				if int(sub["to"]) != c:
					continue
				var from_color: int = int(sub["from"])
				var swapped: int = mini(int(avail.get(from_color, 0)), need)
				avail[from_color] = int(avail.get(from_color, 0)) - swapped
				need -= swapped
				if need <= 0:
					break
		if need > 0:
			return false
	var leftover := 0
	for c in avail:
		leftover += int(avail[c])
	return leftover >= cost.generic + x_value


## Pay [param cost] from the pool. Callers must check [method can_pay]
## first; paying an unpayable cost is a programming error and asserts.
## See [method can_pay] for the optional arguments.
func pay(cost: ManaCost, x_value: int = 0, usage_keys: Array = [],
		substitutions: Array = [], any_color: bool = false) -> void:
	assert(can_pay(cost, x_value, usage_keys, substitutions, any_color),
		"ManaPool.pay called without can_pay check")
	var generic_due: int = cost.generic + x_value
	if any_color:
		# North Star: every pip is payable with anything, so the whole cost
		# behaves like generic mana.
		generic_due = cost.mana_value() + x_value
	else:
		for c in cost.colored:
			var need: int = _take(c, int(cost.colored[c]), usage_keys)
			for sub in substitutions:
				if need <= 0:
					break
				if int(sub["to"]) == c:
					need = _take(int(sub["from"]), need, usage_keys)
			assert(need == 0, "ManaPool.pay could not cover a colored pip")
	# Generic: restricted mana first (it would be wasted otherwise), then
	# colorless, then the most abundant color.
	for key in usage_keys:
		for c in _restricted.get(key, {}).keys():
			generic_due = _take(c, generic_due, usage_keys)
			if generic_due <= 0:
				break
		if generic_due <= 0:
			break
	generic_due = _take(Mtg.ManaColor.C, generic_due, usage_keys)
	while generic_due > 0:
		var best := -1
		var best_amount := 0
		var avail := _spendable(usage_keys)
		for c in avail:
			if int(avail[c]) > best_amount:
				best_amount = int(avail[c])
				best = c
		if best == -1:
			# `can_pay` said yes, so this cannot happen — but a release
			# build strips `assert`, and an unbounded `while` on a wrong
			# answer is a frozen game, not a failed check. Leave the
			# cost short and say so (2026-09-02).
			push_error("ManaPool.pay ran out of mana mid-payment")
			break
		generic_due = _take(best, generic_due, usage_keys)


## Empty the pool (end of step, CR 500.4).
func clear() -> void:
	_mana.clear()
	_restricted.clear()


## Spend up to [param due] mana of [param color], taking RESTRICTED mana
## first; returns what remains due.
func _take(color: int, due: int, usage_keys: Array) -> int:
	if due <= 0:
		return due
	for key in usage_keys:
		if not _restricted.has(key):
			continue
		var bucket: Dictionary = _restricted[key]
		var have: int = int(bucket.get(color, 0))
		if have <= 0:
			continue
		var used: int = mini(have, due)
		bucket[color] = have - used
		due -= used
		if due <= 0:
			return 0
	var loose := int(_mana.get(color, 0))
	var spent: int = mini(loose, due)
	if spent > 0:
		_mana[color] = loose - spent
	return due - spent


func _to_string() -> String:
	var parts := PackedStringArray()
	for c in _mana:
		if _mana[c] > 0:
			parts.append("%s x%d" % [Mtg.COLOR_NAMES[c], _mana[c]])
	for key in _restricted:
		for c in _restricted[key]:
			if int(_restricted[key][c]) > 0:
				parts.append("%s x%d (%s only)" % [
					Mtg.COLOR_NAMES[c], _restricted[key][c], key])
	return "[" + ", ".join(parts) + "]"
