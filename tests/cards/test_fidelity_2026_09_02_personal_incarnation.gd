extends GameTest
## Personal Incarnation's metered redirect, lifted 2026-09-02
## (docs/simplified-cards.md, "Personal Incarnation"): "{0}: The next 1
## damage that would be dealt to this creature this turn is dealt to its
## owner instead." One activation moves ONE point; the rest stays on the
## Avatar. `Duel.hlp`: "owner may redirect any amount of damage from it to
## himself or herself" — `@PERSONAL_INCARNATION`: "How much damage to
## redirect to you?" — the 1997 amount is N activations here.


func _arm(avatar: CardInstance, times: int) -> void:
	for _i in times:
		assert_ok(g.activate_ability(0, avatar, 0))
	resolve_stack()


func test_one_activation_moves_one_point_and_the_rest_stays() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_arm(avatar, 1)
	assert_eq(avatar.damage_point_redirects, 1)
	g.deal_damage(giant, TargetRef.card(avatar), 3)
	assert_eq(avatar.damage, 2, "two points stay on the Avatar")
	assert_eq(g.players[0].life, 19, "the owner takes exactly one")
	assert_eq(avatar.damage_point_redirects, 0, "the point is spent")


func test_points_are_spent_one_hit_at_a_time_and_the_rest_wait() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_arm(avatar, 3)
	g.deal_damage(giant, TargetRef.card(avatar), 2)
	assert_eq(avatar.damage, 0, "both points moved")
	assert_eq(g.players[0].life, 18)
	assert_eq(avatar.damage_point_redirects, 1, "one point left for later")
	g.deal_damage(giant, TargetRef.card(avatar), 2)
	assert_eq(avatar.damage, 1, "the last point moved, the other stayed")
	assert_eq(g.players[0].life, 17)


func test_a_stolen_avatar_still_sends_the_point_to_its_owner() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_arm(avatar, 1)
	g.change_control(avatar, 1)
	g.deal_damage(giant, TargetRef.card(avatar), 3)
	assert_eq(g.players[0].life, 19, "the OWNER, not the thief")
	assert_eq(g.players[1].life, 20)
	assert_eq(avatar.damage, 2)


func test_unspent_points_expire_at_cleanup() -> void:
	var avatar := put_battlefield(0, "Personal Incarnation")
	advance_to_step(Mtg.Step.MAIN1)
	_arm(avatar, 2)
	advance_to_next_turn()
	assert_eq(avatar.damage_point_redirects, 0, "this-turn only")
	assert_eq(avatar.damage_point_redirect_to, -1)


func test_the_moved_point_is_the_same_damage_for_a_waiting_caller() -> void:
	# Drain Life on an armed Avatar: "you gain life equal to the damage
	# dealt this way" counts the point that landed on the owner too — it
	# was dealt, just elsewhere.
	var avatar := put_battlefield(0, "Personal Incarnation")
	advance_to_next_turn()               # P1's turn: Drain Life is a sorcery
	advance_to_step(Mtg.Step.MAIN1)
	g.players[1].life = 10
	var drain := give_hand(1, "Drain Life")
	add_mana(1, Mtg.ManaColor.B, 3)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, drain, [TargetRef.card(avatar)], 2))
	assert_ok(g.pass_priority(1))
	assert_ok(g.activate_ability(0, avatar, 0))   # in response
	resolve_stack()
	assert_eq(avatar.damage, 1)
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[1].life, 12, "gained 2: both points were dealt")


func test_in_the_1997_window_the_moved_point_gets_its_own_prevention_step() -> void:
	# `Duel.hlp`, Veteran Bodyguard: a redirect "causes a second
	# damage-prevention step that follows the current one".
	g.rules.damage_prevention_window = true
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	var avatar := put_battlefield(0, "Personal Incarnation")
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	_arm(avatar, 1)
	g.deal_damage(giant, TargetRef.card(avatar), 3)
	g._open_priority()
	assert_true(g.awaiting_damage_prevention, "the Avatar's owner could still act")
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(avatar.damage, 2, "the first step landed two on the Avatar")
	assert_eq(g.players[0].life, 20, "the moved point waits for its own step")
	assert_eq(g.damage_pending.size(), 1)
	assert_true(g.damage_pending[0].target.is_player)
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration) and guard < 8:
		guard += 1
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.players[0].life, 19, "and then lands")
