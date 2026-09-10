extends GameTest
## TWO THINGS FOUND WHILE MOVING PHANTASMAL TERRAIN ONTO CardData.as_it_enters
## (2026-09-09).
##
## ONE — THE LICH'S PRICE. *"As this enchantment enters, you lose life
## equal to your life total"* is a REPLACEMENT effect (CR 614.1c): it is
## applied AS the enchantment enters, uses no stack, and there is no moment
## at which the Lich is on the battlefield and the life is not yet paid.
## It was an ENTERS_BATTLEFIELD trigger, which is a stack object, so both
## players held priority over a Lich standing at twenty life with *"you
## don't lose the game for having 0 or less life"* already true.
##
## What that window bought, reproduced below: at 2 life, a Lightning Bolt
## thrown into it puts the controller on -1 — and *"lose life equal to your
## life total"* then resolves against -1, which is a loss of -1, which is a
## GAIN of 1, which the Lich's own second static turns into a CARD DRAW.
## The window was worth two life and a card. It is closed.
##
## TWO — WHAT `controller` MEANS ON BECAME_TAPPED. Five sites in
## MtgGame dispatch the event; two of them used to send the ACTIVATING
## player and three the permanent's controller. No card in the pool read
## the key, so nothing was broken — which is exactly why it needed a test
## before it rotted back. `controller` is the PERMANENT'S controller, on
## this event as on every other one that carries the key (see
## Mtg.EventType.ABILITY_ACTIVATED, which carries the acting player
## separately, as `player`, because the two are not the same thing). One
## test per dispatch site, and where the two values can be pulled apart —
## an ability the whole table may activate, an Icy tapping something across
## the table, a regeneration somebody else's removal spell paid for — they
## are pulled apart.


# ------------------------------------------------- the synthetic apparatus --

## Writes down the `controller` every BECAME_TAPPED event carries, in the
## order the events were dispatched. A permanent of its own, so the trigger
## index reaches it exactly as it reaches a card.
class Ledger:
	static func data() -> CardData:
		return CardData.new("Test Tap Ledger", "{1}", Mtg.CardType.ENCHANTMENT) \
			.triggered(TriggeredAbility.new(
				Mtg.EventType.BECAME_TAPPED, Ledger.record,
				"Whenever a permanent becomes tapped, write down the player "
				+ "the event called its controller."))

	static func record(_game: MtgGame, source: CardInstance,
			event: GameEvent) -> void:
		var seen: Array = source.memory.get("seen", [])
		seen.append(int(event.data["controller"]))
		source.memory["seen"] = seen


## "{T}: Nothing. Any player may activate this ability." The one shape in
## which a tap-cost activation's PAYER is not the permanent's controller —
## Ifh-Bíff Efreet, Land's Edge and Clergy of the Holy Nimbus hand their
## abilities to the table the same way, and none of them costs {T} yet.
class Contraption:
	static func data() -> CardData:
		return CardData.new("Test Contraption", "{2}", Mtg.CardType.ARTIFACT) \
			.activated(ActivatedAbility.new("", true, [],
				"{T}: Nothing happens. Any player may activate this ability.") \
				.anyone_activated())


func _ledger(pid: int) -> CardInstance:
	return put_synthetic(pid, Ledger.data())


func _seen(ledger: CardInstance) -> Array:
	return ledger.memory.get("seen", [])


## Stop the game at the FIRST instant [param inst] is on the battlefield —
## the earliest moment any player could act on it.
func _resolve_until_it_arrives(inst: CardInstance) -> void:
	var guard := 0
	while inst.zone != Mtg.Zone.BATTLEFIELD and not g.game_over and guard < 40:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_lt(guard, 40, "the permanent arrived")


func _cast_lich(pid: int) -> CardInstance:
	var lich := give_hand(pid, "Lich")
	add_mana(pid, Mtg.ManaColor.B, 4)
	assert_ok(g.cast_spell(pid, lich, []))
	return lich


# ================================================ ONE: THE LICH'S PRICE ==

func test_the_price_is_paid_as_the_lich_enters() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var lich := _cast_lich(0)
	_resolve_until_it_arrives(lich)
	assert_true(g.stack.is_empty(),
		"nothing of the Lich's own is waiting on the stack (CR 614.1c)")
	assert_eq(g.players[0].life, 0,
		"the life is gone at the first instant the Lich is on the battlefield")
	assert_false(g.game_over, "and the bargain kept them alive at 0")


func test_there_is_no_window_between_the_lich_and_its_price() -> void:
	# THE REPRODUCTION. At 2 life with three lands, a Lightning Bolt taken
	# at the earliest instant the opponent can throw one. While the price
	# was a trigger the Bolt landed FIRST: -1 life, three lands eaten by the
	# damage trigger, and then "lose life equal to your life total" paid out
	# a loss of -1 — a gain, which "if you would gain life, draw that many
	# cards instead" turned into a card. Now the price is already paid and
	# the Bolt can only land on top of it.
	g.players[0].life = 2
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	var bolt := give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.MAIN1)
	var lich := _cast_lich(0)
	_resolve_until_it_arrives(lich)
	assert_eq(g.players[0].life, 0, "the price came first — it always does")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].life, -3,
		"three damage on top of a life total the Lich had already emptied")
	assert_eq(g.players[0].hand.size(), 0,
		"and no card: a life LOSS never became a gain, so nothing was drawn")
	assert_eq(g.players[0].battlefield.size(), 1,
		"three damage ate the three lands")
	assert_eq(lich.zone, Mtg.Zone.BATTLEFIELD, "and the Lich itself stands")
	assert_false(g.game_over, "you don't lose the game for having -3 life")


func test_the_naming_is_a_replacement_and_not_an_arrival_trigger() -> void:
	var lich := CardRegistry.get_card("Lich")
	assert_true(lich.as_enters.is_valid(),
		"the price is CardData.as_enters (CR 614.1c)")
	for trig in lich.triggered_abilities:
		assert_ne(trig.event_type, Mtg.EventType.ENTERS_BATTLEFIELD,
			"and nothing of the Lich's goes on the stack as it arrives")


# ------------------------------- the other three clauses, exactly as they were --

func test_the_bargain_still_stands() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var lich := _cast_lich(0)
	resolve_stack()
	assert_eq(lich.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.players[0].life, 0)
	assert_true(g.players[0].cant_lose_to_life,
		"you don't lose the game for having 0 or less life")
	assert_true(g.players[0].life_gain_becomes_draw,
		"if you would gain life, draw that many cards instead")
	assert_false(g.game_over)


func test_gaining_life_still_draws_cards() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	_cast_lich(0)
	resolve_stack()
	var hand := g.players[0].hand.size()
	g.adjust_life(0, 3)
	assert_eq(g.players[0].life, 0, "no life was gained")
	assert_eq(g.players[0].hand.size(), hand + 3, "three cards instead")


func test_damage_still_feeds_the_lich() -> void:
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	_cast_lich(0)
	resolve_stack()
	var permanents := g.players[0].battlefield.size()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.pass_priority(0))
	assert_ok(g.cast_spell(1, bolt, [TargetRef.player(0)]))
	resolve_stack()
	assert_eq(g.players[0].battlefield.size(), permanents - 3,
		"three damage, three permanents")


func test_a_lich_in_a_graveyard_still_loses_the_game() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var lich := _cast_lich(0)
	resolve_stack()
	g.players[0].life = 7   # so it is the TRIGGER that ends it, not 0 life
	g.destroy(lich)
	resolve_stack()
	assert_true(g.game_over)
	assert_eq(g.winner, 1)


func test_a_bounced_lich_still_costs_only_the_enchantment() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var lich := _cast_lich(0)
	resolve_stack()
	g.players[0].life = 7   # hold the total up: 0 life kills once the aura goes
	g.return_to_hand(lich)
	assert_eq(lich.zone, Mtg.Zone.HAND)
	assert_true(g.stack.is_empty(), "no trigger was put on the stack")
	resolve_stack()
	assert_false(g.game_over,
		"only a Lich put into a GRAVEYARD from the battlefield loses the game")
	assert_eq(g.players[0].life, 7)


# ============================ TWO: `controller` ON BECAME_TAPPED ==
#
# One test per dispatch site in MtgGame. The key is the TAPPED PERMANENT'S
# controller at every one of them.

func test_a_tap_for_mana_names_the_lands_controller() -> void:
	# MtgGame.tap_for_mana. The two values cannot be pulled apart here —
	# see the refusal pinned below — but the meaning is still the
	# permanent's, and that is what a watcher reads.
	var ledger := _ledger(0)
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.tap_for_mana(1, theirs))
	resolve_stack()
	assert_eq(_seen(ledger), [1], "their Forest, their tap, their number")


func test_nobody_can_tap_a_land_they_do_not_control_for_mana() -> void:
	# Which is WHY the mana site could never tell the two apart: the
	# activator of a mana ability is always the permanent's controller.
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	assert_refused(g.tap_for_mana(0, theirs), "you don't control that permanent")


func test_a_tap_cost_names_the_permanents_controller() -> void:
	# MtgGame.activate_ability, the {T} in the cost — an Icy Manipulator
	# tapping itself to pay for its own ability. Both ends are written
	# down, and since 2026-09-10 in the CLOCK's order as well as the
	# stack's: a trigger raised while a cost is being paid waits for the
	# ability to be on the stack and then goes ABOVE it (CR 603.3b,
	# MtgGame._waiting_triggers), so the Icy's own tap is recorded first
	# and the creature it went on to tap second. It read the other way
	# round until the waiting queue closed that ledger row.
	var ledger := _ledger(0)
	var icy := put_battlefield(1, "Icy Manipulator")
	var target := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(1, icy, 0, [TargetRef.card(target)]))
	resolve_stack()
	assert_true(icy.tapped and target.tapped, "both ends of the Icy fired")
	assert_eq(_seen(ledger), [1, 0],
		"their Icy, then our creature — each named by its own controller")


func test_an_ability_the_table_may_activate_names_its_controller() -> void:
	# THE ONE SHAPE WHERE THE ACTIVATOR IS NOT THE CONTROLLER. Seat 1 pays
	# the {T}; the permanent is seat 0's, and the event says so.
	var ledger := _ledger(0)
	var thing := put_synthetic(0, Contraption.data())
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, thing, 0, []))
	assert_true(thing.tapped, "seat 1 tapped a permanent seat 0 controls")
	resolve_stack()
	assert_eq(_seen(ledger), [0],
		"the PERMANENT'S controller, not the player who paid the cost")


func test_attacking_names_the_attackers_controller() -> void:
	# MtgGame.declare_attackers — attacking taps (CR 508.1f).
	var ledger := _ledger(1)
	var bear := put_battlefield(0, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bear.id]))
	resolve_stack()
	assert_true(bear.tapped)
	assert_eq(_seen(ledger), [0], "our attacker, our number")


func test_a_stolen_creature_attacking_names_its_new_controller() -> void:
	# CONTROL, not ownership: the Giant is seat 1's card, seat 0's
	# permanent, and it is seat 0 the event names.
	var ledger := _ledger(1)
	var giant := put_battlefield(1, "Hill Giant")
	var steal := give_hand(0, "Control Magic")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, steal, [TargetRef.card(giant)]))
	resolve_stack()
	assert_eq(giant.controller_id, 0, "ours now")
	advance_to_next_turn()          # theirs
	advance_to_next_turn()          # ours again, and the Giant may swing
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_eq(g.active_player, 0)
	ledger.memory["seen"] = []      # forget the turns we walked through
	assert_ok(g.declare_attackers(0, [giant.id]))
	resolve_stack()
	assert_eq(_seen(ledger), [0], "the thief, not the owner")


func test_a_regeneration_tap_names_the_regenerated_permanents_controller() -> void:
	# MtgGame.destroy — the tap taken INSTEAD of destruction (CR 701.15c).
	# Whoever aimed the removal, the permanent — and the number — are the
	# skeleton's controller's.
	var ledger := _ledger(0)
	var skeleton := put_battlefield(1, "Drudge Skeletons")
	advance_to_step(Mtg.Step.MAIN1)
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.B)
	assert_ok(g.activate_ability(1, skeleton, 0, []))
	resolve_stack()
	assert_eq(skeleton.regeneration_shields, 1, "the shield is bought")
	assert_true(_seen(ledger).is_empty(), "regenerating is not tapping — yet")
	g.destroy(skeleton)
	resolve_stack()
	assert_eq(skeleton.zone, Mtg.Zone.BATTLEFIELD, "it regenerated")
	assert_true(skeleton.tapped, "and regeneration taps")
	assert_eq(_seen(ledger), [1], "their skeleton, however it got there")


func test_a_tap_by_effect_names_the_tapped_permanents_controller() -> void:
	# MtgGame.tap_permanent — an Icy Manipulator reaching across the table.
	# The activator is seat 0 and the land is seat 1's, so this site can
	# tell the two meanings apart on its own. The Icy's own {T} is recorded
	# first: its trigger waited for the ability and went on above it
	# (CR 603.3b), and the land is not tapped until that ability resolves.
	var ledger := _ledger(0)
	var icy := put_battlefield(0, "Icy Manipulator")
	var theirs := put_battlefield(1, "Forest")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, icy, 0, [TargetRef.card(theirs)]))
	resolve_stack()
	assert_true(theirs.tapped, "the Icy tapped it")
	assert_eq(_seen(ledger), [0, 1],
		"our Icy paying its own {T}, then THEIR land — never the activator")


# ================= THREE: THE SIBLINGS THAT SHARED THE SHAPE ==
#
# Five other cards put an "As ... enters" clause on an arrival trigger. The
# pass that fixed Phantasmal Terrain judged them harmless — the three that
# "choose an opponent" have one legal answer in a duel, and Jihad and
# Psychic Allergy guard their statics with memory.has(...) and do nothing
# until the trigger resolves. FOUR OF THE FIVE were wrong anyway, and this
# is what pulled them apart.

func test_jihads_anthem_is_up_before_anybody_can_act() -> void:
	# The guard was right that Jihad does nothing until the choice is made
	# — and that IS the bug, because the choice should already be made.
	# A Samite Healer under a chosen Jihad is a 3/2; in the window it was
	# a 1/1, and a Prodigal Sorcerer's single point killed it.
	var healer := put_battlefield(0, "Samite Healer")     # white 1/1
	var tim := put_battlefield(1, "Prodigal Sorcerer")    # blue: the hint
	var jihad := give_hand(0, "Jihad")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.W, 3)
	assert_ok(g.cast_spell(0, jihad, []))
	_resolve_until_it_arrives(jihad)
	assert_true(g.stack.is_empty(), "nothing of Jihad's own is waiting")
	assert_eq(healer.cur_power, 3, "the anthem is up as Jihad arrives")
	assert_eq(healer.cur_toughness, 2, "+2/+1, toughness included")
	assert_ok(g.pass_priority(0))
	assert_ok(g.activate_ability(1, tim, 0, [TargetRef.card(healer)]))
	resolve_stack()
	assert_eq(healer.zone, Mtg.Zone.BATTLEFIELD,
		"a 3/2 takes a point and lives; the 1/1 in the old window did not")


func test_the_racks_choice_is_out_of_a_thiefs_reach() -> void:
	# Aladdin steals the Rack at the earliest instant anybody can act. With
	# the choice on a trigger the stamp was made afterwards, FROM THE
	# THIEF'S SEAT, and named the Rack's own caster: seat 0 spent the game
	# discarding to four. The choice is locked in as it enters now.
	var aladdin := put_battlefield(1, "Aladdin")
	var rack := give_hand(0, "Cursed Rack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 4)
	assert_ok(g.cast_spell(0, rack, []))
	_resolve_until_it_arrives(rack)
	assert_eq(int(rack.memory.get("victim", -1)), 1,
		"the opponent was chosen as it entered (CR 614.1c)")
	assert_eq(g.players[1].max_hand_size, 4, "and the prison is already theirs")
	assert_ok(g.pass_priority(0))
	add_mana(1, Mtg.ManaColor.R, 2)
	add_mana(1, Mtg.ManaColor.C, 1)
	assert_ok(g.activate_ability(1, aladdin, 0, [TargetRef.card(rack)]))
	resolve_stack()
	assert_eq(rack.controller_id, 1, "they took it")
	assert_eq(int(rack.memory["victim"]), 1,
		"and it keeps squeezing the player it chose, not its caster")
	assert_eq(g.players[1].max_hand_size, 4, "the thief holds their own prison")
	assert_eq(g.players[0].max_hand_size, 7, "and the caster's hand is free")


func test_black_vise_and_the_rack_choose_as_they_enter_too() -> void:
	var vise := give_hand(0, "Black Vise")
	var rack := give_hand(0, "The Rack")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.C, 2)
	assert_ok(g.cast_spell(0, vise, []))
	_resolve_until_it_arrives(vise)
	assert_eq(int(vise.memory.get("victim", -1)), 1)
	assert_true(g.stack.is_empty(), "no arrival trigger of its own")
	assert_ok(g.cast_spell(0, rack, []))
	_resolve_until_it_arrives(rack)
	assert_eq(int(rack.memory.get("victim", -1)), 1)
	assert_true(g.stack.is_empty(), "no arrival trigger of its own")


func test_the_as_it_enters_clauses_are_replacements_not_triggers() -> void:
	for name in ["Lich", "Jihad", "Black Vise", "The Rack", "Cursed Rack",
			"Phantasmal Terrain"]:
		var data := CardRegistry.get_card(name)
		assert_true(data.as_enters.is_valid(),
			"%s reads its 'as this enters' clause off CardData.as_enters" % name)
		for trig in data.triggered_abilities:
			assert_ne(trig.event_type, Mtg.EventType.ENTERS_BATTLEFIELD,
				"%s puts nothing of its own on the stack as it arrives" % name)


func test_psychic_allergy_keeps_its_trigger_and_that_is_the_ruling() -> void:
	# The one of the six left on an arrival trigger, checked rather than
	# assumed: the colour it names has exactly two readers, both of them
	# UPKEEP_START triggers, and an upkeep cannot begin while a player
	# holds priority in the main phase the enchantment is cast in. Nothing
	# can read the window, so the window is not observable.
	var allergy := CardRegistry.get_card("Psychic Allergy")
	assert_false(allergy.as_enters.is_valid(),
		"deliberately still a trigger — see the card's own note")
	var readers := 0
	for trig in allergy.triggered_abilities:
		if trig.event_type == Mtg.EventType.UPKEEP_START:
			readers += 1
	assert_eq(readers, 2, "and both readers are upkeep triggers")
