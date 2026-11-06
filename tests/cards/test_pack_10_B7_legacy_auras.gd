extends GameTest
## Pack 10 (the Urza block), batch B7: the Urza's Legacy Auras in
## cards/sets/ulg/_auras.gd, and the self-returning Auras' edges named in
## the pack inventory: an Aura put into the graveyard by state-based
## actions comes back; one exiled instead (Forbidden Crypt, Pack 8) does not.

const CLAIMED := ["Cessation", "Slow Motion", "Sleeper's Guile", "Treacherous Link",
	"Granite Grip", "Sluggishness", "Rancor"]

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

func _pt(i: CardInstance) -> Array: return [i.cur_power, i.cur_toughness]

func _priority_to(pid: int) -> void:
	if g.priority_player != pid: assert_ok(g.pass_priority(g.priority_player))
	assert_eq(g.priority_player, pid)

func _enchant(pid: int, aura_name: String, host: CardInstance, mana: Array) -> CardInstance:
	_priority_to(pid)
	var aura := give_hand(pid, aura_name)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, aura, [TargetRef.card(host)]))
	resolve_stack()
	assert_eq(aura.attached_to, host.id, aura_name + " is attached")
	return aura

func _cast_at(pid: int, spell: String, target: TargetRef, mana: Array) -> CardInstance:
	_priority_to(pid)
	var card := give_hand(pid, spell)
	for m in mana: add_mana(pid, int(m))
	assert_ok(g.cast_spell(pid, card, [target]))
	resolve_stack()
	return card

func _bolt(pid: int, target: TargetRef) -> void:
	_cast_at(pid, "Lightning Bolt", target, [Mtg.ManaColor.R])

func _to_upkeep_of(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.turn_number == turn and guard < 400:
		_advance_once()
		guard += 1
	while not (g.active_player == pid and g.current_step() == Mtg.Step.UPKEEP) and guard < 400:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, pid)
	assert_eq(g.current_step(), Mtg.Step.UPKEEP)


func test_claimed_cards_no_longer_carry_the_pending_guard() -> void:
	for card_name in CLAIMED:
		var c := CardRegistry.get_card(card_name)
		assert_not_null(c, card_name)
		if c == null: continue
		var pending := c.cast_condition.is_valid() and c.cast_condition.get_method() == "_pending"
		assert_false(pending, "%s is still pending" % card_name)
		assert_true(c.is_aura(), "%s enchants something" % card_name)


# ---------------------------------------------------------------------- Rancor --

func test_rancor_pumps_tramples_and_comes_back_after_its_creature_dies() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(1, "Llanowar Elves")
	var rancor := _enchant(0, "Rancor", bear, [Mtg.ManaColor.G])
	assert_eq(_pt(bear), [4, 2])
	assert_true(bear.has_keyword(Mtg.Keyword.TRAMPLE))
	run_combat([bear.id], {wall.id: bear.id})
	assert_eq(g.players[1].life, 17, "three tramples over the 1/1")
	_bolt(1, TargetRef.card(bear))
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(rancor.zone, Mtg.Zone.HAND, "put into the graveyard by state-based actions: it returns")

func test_rancor_exiled_instead_by_forbidden_crypt_does_not_return() -> void:
	CardPacks.set_enabled("pack-8", true)
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(0, "Forbidden Crypt")
	var bear := put_battlefield(0, "Grizzly Bears")
	var rancor := _enchant(0, "Rancor", bear, [Mtg.ManaColor.G])
	_bolt(1, TargetRef.card(bear))
	assert_eq(rancor.zone, Mtg.Zone.EXILE, "never put into a graveyard: no trigger")
	assert_false(g.players[0].hand.has(rancor))

func test_rancor_on_an_opponents_creature_comes_back_to_its_owner() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	var rancor := _enchant(0, "Rancor", giant, [Mtg.ManaColor.G])
	_cast_at(0, "Terror", TargetRef.card(giant), [Mtg.ManaColor.B, Mtg.ManaColor.C])
	assert_true(g.players[0].hand.has(rancor))

func test_rancor_whose_target_died_in_response_stays_in_the_graveyard() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var rancor := give_hand(0, "Rancor")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, rancor, [TargetRef.card(bear)]))
	assert_ok(g.pass_priority(0))
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(bear)]))
	resolve_stack()
	assert_eq(rancor.zone, Mtg.Zone.GRAVEYARD, "it never was on the battlefield")


# ------------------------------------------------------------------- Cessation --

func test_cessation_stops_attacks_but_not_blocks_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var cessation := _enchant(0, "Cessation", bear, [Mtg.ManaColor.W, Mtg.ManaColor.C, Mtg.ManaColor.C])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_refused(g.declare_attackers(0, [bear.id]))
	assert_ok(g.declare_attackers(0, []))
	advance_to_next_turn()
	var giant := put_battlefield(1, "Hill Giant")
	run_combat([giant.id], {bear.id: giant.id})
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "it may still block")
	assert_eq(cessation.zone, Mtg.Zone.HAND)


# ---------------------------------------------------------------- Sluggishness --

func test_sluggishness_stops_blocks_but_not_attacks_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	var aura := _enchant(0, "Sluggishness", bear, [Mtg.ManaColor.R, Mtg.ManaColor.C])
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bear.id: giant.id}))
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 17)
	advance_to_step(Mtg.Step.MAIN2)
	_bolt(0, TargetRef.card(bear))
	assert_true(g.players[0].hand.has(aura), "to its owner's hand")


# ------------------------------------------------------------- Sleeper's Guile --

func test_sleepers_guile_gives_fear_and_comes_home() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var aura := _enchant(0, "Sleeper's Guile", bear, [Mtg.ManaColor.B, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_true(bear.has_keyword(Mtg.Keyword.FEAR))
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: bear.id}), "")
	assert_ok(g.declare_blockers(1, {}))
	advance_to_step(Mtg.Step.MAIN2)
	_bolt(1, TargetRef.card(bear))
	assert_eq(aura.zone, Mtg.Zone.HAND)


# ----------------------------------------------------------------- Slow Motion --

func test_slow_motion_sacrifices_the_creature_unless_its_controller_pays() -> void:
	var seat := _seat(1)
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	var aura := _enchant(0, "Slow Motion", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(seat.asked.size(), 1, "the creature's controller is asked")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "paid {2}")
	seat.yes = false
	_to_upkeep_of(1)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "declined")
	assert_true(g.players[0].hand.has(aura), "and the Aura came home")

func test_slow_motion_only_in_the_creatures_controllers_upkeep() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	_enchant(0, "Slow Motion", bear, [Mtg.ManaColor.U, Mtg.ManaColor.C, Mtg.ManaColor.C])
	_to_upkeep_of(1)
	assert_true(g.stack.is_empty())
	_to_upkeep_of(0)
	assert_false(g.stack.is_empty())
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD, "no mana to pay")


# ------------------------------------------------------------ Treacherous Link --

func test_treacherous_link_sends_the_creatures_damage_to_its_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Treacherous Link", giant, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	_bolt(0, TargetRef.card(giant))
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.damage, 0)
	assert_eq(g.players[1].life, 17, "its controller took it")

func test_treacherous_link_follows_a_change_of_controller() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var giant := put_battlefield(1, "Hill Giant")
	_enchant(0, "Treacherous Link", giant, [Mtg.ManaColor.B, Mtg.ManaColor.C])
	g.change_control(giant, 0)
	_bolt(1, TargetRef.card(giant))
	assert_eq(g.players[0].life, 17, "its controller as the damage is dealt")
	assert_eq(g.players[1].life, 20)


# ----------------------------------------------------------------- Granite Grip --

func test_granite_grip_counts_your_mountains() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Mountain")
	_enchant(0, "Granite Grip", bear, [Mtg.ManaColor.R, Mtg.ManaColor.C, Mtg.ManaColor.C])
	assert_eq(_pt(bear), [4, 2], "+1/+0 for each of the two Mountains you control")
