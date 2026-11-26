extends RefCounted
## WHAT A COMBAT IS WORTH TO A BODY THAT WILL NOT BE HERE TOMORROW, AND WHAT
## A BLOCK STOPS OF A TRAMPLER (player report 2026-11-26: "casts Ball
## Lightning before combat but then doesn't attack with it if it would die
## in combat", "doesn't seem to understand how trample works and doesn't
## block with it in mind"). No card is named: every reading is a printed
## end-step line on the body, the engine's own public end-step doom list,
## and the bodies on the table.
##
##  * THE BODY GONE AT END OF TURN ANYWAY ("At the beginning of the end
##    step, sacrifice this creature." — Ball Lightning; a body an effect
##    condemned for the next end step — Sneak Attack's creature, a fourth
##    breath's Dragon Whelp): staying home saves nothing, so it attacks
##    whenever it has power ([method sent_regardless], asked by
##    [method AiPlayer._conscripted]), its death in combat is priced at
##    nothing on either side of the table ([method worthless_tomorrow]),
##    and it is no blocker on their turn ([method fleeting]).
##  * THE BODY BACK IN HAND AT END OF TURN ("At the beginning of the end
##    step, return this creature to its owner's hand." — Viashino
##    Sandstalker): the card is kept, so its death still costs it; but it
##    blocks nothing by staying home either, so it attacks unless a blocker
##    over there stops it cold ([method stopped_cold]).
##  * … AND NEITHER IS CAST FOR NOTHING ([method cast_refusal]): not after
##    combat, not without haste, not into a blocker that stops it cold.
##  * THE TRAMPLER'S SPILL WHEN THE SWING IS LETHAL ([method
##    hold_the_line]): a throwaway block stops only the blocker's toughness
##    of a trampler, so the block ladder's one cheapest chump is not the
##    block that keeps the pilot alive. When the planned blocks still let
##    lethal damage through, the spare bodies are added where they soak the
##    most, the plan is kept only if the pilot then lives, and a body whose
##    block then soaks nothing more is taken back out.
##
## All of it behind [member AiProfile.forecasts_tactics], which every
## standard rung ships on: the gate off is the pilot as it was. A table
## with no such body and no trampler asks nothing here beyond one pass
## over a candidate's own triggers.

## What [method fleeting] answers.
const STAYS := 0
## Sacrificed, destroyed or exiled at the end step: the card is lost.
const LOST := 1
## Returned to its owner's hand at the end step: the card is kept.
const RETURNED := 2

const _SACRIFICE_LINE := "sacrifice this creature"
const _RETURN_LINE := "return this creature to its owner's hand"


## The printed end-step line of [param data] itself: [constant LOST],
## [constant RETURNED] or [constant STAYS]. An unconditional trigger only
## (Pestilence's "if there are no creatures" is another card).
static func printed_fleeting(data: CardData) -> int:
	if data.triggered_abilities.is_empty():
		return STAYS
	return _read_triggers(data.triggered_abilities, data.card_name)


## Is [param inst], on the battlefield, gone at this turn's end step
## whatever it does — by its own live end-step trigger, or by the engine's
## end-step doom list (an unconditional entry: Berserk's "if it attacked"
## and Nettling Imp's "if it did not" are decisions, not fates)?
static func fleeting(g: MtgGame, inst: CardInstance) -> int:
	if inst == null:
		return STAYS
	if g.is_doomed_at_end_step(inst) \
			and not g._end_step_doom_if_attacked.has(inst.id) \
			and not g._end_step_doom_unless_attacked.has(inst.id) \
			and (g._end_step_doom_sacrifice.has(inst.id) or not inst.cur_indestructible):
		return LOST
	if inst.cur_triggered_abilities.is_empty():
		return STAYS
	return _read_triggers(inst.cur_triggered_abilities, inst.data.card_name)


static func _read_triggers(triggers: Array, card_name: String) -> int:
	for trigger in triggers:
		if trigger.event_type != Mtg.EventType.END_STEP_START or trigger.condition.is_valid():
			continue
		var lower: String = String(trigger.text).to_lower()
		if lower.contains(_SACRIFICE_LINE) or lower.contains("sacrifice " + card_name.to_lower()):
			return LOST
		if lower.contains(_RETURN_LINE):
			return RETURNED
	return STAYS


## Is the card of [param inst] lost at the end step whatever happens — so
## that its death in combat costs its controller nothing and killing it
## gains the other side nothing?
static func worthless_tomorrow(g: MtgGame, inst: CardInstance) -> bool:
	return fleeting(g, inst) == LOST


## Does the pilot send [param inst] whatever the exchange analysis said?
## A body lost at the end step always (it has power, and attacking is
## free); one returned to hand unless a blocker stops it cold.
static func sent_regardless(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if inst == null or inst.cur_power <= 0 or not inst.is_creature():
		return false
	var kind := fleeting(g, inst)
	if kind == STAYS:
		return false
	if not inst.cur_attack_costs.is_empty() or inst.cur_attack_land_sacrifices > 0:
		return false   # an attack that costs something is priced as any other
	if kind == LOST:
		return true
	return not stopped_cold(g, pilot, inst)


## Does an untapped creature across the table block [param inst] and live
## through it — so the attack lands nothing and kills nothing? The engine's
## own block legality and the pilot's own kill test.
static func stopped_cold(g: MtgGame, pilot, inst: CardInstance) -> bool:
	var defender := g.opponent_of(inst.controller_id)
	for blocker in g.players[defender].battlefield:
		if not blocker.is_creature() or blocker.tapped or blocker.phased_out:
			continue
		if CombatState.block_illegality(g, blocker, inst, defender, true, inst.controller_id) != "":
			continue
		if not pilot._dies_to(g, blocker, inst):
			return true
	return false


## Why [param inst], a card in the pilot's hand, is not cast in this
## position ("" when nothing here objects) — one of [method
## AiPlayer._cast_gate]'s questions. Only a creature whose whole point is
## this turn's attack is judged: one with an arrival trigger or an ability
## to activate has other reasons to be cast.
static func cast_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var data: CardData = inst.data
	if not data.is_creature() or printed_fleeting(data) == STAYS:
		return ""
	if g.active_player != pilot.pid or not data.activated_abilities.is_empty():
		return ""
	for trigger in data.triggered_abilities:
		if trigger.event_type != Mtg.EventType.END_STEP_START:
			return ""
	if g.current_step() != Mtg.Step.MAIN1 or g.no_attacks_this_turn:
		return "it would be gone before it could attack"
	if not data.keywords.has(Mtg.Keyword.HASTE):
		return "it has no haste to attack with"
	var defender := g.opponent_of(pilot.pid)
	var flies := data.keywords.has(Mtg.Keyword.FLYING)
	var first := data.keywords.has(Mtg.Keyword.FIRST_STRIKE)
	for blocker in g.players[defender].battlefield:
		if not blocker.is_creature() or blocker.tapped or blocker.phased_out:
			continue
		if flies and not blocker.has_keyword(Mtg.Keyword.FLYING) \
				and not blocker.has_keyword(Mtg.Keyword.REACH):
			continue
		# It is struck down before it deals anything...
		if not first and blocker.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
				and blocker.cur_power >= data.toughness:
			return "a first striker would stop it cold"
		# ...or the blocker lives through all of it (so nothing tramples over).
		if blocker.cur_toughness - blocker.damage > data.power:
			return "a blocker would stop it cold"
	return ""


# ------------------------------------------------------ the trampler's spill --

## What [param plan] (blocker id -> attacker id) lets through to the
## pilot: an unblocked attacker's power, and a blocked trampler's power
## less what its blockers soak ([method AiPlayer._absorbed_by], the
## reading the panic line uses).
static func damage_through(g: MtgGame, pilot, attackers: Array[CardInstance],
		plan: Dictionary, shares: Dictionary = {}) -> int:
	var total := 0
	for attacker in attackers:
		var band: Array[CardInstance] = []
		for blocker_id in plan:
			if int(plan[blocker_id]) != attacker.id:
				continue
			var body := g.find_instance(int(blocker_id))
			if body != null:
				band.append(body)
		var power := maxi(attacker.cur_power, 0)
		if band.is_empty() or attacker.cur_damage_as_unblocked_forced:
			total += power
		elif attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			var soaked := 0
			for body in band:
				soaked += pilot._absorbed_by(g, body, attacker, shares, band)
			total += maxi(power + pilot._rampage_bonus(attacker, band.size(), g) - soaked, 0)
	return total


## [param plan], the block ladder's answer, REPAIRED when a trampler makes
## it a losing one: the planned blocks still let lethal damage through, and
## spare bodies stacked where they soak the most stop enough of it. The
## blockers it adds are appended to [param used]. Unchanged when no
## attacker tramples, when the plan already keeps the pilot alive, and when
## nothing does.
static func hold_the_line(g: MtgGame, pilot, attackers: Array[CardInstance],
		free: Array[CardInstance], plan: Dictionary, used: Array[int],
		shares: Dictionary = {}) -> Dictionary:
	if not pilot.profile.forecasts_tactics:
		return plan
	var tramples := false
	for attacker in attackers:
		if attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			tramples = true
			break
	if not tramples:
		return plan
	var life: int = g.players[pilot.pid].life
	var through := damage_through(g, pilot, attackers, plan, shares)
	if through < life:
		return plan
	var out := plan.duplicate()
	var spare: Array[CardInstance] = []
	for body in free:
		if not out.has(body.id) and not used.has(body.id):
			spare.append(body)
	while through >= life and not spare.is_empty():
		if g.max_blockers > 0 and out.size() >= g.max_blockers:
			break
		var best_body: CardInstance = null
		var best_attacker: CardInstance = null
		var best_left := through
		for body in spare:
			for attacker in attackers:
				if CombatState.block_illegality(g, body, attacker, pilot.pid) != "":
					continue
				var cap: int = pilot._blocker_cap(g, attacker)
				if cap > 0 and _band_size(out, attacker) >= cap:
					continue
				out[body.id] = attacker.id
				var left := damage_through(g, pilot, attackers, out, shares)
				out.erase(body.id)
				if left < best_left or (left == best_left and left < through and best_body != null
						and Evaluator.permanent_value(body, pilot.profile)
							< Evaluator.permanent_value(best_body, pilot.profile)):
					best_left = left
					best_body = body
					best_attacker = attacker
		if best_body == null:
			break
		out[best_body.id] = best_attacker.id
		spare.erase(best_body)
		through = best_left
	if through >= life:
		return plan   # no block keeps us alive: the ladder's answer stands
	# A body whose block soaks nothing more (a 1/1 beside the wall that
	# holds all of it) is thrown away for nothing: taken back out, unless
	# its gang kills the trampler.
	for attacker in attackers:
		if not attacker.has_keyword(Mtg.Keyword.TRAMPLE):
			continue
		var band: Array[CardInstance] = []
		for blocker_id in out:
			if int(out[blocker_id]) == attacker.id:
				var body := g.find_instance(int(blocker_id))
				if body != null:
					band.append(body)
		if band.size() < 2 or attacker.cur_min_blockers > 1 \
				or pilot._band_kills(g, attacker, band):
			continue
		band.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.cur_toughness - a.damage < b.cur_toughness - b.damage)
		var left_in := band.size()
		for body in band:
			if left_in < 2:
				break
			out.erase(body.id)
			if damage_through(g, pilot, attackers, out, shares) == through \
					and pilot._dies_to(g, body, attacker):
				left_in -= 1
			else:
				out[body.id] = attacker.id
	for blocker_id in out:
		if not plan.has(blocker_id) and not used.has(int(blocker_id)):
			used.append(int(blocker_id))
	for blocker_id in plan:
		if not out.has(blocker_id):
			used.erase(int(blocker_id))
	return out


static func _band_size(plan: Dictionary, attacker: CardInstance) -> int:
	var n := 0
	for blocker_id in plan:
		if int(plan[blocker_id]) == attacker.id:
			n += 1
	return n
