extends GameTest
## TWO "SURE WINS" THAT WERE NOT (bug hunt 2026-10-21, ai; Pack 9's
## `engine/ai/tempest_spells.gd`).
##
##  * REINS OF POWER untaps every creature on both sides before the swap,
##    and [method TempestSpells.reins] read the blocks off the table as it
##    stood — a tapped creature blocks nothing. Our Serra Angel tapped
##    (their Icy at our upkeep) was no blocker for the Craw Wurm we would
##    borrow, 6 damage read "through" at 5 life, and the Wizard cast Reins
##    as the game: the untapped Angel blocks the Wurm and both cards are
##    gone. The reading untaps both sides under the search journal now.
##  * CORPSE DANCE returns the top creature card of our graveyard, hasty,
##    for one attack ([method TempestSpells.corpse_dance]); "worth its power
##    when it is a real attacker" never asked whether it could attack. A
##    Wall of Spears (2 power, defender) at 2 life read as lethal; it is
##    exiled at the end step without having attacked.

const TS := preload("res://engine/ai/tempest_spells.gd")


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, id == "pack-9")


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func after_each() -> void:
	g = null


## Our Serra Angel (tapped unless [param untapped_angel]) and their Craw
## Wurm at 5 life, our first main phase; what Reins of Power is worth.
func _reins(angel_tapped: bool) -> Variant:
	before_each()
	advance_to_step(Mtg.Step.MAIN1)
	var angel := put_battlefield(0, "Serra Angel")
	angel.tapped = angel_tapped
	var wurm := put_battlefield(1, "Craw Wurm")
	g.players[1].life = 5
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var reins := give_hand(0, "Reins of Power")
	var choice: Variant = TS.reins(g, ai, reins, reins.data.spell_effects[0])
	assert_eq(angel.tapped, angel_tapped, "the reading leaves the Angel as it was")
	assert_false(wurm.tapped)
	assert_null(g.undo_log, "and no search open")
	return choice


func test_reins_counts_the_tapped_angel_as_their_blocker() -> void:
	assert_eq(_reins(true), {}, "untapped by Reins, the Angel blocks the Wurm")
	assert_eq(_reins(false), {}, "the same board with the Angel untapped")


## THE CONTROL: with no creature of ours to block, the Wurm is the game.
func test_reins_with_nothing_of_ours_is_still_the_game() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Craw Wurm").tapped = true
	g.players[1].life = 5
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var reins := give_hand(0, "Reins of Power")
	var choice: Variant = TS.reins(g, ai, reins, reins.data.spell_effects[0])
	assert_true(choice is Dictionary and float((choice as Dictionary).get("value", 0.0)) >= TS.LETHAL_WORTH,
		"their tapped Wurm, untapped by Reins, attacks for the game")


func _in_graveyard(pid: int, card_name: String) -> CardInstance:
	var inst := _make_instance(pid, card_name)
	inst.zone = Mtg.Zone.GRAVEYARD
	g.players[pid].graveyard.append(inst)
	return inst


func test_corpse_dance_raises_no_wall() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_in_graveyard(0, "Wall of Spears")
	g.players[1].life = 2
	var ai := AiPlayer.new(0, AiProfile.wizard())
	assert_eq(TS.corpse_dance(g, ai), {}, "a defender cannot attack")


## THE CONTROL: a Hill Giant on top at 2 life, nothing of theirs untapped.
func test_corpse_dance_still_raises_an_attacker() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_in_graveyard(0, "Hill Giant")
	g.players[1].life = 2
	var ai := AiPlayer.new(0, AiProfile.wizard())
	var choice: Dictionary = TS.corpse_dance(g, ai)
	assert_gte(float(choice.get("value", 0.0)), TS.LETHAL_WORTH)
