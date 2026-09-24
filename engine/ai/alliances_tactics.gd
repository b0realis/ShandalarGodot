extends RefCounted
## Public-board/own-hand policies. No future draws, hidden hands or RNG reads.
## Null and nonmatching shapes preserve pre-pack policy. All new decisions
## are gated by forecasts_tactics; legality/cost enforcement is engine-owned.
const H := preload("res://engine/ai/homelands_tactics.gd")
const COSTS := preload("res://engine/additional_object_costs.gd")

static func result(value: float, targets: Array = [], x := 0) -> Dictionary: return {"value": value, "targets": targets, "x": x}
static func affordable(g: MtgGame, pid: int, pay: Dictionary) -> bool: return g.players[pid].mana_pool.can_pay(pay.cost, pay.extra, pay.usage) or not ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty()
static func sizes_x(pilot, a: ActivatedAbility) -> bool: return pilot.profile.forecasts_tactics and not a.effects.is_empty() and a.effects[0].ai_role in [&"exact_mv_removal", &"tap_x_lands", &"mill_until_creature"]
static func object_price(g: MtgGame, pilot, s: CardInstance, groups: Array) -> float:
	var slots := COSTS.pools(g, pilot.pid, groups, s)
	if not COSTS.can_assign(slots): return INF
	var total := 0.0
	var used := {}
	for index in slots.size():
		var best := INF
		var chosen := -1
		for i in slots[index].cards:
			if used.has(i.id): continue
			var next := used.duplicate()
			next[i.id] = true
			if not COSTS.can_assign(slots, index + 1, next): continue
			var price := 0.5
			if slots[index].group.operation in ["sacrifice", "discard"]: price = pilot._own_value(g, i)
			elif slots[index].group.operation == "counter": price = pilot._own_value(g, i) if i.cur_toughness <= i.damage + 1 else 1.5
			if price < best:
				best = price
				chosen = i.id
		total += best
		used[chosen] = true
	return total

static func option(g: MtgGame, pilot, s: CardInstance, index: int, window: String) -> Variant:
	if not pilot.profile.forecasts_tactics: return null
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty(): return null
	var e: EffectBase = a.effects[0]
	var pid: int = pilot.pid
	var me := g.players[pid]
	var refs: Array = e.target_spec.legal_targets(g, s) if e.target_spec != null else []
	var best := {}
	match e.ai_role:
		&"library_selection":
			if window == "RESPONSE" or not pilot.profile.plays_engines or me.library.size() < int(e.ai_parameters.consume) + 4: return {}
			return result(float(e.ai_parameters.value), [TargetRef.player(1 - pid)] if e.target_spec != null else [])
		&"scry": return result(2.0) if window == "SINK" and not me.library.is_empty() else {}
		&"grave_bottom": return result(3.0) if not me.graveyard.is_empty() and me.library.size() < 10 and window == "SINK" else {}
		&"land_search": return result(5.5) if window != "RESPONSE" and me.library.size() > 1 else {}
		&"exact_mv_removal":
			for i in g.players[1 - pid].battlefield:
				var x := i.data.cost.mana_value()
				var ref := TargetRef.card(i)
				if not g.target_legal_at(e.target_spec, ref, s, x): continue
				var pay := g.ability_payment(pid, s, index, x)
				if ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty(): continue
				best = H.better(best, result(pilot._victim_value(g, i) + 3.0 - x * 0.5, [ref], x))
		&"tap_x_lands":
			if window != "UPKEEP": return {}
			var targets: Array = []
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id == pid or i.tapped: continue
				targets.append(ref)
				var pay := g.ability_payment(pid, s, index, targets.size())
				if ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty(): break
				best = result(3.0 * targets.size(), targets.duplicate(), targets.size())
		&"mill_until_creature":
			if window == "RESPONSE" or g.players[1 - pid].library.is_empty(): return {}
			for x in range(1, 9):
				var pay := g.ability_payment(pid, s, index, x)
				if ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty(): break
				best = result(4.0 + minf(x, g.players[1 - pid].library.size()), [TargetRef.player(1 - pid)], x)
		&"blind_counter_growth":
			# Unknown top: never pretend to know its mana value. Conservative
			# buffer against the public power-seven sacrifice threshold.
			if me.library.size() > 12 and s.cur_power <= 3 and window == "COMBAT": return result(3.5)
			return {}
		&"hasty_token": return result(6.0) if window == "MAIN" and g.current_step() == Mtg.Step.MAIN1 else {}
		&"fight":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id == pid: continue
				var recurring := false
				for trigger in i.cur_triggered_abilities: recurring = recurring or trigger.returns_source_after_death
				# Killing an automatic return outside an actual attack can
				# achieve nothing (or repeatedly grant a skipped draw). Price
				# the permanent kill only when it is permanent.
				if recurring and not g.combat.attackers.has(i.id): continue
				if a.tap_cost and g.active_player == pid and g.current_step() in [Mtg.Step.UPKEEP, Mtg.Step.DRAW, Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN] and pilot._victim_value(g, i) < float(s.cur_power): continue
				if s.cur_power >= i.cur_toughness - i.damage:
					best = H.better(best, result(pilot._victim_value(g, i) + 2.0 - (pilot._own_value(g, s) if i.cur_power >= s.cur_toughness - s.damage else 0.0), [ref]))
		&"counter_spell":
			if window != "RESPONSE": return {}
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id != pid: best = H.better(best, result(Evaluator.card_value(i.data) + 3.0, [ref]))
		&"self_bounce", &"self_bounce_gift":
			if window != "RESPONSE": return {}
			for item in g.stack:
				if item.controller == pid: continue
				for ref in item.targets:
					if not ref.is_player and ref.instance_id == s.id: return result(pilot._own_value(g, s) + 2.0, [TargetRef.player(1 - pid)] if e.target_spec != null else [])
		&"self_keyword_gift", &"self_keyword":
			var keyword: int = e.ai_parameters.keyword
			if s.has_keyword(keyword) or not g.combat.attackers.has(s.id): return {}
			return result(3.5, [TargetRef.player(1 - pid)] if e.target_spec != null else [])
		&"match_combat_stats":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				var dp := i.cur_toughness - 1 - s.cur_power
				var dt := i.cur_power + 1 - s.cur_toughness
				best = H.better(best, result(H.pump_gain(g, pilot, s, dp, dt), [ref]))
		&"untap_host":
			var host := g.find_instance(s.attached_to)
			return result(4.0) if host != null and host.tapped and host.controller_id == pid else {}
		&"permanent_keyword":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id == pid and not i.has_keyword(int(e.ai_parameters.keyword)): best = H.better(best, result(3.0 + float(i.cur_power) * 0.5, [ref]))
		&"recover_hidden":
			for link in s.memory.get("all_scepter", []):
				var i := g.find_instance(int(link[0]))
				if i != null and i.zone == Mtg.Zone.EXILE and i.exile_entry == int(link[1]) and i.owner_id == pid and i.exile_visible_to == pid: return result(5.0)
			return {}
		&"hide_hand":
			# Avoid a free hide/recover loop; only protect against an actual
			# opponent discard spell announced on the public stack.
			if window != "RESPONSE" or me.hand.is_empty(): return {}
			for item in g.stack:
				if item.controller != pid and EffectIntent.read(item.effects).discards > 0: return result(4.0)
			return {}
		&"blind_snow_pump", &"blind_risky_pump": return {} # unknown outcomes are not guaranteed pumps
		&"untap_object":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id == pid and i.tapped: best = H.better(best, result(3.0 if i.is_land() else 4.0, [ref]))
		&"tap_flyer":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id != pid and not i.tapped and g.current_step() in [Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS]: best = H.better(best, result(pilot._victim_value(g, i), [ref]))
		&"permanent_animation":
			var lands := 0
			for land in me.battlefield:
				if land.is_land(): lands += 1
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				if i.controller_id == pid and not i.is_creature() and lands > 4: best = H.better(best, result(8.0, [ref]))
		&"remove_auras":
			for ref in refs:
				var i := g.find_instance(ref.instance_id)
				var value := 0.0
				for aura in g.all_battlefield():
					if aura.attached_to == i.id and aura.controller_id != pid: value += pilot._victim_value(g, aura)
				if value > 0: best = H.better(best, result(value + 2.0, [ref]))
		&"regenerate_gift":
			if s.regeneration_shields > 0 or not g.can_forecast_damage_top() and (g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers): return {}
			var future := g.forecast_damage(true, g.can_forecast_damage_top())
			if not future.alive.has(s.id): return result(pilot._own_value(g, s) - 1.0, [TargetRef.player(1 - pid)])
		&"suicide_evasion", &"band_trample", &"move_buff_aura": return null
		_: return null
	return best

static func special_spell(g: MtgGame, pilot, response := false) -> String:
	if not pilot.profile.forecasts_tactics: return ""
	var best := {}
	for s in g.players[pilot.pid].hand:
		if response and not s.is_type(Mtg.CardType.INSTANT): continue
		if g.cast_timing_refusal(pilot.pid, s) != "": continue
		var payments := false
		for row in s.data.modes:
			if not row.get("payment", {}).is_empty(): payments = true
		var custom: Variant = spell_choice(g, pilot, s) if response else null
		if not payments and s.data.repeated_additional_cost == "" and s.data.extra_target_color_mask == 0 and custom == null: continue
		for mode in maxi(1, s.data.modes.size()):
			var effects: Array = s.data.modes[mode].effects if s.data.is_modal() else s.data.spell_effects
			if effects.is_empty(): continue
			var e: EffectBase = effects[0]
			var choice := {}
			if e is CounterEffect:
				if not response or g.stack.is_empty(): continue
				var top: StackItem = g.stack.back()
				if top.controller == pilot.pid or top.kind != Mtg.StackKind.SPELL: continue
				var ref := TargetRef.card(top.card)
				if not e.target_spec.is_legal(g, ref, s) or not e.affects_spell(top.card): continue
				var value := Evaluator.card_value(top.card.data)
				var intent := EffectIntent.read(top.effects)
				for t in top.targets:
					if t.is_player and t.player_id == pilot.pid and intent.damage_at(top.x_value) >= g.players[pilot.pid].life: value += 100.0
				choice = result(value + 2.0, [ref])
			elif e.divided_total > 0 and (e is DamageEffect or e is CounterMarkerEffect): choice = _divided(g, pilot, s, e)
			elif e is PreventDamageEffect: choice = _prevention(g, pilot, s, e)
			elif e is PreventCombatDamageEffect:
				# The basic mode is exact. Do not value a selective Fog as a
				# blanket Fog; its paid mode stays with the explicit player.
				if mode != 0: continue
				choice = _fog(g, pilot)
			elif e is GainLifeEffect and s.data.repeated_additional_cost != "":
				if g.players[pilot.pid].life > 10: continue
				for x in range(0, 21):
					var pay := g.spell_payment(pilot.pid, s.data, x, 1, s, mode)
					if ManaPlanner.plan(g, pilot.pid, pay.cost, pay.extra, pay.usage).is_empty(): break
					choice = result((3.0 + 3.0 * x) * pilot._life_price(g.players[pilot.pid].life), [], x)
			elif e is DestroyEffect and s.data.extra_target_color_mask != 0:
				var targets: Array = []
				var value := 0.0
				for ref in e.target_spec.legal_targets(g, s):
					var i := g.find_instance(ref.instance_id)
					if i.controller_id == pilot.pid: continue
					targets.append(ref)
					var pay := g.spell_payment(pilot.pid, s.data, 0, targets.size(), s, mode)
					if ManaPlanner.plan(g, pilot.pid, pay.cost, pay.extra, pay.usage).is_empty(): break
					value += pilot._victim_value(g, i)
					choice = result(value, targets.duplicate())
			elif custom != null: choice = custom
			else: continue
			if choice.is_empty() or g.cast_refusal(pilot.pid, s, choice.targets, choice.x, mode) != "": continue
			var payment := g.spell_payment(pilot.pid, s.data, choice.x, maxi(1, choice.targets.size()), s, mode)
			if not affordable(g, pilot.pid, payment): continue
			var pitch_price := 0.0
			var alternate: Dictionary = s.data.payment_option(mode)
			if int(alternate.get("exile_color", 0)) != 0:
				pitch_price = INF
				for i in g.pitch_candidates(pilot.pid, s, mode): pitch_price = minf(pitch_price, Evaluator.card_value(i.data))
			pitch_price += int(alternate.get("life", 0)) * pilot._life_price(g.players[pilot.pid].life)
			var value: float = choice.value - pitch_price - float(payment.cost.mana_value() + payment.extra) * 0.25
			if value > 2.0 and (best.is_empty() or value > best.value): best = {"value": value, "source": s, "mode": mode, "choice": choice, "payment": payment}
	if best.is_empty(): return ""
	var pay: Dictionary = best.payment
	if not ManaPlanner.plan_and_pay(g, pilot.pid, pay.cost, pay.extra, pay.usage): return ""
	if g.cast_spell(pilot.pid, best.source, best.choice.targets, best.choice.x, best.mode) != "": return ""
	return "cast %s" % best.source.data.card_name

static func _divided(g: MtgGame, pilot, s: CardInstance, e: EffectBase) -> Dictionary:
	var damage := e is DamageEffect
	var helpful: bool = e is CounterMarkerEffect and e.kind.begins_with("+")
	if helpful:
		var best := {}
		for ref in e.target_spec.legal_targets(g, s):
			var body := g.find_instance(ref.instance_id)
			if body.controller_id != pilot.pid: continue
			ref.amount = e.divided_total
			best = H.better(best, result(H.pump_gain(g, pilot, body, e.divided_total, e.divided_total), [ref]))
		return best
	var candidates: Array = []
	for ref in e.target_spec.legal_targets(g, s):
		var i := g.find_instance(ref.instance_id)
		if i.controller_id == pilot.pid: continue
		var need := maxi(1, i.cur_toughness - (i.damage if damage else 0))
		if need <= e.divided_total: candidates.append({"ref": ref, "need": need, "value": pilot._victim_value(g, i)})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.value / a.need > b.value / b.need)
	var left := e.divided_total
	var refs: Array = []
	var value := 0.0
	for candidate in candidates:
		if e.target_max > 0 and refs.size() >= e.target_max: break
		if candidate.need > left: continue
		candidate.ref.amount = candidate.need
		left -= int(candidate.need)
		refs.append(candidate.ref)
		value += float(candidate.value)
	if refs.is_empty(): return {}
	refs[0].amount += left
	return result(value + 1.0, refs)

static func spell_choice(g: MtgGame, pilot, s: CardInstance) -> Variant:
	if not pilot.profile.forecasts_tactics or s.data.spell_effects.is_empty(): return null
	var e: EffectBase = s.data.spell_effects[0]
	var pid: int = pilot.pid
	var me := g.players[pid]
	var best := {}
	match e.ai_role:
		&"attacker_exile_life":
			for ref in e.target_spec.legal_targets(g, s):
				var body := g.find_instance(ref.instance_id)
				if body.controller_id != pid: best = H.better(best, result(pilot._victim_value(g, body) + body.cur_toughness * pilot._life_price(me.life), [ref]))
		&"mana_value_pump":
			var price := object_price(g, pilot, s, s.data.object_costs)
			for ref in e.target_spec.legal_targets(g, s):
				var body := g.find_instance(ref.instance_id)
				if body.controller_id == pid: best = H.better(best, result(H.pump_gain(g, pilot, body, body.data.cost.mana_value(), 0) - price, [ref]))
		&"asymmetric_combat_sweep", &"nonartifact_debuff_sweep":
			var value := 0.0
			if e.ai_role == &"asymmetric_combat_sweep" and me.life <= 1: return {}
			for body in g.all_battlefield():
				if not body.is_creature(): continue
				var dies := false
				if e.ai_role == &"nonartifact_debuff_sweep": dies = not body.is_type(Mtg.CardType.ARTIFACT) and (body.cur_toughness <= 1 or not body.cur_indestructible and body.damage + 1 >= body.cur_toughness)
				else:
					var damage := (2 if g.combat.attackers.has(body.id) else 0) + (1 if body.controller_id == pid else 0)
					dies = damage > 0 and not body.cur_indestructible and H.DAMAGE.damage_through(g, s, TargetRef.card(body), damage) + body.damage >= body.cur_toughness
				if dies: value += pilot._victim_value(g, body) if body.controller_id != pid else -pilot._own_value(g, body)
			if value >= AiPlayer.SWEEP_BAR: return result(value)
		&"opponent_choice_value":
			if me.library.size() > 4: return result(4.0 + pilot._draw_need(me.hand.size()))
		&"hand_filter_slow_draw":
			if me.hand.size() > 1 and me.hand.size() < 5 and me.library.size() > 3: return result(4.0)
		&"library_thin_slow_draw":
			if me.library.size() > 10: return result(2.5)
		&"reset_hands":
			if me.library.size() > 20 and me.hand.size() <= 2 and g.players[1 - pid].hand.size() >= 4: return result(6.0)
		&"untap_fog":
			if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers: return {}
			var targets: Array = []
			for ref in e.target_spec.legal_targets(g, s):
				var body := g.find_instance(ref.instance_id)
				if body.controller_id != pid and g.combat.attackers.has(body.id): targets.append(ref)
			if targets.is_empty(): return {}
			var before := g.forecast_damage(true)
			var nested := g.undo_log != null
			var mark := g.make_mark()
			for ref in targets:
				var body := g.find_instance(ref.instance_id)
				g._rec(body, &"cur_prevent_combat_damage_dealt")
				g._rec(body, &"cur_prevent_combat_damage_taken")
				body.cur_prevent_combat_damage_dealt = true
				body.cur_prevent_combat_damage_taken = true
			var after := g.forecast_damage(true)
			g.unmake_to(mark)
			if not nested: g.end_search()
			return result(H.swing(g, pilot, before, after), targets)
		_: return null
	return best

static func _prevention(g: MtgGame, pilot, s: CardInstance, e: PreventDamageEffect) -> Dictionary:
	if not g.can_forecast_damage_top() and (g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers): return {}
	var before := g.forecast_damage(true, g.can_forecast_damage_top())
	var best := {}
	for ref in e.target_spec.legal_targets(g, s):
		var object = g.players[ref.player_id] if ref.is_player else g.find_instance(ref.instance_id)
		if (ref.player_id if ref.is_player else object.controller_id) != pilot.pid: continue
		var nested := g.undo_log != null
		var mark := g.make_mark()
		var property := &"damage_prevention" if ref.is_player else &"prevention"
		g._rec(object, property)
		object.set(property, int(object.get(property)) + e.amount)
		var after := g.forecast_damage(true, g.can_forecast_damage_top())
		g.unmake_to(mark)
		if not nested: g.end_search()
		best = H.better(best, result(H.swing(g, pilot, before, after), [ref]))
	return best

static func _fog(g: MtgGame, pilot) -> Dictionary:
	if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers or g.combat_damage_prevented: return {}
	var before := g.forecast_damage(true)
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g._rec(g, &"combat_damage_prevented")
	g.combat_damage_prevented = true
	var after := g.forecast_damage(true)
	g.unmake_to(mark)
	if not nested: g.end_search()
	return result(H.swing(g, pilot, before, after))
