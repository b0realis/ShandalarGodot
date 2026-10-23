extends GutTest
## A PLACE'S PANES OPEN AND CLOSE AS 1997'S TOWN MENU DID (adventure
## campaign 2026-10-23; findings h1-4/h3-4/h6-2, h3-7, h1-5, h2-2/h4-4,
## h2-6, h4-3). "Edit deck/Sell cards" closed into the world instead of the
## town: no World Magic seller, no autosave, and the town re-entered drew
## its quest and its trade again. The wise man's pane, left by a click and
## Escape in one frame, opened two town panes, the one under them dead. The
## town's quest taken never marked the town's wise man as heard. A lair
## stayed on the map while its pane was open, so a save made inside it gave
## its gold again on loading (ruling C: a lair is spent the moment it is
## entered). The nearest place's tune played on under a lair. And a save
## that could not be written was never told.
##
## Clicks and keys go through the viewport where the bug was in input.

## A world screen that counts the game's end and can be made to fail its
## saves.
class Probe extends WorldScreen:
	var ends := 0
	var fail_saves := false

	func _end_process() -> void:
		ends += 1

	func _write_autosave() -> String:
		return "" if fail_saves else super()


const SAVES := "user://adventure_tests_c3_f1_places"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array


func after_each() -> void:
	CardHints.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _first(kind: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


func _tile(slot: int) -> Vector2i:
	return Vector2i(int(screen.world.sites[slot]["x"]), int(screen.world.sites[slot]["y"]))


## The town panes over the world (not the wise man's, not a lair's), alive.
func _town_panes() -> Array[VisitPane]:
	var out: Array[VisitPane] = []
	for child in screen.get_children():
		if child is VisitPane and not child is WiseManPane and not child is LairPane \
				and not child.is_queued_for_deletion():
			out.append(child)
	return out


## The World Magic seller, if leaving opened it, closed.
func _past_the_seller() -> void:
	var seller := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	if seller != null and not seller.is_queued_for_deletion():
		seller.done.emit()
		await _frames()


func _press(node: Control) -> void:
	var at := node.get_global_rect().get_center()
	for pressed in [true, false]:
		var click := InputEventMouseButton.new()
		click.button_index = MOUSE_BUTTON_LEFT
		click.pressed = pressed
		click.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
		click.position = at
		click.global_position = at
		viewport.push_input(click, true)


func _escape() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)


## Findings h1-4/h3-4/h6-2: the town's deck builder comes back to the town,
## as 1997's `OpenTownDeckBuilder` came back to its menu; the town is left
## only by Leave.
func test_edit_deck_comes_back_to_the_town() -> void:
	var player := screen.player
	var town := _first(ShandalarWorld.TOWN)
	var pane := screen.visit(_tile(town))
	await _frames()
	var journal := player.journal.size()
	var offer := player.quest_offer.duplicate(true)
	var shop := (player.shops.get(str(town), {}) as Dictionary).duplicate(true)
	var last := player.last_town
	var timer := player.monster_timer
	_press(pane.find_child("Choice_deck", true, false) as Control)
	await _frames()
	assert_true(screen.building(), "Edit deck/Sell cards: the town's deck builder")
	(screen.find_child("DeckBuilder", true, false) as AdventureBuilder)._exit()
	await _frames()
	assert_false(screen.building())
	assert_eq(_town_panes().size(), 1, "Done: back in the town")
	assert_true(screen.modal(), "the town holds the screen again")
	assert_null(screen.find_child("WorldMagicPane", true, false), "the seller waits for the town to be left")
	assert_eq(player.last_town, last, "the town not left")
	assert_eq(player.monster_timer, timer, "the clock not moved on")
	assert_eq(player.journal.size(), journal, "no second arrival in the journal")
	assert_eq(player.quest_offer, offer, "no new quest drawn")
	assert_eq(player.shops.get(str(town), {}), shop, "nor a new trade colour")
	# Leave: now the town is left.
	_town_panes()[0].choose("leave")
	await _frames()
	await _past_the_seller()
	assert_false(screen.modal())
	assert_eq(player.last_town, town, "left by Leave")
	assert_eq(player.monster_timer & 0x1F, 0x1F, "the clock on to the next 32")


## With no cards to show, or no trade after all, the town stays.
func test_a_service_that_cannot_open_leaves_the_hero_in_the_town() -> void:
	var player := screen.player
	var town := _first(ShandalarWorld.TOWN)
	var pane := screen.visit(_tile(town))
	await _frames()
	var cards := player.cards.duplicate(true)
	player.cards.clear()
	pane.choose("deck")
	await _frames()
	assert_eq(screen.hud.notice(), "No cards yet.")
	assert_eq(_town_panes().size(), 1, "no cards yet: still in the town")
	player.cards = cards
	for hue in AdventurePlayer.COLORS:
		player.amulets[hue] = 0
	_town_panes()[0].choose("trade")
	await _frames()
	assert_false(screen.trading(), "nothing to trade")
	assert_eq(_town_panes().size(), 1, "still in the town")
	assert_ne(player.last_town, town, "never left")


## Finding h3-7: the wise man left by a click and Escape in one frame
## closes once — one town pane, which answers.
func test_the_wise_man_is_left_once() -> void:
	var town := _first(ShandalarWorld.TOWN)
	var pane := screen.visit(_tile(town))
	await _frames()
	pane.left.emit("wiseman")
	await _frames()
	var wise := screen.find_child("WiseManPane", true, false) as WiseManPane
	assert_not_null(wise, "the wise man's room")
	var leave := wise.find_child("Choice_leave", true, false) as Control
	assert_not_null(leave)
	_press(leave)
	_escape()
	await _frames(3)
	var towns := _town_panes()
	assert_eq(towns.size(), 1, "one town pane, not two")
	assert_eq(screen._visit, towns[0], "and it is the screen's")
	towns[0].choose("leave")
	await _frames()
	await _past_the_seller()
	assert_false(screen.modal(), "its Leave leaves the town")
	assert_eq(_town_panes().size(), 0)


## Finding h1-5: the town's quest heard from the wise man is his word for
## this visit, as 1997 set `g_last_town_services_town_index` at the end of
## `VisitTownWiseman` for his talk and his quest alike.
func test_the_quest_taken_is_the_wise_man_s_word_for_the_visit() -> void:
	var player := screen.player
	var town := _first(ShandalarWorld.TOWN)
	player.last_town = -1
	var pane := screen.visit(_tile(town))
	await _frames()
	var destination := -1
	for slot in screen.world.sites.size():
		if slot != town and TownStatus.is_town(screen.world, slot):
			destination = slot
			break
	player.quest_offer = {"type": Quests.LETTER_AMULET, "destination": destination, "color": 2, "at": town}
	pane.left.emit("quest")
	await _frames()
	var wise := screen.find_child("WiseManPane", true, false) as WiseManPane
	wise.choose("accept")
	assert_true(Quests.has_quest(player))
	wise.choose("leave")
	await _frames()
	assert_eq(player.last_town, town, "the wise man heard in this town")
	assert_eq(_town_panes().size(), 1, "and the town again")
	# Declined, the same (visitLocation.c 996 sets it after either).
	player.last_town = -1
	_town_panes()[0].left.emit("quest")
	await _frames()
	wise = screen.find_child("WiseManPane", true, false) as WiseManPane
	wise.choose("leave")
	await _frames()
	assert_eq(player.last_town, town, "declined: heard all the same")


## Finding h1-6 with f3's ruling kept: the town's shop is drawn again only on
## a visit after another town ([method CardShop.offers] before the town is
## the last one) — the comings and goings of this pass leave that rule be.
func test_a_town_restocks_only_after_another_town() -> void:
	var player := screen.player
	var town := _first(ShandalarWorld.TOWN)
	var other := -1
	for slot in screen.world.sites.size():
		if slot != town and int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			other = slot
			break
	var leave := func() -> void:
		var pane := _town_panes()[0]
		pane.choose("leave")
		await _frames()
		await _past_the_seller()
	screen.visit(_tile(town))
	await _frames()
	# A place sold long ago, ready to be drawn again.
	var shop: Dictionary = player.shops[str(town)]
	shop["cards"][0] = ""
	shop["restock"][0] = player.quest_timer - 1000
	await leave.call()
	screen.visit(_tile(town))
	await _frames()
	assert_eq(String(player.shops[str(town)]["cards"][0]), "", "the same town again at once: not drawn")
	await leave.call()
	screen.visit(_tile(other))
	await _frames()
	await leave.call()
	screen.visit(_tile(town))
	await _frames()
	assert_ne(String(player.shops[str(town)]["cards"][0]), "", "after another town: drawn again")


## A lair of colour 3 beside the hero in roaming slot 1, entered with the
## clock at 0 (one of the fourteen events, not a treasure).
func _enter_lair() -> LairPane:
	var player := screen.player
	var hero := player.tile()
	player.monsters = [{"slot": 1, "kind": "lair", "color": 3,
		"x": hero.x * 32 + 16, "y": (hero.y + 1) * 32 + 16}]
	player.monster_timer = 0
	var pane := screen.enter_lair(1)
	await _frames()
	return pane


func _discovered(journal: Array) -> int:
	var count := 0
	for entry in journal:
		if String((entry as Dictionary).get("text", "")).begins_with("Discovered"):
			count += 1
	return count


## Ruling C (findings h2-2, h4-4): a lair is spent the moment it is entered
## — no save holds a lair the hero is inside.
func test_a_lair_is_spent_the_moment_it_is_entered() -> void:
	var player := screen.player
	var pane := await _enter_lair()
	assert_not_null(pane)
	assert_eq(WorldLairs.held_in(player, 1), {}, "gone from the map as it is entered")
	assert_eq(player.lairs_explored, 1, "counted at once")
	assert_eq(player.monster_timer & 0x1F, 0x1F, "the clock on to the next 32")
	assert_eq(_discovered(player.journal), 1, "one Discovered line")
	# The window closed mid-lair: the save holds no lair.
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	var saved := AdventurePlayer.load_from(player.save_path())
	assert_not_null(saved, "saved as the window closed")
	assert_eq(WorldLairs.held_in(saved, 1), {}, "no lair in the save")
	assert_eq(saved.lairs_explored, 1)
	assert_eq(WorldLairs.tick(saved), -1, "loaded, the next tick enters no lair again")
	assert_eq(_discovered(saved.journal), 1, "and one Discovered line in it")
	# Leaving: counted once, not twice.
	for i in 4:
		if not screen.visiting():
			break
		pane.leave_lair()
		await _frames()
	assert_false(screen.visiting(), "left")
	assert_eq(player.lairs_explored, 1, "counted once")
	assert_eq(_discovered(player.journal), 1)


## Finding h2-6: 1997's `StopWorldLocationMusic` — the nearby place's tune
## rests under a lair, and is heard again after.
func test_the_place_s_tune_rests_in_a_lair() -> void:
	var sound := screen.soundscape
	sound.site = _first(ShandalarWorld.TOWN)
	sound.level = 60
	var pane := await _enter_lair()
	assert_eq([sound.site, sound.level], [-1, 0], "silent in the lair")
	for i in 4:
		if not screen.visiting():
			break
		pane.leave_lair()
		await _frames()
	var near := WorldSoundscape.nearest(screen.world, screen.player.position)
	var heard := int(near["percent"]) > WorldSoundscape.HEARD and String(near["key"]) != ""
	assert_eq(sound.site, int(near["slot"]) if heard else -1, "heard again from where the hero stands")


## Finding h4-3: a save that could not be written is told, and leaving the
## world asks first.
func test_a_save_that_fails_is_told_and_asked_about() -> void:
	var player := screen.player
	var hud := screen.hud
	screen.fail_saves = true
	# Leaving a place: told.
	screen.visit(_tile(_first(ShandalarWorld.VILLAGE)))
	await _frames()
	screen._left_place("")
	await _frames()
	await _past_the_seller()
	assert_eq(hud.notice(), WorldScreen.UNSAVED, "told beside the panel")
	# Exit game: asked; Stay stays.
	screen.exit_game()
	await _frames()
	var ask := screen.find_child("UnsavedAsk", true, false) as Control
	assert_not_null(ask, "asked before the game ends")
	assert_eq(screen.ends, 0, "not ended yet")
	assert_true(screen.modal(), "the question holds the screen")
	_press(ask.find_child("Stay", true, false) as Control)
	await _frames()
	assert_null(screen.find_child("UnsavedAsk", true, false), "Stay: the world again")
	assert_eq(screen.ends, 0)
	# Exit game again: Escape stays too; then leave without saving.
	screen.exit_game()
	await _frames()
	_escape()
	await _frames()
	assert_null(screen.find_child("UnsavedAsk", true, false), "Escape stays")
	screen.exit_game()
	await _frames()
	_press(screen.find_child("LeaveUnsaved", true, false) as Control)
	await _frames()
	assert_eq(screen.ends, 1, "left without saving, as asked")
	# Return to main menu: asked the same.
	screen.return_to_menu()
	await _frames()
	assert_false(screen._leaving, "asked first")
	_press(screen.find_child("LeaveUnsaved", true, false) as Control)
	await _frames()
	assert_true(screen._leaving, "then on the way to the title")
	screen._leaving = false
	# The window closed: told, for as long as the window stays.
	hud.say("")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(hud.notice(), WorldScreen.UNSAVED)
	# A lair entered: told too.
	hud.say("")
	await _enter_lair()
	assert_eq(hud.notice(), WorldScreen.UNSAVED)
	# A save that works asks nothing.
	screen.fail_saves = false
	for i in 4:
		if not screen.visiting():
			break
		(screen._visit as LairPane).leave_lair()
		await _frames()
	screen.exit_game()
	await _frames()
	assert_null(screen.find_child("UnsavedAsk", true, false))
	assert_eq(screen.ends, 2, "saved: the game ends at once")
	assert_true(FileAccess.file_exists(player.save_path()))
