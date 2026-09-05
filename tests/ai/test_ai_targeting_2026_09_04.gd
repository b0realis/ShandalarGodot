extends GameTest
## THE 2026-09-04 TARGETING AUDIT: which SIDE of the table the AI aims a
## card at, and whether a tap is worth buying at all.
##
## Two playtest observations started it — "an opponent casting Psychic
## Venom on its own land" and "using Twiddle randomly" — and both turned
## out to be one bug each in the same routine, `AiPlayer._pick_for_spec`:
##
##  * AN AURA HAS NO SPELL EFFECTS, so `_is_harmful` could not read one.
##    It answered from a FOUR-NAME list inlined in the function ("Weakness",
##    "Paralyze", "Warp Artifact", "Wanderlust"); the other 73 auras in the
##    pool therefore counted as HELPFUL and were aimed at the AI's own
##    board. Psychic Venom on its own Island is the shape the owner saw;
##    Cursed Land, Evil Presence, Erosion, Backfire, Feedback, Blight,
##    Brainwash, Takklemaggot and eighteen more had the same bug and
##    nobody had watched them yet. The aim is now stated once, as data, in
##    [constant EffectIntent.AURA_HOSTILE], and
##    `test_every_aura_in_the_pool_is_classified` walks the whole registry
##    so a new aura cannot slip in unclassified the way those 73 did.
##
##  * A TAP has no value of its own — the same Twiddle is a blow-out or a
##    wasted card depending on whose permanent it hits and what state that
##    permanent is in. The AI knew this for repeatable ABILITIES
##    (`_ability_option`'s tap arm, `_best_tap_victim`) and knew none of it
##    for a tap SPELL, which went through the generic picker and aimed at
##    the enemy's most valuable permanent — tapped or not, land or not, at
##    whatever moment the spell became affordable. See "the tap policy" in
##    `ai_player.gd` for the two readings kept and the two left out.
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


## Run the AI's main phase until it stops doing things (bounded).
func _play_out_main(ai: AiPlayer) -> Array[String]:
	var did: Array[String] = []
	for _i in 12:
		var line := ai.act(g)
		if line == "" or line == "pass":
			break
		did.append(line)
	return did


# ================================================= 1. the aura's own side --

func test_psychic_venom_goes_on_their_land_not_ours() -> void:
	# THE OWNER'S OBSERVATION. Two Islands ours, two Islands theirs, one
	# Psychic Venom in hand. Before the fix the aura read as "helpful" and
	# the picker shopped our own battlefield — the AI enchanted its own
	# Island and took 2 every time it tapped for mana.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	var theirs := put_battlefield(1, "Island")
	give_hand(0, "Psychic Venom")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Psychic Venom")
	resolve_stack()
	assert_not_null(_aura_on(theirs, "Psychic Venom"), "it enchants THEIR land")
	for inst in g.players[0].battlefield:
		assert_eq(inst.attachments.size(), 0,
			"nothing of ours is wearing it (%s)" % inst.data.card_name)


func test_psychic_venom_is_not_cast_at_all_with_only_our_own_lands() -> void:
	# The other half of the decision, and it is the one that matters for a
	# self-harm aura: with no enemy land on the table the AI DECLINES.
	# Nothing in this pool pays the AI back for two damage a tap, so the
	# card waits in hand — it costs nothing there and everything on our
	# own Island.
	var ai := _wizard(0)
	_lands(0, "Island", 4)
	give_hand(0, "Psychic Venom")
	advance_to_step(Mtg.Step.MAIN1)
	for _i in 4:
		var line := ai.act(g)
		assert_false(line.contains("Psychic Venom"),
			"no enemy land: the venom stays in hand, not on ours")
		if line == "" or line == "pass":
			break
	assert_eq(g.players[0].hand.size(), 1, "the card is still in hand")
	for inst in g.players[0].battlefield:
		assert_eq(inst.attachments.size(), 0, "and nothing of ours wears it")


func test_a_helpful_aura_still_goes_on_our_own_creature() -> void:
	# The fix must not flip the pool the other way: Holy Strength is a
	# pump and belongs on ours, even with a fatter enemy creature in view.
	var ai := _wizard(0)
	_lands(0, "Plains", 2)
	var ours := put_battlefield(0, "Savannah Lions")
	var theirs := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Holy Strength")
	resolve_stack()
	assert_not_null(_aura_on(ours, "Holy Strength"), "our Lions wear it")
	assert_null(_aura_on(theirs, "Holy Strength"), "their Wurm does not")


func test_a_steal_aura_still_takes_their_best() -> void:
	# aura_steals is the one structural signal that already worked; pin it
	# so the table can never quietly override it.
	var ai := _wizard(0)
	_lands(0, "Island", 4)
	put_battlefield(0, "Grizzly Bears")
	var prize := put_battlefield(1, "Serra Angel")
	give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Control Magic")
	resolve_stack()
	assert_not_null(_aura_on(prize, "Control Magic"), "it takes the Angel")


func test_relic_bind_becomes_castable_at_all() -> void:
	# THE SAME DISEASE, FOUND BY THE SWEEP. Relic Bind's own spec says
	# "enchant artifact an opponent controls", so while the AI read it as
	# helpful it shopped its OWN battlefield, found nothing legal there,
	# and never cast the card in any game. Aimed across the table it works.
	var ai := _wizard(0)
	_lands(0, "Island", 4)
	put_battlefield(0, "Sol Ring")           # legal for the type, not the side
	var theirs := put_battlefield(1, "Icy Manipulator")
	give_hand(0, "Relic Bind")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Relic Bind")
	resolve_stack()
	assert_not_null(_aura_on(theirs, "Relic Bind"), "on THEIR artifact")


# ------------------------------------------- the classification itself --

func test_aura_aim_reads_the_shapes_it_is_meant_to() -> void:
	var venom := CardRegistry.get_card("Psychic Venom")
	assert_eq(EffectIntent.aura_aim(venom), EffectIntent.Aim.HOSTILE)
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("Cursed Land")),
		EffectIntent.Aim.HOSTILE, "a land tax points across the table")
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("Holy Strength")),
		EffectIntent.Aim.FRIENDLY)
	# The three structural signals need no table row.
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("Control Magic")),
		EffectIntent.Aim.HOSTILE, "aura_steals")
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("Animate Dead")),
		EffectIntent.Aim.FRIENDLY, "aura_reanimates — the host is in a graveyard")
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("White Ward")),
		EffectIntent.Aim.FRIENDLY, "aura_grants_protection")
	# And a non-aura is never asked the question.
	assert_eq(EffectIntent.aura_aim(CardRegistry.get_card("Lightning Bolt")),
		EffectIntent.Aim.FRIENDLY, "not an aura: no opinion")


func test_the_punishers_the_ai_wants_on_its_own_permanents() -> void:
	# THE NAMED EXCEPTIONS. Each of these reads like a curse and is not:
	# something else on the card pays the controller back, so the AI wants
	# it on ITS OWN permanent.
	#  * Unstable Mutation is a LOAN — +3/+3 now, a -1/-1 counter each of
	#    the host controller's upkeeps. The 1997 blue decks that run it
	#    (Ethyl Merman, Astral Visionary) put it on their own Merfolk.
	#  * Living Artifact's counters come from damage dealt to the AURA's
	#    controller and the life is paid to them, so it wants a host that
	#    will still be there.
	#  * Cocoon taps its host and holds it down — and then hands it back
	#    with a +1/+1 counter and flying.
	for name in ["Unstable Mutation", "Living Artifact", "Cocoon"]:
		assert_eq(EffectIntent.aura_aim(CardRegistry.get_card(name)),
			EffectIntent.Aim.FRIENDLY, "%s is a punisher we want at home" % name)


func test_every_aura_in_the_pool_is_classified() -> void:
	# THE LEDGER. The bug was not that Psychic Venom was missing from a
	# list — it was that a list existed at all and nothing checked it
	# against the pool. This walks all 897 cards, and any aura that is
	# neither settled structurally nor named in AURA_HOSTILE has to be
	# listed here as a DELIBERATE friendly, with the sweep's reading.
	const REVIEWED_FRIENDLY := [
		"Animate Artifact", "Animate Wall", "Anti-Magic Aura", "Artifact Ward",
		"Aspect of Wolf", "Blessing", "Burrowing", "Cocoon", "Consecrate Land",
		"Divine Transformation", "Dream Coat", "Equinox", "Eternal Warrior",
		"Farmstead", "Fear", "Firebreathing", "Fishliver Oil", "Flight",
		"Giant Strength", "Goblin Caves", "Goblin Shrine", "Holy Armor",
		"Holy Strength", "Infinite Authority", "Instill Energy", "Invisibility",
		"Lance", "Living Artifact", "Lure", "Power Artifact", "Puppet Master",
		"Regeneration", "Seeker", "Spectral Cloak", "Spirit Link", "The Brute",
		"Unholy Strength", "Unstable Mutation", "Venom", "Web", "Wild Growth",
	]
	var unclassified: Array[String] = []
	var auras := 0
	for card_name in CardRegistry.all_names():
		var data := CardRegistry.get_card(card_name)
		if data == null or not data.is_aura():
			continue
		auras += 1
		# The aim itself: hostile exactly when the table names it or the
		# card says it steals; friendly for everything else.
		var expected: int = EffectIntent.Aim.HOSTILE \
			if (EffectIntent.AURA_HOSTILE.has(card_name) or data.aura_steals) \
			else EffectIntent.Aim.FRIENDLY
		assert_eq(EffectIntent.aura_aim(data), expected, "%s's aim" % card_name)
		# And the coverage: decided by a structural signal, named in the
		# hostile table, or swept and listed here as a deliberate friendly.
		if EffectIntent.aura_is_classified(data) or REVIEWED_FRIENDLY.has(card_name):
			continue
		unclassified.append(card_name)
	assert_gt(auras, 70, "the pool really does hold that many auras")
	assert_eq(unclassified, [] as Array[String],
		"an aura nobody classified defaults to OUR OWN board — sweep it and "
		+ "put it in AURA_HOSTILE or in this test's REVIEWED_FRIENDLY list")


# ===================================================== 2. the tap policy --

func test_twiddle_reads_as_a_tap_and_an_untap() -> void:
	var twiddle := EffectIntent.read(
		CardRegistry.get_card("Twiddle").spell_effects, "Twiddle")
	assert_true(twiddle.taps, "the tap half")
	assert_true(twiddle.untaps, "the untap half — the mode is chosen on resolution")
	assert_false(twiddle.unknown, "a table row is a known shape")
	assert_true(twiddle.is_tap_utility(), "tapping is its whole job")
	# The shapes that must NOT be routed through the tap policy.
	assert_false(EffectIntent.read(
		CardRegistry.get_card("Lightning Bolt").spell_effects, "Lightning Bolt")
		.is_tap_utility())
	var icy := EffectIntent.read(
		CardRegistry.get_card("Icy Manipulator").activated_abilities[0].effects,
		"Icy Manipulator")
	assert_true(icy.is_tap_utility(), "the ability the policy was modelled on")


func test_twiddle_is_not_cast_with_nothing_worth_tapping() -> void:
	# The complaint, in its simplest form: an untargeted-feeling card cast
	# because SOMETHING was legal. Their board is one Island and one
	# already-tapped Bears; ours is empty of attackers. Nothing here is
	# worth a card, so the Twiddle stays in hand.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	put_battlefield(1, "Island")
	var sleeping := put_battlefield(1, "Grizzly Bears")
	g.tap_permanent(sleeping)
	give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	for line in _play_out_main(ai):
		assert_false(line.contains("Twiddle"), "no reason to Twiddle: %s" % line)
	assert_eq(g.players[0].hand.size(), 1, "still in hand")


func test_twiddle_never_taps_our_own_permanent() -> void:
	# Our own Serra Angel is the most valuable permanent on the table, and
	# the old picker aimed a "removal-shaped" unknown at the best thing it
	# could see on the side it had chosen. It must never choose ours.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	var ours := put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	_play_out_main(ai)
	resolve_stack()
	assert_false(ours.tapped, "our Angel is not the target")


func test_twiddle_clears_the_blocker_before_our_attack() -> void:
	# READING 2 of the policy: our precombat main, an attack ready, their
	# best untapped blocker tapped down so the swing gets through.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	put_battlefield(0, "Air Elemental")             # our attacker, 4/4 flier
	var blocker := put_battlefield(1, "Phantom Monster")   # 3/3 flier, can block it
	give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Twiddle")
	resolve_stack()
	assert_true(blocker.tapped, "the blocker is tapped down")


func test_twiddle_taps_their_best_creature_at_their_upkeep() -> void:
	# READING 1, and the strongest: a tap laid down at THEIR upkeep holds
	# through their turn (no attack) and ours (no block) — the Icy
	# Manipulator play, bought once with a card.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	var prize := put_battlefield(1, "Serra Angel")
	give_hand(0, "Twiddle")
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "reached their upkeep")
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var did := ai.act(g)
	assert_string_contains(did, "Twiddle")
	resolve_stack()
	assert_true(prize.tapped, "their Angel spends both turns tapped")


func test_a_tap_spell_skips_what_is_already_tapped() -> void:
	# Word of Binding is the other card of the shape, and a sorcery: "tap X
	# target creatures". X is bought for the creatures worth tapping and no
	# more, and an already-tapped Serra is not one of them.
	var ai := _wizard(0)
	_lands(0, "Swamp", 5)
	put_battlefield(0, "Hill Giant")                  # something to attack with
	var asleep := put_battlefield(1, "Serra Angel")
	g.tap_permanent(asleep)
	var awake := put_battlefield(1, "Grizzly Bears")
	give_hand(0, "Word of Binding")
	advance_to_step(Mtg.Step.MAIN1)
	var did := ai.act(g)
	assert_string_contains(did, "Word of Binding")
	resolve_stack()
	assert_true(awake.tapped, "the untapped blocker goes down")
	assert_eq(g.players[0].battlefield.filter(
		func(i: CardInstance) -> bool: return i.is_land() and i.tapped).size(), 3,
		"{2}{B}{B} — X = 1, the one creature worth tapping")


func test_the_tap_policy_leaves_lands_alone() -> void:
	# Left out on purpose (see "the tap policy"): one land is not worth a
	# card, and a land tapped on OUR turn untaps before their main phase
	# and denies nothing at all.
	var ai := _wizard(0)
	_lands(0, "Island", 3)
	put_battlefield(0, "Hill Giant")
	_lands(1, "Mountain", 4)
	give_hand(0, "Twiddle")
	advance_to_step(Mtg.Step.MAIN1)
	_play_out_main(ai)
	resolve_stack()
	for inst in g.players[1].battlefield:
		assert_false(inst.tapped, "their %s is untouched" % inst.data.card_name)
