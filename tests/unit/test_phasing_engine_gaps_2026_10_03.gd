extends GameTest
## The engine-side PHASING GAPS the 2026-10-03 phasing audit of the older
## cards found (scratch: phase_audit/engine_gaps.md), each reproduced here
## before it was closed. CR 702.26b: a phased-out permanent "can't affect or
## be affected by anything else in the game"; 702.26e: a continuous effect a
## resolving spell or ability creates does not include it; 702.26f: "for as
## long as" durations that track it end when it phases out; 702.26d: it never
## LEAVES the battlefield, so "until it leaves" effects go on.
##
## (a) set_color / become_copy / add_point_redirect on a phased-out permanent
## (b) move_to_ante corrupting a phased-out permanent
## (c) the ContinuousEffects adders naming a phased-out instance
## (d) Old Man of the Sea's victim-tracking cap surviving the victim phasing
## (e) Johan's offer with Johan phased out
## (f) a redirection onto a phased-out creature swallowing the damage
## (g) "while the source stays tapped" resuming after the source phased
## (h) Gaea's Liege / Cyclopean Tomb reverting while their source is out;
##     Bronze Tablet's owner swap reaching a phased-out Tablet
## (i) a static play ban working from a silenced or suspended source


func _bear(pid: int, card_name := "Test Bear", power := 2, toughness := 2) -> CardInstance:
	return put_synthetic(pid, CardData.new(card_name, "{1}{G}",
		Mtg.CardType.CREATURE).pt(power, toughness))


## No zone list holds [param inst] but its owner's/controller's phased_out.
func _still_parked(inst: CardInstance) -> void:
	assert_true(inst.phased_out, "still phased out")
	assert_eq(inst.zone, Mtg.Zone.BATTLEFIELD)
	var parked := 0
	for p in g.players:
		parked += p.phased_out.count(inst)
		for list in [p.battlefield, p.ante, p.exile, p.graveyard, p.hand, p.library]:
			assert_false(list.has(inst), "not in any other zone list")
	assert_eq(parked, 1, "parked exactly once")


# ------------------------------------------------------------------- (a) --

func test_set_color_does_not_reach_a_phased_out_permanent() -> void:
	var bear := _bear(0)
	assert_true(g.phase_out(bear))
	g.set_color(bear, Mtg.ManaColor.R)
	assert_true(g.phase_in(bear))
	assert_eq(bear.cur_colors, Mtg.ManaColor.G, "702.26e: the Lace never included it")


func test_become_copy_does_not_reach_a_phased_out_permanent() -> void:
	var bear := _bear(0)
	var giant := _bear(1, "Test Giant", 5, 5)
	assert_true(g.phase_out(bear))
	g.become_copy(bear, g.copiable_data(giant))
	assert_true(g.phase_in(bear))
	assert_eq(bear.data.card_name, "Test Bear")
	assert_eq(bear.cur_power, 2)


func test_a_point_redirect_is_not_booked_on_a_phased_out_permanent() -> void:
	var bear := _bear(0)
	assert_true(g.phase_out(bear))
	g.add_point_redirect(bear, 0, 1)
	assert_eq(bear.damage_point_redirects, 0)


# ------------------------------------------------------------------- (b) --

func test_a_phased_out_permanent_cannot_be_anted() -> void:
	var bear := _bear(0)
	assert_true(g.phase_out(bear))
	g.move_to_ante(bear)
	_still_parked(bear)
	assert_true(g.phase_in(bear))
	assert_true(g.players[0].battlefield.has(bear))


# ------------------------------------------------------------------- (c) --

func test_a_floating_effect_created_while_it_is_phased_out_never_includes_it() -> void:
	var bear := _bear(0)
	assert_true(g.phase_out(bear))
	var c := g.continuous
	c.add_until_eot_pump(bear.id, 3, 3, [Mtg.Keyword.FLYING])
	c.add_until_eot_keywords(bear.id, [Mtg.Keyword.TRAMPLE])
	c.add_until_eot_protection(bear.id, Mtg.ManaColor.R)
	c.add_until_eot_color(bear.id, Mtg.ManaColor.B)
	c.add_until_eot_base_pt(bear.id, 7, 7)
	c.add_until_eot_animation(bear.id, Mtg.CardType.ARTIFACT, 6, 6)
	c.add_until_eot_pt_switch(bear.id)
	c.add_until_eot_loss(bear.id, [Mtg.Keyword.REACH])
	c.add_granted_activated_ability(bear.id, ActivatedAbility.new("{0}", false, [],
		"{0}: Nothing."))
	assert_true(g.phase_in(bear))
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "no pump, set, switch")
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING))
	assert_false(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_eq(bear.cur_protection, 0)
	assert_eq(bear.cur_colors, Mtg.ManaColor.G)
	assert_false(bear.is_type(Mtg.CardType.ARTIFACT))
	assert_eq(bear.cur_activated_abilities.size(), 0)


func test_a_floating_effect_from_before_it_phased_out_still_applies() -> void:
	# The other half: the effect INCLUDED it when it was created, and the
	# same object came back (702.26d/e) — it applies until it expires.
	var bear := _bear(0)
	g.continuous.add_until_eot_pump(bear.id, 3, 3)
	g.recalculate()
	assert_true(g.phase_out(bear))
	assert_true(g.phase_in(bear))
	assert_eq(bear.cur_power, 5)


# ------------------------------------------------------------------- (d) --

func test_a_leash_capped_by_the_victims_power_ends_when_the_victim_phases_out() -> void:
	# Old Man of the Sea: "for as long as this creature remains tapped AND
	# that creature's power remains less than or equal to this creature's
	# power" — the second half tracks the VICTIM (702.26f).
	var old_man := _bear(0, "Test Old Man", 3, 3)
	var victim := _bear(1, "Test Victim")
	g.tap_permanent(old_man)
	g.gain_control_leashed(victim, old_man, true, true, false)
	assert_eq(victim.controller_id, 0)
	assert_true(g.phase_out(victim))
	assert_true(g.phase_in(victim))
	assert_eq(victim.controller_id, 1, "the duration that tracked it ended")


func test_a_leash_tracking_only_its_source_survives_the_victim_phasing() -> void:
	var leash := _bear(0, "Test Leash")
	var victim := _bear(1, "Test Victim")
	g.tap_permanent(leash)
	g.gain_control_leashed(victim, leash, true, false, false)
	assert_eq(victim.controller_id, 0)
	assert_true(g.phase_out(victim))
	assert_true(g.phase_in(victim))
	assert_eq(victim.controller_id, 0, "it tracks the leash, not the victim")


# ------------------------------------------------------------------- (e) --

func test_johans_offer_needs_johan_present() -> void:
	var johan := _bear(0, "Test Johan", 5, 4)
	g.attacks_without_tapping[0] = johan.id
	assert_true(g._attacks_without_tapping_now(0))
	assert_true(g.phase_out(johan))
	assert_false(g._attacks_without_tapping_now(0), "a phased-out Johan spares nobody")


# ------------------------------------------------------------------- (f) --

func test_a_redirection_onto_a_phased_out_creature_does_not_apply() -> void:
	# CR 614.6: a replacement that can't do what it says doesn't apply —
	# the damage goes where it was going.
	var source := _bear(1, "Test Source")
	var soak := _bear(0, "Test Soak", 4, 4)
	assert_true(g.phase_out(soak))
	var packet := g._plan_damage(source, TargetRef.player(0), 2, false)
	assert_eq(g.redirect_damage(packet, TargetRef.card(soak)), -1, "not redirected")
	assert_eq(packet.remaining(), 2, "nothing was taken out of the event")
	g._land_damage(packet)
	assert_eq(g.players[0].life, 18, "it landed on the player")
	assert_eq(soak.damage, 0)


# ------------------------------------------------------------------- (g) --

func test_phasing_out_breaks_the_continuity_markers() -> void:
	var bear := _bear(0)
	var untaps := bear.untap_sequence
	var phases := bear.phase_sequence
	assert_true(g.phase_out(bear))
	assert_eq(bear.untap_sequence, untaps + 1, "'remains tapped' durations end")
	assert_eq(bear.phase_sequence, phases + 1, "'remains on the battlefield' ones too")
	assert_true(g.phase_in(bear))
	assert_eq(bear.phase_sequence, phases + 1, "phasing in breaks nothing")


func test_battle_gear_stops_for_good_when_the_gear_phases_out() -> void:
	# "+2/-2 for as long as Ashnod's Battle Gear remains tapped": the Gear
	# phasing out ends it (702.26f), and phasing back in still tapped must
	# not bring it back.
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	var body := _bear(0, "Test Body", 2, 4)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(body)]))
	resolve_stack()
	assert_eq([body.cur_power, body.cur_toughness], [4, 2])
	assert_true(g.phase_out(gear))
	assert_eq(body.cur_power, 2)
	assert_true(g.phase_in(gear))
	assert_true(gear.tapped, "it came back still tapped")
	assert_eq([body.cur_power, body.cur_toughness], [2, 4], "and the effect is over")


func test_battle_gear_survives_its_creature_phasing() -> void:
	# The duration tracks the Gear, not the creature.
	var gear := put_battlefield(0, "Ashnod's Battle Gear")
	var body := _bear(0, "Test Body", 2, 4)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, gear, 0, [TargetRef.card(body)]))
	resolve_stack()
	assert_true(g.phase_out(body))
	assert_true(g.phase_in(body))
	assert_eq([body.cur_power, body.cur_toughness], [4, 2])


# ------------------------------------------------------------------- (h) --

func test_gaeas_liege_forest_outlasts_the_liege_phasing_out() -> void:
	# "Until this creature leaves the battlefield" — phasing is not leaving
	# (702.26d), so the land stays a Forest while the Liege is phased out.
	put_battlefield(0, "Forest")
	var liege := put_battlefield(0, "Gaea's Liege")
	var mountain := put_battlefield(1, "Mountain")
	assert_ok(g.activate_ability(0, liege, 0, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_true(mountain.has_subtype("forest"))
	assert_true(g.phase_out(liege))
	assert_true(mountain.has_subtype("forest"), "the Liege hasn't left")
	assert_true(g.phase_in(liege))
	assert_true(mountain.has_subtype("forest"))
	g.destroy(liege)
	assert_true(mountain.has_subtype("mountain"), "it left: the duration is over")
	assert_false(mountain.has_subtype("forest"))


func test_a_mired_land_stays_a_swamp_while_the_tomb_is_phased_out() -> void:
	# "That land is a Swamp for as long as it has a mire counter on it" —
	# nothing about the Tomb.
	var tomb := put_battlefield(0, "Cyclopean Tomb")
	var mountain := put_battlefield(1, "Mountain")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, tomb, 0, [TargetRef.card(mountain)]))
	resolve_stack()
	assert_true(mountain.has_subtype("swamp"))
	assert_true(g.phase_out(tomb))
	assert_true(mountain.has_subtype("swamp"), "the counter is still there")
	g.remove_counters(mountain, "mire", 1)
	assert_true(mountain.has_subtype("mountain"), "and without it, no Swamp")


func test_bronze_tablet_phased_out_in_response_is_left_alone() -> void:
	var tablet := put_battlefield(0, "Bronze Tablet")
	g.untap_permanent(tablet)
	var hostage := _bear(1, "Test Hostage")
	g.players[1].life = 8   # cannot pay the ransom
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.activate_ability(0, tablet, 0, [TargetRef.card(hostage)]))
	assert_true(g.phase_out(tablet))
	resolve_stack()
	_still_parked(tablet)
	assert_eq(tablet.owner_id, 0, "a phased-out Tablet changes owner for nobody")
	assert_eq(hostage.zone, Mtg.Zone.EXILE)


# ------------------------------------------------------------------- (i) --

static func _silence_worms(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.data.card_name == "Worms of the Earth":
			inst.cur_abilities_silenced = true


func test_a_play_ban_stops_while_its_source_is_phased_out() -> void:
	var worms := put_battlefield(0, "Worms of the Earth")
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.play_land(0, land), "Worms of the Earth")
	assert_true(g.phase_out(worms))
	assert_ok(g.play_land(0, land))


func test_a_play_ban_stops_while_its_source_has_lost_its_abilities() -> void:
	put_battlefield(0, "Worms of the Earth")
	put_synthetic(1, CardData.new("Test Silence", "{1}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_silence_worms,
			"Worms of the Earth loses all abilities.").silencing_abilities()))
	var land := give_hand(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.play_banned(0, land.data), "")
	assert_ok(g.play_land(0, land))


func test_a_tapped_artifacts_ban_stops_under_the_1997_rule() -> void:
	g.rules.tapped_artifacts_stop = true
	var city := put_battlefield(0, "City in a Bottle")
	var desert := give_hand(0, "Desert")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.play_land(0, desert), "City in a Bottle")
	g.tap_permanent(city)
	assert_eq(g.play_banned(0, desert.data), "",
		"a tapped artifact's continuous effects cease (manual p.124)")


# ------------------------------------- (g) a duration tracking only the source --

func after_each() -> void:
	CardPacks.set_enabled("pack-5", false)


func test_stromgald_spys_reveal_ends_for_good_when_the_spy_phases_out() -> void:
	# "For as long as this creature remains on the battlefield": phasing is
	# not leaving, but the duration TRACKS the Spy, so it ends (702.26f) and
	# does not come back with it.
	CardPacks.set_enabled("pack-5", true)
	var spy := put_battlefield(0, "Stromgald Spy")
	give_hand(1, "Forest")   # something to reveal: the seat says yes
	run_combat([spy.id])
	assert_true(g.players[1].hand_revealed, "unblocked: the hand is revealed")
	assert_true(g.phase_out(spy))
	assert_false(g.players[1].hand_revealed)
	assert_true(g.phase_in(spy))
	assert_false(g.players[1].hand_revealed, "the duration ended as it phased out")
