extends GameTest
## Public effect labels and the portrait badge have the same lifetime.

func test_badge_names_the_source_and_disappears_when_the_shield_is_used() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var reverse := give_hand(1, "Reverse Damage")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W, 2)
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(1, reverse, []))
	resolve_stack()
	var badge := PlayerProtectionBadge.new()
	add_child_autofree(badge)
	badge.present("Defender", g.player_damage_effects(1))
	assert_true(badge.visible)
	assert_string_contains(badge.tooltip_text, "Hill Giant")
	assert_string_contains(badge.tooltip_text, "next hit")
	assert_string_contains(badge.tooltip_text, "this turn")
	badge.open_details()
	assert_not_null(badge._dialog)
	assert_string_contains(badge._details.text, "Reverse Damage")
	g.deal_damage(giant, TargetRef.player(1), 3)
	badge.present("Defender", g.player_damage_effects(1))
	assert_false(badge.visible)
	assert_null(badge._dialog)
	assert_eq(g.players[1].life, 23)
	await get_tree().process_frame

func test_shields_expire_at_cleanup_and_duplicate_labels_are_grouped() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	g.players[1].reverse_damage_sources.assign([giant.id, giant.id])
	var rows := g.player_damage_effects(1)
	assert_eq(rows.size(), 1)
	assert_string_contains(rows[0], "2 ×")
	advance_to_next_turn()
	assert_true(g.player_damage_effects(1).is_empty())

func test_public_descriptions_do_not_reveal_a_face_down_or_hidden_identity() -> void:
	var source := put_battlefield(0, "Hill Giant")
	g.players[1].reverse_damage_sources.append(source.id)
	source.face_down = true
	assert_false(str(g.player_damage_effects(1)).contains("Hill Giant"))
	source.face_down = false
	source.zone = Mtg.Zone.HAND # public presentation must not inspect hidden identity
	assert_false(str(g.player_damage_effects(1)).contains("Hill Giant"))

func test_pool_and_all_turn_protection_have_different_duration_text() -> void:
	g.players[1].damage_prevention = 3
	g.players[1].prevention_shield_filters.append({"desc": "Scarecrow", "all_turn": true})
	var rows := g.player_damage_effects(1)
	assert_eq(rows.size(), 2)
	assert_string_contains(rows[0], "next 3 damage")
	assert_string_contains(rows[1], "all matching damage")

func test_eye_for_an_eye_label_does_not_promise_prevention() -> void:
	put_battlefield(0, "Hill Giant")
	var eye := give_hand(1, "Eye for an Eye")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(1, eye, []))
	resolve_stack()
	var rows := g.player_damage_effects(1)
	assert_eq(rows.size(), 1)
	assert_string_contains(rows[0], "Hill Giant")
	assert_string_contains(rows[0], "does not prevent your damage")
	assert_string_contains(rows[0], "next matching hit this turn")

func test_long_player_names_wrap_inside_the_details_window() -> void:
	var badge := PlayerProtectionBadge.new()
	add_child_autofree(badge)
	badge.present("A very long duelist name ".repeat(4), ["Prevent the next 3 damage; this turn"])
	badge.open_details()
	await get_tree().process_frame
	await get_tree().process_frame
	assert_lte(badge._dialog.size.x, 430.0)
	assert_lte(badge._details.get_global_rect().end.x, badge._dialog.get_global_rect().end.x)
