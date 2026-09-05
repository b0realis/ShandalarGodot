extends GameTest
## AI card-capability tests (2026-09-02): the general activated-ability
## scorer, the "hold the instant for its moment" rule and its mana
## reservation, regeneration in combat and against the stack, X sizing,
## sweeper gating, Dark Ritual gating, colour-aware land drops and
## land-aware discards. Every test acts through AiPlayer.act and the
## public MtgGame API; nothing pokes the AI's internals.


func _wizard(seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


# ------------------------------------------------ activated abilities --

func test_rod_of_ruin_pings_the_creature_it_kills() -> void:
	var ai := _wizard()
	put_battlefield(0, "Rod of Ruin")
	_lands(0, "Mountain", 3)
	var lions := put_battlefield(1, "Savannah Lions")   # 2/1
	put_battlefield(1, "Grizzly Bears")                 # 2/2: out of reach
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "activated Rod of Ruin")
	resolve_stack()
	assert_eq(lions.zone, Mtg.Zone.GRAVEYARD, "the X/1 died")
	assert_eq(g.players[1].life, 20, "not the face while a creature dies to it")


func test_orcish_artillery_holds_its_fire_at_an_empty_board() -> void:
	# Three life a shot at a face at twenty is a losing trade; the old AI
	# fired every turn and killed itself on the recoil.
	var ai := _wizard()
	put_battlefield(0, "Orcish Artillery")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_eq(g.players[0].life, 20)


func test_orcish_artillery_shoots_a_creature_it_kills() -> void:
	var ai := _wizard()
	put_battlefield(0, "Orcish Artillery")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "activated Orcish Artillery")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 17, "the recoil was paid")


func test_icy_manipulator_taps_their_best_creature_in_their_upkeep() -> void:
	var ai := _wizard()
	put_battlefield(0, "Icy Manipulator")
	put_battlefield(0, "Plains")
	var serra := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "nothing to attack into; the Icy waits for their upkeep")
	_their_turn_at(Mtg.Step.UPKEEP)
	assert_string_contains(ai.act(g), "activated Icy Manipulator")
	resolve_stack()
	assert_true(serra.tapped, "tapped before it could attack")


func test_jayemdae_tome_sinks_spare_mana_at_their_end_step() -> void:
	var ai := _wizard()
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Plains", 4)
	for _i in 5:
		give_hand(0, "Plains")   # a full hand: no draw NEED in the main phase
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "played a land")
	assert_eq(ai.act(g), "pass", "a Tome into a full hand is not worth the turn's mana")
	var before := g.players[0].hand.size()
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "activated Jayemdae Tome")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1, "the mana was about to be wasted")


# ---------------------------------------------- holding an instant --

func test_wizard_holds_terror_and_fires_it_at_their_end_step() -> void:
	var ai := _wizard()
	give_hand(0, "Terror")
	_lands(0, "Swamp", 2)
	var serra := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "removal waits for their turn")
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD)
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "cast Terror at end of turn")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


func test_wizard_bolts_the_face_when_it_is_lethal_now() -> void:
	var ai := _wizard()
	give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	g.players[1].life = 3
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Lightning Bolt")
	resolve_stack()
	assert_true(g.game_over)


func test_wizard_keeps_mana_open_for_the_held_removal() -> void:
	# Two Swamps, a Terror and a Gray Ogre: casting the Ogre would tap out
	# of the Terror that has a Serra to answer, so the Ogre waits.
	var ai := _wizard()
	give_hand(0, "Terror")
	give_hand(0, "Gray Ogre")   # {2}{R}
	_lands(0, "Swamp", 2)
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "the Ogre is not worth tapping out of the Terror")
	assert_not_null(g.find_in_hand(0, "Gray Ogre"))


func test_wizard_casts_freely_when_nothing_needs_answering() -> void:
	var ai := _wizard()
	give_hand(0, "Terror")
	give_hand(0, "Gray Ogre")
	_lands(0, "Swamp", 2)
	put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Gray Ogre")


# --------------------------------------------------- regeneration --

func test_skeletons_shield_when_blocking_to_death() -> void:
	var ai := _wizard(1)
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skeletons.id: bears.id}))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "shields Drudge Skeletons")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "regenerated (CR 701.15)")
	assert_true(skeletons.tapped, "the shield tapped it")


func test_skeletons_shield_against_a_bolt_but_not_an_exile() -> void:
	var ai := _wizard(1)
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Swamp")
	put_battlefield(1, "Swamp")
	var swords := give_hand(0, "Swords to Plowshares")
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(skeletons)]))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "shields Drudge Skeletons")
	resolve_stack()
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD, "the shield ate the Bolt")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, swords, [TargetRef.card(skeletons)]))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass", "a shield is no answer to exile (CR 701.15b)")


func test_skeletons_block_the_bear_and_shield() -> void:
	# The block maths knows its own regenerator: a Skeletons with {B} open
	# is a free wall against a 2/2, not a chump held back for emergencies.
	var ai := _wizard(1)
	var skeletons := put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_string_contains(ai.act(g), "1 block")
	assert_true(g.combat.blocks.has(skeletons.id))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "shields Drudge Skeletons")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(skeletons.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[1].life, 20, "the bear never connected")


# ------------------------------------------------------ combat maths --

func test_a_first_striker_attacks_into_a_bear_it_kills_first() -> void:
	var ai := _wizard()
	var knight := put_battlefield(0, "White Knight")   # 2/2 first strike
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.has(knight.id), "first strike wins that fight (CR 510.2)")


func test_a_first_striker_blocks_a_bear_it_kills_first() -> void:
	var ai := _wizard(1)
	var knight := put_battlefield(1, "White Knight")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_true(g.combat.blocks.has(knight.id), "kill it and live")


func test_no_all_in_when_the_blocks_stop_the_lethal() -> void:
	# Six power against five life LOOKS lethal; two untapped angels say
	# otherwise. The old sum-of-power push sent all three bears to die.
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Serra Angel")
	g.players[1].life = 5
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.is_empty(), "no bear into an angel for nothing")


func test_all_in_when_the_damage_gets_through_the_blocks() -> void:
	var ai := _wizard()
	for _i in 3:
		put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_eq(g.combat.attackers.size(), 3, "one blocked, four through, dead")


func test_a_pump_in_hand_sends_one_more_attacker() -> void:
	var ai := _wizard()
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	give_hand(0, "Giant Growth")
	put_battlefield(1, "Hill Giant")   # 3/3: eats a bare bear
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.has(bears.id), "a 5/5 with the trick beats the giant")


func test_no_attack_into_the_giant_without_the_trick() -> void:
	var ai := _wizard()
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	ai.act(g)
	assert_true(g.combat.attackers.is_empty())


# ------------------------------------------------ combat responses --

func test_a_bolt_stops_the_lethal_swing() -> void:
	var ai := _wizard(1)
	give_hand(1, "Lightning Bolt")
	put_battlefield(1, "Mountain")
	g.players[1].life = 4
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Lightning Bolt")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 2, "a bear is beneath the bar, unless it is the game")


func test_a_pump_on_the_unblocked_attacker_for_lethal() -> void:
	var ai := _wizard()
	give_hand(0, "Giant Growth")
	put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_string_contains(ai.act(g), "responded with Giant Growth")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.game_over, "2 + 3 = 5 > 4")


func test_removal_on_the_blocker_that_would_eat_the_angel() -> void:
	var ai := _wizard()
	give_hand(0, "Terror")
	_lands(0, "Swamp", 2)
	var serra := put_battlefield(0, "Serra Angel")
	var shivan := put_battlefield(1, "Shivan Dragon")   # 5/5 kills it and lives
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [serra.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {shivan.id: serra.id}))
	assert_string_contains(ai.act(g), "responded with Terror")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(shivan.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.zone, Mtg.Zone.BATTLEFIELD, "the angel flew on")


# --------------------------------------------------- sizing X spells --

func test_fireball_goes_to_the_face_for_exactly_lethal() -> void:
	var ai := _wizard()
	give_hand(0, "Fireball")
	_lands(0, "Mountain", 8)
	put_battlefield(1, "Serra Angel")   # the juicier creature target
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball")
	resolve_stack()
	assert_true(g.game_over, "X = 5 at the face, not at the angel")


func test_fireball_pays_exactly_the_toughness() -> void:
	var ai := _wizard()
	give_hand(0, "Fireball")
	_lands(0, "Mountain", 8)
	var serra := put_battlefield(1, "Serra Angel")   # 4/4
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Fireball")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)
	var untapped := 0
	for inst in g.players[0].battlefield:
		if inst.is_land() and not inst.tapped:
			untapped += 1
	assert_eq(untapped, 3, "X = 4 plus {R}: five lands, not eight")


func test_fireball_waits_rather_than_plink_a_face_at_twenty() -> void:
	var ai := _wizard()
	give_hand(0, "Fireball")
	_lands(0, "Mountain", 3)
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "two to the face is not what a Fireball is for")


# ------------------------------------------------------- sweepers --

func test_wrath_waits_while_our_board_is_the_bigger_one() -> void:
	var ai := _wizard()
	give_hand(0, "Wrath of God")
	_lands(0, "Plains", 4)
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_not_null(g.find_in_hand(0, "Wrath of God"))


func test_wrath_clears_a_board_that_beats_ours() -> void:
	var ai := _wizard()
	give_hand(0, "Wrath of God")
	_lands(0, "Plains", 4)
	put_battlefield(0, "Savannah Lions")
	var serra := put_battlefield(1, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Wrath of God")
	resolve_stack()
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------- Dark Ritual --

func test_dark_ritual_waits_for_a_spell_it_enables() -> void:
	var ai := _wizard()
	give_hand(0, "Dark Ritual")
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "{B}{B}{B} with nothing to spend it on")
	assert_not_null(g.find_in_hand(0, "Dark Ritual"))


func test_dark_ritual_powers_out_the_specter() -> void:
	var ai := _wizard()
	give_hand(0, "Dark Ritual")
	give_hand(0, "Hypnotic Specter")   # {1}{B}{B} off one Swamp
	put_battlefield(0, "Swamp")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Dark Ritual")
	resolve_stack()
	assert_string_contains(ai.act(g), "cast Hypnotic Specter", "the floating mana was spent")
	resolve_stack()
	assert_not_null(g.find_on_battlefield(0, "Hypnotic Specter"))


# ----------------------------------------------- lands and discards --

func test_the_land_drop_is_the_colour_the_hand_is_short_of() -> void:
	var ai := _wizard()
	give_hand(0, "Mountain")
	give_hand(0, "Swamp")
	give_hand(0, "Hypnotic Specter")   # {1}{B}{B}
	put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "played a land")
	assert_not_null(g.find_on_battlefield(0, "Swamp"), "black is what the hand wants")
	assert_not_null(g.find_in_hand(0, "Mountain"))


func test_a_land_light_hand_discards_the_spell_not_the_land() -> void:
	var ai := _wizard()
	put_battlefield(0, "Swamp")
	give_hand(0, "Swamp")
	give_hand(0, "Gray Ogre")   # worth 4 as a card; a land is worth 1.5
	var picked := ai.answer_discard(g, 0, 1)
	assert_eq(picked.size(), 1)
	assert_eq(picked[0].data.card_name, "Gray Ogre",
		"one land on the table: the second land is the keeper")


# ------------------------------------------- self-pumps and bounces --

func test_gargoyle_pumps_toughness_to_survive_the_block() -> void:
	var ai := _wizard(1)
	var gargoyle := put_battlefield(1, "Granite Gargoyle")   # 2/2, {R}: +0/+1
	put_battlefield(1, "Mountain")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {gargoyle.id: bears.id}))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "pumps Granite Gargoyle")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(gargoyle.zone, Mtg.Zone.BATTLEFIELD, "2/3 lives through two")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_unsummon_saves_the_djinn_from_terror() -> void:
	var ai := _wizard(1)
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	put_battlefield(1, "Island")
	give_hand(1, "Unsummon")
	var terror := give_hand(0, "Terror")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(djinn)]))
	assert_ok(g.pass_priority(0))
	assert_string_contains(ai.act(g), "responded with Unsummon")
	resolve_stack()
	assert_eq(djinn.zone, Mtg.Zone.HAND, "the card is kept; the Terror fizzles")


func test_firebreathing_leaves_the_mana_for_the_second_main_phase() -> void:
	# Shivan unblocked, five Mountains, a Hill Giant in hand ({3}{R}): one
	# breath is spare, the other four are the Giant. The old AI breathed
	# five times and cast nothing after combat.
	var ai := _wizard()
	give_hand(0, "Hill Giant")
	_lands(0, "Mountain", 5)
	var shivan := put_battlefield(0, "Shivan Dragon")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [shivan.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var breaths := 0
	for _i in 8:
		var did := ai.act(g)
		if did.begins_with("firebreathing"):
			breaths += 1
			resolve_stack()
		else:
			break
	assert_eq(breaths, 1, "one spare red, the rest is the Giant's")
	assert_eq(shivan.cur_power, 6)
	advance_to_step(Mtg.Step.MAIN2)
	assert_string_contains(ai.act(g), "cast Hill Giant")


func test_firebreathing_goes_all_in_when_the_breaths_are_lethal() -> void:
	var ai := _wizard()
	give_hand(0, "Hill Giant")
	_lands(0, "Mountain", 5)
	var shivan := put_battlefield(0, "Shivan Dragon")
	g.players[1].life = 10   # 5 + 5 breaths
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [shivan.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	var breaths := 0
	for _i in 8:
		var did := ai.act(g)
		if did.begins_with("firebreathing"):
			breaths += 1
			resolve_stack()
		else:
			break
	assert_eq(breaths, 5, "the Giant can wait: this is the game")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_true(g.game_over)


func test_a_toughness_pump_is_not_firebreathing() -> void:
	# Granite Gargoyle's {R}: +0/+1 at an open lane adds no damage; the
	# mana stays up.
	var ai := _wizard()
	_lands(0, "Mountain", 3)
	var gargoyle := put_battlefield(0, "Granite Gargoyle")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [gargoyle.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(ai.act(g), "pass")
	for land in g.players[0].battlefield:
		if land.is_land():
			assert_false(land.tapped, "%s stayed open" % land.data.card_name)
