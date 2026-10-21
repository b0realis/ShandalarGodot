extends GameTest

class Decline extends DecisionAgent:
	func answer_yes_no(_g: MtgGame, _pid: int, _prompt: String, _hint: bool) -> bool: return false

func before_each() -> void:
	CardPacks.set_enabled("pack-4", true)
	super()
	# Played FOR ANTE: in a duel that is not, the ante cards do nothing and
	# nothing reaches the ante (the owner's ruling of 2026-10-21,
	# tests/unit/test_ruling_2026_10_21_ante_off.gd).
	g.ante_enabled = true
	advance_to_step(Mtg.Step.MAIN1)

func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-4", false)

func dead(name: String) -> CardInstance:
	var i := put_battlefield(1, name)
	g.destroy(i)
	return i

func unblocked(badger: CardInstance) -> void:
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [badger.id]))
	advance_to_step(Mtg.Step.DECLARE_BLOCKERS)
	assert_ok(g.declare_blockers(1, {}))

func test_badger_announces_two_distinct_graveyard_targets_and_life_replaces_damage() -> void:
	var badger := put_battlefield(0, "Rysorian Badger")
	var bear := dead("Grizzly Bears")
	var giant := dead("Hill Giant")
	g.players[0].life = 5
	unblocked(badger)
	assert_eq(g.stack.size(), 1)
	if g.stack.is_empty(): return
	assert_eq(g.stack.back().targets.size(), 2)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.EXILE)
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].life, 7)
	assert_true(badger.cur_assigns_no_combat_damage)
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_eq(g.players[1].life, 20)

func test_badger_partial_target_loss_and_new_graveyard_incarnation() -> void:
	var badger := put_battlefield(0, "Rysorian Badger")
	var bear := dead("Grizzly Bears")
	var giant := dead("Hill Giant")
	g.players[0].life = 5
	unblocked(badger)
	g.reanimate(bear, 1)
	g.destroy(bear)
	resolve_stack()
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(giant.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].life, 6)

func test_badger_human_can_choose_zero_targets_without_fizzle_or_hidden_choice() -> void:
	var badger := put_battlefield(0, "Rysorian Badger")
	dead("Grizzly Bears")
	g.set_agent(0, HumanAgent.new())
	g.interactive_choices = true
	unblocked(badger)
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null: return
	assert_eq(g.awaiting_choice.kind, PlayerChoice.Kind.OPTION)
	assert_ok(g.answer_choice(0))
	assert_eq(g.stack.back().targets.size(), 0)
	resolve_stack()
	assert_false(badger.cur_assigns_no_combat_damage)
	assert_true(g.unanswered_choices.is_empty())

func test_fiends_exchange_follows_ownership_not_control_and_moves_from_exile() -> void:
	var fiends := put_battlefield(0, "Timmerian Fiends")
	var artifact := put_battlefield(1, "Sol Ring")
	g.change_control(artifact, 0)
	g.set_agent(1, Decline.new())
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, fiends, 0, [TargetRef.card(artifact)]))
	g.exile_from_graveyard(fiends)
	resolve_stack()
	assert_eq(artifact.owner_id, 0)
	assert_true(g.players[0].graveyard.has(artifact))
	assert_eq(fiends.owner_id, 1)
	assert_true(g.players[1].graveyard.has(fiends))
	assert_false(g.players[1].exile.has(fiends))

func test_fiends_owner_may_ante_to_keep_artifact() -> void:
	var fiends := put_battlefield(0, "Timmerian Fiends")
	var artifact := put_battlefield(1, "Sol Ring")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(g.activate_ability(0, fiends, 0, [TargetRef.card(artifact)]))
	resolve_stack()
	assert_eq(artifact.owner_id, 1)
	assert_eq(artifact.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(fiends.owner_id, 0)
	assert_eq(g.players[1].ante.size(), 1)

func test_fiends_digital_token_limit_is_visible_and_enforced() -> void:
	var fiends := put_battlefield(0, "Timmerian Fiends")
	var token := g.create_token(1, CardData.new("Token artifact", "", Mtg.CardType.ARTIFACT))[0]
	assert_string_contains(fiends.data.oracle_text, "only nontoken")
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_refused(g.activate_ability(0, fiends, 0, [TargetRef.card(token)]))
	fiends.is_token = true
	var artifact := put_battlefield(1, "Sol Ring")
	assert_refused(g.activate_ability(0, fiends, 0, [TargetRef.card(artifact)]), "token copies")
