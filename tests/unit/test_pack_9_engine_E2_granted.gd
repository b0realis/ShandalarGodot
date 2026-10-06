extends GameTest
## Pack 9 engine package E2 — GRANTED ALTERNATIVE COSTS, STATIC FLASH and
## the SPELLS-CAST COUNT.
##
## - M_GRANTED_ALT_COST: a permanent offers OTHER spells an alternative
##   cost (CR 118.9, 601.2b/f): Dream Halls' "Rather than pay the mana cost
##   for a spell, its controller may discard a card that shares a color
##   with that spell", Aluren's "without paying their mana costs". The
##   engine lists every payment row of a spell with
##   [method MtgGame.payment_rows] — the printed rows FIRST, so no existing
##   index moves, then one granted row per eligible printed row (only one
##   alternative cost at a time, CR 118.9a; buyback, an additional cost,
##   stays payable on top — the Dream Halls ruling). X is 0 when the
##   alternative cost has none (CR 107.3b; the Aluren ruling).
## - M_STATIC_FLASH: "You may cast Aura spells with enchant creature as
##   though they had flash" (Rootwater Shaman) — a static permission
##   ([method CardData.with_granted_flash]); Aluren's flash belongs to its
##   ROW only ("You can't choose to cast a creature as though it had flash
##   via Aluren and still pay the mana cost", Aluren ruling 2004-10-04).
## - M_SPELLS_CAST_COUNT: [method MtgGame.spells_cast_count] (Skyshroud
##   Condor's "Cast this spell only if you've cast another spell this
##   turn"): every spell cast, never a copy, reset with the turn.

const OC := preload("res://engine/additional_object_costs.gd")


# ------------------------------------------------------------- synthetics --

static func _shares_color(_g: MtgGame, card: CardInstance, spell: CardInstance) -> bool:
	return spell != null and (card.cur_colors & spell.cur_colors) != 0


static func _halls_rows(_g: MtgGame, _pid: int, spell: CardInstance,
		_source: CardInstance) -> Array:
	if spell.cur_colors == 0:
		return []   # a colourless spell shares a colour with nothing
	var group := OC.discarding("card that shares a color with it")
	group["source_filter"] = _shares_color
	return [{"label": "Discard a card that shares a color with it", "object_costs": [group]}]


static func _aluren_rows(_g: MtgGame, _pid: int, spell: CardInstance,
		_source: CardInstance) -> Array:
	if not spell.is_creature() or spell.data.cost.mana_value() > 3:
		return []
	return [{"label": "Cast it without paying its mana cost", "flash": true}]


static func _shaman_flash(_g: MtgGame, pid: int, spell: CardInstance,
		source: CardInstance) -> bool:
	return pid == source.controller_id and spell.data.is_aura() \
		and spell.data.aura_target.kind == TargetSpec.Kind.CREATURE


static func _is_land(i: CardInstance) -> bool:
	return i.is_land()


func _halls() -> CardData:
	return CardData.new("Test Halls", "{3}{U}{U}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_halls_rows)


func _aluren() -> CardData:
	return CardData.new("Test Aluren", "{2}{G}{G}", Mtg.CardType.ENCHANTMENT) \
		.with_granted_alternative_cost(_aluren_rows)


func _shaman() -> CardData:
	return CardData.new("Test Shaman", "{1}{U}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_granted_flash(_shaman_flash)


func _bear(card_name := "Test Bear", cost := "{1}{G}") -> CardData:
	return CardData.new(card_name, cost, Mtg.CardType.CREATURE).pt(2, 2)


func _touch() -> CardData:
	return CardData.new("Test Touch", "{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(1).any_target()) \
		.with_buyback({"mana": "{4}"})


func _blast() -> CardData:
	return CardData.new("Test Blast", "{X}{R}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().any_target())


func _charm() -> CardData:
	return CardData.new("Test Charm", "{R}", Mtg.CardType.INSTANT) \
		.mode("Deal 1 damage to any target", [DamageEffect.new(1).any_target()]) \
		.mode("You gain 3 life", [GainLifeEffect.new(3)])


func _aura() -> CardData:
	return CardData.new("Test Aura", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature())


func _land_aura() -> CardData:
	return CardData.new("Test Land Aura", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land))


func _condor() -> CardData:
	return CardData.new("Test Condor", "{1}{G}", Mtg.CardType.CREATURE).pt(3, 3) \
		.castable_only_when(func(game: MtgGame, pid: int) -> String:
			return "" if game.spells_cast_count(pid) > 0 \
				else "Cast this spell only if you've cast another spell this turn")


func _pool(pid: int) -> int:
	return g.players[pid].mana_pool.total()


## Seat 1 receives priority in seat 0's upkeep: an instant-speed moment.
func _their_upkeep_priority() -> void:
	advance_to_step(Mtg.Step.UPKEEP)
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


# ------------------------------------------------------------- Dream Halls --

func test_without_a_grant_the_rows_are_the_printed_ones() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var rows := g.payment_rows(0, bolt)
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0]["granted_by"]), -1)
	var touch := give_synthetic(0, _touch())
	assert_eq(g.payment_rows(0, touch).size(), 2, "printed + buyback")


func test_dream_halls_lets_its_controller_discard_instead_of_paying() -> void:
	var halls := put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	var fodder := give_hand(0, "Lightning Bolt")
	var rows := g.payment_rows(0, bolt)
	assert_eq(rows.size(), 2)
	assert_eq(int(rows[1]["granted_by"]), halls.id)
	assert_eq(int(rows[1]["effects_mode"]), 0)
	assert_true(g.is_alternative_payment(rows[1]["payment"]))
	assert_eq(g.payment_row_refusal(0, bolt, 1), "")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD, "the red card paid for it")
	resolve_stack()
	assert_eq(g.players[1].life, 17)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_dream_halls_works_for_every_player() -> void:
	put_synthetic(0, _halls())
	var bolt := give_hand(1, "Lightning Bolt")
	var fodder := give_hand(1, "Lightning Bolt")
	_their_upkeep_priority()
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)], 0, 1))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[0].life, 17)


func test_dream_halls_needs_a_card_sharing_a_colour() -> void:
	put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	var blue := give_hand(0, "Counterspell")
	assert_ne(g.payment_row_refusal(0, bolt, 1), "")
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1))
	assert_eq(blue.zone, Mtg.Zone.HAND, "a blue card shares nothing with a red spell")
	assert_eq(bolt.zone, Mtg.Zone.HAND)


func test_dream_halls_never_lets_a_spell_pay_with_itself() -> void:
	put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1))
	assert_eq(bolt.zone, Mtg.Zone.HAND)


func test_a_colourless_spell_gets_no_dream_halls_row() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _halls())
	var rock := give_synthetic(0, CardData.new("Test Rock", "{2}", Mtg.CardType.ARTIFACT))
	give_hand(0, "Lightning Bolt")
	assert_eq(g.payment_rows(0, rock).size(), 1)
	assert_refused(g.cast_spell(0, rock, [], 0, 1), "not enough mana")


func test_x_is_zero_without_the_mana_cost() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_synthetic(0, _halls())
	var blast := give_synthetic(0, _blast())
	give_hand(0, "Lightning Bolt")
	assert_refused(g.cast_spell(0, blast, [TargetRef.player(1)], 3, 1), "X")
	assert_eq(blast.zone, Mtg.Zone.HAND)
	assert_ok(g.cast_spell(0, blast, [TargetRef.player(1)], 0, 1))
	resolve_stack()
	assert_eq(g.players[1].life, 20, "X = 0 (CR 107.3b)")


func test_dream_halls_and_buyback_together() -> void:
	put_synthetic(0, _halls())
	var touch := give_synthetic(0, _touch())
	var fodder := give_hand(0, "Lightning Bolt")
	var rows := g.payment_rows(0, touch)
	assert_eq(rows.size(), 4, "printed, buyback, Halls, Halls + buyback")
	assert_eq(int(rows[3]["effects_mode"]), 1, "the buyback row's spell")
	assert_true(bool(rows[3]["payment"].get("buyback", false)))
	assert_eq(g.spell_cost_for(0, touch.data, 0, 3, touch).mana_value(), 4,
		"the mana cost is replaced; the buyback is still owed (Dream Halls ruling)")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_refused(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 3), "not enough mana")
	assert_eq(fodder.zone, Mtg.Zone.HAND)
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 3))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_pool(0), 0)
	resolve_stack()
	assert_eq(touch.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 19)


func test_a_modal_spell_gets_one_granted_row_per_mode() -> void:
	put_synthetic(0, _halls())
	var charm := give_synthetic(0, _charm())
	give_hand(0, "Lightning Bolt")
	var rows := g.payment_rows(0, charm)
	assert_eq(rows.size(), 4)
	assert_eq(int(rows[2]["effects_mode"]), 0)
	assert_eq(int(rows[3]["effects_mode"]), 1)
	assert_ok(g.cast_spell(0, charm, [], 0, 3))
	assert_eq(g.stack.back().mode, 1, "the stack item carries the MODE, the row only paid")
	resolve_stack()
	assert_eq(g.players[0].life, 23)


func test_a_stale_granted_row_is_refused_once_the_grant_is_gone() -> void:
	var halls := put_synthetic(0, _halls())
	var charm := give_synthetic(0, _charm())
	var fodder := give_hand(0, "Lightning Bolt")
	g.destroy(halls)
	assert_eq(g.payment_rows(0, charm).size(), 2)
	assert_refused(g.cast_spell(0, charm, [], 0, 3), "no mode")
	assert_eq(fodder.zone, Mtg.Zone.HAND)
	var bolt := give_hand(0, "Lightning Bolt")
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1), "not enough mana")
	assert_eq(fodder.zone, Mtg.Zone.HAND, "a non-modal card falls back to its printed cost")


func test_a_silenced_dream_halls_grants_nothing() -> void:
	var halls := put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	give_hand(0, "Lightning Bolt")
	halls.cur_abilities_silenced = true
	assert_eq(g.payment_rows(0, bolt).size(), 1, "an ability that is gone grants nothing")
	halls.cur_abilities_silenced = false
	assert_eq(g.payment_rows(0, bolt).size(), 2)


func test_dream_halls_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	var fodder := give_hand(0, "Lightning Bolt")
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1))
	assert_eq(fodder.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(g.players[1].life, 17)


# ------------------------------------------------------------------ Aluren --

func test_aluren_casts_a_small_creature_free_at_instant_speed_for_anyone() -> void:
	put_synthetic(0, _aluren())
	var bear := give_synthetic(1, _bear())
	_their_upkeep_priority()
	assert_true(g.has_flash(1, bear), "Aluren's row gives the creature flash")
	assert_true(g.casts_at_instant_speed(1, bear))
	assert_eq(g.payment_rows(1, bear).size(), 2)
	assert_ok(g.cast_spell(1, bear, [], 0, 1))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 1)


func test_aluren_flash_does_not_come_with_the_printed_cost() -> void:
	put_synthetic(0, _aluren())
	var bear := give_synthetic(1, _bear())
	_their_upkeep_priority()
	add_mana(1, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(1, bear, [], 0, 0))
	assert_ne(g.cast_refusal(1, bear, [], 0, 0), "")
	assert_ne(g.spell_announce_refusal(1, bear, 0, 0), "")
	assert_eq(g.spell_announce_refusal(1, bear, 0, 1), "")
	assert_eq(_pool(1), 2, "nothing paid")
	assert_eq(bear.zone, Mtg.Zone.HAND)


func test_aluren_at_sorcery_speed_casts_free_or_paid() -> void:
	put_synthetic(0, _aluren())
	var bear := give_synthetic(0, _bear())
	var other := give_synthetic(0, _bear("Test Bear Two"))
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.cast_spell(0, bear, [], 0, 1))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, other, [], 0, 0))
	assert_eq(_pool(0), 0, "the printed cost may still be paid")
	resolve_stack()
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD)


func test_aluren_skips_creatures_above_three_and_noncreature_spells() -> void:
	put_synthetic(0, _aluren())
	var giant := give_synthetic(0, _bear("Test Giant", "{3}{G}"))
	var bolt := give_hand(0, "Lightning Bolt")
	assert_eq(g.payment_rows(0, giant).size(), 1, "mana value 4")
	assert_eq(g.payment_rows(0, bolt).size(), 1, "not a creature spell")
	assert_false(g.has_flash(0, giant), "no row, no flash")


func test_aluren_x_creature_is_cast_for_x_zero() -> void:
	put_synthetic(0, _aluren())
	var hydra := give_synthetic(0, _bear("Test Hydra", "{X}{G}"))
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.cast_spell(0, hydra, [], 2, 1), "X")
	assert_ok(g.cast_spell(0, hydra, [], 0, 1))
	resolve_stack()
	assert_eq(hydra.zone, Mtg.Zone.BATTLEFIELD)


func test_aluren_under_the_fifth_edition_rules() -> void:
	g.rules.set_edition("fifth")
	put_synthetic(0, _aluren())
	var bear := give_synthetic(1, _bear())
	_their_upkeep_priority()
	assert_ok(g.cast_spell(1, bear, [], 0, 1))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Rootwater Shaman --

func test_static_flash_for_its_controllers_creature_auras_only() -> void:
	put_synthetic(1, _shaman())
	var host := put_synthetic(1, _bear())
	var aura := give_synthetic(1, _aura())
	var land_aura := give_synthetic(1, _land_aura())
	var theirs := give_synthetic(0, _aura())
	assert_true(g.has_flash(1, aura))
	assert_false(g.has_flash(1, land_aura), "enchant land is not enchant creature")
	assert_false(g.has_flash(0, theirs), "\"you may\": the Shaman's controller only")
	_their_upkeep_priority()
	add_mana(1, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(1, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(aura.attached_to, host.id)


func test_static_flash_ends_with_its_source() -> void:
	var shaman := put_synthetic(1, _shaman())
	var aura := give_synthetic(1, _aura())
	assert_true(g.has_flash(1, aura))
	shaman.cur_abilities_silenced = true
	assert_false(g.has_flash(1, aura), "silenced")
	shaman.cur_abilities_silenced = false
	g.destroy(shaman)
	assert_false(g.has_flash(1, aura), "gone")


# ---------------------------------------------------------- spells cast count --

func test_condor_needs_an_earlier_spell_this_turn() -> void:
	var condor := give_synthetic(0, _condor())
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(g.spells_cast_count(0), 0)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, condor), "another spell")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.spells_cast_count(0), 1)
	assert_eq(g.spells_cast_count(1), 0, "per player")
	assert_ok(g.cast_spell(0, condor))
	resolve_stack()
	assert_eq(condor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.spells_cast_count(0), 2)


func test_the_count_ignores_copies_and_resets_with_the_turn() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R, 3)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	var fork := give_hand(0, "Fork")
	assert_ok(g.cast_spell(0, fork, [TargetRef.card(bolt)]))
	resolve_stack()
	assert_eq(g.spells_cast_count(0), 2, "Bolt and Fork; the copy was never cast (CR 707.10)")
	advance_to_next_turn()
	assert_eq(g.spells_cast_count(0), 0)


func test_the_count_comes_back_with_an_undo() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var mark := g.make_mark()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.spells_cast_count(0), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.spells_cast_count(0), 0)
	assert_eq(bolt.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------------- undo --

func test_a_granted_cast_unmakes_exactly() -> void:
	put_synthetic(0, _halls())
	var bolt := give_hand(0, "Lightning Bolt")
	var fodder := give_hand(0, "Lightning Bolt")
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)], 0, 1))
	while not g.stack.is_empty():
		g._resolve_top()
	assert_eq(g.players[1].life, 17)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[1].life, 20)
	assert_eq(bolt.zone, Mtg.Zone.HAND)
	assert_eq(fodder.zone, Mtg.Zone.HAND)
	assert_eq(g.payment_rows(0, bolt).size(), 2, "the rows are derived, never stored")


func test_the_rows_a_definition_reads_find_a_card_in_hand() -> void:
	# The AI planners price a row from the DEFINITION (spell_cost_for(pid,
	# data, x, mode)); a granted row is found through a card of that
	# definition in the caster's hand.
	put_synthetic(0, _aluren())
	var bear := give_synthetic(0, _bear())
	assert_true(ManaPlanner.cost_is_free(g.spell_cost_for(0, bear.data, 0, 1)))
	assert_eq(g.spell_cost_for(0, bear.data, 0, 0).mana_value(), 2)
