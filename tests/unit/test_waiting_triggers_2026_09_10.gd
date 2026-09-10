extends GameTest
## THE WAITING-TRIGGER QUEUE (CR 603.3, 603.3b) — 2026-09-10.
##
## A triggered ability does NOTHING when it triggers. It is put on the
## stack the next time a player would receive priority (CR 603.3), and
## between announcing a spell (CR 601.2a) and that spell being on the
## stack (CR 601.2i) nobody receives priority at all. So every trigger
## raised by PAYING THE COST — the {T} that wakes Spirit Shackle, the
## creature a sacrifice cost eats, the land Dingus Egg mourns — goes on
## the stack ABOVE the object it was paying for, and resolves BEFORE it.
##
## Until 2026-09-10 ours went on as it fired, which put it underneath: the
## ledger row read "Triggers that fire while a cost is being paid go on the
## stack BELOW the object being cast/activated". MtgGame._freeze_stack /
## _unfreeze_stack / _waiting_triggers close it.
##
## THE POOL CAN SEE IT. 176 cards have {T} in an activation cost and 13
## trigger on BECAME_TAPPED; 27 pay a sacrifice cost and 18 trigger on
## DIES; two spells (Metamorphosis, Sacrifice) eat a creature as an
## additional cost to be cast. The first two boards below are outcome
## flips rather than order flips: a player at 1 life dies to Dingus Egg
## before the life they were paying for arrives, and Prodigal Sorcerer is
## in the graveyard by the time its own ability resolves.


## THE REPRODUCTION. P0 at 1 life sacrifices a Forest to Dark Heart of the
## Wood ("Sacrifice a Forest: You gain 3 life") while P1 holds Dingus Egg
## ("Whenever a land is put into a graveyard from the battlefield, this
## artifact deals 2 damage to that land's controller").
##
## Old order — the Egg underneath — gained 3 first and took 2 after: life
## 2, alive. CR 603.3b puts the Egg on top: 2 damage first, and the life
## the Forest bought never arrives.
func test_a_cost_trigger_resolves_before_the_ability_it_paid_for() -> void:
	g.players[0].life = 1
	put_battlefield(1, "Dingus Egg")
	var heart := put_battlefield(0, "Dark Heart of the Wood")
	put_battlefield(0, "Forest")
	assert_ok(g.activate_ability(0, heart, 0))
	assert_eq(g.stack.size(), 2, "the ability and the Egg's trigger")
	assert_eq(g.stack[0].kind, Mtg.StackKind.ABILITY,
		"the ability is at the BOTTOM (CR 601.2i)")
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER,
		"the trigger the cost raised is ON TOP (CR 603.3)")
	resolve_stack()
	assert_eq(g.players[0].life, -1, "the Egg cracked before the heart fed")
	assert_true(g.game_over, "and 1 - 2 ends the duel (CR 704.5a)")


## The same rule on the OTHER cost that raises a trigger — {T}. Spirit
## Shackle ("Whenever enchanted creature becomes tapped, put a -0/-2
## counter on it") on Prodigal Sorcerer, a 1/1: tapping for the ping is
## what kills the Sorcerer, and the Shackle's counter now lands FIRST.
## The ability resolves anyway — it exists on the stack independently of
## its source (CR 112.7a, 608.2) — but its source is in the graveyard
## while it does.
func test_a_tap_cost_trigger_resolves_before_the_ability() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var tim := put_battlefield(0, "Prodigal Sorcerer")
	var shackle := give_hand(0, "Spirit Shackle")
	add_mana(0, Mtg.ManaColor.B, 2)
	assert_ok(g.cast_spell(0, shackle, [TargetRef.card(tim)]))
	resolve_stack()
	assert_ok(g.activate_ability(0, tim, 0, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER,
		"the Shackle's trigger is above the ping it paid for")
	# ONE resolution — both seats pass once — and it is the trigger, not
	# the ping.
	assert_ok(g.pass_priority(g.priority_player))
	assert_ok(g.pass_priority(g.priority_player))
	assert_eq(tim.zone, Mtg.Zone.GRAVEYARD,
		"-0/-2 on a 1/1 is a state-based death (CR 704.5f)")
	assert_eq(g.players[1].life, 20, "the ping has not resolved yet")
	assert_eq(g.stack.size(), 1, "and it is still on the stack")
	resolve_stack()
	assert_eq(g.players[1].life, 19, "a dead source still deals its damage")


## A SPELL's additional cost, not an ability's: Metamorphosis eats a
## creature to be cast (CR 601.2h). Rukh Egg's death trigger goes on above
## the spell.
func test_an_additional_cast_cost_trigger_sits_above_the_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var egg := put_battlefield(0, "Rukh Egg")
	var meta := give_hand(0, "Metamorphosis")
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.cast_spell(0, meta, []))
	assert_eq(egg.zone, Mtg.Zone.GRAVEYARD, "the cost was paid")
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[0].kind, Mtg.StackKind.SPELL, "Metamorphosis at the bottom")
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER, "the Egg's death above it")


## APNAP INSIDE THE FLUSH (CR 603.3b): when both players have a trigger
## waiting, the ACTIVE player's goes on the stack first — so it resolves
## LAST. Two Dingus Eggs, one per seat, watching P0 feed the Dark Heart.
func test_the_flush_is_apnap() -> void:
	put_battlefield(0, "Dingus Egg")
	put_battlefield(1, "Dingus Egg")
	var heart := put_battlefield(0, "Dark Heart of the Wood")
	put_battlefield(0, "Forest")
	assert_eq(g.active_player, 0)
	assert_ok(g.activate_ability(0, heart, 0))
	assert_eq(g.stack.size(), 3, "the ability and both Eggs")
	assert_eq(g.stack[1].controller, 0,
		"the active player's trigger goes on first (CR 603.3b)")
	assert_eq(g.stack[2].controller, 1,
		"the non-active player's on top of it, so it resolves first")


## THE NULL. A cast that raises no trigger while its cost is paid leaves
## the queue empty and the stack exactly as it was.
func test_a_cast_with_no_cost_trigger_is_unchanged() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))
	assert_eq(g.stack.size(), 1)
	assert_false(g._stack_frozen, "the freeze is closed by the same call")
	assert_eq(g._waiting_triggers.size(), 0)
	resolve_stack()
	assert_eq(g.players[1].life, 17)


## And a trigger on the CAST itself still goes on above the spell, which is
## where it always went (CR 603.3b) — the freeze must not have moved it.
func test_a_cast_trigger_still_sits_above_its_spell() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	put_battlefield(1, "Nether Void")
	var bear := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear, []))
	assert_eq(g.stack.size(), 2)
	assert_eq(g.stack[0].card, bear, "the spell at the bottom")
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER,
		"Nether Void's counter-trigger above it (CR 603.3b)")
