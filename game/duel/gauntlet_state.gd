class_name GauntletState
extends RefCounted
## THE GAUNTLET — the 1997 shell's fourth duel mode, specified by the
## original in nine words of its own: `2&Gauntlet:Defeat as many opponents
## in a row as possible.` (`@SHELLSCREEN_DUEL`,
## `Program/UIStrings.txt:5-11` = `s30/assets/text/Uistrings.txt:5-9`).
##
## THIS CLASS IS THE RUN AND NOTHING ELSE — the opponent order, the round
## counter, the session record and the words. It owns no Node and no
## window, exactly as [MatchState] owns none: a gauntlet is a sequence of
## MATCHES the way a match is a sequence of DUELS, and each layer knows
## only the one below it. [GauntletScreen] owns the windows.
##
## THE LOOP, read out of the decompiled 1997 `DUEL.EXE`. The decompilation
## is Tier 2 (`Provenance.md`), whose rule is to cite the entry-point
## ADDRESS and quote the code — the recovered function NAMES are inferred
## and several are wrong (the one driving the whole gauntlet run is called
## `Pic_Load_004420a1`). Every quotation below is as recorded by the
## survey in `docs/gauntlet-design.md` §1.4 and §1.7; that document is the
## design this file implements.
##
## **How many opponents** — the Gauntlet Startup screen (dialog resource
## `0xe7`, proc at **0x49c2d0**) counts the deck files it can offer, then:
##
##     DAT_005f6288 = <number of .dck files found>;
##     DAT_005f649c = DAT_005f6288;
##     if (0x13 < DAT_005f6288) { DAT_005f649c = 0x14; }   /* cap at 20 */
##
## so a run is `min(decks on disk, 20)` opponents long. The cap is real:
## the shuffle buffer is `int aiStack_54[20]`. [constant MAX_OPPONENTS].
##
## **Which, and in what order** — **0x49e6f9**, called straight after the
## count:
##
##     for (i = 0; i < DAT_005f649c; i++) aiStack_54[i] = i;
##     for (i = 0; i < DAT_005f649c * 10; i++) {      /* 10n random swaps */
##         r = _rand();
##         swap(aiStack_54[i % n], aiStack_54[r % n]);
##     }
##
## **Where the run starts in that order** — **0x49e921**, the opponent's
## `Random deck` branch: `if (gauntlet) { DAT_005f6498 = _rand() % n; }`
## — and the driver at **0x4420a1** picks each round's opponent as
##
##     local_5c = (DAT_005f6498 + DAT_005f6cb0) % DAT_005f649c;
##
## with `DAT_005f6cb0` the 1-based round counter, initialised to 1 beside
## the 20 life totals in the driver's case 0. So the run walks the
## shuffled list from a random offset and WRAPS, the first opponent is
## `start + 1`, and over `n` rounds every deck is met exactly once. That
## arithmetic is reproduced here rather than tidied: see
## [method opponent_index].
##
## DETERMINISM IS LOAD-BEARING HERE, more than anywhere else in this
## project's UI. MicroProse's own patch notes list *"The random selection
## of opponents in the Gauntlet is now fixed."* among three gauntlet fixes
## (the 1997 community FAQ, Dana Huyler v1.2, `s30/shandalar-faq.txt:458-465`)
## — the opponent order is exactly the kind of thing that shipped broken
## and must therefore replay from a seed. [method shuffle] takes a
## [RandomNumberGenerator] and never touches `randi()`, per CONTRIBUTING.md
## rule 7.
##
## WHAT A GAUNTLET IS NOT: a progression mode. There is no collection, no
## purse, no unlocks and no record kept between runs — checked in every
## source (`docs/gauntlet-design.md` §1.6) and none of them is there.
## `You've successfully run the gauntlet!` is the whole reward.

## `aiStack_54[20]` at 0x49e6f9, and the `0x14` cap at 0x49c2d0.
const MAX_OPPONENTS := 20

# ------------------------------------------------------------ the words --
#
# `@GAUNTLET` (`Program/UIStrings.txt:1352-1363` =
# `s30/assets/text/Uistrings.txt:1312-1323`) is ten strings, and every one
# of them is ALSO a hard-coded literal in the decompiled 1997 `DUEL.EXE`
# (0x505a04 … 0x505b10) — the strongest corroboration a string table in
# this project has ever had. The originals carry `\n` runs for the message
# box that concatenates them; those are dropped here exactly as
# [MatchState] drops `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS`'s, because the
# caller lays the window out.

## Entries 1-3: the line about the DUEL just played. One, always.
## (Entry 3 is `\n Oh well... \nThe duel ended in a tie\n\n` — two lines in
## the original's box, one line here.)
const CONGRATULATIONS := "Congratulations!"
const TOO_BAD := "Too bad"
const DUEL_TIED := "Oh well... The duel ended in a tie"

## Entries 4-7, 9-10: the line about the RUN, of which exactly one follows.
const WON_MATCH := "You won the match."
const NEXT_IS := "Your next duel is against %s."
const CONTINUE_Q := "Do you wish to continue?"
const RAN_IT := "You've successfully run the gauntlet!"
const LOST_RUN := "You lost the game."
const CONTINUES := "The match continues..."

## Entry 8, `You've won the duel!`, is the SINGLE-DUEL branch of the same
## driver — the proof that one state machine served both `&Gauntlet` and
## `&Single Duel`. Our single duel has its own End of Duel window
## (`@DIALOG_SHANDALARENDDUEL`), so the string is recorded and unused.
const WON_DUEL := "You've won the duel!"

# `@DIALOG_GAUNTLETENDDUEL` (`Program/UIStrings.txt:520-525`, the same
# lines in s30's copy — the two files are aligned to line 1183), four
# entries, composed by one `sprintf` at `DUEL.EXE` 0x4f7c78 whose format
# is `"%s That was round %d Your record %d/%d/%d"` and whose five
# arguments are the message above, the round, and the session triple.
const ROUND_LINE := "That was round %d"
const RECORD := "Your record is %d/%d/%d"
const NEXT_ROUND := "Next round"
const QUIT := "Quit Gauntlet"

# ------------------------------------------------ the opponent's deck --
#
# `@GAUNTLETERRORS` (`Program/UIStrings.txt:1365-1378` =
# `s30/assets/text/Uistrings.txt:1325-1338`) is twelve strings, of which
# FOUR are about the opponent's deck — the original validates it every
# round, not once at the start, which is why they exist as a group. All
# four are here now (the first was wired when the mode landed; the other
# three arrived with slice 4). Each carries exactly one `%s`, the deck's
# name. [method opponent_deck_problem] is the one place that chooses
# between them.
#
# FIVE MORE ARE ABOUT YOUR OWN DECK (entry 1, `Your selected deck is not
# a legal deck.`, and entries 2-5, `Player's deck %s is invalid.` with its
# three variants, `:1368-1372` = `:1328-1332`), checked ONCE, when `Run
# the gauntlet` is pressed, because that is the one moment the player's
# choice is made. They are the same three tests as the opponent's under
# the other name; [method your_deck_problem] chooses. Until 2026-09-02 a
# deck of yours that failed them was silently REPLACED by the config's
# default deck and the run started anyway — the player picked their
# deck, and played someone else's.

## Entry 8 (`:1374` = `:1334`) — the general refusal: the file will not
## load, or holds no cards this project can play.
const DECK_INVALID := "Opponent's deck %s is invalid."

## Entry 9 (`:1375` = `:1335`). RECORDED AND UNREACHABLE, and this is the
## one place slice 4's design (`docs/gauntlet-design.md` §4) turned out to
## be wrong: it lists *"deck validation per round with `@GAUNTLETERRORS`'
## own words"* as four messages we can produce, and we can produce three.
##
## **Neither deck format this project reads carries a version number.**
## The 1997 `.dck` files themselves are the evidence — all 55 shipped in
## `shandalar-src/Program/decks/` open with a bare name line
## (`Seer (Ub, Type 1)`), a blank line, and then `.<id>\t<count>\t<name>`
## rows, with no version field anywhere; our own `.deck`/`.dec` text has
## none either. The only numbered revision anyone has is Manalink 3's,
## whose `save_deck` writes an eight-line `;`-prefixed header with
## `;%d\n` for `global_deck_revision`
## (`shandalar-src/src/deck/deckdll.cpp:5522-5545`) — Tier 3, a format we
## do not write and the 1997 game never read.
##
## So there is no state of a deck file that could truthfully produce this
## sentence. It is kept, unused, for the same reason [constant WON_DUEL]
## and [constant CONTINUES] are: the group is four strings, and a reader
## who finds three has to go and check whether the fourth was missed or
## judged. It was judged.
const DECK_WRONG_VERSION := "Opponent's deck %s is invalid. Wrong version number."

## Entry 10 (`:1376` = `:1336`). [constant DeckModel.MIN_CARDS] is the
## same forty, from `@TOOFEWCARDS`.
const DECK_TOO_SMALL := "Opponent's deck %s is invalid. Decks must have a minimum of 40 cards."

## Entry 11 (`:1377` = `:1337`), and [constant DeckModel.MAX_UNIQUE] /
## [constant DeckModel.MAX_TOTAL] are the same two numbers.
##
## THE DOUBLE SPACE AFTER `%s` IS THE ORIGINAL'S and is quoted rather than
## tidied: it is in BOTH copies of the table, the Manalink one and s30's
## clean 1997 one, so it is a 1997 typo and not a transcription of ours.
## (Contrast [constant GauntletOptions.BANDS], where a TRAILING space on
## `very hard ` is trimmed and said to be: trailing whitespace cannot be
## seen and carrying it would be superstition, while this one is between
## two words the player reads.) Do not "fix" it.
const DECK_TOO_BIG := "Opponent's deck %s  is invalid. Decks are limited to 200 unique cards / 500 total cards."

## Entry 1 (`:1368` = `:1328`) — the refusal with no deck to name: what
## `<random deck>` earns when not one deck on disk can be played.
const YOUR_DECK_ILLEGAL := "Your selected deck is not a legal deck. Please select a new deck."
## Entry 2 (`:1369` = `:1329`) — your deck's general refusal: the file
## will not load, or holds a card this project cannot play (a proxy under
## a strict load is an error, and a gauntlet cannot deal a proxy).
const YOUR_DECK_INVALID := "Player's deck %s is invalid."
## Entry 4 (`:1371` = `:1331`).
const YOUR_DECK_TOO_SMALL := "Player's deck %s is invalid. Decks must have a minimum of 40 cards."
## Entry 5 (`:1372` = `:1332`). No double space in this one — the typo
## is the opponent's line's alone, in both copies of the table.
const YOUR_DECK_TOO_BIG := "Player's deck %s is invalid. Decks are limited to 200 unique cards / 500 total cards."

# --------------------------------------------- announcing the opponent --
#
# `@DIALOG_STARTEXP1MATCH_GAUNTLET` (`Program/UIStrings.txt:149-153` =
# `s30/assets/text/Uistrings.txt:149-153`; the two copies are aligned to
# line 1183 and these three read identically in both), the line that
# introduces the round's opponent — one of three, chosen by where the
# round falls in the run.
#
# MicroProse's own patch notes list it among three gauntlet fixes: *"The
# Next Opponent screen displays the correct name for the next opponent."*
# (the 1997 community FAQ, Dana Huyler v1.2, `s30/shandalar-faq.txt:458-465`),
# so the announcement is a screen the original had and shipped broken.

## Entry 1 — round 1.
const FIRST_OPPONENT := "Your first opponent in the gauntlet:"
## Entry 2, whose original spelling is
## `You now meet opponent %1!d! (of %2!d!) in the gauntlet:` — the Windows
## POSITIONAL printf the 1997 resource compiler used, where `%1!d!` reads
## "argument 1, formatted `%d`". The arguments are therefore the round and
## the run's length in that order, which is what GDScript's two plain
## `%d`s carry; nothing else about the string changes.
const NTH_OPPONENT := "You now meet opponent %d (of %d) in the gauntlet:"
## Entry 3 — the last round.
const FINAL_OPPONENT := "Your final opponent in the gauntlet:"

## The round window's own heading. The original's dialog `0xf6` carries no
## title string of its own; this is the mode's own name from
## `@SHELLSCREEN_DUEL` entry 4, which is the word the player chose it by.
const TITLE := "Gauntlet"

## The three ways a duel can end, from YOUR side — the three result lines
## above, in the string table's own order.
enum Outcome { WON, LOST, TIED }

# ------------------------------------------------------------- the run --

## The opponents in the order they will be met: deck FILE PATHS, already
## shuffled and already cut to [constant MAX_OPPONENTS] by
## [method shuffle]. `DUEL.EXE` 0x5f6cc0.
var order: Array[String] = []
## Path -> the deck's own name, for `Your next duel is against %s.` Empty
## entries fall back to the file's stem, so a run still names its
## opponents when nobody filled this in.
var names := {}
## Where in [member order] the run begins. `DUEL.EXE` 0x5f6498.
var start := 0
## The current round, 1-BASED as the original's is (`DUEL.EXE` 0x5f6cb0,
## set to 1 in the driver's case 0). Named `round_number` and not `round`
## only because `round()` is a GDScript global and shadowing it warns.
var round_number := 1
## THE SESSION RECORD — duels won / lost / tied across the WHOLE run
## (`DUEL.EXE` 0x5f76c0 / 0x5f6494 / 0x5f67fc). These are NOT the current
## match's tally: that is a second, separate pair (0x5f6c58 / 0x5f67e8)
## which is zeroed every time a match ends while this triple is not.
## [MatchState] is that pair; this is the run's.
var wins := 0
var losses := 0
var ties := 0
## The run has ended and no further match may be played — you lost one,
## you took the last one, or you quit.
var over := false
## True only for the second of those: the run ended by WINNING the final
## match, which is the `You've successfully run the gauntlet!` branch.
var completed := false


## How many opponents this run has.
func length() -> int:
	return order.size()


## The index into [member order] of the round now being played — the
## original's own arithmetic, `(start + round) % n`, with a 1-based round
## added to a 0-based offset (`DUEL.EXE` 0x4420a1). That the first
## opponent is `start + 1` rather than `start` is therefore not an
## off-by-one of ours; it is what the binary does, and since the run walks
## `n` consecutive rounds it meets all `n` decks either way.
## -1 when there is nobody to meet.
func opponent_index() -> int:
	return index_for_round(round_number)


## [method opponent_index] for any round, so the round window can name the
## NEXT one before the counter has moved.
func index_for_round(which: int) -> int:
	if order.is_empty():
		return -1
	return (start + which) % order.size()


## The current opponent's deck path, or "" when there is none.
func opponent() -> String:
	var at := opponent_index()
	return "" if at < 0 else order[at]


## The current opponent's display name — what `Your next duel is against
## %s.` prints.
func opponent_name() -> String:
	return name_for_round(round_number)


## The name the NEXT round's opponent will be announced by.
func next_opponent_name() -> String:
	return name_for_round(round_number + 1)


func name_for_round(which: int) -> String:
	var at := index_for_round(which)
	if at < 0:
		return ""
	var path: String = order[at]
	if names.has(path) and String(names[path]) != "":
		return String(names[path])
	return path.get_file().get_basename()


## Is this the last opponent? `@DIALOG_STARTEXP1MATCH_GAUNTLET` has a
## sentence for it and so does `@GAUNTLET` ([constant RAN_IT]).
func is_final_round() -> bool:
	return round_number >= length()


## THE LINE THAT INTRODUCES THIS ROUND'S OPPONENT — one of
## `@DIALOG_STARTEXP1MATCH_GAUNTLET`'s three, chosen by where [param which]
## falls in the run. "" when the run has no opponents at all.
##
## THE ONE ROUND BOTH SENTENCES FIT is a run of length 1, which is at once
## the first opponent and the final one. No source settles it — the shell
## page's `&Num opponents:` is what makes a one-round gauntlet reachable
## and the decompiled driver's own screen is not in the survey — so the
## choice is OURS and it is `first`: the announcement is made as the run
## BEGINS, and "Your first opponent" is true of the opening of every run
## while "Your final opponent" is a note about how much is left. The
## `RAN_IT` branch of the round window still calls it a gauntlet run.
func announcement_for_round(which: int) -> String:
	if length() == 0:
		return ""
	if which <= 1:
		return FIRST_OPPONENT
	if which >= length():
		return FINAL_OPPONENT
	return NTH_OPPONENT % [which, length()]


## [method announcement_for_round] for the round now being played.
func announcement() -> String:
	return announcement_for_round(round_number)


## Record one DUEL in the session triple. The match's own tally belongs to
## [MatchState]; these three numbers survive it.
func record_duel(outcome: Outcome) -> void:
	match outcome:
		Outcome.WON:
			wins += 1
		Outcome.LOST:
			losses += 1
		_:
			ties += 1


## Record the MATCH that has just ended — the unit of progress in a
## gauntlet, which is why `That was round %d` counts matches and not
## duels. Winning advances the run or finishes it; anything else ends it.
##
## A TIED MATCH ends the run too, and that is ours rather than 1997's: the
## original's match cannot end without somebody reaching wins-needed, so
## its driver has only the two branches. Our [MatchState] also ends a
## match when the duels simply run out (a best of three that draws twice),
## and a match you did not take is not a match you survived.
func record_match(won: bool) -> void:
	if over:
		return
	if not won:
		over = true
		return
	if is_final_round():
		over = true
		completed = true
		return
	round_number += 1


## `&Quit Gauntlet` — the dialog returns 0 and the driver falls back to
## its startup screen (`docs/gauntlet-design.md` §1.7, case 3). The run is
## over but it was not RUN: [member completed] stays false.
func quit() -> void:
	over = true


# -------------------------------------------------------- the messages --

## WHICH `@GAUNTLETERRORS` MESSAGE THIS OPPONENT'S DECK EARNS, as a format
## string with one `%s` for the deck's name — or "" when the deck may be
## played. The original validates the opponent's deck EVERY ROUND
## (`docs/gauntlet-design.md` §1.7, case 4), which is why this is checked
## per round and not once at the start: a deck deleted or edited between
## the shuffle and round 6 is exactly the case those four strings exist
## for.
##
## The order is the string table's own, loosest test last, so a deck that
## fails more than one is named by the first thing wrong with it. The two
## numeric limits are [DeckModel]'s, which already carries them from
## `@TOOFEWCARDS` / `@TOOMANYCARDS` with the 1997 citations on them —
## deliberately not re-declared here, because two copies of `40` in one
## project is one copy too many.
##
## [constant DECK_WRONG_VERSION] is NOT among the answers, and its own doc
## comment says why: nothing this project reads carries a version number.
##
## [param deck] is a STRICT [method DeckList.load_file] — under a lenient
## load an unimplemented card becomes a proxy instead of an error, and a
## gauntlet cannot deal a proxy into a library.
static func opponent_deck_problem(path: String, deck: DeckList) -> String:
	return _deck_problem(path, deck, DECK_INVALID, DECK_TOO_SMALL, DECK_TOO_BIG)


## The same three tests over YOUR deck, answered in the `Player's deck`
## strings — "" when it may be played. [param deck] is a STRICT load, for
## the reason [method opponent_deck_problem] gives.
static func your_deck_problem(path: String, deck: DeckList) -> String:
	return _deck_problem(path, deck, YOUR_DECK_INVALID, YOUR_DECK_TOO_SMALL,
		YOUR_DECK_TOO_BIG)


static func _deck_problem(path: String, deck: DeckList, invalid: String,
		too_small: String, too_big: String) -> String:
	if path == "" or deck == null or not deck.errors.is_empty() \
			or deck.cards.is_empty():
		return invalid
	if deck.cards.size() < DeckModel.MIN_CARDS:
		return too_small
	var distinct := {}
	for card_name in deck.cards:
		distinct[card_name] = true
	if distinct.size() > DeckModel.MAX_UNIQUE \
			or deck.cards.size() > DeckModel.MAX_TOTAL:
		return too_big
	return ""


## The result line for a duel — `@GAUNTLET` entries 1-3, one always.
static func result_line(outcome: Outcome) -> String:
	match outcome:
		Outcome.WON:
			return CONGRATULATIONS
		Outcome.LOST:
			return TOO_BAD
		_:
			return DUEL_TIED


## A duel's [enum Outcome] from the seat that won it (-1 for a draw, the
## same value [signal DuelScreen.duel_finished] and [MatchState.record]
## carry) as seen from [param human_seat].
static func outcome_for(winner_id: int, human_seat: int) -> Outcome:
	if winner_id < 0:
		return Outcome.TIED
	return Outcome.WON if winner_id == human_seat else Outcome.LOST


## THE WHOLE MESSAGE the round window shows, in the driver's own order and
## no other (0x4420a1): the result line, then exactly ONE of the four
## run-level branches, then the two `@DIALOG_GAUNTLETENDDUEL` lines.
##
## Call it BEFORE [method record_match] — `That was round %d` names the
## round just played, and the branches are decided by where the run stands
## at the moment the duel ended.
##
## [param match_over] is [method MatchState.is_over] and [param match_won]
## is whether the human seat took it.
func end_of_duel_lines(outcome: Outcome, match_over: bool,
		match_won: bool) -> Array[String]:
	var lines: Array[String] = [result_line(outcome)]
	if not match_over:
		# Nobody has taken the match yet. In the original this line is on
		# the same window as everything else; our match's own between-duels
		# window (`@DIALOG_ENDEXP1DUEL_*`, [MatchScreen]) is the one the
		# player sees mid-match, so this branch is composed, tested and
		# not currently rendered — see [GauntletScreen].
		lines.append(CONTINUES)
	elif not match_won:
		lines.append(LOST_RUN)
	elif is_final_round():
		lines.append(RAN_IT)
	else:
		lines.append(WON_MATCH)
		lines.append(NEXT_IS % next_opponent_name())
		lines.append(CONTINUE_Q)
	lines.append(ROUND_LINE % round_number)
	lines.append(RECORD % [wins, losses, ties])
	return lines


# --------------------------------------------------------- the shuffle --

## Build a run's opponent order out of [param decks] (deck file paths).
##
## This reproduces 0x49e6f9 IN EFFECT, not instruction for instruction,
## and both differences are `[QoL]` and deliberate:
##
## 1. **A proper Fisher-Yates**, where the original does `10n` random
##    swaps of `list[i % n]` with `list[rand() % n]`. That loop is a
##    weaker shuffle (it is biased and it burns ten times the rolls), and
##    at any run length a player will ever see the two are
##    indistinguishable.
## 2. **The sample is drawn from the WHOLE folder.** The original numbers
##    only the first `min(n, 20)` decks and shuffles those among
##    themselves, so with more than twenty decks on disk deck 21 onward is
##    never met — almost certainly the defect behind MicroProse's own
##    *"The random selection of opponents in the Gauntlet is now fixed"*.
##    Shuffling first and cutting second is indistinguishable with five
##    decks and is the difference between a mode and a bug with fifty
##    (`docs/gauntlet-design.md` §5.6).
##
## [param limit] is the run length: capped at [constant MAX_OPPONENTS] and
## at the number of decks available, so `Num opponents` can shorten a run
## but never lengthen it past the twenty the original allows.
static func shuffle(decks: Array[String], rng: RandomNumberGenerator,
		limit := MAX_OPPONENTS) -> Array[String]:
	var pool: Array[String] = decks.duplicate()
	for i in range(pool.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var swap := pool[i]
		pool[i] = pool[j]
		pool[j] = swap
	var take := mini(mini(limit, MAX_OPPONENTS), pool.size())
	return pool.slice(0, maxi(take, 0))


## Start a run: the shuffled order, and the random point in it the run is
## entered at (0x49e921 — `DAT_005f6498 = _rand() % DAT_005f649c`).
## Everything else is the driver's case 0: round 1, an empty record, and a
## run that is not over.
func begin(decks: Array[String], rng: RandomNumberGenerator,
		limit := MAX_OPPONENTS) -> void:
	order = shuffle(decks, rng, limit)
	start = 0 if order.is_empty() else rng.randi() % order.size()
	round_number = 1
	wins = 0
	losses = 0
	ties = 0
	over = false
	completed = false
