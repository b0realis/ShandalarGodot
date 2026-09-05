class_name LabConsole
extends RefCounted
## THE DECK LAB'S TERMINAL SIDE — the banner, the progress bar, colour,
## and the "did you mean" suggestions behind its error messages. Pure
## static string building, unit-tested in tests/tools/test_deck_lab.gd.
##
## WHY THE DECORATION LIVES ON stderr, AND ONLY ON A TERMINAL
## ----------------------------------------------------------
## The Deck Lab is a MEASURING INSTRUMENT before it is a nice experience:
## `results.json` and `matchups.csv` are read by other tooling, and stdout
## carries the same report text that lands in `report.txt`. So stdout is
## the instrument's channel and stderr is the human's — the banner, the
## progress bar and every hint go to stderr, and only when stderr is a
## TERMINAL.
##
## GDScript cannot ask whether a stream is a tty, so `DeckLab/deck_lab.sh`
## asks (`[ -t 2 ]`) and passes the answer in [constant TTY_ENV], with the
## terminal's width in [constant WIDTH_ENV]. The consequence is the one
## that matters: `deck_lab.sh ... > run.log` keeps the banner on the
## terminal and the log clean, and `deck_lab.sh ... > run.log 2>&1` (what
## a script or an agent writes) gets no decoration at all without anyone
## having to remember a flag.
##
## Colour follows the same switch, plus the `NO_COLOR` convention
## (https://no-color.org) and `--quiet` / `--no-banner` /
## [constant NO_BANNER_ENV] for anyone who runs a hundred sweeps a day and
## has stopped enjoying the artwork.

## Set to "1" by deck_lab.sh when stderr is a terminal.
const TTY_ENV := "DECK_LAB_TTY"
## The terminal's width in columns, when there is a terminal.
const WIDTH_ENV := "DECK_LAB_COLUMNS"
## Export this to 1 to never see the banner again (the flag is --no-banner).
const NO_BANNER_ENV := "DECK_LAB_NO_BANNER"
const DEFAULT_WIDTH := 80
## The width the "eta 1m 04s" field is padded to, so the bar beside it
## keeps one length for the whole run.
const ETA_WIDTH := 11

# ANSI SGR codes. Only the basic sixteen: every terminal that has colour
# at all has these, and everything degrades to plain text when `colour`
# is false rather than needing a second code path.
## The escape character itself, so that no other file has to spell it
## (and so a test can look for one without carrying a control character
## in its own source).
const ESC := "\u001b"
const RESET := "\u001b[0m"
const BOLD := "\u001b[1m"
const DIM := "\u001b[2m"
const AMBER := "\u001b[33m"
const GREEN := "\u001b[32m"
const RED := "\u001b[31m"
const CYAN := "\u001b[36m"
## Move the cursor up one line and clear it — how the progress line
## rewrites itself in place. `printerr` always ends its line, so there is
## no other way to stay on one row.
const LINE_UP := "\u001b[1A\u001b[2K"

## The five colours of Magic, in WUBRG order, for the banner's signature
## line. Black is grey because black on black is nothing.
const MANA := [
	["W", "\u001b[97m"], ["U", "\u001b[94m"], ["B", "\u001b[90m"],
	["R", "\u001b[91m"], ["G", "\u001b[92m"],
]

## Three lines and no more. The Lab is a tool somebody runs a hundred
## times in an afternoon, and a banner that has to be scrolled past is a
## banner that gets switched off.
## EVERY GLYPH KEEPS ITS OWN WIDTH. The first cut squeezed them together
## to save two columns, and the letters lost their edges for it: D ran
## straight into E, and L's closing stem became A's slash, so the word
## read `DECK LAB` only if you already knew it did (2026-09-05). Six
## columns for D/C/K/L, five for E/B, seven for A — the widths the font
## they come from actually uses.
## THREE LINES, DOWN FROM FOUR (2026-09-05). The block letters were
## correct but they were also a third of a short terminal, and the whole
## argument for a banner is that it costs nothing to leave on. This is the
## same word in a half-height face: box-drawing rather than pipes and
## underscores, 23 columns instead of 43, and it still reads as DECK LAB
## at a glance. The mana letters move onto the last line, so the banner is
## exactly as tall as its caption and not a row taller.
const WORDMARK := [
	"┌┬┐┌─┐┌─┐┬┌─  ┬  ┌─┐┌┐ ",
	" ││├┤ │  ├┴┐  │  ├─┤├┴┐",
	"─┴┘└─┘└─┘┴ ┴  ┴─┘┴ ┴└─┘",
]

## The caption beside the wordmark, one entry per wordmark line ("" for
## the rows that stay bare). The last one is filled in with the mana
## letters, which are the only coloured thing here.
## SHORT ENOUGH FOR EIGHTY COLUMNS, which is a hard limit and not a
## preference: the two-space indent plus the wordmark's 43 columns plus
## the three-space gap leaves 32 for the caption, and the corrected
## letterforms (2026-09-05) are wider than the squeezed ones these lines
## were first written against.
const CAPTION := [
	"Shandalar 1997 · AI vs AI",
	"headless deck measurement",
	"",
]


## Whether stderr is a terminal, as deck_lab.sh found it. False when the
## Lab is run through Godot directly, which is the honest answer: that
## caller has no terminal we know of.
static func is_terminal() -> bool:
	return OS.get_environment(TTY_ENV) == "1"


## Colour is a terminal thing, and `NO_COLOR` (any value) turns it off —
## the convention every modern CLI honours.
static func use_colour() -> bool:
	return is_terminal() and OS.get_environment("NO_COLOR") == ""


## The terminal's width, clamped to something a progress line can live
## in. Too narrow and the line wraps, which breaks the redraw (the cursor
## can only go up one ROW, and a wrapped line is two).
static func width() -> int:
	var columns := OS.get_environment(WIDTH_ENV).to_int()
	if columns <= 0:
		columns = DEFAULT_WIDTH
	return clampi(columns, 40, 120)


## [param text] wrapped in an SGR code, or untouched when [param colour]
## is false. EVERY colour in this file goes through here, so "degrades to
## plain text" is one line of code rather than a discipline.
static func paint(text: String, code: String, colour: bool) -> String:
	if not colour or code == "":
		return text
	return code + text + RESET


## The banner, as lines. Four rows of wordmark with the caption beside
## it; the mana letters sign the last row.
static func banner_lines(colour: bool) -> PackedStringArray:
	var mana := PackedStringArray()
	for pair in MANA:
		mana.append(paint(String(pair[0]), String(pair[1]), colour))
	var lines := PackedStringArray()
	for i in WORDMARK.size():
		var caption: String = CAPTION[i]
		if i == WORDMARK.size() - 1:
			caption = " ".join(mana)
		var line := "  " + paint(WORDMARK[i], AMBER + BOLD, colour)
		if caption != "":
			line += "   " + (caption if i == WORDMARK.size() - 1
				else paint(caption, DIM, colour))
		lines.append(line)
	return lines


static func banner(colour: bool) -> String:
	return "\n".join(banner_lines(colour))


## "1m 04s" / "2h 11m" / "8.4s" — a duration a human reads at a glance.
## Anything under a minute keeps a decimal, because the difference
## between 0.4 s and 9 s per game is the difference between a coffee and
## an afternoon.
static func duration(seconds: float) -> String:
	if seconds < 60.0:
		return "%.1fs" % seconds
	var whole := int(round(seconds))
	if whole < 3600:
		return "%dm %02ds" % [whole / 60, whole % 60]
	return "%dh %02dm" % [whole / 3600, (whole % 3600) / 60]


## 10000 -> "10,000". Six-figure game counts are this tool's daily work
## and an unseparated one is unreadable.
static func commas(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	while digits.length() > 3:
		out = "," + digits.substr(digits.length() - 3) + out
		digits = digits.substr(0, digits.length() - 3)
	out = digits + out
	return ("-" + out) if value < 0 else out


## The progress line, sized to fit [param columns] EXACTLY once (see
## [constant LINE_UP]: a wrapped line cannot be redrawn). Plain text; the
## caller paints it.
##
## Reports what a waiting human actually wants: how far along, how fast,
## and how much longer. The ETA is a straight extrapolation of the rate
## so far, which is honest for this workload — every game is an
## independent duel of much the same cost.
static func progress_line(done: int, total: int, elapsed: float,
		unit: String, columns: int) -> String:
	var fraction := 0.0 if total <= 0 else clampf(float(done) / total, 0.0, 1.0)
	var rate := 0.0 if elapsed <= 0.0 else done / elapsed
	# EVERY FIELD IS A FIXED WIDTH, so the bar does not change length as
	# the numbers grow and the eta shortens. A bar that breathes in and
	# out while it is redrawn four times a second is unreadable, and it
	# was the first thing wrong with this line.
	var total_text := commas(total)
	var tail := "%s/%s %s" % [commas(done).lpad(total_text.length()),
		total_text, unit]
	var when := ""
	if rate > 0.0:
		when = duration(elapsed) if done >= total \
			else "eta " + duration((total - done) / rate)
	tail += "  %s/s  %s" % [("%.1f" % rate if rate > 0.0 else "--").lpad(5),
		when.rpad(ETA_WIDTH)]
	var head := "  %3d%%  " % int(round(fraction * 100.0))
	# What is left over is the bar. A very narrow terminal gets no bar
	# rather than a broken one.
	var bar_width := columns - head.length() - tail.length() - 3
	if bar_width < 8:
		return (head + tail).substr(0, columns)
	var filled := int(round(fraction * bar_width))
	return "%s[%s%s] %s" % [head, "=".repeat(filled),
		" ".repeat(bar_width - filled), tail]


## The names in [param candidates] most like [param word], best first —
## the "did you mean" behind a bad deck path or a mistyped flag.
## [method String.similarity] is a bigram score, so it forgives a missing
## extension, a swapped pair of letters and a wrong separator, which is
## what people actually type.
## [param spread] keeps the list HONEST: only candidates within that much
## of the best score survive, so a confident match is not diluted by a
## runner-up nobody meant (`--gamez` is 0.83 against `--games` and 0.50
## against `--names`; offering both makes the good answer look like a
## guess). A tie — `--deck_a` scores 0.71 against both `--deck-a` and
## `--deck-b` — still shows both, which is the case where two suggestions
## are the honest answer.
static func closest(word: String, candidates: PackedStringArray,
		limit := 3, floor := 0.45, spread := 1.0) -> PackedStringArray:
	var scored: Array = []
	var needle := word.to_lower()
	for candidate in candidates:
		var score := needle.similarity(String(candidate).to_lower())
		if score >= floor:
			scored.append([score, String(candidate)])
	# Best score first; ties by name, so a suggestion list is stable
	# whatever order the filesystem handed the candidates over in.
	scored.sort_custom(func(a: Array, b: Array) -> bool:
		if a[0] == b[0]:
			return a[1] < b[1]
		return a[0] > b[0])
	var out := PackedStringArray()
	var best := 0.0 if scored.is_empty() else float(scored[0][0])
	for row in scored:
		if out.size() >= limit or best - float(row[0]) > spread:
			break
		out.append(String(row[1]))
	return out
