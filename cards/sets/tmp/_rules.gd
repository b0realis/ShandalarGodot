extends RefCounted
## Tempest family dispatcher (Pack 9, the Tempest block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_9_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/tmp/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_buyback.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_shadow.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_licids.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_slivers.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_spikes.gd").configure(c)
	if not done: done = preload("res://cards/sets/tmp/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Tempest block rules integration is not yet complete for this card"
