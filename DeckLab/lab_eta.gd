class_name LabEta
extends RefCounted
## HOW MUCH LONGER — the Deck Lab's estimate of the time a run has left.
## Fed one sample per progress tick, asked for one rate; the drawing is
## [LabConsole]'s and the polling is the Lab's. Unit-tested in
## tests/tools/test_deck_lab.gd.
##
## WHY THIS IS NOT `remaining / (done / elapsed)`
## ---------------------------------------------
## That is what the bar did until 2026-09-11, and it is wrong in three
## ways this tool hits every day. All three are the same mistake: the
## overall average is an average of a run that is not one thing.
##
##   * THE START IS NOT THE RUN. The clock starts before any game does. A
##     fanned-out run spends its first two seconds booting eight engines
##     and nothing finishes in them, so the first rate is the rate of a
##     machine that is not playing yet. MEASURED, on the recorded trace of
##     a 30,000-game duel that took 164 s: the first estimate the old
##     formula could print was 72,028 seconds — TWENTY HOURS — and it was
##     still saying seven minutes two seconds later.
##   * THE END IS NOT THE START EITHER. A sweep plays its arms one after
##     another and a gauntlet its pairs; against The Deck a game runs 39
##     turns and against Twist of Fire 10, so the second half of a run can
##     cost four times the first. An average over the whole run keeps
##     quoting the speed of work that has already finished.
##   * IT NEVER RECOVERS. The overall average can only be dragged back by
##     a growing weight of new samples, so an estimate that starts wrong
##     stays wrong: on that same two-pair gauntlet the old formula was
##     still 68% short three quarters of the way through, while a window
##     had come back to 33%.
##
## SO: A SLIDING WINDOW OVER THE LAST [constant WINDOW_SECONDS], AND NO
## ESTIMATE AT ALL UNTIL THERE ARE [constant MIN_SPAN_SECONDS] OF RUN TO
## MEASURE. Samples before the first finished game are not recorded, which
## is the whole of "discard the warm-up" — an `if`, not a heuristic about
## what a warm-up looks like. Both halves are arithmetic a reader can do
## in their head, and neither has a knob that is not in this file.
##
## WHY THIRTY SECONDS, AND WHY NOT AN EXPONENTIAL DECAY. Measured on five
## recorded runs rather than argued (the table is in docs/ROADMAP.md, "A
## PROPER ETA"). A short window tracks a change of pair faster and pays
## for it in jitter — measured as how far the printed number strays from
## ticking down one second per second, a 5-second window moves between
## four and six times as much as a 30-second one, and a number that jumps
## around is unreadable in exactly the way [LabConsole]'s own comment says
## a bar that breathes in and out is. An exponentially weighted rate was
## no better on jitter, no better on accuracy, and worse over the first
## tenth of a run (+72% against -3% on the fanned duel, because a decay
## starts at the first interval's rate and climbs out of it), for a
## half-life nobody can point at on a screen. Thirty seconds is the
## flattest part of that trade and it is also a thing one can say out
## loud: THE BAR SHOWS HOW FAST THE LAST HALF-MINUTE WENT.
##
## WHAT IT STILL CANNOT DO, because nothing measuring a rate can: see a
## change that has not happened yet. Half way through a gauntlet whose
## second pair is four times slower, every method here is about 55% short
## — the difference is that this one is back within a third by 75%, and
## the overall average is not back at all. An estimate is the speed of the
## last half-minute projected forward; it is not a promise.
##
## IT HANDS OVER A RATE, NOT A TIME, and the division happens where the
## line is drawn ([method LabConsole.progress_line]). That is deliberate:
## the bar prints both numbers, and this way they cannot disagree — the
## eta on screen is always exactly the games left over the rate beside it,
## and a reader can check it by eye. The report's own `(182 games/s)` is
## still the average over the whole run; that one is a measurement of the
## machine, not a prediction.

## The rate is measured over the last this-many seconds of completions.
const WINDOW_SECONDS := 30.0
## AND NOTHING IS CLAIMED BEFORE THIS. A rate measured over a fifth of a
## second of a run that is still starting is wrong by a factor: gating it
## at three seconds took the first printed estimate from +172% to +16% on
## the fanned duel and from +179% to +10% on the sweep, and moved no other
## figure in the table. The bar simply shows no eta until then — which it
## already does for the first two seconds of every run.
const MIN_SPAN_SECONDS := 3.0

## (elapsed seconds, games finished), oldest first, trimmed to the window.
var _samples: Array = []
## The first sample that had a finished game in it — the run's real start.
## Kept for the whole run, because it is the fallback when the window
## holds no completions at all (every worker grinding a long game).
var _anchor_at := -1.0
var _anchor_done := 0


## One progress tick: [param done] games finished at [param elapsed]
## seconds. A tick before the first finished game is DROPPED rather than
## recorded — engine boot, project import and deck loading are in those
## seconds, and none of them is the speed of a game.
func observe(elapsed: float, done: int) -> void:
	if done <= 0:
		return
	if _anchor_at < 0.0:
		_anchor_at = elapsed
		_anchor_done = done
	_samples.append([elapsed, done])
	# Drop what has fallen out of the window, never the last two samples:
	# a rate needs two points to exist at all.
	while _samples.size() > 2 \
			and elapsed - float(_samples[0][0]) > WINDOW_SECONDS:
		_samples.pop_front()


## Games per second over the window, or 0.0 while it will not say. Three
## answers, in order: the window; the run's own average since its first
## finished game, when the window holds no completions (a run currently
## grinding through long games still has an estimate, just a coarser one);
## and nothing at all, for the first seconds of a run.
func rate() -> float:
	if _samples.size() < 2:
		return 0.0
	var last: Array = _samples[_samples.size() - 1]
	var first: Array = _samples[0]
	var span := float(last[0]) - float(first[0])
	var gained := int(last[1]) - int(first[1])
	if span >= MIN_SPAN_SECONDS and gained > 0:
		return gained / span
	var all_span := float(last[0]) - _anchor_at
	var all_gained := int(last[1]) - _anchor_done
	if all_span >= MIN_SPAN_SECONDS and all_gained > 0:
		return all_gained / all_span
	return 0.0
