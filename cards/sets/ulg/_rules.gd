extends RefCounted
## Urza's Legacy family dispatcher (Pack 10, the Urza block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_10_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/ulg/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_enchantments.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_opal.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_echo.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_cycling.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_untap.gd").configure(c)
	if not done: done = preload("res://cards/sets/ulg/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Urza block rules integration is not yet complete for this card"
