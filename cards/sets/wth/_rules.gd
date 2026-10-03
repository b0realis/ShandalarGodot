extends RefCounted
## Weatherlight family dispatcher (Pack 8, the Mirage block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_8_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/wth/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_phasing.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/wth/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Mirage block rules integration is not yet complete for this card"
