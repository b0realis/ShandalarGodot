extends GameTest
## FLANKING'S LEFTOVERS (Pack 8, 2026-10-03; engine packages E2 and E9;
## [member AiProfile.reads_gaze] for the combat readings,
## [member AiProfile.forecasts_tactics] for the response).
##
##  * A FLANKING TRIGGER STILL ON THE STACK is counted: between the block
##    and its resolution the blocker is already N smaller for every
##    response that reads the combat (mirage_tactics.gd `pending_flank`).
##  * THE FORCED COMPANION: an Ekundu Cyclops attacks whenever anything of
##    ours does (CR 508.1d); an attack it would turn into a loss is not
##    made (`price_forced_attackers`).
##  * THE LIFE TAX ON A BLOCK: Heat Wave's 1 life per blocker is spent
##    only on a block that kills, stops more than it costs, or keeps us
##    alive (`price_block_tax`).
##  * THE BLOCK AN EFFECT MAKES: Dazzling Beauty on their biggest
##    unblocked attacker — never a trampler, which would then deal all
##    its damage to us (`make_blocked_response`).


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _off() -> AiProfile:
	var p := AiProfile.wizard()
	p.reads_gaze = false
	return p


func _they_attack(ids: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, ids))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1


func _knight(power := 1, toughness := 1) -> CardData:
	return CardData.new("Test Flanker", "{1}{W}", Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords([Mtg.Keyword.FLANKING])


# ---------------------------------------------------- the pending trigger --

func test_a_pending_flanking_trigger_is_counted() -> void:
	# A 1/1 flanker blocked by our Bears: the trigger is on the stack, the
	# Bears is a 1/1 the moment it resolves, and the 1/1's hit kills it.
	var ai := _ai()
	var bears := put_battlefield(0, "Grizzly Bears")
	var knight := put_synthetic(1, _knight())
	_they_attack([knight.id])
	assert_ok(g.declare_blockers(0, {bears.id: knight.id}))
	assert_eq(g.stack.size(), 1, "the flanking trigger waits")
	assert_eq(bears.cur_toughness, 2, "not yet resolved")
	assert_true(ai._dies_to(g, bears, knight), "read as the 1/1 it is about to be")
	assert_true(ai._dies_in_combat(g, bears))


func test_off_the_pending_trigger_is_not_read() -> void:
	var ai := _ai(_off())
	var bears := put_battlefield(0, "Grizzly Bears")
	var knight := put_synthetic(1, _knight())
	_they_attack([knight.id])
	assert_ok(g.declare_blockers(0, {bears.id: knight.id}))
	assert_false(ai._dies_in_combat(g, bears), "the pilot as it was")


# ------------------------------------------------- the forced companion --

func test_no_attack_the_cyclops_would_lose() -> void:
	# The Angel flies over the Wurm, but the Cyclops comes too and dies in
	# front of it: four damage for a 3/4 is a loss, so nobody goes.
	var ai := _ai()
	var cyclops := put_battlefield(0, "Ekundu Cyclops")
	var angel := put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "declared 0 attacker")
	assert_false(angel.tapped)
	assert_eq(cyclops.zone, Mtg.Zone.BATTLEFIELD)


func test_the_cyclops_comes_along_when_the_attack_still_pays() -> void:
	var ai := _ai()
	var cyclops := put_battlefield(0, "Ekundu Cyclops")
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "declared 2 attacker")
	assert_true(g.combat.attackers.has(cyclops.id))


func test_off_the_companion_is_not_priced() -> void:
	var ai := _ai(_off())
	put_battlefield(0, "Ekundu Cyclops")
	put_battlefield(0, "Serra Angel")
	put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_string_contains(ai.act(g), "declared 2 attacker", "the repair drags it in, unpriced")


# ------------------------------------------------------------ the heat wave --

## Heat Wave enters after their upkeep (its cumulative upkeep would
## otherwise be the question), before our blocks.
func _heat_wave() -> void:
	put_battlefield(1, "Heat Wave")
	g.recalculate()


func test_heat_wave_a_one_for_one_block_is_not_paid_for() -> void:
	var ai := _ai()
	var wall := put_battlefield(0, "Wall of Stone")
	var elves := put_battlefield(1, "Llanowar Elves")
	_they_attack([elves.id])
	_heat_wave()
	assert_string_contains(ai.act(g), "declared 0 block")
	assert_false(g.combat.blocks.has(wall.id))


func test_heat_wave_a_block_that_stops_more_is_paid_for() -> void:
	var ai := _ai()
	var wall := put_battlefield(0, "Wall of Stone")
	var giant := put_battlefield(1, "Hill Giant")
	_they_attack([giant.id])
	_heat_wave()
	assert_string_contains(ai.act(g), "declared 1 block")
	assert_true(g.combat.blocks.has(wall.id))
	assert_eq(g.players[0].life, 19, "one life for three damage")


# ----------------------------------------------------- the made block --

func _past_blocks(blocks: Dictionary) -> void:
	assert_ok(g.declare_blockers(0, blocks))
	var guard := 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)


func test_dazzling_beauty_blocks_their_biggest_attacker() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Plains")
	var beauty := give_hand(0, "Dazzling Beauty")
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[0].life = 6
	_they_attack([wurm.id])
	_past_blocks({})
	assert_string_contains(ai.act(g), "Dazzling Beauty")
	resolve_stack()
	assert_true(g.combat.was_blocked(g.combat.band_of(wurm.id)))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 6, "blocked by nothing, it dealt nothing")
	assert_eq(beauty.zone, Mtg.Zone.GRAVEYARD)


func test_dazzling_beauty_never_blocks_a_trampler() -> void:
	var ai := _ai()
	for _i in 3: put_battlefield(0, "Plains")
	var beauty := give_hand(0, "Dazzling Beauty")
	var stomper := put_synthetic(1, CardData.new("Test Stomper", "{4}{G}", Mtg.CardType.CREATURE)
		.pt(6, 6).with_keywords([Mtg.Keyword.TRAMPLE]))
	g.players[0].life = 6
	_they_attack([stomper.id])
	_past_blocks({})
	ai.act(g)
	assert_eq(beauty.zone, Mtg.Zone.HAND, "blocked by nothing, a trampler deals it all to us")


# ------------------------------------------------- the flankers' buttons --

func _we_attack(ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, ids))
	resolve_stack()


func test_searing_spear_askari_buys_menace_past_a_lone_blocker() -> void:
	var ai := _ai()
	var askari := put_battlefield(0, "Searing Spear Askari")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var bears := put_battlefield(1, "Grizzly Bears")
	_we_attack([askari.id])
	assert_eq(g.priority_player, 0)
	assert_string_contains(ai.act(g), "Searing Spear Askari")
	resolve_stack()
	assert_eq(askari.cur_min_blockers, 2, "menace")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {bears.id: askari.id}))


func test_knight_of_valor_shrinks_the_blocker_that_would_kill_it() -> void:
	var ai := _ai()
	var knight := put_battlefield(0, "Knight of Valor")
	put_battlefield(0, "Plains")
	put_battlefield(0, "Plains")
	var giant := put_battlefield(1, "Hill Giant")
	_we_attack([knight.id])
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {giant.id: knight.id}))
	resolve_stack()   # the flanking trigger: the Giant is a 2/2
	var guard := 0
	while g.priority_player != 0 and guard < 5:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_string_contains(ai.act(g), "Knight of Valor")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(knight.zone, Mtg.Zone.BATTLEFIELD, "a 1/1 Giant could not kill it")
