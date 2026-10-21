extends GameTest
## THE ISLANDWALK GIVEN AWAY (bug hunt 2026-10-21, ai).
##
## Part Water — "X target creatures gain islandwalk until end of turn" — is
## a [GrantLandwalkEffect], which [method EffectIntent.read] has no arm for:
## an unknown effect reads removal-shaped, so [method AiPlayer._is_harmful]
## sent it across the table. With five Islands, a Hill Giant and Part Water,
## the Wizard gave THEIR two Grizzly Bears islandwalk — unblockable by us,
## the Islands' controller, for the turn. A landwalk is a gift to its
## holder now, and the spell waits while they control no land of the type
## (it walks past nothing); with their Island on the table it is aimed at
## our own Giant (the control).


func after_each() -> void:
	g = null


## Our five Islands, Hill Giant and Part Water; their two Grizzly Bears
## (and an Island of theirs when [param their_island]); our main phase,
## acted out. Returns [bears, giant, part water].
func _board(their_island: bool) -> Array:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	for n in 5: put_battlefield(0, "Island")
	var giant := put_battlefield(0, "Hill Giant")
	var bears: Array[CardInstance] = [put_battlefield(1, "Grizzly Bears"), put_battlefield(1, "Grizzly Bears")]
	if their_island:
		put_battlefield(1, "Island")
	var pw := give_hand(0, "Part Water")
	advance_to_step(Mtg.Step.MAIN1)
	for i in 4:
		var did := ai.act(g)
		resolve_stack()
		if did == "pass" or did == "": break
	return [bears, giant, pw]


func test_their_creatures_get_no_islandwalk() -> void:
	var out := _board(true)
	for bear in out[0]:
		assert_true((bear as CardInstance).cur_landwalk.is_empty(), "their Bears walk past OUR Islands")


func test_nothing_to_walk_past_holds_the_spell() -> void:
	var out := _board(false)
	assert_eq((out[2] as CardInstance).zone, Mtg.Zone.HAND, "they control no Island")
	for bear in out[0]:
		assert_true((bear as CardInstance).cur_landwalk.is_empty())


## THE CONTROL: their Island on the table — if it is cast, it is our Giant
## that walks.
func test_with_their_island_it_is_ours_that_walk() -> void:
	var out := _board(true)
	if (out[2] as CardInstance).zone != Mtg.Zone.HAND:
		assert_true((out[1] as CardInstance).cur_landwalk.has("island"), "our Giant walks past their Island")
	assert_false(AiPlayer.new(0, AiProfile.wizard())._is_harmful(out[2],
		(out[2] as CardInstance).data.spell_effects[0]), "a landwalk is help")
