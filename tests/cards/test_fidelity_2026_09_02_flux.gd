extends GameTest
## Fidelity lift of 2026-09-02: Energy Flux GRANTS each artifact its own
## upkeep tax (CardInstance.cur_triggered_abilities, read by
## MtgGame.dispatch_event) instead of walking the board from one trigger
## on the Flux.


class Skinflint extends DecisionAgent:
	func answer_yes_no(_game: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool:
		return false


func _to_their_upkeep() -> void:
	var guard := 0
	while (g.turn_number < 2 or g.current_step() != Mtg.Step.UPKEEP) and guard < 200:
		_advance_once()
		guard += 1
	assert_eq(g.active_player, 1, "their upkeep")


func test_each_artifact_carries_its_own_tax_trigger() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var rod := put_battlefield(1, "Rod of Ruin")
	var ours := put_battlefield(0, "Sol Ring")
	put_battlefield(0, "Energy Flux")
	g.recalculate()
	assert_eq(ring.cur_triggered_abilities.size(), 1, "the granted ability rides on the artifact")
	assert_eq(ours.cur_triggered_abilities.size(), 1, "on every artifact, ours included")
	_to_their_upkeep()
	assert_eq(g.stack.size(), 2, "one trigger PER ARTIFACT, not one on the Flux")
	var carriers: Array = []
	for item in g.stack:
		carriers.append(item.card)
		assert_eq(item.controller, 1, "controlled by the artifact's controller")
	assert_true(carriers.has(ring))
	assert_true(carriers.has(rod))
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(rod.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(ours.zone, Mtg.Zone.BATTLEFIELD, "not OUR upkeep")


func test_an_artifact_that_arrives_after_upkeep_began_is_spared_this_turn() -> void:
	# CR 603.2: the granted ability triggers at the beginning of the upkeep;
	# an artifact that was not there then has nothing to trigger.
	put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Energy Flux")
	_to_their_upkeep()
	assert_eq(g.stack.size(), 1)
	var late := put_battlefield(1, "Rod of Ruin")
	resolve_stack()
	assert_eq(late.zone, Mtg.Zone.BATTLEFIELD, "it arrived after the taxes were due")


func test_the_taxes_resolve_one_at_a_time_with_priority_in_between() -> void:
	put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Rod of Ruin")
	put_battlefield(0, "Energy Flux")
	_to_their_upkeep()
	assert_eq(g.stack.size(), 2)
	assert_ok(g.pass_priority(1))
	assert_ok(g.pass_priority(0))
	assert_eq(g.stack.size(), 1, "one resolved, the other still waits for a response")
	assert_eq(g.priority_player, 1)


func test_the_artifacts_controller_decides_and_pays() -> void:
	g.set_agent(1, Skinflint.new())
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(1, "Forest")
	put_battlefield(1, "Forest")
	put_battlefield(0, "Energy Flux")
	_to_their_upkeep()
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.GRAVEYARD, "they could pay, and declined")


func test_a_silenced_artifact_has_no_tax() -> void:
	# Titania's Song takes every ability off a noncreature artifact — the
	# granted tax included.
	var ring := put_battlefield(1, "Sol Ring")
	put_battlefield(0, "Titania's Song")
	put_battlefield(0, "Energy Flux")
	g.recalculate()
	assert_true(ring.cur_abilities_silenced)
	_to_their_upkeep()
	assert_true(g.stack.is_empty(), "no ability, no tax")
	resolve_stack()
	assert_eq(ring.zone, Mtg.Zone.BATTLEFIELD)


func test_the_flux_leaving_takes_the_taxes_with_it() -> void:
	var ring := put_battlefield(1, "Sol Ring")
	var flux := put_battlefield(0, "Energy Flux")
	g.recalculate()
	assert_eq(ring.cur_triggered_abilities.size(), 1)
	g.destroy(flux, false)
	assert_eq(ring.cur_triggered_abilities.size(), 0)
	_to_their_upkeep()
	assert_true(g.stack.is_empty())
