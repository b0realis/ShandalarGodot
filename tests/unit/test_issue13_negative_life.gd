extends GameTest
## ISSUE #13 (2026-11-11, "Spirit Link Life at End of Duel in Dungeon Not
## Counted"): a Juggernaut wearing two Spirit Links dealt the killing blow
## at 46 life, in the Cave of the Ice Worm, where life carries from room to
## room — and the hero left at 46, not 56. Under the modern rules the duel
## ends the moment the creature's life reaches 0, before the gain of that
## blow resolves (CR 704); the 1997 rule "Negative life is survivable"
## ([RulesOptions], `life_checked_at_phase_end`) checks life as the phase
## ends, and the gain counts. THE OWNER'S RULING (2026-11-13): "Add this
## setting to campaign settings and explain it!" — a Campaign Settings box
## ([member AdventurePlayer.life_checked_at_phase_end]) that plays the 1997
## rule in every duel of the adventure ([method
## CreatureMeeting.campaign_rules], [member DuelConfig.rule_forks], [method
## DuelOpening.prepare]); unticked, the Options decide, as before.

const KEY := "life_checked_at_phase_end"


# ------------------------------------------------------------ the engine --

## The reporter's blow: a Juggernaut wearing two Spirit Links attacks, the
## hero at 46 and the creature at 5.
func _last_blow() -> void:
	var juggernaut := put_battlefield(0, "Juggernaut")
	for i in 2:
		var link := give_hand(0, "Spirit Link")
		advance_to_step(Mtg.Step.MAIN1)
		add_mana(0, Mtg.ManaColor.W)
		assert_ok(g.cast_spell(0, link, [TargetRef.card(juggernaut)]))
		resolve_stack()
	g.players[0].life = 46
	g.players[1].life = 5
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [juggernaut.id]))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)


func test_modern_rules_end_the_duel_before_the_gain() -> void:
	g.rules.life_checked_at_phase_end = false
	_last_blow()
	assert_true(g.game_over, "0 life loses at once")
	assert_eq(g.winner, 0)
	assert_eq(g.players[0].life, 46, "the two gains never resolved: what the reporter saw")


func test_the_1997_rule_counts_the_gain() -> void:
	g.rules.life_checked_at_phase_end = true
	_last_blow()
	assert_false(g.game_over, "at 0 the creature lives until the phase ends")
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN2)
	assert_true(g.game_over, "and loses as combat ends")
	assert_eq(g.winner, 0)
	assert_eq(g.players[0].life, 56, "5 from each Spirit Link")
	assert_eq(DungeonDuels.pool_after(DungeonDuels.CARRY, 0, 46, 56), 10,
		"a dungeon carries the gain to the next room")


# ------------------------------------------------------- the adventure --

func _hero(on: bool) -> AdventurePlayer:
	var setup := AdventureSetup.new()
	setup.player_name = "Ice Worm Delver"
	setup.color = "white"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "1311"
	setup.life_checked_at_phase_end = on
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	hero.monsters = []
	hero.cards = []
	for card_name in ["Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
			"Juggernaut", "Spirit Link", "Spirit Link", "Savannah Lions", "White Knight"]:
		hero.cards.append({"card": card_name, "decks": [0]})
	hero.current_deck = 0
	return hero


## Every kind of adventure duel's config for [param hero]: a meeting's (a
## lair's and a ruled town's come through it), a dungeon room's and
## Arzakon's.
func _configs(hero: AdventurePlayer) -> Dictionary:
	var druid := CreatureBook.row_named("Druid")
	var run := {"index": 13, "castle": false, "color": 3, "rules": DungeonDuels.CARRY,
		"monsters": [druid, 2, 3, 4, 5], "life_pool": 0, "dice_card": "", "card_in_effect": -1}
	return {"meeting": CreatureMeeting.duel_config(hero, CreatureMeeting.meet(hero, 22, 3)),
		"dungeon": DungeonDuels.duel_config(hero, run, DungeonDuels.setup(hero, run, 0)),
		"final battle": FinalBattle.duel_config(hero)}


func test_every_adventure_duel_plays_the_campaign_s_rule() -> void:
	var on := _configs(_hero(true))
	for kind: String in on:
		assert_eq((on[kind] as DuelConfig).rule_forks, {KEY: true}, "%s: the 1997 rule" % kind)
	var off := _configs(_hero(false))
	for kind: String in off:
		assert_eq((off[kind] as DuelConfig).rule_forks, {}, "%s: unticked, the Options decide" % kind)


func test_the_rule_stands_beside_every_adventure_playmat() -> void:
	# Every adventure duel wears the hero's playmat (the c12 feature pass);
	# the plugin lands' duels too — each of those places sets the rule.
	var found := 0
	for path in ["res://game/adventure/creature_meeting.gd", "res://game/adventure/dungeon_duels.gd",
			"res://game/adventure/final_battle.gd", "res://game/adventure/plugins/plugin_journey.gd"]:
		var text := FileAccess.get_file_as_string(path)
		var mats := text.count("hero_playmat(config, player)")
		assert_gt(mats, 0, "%s: a playmat" % path)
		assert_eq(text.count("campaign_rules(config, player)"), mats, "%s: the rule beside it" % path)
		found += mats
	assert_eq(found, 4)


func test_the_opening_plays_the_config_s_forks_over_the_options() -> void:
	var had := Settings.has_value("rule_" + KEY)
	var was := Settings.rule(KEY)
	Settings.set_rule(KEY, false, false)
	var forests: Array = []
	for i in 40:
		forests.append("Forest")
	var config := DuelConfig.new()
	config.decks = [forests.duplicate(), forests.duplicate()]
	var plain := MtgGame.new()
	DuelOpening.prepare(plain, config, 7)
	assert_false(plain.rules.life_checked_at_phase_end, "no fork of its own: the Options' answer")
	config.rule_forks = {KEY: true}
	var campaign := MtgGame.new()
	DuelOpening.prepare(campaign, config, 7)
	assert_true(campaign.rules.life_checked_at_phase_end, "the campaign's rule over the Options")
	assert_eq(campaign.rules.mana_burn, plain.rules.mana_burn, "the other forks stay the Options'")
	config.rule_forks = {KEY: "yes", 3: true, "no_such_fork": true}
	var odd := MtgGame.new()
	DuelOpening.prepare(odd, config, 7)
	assert_false(odd.rules.life_checked_at_phase_end, "a value that is not a switch is no fork")
	if had:
		Settings.set_rule(KEY, was, false)
	else:
		Settings.clear_value("rule_" + KEY)


func test_the_choice_rides_in_the_save() -> void:
	var hero := _hero(true)
	assert_true(hero.life_checked_at_phase_end, "the Embark's record begins the adventure with it")
	var saved: Dictionary = JSON.parse_string(JSON.stringify(hero.to_dict()))
	assert_true(bool(saved["hero"][KEY]))
	assert_true(AdventurePlayer.from_dict(saved).life_checked_at_phase_end, "and a load")
	(saved["hero"] as Dictionary).erase(KEY)
	assert_false(AdventurePlayer.from_dict(saved).life_checked_at_phase_end, "a save from before it: off")
	(saved["hero"] as Dictionary)[KEY] = "yes"
	assert_false(AdventurePlayer.from_dict(saved).life_checked_at_phase_end, "an odd value: off")


func test_the_embark_remembers_it() -> void:
	var setup := AdventureSetup.new()
	assert_false(setup.life_checked_at_phase_end, "off for a new adventure")
	setup.life_checked_at_phase_end = true
	setup.remember()
	assert_true(AdventureSetup.restore([] as Array[String]).life_checked_at_phase_end, "the next visit")
	AdventureSetup.forget()
	assert_false(AdventureSetup.restore([] as Array[String]).life_checked_at_phase_end, "forgotten: off")
