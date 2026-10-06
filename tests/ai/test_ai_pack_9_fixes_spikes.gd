extends GameTest
## THE SPIKE'S COUNTERS IN A DECLARED COMBAT (Pack 9 study fix, 2026-10-06;
## CR 510.1c, 510.2, 602.2b; [member AiProfile.forecasts_tactics];
## engine/ai/tempest_tactics.gd `spike_save`).
##
## The Deck Lab study (Spikes v Licids, seed 98100) measured the Spike
## policy at -9.5 +- 7.6 points: a Spike "about to die" in combat spent
## every counter BEFORE damage, shrank, and lost the kill its counters
## were — two Spike Feeders double-blocking a Youthful Knight both cashed
## out (each was judged doomed although the Knight's two points can kill
## only one of them) and the Knight lived; a Feeder trading with a 2/2
## cashed out and the 2/2 lived. The rule pinned here:
##  * the combat is read by the game's own damage forecast (the division
##    among several blockers, first strike, prevention), not by a
##    one-pair reading, so a Spike the damage does not reach is not
##    "doomed";
##  * a doomed Spike spends a counter only when the combat with the
##    counter gone (and whatever it buys put on the board) is no worse:
##    the counters its kill needs stay on it;
##  * what it buys is read whole — a regeneration shield, a counter on a
##    creature that survives, a pump on itself, life.
## The null arm (gate off) spends nothing; the opponent's hidden hand and
## library do not move a decision.


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _spike(name: String, counters: int) -> CardInstance:
	var spike := put_battlefield(0, name)
	spike.counters["+1/+1"] = counters
	g.recalculate()
	return spike


func _lands(name: String, n: int, seat := 0) -> void:
	for _i in n: put_battlefield(seat, name)


## Seat 1 attacks with [param attackers]; seat 0 blocks with [param blocks]
## (blocker id -> attacker id); seat 0 then holds priority in the declare
## blockers step.
func _their_attack(attackers: Array, blocks: Dictionary) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, attackers))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, blocks))
	guard = 0
	while g.priority_player != 0 and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)


## Seat 0's AI acts and seat 1 passes until the combat is over; the AI's
## lines.
func _fight(ai: AiPlayer) -> Array:
	var lines: Array = []
	var guard := 0
	while g.active_player == 1 and g.current_step() in [Mtg.Step.DECLARE_BLOCKERS,
			Mtg.Step.FIRST_STRIKE_DAMAGE, Mtg.Step.COMBAT_DAMAGE] \
			and not g.game_over and guard < 80:
		if g.priority_player == 0:
			lines.append(ai.act(g))
		else:
			assert_ok(g.pass_priority(1))
		guard += 1
	assert_lt(guard, 80)
	return lines


func _spent(lines: Array, name: String) -> int:
	var n := 0
	for line in lines:
		if String(line).contains("activated %s" % name):
			n += 1
	return n


# ------------------------------------------------- the division of damage --

## The study's seed 98154: the Knight's two first-strike points kill ONE
## Feeder; the other strikes back. Both cashed out and the Knight lived.
func test_two_spikes_double_blocking_a_first_striker_keep_the_kill() -> void:
	var ai := _ai()
	var a := _spike("Spike Feeder", 2)
	var b := _spike("Spike Feeder", 2)
	_lands("Forest", 4)
	var knight := put_battlefield(1, "Youthful Knight")
	_their_attack([knight.id], {a.id: knight.id, b.id: knight.id})
	_fight(ai)
	assert_eq(knight.zone, Mtg.Zone.GRAVEYARD, "the surviving Feeder struck back")
	assert_true(a.zone == Mtg.Zone.BATTLEFIELD or b.zone == Mtg.Zone.BATTLEFIELD,
		"two points of first strike kill one Feeder, not two")


## The study's seed 98110: a Feeder trading with a 2/2 cashed out its
## counters for life and the 2/2 lived.
func test_a_spike_trading_with_its_attacker_keeps_its_counters() -> void:
	var ai := _ai()
	var feeder := _spike("Spike Feeder", 2)
	_lands("Forest", 4)
	var bears := put_battlefield(1, "Grizzly Bears")
	_their_attack([bears.id], {feeder.id: bears.id})
	var lines := _fight(ai)
	assert_eq(_spent(lines, "Spike Feeder"), 0, "the counters are the damage")
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the trade happened")
	assert_eq(g.players[0].life, 20)


## A doomed Spike spends the counters its kill does not need, and keeps
## the last one: a 3/3 Feeder blocking a 4/1 dies whatever it does, and
## one point of damage still kills the 4/1.
func test_a_doomed_spike_spends_only_what_its_kill_does_not_need() -> void:
	var ai := _ai()
	var feeder := _spike("Spike Feeder", 3)
	var bears := put_battlefield(0, "Grizzly Bears")
	_lands("Forest", 4)
	var elemental := put_battlefield(1, "Lightning Elemental")
	_their_attack([elemental.id], {feeder.id: elemental.id})
	var lines := _fight(ai)
	var bought: int = int(bears.counters.get("+1/+1", 0)) + (g.players[0].life - 20) / 2
	assert_eq(_spent(lines, "Spike Feeder"), 2, str(lines))
	assert_eq(bought, 2, "two counters' worth landed on the Bears or as life")
	assert_eq(elemental.zone, Mtg.Zone.GRAVEYARD, "the last counter was the kill")
	assert_eq(feeder.zone, Mtg.Zone.GRAVEYARD)


## Where the kill is impossible the counters still buy what they can
## (the policy the fix must not lose): a 2/2 Feeder in front of a Craw
## Wurm moves both of its counters to the Bears before it dies.
func test_a_spike_that_cannot_kill_still_cashes_out() -> void:
	var ai := _ai()
	var feeder := _spike("Spike Feeder", 2)
	var bears := put_battlefield(0, "Grizzly Bears")
	_lands("Forest", 4)
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id], {feeder.id: wurm.id})
	var lines := _fight(ai)
	assert_eq(_spent(lines, "Spike Feeder"), 2, str(lines))
	assert_eq(int(bears.counters.get("+1/+1", 0)) + (g.players[0].life - 20) / 2, 2)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)


## Spike Soldier's "+2/+2 until end of turn" is a counter that grows the
## body: a 3/3 Soldier in front of a 6/4 Craw Wurm pumps into a 4/4 that
## kills it (it was left unread: the Soldier died without a kill).
func test_spike_soldier_pumps_into_the_kill() -> void:
	var ai := _ai()
	var soldier := _spike("Spike Soldier", 3)
	_lands("Forest", 4)
	var wurm := put_battlefield(1, "Craw Wurm")
	_their_attack([wurm.id], {soldier.id: wurm.id})
	var lines := _fight(ai)
	assert_gt(_spent(lines, "Spike Soldier"), 0, str(lines))
	assert_eq(wurm.zone, Mtg.Zone.GRAVEYARD)


# -------------------------------------------------------- the null arm --

func test_the_null_arm_spends_nothing_in_combat() -> void:
	var ai := _ai(false)
	var a := _spike("Spike Feeder", 2)
	var b := _spike("Spike Feeder", 2)
	_lands("Forest", 4)
	var knight := put_battlefield(1, "Youthful Knight")
	_their_attack([knight.id], {a.id: knight.id, b.id: knight.id})
	var lines := _fight(ai)
	assert_eq(_spent(lines, "Spike Feeder"), 0)
	assert_eq(g.players[0].life, 20)


# ------------------------------------------------- hidden information --

func test_the_combat_reading_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		var feeder := _spike("Spike Feeder", 3)
		put_battlefield(0, "Grizzly Bears")
		_lands("Forest", 4)
		var elemental := put_battlefield(1, "Lightning Elemental")
		give_hand(1, "Giant Growth" if variant == 0 else "Terror")
		g.players[1].library.reverse()
		_their_attack([elemental.id], {feeder.id: elemental.id})
		answers.append(str(_fight(ai)))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
