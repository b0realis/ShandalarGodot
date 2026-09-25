extends RefCounted
## Estimates from public zones, public counts and our own hand only.
## Never inspect an opponent's hand contents, unknown draws, or RNG state.
const H := preload("res://engine/ai/homelands_tactics.gd")
const A := preload("res://engine/ai/alliances_tactics.gd")

static func spell_choice(g: MtgGame, pilot, s: CardInstance, max_x := 0) -> Variant:
	var second: Variant = preload("res://engine/ai/second_age_tactics.gd").spell_choice(g, pilot, s)
	if second != null: return second
	if not pilot.profile.forecasts_tactics or s.data.spell_effects.is_empty(): return null
	var e: EffectBase = s.data.spell_effects[0]
	var pid: int = pilot.pid
	var me := g.players[pid]
	var foe := g.players[1 - pid]
	var best := {}
	match e.ai_role:
		&"divided_creature_damage": return A._divided(g, pilot, s, e)
		&"pump_then_damage_two":
			for ref in e.target_spec.legal_targets(g, s):
				var body := g.find_instance(ref.instance_id)
				var damage := H.DAMAGE.damage_through(g, s, ref, 2)
				if body.controller_id == pid:
					if body.cur_toughness > body.damage + damage: best = H.better(best, A.result(H.pump_gain(g, pilot, body, 2, -damage), [ref]))
				elif not body.cur_indestructible and body.cur_toughness <= body.damage + damage:
					best = H.better(best, A.result(pilot._victim_value(g, body) + 1.0, [ref]))
		&"mountain_damage":
			var amount := 0
			for land in me.battlefield:
				if land.has_subtype("mountain"): amount += 1
			for ref in e.target_spec.legal_targets(g, s):
				var body := g.find_instance(ref.instance_id)
				if body.controller_id != pid and not body.cur_indestructible and H.DAMAGE.damage_through(g, s, ref, amount) + body.damage >= body.cur_toughness:
					best = H.better(best, A.result(pilot._victim_value(g, body) + 1.0, [ref]))
		&"sacrifice_power_damage":
			# The cost chooser is free to select any eligible creature. Only
			# promise lethal if even its smallest-power choice is sufficient.
			var power := 100000
			for body in me.creatures(): power = mini(power, body.cur_power)
			if not me.creatures().is_empty() and H.DAMAGE.damage_through(g, s, TargetRef.player(1 - pid), power) >= foe.life:
				return A.result(AiPlayer.LETHAL_WORTH, [TargetRef.player(1 - pid)])
		&"extra_turn_then_lose":
			if me.library.size() < 2 or not g.next_turn_statics.is_empty(): return {}
			var damage := 0
			for body in me.creatures():
				if body.has_keyword(Mtg.Keyword.DEFENDER) or body.cur_cant_attack or body.cant_attack_next_turn: continue
				if not body.cur_attack_costs.is_empty() or body.cur_attack_land_sacrifices > 0: continue
				if body.tapped and (body.cur_skips_untap or body.skip_untaps > 0 or body.skip_untap_for.has(pid)): continue
				var needs: String = body.data.attack_needs_defender_land
				if needs != "" and not CombatState._controls_land_of_type(g, 1 - pid, needs): continue
				var blockable := false
				for blocker in foe.creatures():
					if CombatState.block_illegality(g, blocker, body, 1 - pid) == "": blockable = true
				# Until-end-of-turn pumps do not survive into the extra turn.
				if not blockable: damage += H.DAMAGE.damage_through(g, body, TargetRef.player(1 - pid), maxi(0, mini(body.data.power, body.cur_power)))
			# Do not buy an ordinary value turn with a guaranteed loss rider.
			if damage >= foe.life: return A.result(AiPlayer.LETHAL_WORTH * 0.5)
		&"both_players_draw_x":
			var x := mini(max_x, me.library.size() - 1)
			if x > foe.library.size(): return A.result(AiPlayer.LETHAL_WORTH, [], foe.library.size() + 1)
			x = mini(x, maxi(0, 7 - me.hand.size()))
			if x >= 2 and me.hand.size() < foe.hand.size(): return A.result(x * pilot._draw_need(me.hand.size()), [], x)
		&"draw_hand_difference", &"draw_tapped_enemies":
			var count := maxi(0, foe.hand.size() - (me.hand.size() - 1))
			if e.ai_role == &"draw_tapped_enemies":
				count = 0
				for body in foe.creatures():
					if body.tapped: count += 1
			if count > 0 and count < me.library.size(): return A.result(count * pilot._draw_need(me.hand.size()), [TargetRef.player(1 - pid)])
		&"reveal_opponent_draw":
			# Matching colors in a hidden hand are unknown, not zero or certain.
			if foe.hand.size() >= 3 and me.library.size() > foe.hand.size(): return A.result(3.0, [TargetRef.player(1 - pid)])
		&"draw_four_half_life":
			if me.library.size() > 4 and me.life >= 10 and me.hand.size() <= 4: return A.result(7.0)
		&"select_two_of_seven":
			if me.library.size() > 9: return A.result(6.0)
		&"order_three_cantrip":
			if me.library.size() > 2: return A.result(3.0 + pilot._draw_need(me.hand.size()))
		&"catch_up_plains":
			var ours := 0
			var theirs := 0
			for land in me.battlefield:
				if land.is_land(): ours += 1
			for land in foe.battlefield:
				if land.is_land(): theirs += 1
			if theirs > ours and me.library.size() > 4: return A.result(6.0)
		&"extra_land_plays":
			var lands := 0
			for card in me.hand:
				if card.is_land(): lands += 1
			if lands >= 2: return A.result(mini(3, lands) * 3.0)
		&"opponent_discards_two":
			if not foe.hand.is_empty(): return A.result(mini(2, foe.hand.size()) * 3.0, [TargetRef.player(1 - pid)])
		&"damage_attackers_one":
			var value := 0.0
			for id in g.combat.attackers:
				var body := g.find_instance(id)
				if body != null and not body.cur_indestructible and H.DAMAGE.damage_through(g, s, TargetRef.card(body), 1) + body.damage >= body.cur_toughness: value += pilot._victim_value(g, body)
			if value >= 3.0: return A.result(value)
		&"attacker_fog", &"reflect_attack_damage", &"life_per_attacker":
			var damage := 0
			for id in g.combat.attackers:
				var body := g.find_instance(id)
				if body != null and body.controller_id != pid: damage += maxi(0, body.cur_power)
			if e.ai_role == &"life_per_attacker":
				if damage > 0: return A.result(3.0 * g.combat.attackers.size() * pilot._life_price(me.life))
			elif damage >= me.life or damage >= 5: return A.result(float(damage) * pilot._life_price(me.life))
		&"life_per_forest", &"life_per_enemy_mountain", &"life_per_enemy_black_creature":
			var gain := 0
			for body in g.all_battlefield():
				if e.ai_role == &"life_per_forest" and body.has_subtype("forest"): gain += 1
				elif body.controller_id != pid:
					if e.ai_role == &"life_per_enemy_mountain" and body.has_subtype("mountain"): gain += 2
					elif e.ai_role == &"life_per_enemy_black_creature" and body.is_creature() and (body.cur_colors & Mtg.ManaColor.B) != 0: gain += 3
			if gain > 0: return A.result(gain * pilot._life_price(me.life), [] if e.target_spec == null else [TargetRef.player(1 - pid)])
		_: return null
	return best

static func special_spell(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics: return ""
	for s in g.players[pilot.pid].hand:
		if not s.is_type(Mtg.CardType.INSTANT) or g.cast_timing_refusal(pilot.pid, s) != "": continue
		var choice: Variant = spell_choice(g, pilot, s)
		if choice == null or choice.is_empty() or float(choice.value) < 2.0: continue
		if g.cast_refusal(pilot.pid, s, choice.targets, choice.x) != "": continue
		var pay := g.spell_payment(pilot.pid, s.data, choice.x, maxi(1, choice.targets.size()), s)
		if not ManaPlanner.plan_and_pay(g, pilot.pid, pay.cost, pay.extra, pay.usage): continue
		if g.cast_spell(pilot.pid, s, choice.targets, choice.x) == "": return "cast " + s.data.card_name
	return ""
