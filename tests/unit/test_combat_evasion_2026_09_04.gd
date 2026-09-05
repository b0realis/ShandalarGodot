extends GameTest
## THE PLAYTEST DEFECT OF 2026-09-04 — *"Opponent attacked with Mahamoti
## Djinn (5/6) and I blocked with Giant Spider (2/4). Spider was not killed
## and all damage went to my life directly."*
##
## Two wrongs in one combat: a blocked attacker's damage reached the
## DEFENDING PLAYER, and its blocker took none. Either one alone is a
## rules defect; together they are the shape of an attacker that was
## treated as UNBLOCKED at the damage step.
##
## THE SUITE HAD 4089 TESTS AND DID NOT CATCH IT, and the reason is worth
## stating exactly. `tests/unit/test_combat.gd` DOES assert "blocked
## attacker deals no player damage" — twice, both times for a GROUND
## creature (a 2/2 trade, and trample's wasted excess). Its evasion tests
## stop at LEGALITY: one declares a ground blocker against a flyer and
## reads the refusal, one lets a flyer block a flyer and checks the two
## graveyards. Neither looks at the life total that follows, and the word
## REACH does not appear in the file at all. So every case below asserts
## the DEFENDING PLAYER'S LIFE as well as the bodies, across the whole
## evasion x blocker matrix rather than for one pairing:
##
##   * every evasion keyword against every blocker shape that may legally
##     stop it (flying/reach, fear, landwalk, protection, the printed
##     "can't be blocked by" clauses, the power thresholds, and the
##     open-ended block restrictions);
##   * every damage-assignment path (one blocker, several, trample, first
##     strike, banding's defender-assigns fork, and the 1997
##     free-division ruleset);
##   * and every way a blocker can LEAVE between the declaration and the
##     damage (CR 509.1h), which is the other road to "it dealt its
##     damage to me".
##
## THE INVARIANT, in one sentence: a creature that BECAME BLOCKED deals no
## damage to the defending player unless it has trample, and its blockers
## take the damage instead.


## Life of the player being attacked — the number the owner watched.
func _defender_life() -> int:
	return g.players[g.opponent_of(g.active_player)].life


## Stand the duel in turn 2, where seat 1 is the attacker and seat 0 the
## defender (the owner's seat).
func _their_turn() -> void:
	advance_to_next_turn()
	assert_eq(g.active_player, 1, "seat 1 attacks on turn 2")


## Attack with [param attacker], block with [param blocker], resolve all
## of combat. Returns the block declaration's refusal ("" when it stood).
func _combat(attacker: CardInstance, blocker: CardInstance) -> String:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, [attacker.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	var why := g.declare_blockers(g.opponent_of(g.active_player),
		{blocker.id: attacker.id})
	if why == "":
		advance_to_step(Mtg.Step.COMBAT_END)
	return why


## A synthetic body, so a case names its own characteristics instead of
## borrowing a card's.
func _body(pid: int, name: String, power: int, toughness: int,
		keywords: Array = []) -> CardData:
	return CardData.new(name, "{4}", Mtg.CardType.CREATURE) \
		.pt(power, toughness).with_keywords(keywords)


# =================================================== THE OWNER'S COMBAT --

func test_reach_blocks_flying_and_the_djinn_never_touches_the_player() -> void:
	var djinn := put_battlefield(1, "Mahamoti Djinn")     # 5/6 flying
	var spider := put_battlefield(0, "Giant Spider")      # 2/4 reach
	_their_turn()
	assert_eq(_combat(djinn, spider), "", "reach may block a flyer (CR 702.17)")
	assert_eq(g.players[0].life, 20,
		"THE DEFECT: a blocked Mahamoti Djinn dealt 5 to the player")
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD,
		"THE DEFECT: the Spider took none of the Djinn's damage")
	assert_eq(djinn.damage, 2, "and the Spider hit back for 2")


func test_the_block_is_recorded_in_every_collection_the_engine_reads() -> void:
	# The declaration itself, before any damage: CombatState is what the
	# damage step reads, and every one of these four answers has to agree
	# or the attacker is unblocked to somebody.
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [djinn.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {spider.id: djinn.id}))
	assert_eq(g.combat.blockers_of(djinn.id), [spider.id] as Array[int])
	assert_eq(g.combat.attackers_blocked_by(spider.id), [djinn.id] as Array[int])
	assert_true(g.combat.is_blocking(spider.id, djinn.id))
	assert_true(g.combat.was_blocked([djinn.id]),
		"CR 509.1h: the Djinn became blocked")


# ================================== EVASION x EVERY LEGAL BLOCKER SHAPE --
#
# One test per evasion keyword, each asserting BOTH halves of the
# invariant: the legal blocker stops the damage, and an illegal one is
# refused (and is refused with a reason, never silently).

func test_flying_is_stopped_by_reach_and_by_flying_and_by_nothing_else() -> void:
	var flyer := put_synthetic(1, _body(1, "Sweep Flyer", 4, 4,
		[Mtg.Keyword.FLYING]))
	var ground := put_battlefield(0, "Grizzly Bears")
	var reachy := put_battlefield(0, "Giant Spider")
	var winged := put_battlefield(0, "Serra Angel")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [flyer.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {ground.id: flyer.id}), "can't block flying")
	assert_ok(g.declare_blockers(0, {reachy.id: flyer.id, winged.id: flyer.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "a blocked flyer hits no player")


func test_fear_is_stopped_by_a_black_or_artifact_creature() -> void:
	var fearsome := put_synthetic(1, _body(1, "Sweep Fearsome", 3, 3,
		[Mtg.Keyword.FEAR]))
	var red := put_battlefield(0, "Hurloon Minotaur")          # red 2/3
	var black := put_battlefield(0, "Scathe Zombies")          # black 2/2
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [fearsome.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {red.id: fearsome.id}), "fear")
	assert_ok(g.declare_blockers(0, {black.id: fearsome.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)
	assert_eq(black.zone, Mtg.Zone.GRAVEYARD, "the blocker ate all 3")


func test_landwalk_is_a_block_rule_and_not_an_unblockable_one() -> void:
	var walker := put_synthetic(1, CardData.new("Sweep Walker", "{2}{U}",
		Mtg.CardType.CREATURE).pt(3, 3).with_landwalk(["island"]))
	var bear := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	# With no Island on the defender's side the walk grants nothing.
	assert_eq(_combat(walker, bear), "")
	assert_eq(g.players[0].life, 20, "islandwalk with no Island is blockable")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_landwalk_over_the_land_is_refused_and_the_damage_is_the_players() -> void:
	var walker := put_synthetic(1, CardData.new("Sweep Walker", "{2}{U}",
		Mtg.CardType.CREATURE).pt(3, 3).with_landwalk(["island"]))
	put_battlefield(0, "Island")
	var bear := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	assert_string_contains(_combat(walker, bear), "islandwalk")
	# ...and an attacker nobody blocked deals its damage to the player,
	# which is the OTHER half of the invariant and must still hold.
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 17, "an unblocked attacker still connects")


func test_protection_from_a_colour_refuses_that_colours_blocker() -> void:
	var white := put_synthetic(1, CardData.new("Sweep Paladin", "{2}{W}",
		Mtg.CardType.CREATURE).pt(3, 3).with_protection_from(Mtg.ManaColor.G))
	var green := put_battlefield(0, "Grizzly Bears")
	var other := put_battlefield(0, "Scathe Zombies")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [white.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {green.id: white.id}), "protection")
	assert_ok(g.declare_blockers(0, {other.id: white.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_a_printed_cant_be_blocked_by_clause_still_lets_everything_else_block() -> void:
	var jug := put_synthetic(1, CardData.new("Sweep Juggernaut", "{4}",
		Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE).pt(5, 3)
		.with_cant_be_blocked_by(["wall"]))
	var wall := put_battlefield(0, "Wall of Wood")
	var bear := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [jug.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {wall.id: jug.id}), "Wall")
	assert_ok(g.declare_blockers(0, {bear.id: jug.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)


func test_the_two_power_thresholds_both_ways() -> void:
	var small := put_synthetic(1, CardData.new("Sweep Kithkin", "{1}{W}",
		Mtg.CardType.CREATURE).pt(2, 2).with_cant_be_blocked_by_power_ge(2))
	var big := put_battlefield(0, "Ironroot Treefolk")   # 3/5
	var tiny := put_battlefield(0, "Llanowar Elves")     # 1/1
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [small.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {big.id: small.id}), "power")
	assert_ok(g.declare_blockers(0, {tiny.id: small.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "the 1/1 stopped it dead")


func test_a_block_restriction_names_who_may_block_and_stops_the_rest() -> void:
	# The open-ended clause (Elven Riders, Invisibility, Seeker): a
	# predicate every blocker must satisfy, and the road until-EOT
	# restrictions arrive on too (Tower of Coireall).
	var riders := put_battlefield(1, "Elven Riders")   # 3/3, Walls/flyers only
	var bear := put_battlefield(0, "Grizzly Bears")
	var wall := put_battlefield(0, "Wall of Wood")     # 0/3
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [riders.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(0, {bear.id: riders.id}),
		"can't be blocked except by")
	assert_ok(g.declare_blockers(0, {wall.id: riders.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)
	assert_eq(wall.zone, Mtg.Zone.GRAVEYARD, "the Wall took all 3")


# ===================================== EVERY DAMAGE-ASSIGNMENT PATH --

func test_one_blocker_takes_every_point_and_the_player_none() -> void:
	var ogre := put_battlefield(1, "Hill Giant")     # 3/3
	var bear := put_battlefield(0, "Grizzly Bears")  # 2/2
	_their_turn()
	assert_eq(_combat(ogre, bear), "")
	assert_eq(g.players[0].life, 20)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)


func test_two_blockers_split_lethal_first_and_the_player_takes_none() -> void:
	var wurm := put_battlefield(1, "Craw Wurm")          # 6/4
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [wurm.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {a.id: wurm.id, b.id: wurm.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "6 power, 4 of it lethal, none spilled")
	assert_eq(a.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(b.zone, Mtg.Zone.GRAVEYARD)


func test_trample_is_the_only_thing_that_spills_over() -> void:
	var trampler := put_synthetic(1, _body(1, "Sweep Trampler", 5, 5,
		[Mtg.Keyword.TRAMPLE]))
	var bear := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	assert_eq(_combat(trampler, bear), "")
	assert_eq(g.players[0].life, 17, "5 - 2 lethal = 3 through (CR 702.19b)")


func test_trample_over_two_blockers_pays_both_before_the_player() -> void:
	var trampler := put_synthetic(1, _body(1, "Sweep Trampler", 7, 7,
		[Mtg.Keyword.TRAMPLE]))
	var a := put_battlefield(0, "Grizzly Bears")
	var b := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [trampler.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {a.id: trampler.id, b.id: trampler.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 17, "2 + 2 lethal, 3 tramples through")


func test_defensive_banding_hands_the_division_over_and_still_owes_nothing() -> void:
	# CR 702.22f-h: a banding blocker gives the DEFENDING player the
	# division of the attacker's damage, free of the lethal-first order
	# (MtgGame._collect_damage_requests' `free_order`). What it must never
	# give them is a way to put their own attacker's damage anywhere but on
	# a blocker.
	var giant := put_battlefield(1, "Hill Giant")      # 3/3
	var hero := put_battlefield(0, "Benalish Hero")    # 1/1 banding
	var bear := put_battlefield(0, "Grizzly Bears")    # 2/2
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [giant.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(0, {hero.id: giant.id, bear.id: giant.id}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20,
		"the defender's own division still owes the player nothing")
	assert_eq(hero.zone, Mtg.Zone.GRAVEYARD,
		"all 3 went on the body they mind losing least")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "and the 2/2 walked away")


func test_a_first_striking_attacker_still_owes_its_damage_to_the_blocker() -> void:
	var striker := put_synthetic(1, _body(1, "Sweep Striker", 3, 3,
		[Mtg.Keyword.FIRST_STRIKE]))
	var bear := put_battlefield(0, "Grizzly Bears")
	_their_turn()
	assert_eq(_combat(striker, bear), "")
	assert_eq(g.players[0].life, 20, "the first-strike wave hit the blocker")
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(striker.damage, 0, "and the dead blocker never struck back")


func test_a_first_striking_blocker_that_kills_the_attacker_stops_all_of_it() -> void:
	var attacker := put_synthetic(1, _body(1, "Sweep Charger", 2, 1))
	var archers := put_battlefield(0, "Elvish Archers")   # 2/1 first strike
	_their_turn()
	assert_eq(_combat(attacker, archers), "")
	assert_eq(g.players[0].life, 20)
	assert_eq(attacker.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(archers.zone, Mtg.Zone.BATTLEFIELD, "it struck first and lived")


func test_the_1997_free_division_fork_still_owes_the_blocker_its_damage() -> void:
	# RulesOptions.free_damage_assignment drops the ORDER (CR 509.2) and
	# the lethal-first rule — it must never drop "a blocked creature deals
	# no damage to the player" (docs/duel-todo.md §1.4).
	g.rules.free_damage_assignment = true
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	assert_eq(_combat(djinn, spider), "")
	assert_eq(g.players[0].life, 20)
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD)


func test_the_attacking_ai_assigns_to_the_blocker_and_not_to_the_face() -> void:
	# The owner's opponent was the AI, so the division was ITS to make.
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	assert_eq(_combat(djinn, spider), "")
	assert_eq(g.players[0].life, 20, "the AI may not point damage at the face")
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD)


func test_an_agent_that_answers_with_face_damage_is_overruled() -> void:
	# A DecisionAgent is engine code, but an illegal division must be
	# replaced by the default rather than obeyed (MtgGame._agent_split).
	g.set_agent(1, FaceSeat.new())
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	assert_eq(_combat(djinn, spider), "")
	assert_eq(g.players[0].life, 20,
		"an illegal split falls back to lethal-first, not to the player")
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD)


# ============================ THE BLOCKER LEAVES BEFORE DAMAGE (509.1h) --

func _attack_and_block(a: CardInstance, b: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(g.active_player, [a.id]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(g.opponent_of(g.active_player), {b.id: a.id}))


func test_a_bounced_blocker_leaves_the_attacker_blocked() -> void:
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	var bounce := give_hand(1, "Unsummon")
	_their_turn()
	_attack_and_block(djinn, spider)
	add_mana(1, Mtg.ManaColor.U)
	assert_ok(g.cast_spell(1, bounce, [TargetRef.card(spider)]))
	resolve_stack()
	assert_eq(spider.zone, Mtg.Zone.HAND)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "CR 509.1h: still blocked, still nothing")


func test_a_killed_blocker_leaves_the_attacker_blocked() -> void:
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	var blast := give_hand(1, "Psionic Blast")
	_their_turn()
	_attack_and_block(djinn, spider)
	add_mana(1, Mtg.ManaColor.U, 3)
	assert_ok(g.cast_spell(1, blast, [TargetRef.card(spider)]))
	resolve_stack()
	assert_eq(spider.zone, Mtg.Zone.GRAVEYARD)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "CR 509.1h: still blocked, still nothing")


## An agent that tries to put a blocked attacker's damage on the player.
class FaceSeat extends DecisionAgent:
	func assign_combat_damage(_game: MtgGame, _source: CardInstance,
			_targets: Array, amount: int, _trample: bool,
			_already: Dictionary, _free_order := false) -> Dictionary:
		return {MtgGame.DAMAGE_TO_PLAYER: amount}


# ================================== THE AI ON BOTH SIDES OF THE MATCHUP --

func test_the_defending_ai_spends_its_reach_on_a_flyer_worth_blocking() -> void:
	# General AI play, not one pairing: the block evaluation asks
	# CombatState.block_illegality like everything else, so reach is a
	# legal answer to flying for the AI as well as for the player.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var sparrow := put_synthetic(1, _body(1, "Sweep Sparrow", 1, 1,
		[Mtg.Keyword.FLYING]))
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [sparrow.id]))
	resolve_stack()
	while not g.awaiting_blockers and not g.game_over:
		assert_ok(g.pass_priority(g.priority_player))
	ai.act(g)
	assert_true(g.combat.is_blocking(spider.id, sparrow.id),
		"a 2/4 with reach eats a 1/1 flyer and lives")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20)
	assert_eq(sparrow.zone, Mtg.Zone.GRAVEYARD)


func test_a_creature_in_hand_is_not_a_legal_blocker() -> void:
	# CR 509.1a. The declaration always refused it; the PREDICATE said yes,
	# and the duel screen's pick-up gate asks the predicate.
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var in_hand := give_hand(0, "Giant Spider")
	_their_turn()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(1, [djinn.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_string_contains(
		CombatState.block_illegality(g, in_hand, djinn, 0),
		"not on the battlefield")
	assert_refused(g.declare_blockers(0, {in_hand.id: djinn.id}))


func test_a_blocker_removed_from_combat_leaves_the_attacker_blocked() -> void:
	# The third way out: MtgGame.remove_from_combat, which is regeneration's
	# own move (CR 701.15a) and Mijae Djinn's, Disharmony's and Imprison's.
	# Only the printed exception (False Orders, Ydwen Efreet) unblocks the
	# attacker, and this is not it.
	var djinn := put_battlefield(1, "Mahamoti Djinn")
	var spider := put_battlefield(0, "Giant Spider")
	_their_turn()
	_attack_and_block(djinn, spider)
	g.remove_from_combat(spider)
	assert_false(g.combat.blocks.has(spider.id), "it stopped blocking")
	assert_true(g.combat.was_blocked([djinn.id]), "the Djinn stays blocked")
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[0].life, 20, "CR 509.1h: still blocked, still nothing")
	assert_eq(spider.damage, 0, "and out of combat, so it takes none either")
