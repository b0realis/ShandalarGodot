extends GameTest
## WHAT THE AI SPENDS TO BLOCK (audit of 2026-09-04, the companion to that
## day's attack audit — `tests/ai/test_ai_attacks_2026_09_04.gd`).
##
## Attacking had just been rewritten; blocking had never been looked at.
## Two things were wrong with it, and both were found by instrumenting 120
## whole AI-vs-AI games and reading every block decision back out:
##
## 1. THE PANIC LINE WAS ASKED BEFORE THE BLOCKS. `desperate` was
##    `life - <total power of every attacker> <= chump_threshold`, counted
##    with nothing blocked, so a Wizard at 7 life facing three power called
##    itself desperate. It fired in 192 of the 571 combats the AI had a
##    free body for.
## 2. THE CHUMP RUNG HAD NO PRICE. Once desperate, the cheapest legal body
##    went under the attacker whatever it was worth. 49 of the 92 bodies
##    the AI threw away over those 120 games died in a combat it would
##    have survived untouched — 31 of them with four life or more to
##    spare, and one of them a Hypnotic Specter put under an Ironroot
##    Treefolk at 7 life to save 3 damage.
##
## Both readings now go through numbers the AI already had: the block plan
## itself says what gets through, and [method AiPlayer._face_damage_value]
## — the attack side's clock — says what that life is worth against the
## body being spent.
##
## A third gap was on the ATTACKING side of the same combat: `AiPlayer`
## had no [method DecisionAgent.order_blockers], so a gang block was
## divided in whatever order the defender happened to declare it. 46 gang
## blocks in those 120 games, 24 of them order-sensitive.
##
## These tests state the BOARD and the block a competent player makes.


func _wizard(seat := 1) -> AiPlayer:
	return AiPlayer.new(seat, AiProfile.wizard())


## Let seat 1's AI answer the attack, and hand back its blocks.
func _blocks(ai: AiPlayer, attacker_ids: Array) -> Dictionary:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, attacker_ids))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	ai.act(g)
	assert_false(g.awaiting_blockers, "the AI left the block step open")
	return g.combat.blocks


# ------------------------------------------------------- the chump's price --

func test_does_not_chump_a_specter_to_save_three_life_at_seven() -> void:
	# The logged case, exactly. 7 life is inside the Wizard's panic line
	# (6) once three damage is counted, and the Specter is the only legal
	# body — so the old ladder reached the chump rung and spent it. Three
	# life against a 2/2 flier is not a trade.
	var ai := _wizard()
	g.players[1].life = 7
	put_battlefield(1, "Hypnotic Specter")
	var tree := put_battlefield(0, "Ironroot Treefolk")
	assert_eq(_blocks(ai, [tree.id]).size(), 0,
		"a 5.5-point flier does not die to save 3 life at 7")


func test_chumps_when_the_swing_would_actually_kill_us() -> void:
	# Same board at 3 life: the residue after the blocks worth making IS
	# lethal, and then any body at any price beats losing.
	var ai := _wizard()
	g.players[1].life = 3
	var specter := put_battlefield(1, "Hypnotic Specter")
	var tree := put_battlefield(0, "Ironroot Treefolk")
	var blocks := _blocks(ai, [tree.id])
	assert_eq(blocks.size(), 1, "the lethal swing is blocked")
	assert_eq(int(blocks.get(specter.id, -1)), tree.id)


func test_still_chumps_when_the_life_outprices_the_body() -> void:
	# A Llanowar Elves is two points; three damage at 6 life is 4.5 on the
	# same scale. The rung is priced, not closed.
	var ai := _wizard()
	g.players[1].life = 6
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	var blocks := _blocks(ai, [giant.id])
	assert_eq(blocks.size(), 1, "two points of body for 4.5 points of life")
	assert_eq(int(blocks.get(elves.id, -1)), giant.id)


# ------------------------------------------- the panic line after the blocks --

func test_the_value_blocks_take_the_panic_out_of_the_swing() -> void:
	# 12 life against 8 power reads as desperate BEFORE the blocks — and
	# is comfortable after them, because our Craw Wurm trades with theirs
	# and only the Bears gets through. The Elves used to go under it.
	var ai := _wizard()
	g.players[1].life = 12
	var wurm := put_battlefield(1, "Craw Wurm")
	put_battlefield(1, "Llanowar Elves")
	var their_wurm := put_battlefield(0, "Craw Wurm")
	var bears := put_battlefield(0, "Grizzly Bears")
	var blocks := _blocks(ai, [their_wurm.id, bears.id])
	assert_eq(blocks.size(), 1, "only the trade is made")
	assert_eq(int(blocks.get(wurm.id, -1)), their_wurm.id, "wurm on wurm")


func test_the_ladder_still_panics_earlier_at_the_top() -> void:
	# chump_threshold is the difficulty knob and keeps its direction: the
	# Wizard's 6 opens the rung at 8 life against a Hill Giant, the
	# Apprentice's 3 does not. Same board, same code, different profile.
	g.players[1].life = 8
	var elves := put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	var blocks := _blocks(_wizard(), [giant.id])
	assert_eq(int(blocks.get(elves.id, -1)), giant.id, "the Wizard panics")


func test_the_apprentice_does_not_panic_on_the_same_board() -> void:
	g.players[1].life = 8
	put_battlefield(1, "Llanowar Elves")
	var giant := put_battlefield(0, "Hill Giant")
	var blocks := _blocks(AiPlayer.new(1, AiProfile.apprentice()), [giant.id])
	assert_eq(blocks.size(), 0, "the Apprentice's panic line is lower")


# ------------------------------------------- the damage assignment order --

func test_the_gang_block_order_kills_the_blocker_worth_killing() -> void:
	# CR 509.2. Two damage, two blockers: a Grizzly Bears (2/2, four
	# points) and a Llanowar Elves (1/1, two). Lethal-first down the
	# DEFENDER's declaration order buries the Elves and leaves the Bears
	# standing; the attacker's own order buries the Bears.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var erg := put_battlefield(0, "Erg Raiders")
	var elves := put_battlefield(1, "Llanowar Elves")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [erg.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {elves.id: erg.id, bears.id: erg.id}))
	var order: Array = g.combat.damage_order.get(erg.id, [])
	assert_eq(order.size(), 2, "an order was announced")
	assert_eq(int(order[0]), bears.id, "the four-point body is first")


func test_a_blocker_the_damage_cannot_reach_sorts_last() -> void:
	# The Ironroot Treefolk is worth twice the Bears and cannot be killed
	# by two damage at all; spending the whole two on it kills nothing.
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var erg := put_battlefield(0, "Erg Raiders")
	var tree := put_battlefield(1, "Ironroot Treefolk")
	var bears := put_battlefield(1, "Grizzly Bears")
	g.set_agent(0, ai)
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [erg.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {tree.id: erg.id, bears.id: erg.id}))
	var order: Array = g.combat.damage_order.get(erg.id, [])
	assert_eq(int(order[0]), bears.id, "the body the damage can reach is first")
