extends GameTest
## Fidelity lift 2026-09-02 — Drain Life's "Spend only black mana on X"
## (docs/simplified-cards.md row "Drain Life"). The 1997 exe charged X in
## BLACK (`charge_mana(player, COLOR_BLACK, -1)` in the routine at
## 0x41E9B0, `src/cards/unlimited.c` `card_drain_life`); the printed card
## says the same. X is a coloured payment (CardData.with_colored_x), the
## way Goblin Polka Band's per-target {R} already is for abilities.


func _drain_ready() -> CardInstance:
	var drain := give_hand(0, "Drain Life")
	advance_to_step(Mtg.Step.MAIN1)
	return drain


func test_drain_life_x_must_be_paid_in_black() -> void:
	var drain := _drain_ready()
	put_battlefield(1, "Hill Giant")
	add_mana(0, Mtg.ManaColor.B)      # the {B}
	add_mana(0, Mtg.ManaColor.C)      # the {1}
	add_mana(0, Mtg.ManaColor.G, 3)   # green cannot be spent on X
	assert_refused(g.cast_spell(0, drain, [TargetRef.player(1)], 3), "not enough mana")
	assert_eq(drain.zone, Mtg.Zone.HAND)


func test_drain_life_black_x_is_accepted_and_drains() -> void:
	var drain := _drain_ready()
	add_mana(0, Mtg.ManaColor.B, 4)   # {B} + X=3 in black
	add_mana(0, Mtg.ManaColor.C)      # the {1}
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 3))
	assert_eq(g.players[0].mana_pool.total(), 0, "every pip was spent")
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 23)


func test_drain_life_generic_part_still_takes_any_colour() -> void:
	var drain := _drain_ready()
	add_mana(0, Mtg.ManaColor.B, 3)   # {B} + X=2
	add_mana(0, Mtg.ManaColor.G)      # the {1} is generic: green is fine
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 2))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_drain_life_black_short_by_one_is_refused() -> void:
	var drain := _drain_ready()
	add_mana(0, Mtg.ManaColor.B, 3)   # {B} + only 2 black for X=3
	add_mana(0, Mtg.ManaColor.C, 2)   # plenty of colourless
	assert_refused(g.cast_spell(0, drain, [TargetRef.player(1)], 3), "not enough mana")
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 2))   # X=2 fits the black on hand


func test_drain_life_x_zero_needs_no_black_beyond_the_pip() -> void:
	var drain := _drain_ready()
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, drain, [TargetRef.player(1)], 0))
	resolve_stack()
	assert_eq(g.players[1].life, 20)


func test_ai_sizes_drain_life_by_its_black_mana() -> void:
	# Three Swamps and three Forests: {B}{1} plus X — the Forests can pay
	# the {1} but not X, so the biggest legal X is 2: enough for the Bears.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Drain Life")
	put_battlefield(1, "Grizzly Bears")
	for _i in 3:
		put_battlefield(0, "Swamp")
		put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	var action := ai.act(g)
	assert_string_contains(action, "cast Drain Life")
	assert_eq(g.stack.size(), 1, "the cast was accepted by the engine: %s" % action)
	if not g.stack.is_empty():
		assert_eq(g.stack[-1].x_value, 2, "X sized by the black mana available")


func test_ai_never_offers_an_x_its_black_cannot_cover() -> void:
	# The same mana, a Hill Giant (toughness 3): X=3 would kill it but only
	# two black are free once the {B} is paid. The AI must not tap out for
	# a cast the engine refuses — it either casts a legal X or waits.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	give_hand(0, "Drain Life")
	put_battlefield(1, "Hill Giant")
	for _i in 3:
		put_battlefield(0, "Swamp")
		put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	for line in g.log_lines:
		assert_false(line.contains("refused"), line)
	if not g.stack.is_empty():
		assert_true(g.stack[-1].x_value <= 2, "X within the black available")
