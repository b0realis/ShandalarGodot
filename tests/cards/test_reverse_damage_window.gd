extends GameTest
## Reverse Damage must be usable in the classic prevention window, including
## against a spell that has resolved but whose damage is still waiting.

class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true

func _arm() -> void:
	g.rules.set_edition("fifth")
	g.set_agent(1, WindowSeat.new())

func _cast_reverse(reverse: CardInstance) -> bool:
	if g.priority_player != 1:
		assert_ok(g.end_damage_prevention(g.priority_player))
	add_mana(1, Mtg.ManaColor.W, 2)
	add_mana(1, Mtg.ManaColor.C)
	var result := g.cast_spell(1, reverse, [])
	assert_ok(result)
	if result != "":
		return false
	resolve_stack()
	return true

func _end_window() -> void:
	assert_ok(g.end_damage_prevention(g.priority_player))
	if g.awaiting_damage_prevention or g.awaiting_regeneration:
		assert_ok(g.end_damage_prevention(g.priority_player))

func _bolt(target: TargetRef) -> CardInstance:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [target]))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	return bolt

func test_reverse_damage_alone_opens_the_combat_prevention_window() -> void:
	_arm()
	var wurm := put_battlefield(0, "Craw Wurm")
	var reverse := give_hand(1, "Reverse Damage")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention, "Reverse Damage is a prevention effect")
	assert_eq(g.players[1].life, 20, "damage waits for a response")
	if not g.awaiting_damage_prevention or not _cast_reverse(reverse):
		return
	_end_window()
	assert_eq(g.players[1].life, 26, "six prevented, six gained")
	assert_true(g.players[1].reverse_damage_sources.is_empty(), "one-shot shield spent")

func test_reverse_damage_is_legal_in_a_window_opened_by_another_card() -> void:
	_arm()
	var reverse := give_hand(1, "Reverse Damage")
	give_hand(1, "Healing Salve")
	_bolt(TargetRef.player(1))
	assert_true(g.awaiting_damage_prevention)
	if not g.awaiting_damage_prevention or not _cast_reverse(reverse):
		return
	_end_window()
	assert_eq(g.players[1].life, 23)

func test_resolved_spell_stays_selectable_and_is_ranked_before_unrelated_threats() -> void:
	_arm()
	var reverse := give_hand(1, "Reverse Damage")
	give_hand(1, "Healing Salve")
	put_battlefield(0, "Craw Wurm")
	var bolt := _bolt(TargetRef.player(1))
	var sources := g.damage_sources(Callable(), TargetRef.player(1))
	assert_true(sources.has(bolt), "pending damage retains its departed source")
	assert_eq(sources[0], bolt, "the default chooser should prevent imminent damage")
	var filtered := g.damage_sources(func(source: CardInstance) -> bool:
		return source.data.card_name != "Lightning Bolt")
	assert_false(filtered.has(bolt), "source predicates also apply to pending spells")
	if not _cast_reverse(reverse):
		return
	_end_window()
	assert_eq(g.players[1].life, 23)
	assert_false(g.damage_sources().has(bolt), "ordinary graveyard cards are not sources")

func test_pending_sources_respect_filters_and_do_not_duplicate_permanents() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(0, "Craw Wurm")
	plant_damage_packet(giant, TargetRef.player(1), 3)
	plant_damage_packet(giant, TargetRef.card(wurm), 1)
	var sourceless := DamagePacket.new()
	sourceless.target = TargetRef.player(1)
	sourceless.amount = 1
	g.damage_pending.append(sourceless)
	var sources := g.damage_sources(func(source: CardInstance) -> bool:
		return source.data.card_name == "Hill Giant")
	assert_eq(sources.size(), 1)
	assert_eq(sources[0], giant)

func test_pending_threat_ranking_uses_the_victim_and_remaining_damage() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var wurm := put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(1, "Grizzly Bears")
	var giant_packet := plant_damage_packet(giant, TargetRef.player(1), 3)
	plant_damage_packet(wurm, TargetRef.card(bears), 6)
	assert_eq(g.damage_sources(Callable(), TargetRef.player(1))[0], giant)
	assert_eq(g.damage_sources(Callable(), TargetRef.card(bears))[0], wurm)
	giant_packet.prevent(3)
	assert_eq(g.damage_sources(Callable(), TargetRef.player(1))[0], wurm,
		"fully prevented packets no longer take priority over other threats")

func test_reverse_damage_does_not_save_a_creature_in_the_classic_window() -> void:
	_arm()
	var bears := put_battlefield(1, "Grizzly Bears")
	var reverse := give_hand(1, "Reverse Damage")
	give_hand(1, "Healing Salve")
	var bolt := _bolt(TargetRef.card(bears))
	assert_true(g.awaiting_damage_prevention)
	if not g.awaiting_damage_prevention or not _cast_reverse(reverse):
		return
	_end_window()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the spell protects you, not your creatures")
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[1].reverse_damage_sources, [bolt.id], "creature damage does not spend the shield")
