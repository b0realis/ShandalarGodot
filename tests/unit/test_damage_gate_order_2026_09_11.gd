extends GameTest
## A PREVENTION ORDERED AGAINST A REPLACEMENT (CR 616.1) — 2026-09-11.
##
## "If two or more replacement and/or prevention effects are attempting to
## modify the way an event affects an object or player, the affected
## object's controller or the affected player chooses one to apply, and
## then the rule is applied again." The 2026-09-10 pass built that for
## DRAWS and ruled the shield-versus-shield half of the damage row
## unobservable; it named this half as real and unbuilt, because
## MtgGame._land_damage_impl walked its gates in ONE fixed order with the
## one-shot REPLACEMENTS (Forcefield, Dark Sphere, Eye for an Eye, Nova
## Pentacle, Shimian Night Stalker) hard-wired ahead of every PREVENTION
## (the Circles, Reverse Damage, a prevention pool, Ali from Cairo).
##
## The pool can see it with two commons and a rare on the table. A Circle
## of Protection: Red naming a Lightning Bolt and a Nova Pentacle watching
## the same Bolt both apply to the same three points:
##
##  * the Pentacle first — today's fixed order — deflects all three onto a
##    creature the opponent named, and the Circle's shield is still up;
##  * the Circle first prevents the damage outright, so there is no damage
##    left for the Pentacle to move and its one-shot is still waiting.
##
## Neither line is the engine's to pick. The question is now put to the
## damaged seat, hinted at index 0 — today's order — so a heuristic seat
## answers exactly as the old chain ran and only a seat that says otherwise
## sees a different board.
##
## WHAT WAS NOT BUILT WHEN THIS FILE WAS WRITTEN, and was narrowed rather
## than closed: the same question on the CREATURE branch (protection
## against Jade Monolith, Rock Hydra's counters against a prevention pool).
## The footer pinned the fixed order there so a later pass would start from
## a reading rather than from prose, and it did, LATER THE SAME DAY —
## tests/unit/test_creature_damage_gate_order_2026_09_11.gd. The footer
## test below is unchanged and still green: that order is now the DEFAULT
## answer rather than the only one, which is exactly what a heuristic seat
## still plays.


## Names a card when it can, answers the CR 616.1 ordering question with
## whichever index the test parked, and records every question asked.
class Chooser extends DecisionAgent:
	var wanted := ""
	var take := 0
	var asked: Array[String] = []

	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String,
			_hint: bool) -> bool:
		return true

	func answer_card(_game: MtgGame, _pid: int, candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		for inst in candidates:
			if inst.data.card_name == wanted:
				return inst
		return null if candidates.is_empty() else candidates[0]

	func answer_option(_game: MtgGame, _pid: int, _prompt: String,
			options: Array[String], hint: int) -> int:
		asked.append(", ".join(options))
		return hint if take < 0 else take


## P1 bolts P0, who holds a Circle of Protection: Red and a Nova Pentacle
## and answers the ordering question with [param take]. P1 keeps a Grizzly
## Bears for the Pentacle to deflect onto — the opponent's own choice, and
## their order puts P0's creatures first, so with none of P0's out it is
## their Bears.
func _bolt_into_two_gates(take: int) -> Chooser:
	var chooser := Chooser.new()
	chooser.wanted = "Lightning Bolt"
	chooser.take = take
	g.set_agent(0, chooser)
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var pentacle := put_battlefield(0, "Nova Pentacle")
	put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C, 3)
	assert_ok(g.activate_ability(0, pentacle, 0))
	resolve_stack_but_one()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()
	return chooser


## Resolve everything the two seats have put up EXCEPT the bottom item —
## the Bolt itself, which must still be on the stack for the Circle and the
## Pentacle to name it as their source.
func resolve_stack_but_one() -> void:
	var guard := 0
	while g.stack.size() > 1 and guard < 40:
		guard += 1
		if g.pass_priority(g.priority_player) != "":
			break


# ------------------------------------------------- the reproduction, both ways --

## THE REPRODUCTION. Two effects apply to one packet, so the damaged seat
## is asked which applies first (CR 616.1) — and is asked exactly once.
func test_the_damaged_seat_is_asked_which_gate_applies_first() -> void:
	var chooser := _bolt_into_two_gates(0)
	assert_eq(chooser.asked.size(), 1, "asked once, for the one packet")
	assert_true(chooser.asked[0].contains("Nova Pentacle"),
		"the replacement is on the list: %s" % chooser.asked[0])
	assert_true(chooser.asked[0].contains("Circle of Protection: Red"),
		"and so is the prevention: %s" % chooser.asked[0])


## Taking the replacement is what the engine always did: the three points
## land on the creature the opponent named and the Circle is still up.
func test_taking_the_replacement_keeps_the_circle() -> void:
	_bolt_into_two_gates(0)
	assert_eq(g.players[0].life, 20, "it never reached you")
	assert_eq(g.players[1].battlefield.size(), 0, "their Bears ate the Bolt")
	assert_eq(g.players[0].prevention_shield_filters.size(), 1,
		"the Circle's shield was not spent")
	assert_eq(g.players[0].damage_replacements.size(), 0,
		"the Pentacle's one-shot was")


## Taking the prevention prevents the damage outright — and a replacement
## has nothing left to modify, so the Pentacle is still waiting for the
## next source it watches (CR 616.1 is re-applied only to an event that
## still exists).
func test_taking_the_prevention_keeps_the_replacement() -> void:
	_bolt_into_two_gates(1)
	assert_eq(g.players[0].life, 20, "prevented outright")
	assert_eq(g.players[1].battlefield.size(), 1, "their Bears are untouched")
	assert_eq(g.players[0].prevention_shield_filters.size(), 0,
		"the Circle's shield was spent instead")
	assert_eq(g.players[0].damage_replacements.size(), 1,
		"and the Pentacle is still watching")


# ------------------------------------------- the life totals disagree too --

## Eye for an Eye against the same Circle, where the two orders do not even
## agree on the OPPONENT's life. The Eye prevents nothing: it mirrors the
## blow back and lets yours carry on into the Circle, so taking it first
## costs them three. Taking the Circle first prevents the damage, and a
## blow that is never dealt is never mirrored.
func _eye_into_a_circle(take: int) -> void:
	var chooser := Chooser.new()
	chooser.wanted = "Lightning Bolt"
	chooser.take = take
	g.set_agent(0, chooser)
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var eye := give_hand(0, "Eye for an Eye")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.W, 2)
	assert_ok(g.cast_spell(0, eye, []))
	resolve_stack_but_one()
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()


func test_taking_the_eye_first_mirrors_the_bolt() -> void:
	_eye_into_a_circle(0)
	assert_eq(g.players[0].life, 20, "the Circle caught your half")
	assert_eq(g.players[1].life, 17, "and the Eye sent theirs back")


func test_taking_the_circle_first_leaves_nothing_to_mirror() -> void:
	_eye_into_a_circle(1)
	assert_eq(g.players[0].life, 20, "prevented outright")
	assert_eq(g.players[1].life, 20,
		"no damage was dealt, so nothing was mirrored (CR 616.1)")
	assert_eq(g.players[0].damage_replacements.size(), 1,
		"and the Eye is still watching its source")


# --------------------------------------------------------------- the null --

## ONE applicable effect is not a choice and nobody is asked — which is
## every packet in almost every duel, and the reason this costs nothing on
## the combat-damage path.
func test_one_applicable_gate_asks_nothing() -> void:
	var chooser := Chooser.new()
	chooser.wanted = "Lightning Bolt"
	g.set_agent(0, chooser)
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()
	assert_eq(chooser.asked, [], "nobody was asked to order one effect")
	assert_eq(g.players[0].life, 20, "and the Circle still worked")


## And a packet with NO applicable effect never builds a candidate list at
## all — the early-out that keeps the combat-damage path the price it was.
func test_an_unshielded_packet_asks_nothing() -> void:
	var chooser := Chooser.new()
	g.set_agent(0, chooser)
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(chooser.asked, [], "nothing applied, nothing was asked")
	assert_eq(g.players[0].life, 17)


# ------------------------------------------------- combat damage, in anger --

## The path the note named: COMBAT damage, where the decision point sits in
## front of every gate. Shimian Night Stalker's all-turn redirect and a
## Circle naming the same attacker both apply to the blow.
func _stalker_and_circle(take: int) -> Array[CardInstance]:
	var chooser := Chooser.new()
	chooser.wanted = "Shivan Dragon"
	chooser.take = take
	g.set_agent(0, chooser)
	var stalker := put_battlefield(0, "Shimian Night Stalker")
	var cop := put_battlefield(0, "Circle of Protection: Red")
	var dragon := put_battlefield(1, "Shivan Dragon")
	advance_to_next_turn()          # P1's turn, so the Dragon can attack
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [dragon.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	assert_ok(g.pass_priority(1))   # the active player acts first (CR 117.3c)
	add_mana(0, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(0, stalker, 0, [TargetRef.card(dragon)]))
	resolve_stack()
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, cop, 0))
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	return [stalker, dragon]


func test_combat_damage_takes_the_redirect_by_default() -> void:
	var board := _stalker_and_circle(0)
	assert_eq(g.players[0].life, 20, "the Stalker stepped in front")
	assert_eq(board[0].zone, Mtg.Zone.GRAVEYARD,
		"and took the Dragon's five on a 4/4 body")


func test_combat_damage_can_take_the_circle_instead() -> void:
	var board := _stalker_and_circle(1)
	assert_eq(g.players[0].life, 20, "prevented instead")
	assert_eq(board[0].zone, Mtg.Zone.BATTLEFIELD, "the Stalker is unhurt")
	assert_eq(board[0].damage, 0)


# ============ THE CREATURE BRANCH: THE OLD ORDER, NOW THE DEFAULT ============
#
# CR 616.1 is put to the AFFECTED PLAYER, and MtgGame._land_damage_impl
# does that for every packet aimed at a PLAYER. A packet aimed at a
# CREATURE is the same question asked of ITS CONTROLLER, and since later
# the same day it is asked (MtgGame._creature_damage_gates,
# tests/unit/test_creature_damage_gate_order_2026_09_11.gd). The test below
# was written to pin the fixed order that was there; it is unchanged and
# still green, because that order is the hint every seat that is not a
# human still takes.

## Uncle Istvan's "prevent all damage that would be dealt to this creature
## by creatures" is spent before a prevention POOL sitting on the same
## body, so the pool is never touched — one candidate is not a choice, so
## nobody is even asked here, and this is the answer either way.
func test_the_creature_branch_defaults_to_its_old_fixed_order() -> void:
	var istvan := put_battlefield(0, "Uncle Istvan")
	var bear := put_battlefield(1, "Grizzly Bears")
	istvan.prevention = 2
	g.deal_damage(bear, TargetRef.card(istvan), 2)
	assert_eq(istvan.damage, 0, "prevented either way")
	assert_eq(istvan.prevention, 2,
		"the whole-event prevention went first and the pool was never spent")


# ======================= THE SURVEY, PINNED =======================
#
# The choice is only worth its prompt while the pool holds cards that can
# contend. These two tests are the survey the build rested on, written so
# that a new card changes a reading rather than a paragraph.

## The five one-shot REPLACEMENTS. A sixth writer of the list forces this
## reading to be re-taken — and it is the replacements that make the
## question observable, because the fixed chain put every one of them
## ahead of every prevention.
func test_the_pool_has_five_damage_replacement_writers() -> void:
	var writers := _cards_containing("damage_replacements.append")
	writers.sort()
	assert_eq(writers, ["dark_sphere.gd", "eye_for_an_eye.gd", "forcefield.gd",
		"nova_pentacle.gd", "shimian_night_stalker.gd"],
		"a new damage replacement: re-take the CR 616.1 survey")


## And the PREVENTIONS that can meet them on a packet aimed at a player:
## every Circle of Protection through PreventDamageShieldEffect, plus the
## two class shields that write the predicate list themselves.
func test_the_pool_has_nine_player_side_prevention_writers() -> void:
	var circles := _cards_containing("PreventDamageShieldEffect")
	var direct := _cards_containing("prevention_shield_filters.append")
	assert_eq(circles.size(), 7, "the Circle family: %s" % [circles])
	direct.sort()
	assert_eq(direct, ["al_abara_s_carpet.gd", "scarecrow.gd"],
		"and the two all-turn class shields")


## Card FILES under cards/sets/ whose source contains [param needle].
func _cards_containing(needle: String) -> Array[String]:
	var hits: Array[String] = []
	for set_dir in DirAccess.get_directories_at("res://cards/sets"):
		var dir_path := "res://cards/sets/%s" % set_dir
		for file in DirAccess.get_files_at(dir_path):
			if not file.ends_with(".gd"):
				continue
			if FileAccess.get_file_as_string("%s/%s" % [dir_path, file]).contains(needle):
				hits.append(file)
	return hits
