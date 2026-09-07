extends GameTest
## THE SECOND LEGEND (2026-09-07, "The Deck, second pass"). Some arrivals
## are a card thrown away: a legend whose name is already on the
## battlefield is buried the moment it lands (the 1997 legend rule, the
## newcomer loses), and a world enchantment buries every other world on
## arrival (CR 704.5k) — our own included. The pilot cast its second and
## third The Abyss over the first, four mana and a card each time, in a
## game it then lost on cards (docs/ROADMAP.md, "The Deck, second pass").
##
## The rule reads the supertype bits and the names on the battlefield:
## nothing here names a card. A legend of ours or theirs with our name
## holds ours in hand; a world of OURS holds a second world in hand; a
## world of THEIRS is exactly what a world of ours is for. One knob,
## [member AiProfile.holds_duplicates], so each behaviour is pinned twice.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


func _holding() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.holds_duplicates = true
	return profile


func _not_holding() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.holds_duplicates = false
	return profile


# ----------------------------------------------------------- the world --

func test_a_second_world_of_our_own_stays_in_hand() -> void:
	var ai := _ai(_holding())
	put_battlefield(0, "The Abyss")
	var second := give_hand(0, "The Abyss")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(second.zone, Mtg.Zone.HAND, "it would bury the first for nothing")


func test_a_pilot_that_does_not_hold_buries_its_own_world() -> void:
	# The null: the behaviour the measurement was taken against.
	var ai := _ai(_not_holding())
	var first := put_battlefield(0, "The Abyss")
	give_hand(0, "The Abyss")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast The Abyss")
	resolve_stack()
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD, "the world rule buried the older one")


func test_a_different_world_of_our_own_is_held_too() -> void:
	# The rule is the supertype, not the name: any world of ours would go.
	var ai := _ai(_holding())
	put_battlefield(0, "Living Plane")
	var abyss := give_hand(0, "The Abyss")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(abyss.zone, Mtg.Zone.HAND)


func test_a_world_of_theirs_is_what_ours_is_for() -> void:
	var ai := _ai(_holding())
	var theirs := put_battlefield(1, "Concordant Crossroads")
	give_hand(0, "The Abyss")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast The Abyss")
	resolve_stack()
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "ours buried theirs: CR 704.5k")


func test_the_first_world_is_cast_as_ever() -> void:
	var ai := _ai(_holding())
	give_hand(0, "The Abyss")
	_lands(0, "Swamp", 4)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast The Abyss")


# ---------------------------------------------------------- the legend --

func test_a_legend_already_on_the_battlefield_holds_ours_in_hand() -> void:
	# Theirs: the 1997 legend rule buries the newcomer, which would be ours.
	var ai := _ai(_holding())
	put_battlefield(1, "Jasmine Boreal")
	var ours := give_hand(0, "Jasmine Boreal")
	_lands(0, "Forest", 3)
	_lands(0, "Plains", 2)
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(ours.zone, Mtg.Zone.HAND)


func test_a_pilot_that_does_not_hold_casts_the_second_legend() -> void:
	var ai := _ai(_not_holding())
	put_battlefield(1, "Jasmine Boreal")
	var ours := give_hand(0, "Jasmine Boreal")
	_lands(0, "Forest", 3)
	_lands(0, "Plains", 2)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Jasmine Boreal")
	resolve_stack()
	assert_eq(ours.zone, Mtg.Zone.GRAVEYARD, "buried on arrival: the legend rule")


func test_a_legendary_land_is_not_played_over_its_own_name() -> void:
	var ai := _ai(_holding())
	put_battlefield(0, "Karakas")
	var second := give_hand(0, "Karakas")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(second.zone, Mtg.Zone.HAND, "the land drop is worth more than a burial")


func test_a_pilot_that_does_not_hold_plays_the_second_karakas() -> void:
	var ai := _ai(_not_holding())
	put_battlefield(0, "Karakas")
	var second := give_hand(0, "Karakas")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "played a land")
	g.check_state_based_actions()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD, "buried on arrival: the legend rule")


func test_a_legend_of_a_different_name_is_cast() -> void:
	var ai := _ai(_holding())
	put_battlefield(1, "Jasmine Boreal")
	give_hand(0, "Tobias Andrion")
	_lands(0, "Plains", 3)
	_lands(0, "Island", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Tobias Andrion")


# ------------------------------------------------------------- the ladder --

func test_the_ladder_holds_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().holds_duplicates)
	assert_false(AiProfile.magician().holds_duplicates)
	assert_true(AiProfile.sorcerer().holds_duplicates)
	assert_true(AiProfile.wizard().holds_duplicates)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("holds_duplicates=off"), "")
	assert_false(profile.holds_duplicates)
	assert_eq(profile.apply_overrides("holds_duplicates=on"), "")
	assert_true(profile.holds_duplicates)
