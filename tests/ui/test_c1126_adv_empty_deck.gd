extends GutTest
## 0.70.11 campaign, bugs3 #1: Done in a town's deck builder (and in the
## Final Battle's) on a deck with no spell brings the builder up again on a
## deck that plays, saying so; the next creature is a meeting, not the end.

const SAVES := "user://c1126_adv_empty_deck_saves"

var viewport: SubViewport
var screen: WorldScreen


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	AdventureFinale.movie_forced = 0
	var setup := AdventureSetup.new()
	setup.player_name = "Probe"
	setup.color = "red"
	setup.difficulty = 1
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	AdventureFinale.movie_forced = -1
	AdventurePlayer.finish_saves()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func _town_tile() -> Vector2i:
	for site in screen.world.sites:
		if int(site["type"]) == ShandalarWorld.TOWN:
			return Vector2i(int(site["x"]), int(site["y"]))
	return Vector2i(-1, -1)


func test_done_on_an_empty_slot_in_a_town_comes_back_on_the_deck_that_plays() -> void:
	var hero := screen.player
	var pane := screen.visit(_town_tile())
	await _frames(2)
	pane.choose("deck")
	await _frames(6)
	var builder: AdventureBuilder = screen._builder
	assert_not_null(builder)
	builder._switch_slot(1)
	await _frames(2)
	builder._exit()
	await _frames(6)
	assert_true(screen.building(), "the builder is up again")
	var again: AdventureBuilder = screen._builder
	assert_ne(again, builder, "a new builder")
	assert_false(again.looking, "the decks may be changed")
	assert_eq(again._slot, 0, "deck 1 on show")
	assert_eq(hero.current_deck, 0, "and in use")
	assert_string_contains(again._status_label.text, DeckRescue.SWITCHED % [2, 1])
	assert_string_contains(again._status_label.text, WorldScreen.DECK_RESCUED)
	assert_false(CreatureMeeting.usable_cards(hero).is_empty())
	again._exit()
	await _frames(6)
	assert_false(screen.building(), "Done keeps it")
	assert_true(screen.visiting(), "the town again")
	assert_eq(hero.current_deck, 0)
	assert_eq(hero.deck_note, "", "said in the builder, not again beside the panel")


func test_a_creature_met_with_an_empty_slot_in_use_is_a_meeting_not_the_end() -> void:
	var hero := screen.player
	hero.current_deck = 2
	var row := CreatureBook.pick(MsvcRandom.new(9), 4, 4)
	var at := hero.position + Vector2i(8, 0)
	hero.monsters = [{"slot": 1, "kind": "creature", "creature": row, "x": at.x, "y": at.y, "color": 4,
		"heading": 7, "frame": 0}]
	var meeting := screen.meet_creature(1)
	await _frames(4)
	assert_not_null(meeting)
	assert_false(screen.lost(), "the adventure goes on")
	assert_false(screen.ended())
	assert_eq(hero.current_deck, 0, "deck 1 in use")
	assert_eq(hero.deck_note, "", "said beside the panel")


func test_the_final_battle_s_builder_comes_back_on_a_deck_that_plays() -> void:
	var hero := screen.player
	hero.defeated_wizards.assign(AdventurePlayer.COLORS)
	AdventureFinale.after_fifth_wizard(screen, hero)
	await _frames()
	var finale := AdventureFinale.showing(screen)
	finale._shown_at -= 100000
	finale.choose("face")
	finale._shown_at -= 100000
	finale.go_on()
	await _frames(4)
	assert_eq(finale.step, AdventureFinale.BUILDER)
	var builder := finale.builder
	builder._switch_slot(2)
	await _frames(2)
	builder._exit()
	await _frames(6)
	assert_eq(finale.step, AdventureFinale.BUILDER, "no battle with forty lands")
	assert_true(is_instance_valid(finale.builder) and finale.builder != builder, "the builder again")
	assert_eq(hero.current_deck, 0)
	assert_eq(finale.builder._slot, 0)
	assert_string_contains(finale.builder._status_label.text, DeckRescue.SWITCHED % [3, 1])
	assert_string_contains(finale.builder._status_label.text, AdventureFinale.BUILDER_SAYS)
	finale.builder._exit()
	await _frames(6)
	assert_eq(finale.step, AdventureFinale.BATTLE, "Done again: the battle")
	assert_true((finale.duel.config.decks[0] as Array).any(func(card: String) -> bool:
		return not card in CreatureDeck.BASICS), "spells in the hero's deck")
