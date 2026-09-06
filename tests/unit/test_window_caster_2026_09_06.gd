extends GameTest
## THE WINDOW CASTER (2026-09-06). Twelve cards in the pool carry a "Cast
## this spell only ..." rider that keeps them out of their caster's own
## main phase altogether, and every one of them sat in hand for the whole
## duel: [method AiPlayer._try_cast_best] runs only in our main phase,
## where the rider refuses them, and nothing outside it asked
## (docs/ROADMAP.md, the dead-card sweep's class 1). [method
## AiPlayer._cast_in_window] is the last arm of `_respond_action`: it
## admits only a spell whose rider refuses BOTH of our main phases
## ([method MtgGame.rider_admits_own_main]), fires nothing an existing
## responder holds ([method AiPlayer._claimed_by_a_responder]), and
## prices the card's SHAPE from the board ([constant
## EffectIntent.WINDOW_SHAPES], [method AiPlayer._window_worth]). Gated by
## [member AiProfile.casts_timed_spells], on for Sorcerer and Wizard.


func _ai(profile: AiProfile, seat := 1) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


## Seat 0's turn (it is turn 1, seat 0 active): reach [param step] with seat
## 0 holding priority, then hand priority to seat 1 — the AI's seat in the
## "their turn" tests.
func _their(step: int) -> void:
	var guard := 0
	while not (g.active_player == 0 and g.current_step() == step
			and g.priority_player == 0 and not g.awaiting_attackers) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached seat 0's %s" % Mtg.step_name(step))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


## Seat 0 attacks with [param ids] and hands priority to seat 1 in the
## declare-attackers step.
func _they_attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


# ------------------------------------------------------------ the gate --

func test_the_probe_tells_a_window_card_from_a_planners_card() -> void:
	# The class-1 definition, asked of the rider itself: a rider that
	# admits either of our main phases is the main-phase planner's.
	for card_name in ["Festival", "Siren's Call", "Reset", "Teleport",
			"False Orders", "Blaze of Glory", "Disharmony", "Camouflage"]:
		assert_false(g.rider_admits_own_main(0, give_hand(0, card_name)),
			"%s has no main-phase window" % card_name)
	for card_name in ["Berserk", "Rapid Fire", "Glyph of Reincarnation"]:
		assert_true(g.rider_admits_own_main(0, give_hand(0, card_name)),
			"%s can be cast in a main phase of ours" % card_name)
	assert_true(g.rider_admits_own_main(0, give_hand(0, "Lightning Bolt")),
		"no rider at all")
	# Asked from the OTHER seat's turn, and the turn structure is put back.
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var step := g.current_step()
	assert_false(g.rider_admits_own_main(0, give_hand(0, "Siren's Call")))
	assert_true(g.rider_admits_own_main(0, give_hand(0, "Berserk")))
	assert_eq(g.active_player, 1, "the probe restores the active player")
	assert_eq(g.current_step(), step, "and the step")


func test_a_card_a_responder_holds_is_not_the_window_casters() -> void:
	var ai := _ai(AiProfile.wizard())
	for card_name in ["Fog", "Counterspell", "Lightning Bolt", "Giant Growth",
			"Terror", "Unsummon", "Ancestral Recall", "Dark Ritual", "Twiddle",
			"Howl from Beyond", "Healing Salve"]:
		var data := CardRegistry.get_card(card_name)
		assert_true(ai._claimed_by_a_responder(data,
			EffectIntent.read(data.spell_effects, card_name)),
			"%s belongs to a responder" % card_name)
	for card_name in ["Festival", "Siren's Call", "Reset", "Disharmony",
			"Blaze of Glory", "False Orders", "Teleport"]:
		var data := CardRegistry.get_card(card_name)
		assert_false(ai._claimed_by_a_responder(data,
			EffectIntent.read(data.spell_effects, card_name)),
			"%s belongs to no responder" % card_name)


func test_the_arm_does_not_fire_a_fog_the_fog_arm_declined() -> void:
	# Two damage at twenty life is beneath the Fog's bar, and the window
	# caster — running after it — must not reach for the Fog either.
	var ai := _ai(AiProfile.wizard())
	var fog := give_hand(1, "Fog")
	put_battlefield(1, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass")
	assert_eq(fog.zone, Mtg.Zone.HAND, "the Fog is held")


func test_the_arm_does_not_fire_a_counter_under_the_threshold() -> void:
	var ai := _ai(AiProfile.wizard())
	var counter := give_hand(1, "Counterspell")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	var bears := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, bears, []))
	assert_ok(g.pass_priority(0))
	assert_eq(ai.act(g), "pass")
	assert_eq(counter.zone, Mtg.Zone.HAND)


func test_a_rider_the_planner_can_use_stays_the_planners() -> void:
	# Berserk is legal here (before combat damage) and its rider admits
	# our own first main, so the window caster leaves it alone — the
	# pump arm, not this one, decides about a Berserk.
	var ai := _ai(AiProfile.wizard())
	var berserk := give_hand(1, "Berserk")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	_they_attack([bears.id])
	assert_eq(ai.act(g), "pass")
	assert_eq(berserk.zone, Mtg.Zone.HAND)


# --------------------------------------------------------- the shapes --

func test_festival_is_cast_at_their_upkeep_before_a_big_swing() -> void:
	var ai := _ai(AiProfile.wizard())
	var festival := give_hand(1, "Festival")
	put_battlefield(1, "Plains")
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Grizzly Bears")
	_their(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "cast Festival in its window")
	resolve_stack()
	assert_eq(festival.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.no_attacks_this_turn, "no creature attacks this turn")


func test_festival_is_held_against_a_small_swing() -> void:
	# Two power at twenty life is the Fog arm's "let it through", and the
	# same bar holds here: the card waits for a turn worth it.
	var ai := _ai(AiProfile.wizard())
	var festival := give_hand(1, "Festival")
	put_battlefield(1, "Plains")
	put_battlefield(0, "Grizzly Bears")
	_their(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass")
	assert_eq(festival.zone, Mtg.Zone.HAND)


func test_sirens_call_sends_their_bears_into_our_giant() -> void:
	var ai := _ai(AiProfile.wizard())
	var call := give_hand(1, "Siren's Call")
	put_battlefield(1, "Island")
	put_battlefield(1, "Hill Giant")
	var bears := put_battlefield(0, "Grizzly Bears")
	_their(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "cast Siren's Call in its window")
	resolve_stack()
	assert_eq(call.zone, Mtg.Zone.GRAVEYARD)
	assert_true(bears.must_attack_this_turn, "the Bears attack or die")


func test_sirens_call_is_held_when_the_forced_swing_would_hurt_us() -> void:
	# A Craw Wurm forced into a lone Grizzly Bears is six damage to us and
	# nothing to them; a card that makes that happen is not cast.
	var ai := _ai(AiProfile.wizard())
	var call := give_hand(1, "Siren's Call")
	put_battlefield(1, "Island")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(0, "Craw Wurm")
	_their(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass")
	assert_eq(call.zone, Mtg.Zone.HAND)


func test_reset_untaps_the_lands_a_held_counter_needs() -> void:
	# Tapped out over our own turn with a Counterspell in hand: Reset in
	# their main phase gives the counter its mana back — and pays for
	# itself, since the two Islands it taps untap with the rest.
	var ai := _ai(AiProfile.wizard())
	var reset := give_hand(1, "Reset")
	give_hand(1, "Counterspell")
	var islands: Array[CardInstance] = []
	for _i in 5:
		islands.append(put_battlefield(1, "Island"))
	for i in 3:
		islands[i].tapped = true
	_their(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "cast Reset in its window")
	resolve_stack()
	assert_eq(reset.zone, Mtg.Zone.GRAVEYARD)
	for island in islands:
		assert_false(island.tapped, "every Island untapped")


func test_reset_is_held_when_nothing_in_hand_is_waiting_for_the_mana() -> void:
	var ai := _ai(AiProfile.wizard())
	var reset := give_hand(1, "Reset")
	var islands: Array[CardInstance] = []
	for _i in 5:
		islands.append(put_battlefield(1, "Island"))
	for i in 3:
		islands[i].tapped = true
	_their(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_eq(reset.zone, Mtg.Zone.HAND)


func test_disharmony_steals_the_attacker_that_makes_the_swing_lethal() -> void:
	var ai := _ai(AiProfile.wizard())
	var disharmony := give_hand(1, "Disharmony")
	for _i in 3:
		put_battlefield(1, "Mountain")
	g.players[1].life = 5
	var serra := put_battlefield(0, "Serra Angel")
	var bears := put_battlefield(0, "Grizzly Bears")
	_they_attack([serra.id, bears.id])
	assert_eq(ai.act(g), "cast Disharmony in its window")
	resolve_stack()
	assert_eq(disharmony.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.controller_id, 1, "the Angel is ours for the turn")
	assert_false(g.combat.attackers.has(serra.id), "and out of combat")
	assert_false(serra.tapped)


func test_blaze_of_glory_puts_the_wall_in_front_of_the_whole_team() -> void:
	# One Wall of Stone blocks one Bears and four damage lands; with the
	# Blaze it blocks all three and nothing does.
	var ai := _ai(AiProfile.wizard())
	var blaze := give_hand(1, "Blaze of Glory")
	put_battlefield(1, "Plains")
	var wall := put_battlefield(1, "Wall of Stone")
	var ids: Array = []
	for _i in 3:
		ids.append(put_battlefield(0, "Grizzly Bears").id)
	_they_attack(ids)
	assert_eq(ai.act(g), "cast Blaze of Glory in its window")
	resolve_stack()
	assert_eq(blaze.zone, Mtg.Zone.GRAVEYARD)
	assert_true(wall.must_block_this_turn)
	assert_eq(wall.extra_blocks_this_turn, -1, "any number of blocks")


func test_blaze_of_glory_is_held_against_a_single_attacker() -> void:
	var ai := _ai(AiProfile.wizard())
	var blaze := give_hand(1, "Blaze of Glory")
	put_battlefield(1, "Plains")
	put_battlefield(1, "Wall of Stone")
	var bears := put_battlefield(0, "Grizzly Bears")
	_they_attack([bears.id])
	assert_eq(ai.act(g), "pass", "a single block needs no Blaze")
	assert_eq(blaze.zone, Mtg.Zone.HAND)


func test_false_orders_pulls_the_wall_off_the_lethal_wurm() -> void:
	# Our Wurm is blocked by their Wall and our Bears connect for two at
	# four life: the pull frees the Wurm for lethal, and the Wall — sent
	# where the card's own hint sends it — lands on the Bears instead.
	var ai := _ai(AiProfile.wizard(), 0)
	var orders := give_hand(0, "False Orders")
	put_battlefield(0, "Mountain")
	var wurm := put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Wall of Stone")
	g.players[1].life = 4
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id, bears.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wurm.id}))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "cast False Orders in its window")
	resolve_stack()
	assert_eq(orders.zone, Mtg.Zone.GRAVEYARD)
	assert_false(g.combat.was_blocked(g.combat.band_of(wurm.id)), "the Wurm is unblocked")
	assert_eq(g.combat.blockers_of(bears.id), [wall.id], "the Wall blocks the Bears")


func test_false_orders_is_held_when_the_hint_would_send_the_blocker_straight_back() -> void:
	# A lone attacker: the freed Wurm is the smallest unblocked attacker,
	# so the Wall would block it again and the card would buy nothing.
	var ai := _ai(AiProfile.wizard(), 0)
	var orders := give_hand(0, "False Orders")
	put_battlefield(0, "Mountain")
	var wurm := put_battlefield(0, "Craw Wurm")
	var wall := put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {wall.id: wurm.id}))
	assert_eq(ai.act(g), "pass")
	assert_eq(orders.zone, Mtg.Zone.HAND)


func test_teleport_makes_the_lethal_attacker_unblockable() -> void:
	var ai := _ai(AiProfile.wizard(), 0)
	var teleport := give_hand(0, "Teleport")
	for _i in 3:
		put_battlefield(0, "Island")
	var wurm := put_battlefield(0, "Craw Wurm")
	var wall := put_battlefield(1, "Wall of Stone")
	g.players[1].life = 6
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "cast Teleport in its window")
	resolve_stack()
	assert_eq(teleport.zone, Mtg.Zone.GRAVEYARD)
	assert_refused(CombatState.block_illegality(g, wall, wurm, 1))


func test_teleport_is_held_when_nothing_of_theirs_could_block() -> void:
	var ai := _ai(AiProfile.wizard(), 0)
	var teleport := give_hand(0, "Teleport")
	for _i in 3:
		put_battlefield(0, "Island")
	var wurm := put_battlefield(0, "Craw Wurm")
	g.players[1].life = 6
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	assert_eq(ai.act(g), "pass", "unblockable already")
	assert_eq(teleport.zone, Mtg.Zone.HAND)


func test_camouflage_is_left_in_hand() -> void:
	# A coin flip the defender half-controls has no reading; the shape
	# table has no row for it, and no row means no cast.
	var ai := _ai(AiProfile.wizard(), 0)
	var camouflage := give_hand(0, "Camouflage")
	put_battlefield(0, "Forest")
	var wurm := put_battlefield(0, "Craw Wurm")
	put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	assert_eq(ai.act(g), "pass")
	assert_eq(camouflage.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------- the reader --

func test_the_reader_names_the_shape_and_keeps_the_effect_unknown() -> void:
	var festival := CardRegistry.get_card("Festival")
	var intent := EffectIntent.read(festival.spell_effects, "Festival")
	assert_eq(intent.window, EffectIntent.Shape.STOPS_ATTACKS)
	assert_true(intent.unknown, "the second table does not make the effect known")
	var teleport := CardRegistry.get_card("Teleport")
	intent = EffectIntent.read(teleport.spell_effects, "Teleport")
	assert_eq(intent.window, EffectIntent.Shape.NONE, "Teleport is read structurally")
	assert_true(intent.pump_keywords.has(Mtg.Keyword.UNBLOCKABLE))
	assert_true(intent.pumps)
	assert_eq(intent.pump_toughness, 0)
	var bolt := CardRegistry.get_card("Lightning Bolt")
	assert_eq(EffectIntent.read(bolt.spell_effects, "Lightning Bolt").window,
		EffectIntent.Shape.NONE)


# ------------------------------------------------------------ the knob --

func test_with_the_knob_off_nothing_changes() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("casts_timed_spells=off"), "")
	assert_false(profile.casts_timed_spells)
	var ai := _ai(profile)
	var festival := give_hand(1, "Festival")
	put_battlefield(1, "Plains")
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Grizzly Bears")
	_their(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass")
	assert_eq(festival.zone, Mtg.Zone.HAND)


func test_the_bottom_difficulties_never_cast_in_a_window() -> void:
	# The ladder: a capability, like plays_engines and pays_sacrifices —
	# off for the two lowest profiles and on for the two highest.
	assert_false(AiProfile.apprentice().casts_timed_spells)
	assert_false(AiProfile.magician().casts_timed_spells)
	assert_true(AiProfile.sorcerer().casts_timed_spells)
	assert_true(AiProfile.wizard().casts_timed_spells)
	var ai := _ai(AiProfile.magician())
	var festival := give_hand(1, "Festival")
	put_battlefield(1, "Plains")
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "Craw Wurm")
	put_battlefield(0, "Grizzly Bears")
	_their(Mtg.Step.UPKEEP)
	for _i in 4:
		assert_ne(ai.act(g), "cast Festival in its window")
	assert_eq(festival.zone, Mtg.Zone.HAND)
