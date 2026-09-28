extends GameTest
## THE SAME CARD TWICE (2026-09-28): the AI does not cast a card whose
## second copy adds nothing to the first. The owner, from the third
## handheld playtest: *"i noticed it played the same aura card
## ("regeneration") on the card with already the same aura on it! Repair
## AI so it does not cast same cards allready present! This should
## improve AI play with all cards :)"*
##
## Regeneration grants an ability, not a keyword, so the host reader
## ([method EffectIntent.aura_fits]) had no opinion and the picker took
## the best body — the one already wearing the first. Now [method
## EffectIntent.stacks] reads whether a card is a QUANTITY off its own
## printed line (a pump, a damage, a counter, a mana, a life, a {T}: two
## are twice as much) and [method EffectIntent.aura_repeats] /
## [method EffectIntent.permanent_repeats] refuse the second copy of
## anything else — on a host already wearing it, or on a side already
## holding it. On for every profile ([member AiProfile.holds_repeats]).
##
## Every test acts through AiPlayer.act / the public MtgGame API.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## The aura attached to [param host], or null.
func _aura_on(host: CardInstance, aura_name: String) -> CardInstance:
	for inst in g.all_battlefield():
		if inst.data.card_name == aura_name and inst.attached_to == host.id:
			return inst
	return null


func _in_hand(seat: int, card_name: String) -> bool:
	for card in g.players[seat].hand:
		if card.data.card_name == card_name:
			return true
	return false


func _count_on_table(seat: int, card_name: String) -> int:
	var n := 0
	for perm in g.players[seat].battlefield:
		if perm.data.card_name == card_name:
			n += 1
	return n


# ================================================== the owner's playtest --

func test_a_second_regeneration_goes_on_the_creature_without_one() -> void:
	var ai := _wizard(0)
	_lands(0, "Forest", 4)
	var giant := put_battlefield(0, "Hill Giant")      # 3/3, the better body
	var bears := put_battlefield(0, "Grizzly Bears")   # 2/2
	var first := give_hand(0, "Regeneration")
	g.attach_aura_from_anywhere(first, giant, 0)
	assert_not_null(_aura_on(giant, "Regeneration"), "the first is worn by the Giant")
	give_hand(0, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Regeneration")
	resolve_stack()
	assert_not_null(_aura_on(bears, "Regeneration"), "the Bears, who had none")
	assert_eq(giant.attachments.size(), 1, "never a second on the Giant")


func test_a_second_regeneration_stays_in_hand_with_one_host_already_wearing_it() -> void:
	var ai := _wizard(0)
	_lands(0, "Forest", 4)
	var giant := put_battlefield(0, "Hill Giant")
	var first := give_hand(0, "Regeneration")
	g.attach_aura_from_anywhere(first, giant, 0)
	give_hand(0, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_false(did.contains("Regeneration"), "not cast for nothing: %s" % did)
	assert_true(_in_hand(0, "Regeneration"), "kept for a creature that has none")


func test_a_second_pump_on_the_same_body_is_twice_the_pump() -> void:
	# Giant Strength is a quantity: +4/+4 on the best body is the play it
	# always was.
	var ai := _wizard(0)
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	var first := give_hand(0, "Giant Strength")
	g.attach_aura_from_anywhere(first, giant, 0)
	give_hand(0, "Giant Strength")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Giant Strength")
	resolve_stack()
	assert_eq(giant.attachments.size(), 2, "both on the Giant")
	assert_eq(giant.cur_power, 7, "3 + 2 + 2")


# ================================================================ the null --

func test_with_the_knob_off_the_giant_wears_two_as_before() -> void:
	# The Deck Lab's null: holds_repeats off is the picker of old.
	var profile := AiProfile.wizard()
	profile.holds_repeats = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	_lands(0, "Forest", 4)
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(0, "Grizzly Bears")
	var first := give_hand(0, "Regeneration")
	g.attach_aura_from_anywhere(first, giant, 0)
	give_hand(0, "Regeneration")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Regeneration")
	resolve_stack()
	assert_eq(giant.attachments.size(), 2, "the nonsense, on request")


# ======================================================= the static permanent --

func test_a_second_kismet_stays_in_hand() -> void:
	var ai := _wizard(0)
	_lands(0, "Plains", 4)
	put_battlefield(0, "Kismet")
	give_hand(0, "Kismet")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._try_cast_best(g), "", "the same card thrown away")
	assert_true(_in_hand(0, "Kismet"))
	assert_eq(_count_on_table(0, "Kismet"), 1)
	ai.profile.holds_repeats = false
	assert_eq(ai._try_cast_best(g), "cast Kismet", "off, the second is cast")


func test_the_first_kismet_is_cast() -> void:
	var ai := _wizard(0)
	_lands(0, "Plains", 4)
	give_hand(0, "Kismet")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._try_cast_best(g), "cast Kismet")


func test_a_second_howling_mine_is_a_second_card_a_turn() -> void:
	var ai := _wizard(0)
	_lands(0, "Plains", 4)
	put_battlefield(0, "Howling Mine")
	give_hand(0, "Howling Mine")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._try_cast_best(g), "cast Howling Mine")


func test_their_kismet_does_not_hold_ours() -> void:
	# Theirs taps OUR permanents; ours taps theirs.
	var ai := _wizard(0)
	_lands(0, "Plains", 4)
	put_battlefield(1, "Kismet")
	give_hand(0, "Kismet")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai._try_cast_best(g), "cast Kismet")


# ============================================================ the reader --

func test_a_quantity_stacks_and_a_grant_does_not() -> void:
	for name in ["Giant Strength", "Holy Strength", "Weakness", "Aspect of Wolf",
			"Wanderlust", "Psychic Venom", "Spirit Shackle", "Wild Growth",
			"Spirit Link", "Howling Mine", "Crusade", "Gloom", "Icy Manipulator",
			"Copy Artifact"]:
		assert_true(EffectIntent.stacks(CardRegistry.get_card(name)), "%s is a quantity" % name)
	for name in ["Regeneration", "Flight", "Eternal Warrior", "Black Ward", "Paralyze",
			"Gaseous Form", "Lure", "Control Magic", "Kismet", "Winter Orb", "Moat",
			"Meekstone", "Blood Moon"]:
		assert_false(EffectIntent.stacks(CardRegistry.get_card(name)), "%s is had once" % name)
	assert_true(EffectIntent.stacks(null), "nothing is not a repeat")


func test_a_host_repeats_only_the_aura_it_wears() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	var regeneration := CardRegistry.get_card("Regeneration")
	assert_false(EffectIntent.aura_repeats(regeneration, giant, g), "bare")
	g.attach_aura_from_anywhere(give_hand(0, "Regeneration"), giant, 0)
	assert_true(EffectIntent.aura_repeats(regeneration, giant, g), "worn")
	assert_false(EffectIntent.aura_repeats(regeneration, bears, g), "the other is bare")
	assert_false(EffectIntent.aura_repeats(CardRegistry.get_card("Flight"), giant, g),
		"a different aura")
	g.attach_aura_from_anywhere(give_hand(0, "Giant Strength"), giant, 0)
	assert_false(EffectIntent.aura_repeats(CardRegistry.get_card("Giant Strength"), giant, g),
		"a pump never repeats")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.attach_aura_from_anywhere(give_hand(0, "Paralyze"), theirs, 0)
	assert_true(EffectIntent.aura_repeats(CardRegistry.get_card("Paralyze"), theirs, g),
		"their creature under one already")
	assert_false(EffectIntent.aura_repeats(regeneration, null, g))
	assert_false(EffectIntent.aura_repeats(null, giant, g))
	assert_false(EffectIntent.aura_repeats(CardRegistry.get_card("Hill Giant"), giant, g),
		"not an aura")


func test_a_side_repeats_only_the_static_permanent_it_holds() -> void:
	var kismet := CardRegistry.get_card("Kismet")
	assert_false(EffectIntent.permanent_repeats(kismet, g, 0), "none yet")
	put_battlefield(0, "Kismet")
	assert_true(EffectIntent.permanent_repeats(kismet, g, 0))
	assert_false(EffectIntent.permanent_repeats(kismet, g, 1), "their side is bare")
	put_battlefield(0, "Howling Mine")
	assert_false(EffectIntent.permanent_repeats(CardRegistry.get_card("Howling Mine"), g, 0),
		"a card a turn is a quantity")
	put_battlefield(0, "Icy Manipulator")
	assert_false(EffectIntent.permanent_repeats(CardRegistry.get_card("Icy Manipulator"), g, 0),
		"an activation each")
	put_battlefield(0, "Grizzly Bears")
	assert_false(EffectIntent.permanent_repeats(CardRegistry.get_card("Grizzly Bears"), g, 0),
		"a creature is a body")
	put_battlefield(0, "Forest")
	assert_false(EffectIntent.permanent_repeats(CardRegistry.get_card("Forest"), g, 0),
		"a land is a land")
	assert_false(EffectIntent.permanent_repeats(null, g, 0))
