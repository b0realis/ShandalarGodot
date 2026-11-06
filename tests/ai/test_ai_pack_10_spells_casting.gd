extends GameTest
## Pack 10 (the Urza block), the fair AI's PRICE OF A CAST and RESPONSES
## (stage 4; engine/ai/urza_spells.gd `cast_adjustment` and `respond`,
## [member AiProfile.forecasts_tactics]).
##
## "Untap up to N lands" hands back the mana the cast paid with: a Great
## Whale cast first leaves seven lands for the Mahamoti Djinn, cast second
## it never comes. A creature spell into the opponent's dormant Opal
## Archangel makes them a 5/5 flier — a public trigger condition, priced
## before the cast. Humble and Redeem wait for a declared combat and are
## never cast into our own main phase. With the gate off the pilot casts as
## before Pack 10.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-10", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _lands(pid: int, land: String, n: int) -> void:
	for _i in n:
		put_battlefield(pid, land)


func _main_actions(ai: AiPlayer, n: int) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	g.players[0].lands_played_this_turn = 99
	for _i in n:
		ai.act(g)
		resolve_stack()


## Their attack with [param attackers], our blocks [param blocks]
## (blocker id -> attacker id); seat 0 then holds priority in the
## declare-blockers step.
func _their_attack(attackers: Array, blocks: Dictionary) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	var ids: Array = []
	for a in attackers: ids.append(a.id)
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while not g.awaiting_blockers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, blocks))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)


func _finish_combat() -> void:
	var guard := 0
	while g.current_step() != Mtg.Step.COMBAT_END and not g.game_over and guard < 100:
		_advance_once()
		guard += 1


# ------------------------------------------------------------- the mana handed back --

func test_the_whale_is_cast_first_and_pays_for_the_djinn() -> void:
	var ai := _ai()
	_lands(0, "Island", 7)
	var whale := give_hand(0, "Great Whale")
	var djinn := give_hand(0, "Mahamoti Djinn")
	_main_actions(ai, 4)
	assert_eq(whale.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD, "the seven lands came back")


func test_the_null_arm_casts_the_djinn_first() -> void:
	var ai := _ai(false)
	_lands(0, "Island", 7)
	var whale := give_hand(0, "Great Whale")
	var djinn := give_hand(0, "Mahamoti Djinn")
	_main_actions(ai, 4)
	assert_eq(djinn.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(whale.zone, Mtg.Zone.HAND, "gate off: the bigger card first, as before Pack 10")


func test_the_untap_spell_is_read_as_a_refund() -> void:
	var data := CardRegistry.get_card("Snap")
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	assert_eq(intent.untaps_lands, 2)
	assert_true(intent.bounces)
	assert_false(intent.unknown, "a bounce and a refund, not an unknown card")


# ------------------------------------------------------------- their dormant Opals --

func _giant_or_tome(on: bool) -> Array:
	var ai := _ai(on)
	_lands(0, "Forest", 3)
	_lands(0, "Mountain", 3)
	put_battlefield(1, "Opal Archangel")
	var giant := give_hand(0, "Hill Giant")
	var tome := give_hand(0, "Jayemdae Tome")
	_main_actions(ai, 1)
	return [giant, tome]


func test_the_creature_waits_behind_a_card_that_wakes_nothing() -> void:
	var cards := _giant_or_tome(true)
	assert_eq(cards[1].zone, Mtg.Zone.BATTLEFIELD, "the Tome first")
	assert_eq(cards[0].zone, Mtg.Zone.HAND, "the Giant would make them a 5/5 flier")


func test_the_null_arm_wakes_the_archangel() -> void:
	var cards := _giant_or_tome(false)
	assert_eq(cards[0].zone, Mtg.Zone.BATTLEFIELD, "gate off: the Giant first, as before Pack 10")


func test_a_hand_of_creatures_alone_still_plays() -> void:
	var ai := _ai()
	_lands(0, "Forest", 2)
	put_battlefield(1, "Opal Archangel")
	var bears := give_hand(0, "Grizzly Bears")
	_main_actions(ai, 2)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "nothing in hand wakes nothing: the price of playing")


func test_without_the_archangel_the_giant_is_cast_first() -> void:
	var ai := _ai()
	_lands(0, "Forest", 3)
	_lands(0, "Mountain", 3)
	var giant := give_hand(0, "Hill Giant")
	give_hand(0, "Jayemdae Tome")
	_main_actions(ai, 1)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


func test_a_noncreature_spell_wakes_no_archangel() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	put_battlefield(1, "Opal Archangel")
	var tome := give_hand(0, "Jayemdae Tome")
	_main_actions(ai, 2)
	assert_eq(tome.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------ the responses --

func test_humble_and_redeem_wait_for_a_combat() -> void:
	var ai := _ai()
	_lands(0, "Plains", 4)
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	var humble := give_hand(0, "Humble")
	var redeem := give_hand(0, "Redeem")
	_main_actions(ai, 3)
	assert_eq(humble.zone, Mtg.Zone.HAND)
	assert_eq(redeem.zone, Mtg.Zone.HAND)


func test_humble_turns_their_wurm_into_a_meal() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Humble")
	_their_attack([wurm], {bears.id: wurm.id})
	assert_string_contains(ai.act(g), "Humble")
	resolve_stack()
	_finish_combat()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "a 0/1 blocked by a 2/2")


func test_redeem_saves_two_blockers() -> void:
	var ai := _ai()
	_lands(0, "Plains", 2)
	var first := put_battlefield(0, "Serra Angel")
	var second := put_battlefield(0, "Serra Angel")
	var wurm_a := put_battlefield(1, "Craw Wurm")
	var wurm_b := put_battlefield(1, "Craw Wurm")
	give_hand(0, "Redeem")
	_their_attack([wurm_a, wurm_b], {first.id: wurm_a.id, second.id: wurm_b.id})
	assert_string_contains(ai.act(g), "Redeem")
	resolve_stack()
	_finish_combat()
	assert_eq(first.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(second.zone, Mtg.Zone.BATTLEFIELD)


func test_the_null_arm_has_no_humble_moment() -> void:
	var ai := _ai(false)
	_lands(0, "Plains", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	var wurm := put_battlefield(1, "Craw Wurm")
	var humble := give_hand(0, "Humble")
	_their_attack([wurm], {bears.id: wurm.id})
	ai.act(g)
	assert_eq(humble.zone, Mtg.Zone.HAND)
