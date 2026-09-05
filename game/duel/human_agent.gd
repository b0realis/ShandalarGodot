class_name HumanAgent
extends DecisionAgent
## The human seat's DecisionAgent: the MAILBOX between the DuelScreen and
## the engine's mid-resolution choice points (docs/duel-todo.md §1.3).
##
## The engine is fully synchronous — when Demonic Tutor resolves it calls
## choose_card RIGHT THEN and needs an answer before returning. A UI can't
## pop a dialog mid-call, so the answer is always parked HERE first and the
## resolution then reads it. Three ways an answer gets here, because the
## three kinds of foresight are different:
##
## - [method accept_answer] is the main one and the engine's own door. The
##   engine PRE-FLIGHTS every resolution (MtgGame._preflight: it resolves
##   the item once over a rewind point purely to learn what it asks), holds
##   the resolution open on `awaiting_choice`, and hands the player's answer
##   here through `MtgGame.answer_choice`. Then it resolves the item for
##   real and this mailbox serves the answer. That covers every question a
##   resolution asks, from the FIRST time a card asks it.
## - [method preselect] parks the ONE card choice a cast is going to make
##   (a SearchLibraryEffect spotted in the spell being cast). It has to
##   survive from the click that casts the spell until the spell resolves,
##   which can be several priority rounds later, so nothing clears it but
##   the answer being served or the cast being abandoned.
## - [method park] is the raw form both of the above use. The engine calls
##   [method begin_resolution] / [method end_resolution] around each
##   resolution, and anything left parked is dropped at the end so an
##   unused answer can never leak into the next card's question.
##
## Answers are matched by KIND and by the CARD that asked, and served in the
## order they were parked, so a card that asks twice gets its two answers
## the right way round.
##
## Whatever is not parked falls through to DecisionAgent's heuristics —
## never a crash, but the question is filed in MtgGame.unanswered_choices
## and written into the log, so a decision made on the player's behalf is
## visible instead of invisible. That is now only the handful of asks made
## OUTSIDE a resolution — cost payments, mana abilities, the as-enters copy
## replacement — listed in docs/duel-todo.md §1.3.
##
## A probe is invisible from here: it consumes this mailbox exactly as the
## real resolution will, and [GameSnapshot] hands it back untouched.
##
## Pure logic, no Node — lives in game/ because only the UI uses it.

## Parked card choice for the pending CAST, served once by answer_card. The
## card NAME is parked rather than the instance: the picker browses the
## library, but by the time the engine searches, a shuffle may have
## replaced instances.
var _preselected_name := ""

## Answers parked for the resolution currently running, consumed in order.
## Entries are `{"kind": PlayerChoice.Kind, "value": Variant}`.
var _parked: Array = []


## Park the next answer_card answer for the pending cast ("" clears).
func preselect(card_name: String) -> void:
	_preselected_name = card_name


func has_preselection() -> bool:
	return _preselected_name != ""


## Park one answer for a resolution that has not started yet.
## [param kind] is a [enum PlayerChoice.Kind]; several may be parked and are
## served in order. [param source] names the CARD the answer is for — the
## UI knows it from MtgGame.choice_history, and naming it is what stops an
## answer meant for the upkeep trigger being served to whatever the
## opponent casts in response. "" means "the very next question".
func park(kind: int, value: Variant, source := "") -> void:
	_parked.append({"kind": kind, "value": value, "source": source})


## The engine held a resolution open on [param choice] and the player has
## answered it (MtgGame.answer_choice). Park the answer under the card that
## asked, so the re-run of that resolution serves it instead of asking again.
func accept_answer(choice: PlayerChoice, value: Variant) -> void:
	park(choice.kind, value, choice.source)


## Is anything parked?
func has_parked() -> bool:
	return not _parked.is_empty()


## Is an answer already parked for [param source]? (The UI asks before it
## offers the question again.)
func has_parked_for(source: String) -> bool:
	for entry in _parked:
		if String(entry["source"]) == source:
			return true
	return false


## Take the parked answer for [param kind] if the next one matches — and,
## when it names a card, only while THAT card is the one asking. The
## question is marked as the player's own here unless [param mark] is
## off, for a caller that still has to find out whether the parked answer
## is USABLE (answer_discard) and marks it itself once it is.
func _take(kind: int, mark := true) -> Variant:
	if _parked.is_empty() or int(_parked[0]["kind"]) != kind:
		return null
	var wanted := String(_parked[0]["source"])
	if wanted != "":
		var asking := current_choice()
		if asking == null or asking.source != wanted:
			return null
	if mark:
		mark_answered_by_player()
	return _parked.pop_front()["value"]


func begin_resolution(_source: String) -> void:
	pass   # answers are parked BEFORE the resolution starts


func end_resolution(source: String) -> void:
	# Anything this resolution did not ask for is dropped: an unnamed
	# answer is good for exactly one resolution, and a named one only
	# until its own card has resolved.
	for i in range(_parked.size() - 1, -1, -1):
		var named := String(_parked[i]["source"])
		if named == "" or named == source:
			_parked.remove_at(i)


## The human picks their OWN cleanup discard: the engine holds the turn at
## the discard phase and waits for MtgGame.discard_to_hand_size instead of
## calling choose_discard (docs/duel-todo.md §1.1). The 1997 game named
## that pause outright — `@PROMPT_DISCARD` is "Paused: Discard phase".
func wants_to_choose_discard() -> bool:
	return true


## The human divides their attackers' combat damage themselves — the
## original's `%s: Assign damage to blockers, %d points left` loop
## (docs/duel-todo.md §1.4).
func wants_to_assign_combat_damage() -> bool:
	return true


## The human gets the 1997 DAMAGE-PREVENTION WINDOW (§6.8) — the step
## `Duel.hlp` puts after every damage-dealing step, where prevention,
## healing and redirection are the only legal plays, and then the
## regeneration step after that. Saying yes here only ARMS it: the window
## still opens solely under `RulesOptions.damage_prevention_window`, which
## defaults to the modern answer of no step at all.
func wants_damage_prevention_window() -> bool:
	return true


## Everything else the engine asks mid-resolution is a question the player
## should have seen: saying so is what puts an unparked one on the record.
func wants_to_be_asked() -> bool:
	return true


func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
		prompt: String) -> CardInstance:
	var parked: Variant = _take(PlayerChoice.Kind.CARD)
	if parked != null:
		# A PERMANENT is answered by instance id (the overlay tells two
		# Grizzly Bears apart — DuelScreen.choice_card_lines); a card in a
		# hidden zone by name, since a shuffle may have replaced instances.
		for inst in candidates:
			if (inst.id == int(parked)) if parked is int \
					else (inst.data.card_name == String(parked)):
				return inst
		# The player answered and their answer is not among the candidates —
		# "" is the overlay's own "fail to find", and a stale name is not a
		# licence to grab a card they did not pick. Either way: decline.
		return null
	if _preselected_name != "":
		var wanted := _preselected_name
		_preselected_name = ""
		mark_answered_by_player()
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		# Parked name not among candidates (shouldn't happen — the picker
		# listed the same library): fail to find rather than grab a random card.
		return null
	return super.answer_card(game, pid, candidates, prompt)


func answer_yes_no(game: MtgGame, pid: int, prompt: String, hint: bool) -> bool:
	var parked: Variant = _take(PlayerChoice.Kind.YES_NO)
	if parked != null:
		return bool(parked)
	return super.answer_yes_no(game, pid, prompt, hint)


func answer_color(game: MtgGame, pid: int, prompt: String, hint: int) -> int:
	var parked: Variant = _take(PlayerChoice.Kind.COLOR)
	if parked != null:
		return int(parked)
	return super.answer_color(game, pid, prompt, hint)


## "Choose one of these labelled things", answered by INDEX — Shapeshifter's
## number, Gabriel Angelfire's ability, Petra Sphinx's card name
## (DecisionAgent.choose_option). Same shape as answer_color: the overlay
## parks the index it was clicked on. `choose_option` clamps whatever comes
## back into range, so a stale index cannot reach a card.
func answer_option(game: MtgGame, pid: int, prompt: String,
		options: Array[String], hint: int) -> int:
	var parked: Variant = _take(PlayerChoice.Kind.OPTION)
	if parked != null:
		return int(parked)
	return super.answer_option(game, pid, prompt, options, hint)


## The human seat can be shown all FIVE kinds: the duel overlay grew its
## OPTION case on 2026-09-01 (docs/duel-todo.md §1.3), so an OPTION question
## no longer has to fall through to the heuristic to avoid a buttonless
## dialog. Any front end WITHOUT that case must not widen this.
func can_answer(choice: PlayerChoice) -> bool:
	return choice.kind == PlayerChoice.Kind.OPTION or super.can_answer(choice)


## An EFFECT's discard (Hypnotic Specter's random pick, Bazaar of Baghdad's
## discard to library) — not the cleanup discard, which holds the turn open
## instead (wants_to_choose_discard). The overlay hands back the whole set of
## cards, by name, and they are matched against the hand as it stands now.
func answer_discard(game: MtgGame, pid: int, count: int) -> Array[CardInstance]:
	# Not marked as the player's yet: a stale pick below falls through to
	# the heuristic, and an answer the referee gave belongs on the
	# unanswered ledger, whatever the player had parked (2026-09-02).
	var parked: Variant = _take(PlayerChoice.Kind.DISCARD, false)
	if parked == null:
		return super.answer_discard(game, pid, count)
	var wanted: Array = parked if parked is Array else []
	var hand: Array[CardInstance] = game.players[pid].hand.duplicate()
	var out: Array[CardInstance] = []
	for name in wanted:
		for inst in hand:
			if inst.data.card_name == String(name):
				out.append(inst)
				hand.erase(inst)
				break
	if out.size() < mini(count, game.players[pid].hand.size()):
		return super.answer_discard(game, pid, count)   # stale pick
	mark_answered_by_player()
	return out
