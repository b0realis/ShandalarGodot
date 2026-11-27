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
##  * THE LOSS ANOTHER CARD SCHEDULED ("Exile it at the beginning of the
##    next end step." — Shallow Grave's creature; "Exile them at the
##    beginning of the next cleanup step." — Waylay's Knights): read off
##    the engine's delayed end-step triggers and cleanup actions, by the
##    line each carries and the object it names ([method
##    scheduled_fleeting]). Such a body attacks as above and blocks for
##    nothing ([method throwaway_block]); the instant or sorcery that makes
##    it ([method made_fleeting]) is cast before our combat for a body that
##    can attack, or into their declared attack when the blocks it buys are
##    worth the card ([method ambush]), and at no other moment.
##  * THE GANG A TRAMPLER INVITES ([method through_gangs]): a lethal push
##    counted with one blocker per attacker is counted again with as many
##    as the defender can put before a trampler.
##  * THE ABILITY THAT MAKES SUCH A BODY ("{1}{R}{R}, {T}: Search your
##    library for a Dragon permanent card, put that card onto the
##    battlefield … Exile it at the beginning of the next end step.",
##    "Create a 3/1 … Graveborn creature token with haste. Sacrifice it at
##    the beginning of the next end step."): read off the ability's own
##    line ([method one_turn_line]) and then off the engine — the
##    activation is forecast under the search journal and the new body's
##    scheduled loss is read as above. It is activated in our first main
##    phase for a body that can attack and is not stopped cold ([method
##    one_turn_option], a line of [method AiPlayer._ability_option]), or
##    into their declared attack when the block it buys is worth its
##    costs ([method ambush]), and at no other moment. A spell another
##    reading owns the main-phase cast of (Corpse Dance) is given the cold
##    stop and the ambush too ([method made_for_a_turn]).
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
	var kind := STAYS
	if not inst.cur_triggered_abilities.is_empty():
		kind = _read_triggers(inst.cur_triggered_abilities, inst.data.card_name)
	if kind == STAYS:
		kind = scheduled_fleeting(g, inst)   # the loss another card's effect scheduled
	return kind


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
	if not data.is_permanent_type():
		return _maker_refusal(g, pilot, inst)   # the spell that makes such a body
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
	return _met_cold(g, g.opponent_of(pilot.pid), data, data.power, data.toughness)


## Why [param body], a card not yet on the battlefield attacking as a
## [param power]/[param toughness], lands nothing and kills nothing against
## [param defender]'s untapped creatures ("" when none stops it cold).
static func _met_cold(g: MtgGame, defender: int, body: CardData, power: int,
		toughness: int) -> String:
	var flies := body.keywords.has(Mtg.Keyword.FLYING)
	var first := body.keywords.has(Mtg.Keyword.FIRST_STRIKE)
	for blocker in g.players[defender].battlefield:
		if not blocker.is_creature() or blocker.tapped or blocker.phased_out:
			continue
		if flies and not blocker.has_keyword(Mtg.Keyword.FLYING) \
				and not blocker.has_keyword(Mtg.Keyword.REACH):
			continue
		# It is struck down before it deals anything...
		if not first and blocker.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
				and blocker.cur_power >= toughness:
			return "a first striker would stop it cold"
		# ...or the blocker lives through all of it (so nothing tramples over).
		if blocker.cur_toughness - blocker.damage > power:
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


# ------------------------------------------- the loss an effect scheduled --

## The fate an EFFECT scheduled for [param inst] at this turn's end: a
## delayed end-step trigger or a cleanup action the engine holds, whose own
## line says what it does ("Exile the creature … returned.", "Sacrifice the
## Spirit token.", "Return the guided creature to its owner's hand.") and
## which names this object — in its memory, or in the id and battlefield
## stamp bound to its callable. A line with a condition ("if …", "unless
## …") or a flip is a decision, not a fate.
static func scheduled_fleeting(g: MtgGame, inst: CardInstance) -> int:
	if g.delayed_triggers.is_empty() and g._cleanup_actions.is_empty():
		return STAYS
	for entry in g.delayed_triggers:
		var trigger: TriggeredAbility = entry["trigger"]
		if trigger.event_type != Mtg.EventType.END_STEP_START or trigger.condition.is_valid():
			continue
		var kind := _fate_of_line(String(entry.get("desc", trigger.text)))
		if kind == STAYS:
			continue
		var memory: Variant = entry.get("memory")
		if memory is Dictionary and memory.has("stamp") and memory["stamp"] is int \
				and int(memory["stamp"]) == inst.layer_timestamp:
			for key in memory:   # the id beside the stamp, whatever it is called
				if key != "stamp" and memory[key] is int and int(memory[key]) == inst.id:
					return kind
		if _binds(trigger.on_resolve.get_bound_arguments(), inst):
			return kind
	for row in g._cleanup_actions:
		var kind := _fate_of_line(String(row.get("desc", "")))
		if kind == STAYS:
			continue
		var action: Callable = row["action"]
		if _binds(action.get_bound_arguments(), inst):
			return kind
	return STAYS


## What a scheduled effect's own line does to the object it names.
static func _fate_of_line(text: String) -> int:
	var line := text.to_lower()
	if line.contains(" if ") or line.contains("unless") or line.contains("flip"):
		return STAYS
	if line.begins_with("exile ") or line.begins_with("sacrifice ") or line.begins_with("destroy "):
		return LOST
	if line.begins_with("return ") and line.contains("owner's hand"):
		return RETURNED
	return STAYS


## Do a callable's bound arguments name [param inst] as the object it is
## now — its id followed by its battlefield stamp, or a row of the two?
static func _binds(args: Array, inst: CardInstance) -> bool:
	for i in args.size():
		var arg: Variant = args[i]
		if arg is Array:
			if _binds(arg, inst):
				return true
		elif arg is int and int(arg) == inst.id and i + 1 < args.size() \
				and args[i + 1] is int and int(args[i + 1]) == inst.layer_timestamp:
			return true
	return false


# ------------------------------------------- the spell that makes such a body --

static var _makers: Dictionary = {}
static var _makers_lock := Mutex.new()
static var _maker_rx: RegEx = null
## The token line the Mirage reading already casts as an ambush
## (mirage_tactics.gd `DOOMED_TOKEN`).
const _WALL_LINE := "sacrifice it at the beginning of the next end step"

## What an instant or a sorcery makes that is gone at the end of the turn
## it is cast in, read off its printed text ("Create three 2/2 white Knight
## creature tokens. Exile them at the beginning of the next cleanup step.",
## "Return the top creature card of your graveyard to the battlefield. …
## Exile it at the beginning of the next end step."): [code]{}[/code] for
## any other card, else [code]token[/code] (the token's [CardData]) and
## [code]count[/code], or [code]returns[/code]; and [code]haste[/code].
## Not a spell that is aimed (its target is its point), nor one another
## reading of the pilot's owns (an effect with a role, the doomed Wall
## mirage_tactics.gd casts).
static func made_fleeting(data: CardData) -> Dictionary:
	_makers_lock.lock()
	var made: Variant = _makers.get(data.card_name)
	if made == null:
		made = _read_maker(data)
		_makers[data.card_name] = made
	_makers_lock.unlock()
	return made


static func _maker_line() -> RegEx:
	if _maker_rx == null:
		_maker_rx = RegEx.create_from_string(
			"(exile|sacrifice|destroy) (it|them|the tokens?|those tokens|that creature|those creatures) at the beginning of the next (end|cleanup) step")
	return _maker_rx


static func _read_maker(data: CardData) -> Dictionary:
	if data.is_permanent_type() or data.is_modal() or data.oracle_text.is_empty():
		return {}
	var text := data.oracle_text.to_lower()
	if _maker_line().search(text) == null:
		return {}
	var token: CardData = null
	var count := 0
	for e in data.spell_effects:
		if e.target_spec != null or e.ai_role != &"":
			return {}
		if e is CreateTokenEffect and token == null:
			token = e.token
			count = e.count
	if token != null:
		if text.contains(_WALL_LINE) or not token.is_creature():
			return {}   # the doomed Wall is cast by the Mirage reading
		return {"token": token, "count": count,
			"haste": token.keywords.has(Mtg.Keyword.HASTE) or text.contains("haste")}
	if text.contains("return the top creature card of your graveyard to the battlefield"):
		return {"returns": true, "haste": text.contains("haste")}
	return {}


## [method made_fleeting], and also the spell of the same printed line
## whose main-phase cast ANOTHER reading owns (an effect with a role, a
## buyback row beside the printed one — Corpse Dance): that reading still
## says what the cast is worth before our combat; this one adds the moment
## it left out (their declared attack, [method ambush]) and the blocker
## that stops the body cold. Such a row carries [code]owned[/code].
static func made_for_a_turn(data: CardData) -> Dictionary:
	var made := made_fleeting(data)
	if not made.is_empty() or data.is_permanent_type() or data.oracle_text.is_empty():
		return made
	_makers_lock.lock()
	var owned: Variant = _owned_makers.get(data.card_name)
	if owned == null:
		owned = {}
		var text := data.oracle_text.to_lower()
		var aimed := false
		for e in data.spell_effects:
			if e.target_spec != null:
				aimed = true
		if not aimed and _maker_line().search(text) != null \
				and (not data.is_modal() or AiPlayer._payment_rows_only(data)) \
				and text.contains("return the top creature card of your graveyard to the battlefield"):
			owned = {"returns": true, "haste": text.contains("haste"), "owned": true}
		_owned_makers[data.card_name] = owned
	_makers_lock.unlock()
	return owned


static var _owned_makers: Dictionary = {}


## The body [param made] would put on [param pid]'s side now, as printed:
## the token, or the top creature card of that graveyard (null when there
## is none).
static func made_body(g: MtgGame, pid: int, made: Dictionary) -> CardData:
	if made.has("token"):
		return made["token"]
	var grave: Array = g.players[pid].graveyard
	for i in range(grave.size() - 1, -1, -1):
		if grave[i].data.is_creature():
			return grave[i].data
	return null


## Why a spell that makes a body gone at end of turn is not cast now: on
## our turn its moment is before our combat, with haste, for a body that
## can attack; on theirs it is their declared attack, before our blocks
## ([method ambush] asks what the blocks are worth).
static func _maker_refusal(g: MtgGame, pilot, inst: CardInstance) -> String:
	var made := made_for_a_turn(inst.data)
	if made.is_empty():
		return ""
	var body := made_body(g, pilot.pid, made)
	if body == null:
		return "it would make nothing"
	if g.active_player == pilot.pid:
		if g.current_step() != Mtg.Step.MAIN1 or g.no_attacks_this_turn:
			return "its creature would be gone before it could attack"
		if not bool(made["haste"]) and not body.keywords.has(Mtg.Keyword.HASTE):
			return "its creature has no haste to attack with"
		var power := Evaluator.arrival_power(body)
		var foe := g.opponent_of(pilot.pid)
		var needs := body.attack_needs_defender_land
		if body.keywords.has(Mtg.Keyword.DEFENDER) or power <= 0 \
				or (needs != "" and not CombatState._controls_land_of_type(g, foe, needs)):
			return "its creature could not attack"
		return _met_cold(g, foe, body, power, Evaluator.arrival_toughness(body))
	if g.current_step() == Mtg.Step.DECLARE_ATTACKERS and not g.awaiting_attackers \
			and not g.combat.attackers.is_empty():
		return ""
	return "its creature would be gone before it could block"


# --------------------------------------------------------------- the ambush --

## What a cast must add to our defence before it is a card well spent.
const AMBUSH_BAR := 3.0
## A defence that does not survive the swing.
const LOST_GAME := -1000.0

## THE AMBUSH — an arm of [method AiPlayer._respond_action]: their
## attackers are declared, our blocks are not, and an instant in hand makes
## bodies that are gone at end of turn. The cast is forecast under the
## search journal, the pilot's own block plan is asked of both boards, and
## the spell is cast when the blocks it buys are worth the card (attackers
## killed, damage kept off, our lasting bodies spared) or keep us alive.
static func ambush(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics or g.active_player == pilot.pid \
			or g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.awaiting_attackers \
			or g.combat.attackers.is_empty() or not g.stack.is_empty():
		return ""
	var pid: int = pilot.pid
	var candidates: Array[CardInstance] = []
	for inst in g.players[pid].hand:
		if inst.data.is_permanent_type() or made_for_a_turn(inst.data).is_empty():
			continue
		if not g.casts_at_instant_speed(pid, inst) or pilot._refused.has(str(inst.id)) \
				or pilot._cast_gate(g, inst) != "":
			continue
		candidates.append(inst)
	var makers := _block_makers(g, pilot)   # [permanent, ability index] rows
	if candidates.is_empty() and makers.is_empty():
		return ""
	var sources: Array = pilot._mana_sources(g)
	var base := defence_worth(g, pilot)
	var best: CardInstance = null
	var best_gain := 0.0
	for inst in candidates:
		var extra: int = g.spell_surcharge(pid, inst.data)
		if pilot._plan_taps_from(sources, inst.data.cost, extra,
				g.mana_usage_keys(inst.data, inst)).is_empty() \
				and not pilot._free_at(inst.data.cost, extra):
			continue
		var after := _defence_after(g, pilot, inst)
		if after <= LOST_GAME:
			continue
		var gain := after - base
		# A card that comes back to the hand (its buyback row, paid by the
		# pilot's own rule in [method AiPlayer._cast_response]) is not spent.
		var bar := AMBUSH_BAR if inst.data.has_buyback() and pilot._buyback_row(g, inst.data) >= 0 \
			else maxf(AMBUSH_BAR, Evaluator.card_value(inst.data))
		if gain < bar or gain <= best_gain:
			continue
		best = inst
		best_gain = gain
	# The permanent whose ability makes the blocker: no card is spent, so
	# the block answers to what the activation costs.
	var best_maker: Array = []
	for row in makers:
		var source: CardInstance = row[0]
		var ability: ActivatedAbility = source.cur_activated_abilities[int(row[1])]
		var read := _activation_forecast(g, pilot, source, int(row[1]), [], true)
		if not bool(read["made"]) or float(read["worth"]) <= LOST_GAME:
			continue
		var gain := float(read["worth"]) - base - float(read["costs"]) \
			- maxf(ability.cost.mana_value() - 1, 0.0) * 0.5
		if gain < BLOCK_BAR or gain <= best_gain:
			continue
		best_maker = row
		best_gain = gain
	if not best_maker.is_empty():
		return _activate(g, pilot, best_maker[0], int(best_maker[1]))
	if best == null:
		return ""
	return pilot._cast_response(g, best, [], 0, "cast %s for its blockers" % best.data.card_name)


## What the pilot's own block plan makes of the declared attack on the
## board as it stands: attackers killed, less our bodies lost (one gone at
## end of turn anyway costs nothing), less the damage that lands at the
## pilot's price of life; [constant LOST_GAME] when the swing kills.
static func defence_worth(g: MtgGame, pilot) -> float:
	var pid: int = pilot.pid
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	attackers.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	var free: Array[CardInstance] = pilot._untapped_creatures(g, pid)
	var used: Array[int] = []
	var plan: Dictionary = pilot._block_choice(g, attackers, free, used)
	var life: int = g.players[pid].life
	var through := damage_through(g, pilot, attackers, plan)
	if through >= life:
		return LOST_GAME
	var worth := -float(through) * float(pilot._life_price(life))
	for attacker in attackers:
		var band: Array[CardInstance] = []
		for blocker_id in plan:
			if int(plan[blocker_id]) == attacker.id:
				var body := g.find_instance(int(blocker_id))
				if body != null:
					band.append(body)
		if band.is_empty():
			continue
		if pilot._band_kills(g, attacker, band) and not worthless_tomorrow(g, attacker):
			worth += float(pilot._victim_value(g, attacker))
		for body in band:
			if pilot._dies_to(g, body, attacker) and not worthless_tomorrow(g, body):
				worth -= Evaluator.permanent_value(body, pilot.profile)
	return worth


## [method defence_worth] of the board [param inst]'s cast would leave:
## the cast itself, paid from mana lent for the forecast and resolved under
## the search journal with nobody asked, and everything put back.
## [constant LOST_GAME] when the engine refuses the cast.
static func _defence_after(g: MtgGame, pilot, inst: CardInstance) -> float:
	var pid: int = pilot.pid
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	g.agents = [DecisionAgent.new(), DecisionAgent.new()]
	for color in [1, 2, 4, 8, 16, 32]:
		g.players[pid].mana_pool.add(color, 60)
	var depth := g.stack.size()
	var worth := LOST_GAME
	if g.cast_spell(pid, inst, [], 0, 0) == "":
		var guard := 0
		var stuck := false
		while g.stack.size() > depth and not g.game_over and guard < 60:
			if g.pass_priority(g.priority_player) != "":
				stuck = true
				break
			guard += 1
		if not stuck and not g.game_over and g.stack.size() <= depth \
				and g.current_step() == Mtg.Step.DECLARE_ATTACKERS:
			worth = defence_worth(g, pilot)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return worth


## THE BLOCK A BODY GONE TONIGHT MAKES FOR NOTHING — a rung of [method
## AiPlayer._best_block_for], asked above the trade: among [param legal],
## our blockers lost at end of turn whatever happens. The fewest of them
## that kill [param attacker] block it; when none can, one stands in its
## way (the damage it stops is free). Empty when no such body is here.
static func throwaway_block(g: MtgGame, pilot, attacker: CardInstance,
		legal: Array[CardInstance]) -> Array[int]:
	var gone: Array[CardInstance] = []
	for body in legal:
		if fleeting(g, body) == LOST:
			gone.append(body)
	var out: Array[int] = []
	if gone.is_empty() or attacker.cur_min_blockers > gone.size():
		return out
	gone.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.cur_power > b.cur_power)
	var cap: int = pilot._blocker_cap(g, attacker)
	var band: Array[CardInstance] = []
	for body in gone:
		if cap > 0 and band.size() >= cap:
			break
		band.append(body)
		if band.size() >= attacker.cur_min_blockers and pilot._band_kills(g, attacker, band):
			for b in band:
				out.append(b.id)
			return out
	if attacker.cur_power <= 0:
		return out
	for i in mini(maxi(attacker.cur_min_blockers, 1), gone.size()):
		out.append(gone[i].id)
	return out


# ------------------------------------------- the gang a trampler invites --

## The searches [method through_gangs] may spend on one board.
const GANG_BUDGET := 4000

## THE LETHAL PUSH, RE-ASKED OF A GANG BLOCK — the last line of [method
## AiPlayer._damage_through_blocks]. That count gives each attacker one
## blocker; a trampler is the attacker a second blocker still stops damage
## of, so "eight trampling into a 3/3 is five through, and five is their
## life" sent the whole board into a defence that puts two 3/3s in its way
## and takes two. Only a count that reads as lethal is asked again, and
## only with a trampler among [param hitters]: every blocker is tried on
## every attacker it may block ([param stopped], the same table: what the
## pair stops), a trampler taking as many as its cap allows and losing
## their toughness up to its power, any other attacker one. The damage the
## best such defence lets through — never more than [param through].
static func through_gangs(g: MtgGame, pilot, hitters: Array[CardInstance], stopped: Array,
		total: int, through: int, defender: int) -> int:
	if through < g.players[defender].life or hitters.is_empty():
		return through
	var columns: int = (stopped[0] as Array).size()
	if columns < 2:
		return through
	var gangs := PackedInt32Array()   # how many blockers each attacker may take
	var any := false
	for hitter in hitters:
		if hitter.has_keyword(Mtg.Keyword.TRAMPLE):
			var cap: int = pilot._blocker_cap(g, hitter)
			gangs.append(cap if cap > 0 else columns)
			any = true
		else:
			gangs.append(1)
	if not any:
		return through
	var powers := PackedInt32Array()
	for hitter in hitters:
		powers.append(maxi(hitter.cur_power, 0))
	var soaked := PackedInt32Array()
	soaked.resize(hitters.size())
	var taken := PackedInt32Array()
	taken.resize(hitters.size())
	var state := {"best": total - through, "nodes": 0}
	_gang_search(stopped, powers, gangs, soaked, taken, 0, columns, state)
	return mini(through, total - int(state["best"]))


static func _gang_search(stopped: Array, powers: PackedInt32Array, gangs: PackedInt32Array,
		soaked: PackedInt32Array, taken: PackedInt32Array, column: int, columns: int,
		state: Dictionary) -> void:
	if column == columns:
		var sum := 0
		for i in powers.size():
			sum += mini(soaked[i], powers[i])
		if sum > int(state["best"]):
			state["best"] = sum
		return
	state["nodes"] = int(state["nodes"]) + 1
	if int(state["nodes"]) > GANG_BUDGET:
		return
	for i in powers.size():
		var held := int(stopped[i][column])
		if held <= 0 or taken[i] >= gangs[i] or soaked[i] >= powers[i]:
			continue
		soaked[i] += held
		taken[i] += 1
		_gang_search(stopped, powers, gangs, soaked, taken, column + 1, columns, state)
		soaked[i] -= held
		taken[i] -= 1
	_gang_search(stopped, powers, gangs, soaked, taken, column + 1, columns, state)


# ------------------------------------- the ability that makes such a body --

## A card taken out of our library for one turn's body, and a card of our
## graveyard paid for one (the house price of graveyard fuel).
const LIBRARY_CARD_PRICE := 0.25
const GRAVE_CARD_PRICE := 0.25
## A library this small is the clock: no card leaves it for one attack.
const THIN_LIBRARY := 7
## What the block an activation buys must be worth over its costs (the
## response moment's own bar, [constant AiPlayer.ABILITY_BAR_UPKEEP]).
const BLOCK_BAR := 2.0

static var _lines: Dictionary = {}
static var _line_makes_rx: RegEx = null
static var _line_loses_rx: RegEx = null


## Does an ability's own line ([param text]) make a creature that leaves at
## the end of the turn — "Create …" or "… (on)to the battlefield", then
## "Exile / Sacrifice / Destroy it (the token, the creature) at the
## beginning of the next end step"? The cheap question; the engine answers
## the real one ([method _activation_forecast]). An ability that dooms its
## own source ("this creature may attack …; exile it at the next end
## step") makes nothing and is not one.
static func one_turn_line(text: String) -> bool:
	_makers_lock.lock()
	var known: Variant = _lines.get(text)
	if known == null:
		if _line_makes_rx == null:
			_line_makes_rx = RegEx.create_from_string("\\bcreate |onto the battlefield|to the battlefield")
			_line_loses_rx = RegEx.create_from_string(
				"(exile|sacrifice|destroy) (it|them|the tokens?|that token|the creature|that creature)[^.;]* at the (beginning of the )?next end step|at the beginning of the next end step, (exile|sacrifice|destroy) (it|them)")
		var line := text.to_lower()
		known = _line_makes_rx.search(line) != null and _line_loses_rx.search(line) != null
		_lines[text] = known
	_makers_lock.unlock()
	return known


## WHEN SUCH AN ABILITY IS ACTIVATED — a line of [method
## AiPlayer._ability_option], asked after the older readings: [param old]
## is their answer (null: none of them knows the ability; {}: one refused
## it) and comes back unchanged for any other ability. The moment is our
## first main phase with the stack empty and an attack ahead; at every
## other one the body would vanish unused (their declared attack is
## [method ambush]'s). There the activation is forecast: no body that
## leaves tonight, and the older answer stands; a body that can neither
## attack to any effect nor has an arrival or a departure of its own to
## be made for, and the mana (the graveyard card, the library card) stays.
## An ability no older reading prices (Zirilan of the Claw) is worth the
## attack it buys, less the attack its own tap gives up and the cards it
## costs, at the bar of an ability with no other moment.
static func one_turn_option(g: MtgGame, pilot, inst: CardInstance, index: int, moment: String,
		old: Variant) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return old
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	if not one_turn_line(ability.text):
		return old
	if old is Dictionary and (old as Dictionary).is_empty():
		return old
	var pid: int = pilot.pid
	if moment != "MAIN" or g.active_player != pid or g.current_step() != Mtg.Step.MAIN1 \
			or g.no_attacks_this_turn or not g.stack.is_empty():
		return {}
	var targets: Array = (old as Dictionary).get("targets", []) if old is Dictionary else []
	if old == null:
		for e in ability.effects:
			if e.target_spec != null:
				return old   # nothing here aims it
	var read := _activation_forecast(g, pilot, inst, index, targets, false)
	if not bool(read["made"]):
		return old
	var attack := float(read["attack"])
	if attack <= 0.0 and not bool(read["point"]):
		return {}
	if old != null:
		return old
	if attack <= 0.0:
		return {}
	if int(read["library"]) > 0 and attack < -LOST_GAME \
			and g.players[pid].library.size() <= THIN_LIBRARY:
		return {}
	return {"value": attack - float(read["forgone"]) - float(read["costs"]), "targets": [],
		"bar": pilot.ABILITY_BAR_SINK}


## One activation of [param inst]'s ability [param index], forecast under
## the search journal (mana lent, the pilot answering its own choices, a
## plain agent the other seat's, everything put back): [code]made[/code]
## — did a creature arrive on our side that is lost at the end of the
## turn; [code]attack[/code] — what such bodies' attack is worth now (the
## power of each that may attack and is not stopped cold; the game when
## that is their life and nothing of theirs can block it);
## [code]point[/code] — a body with an arrival or a departure of its own;
## [code]forgone[/code] — the attack the source's own {T} gives up;
## [code]costs[/code] — the cards the activation took from our hand (at
## their value), our graveyard and our library ([code]library[/code], how
## many); and, [param defending], [code]worth[/code] — [method
## defence_worth] of the board it leaves.
static func _activation_forecast(g: MtgGame, pilot, inst: CardInstance, index: int,
		targets: Array, defending: bool) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var me := g.players[pid]
	var ability: ActivatedAbility = inst.cur_activated_abilities[index]
	var out := {"made": false, "attack": 0.0, "point": false, "forgone": 0.0, "costs": 0.0,
		"library": 0, "worth": LOST_GAME}
	if not defending and ability.tap_cost and inst.is_creature() and inst.cur_power > 0 \
			and CombatState.attack_illegality(g, inst, foe) == "" and not stopped_cold(g, pilot, inst):
		out["forgone"] = float(inst.cur_power)
	var before := {}
	for body in me.battlefield:
		before[body.id] = true
	var hand: Array = me.hand.duplicate()
	var library := me.library.size()
	var grave := me.graveyard.size()
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec_turn()
	g._rec(g, &"agents")
	var seats: Array[DecisionAgent] = [DecisionAgent.new(), DecisionAgent.new()]
	seats[pid] = pilot
	g.agents = seats
	for color in [1, 2, 4, 8, 16, 32]:
		me.mana_pool.add(color, 60)
	var depth := g.stack.size()
	var step := g.current_step()
	if g.activate_ability(pid, inst, index, targets, 0) == "":
		var guard := 0
		var stuck := false
		while g.stack.size() > depth and not g.game_over and guard < 60:
			if g.pass_priority(g.priority_player) != "":
				stuck = true
				break
			guard += 1
		if not stuck and not g.game_over and g.stack.size() <= depth and g.current_step() == step:
			for body in me.battlefield:
				if before.has(body.id) or not body.is_creature() or fleeting(g, body) != LOST:
					continue
				out["made"] = true
				for trigger in body.cur_triggered_abilities:
					if trigger.event_type in [Mtg.EventType.ENTERS_BATTLEFIELD,
							Mtg.EventType.LEAVES_BATTLEFIELD, Mtg.EventType.DIES]:
						out["point"] = true
				if defending or body.cur_power <= 0 \
						or CombatState.attack_illegality(g, body, foe) != "" \
						or stopped_cold(g, pilot, body):
					continue
				var blocked := false
				for blocker in g.players[foe].battlefield:
					if blocker.is_creature() and not blocker.tapped and not blocker.phased_out \
							and CombatState.block_illegality(g, blocker, body, foe, true, pid) == "":
						blocked = true
						break
				out["attack"] = float(out["attack"]) + (-LOST_GAME if not blocked \
					and body.cur_power >= g.players[foe].life else float(body.cur_power))
			if bool(out["made"]):
				var costs := 0.0
				for card in hand:
					if not me.hand.has(card):
						costs += Evaluator.card_value(card.data)
				out["library"] = maxi(library - me.library.size(), 0)
				costs += float(out["library"]) * LIBRARY_CARD_PRICE
				costs += float(maxi(grave - me.graveyard.size(), 0)) * GRAVE_CARD_PRICE
				out["costs"] = costs
				if defending:
					out["worth"] = defence_worth(g, pilot)
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	return out


## Our permanents' abilities that may make a blocker now: the line, no aim
## and no X, the pilot's own availability check, the engine's activation
## rules (a sorcery-speed one answers no) and the mana on the table.
static func _block_makers(g: MtgGame, pilot) -> Array:
	var out: Array = []
	var pid: int = pilot.pid
	var sources: Variant = null
	for inst in g.players[pid].battlefield:
		for index in inst.cur_activated_abilities.size():
			var ability: ActivatedAbility = inst.cur_activated_abilities[index]
			if not one_turn_line(ability.text) or ability.cost.has_x:
				continue
			var aimed := false
			for e in ability.effects:
				if e.target_spec != null:
					aimed = true
			if aimed or not pilot._ability_available(g, inst, index, true) \
					or g.activation_refusal(pid, inst, index) != "":
				continue
			if sources == null:
				sources = pilot._mana_sources(g)
			var own: Array = sources
			if ability.tap_cost:
				own = own.filter(func(row: Array) -> bool: return row[0] != inst)
			var payment := g.ability_payment(pid, inst, index, 0)
			if not (pilot._cost_is_free(payment.cost) and int(payment.extra) == 0) \
					and pilot._plan_taps_from(own, payment.cost, int(payment.extra), payment.usage).is_empty() \
					and not g.players[pid].mana_pool.can_pay(payment.cost, int(payment.extra), payment.usage):
				continue
			out.append([inst, index])
	return out


## Pay for and activate [param source]'s untargeted ability [param index],
## as the tail of [method AiPlayer._try_activate] does.
static func _activate(g: MtgGame, pilot, source: CardInstance, index: int) -> String:
	var pid: int = pilot.pid
	var ability: ActivatedAbility = source.cur_activated_abilities[index]
	var payment := g.ability_payment(pid, source, index, 0)
	if not pilot._plan_and_pay(g, payment.cost, int(payment.extra), payment.usage,
			pilot._spared_for(g, source, ability, [])):
		return ""
	var err := g.activate_ability(pid, source, index, [], 0)
	if err != "":
		g.log_line("(AI activation of %s refused: %s)" % [source.data.card_name, err])
		pilot._refused["%d:%d" % [source.id, index]] = true
		return ""
	return "activated %s for its blocker" % source.data.card_name
