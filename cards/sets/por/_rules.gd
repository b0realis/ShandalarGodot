extends RefCounted
## Original Portal uses current Oracle types and rules. No partial card is
## silently playable; the catalogue tests require every dispatch to finish.

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/por/_simple.gd").configure(c)
	if not done: done = preload("res://cards/sets/por/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/por/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/por/_spells.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	preload("res://cards/sets/por/_effect_shapes.gd").apply(c)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid():
			trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Portal rules integration is not yet complete for this card"
