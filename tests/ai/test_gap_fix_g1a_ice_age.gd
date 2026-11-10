extends GameTest
## GAP FIX G1a (gap review 2026-11-10, r1a-5 and r1a-6): three Ice Age
## combat readings that ran ahead of the blocks.
##
## r1a-5 — Kjeldoran Royal Guard ("{T}: all combat damage that would be
## dealt to you by unblocked creatures this turn is dealt to this creature
## instead") and Mercenaries ("{3}: the next time this creature would deal
## damage to you this turn, prevent that damage") counted every attacker as
## unblocked while the blockers were still to be declared: the Guard tapped
## itself out of blocking, and {3} was paid against an attacker that a
## blocker could still stop. Both wait for the blocks now, and the Guard
## counts the combat damage its own block takes too.
##
## r1a-6 — Melee ("whenever a creature attacks and isn't blocked this
## combat, untap it and remove it from combat") was priced by the fights it
## forces alone: cast into a lethal attack it removed the lethal damage.
## The face damage the attack would land through their best blocks is now
## charged, and Melee is never cast when that damage is lethal.
##
## All three are [member AiProfile.forecasts_tactics]: off keeps the old
## decision. Public board only.

const ICE := preload("res://engine/ai/ice_age_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled(IceAgePack.ID, true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled(IceAgePack.ID, false)
	CardPacks.set_enabled(CardPacks.ID, false)


func pilot(forecasts := true, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, AiProfile.wizard())
	ai.profile.develops_late = false
	ai.profile.forecasts_tactics = forecasts
	g.set_agent(seat, ai)
	return ai


## Seat 1 attacks with [param attackers]; seat 0 holds priority in the
## declare attackers step, before any block.
func _their_attack(attackers: Array) -> void:
	advance_to_next_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, attackers))
	resolve_stack()
	if g.priority_player == 1: assert_ok(g.pass_priority(1))


## ...then seat 0 declares [param blocks] and holds priority after them.
func _block(blocks: Dictionary) -> void:
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, blocks))
	if g.priority_player == 1: assert_ok(g.pass_priority(1))


static func _digest(option: Dictionary) -> Array:
	if option.is_empty(): return []
	return [snappedf(float(option["value"]), 0.001), option.get("targets", []).size()]


# --- r1a-5: Kjeldoran Royal Guard ------------------------------------------

func test_royal_guard_waits_for_blocks() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")   # 2/5
	var x := put_battlefield(1, "Grizzly Bears")
	var y := put_battlefield(1, "Grizzly Bears")
	_their_attack([x.id, y.id])
	var ai := pilot()
	assert_true(ai._ability_option(g, guard, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"before blocks nothing is unblocked yet")
	ai.act(g)
	assert_false(guard.tapped, "the Guard is still a blocker")


func test_royal_guard_takes_the_unblocked_damage_after_blocks() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")
	var x := put_battlefield(1, "Grizzly Bears")
	var y := put_battlefield(1, "Grizzly Bears")
	_their_attack([x.id, y.id])
	_block({})
	var ai := pilot()
	assert_eq(ai.act(g), "activated Kjeldoran Royal Guard", "four damage onto a 2/5")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)
	assert_eq(guard.zone, Mtg.Zone.BATTLEFIELD)


func test_royal_guard_counts_the_damage_of_its_own_block() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")
	var giant := put_battlefield(1, "Hill Giant")
	var x := put_battlefield(1, "Grizzly Bears")
	var y := put_battlefield(1, "Grizzly Bears")
	_their_attack([giant.id, x.id, y.id])
	_block({guard.id: giant.id})
	var ai := pilot()
	assert_true(ai._ability_option(g, guard, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"three from the Giant and four redirected kill a 2/5 for four life at twenty")
	ai.act(g)
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(guard.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 16)


func test_royal_guard_gate_off_keeps_the_old_reading() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")
	var x := put_battlefield(1, "Grizzly Bears")
	var y := put_battlefield(1, "Grizzly Bears")
	_their_attack([x.id, y.id])
	var ai := pilot(false)
	assert_false(ai._ability_option(g, guard, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"forecasts_tactics off: the pre-fix reading, unchanged")


func test_royal_guard_reads_no_hidden_card() -> void:
	var guard := put_battlefield(0, "Kjeldoran Royal Guard")
	var x := put_battlefield(1, "Grizzly Bears")
	var y := put_battlefield(1, "Grizzly Bears")
	var hidden := give_hand(1, "Giant Growth")
	_their_attack([x.id, y.id])
	_block({})
	var ai := pilot()
	var before := _digest(ai._ability_option(g, guard, 0, AiPlayer.Moment.RESPONSE))
	hidden.data = CardRegistry.get_card("Lightning Bolt")
	assert_eq(_digest(ai._ability_option(g, guard, 0, AiPlayer.Moment.RESPONSE)), before)
	assert_false(before.is_empty())


# --- r1a-5: Mercenaries -----------------------------------------------------

func test_mercenaries_shield_waits_for_blocks() -> void:
	var merc := put_battlefield(1, "Mercenaries")   # 3/3, theirs
	put_battlefield(0, "Hill Giant")                # a blocker for it
	for _i in 3: put_battlefield(0, "Plains")
	_their_attack([merc.id])
	var ai := pilot()
	assert_true(ai._ability_option(g, merc, 0, AiPlayer.Moment.RESPONSE).is_empty(),
		"{3} for a shield against an attacker it can still block")
	assert_false(ai.act(g).begins_with("activated Mercenaries"))


func test_mercenaries_shield_is_bought_once_it_is_unblocked() -> void:
	var merc := put_battlefield(1, "Mercenaries")
	for _i in 3: put_battlefield(0, "Plains")
	_their_attack([merc.id])
	_block({})
	var ai := pilot()
	assert_eq(ai.act(g), "activated Mercenaries", "three damage on the way, nothing to block it")


func test_mercenaries_gate_off_keeps_the_old_reading() -> void:
	var merc := put_battlefield(1, "Mercenaries")
	put_battlefield(0, "Hill Giant")
	for _i in 3: put_battlefield(0, "Plains")
	_their_attack([merc.id])
	var ai := pilot(false)
	assert_false(ai._ability_option(g, merc, 0, AiPlayer.Moment.RESPONSE).is_empty())


# --- r1a-6: Melee -----------------------------------------------------------

func _melee_board(their_life: int) -> Array:
	var wurm := put_battlefield(0, "Craw Wurm")
	var giant := put_battlefield(0, "Hill Giant")
	var bear := put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	g.players[1].life = their_life
	give_hand(0, "Melee")
	for _i in 5: put_battlefield(0, "Mountain")
	return [wurm, giant, bear]


func test_melee_does_not_throw_away_lethal() -> void:
	var ours := _melee_board(2)
	var a := pilot()
	var b := pilot(true, 1)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ours[0].id, ours[1].id, ours[2].id]))
	resolve_stack()
	var melee: CardInstance = g.players[0].hand[0]
	assert_true(ICE.spell_choice(g, a, melee, 0, 0).is_empty(),
		"three attackers into two blockers at 2 life is lethal without Melee")
	var guard := 0
	while not g.game_over and g.current_step() != Mtg.Step.COMBAT_END and guard < 200:
		a.act(g)
		b.act(g)
		guard += 1
	assert_true(g.game_over and g.winner == 0, "the attack is lethal through their best blocks")


func test_melee_charges_the_face_damage_it_removes() -> void:
	# Serra Angel forced in front of the Scaled Wurm dies — but twelve damage
	# from four attackers into one blocker is the larger prize at 20 life.
	var scaled := put_battlefield(0, "Scaled Wurm")
	var craw := put_battlefield(0, "Craw Wurm")
	var g1 := put_battlefield(0, "Hill Giant")
	var g2 := put_battlefield(0, "Hill Giant")
	put_battlefield(1, "Serra Angel")
	var melee := give_hand(0, "Melee")
	for _i in 5: put_battlefield(0, "Mountain")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [scaled.id, craw.id, g1.id, g2.id]))
	resolve_stack()
	var ai := pilot()
	assert_true(ICE.spell_choice(g, ai, melee, 0, 0).is_empty(),
		"Melee removes twelve unblocked damage to kill one Angel")
	assert_ne(ai.act(g), "cast Melee")


func test_melee_still_forces_a_winning_fight() -> void:
	var giant := put_battlefield(0, "Scaled Wurm")
	var enemy := put_battlefield(1, "Serra Angel")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [giant.id]))
	var melee := give_hand(0, "Melee")
	add_mana(0, Mtg.ManaColor.R, 5)
	var ai := pilot()
	assert_false(ICE.spell_choice(g, ai, melee, 0, 0).is_empty(),
		"the Angel would block nothing; Melee makes it block the Wurm and die")
	assert_eq(ICE.respond(g, ai), "cast Melee")
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_eq(ai.act(g), "chose opposing blockers with Melee")
	assert_eq(g.combat.blocks.get(enemy.id, -1), giant.id)


func test_melee_gate_off_keeps_the_old_reading() -> void:
	var ours := _melee_board(2)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ours[0].id, ours[1].id, ours[2].id]))
	resolve_stack()
	var ai := pilot(false)
	var melee: CardInstance = g.players[0].hand[0]
	assert_false(ICE.spell_choice(g, ai, melee, 0, 0).is_empty(),
		"forecasts_tactics off: the pre-fix reading, unchanged")


func test_melee_reads_no_hidden_card() -> void:
	var ours := _melee_board(9)
	var hidden := give_hand(1, "Giant Growth")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [ours[0].id, ours[1].id, ours[2].id]))
	resolve_stack()
	var ai := pilot()
	var melee: CardInstance = g.players[0].hand[0]
	var before: Variant = ICE.spell_choice(g, ai, melee, 0, 0)
	hidden.data = CardRegistry.get_card("Fog")
	var after: Variant = ICE.spell_choice(g, ai, melee, 0, 0)
	assert_eq(_digest(after), _digest(before))
