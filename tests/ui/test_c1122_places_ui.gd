extends GutTest
## PLACES, API 3, ON THE WORLD SCREEN (the places campaign of 2026-11-22):
## a talk's pane, a roll and a duel pressed through the screen's own visit
## pane. The duel is the adventure's duel host's: its stake is in the save
## made as it begins, nothing is saved under it (the owner's ruling 4, as
## the review of 2026-11-21 held every duel to), and its result comes once.

const INN := preload("res://tests/support/c1122_places_fixture.gd")
const ROOT := "user://c1122_places_ui_tests"
const SAVES := "user://c1122_places_ui_saves"


class Probe extends WorldScreen:
	var saves := 0
	var gold_at_save: Array = []
	var uses_at_save: Array = []

	func _board_seed() -> int:
		return 4242

	func _write_autosave() -> String:
		saves += 1
		gold_at_save.append(player.gold)
		uses_at_save.append(JSON.stringify(player.sites))
		return super()

	func _go_to_title() -> void:
		_leaving = true


var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	INN.install(ROOT, INN.sites())
	AdventurePlugins.folders_override = [ROOT] as Array[String]
	AdventurePlugins.scan()
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.adventures = ["inn"] as Array[String]
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.monsters = [] as Array
	screen.player.cards = []
	for card_name in ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest", "Forest",
			"Giant Growth", "Giant Growth", "Giant Growth", "Giant Growth", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears", "Grizzly Bears"]:
		screen.player.cards.append({"card": card_name, "decks": [0]})
	screen.player.current_deck = 0
	screen.player.gold = 500
	screen.saves = 0
	screen.gold_at_save = []
	screen.uses_at_save = []


func after_each() -> void:
	await _frames()
	AdventurePlayer.finish_saves()
	TileReveal.forced = -1
	INN.remove(SAVES)
	INN.remove(ROOT)
	AdventurePlugins.folders_override = [] as Array[String]
	AdventurePlugins.scan()
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


func inn() -> DataSites:
	return AdventureSites.provider("inn")


## The button of the open pane whose id ends with [param tail], pressed.
func _press(tail: String) -> void:
	var pane: VisitPane = screen._visit
	assert_not_null(pane, "a pane is open for " + tail)
	if pane == null:
		return
	for action: Array in pane.place.get("actions", []):
		if String(action[0]).ends_with(tail):
			pane.choose(String(action[0]))
			await _frames(2)
			return
	fail_test("the pane has no button %s: %s" % [tail, str(pane.place.get("actions", []))])


func _report(result: int) -> DuelReport:
	var report := DuelReport.new()
	report.finished = true
	report.result = result
	report.winner = 0 if result == DuelReport.WIN else 1
	var start: Array[int] = [12, 12]
	var end: Array[int] = [9, 0]
	if result != DuelReport.WIN:
		end = [0, 7] as Array[int]
	report.lives_start = start
	report.lives_end = end
	return report


func test_the_inn_stands_on_the_map_and_opens_by_its_tile() -> void:
	assert_true(AdventureSites.on(screen.player, "inn"), "control: the plugin is part of the campaign")
	var point: Array = screen.world.expansion[AdventureSites.KEY]["inn:inn"]
	var pane := screen.visit(Vector2i(int(point[0]), int(point[1])))
	assert_not_null(pane)
	if pane != null:
		assert_eq(String(pane.place["name"]), "The Inn")
		assert_eq(String(pane.place["kind"]), "site")


func test_a_talk_a_roll_and_a_duel_through_the_visit_pane() -> void:
	screen.open_place(inn().describe(screen.player, "inn"))
	await _frames(2)
	# A talk: its pane, nothing saved.
	await _press(":inn:ask")
	assert_eq(String(screen._visit.place["pane"]), "rumors")
	assert_eq(String(screen._visit.place["lines"][0]), "Rumor A.")
	assert_eq(screen.saves, 0, "a talk that only opens its pane saves nothing")
	assert_true(screen.visiting())
	await _press("_leave")
	assert_false(screen.visiting(), "and its pane can be left")
	# A roll: paid, saved, its outcome's line shown.
	screen.open_place(inn().describe(screen.player, "inn"))
	await _frames(2)
	await _press(":inn:games")
	assert_eq(String(screen._visit.place["pane"]), "games")
	var saved := screen.saves
	await _press(":inn:gamble")
	var line := String(screen._visit.place["lines"][0])
	assert_true(line in ["You win.", "You lose."], line)
	assert_eq(screen.player.gold, 520 if line == "You win." else 490)
	assert_eq(screen.saves, saved + 1, "saved with the roll's outcome")
	assert_eq(inn().uses(screen.player, "inn", "gamble"), 1)
	await _press("_back:inn")
	assert_eq(String(screen._visit.place["pane"]), "", "Return: the place's own pane")
	# A duel: the stake first, the save, then the duel over the world.
	await _press(":inn:games")
	var gold := screen.player.gold
	await _press(":inn:duel")
	await _frames(3)
	var host := screen.get_node_or_null("WorldDuel") as WorldDuels
	assert_not_null(host, "the duel is dealt over the world")
	if host == null:
		return
	assert_eq(screen.player.gold, gold - 100, "the stake is paid")
	assert_eq(screen.saves, saved + 2, "and the world saved before the duel is dealt")
	assert_eq(screen.gold_at_save[-1], gold - 100, "with the stake paid in it: a duel left is a stake lost")
	assert_eq(host.config.lives[1], 12, "the plugin's foe, never scaled")
	assert_eq(host.foe, "The Champion")
	screen.notification(Node.NOTIFICATION_WM_CLOSE_REQUEST)
	assert_eq(screen.saves, saved + 2, "the window closed over the duel: nothing saved (ruling 4)")
	assert_eq(inn().counter(screen.player, "wins"), 0, "and nothing won")
	host._finish(_report(DuelReport.WIN))
	await _frames(3)
	assert_eq(screen.player.gold, gold + 200, "the win's 300 gold")
	assert_eq(inn().counter(screen.player, "wins"), 1)
	assert_eq(screen.saves, saved + 3, "saved with the result")
	assert_eq(screen.gold_at_save[-1], gold + 200)
	assert_not_null(screen._visit, "the result's pane")
	if screen._visit != null:
		assert_eq(screen._visit.place["lines"], ["Well fought; 1 wins."])
	assert_eq(inn().duel_begin(screen.player, "inn", "duel"), -1, "won once: the prize is not had twice")
	assert_eq(screen.player.duel_record()["won"], 0, "a place's duel is the plugin's event, not the hero's record")
	await _press("_leave")
	assert_false(screen.modal(), "nothing left holding the world")


func test_a_duel_refused_pays_nothing_and_deals_no_duel() -> void:
	screen.player.gold = 40
	screen.open_place(inn().describe(screen.player, "inn", "games"))
	await _frames(2)
	await _press(":inn:duel")
	assert_null(screen.get_node_or_null("WorldDuel"))
	assert_eq(screen.player.gold, 40)
	assert_string_contains(String(screen._visit.place["lines"][0]), "You need 100 gold")
	assert_eq(screen.saves, 0)


func test_a_card_is_bought_from_the_list() -> void:
	screen.open_place(inn().describe(screen.player, "inn", "shop"))
	await _frames(2)
	await _press(":inn:buy")
	var list: CardListPane = screen._card_list
	assert_not_null(list, "the card list over the pane")
	if list == null:
		return
	var price := CardShop.sell_range("Grizzly Bears").y
	assert_eq(int(list.cards.get("Grizzly Bears", -1)), price, "the number beside a card is its price")
	assert_true(list.cards.has("Black Lotus"))
	list.picked.emit("Grizzly Bears")
	await _frames(2)
	assert_eq(screen.player.gold, 500 - price)
	assert_eq(DataSites.held(screen.player, "Grizzly Bears"), 5)
	assert_string_contains(String(screen._visit.place["lines"][0]), "Grizzly Bears is yours for %d gold." % price)
	assert_eq(screen.saves, 1)
