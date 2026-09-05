extends GameTest
## Engine pins from the 2026-09-01 code review (docs/code-review-2026-09.md).
## Every test here failed before the fix recorded in the same row of that
## document.


# ------------------------------------- CardRegistry: the printing index --

func test_the_printing_index_is_built_before_a_worker_thread_can_ask() -> void:
	# THE BUG THIS PINS: the card-name -> first-printing index and the
	# illustrator index were each built LAZILY, and each set its "loaded"
	# flag BEFORE filling its dictionary. `originally_printed_in` is asked
	# from inside a game (City in a Bottle, Golgothian Sylex) and the Deck
	# Lab fans games out over a WorkerThreadPool, so two games reaching a
	# cold index at once was a real shape. An 8-thread probe on a cold
	# index measured 7 of 8 threads answering `false` for an Arabian
	# Nights original, and the process segfaulted within ten cold starts.
	#
	# The fix is structural: ensure_loaded() builds the index, so a worker
	# can never find it cold. This asserts the flag the fix introduced —
	# if the index ever goes lazy again, this line stops compiling.
	CardRegistry.ensure_loaded()
	assert_true(CardRegistry._printings_loaded,
		"ensure_loaded() leaves nothing for a worker thread to build")
	assert_false(CardRegistry._original_set.is_empty())
	assert_true(CardRegistry.originally_printed_in("Erg Raiders", "arn"),
		"and the index it built still answers correctly")
	assert_false(CardRegistry.originally_printed_in("Mountain", "arn"),
		"Mountain is in the Arabian Nights data but was printed in Alpha")


func test_the_one_pass_index_still_credits_the_right_printing() -> void:
	# The artist and printing indexes used to be two passes over the same
	# JSON; merging them into one is what warms both from ensure_loaded().
	# This pins that the merge kept both answers: a 4ed reprint credits
	# 4ed's artist, and a name no snapshot lists credits nobody.
	assert_ne(CardRegistry.artist_of("Air Elemental"), "")
	assert_eq(CardRegistry.artist_of("No Such Card At All"), "")
	assert_eq(CardRegistry.artist_of("Air Elemental", "4ed"),
		CardRegistry.artist_of("Air Elemental"),
		"4ed is the folder Air Elemental ships in")


# ------------------------------- CR 613 layer 3: text changes on a land --

func test_hacking_one_half_of_a_dual_land_keeps_the_other_half() -> void:
	# THE BUG THIS PINS: a "land_type" text change REPLACED the whole live
	# mana-ability list with a single ability for the new type. A dual land
	# has one intrinsic mana ability per basic land type it carries (CR
	# 305.6), so Magical Hack on a Tundra ("island" -> "swamp") left a
	# permanent whose type line still read Plains Swamp but which tapped
	# only for {B} — the {W} was deleted along with the Island.
	var tundra := put_battlefield(0, "Tundra")
	assert_eq(tundra.cur_mana_abilities.size(), 2, "W and U to start with")
	g.change_text(tundra, "land_type", "island", "swamp")
	assert_true(tundra.has_subtype("plains"), "the Plains half is untouched")
	assert_true(tundra.has_subtype("swamp"))
	assert_false(tundra.has_subtype("island"))
	assert_eq(tundra.cur_mana_abilities.size(), 2,
		"still two mana abilities: one per basic land type")
	var colors := 0
	for ability in tundra.cur_mana_abilities:
		for pair in ability.produces:
			colors |= int(pair[0])
	assert_eq(colors, Mtg.ManaColor.W | Mtg.ManaColor.B,
		"the hacked half taps for {B}, the Plains half still for {W}")


func test_hacking_a_land_onto_a_type_it_already_has_does_not_double_it() -> void:
	# The other half of the same rewrite: "Land — Plains Island" with
	# "plains" rewritten to "island" is a plain Island, not an
	# "Island Island" that taps for {U} twice.
	var tundra := put_battlefield(0, "Tundra")
	g.change_text(tundra, "land_type", "plains", "island")
	assert_eq(tundra.cur_subtypes, ["island"] as Array[String])
	assert_eq(tundra.cur_mana_abilities.size(), 1)


# ------------------------------ CR 708.2: a face-down permanent's rules --

func test_a_masked_juggernaut_can_be_blocked_by_a_wall() -> void:
	# THE BUG THIS PINS: three combat restrictions — "can't be blocked by
	# <subtype>", "can't block power N+", "can't be blocked by power N+" —
	# were the only combat characteristics with no live mirror, so
	# `CombatState.block_illegality` read them off the PRINTED CardData. A
	# face-down permanent is a nameless 2/2 with NO abilities (CR 708.2),
	# and `reset_characteristics` wipes every other live list for one — but
	# a Juggernaut put onto the battlefield face down by Illusionary Mask
	# still refused a Wall block, announcing a printed ability the object
	# does not have.
	var jug := give_hand(0, "Juggernaut")
	g.put_from_hand_face_down(jug, 0)
	jug.summoning_sick = false
	var wall := put_battlefield(1, "Wall of Stone")
	assert_eq(CombatState.block_illegality(g, wall, jug, 1), "",
		"a masked 2/2 has no 'can't be blocked by Walls'")


func test_a_masked_ironclaw_orcs_can_block_a_big_creature() -> void:
	# The mirror restriction, read off the blocker's printed data.
	var orcs := give_hand(1, "Ironclaw Orcs")
	g.put_from_hand_face_down(orcs, 1)
	var giant := put_battlefield(0, "Hill Giant")
	assert_eq(CombatState.block_illegality(g, orcs, giant, 1), "",
		"a masked 2/2 has no 'can't block power 2 or greater'")


func test_a_masked_amrou_kithkin_can_be_blocked_by_anything() -> void:
	var kithkin := give_hand(0, "Amrou Kithkin")
	g.put_from_hand_face_down(kithkin, 0)
	kithkin.summoning_sick = false
	var giant := put_battlefield(1, "Hill Giant")
	assert_eq(CombatState.block_illegality(g, giant, kithkin, 1), "",
		"a masked 2/2 has no 'can't be blocked by power 3 or greater'")


# -------------------- 1997 fork: a TAPPED artifact's statics (p.124) --

func test_an_animated_tapped_artifact_keeps_its_static() -> void:
	# THE BUG THIS PINS: the 1997 "a tapped artifact's continuous effects
	# cease — artifact CREATURES excepted" pass ran BEFORE the animation
	# registry was applied, so it judged every permanent on its pass-1
	# types. Its own comment claimed the opposite ("an animated artifact
	# (Jade Statue) is exempt while it is a creature"), which is how it
	# survived: a Cursed Rack animated by Xenic Poltergeist is an artifact
	# creature by the time anything reads it, and the rule exempts it.
	g.rules.tapped_artifacts_stop = true
	var rack := put_battlefield(0, "Cursed Rack")
	var ghost := put_battlefield(0, "Xenic Poltergeist")
	ghost.summoning_sick = false
	g.recalculate()
	assert_eq(g.players[1].max_hand_size, 4, "untapped, the Rack bites")
	rack.tapped = true
	g.recalculate()
	assert_eq(g.players[1].max_hand_size, 7,
		"tapped, a noncreature artifact's static is suspended (manual p.124)")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, ghost, 0, [TargetRef.card(rack)]))
	resolve_stack()
	assert_true(rack.is_creature(), "the Rack is an artifact creature now")
	assert_eq(g.players[1].max_hand_size, 4,
		"and artifact creatures are exempt from the tapped-artifact rule")


# ---------------------------- CONTRIBUTING.md rule 5: live values, not printed --

func test_has_lethal_damage_reads_the_live_type() -> void:
	# THE BUG THIS PINS: the helper asked `data.is_creature()`, the PRINTED
	# type, so an animated land carrying lethal damage answered `false`.
	# Nothing called it (MtgGame's SBA pass inlines the same check), which
	# is exactly what let a rule-5 violation sit on a public method.
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature(), "animated into a 2/2")
	assert_false(factory.has_lethal_damage(), "undamaged")
	factory.damage = 2
	assert_true(factory.has_lethal_damage(),
		"a 2/2 with 2 damage is dead, whatever the card was printed as")
