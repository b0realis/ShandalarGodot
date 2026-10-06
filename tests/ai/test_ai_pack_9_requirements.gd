extends GameTest
## COMBAT REQUIREMENTS, READ BY THE FAIR AI (Pack 9, engine package E4;
## CR 508.1d, 508.1g; [member AiProfile.reads_gaze] for the pricing).
##
## Magnetic Web's "if a creature with a magnet counter on it attacks, all
## creatures with magnet counters on them attack if able" is a PREDICATE
## attack requirement: a plan that sends one magnet creature drags every
## able other one along ([method CombatDeclaration.predicate_companions]).
## The attack planner prices those dragged bodies with the plan (the
## Ekundu Cyclops reading, [method MirageTactics.price_forced_attackers]):
## a plan the companions turn into a loss sends nobody; one they do not is
## declared WITH them, so the engine's repair never has to rebuild it.
##
## Exalted Dragon ("can't attack unless you sacrifice a land", CR 508.1g)
## is a land-taxed attacker the planner volunteers on its own terms; the
## repair of a declaration that breaks a requirement used to drop every
## taxed body, the volunteered one too, so a Dragon beside a magnet
## companion never attacked. The repair now keeps what the plan proposed.
##
## Hidden information: the opponent's hand and library are substituted and
## the declaration does not move (docs/fair-play.md).

const CD := preload("res://engine/core/combat_declaration.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(gaze := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.reads_gaze = gaze
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _magnet(inst: CardInstance) -> void:
	g.add_counters(inst, "magnet", 1)
	g.recalculate()


## Our declare-attackers question, open for seat 0.
func _to_our_attack() -> void:
	advance_to_step(Mtg.Step.COMBAT_BEGIN)
	var guard := 0
	while not g.awaiting_attackers and guard < 50:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_true(g.awaiting_attackers)


# ------------------------------------------------------------ the repair --

func test_the_repair_keeps_a_volunteered_land_taxed_attacker() -> void:
	put_battlefield(0, "Magnetic Web")
	var dragon := put_battlefield(0, "Exalted Dragon")
	var bears := put_battlefield(0, "Grizzly Bears")
	for _i in 3: put_battlefield(0, "Plains")
	_magnet(dragon)
	_magnet(bears)
	var fixed: Array = CD.repair_attacks(g, 0, [dragon.id])
	assert_true(fixed.has(dragon.id), "the plan volunteered the Dragon and its land")
	assert_true(fixed.has(bears.id), "the magnet companion comes along (CR 508.1d)")
	assert_eq(CD.attack_error(g, 0, fixed), "")


func test_the_repair_still_never_volunteers_a_land_taxed_attacker() -> void:
	put_battlefield(0, "Magnetic Web")
	var dragon := put_battlefield(0, "Exalted Dragon")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(0, "Hill Giant")
	for _i in 3: put_battlefield(0, "Plains")
	_magnet(giant)
	_magnet(bears)
	var fixed: Array = CD.repair_attacks(g, 0, [bears.id])
	assert_false(fixed.has(dragon.id), "no player is required to pay an attack cost")
	assert_true(fixed.has(giant.id))


# ------------------------------------------------------- the declaration --

func test_the_dragon_attacks_beside_its_magnet_companion() -> void:
	var ai := _ai()
	put_battlefield(0, "Magnetic Web")
	var dragon := put_battlefield(0, "Exalted Dragon")
	var bears := put_battlefield(0, "Grizzly Bears")
	for _i in 6: put_battlefield(0, "Plains")
	_magnet(dragon)
	_magnet(bears)
	put_battlefield(1, "Craw Wurm")
	g.players[1].life = 10
	_to_our_attack()
	assert_string_contains(ai.act(g), "declared")
	assert_true(g.combat.attackers.has(dragon.id), "the Dragon pays its land and attacks")
	assert_true(g.combat.attackers.has(bears.id), "its magnet companion is dragged along")


func test_a_magnet_companion_that_loses_the_attack_keeps_everyone_home() -> void:
	var ai := _ai()
	var answers := _companion_board()
	assert_true(g.combat.attackers.is_empty(),
		"the flier's 1 damage does not pay for the Giant the Wurm eats: %s" % answers)


func test_the_null_arm_drags_the_companion_into_the_wurm() -> void:
	var ai := _ai(false)
	_companion_board()
	assert_false(g.combat.attackers.is_empty(), "gate off: the plan is repaired, unpriced")


## Our 1/1 flier and a Hill Giant both carry magnet counters; their Craw
## Wurm eats the Giant. Returns the AI's answer.
func _companion_board() -> String:
	put_battlefield(0, "Magnetic Web")
	var flier := put_battlefield(0, "Scryb Sprites")
	var giant := put_battlefield(0, "Hill Giant")
	_magnet(flier)
	_magnet(giant)
	put_battlefield(1, "Craw Wurm")
	_to_our_attack()
	return g.agents[0].act(g)


func test_the_declaration_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Magnetic Web")
		var dragon := put_battlefield(0, "Exalted Dragon")
		var bears := put_battlefield(0, "Grizzly Bears")
		for _i in 6: put_battlefield(0, "Plains")
		_magnet(dragon)
		_magnet(bears)
		put_battlefield(1, "Craw Wurm")
		g.players[1].life = 10
		give_hand(1, "Giant Growth" if variant == 0 else "Fog")
		g.players[1].library.reverse()
		_to_our_attack()
		ai.act(g)
		answers.append(g.combat.attackers.keys())
	assert_eq(answers[0].size(), answers[1].size(), "hidden cards changed the declaration")
	assert_eq(answers[0].size(), 2)
