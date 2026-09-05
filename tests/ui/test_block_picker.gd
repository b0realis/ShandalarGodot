extends GutTest
## THE BLOCK GESTURE, and its one-to-many case — `DuelScreen._pick_block`.
##
## `Duel.hlp`: *"To make one of your creatures a blocker, click on it.
## Next, click on the attacker you want your blocker to block."* That is
## unchanged, and the first two tests here pin it, because the engine
## grew one-to-many blocks on 2026-09-02 and the ordinary creature must
## behave exactly as it always did.
##
## WHAT IS NEW: a creature an effect lets block more than one attacker
## (CR 509.1b — Two-Headed Giant of Foriys, anything under Blaze of Glory)
## stays in the hand after an assignment, so its second block is one more
## click rather than a re-pick. Without this the rules engine accepted a
## declaration the screen had no way to make — the same shape of gap as
## `TargetSpec.Kind.ABILITY` having no case in the target picker.


var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	# The opponent is attacking; we are the defender picking blocks.
	screen.game.active_player = 1
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	screen.mode = DuelScreen.Mode.BLOCKERS


func _summon(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _attacker(card_name: String) -> CardInstance:
	var inst := _summon(card_name, 1)
	screen.game.combat.attackers[inst.id] = true
	return inst


# ------------------------------------------------- the ordinary creature --

func test_pick_then_aim_makes_one_block() -> void:
	var attacker := _attacker("Gray Ogre")
	var mine := _summon("Grizzly Bears", 0)
	screen._pick_block(mine)
	assert_eq(screen._selected_blocker, mine.id, "picked up")
	screen._pick_block(attacker)
	assert_eq(screen._block_map[mine.id], [attacker.id])
	assert_eq(screen._selected_blocker, -1,
		"a creature that may block one is put down once it has")


func test_clicking_an_assigned_blocker_takes_the_block_back() -> void:
	var attacker := _attacker("Gray Ogre")
	var mine := _summon("Grizzly Bears", 0)
	screen._pick_block(mine)
	screen._pick_block(attacker)
	screen._pick_block(mine)
	assert_false(screen._block_map.has(mine.id))
	assert_eq(screen._selected_blocker, -1)


func test_an_illegal_block_is_refused_with_the_1997_words() -> void:
	var flyer := _attacker("Serra Angel")
	var mine := _summon("Grizzly Bears", 0)
	screen._pick_block(mine)
	screen._pick_block(flyer)
	assert_false(screen._block_map.has(mine.id))
	assert_true(screen._prompt_label.text.contains("Illegal block."),
		screen._prompt_label.text)


# ------------------------------------------------------- the second block --

func test_the_giant_keeps_the_blocker_in_hand_for_a_second_attacker() -> void:
	var a := _attacker("Gray Ogre")
	var b := _attacker("Grizzly Bears")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	screen._pick_block(a)
	assert_eq(screen._selected_blocker, giant.id,
		"still held: it may block another")
	screen._pick_block(b)
	assert_eq(screen._block_map[giant.id], [a.id, b.id])
	assert_eq(screen._selected_blocker, -1, "and now it is full")


func test_a_full_blocker_refuses_a_third_attacker() -> void:
	var a := _attacker("Gray Ogre")
	var b := _attacker("Grizzly Bears")
	var c := _attacker("Hurloon Minotaur")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	screen._pick_block(a)
	screen._pick_block(b)
	# It was put down when it filled up, so a third needs a re-pick — and
	# picking a full creature up is the take-back gesture.
	screen._selected_blocker = giant.id
	screen._pick_block(c)
	assert_eq(screen._block_map[giant.id], [a.id, b.id], "no third block")
	assert_true(screen._prompt_label.text.contains("can block only 2"),
		screen._prompt_label.text)


func test_taking_a_multi_blocker_back_drops_every_block_at_once() -> void:
	var a := _attacker("Gray Ogre")
	var b := _attacker("Grizzly Bears")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	screen._pick_block(a)
	screen._pick_block(b)
	screen._pick_block(giant)     # full, so this is the take-back
	assert_false(screen._block_map.has(giant.id))


func test_the_same_attacker_cannot_be_blocked_twice_by_one_creature() -> void:
	var a := _attacker("Gray Ogre")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	screen._pick_block(a)
	screen._pick_block(a)
	assert_eq(screen._block_map[giant.id], [a.id])


func test_the_declaration_the_screen_builds_is_one_the_engine_takes() -> void:
	# The end of the gesture: what the picker assembles has to be what
	# MtgGame.declare_blockers accepts, or the whole thing is theatre.
	var g: MtgGame = screen.game
	var a := _attacker("Gray Ogre")
	var b := _attacker("Grizzly Bears")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	g.awaiting_blockers = true
	screen._pick_block(giant)
	screen._pick_block(a)
	screen._pick_block(b)
	assert_eq(g.declare_blockers(0, screen._block_map), "")
	assert_eq(g.combat.attackers_blocked_by(giant.id), [a.id, b.id] as Array[int])
