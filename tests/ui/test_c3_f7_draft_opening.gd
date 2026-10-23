extends GutTest
## Adventure campaign fix pass 2026-10-23, h5-10 round 2: THE DRAFT'S
## BUILDER OPENS ON ITS POOL. [DraftBuilder] put the dealt pool in force
## after `super._ready()`, so the ordinary builder had first filtered,
## sorted and drawn the whole library (120 ms with every card pack on) and
## the pool was then walked twice more. It now puts the pool in before the
## first fill ([method DeckBuilderScreen._before_first_fill]), and the
## builder opens exactly as it did: the pool less nothing placed, the
## draft's title, its one slot and its locked medallions, its last word
## the pool's own line.


func _counts() -> Dictionary:
	return {"Grizzly Bears": 2, "Giant Growth": 1, "Lightning Bolt": 3, "Forest": 4, "Shivan Dragon": 1}


func _open() -> DraftBuilder:
	CardRegistry.ensure_loaded()
	var builder := DraftBuilder.new()
	builder.draft_counts = _counts()
	add_child_autofree(builder)
	await get_tree().process_frame
	return builder


func test_the_draft_builder_walks_its_pool_once() -> void:
	var builder: DraftBuilder = await _open()
	assert_eq(builder.filter_passes, 1,
		"one walk, over the dealt pool (it was three: the whole library, then the pool twice)")
	assert_not_null(builder.sealed)
	var listed := {}
	for entry in builder._inventory._visible_entries():
		listed[(entry[0] as CardData).card_name] = int(entry[1])
	assert_eq(listed, _counts(), "every dealt card, with its copies")
	assert_eq(builder._inventory.badge_min, 2)
	assert_false(builder._inventory.count_source.is_valid())


func test_it_opens_as_the_draft_s_builder() -> void:
	var builder: DraftBuilder = await _open()
	assert_eq(builder.deck.deck_name, "Booster Draft")
	assert_eq(builder._header_label.text, "Booster Draft", "the title slab says so")
	assert_eq(builder.deck.total(), 0, "nothing placed yet")
	assert_eq(builder._clear_button.text, "Clear deck", "nothing cleared to restore")
	for button in builder._slot_buttons:
		assert_false(button.visible, "one deck, no slots")
	assert_false((builder._command_row.get_node("LoadButton") as Control).visible)
	assert_true(builder._dice_button.disabled)
	assert_true(builder._pool_button.disabled)
	assert_eq(builder._dice_button.tooltip_text, "Your dealt pool is locked for this session.")
	assert_true(builder._dice_button.button_pressed, "the dice down: a dealt pool is in force")
	assert_eq(builder._status_label.text, "Sealed Deck — %s" % builder.sealed.summary(),
		"its last word is the pool's own line")
	assert_true(builder._add_one("Lightning Bolt"), "a dealt card goes in")
	assert_false(builder._add_one("Black Lotus"), "one not dealt does not")
