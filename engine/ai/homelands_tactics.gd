extends RefCounted
## Shape-based public-board/own-hand policies for the new custom effects.
## null preserves the shared policy; {} deliberately waits. Prices for mana
## and sacrifice are charged once by AiPlayer. No library contents, hostile
## hand contents, sampled coins, game copies or arbitrary effect simulation.
const DAMAGE := preload("res://engine/ai/ice_age_tactics.gd")

static func sizes_x(pilot, ability: ActivatedAbility) -> bool:
	return pilot.profile.forecasts_tactics and not ability.effects.is_empty() and (ability.effects[0] is CreatureRedirectEffect or ability.effects[0].ai_role == &"recharge")

static func result(value: float, targets: Array = [], x := 0) -> Dictionary:
	return {"value": value, "targets": targets, "x": x}

static func option(g: MtgGame, pilot, s: CardInstance, index: int, window: String) -> Variant:
	if not pilot.profile.forecasts_tactics: return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty(): return null
	var e: EffectBase = a.effects[0]
	var pid: int = pilot.pid
	var me := g.players[pid]
	var role := e.ai_role
	if e is CreatureRedirectEffect: return redirect_choice(g, pilot, s, index)
	if role == &"": return null
	# A Spike's move (Pack 9) pays its +1/+1 counter off its own body: the
	# Tempest module prices that cost (engine/ai/tempest_tactics.gd), this
	# reading would not.
	if a.counter_cost_kind == "+1/+1": return null
	var best := {}
	var refs: Array = e.target_spec.legal_targets(g, s) if e.target_spec != null else []
	match role:
		&"sustained_lock":
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if body.controller_id == pid or body.cur_skips_untap: continue
				best = better(best, result(pilot._victim_value(g, body) + 2.0, [ref]))
		&"recharge":
			if not pilot.profile.plays_engines or window == "RESPONSE": return {}
			var missing := int(e.ai_parameters.maximum) - int(s.counters.get(e.ai_parameters.kind, 0))
			for x in range(missing, 0, -1):
				var pay := g.ability_payment(pid, s, index, x)
				if not ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty(): return result(float(x) + 2.0, [], x)
		&"deploy_tribe":
			if not pilot.profile.plays_engines: return {}
			for body in me.hand:
				if not body.has_subtype(e.ai_parameters.subtype) or (body.cur_types & (Mtg.CardType.CREATURE | Mtg.CardType.ARTIFACT | Mtg.CardType.ENCHANTMENT | Mtg.CardType.LAND)) == 0: continue
				best = better(best, result(Evaluator.card_value(body.data) + 2.0))
		&"remove_creature_ban":
			if me.life <= a.life_cost + 3: return {}
			# Own known creature cards, not the opponent's unseen hand.
			for body in me.hand:
				if body.is_creature() and body.data.cost.mana_value() <= pilot._mana_sources(g).size() + me.mana_pool.total():
					best = better(best, result(Evaluator.card_value(body.data) + 2.0 - a.life_cost * pilot._life_price(me.life)))
		&"stat_counter", &"stat_debuff", &"counter_host":
			if role == &"counter_host":
				var host := g.find_instance(s.attached_to)
				if host != null and host.zone == Mtg.Zone.BATTLEFIELD: refs = [TargetRef.card(host)]
			var dp := -1
			var dt := -1
			if e is CounterMarkerEffect:
				var pieces: PackedStringArray = e.kind.split("/")
				if pieces.size() != 2: return {}
				dp = int(pieces[0]) * e.count
				dt = int(pieces[1]) * e.count
			elif e is PumpEffect:
				dp = e.power
				dt = e.toughness
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				var helpful := dt > 0 or (dt == 0 and dp > 0)
				if (body.controller_id == pid) != helpful: continue
				var value := 0.0
				if not helpful:
					if body.cur_toughness + dt <= body.damage: value = pilot._victim_value(g, body) + 2.0
					elif role != &"stat_debuff": value = minf(pilot._victim_value(g, body), float(-dp - dt)) + (1.0 if window == "SINK" else 0.0)
				elif g.current_step() == Mtg.Step.DECLARE_BLOCKERS and not g.awaiting_blockers:
					value = pump_gain(g, pilot, body, dp, dt)
				elif window == "SINK": value = float(dp + dt) + 1.0
				if value > 0: best = better(best, result(value, [] if role == &"counter_host" else [ref]))
		&"untap_self":
			if not s.tapped or not pilot.profile.plays_engines: return {}
			var food: CardInstance = pilot._sacrifice_fodder(g, s, a)
			if food != null and food != s: return result(pilot._own_value(g, s) + 2.0)
		&"evasion": return evasion(g, pilot, s, e)
		&"tribal_pump":
			if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers: return {}
			var before := g.forecast_damage(true)
			var nested := g.undo_log != null
			var mark := g.make_mark()
			for body in me.battlefield:
				if body != s and body.is_creature() and body.has_subtype(e.ai_parameters.subtype): g.continuous.add_until_eot_pump(body.id, int(e.ai_parameters.power), 0)
			g.recalculate()
			var after := g.forecast_damage(true)
			g.unmake_to(mark)
			if not nested: g.end_search()
			return result(swing(g, pilot, before, after)) if swing(g, pilot, before, after) > 0 else {}
		&"set_sweep":
			var gain := 0.0
			for body in g.all_battlefield():
				if body == s or body.is_token or body.cur_indestructible or not CardRegistry.originally_printed_in(body.data.card_name, e.ai_parameters.set): continue
				gain += pilot._victim_value(g, body) if body.controller_id != pid else -pilot._own_value(g, body)
			return result(gain) if gain > 0 else {}
		&"replenish_counter":
			if not pilot.profile.plays_engines or int(s.counters.get(e.ai_parameters.kind, 0)) > 0 or window != "SINK": return {}
			# An Island is a real card: only surplus land buys more counters.
			if pilot._mana_sources(g).size() >= 7: return result(float(e.ai_parameters.count) * 2.0)
		&"delayed_damage":
			if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers: return {}
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if body.controller_id == pid: continue
				var damage := DAMAGE.damage_through(g, s, ref, int(e.ai_parameters.amount))
				var future := g.forecast_damage(true)
				if future.alive.has(body.id) and damage + int(future.damage.get(body.id, 0)) >= body.cur_toughness:
					best = better(best, result(pilot._victim_value(g, body) + 2.0, [ref]))
		&"protection":
			if g.stack.is_empty(): return {}
			var top: StackItem = g.stack.back()
			if top.controller == pid or top.card == null or (top.card.cur_colors & int(e.ai_parameters.color)) == 0: return {}
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if body.controller_id != pid or (body.cur_protection & int(e.ai_parameters.color)) != 0: continue
				for target in top.targets:
					if not target.is_player and target.instance_id == body.id: best = better(best, result(pilot._own_value(g, body) + 2.0, [ref]))
		&"ownership_offer":
			# Owner can simply ante instead: never price this as guaranteed theft.
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if body.owner_id == pid or not g.players[body.owner_id].library.is_empty(): continue
				best = better(best, result(pilot._victim_value(g, body), [ref]))
		&"permit_shroud":
			if s.cur_shroud_ignored_by.has(pid): return {}
			var nested := g.undo_log != null
			var mark := g.make_mark()
			g._rec(s, &"cur_shroud_ignored_by")
			s.cur_shroud_ignored_by.append(pid)
			for card in me.hand:
				if card.data.is_aura() and not pilot._is_harmful(card, null) and card.data.aura_target.is_legal(g, TargetRef.card(s), card):
					var combined: ManaCost = pilot._combined_cost(a.cost, card.data.cost)
					if not ManaPlanner.plan(g, pid, combined, g.spell_surcharge(pid, card.data)).is_empty(): best = result(4.0, [TargetRef.player(pid)])
			g.unmake_to(mark)
			if not nested: g.end_search()
		&"attack_once":
			if g.active_player != pid or g.current_step() not in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN] or s.cur_can_attack_with_defender: return {}
			var nested := g.undo_log != null
			var mark := g.make_mark()
			g._rec(s, &"cur_can_attack_with_defender")
			s.cur_can_attack_with_defender = true
			var legal := CombatState.attack_illegality(g, s, 1 - pid) == ""
			for blocker in g.players[1 - pid].battlefield:
				if blocker.is_creature() and CombatState.block_illegality(g, blocker, s, 1 - pid, true, pid) == "": legal = false
			var lethal := DAMAGE.damage_through(g, s, TargetRef.player(1 - pid), maxi(0, s.cur_power)) >= g.players[1 - pid].life
			g.unmake_to(mark)
			if not nested: g.end_search()
			if legal and lethal: return result(AiPlayer.LETHAL_WORTH)
		&"regenerate_host": return null # shared stack/combat/classic regeneration reader
		_: return null # later semantic vocabularies can handle their own shapes
	return best

static func better(old: Dictionary, candidate: Dictionary) -> Dictionary:
	return candidate if old.is_empty() or float(candidate.value) > float(old.value) else old

static func swing(g: MtgGame, pilot, before: Dictionary, after: Dictionary) -> float:
	var pid: int = pilot.pid
	if int(before.life[pid]) <= 0 and int(after.life[pid]) > 0: return AiPlayer.LETHAL_WORTH
	if int(after.life[pid]) <= 0: return -AiPlayer.LETHAL_WORTH
	if int(before.life[1 - pid]) > 0 and int(after.life[1 - pid]) <= 0: return AiPlayer.LETHAL_WORTH
	var value: float = float(int(after.life[pid]) - int(before.life[pid])) * pilot._life_price(g.players[pid].life)
	value += float(int(before.life[1 - pid]) - int(after.life[1 - pid])) * pilot._life_price(g.players[1 - pid].life)
	for body in g.all_battlefield():
		if before.alive.has(body.id) == after.alive.has(body.id): continue
		var saved := 1.0 if after.alive.has(body.id) else -1.0
		value += saved * (pilot._own_value(g, body) if body.controller_id == pid else -pilot._victim_value(g, body))
	return value

static func pump_gain(g: MtgGame, pilot, body: CardInstance, dp: int, dt: int) -> float:
	var before := g.forecast_damage(true, g.can_forecast_damage_top())
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g.continuous.add_until_eot_pump(body.id, dp, dt)
	g.recalculate()
	var after := g.forecast_damage(true, g.can_forecast_damage_top())
	g.unmake_to(mark)
	if not nested: g.end_search()
	return swing(g, pilot, before, after)

static func redirect_choice(g: MtgGame, pilot, s: CardInstance, index: int) -> Dictionary:
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	var e: CreatureRedirectEffect = a.effects[0]
	var pid: int = pilot.pid
	if g.awaiting_damage_prevention: return pending_choice(g, pilot, s, e)
	if not g.can_forecast_damage_top() and (g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers): return {}
	var before := g.forecast_damage(true, g.can_forecast_damage_top())
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player: continue # generic creature reader; player diversion is separate
		var body := g.find_instance(ref.instance_id)
		if body == s or body.controller_id != pid or before.alive.has(body.id): continue
		var maximum := maxi(0, s.cur_toughness - s.damage - 1)
		if not e.use_x: maximum = mini(maximum, e.amount)
		for points in range(1, mini(maximum, 32) + 1):
			if not e.use_x and points != e.amount: continue
			var payment := g.ability_payment(pid, s, index, points if e.use_x else 0)
			if ManaPlanner.plan(g, pid, payment.cost, payment.extra, payment.usage).is_empty(): continue
			var nested := g.undo_log != null
			var mark := g.make_mark()
			g.book_creature_redirect(body, s, points)
			var after := g.forecast_damage(true, g.can_forecast_damage_top())
			g.unmake_to(mark)
			if not nested: g.end_search()
			var value := swing(g, pilot, before, after)
			if value > 0:
				best = better(best, result(value + 2.0, [ref], points if e.use_x else 0))
				break # minimum amount that improves this target's outcome
	return best

static func pending_choice(g: MtgGame, pilot, s: CardInstance, e: CreatureRedirectEffect) -> Dictionary:
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		if ref.is_player: continue
		var body := g.find_instance(ref.instance_id)
		if body == s or body.controller_id != pilot.pid or not body.creature_damage_redirects.is_empty(): continue
		var incoming := 0
		var source_damage := 0
		for packet in g.damage_pending:
			if packet.target.is_player: continue
			if packet.target.instance_id == body.id: incoming += pilot._uncovered(g, packet)
			if packet.target.instance_id == s.id: source_damage += pilot._uncovered(g, packet)
		var needed := incoming + body.damage - body.cur_toughness + 1
		if needed <= 0 or (not e.use_x and needed > e.amount): continue
		var amount := needed if e.use_x else e.amount
		if s.damage + source_damage + amount >= s.cur_toughness: continue
		best = better(best, result(pilot._own_value(g, body) + 2.0, [ref], amount if e.use_x else 0))
	return best

static func redirect_pending(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics: return ""
	for s in g.players[pilot.pid].battlefield:
		for index in s.cur_activated_abilities.size():
			if s.cur_activated_abilities[index].effects.is_empty() or not s.cur_activated_abilities[index].effects[0] is CreatureRedirectEffect: continue
			if not pilot._ability_available(g, s, index, true): continue
			var choice := redirect_choice(g, pilot, s, index)
			if choice.is_empty(): continue
			var pay := g.ability_payment(pilot.pid, s, index, choice.x)
			if not pilot._plan_and_pay(g, pay.cost, pay.extra, pay.usage): continue
			if g.activate_ability(pilot.pid, s, index, choice.targets, choice.x) == "": return "activated %s" % s.data.card_name
	return ""

static func evasion(g: MtgGame, pilot, s: CardInstance, e: EffectBase) -> Dictionary:
	var pid: int = pilot.pid
	if g.active_player != pid or g.current_step() not in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS] or g.combat_damage_prevented: return {}
	var refs: Array = e.target_spec.legal_targets(g, s) if e.target_spec != null else [TargetRef.card(s)]
	var best := {}
	for ref in refs:
		var body := g.find_instance(ref.instance_id)
		if body.controller_id != pid or body.cur_power + int(e.ai_parameters.get("power", 0)) <= 0 or body.cur_assigns_no_combat_damage: continue
		if g.current_step() == Mtg.Step.DECLARE_ATTACKERS:
			if not g.combat.attackers.has(body.id): continue
		elif CombatState.attack_illegality(g, body, 1 - pid) != "": continue
		var walk := String(e.ai_parameters.get("landwalk", ""))
		if walk != "":
			if body.cur_landwalk.has(walk): continue
			var land := false
			for other in g.players[1 - pid].battlefield:
				if other.is_land() and other.has_subtype(walk): land = true
			if not land: continue
		var blocked := false
		var still_blocked := false
		for other in g.players[1 - pid].battlefield:
			if not other.is_creature() or CombatState.block_illegality(g, other, body, 1 - pid, true, pid) != "": continue
			blocked = true
			if bool(e.ai_parameters.get("walls_only", false)) and other.has_subtype("wall"): still_blocked = true
		if not blocked or still_blocked: continue
		var damage := maxi(0, body.cur_power + int(e.ai_parameters.get("power", 0)))
		var gain: float = damage * pilot._life_price(g.players[1 - pid].life)
		if damage >= g.players[1 - pid].life: gain = AiPlayer.LETHAL_WORTH
		best = better(best, result(gain + 2.0, [] if e.target_spec == null else [ref]))
	return best

static func affordable_attackers(g: MtgGame, pilot, ids: Array) -> Array:
	var ranked: Array = ids.duplicate()
	ranked.sort_custom(func(a: int, b: int) -> bool:
		var va: float = pilot._own_value(g, g.find_instance(a))
		var vb: float = pilot._own_value(g, g.find_instance(b))
		return a < b if is_equal_approx(va, vb) else va > vb)
	var kept: Array = []
	var total := 0
	for id in ranked:
		var tax := 0
		for cost in g.find_instance(id).cur_attack_costs: tax += int(cost.get("generic_mana", 0))
		if tax == 0 or g.can_afford_cost(pilot.pid, ManaCost.parse("{%d}" % (total + tax))):
			kept.append(id)
			total += tax
	# Budget trimming can invalidate "at least N attackers". Such optional
	# groups stay home; never re-add unaffordable volunteers during repair.
	var changed := true
	while changed:
		changed = false
		for id in kept.duplicate():
			if g.find_instance(id).cur_min_attack_group > kept.size():
				kept.erase(id)
				changed = true
	# Preserve original attack order when no budget restriction bites.
	return ids.filter(func(id: int) -> bool: return kept.has(id))

static func trade_damage_for_life(g: MtgGame, pilot, hint: bool) -> bool:
	if not hint: return false
	var damage := 0
	for id in g.combat.attackers:
		var body := g.find_instance(id)
		if body.controller_id == pilot.pid and not g.combat.was_blocked(g.combat.band_of(id)) and not body.cur_assigns_no_combat_damage:
			damage += DAMAGE.damage_through(g, body, TargetRef.player(1 - pilot.pid), maxi(body.cur_power, 0))
	return damage < g.players[1 - pilot.pid].life

static func spell_choice(g: MtgGame, pilot, s: CardInstance) -> Variant:
	if not pilot.profile.forecasts_tactics or s.data.spell_effects.is_empty(): return null
	var e: EffectBase = s.data.spell_effects[0]
	if e.ai_role == &"": return null
	return spell_shape(g, pilot, s, e)

static func spell_shape(g: MtgGame, pilot, s: CardInstance, e: EffectBase) -> Variant:
	var pid: int = pilot.pid
	var me := g.players[pid]
	var them := g.players[1 - pid]
	var refs: Array = e.target_spec.legal_targets(g, s) if e.target_spec != null else []
	var best := {}
	match e.ai_role:
		&"attacker_destroy_token", &"graveyard_exile_cantrip":
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if (body.controller_id if body.zone == Mtg.Zone.BATTLEFIELD else body.owner_id) == pid: continue
				if e.ai_role == &"attacker_destroy_token" and body.cur_indestructible: continue
				best = better(best, result(pilot._victim_value(g, body) + 2.0, [ref]))
		&"remove_poison":
			if me.poison >= 4 and me.poison < me.life and e.target_spec.is_legal(g, TargetRef.player(pid), s): return result(float(me.poison) + 2.0, [TargetRef.player(pid)])
		&"opponent_cantrip":
			if me.library.size() > 1 and not refs.is_empty(): return result(3.0 + pilot._draw_need(me.hand.size()), [refs[0]])
		&"green_life":
			var life := 1
			for body in g.all_battlefield():
				if body.is_creature() and (body.cur_colors & Mtg.ManaColor.G) != 0: life += 1
			if me.life <= 10: return result(float(life) * pilot._life_price(me.life))
		&"sacrifice_pair":
			refs.sort_custom(func(a: TargetRef, b: TargetRef) -> bool: return pilot._victim_value(g, g.find_instance(a.instance_id)) > pilot._victim_value(g, g.find_instance(b.instance_id)))
			if refs.size() >= 2: return result(pilot._victim_value(g, g.find_instance(refs[1].instance_id)) + 2.0, [refs[0], refs[1]])
		&"chain_tap_untap":
			if not ManaPlanner.plan(g, 1 - pid, ManaCost.parse("{2}{U}"), 0, [], {}, pid).is_empty(): return {}
			var victim: CardInstance = pilot._best_tap_victim(g, s, e.target_spec)
			if victim != null and victim.controller_id != pid and not victim.tapped: return result(pilot._victim_value(g, victim), [TargetRef.card(victim)])
		&"blocking_first_strike":
			if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers or g.active_player == pid: return {}
			var before := g.forecast_damage(true)
			var nested := g.undo_log != null
			var mark := g.make_mark()
			for body in g.all_battlefield():
				if not g.combat.attackers_blocked_by(body.id).is_empty(): g.continuous.add_until_eot_pump(body.id, 0, 0, [Mtg.Keyword.FIRST_STRIKE])
			g.recalculate()
			var after := g.forecast_damage(true)
			g.unmake_to(mark)
			if not nested: g.end_search()
			var value := swing(g, pilot, before, after)
			if value > 0: return result(value)
		&"aura_damage", &"coin_sweep_draw":
			var gain := 0.0
			if e.ai_role == &"coin_sweep_draw" and (me.life <= 1 or me.library.size() <= 1): return {}
			for body in g.all_battlefield():
				if not body.is_creature(): continue
				var amount := 1
				if e.ai_role == &"aura_damage":
					amount = 0
					for id in body.attachments:
						var aura := g.find_instance(id)
						if aura != null and aura.data.is_aura(): amount += 2
				if amount > 0 and DAMAGE.damage_through(g, s, TargetRef.card(body), amount) + body.damage >= body.cur_toughness and not body.cur_indestructible:
					gain += pilot._victim_value(g, body) if body.controller_id != pid else -pilot._own_value(g, body)
			if e.ai_role == &"coin_sweep_draw": gain *= 0.5
			if gain >= AiPlayer.SWEEP_BAR: return result(gain)
		&"mutual_draw_life":
			if me.library.size() > 3 and (me.hand.size() <= 2 or me.life <= 5) and them.hand.size() >= me.hand.size() + 2: return result(4.0 + pilot._draw_need(me.hand.size()))
		&"discard_redraw":
			# We may read our own hand; an opponent chooses their own discards.
			var surplus := 0
			if pilot._mana_sources(g).size() >= 5:
				for card in me.hand:
					if card != s and card.is_land(): surplus += 1
			if surplus >= 2 and me.library.size() > 2: return result(4.0, [TargetRef.player(pid)])
		&"land_type_cantrip":
			# A cantrip is not land destruction; prefer a hostile nonbasic.
			if me.library.size() <= 1: return {}
			for ref in refs:
				var body := g.find_instance(ref.instance_id)
				if body.controller_id != pid and (body.cur_supertypes & Mtg.Supertype.BASIC) == 0: return result(3.0, [ref])
		_: return null # do not swallow Ice Age or later semantic vocabularies
	return best

static func respond(g: MtgGame, pilot) -> String:
	if not pilot.profile.forecasts_tactics: return ""
	for s in g.players[pilot.pid].hand:
		if not s.is_type(Mtg.CardType.INSTANT) or s.data.spell_effects.is_empty(): continue
		var role: StringName = s.data.spell_effects[0].ai_role
		if role not in [&"attacker_destroy_token", &"blocking_first_strike", &"chain_tap_untap"]: continue
		var choice: Variant = spell_choice(g, pilot, s)
		if choice == null or choice.is_empty() or float(choice.value) < 3.0: continue
		var action: String = pilot._cast_response(g, s, choice.targets, 0, "cast %s" % s.data.card_name)
		if action != "": return action
	return ""
