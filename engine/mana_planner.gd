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
## AND THAT FLAG LIST IS WHERE THE TIE-BREAK COMES FROM (2026-09-11).
## `AUTOTAP_NO_NONBASIC_LANDS` says the 1997 auto-tapper would not touch a
## Library of Alexandria, a Strip Mine or a Mishra's Factory at all: the
## utility land was the player's to spend by hand. A widened auto-tapper
## cannot keep that rule — a deck of nothing but nonbasics could never
## auto-cast — so ours keeps the INSTINCT instead and spends the basic
## first, reaching the utility land only when the cost needs it
## ([method holds_untapped], [method cheapest_source_first]).
##
## Pure [RefCounted] with static methods only, in `engine/` because the
## engine and the AI both live there and neither may reach into `game/`.

## The untapped mana sources [param pid] has right now, sorted the way the
## planner wants them:
## `[inst, ability_index, color, amount, sacrifice, restriction_key, pain,
## holds]`. Opted-in mana converters add a ninth Dictionary with their
## activation cost, repeatability and floating-pool snapshot. They are never
## counted as free sources; `mana_conversion_planner.gd` orders their costs.
## `restriction_key` is "" for ordinary mana and the
## [member ManaAbility.restriction_key] of mana that may pay only for one
## kind of spell (Mishra's Workshop's "artifact") — a source a plan may use
## only when the caller's `usage_keys` include the key. `pain` is
## [member ManaAbility.pain], the life the tap costs (City of Brass).
## `holds` is [method holds_untapped], what the source can still do while
## it stands untapped — the tie-break of 2026-09-11.
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
##
## [param viewer] — the seat ASKING, when it is not [param pid]'s own
## (2026-09-16). A mana source in the HAND (Elvish Spirit Guide's "exile
## this card from your hand") is hidden information, and rule 8 of
## CONTRIBUTING.md forbids the computer opponent to read the other seat's
## hand for anything — so an opponent's count of what this seat can pay
## (a blocking tax, a spell tax, the open mana a counter must beat) takes
## only the hand cards that are already revealed. The default, -1, is the
## seat's own full knowledge: the engine paying for its player, the AI
## planning its own casts.
static func sources(game: MtgGame, pid: int, excluded: Dictionary = {},
		mind_pain := true, viewer := -1) -> Array:
	var out: Array = []   # [inst, index, color, amount, sacrifice, key, pain, holds]
	# Mana already floating (a resolved Dark Ritual) is a source that costs
	# nothing to "tap": a null instance the executors skip. Without it the
	# Ritual's {B}{B}{B} sat in the pool until the step ended and burned.
	var pool := game.players[pid].mana_pool
	for color in Mtg.ManaColor.values():
		for unit in pool.amount_of(color):
			out.append([null, unit, color, 1, false, "", 0, 0])   # one unit per entry
	for key in pool._restricted:
		for color in pool._restricted[key]:
			for unit in int(pool._restricted[key][color]):
				out.append([null, unit, int(color), 1, false, String(key), 0, 0])
	var candidates: Array[CardInstance] = game.players[pid].battlefield + game.players[pid].hand
	if game.foreign_land_mana.has(pid):
		for land in game.players[1 - pid].battlefield:
			if game.may_tap_foreign_land(pid, land): candidates.append(land)
	for inst in candidates:
		if inst.cur_mana_abilities.is_empty():
			continue
		if excluded.has(inst.id):
			continue          # `Don't auto tap this card`
		if inst.zone == Mtg.Zone.HAND and viewer >= 0 and viewer != pid \
				and not inst.revealed_in_hand:
			continue          # another seat's hidden card (rule 8)
		# Read once per instance, not once per comparison: the sort asks for
		# it O(n log n) times and the answer is the same every time.
		var holds := holds_untapped(inst)
		for index in inst.cur_mana_abilities.size():
			var ability := game.mana_ability_for(pid, inst, index)
			var borrowed := inst.zone == Mtg.Zone.BATTLEFIELD and inst.controller_id != pid
			if borrowed and not game.may_tap_foreign_land(pid, inst, index): continue
			if not ability.object_costs.is_empty(): continue # not free, must be chosen explicitly
			if inst.zone != ability.activation_zone: continue
			# Sacrificing a Swamp is never an implicit auto-tap. A player may
			# activate it explicitly; planners must not count its output free.
			if game.BLACK_SYMBOL_COST.amount(game, ability.cost) > 0: continue
			if ability.taps_source and (inst.tapped or (inst.is_creature() and inst.summoning_sick)):
				continue
			# Only abilities the planner can actually pay for: a rider it
			# does not model (mana, life, a sacrifice, counters to remove)
			# makes tap_for_mana refuse mid-plan, and the turn's lands are
			# spent for nothing. Rasputin Dreamweaver's "remove a dream
			# counter" is why counter costs are on this list.
			if (ability.cost != null and not ability.planner_conversion) or ability.life_cost > 0 \
					or (ability.counter_cost_kind != "" and not ability.planner_counter_cost) \
					or ability.sacrifice_filter.is_valid():
				continue
			if ability.counter_cost_kind != "" and int(inst.counters.get(ability.counter_cost_kind, 0)) < ability.counter_cost_count: continue
			var amount := ability.amount_for(game, inst, pid)
			# Storage lands have no guaranteed base output; the announced
			# counter choice (whose default is all available fuel) supplies it.
			if amount == 0 and ability.any_number_counter_kind != "":
				amount = int(inst.counters.get(ability.any_number_counter_kind, 0)) * ability.bonus_per_counter
			if amount <= 0:
				continue
			# A dynamic-colour source (Gem Bazaar) makes the colour it is
			# SHOWING, not the seed colour it was built with. A CHOICE
			# source (Fellwar Stone) makes whichever of the colours on
			# offer its controller picks as it is tapped, so it is listed
			# ONCE PER COLOUR, the way a dual land is listed once per
			# ability: the rows share the instance, [method source_key]
			# lets a plan spend it once, and the row a plan picks names the
			# colour the tap is then told to make ([method step_of]). Until
			# 2026-09-17 the planner took the FIRST colour on offer for its
			# one row, so a Stone facing an Island and a Mountain was blue
			# to every plan and could never be planned for a {R}.
			var colors: Array = [ability.produces[0][0]]
			if ability.color_options.is_valid():
				colors = ability.color_options.call(game, inst).duplicate()
				if colors.is_empty():
					colors = [Mtg.ManaColor.C]
			elif ability.dynamic_color.is_valid():
				colors = [int(ability.dynamic_color.call(game, inst))]
			for color_choice in colors:
				var row := _source_row(game, pool, inst, index, ability,
					int(color_choice), amount, holds, mind_pain, borrowed)
				if borrowed and not row.is_empty():
					# These legacy restrictions already mean spells only;
					# conjunct keys preserve any other restriction as well.
					row[5] = "spell" if ability.restriction_key == "" else "spell:" + ability.restriction_key
					if row.size() > 8 and row[8].has("outputs"):
						# Only the land's own output is restricted. Independently
						# triggered bonus mana retains the trigger's restriction.
						for n in ability.produces.size(): row[8].outputs[n][2] = row[5]
				if not row.is_empty():
					out.append(row)
	# Fewer options first; painful sources after painless; sacrifices last;
	# and last of all, the source that is holding something back.
	out.sort_custom(cheapest_source_first)
	return out


## The source row for one mana ability making [param color] — a plain
## row, or one with the converter/multi-output ninth entry (see
## [method sources]); `[]` when the ability is not one the planner models.
static func _source_row(game: MtgGame, pool: ManaPool, inst: CardInstance,
		index: int, ability: ManaAbility, color: int, amount: int, holds: int,
		mind_pain: bool, borrowed := false) -> Array:
	# Only public descriptors, never speculative callbacks or RNG.
	# Snowfall's restricted blue bonus is not ordinary island mana,
	# and High Tide still adds BLUE after Darkness recolors the land.
	var bonuses: Array = []
	if ability.taps_source and inst.is_land():
		var triggers: Array = []
		for entry in game.delayed_triggers: triggers.append(entry.trigger)
		for permanent in game.all_battlefield():
			if not permanent.cur_abilities_silenced: triggers.append_array(permanent.cur_triggered_abilities)
		for trigger in triggers:
			if not trigger.is_mana_trigger or trigger.mana_bonus_amount <= 0 or not inst.has_subtype(trigger.mana_bonus_subtype): continue
			var restriction: String = trigger.mana_bonus_restriction
			if restriction == "cumulative_upkeep" and game.current_step() != Mtg.Step.UPKEEP: continue
			var bonus: int = trigger.mana_bonus_amount
			if (inst.cur_supertypes & Mtg.Supertype.SNOW) != 0: bonus += trigger.mana_bonus_snow_extra
			if not borrowed and trigger.mana_bonus_color == color and restriction == ability.restriction_key: amount += bonus
			else: bonuses.append([trigger.mana_bonus_color, bonus, restriction])
	var row: Array = [inst, index, color,
		amount, ability.sacrifice_source or ability.exile_source, ability.restriction_key,
		ability.pain if mind_pain else 0, holds]
	if ability.planner_counter_cost and not ability.taps_source:
		# Finite counter fuel, never a reusable free source. Search
		# budgets activations and the real engine removes each counter.
		row.append({"cost": ability.cost, "repeatable": true,
			"fuel_key": "%d:%s" % [inst.id, ability.counter_cost_kind],
			"fuel": int(inst.counters.get(ability.counter_cost_kind, 0)) / maxi(1, ability.counter_cost_count),
			"cost_usage": game.ability_mana_usage_keys(inst),
			"floating": pool._mana.duplicate(), "restricted": pool._restricted.duplicate(true)})
	elif ability.planner_conversion:
		if ability.produces.size() != 1 or ability.color_options.is_valid() \
				or ability.dynamic_amount.is_valid() or ability.dynamic_color.is_valid():
			return []
		row.append({"cost": ability.cost, "repeatable": not ability.taps_source and not ability.sacrifice_source,
			"cost_usage": game.ability_mana_usage_keys(inst),
			"floating": pool._mana.duplicate(), "restricted": pool._restricted.duplicate(true)})
	elif ability.produces.size() > 1 or not bonuses.is_empty():
		# One tap can produce DIFFERENT colours together (Adarkar
		# Unicorn). Treat it as one atomic action in the pure fallback.
		var outputs: Array = [[color, amount, ability.restriction_key]]
		for pair in ability.produces.slice(1):
			outputs.append([pair[0], pair[1], ability.restriction_key])
		outputs.append_array(bonuses)
		row.append({"cost": null, "repeatable": false, "outputs": outputs,
			"floating": pool._mana.duplicate(), "restricted": pool._restricted.duplicate(true)})
	return row


## The tap plan covering [param cost] against a pre-built [param src] list:
## an Array of `[instance, ability_index]` pairs (a null instance is mana
## already floating, which the executors skip; a colour-choice source's
## step carries the colour the plan picked as a third entry — see
## [method step_of]), or `[]` when no plan covers it. A cost that is FREE
## also plans as `[]` — callers check that first (see
## [method plan_and_pay]).
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
	if cost.restricted_x_amount > 0:
		# Enumerate the mixtures the restriction allows, preserving coupled
		# sources and restrictions in the ordinary planner. The palette is
		# ManaPool's own spending order, so the colours a plan taps for are
		# the colours the payment then spends: Soul Burn's life-gaining {B}
		# first, and every other mask (Primitive Justice's {R}/{G}) the
		# same way. Until 2026-09-16 only the {B}/{R} mask planned at all
		# and every other one reported the cast as unpayable, which is what
		# left the duel screen unable to auto-tap a second target for it.
		var restricted_due := cost.restricted_x_due(x_value)
		var palette: Array[int] = []
		for color in ManaPool.RESTRICTED_SPEND_ORDER:
			if (color & cost.restricted_x_mask) != 0:
				palette.append(color)
		if palette.is_empty():
			return []
		var concrete := cost.minus_generic(0)
		concrete.restricted_x_mask = 0
		concrete.restricted_x_amount = 0
		return _plan_restricted(src, concrete, palette, restricted_due,
			maxi(-cost.generic, x_value), usage_keys)
	var converts := false
	for row in src:
		if row.size() > 8:
			converts = true
			break
	if not converts:
		return _plan_free_sources(src, cost, x_value, usage_keys)
	var ordinary: Array = []
	for row in src:
		if row.size() <= 8: ordinary.append(row)
	var simple := _plan_free_sources(ordinary, cost, x_value, usage_keys)
	if not simple.is_empty() or (cost.mana_value() + x_value == 0):
		return simple
	return preload("res://engine/mana_conversion_planner.gd").plan(src, cost, x_value, usage_keys)


## One restricted-X mixture at a time: the earliest colour of
## [param palette] takes as much of [param due] as it can, and the search
## backs off a point at a time until a plan comes out. The recursion is one
## level per colour in the mask and at most `due + 1` branches each, which
## is a handful for the two-colour masks this pool prints.
static func _plan_restricted(src: Array, base: ManaCost, palette: Array[int],
		due: int, x_value: int, usage_keys: Array) -> Array:
	if palette.size() == 1:
		return plan_from(src, base.plus_colored(palette[0], due), x_value, usage_keys)
	var rest: Array[int] = palette.slice(1)
	for take in range(due, -1, -1):
		var possible := _plan_restricted(src, base.plus_colored(palette[0], take),
			rest, due - take, x_value, usage_keys)
		if not possible.is_empty():
			return possible
	return []


static func _plan_free_sources(src: Array, cost: ManaCost, x_value: int,
		usage_keys: Array) -> Array:
	var out: Array = []
	var used_instances: Dictionary = {}   # source key -> true (O(1) probes)
	var pool_check := ManaPool.new()
	# Colored requirements first.
	for color in cost.colored:
		for _n in cost.colored[color]:
			if pool_check.amount_of(color) >= int(cost.colored[color]):
				break   # one charged source can cover several coloured pips
			var found := false
			for s in src:
				if used_instances.has(source_key(s)) or s[2] != color \
						or not source_usable(s, usage_keys):
					continue
				out.append(step_of(s))
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
		out.append(step_of(s))
		used_instances[source_key(s)] = true
		generic -= s[3]
	if generic > 0:
		return []
	return out


## [method plan_from] against a source list built on the spot.
static func plan(game: MtgGame, pid: int, cost: ManaCost, x_value: int,
		usage_keys: Array = [], excluded: Dictionary = {}, viewer := -1) -> Array:
	return plan_from(sources(game, pid, excluded, true, viewer), cost, x_value, usage_keys)


## May the source [param s] pay for something with [param usage_keys]?
## Unrestricted mana always; restricted mana only for its own key.
static func source_usable(s: Array, usage_keys: Array) -> bool:
	# A card being cast cannot exile itself to fund its own spell.
	if s[0] != null and usage_keys.has("spell_instance:%d" % s[0].id): return false
	# Coupled output can have different restrictions: Piracy's borrowed
	# land mana is spell-only, while High Tide's independent bonus is not.
	if s.size() > 8 and s[8].has("outputs"):
		for output in s[8].outputs:
			if int(output[1]) > 0 and (output[2] == "" or usage_keys.has(output[2])): return true
		return false
	var key: String = String(s[5]) if s.size() > 5 else ""
	return key == "" or usage_keys.has(key)


## Comparator for [method sources]: non-sacrifice sources first, then the
## ones that cost no life (a Plains, and a Tundra too, before a City of
## Brass — the dual's flexibility is free and the City's costs a life a
## tap), then the least flexible land (a basic before a dual), and last —
## among sources that were equal on every count above, where the answer
## used to be battlefield order — the one HOLDING NOTHING BACK
## ([method holds_untapped]). A named static instead of an inline lambda —
## the planner runs once per castable card per AI action, and a lambda
## allocates a fresh Callable on every call.
##
## THE TIE-BREAK IS THE LAST KEY ON PURPOSE (2026-09-11). It decides only
## what was undecided; every ordering the planner already had — the
## sacrifice last, the painless before the painful, the basic before the
## dual — is untouched, so a Library of Alexandria beside a lone Tundra is
## still spent before the dual and the dual's flexibility still wins. That
## case is a second question with a second measurement, and it is left
## open rather than folded in here (`docs/ai-difficulty.md` §5).
static func cheapest_source_first(a: Array, b: Array) -> bool:
	if a[4] != b[4]:
		return not a[4]
	var pain_a := source_pain(a)
	var pain_b := source_pain(b)
	if (pain_a > 0) != (pain_b > 0):
		return pain_a == 0
	var options_a := source_options(a)
	var options_b := source_options(b)
	if options_a != options_b:
		return options_a < options_b
	return source_holds(a) < source_holds(b)


## What an untapped [param inst] can still DO that tapping it for mana
## takes away — THE PLANNER'S TIE-BREAK, 2026-09-11. 0 for a Forest, and
## for every source whose only printed line is the mana.
##
## Read as a SHAPE and never as a card name, which is also the rule the
## AI's own decision code keeps: two things a permanent prints, both of
## them foreclosed by the tap.
##
## [b]THE {T} THAT IS ALREADY SPOKEN FOR.[/b] A permanent has one tap
## symbol to spend (CR 107.5 — an already-tapped permanent cannot be
## tapped again to pay a cost), so a mana ability and any other activated
## ability with a tap in its cost are competing for the same thing. Tapping
## for mana is the engine refusing the other one in as many words:
## *"Library of Alexandria is already tapped"*, *"Strip Mine is already
## tapped"*. In this pool that shape is SIXTEEN cards — the draw, the
## land destruction, a Desert's shot at an attacker, a Pendelhaven's pump,
## the five mana batteries' charge counter, Karakas, Urborg (which prints
## two of them), Hammerheim, Tolaria, Elephant Graveyard, City of Shadows
## and the Factory's own Assembly-Worker pump.
##
## [b]THE BODY IT COULD BECOME.[/b] An ability that animates the source
## ([AnimateSelfEffect]) buys an attacker or a blocker, and a tapped
## creature can do neither (CR 508.1a, CR 509.1a). Mishra's Factory
## animates for {1} with NO tap in the cost, so the first shape would
## price the Factory for the wrong ability — its Assembly-Worker pump —
## and a manland printed without one would read as a plain land.
##
## WHAT IS DELIBERATELY NOT COUNTED. A creature that makes mana (Llanowar
## Elves, Birds of Paradise — seven in the pool) is worth something
## untapped too, but that is the AI's combat reading rather than the
## planner's arithmetic: [method AiPlayer._attackers_excluded] and
## [method AiPlayer._main2_mana_held] already take bodies out of the list
## by name of the attack they are wanted for, and a planner that pushed
## every mana creature behind every land would be re-deciding combat from
## inside a sort. And PAYABILITY is not read either: whether the other
## ability could be paid for depends on the rest of the turn, while this
## list is built once per decision off the battlefield alone.
static func holds_untapped(inst: CardInstance) -> int:
	if inst == null:
		return 0
	var held := 0
	for ability in inst.cur_activated_abilities:
		if ability.tap_cost:
			held += 1
			continue      # one ability, one thing held back
		for effect in ability.effects:
			if effect is AnimateSelfEffect:
				held += 1
				break
	return held


## What [method holds_untapped] answered for a source row.
static func source_holds(s: Array) -> int:
	return int(s[7]) if s.size() > 7 else 0


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
## first, it is gone at the end of the step). A colour CHOICE counts as
## one more way, so a Fellwar Stone sorts with the duals, after the basic
## whose colour it is borrowing (2026-09-17).
static func source_options(s: Array) -> int:
	if s[0] == null:
		return 0
	var options: int = s[0].cur_mana_abilities.size()
	for ability in s[0].cur_mana_abilities:
		if ability.color_options.is_valid():
			options += 1
	return options


## The key a plan tracks a source by — one instance taps once; floating
## mana of one colour is one bucket.
static func source_key(s: Array) -> String:
	return "pool:%d:%d:%s" % [int(s[2]), int(s[1]), String(s[5]) if s.size() > 5 else ""] if s[0] == null else "inst:%d" % s[0].id


## The plan step for source row [param s]: `[instance, ability_index]`,
## and for a COLOUR-CHOICE source (Fellwar Stone, listed once per colour
## by [method sources]) `[instance, ability_index, color]` — the colour
## this plan is counting on, which [method run_plan] hands to
## [method MtgGame.tap_for_mana] so the tap makes what the plan priced.
## A colour the source does not offer is ignored there and the tap asks
## instead: that is how [method auto_tap_sources]' generic-only row
## ({C}) leaves the question to the player.
static func step_of(s: Array) -> Array:
	if source_chooses_color(s):
		return [s[0], s[1], int(s[2])]
	return [s[0], s[1]]


## Is the source row [param s] a colour-choice ability's (Fellwar Stone)?
static func source_chooses_color(s: Array) -> bool:
	return s[0] != null and int(s[1]) < s[0].cur_mana_abilities.size() \
		and s[0].cur_mana_abilities[int(s[1])].color_options.is_valid()


## The source list a PLAYER's auto-tap plans over — the duel's double-click
## and SGManalink's autopay — which is [method sources] with THE OWNER'S
## RULE FOR FELLWAR STONE (2026-09-17) applied: *"Fellwar Stone should tap
## automatically only for a colourless mana request, or if we know the
## opponent only has land of the colour we know. If Fellwar Stone can
## produce many mana types, you should be asked upon tapping what kind of
## mana you want it to produce."*
##
## So a choice source offering ONE colour keeps its row (the colour is
## known, and the tap asks nothing — [method MtgGame.tap_for_mana]); one
## offering SEVERAL is collapsed to a single {C} row, which the fast path
## can spend only on generic mana and whose tap, told a colour the Stone
## does not offer, puts the question to the player. The AI's plans keep
## the full per-colour list: a heuristic seat answers its own question
## with the colour its plan picked.
static func auto_tap_sources(game: MtgGame, pid: int,
		excluded: Dictionary = {}) -> Array:
	var src := sources(game, pid, excluded)
	var rows_per_source: Dictionary = {}
	for s in src:
		if source_chooses_color(s):
			var key := source_key(s)
			rows_per_source[key] = int(rows_per_source.get(key, 0)) + 1
	var out: Array = []
	var collapsed: Dictionary = {}
	for s in src:
		if not source_chooses_color(s) or int(rows_per_source.get(source_key(s), 0)) < 2:
			out.append(s)
			continue
		var key := source_key(s)
		if collapsed.has(key):
			continue
		collapsed[key] = true
		var generic_only: Array = s.duplicate()
		generic_only[2] = Mtg.ManaColor.C
		out.append(generic_only)
	return out


## Is this cost nothing at all? (A free cost plans as `[]`, which is also
## what "no plan" looks like, so every executor asks this first.)
static func cost_is_free(cost: ManaCost) -> bool:
	return cost.mana_value() == 0 and not cost.has_x


## Execute [param tap_plan] — tap every real source in it, in order.
## Floating-mana entries (a null instance) are already in the pool. A
## colour-choice step ([method step_of]) tells the tap its colour. Stops
## at a tap that HOLDS THE DUEL OPEN on a question (a player's Fellwar
## Stone asked its colour): every tap after it would be refused while the
## question stands, so the caller finishes the plan once it is answered
## (DuelScreen._auto_tap_for_pending, SgDuelActions.autopay). Returns
## true when every step ran.
static func run_plan(game: MtgGame, pid: int, tap_plan: Array) -> bool:
	for step in tap_plan:
		if step[0] != null:
			run_step(game, pid, step)
			if game.awaiting_choice != null:
				return false
	return true


## Tap one plan [param step] (never a floating-mana step, whose source is
## null): the colour a three-entry step carries goes with it, so a
## colour-choice source makes what the plan priced instead of asking.
## Returns [method MtgGame.tap_for_mana]'s refusal, "" when it tapped.
static func run_step(game: MtgGame, pid: int, step: Array) -> String:
	return game.tap_for_mana(pid, step[0], step[1],
		int(step[2]) if step.size() > 2 else -1)


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
