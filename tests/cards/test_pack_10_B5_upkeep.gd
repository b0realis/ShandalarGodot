extends GameTest
## Pack 10 (the Urza block), batch B5: the upkeep triggers of
## cards/sets/usg/_triggers.gd and cards/sets/uds/_triggers.gd — intervening
## "if"s checked twice (CR 603.4), "sacrifice unless" payments on
## resolution (mana, a permanent, a discard — CR 118.12), a seeded coin —
## and the three "when you control no …, sacrifice" clauses
## (CardData.sacrifices_when) in both rules forks.

class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []

	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]


var me: Seat
var foe: Seat


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	CardRegistry.ensure_loaded()
	super()
	me = Seat.new()
	foe = Seat.new()
	g.set_agent(0, me)
	g.set_agent(1, foe)
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)
	CardPacks.set_enabled("pack-9", false)   # the Megrim test


## Pass until [param pid]'s upkeep of a LATER turn, its triggers waiting.
func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

## Seed the game RNG so the NEXT coin flip is won (or lost): MtgGame.flip_coin
## wins on an even randi().
func _seed_flip(win: bool) -> void:
	for n in range(1, 500):
		var probe := RandomNumberGenerator.new()
		probe.seed = n
		if ((probe.randi() % 2) == 0) == win:
			g.rng.seed = n
			return
	fail_test("no seed found")


# ------------------------------------------------------------------ Imaginary Pet --

func test_imaginary_pet_goes_home_while_you_hold_a_card() -> void:
	var pet := put_battlefield(0, "Imaginary Pet")
	give_hand(0, "Island")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(pet.zone, Mtg.Zone.HAND)

func test_imaginary_pet_stays_with_an_empty_hand_and_ignores_other_upkeeps() -> void:
	var pet := put_battlefield(0, "Imaginary Pet")
	var card := give_hand(0, "Island")
	_to_upkeep(1)
	assert_true(g.stack.is_empty(), "not the opponent's upkeep")
	assert_eq(pet.zone, Mtg.Zone.BATTLEFIELD)
	g.discard_cards(0, [card])   # setup: P0 holds nothing at its next upkeep
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "the intervening if: no trigger")
	assert_eq(pet.zone, Mtg.Zone.BATTLEFIELD)

func test_imaginary_pet_rechecks_the_hand_on_resolution() -> void:
	var pet := put_battlefield(0, "Imaginary Pet")
	var card := give_hand(0, "Island")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	g.discard_cards(0, g.players[0].hand.duplicate())
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD)
	resolve_stack()
	assert_eq(pet.zone, Mtg.Zone.BATTLEFIELD, "CR 603.4")


# ----------------------------------------------------------------- Reclusive Wight --

func test_reclusive_wight_is_sacrificed_beside_another_nonland_permanent() -> void:
	var wight := put_battlefield(0, "Reclusive Wight")
	put_battlefield(0, "Sol Ring")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(wight.zone, Mtg.Zone.GRAVEYARD)

func test_reclusive_wight_stays_among_lands() -> void:
	var wight := put_battlefield(0, "Reclusive Wight")
	put_battlefield(0, "Swamp")
	put_battlefield(1, "Sol Ring")
	_to_upkeep(0)
	assert_true(g.stack.is_empty())
	assert_eq(wight.zone, Mtg.Zone.BATTLEFIELD, "lands and the opponent's permanents do not count")


# ------------------------------------------------------------------ Sleeper Agent --

func test_sleeper_agent_damages_its_current_controller_each_upkeep() -> void:
	var agent := give_hand(0, "Sleeper Agent")
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, agent))
	resolve_stack()
	assert_eq(agent.controller_id, 1)
	_to_upkeep(0)
	assert_true(g.stack.is_empty(), "not its owner's upkeep")
	_to_upkeep(1)
	var life := g.players[1].life
	resolve_stack()
	assert_eq(g.players[1].life, life - 2)


# ------------------------------------------------------------------------ Vebulid --

func test_vebulid_enters_with_a_counter_and_may_grow_each_upkeep() -> void:
	var vebulid := give_hand(0, "Vebulid")
	add_mana(0, Mtg.ManaColor.B, 1)
	assert_ok(g.cast_spell(0, vebulid))
	resolve_stack()
	assert_eq(int(vebulid.counters.get("+1/+1", 0)), 1)
	assert_eq(vebulid.cur_power, 1)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(vebulid.cur_power, 2)
	_to_upkeep(0)
	me.yes = 0
	resolve_stack()
	assert_eq(vebulid.cur_power, 2, "declined")


# ------------------------------------------------------------------- Scoria Wurm --

func test_scoria_wurm_stays_on_a_won_flip_and_goes_home_on_a_lost_one() -> void:
	var wurm := put_battlefield(0, "Scoria Wurm")
	_to_upkeep(0)
	_seed_flip(true)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep(0)
	_seed_flip(false)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.HAND)


# ------------------------------------------------------------------ Child of Gaea --

func test_child_of_gaea_is_kept_for_two_green_and_lost_without() -> void:
	var child := put_battlefield(0, "Child of Gaea")
	_to_upkeep(0)
	add_mana(0, Mtg.ManaColor.G, 2)
	resolve_stack()
	assert_eq(child.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 0, "paid")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(child.zone, Mtg.Zone.GRAVEYARD, "nothing to pay with")

func test_child_of_gaea_regenerates() -> void:
	var child := put_battlefield(0, "Child of Gaea")
	add_mana(0, Mtg.ManaColor.G, 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, child, 0))
	resolve_stack()
	g.destroy(child)
	assert_eq(child.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------------- Endless Wurm --

func test_endless_wurm_eats_an_enchantment_or_goes() -> void:
	var wurm := put_battlefield(0, "Endless Wurm")
	var crusade := put_battlefield(0, "Crusade")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	_to_upkeep(0)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD, "no enchantment left")

func test_endless_wurm_may_refuse_to_pay() -> void:
	var wurm := put_battlefield(0, "Endless Wurm")
	var crusade := put_battlefield(0, "Crusade")
	me.yes = 0
	_to_upkeep(0)
	resolve_stack()
	assert_eq(crusade.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)


# ---------------------------------------------------------------------- Masticore --

func test_masticore_discards_to_stay_and_the_discard_skips_library_of_leng() -> void:
	var masticore := put_battlefield(0, "Masticore")
	put_battlefield(0, "Library of Leng")
	var card := give_hand(0, "Lightning Bolt")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(masticore.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(card.zone, Mtg.Zone.GRAVEYARD, "an unless payment, not an effect's discard (CR 118.12)")

func test_masticore_is_sacrificed_with_an_empty_hand() -> void:
	var masticore := put_battlefield(0, "Masticore")
	_to_upkeep(0)
	g.players[0].hand.clear()   # setup: nothing to discard
	resolve_stack()
	assert_eq(masticore.zone, Mtg.Zone.GRAVEYARD)

func test_masticore_pings_and_regenerates() -> void:
	var masticore := put_battlefield(0, "Masticore")
	var elves := put_battlefield(1, "Llanowar Elves")
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, masticore, 0, [TargetRef.card(elves)]))
	resolve_stack()
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.activate_ability(0, masticore, 1))
	resolve_stack()
	g.destroy(masticore)
	assert_eq(masticore.zone, Mtg.Zone.BATTLEFIELD)

func test_masticore_holds_a_human_seat_on_the_discard() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var masticore := put_battlefield(0, "Masticore")
	give_hand(0, "Lightning Bolt")
	give_hand(0, "Island")
	_to_upkeep(0)
	var guard := 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_not_null(g.awaiting_choice, "the unless question is the player's")
	assert_eq(g.awaiting_choice.source, "Masticore")
	assert_ok(g.answer_choice(false))
	guard = 0
	while not g.stack.is_empty() and g.awaiting_choice == null and guard < 20:
		g.pass_priority(g.priority_player)
		guard += 1
	assert_eq(masticore.zone, Mtg.Zone.GRAVEYARD, "declined: sacrificed")


# ------------------------------------------ the "when you control no …" clauses --

func test_tethered_griffin_covetous_dragon_and_emperor_crocodile_need_company() -> void:
	for wait in [false, true]:
		before_each()
		g.rules.sacrifice_clauses_wait = wait
		var crusade := put_battlefield(0, "Crusade")
		var ring := put_battlefield(0, "Sol Ring")
		var griffin := put_battlefield(0, "Tethered Griffin")
		var dragon := put_battlefield(0, "Covetous Dragon")
		var croc := put_battlefield(0, "Emperor Crocodile")
		g.check_state_based_actions()
		resolve_stack()
		assert_eq(griffin.zone, Mtg.Zone.BATTLEFIELD, "wait=%s" % wait)
		assert_eq(dragon.zone, Mtg.Zone.BATTLEFIELD, "wait=%s" % wait)
		assert_eq(croc.zone, Mtg.Zone.BATTLEFIELD, "other creatures: the Griffin and the Dragon (wait=%s)" % wait)
		g.destroy(crusade)
		g.destroy(ring)
		g.check_state_based_actions()
		resolve_stack()
		assert_eq(griffin.zone, Mtg.Zone.GRAVEYARD, "no enchantments (wait=%s)" % wait)
		assert_eq(dragon.zone, Mtg.Zone.GRAVEYARD, "no artifacts (wait=%s)" % wait)
		g.check_state_based_actions()
		resolve_stack()
		assert_eq(croc.zone, Mtg.Zone.GRAVEYARD, "alone (wait=%s)" % wait)

func test_an_opponents_enchantment_does_not_keep_the_griffin() -> void:
	put_battlefield(1, "Crusade")
	var griffin := put_battlefield(0, "Tethered Griffin")
	g.check_state_based_actions()
	resolve_stack()
	assert_eq(griffin.zone, Mtg.Zone.GRAVEYARD)


func test_masticores_discard_is_still_a_discard_for_megrim() -> void:
	CardPacks.set_enabled("pack-9", true)
	before_each()
	put_battlefield(1, "Megrim")
	var masticore := put_battlefield(0, "Masticore")
	give_hand(0, "Lightning Bolt")
	_to_upkeep(0)
	resolve_stack()
	assert_eq(masticore.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 18, "Megrim: 2 damage for the discard")
