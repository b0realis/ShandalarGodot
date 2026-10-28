extends GutTest
## A BEATEN WIZARD'S CREATURES (part C stage C3):
##  - h2-2: the quest's creature keeps coming into slot 0 when its colour's
##    wizard is beaten — the beaten colour's gate turned it away every
##    time, and the quest failed at its deadline — and the castle's win
##    ([method Sieges.free_all]) leaves it on the map;
##  - h4-3 (the owner, 2026-10-28, [ours]): such a creature — its wizard's
##    castle beaten, or the world at peace — says the fallen-master line,
##    not 1997's "domain of the Mighty …" (nor, with five wins, "tremble in
##    fear"); near a castle and as a henchman it speaks as before.

const HERO := Vector2i(20, 20)
const WHITE := 6
## The Cleric: white, tier 4.
const CLERIC := 8
const FALLEN_WHITE: Array[String] = ["The White Wizard has fallen,",
	"but his creatures still roam", "these lands.", "Pay, or fight."]
const FALLEN_BLUE: Array[String] = ["The Blue Wizardess has fallen,",
	"but her creatures still roam", "these lands.", "Pay, or fight."]
## The tribute's (the owner, 2026-10-28: "fallen + tremble").
const TRIBUTE_WHITE: Array[String] = ["The White Wizard has fallen,",
	"and his creatures tremble", "before you.", "Accept our tribute."]


## A world of white plains, the hero in its middle, every slot's respawn
## long past (tests/unit/test_b_w4_world_creatures.gd's).
func _player() -> AdventurePlayer:
	var world := ShandalarWorld.new()
	world.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			world.page[y * ShandalarWorld.PAGE_WIDTH + x] = WHITE
	for i in 8:
		world.lair_respawn.append(-1000000)
	var player := AdventurePlayer.new()
	player.world = world
	player.difficulty = 1
	player.position = HERO * 32 + Vector2i(16, 16)
	player.monster_timer = 1000
	player.dice = 4242
	return player


# ---------------------------------------------------------------- h2-2 --

func _quest_fills(player: AdventurePlayer) -> int:
	var came := 0
	var dice := MsvcRandom.new(7)
	for i in 400:
		player.monsters = []
		WorldLairs.fill(player, 0, dice)
		var held := WorldLairs.held_in(player, 0)
		if WorldCreatures.is_creature(held):
			assert_eq(int(held["creature"]), CLERIC, "only the quest's creature")
			assert_eq(int(held["color"]), 5, "in its own colour")
			came += 1
	return came


func test_the_quest_s_creature_comes_when_its_wizard_is_beaten() -> void:
	var player := _player()
	player.quest = {"type": -CLERIC, "destination": 0, "giver": 0, "color": 5}
	var unbeaten := _quest_fills(player)
	assert_gt(unbeaten, 0, "it comes")
	player.defeated_wizards.append("white")
	assert_eq(_quest_fills(player), unbeaten, "as often, the White Wizard beaten")
	# Any other white creature is still turned away from the other slots.
	var dice := MsvcRandom.new(5)
	for i in 300:
		player.monsters = []
		WorldLairs.fill(player, 1, dice)
		var held := WorldLairs.held_in(player, 1)
		if WorldCreatures.is_creature(held):
			assert_ne(int(held["color"]), 5, "no other creature of the beaten colour")


func test_the_castle_s_win_leaves_the_quest_s_creature_on_the_map() -> void:
	var player := _player()
	player.quest = {"type": -CLERIC, "destination": 0, "giver": 0, "color": 5}
	var at := player.position + Vector2i(64, 0)
	player.monsters = [
		{"slot": 0, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y, "color": 5},
		{"slot": 2, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y + 32, "color": 5},
		{"slot": 3, "kind": "creature", "creature": 34, "x": at.x, "y": at.y + 64, "color": 4},
		{"slot": Sieges.SLOT, "kind": "creature", "creature": CLERIC, "x": at.x, "y": at.y + 96,
			"color": 5, "town": 0},
	]
	player.siege_active = true
	Sieges.free_all(player, 5)
	var left := []
	for held in player.monsters:
		left.append(int(held["slot"]))
	assert_eq(left, [0, 2, 3], "the quest's creatures stay, the besieger goes")
	assert_false(player.siege_active, "the siege over")
	player.quest = {}
	Sieges.free_all(player, 5)
	assert_eq(player.monsters.size(), 1, "no quest: his creatures all go")


# ---------------------------------------------------------------- h4-3 --

func _meeting(color: int, wins := 0, relation := CreatureMeeting.NONE, row := CLERIC) -> Dictionary:
	return {"color": color, "kind": CreatureBook.kind(row), "relation": relation, "wins": wins,
		"row": row, "town": -1, "at": Vector2i(0, 0)}


func test_a_beaten_wizard_s_creature_says_its_master_has_fallen() -> void:
	var player := _player()
	assert_eq(CreatureMeeting.words(player, _meeting(5))[1], "of the Mighty White Wizard", "1997's, unbeaten")
	player.defeated_wizards.append("white")
	assert_eq(CreatureMeeting.words(player, _meeting(5)), FALLEN_WHITE, "his castle beaten")
	assert_eq(CreatureMeeting.words(player, _meeting(5, CreatureMeeting.TRIBUTE_WINS)), TRIBUTE_WHITE,
		"its tribute: fallen, and trembling")
	assert_eq(CreatureMeeting.words(player, _meeting(2))[1], "of the Mighty Blue Wizardess",
		"another colour's wizard still rules")
	player.ended = AdventurePlayer.ENDED_WON
	assert_eq(CreatureMeeting.words(player, _meeting(2)), FALLEN_BLUE, "the world at peace: hers too")


func test_near_his_ruins_a_creature_meets_the_hero_as_anywhere_else() -> void:
	var player := _player()
	for c in 5:
		player.world.encounters.append({"x": 10 + c * 8, "y": 10})
	var near := Vector2i((10 + 4 * 8) * 32 + 16, 11 * 32 + 16)
	assert_eq(CreatureMeeting.relation_of(player, CLERIC, 5, 1, near), CreatureMeeting.STRONGHOLD,
		"control: near an unbeaten wizard's castle, his stronghold")
	player.defeated_wizards.append("white")
	assert_eq(CreatureMeeting.relation_of(player, CLERIC, 5, 1, near), CreatureMeeting.NONE,
		"the owner: ruins are no stronghold")
	assert_eq(CreatureMeeting.relation_of(player, CLERIC, 4, 1, Vector2i((10 + 3 * 8) * 32, 10 * 32)),
		CreatureMeeting.STRONGHOLD, "another wizard's castle still is")
	assert_eq(CreatureMeeting.relation_of(player, CLERIC, 5, CreatureMeeting.SIEGE_SLOT, near),
		CreatureMeeting.SIEGE, "the besieger keeps its own relation")


func test_near_a_castle_and_as_a_henchman_the_words_are_1997_s() -> void:
	var player := _player()
	player.defeated_wizards.append("white")
	assert_eq(CreatureMeeting.words(player, _meeting(5, 0, CreatureMeeting.STRONGHOLD))[0],
		"Those who near the stronghold")
	assert_eq(CreatureMeeting.words(player, _meeting(5, 0, CreatureMeeting.NONE, 6))[0], "The Evil White Wizard",
		"the Necromancer, a henchman")
