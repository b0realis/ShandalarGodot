extends GameTest
## THE DISK DEFERRAL (2026-09-10, [member AiProfile.times_sweeps]; the
## third pass's open row, `docs/AI-next-wave.md` wave 3).
##
## `times_sweeps` gave the activated sweeper a MOMENT — the opponent's
## combat, the attackers declared and the damage still to come, the Disk
## as a Fog — but only as an ADDITION. Our own main phase went on
## offering the same activation at its own bar, and [method
## AiPlayer._sweep_value] carries a relief read off an attack that has
## not happened, so a Disk worth firing at home still fired at home.
## Reproduced with a headless probe before a line was written: a Disk and
## two Jayemdae Tomes of ours against three Grizzly Bears, nothing else
## on the table — `activated Nevinyrral's Disk` in our own first main
## phase, both Tomes in the graveyard, on a turn where waiting cost
## nothing at all.
##
## THE DEFERRAL IS THE RELIEF READ ONE PHASE EARLIER ([method
## AiPlayer._defers_sweep]): while a creature of theirs COULD attack us,
## their combat is a strictly better moment for the same activation and
## the sweeper waits for it — in our main phase and at their upkeep
## alike, both of which are earlier than the combat. A board that cannot
## attack has no combat to wait for, so the sweeper is not made to wait
## on a moment that is never offered; a sweep that WINS is never
## deferred; and a printed timing rider that would refuse their combat
## ends the wait too.
##
## AND THE "AFTER" BOARD APPLIES THE STATICS THE SWEEP REMOVES ([method
## AiPlayer._ground_the_sweep_opens]). [method AiPlayer._sweep_relief]
## built its after-board out of the survivors and then asked [method
## AiPlayer._could_attack_next_turn] of them — a question answered off
## the board as it STANDS, Moat and all. Probed at HEAD: at two life,
## with a Moat and a Disk of ours against a Serra Angel and a
## regenerating 2/2, the relief came back 1008.00 — the Angel's four
## priced as lethal plus [constant AiPlayer.LETHAL_WORTH] for a sweep
## that "is the out" — while the 2/2 the Disk does not kill (its printed
## line carries no clause against regeneration) walks in for two the
## moment the Moat is gone. It reads 4.00 now, and the seat does not blow
## its own Moat to lose anyway.
##
## Every behaviour is pinned on BOTH arms of the knob. With
## `times_sweeps` off the pilot does exactly what it did at HEAD, which
## is the null.


func _ai(sweeps: bool, seat := 0) -> AiPlayer:
	var profile := AiProfile.wizard()
	profile.times_sweeps = sweeps
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## An untapped Disk of ours (the setup shortcut skips its enters-tapped).
func _disk() -> CardInstance:
	var disk := put_battlefield(0, "Nevinyrral's Disk")
	disk.tapped = false
	return disk


func _disk_effect(disk: CardInstance) -> EffectBase:
	return disk.cur_activated_abilities[0].effects[0]


## Walk to the opponent's [param step] and hand seat 0 priority there.
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## Walk their turn to the attack declaration, declare [param attackers],
## and hand seat 0 priority in the declare-attackers step.
func _their_attack(attackers: Array) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_true(g.awaiting_attackers, "reached their declaration")
	assert_ok(g.declare_attackers(1, attackers))
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


## The probe's board: a Disk and two Tomes of ours, three bears of theirs.
func _the_probe_board() -> Array:
	var disk := _disk()
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 3)
	var bears: Array = []
	for _i in 3:
		bears.append(put_battlefield(1, "Grizzly Bears"))
	return [disk, bears]


# ------------------------------------------------------- the reproduction --

func test_the_disk_no_longer_fires_at_home() -> void:
	var ai := _ai(true)
	var board := _the_probe_board()
	var disk: CardInstance = board[0]
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "their combat is the moment, not ours")
	assert_false(disk.tapped)
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)


func test_off_the_disk_still_fires_at_home() -> void:
	# THE NULL, and it is the whole of it: the knob that offers the later
	# moment is the knob that may defer to it.
	var ai := _ai(false)
	var board := _the_probe_board()
	var disk: CardInstance = board[0]
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)


func test_the_deferred_disk_goes_off_when_they_swing() -> void:
	var ai := _ai(true)
	var board := _the_probe_board()
	var disk: CardInstance = board[0]
	var bears: Array = board[1]
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	# Their upkeep is EARLIER than their combat, so the wait holds there
	# too — the first cut of this deferred the main phase and watched the
	# Disk go off at the upkeep instead.
	_their_turn_at(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass", "their upkeep is one phase earlier, not later")
	assert_false(disk.tapped)
	var ids: Array = []
	for bear in bears:
		ids.append(bear.id)
	_their_attack(ids)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk",
		"and the declared attack is what it was waiting for")
	resolve_stack()
	for bear in bears:
		assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[0].life, 20, "no damage landed")


# ------------------------------------------------------- what ends the wait --

func test_a_sweep_that_wins_is_never_deferred() -> void:
	# The census board at three life: the relief is the whole game, so
	# the Disk goes off in our own main phase. The hold and the deferral
	# answer to the same lethal.
	var ai := _ai(true)
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Island", 1)
	put_battlefield(1, "Erg Raiders")
	put_battlefield(1, "Scathe Zombies")
	put_battlefield(1, "Drudge Skeletons")
	g.players[0].life = 3
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk",
		"a sweep that is the out waits for nothing")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)


func test_a_board_that_cannot_attack_is_no_reason_to_wait() -> void:
	# Our own Moat against three Craw Wurms: the ground is already held,
	# so there is no combat to defer to and the Disk fires at home — on
	# both arms, and for the same reason.
	for sweeps in [true, false]:
		before_each()
		var ai := _ai(sweeps)
		var disk := _disk()
		put_battlefield(0, "Moat")
		_lands(0, "Island", 3)
		for _i in 3:
			put_battlefield(1, "Craw Wurm")
		advance_to_step(Mtg.Step.MAIN1)
		assert_eq(ai.act(g), "activated Nevinyrral's Disk",
			"times_sweeps=%s: a combat that never comes is no moment" % str(sweeps))
		resolve_stack()
		assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)


func test_a_wall_of_theirs_is_not_a_combat_to_wait_for() -> void:
	var ai := _ai(true)
	_disk()
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 3)
	for _i in 4:
		put_battlefield(1, "Wall of Stone")
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk", "walls do not attack")


func test_the_deferral_is_a_reading_and_not_a_ban() -> void:
	# Asked directly, at each moment the ability scorer has.
	var ai := _ai(true)
	var board := _the_probe_board()
	var disk: CardInstance = board[0]
	var ability: ActivatedAbility = disk.cur_activated_abilities[0]
	advance_to_step(Mtg.Step.MAIN1)
	assert_true(ai._defers_sweep(g, disk, ability, _disk_effect(disk),
		AiPlayer.Moment.MAIN))
	assert_false(ai._defers_sweep(g, disk, ability, _disk_effect(disk),
		AiPlayer.Moment.COMBAT), "their combat is the moment it waits FOR")
	assert_false(ai._defers_sweep(g, disk, ability, _disk_effect(disk),
		AiPlayer.Moment.SINK), "their end step is after the combat, not before")

	var off := AiPlayer.new(0, AiProfile.wizard())
	off.profile.times_sweeps = false
	assert_false(off._defers_sweep(g, disk, ability, _disk_effect(disk),
		AiPlayer.Moment.MAIN), "no later moment, no deferral")


# ------------------------------------- the statics the sweep takes with it --

## Our Moat and our Disk; their Serra Angel and a 2/2 with a regeneration
## shield up, which the Disk does not kill. The board the note names.
func _the_moat_board() -> Array:
	var disk := _disk()
	put_battlefield(0, "Moat")
	_lands(0, "Island", 3)
	put_battlefield(1, "Serra Angel")
	var troll := put_battlefield(1, "Sedge Troll")
	troll.regeneration_shields = 1   # setup: a shield already paid for
	g.players[0].life = 2
	return [disk, troll]


func test_the_moat_the_disk_takes_no_longer_holds_the_ground() -> void:
	var ai := _ai(true)
	var board := _the_moat_board()
	var disk: CardInstance = board[0]
	var troll: CardInstance = board[1]
	var effect := _disk_effect(disk)
	assert_true(troll.cur_cant_attack, "the Moat grounds it while the Moat is there")
	assert_false(ai._sweep_kills(effect, troll, 0), "and the Disk does not kill it")
	var freed: Array = ai._ground_the_sweep_opens(g, effect, 0)
	assert_eq(freed.size(), 1, "the sweep takes every static on the table")
	assert_eq(freed[0], troll)
	# Two of theirs deal four and two; the sweep leaves the two. At two
	# life that is not an out, and the relief says so.
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0, 0.001,
		"two points relieved at the reaper's rate, and no lethal bonus")


func test_a_static_still_standing_keeps_the_old_reading() -> void:
	# The conservative direction, and it is deliberate: with a second
	# static source alive after the sweep nothing can say which permanent
	# was grounding what, so the board as it stands is what is read.
	var ai := _ai(true)
	var board := _the_moat_board()
	var disk: CardInstance = board[0]
	var ours := put_battlefield(0, "Sedge Troll")
	ours.regeneration_shields = 1
	assert_false(ai._sweep_kills(_disk_effect(disk), ours, 0))
	assert_eq(ai._ground_the_sweep_opens(g, _disk_effect(disk), 0).size(), 0,
		"something that could be grounding them is still there")
	assert_almost_eq(ai._sweep_relief(g, _disk_effect(disk), 0),
		8.0 + AiPlayer.LETHAL_WORTH, 0.001, "which is the reading it always made")


func test_a_creature_is_never_counted_against_itself() -> void:
	# Moat is symmetric and the Evil Eye grounds everything but itself:
	# a survivor's OWN static is not what holds it back, so the one
	# static left standing being the creature being asked about does not
	# make the reading conservative.
	var ai := _ai(true)
	var board := _the_moat_board()
	var disk: CardInstance = board[0]
	var troll: CardInstance = board[1]
	assert_true(g.battlefield_with_statics().has(troll),
		"the Sedge Troll carries a static of its own")
	assert_true(ai._ground_the_sweep_opens(g, _disk_effect(disk), 0).has(troll))


func test_the_grounding_read_needs_the_sweep_to_take_the_static() -> void:
	# A Wrath-shaped sweep takes no enchantment, so the Moat stands — and
	# it takes the Troll anyway, which is the other half of the same
	# arithmetic.
	var ai := _ai(true)
	var board := _the_moat_board()
	var troll: CardInstance = board[1]
	var wrath := give_hand(0, "Wrath of God")
	var effect: EffectBase = wrath.data.spell_effects[0]
	assert_true(ai._sweep_kills(effect, troll, 0),
		"a Wrath allows no regeneration, so it takes the Troll too")
	assert_eq(ai._ground_the_sweep_opens(g, effect, 0).size(), 0)


func test_a_defender_is_not_freed_by_the_moat_going_away() -> void:
	var ai := _ai(true)
	var disk := _disk()
	put_battlefield(0, "Moat")
	_lands(0, "Island", 3)
	var wall := put_battlefield(1, "Wall of Stone")
	wall.regeneration_shields = 1
	assert_eq(ai._ground_the_sweep_opens(g, _disk_effect(disk), 0).size(), 0,
		"a wall does not attack whatever happens to the Moat")


# --------------------------------------------------------------- the ladder --

func test_the_rungs_are_the_ones_the_knob_already_had() -> void:
	assert_false(AiProfile.apprentice().times_sweeps)
	assert_false(AiProfile.magician().times_sweeps)
	assert_true(AiProfile.sorcerer().times_sweeps)
	assert_true(AiProfile.wizard().times_sweeps)
