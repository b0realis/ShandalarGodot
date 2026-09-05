extends GutTest
## CLICKING AN ABILITY ON THE CHAIN — `TargetSpec.Kind.ABILITY` in the duel
## screen's target picker (docs/ROADMAP.md, the 2026-09-01 audit's
## "a human cannot click an ability as a target", closed 2026-09-02).
##
## The kind existed, the engine enforced it, the AI could aim with it, and
## the duel screen had no case for it at all — so Rust and Ayesha Tanaka
## were two cards the opponent could play and the player could not.
##
## AN ABILITY IS NOT ITS SOURCE (CR 113.7a). The chain entry draws the
## permanent's card because that is the only picture there is, but the
## object being pointed at is the ACTIVATION, which is why clicking the
## entry has to build a `TargetRef.ability` and not a `TargetRef.card` —
## and why the permanent's own widget on the battlefield must keep
## behaving like a permanent.


var screen: DuelScreen
## Read back rather than assumed: `_new_game` tosses a coin, so which seat
## opens with priority differs run to run.
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


func _battlefield(pid: int, card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


## One ACTIVATED ABILITY of [param source] on the chain, built the way
## `_chain` in tests/ui/test_auto_target.gd builds a spell: the point under
## test is the targeting step, not who may activate when.
func _chain_ability(owner: int, source: CardInstance) -> StackItem:
	var g: MtgGame = screen.game
	var item := StackItem.new()
	item.kind = Mtg.StackKind.ABILITY
	item.card = source
	item.controller = owner
	item.effects = source.data.activated_abilities[0].effects
	item.description = "%s activates %s" % [
		g.players[owner].player_name, source.data.card_name]
	item.id = g._next_stack_id
	g._next_stack_id += 1
	g.stack.append(item)
	return item


func _rust() -> CardInstance:
	screen.game.players[me].mana_pool.add(Mtg.ManaColor.G, 1)
	return _give(me, "Rust")


# ------------------------------------------------------------- the click --

func test_clicking_the_chain_entry_takes_the_ability_as_a_target() -> void:
	var icy := _battlefield(foe, "Icy Manipulator")
	var item := _chain_ability(foe, icy)
	screen._click_hand_card(_rust())
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"an ability slot opens the picker like any other")
	screen._on_chain_ability_clicked(item)
	assert_eq(screen.game.stack.size(), 2, "Rust went on the chain")
	var rust_item: StackItem = screen.game.stack[1]
	assert_eq(rust_item.targets.size(), 1)
	assert_true(rust_item.targets[0].is_ability,
		"the ACTIVATION, not the Icy Manipulator")
	assert_eq(rust_item.targets[0].ability_id, item.id)


func test_the_ability_really_gets_countered_by_the_click() -> void:
	# End to end, because "the picker built a ref" is only worth having if
	# the ref does the thing the card says.
	var icy := _battlefield(foe, "Icy Manipulator")
	var item := _chain_ability(foe, icy)
	screen._click_hand_card(_rust())
	screen._on_chain_ability_clicked(item)
	var guard := 0
	while not screen.game.stack.is_empty() and guard < 12:
		guard += 1
		screen.game.pass_priority(screen.game.priority_player)
	assert_eq(screen.game.stack.size(), 0, "the chain emptied")


func test_the_permanents_own_widget_is_still_a_permanent() -> void:
	# The Icy Manipulator is on the battlefield AND drawn on the chain.
	# Only the chain entry is the ability; clicking the board one must not
	# quietly become an ability target.
	var icy := _battlefield(foe, "Icy Manipulator")
	_chain_ability(foe, icy)
	screen._click_hand_card(_rust())
	screen._on_card_clicked(icy)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING,
		"a card ref is not a legal ability target, so the picker stays open")
	assert_eq(screen.game.stack.size(), 1, "and Rust has not been cast")


# ----------------------------------------------------------- the cueing --

func test_a_legal_ability_on_the_chain_is_highlighted() -> void:
	var icy := _battlefield(foe, "Icy Manipulator")
	var item := _chain_ability(foe, icy)
	screen._click_hand_card(_rust())
	assert_eq(screen._ability_highlight(item), MiniCard.Highlight.TARGET_LEGAL,
		"a target you may click has to look like one")


func test_an_ability_the_spell_may_not_target_is_not_highlighted() -> void:
	# Rust is "from an ARTIFACT source" — a Prodigal Sorcerer's ping is on
	# the chain as an ability and is still not a legal target.
	var sorcerer := _battlefield(foe, "Prodigal Sorcerer")
	var item := _chain_ability(foe, sorcerer)
	screen._click_hand_card(_rust())
	assert_eq(screen._ability_highlight(item), MiniCard.Highlight.NONE)


func test_nothing_is_highlighted_outside_targeting() -> void:
	var icy := _battlefield(foe, "Icy Manipulator")
	var item := _chain_ability(foe, icy)
	assert_eq(screen._ability_highlight(item), MiniCard.Highlight.NONE)
	assert_eq(screen._ability_target_state(item), -1)


func test_the_chain_entry_for_a_spell_is_untouched() -> void:
	# The optional argument must change nothing for the ordinary case: a
	# SPELL on the chain is still clicked as a card (that is how
	# Counterspell takes it).
	var g: MtgGame = screen.game
	var bolt := _give(foe, "Lightning Bolt")
	g.players[foe].hand.erase(bolt)
	bolt.zone = Mtg.Zone.STACK
	var item := StackItem.new()
	item.kind = Mtg.StackKind.SPELL
	item.card = bolt
	item.controller = foe
	item.effects = bolt.data.spell_effects.duplicate()
	item.description = "casts Lightning Bolt"
	g.stack.append(item)
	var widget := screen._make_card(bolt, item)
	assert_not_null(widget)
	widget.free()
