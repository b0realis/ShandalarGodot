class_name DuelOpening
extends RefCounted
## EVERYTHING BETWEEN `Go!` AND TURN 1 THAT IS NOT A WINDOW — the one place
## a [DuelConfig] becomes a dealt [MtgGame], shared by the duel screen
## ([method DuelScreen._new_game]) and the headless duel ([HeadlessDuel]),
## so a test of an adventure duel runs the very setup the player's duel
## runs. Moved here out of the duel screen as it stood (part B, W2,
## 2026-10-23), in the same order, with the adventure's own steps added:
##
##   1. [method prepare] — the libraries built and shuffled on the duel's
##      seed, the printings, the seed and challenge lines, THE STAKES
##      ([method stake]), THE ARRANGEMENTS the start of turn 1 runs
##      ([method arrange]) and the rules forks;
##   2. the seats' agents — the caller's (a human seat's mailbox, an AI);
##   3. [method first_seat] — who STARTS when the config says so
##      (`DuelConfig.first_player`), else the toss winner, on the game's
##      rng;
##   4. `MtgGame.deal_opening_hands(7)`, then the opening hand
##      ([OpeningHand]) or, with no window, [method first_without_windows],
##      and `MtgGame.start_duel`.
##
## A config that asks for none of the adventure's steps
## ([method DuelConfig.adventure_opening] false) spends no rng draw and
## moves no card it did not before: every other duel is dealt exactly as
## it was.
##
## ## DESIGNED, NEVER USED
## Three openings 1997's `play_duel` computed and then threw away
## (`duel.c:2289-2325`, `:2502-2511`; the same in retail, `Kimpic.c`
## 19750-19751). Dead in 1997, dead here (the owner's ruling: "Dead 1997
## code stays dead"); each would live in this file.
##  - THE CREATURE'S HAND BY STRENGTH. `opening_hand_count = clamp(B + d +
##    4, 0, 99)` — the creature's BASE strength B (1–3,
##    world_lair_monster_encounter.c 1557, not the strength with the tier)
##    plus the difficulty d plus four — plus the meeting's modifier
##    (`−clamp(3 − W/3, 0, 3)`, W the adventurer's wins), never below three,
##    was dealt to the CREATURE (the adventurer always drew seven); the next
##    line overwrites it with 7. It would have made creatures start short on
##    the easy levels and long on the hard ones (a Witch, B 2, at Apprentice
##    with few wins: 2 + 0 + 4 − 3 = three cards; a Nether Fiend, B 2, at
##    Sorcerer: eight, five to eight with the modifier) — the whole
##    difficulty curve in the opening hand (`g_hand_count_adjustment`,
##    seven less that size, is what the discard and land-play checks
##    would have read; `duel.c:1406`, `duel_ai.c:470`). To switch it on: a
##    `DuelConfig` field for seat 1's opening size, dealt in place of the
##    seven in [method DuelScreen._new_game] / [HeadlessDuel] (the engine's
##    `deal_opening_hands` deals one size to both today).
##  - THE FIRST MOVE BY DIFFICULTY. `starting_player` was pre-picked — the
##    adventurer at Apprentice, a coin of its own above — and handed to
##    `coin_flip`, which ignores it and flips `rand() % 2`. It would have
##    given an Apprentice the toss every duel. To switch it on:
##    [method first_seat] returning the pre-pick (or using it to weight
##    the toss) for an adventure config.
##  - THE ADVENTURER MOVING FIRST WHEN THE CREATURE STARTS WITH A CARD IN
##    PLAY. Putting the creature's card into play set `g_next_duel_card_id`
##    to 0 — "the adventurer moves first" — after the first player had
##    already been decided (`:2315-2325`), and the reset after every duel
##    (`visitLocation.c:2196-2231`) wiped it before any duel could read it.
##    It would have paid for the creature's head start with the first turn.
##    To switch it on: the adventure sets `DuelConfig.first_player = 0`
##    whenever seat 1's `start_in_play` is not empty.


## Steps 1: [param game] set up from [param config] on [param duel_seed],
## played for ante as the config says, its opening arranged, its rules
## forks set from the player's Options — the order the duel screen always
## had. The game's signals should be connected before this (the running
## log's first line is the engine's "Game set up").
static func prepare(game: MtgGame, config: DuelConfig, duel_seed: int) -> void:
	game.setup(config.decks[0], config.decks[1],
		config.seat_name(0), config.seat_name(1),
		config.lives[0], config.lives[1], duel_seed)
	CardPrintings.apply_game(game, config.printings)
	game.log_line("Duel seed: %d" % duel_seed)
	if config.challenge_label() != "": game.log_line(config.challenge_label())
	stake(game, config)
	arrange(game, config)
	# The RULES FORKS, per Options (see RulesOptions / Settings.rule).
	# Logged by preset name when any of them leaves plain modern, so a
	# bug report says which ruleset the duel was actually played under.
	# An adventure duel plays the player's own rules too (the PLAN's lead
	# defaults: "the player's own rules options apply to adventure duels").
	for fork in RulesOptions.FORKS:
		game.rules.set_fork(fork["key"], Settings.rule(fork["key"]))
	var preset: String = game.rules.preset()
	if preset != "modern":
		game.log_line("Rules: %s" % RulesOptions.preset_label(preset))


## THE ANTE (§6.19) — the original's `&Ante` match parameter. Staked
## between the shuffle and the deal, because that is the manual's own
## order: p.60 *"Before the duel begins, both players put up one or more
## cards from their decks as ante"*, and p.118 pins it precisely by
## describing the minimum-deck padding as lands added *"(after the ante but
## before the shuffle)"*.
##
## AN ADVENTURE DUEL NAMES ITS STAKES (part B, W2;
## [method DuelConfig.plays_named_ante]): each seat's
## `DuelConfig.ante_cards` lifted out of its library, then its
## `DuelConfig.ante_extras` made straight into its ante, the adventurer's
## first. Otherwise the random count: the player's stake spares BASIC lands
## and the opponent's does not — Shandalar's own asymmetry (FAQ 1.9,
## *"Basic lands are too weak a card to ante"*), and exactly what the
## owner's 1997 screenshot shows: your Animate Dead against Cromer's
## Mountain.
static func stake(game: MtgGame, config: DuelConfig) -> void:
	if config.plays_named_ante():
		for pid in 2:
			game.stake_named_ante(pid, DuelConfig.seat_names(config.ante_cards, pid))
			var made := game.stake_extra_ante(pid, DuelConfig.seat_names(config.ante_extras, pid))
			_wear_printings(made, config, pid)
		return
	if config.ante > 0:
		for pid in 2:
			game.stake_ante(pid, config.ante, not config.is_ai(pid))


## The adventure's opening rules and what the start of turn 1 runs
## ([method MtgGame.arrange_opening]): 1997's mulligan, Mind Control and
## the cards in play. Nothing for a config that asks for none of them.
static func arrange(game: MtgGame, config: DuelConfig) -> void:
	game.mulligan_rule = config.mulligan_rule
	var in_play := [DuelConfig.seat_names(config.start_in_play, 0),
		DuelConfig.seat_names(config.start_in_play, 1)]
	if config.mirror_seat0 or not (in_play[0] as Array).is_empty() \
			or not (in_play[1] as Array).is_empty():
		game.arrange_opening(config.mirror_seat0, in_play)


## Step 3: the seat that starts when `DuelConfig.first_player` names one —
## no toss, so no rng draw — else THE COIN TOSS (the original's Toss.wav
## moment), rolled on the game's rng and not the global one, so a seeded
## game replays its opening exactly: the leader is part of the game's
## stream. The toss winner then chooses play or draw ([OpeningHand]).
static func first_seat(game: MtgGame, config: DuelConfig) -> int:
	if config.first_player == 0 or config.first_player == 1:
		return config.first_player
	return game.rng.randi() % 2


## Who plays first when no window asks (the duel screen headless — tests
## and CI begin the duel at once, with no mulligan, as they always have):
## the seat [method first_seat] gave — a forced start, or the toss winner
## taking the play — unless the winner is the computer and 1997's random
## choice is asked for (`DuelConfig.ai_random_play_or_draw`,
## [method OpeningHand.ai_chooses_play]).
static func first_without_windows(game: MtgGame, config: DuelConfig, seat: int) -> int:
	if config.first_player < 0 and config.ai_random_play_or_draw and config.is_ai(seat) \
			and not OpeningHand.ai_chooses_play(game):
		return game.opponent_of(seat)
	return seat


## Put the opening hand's options from [param config] on [param opening]
## before it runs: a forced start, 1997's random choice for the computer.
## (1997's mulligan is the game's own `mulligan_rule`, set by [method arrange].)
static func configure(opening: OpeningHand, config: DuelConfig) -> void:
	opening.forced_first = config.first_player == 0 or config.first_player == 1
	opening.ai_random_order = config.ai_random_play_or_draw


## A card made for the ante wears the printing its seat chose for that name,
## as the deck's own cards do ([method CardPrintings.apply_game]).
static func _wear_printings(cards: Array[CardInstance], config: DuelConfig, pid: int) -> void:
	if pid >= config.printings.size() or not config.printings[pid] is Dictionary:
		return
	var chosen: Dictionary = config.printings[pid]
	for card in cards:
		var id: Variant = chosen.get(card.data.card_name, "")
		if DeckPrintings.valid_id(id):
			card.set_meta(CardPrintings.META, id)
