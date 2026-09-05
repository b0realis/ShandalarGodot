class_name MatchState
extends RefCounted
## THE MATCH — `&Best of:` (`@SHELLPAGE_SINGLEDUEL`,
## `Program/UIStrings.txt:49`, and the same control on
## `@SHELLPAGE_GAUNTLET` `:71` and `@SHELLPAGE_SEALEDDECK` `:91`), and the
## reason the original's pre-duel parameter screen exists at all: it is
## not a screen for setting up one duel, it is a screen for setting up a
## MATCH.
##
## THERE ARE THREE MATCH-LENGTH SURFACES IN THE SOURCES, not two, and
## [constant LENGTHS] is what they add up to (`docs/duel-todo.md` §6.21,
## which corrected the citations this comment used to carry):
##
##  1. **The shell pages.** `&Best of:` is an `msctls_updown32` SPINNER
##     with an edit box, readable in the 1997 `SINGLEDUELPAGE`,
##     `GAUNTLETPAGE` and `SEALEDDECKPAGE` dialog templates — so it takes
##     any N, and there is no `Free Play` control beside it.
##  2. **The duel program's own options dialog.** `@DIALOG_GAUNTLETOPTIONS`
##     (`Program/UIStrings.txt:624-626`) offers `Match Size` as
##     `Best of &Three` / `Best of &One`, and the decompiled 1997
##     `DUEL.EXE` sets wins-needed to exactly 2 or 1 from it (dialog
##     resource `0xe8`, controls `0x456`/`0x457`). The manual says it in
##     prose (p.156): *"Match Size is a choice between two options. You
##     can either play every match as a two out of three contest or decide
##     each match on the strength of a single duel."*
##  3. **The record sentence.** `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS`
##     (`Program/UIStrings.txt:553-562`) ships exactly two record lines,
##     one saying *"best of 3"* and one *"best of 5"*, both with the
##     number written into the sentence rather than substituted. Those are
##     the only two lengths the game can NARRATE: a best of 7 would mean
##     printing a line MicroProse never wrote.
##
## Hence **1, 3 and 5** — 3 and 5 from surface 3, and the 1 from surface
## 2, which is the gauntlet's own Match Size ([GauntletState]). Nothing is
## added to [constant PROGRESS] for the 1: there is no `best of 1 match`
## sentence, and [method progress_line] already returns "" for a length it
## has no line for, so the 1997 constraint and this code agree.
##
## **`&Free play` IS NOT A 1997 STRING — `[QoL]`, and the setup screen's
## label is ours.** It exists only in `@SHELLPAGE_MULTIDUEL`
## (`Program/Text.res:2869`), a tag that does not appear in
## `Program/UIStrings.txt` at all: `Text.res` is Manalink 3's table
## (`Provenance.md`, demoted 2026-09-02) and `MULTIDUELPAGE` is Manalink's
## own page, which dropped `Opponent S&kill` and added `Free Play` beside
## the network row. The 1997 way of saying it is the spinner at 1. We keep
## the word anyway, because [constant FREE_PLAY] really is a different
## thing from `Best of: 1` and needs a name of its own:
##
##   * **`Free play`** `[QoL]` — one duel and NO record: both
##     [method progress_line] and [method verdict] are "". The default, so
##     anything that builds a [DuelConfig] without asking for a match (the
##     Deck Lab, the tests, a standalone scene run) gets exactly the single
##     duel it always did.
##   * **`Best of: 1`** — a MATCH one duel long, which KEEPS a record: it
##     ends with `You've won the match!` and in the original it put
##     `&Save match` on the between-duels window. This is `Best of &One`.
##
## THE RECORD is `wins/losses/draws` from the human seat's point of view,
## which is whose sentence it is — *"your record is %2!d!/%3!d!/%4!d!"*.
## In an AI-vs-AI demo there is no "you"; [member human_seat] then names
## the seat the record is kept for and the words are unchanged, because
## inventing a second set of sentences for a spectator would be inventing
## 1997 text.

## `&Free play` — one duel, no match. The default, so a bare MatchState
## behaves exactly as this project did before matches existed.
const FREE_PLAY := 0
## The three lengths the sources between them offer: `Best of &One` from
## the gauntlet's Match Size, and the two the record sentence can narrate.
## See the class doc — the 1 has no [constant PROGRESS] line and needs
## none.
const LENGTHS: Array[int] = [1, 3, 5]

# The strings, verbatim from `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS`
# (`Program/UIStrings.txt:553-562`). The originals carry `\n\n` and the
# `%1!d!` ordinal-argument spelling Windows' FormatMessage used; the
# newlines are dropped (the caller lays the window out) and the ordinals
# become plain `%d`, in the order the original numbered them.
const PROGRESS := {
	3: "After %d duel(s) in this best of 3 match, your record is %d/%d/%d",
	5: "After %d duel(s) in this best of 5 match, your record is %d/%d/%d",
}
const WON := "You've won the match!"
const LOST := "You've lost the match."
const TIED := "The match ends in a tie."

## [member last_winner] before a single duel has been recorded. Not -1,
## which is the draw the duel screen and this class already carry.
const NO_DUEL := -2

## 0 for `&Free play`, else one of [constant LENGTHS].
var best_of := FREE_PLAY
## `Side&board between duels` (`@SHELLPAGE_SINGLEDUEL`,
## `Program/UIStrings.txt:50`; the gauntlet page carries the same
## parameter at `:72`) — the other match parameter, and the only thing
## that happens BETWEEN two duels of a match.
var sideboard_between_duels := false
## Duels won, per seat.
var wins: Array[int] = [0, 0]
## Duels that ended with nobody winning (CR 104.4 — our engine has them).
var draws := 0
## Whose record the sentences are written from.
var human_seat := 0
## The winner of the LAST duel recorded — a seat, -1 for a draw, or
## [constant NO_DUEL] before any duel has been played.
##
## The match itself has no use for it; the GAUNTLET does. Its round window
## opens with a line about the DUEL just played (`Congratulations!` /
## `Too bad` / `Oh well...`, `@GAUNTLET` entries 1-3) and only then says
## what became of the match, and a match that ends by running out of duels
## need not have ended on a decisive one — a best of three that is won,
## drawn, drawn is over, is won, and its last duel was a draw. Deriving
## the duel from the match would get that case wrong.
var last_winner := NO_DUEL


## How many duels have been played.
func duels_played() -> int:
	return wins[0] + wins[1] + draws


## How many wins take the match. Free play is decided by one duel.
func wins_needed() -> int:
	if best_of == FREE_PLAY:
		return 1
	return best_of / 2 + 1


## Record one duel. [param winner_id] is a seat, or -1 for a draw.
func record(winner_id: int) -> void:
	last_winner = winner_id
	if winner_id < 0:
		draws += 1
	else:
		wins[winner_id] += 1


## Is there another duel to play? A match ends the moment one seat can no
## longer be caught, and also when the duels simply run out — which is how
## a match full of draws ends, and why [method verdict] can say TIED.
func is_over() -> bool:
	if best_of == FREE_PLAY:
		return duels_played() >= 1
	for pid in 2:
		if wins[pid] >= wins_needed():
			return true
	return duels_played() >= best_of


## The seat that took the match, or -1 for a tie (and while it is still
## being played).
func winner() -> int:
	if not is_over():
		return -1
	if wins[0] > wins[1]:
		return 0
	if wins[1] > wins[0]:
		return 1
	return -1


## The record line — `@DIALOG_ENDEXP1DUEL_MATCHPROGRESS` entry 4 or 5,
## with the four numbers the original puts in it: duels played, then
## wins/losses/draws from [member human_seat]'s side. Empty in free play,
## which keeps no record.
func progress_line() -> String:
	if not PROGRESS.has(best_of):
		return ""
	return PROGRESS[best_of] % [duels_played(), wins[human_seat],
		wins[1 - human_seat], draws]


## The match's last word, or "" while it is still running.
func verdict() -> String:
	if not is_over() or best_of == FREE_PLAY:
		return ""
	var took := winner()
	if took == -1:
		return TIED
	return WON if took == human_seat else LOST


## "Duel 2 of 3" — the line the next duel is announced with. Ours, not
## 1997's: the original's own progress sentence is written for the moment
## a duel ENDS and says nothing about the one about to start.
func duel_heading() -> String:
	if best_of == FREE_PLAY:
		return ""
	return "Duel %d of %d" % [duels_played() + 1, best_of]
