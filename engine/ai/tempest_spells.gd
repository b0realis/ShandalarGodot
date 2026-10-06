extends RefCounted
## THE TEMPEST BLOCK'S SPELLS, READ BY THE FAIR AI (Pack 9, stage 4,
## casting and spell valuation).
##
## Static functions in the shape of [code]mirage_tactics.gd[/code]: each
## takes the pilot ([AiPlayer], untyped to keep the preload cycle open)
## and answers `null` for "not my card, ask the next reader", `{}` for
## "not now" and `{x, targets, value}` for a cast. Every answer is gated
## by [member AiProfile.forecasts_tactics] — with the gate off every
## function answers `null` (or "") and the pilot plays as it did before
## Pack 9.
##
## The policies read the card's declared shape ([member EffectBase.ai_role]
## and [member EffectBase.ai_parameters], set by the card modules under
## cards/sets/{tmp,sth,exo}/), its typed effects and its printed line —
## never a card name — and only the public board, the stack, our own hand
## and our own registered list (docs/fair-play.md): never the opponent's
## hand (its SIZE is public), never either library's order. The board and
## combat policies of the same pack (licids, slivers, spikes, shadow
## tricks, most activated abilities) are [code]tempest_tactics.gd[/code]'s.
##
## THE SHAPES, by what they ask of the board:
##  * DAMAGE COUNTED AS IT RESOLVES — a hand's size (`damage_per_hand_card`),
##    a creature's own power (`self_power_damage`, `shooter_power_damage`),
##    our creatures (`burn_per_creature_you_control`), a player and their
##    whole board (`player_and_creatures_burn`): the amount the effect will
##    deal, read off the public board, at the target it kills.
##  * BOTH SIDES OF THE TABLE — every player's permanents, hand, lands or
##    creatures (`exile_all_permanents_discard_hand`, `cataclysm`,
##    `creature_tax_sweep`, `mass_bounce`, `nonbasic_land_tax`,
##    `living_death`, `sweep_chosen_type`, the five-land enchantment): cast
##    only when what they lose beats what we lose by a sweeper's bar.
##  * A TURN SKIPPED (`skip_next_turn`) is priced as the turn it is.
##  * THE RESPONSES — redirection, team regeneration, a coin fog, a
##    doomed pump, a damage shield that grows, a player-spell retarget, a
##    "can't attack" — have a moment in a combat or on the stack, never in
##    our empty main phase ([method respond]).

const DAMAGE := preload("res://engine/ai/ice_age_tactics.gd")

## What a sweep must swing to be cast — [constant AiPlayer.SWEEP_BAR]'s
## figure, which a symmetric card must clear on top of its own card.
const SWEEP_BAR := 3.0
## The roles whose only moment is a response ([method respond]): never cast
## into our own main phase.
const RESPONSE_ROLES := [&"redirect_source_damage", &"team_regeneration",
	&"coin_fog_blockers", &"pump_doomed", &"prevent_damage_grow",
	&"retarget_player_spell", &"cant_attack_this_turn", &"force_attack"]
## The roles whose moment is OUR FIRST MAIN PHASE, before the attack —
## never held for their end step even when the card also draws.
const MAIN_ROLES := [&"cant_block_this_turn", &"reanimate_top_hasty",
	&"swap_creatures_until_eot"]
## The roles this pilot leaves in hand (documented in the Pack 9 guide):
## a text change it has no reading for, and a sacrifice whose body the
## cost question — not this reader — would choose.
const NEVER_ROLES := [&"text_change", &"sacrificed_power_damage"]
## The game, on the pilot's scale ([constant AiPlayer.LETHAL_WORTH]).
const LETHAL_WORTH := 1000.0
## A 1/1 creature token's worth on [method AiPlayer._victim_value]'s scale
## (the Goblins Mogg Infestation hands back).
const TOKEN_WORTH := 1.25


# =============================================================== the cast --

## The main-phase planner's question for one card ([method
## AiPlayer._size_and_aim]): `null` when no Pack 9 reading applies.
static func spell_choice(g: MtgGame, pilot, inst: CardInstance, _max_x: int, mode: int) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var data := inst.data
	# THE PERMANENTS THAT MAY SERVE THE OTHER SIDE (the Pack 9 bug pass,
	# h6-3..h6-7): an Oath only the opponent qualifies for, a Jinxed Idol
	# nothing of ours can give away, an Ensnaring Bridge that locks our own
	# attackers, a Furnace of Rath doubling only their damage, a Spike
	# Cannibal that eats our own Spikes.
	var harm: Variant = permanent_harm(g, pilot, inst)
	if harm != null:
		return harm
	# MEMORY CRYSTAL: a discount on the buyback cards we hold and run.
	if data.cost_modifier.has("buyback") and data.is_permanent_type():
		var worth: float = pilot._buyback_modifier_value(g, inst)
		return {} if worth <= 0.0 else {"x": 0, "targets": [], "value": worth}
	# MOX DIAMOND: an arrival paid with a land card from the hand.
	if not data.is_land() and data.entry_payment.is_valid() \
			and data.oracle_text.to_lower().contains("discard a land card"):
		return null if spare_land(g, pilot, inst) else {}
	# LIMITED RESOURCES: every player keeps five lands.
	var keep := lands_kept(data)
	if keep > 0:
		return lands_kept_choice(g, pilot, keep)
	# A BODY MADE AS IT ENTERS (Minion of the Wastes' life, Dracoplasm's
	# creatures): a printed 0/0 that the entry choice sizes.
	if data.is_creature() and data.toughness <= 0:
		var made: Variant = body_made_on_entry(g, pilot, inst)
		if made != null:
			return made
	var effects: Array = data.modes[mode]["effects"] if data.is_modal() \
		and mode < data.modes.size() else data.spell_effects
	for e in effects:
		var role: StringName = e.ai_role
		if role == &"":
			continue
		if role in RESPONSE_ROLES or role in NEVER_ROLES:
			return {}
		match role:
			&"damage_per_hand_card": return hand_burn(g, pilot, inst, e)
			&"self_power_damage": return self_power(g, pilot, inst, e)
			&"shooter_power_damage": return deadshot(g, pilot, inst, effects)
			&"burn_per_creature_you_control": return mob_burn(g, pilot, inst, e)
			&"player_and_creatures_burn": return wave_burn(g, pilot, inst, e)
			&"player_creature_sweep": return infestation(g, pilot, inst, e)
			&"skip_next_turn": return skipped_turn(g, pilot, inst, effects)
			&"sweep_chosen_type": return chosen_type_sweep(g, pilot)
			&"exile_all_permanents_discard_hand": return apocalypse(g, pilot, inst)
			&"cataclysm": return cataclysm(g, pilot)
			&"creature_tax_sweep": return fade_away(g, pilot, inst)
			&"mass_bounce": return mass_bounce(g, pilot)
			&"nonbasic_land_tax": return land_tax(g, pilot)
			&"living_death": return living_death(g, pilot, inst)
			&"swap_creatures_until_eot": return reins(g, pilot, inst, e)
			&"cant_block_this_turn": return stun(g, pilot, inst, e)
			&"reanimate_top_hasty": return corpse_dance(g, pilot)
			&"animate_land": return animate_own_land(g, pilot, inst, e)
			&"discard", &"name_from_revealed_hand_exile_all":
				if g.players[g.opponent_of(pilot.pid)].hand.is_empty():
					return {}   # nothing to take
			&"exile_lands_from_library":
				if g.players[pilot.pid].library.size() < 20:
					return {}   # a thin library is the clock, not a thinner one
	return null


## Is [param data] a card whose Pack 9 reading casts it in our first main
## phase ([constant MAIN_ROLES])? Asked by [method AiPlayer._is_held_instant].
static func main_phase_card(data: CardData) -> bool:
	for e in data.spell_effects:
		if e.ai_role in MAIN_ROLES:
			return true
	return false


## May a HELD instant ([method AiPlayer._fire_held_instant], [method
## AiPlayer._held_reserve]) be fired or booked at all? False for a card
## whose moment is a Pack 9 response or never, and for a draw that skips
## a turn this board cannot afford to skip ([method skipped_turn]).
static func held_veto(g: MtgGame, pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics:
		return false
	for e in inst.data.spell_effects:
		if e.ai_role in RESPONSE_ROLES or e.ai_role in NEVER_ROLES:
			return true
		if e.ai_role == &"skip_next_turn":
			return skipped_turn(g, pilot, inst, inst.data.spell_effects).is_empty()
	return false


## Is there a land card in our hand the Mox may eat — one the turn does not
## need for its land drop (two in hand, or the drop already made)?
static func spare_land(g: MtgGame, pilot, inst: CardInstance) -> bool:
	var lands := 0
	for card in g.players[pilot.pid].hand:
		if card != inst and card.data.is_land():
			lands += 1
	if lands == 0:
		return false
	return lands >= 2 or not g.land_drop_available(pilot.pid)


# ------------------------------------------------ permanents that may serve them --

## The AI role a card module declared on [param ability] — a trigger or a
## static, which have no effect list to carry [member EffectBase.ai_role],
## so the module sets it as the ability's metadata (`ai_role`, and
## `ai_parameters`) — or &"".
static func ability_role(ability: Object) -> StringName:
	if ability == null or not ability.has_meta(&"ai_role"):
		return &""
	return StringName(ability.get_meta(&"ai_role"))


static func ability_parameters(ability: Object) -> Dictionary:
	if ability == null or not ability.has_meta(&"ai_parameters"):
		return {}
	return ability.get_meta(&"ai_parameters")


## The first of [param data]'s triggers and statics carrying [param role],
## or null.
static func _role_ability(data: CardData, role: StringName) -> Object:
	for t in data.triggered_abilities:
		if ability_role(t) == role:
			return t
	for st in data.static_abilities:
		if ability_role(st) == role:
			return st
	return null


## `{}` (never now) when [param inst], a permanent card, would serve the
## opponent more than us on this board; null when no such reading applies
## (the generic value decides, as before).
static func permanent_harm(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	if not data.is_permanent_type():
		return null
	var oath := _role_ability(data, &"oath")
	if oath != null:
		return oath_choice(g, pilot, inst, ability_parameters(oath))
	if _role_ability(data, &"hand_size_attack_cap") != null:
		return bridge_choice(g, pilot, inst)
	if _role_ability(data, &"damage_doubler") != null:
		return doubler_choice(g, pilot, inst)
	var feast := _role_ability(data, &"take_all_counters")
	if feast != null:
		return cannibal_choice(g, pilot, inst, ability_parameters(feast))
	return donation_choice(g, pilot, inst)


## THE OATHS (role `oath`, parameters `measure` — `func(game, pid) -> int`,
## the public quantity — and `fewer`): "at the beginning of each player's
## upkeep, that player chooses target opponent who has more <measure>; the
## first player may ..." — each upkeep serves the player who is BEHIND.
## With the Oath out of our hand (it is cast), the opponent qualifying and
## we not: `{}`, the Oath would serve only them. Otherwise null.
static func oath_choice(g: MtgGame, pilot, inst: CardInstance, params: Dictionary) -> Variant:
	var measure: Callable = params.get("measure", Callable())
	if not measure.is_valid():
		return null
	var fewer := bool(params.get("fewer", false))
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var nested := g.undo_log != null
	var mark := g.make_mark()
	var me := g.players[pid]
	g._rec(me, &"hand")
	var rest := me.hand.duplicate()
	rest.erase(inst)
	me.hand = rest
	var ours := int(measure.call(g, pid))
	var theirs := int(measure.call(g, foe))
	g.unmake_to(mark)
	if not nested:
		g.end_search()
	var we_qualify := theirs < ours if fewer else theirs > ours
	var they_qualify := ours < theirs if fewer else ours > theirs
	if they_qualify and not we_qualify:
		return {}
	return null


## ENSNARING BRIDGE (role `hand_size_attack_cap`): "creatures with power
## greater than the number of cards in your hand can't attack" — both
## sides', at the hand we keep once it is cast. `{}` when the power it
## keeps home of ours is not less than the power it keeps home of theirs
## (and something is kept home); null otherwise.
static func bridge_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var pid: int = pilot.pid
	var cap: int = g.players[pid].hand.size() - (1 if inst.zone == Mtg.Zone.HAND else 0)
	var ours := _power_above(g, pid, cap)
	var theirs := _power_above(g, g.opponent_of(pid), cap)
	if ours == 0 and theirs == 0:
		return null
	return {} if theirs <= ours else null


## The power of [param who]'s creatures able to attack (no defender) whose
## power is above [param cap].
static func _power_above(g: MtgGame, who: int, cap: int) -> int:
	var total := 0
	for body in g.players[who].creatures():
		if body.has_keyword(Mtg.Keyword.DEFENDER) or body.cur_power <= cap:
			continue
		total += body.cur_power
	return total


## FURNACE OF RATH (role `damage_doubler`): every source's damage doubled,
## both sides'. The damage each side shows — creatures that can attack,
## and on our side the burn in our own hand — and `{}` while theirs is not
## below ours (the bug pass: their Craw Wurm's 6 became a 12 we had no
## answer to); null otherwise.
static func doubler_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var pid: int = pilot.pid
	var ours := _power_above(g, pid, 0)
	for card in g.players[pid].hand:
		if card == inst or not (card.is_type(Mtg.CardType.INSTANT) or card.is_type(Mtg.CardType.SORCERY)):
			continue
		var intent := EffectIntent.read(card.data.spell_effects, card.data.card_name)
		ours += maxi(intent.damage, 0)
	var theirs := _power_above(g, g.opponent_of(pid), 0)
	return {} if theirs >= ours else null


## SPIKE CANNIBAL (role `take_all_counters`, `kind`): "move all +1/+1
## counters from all creatures onto it" — every other creature's, both
## sides'. Ours move to the Cannibal (no loss) unless the body they leave
## dies (a Spike is a 0/0: its worth less the counters that come over);
## theirs are taken, and a body of theirs they leave dead is a kill. `{}`
## when that costs us more than it costs them; a value over the card's own
## when it takes more; null when no counter is out.
static func cannibal_choice(g: MtgGame, pilot, inst: CardInstance, params: Dictionary) -> Variant:
	var kind := String(params.get("kind", "+1/+1"))
	var pid: int = pilot.pid
	var gain := 0.0
	var loss := 0.0
	var seen := 0
	for body in g.all_battlefield():
		if body == inst or body.phased_out or not body.is_creature():
			continue
		var n := int(body.counters.get(kind, 0))
		if n <= 0:
			continue
		seen += n
		var dies := not body.cur_indestructible and body.cur_toughness - n <= body.damage
		if body.controller_id == pid:
			if dies:
				loss += maxf(float(pilot._own_value(g, body)) - float(n), 0.5)
		else:
			gain += float(n) + (float(pilot._victim_value(g, body)) if dies else float(n))
	if seen == 0:
		return null
	var net := gain - loss
	if net < 0.0:
		return {}
	if net == 0.0:
		return null
	return {"x": 0, "targets": [], "value": Evaluator.card_value(inst.data) + net}


## JINXED IDOL / JINXED RING (an activated `donate_self`, "Target opponent
## gains control of this artifact", whose own triggers hurt their
## controller): the card is worth casting only to be given away — so only
## when a body of ours can pay the donation and the toll handed over
## outweighs that body by the bar the activation will be asked to clear
## (TempestTactics `donate_option`; the bug pass, h6-4: an Idol cast with no
## creature to give it away with only bit its caster). null for any other
## card.
static func donation_choice(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	var donate: ActivatedAbility = null
	for a in data.activated_abilities:
		if not a.effects.is_empty() and a.effects[0].ai_role == &"donate_self":
			donate = a
			break
	if donate == null:
		return null
	var tactics := preload("res://engine/ai/tempest_tactics.gd")
	var per_turn: float = tactics.toll_per_turn(data.triggered_abilities)
	if per_turn <= 0.0:
		return null
	var pid: int = pilot.pid
	var fodder := INF
	if donate.sacrifice_filter.is_valid() or donate.sacrifice_cost:
		for body in g.players[pid].battlefield:
			if donate.sacrifice_filter.is_valid() and not bool(donate.sacrifice_filter.call(body)):
				continue
			fodder = minf(fodder, float(pilot._own_value(g, body)))
		if fodder == INF:
			return {}   # nothing to give it away with: it only bites us
	else:
		fodder = 0.0
	var gift: float = tactics.donation_value(g, pilot, per_turn)
	if gift - fodder < float(pilot.ABILITY_BAR_MAIN):
		return {}
	return {"x": 0, "targets": [], "value": gift - fodder}


# ------------------------------------------------- damage counted as it resolves --

## The opponent as a legal target of [param e] for [param inst], or null.
static func _opponent_ref(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> TargetRef:
	var foe := TargetRef.player(g.opponent_of(pilot.pid))
	if e.target_spec == null or not g.target_legal_at(e.target_spec, foe, inst, 0):
		return null
	return foe


## A burn at the opponent's face for [param amount]: the game when lethal,
## else the clock's worth plus [param extra] — or `{}` below
## [param floor] points with nothing extra.
static func _face(g: MtgGame, pilot, inst: CardInstance, ref: TargetRef, amount: int,
		floor := 1, extra := 0.0) -> Dictionary:
	var dealt := DAMAGE.damage_through(g, inst, ref, amount)
	var life: int = g.players[ref.player_id].life
	if dealt >= life:
		return {"x": 0, "targets": [ref], "value": LETHAL_WORTH}
	if dealt < floor and extra <= 0.0:
		return {}
	var value: float = pilot._face_damage_value(g, dealt, ref.player_id) + extra
	return {} if value <= 0.0 else {"x": 0, "targets": [ref], "value": value}


## SUDDEN IMPACT (`damage_per_hand_card`): as many points as cards in the
## target player's hand — a public count. Thrown at three or more, or when
## lethal.
static func hand_burn(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var ref := _opponent_ref(g, pilot, inst, e)
	if ref == null:
		return {}
	return _face(g, pilot, inst, ref, g.players[ref.player_id].hand.size(), 3)


## MOB JUSTICE (`burn_per_creature_you_control`): a point per creature we
## control as it resolves. Thrown at three or more, or when lethal.
static func mob_burn(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var ref := _opponent_ref(g, pilot, inst, e)
	if ref == null:
		return {}
	return _face(g, pilot, inst, ref, g.players[pilot.pid].creatures().size(), 3)


## FLAME WAVE (`player_and_creatures_burn`, `amount`): the points at the
## player and at every creature they control — their board's dead plus
## the face.
static func wave_burn(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var ref := _opponent_ref(g, pilot, inst, e)
	if ref == null:
		return {}
	var amount := int(e.ai_parameters.get("amount", 0))
	var dead := 0.0
	for body in g.players[ref.player_id].creatures():
		if _dies_to(g, inst, body, amount):
			dead += float(pilot._victim_value(g, body))
	return _face(g, pilot, inst, ref, amount, maxi(amount, 1) + 1, dead)


## Would [param amount] damage from [param source] destroy [param body]?
static func _dies_to(g: MtgGame, source: CardInstance, body: CardInstance, amount: int) -> bool:
	if body.cur_indestructible:
		return false
	return body.damage + DAMAGE.damage_through(g, source, TargetRef.card(body), amount) \
		>= body.cur_toughness


## REPENTANCE (`self_power_damage`): the target creature deals damage equal
## to its power to itself — their best creature that it kills.
static func self_power(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var best: CardInstance = null
	var best_value := 0.0
	for body in g.players[g.opponent_of(pilot.pid)].creatures():
		var ref := TargetRef.card(body)
		if not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		if body.cur_power <= 0 or not _dies_to(g, body, body, body.cur_power):
			continue
		var worth: float = pilot._victim_value(g, body)
		if worth > best_value:
			best = body
			best_value = worth
	if best == null:
		return {}
	return {"x": 0, "targets": [TargetRef.card(best)], "value": best_value + 1.0}


## DEADSHOT (`shooter_power_damage` on the second slot; the first slot is a
## tap): the first creature, tapped, deals damage equal to its power to the
## second. Their creature that dies to a shooter, the shooter theirs when
## one serves (tapping it is a bonus), ours only at the price of an attack
## it then cannot make.
static func deadshot(g: MtgGame, pilot, inst: CardInstance, effects: Array) -> Dictionary:
	if effects.size() < 2 or effects[0].target_spec == null or effects[1].target_spec == null:
		return {}
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var shooters: Array[CardInstance] = []
	for p in [foe, pid]:
		for body in g.players[p].creatures():
			if body.cur_power > 0 and g.target_legal_at(effects[0].target_spec,
					TargetRef.card(body), inst, 0):
				shooters.append(body)
	var best := {}
	for victim in g.players[foe].creatures():
		var worth: float = pilot._victim_value(g, victim)
		for shooter in shooters:
			if shooter == victim:
				continue
			var earlier: Array = [TargetRef.card(shooter)]
			if not g.target_legal_at(effects[1].target_spec, TargetRef.card(victim), inst, 0, earlier):
				continue
			if not _dies_to(g, shooter, victim, shooter.cur_power):
				continue
			var value := worth + 1.0
			if shooter.controller_id == foe and not shooter.tapped:
				value += 0.5   # tapped out of their next block or attack
			elif shooter.controller_id == pid and not shooter.tapped \
					and g.active_player == pid and g.current_step() == Mtg.Step.MAIN1:
				value -= 0.5   # one attacker fewer this turn
			if best.is_empty() or value > float(best["value"]):
				best = {"x": 0, "targets": [TargetRef.card(shooter), TargetRef.card(victim)],
					"value": value}
	return best


## MOGG INFESTATION (`player_creature_sweep`, `tokens_each`): every creature
## the target player controls is destroyed, and they get Goblins for each
## one that died. Their board less the tokens it hands back.
static func infestation(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var ref := _opponent_ref(g, pilot, inst, e)
	if ref == null:
		return {}
	var each := int(e.ai_parameters.get("tokens_each", 0))
	var swing := 0.0
	for body in g.players[ref.player_id].creatures():
		if body.cur_indestructible:
			continue
		swing += float(pilot._victim_value(g, body)) - TOKEN_WORTH * float(each)
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [ref], "value": swing}


# ----------------------------------------------------------- both sides of the table --

## The worth of [param body] to its controller, on the pilot's two scales.
static func _worth(g: MtgGame, pilot, body: CardInstance) -> float:
	return float(pilot._own_value(g, body)) if body.controller_id == pilot.pid \
		else float(pilot._victim_value(g, body))


## APOCALYPSE (`exile_all_permanents_discard_hand`): every permanent, both
## sides, and then our own hand. Their board against our board AND hand.
static func apocalypse(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var swing := 0.0
	for body in g.all_battlefield():
		if not g.is_present(body):
			continue
		swing += _worth(g, pilot, body) * (1.0 if body.controller_id != pilot.pid else -1.0)
	for card in g.players[pilot.pid].hand:
		if card != inst:
			swing -= Evaluator.card_value(card.data)
	return {} if swing < SWEEP_BAR * 2.0 else {"x": 0, "targets": [], "value": swing}


## CATACLYSM (`cataclysm`): each player keeps one artifact, creature,
## enchantment and land — their best of each, by the pilot's two scales —
## and sacrifices the rest.
static func cataclysm(g: MtgGame, pilot) -> Dictionary:
	var swing := 0.0
	for p in [pilot.pid, g.opponent_of(pilot.pid)]:
		var kept := {}
		for kind in [Mtg.CardType.ARTIFACT, Mtg.CardType.CREATURE,
				Mtg.CardType.ENCHANTMENT, Mtg.CardType.LAND]:
			var best: CardInstance = null
			for body in g.players[p].battlefield:
				if not body.is_type(kind) or kept.has(body.id):
					continue
				if best == null or _worth(g, pilot, body) > _worth(g, pilot, best):
					best = body
			if best != null:
				kept[best.id] = true
		var lost := 0.0
		for body in g.players[p].battlefield:
			if not kept.has(body.id):
				lost += _worth(g, pilot, body)
		swing += lost if p != pilot.pid else -lost
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## FADE AWAY (`creature_tax_sweep`): for each creature a player controls,
## {1} or a permanent. Each side pays what its open mana covers (ours net
## of this spell) and sacrifices its cheapest permanents for the rest.
static func fade_away(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var ours_open := 0
	for source in pilot._mana_sources(g):
		ours_open += int(source[3])
	ours_open -= inst.data.cost.mana_value()
	var swing := _tax_loss(g, pilot, foe, int(pilot._their_open_mana(g, foe))) \
		- _tax_loss(g, pilot, pid, maxi(ours_open, 0))
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


static func _tax_loss(g: MtgGame, pilot, who: int, open_mana: int) -> float:
	var owed := maxi(0, g.players[who].creatures().size() - open_mana)
	if owed == 0:
		return 0.0
	var values: Array[float] = []
	for body in g.players[who].battlefield:
		values.append(_worth(g, pilot, body))
	values.sort()
	var lost := 0.0
	for i in mini(owed, values.size()):
		lost += values[i]
	return lost


## EVACUATION (`mass_bounce`): every creature to its owner's hand — a token
## is gone, a card is a recast. Their tempo against ours.
static func mass_bounce(g: MtgGame, pilot) -> Dictionary:
	var swing := 0.0
	for body in g.all_battlefield():
		if not body.is_creature() or not g.is_present(body):
			continue
		var lost := _worth(g, pilot, body) * (1.0 if body.is_token else 0.5)
		swing += lost if body.controller_id != pilot.pid else -lost
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## PRICE OF PROGRESS (`nonbasic_land_tax`): two damage to each player per
## nonbasic land they control. Never into our own death; the game when it
## is theirs; else their points less ours.
static func land_tax(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var mine := 2 * _nonbasics(g, pid)
	var theirs := 2 * _nonbasics(g, foe)
	if mine >= g.players[pid].life:
		return {}
	if theirs >= g.players[foe].life:
		return {"x": 0, "targets": [], "value": LETHAL_WORTH}
	var value: float = pilot._face_damage_value(g, theirs, foe) \
		- float(mine) * pilot._life_price(g.players[pid].life)
	return {} if value < 2.0 else {"x": 0, "targets": [], "value": value}


static func _nonbasics(g: MtgGame, who: int) -> int:
	var n := 0
	for body in g.players[who].battlefield:
		if body.is_land() and (body.cur_supertypes & Mtg.Supertype.BASIC) == 0:
			n += 1
	return n


## LIVING DEATH (`living_death`): each side trades its creatures on the
## battlefield for the creature cards in its graveyard. Ours gained less
## theirs gained.
static func living_death(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var swing := 0.0
	for p in [pilot.pid, g.opponent_of(pilot.pid)]:
		var gain := 0.0
		for card in g.players[p].graveyard:
			if card.data.is_creature() and card != inst:
				gain += Evaluator.card_value(card.data)
		for body in g.players[p].creatures():
			gain -= _worth(g, pilot, body)
		swing += gain if p == pilot.pid else -gain
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## EXTINCTION (`sweep_chosen_type`): "destroy all creatures of the creature
## type of your choice". The type is chosen as it resolves; the card's own
## hint names the type whose loss costs the other side the most against
## ours, by a public worth (mana value, power, toughness), and that type is
## the one priced here — on the pilot's own scales.
static func chosen_type_sweep(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var score := {}
	for body in g.all_battlefield():
		if not body.is_creature() or not g.is_present(body):
			continue
		var crude := 1 + body.data.cost.mana_value() + maxi(body.cur_power, 0) \
			+ maxi(body.cur_toughness, 0)
		for kind in body.cur_subtypes:
			score[kind] = int(score.get(kind, 0)) + (crude if body.controller_id != pid else -crude)
	var chosen := ""
	var top := 0
	for kind in score:
		if int(score[kind]) > top:
			top = int(score[kind])
			chosen = String(kind)
	if chosen == "":
		return {}
	var swing := 0.0
	for body in g.all_battlefield():
		if body.is_creature() and g.is_present(body) and body.has_subtype(chosen) \
				and not body.cur_indestructible:
			swing += _worth(g, pilot, body) * (1.0 if body.controller_id != pid else -1.0)
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## The number of lands an arrival trigger lets each player keep ("each
## player chooses five lands they control and sacrifices the rest" —
## Limited Resources), read off the printed line; 0 for any other card.
static func lands_kept(data: CardData) -> int:
	for t in data.triggered_abilities:
		if t.event_type != Mtg.EventType.ENTERS_BATTLEFIELD:
			continue
		var line := t.text.to_lower()
		var at := line.find("each player chooses ")
		if at < 0 or not line.contains("lands they control and sacrifices the rest"):
			continue
		var words := line.substr(at + 20).split(" ", false)
		if words.is_empty():
			continue
		var n := ["one", "two", "three", "four", "five", "six", "seven"].find(words[0]) + 1
		if n > 0:
			return n
	return 0


## Each side keeps its best [param keep] lands: their excess against ours.
static func lands_kept_choice(g: MtgGame, pilot, keep: int) -> Dictionary:
	var swing := 0.0
	for p in [pilot.pid, g.opponent_of(pilot.pid)]:
		var values: Array[float] = []
		for body in g.players[p].battlefield:
			if body.is_land():
				values.append(_worth(g, pilot, body))
		values.sort()
		var lost := 0.0
		for i in maxi(0, values.size() - keep):
			lost += values[i]
		swing += lost if p != pilot.pid else -lost
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## MEDITATE (`skip_next_turn`): the cards it draws against the turn it
## costs ([method AiPlayer._extra_turn_value] — the draw, the land and the
## attack of a turn). Never while their board, swinging twice before we
## untap, reaches our life; never into a library it would empty.
static func skipped_turn(g: MtgGame, pilot, inst: CardInstance, effects: Array) -> Dictionary:
	var pid: int = pilot.pid
	var draws := 0
	for e in effects:
		if e is DrawEffect:
			draws += e.count
	var me := g.players[pid]
	if me.library.size() <= draws + 2:
		return {}
	var power := 0
	for body in g.players[g.opponent_of(pid)].creatures():
		if not body.has_keyword(Mtg.Keyword.DEFENDER) and not body.cur_cant_attack:
			power += maxi(body.cur_power, 0)
	if power * 2 >= me.life:
		return {}
	var kept := mini(draws, maxi(0, 7 - (me.hand.size() - 1)))
	var value: float = float(kept) * pilot.profile.w_hand - pilot._extra_turn_value(g, 1)
	return {} if value < Evaluator.card_value(inst.data) else {"x": 0, "targets": [], "value": value}


## A 0/0 creature whose size is chosen as it enters, read off its printed
## line: "pay any amount of life" (Minion of the Wastes: the card's own
## hint pays the lesser of half our life and our life less five) and
## "sacrifice any number of creatures" (Dracoplasm: the hint eats every
## creature of ours without flying). `{}` when the body would enter as a
## 0/0 or not repay what it eats; `null` for any other card.
static func body_made_on_entry(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var pid: int = pilot.pid
	var line := inst.data.oracle_text.to_lower()
	if line.contains("as this creature enters, pay any amount of life") \
			or line.contains("enters, pay any amount of life"):
		var life: int = g.players[pid].life
		var paid := clampi(mini(life / 2, life - 5), 0, life)
		if paid < 3:
			return {}
		var value: float = float(paid) * 1.5 - float(paid) * pilot._life_price(life - paid)
		return {} if value <= 0.0 else {"x": 0, "targets": [], "value": value}
	if line.contains("as this creature enters, sacrifice any number of creatures"):
		var power := 0
		var toughness := 0
		var eaten := 0.0
		for body in g.players[pid].creatures():
			if body.has_keyword(Mtg.Keyword.FLYING):
				continue
			power += maxi(body.cur_power, 0)
			toughness += maxi(body.cur_toughness, 0)
			eaten += float(pilot._own_value(g, body))
		if toughness <= 0:
			return {}
		var value := float(power + toughness) * 0.75 + 1.5 - eaten
		return {} if value <= 0.0 else {"x": 0, "targets": [], "value": value}
	return null


# --------------------------------------------------------------------- the attack --

## REINS OF POWER (`swap_creatures_until_eot`): our creatures and theirs
## change sides until end of turn, untapped and hasty. Cast in our first
## main phase only when their creatures, attacking past our own as their
## blockers, deal them lethal damage — the one use that cannot backfire.
static func reins(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	if g.active_player != pid or g.current_step() != Mtg.Step.MAIN1:
		return {}
	var ref := _opponent_ref(g, pilot, inst, e)
	if ref == null:
		return {}
	var attackers: Array[CardInstance] = []
	for body in g.players[foe].creatures():
		if body.cur_power > 0 and not body.has_keyword(Mtg.Keyword.DEFENDER) \
				and not body.cur_cant_attack:
			attackers.append(body)
	if attackers.is_empty():
		return {}
	var blockers: Array[CardInstance] = []
	for body in g.players[pid].creatures():
		blockers.append(body)
	var through: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	if through < g.players[foe].life:
		return {}
	return {"x": 0, "targets": [ref], "value": LETHAL_WORTH}


## STUN (`cant_block_this_turn`): their best untapped creature out of the
## blocks, in our first main phase, when we have an attack for it to stop.
static func stun(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	if g.active_player != pid or g.current_step() != Mtg.Step.MAIN1:
		return {}
	if pilot._attack_candidates(g, foe).is_empty():
		return {}
	var best: CardInstance = null
	var best_value := 0.0
	for body in pilot._untapped_creatures(g, foe):
		if not g.target_legal_at(e.target_spec, TargetRef.card(body), inst, 0):
			continue
		var worth: float = pilot._victim_value(g, body)
		if worth > best_value:
			best = body
			best_value = worth
	if best == null:
		return {}
	var drew := 0.0
	for other in inst.data.spell_effects:
		if other is DrawEffect:
			drew += float(other.count) * pilot.profile.w_hand
	return {"x": 0, "targets": [TargetRef.card(best)], "value": best_value * 0.4 + drew}


## CORPSE DANCE (`reanimate_top_hasty`): the top creature card of our
## graveyard, hasty, for one attack in our first main phase (exiled at the
## end step). Worth its power when it is a real attacker.
static func corpse_dance(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	if g.active_player != pid or g.current_step() != Mtg.Step.MAIN1:
		return {}
	var top: CardInstance = null
	var grave: Array = g.players[pid].graveyard
	for i in range(grave.size() - 1, -1, -1):
		if grave[i].data.is_creature():
			top = grave[i]
			break
	if top == null or top.data.power < 2:
		return {}
	var foe := g.opponent_of(pid)
	if top.data.power >= g.players[foe].life and pilot._untapped_creatures(g, foe).is_empty():
		return {"x": 0, "targets": [], "value": LETHAL_WORTH}
	return {"x": 0, "targets": [], "value": float(top.data.power)}


## VERDANT TOUCH (`animate_land`, `power`/`toughness`): one of OUR lands, the
## one we miss least, and only with lands to spare — a land made a creature
## is a land creature removal now answers.
static func animate_own_land(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var lands: Array[CardInstance] = []
	for body in g.players[pid].battlefield:
		if body.is_land():
			lands.append(body)
	if lands.size() < 5:
		return {}
	var best: CardInstance = null
	var best_cost := INF
	for land in lands:
		if land.is_creature() or not g.target_legal_at(e.target_spec, TargetRef.card(land), inst, 0):
			continue
		var cost: float = pilot._own_value(g, land)
		if cost < best_cost:
			best = land
			best_cost = cost
	if best == null:
		return {}
	var body := float(int(e.ai_parameters.get("power", 0)) + int(e.ai_parameters.get("toughness", 0)))
	return {"x": 0, "targets": [TargetRef.card(best)], "value": body * 0.75}


# ============================================================ the responses --

## Pack 9's instant-speed moments ([method AiPlayer._respond_action]): "" when
## none fires. In a combat whose blocks are declared — the redirect, the
## team regeneration, the coin fog, the growing shield, the doomed pump;
## on the stack — the growing shield against burn, the player-spell
## retarget; at their beginning of combat — "can't attack".
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var pid: int = pilot.pid
	var hand: Array = []
	for inst in g.players[pid].hand:
		if pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue
		if not g.casts_at_instant_speed(pid, inst):
			continue
		for e in inst.data.spell_effects:
			if e.ai_role in RESPONSE_ROLES:
				hand.append([inst, e])
				break
	for row in hand:
		var done := _respond_with(g, pilot, row[0], row[1])
		if done != "":
			return done
	return ""


static func _respond_with(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var top: StackItem = null if g.stack.is_empty() else g.stack.back()
	var combat := not g.combat.attackers.is_empty() and top == null \
		and g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers
	match e.ai_role:
		&"redirect_source_damage":
			return kor_chant(g, pilot, inst) if combat else ""
		&"team_regeneration":
			return team_regeneration(g, pilot, inst) if combat else ""
		&"coin_fog_blockers":
			return coin_fog(g, pilot, inst) if combat else ""
		&"pump_doomed":
			return doomed_pump(g, pilot, inst, e) if combat else ""
		&"prevent_damage_grow":
			if combat:
				return growing_shield_in_combat(g, pilot, inst, e)
			return growing_shield_on_stack(g, pilot, inst, e, top)
		&"retarget_player_spell":
			return rebound(g, pilot, inst, e, top)
		&"cant_attack_this_turn":
			return cant_attack(g, pilot, inst, e)
		&"force_attack":
			return force_attack(g, pilot, inst, e)
	return ""


## What the spell on the stack [param top] does: the mode it was cast in,
## read as its card reads ([method EffectIntent.read], the card-local table
## by name included).
static func _spell_intent(top: StackItem) -> EffectIntent:
	var effects: Array = top.effects if not top.effects.is_empty() \
		else top.card.data.spell_effects
	return EffectIntent.read(effects, top.card.data.card_name)


## Our creatures the declared combat kills.
static func _our_dying(g: MtgGame, pilot) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for body in g.players[pilot.pid].creatures():
		if pilot._dies_in_combat(g, body):
			out.append(body)
	return out


## KOR CHANT (`redirect_source_damage`): "all damage that would be dealt
## this turn to target creature you control by a source of your choice is
## dealt to another target creature instead". In a declared combat, a
## creature of ours fighting ONE creature that kills it: that creature's
## damage goes to a creature of theirs it kills — itself when it can.
static func kor_chant(g: MtgGame, pilot, inst: CardInstance) -> String:
	var effects: Array = inst.data.spell_effects
	if effects.size() < 2 or effects[0].target_spec == null or effects[1].target_spec == null:
		return ""
	var pid: int = pilot.pid
	var best := {}
	for ours in _our_dying(g, pilot):
		var foes: Array = g.combat.blockers_of(ours.id) if g.combat.attackers.has(ours.id) \
			else g.combat.attackers_blocked_by(ours.id)
		if foes.size() != 1:
			continue
		var source := g.find_instance(int(foes[0]))
		if source == null or source.cur_power <= 0:
			continue
		var first := TargetRef.card(ours)
		if not g.target_legal_at(effects[0].target_spec, first, inst, 0):
			continue
		for victim in g.players[g.opponent_of(pid)].creatures():
			var second := TargetRef.card(victim)
			if not g.target_legal_at(effects[1].target_spec, second, inst, 0, [first]):
				continue
			if not _dies_to(g, source, victim, source.cur_power):
				continue
			var value: float = float(pilot._own_value(g, ours)) + float(pilot._victim_value(g, victim))
			if best.is_empty() or value > float(best["value"]):
				best = {"value": value, "targets": [first, second]}
	if best.is_empty() or float(best["value"]) < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, best["targets"], 0, "cast %s" % inst.data.card_name)


## RESUSCITATE (`team_regeneration`): our creatures gain "{1}: Regenerate"
## until end of turn — worth the dying creatures the mana left after the
## spell can regenerate.
static func team_regeneration(g: MtgGame, pilot, inst: CardInstance) -> String:
	var dying := _our_dying(g, pilot)
	if dying.is_empty():
		return ""
	var open := 0
	for source in pilot._mana_sources(g):
		open += int(source[3])
	var spare := open - inst.data.cost.mana_value()
	if spare <= 0:
		return ""
	var worths: Array[float] = []
	for body in dying:
		worths.append(float(pilot._own_value(g, body)))
	worths.sort()
	worths.reverse()
	var saved := 0.0
	for i in mini(spare, worths.size()):
		saved += worths[i]
	if saved < Evaluator.card_value(inst.data) + 1.0:
		return ""
	return pilot._cast_response(g, inst, [], 0, "cast %s" % inst.data.card_name)


## FIGHTING CHANCE (`coin_fog_blockers`): on our attack, each blocker's
## combat damage is prevented on a won flip — half of what the blocks kill
## of ours, expected.
static func coin_fog(g: MtgGame, pilot, inst: CardInstance) -> String:
	if g.active_player != pilot.pid:
		return ""
	var saved := 0.0
	for body in _our_dying(g, pilot):
		if g.combat.attackers.has(body.id):
			saved += 0.5 * float(pilot._own_value(g, body))
	if saved < Evaluator.card_value(inst.data) + 1.0:
		return ""
	return pilot._cast_response(g, inst, [], 0, "cast %s" % inst.data.card_name)


## BLOOD FRENZY (`pump_doomed`, `power`): +N/+0 and destroyed at the next
## end step. On our UNBLOCKED attacker when the points are lethal; on
## THEIR unblocked attacker as removal, when the extra points leave us
## alive — never on a creature in a block, whose extra power kills the
## other side of it.
static func doomed_pump(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var bonus := int(e.ai_parameters.get("power", 0))
	var best := {}
	if g.active_player == pid:
		var through := 0
		for id in g.combat.attackers:
			var body := g.find_instance(int(id))
			if body != null and g.combat.blockers_of(body.id).is_empty():
				through += maxi(body.cur_power, 0)
		for id in g.combat.attackers:
			var body := g.find_instance(int(id))
			if body == null or not g.combat.blockers_of(body.id).is_empty():
				continue
			if not g.target_legal_at(e.target_spec, TargetRef.card(body), inst, 0):
				continue
			if through + bonus >= g.players[foe].life:
				best = {"value": LETHAL_WORTH, "targets": [TargetRef.card(body)]}
				break
	else:
		var incoming: int = pilot._incoming_damage(g)
		var life: int = g.players[pid].life
		for id in g.combat.attackers:
			var body := g.find_instance(int(id))
			if body == null or not g.combat.blockers_of(body.id).is_empty():
				continue
			if not g.target_legal_at(e.target_spec, TargetRef.card(body), inst, 0):
				continue
			if incoming + bonus >= life:
				continue
			var value: float = float(pilot._victim_value(g, body)) \
				- float(bonus) * pilot._life_price(life - incoming)
			if value > 0.0 and (best.is_empty() or value > float(best["value"])):
				best = {"value": value, "targets": [TargetRef.card(body)]}
	if best.is_empty() or float(best["value"]) < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, best["targets"], 0, "cast %s" % inst.data.card_name)


## TEMPER (`prevent_damage_grow`, {X}): prevent the next X damage to our
## creature and grow it a counter per point. In a declared combat, our
## creature the combat kills, X its incoming damage.
static func growing_shield_in_combat(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var best := {}
	for body in _our_dying(g, pilot):
		var hit: int = pilot._combat_damage_to(g, body)
		var value := float(pilot._own_value(g, body)) + float(hit)
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "body": body, "x": hit}
	if best.is_empty():
		return ""
	return _shield(g, pilot, inst, e, best["body"], int(best["x"]), float(best["value"]))


## TEMPER on the stack: an opposing spell's damage aimed at a creature of
## ours that it kills.
static func growing_shield_on_stack(g: MtgGame, pilot, inst: CardInstance, e: EffectBase,
		top: StackItem) -> String:
	if top == null or top.controller == pilot.pid or top.kind != Mtg.StackKind.SPELL:
		return ""
	var intent := _spell_intent(top)
	var amount := intent.damage_at(top.x_value)
	if amount <= 0:
		return ""
	for ref in top.targets:
		if ref == null or ref.is_player:
			continue
		var body := g.find_instance(ref.instance_id)
		if body == null or body.controller_id != pilot.pid or not body.is_creature():
			continue
		if body.damage + amount < body.cur_toughness:
			continue
		return _shield(g, pilot, inst, e, body, amount, float(pilot._own_value(g, body)) + float(amount))
	return ""


static func _shield(g: MtgGame, pilot, inst: CardInstance, e: EffectBase, body: CardInstance,
		x: int, value: float) -> String:
	var ref := TargetRef.card(body)
	if x <= 0 or not g.target_legal_at(e.target_spec, ref, inst, x):
		return ""
	if inst.data.cost.has_x:
		var reach: int = pilot._max_affordable_x(g, inst.data.cost, g.spell_surcharge(pilot.pid, inst.data),
			pilot._mana_sources(g), inst.data.x_color, g.mana_usage_keys(inst.data, inst))
		if reach < x:
			return ""
	if value < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, [ref], 0, "cast %s" % inst.data.card_name, x)


## REBOUND (`retarget_player_spell`): their spell that targets only a
## player — us — and harms us (damage, a life loss, a discard) is sent back
## at them.
static func rebound(g: MtgGame, pilot, inst: CardInstance, e: EffectBase, top: StackItem) -> String:
	if top == null or top.controller == pilot.pid or top.kind != Mtg.StackKind.SPELL \
			or top.targets.size() != 1 or top.targets[0] == null or not top.targets[0].is_player \
			or top.targets[0].player_id != pilot.pid:
		return ""
	var intent := _spell_intent(top)
	var harm: float = float(intent.damage_at(top.x_value) + maxi(intent.life_loss, 0)) \
		+ float(maxi(intent.discards, 0)) * pilot.profile.w_hand
	if harm < Evaluator.card_value(inst.data):
		return ""
	var ref := TargetRef.card(top.card)
	if not g.target_legal_at(e.target_spec, ref, inst, 0):
		return ""
	return pilot._cast_response(g, inst, [ref], 0, "cast %s" % inst.data.card_name)


## CHANGE OF HEART (`cant_attack_this_turn`): at their beginning of combat,
## their biggest attacker stays home — when it matters: three power or
## more, or the swing that would be lethal.
static func cant_attack(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	if g.active_player != foe or g.current_step() != Mtg.Step.COMBAT_BEGIN or not g.stack.is_empty():
		return ""
	var best: CardInstance = null
	var total := 0
	for body in g.players[foe].creatures():
		if body.tapped or body.cur_cant_attack or body.cant_attack_this_turn \
				or body.has_keyword(Mtg.Keyword.DEFENDER) or body.cur_power <= 0:
			continue
		if body.summoning_sick and not body.has_keyword(Mtg.Keyword.HASTE):
			continue
		total += body.cur_power
		if not g.target_legal_at(e.target_spec, TargetRef.card(body), inst, 0):
			continue
		if best == null or body.cur_power > best.cur_power:
			best = body
	if best == null:
		return ""
	if best.cur_power < 3 and total < g.players[pid].life:
		return ""
	return pilot._cast_response(g, inst, [TargetRef.card(best)], 0, "cast %s" % inst.data.card_name)


## IMPS' TAUNT (`force_attack`): at their beginning of combat, their
## creature that must attack — the one a creature of ours blocks, kills and
## survives. Never on our own turn (our creature attacks when we say so).
static func force_attack(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	if g.active_player != foe or g.current_step() != Mtg.Step.COMBAT_BEGIN or not g.stack.is_empty():
		return ""
	var best: CardInstance = null
	var best_value := 0.0
	for theirs in g.players[foe].creatures():
		if theirs.tapped or theirs.cur_cant_attack or theirs.cant_attack_this_turn \
				or theirs.has_keyword(Mtg.Keyword.DEFENDER) or theirs.cur_power < 0:
			continue
		if theirs.summoning_sick and not theirs.has_keyword(Mtg.Keyword.HASTE):
			continue
		if not g.target_legal_at(e.target_spec, TargetRef.card(theirs), inst, 0):
			continue
		var caught := false
		for ours in pilot._untapped_creatures(g, pid):
			if CombatState.block_illegality(g, ours, theirs, pid, true, pid) != "":
				continue
			if _dies_to(g, ours, theirs, ours.cur_power) \
					and not _dies_to(g, theirs, ours, theirs.cur_power):
				caught = true
				break
		if not caught:
			continue
		var worth: float = pilot._victim_value(g, theirs)
		if worth > best_value:
			best = theirs
			best_value = worth
	if best == null or best_value < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, [TargetRef.card(best)], 0, "cast %s" % inst.data.card_name)


# ================================================================ abilities --

## The activated-ability reader's question ([method AiPlayer._ability_option]'s
## expansion chain): `null` when no Pack 9 reading applies to ability
## [param index] of [param s].
static func option(g: MtgGame, pilot, s: CardInstance, index: int, _window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	for e in a.effects:
		if e.ai_role == &"coin_destroy_either":
			return coin_destroy_value(g, pilot, s, a)
		if e.ai_role == &"steal_creature":
			return steal_value(g, pilot, s, e)
	return null


## LEGACY'S ALLURE (`steal_creature`): "Sacrifice this enchantment: Gain
## control of target creature with power less than or equal to the number
## of treasure counters on this enchantment." Their best creature the
## counters now reach, worth taking (a creature for us AND one fewer for
## them); the sacrificed source is priced by the scorer's own sacrifice
## line. `{}` while nothing worth three points is in reach.
static func steal_value(g: MtgGame, pilot, s: CardInstance, e: EffectBase) -> Dictionary:
	var best: CardInstance = null
	var best_value := 0.0
	for body in g.players[g.opponent_of(pilot.pid)].creatures():
		if e.target_spec == null or not g.target_legal_at(e.target_spec, TargetRef.card(body), s, 0):
			continue
		var worth: float = pilot._victim_value(g, body)
		if worth > best_value:
			best = body
			best_value = worth
	if best == null or best_value < 3.0:
		return {}
	return {"value": best_value * 1.5, "targets": [TargetRef.card(best)]}


## MOGG ASSASSIN'S COIN (Pack 9, `coin_destroy_either`): "You choose target
## creature an opponent controls, and that opponent chooses target
## creature. Flip a coin. If you win the flip, destroy the creature you
## chose. If you lose the flip, destroy the creature your opponent chose."
## A fair coin, and the opponent's pick is any creature — ours first, and
## the dearest of ours (the source itself among them). So the activation
## is worth half the best creature of theirs we may name less half the
## dearest creature of ours their slot may name; never worth it when that
## is not positive. `{value, targets}` with our slot's target, or `{}`.
static func coin_destroy_value(g: MtgGame, pilot, s: CardInstance, a: ActivatedAbility) -> Dictionary:
	var pid: int = pilot.pid
	var mine: TargetSpec = null
	var theirs: TargetSpec = null
	for e in a.effects:
		if e.target_spec == null:
			continue
		if e.target_spec.chosen_by_opponent:
			theirs = e.target_spec
		elif mine == null:
			mine = e.target_spec
	if mine == null:
		return {}
	var best: TargetRef = null
	var gain := 0.0
	for ref in mine.legal_targets(g, s):
		if ref.is_player:
			continue
		var victim := g.find_instance(ref.instance_id)
		if victim == null or victim.controller_id == pid:
			continue
		var worth: float = pilot._victim_value(g, victim)
		if best == null or worth > gain:
			best = ref
			gain = worth
	if best == null:
		return {}
	var risk := 0.0
	if theirs != null:
		for ref in theirs.legal_targets(g, s):
			if ref.is_player:
				continue
			var ours := g.find_instance(ref.instance_id)
			if ours != null and ours.controller_id == pid:
				risk = maxf(risk, pilot._own_value(g, ours))
	var value := 0.5 * gain - 0.5 * risk
	return {} if value <= 0.0 else {"value": value, "targets": [best]}
