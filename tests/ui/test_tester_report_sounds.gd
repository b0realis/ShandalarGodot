extends GutTest
## THE SHOP HEARD (a play-tester's report, 2026-11-05: *"I liked how you
## have a sound when you add and remove cards to your deck but I didn't
## notice a sound when you sell a card"*): a card sold in a town's deck
## builder plays the world's gold sound ([constant DeckAudio.CUE_SELL]), a
## card bought at the shop the sound of a card found ([method
## WorldSoundscape.card_key]).

const SAVES := "user://adventure_tests_tester_sounds"


## A soundscape that only listens: what the shop asked it to play.
class Ear extends Node:
	var keys: Array[String] = []

	func play(key: String) -> void:
		keys.append(key)


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _record() -> Dictionary:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	return setup.resolve({})


func _town(world: ShandalarWorld) -> int:
	for slot in world.sites.size():
		if int(world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			return slot
	return -1


func test_a_card_sold_is_heard() -> void:
	var screen := WorldScreen.new()
	screen.record = _record()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.player.cards.append({"card": "Mahamoti Djinn", "decks": []})
	var builder := screen.show_deck(_town(screen.world))
	await get_tree().process_frame
	builder._audio.recent.clear()
	assert_gt(builder.sell("Mahamoti Djinn"), 0, "sold")
	assert_eq(builder._audio.recent.count(DeckAudio.CUE_SELL), 1, "and heard, once")
	builder._audio.recent.clear()
	assert_eq(builder.sell("Mahamoti Djinn"), 0, "none left to sell")
	assert_eq(builder._audio.recent.count(DeckAudio.CUE_SELL), 0, "nothing sold, nothing heard")


func test_a_card_bought_is_heard_as_a_card_found() -> void:
	CardRegistry.ensure_loaded()
	var record := _record()
	var player := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	player.gold = 100000
	var slot := _town(player.world)
	var ear := Ear.new()
	ear.add_to_group("world_soundscape")
	add_child_autofree(ear)
	var shop := CardShopPane.new()
	shop.player = player
	shop.slot = slot
	add_child_autofree(shop)
	await get_tree().process_frame
	var offers := CardShop.offers(player, slot)
	var index := -1
	for i in offers.size():
		if offers[i] != "" and CardShop.may_offer(player, offers[i]):
			index = i
			break
	assert_gt(index, -1, "the shelf has a card to buy")
	if index < 0:
		return
	var card_name := offers[index]
	shop.choose(index)
	shop.buy_chosen()
	assert_eq(CardShop.offers(player, slot)[index], "", "bought")
	assert_eq(ear.keys, [WorldSoundscape.card_key(card_name)] as Array[String], "the card's own sound")
	player.gold = 0
	shop.choose(_next_offer(player, slot))
	shop.buy_chosen()
	assert_eq(ear.keys.size(), 1, "a buy refused is not heard")


func _next_offer(player: AdventurePlayer, slot: int) -> int:
	var offers := CardShop.offers(player, slot)
	for i in offers.size():
		if offers[i] != "":
			return i
	return -1
