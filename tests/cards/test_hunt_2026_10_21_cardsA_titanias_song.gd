extends GameTest
## TITANIA'S SONG SIZES IN LAYER 7b (bug hunt 2026-10-21, cardsA; found by the
## rules hunter, fixed in the card).
##
## "Each noncreature artifact … becomes an artifact creature with power and
## toughness each equal to its mana value." The size is a layer-7b effect
## and applies in timestamp order with the other 7b setters (CR 613.4b,
## 613.7). The Song's one static wrote it in the early silence-and-retype
## pass, so a Humility of any age overwrote it: a Song newer than the
## Humility still left a Jayemdae Tome 1/1 where it is 4/4. The size is now
## a static of its own in 7b — and the lingering Song ("this effect
## continues until end of turn") floats both halves.


## "All creatures lose all abilities and have base power and toughness
## 1/1." — Humility's two statics, built as test_pack_9_engine_F_silencing
## builds them, so no pack has to be on.
static func _creature(_g: MtgGame, _s: CardInstance, inst: CardInstance) -> bool:
	return inst.is_creature()


static func _humility() -> CardData:
	return CardData.new("Test Humility", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.removing_all_abilities(_creature,
			"All creatures lose all abilities.")) \
		.static_ability(StaticAbility.base_pt_for(_creature, 1, 1,
			"All creatures have base power and toughness 1/1."))


func test_a_song_newer_than_humility_sizes_the_artifact() -> void:
	put_synthetic(1, _humility())
	var tome := put_battlefield(0, "Jayemdae Tome")   # mana value 4
	put_battlefield(0, "Titania's Song")              # the later timestamp
	g.recalculate()
	assert_true(tome.is_creature())
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4],
		"CR 613.7: the Song's 7b set is later than Humility's 1/1")


func test_a_humility_newer_than_the_song_makes_it_one_one() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Titania's Song")
	put_synthetic(1, _humility())                     # the later timestamp
	g.recalculate()
	assert_eq([tome.cur_power, tome.cur_toughness], [1, 1])


func test_the_song_alone_still_animates_and_silences() -> void:
	var tome := put_battlefield(0, "Jayemdae Tome")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Titania's Song")
	g.recalculate()
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4])
	assert_true(tome.cur_abilities_silenced)
	assert_eq(tome.cur_activated_abilities.size(), 0, "the Tome's draw is gone")
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 2], "creatures are untouched")


func test_the_lingering_song_still_sizes_after_humility() -> void:
	put_synthetic(1, _humility())
	var tome := put_battlefield(0, "Jayemdae Tome")
	var song := put_battlefield(0, "Titania's Song")
	g.destroy(song)
	g.recalculate()
	assert_true(tome.is_creature(), "the effect continues until end of turn")
	assert_eq([tome.cur_power, tome.cur_toughness], [4, 4],
		"the floating halves are newer than the Humility too")
