extends GutTest
## THE DUELS' STARTING LIFE SHOWN (builder A1 of 0.50.65): under the
## Campaign Settings' "Base 10 + links" the pre-duel purse's life (every
## meeting's, lair's, ruled town's page; a dungeon room's shows its own run's
## life, [method DungeonDuels.hero_life]), the hero's panel and the ankh's
## tip say the life duels start from ([method
## AdventurePlayer.duel_start_life]); under "Links only" they read as
## before.

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Life Reader"
	setup.color = "red"
	setup.seed_text = "2468"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))


func _purse_life() -> String:
	var stage := EncounterStage.new()
	add_child_autofree(stage)
	stage.purse(player)
	return (stage.part("Life") as Label).text


func _shows(text: String, life: int) -> bool:
	return text == str(life) or text == "Life %d" % life


func test_the_purse_shows_the_life_duels_start_from() -> void:
	var links := player.mana_links()
	assert_true(_shows(_purse_life(), links), "links only: the links, as 1997")
	player.life_start = AdventurePlayer.START_BASE
	assert_true(_shows(_purse_life(), 10 + links), "base 10 + links")
	player.world_magics.append("Fruit of Sustenance")
	assert_true(_shows(_purse_life(), 15 + links), "and the World Magics' bonuses")


func test_the_hero_panel_and_the_ankh_say_it() -> void:
	var hud := WorldHud.new()
	autofree(hud)
	hud.player = player
	var said := "\n".join(hud.hero_lines())
	assert_false(said.contains("Your duels start at"), "links only: nothing more")
	assert_false(hud.tip_for("strip:ankh")[1].contains("start at"))
	player.life_start = AdventurePlayer.START_BASE
	said = "\n".join(hud.hero_lines())
	assert_string_contains(said, "Your duels start at %d life." % (10 + player.mana_links()))
	assert_string_contains(hud.tip_for("strip:ankh")[1], "Your duels start at %d life." % (10 + player.mana_links()))
	var coin := AdventurePlayer.WORLD_MAGICS.find("Haggler's Coin")
	assert_string_contains(hud.tip_for("magic:%d" % coin)[1], "adds 2 life to every duel")
	var sword := AdventurePlayer.WORLD_MAGICS.find("Sword of Resistance")
	assert_false(hud.tip_for("magic:%d" % sword)[1].contains("life to every duel"), "not a life item")
