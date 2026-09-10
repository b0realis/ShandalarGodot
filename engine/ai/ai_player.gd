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

## THE SPLIT THE DECLARATION WAS MADE ON (2026-09-09,
## [member AiProfile.pumps_to_attack]), `{instance id: activations}` —
## how many breaths each of our bodies was priced with when the attack or
## the block was declared, and the number [method _combat_self_pumps]
## then has to deliver.
##
## WHY IT HAS TO BE REMEMBERED RATHER THAN ASKED AGAIN. [method
## _pump_shares] divides ONE mana pool among several bodies, in a fixed
## order — the body with no power at all first, then by what the
## evaluator thinks each is worth. Re-deriving that split after the first
## breath has resolved gives a DIFFERENT split, because the body that
## just bought a breath is no longer the mute one and drops down the
## order; the pool would then be re-allotted mid-combat to whichever body
## happens to be smallest, which is not the block that was declared. So
## the split is written down once, where the declaration is made, and
## spent down one activation at a time.
##
## Stamped with the turn it was made on ([method _pump_plan_for]): a plan
## older than that is no plan, and the recovery falls back to the reading
## it had before this knob existed. A stale plan can only ever hold a
## breath BACK — [method _pumps_in_reach] still prices every activation
## against the mana actually on the table — so being wrong here costs a
## pump and never an illegal one.
##
## AND IT IS DELIVERED BEFORE ANYTHING ELSE OF OURS SPENDS THE POOL
## (2026-09-10): [method _combat_planned_pumps] runs ahead of the
## pre-emptive regeneration shield, which is the one spender that was
## measurably breaking it. See that method for the reproduction and for
## what an opponent can still take away.
var _pump_plan: Dictionary = {}
var _pump_plan_turn := -1


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
	# THE LIFE ALREADY SOLD (2026-09-10, AiProfile.reads_lethal_x): a
	# life-for-mana grant is open and the burn in hand ends the game with
	# it. Asked before the ranking, because no ranking prices a win.
	var channelled := _lethal_life_mana(game)
	if channelled != "":
		return channelled
	var cast := _try_cast_best(game)
	if cast != "":
		return cast
	return _try_activate(game)


# ------------------------------------------------- develop after combat --
#
# DEVELOP AFTER COMBAT (2026-09-10, [member AiProfile.develops_late];
# `docs/forge/casting.md` P1). The four functions below are the whole of
# the row: when the hold is on, what Main 1 may still do, whether one
# cast or activation changes the combat that is about to happen, and
# whether the LAND stays in hand.


## Is this the main phase whose development waits? True only in OUR OWN
## first main step, under the knob — everything here is a question about
## the combat that has not happened yet, and after it there is none.
func _develops_late(game: MtgGame) -> bool:
	return profile.develops_late and game.active_player == pid \
		and game.current_step() == Mtg.Step.MAIN1


## FORGE'S MAIN-1 LIST, read off the reader instead of off a card's
## `SVar:PlayMain1`. Would this cast lose something by waiting for the
## second main phase?
##
## [forge] `ComputerUtil.castPermanentInMain1`
## (`forge-ai/src/main/java/forge/ai/ComputerUtil.java:1141-1297`, commit
## `b09a3d3f`) and its parallel `castSpellInMain1` (`:1299-1361`). Five
## sentences, and the reasoning for each is in
## [member AiProfile.develops_late].
func _main1_worthy(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		targets: Array, value: float) -> bool:
	# A WIN IS NEVER POSTPONED. Main 2 would end the game just as well and
	# a pilot that holds a won game is one bad interaction away from
	# losing it; `_lethal_life_mana` is asked before this function is
	# reached for the same reason.
	if value >= LETHAL_WORTH:
		return true
	# FLOATING MANA IS LOST AT THE STEP BOUNDARY (CR 500.4), and
	# [method ManaPlanner.sources] offers the pool before it offers a
	# land, so the cast that spends it is made now (`:1191-1205`).
	if game.players[pid].mana_pool.total() > 0:
		return true
	# A HASTE CREATURE ATTACKS THIS TURN (`:1217-1220`).
	if inst.data.is_creature() and inst.data.keywords.has(Mtg.Keyword.HASTE):
		return true
	# A MANA SOURCE HELD IS MANA HELD (`:1181`, where Forge's own line is
	# the zero cost the Moxen are scripted with). A mana CREATURE is
	# summoning sick and makes nothing this turn, so it waits.
	if not inst.data.is_creature() and not inst.data.mana_abilities.is_empty():
		return true
	return _changes_this_combat(game, targets)


## Does what this spell or ability POINTS AT change the combat that is
## about to happen? Forge's Main-1 interrupts, in one sentence for both
## paths: a permanent of THEIRS answered is a blocker that will not be
## there (`ComputerUtil.java:1246-1259` — "removing a blocker lets more
## attackers through in own Main 1"), and a permanent of OURS aimed at is
## the aura or the pump that makes the attack bigger
## (`castSpellInMain1`'s pump clause).
##
## Both want an attack to be coming — Forge's `PlayMain1:TRUE` is
## literally "when the AI has creatures" — and [method _has_attackers]
## is the same question the animation probe asks.
func _changes_this_combat(game: MtgGame, targets: Array) -> bool:
	if targets.is_empty():
		return false
	if not _has_attackers(game):
		return false
	for t in targets:
		if not (t is TargetRef) or t.is_player:
			continue
		var victim := game.find_instance(t.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD:
			continue
		return true
	return false


## The activation half of the same question. An ability that ANIMATES its
## own source is a body that attacks this turn and nothing else
## ([method _animation_value] already answers 0.0 outside our own first
## main step); everything else is judged by what it points at.
func _activation_changes_combat(game: MtgGame, inst: CardInstance,
		index: int, option: Dictionary) -> bool:
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var intent := EffectIntent.read(ability.effects, inst.data.card_name)
	if intent.animates != null:
		return true
	return _changes_this_combat(game, option.get("targets", []))


## THE LAND DROP HELD FOR MAIN 2 (`AiController.isSafeToHoldLandDropForMain2`,
## `AiController.java:1404-1516`). A land that changes nothing castable
## this turn is worth more in hand than on the table, because it is the
## one card the opponent can be certain of.
##
## Forge's own four guards, and the fourth is the one that matters here.
## THIS PILOT SIZES ITS OWN COMBAT BY THE MANA IT IS HOLDING — a Carrion
## Ants behind four Swamps is a 4/5 to [method _pump_reach], a Factory is
## a blocker to [member AiProfile.reads_manlands] — so a land kept in hand
## is a body that reads one point smaller at the declaration. Forge's
## `hasRelevantAbsOTB` (`:1504-1512`) is exactly that guard and it is
## kept: with an ability on our own table the mana could pay for, the land
## is played.
func _land_drop_waits(game: MtgGame, land: CardInstance) -> bool:
	if not _develops_late(game):
		return false
	# `:1415-1418` — on turn 1 or 2 the bluff fools nobody.
	if game.turn_number <= 2:
		return false
	var me := game.players[pid]
	# `HOLD_LAND_DROP_ONLY_IF_HAVE_OTHER_PERMS` (`:1423`): an empty board
	# has nothing to be coy about.
	if me.battlefield.is_empty():
		return false
	if _has_ability_wanting_mana(game):
		return false
	if _land_unlocks_a_cast(game, _mana_sources(game), land):
		return false
	return true


## An ability on OUR OWN battlefield the extra mana could pay for —
## Forge's `hasRelevantAbsOTB`. A firebreather, a Factory's animation, an
## Icy Manipulator, a Tome: every one of them is a reason for the land to
## be on the table where the combat maths can see it.
func _has_ability_wanting_mana(game: MtgGame) -> bool:
	for inst in game.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if ability.cost == null or ability.cost.mana_value() <= 0:
				continue
			if not _ability_available(game, inst, index):
				continue
			return true
	return false


## Does the drop change what the hand can cast this turn? Forge's
## `canCastWithLandDrop` / `cantCastAnythingNow` arithmetic (`:1443-1444`),
## asked of the mana planner itself rather than of a cheapest-CMC number:
## for every colour the land could make, is there a card in hand that goes
## from unplannable to plannable?
##
## An X spell says yes on sight: its X is what the land is FOR, and a
## plan at X = 0 would answer "castable already" for a Fireball on one
## Mountain.
func _land_unlocks_a_cast(game: MtgGame, sources: Array,
		land: CardInstance) -> bool:
	var colours: Dictionary = {}
	for ability in land.data.mana_abilities:
		# The same riders [method ManaPlanner.sources] refuses to model.
		if ability.cost != null or ability.life_cost > 0 \
				or ability.counter_cost_kind != "" \
				or ability.sacrifice_filter.is_valid():
			continue
		for pair in ability.produces:
			colours[int(pair[0])] = maxi(int(colours.get(int(pair[0]), 0)),
				int(pair[1]))
	if colours.is_empty():
		return false   # a Maze of Ith makes no mana: no cast is waiting on it
	for inst in game.players[pid].hand:
		if inst.is_land():
			continue
		if _cast_gate(game, inst) != "":
			continue   # "Cast this spell only ..." — not this turn, whatever we play
		if inst.data.cost.has_x:
			return true
		var surcharge := game.spell_surcharge(pid, inst.data)
		var keys: Array = game.mana_usage_keys(inst.data)
		if _cost_is_free(inst.data.cost) and surcharge == 0:
			continue
		if not _plan_taps_from(sources, inst.data.cost, surcharge, keys).is_empty():
			continue   # castable already: the drop changes nothing for it
		for colour in colours:
			var with_land: Array = sources.duplicate()
			# One entry per unit, shaped the way the planner's own
			# floating-mana rows are ([method ManaPlanner.sources]).
			for _unit in int(colours[colour]):
				with_land.append([null, 0, int(colour), 1, false, "", 0])
			if not _plan_taps_from(with_land, inst.data.cost, surcharge,
					keys).is_empty():
				return true
	return false


## THE MANA THE SECOND MAIN PHASE IS WAITING ON (2026-09-10, [member
## AiProfile.develops_late]), as `{instance id: true}` — the bodies of
## ours that must not be sent to attack, because attacking taps them and
## the cast after combat needs what they make.
##
## THIS IS THE ROW'S OWN HAZARD, AND THE LAB FOUND IT BEFORE THE ARGUMENT
## DID. A cast held for Main 2 is mana that looks open in between, and the
## attack declaration is what spends it: Big Green's Llanowar Elves is
## tapped for mana in Main 1 at HEAD and therefore never attacks, while
## with the hold on it stands untapped at the declaration and is sent.
## Measured over 200 games of Big Green against White Knights, mana
## sources sent to attack per game went 1.49 -> 3.00 and the pilot cast a
## whole spell FEWER each game (7.89 -> 6.84), with its creature count at
## turn six down from 1.60 to 1.39. That is the whole of the −4.7 the
## first sweep measured.
##
## [forge] `AiController.reserveManaSourcesForMain2` /
## `HELD_MANA_SOURCES_FOR_MAIN2` (`AiController.java:722-757`, commit
## `b09a3d3f`, `docs/forge/casting.md` §2.2) marks the sources
## `predictSpellToCastInMain2` will want so nothing else spends them; ours
## is the same mark, put where this pilot spends mana that Forge does not
## — its own attack.
##
## THE LANDS ARE ASKED FIRST, so a body is held only when it is actually
## needed: if the cast plans out of the non-creature sources alone, every
## creature attacks as it always did. A body under an attack REQUIREMENT
## (Juggernaut) is never held — the engine refuses that declaration.
## Same shape as [method _attackers_excluded], which is the mirror of this
## sentence for a Factory animated to attack.
func _main2_mana_held(game: MtgGame) -> Dictionary:
	var out: Dictionary = {}
	if not profile.develops_late or game.active_player != pid \
			or game.current_step() > Mtg.Step.DECLARE_ATTACKERS:
		return out
	var sources := _mana_sources(game)
	var main2 := _main2_reserve(game, sources)
	if main2.is_empty():
		return out
	var cost: ManaCost = main2["cost"]
	var surcharge := int(main2.get("surcharge", 0))
	var keys: Array = main2.get("keys", [])
	var landbound: Array = []
	for row in sources:
		var src: CardInstance = row[0]
		if src == null or not src.is_creature():
			landbound.append(row)
	if not _plan_taps_from(landbound, cost, surcharge, keys).is_empty():
		return out   # the lands pay for it: no body is spoken for
	for step in _plan_taps_from(sources, cost, surcharge, keys):
		var src: CardInstance = step[0]
		if src != null and src.is_creature():
			out[src.id] = true
	return out


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
		if _arrival_wasted(game, inst.data):
			continue   # a second Karakas is buried on arrival: the drop is worth more
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
	if _land_drop_waits(game, best):
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
		if _arrival_wasted(game, inst.data):
			continue   # a second legend, a second world: a card thrown away
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
		# ...and CHANNEL is worth exactly the game it ends (2026-09-10,
		# AiProfile.reads_lethal_x). Off, it is the plain 3.00 spell the
		# pilot has always cast into an empty board.
		if intent.mana_for_life and profile.reads_lethal_x \
				and not _life_mana_enables(game, inst, sources):
			continue
		var mode := _pick_mode(game, inst.data)
		var sized := _size_and_aim(game, inst, intent, max_x, mode)   # {} = wait
		if sized.is_empty():
			continue
		var x: int = sized["x"]
		var targets: Array = sized["targets"]
		var value: float = sized["value"]
		# DEVELOP AFTER COMBAT (2026-09-10, AiProfile.develops_late). In
		# our FIRST main phase only what Forge's `castPermanentInMain1`
		# would cast is cast; everything else has a whole second main
		# phase to be cast in, and the opponent declares its blocks
		# without it.
		if _develops_late(game) \
				and not _main1_worthy(game, inst, intent, targets, value):
			continue
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
		# THE ONE-PLY VETO (2026-09-10, AiProfile.checks_before_casting):
		# the engine has cleared the cast; this asks whether the POSITION
		# it leaves us in is worse than the one we are in.
		if _cast_veto(game, inst, intent, targets, x):
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


## THE ONE-PLY VETO (2026-09-10, [member AiProfile.checks_before_casting];
## `docs/forge/casting.md` P8). Would this cast leave us WORSE OFF than
## simply passing — once the spell has resolved and the one answer the
## table is already showing has been taken?
##
## [forge] `forge-ai/src/main/java/forge/ai/simulation/OnePlaySafetyChecker.java:23-31`
## (commit `b09a3d3f`) runs the heuristic picker, COPIES the game, replays
## that one play and refuses it when the score drops. We cannot copy the
## game and do not have to (`docs/forge/casting.md` §6.4):
## [method Evaluator.position_score] is a sum of four counted quantities,
## so the position after a cast is ARITHMETIC — the card leaves the hand,
## the victim leaves their board, the life totals move, our permanent
## arrives. That is [method _cast_projection], and it costs one pass over
## the targets.
##
## THE ANSWER IS THE ONE THE TABLE IS ALREADY SHOWING, AND NO OTHER. The
## note asks for "the opponent's obvious answer"; the only answer a seat
## may READ is the one it can see, so it is an activated ability on THEIR
## battlefield that they can pay for right now and that would take the
## body straight off again ([method _answered_on_arrival]) — a Prodigal
## Sorcerer's ping, a Rod of Ruin, an Orcish Artillery. Their hand is not
## looked at. The note's other clause — a guessed Lightning Bolt behind
## open red mana, gated on [AiMatchMemory] having seen that colour deal
## damage — is NOT built, and the reason is structural rather than a
## preference: `AiMatchMemory` belongs to the sideboard, no `AiPlayer`
## carries one, and free play has none at all, so the clause would be
## inert in the very runs that measure it (docs/ai-difficulty.md §5).
##
## AND THE SWING THEIR CREATURES MAKE NEXT TURN IS NOT COUNTED, because
## the body is not on the table to block it: with no instance to hand,
## [method _damage_after_value_blocks] answers the same number on both
## sides of the comparison and the term cancels.
##
## IT ABSTAINS UNLESS THE ANSWER IS THERE. A cast nothing on the table
## answers is never vetoed whatever the projection says — a veto with no
## answer in it is exactly the "pessimistic projection that never casts
## into open red mana" the note's own risk paragraph names. And a
## DESPERATE PLAY IS ALLOWED TO BE DESPERATE: [method _in_danger] — the
## panic line read against the damage their board would actually land —
## lifts it, which is Forge's own escape ("desperate plays are ok if next
## combat was already likely to kill AI").
func _cast_veto(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		targets: Array, x_value: int) -> bool:
	if not profile.checks_before_casting:
		return false
	if intent.unknown or not intent.makes_token.is_empty():
		return false   # a payoff the projection cannot price: no opinion
	if not _answered_on_arrival(game, inst.data):
		return false
	if _in_danger(game):
		return false
	return _cast_projection(game, inst, intent, targets, x_value) < 0.0


## The position this cast would leave us in, as a delta on
## [method Evaluator.position_score]'s own terms — with the arriving
## permanent already struck out, because this is only ever asked once
## [method _answered_on_arrival] has said the table takes it back. Every
## term is one of the four quantities that score counts, and nothing that
## is not one of them is guessed at.
func _cast_projection(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		targets: Array, x_value: int) -> float:
	var delta := -profile.w_hand   # the card leaves our hand
	var drawn := intent.draws + (x_value if intent.draws_use_x else 0)
	delta += float(drawn) * profile.w_hand
	delta += float(intent.life_gain - intent.self_damage) * Evaluator.W_LIFE
	for t in targets:
		if not (t is TargetRef):
			continue
		var ref: TargetRef = t
		if ref.is_player:
			var dmg := intent.damage_at(x_value)
			if dmg > 0:
				delta += float(dmg) * Evaluator.W_LIFE \
					* (1.0 if ref.player_id != pid else -1.0)
			continue
		var victim := game.find_instance(ref.instance_id)
		if victim == null or not intent.kills(victim, x_value):
			continue
		var worth := Evaluator.permanent_value(victim, profile) * Evaluator.W_BOARD
		delta += worth if victim.controller_id != pid else -worth
	return delta


## THE ANSWER THE TABLE IS ALREADY SHOWING (2026-09-10, [member
## AiProfile.checks_before_casting]): would the creature this cast puts on
## the battlefield be taken off it again by an activated ability the
## opponent can pay for RIGHT NOW?
##
## The same reading [method _taps_into_execution] makes for the Royal
## Assassin and [method _shieldable] for their regeneration shield, asked
## of a body that does not exist yet: their open sources counted the way
## both of those count them (untapped permanents with a mana ability,
## public to both seats), the ability's own tap cost paid by an untapped,
## un-sick source, and the effect read as a SHAPE ([EffectIntent]) rather
## than as a card name.
##
## THREE THINGS IT REFUSES TO GUESS AT, each in the safe direction —
## fewer vetoes, never more. A cost that is not mana (a sacrifice, a life
## payment, an exile, a discard) is a board or a card and nothing here
## prices either, which is the answer [method _cheapest_pump_of] gives the
## same question. A target spec with a FILTER on it is one this reading
## cannot put an unbuilt body to — a Royal Assassin's *target TAPPED
## creature* is no answer to a creature that has not arrived — so it is
## passed over. And only a CREATURE is asked about: nothing in this pool
## answers an artifact or an enchantment at will.
func _answered_on_arrival(game: MtgGame, data: CardData) -> bool:
	if not data.is_creature():
		return false
	var them := game.opponent_of(pid)
	var open := 0
	for p in game.players[them].battlefield:
		if not p.tapped and not p.cur_mana_abilities.is_empty() \
				and not (p.is_creature() and p.summoning_sick):
			open += 1
	for source in game.players[them].battlefield:
		if (data.protection_from & source.cur_colors) != 0:
			continue
		for index in source.cur_activated_abilities.size():
			var ability: ActivatedAbility = source.cur_activated_abilities[index]
			if ability.effects.is_empty() or ability.only_opponents_may_activate:
				continue
			if ability.sacrifice_cost or ability.exile_cost \
					or ability.life_cost > 0 or ability.random_discard_cost > 0:
				continue
			if ability.tap_cost and (source.tapped
					or (source.is_creature() and source.summoning_sick)):
				continue
			if ability.cost != null and ability.cost.mana_value() > open:
				continue
			var intent := EffectIntent.read(ability.effects, source.data.card_name)
			var spec := intent.target_spec
			if spec == null or spec.filter.is_valid() or spec.game_filter.is_valid():
				continue
			if spec.kind != TargetSpec.Kind.CREATURE \
					and spec.kind != TargetSpec.Kind.ANY:
				continue
			if intent.removes:
				return true
			if intent.damage > 0 and intent.damage >= data.toughness:
				return true
	return false


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


## THE SECOND LEGEND (2026-09-07, [member AiProfile.holds_duplicates]):
## would this permanent's arrival be a card thrown away? A legend whose
## name is already on the battlefield — either side's — is buried the
## moment it lands (the legend rule as 1997 played it, the newcomer
## loses: MtgGame._newest_duplicate_legend), and a world enchantment
## buries every other world on arrival (CR 704.5k,
## MtgGame._superseded_world_permanent) — a world of OURS with it, which
## is the same card twice or a world traded for a world; a world of
## THEIRS is what ours is for. The pilot that never asked cast its
## second and third The Abyss over the first, four mana and a card each.
## The supertype bits and the names on the battlefield: nothing here
## names a card.
func _arrival_wasted(game: MtgGame, data: CardData) -> bool:
	if not profile.holds_duplicates:
		return false
	var legend := (data.supertypes & Mtg.Supertype.LEGENDARY) != 0
	var world := (data.supertypes & Mtg.Supertype.WORLD) != 0
	if not legend and not world:
		return false
	for seat in [pid, game.opponent_of(pid)]:
		for perm in game.players[seat].battlefield:
			if legend and perm.data.card_name == data.card_name \
					and (perm.data.supertypes & Mtg.Supertype.LEGENDARY) != 0:
				return true
			if world and seat == pid \
					and (perm.data.supertypes & Mtg.Supertype.WORLD) != 0:
				return true
	return false


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
		var worth := Evaluator.permanent_value(perm, profile)
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
			if _decking_draw(game, inst, intent, intent.draws, 0) >= 0:
				value = LETHAL_WORTH
			elif intent.draws > _hand_room(game, Moment.SINK, inst):
				continue   # _fire_held_instant would not draw it either
			else:
				value = 3.0 + _draw_need(me.hand.size())
		elif intent.answers_creatures():
			var victim := _best_victim(game, inst, intent, 0)
			if victim != null:
				var worth := Evaluator.permanent_value(victim, profile)
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

## COMBAT is THEIR combat with the attackers declared and the damage not
## yet dealt (2026-09-08, [member AiProfile.times_sweeps]): the one
## moment at which only a sweeper is offered, at the upkeep's bar.
enum Moment { MAIN, UPKEEP, SINK, COMBAT }


## Activate the best-scoring ability that clears the bar for [param moment],
## or "" when nothing does. One activation per call, like every other action.
func _try_activate(game: MtgGame, moment: int = Moment.MAIN) -> String:
	var bar: float = ABILITY_BAR_MAIN
	if moment == Moment.UPKEEP or moment == Moment.COMBAT:
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
			# DEVELOP AFTER COMBAT (2026-09-10,
			# AiProfile.develops_late): the mana sink is a Main 2 action
			# like every other one. Without this the knob defeats itself
			# — with the hand held, `_try_cast_best` returns "" in Main 1
			# and a Jayemdae Tome would spend on a card the mana the
			# whole point was to keep open.
			if not option.is_empty() and _develops_late(game) \
					and not _activation_changes_combat(game, inst, index, option):
				continue
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
			or ability.random_discard_cost or ability.discard_cost > 0:
		return false
	# A COUNTER IS A PRICE TOO (2026-09-09, [member
	# AiProfile.spends_counters]) — it used to sit on the line above and
	# no counter had ever been removed as a cost in this AI's life.
	if ability.counter_cost_kind != "" \
			and not _counter_cost_spendable(inst, ability):
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
			and not sacrifices \
			and ability.counter_cost_kind == "":
		# A body is a thing the turn runs out of, and since 2026-09-09 so
		# is a counter: Osai Vultures' `+1/+1 for two carrion` is free of
		# mana, free of the tap and capped by nothing but the birds it has
		# eaten, and without this line the sink would offer it forever.
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


## THE COUNTER THAT WAS NEVER SPENT (2026-09-09, [member
## AiProfile.spends_counters]). May the pilot pay [param ability]'s
## "remove N <kind> counters from this permanent" cost off [param inst]?
##
## Until this existed [method _ability_available] refused every counter
## cost in the pool outright — they sat on the same line as the exile and
## discard riders the mana planner cannot model — so no counter had ever
## been removed as a cost in this AI's life. The report that surfaced it
## was Osai Vultures: *"Remove two carrion counters from this creature: it
## gets +1/+1 until end of turn"*, a bird that eats at every end step a
## creature died and blocks at 1/1 with four counters on it.
##
## "ALLOW ALL COUNTER COSTS" IS THE WRONG RULE, and the reason is the same
## one [member AiProfile.pays_sacrifices] is gated for: every reader
## downstream prices the EFFECT and not the cost, and a counter is not
## free the way tapping a land is. A Triskelion's three +1/+1 counters ARE
## the 4/4 body; a pilot that shoots three times has bought three damage
## and sold six points of creature without ever seeing the second half of
## the trade.
##
## SO THE RULE IS: NOTHING BUT THE COST MAY READ THE COUNTER. A permanent's
## counters can be read by exactly three things here, and two of them can
## be asked from outside the card:
##
##  * THE NAME, read by the characteristics pipeline itself. A kind that
##    parses as a P/T delta ([method ContinuousEffects.parse_pt_counter] —
##    "+1/+1", "-0/-2", "+1/+0", "any P/T counter a card invents just
##    works") is part of the creature's size, so removing it shrinks the
##    body. Refused.
##  * THE LIVE FIELD, read by the damage replacement. [member
##    CardInstance.damage_eats_counters] names the kind a permanent sheds
##    point for point instead of taking damage — a Rock Hydra's heads are
##    its life (CR 615.1, a prevention effect that replaces the damage).
##    Refused, whatever the kind is called.
##  * THE CARD'S OWN SCRIPT, which cannot be read from outside it. That is
##    where a CLOCK would live — a doom counter, a turn counter — and the
##    ruling stops there and says so. Nothing in this pool makes a clock's
##    counter a COST: Armageddon Clock removes its doom counter as an
##    EFFECT, and the Oracle Time Vault this engine implements carries no
##    counters at all.
##
## What is left is FUEL, and every counter cost the pool actually ships is
## one: carrion, corpse and husk counters a trigger of the card's own puts
## back, Life Matrix's matrix counter whose only printed use is the
## regeneration it buys, Rasputin's dream counters refilled each upkeep.
## Fuel needs no price of its own — to the evaluator, the combat maths and
## the damage replacement it is worth zero until it is spent — so the
## effect the existing readers already price is the whole of the trade.
##
## The count is checked here as well as in the engine so the refusal costs
## no mana: [method MtgGame.activate_ability] would refuse an empty
## permanent AFTER [method _plan_and_pay] had tapped the lands.
func _counter_cost_spendable(inst: CardInstance, ability: ActivatedAbility) -> bool:
	if not profile.spends_counters:
		return false
	var kind: String = ability.counter_cost_kind
	if int(inst.counters.get(kind, 0)) < maxi(ability.counter_cost_count, 1):
		return false
	if ContinuousEffects.parse_pt_counter(kind) != Vector2i.ZERO:
		return false   # the counter IS the body
	if inst.damage_eats_counters == kind:
		return false   # the counter IS the armour
	return true


## Score one ability for [param moment]: `{inst, index, targets, value}`,
## or `{}` when it has no worthwhile use right now. The numbers are
## mage-go's `intrinsicAbilityQuality` scale (draw 5, damage 4, tap 4,
## lifegain 3...) adjusted by hand size, life cost and mana price the way
## `cardDrawNeedAdjustment` and `lifeCost*15/life` adjust them.
func _ability_option(game: MtgGame, inst: CardInstance, index: int, moment: int) -> Dictionary:
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var intent := EffectIntent.read(ability.effects, inst.data.card_name)
	if moment == Moment.COMBAT and intent.sweeper == null:
		return {}   # their combat is a sweeper's moment and nobody else's
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
			value = Evaluator.permanent_value(victim, profile) + 1.0
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
				value = Evaluator.permanent_value(mark, profile) * 0.6 + 1.0
			elif game.current_step() == Mtg.Step.MAIN1 and _has_attackers(game):
				value = Evaluator.permanent_value(mark, profile) * 0.4 + 1.0
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
		# THE COUNT (2026-09-07): a draw the hand cannot hold or the
		# library cannot spare is not a draw, it is a card thrown away.
		if intent.draws > _hand_room(game, moment):
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
	elif not intent.makes_token.is_empty() and profile.plays_engines:
		# THE BODY THE SCORER COULD NOT SEE (2026-09-10). Five permanents
		# in this pool turn mana into a creature TOKEN through an activated
		# ability — The Hive, Boris Devilboon, Master of the Hunt, Serpent
		# Generator, Necropolis of Azar — and not one of them had ever made
		# a token. The cost was never the gate ([method
		# _ability_available] says yes to all five, the Necropolis's husk
		# counter included since [member AiProfile.spends_counters]); the
		# gate was this function, which had no arm for an effect whose
		# whole payload is a permanent that did not exist a moment ago, so
		# every one of them fell through to the `else` below.
		#
		# It is the same knob as the animation and the repeatable discard,
		# and the knob's own words say why: a Hive turns "mana it has
		# nothing else to do with" into a body every turn, which is what a
		# Tome does with cards. A pilot that cannot read a permanent as a
		# thing that pays over time simply owns an artifact.
		value = _token_value(intent.makes_token)
		if moment == Moment.SINK:
			value += 1.0   # mana that would otherwise be lost
		# AND NO BAR OF ITS OWN, unlike the animation. An animation lasts
		# until end of turn, so the moment it is not bought is the moment
		# it is lost; a TOKEN is permanent, so the ability that makes one
		# has every later moment to be used at and the main phase's bar —
		# "is this worth the mana a SPELL might want" — is the right one
		# for it to fail. What it fails into is the mana sink at their end
		# step, where the mana is about to be wasted anyway and the body
		# arrives in time to attack on our next turn.
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


## WHAT A TOKEN IS WORTH ON THE BOARD (2026-09-10, [member
## AiProfile.plays_engines]) — [param row] is a row of [constant
## EffectIntent.TOKEN_MAKERS], the body one activation GUARANTEES.
##
## Priced as [method Evaluator.permanent_value] prices the creature it is
## about to become, and deliberately NOT as a constant: the whole point of
## reading the body is that a 1/1 flier off a Hive and a 1/1 off a Boris
## Devilboon cost the same five-ish mana and are not the same purchase,
## and the Spawn of Azar's swampwalk is worth the same half point on the
## table as any other landwalker's. A token is a creature that cost no
## card, so nothing is subtracted for the card it did not spend; the mana
## is charged by [method _ability_option]'s own price term, like every
## other arm's.
##
## The row is a body, not a permanent, so the three terms
## [method Evaluator.permanent_value] reads off a live instance and this
## cannot — protection, regeneration shields, and any size a static
## ability would add — are simply absent. All three understate, which is
## the direction a purchase should err in.
func _token_value(row: Dictionary) -> float:
	var value := float(int(row.get("power", 0)) + int(row.get("toughness", 0)))
	for keyword in row.get("keywords", []):
		value += float(Evaluator.KEYWORD_VALUE.get(keyword, 0.0))
	if bool(row.get("landwalk", false)):
		value += 0.5
	return maxf(value, 0.5)   # permanent_value's own floor


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
	var excluded := _excluded_sources(game)
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
	var excluded := _excluded_sources(game)
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
	if profile.animates_to_attack \
			and not _would_attack_once_animated(game, inst, anim, defender):
		return 0.0   # the declaration would leave it home: nothing to pay for
	return _face_damage_value(game, anim.set_power, defender)


## THE FACTORY ANIMATED FOR NOTHING (2026-09-08,
## [member AiProfile.animates_to_attack]). Would the attack declaration
## send [param inst] once [param anim] has made it a creature? The
## blocker count above is [method _animation_value]'s own reading; the
## DECLARATION is made by [method _attack_choice] over the whole board —
## the attack legality of every ban in play (our own Moat stops a
## Factory as surely as theirs), the cohort, the crack-back search — and
## the two disagreed often enough that the pilot paid a mana a turn for
## a 2/2 that then declared nothing (docs/ROADMAP.md, "The Deck, third
## pass"). So the question is put to the declaration itself, under the
## journal: the body is animated the way the ability would animate it,
## the deterministic half of the declaration is asked, and both are
## unmade. No random stream is consumed ([method _attack_choice] has no
## mistake roll), no log line is written (a search node is a probe), and
## a search already in progress keeps its journal.
func _would_attack_once_animated(game: MtgGame, inst: CardInstance,
		anim: AnimateSelfEffect, defender: int) -> bool:
	var owned := game.undo_log == null
	var mark := game.make_mark()
	game.continuous.add_until_eot_animation(inst.id, anim.add_types,
		anim.set_power, anim.set_toughness, anim.add_subtypes, anim.combat_duration)
	game.recalculate()
	var would := false
	if inst.is_creature():
		var candidates := _attack_candidates(game, defender)
		if candidates.has(inst):
			would = _attack_choice(game, candidates, defender).has(inst.id)
	game.unmake_to(mark)
	if owned:
		game.end_search()
	return would


## Is [param inst] a creature only until this turn ends — not by its
## printed types, and by no animation that outlasts cleanup? See
## [method ContinuousEffects.creature_until_end_of_turn].
func _creature_until_end_of_turn(game: MtgGame, inst: CardInstance) -> bool:
	return not inst.data.is_creature() \
		and game.continuous.creature_until_end_of_turn(inst.id)


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


## THE COUNT (2026-09-07, [member AiProfile.counts_cards]): how many more
## cards this seat can draw at [param moment] and still USE — the room
## under its maximum hand size, plus the cards its next turn will play. A
## card drawn into a full hand is discarded at cleanup (CR 514.1), which
## is a card off the library for nothing; the pilot that never counted
## this drew with a Tome into hands of fifteen and drew itself out. At
## THEIR end step our own draw step still adds one before we play
## anything; in our main phase what is drawn can be played on the spot.
## Every seat that does not count has all the room in the world. A
## [param source] cast from the hand counts itself out. The room is then
## capped by THE PACE ([method _library_slack]): a card the hand could
## hold but the library race cannot spare is not drawn either.
func _hand_room(game: MtgGame, moment: int, source: CardInstance = null) -> int:
	var room := 1 << 20
	if profile.counts_cards:
		var me := game.players[pid]
		var allowance := 2 if moment == Moment.MAIN else 1
		room = me.max_hand_size + allowance - me.hand.size()
		if source != null and source.zone == Mtg.Zone.HAND:
			room += 1   # the spell itself leaves the hand before its cards arrive
	return mini(room, _library_slack(game))


## THE PACE (2026-09-07, [member AiProfile.paces_draws]): the end of a
## library is this near — in cards of our own — before the race to it
## is allowed to refuse a draw. Twenty turns of draw steps: a game that
## has not ended by then is being decided by the libraries.
const PACE_HORIZON := 20


## THE PACE (2026-09-07, [member AiProfile.paces_draws]): how many cards
## this seat can take off its library and still win the race to deck.
## The loss is the draw from the empty library (CR 704.5b), and each
## draw step takes one card from each library in turn, so the race is
## the two counts and WHOSE draw step comes next: when theirs does, they
## draw from nothing first as long as our library is no smaller than
## theirs; when ours does, ours has to be strictly larger. A seat that
## holds the race may spend its lead down to nothing and no further; a
## seat that has already lost it has nothing left to protect, and draws
## for value; and while the library is beyond [constant PACE_HORIZON]
## the game is not being decided by the libraries at all. The pilot that
## never counted this drew with two Tomes into a race it then lost from
## twenty life. Every seat that does not pace has all the slack in the
## world.
##
## TIME WALK'S DRAW STEP (2026-09-08): an extra turn already queued
## ([member MtgGame.extra_turns]) is a draw step off its taker's library
## before the other's comes round — ours counted against the lead,
## theirs for it. The pilot that never counted this cast a Time Walk
## into a race it led by nothing.
func _library_slack(game: MtgGame) -> int:
	if not profile.paces_draws:
		return 1 << 20
	var mine := game.players[pid].library.size()
	var theirs := game.players[game.opponent_of(pid)].library.size()
	var step := game.current_step()
	var ours_next := (game.active_player == pid and step < Mtg.Step.DRAW) \
		or (game.active_player != pid and step >= Mtg.Step.DRAW)
	var lead := mine - theirs - (1 if ours_next else 0)
	for taker in game.extra_turns:
		lead += -1 if taker == pid else 1
	if lead < 0:
		return 1 << 20   # the race is lost already: not ours to protect
	return maxi(lead, mine - PACE_HORIZON - 1)


## THE DRAW THAT WINS (2026-09-07, [member AiProfile.counts_cards]): a
## draw effect that may target a player and can draw the OPPONENT'S whole
## library. They lose the game at their next draw step (CR 704.5b), and
## nothing they draw on the way changes that. [param draws] is the number
## the spell would draw at the X it can afford; returns the X to cast it
## for, or -1 when the play is not there.
func _decking_draw(game: MtgGame, source: CardInstance, intent: EffectIntent,
		draws: int, max_x: int) -> int:
	if not profile.counts_cards or intent.target_spec == null \
			or intent.target_spec.kind != TargetSpec.Kind.PLAYER:
		return -1
	var opponent := game.opponent_of(pid)
	var theirs := game.players[opponent].library.size()
	if theirs <= 0 or draws < theirs:
		return -1
	var x := theirs if intent.draws_use_x else 0
	if not game.target_legal_at(intent.target_spec, TargetRef.player(opponent),
			source, x):
		return -1
	return mini(x, max_x)


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
		return Evaluator.permanent_value(inst, profile)
	if inst.is_land():
		return Evaluator.land_value(game, inst)
	var value := Evaluator.permanent_value(inst, profile)
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
##
## THE LIABILITY (2026-09-09, [member AiProfile.prices_liabilities]) is
## read here and only here, and the reason is a count: [method
## Evaluator.permanent_value] has 76 callers and every one of them is a
## BOARD reading — what an attacker is worth, what a block trades, what a
## sweep takes, which creature a tutor wants, whether a spell clears the
## counter threshold. A permanent allowed to price below zero there moves
## all of them at once and the knob's null stops being the null. The
## question this method asks is a different one — *what is giving this
## permanent up worth to us* — and every caller asks exactly that: the
## slots of a harmful spell and its single target ([method
## _extra_targets], [method _pick_for_spec], both through [method
## _worth_giving_up]), what that cast is worth ([method _cast_value]),
## what an activation's sacrifice costs ([method _sacrifice_price]), and
## the body a cost eats or a tribute takes ([method answer_card], [method
## _tribute_value]). The floor of zero stays on the board score.
func _own_value(game: MtgGame, inst: CardInstance, as_source := false) -> float:
	# THE RECKONING outranks every other reading, including the land maths
	# below: a permanent whose departure loses the game has no price.
	var priced := profile.prices_liabilities and inst.zone == Mtg.Zone.BATTLEFIELD
	if priced and EffectIntent.loses_the_game_on_leaving(inst.data):
		return LETHAL_WORTH
	var toll := _liability_price(game, inst) if priced else 0.0
	if not inst.is_land():
		if priced and _dead_weight(game, inst):
			return 0.0 - toll   # nothing it does is ours until it untaps
		return Evaluator.permanent_value(inst, profile) - toll
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
	return value - toll


## THE DEAD WEIGHT (2026-09-09, [member AiProfile.prices_liabilities]):
## is nothing this permanent does available to us at all?
##
## [method Evaluator.permanent_value] prices an artifact or an enchantment
## by what it cost — "it earned its slot" — which is the right guess for a
## permanent that is working. A Mana Vault that is tapped, that does not
## untap in our untap step, and whose one ability is "{T}: Add {C}{C}{C}"
## is not working: it is a card face-down on the table, and it is worth 1.0
## all the same. The three tests are all live fields, and a permanent that
## has anything left to give fails one of them:
##
##  * it is TAPPED and [member CardInstance.cur_skips_untap] — the untap
##    step will not give it back (Mana Vault's own static, a Paralyze, a
##    Meekstone, an Arena of the Ancients);
##  * every activated and mana ability it has needs the {T} it cannot pay
##    — a Basalt Monolith's "{3}: untap this artifact" and a Colossus of
##    Sardia's {9} both fail this and keep their worth, which is right:
##    they can free themselves;
##  * it has no STATIC ability except the untap lock itself, read off the
##    printed line ([constant UNTAP_LOCK_WORDS]) — a static keeps working
##    while its source is tapped, so a Lord under a Paralyze is still
##    pumping the board and is no dead weight, while the Vault's one
##    static IS the thing that killed it.
##
## What it deliberately does not reach: a permanent held down by something
## on the OTHER side of the table asks the same question (a Paralyze the
## opponent controls offers ITS controller nothing). The untap price
## printed on the AURA rather than on the host WAS the second such gap
## and is one no longer ([method _untap_prices], 2026-09-10).
const UNTAP_LOCK_WORDS := "doesn't untap"


func _dead_weight(game: MtgGame, inst: CardInstance) -> bool:
	if not inst.tapped or not inst.cur_skips_untap or inst.is_land():
		return false
	for ability in inst.cur_mana_abilities:
		if not ability.taps_source:
			return false
	for ability in inst.cur_activated_abilities:
		if not ability.tap_cost:
			return false
	for static_ability in inst.data.static_abilities:
		if not static_ability.text.to_lower().contains(UNTAP_LOCK_WORDS):
			return false
	# ...and only while EVERY price printed to free it is out of reach: its
	# own line and, since 2026-09-10, the lines of what is attached to it.
	for escape in _untap_prices(game, inst):
		if _can_reach(game, inst, ManaCost.parse(escape)):
			return false
	return true


## THE UNTAP PRICE, WHEREVER IT IS PRINTED (2026-09-10, [member
## AiProfile.prices_liabilities]): every mana price on the table that
## would hand [param inst] back to us at the next beat of our own turn.
##
## The permanent's own line is the first of them ([method _own_toll]: a
## Mana Vault's {4}, a Brass Man's {1}, an Island Fish Jasconius's
## {U}{U}{U}). The rest are printed on what is ATTACHED to it, which is
## where this pool actually puts them — Paralyze locks the creature's
## untap step and offers "that player may pay {4}" on the AURA, and the
## host's own [member CardInstance.cur_triggered_abilities] never sees it.
##
## WHY IT WAS NOT HARMLESS. The liability pass called this understatement
## safe because [member AiProfile.spares_own]'s door needs a price BELOW
## zero and dead weight is only worth zero, so no harmful spell of ours
## could be pointed at the creature. That is true of THAT door and of no
## other caller: [method answer_card] gives up the LEAST valuable of ours
## when the giving is no cost we chose ([member AiProfile.feeds_worst]),
## and zero is the least there is. A Serra Angel under a Paralyze with
## four mana open was therefore fed to a Lord of the Pit's upkeep ahead of
## a Grizzly Bears, on a turn the {4} would have given the Angel back.
##
## STRUCTURAL, NOT CARD-NAMED. The link is [member
## CardInstance.attachments], the beat is [constant
## EffectIntent.TOLL_BEATS], the price is what [method
## EffectIntent.toll_of_line] already reads off a permanent's own line,
## and the line has to say UNTAP or it is some other bargain
## ([constant UNTAP_ESCAPE_WORD]). WHO CONTROLS the attachment is not
## asked, because the printed line does not ask it — "that player may pay
## {4}" is addressed to the creature's controller, and an enemy Paralyze
## is the copy of the card this pool actually plays. The trigger's own
## condition is put to it with a probe event (CR 603.4), exactly as
## [method _own_toll] does, so an offer that is not ours to take answers
## for itself.
##
## WHAT IT STILL DOES NOT REACH: a price printed on a permanent with NO
## structural link to the host — Magnetic Mountain's "{4} for each tapped
## blue creature" is offered to us by an enchantment that is attached to
## nothing, and tying it to THIS creature means reading the card's own
## filter. That one still understates, and still cannot give a permanent
## away through `spares_own`'s door.
const UNTAP_ESCAPE_WORD := "untap"


func _untap_prices(game: MtgGame, inst: CardInstance) -> Array[String]:
	var out: Array[String] = []
	var own := String(_own_toll(game, inst)["escape"])
	if own != "":
		out.append(own)
	for attached_id in inst.attachments:
		var attached := game.find_instance(attached_id)
		if attached == null or attached.zone != Mtg.Zone.BATTLEFIELD:
			continue
		for trig in attached.cur_triggered_abilities:
			if not EffectIntent.TOLL_BEATS.has(trig.event_type):
				continue
			if not trig.text.to_lower().contains(UNTAP_ESCAPE_WORD):
				continue
			if trig.condition.is_valid():
				var probe := GameEvent.new(trig.event_type, {"player": pid})
				if not trig.condition.call(game, attached, probe):
					continue
			var price := String(EffectIntent.toll_of_line(trig.text)["escape"])
			if price != "":
				out.append(price)
	return out


## THE TOLL (2026-09-09, [member AiProfile.prices_liabilities]): what this
## permanent of ours takes from us at the next beat of our own turn, and
## the mana price it prints to stop it — `{"damage": n, "escape": "{4}"}`.
##
## Every trigger the permanent actually has ([member
## CardInstance.cur_triggered_abilities], so a silenced or granted one is
## counted as the board has it) whose event is one of the beats that come
## round whether we like them or not ([constant EffectIntent.TOLL_BEATS]),
## and whose OWN condition says it would fire — the card's intervening
## "if" asked with a probe event, CR 603.4, which is the whole reason an
## UNTAPPED Mana Vault reads as no liability at all: its draw-step line
## tests `source.tapped` and answers for itself.
func _own_toll(game: MtgGame, inst: CardInstance) -> Dictionary:
	var out := {"damage": 0, "escape": ""}
	for trig in inst.cur_triggered_abilities:
		if not EffectIntent.TOLL_BEATS.has(trig.event_type):
			continue
		if trig.condition.is_valid():
			var probe := GameEvent.new(trig.event_type, {"player": pid})
			if not trig.condition.call(game, inst, probe):
				continue
		var line := EffectIntent.toll_of_line(trig.text)
		out["damage"] = int(out["damage"]) + int(line["damage"])
		if String(out["escape"]) == "":
			out["escape"] = line["escape"]
	return out


## What KEEPING [param inst] will cost us, on the evaluator's scale — the
## other half of [method _own_value] and the half that can push it below
## zero.
##
## THE PRICE IS THE TOLL TIMES THE TURNS IT STILL GETS, and neither number
## is chosen. The toll is what the card's own line says it takes
## ([method _own_toll]), charged at the reaper's rate for a point of our
## own life ([method _life_price] — half a point at twenty, two under
## seven), which is the same rate the sweep's relief is charged at
## ([method _sweep_relief]). The turns are the ones our mana still needs to
## reach the price the card itself prints to stop it, one source a turn,
## which is the rate a game of this pool actually develops at: a War Mage
## on one Mountain is three turns from the Vault's {4} and pays three
## points for them; on four Mountains it is none, and the Vault is not a
## liability at all because it will untap at the next upkeep.
##
## AND A TOLL WITH NO PRINTED PRICE IS NOT READ. A Serendib Efreet's point
## a turn and an Erg Raiders' two have no end but the game's, and [method
## Evaluator.permanent_value] is a SNAPSHOT — a 5/5 is worth ten whether
## the game lasts three turns or thirty — so a stream with no end cannot
## be subtracted from it without pricing every drawback creature in the
## pool out of its own deck. What this reading can price honestly is a
## toll we are paying only because we cannot yet afford to stop it, and
## that is the case the owner reported.
##
## RULED AND NOT BUILT, 2026-09-10. The honest price of an endless stream
## is the stream times a HORIZON — how long the game has left, or how long
## we expect to keep the permanent — and this engine has no such number
## and never has. Everything that looks like one was read and is not:
## [method _face_damage_value] scales a single hit by the share of a life
## total it takes and counts no turns; [method Evaluator.position_score]
## is a snapshot of life, board, hand and lands; [constant PACE_HORIZON]
## is twenty DRAW STEPS of a library race under [member
## AiProfile.paces_draws], a decking clock and not a game clock; the
## `turns` above are the turns our MANA needs to reach a printed price,
## which is a development rate, not an ending; and [CombatSearch] looks
## exactly one turn ahead. The only horizon that could be derived from
## what is here is the toll's own — our life divided by its rate, which is
## the cap on the line below — and taking it prices a Serendib Efreet at
## 8.5 minus the whole of our life: −1.5 at twenty, and every drawback
## creature in the pool out of its own deck. An invented constant would be
## worse than the silence, so the silence stands and the item closes:
## a toll with no printed escape is worth its printed worth, and the
## horizon is `counts_the_race`'s to bring (docs/AI-next-wave.md, wave 4).
##
## The whole price is capped at what our life is worth, because a toll can
## never take more than the life it has to take.
func _liability_price(game: MtgGame, inst: CardInstance) -> float:
	var toll := _own_toll(game, inst)
	var damage := int(toll["damage"])
	var escape := String(toll["escape"])
	if damage <= 0 or escape == "":
		return 0.0
	var cost := ManaCost.parse(escape)
	if _can_reach(game, inst, cost):
		return 0.0   # we stop it at the next beat
	var life := game.players[pid].life
	var turns := maxi(cost.mana_value() - _mana_reach(game, inst), 1)
	return minf(float(damage * turns), float(life)) * _life_price(life)


## Can a full untap pay [param cost]? [method MtgGame.can_afford_cost]
## asks what is untapped NOW, which says "no" on a turn we have already
## tapped out and would say it about a price we will comfortably pay at
## the next upkeep. The liability reading wants the seat's REACH, so the
## sources are counted as if they had all untapped — [param exclude] left
## out, because a permanent cannot pay for its own release.
func _can_reach(game: MtgGame, exclude: CardInstance, cost: ManaCost) -> bool:
	return _mana_reach(game, exclude) >= cost.mana_value()


## The mana a full untap would give us: every permanent's best mana
## ability, [param exclude] left out. Generic reach only — the colours of
## an escape price are not checked, which overstates what we can pay and
## therefore understates the liability, the safe direction.
func _mana_reach(game: MtgGame, exclude: CardInstance) -> int:
	var reach := 0
	for perm in game.players[pid].battlefield:
		if perm == exclude:
			continue
		var best := 0
		for ability in perm.cur_mana_abilities:
			var made := 0
			for pair in ability.produces:
				made += int(pair[1])
			best = maxi(best, made)
		reach += best
	return reach


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
			value = Evaluator.permanent_value(inst, profile)
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
##
## Under [member AiProfile.times_sweeps] the sum also carries THE RELIEF
## ([method _sweep_relief], the damage the sweep keeps off our life), so
## a control deck's own engines no longer price the board that is killing
## it as one not worth sweeping. The sweeper's own body, when it is a
## permanent (a Nevinyrral's Disk), COUNTS as a loss: the first cut of
## this left it out as "the activation's price" and the measurement
## showed the Disk going off at twenty life to kill a lone 3/3
## (2026-09-08, THE DECK, THIRD PASS).
##
## Under [member AiProfile.levels_boards] a sweep whose every kill is a
## LAND is read as the leveller it is — [method _land_sweep] for the two
## readings and why they belong to that knob.
func _sweep_value(game: MtgGame, effect: EffectBase, x_value: int) -> float:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var swing := 0.0
	var n := 0   # a DamageAllEffect's amount; unused by a DestroyAllEffect
	if effect is DamageAllEffect:
		n = x_value if effect.use_x else effect.amount
		if n <= 0:
			return 0.0
	elif not (effect is DestroyAllEffect):
		return 0.0
	var levels_lands := profile.levels_boards and _land_sweep(game, effect, n)
	for inst in game.all_battlefield():
		if not _sweep_kills(effect, inst, n):
			continue
		var worth := Evaluator.land_value(game, inst) if levels_lands \
			else Evaluator.permanent_value(inst, profile)
		swing += -worth if inst.controller_id == pid else worth
	swing *= Evaluator.W_BOARD
	# THE DROUGHT IS WON BY WHOEVER STILL HAS A CLOCK (2026-09-10,
	# AiProfile.levels_boards). An all-lands sweep kills nothing on the
	# table, so both boards go on hitting each other with no mana to
	# answer with, and whatever theirs gets through ours does not is a
	# toll the sweep hands them — charged at the reaper's rate ([method
	# _life_price]), the same currency the relief credits damage in, and
	# for one turn of it, because how many turns a drought lasts is the
	# horizon this engine does not have (docs/ai-difficulty.md §5). So a
	# Serra Angel across the table is four points of price against the
	# land swing and two Grizzly Bears are one, which is the difference
	# between a blunder and a close call.
	if levels_lands:
		var toll := _drought_clock(game, them.id) - _drought_clock(game, me.id)
		if toll > 0:
			swing -= float(toll) * _life_price(me.life)
	if effect is DamageAllEffect and effect.hit_players:
		if n >= me.life:
			return -LETHAL_WORTH   # never
		if n >= them.life:
			return LETHAL_WORTH
		swing += n * Evaluator.W_LIFE           # their life
		# Our life is dearer the lower we are.
		var life_price := 1.0 if me.life - n > 10 else 2.0
		swing -= n * life_price
	if profile.times_sweeps:
		swing += _sweep_relief(game, effect, n)
	return swing


## Would [param effect] (a DestroyAllEffect, or a DamageAllEffect dealing
## [param n]) kill [param inst] as it stands? The one death rule
## [method _sweep_value] and [method _sweep_relief] share.
func _sweep_kills(effect: EffectBase, inst: CardInstance, n: int) -> bool:
	if effect is DestroyAllEffect:
		var hit: bool = effect.filter.call(inst) if effect.filter.is_valid() \
			else inst.is_creature()
		if not hit or inst.cur_indestructible:
			return false
		if effect.can_regenerate and inst.regeneration_shields > 0:
			return false
		return true
	if effect is DamageAllEffect:
		if not inst.is_creature():
			return false
		if effect.creature_filter.is_valid() and not effect.creature_filter.call(inst):
			return false
		return inst.damage + n >= inst.cur_toughness
	return false


## THE LAND SWEEP (2026-09-10, AiProfile.levels_boards): is [param effect]
## a sweeper that takes LANDS AND NOTHING ELSE off this board?
##
## Read off the board rather than off a name: every permanent the sweep
## would kill is a land, and it would kill at least one. Armageddon is the
## card that asks it in this pool's shipped decks (four in Armies of
## Light, in High Priest, in Sainted One); the one-sided land sweepers —
## Flashfires, Tsunami, Acid Rain — answer it the same way and are
## sideboard cards in every list that holds them. A Wrath, an Earthquake
## or a Nevinyrral's Disk fails at the first non-land it kills, and a Disk
## on a board of nothing but lands kills nothing at all, so neither reads
## as one.
##
## WHY IT BELONGS TO THE LEVELLER and not to a knob of its own: [member
## AiProfile.levels_boards] is "price a spell that levels both sides by
## what each side would lose", and an all-lands sweep is that sentence
## with only the land clause — the same reading [method _level_value]
## already makes about a Balance's lands, made in the sweeper's own
## function because that is where an all-lands sweeper is priced. Two
## knobs for one idea would be the second difficulty concept
## docs/ai-difficulty.md §1 forbids.
##
## [forge] The shape of the rule is `DestroyAllAi.java:146-163` (commit
## `b09a3d3f`, docs/forge/casting.md §3.3): an all-lands branch, a
## creature comparison and a land-value comparison. Neither of its numbers
## is taken — the creature comparison is a CLOCK here (see [method
## _drought_clock], which is why), and its land test is the swing itself
## once the lands are priced by [method Evaluator.land_value]. Its third
## clause, a Crucible of Worlds, names a card this pool does not have.
func _land_sweep(game: MtgGame, effect: EffectBase, n: int) -> bool:
	var any := false
	for inst in game.all_battlefield():
		if not _sweep_kills(effect, inst, n):
			continue
		if not inst.is_land():
			return false
		any = true
	return any


## THE CLOCK a land sweep would leave [param of_pid] holding: the damage
## their board puts through the other's best blocks, [method
## _damage_through_blocks] — the same reading [method _sweep_relief] asks
## their next attack with, so the two agree about what a board does.
##
## WHY A CLOCK AND NOT A SUM. The first cut of this test compared the two
## sides on [method Evaluator.permanent_value] (Forge's own
## `evaluateCreatureList` comparison) and MEASURED WORSE where it mattered
## most: that scale is power plus toughness, so an Ironroot Treefolk
## outweighs two Savannah Lions and a white weenie deck reads as behind
## against the wall that cannot catch it. Armies of Light vs Big Green
## lost 15 of the 17 games that turned on it. What decides a game with no
## mana in it is not what the boards are WORTH but what they get THROUGH.
##
## Two things are deliberately not asked. A creature that has not shed its
## summoning sickness still counts: the drought lasts turns, not one step.
## And "can't attack unless defending player controls a <type>" is not
## read, because a sweep that takes every land takes that land too.
func _drought_clock(game: MtgGame, of_pid: int) -> int:
	var against := game.opponent_of(of_pid)
	var attackers: Array[CardInstance] = []
	for inst in game.players[of_pid].battlefield:
		if not inst.is_creature() or inst.cur_power <= 0:
			continue
		if inst.has_keyword(Mtg.Keyword.DEFENDER) or inst.cur_cant_attack:
			continue
		attackers.append(inst)
	var blockers: Array[CardInstance] = []
	for inst in game.players[against].battlefield:
		if inst.is_creature():
			blockers.append(inst)
	return _damage_through_blocks(game, attackers, blockers, against)


## THE RELIEF (2026-09-08, AiProfile.times_sweeps): what the sweep keeps
## off our life, on the Evaluator's scale. Their attack is read twice
## through [method _damage_through_blocks] — the same one-blocker-per-
## attacker maths the attack code prices its own swings by — once with
## the board as it stands and once with what the sweep leaves, and the
## difference is charged at the reaper's rate ([method _life_price]:
## half a point a life at twenty, two under seven). When the attack as
## it stands is lethal and the sweep's remainder is not, the sweep is
## the out and worth [constant LETHAL_WORTH], the way every other lethal
## is priced. The attack is the DECLARED one when we are in their combat
## with the damage still to come (the attackers named, our untapped
## bodies the blockers, or only the unblocked ones once blocks are in),
## and otherwise the next-turn model the crack-back read uses: every
## creature of theirs that could attack ([method _could_attack_next_turn]
## — Defender, "can't attack" and our Moat honoured), our untapped
## creatures the blockers. A Fog already cast leaves nothing to relieve.
##
## The next-turn model honours THE APPETITE ([method _upkeep_meals]): a
## creature of theirs an Abyss takes at their upkeep never attacks, on
## the board as it stands and on what the sweep leaves of it alike — a
## Disk that takes the Abyss with the board takes its appetite too. The
## first cut of this read the board without it and fired a Disk at one
## life into a lone Llanowar Elves our own Abyss was about to eat, losing
## two Tomes, two Scepters and the mana that went with them.
func _sweep_relief(game: MtgGame, effect: EffectBase, n: int) -> float:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var attackers: Array[CardInstance] = []
	var survivors: Array[CardInstance] = []
	var blockers: Array[CardInstance] = []
	var left: Array[CardInstance] = []
	var declared := game.active_player != pid and not game.combat.attackers.is_empty() \
		and game.current_step() <= Mtg.Step.DECLARE_BLOCKERS
	if declared:
		if game.combat_damage_prevented:
			return 0.0
		var blocks_in := game.current_step() == Mtg.Step.DECLARE_BLOCKERS \
			and not game.awaiting_blockers
		for attacker_id in game.combat.attackers:
			var attacker := game.find_instance(attacker_id)
			if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD \
					or attacker.cur_power <= 0:
				continue
			if blocks_in and game.combat.was_blocked(game.combat.band_of(attacker_id)):
				continue   # a blocked attacker lands nothing on us (trample aside)
			attackers.append(attacker)
			if not _sweep_kills(effect, attacker, n):
				survivors.append(attacker)
		if not blocks_in:
			for inst in me.battlefield:
				if inst.is_creature() and not inst.tapped:
					blockers.append(inst)
					if not _sweep_kills(effect, inst, n):
						left.append(inst)
	else:
		var board := game.all_battlefield()
		var remains: Array[CardInstance] = []
		for inst in board:
			if not _sweep_kills(effect, inst, n):
				remains.append(inst)
		var eaten := _upkeep_meals(game, them.id, board)
		var eaten_after := _upkeep_meals(game, them.id, remains)
		for inst in them.battlefield:
			if inst.cur_power <= 0 or not _could_attack_next_turn(game, inst):
				continue
			if not eaten.has(inst):
				attackers.append(inst)
			if remains.has(inst) and not eaten_after.has(inst):
				survivors.append(inst)
		for inst in me.battlefield:
			if inst.is_creature() and not inst.tapped:
				blockers.append(inst)
				if not _sweep_kills(effect, inst, n):
					left.append(inst)
	if attackers.is_empty():
		return 0.0
	var before := _damage_through_blocks(game, attackers, blockers, pid)
	var after := _damage_through_blocks(game, survivors, left, pid)
	var relief := before - after
	if relief <= 0:
		return 0.0
	var value := relief * _life_price(me.life)
	if before >= me.life and after < me.life:
		value += LETHAL_WORTH   # the sweep is the out
	return value


## THE APPETITE (2026-09-08, AiProfile.times_sweeps): the creatures
## [param who]'s next upkeep takes from them before they can attack — one
## per permanent whose trigger declares
## [member TriggeredAbility.kills_each_upkeep] (The Abyss, whoever
## controls it), the least valuable legal one each time, the choice being
## theirs ([member AiProfile.feeds_worst] is what they answer with; a
## human is assumed no more generous). [param alive] is the board the
## count is made on: the battlefield as it stands, or what a sweep leaves
## of it, so a sweep that kills the feeder kills its appetite.
func _upkeep_meals(game: MtgGame, who: int,
		alive: Array[CardInstance]) -> Array[CardInstance]:
	var eaten: Array[CardInstance] = []
	for feeder in alive:
		for ability in feeder.cur_triggered_abilities:
			var spec: TargetSpec = ability.kills_each_upkeep
			if spec == null:
				continue
			var meal: CardInstance = null
			for inst in alive:
				if inst.controller_id != who or eaten.has(inst):
					continue
				if not spec.is_legal(game, TargetRef.card(inst), feeder):
					continue
				if meal == null or Evaluator.permanent_value(inst, profile) \
						< Evaluator.permanent_value(meal, profile):
					meal = inst
			if meal != null:
				eaten.append(meal)
	return eaten


## THE ABYSS AS AN ANSWER (2026-09-08, [member AiProfile.trusts_abyss]):
## would [param card], resolved onto [param who]'s battlefield as
## printed, be the NEXT MEAL of a feeder on the table — a permanent
## whose upkeep trigger declares an appetite ([member
## TriggeredAbility.kills_each_upkeep]) that the body satisfies, with no
## legal creature of theirs worth less to be fed first? The card is
## still on the stack, so the spec's zone check cannot be asked; its
## own filter (nonartifact, for the Abyss) and printed protection are.
## The meal is the least valuable legal creature, the same reading
## [method _upkeep_meals] makes of a board.
func _is_next_meal(game: MtgGame, card: CardInstance, who: int) -> bool:
	var worth := Evaluator.permanent_value(card, profile)
	for feeder in game.all_battlefield():
		for ability in feeder.cur_triggered_abilities:
			var spec: TargetSpec = ability.kills_each_upkeep
			if spec == null:
				continue
			if spec.filter.is_valid() and not spec.filter.call(card):
				continue
			if (card.cur_protection & feeder.cur_colors) != 0:
				continue
			var sheltered := false
			for inst in game.players[who].battlefield:
				if not spec.is_legal(game, TargetRef.card(inst), feeder):
					continue
				# THE TWIN (2026-09-10): a creature already on the table
				# that is worth NO MORE than the newcomer shelters it just
				# as surely as a cheaper one does — the feeder takes one
				# body a turn, so a second Sengir Vampire beside the first
				# leaves a Sengir Vampire standing whichever of the two is
				# eaten. The test was `<`, so the pilot read the newcomer
				# as the next meal, kept its Counterspell, and the pair
				# traded one copy for nothing (reproduced 2026-09-10:
				# `_is_next_meal(second Sengir) = true`).
				if Evaluator.permanent_value(inst, profile) <= worth:
					sheltered = true
					break
			if not sheltered:
				return true
	return false


## THE SHELTER CAST (2026-09-10, [member AiProfile.trusts_abyss]): what
## letting [param card] resolve onto [param who]'s battlefield would SAVE
## from the feeder's next meal, on the Evaluator's scale — 0.0 when it
## saves nothing.
##
## [method _is_next_meal] reads the table as it stands, and the table does
## not stand still. The counter is kept because The Abyss will eat their
## Serra Angel at their upkeep; they then cast a Mesa Pegasus, which is
## cheaper, and the Abyss eats THAT instead — one Counterspell saved, one
## Serra Angel on the table, which is the trade the knob was built to
## avoid (reproduced 2026-09-10: the meal goes from `Serra Angel(10.0)`
## to `Mesa Pegasus(3.8)` the moment the one-drop lands, and the Pegasus's
## own printed worth of 3.8 is below [member AiProfile.counter_threshold],
## so [method _try_counter] returned before it ever asked about the
## Abyss).
##
## THE READING IS THE "AFTER" BOARD, ASKED ONCE MORE. The meal a feeder
## takes today is the cheapest legal creature of theirs ([method
## _upkeep_meals]'s own rule, and the choice is theirs — [member
## AiProfile.feeds_worst] is what they answer with). A newcomer worth less
## than that displaces it, and what the displacement buys them is exactly
## the difference: the dear body lives, the cheap one dies in its place.
## That number is what the spell is worth countering for, and it is
## nothing whatever to do with what the spell is worth on the board — a
## Mesa Pegasus that saves a Serra Angel is a Serra Angel.
##
## ONE FEEDER AT A TIME, taking the largest displacement. Two feeders
## would each take a meal and the second one's is a board this reader
## would have to simulate; the pool has one card of the shape and the
## honest single-feeder number is the one that can be read off the table.
func _shelter_swing(game: MtgGame, card: CardInstance, who: int) -> float:
	var worth := Evaluator.permanent_value(card, profile)
	var best := 0.0
	for feeder in game.all_battlefield():
		for ability in feeder.cur_triggered_abilities:
			var spec: TargetSpec = ability.kills_each_upkeep
			if spec == null:
				continue
			# The card is on the stack, so the spec's zone check cannot be
			# asked; its own filter and printed protection are — the same
			# reading [method _is_next_meal] makes of a spell.
			if spec.filter.is_valid() and not spec.filter.call(card):
				continue
			if (card.cur_protection & feeder.cur_colors) != 0:
				continue
			var meal: CardInstance = null
			for inst in game.players[who].battlefield:
				if not spec.is_legal(game, TargetRef.card(inst), feeder):
					continue
				if meal == null or Evaluator.permanent_value(inst, profile) \
						< Evaluator.permanent_value(meal, profile):
					meal = inst
			if meal == null:
				continue
			var saved := Evaluator.permanent_value(meal, profile)
			if worth < saved:
				best = maxf(best, saved - worth)
	return best


## What a leveller (Balance: [member EffectIntent.levels]) would move,
## on the Evaluator's scale — theirs counting for us, ours against. Each
## pass measures the fewest across the two seats and every card over it
## goes: a land at what one more is worth to the player left with the
## fewest ([method Evaluator.land_value]'s curve, W_LANDS), a card in
## hand at the pilot's own [member AiProfile.w_hand] (the sweep of
## 2026-09-10 moves this reading with [method Evaluator.position_score]'s,
## so that one number is being measured and not two), a creature at its
## permanent value times W_BOARD. The
## choices being each player's own, the CHEAPEST creatures are the ones
## assumed to go (the order the card's own default takes,
## BalanceEffect._cheapest_first), and the leveller itself is on the
## stack by the time the hands are counted (CR 601.2a).
func _level_value(game: MtgGame, source: CardInstance) -> float:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var swing := 0.0
	# Lands.
	var my_lands := 0
	var their_lands := 0
	for inst in me.battlefield:
		if inst.is_land():
			my_lands += 1
	for inst in them.battlefield:
		if inst.is_land():
			their_lands += 1
	var fewest := mini(my_lands, their_lands)
	var land_price := Evaluator.W_LANDS * (1.0 + 3.0 / float(maxi(fewest, 1)))
	swing += float(their_lands - fewest) * land_price
	swing -= float(my_lands - fewest) * land_price
	# Hands.
	var my_hand := me.hand.size() - (1 if source.zone == Mtg.Zone.HAND else 0)
	var their_hand := them.hand.size()
	fewest = mini(my_hand, their_hand)
	swing += float(their_hand - fewest) * profile.w_hand
	swing -= float(my_hand - fewest) * profile.w_hand
	# Creatures: each side gives up its cheapest, however big the rest.
	var mine: Array[float] = []
	var theirs: Array[float] = []
	for inst in me.battlefield:
		if inst.is_creature():
			mine.append(Evaluator.permanent_value(inst, profile))
	for inst in them.battlefield:
		if inst.is_creature():
			theirs.append(Evaluator.permanent_value(inst, profile))
	mine.sort()
	theirs.sort()
	fewest = mini(mine.size(), theirs.size())
	for i in theirs.size() - fewest:
		swing += theirs[i] * Evaluator.W_BOARD
	for i in mine.size() - fewest:
		swing -= mine[i] * Evaluator.W_BOARD
	return swing


func _board_value(game: MtgGame, of_pid: int) -> float:
	var total := 0.0
	for inst in game.players[of_pid].battlefield:
		if not inst.is_land():
			total += Evaluator.permanent_value(inst, profile)
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
##
## THE STING ON THE END OF A PUNISHER'S REMOVAL ([member
## EffectIntent.damage_to_target_controller]) is priced on BOTH sides of
## the table since 2026-09-10, under the same knob that read the first
## half of it ([member AiProfile.prices_liabilities]). The field was born
## with that knob and only its own-side half was charged — the price we
## pay to relieve ourselves of a liability — so the sentence the reader
## could say was half a sentence: a Detonate that costs us X to our own
## face gained the same X against theirs for nothing. Two things follow
## from finishing it, and the second is the one a table sees: their life
## is priced on the AI's own clock ([method _face_damage_value], the
## currency every point of combat damage to a face is already read in),
## and a sting that is LETHAL is worth [constant LETHAL_WORTH] like every
## other lethal line in this file — a Detonate on their Nevinyrral's Disk
## with the opponent at four is a kill the pilot could not see.
func _cast_value(game: MtgGame, inst: CardInstance, targets: Array, x_value: int) -> float:
	var value := _card_value(inst.data)
	if inst.data.cost.has_x:
		value = maxf(value, float(x_value) * 1.5)
	var intent: EffectIntent = null
	for t in targets:
		if t is TargetRef and not t.is_player:
			var victim := game.find_instance(t.instance_id)
			if victim == null:
				continue
			if victim.controller_id != pid:
				value += Evaluator.permanent_value(victim, profile) * 0.5
				# ONE OF THEIRS, and the sting it carries (2026-09-10).
				if not profile.prices_liabilities:
					continue
				if intent == null:
					intent = _intent_of(inst)
				var theirs := _controller_sting(intent, x_value)
				if theirs <= 0:
					continue
				if theirs >= game.players[victim.controller_id].life:
					return LETHAL_WORTH
				value += _face_damage_value(game, theirs, victim.controller_id)
				continue
			# ONE OF OUR OWN (2026-09-09, AiProfile.prices_liabilities).
			# Until this landed, [method _extra_targets]'s note was
			# literally true: an own-side victim was charged NOTHING, the
			# picker being the only gate. It is charged now — and CREDITED
			# when it is a liability, on the same half-share an enemy
			# victim is credited at, so a Detonate on our own dead Mana
			# Vault is worth what the Vault was costing us and no more.
			if not profile.prices_liabilities:
				continue
			value += maxf(-_own_value(game, victim), 0.0) * 0.5
			# ...and the sting the card puts on its own target's
			# controller is OURS to pay when the target is ours (Detonate's
			# X, [member EffectIntent.damage_to_target_controller]),
			# charged at the reaper's rate like every other self-damage.
			if intent == null:
				intent = _intent_of(inst)
			var sting := _controller_sting(intent, x_value)
			if sting > 0:
				value -= float(sting) * _life_price(game.players[pid].life)
	return value


## How much [param intent]'s "damage to that permanent's controller"
## actually deals at X = [param x_value]. The field carries -1 for "the
## amount is the spell's X" ([member
## EffectIntent.damage_to_target_controller]); everything else is the
## printed number. One line, so the two sides of the table cannot read the
## same field differently.
static func _controller_sting(intent: EffectIntent, x_value: int) -> int:
	var sting := intent.damage_to_target_controller
	if sting < 0:
		return maxi(x_value, 0)
	return sting


## The reader's summary of what [param inst] does as a SPELL — the whole
## card, not one mode. One line, so the readings that want it can share a
## sentence about where it comes from.
func _intent_of(inst: CardInstance) -> EffectIntent:
	return EffectIntent.read(inst.data.spell_effects, inst.data.card_name)


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
	# THE LEVELLER (2026-09-07, AiProfile.levels_boards): a spell that
	# levels lands, hands and creatures down to the fewest is priced the
	# way a sweeper is — by what each side would lose — and waits below
	# the sweeper's bar. Off, it is cast for its printed worth, below.
	if intent.levels and profile.levels_boards and not data.is_modal():
		var swing := _level_value(game, inst)
		if swing < SWEEP_BAR:
			return {}
		return {"x": 0, "targets": [], "value": swing}
	# THE FALLOUT (2026-09-09, AiProfile.prices_fallout): a spell that
	# destroys what it targets and then blasts EVERY creature and BOTH
	# players is sized and priced by [method _size_blast]. Off, it falls
	# through to the plain targeted path below, which reads the victims it
	# names and nothing else — the pilot that Erupted itself to death.
	if intent.blasts and profile.prices_fallout and not data.is_modal():
		return _size_blast(game, inst, max_x, mode)
	if intent.damage_uses_x and intent.target_spec != null and not data.is_modal():
		return _size_x_burn(game, inst, intent, max_x)
	# A tap is worth nothing by itself: it has a POLICY, not a value.
	if intent.is_tap_utility() and not data.is_modal():
		return _size_tap(game, inst, intent, max_x, mode)
	if intent.draws_use_x and max_x < 2 and game.players[pid].hand.size() > 1:
		return {}   # Braingeyser for one is a bad Ancestral
	# THE PACE (2026-09-07, AiProfile.paces_draws): a search is a card off
	# the library as much as a draw is, and the race counts it the same.
	if intent.searches and not data.is_modal() and _library_slack(game) < 1:
		return {}
	# TIME WALK'S DRAW STEP (2026-09-08, AiProfile.paces_draws): an extra
	# turn is a draw step off our library before theirs comes round, and
	# the race counts it the way it counts a Tome.
	if intent.extra_turns > 0 and not data.is_modal() \
			and _library_slack(game) < intent.extra_turns:
		return {}
	# THE COUNT (2026-09-07, AiProfile.counts_cards): an X that draws or
	# discards is sized to the cards it acts on, not to the mana at hand.
	if profile.counts_cards and not data.is_modal():
		if intent.draws_use_x:
			var win_x := _decking_draw(game, inst, intent, max_x, max_x)
			if win_x >= 0:
				return {"x": win_x, "targets": [TargetRef.player(game.opponent_of(pid))],
					"value": LETHAL_WORTH}
			# Our own draw: the room in the hand, and never the library's
			# last card.
			var x := mini(max_x, _hand_room(game, Moment.MAIN, inst))
			x = mini(x, game.players[pid].library.size() - 1)
			if x < 1 or (x < 2 and game.players[pid].hand.size() > 1):
				return {}
			var targets = _choose_targets(game, inst, x, mode)
			if targets == null:
				return {}
			return {"x": x, "targets": targets, "value": _cast_value(game, inst, targets, x)}
		if intent.discards < 0 and intent.target_spec != null \
				and intent.target_spec.kind == TargetSpec.Kind.PLAYER:
			# An X discard at a player: their hand is the ceiling, an empty
			# hand is a reason to wait, and a Twist for one that leaves them
			# holding more is the deck's one Twist wasted.
			var their_hand := game.players[game.opponent_of(pid)].hand.size()
			var x := mini(max_x, their_hand)
			if x <= 0 or (x < 2 and x < their_hand):
				return {}
			var targets = _choose_targets(game, inst, x, mode)
			if targets == null:
				return {}
			return {"x": x, "targets": targets, "value": _cast_value(game, inst, targets, x)}
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
		var worth := Evaluator.permanent_value(victim, profile)
		if worth >= 3.0:
			var need: int = victim.cur_toughness - victim.damage - intent.damage
			# THE HOLD (2026-09-10, [member AiProfile.holds_x_burn]): a
			# burn whose whole reach is small, pointed at a creature while
			# the game is young, is the finisher thrown away. See [method
			# _holds_x_burn]. The face arm below still gets its say, so a
			# burn worth throwing at a player within range of it is still
			# thrown.
			if not _holds_x_burn(game, max_x):
				return {"x": clampi(need, 1, max_x),
					"targets": [TargetRef.card(victim)], "value": worth + 1.0}
	if face_ok and max_x >= 4 and them.life <= intent.damage_at(max_x) * 2:
		return {"x": max_x, "targets": [TargetRef.player(opponent)],
			"value": intent.damage_at(max_x) * 0.75 + 2.0}
	return {}


## THE X BURN HELD FOR A BIGGER ONE (2026-09-10, [member
## AiProfile.holds_x_burn]).
##
## An X burn spell is the only card in a hand whose worth GROWS with the
## turn: a Fireball is two damage on turn three and eight on turn nine,
## and the deck holds it because it is the reach. [method _size_x_burn]
## sizes the X to the victim, which is right, and then fired a two-point
## Disintegrate at a Grizzly Bears on turn three — one of the deck's two
## finishers spent on a bear, on a board a Lightning Bolt answers for one
## mana.
##
## The knob is a NUMBER and not a switch because what is held is a SIZE:
## the burn waits while the LARGEST X the mana can reach is under the
## number AND the game is younger than twice that in turns, so the hold
## expires on its own and a Fireball is never held for a game that has
## stopped being young. [member MtgGame.turn_number] counts a PLAYER's
## turn, so twice the threshold is the Wizard's ninth and the Sorcerer's
## fifth.
##
## THE REACH AND NOT THE SHOT, and the difference was measured rather
## than argued. [param max_x] is what the mana can pay; the X this
## routine would actually spend on the victim is smaller. Gating on the
## SHOT was built first and refuses a Fireball for four at a Serra Angel
## — a play `tests/ai/test_ai_capabilities.gd` has pinned as correct
## since the Fireball was first sized, and one no human would decline —
## because four is under the Wizard's five for the whole of a game's
## first nine turns. Gating on the REACH says the honest thing instead:
## while the card can only be small it is not yet the answer to anything,
## and once it is big the sizing that was already right takes over. It is
## also what Forge does, `dmg` there being its own maximum X.
##
## Two things end it early, and each is a reading this pilot already
## makes rather than a constant:
##
##  * LETHAL is not asked here at all. [method _size_x_burn] returns the
##    FACE before it ever looks for a creature, so reaching this line
##    means the burn does not win the game on the spot.
##  * THEIR CLOCK ([method _in_danger]): a pilot the board in front of it
##    is about to kill spends the card it was keeping for turn nine.
##
## [forge] `DamageDealAi.canPlayAI`
## (forge-ai/src/main/java/forge/ai/ability/DamageDealAi.java:97-160),
## commit b09a3d3f: `dmg < HOLD_X_DAMAGE_SPELLS_THRESHOLD && turn / 2 <
## threshold && !inDanger && !isLethal` refuses the play, with the
## threshold 5 in the Default profile and 3 in Reckless — which is where
## the two rungs come from (docs/forge/casting.md, P7). The ROLL that
## gates it there (`HOLD_X_DAMAGE_SPELLS_FOR_MORE_DAMAGE_CHANCE`, 100 and
## 85) is not ported: nothing in this AI is decided by a coin
## (docs/forge/README.md, "what is not to be copied").
func _holds_x_burn(game: MtgGame, max_x: int) -> bool:
	if profile.holds_x_burn <= 0:
		return false
	if max_x >= profile.holds_x_burn:
		return false
	if game.turn_number >= profile.holds_x_burn * 2:
		return false
	return not _in_danger(game)


## THEIR CLOCK: would the attack the board in front of us can declare put
## this seat on the panic line?
##
## [member AiProfile.chump_threshold] read a fourth time — the chump
## block, the prevention window and the blast's own X are the other three
## — and asked of the damage that would ACTUALLY land, through the block
## plan this seat would make ([method _damage_after_value_blocks]), not
## of the total power standing on the table.
##
## Every creature of theirs counts, tapped ones included: they untap
## before they swing, which is the reading [method _search_hold_back]
## already makes. Ours are offered as blockers and the block predicate
## refuses the tapped ones itself, so a swing reads as slightly more
## dangerous than it is — the safe direction for a question whose wrong
## answer is a card held while the game ends.
func _in_danger(game: MtgGame) -> bool:
	var me := game.players[pid]
	var theirs: Array[CardInstance] = []
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.is_creature() and inst.cur_power > 0 \
				and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			theirs.append(inst)
	if theirs.is_empty():
		return me.life <= profile.chump_threshold
	var mine: Array[CardInstance] = []
	for inst in me.battlefield:
		if inst.is_creature():
			mine.append(inst)
	return me.life - _damage_after_value_blocks(game, theirs, mine) \
		<= profile.chump_threshold


# ================================================================ the blast --
#
# A SPELL THAT ANSWERS TO BOTH SIDES OF THE TABLE (2026-09-09,
# [member AiProfile.prices_fallout]). Volcanic Eruption destroys X target
# Mountains and then deals that many damage to each creature and each
# player — the pool's one card whose targeted half points across the table
# and whose untargeted half lands on ours as hard as on theirs
# ([constant EffectIntent.BLASTS]).
#
# Two things had to be answered and the generic path answered neither.
# WHAT IT IS WORTH: [method _cast_value] credits the victims a spell names
# and knows nothing about what it does on the way past, so the blast was
# free — the Serra Angels it burned to take four lands cost the planner
# nothing, and neither did the last five points of its own life. WHAT X TO
# PAY: the X here buys TARGETS, not damage (the Detonate reading, CR
# 601.2b), so an X past the Mountains on the table is mana paid for
# nothing, and the fall-through simply spent every point it could afford.
#
# The answer to both is one loop: try each affordable X, price the whole
# resolution, and keep the best — a strict `>` from a floor of zero, so a
# tie goes to the CHEAPEST X and a board where the spell is not worth
# casting leaves it in hand.
#
# THE PANIC LINE, READ THE OTHER WAY ROUND. [method _sweep_value]'s life
# guard is "never a sweep that is lethal to us", which is the right rule
# for a sweeper whose size is printed on it and the wrong one for a spell
# whose size we are choosing: it let the Eruption at five life step back
# from X=6 and take X=4 instead, which is one life and an opponent at
# fourteen. [member AiProfile.chump_threshold] is already the life total
# at which this seat starts spending resources purely to survive, in both
# of its readings — the chump block and the prevention window — so it is
# the same question a third time, asked of our own spell: an X that would
# put US on that line or below it is not paid, unless the blast wins the
# game outright. It needs no number of its own, and it gives the rule a
# per-rung shape for free: an Apprentice (3) walks closer to the edge
# than a Wizard (6), which is what the lower rungs are.


## Size and aim a blast, or `{}` to hold it. See the note above.
func _size_blast(game: MtgGame, inst: CardInstance, max_x: int,
		mode: int) -> Dictionary:
	var me := game.players[pid]
	var them := game.players[game.opponent_of(pid)]
	var best_x := -1
	var best_targets: Array = []
	var best_value := 0.0
	for x in range(1, max_x + 1):
		var aim = _choose_targets(game, inst, x, mode)   # Array or null
		if aim == null or aim.is_empty():
			continue
		# What the X actually BOUGHT: the picker fills as many slots as the
		# board can (CR 601.2c), so the blast is the count it came back
		# with, and so is the X worth paying for.
		var bought: int = mini(x, aim.size())
		if bought < them.life and me.life - bought <= profile.chump_threshold:
			continue   # the panic line, read the other way round
		var worth := _cast_value(game, inst, aim, bought) + _blast_price(game, bought)
		if worth > best_value:
			best_x = bought
			best_targets = aim
			best_value = worth
	if best_x < 0:
		return {}
	return {"x": best_x, "targets": best_targets, "value": best_value}


## What the blast half is worth once [param n] permanents are buried: the
## sweeper reading, whole. [method _sweep_value] already prices "damage to
## each creature and each player" from both boards and both life totals —
## what dies on their side minus what dies on ours, their life at the
## board scale and ours at the reaper's, a lethal blast at [constant
## LETHAL_WORTH] and one that is lethal to US at minus the same, which is
## the line the Eruption at five life walked over. The [DamageAllEffect]
## built here is the sentence the shared vocabulary would have carried had
## the card been able to use it; nothing is added to the game with it.
func _blast_price(game: MtgGame, n: int) -> float:
	if n <= 0:
		return 0.0
	return _sweep_value(game, DamageAllEffect.new(n).and_each_player(), n)


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
			worth += Evaluator.permanent_value(mark, profile)
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
		var worth := Evaluator.permanent_value(mark, profile)
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


## CHANNEL-FIREBALL (2026-09-10, [member AiProfile.reads_lethal_x];
## `docs/forge/casting.md` P6). The gate [method _mana_spell_enables] is
## for Dark Ritual, applied to the spell that sells mana for LIFE: cast it
## only in a step where the life it opens makes an X burn in hand LETHAL.
##
## The bar is deliberately higher than the Ritual's. Dark Ritual is worth
## casting whenever it turns an unaffordable card into an affordable one,
## because the mana costs nothing but the card; this costs LIFE, and life
## spent on a Fireball that does not finish them is life they finish us
## with. Probed at HEAD the pilot cast Channel into an empty board on turn
## three for a card's worth of 3.00 and never paid a point — the card was
## simply thrown away — so with the knob off nothing here runs and that is
## still what happens.
##
## [param sources] is the seat's own list; the life is capped by
## [method _life_for_mana_budget].
func _life_mana_enables(game: MtgGame, spell: CardInstance,
		sources: Array) -> bool:
	return not _lethal_x_off_life(game, spell, sources).is_empty()


## THE X BURN THE LIFE WOULD FINISH THEM WITH, as
## `{inst, x, life}` — or `{}`.
##
## [param spending] is the spell that OPENS the life-for-mana source when
## it is still in hand (Channel on the stack has not resolved, so its own
## cost is charged and it is not itself a candidate), and null once the
## source is open and the only question left is how much life to pay.
##
## Their life is the X to find, and the reach is what the board pays plus
## the life we may spend. Two printed shapes reach a player's life with an
## X and the pool holds one of each behind a Channel: the AIMED burn
## (Fireball, Disintegrate — [method _lethal_burn]'s own test) and the
## SWEEPER THAT HITS PLAYERS (Hurricane, Earthquake), whose X lands on us
## as well and must therefore leave us alive. The only new arithmetic is
## the budget.
func _lethal_x_off_life(game: MtgGame, spending: CardInstance,
		sources: Array) -> Dictionary:
	var budget := _life_for_mana_budget(game)
	if budget <= 0:
		return {}
	var opening := 0
	if spending != null:
		# Channel's own cost is paid out of the same board, so the mana it
		# takes is not there for the burn.
		var plan := _plan_taps_from(sources, spending.data.cost,
			game.spell_surcharge(pid, spending.data),
			game.mana_usage_keys(spending.data))
		if plan.is_empty() and not _cost_is_free(spending.data.cost):
			return {}
		opening = spending.data.cost.mana_value() \
			+ game.spell_surcharge(pid, spending.data)
	var me := game.players[pid]
	var opponent := game.opponent_of(pid)
	var their_life := game.players[opponent].life
	for inst in me.hand:
		if inst == spending or inst.is_land() or inst.data.is_modal():
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # locked, banned, "cast only ...", or refused this step
		if not inst.data.cost.has_x or inst.data.x_color != 0:
			continue   # "spend only black mana on X": life buys none of it
		var intent := _intent_of(inst)
		# TWO SHAPES REACH A PLAYER'S LIFE WITH AN X, and the pool holds one
		# of each behind a Channel: the AIMED burn (Fireball, Disintegrate)
		# and the SWEEPER THAT HITS PLAYERS (Hurricane, Earthquake), whose
		# damage lands on us as well and therefore has to be survived.
		var aimed := intent.damage_uses_x and intent.target_spec != null \
			and (intent.target_spec.kind == TargetSpec.Kind.ANY
				or intent.target_spec.kind == TargetSpec.Kind.PLAYER) \
			and intent.target_spec.is_legal(game, TargetRef.player(opponent), inst)
		var swept: bool = intent.sweeper is DamageAllEffect \
			and intent.sweeper.hit_players and intent.sweeper.use_x
		if not (aimed or swept):
			continue
		if aimed and intent.self_damage >= me.life - budget:
			continue   # a Psionic Blast that kills us on the way is no win
		var surcharge := game.spell_surcharge(pid, inst.data)
		var keys: Array = game.mana_usage_keys(inst.data)
		# The board's own reach, with Channel's cost already spent out of
		# it, and then the life on top: one life is one colourless mana.
		var reach := _max_affordable_x(game, inst.data.cost,
			surcharge + opening, sources, inst.data.x_color, keys)
		var need: int = their_life - (intent.damage if aimed else 0)
		if need <= reach:
			return {}   # the board already pays for it; no life is owed
		var life := (need - reach) * maxi(inst.data.cost.x_count, 1)
		if life > budget:
			continue
		if swept and me.life - life - need < 1:
			continue   # a Hurricane that kills us with them is not a win
		return {"inst": inst, "x": need, "life": life,
			"targets": [TargetRef.player(opponent)] if aimed else []}
	return {}


## THE LIFE THIS SEAT MAY SELL FOR MANA: everything down to one point,
## less what their board would land on us if we spend the turn on this and
## the spell does not end the game — `life − 1 − their attack`, the cap
## P6 names. [method _damage_after_value_blocks] is the same reading
## [method _in_danger] makes of their clock, so a Fireball is not paid for
## with the life a Serra Angel is about to take.
func _life_for_mana_budget(game: MtgGame) -> int:
	var me := game.players[pid]
	var theirs: Array[CardInstance] = []
	for inst in game.players[game.opponent_of(pid)].battlefield:
		if inst.is_creature() and inst.cur_power > 0 \
				and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			theirs.append(inst)
	var mine: Array[CardInstance] = []
	for inst in me.battlefield:
		if inst.is_creature():
			mine.append(inst)
	var swing := 0
	if not theirs.is_empty():
		swing = _damage_after_value_blocks(game, theirs, mine)
	return maxi(me.life - 1 - swing, 0)


## THE LIFE PAID AND THE BURN FIRED, IN ONE ACTION (2026-09-10,
## [member AiProfile.reads_lethal_x]).
##
## [method MtgGame.pay_life_for_mana] had never been called by any seat in
## this AI's life. It is not a mana ability the planner can model — it is
## an action on the game, taken by the player, with no permanent to tap —
## so the pilot pays it here, itself, and casts in the same call: a seat
## that paid the life and then failed to cast would have burned its own
## life for nothing, and there is no rung at which that is a weakness
## rather than a malfunction.
##
## Everything is checked before a point is paid: the burn is in hand, its
## X reaches their life with the life added, the target is legal, and the
## cast itself is refused-checked the way every other cast in this file is.
func _lethal_life_mana(game: MtgGame) -> String:
	if not profile.reads_lethal_x or not game.players[pid].life_for_mana:
		return ""
	var found := _lethal_x_off_life(game, null, _mana_sources(game))
	if found.is_empty():
		return ""
	var inst: CardInstance = found["inst"]
	var x := int(found["x"])
	var life := int(found["life"])
	var targets: Array = found["targets"]
	if game.cast_refusal(pid, inst, targets, x, 0) != "":
		_refused[str(inst.id)] = true
		return ""
	if game.pay_life_for_mana(pid, life) != "":
		return ""
	if not _plan_and_pay(game, inst.data.cost_for(x),
			_generic_x(inst.data, x) + game.spell_surcharge(pid, inst.data),
			game.mana_usage_keys(inst.data)):
		return ""
	if game.cast_spell(pid, inst, targets, x) != "":
		_refused[str(inst.id)] = true
		return ""
	return "paid %d life and cast %s for %d" % [life, inst.data.card_name, x]


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
			# THE DRAW THAT WINS (2026-09-07): an Ancestral at a library
			# of three is lethal at their next draw step.
			if _decking_draw(game, inst, intent, intent.draws, 0) >= 0:
				targets = [TargetRef.player(opponent)]
				value = LETHAL_WORTH
			elif me.library.size() <= intent.draws \
					or intent.draws > _hand_room(game, Moment.SINK, inst):
				continue
			else:
				if intent.target_spec != null:
					targets = [TargetRef.player(pid)]
				value = 3.0 + _draw_need(me.hand.size())
		elif intent.answers_creatures():
			var victim := _best_victim(game, inst, intent, 0)
			if victim != null:
				var worth := Evaluator.permanent_value(victim, profile)
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
	var response := ""
	if not game.combat.attackers.is_empty():
		# THE BLOCK THAT WAS DECLARED IS PAID FOR BEFORE ANYTHING ELSE OF
		# OURS SPENDS THE MANA (2026-09-10) — see [method
		# _combat_planned_pumps]. Below Sorcerer there is no plan and this
		# returns "" without looking at the board, so the null is the null.
		var owed := _combat_planned_pumps(game)
		if owed != "":
			return owed
		var shield := _combat_regeneration(game)
		if shield != "":
			return shield
		var pumped := _combat_self_pumps(game)
		if pumped != "":
			return pumped
		if game.active_player != pid:
			response = _defensive_combat_response(game)
		else:
			response = _offensive_combat_response(game)
	# THE OPPONENT'S TURN, empty stack: the two moments the ability scorer
	# keys on (their upkeep, their end step) and the last call for a held
	# instant before our own untap.
	elif game.active_player != pid and game.stack.is_empty():
		match game.current_step():
			Mtg.Step.UPKEEP:
				# The tap policy's strongest reading (see "the tap policy"):
				# a tap laid down HERE holds through their turn and ours.
				response = _fire_tap_instant(game)
				if response == "":
					response = _try_activate(game, Moment.UPKEEP)
			Mtg.Step.END:
				response = _end_of_their_turn(game)
	if response != "":
		return response
	# LAST, after every responder above has had its say and declined: the
	# spell whose only legal moment is one of these (see "the window
	# caster" below). Last because each responder above HOLDS what it is
	# for — the counter for the threat, the Fog for the lethal swing, the
	# Bolt for the end step — and a general caster that ran first would
	# spend the mana they are waiting on.
	return _cast_in_window(game)


## The opponent's end step: everything still in hand or open that would
## be wasted by our untap step. Held instants first (a Bolt at their best
## creature, an Ancestral into a thin hand), then the mana sinks.
func _end_of_their_turn(game: MtgGame) -> String:
	var fired := _fire_held_instant(game)
	if fired != "":
		return fired
	return _try_activate(game, Moment.SINK)


# ==================================================== the window caster --
#
# THE CARDS WITH A MOMENT (2026-09-06). Twelve cards in this pool carry a
# "Cast this spell only ..." rider that keeps them out of their caster's
# own main phase altogether — Festival at an opponent's upkeep, Siren's
# Call before they declare attackers, Reset once they are past their
# upkeep, Teleport in a declare-attackers step, Blaze of Glory and
# Disharmony before blockers, False Orders in the declare-blockers step —
# and until this landed every one of them sat in hand for the whole duel:
# [method _try_cast_best] runs only in our own main phase, where the
# rider refuses them, and nothing outside it asked (docs/ROADMAP.md, the
# dead-card sweep's class 1).
#
# THE GATE IS THE CLASS ITSELF, and it is the safest one there is. A card
# is this arm's only if [method MtgGame.rider_admits_own_main] says its
# rider would refuse it in BOTH of our main phases — so Berserk and Rapid
# Fire, which the planner may cast in our first main, stay the planner's,
# and nothing an existing responder holds can be reached at all: a
# counterspell, a Fog, a Bolt, a Giant Growth has no rider. The second
# fence, [method _claimed_by_a_responder], says the same thing
# structurally, so a rider added to a removal spell some day still could
# not be fired from here out of turn.
#
# THE PRICE IS THE BOARD'S. Every card the gate admits is a card-local
# effect the intent reader cannot express, and what it does is done to
# THE COMBAT it is cast into rather than to a target; so
# [constant EffectIntent.WINDOW_SHAPES] names the shape and
# [method _window_worth] prices the shape from the board, with the
# primitives the attack and block planners already use (one blocker per
# attacker, [method _dies_to], [method _face_damage_value]). A shape it
# has no reading for is not cast — risk first. The bar is the card's own
# worth ([method Evaluator.card_value]): a Siren's Call that kills a 2/2
# is a card for a card, and a Festival that stops two damage at twenty
# life is a card for nothing.
#
# THE 1997 GAME had no policy for these beyond legality. The Manalink AI
# speculates every card whose EVENT_CAN_CAST handler admits the phase
# (`functions/ai.c`, ai_decision_phase: dispatch EVENT_SHOULD_AI_PLAY,
# keep the line with the better ai_opinion_of_gamestate), and the card
# functions answer only "may this be cast now" (unlimited.c,
# card_sirens_call: `current_turn != player && current_phase <
# PHASE_DECLARE_ATTACKERS`; the_dark.c, card_festival; legends.c,
# card_reset). Legality from the card, the decision from a whole-state
# opinion after trying it — which is this arm's shape too, with the
# engine's own [method MtgGame.cast_refusal] as the card's answer and a
# one-ply reading of the board in place of the speculation.

## One window cast, or "" — the last arm of [method _respond_action].
func _cast_in_window(game: MtgGame) -> String:
	if not profile.casts_timed_spells:
		return ""
	var me := game.players[pid]
	var sources: Array = []
	var reserve: Dictionary = {}
	var looked := false
	var best: CardInstance = null
	var best_targets: Array = []
	var best_value := 0.0
	for inst in me.hand:
		if not inst.is_type(Mtg.CardType.INSTANT) \
				or not inst.data.cast_condition.is_valid():
			continue
		if _refused.has(str(inst.id)) or _cast_gate(game, inst) != "":
			continue   # refused this step, locked, banned, or the rider says not now
		if game.rider_admits_own_main(pid, inst):
			continue   # the main-phase planner's card, whatever the rider allows tonight
		var intent := EffectIntent.read(inst.data.spell_effects, inst.data.card_name)
		if _claimed_by_a_responder(inst.data, intent):
			continue
		# Nothing below taps a land, so the sources and the reserve are the
		# same for every candidate — and most priority rounds never get
		# this far, so neither is built until one does.
		if not looked:
			sources = _mana_sources(game)
			reserve = _held_reserve(game)
			looked = true
		var surcharge := game.spell_surcharge(pid, inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge,
				game.mana_usage_keys(inst.data)).is_empty() \
				and not (_cost_is_free(inst.data.cost) and surcharge == 0):
			continue
		var worth := _window_worth(game, inst, intent, reserve)   # {} = no reading, or not tonight
		if worth.is_empty():
			continue
		var value: float = worth["value"]
		if value < Evaluator.card_value(inst.data):
			continue
		# Mana kept open for a held instant or a counter — the 1.5x rule of
		# [method _try_cast_best]: a window cast that would tap us out of
		# it must be worth half again as much. Except the one shape whose
		# whole worth is that reserve: a Reset is cast BECAUSE the held
		# card cannot be paid for tonight, and untapping the lands is what
		# pays for it.
		if not reserve.is_empty() and value < float(reserve["value"]) * 1.5 \
				and intent.window != EffectIntent.Shape.UNTAPS_LANDS \
				and _plan_taps_from(sources, _combined_cost(inst.data.cost, reserve["cost"]),
					surcharge).is_empty():
			continue
		var targets: Array = worth["targets"]
		if game.cast_refusal(pid, inst, targets) != "":
			continue
		if value > best_value:
			best = inst
			best_targets = targets
			best_value = value
	if best == null:
		return ""
	return _cast_response(game, best, best_targets, 0,
		"cast %s in its window" % best.data.card_name)


## Does an existing responder HOLD this instant for a moment of its own?
## The counter and the Fog ([method _is_reactive]), the shield, the
## ritual, the sweeper and the animation ([method _try_cast_best]'s), the
## removal, the draw and the face burn ([method _fire_held_instant],
## [method _find_instant_removal_for]), the tap ([method
## _fire_tap_instant]), the stat pump and the X pump ([method
## _find_pump_instant], [method _find_x_power_pump], [method
## _combat_self_pumps]). Structural, like the readers it names: the
## window caster fires nothing that any of them could.
func _claimed_by_a_responder(data: CardData, intent: EffectIntent) -> bool:
	if _is_reactive(data) or data.is_modal():
		return true
	if intent.counters or intent.fogs or intent.regenerates or intent.adds_mana:
		return true
	if intent.sweeper != null or intent.animates != null:
		return true
	if intent.answers_creatures() or intent.draws > 0 or intent.draws_use_x:
		return true
	if intent.taps or intent.untaps:
		return true
	if intent.pumps and (intent.pump_toughness > 0 or intent.pump_uses_x
			or intent.pump_self):
		return true
	return false


## What [param inst] is worth cast into THIS moment: `{targets, value}`,
## or `{}` when the arm has no reading for its shape or the board gives
## the shape nothing to do. [param reserve] is [method _held_reserve]'s
## answer, already built by the caller. The value is on [method
## Evaluator]'s stat scale, the way every other price in this file is.
func _window_worth(game: MtgGame, inst: CardInstance, intent: EffectIntent,
		reserve: Dictionary) -> Dictionary:
	var theirs := game.active_player != pid
	match intent.window:
		EffectIntent.Shape.STOPS_ATTACKS:
			return _worth_stopping_attacks(game) if theirs else {}
		EffectIntent.Shape.FORCES_ATTACKS:
			return _worth_forcing_attacks(game) if theirs else {}
		EffectIntent.Shape.UNTAPS_LANDS:
			return _worth_untapping_lands(game, reserve) if theirs else {}
		EffectIntent.Shape.STEALS_ATTACKER:
			return _worth_stealing_an_attacker(game) if theirs else {}
		EffectIntent.Shape.CONSCRIPTS_BLOCKER:
			return _worth_conscripting_a_blocker(game) if theirs else {}
		EffectIntent.Shape.PULLS_BLOCKER:
			return {} if theirs else _worth_pulling_a_blocker(game)
	# Teleport's shape is read from the effect rather than from a row: a
	# pump that grants UNBLOCKABLE and nothing else.
	if intent.pumps and intent.pump_keywords.has(Mtg.Keyword.UNBLOCKABLE) \
			and intent.pump_power == 0 and intent.pump_toughness == 0:
		return {} if theirs else _worth_unblockable(game, inst)
	return {}


## Untapped creatures [param of_pid] controls — the bodies that could
## attack or block this turn, before any legality question.
func _untapped_creatures(game: MtgGame, of_pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in game.players[of_pid].battlefield:
		if inst.is_creature() and not inst.tapped:
			out.append(inst)
	return out


## The declared attackers still on the battlefield.
func _declared_attackers(game: MtgGame) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for attacker_id in game.combat.attackers:
		var attacker := game.find_instance(attacker_id)
		if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
			out.append(attacker)
	return out


## STOPS_ATTACKS (Festival, their upkeep): a Fog cast before the swing,
## priced by the Fog's own rule — what their whole attack would land on
## us after our best one-blocker-per-attacker answer, worth casting at
## the same seven-or-lethal bar [method _defensive_combat_response] holds
## the Fog to, and the game itself when the swing is lethal.
func _worth_stopping_attacks(game: MtgGame) -> Dictionary:
	var me := game.players[pid]
	var opponent := game.opponent_of(pid)
	var could_attack: Array[CardInstance] = []
	for inst in _untapped_creatures(game, opponent):
		if CombatState.attack_illegality(game, inst, pid) == "":
			could_attack.append(inst)
	var through := _damage_through_blocks(game, could_attack,
		_untapped_creatures(game, pid), pid)
	if through < mini(me.life, 7):
		return {}
	var value: float = LETHAL_WORTH if through >= me.life \
		else _face_damage_value(game, through, pid)
	return {"targets": [], "value": value}


## FORCES_ATTACKS (Siren's Call, their turn before attackers): every
## non-Wall creature they held since the turn began attacks or dies at
## the end step. What we gain is what the forced swing costs them — the
## bodies that cannot attack at all (tapped, defender, a Serpent with no
## Island to swim to), and the ones our blockers kill and survive or
## trade up against, one blocker each — less what lands on us through
## the rest. Never when the rest is lethal: a card that forces the
## attack that kills us is not a card.
func _worth_forcing_attacks(game: MtgGame) -> Dictionary:
	var me := game.players[pid]
	var opponent := game.opponent_of(pid)
	var gain := 0.0
	var forced: Array[CardInstance] = []
	for inst in game.players[opponent].battlefield:
		if not inst.is_creature() or inst.has_subtype("wall") or inst.summoning_sick:
			continue
		if CombatState.attack_illegality(game, inst, pid) != "":
			gain += Evaluator.permanent_value(inst, profile)   # dies at the end step
		else:
			forced.append(inst)
	forced.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return Evaluator.permanent_value(a, profile) > Evaluator.permanent_value(b, profile))
	var free := _untapped_creatures(game, pid)
	var used: Dictionary = {}
	var through := 0
	for attacker in forced:
		var worth := Evaluator.permanent_value(attacker, profile)
		var best_gain := 0.0
		var best_blocker: CardInstance = null
		for blocker in free:
			if used.has(blocker.id) \
					or CombatState.block_illegality(game, blocker, attacker, pid) != "":
				continue
			if not _dies_to(game, attacker, blocker):
				continue
			var trade := worth
			if _dies_to(game, blocker, attacker):
				trade -= Evaluator.permanent_value(blocker, profile)
			if trade > best_gain:
				best_gain = trade
				best_blocker = blocker
		if best_blocker != null:
			used[best_blocker.id] = true
			gain += best_gain
		else:
			through += attacker.cur_power
	if through >= me.life:
		return {}
	var value := gain - _face_damage_value(game, through, pid)
	if value <= 0.0:
		return {}
	return {"targets": [], "value": value}


## UNTAPS_LANDS (Reset, their turn past their upkeep): every land we
## control untaps, the two that paid for it included, so the mana it
## returns is exactly the lands that were tapped — and mana is worth
## what it lets us cast ([method _mana_spell_enables]' rule for the
## ritual). Worth a card only when something in hand is WAITING for it:
## the held instant or the counter [method _held_reserve] names.
func _worth_untapping_lands(game: MtgGame, reserve: Dictionary) -> Dictionary:
	if reserve.is_empty():
		return {}
	var tapped := 0
	for inst in game.players[pid].battlefield:
		if inst.is_land() and inst.tapped:
			tapped += 1
	if tapped == 0:
		return {}
	return {"targets": [], "value": float(tapped)}


## STEALS_ATTACKER (Disharmony, their declare-attackers step): their
## attacker leaves combat untapped and is ours until the end of the turn
## — half a body's worth of it (it cannot attack for us, but it can
## block) plus the damage it was bringing, priced the way [method
## _defensive_combat_response] prices an attacker worth killing, and
## the game itself when it is the one that makes the swing lethal.
func _worth_stealing_an_attacker(game: MtgGame) -> Dictionary:
	var me := game.players[pid]
	var attackers := _declared_attackers(game)
	var blockers := _untapped_creatures(game, pid)
	var through := _damage_through_blocks(game, attackers, blockers, pid)
	var incoming := 0
	for attacker in attackers:
		incoming += attacker.cur_power
	var best: CardInstance = null
	var best_value := 0.0
	for attacker in attackers:
		var value := Evaluator.permanent_value(attacker, profile) * 0.5
		if through >= me.life:
			var rest: Array[CardInstance] = attackers.duplicate()
			rest.erase(attacker)
			var stolen_blockers: Array[CardInstance] = blockers.duplicate()
			stolen_blockers.append(attacker)
			if _damage_through_blocks(game, rest, stolen_blockers, pid) < me.life:
				value += LETHAL_WORTH
		else:
			value += attacker.cur_power * (1.0 if me.life - incoming <= 10 else 0.34)
		if value > best_value:
			best = attacker
			best_value = value
	if best == null:
		return {}
	return {"targets": [TargetRef.card(best)], "value": best_value}


## CONSCRIPTS_BLOCKER (Blaze of Glory, their declare-attackers step): one
## creature of ours blocks every attacker it can reach. Its worth is what
## it stops beyond what our ordinary one-blocker-per-attacker answer
## already stopped, plus the attackers its power kills (dealt biggest
## first, the way [method order_blockers] orders damage), less the body
## itself when the sum of their power gets through its toughness. Two
## attackers in reach at least — a single block needs no Blaze.
func _worth_conscripting_a_blocker(game: MtgGame) -> Dictionary:
	var attackers := _declared_attackers(game)
	var blockers := _untapped_creatures(game, pid)
	var through_now := _damage_through_blocks(game, attackers, blockers, pid)
	var best: CardInstance = null
	var best_value := 0.0
	for conscript in blockers:
		var reach: Array[CardInstance] = []
		var rest: Array[CardInstance] = []
		var taken := 0
		for attacker in attackers:
			if CombatState.block_illegality(game, conscript, attacker, pid) == "":
				reach.append(attacker)
				taken += attacker.cur_power
			else:
				rest.append(attacker)
		if reach.size() < 2:
			continue
		var others: Array[CardInstance] = blockers.duplicate()
		others.erase(conscript)
		var stopped := through_now - _damage_through_blocks(game, rest, others, pid)
		var value := _face_damage_value(game, stopped, pid)
		reach.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return Evaluator.permanent_value(a, profile) > Evaluator.permanent_value(b, profile))
		var power_left := conscript.cur_power
		for attacker in reach:
			var needed := attacker.cur_toughness - attacker.damage
			if needed <= 0 or needed > power_left or attacker.cur_indestructible \
					or _shieldable(game, attacker):
				continue
			power_left -= needed
			value += Evaluator.permanent_value(attacker, profile)
		if taken >= conscript.cur_toughness - conscript.damage \
				and not conscript.cur_indestructible and not _shieldable(game, conscript):
			value -= Evaluator.permanent_value(conscript, profile)
		if value > best_value:
			best = conscript
			best_value = value
	if best == null:
		return {}
	return {"targets": [TargetRef.card(best)], "value": best_value}


## PULLS_BLOCKER (False Orders, our declare-blockers step): the one
## creature blocking one of our attackers alone leaves the block, and
## the attacker connects. "You may have it block an attacking creature
## of your choice" is answered through the option funnel with the card's
## own hint — our smallest attacker that is not being blocked, the freed
## one included — so the price is the whole exchange: the freed
## attacker's damage and its life, less the attacker the blocker lands
## on instead. A pull whose hint would put the blocker straight back
## where it was is worth nothing and is not made.
func _worth_pulling_a_blocker(game: MtgGame) -> Dictionary:
	var opponent := game.opponent_of(pid)
	var them := game.players[opponent]
	var attackers := _declared_attackers(game)
	var unblocked: Array[CardInstance] = []
	var landing_total := 0
	for attacker in attackers:
		if not game.combat.was_blocked(game.combat.band_of(attacker.id)):
			unblocked.append(attacker)
			landing_total += attacker.cur_power
	var best: CardInstance = null
	var best_value := 0.0
	for attacker in attackers:
		var blockers := game.combat.blockers_of(attacker.id)
		if blockers.size() != 1:
			continue
		var blocker := game.find_instance(blockers[0])
		if blocker == null or blocker.zone != Mtg.Zone.BATTLEFIELD \
				or blocker.controller_id != opponent:
			continue
		# Where the hint sends it once the freed attacker is unblocked too.
		var landing: CardInstance = attacker
		for other in unblocked:
			if other.cur_power < landing.cur_power:
				landing = other
		if landing == attacker:
			continue
		var value := _face_damage_value(game, attacker.cur_power, opponent) \
			- _face_damage_value(game, landing.cur_power, opponent)
		if _dies_to(game, attacker, blocker):
			value += Evaluator.permanent_value(attacker, profile)
		if _dies_to(game, blocker, attacker):
			value -= Evaluator.permanent_value(blocker, profile)
		if _dies_to(game, landing, blocker):
			value -= Evaluator.permanent_value(landing, profile)
		if _dies_to(game, blocker, landing):
			value += Evaluator.permanent_value(blocker, profile)
		if landing_total + attacker.cur_power - landing.cur_power >= them.life \
				and landing_total < them.life:
			value += LETHAL_WORTH
		if value > best_value:
			best = blocker
			best_value = value
	if best == null:
		return {}
	return {"targets": [TargetRef.card(best)], "value": best_value}


## UNBLOCKABLE for the turn (Teleport, our declare-attackers step): the
## attacker of ours whose connecting matters most — the damage it adds
## to what our swing already gets through their best blocks, plus the
## worst a block could have done to it ([method _attack_risk]), and the
## game itself when it is the one that makes the swing lethal. An
## attacker nothing of theirs may block gains nothing from it.
func _worth_unblockable(game: MtgGame, _inst: CardInstance) -> Dictionary:
	var opponent := game.opponent_of(pid)
	var them := game.players[opponent]
	var attackers: Array[CardInstance] = []
	for attacker in _declared_attackers(game):
		if attacker.controller_id == pid:
			attackers.append(attacker)
	var blockers := _untapped_creatures(game, opponent)
	var through_now := _damage_through_blocks(game, attackers, blockers, opponent)
	var best: CardInstance = null
	var best_value := 0.0
	for attacker in attackers:
		var risk := _attack_risk(game, attacker, blockers, opponent)
		if risk < 0.0:
			continue   # nothing they have may block it anyway
		var rest: Array[CardInstance] = attackers.duplicate()
		rest.erase(attacker)
		var through_with := _damage_through_blocks(game, rest, blockers, opponent) \
			+ attacker.cur_power
		var value := _face_damage_value(game, through_with - through_now, opponent) + risk
		if through_with >= them.life and through_now < them.life:
			value += LETHAL_WORTH
		if value > best_value:
			best = attacker
			best_value = value
	if best == null:
		return {}
	return {"targets": [TargetRef.card(best)], "value": best_value}


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
		# Burn: a breath of the creature's own, or a Giant Growth that
		# lifts toughness past the damage.
		if intent.damage_at(top.x_value) > 0 and not intent.removes:
			# ITS OWN BREATH FIRST (2026-09-09) — the mana untaps and the
			# card does not come back, so the Shade that can grow out of
			# the Bolt is asked before the Giant Growth in hand is, and
			# no worth bar stands in front of it: there is no card to
			# lose, and a body whose own ability makes it bigger is one
			# the evaluator's snapshot under-reads by construction.
			var grown := _pump_out_of_reach(game, victim,
				intent.damage_at(top.x_value))
			if grown != "":
				return grown
			# ...and then the card, which is only worth a creature worth
			# a card.
			if Evaluator.permanent_value(victim, profile) >= 3.0:
				var pump := _find_pump_instant(game)
				if pump != null:
					var lift: int = pump.data.spell_effects[0].toughness
					if victim.cur_toughness - victim.damage + lift \
							> intent.damage_at(top.x_value):
						return _cast_response(game, pump, [TargetRef.card(victim)])
		# Unsummon our own Djinn out from under the Terror: the card is
		# kept, the tempo is lost — worth it for a creature worth two.
		if Evaluator.permanent_value(victim, profile) >= 5.0:
			var bounce := _find_bounce_for(game, victim)
			if bounce != null:
				return _cast_response(game, bounce, [TargetRef.card(victim)])
	return ""


## THE SHADE THAT DIED WITH FOUR SWAMPS UP (2026-09-09, [member
## AiProfile.pumps_to_attack]'s fourth reading). One activation of
## [param victim]'s own self-pump, when the burn spell on the stack would
## deal [param damage] to it and the breaths in reach would carry it past
## that; "" when there is no such breath, when the mana is spoken for, or
## when everything in reach still is not enough.
##
## [method _save_from_the_stack] knew exactly one answer to a burn spell
## aimed at one of ours — a pump INSTANT in hand ([method
## _find_pump_instant]) — so a Frozen Shade with four Swamps untapped, a
## 4/5 for the asking and three Swamps enough to walk out of a Lightning
## Bolt, died to the Bolt with the mana still on the table. Every part of
## the machinery this needs was built by the pump passes and none of it
## had ever been asked here.
##
## THE THREE THINGS THOSE PASSES LEARNED, and all three are kept:
##
##  * the mana may be SPOKEN FOR. [method _pump_reserve] books the second
##    main phase's best cast (on our own turn) and the held instant, so a
##    Counterspell's {U}{U} is never spent on a point of toughness. A
##    breath whose whole cost is counters takes none of it and is bounded
##    by the counters alone ([method _pumps_in_reach]).
##  * a per-turn CAP is counted, not the mana ([method
##    _activations_left]): a body whose breath is once a turn is one
##    point bigger, however many lands are open.
##  * an ability whose cost is a BODY stays invisible, and one whose cost
##    is a COUNTER is [member AiProfile.spends_counters]'s ruling — both
##    through [method _ability_available], which [method _self_pump_of]
##    asks.
##
## ONE ACTIVATION PER CALL, like [method _combat_self_pumps]: the pilot
## acts once, our own object goes on top of the stack, [method
## _respond_action] waits for it to resolve, and the burn spell is still
## there to be answered again. The pumps ALREADY on the stack are counted
## ([method _pending_pumps]) so a second is not bought for a job the first
## has done.
##
## WHAT IT DELIBERATELY DOES NOT REACH: a spell that kills by shrinking
## rather than by burning (a Dwarven Warriors' `-2/-2` shape has no
## [member EffectIntent.damage_at]), which is the same arm [method
## _find_pump_instant] has never answered either.
func _pump_out_of_reach(game: MtgGame, victim: CardInstance,
		damage: int) -> String:
	if not profile.pumps_to_attack:
		return ""
	var pump := _self_pump_of(game, victim, true)
	if pump.is_empty():
		return ""
	var index := int(pump["index"])
	var ability: ActivatedAbility = pump["ability"]
	var bonus: Vector2i = pump["bonus"]
	var live := maxi(victim.cur_toughness - victim.damage, 0)
	var pending := _pending_pumps(game, victim)
	if live + bonus.y * pending > damage:
		return ""   # what is already on the stack saves it
	var sources := _mana_sources(game)
	var reach := _pumps_in_reach(game, victim, ability, sources,
		_pump_reserve(game, sources), _activations_left(game, victim, index)) \
		+ pending
	if live + bonus.y * reach <= damage:
		return ""   # every breath it can reach still leaves it dead
	if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, victim)):
		return ""
	if game.activate_ability(pid, victim, index, []) != "":
		return ""
	return "pumps %s out of the burn" % victim.data.card_name


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


## THE PLAN IS DELIVERED BEFORE THE PILOT'S OWN NEXT PURCHASE (2026-09-10,
## [member AiProfile.pumps_to_attack]'s fifth reading, and the last thing
## the fourth pass left standing on [member _pump_plan]).
##
## WHAT WAS OPEN. The gang pass made the declaration and the recovery agree
## by construction — the mates are priced at what the plan still owes them
## ([method _owed_bonuses]), and the trampler's residue ([method
## _absorbed_by]) reads the same number — with one exposure named at the
## site and in `docs/ai-difficulty.md` §5: *mana spent between the
## declaration and the recovery by something else leaves a body short of
## the reach its plan promised, and the residue then over-reads by that
## much.* That is the dangerous direction: the panic line
## ([method _damage_after_value_blocks]) reads less through than will land,
## the chump rung stays shut, and the pilot declines to chump and dies.
##
## SOMETHING CAN. It is not an opponent's trick or a Time Walk-ish extra
## beat — it is the routine on the next line of [method _respond_action]
## itself, which ran [method _combat_regeneration] BEFORE [method
## _combat_self_pumps], and a pre-emptive regeneration shield is paid for
## out of the same open mana the declaration had already allotted to the
## breaths. Worse, the two were double-booked at the declaration itself:
## the block ladder asks [method _dies_to], which asks [method _shieldable]
## → [method _can_shield], which plans the shield's cost against the WHOLE
## open pool — the same pool [method _pump_shares] was dividing among the
## bodies.
##
## Reproduced 2026-09-10 on the gang pass's own board plus one Drudge
## Skeletons: six Swamps, a Carrion Ants and a Scathe Zombies in front of a
## Force of Nature (8/8 trample) and the Skeletons in front of a Hill
## Giant, us at 12. The plan allotted the swarm six breaths and the ladder
## declared the gang on the eight damage an 8/8 needs; the shield then took
## a Swamp for the 1/1, the swarm could reach only five, [method
## _band_kills] said no — correctly, of the mana that was left — and the
## recovery bought NOTHING. Both blockers died at 0/1 and 2/2, five
## trampled through, the trampler walked away and five Swamps were still
## untapped. Without the Skeletons on the board the same pilot buys all six
## and kills the 8/8 for nothing through.
##
## THE FIX IS THE ORDER, and it is the smallest one that closes it: the
## breaths the declaration was priced with are bought BEFORE the pilot's
## own next discretionary purchase. A block is a commitment already made —
## the bodies are standing where they are because of the plan — and the
## shield is a fresh option; when the pool cannot pay for both, the
## commitment wins and the declaration stops being a blunder in retrospect.
## The counterspell and the answer to removal on the stack still come
## first, and they always could: [method _pump_reserve] books
## [method _held_reserve] out of every share, so the plan never owned that
## mana to begin with.
##
## WHAT IS STILL NOT GUARANTEED, and it is now only THEIRS: an opponent's
## effect that taps one of our lands between the two moments (an Icy
## Manipulator, a Winter Orb turn) still leaves the body short. The residue
## over-reads by that much, and the recovery's mates keep the plan's
## number — [method _owed_bonuses] is deliberately not re-read, because
## over-crediting a mate errs on the harmless side: the breaths it buys are
## toughness as well as power, so against a trampler — the case this
## reading exists for — they still absorb the assignment they were bought
## for, and on the opponent's turn that mana has nothing else to buy. Ruled
## 2026-09-10, `docs/ai-difficulty.md` §5.
##
## Gated by [member AiProfile.pumps_to_attack], which is what the plan
## itself is gated by: below Sorcerer [method _remember_pump_plan] is never
## called, so this returns "" before it reads the board and the null is
## reproduced exactly.
func _combat_planned_pumps(game: MtgGame) -> String:
	if not profile.pumps_to_attack:
		return ""
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	return _self_pump_once(game, true)


## Self-pumps once blocks are known (Granite Gargoyle's {R}: +0/+1,
## firebreathing on a BLOCKED Shivan): one activation per call, for a
## creature of ours the declared combat would kill and the pumps in reach
## would save, or one the pumps would let kill its opposite number.
## Unblocked attackers get their firebreathing in
## _offensive_combat_response. Bounded: each call spends mana, and the
## pump already on the stack counts as if it had resolved.
##
## THE PLAN'S SHARE FIRST, THE LEFTOVERS AFTER (2026-09-09,
## [member AiProfile.pumps_to_attack]). The declaration probes divide ONE
## mana pool among several bodies ([method _pump_shares]) and then declare
## the attack — or the block — on the sizes that division bought. This
## routine priced every body against the WHOLE remaining pool and bought
## one activation at a time, so the first body down the battlefield could
## spend the mana the second was priced with, and the block that happened
## was not the block that was planned. Measured on 2026-09-09: a Carrion
## Ants and a Vampire Bats behind four Swamps, the probe splitting them
## two and two, the Ants blocking a 3/2 and the Bats a 2/2 flier — the
## Ants took three of the four Swamps to save ITSELF (a save the plan had
## never priced and the ladder had not blocked for), the Bats stayed a
## 0/1, killed nothing, and died for nothing.
##
## So the plan is delivered first: one pass in which every body may buy
## only what it was allotted ([member _pump_plan]), and — because mana a
## body declines is mana wasted, which is what this routine would have
## spent it on before — a second, uncapped pass that runs only when the
## first found nothing left to buy. With the knob off there is no plan
## and the second pass is the only one, which is the null exactly.
##
## AND THE QUESTION IT ASKS A BLOCKER IS THE GANG'S, NOT THE BODY'S OWN
## (2026-09-09, the fourth pass, and the last thing the third one left
## standing). "Does this breath win the trade?" used to mean "does this
## body kill the attacker ALONE?" — but the block ladder's third rung
## declares a GANG on the probe's sizes, where no single body has to. So
## the pilot declared the gang and then bought nothing for it. Measured
## on 2026-09-09, on the third pass's own board: a Carrion Ants and a
## Scathe Zombies in front of a Force of Nature, six Swamps open, the
## declaration priced the swarm at six breaths and the gang at exactly
## the eight damage an 8/8 needs — and the recovery bought NOTHING, both
## bodies died at 0/1 and 2/2, five trampled through and the Force of
## Nature walked away with all six Swamps still untapped. Asked as the
## gang's question ([method _band_kills], the ladder's own rung), the six
## breaths are bought, the 8/8 dies and nothing comes through.
##
## The mates are priced at what the PLAN still owes them, which is the
## size the block was declared on, so every body of the gang reaches the
## same verdict and they buy together. The one way they could disagree was
## the one [member _pump_plan] documented — mana spent between the
## declaration and the recovery by something else — and the spender turned
## out to be the pilot's own pre-emptive shield running one line above this
## one in [method _respond_action]. Closed 2026-09-10 by
## [method _combat_planned_pumps], which delivers the plan first; what an
## OPPONENT can still take away is ruled at that method and in
## `docs/ai-difficulty.md` §5.
func _combat_self_pumps(game: MtgGame) -> String:
	if game.current_step() != Mtg.Step.DECLARE_BLOCKERS:
		return ""
	if not profile.pumps_to_attack:
		return _self_pump_once(game, false)
	var planned := _self_pump_once(game, true)
	return planned if planned != "" else _self_pump_once(game, false)


## One activation of [method _combat_self_pumps]'s search. With
## [param honour_plan] the pass serves only the bodies the declaration
## allotted breaths to, and only up to the allotment; without it, every
## body against every point of open mana — the reading this had before
## [member AiProfile.pumps_to_attack] existed.
func _self_pump_once(game: MtgGame, honour_plan: bool) -> String:
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
			var bonus := Vector2i(intent.pump_power, intent.pump_toughness)
			if not intent.pump_self:
				# The card-local breath the reader cannot see (2026-09-09,
				# gated by [member AiProfile.pumps_to_attack]): Dragon
				# Whelp and Nalathni Dragon pump through an EffectBase of
				# their own, so this loop had never seen either of them.
				var breath := _card_local_breath(inst, index, intent)
				if breath.is_empty():
					continue
				bonus = Vector2i(int(breath["power"]), int(breath["toughness"]))
			if not _ability_available(game, inst, index):
				continue
			var pending := _pending_pumps(game, inst)
			# The allotment this body was declared on, spent down as the
			# breaths are bought. -1 is "no cap of its own" — the leftover
			# pass, and every rung below Sorcerer.
			var cap := _activations_left(game, inst, index)
			if honour_plan:
				var allotted := _pump_plan_for(game, inst)
				if allotted <= 0:
					continue
				cap = allotted if cap < 0 else mini(cap, allotted)
			# Activations in reach: planned pump by pump against the REAL
			# cost, colour included (as _pumps_are_lethal counts them) — a
			# Frozen Shade with one Swamp and three Forests open has one
			# {B} in reach, not four, and the count used to say four.
			var reach: int = _pumps_in_reach(game, inst, ability, sources, null,
				cap) + pending
			if reach <= pending:
				continue
			var pending_bonus := bonus * pending
			var reach_bonus := bonus * reach
			var worth := false
			if bonus.y > 0:
				var incoming := _incoming_combat_damage(game, inst, opposite)
				var dies := incoming > 0 \
					and inst.damage + incoming >= inst.cur_toughness + pending_bonus.y
				var saved := inst.damage + incoming < inst.cur_toughness + reach_bonus.y
				worth = dies and saved
			if not worth and bonus.x > 0:
				for other_id in opposite:
					var other := game.find_instance(other_id)
					if other == null or other.zone != Mtg.Zone.BATTLEFIELD:
						continue
					if not _dies_to(game, other, inst, Vector2i.ZERO, pending_bonus) \
							and _dies_to(game, other, inst, Vector2i.ZERO, reach_bonus):
						worth = true
						break
					# THE GANG'S QUESTION (2026-09-09) — see the note above.
					# Only in the plan's own pass: the gang is priced with
					# every mate at the size the DECLARATION allotted it,
					# and outside that pass there is no allotment to hold
					# the pool for them.
					if not honour_plan or not game.combat.blocks.has(inst.id):
						continue
					var band := _gang_on(game, other)
					if band.size() < 2:
						continue
					var owed := _owed_bonuses(game, band, inst)
					owed[inst.id] = pending_bonus
					if _band_kills(game, other, band, owed):
						continue   # the gang finishes it without this breath
					owed[inst.id] = reach_bonus
					if _band_kills(game, other, band, owed):
						worth = true
						break
			if not worth:
				continue
			if not _plan_and_pay(game, ability.cost, game.ability_surcharge(pid, inst)):
				continue
			if game.activate_ability(pid, inst, index, []) == "":
				if _pump_plan.has(inst.id):
					_pump_plan[inst.id] = maxi(int(_pump_plan[inst.id]) - 1, 0)
				return "pumps %s" % inst.data.card_name
	return ""


## How many times [param ability] of [param inst] the open mana in
## [param sources] can pay for, planning the combined cost each time so
## every coloured pip is counted. Capped at 20 — a Shade with twenty
## Swamps needs no finer answer.
##
## [param kept] is a cost the pumps must leave payable ([method
## _pump_reserve]: the second main phase's cast, the held instant), null
## for "every point of it is the pump's"; [param cap] is the ability's
## own remaining activations this turn ([method _activations_left]), -1
## for uncapped. Both default to the reading this had before
## [member AiProfile.pumps_to_attack] existed, which is the null.
func _pumps_in_reach(game: MtgGame, inst: CardInstance, ability: ActivatedAbility,
		sources: Array, kept: ManaCost = null, cap := -1) -> int:
	var surcharge := game.ability_surcharge(pid, inst)
	var limit := cap
	# THE COUNTERS ARE PART OF THE COST TOO (2026-09-09, [member
	# AiProfile.spends_counters]). A reach counted in mana alone would
	# read an Osai Vultures with two carrion counters as +20/+20, because
	# its breath asks for no mana at all — the counters on the permanent
	# now are the bound, exactly as the per-turn cap is, and the smaller
	# of the two wins. With the knob off no counter-cost ability ever
	# reaches this function: [method _ability_available] refuses it.
	if ability.counter_cost_kind != "":
		var budget: int = int(inst.counters.get(ability.counter_cost_kind, 0)) \
			/ maxi(ability.counter_cost_count, 1)
		limit = budget if limit < 0 else mini(limit, budget)
		if _cost_is_free(ability.cost) and surcharge == 0:
			# Counters and nothing else: there is no plan to make, and no
			# reserve to keep whole either — this breath cannot take a
			# single point of mana away from the Counterspell.
			return maxi(limit, 0)
	var cost: ManaCost = ability.cost if kept == null \
		else _combined_cost(ability.cost, kept)
	var pumps := 0
	while pumps < 20 and (limit < 0 or pumps < limit) \
			and not _plan_taps_from(sources, cost, surcharge * (pumps + 1)).is_empty():
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
	# THE GAZE (2026-09-10, [member AiProfile.reads_gaze]): a Cockatrice
	# destroys what it blocks or is blocked by WHATEVER the numbers say,
	# so the reading comes before the arithmetic and not after it. It is
	# still a DESTRUCTION, which is why the two clauses this predicate
	# already ends on — indestructible above, a shield in reach below —
	# are exactly the right ones and are simply shared.
	if profile.reads_gaze and _gaze_kills(game, hitter, victim):
		return not _shieldable(game, victim)
	# THEIR PUMPS ARE PUBLIC (2026-09-10, [member AiProfile.reads_pumps]):
	# a creature THEY control does not die at its printed toughness, it
	# dies at the toughness their open mana can pay for — the way [method
	# _shieldable] has read their regeneration since the block audit. It
	# goes in HERE rather than at the two dozen call sites because the
	# bonus is already the right channel, so every reader of this
	# predicate — the attack risk, the block ladder, the gang, the
	# crack-back matrices — asks one question and gets one answer.
	# [method _pump_reach] answers zero for a body of OURS ([member
	# AiProfile.pumps_to_attack] is that half) and for every creature with
	# no activated ability at all, which is nearly the whole pool; the
	# bonus the caller already passed is ADDED to, never replaced.
	#
	# WHAT IS NOT HERE IS THE OTHER DIRECTION, and it is the measurement
	# of 2026-09-10 that put it where it is rather than an argument. Their
	# pump also KILLS a body of ours, and read here that reading took a
	# whole block declaration away: the ladder's first rung stopped
	# claiming the kill, no later rung caught a printed 0/1, and three
	# Carrion Ants behind six Swamps walked past three Hill Giants for six
	# damage a turn. Mountain Artillery against Vampire Lord measured
	# -2.4 +-2.8 on that half alone and -0.2 on the other. So the power
	# half is asked where we are choosing to SEND a body into it — the two
	# halves of the attack declaration, [method _attack_risk] and [method
	# _cohort_value] — and not where we are choosing to put one in FRONT
	# of it: a blocker of ours that dies to their breath has spent their
	# mana, and mana spent killing a blocker is mana that did not reach
	# our face (this engine firebreathes an unblocked attacker at the
	# player, on both sides of the table — [method
	# _offensive_combat_response]). An attacker of ours that dies to it
	# has bought nothing at all.
	#
	# It sits AFTER the gaze on purpose: a Cockatrice kills what the
	# numbers say it does not, and a pump that changes the numbers changes
	# nothing about a gaze.
	if profile.reads_pumps:
		victim_bonus += _pump_reach(game, victim)
	var hit := _damage_from(hitter, victim, hitter_bonus, victim_bonus)
	if hit <= 0 or hit < victim.cur_toughness + victim_bonus.y - victim.damage:
		return false
	return not _shieldable(game, victim)


## Would [param gazer]'s own printed line destroy [param victim] for
## meeting it in combat (2026-09-10, [member AiProfile.reads_gaze])?
##
## [method _dies_to] is asked about a PAIR and is deliberately blind to
## which of the two is attacking — the crack-back matrix asks both ways
## about the same two bodies — and the gaze does not care either: its
## trigger fires on "blocks or becomes blocked". So the pair is put to
## the trigger's own condition in both roles ([constant
## Mtg.EventType.BLOCKED] carries `{attacker, blocker}`, which is what
## Cockatrice's "non-Wall" rider reads), and either answer is taken. A
## card that gazed in one direction only would be over-read by that, and
## this pool prints none; the alternative — demanding both — would
## under-read the two it does print the moment they attack.
##
## The empty-trigger bail on the first line is what keeps this off the
## cost of the matrix: nearly every creature in the pool has no triggered
## ability at all, and [method _dies_to] is asked n x m times per
## declaration.
func _gaze_kills(game: MtgGame, gazer: CardInstance, victim: CardInstance) -> bool:
	if gazer == null or victim == null or gazer == victim:
		return false
	if gazer.cur_triggered_abilities.is_empty():
		return false
	if not victim.is_creature() or victim.zone != Mtg.Zone.BATTLEFIELD:
		return false
	if not gazer.is_creature() or gazer.zone != Mtg.Zone.BATTLEFIELD:
		return false
	for trig in gazer.cur_triggered_abilities:
		if not EffectIntent.is_gaze(trig):
			continue
		if not trig.condition.is_valid():
			return true
		var as_blocker := GameEvent.new(Mtg.EventType.BLOCKED,
			{"attacker": victim, "blocker": gazer})
		if trig.condition.call(game, gazer, as_blocker):
			return true
		var as_attacker := GameEvent.new(Mtg.EventType.BLOCKED,
			{"attacker": gazer, "blocker": victim})
		if trig.condition.call(game, gazer, as_attacker):
			return true
	return false


## RAMPAGE (CR 702.23, 2026-09-10, [member AiProfile.reads_gaze]): the
## +N/+N [param attacker] takes for each of [param blockers] past the
## first. The engine applies it as the blockers are declared
## ([method MtgGame.declare_blockers]); every reading of ours that prices
## a GANG has to apply it a moment earlier, or the gang is declared on an
## attacker that is two sizes smaller than the one it meets.
##
## Zero for a gang of one, which is what makes this safe to put in every
## band predicate: a single block is the number it always was.
func _rampage_bonus(attacker: CardInstance, blockers: int) -> int:
	if not profile.reads_gaze or attacker == null or blockers <= 1:
		return 0
	return maxi(attacker.cur_rampage, 0) * (blockers - 1)


## Would attacking TAP [param inst] into an execution (2026-09-10,
## [member AiProfile.reads_gaze])? An untapped Royal Assassin with its
## mana open is why a non-vigilant body stays home, and the shape is
## Forge's `canBeKilledByRoyalAssassin` — an opposing Destroy ability,
## payable now, that can be aimed at the creature only once it is tapped.
##
## Three things have to hold and each rules a real case out. The body
## must TAP to attack (vigilance keeps a Serra Angel out of this
## entirely). The ability's line must name the tapped state and destroy a
## creature ([method EffectIntent.destroys_the_tapped]). And the spec
## must REFUSE the body as it stands: an ability that can already take it
## standing still is a threat the attack did not create — Tetsuo
## Umezawa's "target tapped or blocking creature" carries no filter at
## all in this engine, so it may aim at our body either way and is no
## reason to hold it back.
##
## Their mana is counted the way [method _shieldable] already counts it —
## untapped permanents with a mana ability, which is public to both seats
## — and their protection is read off the body the way [method
## _is_next_meal] reads a feeder's.
func _taps_into_execution(game: MtgGame, inst: CardInstance, defender: int) -> bool:
	if inst.tapped or inst.has_keyword(Mtg.Keyword.VIGILANCE):
		return false
	if not inst.is_creature() or inst.zone != Mtg.Zone.BATTLEFIELD:
		return false
	var open := 0
	for p in game.players[defender].battlefield:
		if not p.tapped and not p.cur_mana_abilities.is_empty() \
				and not (p.is_creature() and p.summoning_sick):
			open += 1
	var ref := TargetRef.card(inst)
	for source in game.players[defender].battlefield:
		if (inst.cur_protection & source.cur_colors) != 0:
			continue
		for index in source.cur_activated_abilities.size():
			var ability: ActivatedAbility = source.cur_activated_abilities[index]
			if not EffectIntent.destroys_the_tapped(ability):
				continue
			if ability.tap_cost and (source.tapped
					or (source.is_creature() and source.summoning_sick)):
				continue
			if ability.cost.mana_value() > open:
				continue
			var spec: TargetSpec = ability.effects[0].target_spec
			if spec.is_legal(game, ref, source):
				continue   # it can take the body standing still
			if not spec.filter.is_valid() or spec.filter.call(inst):
				continue   # something other than the tap is refusing
			return true
	return false


## WHAT THEIR BODY CAN GROW TO RIGHT NOW (2026-09-10, [member
## AiProfile.reads_pumps]; `docs/forge/combat.md` P2), as a +power/
## +toughness [Vector2i] — [constant Vector2i.ZERO] when it can grow no
## further.
##
## [method _shieldable] already counts their open sources against their
## cheapest regeneration shield, so a Drudge Skeletons with {B} up is a
## wall to every kill this file predicts. This is the same sentence about
## the other printed line their mana buys: the cheapest self-targeting
## [PumpEffect] ability with NO tap cost (a body that taps to pump cannot
## also block), times the activations their open sources pay for.
##
## THREE CAPS, and each one is a real card. The printed "activate only N
## times each turn" ([member ActivatedAbility.max_per_turn], read against
## the instance's own tally) is why a Fire Drake behind five Mountains is
## a 3/2 and a Vampire Bats a 4/2 — the same fact [method
## _activations_left] keeps for our own breath, read here off the ability
## because the reading is of THEIR permanent and asks nobody to pay for
## anything. Their OPEN SOURCES are the second, counted the way [method
## _shieldable] counts them (untapped permanents with a mana ability,
## public to both seats) and never from their hand, which is not. And the
## third is [method _pump_cap]: the smallest activation count past which
## no kill-or-survive answer on THIS board could still change.
##
## THE THIRD CAP IS WHY THIS IS A READING AND NOT A FANTASY. [forge]
## `ComputerUtilCombat.predictPowerBonusOfBlocker` (`ComputerUtilCombat.java:955-991`,
## the attacker twin at 1138-1322, commit `b09a3d3f`,
## docs/forge/combat.md P2) adds ONE activation per pump ability, gated by
## `ComputerUtilCost.canPayCost`, which under-reads a Frozen Shade behind
## four Swamps by three points; counting every activation the mana pays
## for is the honest read of public information. But the number that comes
## out of that has to stay a COMBAT number: a Shade behind ten Swamps
## facing one Grizzly Bears is read at +2/+2, because +3/+3 and +10/+10
## answer every question on that board exactly the same way, and a reading
## that prints 10 invites some later caller to believe it.
##
## OURS ANSWERS ZERO, deliberately. [member AiProfile.pumps_to_attack] is
## the half of this that sizes our OWN body by our OWN open mana, and it
## does it through the real planner with the second main phase and the
## held instant booked out of the pool. Two readers for one side would be
## two answers.
##
## The empty-ability bail on the second line is what keeps this off the
## cost of the crack-back matrix, exactly as [method _gaze_kills]'s is:
## [method _dies_to] is asked n x m times per declaration and nearly every
## creature in the pool has no activated ability at all.
func _pump_reach(game: MtgGame, inst: CardInstance) -> Vector2i:
	# ONE GATE, ONE STORY. Every reader of this reaches it through here,
	# so the null cannot be moved by a caller that forgot its own check —
	# and [method _dies_to] keeps one anyway, because it asks this once
	# per pair and the crack-back matrix asks it n x m times.
	if not profile.reads_pumps:
		return Vector2i.ZERO
	if inst == null or inst.cur_activated_abilities.is_empty():
		return Vector2i.ZERO
	if inst.controller_id == pid:
		return Vector2i.ZERO   # ours is [member AiProfile.pumps_to_attack]'s question
	if not inst.is_creature() or inst.zone != Mtg.Zone.BATTLEFIELD:
		return Vector2i.ZERO
	var who := inst.controller_id
	var best := _cheapest_pump_of(game, inst)
	if best.is_empty():
		return Vector2i.ZERO
	var bonus: Vector2i = best["bonus"]
	var index := int(best["index"])
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var open := 0
	for p in game.players[who].battlefield:
		if not p.tapped and not p.cur_mana_abilities.is_empty() \
				and not (p.is_creature() and p.summoning_sick):
			open += 1
	# ONE POOL, SHARED (2026-09-10). Their mana is spent ONCE, and until
	# this line every body of theirs was read as if the whole of it were
	# waiting for that body alone: three Carrion Ants attacking behind six
	# Swamps were three 6/7s to the block ladder, which declared no block
	# at all and took six, where the truth is six mana between three
	# bodies. It is [member AiProfile.pumps_to_attack]'s own fifth-pass
	# sentence read from the other side of the table — the split of the
	# one pool is spent as it was allotted — and the bodies it is split
	# among are the ones THIS combat can ask it of ([method
	# _pump_claimants]).
	var times := open / (int(best["price"]) * _pump_claimants(game, inst))
	if ability.max_per_turn > 0:
		times = mini(times,
			maxi(ability.max_per_turn - int(inst.ability_uses.get(index, 0)), 0))
	times = mini(times, _pump_cap(game, inst, bonus))
	return bonus * maxi(times, 0)


## The cheapest self-pump of [param inst] that its controller could
## actually activate right now, as `{index, bonus, price}` — `{}` when it
## has none (2026-09-10, [member AiProfile.reads_pumps]).
##
## The gates are the ones the pilot's own pump paths keep, read for a seat
## that is not ours and so without asking the engine to pay for anything:
## no tap cost (a body that taps to pump cannot also block), the printed
## timing riders ([method _animation_timing_open]), and a cost that is
## MANA. An Atog eats an artifact and a Fallen Angel a creature; what
## those cost is a board, not a Swamp, and nothing here prices a board —
## the same answer [method _ability_available] gives them on our own side
## of the table until a knob rules otherwise.
func _cheapest_pump_of(game: MtgGame, inst: CardInstance) -> Dictionary:
	var who := inst.controller_id
	var best: Dictionary = {}
	for index in inst.cur_activated_abilities.size():
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if ability.tap_cost or ability.cost == null:
			continue
		if not _animation_timing_open(game, ability, who):
			continue   # the printed timing riders, read for THEIR seat
		if ability.only_owner_may_activate and inst.owner_id != who:
			continue   # a stolen Personal Incarnation answers to its owner
		if ability.cost.has_x or ability.sacrifice_cost \
				or ability.sacrifice_filter.is_valid() or ability.exile_cost \
				or ability.exile_filter.is_valid() or ability.discard_cost > 0 \
				or ability.random_discard_cost > 0 or ability.life_cost > 0 \
				or ability.counter_cost_kind != "":
			continue
		var intent := EffectIntent.read(ability.effects, inst.data.card_name)
		if not intent.pump_self or intent.unknown:
			continue
		var bonus := Vector2i(intent.pump_power, intent.pump_toughness)
		if bonus.x < 0 or bonus.y < 0 or (bonus.x <= 0 and bonus.y <= 0):
			continue   # a Wall of Wonder's +4/-4 is a different card
		var price := ability.cost.mana_value()
		if price <= 0:
			continue   # a free pump has no mana to read; this pool prints none
		if best.is_empty() or price < int(best["price"]):
			best = {"price": price, "bonus": bonus, "index": index}
	return best


## HOW MANY BODIES OF THEIRS ARE ASKING THE SAME POOL FOR THE SAME COMBAT
## (2026-09-10, [member AiProfile.reads_pumps]) — never fewer than one,
## and [param inst] is always one of them.
##
## The set is the combat's own. When THEY are attacking, it is their
## attacking pumpers: those are the bodies a block can put the question
## to, and the ones left at home want nothing. When we are the seat
## declaring, it is their UNTAPPED pumpers: those are the bodies that
## could block, and a tapped one is no blocker at all (CR 509.1a).
##
## THE DIRECTION OF THE ERROR IS CHOSEN. Splitting the pool evenly
## under-reads the case where only one of their several bodies ends up in
## the combat and takes the whole of it, and that under-read pushes the
## pilot back toward the null it is measured against; reading the pool
## whole for each of them over-read a whole block declaration away, which
## is the wall this knob's own risk note is about (`docs/forge/combat.md`
## P2). Measured both ways on 2026-09-10 and the split is what the Lab
## kept.
func _pump_claimants(game: MtgGame, inst: CardInstance) -> int:
	var who := inst.controller_id
	var they_attack := game.active_player == who and not game.combat.attackers.is_empty()
	var claimants := 0
	for other in game.players[who].battlefield:
		if not other.is_creature() or other.cur_activated_abilities.is_empty():
			continue
		if other != inst:
			if they_attack:
				if not game.combat.attackers.has(other.id):
					continue
			elif other.tapped:
				continue
			if _cheapest_pump_of(game, other).is_empty():
				continue
		claimants += 1
	return maxi(claimants, 1)


## THE CAP ON [method _pump_reach]: the smallest number of activations
## past which NO kill-or-survive answer on this board could still change
## (2026-09-10, [member AiProfile.reads_pumps]).
##
## Two questions and no third. How much power would [param inst] need to
## finish every body we have (the sum of their toughness — an attacker
## divides its power among its blockers, so the sum is the ceiling), and
## how much toughness would it need to live through every body we have
## (the sum of their power, and one more). Whichever wants more
## activations is the cap; a board with no creature of ours on it wants
## none, and the reach is zero.
##
## It is a CEILING and not a target: the predicate it feeds is binary, so
## the answers at the cap and above it are identical by construction —
## which is exactly why the number may be capped without changing a
## single decision, and why it must be, so that no reading downstream ever
## inherits a +10/+10 that means +2/+2.
func _pump_cap(game: MtgGame, inst: CardInstance, bonus: Vector2i) -> int:
	var our_power := 0
	var our_toughness := 0
	for body in game.players[pid].battlefield:
		if not body.is_creature():
			continue
		our_power += maxi(body.cur_power, 0)
		our_toughness += maxi(body.cur_toughness - body.damage, 0)
	var need := 0
	if bonus.x > 0:
		var short_power := maxi(our_toughness - maxi(inst.cur_power, 0), 0)
		need = maxi(need, ceili(float(short_power) / float(bonus.x)))
	if bonus.y > 0:
		var alive := maxi(inst.cur_toughness - inst.damage, 0)
		var short_toughness := maxi(our_power + 1 - alive, 0)
		need = maxi(need, ceili(float(short_toughness) / float(bonus.y)))
	return need


## THE SAME QUESTION ASKED OF A WHOLE BAND (2026-09-09,
## [member AiProfile.pumps_to_attack]): would [param band] TOGETHER finish
## [param victim], with [param extra] naming a what-if bonus for any of
## the bodies in it (`{instance id: Vector2i}`)?
##
## It is the "gang up" rung of [method _best_block_for] written down as a
## predicate, for the two readings that had been asking each body whether
## it kills the attacker ALONE — the recovery ([method _self_pump_once])
## and the trampler's residue ([method _absorbed_by]) — so that all three
## ask one question. For a band of ONE it is [method _dies_to] exactly,
## which is what both readings fall back to when there is no gang.
func _band_kills(game: MtgGame, victim: CardInstance,
		band: Array[CardInstance], extra: Dictionary = {}) -> bool:
	if victim.cur_indestructible or _shieldable(game, victim):
		return false
	# THEIR PUMPS ARE PUBLIC (2026-09-10, [member AiProfile.reads_pumps]):
	# a gang is a kill test, and this one does not go through
	# [method _dies_to], so the reading is put to it here in the same
	# words. Zero for a body of ours and for a creature with no ability.
	var grows := _pump_reach(game, victim)
	var total := 0
	var bodies := 0
	for body in band:
		if body == null or body.zone != Mtg.Zone.BATTLEFIELD:
			continue
		bodies += 1
		var bonus: Vector2i = extra.get(body.id, Vector2i.ZERO)
		total += _damage_from(body, victim, bonus, grows)
	# RAMPAGE (CR 702.23, 2026-09-10, [member AiProfile.reads_gaze]): the
	# body a gang meets is not the body it was declared against — a Craw
	# Giant blocked by two is +2/+2 before any damage is assigned. Zero
	# for a gang of one, so this predicate still IS [method _dies_to]
	# there, which is what `tests/ai/test_ai_gang_blocks_2026_09_05.gd`
	# pins.
	return total > 0 and total >= victim.cur_toughness - victim.damage \
		+ _rampage_bonus(victim, bodies) + grows.y


## Every body of ours blocking [param victim], as the band [method
## _band_kills] asks about.
func _gang_on(game: MtgGame, victim: CardInstance) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for blocker_id in game.combat.blockers_of(victim.id):
		var body := game.find_instance(blocker_id)
		if body != null and body.zone == Mtg.Zone.BATTLEFIELD:
			out.append(body)
	return out


## The breaths the plan still owes every body of [param band] except
## [param inst], as `{instance id: Vector2i}` — the size the block was
## DECLARED on, less whatever the recovery has bought so far. A body with
## no plan, or one that has had everything it was allotted, contributes
## the printed damage it already deals and no entry here.
func _owed_bonuses(game: MtgGame, band: Array[CardInstance],
		inst: CardInstance) -> Dictionary:
	var out: Dictionary = {}
	for body in band:
		if body == inst:
			continue
		var owed := _pump_plan_for(game, body) + _pending_pumps(game, body)
		if owed <= 0:
			continue
		var pump := _self_pump_of(game, body)
		if pump.is_empty():
			continue
		out[body.id] = Vector2i(pump["bonus"]) * owed
	return out


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


## THE PRICE A SOFT COUNTER LETS ITS VICTIM WALK THROUGH FOR: the `{N}`
## of *"Counter target spell unless its controller pays {N}"*, read off
## the card's own oracle line exactly as [method _is_counterspell] reads
## the first one, and for the same reason — the effect class cannot say
## it (CR 701.5a: the spell is countered only if the price goes unpaid).
##
## [constant UNLESS_NONE] for a HARD counter, one that prints no such
## line; [constant UNLESS_X] when the price is the {X} we ourselves name,
## which is the one price this seat controls. A line this reader cannot
## parse is read as no price at all, which prices the card as the hard
## counter it is not — the mild direction, and the pool holds exactly two
## of the shape (Power Sink's {X}, Force Spike's {1}) and both parse.
const UNLESS_NONE := -1
const UNLESS_X := -2


static func _unless_price(data: CardData) -> int:
	var at := data.oracle_text.find("unless its controller pays {")
	if at < 0:
		return UNLESS_NONE
	var opened := data.oracle_text.find("{", at)
	var closed := data.oracle_text.find("}", opened)
	if closed < 0:
		return UNLESS_NONE
	var body := data.oracle_text.substr(opened + 1, closed - opened - 1)
	if body == "X":
		return UNLESS_X
	return int(body) if body.is_valid_int() else UNLESS_NONE


## The mana [param who] can still reach: what is floating in their pool
## plus every untapped permanent of theirs the planner would tap — the
## same list this seat builds for itself ([method _mana_sources]), asked
## of the other seat. All of it is public: an untapped permanent and the
## ability printed on it are on the table, and nothing here reads a hand,
## a library or a decision.
##
## It is the PLANNER's list and therefore slightly short: a source whose
## ability carries a rider the planner does not model (a life cost, a
## sacrifice, a counter to remove) is left out of it, so a seat holding
## one can pay a little more than this says. Short is the direction that
## costs a counter rather than a game — the price we name is one they
## might just cover — and the alternative is a second mana model beside
## the one this whole file already shares.
func _their_open_mana(game: MtgGame, who: int) -> int:
	var total := 0
	for source in ManaPlanner.sources(game, who):
		total += int(source[3])
	return total


## The spec [method _try_counter] would fire [param inst] at this spell
## with, or null when the card is no answer to it. The three shapes that
## loop knows, in its own order: the shared [CounterEffect], a card-local
## counterspell ([method _is_counterspell]) and a modal card one of whose
## modes is a counter.
func _counter_spec(game: MtgGame, inst: CardInstance,
		top_ref: TargetRef) -> TargetSpec:
	for effect in inst.data.spell_effects:
		if effect is CounterEffect \
				and effect.target_spec.is_legal(game, top_ref, inst):
			return effect.target_spec
	if _is_counterspell(inst.data):
		for effect in inst.data.spell_effects:
			if effect.target_spec != null \
					and effect.target_spec.kind == TargetSpec.Kind.SPELL:
				return effect.target_spec
	for mode in inst.data.modes:
		var m_effects: Array = mode["effects"]
		if m_effects.size() == 1 and m_effects[0] is CounterEffect \
				and m_effects[0].target_spec.is_legal(game, top_ref, inst):
			return m_effects[0].target_spec
	return null


## THE COUNTERS IN HAND, THE BEST ANSWER TO THIS SPELL FIRST (2026-09-10,
## [member AiProfile.ranks_counters]).
##
## [method _try_counter] walked the hand in the order the cards sit in it
## and cast the first one that could legally answer, so WHICH counter
## answered a Serra Angel was the shuffle's business. A Mana Drain and a
## Power Sink in the same hand meant the Drain went on whatever came
## first — and against a tapped-out caster the Sink is the card that
## stops that spell for two mana, while the Drain is the one that stops
## anything.
##
## Five keys, and every one is read off the board and the cards' own
## lines:
##
##  1. CAN WE PAY FOR IT. A counter the mana on the table does not cover
##     is not an answer, and it sorts last so the loop reaches one that
##     is. This is a fix as much as an ordering: the loop RETURNS what
##     [method _cast_response] gives it, so a legal counter it could not
##     afford used to end the search with a pass.
##  2. DOES IT STOP THE SPELL. A soft counter is a counter only while the
##     price it prints is out of the caster's reach: a Force Spike into
##     an untapped land, or a Power Sink whose unpayable X we cannot
##     afford, is a card thrown away. This is the "hard before
##     unless-cost" half of the rule, and it is also why a Sink is not
##     cast at all when they can pay it and something else in hand
##     answers — that card is simply ahead of it.
##  3. WHAT IT COSTS US NOW, the X included: cheap before dear.
##  4. THE NARROW CARD BEFORE THE WIDE ONE — a spec carrying a filter of
##     its own (Remove Soul's creature spells, an Elemental Blast's
##     colour) is spent before the one that answers anything.
##  5. THE CARD WE WOULD RATHER KEEP, kept. A Power Sink for one and a
##     Mana Drain both cost two mana against a tapped-out caster; the
##     Sink is the lesser card, so the Sink is what a Grizzly Bears gets
##     and the Drain is still in hand when the Serra Angel comes.
##
## The hand's own index is the last key, so the order is total and a
## seeded duel replays it ([method Array.sort_custom] is not stable).
## With the knob off the hand is returned untouched, which is the null.
##
## [forge] the shape is `ComputerUtil.counterSpellRestriction`
## (forge-ai/src/main/java/forge/ai/ComputerUtil.java:160-214), chosen by
## `AiController.chooseCounterSpell` (:691-717), commit b09a3d3f: its
## unless-cost arm scores a counter the caster cannot pay through far
## above one they can, and its `validTgts` arm puts the narrow card
## first. The scores themselves are not ported — there they are a sum of
## magic numbers, here they are a sort.
func _counter_order(game: MtgGame, top: StackItem, top_ref: TargetRef) -> Array:
	var hand: Array = game.players[pid].hand
	if not profile.ranks_counters:
		return hand
	var open_mana := _their_open_mana(game, top.controller)
	var sources := _mana_sources(game)
	var rows: Array = []
	for i in hand.size():
		rows.append(_counter_key(game, hand[i], top_ref, open_mana, sources, i))
	rows.sort_custom(func(a: Array, b: Array) -> bool:
		for k in 6:
			if a[k] != b[k]:
				return a[k] < b[k]
		return false)
	var out: Array = []
	for row in rows:
		out.append(row[6])
	return out


## One row of [method _counter_order]'s sort: the five readings, the
## hand's index and the card. A card that answers nothing here sorts
## behind every card that does — the loop skips it either way, so its
## place among its own kind does not matter.
func _counter_key(game: MtgGame, inst: CardInstance, top_ref: TargetRef,
		open_mana: int, sources: Array, index: int) -> Array:
	var no_answer := [1, 1, 99, 1, 99.0, index, inst]
	var spec := _counter_spec(game, inst, top_ref)
	if spec == null:
		return no_answer
	var data := inst.data
	var surcharge := game.spell_surcharge(pid, data)
	var keys: Array = game.mana_usage_keys(data)
	var unless := _unless_price(data)
	var unpayable := 0   # 1 = the mana on the table does not cover it
	var walks := 0       # 1 = the caster can simply pay past it
	var x := 0
	if data.cost.has_x:
		var max_x := _max_affordable_x(game, data.cost, surcharge, sources,
			data.x_color, keys)
		if spec.source_filter.is_valid():
			# Spell Blast: the X is the mana value on the stack, and the
			# spec is the only thing that knows which.
			x = _x_that_makes_legal(game, inst, spec, top_ref, max_x)
			if x < 0:
				return no_answer
		elif unless == UNLESS_X:
			x = open_mana + 1
			if x > max_x:
				x = max_x
				walks = 1
		else:
			x = max_x
		if max_x <= 0:
			unpayable = 1
	elif _plan_taps_from(sources, data.cost, surcharge, keys).is_empty() \
			and not (_cost_is_free(data.cost) and surcharge == 0):
		unpayable = 1
	if unless >= 0 and open_mana >= unless:
		walks = 1
	return [unpayable, walks, data.cost.mana_value() + surcharge + maxi(x, 0),
		0 if spec.filter.is_valid() else 1, Evaluator.card_value(data),
		index, inst]


## THE SHAPE OF THE SPELL, not its price (2026-09-10,
## [member AiProfile.counters_by_shape]; wave 2, `docs/forge/casting.md`
## P2). [constant SHAPE_ALWAYS], [constant SHAPE_NEVER] or
## [constant SHAPE_BAR] — "ask [member AiProfile.counter_threshold], as
## this seat always did".
##
## WHY A PRINTED WORTH IS THE WRONG INSTRUMENT. [method
## Evaluator.card_value] reads a card's cost and its printed numbers, and
## the spells that decide a game have neither: probed at HEAD, Wrath of
## God prices at 5.00, Fireball at 2.50, Time Walk at 3.00 and Wheel of
## Fortune at 4.00, so a Sorcerer (bar 5.5) watched a Wrath take four
## Serra Angels off its own table and every rung let a Fireball for eight
## resolve at eight life. Meanwhile a Serra Angel at 10.00 ate the
## Counterspell with a Swords to Plowshares in hand and a Plains untapped.
##
## THE FIVE ALWAYS CLAUSES, each a shape and none a name:
##
##  1. A SWEEPER that takes more off our board than off theirs by a 2/2's
##     worth ([constant SWEEP_BAR] — the bar our own sweeps have to clear
##     to be worth casting, read from the other side of the table).
##  2. DAMAGE AT OUR FACE that is lethal, or that puts us on the panic
##     line — the same reading [method _packet_worth] makes of a waiting
##     packet one step later, so the counter and the Circle answer the
##     same Fireball with the same number. The X is the one on the STACK,
##     which is public. A sweeper that hits PLAYERS is read here as well
##     as at clause 1: against a control deck with two creatures on the
##     table, an Earthquake for eight is not a board sweep at all.
##  3. A DRAW AT OUR LIBRARY that empties it: they win at our next draw
##     step (CR 704.5b) and nothing we draw on the way changes it — the
##     mirror of [method _decking_draw], which reads it in our favour.
##  4. AN EXTRA TURN ([member EffectIntent.extra_turns]). An untap, a
##     draw, a land drop and a whole attack, and no bar prices it.
##  5. A WHEEL ([member EffectIntent.wheels]) while OUR hand is the
##     fuller. The swing is `their hand − our hand` (P5's arithmetic: the
##     refill count cancels), measured against the hand the counter leaves
##     us. A REROLL that gives each player back what it took nets nobody
##     anything and is not a clause.
##
## THE STEAL IS NOT A CLAUSE, and P2's list names it. It DID NOT REPRODUCE:
## [method _try_counter] has raised the threat to the worth of any card of
## OURS the top spell targets since long before this knob — the line
## written for a counter-war — and a Control Magic names our Serra Angel,
## so the Angel's 10.00 is already the number the bar is asked. A second
## copy of that reading would fire only where the first refuses, which is a
## steal on a creature the bar itself would not spend a counter for.
## `tests/ai/test_ai_counters_by_shape_2026_09_10.gd` pins the board on
## both arms so nobody builds it twice.
##
## THE COUNTER-WAR is not a clause either, and for the same reason: that
## reading predates this knob and stands unchanged.
##
## NEVER is asked last and only when no ALWAYS clause fired, so a lethal
## Fireball is never let through because we hold an answer to it.
const SHAPE_NEVER := -1
const SHAPE_BAR := 0
const SHAPE_ALWAYS := 1


func _counter_shape(game: MtgGame, top: StackItem) -> int:
	var me := game.players[pid]
	var them := game.players[top.controller]
	var intent := _intent_of(top.card)
	# 1. THE SWEEPER.
	if intent.sweeper != null and _their_sweep_loss(game, intent.sweeper,
			top.x_value) >= SWEEP_BAR:
		return SHAPE_ALWAYS
	# 2. THE BURN AT OUR FACE.
	var at_us := _damage_at_us(game, top, intent)
	if at_us > 0:
		if at_us >= me.life:
			return SHAPE_ALWAYS
		if float(me.life - at_us) \
				<= profile.chump_threshold * (1.5 - profile.aggression):
			return SHAPE_ALWAYS
	# 3. THE DRAW THAT DECKS US.
	if _draw_at_us(game, top, intent) >= me.library.size() \
			and me.library.size() > 0:
		return SHAPE_ALWAYS
	# 4. THE EXTRA TURN.
	if intent.extra_turns > 0:
		return SHAPE_ALWAYS
	# 5. THE WHEEL. `me.hand.size() - 1` is the hand the counter leaves us,
	# which is the hand the refill would have to fill.
	if intent.wheels > 0 and me.hand.size() - 1 > them.hand.size():
		return SHAPE_ALWAYS
	if _answered_later(game, top, intent):
		return SHAPE_NEVER
	return SHAPE_BAR


## What THEIR sweeper would take off our board net of theirs, on the
## evaluator's own board scale — [method _sweep_value] read from the other
## side of the table, and deliberately not that function: its relief, its
## land reading and its life terms are all about a sweep WE cast, and the
## question here is only whose board it clears.
func _their_sweep_loss(game: MtgGame, effect: EffectBase, x_value: int) -> float:
	var n := 0
	if effect is DamageAllEffect:
		n = x_value if effect.use_x else effect.amount
		if n <= 0:
			return 0.0
	elif not (effect is DestroyAllEffect):
		return 0.0
	var loss := 0.0
	for inst in game.all_battlefield():
		if not _sweep_kills(effect, inst, n):
			continue
		var worth := Evaluator.permanent_value(inst, profile)
		loss += worth if inst.controller_id == pid else -worth
	return loss * Evaluator.W_BOARD


## The damage [param top] would deal to THIS SEAT'S FACE at the X it was
## cast for, or 0.
##
## A DIVIDED spell (Fireball at several targets) splits its damage, and
## the split is the caster's; the honest floor is what is left after every
## other target has taken the one point it must — CR 601.2d, "each target
## must be assigned at least one".
func _damage_at_us(game: MtgGame, top: StackItem, intent: EffectIntent) -> int:
	# A SWEEPER THAT HITS PLAYERS (Earthquake, Hurricane) lands the same
	# points on our face with no target list to read them off. The board
	# half of it is clause 1's; this is the face half, and against a
	# control deck with two creatures the face half is the whole spell.
	if intent.sweeper is DamageAllEffect and intent.sweeper.hit_players:
		var n: int = top.x_value if intent.sweeper.use_x else intent.sweeper.amount
		return maxi(n, 0)
	var total := intent.damage_at(top.x_value)
	if total <= 0:
		return 0
	var at_us := false
	var others := 0
	for t in top.targets:
		if t == null:
			continue
		if t.is_player and t.player_id == pid:
			at_us = true
		else:
			others += 1
	if not at_us:
		return 0
	if intent.damage_divided and others > 0:
		return maxi(total - others, 0)
	return total


## The cards [param top] would draw off OUR library at the X it was cast
## for, or 0 — the mirror of [method _decking_draw], which asks the same
## question in our favour.
func _draw_at_us(game: MtgGame, top: StackItem, intent: EffectIntent) -> int:
	if not (intent.draws > 0 or intent.draws_use_x):
		return 0
	for t in top.targets:
		if t != null and t.is_player and t.player_id == pid:
			return intent.draws + (top.x_value if intent.draws_use_x else 0)
	return 0


## WEISSMAN'S RULE (2026-09-10): is there a card in hand that answers
## [param top] AFTER it resolves, for less than the counter costs?
##
## *"A capability of a different kind"* (`docs/ROADMAP.md`): the counter is
## the answer to what nothing else in the hand can touch, so a creature we
## hold a Terror for is let through and the Counterspell is still there
## when the Wrath comes. It cannot apply to a sorcery or an instant —
## there is nothing left to answer — nor while our own hand is down to the
## counter itself, which is the moment the discipline becomes a loss.
##
## THE RISK THE NOTE NAMED, and it is the whole of the second half: *"the
## rule must check [method _plan_taps] for the answer at the opponent's
## next end step, not just its presence"*. A Hypnotic Specter let through
## because a Terror sits in hand is a card in hand and a Specter on the
## table when the black mana is not there, so the answer is planned
## against this seat's own sources ([method _plan_taps_from]) and refused
## when the plan comes back empty. The list is the one standing NOW rather
## than a modelled untap, and it is the same list either way: this seat is
## looking at a spell on THEIR turn with a counter in hand, which is a
## turn its lands have been untapped for since its own untap step.
##
## The answer's legality is read as far as a spell on the STACK can be
## read: the spec's kind and its own filter put to the card, and the
## printed protection put to the answer's colours the way [method
## TargetSpec.refusal_reason] puts it. A creature that will be legal only
## once something else has happened is not counted.
func _answered_later(game: MtgGame, top: StackItem, intent: EffectIntent) -> bool:
	var me := game.players[pid]
	if me.hand.size() <= 1:
		return false          # the counter is all we have: cast it
	var host := top.card
	if not (host.is_creature() or host.is_type(Mtg.CardType.ENCHANTMENT)
			or host.is_type(Mtg.CardType.ARTIFACT)):
		return false
	if intent.counters:
		return false          # a counter-war is settled by the prize, not by this
	var sources := _mana_sources(game)
	var counter_price := 99
	for inst in me.hand:
		if _is_counterspell(inst.data):
			counter_price = mini(counter_price, inst.data.cost.mana_value())
	var answers := 0
	for inst in me.hand:
		if inst.is_land() or _is_counterspell(inst.data):
			continue
		if _refused.has(str(inst.id)):
			continue
		var answer := _intent_of(inst)
		if not _answers_the_host(game, inst, answer, host):
			continue
		if inst.data.cost.mana_value() >= counter_price:
			continue          # not cheaper: the counter is the better card here
		if _plan_taps_from(sources, inst.data.cost,
				game.spell_surcharge(pid, inst.data),
				game.mana_usage_keys(inst.data)).is_empty():
			continue          # the Terror in hand with no Swamp is no answer
		answers += 1
	# THE ANSWER MUST BE SPARE, and this clause is what the Lab put here
	# (see the method's own note). Every permanent already on their side
	# has a claim on the removal in our hand, so one Swords to Plowshares
	# against a Savannah Lions on the table is not a reason to let a White
	# Knight resolve — it is a reason to counter one and Swords the other.
	var claims := 0
	for inst in game.players[top.controller].battlefield:
		if inst.is_creature() and not inst.has_keyword(Mtg.Keyword.DEFENDER):
			claims += 1
	return answers > claims


## Would [param answer] in hand deal with [param host] once it is on the
## battlefield? The reading a spell on the STACK allows: the shape, the
## spec's kind, the spec's own filter and the printed protection.
func _answers_the_host(game: MtgGame, inst: CardInstance,
		answer: EffectIntent, host: CardInstance) -> bool:
	if inst.data.is_modal() or answer.target_spec == null:
		return false
	if answer.damage_uses_x or answer.sweeper != null:
		return false          # sized on a board we cannot see yet
	var spec := answer.target_spec
	if host.is_creature():
		if not answer.answers_creatures():
			return false
		if spec.kind != TargetSpec.Kind.CREATURE \
				and spec.kind != TargetSpec.Kind.ANY \
				and spec.kind != TargetSpec.Kind.PERMANENT:
			return false
		if answer.damage > 0 and not answer.removes \
				and answer.damage < host.cur_toughness:
			return false      # a Bolt is no answer to a Serra Angel
	else:
		if not answer.removes:
			return false
		if spec.kind != TargetSpec.Kind.PERMANENT:
			return false
	if spec.filter.is_valid() and not spec.filter.call(host):
		return false
	if spec.game_filter.is_valid() and not spec.game_filter.call(game, host):
		return false
	if (host.cur_protection & inst.cur_colors) != 0:
		return false
	return true


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
	# THE SHELTER CAST (2026-09-10, AiProfile.trusts_abyss): a creature
	# spell is sometimes worth far more than it prints, because what it
	# does on that board is take the feeder's next meal away from a body
	# twice its size (_shelter_swing). It is read BEFORE the bar, because
	# the whole point of it is a one-drop the bar would never look at.
	var shelter := 0.0
	if profile.trusts_abyss and top.card.is_creature():
		shelter = _shelter_swing(game, top.card, top.controller)
		threat = maxf(threat, shelter)
	# THE SHAPE BEFORE THE BAR (2026-09-10, AiProfile.counters_by_shape):
	# what the spell DOES and what our own hand can answer, asked before
	# the one number. ALWAYS skips the bar, NEVER skips the counter, and
	# between them the bar is exactly what it was — which is the null.
	var shape := SHAPE_BAR
	if profile.counters_by_shape:
		shape = _counter_shape(game, top)
	if shape == SHAPE_NEVER:
		return ""
	if shape != SHAPE_ALWAYS and threat < profile.counter_threshold:
		return ""
	# THE ABYSS AS AN ANSWER (2026-09-08, AiProfile.trusts_abyss): a
	# creature that will be the next meal of a feeder on the table dies
	# at their upkeep having blocked once at most; the counter is saved
	# for what the feeder cannot eat. A body that is the next meal ONLY
	# because it shelters a dearer one is not that body: the feeder eats
	# it and the threat we were trusting the feeder to answer walks away,
	# so the trust is withheld exactly where the swing says it should be.
	if profile.trusts_abyss and top.card.is_creature() and shelter <= 0.0 \
			and shape != SHAPE_ALWAYS \
			and _is_next_meal(game, top.card, top.controller):
		return ""
	var top_ref := TargetRef.card(top.card)
	# THE ORDER (2026-09-10, [member AiProfile.ranks_counters]): the hand's
	# own, until this landed — and still, with the knob off.
	for inst in _counter_order(game, top, top_ref):
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
						# THE UNLESS-COST'S X (2026-09-10, [member
						# AiProfile.ranks_counters]): the smallest X the
						# caster cannot pay, which is the mana they can
						# still reach plus one — not "as deep as the mana
						# goes", which spent eight Islands making a
						# one-mana price unpayable. Whenever that X is out
						# of our own reach the old maximum stands, and so
						# does the card's own resolution: a price they CAN
						# pay is a counter that does not counter, which is
						# why the ranking above has already put anything
						# else in hand that answers ahead of it.
						x = max_x
						if profile.ranks_counters:
							var beyond := _their_open_mana(game, top.controller) + 1
							if beyond <= max_x:
								x = beyond
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
	# THE SWEEP THAT ANSWERS AN ATTACK (2026-09-08, AiProfile.times_sweeps):
	# a wipe we can activate, offered once the attackers are declared and
	# before the damage — the moment it is also a Fog. Priced by
	# _sweep_value with the declared attack as its relief; the upkeep's
	# bar, because their turn is the moment's own.
	if profile.times_sweeps and not game.combat_damage_prevented \
			and game.current_step() <= Mtg.Step.DECLARE_BLOCKERS:
		var swept := _try_activate(game, Moment.COMBAT)
		if swept != "":
			return swept
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
		var gain := Evaluator.permanent_value(attacker, profile)
		if blocks_known:
			if game.combat.was_blocked(game.combat.band_of(attacker_id)):
				for blocker_id in game.combat.blockers_of(attacker_id):
					var blocker := game.find_instance(blocker_id)
					if blocker != null and blocker.controller_id == pid \
							and _dies_to(game, blocker, attacker) \
							and not _dies_to(game, attacker, blocker):
						gain += Evaluator.permanent_value(blocker, profile)
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
						and Evaluator.permanent_value(blocker, profile) >= 3.0:
					return _cast_response(game, pump, [TargetRef.card(blocker)])
	# THE FACTORY ANIMATED TO BLOCK (2026-09-10, AiProfile.reads_manlands)
	# — last, because every responder above holds a CARD this mana might
	# be wanted for, and an animation's whole worth is spent in this
	# combat. Below the rung it returns before it reads the board.
	return _combat_animation(game)


## THE FACTORY ANIMATED TO BLOCK (2026-09-10, [member
## AiProfile.reads_manlands], the other half of the read; the third
## pass's own open row, `docs/ai-difficulty.md` §5: *"no rung animates a
## Factory to BLOCK on the opponent's turn"*).
##
## [method _animation_value] prices an animation by the ATTACK it enables
## and returns 0.0 at every moment but our own precombat main — the body,
## the mana and the whole reading are simply absent on their turn. So
## three untapped lands watched a Grizzly Bears hit us for two
## (reproduced 2026-09-10: `declared 0 block(s)`, life 20 → 18, three
## lands still untapped).
##
## THE MOMENT IS THE ONE THIS ROUTINE ALREADY OWNS — their declare-
## attackers, after the attack is declared and before we are asked for
## blocks. It is the only window there is: an animation bought at their
## upkeep is a body that has to survive their whole main phase, and one
## bought after the blockers are declared is a body that did not block.
##
## THE PROBE IS [method _would_attack_once_animated] MIRRORED, which is
## the same reason that one exists: the price and the declaration must be
## read by ONE reader, or the two disagree and the pilot pays a mana a
## turn for nothing. The body is animated under the journal, the block
## declaration's deterministic half is asked over the attackers actually
## on the table, and both are unmade.
##
## AND IT COMES LAST IN THIS ROUTINE, after every responder above has
## declined. The argument is the mana sink's ([method _try_activate]):
## the Fog, the sweep, the removal and the trick are all cards or
## answers this mana might be wanted for, and an animation is the one
## purchase whose whole value is spent inside this combat. Nothing above
## it changes behaviour.
func _combat_animation(game: MtgGame) -> String:
	if not profile.reads_manlands or game.active_player == pid:
		return ""
	if game.current_step() != Mtg.Step.DECLARE_ATTACKERS or game.awaiting_blockers:
		return ""
	var attackers: Array[CardInstance] = []
	for attacker_id in game.combat.attackers:
		var attacker := game.find_instance(attacker_id)
		if attacker != null and attacker.zone == Mtg.Zone.BATTLEFIELD:
			attackers.append(attacker)
	if attackers.is_empty():
		return ""
	# The order the block ladder itself reads them in.
	attackers.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	for inst in game.players[pid].battlefield:
		if inst.is_creature() or inst.tapped:
			continue
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _ability_available(game, inst, index):
				continue
			if not _animation_timing_open(game, ability, pid):
				continue
			var anim := EffectIntent.read(ability.effects,
				inst.data.card_name).animates
			if anim == null or (anim.add_types & Mtg.CardType.CREATURE) == 0 \
					or anim.set_power <= 0:
				continue
			if not _animation_payable(game, inst, ability):
				continue
			if not _would_block_once_animated(game, inst, anim, attackers):
				continue
			if not _pay_without_source(game, inst, ability):
				continue
			if game.activate_ability(pid, inst, index, []) != "":
				game.log_line("(AI animation of %s refused)" % inst.data.card_name)
				_refused["%d:%d" % [inst.id, index]] = true
				return ""
			return "animates %s to block" % inst.data.card_name
	return ""


## Would the block declaration put [param inst] in front of something,
## once [param anim] has made it a creature — and would it come back?
##
## The first half is [method _would_attack_once_animated]'s question with
## the roles swapped, and it is asked of the same declaration code the
## step after this one will run ([method _block_choice], or the pumped
## probe when the knob for that is on), so the animation is never bought
## for a block the ladder was not going to make.
##
## THE SECOND HALF IS [method _animation_value]'S OWN REFUSAL, mirrored.
## What animates here is almost always a LAND, and a land traded for
## nothing is a mana source a control deck needed — so the body steps out
## only when it LIVES through the block, or takes the attacker with it. A
## chump block by a Mishra's Factory is a mana source spent on two points
## of life, and the block ladder's panic rung cannot know it is spending
## a land.
##
## AND THE PROBE LEAVES NO PLAN BEHIND. [method _block_choice_once_pumped]
## writes the breath allotment down ([member _pump_plan]) for [method
## _combat_planned_pumps] to spend, and that member is NOT journaled —
## a probe that left its own allotment there would have the pilot paying
## for a block on a board that never existed. It is saved and put back
## around the call, the way the journal puts the board back.
func _would_block_once_animated(game: MtgGame, inst: CardInstance,
		anim: AnimateSelfEffect, attackers: Array[CardInstance]) -> bool:
	var saved_plan := _pump_plan.duplicate()
	var saved_turn := _pump_plan_turn
	var owned := game.undo_log == null
	var mark := game.make_mark()
	game.continuous.add_until_eot_animation(inst.id, anim.add_types,
		anim.set_power, anim.set_toughness, anim.add_subtypes, anim.combat_duration)
	game.recalculate()
	var would := false
	if inst.is_creature() and not inst.tapped:
		var free: Array[CardInstance] = []
		for body in game.players[pid].battlefield:
			if body.is_creature() and not body.tapped:
				free.append(body)
		var used: Array[int] = []
		var plan := _block_choice_once_pumped(game, attackers, free, used) \
			if profile.pumps_to_attack else _block_choice(game, attackers, free, used)
		var against: Variant = plan.get(inst.id)
		if against != null:
			var first: int = int(against[0]) if against is Array else int(against)
			var attacker := game.find_instance(first)
			would = attacker != null \
				and (not _dies_to(game, inst, attacker) or _dies_to(game, attacker, inst))
	game.unmake_to(mark)
	if owned:
		game.end_search()
	_pump_plan = saved_plan
	_pump_plan_turn = saved_turn
	return would


## We are ATTACKING; blocks are (being) declared.
##
## AND THE PUMP PLAN IS NOT CONSULTED HERE, BY RULING (2026-09-09, the
## fourth pass at [member AiProfile.pumps_to_attack]). The note this
## routine carried said it "spends the leftovers off-plan", and it does:
## measured on that date, two unblocked firebreathers behind four Swamps,
## the declaration's split two and two ([method _pump_shares]), and this
## loop poured all four into the first body it met — a 4/5 Carrion Ants
## beside a 0/1 Vampire Bats where the plan had priced a 2/3 and a 2/1.
##
## It costs NOTHING, and the reason is structural rather than lucky. The
## plan is a DECLARATION's split: which body has to be big enough to be
## worth sending. By the time this runs the blocks are in, the bodies it
## serves are UNBLOCKED, and every point they buy is face damage — which
## is fungible between them, so any split of the same pool lands the same
## total (16 life either way, on that board). Two things then argue
## against honouring it: a breath that is dearer per point of power would
## be handed mana a cheaper one could spend better, and an allotment made
## out to a body that stayed home, died, or was blocked would simply go
## unspent. [method _combat_self_pumps] always has its say BEFORE this
## routine does ([method _respond_action]'s order), so the mana reaching
## here is mana the plan's own recovery has already declined.
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
		if Evaluator.permanent_value(blocker, profile) + Evaluator.permanent_value(attacker, profile) >= 5.0:
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
	# ONE RESERVE, AND IT IS THE DECLARATION'S OWN (2026-09-09,
	# [member AiProfile.pumps_to_attack]). This loop booked the second
	# main phase and nothing else, so it would spend a Counterspell's
	# {U}{U} on two points of face damage — the asymmetry the note of
	# 36058fc named and the fourth pass closed. [method _pump_reserve] is
	# the cost every OTHER breath in this file is already priced against
	# (both declaration probes and [method _combat_self_pumps] reach it
	# through [method _pumps_in_reach]), and it books the same second main
	# phase plus the held instant or counter the reactive game is waiting
	# on. Measured on 2026-09-09: a Carrion Ants unblocked behind four
	# Swamps and two Islands with a Counterspell in hand — the
	# declaration priced it at FOUR breaths and the recovery bought SIX,
	# tapping every land, and the counter could not be paid for.
	var kept: ManaCost = null
	if profile.pumps_to_attack:
		kept = _pump_reserve(game, sources)
	else:
		var main2 := _main2_reserve(game, sources)
		if not main2.is_empty():
			kept = main2["cost"]
	for attacker in unblocked:
		for index in attacker.cur_activated_abilities.size():
			var ability: ActivatedAbility = attacker.cur_activated_abilities[index]
			if ability.tap_cost or ability.effects.size() != 1:
				continue
			# What ONE activation adds to the power: the PumpEffect the
			# reader can see, or — since 2026-09-09, under [member
			# AiProfile.pumps_to_attack] — the card-local breath the table
			# names for it. A Dragon Whelp with six Mountains and its
			# opponent at 5 life used to swing for 2 and leave every
			# Mountain untapped, because this loop tested `is PumpEffect`
			# and its breath is a class inside its own card file.
			var per_pump := 0
			if ability.effects[0] is PumpEffect and ability.effects[0].self_mode:
				per_pump = int(ability.effects[0].power)
			else:
				per_pump = int(_card_local_breath(attacker, index,
					EffectIntent.read(ability.effects, attacker.data.card_name)
					).get("power", 0))
			if per_pump <= 0:
				continue
			# The same gate every other activation passes: a pump whose
			# price is a BODY (Fallen Angel, Atog) is not firebreathing,
			# and used to eat the board one Serra at a time.
			if not _ability_available(game, attacker, index):
				continue
			# THE FUSE, and the one place it may be lit. Dragon Whelp's
			# fourth breath sacrifices the dragon at the next end step
			# (CR 701.17 — the delayed sacrifice regeneration cannot
			# stop), so [method _activations_left] hands this loop three
			# and no more. A dragon is worth spending on the attack that
			# ENDS THE GAME and on nothing else — and only while the game
			# is not already ending: the damage on the table is read
			# FIRST (`unblocked_total` carries the breaths already
			# bought), so a Whelp that has reached exactly lethal at
			# three stops there and keeps itself. Buying past lethal is
			# free for every other firebreather and costs a dragon here.
			if _activations_left(game, attacker, index) == 0 \
					and not (unblocked_total < them.life
						and _pumps_are_lethal(game, attacker, ability, sources,
							unblocked_total, per_pump)):
				continue
			var surcharge := game.ability_surcharge(pid, attacker)
			if kept != null \
					and _plan_taps_from(sources,
						_combined_cost(ability.cost, kept), surcharge).is_empty() \
					and not _pumps_are_lethal(game, attacker, ability, sources,
						unblocked_total, per_pump):
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
		var keys: Array = game.mana_usage_keys(inst.data)
		if _plan_taps_from(sources, inst.data.cost, surcharge, keys).is_empty():
			continue
		var value := Evaluator.card_value(inst.data)
		if value >= 3.0 and value > float(out.get("value", 0.0)):
			# `surcharge` and `keys` are the same two the plan above was
			# made with, carried so a second caller ([method
			# _main2_mana_held]) can re-plan the identical cost without
			# guessing at them. Every older reader takes `cost` and
			# `value` and is unaffected.
			out = {"cost": inst.data.cost, "value": value,
				"surcharge": surcharge, "keys": keys}
	return out


## Would firebreathing [param attacker] with everything open finish them?
## The one case where the second main phase does not matter.
##
## [param per_pump] is what ONE activation adds to the power, 0 for "read
## it off the effect" — the card-local breaths (2026-09-09) have no
## [PumpEffect] to read it from, and asking `effects[0].power` of a
## [WhelpBreathEffect] is a script error, not a zero.
func _pumps_are_lethal(game: MtgGame, attacker: CardInstance,
		ability: ActivatedAbility, sources: Array, unblocked_total: int,
		per_pump := 0) -> bool:
	var them := game.players[game.opponent_of(pid)]
	var power := per_pump
	if power <= 0:
		if not (ability.effects[0] is PumpEffect):
			return false
		power = int(ability.effects[0].power)
	if power <= 0:
		return false
	# Bounded by the mana open, and — since 2026-09-09 — by the ability's
	# own per-turn cap: a Fire Drake with five Mountains breathes once.
	# The FUSE is not a bound here and nowhere else it is not: a dragon
	# sacrificed at the next end step of a game that ended this turn cost
	# nothing at all, which is the whole of "worth a dragon".
	var index := attacker.cur_activated_abilities.find(ability)
	var pumps := _pumps_in_reach(game, attacker, ability, sources, null,
		_activations_left(game, attacker, index, true) if index >= 0 else -1)
	return unblocked_total + pumps * power >= them.life


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

## The bodies that may be declared this turn: creatures, legal to attack
## [param defender] under every ban on the board (our own Moat stops a
## Factory as surely as theirs), whose attack cost is payable.
func _attack_candidates(game: MtgGame, defender: int) -> Array[CardInstance]:
	var candidates: Array[CardInstance] = []
	# THE MANA THE SECOND MAIN PHASE IS WAITING ON (2026-09-10,
	# AiProfile.develops_late): a Llanowar Elves that attacks is a Llanowar
	# Elves that cannot be tapped after combat.
	var held := _main2_mana_held(game)
	for inst in game.players[pid].battlefield:
		if inst.is_creature() \
				and CombatState.attack_illegality(game, inst, defender) == "" \
				and _attack_costs_payable(game, inst):
			if held.has(inst.id) and not _must_attack(inst):
				continue
			candidates.append(inst)
	return candidates


## THE DECLARATION ITSELF, deterministic: the lethal push or the cohort,
## the pump rider, the crack-back search, the must-attackers. Everything
## [method _declare_attacks] then does to it — the mistake roll, the
## bans and the cap, the band — is either random or a restriction the
## engine enforces, so this is the half a PROBE may ask without moving
## the game's random stream ([method _would_attack_once_animated]).
func _attack_choice(game: MtgGame, candidates: Array[CardInstance],
		defender: int) -> Array:
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
							or Evaluator.permanent_value(inst, profile) > Evaluator.permanent_value(extra, profile)):
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
	return attackers


## THE FIREBREATHER THAT NEVER SWUNG (2026-09-09,
## [member AiProfile.pumps_to_attack]). The owner's playtest: *"when
## creatures can have greater power or defense by some action (like
## paying mana), the ai opponent does not use this before attack for
## example (even if opponent has free mana available). In other words:
## Opponent does not pump Carrion Ants :)"*.
##
## Everything AFTER the declaration was already right — an unblocked
## attacker breathes fire for the damage ([method
## _offensive_combat_response]), a blocked one pumps to win or survive
## its trade ([method _combat_self_pumps]) — and neither had ever been
## given an attacker to work with, because the declaration reads
## [member CardInstance.cur_power] and nothing else: [method
## _choose_attack_cohort] drops a body with no power before it prices
## anything, so a Carrion Ants with four Swamps untapped (a 4/5 for the
## asking) was a 0/1 that could not be worth sending, and a Frozen Shade
## or a Killer Bees stayed home for the whole duel.
##
## So the question is put to the declaration itself, under the journal,
## exactly as [method _would_attack_once_animated] puts the Factory's:
## every candidate is grown to the size its share of the open mana can
## reach, the deterministic half of the declaration is asked, and the
## pumps are unmade. No mana is tapped here — the pump is bought later,
## one activation at a time, by the two routines above, and against the
## real board each time. No random stream is consumed ([method
## _attack_choice] has no mistake roll), and a search already in
## progress keeps its journal.
##
## ONE DIFFERENCE FROM THE FACTORY, and it runs the other way. An
## animated Factory is a land again at cleanup, so the crack-back model
## had to stop counting it as a blocker on their turn; a pumped body is
## a creature either way and our lands untap before they swing, so the
## search reading it at its reach size on their turn is the truth, not
## an over-count. Nothing here is excluded from it.
func _attack_choice_once_pumped(game: MtgGame, candidates: Array[CardInstance],
		defender: int) -> Array:
	var shares := _pump_shares(game, candidates)
	# THE SPLIT IS WRITTEN DOWN HERE (2026-09-09), before anything is
	# hung on the board: what the declaration is about to be made on is
	# what [method _combat_self_pumps] has to buy once the blocks are in.
	_remember_pump_plan(game, shares)
	if shares.is_empty():
		return _attack_choice(game, candidates, defender)
	var owned := game.undo_log == null
	var mark := game.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		game.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	game.recalculate()
	var chosen := _attack_choice(game, _attack_candidates(game, defender), defender)
	game.unmake_to(mark)
	if owned:
		game.end_search()
	return chosen


## The bonus each of [param candidates] could pay its way to right now,
## `{instance id: Vector2i}` — the empty dictionary when none of them can.
##
## ONE POOL, spent once. Two Frozen Shades in front of four Swamps are
## not both a 4/5, so the mana a body is priced with comes off the table
## before the next body is priced. The body that cannot swing AT ALL
## without the mana is served first — that is the attack the knob exists
## to create — and the rest in the order the evaluator values them.
##
## ONE PRICING PATH FOR BOTH DECLARATIONS (2026-09-09). [param candidates]
## is our attackers-to-be on our turn ([method _attack_choice_once_pumped])
## and our untapped bodies on theirs ([method _block_choice_once_pumped]),
## and the pricing does not care which: the question is the same question,
## and asking it twice in two places is how the two halves drift apart.
## The order is the same too — the body with no power at all is the body
## the mana transforms, blocking as much as attacking (a 0/1 blocks
## anything and kills nothing).
##
## The totals are all the two probes ever wanted; the split behind them —
## which body was allotted how many breaths — is [method _pump_shares],
## and it is what [method _combat_self_pumps] has to spend and what
## [method _absorbed_by] has to price a trampler against.
func _reachable_pumps(game: MtgGame, candidates: Array[CardInstance]) -> Dictionary:
	var out: Dictionary = {}
	var shares := _pump_shares(game, candidates)
	for id in shares:
		var share: Dictionary = shares[id]
		out[id] = Vector2i(share["bonus"]) * int(share["count"])
	return out


## THE SAME SPLIT, BREATH BY BREATH (2026-09-09) — `{instance id:
## {index, ability, bonus, count}}`, where `bonus` is what ONE activation
## grants and `count` is how many of them that body was allotted.
##
## [method _reachable_pumps] is the total this hands the two declaration
## probes, and it was all anybody needed while the split was read once and
## thrown away. Two readings want the pieces instead:
##
##  * [method _combat_self_pumps], which has to SPEND the allotment
##    ([member _pump_plan]) rather than the whole pool — the split is a
##    plan, and a plan the recovery ignores is a block declared on a lie;
##  * [method _absorbed_by], which has to know how many of the breaths
##    the recovery will actually buy before it prices a TRAMPLER's
##    overflow against them.
##
## Everything the old routine did, it still does, in the same order and
## against the same reserve.
func _pump_shares(game: MtgGame, candidates: Array[CardInstance]) -> Dictionary:
	var out: Dictionary = {}
	# The bodies FIRST, and the mana only if there are any: most boards
	# hold no firebreather at all, and this runs on every declaration a
	# Sorcerer or a Wizard makes.
	var breathers: Array = []
	for inst in candidates:
		var pump := _self_pump_of(game, inst)
		if not pump.is_empty():
			pump["inst"] = inst
			breathers.append(pump)
	if breathers.is_empty():
		return out
	var sources := _mana_sources(game)
	if sources.is_empty():
		return out
	var kept := _pump_reserve(game, sources)
	breathers.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		var a: CardInstance = x["inst"]
		var b: CardInstance = y["inst"]
		var a_mute := a.cur_power <= 0
		var b_mute := b.cur_power <= 0
		if a_mute != b_mute:
			return a_mute
		return Evaluator.permanent_value(a, profile) > Evaluator.permanent_value(b, profile))
	for pump in breathers:
		var inst: CardInstance = pump["inst"]
		var ability: ActivatedAbility = pump["ability"]
		var reach := _pumps_in_reach(game, inst, ability, sources, kept,
			_activations_left(game, inst, int(pump["index"])))
		if reach <= 0:
			continue
		out[inst.id] = {"index": int(pump["index"]), "ability": ability,
			"bonus": Vector2i(pump["bonus"]), "count": reach}
		var cost: ManaCost = ability.cost
		for _i in reach - 1:
			cost = _combined_cost(cost, ability.cost)
		sources = _sources_after(sources, _plan_taps_from(sources, cost,
			game.ability_surcharge(pid, inst) * reach))
	return out


## Write [param shares] down as the plan this combat's breaths are to be
## bought against ([member _pump_plan]).
func _remember_pump_plan(game: MtgGame, shares: Dictionary) -> void:
	_pump_plan = {}
	for id in shares:
		_pump_plan[id] = int(shares[id]["count"])
	_pump_plan_turn = game.turn_number


## Activations of [param inst] still owed by the plan — 0 when the plan is
## from another turn, when the body was priced at nothing, or when it has
## already had everything it was allotted.
func _pump_plan_for(game: MtgGame, inst: CardInstance) -> int:
	if _pump_plan_turn != game.turn_number:
		return 0
	return int(_pump_plan.get(inst.id, 0))


## The self-pump [param inst] would breathe with, as
## `{index, ability, bonus}` — `{}` when it has none the pilot may use.
##
## The gates are the ones the other pump paths already keep. No tap cost
## (a body that taps to pump cannot also attack), the ability available
## on its own terms ([method _ability_available], which is what keeps a
## pump priced in BODIES — Atog, Fallen Angel — invisible here as
## everywhere else, and one priced in COUNTERS invisible too until
## [member AiProfile.spends_counters] rules on it), a POWER bonus (a
## Granite Gargoyle's +0/+1 buys no attack), no
## toughness LOSS (Wall of Wonder's +4/-4 is a different card and a
## Defender besides), and nothing in the effect list the reader cannot
## price beside the pump — an Electric Eel's {R}{R} also shocks its
## controller, and a shape [EffectIntent] reads as `unknown` is not
## firebreathing. The FIRST such ability, not the best: a body with
## several breaths (Vaevictis Asmadi's three colours) is counted at one
## of them, which under-counts and never over-counts.
##
## THE ONE EXCEPTION TO `unknown` (2026-09-09) is an ability whose WHOLE
## effect list is a card-local breath the reader has a row for ([method
## _card_local_breath], [constant EffectIntent.CARD_LOCAL_PUMPS]): the
## row says what the effect does, so nothing unpriced is left standing
## beside it. That is the difference between Dragon Whelp — one effect,
## one row, read — and an Electric Eel, whose pump IS a [PumpEffect] and
## has an unpriced second effect next to it, and stays refused.
##
## [param for_toughness] turns the power gate around (2026-09-09,
## [member AiProfile.pumps_to_attack]'s fourth reading): the burn on the
## stack is answered with TOUGHNESS, so [method _pump_out_of_reach] wants
## the Granite Gargoyle's `{R}: +0/+1` this function exists to refuse, and
## does not care whether the breath grants power at all. Every other gate
## is the same one, and the default is the reading this had before.
func _self_pump_of(game: MtgGame, inst: CardInstance,
		for_toughness := false) -> Dictionary:
	for index in inst.cur_activated_abilities.size():
		var ability: ActivatedAbility = inst.cur_activated_abilities[index]
		if ability.tap_cost or ability.cost == null:
			continue
		var intent := EffectIntent.read(ability.effects, inst.data.card_name)
		var bonus := Vector2i(intent.pump_power, intent.pump_toughness)
		if not intent.pump_self or intent.unknown:
			# ...or a breath the shared vocabulary cannot express and the
			# table names instead (2026-09-09: Dragon Whelp, Nalathni
			# Dragon). Same gates, same price, same cap.
			var breath := _card_local_breath(inst, index, intent)
			if breath.is_empty():
				continue
			bonus = Vector2i(int(breath["power"]), int(breath["toughness"]))
		if bonus.x < 0 or bonus.y < 0:
			continue
		if (bonus.y <= 0) if for_toughness else (bonus.x <= 0):
			continue
		if not _ability_available(game, inst, index):
			continue
		return {"index": index, "ability": ability, "bonus": bonus}
	return {}


## WHAT THE MANA IS OTHERWISE FOR, as one cost the pump must leave
## payable — null when nothing is spoken for. Two bookings, and both are
## the pilot's own: the second main phase's best sorcery-speed cast, the
## reserve the firebreathing itself already keeps ([method
## _main2_reserve]), and the held instant or counterspell the reactive
## game is waiting on ([method _held_reserve], the reserve every
## activation respects). A pump that spends the Counterspell's mana on
## two points of damage is a bad trade, and this is where it is refused.
##
## A booking that cannot be paid for out of what is open books nothing:
## [method _held_reserve] reserves a Counterspell's {U}{U} from the
## moment the card is in hand, Islands or no Islands, and a reserve like
## that would silently zero every pump in the deck.
##
## AND ONE OF THE TWO IS OUR TURN'S ONLY (2026-09-09, the block half).
## The second main phase is a phase of OUR turn: on theirs there is no
## sorcery-speed cast this mana is being kept for, and our lands untap
## before the phase that wants it. Booking it while blocking would keep
## a Hypnotic Specter's four Swamps back from the block that saves the
## body they were kept from — mana spent on nothing at all. The held
## instant books on both turns, and on theirs it is the more real of the
## two.
func _pump_reserve(game: MtgGame, sources: Array) -> ManaCost:
	var kept: ManaCost = null
	var main2 := _main2_reserve(game, sources) if pid == game.active_player else {}
	if not main2.is_empty():
		kept = main2["cost"]
	var held := _held_reserve(game)
	if not held.is_empty():
		var cost: ManaCost = held["cost"]
		if not _plan_taps_from(sources, cost, 0).is_empty():
			kept = cost if kept == null else _combined_cost(kept, cost)
	return kept


## How many more times ability [param index] of [param inst] may be
## activated this turn, or -1 for "as often as the mana lasts".
##
## THE CAP (2026-09-09). A reach counted in mana alone promises what the
## card will not deliver: a Fire Drake with five Mountains open is a 2/2
## and not a 6/2, because its breath is `{R}: +1/+0` ONCE a turn, and a
## Vampire Bats is a 2/1 at most. [method _ability_available] refuses the
## activation itself once the cap is spent, so the mana was never lost —
## but the reading that sent the attacker was wrong, and a body sent on a
## size it cannot reach is exactly what this knob exists to stop. Gated
## by [member AiProfile.pumps_to_attack] so the Deck Lab can run the
## null: without it every reach in this file counts the mana only, as it
## did before.
##
## THE FUSE (2026-09-09, the second half). Dragon Whelp and Nalathni
## Dragon carry a cap of a different kind: *"if this ability has been
## activated four or more times this turn, sacrifice this creature at the
## beginning of the next end step"*. It is not a restriction — the engine
## will happily sell the fourth breath — it is a PRICE, and the price is
## the dragon. So three is what this hands every reader, and the fourth
## is available only to a caller that passes [param may_light_fuse],
## which is the lethal probe and nothing else: a dragon sacrificed at the
## end step of a game that ended in this combat cost nothing.
##
## The count is the card's own ([member CardInstance.memory], keyed by
## the row in [constant EffectIntent.CARD_LOCAL_PUMPS]) because
## [member CardInstance.ability_uses] is only kept for an ability with a
## [member ActivatedAbility.max_per_turn] and the fuse is not one. The
## activations already on the stack count too — they have paid their mana
## and not yet written their tally.
func _activations_left(game: MtgGame, inst: CardInstance, index: int,
		may_light_fuse := false) -> int:
	if not profile.pumps_to_attack:
		return -1
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var left := -1
	if ability.max_per_turn > 0:
		left = maxi(ability.max_per_turn - int(inst.ability_uses.get(index, 0)), 0)
	if may_light_fuse:
		return left
	var breath := _card_local_breath(inst, index,
		EffectIntent.read(ability.effects, inst.data.card_name))
	var fuse := int(breath.get("fuse", 0))
	if fuse <= 0:
		return left
	var spent := _breaths_this_turn(game, inst, breath) + _pending_pumps(game, inst)
	var safe := maxi(fuse - 1 - spent, 0)
	return safe if left < 0 else mini(left, safe)


## THE FIREBREATHERS THE READER CANNOT SEE (2026-09-09,
## [member AiProfile.pumps_to_attack]). The breath ability [param index]
## of [param inst] grants, as a row of
## [constant EffectIntent.CARD_LOCAL_PUMPS] — `{}` when there is none.
##
## Dragon Whelp and Nalathni Dragon pump themselves through a `class X
## extends EffectBase` written inside their own card file, because the
## breath carries a fuse the shared [PumpEffect] cannot express. So
## [member EffectIntent.pump_self] is false for both, and until this
## existed NO pump path in this file had ever seen either of them: not
## the attack declaration, not the block declaration, not the
## firebreathing on an unblocked attacker, not the pump that wins a
## blocked trade. A Whelp with six Mountains open swung for 2 into an
## empty board with its opponent at 5 life and left every Mountain
## untapped.
##
## GATED, and deliberately. A reading in the reader's own tables is
## ungated — every profile gets it — and an ungated Whelp row would have
## changed [method _combat_self_pumps] with the knob OFF, which is to say
## it would have moved the null the Deck Lab measures this knob against.
## Worse than untidy: the FUSE reading above is itself gated, so an
## ungated row would have sold the fourth breath with no cap read at all
## and doomed the dragon for a trade. One gate, one story.
##
## The row is the card's ONE breath: it is offered only for an ability
## whose whole effect list is the single card-local effect the reader
## called `unknown`, so a second ability of the same card (Rainbow
## Knights' `{1}`: first strike, a real [PumpEffect]) can never pick it
## up by name.
func _card_local_breath(inst: CardInstance, index: int,
		intent: EffectIntent) -> Dictionary:
	if not profile.pumps_to_attack:
		return {}
	if intent.pump_self or not intent.unknown:
		return {}
	if inst.cur_activated_abilities[index].effects.size() != 1:
		return {}
	return EffectIntent.card_local_pump(inst.data.card_name)


## How many breaths of THIS turn [param inst] has already taken, read out
## of the card's own memory through [param breath]'s key names. The turn
## number travels with the count because nothing clears card memory
## between turns, and "four or more times THIS TURN" resets.
func _breaths_this_turn(game: MtgGame, inst: CardInstance,
		breath: Dictionary) -> int:
	var turn_key := String(breath.get("fuse_turn", ""))
	if turn_key != "" and int(inst.memory.get(turn_key, -1)) != game.turn_number:
		return 0
	return int(inst.memory.get(String(breath.get("fuse_count", "")), 0))


## [param sources] with everything [param plan] would tap taken out of
## it — the planner's list minus the planner's own answer, so the next
## body is priced against what is actually left. A plan entry is
## `[instance, ability_index]` and a null instance is mana already
## floating, which is keyed apart from every permanent.
func _sources_after(sources: Array, plan: Array) -> Array:
	if plan.is_empty():
		return sources
	var spent: Dictionary = {}
	for pair in plan:
		var owner_id := -1 if pair[0] == null else int(pair[0].id)
		var key := "%d:%d" % [owner_id, int(pair[1])]
		spent[key] = int(spent.get(key, 0)) + 1
	var out: Array = []
	for src in sources:
		var owner_id := -1 if src[0] == null else int(src[0].id)
		var key := "%d:%d" % [owner_id, int(src[1])]
		if int(spent.get(key, 0)) > 0:
			spent[key] = int(spent[key]) - 1
			continue
		out.append(src)
	return out


## THE DECLARATION, WITH THEIR MANLANDS ON THE TABLE (2026-09-10,
## [member AiProfile.reads_manlands]). One line, so that [method
## _declare_attacks] keeps reading as the ladder it is, and so that the
## two halves of the declaration — the pumped one and the plain one —
## stay one call for every reader that follows.
func _attack_declaration(game: MtgGame, candidates: Array[CardInstance],
		defender: int) -> Array:
	if profile.reads_manlands:
		return _attack_choice_reading_manlands(game, candidates, defender)
	return _attack_choice_once_pumped(game, candidates, defender) \
		if profile.pumps_to_attack else _attack_choice(game, candidates, defender)


## THE MANLAND IS A BLOCKER (2026-09-10, [member
## AiProfile.reads_manlands]; `docs/forge/combat.md` P7). [method
## _attack_choice] prices the attack against their untapped CREATURES, so
## a Mishra's Factory with {1} open is invisible to the cohort, to the
## pump rider and to the crack-back model alike — and the Grizzly Bears
## that walks into it trades a card for a mana (reproduced 2026-09-10:
## `blockers the attack reading sees: 0`, `_attack_risk -1.0`, the Bears
## sent).
##
## The question is put to the declaration itself with their affordable
## animations HUNG ON, under the journal, exactly as [method
## _would_attack_once_animated] puts our own Factory's and [method
## _attack_choice_once_pumped] puts our own breath's: the bodies are
## animated the way their abilities would animate them, the deterministic
## half of the declaration is asked, and the animations are unmade. No
## mana is tapped, no random stream is consumed ([method _attack_choice]
## has no mistake roll), and a search already in progress keeps its
## journal.
##
## WHY IT IS THE WHOLE DECLARATION AND NOT ONE LIST. The blockers a
## cohort is priced against, the bodies the pump rider looks past and the
## `theirs` side of [method _build_combat_model] are three readings of the
## same battlefield taken in three places; hanging the animation on the
## BOARD is what makes all three agree, and it is the only way the
## crack-back model — which builds itself out of `is_creature()` — can
## see the body at all.
##
## AND IT IS AN OVER-COUNT ON THEIR NEXT TURN, in the safe direction and
## on purpose. An animation lasts until end of turn, so the Factory the
## model treats as a creature that could swing at us next turn is one
## they would have to pay for again. That is the same judgement [method
## _build_combat_model] already records about its own defensive reads —
## over-including a body that might block or swing is the safe way to be
## wrong — and it is the mirror of [member animates_to_attack]'s ruling
## about OUR animated body, which is excluded because holding it home
## buys nothing.
func _attack_choice_reading_manlands(game: MtgGame,
		candidates: Array[CardInstance], defender: int) -> Array:
	var manlands := _animatable_bodies(game, defender)
	if manlands.is_empty():
		return _attack_choice_once_pumped(game, candidates, defender) \
			if profile.pumps_to_attack else _attack_choice(game, candidates, defender)
	var owned := game.undo_log == null
	var mark := game.make_mark()
	for row in manlands:
		var anim: AnimateSelfEffect = row["anim"]
		game.continuous.add_until_eot_animation(int(row["id"]), anim.add_types,
			anim.set_power, anim.set_toughness, anim.add_subtypes,
			anim.combat_duration)
	game.recalculate()
	var fresh := _attack_candidates(game, defender)
	var chosen := _attack_choice_once_pumped(game, fresh, defender) \
		if profile.pumps_to_attack else _attack_choice(game, fresh, defender)
	game.unmake_to(mark)
	if owned:
		game.end_search()
	# AND THE DECLARATION IS FILTERED BACK TO THE REAL BOARD. Attack
	# legality can read the DEFENDER's permanents ("can't attack unless
	# the defending player controls a ..." — CombatState.attack_illegality),
	# so a body animated inside the probe could make an attack legal that
	# the engine refuses the moment the probe is unmade. The declaration
	# ladder would survive it — a refusal falls back to the conscripts —
	# but a fallback is a worse attack than the one we meant, and the
	# candidates the caller handed us are the ones the board really has.
	var legal: Array = []
	for id in chosen:
		for inst in candidates:
			if inst.id == id:
				legal.append(id)
				break
	return legal


## Every permanent of [param who]'s that could make ITSELF a creature
## right now, as `[{id, anim}]` — the bodies [method
## _attack_choice_reading_manlands] hangs on the board and nothing else.
##
## THE COST IS PAID FROM THEIR OTHER SOURCES, which is [method
## _animation_payable]'s rule read from the other side of the table: a
## Factory that taps for its own {1} is a tapped body and no blocker at
## all (CR 509.1a). Their mana is counted the way [method _shieldable]
## counts it — untapped permanents that make mana, which is public
## information both seats can see — and never from their hand, which is
## not.
##
## The timing riders that could refuse the activation are honoured
## because they are printed on the ability and cost nothing to read: an
## "activate only during your turn" ability is not one they may use in
## OUR combat, and a combat-only one (Jade Statue) is one they may. What
## is deliberately not modelled is [member ActivatedAbility.max_per_turn]
## and an [member ActivatedAbility.activation_condition], both of which
## would need a per-instance count or the card's own predicate; both
## over-include, which on a read of what may BLOCK us is the safe way to
## be wrong.
func _animatable_bodies(game: MtgGame, who: int) -> Array:
	var out: Array = []
	var open := 0
	for p in game.players[who].battlefield:
		if not p.tapped and not p.cur_mana_abilities.is_empty() \
				and not (p.is_creature() and p.summoning_sick):
			open += 1
	for inst in game.players[who].battlefield:
		if inst.is_creature() or inst.tapped:
			continue
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not _animation_timing_open(game, ability, who):
				continue
			var anim := EffectIntent.read(ability.effects,
				inst.data.card_name).animates
			if anim == null or (anim.add_types & Mtg.CardType.CREATURE) == 0 \
					or anim.set_power <= 0:
				continue
			var mine := 1 if not inst.cur_mana_abilities.is_empty() else 0
			if ability.cost.mana_value() > open - mine:
				continue
			out.append({"id": inst.id, "anim": anim})
			break
	return out


## The printed timing riders on [param ability], asked of the step we are
## actually in for the seat [param who]. A thin mirror of the three
## clauses [method MtgGame.activate_ability] enforces — it exists so the
## reading of THEIR permanent can be made without asking the engine to
## pay for anything.
func _animation_timing_open(game: MtgGame, ability: ActivatedAbility,
		who: int) -> bool:
	if ability.only_opponents_may_activate or ability.cost.has_x:
		return false
	if ability.only_during_combat and not Mtg.is_combat_step(game.current_step()):
		return false
	if ability.only_during_step >= 0 and game.current_step() != ability.only_during_step:
		return false
	if ability.only_before_step >= 0 \
			and Mtg.STEP_ORDER.find(game.current_step()) \
				>= Mtg.STEP_ORDER.find(ability.only_before_step):
		return false
	if ability.turn_restriction > 0 and game.active_player != who:
		return false
	if ability.turn_restriction < 0 and game.active_player == who:
		return false
	return true


## Attack declaration: per-attacker favorable-trade analysis (mage-go's
## combat heuristic, simplified), plus a lethal-push override and the
## aggression/mistake tilts from the profile.
func _declare_attacks(game: MtgGame) -> String:
	var defender := game.opponent_of(pid)
	var candidates := _attack_candidates(game, defender)
	var attackers := _attack_declaration(game, candidates, defender)
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
					or Evaluator.permanent_value(inst, profile) > Evaluator.permanent_value(best_rider, profile):
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
		return Evaluator.permanent_value(a, profile) > Evaluator.permanent_value(b, profile))
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
	var my_value := Evaluator.permanent_value(inst, profile)
	var worst_loss := -1.0   # < 0 = unblockable by anything they have
	# TAPPING INTO AN EXECUTION (2026-09-10, [member
	# AiProfile.reads_gaze]). The whole of this function below is about
	# BLOCKERS, and an assassin is not one: the body is lost for having
	# tapped, before a blocker is declared and whether or not anything
	# over there could have blocked it. So it is priced first, at the
	# body's own worth, and it deliberately overwrites the "nothing may
	# block this" answer — a Hypnotic Specter no 1/1 can stop is exactly
	# the body the {T} was waiting for.
	if profile.reads_gaze and _taps_into_execution(game, inst, defender):
		worst_loss = my_value
	for blocker in blockers:
		if CombatState.block_illegality(game, blocker, inst, defender) != "":
			continue
		worst_loss = maxf(worst_loss, 0.0)
		# THEIR PUMPS ARE PUBLIC (2026-09-10, [member
		# AiProfile.reads_pumps]). This is where a body of ours is being
		# SENT into theirs, so the breath their open mana pays for is
		# asked of the blocker as well: a Grizzly Bears into a 0/1 Frozen
		# Shade behind four Swamps read 0.00 here — "we kill it and live"
		# — and was in the graveyard with their life still twenty.
		# [method _dies_to] carries the other direction (their body
		# surviving ours) for every reader.
		var grows := _pump_reach(game, blocker)
		var kills_me := _dies_to(game, inst, blocker, bonus, grows)
		var survives_me := not _dies_to(game, blocker, inst, Vector2i.ZERO, bonus)
		if kills_me and survives_me:
			worst_loss = maxf(worst_loss, my_value)          # pure loss
		elif kills_me:
			var trade := my_value - Evaluator.permanent_value(blocker, profile)
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
##
## AND IT IS ALSO THE ONLY QUESTION IT EVER ASKED (2026-09-10, [member
## AiProfile.crack_back_margin]). An exact gate on LOSING THE GAME never
## asks whether the swing costs us eight life for one point of damage,
## which is a bad attack at twenty life as much as at nine. The search has
## priced life since it was built ([method CombatSearch._fdv]), so the
## knob is the gate and nothing else: it lowers the bar by its own number
## of life points and lets the same search answer the same way. Zero is
## the gate exactly as it stood, which is the null; the Wizard carries
## [member AiProfile.chump_threshold]'s 6, so the two sides of the table
## agree about what "close to dead" means.
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
	if reach < game.players[pid].life - profile.crack_back_margin:
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
	search.a_rampage.resize(n)
	for i in n:
		var inst := mine[i]
		search.a_pow[i] = maxi(inst.cur_power, 0)
		search.a_val[i] = Evaluator.permanent_value(inst, profile)
		search.a_id[i] = inst.id
		search.a_can_attack[i] = 1 if candidates.has(inst) else 0
		search.a_forced[i] = 1 if (candidates.has(inst) and _must_attack(inst)) else 0
		# THE FACTORY ANIMATED FOR NOTHING (2026-09-08,
		# [member AiProfile.animates_to_attack]): a body that is a creature
		# only until end of turn is a land again before they swing, so it
		# is no blocker on their turn and holding it home buys nothing.
		# The ply-4 read used to count it, and kept an animated Factory
		# home to block with a body that would not be there.
		search.a_free[i] = 0 if (profile.animates_to_attack
			and _creature_until_end_of_turn(game, inst)) else 1
		search.a_vigilant[i] = 1 if inst.has_keyword(Mtg.Keyword.VIGILANCE) else 0
		search.a_trample[i] = 1 if inst.has_keyword(Mtg.Keyword.TRAMPLE) else 0
		search.a_soak[i] = maxi(inst.cur_toughness - inst.damage, 0)
		search.a_first[i] = 1 if inst.has_keyword(Mtg.Keyword.FIRST_STRIKE) else 0
		search.a_immune[i] = 1 if (inst.cur_indestructible
			or _shieldable(game, inst)) else 0
		# RAMPAGE (CR 702.23, 2026-09-10, [member AiProfile.reads_gaze]):
		# zero unless the knob is on, so the model the null arm searches
		# is byte-identical to the one it always searched.
		search.a_rampage[i] = inst.cur_rampage if profile.reads_gaze else 0
	search.d_pow.resize(m)
	search.d_val.resize(m)
	search.d_free.resize(m)
	search.d_can_attack.resize(m)
	search.d_trample.resize(m)
	search.d_soak.resize(m)
	search.d_first.resize(m)
	search.d_immune.resize(m)
	search.d_rampage.resize(m)
	for j in m:
		var inst := theirs[j]
		search.d_pow[j] = maxi(inst.cur_power, 0)
		search.d_val[j] = Evaluator.permanent_value(inst, profile)
		search.d_free[j] = 0 if inst.tapped else 1
		search.d_can_attack[j] = 1 if _could_attack_next_turn(game, inst) else 0
		search.d_trample[j] = 1 if inst.has_keyword(Mtg.Keyword.TRAMPLE) else 0
		search.d_soak[j] = maxi(inst.cur_toughness - inst.damage, 0)
		search.d_first[j] = 1 if inst.has_keyword(Mtg.Keyword.FIRST_STRIKE) else 0
		search.d_immune[j] = 1 if (inst.cur_indestructible
			or _shieldable(game, inst)) else 0
		search.d_rampage[j] = inst.cur_rampage if profile.reads_gaze else 0
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
	if Evaluator.position_score(game, pid, profile) > 5.0:
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
			# THEIR PUMPS ARE PUBLIC (2026-09-10, [member
			# AiProfile.reads_pumps]): the GROUP half of what [method
			# _attack_risk] asks per creature, and it has to be paid here
			# too or the cohort re-adds the body the per-creature filter
			# refused — the same place [member AiProfile.reads_gaze]'s
			# executioner had to be paid.
			if _dies_to(game, attacker, blocker, Vector2i.ZERO,
					_pump_reach(game, blocker)):
				gain += Evaluator.permanent_value(attacker, profile)
			if _dies_to(game, blocker, attacker):
				gain -= Evaluator.permanent_value(blocker, profile)
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
		# TAPPING INTO AN EXECUTION (2026-09-10, [member
		# AiProfile.reads_gaze]). [method _attack_risk] is the per-creature
		# half of the decision and this is the GROUP half, so the loss has
		# to be paid here too or a flier no blocker can stop is sent for
		# its face damage and dies at the declaration — reproduced that
		# day, a Hypnotic Specter in the graveyard with their life still
		# twenty. The {T} answers before the damage step, so the body
		# lands nothing and trades with nobody: it is subtracted and the
		# loop moves on.
		if profile.reads_gaze and _taps_into_execution(game, attacker, defender):
			value -= Evaluator.permanent_value(attacker, profile)
			continue
		if not blocked.has(attacker.id):
			through += attacker.cur_power
			continue
		var blocker: CardInstance = blocked[attacker.id]
		if attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			through += maxi(
				attacker.cur_power - maxi(blocker.cur_toughness - blocker.damage, 0), 0)
		if _dies_to(game, attacker, blocker, Vector2i.ZERO,
				_pump_reach(game, blocker)):
			value -= Evaluator.permanent_value(attacker, profile)
		if _dies_to(game, blocker, attacker):
			value += Evaluator.permanent_value(blocker, profile)
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
	block_map = _block_choice_once_pumped(game, attackers, free, used) \
		if profile.pumps_to_attack else _block_choice(game, attackers, free, used)
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


## THE BLOCK IS DECLARED AT PRINTED SIZE TOO (2026-09-09,
## [member AiProfile.pumps_to_attack], the second half of the knob).
##
## [method _attack_choice_once_pumped] fixed the ATTACK: a Carrion Ants
## with four Swamps untapped is judged a 4/5 and sent. The BLOCK read
## [member CardInstance.cur_power] and [member CardInstance.cur_toughness]
## and nothing else, all the way down the ladder — so the same swarm,
## with SIX Swamps open and a Craw Wurm coming at it, declared no block
## at all and took six to the face, when a 6/7 eats a 6/4 and walks away.
## Measured before this landed, at 20 life: `declared 0 block(s)`, life
## 20 → 14, six Swamps still untapped. Lower the life to 8 and it was
## worse in the other direction: the panic rung opened, the swarm went
## under the Wurm as a 0/1 chump, and [method _combat_self_pumps] then
## paid four Swamps to rescue a body that had been thrown away — the
## block it would have MADE as a 4/5 was never planned.
##
## The probe is the attack's, mirrored, and deliberately the same code:
## [method _reachable_pumps] over our untapped bodies, the bonuses hung
## on under the journal, the deterministic half of the declaration asked,
## the pumps unmade. Nothing is tapped here — [method _combat_self_pumps]
## buys the breaths one at a time once the blocks are declared, against
## the real board, and it buys them for exactly the reasons the ladder
## planned the block for (the pump wins the trade, or the pump saves the
## body).
##
## THE PANIC LINE MOVES WITH IT, and that is the point rather than a side
## effect. [method _damage_after_value_blocks] runs the same ladder, so
## inside the probe it reads the damage that lands once the blocks we can
## AFFORD have been made: the Wurm above stops being six points through
## and the chump rung never opens. Reading the panic at printed size
## while planning the blocks at reach size is the one combination that
## would be wrong — it would chump AND value-block with the same bodies,
## spending two for one. So both readings are taken inside the probe, on
## one board, which is what [method _block_choice] exists to guarantee.
##
## THE TRAMPLER'S OVERFLOW WAS THE ONE OVER-COUNT THIS LEFT STANDING, and
## it is closed (2026-09-09). The residue used to be counted with
## [member CardInstance.cur_toughness] as the probe made it, so a
## trampler's surplus was measured against a toughness the pilot only
## buys when the pump saves the body — it read the swing as LESS
## dangerous than it turned out to be, which is the direction that gets a
## pilot killed. [method _absorbed_by] now asks the recovery's own
## question of every blocker the trial plans, and the panic line and the
## chump rung's price both go through it.
func _block_choice_once_pumped(game: MtgGame, attackers: Array[CardInstance],
		free: Array[CardInstance], used: Array[int]) -> Dictionary:
	var shares := _pump_shares(game, free)
	_remember_pump_plan(game, shares)
	if shares.is_empty():
		return _block_choice(game, attackers, free, used)
	var owned := game.undo_log == null
	var mark := game.make_mark()
	for id in shares:
		var bonus: Vector2i = Vector2i(shares[id]["bonus"]) * int(shares[id]["count"])
		game.continuous.add_until_eot_pump(int(id), bonus.x, bonus.y)
	game.recalculate()
	var chosen := _block_choice(game, attackers, free, used, shares)
	game.unmake_to(mark)
	if owned:
		game.end_search()
	return chosen


## The deterministic half of the block declaration, read off the board as
## it stands: the panic line, then the ladder.
##
## THE PANIC LINE, and it is asked of what actually LANDS: the ladder is
## run once with no desperation, and the residue decides both whether the
## chump rung opens at all and whether the swing is lethal, which is the
## one case that buys a body at any price.
func _block_choice(game: MtgGame, attackers: Array[CardInstance],
		free: Array[CardInstance], used: Array[int],
		shares: Dictionary = {}) -> Dictionary:
	var me := game.players[pid]
	var through := _damage_after_value_blocks(game, attackers, free, shares)
	var desperate: bool = me.life - through <= profile.chump_threshold
	var lethal_swing := through >= me.life
	return _plan_blocks(game, attackers, free, desperate, used, lethal_swing,
		shares)


## The block plan the tier ladder makes for these attackers: blocker id ->
## attacker id, with the blockers it spent appended to [param used].
##
## SAFE BLOCK, THEN FINISH IT (2026-09-10, [member
## AiProfile.reinforces_blocks]): the ladder is walked once per attacker
## and returns on the first rung that answers, so the finished plan is
## revisited ONCE — [method _reinforce_blocks] — before it is handed back.
## It can only ever ADD a body to an attacker the plan already blocked,
## never move one and never take one away, so every caller of this with
## the knob off gets the declaration it always got.
func _plan_blocks(game: MtgGame, attackers: Array[CardInstance],
		free: Array[CardInstance], desperate: bool,
		used: Array[int], lethal_swing := false,
		shares: Dictionary = {}) -> Dictionary:
	var block_map := {}
	for attacker in attackers:
		var choice := _best_block_for(game, attacker, free, used, desperate,
			lethal_swing, shares)
		for blocker_id in choice:
			block_map[blocker_id] = attacker.id
			used.append(blocker_id)
	_reinforce_blocks(game, attackers, block_map, free, used)
	return block_map


## THE SECOND PASS OVER A FINISHED BLOCK PLAN (2026-09-10, [member
## AiProfile.reinforces_blocks]; `docs/forge/combat.md` P4): an attacker
## met by a band that SURVIVES it and does not KILL it gets more bodies
## until it dies, or gets none at all.
##
## [method _best_block_for] is a ladder that returns on its first
## answering rung, and the free absorb (rung 1.5 — a wall soaks the hit at
## zero cost) sits ABOVE the value trade and the gang. So a Wall of Stone
## on the table blocks alone every time and the rungs below it are never
## reached, however many bodies are standing at home. Reproduced
## 2026-09-10 on two boards:
##
## [codeblock]
## their Serra Angel 4/4    ours: Wall of Swords 3/5, Wall of Swords 3/5
##     _plan_blocks -> ["Wall of Swords"] ; band kills it: false
##       + Wall of Swords -> kills it: true ; that body dies: false
##
## their Craw Wurm 6/4      ours: Wall of Stone 0/8, Water Elemental 5/4
##     _plan_blocks -> ["Wall of Stone"] ; band kills it: false
##       + Water Elemental -> kills it: true ; that body dies: true
## [/codeblock]
##
## The first of those is FREE — two walls that both live through a Serra
## Angel and together deal it exactly four.
##
## THE ORDER IS FORGE'S: safe bodies first, then one that dies to finish
## the job.
## [forge] after fai/AiBlockController.java:795-858
## (reinforceBlockersToKill) at b09a3d3f — with one thing tightened. Forge
## adds its safe blockers whether or not the attacker ends up dead;
## nothing is written into the plan here unless the band it builds
## actually kills, because a body added for nothing is a body exposed to a
## combat trick for nothing (P4's own named risk: a Giant Growth on the
## Wurm).
##
## THE PRICE IS WHAT THE PAIR PUTS AT RISK, and it is rung 3's rule
## (`price <= attacker_value * 1.5`) read off the bodies that actually
## DIE. The survivor the ladder already committed is not spent, so it is
## not charged — but it is re-asked at the size the gang MAKES the
## attacker, so a rampage that turns the pair into two corpses is charged
## for both (CR 702.23, [method _rampage_bonus]). Forge's own bound is
## kept on top of it: the body that dies must be worth strictly less than
## the attacker it kills. That is the same currency the crack-back
## search's own gang defence spends ([member CombatSearch.gang_defence],
## which values a gang as the attacker gained less the bodies lost), so
## the declaration this makes and the declaration that search predicts of
## us do not disagree.
##
## NEVER AGAINST A BODY THAT CANNOT DIE: indestructible, a regeneration
## shield their open mana reaches ([method _shieldable]), or a band that
## already finishes it by a printed line rather than by the arithmetic
## ([member AiProfile.reads_gaze]) — all three are asked before a single
## candidate is looked at.
func _reinforce_blocks(game: MtgGame, attackers: Array[CardInstance],
		block_map: Dictionary, free: Array[CardInstance],
		used: Array[int]) -> void:
	if not profile.reinforces_blocks:
		return
	for attacker in attackers:
		var band := _planned_band(game, block_map, attacker)
		if band.is_empty():
			continue
		if attacker.cur_indestructible or _shieldable(game, attacker):
			continue
		var spent := false
		var finished := _band_kills(game, attacker, band)
		for body in band:
			# The chump and the trade are not what this is for: a band that
			# has already paid a body is not the "safe block" Forge records.
			if _dies_to(game, body, attacker, Vector2i.ZERO,
					_rampage_vector(attacker, band.size())):
				spent = true
			# THE GAZE finishes it without the arithmetic ever agreeing
			# (2026-09-10, [member AiProfile.reads_gaze]): our own Cockatrice
			# is a band that kills, and [method _band_kills] cannot see it.
			if _dies_to(game, attacker, body):
				finished = true
		if spent or finished:
			continue
		var legal := _reinforcements_for(game, attacker, free, used)
		if legal.is_empty():
			continue
		for body in _reinforcement_band(game, attacker, band, legal):
			block_map[body.id] = attacker.id
			used.append(body.id)


## The bodies [param block_map] puts in front of [param attacker], in
## battlefield order.
func _planned_band(game: MtgGame, block_map: Dictionary,
		attacker: CardInstance) -> Array[CardInstance]:
	var band: Array[CardInstance] = []
	for blocker_id in block_map:
		if int(block_map[blocker_id]) != attacker.id:
			continue
		var body := game.find_instance(int(blocker_id))
		if body != null and body.zone == Mtg.Zone.BATTLEFIELD:
			band.append(body)
	return band


## RAMPAGE as a [Vector2i] the damage predicates already read (CR 702.23):
## what [param attacker] is wearing once [param blockers] bodies are on
## it. Zero at every rung [member AiProfile.reads_gaze] is off at, and for
## every creature in this pool that does not print the keyword.
func _rampage_vector(attacker: CardInstance, blockers: int) -> Vector2i:
	var bonus := _rampage_bonus(attacker, blockers)
	return Vector2i(bonus, bonus)


## The still-free bodies that may legally be added to [param attacker]'s
## block, cheapest first (ties by instance id, so the choice is
## deterministic).
func _reinforcements_for(game: MtgGame, attacker: CardInstance,
		free: Array[CardInstance], used: Array[int]) -> Array[CardInstance]:
	var legal: Array[CardInstance] = []
	for inst in free:
		if used.has(inst.id):
			continue
		if CombatState.block_illegality(game, inst, attacker, pid) != "":
			continue
		legal.append(inst)
	legal.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		var av := Evaluator.permanent_value(a, profile)
		var bv := Evaluator.permanent_value(b, profile)
		if absf(av - bv) > 1e-6:
			return av < bv
		return a.id < b.id)
	return legal


## The bodies to ADD to [param band] so that it finishes [param attacker],
## or an empty array when no set of them is worth it.
##
## Safe bodies first and free of charge — they live through the attacker
## at the size the gang makes it, so nothing is spent — and then, only if
## the safe ones fall short, ONE body that dies to close the kill exactly.
## That last one is what the price rule is for.
func _reinforcement_band(game: MtgGame, attacker: CardInstance,
		band: Array[CardInstance],
		legal: Array[CardInstance]) -> Array[CardInstance]:
	var trial: Array[CardInstance] = band.duplicate()
	var added: Array[CardInstance] = []
	var spare: Array[CardInstance] = []
	for body in legal:
		var grown := _rampage_vector(attacker, trial.size() + 1)
		if _dies_to(game, body, attacker, Vector2i.ZERO, grown) \
				or _damage_from(body, attacker) <= 0:
			spare.append(body)
			continue
		trial.append(body)
		added.append(body)
		if _band_kills(game, attacker, trial):
			return added
	# THE ONE THAT DIES TO FINISH IT. Forge's own clause: the body has to
	# CLOSE the kill (the band without it does not, the band with it does)
	# and be worth strictly less than the prize. The safe bodies gathered
	# above ride along only because this one finishes what they started.
	var attacker_value := Evaluator.permanent_value(attacker, profile)
	for body in spare:
		if Evaluator.permanent_value(body, profile) >= attacker_value:
			continue
		var closed: Array[CardInstance] = trial.duplicate()
		closed.append(body)
		if not _band_kills(game, attacker, closed):
			continue
		if _reinforcement_price(game, attacker, closed) > attacker_value * 1.5:
			continue
		added.append(body)
		return added
	return []


## What a block by [param band] on [param attacker] would COST us: the
## worth of every body of the band the attacker kills, asked at the size
## the gang makes it (CR 702.23). The rung 3 price rule is read against
## this, so a survivor is free and a rampage that kills the survivor too
## is charged for both bodies.
func _reinforcement_price(game: MtgGame, attacker: CardInstance,
		band: Array[CardInstance]) -> float:
	var grown := _rampage_vector(attacker, band.size())
	var price := 0.0
	for body in band:
		if _dies_to(game, body, attacker, Vector2i.ZERO, grown):
			price += Evaluator.permanent_value(body, profile)
	return price


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
		free: Array[CardInstance], shares: Dictionary = {}) -> int:
	var trial_used: Array[int] = []
	var trial := _plan_blocks(game, attackers, free, false, trial_used, false,
		shares)
	var through := 0
	for attacker in attackers:
		# The whole band first, because what each body of a gang absorbs
		# depends on whether the gang KILLS (2026-09-09, [method
		# _absorbed_by]) and not on what it could do alone.
		var band: Array[CardInstance] = []
		for blocker_id in trial:
			if int(trial[blocker_id]) != attacker.id:
				continue
			var blocker := game.find_instance(int(blocker_id))
			if blocker != null:
				band.append(blocker)
		var stopped := 0
		for blocker in band:
			stopped += _absorbed_by(game, blocker, attacker, shares, band)
		if stopped == 0:
			through += attacker.cur_power
		elif attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			# RAMPAGE feeds the trampler too (2026-09-10): the surplus is
			# measured against the size the gang MAKES it, which is the
			# same direction the trampler's overflow was fixed in — under-
			# reading lethal is what gets a pilot killed.
			through += maxi(attacker.cur_power
				+ _rampage_bonus(attacker, band.size()) - stopped, 0)
	return through


## THE TRAMPLER'S OVERFLOW, PRICED AGAINST THE TOUGHNESS THE PILOT WILL
## ACTUALLY HAVE BOUGHT (2026-09-09, [member AiProfile.pumps_to_attack]).
## Lethal damage [param blocker] takes off [param attacker]'s assignment
## before the rest of it tramples through (CR 702.19b: the attacker must
## assign lethal damage to each blocker, and lethal damage is toughness
## less damage already marked).
##
## WHY IT IS NOT SIMPLY THE BLOCKER'S TOUGHNESS ANY MORE. The block
## declaration is made inside [method _block_choice_once_pumped], on a
## board where every one of our bodies is already wearing the WHOLE
## bonus its share of the open mana could reach — that is the point of
## the probe. [method _combat_self_pumps] then buys the breaths for real,
## one at a time, and it buys a TOUGHNESS bonus only when the bonus saves
## the body and a POWER bonus only when it wins the trade. So the two do
## not have to agree, and against a trampler that disagreement is damage
## to the face: measured on 2026-09-09, a Carrion Ants behind six Swamps
## and a Scathe Zombies ganging a Force of Nature read the swing as ZERO
## through (a 6/7 and a 2/2 stop eight) and took FIVE, because neither
## body kills an 8/8 on its own, so the recovery bought nothing at all
## and the swarm blocked at 0/1 with six Swamps still untapped. The panic
## line ([method _damage_after_value_blocks]) and the chump rung's price
## ([method _best_block_for]) were both reading it, and under-reading
## lethal is the dangerous direction: the pilot declines to chump and
## dies.
##
## THE READING, and it is the recovery's own ladder asked one step early:
##
##  * no share, or a share with no toughness in it — the body is what it
##    looks like;
##  * the probe's size SAVES it (its live toughness beats what is coming)
##    — the recovery buys exactly enough to save it, and a body that
##    lives absorbs the whole assignment anyway, so the probe's number is
##    the honest one;
##  * otherwise the body dies whatever it does, so the recovery buys only
##    the breaths that KILL what it is in front of — the fewest that do,
##    counted here the way [method _combat_self_pumps] counts them — and
##    nothing at all when nothing it can reach kills.
##
## AND THE KILL IS THE GANG'S (2026-09-09, the fourth pass). The one
## thing this reading left standing was that a body in a GANG was asked
## whether it kills the attacker ALONE — so two bodies that finish a
## trampler between them were each priced at no breath. It errs safe as a
## READING, but it was mirroring a recovery that was itself wrong: the
## block ladder declares a gang on the probe's sizes and
## [method _combat_self_pumps] then bought nothing for it. Both now ask
## [method _band_kills] — do these bodies TOGETHER finish it — and the
## breaths this routine counts are the breaths the recovery buys.
##
## [param band] is the bodies blocking [param attacker] alongside
## [param blocker] in the block being priced, and it comes from the
## caller because the block is still a PLAN here and the engine has not
## been told of it: [method _damage_after_value_blocks] has the trial map,
## and the chump rung of [method _best_block_for] is throwing one body, so
## it passes none and the reading is the alone one it always was. Inside
## the probe every mate is already wearing its whole share, so only the
## body under test carries a delta.
func _absorbed_by(game: MtgGame, blocker: CardInstance,
		attacker: CardInstance, shares: Dictionary,
		band: Array[CardInstance] = []) -> int:
	var live := maxi(blocker.cur_toughness - blocker.damage, 0)
	var share: Dictionary = shares.get(blocker.id, {})
	if share.is_empty():
		return live
	var bonus: Vector2i = share["bonus"]
	var count: int = share["count"]
	if bonus.y <= 0 or count <= 0:
		return live
	if live > _damage_from(attacker, blocker):
		return live
	var gang: Array[CardInstance] = []
	gang.assign(band)
	if gang.is_empty():
		gang.append(blocker)
	# The breaths are counted DOWN from the probe's size, because the
	# probe's size is what the board is wearing right now: a body asked
	# about at `bought` breaths is the one in front of us less the rest.
	for bought in count + 1:
		if _band_kills(game, attacker, gang,
				{blocker.id: bonus * (bought - count)}):
			return maxi(live - bonus.y * (count - bought), 0)
	return maxi(live - bonus.y * count, 0)


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
		lethal_swing := false, shares: Dictionary = {}) -> Array[int]:
	var legal: Array[CardInstance] = []
	for inst in free:
		if used.has(inst.id):
			continue
		if CombatState.block_illegality(game, inst, attacker, pid) == "":
			legal.append(inst)
	if legal.is_empty():
		return []
	var attacker_value := Evaluator.permanent_value(attacker, profile)
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
				and Evaluator.permanent_value(blocker, profile) <= attacker_value + 0.5:
			return [blocker.id]
	# 3) Gang up: two blockers whose combined damage kills it, if their
	#    combined worth isn't wildly above the prize.
	if not _shieldable(game, attacker) and not attacker.cur_indestructible:
		# THEIR PUMPS ARE PUBLIC (2026-09-10, [member
		# AiProfile.reads_pumps]): the gang rung asks its own kill
		# question rather than [method _dies_to]'s, so the body it prices
		# is the one their open mana can put in front of it.
		var grows := _pump_reach(game, attacker)
		for i in legal.size():
			for j in range(i + 1, legal.size()):
				if _damage_from(legal[i], attacker, Vector2i.ZERO, grows) \
						+ _damage_from(legal[j], attacker, Vector2i.ZERO, grows) \
						>= attacker.cur_toughness - attacker.damage \
							+ _rampage_bonus(attacker, 2) + grows.y:
					var price := Evaluator.permanent_value(legal[i], profile) \
						+ Evaluator.permanent_value(legal[j], profile)
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
			if Evaluator.permanent_value(blocker, profile) < Evaluator.permanent_value(cheapest, profile):
				cheapest = blocker
		if not lethal_swing:
			var stopped := attacker.cur_power
			if tramples:
				stopped = mini(stopped,
					_absorbed_by(game, cheapest, attacker, shares))
			if _face_damage_value(game, stopped, pid) \
					< Evaluator.permanent_value(cheapest, profile):
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
		_excluded_sources(game))


## The untapped mana sources available right now — [method
## ManaPlanner.sources] for this agent's seat. Built ONCE per decision and
## passed to [method _plan_taps_from], because one "what should I cast?"
## pass plans a cost for every card in hand.
func _mana_sources(game: MtgGame) -> Array:
	return ManaPlanner.sources(game, pid, _excluded_sources(game),
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


## THE ATTACKER THAT IS ALSO A LAND, left out of the plan
## ([member AiProfile.animates_to_attack], 2026-09-08). A Mishra's
## Factory animated in our first main phase was paid for as the attack
## it enables ([method _animation_value]) — and to the planner it was
## still a land, the cheapest source on the table, so the next thing the
## pilot paid for (a Disrupting Scepter, three mana) tapped the body it
## had just bought and the declaration found it tapped. Twenty-one of the
## twenty-nine animations that went nowhere in 150 instrumented games
## were this, not the attack code (docs/ROADMAP.md, "The Deck, third
## pass"). So until the attack is declared, a body that is a creature
## only until end of turn and could still attack is not a mana source;
## once combat is over it taps like any land, and on their turn nothing
## is animated. Same shape as [method _pain_excluded], and unioned with
## it by [method _excluded_sources].
func _attackers_excluded(game: MtgGame) -> Dictionary:
	var out: Dictionary = {}
	if not profile.animates_to_attack or game.active_player != pid \
			or game.current_step() > Mtg.Step.COMBAT_BEGIN:
		return out
	for inst in game.players[pid].battlefield:
		if inst.tapped or inst.summoning_sick or inst.cur_mana_abilities.is_empty():
			continue
		if inst.is_creature() and _creature_until_end_of_turn(game, inst):
			out[inst.id] = true
	return out


## Every source the planner is to leave alone for this seat: the tap that
## would kill us ([method _pain_excluded]) and the body animated to attack
## ([method _attackers_excluded]).
func _excluded_sources(game: MtgGame) -> Dictionary:
	var out := _pain_excluded(game)
	out.merge(_attackers_excluded(game))
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
		_excluded_sources(game))


func _cost_is_free(cost: ManaCost) -> bool:
	return ManaPlanner.cost_is_free(cost)


## [param sources]: a pre-built mana-source list (see [method _mana_sources]).
func _max_affordable_x(game: MtgGame, cost: ManaCost, extra := 0,
		sources: Array = [], x_color := 0, usage_keys: Array = []) -> int:
	return ManaPlanner.max_affordable_x(game, pid, cost, extra, sources,
		x_color, usage_keys, _excluded_sources(game))


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
			# THE WRONG SIDE OF THE TABLE (2026-09-08, AiProfile.spares_own).
			# `rest` is the other side's permanents, and for a harmful
			# effect the other side is OURS: once their board ran out of
			# creatures, a Winter Blast for four was filled out with our own
			# and priced as if that cost nothing ([method _cast_value]
			# credits an enemy victim and charges nothing for ours). A
			# permanent of ours is offered to a harmful slot only when
			# giving it up is worth less than nothing to us — a liability
			# by the evaluator's reading, never by a card's name — and
			# otherwise the slot stays empty, which the engine's refusal
			# turns into "not now" ([method MtgGame.cast_refusal] asks for
			# the count before a land is tapped).
			# THE LIABILITY (2026-09-09, AiProfile.prices_liabilities) is
			# what opens that door: _own_value may now answer below zero,
			# and a slot may take a permanent of ours when it does — but
			# only a slot that RELIEVES it. Tapping our own dead Mana
			# Vault leaves it dead and tapped ([method _relieves]).
			if harmful and found != null and owner_pid == pid \
					and profile.spares_own \
					and not _worth_giving_up(game, source, effect, found, x_value):
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
	#
	# It is also a guess about the FILTER, and the filter can be about
	# something other than the side of the table: Detonate's "with mana
	# value X" (TargetSpec.source_filter reading [method MtgGame.casting_x])
	# emptied their side for want of an artifact of the right cost, this
	# fallback shopped ours, and the AI Detonated its own Mana Vault
	# (2026-09-08). The reader has a row for Detonate now; the general
	# rule — our permanents are not offered to a harmful reading unless
	# the evaluator prices them below zero, AiProfile.spares_own — lives
	# where slots are padded ([method _extra_targets]). Here it cannot,
	# because the harmful reading is the very thing this pool doubts, and
	# a filter that says "you control" is still the better authority.
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
			# ...and don't hang an aura on a creature it gives nothing
			# to — a keyword it has, or an attacker's gift (vigilance,
			# fear, landwalk) to a Wall: the owner's Eternal Warrior on
			# a Wall of Swords (2026-09-08). See EffectIntent.aura_fits.
			if not harmful and profile.fits_auras and source.data.is_aura() \
					and not EffectIntent.aura_fits(source.data, inst):
				continue
			# Their permanents by what taking them costs THEM (a Stone
			# Rain on the only Swamp, not the fourth Mountain); ours by
			# the flat board scale.
			var value := _victim_value(game, inst) if harmful \
				else Evaluator.permanent_value(inst, profile)
			if value > best_value:
				best = inst
				best_value = value
		if best != null:
			break
	if best != null:
		return TargetRef.card(best)
	# THE LIABILITY (2026-09-09, AiProfile.prices_liabilities), and the
	# LAST thing this picker tries, because their board comes first: with
	# nothing of theirs worth taking, is one of OURS worth giving up? A
	# permanent the evaluator prices below zero that this spell would
	# actually take off the table ([method _worth_giving_up]) — the tapped
	# Mana Vault we cannot pay {4} for, and the Detonate in hand. Off (and
	# before 2026-09-09) this block finds nothing, because nothing prices
	# below zero, so the picker could never name one of ours for a KNOWN
	# harmful effect and the owner's Detonate had to come through the
	# unknown-effect fallback above.
	if harmful and profile.prices_liabilities:
		var relief := 0.0
		for inst in game.players[pid].battlefield:
			var ref := TargetRef.card(inst)
			if not game.target_legal_at(spec, ref, source, x_value, earlier):
				continue
			if _already_chosen(ref, earlier):
				continue
			if not _worth_giving_up(game, source, effect, inst, x_value):
				continue
			var value := -_own_value(game, inst)
			if value > relief:
				best = inst
				relief = value
		if best != null:
			return TargetRef.card(best)
	# Harmful any-target with no creature worth hitting: go to the face if
	# the spec allows players.
	if harmful and spec.kind == TargetSpec.Kind.ANY \
			and game.target_legal_at(spec, TargetRef.player(opponent), source,
				x_value, earlier):
		return TargetRef.player(opponent)
	return null


## THE ONE DOOR (2026-09-09, [member AiProfile.prices_liabilities] and
## [member AiProfile.spares_own]): may this harmful effect of ours be
## pointed at [param mine], a permanent of our OWN?
##
## Two things have to be true and neither is a card's name. The evaluator
## has to price giving it up BELOW ZERO ([method _own_value] — the
## liability reading, off before 2026-09-09 and off on the null arm, where
## nothing ever prices below zero and this answers false for everything).
## And the effect has to actually RELIEVE us of it: a destroy, an exile or
## a bounce takes the permanent off the table, and damage does when it
## kills; a TAP does not — our dead Mana Vault is already tapped, and
## tapping it again is the padding this rule was written against.
func _worth_giving_up(game: MtgGame, source: CardInstance, effect: EffectBase,
		mine: CardInstance, x_value := 0) -> bool:
	if mine == null or effect == null:
		return false
	if _own_value(game, mine) >= 0.0:
		return false
	var intent := EffectIntent.read([effect], source.data.card_name)
	if intent.removes or intent.bounces:
		return true
	return intent.damage_at(x_value) > 0 and mine.is_creature() \
		and intent.kills(mine, x_value)


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
	return Evaluator.permanent_value(inst, profile)


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
		var va := Evaluator.permanent_value(a, profile)
		var vb := Evaluator.permanent_value(b, profile)
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
		if Evaluator.card_value(inst.data) > Evaluator.permanent_value(victim, profile):
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

## THE OPENING HAND. Behind [member AiProfile.mulligans] the seat judges
## its hand — lands against a keep range, then whether those lands cast
## anything ([AiMulligan]); with the knob off it throws back only the
## hand with no land or nothing but land, the plain rule every agent has.
## Asked again after every redraw by whoever runs the opening (the
## OpeningWindow at the table, the Deck Lab's `--mulligan on`), and
## answering false is the keep.
func choose_mulligan(game: MtgGame, p_pid: int) -> bool:
	if profile.mulligans:
		return AiMulligan.wants_mulligan(game, p_pid)
	return super(game, p_pid)


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
		var worth := Evaluator.permanent_value(blocker, profile)
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
## or a Sacrifice spell), or a TRIBUTE ([method _tribute_ask]: The Abyss,
## a Lord of the Pit, a Mana Vortex — the same loss without the cost
## flag; [member AiProfile.feeds_worst]), when the LEAST valuable goes.
##
## And unless it is a LIBRARY SEARCH read for the turn it is made in
## ([member AiProfile.tutors_for_the_turn], [method _tutor_pick]), which
## is the one gain ask that has an order rather than a maximum.
func answer_card(game: MtgGame, p_pid: int, candidates: Array[CardInstance],
		prompt: String) -> CardInstance:
	var asked := current_choice()
	if asked != null and (asked.adverse or asked.ordered) \
			and not candidates.is_empty():
		return candidates[0]
	var paying := asked != null and asked.is_cost
	var tribute := not paying and profile.feeds_worst \
		and _tribute_ask(p_pid, candidates, prompt)
	if not paying and not tribute and p_pid == pid \
			and profile.tutors_for_the_turn and _tutor_ask(p_pid, candidates):
		return _tutor_pick(game, candidates)
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
		elif tribute:
			if _tribute_value(game, inst) < _tribute_value(game, best):
				best = inst
		elif Evaluator.card_value(inst.data) > Evaluator.card_value(best.data):
			best = inst
	return best


## THE TRIBUTE (2026-09-08, AiProfile.feeds_worst): is this card ask a
## LOSS for the seat answering it — one of its own to sacrifice, to be
## destroyed, or to discard — rather than the gain every other card ask
## is (a tutor, a Regrowth, a Reanimate)? Read off the two things every
## such ask shares: the candidates are all the seat's own, and the line
## it is asked with says what happens to the one it names. The words are
## [constant TRIBUTE_WORDS], the vocabulary of the pool's own prompts
## ("Sacrifice a creature to Lord of the Pit", "The Abyss: choose a
## nonartifact creature to be destroyed", "Select card drawn this turn
## to discard."); an ask an OPPONENT answers about our cards (Demonic
## Hordes' "Choose a land for X's controller to sacrifice") fails the
## first test and stays the gain it is for them.
func _tribute_ask(p_pid: int, candidates: Array[CardInstance], prompt: String) -> bool:
	if candidates.is_empty():
		return false
	var loss := false
	for word in TRIBUTE_WORDS:
		if prompt.findn(word) >= 0:
			loss = true
			break
	if not loss:
		return false
	for inst in candidates:
		if inst.controller_id != p_pid:
			return false
	return true


## The words a card ask uses when the card named is lost by the seat
## naming it. Matched case-blind, anywhere in the prompt.
const TRIBUTE_WORDS: Array[String] = ["sacrifice", "destroy", "discard", "bury"]


## What a tribute costs the seat: a permanent by [method _own_value] (a
## land's scarcity and colour counted, the way a cost's sacrifice prices
## it), a card in hand by [method Evaluator.card_value].
func _tribute_value(game: MtgGame, inst: CardInstance) -> float:
	if inst.zone == Mtg.Zone.BATTLEFIELD:
		return _own_value(game, inst)
	return Evaluator.card_value(inst.data)


# ---------------------------------------------------------- the tutor's pick --

## THE TUTOR (2026-09-10, AiProfile.tutors_for_the_turn): is this card ask
## a search of OUR OWN LIBRARY — the one gain ask whose answer is an
## ORDER rather than a maximum?
##
## Structural, like [method _tribute_ask] and for the same reason: no card
## is named and no prompt is read. Every candidate sits in the library,
## which is true of a Demonic Tutor's whole deck, an Untamed Wilds' basic
## lands, a Land Tax's three, a Transmute Artifact's artifacts and an
## Aladdin's Lamp's top X — and of nothing else the pilot is asked. The
## graveyard's own gain asks (Regrowth, Recall) are not here: they go
## through [method _choose_targets], which has had its own land rule since
## the second pass. An ask ordered by the card ([member
## PlayerChoice.ordered] — Natural Selection's restack) never reaches this,
## having been answered above.
func _tutor_ask(p_pid: int, candidates: Array[CardInstance]) -> bool:
	if candidates.is_empty():
		return false
	for inst in candidates:
		if inst.zone != Mtg.Zone.LIBRARY or inst.controller_id != p_pid:
			return false
	return true


## What the tutor takes, in the order the casting note ranks it
## (docs/forge/casting.md P9; [forge] `ChangeZoneAi.java:1641-1645` and
## `:630-656`, commit `b09a3d3f`, read for the ORDER and not for its
## numbers — its key-card list is a deck resource file this project does
## not have and would not read, and step 3 stands in its place).
##
## 1. A LAND WHEN SHORT. [method _land_light] already says what short is —
##    fewer than a working four, or fewer than the hand's biggest spell
##    wants — and the fetch is only the answer when the land drop is not
##    already covered from hand and nothing we hold is castable at all.
##    Forge's three clauses exactly; the third is asked of the mana our
##    BOARD makes ([method _mana_permanents]) and not of what is untapped,
##    because at the moment a search resolves the lands that paid for it
##    are tapped and "nothing castable" would be true of every board.
##    Which land is [method _tutor_land]'s.
## 2. WHAT NEXT TURN CAN CAST — the board's sources plus the one land the
##    turn allows. The candidates that fit, if any: a Hypnotic Specter on
##    three lands rather than the Mahamoti Djinn four turns away. No turn
##    number gates it: late in a game the filter admits everything and the
##    step costs nothing, which is Forge's `turn <= 3` without the number.
## 3. THE CARD WORTH MOST ON THIS BOARD, [method _tutor_worth], which is
##    the whole difference between fetching for the game and fetching for
##    the turn.
func _tutor_pick(game: MtgGame, candidates: Array[CardInstance]) -> CardInstance:
	var sources := _mana_permanents(game)
	if _land_light(game) and not _holding_a_land(game) \
			and not _castable_within(game, sources):
		var land := _tutor_land(game, candidates)
		if land != null:
			return land
	var shortlist: Array[CardInstance] = []
	for inst in candidates:
		if inst.data.cost.mana_value() <= sources + 1:
			shortlist.append(inst)
	if shortlist.is_empty():
		shortlist = candidates
	var best: CardInstance = null
	var best_worth := 0.0
	for inst in shortlist:
		var worth := _tutor_worth(game, inst)
		if best == null or worth > best_worth:
			best = inst
			best_worth = worth
	return best


## How many permanents of ours make mana — tapped ones counted, because
## they untap (CR 502.1) and this is a question about turns rather than
## about the pool. Forge's `manaSources`; next turn's reach is this plus
## the one land the turn allows.
func _mana_permanents(game: MtgGame) -> int:
	var sources := 0
	for inst in game.players[pid].battlefield:
		if not inst.cur_mana_abilities.is_empty():
			sources += 1
	return sources


## Is a land already in hand? The drop the fetch would buy is covered.
func _holding_a_land(game: MtgGame) -> bool:
	for inst in game.players[pid].hand:
		if inst.is_land():
			return true
	return false


## Does the hand hold a spell [param reach] mana can pay for? Read off the
## printed mana value alone — the colours are what [method _tutor_land]
## fixes, and a hand of coloured cards with no land to cast them is
## exactly the board the land fetch exists for.
func _castable_within(game: MtgGame, reach: int) -> bool:
	for inst in game.players[pid].hand:
		if not inst.is_land() and inst.data.cost.mana_value() <= reach:
			return true
	return false


## Which land the fetch takes: the one that makes the colour the hand is
## missing most ([method _colour_shortfall], the same reading [method
## _try_play_land] chooses the drop by), and among equals the one worth
## most to us ([method Evaluator.land_value]: scarcity, a dual, the only
## source of a colour, a land that does more than make mana). Null when
## the search offers no land at all.
func _tutor_land(game: MtgGame, candidates: Array[CardInstance]) -> CardInstance:
	var shortfall := _colour_shortfall(game)
	var best: CardInstance = null
	var best_fixes := 0.0
	var best_worth := 0.0
	for inst in candidates:
		if not inst.is_land():
			continue
		var fixes := 0.0
		for ability in inst.data.mana_abilities:
			for pair in ability.produces:
				fixes = maxf(fixes, float(shortfall.get(int(pair[0]), 0)))
		var worth := Evaluator.land_value(game, inst)
		if best == null or fixes > best_fixes \
				or (fixes == best_fixes and worth > best_worth):
			best = inst
			best_fixes = fixes
			best_worth = worth
	return best


## What a fetched card is worth ON THIS BOARD rather than on its own.
##
## Two shapes have a board reading in this file already and both are used
## here, which is why the third step of P9 costs nothing new: a SWEEPER is
## worth what the sweep would swing ([method _sweep_value] — a Wrath is
## the best card in the deck against four creatures and the worst against
## none), and a LEVELLER what each side would lose ([method _level_value],
## under the knob that owns it). Everything else keeps its printed worth
## ([method _card_value], which prices the pool's `*/*` creatures by what
## they cost). It is the same pair of readings [method _size_and_aim]
## opens with, so the tutor and the caster cannot disagree about which
## card the board wants.
##
## The leveller's reading is exact at this moment and not by luck: the
## search is resolving, so the tutor itself has left the hand and the
## fetched card has not arrived — which is the hand size [method
## _level_value] would see with the leveller in hand and its own copy
## discounted.
##
## WHAT IS NOT READ, and it is P9's own third line: "a Moat when their
## creatures are ground-bound" and "the finisher when the board is ours"
## have no reading in this engine to borrow, and inventing one for a
## fetch would be a card-shaped rule in the one place the ladder forbids
## it. Named in docs/ai-difficulty.md §5.
func _tutor_worth(game: MtgGame, inst: CardInstance) -> float:
	var intent := _intent_of(inst)
	if intent.sweeper != null and not inst.data.is_modal():
		return _sweep_value(game, intent.sweeper, 0)
	if intent.levels and profile.levels_boards and not inst.data.is_modal():
		return _level_value(game, inst)
	return _card_value(inst.data)
