extends GameTest
## The IMMEDIATE leaves-the-battlefield hook (CardData.as_it_leaves,
## MtgGame._run_leave_hook) and the FLOATING STATICS it exists to create
## (ContinuousEffects.add_floating_static).
##
## WHY A TRIGGER IS NOT ENOUGH. A leave-trigger goes on the stack and
## resolves later; by then MtgGame has already called recalculate() and the
## departing permanent's statics have been un-applied. Anything that has to
## be captured while the board still shows the effect — "if this
## enchantment leaves the battlefield, this effect continues until end of
## turn" — has no moment to run in. The hook is that moment: it runs at the
## instant the permanent leaves, from every one of the battlefield's four
## exits, after the leave-triggers are on the stack and after the object's
## own floating effects are dropped (CR 400.7), and before the world is
## recomputed.
##
## Pinned on SYNTHETIC permanents so nothing here depends on how any card
## is written; Titania's Song, the pool's one user, is pinned in
## tests/cards/test_fidelity_2026_09_02.gd.


## A permanent whose leave hook appends to [param diary].
func _diarist(diary: Array) -> CardData:
	return CardData.new("Test Diarist", "", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.as_it_leaves(func(_game: MtgGame, inst: CardInstance, controller: int,
				parting: Dictionary) -> void:
			diary.append({"zone": inst.zone, "controller": controller,
				"memory": parting}))


# --------------------------------------------- it fires from every exit --

func test_the_hook_fires_when_the_permanent_dies() -> void:
	var diary: Array = []
	var it := put_synthetic(0, _diarist(diary))
	g.destroy(it)
	assert_eq(diary.size(), 1)
	assert_eq(int(diary[0]["controller"]), 0, "who controlled it as it left")


func test_the_hook_fires_when_the_permanent_is_exiled() -> void:
	var diary: Array = []
	g.exile_permanent(put_synthetic(0, _diarist(diary)))
	assert_eq(diary.size(), 1)


func test_the_hook_fires_when_the_permanent_is_bounced() -> void:
	var diary: Array = []
	g.return_to_hand(put_synthetic(1, _diarist(diary)))
	assert_eq(diary.size(), 1)
	assert_eq(int(diary[0]["controller"]), 1)


func test_the_hook_fires_when_the_permanent_is_anted() -> void:
	# The fourth exit.
	var diary: Array = []
	var it := put_synthetic(0, _diarist(diary))
	g.move_to_ante(it)
	assert_eq(diary.size(), 1)
	assert_eq(it.zone, Mtg.Zone.ANTE)


func test_the_hook_does_not_fire_while_the_permanent_stays() -> void:
	var diary: Array = []
	put_synthetic(0, _diarist(diary))
	advance_to_next_turn()
	assert_eq(diary.size(), 0)


# ------------------------------------------------------ floating statics --

## An enchantment that pumps every Bear by +1/+1, and whose leave hook
## keeps that static running until end of turn — Titania's Song's shape,
## with a cheaper effect.
func _bear_anthem() -> CardData:
	var data := CardData.new("Test Bear Anthem", "{2}", Mtg.CardType.ENCHANTMENT)
	var anthem := StaticAbility.new(_pump_bears, "Bears get +1/+1.")
	data.static_ability(anthem)
	data.as_it_leaves(func(game: MtgGame, inst: CardInstance, _c: int,
			_parting: Dictionary) -> void:
		game.continuous.add_floating_static(inst, anthem))
	return data


static func _pump_bears(game: MtgGame, _source: CardInstance) -> void:
	for inst in game.all_battlefield():
		if inst.has_subtype("bear"):
			inst.cur_power += 1
			inst.cur_toughness += 1


func test_a_floating_static_outlives_its_source() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var anthem := put_synthetic(0, _bear_anthem())
	g.recalculate()
	assert_eq(bear.cur_power, 3, "2/2 plus the anthem")
	g.destroy(anthem)
	g.check_state_based_actions()
	assert_eq(bear.cur_power, 3, "the effect continues without its source")


func test_a_floating_static_is_not_locked_in() -> void:
	# CR 611.3a: a continuous effect from a static ability applies at any
	# given moment to whatever its text indicates. The rider lifts the
	# source's PRESENCE (CR 611.3b) and nothing else, so a Bear that turns
	# up after the anthem has gone is pumped too.
	var anthem := put_synthetic(0, _bear_anthem())
	g.destroy(anthem)
	g.check_state_based_actions()
	var latecomer := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	assert_eq(latecomer.cur_power, 3)


func test_a_floating_static_expires_at_end_of_turn() -> void:
	var bear := put_battlefield(0, "Grizzly Bears")
	var anthem := put_synthetic(0, _bear_anthem())
	g.destroy(anthem)
	g.check_state_based_actions()
	assert_eq(bear.cur_power, 3)
	advance_to_next_turn()
	assert_eq(bear.cur_power, 2, "END_OF_TURN is the default duration")


func test_a_floating_static_is_not_forgotten_with_its_source() -> void:
	# ContinuousEffects.forget_instance drops every floating entry keyed to
	# a departing object (CR 400.7). A floating static must survive that —
	# its source is exactly the object that just left — which is why its
	# entry carries instance_id -1.
	var bear := put_battlefield(0, "Grizzly Bears")
	var anthem := put_synthetic(0, _bear_anthem())
	g.destroy(anthem)
	g.check_state_based_actions()
	g.continuous.forget_instance(anthem.id)
	g.recalculate()
	assert_eq(bear.cur_power, 3)
