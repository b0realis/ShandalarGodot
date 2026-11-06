extends RefCounted
## THE URZA BLOCK'S SPELLS, READ BY THE FAIR AI (Pack 10, stage 4,
## casting and resolution answers).
##
## Static functions in the shape of [code]tempest_spells.gd[/code]: each
## takes the pilot ([AiPlayer], untyped to keep the preload cycle open)
## and answers `null` for "not my card, ask the next reader", `{}` for
## "not now" and `{x, targets, value}` for a cast. Every answer is gated
## by [member AiProfile.forecasts_tactics] — with the gate off every
## function answers `null` (or "", false, 0.0, -1) and the pilot plays as
## it did before Pack 10.
##
## The policies read the card's declared shape ([member EffectBase.ai_role]
## and [member EffectBase.ai_parameters], set by the card modules under
## cards/sets/{usg,ulg,uds}/), its typed effects, the echo and cycling
## markers and its printed line — never a card name — and only the public
## board, the stack, both graveyards, both hand SIZES, our own hand and our
## own library's size (docs/fair-play.md): never the opponent's hand, never
## either library's order. The board, combat and activation policies of the
## same pack (Opal dodges, Monoliths, counters cashed in, cheated creatures,
## combat shapes) are [code]urza_tactics.gd[/code]'s.
##
## THE SHAPES, by what they ask of the board:
##  * BOTH SIDES OF THE TABLE — every land, colour, artifact, enchantment or
##    creature of both players moved, bounced or destroyed (Sunder,
##    Hibernation, Rebuild, Harmonic Convergence, Catastrophe, Curfew,
##    Planar Birth, Exhume, Disorder, Acidic Soil, Meltdown): cast only when
##    what they lose beats what we lose by a sweeper's bar.
##  * HANDS — Windfall's greatest hand, Tolarian Winds' dead cards, Ill-
##    Gotten Gains' best three, Unnerve, Show and Tell: our hand by its
##    cards, theirs by its SIZE alone.
##  * COUNTED AS IT RESOLVES — Corrupt's Swamps, the Scents' revealed cards,
##    Titania's Boon's creatures, Congregate's bodies, Goblin Offensive's X.
##  * GIFTS — a creature that hands itself to the opponent (Sleeper Agent),
##    the exchange on arrival (Gilded Drake), Donate, Brand, Flicker.
##  * A LOCK ON WHOEVER IS AHEAD — Damping Engine, cast only while their
##    board outnumbers ours with it ([method permanent_count_lock]).
##  * MANA HANDED BACK — "untap up to N lands" (the untap spells, Great
##    Whale, Peregrine Drake, Palinchron, Treachery) is worth the cast it
##    then pays for ([method cast_adjustment]).
##  * THE PRICE OF A CAST — the opponent's dormant Opal/Veiled/Hidden
##    enchantments our spell would wake, and the echo it commits next
##    upkeep's mana to ([method cast_adjustment]).
##  * THE UPKEEP — echo paid or let go ([method echo_choice]); "sacrifice it
##    unless you discard / sacrifice ..." ([method unless_objects_answer]).
##  * CYCLING — what is dead on the public board, and when a fresh card is
##    worth the discard ([method cycling_sources]).
##  * THE RESPONSES — Humble and Redeem have a moment in a declared combat,
##    never in our empty main phase ([method respond]).

const TEMPEST := preload("res://engine/ai/tempest_spells.gd")
const DAMAGE := preload("res://engine/ai/ice_age_tactics.gd")
const URZA_TACTICS := preload("res://engine/ai/urza_tactics.gd")

## What a sweep must swing to be cast ([constant AiPlayer.SWEEP_BAR]).
const SWEEP_BAR := 3.0
## The bar of a cheap one-sided swing (a one- or two-mana card).
const CHEAP_BAR := 1.5
## The game, on the pilot's scale ([constant AiPlayer.LETHAL_WORTH]).
const LETHAL_WORTH := 1000.0
## A 1/1 creature token's worth on [method AiPlayer._victim_value]'s scale.
const TOKEN_WORTH := 1.25
## A card in the opponent's hand, whose identity we do not know (its
## SIZE is public): the worth of an average card on [method
## Evaluator.card_value]'s scale.
const UNSEEN_CARD := 3.0
## The roles whose only moment is a response ([method respond]).
const RESPONSE_ROLES := [&"silence_and_shrink_until_eot", &"prevent_all_damage_to_creatures"]
## The roles whose moment is OUR FIRST MAIN PHASE, before the attack.
const MAIN_ROLES := [&"grounded_cant_block_this_turn"]
## The roles this pilot leaves in hand (documented in the Pack 10 guide):
## a ritual it has no reading for (each needs a card it enables, and the
## lands it eats), and a graveyard shuffle worth its cycling, not its
## spell.
const NEVER_ROLES := [&"lands_sacrifice_for_black", &"mana_bonus_this_turn",
	&"graveyard_creatures_to_library"]
## How many of the opponent's upkeeps a creature that pings its own
## controller is expected to stay with them (Sleeper Agent).
const GIFT_TURNS := 3.0


# =============================================================== the cast --

## The main-phase planner's question for one card ([method
## AiPlayer._size_and_aim]): `null` when no Pack 10 reading applies.
static func spell_choice(g: MtgGame, pilot, inst: CardInstance, max_x: int, mode: int) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var data := inst.data
	if data.is_creature():
		var gift: Variant = gift_on_arrival(g, pilot, inst)
		if gift != null:
			return gift
		var swap: Variant = exchange_on_arrival(g, pilot, inst)
		if swap != null:
			return swap
		var dogs: Variant = life_race_creature(g, pilot, inst)
		if dogs != null:
			return dogs
	var animator: Variant = card_type_animator(g, pilot, inst)
	if animator != null:
		return animator
	var lock: Variant = permanent_count_lock(g, pilot, inst)
	if lock != null:
		return lock
	var effects: Array = data.modes[mode]["effects"] if data.is_modal() \
		and mode < data.modes.size() else data.spell_effects
	for e in effects:
		var role: StringName = e.ai_role
		if role == &"":
			continue
		if role in RESPONSE_ROLES or role in NEVER_ROLES:
			return {}
		match role:
			&"return_all_basic_lands": return planar_birth(g, pilot)
			&"each_player_bounces_own_creature": return curfew(g, pilot)
			&"bounce_all_of_color": return color_bounce(g, pilot, int(e.ai_parameters.get("color", 0)))
			&"bounce_all_lands": return land_bounce(g, pilot)
			&"grounded_cant_block_this_turn": return falter(g, pilot)
			&"counter_on_each_own_creature": return team_counters(g, pilot, e)
			&"life_per_creature_on_battlefield": return congregate(g, pilot, inst, e)
			&"discard_hand_draw_that_many": return hand_refresh(g, pilot, inst)
			&"wheel_greatest_hand": return greatest_hand_wheel(g, pilot, inst)
			&"swamp_count_drain": return swamp_drain(g, pilot, inst, e)
			&"wheel_regrow_three": return regrow_three(g, pilot, inst)
			&"sacrifice_any_number_draw": return reprocess(g, pilot)
			&"each_opponent_discards": return opponent_discards(g, pilot, e)
			&"damage_each_player_per_land": return land_burn(g, pilot)
			&"white_creatures_and_their_controllers": return color_burn(g, pilot, inst, e)
			&"tutor_then_random_discard": return gamble(g, pilot, inst)
			&"x_tokens": return x_tokens(g, pilot, max_x)
			&"artifact_sweep_mana_value_x": return artifact_sweep_x(g, pilot, max_x)
			&"sacrifice_creatures_damage": return last_ditch(g, pilot, inst, e)
			&"enchantments_to_library_top": return enchantments_home(g, pilot)
			&"each_player_reanimates_one": return exhume(g, pilot, inst)
			&"mass_artifact_bounce": return artifact_bounce(g, pilot)
			&"regain_control": return regain_control(g, pilot)
			&"skip_draw_step": return skip_draw(g, pilot, inst, e)
			&"flicker_permanent": return flicker(g, pilot, inst, e)
			&"donate_permanent": return donate(g, pilot, inst, effects)
			&"lands_to_library_top": return plow_under(g, pilot, inst, e)
			&"sweep_lands_or_creatures": return lands_or_creatures(g, pilot)
			&"reveal_from_hand": return reveal_choice(g, pilot, inst, e)
	# Shapes no role names, read off the effect's own printed line.
	var line := _line_of(effects)
	if line.contains("cast spells from your graveyard"):
		return graveyard_replay(g, pilot, inst)
	if line.begins_with("each player may put an artifact, creature, enchantment, or land card from their hand"):
		return show_and_tell(g, pilot, inst)
	if line.begins_with("return all enchantment cards from your graveyard to the battlefield"):
		return replenish(g, pilot, inst)
	return null


## Is [param data] a card whose Pack 10 reading casts it in our first main
## phase ([constant MAIN_ROLES])? Asked by [method AiPlayer._is_held_instant].
static func main_phase_card(data: CardData) -> bool:
	for e in data.spell_effects:
		if e.ai_role in MAIN_ROLES:
			return true
	return false


## May a HELD instant be fired or booked at all? False for a card whose
## moment is a Pack 10 response, or never.
static func held_veto(_g: MtgGame, pilot, inst: CardInstance) -> bool:
	if not pilot.profile.forecasts_tactics:
		return false
	for e in inst.data.spell_effects:
		if e.ai_role in RESPONSE_ROLES or e.ai_role in NEVER_ROLES:
			return true
		if e.ai_role == &"reveal_from_hand" \
				and StringName(e.ai_parameters.get("per_card", &"")) == &"pump":
			return true
	return false


## The lower-cased descriptions of [param effects], joined — of the
## effects the typed reader has no model for ([member
## EffectIntent.unknown]), whose own line is the only thing they say about
## themselves: the same effects [method EffectIntent._wheel_draw] reads.
## A typed effect's line is never read here (an engine line can assume a
## target the effect does not have — a self-pump's [method
## PumpEffect.describe]).
static func _line_of(effects: Array) -> String:
	var parts := PackedStringArray()
	for e in effects:
		if EffectIntent.read([e]).unknown:
			parts.append(e.describe().to_lower())
	return " ".join(parts)


## The worth of [param body] to its controller, on the pilot's two scales.
static func _worth(g: MtgGame, pilot, body: CardInstance) -> float:
	return float(pilot._own_value(g, body)) if body.controller_id == pilot.pid \
		else float(pilot._victim_value(g, body))


## What a card of OUR hand is worth keeping: a land beyond a built mana
## base is little, any other card its printed worth.
static func hand_worth(g: MtgGame, pilot, card: CardInstance) -> float:
	if card.data.is_land():
		var lands := 0
		for p in g.players[pilot.pid].battlefield:
			if p.is_land():
				lands += 1
		return 0.5 if lands >= 5 and not pilot._land_light(g) else 2.5
	return Evaluator.card_value(card.data)


## Is [param card] of our hand dead weight right now — a land beyond a
## built mana base, or a spell no turn soon pays for (its mana value two
## above every land we have and hold)?
static func dead_in_hand(g: MtgGame, pilot, card: CardInstance) -> bool:
	var me := g.players[pilot.pid]
	var lands := 0
	for p in me.battlefield:
		if p.is_land():
			lands += 1
	if card.data.is_land():
		return lands >= 5 and not pilot._land_light(g)
	var held := 0
	for other in me.hand:
		if other.data.is_land():
			held += 1
	return card.data.cost.mana_value() > lands + held + 2


# ------------------------------------------------------- both sides of the table --

## OPALESCENCE (a static that retypes by CARD TYPE — "each other non-Aura
## enchantment is a creature" — [member StaticAbility.reads_card_types],
## Pack 10 E3): every such enchantment of BOTH sides becomes a creature.
## Projected under the search journal ([method TempestSpells.static_projection],
## Humility's layers included) and priced on both sides: `{}` while it
## gives their board at least as much as ours; a value for the bodies it
## gives us otherwise. null for any other card.
static func card_type_animator(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	if inst.zone != Mtg.Zone.HAND or data.is_creature() or data.is_aura():
		return null
	var reads := false
	for st in data.static_abilities:
		if st.reads_card_types:
			reads = true
	if not reads:
		return null
	var swing := TEMPEST.static_projection(g, pilot, inst)
	var ours: float = swing["ours"]
	var theirs: float = swing["theirs"]
	if ours - theirs < 1.0:
		return {}
	return {"x": 0, "targets": [], "value": ours - theirs + Evaluator.card_value(data) * 0.5}


## DAMPING ENGINE (no role; a play ban and its printed line: "A player who
## controls more permanents than each other player can't play lands or
## cast artifact, creature, or enchantment spells"): a lock on whoever is
## AHEAD on permanents, counted live at every play — the Engine itself
## among ours once it lands. The probe cast it four lands and a Bear to
## one Forest, a lock on nobody but us (the 0.60.19 bug pass, h5-3). `{}`
## unless their board still outnumbers ours with the Engine on it (equal
## counts bind nobody); then null — the shared reader's cast. null for any
## other card.
static func permanent_count_lock(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	if not data.play_ban.is_valid() or not data.oracle_text.to_lower().contains(
			"who controls more permanents than each other player can't"):
		return null
	var pid: int = pilot.pid
	var ours := g.players[pid].battlefield.size() + (0 if inst.zone == Mtg.Zone.BATTLEFIELD else 1)
	return null if g.players[g.opponent_of(pid)].battlefield.size() > ours else {}


## PLANAR BIRTH (`return_all_basic_lands`): every basic land card in every
## graveyard returns, tapped, under its owner. Our lands back against
## theirs (both graveyards are public).
static func planar_birth(g: MtgGame, pilot) -> Dictionary:
	var swing := 0.0
	for p in [pilot.pid, g.opponent_of(pilot.pid)]:
		var n := 0
		for card in g.players[p].graveyard:
			if card.data.is_land() and (card.data.supertypes & Mtg.Supertype.BASIC) != 0:
				n += 1
		swing += float(n) * (1.0 if p == pilot.pid else -1.0)
	return {} if swing < 2.0 else {"x": 0, "targets": [], "value": swing * 1.25}


## CURFEW (`each_player_bounces_own_creature`): each player returns a
## creature of their choice — the one they miss least, a token last. A
## card returned is a recast (half its worth), a token returned is gone.
static func curfew(g: MtgGame, pilot) -> Dictionary:
	var swing := 0.0
	for p in [pilot.pid, g.opponent_of(pilot.pid)]:
		var least := INF
		var least_token := INF
		for body in g.players[p].creatures():
			if not g.is_present(body):
				continue
			var w := _worth(g, pilot, body)
			if body.is_token:
				least_token = minf(least_token, w)
			else:
				least = minf(least, w * 0.5)
		var lost := least if least < INF else (least_token if least_token < INF else 0.0)
		swing += lost if p != pilot.pid else -lost
	return {} if swing < CHEAP_BAR else {"x": 0, "targets": [], "value": swing}


## The swing of every permanent [param hit] picks returning to its owner's
## hand: a token is gone, a card is a recast.
static func _bounce_swing(g: MtgGame, pilot, hit: Callable) -> float:
	var swing := 0.0
	for body in g.all_battlefield():
		if not g.is_present(body) or not bool(hit.call(body)):
			continue
		var lost := _worth(g, pilot, body) * (1.0 if body.is_token else 0.5)
		swing += lost if body.controller_id != pilot.pid else -lost
	return swing


## HIBERNATION (`bounce_all_of_color`, `color`): every permanent of the
## colour, both sides.
static func color_bounce(g: MtgGame, pilot, color: int) -> Dictionary:
	if color == 0:
		return {}
	var swing := _bounce_swing(g, pilot, func(b: CardInstance) -> bool:
		return (b.cur_colors & color) != 0)
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## REBUILD (`mass_artifact_bounce`): every artifact, both sides.
static func artifact_bounce(g: MtgGame, pilot) -> Dictionary:
	var swing := _bounce_swing(g, pilot, func(b: CardInstance) -> bool:
		return b.is_type(Mtg.CardType.ARTIFACT))
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## SUNDER (`bounce_all_lands`): every land to its owner's hand. Both sides
## rebuild a land a turn, so what counts is the land LEAD it erases, the
## mana that does not come from lands (ours and theirs), and the board
## that keeps attacking through the drought.
static func land_bounce(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var swing := 0.0
	for p in [pid, foe]:
		var lands := 0
		var rocks := 0
		for body in g.players[p].battlefield:
			if not g.is_present(body):
				continue
			if body.is_land():
				lands += 1
			elif not body.cur_mana_abilities.is_empty():
				rocks += 1
		var lost := float(lands) * Evaluator.W_LANDS - float(rocks) * 1.5
		swing += lost if p != pid else -lost
	swing += (_creatures_worth(g, pilot, pid) - _creatures_worth(g, pilot, foe)) * 0.25
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## [param who]'s creatures at [method Evaluator.permanent_value].
static func _creatures_worth(g: MtgGame, pilot, who: int) -> float:
	var total := 0.0
	for body in g.players[who].creatures():
		if g.is_present(body):
			total += Evaluator.permanent_value(body, pilot.profile)
	return total


## HARMONIC CONVERGENCE (`enchantments_to_library_top`): every enchantment
## on top of its owner's library — gone from the board, and the owner's
## next draw spent on drawing it again.
static func enchantments_home(g: MtgGame, pilot) -> Dictionary:
	var swing := 0.0
	for body in g.all_battlefield():
		if not g.is_present(body) or not body.is_type(Mtg.CardType.ENCHANTMENT):
			continue
		var lost := _worth(g, pilot, body) * (1.0 if body.is_token else 0.75) + 0.5
		swing += lost if body.controller_id != pilot.pid else -lost
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## CATASTROPHE (`sweep_lands_or_creatures`): the caster chooses as it
## resolves; the card's own hint names the side whose loss costs the other
## seat more (lands weigh three each, a creature its mana value, power and
## toughness), and that choice is the one priced here, on the pilot's own
## scales. A choice that costs us more is no cast.
static func lands_or_creatures(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var crude_creatures := 0
	var crude_lands := 0
	var creatures := 0.0
	var lands := 0.0
	for body in g.all_battlefield():
		if not g.is_present(body):
			continue
		var side := 1 if body.controller_id != pid else -1
		if body.is_creature():
			crude_creatures += side * (1 + body.data.cost.mana_value() \
				+ maxi(body.cur_power, 0) + maxi(body.cur_toughness, 0))
			creatures += float(side) * _worth(g, pilot, body)
		if body.is_land():
			crude_lands += side * 3
			lands += float(side) * _worth(g, pilot, body)
	var swing := creatures if crude_creatures >= crude_lands else lands
	return {} if swing < SWEEP_BAR else {"x": 0, "targets": [], "value": swing}


## EXHUME (`each_player_reanimates_one`): each player puts a creature card
## from their own graveyard onto the battlefield — their best, both
## graveyards public. Ours against theirs.
static func exhume(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var ours := _best_creature_card(g, pilot.pid, inst)
	if ours <= 0.0:
		return {}
	var theirs := _best_creature_card(g, g.opponent_of(pilot.pid), inst)
	var swing := ours - theirs
	return {} if swing < 2.0 else {"x": 0, "targets": [], "value": swing}


static func _best_creature_card(g: MtgGame, who: int, skip: CardInstance) -> float:
	var best := 0.0
	for card in g.players[who].graveyard:
		if card == skip or not card.data.is_creature():
			continue
		best = maxf(best, Evaluator.card_value(card.data))
	return best


## DISORDER (`white_creatures_and_their_controllers`, `amount`): the
## points at every white creature and at each player who controls one.
static func color_burn(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var amount := int(e.ai_parameters.get("amount", 2))
	var swing := 0.0
	var hit := {pid: false, foe: false}
	for body in g.all_battlefield():
		if not g.is_present(body) or not body.is_creature() \
				or (body.cur_colors & Mtg.ManaColor.W) == 0:
			continue
		hit[body.controller_id] = true
		if TEMPEST._dies_to(g, inst, body, amount):
			swing += _worth(g, pilot, body) * (1.0 if body.controller_id != pid else -1.0)
	if bool(hit[pid]) and amount >= g.players[pid].life:
		return {}
	if bool(hit[foe]):
		if amount >= g.players[foe].life:
			return {"x": 0, "targets": [], "value": LETHAL_WORTH}
		swing += pilot._face_damage_value(g, amount, foe)
	if bool(hit[pid]):
		swing -= float(amount) * pilot._life_price(g.players[pid].life)
	return {} if swing < 2.0 else {"x": 0, "targets": [], "value": swing}


## ACIDIC SOIL (`damage_each_player_per_land`): a point to each player per
## land they control. Never into our own death; the game when it is
## theirs; else their points less ours.
static func land_burn(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var mine := 0
	var theirs := 0
	for body in g.all_battlefield():
		if g.is_present(body) and body.is_land():
			if body.controller_id == pid:
				mine += 1
			else:
				theirs += 1
	if mine >= g.players[pid].life:
		return {}
	if theirs >= g.players[foe].life:
		return {"x": 0, "targets": [], "value": LETHAL_WORTH}
	var value: float = pilot._face_damage_value(g, theirs, foe) \
		- float(mine) * pilot._life_price(g.players[pid].life)
	return {} if value < 2.0 else {"x": 0, "targets": [], "value": value}


## MELTDOWN (`artifact_sweep_mana_value_x`): every artifact whose printed
## mana value is X or less — the X with the best swing of theirs against
## ours.
static func artifact_sweep_x(g: MtgGame, pilot, max_x: int) -> Dictionary:
	var best_x := -1
	var best := 0.0
	for x in range(0, max_x + 1):
		var swing := 0.0
		for body in g.all_battlefield():
			if not g.is_present(body) or not body.is_type(Mtg.CardType.ARTIFACT) \
					or body.cur_indestructible or body.data.cost.mana_value() > x:
				continue
			swing += _worth(g, pilot, body) * (1.0 if body.controller_id != pilot.pid else -1.0)
		if swing > best:
			best = swing
			best_x = x
	if best_x < 0 or best < SWEEP_BAR:
		return {}
	return {"x": best_x, "targets": [], "value": best}


## TITANIA'S BOON (`counter_on_each_own_creature`, `count`): a +1/+1
## counter on each creature of ours — worth it across two bodies.
static func team_counters(g: MtgGame, pilot, e: EffectBase) -> Dictionary:
	var n := 0
	for body in g.players[pilot.pid].creatures():
		if g.is_present(body):
			n += 1
	if n < 2:
		return {}
	return {"x": 0, "targets": [], "value": float(n * int(e.ai_parameters.get("count", 1))) * 1.5}


## CONGREGATE (`life_per_creature_on_battlefield`, `per`): life for us,
## counted from every creature on the battlefield — worth what that life
## is needed for ([method AiPlayer._life_gain_worth]).
static func congregate(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var n := 0
	for body in g.all_battlefield():
		if g.is_present(body) and body.is_creature():
			n += 1
	var me := TargetRef.player(pilot.pid)
	if e.target_spec != null and not g.target_legal_at(e.target_spec, me, inst, 0):
		return {}
	var value: float = pilot._life_gain_worth(g, n * int(e.ai_parameters.get("per", 2)))
	return {} if value < 2.0 else {"x": 0, "targets": [me], "value": value}


## FALTER (`grounded_cant_block_this_turn`): no creature without flying
## blocks this turn. In our first main phase, with an attack: the game when
## their fliers alone cannot stop it, else the damage it adds past their
## grounded blockers.
static func falter(g: MtgGame, pilot) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	if g.active_player != pid or g.current_step() != Mtg.Step.MAIN1:
		return {}
	var attackers: Array[CardInstance] = pilot._attack_candidates(g, foe)
	if attackers.is_empty():
		return {}
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	var fliers: Array[CardInstance] = []
	for body in blockers:
		if body.has_keyword(Mtg.Keyword.FLYING):
			fliers.append(body)
	if fliers.size() == blockers.size():
		return {}   # nothing of theirs is grounded
	var before: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	var after: int = pilot._damage_through_blocks(g, attackers, fliers, foe)
	if after >= g.players[foe].life:
		return {"x": 0, "targets": [], "value": LETHAL_WORTH}
	var gain := after - before
	if gain < 3:
		return {}
	return {"x": 0, "targets": [], "value": pilot._face_damage_value(g, gain, foe)}


# --------------------------------------------------------------------- the hands --

## TOLARIAN WINDS (`discard_hand_draw_that_many`): the hand for as many
## fresh cards — worth the dead cards in it ([method dead_in_hand]), never
## for fewer than two of them, never into a library it would empty.
static func hand_refresh(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var me := g.players[pilot.pid]
	var held := 0
	var dead := 0
	for card in me.hand:
		if card == inst:
			continue
		held += 1
		if dead_in_hand(g, pilot, card):
			dead += 1
	if dead < 2 or me.library.size() <= held + 2:
		return {}
	return {"x": 0, "targets": [], "value": float(dead) * pilot.profile.w_hand * 0.8}


## WINDFALL (`wheel_greatest_hand`): every hand discarded, each player
## draws as many as the greatest. We gain what our hand was short of the
## greatest, they gain what theirs was short of it — their hand by its
## SIZE alone. The game when their library cannot pay the draw and ours
## can; never into a library of ours it would empty.
static func greatest_hand_wheel(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var me := g.players[pid]
	var ours := me.hand.size() - (1 if inst.zone == Mtg.Zone.HAND else 0)
	var theirs := g.players[foe].hand.size()
	var most := maxi(ours, theirs)
	if most <= 0 or me.library.size() < most + 2:
		return {}
	if g.players[foe].library.size() < most:
		return {"x": 0, "targets": [], "value": LETHAL_WORTH}
	var dead := 0
	for card in me.hand:
		if card != inst and dead_in_hand(g, pilot, card):
			dead += 1
	var value: float = float((most - ours) - (most - theirs)) * pilot.profile.w_hand \
		+ float(dead) * 0.5 * pilot.profile.w_hand
	return {} if value < CHEAP_BAR else {"x": 0, "targets": [], "value": value}


## ILL-GOTTEN GAINS (`wheel_regrow_three`): every hand discarded, then each
## player returns up to three cards of their graveyard. Our best three of
## hand and graveyard against the hand we had; theirs from their PUBLIC
## graveyard and their hand's SIZE, each unseen card an average card.
static func regrow_three(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var ours: Array[float] = []
	var had := 0.0
	for card in g.players[pid].hand:
		if card == inst:
			continue
		var w := hand_worth(g, pilot, card)
		ours.append(w)
		had += w
	for card in g.players[pid].graveyard:
		ours.append(Evaluator.card_value(card.data))
	var theirs: Array[float] = []
	var held: int = g.players[foe].hand.size()
	for _i in held:
		theirs.append(UNSEEN_CARD)
	for card in g.players[foe].graveyard:
		theirs.append(Evaluator.card_value(card.data))
	var gain := _top_sum(ours, 3) - had
	var their_gain := _top_sum(theirs, 3) - float(held) * UNSEEN_CARD
	var swing := gain - their_gain
	return {} if swing < 2.0 else {"x": 0, "targets": [], "value": swing}


static func _top_sum(values: Array[float], n: int) -> float:
	var sorted := values.duplicate()
	sorted.sort()
	sorted.reverse()
	var total := 0.0
	for i in mini(n, sorted.size()):
		total += float(sorted[i])
	return total


## UNNERVE (`each_opponent_discards`, `count`): cards out of their hand —
## only what its public size holds.
static func opponent_discards(g: MtgGame, pilot, e: EffectBase) -> Dictionary:
	var n := mini(int(e.ai_parameters.get("count", 1)), g.players[g.opponent_of(pilot.pid)].hand.size())
	if n <= 0:
		return {}
	return {"x": 0, "targets": [], "value": float(n) * pilot.profile.w_hand}


## GAMBLE (`tutor_then_random_discard`): the card found joins the hand
## before the random discard — with nothing else in hand it is the card
## discarded. Otherwise the tutor's own reading (null).
static func gamble(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var others := 0
	for card in g.players[pilot.pid].hand:
		if card != inst:
			others += 1
	return {} if others == 0 else null


## SHOW AND TELL (no role; its line): each player may put an artifact,
## creature, enchantment or land card from their hand onto the battlefield.
## Ours is our biggest such card (the card's own default), worth its card
## and the mana it saves; theirs, whose hand we do not see, an average
## permanent while their hand holds anything at all.
static func show_and_tell(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var best: CardInstance = null
	for card in g.players[pilot.pid].hand:
		if card == inst or not card.data.is_permanent_type():
			continue
		if card.data.is_aura() and g.aura_entry_hosts(card, pilot.pid).is_empty():
			continue
		if best == null or card.data.cost.mana_value() > best.data.cost.mana_value():
			best = card
	if best == null:
		return {}
	var ours := Evaluator.card_value(best.data) + float(best.data.cost.mana_value()) * 0.5
	var theirs := UNSEEN_CARD + 1.5 if g.players[g.opponent_of(pilot.pid)].hand.size() > 0 else 0.0
	var value := ours - theirs
	return {} if value < 2.0 else {"x": 0, "targets": [], "value": value}


# ------------------------------------------------------------- counted as it resolves --

## The opponent as a legal target of [param e] for [param inst], or null.
static func _opponent_ref(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> TargetRef:
	var foe := TargetRef.player(g.opponent_of(pilot.pid))
	if e.target_spec == null or not g.target_legal_at(e.target_spec, foe, inst, 0):
		return null
	return foe


## [param amount] points from [param inst] at the best of their creatures
## it kills or at their face: the game when lethal, the creature when it
## is worth more than the points at the face (three or more), plus
## [param extra] either way.
static func _burn_choice(g: MtgGame, pilot, inst: CardInstance, e: EffectBase, amount: int,
		extra := 0.0) -> Dictionary:
	if amount <= 0:
		return {}
	var foe := g.opponent_of(pilot.pid)
	var face := _opponent_ref(g, pilot, inst, e)
	if face != null and DAMAGE.damage_through(g, inst, face, amount) >= g.players[foe].life:
		return {"x": 0, "targets": [face], "value": LETHAL_WORTH}
	var best := {}
	for body in g.players[foe].creatures():
		var ref := TargetRef.card(body)
		if e.target_spec == null or not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		if not TEMPEST._dies_to(g, inst, body, amount):
			continue
		var worth: float = pilot._victim_value(g, body) + 1.0 + extra
		if best.is_empty() or worth > float(best["value"]):
			best = {"x": 0, "targets": [ref], "value": worth}
	if face != null and amount >= 3:
		var dealt := DAMAGE.damage_through(g, inst, face, amount)
		var worth: float = pilot._face_damage_value(g, dealt, foe) + extra
		if dealt > 0 and (best.is_empty() or worth > float(best["value"])):
			best = {"x": 0, "targets": [face], "value": worth}
	return best


## CORRUPT (`swamp_count_drain`): as many points as Swamps we control, and
## the life the damage gives us.
static func swamp_drain(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var n := 0
	for body in g.players[pilot.pid].battlefield:
		if g.is_present(body) and body.is_land() and body.has_subtype("swamp"):
			n += 1
	return _burn_choice(g, pilot, inst, e, n, pilot._life_gain_worth(g, n))


## Our hand's cards of [param color], [param inst] aside — the "reveal any
## number" count (our own hand: fair).
static func colored_in_hand(g: MtgGame, pilot, inst: CardInstance, color: int) -> int:
	var n := 0
	for card in g.players[pilot.pid].hand:
		if card != inst and (card.data.color_mask() & color) != 0:
			n += 1
	return n


## THE SEERS' AND SCENTS' SPELLS (`reveal_from_hand`, `color`, `per_card`,
## `amount`): X is the cards of the colour in our hand, revealed all when
## the payout serves us (the card's own answer). Life is worth what it is
## needed for, damage and -X/-X kill, a pump waits for its combat, the
## counter for the counter reader, the enchantments returned are their
## cards.
static func reveal_choice(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Variant:
	var n := colored_in_hand(g, pilot, inst, int(e.ai_parameters.get("color", 0)))
	var amount := int(e.ai_parameters.get("amount", 1))
	match StringName(e.ai_parameters.get("per_card", &"")):
		&"life":
			var value: float = pilot._life_gain_worth(g, n * amount)
			return {} if value < 1.5 else {"x": 0, "targets": [], "value": value}
		&"damage":
			return _burn_choice(g, pilot, inst, e, n * amount)
		&"shrink":
			return _shrink_choice(g, pilot, inst, e, n * amount)
		&"pump":
			return {}
		&"raise_enchantment":
			var found: Array[float] = []
			for card in g.players[pilot.pid].graveyard:
				if card.data.is_type(Mtg.CardType.ENCHANTMENT):
					found.append(Evaluator.card_value(card.data))
			var value := _top_sum(found, n * amount)
			return {} if value < 2.5 else {"x": 0, "targets": [], "value": value}
	return null


## -[param amount]/-[param amount]: their best creature it kills.
static func _shrink_choice(g: MtgGame, pilot, inst: CardInstance, e: EffectBase, amount: int) -> Dictionary:
	if amount <= 0:
		return {}
	var best := {}
	for body in g.players[g.opponent_of(pilot.pid)].creatures():
		var ref := TargetRef.card(body)
		if e.target_spec == null or not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		if body.cur_toughness > amount:
			continue
		var worth: float = pilot._victim_value(g, body) + 1.0
		if best.is_empty() or worth > float(best["value"]):
			best = {"x": 0, "targets": [ref], "value": worth}
	return best


## GOBLIN OFFENSIVE (`x_tokens`): X 1/1 tokens at the largest X — worth it
## from two bodies.
static func x_tokens(_g: MtgGame, _pilot, max_x: int) -> Dictionary:
	if max_x < 2:
		return {}
	return {"x": max_x, "targets": [], "value": float(max_x) * 1.5}


## REPROCESS (`sacrifice_any_number_draw`): what the card's own hint
## sacrifices — our tokens and the lands beyond the sixth — a card each.
static func reprocess(g: MtgGame, pilot) -> Dictionary:
	var lands: Array[float] = []
	var eaten := 0.0
	var n := 0
	for body in g.players[pilot.pid].battlefield:
		if not g.is_present(body):
			continue
		var kind := body.is_type(Mtg.CardType.ARTIFACT) or body.is_creature() or body.is_land()
		if body.is_token and kind:
			n += 1
			eaten += float(pilot._own_value(g, body))
		elif body.is_land():
			lands.append(float(pilot._own_value(g, body)))
	if lands.size() > 6:
		lands.sort()
		for i in lands.size() - 6:
			n += 1
			eaten += lands[i]
	var value: float = float(n) * pilot.profile.w_hand - eaten * 0.5
	return {} if n < 2 or value < 2.0 else {"x": 0, "targets": [], "value": value}


## LAST-DITCH EFFORT (`sacrifice_creatures_damage`): as many points as
## creatures sacrificed — the card's own hint eats just enough to finish an
## opposing target. Cast for the game, or for a creature of theirs worth
## more than the bodies it eats.
static func last_ditch(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var bodies: Array[float] = []
	for body in g.players[pid].creatures():
		if g.is_present(body):
			bodies.append(float(pilot._own_value(g, body)))
	bodies.sort()
	var face := _opponent_ref(g, pilot, inst, e)
	if face != null and g.players[foe].life <= bodies.size() \
			and DAMAGE.damage_through(g, inst, face, bodies.size()) >= g.players[foe].life:
		return {"x": 0, "targets": [face], "value": LETHAL_WORTH}
	var best := {}
	for victim in g.players[foe].creatures():
		var need := maxi(victim.cur_toughness - victim.damage, 0)
		if need <= 0 or need > bodies.size():
			continue
		var ref := TargetRef.card(victim)
		if not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		var eaten := 0.0
		for i in need:
			eaten += bodies[i]
		var value: float = pilot._victim_value(g, victim) - eaten
		if value > 1.0 and (best.is_empty() or value > float(best["value"])):
			best = {"x": 0, "targets": [ref], "value": value}
	return best


# --------------------------------------------------------------------- the gifts --

## BRAND (`regain_control`): every permanent we own that they control comes
## back — its worth to them and to us.
static func regain_control(g: MtgGame, pilot) -> Dictionary:
	var value := 0.0
	for body in g.players[g.opponent_of(pilot.pid)].battlefield:
		if body.owner_id == pilot.pid and g.is_present(body):
			value += float(pilot._victim_value(g, body)) * 2.0
	return {} if value <= 0.0 else {"x": 0, "targets": [], "value": value}


## FATIGUE (`skip_draw_step`): their next draw step, a card.
static func skip_draw(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var foe := _opponent_ref(g, pilot, inst, e)
	if foe == null:
		return {}
	return {"x": 0, "targets": [foe], "value": pilot.profile.w_hand}


## FLICKER (`flicker_permanent`): a nontoken permanent exiled and returned
## under its OWNER's control. Worth it on a permanent of ours they control
## (it comes home), or on one of ours wearing their hostile Auras (they
## fall off); never on what the return would only reset.
static func flicker(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	var best := {}
	for body in g.all_battlefield():
		if not g.is_present(body) or body.is_token:
			continue
		var ref := TargetRef.card(body)
		if not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		var value := 0.0
		if body.owner_id == pid and body.controller_id != pid:
			value = float(pilot._victim_value(g, body)) * 2.0
		elif body.controller_id == pid:
			for aura_id in body.attachments:
				var aura := g.find_instance(aura_id)
				if aura != null and aura.controller_id != pid \
						and EffectIntent.aura_aim(aura.data) == EffectIntent.Aim.HOSTILE:
					value += Evaluator.card_value(aura.data)
			if body.is_creature() and EchoAbility.has_echo(body):
				value -= 2.0   # a fresh object owes its echo again
		if value > 2.0 and (best.is_empty() or value > float(best["value"])):
			best = {"x": 0, "targets": [ref], "value": value}
	return best


## DONATE (`donate_permanent` on both slots, the player and the permanent
## of ours): our permanent that is a liability to its controller ([method
## AiPlayer._own_value] below nothing) — a Sleeper Agent, a Delusions of
## Mediocrity — handed to the opponent. Never anything we would keep.
static func donate(g: MtgGame, pilot, inst: CardInstance, effects: Array) -> Dictionary:
	if effects.size() < 2 or effects[0].target_spec == null or effects[1].target_spec == null:
		return {}
	var pid: int = pilot.pid
	var foe := TargetRef.player(g.opponent_of(pid))
	if not g.target_legal_at(effects[0].target_spec, foe, inst, 0):
		return {}
	var best := {}
	for body in g.players[pid].battlefield:
		if not g.is_present(body):
			continue
		var ref := TargetRef.card(body)
		if not g.target_legal_at(effects[1].target_spec, ref, inst, 0, [foe]):
			continue
		var shed := -float(pilot._own_value(g, body))
		var toll: float = preload("res://engine/ai/tempest_tactics.gd").toll_per_turn(body.data.triggered_abilities)
		if toll > 0.0:   # the points off our life, and onto theirs
			shed += toll * GIFT_TURNS * (pilot._life_price(g.players[pid].life) \
				+ pilot._life_price(g.players[g.opponent_of(pid)].life))
		if shed > 1.0 and (best.is_empty() or shed > float(best["value"])):
			best = {"x": 0, "targets": [foe, ref], "value": shed}
	return best


## PLOW UNDER (`lands_to_library_top`, two targets): their two best lands
## on top of their library — the lands, and the two draws they redraw them
## with.
static func plow_under(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> Dictionary:
	var lands: Array = []
	for body in g.players[g.opponent_of(pilot.pid)].battlefield:
		if not g.is_present(body) or not body.is_land():
			continue
		if not g.target_legal_at(e.target_spec, TargetRef.card(body), inst, 0):
			continue
		lands.append([float(pilot._victim_value(g, body)), body])
	if lands.size() < 2:
		return {}
	lands.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var first := TargetRef.card(lands[0][1])
	var second := TargetRef.card(lands[1][1])
	if not g.target_legal_at(e.target_spec, second, inst, 0, [first]):
		return {}
	var value: float = float(lands[0][0]) + float(lands[1][0]) + 2.0 * pilot.profile.w_hand * 0.5
	return {"x": 0, "targets": [first, second], "value": value}


## SLEEPER AGENT (a creature whose own arrival hands it to the opponent,
## and whose own upkeep trigger hurts its controller): cast only when the
## toll they will pay outweighs the body they get — read off the board:
## the attacker it is for them against our blockers, their life against
## the toll. null for any other creature.
static func gift_on_arrival(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	var gives := false
	for t in data.triggered_abilities:
		if t.event_type == Mtg.EventType.ENTERS_BATTLEFIELD \
				and t.text.to_lower().contains("opponent gains control of it"):
			gives = true
	if not gives:
		return null
	var pid: int = pilot.pid
	var foe := g.opponent_of(pid)
	var per_turn: float = preload("res://engine/ai/tempest_tactics.gd").toll_per_turn(data.triggered_abilities)
	var their_life: int = g.players[foe].life
	var power := Evaluator.arrival_power(data)
	var toughness := Evaluator.arrival_toughness(data)
	# Their attacker, against our best untapped blocker.
	var held := false
	for body in g.players[pid].creatures():
		if body.cur_toughness > power or body.cur_power >= toughness:
			held = true
	var threat: float = 0.0 if held else float(power) * GIFT_TURNS * pilot._life_price(g.players[pid].life)
	if not held and power * 2 >= g.players[pid].life:
		return {}
	if per_turn > 0.0 and float(their_life) <= per_turn * 2.0:
		return {"x": 0, "targets": [], "value": LETHAL_WORTH * 0.5}
	var value: float = per_turn * GIFT_TURNS * pilot._life_price(their_life) - threat \
		- Evaluator.card_value(data) * 0.25
	return {} if value < 1.0 else {"x": 0, "targets": [], "value": value}


## GILDED DRAKE (a creature whose arrival exchanges it for "up to one
## target creature an opponent controls", sacrificed when it cannot): never
## cast without a creature of theirs worth more than the body it hands
## over.
static func exchange_on_arrival(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	var data := inst.data
	var swap: TriggeredAbility = null
	for t in data.triggered_abilities:
		if t.event_type == Mtg.EventType.ENTERS_BATTLEFIELD and t.target_spec != null \
				and t.text.to_lower().contains("exchange control of this creature"):
			swap = t
	if swap == null:
		return null
	var given := Evaluator.card_value(data)
	var best := 0.0
	for body in g.players[g.opponent_of(pilot.pid)].creatures():
		if not g.is_present(body) or not g.target_legal_at(swap.target_spec, TargetRef.card(body), inst, 0):
			continue
		if body.cur_cant_change_control:
			continue
		best = maxf(best, float(pilot._victim_value(g, body)))
	var value := best * 2.0 - given
	return {} if best <= 0.0 or value < 2.0 else {"x": 0, "targets": [], "value": value}


## WILD DOGS (a creature whose upkeep trigger hands it to "the player with
## the most life"): never cast while that player is the opponent.
static func life_race_creature(g: MtgGame, pilot, inst: CardInstance) -> Variant:
	for t in inst.data.triggered_abilities:
		if t.event_type == Mtg.EventType.UPKEEP_START \
				and t.text.to_lower().contains("the player with the most life gains control"):
			if g.players[g.opponent_of(pilot.pid)].life > g.players[pilot.pid].life:
				return {}
	return null


# ------------------------------------------------------------- graveyards --

## YAWGMOTH'S WILL (no role; its line "cast spells from your graveyard"):
## our graveyard is public and ours to replay. Worth the replays the mana
## left after the Will pays for — greedily, the best worth per mana first —
## plus a land from the graveyard when the land drop is unused. Never with
## an empty or useless graveyard.
static func graveyard_replay(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var paid: Array = pilot._plan_taps_from(sources, inst.data.cost, g.spell_surcharge(pid, inst.data))
	if paid.is_empty():
		return {}
	var left: int = URZA_TACTICS.rows_mana(_rows_without(sources, paid), true)
	var value := 0.0
	var land := false
	var spells: Array = []
	for card in g.players[pid].graveyard:
		if card == inst:
			continue
		if card.data.is_land():
			land = true
			continue
		var cost := card.data.cost.mana_value()
		if card.data.cost.has_x or cost > left:
			continue
		var worth := Evaluator.card_value(card.data)
		if worth < 2.5:
			continue
		spells.append([worth / float(maxi(cost, 1)), cost, worth])
	spells.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	for row in spells:
		if int(row[1]) <= left:
			left -= int(row[1])
			value += float(row[2])
	if land and g.land_drop_available(pid):
		var in_hand := false
		for card in g.players[pid].hand:
			if card.data.is_land():
				in_hand = true
		if not in_hand:
			value += 1.5
	return {} if value < Evaluator.card_value(inst.data) + 1.0 else {"x": 0, "targets": [], "value": value}


## REPLENISH (no role; its line): every enchantment card of our graveyard
## returns — an Aura only with something to enchant.
static func replenish(g: MtgGame, pilot, inst: CardInstance) -> Dictionary:
	var value := 0.0
	for card in g.players[pilot.pid].graveyard:
		if card == inst or not card.data.is_type(Mtg.CardType.ENCHANTMENT):
			continue
		if card.data.is_aura() and g.aura_entry_hosts(card, pilot.pid).is_empty():
			continue
		value += Evaluator.card_value(card.data)
	return {} if value < Evaluator.card_value(inst.data) + 1.0 else {"x": 0, "targets": [], "value": value}


# ======================================================== the price of a cast --

## What a cast of [param inst] costs or earns beyond its own reading
## ([method AiPlayer._try_cast_best], added to the ranked value): the mana
## an untap hands back (a cast it then pays for), the dormant enchantments
## of theirs it wakes, the echo it commits next upkeep to. 0.0 with the
## gate off.
static func cast_adjustment(g: MtgGame, pilot, inst: CardInstance, sources: Array) -> float:
	if not pilot.profile.forecasts_tactics:
		return 0.0
	var delta := 0.0
	var refund := untapped_on_cast(inst.data)
	if refund > 0:
		delta += refund_value(g, pilot, inst, refund, sources)
	delta -= awakened_worth(g, pilot, inst)
	delta -= echo_commitment(g, pilot, inst)
	return delta


## "Untap up to N lands" on the card — a spell effect ([member
## EffectIntent.untaps_lands], or a card-local line that says so: Time
## Spiral's "you untap up to six lands") or its own arrival's line (Great
## Whale, Treachery) — or 0.
static func untapped_on_cast(data: CardData) -> int:
	var n := 0
	for e in data.spell_effects:   # EffectIntent.untaps_lands' own reading, without the whole read
		if e.ai_role == &"untap_lands":
			n += int(e.ai_parameters.get("count", 0))
		elif e.ai_role == &"":
			n += _untap_count(_line_of([e]))   # a card-local line only
	for t in data.triggered_abilities:
		if t.event_type == Mtg.EventType.ENTERS_BATTLEFIELD:
			n += _untap_count(t.text.to_lower())
	return n


## The N of "untap up to N lands" in a lower-cased [param line], or 0.
static func _untap_count(line: String) -> int:
	var at := line.find("untap up to ")
	if at < 0 or not line.contains(" lands"):
		return 0
	var word := line.substr(at + 12).get_slice(" ", 0)
	return int(EffectIntent.WHEEL_COUNTS.get(word, 0)) if not word.is_valid_int() else int(word)


## [param sources] without the rows a [param plan] taps — EVERY row of a
## source it taps: a dual land is listed once per ability and an
## any-color source once per color ([method ManaPlanner.source_key]), and
## the tap spends the source whichever row the plan named. Dropping only
## the row named left the Underground Sea the Will was paid with as mana
## for the replays (the 0.60.19 bug pass, h5-2). A floating step drops its
## own unit.
static func _rows_without(sources: Array, plan: Array) -> Array:
	return sources.filter(func(s: Array) -> bool:
		for step in plan:
			if step[0] == null:
				if s[0] == null and int(step[1]) == int(s[1]):
					return false
			elif step[0] == s[0]:
				return false
		return true)


## THE MANA HANDED BACK: the lands the cast taps, up to [param refund],
## untap again as it resolves (the card's own hint untaps ours, the most
## mana first). Worth the best card of our hand that the mana left after
## the cast could not pay for and the refund can — a permanent or an
## untargeted spell worth a card ([method AiPlayer._ritual_has_a_use]'s
## bar) — so the untap card is cast FIRST, and the other after it. 0.0
## when nothing waits for that mana.
static func refund_value(g: MtgGame, pilot, inst: CardInstance, refund: int, sources: Array) -> float:
	var pid: int = pilot.pid
	var surcharge := g.spell_surcharge(pid, inst.data)
	var keys: Array = g.mana_usage_keys(inst.data, inst)
	var paid: Array = pilot._plan_taps_from(sources, inst.data.cost, surcharge, keys)
	if paid.is_empty():
		return 0.0
	var rest := _rows_without(sources, paid)
	var back := rest.duplicate()
	# Each land handed back once, with every row it is listed by (a dual's
	# two abilities are one land untapped, not two).
	var handed := {}
	for row in sources:
		var land: CardInstance = row[0]
		if land == null or not land.is_land() or rest.has(row):
			continue
		if not handed.has(land.id):
			if handed.size() >= refund:
				continue
			handed[land.id] = true
		back.append(row)
	if handed.is_empty():
		return 0.0
	var best := 0.0
	for other in g.players[pid].hand:
		if other == inst or other.is_land() or other.data.cost.has_x or pilot._is_reactive(other.data):
			continue
		if pilot._refused.has(str(other.id)) or pilot._cast_gate(g, other) != "":
			continue
		var aimed := false
		for e in other.data.spell_effects:
			if e.target_spec != null:
				aimed = true
		if aimed or other.data.is_aura():
			continue
		var worth := Evaluator.card_value(other.data)
		if worth < 3.0 or worth <= best:
			continue
		var extra := g.spell_surcharge(pid, other.data)
		var other_keys: Array = g.mana_usage_keys(other.data, other)
		if not pilot._plan_taps_from(rest, other.data.cost, extra, other_keys).is_empty():
			continue   # paid for already: the refund is not what it waits for
		if pilot._plan_taps_from(back, other.data.cost, extra, other_keys).is_empty():
			continue
		best = worth
	return best * 0.75


## THEIR DORMANT ENCHANTMENTS (Opal, Veiled and Hidden): "when an opponent
## casts a <kind> spell, if this permanent is an enchantment, it becomes a
## P/T creature" — public triggers on their board. The bodies our cast of
## [param inst] would wake ([member TriggeredAbility.condition] asked of
## the cast as it would be announced), at their worth to them; a Veiled
## Sentry's body is our spell's mana value. A spell that wakes nothing is
## played first, so a creature waits behind the noncreature cards of our
## hand; once every card of our hand would wake it (or it wakes on any
## spell at all — Veil of Birds) the waking is the price of playing at all
## and only a share of it is charged.
##
## THE SENTRY'S SIZE IS OUR CHOICE (the 0.60.19 bug pass, h5-4): a body
## the size of our spell's mana value was charged that share whatever the
## spell — a Yawgmoth's Bargain into a Veiled Sentry handed them a 6/6 at
## 0.4 of its worth. Only the body the CHEAPEST waking card of our hand
## would make is the price of playing at all; what this cast adds over it
## is charged in full (with no other waking card in hand, all of it). And
## no cast whose woken bodies turn their visible power into our life total
## (urza_tactics.gd `their_power` — the duel audit's seed 456012 died to
## exactly that): priced at half the game, so only a cast that wins
## outright still goes ahead.
static func awakened_worth(g: MtgGame, pilot, inst: CardInstance) -> float:
	var pid: int = pilot.pid
	var total := 0.0
	var woken_power := 0
	var mana_value := inst.data.cost.mana_value()
	for body in g.players[g.opponent_of(pid)].battlefield:
		if not g.is_present(body) or body.is_creature() \
				or not body.is_type(Mtg.CardType.ENCHANTMENT):
			continue
		for t in body.data.triggered_abilities:
			if t.event_type != Mtg.EventType.SPELL_CAST or not t.condition.is_valid():
				continue
			var line := t.text.to_lower()
			if not line.contains("if this permanent is an enchantment, it becomes"):
				continue
			if not _wakes(g, pid, body, t, inst):
				continue
			var worth := _awakened_body(line, mana_value)
			woken_power += _awakened_size(line, mana_value).x
			var least := INF   # the body the cheapest other waking card makes
			var unavoidable := true
			for card in g.players[pid].hand:
				if card == inst or card.data.is_land():
					continue
				if not _wakes(g, pid, body, t, card):
					unavoidable = false
					break
				least = minf(least, _awakened_body(line, card.data.cost.mana_value()))
			if unavoidable:
				if least == INF:   # no other waking card: a printed size is the same body anyway
					least = worth if _printed_size(line) else 0.0
				var floor_worth := minf(worth, least)
				worth = floor_worth * 0.4 + (worth - floor_worth)
			total += worth
	var their_power: int = URZA_TACTICS.their_power(g, pilot)
	var life := g.players[pid].life
	if woken_power > 0 and their_power < life and their_power + woken_power >= life:
		return LETHAL_WORTH * 0.5
	return total


## Would our cast of [param card] fire [param body]'s dormant trigger
## [param t]? Its own intervening condition, asked of the cast.
static func _wakes(g: MtgGame, pid: int, body: CardInstance, t: TriggeredAbility,
		card: CardInstance) -> bool:
	var cast := GameEvent.new(Mtg.EventType.SPELL_CAST,
		{"instance": card, "controller": pid, "player": pid})
	return bool(t.condition.call(g, body, cast))


## The worth of the creature a dormant enchantment's [param line] becomes:
## its printed P/T (or our spell's [param mana_value] for "equal to that
## spell's mana value") and flying, on [method Evaluator.permanent_value]'s
## scale, three quarters of it (a body that can still be answered).
static func _awakened_body(line: String, mana_value: int) -> float:
	var size := _awakened_size(line, mana_value)
	var worth := float(size.x + size.y)
	if line.contains("flying"):
		worth += 1.5
	return worth * 0.75


## The P/T a dormant enchantment's [param line] prints ("it becomes a 4/4
## …"), or ([param mana_value], [param mana_value]) for a body the size of
## the spell that wakes it (Veiled Sentry).
static func _awakened_size(line: String, mana_value: int) -> Vector2i:
	var word := _size_word(line)
	if word.contains("/"):
		return Vector2i(word.get_slice("/", 0).to_int(), word.get_slice("/", 1).to_int())
	return Vector2i(mana_value, mana_value)


## Does [param line] print the body's P/T (not "equal to that spell's mana
## value")?
static func _printed_size(line: String) -> bool:
	return _size_word(line).contains("/")


## The word after "it becomes a" in [param line], or "".
static func _size_word(line: String) -> String:
	var at := line.find("it becomes a")
	return "" if at < 0 else line.substr(at + 12).strip_edges().get_slice(" ", 0)


## THE ECHO A CAST COMMITS TO: an echo permanent cast now owes its echo at
## our next upkeep — the mana of next turn, or the permanent. A quarter of
## that mana for a body we would keep; nothing for one whose worth is its
## arrival (it is let go: [method echo_choice]).
static func echo_commitment(_g: MtgGame, _pilot, inst: CardInstance) -> float:
	var data := inst.data
	var cost := EchoAbility.echo_cost(inst)
	if cost == "":
		return 0.0
	for t in data.triggered_abilities:
		if t.event_type == Mtg.EventType.ENTERS_BATTLEFIELD:
			return 0.0
	return float(ManaCost.parse(cost).mana_value()) * 0.25


# ================================================================= the upkeep --

## ECHO, PAID OR LET GO ([method DecisionAgent.echo_hint], asked only when
## the echo is affordable): `null` with the gate off. The permanent's worth
## to our side — our board with it against our board without it, so an
## anthem over our Squirrels counts — less what its leaving brings (a
## "when this dies" payoff), against the echo's mana priced like an upkeep
## rent, plus the cast this turn the payment would cost us (the best card
## of our hand the mana pays for now and not after the echo) and the mana
## it would burn. A creature whose worth was its arrival is let go.
static func echo_choice(g: MtgGame, pilot, source: CardInstance, cost: ManaCost) -> Variant:
	if not pilot.profile.forecasts_tactics or source == null:
		return null
	var pid: int = pilot.pid
	var me := g.players[pid]
	var keep: float = pilot._own_value(g, source)
	if source.is_creature():
		var with_it := TEMPEST.side_worth(g, pilot, pid, null)
		var without := g.value_without_permanent(source, func() -> float:
			return TEMPEST.side_worth(g, pilot, pid, null))
		keep = maxf(keep, with_it - without)
	for t in source.data.triggered_abilities:
		if t.event_type == Mtg.EventType.DIES:
			keep -= _dies_payoff(t.text.to_lower())
	var burn: int = pilot._upkeep_burn(g, cost)
	if burn > 0 and burn >= me.life:
		return false
	var price: float = float(cost.mana_value()) * 0.75 + float(burn) * pilot._life_price(me.life)
	price += _cast_lost(g, pilot, cost) * 0.5
	return keep >= price


## What a "when this creature dies" line hands its controller: tokens
## (their count), a counter, a card — roughly.
static func _dies_payoff(line: String) -> float:
	if line.contains("create"):
		var at := line.find("create ")
		var word := line.substr(at + 7).get_slice(" ", 0)
		var n := int(EffectIntent.WHEEL_COUNTS.get(word, 1)) if not word.is_valid_int() else int(word)
		return float(n) * TOKEN_WORTH * 1.5
	if line.contains("counter") or line.contains("draw"):
		return 1.0
	return 0.0


## The best card of our hand the mana we have now pays for and the mana
## left after paying [param cost] does not: its worth, 0.0 for none.
static func _cast_lost(g: MtgGame, pilot, cost: ManaCost) -> float:
	var pid: int = pilot.pid
	var sources: Array = pilot._mana_sources(g)
	var paid: Array = pilot._plan_taps_from(sources, cost, 0, EchoAbility.USAGE)
	if paid.is_empty():
		return 0.0
	var rest := _rows_without(sources, paid)
	var best := 0.0
	for card in g.players[pid].hand:
		if card.is_land() or card.data.cost.has_x or pilot._is_reactive(card.data):
			continue
		var worth := Evaluator.card_value(card.data)
		if worth <= best:
			continue
		var extra := g.spell_surcharge(pid, card.data)
		var keys: Array = g.mana_usage_keys(card.data, card)
		if pilot._plan_taps_from(sources, card.data.cost, extra, keys).is_empty():
			continue
		if not pilot._plan_taps_from(rest, card.data.cost, extra, keys).is_empty():
			continue
		best = worth
	return best


## "<Source>: discard a card? (otherwise sacrifice <Source>)" and its kin
## (Masticore, Body Snatcher, Endless Wurm, Contamination): the payment's
## cheapest object of ours against the source's own worth. 1 pay, 0 let it
## go, -1 not this question (the hint stands).
static func unless_objects_answer(g: MtgGame, pilot, prompt: String) -> int:
	if not pilot.profile.forecasts_tactics:
		return -1
	var colon := prompt.find(": ")
	var other := prompt.find("? (otherwise ")
	if colon < 0 or other < colon or not prompt.ends_with(")"):
		return -1
	var name := prompt.substr(0, colon)
	var pay := prompt.substr(colon + 2, other - colon - 2).to_lower()
	var pid: int = pilot.pid
	var source: CardInstance = null
	for body in g.players[pid].battlefield:
		if body.data.card_name == name and not body.face_down:
			source = body
	if source == null:
		return -1
	var price := INF
	if pay == "discard a card" or pay.begins_with("discard a ") and pay.ends_with(" card"):
		var kind := pay.trim_prefix("discard a ").trim_suffix(" card").trim_suffix("card").strip_edges()
		for card in g.players[pid].hand:
			if kind != "" and not _card_is_kind(card.data, kind):
				continue
			price = minf(price, hand_worth(g, pilot, card))
	elif pay.begins_with("sacrifice a ") or pay.begins_with("sacrifice an "):
		var kind := pay.trim_prefix("sacrifice an ").trim_prefix("sacrifice a ").strip_edges()
		for body in g.players[pid].battlefield:
			if body == source or not g.is_present(body) or not _permanent_is_kind(body, kind):
				continue
			price = minf(price, float(pilot._own_value(g, body)))
	else:
		return -1
	if price == INF:
		return -1
	return 1 if float(pilot._own_value(g, source)) > price else 0


static func _card_is_kind(data: CardData, kind: String) -> bool:
	match kind:
		"creature": return data.is_creature()
		"land": return data.is_land()
		"artifact": return data.is_type(Mtg.CardType.ARTIFACT)
		"enchantment": return data.is_type(Mtg.CardType.ENCHANTMENT)
	return true


static func _permanent_is_kind(body: CardInstance, kind: String) -> bool:
	match kind:
		"creature": return body.is_creature()
		"land": return body.is_land()
		"artifact": return body.is_type(Mtg.CardType.ARTIFACT)
		"enchantment": return body.is_type(Mtg.CardType.ENCHANTMENT)
	return false


# ================================================================== cycling --

## OUR HAND'S CYCLING ([method AiPlayer._activation_sources]): the hand
## cards worth a fresh card now, least worth first so the activation
## scorer's tie goes to the card we miss least. At THEIR end step with the
## stack empty (the mana sink): a card dead on the public board — a land
## beyond a working mana base, a spell or Aura whose every permanent or
## graveyard target is missing, a Rune of Protection whose colour the
## opponent has never shown — and, while our cycling costs nothing
## (Fluctuator), also a card no turn soon pays for. Never while a cycle
## would cost us our own enchantment ("when a card is put into your
## graveyard ..., sacrifice this") or our life through their discard
## punisher at the last points.
static func cycling_sources(g: MtgGame, pilot) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	var pid: int = pilot.pid
	if not pilot.profile.forecasts_tactics or g.active_player == pid or not g.stack.is_empty() \
			or g.current_step() != Mtg.Step.END:
		return out
	if _discard_forbidden(g, pilot):
		return out
	var lands := 0
	for inst in g.players[pid].battlefield:
		if inst.is_land():
			lands += 1
	var rows: Array = []
	for inst in g.players[pid].hand:
		var cycler: ActivatedAbility = null
		for ability in inst.cur_activated_abilities:
			if ability.activation_zone == Mtg.Zone.HAND:
				cycler = ability
				break
		if cycler == null:
			continue
		var dead := false
		if inst.is_land():
			dead = lands >= 5 and not pilot._land_light(g)
		else:
			dead = _aimless(g, inst) or _rune_unneeded(g, pilot, inst)
		if not dead and _cycles_free(g, pid, inst, cycler):
			dead = dead_in_hand(g, pilot, inst) or (inst.is_land() and lands >= 4 and not pilot._land_light(g))
		if dead:
			rows.append([hand_worth(g, pilot, inst), inst])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) < float(b[0]))
	for row in rows:
		out.append(row[1])
	return out


## Every permanent or graveyard target spec of [param inst] (an Aura's
## enchant spec) has no legal target — Scrap with no artifact, Clear with
## no enchantment (Pack 10 E2's reading).
static func _aimless(g: MtgGame, inst: CardInstance) -> bool:
	var specs: Array = []
	if inst.data.is_aura():
		specs.append(inst.data.aura_target)
	else:
		for effect in inst.data.spell_effects:
			specs.append(effect.target_spec)
	var aimed := 0
	var aimless := 0
	for spec in specs:
		if spec == null or (spec as TargetSpec).kind not in [TargetSpec.Kind.CREATURE,
				TargetSpec.Kind.PERMANENT, TargetSpec.Kind.CREATURE_IN_YOUR_GRAVEYARD,
				TargetSpec.Kind.CARD_IN_YOUR_GRAVEYARD, TargetSpec.Kind.CREATURE_IN_ANY_GRAVEYARD,
				TargetSpec.Kind.CARD_IN_ANY_GRAVEYARD]:
			continue
		aimed += 1
		if (spec as TargetSpec).legal_targets(g, inst).is_empty():
			aimless += 1
	return aimed > 0 and aimless == aimed


## A RUNE OF PROTECTION's colour: a permanent whose every battlefield
## ability is a damage shield against one colour, and the opponent has
## shown nothing of that colour — no permanent, no card in their graveyard
## or face-up exile.
static func _rune_unneeded(g: MtgGame, pilot, inst: CardInstance) -> bool:
	var color := 0
	for ability in inst.data.activated_abilities:
		if ability.activation_zone == Mtg.Zone.HAND:
			continue
		if ability.effects.size() != 1 or not (ability.effects[0] is PreventDamageShieldEffect):
			return false
		var shield: PreventDamageShieldEffect = ability.effects[0]
		if shield.color_mask == 0:
			return false
		color |= shield.color_mask
	if color == 0:
		return false
	var foe := g.players[g.opponent_of(pilot.pid)]
	for body in foe.battlefield:
		if body.face_down:
			continue
		if (body.cur_colors & color) != 0:
			return false
		for ability in body.cur_mana_abilities:   # a land is colourless; its mana is not
			for pair in ability.produces:
				if (int(pair[0]) & color) != 0:
					return false
	for card in foe.graveyard + foe.exile:
		if not card.face_down and (card.data.color_mask() & color) != 0:
			return false
	return true


## Does [param ability] (a hand ability of [param inst]) cost us nothing
## now — every generic of it taken off by our cost reducers (Fluctuator)?
static func _cycles_free(g: MtgGame, pid: int, inst: CardInstance, ability: ActivatedAbility) -> bool:
	var cost := ability.cost
	if cost == null:
		return true
	return cost.mana_value() - g.ability_floored_reduction(pid, inst, ability, cost, 0) <= 0


## A discard is not ours to make: our own enchantment that is sacrificed
## when a card reaches our graveyard (Energy Field), or their discard
## punisher ("whenever an opponent discards a card, ... damage") at the
## last points of our life.
static func _discard_forbidden(g: MtgGame, pilot) -> bool:
	var pid: int = pilot.pid
	for body in g.players[pid].battlefield:
		for t in body.data.triggered_abilities:
			var line := t.text.to_lower()
			if line.contains("put into your graveyard") and line.contains("sacrifice"):
				return true
	for body in g.players[g.opponent_of(pid)].battlefield:
		for t in body.data.triggered_abilities:
			var line := t.text.to_lower()
			if line.contains("opponent discards") and line.contains("damage"):
				var at := line.find("deals ")
				var n := line.substr(at + 6).to_int() if at >= 0 else 2
				if g.players[pid].life <= maxi(n, 1) * 3:
					return true
	return false


# ============================================================ the responses --

## Pack 10's instant-speed moments ([method AiPlayer._respond_action]): ""
## when none fires. In a combat whose blocks are declared — Humble on the
## creature of theirs that kills ours, Redeem on our dying creatures.
static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics:
		return ""
	var pid: int = pilot.pid
	var combat := not g.combat.attackers.is_empty() and g.stack.is_empty() \
		and g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers
	if not combat:
		return ""
	for inst in g.players[pid].hand:
		if pilot._refused.has(str(inst.id)) or pilot._cast_gate(g, inst) != "":
			continue
		if not g.casts_at_instant_speed(pid, inst):
			continue
		for e in inst.data.spell_effects:
			var done := ""
			match e.ai_role:
				&"silence_and_shrink_until_eot":
					done = humble(g, pilot, inst, e)
				&"prevent_all_damage_to_creatures":
					done = redeem(g, pilot, inst, e)
			if done != "":
				return done
	return ""


## Our creatures the declared combat kills, dearest first.
static func _our_dying(g: MtgGame, pilot) -> Array[CardInstance]:
	var rows: Array = []
	for body in g.players[pilot.pid].creatures():
		if pilot._dies_in_combat(g, body):
			rows.append([float(pilot._own_value(g, body)), body])
	rows.sort_custom(func(a: Array, b: Array) -> bool: return float(a[0]) > float(b[0]))
	var out: Array[CardInstance] = []
	for row in rows:
		out.append(row[1])
	return out


## HUMBLE (`silence_and_shrink_until_eot`): their creature in a declared
## combat becomes a 0/1 with no abilities — on the one creature that kills
## a creature of ours alone, which then survives and kills it back.
static func humble(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var best := {}
	for ours in _our_dying(g, pilot):
		var foes: Array = g.combat.blockers_of(ours.id) if g.combat.attackers.has(ours.id) \
			else g.combat.attackers_blocked_by(ours.id)
		if foes.size() != 1:
			continue
		var theirs := g.find_instance(int(foes[0]))
		if theirs == null or theirs.controller_id == pilot.pid:
			continue
		var ref := TargetRef.card(theirs)
		if not g.target_legal_at(e.target_spec, ref, inst, 0):
			continue
		var value: float = float(pilot._own_value(g, ours)) \
			+ (float(pilot._victim_value(g, theirs)) if ours.cur_power >= 1 else 0.0)
		if best.is_empty() or value > float(best["value"]):
			best = {"value": value, "targets": [ref]}
	if best.is_empty() or float(best["value"]) < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, best["targets"], 0, "cast %s" % inst.data.card_name)


## REDEEM (`prevent_all_damage_to_creatures`, up to two targets): all
## damage to our two dearest creatures the declared combat kills.
static func redeem(g: MtgGame, pilot, inst: CardInstance, e: EffectBase) -> String:
	var targets: Array = []
	var saved := 0.0
	for ours in _our_dying(g, pilot):
		if targets.size() >= maxi(e.target_max, 1):
			break
		var ref := TargetRef.card(ours)
		if not g.target_legal_at(e.target_spec, ref, inst, 0, targets):
			continue
		targets.append(ref)
		saved += float(pilot._own_value(g, ours))
	if targets.is_empty() or saved < Evaluator.card_value(inst.data):
		return ""
	return pilot._cast_response(g, inst, targets, 0, "cast %s" % inst.data.card_name)


# ================================================================ abilities --

## The activated-ability reader's question ([method AiPlayer._ability_option]'s
## expansion chain): `null` when no Pack 10 reading applies to ability
## [param index] of [param s]. The Seers' reveal abilities (the Scents'
## readings, from a permanent), Memory Jar's symmetric seven and Temporal
## Aperture's free card.
static func option(g: MtgGame, pilot, s: CardInstance, index: int, window: String) -> Variant:
	if not pilot.profile.forecasts_tactics:
		return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.activation_zone == Mtg.Zone.HAND:
		return null
	for e in a.effects:
		if e.ai_role == &"reveal_from_hand":
			var per := StringName(e.ai_parameters.get("per_card", &""))
			if per == &"pump" or per == &"counter_tax":
				return {}
			var choice: Variant = reveal_choice(g, pilot, s, e)
			if choice == null or (choice as Dictionary).is_empty():
				return {}
			return {"value": float(choice["value"]), "targets": choice["targets"]}
	var line := _line_of(a.effects)
	if line.contains("exiles their hand face down") and line.contains("draws seven"):
		return memory_jar(g, pilot, window)
	if line.contains("shuffle your library and reveal the top card") \
			and line.contains("without paying its mana cost"):
		return aperture(g, pilot, window)
	return null


## MEMORY JAR ("each player exiles their hand face down and draws seven;
## at the next end step they discard those and get the exiled cards
## back"): seven cards for THIS turn, both sides. In our main phase, with
## a hand that has nothing left to cast and mana up to cast what comes:
## worth the mana it puts to work, less the instant-speed answers their
## seven fresh cards may hold (their open mana, public).
static func memory_jar(g: MtgGame, pilot, window: String) -> Dictionary:
	var pid: int = pilot.pid
	if window != "MAIN" or g.active_player != pid or not Mtg.is_main_step(g.current_step()):
		return {}
	var me := g.players[pid]
	if me.library.size() < 10 or me.hand.size() > 2:
		return {}
	var open: int = URZA_TACTICS.rows_mana(pilot._mana_sources(g), true)   # each source once (h5-2)
	if open < 3:
		return {}
	var theirs: int = URZA_TACTICS.open_mana(g, g.opponent_of(pid))
	var value := float(mini(open, 7)) * 0.75 - float(theirs) * 0.5
	return {} if value < 2.0 else {"value": value, "targets": []}


## TEMPORAL APERTURE ({5}, {T}: the top card, free while it stays on top):
## only in our own main phase with the cast done and five to spare — the
## card it shows is the planner's (the library row is public once shown).
## Worth an unseen card ([constant UNSEEN_CARD]) against the mana sink's
## bar, for the sink's reason: the main phase's casts are done, so the five
## would otherwise go unspent. (Its first value, 2.5 against the main
## phase's bar of 3.0 after the activation's own price of 2.0, never
## cleared it: the Pack 10 duel audit cast 80 Apertures and activated none.)
static func aperture(g: MtgGame, pilot, window: String) -> Dictionary:
	var pid: int = pilot.pid
	if window != "MAIN" or g.active_player != pid or not Mtg.is_main_step(g.current_step()):
		return {}
	if g.players[pid].library.size() < 5:
		return {}
	return {"value": UNSEEN_CARD, "targets": [], "bar": AiPlayer.ABILITY_BAR_SINK}
