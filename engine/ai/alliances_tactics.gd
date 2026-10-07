extends RefCounted
## Public-board/own-hand policies. No future draws, hidden hands or RNG reads.
## Null and nonmatching shapes preserve pre-pack policy. All new decisions
## are gated by forecasts_tactics; legality/cost enforcement is engine-owned.
const H := preload("res://engine/ai/homelands_tactics.gd")
const COSTS := preload("res://engine/additional_object_costs.gd")
## Pack 9 E7's object prices: a card put on top of the library (the draw it
## replaces) and one +1/+1 counter removed from a creature that survives it.
const LIBRARY_TOP_PRICE := 0.75
const COUNTER_PRICE := 1.0

static func result(value: float, targets: Array = [], x := 0) -> Dictionary: return {"value": value, "targets": targets, "x": x}
static func affordable(g: MtgGame, pid: int, pay: Dictionary) -> bool: return g.players[pid].mana_pool.can_pay(pay.cost, pay.extra, pay.usage) or not ManaPlanner.plan(g, pid, pay.cost, pay.extra, pay.usage).is_empty()
static func sizes_x(pilot, a: ActivatedAbility) -> bool: return pilot.profile.forecasts_tactics and not a.effects.is_empty() and a.effects[0].ai_role in [&"exact_mv_removal", &"tap_x_lands", &"mill_until_creature"]
## What paying [param groups] (engine/additional_object_costs.gd) costs the
## pilot, on its own-value scale; INF when it cannot be paid at [param x].
## Pack 8 (2026-10-03) priced the new operations from the pilot's OWN board,
## hand and graveyard only: a returned land is a land drop (cheap while one
## is left this turn), a returned spell is its recasting tempo, a graveyard
## card is nearly free, a card from hand is a card, and the all-at-once
## operations price every object they take.
static func object_price(g: MtgGame, pilot, s: CardInstance, groups: Array, x := 0) -> float:
	var slots := COSTS.pools(g, pilot.pid, groups, s, x)
	if not COSTS.can_assign(slots): return INF
	var total := 0.0
	var used := {}
	for index in slots.size():
		# A CARD AT RANDOM (Pack 9 E7): nobody chooses it, so it costs the
		# AVERAGE card of the hand it is rolled from — the cards no chosen
		# slot has taken — never the cheapest (no peek at the roll).
		if COSTS.is_random(slots[index].group):
			var sum := 0.0
			var n := 0
			for i in slots[index].cards:
				if used.has(i.id): continue
				sum += _object_unit_price(g, pilot, slots[index].group, i)
				n += 1
			if n == 0: return INF
			total += sum / float(n)
			continue
		var best := INF
		var chosen := -1
		# The cards that leave every later slot payable, from ONE matching
		# (engine/additional_object_costs.gd `extendable`, campaign w7-1) —
		# the set a can_assign per candidate gave, in the same order.
		for i in COSTS.extendable(slots, index, used):
			var price := _object_unit_price(g, pilot, slots[index].group, i)
			if price < best:
				best = price
				chosen = i.id
		total += best
		used[chosen] = true
	for group in groups:
		if not COSTS.is_all(group): continue
		match String(group.operation):
			"discard_hand":
				for card in g.players[pilot.pid].hand:
					if card != s: total += Evaluator.card_value(card.data)
			"sacrifice_all":
				for body in g.players[pilot.pid].battlefield:
					if COSTS._passes(group, body): total += pilot._own_value(g, body, body == s)
	return total

static func _object_unit_price(g: MtgGame, pilot, group: Dictionary, i: CardInstance) -> float:
	match String(group.operation):
		"sacrifice", "discard": return pilot._own_value(g, i)
		"counter": return pilot._own_value(g, i) if i.cur_toughness <= i.damage + 1 else 1.5
		"return":
			if i.is_token: return pilot._own_value(g, i)   # it ceases to exist
			if i.is_land(): return 0.75 if g.land_drop_available(pilot.pid) else 1.75
			return maxf(1.0, i.data.cost.mana_value() * 0.75)
		"exile":
			match i.zone:
				Mtg.Zone.GRAVEYARD: return 0.25
				Mtg.Zone.HAND: return Evaluator.card_value(i.data)
				_: return pilot._own_value(g, i)
		# Pack 9 E7 (2026-10-06): a card discarded AT RANDOM is priced as a
		# discard (object_price averages the hand); a card put on TOP of the
		# library comes back as the next draw — what it costs is the draw it
		# replaces, a fixed fraction of a card; a counter REMOVED from a
		# creature is the counter (a +1/+1 counter is a point of each) or,
		# when it is the last of the creature's toughness, the creature.
		"random_discard": return pilot._own_value(g, i)
		"library_top": return LIBRARY_TOP_PRICE
		"remove_counter":
			var amount := int(group.get("amount", 1))
			var pt := ContinuousEffects.parse_pt_counter(String(group.get("kind", "")))
			if pt.y > 0 and i.cur_toughness - pt.y * amount <= i.damage:
				return pilot._own_value(g, i)
			return COUNTER_PRICE * amount if pt != Vector2i.ZERO else 0.5 * amount
	return 0.5

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
		&"hasty_token":
			if window != "MAIN" or g.current_step() != Mtg.Step.MAIN1: return {}
			# A TARGETED token maker (the Pack 9 study, 2026-10-06: Echo
			# Chamber activated, and refused, with no creature across the
			# table) needs a legal target first (CR 115.1, 602.2b). When
			# the OPPONENT names it ("an opponent chooses target creature
			# they control", the role's `opponent_chooses`) the copy is
			# the body they would miss least — the card's own chooser
			# order, public — and is worth that body, not a flat 6.0.
			if e.target_spec == null: return result(6.0)
			if refs.is_empty(): return {}
			if not bool(e.ai_parameters.get("opponent_chooses", false)): return result(6.0)
			var pick := _their_pick(g, s, e.target_spec, refs)
			# A COPY THAT DOES NOT STAY (campaign fix-ai-b, w3-6): a copy of
			# a body whose arrival trigger sacrifices it unless a price is
			# paid (Phyrexian Dreadnought's power 12) is a one-turn token
			# nobody pays that price for — it is gone as it arrives — and a
			# body the state-based check kills is gone too.
			if keeps_only_for_a_price(pick) or preload("res://engine/ai/mirage_tactics.gd").dies_on_arrival(g, pilot, pick): return {}
			return result(Evaluator.permanent_value(pick, pilot.profile))
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
				if i.controller_id == pid: continue
				# The profile's own bar and the shape before it
				# (2026-10-03), the question AiPlayer._try_counter asks.
				var item := _stack_item_of(g, i)
				if item == null or not pilot._counter_clears_bar(g, item): continue
				# Never at a spell that can't be countered (Pack 9 E6, Scragnoth).
				if g.spell_cant_be_countered(i): continue
				best = H.better(best, result(Evaluator.card_value(i.data) + 3.0, [ref]))
		&"self_bounce", &"self_bounce_gift":
			if window != "RESPONSE": return {}
			for item in g.stack:
				if item.controller == pid: continue
				for ref in item.targets:
					if ref == null or ref.is_player or ref.is_damage or ref.is_ability or ref.instance_id != s.id: continue
					# ONLY WHAT THE OBJECT DOES IS ANSWERED (the Pack 9 bug
					# pass, h6-8): Hibernation Sliver's grant paid 2 life and
					# bounced its own lord from a Twiddle, and from a Capsize
					# that returned it anyway.
					if takes_self(g, item, s, e): return result(pilot._own_value(g, s) + 2.0, [TargetRef.player(1 - pid)] if e.target_spec != null else [])
		&"self_keyword_gift", &"self_keyword":
			var keyword: int = e.ai_parameters.keyword
			if s.has_keyword(keyword) or not g.combat.attackers.has(s.id): return {}
			# EVASION AFTER BLOCKS IS NOTHING (Pack 9 E1, 2026-10-06): a
			# blocked creature stays blocked whatever it gains once blockers
			# are declared (CR 506.4, 509.1h) — shadow, flying, fear.
			if keyword in [Mtg.Keyword.FLYING, Mtg.Keyword.SHADOW, Mtg.Keyword.FEAR,
					Mtg.Keyword.UNBLOCKABLE] and blocks_declared(g): return {}
			# SHADOW CUTS BOTH WAYS (CR 702.28b; the bug pass, h1-3): it
			# frees the attacker from their creatures without shadow and
			# lets their SHADES block it — priced as the exchange their best
			# blocks give before and after, under the journal.
			if keyword == Mtg.Keyword.SHADOW:
				var gain := shadow_gain(g, pilot, s)
				return result(gain, [TargetRef.player(1 - pid)] if e.target_spec != null else []) if gain > 0.0 else {}
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

## THE SELF-BOUNCE'S QUESTION: does their stack [param item], aimed at
## [param s], take it from us — so that [param e] (our "return this to
## hand / to the top of the library", or a shroud or protection that
## makes the target illegal) saves something? A hostile Aura, a removal, a
## steal or an unread effect (the harm reader's removal-shaped default),
## damage or a shrink that kills it: yes. A tap (Twiddle) or damage it
## lives through: no. A BOUNCE: only when the object pays to come back
## (buyback — it fizzles into the graveyard instead), or when [param e]
## keeps the permanent where it is (shroud, protection).
static func takes_self(g: MtgGame, item: StackItem, s: CardInstance, e: EffectBase) -> bool:
	if item.kind == Mtg.StackKind.SPELL and item.card != null and item.card.data.is_aura():
		return EffectIntent.aura_aim(item.card.data) == EffectIntent.Aim.HOSTILE
	var intent := EffectIntent.read(item.effects, item.card.data.card_name if item.card != null else "")
	if not intent.is_harmful() or intent.is_tap_utility():
		return false
	if intent.removes:
		return true
	if intent.bounces:
		return bool(item.cost_paid.get("buyback", false)) or not self_bounce_leaves(e)
	if s.is_creature():
		if intent.damage_at(item.x_value) > 0 and not intent.kills(s, item.x_value):
			return false   # damage it lives through
		if intent.shrinks() and s.cur_toughness + intent.pump_toughness > s.damage:
			return false   # a shrink it lives through
	if intent.taps and not intent.unknown and intent.damage_at(item.x_value) <= 0:
		return false
	return true

## Does [param e] (a `self_bounce` effect) take the permanent off the
## battlefield — to its owner's hand or library — rather than keep it there
## out of the object's reach (shroud, protection: "gains")?
static func self_bounce_leaves(e: EffectBase) -> bool:
	return e is ReturnToHandEffect or not e.describe().to_lower().contains(" gains ")

## What a shadow gained now is worth to [param s], our attacker, before
## blocks: their untapped creatures' best blocks against our declared
## attack ([method AiPlayer._cohort_value]) with shadow and without it, run
## under the search journal; the game when it makes the attack lethal
## through their blocks. Never positive when only shades could block it.
static func shadow_gain(g: MtgGame, pilot, s: CardInstance) -> float:
	var foe := g.opponent_of(pilot.pid)
	var attackers: Array[CardInstance] = pilot._declared_attackers(g)
	var blockers: Array[CardInstance] = pilot._untapped_creatures(g, foe)
	if attackers.is_empty() or blockers.is_empty():
		return 0.0   # nothing over there blocks anything: nothing to escape
	var before: float = pilot._cohort_value(g, attackers, blockers, foe)
	var through_before: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	var nested := g.undo_log != null
	var mark := g.make_mark()
	g.continuous.add_until_eot_keywords(s.id, [Mtg.Keyword.SHADOW])
	g.recalculate()
	var after: float = pilot._cohort_value(g, attackers, blockers, foe)
	var through_after: int = pilot._damage_through_blocks(g, attackers, blockers, foe)
	g.unmake_to(mark)
	if not nested: g.end_search()
	var life := g.players[foe].life
	if through_before < life and through_after >= life:
		return pilot.LETHAL_WORTH
	return after - before

## Have this combat's blockers been declared (CR 509) — the moment after
## which no evasion changes a block?
static func blocks_declared(g: MtgGame) -> bool:
	var step := g.current_step()
	if step == Mtg.Step.DECLARE_BLOCKERS: return not g.awaiting_blockers
	return step in [Mtg.Step.FIRST_STRIKE_DAMAGE, Mtg.Step.COMBAT_DAMAGE, Mtg.Step.COMBAT_END]

## The creature the OPPONENT would name for a spec they choose ([member
## TargetSpec.chosen_by_opponent]): the first of [param refs] in the
## card's own chooser order ([member TargetSpec.chooser_order], their
## point of view — what their seat's heuristic takes), else the one worth
## least on the board. Public board only.
static func _their_pick(g: MtgGame, s: CardInstance, spec: TargetSpec, refs: Array) -> CardInstance:
	var ordered := refs.duplicate()
	if spec.chooser_order.is_valid():
		ordered.sort_custom(func(a: TargetRef, b: TargetRef) -> bool:
			return bool(spec.chooser_order.call(g, s, a, b)))
	else:
		ordered.sort_custom(func(a: TargetRef, b: TargetRef) -> bool:
			return Evaluator.permanent_value(g.find_instance(a.instance_id)) \
				< Evaluator.permanent_value(g.find_instance(b.instance_id)))
	return g.find_instance((ordered[0] as TargetRef).instance_id)

## Does [param body]'s copy sacrifice itself on arrival unless something is
## paid ("When this creature enters, sacrifice it unless you sacrifice any
## number of creatures with total power 12 or greater")? Read off its live
## arrival triggers' printed lines (campaign fix-ai-b, w3-6).
static func keeps_only_for_a_price(body: CardInstance) -> bool:
	if body == null:
		return false
	for t in body.cur_triggered_abilities:
		if t.event_type == Mtg.EventType.ENTERS_BATTLEFIELD \
				and t.text.to_lower().contains("sacrifice it unless"):
			return true
	return false

## The stack item that holds [param card], or null.
static func _stack_item_of(g: MtgGame, card: CardInstance) -> StackItem:
	for item in g.stack:
		if item.card == card: return item
	return null

static func special_spell(g: MtgGame, pilot, response := false) -> String:
	if not pilot.profile.forecasts_tactics: return ""
	var best := {}
	for s in g.players[pilot.pid].hand:
		if response and not s.is_type(Mtg.CardType.INSTANT): continue
		if g.cast_timing_refusal(pilot.pid, s) != "": continue
		var payments := false
		for row in s.data.modes:
			# A BUYBACK row (Pack 9 E2) is the printed spell plus a cost
			# that brings it back — not an alternative payment this
			# comparison can price (it would charge the cost and credit
			# nothing). Such a card is cast by the pilot's own responders,
			# whose buyback rule weighs the return (AiPlayer._cast_response).
			var pay: Dictionary = row.get("payment", {})
			if not pay.is_empty() and not bool(pay.get("buyback", false)): payments = true
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
				var lethal := false
				for t in top.targets:
					if t.is_player and t.player_id == pilot.pid and intent.damage_at(top.x_value) >= g.players[pilot.pid].life:
						value += 100.0
						lethal = true
				# THE PROFILE'S BAR (2026-10-03): this branch countered
				# anything worth more than the flat 2.0 below, so a
				# Magician (counter_threshold 7.0) Forced a Llanowar Elves.
				# The same question AiPlayer._try_counter asks — the threat
				# against the bar, unless the shape says always or never —
				# except for the burn that kills us, which this branch has
				# always answered whatever the bar.
				if not lethal and not pilot._counter_clears_bar(g, top): continue
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
			# The chosen targets priced in: a Force of Will at a Kaervek's
			# Torch pays its "{2} more" too (Pack 8, 2026-10-03).
			var payment := g.spell_payment(pilot.pid, s.data, choice.x, maxi(1, choice.targets.size()), s, mode, choice.targets)
			if not affordable(g, pilot.pid, payment): continue
			var pitch_price := 0.0
			var alternate: Dictionary = s.data.payment_option(mode)
			if int(alternate.get("exile_color", 0)) != 0:
				pitch_price = INF
				for i in g.pitch_candidates(pilot.pid, s, mode): pitch_price = minf(pitch_price, Evaluator.card_value(i.data))
			pitch_price += int(alternate.get("life", 0)) * pilot._life_price(g.players[pilot.pid].life)
			# Object costs, additional and alternative (Fireblast's two
			# Mountains, Spinning Darkness's three black cards) — Pack 8.
			var object_groups: Array = g.spell_object_costs(s.data, mode)
			if not object_groups.is_empty():
				pitch_price += object_price(g, pilot, s, object_groups, int(choice.x))
			var value: float = choice.value - pitch_price - float(payment.cost.mana_value() + payment.extra) * 0.25
			if value > 2.0 and (best.is_empty() or value > best.value): best = {"value": value, "source": s, "mode": mode, "choice": choice, "payment": payment}
	if best.is_empty(): return ""
	var pay: Dictionary = best.payment
	# The pilot's own payer (2026-10-03): the pain it may not pay and the
	# targets it may not tap or sacrifice for the spell aimed at them.
	if not pilot._plan_and_pay(g, pay.cost, pay.extra, pay.usage, pilot._own_target_ids(g, best.choice.targets)): return ""
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
