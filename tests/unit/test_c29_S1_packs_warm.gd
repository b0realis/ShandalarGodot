extends GutTest
## THE PACKS ON IN ONE REBUILD, OFF THE MAIN THREAD, AND THEIR PRICES READ
## AHEAD (0.60.15, the owner's rulings of 2026-11-03, c29 S1).
##
## Ruling 1, "Embark: no frozen window": the packs a campaign switches on as
## it sets out or resumes go on in ONE rebuild of the card pool
## ([method CardPacks.set_enabled_many]) — one pack at a time rebuilt it
## eight times for Packs 2–9 — and, asked to, it compiles on a thread
## ([method CardRegistry.load_in_background]) while the caller goes on.
##
## Ruling 2, "Prewarm pack prices": the campaign's pack cards are read on a
## worker as the world opens ([method AdventurePacks.warm]); the worker's
## rows and facts are those the main thread reads ([method
## AdventurePacks.card_stock], [method CardValue.facts]); it writes nothing
## shared while it runs; the first draw before it is done waits for it; a
## pool about to change stops it.

var _enabled_before: Array[String] = []


func before_each() -> void:
	_enabled_before = Settings.enabled_card_packs().duplicate()
	AdventureSetup.forget()


func after_each() -> void:
	AdventurePacks.stop_warm()
	AdventurePacks.warm_forced = -1
	CardRegistry.ensure_loaded()
	_switch(_enabled_before)
	AdventureSetup.forget()
	_forget_tables()


func _forget_tables() -> void:
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	LairEvent.forget()
	CardHints.forget()
	AdventurePacks.forget()


## Exactly the packs [param on] switched on in Options › Card Packs.
func _switch(on: Array) -> void:
	for id in CardPacks.available_ids():
		if CardPacks.is_enabled(id) != (id in on):
			CardPacks.set_enabled(id, id in on)


func _offered() -> Array[String]:
	return AdventureSetup.offered_packs(CardPacks.available_ids())


func _hero(selected: Array[String]) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.seed_text = "48271"
	setup.packs = selected
	var versions := {}
	for id in selected:
		versions[id] = "1"
	var record := setup.resolve(versions)
	return AdventurePlayer.begin(record, AdventureSetup.make_world(record))


## A card [param id] brings that the pool holds once it is on.
func _a_card_of(id: String) -> String:
	for entry in CardPacks.entry_records(id):
		var card := String(entry["name"])
		if AdventurePacks.owner_of(card) == id or id == FifthEditionPack.ID:
			return card
	return ""


## [param rows] as plain values: names and facts, to compare.
func _plain(rows: Array) -> Array:
	var out: Array = []
	for row in rows:
		out.append([String(row["name"]), (row["facts"] as Dictionary).duplicate()])
	return out


## Every campaign pack's stock, shelves and lists, as plain values.
func _stocks(player: AdventurePlayer) -> Dictionary:
	var out := {}
	for id in AdventurePacks.campaign_packs(player):
		out[id] = _plain(AdventurePacks.card_stock(id))
		out[id + "|shelves"] = _plain(AdventurePacks.card_stock(id, true))
	return out


## Where two stocks ([method _stocks]) part, "" when they agree — compared
## here, not by a deep diff of thousands of rows in every assertion.
func _difference(got: Dictionary, wanted: Dictionary) -> String:
	if got.keys() != wanted.keys():
		return "keys %s, wanted %s" % [got.keys(), wanted.keys()]
	for key in wanted:
		var a: Array = got[key]
		var b: Array = wanted[key]
		if a.size() != b.size():
			return "%s: %d rows, wanted %d" % [key, a.size(), b.size()]
		for i in b.size():
			if a[i] != b[i]:
				return "%s row %d: %s, wanted %s" % [key, i, a[i], b[i]]
	return ""


func _wait_for_warm() -> void:
	var waited := 0
	while not AdventurePacks.warm_done() and waited < 30000:
		OS.delay_msec(5)
		waited += 5


# ------------------------------------------------------------ ruling 1 --

## The Embark's packs, off in Options, go on in one rebuild (eight before
## for Packs 2–9: one per pack).
func test_setting_out_switches_every_pack_on_in_one_rebuild() -> void:
	var ids := _offered()
	if ids.size() < 2:
		pass_test("fewer than two packs installed here")
		return
	_switch([])
	var before := CardRegistry.revision
	assert_eq(AdventurePacks.activate(ids), "")
	assert_eq(CardRegistry.revision - before, 1, "one rebuild of the card pool")
	for id in ids:
		assert_true(CardPacks.is_enabled(id), id + " on")
		var card := _a_card_of(id)
		assert_true(card != "" and CardRegistry.has_card(card), id + "'s cards in the pool: " + card)


## The batch itself: one settings write and one rebuild, a `changed` for
## each pack that moved, nothing done for packs already as asked, and the
## refusals of a single switch.
func test_the_batch_switches_together() -> void:
	var ids := _offered()
	if ids.size() < 2:
		pass_test("fewer than two packs installed here")
		return
	_switch(ids)
	watch_signals(CardPacks)
	var before := CardRegistry.revision
	assert_true(CardPacks.set_enabled_many(ids, false))
	assert_eq(CardRegistry.revision - before, 1, "off in one rebuild")
	assert_signal_emit_count(CardPacks, "changed", ids.size(), "one change a pack")
	for id in ids:
		assert_false(CardPacks.is_enabled(id), id + " off")
	before = CardRegistry.revision
	assert_true(CardPacks.set_enabled_many(ids, false), "nothing to do is done")
	assert_eq(CardRegistry.revision, before, "and rebuilds nothing")
	var with_missing: Array[String] = [ids[0], "pack-missing"]
	assert_false(CardPacks.set_enabled_many(with_missing, true), "a pack not installed refuses all")
	assert_false(CardPacks.is_enabled(ids[0]), "and switches none")


## Asked to, the rebuild compiles on a thread: the call returns with the
## pool still building, the packs already on; the first ask for a card
## waits for it and finds them.
func test_the_rebuild_can_compile_on_a_thread() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch([])
	var before := CardRegistry.revision
	assert_eq(AdventurePacks.activate(ids, true), "")
	assert_true(CardRegistry.is_loading(), "the pool builds on its thread")
	for id in ids:
		assert_true(CardPacks.is_enabled(id), id + " on at once")
	CardRegistry.ensure_loaded()
	assert_false(CardRegistry.is_loading())
	assert_eq(CardRegistry.revision - before, 1, "one rebuild")
	for id in ids:
		var card := _a_card_of(id)
		assert_true(CardRegistry.has_card(card), id + "'s cards in the pool: " + card)


## A save whose packs are off resumes with them on in one rebuild (two
## before for Packs 3 and 9), on a thread when asked.
func test_resume_switches_the_saves_packs_on_in_one_rebuild() -> void:
	var ids := _offered()
	if ids.size() < 2:
		pass_test("fewer than two packs installed here")
		return
	var two: Array[String] = [ids[0], ids[ids.size() - 1]]
	_switch(two)
	var player := _hero(two)
	_switch([])
	var before := CardRegistry.revision
	var answer := AdventurePacks.resume(player)
	assert_eq(String(answer["refusal"]), "")
	assert_eq((answer["enabled"] as Array).size(), 2, "both named in the notice")
	assert_eq(CardRegistry.revision - before, 1, "one rebuild")
	_switch([])
	answer = AdventurePacks.resume(player, true)
	assert_eq(String(answer["refusal"]), "")
	assert_true(CardRegistry.is_loading(), "on a thread when asked")
	CardRegistry.ensure_loaded()
	for id in two:
		assert_true(CardPacks.is_enabled(id), id + " on")


# ------------------------------------------------------------ ruling 2 --

## THE WORKER'S ROWS ARE THE MAIN THREAD'S: every campaign pack's stock,
## shelves and lists, read cold on the main thread, then cold again on the
## worker and taken in — the same names in the same order, the same facts.
## While it runs it writes nothing shared; once taken in, the first draw
## reads no card.
func test_the_workers_rows_are_the_main_threads() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch(ids)
	var player := _hero(ids)
	_forget_tables()
	CardTrade.catalogue()
	var main := _stocks(player)
	var main_facts := {}
	for card in AdventurePacks.add_stock(player, CardTrade.catalogue()).map(func(row: Dictionary) -> String: return String(row["name"])):
		main_facts[card] = CardValue.facts(CardRegistry.get_card(card)).duplicate()
	_forget_tables()
	CardTrade.catalogue()
	var kept_before := CardValue._facts_read.size()
	AdventurePacks.warm_forced = 1
	assert_true(AdventurePacks.warm(player), "the worker starts")
	_wait_for_warm()
	assert_true(AdventurePacks.warm_done(), "and finishes")
	assert_eq(CardValue._facts_read.size(), kept_before, "the worker kept nothing in CardValue's cache")
	assert_true(AdventurePacks._stock.is_empty(), "nor in the packs' stock")
	AdventurePacks.settle_warm()
	assert_false(AdventurePacks.warming())
	var kept_after := CardValue._facts_read.size()
	assert_gt(kept_after, kept_before, "its facts taken in")
	assert_eq(_difference(_stocks(player), main), "", "every row and its facts as the main thread reads them")
	assert_eq(CardValue._facts_read.size(), kept_after, "the draw read no card itself")
	var wrong: Array[String] = []
	for card in main_facts:
		if CardValue.facts(CardRegistry.get_card(card)) != main_facts[card]:
			wrong.append(card)
	assert_eq(wrong, [] as Array[String], "every card's facts as the main thread reads them")
	var rows := AdventurePacks.card_stock(ids[0])
	if not rows.is_empty() and ids[0] != FifthEditionPack.ID:
		assert_true(is_same(rows[0]["facts"], CardValue.facts(CardRegistry.get_card(String(rows[0]["name"])))),
			"the rows share the facts kept")


## The reading apart is the reading: [method CardValue.read_aside] with a
## scorer of its own gives what [method CardValue.facts] gives, base cards
## (the 1997 table's or derived) and pack cards alike.
func test_reading_apart_matches_the_cache() -> void:
	var ids := _offered()
	_switch(ids)
	_forget_tables()
	var names: Array[String] = ["Lightning Bolt", "Serra Angel", "Black Lotus", "Forest"]
	for id in ids:
		var card := _a_card_of(id)
		if card != "":
			names.append(card)
	var scorer := AutoDeck.new()
	for card in names:
		var data := CardRegistry.get_card(card)
		assert_eq(CardValue.read_aside(data, CardValue.imported_table(), scorer), CardValue.facts(data), card)


## The first draw that comes before the worker is done waits for it, and
## draws what the main thread would have.
func test_the_first_draw_waits_for_the_worker() -> void:
	var ids := _offered()
	if ids.is_empty():
		pass_test("no pack installed here")
		return
	_switch(ids)
	var player := _hero(ids)
	_forget_tables()
	var main := _plain(AdventurePacks.add_stock(player, CardTrade.catalogue()))
	_forget_tables()
	AdventurePacks.warm_forced = 1
	assert_true(AdventurePacks.warm(player))
	var drawn := _plain(AdventurePacks.add_stock(player, CardTrade.catalogue()))
	assert_false(AdventurePacks.warming(), "waited for and taken in")
	assert_eq(_difference({"list": drawn}, {"list": main}), "", "the list the main thread draws")


## A pool about to change stops the worker and waits for it (it reads the
## pool), and the stock follows the new pool; a world left stops only its
## own hero's worker.
func test_a_pool_change_stops_the_worker() -> void:
	var ids := _offered()
	if ids.size() < 2:
		pass_test("fewer than two packs installed here")
		return
	_switch(ids)
	var player := _hero(ids)
	_forget_tables()
	AdventurePacks.warm_forced = 1
	assert_true(AdventurePacks.warm(player))
	AdventurePacks.stop_warm(_hero(ids))
	assert_true(AdventurePacks.warming(), "another hero's world leaves it alone")
	var off: Array[String] = [ids[0]]
	assert_true(CardPacks.set_enabled_many(off, false))
	assert_false(AdventurePacks.warming(), "stopped and waited for before the pool went")
	assert_true(AdventurePacks._stock.is_empty(), "its rows let go")
	assert_false(ids[0] in AdventurePacks.campaign_packs(player), "the pack off is no campaign pack now")
	assert_false(AdventurePacks.card_stock(ids[1]).is_empty(), "the others read from the new pool")


## Nothing to read, nothing started: no campaign pack, every pack read, or
## headless by the rule (the tests).
func test_no_worker_without_work() -> void:
	var ids := _offered()
	_switch(ids)
	assert_false(AdventurePacks.warm(_hero([] as Array[String])), "a campaign of base cards")
	if ids.is_empty():
		return
	var player := _hero(ids)
	assert_false(AdventurePacks.warm(player), "headless, by the rule")
	AdventurePacks.warm_forced = 1
	AdventurePacks.pools(player, true)
	AdventurePacks.pools(player)
	assert_false(AdventurePacks.warm(player), "every pack read already")
