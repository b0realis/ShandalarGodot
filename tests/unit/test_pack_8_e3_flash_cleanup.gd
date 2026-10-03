extends GameTest
## Pack 8 engine package E3 — FLASH and the CR 514.3a CLEANUP TRIGGERS.
##
## - N_flash: the keyword (CR 702.8a), honoured where the cast checks its
##   timing (MtgGame._cast_announce_checks).
## - N_flash_rider: Mirage's "You may cast this spell as though it had
##   flash. If you cast it any time a sorcery couldn't have been cast, the
##   controller of the permanent it becomes sacrifices it at the beginning
##   of the next cleanup step" (CardData.with_flash_rider).
## - N_flash_seat: "You may cast creature spells this turn as though they
##   had flash" (MtgGame.grant_flash — Winding Canyons).
## - N_cleanup_triggers: "at the beginning of the next cleanup step" goes
##   on the stack AFTER the 514.1 discard and the 514.2 damage removal,
##   the active player gets priority, and another cleanup step follows
##   (CR 514.3a/b). Before Pack 8 those actions ran at the TOP of cleanup
##   with no priority — an instant-speed Armor of Thorns was sacrificed
##   while its creature's damage was still marked.
## - N_dynamic_ward: Ward of Lights' "protection from the chosen color.
##   This effect doesn't remove this Aura" reads the colour chosen as THIS
##   aura entered (CardData.grants_host_protection_from_chosen).


# ------------------------------------------------------------- synthetics --

static func _pump(game: MtgGame, source: CardInstance, p: int, t: int) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_power += p
		host.cur_toughness += t


## A Mirage flash-rider Aura: "Enchanted creature gets +p/+t."
func _rider_aura(card_name := "Test Armor", p := 2, t := 2) -> CardData:
	return CardData.new(card_name, "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_pump.bind(p, t), "Enchanted creature gets +%d/+%d." % [p, t])) \
		.with_flash_rider()


## A Mirage flash-rider global enchantment (Parapet's shape, no target).
func _rider_global() -> CardData:
	return CardData.new("Test Parapet", "{W}", Mtg.CardType.ENCHANTMENT).with_flash_rider()


func _bear(card_name := "Test Bear", p := 2, t := 2) -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(p, t)


func _flash_bear() -> CardData:
	return CardData.new("Test Cheetah", "{G}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_keywords([Mtg.Keyword.FLASH])


func _shock() -> CardData:
	return CardData.new("Test Shock", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target())


## Pass priority until the game is in the cleanup step with priority (or
## the turn has moved on — the caller asserts which).
func _to_cleanup_priority() -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty()) \
			and g.turn_number == turn and guard < 200:
		_advance_once()
		guard += 1


# ------------------------------------------------------------------ flash --

func test_flash_keyword_lets_a_creature_be_cast_in_the_opponents_turn() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	var cheetah := give_synthetic(1, _flash_bear())
	var bear := give_synthetic(1, _bear())
	assert_ok(g.pass_priority(0))   # P1 now has priority in P0's upkeep
	add_mana(1, Mtg.ManaColor.G, 3)
	assert_refused(g.cast_spell(1, bear), "main phase")
	assert_ok(g.cast_spell(1, cheetah))
	resolve_stack()
	assert_eq(cheetah.zone, Mtg.Zone.BATTLEFIELD, "a flash creature is cast like an instant (CR 702.8a)")
	assert_eq(g.cast_timing_refusal(1, bear).is_empty(), false, "the control still waits for its main phase")


func test_flash_still_needs_priority() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	var cheetah := give_synthetic(1, _flash_bear())
	add_mana(1, Mtg.ManaColor.G)
	assert_refused(g.cast_spell(1, cheetah), "priority")


func test_flash_creature_answers_in_the_declare_blockers_step() -> void:
	var attacker := put_synthetic(0, _bear("Attacker"))
	var cheetah := give_synthetic(1, _flash_bear())
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, cheetah))
	resolve_stack()
	assert_eq(cheetah.zone, Mtg.Zone.BATTLEFIELD)
	var second := give_synthetic(1, _flash_bear())
	assert_true(g.casts_at_instant_speed(1, second), "the AI/screen read: castable now")
	assert_false(g.casts_at_instant_speed(1, give_synthetic(1, _bear())), "the control")


# ------------------------------------------------------------ flash rider --

func test_a_rider_aura_cast_in_the_main_phase_is_permanent() -> void:
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.MAIN1)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_false(bool(armor.memory.get("flash_cast", false)), "a sorcery could have been cast")
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD, "no sacrifice when cast at sorcery speed")
	assert_eq(bear.cur_toughness, 4)


func test_a_rider_aura_cast_at_instant_speed_is_sacrificed_at_cleanup() -> void:
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_true(bool(armor.memory.get("flash_cast", false)), "cast when a sorcery couldn't have been")
	resolve_stack()
	assert_eq(bear.cur_power, 4)
	advance_to_step(Mtg.Step.END)
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD, "still there in the end step")
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed at the beginning of the next cleanup step")
	assert_eq(bear.cur_power, 2)


func test_a_rider_aura_cast_in_response_in_your_own_main_phase_is_sacrificed() -> void:
	# "Any time a sorcery couldn't have been cast": the main phase is not
	# enough, the stack must be empty too.
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.MAIN1)
	var shock := give_synthetic(0, _shock())
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, shock, [TargetRef.player(1)]))
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_true(bool(armor.memory.get("flash_cast", false)))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)


func test_a_rider_cast_in_the_opponents_turn_is_sacrificed_in_that_turns_cleanup() -> void:
	var bear := put_synthetic(1, _bear())
	advance_to_step(Mtg.Step.END)
	var armor := give_synthetic(1, _rider_aura())
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, armor, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "the NEXT cleanup step is the current turn's")
	assert_eq(g.players[1].graveyard.has(armor), true)


func test_the_sacrifice_comes_after_damage_wears_off() -> void:
	# THE KEY FINDING of the Pack 8 inventory: a 2/2 wearing an
	# instant-speed +2/+2 Aura takes 3 damage in combat. Under CR 514.2 the
	# damage is removed BEFORE the "next cleanup step" trigger resolves, so
	# the creature survives; the old order (sacrifice first) killed it.
	var bear := put_synthetic(0, _bear())
	var blocker := put_synthetic(1, _bear("Blocker", 3, 3))
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	run_combat([bear.id], {blocker.id: bear.id})
	assert_eq(bear.damage, 3)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "4/4 with 3 damage")
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "damage wore off before the Aura was sacrificed")
	assert_eq(bear.damage, 0)


func test_the_cleanup_trigger_uses_the_stack_and_the_active_player_gets_priority() -> void:
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.stack.size(), 1, "the delayed sacrifice is ON THE STACK (CR 514.3a)")
	assert_eq(g.stack[0].kind, Mtg.StackKind.TRIGGER)
	assert_eq(g.priority_player, 0, "the active player gets priority")
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD, "nothing has happened yet")
	# The opponent may respond inside the cleanup step.
	var shock := give_synthetic(1, _shock())
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, shock, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.turn_number, 1, "the turn has not passed: another cleanup step follows (CR 514.3b)")
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.turn_number, 2, "the second cleanup step had nothing to do and the turn passed")


func test_a_rider_cast_during_the_cleanup_window_goes_at_the_following_cleanup_step() -> void:
	var bear := put_synthetic(0, _bear())
	var other := put_synthetic(0, _bear("Other Bear"))
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	_to_cleanup_priority()
	var second := give_synthetic(0, _rider_aura("Second Armor"))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, second, [TargetRef.card(other)]))
	assert_true(bool(second.memory.get("flash_cast", false)), "no sorcery in the cleanup step")
	resolve_stack()   # Second Armor resolves, then the first sacrifice
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD, "its 'next cleanup step' has not begun yet")
	# Both pass on an empty stack: a NEW cleanup step begins (514.3b) and
	# its trigger goes on the stack.
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.turn_number, 1)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	assert_eq(g.turn_number, 2)


func test_a_plain_cleanup_still_passes_the_turn_without_priority() -> void:
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.turn_number, 2, "no trigger, no state-based action: no priority (CR 514.3)")


func test_a_countered_rider_leaves_nothing_to_sacrifice() -> void:
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	g.counter_spell(armor)
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].battlefield.size(), 1)


func test_a_bounced_rider_recast_at_sorcery_speed_is_kept() -> void:
	# CR 400.7: the permanent the instant-speed spell became left; the
	# card cast again in the main phase is a new object nothing names.
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	g.return_to_hand(armor)
	advance_to_step(Mtg.Step.MAIN2)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	assert_false(bool(armor.memory.get("flash_cast", false)))
	resolve_stack()
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD, "the recast Aura is not the one the trigger names")


func test_the_controller_of_the_permanent_sacrifices_it_after_a_control_change() -> void:
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var parapet := give_synthetic(0, _rider_global())
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, parapet))
	resolve_stack()
	g.change_control(parapet, 1)
	assert_eq(parapet.controller_id, 1)
	advance_to_next_turn()
	assert_eq(parapet.zone, Mtg.Zone.GRAVEYARD, "its new controller sacrificed it")
	assert_true(g.players[0].graveyard.has(parapet), "into its OWNER's graveyard")


func test_a_rider_cast_under_the_fifth_edition_rules_behaves_the_same() -> void:
	g.rules.set_edition("fifth")
	var bear := put_synthetic(0, _bear())
	var blocker := put_synthetic(1, _bear("Blocker", 3, 3))
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	run_combat([bear.id], {blocker.id: bear.id})
	advance_to_next_turn()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------- the seat's flash --

func test_grant_flash_lets_creature_spells_be_cast_this_turn_only() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	var bear := give_synthetic(1, _bear())
	var sorcery := give_synthetic(1, CardData.new("Test Sorcery", "{G}", Mtg.CardType.SORCERY) \
		.spell(DrawEffect.new(1)))
	g.grant_flash(1, func(_g: MtgGame, i: CardInstance) -> bool: return i.is_creature(),
		"creature spells this turn")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.G, 3)
	assert_refused(g.cast_spell(1, sorcery), "main phase")
	assert_ok(g.cast_spell(1, bear))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	var later := give_synthetic(1, _bear("Later Bear"))
	advance_to_next_turn()   # P1's turn 2
	advance_to_next_turn()   # P0's turn 3
	advance_to_step(Mtg.Step.UPKEEP)
	assert_refused(g.cast_timing_refusal(1, later), "main phase")


func test_grant_flash_is_journaled() -> void:
	g.undo_log = UndoLog.new()
	var mark := g.make_mark()
	g.grant_flash(0, func(_g: MtgGame, _i: CardInstance) -> bool: return true, "all")
	assert_eq(g.flash_permissions.size(), 1)
	g.unmake_to(mark)
	assert_eq(g.flash_permissions.size(), 0)


# ----------------------------------------------------- Ward of Lights' grant --

static func _choose_red(_g: MtgGame, s: CardInstance, _pid: int) -> void:
	s.memory["ward_color"] = Mtg.ManaColor.R


func test_a_chosen_color_ward_does_not_remove_itself() -> void:
	var bear := put_synthetic(0, _bear())
	var ward_data := CardData.new("Test Ward of Lights", "{W}{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()).with_colors(Mtg.ManaColor.R) \
		.grants_host_protection_from_chosen("ward_color", "Enchanted creature has protection from the chosen color.") \
		.as_it_enters(_choose_red)
	advance_to_step(Mtg.Step.MAIN1)
	var ward := give_synthetic(0, ward_data)
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, ward, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(int(ward.memory.get("ward_color", 0)), Mtg.ManaColor.R)
	assert_ne(bear.cur_protection & Mtg.ManaColor.R, 0, "protection from the chosen color")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD, "the red Ward is not removed by its own grant")
	# Another red Aura falls off (CR 702.16d) — only THIS Ward is exempt.
	var red_aura := CardData.new("Red Aura", "{R}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())
	var other := put_synthetic(0, red_aura)
	g._rec(other, &"attached_to")
	other.attached_to = bear.id
	bear.attachments.append(other.id)
	g.check_state_based_actions()
	assert_eq(other.zone, Mtg.Zone.GRAVEYARD, "a different red Aura is shed")
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------- the lifted Alliances adaptation --

func after_each() -> void:
	CardPacks.set_enabled("pack-5", false)


func test_bounty_of_the_hunt_removes_its_counters_on_the_stack_at_cleanup() -> void:
	CardPacks.set_enabled("pack-5", true)
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	var bounty := give_hand(0, "Bounty of the Hunt")
	add_mana(0, Mtg.ManaColor.G, 5)
	assert_ok(g.cast_spell(0, bounty, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(bear.cur_power, 5)
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.stack.size(), 3, "one delayed trigger per counter, on the stack (CR 514.3a)")
	assert_eq(bear.cur_power, 5, "and can be responded to")
	resolve_stack()
	assert_eq(bear.cur_power, 2)
	assert_false(bounty.data.oracle_text.contains("SIMPLIFIED"), "the ledger row is lifted")


func test_thawing_glaciers_returns_on_the_stack_at_cleanup() -> void:
	CardPacks.set_enabled("pack-5", true)
	var glacier := put_battlefield(0, "Thawing Glaciers")
	g.untap_permanent(glacier)
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, glacier, 0))
	resolve_stack()
	_to_cleanup_priority()
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.stack.size(), 1)
	assert_eq(glacier.zone, Mtg.Zone.BATTLEFIELD)
	resolve_stack()
	assert_eq(glacier.zone, Mtg.Zone.HAND)
	assert_false(glacier.data.oracle_text.contains("SIMPLIFIED"))


# ------------------------------------------------------------------ undo --

func test_the_cleanup_trigger_round_trips_the_journal() -> void:
	var bear := put_synthetic(0, _bear())
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var armor := give_synthetic(0, _rider_aura())
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, armor, [TargetRef.card(bear)]))
	resolve_stack()
	advance_to_step(Mtg.Step.END)
	g.undo_log = UndoLog.new()
	var before := g.players[0].graveyard.size()
	var mark := g.make_mark()
	# Through the end step into cleanup, the trigger and its resolution.
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	resolve_stack()
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(mark)
	assert_eq(g.current_step(), Mtg.Step.END)
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].graveyard.size(), before)
	assert_eq(g._cleanup_actions.size(), 1, "the pending sacrifice is back in its pool")


static func _shrink_all(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.is_creature():
			inst.cur_toughness -= 1


func test_a_state_based_action_in_cleanup_gives_priority_too() -> void:
	# CR 514.3a: "if state-based actions would be performed ... the active
	# player gets priority". A 1/1 under a -0/-1 static lives on a +0/+1
	# pump until the pump wears off in 514.2.
	put_synthetic(1, CardData.new("Test Blight", "{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_shrink_all, "Creatures get -0/-1.")))
	var weakling := put_synthetic(0, _bear("Weakling", 1, 1))
	g.continuous.add_until_eot_pump(weakling.id, 0, 1)
	g.recalculate()
	assert_eq(weakling.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_step(Mtg.Step.END)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(weakling.zone, Mtg.Zone.GRAVEYARD, "it died in the cleanup step")
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	assert_eq(g.turn_number, 1, "priority in the cleanup step")
	assert_eq(g.priority_player, 0)
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_eq(g.turn_number, 2, "the next cleanup step found nothing and the turn passed")
