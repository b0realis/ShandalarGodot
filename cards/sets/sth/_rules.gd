extends RefCounted
## Stronghold family dispatcher (Pack 9, the Tempest block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_9_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/sth/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_buyback.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_shadow.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_licids.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_slivers.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_spikes.gd").configure(c)
	if not done: done = preload("res://cards/sets/sth/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Tempest block rules integration is not yet complete for this card"
