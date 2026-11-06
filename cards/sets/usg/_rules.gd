extends RefCounted
## Urza's Saga family dispatcher (Pack 10, the Urza block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_10_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/usg/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_enchantments.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_opal.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_echo.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_cycling.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_untap.gd").configure(c)
	if not done: done = preload("res://cards/sets/usg/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Urza block rules integration is not yet complete for this card"
