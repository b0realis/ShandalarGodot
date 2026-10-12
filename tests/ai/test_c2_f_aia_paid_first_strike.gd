extends GameTest
## THEIR FIRST STRIKE IS PUBLIC (robustness campaign 2026-10-12, b5-5;
## [member AiProfile.forecasts_tactics] with [member AiProfile.reads_pumps]).
##
## Burning Shield Askari prints "{R}{R}: gains first strike until end of
## turn". The block reading took first strike from the keyword alone, so a
## Hill Giant blocked the Askari with two Mountains open across the table:
## flanking makes the Giant a 2/2, the Askari strikes first and kills it,
## and the Askari lives (Lab: p8_jamuraa v p8_knights; a 5/4 Wildebeests
## lost under an Agility-wearing Askari at 16 life). An attacker whose own
## ability grants it first strike, payable from its controller's untapped
## permanents, is read as a first striker when the block is judged —
## [method AiPlayer._dies_to] and the combat model alike. The mana is on the
## table; their hand is never read. Gate off: the keyword alone.


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _block_with(blocker: String, rr_open: bool, agility := false, on := true,
		their_hand: Array = [], profile: AiProfile = null) -> Dictionary:
	before_each()
	var p := profile if profile != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	g.players[0].life = 16
	var body := put_battlefield(0, blocker)
	put_battlefield(0, "Ophidian")
	var askari := put_battlefield(1, "Burning Shield Askari")
	if agility:
		var aura := give_hand(1, "Agility")
		g.attach_aura_from_anywhere(aura, askari, 1)
	for i in 2:
		var mountain := put_battlefield(1, "Mountain")
		mountain.tapped = not rr_open
	for n in their_hand: give_hand(1, n)
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.DECLARE_ATTACKERS
			and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	if not rr_open:
		for inst in g.players[1].battlefield:
			if inst.data.card_name == "Mountain": inst.tapped = true
	g.recalculate()
	assert_ok(g.declare_attackers(1, [askari.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 50:
		g.pass_priority(g.priority_player)
		guard += 1
	var line := ai.act(g)
	return {"blocked": g.combat.blocks.has(body.id), "line": line}


func test_the_hill_giant_does_not_block_into_paid_first_strike() -> void:
	var on := _block_with("Hill Giant", true)
	assert_false(bool(on["blocked"]), "{R}{R} open: the Giant would die for nothing")
	var off := _block_with("Hill Giant", true, false, false)
	assert_true(bool(off["blocked"]), "gate off: the keyword-only reading blocks")


func test_with_the_mountains_tapped_the_trade_is_taken() -> void:
	# The control: no mana for the first strike, a 2/2-for-2/2 trade at 16
	# life; the reading must not refuse it for an ability nobody can pay.
	var r := _block_with("Hill Giant", false)
	assert_true(bool(r["blocked"]), "nothing open: the Giant trades with the Askari")


func test_the_wildebeests_do_not_block_the_agility_askari() -> void:
	var r := _block_with("Stampeding Wildebeests", true, true)
	assert_false(bool(r["blocked"]),
		"two flanking triggers make the Wildebeests 3/2; first strike kills it first")


func test_the_sorcerer_reads_it_too() -> void:
	var r := _block_with("Hill Giant", true, false, true, [], AiProfile.sorcerer())
	assert_false(bool(r["blocked"]))


func test_their_hidden_hand_does_not_move_the_block() -> void:
	var seen: Array = []
	for their_hand in [[], ["Giant Growth"], ["Lightning Bolt", "Counterspell"]]:
		seen.append(_block_with("Hill Giant", true, false, true, their_hand)["blocked"])
	assert_eq(seen[1], seen[0], "a hidden pump changed the block")
	assert_eq(seen[2], seen[0], "a hidden hand changed the block")


func test_the_reading_is_the_opponents_ability_and_mana() -> void:
	# The predicate itself: their Askari with {R}{R} open strikes first;
	# with the Mountains tapped it does not; our own Askari is not read
	# here (the attack side prices our own pumps).
	before_each()
	var p := AiProfile.wizard()
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	var theirs := put_battlefield(1, "Burning Shield Askari")
	var m1 := put_battlefield(1, "Mountain")
	var m2 := put_battlefield(1, "Mountain")
	var ours := put_battlefield(0, "Burning Shield Askari")
	put_battlefield(0, "Mountain")
	put_battlefield(0, "Mountain")
	assert_true(ai._strikes_first(g, theirs), "their {R}{R} is open")
	assert_false(ai._strikes_first(g, ours), "ours is not this reading's")
	m1.tapped = true
	assert_false(ai._strikes_first(g, theirs), "one Mountain cannot pay {R}{R}")
	m2.tapped = true
	p.forecasts_tactics = false
	m1.tapped = false
	m2.tapped = false
	assert_false(ai._strikes_first(g, theirs), "gate off: the keyword alone")
