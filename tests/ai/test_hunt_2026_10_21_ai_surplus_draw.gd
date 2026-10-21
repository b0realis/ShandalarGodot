extends GameTest
## THE ANCESTRAL THE CLEANUP THREW AWAY (bug hunt 2026-10-21, ai; the
## morning review's "It discarded Ancestral Recall at cleanup instead of
## casting it").
##
## At its own end step over the hand size, the pilot fires the instant the
## cleanup would discard ([method AiPlayer._fire_surplus_instants], campaign
## w2-8) — but a draw was skipped on purpose, "it only grows the hand". The
## hand it grows is the one the cleanup cuts anyway: cast, the Recall is
## the best seven of ten cards kept; discarded, the same seven and the
## Recall gone. With two Islands open and seven Grizzly Bears it could not
## cast, the Wizard discarded the Recall.
##
## Now a draw the discard would take is cast first, at our own seat — and
## never into the end of a library, the control below.


func after_each() -> void:
	g = null


## Drive seat 0's own turn 1 to its end (seat 1 passes).
func _drive_own_turn(ai: AiPlayer) -> void:
	var guard := 0
	while g.turn_number == 1 and guard < 80:
		if g.priority_player == 0 or g.awaiting_attackers:
			var did := ai.act(g)
			if did == "":
				if g.priority_player == 0: g.pass_priority(0)
				elif g.awaiting_attackers: g.declare_attackers(0, [])
		else:
			g.pass_priority(g.priority_player)
		guard += 1


func _board() -> CardInstance:
	for n in 2: put_battlefield(0, "Island")
	for n in 7: give_hand(0, "Grizzly Bears")
	return give_hand(0, "Ancestral Recall")


func test_the_doomed_ancestral_is_cast_before_the_discard() -> void:
	var recall := _board()
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.MAIN2)
	var library := g.players[0].library.size()
	_drive_own_turn(ai)
	assert_eq(g.players[0].library.size(), library - 3, "the Recall drew three")
	assert_eq(g.players[1].library.size(), 30, "at our own seat, not theirs")
	assert_eq(recall.zone, Mtg.Zone.GRAVEYARD, "cast, and in the graveyard as a spell")
	assert_eq(g.players[0].hand.size(), 7, "the cleanup still cut the hand to seven")
	var discarded := 0
	for line in g.log_lines:
		if String(line).contains("discards Ancestral Recall"):
			discarded += 1
	assert_eq(discarded, 0, "never discarded")


## THE CONTROL: with three cards left in the library the Recall is not
## drawn into the end of it — the discard takes it, as before.
func test_not_into_the_end_of_the_library() -> void:
	var recall := _board()
	while g.players[0].library.size() > 3:
		g.players[0].library.pop_back()
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.MAIN2)
	_drive_own_turn(ai)
	assert_eq(g.players[0].library.size(), 3, "nothing drawn")
	assert_eq(recall.zone, Mtg.Zone.GRAVEYARD, "discarded by the cleanup")


## The gate's null arm: below the tactical forecast nothing is fired.
func test_the_gate_off_keeps_the_old_answer() -> void:
	var recall := _board()
	var profile := AiProfile.wizard()
	profile.forecasts_tactics = false
	var ai := AiPlayer.new(0, profile)
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.MAIN2)
	var library := g.players[0].library.size()
	_drive_own_turn(ai)
	assert_eq(g.players[0].library.size(), library, "nothing drawn with the gate off")
	assert_eq(recall.zone, Mtg.Zone.GRAVEYARD)
