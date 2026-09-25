extends RefCounted
## Public-board and own-hand valuations. Hidden cards and future draws are
## never inspected; a legal look/search decision is handled at resolution.
const H := preload("res://engine/ai/homelands_tactics.gd")

static func option(g: MtgGame, pilot, s: CardInstance, index: int) -> Variant:
	if not pilot.profile.forecasts_tactics: return null
	var effects: Array = s.cur_activated_abilities[index].effects
	if effects.is_empty() or effects[0].ai_role != &"green_creature_from_hand": return null
	var best := {}
	for body in g.players[pilot.pid].hand:
		if body.is_creature() and (body.cur_colors & Mtg.ManaColor.G) != 0:
			best = H.better(best, H.result(Evaluator.card_value(body.data) + 3.0))
	return best

static func spell_choice(g: MtgGame, pilot, s: CardInstance) -> Variant:
	if not pilot.profile.forecasts_tactics or s.data.spell_effects.is_empty(): return null
	var e: EffectBase = s.data.spell_effects[0]
	var pid: int = pilot.pid
	var me := g.players[pid]
	var foe := g.players[1 - pid]
	match e.ai_role:
		&"select_one_of_two":
			return H.result(3.5 + pilot._draw_need(me.hand.size())) if not me.library.is_empty() else {}
		&"look_and_mill_one":
			return H.result(2.0, [TargetRef.player(1 - pid)]) if not foe.library.is_empty() else {}
		&"opponent_sacrifice_creature":
			var least := INF
			for body in foe.creatures(): least = minf(least, pilot._victim_value(g, body))
			return H.result(least + 1.0, [TargetRef.player(1 - pid)]) if least < INF else {}
		&"opponent_draw_gain_life":
			if foe.library.is_empty(): return H.result(AiPlayer.LETHAL_WORTH, [TargetRef.player(1 - pid)])
			return H.result(7 * pilot._life_price(me.life) - 3.0, [TargetRef.player(1 - pid)]) if me.life <= 10 else {}
		&"life_per_own_creature":
			return H.result(2 * me.creatures().size() * pilot._life_price(me.life)) if me.life < 16 else {}
		&"goblin_count_damage":
			var count := 0
			for body in me.battlefield:
				if body.has_subtype("goblin"): count += 1
			var damage := H.DAMAGE.damage_through(g, s, TargetRef.player(1 - pid), count)
			return H.result(pilot._face_damage_value(g, damage, 1 - pid), [TargetRef.player(1 - pid)]) if damage > 0 else {}
		&"destroy_tapped_gain_life", &"destroy_enemy_lose_life", &"sacrifice_lands_sweep":
			var value := 0.0
			var count := 0
			for body in g.all_battlefield():
				if not body.is_creature() or body.cur_indestructible or body.regeneration_shields > 0: continue
				if e.ai_role == &"destroy_tapped_gain_life" and not body.tapped: continue
				if e.ai_role == &"destroy_enemy_lose_life" and body.controller_id == pid: continue
				if e.ai_role == &"sacrifice_lands_sweep" and H.DAMAGE.damage_through(g, s, TargetRef.card(body), 4) + body.damage < body.cur_toughness: continue
				count += 1
				value += pilot._victim_value(g, body) * (1.0 if body.controller_id != pid else -1.0)
			if e.ai_role == &"destroy_enemy_lose_life":
				if me.life <= count * 2: return {}
				value -= count * 2 * pilot._life_price(me.life)
				return H.result(value, [TargetRef.player(1 - pid)]) if value > 1 else {}
			if e.ai_role == &"destroy_tapped_gain_life": value += count * 2 * pilot._life_price(me.life)
			else:
				var ours := 0
				var theirs := 0
				for land in me.battlefield:
					if land.is_land(): ours += 1
				for land in foe.battlefield:
					if land.is_land(): theirs += 1
				value += 2.0 * (mini(4, theirs) - mini(4, ours))
			return H.result(value) if value > 3 else {}
		&"shuffle_grave_creatures":
			if me.library.size() > 8: return {}
			var targets: Array = e.target_spec.legal_targets(g, s)
			return H.result(3.0 + targets.size(), targets) if not targets.is_empty() else {}
		&"return_nightstalkers":
			var value := 0.0
			for body in me.graveyard:
				if body.has_subtype("nightstalker") and body.data.is_permanent_type(): value += Evaluator.card_value(body.data) + 2.0
			for land in me.battlefield:
				if land.has_subtype("swamp") and not land.cur_indestructible: value -= 2.5
			return H.result(value) if value > 4 else {}
		&"tap_creatures_for_life":
			if me.life > 10: return {}
			var count := 0
			for body in me.creatures():
				if not body.tapped: count += 1
			return H.result(4 * count * pilot._life_price(me.life) - count * 2.0) if count > 0 else {}
		&"one_enemy_blocker":
			if g.current_step() != Mtg.Step.MAIN1 or foe.creatures().size() < 2: return {}
			var attackers := 0
			for body in me.creatures():
				if CombatState.attack_illegality(g, body, 1 - pid).is_empty(): attackers += 1
			return H.result(3.0 * mini(attackers - 1, foe.creatures().size() - 1), [TargetRef.player(1 - pid)]) if attackers >= 2 else {}
		&"additional_combat":
			var power := 0
			for body in me.creatures():
				if (not body.tapped or body.attacked_this_turn) and not body.summoning_sick and not body.cur_cant_attack and not body.has_keyword(Mtg.Keyword.DEFENDER): power += maxi(0, body.cur_power)
			return H.result(float(power)) if power >= 4 else {}
		&"borrow_land_mana":
			if g.foreign_land_mana.has(pid): return {}
			var available := 0
			for land in foe.battlefield:
				if land.is_land() and not land.tapped and not land.cur_mana_abilities.is_empty(): available += 1
			if available < 2: return {}
			for spell in me.hand:
				if spell != s and not spell.is_land() and spell.data.cost.mana_value() >= 3:
					return H.result(float(available) + 2.0)
			return {}
	return null
