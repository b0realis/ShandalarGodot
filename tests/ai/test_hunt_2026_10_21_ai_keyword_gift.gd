extends GameTest
## THE KEYWORD BOUGHT FOR NOTHING (bug hunt 2026-10-21, ai).
##
## Phelddagrif — "{G}: gains trample until end of turn; target opponent
## creates a 1/1 green Hippo. {W}: gains flying until end of turn; target
## opponent gains 2 life" — and every `self_keyword` ability were priced by
## the Alliances arm ([method AlliancesTactics.option]) at a flat 3.5 for
## any keyword the attacker lacked. Attacking into an empty board, the
## Wizard bought both: the Hippo arrived BEFORE blocks (a chump blocker for
## the very attacker), the opponent gained 2, and the 4 damage was the 4 it
## would have dealt anyway.
##
## Evasion is bought now only while a creature of theirs could block the
## attacker, and trample only once it is blocked by less toughness than its
## power — the control below, where the Bears block and trample pushes two
## through. Banding is never bought by an attacker already declared: a band
## is formed as attackers are declared (CR 702.22c), and Urza's Engine paid
## {3} for one it could not join.

const A := preload("res://engine/ai/alliances_tactics.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-5")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Our Phelddagrif and five lands; it attacks; seat 0 acts until it passes.
func _attack(their_bears := false, block := false) -> Array:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var grif := put_battlefield(0, "Phelddagrif")
	for land in ["Forest", "Plains", "Island", "Forest", "Plains"]:
		put_battlefield(0, land)
	var bears: CardInstance = put_battlefield(1, "Grizzly Bears") if their_bears else null
	var guard := 0
	while not (g.active_player == 0 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(0, [grif.id]))
	if block:
		guard = 0
		while not g.awaiting_blockers and guard < 20:
			assert_ok(g.pass_priority(g.priority_player))
			guard += 1
		assert_ok(g.declare_blockers(1, {bears.id: grif.id}))
		guard = 0
		while g.priority_player != 0 and guard < 20:
			assert_ok(g.pass_priority(g.priority_player))
			guard += 1
	var lines: Array = []
	for i in 6:
		if g.priority_player != 0: break
		var did := ai.act(g)
		lines.append(did)
		resolve_stack()
		if did == "pass" or did == "": break
	return [grif, lines]


func test_no_gift_into_an_empty_board() -> void:
	var grif: CardInstance = _attack()[0]
	assert_eq(g.players[1].battlefield.size(), 0, "no Hippo for them before blocks")
	assert_eq(g.players[1].life, 20, "no life for them")
	assert_false(grif.has_keyword(Mtg.Keyword.TRAMPLE))
	assert_false(grif.has_keyword(Mtg.Keyword.FLYING))


## THE CONTROL: blocked by Grizzly Bears, trample puts two of its four
## through — worth the Hippo they get after blocks.
func test_trample_is_bought_once_the_bears_block() -> void:
	var grif: CardInstance = _attack(true, true)[0]
	assert_true(grif.has_keyword(Mtg.Keyword.TRAMPLE), "two damage past a 2/2")
	assert_eq(A.trample_gain(g, grif), 2)


func test_the_readings() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var grif := put_battlefield(0, "Phelddagrif")
	assert_false(A.could_be_blocked(g, ai, grif), "nothing of theirs on the table")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(A.could_be_blocked(g, ai, grif), "their Bears could block it")
	bears.tapped = true
	assert_false(A.could_be_blocked(g, ai, grif), "not while tapped")


func test_urzas_engine_buys_no_band_after_declaring() -> void:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var engine := put_battlefield(0, "Urza's Engine")
	for n in 6: put_battlefield(0, "Mountain")
	put_battlefield(1, "Grizzly Bears")
	var guard := 0
	while not (g.active_player == 0 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(0, [engine.id]))
	for i in 6:
		if g.priority_player != 0: break
		var did := ai.act(g)
		resolve_stack()
		if did == "pass" or did == "": break
	assert_false(engine.has_keyword(Mtg.Keyword.BANDING), "{3} for a band nobody can join")
