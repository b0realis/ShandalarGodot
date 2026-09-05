extends GameTest
## Engine pins from the 2026-09 full audit (docs/audit-2026-09.md).
## Every test here failed before the fix recorded in the same row of that
## document; each one names the Comprehensive Rule it protects.


# ------------------------------------------------- CR 613.1: layer 4 vs 7b --

func test_type_changing_statics_run_before_base_pt_setters() -> void:
	# Layer 4 (type/subtype changes) must be applied before layer 7b (base
	# P/T setters): Evil Presence makes a Forest a Swamp, and only then can
	# Kormus Bell see a Swamp to animate.
	var forest := put_battlefield(1, "Forest")
	put_battlefield(0, "Kormus Bell")
	var aura := give_hand(0, "Evil Presence")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(forest)]))
	resolve_stack()
	assert_true(forest.has_subtype("swamp"), "Evil Presence retunes it")
	assert_true(forest.is_creature(), "and Kormus Bell animates every Swamp")
	assert_eq(forest.cur_power, 1)
	assert_eq(forest.cur_toughness, 1)


func test_gaea_s_liege_counts_the_forests_it_just_made() -> void:
	# Same ordering, seen from the other side: the Liege's {T} ability turns
	# a land into a Forest (layer 4), and its own characteristic-defining
	# power (layer 7a/7b) must count that Forest on the same pass.
	put_battlefield(0, "Forest")   # one Forest keeps the 1/1 Liege alive
	var liege := put_battlefield(0, "Gaea's Liege")
	var mountain := put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(liege.cur_power, 1, "one Forest so far")
	assert_ok(g.activate_ability(0, liege, 0, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_true(mountain.has_subtype("forest"))
	assert_eq(liege.cur_power, 2, "the Forest it just made counts too")


# ------------------------------------------------- untap caps (CR 502.2-ish) --

func test_smoke_caps_artifact_creatures_too() -> void:
	# "Players can't untap more than one creature during their untap steps."
	# An ARTIFACT creature is a creature; the untap step used to file each
	# permanent under a single category (land → artifact → creature), so
	# Juggernauts untapped freely under Smoke.
	put_battlefield(1, "Smoke")
	var a := put_battlefield(0, "Juggernaut")
	var b := put_battlefield(0, "Juggernaut")
	a.tapped = true
	b.tapped = true
	advance_to_next_turn()   # opponent's turn
	advance_to_next_turn()   # ours: the untap step runs
	var untapped := int(not a.tapped) + int(not b.tapped)
	assert_eq(untapped, 1, "Smoke lets exactly one of them untap")


# --------------------------------------------- source-filtered targeting bans --

func test_artifact_ward_blocks_an_artifact_source_ability() -> void:
	# "Enchanted creature can't be the target of abilities from artifact
	# sources" — the clause the card's header and the ledger both promised.
	var bear := put_battlefield(0, "Grizzly Bears")
	var ward := give_hand(0, "Artifact Ward")
	var rod := put_battlefield(1, "Rod of Ruin")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 3)
	assert_refused(g.activate_ability(1, rod, 0, [TargetRef.card(bear)]),
		"Illegal target")


func test_wall_of_shadows_ducks_wall_only_targeting() -> void:
	# "Can't be the target of spells or abilities that can target only Walls"
	# — the Glyph cycle is exactly that.
	var shadows := put_battlefield(0, "Wall of Shadows")
	var other := put_battlefield(0, "Wall of Stone")
	var glyph := give_hand(0, "Glyph of Doom")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, glyph, [TargetRef.card(shadows)]))
	# an ordinary Wall is still a legal Glyph target
	assert_ok(g.cast_spell(0, glyph, [TargetRef.card(other)]))


# ------------------------------------------- CR 305.7: a retuned land's text --

func test_blood_moon_strips_a_nonbasic_land_of_its_abilities() -> void:
	# "Nonbasic lands are Mountains": the land loses the abilities its rules
	# text granted (CR 305.7), so Strip Mine keeps only "{T}: Add {R}".
	var mine := put_battlefield(0, "Strip Mine")
	put_battlefield(1, "Blood Moon")
	g.recalculate()
	assert_true(mine.has_subtype("mountain"))
	assert_eq(mine.cur_activated_abilities.size(), 0,
		"the land-destruction ability is gone with the rest of its text")
	assert_eq(mine.cur_mana_abilities.size(), 1)
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)


# ---------------------------------- "a name originally printed in <expansion>" --

func test_city_in_a_bottle_finds_arabian_cards_in_any_set_folder() -> void:
	# The test is the card's NAME, not the folder our implementation happens
	# to live in: Erg Raiders is an Arabian Nights card that ships in
	# cards/sets/4ed/. Basic lands are older than Arabian Nights and stay.
	var raiders := put_battlefield(1, "Erg Raiders")
	var mountain := put_battlefield(1, "Mountain")
	var bottle := give_hand(0, "City in a Bottle")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, bottle))
	resolve_stack()
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mountain.zone, Mtg.Zone.BATTLEFIELD,
		"Mountain was printed in Alpha, not in Arabian Nights")


func test_golgothian_sylex_finds_antiquities_cards_in_any_set_folder() -> void:
	var sylex := put_battlefield(0, "Golgothian Sylex")
	var stone := put_battlefield(1, "Millstone")       # Antiquities, ships in 4ed/
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, sylex, 0, []))
	resolve_stack()
	assert_eq(stone.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(sylex.zone, Mtg.Zone.GRAVEYARD, "the Sylex sweeps itself too")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------ cost modifiers (601.2f) --

func test_a_cost_modifier_only_discounts_its_own_controller() -> void:
	# "Instant and enchantment spells YOU cast cost {2} less" — two Matrices,
	# one each, used to stack into a {4} discount for whoever cast first,
	# because each modifier callback scanned the board for any Matrix.
	var blast := CardRegistry.get_card("Psionic Blast")   # {2}{U} instant
	put_battlefield(0, "Mana Matrix")
	assert_eq(g.spell_surcharge(0, blast), -2, "your own Matrix discounts {2}")
	put_battlefield(1, "Mana Matrix")
	assert_eq(g.spell_surcharge(0, blast), -2,
		"the opponent's Matrix discounts THEIR spells, not yours")
	assert_eq(g.spell_surcharge(1, blast), -2)
	# And two of your own really do stack (each says "spells you cast").
	put_battlefield(0, "Mana Matrix")
	assert_eq(g.spell_surcharge(0, blast), -4)


# ------------------------------------------------------ CR 400.7 / 111.7: zones --

func test_a_bounced_token_ceases_to_exist() -> void:
	# CR 111.7 — a token that leaves the battlefield ceases to exist; it must
	# never turn up in a hand (where it could be recast for free).
	var token: CardInstance = g.create_token(0, CardRegistry.get_card("Grizzly Bears"))[0]
	g.return_to_hand(token)
	assert_eq(g.players[0].hand.size(), 0, "no token card in hand")
	assert_null(g.find_instance(token.id), "and it is gone from the game")


func test_an_exiled_token_ceases_to_exist() -> void:
	var token: CardInstance = g.create_token(0, CardRegistry.get_card("Grizzly Bears"))[0]
	g.exile_permanent(token)
	assert_eq(g.players[0].exile.size(), 0)
	assert_null(g.find_instance(token.id))


func test_a_pump_does_not_follow_a_bounced_creature_back() -> void:
	# CR 400.7 — the card that returns is a NEW object; until-end-of-turn
	# effects keyed to the old one must not re-attach.
	var bear := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	g.return_to_hand(bear)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_eq(bear.cur_power, 2, "the +3/+3 stayed with the old object")


func test_anteing_a_permanent_takes_it_off_the_battlefield_view() -> void:
	var bird := put_battlefield(0, "Jeweled Bird")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, bird, 0, []))
	resolve_stack()
	assert_eq(bird.zone, Mtg.Zone.ANTE)
	assert_false(g.all_battlefield().has(bird), "the battlefield cache went stale")


func test_an_animated_land_that_dies_is_a_creature_dying() -> void:
	# CR 608.2h — last known information: the Factory died as a 2/2 creature.
	var factory := put_battlefield(0, "Mishra's Factory")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	assert_true(factory.is_creature())
	g.destroy(factory, false)
	assert_eq(g.creatures_died_this_turn, 1)


# --------------------------------------------------------------- combat rules --

func test_a_regenerated_blocker_leaves_its_attacker_blocked() -> void:
	# CR 509.1h — regeneration removes the REGENERATED creature from combat;
	# the attacker it was blocking stays blocked and (without trample) deals
	# no damage.
	var wurm := put_battlefield(0, "Craw Wurm")
	var skel := put_battlefield(1, "Drudge Skeletons")
	skel.regeneration_shields = 1
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skel.id: wurm.id}))
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(skel)]))
	resolve_stack()
	assert_eq(skel.zone, Mtg.Zone.BATTLEFIELD, "it regenerated")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the Wurm is still blocked")


func test_stealing_an_attacker_removes_it_from_combat() -> void:
	# CR 506.4 — a permanent is removed from combat when its controller changes.
	var angel := put_battlefield(0, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	g.change_control(angel, 1)
	assert_false(g.combat.attackers.has(angel.id))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "it stopped attacking its new controller")


func test_removing_a_band_member_from_combat_stops_its_damage() -> void:
	var hero := put_battlefield(0, "Benalish Hero")
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [hero.id, giant.id], [[hero.id, giant.id]]))
	g.remove_from_combat(giant)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 19, "only the Hero connects")


func test_a_must_attacker_yields_to_a_ban_instead_of_deadlocking() -> void:
	# CR 508.1d — a restriction always beats a requirement; an unsatisfiable
	# requirement is simply not met. Festival + Juggernaut used to make the
	# declare-attackers step impossible to leave.
	put_battlefield(0, "Juggernaut")
	g.no_attacks_this_turn = true
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, []))


func test_lure_is_not_satisfied_by_blocking_someone_else() -> void:
	# CR 509.1c — "all creatures able to block IT do so".
	var lured := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Hill Giant")
	var lure := give_hand(0, "Lure")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, lure, [TargetRef.card(lured)]))
	resolve_stack()
	var wall := put_battlefield(1, "Wall of Wood")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [lured.id, other.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: other.id}), "must block")
	assert_ok(g.declare_blockers(1, {wall.id: lured.id}))


func test_a_blocker_assigns_its_damage_in_one_packet() -> void:
	# CR 510.1c — a blocker assigns all its combat damage to what it blocks
	# as ONE event, so Jade Monolith's one-shot redirection soaks all of it.
	var bear := put_battlefield(0, "Grizzly Bears")
	var monolith := put_battlefield(0, "Jade Monolith")
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wurm.id: bear.id}))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, monolith, 0, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 14, "all six points were redirected")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


func test_attacked_this_turn_expires_for_both_players() -> void:
	# "This turn" state must expire with the turn for EVERY permanent, not
	# just the active player's (Berserk, Clockwork Beast and Lurker read it).
	var wurm := put_battlefield(1, "Craw Wurm")
	advance_to_next_turn()          # the opponent's turn
	run_combat([wurm.id])
	assert_true(wurm.attacked_this_turn)
	advance_to_next_turn()          # back to ours
	assert_false(wurm.attacked_this_turn, "a new turn, a clean slate")


# ----------------------------------------------------------- copies and spells --

func test_a_countered_copy_of_a_spell_never_becomes_a_card() -> void:
	# CR 707.10a — a copy is not a card; countering it makes it cease to exist.
	var bolt := give_hand(0, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var copy := g.copy_spell_on_stack(bolt, 0)
	assert_not_null(copy)
	g.counter_spell(copy)
	assert_eq(g.players[0].graveyard.size(), 0, "no phantom card in a graveyard")
	assert_null(g.find_instance(copy.id))


func test_a_copy_keeps_its_borrowed_dies_trigger() -> void:
	# CR 608.2h — the dies-trigger of a Clone that copied Onulet fires from
	# the identity it had as it left the battlefield.
	put_battlefield(1, "Onulet")
	var clone := give_hand(0, "Clone")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, clone))
	resolve_stack()
	assert_eq(clone.data.card_name, "Onulet")
	g.destroy(clone, false)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "the copy's own dies-trigger paid out")


func test_a_shifted_doppelganger_brings_its_new_static_along() -> void:
	# become_copy must invalidate the derived battlefield indexes, or the
	# copy's static abilities are never run — and a 0/0 printed body dies.
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var nightmare := put_battlefield(1, "Nightmare")
	var doppel := put_battlefield(0, "Grizzly Bears")
	g.become_copy(doppel, nightmare.data)
	assert_eq(doppel.zone, Mtg.Zone.BATTLEFIELD,
		"its copied ability makes it a 2/2, so it does not die as a 0/0")
	assert_eq(doppel.cur_power, 2, "two Swamps of its own")
	assert_eq(doppel.cur_toughness, 2)


func test_an_ability_with_no_legal_target_is_countered() -> void:
	# CR 608.2b — an ability whose targets are all illegal is countered, so
	# Psionic Entity's self-damage rider does not happen either.
	var entity := put_battlefield(0, "Psionic Entity")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.activate_ability(0, entity, 0, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(entity.zone, Mtg.Zone.BATTLEFIELD, "the whole ability was countered")


func test_an_aura_falls_off_when_its_host_stops_being_a_creature() -> void:
	# CR 704.5m — an Aura attached to an illegal object goes to the graveyard.
	var factory := put_battlefield(0, "Mishra's Factory")
	var fire := give_hand(0, "Firebreathing")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, factory, 0, []))
	resolve_stack()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, fire, [TargetRef.card(factory)]))
	resolve_stack()
	advance_to_next_turn()
	assert_false(factory.is_creature())
	assert_eq(fire.zone, Mtg.Zone.GRAVEYARD)
	assert_true(factory.attachments.is_empty())


# ----------------------------------------------------------------- mana rules --

func test_a_cost_reduction_applies_to_the_chosen_x() -> void:
	# CR 601.2f — X is part of the total cost before reductions apply, so a
	# reducer may eat generic mana that X contributed.
	put_battlefield(0, "Mana Matrix")   # instant/enchantment spells cost {2} less
	var howl := give_hand(0, "Howl from Beyond")   # {X}{B}
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, howl, [TargetRef.card(bear)], 3))
	resolve_stack()
	assert_eq(bear.cur_power, 5)


func test_a_refused_mana_ability_pays_nothing() -> void:
	# CR 601.2h — costs are paid only once the whole cost is payable.
	var stones := put_battlefield(0, "Standing Stones")
	g.players[0].life = 0
	g.players[0].cant_lose_to_life = true
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.tap_for_mana(0, stones), "life")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 1,
		"the {1} was not spent")
	assert_false(stones.tapped)


func test_seed_zero_is_a_real_seed() -> void:
	var deck: Array = []
	for _i in 40:
		deck.append("Forest")
	var a := MtgGame.new()
	a.setup(deck, deck, "A", "B", 20, 20, 0)
	var b := MtgGame.new()
	b.setup(deck, deck, "A", "B", 20, 20, 0)
	var ids_a: Array = []
	var ids_b: Array = []
	for i in 5:
		ids_a.append(a.players[0].library[i].id)
		ids_b.append(b.players[0].library[i].id)
	assert_eq(ids_a, ids_b, "seed 0 must reproduce, like every other seed")


# ------------------------------------------------- printed colour (CR 105.2b) --

func test_the_kobolds_are_red_despite_costing_nothing() -> void:
	# The three Legends Kobolds cost {0} and are still RED cards (Scryfall
	# agrees) — a colour indicator, not a colour derived from the cost.
	for name in ["Crimson Kobolds", "Crookshank Kobolds", "Kobolds of Kher Keep"]:
		var kobold := put_battlefield(0, name)
		assert_true(kobold.has_color(Mtg.ManaColor.R), "%s is red" % name)
		assert_false(kobold.is_colorless(), "%s is not colourless" % name)


func test_only_false_orders_unblocks_the_creature_it_freed() -> void:
	# CR 509.1h is the default — a blocker that leaves combat leaves its
	# attacker blocked — and False Orders' middle sentence is the printed
	# exception. Both halves have to be true at once.
	var wurm := put_battlefield(0, "Craw Wurm")
	var giant := put_battlefield(0, "Hill Giant")
	var skel := put_battlefield(1, "Drudge Skeletons")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id, giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {skel.id: wurm.id, bear.id: giant.id}))
	g.remove_from_combat(skel)              # the default rule
	assert_true(g.combat.was_blocked([wurm.id]),
		"the Wurm stays blocked with nothing blocking it")
	g.remove_from_combat(bear, true)        # False Orders' printed override
	assert_false(g.combat.was_blocked([giant.id]),
		"the Giant was blocked by that creature ALONE, so it is unblocked")


func test_a_retyped_land_is_not_animated_by_its_old_type() -> void:
	# CR 613.8 by construction: Blood Moon RETYPES (layer 4a) before Kormus
	# Bell ANIMATES (layer 4b), so a dual land that stops being a Swamp is a
	# plain Mountain — not a 1/1 black creature that is also a Mountain.
	var badlands := put_battlefield(0, "Badlands")   # Swamp Mountain
	put_battlefield(0, "Kormus Bell")
	g.recalculate()
	assert_true(badlands.is_creature(), "a Swamp, so the Bell animates it")
	put_battlefield(1, "Blood Moon")
	g.recalculate()
	assert_true(badlands.has_subtype("mountain"))
	assert_false(badlands.has_subtype("swamp"))
	assert_false(badlands.is_creature(), "it is no longer a Swamp to animate")


func test_titanias_song_silences_a_type_changing_static() -> void:
	# "Each noncreature artifact loses all abilities" is CR 613 layer 6,
	# which precedes every P/T layer — so a silenced Kormus Bell animates
	# nothing, whichever of the two entered first.
	var swamp := put_battlefield(0, "Swamp")
	put_battlefield(0, "Kormus Bell")
	g.recalculate()
	assert_true(swamp.is_creature())
	put_battlefield(1, "Titania's Song")
	g.recalculate()
	assert_false(swamp.is_creature(), "the Bell lost its ability")


func test_meekstone_sees_counters_a_creature_entered_with() -> void:
	# Meekstone reads power, so the counters pass (layer 7d) has to be done
	# by the time it runs: Clockwork Beast is a printed 0/4 that enters with
	# seven +1/+0 counters.
	var beast := put_battlefield(0, "Clockwork Beast")
	put_battlefield(1, "Meekstone")
	g.recalculate()
	assert_eq(beast.cur_power, 7)
	assert_true(beast.cur_skips_untap, "power 3 or greater: it stays tapped")
