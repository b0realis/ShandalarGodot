class_name PlayerChoice
extends RefCounted
## ONE MID-RESOLUTION QUESTION — the object docs/duel-todo.md §1.3 is
## about. Every time the engine stops mid-resolution and asks a seat
## something it could not be told in advance ("Pay {U} to keep Stasis?",
## "Choose a color", "Sacrifice an Island", "which cards do you discard")
## the question is built here, answered, and filed on the game.
##
## Why it exists as an object rather than four bare method calls: the
## engine is fully synchronous, so a UI cannot open a dialog in the middle
## of a resolution (DecisionAgent's header explains). Making the question a
## first-class value means it can be
## - ANNOUNCED, on MtgGame.choice_requested, so nothing is decided silently;
## - LEDGERED, in MtgGame.choice_log and MtgGame.unanswered_choices, so a
##   heuristic answer given on a human's behalf is visible rather than
##   invisible; and
## - REMEMBERED, in MtgGame.choice_history, so the SECOND time a card asks
##   the same question — every upkeep, for most of this pool — the UI knows
##   it is coming and can park the player's own answer beforehand.
##
## Read-only for everyone but DecisionAgent, which fills [member answer].

enum Kind {
	YES_NO,    ## "you may pay" / "unless you pay" — answer is a bool
	CARD,      ## pick one CardInstance from candidates (null = decline)
	COLOR,     ## an Mtg.ManaColor bitmask
	DISCARD,   ## choose [member count] cards from your hand
	OPTION,    ## pick one of [member options] — answer is its INDEX
}

## Which of the primitives was asked.
var kind: int = Kind.YES_NO

## The seat being asked.
var pid: int = 0

## The question, in the caller's own words — the string a UI shows.
## `choose_discard` has no prompt parameter, so the engine writes one.
var prompt: String = ""

## The card whose resolution asked, "" when the question came from the turn
## machine rather than from a resolving spell or ability.
var source: String = ""

## The Mtg.Step the question was asked in, -1 outside a game. It is what
## tells an UPKEEP COST ("Pay {B}{B} to keep Junún Efreet?") from any other
## "you may pay", and the two have different buttons in 1997
## (`@PROMPT_PAYUPKEEP`, docs/duel-todo.md §6.17).
var step: int = -1

## The heuristic's suggestion — what the base DecisionAgent would say.
var hint: Variant = null

## What was actually decided.
var answer: Variant = null

## True when the seat's own agent supplied the answer from something the
## player chose (a parked answer), false when a heuristic stood in.
var answered_by_player := false

## DISCARD only: how many cards were wanted.
var count := 0

## CARD and DISCARD: what there was to choose from — the searched library's
## matches, or the hand. Carried so the pre-flight can put the same list in
## front of the player that the engine put in front of the heuristic
## (docs/duel-todo.md §1.3). Empty for YES_NO and COLOR, whose options are
## fixed.
var candidates: Array[CardInstance] = []

## OPTION only: the labelled things there are to choose between, in the
## order the answer INDEXES them. This is the one kind whose choices are
## neither fixed (YES_NO, COLOR) nor cards (CARD, DISCARD): "choose a
## number between 0 and 7" (Shapeshifter), "choose flying, first strike,
## trample, or rampage 3" (Gabriel Angelfire), "choose a card name"
## (Petra Sphinx). The caller writes the labels and reads the index back,
## so nothing here needs to know what an option MEANS.
var options: Array[String] = []

## CARD only: may the seat decline? A library search may "fail to find"
## (CR 701.19b); a cost's sacrifice pick may not.
var optional := false

## CARD and OPTION: is the seat choosing AGAINST ITSELF — which of its own
## creatures a Preacher takes, which of its bodies steps into the Arena,
## where a Cuombajj Witches' second shot lands ("… of an opponent's
## choice")? The candidates then come ordered from the chooser's point of
## view, best first, and [member hint] is that first one; a heuristic
## seat takes it instead of the "most valuable" pick it makes when it is
## choosing FOR itself (a tutor, a Clone).
var adverse := false

## CARD and OPTION: do the candidates come ORDERED, best first from the
## chooser's own point of view, with [member hint] the first of them? A
## targeted TRIGGER's question does (TriggeredAbility.target_order): the
## card ranked the legal targets for its controller, so a heuristic seat
## takes the first rather than the "most valuable" pick it makes for a
## tutor — a Djinn's controller hands forestwalk to the WORST enemy body,
## not the best. [member adverse] implies the same ordering; this flag
## says so for a seat choosing FOR itself.
var ordered := false


## COLOR only: the Mtg.ManaColor flags on offer, in the order a UI should
## list them. Empty means "any of the five", which is what every colour
## question asked inside a resolution means (Alchor's Tomb, Dream Coat).
## Fellwar Stone is the one that narrows it: "any color that a land an
## opponent controls could produce" is a census, and offering a colour that
## census does not include would be offering something the rules do not.
var colors: Array[int] = []


## Was this asked while a COST was being assembled (CR 601.2h) rather than
## while a spell or ability RESOLVED (CR 608)? The distinction is the whole
## of docs/duel-todo.md §1.3's last four rows: a cost is paid before its
## spell is on the stack, and a mana ability never touches the stack at all
## (CR 605.3a), so the PRE-FLIGHT — which probes a stack resolution — cannot
## reach these questions. They are held open a different way (the action is
## simply re-issued, [method MtgGame.answer_choice]) and they wear different
## 1997 words, so the front end has to be able to tell them apart.
var is_cost := false


## The 1997 game's own words for "which one goes?".
## `@SACRIFICE_ARTIFACT` / `@SACRIFICE_CREATURE` / `@SACRIFICE_ENCHANTMENT`
## / `@SACRIFICE_LAND` (Program/Text.res:2645-2659) are all
## `Select <what> to sacrifice.`, and `@SACRIFICE_LANDS` (`:2661-2667`)
## spells the five basics in lower case (`Select swamp to sacrifice.`).
## Every per-card tag in the prompt tables says the same sentence —
## `@SACRIFICE` (promptsX1.txt:364), `@METAMORPHOSIS` (`:256`),
## `@ASHNODS_ALTAR` (`:45`), `@ATOG` (`:53`), `@PRIEST_OF_YAWGMOTH` (`:312`),
## `@ORCISH_MECHANICS` (`:291`), `@SAGE_OF_LAT_NAM` (`:368`),
## `@GATE_TO_PHYREXIA` (`:182`), `@FALLEN_ANGEL` (promptsX2.txt:46),
## `@LIFE_CHISEL` (`:81`) — so the wording is GENERIC in the original too,
## and this builds it from the cost's own description.
static func sacrifice_prompt(what: String) -> String:
	# `@SACRIFICE_LANDS` names the basics in lower case; every other
	# description is the cost's own noun phrase and keeps its capitals
	# ("other Orc or Goblin" — Orc General).
	var noun := what.to_lower() if BASIC_LAND_NAMES.has(what) else what
	return "Select %s to sacrifice." % noun


## The five the original spells out in `@SACRIFICE_LANDS`.
const BASIC_LAND_NAMES := ["Plains", "Island", "Swamp", "Mountain", "Forest"]


## `@MULTIMANA` (Program/Text.res:2057-2059) — `%s: What kind of mana?`,
## the original's line for every source whose colour you choose as you tap
## it (the duals, City of Brass, Birds of Paradise), and the exact sentence
## `@FELLWAR_STONE` (prompts.txt:372-374) spells out for the one such card
## our pool has: `Fellwar Stone: What kind of mana?`.
static func mana_color_prompt(source_name: String) -> String:
	return "%s: What kind of mana?" % source_name


func _init(p_kind: int, p_pid: int, p_prompt: String, p_hint: Variant = null) -> void:
	kind = p_kind
	pid = p_pid
	prompt = p_prompt
	hint = p_hint


## One line for the game log and for the UI's "the referee decided this for
## you" notice.
func describe() -> String:
	var said := str(answer)
	match kind:
		Kind.YES_NO:
			said = "yes" if bool(answer) else "no"
		Kind.CARD:
			said = "nothing" if answer == null \
				else (answer as CardInstance).data.card_name
		Kind.COLOR:
			said = ChangeColorEffect.color_name(int(answer)) \
				if answer != null else "none"
		Kind.DISCARD:
			var names := PackedStringArray()
			for inst in (answer if answer is Array else []):
				names.append((inst as CardInstance).data.card_name)
			said = ", ".join(names) if names.size() > 0 else "nothing"
		Kind.OPTION:
			var picked := int(answer) if answer != null else -1
			said = options[picked] if picked >= 0 and picked < options.size() \
				else "nothing"
	return "%s — %s" % [prompt, said]
