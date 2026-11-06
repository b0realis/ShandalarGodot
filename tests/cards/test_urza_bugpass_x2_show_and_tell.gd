extends GameTest
## The 0.60.19 bug pass (Pack 10), Show and Tell's hidden choices.
##
## CR 101.4a: cards chosen from a hidden zone may stay face down until every
## player has chosen. Show and Tell: the active player chooses, then the
## opponent chooses WITHOUT knowing what — no reveal, no log line naming
## it, nothing on the question (PlayerChoice.information, which a human
## seat and a LAN guest are shown) and nothing an AI could read — and only
## then are both revealed and put onto the battlefield together. The
## active player's choice used to be revealed and logged as it was made.

const U := Mtg.ManaColor.U


## A scripted seat: yes/no (-1 the hint), a card by name when offered (else
## the first candidate), and at every ask a note of what this seat could
## read of the table then — the log as this seat reads it and every
## reveal so far (the test fills `reveals`).
class Seat extends DecisionAgent:
	var yes := -1
	var prefer: Array = []
	var asked: Array = []
	var reveals: Array = []
	var record_seen: Array = []
	func answer_yes_no(game: MtgGame, pid: int, prompt: String, hint: bool) -> bool:
		_note(game, pid, prompt)
		return hint if yes < 0 else yes == 1
	func answer_card(game: MtgGame, pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		_note(game, pid, prompt)
		for card_name in prefer:
			for c in candidates:
				if c.data.card_name == card_name: return c
		return null if candidates.is_empty() else candidates[0]
	func _note(game: MtgGame, pid: int, prompt: String) -> void:
		asked.append(prompt)
		record_seen.append(Table.record(game, pid, reveals))


## The real AI, with a note at every ask of what it could read then.
class SpyAi extends AiPlayer:
	var reveals: Array = []
	var record_seen: Array = []
	var answers: Array = []
	func answer_yes_no(game: MtgGame, p_pid: int, prompt: String, hint: bool) -> bool:
		record_seen.append([AiObservation.key(game, p_pid), Table.record(game, p_pid, reveals)])
		var said := super(game, p_pid, prompt, hint)
		answers.append(said)
		return said
	func answer_card(game: MtgGame, p_pid: int, candidates: Array[CardInstance],
			prompt: String) -> CardInstance:
		record_seen.append([AiObservation.key(game, p_pid), Table.record(game, p_pid, reveals)])
		var pick := super(game, p_pid, candidates, prompt)
		answers.append(pick.data.card_name if pick != null else "")
		return pick


## Everything [param seat] may read of the table: the log as that seat reads
## it (a line private to the other seat by its public text) and the reveals
## shown to it.
class Table:
	static func record(game: MtgGame, seat: int, reveals: Array) -> Array:
		var lines: Array = []
		for i in game.log_lines.size():
			var meta: Dictionary = game.log_meta[i]
			var private_to := int(meta.get("private_to", -1))
			lines.append(String(game.log_lines[i]) if private_to == -1 or private_to == seat
				else String(meta.get("public", "")))
		var shown: Array = []
		for row in reveals:
			if int(row[0]) in [-1, seat]: shown.append(row[2].duplicate())
		return [lines, shown]


var me: Seat
var foe: Seat
var reveals: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super()
	reveals = []
	me = Seat.new()
	foe = Seat.new()
	me.reveals = reveals
	foe.reveals = reveals
	g.set_agent(0, me)
	g.set_agent(1, foe)
	g.information_revealed.connect(func(viewer: int, title: String, names: Array) -> void:
		reveals.append([viewer, title, names.duplicate()]))
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _cast_show_and_tell() -> void:
	var spell := give_hand(0, "Show and Tell")
	add_mana(0, U, 3)
	assert_ok(g.cast_spell(0, spell))


static func _names(record: Array, card_name: String) -> bool:
	for line in record[0]:
		if String(line).contains(card_name): return true
	for names in record[1]:
		if (names as Array).has(card_name): return true
	return false


func test_the_second_chooser_does_not_know_the_first_choice() -> void:
	var wurm := give_hand(0, "Craw Wurm")
	var giant := give_hand(1, "Hill Giant")
	_cast_show_and_tell()
	resolve_stack()
	assert_eq(foe.record_seen.size(), 2, "the opponent was asked (may, then which)")
	for record in foe.record_seen:
		assert_false(_names(record, "Craw Wurm"),
			"nothing the second chooser could read named the first choice (CR 101.4a)")
	# Then both are revealed, the active player's first, and arrive together.
	var shown: Array = []
	for row in reveals:
		if int(row[0]) == -1: shown.append(row[2])
	assert_eq(shown, [["Craw Wurm"], ["Hill Giant"]], "both revealed once both have chosen")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.controller_id, 1)


func test_whether_the_first_player_chose_at_all_is_hidden_too() -> void:
	give_hand(0, "Craw Wurm")
	give_hand(1, "Hill Giant")
	me.yes = 0
	_cast_show_and_tell()
	resolve_stack()
	var declined: Array = foe.record_seen.duplicate()
	g = null
	before_each()
	give_hand(0, "Craw Wurm")
	give_hand(1, "Hill Giant")
	_cast_show_and_tell()
	resolve_stack()
	assert_eq(foe.record_seen, declined, "the second chooser reads the same table either way")


func test_the_ai_second_chooser_reads_the_same_table_whatever_was_chosen() -> void:
	var outcomes: Array = []
	for first in ["Craw Wurm", "Grizzly Bears"]:
		g = null
		before_each()
		var profile := AiProfile.wizard()
		profile.mistake_chance = 0.0
		var ai := SpyAi.new(1, profile)
		ai.reveals = reveals
		g.set_agent(1, ai)
		me.prefer = [first]
		give_hand(0, "Craw Wurm")
		give_hand(0, "Grizzly Bears")
		give_hand(1, "Hill Giant")
		give_hand(1, "Llanowar Elves")
		_cast_show_and_tell()
		resolve_stack()
		assert_false(ai.record_seen.is_empty(), "the AI was asked")
		outcomes.append([ai.record_seen.duplicate(true), ai.answers.duplicate()])
	assert_eq(outcomes[0], outcomes[1],
		"rule 8: the AI's view and answers do not depend on the hidden first choice")


func test_a_human_second_chooser_is_not_shown_the_first_choice() -> void:
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	var wurm := give_hand(0, "Craw Wurm")
	var giant := give_hand(1, "Hill Giant")
	_cast_show_and_tell()
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	var answers := 0
	while g.awaiting_choice != null and answers < 4:
		var asked := g.awaiting_choice
		assert_eq(asked.pid, 1)
		assert_false(asked.prompt.contains("Craw Wurm"))
		for info in asked.information:
			assert_false((info.cards as Array).has("Craw Wurm"),
				"the question shows nothing of the first choice: %s" % str(info))
		assert_false(_names(Table.record(g, 1, reveals), "Craw Wurm"),
			"no log line, no reveal of it yet")
		assert_ok(g.answer_choice(true if asked.kind == PlayerChoice.Kind.YES_NO else "Hill Giant"))
		answers += 1
	assert_gt(answers, 0, "the human was asked")
	resolve_stack()
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(_names(Table.record(g, 1, reveals), "Craw Wurm"), "revealed once both had chosen")


func test_a_lan_guest_choosing_second_is_not_sent_the_hosts_choice() -> void:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	var angel := give_hand(0, "Serra Angel")
	var wurm := give_hand(1, "Craw Wurm")
	_cast_show_and_tell()
	var guard := 0
	while g.awaiting_choice == null and not g.stack.is_empty() and guard < 10:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	guard = 0
	while g.awaiting_choice != null and g.awaiting_choice.pid == 0 and guard < 6:
		assert_ok(g.answer_choice("Serra Angel" if g.awaiting_choice.kind == PlayerChoice.Kind.CARD else true))
		guard += 1
	assert_not_null(g.awaiting_choice, "then the guest")
	guard = 0
	while g.awaiting_choice != null and guard < 6:
		assert_eq(g.awaiting_choice.pid, 1)
		assert_false(SgProtocol.encode(referee.view(1)).contains("Serra Angel"),
			"the guest's view names nothing of the host's choice")
		assert_ok(g.answer_choice("Craw Wurm" if g.awaiting_choice.kind == PlayerChoice.Kind.CARD else true))
		guard += 1
	resolve_stack()
	assert_eq(angel.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD, "both arrived together")
