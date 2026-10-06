extends GameTest
## Pack 9 (the Tempest block), batch B2: what each Tempest buyback spell
## DOES (cards/sets/tmp/_buyback.gd) — Anoint, Capsize, Corpse Dance,
## Disturbed Burial, Elvish Fury, Evincar's Justice, Imps' Taunt,
## Invulnerability, Searing Touch, Whim of Volrath, Whispers of the Muse and
## Worthy Cause: each card's effect, its refused or illegal case, and the
## interactions its text implies. The buyback itself, card by card, is
## tests/cards/test_pack_9_B2_buyback.gd.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-9", false)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card

## P1 casts a Lightning Bolt at [param target] and passes: P0 holds
## priority over it.
func _their_bolt(target: TargetRef) -> CardInstance:
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [target]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	return bolt

## Into the OPPONENT's turn, P0 holding priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------------------- Anoint --

func test_anoint_prevents_the_next_three_damage_to_a_creature() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var anoint := give_hand(0, "Anoint")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, anoint, [TargetRef.card(giant)], 0, 0))
	resolve_stack()
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.damage, 0, "three of three prevented")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(anoint.data.spell_effects[0].is_damage_prevention, "legal in the 1997 window")

func test_anoint_targets_creatures_only() -> void:
	var anoint := give_hand(0, "Anoint")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, anoint, [TargetRef.player(0)], 0, 0))
	assert_eq(anoint.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Capsize --

func test_capsize_returns_any_permanent_to_its_owners_hand() -> void:
	var land := put_battlefield(1, "Mountain")
	var capsize := give_hand(0, "Capsize")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, capsize, [TargetRef.card(land)], 0, 0))
	resolve_stack()
	assert_true(g.players[1].hand.has(land))

func test_capsize_sends_a_stolen_creature_to_its_owner() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var magic := give_hand(0, "Control Magic")
	add_mana(0, Mtg.ManaColor.U, 4)
	assert_ok(g.cast_spell(0, magic, [TargetRef.card(bears)]))
	resolve_stack()
	assert_eq(bears.controller_id, 0)
	var capsize := give_hand(0, "Capsize")
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, capsize, [TargetRef.card(bears)], 0, 1))
	resolve_stack()
	assert_true(g.players[1].hand.has(bears), "its OWNER's hand")
	assert_true(g.players[0].hand.has(capsize), "bought back")

func test_capsize_cannot_target_a_player() -> void:
	var capsize := give_hand(0, "Capsize")
	add_mana(0, Mtg.ManaColor.U, 3)
	assert_refused(g.cast_spell(0, capsize, [TargetRef.player(1)], 0, 0))


# ------------------------------------------------------------- Corpse Dance --

func test_corpse_dance_returns_the_topmost_creature_card_with_haste() -> void:
	_to_graveyard(0, "Hill Giant")
	var bears := _to_graveyard(0, "Grizzly Bears")
	var land := _to_graveyard(0, "Forest")
	_to_graveyard(1, "Craw Wurm")
	var dance := give_hand(0, "Corpse Dance")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, dance, [], 0, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "the top CREATURE card: the Forest above it is passed over")
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.controller_id, 0)
	assert_true(bears.has_keyword(Mtg.Keyword.HASTE))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bears.id]))
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.EXILE, "exiled at the beginning of the next end step")

func test_corpse_dance_haste_is_until_end_of_turn_and_a_creature_that_left_stays_gone() -> void:
	var bears := _to_graveyard(0, "Grizzly Bears")
	var dance := give_hand(0, "Corpse Dance")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, dance, [], 0, 1))
	resolve_stack()
	assert_eq(dance.zone, Mtg.Zone.HAND)
	# Bounced before the end step: a new object in the hand, not exiled.
	g.return_to_hand(bears)
	advance_to_step(Mtg.Step.END)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND, "only exiled if still on the battlefield (ruling)")

func test_corpse_dance_with_no_creature_card_does_nothing() -> void:
	_to_graveyard(0, "Forest")
	_to_graveyard(1, "Grizzly Bears")
	var dance := give_hand(0, "Corpse Dance")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, dance, [], 0, 0))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), 0, "only YOUR graveyard")
	assert_eq(dance.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Disturbed Burial --

func test_disturbed_burial_returns_a_creature_card_to_the_hand() -> void:
	var bears := _to_graveyard(0, "Grizzly Bears")
	var burial := give_hand(0, "Disturbed Burial")
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, burial, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_true(g.players[0].hand.has(bears))

func test_disturbed_burial_refuses_a_noncreature_or_an_opponents_card() -> void:
	var land := _to_graveyard(0, "Forest")
	var theirs := _to_graveyard(1, "Grizzly Bears")
	var burial := give_hand(0, "Disturbed Burial")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_refused(g.cast_spell(0, burial, [TargetRef.card(land)], 0, 0))
	assert_refused(g.cast_spell(0, burial, [TargetRef.card(theirs)], 0, 0))
	assert_eq(burial.zone, Mtg.Zone.HAND)


# -------------------------------------------------------------- Elvish Fury --

func test_elvish_fury_pumps_until_end_of_turn() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var fury := give_hand(0, "Elvish Fury")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, fury, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	assert_eq([bears.cur_power, bears.cur_toughness], [4, 4], "any creature, theirs too")
	advance_to_next_turn()
	assert_eq([bears.cur_power, bears.cur_toughness], [2, 2])


# -------------------------------------------------------- Evincar's Justice --

func test_evincars_justice_hits_each_creature_and_each_player() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var justice := give_hand(0, "Evincar's Justice")
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, justice, [], 0, 0))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.damage, 2)
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)

func test_evincars_justice_is_a_sorcery() -> void:
	var justice := give_hand(0, "Evincar's Justice")
	_their_turn_at(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.B, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_refused(g.cast_spell(0, justice, [], 0, 0))


# ------------------------------------------------------------- Imps' Taunt --

func test_imps_taunt_makes_their_creature_attack() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var taunt := give_hand(0, "Imps' Taunt")
	_their_turn_at(Mtg.Step.UPKEEP)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, taunt, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(1, []), "must attack")
	assert_ok(g.declare_attackers(1, [bears.id]))

func test_imps_taunt_on_a_creature_that_cannot_attack_asks_nothing() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var taunt := give_hand(0, "Imps' Taunt")
	_their_turn_at(Mtg.Step.UPKEEP)
	g.tap_permanent(bears)
	add_mana(0, Mtg.ManaColor.B)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, taunt, [TargetRef.card(bears)], 0, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, []))   # a tapped creature is not able to attack


# --------------------------------------------------------- Invulnerability --

func test_invulnerability_prevents_the_next_damage_from_the_chosen_source() -> void:
	for preset in ["modern", "fifth"]:
		before_each()
		g.rules.set_preset(preset)
		var bolt := _their_bolt(TargetRef.player(0))
		var shield := give_hand(0, "Invulnerability")
		add_mana(0, Mtg.ManaColor.W)
		add_mana(0, Mtg.ManaColor.C, 4)
		assert_ok(g.cast_spell(0, shield, [], 0, 1))
		resolve_stack()
		assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(g.players[0].life, 20, "%s: the Bolt named as it resolved" % preset)
		assert_eq(shield.zone, Mtg.Zone.HAND, preset)
		assert_true(shield.data.spell_effects[0].is_damage_prevention)

func test_invulnerability_is_spent_by_one_event_and_guards_only_you() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var bolt := _their_bolt(TargetRef.card(giant))
	var shield := give_hand(0, "Invulnerability")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, shield, [], 0, 0))
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "damage to you only, never to a creature")


# ------------------------------------------------------------ Searing Touch --

func test_searing_touch_deals_one_damage_to_any_target() -> void:
	var touch := give_hand(0, "Searing Touch")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, touch, [TargetRef.player(1)], 0, 0))
	resolve_stack()
	assert_eq(g.players[1].life, 19)
	var elf := put_battlefield(1, "Llanowar Elves")
	touch = give_hand(0, "Searing Touch")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, touch, [TargetRef.card(elf)], 0, 0))
	resolve_stack()
	assert_eq(elf.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------- Whim of Volrath --

func test_whim_of_volrath_changes_a_land_type_until_end_of_turn() -> void:
	var forest := put_battlefield(1, "Forest")
	var whim := give_hand(0, "Whim of Volrath")
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, whim, [TargetRef.card(forest)], 0, 1))
	resolve_stack()
	assert_eq(whim.zone, Mtg.Zone.HAND, "bought back")
	assert_false(forest.has_subtype("forest"))
	assert_eq(forest.text_changes.size(), 1)
	advance_to_next_turn()
	assert_true(forest.has_subtype("forest"), "the change ended at cleanup (CR 514.2)")
	assert_true(forest.text_changes.is_empty())

func test_whim_of_volrath_rewrites_a_protection_colour() -> void:
	var knight := put_battlefield(1, "White Knight")
	assert_eq(knight.cur_protection, Mtg.ManaColor.B)
	var whim := give_hand(0, "Whim of Volrath")
	add_mana(0, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(0, whim, [TargetRef.card(knight)], 0, 0))
	resolve_stack()
	assert_ne(knight.cur_protection, Mtg.ManaColor.B, "black became another colour")
	var terror := give_hand(0, "Terror")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, terror, [TargetRef.card(knight)]))
	resolve_stack()
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD)

func test_whim_of_volrath_needs_a_word_it_can_change() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var whim := give_hand(0, "Whim of Volrath")
	add_mana(0, Mtg.ManaColor.U)
	assert_refused(g.cast_spell(0, whim, [TargetRef.card(bears)], 0, 0))
	assert_eq(whim.zone, Mtg.Zone.HAND)


# ------------------------------------------------------ Whispers of the Muse --

func test_whispers_of_the_muse_draws_a_card() -> void:
	var whispers := give_hand(0, "Whispers of the Muse")
	var before := g.players[0].hand.size()
	add_mana(0, Mtg.ManaColor.U)
	add_mana(0, Mtg.ManaColor.C, 5)
	assert_ok(g.cast_spell(0, whispers, [], 0, 1))
	resolve_stack()
	assert_eq(g.players[0].hand.size(), before + 1, "the Whispers came back and a card was drawn")


# ------------------------------------------------------------- Worthy Cause --

func test_worthy_cause_gains_the_sacrificed_creatures_toughness() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	var cause := give_hand(0, "Worthy Cause")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, cause, [], 0, 0))
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "sacrificed as it is cast")
	resolve_stack()
	assert_eq(g.players[0].life, 23)

func test_worthy_cause_reads_the_toughness_the_creature_last_had() -> void:
	var bears := put_battlefield(0, "Grizzly Bears")
	var growth := give_hand(0, "Giant Growth")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(bears)]))
	resolve_stack()
	var cause := give_hand(0, "Worthy Cause")
	add_mana(0, Mtg.ManaColor.W)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, cause, [], 0, 1))
	resolve_stack()
	assert_eq(g.players[0].life, 25, "a 5/5 as it was sacrificed (CR 608.2h)")
	assert_eq(cause.zone, Mtg.Zone.HAND)

func test_worthy_cause_gains_a_sacrificed_tokens_toughness() -> void:
	# A token ceases to exist once it leaves (CR 111.7), so nothing can be
	# looked up afterwards: the cost record keeps its toughness as paid.
	var token: CardInstance = g.create_token(0, CardData.new("Test Token", "", Mtg.CardType.CREATURE).pt(2, 3))[0]
	var cause := give_hand(0, "Worthy Cause")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, cause, [], 0, 0))
	assert_ne(token.zone, Mtg.Zone.BATTLEFIELD, "sacrificed as it is cast")
	resolve_stack()
	assert_eq(g.players[0].life, 23, "the token's toughness 3")

func test_worthy_cause_needs_a_creature_to_sacrifice() -> void:
	put_battlefield(0, "Plains")
	var cause := give_hand(0, "Worthy Cause")
	add_mana(0, Mtg.ManaColor.W)
	assert_refused(g.cast_spell(0, cause, [], 0, 0))
	assert_eq(g.players[0].mana_pool.total(), 1, "nothing paid")
	assert_eq(cause.zone, Mtg.Zone.HAND)
