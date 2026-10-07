extends RefCounted
## Pack 9 (the Tempest block): the fair AI's readings of the block's new
## shapes, in the shape of the other expansion modules — static functions
## that return null when their shape is not involved or their gate is off
## (the null arm: the pilot plays exactly as it did before Pack 9), `{}`
## for "no, not now", or `{value, targets}`; the action arms answer the
## action line or "".
##
## Information: the public board, the stack and the pilot's own hand only
## (docs/fair-play.md). Shape, not name: a licid is recognised by its
## effect's declared role ([member EffectBase.ai_role] `&"licid"`, set by
## [method CardData.as_licid]), a shadow trick by the keyword its typed
## [PumpEffect] grants or its [LoseAbilityEffect] takes, Volrath's Curse by
## the ignore its card declares ([member CardData.ignore_effect_sacrifice]),
## never by a card name.
##
## THE GATES are the profile's existing capabilities (docs/ai-difficulty.md
## §1): [member AiProfile.forecasts_tactics] for every reading here; the
## response arms run only where [method AiPlayer._respond_action] runs
## ([member AiProfile.holds_instants]).
##
## Reached through the Mirage module (engine/ai/mirage_tactics.gd): its
## activation arm ([method option]), its response arm ([method respond]),
## its end-step arm ([method end_step_action]) and its main-phase arm
## ([method main_action]) ask this module first.
##
## THE LICID (engine package E3; this module's AI stage, 2026-10-06).
## "{c}, {T}: This creature … becomes an Aura enchantment with enchant
## creature. Attach it to target creature. You may pay {e} to end this
## effect."
##  * ON OUR CREATURE (E3's minimum): the licid gives up its body to dress
##    one of OUR creatures — worth it when the dressed creature makes THIS
##    TURN'S ATTACK better by more than the main phase's bar, asked of the
##    pilot's own attack planner under the search journal ([method
##    attack_worth] against [method attack_worth_dressed]).
##  * ON THEIR CREATURE: the Aura halves that hurt a host — "can't attack"
##    (THEIR attack is worth less: [method their_attack_worth], the
##    mirror of [method attack_worth]), "can't block" (our attack grows),
##    "deals N damage to that player" (a recurring toll, [method
##    toll_value]) and "you control enchanted creature" (the steal) — are
##    priced on the same journal, the denial counted over the turns the
##    Aura stays ([constant AURA_TURNS], the toll's own horizon), less
##    half the body the licid gives up (its end cost buys the body back).
##  * ENDING THE EFFECT (CR 116.2c, the special action [method
##    MtgGame.end_licid_effect]): when the host is about to leave — their
##    removal on the stack names it or the licid, or it dies in the combat
##    damage about to be dealt — the licid becomes its creature self in
##    response and survives ([method licid_save]). A licid stealing a host
##    that is not about to leave is never ended.
##
## VOLRATH'S CURSE (CR 116.2d, [method MtgGame.ignore_static_effect]): the
## sacrifice that ignores it this turn is taken only when the attack it
## frees is worth more than the cheapest permanent we would give up, or
## wins the game ([method curse_action]).
##
## SPIKES (B3; CR 602.2b — the counter is a cost): a "+1/+1 counter from
## this creature" ability spends the body itself, so the shared scorer
## never reaches it ([method option] answers `{}`); a counter is spent when
## the Spike is about to die anyway ([method spike_save]: a regeneration
## shield, a counter moved, a token, life — in a declared combat only the
## counters its kill does not need, priced on the game's damage forecast,
## [method spike_combat_option]) and at their end step to move a counter
## from a Spike their board blocks onto an attacker it cannot ([method
## spike_shift]).
##
## THE BLOCK'S ROLES ([method option] and the moments of [method
## respond] / [method end_step_action]): each card module declares the role
## its effect plays and an arm here reads it — the Keepers' condition slot
## (never paid for unmet), Starke's donating removal, Cursed Scroll's hit
## chance, Bounty Hunter's mark, a land from hand, Essence Bottle and
## Torture Chamber's counters, the steals (Helm of Possession, Rootwater
## Matriarch), Jinxed Idol's gift, Trumpeting Armodon's lure, Duct
## Crawler's "can't block it", Bullwhip's ping, Samite Blessing's shield,
## Silver Wyvern's retarget, Magnetic Web's counters, Hermit Druid's dig,
## a shrink on a blocker; and from the response window the en-Kor
## redirect, Soltari Guerrillas' damage, Cold Storage and Maddening Imp.
##
## SHADOW TRICKS (engine package E1, CR 702.28, 506.4): a shadow grant on a
## target creature (Shadow Rift, Dauthi Embrace, Dauthi Trapper) is an
## evasion trick for OUR attacker after attackers are declared and before
## blocks — never later, when it changes nothing (CR 506.4); a shadow loss
## (Reality Anchor) takes it from THEIR attacker before blocks when our
## blockers then stop damage or kill it ([method evasion_trick], [method
## deny_evasion]). Both are held out of the main phase ([method
## spell_choice]).

const LICID_ROLE := &"licid"
const HOMELANDS_TACTICS := preload("res://engine/ai/homelands_tactics.gd")


# ======================================================= the activations --

## The activation arm, asked first by [method MirageTactics.option] (which
## every activation asks through [method AiPlayer._ability_option]).
static func option(g: MtgGame, pilot, s: CardInstance, index: int,
		window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty():
		return null
	var e: EffectBase = a.effects[0]
	if e.ai_role == LICID_ROLE:
		return licid_option(g, pilot, s, index, window)
	# A shadow grant or loss on a TARGET is a combat trick with exactly one
	# moment, read by [method respond]; no other arm may spend it.
	if shadow_shift(e) != 0:
		return {}
	# A Spike's "remove a +1/+1 counter from this creature" ability: the
	# counter IS the body, so only the moments that price it spend one
	# ([method spike_save], [method spike_shift]).
	if is_spike_ability(a):
		return {}
	match e.ai_role:
		&"keeper_condition":
			return keeper_option(g, pilot, s, a, window)
		&"destroy_donates_self":
			return donating_removal_option(g, pilot, s, a, window)
		&"named_reveal_damage":
			return scroll_option(g, pilot, s, a, window)
		&"bounty_mark":
			return bounty_option(g, pilot, s, a, window)
		&"land_from_hand":
			return land_from_hand_option(g, pilot, s, window)
		&"charge_counter":
			return charge_option(g, pilot, s, a, window)
		&"cash_counters_life":
			return drink_option(g, pilot, s, a, window)
		&"cash_counters_damage":
			return rack_option(g, pilot, s, a, window)
		&"steal_while_tapped", &"steal_while_enchanted":
			return steal_option(g, pilot, s, a, window)
		&"donate_self":
			return donate_option(g, pilot, s, a, window)
		&"lure_target":
			return lure_option(g, pilot, s, a, window)
		&"cant_block_source":
			return unblockable_by_option(g, pilot, s, a, window)
		&"ping_and_force_attack":
			return ping_option(g, pilot, s, a, window)
		&"source_shield":
			return blessing_option(g, pilot, s, a, window)
		&"retarget_from_self":
			return wyvern_option(g, pilot, s, a, window)
		&"magnet_counter":
			return magnet_option(g, pilot, s, a, window)
		&"dig_for_basic_land":
			return dig_land_option(g, pilot, s, window)
		&"stash_own_creature", &"release_stash", &"redirect_point_to_own", \
				&"combat_damage_to_creature", &"forces_attacks", &"sacrifice_mill":
			return {}   # the moments' (respond / end step), or not played
	if shrinks_blocker(e):
		return shrink_blocker_option(g, pilot, s, a, window)
	var raised: Variant = reanimate_option(g, pilot, s, a, window)
	if raised != null:
		return raised
	return null


# ================================================================ licids --

## The licid arm: our own main phase before combat, the stack empty; the
## host among our creatures whose dressing gains the attack the most, or
## among THEIRS whose Aura half is worth more than the licid's body.
static func licid_option(g: MtgGame, pilot, s: CardInstance, index: int,
		window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty() or a.effects[0].ai_role != LICID_ROLE:
		return null
	var pid: int = pilot.pid
	if window != "MAIN" or g.active_player != pid \
			or g.current_step() != Mtg.Step.MAIN1 or not g.stack.is_empty():
		return {}
	# THE DECISION'S BUDGET (campaign fix-ai-b, w6-2): the hosts worth a
	# reading, the node allowance every reading runs at, and the readings
	# this decision already made — shared by every licid the scan asks.
	var plan := licid_plan(g, pilot)
	var answers: Dictionary = plan["answers"]
	var twin := licid_twin_key(s)
	if answers.has(twin):
		return twin_answer(answers[twin], s, g)
	var rows: Dictionary = plan["hosts"].get(s.id, {})
	if rows.is_empty():
		rows = trim_hosts(licid_hosts(g, pilot, s, a),
			{"ours": int(plan["quota"]), "theirs": int(plan["quota"])})
	var defender := g.opponent_of(pid)
	var keep: int = pilot.profile.combat_search_nodes
	pilot.profile.combat_search_nodes = mini(keep, int(plan["nodes"]))
	if not plan.has("before"):
		plan["before"] = attack_worth(g, pilot, defender)
		plan["threat"] = their_attack_worth(g, pilot)
	var before: float = plan["before"]
	var toll := toll_value(g, pilot, s)
	var best := {}
	for id in rows["ours"]:
		var host := g.find_instance(int(id))
		# A recurring toll the Aura half charges its host's controller is
		# charged to US on our own creature.
		var gain := attack_worth_dressed(g, pilot, s, host, defender) - before - toll
		if best.is_empty() or gain > float(best["value"]):
			best = {"value": gain, "targets": [TargetRef.card(host)]}
	var threat: float = plan["threat"]
	# The body given up: its attacks and blocks over the Aura's turns are
	# already in the two attack readings; the rest of its worth is
	# discounted by half — the end cost buys it back.
	var body: float = pilot._own_value(g, s) * 0.5
	for id in rows["theirs"]:
		var host := g.find_instance(int(id))
		var gain := hostile_gain(g, pilot, s, host, before, threat) + toll - body
		if best.is_empty() or gain > float(best["value"]):
			best = {"value": gain, "targets": [TargetRef.card(host)]}
	pilot.profile.combat_search_nodes = keep
	answers[twin] = {"id": s.id, "best": best.duplicate()}
	return best


## What the attack the pilot would declare against [param defender] right
## now is worth, the defender blocking as well as it can — 0.0 when it
## would send nothing.
static func attack_worth(g: MtgGame, pilot, defender: int) -> float:
	var candidates: Array[CardInstance] = pilot._attack_candidates(g, defender)
	if candidates.is_empty():
		return 0.0
	var ids: Array = pilot._attack_choice(g, candidates, defender)
	var group: Array[CardInstance] = []
	for inst in candidates:
		if ids.has(inst.id):
			group.append(inst)
	if group.is_empty():
		return 0.0
	var blockers: Array[CardInstance] = []
	for inst in g.players[defender].battlefield:
		if inst.is_creature() and not inst.tapped:
			blockers.append(inst)
	return maxf(float(pilot._cohort_value(g, group, blockers, defender)), 0.0)


## [method attack_worth] with [param licid] made an Aura on [param host]
## — run under the search journal and unmade; a search already in progress
## keeps its journal.
static func attack_worth_dressed(g: MtgGame, pilot, licid: CardInstance,
		host: CardInstance, defender: int) -> float:
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g.become_licid_aura(licid, host)
	var worth := attack_worth(g, pilot, defender)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return worth


## WHAT THEIR ATTACK IS WORTH TO THEM: the mirror of [method
## attack_worth] — every creature of theirs able to attack next turn
## ([method AiPlayer._could_attack_next_turn]) sent at us, our creatures
## blocking as well as they can, priced by the pilot's own cohort reading
## ([method AiPlayer._cohort_value]: the damage that lands at our life's
## face price, the blockers it kills, less the attackers it loses); 0.0
## when it would send nothing worth sending. Public board only.
static func their_attack_worth(g: MtgGame, pilot) -> float:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var attackers: Array[CardInstance] = []
	for inst in g.players[foe].battlefield:
		if pilot._could_attack_next_turn(g, inst, pid) and inst.cur_power > 0:
			attackers.append(inst)
	if attackers.is_empty():
		return 0.0
	var blockers: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_creature():
			blockers.append(inst)
	return maxf(float(pilot._cohort_value(g, attackers, blockers, pid)), 0.0)


## The turns a hostile Aura half is counted over: it stays until its
## host leaves or we end it, so what it denies is denied every turn — read
## as "a few turns of it", the same horizon [method toll_value] charges a
## toll over.
const AURA_TURNS := 2.0


## [param licid] hung on THEIR [param host], priced under the journal:
## what the Aura denies them — our attack's gain (a host that can't
## block) and their attack's loss (a host that can't attack: [method
## their_attack_worth]), both over [constant AURA_TURNS] — and a stolen
## host's worth to both tables. [param before] / [param threat]: [method
## attack_worth] and [method their_attack_worth] as the board stands.
##
## THE PACK 9 STUDY (2026-10-06): the "can't attack" half was one turn of
## the damage their attack puts through our blocks at our life's price,
## and half the licid's body came off it — a Calming Licid on a Serra
## Angel at 20 life came to 4 x 0.5 - 2.0 = 0.0, and a Craw Wurm our
## Llanowar Elves could only chump read as no threat at all (the damage
## "through" a chump block is none). Hostile licids were almost never
## activated.
static func hostile_gain(g: MtgGame, pilot, licid: CardInstance, host: CardInstance,
		before: float, threat: float) -> float:
	var pid: int = pilot.pid
	var defender := g.opponent_of(pid)
	var stolen := 0.0
	if licid.data.licid_steals:
		stolen = float(pilot._victim_value(g, host)) + Evaluator.permanent_value(host, pilot.profile)
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g.become_licid_aura(licid, host)
	var after := attack_worth(g, pilot, defender)
	var threat_after := their_attack_worth(g, pilot)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return ((after - before) + (threat - threat_after)) * AURA_TURNS + stolen


## THE TOLL an Aura half charges its host's controller every turn — "deals
## N damage to that player" at their upkeep (Leeching Licid) or "to that
## creature's controller" whenever it becomes tapped (Stinging Licid) —
## read off the printed lines of [param licid]'s Aura definition ([method
## MtgGame.licid_aura_data]); a few turns of it, at the face's price.
static func toll_value(g: MtgGame, pilot, licid: CardInstance) -> float:
	var data: CardData = g.licid_aura_data(licid)
	if data == null:
		return 0.0
	var total := 0.0
	for trig in data.triggered_abilities:
		var lower := trig.text.to_lower()
		if not (lower.contains("damage to that player") \
				or lower.contains("damage to that creature's controller")):
			continue
		var at := lower.find("deals ")
		var n := lower.substr(at + 6).to_int() if at >= 0 else 0
		if n <= 0:
			continue
		# An upkeep toll is paid every turn; a tap toll when the host
		# attacks or uses a {T} ability — about every other turn.
		var per_turn := 1.0 if trig.event_type == Mtg.EventType.UPKEEP_START else 0.6
		total += float(n) * per_turn * AURA_TURNS * pilot._life_price(g.players[g.opponent_of(pilot.pid)].life)
	return total


# --- Campaign fix-ai-b: the licid decision's budget (w6-2) ---
#
# THE THINK TIME (whole-game campaign 2026-10-07, w6-2). Every licid the
# activation scan asks read the whole attack again for every host on both
# sides — the pilot's own attack planner, a combat study of up to
# [member AiProfile.combat_search_nodes] nodes each — and read the board's
# two base readings (`before`, `threat`) once per licid. Seven licids took
# one Wizard main-phase decision to 9.7 s (a pass); two or three took
# every main phase of a licid duel to one to six seconds, with the duel
# screen frozen for it. Four things now bound it, all deterministic (no
# clock is read: the same board gets the same answer on any machine):
#  * ONE PLAN PER DECISION ([method licid_plan]), kept on the pilot and
#    keyed by the exact public board ([method licid_stamp]): the base
#    readings are made once, and a licid identical to one already read
#    ([method licid_twin_key]: two untouched Tempting Licids) takes its
#    twin's answer ([method twin_answer]) instead of reading it again.
#  * ONLY THE HOSTS THE AURA HALF CAN MATTER ON ([method licid_hosts]):
#    the dressing is read under the journal first ([method
#    dressed_reading], a recalculation, not an attack plan) — a host it
#    makes stronger is a host of ours worth dressing, one it makes weaker
#    (can't attack, can't block, smaller, stolen) one of theirs worth
#    denying; "must be blocked" and any line the reading cannot classify
#    count both ways. A Calming Licid is no longer priced on our own
#    creatures nor a Gliding Licid on theirs: the reading ranked those
#    below the bar, at the price of a full attack plan each.
#  * AT MOST [constant LICID_READINGS] READINGS A DECISION: past it, each
#    licid's side keeps its likeliest hosts ([method trim_hosts]) — ours
#    that can attack once dressed and hit hardest, theirs worth the most.
#  * ONE NODE BUDGET ([constant LICID_NODES]) shared by the decision's
#    readings: each runs the pilot's own planner at that share of it —
#    never more than the profile's own budget, never less than
#    [constant LICID_MIN_NODES] — the truncation the Sorcerer's half
#    budget already is. The base readings run at the same allowance, so a
#    gain compares like with like.
# A board with a licid or two and a handful of creatures is read exactly as
# before: under the cap, and searched within its share.

const SIDE_OURS := 1
const SIDE_THEIRS := 2
const LICID_READINGS := 10
const LICID_NODES := 6000
const LICID_MIN_NODES := 200
const LICID_PLAN_META := &"tempest_licid_plan"


## The decision's plan: `{stamp, hosts: {licid id: {ours, theirs}},
## quota, nodes, answers}` — made on the first ask of a decision, reused by
## every later ask while the board stays [method licid_stamp]'s. Held as
## metadata on the pilot (never a static: the Deck Lab plays its duels on
## worker threads), so it dies with the seat.
static func licid_plan(g: MtgGame, pilot) -> Dictionary:
	var stamp := licid_stamp(g, pilot)
	if pilot.has_meta(LICID_PLAN_META):
		var held: Dictionary = pilot.get_meta(LICID_PLAN_META)
		if String(held.get("stamp", "")) == stamp:
			return held
	var pid: int = pilot.pid
	var rows := {}
	var twins := {}
	var readings := 1
	var sides := 0
	for inst in g.players[pid].battlefield:
		if not inst.is_creature():
			continue
		for index in inst.cur_activated_abilities.size():
			var a: ActivatedAbility = inst.cur_activated_abilities[index]
			if a.effects.is_empty() or a.effects[0].ai_role != LICID_ROLE:
				continue
			var key := licid_twin_key(inst)
			if twins.has(key) or not ability_ready(g, pilot, inst, index):
				break
			twins[key] = true
			var found := licid_hosts(g, pilot, inst, a)
			rows[inst.id] = found
			readings += found["ours"].size() + found["theirs"].size()
			sides += int(not found["ours"].is_empty()) + int(not found["theirs"].is_empty())
			break
	# Past the cap the readings are dealt out a host at a time, every side
	# in battlefield order, until they run out: each side its likeliest
	# host first, a side with fewer hosts leaving its share to the rest.
	var quota := -1
	var quotas := {}
	for id in rows:
		quotas[id] = {"ours": -1, "theirs": -1}
	if readings > LICID_READINGS and sides > 0:
		quota = maxi(1, (LICID_READINGS - 1) / sides)
		var left := LICID_READINGS - 1
		for id in rows:
			quotas[id] = {"ours": 0, "theirs": 0}
		var grew := true
		while left > 0 and grew:
			grew = false
			for id in rows:
				for side in ["ours", "theirs"]:
					if left > 0 and int(quotas[id][side]) < rows[id][side].size():
						quotas[id][side] = int(quotas[id][side]) + 1
						left -= 1
						grew = true
	var hosts := {}
	var made := 1
	for id in rows:
		hosts[id] = trim_hosts(rows[id], quotas[id])
		made += hosts[id]["ours"].size() + hosts[id]["theirs"].size()
	var plan := {"stamp": stamp, "hosts": hosts, "quota": quota, "answers": {},
		"nodes": maxi(LICID_MIN_NODES, LICID_NODES / made)}
	pilot.set_meta(LICID_PLAN_META, plan)
	return plan


## The exact public board one decision is made on: the moment, both
## players' public counts, every permanent's id and visible state, and
## our own hand. A change to any of them is a new decision.
static func licid_stamp(g: MtgGame, pilot) -> String:
	var parts := PackedStringArray()
	parts.append("%d:%d:%d:%d:%d:%d:%d" % [g.get_instance_id(), pilot.pid, g.turn_number,
		g.current_step(), g.priority_player, g.stack.size(), g.log_lines.size()])
	for pl in g.players:
		parts.append("%d:%d:%d:%d:%d" % [pl.life, pl.hand.size(), pl.library.size(),
			pl.graveyard.size(), pl.mana_pool.total()])
		for inst in pl.battlefield:
			parts.append("%d:%d:%d:%d:%d:%d:%d:%d:%d" % [inst.id, inst.controller_id,
				int(inst.tapped), int(inst.summoning_sick), inst.damage, inst.attached_to,
				inst.cur_power, inst.cur_toughness, inst.counters.size()])
	for inst in g.players[pilot.pid].hand:
		parts.append(str(inst.id))
	return "|".join(parts)


## Two licids with this key are interchangeable for the arm: the same
## card in the same visible state.
static func licid_twin_key(s: CardInstance) -> String:
	return "%s:%d:%d:%d:%d:%d:%d:%d:%s" % [s.data.card_name, int(s.tapped),
		int(s.summoning_sick), s.damage, s.cur_power, s.cur_toughness,
		s.attachments.size(), s.regeneration_shields, str(s.counters)]


## The answer [param entry] (`{id, best}`) gave its licid, given to its
## twin [param s]: the same value at the same host — or, when that host was
## [param s] itself, at the licid that was read (each dresses the other).
## Always a copy: the scan prices pain into the option it is handed.
static func twin_answer(entry: Dictionary, s: CardInstance, g: MtgGame = null) -> Dictionary:
	var best: Dictionary = entry["best"]
	if best.is_empty():
		return {}
	var out := best.duplicate()
	var ref: TargetRef = best["targets"][0]
	if int(entry["id"]) != s.id and ref.instance_id == s.id and g != null:
		var read := g.find_instance(int(entry["id"]))
		if read != null:
			out["targets"] = [TargetRef.card(read)]
	return out


## Every legal host of [param s]'s licid ability [param a] the Aura half
## can matter on: `{ours: [{id, prior}], theirs: [{id, prior}]}` in
## battlefield order — ours where the dressing makes the host stronger (or
## gives its controller an ability for it), theirs where it makes the host
## weaker, charges its controller or takes it ([method dressed_reading],
## [method aura_sides]). [code]prior[/code] ranks them for [method
## trim_hosts].
static func licid_hosts(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility) -> Dictionary:
	var ours: Array = []
	var theirs: Array = []
	var spec: TargetSpec = a.effects[0].target_spec
	if spec == null:
		return {"ours": ours, "theirs": theirs}
	var pid: int = pilot.pid
	var defender := g.opponent_of(pid)
	var shared := aura_sides(g, s)
	for host in g.players[pid].battlefield:
		if host == s or not host.is_creature() or not spec.is_legal(g, TargetRef.card(host), s):
			continue
		var seen := dressed_reading(g, s, host)
		if (shared | int(seen["sides"])) & SIDE_OURS:
			ours.append({"id": host.id, "prior": [int(seen["attacks"]), int(seen["power"]),
				Evaluator.permanent_value(host, pilot.profile)]})
	for host in g.players[defender].battlefield:
		if not host.is_creature() or not spec.is_legal(g, TargetRef.card(host), s):
			continue
		if preload("res://engine/ai/mirage_tactics.gd").dies_when_targeted(host, g):
			continue   # the Aura would have no host to land on
		var seen := dressed_reading(g, s, host)
		if (shared | int(seen["sides"])) & SIDE_THEIRS:
			theirs.append({"id": host.id, "prior": [Evaluator.permanent_value(host, pilot.profile)]})
	return {"ours": ours, "theirs": theirs}


## The sides [param s]'s Aura half matters on whatever its host: a steal
## or a toll ([method toll_value]'s lines) is theirs; an ability the Aura
## gives its controller for the host (Nurturing Licid's regeneration) is
## ours; any other triggered line is read both ways.
static func aura_sides(g: MtgGame, s: CardInstance) -> int:
	var data: CardData = g.licid_aura_data(s)
	if data == null:
		return SIDE_OURS | SIDE_THEIRS
	var sides := 0
	if data.licid_steals:
		sides |= SIDE_THEIRS
	if not data.activated_abilities.is_empty():
		sides |= SIDE_OURS
	for trig in data.triggered_abilities:
		var lower := trig.text.to_lower()
		if lower.contains("damage to that player") \
				or lower.contains("damage to that creature's controller"):
			sides |= SIDE_THEIRS
		else:
			sides |= SIDE_OURS | SIDE_THEIRS
	return sides


## [param licid] made an Aura on [param host] under the search journal —
## a recalculation, no attack plan: `{sides, attacks, power}`, the
## [constant SIDE_OURS] / [constant SIDE_THEIRS] bits for what changed on
## the host (stronger / weaker; "must be blocked" both), and whether it can
## attack and how hard once dressed. A search in progress keeps its journal.
static func dressed_reading(g: MtgGame, licid: CardInstance, host: CardInstance) -> Dictionary:
	var was := host_shape(g, host)
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g.become_licid_aura(licid, host)
	var now := host_shape(g, host)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	var sides := 0
	if int(now["power"]) > int(was["power"]) or int(now["toughness"]) > int(was["toughness"]):
		sides |= SIDE_OURS
	if int(now["power"]) < int(was["power"]) or int(now["toughness"]) < int(was["toughness"]):
		sides |= SIDE_THEIRS
	for k in now["keywords"]:
		if not was["keywords"].has(k):
			sides |= SIDE_OURS
	for k in was["keywords"]:
		if not now["keywords"].has(k):
			sides |= SIDE_THEIRS
	for field in ["landwalk", "protection", "unblockable_by", "min_blockers"]:
		if int(now[field]) > int(was[field]):
			sides |= SIDE_OURS
	if bool(now["attacks"]) and not bool(was["attacks"]):
		sides |= SIDE_OURS
	for field in ["cant_attack", "cant_block", "skips_untap"]:
		if bool(now[field]) and not bool(was[field]):
			sides |= SIDE_THEIRS
	if bool(was["attacks"]) and not bool(now["attacks"]):
		sides |= SIDE_THEIRS
	if int(now["controller"]) != int(was["controller"]):
		sides |= SIDE_THEIRS
	if bool(now["must_be_blocked"]) and not bool(was["must_be_blocked"]):
		sides |= SIDE_OURS | SIDE_THEIRS
	return {"sides": sides, "attacks": now["attacks"], "power": now["power"]}


## The visible combat shape of [param host] [method dressed_reading] compares.
static func host_shape(g: MtgGame, host: CardInstance) -> Dictionary:
	var keywords: Array = host.cur_keywords.duplicate()
	return {"power": host.cur_power, "toughness": host.cur_toughness, "keywords": keywords,
		"landwalk": host.cur_landwalk.size(), "protection": host.cur_protection,
		"unblockable_by": host.cur_cant_be_blocked_by.size(), "min_blockers": host.cur_min_blockers,
		"cant_attack": host.cur_cant_attack, "cant_block": host.cur_cant_block_filter.is_valid(),
		"skips_untap": host.cur_skips_untap, "must_be_blocked": host.cur_must_be_blocked,
		"controller": host.controller_id,
		"attacks": CombatState.attack_illegality(g, host, g.opponent_of(host.controller_id), false) == ""}


## [param rows] ([method licid_hosts]) as plain id lists in battlefield
## order, each side cut to its quota in [param quotas] (`{ours, theirs}`)
## of likeliest hosts by their prior (highest first, the earlier host on a
## tie) — all of them where the quota is negative.
static func trim_hosts(rows: Dictionary, quotas: Dictionary) -> Dictionary:
	var out := {}
	for side in ["ours", "theirs"]:
		var list: Array = rows[side]
		var quota := int(quotas[side])
		var keep: Array = []
		if quota >= 0 and list.size() > quota:
			var ranked := range(list.size())
			ranked.sort_custom(func(x: int, y: int) -> bool:
				var px: Array = list[x]["prior"]
				var py: Array = list[y]["prior"]
				for k in px.size():
					if not is_equal_approx(float(px[k]), float(py[k])):
						return float(px[k]) > float(py[k])
				return x < y)
			var chosen: Array = ranked.slice(0, quota)
			chosen.sort()
			for i in chosen:
				keep.append(list[i]["id"])
		else:
			for row in list:
				keep.append(row["id"])
		out[side] = keep
	return out
# --- end campaign fix-ai-b licid budget ---


## THE LICID SAVED (CR 116.2c): one of our licids is an Aura whose host —
## ours or theirs — is about to leave the battlefield, or which is itself
## the target of a hostile spell of theirs; paying its end cost makes it
## its creature self in place, and the Aura SBA no longer reaches it.
## "" when nothing is threatened or nothing is worth the mana.
##
## TWO HOSTS NOT TO ABANDON (the Pack 9 bug pass, h3-3 / h3-4): a host the
## licid's own "regenerate enchanted creature" can still shield from the
## threat is regenerated instead ([method host_shieldable] — the pilot's
## regeneration arm answers it; the Aura stays), and a host a STEALING
## licid holds that dies in the combat for us is not handed back alive
## unless the licid is worth more than that creature is to them.
static func licid_save(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	for licid in g.players[pid].battlefield:
		if not g.is_licid_aura(licid) or licid.controller_id != pid:
			continue
		var host := g.find_instance(licid.attached_to)
		if not licid_doomed(g, pilot, licid, host):
			continue
		var worth := Evaluator.card_value(licid.data.licid_base) \
			if licid.data.licid_base != null else 2.0
		if worth < 1.5:
			continue
		if host != null and host_shieldable(g, pilot, licid, host):
			continue
		if host != null and licid.data.licid_steals and host.controller_id == pid \
				and g.stack.is_empty() and worth <= float(pilot._victim_value(g, host)):
			continue   # it dies for us; ended, it goes home alive
		var done := take_special(g, pid, "licid_end", licid.id)
		if done != "":
			return "ends %s's effect: %s" % [licid.data.card_name, done]
	return ""


## Is [param licid] (an Aura on [param host]) about to go to the
## graveyard — the top of the stack THEIR object that removes, kills,
## bounces or kills the host, or that destroys or bounces the licid
## itself; or the host dying in the combat damage about to be dealt?
static func licid_doomed(g: MtgGame, pilot, licid: CardInstance, host: CardInstance) -> bool:
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		if top.controller == pilot.pid or top.targets.is_empty():
			return false
		var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
		for t in top.targets:
			if t == null or t.is_player or t.is_damage or t.is_ability:
				continue
			if t.instance_id == licid.id and (intent.removes or intent.bounces):
				return true
			if host != null and t.instance_id == host.id:
				if intent.removes or intent.bounces \
						or (intent.damage_at(top.x_value) > 0 and intent.kills(host, top.x_value)):
					return true
		return false
	if host == null or g.combat.attackers.is_empty() \
			or g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers:
		return false
	return pilot._dies_in_combat(g, host)


## Can [param host]'s threat — THEIR object on top of the stack aimed at
## it, or the combat damage about to be dealt — be answered by a
## regeneration shield one of [param licid]'s own abilities gives "enchanted
## creature" (role `regenerate_host`, Nurturing Licid), payable now? A
## removal that forbids regeneration, a bounce or an exile, or a threat
## aimed at the licid itself, cannot; a host already shielded needs no
## second shield.
static func host_shieldable(g: MtgGame, pilot, licid: CardInstance, host: CardInstance) -> bool:
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
		if intent.bounces or intent.removal_ignores_regeneration:
			return false
		for t in top.targets:
			if t != null and not t.is_player and not t.is_damage and not t.is_ability \
					and t.instance_id == licid.id:
				return false   # the licid itself is the target
	if host.regeneration_shields > 0:
		return true
	for index in licid.cur_activated_abilities.size():
		var a: ActivatedAbility = licid.cur_activated_abilities[index]
		if a.effects.is_empty() or a.effects[0].ai_role != &"regenerate_host":
			continue
		if ability_ready(g, pilot, licid, index):
			return true
	return false


## Take the special action of [param kind] on permanent [param id] for
## [param pid] when it can be taken now: "" when it was not, else the row's
## label.
static func take_special(g: MtgGame, pid: int, kind: String, id: int) -> String:
	for row in g.special_actions(pid):
		if String(row.get("kind", "")) != kind or int(row.get("id", -1)) != id:
			continue
		if g.special_action_refusal(pid, row) != "":
			return ""
		if g.take_special_action(pid, row) == "":
			return String(row.get("label", kind))
	return ""


# ======================================================== Volrath's Curse --

## THE IGNORE (CR 116.2d), asked in our first main phase before combat:
## a Curse on one of our creatures keeps it home; sacrificing a permanent
## frees it for this turn. Taken when the attack the pilot would then
## declare is worth more than it is now by more than the body the cost
## question gives up — the cheapest one the engine offers it ([method
## MtgGame._ignore_bodies], by [method AiPlayer._own_value]) other than the
## cursed creature itself — or is lethal. THE BODY IS PRICED GONE (the
## Pack 9 bug pass, h3-2): the attack after the ignore is read with that
## body sacrificed under the search journal, so a creature the cost eats
## is not counted in the attack it pays for.
static func curse_action(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player != pid or g.current_step() != Mtg.Step.MAIN1 or not g.stack.is_empty():
		return ""
	var defender := g.opponent_of(pid)
	for row in g.special_actions(pid):
		if String(row.get("kind", "")) != "ignore_effect":
			continue
		var curse: CardInstance = row.get("card")
		var host := g.find_instance(curse.attached_to) if curse != null else null
		if host == null or host.controller_id != pid or not host.is_creature():
			continue
		if g.special_action_refusal(pid, row) != "":
			continue
		var pick := curse_price_body(g, pilot, curse, host)
		if pick == null:
			continue
		var cheapest := float(pilot._own_value(g, pick))
		var before := attack_worth(g, pilot, defender)
		var nested := g.undo_log != null
		var mark := g.make_mark()
		g._rec(curse, &"memory")
		var ignored: Dictionary = {}
		if curse.memory.get("ignored") is Dictionary:
			ignored = (curse.memory["ignored"] as Dictionary).duplicate()
		ignored[pid] = g.turn_number
		curse.memory["ignored"] = ignored
		g.sacrifice_permanent(pick)
		g.recalculate()
		var after := attack_worth(g, pilot, defender)
		var lethal := false
		if after > 0.0:
			var candidates: Array[CardInstance] = pilot._attack_candidates(g, defender)
			lethal = pilot._damage_through_blocks(g, candidates,
				pilot._untapped_creatures(g, defender), defender) >= g.players[defender].life
		g.unmake_to(mark)
		if not nested:
			g.end_search()
		if not lethal and after - before <= cheapest + 1.0:
			continue
		var done := take_special(g, pid, "ignore_effect", curse.id)
		if done != "":
			return "ignores %s: %s" % [curse.data.card_name, done]
	return ""


## The body the Curse's sacrifice gives up: the cheapest permanent the
## engine offers the cost question ([method MtgGame._ignore_bodies]) other
## than the cursed [param host] — the pick the pilot's cost answer makes
## ([method AiPlayer.answer_card]) — or null when the host is the only one.
static func curse_price_body(g: MtgGame, pilot, curse: CardInstance,
		host: CardInstance) -> CardInstance:
	var pick: CardInstance = null
	var cheapest := INF
	for body in g._ignore_bodies(pilot.pid, curse):
		if body == host:
			continue
		var value := float(pilot._own_value(g, body))
		if value < cheapest:
			cheapest = value
			pick = body
	return pick


# =========================================================== the shadow --

## +1 when [param e] GRANTS shadow to a target creature (a [PumpEffect]
## carrying [constant Mtg.Keyword.SHADOW], not "this creature"), -1 when it
## takes shadow from one ([LoseAbilityEffect]), 0 otherwise.
static func shadow_shift(e: EffectBase) -> int:
	if e == null or e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.CREATURE:
		return 0
	if e is PumpEffect and (e as PumpEffect).granted_keywords.has(Mtg.Keyword.SHADOW) \
			and not (e as PumpEffect).self_mode:
		return 1
	if e is LoseAbilityEffect and (e as LoseAbilityEffect).keywords.has(Mtg.Keyword.SHADOW) \
			and not (e as LoseAbilityEffect).self_mode:
		return -1
	return 0


## The first effect of [param data]'s spell that shifts shadow, or null.
static func _spell_shift(data: CardData, sign: int) -> EffectBase:
	for e in data.spell_effects:
		if shadow_shift(e) == sign:
			return e
	return null


## Every way the pilot can shift shadow ([param sign]: +1 grant, -1 loss)
## on [param victim] right now, cheapest first — `{price, kind, inst,
## index, targets}`, the shape [method MirageTactics.use_tool] puts to
## work. An ability is priced as its mana (and a {T} creature body that is
## not attacking: half a point); a spell as the card, less the card it
## draws back.
static func shadow_tools(g: MtgGame, pilot, victim: CardInstance, sign: int) -> Array:
	var out: Array = []
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var vref := TargetRef.card(victim)
	for src in g.players[pid].battlefield:
		for index in src.cur_activated_abilities.size():
			var a: ActivatedAbility = src.cur_activated_abilities[index]
			if a.effects.is_empty() or shadow_shift(a.effects[0]) != sign:
				continue
			if not a.effects[0].target_spec.is_legal(g, vref, src):
				continue
			if not pilot._ability_available(g, src, index):
				continue
			# Priced as the engine charges it (Heartstone; the bug pass, h5-3).
			var mana: int = preload("res://engine/ai/mirage_tactics.gd").ability_mana(g, pilot, src, index, sources)
			if mana < 0:
				continue
			var price := float(mana) * 0.5
			if a.tap_cost and src.is_creature():
				price += 0.5
			out.append({"price": price, "kind": &"ability", "inst": src,
				"index": index, "mode": 0, "targets": [vref]})
	for inst in g.players[pid].hand:
		var e := _spell_shift(inst.data, sign)
		if e == null or not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)):
			continue
		if not e.target_spec.is_legal(g, vref, inst) or g.cast_refusal(pid, inst, [vref]) != "":
			continue
		var surcharge := g.spell_surcharge(pid, inst.data)
		var cost := g.spell_cost_for(pid, inst.data)
		if not (pilot._cost_is_free(cost) and surcharge <= 0) \
				and pilot._plan_taps_from(sources, cost, surcharge,
					g.mana_usage_keys(inst.data, inst)).is_empty():
			continue
		var price := Evaluator.card_value(inst.data)
		for other in inst.data.spell_effects:
			if other is DrawEffect:
				price -= float((other as DrawEffect).count) * 1.5
		out.append({"price": maxf(price, 0.5), "kind": &"spell", "inst": inst,
			"index": -1, "mode": 0, "targets": [vref]})
	out.sort_custom(func(x: Dictionary, y: Dictionary) -> bool:
		return float(x["price"]) < float(y["price"]))
	return out


## THE EVASION TRICK: our attackers are declared and their blocks are not;
## an attacker of ours without shadow that their untapped creatures would
## block well — the exchange the defender's best blocks give ([method
## AiPlayer._cohort_value]) — gains shadow, and with no shade of theirs to
## meet it, the block is gone (CR 702.28b). Priced as the exchange won
## against the cheapest tool; the game when it makes the attack lethal
## through their blocks. Never after blocks: a shadow gained then changes
## nothing (CR 506.4).
static func evasion_trick(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player != pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS \
			or g.awaiting_attackers or g.combat.attackers.is_empty() or not g.stack.is_empty() \
			or g.combat_damage_prevented:
		return ""
	var foe := g.opponent_of(pid)
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	if attackers.is_empty() or blockers.is_empty():
		return ""
	var life := g.players[foe].life
	var before: float = pilot._cohort_value(g, attackers, blockers, foe)
	var through_before: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	var best := {}
	var best_value := 0.0
	var best_victim: CardInstance = null
	for attacker in attackers:
		if attacker.controller_id != pid or attacker.has_keyword(Mtg.Keyword.SHADOW):
			continue
		var blockable := false
		for b in blockers:
			if CombatState.block_illegality(g, b, attacker, foe, true, pid) == "":
				blockable = true
				break
		if not blockable:
			continue
		var tools := shadow_tools(g, pilot, attacker, 1)
		if tools.is_empty():
			continue
		var nested := g.undo_log != null
		var mark := g.make_mark()
		g.continuous.add_until_eot_keywords(attacker.id, [Mtg.Keyword.SHADOW])
		g.recalculate()
		var after: float = pilot._cohort_value(g, attackers, blockers, foe)
		var through_after: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
		g.unmake_to(mark)
		if not nested:
			g.end_search()
		var value := after - before
		if through_before < life and through_after >= life:
			value = pilot.LETHAL_WORTH
		if value < float(tools[0]["price"]) + 1.0:
			continue
		if value > best_value:
			best = tools[0]
			best_value = value
			best_victim = attacker
	if best.is_empty():
		return ""
	return preload("res://engine/ai/mirage_tactics.gd").use_tool(g, pilot, best,
		"%s gains shadow" % best_victim.data.card_name)


## THE EVASION DENIED: their attackers are declared and our blocks are
## not; an attacker of theirs WITH shadow loses it, and our untapped
## creatures may then block it (CR 702.28b). Priced as the damage our best
## blocks then stop (at our life's price) plus the attacker when one of
## our blockers kills it and lives; the game when it turns a lethal attack
## into a survivable one.
static func deny_evasion(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player == pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS \
			or g.awaiting_attackers or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var life := g.players[pid].life
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, pid)
	if attackers.is_empty() or blockers.is_empty():
		return ""
	var before: int = pilot._damage_through_blocks(g, attackers, blockers, pid)
	var best := {}
	var best_value := 0.0
	var best_victim: CardInstance = null
	for attacker in attackers:
		if attacker.controller_id == pid or not attacker.has_keyword(Mtg.Keyword.SHADOW):
			continue
		var tools := shadow_tools(g, pilot, attacker, -1)
		if tools.is_empty():
			continue
		var nested := g.undo_log != null
		var mark := g.make_mark()
		g.continuous.add_until_eot_loss(attacker.id, [Mtg.Keyword.SHADOW])
		g.recalculate()
		var after: int = pilot._damage_through_blocks(g, attackers, blockers, pid)
		var kill := 0.0
		for b in blockers:
			if CombatState.block_illegality(g, b, attacker, pid, true, attacker.controller_id) != "":
				continue
			if pilot._dies_to(g, attacker, b) and not pilot._dies_to(g, b, attacker):
				kill = maxf(kill, float(pilot._victim_value(g, attacker)))
		g.unmake_to(mark)
		if not nested:
			g.end_search()
		var value: float = float(maxi(before - after, 0)) * pilot._life_price(life) + kill
		if before >= life and after < life:
			value = pilot.LETHAL_WORTH
		if value < float(tools[0]["price"]) + 1.0:
			continue
		if value > best_value:
			best = tools[0]
			best_value = value
			best_victim = attacker
	if best.is_empty():
		return ""
	return preload("res://engine/ai/mirage_tactics.gd").use_tool(g, pilot, best,
		"%s loses shadow" % best_victim.data.card_name)


## THE MAIN-PHASE CAST of a shadow trick, asked by [method
## MirageTactics.spell_choice]: null when [param inst] shifts no shadow; a
## seat that holds instants keeps it for the declare-attackers step
## ([method respond]), `{}`.
static func spell_choice(g: MtgGame, pilot, inst: CardInstance, _mode: int) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	if _spell_shift(inst.data, 1) == null and _spell_shift(inst.data, -1) == null:
		return null
	if pilot.profile.holds_instants and g.casts_at_instant_speed(pilot.pid, inst):
		return {}
	return null


# ======================================================= the block's roles --
#
# Each arm below reads a role a Pack 9 card module declares on its effect
# ([member EffectBase.ai_role]); none names a card. Values are on the
# shared scorer's scale ([method AiPlayer._ability_option] then charges the
# mana and any sacrifice); `{}` is "no, not now".


## "Choose target opponent who … as you activate this ability. <effect>"
## (the Keepers): the condition slot first — an ability whose condition no
## opponent meets is never paid for (the engine would refuse it after the
## mana) — then the effect it guards, read off its typed shape.
static func keeper_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window == "RESPONSE" or window == "COMBAT" or a.effects.size() < 2:
		return {}
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var fref := TargetRef.player(foe)
	if a.effects[0].target_spec == null or not a.effects[0].target_spec.is_legal(g, fref, s):
		return {}
	var me := g.players[pid]
	var sink := 1.0 if window == "SINK" else 0.0
	var e: EffectBase = a.effects[1]
	if e is GainLifeEffect:
		var life: float = float((e as GainLifeEffect).amount) * pilot._life_price(me.life)
		return {"value": life + sink, "targets": [fref], "bar": 0.5}
	if e is DrawEffect:
		var n := (e as DrawEffect).count
		if me.library.size() <= n + 3 or (g.active_player == pid and me.hand.size() + n > 7):
			return {}
		return {"value": 4.0 + sink, "targets": [fref]}
	if e is CreateTokenEffect:
		var body := (e as CreateTokenEffect).token
		return {"value": float(body.power + body.toughness) + sink, "targets": [fref]}
	if e is DestroyEffect and e.target_spec != null:
		var best := {}
		for inst in g.players[foe].battlefield:
			var ref := TargetRef.card(inst)
			if not inst.is_creature() or not e.target_spec.is_legal(g, ref, s, [fref]):
				continue
			var value: float = float(pilot._victim_value(g, inst)) + 1.0
			if best.is_empty() or value > float(best["value"]):
				best = {"value": value, "targets": [fref, ref]}
		return best
	return {}


## Removal that hands its own source to the victim's controller ("Destroy
## target artifact or creature. That permanent's controller gains control
## of Starke"): the victim is worth the trade only above the source twice
## over — we lose it and they gain a repeatable removal of their own.
static func donating_removal_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window == "COMBAT" or a.effects[0].target_spec == null:
		return {}
	var foe := g.opponent_of(pilot.pid)
	var donated: float = 2.0 * float(pilot._own_value(g, s)) + 3.0
	var best := {}
	for inst in g.players[foe].battlefield:
		var ref := TargetRef.card(inst)
		if not a.effects[0].target_spec.is_legal(g, ref, s) or inst.cur_indestructible:
			continue
		var value: float = float(pilot._victim_value(g, inst)) + 1.0 - donated
		if value > 0.0 and (best.is_empty() or value > float(best["value"])):
			best = {"value": value, "targets": [ref]}
	return best


## "Choose a card name, then reveal a card at random from your hand. If it
## has the chosen name, 2 damage to any target" (Cursed Scroll): the name
## the resolution picks is the one our hand holds most copies of, so the
## hit chance is that count over the hand — our own hand, ours to know.
static func scroll_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var pid: int = pilot.pid
	var hand: Array = g.players[pid].hand
	if hand.is_empty() or window == "COMBAT":
		return {}
	var counts := {}
	var most := 0
	for card in hand:
		var n := int(counts.get(card.data.card_name, 0)) + 1
		counts[card.data.card_name] = n
		most = maxi(most, n)
	var chance := float(most) / float(hand.size())
	var e: DamageEffect = a.effects[0]
	var foe := g.opponent_of(pid)
	var best := {}
	for inst in g.players[foe].battlefield:
		var ref := TargetRef.card(inst)
		if not inst.is_creature() or not e.target_spec.is_legal(g, ref, s):
			continue
		if not bool(g.predict_damage(s, ref, e.amount, false, 0, pid)["dies"]):
			continue
		var value: float = float(pilot._victim_value(g, inst)) + 1.0
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	var face := TargetRef.player(foe)
	if e.target_spec.is_legal(g, face, s):
		var life := g.players[foe].life
		var value: float = float(e.amount) * 0.75 + (2.0 if life <= e.amount * 3 else 0.0)
		if e.amount >= life:
			value = pilot.LETHAL_WORTH
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [face]}
	if best.is_empty():
		return {}
	best["value"] = float(best["value"]) * chance + (1.0 if window == "SINK" else 0.0)
	return best


## "{T}: Put a bounty counter on target nonblack creature" — the mark the
## same creature's "{T}: Destroy target creature with a bounty counter"
## collects (the shared removal arm reads that one). Marked at their end
## step, when the {T} costs no attack, on their best legal creature; never
## while a marked one waits to be collected.
static func bounty_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "SINK":
		return {}
	var foe := g.opponent_of(pilot.pid)
	var kind := String(a.effects[0].ai_parameters.get("kind", "bounty"))
	var best := {}
	for inst in g.players[foe].battlefield:
		if not inst.is_creature():
			continue
		if int(inst.counters.get(kind, 0)) > 0:
			return {}
		var ref := TargetRef.card(inst)
		if not a.effects[0].target_spec.is_legal(g, ref, s):
			continue
		var value: float = float(pilot._victim_value(g, inst)) * 0.6
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref], "bar": 0.5}
	return best


## "{T}: You may put a land card from your hand onto the battlefield" — a
## second land this turn once the land drop is spent (the planner plays
## the first; putting one is not playing one, CR 305.4).
static func land_from_hand_option(g: MtgGame, pilot, s: CardInstance,
		window: String) -> Dictionary:
	var pid: int = pilot.pid
	if window != "MAIN" or g.land_drop_available(pid):
		return {}
	for card in g.players[pid].hand:
		if card.data.is_land():
			return {"value": 3.5, "targets": []}
	return {}


## "{c}, {T}: Put a <kind> counter on this artifact" whose counters another
## of its abilities cashes (Essence Bottle): bought with mana the untap step
## would waste.
static func charge_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "SINK":
		return {}
	if g.players[pilot.pid].life <= 8:
		return {}   # the life is wanted now: [method drink_option]
	return {"value": 1.5, "targets": [], "bar": 0.5}


## "{T}, Remove all <kind> counters: You gain N life for each" (Essence
## Bottle): cashed when the life decides something — their attack about
## to kill us, or a low life total — never for a point at a healthy one.
static func drink_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var kind := String(a.effects[0].ai_parameters.get("kind", ""))
	var per := int(a.effects[0].ai_parameters.get("per", 1))
	var n := int(s.counters.get(kind, 0))
	if n <= 0:
		return {}
	var me := g.players[pilot.pid]
	var gain := n * per
	if window == "RESPONSE":
		var incoming: int = pilot._incoming_damage(g)
		if incoming >= me.life and me.life + gain > incoming:
			return {"value": pilot.LETHAL_WORTH, "targets": []}
		return {}
	if me.life > 8 or window == "COMBAT":
		return {}
	return {"value": float(gain) * pilot._life_price(me.life), "targets": [], "bar": 0.5}


## "{c}, {T}, Remove all <kind> counters: It deals that much damage to
## target creature" (Torture Chamber): their best creature the count
## kills; the counters it sheds stop hurting us at our end step too.
static func rack_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window == "COMBAT" or window == "RESPONSE":
		return {}
	var kind := String(a.effects[0].ai_parameters.get("kind", ""))
	var n := int(s.counters.get(kind, 0))
	if n <= 0:
		return {}
	var pid: int = pilot.pid
	var relief: float = float(n) * pilot._life_price(g.players[pid].life)
	var best := {}
	for inst in g.players[g.opponent_of(pid)].battlefield:
		var ref := TargetRef.card(inst)
		if not inst.is_creature() or not a.effects[0].target_spec.is_legal(g, ref, s):
			continue
		if not bool(g.predict_damage(s, ref, n, false, 0, pid)["dies"]):
			continue
		var value: float = float(pilot._victim_value(g, inst)) + 1.0 + relief
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## "Gain control of target creature" for as long as a condition holds — the
## activating permanent stays tapped (Helm of Possession), or the creature
## stays enchanted (Rootwater Matriarch): their best creature that meets
## it, worth what it does for us and what it no longer does for them. The
## sacrifice a cost asks for is charged by the shared scorer.
static func steal_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "MAIN" and window != "SINK":
		return {}
	var e: EffectBase = a.effects[0]
	var foe := g.opponent_of(pilot.pid)
	var best := {}
	for inst in g.players[foe].battlefield:
		var ref := TargetRef.card(inst)
		if not inst.is_creature() or not e.target_spec.is_legal(g, ref, s):
			continue
		if e.ai_role == &"steal_while_enchanted" and not g.is_enchanted(inst):
			continue
		var value: float = float(pilot._victim_value(g, inst)) \
			+ 0.5 * Evaluator.permanent_value(inst, pilot.profile)
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## The turns of a toll a donation is priced over.
const DONATE_TURNS := 4.0


## "Target opponent gains control of this artifact" (Jinxed Idol, Jinxed
## Ring): a permanent whose own triggers hurt its controller — "deals N
## damage to you" — is given away at their end step, the last moment before
## our upkeep would pay its toll. The donation costs a creature (charged by
## the shared scorer), and the same ability hands it straight back for one
## of theirs: so it is priced as one turn of the toll while they have a
## creature to send it back with — no trade for a body at a healthy life,
## which kept two pilots bleeding creatures into an Idol passed to and fro
## (the Pack 9 smoke) — and as a few turns of it when they have none.
static func donate_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "SINK":
		return {}
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var per_turn := toll_per_turn(s.cur_triggered_abilities)
	if per_turn <= 0.0:
		return {}
	var fref := TargetRef.player(foe)
	if a.effects[0].target_spec != null and not a.effects[0].target_spec.is_legal(g, fref, s):
		return {}
	return {"value": donation_value(g, pilot, per_turn), "targets": [fref]}


## The points a turn [param triggers] — a permanent's own — deal "to you",
## its controller: an upkeep toll every turn, any other about every other
## turn. Read off the printed lines.
static func toll_per_turn(triggers: Array) -> float:
	var per_turn := 0.0
	for trig in triggers:
		var lower: String = trig.text.to_lower()
		if not lower.contains("damage to you"):
			continue
		var at := lower.find("deals ")
		var n := lower.substr(at + 6).to_int() if at >= 0 else 0
		per_turn += float(maxi(n, 1)) * (1.0 if trig.event_type == Mtg.EventType.UPKEEP_START else 0.4)
	return per_turn


## What handing a toll of [param per_turn] points to the opponent is worth
## ([method donate_option]): one turn of it while they have a creature to
## send it back with, [constant DONATE_TURNS] when they have none — the
## points off their life and kept off ours.
static func donation_value(g: MtgGame, pilot, per_turn: float) -> float:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var returnable := false
	for inst in g.players[foe].battlefield:
		if inst.is_creature():
			returnable = true
	var turns := 1.0 if returnable else DONATE_TURNS
	return per_turn * turns * (pilot._life_price(g.players[pid].life) \
		+ pilot._life_price(g.players[foe].life))


## "Target creature blocks this creature this turn if able" (Trumpeting
## Armodon): our attack is declared, their blocks are not; the source is
## attacking, and their creature it kills without dying is ordered into
## the block — a removal spell their requirement pays for. A creature the
## source's live requirement already binds is not ordered again (the bug
## pass, h1-7: three activations on the same Grizzly Bears), and nothing
## is ordered while an order of ours is still on the stack.
static func lure_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var pid: int = pilot.pid
	if window != "RESPONSE" or g.active_player != pid \
			or g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.awaiting_attackers \
			or not g.combat.attackers.has(s.id):
		return {}
	for item in g.stack:
		if item.controller == pid and item.card == s and item.kind != Mtg.StackKind.SPELL:
			return {}
	var foe := g.opponent_of(pid)
	var best := {}
	for inst in pilot._untapped_creatures(g, foe):
		var ref := TargetRef.card(inst)
		if not a.effects[0].target_spec.is_legal(g, ref, s):
			continue
		if already_lured(s, inst):
			continue
		if CombatState.block_illegality(g, inst, s, foe, true, pid) != "":
			continue
		if not pilot._dies_to(g, inst, s) or pilot._dies_to(g, s, inst):
			continue
		var value: float = float(pilot._victim_value(g, inst)) + 1.0
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## Does [param attacker]'s live block requirement already bind [param
## blocker] — "all creatures able to block it do so", or a requirement
## narrowed to creatures its filter accepts (Trumpeting Armodon's order,
## Magnetic Web's magnets)? The engine's own answer
## ([method CombatDeclaration.lure_binds]), so the AI and the block rules
## cannot disagree.
static func already_lured(attacker: CardInstance, blocker: CardInstance) -> bool:
	return preload("res://engine/core/combat_declaration.gd").lure_binds(attacker, blocker)


## "Target creature can't block this creature this turn" (Duct Crawler):
## our attack is declared, their blocks are not; the creature of theirs
## whose absence as a blocker of the source gains the exchange the most
## ([method AiPlayer._cohort_value], the effect run under the journal).
static func unblockable_by_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	var pid: int = pilot.pid
	if window != "RESPONSE" or g.active_player != pid \
			or g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.awaiting_attackers \
			or not g.combat.attackers.has(s.id) or not g.stack.is_empty():
		return {}
	var foe := g.opponent_of(pid)
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	var before: float = pilot._cohort_value(g, attackers, blockers, foe)
	var best := {}
	for inst in blockers:
		var ref := TargetRef.card(inst)
		if not a.effects[0].target_spec.is_legal(g, ref, s) \
				or CombatState.block_illegality(g, inst, s, foe, true, pid) != "":
			continue
		var nested := g.undo_log != null
		var mark := g.make_mark()
		a.effects[0].resolve(g, s, pid, ref)
		g.recalculate()
		var after: float = pilot._cohort_value(g, attackers, blockers, foe)
		g.unmake_to(mark)
		if not nested:
			g.end_search()
		if after - before > 0.0 and (best.is_empty() or after - before > float(best["value"])):
			best = {"value": after - before, "targets": [ref]}
	return best


## "1 damage to target creature; that creature attacks this turn if able"
## (Bullwhip): a ping that kills — their creature one point from death.
static func ping_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window == "COMBAT" or window == "RESPONSE":
		return {}
	var pid: int = pilot.pid
	var best := {}
	for inst in g.players[g.opponent_of(pid)].battlefield:
		var ref := TargetRef.card(inst)
		if not inst.is_creature() or not a.effects[0].target_spec.is_legal(g, ref, s):
			continue
		if not bool(g.predict_damage(s, ref, 1, false, 0, pid)["dies"]):
			continue
		var value: float = float(pilot._victim_value(g, inst)) + 1.0
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	return best


## Our creature their spell or ability on the stack, or the combat damage
## about to be dealt, is killing: the most valuable one, or null.
static func _dying_creature(g: MtgGame, pilot, spec: TargetSpec, s: CardInstance) -> CardInstance:
	var pid: int = pilot.pid
	var best: CardInstance = null
	var best_value := 0.0
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		if top.controller == pid:
			return null
		var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
		var dmg := intent.damage_at(top.x_value)
		if dmg <= 0:
			return null
		for t in top.targets:
			if t == null or t.is_player or t.is_damage or t.is_ability:
				continue
			var inst := g.find_instance(t.instance_id)
			if inst == null or inst.controller_id != pid or not inst.is_creature() \
					or not intent.kills(inst, top.x_value):
				continue
			if spec != null and not spec.is_legal(g, TargetRef.card(inst), s):
				continue
			var value: float = pilot._own_value(g, inst)
			if value > best_value:
				best = inst
				best_value = value
		return best
	if g.combat.attackers.is_empty() or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or g.combat_damage_prevented:
		return null
	for inst in g.players[pid].battlefield:
		if not inst.is_creature() or not pilot._dies_in_combat(g, inst):
			continue
		if spec != null and not spec.is_legal(g, TargetRef.card(inst), s):
			continue
		var value: float = pilot._own_value(g, inst)
		if value > best_value:
			best = inst
			best_value = value
	return best


## "{T}: The next time a source of your choice would deal damage to target
## creature this turn, prevent that damage" (Samite Blessing's grant): our
## creature their damage — a spell on the stack, the combat about to be
## dealt — is killing. The source is named on resolution, the one about to
## hit it ([method MtgGame.choose_damage_source]).
static func blessing_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "RESPONSE" and window != "COMBAT":
		return {}
	var victim := _dying_creature(g, pilot, a.effects[0].target_spec, s)
	if victim == null:
		return {}
	return {"value": float(pilot._own_value(g, victim)) + 1.0, "targets": [TargetRef.card(victim)]}


## "Change the target of target spell or ability that targets only this
## creature. The new target must be a creature" (Silver Wyvern): THEIR
## hostile object aimed at it alone, with one of THEIR creatures a legal
## new target (the resolution's own hint lands a harmful object there).
static func wyvern_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "RESPONSE" or g.stack.is_empty():
		return {}
	var pid: int = pilot.pid
	var top: StackItem = g.stack.back()
	if top.controller == pid or not MtgGame.stack_item_targets_only(top, s):
		return {}
	var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
	if not intent.is_harmful():
		return {}
	var landing := 0.0
	for ref in g.single_target_retargets(top):
		if ref.is_player:
			continue
		var other := g.find_instance(ref.instance_id)
		if other != null and other.is_creature() and other.controller_id != pid:
			landing = maxf(landing, float(pilot._victim_value(g, other)) * 0.5)
	if landing <= 0.0:
		return {}
	var ref := TargetRef.ability(top) if top.kind != Mtg.StackKind.SPELL else TargetRef.card(top.card)
	if not a.effects[0].target_spec.is_legal(g, ref, s):
		return {}
	return {"value": float(pilot._own_value(g, s)) + landing, "targets": [ref]}


## "{1}, {T}: Put a magnet counter on target creature" (Magnetic Web: a
## creature with one that attacks drags every other magnet creature into
## the attack, and every magnet creature must BLOCK it). Bought at their
## end step: on our best attacker that wins a fight with each creature of
## theirs that could block it, once; then on THEIR creature that attacker
## kills and survives — its block next turn is a removal spell their own
## requirement pays for (and it attacking drags our magnet creature onto
## it, which the same fight decides our way).
static func magnet_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Dictionary:
	if window != "SINK":
		return {}
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var kind := "magnet"
	var e: EffectBase = a.effects[0]
	var hammer: CardInstance = null
	for inst in g.players[pid].battlefield:
		if inst.is_creature() and int(inst.counters.get(kind, 0)) > 0 \
				and pilot._could_attack_next_turn(g, inst, foe):
			if hammer == null or Evaluator.permanent_value(inst, pilot.profile) \
					> Evaluator.permanent_value(hammer, pilot.profile):
				hammer = inst
	if hammer == null:
		# The first counter: our attacker that beats everything of theirs
		# that could block it.
		var best := {}
		for inst in g.players[pid].battlefield:
			if inst == s or not inst.is_creature() or not pilot._could_attack_next_turn(g, inst, foe):
				continue
			var ref := TargetRef.card(inst)
			if not e.target_spec.is_legal(g, ref, s):
				continue
			var wins := false
			var loses := false
			for b in g.players[foe].battlefield:
				if not b.is_creature() or CombatState.block_illegality(g, b, inst, foe, true, pid) != "":
					continue
				if pilot._dies_to(g, inst, b):
					loses = true
				elif pilot._dies_to(g, b, inst):
					wins = true
			if loses or not wins:
				continue
			var value := 1.0
			if best.is_empty() or Evaluator.permanent_value(inst, pilot.profile) > float(best["worth"]):
				best = {"value": value, "targets": [ref], "bar": 0.5,
					"worth": Evaluator.permanent_value(inst, pilot.profile)}
		best.erase("worth")
		return best
	var out := {}
	for b in g.players[foe].battlefield:
		if not b.is_creature() or int(b.counters.get(kind, 0)) > 0:
			continue
		var ref := TargetRef.card(b)
		if not e.target_spec.is_legal(g, ref, s):
			continue
		if CombatState.block_illegality(g, b, hammer, foe, true, pid) != "":
			continue
		if not pilot._dies_to(g, b, hammer) or pilot._dies_to(g, hammer, b):
			continue
		var value: float = float(pilot._victim_value(g, b)) * 0.6
		if out.is_empty() or value > float(out["value"]):
			out = {"value": value, "targets": [ref], "bar": 0.5}
	return out


## "{G}, {T}: Reveal cards from the top of your library until you reveal a
## basic land card. Put that card into your hand and all other cards
## revealed this way into your graveyard" (Hermit Druid): a land when our
## hand has none and our lands are few — never from a thin library, since
## every card before the land is milled.
static func dig_land_option(g: MtgGame, pilot, s: CardInstance, window: String) -> Dictionary:
	var pid: int = pilot.pid
	var me := g.players[pid]
	if window == "COMBAT" or window == "RESPONSE" or me.library.size() < 15:
		return {}
	for card in me.hand:
		if card.data.is_land():
			return {}
	var lands := 0
	for perm in me.battlefield:
		if perm.is_land():
			lands += 1
	if lands >= 6:
		return {}
	if window == "MAIN" and g.active_player == pid and g.land_drop_available(pid):
		return {"value": 4.0, "targets": []}
	if window == "SINK":
		return {"value": 3.0, "targets": [], "bar": 0.5}
	return {}


## A -X/-X (or -0/-X) on target creature with no other job — Rabid Rats'
## "target blocking creature gets -1/-1" — read where it decides a fight:
## their blocks are in on our attack, and the shrink kills a blocker that
## would have lived or keeps our attacker alive (Knight of Valor's reading,
## [method MirageTactics.valor_option], aimed at one blocker).
static func shrinks_blocker(e: EffectBase) -> bool:
	return e is PumpEffect and not (e as PumpEffect).self_mode and e.target_spec != null \
		and (e as PumpEffect).toughness < 0 and (e as PumpEffect).power <= 0 \
		and (e as PumpEffect).granted_keywords.is_empty()


static func shrink_blocker_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var pid: int = pilot.pid
	if window != "RESPONSE" or g.active_player != pid \
			or g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers \
			or g.combat.attackers.is_empty():
		return null   # outside its fight, the shared readers keep their say
	var e: PumpEffect = a.effects[0]
	var shrink := Vector2i(e.power, e.toughness)
	var best := {}
	for attacker in pilot._declared_attackers(g):
		if attacker.controller_id != pid:
			continue
		for id in g.combat.blockers_of(attacker.id):
			var b := g.find_instance(id)
			if b == null or not g.is_present(b):
				continue
			var ref := TargetRef.card(b)
			if not e.target_spec.is_legal(g, ref, s):
				continue
			var value := 0.0
			if not pilot._dies_to(g, b, attacker) and pilot._dies_to(g, b, attacker, shrink):
				value += float(pilot._victim_value(g, b))
			if pilot._dies_to(g, attacker, b) \
					and not pilot._dies_to(g, attacker, b, Vector2i.ZERO, Vector2i(e.power, 0)):
				value += float(pilot._own_value(g, attacker))
			if value > 0.0 and (best.is_empty() or value > float(best["value"])):
				best = {"value": value, "targets": [ref]}
	return best


## What the unknown card a creature card put on top of our library
## replaces is worth — the average draw, never a peek at it.
const DRAW_WORTH := 2.0
## A body that leaves when its raiser untaps or leaves (Coffin Queen's
## leash: "when this creature becomes untapped or you lose control of
## this creature, exile that creature") is worth this share of itself.
const LEASH_SHARE := 0.6


## AN ACTIVATED REANIMATION (the Pack 9 bug pass, h6-10: Coffin Queen,
## Recurring Nightmare and Volrath's Stronghold were never activated — the
## shared scorer has no price for a [ReturnFromGraveyardEffect], whose
## spell form card_value prices): read off the typed effect, never a name.
##  * TO THE BATTLEFIELD (Recurring Nightmare, Coffin Queen): the best
##    creature card a legal target names, at its card worth — a body the
##    sacrifice and the "return this to hand" of the cost are charged
##    against by the shared scorer ([method AiPlayer._sacrifice_price]). A
##    raiser that may stay tapped to keep it ({T} and "you may choose not to
##    untap": the leash) gets [constant LEASH_SHARE] of it. In our main
##    phase, or with the mana of their end step.
##  * ON TOP OF THE LIBRARY (Volrath's Stronghold): that card instead of
##    the unknown next draw ([constant DRAW_WORTH]), with the mana of their
##    end step only.
## Graveyards are public; null for any other effect (a return to hand
## keeps the reading it had).
static func reanimate_option(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility,
		window: String) -> Variant:
	var e: EffectBase = a.effects[0]
	if not (e is ReturnFromGraveyardEffect) or e.target_spec == null:
		return null
	var to_battlefield: bool = (e as ReturnFromGraveyardEffect).to_battlefield_mode
	var to_top := not to_battlefield and e.describe().to_lower().contains("on top of")
	if not to_battlefield and not to_top:
		return null
	if to_top and window != "SINK":
		return {}
	if to_battlefield and window != "MAIN" and window != "SINK":
		return {}
	var best: TargetRef = null
	var best_worth := 0.0
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player:
			continue
		var card := g.find_instance(ref.instance_id)
		if card == null or card.zone != Mtg.Zone.GRAVEYARD or not card.data.is_creature():
			continue
		var worth := Evaluator.card_value(card.data)
		if best == null or worth > best_worth:
			best = ref
			best_worth = worth
	if best == null:
		return {}
	var value := best_worth
	if to_top:
		value -= DRAW_WORTH
		return {} if value <= 0.5 else {"value": value, "targets": [best], "bar": 0.5}
	if a.tap_cost and s.data.may_skip_untap:
		value *= LEASH_SHARE
	return {"value": value, "targets": [best]}


# ================================================================ spikes --

## THE SPIKE'S COUNTER (Pack 9 B3): "{c}, Remove a +1/+1 counter from this
## creature: <effect>" — [member ActivatedAbility.counter_cost_kind] is the
## +1/+1 counter and the creature's body is made of them (a 0/0 printed).
## The shared scorer never spends a body's counter ([method
## AiPlayer._counter_cost_spendable]); this module spends one only where
## the counter's worth is priced: when the Spike is about to die anyway
## ([method spike_save]) and when a counter moved off a Spike their board
## holds back onto an attacker it does not ([method spike_shift]).
static func is_spike_ability(a: ActivatedAbility) -> bool:
	return a != null and a.counter_cost_kind == "+1/+1" and a.object_costs.is_empty() \
		and not a.effects.is_empty()


## Can [param s]'s Spike ability at [param index] be activated now — the
## counter there, the timing, the mana — without asking the shared gate
## that refuses every body counter (this module prices it itself)?
static func spike_ready(g: MtgGame, pilot, s: CardInstance, index: int) -> bool:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if not is_spike_ability(a):
		return false
	if int(s.counters.get("+1/+1", 0)) < maxi(a.counter_cost_count, 1):
		return false
	return ability_ready(g, pilot, s, index, true)


## Can [param s]'s ability [param index] be activated by the pilot now —
## for the arms that activate directly from a moment ([method respond],
## [method end_step_action]) and price their own cost: the timing riders,
## the tap, the mana, a per-turn cap, nothing refused this step; no life,
## sacrifice, discard or object cost (those stay the shared scorer's), and
## a counter cost only when [param counter_ok], and sacrificing the source
## itself only when [param self_sacrifice_ok].
static func ability_ready(g: MtgGame, pilot, s: CardInstance, index: int,
		counter_ok := false, self_sacrifice_ok := false) -> bool:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if s.zone != a.activation_zone or s.phased_out:
		return false
	if a.only_opponents_may_activate or (a.only_owner_may_activate and s.owner_id != pilot.pid):
		return false
	if a.activator_condition.is_valid() and a.activator_condition.call(g, s, pilot.pid) != "":
		return false
	if pilot._refused.has("%d:%d" % [s.id, index]):
		return false
	if a.tap_cost and (s.tapped or (s.is_creature() and s.summoning_sick
			and not s.has_keyword(Mtg.Keyword.HASTE))):
		return false
	if a.sacrifice_cost and not self_sacrifice_ok:
		return false
	if a.life_cost > 0 or a.sacrifice_filter.is_valid() \
			or a.discard_cost > 0 or a.random_discard_cost > 0 or a.cost.has_x \
			or not a.object_costs.is_empty() or a.tap_permanent_count > 0 \
			or a.exile_cost or a.exile_filter.is_valid() or a.library_exile_cost > 0:
		return false
	if a.counter_cost_kind != "" and not counter_ok:
		return false
	if g.ability_timing_refusal(pilot.pid, s, a) != "":
		return false
	if a.max_per_turn > 0 and int(s.ability_uses.get(index, 0)) >= a.max_per_turn:
		return false
	var pay := g.ability_payment(pilot.pid, s, index, 0)
	if pilot._cost_is_free(pay.cost) and int(pay.extra) == 0:
		return true
	var sources: Array = pilot._mana_sources(g)
	if a.tap_cost:
		sources = sources.filter(func(row: Array) -> bool: return row[0] != s)
	return g.players[pilot.pid].mana_pool.can_pay(pay.cost, int(pay.extra), pay.usage) \
		or not pilot._plan_taps_from(sources, pay.cost, int(pay.extra), pay.usage).is_empty()


## Pay for and activate [param s]'s ability [param index] at [param targets];
## the action line or "".
static func activate_direct(g: MtgGame, pilot, s: CardInstance, index: int,
		targets: Array, verb: String) -> String:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	var pay := g.ability_payment(pilot.pid, s, index, 0)
	if not (pilot._cost_is_free(pay.cost) and int(pay.extra) == 0) \
			and not pilot._plan_and_pay(g, pay.cost, int(pay.extra), pay.usage,
				pilot._tap_spared(s, a)):
		return ""
	var err := g.activate_ability(pilot.pid, s, index, targets)
	if err != "":
		g.log_line("(AI activation of %s refused: %s)" % [s.data.card_name, err])
		pilot._refused["%d:%d" % [s.id, index]] = true
		return ""
	return "activated %s: %s" % [s.data.card_name, verb]


## The creature of ours a moved +1/+1 counter does the most for: the most
## valuable one that is not [param spike], not dying in the combat being
## fought and a legal target of [param e]; null when there is none. With
## the combat's [param future] ([method combat_forecast]) "dying" is the
## forecast's word, not the one-pair reading's.
static func counter_home(g: MtgGame, pilot, spike: CardInstance, e: EffectBase,
		future: Dictionary = {}) -> CardInstance:
	var best: CardInstance = null
	var best_value := -INF
	for inst in g.players[pilot.pid].battlefield:
		if inst == spike or not inst.is_creature() or inst.phased_out:
			continue
		if e.target_spec != null and not e.target_spec.is_legal(g, TargetRef.card(inst), spike):
			continue
		var fighting: bool = g.combat.attackers.has(inst.id) or g.combat.blocks.has(inst.id)
		if fighting and not future.is_empty():
			if not future["alive"].has(inst.id):
				continue
		elif fighting and g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers \
				and pilot._dies_in_combat(g, inst):
			continue
		var value: float = Evaluator.permanent_value(inst, pilot.profile)
		if value > best_value:
			best_value = value
			best = inst
	return best


## THE COMBAT, READ ONCE (the Pack 9 study fix, 2026-10-06): the game's own
## damage forecast of the combat now declared ([method
## MtgGame.forecast_damage] — the division of an attacker's damage among
## its blockers, CR 510.1c; first strike, CR 510.4; prevention; a
## regeneration shield), or {} outside a declared combat's damage window
## or with the stack not empty. Public board only: the forecast seats
## default agents for both players and runs under the search journal.
static func combat_forecast(g: MtgGame) -> Dictionary:
	if g.combat.attackers.is_empty() or g.awaiting_blockers or g.combat_damage_prevented \
			or not g.stack.is_empty() or g.game_over \
			or not g.current_step() in [Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.FIRST_STRIKE_DAMAGE]:
		return {}
	return g.forecast_damage(true)


## Is [param spike] about to leave the battlefield, and how: "" when not,
## "stack" for THEIR spell or ability on top of the stack that removes,
## bounces or kills it ("stack_final" when it also forbids regeneration),
## "combat" for the combat damage about to be dealt — read off the
## combat's [param future] ([method combat_forecast], computed here when
## not given). The study's seed 98154: the one-pair reading ([method
## AiPlayer._dies_in_combat]) charged each of two Spike Feeders blocking
## a Youthful Knight with the Knight's whole two points, so both were
## "doomed" and both cashed out; the Knight kills one.
static func spike_threat(g: MtgGame, pilot, spike: CardInstance,
		future: Dictionary = {}) -> String:
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		if top.controller == pilot.pid or top.targets.is_empty():
			return ""
		var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
		for t in top.targets:
			if t == null or t.is_player or t.is_damage or t.is_ability or t.instance_id != spike.id:
				continue
			if intent.bounces:
				return "stack_final"
			if intent.removes:
				return "stack_final" if intent.removal_ignores_regeneration else "stack"
			if intent.damage_at(top.x_value) > 0 and intent.kills(spike, top.x_value):
				return "stack"
		return ""
	if not g.combat.attackers.has(spike.id) and not g.combat.blocks.has(spike.id):
		return ""
	if future.is_empty():
		future = combat_forecast(g)
	if future.is_empty():
		return ""
	return "" if future["alive"].has(spike.id) else "combat"


## THE SPIKE THAT DIES ANYWAY: its counters are worth nothing in the
## graveyard, so each one buys what its abilities offer — a regeneration
## shield on itself where the threat allows one and the body survives the
## counter it pays, else a counter moved to our best other creature, a
## token, life. One activation per call; the next call (after it resolves)
## spends the next counter.
##
## IN A DECLARED COMBAT the counters ARE the Spike's damage (the Pack 9
## study, 2026-10-06: -9.5 +- 7.6 points, Spikes v Licids, seed 98100 — a
## Feeder trading with a 2/2 gained four life, shrank to nothing, and the
## 2/2 lived). There each counter is priced on the forecast ([method
## spike_combat_option]): spent only when the combat with it gone, and
## what it buys on the board, is no worse — so the counters a kill needs
## stay on the Spike, and a Spike whose kill is impossible still cashes
## out.
static func spike_save(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var future := {}
	for spike in g.players[pid].battlefield:
		if not spike.is_creature() or int(spike.counters.get("+1/+1", 0)) <= 0:
			continue
		if future.is_empty() and g.stack.is_empty() \
				and (g.combat.attackers.has(spike.id) or g.combat.blocks.has(spike.id)):
			future = combat_forecast(g)
		var threat := spike_threat(g, pilot, spike, future)
		if threat == "":
			continue
		var best := {}
		for index in spike.cur_activated_abilities.size():
			var a: ActivatedAbility = spike.cur_activated_abilities[index]
			if not is_spike_ability(a) or not spike_ready(g, pilot, spike, index):
				continue
			var e: EffectBase = a.effects[0]
			var value := 0.0
			var targets: Array = []
			if threat == "combat":
				var priced := spike_combat_option(g, pilot, spike, index, future)
				if priced.is_empty():
					continue
				value = float(priced["value"])
				targets = priced["targets"]
			elif e is RegenerateEffect:
				# The shield saves the Spike itself — unless the threat
				# forbids it, or paying the counter already kills it.
				if threat == "stack_final" or spike.regeneration_shields > 0 \
						or spike.cur_toughness - 1 - spike.damage <= 0:
					continue
				value = float(pilot._own_value(g, spike)) + 1.0
			elif e is CounterMarkerEffect and (e as CounterMarkerEffect).kind == "+1/+1":
				var home := counter_home(g, pilot, spike, e)
				if home == null:
					continue
				value = 1.5
				targets = [TargetRef.card(home)]
			elif e is CreateTokenEffect:
				value = 2.0
			elif e is GainLifeEffect:
				value = float((e as GainLifeEffect).amount) * pilot._life_price(g.players[pid].life)
			else:
				continue
			if e.target_spec != null and targets.is_empty():
				continue
			if best.is_empty() or value > float(best["value"]):
				best = {"value": value, "index": index, "targets": targets}
		if best.is_empty():
			continue
		var done := activate_direct(g, pilot, spike, int(best["index"]), best["targets"],
			"a counter spent before %s leaves" % spike.data.card_name)
		if done != "":
			return done
	return ""


## A doomed Spike's ability [param index] in a declared combat, priced on
## the forecast: [param before] ([method combat_forecast]) against the
## combat with the counter paid off [param spike] and what the ability
## buys put on the board under the search journal — a regeneration
## shield on itself, a counter on our best surviving creature ([method
## counter_home]), its own pump, life, a Fog — scored by [method
## HomelandsTactics.swing] (bodies saved or lost on both sides, life),
## plus what outlasts the combat: the moved counter on a creature that
## lives, a token. `{value, targets}` when that is better than nothing,
## {} otherwise — a counter its kill needs costs that kill in the swing
## and stays. An effect not read here is never spent in combat.
static func spike_combat_option(g: MtgGame, pilot, spike: CardInstance, index: int,
		before: Dictionary) -> Dictionary:
	var a: ActivatedAbility = spike.cur_activated_abilities[index]
	var e: EffectBase = a.effects[0]
	var pid: int = pilot.pid
	var home: CardInstance = null
	var lasting := 0.0
	if e is CounterMarkerEffect and (e as CounterMarkerEffect).kind == "+1/+1":
		home = counter_home(g, pilot, spike, e, before)
		if home == null:
			return {}
	elif e is CreateTokenEffect:
		lasting = 2.0
	elif e is PumpEffect:
		if not (e as PumpEffect).self_mode or (e as PumpEffect).use_x_power:
			return {}
	elif not (e is RegenerateEffect or e is GainLifeEffect or e is PreventCombatDamageEffect):
		return {}
	if e is PreventCombatDamageEffect and (e as PreventCombatDamageEffect).targeted_mode:
		return {}
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec(spike, &"counters")
	var left := int(spike.counters.get("+1/+1", 0)) - maxi(a.counter_cost_count, 1)
	if left > 0:
		spike.counters["+1/+1"] = left
	else:
		spike.counters.erase("+1/+1")
	if e is RegenerateEffect:
		g._rec(spike, &"regeneration_shields")
		spike.regeneration_shields += 1
	elif home != null:
		g._rec(home, &"counters")
		home.counters["+1/+1"] = int(home.counters.get("+1/+1", 0)) + 1
	elif e is PumpEffect:
		g.continuous.add_until_eot_pump(spike.id, (e as PumpEffect).power,
			(e as PumpEffect).toughness, (e as PumpEffect).granted_keywords)
	elif e is GainLifeEffect:
		g._rec(g.players[pid], &"life")
		g.players[pid].life += (e as GainLifeEffect).amount
	elif e is PreventCombatDamageEffect:
		g._rec(g, &"combat_damage_prevented")
		g.combat_damage_prevented = true
	g.recalculate()
	var after := g.forecast_damage(true)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	var value: float = HOMELANDS_TACTICS.swing(g, pilot, before, after) + lasting
	if home != null and after["alive"].has(home.id):
		value += 1.5
	if value <= 0.0:
		return {}
	return {"value": value, "targets": [TargetRef.card(home)] if home != null else []}


## THE COUNTER MOVED TO WHERE IT HITS: at their end step (mana the untap
## step would waste), a Spike their untapped creatures can block hands a
## +1/+1 counter to an attacker of ours none of them can block — a point
## of damage every turn instead of a point of a body that is stopped.
## The Spike keeps its last counter (the move that empties it kills it).
static func spike_shift(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var blockers: Array[CardInstance] = []
	for inst in g.players[foe].battlefield:
		if inst.is_creature():
			blockers.append(inst)
	if blockers.is_empty():
		return ""
	for spike in g.players[pid].battlefield:
		if not spike.is_creature() or int(spike.counters.get("+1/+1", 0)) < 2:
			continue
		if not _blockable_by(g, spike, blockers, foe, pid):
			continue
		for index in spike.cur_activated_abilities.size():
			var a: ActivatedAbility = spike.cur_activated_abilities[index]
			if not is_spike_ability(a) or not spike_ready(g, pilot, spike, index):
				continue
			var e: EffectBase = a.effects[0]
			if not (e is CounterMarkerEffect and (e as CounterMarkerEffect).kind == "+1/+1"):
				continue
			var best: CardInstance = null
			for inst in g.players[pid].battlefield:
				if inst == spike or not pilot._could_attack_next_turn(g, inst, foe) \
						or inst.cur_power <= 0:
					continue
				if not e.target_spec.is_legal(g, TargetRef.card(inst), spike):
					continue
				if _blockable_by(g, inst, blockers, foe, pid):
					continue
				if best == null or Evaluator.permanent_value(inst, pilot.profile) \
						> Evaluator.permanent_value(best, pilot.profile):
					best = inst
			if best == null:
				continue
			var done := activate_direct(g, pilot, spike, index, [TargetRef.card(best)],
				"a counter onto %s" % best.data.card_name)
			if done != "":
				return done
	return ""


static func _blockable_by(g: MtgGame, attacker: CardInstance, blockers: Array[CardInstance],
		defender: int, attacking: int) -> bool:
	for b in blockers:
		if CombatState.block_illegality(g, b, attacker, defender, true, attacking) == "":
			return true
	return false


# ================================================== the moments' roles --

## The first ability of [param s] whose effect carries [param role] and can
## be activated now, or -1.
static func _role_index(g: MtgGame, pilot, s: CardInstance, role: StringName,
		self_sacrifice_ok := false) -> int:
	for index in s.cur_activated_abilities.size():
		var a: ActivatedAbility = s.cur_activated_abilities[index]
		if a.effects.is_empty() or a.effects[0].ai_role != role:
			continue
		if ability_ready(g, pilot, s, index, false, self_sacrifice_ok):
			return index
	return -1


## Points of damage already booked away from [param inst] by redirect
## effects on the table ([member MtgGame.damage_effects]).
static func _booked_away(g: MtgGame, inst: CardInstance) -> int:
	var n := 0
	for e in g.damage_effects:
		if StringName(e.get("kind", &"")) != &"redirect":
			continue
		for v in e.get("victims", []):
			if int((v as Dictionary).get("id", -1)) == inst.id:
				n += int(e.get("points_left", e.get("points", 0)))
	return n


## Points of damage already booked onto [param inst] by redirect effects.
static func _booked_onto(g: MtgGame, inst: CardInstance) -> int:
	var n := 0
	for e in g.damage_effects:
		if StringName(e.get("kind", &"")) == &"redirect" \
				and int((e.get("to", {}) as Dictionary).get("id", -1)) == inst.id:
			n += int(e.get("points_left", e.get("points", 0)))
	return n


## The damage about to land on our [param inst]: their spell or ability on
## top of the stack naming it, else the combat damage of declared blocks.
static func _incoming_to(g: MtgGame, pilot, inst: CardInstance) -> int:
	if not g.stack.is_empty():
		var top: StackItem = g.stack.back()
		if top.controller == pilot.pid:
			return 0
		var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
		for t in top.targets:
			if t != null and not t.is_player and not t.is_damage and not t.is_ability \
					and t.instance_id == inst.id:
				return intent.damage_at(top.x_value)
		return 0
	if g.combat.attackers.is_empty() or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or g.combat_damage_prevented:
		return 0
	if not g.combat.attackers.has(inst.id) and not g.combat.blocks.has(inst.id):
		return 0
	return int(pilot._combat_damage_to(g, inst))


## THE EN-KOR: "{0}: The next 1 damage that would be dealt to this
## creature this turn is dealt to target creature you control instead" —
## damage about to kill it (a burn spell of theirs, the combat damage of
## its block) is moved, a point an activation, onto our creature that
## takes it and lives; the points already booked are counted, so the
## activations stop where the en-Kor survives — and none starts when our
## creatures cannot take enough of it to save the en-Kor.
static func en_kor_save(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	for enkor in g.players[pid].battlefield:
		if not enkor.is_creature():
			continue
		var index := _role_index(g, pilot, enkor, &"redirect_point_to_own")
		if index < 0:
			continue
		var incoming := _incoming_to(g, pilot, enkor)
		if incoming <= 0:
			continue
		var room := enkor.cur_toughness - enkor.damage - 1 + enkor.prevention
		var needed := incoming - room - _booked_away(g, enkor)
		if needed <= 0:
			continue
		var spec: TargetSpec = enkor.cur_activated_abilities[index].effects[0].target_spec
		var home: CardInstance = null
		var home_room := 1
		var capacity := 0
		for inst in g.players[pid].battlefield:
			if inst == enkor or not inst.is_creature() \
					or not spec.is_legal(g, TargetRef.card(inst), enkor):
				continue
			var left := inst.cur_toughness - inst.damage - _booked_onto(g, inst) \
				- _incoming_to(g, pilot, inst)
			capacity += maxi(left - 1, 0)
			if left > home_room:
				home = inst
				home_room = left
		# Only a save that saves: the points our creatures can take and live
		# must cover what the en-Kor cannot.
		if home == null or capacity < needed:
			continue
		var done := activate_direct(g, pilot, enkor, index, [TargetRef.card(home)],
			"a point of damage onto %s" % home.data.card_name)
		if done != "":
			return done
	return ""


## SOLTARI GUERRILLAS: "{0}: The next time this creature would deal combat
## damage to an opponent this turn, it deals that damage to target creature
## instead" — our attacker is unblocked, and the creature of theirs its
## damage kills is worth more than the damage to their face. Never while
## the combat as declared is lethal (the bug pass, h1-4: four unblocked
## shades dealing exactly their last 10 had 3 of it turned onto a
## creature): the game's own forecast of the combat ([method
## combat_forecast]) says so, every attacker counted.
static func guerrilla_redirect(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player != pid or g.current_step() != Mtg.Step.DECLARE_BLOCKERS \
			or g.awaiting_blockers or not g.stack.is_empty() or g.combat_damage_prevented:
		return ""
	var foe := g.opponent_of(pid)
	var lethal_checked := false
	for attacker in pilot._declared_attackers(g):
		if attacker.controller_id != pid or attacker.cur_power <= 0 \
				or g.combat.was_blocked(g.combat.band_of(attacker.id)):
			continue
		var index := _role_index(g, pilot, attacker, &"combat_damage_to_creature")
		if index < 0:
			continue
		var already := false
		for e in g.damage_effects:
			if int(e.get("source_id", -1)) == attacker.id:
				already = true
		if already:
			continue
		var spec: TargetSpec = attacker.cur_activated_abilities[index].effects[0].target_spec
		var face: float = pilot._face_damage_value(g, attacker.cur_power, foe)
		if attacker.cur_power >= g.players[foe].life:
			continue   # the face is the game
		if not lethal_checked:
			lethal_checked = true
			var future := combat_forecast(g)
			if not future.is_empty() and int(future["life"][foe]) <= 0:
				return ""   # the whole combat is the game
		var best: CardInstance = null
		var best_value := 0.5
		for inst in g.players[foe].battlefield:
			var ref := TargetRef.card(inst)
			if not inst.is_creature() or not spec.is_legal(g, ref, attacker):
				continue
			if not bool(g.predict_damage(attacker, ref, attacker.cur_power, false, 0, pid)["dies"]):
				continue
			var value: float = float(pilot._victim_value(g, inst)) - face
			if value > best_value:
				best = inst
				best_value = value
		if best == null:
			continue
		var done := activate_direct(g, pilot, attacker, index, [TargetRef.card(best)],
			"its combat damage goes to %s" % best.data.card_name)
		if done != "":
			return done
	return ""


## Is our [param inst] about to be removed by THEIR object on top of the
## stack — a targeted removal, bounce or killing damage, or a sweeper that
## reaches it?
static func _removal_aimed_at(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if g.stack.is_empty():
		return false
	var top: StackItem = g.stack.back()
	if top.controller == pilot.pid:
		return false
	var intent := EffectIntent.read(top.effects, top.card.data.card_name if top.card != null else "")
	if intent.sweeper != null:
		var scope := preload("res://engine/ai/mirage_tactics.gd").sweep_scope(g, intent.sweeper, top.controller)
		if scope < 0 or scope == pilot.pid:
			return true
	for t in top.targets:
		if t == null or t.is_player or t.is_damage or t.is_ability or t.instance_id != inst.id:
			continue
		if intent.removes or intent.bounces:
			return true
		if intent.damage_at(top.x_value) > 0 and intent.kills(inst, top.x_value):
			return true
	return false


## COLD STORAGE: "{3}: Exile target creature you control" — our creature
## their removal is aimed at, worth the mana, goes into storage in
## response ([method stash_release] brings it back).
static func stash_save(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	for box in g.players[pid].battlefield:
		var index := _role_index(g, pilot, box, &"stash_own_creature")
		if index < 0:
			continue
		var spec: TargetSpec = box.cur_activated_abilities[index].effects[0].target_spec
		var best: CardInstance = null
		var best_value := 3.0
		for inst in g.players[pid].battlefield:
			if inst == box or not inst.is_creature() or inst.is_token \
					or not spec.is_legal(g, TargetRef.card(inst), box):
				continue
			if not _removal_aimed_at(g, pilot, inst):
				continue
			var value: float = pilot._own_value(g, inst)
			if value > best_value:
				best = inst
				best_value = value
		if best == null:
			continue
		var done := activate_direct(g, pilot, box, index, [TargetRef.card(best)],
			"%s into storage" % best.data.card_name)
		if done != "":
			return done
	return ""


## COLD STORAGE'S RETURN: "Sacrifice this artifact: Return each creature
## card exiled with this artifact to the battlefield under your control" —
## at their end step, once a stored creature card is waiting.
static func stash_release(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	for box in g.players[pid].battlefield:
		var index := _role_index(g, pilot, box, &"release_stash", true)
		if index < 0:
			continue
		var stored := 0.0
		for p in g.players:
			for card in p.exile:
				var link: Array = card.memory.get("cold_storage", [])
				if link.size() == 3 and int(link[0]) == box.id and card.data.is_creature():
					stored += Evaluator.card_value(card.data)
		if stored < Evaluator.permanent_value(box, pilot.profile) + 1.0:
			continue
		var done := activate_direct(g, pilot, box, index, [], "the stored creatures return")
		if done != "":
			return done
	return ""


## MADDENING IMP: "{T}: Non-Wall creatures the active player controls
## attack this turn if able. At the beginning of the next end step, destroy
## each of those creatures that didn't attack this turn. Activate only
## during an opponent's turn and only before combat." Asked in their turn
## before combat, the stack empty: every non-Wall creature of theirs that
## CANNOT attack (summoning sick, tapped, held back) is destroyed at the end
## step, and every one that can attacks into our untapped creatures; worth
## the bodies lost to the doom and to our good blocks, less the damage
## their forced attack puts through — never when that damage is lethal.
static func madden(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if g.active_player == pid or not g.stack.is_empty() \
			or g.current_step() >= Mtg.Step.COMBAT_BEGIN:
		return ""
	var foe := g.opponent_of(pid)
	for imp in g.players[pid].battlefield:
		var index := _role_index(g, pilot, imp, &"forces_attacks")
		if index < 0:
			continue
		var doomed := 0.0
		var attackers: Array[CardInstance] = []
		for inst in g.players[foe].battlefield:
			if not inst.is_creature() or inst.has_subtype("wall"):
				continue
			if CombatState.attack_illegality(g, inst, pid) != "":
				doomed += float(pilot._victim_value(g, inst))
			else:
				attackers.append(inst)
		var blockers: Array[CardInstance] = []
		for inst in g.players[pid].battlefield:
			if inst.is_creature() and inst != imp and not inst.tapped:
				blockers.append(inst)
		var through: int = pilot._damage_through_blocks(g, attackers, blockers, pid) \
			if not attackers.is_empty() else 0
		if through >= g.players[pid].life:
			continue
		var eaten := 0.0
		for inst in attackers:
			for b in blockers:
				if pilot._dies_to(g, inst, b) and not pilot._dies_to(g, b, inst):
					eaten += float(pilot._victim_value(g, inst)) * 0.5
					break
		var value: float = doomed + eaten - float(through) * pilot._life_price(g.players[pid].life)
		if value < 3.0:
			continue
		var done := activate_direct(g, pilot, imp, index, [],
			"their creatures attack or die")
		if done != "":
			return done
	return ""


# ============================================================ the moments --

## THE RESPONSE ARM, asked first by [method MirageTactics.respond]: one
## Tempest action, or "".
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var done := licid_save(g, pilot)
	if done != "":
		return done
	done = spike_save(g, pilot)
	if done != "":
		return done
	done = en_kor_save(g, pilot)
	if done != "":
		return done
	done = stash_save(g, pilot)
	if done != "":
		return done
	done = guerrilla_redirect(g, pilot)
	if done != "":
		return done
	done = madden(g, pilot)
	if done != "":
		return done
	done = evasion_trick(g, pilot)
	if done != "":
		return done
	return deny_evasion(g, pilot)


## Our main phase, nothing cast: the special actions that open the
## combat (asked by [method MirageTactics.lion_eye_action]).
static func main_action(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	return curse_action(g, pilot)


## Their end step, the stack empty (asked by [method
## MirageTactics.pay_ransom]): the stored creatures brought back, a
## Spike's counter moved onto an attacker their board cannot block.
static func end_step_action(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var done := stash_release(g, pilot)
	if done != "":
		return done
	return spike_shift(g, pilot)
