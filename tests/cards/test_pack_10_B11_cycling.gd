extends GameTest
## Pack 10 (the Urza block), batch B11: CYCLING on every card of
## cards/sets/usg/_cycling.gd, ulg/_cycling.gd and uds/_cycling.gd, read off
## the real registry cards (the engine's own mechanism is pinned by
## tests/unit/test_pack_10_engine_E2_cycling.gd). Each card is claimed (no
## pending guard), prints "Cycling {2}" as its LAST activated ability, and
## cycles from its owner's hand at instant speed: {2}, the card to the
## graveyard as the cost, a card drawn as the ability resolves. The cycling
## lands are played or cycled, and have no cycling on the battlefield.

const USG := ["Clear", "Disciple of Grace", "Disciple of Law", "Rune of Protection: Artifacts",
	"Rune of Protection: Black", "Rune of Protection: Blue", "Rune of Protection: Green",
	"Rune of Protection: Lands", "Rune of Protection: Red", "Rune of Protection: White",
	"Shimmering Barrier", "Drifting Djinn", "Lingering Mirage", "Pendrell Drake", "Power Taint",
	"Rescind", "Sandbar Merfolk", "Sandbar Serpent", "Expunge", "Sicken", "Brand", "Lay Waste",
	"Scrap", "Hush", "Lull", "Rejuvenate", "Wild Dogs", "Blasted Landscape", "Drifting Meadow",
	"Polluted Mire", "Remote Isle", "Slippery Karst", "Smoldering Crater"]
const ULG := ["Iron Will", "Radiant's Judgment", "Cloud of Faeries", "Miscalculation", "Rebuild",
	"Swat", "Unearth", "Bloated Toad", "Darkwatch Elves", "Repopulate"]
const UDS := ["Fend Off", "Rapid Decay", "Flame Jet"]
const CYCLING_LANDS := ["Blasted Landscape", "Drifting Meadow", "Polluted Mire", "Remote Isle",
	"Slippery Karst", "Smoldering Crater"]


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


static func _all() -> Array:
	return USG + ULG + UDS


## A deep library for [param pid], so many draws never deck them.
func _stock_library(pid: int, count: int) -> void:
	for _i in count:
		var inst := _make_instance(pid, "Forest")
		inst.zone = Mtg.Zone.LIBRARY
		g.players[pid].library.append(inst)


static func _cycling_index(inst: CardInstance) -> int:
	for i in inst.cur_activated_abilities.size():
		if inst.cur_activated_abilities[i].is_cycling:
			return i
	return -1


func test_every_b11_card_is_claimed_and_prints_cycling_last() -> void:
	assert_eq(_all().size(), 46, "45 cycling cards here + Veiled Serpent (B12) = 47 with cycling")
	for card_name in _all():
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending",
			"%s is claimed" % card_name)
		assert_true(c.has_cycling(), card_name)
		var last: ActivatedAbility = c.activated_abilities.back()
		assert_true(last.is_cycling, "%s: cycling is its last ability" % card_name)
		assert_eq(last.activation_zone, Mtg.Zone.HAND, card_name)
		assert_true(last.discard_self_cost, card_name)
		assert_eq(last.cost.text, "{2}", card_name)
		assert_eq(last.text, "Cycling {2} ({2}, Discard this card: Draw a card.)", card_name)
		assert_true(c.oracle_text.ends_with("Cycling {2} ({2}, Discard this card: Draw a card.)"), card_name)
		var cycling_count := 0
		for ability in c.activated_abilities:
			if ability.is_cycling: cycling_count += 1
		assert_eq(cycling_count, 1, "%s: one cycling ability" % card_name)


func test_fluctuator_is_claimed_and_prints_no_cycling() -> void:
	var c := CardRegistry.get_card("Fluctuator")
	assert_false(c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending")
	assert_false(c.has_cycling())
	assert_false(c.cost_modifier.get("ability_floored", {}).is_empty())


func test_every_b11_card_cycles_from_hand_at_instant_speed() -> void:
	_stock_library(0, 60)
	# Their main phase: no sorcery-speed cast, and no land drop, is ours.
	advance_to_next_turn()
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	for card_name in _all():
		var card := give_hand(0, card_name)
		var hand_before := g.players[0].hand.size()
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_eq(g.ability_announce_refusal(0, card, _cycling_index(card)), "", card_name)
		assert_ok(g.activate_ability(0, card, _cycling_index(card)))
		assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "%s is discarded as the cost" % card_name)
		assert_eq(g.stack.size(), 1, card_name)
		resolve_stack()
		assert_eq(g.players[0].hand.size(), hand_before, "%s: one out, one drawn" % card_name)
		if g.priority_player != 0:
			assert_ok(g.pass_priority(g.priority_player))


func test_only_the_owner_cycles_and_only_from_the_hand() -> void:
	var clear := give_hand(0, "Clear")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(1, clear, _cycling_index(clear)), "owner")
	assert_eq(clear.zone, Mtg.Zone.HAND)
	var toad := put_battlefield(1, "Bloated Toad")
	assert_refused(g.activate_ability(1, toad, _cycling_index(toad)), "not available from this zone")


func test_a_cycling_land_is_played_or_cycled_never_both() -> void:
	for land_name in CYCLING_LANDS:
		var land := give_hand(0, land_name)
		assert_true(land.is_land(), land_name)
	var played := g.players[0].hand[0]
	assert_ok(g.play_land(0, played))
	assert_eq(played.zone, Mtg.Zone.BATTLEFIELD)
	assert_refused(g.activate_ability(0, played, _cycling_index(played)), "not available from this zone")
	# The drop is spent, but cycling another is still open.
	var cycled := g.players[0].hand[0]
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, cycled, _cycling_index(cycled)))
	resolve_stack()
	assert_eq(cycled.zone, Mtg.Zone.GRAVEYARD)


func test_the_cycling_lands_tap_for_their_color_and_five_enter_tapped() -> void:
	var expected := {"Blasted Landscape": Mtg.ManaColor.C, "Drifting Meadow": Mtg.ManaColor.W,
		"Polluted Mire": Mtg.ManaColor.B, "Remote Isle": Mtg.ManaColor.U,
		"Slippery Karst": Mtg.ManaColor.G, "Smoldering Crater": Mtg.ManaColor.R}
	for land_name in CYCLING_LANDS:
		var c := CardRegistry.get_card(land_name)
		assert_eq(c.enters_tapped, land_name != "Blasted Landscape", land_name)
		assert_eq(c.mana_abilities.size(), 1, land_name)
		var land := put_battlefield(0, land_name)
		land.tapped = false   # the setup shortcut entered it tapped
		assert_ok(g.tap_for_mana(0, land))
		assert_eq(g.players[0].mana_pool.amount_of(int(expected[land_name])), 1, land_name)
		g.players[0].mana_pool.clear()


func test_a_drifting_meadow_played_from_hand_enters_tapped() -> void:
	var meadow := give_hand(0, "Drifting Meadow")
	assert_ok(g.play_land(0, meadow))
	assert_true(meadow.tapped)


func test_a_real_cycling_card_is_offered_over_sgmanalink_to_its_owner() -> void:
	var clear := give_hand(0, "Clear")
	add_mana(0, Mtg.ManaColor.C, 2)
	var abilities := SgDuelActions.options(clear, 0, g).filter(
		func(option: Dictionary) -> bool: return option.kind == "ability")
	assert_eq(abilities.size(), 1)
	assert_eq(int(abilities[0].index), _cycling_index(clear))
	assert_true(SgDuelActions.options(clear, 1, g).filter(
		func(option: Dictionary) -> bool: return option.kind == "ability").is_empty())


func test_the_fair_ai_cycles_a_dead_scrap_at_their_end_step_and_not_with_the_gate_off() -> void:
	for forecasts in [true, false]:
		before_each()
		var p := AiProfile.wizard()
		p.develops_late = false
		p.forecasts_tactics = forecasts
		var ai := AiPlayer.new(0, p)
		g.set_agent(0, ai)
		put_battlefield(0, "Mountain")
		put_battlefield(0, "Mountain")
		var scrap := give_hand(0, "Scrap")
		var guard := 0
		while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
			_advance_once()
			guard += 1
		if g.priority_player == 1:
			assert_ok(g.pass_priority(1))
		ai.act(g)
		assert_eq(scrap.zone, Mtg.Zone.GRAVEYARD if forecasts else Mtg.Zone.HAND,
			"forecasts_tactics %s" % forecasts)
