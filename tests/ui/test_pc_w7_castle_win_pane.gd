extends GutTest
## A WIZARD BEATEN IN HIS CASTLE, THE PANE (part C, stage C2, W7):
## [CastleWinPane] — the contract (`make`, `finished(picked)` once, the
## pane gone after), the pages in order (his room, the words over the
## trade backdrop with the news line, the three picks, the cards taken), the
## picks (his colour's cards, a card taken not offered again, Yes takes it
## into no deck, No and Escape put it back, no Done), a full bag said and
## its picks not offered, a wizard beaten before shown with no picks, his
## castle's tune, and the pane on the window at 1280 × 800 and 800 × 600,
## with and without the Big buttons.

var base: Dictionary
var player: AdventurePlayer
var viewport: SubViewport
var done: Array = []


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Liberator"
	setup.color = "white"
	setup.difficulty = 1
	setup.walker = "female"
	setup.seed_text = "90210"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.siege_active = false
	for slot in player.world.sites.size():
		TownStatus.release(player.world, slot)
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	done = []


func _frames(count := 3) -> void:
	for i in count:
		await get_tree().process_frame


## The first [param count] towns ruled by wizard [param wizard].
func _rule(wizard: int, count: int) -> Array[int]:
	var out: Array[int] = []
	for slot in player.world.sites.size():
		if out.size() < count and TownStatus.is_town(player.world, slot):
			TownStatus.take(player.world, slot, wizard)
			out.append(slot)
	return out


func _open(record: Dictionary, k := 1.0) -> CastleWinPane:
	var pane := CastleWinPane.make(player, record)
	assert_false(pane.is_inside_tree(), "make: not yet in the tree")
	pane.k = k
	pane.finished.connect(func(picked: Array[String]) -> void: done.append(picked))
	viewport.add_child(pane)
	PaneStyle.centre(pane)
	await _frames()
	return pane


func _key(code: Key) -> void:
	var down := InputEventKey.new()
	down.keycode = code
	down.physical_keycode = code
	down.pressed = true
	viewport.push_input(down, true)
	var up := down.duplicate() as InputEventKey
	up.pressed = false
	viewport.push_input(up, true)
	await _frames()


## The tune [param key] the pane plays: none with the music off, or without
## the 1997 skin that holds it (the gate runs with no skin).
func _tune(key: String) -> String:
	return key if Settings.music_enabled() and GameSkin.sound(key) != null else ""


# ------------------------------------------------------------- the pages --

func test_his_room_then_the_words_with_the_news_then_the_picks() -> void:
	var towns := _rule(4, 2)
	var record := CastleWin.beat(player, 3)
	var pane := await _open(record)
	assert_eq(pane.step, "room", "his room first")
	assert_eq(pane.stage.ground_key(), "wizards_room_red", "statwin's still of his room")
	assert_eq(pane.words(), CastleWinPane.BEATEN % "Red Wizardess")
	assert_eq(pane.title_text(), WorldNames.dungeon_name(3))
	assert_eq(pane.music_key(), _tune("music_castle_red"), "his castle's tune")
	assert_eq(pane.choice_ids(), ["continue"] as Array[String])
	pane.choose("continue")
	assert_eq(pane.step, "words")
	assert_eq(pane.stage.ground_key(), "card_browser", "the trade backdrop (Tradscrn)")
	var words := (pane.stage.part("CastleWords") as Label).text
	assert_eq(words, "\n".join(PackedStringArray(record["lines"])), "1997's words, each town freed")
	assert_string_contains(words, WorldNames.site_name(player.world, towns[0]) + " freed!")
	var take := pane.stage.part("TakeWords") as Label
	assert_eq(take.text, "You may take any three\ndifferent Red cards.")
	assert_eq(take.get_theme_font_size("font_size"),
		(pane.stage.part("CastleWords") as Label).get_theme_font_size("font_size"), "one size, one face")
	var names: Array[String] = []
	for town in towns:
		names.append(WorldNames.site_name(player.world, town))
	assert_eq(pane.words(), CastleWinPane.NEWS_TOWNS % [CastleWinPane.joined(names), "are", "Red Wizardess"],
		"the news line: the towns freed, his creatures gone")
	pane.choose("continue")
	assert_eq(pane.step, "pick")
	assert_false(pane.page_shown(), "the picks stand in the page's place")
	assert_eq(pane.title_text(), "Pick a card - 3 left")
	assert_eq(pane.shown(), CastleWin.offered(player, [], 4), "every red card a trade may give")
	assert_eq(pane.choice_ids(), ["yes", "no"] as Array[String], "no Done: no way to skip")
	assert_true(pane.choice("yes").disabled, "nothing chosen yet")
	assert_eq(done, [], "not finished")


func test_three_picks_each_taken_not_offered_again_then_the_cards_taken() -> void:
	var record := CastleWin.beat(player, 3)
	var pane := await _open(record)
	pane.choose("continue")
	pane.choose("continue")
	var had := player.cards.size()
	var first := pane.shown()[0]
	pane.choose_card(first)
	assert_eq(pane.words(), CastleWin.TAKE_THIS, "Will you take this card...")
	assert_false(pane.choice("yes").disabled)
	pane.choose("no")
	assert_eq(pane.chosen, "", "No: the same pick again")
	assert_eq(player.cards.size(), had)
	pane.choose_card(first)
	await _key(KEY_ESCAPE)
	assert_eq(pane.chosen, "", "Escape puts the card back, the pane stays")
	assert_eq(pane.step, "pick")
	pane.choose_card(first)
	pane.choose("yes")
	assert_eq(player.cards.size(), had + 1, "taken")
	var entry: Dictionary = player.cards[-1]
	assert_eq(String(entry["card"]), first)
	assert_eq(entry["decks"], [], "in no deck")
	assert_eq(pane.title_text(), "Pick a card - 2 left")
	assert_false(first in pane.shown(), "different: a card taken is not offered again")
	assert_eq(pane.note(), "%s joins your cards." % first)
	pane.choose_card(pane.shown()[0])
	pane.choose("yes")
	pane.choose_card(pane.shown()[0])
	pane.choose("yes")
	assert_eq(pane.step, "taken", "the three taken, shown")
	assert_eq(pane.stage.ground_key(), "win_back_cards")
	assert_eq(pane.stage.cards_shown(), pane.picked)
	assert_eq(pane.picked.size(), 3)
	assert_eq(done, [], "not yet")
	pane.choose("continue")
	assert_eq(done.size(), 1, "finished once")
	assert_eq(done[0], pane.picked)
	assert_false(pane.is_inside_tree(), "the pane takes itself away")
	assert_eq(pane.music_key(), "", "the tune stopped")


func test_a_full_bag_is_said_and_its_picks_not_offered() -> void:
	while player.cards.size() < AdventurePlayer.BAG_MOST:
		player.cards.append({"card": "Plains", "decks": []})
	var record := CastleWin.beat(player, 0)
	var pane := await _open(record)
	pane.choose("continue")
	pane.choose("continue")
	assert_eq(pane.step, "bag_full", "no list whose pick would vanish")
	var said := (pane.stage.part("BagFull") as Label).text
	assert_string_contains(said, AdventurePlayer.BAG_FULL)
	assert_string_contains(said, CastleWinPane.PICKS_LOST_MANY % 3)
	assert_eq(player.cards.size(), AdventurePlayer.BAG_MOST, "nothing added")
	await _key(KEY_ENTER)
	assert_eq(done, [[]], "finished with nothing picked")


func test_room_for_one_pick_takes_one_and_says_the_rest_are_lost() -> void:
	while player.cards.size() < AdventurePlayer.BAG_MOST - 1:
		player.cards.append({"card": "Plains", "decks": []})
	var pane := await _open(CastleWin.beat(player, 2))
	pane.choose("continue")
	pane.choose("continue")
	pane.choose_card(pane.shown()[0])
	pane.choose("yes")
	assert_eq(pane.step, "bag_full")
	assert_string_contains((pane.stage.part("BagFull") as Label).text, CastleWinPane.PICKS_LOST_MANY % 2)
	pane.choose("continue")
	assert_eq(pane.step, "taken", "the one taken shown")
	pane.choose("continue")
	assert_eq(done.size(), 1)
	assert_eq((done[0] as Array).size(), 1)


func test_no_towns_freed_says_his_creatures_left() -> void:
	var pane := await _open(CastleWin.beat(player, 1))
	pane.choose("continue")
	assert_eq(pane.words(), CastleWinPane.NEWS_NONE % "Blue Wizardess")


func test_a_wizard_beaten_before_shows_no_picks() -> void:
	CastleWin.beat(player, 4)
	var again := CastleWin.beat(player, 4)
	assert_true(bool(again["already"]))
	var pane := await _open(again)
	pane.choose("continue")
	assert_eq(pane.step, "words")
	assert_null(pane.stage.part("TakeWords"), "no picks to offer")
	pane.choose("continue")
	assert_eq(done, [[]], "finished, nothing picked")


func test_an_empty_record_finishes_at_once() -> void:
	await _open({})
	assert_eq(done, [[]])


func test_escape_and_enter_read_a_page_on() -> void:
	var pane := await _open(CastleWin.beat(player, 3))
	await _key(KEY_ESCAPE)
	assert_eq(pane.step, "words", "Escape reads on, as 1997's key")
	await _key(KEY_ENTER)
	assert_eq(pane.step, "pick", "Enter takes the only choice")


func test_the_type_chips_and_the_name_box_narrow_the_list() -> void:
	var pane := await _open(CastleWin.beat(player, 3))
	pane.choose("continue")
	pane.choose("continue")
	var every := pane.shown()
	(pane.find_child("Chip_Instant", true, false) as Button).button_pressed = true
	var instants := pane.shown()
	assert_true(instants.size() > 0 and instants.size() < every.size(), "fewer: %d of %d" % [instants.size(), every.size()])
	for card_name in instants:
		assert_true(CardRegistry.get_card(card_name).is_type(Mtg.CardType.INSTANT), card_name)
	(pane.find_child("Chip_All", true, false) as Button).button_pressed = true
	assert_eq(pane.shown(), every)
	var search := pane.find_child("PickSearch", true, false) as LineEdit
	search.text = "bolt"
	search.text_changed.emit("bolt")
	for card_name in pane.shown():
		assert_string_contains(card_name.to_lower(), "bolt")


# ------------------------------------------------------------- the fit --

func test_the_pane_fits_the_window_with_and_without_big_buttons() -> void:
	for size in [Vector2i(1280, 800), Vector2i(800, 600)]:
		for k in [1.0, WorldHud.BIG]:
			viewport.size = size
			player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
			_rule(4, 3)
			var pane := await _open(CastleWin.beat(player, 3), k)
			var room := Rect2(Vector2.ZERO, Vector2(size))
			for step in ["room", "words", "pick"]:
				await _frames(4)
				assert_eq(pane.step, step)
				assert_true(room.encloses(pane.get_rect()),
					"%s at k %s, %s: %s inside %s" % [size, k, step, pane.get_rect(), room])
				pane.choose("continue")
			pane.choose_card(pane.shown()[0])
			await _frames(4)
			assert_true(room.encloses(pane.get_rect()), "%s at k %s, asked: %s" % [size, k, pane.get_rect()])
			pane.free()
