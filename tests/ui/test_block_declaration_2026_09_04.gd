extends GutTest
## THE BLOCK THAT WAS NEVER DECLARED — the playtest defect of 2026-09-04.
##
## *"Opponent attacked with Mahamoti Djinn (5/6) and I blocked with Giant
## Spider (2/4). Spider was not killed and all damage went to my life
## directly."* Both halves of that are what an UNBLOCKED attacker does,
## and the engine gets every one of those cases right
## (`tests/unit/test_combat_evasion_2026_09_04.gd`, twenty-five of them,
## twenty-four green before this pass touched anything): the block never
## reached it.
##
## HOW A BLOCK COULD BE LOST BETWEEN THE SCREEN AND THE ENGINE. A creature
## PICKED UP as a blocker leaves its territory for the Combat window's
## shield lane ([method DuelScreen._combat_lineup]) — so a gesture that
## ended one click early looked exactly like a finished block, with only
## the red arrow to tell them apart. Nothing said otherwise: the bar went
## on showing whatever it had said before, a click that missed the
## attacker was swallowed in silence, and Done then declared NO blockers
## and threw the held creature away without a word.
##
## THE ORIGINAL SPEAKS THREE SENTENCES HERE and we were saying one of
## them. `@PROMPT_DEFENDWHOM` (`shandalar-src/Program/UIStrings.txt:993`)
## is `Block which attacker?` / `Illegal block.` / `That isn't an
## attacker.`, and `@PROMPT_CHOOSEBLOCKERS` (`:1139`) is `Choose blockers`
## / `Block which attacker?` / `Illegal block.` The question in the middle
## is the one that was missing, and it is the one that says a block is not
## finished yet.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	# The opponent is attacking and the engine is waiting on our blocks.
	screen.game.active_player = 1
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	screen.game.awaiting_blockers = true
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


## An attacking creature — tapped, as attacking leaves it (CR 508.1f).
func _attacker(card_name: String) -> CardInstance:
	var inst := _summon(card_name, 1)
	screen.game.combat.attackers[inst.id] = true
	inst.tapped = true
	return inst


func _prompt() -> String:
	return screen._prompt_label.text


# ================================================== THE OWNER'S COMBAT --

func test_the_owners_gesture_reaches_the_engine() -> void:
	var djinn := _attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	screen._pick_block(djinn)
	screen._on_done()
	assert_true(screen.game.combat.is_blocking(spider.id, djinn.id),
		"reach blocks the flyer and the engine has the block")
	assert_true(screen.game.combat.blocked_attackers.has(djinn.id),
		"CR 509.1h: the Djinn became blocked")
	assert_false(screen.game.awaiting_blockers, "the declaration went in")


func test_a_held_blocker_is_never_declared_away_by_done() -> void:
	# THE DEFECT. The Spider is picked up and never aimed; it is standing
	# in the shield lane opposite the Djinn, so the player believes it is
	# blocking. Done must not turn that into "no blockers".
	var djinn := _attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	assert_true((screen._combat_lineup()[1] as Array).has(spider.id),
		"a held creature stands in the Combat window's blocker lane")
	screen._on_done()
	assert_true(screen.game.awaiting_blockers,
		"the block window is still open — nothing was declared")
	assert_eq(screen._selected_blocker, -1, "and the creature was put down")
	assert_string_contains(_prompt(), "Giant Spider")
	assert_string_contains(_prompt(), "not blocking")
	# The block is still there to be made, which is the whole point.
	screen._pick_block(spider)
	screen._pick_block(djinn)
	screen._on_done()
	assert_true(screen.game.combat.is_blocking(spider.id, djinn.id))


func test_the_second_done_declares_what_was_actually_pencilled_in() -> void:
	# Putting the held creature down must not cost the blocks already made
	# — one extra click, never a lost block.
	var djinn := _attacker("Mahamoti Djinn")
	var angel := _attacker("Serra Angel")
	var spider := _summon("Giant Spider", 0)
	var second := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	screen._pick_block(djinn)          # a real block
	screen._pick_block(second)         # ...and one left in hand
	screen._on_done()
	assert_true(screen.game.awaiting_blockers)
	assert_true(screen._block_map.has(spider.id),
		"the finished block survived the put-down")
	screen._on_done()
	assert_true(screen.game.combat.is_blocking(spider.id, djinn.id))
	assert_false(screen.game.combat.blocks.has(second.id))
	assert_false(screen.game.combat.blocked_attackers.has(angel.id))


# ============================== A CREATURE THAT CAN BLOCK NOTHING IS NOT --
#                                                       LIFTED AT ALL --

func test_a_tapped_creature_is_refused_at_the_pick_up() -> void:
	var djinn := _attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	spider.tapped = true
	screen._pick_block(spider)
	assert_eq(screen._selected_blocker, -1,
		"it never leaves its territory for the shield lane")
	assert_false((screen._combat_lineup()[1] as Array).has(spider.id))
	assert_string_contains(_prompt(), "Illegal block.")
	assert_string_contains(_prompt(), "tapped")
	screen._on_done()
	assert_false(screen.game.combat.blocked_attackers.has(djinn.id),
		"and a tapped creature still blocks nothing")


func test_a_ground_creature_facing_only_flyers_is_refused_at_the_pick_up() -> void:
	_attacker("Mahamoti Djinn")
	var bear := _summon("Grizzly Bears", 0)
	screen._pick_block(bear)
	assert_eq(screen._selected_blocker, -1)
	assert_string_contains(_prompt(), "Illegal block.")
	assert_string_contains(_prompt(), "flying")


func test_a_creature_that_can_block_one_of_several_is_still_lifted() -> void:
	# The gate is "can block NOTHING", not "can block this one".
	var djinn := _attacker("Mahamoti Djinn")
	var ogre := _attacker("Gray Ogre")
	var bear := _summon("Grizzly Bears", 0)
	screen._pick_block(bear)
	assert_eq(screen._selected_blocker, bear.id)
	screen._pick_block(djinn)
	assert_string_contains(_prompt(), "Illegal block.")
	screen._pick_block(ogre)
	assert_eq(screen._block_map[bear.id], [ogre.id])


# ============================================ THE THREE 1997 SENTENCES --

func test_a_held_blocker_makes_the_bar_ask_which_attacker() -> void:
	_attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	# @PROMPT_DEFENDWHOM entry 1 / @PROMPT_CHOOSEBLOCKERS entry 2.
	assert_eq(_prompt(), "Block which attacker?")


func test_clicking_something_that_is_not_an_attacker_says_so() -> void:
	_attacker("Mahamoti Djinn")
	var idle := _summon("Gray Ogre", 1)   # theirs, but not attacking
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	screen._pick_block(idle)
	# @PROMPT_DEFENDWHOM entry 3, UIStrings.txt:997 — verbatim.
	assert_eq(_prompt(), "That isn't an attacker.")
	assert_true(screen._block_map.is_empty(), "and no block was made")


func test_putting_a_blocker_down_puts_the_standing_question_back() -> void:
	_attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	screen._pick_block(spider)   # the take-back gesture
	assert_eq(screen._selected_blocker, -1)
	assert_eq(_prompt(), "Combat phase: Choose blockers.")


func test_a_completed_block_puts_the_standing_question_back() -> void:
	var djinn := _attacker("Mahamoti Djinn")
	var spider := _summon("Giant Spider", 0)
	screen._pick_block(spider)
	screen._pick_block(djinn)
	assert_eq(screen._selected_blocker, -1, "an ordinary blocker is put down")
	assert_eq(_prompt(), "Combat phase: Choose blockers.")


# ================================================ THE MULTI-BLOCK CASE --

func test_a_multi_blocker_keeps_the_question_while_it_has_room() -> void:
	var a := _attacker("Gray Ogre")
	var b := _attacker("Hurloon Minotaur")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	assert_eq(_prompt(), "Block which attacker?")
	screen._pick_block(a)
	assert_eq(screen._selected_blocker, giant.id, "still held for its second")
	assert_eq(_prompt(), "Block which attacker?")
	screen._pick_block(b)
	assert_eq(screen._selected_blocker, -1)
	assert_eq(_prompt(), "Combat phase: Choose blockers.")


func test_a_partly_committed_multi_blocker_can_still_be_taken_back() -> void:
	# The pick-up gate must never close the take-back door: this Giant has
	# blocked the only attacker it can legally block, so "can it block
	# anything?" is false — and it must still be liftable to undo.
	var djinn := _attacker("Mahamoti Djinn")   # nothing here can block it
	var ogre := _attacker("Gray Ogre")
	var giant := _summon("Two-Headed Giant of Foriys", 0)
	screen._pick_block(giant)
	screen._pick_block(ogre)
	assert_eq(screen._block_map[giant.id], [ogre.id])
	assert_eq(screen._selected_blocker, giant.id, "held: it may block again")
	screen._pick_block(giant)   # put it down, blocks and all
	assert_false(screen._block_map.has(giant.id))
	assert_eq(screen._selected_blocker, -1)
	screen._on_done()
	assert_false(screen.game.combat.blocked_attackers.has(djinn.id))
	assert_false(screen.game.combat.blocked_attackers.has(ogre.id))
