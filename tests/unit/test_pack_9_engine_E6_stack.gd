extends GameTest
## Pack 9 engine package E6 — STACK: "this spell can't be countered"
## (Scragnoth, CR 101.2 / 701.5) and a spell EXILED with delay counters that
## comes back as a copy of itself (Ertai's Meddling, CR 701.5a: exiling is
## not countering; CR 707.10: the choices made for the original are kept).
##
## Ertai's Meddling: "X can't be 0. Target spell's controller exiles it with
## X delay counters on it. At the beginning of each of that player's
## upkeeps, if that card is exiled, remove a delay counter from it. If the
## card has no delay counters on it, the player puts it onto the stack as a
## copy of the original spell."
##
## The CARD itself goes back on the stack (Forge's `UseOriginalHost`): it is
## put there, not cast (no SPELL_CAST, no "spells cast this turn"), keeps
## the original's mode, X, targets and cost record, and resolves like any
## spell — an instant into its owner's graveyard, a permanent onto the
## battlefield as itself. A target that changed zones in the meantime is a
## new object (CR 400.7) and is no longer that spell's target.
##
## Scragnoth and Meddling are SYNTHETIC here (their cards are Pack 9 scripts
## written against this API).


## "Target spell's controller exiles it with X delay counters on it ..."
class DelaySpell extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.spell("target spell")

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value: int = 0) -> void:
		game.delay_spell(game.find_instance(target.instance_id), x_value,
			source, controller)

	func describe() -> String:
		return "delays target spell"


static func _meddling() -> CardData:
	return CardData.new("Test Meddling", "{X}{U}", Mtg.CardType.INSTANT) \
		.spell(DelaySpell.new())


static func _scragnoth() -> CardData:
	return CardData.new("Test Scragnoth", "{4}{G}", Mtg.CardType.CREATURE).pt(4, 4) \
		.with_cant_be_countered()


## P0 casts [param card] (main phase, mana given), then passes, so P1 holds
## priority with the spell on the stack.
func _p0_casts(card: CardInstance, targets: Array = [], x := 0) -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_pay_for(0, card, x)
	assert_ok(g.cast_spell(0, card, targets, x))
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1)


## Float exactly the mana [param card] costs at [param x], colour by colour.
func _pay_for(pid: int, card: CardInstance, x := 0) -> void:
	var cost := card.data.cost_for(x)
	for color in cost.colored:
		add_mana(pid, int(color), int(cost.colored[color]))
	if cost.generic + x * cost.x_count > 0:
		add_mana(pid, Mtg.ManaColor.C, cost.generic + x * cost.x_count)


func _p1_meddles(spell: CardInstance, x: int) -> CardInstance:
	var meddling := give_synthetic(1, _meddling())
	add_mana(1, Mtg.ManaColor.U, 1 + x)
	assert_ok(g.cast_spell(1, meddling, [TargetRef.card(spell)], x))
	resolve_stack()
	return meddling


## Advance to [param pid]'s next upkeep with its triggers resolved.
func _to_upkeep_of(pid: int) -> void:
	advance_to_next_turn()
	while g.active_player != pid:
		advance_to_next_turn()
	# advance_to_next_turn stops at MAIN1, after the upkeep's triggers.
	resolve_stack()


func _delay_entries() -> int:
	var n := 0
	for entry in g.delayed_triggers:
		if String(entry.get("desc", "")).contains("delay counter"):
			n += 1
	return n


# ------------------------------------------------- can't be countered --

func test_counterspell_does_nothing_to_an_uncounterable_spell() -> void:
	var scragnoth := give_synthetic(0, _scragnoth())
	_p0_casts(scragnoth)
	var counter := give_hand(1, "Counterspell")
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_eq(g.cast_spell(1, counter, [TargetRef.card(scragnoth)]), "",
		"a legal target all the same")
	resolve_stack()
	assert_eq(scragnoth.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(counter.zone, Mtg.Zone.GRAVEYARD)


func test_the_other_counters_do_nothing_either() -> void:
	for card_name in ["Remove Soul", "Power Sink", "Spell Blast", "Force Spike"]:
		before_each()
		var scragnoth := give_synthetic(0, _scragnoth())
		_p0_casts(scragnoth)
		var counter := give_hand(1, card_name)
		var x := 5 if card_name == "Spell Blast" else 1
		add_mana(1, Mtg.ManaColor.U, 1 + x)
		assert_eq(g.cast_spell(1, counter, [TargetRef.card(scragnoth)], x), "", card_name)
		resolve_stack()
		assert_eq(scragnoth.zone, Mtg.Zone.BATTLEFIELD, card_name)


func test_counter_spell_is_a_no_op_for_every_destination() -> void:
	var scragnoth := give_synthetic(0, _scragnoth())
	_p0_casts(scragnoth)
	for destination in [Mtg.Zone.GRAVEYARD, Mtg.Zone.LIBRARY, Mtg.Zone.EXILE]:
		g.counter_spell(scragnoth, destination)
		assert_eq(scragnoth.zone, Mtg.Zone.STACK)
	g.counter_spell(scragnoth, Mtg.Zone.BATTLEFIELD, 1)   # Desertion
	assert_eq(scragnoth.zone, Mtg.Zone.STACK)
	assert_not_null(g.find_stack_item(scragnoth), "still a spell on the stack")


func test_the_engine_and_the_counter_effect_say_so() -> void:
	var scragnoth := give_synthetic(0, _scragnoth())
	var bear := give_hand(0, "Grizzly Bears")
	assert_true(g.spell_cant_be_countered(scragnoth))
	assert_false(g.spell_cant_be_countered(bear))
	var effect := CounterEffect.new()
	assert_false(effect.affects_spell(scragnoth), "the AI reads this before it counters")
	assert_true(effect.affects_spell(bear))


# ------------------------------------------------------ Ertai's Meddling --

func test_a_meddled_bolt_comes_back_at_its_controllers_second_upkeep() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	_p1_meddles(bolt, 2)
	assert_eq(bolt.zone, Mtg.Zone.EXILE, "exiled, not countered")
	assert_eq(int(bolt.counters.get("delay", 0)), 2)
	assert_eq(g.players[1].life, 20)
	_to_upkeep_of(1)
	assert_eq(int(bolt.counters.get("delay", 0)), 2, "not P1's upkeeps: 'that player's'")
	_to_upkeep_of(0)
	assert_eq(int(bolt.counters.get("delay", 0)), 1)
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	_to_upkeep_of(0)
	assert_eq(g.players[1].life, 17, "the copy hit the original target")
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "the card resolves like any instant")
	assert_eq(_delay_entries(), 0, "the delayed trigger is spent")


func test_the_returning_spell_is_not_cast() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	_p1_meddles(bolt, 1)
	advance_to_next_turn()   # P1
	advance_to_next_turn()   # P0, upkeep done, the bolt is on the stack or resolved
	assert_eq(g.spells_cast_this_turn[0].size(), 0, "put onto the stack, not cast")
	assert_eq(g.players[1].life, 17)


func test_a_target_that_left_makes_it_fizzle() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.card(bear)])
	_p1_meddles(bolt, 1)
	g.destroy(bear)
	_to_upkeep_of(1)
	_to_upkeep_of(0)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD, "fizzled")


func test_a_target_that_left_and_came_back_is_a_new_object() -> void:
	var bear := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.card(bear)])
	_p1_meddles(bolt, 1)
	g.return_to_hand(bear)
	g.players[1].hand.erase(bear)
	g._put_on_battlefield(bear, 1)   # replayed: CR 400.7
	_to_upkeep_of(1)
	_to_upkeep_of(0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD, "the Bolt's target is gone")
	assert_eq(bear.damage, 0)
	assert_eq(bolt.zone, Mtg.Zone.GRAVEYARD)


func test_a_creature_spell_comes_back_as_the_card() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	_p0_casts(bear)
	_p1_meddles(bear, 1)
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	_to_upkeep_of(1)
	_to_upkeep_of(0)
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(bear.controller_id, 0)
	assert_false(bear.is_token, "the card itself, not a token")
	assert_false(bear.counters.has("delay"), "counters stay behind in exile")


func test_an_uncounterable_spell_can_be_meddled_with() -> void:
	var scragnoth := give_synthetic(0, _scragnoth())
	_p0_casts(scragnoth)
	_p1_meddles(scragnoth, 1)
	assert_eq(scragnoth.zone, Mtg.Zone.EXILE, "exile is not a counter (CR 701.5a)")


func test_x_is_remembered() -> void:
	var fireball := give_hand(0, "Fireball")
	_p0_casts(fireball, [TargetRef.player(1)], 2)
	_p1_meddles(fireball, 1)
	_to_upkeep_of(1)
	_to_upkeep_of(0)
	assert_eq(g.players[1].life, 18, "X = 2 again")


func test_a_card_that_leaves_exile_is_left_alone() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	_p1_meddles(bolt, 1)
	# Something takes it out of exile (setup surgery: no card in the pool does).
	g.players[0].exile.erase(bolt)
	bolt.zone = Mtg.Zone.HAND
	g.players[0].hand.append(bolt)
	_to_upkeep_of(1)
	_to_upkeep_of(0)
	assert_eq(bolt.zone, Mtg.Zone.HAND, "'if that card is exiled' (CR 603.4)")
	assert_eq(g.players[1].life, 20)


func test_a_meddled_copy_simply_ceases_to_exist() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	var copy := g.copy_spell_on_stack(bolt, 1, [TargetRef.player(0)])
	_p1_meddles(copy, 1)
	assert_false(g._instances.has(copy.id), "a copy is not a card (CR 707.10a)")
	assert_eq(_delay_entries(), 0)


func test_undo_puts_the_spell_back_on_the_stack() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	var meddling := give_synthetic(1, _meddling())
	add_mana(1, Mtg.ManaColor.U, 2)
	assert_ok(g.cast_spell(1, meddling, [TargetRef.card(bolt)], 1))
	var mark := g.make_mark()
	resolve_stack()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(_delay_entries(), 1)
	g.unmake_to(mark)
	g.end_search()
	assert_eq(bolt.zone, Mtg.Zone.STACK)
	assert_false(bolt.counters.has("delay"))
	assert_eq(_delay_entries(), 0)
	assert_not_null(g.find_stack_item(bolt))


func test_a_snapshot_rewinds_the_counters_and_the_delayed_trigger() -> void:
	var bolt := give_hand(0, "Lightning Bolt")
	_p0_casts(bolt, [TargetRef.player(1)])
	_p1_meddles(bolt, 2)
	var snap := GameSnapshot.take(g)
	_to_upkeep_of(0)
	_to_upkeep_of(0)
	assert_eq(g.players[1].life, 17, "precondition: it came back and hit")
	snap.restore()
	assert_eq(bolt.zone, Mtg.Zone.EXILE)
	assert_eq(int(bolt.counters.get("delay", 0)), 2)
	assert_eq(_delay_entries(), 1)
	assert_eq(g.players[1].life, 20)


# -------------------------------------------- CR 608.3f: copies of permanents --

func test_a_copy_of_a_permanent_spell_resolves_into_a_token() -> void:
	var bear := give_hand(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_ok(g.cast_spell(0, bear))
	var copy := g.copy_spell_on_stack(bear, 0)
	resolve_stack()
	assert_eq(copy.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(copy.is_token, "a copy of a permanent spell becomes a token")
	assert_false(copy.is_copy)
	g.return_to_hand(copy)
	assert_false(g.players[0].hand.has(copy), "and ceases to exist off the battlefield")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
