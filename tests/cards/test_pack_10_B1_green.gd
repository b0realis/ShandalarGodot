extends GameTest
## Pack 10 (the Urza block), batch B1: the green instants and sorceries of
## cards/sets/usg/_spells.gd and cards/sets/ulg/_spells.gd — every card
## claimed, its main effect, a refused or illegal case, and the
## interactions its text implies (searches that may find less, a land
## sacrificed as a cost, each owner ordering their own library top).

const CLAIMED := ["Gaea's Bounty", "Symbiosis", "Titania's Boon", "Whirlwind", "Crop Rotation",
	"Harmonic Convergence", "Might of Oaks", "Silk Net", "Wing Snare"]


## Scripted answers: a card by name from [member picks] (else the first
## candidate, or nothing at all with [member declines]). [member seen]
## keeps the names offered by the last card question.
class Seat extends DecisionAgent:
	var picks: Array[String] = []
	var declines := false
	var seen: Array[String] = []
	func answer_card(_g: MtgGame, _pid: int, candidates: Array[CardInstance], _prompt: String) -> CardInstance:
		seen.clear()
		for c in candidates: seen.append(c.data.card_name)
		for n in picks.size():
			for c in candidates:
				if c.data.card_name == picks[n]:
					picks.remove_at(n)
					return c
		if declines: return null
		return null if candidates.is_empty() else candidates[0]


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

func _pay(pid: int, card_name: String, x := 0) -> void:
	var cost := CardRegistry.get_card(card_name).cost
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	var generic := cost.generic + x * cost.x_count
	if generic > 0:
		add_mana(pid, Mtg.ManaColor.C, generic)

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

func _library_top(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.put_from_hand_on_top_of_library(card)
	return card


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)


# ------------------------------------------------------------ Gaea's Bounty --

func test_gaeas_bounty_fetches_up_to_two_forests() -> void:
	var seat := _seat(0)
	_library_top(0, "Island")
	var library := g.players[0].library.size()
	_cast_resolve(0, "Gaea's Bounty")
	assert_eq(g.players[0].hand.size(), 2)
	for c in g.players[0].hand:
		assert_eq(c.data.card_name, "Forest")
	assert_eq(g.players[0].library.size(), library - 2)
	assert_false(seat.seen.has("Island"), "Forest cards only")

func test_gaeas_bounty_may_find_fewer() -> void:
	var seat := _seat(0)
	seat.declines = true
	var library := g.players[0].library.size()
	_cast_resolve(0, "Gaea's Bounty")
	assert_eq(g.players[0].hand.size(), 0)
	assert_eq(g.players[0].library.size(), library)


# ---------------------------------------------------------------- Symbiosis --

func test_symbiosis_pumps_two_target_creatures() -> void:
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(1, "Gray Ogre")
	assert_refused(_try(0, "Symbiosis", [TargetRef.card(a)]))
	_cast_resolve(0, "Symbiosis", [TargetRef.card(a), TargetRef.card(b)])
	assert_eq([a.cur_power, a.cur_toughness], [4, 4])
	assert_eq([b.cur_power, b.cur_toughness], [4, 4])
	advance_to_next_turn()
	assert_eq([a.cur_power, a.cur_toughness], [2, 2])


# ----------------------------------------------------------- Titania's Boon --

func test_titanias_boon_counters_each_creature_you_control() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var ogre := put_battlefield(1, "Gray Ogre")
	_cast_resolve(0, "Titania's Boon")
	assert_eq(int(bear.counters.get("+1/+1", 0)), 1)
	assert_eq(int(giant.counters.get("+1/+1", 0)), 1)
	assert_eq(int(ogre.counters.get("+1/+1", 0)), 0)
	advance_to_next_turn()
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3], "a counter stays")


# ---------------------------------------------------------------- Whirlwind --

func test_whirlwind_destroys_every_creature_with_flying() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	var birds := put_battlefield(0, "Birds of Paradise")
	var bear := put_battlefield(1, "Grizzly Bears")
	_cast_resolve(0, "Whirlwind")
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(birds.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)


# ------------------------------------------------------------ Crop Rotation --

func test_crop_rotation_trades_a_land_for_one_from_the_library() -> void:
	var seat := _seat(0)
	var forest := put_battlefield(0, "Forest")
	var island := _library_top(0, "Island")
	seat.picks = ["Island"]
	_cast_resolve(0, "Crop Rotation")
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(island.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(island.tapped)

func test_crop_rotation_needs_a_land_to_sacrifice() -> void:
	assert_refused(_try(0, "Crop Rotation"), "land")


# ----------------------------------------------------- Harmonic Convergence --

func test_harmonic_convergence_puts_every_enchantment_on_its_owners_library() -> void:
	var seat := _seat(0)
	var crusade := put_battlefield(0, "Crusade")
	var bear := put_battlefield(0, "Grizzly Bears")
	var holy := give_hand(0, "Holy Strength")
	g.attach_aura_from_anywhere(holy, bear, 0)
	var pest := put_battlefield(1, "Pestilence")
	seat.picks = ["Holy Strength"]
	_cast_resolve(0, "Harmonic Convergence")
	var mine := g.players[0].library
	assert_eq(mine[mine.size() - 1], holy, "the owner chose it to be on top")
	assert_eq(mine[mine.size() - 2], crusade)
	assert_eq(g.players[1].library.back(), pest)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq([bear.cur_power, bear.cur_toughness], [2, 2])

func test_harmonic_convergence_the_other_order() -> void:
	var seat := _seat(0)
	var crusade := put_battlefield(0, "Crusade")
	var pest := put_battlefield(0, "Pestilence")
	seat.picks = ["Crusade"]
	_cast_resolve(0, "Harmonic Convergence")
	var mine := g.players[0].library
	assert_eq(mine[mine.size() - 1], crusade)
	assert_eq(mine[mine.size() - 2], pest)


# ------------------------------------------------------------- Might of Oaks --

func test_might_of_oaks_gives_plus_seven() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	_cast_resolve(0, "Might of Oaks", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [9, 9])


# ----------------------------------------------------------------- Silk Net --

func test_silk_net_gives_plus_one_and_reach_to_block_a_flier() -> void:
	var pegasus := put_battlefield(0, "Mesa Pegasus")
	var bear := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [pegasus.id]))
	resolve_stack()
	_cast_resolve(1, "Silk Net", [TargetRef.card(bear)])
	assert_eq([bear.cur_power, bear.cur_toughness], [3, 3])
	assert_true(bear.has_keyword(Mtg.Keyword.REACH))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {bear.id: pegasus.id}))


# --------------------------------------------------------------- Wing Snare --

func test_wing_snare_destroys_target_creature_with_flying() -> void:
	var angel := put_battlefield(1, "Serra Angel")
	_cast_resolve(0, "Wing Snare", [TargetRef.card(angel)])
	assert_eq(angel.zone, Mtg.Zone.GRAVEYARD)
	var bear := put_battlefield(1, "Grizzly Bears")
	assert_refused(_try(0, "Wing Snare", [TargetRef.card(bear)]))
