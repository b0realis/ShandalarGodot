extends GameTest
## THE SWEEP THAT ANSWERS AN ATTACK (2026-09-08, The Deck's third pass).
## Black-Red Raiders game 10 of the census, turn 16: The Deck at three
## life, Nevinyrral's Disk untapped beside The Abyss, a Tome, a Scepter,
## a Tower, two Moxen and a Sol Ring, three creatures across the table
## with five power between them. The Disk was priced at theirs minus
## ours on the Evaluator's scale — eleven against sixteen — and the
## pilot took the five (docs/ROADMAP.md, "The Deck, third pass").
##
## Two readings under one knob, [member AiProfile.times_sweeps]: the
## damage their creatures would push through our blockers is counted
## before and after the sweep — a creature an Abyss will eat at their
## upkeep never attacking ([method AiPlayer._upkeep_meals]) — and the
## relief priced at the reaper's rate, lethal-worth when the sweep is
## the out ([method AiPlayer._sweep_relief]); and a sweeper that can be
## activated is offered in THEIR combat, once the attackers are declared
## and before the damage ([constant AiPlayer.Moment.COMBAT]). The
## sweeper's own body counts as a loss under the knob as without it: the
## first cut left it out and the measurement caught a Disk going off at
## twenty life to kill a lone 3/3. Each behaviour is pinned twice: with
## the knob and without it.


func _ai(profile: AiProfile, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile)
	g.set_agent(seat, ai)
	return ai


func _on() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.times_sweeps = true
	return profile


func _off() -> AiProfile:
	var profile := AiProfile.wizard()
	profile.times_sweeps = false
	return profile


func _lands(seat: int, land_name: String, count: int) -> void:
	for _i in count:
		put_battlefield(seat, land_name)


## An untapped Disk of ours (the setup shortcut skips its enters-tapped).
func _disk() -> CardInstance:
	var disk := put_battlefield(0, "Nevinyrral's Disk")
	disk.tapped = false
	return disk


## The Disk's own sweep effect, for pricing it directly.
func _disk_effect(disk: CardInstance) -> EffectBase:
	return disk.cur_activated_abilities[0].effects[0]


## The census board: our engines on the table, their three creatures.
func _the_census_board() -> CardInstance:
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	put_battlefield(1, "Erg Raiders")
	put_battlefield(1, "Scathe Zombies")
	put_battlefield(1, "Drudge Skeletons")
	return disk


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400, "never reached the opponent's %s" % Mtg.step_name(step))
	assert_eq(g.priority_player, 1, "the active player gets priority first")
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
	assert_eq(g.current_step(), Mtg.Step.DECLARE_ATTACKERS)
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# --------------------------------------------- the out, in our own main --

func test_the_disk_is_the_out_at_three_life() -> void:
	# The census board at three life: eleven of theirs against sixteen
	# of ours on the Evaluator's scale, five power coming. The relief is
	# the whole game, and the Disk goes off in our own main phase.
	var ai := _ai(_on())
	var disk := _the_census_board()
	_lands(0, "Island", 1)
	g.players[0].life = 3
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[1].battlefield.size(), 0, "their board is gone")


func test_off_the_disk_is_priced_as_a_trade_of_permanents() -> void:
	var ai := _ai(_off())
	var disk := _the_census_board()
	_lands(0, "Island", 1)
	g.players[0].life = 3
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass", "eleven against sixteen: not worth it, at three life")
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(disk.tapped)


# ------------------------------------------------- the Disk at their attack --

func test_the_disk_answers_the_attack_before_the_damage() -> void:
	# At their upkeep one Zombies is not worth our four engines; by the
	# attack they have two more bodies and four power on the way. The
	# Disk fires in the declare-attackers step, and the damage never
	# lands.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Ivory Tower")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Island", 2)
	var zombies := put_battlefield(1, "Scathe Zombies")
	_their_turn_at(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass", "one Zombies is not worth the engines")
	assert_false(disk.tapped)
	var raiders := put_battlefield(1, "Erg Raiders")
	var serra := put_battlefield(1, "Serra Angel", true)   # cast this turn: sick
	_their_attack([zombies.id, raiders.id])
	assert_eq(ai.act(g), "activated Nevinyrral's Disk")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(zombies.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(raiders.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD, "the body cast precombat dies too")
	advance_to_step(Mtg.Step.END)
	assert_eq(g.players[0].life, 20, "no damage landed")


func test_off_the_disk_waits_for_their_end_step_and_takes_the_hit() -> void:
	var ai := _ai(_off())
	var disk := _disk()
	put_battlefield(0, "Ivory Tower")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Island", 2)
	var zombies := put_battlefield(1, "Scathe Zombies")
	_their_turn_at(Mtg.Step.UPKEEP)
	assert_eq(ai.act(g), "pass")
	var raiders := put_battlefield(1, "Erg Raiders")
	put_battlefield(1, "Serra Angel", true)
	_their_attack([zombies.id, raiders.id])
	assert_eq(ai.act(g), "pass", "their combat is no moment of the null's")
	assert_false(disk.tapped)
	_their_turn_at(Mtg.Step.END)
	assert_eq(g.players[0].life, 16, "the four landed first")
	assert_eq(ai.act(g), "activated Nevinyrral's Disk", "the sink fires it after the fact")


func test_a_fog_already_cast_leaves_nothing_to_relieve() -> void:
	# Their lone Zombies attacks into our two life: the Disk is the out
	# and fires — unless the damage is already prevented, in which case
	# the relief is nothing, one Zombies is under the engines, and the
	# Disk is held.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	_lands(0, "Island", 2)
	g.players[0].life = 2
	var zombies := put_battlefield(1, "Scathe Zombies")
	_their_attack([zombies.id])
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 2.0 * 2.0 + AiPlayer.LETHAL_WORTH, 0.001,
		"with the damage coming, the out")
	g.combat_damage_prevented = true
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 0.0, 0.001)
	assert_eq(ai.act(g), "pass")
	assert_false(disk.tapped)


func test_their_combat_offers_nothing_but_a_sweeper() -> void:
	# A Tome and four open Islands in their declare-attackers step: the
	# moment is a sweeper's and nobody else's, so no draw is bought.
	var ai := _ai(_on())
	var tome := put_battlefield(0, "Jayemdae Tome")
	_lands(0, "Island", 4)
	var zombies := put_battlefield(1, "Scathe Zombies")
	_their_attack([zombies.id])
	assert_eq(ai.act(g), "pass")
	assert_false(tome.tapped)


func test_the_disk_fires_on_the_unblocked_remainder() -> void:
	# Blocks in: our Wall of Stone takes the Raiders, the Zombies and a
	# Serra come through for six at our seven life. The relief is
	# lethal-worth once the blocks are known, and the Disk fires in the
	# declare-blockers step.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	var wall := put_battlefield(0, "Wall of Stone")
	_lands(0, "Island", 2)
	g.players[0].life = 7
	var zombies := put_battlefield(1, "Scathe Zombies")
	var raiders := put_battlefield(1, "Erg Raiders")
	var serra := put_battlefield(1, "Serra Angel")
	_their_attack([zombies.id, raiders.id, serra.id])
	# Pass through the declaration; declare the one block ourselves.
	assert_ok(g.pass_priority(0))
	assert_true(g.awaiting_blockers)
	assert_ok(g.declare_blockers(0, {wall.id: raiders.id}))
	assert_eq(g.current_step(), Mtg.Step.DECLARE_BLOCKERS)
	if g.priority_player == 1:
		assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	assert_eq(ai.act(g), "activated Nevinyrral's Disk")
	resolve_stack()
	assert_eq(disk.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(serra.zone, Mtg.Zone.GRAVEYARD)


# --------------------------------------------------------- the numbers --

func test_the_sweepers_own_body_is_a_loss() -> void:
	# No creatures anywhere: the Disk's value is what dies, its own 3.2
	# among the losses (times W_BOARD). The first cut of the knob left
	# the sweeper out of its own sum as "the activation's price"; the
	# measurement found the Disk going off at twenty life to kill a lone
	# 3/3 with a Sol Ring and a Mox, and the reading went.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Jayemdae Tome")          # 3.2
	put_battlefield(1, "Disrupting Scepter")     # 2.4
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_value(g, effect, 0),
		(2.4 - 3.2 - 3.2) * Evaluator.W_BOARD, 0.001)


func test_off_the_body_counts_the_same() -> void:
	var ai := _ai(_off())
	var disk := _disk()
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(1, "Disrupting Scepter")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_value(g, effect, 0),
		(2.4 - 3.2 - 3.2) * Evaluator.W_BOARD, 0.001)


func test_the_relief_is_the_damage_through_our_blockers() -> void:
	# Their two Bears against our one Wall of Stone: one Bears is
	# blocked, two damage comes through, and the sweep relieves it at
	# half a point a life (twenty life). The board trade itself is the
	# two Bears (8) less the Wall (0/8 Defender: 7): one point, doubled.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Wall of Stone")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 2.0 * 0.5, 0.001)
	assert_almost_eq(ai._sweep_value(g, effect, 0),
		(8.0 - 7.0 - 3.2) * Evaluator.W_BOARD + 1.0, 0.001, "the trade, the Disk, the relief")


func test_off_there_is_no_relief() -> void:
	var ai := _ai(_off())
	var disk := _disk()
	put_battlefield(0, "Wall of Stone")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_value(g, effect, 0),
		(8.0 - 7.0 - 3.2) * Evaluator.W_BOARD, 0.001, "the Bears, the Wall, and the Disk")


func test_the_relief_is_lethal_worth_when_the_sweep_is_the_out() -> void:
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 4
	var effect := _disk_effect(disk)
	# Four coming at four life, two a point (under seven), and the out.
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0 * 2.0 + AiPlayer.LETHAL_WORTH, 0.001)
	g.players[0].life = 5
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0 * 2.0, 0.001, "four at five is not the out")


func test_the_relief_honours_our_moat() -> void:
	# Under our Moat their ground creatures cannot attack next turn, so
	# there is nothing to relieve — and a Disk would take the Moat with it.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "Moat")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Birds of Paradise")   # over the Moat, but no power
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 0.0, 0.001)
	put_battlefield(1, "Serra Angel")
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0 * 0.5, 0.001, "the Angel flies over it")


func test_the_relief_counts_the_survivors_of_an_earthquake() -> void:
	# Earthquake for two: their Bears die, their Hill Giant (3/3) lives
	# and still swings for three. Relief is the Bears' two.
	var ai := _ai(_on())
	var quake := give_hand(0, "Earthquake")
	var effect: EffectBase = quake.data.spell_effects[0]
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	assert_almost_eq(ai._sweep_relief(g, effect, 2), 2.0 * 0.5, 0.001)
	assert_almost_eq(ai._sweep_relief(g, effect, 3), 5.0 * 0.5, 0.001, "for three, everything")


# ------------------------------------------------------- the appetite --

func test_the_relief_honours_the_abyss() -> void:
	# Our Abyss takes their least valuable creature at their upkeep
	# before it can attack: the Bears go, the Angel swings for four, and
	# four is what a Disk relieves — not six.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0 * 0.5, 0.001)


func test_a_creature_the_abyss_will_eat_is_no_reason_to_fire() -> void:
	# Big Green, game 1 of the census, turn 37: The Deck at one life on
	# their end step, two Tomes, two Scepters, a Sol Ring and the Abyss
	# on the table against a lone Llanowar Elves. The first cut read the
	# Elves as lethal next turn and wiped its own board to kill it; the
	# Abyss would have eaten the Elves at their upkeep. Nothing to
	# relieve, the Disk stays home.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Jayemdae Tome")
	put_battlefield(0, "Disrupting Scepter")
	put_battlefield(0, "Disrupting Scepter")
	put_battlefield(0, "Sol Ring")
	_lands(0, "Island", 2)
	_their_turn_at(Mtg.Step.END)
	# The Elves land after the walk: their upkeep has passed, the Abyss
	# has not eaten yet this turn, and the next meal is theirs.
	var elves := put_battlefield(1, "Llanowar Elves")
	g.players[0].life = 1
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 0.0, 0.001, "the Elves never attack")
	assert_eq(ai.act(g), "activated Jayemdae Tome", "the end-step draw, not the wipe")
	assert_eq(disk.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(elves.zone, Mtg.Zone.BATTLEFIELD)


func test_the_disk_takes_the_appetite_with_the_board() -> void:
	# The board as it stands: the Abyss eats the Bears, the Angel and
	# the Giant attack for seven. What the Disk leaves: nothing, Abyss
	# included — so its relief is the full seven, not seven less a meal
	# the dead Abyss would have taken.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Hill Giant")
	put_battlefield(1, "Serra Angel")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 7.0 * 0.5, 0.001)


func test_the_appetite_survives_an_earthquake() -> void:
	# Earthquake for two under our Abyss: as it stands the Abyss takes
	# the Bears and the Angel attacks for four; after the quake the Bears
	# are dead, the Abyss is not, and it takes the Angel instead — no
	# attack at all. Relief: the Angel's four.
	var ai := _ai(_on())
	var quake := give_hand(0, "Earthquake")
	var effect: EffectBase = quake.data.spell_effects[0]
	put_battlefield(0, "The Abyss")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	assert_almost_eq(ai._sweep_relief(g, effect, 2), 4.0 * 0.5, 0.001)


func test_the_appetite_is_the_least_valuable_legal_creature() -> void:
	# An artifact creature is no meal for the Abyss (the reason every
	# Abyss deck of the era ran Su-Chi): their Clay Statue is not on the
	# menu, the Bears are, and the Statue attacks for three.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(0, "The Abyss")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Clay Statue")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 3.0 * 0.5, 0.001)


func test_their_own_abyss_eats_their_creatures_too() -> void:
	# The Abyss is theirs: it still takes one of their creatures at
	# their upkeep, and the relief reads the same.
	var ai := _ai(_on())
	var disk := _disk()
	put_battlefield(1, "The Abyss")
	put_battlefield(1, "Grizzly Bears")
	put_battlefield(1, "Serra Angel")
	var effect := _disk_effect(disk)
	assert_almost_eq(ai._sweep_relief(g, effect, 0), 4.0 * 0.5, 0.001)


func test_the_card_declares_its_appetite() -> void:
	# The AI reads no card name: The Abyss's trigger carries the spec of
	# what it eats, and a Serra Angel's triggers carry none.
	var abyss := put_battlefield(0, "The Abyss")
	var serra := put_battlefield(1, "Serra Angel")
	assert_eq(abyss.cur_triggered_abilities.size(), 1)
	assert_not_null(abyss.cur_triggered_abilities[0].kills_each_upkeep)
	for ability in serra.cur_triggered_abilities:
		assert_null(ability.kills_each_upkeep)


# ---------------------------------------------- the spell-side sweeper --

func test_the_wrath_is_the_out_at_four_life() -> void:
	# White Knights' own board wipe: our Serra and a Knight (15) against
	# their four Bears (16) is a two-point trade, under the bar — but at
	# four life with two Bears unblockable by count, the Wrath is the
	# game, and is cast.
	var ai := _ai(_on())
	give_hand(0, "Wrath of God")
	_lands(0, "Plains", 4)
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "White Knight")
	for _i in 4:
		put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "cast Wrath of God")


func test_off_the_wrath_is_a_two_point_trade_and_waits() -> void:
	var ai := _ai(_off())
	give_hand(0, "Wrath of God")
	_lands(0, "Plains", 4)
	put_battlefield(0, "Serra Angel")
	put_battlefield(0, "White Knight")
	for _i in 4:
		put_battlefield(1, "Grizzly Bears")
	g.players[0].life = 4
	advance_to_step(Mtg.Step.MAIN1)
	assert_eq(ai.act(g), "pass")
	assert_not_null(g.find_in_hand(0, "Wrath of God"))


# ------------------------------------------------------------- the ladder --

func test_the_ladder() -> void:
	assert_false(AiProfile.apprentice().times_sweeps)
	assert_false(AiProfile.magician().times_sweeps)
	assert_true(AiProfile.sorcerer().times_sweeps)
	assert_true(AiProfile.wizard().times_sweeps)


func test_the_override() -> void:
	var profile := AiProfile.wizard()
	assert_eq(profile.apply_overrides("times_sweeps=off"), "")
	assert_false(profile.times_sweeps)
	assert_eq(profile.apply_overrides("times_sweeps=on"), "")
	assert_true(profile.times_sweeps)
