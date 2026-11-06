extends GameTest
## Pack 10 (the Urza block), batch B13: the "put into a graveyard from
## anywhere" cards (Pack 10 E4, `Mtg.EventType.CARD_PUT_INTO_GRAVEYARD`) —
## Planar Void, Energy Field, Compost and Serra Avatar (with Pack 10 E3's
## life-total size).

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

const CLAIMED := ["Planar Void", "Energy Field", "Compost", "Serra Avatar"]

## A seat whose yes/no answers a test scripts (-1 follows the hint).
class Seat extends DecisionAgent:
	var yes := -1
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _cast(pid: int, card_name: String, targets: Array = []) -> CardInstance:
	_priority(pid)
	var card := give_hand(pid, card_name)
	for color in [W, U, B, R, G]: add_mana(pid, color, 4)
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

## Forbidden Crypt's replacement for [param pid] (a core-set stand-in for
## Yawgmoth's Will's second sentence).
static func _crypt() -> CardData:
	return CardData.new("Test Crypt", "{3}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(func(game: MtgGame, s: CardInstance) -> void:
			game.players[s.controller_id].graveyard_becomes_exile = true,
			"If a card would be put into your graveyard from anywhere, exile that card instead."))


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------- Planar Void --

func test_planar_void_exiles_every_other_card_put_into_a_graveyard() -> void:
	put_battlefield(0, "Planar Void")
	var discarded := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [discarded])
	resolve_stack()
	assert_eq(discarded.zone, Mtg.Zone.EXILE, "from a hand")
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := _cast(0, "Lightning Bolt", [TargetRef.card(bear)])
	assert_eq(bear.zone, Mtg.Zone.EXILE, "a death")
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "a resolved spell, its controller's own")
	g.mill(1, 2)
	resolve_stack()
	assert_true(g.players[1].graveyard.is_empty(), "a mill")


func test_planar_void_ignores_tokens_and_itself() -> void:
	var void_ := put_battlefield(0, "Planar Void")
	var token: CardInstance = g.create_token(1, CardData.new("Test Token", "", Mtg.CardType.CREATURE).pt(1, 1))[0]
	g.destroy(token)
	assert_true(g.stack.is_empty(), "a token is not a card")
	g.destroy(void_)
	assert_true(g.stack.is_empty(), "its own arrival is nobody's (CR 603.6c)")
	assert_eq(void_.zone, Mtg.Zone.GRAVEYARD)


func test_planar_void_exiles_a_second_planar_void() -> void:
	put_battlefield(0, "Planar Void")
	var other := put_battlefield(1, "Planar Void")
	g.destroy(other)
	resolve_stack()
	assert_eq(other.zone, Mtg.Zone.EXILE)


func test_planar_void_exiles_only_the_same_graveyard_object() -> void:
	put_battlefield(0, "Planar Void")
	var card := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [card])
	assert_eq(g.stack.size(), 1)
	g.return_from_graveyard_to_hand(card)   # in response, it leaves (CR 400.7)
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.HAND)


func test_planar_void_has_nothing_to_do_under_a_graveyard_replacement() -> void:
	put_battlefield(0, "Planar Void")
	put_synthetic(1, _crypt())
	g.recalculate()
	var card := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [card])
	assert_true(g.stack.is_empty(), "the card never reached a graveyard")
	assert_eq(card.zone, Mtg.Zone.EXILE)


# ------------------------------------------------------------ Energy Field --

func test_energy_field_prevents_damage_from_sources_you_dont_control() -> void:
	put_battlefield(0, "Energy Field")
	_cast(1, "Lightning Bolt", [TargetRef.player(0)])
	assert_eq(g.players[0].life, 20, "an opponent's spell")
	var ogre := put_battlefield(1, "Hill Giant")
	g.deal_damage(ogre, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 20, "an opponent's creature")


func test_energy_field_lets_your_own_sources_through() -> void:
	var field := put_battlefield(0, "Energy Field")
	var giant := put_battlefield(0, "Hill Giant")
	g.deal_damage(giant, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17)
	assert_eq(field.zone, Mtg.Zone.BATTLEFIELD)


func test_energy_field_is_sacrificed_when_a_card_reaches_your_graveyard() -> void:
	var field := put_battlefield(0, "Energy Field")
	var theirs := give_hand(1, "Grizzly Bears")
	g.discard_cards(1, [theirs])
	assert_true(g.stack.is_empty(), "not your graveyard")
	var mine := give_hand(0, "Grizzly Bears")
	g.discard_cards(0, [mine])
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(field.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_true(g.stack.is_empty(), "its own arrival triggers nothing")


func test_energy_field_goes_when_your_own_spell_resolves() -> void:
	var field := put_battlefield(0, "Energy Field")
	_cast(0, "Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17)
	assert_eq(field.zone, Mtg.Zone.GRAVEYARD, "the Bolt went to your graveyard")


func test_energy_field_survives_a_card_exiled_instead() -> void:
	var field := put_battlefield(0, "Energy Field")
	put_synthetic(0, _crypt())
	g.recalculate()
	g.discard_cards(0, [give_hand(0, "Grizzly Bears")])
	assert_true(g.stack.is_empty())
	assert_eq(field.zone, Mtg.Zone.BATTLEFIELD)


func test_energy_field_that_left_in_response_is_not_sacrificed_again() -> void:
	var field := put_battlefield(0, "Energy Field")
	g.discard_cards(0, [give_hand(0, "Grizzly Bears")])
	assert_eq(g.stack.size(), 1)
	g.return_to_hand(field)
	resolve_stack()
	assert_eq(field.zone, Mtg.Zone.HAND, "nothing to sacrifice")


# ------------------------------------------------------------------ Compost --

func test_compost_may_draw_for_a_black_card_into_an_opponents_graveyard() -> void:
	put_battlefield(0, "Compost")
	var hand := g.players[0].hand.size()
	var black := give_hand(1, "Hypnotic Specter")
	g.discard_cards(1, [black])
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand + 1)
	assert_eq(me.asked.size(), 1, "\"you may\": asked")


func test_compost_draw_is_optional() -> void:
	put_battlefield(0, "Compost")
	me.yes = 0
	var hand := g.players[0].hand.size()
	g.discard_cards(1, [give_hand(1, "Hypnotic Specter")])
	resolve_stack()
	assert_eq(g.players[0].hand.size(), hand)


func test_compost_ignores_other_colors_your_graveyard_and_tokens() -> void:
	put_battlefield(0, "Compost")
	g.discard_cards(1, [give_hand(1, "Grizzly Bears")])
	assert_true(g.stack.is_empty(), "not black")
	g.discard_cards(0, [give_hand(0, "Hypnotic Specter")])
	assert_true(g.stack.is_empty(), "your own graveyard")
	var token: CardInstance = g.create_token(1, CardData.new("Test Zombie", "{B}", Mtg.CardType.CREATURE).pt(2, 2))[0]
	g.destroy(token)
	assert_true(g.stack.is_empty(), "a token is not a card")


func test_compost_hears_a_countered_black_spell() -> void:
	put_battlefield(0, "Compost")
	var hand := g.players[0].hand.size()
	_priority(1)
	var ritual := give_hand(1, "Dark Ritual")
	add_mana(1, B)
	assert_ok(g.cast_spell(1, ritual))
	_priority(0)
	var counter := give_hand(0, "Counterspell")
	add_mana(0, U, 2)
	assert_ok(g.cast_spell(0, counter, [TargetRef.card(ritual)]))
	resolve_stack()
	assert_eq(ritual.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), hand + 1, "drew for the countered Dark Ritual")


# ------------------------------------------------------------- Serra Avatar --

func test_serra_avatar_is_as_big_as_its_controllers_life() -> void:
	var avatar := put_battlefield(0, "Serra Avatar")
	assert_eq([avatar.cur_power, avatar.cur_toughness], [20, 20])
	g.adjust_life(0, -7)
	assert_eq([avatar.cur_power, avatar.cur_toughness], [13, 13])
	g.change_control(avatar, 1)
	g.adjust_life(1, 5)
	assert_eq([avatar.cur_power, avatar.cur_toughness], [25, 25], "its controller's")


func test_serra_avatar_in_hand_reads_its_owner() -> void:
	var avatar := give_hand(0, "Serra Avatar")
	g.adjust_life(0, -2)
	g.recalculate()
	assert_eq(avatar.cur_power, 18)


func test_serra_avatar_dies_when_life_drops_below_its_damage() -> void:
	var avatar := put_battlefield(0, "Serra Avatar")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(avatar), 5)
	assert_eq(avatar.zone, Mtg.Zone.BATTLEFIELD)
	g.adjust_life(0, -16)   # 4 life: a 4/4 with 5 damage
	g.check_state_based_actions()
	assert_ne(avatar.zone, Mtg.Zone.BATTLEFIELD, "judged at the same check (E3)")


func test_serra_avatar_dies_in_the_check_after_a_mana_burn() -> void:
	g.rules.set_fork("mana_burn", true)
	g.rules.set_fork("pool_empties_on_attack", false)
	var avatar := put_battlefield(0, "Serra Avatar")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(avatar), 5)
	g.adjust_life(0, -13)   # 7 life: a 7/7 with 5 damage
	g.check_state_based_actions()
	assert_eq(avatar.zone, Mtg.Zone.BATTLEFIELD)
	add_mana(0, R, 3)
	g._close_step_boundary()   # the pool empties and burns 3 (CR 500.4)
	assert_eq(g.players[0].life, 4)
	assert_ne(avatar.zone, Mtg.Zone.BATTLEFIELD,
		"a 4/4 with 5 damage, judged in the burn's own state-based check")


func test_serra_avatar_survives_a_step_boundary_without_a_burn() -> void:
	g.rules.set_fork("mana_burn", false)
	var avatar := put_battlefield(0, "Serra Avatar")
	var giant := put_battlefield(1, "Hill Giant")
	g.deal_damage(giant, TargetRef.card(avatar), 5)
	g.adjust_life(0, -13)
	add_mana(0, R, 3)
	g._close_step_boundary()
	assert_eq(g.players[0].life, 7, "the control: no mana burn")
	assert_eq(avatar.zone, Mtg.Zone.BATTLEFIELD)


func test_serra_avatar_shuffles_itself_back_from_the_battlefield() -> void:
	var avatar := put_battlefield(0, "Serra Avatar")
	var library := g.players[0].library.size()
	g.destroy(avatar)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.size(), library + 1)


func test_serra_avatar_shuffles_itself_back_from_hand_library_and_stack() -> void:
	var avatar := give_hand(0, "Serra Avatar")
	g.discard_cards(0, [avatar])
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY, "discarded")
	g.players[0].library.erase(avatar)
	g.players[0].library.append(avatar)   # on top (setup)
	g.mill(0, 1)
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.LIBRARY, "milled")
	var cast := give_hand(0, "Serra Avatar")
	for color in [W, U, B, R, G]: add_mana(0, color, 4)
	assert_ok(g.cast_spell(0, cast))
	_priority(1)
	var counter := give_hand(1, "Counterspell")
	add_mana(1, U, 2)
	assert_ok(g.cast_spell(1, counter, [TargetRef.card(cast)]))
	resolve_stack()
	assert_eq(cast.zone, Mtg.Zone.LIBRARY, "countered")


func test_serra_avatar_exiled_instead_stays_exiled() -> void:
	put_synthetic(0, _crypt())
	g.recalculate()
	var avatar := put_battlefield(0, "Serra Avatar")
	g.destroy(avatar)
	assert_eq(avatar.zone, Mtg.Zone.EXILE)
	assert_true(g.stack.is_empty())


func test_serra_avatar_that_left_the_graveyard_is_not_shuffled() -> void:
	var avatar := give_hand(0, "Serra Avatar")
	g.discard_cards(0, [avatar])
	assert_eq(g.stack.size(), 1)
	g.return_from_graveyard_to_hand(avatar)   # in response
	resolve_stack()
	assert_eq(avatar.zone, Mtg.Zone.HAND)
