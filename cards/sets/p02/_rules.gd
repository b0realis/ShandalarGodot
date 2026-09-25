extends RefCounted
## Current Oracle rules; no unresolved family is silently playable.
static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/p02/_simple.gd").configure(c)
	if not done: done = preload("res://cards/sets/p02/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/p02/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/p02/_combat_mana.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Portal Second Age rules integration is not yet complete for this card"
