extends GutTest
## THE IDLE RING POINTED TO NOWHERE (the 0.50.66 bug campaign, h3-2; the
## owner's ruling of 2026-10-29, "Mark them, skip the Ring", and the lead's
## follow-up): with no siege to come and Starting life "Links only", Ring of
## the Guardian is not sold ([method WorldMagicShop.idle]) — so the Info
## Map and the city list do not name it at its town, nor does the wise man's
## news say where it may be found; under "Base 10 + links" (its 3 life
## count) they do. The seller's pane marks Sword of Resistance's and the
## Ring's words "(no sieges in this campaign)" ([method
## WorldMagicPane.tip_words]).

## A world screen that saves nowhere and never leaves for the title.
class Probe extends WorldScreen:
	func _write_autosave() -> String:
		return ""

	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c21_x2_ring"
const RING := "Ring of the Guardian"
const SWORD := "Sword of Resistance"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	TileReveal.forced = 0
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	TileReveal.forced = -1
	var dir := DirAccess.open(SAVES)
	if dir != null:
		for file_name in dir.get_files():
			dir.remove(file_name)
		DirAccess.remove_absolute(SAVES)
	AdventurePlayer.saves_folder = AdventurePlayer.SAVES_FOLDER


func _frames(count := 2) -> void:
	for i in count:
		await get_tree().process_frame


## A green hero's world (seed 12345, Apprentice) with the sieges' pace
## [param sieges] and Starting life [param life_start].
func _world(sieges: String, life_start := AdventurePlayer.START_LINKS) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		await _frames(2)
	var setup := AdventureSetup.new()
	setup.player_name = "Ring Seeker"
	setup.color = "green"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.sieges = sieges
	setup.life_start = life_start
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.monsters = [] as Array
	screen.player.gold = 5000


## The town that sells Ring of the Guardian.
func _ring_town() -> int:
	return WorldMagicShop.seller(screen.world, AdventurePlayer.WORLD_MAGICS.find(RING))


## Every word on the city list's rows, the Ring's town shown.
func _city_list_words(town: int) -> Array[String]:
	TownStatus.put(screen.world, town, TownStatus.VISITED)
	var list := screen.show_city_list()
	assert_not_null(list, "the city list")
	var out: Array[String] = []
	if list == null:
		return out
	await _frames(2)
	assert_true(WorldNames.site_name(screen.world, town) in list.shown(), "control: the town on the list")
	for line in list.find_child("Rows", true, false).find_children("*", "Label", true, false):
		out.append((line as Label).text)
	list.done.emit()
	await _frames(2)
	return out


## Whether the wise man's news names the Ring, over [param tries] dice.
func _news_names_the_ring(tries := 600) -> bool:
	for seed_value in range(1, tries + 1):
		if RING in WiseMan._news(screen.player, MsvcRandom.new(seed_value)):
			return true
	return false


func test_with_no_siege_to_come_the_ring_is_pointed_to_nowhere() -> void:
	await _world(AdventurePlayer.SIEGES_STEADY)
	var town := _ring_town()
	assert_gt(town, 0, "the Ring is sold somewhere in this world")
	if town <= 0:
		return
	assert_true(RING in screen._map.info_words(town), "control: Steady, the Info Map names it")
	assert_true(RING in await _city_list_words(town), "control: and the city list")
	assert_true(_news_names_the_ring(), "control: and the wise man may tell of it")
	await _world(AdventurePlayer.SIEGES_NONE)
	assert_false(RING in screen._map.info_words(town), "None, Links only: not on the Info Map")
	assert_eq(screen._map.info_words(town).size(), 1, "its town: what it trades alone")
	assert_false(RING in await _city_list_words(town), "not on the city list")
	assert_false(_news_names_the_ring(), "nor in the wise man's news")


func test_under_base_10_and_links_the_ring_is_pointed_to() -> void:
	await _world(AdventurePlayer.SIEGES_NONE, AdventurePlayer.START_BASE)
	var town := _ring_town()
	assert_gt(town, 0)
	if town <= 0:
		return
	assert_true(RING in screen._map.info_words(town), "its 3 life count: the Info Map names it")
	assert_true(RING in await _city_list_words(town), "the city list")
	assert_true(_news_names_the_ring(), "the wise man may tell of it")


# ------------------------------------------------------- the seller's pane --

func _seller_words(offer: Dictionary) -> String:
	screen.open_magic_seller(offer)
	await _frames(2)
	var pane := screen.find_child("WorldMagicPane", true, false) as WorldMagicPane
	assert_not_null(pane, "the seller's pane")
	if pane == null:
		return ""
	var out: Array[String] = []
	for line in pane.find_children("*", "Label", true, false):
		out.append((line as Label).text)
	pane.done.emit()
	await _frames(2)
	return "\n".join(out)


func test_the_seller_s_pane_marks_the_ring_and_the_sword() -> void:
	await _world(AdventurePlayer.SIEGES_STEADY, AdventurePlayer.START_BASE)
	var ring := AdventurePlayer.WORLD_MAGICS.find(RING)
	var sword := AdventurePlayer.WORLD_MAGICS.find(SWORD)
	var steady := await _seller_words({"index": ring, "name": RING, "price": 600, "here": false,
		"direction": "North", "seller_name": "Kraag Temple", "afford": true})
	assert_string_contains(steady, "(The wizards now need 5 mana taps to cast Dominion.)", "control: the 1997 words")
	assert_false("no sieges" in steady, "control: Steady, unmarked")
	await _world(AdventurePlayer.SIEGES_NONE, AdventurePlayer.START_BASE)
	var town := _ring_town()
	var offer := WorldMagicShop.offer(screen.player, town) if town > 0 else {}
	assert_eq(String(offer.get("name", "")), RING, "Base 10 + links: its own town offers it")
	var none := await _seller_words(offer)
	assert_string_contains(none,
		"(The wizards now need 5 mana taps to cast Dominion.) (no sieges in this campaign)", "marked")
	var sword_words := await _seller_words({"index": sword, "name": SWORD, "price": 300, "here": false,
		"direction": "North", "seller_name": "Kraag Temple", "afford": true})
	assert_string_contains(sword_words,
		"(Risk one white amulet to reach a city under siege.) (no sieges in this campaign)",
		"the Sword, still sold to a green hero, marked")
	assert_eq(WorldMagicPane.tip_words("Leap of Fate", screen.player),
		"(Risk one blue amulet to instantly cross any distance.)", "the others as they were")
