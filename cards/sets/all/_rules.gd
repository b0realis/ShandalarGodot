extends RefCounted
## Alliances family dispatcher. Unknown future additions stay fail-closed;
## the catalogue gate requires a completed handler for every published name.

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/all/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_resources.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_worlds.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_auras_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/all/_links.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	preload("res://cards/sets/all/_effect_shapes.gd").annotate(c)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	for ability in c.activated_abilities:
		var extra: Array[String] = []
		if ability.sacrifice_cost: extra.append("Sacrifice this permanent")
		if ability.sacrifice_filter.is_valid(): extra.append("Sacrifice %d %s" % [ability.sacrifice_count, ability.sacrifice_filter_desc])
		if ability.life_cost > 0: extra.append("Pay %d life" % ability.life_cost)
		if ability.discard_cost > 0: extra.append("Discard %d card(s)" % ability.discard_cost)
		if ability.library_exile_cost > 0: extra.append("Exile the top %d card(s) of your library" % ability.library_exile_cost)
		if ability.graveyard_exile_filter.is_valid(): extra.append("Exile %d %s from your graveyard" % [ability.graveyard_exile_count, ability.graveyard_exile_desc])
		if ability.max_per_turn > 0: extra.append("At most %d activation(s) each turn" % ability.max_per_turn)
		for group in ability.object_costs: extra.append(String(group.operation).capitalize() + " " + String(group.desc))
		if not extra.is_empty(): ability.text = "; ".join(extra) + " — " + ability.text
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Alliances rules integration is not yet complete for this card"
