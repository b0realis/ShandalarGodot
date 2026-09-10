extends GameTest
## THE ABYSS AS AN ANSWER (2026-09-08, The Deck's third pass). The
## counter decision priced every opposing spell by its printed worth
## against the profile's bar, so a Wizard with The Abyss on the table
## spent its Counterspell on the Serra Angel the enchantment would have
## destroyed at its controller's next upkeep. [member
## AiProfile.trusts_abyss] reads the appetite the trigger declares
## ([member TriggeredAbility.kills_each_upkeep]): a creature spell whose
## body would be the next meal — the target rule satisfied, no cheaper
## legal creature of theirs to be fed first — is let through, and the
## counter is kept for what the feeder cannot eat. Each behaviour is
## pinned with the knob and without it.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.trusts_abyss = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.trusts_abyss = false
	return profile


## Seat 1 holds a Counterspell with {U}{U} open; seat 0 casts
## [param card_name] in its main phase and passes priority to seat 1.
func _they_cast(card_name: String) -> CardInstance:
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var spell := give_hand(0, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 2)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 6)
	assert_ok(g.cast_spell(0, spell, []))
	assert_ok(g.pass_priority(0))
	return spell


# --------------------------------------------------------- the counter --

func test_the_angel_the_abyss_will_eat_is_let_through() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var serra := _they_cast("Serra Angel")
	assert_eq(ai.act(g), "pass", "the Abyss answers it at their upkeep")
	assert_eq(g.players[1].hand.size(), 1, "Counterspell still in hand")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD)


func test_off_the_angel_is_countered() -> void:
	var ai := _ai(_off())
	put_battlefield(1, "The Abyss")
	var serra := _they_cast("Serra Angel")
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_without_the_abyss_the_angel_is_countered() -> void:
	var ai := _ai(_on())
	var serra := _they_cast("Serra Angel")
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_an_angel_their_bears_shelter_is_countered() -> void:
	# The Bears are fed first: the Angel would live, so it is a threat.
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "Grizzly Bears")
	var serra := _they_cast("Serra Angel")
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_a_disenchant_is_still_answered() -> void:
	# The saved counter has a purpose: the Abyss cannot eat a Disenchant.
	var ai := _ai(_on())
	var abyss := put_battlefield(1, "The Abyss")
	give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var spell := give_hand(0, "Disenchant")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(abyss)]))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Counterspell")
	resolve_stack()
	assert_eq(abyss.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- the reading --

func test_the_meal_is_the_least_valuable_legal_creature() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var bears := give_hand(0, "Grizzly Bears")
	var serra := give_hand(0, "Serra Angel")
	assert_true(ai._is_next_meal(g, bears, 0), "an empty board: the Bears are the meal")
	assert_true(ai._is_next_meal(g, serra, 0), "an empty board: so would the Angel be")
	put_battlefield(0, "Grizzly Bears")
	# THE TWIN, closed 2026-09-10 (docs/ai-difficulty.md §5, the third
	# pass's open row). This assertion used to read `assert_true` and
	# `"level with the Bears on the table: fed either way"`, and that was
	# the malfunction: the feeder takes ONE body a turn, so a second
	# Grizzly Bears beside the first leaves a Grizzly Bears standing
	# whichever of the two is eaten, and the counter kept bought nothing.
	assert_false(ai._is_next_meal(g, bears, 0),
		"a twin already on the table shelters it: only one of the two dies")
	assert_false(ai._is_next_meal(g, serra, 0), "the Bears on the table are fed first")


func test_a_body_the_appetite_cannot_take_is_no_meal() -> void:
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	var knight := give_hand(0, "White Knight")
	assert_false(ai._is_next_meal(g, knight, 0), "protection from black")
	var statue := give_hand(0, "Clay Statue")
	assert_false(ai._is_next_meal(g, statue, 0), "an artifact creature")
	var bears := give_hand(0, "Grizzly Bears")
	assert_true(ai._is_next_meal(g, bears, 0))


func test_a_protected_creature_on_the_table_shelters_nothing() -> void:
	# The White Knight is no legal meal, so the Bears are still next.
	var ai := _ai(_on())
	put_battlefield(1, "The Abyss")
	put_battlefield(0, "White Knight")
	var bears := give_hand(0, "Grizzly Bears")
	assert_true(ai._is_next_meal(g, bears, 0))


func test_their_own_abyss_eats_their_creatures_too() -> void:
	var ai := _ai(_on())
	put_battlefield(0, "The Abyss")
	var serra := give_hand(0, "Serra Angel")
	assert_true(ai._is_next_meal(g, serra, 0))


func test_without_a_feeder_nothing_is_a_meal() -> void:
	var ai := _ai(_on())
	var serra := give_hand(0, "Serra Angel")
	assert_false(ai._is_next_meal(g, serra, 0))


# ----------------------------------------------------------- the ladder --

func test_the_ladder_trusts_from_sorcerer_up() -> void:
	assert_false(AiProfile.apprentice().trusts_abyss)
	assert_false(AiProfile.magician().trusts_abyss)
	assert_true(AiProfile.sorcerer().trusts_abyss)
	assert_true(AiProfile.wizard().trusts_abyss)


func test_the_knob_reads_from_the_lab() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("trusts_abyss=off"), "")
	assert_false(profile.trusts_abyss)
	assert_eq(profile.apply_overrides("trusts_abyss=on"), "")
	assert_true(profile.trusts_abyss)
