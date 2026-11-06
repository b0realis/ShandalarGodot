extends GameTest
## Pack 10 (the Urza block), batch B10: the echo creatures' OTHER clauses —
## the enters (and dies) triggers, firebreathing and regeneration of
## cards/sets/{usg,ulg,uds}/_echo.gd. Each card is cast through the public
## API; targets are chosen by the heuristic seat's order (the opponent's
## biggest for harm, our own for help) unless a test names one.


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-10", false)


## Exactly [param cost]'s mana in [param pid]'s pool.
func _mana_for(pid: int, cost: String) -> void:
	var parsed := ManaCost.parse(cost)
	for color in parsed.colored:
		add_mana(pid, int(color), int(parsed.colored[color]))
	if parsed.generic > 0:
		add_mana(pid, Mtg.ManaColor.C, parsed.generic)


## Cast [param card_name] for [param pid] with exactly its mana, and let
## the spell and its enters trigger resolve.
func _cast(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	_mana_for(pid, card.data.cost.text)
	assert_ok(g.cast_spell(pid, card))
	resolve_stack()
	return card


## Pass until turn [param turn]'s upkeep and resolve what triggered there.
func _upkeep_of(turn: int) -> void:
	var guard := 0
	while not (g.turn_number == turn and g.current_step() == Mtg.Step.UPKEEP) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	resolve_stack()


# --- Crater Hellion -----------------------------------------------------------

func test_crater_hellion_deals_4_to_each_other_creature() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	var mine := put_battlefield(0, "Craw Wurm")   # 6/4
	var giant := put_battlefield(1, "Hill Giant")
	var hellion := _cast(0, "Crater Hellion")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD, "its controller's creatures too")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(hellion.zone, Mtg.Zone.BATTLEFIELD, "not itself")
	assert_eq(hellion.damage, 0)


# --- Karmic Guide --------------------------------------------------------------

func test_karmic_guide_returns_a_creature_card_from_your_graveyard() -> void:
	var dead := give_hand(0, "Craw Wurm")
	g.discard_cards(0, [dead])
	var theirs := give_hand(1, "Shivan Dragon")
	g.discard_cards(1, [theirs])
	_cast(0, "Karmic Guide")
	assert_eq(dead.zone, Mtg.Zone.BATTLEFIELD, "back under its owner's control")
	assert_eq(dead.controller_id, 0)
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "only YOUR graveyard")


func test_karmic_guide_with_an_empty_graveyard_does_nothing() -> void:
	var guide := _cast(0, "Karmic Guide")
	assert_eq(guide.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.stack.is_empty(), "no target, so the trigger never went on the stack")


# --- Radiant's Dragoons, Multani's Acolyte ----------------------------------------

func test_radiants_dragoons_gains_5_life() -> void:
	_cast(0, "Radiant's Dragoons")
	assert_eq(g.players[0].life, 25)


func test_multanis_acolyte_draws_a_card() -> void:
	var before := g.players[0].hand.size()
	_cast(0, "Multani's Acolyte")
	assert_eq(g.players[0].hand.size(), before + 1)


# --- Raven Familiar ------------------------------------------------------------

func test_raven_familiar_keeps_one_of_three_and_bottoms_the_rest() -> void:
	var library := g.players[0].library
	var top3: Array[CardInstance] = [library[library.size() - 1], library[library.size() - 2],
		library[library.size() - 3]]
	var size_before := library.size()
	_cast(0, "Raven Familiar")
	assert_eq(library.size(), size_before - 1)
	var in_hand := 0
	for card in top3:
		if card.zone == Mtg.Zone.HAND: in_hand += 1
	assert_eq(in_hand, 1, "one of the three went to the hand")
	for card in top3:
		if card.zone == Mtg.Zone.LIBRARY:
			assert_true(library.find(card) < 2, "the others are at the bottom")


func test_raven_familiar_holds_a_human_seat_on_its_choice() -> void:
	var human := HumanAgent.new()
	g.agents[0] = human
	g.interactive_choices = true
	var library := g.players[0].library
	var top := library[library.size() - 1]
	var second := library[library.size() - 2]
	var raven := give_hand(0, "Raven Familiar")
	_mana_for(0, "{2}{U}")
	assert_ok(g.cast_spell(0, raven))
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_not_null(g.awaiting_choice, "held on which card to keep")
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.CARD)
	assert_eq(g.awaiting_choice.pid, 0)
	assert_eq(g.awaiting_choice.candidates.size(), 3)
	assert_ok(g.answer_choice(second.id))
	guard = 0
	while g.awaiting_choice != null and guard < 5:
		# The order of the other two on the bottom: the top card first.
		assert_ok(g.answer_choice(top.id))
		guard += 1
	resolve_stack()
	assert_eq(second.zone, Mtg.Zone.HAND, "the player's pick")
	assert_eq(top.zone, Mtg.Zone.LIBRARY)


# --- Bone Shredder -------------------------------------------------------------

func test_bone_shredder_destroys_a_nonartifact_nonblack_creature() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var golem := put_battlefield(1, "Obsianus Golem")   # artifact creature
	var giant := put_battlefield(1, "Hill Giant")
	_cast(0, "Bone Shredder")
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "the only legal target")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "black: not a legal target")
	assert_eq(golem.zone, Mtg.Zone.BATTLEFIELD, "artifact: not a legal target")


func test_bone_shredder_with_no_legal_target_does_nothing() -> void:
	var knight := put_battlefield(1, "Black Knight")
	var shredder := _cast(0, "Bone Shredder")
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(shredder.zone, Mtg.Zone.BATTLEFIELD, "it can't target itself: it is black")


func test_bone_shredder_prefers_the_opponents_creature() -> void:
	put_battlefield(0, "Hill Giant")
	var theirs := put_battlefield(1, "Grizzly Bears")
	_cast(0, "Bone Shredder")
	assert_eq(theirs.zone, Mtg.Zone.GRAVEYARD, "the heuristic seat aims at the opponent")


# --- Avalanche Riders, Keldon Vandals ---------------------------------------------

func test_avalanche_riders_destroys_a_land() -> void:
	var land := put_battlefield(1, "Swamp")
	var riders := _cast(0, "Avalanche Riders")
	assert_eq(land.zone, Mtg.Zone.GRAVEYARD)
	assert_true(riders.has_keyword(Mtg.Keyword.HASTE))


func test_keldon_vandals_destroys_an_artifact() -> void:
	var rod := put_battlefield(1, "Iron Star")
	var bears := put_battlefield(1, "Grizzly Bears")
	_cast(0, "Keldon Vandals")
	assert_eq(rod.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


# --- Ghitu Slinger, Keldon Champion -----------------------------------------------

func test_ghitu_slinger_deals_2_to_any_target() -> void:
	_cast(0, "Ghitu Slinger")
	assert_eq(g.players[1].life, 18, "the heuristic seat aims at the opponent")


func test_keldon_champion_deals_3_to_target_player() -> void:
	var champion := _cast(0, "Keldon Champion")
	assert_eq(g.players[1].life, 17)
	assert_true(champion.has_keyword(Mtg.Keyword.HASTE))


# --- Deranged Hermit -------------------------------------------------------------

func _squirrels(pid: int) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.has_subtype("squirrel"): out.append(i)
	return out


func test_deranged_hermit_makes_four_squirrels_and_pumps_every_squirrel() -> void:
	_cast(0, "Deranged Hermit")
	var squirrels := _squirrels(0)
	assert_eq(squirrels.size(), 4)
	for s in squirrels:
		assert_true(s.is_token)
		assert_eq([s.cur_power, s.cur_toughness], [2, 2], "1/1 +1/+1")


func test_deranged_hermits_squirrels_shrink_when_its_echo_goes_unpaid() -> void:
	_cast(0, "Deranged Hermit")
	_upkeep_of(3)   # no lands: the echo can't be paid
	var squirrels := _squirrels(0)
	assert_eq(squirrels.size(), 4)
	for s in squirrels:
		assert_eq([s.cur_power, s.cur_toughness], [1, 1], "the anthem left with the Hermit")


# --- Yavimaya Granger ------------------------------------------------------------

func test_yavimaya_granger_fetches_a_basic_land_tapped() -> void:
	var lands_before := 0
	for i in g.players[0].battlefield:
		if i.is_land(): lands_before += 1
	_cast(0, "Yavimaya Granger")
	var lands: Array[CardInstance] = []
	for i in g.players[0].battlefield:
		if i.is_land(): lands.append(i)
	assert_eq(lands.size(), lands_before + 1)
	assert_true(lands.back().tapped, "it enters tapped")


class Decliner extends DecisionAgent:
	func answer_card(_g: MtgGame, _pid: int, _c: Array[CardInstance], _p: String) -> CardInstance:
		return null


func test_yavimaya_granger_may_find_nothing() -> void:
	g.set_agent(0, Decliner.new())
	_cast(0, "Yavimaya Granger")
	for i in g.players[0].battlefield:
		assert_false(i.is_land(), "declined: no land")


# --- Goblin Marshal, Hunting Moa ----------------------------------------------------

func _goblin_tokens(pid: int) -> int:
	var n := 0
	for i in g.players[pid].battlefield:
		if i.is_token and i.has_subtype("goblin"): n += 1
	return n


func test_goblin_marshal_makes_two_goblins_on_entering_and_two_more_dying() -> void:
	var marshal := _cast(0, "Goblin Marshal")
	assert_eq(_goblin_tokens(0), 2)
	_upkeep_of(3)   # no lands: the echo goes unpaid, the Marshal is sacrificed
	assert_eq(marshal.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(_goblin_tokens(0), 4, "it died: two more")


func test_hunting_moa_counters_on_entering_and_dying() -> void:
	var wurm := put_battlefield(0, "Craw Wurm")   # our biggest: the helpful target
	var moa := _cast(0, "Hunting Moa")
	assert_eq(int(wurm.counters.get("+1/+1", 0)), 1, "entering: a counter on our Wurm")
	assert_eq(int(moa.counters.get("+1/+1", 0)), 0)
	g.destroy(moa)
	resolve_stack()
	assert_eq(moa.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(int(wurm.counters.get("+1/+1", 0)), 2, "dying: another")


func test_hunting_moa_dying_alone_has_no_target() -> void:
	var moa := put_battlefield(0, "Hunting Moa")
	g.destroy(moa)
	resolve_stack()
	assert_eq(moa.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.stack.is_empty())


# --- Lightning Dragon, Albino Troll ----------------------------------------------

func test_lightning_dragon_firebreathes() -> void:
	var dragon := put_battlefield(0, "Lightning Dragon")
	add_mana(0, Mtg.ManaColor.R, 2)
	assert_ok(g.activate_ability(0, dragon, 0, []))
	resolve_stack()
	assert_ok(g.activate_ability(0, dragon, 0, []))
	resolve_stack()
	assert_eq(dragon.cur_power, 6)
	assert_eq(dragon.cur_toughness, 4)


func test_albino_troll_regenerates() -> void:
	var troll := put_battlefield(0, "Albino Troll")
	add_mana(0, Mtg.ManaColor.G, 1)
	add_mana(0, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(0, troll, 0, []))
	resolve_stack()
	g.destroy(troll)
	assert_eq(troll.zone, Mtg.Zone.BATTLEFIELD, "regenerated")
	assert_true(troll.tapped)


func test_an_unpaid_echo_cannot_be_regenerated() -> void:
	var troll := put_battlefield(0, "Albino Troll")
	troll.regeneration_shields = 1
	_upkeep_of(3)
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "sacrificed, not destroyed")
