extends GutTest
## THE MEETINGS' AND THE RULED TOWNS' SCREENS, THE BUG CAMPAIGN c12 (fixer
## F1, 2026-10-27):
##  - h2-3: a reward that gives nothing to say (lives carried with none
##    changed) shows no screen of a title alone over an empty page.
##  - h2-4: a freed town shows the creature's stake won, "Won this card";
##    with the bag full it says the card is lost, as every other source.
##  - the playmat worn in a ruled town's duel as the world screen holds it.
## Clicks through the viewport.

## A world screen that saves nowhere it should not and never leaves.
class Probe extends WorldScreen:
	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c12_f1_panes"

var viewport: SubViewport
var screen: Probe
var town := -1
var results: Array = []


func before_each() -> void:
	RuledTowns.forget()
	AdventurePlayer.saves_folder = SAVES
	var setup := AdventureSetup.new()
	setup.player_name = "Town Freer"
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "97531"
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.player.monsters = [] as Array
	town = -1
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.TOWN:
			town = slot
			break
	_deck()
	results = []


func after_each() -> void:
	RuledTowns.forget()
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func _deck() -> void:
	screen.player.cards = []
	for i in 10:
		screen.player.cards.append({"card": "Forest", "decks": [0]})
	for card_name in ["Llanowar Elves", "Grizzly Bears", "Giant Growth", "Craw Wurm", "Shanodin Dryads",
			"War Mammoth"]:
		screen.player.cards.append({"card": card_name, "decks": [0]})
	screen.player.current_deck = 0


func _full_bag() -> void:
	while screen.player.cards.size() < AdventurePlayer.BAG_MOST:
		screen.player.cards.append({"card": "Plains", "decks": []})


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


func _click(pane: Node, id: String) -> void:
	var button := pane.find_child("Choice_" + id, true, false) as Button
	assert_not_null(button, "a choice %s" % id)
	if button != null:
		_press(button)
	await _frames(3)


# ------------------------------------------------- h2-4: the town freed --

## The ruled town visited, its duel taken and won: the duel's pane at the
## freed picture, and the creature's stake.
func _freed() -> Array:
	TownStatus.take(screen.world, town, 4)
	var site: Dictionary = screen.world.sites[town]
	var pane := screen.visit(Vector2i(int(site["x"]), int(site["y"])))
	await _frames(2)
	var won := String((pane.ruled["creature_ante"] as Array)[0])
	await _click(pane, "duel")
	var duel := screen.find_child("RuledTownPane", true, false) as RuledTownPane
	assert_not_null(duel)
	duel.finished.connect(func(result: int) -> void: results.append(result))
	var host := duel.duel_host()
	assert_not_null(host, "the duel is up")
	assert_eq(host.config.territories[0], screen.player.playmat, "the hero's playmat on their half")
	host.duel.game.concede(1)
	await _frames(3)
	assert_eq(duel.step, "freed")
	return [duel, won]


func test_a_freed_town_shows_the_card_won() -> void:
	var got := await _freed()
	var duel: RuledTownPane = got[0]
	var won: String = got[1]
	var name := WorldNames.site_name(screen.world, town)
	assert_eq(duel.stage.cards_shown(), [won] as Array[String], "the creature's stake on the picture")
	var caption := duel.stage.part("PrizeCardCaption") as Label
	assert_not_null(caption)
	assert_eq(caption.text, RuledTowns.WON_CARD)
	assert_eq(duel.words(), "%s is freed! The people rejoice." % name)
	assert_eq(screen.player.cards[-1], {"card": won, "decks": [0]}, "kept, in the deck in use")
	await _click(duel, "go")
	assert_eq(results, [RuledTowns.WON])


func test_a_full_bag_says_the_freed_town_s_card_is_lost() -> void:
	_full_bag()
	var got := await _freed()
	var duel: RuledTownPane = got[0]
	var won: String = got[1]
	var name := WorldNames.site_name(screen.world, town)
	assert_eq(duel.stage.cards_shown(), [won] as Array[String], "shown")
	assert_null(duel.stage.part("PrizeCardCaption"), "not captioned as won")
	assert_eq(duel.words(), "%s is freed! The people rejoice.\n%s\nLost: %s." % [name, AdventurePlayer.BAG_FULL, won])
	assert_eq(screen.player.cards.size(), AdventurePlayer.BAG_MOST, "lost: the bag full")


# --------------------------------------------- h2-3: no empty reward --

## A special meeting's VampireLord (its reward: the lives carried) beaten
## with the hero's life where it began: nothing carried, so no reward to
## tell — the steps go on to the end without a title-only page.
func test_a_reward_with_nothing_to_say_has_no_screen() -> void:
	for slot in screen.world.encounters:
		(slot as Dictionary)["clues"] = 7   # no dungeon to hint at
	var player := screen.player
	var row := 4
	assert_eq(CreatureBook.reward_flags(row), CreatureBook.REWARD_LIFE_CARRIED, "control: the VampireLord")
	var meeting := CreatureMeeting.meet(player, row, 1)
	meeting["special"] = true
	CreatureMeeting.prepare_duel(player, meeting)
	var pane := EncounterPane.new()
	pane.player = player
	pane.screen = screen
	pane.meeting = meeting
	pane.finished.connect(func(result: int) -> void: results.append(result))
	viewport.add_child(pane)
	await _frames(2)
	var report := DuelReport.new()
	report.finished = true
	report.result = 1
	report.winner = 0
	# Begun and ended at the hero's links, no gift: nothing to carry (the
	# carry counts from the links since the owner's ruling of 2026-10-27,
	# the bug campaign c12 h2-2).
	var links := player.mana_links()
	report.lives_start = [links, 6] as Array[int]
	report.lives_end = [links, 0] as Array[int]
	report.hero_life = links
	pane._after_duel(report)
	assert_eq(int(pane.spoils["bits"]), CreatureBook.REWARD_LIFE_CARRIED, "control: the reward's bit")
	assert_true((pane.spoils["rewards"] as Array).is_empty(), "control: nothing carried, no line")
	var steps: Array[String] = []
	for i in 12:
		if not is_instance_valid(pane) or pane.done():
			break
		steps.append(pane.step)
		pane.choose(pane.choice_ids()[0] if not pane.choice_ids().is_empty() else "go")
		await _frames(1)
	assert_eq(results, [EncounterPane.WON], "the meeting over: %s" % [steps])
	assert_false(steps.has("reward"), "no reward page: %s" % [steps])
