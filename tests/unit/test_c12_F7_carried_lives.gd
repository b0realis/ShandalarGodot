extends GutTest
## THE LIVES CARRIED, THE BUG CAMPAIGN c12 (fixer F7, 2026-10-27; h2-2 and
## the owner's ruling "Carry the life you ended with"). A creature's reward
## "You get your lives (N) carried over to the next duel" leaves the next
## duel starting at exactly N, the life the hero ended the duel with —
## whatever gift or earlier carry raised the start. 1997 carried the end
## less the START, so a gift that raised the start was taken off again: 10
## links and the wise man's +2 began at 12, ended at 15, said "(15)" and
## started the next duel at 13. With no gift the two agree, as 1997.

const VAMPIRE_LORD := 4   # its reward: the lives carried alone (0x1)

var base: Dictionary
var player: AdventurePlayer


func before_all() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Life Carrier"
	setup.color = "green"
	setup.difficulty = 0
	setup.walker = "female"
	setup.seed_text = "4242"
	var record := setup.resolve({})
	var hero := AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	base = JSON.parse_string(JSON.stringify(hero.to_dict()))


func before_each() -> void:
	player = AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(base)))
	player.monsters = []
	player.cards = []
	for card_name in ["Forest", "Forest", "Forest", "Forest", "Forest", "Forest",
			"Llanowar Elves", "Llanowar Elves", "Grizzly Bears", "Grizzly Bears"]:
		player.cards.append({"card": card_name, "decks": [0]})
	player.current_deck = 0
	for slot in player.world.encounters:
		(slot as Dictionary)["clues"] = 7   # no dungeon to hint at: the cards at once
	_links(10)


## Exactly [param count] towns linked, none ruled.
func _links(count: int) -> void:
	var linked := 0
	for slot in player.world.sites.size():
		var on := TownStatus.is_town(player.world, slot) and not TownStatus.ruled(player.world, slot) \
			and linked < count
		TownStatus.put(player.world, slot, TownStatus.LINKED, on)
		if on:
			linked += 1


## A special meeting's VampireLord beaten, the hero's life [param start] →
## [param end] (the start as the duel's config would set it when -1).
func _beat_vampire_lord(end: int, start := -1) -> Dictionary:
	assert_eq(CreatureBook.reward_flags(VAMPIRE_LORD), CreatureBook.REWARD_LIFE_CARRIED,
		"control: the VampireLord's reward")
	var meeting := CreatureMeeting.meet(player, VAMPIRE_LORD, 1)
	meeting["timer"] = 0   # a special meeting
	CreatureMeeting.prepare_duel(player, meeting)
	meeting["row"] = VAMPIRE_LORD   # whatever it summoned, the VampireLord is fought
	meeting["special"] = true
	var report := DuelReport.new()
	report.finished = true
	report.result = DuelSpoils.WON
	report.winner = 0
	var began := CreatureMeeting.hero_life(player) if start < 0 else start
	report.lives_start = [began, 6] as Array[int]
	report.lives_end = [end, 0] as Array[int]
	report.hero_life = end
	return DuelSpoils.settle(player, meeting, report)


func _said(spoils: Dictionary) -> String:
	return "\n".join(PackedStringArray(spoils.get("rewards", [])))


# ------------------------------------------------------------ the ruling --

## The hunter's repro: 10 links and the wise man's +2 begin the duel at 12;
## it ends at 15; the reward names 15 and the next duel starts at 15.
func test_a_gift_that_raised_the_start_is_not_taken_off_again() -> void:
	player.next_duel_life = 2   # the wise man's
	assert_eq(CreatureMeeting.hero_life(player), 12, "control: 10 links + 2")
	var spoils := _beat_vampire_lord(15)
	assert_string_contains(_said(spoils), "You get your lives (15)")
	assert_eq(CreatureMeeting.hero_life(player), 15, "the next duel starts at the 15 the hero ended with")
	assert_eq(player.next_duel_life, 0, "the gift spent")


## No gift and no earlier carry: the start is the links, and the carry is
## 1997's own (end − start).
func test_with_no_gift_the_carry_is_1997s() -> void:
	var spoils := _beat_vampire_lord(15)
	assert_eq(player.next_duel_life_carried, 5, "15 − 10, as 1997 carried it")
	assert_eq(CreatureMeeting.hero_life(player), 15)
	assert_string_contains(_said(spoils), "You get your lives (15)")
	before_each()
	spoils = _beat_vampire_lord(4)
	assert_eq(player.next_duel_life_carried, -6, "a loss of life carried too")
	assert_eq(CreatureMeeting.hero_life(player), 4)
	assert_string_contains(_said(spoils), "You get your lives (4)")


## An earlier carry that raised the start: ended where it began, the life
## still carries (1997 carried nothing and started the next duel at 10).
func test_an_earlier_carry_that_raised_the_start_carries_on() -> void:
	player.next_duel_life_carried = 3
	assert_eq(CreatureMeeting.hero_life(player), 13, "control: 10 links + 3 carried")
	var spoils := _beat_vampire_lord(13)
	assert_string_contains(_said(spoils), "You get your lives (13)")
	assert_eq(CreatureMeeting.hero_life(player), 13)


## The words and the life agree, whatever the start and the end; a carry
## of nothing (the end is the links) says nothing, as 1997's carry of
## nothing (the end is the start) said nothing.
func test_the_words_and_the_next_duels_life_agree() -> void:
	for case in [[0, 0, 15], [2, 0, 15], [0, 3, 9], [4, -2, 20], [2, 0, 1], [3, 0, 12]]:
		before_each()
		player.next_duel_life = int(case[0])
		player.next_duel_life_carried = int(case[1])
		var spoils := _beat_vampire_lord(int(case[2]))
		var said := _said(spoils)
		var life := CreatureMeeting.hero_life(player)
		assert_eq(life, int(case[2]), "%s: the next duel starts at the end's life" % [case])
		assert_string_contains(said, "You get your lives (%d)" % life, "%s: and the words say so" % [case])
	before_each()
	player.next_duel_life = 2
	var spoils := _beat_vampire_lord(10)
	assert_false(_said(spoils).contains("You get your lives"), "ended at the links: nothing to carry")
	assert_eq(CreatureMeeting.hero_life(player), 10)
	assert_eq(player.next_duel_life_carried, 0)


## The quest pane's line counts the carry from the links, as the duel does.
func test_the_next_duel_line_names_the_carry_from_the_links() -> void:
	player.next_duel_life = 2
	_beat_vampire_lord(15)
	assert_eq(WorldStatus.next_duel_line(player), "Next Duel: +5 lives", "10 links + 5 = the 15 promised")


# --------------------------------------------------------------- the saves --

## A save made before the ruling keeps its carry as it was written: the
## field still adds to the links.
func test_a_save_of_the_old_carry_still_reads() -> void:
	var saved := player.to_dict()
	saved["duels"]["next_duel_life_carried"] = 3   # 1997's end − start, written before
	var back := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(saved)))
	assert_eq(back.next_duel_life_carried, 3)
	assert_eq(CreatureMeeting.hero_life(back), back.mana_links() + 3)
	_beat_vampire_lord(15)
	var again := AdventurePlayer.from_dict(JSON.parse_string(JSON.stringify(player.to_dict())))
	assert_eq(CreatureMeeting.hero_life(again), 15, "a new carry saved and read back starts the duel at 15")
