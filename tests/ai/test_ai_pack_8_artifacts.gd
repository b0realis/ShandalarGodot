extends GameTest
## TWO ARTIFACTS THE READER COULD NOT SEE (Pack 8, 2026-10-03; card batch
## B6's notes; [member AiProfile.forecasts_tactics]).
##
## MAGMA MINE — "{4}: Put a pressure counter on this artifact" and "{T},
## Sacrifice this artifact: It deals damage equal to the number of pressure
## counters on it to any target" — is a DamageEffect of 0: the amount is
## the counters, read at resolution, so the intent saw no damage at all.
## The count is read off the effect's own line and the source's LIVE
## counters (mirage_tactics.gd `counter_damage`); the counter itself is
## bought at the mana sink by a pilot that plays engines.
##
## TRIANGLE OF WAR — "{2}, Sacrifice this artifact: Target creature you
## control fights target creature an opponent controls" — is two card-local
## effects; the pair is chosen where ours kills theirs, priced by what
## each side loses (`fight_pair_option`).
##
## (Mob Mentality is read as the trample aura it also is — hung on our own
## body; its all-out-attack pump is not planned for, which costs nothing.)


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai() -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


func test_the_mine_blasts_a_creature_its_counters_kill() -> void:
	var ai := _ai()
	var mine := put_battlefield(0, "Magma Mine")
	mine.counters["pressure"] = 3
	var giant := put_battlefield(1, "Hill Giant")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Magma Mine")
	resolve_stack()
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "three pressure counters, three damage")
	assert_eq(mine.zone, Mtg.Zone.GRAVEYARD)


func test_the_mine_finishes_the_opponent() -> void:
	var ai := _ai()
	var mine := put_battlefield(0, "Magma Mine")
	mine.counters["pressure"] = 5
	g.players[1].life = 5
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Magma Mine")
	resolve_stack()
	assert_true(g.game_over)


func test_an_empty_mine_is_never_sacrificed_and_is_fed_at_the_sink() -> void:
	var ai := _ai()
	var mine := put_battlefield(0, "Magma Mine")
	for _i in 4: put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD, "no counters, no damage: kept")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Magma Mine")
	resolve_stack()
	assert_eq(int(mine.counters.get("pressure", 0)), 1, "the mana about to be lost bought a counter")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)


func test_triangle_of_war_picks_a_fight_it_wins() -> void:
	var ai := _ai()
	put_battlefield(0, "Triangle of War")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	var giant := put_battlefield(0, "Hill Giant")
	var bears := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Triangle of War")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "3 damage killed the Bears, 2 did not kill the Giant")


func test_triangle_of_war_refuses_a_fight_it_loses() -> void:
	var ai := _ai()
	var triangle := put_battlefield(0, "Triangle of War")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Grizzly Bears")
	put_battlefield(1, "Craw Wurm")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(triangle.zone, Mtg.Zone.BATTLEFIELD, "a 2/2 cannot kill a 6/4")
