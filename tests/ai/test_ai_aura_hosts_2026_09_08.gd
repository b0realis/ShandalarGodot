extends GameTest
## THE AURA AND ITS HOST (2026-09-08): a friendly aura goes on a creature
## it gives something to. The owner, from a playtest: *"ai oponent had
## Wall of swords (wall cannot attack) - and the AI put 'eternal warrior'
## aura - vigilance on the wall - this is complete nonsense! Please add
## this to our Ai play engine. That particular aura should be put on
## valuable creature that can then serve as attacker and blocker"*.
##
## The picker shopped its own board by [method Evaluator.permanent_value]
## alone, and a 3/5 flying Wall is the best creature on many boards.
## [method EffectIntent.aura_gifts] now reads what an aura grants off its
## own words, and [method EffectIntent.aura_fits] says whether a host can
## use it: an attacker's gift (vigilance, fear, landwalk, unblockability)
## is nothing to a creature with defender, and a keyword the host already
## has is nothing to it either. A host that fits none is skipped; with
## no host at all the aura stays in hand.
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


func _gift_keywords(card_name: String) -> Array:
	var out := []
	for gift in EffectIntent.aura_gifts(CardRegistry.get_card(card_name)):
		out.append(int(gift["keyword"]))
	return out


# ================================================== the owner's playtest --

func test_eternal_warrior_goes_on_the_attacker_not_the_wall() -> void:
	var ai := _wizard(0)
	_lands(0, "Mountain", 2)
	var wall := put_battlefield(0, "Wall of Swords")   # 3/5 flying, defender
	var giant := put_battlefield(0, "Hill Giant")      # 3/3, the lesser body
	assert_gt(Evaluator.permanent_value(wall), Evaluator.permanent_value(giant),
		"the Wall is the more valuable creature — the shape the owner saw")
	give_hand(0, "Eternal Warrior")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Eternal Warrior")
	resolve_stack()
	assert_not_null(_aura_on(giant, "Eternal Warrior"), "vigilance on the one that attacks")
	assert_null(_aura_on(wall, "Eternal Warrior"), "never on the Wall")


func test_eternal_warrior_stays_in_hand_with_only_walls_to_wear_it() -> void:
	var ai := _wizard(0)
	_lands(0, "Mountain", 2)
	put_battlefield(0, "Wall of Swords")
	give_hand(0, "Eternal Warrior")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_false(did.contains("Eternal Warrior"), "not cast for nothing: %s" % did)
	var kept := false
	for card in g.players[0].hand:
		kept = kept or card.data.card_name == "Eternal Warrior"
	assert_true(kept, "kept for a creature that can attack")


# ================================================================ the null --

func test_with_the_knob_off_the_wall_wears_it_as_before() -> void:
	# The Deck Lab's null: fits_auras off is the picker of old, the best
	# body by value, defender or not.
	var profile := AiProfile.wizard()
	profile.fits_auras = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	_lands(0, "Mountain", 2)
	var wall := put_battlefield(0, "Wall of Swords")
	put_battlefield(0, "Hill Giant")
	give_hand(0, "Eternal Warrior")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Eternal Warrior")
	resolve_stack()
	assert_not_null(_aura_on(wall, "Eternal Warrior"), "the nonsense, on request")


func test_a_second_eternal_warrior_finds_a_second_host() -> void:
	# What the Troll Shaman sweep was made of (three Eternal Warriors, no
	# Wall): the best body already wears one, so the next goes elsewhere.
	var ai := _wizard(0)
	_lands(0, "Mountain", 4)
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(0, "Gray Ogre")
	var first := give_hand(0, "Eternal Warrior")
	g.attach_aura_from_anywhere(first, giant, 0)
	assert_true(giant.has_keyword(Mtg.Keyword.VIGILANCE), "the first is worn")
	give_hand(0, "Eternal Warrior")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Eternal Warrior")
	resolve_stack()
	assert_not_null(_aura_on(ogre, "Eternal Warrior"), "the Ogre, who had none")


# ============================================ the same rule, other gifts --

func test_flight_is_not_hung_on_a_flyer() -> void:
	var ai := _wizard(0)
	_lands(0, "Island", 2)
	var angel := put_battlefield(0, "Serra Angel")   # 4/4 flying vigilance, the best body
	var giant := put_battlefield(0, "Hill Giant")
	give_hand(0, "Flight")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Flight")
	resolve_stack()
	assert_not_null(_aura_on(giant, "Flight"), "wings for the one without")
	assert_null(_aura_on(angel, "Flight"), "the Angel has hers")


func test_a_blockers_gift_still_goes_on_the_wall() -> void:
	# First strike serves a blocker: Lance on the Wall is a fine play, and
	# the Wall is the better body.
	var ai := _wizard(0)
	_lands(0, "Plains", 2)
	var wall := put_battlefield(0, "Wall of Swords")
	put_battlefield(0, "Hill Giant")
	give_hand(0, "Lance")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Lance")
	resolve_stack()
	assert_not_null(_aura_on(wall, "Lance"), "first strike on the best blocker")


func test_a_pump_is_a_gift_to_any_creature() -> void:
	# Giant Strength grants nothing this reader knows; the host's value
	# decides as before — the Wall, blocking, gets the most from +2/+2.
	var ai := _wizard(0)
	_lands(0, "Mountain", 2)
	var wall := put_battlefield(0, "Wall of Swords")
	put_battlefield(0, "Hill Giant")
	give_hand(0, "Giant Strength")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Giant Strength")
	resolve_stack()
	assert_not_null(_aura_on(wall, "Giant Strength"))


# ============================================================ the reader --

func test_the_gifts_are_read_as_the_cards_spell_them() -> void:
	assert_eq(_gift_keywords("Eternal Warrior"), [Mtg.Keyword.VIGILANCE])
	assert_true(bool(EffectIntent.aura_gifts(CardRegistry.get_card("Eternal Warrior"))[0]["attack_only"]),
		"vigilance is an attacker's gift")
	assert_eq(_gift_keywords("Flight"), [Mtg.Keyword.FLYING])
	assert_false(bool(EffectIntent.aura_gifts(CardRegistry.get_card("Flight"))[0]["attack_only"]),
		"flying serves a blocker too")
	assert_eq(_gift_keywords("Lance"), [Mtg.Keyword.FIRST_STRIKE])
	assert_has(_gift_keywords("Invisibility"), Mtg.Keyword.UNBLOCKABLE)
	var oil: Array = EffectIntent.aura_gifts(CardRegistry.get_card("Fishliver Oil"))
	assert_eq(oil.size(), 1)
	assert_eq(String(oil[0]["landwalk"]), "island", "in the engine's own lower case")
	assert_eq(EffectIntent.aura_gifts(CardRegistry.get_card("Giant Strength")), [], "a pump grants nothing")
	assert_eq(EffectIntent.aura_gifts(CardRegistry.get_card("Psychic Venom")), [], "a land aura grants nothing")
	assert_eq(EffectIntent.aura_gifts(CardRegistry.get_card("Hill Giant")), [], "not an aura")


func test_a_host_fits_when_it_can_use_at_least_one_gift() -> void:
	var wall := put_battlefield(0, "Wall of Swords")
	var giant := put_battlefield(0, "Hill Giant")
	var angel := put_battlefield(0, "Serra Angel")
	var warrior := CardRegistry.get_card("Eternal Warrior")
	var flight := CardRegistry.get_card("Flight")
	var lance := CardRegistry.get_card("Lance")
	var oil := CardRegistry.get_card("Fishliver Oil")
	assert_false(EffectIntent.aura_fits(warrior, wall), "vigilance on a Wall")
	assert_true(EffectIntent.aura_fits(warrior, giant))
	assert_false(EffectIntent.aura_fits(warrior, angel), "the Angel has vigilance")
	assert_false(EffectIntent.aura_fits(flight, wall), "the Wall flies already")
	assert_true(EffectIntent.aura_fits(flight, giant))
	assert_true(EffectIntent.aura_fits(lance, wall), "first strike is a blocker's gift too")
	assert_false(EffectIntent.aura_fits(oil, wall), "islandwalk on a Wall")
	assert_true(EffectIntent.aura_fits(oil, giant))
	giant.cur_landwalk.append("island")
	assert_false(EffectIntent.aura_fits(oil, giant), "a walk it has")
	giant.cur_landwalk.erase("island")
	giant.cur_cant_attack = true
	assert_false(EffectIntent.aura_fits(warrior, giant), "held under a can't-attack")
	giant.cur_cant_attack = false
	assert_true(EffectIntent.aura_fits(CardRegistry.get_card("Giant Strength"), wall),
		"a pump fits anyone")
