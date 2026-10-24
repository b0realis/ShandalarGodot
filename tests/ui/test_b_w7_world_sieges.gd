extends GutTest
## THE SIEGES, THE CREATURE QUESTS AND THE END ON THE WORLD SCREEN (part B,
## W7, 2026-10-23): the siege clock's step as the hero walks brings a news
## flash ([NewsFlashPane]) that stops the walk and holds the tick until it
## is read; the besieger met — beaten, the siege lifted ("Saved %s"); not
## beaten, its town falls at once, the news shown; the Spell of Dominion
## cast and a meeting or a ruled town with no card to stake end the
## adventure ([AdventureEndScreen]) — nothing saved, the title after; a
## town's creature quest offered and accepted through its panes, and its
## reward picked free over the town ([CardTradePane]).

const SAVES := "user://adventure_tests_b_w7_sieges"


## A meeting's pane as the meeting's builder makes it: `finished(result)`.
class FakeMeeting extends Control:
	signal finished(result: int)


## A world screen whose meetings and ruled towns are the test's own panes,
## and which counts its saves and its leaving.
class Probe extends WorldScreen:
	var pane: Control = null
	var asked := -1
	var saves := 0
	var titles := 0

	func _open_meeting(slot: int) -> Control:
		asked = slot
		if pane != null:
			add_child(pane)
		return pane

	func _open_ruled_pane(slot: int) -> Control:
		asked = slot
		if pane != null:
			add_child(pane)
		return pane

	func _write_autosave() -> String:
		saves += 1
		return super()

	func _go_to_title() -> void:
		titles += 1
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
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
	# The clock runs only when the test says.
	screen.set_process(false)
	screen.player.food = 50
	_lone_tile()
	_quiet_slots()
	screen.saves = 0


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## The hero set on the middle of a land tile with land all round it and no
## site within two tiles, the world explored there.
func _lone_tile() -> void:
	var world := screen.world
	for y in range(8, 56):
		for x in range(8, 56):
			if not _open_land(Vector2i(x, y)):
				continue
			screen.player.position = Vector2i(x * 32 + 16, y * 32 + 16)
			screen.show_player(screen.player)
			return
	fail_test("no lone tile in the world")


func _open_land(tile: Vector2i) -> bool:
	var world := screen.world
	for dy in range(-1, 2):
		for dx in range(-1, 3):
			if not world.is_land(tile.x + dx, tile.y + dy):
				return false
	for site in world.sites:
		if absi(int(site["x"]) - tile.x) <= 2 and absi(int(site["y"]) - tile.y) <= 2:
			return false
	return true


## Every roaming slot held by a lair off the hero's way (nothing refills,
## nothing comes); no besieger.
func _quiet_slots() -> void:
	var player := screen.player
	player.monsters = [] as Array
	for slot in WorldLairs.SLOTS:
		var tile := player.tile() + Vector2i(-4, -3 + slot)
		player.monsters.append({"slot": slot, "kind": "lair", "x": tile.x * 32 + 16, "y": tile.y * 32 + 16,
			"color": 1})
	for i in player.world.lair_respawn.size():
		player.world.lair_respawn[i] = -1000000
	player.siege_active = false


## A town of the world (not the hero's), by its slot.
func _a_town(kind := ShandalarWorld.TOWN) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == kind:
			return slot
	return -1


## The besieger of [param town] for [param wizard], [param offset] from the
## hero: within 16 by 1997's measure, met on the next tick whichever way it
## turns.
func _besieger(town: int, wizard: int, offset := Vector2i(4, 0)) -> void:
	var at := screen.player.position + offset
	screen.player.monsters.append({"slot": 7, "kind": "creature", "creature": 29, "x": at.x, "y": at.y,
		"color": wizard, "heading": 0, "frame": 0, "town": town})
	screen.player.siege_active = true


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


func _choose(pane: Node, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames()


func _escape() -> void:
	var esc := InputEventKey.new()
	esc.keycode = KEY_ESCAPE
	esc.physical_keycode = KEY_ESCAPE
	esc.pressed = true
	viewport.push_input(esc, true)
	var up := esc.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


func _news() -> NewsFlashPane:
	return screen.find_child("NewsFlashPane", false, false) as NewsFlashPane


func _end() -> AdventureEndScreen:
	return screen.find_child("AdventureEndScreen", false, false) as AdventureEndScreen


# ------------------------------------------------------- the news flash --

func test_the_siege_clock_s_step_brings_the_news_and_holds_the_tick() -> void:
	var player := screen.player
	player.siege_timer = 63
	player.monster_timer = 96 * 10
	assert_true(screen.walk.walk_to(player.tile() + Vector2i(2, 0)))
	var t := player.monster_timer
	screen.advance(HeroWalk.TICK)
	await _frames()
	var pane := _news()
	assert_not_null(pane, "the news flash over the world")
	assert_true(screen.news_shown())
	assert_true(screen.modal(), "the world waits under it")
	assert_eq(pane.picture_key(), "visit_news")
	assert_eq(pane.place["name"], "--- NEWS FLASH ---")
	assert_string_contains(pane.words(), " sends ")
	assert_string_contains(pane.words(), " to attack ")
	assert_true(player.siege_active)
	assert_false(WorldLairs.held_in(player, 7).is_empty(), "the besieger in slot 7")
	assert_false(screen.walk.is_walking(), "the walk stopped [QoL]")
	assert_eq(player.monster_timer, t, "the tick held: the creatures' turn and the clock wait")
	assert_eq(player.siege_timer, 64 + 1, "the jump: d + T / 256")
	await _choose(pane, "continue")
	await _frames()
	assert_false(screen.news_shown(), "read")
	assert_eq(player.monster_timer, t + 1, "the held tick went on")
	assert_false(screen.modal())


# ------------------------------------------------------- the besieger --

func test_the_besieger_beaten_lifts_the_siege() -> void:
	var town := _a_town()
	_besieger(town, 4)
	var pane := FakeMeeting.new()
	screen.pane = pane
	screen.advance(HeroWalk.TICK)
	assert_eq(screen.asked, 7, "the besieger met")
	pane.finished.emit(WorldCreatures.WON)
	await _frames(3)
	assert_false(screen.player.siege_active, "lifted")
	assert_eq(String(screen.player.journal[-1]["event"]), "saved")
	assert_eq(String(screen.player.journal[-1]["text"]), "Saved %s" % WorldNames.site_name(screen.world, town))
	assert_eq(TownStatus.ruler(screen.world, town), 0)
	assert_true(WorldLairs.held_in(screen.player, 7).is_empty())
	assert_null(_news(), "no news")
	assert_eq(screen.saves, 2, "saved before and after")


func test_the_besieger_not_beaten_takes_its_town_at_once() -> void:
	var town := _a_town()
	TownStatus.put(screen.world, town, TownStatus.LINKED)
	_besieger(town, 4)
	var pane := FakeMeeting.new()
	screen.pane = pane
	screen.advance(HeroWalk.TICK)
	pane.finished.emit(WorldCreatures.LOST)
	await _frames(3)
	assert_eq(TownStatus.ruler(screen.world, town), 4, "the town falls")
	var news := _news()
	assert_not_null(news, "its news")
	var named := WorldNames.site_name(screen.world, town)
	assert_string_contains(news.words(), "The Evil Red Wizardess taps %s!" % named)
	assert_string_contains(news.words(), "Your mana tap here is lost.")
	assert_false(screen.lost())
	assert_eq(screen.saves, 2, "saved after, the town fallen")
	await _choose(news, "continue")
	await _frames()
	assert_false(screen.modal(), "the world again")


func test_dominion_ends_the_adventure_with_nothing_saved() -> void:
	var town := _a_town()
	var others: Array[int] = []
	for slot in screen.world.sites.size():
		if slot != town and TownStatus.is_town(screen.world, slot) and others.size() < 2:
			others.append(slot)
	for slot in others:
		TownStatus.take(screen.world, slot, 2)
	_besieger(town, 2)
	var pane := FakeMeeting.new()
	screen.pane = pane
	screen.advance(HeroWalk.TICK)
	assert_eq(screen.saves, 1, "saved as the meeting began")
	pane.finished.emit(WorldCreatures.DRAWN)
	await _frames(3)
	assert_true(screen.lost(), "the Spell of Dominion cast")
	assert_eq(screen.saves, 1, "no save after: the saves as they were")
	var news := _news()
	assert_string_contains(news.words(), "She casts the spell of Dominion")
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 1, "the window closed: nothing saved")
	await _choose(news, "continue")
	await _frames()
	var end := _end()
	assert_not_null(end, "the end over everything")
	assert_true(screen.ended())
	assert_eq(end.words(), "Your Righteous Quest has Failed\n\nThe Evil Planeswalker Arzakon\nand his Minion the\n"
		+ "Evil Blue Wizardess\nhave attained Dominion over the plane of Shandalar\n\n" + Sieges.SUFFER)
	var art := end.find_child("Art", true, false) as TextureRect
	assert_not_null(art)
	assert_true(screen.modal(), "the world never runs again")
	screen.advance(1.0)
	assert_false(screen.walk.is_walking())
	end.close()
	await _frames()
	assert_eq(screen.titles, 1, "back to the title")
	assert_eq(screen.saves, 1, "without a save")


func test_the_end_waits_a_moment_then_any_key_returns() -> void:
	var end := screen.show_end(["Your Righteous Quest has Failed"])
	await _frames()
	assert_false(end.ready_to_close(), "a click that brought it does not end it")
	await _escape()
	assert_eq(screen.titles, 0)
	await get_tree().create_timer(AdventureEndScreen.GUARD_MS / 1000.0 + 0.05).timeout
	await _escape()
	await _frames()
	assert_eq(screen.titles, 1, "a key: the title")
	var button := end.find_child("ReturnToTitle", true, false) as Button
	assert_not_null(button, "and the button says so")


# ------------------------------------------------- nothing left to stake --

func test_no_card_to_stake_at_a_meeting_is_the_end() -> void:
	var row := 1
	screen.player.monsters.append({"slot": 1, "kind": "creature", "creature": row,
		"x": screen.player.position.x + 4, "y": screen.player.position.y, "color": 1, "heading": 0, "frame": 0})
	# Slot 1 was a lair: the creature replaces it.
	for i in range(screen.player.monsters.size() - 1, -1, -1):
		var held: Dictionary = screen.player.monsters[i]
		if int(held["slot"]) == 1 and String(held["kind"]) == "lair":
			screen.player.monsters.remove_at(i)
	var pane := FakeMeeting.new()
	screen.pane = pane
	screen.advance(HeroWalk.TICK)
	assert_eq(screen.asked, 1)
	pane.finished.emit(WorldEncounters.GAME_OVER)
	await _frames(3)
	var end := _end()
	assert_not_null(end, "the end")
	assert_string_starts_with(end.words(), "You have no power for even an Ante!\n\nYour Righteous Quest has Failed")
	assert_string_contains(end.words(), "have worn you down")
	assert_eq(screen.saves, 1, "only the save made as the meeting began")
	assert_false(WorldLairs.held_in(screen.player, 1).is_empty(), "nothing spent")


func test_no_card_to_stake_at_a_ruled_town_is_the_end() -> void:
	var town := _a_town()
	TownStatus.take(screen.world, town, 3)
	var pane := FakeMeeting.new()
	screen.pane = pane
	screen._open_ruled_duel({"kind": "ruled", "slot": town})
	assert_eq(screen.asked, town)
	assert_true(screen.modal())
	pane.finished.emit(WorldEncounters.GAME_OVER)
	await _frames(3)
	assert_not_null(_end(), "the end, as at a meeting")
	assert_eq(screen.saves, 0, "nothing saved")


# ------------------------------------------------- a creature's quest --

## The hero on town [param town]'s tile, the town fresh: no trade to offer
## (no amulets), no quest under way.
func _in_town(town: int) -> Vector2i:
	var tile := Vector2i(int(screen.world.sites[town]["x"]), int(screen.world.sites[town]["y"]))
	screen.player.position = tile * 32 + Vector2i(16, 16)
	screen.player.last_town = -1
	screen.player.amulets = {"black": 0, "blue": 0, "green": 0, "red": 0, "white": 0}
	screen.player.quest = {}
	return tile


func test_a_town_offers_its_creature_and_the_wise_man_gives_it() -> void:
	var town := _a_town(ShandalarWorld.CITY)
	var tile := _in_town(town)
	var visit := screen.visit(tile)
	await _frames()
	assert_lt(int(screen.player.quest_offer.get("type", 0)), 0, "a city asks for a creature")
	var words := Quests.offer_words(screen.player)
	assert_string_starts_with(words[0], "Defeat the ")
	assert_string_ends_with(words[0], " which has been menacing our village.")
	await _choose(visit, "quest")
	var wise := screen.find_child("WiseManPane", false, false) as WiseManPane
	assert_not_null(wise, "Begin a Quest: the wise man")
	assert_eq(wise.words(), "\n".join(words))
	await _choose(wise, "accept")
	assert_eq(wise.words(), "You have 3 days to complete the quest.")
	assert_lt(int(screen.player.quest["type"]), 0)
	assert_eq(int(screen.player.quest["giver"]), town)


func test_a_town_s_reward_is_a_card_picked_free_and_one_must_be_taken() -> void:
	var town := _a_town()
	var tile := _in_town(town)
	screen.player.quest = {"type": -1 + Quests.DEFEATED, "destination": town, "giver": town, "color": 1,
		"deadline": screen.player.quest_timer + 47}
	var owned := screen.player.cards.size()
	screen.hud.refresh()
	assert_true(screen.hud.quest_pane_shown(), "Return to the town")
	var visit := screen.visit(tile)
	await _frames()
	assert_true(screen.rewarding(), "the free pick over the town")
	assert_false(screen.hud.quest_pane_shown(), "the quest done: the quest pane says so at once")
	assert_false(visit.visible, "the town's pane waits under it")
	assert_string_contains(visit.words(), "The people are glad to be rid of the pesky Witch.")
	var pick := screen.find_child("CardTrade", false, false) as CardTradePane
	assert_not_null(pick)
	assert_eq(pick.way, CardTrade.REWARD)
	assert_false((pick.find_child("TradeDone", true, false) as Button).visible, "no Done: one must be taken")
	var shown := pick.cards()
	assert_gt(shown.size(), 0)
	var trade := int(screen.world.sites[town]["trade"])
	for card_name in shown.slice(0, 20):
		assert_true(CardTrade.wanted(trade, CardValue.facts(CardRegistry.get_card(card_name))), "the town's wares")
	await _escape()
	assert_true(screen.rewarding(), "Escape does not leave without a card")
	screen.saves = 0
	screen._notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, 0, "mid-pick nothing saved: reported again on a reload, as in 1997")
	pick.choose(shown[0])
	assert_eq(pick.ask_text(), "%s. Will you take this card..." % shown[0])
	_press(pick.find_child("TradeNo", true, false) as Button)
	await _frames()
	assert_true(screen.rewarding(), "No: back to the cards")
	pick.choose(shown[0])
	_press(pick.find_child("TradeYes", true, false) as Button)
	await _frames(3)
	assert_false(screen.rewarding(), "taken: done")
	assert_eq(screen.player.cards.size(), owned + 1)
	assert_eq(screen.player.cards[-1], {"card": shown[0], "decks": []})
	assert_true(visit.visible, "the town again")
	# The bug pass of part B (q3-4): what came of the pick is said under the
	# keeper's words (the trader went as it said it).
	assert_string_contains(visit.words(), "%s joins your cards." % shown[0])
	assert_false(Quests.has_quest(screen.player))
	var completed := screen.player.journal.filter(func(e: Dictionary) -> bool:
		return String(e.get("event", "")) == "quest" and bool(e.get("done", false)))
	assert_eq(completed.size(), 1, "\"Completed quest at %s\" in the journal")
