extends GameTest
## Pack 10 (the Urza block), batch B6: Urza's Legacy's "at the beginning of
## your upkeep, if …, sacrifice this enchantment and …" cards in
## cards/sets/ulg/_enchantments.gd — Planar Collapse, Second Chance, Brink
## of Madness, Impending Disaster and Defense of the Heart. Each "if" is an
## intervening one (CR 603.4): checked as it triggers and on resolution.

const W := Mtg.ManaColor.W
const U := Mtg.ManaColor.U
const B := Mtg.ManaColor.B
const R := Mtg.ManaColor.R
const G := Mtg.ManaColor.G

## A seat whose answers a test scripts: yes/no (-1 follows the hint) and
## card names to prefer, and [member decline] for an optional card question.
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var decline := false
	var asked: Array = []
	func answer_yes_no(_game: MtgGame, _pid: int, prompt: String, hint: bool) -> bool:
		asked.append(prompt)
		return hint if yes < 0 else yes == 1
	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		asked.append(prompt)
		if decline: return null
		for name in prefer:
			for c in candidates:
				if c.data.card_name == name: return c
		return null if candidates.is_empty() else candidates[0]

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


func _to_upkeep(pid: int) -> void:
	var start := g.turn_number
	var guard := 0
	while not g.game_over and guard < 800 and not (g.turn_number > start
			and g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP):
		_advance_once()
		guard += 1
	assert_lt(guard, 800, "never reached the upkeep")

func _priority(pid: int) -> void:
	if g.priority_player != pid:
		assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _named(pid: int, card_name: String) -> Array[CardInstance]:
	var out: Array[CardInstance] = []
	for i in g.players[pid].battlefield:
		if i.data.card_name == card_name: out.append(i)
	return out


# ------------------------------------------------------------ Planar Collapse --

func test_planar_collapse_wipes_four_creatures_without_regeneration() -> void:
	var collapse := put_battlefield(0, "Planar Collapse")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Craw Wurm")
	var troll := put_battlefield(1, "Uthden Troll")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	_priority(1)
	add_mana(1, R)
	assert_ok(g.activate_ability(1, troll, 0, []))
	resolve_stack()
	assert_eq(collapse.zone, Mtg.Zone.GRAVEYARD, "sacrificed")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(troll.zone, Mtg.Zone.GRAVEYARD, "they can't be regenerated")


func test_planar_collapse_waits_for_four_creatures() -> void:
	var collapse := put_battlefield(0, "Planar Collapse")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Hill Giant")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 0, "three creatures: no trigger")
	assert_eq(collapse.zone, Mtg.Zone.BATTLEFIELD)


func test_planar_collapse_rechecks_the_count_on_resolution() -> void:
	var collapse := put_battlefield(0, "Planar Collapse")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Llanowar Elves")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	g.destroy(bears)
	resolve_stack()
	assert_eq(collapse.zone, Mtg.Zone.BATTLEFIELD, "only three left (CR 603.4)")
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------------- Second Chance --

func test_second_chance_takes_an_extra_turn_at_five_life() -> void:
	var chance := put_battlefield(0, "Second Chance")
	g.players[0].life = 5
	_to_upkeep(0)
	var turn := g.turn_number
	resolve_stack()
	assert_eq(chance.zone, Mtg.Zone.GRAVEYARD)
	advance_to_next_turn()
	assert_eq(g.turn_number, turn + 1)
	assert_eq(g.active_player, 0, "the extra turn is ours")


func test_second_chance_does_nothing_above_five_life() -> void:
	var chance := put_battlefield(0, "Second Chance")
	g.players[0].life = 6
	_to_upkeep(0)
	assert_eq(g.stack.size(), 0)
	assert_eq(chance.zone, Mtg.Zone.BATTLEFIELD)


func test_second_chance_rechecks_life_on_resolution() -> void:
	var chance := put_battlefield(0, "Second Chance")
	g.players[0].life = 5
	_to_upkeep(0)
	assert_eq(g.stack.size(), 1)
	g.adjust_life(0, 3)
	resolve_stack()
	assert_eq(chance.zone, Mtg.Zone.BATTLEFIELD)
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "no extra turn")


# ------------------------------------------------------------ Brink of Madness --

func test_brink_of_madness_empties_the_opponents_hand() -> void:
	var brink := put_battlefield(0, "Brink of Madness")
	for card in g.players[0].hand.duplicate(): g.put_on_bottom_of_library(card)
	_to_upkeep(0)
	for n in 3: give_hand(1, "Forest")
	assert_eq(g.stack.size(), 1)
	resolve_stack()
	assert_eq(brink.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].hand.size(), 0)


func test_brink_of_madness_needs_an_empty_hand() -> void:
	var brink := put_battlefield(0, "Brink of Madness")
	give_hand(0, "Forest")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 0)
	assert_eq(brink.zone, Mtg.Zone.BATTLEFIELD)


# ---------------------------------------------------------- Impending Disaster --

func test_impending_disaster_destroys_every_land_at_seven() -> void:
	var disaster := put_battlefield(0, "Impending Disaster")
	var lands: Array[CardInstance] = []
	for n in 4: lands.append(put_battlefield(0, "Forest"))
	for n in 3: lands.append(put_battlefield(1, "Island"))
	_to_upkeep(0)
	resolve_stack()
	assert_eq(disaster.zone, Mtg.Zone.GRAVEYARD)
	for land in lands: assert_eq(land.zone, Mtg.Zone.GRAVEYARD)


func test_impending_disaster_waits_below_seven() -> void:
	var disaster := put_battlefield(0, "Impending Disaster")
	for n in 6: put_battlefield(1, "Island")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 0)
	assert_eq(disaster.zone, Mtg.Zone.BATTLEFIELD)


# --------------------------------------------------------- Defense of the Heart --

func _in_library(pid: int, card_name: String) -> CardInstance:
	var card := _make_instance(pid, card_name)
	card.zone = Mtg.Zone.LIBRARY
	g.players[pid].library.insert(0, card)
	return card

func test_defense_of_the_heart_fetches_two_creatures() -> void:
	var defense := put_battlefield(0, "Defense of the Heart")
	for n in 3: put_battlefield(1, "Grizzly Bears")
	var wurm := _in_library(0, "Craw Wurm")
	var giant := _in_library(0, "Hill Giant")
	me.prefer = ["Craw Wurm", "Hill Giant"]
	_to_upkeep(0)
	resolve_stack()
	assert_eq(defense.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.controller_id, 0)


func test_defense_of_the_heart_creatures_enter_together() -> void:
	CardPacks.set_enabled("pack-9", true)   # Soul Warden (Exodus)
	put_battlefield(0, "Defense of the Heart")
	for n in 3: put_battlefield(1, "Grizzly Bears")
	var bears := _in_library(0, "Grizzly Bears")
	var warden := _in_library(0, "Soul Warden")
	me.prefer = ["Grizzly Bears", "Soul Warden"]   # the Bears first
	_to_upkeep(0)
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(warden.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 21, "the Warden sees the Bears entering with it (CR 603.6a)")


func test_defense_of_the_heart_may_find_fewer() -> void:
	put_battlefield(0, "Defense of the Heart")
	for n in 3: put_battlefield(1, "Grizzly Bears")
	var wurm := _in_library(0, "Craw Wurm")
	me.decline = true
	_to_upkeep(0)
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.LIBRARY, "fail to find (CR 701.19b)")


func test_defense_of_the_heart_needs_three_opposing_creatures() -> void:
	var defense := put_battlefield(0, "Defense of the Heart")
	for n in 2: put_battlefield(1, "Grizzly Bears")
	for n in 2: put_battlefield(0, "Grizzly Bears")
	_to_upkeep(0)
	assert_eq(g.stack.size(), 0, "its own creatures do not count")
	assert_eq(defense.zone, Mtg.Zone.BATTLEFIELD)
