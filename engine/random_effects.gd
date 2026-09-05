class_name RandomEffects
extends RefCounted
## The RANDOM-OBJECT subsystem: "a random creature", "a random graveyard",
## "a random color", "a random effect" — the vocabulary the 1997 Astral set
## is built on (mage-go's pkg/mage/effect_random_object.go is the model).
##
## Every pick goes through [member MtgGame.rng], so a seeded game replays a
## Whimsy line-for-line — which is the whole reason this lives in the engine
## instead of in each card file.
##
## Nothing here mutates the game: these are CHOOSERS. The card's effect takes
## the object they return and acts on it through the usual MtgGame helpers.
## Every chooser returns null / -1 / an empty result when no candidate
## exists, and callers are expected to do nothing in that case (CR 608.2:
## "as much as possible").


## A uniformly random integer in [0, n) — the primitive everything else
## uses. Returns -1 for n <= 0.
static func roll(game: MtgGame, n: int) -> int:
	if n <= 0:
		return -1
	return game.rng.randi_range(0, n - 1)


## One uniformly random element of [param items], or null when empty.
static func pick(game: MtgGame, items: Array) -> Variant:
	if items.is_empty():
		return null
	return items[roll(game, items.size())]


## [param count] DIFFERENT random elements of [param items] — "reveals X
## cards at random from their hand" (Nebuchadnezzar). Fewer than count when
## the list is shorter; the order of the result is itself random, so the
## caller can also use it as a shuffle.
static func sample(game: MtgGame, items: Array, count: int) -> Array:
	var pool := items.duplicate()
	var out: Array = []
	while out.size() < count and not pool.is_empty():
		out.append(pool.pop_at(roll(game, pool.size())))
	return out


## A random battlefield permanent matching [param filter]
## ([code]func(inst) -> bool[/code]; unset = any permanent), or null.
static func permanent(game: MtgGame, filter: Callable = Callable()) -> CardInstance:
	var pool: Array = []
	for inst in game.all_battlefield():
		if not filter.is_valid() or filter.call(inst):
			pool.append(inst)
	return pick(game, pool)


## A random battlefield CREATURE matching [param filter], or null.
static func creature(game: MtgGame, filter: Callable = Callable()) -> CardInstance:
	var pool: Array = []
	for inst in game.all_battlefield():
		if not inst.is_creature():
			continue
		if not filter.is_valid() or filter.call(inst):
			pool.append(inst)
	return pick(game, pool)


## A random object that is either a spell on the stack or a battlefield
## permanent (the Laces' target line, rolled instead of chosen), or null.
static func spell_or_permanent(game: MtgGame) -> CardInstance:
	var pool: Array = []
	for item in game.stack:
		if item.card != null and item.card.zone == Mtg.Zone.STACK:
			pool.append(item.card)
	for inst in game.all_battlefield():
		pool.append(inst)
	return pick(game, pool)


## A random "any target": a creature or a player, as a TargetRef. Null when
## every player has lost (which cannot happen mid-game).
static func damage_target(game: MtgGame) -> TargetRef:
	var pool: Array = []
	for inst in game.all_battlefield():
		if inst.is_creature():
			pool.append(TargetRef.card(inst))
	for p in game.players:
		if not p.has_lost:
			pool.append(TargetRef.player(p.id))
	return pick(game, pool)


## A random player id that hasn't lost, or -1.
static func player(game: MtgGame) -> int:
	var pool: Array = []
	for p in game.players:
		if not p.has_lost:
			pool.append(p.id)
	var chosen: Variant = pick(game, pool)
	return -1 if chosen == null else int(chosen)


## A random one of the five colours, as an Mtg.ManaColor flag.
static func color(game: MtgGame) -> int:
	return int(Mtg.WUBRG[roll(game, Mtg.WUBRG.size())])


## A random card in [param pid]'s graveyard matching [param filter], or null.
static func card_in_graveyard(game: MtgGame, pid: int,
		filter: Callable = Callable()) -> CardInstance:
	var pool: Array = []
	for inst in game.players[pid].graveyard:
		if not filter.is_valid() or filter.call(inst):
			pool.append(inst)
	return pick(game, pool)


## A random card in ANY library matching [param filter] (Pandora's Box
## reaches into "all players' decks"), or null.
static func card_in_libraries(game: MtgGame,
		filter: Callable = Callable()) -> CardInstance:
	var pool: Array = []
	for p in game.players:
		for inst in p.library:
			if not filter.is_valid() or filter.call(inst):
				pool.append(inst)
	return pick(game, pool)


## A random creature SUBTYPE present in [param pid]'s library, hand,
## battlefield AND GRAVEYARD ("a random creature type from those in target
## opponent's deck" — Aswan Jaguar). "" when that player has no creatures
## at all. The graveyard is in scope on purpose — the whole 60 cards the
## opponent brought are "their deck" — and it used to be scanned without
## being named here, which is a rules question, not a wording one.
static func creature_type_of(game: MtgGame, pid: int) -> String:
	var types: Array = []
	var p := game.players[pid]
	for pile in [p.library, p.hand, p.battlefield, p.graveyard]:
		for inst in pile:
			if not inst.data.is_creature():
				continue
			for t in inst.data.subtypes:
				if not types.has(t):
					types.append(t)
	var chosen: Variant = pick(game, types)
	return "" if chosen == null else String(chosen)


## Split [param total] into [param buckets] random parts (Orcish Catapult's
## "randomly distribute X counters"). Returns an array of buckets ints
## summing to total; an empty array when either is <= 0.
##
## A part may be ZERO — every point is rolled independently, so a bucket
## can simply never come up. (This said "positive parts" until 2026-09-01;
## a caller that assumed every named object got at least one counter would
## have been misled by it.)
static func distribute(game: MtgGame, total: int, buckets: int) -> Array:
	if total <= 0 or buckets <= 0:
		return []
	var out: Array = []
	out.resize(buckets)
	out.fill(0)
	for _i in total:
		var b := roll(game, buckets)
		out[b] = int(out[b]) + 1
	return out
