extends GutTest
## 0.70.11 campaign, smooth2 #6: arriving in a town hands its shop's cards
## to the card art warmer, read off the shop's record — no dice rolled.

const SAVES := "user://c1126_adv_shop_warm_saves"

var viewport: SubViewport
var screen: WorldScreen


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Probe"
	setup.color = "green"
	setup.difficulty = 1
	setup.seed_text = "12345"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	add_child_autofree(viewport)
	screen = load("res://game/adventure/world/world_screen.tscn").instantiate()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	for i in 3:
		await get_tree().process_frame
	screen.set_process(false)
	screen.player.monsters = [] as Array


func after_each() -> void:
	AdventurePlayer.finish_saves()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER
	AdventurePlayer.forget_saves()


func test_the_shop_s_cards_are_read_off_its_record_and_no_dice_roll() -> void:
	var hero := screen.player
	var town := -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	assert_eq(screen.shop_cards_to_warm(town), [] as Array[String], "nothing drawn yet: nothing asked")
	var dice := hero.dice
	screen.shop_cards_to_warm(town)
	assert_eq(hero.dice, dice, "asking rolls no dice")
	screen._arrive_in_town(town)
	var offered: Array[String] = []
	for card in CardShop.offers(hero, town):
		if card != "" and not offered.has(card):
			offered.append(card)
	assert_gt(offered.size(), 0)
	assert_eq(screen.shop_cards_to_warm(town), offered, "the cards on offer")
	hero.shops[str(town)]["cards"] = "garbled"
	assert_eq(screen.shop_cards_to_warm(town), [] as Array[String], "a garbled record asks nothing")
