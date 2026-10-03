extends RefCounted
## Visions family dispatcher (Pack 8, the Mirage block). Unknown future
## additions stay fail-closed; the catalogue gate requires a completed
## handler for every published name (tests/cards/test_pack_8_catalogue.gd).

static func apply(c: CardData) -> CardData:
	var done := preload("res://cards/sets/vis/_basic.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_spells.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_creatures.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_auras.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_artifacts.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_lands_mana.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_combat.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_triggers.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_phasing.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_choices.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_costs.gd").configure(c)
	if not done: done = preload("res://cards/sets/vis/_misc.gd").configure(c)
	if not done: c.castable_only_when(_pending)
	for trigger in c.triggered_abilities:
		if not trigger.capture_context.is_valid(): trigger.capturing(preload("res://cards/sets/fem/_rules.gd")._source_context)
	return c

static func _pending(_g: MtgGame, _pid: int) -> String:
	return "Mirage block rules integration is not yet complete for this card"
