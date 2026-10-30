extends GutTest
## A CAMPAIGN WITH NO SIEGES (the 0.50.66 bug campaign): under the Embark's
## Sieges "None" a castle's "Leave?" no longer warns of a siege that cannot
## come (h3-1); and, the owner's ruling of 2026-10-29 ("Mark them, skip the
## Ring", h3-2), the tips of Sword of Resistance and Ring of the Guardian
## say "(no sieges in this campaign)", the shops do not offer the Ring
## unless Starting life is "Base 10 + links" (where its 3 life still
## count), nor does a creature tell where it is sold, and the white hero
## keeps the Sword.

## A world screen whose board is drawn on a known seed, which saves nowhere
## and never leaves for the title.
class Probe extends WorldScreen:
	func _board_seed() -> int:
		return 4242

	func _write_autosave() -> String:
		return ""

	func _go_to_title() -> void:
		_leaving = true


const SAVES := "user://adventure_tests_c21_x2_sieges"
const SWORD := "Sword of Resistance"
const RING := "Ring of the Guardian"

var viewport: SubViewport
var screen: Probe


func before_each() -> void:
	AdventurePlayer.saves_folder = SAVES
	DungeonView.frame_seconds = 0.0
	TileReveal.forced = 0
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 800)
	viewport.gui_disable_input = false
	add_child_autofree(viewport)


func after_each() -> void:
	DungeonView.frame_seconds = DungeonView.FRAME_SECONDS
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


## A world embarked at [param difficulty] with the sieges' pace [param
## sieges], the hero of [param color].
func _world(sieges: String, difficulty := 3, color := "green", life_start := AdventurePlayer.START_LINKS) -> void:
	if screen != null and is_instance_valid(screen):
		screen.queue_free()
		await _frames(2)
	var setup := AdventureSetup.new()
	setup.player_name = "Inniscor"
	setup.color = color
	setup.difficulty = difficulty
	setup.walker = "male"
	setup.seed_text = "12345"
	setup.sieges = sieges
	setup.life_start = life_start
	screen = Probe.new()
	screen.record = setup.resolve({})
	viewport.add_child(screen)
	await _frames(3)
	screen.set_process(false)
	screen.player.food = 50
	screen.player.monsters = [] as Array
	screen.player.cards = []
	for i in 10:
		screen.player.cards.append({"card": "Forest", "decks": [0]})
	for i in 6:
		screen.player.cards.append({"card": "Giant Growth", "decks": [0]})
	for i in 4:
		screen.player.cards.append({"card": "Grizzly Bears", "decks": [0]})
	screen.player.current_deck = 0


func _castle_site(castle: int) -> int:
	for slot in screen.world.sites.size():
		if int(screen.world.sites[slot]["type"]) == ShandalarWorld.CASTLE \
				and DungeonDoors.castle_of(screen.world, slot) == castle:
			return slot
	return -1


## The "Leave?" box's words in castle 0, entered by its door.
func _leave_words() -> String:
	screen._enter_board({"kind": "castle", "slot": _castle_site(0)})
	await _frames(3)
	var pane := screen._board as DungeonPane
	assert_not_null(pane, "the castle's board")
	if pane == null:
		return ""
	if pane.step == "first":
		pane.choose("go")
		await _frames()
	pane.ask_leave()
	var said := pane.box_words()
	pane.choose("stay")
	return said


# ------------------------------------------------ h3-1: the castle's Leave --

func test_leaving_a_castle_under_sieges_none_warns_of_no_siege() -> void:
	await _world(AdventurePlayer.SIEGES_STEADY)
	var steady := await _leave_words()
	assert_string_contains(steady, "may send a siege against you", "control: at Wizard, Steady, it warns")
	await _world(AdventurePlayer.SIEGES_NONE)
	var none := await _leave_words()
	assert_string_contains(none, "Leave ", "the question still asked")
	assert_false("siege" in none, "no siege can come: no warning (%s)" % none)


# --------------------------------------------------- h3-2: the tips --

func _tip(magic: String) -> String:
	var index := AdventurePlayer.WORLD_MAGICS.find(magic)
	var said := screen.hud.tip_for("magic:%d" % index)
	return said[1] if said.size() > 1 else ""


func test_the_siege_magics_tips_are_marked_under_none() -> void:
	await _world(AdventurePlayer.SIEGES_STEADY, 1, "white")
	assert_false(WorldHud.NO_SIEGES in _tip(SWORD), "control: Steady, the Sword unmarked")
	assert_false(WorldHud.NO_SIEGES in _tip(RING), "control: the Ring unmarked")
	await _world(AdventurePlayer.SIEGES_NONE, 1, "white")
	assert_true(screen.player.owns(SWORD), "the white hero keeps the Sword")
	assert_string_contains(_tip(SWORD), "Risk one white amulet to reach a city under siege. (no sieges in this campaign)")
	assert_string_contains(_tip(RING), "(no sieges in this campaign)")
	assert_false(WorldHud.NO_SIEGES in _tip("Leap of Fate"), "the others unmarked")
	assert_eq(WorldHud.magic_tip(RING, screen.player),
		"The wizards now need 5 mana taps to cast Dominion. (no sieges in this campaign)", "for any pane that shows it")
	assert_eq(WorldHud.magic_tip(RING), WorldHud.MAGIC_TIPS[RING], "no campaign: the 1997 words")


# -------------------------------------------------- h3-2: the Ring's shop --

func test_the_ring_is_not_offered_under_none_unless_its_life_counts() -> void:
	var ring := AdventurePlayer.WORLD_MAGICS.find(RING)
	await _world(AdventurePlayer.SIEGES_STEADY, 1)
	var town := WorldMagicShop.seller(screen.world, ring)
	assert_gt(town, 0, "the Ring is sold somewhere")
	if town <= 0 or not WorldMagicShop.asks_at(screen.world, town):
		return
	assert_eq(String(WorldMagicShop.offer(screen.player, town).get("name", "")), RING,
		"control: Steady, its own town offers it")
	assert_true(CreatureMeeting.magic_choices(screen.player).has(ring), "control: a creature tells where")
	await _world(AdventurePlayer.SIEGES_NONE, 1)
	assert_ne(String(WorldMagicShop.offer(screen.player, town).get("name", "")), RING,
		"None: the Ring offered nowhere, its own town either")
	assert_false(CreatureMeeting.magic_choices(screen.player).has(ring), "nor told of")
	assert_true(WorldMagicShop.idle(screen.player, ring))
	assert_false(WorldMagicShop.idle(screen.player, AdventurePlayer.WORLD_MAGICS.find(SWORD)), "the Sword stays")
	await _world(AdventurePlayer.SIEGES_NONE, 1, "green", AdventurePlayer.START_BASE)
	assert_eq(String(WorldMagicShop.offer(screen.player, town).get("name", "")), RING,
		"Base 10 + links: its 3 life count, it is offered")
	assert_true(CreatureMeeting.magic_choices(screen.player).has(ring))
