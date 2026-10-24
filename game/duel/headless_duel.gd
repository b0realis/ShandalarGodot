class_name HeadlessDuel
extends RefCounted
## A WHOLE DUEL WITH NO SCREEN — for tests and tools that need a duel
## played to its result (part B, W2, 2026-10-23: the adventure's own tests
## run a creature's duel through this and settle the [DuelReport] it
## returns).
##
## IT IS THE PLAYER'S DUEL, MINUS THE WINDOWS. The game is set up by
## [method DuelOpening.prepare] — the very function the duel screen calls,
## so the stakes, the cards in play, Mind Control, 1997's mulligan and the
## rules forks are the ones the player's duel gets — then the coin toss or
## the forced start ([method DuelOpening.first_seat]), the deal of seven,
## and the opening hand run by [OpeningHand] itself with no seat asking a
## window, which is how its own tests run it. Every seat is then played by
## an [AiPlayer]: an AI seat by its own profile (`DuelConfig.create_ai`), a
## human seat by [param stand_in] (an apprentice when none is given).
##
## USE, from a test (a coroutine — the opening hand is one, though with no
## window it never waits):
## [codeblock]
## var config := DuelConfig.new()
## config.decks = [hero_deck, creature_deck]
## config.pilots = [null, AiProfile.apprentice()]
## config.lives = [3, 4]
## config.rng_seed = 4242                      # same seed, same duel
## config.ante_cards = [["Lightning Bolt"], ["Hill Giant"]]
## config.first_player = 1                     # First Strike
## var report: DuelReport = await HeadlessDuel.play(config)
## assert_true(report.finished, report.describe())
## [/codeblock]
## or in two steps, to look at the table before playing on:
## [codeblock]
## var duel: HeadlessDuel = await HeadlessDuel.begin(config)
## assert_eq(duel.game.turn_number, 1)        # turn 1 has begun
## var report := duel.play_out()
## [/codeblock]
## A short duel is the caller's to make: low [member DuelConfig.lives] (life
## 0 is a loss at once, before anyone acts), small decks, or end it outright
## with `duel.game.concede(seat)` / `duel.game.draw_game(reason)` after
## [method begin].

## The config this duel was dealt from.
var config: DuelConfig
## The duel itself.
var game: MtgGame
## The seed it was dealt on: `DuelConfig.rng_seed`, or one rolled (and
## logged as the screen does) when that is 0.
var duel_seed := 0
## The two seats' players, seat 0 first.
var seats: Array[AiPlayer] = []
## What the opening hand announced, in order — the Situation Bar's lines
## ("Cromer will play first.", "Cromer has no land and chose to take a
## mulligan", ...).
var opening_lines: Array[String] = []


## Set up, deal and open the duel from [param config] — turn 1 has begun
## when this returns. [param stand_in] plays any human seat.
static func begin(config: DuelConfig, stand_in: AiProfile = null) -> HeadlessDuel:
	var out := HeadlessDuel.new()
	out.config = config
	out.game = MtgGame.new()
	out.duel_seed = config.rng_seed if config.rng_seed != 0 else (randi() | 1)
	DuelOpening.prepare(out.game, config, out.duel_seed)
	for pid in 2:
		var seat: AiPlayer = config.create_ai(pid) if config.is_ai(pid) \
			else AiPlayer.new(pid, stand_in if stand_in != null else AiProfile.apprentice())
		out.seats.append(seat)
		out.game.set_agent(pid, seat)
	var first := DuelOpening.first_seat(out.game, config)
	out.game.deal_opening_hands(7)
	var opening := OpeningHand.new()
	DuelOpening.configure(opening, config)
	var lines := out.opening_lines
	opening.announced.connect(func(line: String) -> void: lines.append(line))
	await opening.run(out.game, first, func(_pid: int) -> bool: return false)
	opening.free()
	return out


## Play on until the duel ends — or [param max_steps] AI actions, after
## which the report says it is unfinished — and report it.
func play_out(max_steps := 20000) -> DuelReport:
	if not game.game_over:
		AiPlayer.play_out(game, seats[0], seats[1], max_steps)
	return report()


## The duel's [DuelReport] as it stands now.
func report() -> DuelReport:
	return DuelReport.of(game, config)


## [method begin] and [method play_out] in one: the duel from
## [param config] played to its end, reported.
static func play(config: DuelConfig, stand_in: AiProfile = null, max_steps := 20000) -> DuelReport:
	var duel: HeadlessDuel = await begin(config, stand_in)
	return duel.play_out(max_steps)
