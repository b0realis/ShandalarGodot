extends GutTest
## THE LAIRS' CARDS FOLLOW THE CARD POOL (adventure campaign 2026-10-23,
## with f3's [method CardValue.pool_moved]): what a lair's treasure and
## rare are drawn from ([LairEvent]) was read once and kept for the whole
## session, so a pack turned on or off went unseen by the lairs. It is read
## again when the pool's revision moves on.


func after_each() -> void:
	LairEvent.forget()


func _names(rows: Array[Dictionary]) -> Array[String]:
	var out: Array[String] = []
	for row in rows:
		out.append(String(row["name"]))
	return out


func test_the_lairs_cards_are_read_again_when_the_pool_changes() -> void:
	CardRegistry.ensure_loaded()
	LairEvent.forget()
	var count := LairEvent._cards().size()
	assert_gt(count, 300, "the base sets' cards")
	assert_true("Serra Angel" in _names(LairEvent._cards()))
	assert_eq(LairEvent._read_at, CardRegistry.revision, "read against the pool as it stands")
	# A card no longer in the pool, as a table read before a pack was
	# turned off would hold it.
	LairEvent._treasures.append({"name": "A Card Long Gone", "facts": {}, "treasure": false})
	assert_true("A Card Long Gone" in _names(LairEvent._cards()), "the same pool: the table kept")
	var revision := CardRegistry.revision
	CardRegistry.unload()
	CardRegistry.ensure_loaded()
	assert_gt(CardRegistry.revision, revision, "a new pool")
	var again := _names(LairEvent._cards())
	assert_false("A Card Long Gone" in again, "read again from the new pool")
	assert_eq(again.size(), count, "the same cards as before")
	LairEvent.forget()
	assert_eq(LairEvent._read_at, -1, "forgotten: not read yet")
