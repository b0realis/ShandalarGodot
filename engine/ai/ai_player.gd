class_name AiPlayer
extends DecisionAgent
## The AI opponent: drives one seat entirely through MtgGame's PUBLIC API —
## the same calls the human's clicks make — and answers that seat's
## DecisionAgent choices. Pure engine code: no Node, no UI, headless.
##
## Architecture (mage-go's heuristic layer, adapted — see its
## interactive/ai/heuristic for the reference: creature evaluation,
## favorable-trade combat logic, and an adaptive posture read off a
## position score):
## - [method act] performs ONE action per call and returns a short
##   description ("" = nothing to do / passed). The UI calls it on a
##   pacing timer so humans can watch; tests loop it to play whole games.
## - Decisions are GREEDY-HEURISTIC v1: no lookahead. The upgrade path —
##   game cloning + the minimax in mage-go's search/ package — plugs in
##   behind this same act() surface (docs/ROADMAP.md, M4 phase 3).
## - Difficulty lives ENTIRELY in AiProfile: mistake injection degrades
##   chosen actions; aggression tilts combat risk. All randomness uses
##   game.rng — a seeded game with AI seats replays identically.
##
## What it does (2026-09-02, the card-capabilities pass — every item has a
## test in tests/ai/test_ai_capabilities.gd): reads every spell and
## activated ability through [EffectIntent] and scores it by what it DOES,
## so a Rod of Ruin, an Icy Manipulator, a Jayemdae Tome or an Orcish
## Artillery is used without a special case (`_try_activate`, three
## moments: our main, their upkeep, their end step as the mana sink);
## sizes X to the job (`_size_x_burn`); casts a sweeper only when the
## board it clears beats ours (`_sweep_value`); casts Dark Ritual only for
## a spell it enables; HOLDS removal, draw and tricks for their combat and
## their end step and reserves the mana for them (`_held_reserve`,
## `_fire_held_instant`); reads first strike, regeneration shields and
## trample into every combat question (`_dies_to`,
## `_damage_through_blocks`) on both sides of the table; and picks the
## land drop by the colour the hand is short of. The ATTACK is chosen as
## a GROUP (`_choose_attack_cohort`, 2026-09-04): the per-creature risk
## read is the floor, then the bodies it rejected are offered back and
## the longest prefix whose whole-group exchange pays is kept, so one
## blocker no longer blanks a team it can only eat one of.
##
## Known limits (each documented where it bites): it never plans a
## multi-step line; there is no search or cloning, so every decision is a
## one-ply heuristic — a Disenchant is aimed by permanent value, not by
## what the enchantment does to the game, and a tutor fetches by card
## value alone. Instant-speed responses (counterspells, Fog, removal on
## attackers and on blockers) and attack BANDS are implemented — see
## `_respond_action` and the band grouping in `_declare_attacks` — as are
## the two 1997 DAMAGE WINDOWS when the fork is on (`_window_action`,
## §6.8). The upgrade path (cloning + minimax behind the same act()) is
## M4.x in the roadmap.

var pid: int
var profile: AiProfile

## THE REFUSAL MEMO. The planner taps its lands BEFORE the engine gives
## its final answer, so a cast or activation the engine refuses for a
## reason the planner did not mirror leaves mana floating — and a second
## priority pass in the same step used to plan, tap and lose it again.
## What was refused is remembered for the rest of the step (keyed
## "<instance id>" for a spell, "<instance id>:<ability index>" for an
## ability) and skipped by the ranking loops. Transient by design: wiped
## at the top of [method act] when the turn or step changes, never
## consulted by the engine, and a Dictionary — which a GameSnapshot
## copies — so a search that unwinds the seat cannot see it stale.
var _refused: Dictionary = {}
var _refused_stamp: String = ""


func _init(p_pid: int, p_profile: AiProfile = null) -> void:
	pid = p_pid
	profile = p_profile if p_profile != null else AiProfile.sorcerer()


# ================================================================== driving --

## Perform one action if any part of the game is waiting on this seat.
## Returns what happened for logs/UI ("" when it wasn't our moment).
func act(game: MtgGame) -> String:
	if game.game_over:
		return ""
	var stamp := "%d:%d" % [game.turn_number, game.current_step()]
	if stamp != _refused_stamp:
		_refused_stamp = stamp
		_refused.clear()
	if game.awaiting_attackers and game.active_player == pid:
		return _declare_attacks(game)
	if game.awaiting_blockers and game.opponent_of(game.active_player) == pid:
		return _declare_blocks(game)
	if game.awaiting_attackers or game.awaiting_blockers:
		return ""
	if game.priority_player != pid:
		return ""
	# THE TWO 1997 DAMAGE WINDOWS (§6.8). Answered first, because while one
	# is open it is the ONLY thing this seat may legally do.
	if game.awaiting_damage_prevention or game.awaiting_regeneration:
		var answered := _window_action(game)
		if answered != "":
			return answered
		# `@PROMPT_ENDHEALING` (`promptsX1.txt:1`) — the original's own verb
		# for leaving the step.
		game.end_damage_prevention(pid)
		return "ends damage prevention"
	# Sorcery-speed development in our own main with an empty stack...
	if game.active_player == pid and Mtg.is_main_step(game.current_step()) \
			and game.stack.is_empty():
		var did := _main_phase_action(game)
		if did != "":
			return did
	# ...and PHASE 2: instant-speed responses everywhere else — counters,
	# Fog, removal on attackers, combat tricks, firebreathing.
	elif profile.holds_instants:
		var response := _respond_action(game)
		if response != "":
			return response
	game.pass_priority(pid)
	return "pass"


## Test/soak convenience: alternate both AIs until the game ends.
static func play_out(game: MtgGame, ai0: AiPlayer, ai1: AiPlayer,
		max_steps := 20000) -> bool:
	for _i in max_steps:
		if game.game_over:
			return true
		if ai0.act(game) == "" and ai1.act(game) == "" and not game.game_over:
			# Neither seat had anything to do — should be impossible while
			# the game runs; bail rather than spin.
			push_error("AiPlayer.play_out: stalled at %s, turn %d" % [
				Mtg.step_name(game.current_step()), game.turn_number])
			return false
	return game.game_over


# ============================================================== main phase --

func _main_phase_action(game: MtgGame) -> String:
	if _try_play_land(game):
		return "played a land"
	# Mistake injection: a fumbled turn just stops developing (the classic
	# weak-AI look) — rolled once per potential cast.
	if profile.mistake_chance > 0.0 \
			and game.rng.randf() < profile.mistake_chance:
		return ""
	var cast := _try_cast_best(game)
	if cast != "":
		return cast
	return _try_activate(game)


## Play the land whose colour the hand is shortest of — mage-go's
## `chooseBestLand` (`heuristic.go`, "land that produces the most needed
## colour"). Ties keep hand order, so a seeded duel replays the same.
func _try_play_land(game: MtgGame) -> bool:
	var me := game.players[pid]
	if me.lands_played_this_turn >= 1:
		return false
	var shortfall := _colour_shortfall(game)
	var best: CardInstance = null
	var best_score := -1.0
	for inst in me.hand:
		if not inst.is_land():
			continue
		var score := 0.0
		for ability in inst.data.mana_abilities:
			for pair in ability.produces:
				score = maxf(score, float(shortfall.get(int(pair[0]), 0)))
		if inst.data.mana_abilities.is_empty():
			score = -0.5   # a land that makes no mana (Maze of Ith) comes last
		if score > best_score:
			best = inst
			best_score = score
	if best == null:
		return false
	return game.play_land(pid, best) == ""


## Per colour: pips the hand's spells want beyond what our lands make.
## The want is the deepest single card (a {B}{B} card wants two Swamps,
## not one Swamp per black card).
func _colour_shortfall(game: MtgGame) -> Dictionary:
	var me := game.players[pid]
	var want: Dictionary = {}
	for inst in me.hand:
		if inst.is_land():
			continue
		for color in inst.data.cost.colored:
			want[color] = maxi(int(want.get(color, 0)), int(inst.data.cost.colored[color]))
	var have: Dictionary = {}
	for inst in me.battlefield:
		for ability in inst.cur_mana_abilities:
			for pair in ability.produces:
				have[int(pair[0])] = int(have.get(int(pair[0]), 0)) + 1
	var out: Dictionary = {}
	for color in want:
		out[color] = maxi(int(want[color]) - int(have.get(color, 0)), 0)
	return out


## Short of lands: fewer on the battlefield than the hand's biggest spell
## needs, or fewer than a working four.
func _land_light(game: MtgGame) -> bool:
	var me := game.players[pid]
	var lands := 0
	for inst in me.battlefield:
		if inst.is_land():
			lands += 1
	if lands < 4:
		return true
	for inst in me.hand:
		if not inst.is_land() and inst.data.cost.mana_value() > lands:
			return true
	return false


## Rank castable hand cards by value and cast the best one.
func _try_cast_best(game: MtgGame) -> String:
	var best: CardInstance = null
	var best_value := 0.0
	var best_targets: Array = []
	var best_x := 0
	var best_mode := 0
	# Nothing in this ranking loop taps a land, so the available mana
	# sources are the same for every candidate: build them once.
	var sources := _mana_sources(game)
	# Mana kept open for the held instant that has a job tonight (mage-go's
	# `canCastWhileReserving`, `heuristic.go`): a sorcery-speed cast that
	# would tap us out of it must be worth half again as much.
	var reserve := _held_reserve(game)
	for inst in game.players[pid].hand:
		if inst.is_land():
			continue
		if _is_reactive(inst.data):
			continue   # counterspells/Fog wait for the response framework
		if _refused.has(str(inst.id)):
			continue   # refused this step already — do not tap for it twice
		if _cast_gate(game, inst) != "":
			continue   # locked, banned, or "Cast this spell only ..." — not now
		if not _sacrifice_fodder_ok(game, inst):
			continue   # "As an additional cost, sacrifice ..." with nothing worth giving
		# Cost modifiers (Gloom) are part of the real price — plan them in,
		# or the cast bounces off the engine and the AI stalls.
		var surcharge := game.spell_surcharge(pid, inst.data)
		# Restricted mana (Mishra's Workshop) pays only for what its key
		# names — the same answer the engine's pool gives.
		var keys: Array = game.mana_usage_keys(inst.data)
		var plan := _plan_taps_from(sources, inst.data.cost, surcharge, keys)
		if plan.is_empty() and not (_cost_is_free(inst.data.cost) and surcharge == 0):
			continue
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		var max_x := 0
		if inst.data.cost.has_x:
			max_x = _max_affordable_x(game, inst.data.cost, surcharge, sources,
				inst.data.x_color, keys)
			if max_x <= 0:
				continue
		# A held instant waits for its moment (their combat, their end
		# step) — unless it wins the game right now.
		if _is_held_instant(inst, intent) \
				and not _lethal_burn(game, intent, max_x):
			continue
		# Dark Ritual is worth exactly what it lets us cast this turn.
		if intent.adds_mana and not _mana_spell_enables(game, inst, sources):
			continue
		var mode := _pick_mode(game, inst.data)
		var sized := _size_and_aim(game, inst, intent, max_x, mode)   # {} = wait
		if sized.is_empty():
			continue
		var x: int = sized["x"]
		var targets: Array = sized["targets"]
		var value: float = sized["value"]
		if not reserve.is_empty() and value < float(reserve["value"]) * 1.5 \
				and _plan_taps_from(sources, _combined_cost(inst.data.cost_for(x), reserve["cost"]),
					_generic_x(inst.data, x) + surcharge).is_empty():
			continue
		# Phase 2: hold counterspell mana open. A marginal main-phase cast
		# that would tap us below {U}{U} while we hold a counter waits.
		if profile.holds_instants and value < 6.0 \
				and _holding_counter(game) and _blue_after_plan(game, plan) < 2:
			continue
		# THE PLAN IS PUT TO THE ENGINE BEFORE A LAND IS TAPPED. Everything
		# above mirrors a rule; this asks the rule itself, with the FINAL
		# X, the player filter, the arity a rolled slot demands and the
		# divided arithmetic. Anything the mirror missed used to be paid
		# for and then refused, and the floating mana emptied at the next
		# step boundary (docs/ROADMAP.md, the dead-card sweep's class 4).
		if game.cast_refusal(pid, inst, targets, x, mode) != "":
			continue
		if value > best_value:
			best = inst
			best_value = value
			best_targets = targets
			best_x = x
			best_mode = mode
	if best == null:
		return ""
	var plan := _plan_taps(game, best.data.cost_for(best_x),
		_generic_x(best.data, best_x) + game.spell_surcharge(pid, best.data),
		game.mana_usage_keys(best.data))
	for step in plan:
		if step[0] != null:   # floating mana is already in the pool
			game.tap_for_mana(pid, step[0], step[1])
	var err := game.cast_spell(pid, best, best_targets, best_x, best_mode)
	if err != "":
		if _wait_out(game, best):
			return "holds %s until the stack clears" % best.data.card_name
		# A plan/engine disagreement is an AI bug worth hearing about, but
		# never worth crashing a duel: log, remember, fall through to pass.
		game.log_line("(AI cast of %s refused: %s)" % [best.data.card_name, err])
		_refused[str(best.id)] = true
		return ""
	return "cast %s" % best.data.card_name


## THE REFUSAL THE PLANNER CAN WAIT OUT — and the whole reason the memo
## needs to tell one from the other (docs/ROADMAP.md, "The tap-trigger
## refusal", 2026-09-05).
##
## `cast_refusal` cleared this exact cast a few lines above, with the
## stack EMPTY, because [method act] only reaches the main-phase planner
## with an empty stack. So if the stack is no longer empty the only thing
## that can have filled it is OUR OWN TAPS: a tap-triggered ability —
## Manabarbs, Psychic Venom, Blight — went on the stack in the middle of
## paying, and CR 601.2a's sorcery timing then refuses the spell it was
## being paid for. Nothing about the DECISION was wrong and nothing about
## it will be wrong one priority round from now: the mana stays in the
## pool until the step ends (CR 500.4), the trigger resolves, and the
## same cast is made from the floating mana without tapping a second
## land ([method ManaPlanner.sources] sorts the pool first, so the retry
## has nothing left to tap for).
##
## Memoing it is what threw the turn away — 1,143 of the 1,271 refused
## casts in the X-seam pass's 258-deck census, and every one of them cost
## the AI both the card and the life the trigger charged for it.
##
## STRUCTURAL, not a string match: the test is "did the stack fill up
## while we were paying", which is a fact about the game rather than
## about the wording of a message, and it cannot mistake a refusal that
## really does stand — a retry with an empty stack IS memoed, because
## this returns false there.
func _wait_out(game: MtgGame, inst: CardInstance) -> bool:
	if game.stack.is_empty():
		return false
	game.log_line("(AI holds %s: the stack filled up while it was paying)"
		% inst.data.card_name)
	return true


## The engine's own pre-cast gates the planner can read WITHOUT paying:
## the hand lock (Firestorm Phoenix), the play ban (City in a Bottle) and
## the "Cast this spell only ..." rider (Reset, Teleport). "" when
## [param inst] may be cast now, else the refusal the engine would give.
## Before the 2026-09-02 sweep the first two were not mirrored, and the
## lands were tapped for a cast the engine then bounced.
func _cast_gate(game: MtgGame, inst: CardInstance) -> String:
	var why := game.hand_lock_reason(inst)
	if why != "":
		return why
	why = game.play_banned(pid, inst.data)
	if why != "":
		return why
	if inst.data.cast_condition.is_valid():
		return String(inst.data.cast_condition.call(game, pid))
	return ""


## "As an additional cost to cast this spell, sacrifice a creature"
## (Sacrifice, Metamorphosis): castable only with a body to give — the
## engine refuses otherwise, after the taps — and worth casting only when
## the CHEAPEST such body is worth no more than the card it buys.
func _sacrifice_fodder_ok(game: MtgGame, inst: CardInstance) -> bool:
	if inst.data.additional_sacrifice.is_empty():
		return true
	var want: Dictionary = inst.data.additional_sacrifice
	var cheapest := -1.0
	for perm in game.players[pid].battlefield:
		if not bool(want["filter"].call(perm)):
			continue
		var worth := Evaluator.permanent_value(perm)
		if cheapest < 0.0 or worth < cheapest:
			cheapest = worth
	return cheapest >= 0.0 and cheapest <= Evaluator.card_value(inst.data)


## The held instant with a job right now — removal for a creature of
## theirs worth a card, a draw into a thin hand — as `{cost, value}`, or
## `{}` when nothing in hand is waiting for anything.
func _held_reserve(game: MtgGame) -> Dictionary:
	if not profile.holds_instants:
		return {}
	var me := game.players[pid]
	var out: Dictionary = {}
	for inst in me.hand:
		if not inst.is_type(Mtg.CardType.INSTANT):
			continue
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if not _is_held_instant(inst, intent) or intent.pumps:
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # what cannot be cast tonight reserves nothing
		if intent.self_damage >= me.life:
			continue   # _fire_held_instant would never fire it either
		var value := 0.0
		if intent.draws > 0:
			value = 3.0 + _draw_need(me.hand.size())
		elif intent.answers_creatures():
			var victim := _best_victim(game, inst, intent, 0)
			if victim != null:
				var worth := Evaluator.permanent_value(victim)
				if worth >= 3.0 and not (intent.bounces and not intent.removes
						and intent.damage == 0 and worth < 6.0):
					value = worth + 1.0
		# The recoil (a spell that hurts us too) is part of the price, the
		# way _ability_option charges it: dear when life is short.
		if intent.self_damage > 0:
			value -= intent.self_damage * (0.5 if me.life > 12 else (1.0 if me.life > 6 else 2.0))
		if value > float(out.get("value", 0.0)):
			out = {"cost": inst.data.cost, "value": value}
	# A COUNTERSPELL RESERVES TOO, though it is not a "held instant".
	#
	# [method _is_held_instant] excludes anything that counters, and it is
	# right to: a held instant is one [method _fire_held_instant] may cast
	# at the opponent's end step, and a counterspell fired at an empty
	# stack is a card thrown away. But the two questions are different —
	# "would I cast this unprompted?" and "must the mana still be there
	# when the moment comes?" — and the reserve was only ever asking the
	# first. So the AI would tap out over a Counterspell for any creature
	# worth casting, and the counter it was holding could not be paid for
	# (found 2026-09-06 by asking it to choose between a Counterspell and
	# a 3/3 flier: it cast the flier).
	#
	# ITS VALUE IS THE THRESHOLD IT ANSWERS AT. We cannot know what the
	# opponent will cast, but we know what this AI would bother countering
	# — [member AiProfile.counter_threshold] — so that is what the open
	# mana is worth. The 1.5x rule in [method _try_cast_best] then does
	# the rest: something clearly better than the thing we would counter
	# still gets cast.
	if profile.holds_instants:
		for inst in me.hand:
			if not _is_counterspell(inst.data):
				continue
			if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
				continue
			if profile.counter_threshold > float(out.get("value", 0.0)):
				out = {"cost": inst.data.cost, "value": profile.counter_threshold}
	return out


## The GENERIC mana a spell's X adds at [param x_value]: X per printed
## {X}, or nothing when the card pays X in colour ([member CardData.x_color]
## — CardData.cost_for has spelled those pips out already).
static func _generic_x(data: CardData, x_value: int) -> int:
	if data.x_color != 0:
		return 0
	return x_value * data.cost.x_count


## One cost that pays for both — the planner's way of asking "can we
## afford [param a] and still have [param b] open?".
static func _combined_cost(a: ManaCost, b: ManaCost) -> ManaCost:
	var out := ManaCost.new()
	out.generic = a.generic + b.generic
	out.text = "%s+%s" % [a.text, b.text]
	for c in a.colored:
		out.colored[c] = int(out.colored.get(c, 0)) + int(a.colored[c])
	for c in b.colored:
		out.colored[c] = int(out.colored.get(c, 0)) + int(b.colored[c])
	return out


# ===================================================== activated abilities --
#
# One scorer for every activated ability, by what its effects DO — the
# port of mage-go's `considerAbilityActivation` / `intrinsicAbilityQuality`
# (`heuristic.go:1074-1232`): an ability is read into an [EffectIntent],
# given targets the way the spell picker gives them, and priced in the
# same stat points [Evaluator] uses. Three MOMENTS ask the scorer, and the
# moment sets the bar:
#
#  * MAIN — our own main phase, after the casts: quality >= 3 fires, which
#    is mage-go's own threshold. A Tome with a thin hand, a Rod at a X/1,
#    a Disk against a board that beats ours.
#  * UPKEEP — the opponent's upkeep, tap effects only: an Icy Manipulator
#    on their best creature HERE keeps it tapped through their turn (no
#    attack) and ours (no block), the classic play. Quality >= 2.
#  * SINK — the opponent's end step, the last moment before our untap:
#    every point of mana still open is about to be wasted, so anything
#    with positive value fires (a Rod ping at the face, a Tome draw). This
#    is the "unused mana at the end of the opponent's turn" pass.
#
# Costs the planner cannot model (discard/exile riders) are skipped, as
# they always were; a life cost is priced, not skipped, and since
# 2026-09-06 so is a SACRIFICE ([method _sacrifice_price]) — for the
# profiles that [member AiProfile.pays_sacrifices] says may pay one.

const ABILITY_BAR_MAIN := 3.0
const ABILITY_BAR_UPKEEP := 2.0
const ABILITY_BAR_SINK := 0.5

enum Moment { MAIN, UPKEEP, SINK }


## Activate the best-scoring ability that clears the bar for [param moment],
## or "" when nothing does. One activation per call, like every other action.
func _try_activate(game: MtgGame, moment: int = Moment.MAIN) -> String:
	var bar: float = ABILITY_BAR_MAIN
	if moment == Moment.UPKEEP:
		bar = ABILITY_BAR_UPKEEP
	elif moment == Moment.SINK:
		bar = ABILITY_BAR_SINK
	var best: Dictionary = {}
	var sources := _mana_sources(game)
	# Mana kept open for the held instant with a job tonight — the same
	# reserve _try_cast_best keeps (mage-go's `canCastWhileReserving`). At
	# the mana sink the instant has had its moment, and every open point
	# is about to be lost anyway.
	var reserve: Dictionary = {} if moment == Moment.SINK else _held_reserve(game)
	for inst in game.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _ability_available(game, inst, index, true):
				continue
			var surcharge := game.ability_surcharge(pid, inst)
			if not (_cost_is_free(ability.cost) and surcharge == 0) \
					and _plan_taps_from(sources, ability.cost, surcharge).is_empty() \
					and not game.players[pid].mana_pool.can_pay(ability.cost, surcharge):
				continue
			var option := _ability_option(game, inst, index, moment)
			if not option.is_empty() and profile.minds_pain:
				# THE LIFE THE TAPS COST. A Rod ping at their end step is
				# "mana about to be wasted" only from a Mountain; from a
				# City of Brass it is a life, and a life is not wasted by
				# untapping. Priced as the reaper's own recoil is
				# ([method _life_price]): a Tome draw pays it at any life
				# above the last, a ping for a life is no trade at all.
				var pain := ManaPlanner.plan_pain(sources,
					_plan_taps_from(sources, ability.cost, surcharge))
				if pain > 0:
					option["value"] = float(option["value"]) \
						- pain * _life_price(game.players[pid].life)
			# AN ARM MAY STATE ITS OWN BAR. The moment's bar asks "is this
			# worth the mana a SPELL might want"; an ability with no other
			# moment to be used at is not competing with a spell, because
			# `_try_cast_best` has already declined every card in hand by
			# the time this runs. Such an arm answers with the sink bar,
			# for the sink's own stated reason — mana that would otherwise
			# be lost (see [method _animation_value]).
			if option.is_empty() \
					or float(option["value"]) < float(option.get("bar", bar)):
				continue
			if not reserve.is_empty() and float(option["value"]) < float(reserve["value"]) * 1.5 \
					and _plan_taps_from(sources,
						_combined_cost(ability.cost, reserve["cost"]), surcharge).is_empty():
				continue   # a Tome draw that taps us out of the Terror waits
			if best.is_empty() or float(option["value"]) > float(best["value"]):
				best = option
	if best.is_empty():
		return ""
	var source: CardInstance = best["inst"]
	var ability: ActivatedAbility = source.cur_activated_abilities[int(best["index"])]
	var paid := _pay_without_source(game, source, ability) \
		if bool(best.get("keep_source_untapped", false)) \
		else _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, source))
	if not paid:
		return ""
	var err := game.activate_ability(pid, source, int(best["index"]), best["targets"])
	if err != "":
		game.log_line("(AI activation of %s refused: %s)" % [source.data.card_name, err])
		_refused["%d:%d" % [source.id, int(best["index"])]] = true
		return ""
	return "activated %s" % source.data.card_name


## The cheap half of [method MtgGame.activate_ability]'s legality check —
## everything that can be known without paying. Mirrors the engine's order
## so a refusal never costs a tapped land.
##
## [param priced_sacrifice]: the caller PRICES a sacrifice rider — charges
## the body that goes against the effect it buys — and may therefore see
## an ability the other callers may not. Only [method _try_activate]
## does, through [method _sacrifice_price]; every other path (the combat
## pump, the shield, the attack-time pump) reads an ability's effect and
## not its cost, and for those a pump whose price is a BODY (Fallen
## Angel, Atog) must stay invisible or it eats the board one Serra at a
## time — which is what it did before the gate existed.
func _ability_available(game: MtgGame, inst: CardInstance, index: int,
		priced_sacrifice := false) -> bool:
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	if ability.only_opponents_may_activate:
		return false
	if ability.only_owner_may_activate and inst.owner_id != pid:
		return false   # Personal Incarnation answers to its OWNER (a stolen one refuses)
	if _refused.has("%d:%d" % [inst.id, index]):
		return false   # refused this step already — do not pay for it twice
	if ability.cost.has_x:
		return false   # X abilities: no sizing model yet (none in the starter decks)
	# A SACRIFICE IS A PRICE, NOT A REFUSAL (2026-09-06). Until this
	# landed every sacrifice rider was refused here outright, and 2,733
	# battlefield-turns of Strip Mine produced zero activations — the
	# last big dead card in the control sweep's list. The cost is the
	# body; [method _sacrifice_price] says what the body is worth, and
	# the scorer's bar says whether the effect is worth more. Gated by
	# [member AiProfile.pays_sacrifices] like every other capability.
	# "Sacrifice any number" (Sword of the Ages) is a different question
	# — one optional ask per body — and stays outside the model.
	var sacrifices := ability.sacrifice_cost or ability.sacrifice_filter.is_valid()
	if sacrifices:
		if not priced_sacrifice or not profile.pays_sacrifices \
				or ability.sacrifice_any_number:
			return false
		if ability.sacrifice_filter.is_valid() \
				and _sacrifice_fodder(game, inst, ability) == null:
			return false   # the engine would refuse it AFTER the mana was paid
	# Cost riders the mana planner does not model.
	if ability.exile_cost or ability.exile_filter.is_valid() \
			or ability.graveyard_exile_filter.is_valid() \
			or ability.random_discard_cost or ability.discard_cost > 0 \
			or ability.counter_cost_kind != "":
		return false
	if ability.discard_last_drawn_cost:
		# "Discard the last card you drew this turn" (Jandor's Ring) names
		# ONE card: none drawn, or drawn and gone, and the engine refuses.
		var drawn: Array = game.players[pid].drawn_this_turn
		if drawn.is_empty() or not game.players[pid].hand.has(drawn[-1]):
			return false
	# An ability that costs NOTHING the turn can run out of — no tap, no
	# mana, no life, no per-turn cap — scores the same after every
	# activation, and the one-action-per-call loop would fire it forever
	# at the mana sink. Cards whose free abilities matter (Personal
	# Incarnation's redirect, Dream Coat) are card-local; the general
	# scorer leaves them to their moment.
	if not ability.tap_cost and ability.cost.mana_value() == 0 \
			and ability.life_cost <= 0 and ability.max_per_turn <= 0 \
			and not sacrifices:   # a body is a thing the turn runs out of
		return false
	if ability.life_cost > 0 and game.players[pid].life - ability.life_cost <= 3:
		return false   # never pay life down to the last few points
	if ability.tap_cost and (inst.tapped
			or (inst.is_creature() and inst.summoning_sick
				and not inst.has_keyword(Mtg.Keyword.HASTE))):
		return false
	var step := game.current_step()
	if ability.only_during_combat and not Mtg.is_combat_step(step):
		return false
	if ability.only_during_step >= 0 and step != ability.only_during_step:
		return false
	if ability.only_before_step >= 0 \
			and Mtg.STEP_ORDER.find(step) >= Mtg.STEP_ORDER.find(ability.only_before_step):
		return false
	if ability.turn_restriction > 0 and pid != game.active_player:
		return false
	if ability.turn_restriction < 0 and pid == game.active_player:
		return false
	if ability.max_per_turn > 0 \
			and int(inst.ability_uses.get(index, 0)) >= ability.max_per_turn:
		return false
	if ability.activation_condition.is_valid() \
			and ability.activation_condition.call(game, inst) != "":
		return false
	return true


## Score one ability for [param moment]: `{inst, index, targets, value}`,
## or `{}` when it has no worthwhile use right now. The numbers are
## mage-go's `intrinsicAbilityQuality` scale (draw 5, damage 4, tap 4,
## lifegain 3...) adjusted by hand size, life cost and mana price the way
## `cardDrawNeedAdjustment` and `lifeCost*15/life` adjust them.
func _ability_option(game: MtgGame, inst: CardInstance, index: int, moment: int) -> Dictionary:
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var intent := EffectIntent.read(ability.effects, inst.data.card_name)
	var me := game.players[pid]
	var opponent := game.opponent_of(pid)
	var them := game.players[opponent]
	var value := 0.0
	var targets: Array = []
	# The bar this option answers to, or -1.0 for "the moment's own".
	var own_bar := -1.0
	# Whether the ability must be paid for WITHOUT tapping its own source.
	var keep_source_untapped := false
	# Mana is the price of everything else this turn: a point per mana
	# above the first, halved — a 4-mana Tome draw still clears the bar with
	# a thin hand, a 3-mana Rod ping at the face does not.
	var price: float = maxf(ability.cost.mana_value() - 1, 0) * 0.5
	if intent.self_damage > 0:
		if intent.self_damage >= me.life:
			return {}
		price += intent.self_damage * _life_price(me.life)
	if intent.damage > 0 and intent.target_spec != null:
		# Kill the best creature it can; failing that, the face.
		var victim := _best_victim(game, inst, intent, 0)
		if victim != null:
			value = Evaluator.permanent_value(victim) + 1.0
			targets = [TargetRef.card(victim)]
		elif _spec_allows_player(intent.target_spec, game, inst, opponent):
			targets = [TargetRef.player(opponent)]
			if intent.damage >= them.life:
				value = LETHAL_WORTH
			else:
				# A recoil that costs more than it deals (Orcish Artillery:
				# 2 to them, 3 to us) is a race we lose — a creature is
				# what that gun waits for, unless they are in burn range.
				if intent.self_damage > intent.damage and them.life > intent.damage * 3:
					return {}
				value = intent.damage * 0.75
				if them.life <= intent.damage * 3:
					value += 2.0   # burn range: every point counts now
				if moment == Moment.SINK:
					value += 1.0   # mana that would otherwise be lost
		else:
			return {}
	elif intent.taps and intent.target_spec != null:
		if moment == Moment.SINK:
			return {}   # it untaps before it matters
		var mark := _best_tap_victim(game, inst, intent.target_spec)
		if mark == null:
			return {}
		targets = [TargetRef.card(mark)]
		if mark.is_creature():
			# At their upkeep the tap holds through both turns; on our own
			# turn it only clears a blocker, and only if we mean to attack.
			if moment == Moment.UPKEEP:
				value = Evaluator.permanent_value(mark) * 0.6 + 1.0
			elif game.current_step() == Mtg.Step.MAIN1 and _has_attackers(game):
				value = Evaluator.permanent_value(mark) * 0.4 + 1.0
			else:
				return {}
		else:
			value = 1.0 if moment == Moment.UPKEEP else 0.0
	elif intent.removes and intent.target_spec != null:
		var victim := _best_victim(game, inst, intent, 0)
		if victim == null:
			return {}
		targets = [TargetRef.card(victim)]
		value = _victim_value(game, victim) + 1.0
	elif intent.draws > 0 and intent.target_spec == null:
		if me.library.size() <= intent.draws:
			return {}
		value = 5.0 if ability.cost.mana_value() <= 2 else 3.0
		value += _draw_need(me.hand.size())
		if ability.life_cost > 0:
			value -= ability.life_cost * 15.0 / maxf(me.life, 1.0)
		if moment == Moment.SINK:
			value += 1.0
	elif intent.life_gain > 0 and intent.target_spec == null:
		value = 1.0 + (2.0 if me.life <= 10 else 0.0)
	elif intent.sweeper != null:
		value = _sweep_value(game, intent.sweeper, 0)
	elif intent.animates != null and profile.plays_engines:
		# THE CLOCK A PERMANENT CAN BECOME (2026-09-06, the control sweep).
		value = _animation_value(game, inst, intent.animates, moment)
		if value <= 0.0:
			return {}
		if not _animation_payable(game, inst, ability):
			return {}
		own_bar = ABILITY_BAR_SINK
		keep_source_untapped = true
	elif intent.discards != 0 and profile.plays_engines \
			and intent.target_spec != null:
		# THE REPEATABLE DISCARD (2026-09-06, the control sweep). Weissman
		# named the principle this arm encodes: "taking cards away from
		# your opponent is card advantage just as much as drawing cards of
		# your own" — and a Disrupting Scepter that ticks a card off the
		# hand every turn is the whole soft lock The Deck wins with. In
		# 100 instrumented games the AI had one on the battlefield 1,706
		# times and activated it ZERO times, because the scorer had no arm
		# for an effect whose payoff is a card the opponent no longer has.
		if them.hand.is_empty():
			return {}   # nothing to take
		if not _spec_allows_player(intent.target_spec, game, inst, opponent):
			return {}
		targets = [TargetRef.player(opponent)]
		# A card denied is a card, priced on this function's own scale for
		# one (the draw arm's 5.0 cheap / 3.0 dear). The last cards in a
		# hand are worth more than the first: that is the difference
		# between a plan and a topdeck.
		value = 3.0
		if them.hand.size() <= 2:
			value += 1.0
		# "Activate only during your turn" (the Scepter's own rider) means
		# there is no later moment to spend this mana at — the same
		# argument the animation makes, so the same bar.
		if ability.turn_restriction > 0:
			own_bar = ABILITY_BAR_SINK
	else:
		return {}   # pumps, regeneration, mana, untaps, unknowns: not here
	var sacrifice := _sacrifice_price(game, inst, ability)
	if sacrifice > 0.0:
		# A BODY IS NOT MANA ABOUT TO BE LOST. The sink's low bar is for
		# mana the untap step would waste; a Strip Mine costs the same
		# land at their end step as in our main phase, so a sacrifice
		# rider answers to the main bar at every moment — the sink must
		# not turn "trade my Mine for their fourth Plains" into a bargain.
		own_bar = maxf(own_bar, ABILITY_BAR_MAIN)
	price += sacrifice
	value -= price
	var out := {"inst": inst, "index": index, "targets": targets, "value": value}
	if own_bar >= 0.0:
		out["bar"] = own_bar
	if keep_source_untapped:
		out["keep_source_untapped"] = true
	return out


## CAN THE ANIMATION BE PAID FOR WITHOUT TAPPING THE THING IT ANIMATES?
##
## The one seam an animation has that no other ability has: the permanent
## being animated is itself a MANA SOURCE, and [ManaPlanner] sorts the
## least flexible source first — so a Mishra's Factory, which makes
## exactly one colour, is the first land the planner reaches for and it
## would happily tap the Factory to pay for the Factory's own animation.
## The body that comes out of that cannot attack and cannot block (CR
## 508.1a, 509.1a both want an untapped creature), so the {1} buys
## nothing at all. Asked BEFORE the option is offered, so an animation
## that can only be paid for this way is simply not one of the choices.
func _animation_payable(game: MtgGame, inst: CardInstance,
		ability: ActivatedAbility) -> bool:
	var surcharge := game.ability_surcharge(pid, inst)
	if _cost_is_free(ability.cost) and surcharge == 0:
		return true
	var excluded := _pain_excluded(game)
	excluded[inst.id] = true
	return not _plan_taps_from(ManaPlanner.sources(game, pid, excluded,
		profile.minds_pain), ability.cost, surcharge).is_empty()


## Pay [param ability]'s cost from everything EXCEPT [param inst] itself.
## See [method _animation_payable] for why that exception exists.
func _pay_without_source(game: MtgGame, inst: CardInstance,
		ability: ActivatedAbility) -> bool:
	var surcharge := game.ability_surcharge(pid, inst)
	if _cost_is_free(ability.cost) and surcharge == 0:
		return true
	var excluded := _pain_excluded(game)
	excluded[inst.id] = true
	var plan := _plan_taps_from(ManaPlanner.sources(game, pid, excluded,
		profile.minds_pain), ability.cost, surcharge)
	if plan.is_empty():
		return false
	ManaPlanner.run_plan(game, pid, plan)
	return true


## WHAT A PERMANENT THAT BECOMES A CREATURE IS WORTH THIS TURN.
##
## THE WIN CONDITION THIS AI COULD NOT SEE. Every other arm of
## [method _ability_option] prices an ability by the board it changes;
## an animation changes nothing until the attack it enables, so the
## reader had no model for it and [method _ability_option] fell through
## to its final `return {}`. In 100 instrumented games of Weissman's The
## Deck the AI put a Mishra's Factory on the battlefield 2,339 times and
## animated one ZERO times — and since that list runs no other threat,
## a deck of fifty-nine answers had literally no way to end a game it
## had already stabilised (docs/ROADMAP.md, "the control sweep").
##
## Priced as the ATTACK it enables, in the currency the attack code
## already uses ([method _face_damage_value]), so the ability scorer and
## [method _declare_attacks] agree about the same swing. The refusals are
## the interesting half:
##
##  * ALREADY A CREATURE — the animation is until end of turn and has no
##    per-turn cap, so without this the mana sink would re-animate the
##    same Factory every priority round for as long as the mana lasted.
##  * NOT OUR PRECOMBAT MAIN, TAPPED, OR SUMMONING SICK — the three ways
##    a body cannot swing this turn (CR 302.6 is the famous Factory judge
##    call: a land played this turn may animate and may not attack).
##  * A BLOCKER THAT EATS IT. What animates here is almost always a LAND,
##    and a land traded for nothing is a mana source the control deck
##    needed. So the body goes only when the damage actually arrives:
##    every untapped creature they could block with has to die to it
##    without killing it back. That is also Weissman's own order of
##    operations — clear the board first, attack with the Factory
##    afterwards — arrived at from the numbers rather than written in.
func _animation_value(game: MtgGame, inst: CardInstance,
		anim: AnimateSelfEffect, moment: int) -> float:
	if inst.is_creature():
		return 0.0
	if (anim.add_types & Mtg.CardType.CREATURE) == 0 or anim.set_power <= 0:
		return 0.0
	if moment != Moment.MAIN or game.active_player != pid \
			or game.current_step() != Mtg.Step.MAIN1 \
			or inst.tapped or inst.summoning_sick:
		return 0.0
	var defender := game.opponent_of(pid)
	for blocker in game.players[defender].battlefield:
		if not blocker.is_creature() or blocker.tapped:
			continue
		if blocker.cur_power >= anim.set_toughness \
				or anim.set_power < blocker.cur_toughness:
			return 0.0   # it survives the block, or kills us for free
	return _face_damage_value(game, anim.set_power, defender)


## mage-go's `cardDrawNeedAdjustment`: a thin hand wants cards, a full one
## would discard them.
func _draw_need(hand_size: int) -> float:
	if hand_size <= 2:
		return 2.0
	if hand_size <= 4:
		return 1.0
	if hand_size >= 9:
		return -4.0
	if hand_size >= 7:
		return -3.0
	return 0.0


## The most valuable enemy creature [param intent] would actually finish
## at X = [param x_value], legal for the spec, or null.
##
## A creature is "finished" by damage or removal; a LAND, an artifact or
## an enchantment only by removal — damage does nothing to a Tundra — so
## those are shopped only when [member EffectIntent.removes] is set, and
## priced by [method _victim_value], which is what lets a Strip Mine pick
## the dual over the basic and a Scavenger Folk the Disk over the Ring.
func _best_victim(game: MtgGame, source: CardInstance, intent: EffectIntent,
		x_value: int) -> CardInstance:
	var best: CardInstance = null
	var best_value := 0.0
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.is_creature():
			if not intent.kills(inst, x_value):
				continue
		elif not (intent.removes or intent.bounces):
			continue
		if inst.cur_indestructible and intent.removes:
			continue
		if not intent.target_spec.is_legal(game, TargetRef.card(inst), source):
			continue
		var value := _victim_value(game, inst)
		if value > best_value:
			best = inst
			best_value = value
	return best


## What taking [param inst] off the OPPONENT's board is worth: a
## creature by its live stats ([method Evaluator.permanent_value]), a land
## by what it does for them ([method Evaluator.land_value]), and any other
## permanent by its cost, plus a point when it has an activated ability —
## an Icy Manipulator or a Jayemdae Tome is on the table to be USED, and
## the ability is the reason to take it.
func _victim_value(game: MtgGame, inst: CardInstance) -> float:
	if inst.is_creature():
		return Evaluator.permanent_value(inst)
	if inst.is_land():
		return Evaluator.land_value(game, inst)
	var value := Evaluator.permanent_value(inst)
	if not inst.cur_activated_abilities.is_empty():
		value += 1.0
	return value


## What giving up [param inst] of OUR OWN costs — the other side of the
## same ledger. A land counts the lands still in hand (information a seat
## may use about itself) and, when losing it would leave the hand's
## biggest spell uncastable even after every land in hand is played,
## carries a surcharge: that is a source we cannot spare, whatever it
## buys. [param as_source] prices a permanent whose OWN ability is being
## paid for — a Strip Mine's strip is the thing being bought, not a
## reason to keep the Mine.
func _own_value(game: MtgGame, inst: CardInstance, as_source := false) -> float:
	if not inst.is_land():
		return Evaluator.permanent_value(inst)
	var me := game.players[pid]
	var in_hand := 0
	var biggest := 0
	for card in me.hand:
		if card.is_land():
			in_hand += 1
		else:
			biggest = maxi(biggest, card.data.cost.mana_value())
	var on_table := 0
	for perm in me.battlefield:
		if perm.is_land():
			on_table += 1
	var value := Evaluator.land_value(game, inst, in_hand)
	if as_source and not inst.cur_activated_abilities.is_empty():
		value -= 1.5   # the ability's bonus, which is what we are spending
	if on_table - 1 + in_hand < biggest:
		value += 2.0
	return value


## The body a "sacrifice a <desc>" rider would eat: the least valuable
## permanent of ours the filter accepts — the same list the engine
## builds ([method MtgGame.activate_ability]) and the same choice
## [method answer_card] makes when the cost is actually asked, so the
## price the scorer charges is the body that goes. Null = no legal body.
func _sacrifice_fodder(game: MtgGame, inst: CardInstance,
		ability: ActivatedAbility) -> CardInstance:
	var best: CardInstance = null
	var best_value := 0.0
	for perm in game.players[pid].battlefield:
		if perm == inst and not ability.sacrifice_may_be_source:
			continue
		if not ability.sacrifice_filter.call(perm):
			continue
		var value := _own_value(game, perm)
		if best == null or value < best_value:
			best = perm
			best_value = value
	return best


## What [param ability]'s sacrifice riders cost in board: the source
## itself for "Sacrifice this", the cheapest legal body for "Sacrifice a
## <desc>", both on [method _own_value]'s scale. Zero for an ability with
## no such rider, which is nearly all of them.
func _sacrifice_price(game: MtgGame, inst: CardInstance,
		ability: ActivatedAbility) -> float:
	var price := 0.0
	if ability.sacrifice_cost:
		price += _own_value(game, inst, true)
	if ability.sacrifice_filter.is_valid():
		var fodder := _sacrifice_fodder(game, inst, ability)
		if fodder == null:
			return INF
		price += _own_value(game, fodder)
	return price


## The reaper's price for a point of our own life: cheap at 20, dear
## under 8. What an ability's recoil (Orcish Artillery) and the life its
## taps cost (City of Brass) are both charged at.
func _life_price(life: int) -> float:
	return 0.5 if life > 12 else (1.0 if life > 6 else 2.0)


## What to hold down with a tap ability: their best untapped creature,
## else their best mana artifact (a Sol Ring at their upkeep costs them the
## turn's spare mana).
func _best_tap_victim(game: MtgGame, source: CardInstance, spec: TargetSpec) -> CardInstance:
	var best: CardInstance = null
	var best_value := 0.0
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.tapped or inst.is_land():
			continue
		if not spec.is_legal(game, TargetRef.card(inst), source):
			continue
		var value := 0.0
		if inst.is_creature():
			value = Evaluator.permanent_value(inst)
		elif not inst.cur_mana_abilities.is_empty():
			value = 0.5
		if value > best_value:
			best = inst
			best_value = value
	return best


func _spec_allows_player(spec: TargetSpec, game: MtgGame, source: CardInstance,
		player_id: int) -> bool:
	return spec.is_legal(game, TargetRef.player(player_id), source)


## Do we have a creature that could attack this turn?
func _has_attackers(game: MtgGame) -> bool:
	var defender := game.opponent_of(pid)
	for inst in game.players[pid].battlefield:
		if inst.is_creature() and inst.cur_power > 0 \
				and CombatState.attack_illegality(game, inst, defender) == "":
			return true
	return false


## Net worth of resolving a sweeper right now at X = [param x_value] —
## what dies on their side minus what dies on ours, life included for the
## Earthquake shapes, with a lethal sweep priced like any other lethal and
## a suicidal one refused. The board wipe in a creature deck's own hand
## (White Knights' Wrath of God) is the case this exists for: it used to be
## cast the turn it was affordable, whatever was on the table.
func _sweep_value(game: MtgGame, effect: EffectBase, x_value: int) -> float:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var swing := 0.0
	if effect is DestroyAllEffect:
		for inst in game.all_battlefield():
			var hit: bool = effect.filter.call(inst) if effect.filter.is_valid() \
				else inst.is_creature()
			if not hit or inst.cur_indestructible:
				continue
			if effect.can_regenerate and inst.regeneration_shields > 0:
				continue
			var worth := Evaluator.permanent_value(inst)
			swing += -worth if inst.controller_id == pid else worth
		return swing * Evaluator.W_BOARD
	if effect is DamageAllEffect:
		var n: int = x_value if effect.use_x else effect.amount
		if n <= 0:
			return 0.0
		for inst in game.all_battlefield():
			if not inst.is_creature():
				continue
			if effect.creature_filter.is_valid() and not effect.creature_filter.call(inst):
				continue
			if inst.damage + n < inst.cur_toughness:
				continue
			var worth := Evaluator.permanent_value(inst)
			swing += -worth if inst.controller_id == pid else worth
		swing *= Evaluator.W_BOARD
		if effect.hit_players:
			if n >= me.life:
				return -LETHAL_WORTH   # never
			if n >= them.life:
				return LETHAL_WORTH
			swing += n * Evaluator.W_LIFE           # their life
			# Our life is dearer the lower we are.
			var life_price := 1.0 if me.life - n > 10 else 2.0
			swing -= n * life_price
		return swing
	return 0.0


func _board_value(game: MtgGame, of_pid: int) -> float:
	var total := 0.0
	for inst in game.players[of_pid].battlefield:
		if not inst.is_land():
			total += Evaluator.permanent_value(inst)
	return total


func _holding_counter(game: MtgGame) -> bool:
	for inst in game.players[pid].hand:
		if _has_effect(inst.data, "CounterEffect"):
			return true
	return false


## Untapped blue-capable sources that a candidate tap plan would leave us.
func _blue_after_plan(game: MtgGame, plan: Array) -> int:
	var planned_ids: Array[int] = []
	for step in plan:
		if step[0] != null:
			planned_ids.append(step[0].id)
	var blue := 0
	for inst in game.players[pid].battlefield:
		if inst.tapped or planned_ids.has(inst.id):
			continue
		# LIVE abilities (cur_mana_abilities), as the planner reads them: a
		# Blood Mooned Island makes {R}, whatever its printed list says.
		for ability in inst.cur_mana_abilities:
			if ability.produces[0][0] == Mtg.ManaColor.U:
				blue += 1
				break
	return blue


## Worth of resolving this cast right now: base card value; X spells scale
## with the X actually paid; removal pointed at an enemy adds a share of
## the victim's worth (a Terror on a Serra outranks a fresh Gray Ogre).
func _cast_value(game: MtgGame, inst: CardInstance, targets: Array, x_value: int) -> float:
	var value := _card_value(inst.data)
	if inst.data.cost.has_x:
		value = maxf(value, float(x_value) * 1.5)
	for t in targets:
		if t is TargetRef and not t.is_player:
			var victim := game.find_instance(t.instance_id)
			if victim != null and victim.controller_id != pid:
				value += Evaluator.permanent_value(victim) * 0.5
	return value


## The worth of a card in hand, with the pool's `*/*` CREATURES priced by
## what they cost rather than by a printed power and toughness they do not
## have.
##
## [method Evaluator.card_value] reads the PRINTED numbers, and a creature
## whose size comes from a static ability prints as 0/0 — Clone, Keldon
## Warlord, Plague Rats, Shapeshifter, Vesuvan Doppelganger, Gaea's Liege,
## Dakkon Blackblade, Wood Elemental, Necropolis and the three `0/*` Walls,
## twelve cards in all. Their value came out at exactly 0.0 (or NEGATIVE,
## for a Wall: Defender is priced at -1.0), and [method _try_cast_best]
## keeps the best card found with `value > best_value` from a floor of
## 0.0 — so not one of them could ever become the best card in hand, and
## none had ever been cast in a logged game.
##
## The mana value is the honest stand-in: we do not know how big it will
## be, but we know what it cost.
func _card_value(data: CardData) -> float:
	var value := Evaluator.card_value(data)
	if data.is_creature() and value <= 0.0:
		return maxf(data.cost.mana_value() + 1.0, 2.5)
	return value


## A sweeper is cast when the swing clears this (a 2/2's worth of board).
const SWEEP_BAR := 3.0


## Size X and aim the spell: `{x, targets, value}`, or `{}` to wait. The
## port of mage-go's `bestXValue` (`heuristic.go:365-500`): lethal to the
## face when X reaches their life, exactly the toughness of the best
## creature otherwise, a sweeper at the X with the best board swing, and a
## draw-X never for one card.
func _size_and_aim(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		max_x: int, mode: int) -> Dictionary:
	var data := inst.data
	if intent.sweeper != null and not data.is_modal():
		var best_x := 0
		var best_value := 0.0
		if data.cost.has_x:
			for x in range(1, max_x + 1):
				var swing := _sweep_value(game, intent.sweeper, x)
				if swing > best_value:
					best_value = swing
					best_x = x
		else:
			best_value = _sweep_value(game, intent.sweeper, 0)
		if best_value < SWEEP_BAR:
			return {}
		return {"x": best_x, "targets": [], "value": best_value}
	if intent.damage_uses_x and intent.target_spec != null and not data.is_modal():
		return _size_x_burn(game, inst, intent, max_x)
	# A tap is worth nothing by itself: it has a POLICY, not a value.
	if intent.is_tap_utility() and not data.is_modal():
		return _size_tap(game, inst, intent, max_x, mode)
	if intent.draws_use_x and max_x < 2 and game.players[pid].hand.size() > 1:
		return {}   # Braingeyser for one is a bad Ancestral
	# A SPELL WHOSE TARGETS MOVE WITH ITS X has to be sized to the thing it
	# wants, not to the mana it has: a Detonate for 6 may not name a Sol
	# Ring at all (CR 115.4). Try each affordable X on — cheapest first, so
	# a tie is settled by the cheaper cast — and keep the best aim.
	if _targets_depend_on_x(inst.data, mode):
		var best_x := -1
		var best_targets: Array = []
		var best_value := 0.0
		for x in range(0, max_x + 1):
			var aim = _choose_targets(game, inst, x, mode)   # Array or null
			if aim == null:
				continue
			var worth := _cast_value(game, inst, aim, x)
			if worth > best_value:
				best_x = x
				best_targets = aim
				best_value = worth
		if best_x < 0:
			return {}
		return {"x": best_x, "targets": best_targets, "value": best_value}
	var targets = _choose_targets(game, inst, max_x, mode)   # Array or null
	if targets == null:
		return {}
	return {"x": max_x, "targets": targets, "value": _cast_value(game, inst, targets, max_x)}


## Does this card's TARGETING move with its X? "Target artifact with mana
## value X" (Detonate), "target spell with mana value X" (Spell Blast): a
## spec that reads its own source cannot be judged until an X is chosen,
## so the planner has to try one on ([method MtgGame.target_legal_at]).
static func _targets_depend_on_x(data: CardData, mode := 0) -> bool:
	if not data.cost.has_x:
		return false
	var effects: Array = data.spell_effects
	if data.is_modal():
		effects = data.modes[clampi(mode, 0, data.modes.size() - 1)]["effects"]
	for e in effects:
		if e.target_spec != null and e.target_spec.source_filter.is_valid():
			return true
	return false


## The cheapest X, up to [param max_x], at which [param ref] is a legal
## target for [param spec] — or -1 when none is. What a spell sized to the
## thing it answers needs (Spell Blast for exactly the mana value on the
## stack).
func _x_that_makes_legal(game: MtgGame, source: CardInstance, spec: TargetSpec,
		ref: TargetRef, max_x: int) -> int:
	for x in range(0, max_x + 1):
		if game.target_legal_at(spec, ref, source, x):
			return x
	return -1


## X burn: the face when lethal; the best creature at exactly the X it
## takes; the face again when they are within two of these; else wait —
## a Fireball for 2 at a Bears on turn six is a Fireball wasted.
func _size_x_burn(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		max_x: int) -> Dictionary:
	var opponent := game.opponent_of(pid)
	var them := game.players[opponent]
	var face_ok := game.target_legal_at(intent.target_spec,
		TargetRef.player(opponent), inst, max_x)
	if face_ok and intent.damage_at(max_x) >= them.life:
		return {"x": maxi(them.life - intent.damage, 1),
			"targets": [TargetRef.player(opponent)], "value": LETHAL_WORTH}
	var victim := _best_victim(game, inst, intent, max_x)
	if victim != null:
		var worth := Evaluator.permanent_value(victim)
		if worth >= 3.0:
			var need: int = victim.cur_toughness - victim.damage - intent.damage
			return {"x": clampi(need, 1, max_x), "targets": [TargetRef.card(victim)],
				"value": worth + 1.0}
	if face_ok and max_x >= 4 and them.life <= intent.damage_at(max_x) * 2:
		return {"x": max_x, "targets": [TargetRef.player(opponent)],
			"value": intent.damage_at(max_x) * 0.75 + 2.0}
	return {}


# ============================================================ the tap policy --
#
# WHAT A TAP IS WORTH, and why a tap SPELL needed its own answer.
#
# Every other targeted card the AI casts can be priced by its victim: a
# Terror is worth what it kills. A tap is worth nothing on its own — the
# same Twiddle is a blow-out or a wasted card depending on WHOSE permanent
# it hits and WHAT STATE that permanent is in. The AI has always known
# this for repeatable ABILITIES (`_ability_option`'s `intent.taps` arm and
# `_best_tap_victim`: their best untapped creature, at their upkeep or
# before our own attack, never at the mana sink because it untaps before it
# matters). It knew none of it for a tap SPELL, which went through the
# generic picker and so aimed at the enemy's most valuable permanent —
# tapped or not, land or not, at whatever moment the spell became
# affordable. That is what "using Twiddle randomly" looked like from the
# outside (owner's playtest, 2026-09-04).
#
# THE POLICY, and it is deliberately two readings and not four:
#
#  1. THEIR UPKEEP (instants only, `_fire_tap_instant`): tap their best
#     untapped creature. It cannot attack this turn and, still tapped,
#     cannot block on ours — the Icy Manipulator play, bought once with a
#     card, and the strongest thing a Twiddle does.
#  2. OUR PRECOMBAT MAIN with an attack ready (`_size_tap`): tap the
#     blocker in the way. Cheaper than the first because it only buys one
#     turn's worth, so it wants a bigger prize to be worth the card.
#
# Everything else is left OUT, on purpose, with the reason:
#  * Tapping their LAND to deny mana. One land is not worth a card, and
#    tapping it on our turn denies nothing at all — it untaps before their
#    main phase. `_tap_denies_something` refuses lands outright.
#  * UNTAPPING our own land as a mana burst. Twiddle costs {U} to untap
#    one land: net zero mana and a card gone. It is only a ritual on a
#    permanent that makes two or more (a Sol Ring, a Basalt Monolith), and
#    that is a two-step plan — untap, then spend it on something — which a
#    one-ply heuristic has no way to represent. Roadmap, M4 phase 3.
#  * UNTAPPING our own attacker after combat for a surprise block. Real,
#    but it needs a read of THEIR attack that this AI only performs once
#    blockers are being declared, by which time our untap has passed.

## The worth a tap has to clear to be worth a whole CARD: a 2/2's board
## value ([method Evaluator.permanent_value] of a 2/2 is 4.0). A Twiddle
## on a Merfolk of the Pearl Trident is a Twiddle thrown away.
const TAP_CARD_BAR := 4.0


## Would tapping [param inst] actually cost its controller something this
## AI can name? Their untapped creature — and nothing else. A permanent
## that is already tapped loses nothing; a land untaps before it could have
## denied a main phase; one of OUR OWN permanents is never a tap target.
func _tap_denies_something(game: MtgGame, inst: CardInstance) -> bool:
	if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
		return false
	if inst.controller_id == pid or inst.tapped or inst.is_land():
		return false
	return inst.is_creature()


## Aim a tap SPELL (Twiddle, Word of Binding), or `{}` to hold it. The
## sorcery-speed half of the tap policy above: only in our PRECOMBAT main,
## only with an attack to clear the way for, and only for a prize worth the
## card. Instants that find no use here survive to their upkeep, where
## [method _fire_tap_instant] has the stronger reading.
func _size_tap(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		max_x: int, mode: int) -> Dictionary:
	if game.current_step() != Mtg.Step.MAIN1 or not _has_attackers(game):
		return {}
	# "Tap X target creatures": buy exactly as many as there are blockers
	# worth tapping, never more (CR 601.2c lets the count fall short, but
	# the extra mana would be paid for nothing).
	var x := max_x
	if _tap_count_is_x(inst.data):
		var eligible := 0
		for candidate in game.players[game.opponent_of(pid)].battlefield:
			if _tap_denies_something(game, candidate) \
					and game.target_legal_at(intent.target_spec,
						TargetRef.card(candidate), inst, max_x):
				eligible += 1
		if eligible <= 0:
			return {}
		x = clampi(eligible, 1, max_x)
	var targets = _choose_targets(game, inst, x, mode)   # Array or null
	if targets == null or targets.is_empty():
		return {}
	var worth := 0.0
	for t in targets:
		if t == null or t.is_player:
			continue
		var mark := game.find_instance(t.instance_id)
		if mark != null:
			worth += Evaluator.permanent_value(mark)
	if worth < TAP_CARD_BAR:
		return {}
	# The same 0.4 share `_ability_option` puts on a tap taken on our own
	# turn: it clears a blocker for one attack, no more.
	return {"x": x, "targets": targets, "value": worth * 0.4 + 1.0}


## Does this card's first targeting effect take "X target ..."?
static func _tap_count_is_x(data: CardData) -> bool:
	for e in data.spell_effects:
		if e.target_spec != null:
			return e.target_count_is_x
	return false


## Their upkeep: spend a tap INSTANT on their best untapped creature — it
## cannot attack now and cannot block on our turn. The card-priced twin of
## `_ability_option`'s [constant Moment.UPKEEP] arm.
func _fire_tap_instant(game: MtgGame) -> String:
	if not profile.holds_instants:
		return ""
	var sources := _mana_sources(game)
	var best: CardInstance = null
	var best_mark: CardInstance = null
	var best_worth := TAP_CARD_BAR
	for inst in game.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_modal():
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue
		if inst.data.cost.has_x:
			continue   # no sizing model for an X tap at instant speed
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if not intent.is_tap_utility():
			continue
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge).is_empty() \
				and not (_cost_is_free(inst.data.cost) and surcharge == 0):
			continue
		var mark := _best_tap_victim(game, inst, intent.target_spec)
		if mark == null or not _tap_denies_something(game, mark):
			continue
		var worth := Evaluator.permanent_value(mark)
		if worth < best_worth:
			continue
		best = inst
		best_mark = mark
		best_worth = worth
	if best == null:
		return ""
	return _cast_response(game, best, [TargetRef.card(best_mark)], 0,
		"taps %s with %s" % [best_mark.data.card_name, best.data.card_name])


## Would this spell, at its biggest X, kill the opponent outright?
func _lethal_burn(game: MtgGame, intent: EffectIntent, max_x: int) -> bool:
	if intent.target_spec == null:
		return false
	if intent.target_spec.kind != TargetSpec.Kind.ANY \
			and intent.target_spec.kind != TargetSpec.Kind.PLAYER:
		return false
	return intent.damage_at(max_x) >= game.players[game.opponent_of(pid)].life


## An instant this seat keeps in hand for a better moment — mage-go's
## `instantToHold` (`heuristic.go:1074-1232`): combat tricks for combat,
## creature removal for their attackers or their end step, card draw for
## their end step. Sorcery-speed profiles (the Apprentice) hold nothing.
func _is_held_instant(inst: CardInstance, intent: EffectIntent) -> bool:
	if not profile.holds_instants or not inst.is_type(Mtg.CardType.INSTANT):
		return false
	if inst.data.is_modal():
		return false
	if intent.sweeper != null or intent.adds_mana or intent.counters or intent.fogs:
		return false
	if intent.pumps and not intent.pump_self:
		return true
	if intent.draws > 0 or intent.draws_use_x:
		return true
	if intent.answers_creatures() and intent.target_spec != null \
			and (intent.target_spec.kind == TargetSpec.Kind.ANY
				or intent.target_spec.kind == TargetSpec.Kind.CREATURE):
		return true
	return false


## Dark Ritual's worth: does the mana it makes turn a card in hand from
## unaffordable into affordable this turn?
func _mana_spell_enables(game: MtgGame, ritual: CardInstance, sources: Array) -> bool:
	var net := -ritual.data.cost.mana_value()
	for e in ritual.data.spell_effects:
		if e is AddManaEffect:
			for pair in e.produces:
				net += int(pair[1])
	if net <= 0:
		return false
	var available := 0
	for s in sources:
		available += int(s[3])
	for other in game.players[pid].hand:
		if other == ritual or other.is_land() or _is_reactive(other.data):
			continue
		var mv := other.data.cost.mana_value()
		if mv > available and mv <= available + net \
				and Evaluator.card_value(other.data) >= 3.0:
			return true
	return false


## The opponent's end step: cast the held instant with the best use, or
## "" to keep holding. Removal at their best creature worth a card, a
## bounce only at something big or dressed in auras, a draw into a thin
## hand, burn at the face when it finishes them or nearly does.
func _fire_held_instant(game: MtgGame) -> String:
	var opponent := game.opponent_of(pid)
	var them := game.players[opponent]
	var me := game.players[pid]
	var sources := _mana_sources(game)
	var best: CardInstance = null
	var best_targets: Array = []
	var best_value := 0.0
	for inst in me.hand:
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if not _is_held_instant(inst, intent) or intent.pumps:
			continue
		if intent.self_damage >= me.life:
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # locked, banned, "cast only ...", or refused this step
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge).is_empty() \
				and not (_cost_is_free(inst.data.cost) and surcharge == 0):
			continue
		var targets: Array = []
		var value := 0.0
		if intent.draws > 0:
			if me.library.size() <= intent.draws:
				continue
			if intent.target_spec != null:
				targets = [TargetRef.player(pid)]
			value = 3.0 + _draw_need(me.hand.size())
		elif intent.answers_creatures():
			var victim := _best_victim(game, inst, intent, 0)
			if victim != null:
				var worth := Evaluator.permanent_value(victim)
				var bar := 3.0
				if intent.bounces and not intent.removes and intent.damage == 0 \
						and victim.attachments.is_empty():
					bar = 6.0
				if worth >= bar:
					targets = [TargetRef.card(victim)]
					value = worth + 1.0
			if targets.is_empty() and intent.damage > 0 \
					and intent.target_spec.is_legal(game, TargetRef.player(opponent), inst):
				if intent.damage >= them.life:
					targets = [TargetRef.player(opponent)]
					value = LETHAL_WORTH
				elif them.life <= intent.damage * 2:
					targets = [TargetRef.player(opponent)]
					value = intent.damage * 0.75 + 2.0
		if targets.is_empty() and value <= 0.0:
			continue
		value -= intent.self_damage * 0.5
		if value > best_value:
			best = inst
			best_targets = targets
			best_value = value
	if best == null:
		return ""
	return _cast_response(game, best, best_targets, 0, "cast %s at end of turn" % best.data.card_name)


# ====================================================== phase 2: responses --

## One instant-speed response, or "" to pass. The structural guard: if the
## TOP of the stack is our own object, we always wait for it to resolve —
## which both prevents response loops (state hasn't changed yet, so the
## same response would fire again) and is simply correct Magic.
func _respond_action(game: MtgGame) -> String:
	if not game.stack.is_empty() and game.stack.back().controller == pid:
		return ""
	if profile.mistake_chance > 0.0 and game.rng.randf() < profile.mistake_chance:
		return ""   # a fumbled reaction is no reaction
	var counter := _try_counter(game)
	if counter != "":
		return counter
	# Something of theirs on the stack aimed at one of ours: a regeneration
	# shield or a pump in response (mage-go's "opponent stack threat" arm).
	var saved := _save_from_the_stack(game)
	if saved != "":
		return saved
	if not game.combat.attackers.is_empty():
		var shield := _combat_regeneration(game)
		if shield != "":
			return shield
		var pumped := _combat_self_pumps(game)
		if pumped != "":
			return pumped
		if game.active_player != pid:
			return _defensive_combat_response(game)
		return _offensive_combat_response(game)
	# THE OPPONENT'S TURN, empty stack: the two moments the ability scorer
	# keys on (their upkeep, their end step) and the last call for a held
	# instant before our own untap.
	if game.active_player != pid and game.stack.is_empty():
		match game.current_step():
			Mtg.Step.UPKEEP:
				# The tap policy's strongest reading (see "the tap policy"):
				# a tap laid down HERE holds through their turn and ours.
				var tapped_down := _fire_tap_instant(game)
				if tapped_down != "":
					return tapped_down
				return _try_activate(game, Moment.UPKEEP)
			Mtg.Step.END:
				return _end_of_their_turn(game)
	return ""


## The opponent's end step: everything still in hand or open that would
## be wasted by our untap step. Held instants first (a Bolt at their best
## creature, an Ancestral into a thin hand), then the mana sinks.
func _end_of_their_turn(game: MtgGame) -> String:
	var fired := _fire_held_instant(game)
	if fired != "":
		return fired
	return _try_activate(game, Moment.SINK)


# ---------------------------------------- regeneration under modern rules --
#
# CR 701.15: a regeneration shield has to be up BEFORE the destruction it
# replaces — the exact opposite of the 1997 window, where `Duel.hlp` lets
# you regenerate "at the time when a creature is about to go to the
# graveyard". With the fork OFF, a Drudge Skeletons that never shields
# itself in advance is a 1/1 that dies to a Grizzly Bears; these two
# functions are the modern-rules half of what `_regeneration_action` does
# inside the window. Both stand down while the fork is on, so the same
# mana is never spent twice on one death.


## Shield one of ours that the top of the stack is about to destroy or
## burn (Terror says "can't be regenerated" — the intent knows, so no
## shield is wasted on it), or pump it out of the burn's reach.
func _save_from_the_stack(game: MtgGame) -> String:
	if game.stack.is_empty():
		return ""
	var top: StackItem = game.stack.back()
	if top.controller == pid:
		return ""
	var card_name: String = top.card.data.card_name if top.card != null else ""
	var intent := EffectIntent.read(top.effects, card_name)
	if not intent.answers_creatures():
		return ""
	for t in top.targets:
		if t == null or t.is_player:
			continue
		var victim := game.find_instance(t.instance_id)
		if victim == null or victim.controller_id != pid \
				or victim.zone != Mtg.Zone.BATTLEFIELD or not victim.is_creature():
			continue
		if not intent.kills(victim, top.x_value):
			continue
		if intent.bounces:
			continue   # a shield does nothing against Unsummon
		if not intent.removal_ignores_regeneration \
				and not game.rules.damage_prevention_window:
			var shielded := _shield(game, victim)
			if shielded != "":
				return shielded
		# Burn: a Giant Growth that lifts toughness past the damage saves
		# a creature worth the card.
		if intent.damage_at(top.x_value) > 0 and not intent.removes \
				and Evaluator.permanent_value(victim) >= 3.0:
			var pump := _find_pump_instant(game)
			if pump != null:
				var lift: int = pump.data.spell_effects[0].toughness
				if victim.cur_toughness - victim.damage + lift > intent.damage_at(top.x_value):
					return _cast_response(game, pump, [TargetRef.card(victim)])
		# Unsummon our own Djinn out from under the Terror: the card is
		# kept, the tempo is lost — worth it for a creature worth two.
		if Evaluator.permanent_value(victim) >= 5.0:
			var bounce := _find_bounce_for(game, victim)
			if bounce != null:
				return _cast_response(game, bounce, [TargetRef.card(victim)])
	return ""


## An affordable bounce instant in hand that can take [param victim].
func _find_bounce_for(game: MtgGame, victim: CardInstance) -> CardInstance:
	for inst in game.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_modal():
			continue
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if not intent.bounces or intent.target_spec == null \
				or not intent.target_spec.is_legal(game, TargetRef.card(victim), inst):
			continue
		if _plan_taps(game, inst.data.cost, game.spell_surcharge(pid, inst.data)).is_empty() \
				and not game.players[pid].mana_pool.can_pay(inst.data.cost):
			continue
		return inst
	return null


## Self-pumps once blocks are known (Granite Gargoyle's {R}: +0/+1,
## firebreathing on a BLOCKED Shivan): one activation per call, for a
## creature of ours the declared combat would kill and the pumps in reach
## would save, or one the pumps would let kill its opposite number.
## Unblocked attackers get their firebreathing in
## _offensive_combat_response. Bounded: each call spends mana, and the
## pump already on the stack counts as if it had resolved.
func _combat_self_pumps(game: MtgGame) -> String:
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	var sources := _mana_sources(game)
	for inst in game.players[pid].battlefield:
		if not inst.is_creature():
			continue
		var opposite: Array[int] = []
		if game.combat.attackers.has(inst.id):
			opposite = game.combat.blockers_of(inst.id)
		elif game.combat.blocks.has(inst.id):
			opposite = game.combat.attackers_blocked_by(inst.id)
		if opposite.is_empty():
			continue
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if ability.tap_cost or ability.cost == null:
				continue
			var intent := EffectIntent.read(ability.effects, inst.data.card_name)
			if not intent.pump_self or not _ability_available(game, inst, index):
				continue
			var pending := _pending_pumps(game, inst)
			# Activations in reach: planned pump by pump against the REAL
			# cost, colour included (as _pumps_are_lethal counts them) — a
			# Frozen Shade with one Swamp and three Forests open has one
			# {B} in reach, not four, and the count used to say four.
			var reach: int = _pumps_in_reach(game, inst, ability, sources) + pending
			if reach <= pending:
				continue
			var pending_bonus := Vector2i(intent.pump_power * pending, intent.pump_toughness * pending)
			var reach_bonus := Vector2i(intent.pump_power * reach, intent.pump_toughness * reach)
			var worth := false
			if intent.pump_toughness > 0:
				var incoming := _incoming_combat_damage(game, inst, opposite)
				var dies := incoming > 0 \
					and inst.damage + incoming >= inst.cur_toughness + pending_bonus.y
				var saved := inst.damage + incoming < inst.cur_toughness + reach_bonus.y
				worth = dies and saved
			if not worth and intent.pump_power > 0:
				for other_id in opposite:
					var other := game.find_instance(other_id)
					if other == null or other.zone != Mtg.Zone.BATTLEFIELD:
						continue
					if not _dies_to(game, other, inst, Vector2i.ZERO, pending_bonus) \
							and _dies_to(game, other, inst, Vector2i.ZERO, reach_bonus):
						worth = true
						break
			if not worth:
				continue
			if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, inst)):
				continue
			if game.activate_ability(pid, inst, index, []) == "":
				return "pumps %s" % inst.data.card_name
	return ""


## How many times [param ability] of [param inst] the open mana in
## [param sources] can pay for, planning the combined cost each time so
## every coloured pip is counted. Capped at 20 — a Shade with twenty
## Swamps needs no finer answer.
func _pumps_in_reach(game: MtgGame, inst: CardInstance, ability: ActivatedAbility,
		sources: Array) -> int:
	var surcharge := game.ability_surcharge(pid, inst)
	var cost: ManaCost = ability.cost
	var pumps := 0
	while pumps < 20 and not _plan_taps_from(sources, cost, surcharge * (pumps + 1)).is_empty():
		pumps += 1
		cost = _combined_cost(cost, ability.cost)
	return pumps


## Combat damage [param inst] is about to take from [param opposite].
func _incoming_combat_damage(game: MtgGame, inst: CardInstance, opposite: Array[int]) -> int:
	var incoming := 0
	for other_id in opposite:
		var other := game.find_instance(other_id)
		if other != null and other.zone == Mtg.Zone.BATTLEFIELD:
			incoming += _damage_from(other, inst)
	return incoming


## Self-pump activations of [param inst] already waiting on the stack.
func _pending_pumps(game: MtgGame, inst: CardInstance) -> int:
	var n := 0
	for item in game.stack:
		if item.kind == Mtg.StackKind.ABILITY and item.card == inst:
			n += 1
	return n


## Pre-emptive shields for our creatures that the declared combat would
## kill — attackers that are blocked by enough power, blockers in front of
## enough power. Runs once blocks are known, and never inside the 1997
## window (see the section note).
func _combat_regeneration(game: MtgGame) -> String:
	if game.rules.damage_prevention_window:
		return ""
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	for inst in game.players[pid].battlefield:
		if not inst.is_creature() or inst.regeneration_shields > 0:
			continue
		if _shield_pending(game, inst):
			continue   # one is on the stack already — a second would be mana burnt
		if not _dies_in_combat(game, inst):
			continue
		var shielded := _shield(game, inst)
		if shielded != "":
			return shielded
		# Guardian Angel's rider on this creature: {1} a point, and only
		# the points that turn "dies" into "lives".
		var need: int = inst.damage + _combat_damage_to(game, inst) \
			- inst.prevention - inst.cur_toughness + 1
		var bought := _buy_prevention(game, TargetRef.card(inst), need)
		if bought != "":
			return bought
	return ""


## "Until end of turn, you may pay {1} any time you could cast an instant.
## If you do, prevent the next 1 damage that would be dealt to that
## permanent or player this turn" — Guardian Angel's rider, held on the
## seat ([member MtgPlayer.paid_prevention]). Buy [param points] of
## prevention for [param victim], {1} at a time, ALL of it or none: a
## partial cover that still lets the creature die (or us) is mana thrown
## away, which is the same all-or-nothing the window's Circle spend makes.
func _buy_prevention(game: MtgGame, victim: TargetRef, points: int) -> String:
	if points <= 0 or game.paid_prevention_for(pid, victim).is_empty():
		return ""
	if not _plan_and_pay(game, ManaCost.parse("{%d}" % points)):
		return ""
	for _i in points:
		if game.pay_for_prevention(pid, victim) != "":
			return ""
	return "pays {%d} to Guardian Angel for %s" % [points, game.target_label(victim)]


## Combat damage the declared blocks would deal to [param inst] — the
## sum [method _dies_in_combat] compares against its toughness.
func _combat_damage_to(game: MtgGame, inst: CardInstance) -> int:
	var incoming := 0
	if game.combat.attackers.has(inst.id):
		for blocker_id in game.combat.blockers_of(inst.id):
			var blocker := game.find_instance(blocker_id)
			if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD:
				incoming += _damage_from(blocker, inst)
	elif game.combat.blocks.has(inst.id):
		for attacker_id in game.combat.attackers_blocked_by(inst.id):
			var attacker := game.find_instance(attacker_id)
			if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
				incoming += _damage_from(attacker, inst)
	return incoming


## Would [param inst] be destroyed by the combat damage now declared?
## First strike is honoured both ways: a first striker that kills its
## opposite number takes nothing back.
func _dies_in_combat(game: MtgGame, inst: CardInstance) -> bool:
	if not game.combat.attackers.has(inst.id) and not game.combat.blocks.has(inst.id):
		return false
	var incoming := _combat_damage_to(game, inst)
	# A prevention pool already on it (Healing Salve, a Guardian Angel
	# point bought earlier) soaks the first points.
	return incoming > 0 \
		and inst.damage + maxi(incoming - inst.prevention, 0) >= inst.cur_toughness


## Combat damage [param hitter] deals to [param victim], zero when the
## victim's first strike kills the hitter before it strikes (CR 510.2).
## The bonuses are "what if" pumps (a Giant Growth in hand) as +power/
## +toughness, applied to the hitter and the victim respectively.
func _damage_from(hitter: CardInstance, victim: CardInstance,
		hitter_bonus := Vector2i.ZERO, victim_bonus := Vector2i.ZERO) -> int:
	if victim.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
			and not hitter.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
			and victim.cur_power + victim_bonus.x \
				>= hitter.cur_toughness + hitter_bonus.y - hitter.damage:
		return 0
	return _damage_after_prevention(hitter, victim, hitter_bonus)


## The PREVENTION half of [method _damage_from], without its first-strike
## clause: what [param hitter] would land on [param victim] if it gets to
## strike at all.
##
## Split out for the GANG-BLOCK maths (2026-09-05). The first-strike
## clause above asks whether the victim's power reaches the hitter's whole
## toughness, which is the right question when they are alone together and
## the WRONG one inside a gang: an attacker facing three blockers divides
## its power between them, so which of them it kills before they strike
## depends on the assignment, not on the pair. [CombatSearch] therefore
## takes the raw number here and applies first strike per assignment —
## and for a gang of one the two agree by construction, which
## `tests/ai/test_ai_gang_blocks_2026_09_05.gd` pins against
## [method _dies_to] itself.
func _damage_after_prevention(hitter: CardInstance, victim: CardInstance,
		hitter_bonus := Vector2i.ZERO) -> int:
	# PREVENTION the engine applies to every combat hit (its deal_damage
	# gates, in the same order): protection from the hitter's colour (CR
	# 702.16e), "prevent all damage dealt to this creature by creatures"
	# (Uncle Istvan), "prevent all combat damage" and "prevent all damage"
	# shields — unless the damage is unpreventable this turn (Whippoorwill).
	# A pro-black White Knight used to be scored as dying to Erg Raiders.
	if not victim.damage_unpreventable_this_turn:
		if (victim.cur_protection & hitter.cur_colors) != 0 \
				or victim.cur_prevent_damage_from_creatures \
				or victim.cur_prevent_combat_damage_taken \
				or victim.cur_prevent_all_damage_taken:
			return 0
	return maxi(hitter.cur_power + hitter_bonus.x, 0)


## Would [param hitter]'s combat damage finish [param victim] — and would
## it STAY finished (no shield in reach, not indestructible)? The one
## predicate the attack and block maths share, so a Drudge Skeletons
## with {B} open is a wall to both.
func _dies_to(game: MtgGame, victim: CardInstance, hitter: CardInstance,
		victim_bonus := Vector2i.ZERO, hitter_bonus := Vector2i.ZERO) -> bool:
	if victim.cur_indestructible:
		return false
	var hit := _damage_from(hitter, victim, hitter_bonus, victim_bonus)
	if hit <= 0 or hit < victim.cur_toughness + victim_bonus.y - victim.damage:
		return false
	return not _shieldable(game, victim)


## Can [param inst]'s controller put a regeneration shield on it right
## now? Our own creatures through the real planner; theirs by counting
## their open mana against the cheapest shield they have.
func _shieldable(game: MtgGame, inst: CardInstance) -> bool:
	if inst.controller_id == pid:
		return _can_shield(game, inst)
	if inst.regeneration_shields > 0:
		return true
	if inst.regeneration_banned_this_turn:
		return false
	var open := 0
	for p in game.players[inst.controller_id].battlefield:
		if not p.tapped and not p.cur_mana_abilities.is_empty() \
				and not (p.is_creature() and p.summoning_sick):
			open += 1
	for index in inst.cur_activated_abilities.size():
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if not _effects_regenerate(game, ability.effects, inst, inst):
			continue
		if ability.tap_cost and inst.tapped:
			continue
		if ability.cost.mana_value() <= open:
			return true
	return false


## Put a regeneration shield on [param victim] from its own ability or
## another permanent's targeted one, cheapest first; "" when none is
## affordable. Spells (Death Ward) are left to the window path — a card is
## a card, and a pre-emptive one on a guess is usually a card wasted.
func _shield(game: MtgGame, victim: CardInstance) -> String:
	var best: Dictionary = {}
	for inst in game.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _effects_regenerate(game, ability.effects, victim, inst):
				continue
			if not _ability_available(game, inst, index):
				continue
			var price: float = ability.cost.mana_value()
			if not best.is_empty() and float(best["price"]) <= price:
				continue
			best = {"price": price, "inst": inst, "index": index}
	if best.is_empty():
		return ""
	var source: CardInstance = best["inst"]
	var ability: ActivatedAbility = source.cur_activated_abilities[int(best["index"])]
	if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, source)):
		return ""
	var targets: Array = [] if ability.effects[0].target_spec == null \
		else [TargetRef.card(victim)]
	if game.activate_ability(pid, source, int(best["index"]), targets) != "":
		return ""
	return "shields %s" % victim.data.card_name


## Is a regeneration shield for [param inst] already waiting on the stack
## — its own ability, or another permanent's aimed at it? The shield
## counter only rises when that resolves; until then the "no shield yet"
## read would buy a second one.
func _shield_pending(game: MtgGame, inst: CardInstance) -> bool:
	for item in game.stack:
		if item.kind != Mtg.StackKind.ABILITY or item.controller != pid:
			continue
		if item.effects.size() != 1 or not item.effects[0].is_regeneration:
			continue
		if item.effects[0].target_spec == null:
			if item.card == inst:
				return true
			continue
		for ref in item.targets:
			if not ref.is_player and ref.instance_id == inst.id:
				return true
	return false


## Can [param inst] put up a regeneration shield right now (its own
## ability, mana in reach)? Read by the combat maths, so a Drudge Skeletons
## with {B} open blocks like the wall it is.
func _can_shield(game: MtgGame, inst: CardInstance) -> bool:
	if inst.regeneration_shields > 0:
		return true
	if inst.regeneration_banned_this_turn:
		return false
	for index in inst.cur_activated_abilities.size():
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if not _effects_regenerate(game, ability.effects, inst, inst):
			continue
		if not _ability_available(game, inst, index):
			continue
		if _cost_is_free(ability.cost) \
				or not _plan_taps(game, ability.cost, game.ability_surcharge(pid, inst)).is_empty() \
				or game.players[pid].mana_pool.can_pay(ability.cost):
			return true
	return false


## Does [param data] COUNTER the spell it targets?
##
## The effect-class reader cannot tell: four of this pool's counterspells
## are built from a CARD-LOCAL `class X extends EffectBase` (Power Sink,
## Mana Drain, Spell Blast, Force Spike — 33, 29, 7 and 1 deck files
## between them), so `e is CounterEffect` was false for all of them. They
## were therefore neither filtered out of the main phase by [method
## _is_reactive] nor offered to [method _try_counter]: dead cards in hand
## for the whole game, in a third of the shipped deck pool.
##
## The card's own ORACLE LINE is the reading that does not care how the
## effect was built, and it separates the counterspells from the two cards
## that COPY a spell instead (Fork, Reverberation — "Copy target ..."),
## which must not be fired as answers.
static func _is_counterspell(data: CardData) -> bool:
	for e in data.spell_effects:
		if e is CounterEffect:
			return true
	for effect in data.spell_effects:
		if effect.target_spec != null \
				and effect.target_spec.kind == TargetSpec.Kind.SPELL \
				and data.oracle_text.begins_with("Counter target "):
			return true
	return false


## Counter the top opposing spell when the threat clears the profile bar.
func _try_counter(game: MtgGame) -> String:
	if game.stack.is_empty():
		return ""
	var top: StackItem = game.stack.back()
	if top.kind != Mtg.StackKind.SPELL or top.controller == pid:
		return ""
	var threat := Evaluator.card_value(top.card.data)
	# An opposing counterspell aimed at OUR spell threatens that spell's
	# whole value — counter-wars are judged by the contested prize.
	for t in top.targets:
		if t != null and not t.is_player:
			var target := game.find_instance(t.instance_id)
			if target != null and target.controller_id == pid:
				threat = maxf(threat, Evaluator.card_value(target.data))
	if threat < profile.counter_threshold:
		return ""
	var top_ref := TargetRef.card(top.card)
	for inst in game.players[pid].hand:
		# Plain counterspells — but only when the spell CAN be countered by
		# this card (Remove Soul only stops creature spells).
		for effect in inst.data.spell_effects:
			if effect is CounterEffect \
					and effect.target_spec.is_legal(game, top_ref, inst):
				return _cast_response(game, inst, [top_ref])
		# Counterspells the effect-class reader cannot see (card-local
		# effects — see [method _is_counterspell]).
		if _is_counterspell(inst.data):
			for effect in inst.data.spell_effects:
				if effect.target_spec == null \
						or effect.target_spec.kind != TargetSpec.Kind.SPELL:
					continue
				var x := 0
				if inst.data.cost.has_x:
					var max_x := _max_affordable_x(game, inst.data.cost,
						game.spell_surcharge(pid, inst.data), _mana_sources(game),
						inst.data.x_color, game.mana_usage_keys(inst.data))
					if effect.target_spec.source_filter.is_valid():
						# "COUNTER TARGET SPELL WITH MANA VALUE X" (Spell
						# Blast): the X is not "as deep as the mana goes",
						# it is exactly the mana value on the stack, and
						# the SPEC is the only thing that knows which — so
						# try each affordable X on until one names the
						# spell (CR 115.4). Nothing could do that until
						# `MtgGame.casting_x` learned to answer for a
						# PROPOSED X, which is why the 2026-09-04 sweep
						# recognised this card as a counterspell and it
						# still never fired.
						x = _x_that_makes_legal(game, inst, effect.target_spec,
							top_ref, max_x)
						if x < 0:
							continue
					else:
						# Power Sink's X is paid as deep as the mana goes.
						x = max_x
						if x <= 0:
							continue
				if not game.target_legal_at(effect.target_spec, top_ref, inst, x):
					continue
				return _cast_response(game, inst, [top_ref], 0, "", x)
		# Modal cards with a counter mode (Blue/Red Elemental Blast).
		for mode_i in inst.data.modes.size():
			var m_effects: Array = inst.data.modes[mode_i]["effects"]
			if m_effects.size() == 1 and m_effects[0] is CounterEffect \
					and m_effects[0].target_spec.is_legal(game, top_ref, inst):
				return _cast_response(game, inst, [top_ref], mode_i)
	return ""


## We are DEFENDING and attackers are on the table.
func _defensive_combat_response(game: MtgGame) -> String:
	var me := game.players[pid]
	# Fog once blocks are known and real damage is coming through.
	if game.current_step() == Mtg.Step.DECLARE_BLOCKERS \
			and not game.combat_damage_prevented:
		var unblocked := 0
		for attacker_id in game.combat.attackers:
			var attacker := game.find_instance(attacker_id)
			if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD \
					and not game.combat.was_blocked(game.combat.band_of(attacker_id)):
				unblocked += attacker.cur_power
		if unblocked >= mini(me.life, 7):
			for inst in me.hand:
				if inst.data.card_name == "Fog":
					return _cast_response(game, inst, [])
	# Instant removal: attackers worth killing, the biggest GAIN first —
	# but keep going down the list (the biggest may be unkillable; the
	# specter beside it may not be — a lesson a test taught this function).
	# The gain is the attacker's worth, plus the blocker of ours it would
	# otherwise kill, plus the damage it would land on us — priced by how
	# much that damage matters (a third of a life point at twenty, the
	# whole game when the swing is lethal).
	var worth_killing: Array[CardInstance] = []
	var gains: Dictionary = {}
	var unblocked_total := 0
	var blocks_known := game.current_step() != Mtg.Step.DECLARE_ATTACKERS \
		and game.current_step() != Mtg.Step.COMBAT_BEGIN
	for attacker_id in game.combat.attackers:
		var attacker := game.find_instance(attacker_id)
		if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD and blocks_known \
				and not game.combat.was_blocked(game.combat.band_of(attacker_id)):
			unblocked_total += attacker.cur_power
	for attacker_id in game.combat.attackers:
		var attacker := game.find_instance(attacker_id)
		if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD:
			continue
		var gain := Evaluator.permanent_value(attacker)
		if blocks_known:
			if game.combat.was_blocked(game.combat.band_of(attacker_id)):
				for blocker_id in game.combat.blockers_of(attacker_id):
					var blocker := game.find_instance(blocker_id)
					if blocker != null and blocker.controller_id == pid \
							and _dies_to(game, blocker, attacker) \
							and not _dies_to(game, attacker, blocker):
						gain += Evaluator.permanent_value(blocker)
			elif unblocked_total >= me.life:
				gain += LETHAL_WORTH
			else:
				gain += attacker.cur_power * (1.0 if me.life - unblocked_total <= 10 else 0.34)
		gains[attacker_id] = gain
		if gain >= 5.0:
			worth_killing.append(attacker)
	worth_killing.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return gains[a.id] > gains[b.id])
	for victim in worth_killing:
		var killer := _find_instant_removal_for(game, victim)
		if killer != null:
			return _cast_response(game, killer, [TargetRef.card(victim)])
	# Activated removal (Royal Assassin executing a tapped attacker):
	# battlefield tap-abilities with a targeted DestroyEffect, aimed down
	# the same most-valuable-first list.
	for victim in worth_killing:
		for inst in game.players[pid].battlefield:
			if inst.tapped or (inst.is_creature() and inst.summoning_sick):
				continue
			for index in inst.cur_activated_abilities.size():
				var ability: ActivatedAbility = inst.cur_activated_abilities[index]
				if not ability.tap_cost or ability.sacrifice_cost:
					continue
				if ability.effects.size() != 1 or not (ability.effects[0] is DestroyEffect):
					continue
				var spec: TargetSpec = ability.effects[0].target_spec
				if spec == null or not spec.is_legal(game, TargetRef.card(victim), inst):
					continue
				if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, inst)):
					continue
				if game.activate_ability(pid, inst, index, [TargetRef.card(victim)]) == "":
					return "executed %s with %s" % [victim.data.card_name, inst.data.card_name]
	# Giant Growth to flip a losing block into a surviving one.
	if game.current_step() == Mtg.Step.DECLARE_BLOCKERS:
		var pump := _find_pump_instant(game)
		if pump != null:
			var bonus := Vector2i(pump.data.spell_effects[0].power,
				pump.data.spell_effects[0].toughness)
			for blocker_id in game.combat.blocks:
				var blocker := game.find_instance(blocker_id)
				var attacker := game.find_instance(game.combat.blocks[blocker_id])
				if blocker == null or attacker == null \
						or blocker.controller_id != pid \
						or blocker.zone != Mtg.Zone.BATTLEFIELD \
						or attacker.zone != Mtg.Zone.BATTLEFIELD:
					continue
				var dies_now := _dies_to(game, blocker, attacker)
				var saved_by_pump := not _dies_to(game, blocker, attacker, bonus)
				if dies_now and saved_by_pump \
						and Evaluator.permanent_value(blocker) >= 3.0:
					return _cast_response(game, pump, [TargetRef.card(blocker)])
	return ""


## We are ATTACKING; blocks are (being) declared.
func _offensive_combat_response(game: MtgGame) -> String:
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	var them := game.players[game.opponent_of(pid)]
	var pump := _find_pump_instant(game)
	var bonus := Vector2i.ZERO
	if pump != null:
		bonus = Vector2i(pump.data.spell_effects[0].power, pump.data.spell_effects[0].toughness)
	# The pump on an unblocked attacker when that is the game.
	var unblocked_total := 0
	var unblocked: Array[CardInstance] = []
	for attacker_id in game.combat.attackers:
		var attacker := game.find_instance(attacker_id)
		if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD \
				or attacker.controller_id != pid:
			continue
		if not game.combat.was_blocked(game.combat.band_of(attacker_id)):
			unblocked_total += attacker.cur_power
			unblocked.append(attacker)
	if pump != null and not unblocked.is_empty() and not game.combat_damage_prevented \
			and unblocked_total < them.life and unblocked_total + bonus.x >= them.life:
		return _cast_response(game, pump, [TargetRef.card(unblocked[0])])
	# THE +X/+0 FINISHER (Howl from Beyond, 12 deck files, never fired in a
	# logged game — class 6 of the 2026-09-04 sweep). It is offered HERE
	# and nowhere else, and only for the kill: a pump with no toughness
	# buys no block and no board, so an X sized to whatever mana happens to
	# be open is a card thrown away — but mana is worth nothing at all if
	# the game ends on this attack. X is the shortfall exactly, never the
	# maximum.
	if not unblocked.is_empty() and not game.combat_damage_prevented \
			and unblocked_total < them.life:
		var finisher := _find_x_power_pump(game)
		if not finisher.is_empty() \
				and unblocked_total + int(finisher["x"]) >= them.life:
			var need: int = them.life - unblocked_total
			return _cast_response(game, finisher["inst"],
				[TargetRef.card(unblocked[0])], 0, "", need)
	# Removal on the blocker that would kill our attacker and live: the
	# blocker dies, the attacker lives, and its damage lands (CR 509.1h —
	# a creature stays "blocked", so no damage to the player; it is the
	# creature we keep). Worth it when the two bodies together are worth
	# a card.
	for blocker_id in game.combat.blocks:
		var blocker := game.find_instance(blocker_id)
		var attacker := game.find_instance(game.combat.blocks[blocker_id])
		if blocker == null or attacker == null \
				or attacker.controller_id != pid \
				or blocker.zone != Mtg.Zone.BATTLEFIELD \
				or attacker.zone != Mtg.Zone.BATTLEFIELD:
			continue
		var loses_now := _dies_to(game, attacker, blocker) \
			and not _dies_to(game, blocker, attacker)
		if not loses_now:
			continue
		# Giant Growth to win the block instead, when it does.
		if pump != null and not _dies_to(game, attacker, blocker, bonus) \
				and _dies_to(game, blocker, attacker, Vector2i.ZERO, bonus):
			return _cast_response(game, pump, [TargetRef.card(attacker)])
		if Evaluator.permanent_value(blocker) + Evaluator.permanent_value(attacker) >= 5.0:
			var killer := _find_instant_removal_for(game, blocker)
			if killer != null:
				return _cast_response(game, killer, [TargetRef.card(blocker)])
	# Firebreathing on an UNBLOCKED attacker: every extra red is a hit —
	# but only a POWER pump is (a Gargoyle's +0/+1 at an open lane used to
	# eat the mana of the second main phase for nothing), and only with
	# mana the second main phase does not need for its best cast, unless
	# the pumps themselves are the lethal (mage-go's `canCastWhileReserving`
	# again, with the main-phase spell as the thing reserved for).
	if game.combat_damage_prevented:
		return ""
	var sources := _mana_sources(game)
	var reserve := _main2_reserve(game, sources)
	for attacker in unblocked:
		for index in attacker.cur_activated_abilities.size():
			var ability: ActivatedAbility = attacker.cur_activated_abilities[index]
			if ability.tap_cost or ability.effects.size() != 1:
				continue
			if not (ability.effects[0] is PumpEffect and ability.effects[0].self_mode):
				continue
			if ability.effects[0].power <= 0:
				continue
			# The same gate every other activation passes: a pump whose
			# price is a BODY (Fallen Angel, Atog) is not firebreathing,
			# and used to eat the board one Serra at a time.
			if not _ability_available(game, attacker, index):
				continue
			var surcharge := game.ability_surcharge(pid, attacker)
			if not reserve.is_empty() \
					and _plan_taps_from(sources,
						_combined_cost(ability.cost, reserve["cost"]), surcharge).is_empty() \
					and not _pumps_are_lethal(game, attacker, ability, sources, unblocked_total):
				continue
			if not _plan_and_pay(game, ability.cost, surcharge):
				continue
			if game.activate_ability(pid, attacker, index, []) == "":
				return "firebreathing on %s" % attacker.data.card_name
	return ""


## The most valuable sorcery-speed cast the second main phase could make
## from what is open now, as `{cost, value}` — `{}` when there is none.
## What firebreathing must leave alone.
func _main2_reserve(game: MtgGame, sources: Array) -> Dictionary:
	var out: Dictionary = {}
	for inst in game.players[pid].hand:
		if inst.is_land() or inst.is_type(Mtg.CardType.INSTANT):
			continue
		if inst.data.cost.has_x:
			continue   # sized at cast time; a burn spell waits for its X
		if _cast_gate(game, inst) != "":
			continue   # what cannot be cast needs no mana kept for it
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge,
				game.mana_usage_keys(inst.data)).is_empty():
			continue
		var value := Evaluator.card_value(inst.data)
		if value >= 3.0 and value > float(out.get("value", 0.0)):
			out = {"cost": inst.data.cost, "value": value}
	return out


## Would firebreathing [param attacker] with everything open finish them?
## The one case where the second main phase does not matter.
func _pumps_are_lethal(game: MtgGame, attacker: CardInstance,
		ability: ActivatedAbility, sources: Array, unblocked_total: int) -> bool:
	var them := game.players[game.opponent_of(pid)]
	if ability.effects[0].power <= 0:
		return false
	var surcharge := game.ability_surcharge(pid, attacker)
	var pumps := 0
	var cost := ability.cost
	# Bounded by the mana open (each probe adds one more activation).
	while pumps < 20 and not _plan_taps_from(sources, cost, surcharge * (pumps + 1)).is_empty():
		pumps += 1
		cost = _combined_cost(cost, ability.cost)
	return unblocked_total + pumps * int(ability.effects[0].power) >= them.life


## Cast an instant-speed response from hand (plans mana, taps, casts).
func _cast_response(game: MtgGame, inst: CardInstance, targets: Array,
		mode := 0, verb := "", x_value := 0) -> String:
	if not inst.is_type(Mtg.CardType.INSTANT):
		return ""
	# The same question `_try_cast_best` asks, for the same reason: every
	# instant-speed cast in this file goes through here, and a refusal
	# after `_plan_and_pay` is mana the turn never gets back.
	if game.cast_refusal(pid, inst, targets, x_value, mode) != "":
		_refused[str(inst.id)] = true
		return ""
	if not _plan_and_pay(game, inst.data.cost_for(x_value),
			_generic_x(inst.data, x_value) + game.spell_surcharge(pid, inst.data)):
		return ""
	var err := game.cast_spell(pid, inst, targets, x_value, mode)
	if err != "":
		game.log_line("(AI response %s refused: %s)" % [inst.data.card_name, err])
		_refused[str(inst.id)] = true
		return ""
	if verb != "":
		return verb
	return "responded with %s" % inst.data.card_name


## An instant in hand that answers [param victim] right now — kills it
## outright, exiles it, or bounces it ([param allow_bounce]) — and that
## this seat can pay for.
func _find_instant_removal_for(game: MtgGame, victim: CardInstance,
		allow_bounce := true) -> CardInstance:
	var sources := _mana_sources(game)
	for inst in game.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_modal():
			continue
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if intent.target_spec == null or intent.damage_uses_x or intent.self_damage >= game.players[pid].life:
			continue
		if intent.bounces and not allow_bounce:
			continue
		if not intent.kills(victim, 0):
			continue
		if not intent.target_spec.is_legal(game, TargetRef.card(victim), inst):
			continue
		if intent.removes and victim.cur_indestructible:
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # locked, banned, "cast only ...", or refused this step
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge).is_empty() \
				and not game.players[pid].mana_pool.can_pay(inst.data.cost):
			continue
		return inst
	return null


## The +X/+0 pump instant in hand and the biggest X it can pay for, as
## `{inst, x}` — or `{}`. Kept APART from [method _find_pump_instant] on
## purpose: that one serves three callers who all read a fixed
## `power`/`toughness` straight off the effect, and a pump whose size is
## chosen at cast time has neither. Its one caller is the lethal push in
## [method _offensive_combat_response].
func _find_x_power_pump(game: MtgGame) -> Dictionary:
	for inst in game.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_modal():
			continue
		if not inst.data.cost.has_x:
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # locked, banned, "cast only ...", or refused this step
		if inst.data.spell_effects.size() != 1:
			continue
		var effect: EffectBase = inst.data.spell_effects[0]
		if not (effect is PumpEffect) or effect.self_mode or not effect.use_x_power:
			continue
		var max_x := _max_affordable_x(game, inst.data.cost,
			game.spell_surcharge(pid, inst.data), _mana_sources(game),
			inst.data.x_color, game.mana_usage_keys(inst.data))
		if max_x <= 0:
			continue
		return {"inst": inst, "x": max_x}
	return {}


## A +3/+3-style creature pump instant in hand (Giant Growth shape).
func _find_pump_instant(game: MtgGame) -> CardInstance:
	for inst in game.players[pid].hand:
		if not inst.is_type(Mtg.CardType.INSTANT):
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # locked, banned, "cast only ...", or refused this step
		if inst.data.spell_effects.size() == 1 \
				and inst.data.spell_effects[0] is PumpEffect \
				and not inst.data.spell_effects[0].self_mode \
				and inst.data.spell_effects[0].toughness > 0:
			if not _plan_taps(game, inst.data.cost, 0).is_empty() \
					or game.players[pid].mana_pool.can_pay(inst.data.cost):
				return inst
	return null


static func _has_effect(data: CardData, effect_class: String) -> bool:
	for effect in data.spell_effects:
		if effect.get_script().get_global_name() == effect_class:
			return true
	return false


# ================================================================== combat --

## Attack declaration: per-attacker favorable-trade analysis (mage-go's
## combat heuristic, simplified), plus a lethal-push override and the
## aggression/mistake tilts from the profile.
func _declare_attacks(game: MtgGame) -> String:
	var defender := game.opponent_of(pid)
	var candidates: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_creature() \
				and CombatState.attack_illegality(game, inst, defender) == "" \
				and _attack_costs_payable(game, inst):
			candidates.append(inst)
	var blockers: Array[CardInstance] = []
	for inst in game.players[defender].battlefield:
		if inst.is_creature() and not inst.tapped:
			blockers.append(inst)
	# Lethal push: if what gets past their best blocks would win, send
	# everything. Counted THROUGH the blocks, not as raw power — the old
	# "sum of power >= life" sent the whole board into a wall of blockers
	# and lost it (mage-go combat.go, "lethal through blockers").
	var lethal_push := _damage_through_blocks(game, candidates, blockers, defender) \
		>= game.players[defender].life
	var attackers: Array = []
	if lethal_push:
		for inst in candidates:
			if inst.cur_power <= 0 and not _must_attack(inst):
				continue
			attackers.append(inst.id)
	else:
		attackers = _choose_attack_cohort(game, candidates, blockers, defender)
	# A pump in hand (Giant Growth) with the mana open turns ONE more
	# doubtful attack into a sound one — the most valuable such body goes
	# too, since the trick will be there for it. One, not every: a single
	# card saves a single creature.
	if not lethal_push:
		var pump := _find_pump_instant(game)
		if pump != null:
			var bonus := Vector2i(pump.data.spell_effects[0].power,
				pump.data.spell_effects[0].toughness)
			var extra: CardInstance = null
			for inst in candidates:
				if inst.cur_power <= 0 or attackers.has(inst.id):
					continue
				if _attack_is_reasonable(game, inst, blockers, defender, bonus) \
						and (extra == null
							or Evaluator.permanent_value(inst) > Evaluator.permanent_value(extra)):
					extra = inst
			if extra != null:
				attackers.append(extra.id)
	# THE CRACK-BACK (M4 phase 3, 2026-09-05). Everything above prices
	# THIS combat; an attacker is tapped through the opponent's whole turn,
	# so the swing that wins the exchange can still lose the game.
	# [CombatSearch] takes the declaration as it now stands and searches
	# whether some SUBSET of it survives their counter-swing better — it
	# can only ever hold a body back, never send one the analysis above
	# rejected, and it runs after the pump rider so the body that rider
	# added is on the table it searches. A lethal push never reaches here:
	# a swing that wins the game has no next turn to survive.
	if not lethal_push:
		attackers = _search_hold_back(game, candidates, attackers, defender)
	# Must-attackers are non-optional whatever the analysis said — the
	# printed "attacks each combat if able" (Juggernaut) and the ORDER of
	# the turn (Nettling Imp, Siren's Call — `must_attack_this_turn`).
	# Both are requirements the engine refuses to see broken (CR 508.1d);
	# before the 2026-09-02 sweep the AI knew only the keyword and an
	# ordered Bears wedged the declare-attackers step for good.
	for inst in candidates:
		if _must_attack(inst) and not attackers.has(inst.id):
			attackers.append(inst.id)
	# Mistake injection: a fumbling AI leaves a good attacker home.
	if attackers.size() > 0 and game.rng.randf() < profile.mistake_chance:
		var drop_index := game.rng.randi_range(0, attackers.size() - 1)
		var dropped := game.find_instance(attackers[drop_index])
		if not _must_attack(dropped):
			attackers.remove_at(drop_index)
	# RESTRICTIONS beat requirements (CR 508.1d): a blanket ban (Festival)
	# empties the declaration; an attacker cap (Caverns of Despair) trims
	# it, optional bodies first.
	if game.no_attacks_this_turn:
		attackers = []
	attackers = _trim_attackers_to_cap(game, attackers)
	# Phase 2: declare a band when two-plus banders attack — plus one big
	# non-bander riding along (banding's whole point: the group is blocked
	# as one and WE spread the blocker's damage).
	var band_list: Array = []
	if profile.holds_instants:
		var banders: Array = []
		var best_rider: CardInstance = null
		for id in attackers:
			var inst := game.find_instance(id)
			if inst.has_keyword(Mtg.Keyword.BANDING):
				banders.append(id)
			elif best_rider == null \
					or Evaluator.permanent_value(inst) > Evaluator.permanent_value(best_rider):
				best_rider = inst
		if banders.size() >= 2:
			var band: Array = banders.duplicate()
			if best_rider != null:
				band.append(best_rider.id)
			band_list = [band]
	# THE DECLARATION LADDER. A refused declaration leaves the step open,
	# and a step that never closes is a duel that never ends — so every
	# rung is simpler than the one above, and the last one leaves the
	# GAME rather than the step (an AI/engine mismatch is a bug worth
	# hearing about, never worth a frozen table).
	var err := game.declare_attackers(pid, attackers, band_list)
	if err != "" and not band_list.is_empty():
		# Band refused for any reason: attack unbanded rather than not at all.
		err = game.declare_attackers(pid, attackers)
		if err == "":
			band_list = []
	if err != "":
		game.log_line("(AI attack declaration refused: %s)" % err)
		var conscripts: Array = []
		for inst in candidates:
			if _must_attack(inst):
				conscripts.append(inst.id)
		attackers = _trim_attackers_to_cap(game, conscripts)
		band_list = []
		err = game.declare_attackers(pid, attackers)
	if err != "":
		attackers = []
		err = game.declare_attackers(pid, attackers)
	if err != "":
		push_error("AiPlayer: no legal attack declaration for seat %d (%s)" % [pid, err])
		game.log_line("(AI has no legal attack declaration: %s — concedes)" % err)
		game.concede(pid)
		return ""
	return "declared %d attacker(s)%s" % [attackers.size(),
		"" if band_list.is_empty() else " (banded)"]


## Is [param inst] under an attack REQUIREMENT — "attacks each combat if
## able" (Juggernaut) or "attacks this turn if able" (Nettling Imp)?
static func _must_attack(inst: CardInstance) -> bool:
	return inst.has_keyword(Mtg.Keyword.MUST_ATTACK) or inst.must_attack_this_turn


## Can every attack cost on [param inst] (Brainwash's "{3}") be paid right
## now? The engine refuses the whole declaration otherwise.
func _attack_costs_payable(game: MtgGame, inst: CardInstance) -> bool:
	for cost in inst.cur_attack_costs:
		if not bool(cost["can_pay"].call(game, pid)):
			return false
	return true


## [param ids] cut down to [member MtgGame.max_attackers] (Caverns of
## Despair): the must-attackers stay, the most valuable optional bodies
## fill what is left. Unchanged when there is no cap or it is not reached.
func _trim_attackers_to_cap(game: MtgGame, ids: Array) -> Array:
	var cap: int = game.max_attackers
	if cap <= 0 or ids.size() <= cap:
		return ids
	var keep: Array = []
	var optional: Array[CardInstance] = []
	for id in ids:
		var inst := game.find_instance(id)
		if inst == null:
			continue
		if _must_attack(inst):
			keep.append(id)
		else:
			optional.append(inst)
	optional.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return Evaluator.permanent_value(a) > Evaluator.permanent_value(b))
	for inst in optional:
		if keep.size() >= cap:
			break
		keep.append(inst.id)
	return keep.slice(0, cap)


## Damage that connects if the defender blocks our biggest attackers with
## everything it has — one blocker per attacker, legality (flying, walls,
## protection) honoured, trample counted past the blocker.
func _damage_through_blocks(game: MtgGame, candidates: Array[CardInstance],
		blockers: Array[CardInstance], defender: int) -> int:
	var ordered: Array[CardInstance] = candidates.duplicate()
	ordered.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	var used: Dictionary = {}
	var total := 0
	for inst in ordered:
		if inst.cur_power <= 0:
			continue
		var stopped_by: CardInstance = null
		for blocker in blockers:
			if used.has(blocker.id):
				continue
			if CombatState.block_illegality(game, blocker, inst, defender) != "":
				continue
			used[blocker.id] = true
			stopped_by = blocker
			break
		if stopped_by == null:
			total += inst.cur_power
		elif inst.has_keyword(Mtg.Keyword.TRAMPLE):
			total += maxi(inst.cur_power - (stopped_by.cur_toughness - stopped_by.damage), 0)
	return total


## The worst ONE blocker can do to [param inst], in Evaluator stat points
## and ignoring the damage the block prevents: [method
## Evaluator.permanent_value] when their best answer kills it and lives,
## the size of the trade-DOWN when both die, 0.0 when nothing over there
## beats it. Returns -1.0 when nothing they control may legally block it
## at all — the one answer the cohort maths must tell apart from "0".
func _attack_risk(game: MtgGame, inst: CardInstance,
		blockers: Array[CardInstance], defender: int, bonus := Vector2i.ZERO) -> float:
	var my_value := Evaluator.permanent_value(inst)
	var worst_loss := -1.0   # < 0 = unblockable by anything they have
	for blocker in blockers:
		if CombatState.block_illegality(game, blocker, inst, defender) != "":
			continue
		worst_loss = maxf(worst_loss, 0.0)
		var kills_me := _dies_to(game, inst, blocker, bonus, Vector2i.ZERO)
		var survives_me := not _dies_to(game, blocker, inst, Vector2i.ZERO, bonus)
		if kills_me and survives_me:
			worst_loss = maxf(worst_loss, my_value)          # pure loss
		elif kills_me:
			var trade := my_value - Evaluator.permanent_value(blocker)
			worst_loss = maxf(worst_loss, maxf(trade, 0.0))  # trade-down risk
	return worst_loss


## THE CRACK-BACK SEARCH's entry from the attack declaration
## (docs/ROADMAP.md, "The crack-back search", 2026-09-05).
##
## [param chosen] is the cohort's declaration. Returns it unchanged, or
## the SUBSET of it that survives the opponent's counter-swing best. Two
## prior approximations of this were built and rejected on measurement,
## and both went wrong the same way — they held bodies home on a
## pessimistic reading of a swing the opponent might not even make. The
## search enumerates instead: their swing is a choice they take only if it
## pays them, and our blocks are a choice we make as well as we can.
##
## THE GATE, and it is exact rather than a tuning constant: if every
## creature they control connecting still leaves us alive, no attack we
## could declare loses the game to the counter-swing, so there is nothing
## here for this search to find and the cohort's answer stands untouched.
## That is what keeps the cost off the combats this is not for — measured
## at [i]docs/ROADMAP.md[/i]'s cost table.
func _search_hold_back(game: MtgGame, candidates: Array[CardInstance],
		chosen: Array, defender: int) -> Array:
	if profile.combat_search_nodes <= 0:
		return chosen        # a capability the bottom of the ladder does not have
	if chosen.is_empty():
		return chosen
	var reach := 0
	for inst in game.players[defender].battlefield:
		if inst.is_creature() and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			reach += maxi(inst.cur_power, 0)
	if reach < game.players[pid].life:
		return chosen
	var mine: Array[CardInstance] = []
	for inst in game.players[pid].battlefield:
		if inst.is_creature() and not inst.tapped:
			mine.append(inst)   # tapped bodies neither attack now nor block later
	var theirs: Array[CardInstance] = []
	for inst in game.players[defender].battlefield:
		if inst.is_creature():
			theirs.append(inst)   # ALL of them: they untap before they swing
	if mine.is_empty() or theirs.is_empty() \
			or mine.size() > 24 or theirs.size() > 24:
		return chosen        # the move mask is a 64-bit int; keep it honest
	var search := _build_combat_model(game, mine, theirs, candidates, defender)
	search.budget = profile.combat_search_nodes
	var cohort_mask := 0
	for i in mine.size():
		if chosen.has(mine[i].id):
			cohort_mask |= 1 << i
	var mask := search.best_attack(cohort_mask)
	if mask == cohort_mask:
		return chosen
	var out: Array = []
	for i in mine.size():
		if (mask & (1 << i)) != 0:
			out.append(mine[i].id)
	return out


## Fill a [CombatSearch] from the engine's OWN predicates — nothing here
## is a second rules model. Every block legality is
## [method CombatState.block_illegality] and every kill is
## [method _dies_to], the two the rest of this file's combat maths already
## share, precomputed into matrices so the tree can index them instead of
## re-asking the engine at every node.
##
## The one place a predicate is decomposed rather than called:
## [method CombatState.attack_illegality] refuses a TAPPED or
## SUMMONING-SICK creature, and by their turn neither is true any more, so
## [member CombatSearch.d_can_attack] asks only its durable half —
## Defender, "can't attack", and the "unless the defending player controls
## a ..." rider. Over-including there is the SAFE direction for a
## defensive read.
func _build_combat_model(game: MtgGame, mine: Array[CardInstance],
		theirs: Array[CardInstance], candidates: Array[CardInstance],
		defender: int) -> CombatSearch:
	var search := CombatSearch.new()
	var n := mine.size()
	var m := theirs.size()
	search.my_life = game.players[pid].life
	search.their_life = game.players[defender].life
	search.a_pow.resize(n)
	search.a_val.resize(n)
	search.a_id.resize(n)
	search.a_can_attack.resize(n)
	search.a_forced.resize(n)
	search.a_free.resize(n)
	search.a_vigilant.resize(n)
	search.a_trample.resize(n)
	search.a_soak.resize(n)
	search.a_first.resize(n)
	search.a_immune.resize(n)
	for i in n:
		var inst := mine[i]
		search.a_pow[i] = maxi(inst.cur_power, 0)
		search.a_val[i] = Evaluator.permanent_value(inst)
		search.a_id[i] = inst.id
		search.a_can_attack[i] = 1 if candidates.has(inst) else 0
		search.a_forced[i] = 1 if (candidates.has(inst) and _must_attack(inst)) else 0
		search.a_free[i] = 1
		search.a_vigilant[i] = 1 if inst.has_keyword(Mtg.Keyword.VIGILANCE) else 0
		search.a_trample[i] = 1 if inst.has_keyword(Mtg.Keyword.TRAMPLE) else 0
		search.a_soak[i] = maxi(inst.cur_toughness - inst.damage, 0)
		search.a_first[i] = 1 if inst.has_keyword(Mtg.Keyword.FIRST_STRIKE) else 0
		search.a_immune[i] = 1 if (inst.cur_indestructible
			or _shieldable(game, inst)) else 0
	search.d_pow.resize(m)
	search.d_val.resize(m)
	search.d_free.resize(m)
	search.d_can_attack.resize(m)
	search.d_trample.resize(m)
	search.d_soak.resize(m)
	search.d_first.resize(m)
	search.d_immune.resize(m)
	for j in m:
		var inst := theirs[j]
		search.d_pow[j] = maxi(inst.cur_power, 0)
		search.d_val[j] = Evaluator.permanent_value(inst)
		search.d_free[j] = 0 if inst.tapped else 1
		search.d_can_attack[j] = 1 if _could_attack_next_turn(game, inst) else 0
		search.d_trample[j] = 1 if inst.has_keyword(Mtg.Keyword.TRAMPLE) else 0
		search.d_soak[j] = maxi(inst.cur_toughness - inst.damage, 0)
		search.d_first[j] = 1 if inst.has_keyword(Mtg.Keyword.FIRST_STRIKE) else 0
		search.d_immune[j] = 1 if (inst.cur_indestructible
			or _shieldable(game, inst)) else 0
	var cells := n * m
	search.block_ours.resize(cells)
	search.block_theirs.resize(cells)
	search.we_kill.resize(cells)
	search.they_kill.resize(cells)
	search.hit_ours.resize(cells)
	search.hit_theirs.resize(cells)
	for i in n:
		for j in m:
			var cell := i * m + j
			search.block_ours[cell] = 1 if CombatState.block_illegality(
				game, theirs[j], mine[i], defender) == "" else 0
			search.block_theirs[cell] = 1 if CombatState.block_illegality(
				game, mine[i], theirs[j], pid) == "" else 0
			search.we_kill[cell] = 1 if _dies_to(game, theirs[j], mine[i]) else 0
			search.they_kill[cell] = 1 if _dies_to(game, mine[i], theirs[j]) else 0
			# The GANG half (2026-09-05): the raw damage each side lands,
			# without the first-strike clause a gang has to decide per
			# assignment — see [method _damage_after_prevention].
			search.hit_ours[cell] = _damage_after_prevention(theirs[j], mine[i])
			search.hit_theirs[cell] = _damage_after_prevention(mine[i], theirs[j])
	search.seal()
	return search


## The durable half of [method CombatState.attack_illegality]: could
## [param inst] attack us on THEIR next turn, once it has untapped and
## shed its summoning sickness and this turn's bans have expired?
func _could_attack_next_turn(game: MtgGame, inst: CardInstance) -> bool:
	if not inst.is_creature():
		return false
	if inst.has_keyword(Mtg.Keyword.DEFENDER) or inst.cur_cant_attack:
		return false
	var needs := inst.data.attack_needs_defender_land
	if needs != "" and not CombatState._controls_land_of_type(game, pid, needs):
		return false
	return true


## The profile's appetite for a bad exchange, in stat points. Aggression
## converts acceptable-loss into a threshold: 0.5 accepts even trades;
## higher accepts worse. Being ahead on board buys one more point — the
## Adaptive posture (mage-go's idea): press an advantage.
func _combat_tolerance(game: MtgGame) -> float:
	var posture := 0.0
	if Evaluator.position_score(game, pid) > 5.0:
		posture = 1.0
	return (profile.aggression - 0.5) * 6.0 + posture


## Would attacking with [param inst] be sensible against these blockers,
## judged ON ITS OWN? [param bonus] is a pump in hand the attack may count
## on. This is the per-creature half of the decision; the group half —
## how many blockers there actually ARE — is [method _choose_attack_cohort].
func _attack_is_reasonable(game: MtgGame, inst: CardInstance,
		blockers: Array[CardInstance], defender: int, bonus := Vector2i.ZERO) -> bool:
	var risk := _attack_risk(game, inst, blockers, defender, bonus)
	if risk < 0.0:
		return true   # nothing they control can legally block it
	return risk <= _combat_tolerance(game)


## THE CLOCK. What [param dmg] points to the defender's FACE are worth in
## the stat points creatures are priced in. One point of life is one point
## ([constant Evaluator.W_LIFE]) — but the LAST points of life are the
## game, so the price rises with the share of their remaining total the
## hit takes away: 2 damage is worth 2.2 against 20 life and 4.0 against
## 4. Without a term like this the AI has no reason to attack with
## anything, ever: a 2/2 is worth four points and the two damage it deals
## would be worth two, so every attack it could be blocked for looks like
## a loss. That is exactly the passivity the owner reported.
const CLOCK_WEIGHT := 1.0


func _face_damage_value(game: MtgGame, dmg: int, defender: int) -> float:
	if dmg <= 0:
		return 0.0
	var life := maxi(game.players[defender].life, 1)
	return float(dmg) * Evaluator.W_LIFE \
		* (1.0 + CLOCK_WEIGHT * float(dmg) / float(life))


## What the WHOLE declared attack [param group] is worth once the defender
## blocks it as well as it can: damage that lands (priced by [method
## _face_damage_value]) plus the blockers we kill, minus the attackers we
## lose. 0.0 is "not worth leaving home for".
##
## The defender is modelled the way a competent one plays: one blocker per
## attacker, each block taken in descending order of what it GAINS them —
## damage stopped, plus our creature when it dies, minus theirs when it
## does. Same one-blocker-per-attacker model `_damage_through_blocks`
## already uses for the lethal push, so the two agree; gang blocks and
## their combat tricks are outside it.
func _cohort_value(game: MtgGame, group: Array[CardInstance],
		blockers: Array[CardInstance], defender: int) -> float:
	var pairs: Array = []
	for blocker in blockers:
		for attacker in group:
			if CombatState.block_illegality(game, blocker, attacker, defender) != "":
				continue
			var soaked := attacker.cur_power
			if attacker.has_keyword(Mtg.Keyword.TRAMPLE):
				soaked = mini(soaked, maxi(blocker.cur_toughness - blocker.damage, 0))
			var gain := _face_damage_value(game, soaked, defender)
			if _dies_to(game, attacker, blocker):
				gain += Evaluator.permanent_value(attacker)
			if _dies_to(game, blocker, attacker):
				gain -= Evaluator.permanent_value(blocker)
			if gain <= 0.0:
				continue   # they would rather take the hit
			pairs.append({"gain": gain, "blocker": blocker, "attacker": attacker})
	pairs.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["gain"]) > float(y["gain"]))
	var blocked: Dictionary = {}
	var spent: Dictionary = {}
	for pair in pairs:
		var blocker: CardInstance = pair["blocker"]
		var attacker: CardInstance = pair["attacker"]
		if spent.has(blocker.id) or blocked.has(attacker.id):
			continue
		spent[blocker.id] = true
		blocked[attacker.id] = blocker
	var value := 0.0
	var through := 0
	for attacker in group:
		if not blocked.has(attacker.id):
			through += attacker.cur_power
			continue
		var blocker: CardInstance = blocked[attacker.id]
		if attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			through += maxi(
				attacker.cur_power - maxi(blocker.cur_toughness - blocker.damage, 0), 0)
		if _dies_to(game, attacker, blocker):
			value -= Evaluator.permanent_value(attacker)
		if _dies_to(game, blocker, attacker):
			value += Evaluator.permanent_value(blocker)
	return value + _face_damage_value(game, through, defender)


## WHICH of [param candidates] to send, judged as a GROUP.
##
## THE BUG THIS FIXES (owner's playtest, 2026-09-04 — "it does not
## calculate when to attack; I have no defence"). Selection used to ask
## each creature on its own: "can anything over there block you and win?"
## Four 2/2s facing one 3/3 each heard yes, so all four stayed home —
## though that 3/3 eats exactly ONE of them and the other six damage is
## free. The number of blockers never entered the sum, so one Hill Giant
## blanked an arbitrarily large team, and an empty-handed defender behind
## a single body was never pressed.
##
## The shape: keep every attack the per-creature filter already likes —
## that read is sound and the difficulty ladder is calibrated on it —
## then offer it the bodies it rejected, cheapest risk first, and keep the
## longest prefix whose WHOLE-GROUP exchange ([method _cohort_value]) is
## worth making. Adding only ever widens the attack, so no attack this AI
## used to make is lost, and [method _combat_tolerance] stays the one
## difficulty knob: it is the slack a marginal extra body is allowed.
func _choose_attack_cohort(game: MtgGame, candidates: Array[CardInstance],
		blockers: Array[CardInstance], defender: int) -> Array:
	var tolerance := _combat_tolerance(game)
	var risk: Dictionary = {}
	var base: Array[CardInstance] = []
	var spare: Array[CardInstance] = []
	for inst in candidates:
		if inst.cur_power <= 0:
			continue   # must-attackers are conscripted by the caller
		var r := _attack_risk(game, inst, blockers, defender)
		risk[inst.id] = r
		if r < 0.0 or r <= tolerance:
			base.append(inst)
		else:
			spare.append(inst)
	var ids: Array = []
	for inst in base:
		ids.append(inst.id)
	if spare.is_empty():
		return ids
	# Cheapest risk first, hardest hitter breaking the tie: the defender
	# spends its blocks on the WORST of what we send, so the group grows
	# in the order the risk grows.
	spare.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var ra: float = risk[a.id]
		var rb: float = risk[b.id]
		if not is_equal_approx(ra, rb):
			return ra < rb
		return a.cur_power > b.cur_power)
	var group: Array[CardInstance] = base.duplicate()
	var best_score := _cohort_value(game, group, blockers, defender)
	var slack := maxf(tolerance, 0.0)
	var best_len := 0
	for i in spare.size():
		group.append(spare[i])
		var score := _cohort_value(game, group, blockers, defender)
		# Not a break: the reward is super-linear in the damage that
		# lands, so a group can be worth less at three bodies than at
		# five. Every prefix is priced and the best one wins.
		if score > best_score - slack:
			best_score = maxf(best_score, score)
			best_len = i + 1
	for i in best_len:
		ids.append(spare[i].id)
	return ids


## Block declaration: kill-and-survive first, value trades second, chump
## blocks when life is on the line, multi-block gangs when profitable.
func _declare_blocks(game: MtgGame) -> String:
	var me := game.players[pid]
	var block_map := {}
	var used: Array[int] = []
	var free: Array[CardInstance] = []
	for inst in me.battlefield:
		if inst.is_creature() and not inst.tapped:
			free.append(inst)
	var attackers: Array[CardInstance] = []
	for id in game.combat.attackers:
		var a := game.find_instance(id)
		if a != null and a.zone == Mtg.Zone.BATTLEFIELD:
			attackers.append(a)
	# Biggest threats first.
	attackers.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	# THE PANIC LINE, and it is asked of what actually LANDS: the ladder
	# is run once with no desperation, and the residue decides both
	# whether the chump rung opens at all and whether the swing is
	# lethal, which is the one case that buys a body at any price.
	var through := _damage_after_value_blocks(game, attackers, free)
	var desperate: bool = me.life - through <= profile.chump_threshold
	var lethal_swing := through >= me.life
	block_map = _plan_blocks(game, attackers, free, desperate, used, lethal_swing)
	# Mistake injection: drop one assignment.
	if block_map.size() > 0 and game.rng.randf() < profile.mistake_chance:
		block_map.erase(block_map.keys()[game.rng.randi_range(0, block_map.size() - 1)])
	# REQUIREMENTS and RESTRICTIONS (CR 509.1c): the creatures the rules
	# order into a block go where they are ordered — every able body onto
	# a lured attacker, a Blaze of Glory conscript onto every attacker it
	# can reach — and a blocker cap (Caverns of Despair) trims the rest.
	# The engine refuses a declaration that breaks either, and before the
	# 2026-09-02 sweep a refusal fell back to NO blocks, which the same
	# requirement refused again: the declare-blockers step never ended.
	block_map = _conscript_blocks(game, block_map, free)
	# THE DECLARATION LADDER (see _declare_attacks): the plan, then the
	# requirements alone, then nothing, then — an AI/engine mismatch, a
	# bug worth hearing about — leave the game rather than freeze it.
	var err := game.declare_blockers(pid, block_map)
	if err != "":
		game.log_line("(AI block declaration refused: %s)" % err)
		block_map = _conscript_blocks(game, {}, free)
		err = game.declare_blockers(pid, block_map)
	if err != "":
		block_map = {}
		err = game.declare_blockers(pid, block_map)
	if err != "":
		push_error("AiPlayer: no legal block declaration for seat %d (%s)" % [pid, err])
		game.log_line("(AI has no legal block declaration: %s — concedes)" % err)
		game.concede(pid)
		return ""
	return "declared %d block(s)" % block_map.size()


## The block plan the tier ladder makes for these attackers: blocker id ->
## attacker id, with the blockers it spent appended to [param used].
func _plan_blocks(game: MtgGame, attackers: Array[CardInstance],
		free: Array[CardInstance], desperate: bool,
		used: Array[int], lethal_swing := false) -> Dictionary:
	var block_map := {}
	for attacker in attackers:
		var choice := _best_block_for(game, attacker, free, used, desperate,
			lethal_swing)
		for blocker_id in choice:
			block_map[blocker_id] = attacker.id
			used.append(blocker_id)
	return block_map


## THE PANIC LINE, asked of the damage that would ACTUALLY land: what
## gets through once every block worth making on its own has been made.
##
## The old reading was `life - <total power of every attacker>`, taken
## before a single block was planned, and the chump rung it opened had no
## price at all. Measured over 120 logged AI-vs-AI games, 49 of the 92
## bodies this AI threw away died in a combat it would have survived
## untouched — 31 of them with four life or more to spare — and one of
## them was a Hypnotic Specter put under an Ironroot Treefolk at 7 life to
## stop 3 damage.
##
## [member AiProfile.chump_threshold] keeps its meaning and its direction:
## the larger number still panics earlier, so the ladder is unchanged.
##
## A blocker with no toughness left to spend counts as no block here,
## which reads the swing as more dangerous than it is — the safe way to
## be wrong about a body that is about to die anyway.
func _damage_after_value_blocks(game: MtgGame, attackers: Array[CardInstance],
		free: Array[CardInstance]) -> int:
	var trial_used: Array[int] = []
	var trial := _plan_blocks(game, attackers, free, false, trial_used)
	var through := 0
	for attacker in attackers:
		var stopped := 0
		for blocker_id in trial:
			if int(trial[blocker_id]) != attacker.id:
				continue
			var blocker := game.find_instance(int(blocker_id))
			if blocker != null:
				stopped += maxi(blocker.cur_toughness - blocker.damage, 0)
		if stopped == 0:
			through += attacker.cur_power
		elif attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			through += maxi(attacker.cur_power - stopped, 0)
	return through


## [param block_map] with every block REQUIREMENT written in and the
## blocker cap applied — the declaration the engine will accept, or as
## near to one as the rules allow. Values stay a single attacker id where
## a creature blocks one attacker and become an Array where it blocks
## more, the two shapes [method MtgGame.declare_blockers] reads.
func _conscript_blocks(game: MtgGame, block_map: Dictionary,
		free: Array[CardInstance]) -> Dictionary:
	var out := block_map.duplicate()
	var lured: Array[CardInstance] = []
	for id in game.combat.attackers:
		var a := game.find_instance(id)
		if a != null and a.zone == Mtg.Zone.BATTLEFIELD and a.cur_must_be_blocked:
			lured.append(a)
	# "All creatures able to block it do so" (Lure): blocking some OTHER
	# attacker does not satisfy it, so a planned block makes way — unless
	# it is itself a lure, which the rules cannot ask a creature to leave.
	for lure in lured:
		for inst in free:
			if lure.cur_must_be_blocked_filter.is_valid() \
					and not bool(lure.cur_must_be_blocked_filter.call(inst)):
				continue
			if CombatState.block_illegality(game, inst, lure, pid) != "":
				continue
			_add_block(game, out, inst, lure.id, lured)
	# "It blocks each attacking creature this turn if able" (Blaze of
	# Glory): every attacker it may legally block, up to its allowance.
	for inst in free:
		if not inst.must_block_this_turn:
			continue
		for id in game.combat.attackers:
			var a := game.find_instance(id)
			if a == null or a.zone != Mtg.Zone.BATTLEFIELD \
					or CombatState.block_illegality(game, inst, a, pid) != "":
				continue
			_add_block(game, out, inst, a.id, [])
	# The cap is a RESTRICTION and beats every requirement (CR 509.1c /
	# 508.1d): the ordered blockers stay first, the planned ones fill up.
	var cap: int = game.max_blockers
	if cap > 0 and out.size() > cap:
		var keep := {}
		for blocker_id in out:
			if keep.size() >= cap:
				break
			var inst := game.find_instance(int(blocker_id))
			if inst != null and (inst.must_block_this_turn
					or _blocks_a_lure(out[blocker_id], lured)):
				keep[blocker_id] = out[blocker_id]
		for blocker_id in out:
			if keep.size() >= cap:
				break
			if not keep.has(blocker_id):
				keep[blocker_id] = out[blocker_id]
		out = keep
	return out


## Write [param blocker] blocking [param attacker_id] into [param map]. At
## the blocker's allowance ([method MtgGame.blocks_allowed]) a planned
## block against an attacker that is NOT in [param lured] makes way; one
## that is stays, and the new block is dropped instead.
func _add_block(game: MtgGame, map: Dictionary, blocker: CardInstance,
		attacker_id: int, lured: Array[CardInstance]) -> void:
	var against: Array = []
	var cur: Variant = map.get(blocker.id)
	if cur is Array:
		against = (cur as Array).duplicate()
	elif cur != null:
		against = [int(cur)]
	if against.has(attacker_id):
		return
	var allowed := game.blocks_allowed(blocker)
	while allowed >= 0 and against.size() >= allowed:
		var made_way := false
		for i in against.size():
			if not _blocks_a_lure(against[i], lured):
				against.remove_at(i)
				made_way = true
				break
		if not made_way:
			return
	against.append(attacker_id)
	map[blocker.id] = against[0] if against.size() == 1 else against


## Does a block map value ([param value]: one attacker id or an Array of
## them) include a lured attacker?
static func _blocks_a_lure(value: Variant, lured: Array[CardInstance]) -> bool:
	var ids: Array = value if value is Array else [int(value)]
	for a in lured:
		if ids.has(a.id):
			return true
	return false


## Blocker ids (0, 1, or 2 of them) to throw at one attacker.
func _best_block_for(game: MtgGame, attacker: CardInstance,
		free: Array[CardInstance], used: Array[int], desperate: bool,
		lethal_swing := false) -> Array[int]:
	var legal: Array[CardInstance] = []
	for inst in free:
		if used.has(inst.id):
			continue
		if CombatState.block_illegality(game, inst, attacker, pid) == "":
			legal.append(inst)
	if legal.is_empty():
		return []
	var attacker_value := Evaluator.permanent_value(attacker)
	var tramples := attacker.has_keyword(Mtg.Keyword.TRAMPLE)
	# 1) Kill it and live — always take it. First strike and shields are
	#    in _dies_to: a 2/2 first striker kills the 2/2 that blocks it and
	#    lives; a regenerator of theirs is not "killed" by anything.
	for blocker in legal:
		if _dies_to(game, attacker, blocker) and not _dies_to(game, blocker, attacker):
			return [blocker.id]
	# 1.5) Free absorb: a wall (or other no-attack body) that survives the
	#      hit soaks the damage at zero cost — what walls are FOR. Only
	#      defenders/zero-power bodies volunteer; real attackers stay free.
	for blocker in legal:
		if not tramples and not _dies_to(game, blocker, attacker) \
				and (blocker.has_keyword(Mtg.Keyword.DEFENDER) or blocker.cur_power == 0):
			return [blocker.id]
	# 1.6) A regenerator of ours with the shield mana open soaks it for the
	#      price of the shield — the Drudge Skeletons play (mage-go
	#      combat.go: a blocker that can regenerate blocks freely).
	for blocker in legal:
		if not tramples and blocker.controller_id == pid \
				and _damage_from(attacker, blocker) >= blocker.cur_toughness - blocker.damage \
				and _can_shield(game, blocker):
			return [blocker.id]
	# 1.7) Safe block: the blocker lives through the hit and the hit was
	#      worth stopping (two or more, or we are in the red). Not for a
	#      trampler, whose surplus lands on us anyway.
	if attacker.cur_power >= 2 or desperate:
		for blocker in legal:
			if not tramples and not _dies_to(game, blocker, attacker):
				return [blocker.id]
	# 2) Value trade: we both die, their creature was worth at least ours.
	for blocker in legal:
		if _dies_to(game, attacker, blocker) \
				and Evaluator.permanent_value(blocker) <= attacker_value + 0.5:
			return [blocker.id]
	# 3) Gang up: two blockers whose combined damage kills it, if their
	#    combined worth isn't wildly above the prize.
	if not _shieldable(game, attacker) and not attacker.cur_indestructible:
		for i in legal.size():
			for j in range(i + 1, legal.size()):
				if _damage_from(legal[i], attacker) + _damage_from(legal[j], attacker) \
						>= attacker.cur_toughness - attacker.damage:
					var price := Evaluator.permanent_value(legal[i]) \
						+ Evaluator.permanent_value(legal[j])
					if price <= attacker_value * 1.5 or desperate:
						return [legal[i].id, legal[j].id]
	# 4) Chump: only when the race says so — throw the cheapest body, and
	#    (since the 2026-09-04 block audit) only when the life it buys is
	#    worth more than the body it spends. A chump that does not save
	#    the game is a trade of stat points for life points, and those
	#    have a shared price already: [method _face_damage_value], read
	#    from OUR side of the table. `lethal_swing` — the residue after
	#    the value blocks would finish us — buys anything at any price,
	#    because the alternative is losing.
	if desperate:
		var cheapest: CardInstance = legal[0]
		for blocker in legal:
			if Evaluator.permanent_value(blocker) < Evaluator.permanent_value(cheapest):
				cheapest = blocker
		if not lethal_swing:
			var stopped := attacker.cur_power
			if tramples:
				stopped = mini(stopped,
					maxi(cheapest.cur_toughness - cheapest.damage, 0))
			if _face_damage_value(game, stopped, pid) \
					< Evaluator.permanent_value(cheapest):
				return []
		return [cheapest.id]
	return []


# ============================================================ mana planning --

## Plan which sources to tap (and which ability index) to pay [param cost]
## with X = [param x_value]. Empty plan = unaffordable (a free cost returns
## an empty plan too — check _cost_is_free). Preference order: single-color
## sources before duals/any-color (save flexibility), plain producers
## before sacrifice ones (save the Lotus).
## Build a tap plan for [param cost]: [[permanent, ability_index], ...].
## Empty = the cost can't be covered right now.
##
## Reads LIVE mana abilities (cur_mana_abilities), because that is what
## MtgGame.tap_for_mana activates — a plan built from the printed list taps
## a Blood Mooned dual for {R} while believing it made {G}, and the cast
## then bounces off the engine with the lands already spent. Abilities the
## planner cannot pay for on the spot (a mana cost of their own, a life
## cost, a "sacrifice another X" rider) are skipped for the same reason;
## "sacrifice this permanent" (Black Lotus, Coal Golem) is kept but sorted
## last, since the plan CAN pay that.
##
## THE PLANNER ITSELF NOW LIVES IN [ManaPlanner] (`engine/mana_planner.gd`),
## moved there on 2026-09-03 so the HUMAN seat's auto-cast can use the same
## one — the 1997 double-click that *"takes the casting cost from your
## available mana sources automatically"* (`Duel.hlp`, topic **Spells**).
## Everything below is a thin seat-bound wrapper; the reasoning, and the
## decompilation evidence that 1997 auto-tapped at all, are in that file.
func _plan_taps(game: MtgGame, cost: ManaCost, x_value: int,
		usage_keys: Array = []) -> Array:
	return ManaPlanner.plan(game, pid, cost, x_value, usage_keys,
		_pain_excluded(game))


## The untapped mana sources available right now — [method
## ManaPlanner.sources] for this agent's seat. Built ONCE per decision and
## passed to [method _plan_taps_from], because one "what should I cast?"
## pass plans a cost for every card in hand.
func _mana_sources(game: MtgGame) -> Array:
	return ManaPlanner.sources(game, pid, _pain_excluded(game),
		profile.minds_pain)


## THE SOURCE THAT WOULD KILL US, left out of the plan — `{id: true}`,
## the same shape as the 1997 `Don't auto tap this card` mark.
##
## A City of Brass makes any colour for a life a tap ([member
## ManaAbility.pain]), and to the planner every point of mana was
## equally free. Most of those lives are the card's own trade — a colour
## the deck lacks, at a life — and the planner leaves them to the sort
## ([method ManaPlanner.cheapest_source_first]: the painless source
## first) and to the price [method _try_activate] charges an ability for
## them. The one it never pays is the LAST: a tap whose damage meets our
## life total is the game, whatever it buys, and the engine would let it
## happen. Gated by [member AiProfile.minds_pain], so the Deck Lab can
## run the null.
##
## MEASURED (2026-09-06, 2,000 games a pair, same seeds, the candidate
## on one seat against `wizard:minds_pain=off` on both): The Deck against
## White Knights 6.2% -> 7.1%, against Big Green 12.6% -> 13.1%; Saltrem
## Tor (four Cities) flat in the mirror and against Big Green. A first
## cut that REFUSED every painful source at the sink measured the same
## within noise (7.2% / 13.4%) but would not draw a card off a Jayemdae
## Tome through a City at 20 life, which is plainly the trade to make —
## so the sink prices the life instead. The instrumented run put The
## Deck's self-inflicted damage at 3.3 a game against 17 from the
## opponent: a tax, not the loss, and the 96% is the matchup (The Abyss
## cannot target a White Knight), not the mana.
func _pain_excluded(game: MtgGame) -> Dictionary:
	var out: Dictionary = {}
	if not profile.minds_pain:
		return out
	var life := game.players[pid].life
	for inst in game.players[pid].battlefield:
		if inst.tapped or inst.cur_mana_abilities.is_empty():
			continue
		for ability in inst.cur_mana_abilities:
			if int(ability.pain) > 0 and int(ability.pain) >= life:
				out[inst.id] = true
				break
	return out


## [method _plan_taps] against a pre-built source list.
func _plan_taps_from(sources: Array, cost: ManaCost, x_value: int,
		usage_keys: Array = []) -> Array:
	return ManaPlanner.plan_from(sources, cost, x_value, usage_keys)


## [param extra]: additional generic mana on top of the printed cost — the
## caller passes the current surcharge (game.spell_/ability_surcharge).
## [param usage_keys]: see [method ManaPlanner.plan_from].
func _plan_and_pay(game: MtgGame, cost: ManaCost, extra := 0,
		usage_keys: Array = []) -> bool:
	return ManaPlanner.plan_and_pay(game, pid, cost, extra, usage_keys,
		_pain_excluded(game))


func _cost_is_free(cost: ManaCost) -> bool:
	return ManaPlanner.cost_is_free(cost)


## [param sources]: a pre-built mana-source list (see [method _mana_sources]).
func _max_affordable_x(game: MtgGame, cost: ManaCost, extra := 0,
		sources: Array = [], x_color := 0, usage_keys: Array = []) -> int:
	return ManaPlanner.max_affordable_x(game, pid, cost, extra, sources,
		x_color, usage_keys, _pain_excluded(game))


# =============================================================== targeting --

## Effects the v1 AI recognizes as reactive and never main-phase casts.
## A modal card with ANY counter mode (Blue/Red Elemental Blast) is held
## too — its reactive use is nearly always worth more than its sorcery use.
func _is_reactive(data: CardData) -> bool:
	if _is_counterspell(data):
		return true
	for e in data.spell_effects:
		if e is CounterEffect:
			return true
	for m in data.modes:
		for e in m["effects"]:
			if e is CounterEffect:
				return true
	return data.card_name == "Fog"


## The mode this AI would cast a modal card with right now: the card's own
## ai_mode_picker when it has one (clamped defensively), else mode 0.
func _pick_mode(game: MtgGame, data: CardData) -> int:
	if not data.is_modal():
		return 0
	if data.ai_mode_picker.is_valid():
		return clampi(int(data.ai_mode_picker.call(game, pid)), 0, data.modes.size() - 1)
	return 0


## Pick targets for a cast, or null when a targeted card has no target
## worth spending it on. Harmful effects aim at the enemy's best; helpful
## ones at our own best (or ourselves).
func _choose_targets(game: MtgGame, inst: CardInstance, x_value: int, mode := 0):
	var effects: Array = inst.data.spell_effects
	if inst.data.is_modal():
		effects = inst.data.modes[mode]["effects"]
	var specs: Array[TargetSpec] = []
	if inst.data.is_aura():
		specs = [inst.data.aura_target]
	else:
		for e in effects:
			if e.target_spec != null:
				specs.append(e.target_spec)
	var targets: Array = []
	var effect_index := 0
	for spec in specs:
		var effect: EffectBase = null
		if not inst.data.is_aura():
			# Pair the spec back to its effect for intent classification.
			var seen := 0
			for e in effects:
				if e.target_spec != null:
					if seen == effect_index:
						effect = e
						break
					seen += 1
		# A SLOT THAT IS NOT OURS TO FILL. "… random target creatures"
		# (Orcish Catapult) is rolled by the game and "… of an opponent's
		# choice" is named by them, both AFTER every refusal (CR 601.2c) —
		# the caster supplies nothing, and TargetPlan refuses a caster who
		# supplies something anyway. This loop used to pick for them like
		# any other slot, which is how the Catapult tapped twenty lands
		# for a cast that could never be announced.
		#
		# It is also the one shape this AI cannot AIM, so a spell whose
		# only targets are rolled onto both sides of the table is left in
		# hand rather than fired blind. That is not a guess: 400 Orcish
		# Catapults for X=4 rolled over symmetric three-creature boards
		# put 794 of their 1,600 counters on OUR OWN creatures (49.6%),
		# and 35% of the volleys hurt us more than them. A one-ply
		# heuristic has no way to price a coin flip, and nothing in the
		# shipped deck pool holds one — the leak is what mattered.
		if spec.chosen_at_random or spec.chosen_by_opponent:
			if spec.chosen_at_random and _roll_can_hit_us(game, inst, spec, x_value):
				return null
			effect_index += 1
			continue
		# "Any number of target …" (Drafna's Restoration): take everything
		# that qualifies, and don't bother casting for nothing.
		if effect != null and effect.target_min == 0 and effect.target_max < 0 \
				and not effect.target_count_is_x:
			var all_of_them := _extra_targets(game, inst, spec, effect,
				game.legal_targets_at(spec, inst, x_value, targets).size(),
				targets, x_value)
			if all_of_them.is_empty():
				return null
			targets.append_array(all_of_them)
			effect_index += 1
			continue
		var choice := _pick_for_spec(game, inst, spec, effect, x_value, targets)
		if choice == null:
			return null
		targets.append(choice)
		# VARIABLE-count effects (Word of Binding's X creatures) want more
		# than one ref; without them the engine refuses the cast and the AI
		# would keep re-picking the same dead-end card. Divided effects are
		# left at ONE target, which TargetPlan lets absorb the whole total.
		if effect != null:
			var span: Vector2i = effect.target_range(x_value)
			if span.x > 1 and effect.divided_amount(x_value) <= 0:
				for extra in _extra_targets(game, inst, spec, effect,
						span.x - 1, targets, x_value):
					targets.append(extra)
		effect_index += 1
	return targets


## Could the roll behind a [member TargetSpec.chosen_at_random] slot land
## on one of OUR permanents? See the note in [method _choose_targets].
func _roll_can_hit_us(game: MtgGame, source: CardInstance, spec: TargetSpec,
		x_value: int) -> bool:
	for ref in game.legal_targets_at(spec, source, x_value):
		if ref.is_player:
			if ref.player_id == pid:
				return true
			continue
		var inst := game.find_instance(ref.instance_id)
		if inst != null and inst.controller_id == pid:
			return true
	return false


## Additional distinct targets for a variable-count effect, best first.
func _extra_targets(game: MtgGame, source: CardInstance, spec: TargetSpec,
		effect: EffectBase, want: int, chosen: Array, x_value := 0) -> Array:
	var out: Array = []
	if want <= 0:
		return out
	var harmful := _is_harmful(source, effect)
	var tap_only := effect != null \
		and EffectIntent.read([effect], source.data.card_name).is_tap_utility()
	# Harmful effects work down the opponent's board first, helpful ones
	# down our own — the same intent split _pick_for_spec uses.
	var wanted_pid := game.opponent_of(pid) if harmful else pid
	var preferred: Array = []
	var rest: Array = []
	for ref in game.legal_targets_at(spec, source, x_value, chosen):
		var already := false
		for c in chosen:
			if c.same_object(ref):   # the whole union, damage included (§6.8)
				already = true
		if already:
			continue
		var owner_pid := ref.player_id
		if not ref.is_player:
			var found := game.find_instance(ref.instance_id)
			owner_pid = -1 if found == null else found.controller_id
			# The tap policy applies to every slot of "tap X target
			# creatures", not just the first (Word of Binding).
			if tap_only and not _tap_denies_something(game, found):
				continue
		if owner_pid == wanted_pid:
			preferred.append(ref)
		else:
			rest.append(ref)
	for ref in preferred + rest:
		if out.size() >= want:
			break
		out.append(ref)
	return out


## [param earlier] is the refs already picked for the slots before this
## one — a slot stated relative to them (TargetSpec.sibling_filter) is
## judged against them, the way the engine will judge the whole choice.
func _pick_for_spec(game: MtgGame, source: CardInstance, spec: TargetSpec,
		effect: EffectBase, x_value: int, earlier: Array = []) -> TargetRef:
	var harmful := _is_harmful(source, effect)
	var opponent := game.opponent_of(pid)
	if spec.kind == TargetSpec.Kind.PLAYER:
		# Harmful player effects hit them; draws/gains point home — but the
		# SEAT is only the preference. "Target player who attacked this
		# turn" (Fire and Brimstone, TargetSpec.player_filter) is a
		# targeting restriction like any other, and this line used to hand
		# the seat over without asking it: the planner tapped five lands
		# and the engine refused the cast.
		var seat := opponent if harmful else pid
		if not game.target_legal_at(spec, TargetRef.player(seat), source,
				x_value, earlier):
			return null
		return TargetRef.player(seat)
	if spec.kind == TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD \
			or spec.kind == TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD \
			or spec.kind == TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD:
		# Any-graveyard reanimation shops BOTH graveyards — stealing the
		# opponent's dead dragon beats raising our own bear.
		var graveyards: Array = [game.players[pid].graveyard]
		if spec.kind == TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD:
			graveyards.append(game.players[opponent].graveyard)
		var best_dead: CardInstance = null
		for pile in graveyards:
			for dead in pile:
				if game.target_legal_at(spec, TargetRef.card(dead), source, x_value, earlier) \
						and (best_dead == null
							or Evaluator.card_value(dead.data) > Evaluator.card_value(best_dead.data)):
					best_dead = dead
		# A Regrowth for a Forest is a Regrowth wasted: wait for a card that
		# is worth the card (a land only when we are short of them).
		if best_dead != null and Evaluator.card_value(best_dead.data) < 2.5 \
				and not (best_dead.is_land() and _land_light(game)):
			return null
		return null if best_dead == null else TargetRef.card(best_dead)
	if spec.kind == TargetSpec.Kind.SPELL \
			or spec.kind == TargetSpec.Kind.ABILITY:
		return null   # reactive — filtered out before this point
	# Battlefield targets: enemy best for harm, own best for help.
	var intent: EffectIntent = null
	if effect != null:
		intent = EffectIntent.read([effect], source.data.card_name)
	var pool_pid := opponent if harmful else pid
	var pools: Array = [pool_pid]
	# THE SIDE OF THE TABLE, WHEN THE READER ONLY GUESSED IT. A card-local
	# effect the reader has no model for is assumed removal-shaped
	# ([method EffectIntent.is_harmful]'s last line), so the picker shops
	# the opponent's battlefield — and a card whose SPEC says "creature you
	# control" then finds nothing there and is never cast at all
	# (Simulacrum, Energy Tap, Glyph of Destruction, none of them cast in
	# any logged game). When the guess comes up empty and the spec carries
	# its own source filter, the filter is the better authority: look at
	# our side before giving up. A KNOWN harmful effect never reaches this
	# — only one the reader could not classify.
	if harmful and intent != null and intent.unknown \
			and spec.source_filter.is_valid():
		pools.append(game.opponent_of(pool_pid))
	if spec.sibling_filter.is_valid() and not earlier.is_empty():
		# A slot bound to an earlier pick names that pick's PARTNER (the
		# Wall that blocked it, the permanent that shares its type), and
		# the partner may sit on either side of the table.
		pools.append(game.opponent_of(pool_pid))
	var best: CardInstance = null
	var best_value := -1.0
	for scan_pid in pools:
		for inst in game.players[scan_pid].battlefield:
			var ref := TargetRef.card(inst)
			if not game.target_legal_at(spec, ref, source, x_value, earlier):
				continue
			if _already_chosen(ref, earlier):
				continue   # "two target creatures" are two DIFFERENT ones (CR 601.2c)
			# Don't waste damage — fixed or X — on what it can't kill.
			if harmful and intent != null and intent.damage_at(x_value) > 0 \
					and inst.is_creature() and not intent.kills(inst, x_value):
				continue
			# ...and don't waste a TAP on what it costs nothing to tap.
			if intent != null and intent.is_tap_utility() \
					and not _tap_denies_something(game, inst):
				continue
			# Their permanents by what taking them costs THEM (a Stone
			# Rain on the only Swamp, not the fourth Mountain); ours by
			# the flat board scale.
			var value := _victim_value(game, inst) if harmful \
				else Evaluator.permanent_value(inst)
			if value > best_value:
				best = inst
				best_value = value
		if best != null:
			break
	if best != null:
		return TargetRef.card(best)
	# Harmful any-target with no creature worth hitting: go to the face if
	# the spec allows players.
	if harmful and spec.kind == TargetSpec.Kind.ANY \
			and game.target_legal_at(spec, TargetRef.player(opponent), source,
				x_value, earlier):
		return TargetRef.player(opponent)
	return null


## Is [param ref] already among the refs picked for the earlier slots?
static func _already_chosen(ref: TargetRef, earlier: Array) -> bool:
	for c in earlier:
		if c.same_object(ref):
			return true
	return false


func _is_harmful(source: CardInstance, effect: EffectBase) -> bool:
	if effect != null and effect.ai_helpful:
		return false   # the card said so (EffectBase.helpful)
	if source.data.is_aura():
		# AN AURA HAS NO SPELL EFFECTS. Everything it does lives in
		# Callables this code cannot look inside, so which side of the
		# table it belongs on is stated as DATA, in one place, for the
		# whole pool: [method EffectIntent.aura_aim]. This used to be a
		# four-name list inlined right here, which made the other 73 auras
		# in the pool "helpful" and aimed every one of them at our own
		# board — Psychic Venom on our own Island included (2026-09-04).
		return EffectIntent.aura_aim(source.data) == EffectIntent.Aim.HOSTILE
	if effect is DamageEffect or effect is DestroyEffect or effect is TapEffect \
			or effect is MillEffect:
		return true
	if effect is DrawEffect or effect is GainLifeEffect or effect is UntapEffect \
			or effect is PumpEffect:
		return false
	# Card-local custom effects: ask the READER, which knows the ones the
	# CARD_LOCAL table names (a Twiddle taps, so it points across the
	# table) and falls back to removal-shaped for the rest — the common
	# case in this pool (Swords, Psionic Blast, Drain Life...).
	return EffectIntent.read([effect], source.data.card_name).is_harmful()


# ================================================ the 1997 damage windows --
#
# `Duel.hlp`, topic **Damage Dealing**: *"any damage dealing step during
# which damage is dealt is followed by a damage prevention step, during
# which both players can use effects that prevent and redirect damage.
# also, creatures killed or destroyed during combat can be regenerated."*
# Two windows, two questions, and until this landed the AI answered both
# with "no" — which made the fork a one-sided buff rather than a ruleset
# (`docs/ROADMAP.md`, closed 2026-09-01).
#
# ALL of it scales off [AiProfile] and nothing else. There is no second
# difficulty concept and no knob of its own:
#   * `holds_instants` decides whether this seat uses the window AT ALL;
#   * `mistake_chance` fumbles a window the same way it fumbles a cast;
#   * `chump_threshold` is the life line at which damage to the face is
#     worth a card, because that is already what it means;
#   * `aggression` tilts that line, because it already tilts every other
#     risk this file takes.
# Every roll is on `game.rng`, so a seeded duel replays its windows.


## Does this seat want the 1997 damage-prevention window (§6.8)?
##
## [member AiProfile.holds_instants] and nothing else, because the window
## IS the reactive game: a priority round in the middle of damage whose
## only legal actions are fast effects. The Apprentice's whole feel is
## phase-1, my-turn-only Magic (`holds_instants = false`), so it plays on
## under the modern automatic prevention even with the fork on — a
## weakness, exactly like the counterspells it also never holds up, and
## not a different set of rules.
func wants_damage_prevention_window() -> bool:
	return profile.holds_instants


## ONE ANSWER AT A TIME. An answer this seat has already put on the chain
## has not resolved yet, so nothing it changes is visible: the packet still
## reads its full [method DamagePacket.remaining], and the creature still
## has no regeneration shield. Without this the AI would buy the same
## prevention over and over until its mana ran out — legal (*"you may use
## the Circle on the same damage more than once"*) and pure waste. Let it
## resolve; the window is still open on the other side, `_open_priority`
## runs again inside it, and the numbers will have moved.
func _answer_on_the_chain(game: MtgGame, prevention: bool) -> bool:
	for item in game.stack:
		if item.controller != pid or item.effects.is_empty():
			continue
		var all_of_the_family := true
		for e in item.effects:
			var fits: bool = e.is_damage_prevention if prevention \
				else e.is_regeneration
			if not fits:
				all_of_the_family = false
				break
		if all_of_the_family:
			return true
	return false


## One action inside whichever window is open, or "" to leave it.
func _window_action(game: MtgGame) -> String:
	# One mistake roll per priority round in the window. A fumbled window
	# is a window nobody used, which is what a weak player's damage step
	# actually looks like — the same shape as `_respond_action`'s roll.
	if profile.mistake_chance > 0.0 and game.rng.randf() < profile.mistake_chance:
		return ""
	if game.awaiting_regeneration:
		return _regeneration_action(game)
	return _prevention_action(game)


# ------------------------------------------------------------ prevention --

## Answer the WORST waiting packet we can afford to answer, or "".
## Worst first, then down the list — the biggest packet may be one nothing
## in hand can touch (a Circle of Protection: Red against a green Wurm)
## while the one beside it is exactly answerable.
func _prevention_action(game: MtgGame) -> String:
	if _answer_on_the_chain(game, true):
		return ""
	var ranked: Array = []
	for packet in game.damage_pending:
		var worth := _packet_worth(game, packet)
		if worth > 0.0:
			ranked.append({"packet": packet, "worth": worth})
	# The packet id breaks ties: `sort_custom` is not stable, and a
	# seeded duel has to replay its windows line for line.
	ranked.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a["worth"]), float(b["worth"])):
			return float(a["worth"]) > float(b["worth"])
		return (a["packet"] as DamagePacket).id < (b["packet"] as DamagePacket).id)
	for row in ranked:
		var did := _spend_on_packet(game, row["packet"], float(row["worth"]))
		if did != "":
			return did
	return ""


## What answering [param packet] is worth to this seat, in the same "stat
## points" [Evaluator] prices everything else in; 0 means "not ours, or not
## worth a card".
##
## The two victims are judged differently on purpose:
##  * DAMAGE TO US is worth answering when it takes us to the profile's own
##    panic line or below — [member AiProfile.chump_threshold] already
##    means *"how low before I start spending bodies to survive"*, and this
##    is the same question one step earlier. Above the line, 20 life can
##    afford three damage and a Circle is worth more next turn.
##  * DAMAGE TO OUR CREATURE is worth answering only when it would actually
##    KILL it. "Not speculatively" is the brief's word and `Duel.hlp`'s
##    sense: a 6/4 that takes 2 has lost nothing the prevention step could
##    have saved.
func _packet_worth(game: MtgGame, packet: DamagePacket) -> float:
	if packet == null or packet.target == null or packet.remaining() <= 0:
		return 0.0
	var uncovered := _uncovered(game, packet)
	if uncovered <= 0:
		return 0.0                # a pool already answers it
	if packet.target.is_player:
		if packet.target.player_id != pid:
			return 0.0            # the opponent's damage is their problem
		var after: int = game.players[pid].life - uncovered
		if after <= 0:
			return LETHAL_WORTH   # nothing else on the table matters
		# THE PANIC LINE, tilted by aggression. `1.5 - aggression` is 1.0 at
		# the balanced 0.5, so the Sorcerer and Wizard use their threshold
		# as printed; the Magician's 0.6 shaves it to 4 x 0.9 = 3.6 and a
		# recklessly high aggression would shave it further. The tilt runs
		# the same direction it does in combat: more aggression, less
		# defending.
		if after > profile.chump_threshold * (1.5 - profile.aggression):
			return 0.0
		return uncovered * Evaluator.W_LIFE + FACE_URGENCY
	var inst := game.find_instance(packet.target.instance_id)
	if inst == null or inst.controller_id != pid \
			or inst.zone != Mtg.Zone.BATTLEFIELD:
		return 0.0
	if inst.cur_indestructible or inst.cur_toughness <= 0:
		return 0.0
	if inst.damage + uncovered < inst.cur_toughness:
		return 0.0                # it survives: nothing to save
	return Evaluator.permanent_value(inst)


## What a packet that KILLS US is worth. Bigger than anything
## [Evaluator] can price, because there is no next turn to spend the card
## in.
const LETHAL_WORTH := 1000.0

## What crossing the panic line is worth on top of the life itself — the
## value of one middling creature ([method Evaluator.permanent_value] of a
## 2/2 is 4.0), so a Circle activation clears the price of a card by the
## time we are that low.
const FACE_URGENCY := 4.0


## Spend the CHEAPEST effect that actually covers [param packet], or "".
##
## Two families reach a packet that is already on the table:
##  * one that TARGETS THE DAMAGE — the Circles of Protection, whose 1997
##    form names exactly one packet;
##  * a prevention POOL aimed at that packet's victim (Healing Salve's
##    second mode, Samite Healer), which `_land_damage` draws down when the
##    window closes.
##
## Everything else the window ALLOWS is deliberately skipped, and the
## instructive one is a whole-combat Fog: `PreventCombatDamageEffect`
## raises `MtgGame.combat_damage_prevented`, which the damage STEP reads
## before each wave — so a Fog cast in a window stops the wave that has not
## happened yet and does nothing at all to the packets already waiting. An
## AI that spent one here would be throwing the card away.
##
## [param worth] is what answering this packet is worth (see
## [method _packet_worth]); a card out of HAND has to be worth less than
## that to be spent, while a repeatable activated ability costs no card and
## only has to be affordable.
func _spend_on_packet(game: MtgGame, packet: DamagePacket, worth: float) -> String:
	var best: Dictionary = {}
	# Guardian Angel's rider on the victim: no card, {1} a point, so it is
	# priced at the points still uncovered and bought all at once.
	var victim := _victim_ref(packet)
	var rider_points := _points_to_save(game, packet)
	if rider_points > 0 and not game.paid_prevention_for(pid, victim).is_empty():
		best = {"price": float(rider_points), "inst": null, "index": -2,
			"effects": [], "mode": 0}
	for inst in game.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _effects_answer(game, ability.effects, packet, inst):
				continue
			var price: float = ability.cost.mana_value()
			if not best.is_empty() and float(best["price"]) <= price:
				continue
			best = {"price": price, "inst": inst, "index": index,
				"effects": ability.effects, "mode": 0}
	for inst in game.players[pid].hand:
		# INSTANTS only, the same gate `_cast_response` uses: the window is
		# a priority round in the middle of a step, so anything else is
		# refused by `cast_spell` AFTER `_plan_and_pay` has already tapped
		# for it.
		if not inst.is_type(Mtg.CardType.INSTANT):
			continue
		# A card is a card: only spend one when the packet is worth more
		# than the card is (the same currency the discard picker uses).
		if Evaluator.card_value(inst.data) > worth:
			continue
		var shapes: Array = [{"effects": inst.data.spell_effects, "mode": 0}]
		if inst.data.is_modal():
			shapes = []
			for m in inst.data.modes.size():
				shapes.append({"effects": inst.data.modes[m]["effects"], "mode": m})
		for shape in shapes:
			if not _effects_answer(game, shape["effects"], packet, inst):
				continue
			var price: float = inst.data.cost.mana_value()
			if not best.is_empty() and float(best["price"]) <= price:
				continue
			best = {"price": price, "inst": inst, "index": -1,
				"effects": shape["effects"], "mode": shape["mode"]}
	if best.is_empty():
		return ""
	if int(best["index"]) == -2:
		return _buy_prevention(game, victim, rider_points)
	var source: CardInstance = best["inst"]
	var targets := _window_targets(game, best["effects"], packet, source)
	if int(best["index"]) >= 0:
		var ability: ActivatedAbility = source.cur_activated_abilities[best["index"]]
		if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, source)):
			return ""
		if game.activate_ability(pid, source, best["index"], targets) != "":
			return ""
		return "prevents %d from %s with %s" % [packet.remaining(),
			_packet_source_name(packet), source.data.card_name]
	# The window's own cast asks before it pays, like every other cast in
	# this file (the class-4 fix of 2026-09-05).
	if game.cast_refusal(pid, source, targets, 0, int(best["mode"])) != "":
		return ""
	if not _plan_and_pay(game, source.data.cost, game.spell_surcharge(pid, source.data)):
		return ""
	if game.cast_spell(pid, source, targets, 0, int(best["mode"])) != "":
		return ""
	return "answers %d from %s with %s" % [packet.remaining(),
		_packet_source_name(packet), source.data.card_name]


## Can these effects, as a set, actually reduce [param packet]?
##
## Every one of them must be of the window's family — `Duel.hlp` is a
## whitelist, *"No other kind of fast effects or spells are permitted"* —
## and at least one must REACH this packet. Limited to a single effect,
## because a two-effect prevention card would need a target list this
## routine does not build; no card in the 1997 pool is one.
func _effects_answer(game: MtgGame, effects: Array, packet: DamagePacket,
		source: CardInstance) -> bool:
	if effects.size() != 1:
		return false
	var e: EffectBase = effects[0]
	if not e.is_damage_prevention:
		return false
	if e is PreventDamageShieldEffect:
		# The 1997 Circle: it names the packet, so the packet has to be one
		# it may name.
		return e.target_spec != null \
			and e.target_spec.is_legal(game, TargetRef.damage(packet), source)
	if e is PreventDamageEffect:
		# A pool on the victim. Untargeted "…dealt to you" reaches us only.
		if e.controller_mode:
			return packet.target.is_player and packet.target.player_id == pid
		return e.target_spec != null \
			and e.target_spec.is_legal(game, _victim_ref(packet), source)
	return false


## The target list for the effect chosen by [method _spend_on_packet]:
## the PACKET for a Circle, the packet's VICTIM for a pool, nothing for an
## untargeted one.
func _window_targets(game: MtgGame, effects: Array, packet: DamagePacket,
		source: CardInstance) -> Array:
	var e: EffectBase = effects[0]
	if e.target_spec == null:
		return []
	if e.target_spec.kind == TargetSpec.Kind.DAMAGE:
		return [TargetRef.damage(packet)]
	var victim := _victim_ref(packet)
	if not e.target_spec.is_legal(game, victim, source):
		return []
	return [victim]


## A fresh ref for whatever the packet is aimed at. Fresh rather than the
## packet's own, because [member TargetRef.amount] rides on that one and a
## divided effect would read it.
func _victim_ref(packet: DamagePacket) -> TargetRef:
	if packet.target.is_player:
		return TargetRef.player(packet.target.player_id)
	var ref := TargetRef.new()
	ref.instance_id = packet.target.instance_id
	return ref


func _packet_source_name(packet: DamagePacket) -> String:
	return "?" if packet.source == null else packet.source.data.card_name


## What [param packet] would still deal once the prevention POOL already
## sitting on its victim is drawn down — a Healing Salve that resolved
## earlier in this window, a Guardian Angel point bought a moment ago.
## The packet itself still reads its full [method DamagePacket.remaining]
## (pools are spent when the damage LANDS), so without this the AI would
## answer the same packet twice.
func _uncovered(game: MtgGame, packet: DamagePacket) -> int:
	var pool := 0
	if packet.target.is_player:
		pool = game.players[packet.target.player_id].damage_prevention
	else:
		var inst := game.find_instance(packet.target.instance_id)
		if inst != null:
			pool = inst.prevention
	return maxi(packet.remaining() - pool, 0)


## How many points of a per-point prevention (Guardian Angel's rider)
## turn [param packet] from a loss into nothing lost: for a creature the
## points that keep it at less than lethal damage, for us the whole of
## what is uncovered — the same whole-packet answer a Circle gives, since
## the packet is only worth answering at the panic line or below.
func _points_to_save(game: MtgGame, packet: DamagePacket) -> int:
	var uncovered := _uncovered(game, packet)
	if uncovered <= 0:
		return 0
	if packet.target.is_player:
		return uncovered
	var inst := game.find_instance(packet.target.instance_id)
	if inst == null:
		return 0
	return clampi(inst.damage + uncovered - inst.cur_toughness + 1, 0, uncovered)


# ---------------------------------------------------------- regeneration --

## `Duel.hlp`, topic **Regeneration**: *"You can use regeneration ONLY at
## the time when a creature is about to go to the graveyard."* So this
## never shields speculatively — the engine has already worked out who is
## dying and put them in [member MtgGame.regeneration_candidates], and this
## saves the most valuable of ours that we can pay for.
func _regeneration_action(game: MtgGame) -> String:
	if _answer_on_the_chain(game, false):
		return ""
	var doomed: Array[CardInstance] = []
	for id in game.regeneration_candidates:
		var inst := game.find_instance(id)
		if inst == null or inst.controller_id != pid:
			continue
		if inst.regeneration_shields > 0:
			continue          # already saved this window
		doomed.append(inst)
	# Instance id breaks ties, for the reason `_prevention_action` gives.
	doomed.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var va := Evaluator.permanent_value(a)
		var vb := Evaluator.permanent_value(b)
		return a.id < b.id if is_equal_approx(va, vb) else va > vb)
	for victim in doomed:
		var did := _regenerate(game, victim)
		if did != "":
			return did
	return ""


## Shield [param victim] with the cheapest regeneration this seat holds —
## its own ability first (Drudge Skeletons), then somebody else's targeted
## one (Niall Silvain), then a spell (Death Ward, whose
## `Illegal target (not dying).` is only expressible inside this window).
func _regenerate(game: MtgGame, victim: CardInstance) -> String:
	var best: Dictionary = {}
	for inst in game.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _effects_regenerate(game, ability.effects, victim, inst):
				continue
			var price: float = ability.cost.mana_value()
			if not best.is_empty() and float(best["price"]) <= price:
				continue
			best = {"price": price, "inst": inst, "index": index,
				"effects": ability.effects}
	for inst in game.players[pid].hand:
		# Instants only, for the reason `_spend_on_packet` gives; modal
		# cards are skipped because no regeneration mode exists in the pool
		# and a mode index would have to be carried to the cast.
		if not inst.is_type(Mtg.CardType.INSTANT) or inst.data.is_modal():
			continue
		if not _effects_regenerate(game, inst.data.spell_effects, victim, inst):
			continue
		# A card for a creature: only if the creature is worth more.
		if Evaluator.card_value(inst.data) > Evaluator.permanent_value(victim):
			continue
		var spell_price: float = inst.data.cost.mana_value()
		if not best.is_empty() and float(best["price"]) <= spell_price:
			continue
		best = {"price": spell_price, "inst": inst, "index": -1,
			"effects": inst.data.spell_effects}
	if best.is_empty():
		return ""
	var source: CardInstance = best["inst"]
	var effect: EffectBase = best["effects"][0]
	var targets: Array = [] if effect.target_spec == null \
		else [TargetRef.card(victim)]
	if int(best["index"]) >= 0:
		var ability: ActivatedAbility = source.cur_activated_abilities[best["index"]]
		if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, source)):
			return ""
		if game.activate_ability(pid, source, best["index"], targets) != "":
			return ""
	else:
		if game.cast_refusal(pid, source, targets) != "":
			return ""
		if not _plan_and_pay(game, source.data.cost, game.spell_surcharge(pid, source.data)):
			return ""
		if game.cast_spell(pid, source, targets) != "":
			return ""
	return "regenerates %s" % victim.data.card_name


## Would this single effect shield [param victim]? Untargeted regeneration
## shields its own source, so it only helps when the source IS the victim.
func _effects_regenerate(game: MtgGame, effects: Array, victim: CardInstance,
		source: CardInstance) -> bool:
	if effects.size() != 1:
		return false
	var e: EffectBase = effects[0]
	if not e.is_regeneration:
		return false
	if e.target_spec == null:
		return source == victim
	return e.target_spec.is_legal(game, TargetRef.card(victim), source)


# ======================================================= DecisionAgent side --

## Discard the least valuable cards. A land is the cheapest card in hand
## only once we have lands enough; short of them it outranks any spell
## we could not cast anyway.
## THE DAMAGE ASSIGNMENT ORDER (CR 509.2), which the ATTACKING player
## announces as blockers are declared. The base agent leaves it in the
## order the defender declared its blocks, which is arbitrary from this
## side of the table — and the order decides who dies whenever the
## attacker's power is short of every blocker's lethal put together.
##
## Measured over 120 logged AI-vs-AI games: 46 gang blocks, 24 of them
## order-sensitive (an Erg Raiders held by a Drudge Skeletons 1/1 and a
## Hypnotic Specter 2/2 kills whichever of them it is pointed at first).
##
## The pick is the small knapsack it looks like: choose the set of
## blockers whose lethal totals no more than the damage on offer and whose
## worth is greatest, put it first, and let [method
## MtgGame.default_damage_split]'s lethal-first walk do the rest. Bodies
## nothing can be gained from — a regenerator with its mana open, an
## indestructible one — are worth 0 here and sort to the back, so damage
## is never spent burying something that gets up again.
func order_blockers(game: MtgGame, attacker: CardInstance,
		blocker_ids: Array) -> Array:
	if blocker_ids.size() < 2:
		return blocker_ids
	var entries: Array = []
	for id in blocker_ids:
		var blocker := game.find_instance(int(id))
		if blocker == null:
			return blocker_ids
		var lethal := maxi(blocker.cur_toughness - blocker.damage, 0)
		var worth := Evaluator.permanent_value(blocker)
		if lethal <= 0 or blocker.cur_indestructible or _shieldable(game, blocker):
			worth = 0.0
		entries.append({"id": int(id), "lethal": lethal, "worth": worth})
	# The damage on offer is the whole BAND's (CR 702.22j — the engine
	# pools a band's strikes against the band's blockers and calls this
	# once, for the lead); a solo attacker is a band of one.
	var budget := 0
	for member_id in game.combat.band_of(attacker.id):
		var member := game.find_instance(int(member_id))
		if member != null and member.zone == Mtg.Zone.BATTLEFIELD:
			budget += maxi(member.cur_power, 0)
	var best_mask := 0
	var best_worth := -1.0
	var best_cost := 0
	# 2^n over the blockers on one attacker: a gang block is two or three
	# bodies, and the engine caps what may be declared long before this
	# would matter. Anything larger falls back to worth-first, which is
	# the same answer whenever every blocker fits.
	if entries.size() <= 8:
		for mask in 1 << entries.size():
			var cost := 0
			var worth_sum := 0.0
			for i in entries.size():
				if mask & (1 << i):
					cost += int(entries[i]["lethal"])
					worth_sum += float(entries[i]["worth"])
			if cost > budget:
				continue
			if worth_sum > best_worth or (is_equal_approx(worth_sum, best_worth)
					and cost < best_cost):
				best_worth = worth_sum
				best_mask = mask
				best_cost = cost
	var head: Array = []
	var tail: Array = []
	for i in entries.size():
		if best_mask & (1 << i):
			head.append(entries[i])
		else:
			tail.append(entries[i])
	var by_worth := func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["worth"]) > float(y["worth"])
	head.sort_custom(by_worth)
	tail.sort_custom(by_worth)
	var out: Array = []
	for entry in head + tail:
		out.append(int(entry["id"]))
	return out


func answer_discard(game: MtgGame, p_pid: int, count: int) -> Array[CardInstance]:
	var hand := game.players[p_pid].hand.duplicate()
	var keep_lands := p_pid == pid and _land_light(game)
	var worth := func(inst: CardInstance) -> float:
		if keep_lands and inst.is_land():
			return 5.0   # above any bear, below any angel
		return Evaluator.card_value(inst.data)
	hand.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return worth.call(a) < worth.call(b))
	var out: Array[CardInstance] = []
	for i in mini(count, hand.size()):
		out.append(hand[i])
	return out


## Tutor targets: the most valuable candidate — unless the seat is choosing
## AGAINST itself ([member PlayerChoice.adverse]: which creature a Preacher
## takes, which body steps into the Arena) or the list came RANKED for it
## ([member PlayerChoice.ordered]: a targeted trigger's candidates, which
## the card sorted from its controller's point of view), when the first is
## the answer — or the list is what a COST eats ([member
## PlayerChoice.is_cost]: "sacrifice a creature" for a Fallen Angel pump
## or a Sacrifice spell), when the LEAST valuable body goes.
func answer_card(game: MtgGame, _p_pid: int, candidates: Array[CardInstance],
		_prompt: String) -> CardInstance:
	var asked := current_choice()
	if asked != null and (asked.adverse or asked.ordered) \
			and not candidates.is_empty():
		return candidates[0]
	var paying := asked != null and asked.is_cost
	var best: CardInstance = null
	for inst in candidates:
		if best == null:
			best = inst
		elif paying:
			# The body a cost eats is priced the way [method
			# _sacrifice_price] priced it when the activation was chosen,
			# so the two cannot disagree about which land goes.
			if _own_value(game, inst) < _own_value(game, best):
				best = inst
		elif Evaluator.card_value(inst.data) > Evaluator.card_value(best.data):
			best = inst
	return best
