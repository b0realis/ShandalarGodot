extends GameTest
## STORAGE MATRIX AND THE "WILL UNTAP" HINT (Pack 10 E9). While an untapped
## Storage Matrix is out, each player untaps only the kind they choose in
## their untap step (MtgGame.untap_kind_choices), so the small card cannot
## promise that a tapped permanent will untap — the same silence Winter
## Orb's cap brings (MiniCard.State.WILL_UNTAP) — and an SGManalink seat is
## told so in the same flag (`untap_capped`).


func before_each() -> void:
	CardPacks.set_enabled("pack-10", true)
	super.before_each()


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _will_untap(inst: CardInstance) -> bool:
	var card := MiniCard.new(inst)
	card.game = g
	add_child_autofree(card)
	return card.active_states().has(MiniCard.State.WILL_UNTAP)


func test_an_untapped_storage_matrix_silences_the_will_untap_mark() -> void:
	var lion := put_battlefield(0, "Savannah Lions")
	lion.tapped = true
	assert_true(_will_untap(lion), "control: nothing restricts the untap")
	var matrix := put_battlefield(1, "Storage Matrix")
	g.recalculate()
	assert_false(g.untap_kind_choices.is_empty(), "the Matrix restricts the untap step")
	assert_false(_will_untap(lion), "the kind is chosen in the untap step: no promise")
	matrix.tapped = true
	g.recalculate()
	assert_true(_will_untap(lion), "a tapped Matrix restricts nothing")


func test_an_sgmanalink_seat_is_told_the_untap_is_restricted() -> void:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	assert_false(bool(referee.view(0).presentation.untap_capped), "control")
	put_battlefield(1, "Storage Matrix")
	g.recalculate()
	for seat in 2:
		var view := referee.view(seat)
		assert_true(SgViewProtocol.game(view))
		assert_true(bool(view.presentation.untap_capped), "seat %d: won't all untap" % seat)
