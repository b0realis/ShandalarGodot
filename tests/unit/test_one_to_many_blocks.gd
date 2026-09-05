extends GameTest
## ONE CREATURE BLOCKING SEVERAL ATTACKERS (CR 509.1b) — the last hole in
## this engine's combat, closed 2026-09-02.
##
## The rule: *"a creature can block only one creature unless an effect
## says otherwise"*. Two cards in the pool say otherwise — Two-Headed
## Giant of Foriys (*"can block an additional creature each combat"*,
## printed, [member CardData.extra_blocks]) and Blaze of Glory (*"can
## block any number of creatures this turn"*, granted for the turn,
## [member CardInstance.extra_blocks_this_turn]) — and until this landed
## both became "blocks one", which is what
## `docs/simplified-cards.md`'s combat re-arrangement row said.
##
## Three things had to be true at once and each has a test here: the
## DECLARATION accepts it and refuses it where no effect allows it; the
## DAMAGE is right in both directions (every attacker it blocks hits it,
## and its own power is divided among them exactly once); and the cards
## that ask "is X blocking Y" get the right answer for a creature blocking
## two things.


## Both seats pass through the damage step without stopping.
func _blocks(block_map: Dictionary, attacker_ids: Array) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, block_map))


# ------------------------------------------------------ the permission --

func test_an_ordinary_creature_may_not_block_two_attackers() -> void:
	# CR 509.1b, and the reason the other tests here are about two cards
	# rather than about every creature.
	var a := put_battlefield(0, "Gray Ogre")           # 2/2
	var b := put_battlefield(0, "Grizzly Bears")       # 2/2
	var wall := put_battlefield(1, "Wall of Stone")    # 0/8
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: [a.id, b.id]}),
		"can block only 1 attacker")


func test_the_giant_may_block_two_and_no_more() -> void:
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Hurloon Minotaur")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")   # 4/4
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id, c.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: [a.id, b.id, c.id]}),
		"can block only 2 attacker")
	assert_ok(g.declare_blockers(1, {giant.id: [a.id, b.id]}))
	assert_eq(g.combat.attackers_blocked_by(giant.id), [a.id, b.id] as Array[int])


func test_the_permission_is_read_live_so_a_face_down_giant_loses_it() -> void:
	# CR 708.2: a face-down permanent is a nameless 2/2 with no abilities,
	# and `extra_blocks` is a printed combat characteristic like the three
	# beside it — so it goes with them.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	giant.face_down = true
	g.recalculate()
	assert_eq(giant.cur_extra_blocks, 0)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {giant.id: [a.id, b.id]}),
		"can block only 1 attacker")


# ---------------------------------------------------------- the damage --

func test_both_attackers_hit_the_one_blocker() -> void:
	# The Giant blocks a 2/2 and a 2/2: it takes 4 and dies, which is the
	# printed cost of eating two attackers with one body.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")   # 4/4
	_blocks({giant.id: [a.id, b.id]}, [a.id, b.id])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(giant.zone, Mtg.Zone.GRAVEYARD, "2 + 2 is lethal to a 4/4")
	assert_eq(g.players[1].life, 20, "and neither attacker got through")


func test_the_blocker_deals_its_power_once_not_once_per_attacker() -> void:
	# The bug this restructuring exists to prevent: the damage requests
	# used to be built per BAND, so a blocker that is in two of them got a
	# request each and dealt its FULL power twice. The 4/4 Giant has four
	# points in total — two kill the Ogre and two land on the Wurm, which
	# has toughness 4 and therefore lives. Struck twice it would have four
	# on the Wurm as well, and the Wurm would die.
	var ogre := put_battlefield(0, "Gray Ogre")        # 2/2
	var wurm := put_battlefield(0, "Craw Wurm")        # 6/4
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")   # 4/4
	_blocks({giant.id: [ogre.id, wurm.id]}, [ogre.id, wurm.id])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(ogre.zone, Mtg.Zone.GRAVEYARD, "the first two points killed it")
	assert_eq(wurm.zone, Mtg.Zone.BATTLEFIELD,
		"and the Wurm took the other two, not another four")
	assert_eq(wurm.damage, 2)


func test_the_blockers_damage_is_divided_lethal_first() -> void:
	# CR 510.1a: a creature blocking several attackers divides its damage
	# among them. The engine's default division is lethal-first in order,
	# which here kills the 2/2 and leaves one point on the 3/3.
	var small := put_battlefield(0, "Gray Ogre")          # 2/2
	var big := put_battlefield(0, "Hill Giant")           # 3/3
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")   # 4/4
	_blocks({giant.id: [small.id, big.id]}, [small.id, big.id])
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(small.zone, Mtg.Zone.GRAVEYARD, "lethal went to the first")
	assert_eq(big.damage, 2, "and the two points left went to the second")


func test_a_creature_blocking_two_is_only_one_blocker_for_a_cap() -> void:
	# Caverns of Despair caps BLOCKING CREATURES, not blocks
	# ("no more than one creature can block each combat"), so the Giant
	# eating two attackers is still one creature.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	g.max_blockers = 1
	_blocks({giant.id: [a.id, b.id]}, [a.id, b.id])
	assert_eq(g.combat.attackers_blocked_by(giant.id).size(), 2)


# ------------------------------------------------------- Blaze of Glory --

func test_blaze_of_glory_makes_one_creature_eat_the_whole_team() -> void:
	# The printed card, both halves: the Wall may block ANY NUMBER and
	# must block EACH attacker it can. Leaving one out is refused.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var c := put_battlefield(0, "Hurloon Minotaur")
	var wall := put_battlefield(1, "Wall of Stone")     # 0/8, survives it all
	var blaze := give_hand(1, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [a.id, b.id, c.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))       # the defender's window
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	assert_eq(wall.extra_blocks_this_turn, -1, "any number")
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_refused(g.declare_blockers(1, {wall.id: [a.id]}),
		"must block")
	assert_ok(g.declare_blockers(1, {wall.id: [a.id, b.id, c.id]}))
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20, "the Wall ate all three")
	assert_eq(wall.damage, 6, "2 + 2 + 2, all of it into the Wall")


func test_blaze_of_glory_only_orders_blocks_that_are_legal() -> void:
	# "if able" — a flyer the Wall cannot block is not a block it is
	# refusing to make.
	var flyer := put_battlefield(0, "Serra Angel")      # 4/4 flying
	var ground := put_battlefield(0, "Gray Ogre")
	var wall := put_battlefield(1, "Wall of Stone")
	var blaze := give_hand(1, "Blaze of Glory")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [flyer.id, ground.id]))
	resolve_stack()
	assert_ok(g.pass_priority(0))       # the defender's window
	add_mana(1, Mtg.ManaColor.W)
	assert_ok(g.cast_spell(1, blaze, [TargetRef.card(wall)]))
	resolve_stack()
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	# Blocking the one it can is the whole requirement.
	assert_ok(g.declare_blockers(1, {wall.id: [ground.id]}))


# -------------------------------------------- what the cards ask about it --

func test_is_blocking_answers_for_both_of_a_multi_blockers_attackers() -> void:
	# `blocks[b] == a` was the old spelling and it is wrong for the second
	# attacker; every card that asked it now asks CombatState.is_blocking.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	_blocks({giant.id: [a.id, b.id]}, [a.id, b.id])
	assert_true(g.combat.is_blocking(giant.id, a.id))
	assert_true(g.combat.is_blocking(giant.id, b.id), "the SECOND one too")
	assert_eq(g.combat.blockers_of(b.id), [giant.id] as Array[int])
	assert_true(g.combat.blocked_attackers.has(b.id),
		"CR 509.1h — the second attacker is blocked as well")


func test_a_multi_blocker_that_leaves_combat_is_forgotten_everywhere() -> void:
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	_blocks({giant.id: [a.id, b.id]}, [a.id, b.id])
	g.remove_from_combat(giant)
	assert_false(g.combat.blocks.has(giant.id))
	assert_false(g.combat.extra_blocks.has(giant.id))
	assert_eq(g.combat.attackers_blocked_by(giant.id).size(), 0)


func test_an_attacker_that_leaves_is_taken_out_of_the_extra_list() -> void:
	# The mirror case: the departing object is the SECOND attacker, and a
	# stale id in `extra_blocks` would have the Giant still fighting it.
	var a := put_battlefield(0, "Gray Ogre")
	var b := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Two-Headed Giant of Foriys")
	_blocks({giant.id: [a.id, b.id]}, [a.id, b.id])
	g.remove_from_combat(b)
	assert_false(g.combat.is_blocking(giant.id, b.id))
	assert_eq(g.combat.attackers_blocked_by(giant.id), [a.id] as Array[int])


func test_a_single_block_still_writes_nothing_into_the_extra_map() -> void:
	# The shape claim: `blocks` keeps its meaning for every ordinary
	# combat, which is what two dozen cards' `blocks.has(id)` rests on.
	var a := put_battlefield(0, "Gray Ogre")
	var wall := put_battlefield(1, "Wall of Stone")
	_blocks({wall.id: a.id}, [a.id])
	assert_eq(g.combat.blocks[wall.id], a.id)
	assert_true(g.combat.extra_blocks.is_empty())
	assert_eq(g.combat.attackers_blocked_by(wall.id), [a.id] as Array[int])
