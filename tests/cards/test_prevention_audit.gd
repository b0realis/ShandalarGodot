extends GameTest
## Classic prevention timing and modern retroactive healing are distinct.

class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool: return true

func _arm() -> void:
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())

func _defender_priority() -> void:
	if g.priority_player != 1: assert_ok(g.pass_priority(g.priority_player))

func _close_windows() -> void:
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration) and guard < 12:
		assert_ok(g.end_damage_prevention(g.priority_player))
		guard += 1
	assert_lt(guard, 12)

func _bolt(target: TargetRef) -> CardInstance:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [target]))
	resolve_stack()
	return bolt

func test_jade_monolith_alone_opens_a_window_and_saves_the_creature() -> void:
	_arm()
	var monolith := put_battlefield(1, "Jade Monolith")
	var bears := put_battlefield(1, "Grizzly Bears")
	_bolt(TargetRef.card(bears))
	assert_true(g.awaiting_damage_prevention)
	if not g.awaiting_damage_prevention: return
	_defender_priority()
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, monolith, 0, [TargetRef.card(bears)]))
	resolve_stack()
	_close_windows()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bears.damage, 0)
	assert_eq(g.players[1].life, 17)

func test_dark_sphere_can_name_a_resolved_spell_in_the_classic_window() -> void:
	_arm()
	var sphere := put_battlefield(1, "Dark Sphere")
	put_battlefield(0, "Craw Wurm") # irrelevant permanent must not win the default
	var bolt := _bolt(TargetRef.player(1))
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	_defender_priority()
	assert_ok(g.activate_ability(1, sphere, 0, []))
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 18, "prevent half of three, rounded down")
	assert_true(g.players[1].damage_replacements.is_empty())

func test_classic_simulacrum_heals_pending_damage_and_damages_its_creature() -> void:
	_arm()
	g.players[1].life = 3
	var wall := put_battlefield(1, "Wall of Stone")
	var sim := give_hand(1, "Simulacrum")
	give_hand(1, "Healing Salve") # opens the window even before the fix
	_bolt(TargetRef.player(1))
	_defender_priority()
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	var refusal := g.cast_spell(1, sim, [TargetRef.card(wall)])
	assert_ok(refusal)
	if refusal != "": return
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 3)
	assert_eq(wall.damage, 3)
	assert_false(g.game_over)

func test_classic_reverse_polarity_recovers_actual_artifact_damage() -> void:
	_arm()
	g.players[1].life = 3
	var juggernaut := put_battlefield(0, "Juggernaut")
	var polarity := give_hand(1, "Reverse Polarity")
	give_hand(1, "Healing Salve")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [juggernaut.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	_defender_priority()
	add_mana(1, Mtg.ManaColor.W, 2)
	var refusal := g.cast_spell(1, polarity, [])
	assert_ok(refusal)
	if refusal != "": return
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 8, "three minus five plus ten")
	assert_false(g.game_over)

func test_classic_simulacrum_does_not_gain_life_for_prevented_damage() -> void:
	_arm()
	var wall := put_battlefield(1, "Wall of Stone")
	var sim := give_hand(1, "Simulacrum")
	var salve := give_hand(1, "Healing Salve")
	_bolt(TargetRef.player(1))
	_defender_priority()
	add_mana(1, Mtg.ManaColor.B)
	add_mana(1, Mtg.ManaColor.C)
	var refusal := g.cast_spell(1, sim, [TargetRef.card(wall)])
	assert_ok(refusal)
	if refusal != "": return
	resolve_stack()
	_defender_priority()
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, salve, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 20)
	assert_eq(wall.damage, 0)

func test_modern_simulacrum_does_not_cover_future_damage() -> void:
	var wall := put_battlefield(0, "Wall of Stone")
	var sim := give_hand(0, "Simulacrum")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, sim, [TargetRef.card(wall)]))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	if g.priority_player != 1: assert_ok(g.pass_priority(g.priority_player))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 17)
	assert_eq(wall.damage, 0)

func test_classic_simulacrum_counts_prior_and_pending_damage_once() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	g.deal_damage(giant, TargetRef.player(1), 2)
	_arm()
	var wall := put_battlefield(1, "Wall of Stone")
	var sim := give_hand(1, "Simulacrum")
	_bolt(TargetRef.player(1))
	_defender_priority()
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(1, sim, [TargetRef.card(wall)]))
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 20)
	assert_eq(wall.damage, 5)
	_bolt(TargetRef.player(1))
	_close_windows()
	assert_eq(g.players[1].life, 17, "a later window is not covered")
	assert_eq(wall.damage, 5)

func test_simulacrum_cannot_heal_damage_redirected_away_from_its_player() -> void:
	_arm()
	var bodyguard := put_battlefield(1, "Veteran Bodyguard")
	var wall := put_battlefield(1, "Wall of Stone")
	var giant := put_battlefield(0, "Hill Giant")
	var sim := give_hand(1, "Simulacrum")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	_defender_priority()
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(1, sim, [TargetRef.card(wall)]))
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 20)
	assert_eq(bodyguard.damage, 3)
	assert_eq(wall.damage, 0)

func test_polarity_covers_artifact_packets_only_in_a_mixed_combat() -> void:
	_arm()
	var juggernaut := put_battlefield(0, "Juggernaut")
	var giant := put_battlefield(0, "Hill Giant")
	var polarity := give_hand(1, "Reverse Polarity")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [juggernaut.id, giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	_defender_priority()
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(1, polarity, []))
	resolve_stack()
	_close_windows()
	assert_eq(g.players[1].life, 22, "20 - 5 - 3 + twice the artifact's 5")

func test_pending_recovery_is_restored_by_snapshot_and_undo() -> void:
	_arm()
	give_hand(1, "Simulacrum")
	var wall := put_battlefield(1, "Wall of Stone")
	var sim := give_hand(1, "Simulacrum")
	_bolt(TargetRef.player(1))
	var packet: DamagePacket = g.damage_pending[0]
	var snap := GameSnapshot.take(g)
	g.recover_damage_this_turn(1, 1, false, sim, wall)
	assert_eq(packet.retroactive_heals.size(), 1)
	snap.restore()
	assert_true(packet.retroactive_heals.is_empty())
	var mark := g.make_mark()
	g.recover_damage_this_turn(1, 1, false, sim, wall)
	assert_eq(packet.retroactive_heals.size(), 1)
	g.unmake_to(mark)
	assert_true(packet.retroactive_heals.is_empty())
	g.end_search()
	assert_null(g.undo_log, "finish the test's search before resuming real play")
	_close_windows()
	assert_eq(g.players[1].life, 17)
	assert_eq(wall.damage, 0)

func test_simulacrum_does_not_damage_a_new_incarnation_of_its_recipient() -> void:
	_arm()
	var wall := put_battlefield(1, "Wall of Stone")
	var sim := give_hand(1, "Simulacrum")
	_bolt(TargetRef.player(1))
	_defender_priority()
	add_mana(1, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(1, sim, [TargetRef.card(wall)]))
	resolve_stack()
	g.return_to_hand(wall)
	g._put_on_battlefield(wall, 1)
	_close_windows()
	assert_eq(g.players[1].life, 20)
	assert_eq(wall.damage, 0, "the old target is gone")
