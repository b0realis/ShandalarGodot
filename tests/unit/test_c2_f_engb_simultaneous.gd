extends GameTest
## Campaign 2026-10-12 (b3-4) — a mass removal moves its victims AT ONCE,
## so every victim is judged on the board as it was before any of them
## left (CR 603.10a look-back, 614 replacements of the victim's own,
## Volrath's Shapeshifter's layer-1 text).
##
## DestroyAllEffect, Apocalypse, Evacuation and the state-based death
## batch moved their victims one at a time and every departure
## recalculated the board, so the victims still waiting were re-read
## without the ones already gone: a Rukh Egg humbled by a Humility the
## same Disk destroyed still triggered, a humbled Firestorm Phoenix went
## back to hand, and a Volrath's Shapeshifter became the Rukh Egg that had
## just died beside it and triggered a second time.
## MtgGame.depart_together holds the recalculation until the whole batch
## has moved.

const PACKS := ["pack-8", "pack-9"]


func before_each() -> void:
	for p in PACKS: CardPacks.set_enabled(p, true)
	CardRegistry.ensure_loaded()
	super.before_each()


func after_each() -> void:
	g = null
	for p in PACKS: CardPacks.set_enabled(p, false)


func _start(preset: String) -> void:
	before_each()
	g.rules.set_preset(preset)
	advance_to_step(Mtg.Step.MAIN1)


func _to_graveyard(pid: int, card_name: String) -> CardInstance:
	var card := give_hand(pid, card_name)
	g.discard_cards(pid, [card])
	return card


func _triggers_from(card_name: String) -> int:
	var n := 0
	for item in g.stack + g._waiting_triggers:
		if item.kind == Mtg.StackKind.TRIGGER and item.card != null \
				and item.description.begins_with(card_name):
			n += 1
	return n


func _disk(pid := 0) -> CardInstance:
	var disk := put_battlefield(pid, "Nevinyrral's Disk")
	disk.tapped = false
	g.recalculate()
	return disk


func _fire_disk(disk: CardInstance) -> void:
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.activate_ability(0, disk, 0, []))
	assert_ok(g.pass_priority(0))
	assert_ok(g.pass_priority(1))   # the Disk resolves


# Nevinyrral's Disk destroys Humility and a humbled Rukh Egg at once: the
# Egg had no abilities as it died, so nothing triggers.
func test_disk_over_humility_and_rukh_egg_gives_no_egg_trigger() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		var humility := put_battlefield(0, "Humility")
		var egg := put_battlefield(0, "Rukh Egg")
		var disk := _disk()
		assert_true(egg.cur_abilities_silenced, "precondition: humbled")
		_fire_disk(disk)
		assert_eq(humility.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(egg.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(_triggers_from("Rukh Egg"), 0, "a humbled Egg has no dies trigger (%s)" % preset)
		resolve_stack()
		advance_to_step(Mtg.Step.END)
		resolve_stack()
		var birds := 0
		for inst in g.players[0].battlefield:
			if inst.is_token: birds += 1
		assert_eq(birds, 0, "and no bird arrives at the end step (%s)" % preset)


# Humility listed AFTER the Egg makes no difference either way round.
func test_the_order_of_the_victims_does_not_matter() -> void:
	_start("modern_mana_burn")
	var egg := put_battlefield(0, "Rukh Egg")
	put_battlefield(0, "Humility")
	var disk := _disk()
	assert_true(egg.cur_abilities_silenced)
	_fire_disk(disk)
	assert_eq(_triggers_from("Rukh Egg"), 0)


# The same sweep: a humbled Firestorm Phoenix has no "return it to its
# owner's hand instead", so it dies.
func test_disk_over_humility_kills_a_humbled_phoenix() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		put_battlefield(0, "Humility")
		var phoenix := put_battlefield(0, "Firestorm Phoenix")
		var disk := _disk()
		_fire_disk(disk)
		resolve_stack()
		assert_eq(phoenix.zone, Mtg.Zone.GRAVEYARD, "no replacement: it had no abilities (%s)" % preset)


# Without Humility the Phoenix's own replacement still applies to a sweep.
func test_an_unhumbled_phoenix_still_returns_to_hand() -> void:
	_start("modern_mana_burn")
	var phoenix := put_battlefield(0, "Firestorm Phoenix")
	var disk := _disk()
	_fire_disk(disk)
	resolve_stack()
	assert_eq(phoenix.zone, Mtg.Zone.HAND)


# Wrath of God kills Rukh Egg and Volrath's Shapeshifter (top card: a
# Forest) at once: the Shapeshifter dies as itself, one Egg trigger.
func test_wrath_does_not_turn_the_shapeshifter_into_the_dead_egg() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		_to_graveyard(0, "Forest")
		put_battlefield(0, "Rukh Egg")
		var shifter := put_battlefield(0, "Volrath's Shapeshifter")
		g.recalculate()
		assert_eq(shifter.data.card_name, "Volrath's Shapeshifter")
		var wrath := give_hand(0, "Wrath of God")
		add_mana(0, Mtg.ManaColor.W, 4)
		assert_ok(g.cast_spell(0, wrath, []))
		assert_ok(g.pass_priority(0))
		assert_ok(g.pass_priority(1))
		assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(_triggers_from("Rukh Egg"), 1, "only the real Egg's trigger (%s)" % preset)


# The state-based death batch is one event too: an Egg and a Shapeshifter
# with lethal damage die together, and the Shapeshifter dies as itself.
func test_the_lethal_damage_batch_reads_the_board_before_it() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		_to_graveyard(0, "Forest")
		var egg := put_battlefield(0, "Rukh Egg")
		var shifter := put_battlefield(0, "Volrath's Shapeshifter")
		g.recalculate()
		egg.damage = egg.cur_toughness
		shifter.damage = shifter.cur_toughness
		g.check_state_based_actions()
		assert_eq(egg.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(shifter.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(_triggers_from("Rukh Egg"), 1, "one Egg died (%s)" % preset)


# The batch still settles: a victim that regenerates inside it survives,
# and once the batch has moved it reads the board without the dead
# (Humility gone: a 3/3 Hill Giant again).
func test_a_survivor_reads_the_settled_board_after_the_batch() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		var humility := put_battlefield(0, "Humility")
		var giant := put_battlefield(1, "Hill Giant")
		var disk := _disk()
		assert_eq(giant.cur_power, 1, "humbled")
		add_mana(0, Mtg.ManaColor.C)
		assert_ok(g.activate_ability(0, disk, 0, []))
		var ward := give_hand(1, "Death Ward")
		assert_ok(g.pass_priority(0))
		add_mana(1, Mtg.ManaColor.W)
		assert_ok(g.cast_spell(1, ward, [TargetRef.card(giant)]))
		resolve_stack()
		assert_eq(humility.zone, Mtg.Zone.GRAVEYARD)
		assert_eq(giant.zone, Mtg.Zone.BATTLEFIELD, "regenerated (%s)" % preset)
		assert_true(giant.tapped)
		assert_eq(giant.cur_power, 3, "Humility is gone from the settled board (%s)" % preset)
		assert_eq(giant.cur_toughness, 3)


# Apocalypse exiles Humility and a humbled Floodgate at once: Floodgate had
# no "leaves the battlefield" ability as it left.
func test_apocalypse_over_humility_gives_no_floodgate_trigger() -> void:
	for preset in ["modern_mana_burn", "fifth"]:
		_start(preset)
		put_battlefield(0, "Humility")
		var gate := put_battlefield(0, "Floodgate")
		assert_true(gate.cur_abilities_silenced)
		var apocalypse := give_hand(0, "Apocalypse")
		add_mana(0, Mtg.ManaColor.R, 5)
		assert_ok(g.cast_spell(0, apocalypse, []))
		assert_ok(g.pass_priority(0))
		assert_ok(g.pass_priority(1))
		assert_eq(gate.zone, Mtg.Zone.EXILE)
		assert_eq(_triggers_from("Floodgate"), 0, "a humbled Floodgate has no leave trigger (%s)" % preset)


# Evacuation still returns every creature, through the same batch.
func test_evacuation_returns_every_creature_together() -> void:
	_start("modern_mana_burn")
	var bears := put_battlefield(0, "Grizzly Bears")
	var giant := put_battlefield(1, "Hill Giant")
	var evac := give_hand(0, "Evacuation")
	add_mana(0, Mtg.ManaColor.U, 5)
	assert_ok(g.cast_spell(0, evac, []))
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.HAND)
	assert_eq(giant.zone, Mtg.Zone.HAND)
	assert_eq(g._depart_hold, 0, "the hold is released")


# A search over a sweep unmakes cleanly and leaves no hold behind.
func test_a_search_over_a_sweep_leaves_no_hold() -> void:
	_start("modern_mana_burn")
	put_battlefield(0, "Humility")
	var egg := put_battlefield(0, "Rukh Egg")
	var disk := _disk()
	add_mana(0, Mtg.ManaColor.C)
	var m := g.make_mark()
	assert_ok(g.activate_ability(0, disk, 0, []))
	resolve_stack()
	assert_eq(egg.zone, Mtg.Zone.GRAVEYARD)
	g.unmake_to(m)
	g.end_search()
	assert_eq(egg.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(egg.cur_abilities_silenced)
	assert_eq(g._depart_hold, 0)
