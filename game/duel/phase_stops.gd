class_name PhaseStops
extends RefCounted
## THE STOPS — the 1997 duel's own name for a lasting "do not pass this
## phase" mark the player sets from the Phase Bar's mini-menu.
##
## Manual p.116-117, verbatim: *"You can right-click on any phase and select
## Mark from the mini-menu to put a Stop on that phase. This is a lasting
## instruction that you do not want the duel to pass that phase until you
## have had a chance to do something. Specifically, that phase does not end
## until you tell it to manually; it cannot pass automatically."* —
## `Duel.hlp`, topic **Stop**, words it *"put a Stop **marker** on that
## phase"*, which is what the red dot on the bar is.
##
## `Duel.hlp` also advises *"A Stop on your opponent's Main Pre-Combat
## sub-phase is always a good idea"*, so a Stop is set on **either** seat's
## half of the bar — the top half is the opponent's turn, the lower half
## yours (manual p.116).
##
## THE ORIGINAL'S DATA STRUCTURE, which survives in the Manalink source and
## is the shape copied here: `char option_PhaseStoppers[2][38]`
## (`shandalar-src/src/manalink.h:120`), read and written as
## `option_PhaseStoppers[current_turn][current_phase]` with **bit 0** the
## flag (`src/functions/windows.c:543-557`). Two things it tells us:
##
##   * the first index is WHOSE TURN it is — one set of stops per half of
##     the bar, exactly as the manual describes; and
##   * 38 == 0x26 is one past `PHASE_DAMAGE_PREVENTION` (0x25), the last
##     entry of the original's `phase_t` (`src/defs.h:685-707`), so the
##     array spans the WHOLE phase enum — combat's sub-phases
##     (`PHASE_DECLARE_ATTACKERS` 0x15 … `PHASE_NORMAL_COMBAT_DAMAGE` 0x1B)
##     included. That is the file-level confirmation of `Duel.hlp`'s *"[the
##     Combat Bar] functions in exactly the same way as the larger bar; you
##     can even use Stops."*
##
## So the model here is two BARS — the Phase Bar's eight icons and the
## Combat Bar's seven — times two HALVES. `Bar` plus `slot` is our
## equivalent of the original's flat `current_phase`; we keep the two apart
## because our two strips number their icons independently.
##
## PERSISTED, because the manual calls a Stop *"a lasting instruction"* and
## because the original persisted it: `PhaseStoppers` is one of the values
## under `Software\MicroProse\Magic: The Gathering\DuelOptions`, beside
## `ShowCueCards` and the rest of the Duel Options (docs/duel-todo.md §6.4)
## — and the manual says of that panel *"your option settings are retained
## for future duels"* (p.114). Ours ride `Settings` for the same reason.
##
## Pure logic, no Node: lives in game/ because only the UI uses it.

## The two strips a Stop can sit on. `Bar.PHASE` is the eight-icon Phase
## Bar, `Bar.COMBAT` the seven-icon Combat Bar that replaces it during an
## attack (`Duel.hlp`, topic **Combat Bar**).
enum Bar { PHASE, COMBAT }

## Which half of the bar. Manual p.116: *"The top half of the bar
## represents the phases in your opponent's turn, while the lower half
## represents your turn."* Ordered top-to-bottom so the enum reads like the
## strip.
enum Half { OPPONENTS, YOURS }

## Icons per bar, indexed by [enum Bar].
const SLOT_COUNT: Array[int] = [8, 7]

## The `Settings` key the marks persist under — the original's own value
## name, lower-cased to match our other keys.
const SETTING_KEY := "phase_stoppers"

## `@MENU_PHASEBAR`, `shandalar-src/Program/UIStrings.txt:947` (the same
## four entries at `Program/Text.res:1903`) — the entire mini-menu a
## right-click on a phase icon opens, verbatim and in the table's order.
const MENU_RUN_TO := "Run to this phase"
const MENU_MARK := "Mark this phase to always stop"
const MENU_HELP_PHASE := "Help for this phase..."
const MENU_HELP := "Help..."
const MENU_ENTRIES: Array[String] = [
	MENU_RUN_TO, MENU_MARK, MENU_HELP_PHASE, MENU_HELP,
]

## THE THREE STOPS A FRESH PROFILE STARTS WITH — the owner's playtest,
## 2026-09-03: *"My main phase precombat, combat and main phase post-combat
## should be selected to stop (red dot) by default."*
##
## The three slots of the Phase Bar's LOWER half (manual p.116: *"the lower
## half represents your turn"*) — 3 `Main phase (precombat)`, 4
## `Main phase (declare combat)`, 5 `Main phase (postcombat)`, named by
## `@CUECARD_PHASEBAR` entries 12-14 ([constant PhaseBar.CUE_YOURS]).
## Nothing else carries one, so the opponent's half starts bare and the
## Combat Bar does too.
##
## **THE ORIGINAL SHIPPED THREE TOO, AND THEY ARE NOT QUITE THESE THREE**
## (established 2026-09-03; `docs/ROADMAP.md`, "THE THREE DEFAULT STOPS").
## `Magic.exe`'s duel-options loader zeroes the whole
## `option_PhaseStoppers` array (`0x62c374`, the address
## `shandalar-src/src/manalink.lds:62` links Manalink against) and then
## sets exactly three cells, in both the no-registry-key and the
## no-`PhaseStoppers`-value paths:
##
## | write | cell | seat (`defs.h:2362`: `HUMAN = 0`, `AI = 1`) | phase |
## |---|---|---|---|
## | `mov BYTE PTR ds:0x62c388,1` | `[0][0x14]` | yours | `PHASE_MAIN1` = slot 3 |
## | `mov BYTE PTR ds:0x62c392,1` | `[0][0x1E]` | yours | `PHASE_MAIN2` = slot 5 |
## | `mov BYTE PTR ds:0x62c3b9,1` | `[1][0x1F]` | **the opponent's** | `PHASE_DISCARD` = slot 6 |
##
## — and when a stored value IS read back it still forces your own
## pre-combat main on (`0x45deea`: `movsx eax,[0x62c388]; or al,1`), so
## that one Stop was mandatory. So the 1997 set is **yours 3 and 5, plus
## the opponent's 6**.
##
## OURS IS THE OWNER'S SET, and the two differences are labelled `[QoL]`:
## we ADD your combat icon (slot 4) and we do NOT ship the opponent's
## Discard stop. Everything else agrees with 1997, including the shape of
## the answer — that a fresh profile has Stops at all, on the two main
## phases, and that the file only holds a value once the player changes
## something.
const DEFAULT_SLOTS: Array[int] = [3, 4, 5]

## The 1997 set, kept beside ours so the divergence is one edit wide and
## the original is never lost. Not read by the game — read by
## `tests/ui/test_phase_stops.gd`, which pins the difference so nobody has
## to disassemble `Magic.exe` twice.
const ORIGINAL_1997_YOURS: Array[int] = [3, 5]
const ORIGINAL_1997_OPPONENTS: Array[int] = [6]

## [constant DEFAULT_SLOTS] as the one bitmask that is not zero — the
## `Half.YOURS`/`Bar.PHASE` row, index `1 * 2 + 0` of [member _marks].
const DEFAULT_YOURS_PHASE := (1 << 3) | (1 << 4) | (1 << 5)


## The whole default, in the flat shape [member _marks] and `Settings` use.
## A method rather than a `const` because GDScript will not fold a
## `PackedInt32Array` literal into a constant expression.
static func default_masks() -> PackedInt32Array:
	return PackedInt32Array([0, 0, DEFAULT_YOURS_PHASE, 0])

## One bitmask per (half, bar), flat: `_marks[half * 2 + bar]`, bit
## `1 << slot`. Four ints is the whole model, which is what makes it a
## one-line `Settings` value.
var _marks := PackedInt32Array([0, 0, 0, 0])


## Which half of the bar [param seat]'s turn is drawn in, from the seat the
## human is sitting in. Your own turn is the lower half; anyone else's is
## the upper one.
static func half_for_seat(seat: int, human_seat: int) -> int:
	return Half.YOURS if seat == human_seat else Half.OPPONENTS


static func _index(half: int, bar: int) -> int:
	return clampi(half, 0, 1) * 2 + clampi(bar, 0, 1)


## Is a Stop set on [param slot] of [param bar] in [param half]?
func is_marked(half: int, bar: int, slot: int) -> bool:
	if slot < 0 or slot >= SLOT_COUNT[clampi(bar, 0, 1)]:
		return false
	return (_marks[_index(half, bar)] & (1 << slot)) != 0


## Set or clear one Stop. Out-of-range slots are ignored rather than
## refused: the bars own their own numbering and a stale index is a UI bug,
## not a player mistake.
func set_marked(half: int, bar: int, slot: int, on: bool) -> void:
	if slot < 0 or slot >= SLOT_COUNT[clampi(bar, 0, 1)]:
		return
	var i := _index(half, bar)
	if on:
		_marks[i] |= 1 << slot
	else:
		_marks[i] &= ~(1 << slot)


## Flip one Stop and return its NEW state. This is what
## [constant MENU_MARK] does — see the divergence note in
## `docs/duel-todo.md` §6.1: the 1997 table ships no "unmark" string, so the
## single entry has to serve both ways.
func toggle(half: int, bar: int, slot: int) -> bool:
	var now := not is_marked(half, bar, slot)
	set_marked(half, bar, slot, now)
	return now


## Every marked slot of one (half, bar), in icon order.
func marked_slots(half: int, bar: int) -> Array[int]:
	var out: Array[int] = []
	for slot in SLOT_COUNT[clampi(bar, 0, 1)]:
		if is_marked(half, bar, slot):
			out.append(slot)
	return out


## Is anything marked at all? (The auto-advance driver asks, so a duel with
## no Stops costs nothing.)
func any_marked() -> bool:
	for m in _marks:
		if m != 0:
			return true
	return false


func clear_all() -> void:
	_marks = PackedInt32Array([0, 0, 0, 0])


## The four bitmasks, for persistence and for tests.
func to_masks() -> PackedInt32Array:
	return _marks.duplicate()


func from_masks(masks: PackedInt32Array) -> void:
	clear_all()
	for i in mini(masks.size(), 4):
		_marks[i] = masks[i]


## The three defaults, as a fresh [PhaseStops].
static func defaults() -> PhaseStops:
	var stops := PhaseStops.new()
	stops.from_masks(default_masks())
	return stops


## THE STORED ROW'S OWN GENERATION — a FIFTH int on the persisted value,
## and the reason the owner had to report the same thing twice.
##
## WHAT WENT WRONG (2026-09-04, and this is the whole of it). The contract
## below says "default" means the ABSENCE of a stored row, so a row that
## IS there is honoured verbatim. That is right for a row the player chose
## — and every build before 2026-09-03 shipped NO defaults at all, so the
## rows those builds wrote were chosen against nothing. The owner marked
## their own Main pre-combat by hand back then; their file has held
## `PackedInt32Array(0, 0, 8, 0)` ever since. When the three defaults
## landed the next day, that row went on outranking them, and the owner's
## bar went on showing the one dot they had set themselves. The fix was
## correct, the tests were green, and it could not reach the only profile
## that mattered — because a row written before there were defaults is
## indistinguishable, in four ints, from a deliberate opt-out.
##
## So the row now says which build's answer it is. A row WITHOUT this
## stamp predates the defaults, is not an opt-out from an offer nobody
## made, and gets [method default_masks]; a row WITH it is a decision
## taken with the dots on the table and is honoured to the letter,
## `[0, 0, 0, 0]` included.
##
## BUMP IT ONLY TO RE-OFFER. Raising this number hands every profile the
## current defaults once more and discards the choice they had made, which
## is a thing to do when the defaults themselves change and the player
## should see the new set — not something to do casually.
const DEFAULTS_GENERATION := 1


## Load the player's Stops. Never fails: a missing or malformed value just
## means [method defaults].
##
## THE SETTINGS CONTRACT, and it is the whole reason this reads
## [method Settings.has_value] rather than a default argument. "Default"
## has to mean the ABSENCE of a stored value — writing the defaults into
## the player's file is a bug this project has shipped once already (the
## "fan" hand style) — so the states must stay distinguishable:
##
##   * no key at all           -> [method default_masks], the three main stops;
##   * a STAMPED stored array  -> exactly what it says, **including four
##     zeroes**;
##   * an UNSTAMPED stored array -> a row from a build that had no
##     defaults, so [method default_masks] again (see
##     [constant DEFAULTS_GENERATION]).
##
## The middle line is what protects the player who deliberately clears
## every Stop: `[0, 0, 0, 0, 1]` is a decision and is written down, so the
## next duel does not silently hand the three dots back. See
## [method save] for the other half of the same contract.
static func load_saved() -> PhaseStops:
	var stops := PhaseStops.new()
	if not Settings.has_value(SETTING_KEY):
		return defaults()
	# The default must not be null: ConfigFile refuses a NIL default.
	var raw: Variant = Settings.get_value(SETTING_KEY, PackedInt32Array())
	var masks := PackedInt32Array()
	if raw is PackedInt32Array:
		masks = raw
	elif raw is Array:
		# ConfigFile can hand an untyped Array back; take it either way.
		for v in raw:
			masks.append(int(v))
	if masks.size() < 5 or masks[4] != DEFAULTS_GENERATION:
		# Either not something this class ever wrote (a hand-edited or
		# truncated value), or a row from a build that shipped no defaults
		# for it to disagree with. Neither is a decision, so both fall back
		# to the defaults rather than to a silently emptier bar.
		return defaults()
	stops.from_masks(masks)
	return stops


## Persist. The DEFAULT set clears the key outright, so an untouched
## profile never materialises a default into the player's file (see
## [method Settings.clear_value]); anything else — an added Stop, a
## removed one, or every one of them removed — is the player's own
## decision and is written down, stamped with the generation of the
## defaults it was a decision ABOUT ([constant DEFAULTS_GENERATION]).
## [method load_saved] is the other half.
func save() -> void:
	if _marks == default_masks():
		Settings.clear_value(SETTING_KEY)
	else:
		var row := _marks.duplicate()
		row.append(DEFAULTS_GENERATION)
		Settings.set_value(SETTING_KEY, row)
