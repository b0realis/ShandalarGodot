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
## `[inst, ability_index, color, amount, rank, restriction_key, pain,
## holds]`. Opted-in mana converters add a ninth Dictionary with their
## activation cost, repeatability and floating-pool snapshot. They are never
## counted as free sources; `mana_conversion_planner.gd` orders their costs.
## `amount` counts the bonus mana of the mana triggers on the battlefield
## that describe themselves ([method _bonus_reaches]). `rank` is what the
## tap spends BESIDES the mana ([method source_rank]): 0 for a Forest, and
## bits for a source that does not untap, one an Aura punishes for being
## tapped, and one that is sacrificed or exiled.
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
	var out: Array = []   # [inst, index, color, amount, rank, key, pain, holds]
	# Mana already floating (a resolved Dark Ritual) is a source that costs
	# nothing to "tap": a null instance the executors skip. Without it the
	# Ritual's {B}{B}{B} sat in the pool until the step ended and burned.
	var pool := game.players[pid].mana_pool
	for color in Mtg.ManaColor.values():
		for unit in pool.amount_of(color):
			out.append([null, unit, color, 1, 0, "", 0, 0])   # one unit per entry
	for key in pool._restricted:
		for color in pool._restricted[key]:
			for unit in int(pool._restricted[key][color]):
				out.append([null, unit, int(color), 1, 0, String(key), 0, 0])
	# The mana triggers that describe their bonus, read once per build
	# rather than once per row ([method _bonus_triggers]).
	var bonus_triggers := _bonus_triggers(game)
	var candidates: Array[CardInstance] = game.players[pid].battlefield + game.players[pid].hand
	# ACTIVATION BANS reach mana abilities (CR 605.1a — Null Rod's Mox,
	# Cursed Totem's Elves, City of Solitude's off-turn lands): a banned
	# source is no source, so no plan — the AI's or the human's auto-pay —
	# counts mana tap_for_mana would then refuse. One cheap gate per build.
	var bans := game.has_activation_bans()
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
		var tap_rank := _tap_rank(game, inst)
		for index in inst.cur_mana_abilities.size():
			var ability := game.mana_ability_for(pid, inst, index)
			var borrowed := inst.zone == Mtg.Zone.BATTLEFIELD and inst.controller_id != pid
			if borrowed and not game.may_tap_foreign_land(pid, inst, index): continue
			if not ability.object_costs.is_empty(): continue # not free, must be chosen explicitly
			# Lion's Eye Diamond is "activate only as an instant": never in
			# the middle of a payment, so never an auto-tapped source.
			if ability.instant_only: continue
			# "Activate only once each turn" (Wall of Roots), already used.
			if not game.mana_ability_ready(inst, index): continue
			# A put-a-counter cost (Wall of Roots' -0/-1) is planned only while
			# the counter leaves the source alive.
			if ability.put_counter_kind != "" and _counter_kills(inst, ability): continue
			if inst.zone != ability.activation_zone: continue
			if bans and game.activation_ban_reason(pid, inst, ability, true) != "": continue
			# Sacrificing a Swamp is never an implicit auto-tap. A player may
			# activate it explicitly; planners must not count its output free.
			if game.BLACK_SYMBOL_COST.amount(game, ability.cost) > 0: continue
			# Haste lifts summoning sickness for a {T} mana ability as for any
			# other (CR 302.6) — the gate MtgGame.tap_for_mana keeps; until
			# 2026-10-03 the planner skipped every sick creature regardless.
			if ability.taps_source and (inst.tapped or (inst.is_creature() and inst.summoning_sick
					and not inst.has_keyword(Mtg.Keyword.HASTE))):
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
					int(color_choice), amount, holds, mind_pain, borrowed,
					bonus_triggers, tap_rank)
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
	if pool.spend_as_any != 0 or pool.colorless_only != 0:
		out = _under_spending_rule(out, pool)
	# Sacrifices last, then a tap an Aura punishes, then a source that does
	# not untap; painful sources after painless; fewer options first; and
	# last of all, the source that is holding something back.
	out.sort_custom(cheapest_source_first)
	return out


## THE SEAT'S SPENDING RULE, read into the source list (Celestial Dawn —
## [member ManaPool.spend_as_any] / [member ManaPool.colorless_only]): a
## source whose mana may pay only generic is listed as {C}, and a source
## whose mana may pay any colour is listed once per colour — the way a
## dual land is listed once per ability, sharing its instance's key so a
## plan still taps it once ([method source_key]). The tap makes what it
## always made; the pool's own rule spends it ([method ManaPool.pay]).
## Floating mana keeps its colour: the pool already answers for it.
static func _under_spending_rule(src: Array, pool: ManaPool) -> Array:
	var out: Array = []
	for s in src:
		var color := int(s[2])
		if (color & pool.colorless_only) != 0 and color != Mtg.ManaColor.C:
			var generic_only: Array = s.duplicate()
			generic_only[2] = Mtg.ManaColor.C
			out.append(generic_only)
			continue
		out.append(s)
		if s[0] == null or (color & pool.spend_as_any) == 0 or s.size() > 8 \
				or source_chooses_color(s):
			continue
		for other in Mtg.WUBRG:
			if other != color:   # white pays a red pip even when red can't
				var any_row: Array = s.duplicate()
				any_row[2] = other
				out.append(any_row)
	return out


## Would paying [param ability]'s put-a-counter cost kill [param inst]
## (Wall of Roots' last -0/-1)? A P/T counter shrinks the live toughness;
## any other kind is harmless here.
static func _counter_kills(inst: CardInstance, ability: ManaAbility) -> bool:
	if not inst.is_creature():
		return false
	var delta := ContinuousEffects.parse_pt_counter(ability.put_counter_kind)
	var toughness_after := inst.cur_toughness + delta.y * maxi(1, ability.put_counter_count)
	return toughness_after <= 0 or toughness_after <= inst.damage


## The source row for one mana ability making [param color] — a plain
## row, or one with the converter/multi-output ninth entry (see
## [method sources]); `[]` when the ability is not one the planner models.
static func _source_row(game: MtgGame, pool: ManaPool, inst: CardInstance,
		index: int, ability: ManaAbility, color: int, amount: int, holds: int,
		mind_pain: bool, borrowed := false, bonus_triggers: Array = [],
		tap_rank := 0) -> Array:
	# Only public descriptors, never speculative callbacks or RNG.
	# Snowfall's restricted blue bonus is not ordinary island mana,
	# and High Tide still adds BLUE after Darkness recolors the land.
	var bonuses: Array = []
	if ability.taps_source and inst.is_land():
		for pair in bonus_triggers:
			var trigger: TriggeredAbility = pair[0]
			if not _bonus_reaches(trigger.mana_bonus_subtype, pair[1], inst): continue
			var restriction: String = trigger.mana_bonus_restriction
			if restriction == "cumulative_upkeep" and game.current_step() != Mtg.Step.UPKEEP: continue
			var bonus: int = trigger.mana_bonus_amount
			if (inst.cur_supertypes & Mtg.Supertype.SNOW) != 0: bonus += trigger.mana_bonus_snow_extra
			# Colour 0: "one mana of any type that land produced" (Mana
			# Flare) — the colour this row makes.
			var bonus_color: int = trigger.mana_bonus_color if trigger.mana_bonus_color != 0 else color
			if not borrowed and bonus_color == color and restriction == ability.restriction_key: amount += bonus
			else: bonuses.append([bonus_color, bonus, restriction])
	var rank := RANK_SPENDS_SOURCE if ability.sacrifice_source or ability.exile_source else 0
	if ability.taps_source:
		rank |= tap_rank
	var row: Array = [inst, index, color,
		amount, rank, ability.restriction_key,
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


# --- Campaign fix-mana: bonus mana, tap tolls, untap locks (2026-10-07) ---

## [member TriggeredAbility.mana_bonus_subtype] for a bonus on EVERY land
## tapped for mana — Mana Flare's "whenever a player taps a land for mana".
const BONUS_ANY_LAND := ""
## [member TriggeredAbility.mana_bonus_subtype] for a bonus on the land the
## trigger's own permanent ENCHANTS — Wild Growth's and Overgrowth's
## "whenever enchanted land is tapped for mana". Two words, so it can never
## be a land type.
const BONUS_ENCHANTED_LAND := "enchanted land"

## [method source_rank] bits: what tapping a source spends besides its mana.
## A source that does not untap (Mana Vault, Basalt Monolith, anything under
## a Meekstone- or Paralyze-style lock): the mana is had once.
const RANK_STAYS_TAPPED := 1
## A source wearing an Aura that punishes its tapping (Psychic Venom, Blight,
## Kudzu, Orcish Mine, Relic Bind, Seizures, a Stinging Licid).
const RANK_TAP_TOLL := 2
## A source that is sacrificed or exiled to make its mana (Black Lotus,
## Elvish Spirit Guide) — the planner's oldest "last".
const RANK_SPENDS_SOURCE := 4


## Every mana trigger on the battlefield (and every delayed one — High Tide)
## that DESCRIBES its bonus ([member TriggeredAbility.mana_bonus_amount]),
## as `[trigger, the permanent it is on or null]`: the planner counts that
## mana as part of the land's own tap. Before 2026-10-07 the description
## could name only a land TYPE and the land's own colour, so the bonus of a
## Mana Flare, a Wild Growth or a Gauntlet of Might was unknown to every
## plan: Hill Giant tapped four Mountains under a Flare, made eight red and
## the four left over burned (w1-1, a Deck Lab Wizard burned for 11 at 5
## life). [constant BONUS_ANY_LAND] and [constant BONUS_ENCHANTED_LAND]
## widen what the description can say, and colour 0 means "a mana of the
## type the land made" ([method _source_row]).
static func _bonus_triggers(game: MtgGame) -> Array:
	var out: Array = []
	for entry in game.delayed_triggers:
		var delayed: TriggeredAbility = entry.trigger
		if delayed.is_mana_trigger and delayed.mana_bonus_amount > 0:
			out.append([delayed, null])
	for permanent in game.all_battlefield():
		for trigger in permanent.cur_triggered_abilities:
			if not trigger.is_mana_trigger or trigger.mana_bonus_amount <= 0:
				continue
			# Lost all its abilities: a trigger granted AFTER that still
			# works, its printed ones never do — as the dispatcher reads it
			# (MtgGame.trigger_silenced, CR 613.7 / 613.8a).
			if permanent.cur_abilities_silenced and MtgGame.trigger_silenced(permanent, trigger):
				continue
			out.append([trigger, permanent])
	return out


## Does a bonus described for [param subtype] reach the land [param inst],
## the trigger being on [param source] (null for a delayed one)?
static func _bonus_reaches(subtype: String, source: CardInstance, inst: CardInstance) -> bool:
	if subtype == BONUS_ANY_LAND:
		return true
	if subtype == BONUS_ENCHANTED_LAND:
		return source != null and source.attached_to == inst.id
	return inst.has_subtype(subtype)


## The [method source_rank] bits a TAP of [param inst] costs, read once per
## instance: [constant RANK_STAYS_TAPPED] and [constant RANK_TAP_TOLL]
## (only a mana ability that taps the source pays them — [method _source_row]).
##
## THE TAP TOLL (w1-2): an attached Aura with a "becomes tapped" trigger —
## Psychic Venom's 2 damage, Blight's and Kudzu's destroyed land, Orcish
## Mine's ore counter, Relic Bind's ping, Seizures' {3}-or-3, Stinging
## Licid's 2. Every one of them hurts the permanent's controller, whoever
## controls the Aura (a Kudzu the victim passed back is its caster's own,
## and still eats the land), so the controller is not asked. Read as a
## SHAPE: the trigger's event, never the card. Until 2026-10-07 the planner
## tapped the Venomed Forest first while two plain Forests stood untapped,
## for the AI and for the human's double-click alike.
static func _tap_rank(game: MtgGame, inst: CardInstance) -> int:
	var rank := 0
	if inst.zone == Mtg.Zone.BATTLEFIELD and (inst.cur_skips_untap or inst.skip_next_untap
			or inst.skip_untaps > 0 or not inst.skip_untap_for.is_empty()):
		rank |= RANK_STAYS_TAPPED
	for id in inst.attachments:
		var aura := game.find_instance(id)
		if aura == null or aura.zone != Mtg.Zone.BATTLEFIELD or aura.attached_to != inst.id:
			continue
		for trigger in aura.cur_triggered_abilities:
			if trigger.is_mana_trigger or not trigger.listens(Mtg.EventType.BECAME_TAPPED):
				continue
			if aura.cur_abilities_silenced and MtgGame.trigger_silenced(aura, trigger):
				continue
			rank |= RANK_TAP_TOLL
			break
	return rank


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
	# Colored requirements first. Two colours or more are a MATCHING
	# ([method _cover_colored_matched]); one colour is the greedy pass, which
	# is already the best answer there — and the greedy pass stays the
	# fallback for anything the matching cannot place.
	var covered := cost.colored.size() > 1 \
		and _cover_colored_matched(src, cost, usage_keys, out, used_instances, pool_check)
	if not covered and not _cover_colored_greedy(src, cost, usage_keys, out,
			used_instances, pool_check):
		return []
	# Generic + X from whatever remains.
	var generic := cost.generic + x_value
	var floating := pool_check.total() - cost.mana_value() + cost.generic
	generic -= maxi(floating, 0)
	if not _cover_generic(src, generic, usage_keys, out, used_instances, cost.colored):
		return []
	_drop_surplus(out, used_instances, cost, x_value, usage_keys)
	return out


## THE GENERIC MANA, PAID WITH THE LEAST LEFT OVER (2026-10-07, w6-1).
## The pass this replaces took sources in [method sources]' order until the
## cost was covered, and the size of a source was no key of that order: a
## Sol Ring paid a one-drop beside an untapped Mountain, a Mana Vault paid an
## Icy Manipulator's {1} beside an Island and stayed tapped, and under mana
## burn (the 1997 rule — [member RulesOptions.mana_burn]) the rest burned:
## 392 life in 300 tournament-deck duels, a Millstone activation to 1 life.
##
## Floating mana goes first, unit by unit — it is in the pool whatever is
## tapped. Then each PERMANENT is one group (its rows are the ways it can
## tap; a permanent a coloured pip already took offers only its richer rows
## of that same colour, counted as the extra they make — THE SAME
## PERMANENT'S RICHER ROW of 2026-10-03: Crystal Vein's "{T}, Sacrifice:
## Add {C}{C}" beside its plain "{T}: Add {C}"). Tiers are climbed one at a
## time ([method _tier]: nothing spent, then a painful tap, then a source
## that stays tapped, a tolled one, a sacrifice), and the first tier whose
## sources can cover the cost is searched for the cover with the LEAST
## SURPLUS ([method _least_surplus]); among covers that leave as little,
## the one that takes the sources earliest in [method sources]' order.
## A permanent that can tap for several colours offers the colours of
## [param pips] first (the cost's own coloured pips): a Black Lotus paying
## the {1} of a {1}{U} makes blue, so [method _drop_surplus] can then let
## the Island that paid the {U} go.
## Appends to [param out] / [param used]; false when nothing covers it.
static func _cover_generic(src: Array, need: int, usage_keys: Array, out: Array,
		used: Dictionary, pips: Dictionary = {}) -> bool:
	for s in src:
		if need <= 0:
			return true
		if s[0] != null or used.has(source_key(s)) or not source_usable(s, usage_keys):
			continue
		out.append(step_of(s))
		used[source_key(s)] = s
		need -= int(s[3])
	if need <= 0:
		return true
	var groups: Array = []        # [key, [[amount, tier, row], ...], upgrade]
	var at: Dictionary = {}       # key -> index into groups
	var tiers: Dictionary = {}
	for s in src:
		if s[0] == null or not source_usable(s, usage_keys):
			continue
		var key := source_key(s)
		var amount: int = int(s[3])
		var upgrade := used.has(key)
		if upgrade:
			var was: Array = used[key]
			if int(s[2]) != int(was[2]) or amount <= int(was[3]):
				continue   # the pip it pays stays paid, in its own colour
			amount -= int(was[3])
		if not at.has(key):
			at[key] = groups.size()
			groups.append([key, [], upgrade])
		var tier := _tier(s)
		groups[int(at[key])][1].append([amount, tier, s])
		tiers[tier] = true
	for group in groups:
		group[1] = _pip_colours_first(group[1], pips)
	var ladder: Array = tiers.keys()
	ladder.sort()
	for top in ladder:
		var picked := _least_surplus(groups, need, int(top))
		if picked.is_empty():
			continue
		for choice in picked:
			var group: Array = groups[int(choice[0])]
			var row: Array = choice[1][2]
			var key: String = group[0]
			if bool(group[2]):
				var old_step := step_of(used[key])
				for i in out.size():
					if out[i] == old_step:
						out[i] = step_of(row)
						break
			else:
				out.append(step_of(row))
			used[key] = row
		return true
	return false


## One permanent's [param options] (`[amount, tier, row]`, in
## [method sources]' order) with, inside each tier, the rows making a
## colour of [param pips] before the rest; stable otherwise.
static func _pip_colours_first(options: Array, pips: Dictionary) -> Array:
	if options.size() < 2 or pips.is_empty():
		return options
	var out: Array = []
	var placed: Dictionary = {}
	var tiers: Array = []
	for option in options:
		if not tiers.has(int(option[1])):
			tiers.append(int(option[1]))
	tiers.sort()
	for tier in tiers:
		for wanted in [true, false]:
			for i in options.size():
				var option: Array = options[i]
				if placed.has(i) or int(option[1]) != tier \
						or pips.has(int(option[2][2])) != wanted:
					continue
				placed[i] = true
				out.append(option)
	return out


## The least-surplus cover of [param need] from [param groups] (see
## [method _cover_generic]), using only options of tier [param top] or
## better: `[[group index, option], ...]`, or `[]` when they cannot reach
## [param need]. A subset sum over the groups — at most one option each —
## bounded by `need + the biggest option - 1`, since a cover past that
## still covers with any one source dropped. The walk back takes a group
## whenever the rest can still make the target, so the earliest sources are
## the ones spent.
static func _least_surplus(groups: Array, need: int, top: int) -> Array:
	var options: Array = []       # per group: its options at or under `top`
	var total := 0
	var biggest := 1
	for group in groups:
		var mine: Array = []
		var best := 0
		for option in group[1]:
			if int(option[1]) <= top:
				mine.append(option)
				best = maxi(best, int(option[0]))
		options.append(mine)
		total += best
		biggest = maxi(biggest, best)
	if total < need:
		return []
	var cap := need + biggest - 1
	var n := groups.size()
	var reach: Array[PackedByteArray] = []   # reach[i][s]: groups i.. make exactly s
	reach.resize(n + 1)
	var tail := PackedByteArray()
	tail.resize(cap + 1)
	tail.fill(0)
	tail[0] = 1
	reach[n] = tail
	for i in range(n - 1, -1, -1):
		var after: PackedByteArray = reach[i + 1]
		var here: PackedByteArray = after.duplicate()
		for option in options[i]:
			var a: int = int(option[0])
			for sum in range(cap - a, -1, -1):
				if after[sum] == 1:
					here[sum + a] = 1
		reach[i] = here
	var target := -1
	for sum in range(need, cap + 1):
		if reach[0][sum] == 1:
			target = sum
			break
	if target < 0:
		return []
	var picked: Array = []
	var left := target
	for i in n:
		if left == 0:
			break
		for option in options[i]:
			var a: int = int(option[0])
			if a <= left and reach[i + 1][left - a] == 1:
				picked.append([i, option])
				left -= a
				break
	return picked


## THE TAP THE PLAN DID NOT NEED (2026-10-07). The coloured pips are covered
## before the generic, so a source that makes MORE than one mana of a
## colour (a Forest under Wild Growth makes {G}{G}) can arrive after a plain
## Forest already took the {G} — and then pay the {1} alone, with the plain
## Forest's mana left over. While the plan makes more than [param cost]
## asks, drop the step whose mana the rest can do without — the worst tier
## first, then the biggest — checked against [method ManaPool.can_pay], the
## payment's own rule. Floating mana is never dropped: it is in the pool.
static func _drop_surplus(out: Array, used: Dictionary, cost: ManaCost,
		x_value: int, usage_keys: Array) -> void:
	var due := cost.mana_value() - cost.generic + maxi(0, cost.generic + x_value)
	while true:
		var made := 0
		for key in used:
			made += int(used[key][3])
		var surplus := made - due
		if surplus <= 0:
			return
		var candidates: Array = []   # [tier, amount, position, key]
		for key in used:
			var row: Array = used[key]
			if row[0] == null or int(row[3]) > surplus:
				continue
			candidates.append([_tier(row), int(row[3]), out.find(step_of(row)), key])
		candidates.sort_custom(_worst_first)
		var dropped := false
		for candidate in candidates:
			var key: String = candidate[3]
			if _rows_pay(used, key, cost, x_value, usage_keys):
				out.erase(step_of(used[key]))
				used.erase(key)
				dropped = true
				break
		if not dropped:
			return


## [method _drop_surplus]'s order: the worse tier, then the bigger source,
## then the later step.
static func _worst_first(a: Array, b: Array) -> bool:
	for k in 3:
		if int(a[k]) != int(b[k]):
			return int(a[k]) > int(b[k])
	return false


## Would the rows of [param used], all but [param skip], pay [param cost]?
static func _rows_pay(used: Dictionary, skip: String, cost: ManaCost,
		x_value: int, usage_keys: Array) -> bool:
	var pool := ManaPool.new()
	for key in used:
		if key == skip:
			continue
		var row: Array = used[key]
		if String(row[5]) == "":
			pool.add(int(row[2]), int(row[3]))
		else:
			pool.add_restricted(int(row[2]), int(row[3]), String(row[5]))
	return pool.can_pay(cost, x_value, usage_keys)


## Trade the row [param used] holds for [param key] for the richer row
## [param s] of the same permanent, in place in the plan [param out]:
## the extra mana it makes, or 0 when [param s] is no better (or would
## change the colour of a row a coloured pip counts on — [param any_color]
## false). One tap either way: a permanent's mana abilities share its {T}.
static func _upgrade_row(out: Array, used: Dictionary, key: String, s: Array,
		any_color: bool) -> int:
	var old: Variant = used.get(key)
	if not (old is Array) or s[0] == null:
		return 0
	var was: Array = old
	if int(s[3]) <= int(was[3]) or (not any_color and int(s[2]) != int(was[2])):
		return 0
	var old_step := step_of(was)
	for i in out.size():
		if out[i] == old_step:
			out[i] = step_of(s)
			used[key] = s
			return int(s[3]) - int(was[3])
	return 0


## The coloured pips the planner always had: each takes the first unused
## source of its colour in [method sources]' order, and a source that makes
## several of a colour covers several pips. Appends to [param out] /
## [param used] / [param pool_check]; false when a pip finds nothing.
static func _cover_colored_greedy(src: Array, cost: ManaCost, usage_keys: Array,
		out: Array, used: Dictionary, pool_check: ManaPool) -> bool:
	for color in cost.colored:
		for _n in cost.colored[color]:
			var short := int(cost.colored[color]) - pool_check.amount_of(color)
			if short <= 0:
				break   # one charged source can cover several coloured pips
			# The first source of the colour — unless one of the SAME tier
			# ([method _tier]) further on makes no more than the pips still
			# ask: a plain Forest pays {G} before a Forest under Wild Growth
			# (2026-10-07, w6-1's coloured half).
			var pick: Array = []
			for s in src:
				if used.has(source_key(s)) or s[2] != color \
						or not source_usable(s, usage_keys):
					continue
				if pick.is_empty():
					pick = s
					if int(s[3]) <= short:
						break
				elif _tier(s) != _tier(pick):
					break
				elif int(s[3]) <= short:
					pick = s
					break
			var found := not pick.is_empty()
			if found:
				out.append(step_of(pick))
				used[source_key(pick)] = pick
				pool_check.add(pick[2], pick[3])
			if not found:
				# No untouched source left: a taken permanent may still
				# make MORE of this colour on another of its rows (a
				# "{T}, Sacrifice: Add {G}{G}" beside its "{T}: Add {G}" —
				# see _plan_free_sources). Same colour only.
				for s in src:
					if s[2] != color or not source_usable(s, usage_keys) \
							or not used.has(source_key(s)):
						continue
					var extra := _upgrade_row(out, used, source_key(s), s, false)
					if extra > 0:
						pool_check.add(color, extra)
						found = true
						break
			if not found:
				return false
	return true


## THE COLOURED PIPS AS A MATCHING (2026-10-03). The greedy pass never went
## back: an Underground Sea beside a Volcanic Island spent the Sea on {U}
## and then found no {B}, so `{U}{B}` was refused while `{B}{U}` was paid,
## and a Tundra + Scrubland refused `{W}{U}` — and every payment question
## rides on the planner (`MtgGame.can_afford_cost`, `try_pay` for an
## "unless you pay" or an upkeep cost, the auto-cast, the castable
## highlight, the AI's casts). Each pip is a slot, each source a vertex that
## taps once, and the slots are filled by augmenting paths — the house
## pattern of `BlackSymbolCost._match`.
##
## THE PREFERENCE IS KEPT BY THE ORDER THE SOURCES ARE OFFERED IN. Sources
## join one at a time in [method sources]' order (basic before dual,
## painless before painful, sacrifice last, the tie-break last of all), and
## a source is kept only when the matching can grow with it — the greedy
## rule over a transversal matroid, which picks the EARLIEST set of sources
## that covers the pips. So the matching only ever re-routes a dual; it
## never reaches past a basic, or onto a City of Brass, that a painless
## re-route would have spared — the case the greedy pass got wrong whenever
## the Sea happened to sort before the Volcanic.
##
## A source that makes several of one colour covers that many pips of THAT
## colour (one tap, one colour); a path re-routes such a source one pip at
## a time, so a charged source that would have to change colour wholesale
## is not found here — the greedy pass behind it is the fallback. Appends
## to [param out] / [param used] / [param pool_check] only on success.
static func _cover_colored_matched(src: Array, cost: ManaCost, usage_keys: Array,
		out: Array, used: Dictionary, pool_check: ManaPool) -> bool:
	var slot_color: Array[int] = []   # one slot per pip, in the cost's own order
	for color in cost.colored:
		for _n in int(cost.colored[color]):
			slot_color.append(int(color))
	var order: Array[String] = []     # source keys, cheapest first
	var rows: Dictionary = {}         # key -> {colour: the first row making it}
	for s in src:
		if not cost.colored.has(int(s[2])) or not source_usable(s, usage_keys):
			continue
		var key := source_key(s)
		if not rows.has(key):
			rows[key] = {}
			order.append(key)
		if not rows[key].has(int(s[2])):
			rows[key][int(s[2])] = s
	order = _fitting_first(order, rows, cost)
	var owner: Array[String] = []     # slot -> source key, "" while open
	owner.resize(slot_color.size())
	var held: Dictionary = {}         # source key -> [colour, pips covered]
	var open := slot_color.size()
	for key in order:
		while open > 0 and _augment(key, slot_color, rows, owner, held, {}, {}):
			open -= 1
		if open == 0:
			break
	if open > 0:
		return false
	for slot in slot_color.size():
		if used.has(owner[slot]):
			continue
		var s: Array = rows[owner[slot]][slot_color[slot]]
		out.append(step_of(s))
		used[owner[slot]] = s   # the row, so the generic pass may enrich it
		pool_check.add(s[2], s[3])
	return true


## [param order] (source keys in [method sources]' order) with, inside each
## [method _tier], the sources that make no more of a colour than the cost
## has pips of it before the ones that make more (2026-10-07) — the
## matching's half of [method _cover_colored_greedy]'s rule. Stable
## otherwise, so the preference the order carries is kept.
static func _fitting_first(order: Array[String], rows: Dictionary,
		cost: ManaCost) -> Array[String]:
	var buckets: Dictionary = {}   # tier -> [fitting keys, the rest]
	for key in order:
		var mine: Dictionary = rows[key]
		var tier := -1
		var fits := true
		for color in mine:
			var s: Array = mine[color]
			tier = _tier(s) if tier < 0 else mini(tier, _tier(s))
			if int(s[3]) > int(cost.colored.get(color, 0)):
				fits = false
		if not buckets.has(tier):
			buckets[tier] = [[], []]
		buckets[tier][0 if fits else 1].append(key)
	var tiers: Array = buckets.keys()
	tiers.sort()
	var out: Array[String] = []
	for tier in tiers:
		for part in buckets[tier]:
			for key in part:
				out.append(String(key))
	return out


## One augmenting path from source [param key] to an open slot, re-routing
## the slots' holders on the way ([method _cover_colored_matched]).
## [param visited] is per slot, [param busy] the sources on the path now —
## a source re-routes once per path, so a charged source's colour lock can
## never be broken behind its back.
static func _augment(key: String, slot_color: Array[int], rows: Dictionary,
		owner: Array[String], held: Dictionary, visited: Dictionary,
		busy: Dictionary) -> bool:
	var mine: Dictionary = rows[key]
	busy[key] = true
	for slot in slot_color.size():
		var color := slot_color[slot]
		if visited.has(slot) or owner[slot] == key or not mine.has(color):
			continue
		var h: Array = held.get(key, [0, 0])
		if h[1] > 0 and (h[0] != color or h[1] >= int(mine[color][3])):
			continue   # one tap makes one colour, and only so much of it
		var rival := owner[slot]
		if rival != "" and busy.has(rival):
			continue
		visited[slot] = true
		if rival != "":
			held[rival][1] -= 1   # the rival lets go while it looks elsewhere
			owner[slot] = ""
			if not _augment(rival, slot_color, rows, owner, held, visited, busy):
				held[rival] = [color, held[rival][1] + 1]
				owner[slot] = rival
				continue
		held[key] = [color, h[1] + 1]
		owner[slot] = key
		busy.erase(key)
		return true
	busy.erase(key)
	return false


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
##
## THE FIRST KEY IS NOW A RANK (2026-10-07, [method source_rank]): the
## sacrifice is still last of all, and below it, in that order, a source an
## Aura punishes for tapping and a source that does not untap — a Mana
## Vault is spent after a City of Brass, and a Venomed Forest after both.
static func cheapest_source_first(a: Array, b: Array) -> bool:
	var rank_a := source_rank(a)
	var rank_b := source_rank(b)
	if rank_a != rank_b:
		return rank_a < rank_b
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


## What a source row's activation spends besides its mana, as the
## RANK_* bits ([constant RANK_SPENDS_SOURCE], [constant RANK_TAP_TOLL],
## [constant RANK_STAYS_TAPPED]); 0 for a Forest and for floating mana.
static func source_rank(s: Array) -> int:
	return int(s[4]) if s.size() > 4 else 0


## The TIER a plan reaches for a source in: [method source_rank], then
## painless before painful — the two keys of [method cheapest_source_first]
## that a plan never trades away to save mana. Within one tier the plan
## pays with the least left over ([method _cover_generic]).
static func _tier(s: Array) -> int:
	return source_rank(s) * 2 + (1 if source_pain(s) > 0 else 0)


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
##
## THE BILL (2026-10-07, w1-1): given the [param bill] the plan was made
## for ([param extra] generic on top, [param usage_keys] as in
## [method plan_from]), the run STOPS TAPPING ONCE THE POOL COVERS IT and
## reports true. A mana trigger the plan did not count — a Mana Flare, a
## Wild Growth with no bonus description — makes mana the plan never
## priced, and every tap after the pool already covered the cost made only
## mana to burn: Hill Giant tapped four Mountains under a Flare and floated
## four red. Without a bill every step runs, as before.
##
## [param settled] — a caller whose bill can be PAID WHILE THE PLAN RUNS:
## the duel screen submits a waiting cast from its refresh the moment a tap
## makes the pool cover it ([method DuelScreen._retry_payment]), so the
## pool is empty again before the next step and the bill no longer
## describes anything owed. True from it stops the run the same way.
static func run_plan(game: MtgGame, pid: int, tap_plan: Array,
		bill: ManaCost = null, extra := 0, usage_keys: Array = [],
		settled := Callable()) -> bool:
	for step in tap_plan:
		if bill != null and game.players[pid].mana_pool.can_pay(bill, extra, usage_keys):
			return true
		if settled.is_valid() and bool(settled.call()):
			return true
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
	run_plan(game, pid, tap_plan, cost, extra, usage_keys)
	return game.players[pid].mana_pool.can_pay(cost, extra, usage_keys)


## The largest X [param pid] could pay for. [param src]: a pre-built source
## list; pass one when the caller already has it — this loop plans a cost
## once per candidate X.
##
## The 1997 rule for the auto-cast's X is this number and nothing else:
## *"If you double-click to auto-cast an X spell, ALL of the mana you have
## available in your pool and from land sources will be put into that
## spell"* (`Duel.hlp`, topic **Hands**; topic **Spells** says it again).
## ALL of it includes a described mana trigger's bonus (2026-10-07): a
## Fireball under a Mana Flare is counted with the Flare's mana, which the
## rows' amounts carry ([method _bonus_triggers]).
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
