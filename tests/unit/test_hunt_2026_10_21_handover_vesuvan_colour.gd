extends GameTest
## THE SECOND BUG HUNT (2026-10-21), the handover: Vesuvan Doppelganger's
## "except it doesn't copy that creature's color".
##
## WAS: `MtgGame.become_copy` kept the Doppelganger's colour by writing its
## CURRENT colour as an indefinite colour change (layer 5) — so a colour
## something else had PAINTED on it was kept for good: copying a shape under
## Celestial Dawn left it white after the Dawn was gone. And because the
## exception lived outside the copied values, a Clone of the Doppelganger's
## shape took the shape's own colour (a red Clone of a blue Shivan Dragon)
## where CR 707.9b makes the exception part of what is copied.
## NOW the Doppelganger adopts the copied values with its OWN copiable
## colour written into them (CR 707.9b): no layer-5 change is invented, and
## a copy of the copy is blue too.


func before_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, true)
	CardRegistry.ensure_loaded()


func after_all() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func test_vesuvan_keeps_its_own_colour_not_a_painted_one() -> void:
	var dawn := put_battlefield(0, "Celestial Dawn")
	var bear := put_battlefield(1, "Grizzly Bears")
	var v := put_battlefield(0, "Vesuvan Doppelganger")
	g.recalculate()
	assert_eq(v.cur_colors, Mtg.ManaColor.W, "control: white under the Dawn")
	g.become_copy(v, g.copiable_data(bear), 0, true)
	g.recalculate()
	assert_eq(v.cur_colors, Mtg.ManaColor.W, "still white while the Dawn stands")
	g.destroy(dawn)
	g.recalculate()
	assert_eq(dawn.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(v.cur_colors, Mtg.ManaColor.U,
		"the Dawn is gone: the copy is the Doppelganger's own blue again")


func test_clone_of_a_vesuvan_copy_takes_its_colour_exception() -> void:
	var dragon := put_battlefield(1, "Shivan Dragon")
	var v := put_battlefield(0, "Grizzly Bears")
	g.add_counters(v, "+1/+1", 2)   # a copied 0/0 must survive the check
	g.become_copy(v, CardRegistry.get_card("Vesuvan Doppelganger"))
	g.recalculate()
	assert_eq(v.cur_colors, Mtg.ManaColor.U, "control: a blue Doppelganger")
	g.become_copy(v, g.copiable_data(dragon), 0, true)
	g.recalculate()
	assert_eq(v.data.card_name, "Shivan Dragon")
	assert_eq(v.cur_colors, Mtg.ManaColor.U, "a blue Shivan Dragon")
	var clone := put_battlefield(0, "Grizzly Bears")
	g.become_copy(clone, g.copiable_data(v))
	g.recalculate()
	assert_eq(clone.cur_colors, Mtg.ManaColor.U,
		"CR 707.9b: the copy of the copy has its colour exception")


func test_a_lace_on_the_doppelganger_outlives_its_next_shape() -> void:
	# Control: a colour PAINTED by an effect (layer 5) still applies over
	# the copy's values, as it did over the printed ones.
	var bear := put_battlefield(1, "Grizzly Bears")
	var v := put_battlefield(0, "Vesuvan Doppelganger")
	g.set_color(v, Mtg.ManaColor.R)
	g.become_copy(v, g.copiable_data(bear), 0, true)
	g.recalculate()
	assert_eq(v.cur_colors, Mtg.ManaColor.R, "the painted red stays")


func test_the_doppelganger_returns_to_its_printed_self() -> void:
	# Control: what it adopted is a copy of the shape, so nothing of the
	# shape's own definition was changed, and leaving undoes the copy.
	var bear := put_battlefield(1, "Grizzly Bears")
	var v := put_battlefield(0, "Vesuvan Doppelganger")
	g.become_copy(v, g.copiable_data(bear), 0, true)
	g.recalculate()
	assert_eq(bear.cur_colors, Mtg.ManaColor.G, "the Bears are still green")
	assert_eq(CardRegistry.get_card("Grizzly Bears").color_mask(), Mtg.ManaColor.G)
	g.return_to_hand(v)
	assert_eq(v.data.card_name, "Vesuvan Doppelganger")
