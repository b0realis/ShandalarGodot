extends GameTest
## Pack 8 (the Mirage block), batch B7: the global-rules half of the Mirage
## module (cards/sets/mir/_misc.gd) — Celestial Dawn, Null Chamber, Bazaar
## of Wonders, Forbidden Crypt, Forsaken Wastes, Tombstone Stairwell,
## Chaosphere, Hall of Gemstone and Unfulfilled Desires.

const CLAIMED := ["Celestial Dawn", "Null Chamber", "Bazaar of Wonders", "Forbidden Crypt",
	"Forsaken Wastes", "Tombstone Stairwell", "Chaosphere", "Hall of Gemstone", "Unfulfilled Desires"]


class Scripted extends DecisionAgent:
	var options: Array = []   # int index or String label fragment
	var answers: Array = []   # bool
	var picks: Array = []     # CardInstance or card name
	var colors: Array = []    # Mtg.ManaColor
	var offered: Array = []   # every option list asked, joined
	var color_hints: Array[int] = []

	func answer_option(_g: MtgGame, _p: int, _prompt: String,
			labels: Array[String], hint: int) -> int:
		offered.append(", ".join(labels))
		if options.is_empty():
			return hint
		var want: Variant = options.pop_front()
		if want is String:
			for i in labels.size():
				if labels[i].to_lower() == String(want).to_lower():
					return i
			return hint
		return int(want)

	func answer_yes_no(_g: MtgGame, _p: int, _prompt: String, hint: bool) -> bool:
		return bool(answers.pop_front()) if not answers.is_empty() else hint

	func answer_card(_g: MtgGame, _p: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		if picks.is_empty():
			return null if candidates.is_empty() else candidates[0]
		var want: Variant = picks.pop_front()
		for c in candidates:
			if want is CardInstance and c == want:
				return c
			if want is String and c.data.card_name == want:
				return c
		return null if candidates.is_empty() else candidates[0]

	func answer_color(_g: MtgGame, _p: int, _prompt: String, hint: int) -> int:
		color_hints.append(hint)
		return int(colors.pop_front()) if not colors.is_empty() else hint


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	CardRegistry.ensure_loaded()
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func seat(pid: int) -> Scripted:
	var a := Scripted.new()
	g.set_agent(pid, a)
	return a


func fund(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost
	for c in cost.colored:
		add_mana(pid, c, int(cost.colored[c]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)


func cast(name: String, targets: Array = [], x := 0, pid := 0) -> CardInstance:
	var card := give_hand(pid, name)
	fund(pid, card, x)
	assert_ok(g.cast_spell(pid, card, targets, x))
	resolve_stack()
	return card


func bury(pid: int, name: String) -> CardInstance:
	var inst := put_battlefield(pid, name)
	g.destroy(inst)
	assert_eq(inst.zone, Mtg.Zone.GRAVEYARD)
	return inst


func tokens_of(pid: int, name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for inst in g.players[pid].battlefield:
		if inst.is_token and inst.data.card_name == name:
			out.append(inst)
	return out


## Pass priority until [param pid]'s turn is at [param step] (resolving
## nothing on the way beyond what passing does).
func to_step_of(pid: int, step: int) -> void:
	var guard := 0
	if g.active_player == pid and g.current_step() == step:
		_advance_once()
	while not (g.active_player == pid and g.current_step() == step) and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ---------------------------------------------------------- Celestial Dawn --

func test_celestial_dawn_makes_your_lands_plains_and_leaves_theirs() -> void:
	var forest := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Forest")
	cast("Celestial Dawn")
	assert_true(forest.has_subtype("plains"))
	assert_false(forest.has_subtype("forest"), "CR 305.7: it is ONLY a Plains")
	assert_ok(g.tap_for_mana(0, forest))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 1, "a Plains taps for white")
	assert_true(theirs.has_subtype("forest"), "the opponent's lands are untouched")


func test_celestial_dawn_paints_your_permanents_and_your_cards_everywhere_white() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var their_bear := put_battlefield(1, "Grizzly Bears")
	var in_hand := give_hand(0, "Lightning Bolt")
	var their_hand := give_hand(1, "Lightning Bolt")
	var buried := bury(0, "Hill Giant")
	var dawn := cast("Celestial Dawn")
	assert_eq(bear.cur_colors, Mtg.ManaColor.W, "a nonland permanent you control")
	assert_eq(their_bear.cur_colors, Mtg.ManaColor.G, "not the opponent's")
	assert_eq(in_hand.cur_colors, Mtg.ManaColor.W, "a card you own in your hand")
	assert_eq(buried.cur_colors, Mtg.ManaColor.W, "a card you own in your graveyard")
	assert_eq(their_hand.cur_colors, Mtg.ManaColor.R, "not the opponent's hand")
	g.destroy(dawn)
	assert_eq(bear.cur_colors, Mtg.ManaColor.G, "the printed colours come back")
	assert_eq(in_hand.cur_colors, Mtg.ManaColor.R)


func test_celestial_dawn_white_pays_any_pip_and_other_mana_only_generic() -> void:
	cast("Celestial Dawn")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	g.players[0].mana_pool.clear()
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()
	assert_eq(g.players[1].life, 17, "white paid the {R}")
	assert_eq(bolt.cur_colors, Mtg.ManaColor.W, "a white Bolt in the graveyard")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bear, []))
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bear, []))
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "W for the {G}, other mana for the {1}")


## (The Bolt is in hand BEFORE the Dawn resolves: a card a test drops into
## a hand without any recalculation keeps its stale colours until the next
## one — a drawn card is repainted with the library on the way, see the
## B7 report's probe.)
func test_celestial_dawn_spell_on_the_stack_is_white() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	cast("Celestial Dawn")
	add_mana(0, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(bolt.zone, Mtg.Zone.STACK)
	assert_eq(bolt.cur_colors, Mtg.ManaColor.W, "a spell you control")
	resolve_stack()


# ------------------------------------------------------------ Null Chamber --

func _chamber_decks() -> void:
	g.players[0].deck_names.assign(["Grizzly Bears", "Grizzly Bears", "Giant Growth", "Forest", "Forest"])
	g.players[1].deck_names.assign(["Lightning Bolt", "Lightning Bolt", "Hill Giant", "Mishra's Factory", "Mountain"])


func test_null_chamber_each_player_names_from_the_other_deck_and_the_names_are_banned() -> void:
	_chamber_decks()
	var p0 := seat(0)
	var p1 := seat(1)
	p0.options = ["Lightning Bolt"]
	p1.options = ["Grizzly Bears"]
	var chamber := cast("Null Chamber")
	assert_eq(chamber.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(p0.offered.size(), 1)
	assert_false(p0.offered[0].contains("Mountain"), "no basic land name: %s" % p0.offered[0])
	assert_true(p0.offered[0].contains("Hill Giant"), "the opponent's decklist: %s" % p0.offered[0])
	assert_false(p1.offered[0].contains("Forest"), p1.offered[0])
	assert_true(p1.offered[0].contains("Giant Growth"), "the controller's decklist: %s" % p1.offered[0])
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_refused(g.cast_spell(0, bolt, [TargetRef.player(1)]), "Null Chamber")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G)
	add_mana(0, Mtg.ManaColor.C)
	assert_refused(g.cast_spell(0, bear, []), "Null Chamber")
	var growth := give_hand(0, "Giant Growth")
	var mine := put_battlefield(0, "Hill Giant")
	assert_ok(g.cast_spell(0, growth, [TargetRef.card(mine)]))
	resolve_stack()
	g.destroy(chamber)
	g.players[0].mana_pool.clear()
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	resolve_stack()


func test_null_chamber_bans_playing_a_named_land() -> void:
	_chamber_decks()
	var p0 := seat(0)
	p0.options = ["Mishra's Factory"]
	cast("Null Chamber")
	advance_to_next_turn()
	var factory := give_hand(1, "Mishra's Factory")
	assert_refused(g.play_land(1, factory), "Null Chamber")
	var mountain := give_hand(1, "Mountain")
	assert_ok(g.play_land(1, mountain))


# ------------------------------------------------------- Bazaar of Wonders --

func test_bazaar_of_wonders_exiles_all_graveyards_as_it_enters() -> void:
	var mine := bury(0, "Grizzly Bears")
	var theirs := bury(1, "Hill Giant")
	cast("Bazaar of Wonders")
	assert_eq(mine.zone, Mtg.Zone.EXILE)
	assert_eq(theirs.zone, Mtg.Zone.EXILE)


func test_bazaar_of_wonders_counters_a_spell_named_in_a_graveyard() -> void:
	cast("Bazaar of Wonders")
	cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17, "the first Bolt: no Bolt anywhere yet")
	var second := cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 17, "a Bolt is in a graveyard: countered")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


func test_bazaar_of_wonders_counters_a_spell_named_on_the_battlefield_but_not_for_a_token() -> void:
	cast("Bazaar of Wonders")
	put_battlefield(1, "Grizzly Bears")
	var bear := cast("Grizzly Bears")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "a nontoken Grizzly Bears is on the battlefield")
	g.destroy(g.players[1].battlefield.filter(func(i: CardInstance) -> bool: return i.data.card_name == "Grizzly Bears")[0])
	for c in g.players[1].graveyard.duplicate():
		g.exile_from_graveyard(c)
	for c in g.players[0].graveyard.duplicate():
		g.exile_from_graveyard(c)
	g.create_token(1, CardRegistry.get_card("Hill Giant"))
	var giant := cast("Hill Giant")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "a TOKEN of that name does not count")


func test_a_second_bazaar_is_countered_by_the_first() -> void:
	cast("Bazaar of Wonders")
	var second := cast("Bazaar of Wonders")
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- Forbidden Crypt --

func test_forbidden_crypt_replaces_a_draw_with_a_graveyard_card() -> void:
	var p0 := seat(0)
	var bear := bury(0, "Grizzly Bears")
	var giant := bury(0, "Hill Giant")
	cast("Forbidden Crypt")
	var library := g.players[0].library.size()
	p0.picks = [bear]
	g.draw_cards(0, 1)
	assert_eq(g.players[0].library.size(), library, "nothing drawn")
	assert_eq(bear.zone, Mtg.Zone.HAND, "the chosen graveyard card came back instead")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)


func test_forbidden_crypt_with_an_empty_graveyard_loses_the_game() -> void:
	cast("Forbidden Crypt")
	assert_true(g.players[0].graveyard.is_empty())
	g.draw_cards(0, 1)
	assert_true(g.players[0].has_lost, "If you can't, you lose the game.")


func test_forbidden_crypt_exiles_whatever_would_reach_your_graveyard() -> void:
	cast("Forbidden Crypt")
	var bolt := cast("Lightning Bolt", [TargetRef.player(1)])
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "a resolved spell")
	var bear := put_battlefield(0, "Grizzly Bears")
	g.destroy(bear)
	assert_eq(bear.zone, Mtg.Zone.EXILE, "a destroyed creature")
	var theirs := put_battlefield(1, "Grizzly Bears")
	g.destroy(theirs)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")
	assert_true(g.players[0].graveyard.is_empty())


func test_forbidden_crypt_does_not_touch_the_opponents_draws() -> void:
	cast("Forbidden Crypt")
	var hand := g.players[1].hand.size()
	g.draw_cards(1, 1)
	assert_eq(g.players[1].hand.size(), hand + 1)
	assert_false(g.players[1].has_lost)


# --------------------------------------------------------- Forsaken Wastes --

func test_forsaken_wastes_no_one_gains_life() -> void:
	put_battlefield(0, "Forsaken Wastes")
	g.adjust_life(0, 3)
	g.adjust_life(1, 3)
	assert_eq(g.players[0].life, 20)
	assert_eq(g.players[1].life, 20)
	cast("Healing Salve", [TargetRef.player(0)], 0, 0)
	assert_eq(g.players[0].life, 20)


func test_forsaken_wastes_each_upkeep_that_player_loses_one() -> void:
	put_battlefield(0, "Forsaken Wastes")
	advance_to_next_turn()
	assert_eq(g.players[1].life, 19, "the opponent's upkeep")
	assert_eq(g.players[0].life, 20)
	advance_to_next_turn()
	assert_eq(g.players[0].life, 19, "the controller's own upkeep too")
	assert_eq(g.players[1].life, 19)


func test_forsaken_wastes_targeted_by_a_spell_costs_its_controller_five() -> void:
	var wastes := put_battlefield(0, "Forsaken Wastes")
	cast("Disenchant", [TargetRef.card(wastes)], 0, 0)
	assert_eq(wastes.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].life, 15, "the Disenchant's controller (here its own controller) loses 5")


func test_forsaken_wastes_targeted_by_the_opponent() -> void:
	var wastes := put_battlefield(0, "Forsaken Wastes")
	assert_ok(g.pass_priority(0))
	var dis := give_hand(1, "Disenchant")
	fund(1, dis)
	assert_ok(g.cast_spell(1, dis, [TargetRef.card(wastes)]))
	resolve_stack()
	assert_eq(g.players[1].life, 15)
	assert_eq(g.players[0].life, 20)


## "the target of a SPELL": an activated ability aiming at it costs nothing.
func test_forsaken_wastes_targeted_by_an_ability_costs_nothing() -> void:
	var wastes := put_battlefield(0, "Forsaken Wastes")
	var rod := put_synthetic(0, CardData.new("Test Tapper", "{0}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("", false, [TapEffect.new()], "{0}: Tap target permanent.")))
	assert_ok(g.activate_ability(0, rod, 0, [TargetRef.card(wastes)]))
	resolve_stack()
	assert_true(wastes.tapped)
	assert_eq(g.players[0].life, 20)


# ----------------------------------------------------- Tombstone Stairwell --

func test_tombstone_stairwell_raises_hasty_tombspawn_each_upkeep_and_buries_them_each_end_step() -> void:
	put_battlefield(0, "Tombstone Stairwell")
	bury(0, "Grizzly Bears")
	bury(0, "Hill Giant")
	bury(1, "Grizzly Bears")
	bury(1, "Forest")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	var mine := tokens_of(0, "Tombspawn")
	var theirs := tokens_of(1, "Tombspawn")
	assert_eq(mine.size(), 2, "two creature cards in your graveyard")
	assert_eq(theirs.size(), 1, "each player — one creature card (a land does not count)")
	assert_true(theirs[0].has_keyword(Mtg.Keyword.HASTE))
	assert_eq([theirs[0].cur_power, theirs[0].cur_toughness], [2, 2])
	assert_eq(theirs[0].cur_colors, Mtg.ManaColor.B)
	theirs[0].regeneration_shields = 1
	to_step_of(1, Mtg.Step.END)
	resolve_stack()
	assert_true(tokens_of(0, "Tombspawn").is_empty(), "destroyed at the end step")
	assert_true(tokens_of(1, "Tombspawn").is_empty(), "and they can't be regenerated")


func test_tombstone_stairwell_leaving_destroys_its_tokens_only() -> void:
	var stairwell := put_battlefield(0, "Tombstone Stairwell")
	bury(0, "Grizzly Bears")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(tokens_of(0, "Tombspawn").size(), 1)
	var other := g.create_token(0, CardRegistry.get_card("Grizzly Bears"))[0]
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(1))
	var dis := give_hand(0, "Disenchant")
	fund(0, dis)
	assert_ok(g.cast_spell(0, dis, [TargetRef.card(stairwell)]))
	resolve_stack()
	assert_eq(stairwell.zone, Mtg.Zone.GRAVEYARD)
	assert_true(tokens_of(0, "Tombspawn").is_empty(), "its leave trigger destroyed them")
	assert_eq(other.zone, Mtg.Zone.BATTLEFIELD, "a token it did not create stays")


func test_tombstone_stairwell_has_cumulative_upkeep_one_black() -> void:
	var c := CardRegistry.get_card("Tombstone Stairwell")
	var found := false
	for t in c.triggered_abilities:
		if t.text.begins_with("Cumulative upkeep {1}{B}"):
			found = true
	assert_true(found)
	assert_true((c.supertypes & Mtg.Supertype.WORLD) != 0, "a world enchantment")


func test_tombstone_stairwell_unpaid_upkeep_means_no_tokens() -> void:
	var p0 := seat(0)
	var stairwell := put_battlefield(0, "Tombstone Stairwell")
	bury(0, "Grizzly Bears")
	p0.answers = [false, false, false]
	to_step_of(0, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(stairwell.zone, Mtg.Zone.GRAVEYARD, "cumulative upkeep declined")
	assert_true(tokens_of(0, "Tombspawn").is_empty(), "the intervening if: not on the battlefield, no tokens")


# --------------------------------------------------------------- Chaosphere --

func test_chaosphere_gives_reach_to_creatures_without_flying() -> void:
	put_battlefield(0, "Chaosphere")
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(0, "Serra Angel")
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	assert_false(angel.has_keyword(Mtg.Keyword.REACH))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: angel.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "the bear blocked the flyer")


func test_chaosphere_flyers_can_block_only_flyers() -> void:
	put_battlefield(1, "Chaosphere")
	var bear := put_battlefield(0, "Grizzly Bears")
	var hawk := put_battlefield(0, "Serra Angel")
	var angel := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id, hawk.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {angel.id: bear.id}))
	assert_ok(g.declare_blockers(1, {angel.id: hawk.id}))


func test_without_chaosphere_a_bear_cannot_block_a_flyer() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var angel := put_battlefield(0, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [angel.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: angel.id}))


# --------------------------------------------------------- Hall of Gemstone --

func test_hall_of_gemstone_recolours_every_land_for_the_turn() -> void:
	var p1 := seat(1)
	put_battlefield(0, "Hall of Gemstone")
	var mine := put_battlefield(0, "Forest")
	var theirs := put_battlefield(1, "Island")
	var factory := put_battlefield(1, "Mishra's Factory")
	p1.colors = [Mtg.ManaColor.R]
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(1, theirs))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.R), 1, "the chooser's Island makes red")
	assert_ok(g.tap_for_mana(1, factory))
	assert_eq(g.players[1].mana_pool.amount_of(Mtg.ManaColor.C), 1, "colorless is not a color: untouched")
	g.players[1].mana_pool.clear()
	to_step_of(0, Mtg.Step.UPKEEP)
	var p0 := seat(0)
	p0.colors = [Mtg.ManaColor.U]
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1, "a new turn, a new colour")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 0, "last turn's red ended")


func test_hall_of_gemstone_affects_both_players_lands() -> void:
	var p1 := seat(1)
	put_battlefield(1, "Hall of Gemstone")
	var mine := put_battlefield(0, "Forest")
	p1.colors = [Mtg.ManaColor.B]
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(1))
	assert_ok(g.tap_for_mana(0, mine))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.B), 1, "the other player's land too")


func test_hall_of_gemstone_hint_reads_the_choosers_own_hand() -> void:
	var p1 := seat(1)
	put_battlefield(0, "Hall of Gemstone")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Hill Giant")
	to_step_of(1, Mtg.Step.UPKEEP)
	resolve_stack()
	assert_eq(p1.color_hints, [Mtg.ManaColor.R] as Array[int])


# ------------------------------------------------------- Unfulfilled Desires --

func test_unfulfilled_desires_pays_a_life_to_loot() -> void:
	var desires := put_battlefield(0, "Unfulfilled Desires")
	give_hand(0, "Craw Wurm")
	var hand := g.players[0].hand.size()
	var library := g.players[0].library.size()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, desires, 0))
	assert_eq(g.players[0].life, 19, "1 life paid as the cost")
	resolve_stack()
	assert_eq(g.players[0].library.size(), library - 1, "drew a card")
	assert_eq(g.players[0].hand.size(), hand, "and discarded one")
	assert_eq(g.players[0].graveyard.size(), 1)
	assert_eq(g.players[0].graveyard[0].data.card_name, "Craw Wurm", "the costly one goes by default")
