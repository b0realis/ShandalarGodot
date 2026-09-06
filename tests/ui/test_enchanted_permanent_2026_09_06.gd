extends GutTest
## THE AURA THAT WAS NEVER DRAWN — the playtest defect of 2026-09-06,
## reported the same afternoon as the enchanted attacker
## (`tests/ui/test_enchanted_attacker_2026_09_06.gd`).
##
## *"Opponent casts **Psychic Venom** on MY land — it went directly to the
## graveyard. The card should be present as an aura behind my land on my
## playfield, and should take effect immediately when I tap my land. If
## that enchantment gets destroyed it goes to the OPPONENT's graveyard."*
##
## THE ENGINE WAS INNOCENT, AND THAT MATTERS. All three of the report's
## claims already held: the Aura resolves, enters ATTACHED (CR 303.4a),
## stays on the battlefield under its caster's control; its trigger stings
## the LAND's controller and not the aura's; and destroyed it goes to its
## OWNER's graveyard (CR 400.3). The pins for all three are below, because
## a report is not answered until the thing it claims is pinned.
##
## WHAT THE PLAYER ACTUALLY SAW WAS AN EMPTY BOARD. An attachment is drawn
## as a whole card peeking out from behind its host
## ([constant DuelScreen.AURA_PEEK]), and `DuelScreen._rebuild_field`
## skips every attached card because the HOST's widget draws it. That is
## true only of a host built by `DuelScreen._make_widget` — and lands (and
## every other non-creature permanent) group into the original's strip
## PILES the moment there are two of them, where `CardPile.populate`
## builds bare [MiniCard] rows with no fan at all. So the aura on a LONE
## land was drawn and the aura on one of TWO lands vanished, which is
## every land a real duel ever has. With no card anywhere on the table the
## only reading left was "it went to the graveyard".
##
## THE RULE THIS PINS: a permanent that is wearing something keeps a slot
## of its own and is never folded into a pile — in either row, in either
## half, whoever controls the aura. The report's three RULES claims are
## pinned next door, in `tests/cards/test_hostile_auras_2026_09_06.gd`.

var screen: DuelScreen


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func _mk(card_name: String, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name),
		g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	return inst


func _summon(card_name: String, pid: int) -> CardInstance:
	var inst := _mk(card_name, pid)
	screen.game._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	return inst


## An aura from [param pid]'s hand, put onto [param host] — which is quite
## deliberately allowed to belong to the other seat.
func _enchant(card_name: String, host: CardInstance, pid: int) -> CardInstance:
	var g: MtgGame = screen.game
	var aura := _mk(card_name, pid)
	aura.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(aura)
	g.attach_aura_from_anywhere(aura, host, pid)
	return aura


## Every [MiniCard] the screen currently has on it, by instance id.
func _drawn() -> Dictionary:
	var out := {}
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is MiniCard and (n as MiniCard).instance != null:
			out[(n as MiniCard).instance.id] = n
		for c in n.get_children():
			stack.append(c)
	return out


# ============================== THE BOARD THE REPORT DESCRIBES --

func test_the_venom_on_one_of_my_lands_is_on_the_table() -> void:
	# TWO lands, which is what makes a pile — and what made it vanish.
	var mine := _summon("Island", 0)
	_summon("Island", 0)
	var venom := _enchant("Psychic Venom", mine, 1)
	assert_eq(venom.zone, Mtg.Zone.BATTLEFIELD,
		"the engine kept it on the battlefield")
	screen._refresh()
	await get_tree().process_frame
	assert_true(_drawn().has(venom.id),
		"the aura the opponent put on my land is DRAWN on my playfield")


func test_a_whole_pile_of_lands_still_shows_the_one_that_is_enchanted() -> void:
	# PILE_SIZE lands and the enchanted one in the MIDDLE of them: the
	# pile must close up around it rather than swallow it.
	var lands: Array = []
	for _i in DuelScreen.PILE_SIZE + 2:
		lands.append(_summon("Island", 0))
	var venom := _enchant("Psychic Venom", lands[3], 1)
	screen._refresh()
	await get_tree().process_frame
	var drawn := _drawn()
	assert_true(drawn.has(venom.id), "the aura is drawn")
	for land in lands:
		assert_true(drawn.has(land.id),
			"...and every land is still on the table")


func test_an_enchanted_artifact_is_not_swallowed_either() -> void:
	# `Row.OTHER` piles by exactly the same rule, so the artifact cycle had
	# exactly the same hole.
	var vise := _summon("Black Vise", 0)
	_summon("Black Vise", 0)
	var curse := _enchant("Curse Artifact", vise, 1)
	screen._refresh()
	await get_tree().process_frame
	assert_true(_drawn().has(curse.id),
		"an aura on one of two artifacts is drawn too")


func test_the_opponents_own_enchanted_land_shows_in_their_half() -> void:
	var theirs := _summon("Island", 1)
	_summon("Island", 1)
	var venom := _enchant("Psychic Venom", theirs, 0)
	screen._refresh()
	await get_tree().process_frame
	assert_true(_drawn().has(venom.id),
		"the aura I put on THEIR land is drawn in their half")


## WHAT MUST NOT CHANGE: an unenchanted row still piles. Taking every land
## out of the pile would undo the original's strip-stack windows.
func test_plain_lands_still_pile() -> void:
	for _i in 3:
		_summon("Island", 0)
	screen._refresh()
	await get_tree().process_frame
	var piles := 0
	var stack: Array = [screen]
	while not stack.is_empty():
		var n: Node = stack.pop_back()
		if n is CardPile:
			piles += 1
		for c in n.get_children():
			stack.append(c)
	assert_gt(piles, 0, "three plain lands are still one pile")
