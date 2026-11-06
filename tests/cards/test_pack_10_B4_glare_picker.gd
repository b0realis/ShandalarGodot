extends GutTest
## Pack 10 (the Urza block), batch B4: Wall of Glare is the first PRINTED
## "can block any number of creatures" (CardData.with_extra_blocks(-1)),
## and the human block gesture must offer it — DuelScreen._pick_block keeps
## a creature that may block more in the hand after each assignment
## (tests/ui/test_block_picker.gd pins the gesture on Two-Headed Giant and
## Blaze of Glory; this pins the card).

var screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	# The opponent is attacking; we are the defender picking blocks.
	screen.game.active_player = 1
	screen.game._step_index = Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS)
	screen.mode = DuelScreen.Mode.BLOCKERS

func after_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _summon(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, card_name)
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


func _attacker(card_name: String) -> CardInstance:
	var inst := _summon(card_name, 1)
	screen.game.combat.attackers[inst.id] = true
	return inst


func test_wall_of_glare_stays_in_hand_for_every_attacker() -> void:
	var a := _attacker("Grizzly Bears")
	var b := _attacker("Gray Ogre")
	var c := _attacker("Llanowar Elves")
	var wall := _summon("Wall of Glare", 0)
	assert_eq(screen.game.blocks_allowed(wall), -1)
	screen._pick_block(wall)
	screen._pick_block(a)
	assert_eq(screen._selected_blocker, wall.id, "still in hand after the first block")
	screen._pick_block(b)
	screen._pick_block(c)
	assert_eq(screen._block_map[wall.id], [a.id, b.id, c.id])
	assert_eq(screen._selected_blocker, wall.id, "any number: never full")
	# What the picker assembled is a declaration the engine takes.
	screen.game.awaiting_blockers = true
	assert_eq(screen.game.declare_blockers(0, screen._block_map), "")
	assert_eq(screen.game.combat.attackers_blocked_by(wall.id), [a.id, b.id, c.id] as Array[int])
