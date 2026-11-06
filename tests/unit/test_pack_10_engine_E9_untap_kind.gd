extends GameTest
## Pack 10 engine package E9 (part 1) — "EACH PLAYER CHOOSES ARTIFACT,
## CREATURE, OR LAND DURING THEIR UNTAP STEP. THAT PLAYER CAN UNTAP ONLY
## PERMANENTS OF THE CHOSEN TYPE THIS STEP." (Storage Matrix, CR 502.3).
##
## A static registers its source each recalculation while the condition
## holds ([method MtgGame.restrict_untap_to_chosen_kind] — the Matrix's own
## "as long as this artifact is untapped" is the card's test) into the
## derived [member MtgGame.untap_kind_choices]. [method MtgGame._untap_step]
## then asks the ACTIVE player one OPTION per registered source —
## "Artifact" / "Creature" / "Land", a turn-based question held for a human
## seat on the existing "untap" pending action — BEFORE it works out what
## untaps: a tapped permanent untaps only if it is of every chosen kind (an
## artifact land counts for either), and the "may choose not to untap"
## question and the untap caps (Winter Orb, Static Orb) apply to what is
## left. Nothing tapped that could untap: nothing is asked.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


static func _matrix() -> CardData:
	return CardData.new("Test Matrix", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_restrict,
			"As long as this artifact is untapped, each player chooses artifact, creature, or land during their untap step. That player can untap only permanents of the chosen type this step.")) \
		.oracle("As long as this artifact is untapped, each player chooses artifact, creature, or land during their untap step. That player can untap only permanents of the chosen type this step.")


static func _restrict(g: MtgGame, s: CardInstance) -> void:
	if not s.tapped:
		g.restrict_untap_to_chosen_kind(s)


static func _artifact_land() -> CardData:
	return CardData.new("Test Artifact Land", "", Mtg.CardType.LAND | Mtg.CardType.ARTIFACT) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 1)).oracle("{T}: Add {C}.")


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _tapped(pid: int, card_name: String) -> CardInstance:
	var inst := put_battlefield(pid, card_name)
	inst.tapped = true
	return inst


## Pass until a question holds the duel (or [param pid]'s next main phase).
func _until_held_or_main(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 800 \
			and not (g.turn_number > turn and g.active_player == pid and g.current_step() == Mtg.Step.MAIN1):
		_advance_once()
		guard += 1
	assert_lt(guard, 800)


func _to_own_next_main(pid: int) -> void:
	var turn := g.turn_number
	var guard := 0
	while not (g.turn_number > turn and g.active_player == pid and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	assert_lt(guard, 800)


# --------------------------------------------------------------------------

func test_the_registry_follows_the_static() -> void:
	var matrix := put_synthetic(1, _matrix())
	g.recalculate()
	assert_eq(g.untap_kind_choices, {matrix.id: "Test Matrix"})
	matrix.tapped = true
	g.recalculate()
	assert_true(g.untap_kind_choices.is_empty(), "a tapped Matrix registers nothing")
	matrix.tapped = false
	g.recalculate()
	g.destroy(matrix)
	g.recalculate()
	assert_true(g.untap_kind_choices.is_empty(), "rebuilt every recalculation")


func test_the_heuristic_picks_the_kind_it_has_most_tapped() -> void:
	put_synthetic(1, _matrix())
	var forest_a := _tapped(0, "Forest")
	var forest_b := _tapped(0, "Forest")
	var bears := _tapped(0, "Grizzly Bears")
	_to_own_next_main(0)
	assert_false(forest_a.tapped)
	assert_false(forest_b.tapped, "lands chosen: both Forests untap")
	assert_true(bears.tapped, "the creature stays tapped")


func test_a_human_is_held_and_untaps_only_the_chosen_kind() -> void:
	put_synthetic(1, _matrix())
	var forest := _tapped(0, "Forest")
	var bears := _tapped(0, "Grizzly Bears")
	var ring := _tapped(0, "Sol Ring")
	_human_seat(0)
	_until_held_or_main(0)
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "the untap step holds on the kind")
	assert_eq(g.active_player, 0)
	assert_eq(asked.pid, 0)
	assert_eq(asked.kind, PlayerChoice.Kind.OPTION)
	assert_eq(asked.source, "Test Matrix")
	assert_false(asked.is_cost, "a turn-based question, not a cost")
	assert_eq(asked.options, MtgGame.UNTAP_KIND_LABELS)
	assert_eq(asked.options, ["Artifact", "Creature", "Land"] as Array[String])
	assert_true(forest.tapped and bears.tapped and ring.tapped, "nothing untapped while it stands")
	assert_refused(g.cancel_choice(), "must be answered")
	assert_ok(g.answer_choice(1))
	assert_null(g.awaiting_choice)
	assert_false(bears.tapped, "creature chosen: the Bears untap")
	assert_true(forest.tapped, "the Forest does not")
	assert_true(ring.tapped, "nor the Sol Ring")
	assert_eq(g.unanswered_choices.size(), 0)


func test_a_tapped_matrix_restricts_nothing() -> void:
	var matrix := put_synthetic(0, _matrix())
	matrix.tapped = true
	var forest := _tapped(0, "Forest")
	var bears := _tapped(0, "Grizzly Bears")
	_human_seat(0)
	_until_held_or_main(0)
	assert_null(g.awaiting_choice, "no question")
	assert_false(forest.tapped)
	assert_false(bears.tapped)
	assert_false(matrix.tapped, "and the Matrix untaps with the rest")


func test_an_artifact_land_counts_as_an_artifact() -> void:
	put_synthetic(1, _matrix())
	var both := put_synthetic(0, _artifact_land())
	both.tapped = true
	var forest := _tapped(0, "Forest")
	var thopter := _tapped(0, "Ornithopter")
	_human_seat(0)
	_until_held_or_main(0)
	assert_ok(g.answer_choice(0))   # Artifact
	assert_false(both.tapped, "an artifact land is an artifact")
	assert_false(thopter.tapped, "an artifact creature is an artifact")
	assert_true(forest.tapped)


func test_an_artifact_land_counts_as_a_land() -> void:
	put_synthetic(1, _matrix())
	var both := put_synthetic(0, _artifact_land())
	both.tapped = true
	var forest := _tapped(0, "Forest")
	var thopter := _tapped(0, "Ornithopter")
	_human_seat(0)
	_until_held_or_main(0)
	assert_ok(g.answer_choice(2))   # Land
	assert_false(both.tapped, "an artifact land is a land")
	assert_false(forest.tapped)
	assert_true(thopter.tapped)


func test_winter_orbs_cap_applies_to_what_is_left() -> void:
	put_synthetic(1, _matrix())
	put_battlefield(1, "Winter Orb")
	var forests: Array[CardInstance] = [_tapped(0, "Forest"), _tapped(0, "Forest"), _tapped(0, "Forest")]
	var bears := _tapped(0, "Grizzly Bears")
	_to_own_next_main(0)
	var untapped := 0
	for forest in forests:
		if not forest.tapped: untapped += 1
	assert_eq(untapped, 1, "land chosen, and the Orb lets one untap")
	assert_true(bears.tapped)


func test_each_player_chooses_in_their_own_untap_step() -> void:
	put_synthetic(0, _matrix())
	var forest := _tapped(1, "Forest")
	var bears := _tapped(1, "Grizzly Bears")
	_human_seat(1)
	_until_held_or_main(1)
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "the Matrix's controller's opponent is asked in their own step")
	assert_eq(asked.pid, 1)
	assert_eq(g.active_player, 1)
	assert_ok(g.answer_choice(2))
	assert_false(forest.tapped)
	assert_true(bears.tapped)


func test_nothing_tapped_asks_nothing() -> void:
	put_synthetic(1, _matrix())
	put_battlefield(0, "Forest")
	_human_seat(0)
	_until_held_or_main(0)
	assert_null(g.awaiting_choice)
	assert_eq(g.active_player, 0)
	assert_eq(g.current_step(), Mtg.Step.MAIN1)


func test_two_matrices_ask_twice_and_both_bind() -> void:
	put_synthetic(1, _matrix())
	put_synthetic(1, _matrix())
	var forest := _tapped(0, "Forest")
	var bears := _tapped(0, "Grizzly Bears")
	_human_seat(0)
	_until_held_or_main(0)
	assert_ok(g.answer_choice(2))   # Land
	assert_not_null(g.awaiting_choice, "one choice per Matrix")
	assert_ok(g.answer_choice(1))   # Creature
	assert_null(g.awaiting_choice)
	assert_true(forest.tapped, "a Forest is no creature")
	assert_true(bears.tapped, "and the Bears are no land")


func test_a_may_skip_permanent_of_another_kind_is_not_asked() -> void:
	# "You may choose not to untap" is asked only of what may untap at all.
	put_synthetic(1, _matrix())
	var forest := _tapped(0, "Forest")
	var forest_b := _tapped(0, "Forest")
	var skipper := CardData.new("Test Skipper", "{2}", Mtg.CardType.ARTIFACT).oracle("You may choose not to untap this artifact during your untap step.")
	skipper.may_skip_untap = true
	var odd := put_synthetic(0, skipper)
	odd.tapped = true
	_human_seat(0)
	_until_held_or_main(0)
	assert_eq((g.awaiting_choice as PlayerChoice).source, "Test Matrix")
	assert_ok(g.answer_choice(2))   # Land
	assert_null(g.awaiting_choice, "the artifact's may-skip question never comes")
	assert_false(forest.tapped)
	assert_false(forest_b.tapped)
	assert_true(odd.tapped)
