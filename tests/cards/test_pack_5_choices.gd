extends GameTest

func before_each() -> void:
	CardPacks.set_enabled("pack-5", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)
func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-5", false)
func cast(name: String, targets: Array = [], x := 0, mode := 0) -> CardInstance:
	var card := give_hand(0, name)
	for color in Mtg.WUBRG: add_mana(0, color, 20)
	assert_ok(g.cast_spell(0, card, targets, x, mode))
	resolve_stack()
	return card

func test_primitive_justice_pays_per_target_and_records_green_life() -> void:
	var a := put_battlefield(1, "Sol Ring")
	var b := put_battlefield(1, "Jayemdae Tome")
	var spell := give_hand(0, "Primitive Justice")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.stack.back().cost_paid.restricted_x_paid.get(Mtg.ManaColor.G, 0), 1)
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 21)

func test_primitive_justice_cannot_buy_extra_target_with_only_generic_mana() -> void:
	var a := put_battlefield(1, "Sol Ring")
	var b := put_battlefield(1, "Jayemdae Tome")
	var spell := give_hand(0, "Primitive Justice")
	add_mana(0, Mtg.ManaColor.R)
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_refused(g.cast_spell(0, spell, [TargetRef.card(a), TargetRef.card(b)]))
	assert_eq(g.players[0].mana_pool.total(), 4)

func test_taste_of_paradise_pays_repetitions_before_stack_without_changing_mana_value() -> void:
	var spell := give_hand(0, "Taste of Paradise")
	add_mana(0, Mtg.ManaColor.G, 3)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, spell, [], 2))
	assert_eq(spell.data.cost.mana_value(), 4)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(g.players[0].life, 20)
	resolve_stack()
	assert_eq(g.players[0].life, 29)

func test_undergrowth_paid_mode_keeps_red_combat_damage_only() -> void:
	var red := put_battlefield(0, "Hill Giant")
	var green := put_battlefield(1, "Grizzly Bears")
	cast("Undergrowth", [], 0, 1)
	g.deal_damage(red, TargetRef.player(1), 3, true)
	g.deal_damage(green, TargetRef.player(0), 2, true)
	assert_eq(g.players[1].life, 17)
	assert_eq(g.players[0].life, 20)

func test_gusthas_scepter_hides_names_from_opponent_and_returns_owned_card() -> void:
	var scepter := put_battlefield(0, "Gustha's Scepter")
	var card := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, scepter, 0))
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.EXILE)
	assert_true(card.face_down)
	assert_eq(card.exile_visible_to, 0)
	var theirs := JSON.stringify(AiObservation.capture(g, 1).players[0].exile)
	assert_false(theirs.contains("Forest"))
	var ours := JSON.stringify(AiObservation.capture(g, 0).players[0].exile)
	assert_true(ours.contains("Forest"))
	g.untap_permanent(scepter)
	assert_ok(g.activate_ability(0, scepter, 1))
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.HAND)

func test_scepter_losing_control_moves_linked_cards_to_graveyard() -> void:
	var scepter := put_battlefield(0, "Gustha's Scepter")
	var card := give_hand(0, "Forest")
	assert_ok(g.activate_ability(0, scepter, 0))
	resolve_stack()
	g.change_control(scepter, 1)
	resolve_stack()
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)

func test_martyrdom_redirects_one_point_from_player_not_the_whole_event() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Martyrdom", [TargetRef.card(bear)])
	assert_ok(g.activate_ability(0, bear, 0, [TargetRef.player(0)]))
	resolve_stack()
	var bolt := give_hand(1, "Lightning Bolt")
	g.deal_damage(bolt, TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 18)
	assert_eq(bear.damage, 1)

func test_martyrdom_grant_belongs_to_original_caster_even_after_theft() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Martyrdom", [TargetRef.card(bear)])
	g.change_control(bear, 1)
	assert_ok(g.activate_ability(0, bear, 0, [TargetRef.player(0)]))
	resolve_stack()
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, bear, 0, [TargetRef.player(1)]))

func test_martyrdom_does_not_follow_blinked_recipient() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Martyrdom", [TargetRef.card(bear)])
	assert_ok(g.activate_ability(0, bear, 0, [TargetRef.player(0)]))
	resolve_stack()
	g.return_to_hand(bear)
	g.put_from_hand_into_play(bear, 0)
	g.deal_damage(give_hand(1, "Lightning Bolt"), TargetRef.player(0), 3)
	assert_eq(g.players[0].life, 17)
	assert_eq(bear.damage, 0)

func test_bounty_counters_survive_end_step_then_are_removed_at_cleanup() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	cast("Bounty of the Hunt", [TargetRef.card(bear)])
	assert_eq(bear.cur_power, 5)
	advance_to_step(Mtg.Step.END)
	assert_eq(bear.cur_power, 5)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2)

func test_lodestone_bauble_targets_only_one_players_basic_lands() -> void:
	var a := put_battlefield(0, "Forest")
	var b := put_battlefield(1, "Island")
	g.destroy(a)
	g.destroy(b)
	var bauble := put_battlefield(0, "Lodestone Bauble")
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.activate_ability(0, bauble, 0, [TargetRef.card(a), TargetRef.card(b)]))
	assert_ok(g.activate_ability(0, bauble, 0, [TargetRef.card(a)]))
	resolve_stack()
	assert_eq(a.zone, Mtg.Zone.LIBRARY)
	assert_eq(g.players[0].library.back(), a)

func test_splinter_token_has_flying_and_upkeep_and_departure_damage() -> void:
	var wind := put_battlefield(0, "Splintering Wind")
	var bear := put_battlefield(1, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 3)
	assert_ok(g.activate_ability(0, wind, 0, [TargetRef.card(bear)]))
	resolve_stack()
	var token := g.players[0].creatures()[0]
	assert_eq(token.data.card_name, "Splinter")
	assert_true(token.has_keyword(Mtg.Keyword.FLYING))
	g.destroy(wind)
	g.sacrifice_permanent(token)
	resolve_stack()
	assert_eq(g.players[0].life, 19)

func test_phelddagrif_uses_blue_mana_for_return_and_white_for_flight() -> void:
	var hippo := put_battlefield(0, "Phelddagrif")
	assert_eq(hippo.cur_activated_abilities[2].cost.colored.get(Mtg.ManaColor.U, 0), 1)
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.activate_ability(0, hippo, 1, [TargetRef.player(1)]))
	resolve_stack()
	assert_true(hippo.has_keyword(Mtg.Keyword.FLYING))
	assert_eq(g.players[1].life, 22)

func test_portal_only_uses_ten_cards_and_conserves_library_hand_exile_count() -> void:
	var portal := put_battlefield(0, "Phyrexian Portal")
	var before := g.players[0].library.size()
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, portal, 0, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), 1)
	assert_eq(g.players[0].library.size() + g.players[0].hand.size() + g.players[0].exile.size(), before)

func test_vault_keeps_five_top_cards_and_preserves_every_card() -> void:
	var original: Array = g.players[0].library.slice(-5)
	var before := g.players[0].library.size()
	cast("Lim-Dûl's Vault")
	assert_eq(g.players[0].library.size(), before)
	for i in g.players[0].library.slice(-5): assert_has(original, i)
	assert_eq(g.players[0].life, 20)

## Keeps the first five it is shown and orders them by [member order]
## (instance ids, top first), noting the library's size at every ask.
## (Campaign 2026-10, w2-10: "look again?" is a yes/no since then — it is
## answered no here, and counted with the card asks.)
class VaultOrderSeat extends DecisionAgent:
	var order: Array = []
	var library_sizes: Array = []

	func answer_yes_no(game: MtgGame, pid: int, _prompt: String, _hint: bool) -> bool:
		library_sizes.append(game.players[pid].library.size())
		return false

	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		library_sizes.append(game.players[pid].library.size())
		for id in order:
			for card in candidates:
				if card.id == id: return card
		return candidates[0]

# Bug pass 2026-10-03: the Vault's last step moved cards through the library
# array by hand (hard rule 2), lifting the five out for the shuffle, so they
# were in no zone while their order was asked. Now the whole library
# shuffles and the five go on top through MtgGame.move_library_card_to_top.
func test_vault_orders_the_kept_five_on_top_without_lifting_them_out() -> void:
	var before: Array = g.players[0].library.duplicate()
	var top: Array = before.slice(-5)   # the back of the array is the top
	var seat := VaultOrderSeat.new()
	seat.order = [top[1].id, top[3].id, top[0].id, top[4].id, top[2].id]
	g.set_agent(0, seat)
	var vault := give_hand(0, "Lim-Dûl's Vault")
	for color in Mtg.WUBRG: add_mana(0, color, 2)
	var mark := g.make_mark()
	assert_ok(g.cast_spell(0, vault, []))
	resolve_stack()
	var now: Array = g.players[0].library
	var top_first: Array = []
	for n in 5: top_first.append(now[now.size() - 1 - n].id)
	assert_eq(top_first, seat.order, "the chosen order, the first choice on top")
	assert_eq(now.size(), before.size())
	for card in before:
		assert_eq(now.count(card), 1)
		assert_eq(card.zone, Mtg.Zone.LIBRARY)
	assert_eq(seat.library_sizes.size(), 6, "keep these five (a no to looking again), then five ordering picks")
	for size in seat.library_sizes:
		assert_eq(size, before.size(), "every card stayed in the library while asked")
	assert_eq(g.players[0].life, 20)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(g.players[0].library, before, "the journal puts the library back")
