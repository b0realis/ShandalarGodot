class_name ManaPlanner
extends RefCounted
## THE MANA PLANNER — "which sources do I tap to pay for this?", asked by
## the AI seat and by the human's own auto-cast.
##
## THIS CODE IS THE AI's, MOVED. It was `AiPlayer._mana_sources` /
## `_plan_taps_from` / `_source_usable` / `_cheapest_source_first` /
## `_source_options` / `_source_key` / `_max_affordable_x`, bound to that
## agent's own `pid`. The owner's playtest of 2026-09-03 asked for the 1997
## AUTO-CAST — *"if you double-click a spell with a yellow name that can be
## cast, suitable lands should auto-tap and the card is cast quickly"* —
## and the standing instruction with it was to REUSE the planner rather
## than write a second one. So it moved here, `pid` became a parameter, and
## [AiPlayer] now delegates to it: one planner, one set of answers, and a
## human double-click that can never disagree with what the AI would have
## tapped.
##
## THE ORIGINAL AUTO-TAPPED, and the decompilation names the function:
## `try_to_pay_for_mana_by_autotapping(player, &amt, &v46,
## AUTOTAP_NO_CREATURES|AUTOTAP_NO_ARTIFACTS|AUTOTAP_NO_DONT_AUTO_TAP|
## AUTOTAP_NO_NONBASIC_LANDS, v47)` — read out of `Magic.exe` at `0x42e26b`
## by `shandalar-src/src/patches/patch_autotap_artifacts_and_creatures.pl`,
## whose own header says it *"replaces the logic for human left-double-click
## mana autotapping"*. Two things that patch settles: the 1997 auto-tapper
## existed and was reached by a left double-click, and its DEFAULT flags
## excluded creatures, artifacts, non-basic lands and any source the player
## had marked `Don't auto tap this card` (`@MENU_SMALLCARD`,
## `Program/UIStrings.txt:941`). Manalink widened it to artifacts and
## creatures; ours is Manalink-wide (the planner has always used every
## source the AI can pay for) MINUS the one exclusion the 1997 player
## controls — see [param excluded].
##
## Pure [RefCounted] with static methods only, in `engine/` because the
## engine and the AI both live there and neither may reach into `game/`.

## The untapped mana sources [param pid] has right now, sorted the way the
## planner wants them:
## `[inst, ability_index, color, amount, sacrifice, restriction_key, pain]`.
## `restriction_key` is "" for ordinary mana and the
## [member ManaAbility.restriction_key] of mana that may pay only for one
## kind of spell (Mishra's Workshop's "artifact") — a source a plan may use
## only when the caller's `usage_keys` include the key. `pain` is
## [member ManaAbility.pain], the life the tap costs (City of Brass).
##
## Split out from [method plan] because the list depends only on the
## battlefield, while a single "what should I cast?" pass plans a cost for
## EVERY card in hand (and, for {X} spells, once per candidate X). Building
## and sorting it once per decision instead of once per plan turns an
## O(hand x battlefield log battlefield) sweep into a single build.
##
## [param excluded] is a set of instance ids to leave alone, keyed
## `{id: true}` — the 1997 `Don't auto tap this card` mark, *"the only way
## to tap a locked land is manually, by clicking on it"* (`Duel.hlp`, topic
## **Territory**). Floating mana is never excluded: it is already in the
## pool and cannot be "not tapped".
##
## [param mind_pain] — off, and a source that hurts to tap sorts like any
## other (the planner as it was before 2026-09-06). It is the Deck Lab's
## null for [member AiProfile.minds_pain]; nothing else turns it off.
static func sources(game: MtgGame, pid: int, excluded: Dictionary = {},
		mind_pain := true) -> Array:
	var out: Array = []   # [inst, ability_index, color, amount, sacrifice, restriction_key, pain]
	# Mana already floating (a resolved Dark Ritual) is a source that costs
	# nothing to "tap": a null instance the executors skip. Without it the
	# Ritual's {B}{B}{B} sat in the pool until the step ended and burned.
	var pool := game.players[pid].mana_pool
	for color in Mtg.ManaColor.values():
		for unit in pool.amount_of(color):
			out.append([null, unit, color, 1, false, "", 0])   # one unit per entry
	for inst in game.players[pid].battlefield:
		if inst.tapped or inst.cur_mana_abilities.is_empty():
			continue
		if inst.is_creature() and inst.summoning_sick:
			continue
		if excluded.has(inst.id):
			continue          # `Don't auto tap this card`
		for index in inst.cur_mana_abilities.size():
			var ability: ManaAbility = inst.cur_mana_abilities[index]
			# Only abilities the planner can actually pay for: a rider it
			# does not model (mana, life, a sacrifice, counters to remove)
			# makes tap_for_mana refuse mid-plan, and the turn's lands are
			# spent for nothing. Rasputin Dreamweaver's "remove a dream
			# counter" is why counter costs are on this list.
			if ability.cost != null or ability.life_cost > 0 \
					or ability.counter_cost_kind != "" \
					or ability.sacrifice_filter.is_valid():
				continue
			var amount: int = ability.produces[0][1]
			if ability.dynamic_amount.is_valid():
				amount = int(ability.dynamic_amount.call(game, inst))
			# A dynamic-colour source (Gem Bazaar) makes the colour it is
			# SHOWING, not the seed colour it was built with; a CHOICE
			# source (Fellwar Stone) makes whichever of the colours on
			# offer this planner picks, and the planner models one colour
			# per source, so it takes the first — which is also what the
			# AI's own answer_color would say when tap_for_mana asks.
			var color: int = ability.produces[0][0]
			if ability.color_options.is_valid():
				var offered: Array = ability.color_options.call(game, inst)
				color = int(offered[0]) if not offered.is_empty() \
					else Mtg.ManaColor.C
			elif ability.dynamic_color.is_valid():
				color = int(ability.dynamic_color.call(game, inst))
			out.append([inst, index, color,
				amount, ability.sacrifice_source, ability.restriction_key,
				ability.pain if mind_pain else 0])
	# Fewer options first; painful sources after painless; sacrifices last.
	out.sort_custom(cheapest_source_first)
	return out


## The tap plan covering [param cost] against a pre-built [param src] list:
## an Array of `[instance, ability_index]` pairs (a null instance is mana
## already floating, which the executors skip), or `[]` when no plan
## covers it. A cost that is FREE also plans as `[]` — callers check that
## first (see [method plan_and_pay]).
##
## [param x_value] is additional GENERIC mana on top of the printed cost:
## the chosen X, a surcharge, or both.
##
## [param usage_keys] are the restriction keys the thing being paid for
## qualifies for ([method MtgGame.mana_usage_keys] — "artifact" for an
## artifact spell, nothing for an ability): a RESTRICTED source (Mishra's
## Workshop) is planned only when its key is among them. Before the
## 2026-09-02 sweep the Workshop was three generic mana to the planner, and
## every creature it "paid for" bounced off the engine with the lands
## already tapped.
static func plan_from(src: Array, cost: ManaCost, x_value: int,
		usage_keys: Array = []) -> Array:
	var out: Array = []
	var used_instances: Dictionary = {}   # source key -> true (O(1) probes)
	var pool_check := ManaPool.new()
	# Colored requirements first.
	for color in cost.colored:
		for _n in cost.colored[color]:
			var found := false
			for s in src:
				if used_instances.has(source_key(s)) or s[2] != color \
						or not source_usable(s, usage_keys):
					continue
				out.append([s[0], s[1]])
				used_instances[source_key(s)] = true
				pool_check.add(s[2], s[3])
				found = true
				break
			if not found:
				return []
	# Generic + X from whatever remains.
	var generic := cost.generic + x_value
	var floating := pool_check.total() - cost.mana_value() + cost.generic
	generic -= maxi(floating, 0)
	for s in src:
		if generic <= 0:
			break
		if used_instances.has(source_key(s)) or not source_usable(s, usage_keys):
			continue
		out.append([s[0], s[1]])
		used_instances[source_key(s)] = true
		generic -= s[3]
	if generic > 0:
		return []
	return out


## [method plan_from] against a source list built on the spot.
static func plan(game: MtgGame, pid: int, cost: ManaCost, x_value: int,
		usage_keys: Array = [], excluded: Dictionary = {}) -> Array:
	return plan_from(sources(game, pid, excluded), cost, x_value, usage_keys)


## May the source [param s] pay for something with [param usage_keys]?
## Unrestricted mana always; restricted mana only for its own key.
static func source_usable(s: Array, usage_keys: Array) -> bool:
	var key: String = String(s[5]) if s.size() > 5 else ""
	return key == "" or usage_keys.has(key)


## Comparator for [method sources]: non-sacrifice sources first, then the
## ones that cost no life (a Plains, and a Tundra too, before a City of
## Brass — the dual's flexibility is free and the City's costs a life a
## tap), then the least flexible land (a basic before a dual). A named
## static instead of an inline lambda — the planner runs once per
## castable card per AI action, and a lambda allocates a fresh Callable
## on every call.
static func cheapest_source_first(a: Array, b: Array) -> bool:
	if a[4] != b[4]:
		return not a[4]
	var pain_a := source_pain(a)
	var pain_b := source_pain(b)
	if (pain_a > 0) != (pain_b > 0):
		return pain_a == 0
	return source_options(a) < source_options(b)


## The life a source's tap costs its controller ([member ManaAbility.pain]).
static func source_pain(s: Array) -> int:
	return int(s[6]) if s.size() > 6 else 0


## The life [param tap_plan] would cost, summed over the sources in
## [param src] it taps — what an AI seat charges an ability for being
## paid through a City of Brass ([method AiPlayer._try_activate]).
static func plan_pain(src: Array, tap_plan: Array) -> int:
	var pain := 0
	for step in tap_plan:
		if step[0] == null:
			continue
		for s in src:
			if s[0] == step[0] and int(s[1]) == int(step[1]):
				pain += source_pain(s)
				break
	return pain


## How many ways a source can make mana (floating mana: none — spend it
## first, it is gone at the end of the step).
static func source_options(s: Array) -> int:
	return 0 if s[0] == null else s[0].cur_mana_abilities.size()


## The key a plan tracks a source by — one instance taps once; floating
## mana of one colour is one bucket.
static func source_key(s: Array) -> String:
	return "pool:%d:%d" % [int(s[2]), int(s[1])] if s[0] == null else "inst:%d" % s[0].id


## Is this cost nothing at all? (A free cost plans as `[]`, which is also
## what "no plan" looks like, so every executor asks this first.)
static func cost_is_free(cost: ManaCost) -> bool:
	return cost.mana_value() == 0 and not cost.has_x


## Execute [param tap_plan] — tap every real source in it, in order.
## Floating-mana entries (a null instance) are already in the pool.
static func run_plan(game: MtgGame, pid: int, tap_plan: Array) -> void:
	for step in tap_plan:
		if step[0] != null:
			game.tap_for_mana(pid, step[0], step[1])


## Plan and pay [param cost] plus [param extra] generic. True when the pool
## can cover it afterwards. [param usage_keys]: see [method plan_from].
static func plan_and_pay(game: MtgGame, pid: int, cost: ManaCost, extra := 0,
		usage_keys: Array = [], excluded: Dictionary = {}) -> bool:
	if cost_is_free(cost) and extra == 0:
		return true
	if game.players[pid].mana_pool.can_pay(cost, extra, usage_keys):
		return true
	var tap_plan := plan(game, pid, cost, extra, usage_keys, excluded)
	if tap_plan.is_empty():
		return false
	run_plan(game, pid, tap_plan)
	return game.players[pid].mana_pool.can_pay(cost, extra, usage_keys)


## The largest X [param pid] could pay for. [param src]: a pre-built source
## list; pass one when the caller already has it — this loop plans a cost
## once per candidate X.
##
## The 1997 rule for the auto-cast's X is this number and nothing else:
## *"If you double-click to auto-cast an X spell, ALL of the mana you have
## available in your pool and from land sources will be put into that
## spell"* (`Duel.hlp`, topic **Hands**; topic **Spells** says it again).
static func max_affordable_x(game: MtgGame, pid: int, cost: ManaCost,
		extra := 0, src: Array = [], x_color := 0,
		usage_keys: Array = [], excluded: Dictionary = {}) -> int:
	if src.is_empty():
		src = sources(game, pid, excluded)
	# A doubled {X}{X} cost (Part Water) charges the chosen X twice, so the
	# affordable X is the affordable generic divided by the {X} count.
	var per_x: int = maxi(cost.x_count, 1)
	var x := 0
	if x_color != 0:
		# "Spend only black mana on X" (Drain Life): X is coloured pips,
		# so the plan must find that colour for every point of it.
		while not plan_from(src,
				cost.plus_colored(x_color, (x + 1) * per_x), extra, usage_keys).is_empty():
			x += 1
		return x
	while not plan_from(src, cost, extra + (x + 1) * per_x, usage_keys).is_empty():
		x += 1
	return x
