extends GutTest
## THE WORLD WARMS THE DECK BUILDER'S PICTURES ([method WorldScreen._warm_the_builder],
## [CardArtWarmer]; the owner, 2026-10-23): a moment after the world opens,
## the hero's cards are decoded in the background, the deck in use first.

var screen: WorldScreen
const SAVES := "user://adventure_tests_warm"


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	screen = WorldScreen.new()
	screen.record = setup.resolve({})
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func test_the_deck_in_use_is_warmed_first() -> void:
	var player := screen.player
	player.cards.append({"card": "Shivan Dragon", "decks": []})
	player.cards.push_front({"card": "Serra Angel", "decks": [1]})
	var names := screen._cards_to_warm()
	var in_use := 0
	for entry in player.cards:
		if (entry["decks"] as Array).has(player.current_deck):
			in_use += 1
	assert_eq(names.size(), player.cards.size(), "every card the hero owns")
	for i in in_use:
		assert_true(_in_deck(names[i]), "%s, of the deck in use, comes first" % names[i])
	assert_eq(names.back(), "Shivan Dragon", "a card in no deck after")
	assert_false(names.slice(0, in_use).has("Serra Angel"), "another deck's card after")
	# The others by name, as the builder's bottom row shows them first
	# (the bug pass after the campaign, r1-2), each once.
	player.cards.append({"card": "Air Elemental", "decks": []})
	player.cards.append({"card": "Air Elemental", "decks": [2]})
	var rest := screen._cards_to_warm().slice(in_use)
	assert_eq(rest, ["Air Elemental", "Serra Angel", "Shivan Dragon"], "by name, each once")


func _in_deck(card_name: String) -> bool:
	for entry in screen.player.cards:
		if entry["card"] == card_name and (entry["decks"] as Array).has(screen.player.current_deck):
			return true
	return false


func test_a_moment_after_opening_the_pictures_are_warmed() -> void:
	screen._warm_the_builder()
	# Under the tree's root, joined at the end of the frame (the bug
	# campaign of 0.50.66, h1-3).
	await get_tree().process_frame
	var warmer := get_tree().root.find_child("CardArtWarmer", false, false) as CardArtWarmer
	# No card art ships: with none on this machine there is nothing to warm.
	if warmer == null:
		assert_true(CardArtWarmer._job_for(screen._cards_to_warm()).paths.is_empty(),
			"no warmer only when every picture is kept or none is found")
		return
	for i in 300:
		if not is_instance_valid(warmer) or warmer.finished():
			break
		await get_tree().process_frame
	assert_true(CardArtWarmer._job_for(screen._cards_to_warm()).paths.is_empty(),
		"every picture found is kept now")
	var builder := screen.show_deck(-1, true)
	assert_not_null(builder, "the spellbook opens on the warmed pictures")
