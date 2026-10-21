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
## One flag defaults to its 1997 answer instead: `sacrifice_clauses_wait`,
## which the "Modern rules" preset itself keeps off (see [member PRESETS]),
## so a fresh engine still reads as that preset.
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
	"damage_prevention_window", "damage_effects_fixed_order",
	"sacrifice_clauses_wait"]

## THE PRESETS — the Options screen's list, in its order. A preset is one
## edition's answers ([method set_edition]) with named exceptions on top,
## and the readout names the preset the flags match EXACTLY; any other
## mix reads "Custom". "Modern rules, mana burn on" is what a fresh
## install plays under: the owner's ruling of 2026-09-13 has mana burn on
## by default (Settings.rule), and their word of 2026-09-25 is that this
## one mix has a name — *"all other mix and match should be custom"*.
##
## BOTH MODERN PRESETS keep `sacrifice_clauses_wait` at the 1997 answer
## (the owner's ruling of 2026-10-13: "leave it as is" under every preset),
## so a sacrifice clause is checked at once whichever preset is chosen and
## switching it on is a "Custom" mix of the player's own.
const PRESETS := [
	{"id": "modern", "label": "Modern rules", "edition": "modern",
		"except": {"sacrifice_clauses_wait": false}},
	{"id": "modern_mana_burn", "label": "Modern rules, mana burn on",
		"edition": "modern", "except": {"mana_burn": true, "sacrifice_clauses_wait": false}},
	{"id": "fifth", "label": "1997 — Fifth Edition", "edition": "fifth", "except": {}},
]

## The preset a fresh install plays under — Settings.rule's fallback, so
## the player default and the readout's name for it cannot drift apart.
const DEFAULT_PRESET := "modern_mana_burn"

## The Options screen's word for flags that match no preset.
const CUSTOM_LABEL := "Custom"

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
		"fifth": "The pool empties at the end of each PHASE — the upkeep and the draw are one each, and combat counts as one, emptying when it is over.",
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
			+ "dealt, with no window to respond in.",
		"source": "Duel.hlp topic Damage Dealing (\"During damage dealing, "
			+ "players may use only damage prevention fast effects\"); the "
			+ "prevention step was removed in Sixth Edition (1999), which is "
			+ "why modern CR 615 has replacement effects and no step",
	},
	{
		"key": "free_damage_assignment",
		"label": "Free combat damage division",
		"fifth_value": true,
		"modern_value": true,
		"fifth": "Divide an attacker's damage among its blockers however you like.",
		"modern": "The same: Foundations (2024) dropped the damage assignment "
			+ "order. Switch this off for the 2009-2024 rule, which assigned "
			+ "lethal damage to each blocker in order before the next.",
		"source": "UIStrings @PROMPT_RESOLVECOMBAT (\"%s: Assign damage to "
			+ "blockers, %d points left\"); the damage assignment order came "
			+ "with Magic 2010 (CR 509.2/510.1c, 2009) and left with "
			+ "Foundations (CR 510.1c, November 2024)",
	},
	{
		"key": "damage_effects_fixed_order",
		"label": "Fixed order for damage effects",
		"fifth_value": true,
		"fifth": "When several effects would change the same damage, they "
			+ "apply in a fixed order and nobody is asked (the 1997 game).",
		"modern": "The player — or the controller of the creature — the "
			+ "damage would hit chooses which effect applies first, then "
			+ "the rest apply to the result; the computer picks the order "
			+ "best for itself.",
		"source": "CR 616.1 (\"the affected object's controller ... or the "
			+ "affected player chooses one to apply, and then the rule is "
			+ "applied again\"); the owner's ruling of 2026-10-12 keeps the "
			+ "1997 game's fixed order as the Fifth Edition answer",
	},
	{
		"key": "sacrifice_clauses_wait",
		"label": "Forced sacrifices wait on the chain",
		"fifth_value": false,
		"fifth": "A card that must go when its condition is met — a Pirate "
			+ "Ship when you control no Islands, Goblins of the Flarg when "
			+ "you control a Dwarf — is sacrificed the moment it happens, "
			+ "with no chance to use it once more.",
		"modern": "The sacrifice waits on the Spell Chain like any other "
			+ "triggered ability, so the card gets one more use: a Pirate "
			+ "Ship can ping once more as your last Island goes. It is "
			+ "sacrificed even if an Island comes back in the meantime. "
			+ "Every preset leaves this off; switch it on to play this way.",
		"source": "CR 603.8 (a state trigger triggers once while its "
			+ "condition holds and not again until it has left the stack) "
			+ "and the modern Oracle wording \"When you control no Islands, "
			+ "sacrifice Pirate Ship\", which has no intervening \"if\"; the "
			+ "1997 printings read \"Bury ... if at any time you control no "
			+ "islands\", a check with no response. The owner's ruling of "
			+ "2026-10-13 keeps the 1997 answer under every preset",
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
## with mana_burn, which is then charged on those boundaries. The phases
## are the manual's six (p.60, `Mtg.phase_of_1997`): the upkeep and the
## draw are a phase EACH — the owner's ruling of 2026-10-21, "as separate
## phases!" — where the modern map lumps them into one beginning phase.
var pool_empties_on_attack := false

## The attacking player divides combat damage among the blockers with no
## announced ORDER and no "lethal to each before the next" constraint —
## which is what the 1997 game's own click loop was
## (`@PROMPT_RESOLVECOMBAT`: "%s: Assign damage to blockers, %d points
## left"). The damage assignment order came with Magic 2010 (CR
## 509.2/510.1c, 2009) and LEFT with Foundations (November 2024): the
## current rules divide freely again, so the 1997 game and modern Magic
## agree and this is the only fork whose `modern_value` is its
## `fifth_value`. It stays on the switchboard because the 2009-2024 order
## is a real rule real players learned, and because the engine still
## enforces it when asked. The owner's playtest (2026-09-18) — *"I should
## be able to assign damage arbitrarily amongst all blockers"* — is what
## turned the default from the 2009 answer to the 2024 one. Trample's
## own rule — every blocker must have lethal before any point spills to
## the player (CR 702.19b) — holds under BOTH, because the original
## enforced it too ("Assign trample damage to blockers" is its own later
## prompt). LIVE — MtgGame validates a split against whichever applies
## (docs/duel-todo.md §1.4, §6.9).
var free_damage_assignment := true

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

## WHO ORDERS THE DAMAGE EFFECTS (the owner's ruling of 2026-10-12). When
## two or more replacement and/or prevention effects would modify the same
## damage, the order can change what lands: a Lightning Bolt into a
## Forethought Amulet ("3 or more ... deals 2 instead") and a Furnace of
## Rath ("double that damage") deals 4 with the Amulet taken first and 2
## with the Furnace first.
##
## Modern Magic puts it to the affected one — CR 616.1: *"the affected
## object's controller ... or the affected player chooses one to apply, and
## then the rule is applied again"* — so with this OFF (the modern answer)
## the damaged player, or the damaged creature's controller, picks which
## applies first ([method MtgGame._c2o_walk_player] and
## [method MtgGame._c2o_walk_creature]); a person is shown the choice and
## the computer picks the order that leaves it the least damage
## ([method MtgGame.damage_order_outcomes]). The 1997 game asked nobody:
## ON, every walk takes the engine's fixed order — what helps the victim
## first, what hurts it last — the way the original applied its effects.
## LIVE.
var damage_effects_fixed_order := false

## THE SACRIFICE CLAUSES (the owner's ruling of 2026-10-13). "When you
## control no Islands, sacrifice this" (Pirate Ship, Sea Serpent, Dandân
## and every land type in the pool), its mirror "when you control a Dwarf"
## (Goblins of the Flarg) and the general "when <condition>, sacrifice
## this" (Jihad, Drop of Honey, Floodgate, Phyrexian Devourer ...) — the
## CardData fields `sacrifice_if_no_land_type`,
## `sacrifice_if_you_control_subtype` and `sacrifice_condition`.
##
## The 1997 printings read "Bury ... if at any time you control no
## islands": a check with no response, which is what OFF does — the
## state-based check sacrifices the permanent the moment its condition
## holds. Modern Oracle prints a STATE TRIGGER (CR 603.8): ON, the clause
## triggers once while its condition holds, waits on the stack (so the
## doomed permanent gets one more use — a Pirate Ship pings once more as
## its last Island goes), cannot trigger again while it waits, and on
## resolution sacrifices the permanent with no intervening "if" — an
## Island that came back does not save it
## ([method MtgGame._c2s_queue_clause_triggers]).
##
## OFF UNDER EVERY PRESET, the modern ones included: "leave it as is" is
## the owner's word, so this is the one fork whose default is NOT its
## modern answer, and turning it on reads "Custom". LIVE.
var sacrifice_clauses_wait := false


## CR 704.5q — "if a permanent has both a +1/+1 counter and a -1/-1
## counter on it, N +1/+1 and N -1/-1 counters are removed from it" — is
## a MODERN state-based action (Amonkhet, 2017). The Fifth Edition rules
## the 1997 game enforces (manual p.108) have nothing like it: the two
## kinds sit side by side and simply add up.
##
## NOT A FORK OF ITS OWN, and that is deliberate: a fork is an Options
## row, a settings key and a field of the LAN table rules, and this is not
## a choice the original ever offered. It follows the switch that already
## marks the Fifth/Sixth Edition boundary in this engine — the 1997
## damage-prevention step, removed with the Sixth Edition rules overhaul
## (1999) — so the "1997 — Fifth Edition" preset keeps the two kinds and
## both modern presets annihilate them; a hand-mixed ("Custom") table
## follows that fork. Derived, never stored: the referee's game
## (SgTableRules.apply) and every seat's view of the table
## (SgTableRules.options) compute it from the same transmitted forks.
func counters_annihilate() -> bool:
	return not damage_prevention_window


## Read one fork by name (the Options screen and tests address them as
## data). Unknown keys return false rather than erroring, so a stale
## setting from an older build cannot break a duel.
func get_fork(key: String) -> bool:
	return get(key) if key in self else false


## Set one fork by name. Ignores unknown keys, for the same reason.
func set_fork(key: String, value: bool) -> void:
	if key in self:
		set(key, value)


## What modern Magic answers for [param fork]: the opposite of the 1997
## answer unless the entry says otherwise with a `modern_value` — the two
## rulesets have converged on one fork since (free combat damage
## division, Foundations 2024).
static func modern_answer(fork: Dictionary) -> bool:
	return bool(fork.get("modern_value", not bool(fork["fifth_value"])))


## Turn every fork to one edition's answer. "fifth" is the 1997 game's
## ruleset (manual p.108); anything else is modern Magic.
func set_edition(edition: String) -> void:
	var fifth := edition == "fifth"
	for fork in FORKS:
		set_fork(fork["key"], fork["fifth_value"] if fifth else modern_answer(fork))


## One of [member PRESETS] by id, or `{}`.
static func find_preset(id: String) -> Dictionary:
	for preset in PRESETS:
		if preset["id"] == id:
			return preset
	return {}


## The Options screen's name for a preset id; [member CUSTOM_LABEL] for
## anything else, "custom" included.
static func preset_label(id: String) -> String:
	return String(find_preset(id).get("label", CUSTOM_LABEL))


## Turn every fork to one preset's answers: its edition, then its
## exceptions. An unknown id is plain modern — the engine's own default —
## so a stale saved name cannot break a duel.
func set_preset(id: String) -> void:
	var preset := find_preset(id)
	# Plain modern is the "Modern rules" PRESET, its exceptions included:
	# the modern edition alone would switch the sacrifice clauses' wait on
	# (2026-10-13), which no preset does.
	if preset.is_empty():
		preset = find_preset("modern")
	set_edition(String(preset.get("edition", "modern")))
	var except: Dictionary = preset.get("except", {})
	for key in except:
		set_fork(key, bool(except[key]))


## The preset the current flags match exactly — "modern",
## "modern_mana_burn", "fifth" — or "custom" when they match none. The
## Options screen shows this back; one fork off any preset's answer is
## enough for "custom", a fork the presets agree on included.
func preset() -> String:
	for candidate in PRESETS:
		var wanted := RulesOptions.new()
		wanted.set_preset(candidate["id"])
		if matches(wanted):
			return candidate["id"]
	return "custom"


## The first of [member PRESETS] whose answers match every fork named in
## [param known] (key → bool), or "" when none does. For a ruleset an
## OLDER build saved, which knew fewer forks: the forks added since take
## that preset's answers, so a 1997 table stays the 1997 table
## (`Settings._migrate_rules`, `SgTableRules.upgraded`; 2026-10-12).
static func preset_matching(known: Dictionary) -> String:
	for entry in PRESETS:
		var candidate := RulesOptions.new()
		candidate.set_preset(entry["id"])
		var same := true
		for key in known:
			if candidate.get_fork(String(key)) != bool(known[key]):
				same = false
				break
		if same:
			return String(entry["id"])
	return ""


## Every fork answered the same as [param other]'s.
func matches(other: RulesOptions) -> bool:
	for fork in FORKS:
		if get_fork(fork["key"]) != other.get_fork(fork["key"]):
			return false
	return true
