extends RefCounted
## Ice Age decisions that shared damage/pump classes cannot express.
## null delegates; {} waits. Never inspect an opposing hand, either
## library's contents, or the random generator's future state.

static func option(g: MtgGame, pilot, s: CardInstance, index: int, window: String) -> Variant:
	if s.data.script_set != "ice": return null   # the script's own set (campaign w3-3)
	var pid: int = pilot.pid
	var a: ActivatedAbility = s.cur_activated_abilities[index]
	if a.effects.is_empty(): return null    # a granted, effect-less ability is not ours to score
	var effect: EffectBase = a.effects[0]
	var reacting := window in ["RESPONSE", "COMBAT"]
	var name := s.data.card_name
	if name == "General Jarkeld":
		if g.current_step() != Mtg.Step.DECLARE_BLOCKERS or g.awaiting_blockers: return {}
		var current := {}
		for id in g.combat.blocks: current[id] = g.combat.attackers_blocked_by(id)
		var baseline := block_score(g, pilot, current)
		var best := {}
		var refs := effect.target_spec.legal_targets(g, s)
		for left in refs.size():
			for right in range(left + 1, refs.size()):
				var changed: Dictionary = load("res://cards/sets/ice/_declarations.gd").jarkeld_map(g, g.find_instance(refs[left].instance_id), g.find_instance(refs[right].instance_id))
				if changed.is_empty(): continue
				var gain := block_score(g, pilot, changed) - baseline
				if gain > 2.0 and (best.is_empty() or gain > float(best.value)): best = result(gain, [refs[left], refs[right]])
		return best
	if name == "Crown of the Ages":
		var helper = load("res://cards/sets/ice/_patterns.gd")
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var aura := g.find_instance(ref.instance_id)
			var old := g.find_instance(aura.attached_to)
			var current: float = helper.crown_value(g, aura, old, pid)
			for i in g.all_battlefield():
				if i == old or not i.is_creature() or not g.aura_can_enchant(aura, i) or (i.cur_protection & aura.cur_colors) != 0: continue
				var gain: float = helper.crown_value(g, aura, i, pid) - current
				if gain > 3.0 and (best.is_empty() or gain > float(best.value)): best = result(gain, [ref])
		return best
	if name == "Balduvian Shaman":
		if window not in ["MAIN", "COMBAT"]: return {}
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			var old: int = load("res://cards/sets/ice/_remaining.gd").circle_color(i)
			var current := 0
			var other := 0
			for enemy in g.players[1 - pid].battlefield:
				if not enemy.is_creature(): continue
				if (g.damage_source_colors(enemy) & old) != 0: current += maxi(0, enemy.cur_power)
				else: other += maxi(0, enemy.cur_power)
			if other > current + 2: best = result(float(other - current) + 3.0, [ref])
		return best
	if name == "Dreams of the Dead":
		if window not in ["MAIN", "SINK"]: return {}
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			var worth: float = pilot._own_value(g, i)
			if best.is_empty() or worth > float(best.value): best = result(worth + 3.0, [ref])
		return best
	if name in ["Merieke Ri Berit", "Infernal Denizen", "Magus of the Unseen"]:
		if window == "SINK" and name != "Magus of the Unseen": return {}
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			if i == null or i.controller_id == pid or i.cur_cant_change_control: continue
			var worth: float = pilot._victim_value(g, i) + pilot._own_value(g, i)
			if name == "Magus of the Unseen":
				var fights := g.active_player == pid and g.current_step() in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN]
				var defending := g.combat.attackers.has(i.id)
				if not fights and not defending and i.cur_mana_abilities.is_empty(): continue
				worth *= 0.6
			if best.is_empty() or worth > float(best.value): best = result(worth + 3.0, [ref])
		return best
	if name in ["Jeweled Amulet", "Ice Cauldron", "Iceberg"]:
		if window != "SINK": return {}
		if name == "Ice Cauldron":
			var wanted := 0
			for card in g.players[pid].hand:
				if not card.is_land(): wanted = maxi(wanted, card.data.cost.mana_value())
			if wanted <= 0: return {}
			var max_x: int = pilot._max_affordable_x(g, a.cost, pilot._ability_extra(g, pid, s, a), [], 0, g.ability_mana_usage_keys(s))
			var x := mini(wanted, max_x)
			return {"value": 2.0 + float(x), "targets": [], "x": x} if x > 0 else {}
		return result(2.0)
	if name == "Chromatic Armor":
		if not reacting: return {}
		var host := g.find_instance(s.attached_to)
		if host == null or host.controller_id != pid: return {}
		var color := int(s.memory.get("ward_color", 0))
		for item in g.stack:
			if item.controller == pid or item.card == null: continue
			if g.damage_source_colors(item.card) == 0: continue
			if (g.damage_source_colors(item.card) & color) != 0: continue
			var intent := EffectIntent.read(item.effects)
			if intent.damage <= 0 and not intent.damage_uses_x: continue
			for ref in item.targets:
				if not ref.is_player and ref.instance_id == host.id:
					return {"value": pilot._own_value(g, host) + 4.0, "targets": [], "x": int(s.counters.get("sleight", 0))}
		return {}
	if name == "Runed Arch":
		if g.active_player != pid or g.current_step() not in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN, Mtg.Step.DECLARE_ATTACKERS]: return {}
		var budget: int = pilot._max_affordable_x(g, a.cost, pilot._ability_extra(g, pid, s, a), [], 0, g.ability_mana_usage_keys(s))
		var rows: Array = []
		for ref in effect.target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			if i.controller_id != pid or i.cur_power <= 0 or i.has_keyword(Mtg.Keyword.UNBLOCKABLE): continue
			if g.current_step() == Mtg.Step.DECLARE_ATTACKERS:
				if not g.combat.attackers.has(i.id): continue
			elif CombatState.attack_illegality(g, i, 1 - pid) != "": continue
			var blocked := false
			for enemy in g.players[1 - pid].battlefield:
				if enemy.is_creature() and CombatState.block_illegality(g, enemy, i, 1 - pid, true, pid) == "": blocked = true
			if blocked: rows.append({"ref": ref, "power": i.cur_power})
		rows.sort_custom(func(left: Dictionary, right: Dictionary) -> bool: return int(left.power) > int(right.power))
		var targets: Array = []
		var damage := 0
		for n in mini(budget, rows.size()):
			targets.append(rows[n].ref)
			damage += int(rows[n].power)
		if targets.is_empty(): return {}
		return {"value": 1000.0 if damage >= g.players[1 - pid].life else float(damage) * 2.0, "targets": targets, "x": targets.size()}
	if name == "Krovikan Sorcerer":
		if reacting or g.players[pid].library.size() <= 2: return {}
		var worth := 8.0 if index == 1 else 6.0
		return result(worth) if g.players[pid].hand.size() >= 1 else {}
	if name == "Elemental Augury":
		# One inspection per turn; never inspect the hidden top merely to
		# decide whether to activate, nor pay again for the same ordering.
		if int(s.memory.get("augury_turn", -1)) == g.turn_number: return {}
		for item in g.stack:
			if item.kind == Mtg.StackKind.ABILITY and item.card == s: return {}
		if window == "SINK" and g.players[pid].library.size() > 1: return result(3.0, [TargetRef.player(pid)])
		return {}
	if name == "Orcish Librarian":
		return result(5.0) if window == "SINK" and g.players[pid].library.size() > 12 else {}
	if name == "Vexing Arcanix":
		return result(4.0, [TargetRef.player(1 - pid)]) if window == "SINK" and not g.players[1 - pid].library.is_empty() else {}
	if name == "Orcish Farmer":
		if window != "UPKEEP" or g.active_player == pid: return {}
		var candidates: Array = []
		for ref in effect.target_spec.legal_targets(g, s):
			var land := g.find_instance(ref.instance_id)
			if land.controller_id != pid and not land.has_subtype("swamp"):
				candidates.append(ref)
		return result(3.0, [candidates[0]]) if not candidates.is_empty() else {}
	if name == "Mercenaries":
		if not reacting or s.controller_id == pid: return {}
		for shield in g.players[pid].prevention_shield_filters:
			if String(shield.desc) == "Mercenaries": return {}
		if g.combat.attackers.has(s.id) and not g.combat.was_blocked(g.combat.band_of(s.id)):
			return result(float(maxi(0, s.cur_power)) * pilot._life_price(g.players[pid].life) + 2.0)
		return {}
	if name == "Kjeldoran Royal Guard":
		if not reacting or g.active_player == pid or g.players[pid].combat_damage_redirect >= 0: return {}
		var damage := 0
		for id in g.combat.attackers:
			var i := g.find_instance(id)
			if i != null and not g.combat.was_blocked(g.combat.band_of(id)): damage += maxi(0, i.cur_power)
		if damage <= 0: return {}
		if damage >= g.players[pid].life: return result(1000.0)
		var value: float = float(damage) * pilot._life_price(g.players[pid].life)
		if damage >= s.cur_toughness - s.damage: value -= pilot._own_value(g, s)
		return result(value + 2.0) if value > 0 else {}
	if name == "Elkin Bottle":
		# Only our own main phase gives both land and sorcery hits a use
		# before the permission expires at the next upkeep.
		return result(5.0) if window == "MAIN" and g.active_player == pid and g.players[pid].hand.size() < 4 and not g.players[pid].library.is_empty() else {}
	if name == "Ashen Ghoul": return result(12.0)
	if name == "Whiteout":
		var enemy := 0
		var friendly := 0
		for i in g.all_battlefield():
			if not i.is_creature() or not i.has_keyword(Mtg.Keyword.FLYING): continue
			if i.controller_id == pid: friendly += 1
			else: enemy += 1
		return result(10.0) if enemy > friendly and g.players[pid].battlefield.size() > 4 else {}
	if name == "Necropotence":
		if window not in ["MAIN", "SINK"] or g.players[pid].library.is_empty(): return {}
		# Budget scheduled cards without inspecting their identities. A
		# resolved activation is no longer on the stack but still counts.
		var arriving := 0
		for entry in g.delayed_triggers:
			if int(entry.controller) == pid and entry.source != null and entry.source.data.card_name == "Necropotence": arriving += 1
		for item in g.stack:
			if item.controller == pid and item.card != null and item.card.data.card_name == "Necropotence" and item.kind == Mtg.StackKind.ABILITY: arriving += 1
		var held := g.players[pid].hand.size() + arriving
		if not pilot.profile.forecasts_tactics:
			var budget := mini(6, maxi(0, g.players[pid].life - 5))
			return result(5.0) if held < budget else {}
		return result(5.0) if necro_digs(g, pilot, held, arriving) else {}
	if name == "Jester's Cap":
		return result(15.0, [TargetRef.player(1 - pid)]) if g.players[1 - pid].library.size() > 0 else {}
	if name == "Jester's Mask":
		return result(float(g.players[1 - pid].hand.size()) * 6.0, [TargetRef.player(1 - pid)]) if g.players[1 - pid].hand.size() >= 2 else {}
	if name in ["Blinking Spirit", "Foul Familiar", "Freyalise's Charm", "Leshrac's Sigil"]:
		if not reacting: return {}
		if _targeted_danger(g, pilot, s) or (g.current_step() == Mtg.Step.DECLARE_BLOCKERS and pilot._dies_in_combat(g, s)):
			return result(pilot._own_value(g, s) + 4.0)
		return {}
	if name in ["Armor of Faith", "Stonehands", "Soul Kiss"]:
		if not reacting: return {}
		var host := g.find_instance(s.attached_to)
		if host == null or host.controller_id != pid or host.zone != Mtg.Zone.BATTLEFIELD: return {}
		# Wait for our previous pump to resolve before buying another.
		for item in g.stack:
			if item.kind == Mtg.StackKind.ABILITY and item.card == s: return {}
		var pump: PumpEffect = effect
		if pump.toughness > 0 and _burn_on(g, host) >= host.cur_toughness - host.damage:
			return result(pilot._own_value(g, host) + 4.0)
		if g.current_step() != Mtg.Step.DECLARE_BLOCKERS: return {}
		var others: Array[int] = g.combat.blockers_of(host.id) if g.combat.attackers.has(host.id) else g.combat.attackers_blocked_by(host.id)
		var damage := 0
		var kills := false
		for id in others:
			var enemy := g.find_instance(id)
			if enemy == null: continue
			damage += maxi(0, enemy.cur_power)
			kills = kills or (host.cur_power < enemy.cur_toughness - enemy.damage and host.cur_power + pump.power >= enemy.cur_toughness - enemy.damage)
		if pump.toughness > 0 and damage >= host.cur_toughness - host.damage and damage < host.cur_toughness - host.damage + pump.toughness:
			return result(pilot._own_value(g, host) + 3.0)
		if kills: return result(4.0)
		if g.combat.attackers.has(host.id) and not g.combat.was_blocked(g.combat.band_of(host.id)) and pump.power > 0:
			return result(1000.0 if host.cur_power + pump.power >= g.players[1 - pid].life else float(pump.power) + 2.0)
		return {}
	if name == "Mistfolk":
		if not reacting or g.stack.is_empty(): return {}
		var top: StackItem = g.stack.back()
		if top.kind != Mtg.StackKind.SPELL or top.controller == pid: return {}
		var ref := TargetRef.card(top.card)
		return result(pilot._own_value(g, s) + 4.0, [ref]) if effect.target_spec.is_legal(g, ref, s) else {}
	if name in ["Ice Floe", "Mole Worms"]:
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var target := g.find_instance(ref.instance_id)
			if target.controller_id == pid or target.cur_skips_untap: continue
			var value: float = pilot._victim_value(g, target) + (2.0 if target.is_creature() else 0.0)
			if best.is_empty() or value > float(best.value): best = result(value, [ref])
		return best
	if name == "Karplusan Yeti":
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			var victim := g.find_instance(ref.instance_id)
			if victim.controller_id == pid or victim.cur_toughness - victim.damage > s.cur_power: continue
			if victim.cur_indestructible or (victim.cur_protection & s.cur_colors) != 0: continue
			var value: float = pilot._victim_value(g, victim)
			if s.cur_toughness - s.damage <= victim.cur_power and not s.cur_indestructible: value -= pilot._own_value(g, s)
			if value > 0 and (best.is_empty() or value > float(best.value)): best = result(value + 1.0, [ref])
		return best
	if name == "Freyalise Supplicant":
		var fodder: CardInstance = pilot._sacrifice_fodder(g, s, a)
		if fodder == null: return {}
		var damage := maxi(0, fodder.cur_power) / 2
		var best := {}
		for ref in effect.target_spec.legal_targets(g, s):
			if ref.is_player:
				if ref.player_id != pid and damage >= g.players[ref.player_id].life: return result(1000.0, [ref])
				continue
			var victim := g.find_instance(ref.instance_id)
			if victim.controller_id == pid or victim.cur_toughness - victim.damage > damage or victim.cur_indestructible: continue
			var value: float = pilot._victim_value(g, victim)
			if best.is_empty() or value > float(best.value): best = result(value + 1.0, [ref])
		return best
	return null

# --- Campaign fix-ai-b: Necropotence priced against the table (w2-2) ---

## The life a Necropotence pilot keeps above what the table shows it:
## a Lightning Bolt's worth and a point — their hand is hidden.
const NECRO_MARGIN := 4


## THE LIFE PRICED AGAINST THE TABLE (whole-game campaign 2026-10-07,
## w2-2; [member AiProfile.forecasts_tactics]). Necropotence skips the
## draw step: paying life is the deck's only card flow. The pilot kept a
## flat five life and a hand of at most `life - 5` — at 7 life holding two
## cards it could not use, facing an empty board, it never drew again (the
## Deck Lab: sixteen turns at 7 life doing nothing). The line it keeps is
## now what their creatures could swing for next turn ([method
## AiPlayer._could_attack_next_turn], public) plus [constant NECRO_MARGIN]
## for what a hidden hand may hold; above it the hand is filled as before
## (up to six, [param held] counting the cards already on their way), and
## while life stays at or above that line it still takes ONE card a turn
## ([param arriving] none yet) — the draw the card took away — never into
## a full hand.
static func necro_digs(g: MtgGame, pilot, held: int, arriving: int) -> bool:
	var pid: int = pilot.pid
	var life: int = g.players[pid].life
	var threat := 0
	for body in g.players[g.opponent_of(pid)].battlefield:
		if body.is_creature() and pilot._could_attack_next_turn(g, body, pid):
			threat += maxi(body.cur_power, 0)
	var keep := threat + NECRO_MARGIN
	if held < mini(6, maxi(0, life - keep)):
		return true
	return arriving == 0 and held < 7 and life >= keep + 1
# --- end campaign fix-ai-b Necropotence ---


static func result(value: float, targets: Array = []) -> Dictionary:
	return {"value": value, "targets": targets}

## Public, pure lower bound for a single spell-damage packet. Read the
## engine's applicable gates; do not spend shields, run replacement choices,
## resolve arbitrary effects, look at hidden cards, or touch the RNG.
## Unknown redirects/replacements conservatively promise no damage here.
static func damage_through(g: MtgGame, source: CardInstance, ref: TargetRef, amount: int, unpreventable := false) -> int:
	if amount <= 0: return 0
	if g._damage_prevented_before_gates(source, ref, false, unpreventable): return 0
	var packet := DamagePacket.new()
	packet.source = source
	packet.source_was_spell = true
	packet.unpreventable_to_creatures = unpreventable
	packet.target = ref
	packet.amount = amount
	var body := g.find_instance(ref.instance_id) if not ref.is_player else null
	if not ref.is_player and body == null: return 0
	var gates: Array = g._damage_gates(packet, g.players[ref.player_id], source) if ref.is_player else g._creature_damage_gates(packet, body, source)
	var through := amount
	for gate in gates:
		match String(gate.kind):
			"pool": through -= g.players[ref.player_id].damage_prevention if ref.is_player else body.prevention
			"tracked_pool": through -= int(g.prevention_receipt(body, int(gate.receipt)).get("remaining", 0))
			"floor": through = mini(through, maxi(0, g.players[ref.player_id].life - g.players[ref.player_id].min_life_from_damage))
			_: return 0
	return maxi(0, through)

## forecasts_tactics owns the existing visible-damage correctness layer.
## Its null retains the first-pass target ranking, including at resolution.
static func retarget_value(g: MtgGame, pilot, spell: CardInstance, ref: TargetRef) -> float:
	var old: float = load("res://cards/sets/ice/_patterns.gd").retarget_value(g, pilot.pid, spell, ref)
	if not pilot.profile.forecasts_tactics: return old
	var item := g.find_stack_item(spell)
	if item == null or item.effects.size() != 1 or not item.effects[0] is DamageEffect: return old
	var effect: DamageEffect = item.effects[0]
	var damage := item.x_value + effect.x_bonus if effect.use_x else effect.amount
	if effect.divided_amount(item.x_value) > 0: damage = ref.amount
	var through := damage_through(g, spell, ref, damage, effect.unpreventable_to_creatures)
	if through <= 0: return 0.0
	var who := ref.player_id
	var value := 0.0
	if ref.is_player:
		value = AiPlayer.LETHAL_WORTH if through >= g.players[who].life else pilot._face_damage_value(g, through, who)
	else:
		var body := g.find_instance(ref.instance_id)
		who = body.controller_id
		if not body.cur_indestructible and body.regeneration_shields == 0 and through >= body.cur_toughness - body.damage:
			value = pilot._own_value(g, body) if who == pilot.pid else pilot._victim_value(g, body)
	return -value if who == pilot.pid else value

## Public combat-only estimates, used to select a blocker exchange and
## to force profitable fights with Melee. No speculative state mutation.
static func block_score(g: MtgGame, pilot, blocks: Dictionary) -> float:
	var score := 0.0
	for id in g.combat.attackers:
		var a := g.find_instance(id)
		var power := maxi(0, a.cur_power)
		var incoming := 0
		for blocker in blocks:
			if not (blocks[blocker] as Array).has(id): continue
			var b := g.find_instance(blocker)
			if (a.cur_protection & g.damage_source_colors(b)) == 0: incoming += maxi(0, b.cur_power)
			var kills := power >= b.cur_toughness - b.damage and not b.cur_indestructible and b.regeneration_shields == 0 and (b.cur_protection & g.damage_source_colors(a)) == 0
			if b.has_keyword(Mtg.Keyword.FIRST_STRIKE) and not a.has_keyword(Mtg.Keyword.FIRST_STRIKE) and b.cur_power >= a.cur_toughness - a.damage and not a.cur_indestructible: kills = false
			if kills:
				power -= maxi(0, b.cur_toughness - b.damage)
				score += pilot._victim_value(g, b) if b.controller_id != pilot.pid else -pilot._own_value(g, b)
		if incoming >= a.cur_toughness - a.damage and not a.cur_indestructible and a.regeneration_shields == 0:
			score += pilot._victim_value(g, a) if a.controller_id != pilot.pid else -pilot._own_value(g, a)
	return score

static func melee_blocks(g: MtgGame, pilot) -> Dictionary:
	var choices: Array[CardInstance] = []
	for i in g.players[1 - pilot.pid].battlefield:
		if i.is_creature() and not i.tapped: choices.append(i)
	choices.sort_custom(func(a: CardInstance, b: CardInstance) -> bool: return pilot._victim_value(g, a) > pilot._victim_value(g, b))
	var blocks := {}
	var baseline := 0.0
	for b in choices:
		if g.max_blockers > 0 and blocks.size() >= g.max_blockers: break
		var best := blocks
		var value := baseline
		for id in g.combat.attackers:
			var a := g.find_instance(id)
			if a.cur_min_blockers > 1 or b.cur_min_block_group > 1: continue
			if CombatState.block_illegality(g, b, a, b.controller_id, true, pilot.pid) != "": continue
			if b.cur_block_power_tax > 0 and a.cur_power >= b.cur_block_power_tax_threshold: continue
			var proposed := blocks.duplicate(true)
			proposed[b.id] = [id]
			var worth := block_score(g, pilot, proposed)
			if worth > value:
				best = proposed
				value = worth
		blocks = best
		baseline = value
	return blocks

static func respond(g: MtgGame, pilot) -> String:
	var pid: int = pilot.pid
	if pilot.profile.forecasts_tactics and g.stack.is_empty():
		for card in g.playable_cards(pid):
			if card.data.card_name not in ["Venomous Breath", "Battle Cry"]: continue
			var choice: Dictionary = combat_spell_choice(g, pilot, card)
			if choice.is_empty() or g.cast_refusal(pid, card, choice.targets) != "": continue
			var payment := g.spell_payment(pid, card.data, 0, choice.targets.size(), card)
			if not pilot._plan_and_pay(g, payment.cost, int(payment.extra), payment.usage): continue
			if g.cast_spell(pid, card, choice.targets) == "": return "cast " + card.data.card_name
	if g.current_step() == Mtg.Step.DECLARE_ATTACKERS and g.active_player == pid and g.stack.is_empty() and g.block_chooser_override < 0:
		for card in g.playable_cards(pid):
			if card.data.card_name != "Melee": continue
			var choice: Variant = spell_choice(g, pilot, card, 0, 0)
			if choice == null or choice.is_empty() or g.cast_refusal(pid, card) != "": continue
			var payment := g.spell_payment(pid, card.data, 0, 0, card)
			if not pilot._plan_and_pay(g, payment.cost, int(payment.extra), payment.usage): continue
			if g.cast_spell(pid, card) == "": return "cast Melee"
	if g.current_step() == Mtg.Step.DECLARE_ATTACKERS and g.active_player != pid:
		for card in g.playable_cards(pid):
			if card.data.card_name != "Ray of Command": continue
			var choice: Variant = spell_choice(g, pilot, card, 0, 0)
			if choice == null or choice.is_empty() or g.cast_refusal(pid, card, choice.targets) != "": continue
			var payment := g.spell_payment(pid, card.data, 0, 1, card)
			if not pilot._plan_and_pay(g, payment.cost, int(payment.extra), payment.usage): continue
			if g.cast_spell(pid, card, choice.targets) == "": return "cast Ray of Command"
	if g.stack.is_empty(): return ""
	var top: StackItem = g.stack.back()
	if top.kind != Mtg.StackKind.SPELL or top.controller == pid or top.targets.size() != 1: return ""
	var current := retarget_value(g, pilot, top.card, top.targets[0])
	var best := current
	for ref in g.single_spell_retargets(top.card): best = maxf(best, retarget_value(g, pilot, top.card, ref))
	if best <= current + 2.0: return ""
	for card in g.playable_cards(pid):
		if card.data.card_name != "Deflection" or pilot._cast_gate(g, card) != "": continue
		var payment := g.spell_payment(pid, card.data, 0, 1, card)
		if not pilot._plan_and_pay(g, payment.cost, int(payment.extra), payment.usage): continue
		var why := g.cast_spell(pid, card, [TargetRef.card(top.card)])
		if why == "": return "cast Deflection"
	return ""

static func spell_choice(g: MtgGame, pilot, s: CardInstance, max_x: int, mode: int) -> Variant:
	if s.data.script_set != "ice": return null   # the script's own set (campaign w3-3)
	var pid: int = pilot.pid
	var name := s.data.card_name
	if pilot.profile.forecasts_tactics and name in ["Venomous Breath", "Battle Cry"]:
		return combat_spell_choice(g, pilot, s)
	if name == "Hecatomb":
		return {"x": 0, "targets": [], "value": 8.0} if load("res://cards/sets/ice/_patterns.gd").hecatomb_worthwhile(g, pid) else {}
	if name == "Melee":
		if g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.active_player != pid or g.block_chooser_override >= 0: return {}
		var blocks := melee_blocks(g, pilot)
		var gain := block_score(g, pilot, blocks)
		return {"x": 0, "targets": [], "value": gain} if gain > 5.0 else {}
	if name == "Gaze of Pain":
		if g.current_step() != Mtg.Step.MAIN1: return {}
		for i in g.players[pid].battlefield:
			if CombatState.attack_illegality(g, i, 1 - pid) != "": continue
			var blockable := false
			for other in g.players[1 - pid].battlefield:
				if other.is_creature() and CombatState.block_illegality(g, other, i, 1 - pid, true, pid) == "": blockable = true
			if blockable: continue
			for victim in g.players[1 - pid].battlefield:
				if victim.is_creature() and not victim.cur_indestructible and victim.cur_toughness - victim.damage <= i.cur_power and (g.damage_source_colors(i) & victim.cur_protection) == 0:
					return {"x": 0, "targets": [], "value": pilot._victim_value(g, victim)}
		return {}
	if name == "Spoils of War":
		var needed: int = load("res://cards/sets/ice/_remaining.gd").spoils_count(g, pid)
		if needed == 0 or needed > max_x: return {}
		var best := {}
		for ref in s.data.spell_effects[0].target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			if i.controller_id != pid: continue
			var worth: float = pilot._own_value(g, i) + float(needed) * 3.0
			if i.has_keyword(Mtg.Keyword.FLYING) or i.has_keyword(Mtg.Keyword.TRAMPLE): worth += 4.0
			if best.is_empty() or worth > float(best.value):
				ref.amount = needed
				best = {"x": needed, "targets": [ref], "value": worth}
		return best
	if name == "Winter's Chill":
		var budget := mini(max_x, int(load("res://cards/sets/ice/_remaining.gd").snow_lands(g, pid)))
		if budget <= 0: return {}
		var targets: Array = []
		for ref in s.data.spell_effects[0].target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			if i.controller_id != pid and not i.cur_indestructible: targets.append(ref)
		targets.sort_custom(func(a: TargetRef, b: TargetRef) -> bool: return g.find_instance(a.instance_id).cur_power > g.find_instance(b.instance_id).cur_power)
		targets = targets.slice(0, budget)
		return {"x": targets.size(), "targets": targets, "value": float(targets.size()) * 5.0} if not targets.is_empty() else {}
	if name == "Ray of Command":
		var best := {}
		for ref in s.data.spell_effects[0].target_spec.legal_targets(g, s):
			var i := g.find_instance(ref.instance_id)
			if i.cur_cant_change_control: continue
			var attacking := g.combat.attackers.has(i.id)
			var offensive := g.active_player == pid and g.current_step() in [Mtg.Step.MAIN1, Mtg.Step.COMBAT_BEGIN]
			if not attacking and not offensive: continue
			var worth: float = float(maxi(0, i.cur_power)) * 2.0 + 3.0
			if offensive and i.cur_power >= g.players[1 - pid].life: worth += 20.0
			if best.is_empty() or worth > float(best.value): best = {"x": 0, "targets": [ref], "value": worth}
		return best
	if name in ["Hydroblast", "Pyroblast"]:
		var color := Mtg.ManaColor.R if name == "Hydroblast" else Mtg.ManaColor.U
		var spec: TargetSpec = s.data.modes[mode].effects[0].target_spec
		var best := {}
		for ref in spec.legal_targets(g, s):
			var target := g.find_instance(ref.instance_id)
			if target == null or target.controller_id == pid or (target.cur_colors & color) == 0: continue
			var worth: float = pilot._victim_value(g, target)
			if best.is_empty() or worth > float(best.value): best = {"x": 0, "targets": [ref], "value": worth + 1.0}
		return best
	if name == "Mind Warp":
		var count := mini(max_x, g.players[1 - pid].hand.size())
		return {"x": count, "targets": [TargetRef.player(1 - pid)], "value": float(count) * 3.5} if count > 0 else {}
	if name not in ["Fire Covenant", "Meteor Shower"]: return null
	var life_paid := name == "Fire Covenant"
	var budget := maxi(0, g.players[pid].life - 4) if life_paid else max_x + 1
	if budget <= 0: return {}
	var effect: DamageEffect = s.data.spell_effects[0]
	var candidates: Array = []
	for target in g.players[1 - pid].battlefield:
		if not target.is_creature() or target.cur_indestructible: continue
		var ref := TargetRef.card(target)
		if not effect.target_spec.is_legal(g, ref, s): continue
		var need := maxi(1, target.cur_toughness - target.damage)
		if not target.damage_unpreventable_this_turn: need += target.prevention
		var packet := DamagePacket.new()
		packet.source = s
		packet.source_was_spell = true
		packet.target = ref
		packet.amount = need
		var blocked := false
		for gate in g._creature_damage_gates(packet, target, s):
			# Point pools were budgeted; other active shields, redirects and
			# regeneration are conservative reasons to choose another target.
			if String(gate.kind) != "pool": blocked = true
		if blocked or target.regeneration_shields > 0: continue
		var worth: float = pilot._victim_value(g, target)
		if life_paid and worth <= need * pilot._life_price(g.players[pid].life): continue
		candidates.append({"ref": ref, "need": need, "worth": worth})
	candidates.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return float(a.worth) / int(a.need) > float(b.worth) / int(b.need))
	var targets: Array = []
	var spent := 0
	var value := 0.0
	for row in candidates:
		if spent + int(row.need) > budget: continue
		row.ref.amount = int(row.need)
		targets.append(row.ref)
		spent += int(row.need)
		value += float(row.worth)
	if not life_paid and g.players[1 - pid].life <= budget:
		var face := TargetRef.player(1 - pid)
		for amount in range(maxi(1, g.players[1 - pid].life), budget + 1):
			if pilot.profile.forecasts_tactics and damage_through(g, s, face, amount) < g.players[1 - pid].life: continue
			face.amount = amount
			return {"x": amount - 1, "targets": [face], "value": AiPlayer.LETHAL_WORTH}
	if targets.is_empty(): return {}
	return {"x": spent if life_paid else maxi(0, spent - 1), "targets": targets, "value": value + 1.0}

## Do not cast the words "this turn" before there is a useful combat.
## Both policies price declared, public combat, not a guessed future attack.
static func combat_spell_choice(g: MtgGame, pilot, source: CardInstance) -> Dictionary:
	var pid: int = pilot.pid
	if g.combat.attackers.is_empty(): return {}
	if source.data.card_name == "Venomous Breath":
		if g.awaiting_blockers or g.current_step() not in [Mtg.Step.DECLARE_BLOCKERS, Mtg.Step.FIRST_STRIKE_DAMAGE, Mtg.Step.COMBAT_DAMAGE]: return {}
		var future := g.forecast_damage(true)
		var covered := {}
		for entry in g.delayed_triggers:
			if int(entry.get("expires_turn", -1)) != g.turn_number or not entry.has("combat_destruction"): continue
			var marked: Dictionary = entry.combat_destruction
			covered.merge(g.combat_opponents_this_turn(int(marked.id), int(marked.stamp)), true)
		var best := {}
		for ref in source.data.spell_effects[0].target_spec.legal_targets(g, source):
			var body := g.find_instance(ref.instance_id)
			var history := g.combat_opponents_this_turn(body.id, body.layer_timestamp)
			var value := 0.0
			for id in history:
				var other := g.find_instance(id)
				if other == null or other.layer_timestamp != int(history[id]) or not future.alive.has(id): continue
				if int(covered.get(id, -1)) == other.layer_timestamp: continue
				if other.cur_indestructible or other.regeneration_shields > 0: continue
				value += pilot._victim_value(g, other) if other.controller_id != pid else -pilot._own_value(g, other)
			if value > 0.0 and (best.is_empty() or value > float(best.value)):
				best = {"x": 0, "targets": [ref], "value": value}
		return best
	if source.data.card_name != "Battle Cry" or g.active_player == pid or g.current_step() != Mtg.Step.DECLARE_ATTACKERS or g.combat_damage_prevented: return {}
	var attackers: Array[CardInstance] = []
	for id in g.combat.attackers: attackers.append(g.find_instance(id))
	var blockers: Array[CardInstance] = []
	for body in g.players[pid].battlefield:
		if body.is_creature(): blockers.append(body)
	var pending_bonus := 0
	for entry in g.delayed_triggers:
		if int(entry.get("expires_turn", -1)) == g.turn_number:
			pending_bonus += int(entry.get("blocking_toughness_bonus", 0))
	# Counterfactual characteristics only: do not untap through the action
	# API, trigger abilities, consume answers or inspect any hidden card.
	var nested := g.undo_log != null
	var mark := g.make_mark()
	for body in blockers:
		g._rec(body, &"cur_toughness")
		body.cur_toughness += pending_bonus
	var before: int = pilot._damage_after_value_blocks(g, attackers, blockers)
	var desperate := before >= g.players[pid].life
	if desperate: before = pilot._damage_after_value_blocks(g, attackers, blockers, {}, true)
	for body in blockers:
		if (body.cur_colors & Mtg.ManaColor.W) != 0:
			g._rec(body, &"tapped")
			body.tapped = false
		g._rec(body, &"cur_toughness")
		body.cur_toughness += 1
	var after: int = pilot._damage_after_value_blocks(g, attackers, blockers, {}, desperate)
	g.unmake_to(mark)
	if not nested: g.end_search()
	if after >= before: return {}
	var value: float = pilot._face_damage_value(g, before - after, pid)
	if before >= g.players[pid].life and after < g.players[pid].life: value = AiPlayer.LETHAL_WORTH
	return {"x": 0, "targets": [], "value": value}

static func _targeted_danger(g: MtgGame, pilot, body: CardInstance) -> bool:
	for item in g.stack:
		if item.controller == pilot.pid: continue
		var aimed := false
		for ref in item.targets:
			if not ref.is_player and ref.instance_id == body.id: aimed = true
		if not aimed: continue
		var intent := EffectIntent.read(item.effects, item.card.data.card_name if item.card != null else "")
		if intent.removes or intent.bounces or intent.damage + (item.x_value if intent.damage_uses_x else 0) >= body.cur_toughness - body.damage: return true
	return false

static func _burn_on(g: MtgGame, body: CardInstance) -> int:
	var damage := 0
	for item in g.stack:
		if item.controller == body.controller_id: continue
		for ref in item.targets:
			if not ref.is_player and ref.instance_id == body.id:
				var intent := EffectIntent.read(item.effects, item.card.data.card_name if item.card != null else "")
				damage += intent.damage + (item.x_value if intent.damage_uses_x else 0)
	return damage
