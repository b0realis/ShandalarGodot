extends GutTest
## THE LONE COUNTER-TARGET — `docs/duel-todo.md` §3.3.
##
## s30's `autoCounterTarget` (`duel.go:2006-2041`, pinned by
## `duel_counter_target_test.go`): *"the single valid target for a spell
## that targets a spell on the stack (e.g. Counterspell) when the opponent
## has exactly one such spell there. This spares the player from manually
## picking the only sensible target when countering a lone opposing
## spell."*
##
## Deliberately NOT generalised to "any slot with exactly one legal
## target": a Terror aimed at the board's only creature would then fire
## without the player ever seeing the targeting cursor, and a cast cannot
## be taken back. The chain is the one zone where the candidate is already
## named on screen, in its own window, which is what makes skipping the
## aiming step safe there and nowhere else.


var screen: DuelScreen
## The seat these tests play from. The duel screen tosses a coin in
## `_new_game`, so WHICH seat opens with priority differs run to run —
## reading it back instead of assuming seat 0 is what keeps these
## deterministic. (Hard-coding 0 made them fail about one run in three.)
var me := 0
var foe := 1


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	me = screen.game.priority_player
	foe = screen.game.opponent_of(me)


func _give(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## Put one spell of [param owner]'s onto the chain, bypassing priority —
## the point under test is the TARGETING step, not who may cast when.
func _chain(owner: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := _give(owner, card_name)
	g.players[owner].hand.erase(inst)
	inst.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = inst
	item.controller = owner
	item.effects = inst.data.spell_effects.duplicate()
	item.description = "%s casts %s" % [
		g.players[owner].player_name, inst.data.card_name]
	g.stack.append(item)
	return inst


func _counterspell() -> CardInstance:
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.U, 2)
	return _give(me, "Counterspell")


func test_one_opposing_spell_is_countered_without_opening_targeting() -> void:
	var bolt := _chain(foe, "Lightning Bolt")
	screen._click_hand_card(_counterspell())
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING,
		"the only sensible target needs no aiming")
	assert_eq(screen.game.stack.size(), 2, "the counter went on the chain")
	var top: StackItem = screen.game.stack.back()
	assert_eq(top.card.data.card_name, "Counterspell")
	assert_eq(top.targets.size(), 1)
	assert_eq(top.targets[0].instance_id, bolt.id, "aimed at the lone spell")


func test_two_opposing_spells_open_targeting_normally() -> void:
	_chain(foe, "Lightning Bolt")
	_chain(foe, "Giant Growth")
	screen._click_hand_card(_counterspell())
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"with a choice to make, the player makes it")
	assert_eq(screen._prompt_label.text, "Select target spell.")


func test_your_own_spell_is_never_the_one_chosen_for_you() -> void:
	# s30 counts only the OPPONENT's chain objects (`item.Controller !=
	# oppName` is a `continue`), so a chain holding one of each still
	# auto-targets — at THEIRS. Countering your own spell is legal —
	# Counterspell says "target spell", not "target spell an opponent
	# controls" — but it is never what "the only sensible target" means,
	# and the shortcut must never pick it.
	var theirs := _chain(foe, "Lightning Bolt")
	_chain(me, "Giant Growth")
	screen._click_hand_card(_counterspell())
	assert_ne(screen.mode, DuelScreen.Mode.TARGETING)
	var top: StackItem = screen.game.stack.back()
	assert_eq(top.targets[0].instance_id, theirs.id,
		"the opponent's spell, not our own")


func test_an_ordinary_removal_spell_still_asks() -> void:
	# The guard that keeps this from becoming "auto-target anything with
	# one candidate". Terror on a board holding one creature must still
	# show the targeting cursor.
	var g: MtgGame = screen.game
	var bear := CardInstance.new(CardRegistry.get_card("Grizzly Bears"),
		g._next_instance_id, foe)
	g._next_instance_id += 1
	g._instances[bear.id] = bear
	g._put_on_battlefield(bear, foe)
	g.recalculate()
	g.players[me].mana_pool.add(Mtg.ManaColor.B, 1)
	g.players[me].mana_pool.add(Mtg.ManaColor.C, 1)
	screen._click_hand_card(_give(me, "Terror"))
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"one creature on the board is not permission to skip the aim")


func test_an_empty_chain_leaves_the_counter_aiming_at_nothing() -> void:
	# No legal target at all: the screen opens targeting and the player
	# reaches for Cancel, which is the pre-existing behaviour and still
	# right — the auto-target must not invent one.
	screen._click_hand_card(_counterspell())
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_eq(screen.game.stack.size(), 0)
