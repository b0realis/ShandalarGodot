extends GameTest
## Pack 10 (the Urza block), batch B7: Urza's Destiny's non-Aura
## enchantments in cards/sets/uds/_enchantments.gd — Sanctimony, Mental
## Discipline, Opposition, Attrition, Carnival of Souls, Yawgmoth's Bargain,
## Aether Sting, Goblin Festival, Impatience and Repercussion.

const CLAIMED := ["Sanctimony", "Mental Discipline", "Opposition", "Attrition", "Carnival of Souls",
	"Yawgmoth's Bargain", "Aether Sting", "Goblin Festival", "Impatience", "Repercussion"]

## Answers every yes/no with [member yes] and remembers the prompts.
class Seat extends DecisionAgent:
	var yes := true
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return yes

func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()

func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)

func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _cast_at(pid: int, spell: String, targets: Array, mana: Array) -> CardInstance:
	_priority_to(pid)
	var card := give_hand(pid, spell)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, card, targets))
	resolve_stack()
	return card


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_false(c.is_aura(), "%s is no Aura" % card_name)


# ------------------------------------------------------------------ Sanctimony --

func test_sanctimony_gains_when_an_opponent_taps_a_mountain() -> void:
	var seat := _seat(0)
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sanctimony")
	var mountain := put_battlefield(1, "Mountain")
	var forest := put_battlefield(1, "Forest")
	var own := put_battlefield(0, "Mountain")
	_priority_to(1)
	assert_ok(g.tap_for_mana(1, forest))
	assert_true(g.stack.is_empty(), "a Forest")
	assert_ok(g.tap_for_mana(1, mountain))
	assert_false(g.stack.is_empty(), "a trigger that uses the stack: it adds no mana")
	resolve_stack()
	assert_eq(g.players[0].life, 21)
	assert_eq(seat.asked.size(), 1)
	assert_ok(g.tap_for_mana(0, own))
	assert_true(g.stack.is_empty(), "your own Mountain")

func test_sanctimony_is_optional() -> void:
	var seat := _seat(0)
	seat.yes = false
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Sanctimony")
	var mountain := put_battlefield(1, "Mountain")
	_priority_to(1)
	assert_ok(g.tap_for_mana(1, mountain))
	resolve_stack()
	assert_eq(seat.asked.size(), 1)
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------------- Mental Discipline --

func test_mental_discipline_loots_for_mana_and_a_discard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var discipline := put_battlefield(0, "Mental Discipline")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, discipline, 0, []), "")
	var card := give_hand(0, "Lightning Bolt")
	assert_ok(g.activate_ability(0, discipline, 0, []))
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "discarded as the cost")
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1, "and a fresh card")


# ------------------------------------------------------------------ Opposition --

func test_opposition_taps_for_a_creature_even_a_summoning_sick_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var opposition := put_battlefield(0, "Opposition")
	var elves := put_battlefield(0, "Llanowar Elves", true)
	var giant := put_battlefield(1, "Hill Giant")
	var land := put_battlefield(1, "Forest")
	assert_ok(g.activate_ability(0, opposition, 0, [TargetRef.card(giant)]))
	resolve_stack()
	assert_true(giant.tapped)
	assert_true(elves.tapped, "the cost")
	assert_refused(g.activate_ability(0, opposition, 0, [TargetRef.card(land)]), "")
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.activate_ability(0, opposition, 0, [TargetRef.card(land)]))
	resolve_stack()
	assert_true(land.tapped, "a land is a legal target")
	assert_true(bear.tapped)

func test_opposition_cannot_tap_an_enchantment() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var opposition := put_battlefield(0, "Opposition")
	put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(1, "Sanctimony")
	assert_refused(g.activate_ability(0, opposition, 0, [TargetRef.card(other)]), "")


# ------------------------------------------------------------------- Attrition --

func test_attrition_trades_a_creature_for_a_nonblack_one() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var attrition := put_battlefield(0, "Attrition")
	var elves := put_battlefield(0, "Llanowar Elves")
	var giant := put_battlefield(1, "Hill Giant")
	var knight := put_battlefield(1, "Black Knight")
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, attrition, 0, [TargetRef.card(knight)]), "")
	assert_ok(g.activate_ability(0, attrition, 0, [TargetRef.card(giant)]))
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the cost")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.B)
	assert_refused(g.activate_ability(0, attrition, 0, [TargetRef.card(knight)]), "")


# ------------------------------------------------------------ Carnival of Souls --

func test_carnival_of_souls_charges_a_life_and_pays_a_black_for_every_creature() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Carnival of Souls")
	_cast_at(0, "Grizzly Bears", [], [Mtg.ManaColor.G, Mtg.ManaColor.C])
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1, "added as the trigger resolves")
	advance_to_next_turn()
	_cast_at(1, "Llanowar Elves", [], [Mtg.ManaColor.G])
	assert_eq(g.players[0].life, 18, "an opponent's creature too")
	assert_eq(g.players[1].life, 20)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1, "to the enchantment's controller")
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.B), 0)


# ---------------------------------------------------------- Yawgmoth's Bargain --

func test_yawgmoths_bargain_skips_the_draw_and_sells_cards_for_life() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bargain := put_battlefield(0, "Yawgmoth's Bargain")
	assert_ok(g.activate_ability(0, bargain, 0, []))
	resolve_stack()
	assert_eq(g.players[0].life, 19)
	assert_eq(g.players[0].hand.size(), 1)
	advance_to_next_turn()
	assert_eq(g.players[1].hand.size(), 1, "the opponent still draws")
	advance_to_next_turn()
	assert_eq(g.active_player, 0)
	assert_eq(g.players[0].hand.size(), 1, "no draw step for its controller")


# ----------------------------------------------------------------- Aether Sting --

func test_aether_sting_burns_an_opponent_for_each_creature_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Aether Sting")
	_cast_at(0, "Grizzly Bears", [], [Mtg.ManaColor.G, Mtg.ManaColor.C])
	assert_eq(g.players[0].life, 20, "not your own")
	advance_to_next_turn()
	_cast_at(1, "Llanowar Elves", [], [Mtg.ManaColor.G])
	assert_eq(g.players[1].life, 19)
	_cast_at(1, "Lightning Bolt", [TargetRef.player(0)], [Mtg.ManaColor.R])
	assert_eq(g.players[1].life, 19, "creature spells only")


# -------------------------------------------------------------- Goblin Festival --

func test_goblin_festival_pings_and_changes_hands_on_a_lost_flip() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var festival := put_battlefield(0, "Goblin Festival")
	var pinged := 0
	var guard := 0
	while festival.controller_id == 0 and guard < 30:
		add_mana(0, Mtg.ManaColor.C, 2)
		assert_ok(g.activate_ability(0, festival, 0, [TargetRef.player(1)]))
		resolve_stack()
		pinged += 1
		guard += 1
	assert_eq(festival.controller_id, 1, "a lost flip hands it to the opponent")
	assert_eq(g.players[1].life, 20 - pinged, "every activation dealt its 1 damage first")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.activate_ability(0, festival, 0, [TargetRef.player(1)]), "")


# ------------------------------------------------------------------ Impatience --

func test_impatience_burns_a_player_who_cast_nothing() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Impatience")
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[0].life, 18, "each player's end step, its controller's too")
	advance_to_next_turn()
	_cast_at(1, "Ancestral Recall", [TargetRef.player(1)], [Mtg.ManaColor.U])
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(g.players[1].life, 20, "they cast a spell this turn")

func test_impatience_rechecks_as_it_resolves() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Impatience")
	advance_to_step(Mtg.Step.END)
	assert_false(g.stack.is_empty())
	var recall := give_hand(0, "Ancestral Recall")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, recall, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, 20, "a spell cast in response: the 'if' fails (CR 603.4)")


# ---------------------------------------------------------------- Repercussion --

func test_repercussion_echoes_creature_damage_to_its_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Repercussion")
	var giant := put_battlefield(1, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	_cast_at(0, "Lightning Bolt", [TargetRef.card(giant)], [Mtg.ManaColor.R])
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 17, "that much, to that creature's controller")
	_cast_at(1, "Lightning Bolt", [TargetRef.card(bear)], [Mtg.ManaColor.R])
	assert_eq(g.players[0].life, 17, "its own controller's creatures too")
	_cast_at(0, "Lightning Bolt", [TargetRef.player(1)], [Mtg.ManaColor.R])
	assert_eq(g.players[1].life, 14, "damage to a player is not echoed")
