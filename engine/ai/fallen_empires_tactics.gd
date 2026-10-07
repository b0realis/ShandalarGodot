extends RefCounted
## Public-board policies for the card-local effects in Fallen Empires.
## null delegates to the shared scorer; {} means this effect should wait.
## Values are BEFORE mana, discard, sacrifice and helper-tap prices, which
## AiPlayer applies once. Never inspect opposing hands or either library.

static func option(game: MtgGame, pilot, source: CardInstance, index: int,
		window: String) -> Variant:
	if source.data.script_set != "fem":   # the script's own set (campaign w3-3)
		return null
	var ability: ActivatedAbility = source.cur_activated_abilities[index]
	var pid: int = pilot.pid
	var me := game.players[pid]
	var combat := game.current_step() == Mtg.Step.DECLARE_BLOCKERS
	var reacting := window == "RESPONSE" or window == "COMBAT"
	if ability.effects.is_empty(): return null    # a granted, effect-less ability is not ours to score
	var effect: EffectBase = ability.effects[0]
	var spec := effect.target_spec
	var name := source.data.card_name
	if name == "Goblin Kites":
		if game.active_player != pid or game.combat_damage_prevented \
				or game.current_step() not in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS]: return {}
		var best := {}
		var enemy := game.opponent_of(pid)
		for ref in spec.legal_targets(game, source):
			var body := game.find_instance(ref.instance_id)
			if body.cur_power <= 0 or body.has_keyword(Mtg.Keyword.FLYING) \
					or body.cur_assigns_no_combat_damage or body.cur_prevent_combat_damage_dealt: continue
			if game.current_step() == Mtg.Step.DECLARE_ATTACKERS:
				if not game.combat.attackers.has(body.id): continue
			elif CombatState.attack_illegality(game, body, enemy) != "": continue
			var ground := false
			var air := false
			for blocker in game.players[enemy].battlefield:
				if not blocker.is_creature() or CombatState.block_illegality(game, blocker, body, enemy, true, pid) != "": continue
				ground = true
				if blocker.has_keyword(Mtg.Keyword.FLYING) or blocker.has_keyword(Mtg.Keyword.REACH): air = true
			if not ground or air: continue
			# Buying flying after blockers are declared cannot undo a block.
			# Before then, price the eventual 50% loss without sampling RNG.
			var gain: float = body.cur_power * pilot._life_price(game.players[enemy].life) \
				- pilot._own_value(game, body) * 0.5
			if body.cur_power >= game.players[enemy].life: gain = 1000.0
			if gain > 0.0 and (best.is_empty() or gain > float(best.value)): best = _result(gain, [ref])
		return best
	if name in ["Delif's Cone", "Delif's Cube"] and index == 0:
		if not reacting or game.active_player != pid or game.current_step() != Mtg.Step.DECLARE_ATTACKERS: return {}
		if name == "Delif's Cone" and me.life > 8: return {}
		var best := {}
		for ref in spec.legal_targets(game, source):
			var attacker := game.find_instance(ref.instance_id)
			if not game.combat.attackers.has(attacker.id) or attacker.cur_assigns_no_combat_damage: continue
			var can_block := false
			for enemy in game.players[game.opponent_of(pid)].battlefield:
				if enemy.is_creature() and CombatState.block_illegality(game, enemy, attacker, enemy.controller_id, true, pid) == "": can_block = true
			if can_block: continue
			var gain: float = float(attacker.cur_power) * pilot._life_price(me.life) if name == "Delif's Cone" else 4.0
			gain -= float(attacker.cur_power) * 0.75
			if best.is_empty() or gain > float(best.value): best = _result(gain, [ref])
		return best
	if name == "Heroism":
		if not reacting or not combat or game.active_player == pid: return {}
		if not ManaPlanner.plan(game, game.active_player, ManaCost.parse("{2}{R}"), 0, [], {}, pid).is_empty(): return {}
		var gain := 0.0
		for id in game.combat.attackers:
			var attacker := game.find_instance(id)
			if attacker.cur_prevent_combat_damage_dealt or attacker.cur_assigns_no_combat_damage: continue
			if (attacker.cur_colors & Mtg.ManaColor.R) == 0: continue
			if not game.combat.was_blocked(game.combat.band_of(id)): gain += attacker.cur_power * pilot._life_price(me.life)
		return _result(gain + 2.0) if gain > 0.0 else {}
	if name == "Orcish Captain":
		var best := {}
		for ref in spec.legal_targets(game, source):
			var orc := game.find_instance(ref.instance_id)
			# Expected value only: never inspect or reroll the coin.
			if orc.controller_id == pid or orc.cur_toughness > 2: continue
			var gain: float = pilot._victim_value(game, orc) * 0.5 + 2.0
			if best.is_empty() or gain > float(best.value): best = _result(gain, [ref])
		return best if not reacting else {}
	if effect is CounterEffect:
		if not reacting or game.stack.is_empty(): return {}
		var top: StackItem = game.stack.back()
		if top.controller == pid or top.kind != Mtg.StackKind.SPELL: return {}
		var ref := TargetRef.card(top.card)
		if not spec.is_legal(game, ref, source): return {}
		# These are taxes, not unconditional counters. Read only the
		# opponent's public mana sources, not their hand or future choices.
		for cost in [effect.first, effect.second]:
			if cost == "": continue
			if not ManaPlanner.plan(game, top.controller, ManaCost.parse(cost), 0, [], {}, pid).is_empty(): return {}
		var value := Evaluator.card_value(top.card.data)
		for target in top.targets:
			if target.is_player: continue
			var victim := game.find_instance(target.instance_id)
			if victim != null and victim.controller_id == pid: value = maxf(value, pilot._own_value(game, victim))
		return _result(value + 2.0, [ref]) if value >= pilot.profile.counter_threshold else {}
	# These shields are useful only against an actual, hostile targeted
	# stack object. A shroud activation taps the creature and costs an untap.
	if name in ["Deep Spawn", "Homarid Warrior", "Svyelunite Priest"]:
		if not reacting or game.stack.is_empty(): return {}
		var top: StackItem = game.stack.back()
		if top.controller == pid: return {}
		for ref in top.targets:
			if ref.is_player: continue
			var victim := game.find_instance(ref.instance_id)
			if victim == null or victim.controller_id != pid or victim.cur_shroud: continue
			if spec == null and victim != source: continue
			if spec != null and not spec.is_legal(game, ref, source): continue
			return _result(pilot._own_value(game, victim) + 5.0, [] if spec == null else [ref])
		return {}
	if name == "Spore Flower":
		if not reacting or not combat or game.active_player == pid or game.combat_damage_prevented: return {}
		var damage := _unblocked_damage(game)
		return _result(1000.0 if damage >= me.life else float(damage)) if damage >= mini(me.life, 7) else {}
	if name == "Elvish Scout":
		if not reacting or not combat or game.active_player != pid: return {}
		for ref in spec.legal_targets(game, source):
			var victim := game.find_instance(ref.instance_id)
			if victim.cur_prevent_combat_damage_taken or victim.cur_assigns_no_combat_damage or not pilot._dies_in_combat(game, victim): continue
			# Do not turn a winning trade into a blank combat.
			var killed := 0.0
			for blocker_id in game.combat.blockers_of(victim.id):
				var blocker := game.find_instance(blocker_id)
				if pilot._dies_to(game, blocker, victim): killed += pilot._victim_value(game, blocker)
			return _result(pilot._own_value(game, victim) - killed + 2.0, [ref])
		return {}
	if name == "Tidal Flats":
		if not reacting or not combat or game.active_player == pid: return {}
		if not ManaPlanner.plan(game, game.active_player, ManaCost.parse("{1}"), 0, [], {}, pid).is_empty(): return {}
		var gain := 0.0
		for id in game.combat.attackers:
			var attacker := game.find_instance(id)
			if attacker.has_keyword(Mtg.Keyword.FLYING): continue
			for blocker_id in game.combat.blockers_of(id):
				var blocker := game.find_instance(blocker_id)
				if blocker.controller_id == pid and not blocker.has_keyword(Mtg.Keyword.FIRST_STRIKE) \
						and pilot._dies_to(game, attacker, blocker) and pilot._dies_to(game, blocker, attacker):
					gain += pilot._own_value(game, blocker)
		return _result(gain) if gain > 0.0 else {}
	if name == "Tourach's Gate" and index == 1:
		if not reacting or not combat or game.active_player != pid: return {}
		var gain := 0.0
		for id in game.combat.attackers:
			var attacker := game.find_instance(id)
			if attacker.cur_toughness - attacker.damage <= 1: return {}
			if not game.combat.was_blocked(game.combat.band_of(id)): gain += 2.0
		return _result(gain + 1.0) if gain > 0.0 else {}
	if name == "Vodalian War Machine" and index == 1:
		if not reacting:
			return _result(4.0) if game.active_player == pid and game.current_step() == Mtg.Step.MAIN1 \
				and source.cur_can_attack_with_defender and source.cur_power == 0 else {}
		if not combat: return {}
		if not game.combat.attackers.has(source.id) and game.combat.attackers_blocked_by(source.id).is_empty(): return {}
		var gain := 2.0
		if pilot._dies_in_combat(game, source): gain += pilot._own_value(game, source)
		return _result(gain)
	if reacting:
		return null  # shared combat policies handle the ordinary effects
	if not pilot.profile.plays_engines:
		return null
	match name:
		"Seasinger", "Thrull Champion":
			var victim := _best_enemy(game, pilot, source, spec)
			return {} if victim == null else _result(pilot._victim_value(game, victim) * 2.0 + 2.0, [TargetRef.card(victim)])
		"Elvish Hunter":
			var best: CardInstance = null
			for ref in spec.legal_targets(game, source):
				var victim := game.find_instance(ref.instance_id)
				if victim.controller_id == pid or not victim.tapped or victim.skip_next_untap or victim.cur_skips_untap: continue
				if best == null or pilot._victim_value(game, victim) > pilot._victim_value(game, best): best = victim
			return {} if best == null else _result(pilot._victim_value(game, best) + 2.0, [TargetRef.card(best)])
		"Conch Horn":
			return _result(7.0 + pilot._draw_need(me.hand.size())) if me.library.size() > 2 else {}
		"Icatian Moneychanger":
			var credit := int(source.counters.get("credit", 0))
			return _result(credit * pilot._life_price(me.life) + 2.0) if me.life <= 10 and credit > 0 else {}
		"Fungal Bloom":
			var best: CardInstance = null
			var most := -1
			for ref in spec.legal_targets(game, source):
				var fungus := game.find_instance(ref.instance_id)
				var spores := int(fungus.counters.get("spore", 0))
				if fungus.controller_id != pid or spores >= 3: continue
				var spends := false
				for action in fungus.cur_activated_abilities:
					spends = spends or action.counter_cost_kind == "spore"
				if spends and spores > most:
					most = spores
					best = fungus
			if best == null or (most < 2 and window != "SINK"): return {}
			return _result(4.0 if most == 2 else 2.0, [TargetRef.card(best)])
		"Homarid Spawning Bed":
			var fodder: CardInstance = pilot._sacrifice_fodder(game, source, ability)
			return {} if fodder == null else _result(float(fodder.data.cost.mana_value() * 2) + 1.0)
		"Ebon Praetor":
			var fodder: CardInstance = pilot._sacrifice_fodder(game, source, ability)
			if fodder == null or fodder == source or int(source.counters.get("-2/-2", 0)) == 0: return {}
			return _result(7.0 + (1.0 if fodder.cur_subtypes.has("thrull") else 0.0))
		"Merseine":
			var host := game.find_instance(source.attached_to)
			var nets := int(source.counters.get("net", 0))
			if host == null or host.controller_id != pid or not host.tapped or nets == 0: return {}
			return _result(pilot._own_value(game, host) / float(nets) + 2.0)
		"Spirit Shield", "Zelyon Sword":
			var best := _best_friend(game, pilot, source, spec)
			return {} if best == null else _result(5.0, [TargetRef.card(best)])
		"River Merfolk":
			if game.active_player != pid or game.current_step() != Mtg.Step.MAIN1 or source.tapped or source.summoning_sick \
					or source.cur_landwalk.has("mountain"): return {}
			for land in game.players[game.opponent_of(pid)].battlefield:
				if land.cur_subtypes.has("mountain"): return _result(4.0)
			return {}
		"Vodalian War Machine":
			if index != 0: return null
			if game.active_player != pid or game.current_step() != Mtg.Step.MAIN1 or source.tapped \
					or source.summoning_sick or source.cur_can_attack_with_defender: return {}
			var crew := 0
			for body in me.battlefield:
				if not body.tapped and body.cur_subtypes.has("merfolk"): crew += 1
			if source.cur_power == 0 and crew < 2: return {}
			return _result(float(source.cur_power) + 4.0)
		"Tourach's Gate":
			if index != 0: return {}
			return _result(6.0) if int(source.counters.get("time", 0)) <= 1 and me.battlefield.size() >= 4 else {}
		"Thelonite Druid":
			if game.active_player != pid or game.current_step() != Mtg.Step.MAIN1: return {}
			var forests := 0
			for land in me.battlefield:
				if land.cur_subtypes.has("forest") and not land.is_creature() and not land.tapped and not land.summoning_sick: forests += 1
			return _result(float(maxi(forests - 2, 0)) * 2.0) if forests >= 4 else {}
		"Thelonite Monk":
			var best := {}
			for ref in spec.legal_targets(game, source):
				var land := game.find_instance(ref.instance_id)
				if land.controller_id == pid or land.cur_subtypes.has("forest") or (land.data.supertypes & Mtg.Supertype.BASIC) != 0: continue
				var gain := Evaluator.land_value(game, land) + 2.0
				if best.is_empty() or gain > float(best.value): best = _result(gain, [ref])
			return best
		"Raiding Party":
			var gain := 0.0
			for player in game.players:
				var plains := 0
				var shields := 0
				for body in player.battlefield:
					if body.cur_subtypes.has("plains"): plains += 1
					if body.is_creature() and not body.tapped and (body.cur_colors & Mtg.ManaColor.W) != 0: shields += 2
				gain += maxi(plains - shields, 0) * (-3.0 if player.id == pid else 3.0)
			return _result(gain) if gain > 0.0 else {}
		"Dwarven Armorer", "Armor Thrull":
			var best := _best_friend(game, pilot, source, spec)
			if best == null or (best == source and ability.sacrifice_cost): return {}
			return _result(6.0 if name == "Armor Thrull" else 4.0, [TargetRef.card(best)])
	return null

static func catapult_choice(game: MtgGame, pilot, source: CardInstance, max_x: int) -> Dictionary:
	var opponent := game.opponent_of(pilot.pid)
	var creatures: Array[CardInstance] = []
	for body in game.players[opponent].battlefield:
		if body.is_creature(): creatures.append(body)
	if creatures.is_empty(): return {}
	var best := {}
	for x in range(1, max_x + 1):
		var damage := x / creatures.size()
		var gain := 0.0
		for body in creatures:
			if body.cur_indestructible or body.regeneration_shields > 0 or (body.cur_protection & source.cur_colors) != 0: continue
			if damage >= body.cur_toughness - body.damage + body.prevention: gain += pilot._victim_value(game, body)
		if gain >= 3.0 and (best.is_empty() or gain > float(best.value)):
			best = {"x": x, "value": gain, "targets": [TargetRef.player(opponent)]}
	return best

static func _result(value: float, targets: Array = []) -> Dictionary:
	return {"value": value, "targets": targets}

static func _best_enemy(game: MtgGame, pilot, source: CardInstance, spec: TargetSpec) -> CardInstance:
	var best: CardInstance = null
	for ref in spec.legal_targets(game, source):
		var victim := game.find_instance(ref.instance_id)
		if victim == null or victim.controller_id == pilot.pid: continue
		if best == null or pilot._victim_value(game, victim) > pilot._victim_value(game, best): best = victim
	return best

static func _best_friend(game: MtgGame, pilot, source: CardInstance, spec: TargetSpec) -> CardInstance:
	var best: CardInstance = null
	for ref in spec.legal_targets(game, source):
		var friend := game.find_instance(ref.instance_id)
		if friend == null or friend.controller_id != pilot.pid: continue
		if best == null or pilot._own_value(game, friend) > pilot._own_value(game, best): best = friend
	return best

static func _unblocked_damage(game: MtgGame) -> int:
	var damage := 0
	for id in game.combat.attackers:
		var attacker := game.find_instance(id)
		if attacker != null and not attacker.cur_assigns_no_combat_damage \
				and not attacker.cur_prevent_combat_damage_dealt \
				and not game.combat.was_blocked(game.combat.band_of(id)):
			damage += maxi(attacker.cur_power, 0)
	return damage

## Spend the Tide's blue mana first, then ask whether the remaining
## Islands unlock a worthwhile spell in OUR hand. This is conservative
## about leftover mana from a multi-mana source, never optimistic.
static func high_tide_enables(game: MtgGame, pilot, tide: CardInstance, sources: Array) -> bool:
	var paid := ManaPlanner.plan_from(sources, game.spell_cost_for(pilot.pid, tide.data), game.spell_surcharge(pilot.pid, tide.data))
	if paid.is_empty(): return false
	var after: Array = []
	for row in sources:
		var used := false
		for pick in paid:
			if pick[0] == row[0] and pick[1] == row[1]: used = true
		if used: continue
		var next: Array = row.duplicate()
		var land: CardInstance = row[0]
		if land != null and land.cur_subtypes.has("island") and row[2] == Mtg.ManaColor.U:
			next[3] += 1
		after.append(next)
	for card in game.players[pilot.pid].hand:
		if card == tide or card.is_land() or pilot._is_reactive(card.data) or Evaluator.card_value(card.data) < 3.0: continue
		var cost := game.spell_cost_for(pilot.pid, card.data)
		var extra := game.spell_surcharge(pilot.pid, card.data)
		if ManaPlanner.plan_from(sources, cost, extra).is_empty() and not ManaPlanner.plan_from(after, cost, extra).is_empty():
			return true
	return false
