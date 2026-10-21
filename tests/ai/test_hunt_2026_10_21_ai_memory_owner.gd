extends GameTest
## OUR OWN CARD IN THEIR DECK (bug hunt 2026-10-21, ai).
##
## [AiMatchMemory] tallies the cards the OPPONENT's deck has shown, for the
## sideboarder ([AiSideboard]). It took every arrival whose CONTROLLER was
## not this seat — so our own Serra Angel, raised by their Animate Dead,
## was counted as one of theirs, and a single flier "seen" lifted every
## flier answer in our sideboard off its dead-card penalty. A sighting is
## now read by the card's OWNER: their card is theirs wherever it is, ours
## is never theirs (the control: their own card raised by us is counted).


func after_each() -> void:
	g = null


## A card owned by [param owner] put onto the battlefield under
## [param controller] — an arrival that was never cast.
func _arrive(owner: int, controller: int, card_name: String) -> CardInstance:
	var inst := _make_instance(owner, card_name)
	g._put_on_battlefield(inst, controller)
	return inst


func test_our_card_under_their_control_is_not_theirs() -> void:
	var memory := AiMatchMemory.new(1)
	memory.watch(g)
	_arrive(1, 0, "Serra Angel")
	memory.end_duel()
	assert_eq(memory.copies_seen("Serra Angel"), 0, "the Angel is in OUR deck")


func test_their_card_under_our_control_is_theirs() -> void:
	var memory := AiMatchMemory.new(1)
	memory.watch(g)
	_arrive(0, 1, "Craw Wurm")
	_arrive(0, 0, "Hill Giant")
	memory.end_duel()
	assert_eq(memory.copies_seen("Craw Wurm"), 1, "raised by us, still a card of their deck")
	assert_eq(memory.copies_seen("Hill Giant"), 1, "the ordinary case")
