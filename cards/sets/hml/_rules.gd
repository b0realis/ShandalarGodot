extends RefCounted
## Homelands card rules. Development guards refuse unreviewed behavior;
## no unsupported card is silently treated as a vanilla permanent.

const VANILLA := ["Abbey Gargoyles", "Ambush Party", "Anaba Bodyguard", "Cemetery Gate", "Death Speakers", "Dwarven Trader", "Ebony Rhino", "Ihsan's Shade", "Narwhal", "Sea Sprite", "Willow Faerie"]

static func apply(c: CardData) -> CardData:
	var done := VANILLA.has(c.card_name) or preload("res://cards/sets/hml/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_worlds.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_resources.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_links.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_oyster_redirect.gd").configure(c)
	if not done: done = preload("res://cards/sets/hml/_badger_ante.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	preload("res://cards/sets/hml/_effect_shapes.gd").annotate(c)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	for ability in c.activated_abilities:
		var extra: Array[String] = []
		if ability.sacrifice_cost: extra.append("Sacrifice this permanent")
		if ability.sacrifice_filter.is_valid(): extra.append("Sacrifice %d %s" % [ability.sacrifice_count, ability.sacrifice_filter_desc])
		if ability.life_cost > 0: extra.append("Pay %d life" % ability.life_cost)
		if ability.counter_cost_kind != "": extra.append("Remove %d %s counter(s)" % [ability.counter_cost_count, ability.counter_cost_kind])
		if ability.discard_cost > 0 or ability.random_discard_cost > 0:
			extra.append("Discard %d card(s)%s" % [maxi(ability.discard_cost, ability.random_discard_cost), " at random" if ability.random_discard_cost > 0 else ""])
		if ability.tap_permanent_count > 0: extra.append("Tap %d eligible permanent(s)" % ability.tap_permanent_count)
		if not extra.is_empty(): ability.text = "; ".join(extra) + " — " + ability.text
		if ability.graveyard_exile_filter.is_valid():
			ability.text = "Exile %d eligible card(s) from a graveyard — " % ability.graveyard_exile_count + ability.text
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Homelands rules integration is not yet complete for this card"
