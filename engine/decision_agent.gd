class_name DecisionAgent
extends RefCounted
## The engine's interface for MID-RESOLUTION player decisions — choices
## that can't be supplied upfront like targets: what to discard, whether
## to pay an optional cost, which card to fetch from a searched zone.
##
## One agent per seat (MtgGame.agents, replaceable via set_agent). Three
## implementations exist:
## - THIS base class: sensible heuristic defaults, used for any seat
##   nobody claimed. Every method documents its default.
## - AiPlayer (engine/ai/): the AI opponent overrides these with real
##   evaluation.
## - HumanAgent (game/duel/): the human seat. The engine PRE-FLIGHTS each
##   resolution to find what it will ask and HOLDS it open until the player
##   answers (MtgGame.awaiting_choice → answer_choice → [method
##   accept_answer]); the few asks a pre-flight cannot reach fall through to
##   the heuristic — and are LEDGERED as such rather than decided invisibly
##   (docs/duel-todo.md §1.3).
##
## ══ THE EXTENSION POINTS ARE `answer_*`, `wants_*`, and `accept_answer`.
## OVERRIDE NOTHING ELSE. ══
##
## `answer_yes_no` · `answer_card` · `answer_color` · `answer_discard` ·
## `answer_option` · `order_blockers` · `assign_combat_damage` ·
## `choose_mulligan` · `wants_to_be_asked` · `wants_to_choose_discard` ·
## `wants_to_assign_combat_damage` · `can_answer` · `accept_answer`. That is
## the list. A test agent, the AI and the human seat all subclass at exactly
## that layer.
##
## THE FIVE PRIMITIVES, and why each is two methods.
## `choose_yes_no` / `choose_card` / `choose_color` / `choose_discard` /
## `choose_option` are
## the FUNNEL the engine and the cards call: each builds a [PlayerChoice],
## asks this agent's `answer_*` for the decision, and files the question on
## the game (MtgGame.record_choice — the choice_requested signal, the
## choice_log, the unanswered ledger and the per-card choice_history).
## OVERRIDING A `choose_*` TAKES THE QUESTION OFF THE RECORD — the pre-flight
## then cannot see it coming, the ledger never learns it was asked, and the
## override silently stops matching the moment the funnel grows a parameter
## (`choose_card` grew `optional` on 2026-08-31, which is exactly how this
## paragraph earned its capitals). GDScript does not refuse a mismatched
## override; it fails at RUNTIME, inside whichever card happens to ask.
##
## Contract: agents READ game state freely but never mutate — they return
## choices; the engine acts on them. Determinism: any randomness must use
## game.rng, never global RNG. And an `answer_*` may be called during a
## PROBE (MtgGame.is_probing) that is about to be rewound: keep no state
## outside your own script variables, which [GameSnapshot] restores for you.


# ------------------------------------------------------- the ask/answer --

## Does this seat expect to answer its own mid-resolution questions? The
## human seat says true, which is what turns a heuristic answer into an
## entry in MtgGame.unanswered_choices and a line in the game log; every
## other seat answers its own questions by definition.
func wants_to_be_asked() -> bool:
	return false


## Can this seat answer a question of [param choice]'s KIND for itself?
## The pre-flight only holds a resolution open for a kind that comes back
## true here (docs/duel-todo.md §1.3); any other kind falls through to the
## heuristic and is LEDGERED as such, exactly like the six call sites a
## probe cannot reach at all. Without this gate a front end that has no
## case for a kind would be handed a question it can render no buttons for
## and the duel would stop dead.
##
## The default is the FOUR kinds every front end has been able to show
## since §1.3 shipped. [constant PlayerChoice.Kind.OPTION] is deliberately
## NOT among them: it arrived later (Shapeshifter's "choose a number",
## Gabriel Angelfire's "choose an ability", Petra Sphinx's "choose a card
## name"), and a front end takes it on by OVERRIDING this — which the
## duel screen's [HumanAgent] does, since its overlay grew the OPTION
## case on 2026-09-01. The base stays at four so that any other front
## end without that case is never handed a buttonless question.
func can_answer(choice: PlayerChoice) -> bool:
	return choice.kind == PlayerChoice.Kind.YES_NO \
		or choice.kind == PlayerChoice.Kind.CARD \
		or choice.kind == PlayerChoice.Kind.COLOR \
		or choice.kind == PlayerChoice.Kind.DISCARD


## Take an answer the ENGINE collected for a question it held a resolution
## open on (MtgGame.awaiting_choice → MtgGame.answer_choice). The resolution
## is about to be re-run from the top, so the agent's job is to have this
## answer ready when the same question comes round again — see
## [method HumanAgent.park]. No-op in the base class and in the AI, neither
## of which is ever held open (both say no to
## [method wants_to_be_asked]).
func accept_answer(_choice: PlayerChoice, _value: Variant) -> void:
	pass


## Called around each stack resolution so an agent can scope answers the UI
## parked for exactly that resolution. [param source] is the resolving
## card's name, "" for an anonymous one. No-ops in the base class.
func begin_resolution(_source: String) -> void:
	pass


func end_resolution(_source: String) -> void:
	pass


## Does this seat want to be ASKED for the cleanup discard rather than have
## [method choose_discard] answer for it? A seat that says yes makes the
## turn machine stop at the discard phase (MtgGame.awaiting_discard) and
## wait for [method MtgGame.discard_to_hand_size], exactly as it already
## stops for attackers and blockers.
##
## Default false: the heuristic agent, the AI and every headless test
## answer their own discard and the turn never pauses. The human seat says
## true — the 1997 game had a named Discard Phase with its own prompt
## (`@PROMPT_DISCARD`, "Paused: Discard phase") and its own phase-bar icon,
## and the player, not the referee, picked the cards.
func wants_to_choose_discard() -> bool:
	return false


## Does this seat want the 1997 DAMAGE-PREVENTION WINDOW (§6.8) — the step
## `Duel.hlp` puts after every damage-dealing step, where the only legal
## actions are effects that "prevent, heal, or redirect damage", followed
## by the regeneration step where the only legal action is regenerating
## something about to die?
##
## Default FALSE, and that is load-bearing: with the window off, damage
## lands the moment it is dealt exactly as it always has, so an AI-only
## duel never pauses and the whole headless suite never sees the step.
## Only a seat that says true here — the human — makes the engine hold the
## damage. The RULES FORK (`RulesOptions.damage_prevention_window`) has to
## be on as well; both gates, or no window.
func wants_damage_prevention_window() -> bool:
	return false


## Choose [param count] cards to discard from [param pid]'s hand (cleanup
## discard, Disrupting Scepter...). Must return exactly count cards from
## the hand (fewer only if the hand is smaller).
## Default: highest mana value first — dump expensive uncastables.
func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	var hand := game.players[pid].hand.duplicate()
	hand.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value())
	var out: Array[CardInstance] = []
	for i in mini(count, hand.size()):
		out.append(hand[i])
	return out


# ------------------------------------------------------ combat damage --
#
# CR 510.1c gives the ATTACKING player the division of an attacker's combat
# damage among its blockers, and CR 509.2 gives them the order. The 1997
# game ran the division as a click loop with a live counter —
# `@PROMPT_RESOLVECOMBAT`: "%s: Assign damage to blockers, %d points left"
# — and had no order at all (RulesOptions.free_damage_assignment).

## Does this seat want to be ASKED for each combat damage division rather
## than have [method assign_combat_damage] answer for it? A seat that says
## yes makes the damage step stop (MtgGame.awaiting_damage_assignment) and
## wait for [method MtgGame.assign_combat_damage]. Default false, so the
## AI, the heuristic agent and every headless test are unchanged.
func wants_to_assign_combat_damage() -> bool:
	return false


## The DAMAGE ASSIGNMENT ORDER (CR 509.2), announced as blockers are
## declared: return [param blocker_ids] permuted. Default: the order the
## defender declared them in, which is what the engine always did.
func order_blockers(_game: MtgGame, _attacker: CardInstance,
		blocker_ids: Array) -> Array:
	return blocker_ids


## Divide [param amount] of [param source]'s combat damage among
## [param targets] (blocker ids in assignment order, or the attackers a
## blocker is facing). Return id -> points; the key
## [constant MtgGame.DAMAGE_TO_PLAYER] is the defending player, legal only
## when [param trample] is true and every blocker already has lethal.
## [param already] is what this damage step has assigned to each creature
## so far, so "lethal" accounts for it.
##
## [param free_order] is true when DEFENSIVE BANDING has handed this
## division to the DEFENDING player (CR 702.22f-h): the seat being asked
## owns the blockers, and the lethal-first order of CR 510.1c does not
## apply, so any distribution totalling [param amount] is legal.
##
## Default: the engine's own lethal-first spread — see
## [method MtgGame.default_damage_split], which switches to a
## defender-minded spread when [param free_order] is set. An answer the
## engine judges illegal is replaced by that same default rather than
## refused.
func assign_combat_damage(game: MtgGame, source: CardInstance,
		targets: Array, amount: int, trample: bool,
		already: Dictionary, free_order := false) -> Dictionary:
	return game.default_damage_split(source, targets, amount, trample, already,
		free_order)


## Take the one mulligan the Shandalar rule allows (docs/duel-todo.md
## §1.5)? [param own_hand_qualifies] is true when this seat's own hand is a
## mulligan hand (no land or all land) and false when the offer exists only
## because the opponent redrew — `Duel.hlp`'s *"The other player has the
## option to do so as well"*.
## Default: redraw a mulligan hand, keep an ordinary one.
func choose_mulligan(_game: MtgGame, _pid: int, own_hand_qualifies: bool) -> bool:
	return own_hand_qualifies


## Yes/no decision ("Pay {4} to untap?"). [param hint] is the caller's
## computed sensible answer (e.g. "can afford it"); the default agent
## simply follows the hint.
func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, hint: bool) -> bool:
	return hint


## Pick one card from [param candidates] (library search — Demonic Tutor).
## Returning null means "fail to find"/decline, legal where searches are.
## Default: the first candidate (callers pre-sort by desirability).
func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
		_prompt: String) -> CardInstance:
	return null if candidates.is_empty() else candidates[0]


## Choose a COLOUR (or colours) — "becomes the color of your choice"
## (Alchor's Tomb, Dream Coat), "choose a color" (Jihad-style cards).
## Returns an Mtg.ManaColor bitmask. [param hint] is the caller's computed
## sensible answer; the default agent follows it, which keeps every card
## that asks playable without a UI prompt.
func answer_color(_game: MtgGame, _pid: int, _prompt: String, hint: int) -> int:
	return hint


## Pick ONE of [param options] by index — the kind of question whose
## choices are neither yes/no, a colour, nor a card: "choose a number
## between 0 and 7" (Shapeshifter), "choose flying, first strike, trample,
## or rampage 3" (Gabriel Angelfire), "choose a card name" (Petra Sphinx).
## [param hint] is the caller's computed sensible answer, already an index
## into [param options]; the default agent follows it, so every card that
## asks stays playable without a prompt. An override that wants the
## question's own context (a number's range, whose library the names came
## from) reads [method current_choice].
func answer_option(_game: MtgGame, _pid: int, _prompt: String,
		_options: Array[String], hint: int) -> int:
	return hint


# ------------------------------------------------------------ the funnel --
#
# Do not override these — override the answer_* above. Each one builds the
# question, takes this agent's answer, and files it on the game so that no
# mid-resolution decision is ever made off the record (docs/duel-todo.md
# §1.3). `answered_by_player` starts false and an agent that served a
# PARKED answer flips it in its answer_* override via
# [method mark_answered_by_player].

## True while the funnel is filling one PlayerChoice — an answer_* override
## that served a real player choice calls [method mark_answered_by_player].
var _current_choice: PlayerChoice = null


## The question being filled in right now — an answer_* override reads it
## to match a parked answer against the card that is asking.
func current_choice() -> PlayerChoice:
	return _current_choice


## An answer_* override calls this when the answer it is about to return
## came from the player rather than from a heuristic.
func mark_answered_by_player() -> void:
	if _current_choice != null:
		_current_choice.answered_by_player = true


func choose_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	# `@PROMPT_DISCARDACARD` entry 1, Program/UIStrings.txt:1106 — the
	# original's own words, and the only one of the four the caller does
	# not supply.
	var choice := PlayerChoice.new(PlayerChoice.Kind.DISCARD, pid,
		"Select card to discard.")
	choice.count = count
	choice.candidates = game.players[pid].hand.duplicate()
	choice.source = game.current_resolution_source()
	choice.step = game.current_step()
	choice.is_cost = game.is_paying_cost()
	_current_choice = choice
	var picked := answer_discard(game, pid, count)
	choice.answer = picked
	_file(game, choice)
	return picked


func choose_yes_no(game: MtgGame, pid: int, prompt: String, hint: bool) -> bool:
	var choice := PlayerChoice.new(PlayerChoice.Kind.YES_NO, pid, prompt, hint)
	choice.source = game.current_resolution_source()
	choice.step = game.current_step()
	choice.is_cost = game.is_paying_cost()
	_current_choice = choice
	var said := answer_yes_no(game, pid, prompt, hint)
	choice.answer = said
	_file(game, choice)
	return said


## [param optional] is true where declining is legal — a library search may
## "fail to find" (CR 701.19b). Where it is false the caller replaces a null
## answer with the first candidate, so the overlay must not offer a way out.
## [param ordered] says the candidates come ranked best-first for the seat
## (a targeted trigger's list, [member PlayerChoice.ordered]).
func choose_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
		prompt: String, optional := false, adverse := false,
		ordered := false) -> CardInstance:
	var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, pid, prompt)
	choice.candidates = candidates.duplicate()
	choice.optional = optional
	# An ADVERSE ask ("… of an opponent's choice", see
	# [member PlayerChoice.adverse]) comes pre-sorted from the chooser's
	# point of view, so its hint is the first candidate — and so does an
	# ORDERED one.
	choice.adverse = adverse
	choice.ordered = ordered
	if (adverse or ordered) and not candidates.is_empty():
		choice.hint = candidates[0]
	choice.source = game.current_resolution_source()
	choice.step = game.current_step()
	choice.is_cost = game.is_paying_cost()
	_current_choice = choice
	var picked := answer_card(game, pid, candidates, prompt)
	choice.answer = picked
	_file(game, choice)
	return picked


func choose_color(game: MtgGame, pid: int, prompt: String, hint: int) -> int:
	var choice := PlayerChoice.new(PlayerChoice.Kind.COLOR, pid, prompt, hint)
	choice.source = game.current_resolution_source()
	choice.step = game.current_step()
	choice.is_cost = game.is_paying_cost()
	_current_choice = choice
	var picked := answer_color(game, pid, prompt, hint)
	choice.answer = picked
	_file(game, choice)
	return picked


## Choose one of [param options], returning its INDEX. [param hint] is an
## index too, and is clamped into range — a card that computes its own
## sensible default cannot make the funnel return something out of bounds.
## The labels are the card's business: this funnel never interprets them.
func choose_option(game: MtgGame, pid: int, options: Array[String],
		prompt: String, hint := 0, adverse := false, ordered := false) -> int:
	if options.is_empty():
		return -1
	var safe_hint: int = clampi(hint, 0, options.size() - 1)
	var choice := PlayerChoice.new(PlayerChoice.Kind.OPTION, pid, prompt,
		safe_hint)
	choice.options = options.duplicate()
	choice.adverse = adverse
	choice.ordered = ordered
	choice.source = game.current_resolution_source()
	choice.step = game.current_step()
	choice.is_cost = game.is_paying_cost()
	_current_choice = choice
	var picked: int = clampi(
		answer_option(game, pid, prompt, options, safe_hint),
		0, options.size() - 1)
	choice.answer = picked
	_file(game, choice)
	return picked


## "Choose a number between [param minimum] and [param maximum]" — one
## OPTION question whose labels are the numbers themselves, answered with
## the NUMBER rather than its index. Sugar over [method choose_option], not
## a fifth primitive: there is nothing to override here.
func choose_number(game: MtgGame, pid: int, minimum: int, maximum: int,
		prompt: String, hint := 0) -> int:
	if maximum < minimum:
		return minimum
	var labels: Array[String] = []
	for n in range(minimum, maximum + 1):
		labels.append(str(n))
	var index := choose_option(game, pid, labels, prompt, hint - minimum)
	return minimum if index < 0 else minimum + index


func _file(game: MtgGame, choice: PlayerChoice) -> void:
	_current_choice = null
	if game != null:
		game.record_choice(choice, wants_to_be_asked())
