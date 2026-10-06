class_name AiDeckStudy
extends RefCounted
## [QoL] A study of the seat's OWN registered list, never a library scan.
## Several plans may coexist. Only names and numbers survive the study.

var counts: Dictionary = {}
var roles: Dictionary = {}
var role_counts: Dictionary = {}
var color_demand: Dictionary = {}
var color_sources: Dictionary = {}
var curve: Array[int] = [0, 0, 0, 0, 0, 0, 0, 0]
var plans: Dictionary = {}
var synergies: Array[Dictionary] = []
var dominant := "balanced"
var average_mana := 0.0
var land_count := 0
var creature_count := 0
var unknown_count := 0


static func analyze(names: Array) -> AiDeckStudy:
	var study := AiDeckStudy.new()
	for name in names:
		study.counts[String(name)] = int(study.counts.get(String(name), 0)) + 1
	var ordered: Array = study.counts.keys()
	ordered.sort()
	var totals: Dictionary = {}
	var mana := 0
	var spells := 0
	for name in ordered:
		var data := CardRegistry.get_card(String(name))
		var copies: int = study.counts[name]
		if data == null:
			study.unknown_count += copies
			continue
		var card_roles := classify(data)
		study.roles[name] = card_roles
		for role in card_roles:
			totals[role] = int(totals.get(role, 0)) + copies
		for color in data.cost.colored:
			study.color_demand[color] = int(study.color_demand.get(color, 0)) \
				+ int(data.cost.colored[color]) * copies
		# Nominal source cards, not a promise that their activation is free
		# or that a dual produces both colours at once. Payability is live.
		var produced: Dictionary = {}
		for ability in data.mana_abilities:
			for pair in ability.produces: produced[int(pair[0])] = true
		for color in produced:
			study.color_sources[color] = int(study.color_sources.get(color, 0)) + copies
		if data.is_land():
			study.land_count += copies
			continue
		var cost := data.cost.mana_value()
		study.curve[mini(cost, 7)] += copies
		mana += cost * copies
		spells += copies
		if data.is_creature():
			study.creature_count += copies
	study.average_mana = float(mana) / maxi(spells, 1)
	study.role_counts = totals
	var denominator := float(maxi(spells, 1))
	study.plans = {
		"fast_creatures": (3.0 * totals.get("cheap_creature", 0)
			+ totals.get("pump", 0)) / denominator,
		"burn": 3.0 * totals.get("burn", 0) / denominator,
		"control": (3.0 * totals.get("counter", 0) + 2.0 * totals.get("draw", 0)
			+ totals.get("removal", 0) + 2.0 * totals.get("sweeper", 0)) / denominator,
		"ramp": (2.0 * totals.get("big_creature", 0)
			+ 2.0 * mini(int(totals.get("acceleration", 0)),
				int(totals.get("big_creature", 0)))) / denominator,
		"land_control": 4.0 * totals.get("land_denial", 0) / denominator,
		"tempo": (2.0 * totals.get("evasion", 0) + 2.0 * totals.get("bounce", 0)
			+ totals.get("cheap_creature", 0)) / denominator,
		"attrition": (2.0 * totals.get("discard", 0) + totals.get("recursion", 0)
			+ totals.get("removal", 0)) / denominator,
		"mill": 4.0 * totals.get("mill", 0) / denominator,
	}
	var best := 0.5
	for plan in study.plans:
		if float(study.plans[plan]) > best:
			best = float(study.plans[plan])
			study.dominant = plan
	study._synergy("life_into_x_damage", "life_mana", "x_damage", totals)
	study._synergy("ramp_into_finishers", "acceleration", "big_creature", totals)
	study._synergy("land_denial_with_artifact_mana", "land_denial", "artifact_mana", totals)
	study._synergy("discard_into_reanimation", "self_discard", "reanimation", totals)
	study._synergy("tokens_into_sacrifice", "tokens", "sacrifice_outlet", totals)
	study._synergy("untap_repeatable_effects", "untap", "tap_payoff", totals)
	return study


static func classify(data: CardData) -> Array[String]:
	var out: Array[String] = []
	if data.is_creature():
		out.append("creature")
		if data.cost.mana_value() <= 2 and not data.keywords.has(Mtg.Keyword.DEFENDER):
			out.append("cheap_creature")
		if data.cost.mana_value() >= 5 or data.power >= 5:
			out.append("big_creature")
		# Shadow (CR 702.28, Pack 9) is evasion as good as flying's: almost
		# nothing in the pool blocks a shade. No older card has it.
		if data.keywords.has(Mtg.Keyword.FLYING) or data.keywords.has(Mtg.Keyword.SHADOW) \
				or not data.landwalk.is_empty():
			out.append("evasion")
	if not data.is_land() and not data.mana_abilities.is_empty():
		out.append("acceleration")
		if data.types & Mtg.CardType.ARTIFACT:
			out.append("artifact_mana")
	var effects: Array = data.spell_effects.duplicate()
	for ability in data.activated_abilities:
		effects.append_array(ability.effects)
		if ability.tap_cost:
			out.append("tap_payoff")
		if ability.discard_cost > 0:
			out.append("self_discard")
		if ability.sacrifice_filter.is_valid() or ability.sacrifice_any_number:
			out.append("sacrifice_outlet")
	var intent := EffectIntent.read(effects, data.card_name)
	if intent.damage > 0 or intent.damage_uses_x:
		out.append("burn")
	if intent.damage_uses_x:
		out.append("x_damage")
	if intent.removes: out.append("removal")
	if intent.bounces: out.append("bounce")
	if intent.counters: out.append("counter")
	if intent.draws > 0 or intent.draws_use_x: out.append("draw")
	if intent.discards > 0: out.append("discard")
	if intent.mills > 0: out.append("mill")
	if intent.pumps: out.append("pump")
	if intent.untaps: out.append("untap")
	if intent.sweeper != null: out.append("sweeper")
	if intent.mana_for_life: out.append("life_mana")
	if intent.adds_mana: out.append("acceleration")
	if not intent.makes_token.is_empty(): out.append("tokens")
	if data.aura_reanimates or data.aura_graveyard_entry: out.append("reanimation")
	# This closed pool also has card-local effects. Oracle clauses classify
	# their strategic role only; legality and tactical value remain engine-owned.
	var line := data.oracle_text.to_lower()
	if "destroy target land" in line or "destroy all lands" in line \
			or "lands don't untap" in line or "lands do not untap" in line \
			or "can't untap more than one land" in line or "skip their untap" in line:
		out.append("land_denial")
	if "from your graveyard to your hand" in line:
		out.append("recursion")
	if "return" in line and "graveyard" in line and "battlefield" in line:
		out.append("reanimation")
	var unique: Array[String] = []
	for role in out:
		if not unique.has(role): unique.append(role)
	unique.sort()
	return unique


func _synergy(label: String, first: String, second: String, totals: Dictionary) -> void:
	if int(totals.get(first, 0)) > 0 and int(totals.get(second, 0)) > 0:
		synergies.append({"name": label, "first": first, "second": second,
			"copies": mini(int(totals[first]), int(totals[second]))})


## A modest preference among already useful, legal casts. Never rescues a
## zero-value play or outweighs survival/lethal tactical priorities.
func cast_bonus(name: String, visible_own: Array) -> float:
	var card_roles: Array = roles.get(name, [])
	var wanted: Dictionary = {
		"fast_creatures": ["cheap_creature", "pump"], "burn": ["burn"],
		"control": ["draw", "removal", "counter"],
		"ramp": ["acceleration", "big_creature"],
		"land_control": ["land_denial", "artifact_mana"],
		"tempo": ["cheap_creature", "evasion", "bounce"],
		"attrition": ["discard", "recursion"], "mill": ["mill", "draw"]}
	var bonus := 0.0
	for plan in plans:
		for role in wanted.get(plan, []):
			if card_roles.has(role):
				bonus = maxf(bonus, minf(float(plans[plan]) * 0.2, 0.6))
	for synergy in synergies:
		for pair in [[synergy["first"], synergy["second"]],
				[synergy["second"], synergy["first"]]]:
			if not card_roles.has(pair[0]): continue
			for other in visible_own:
				if String(other) != name and roles.get(String(other), []).has(pair[1]):
					bonus = maxf(bonus, 0.8)
	return bonus
