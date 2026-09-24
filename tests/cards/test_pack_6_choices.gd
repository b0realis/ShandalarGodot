extends GameTest

func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)
func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-6", false)
func cast(name: String, targets: Array = [], pid := 0, x := 0) -> CardInstance:
	var c := give_hand(pid, name)
	for color in Mtg.WUBRG: add_mana(pid, color, 20)
	assert_ok(g.cast_spell(pid, c, targets, x))
	resolve_stack()
	return c

func test_ancestral_memories_keeps_two_and_mills_five_without_drawing() -> void:
	var drawn := g.players[0].drawn_this_turn.size()
	var size := g.players[0].library.size()
	cast("Ancestral Memories")
	assert_eq(g.players[0].hand.size(), 2)
	assert_eq(g.players[0].library.size(), size - 7)
	assert_eq(g.players[0].graveyard.size(), 6)
	assert_eq(g.players[0].drawn_this_turn.size(), drawn)

func test_optional_assassin_does_not_destroy_own_only_legal_target() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	g.set_agent(0, AiPlayer.new(0, AiProfile.wizard()))
	cast("Serpent Assassin")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_human_tutor_waits_without_shuffling_then_places_chosen_card() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bear)
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	var spell := give_hand(0, "Sylvan Tutor")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, spell))
	var rng := g.rng.state
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_not_null(g.awaiting_choice)
	assert_eq(g.rng.state, rng, "an unanswered choice must not shuffle")
	if g.awaiting_choice == null: return
	assert_has(g.awaiting_choice.candidates, bear)
	assert_ok(g.answer_choice(bear.id))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].library.back(), bear)
	assert_true(g.players[0].hand.is_empty())

func test_tutors_put_card_on_top_not_into_hand_and_cruel_costs_life() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	g.put_from_hand_on_top_of_library(bear)
	cast("Sylvan Tutor")
	assert_eq(g.players[0].library.back(), bear)
	assert_true(g.players[0].hand.is_empty())
	cast("Cruel Tutor")
	assert_eq(g.players[0].life, 18)
	assert_true(g.players[0].hand.is_empty())

func test_gift_of_estates_requires_more_enemy_lands_and_finds_duals() -> void:
	var plains := give_hand(0, "Savannah")
	g.put_from_hand_on_top_of_library(plains)
	cast("Gift of Estates")
	assert_eq(plains.zone, Mtg.Zone.LIBRARY)
	put_battlefield(1, "Island")
	cast("Gift of Estates")
	assert_eq(plains.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].hand.size(), 1)

func test_cruel_fate_only_mills_one_of_top_five_and_preserves_rest() -> void:
	var top := give_hand(1, "Serra Angel")
	g.put_from_hand_on_top_of_library(top)
	var size := g.players[1].library.size()
	cast("Cruel Fate", [TargetRef.player(1)])
	assert_eq(g.players[1].graveyard.size(), 1)
	assert_eq(g.players[1].library.size(), size - 1)
	assert_true(g.players[1].hand.is_empty())
	assert_false(g.game_over)

func test_prosperity_draws_both_and_balance_uses_post_cast_hand_size() -> void:
	cast("Prosperity", [], 0, 3)
	assert_eq(g.players[0].hand.size(), 3)
	assert_eq(g.players[1].hand.size(), 3)
	give_hand(1, "Forest")
	give_hand(1, "Forest")
	cast("Balance of Power", [TargetRef.player(1)])
	assert_eq(g.players[0].hand.size(), 5)

func test_temporary_truce_optional_draws_and_gaze_counts_dual_once() -> void:
	cast("Temporary Truce")
	assert_eq(g.players[0].hand.size(), 2)
	assert_eq(g.players[1].hand.size(), 2)
	assert_eq(g.players[0].life, 20)
	give_hand(1, "Taiga")
	give_hand(1, "Mountain")
	give_hand(1, "Hill Giant")
	cast("Baleful Stare", [TargetRef.player(1)])
	assert_eq(g.players[0].hand.size(), 5)

func test_mind_rot_makes_victim_discard_two_and_cruel_bargain_rounds_up() -> void:
	for n in 3: give_hand(1, "Forest")
	cast("Mind Rot", [TargetRef.player(1)])
	assert_eq(g.players[1].hand.size(), 1)
	assert_eq(g.players[1].graveyard.size(), 2)
	g.players[0].life = 9
	cast("Cruel Bargain")
	assert_eq(g.players[0].life, 4)
	assert_eq(g.players[0].hand.size(), 4)

func test_creature_type_filters_and_restricted_activated_abilities() -> void:
	var sorcerer := put_battlefield(0, "Capricious Sorcerer")
	assert_ok(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	g.untap_permanent(sorcerer)
	advance_to_step(Mtg.Step.MAIN2)
	assert_refused(g.activate_ability(0, sorcerer, 0, [TargetRef.player(1)]))

func test_taunt_applies_during_next_turn_and_does_not_force_self_attack() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	cast("Taunt", [TargetRef.player(1)])
	assert_false(bear.has_keyword(Mtg.Keyword.MUST_ATTACK))
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []))
	assert_ok(g.declare_attackers(1, [bear.id]))

func test_alabaster_still_shuffles_after_graveyard_exile() -> void:
	var dragon := put_battlefield(0, "Alabaster Dragon")
	g.destroy(dragon)
	g.exile_from_graveyard(dragon)
	var rng := g.rng.state
	resolve_stack()
	assert_eq(dragon.zone, Mtg.Zone.EXILE)
	assert_ne(g.rng.state, rng)

func test_targeted_triggers_select_before_resolution() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var imp := give_hand(0, "Fire Imp")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, imp))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_false(g.stack.is_empty())
	assert_eq(g.stack.back().targets.size(), 1)
	assert_eq(g.stack.back().targets[0].instance_id, bear.id)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
