extends GameTest
## Pack 10 (the Urza block), batch B1: the white and blue instants and
## sorceries of cards/sets/usg/_spells.gd and cards/sets/ulg/_spells.gd —
## every card claimed, its main effect, a refused or illegal case, and the
## interactions its text implies (Humble's floating silencer at its
## timestamp, Redeem in the 1997 damage window, Waylay's cleanup exile,
## Curfew's untargeted choices, Tolarian Winds under Library of Leng).

const CLAIMED := ["Congregate", "Humble", "Planar Birth", "Redeem", "Waylay", "Annul", "Catalog",
	"Curfew", "Hibernation", "Stroke of Genius", "Sunder", "Tolarian Winds", "Windfall",
	"Erase", "Peace and Quiet", "Purify", "Intervene", "Opportunity", "Tinker"]


## Scripted answers: yes/no from [member says], a card by name from
## [member picks] (else the first candidate), an option by label from
## [member labels] (else the hint), discards by name from [member drops].
## Remembers every prompt.
class Seat extends DecisionAgent:
	var says := true
	var picks: Array[String] = []
	var labels: Array[String] = []
	var drops: Array[String] = []
	var asked: Array[String] = []
	func answer_yes_no(_g: MtgGame, _pid: int, prompt: String, _hint: bool) -> bool:
		asked.append(prompt)
		return says
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], prompt: String) -> CardInstance:
		asked.append(prompt)
		for n in picks.size():
			for c in candidates:
				if c.data.card_name == picks[n]:
					picks.remove_at(n)
					return c
		return null if candidates.is_empty() else candidates[0]
	func answer_option(_g: MtgGame, _pid: int, prompt: String, options: Array[String], hint: int) -> int:
		asked.append(prompt)
		for n in labels.size():
			var at := options.find(labels[n])
			if at >= 0:
				labels.remove_at(n)
				return at
		return hint
	func answer_discard(g: MtgGame, pid: int, count: int) -> Array[CardInstance]:
		if drops.is_empty(): return super(g, pid, count)
		var out: Array[CardInstance] = []
		for want in drops:
			for c in g.players[pid].hand:
				if c.data.card_name == want and not out.has(c):
					out.append(c)
					break
		return out

## A seat that asks for the 1997 damage-prevention window.
class WindowSeat extends DecisionAgent:
	func wants_damage_prevention_window() -> bool:
		return true


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


func _seat(pid: int) -> Seat:
	var s := Seat.new()
	g.set_agent(pid, s)
	return s

## Exactly the mana [param card_name] costs (X extra generic), as colorless
## for the generic part — nothing is left over to burn.
func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

## Give [param pid] the spell, its mana and priority; return the cast's verdict.
func _try(pid: int, card_name: String, targets: Array = [], x := 0) -> String:
	var card := give_hand(pid, card_name)
	_pay(pid, card_name, x)
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	return g.cast_spell(pid, card, targets, x)

func _cast(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	assert_ok(_try(pid, card_name, targets, x))

func _cast_resolve(pid: int, card_name: String, targets: Array = [], x := 0) -> void:
	_cast(pid, card_name, targets, x)
	resolve_stack()

func _grave(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	g.put_into_graveyard(inst)
	return inst

func _library_top(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.put_from_hand_on_top_of_library(card)
	return card

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out

func _respond(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _close_window() -> void:
	var guard := 0
	while (g.awaiting_damage_prevention or g.awaiting_regeneration or not g.stack.is_empty()) \
			and guard < 20:
		if g.stack.is_empty():
			assert_ok(g.end_damage_prevention(g.priority_player))
		else:
			assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 20)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# --------------------------------------------------------------- Congregate --

func test_congregate_counts_every_creature_on_the_battlefield() -> void:
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Gray Ogre")
	put_battlefield(1, "Forest")
	_cast_resolve(0, "Congregate", [TargetRef.player(1)])
	assert_eq(g.players[1].life, 26, "2 life for each of the three creatures, both sides")
	assert_eq(g.players[0].life, 20)
	_cast_resolve(0, "Congregate", [TargetRef.player(0)])
	assert_eq(g.players[0].life, 26)

func test_congregate_counts_as_it_resolves() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Gray Ogre")
	_cast(0, "Congregate", [TargetRef.player(0)])
	g.destroy(bear)
	resolve_stack()
	assert_eq(g.players[0].life, 22, "the bear died before it resolved")


# ------------------------------------------------------------------- Humble --

func test_humble_makes_a_creature_a_vanilla_0_1_until_end_of_turn() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_cast_resolve(0, "Humble", [TargetRef.card(angel)])
	assert_eq([angel.cur_power, angel.cur_toughness], [0, 1])
	assert_false(angel.has_keyword(Mtg.Keyword.FLYING))
	assert_false(angel.has_keyword(Mtg.Keyword.VIGILANCE))
	advance_to_next_turn()
	assert_eq([angel.cur_power, angel.cur_toughness], [4, 4], "it ends at cleanup")
	assert_true(angel.has_keyword(Mtg.Keyword.FLYING))

func test_humble_removes_activated_abilities() -> void:
	var sorcerer := put_battlefield(1, "Prodigal Sorcerer")
	_cast_resolve(0, "Humble", [TargetRef.card(sorcerer)])
	assert_true(sorcerer.cur_activated_abilities.is_empty())
	assert_ok(g.pass_priority(0))
	assert_refused(g.activate_ability(1, sorcerer, 0, [TargetRef.player(0)]))
	assert_eq(g.players[0].life, 20)

func test_a_grant_older_than_humble_is_stripped_and_a_newer_one_survives() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_cast_resolve(0, "Flight", [TargetRef.card(bear)])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING))
	_cast_resolve(0, "Humble", [TargetRef.card(bear)])
	assert_false(bear.has_keyword(Mtg.Keyword.FLYING), "the Flight Aura came first (CR 613.7)")
	_cast_resolve(0, "Jump", [TargetRef.card(bear)])
	assert_true(bear.has_keyword(Mtg.Keyword.FLYING), "a Jump cast after Humble survives")
	_cast_resolve(0, "Giant Growth", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 4], "the pump applies over the base 0/1")

func test_humble_keeps_an_auras_bonus_and_forgets_a_creature_that_left() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var aura := give_hand(0, "Holy Strength")
	_pay(0, "Holy Strength")
	assert_ok(g.cast_spell(0, aura, [TargetRef.card(bear)]))
	resolve_stack()
	_cast_resolve(0, "Humble", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [1, 3], "base 0/1, the Aura's +1/+2 still applies")
	g.return_to_hand(bear)
	_pay(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, bear))
	resolve_stack()
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2], "a new object (CR 400.7)")


# ------------------------------------------------------------- Planar Birth --

func test_planar_birth_returns_every_basic_land_card_tapped_to_its_owner() -> void:
	var mine := _grave(0, "Plains")
	var theirs := _grave(1, "Swamp")
	var nonbasic := _grave(1, "Mishra's Factory")
	var bear := _grave(0, "Grizzly Bears")
	_cast_resolve(0, "Planar Birth")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(theirs.controller_id, 1, "under its owner's control")
	assert_true(mine.tapped)
	assert_true(theirs.tapped)
	assert_eq(nonbasic.zone, Mtg.Zone.GRAVEYARD, "basic lands only")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)

func test_planar_birth_lands_enter_for_ankh_of_mishra() -> void:
	put_battlefield(0, "Ankh of Mishra")
	_grave(0, "Plains")
	_grave(1, "Swamp")
	_cast_resolve(0, "Planar Birth")
	assert_eq(g.players[0].life, 18)
	assert_eq(g.players[1].life, 18)


# ------------------------------------------------------------------- Redeem --

func test_redeem_prevents_all_damage_to_two_creatures_this_turn() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Grizzly Bears")
	_cast_resolve(0, "Redeem", [TargetRef.card(a), TargetRef.card(b)])
	for victim in [a, b, c]:
		_cast_resolve(0, "Lightning Bolt", [TargetRef.card(victim)])
	assert_eq(a.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(b.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(a.damage, 0)
	assert_eq(c.zone, Mtg.Zone.GRAVEYARD, "not one of its targets")
	advance_to_next_turn()
	_cast_resolve(0, "Lightning Bolt", [TargetRef.card(a)])
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD, "this turn only")

func test_redeem_takes_up_to_two_targets() -> void:
	put_battlefield(0, "Grizzly Bears")
	assert_ok(_try(0, "Redeem", []))
	resolve_stack()
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Redeem", [TargetRef.card(a), TargetRef.card(b), TargetRef.card(c)]))

func test_redeem_is_a_prevention_spell_for_the_1997_window() -> void:
	for e in CardRegistry.get_card("Redeem").spell_effects:
		assert_true(e.is_damage_prevention)
	g.rules.damage_prevention_window = true
	g.set_agent(1, WindowSeat.new())
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	var redeem := give_hand(1, "Redeem")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {ogre.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_DAMAGE)
	assert_true(g.awaiting_damage_prevention)
	_respond(1)
	_pay(1, "Redeem")
	assert_ok(g.cast_spell(1, redeem, [TargetRef.card(ogre)]))
	_close_window()
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD, "the waiting 3 is prevented")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "the ogre's 2 does not kill the giant")


# ------------------------------------------------------------------- Waylay --

func test_waylay_makes_three_knights_that_are_exiled_at_cleanup() -> void:
	_cast_resolve(1, "Waylay")
	var knights := _named(1, "Knight")
	assert_eq(knights.size(), 3)
	for k in knights:
		assert_true(k.is_token)
		assert_eq([k.cur_power, k.cur_toughness], [2, 2])
		assert_eq(k.cur_colors, Mtg.ManaColor.W)
		assert_true(k.has_subtype("knight"))
	advance_to_step(Mtg.Step.END)
	assert_eq(_named(1, "Knight").size(), 3, "still there in the end step")
	advance_to_next_turn()
	assert_eq(_named(1, "Knight").size(), 0, "exiled at the beginning of the next cleanup step")

func test_waylays_knights_block_in_the_opponents_combat() -> void:
	var giant := put_battlefield(0, "Hill Giant")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	_cast_resolve(1, "Waylay")
	var knights := _named(1, "Knight")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {knights[0].id: giant.id, knights[1].id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].life, 20)


# -------------------------------------------------------------------- Annul --

func test_annul_counters_an_artifact_or_enchantment_spell() -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1)
	var ring := give_hand(1, "Sol Ring")
	_pay(1, "Sol Ring")
	assert_ok(g.cast_spell(1, ring))
	_cast(0, "Annul", [TargetRef.card(ring)])
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	var pest := give_hand(1, "Pestilence")
	_pay(1, "Pestilence")
	assert_ok(g.cast_spell(1, pest))
	_cast(0, "Annul", [TargetRef.card(pest)])
	resolve_stack()
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD)

func test_annul_refuses_a_creature_spell_but_takes_an_artifact_creature() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	_pay(0, "Grizzly Bears")
	assert_ok(g.cast_spell(0, bear))
	assert_refused(_try(0, "Annul", [TargetRef.card(bear)]))
	resolve_stack()
	var thopter := give_hand(0, "Ornithopter")
	assert_ok(g.cast_spell(0, thopter))
	_cast(0, "Annul", [TargetRef.card(thopter)])
	resolve_stack()
	assert_eq(thopter.zone, Mtg.Zone.GRAVEYARD, "an artifact creature spell is an artifact spell")


# ------------------------------------------------------------------ Catalog --

func test_catalog_draws_two_then_discards_one_of_your_choice() -> void:
	var seat := _seat(0)
	var bolt := give_hand(0, "Lightning Bolt")
	seat.drops = ["Lightning Bolt"]
	_cast_resolve(0, "Catalog")
	assert_eq(g.players[0].hand.size(), 2, "one card, two drawn, one discarded")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "its controller chose the Bolt")


# ------------------------------------------------------------------- Curfew --

func test_curfew_each_player_returns_a_creature_of_their_choice() -> void:
	var mine := _seat(0)
	var theirs := _seat(1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	var wall := put_battlefield(1, "Wall of Stone")
	mine.picks = ["Hill Giant"]
	theirs.picks = ["Wall of Stone"]
	_cast_resolve(0, "Curfew")
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wall.zone, Mtg.Zone.HAND)
	assert_eq(ogre.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.players[1].hand.has(wall))

func test_curfew_is_untargeted_and_a_borrowed_creature_goes_home() -> void:
	var guma := put_battlefield(1, "Guma")   # protection from blue
	var bear := put_battlefield(1, "Grizzly Bears")
	g.change_control(bear, 0)
	_cast_resolve(0, "Curfew")
	assert_eq(guma.zone, Mtg.Zone.HAND, "protection from blue does not stop an untargeted spell")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_true(g.players[1].hand.has(bear), "to its OWNER's hand")

func test_curfew_with_no_creatures_on_one_side() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Curfew")
	assert_eq(bear.zone, Mtg.Zone.HAND)

func test_curfew_holds_a_human_seat_open_on_its_choice() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Gray Ogre")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	_cast(0, "Curfew")
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_has(g.awaiting_choice.candidates, giant)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "nothing moves while the question is open")
	assert_ok(g.answer_choice(giant.id))
	assert_null(g.awaiting_choice)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# -------------------------------------------------------------- Hibernation --

func test_hibernation_returns_every_green_permanent() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	var forest := put_battlefield(1, "Forest")
	var growth := give_hand(1, "Wild Growth")
	g.attach_aura_from_anywhere(growth, forest, 1)
	assert_eq(growth.zone, Mtg.Zone.BATTLEFIELD)
	var giant := put_battlefield(1, "Hill Giant")
	_cast_resolve(0, "Hibernation")
	assert_eq(bear.zone, Mtg.Zone.HAND)
	assert_eq(elves.zone, Mtg.Zone.HAND)
	assert_eq(growth.zone, Mtg.Zone.HAND, "a green enchantment too")
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "a land is colorless")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Stroke of Genius --

func test_stroke_of_genius_target_player_draws_x() -> void:
	var before := g.players[1].hand.size()
	_cast_resolve(0, "Stroke of Genius", [TargetRef.player(1)], 3)
	assert_eq(g.players[1].hand.size(), before + 3)
	var mine := g.players[0].hand.size()
	_cast_resolve(0, "Stroke of Genius", [TargetRef.player(0)], 0)
	assert_eq(g.players[0].hand.size(), mine)


# ------------------------------------------------------------------- Sunder --

func test_sunder_returns_every_land_to_its_owners_hand() -> void:
	var a := put_battlefield(0, "Island")
	var b := put_battlefield(1, "Mountain")
	var c := put_battlefield(1, "Mishra's Factory")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Sunder")
	for land in [a, b, c]:
		assert_eq(land.zone, Mtg.Zone.HAND, land.data.card_name)
	assert_true(g.players[1].hand.has(b))
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ----------------------------------------------------------- Tolarian Winds --

func test_tolarian_winds_discards_the_hand_and_draws_that_many() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	var growth := give_hand(0, "Giant Growth")
	var bear := give_hand(0, "Grizzly Bears")
	_cast_resolve(0, "Tolarian Winds")
	for c in [bolt, growth, bear]:
		assert_eq(c.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 3)

func test_tolarian_winds_with_an_empty_hand_draws_nothing() -> void:
	_cast_resolve(0, "Tolarian Winds")
	assert_eq(g.players[0].hand.size(), 0)

func test_tolarian_winds_counts_cards_library_of_leng_put_on_top() -> void:
	put_battlefield(0, "Library of Leng")
	var bolt := give_hand(0, "Lightning Bolt")
	var growth := give_hand(0, "Giant Growth")
	_cast_resolve(0, "Tolarian Winds")
	assert_eq(g.players[0].hand.size(), 2, "both were discarded, to the top of the library")
	assert_true(g.players[0].hand.has(bolt))
	assert_true(g.players[0].hand.has(growth))


# ----------------------------------------------------------------- Windfall --

func test_windfall_each_player_draws_the_greatest_number_discarded() -> void:
	var mine := give_hand(0, "Lightning Bolt")
	for _i in 5:
		give_hand(1, "Grizzly Bears")
	_cast_resolve(0, "Windfall")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].graveyard.size(), 5)
	assert_eq(g.players[0].hand.size(), 5)
	assert_eq(g.players[1].hand.size(), 5)

func test_windfall_with_empty_hands_draws_nothing() -> void:
	_cast_resolve(0, "Windfall")
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(g.players[1].hand.size(), 0)


# -------------------------------------------------------------------- Erase --

func test_erase_exiles_target_enchantment_only() -> void:
	var pest := put_battlefield(1, "Pestilence")
	_cast_resolve(0, "Erase", [TargetRef.card(pest)])
	assert_eq(pest.zone, Mtg.Zone.EXILE)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Erase", [TargetRef.card(bear)]))


# ---------------------------------------------------------- Peace and Quiet --

func test_peace_and_quiet_destroys_two_target_enchantments() -> void:
	var pest := put_battlefield(1, "Pestilence")
	var crusade := put_battlefield(1, "Crusade")
	assert_refused(_try(0, "Peace and Quiet", [TargetRef.card(pest)]), "")
	_cast_resolve(0, "Peace and Quiet", [TargetRef.card(pest), TargetRef.card(crusade)])
	assert_eq(pest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)


# ------------------------------------------------------------------- Purify --

func test_purify_destroys_all_artifacts_and_enchantments() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var thopter := put_battlefield(1, "Ornithopter")
	var pest := put_battlefield(1, "Pestilence")
	var bear := put_battlefield(1, "Grizzly Bears")
	var land := put_battlefield(1, "Forest")
	_cast_resolve(0, "Purify")
	for i in [ring, thopter, pest]:
		assert_eq(i.zone, Mtg.Zone.GRAVEYARD, i.data.card_name)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(land.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Intervene --

func test_intervene_counters_a_spell_that_targets_a_creature() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	_pay(1, "Lightning Bolt")
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	_cast(0, "Intervene", [TargetRef.card(bolt)])
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)

func test_intervene_refuses_a_spell_aimed_at_a_player() -> void:
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	_pay(1, "Lightning Bolt")
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_refused(_try(0, "Intervene", [TargetRef.card(bolt)]))


# -------------------------------------------------------------- Opportunity --

func test_opportunity_target_player_draws_four() -> void:
	var before := g.players[0].hand.size()
	_cast_resolve(0, "Opportunity", [TargetRef.player(0)])
	assert_eq(g.players[0].hand.size(), before + 4)


# ------------------------------------------------------------------- Tinker --

func test_tinker_trades_an_artifact_for_one_from_the_library() -> void:
	var seat := _seat(0)
	var ring := put_battlefield(0, "Sol Ring")
	var icy := _library_top(0, "Icy Manipulator")
	_library_top(0, "Clockwork Beast")
	seat.picks = ["Icy Manipulator"]
	_cast_resolve(0, "Tinker")
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD, "sacrificed as the additional cost")
	assert_eq(icy.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(icy.controller_id, 0)

func test_tinker_needs_an_artifact_to_sacrifice() -> void:
	_library_top(0, "Icy Manipulator")
	assert_refused(_try(0, "Tinker"), "artifact")

func test_tinker_may_fail_to_find() -> void:
	var ring := put_battlefield(0, "Sol Ring")
	var library := g.players[0].library.size()
	_cast_resolve(0, "Tinker")
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].library.size(), library, "no artifact card: nothing found")
