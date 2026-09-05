class_name RulesOptions
extends RefCounted
## THE RULES FORKS — where the 1997 game's ruleset and modern Magic
## genuinely disagree, as switches rather than as a silent default.
##
## The original states its ruleset outright (manual p.108): *"This version
## of Magic: The Gathering enforces the official FIFTH EDITION rules"*,
## and *"the new rulings... are ruthlessly enforced, and there is no room
## for negotiation."* Our engine, meanwhile, cites the modern
## Comprehensive Rules throughout — better specified, better known, and
## what a card's oracle text assumes.
##
## Both are defensible, so the owner's call (2026-08-31) is that each
## CRITICAL rule is an option: Fifth Edition for fidelity, modern for
## familiarity. This class is the one place those forks live, so a fork is
## never discovered card by card. Each flag below carries the manual page
## that establishes the 1997 behaviour and what modern rules do instead.
##
## Every flag defaults to the MODERN answer, so an engine built without
## touching this class behaves exactly as it did before the class existed.
## For most forks that means false; for `attackers_revocable` the modern
## answer is TRUE, which is why each fork declares its own direction.
##
## Adding a fork: add the flag, cite the manual, implement it behind the
## flag, then flip [member IMPLEMENTED] — the Options screen greys out
## anything not in that set rather than offering a switch that does
## nothing.

## Which forks actually DO something today. The Options screen reads this
## to disable the rest; docs/duel-todo.md §6.20 tracks the remainder.
const IMPLEMENTED := ["mana_burn", "attackers_revocable",
	"tapped_artifacts_stop", "life_checked_at_phase_end",
	"pool_empties_on_attack", "free_damage_assignment",
	"damage_prevention_window"]

## Every fork, with the label and explanation the Options screen shows.
## Order is the order they appear on screen.
##
## `fifth_value` is what the 1997 ruleset says — usually true, but NOT
## always: the original made attacker selection final, so its Fifth
## Edition answer is `false`. set_edition() reads this per fork rather
## than assuming a direction, which lets every row be phrased the way a
## player thinks about it instead of all being forced into "1997 = on".
const FORKS := [
	{
		"key": "mana_burn",
		"label": "Mana burn",
		"fifth_value": true,
		"fifth": "Lose 1 life for each unspent mana when your pool empties.",
		"modern": "Unspent mana is simply lost.",
		"source": "UIStrings @DIALOG_MANABURN; dropped from Magic in 2009",
	},
	{
		"key": "attackers_revocable",
		"label": "Attacker selection revocable",
		"fifth_value": false,
		"fifth": "Once you name an attacker it is committed — no taking it back.",
		"modern": "Click an attacker again to un-declare it, until you press Done.",
		"source": "manual p.86; the owner keeps ours ON as a deliberate divergence",
	},
	{
		"key": "tapped_artifacts_stop",
		"fifth_value": true,
		"label": "Tapped artifacts stop working",
		"fifth": "A tapped artifact's continuous effects cease (artifact creatures excepted).",
		"modern": "Tapping an artifact does nothing to its abilities.",
		"source": "manual p.124 — no modern counterpart at all",
	},
	{
		"key": "life_checked_at_phase_end",
		"fifth_value": true,
		"label": "Negative life is survivable",
		"fifth": "Life is checked at phase boundaries: go below 0 and live, if you gain it back before the phase ends.",
		"modern": "0 or less loses immediately, as a state-based action.",
		"source": "manual p.174 (Glossary)",
	},
	{
		"key": "pool_empties_on_attack",
		"fifth_value": true,
		"label": "1997 mana-pool timing",
		"fifth": "The pool empties at the end of each PHASE — combat counts as one, emptying when it is over.",
		"modern": "The pool empties at the end of every step.",
		"source": "manual p.176",
	},
	{
		"key": "damage_prevention_window",
		"label": "Damage prevention step",
		"fifth_value": true,
		"fifth": "Damage waits: after it is dealt, both players may use "
			+ "prevention, healing and redirection effects on it, and then "
			+ "regenerate whatever still has lethal damage.",
		"modern": "Prevention is applied automatically as the damage is "
			+ "dealt, in a fixed order, with no window to respond in.",
		"source": "Duel.hlp topic Damage Dealing (\"During damage dealing, "
			+ "players may use only damage prevention fast effects\"); the "
			+ "prevention step was removed in Sixth Edition (1999), which is "
			+ "why modern CR 615 has replacement effects and no step",
	},
	{
		"key": "free_damage_assignment",
		"label": "Free combat damage division",
		"fifth_value": true,
		"fifth": "Divide an attacker's damage among its blockers however you like.",
		"modern": "Assign lethal damage to each blocker in order before the next.",
		"source": "UIStrings @PROMPT_RESOLVECOMBAT (\"%s: Assign damage to "
			+ "blockers, %d points left\"); the damage assignment order is a "
			+ "Sixth Edition invention (CR 509.2/510.1c)",
	},
]

# ------------------------------------------------------------- the forks --

## Lose 1 life per unspent mana when the pool empties (manual p.176 and
## @DIALOG_MANABURN, "Mana Burn! / %s loses %d life"). LIVE.
##
## Note MANALINK is what turned this off for this game (config.txt
## ManaBurn:0) — MicroProse shipped it on. Modern Magic dropped the rule
## in 2009.
var mana_burn := false

## Clicking a declared attacker again takes it back, right up until Done.
## The 1997 game did NOT allow this (manual p.86); the owner's call
## (2026-08-31) is to keep ours revocable by DEFAULT and label the
## divergence rather than hide it. LIVE.
var attackers_revocable := true

## A tapped artifact's continuous effects cease; artifact creatures are
## exempt (manual p.124). LIVE — the recalculation marks a tapped
## artifact's statics suspended, so the rule holds in every CR 613 layer
## (continuous.gd). Its activated abilities are untouched: the manual
## suspends CONTINUOUS effects only.
var tapped_artifacts_stop := false

## Life is checked at PHASE boundaries rather than continuously, so a
## player may drop below 0 and survive by regaining it within the phase
## (manual p.174). Poison still outranks it and kills immediately
## (p.177). LIVE — the state-based check steps aside and
## MtgGame._check_lethal_life runs at the phase boundary instead; two
## players dying on the same boundary is a DRAW (p.168).
var life_checked_at_phase_end := false

## The 1997 emptying schedule: end of each PHASE, plus the beginning and
## end of an attack (manual p.176) — a different SHAPE from our
## every-step clear, not merely a different frequency. LIVE, per the
## owner's ruling (2026-08-31): pools empty at each PHASE end, with
## combat counting as ONE phase that empties only when it is over. Pairs
## with mana_burn, which is then charged on those boundaries.
var pool_empties_on_attack := false

## The attacking player divides combat damage among the blockers with no
## announced ORDER and no "lethal to each before the next" constraint —
## which is what the 1997 game's own click loop was
## (`@PROMPT_RESOLVECOMBAT`: "%s: Assign damage to blockers, %d points
## left"). The damage assignment order arrived with Sixth Edition in 1999,
## two years after this game shipped; modern CR 509.2/510.1c is our
## default. Trample's own rule — every blocker must have lethal before any
## point spills to the player (CR 702.19b) — holds under BOTH, because the
## original enforced it too ("Assign trample damage to blockers" is its own
## later prompt). LIVE — MtgGame validates a split against whichever
## applies (docs/duel-todo.md §1.4, §6.9).
var free_damage_assignment := false

## THE DAMAGE-PREVENTION WINDOW (docs/duel-todo.md §6.8). 1997 makes
## damage an object that sits on the table for a moment: `Duel.hlp`, topic
## **Damage Dealing** — *"any damage dealing step during which damage is
## dealt is followed by a damage prevention step, during which both
## players can use effects that prevent and redirect damage. also,
## creatures killed or destroyed during combat can be regenerated"* — and
## topic **Combat**: *"During damage dealing, players may use only damage
## prevention fast effects — those that prevent, heal, or redirect damage.
## ... No other kind of fast effects or spells are permitted."*
##
## Modern Magic has no such step at all: prevention is a replacement
## effect (CR 615) applied automatically in a fixed order, which is
## exactly what our eight prevention gates already are. So this is a fork
## of the real kind — the two rulesets disagree about whether the PLAYER
## chooses which prevention applies to which damage, not merely about how
## much is prevented.
##
## Two windows, not one, because `Duel.hlp`'s **Regeneration** topic is
## explicit that regeneration is not a prevention effect: *"Nor is
## regeneration one of the damage prevention fast effects that you are
## allowed to use during damage prevention steps. You can use
## regeneration ONLY at the time when a creature is about to go to the
## graveyard."*
var damage_prevention_window := false


## Read one fork by name (the Options screen and tests address them as
## data). Unknown keys return false rather than erroring, so a stale
## setting from an older build cannot break a duel.
func get_fork(key: String) -> bool:
	return get(key) if key in self else false


## Set one fork by name. Ignores unknown keys, for the same reason.
func set_fork(key: String, value: bool) -> void:
	if key in self:
		set(key, value)


## Turn every fork to one edition's answer. "fifth" is the 1997 game's
## ruleset (manual p.108); anything else is modern Magic.
func set_edition(edition: String) -> void:
	var fifth := edition == "fifth"
	for fork in FORKS:
		var wants: bool = fork["fifth_value"]
		set_fork(fork["key"], wants if fifth else not wants)


## Which edition the current flags amount to: "fifth", "modern", or
## "custom" when they are mixed. The Options screen shows this back.
func edition() -> String:
	var as_fifth := 0
	for fork in FORKS:
		if get_fork(fork["key"]) == fork["fifth_value"]:
			as_fifth += 1
	if as_fifth == FORKS.size():
		return "fifth"
	if as_fifth == 0:
		return "modern"
	return "custom"
