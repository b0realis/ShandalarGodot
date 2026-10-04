extends GameTest
## Pin the campaign instrument: privacy, target identity and legal division.
const Pilot = preload("res://tests/support/sg_network_pilot.gd")


func _referee() -> SgPracticeMatch:
	var referee := SgPracticeMatch.new(42)
	referee.game = g
	g.interactive_choices = true
	g.rules.free_damage_assignment = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	referee.view(0)
	return referee


func test_pilot_only_reads_its_received_view_and_does_not_mutate_it() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Grizzly Bears")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	give_hand(1, "Black Lotus")
	var referee := _referee()
	var view := referee.view(0)
	var unchanged := view.duplicate(true)
	var first: Dictionary = Pilot.new().choose(view, 0)
	assert_eq(view, unchanged)
	assert_false(JSON.stringify(view).contains("Black Lotus"))
	assert_false(view.has("seed"))
	assert_false(view.players[1].has("hand"))
	assert_false(view.players[1].has("library"))
	give_hand(1, "Ancestral Recall")
	assert_eq(Pilot.new().choose(referee.view(0), 0), first,
		"no decision depends on unseen opposing card identities")


func test_pilot_forms_legal_gang_blocks_and_divides_damage() -> void:
	var referee := _referee()
	var attacker := put_battlefield(0, "Craw Wurm")
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	for i in 8:
		if g.awaiting_blockers: break
		assert_ok(g.pass_priority(g.priority_player))
	var blocks: Dictionary = Pilot.new().choose(referee.view(1), 1)
	assert_eq(blocks.op, "block")
	assert_eq(blocks.pairs.size(), 2)
	assert_ok(referee.act(1, blocks))
	for i in 8:
		if g.awaiting_damage_assignment: break
		assert_ok(g.pass_priority(g.priority_player))
	assert_true(g.awaiting_damage_assignment)
	var damage: Dictionary = Pilot.new().choose(referee.view(0), 0)
	assert_eq(damage.op, "damage")
	assert_eq(damage.points.size(), 2)
	assert_ok(referee.act(0, damage))
	assert_eq(first.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(second.zone, Mtg.Zone.GRAVEYARD)


func test_pilot_assigns_lethal_before_trampling_and_spends_every_point() -> void:
	var pilot := Pilot.new()
	assert_eq(pilot._damage({"amount": 7, "targets": [
		{"id": "c1", "lethal": 2}, {"id": "c2", "lethal": 3}, {"id": "player", "lethal": 0}]}),
		{"op": "damage", "points": [["c1", 2], ["c2", 3], ["player", 2]]})
	assert_eq(pilot._damage({"amount": 1, "targets": [
		{"id": "c1", "lethal": 2}, {"id": "player", "lethal": 0}]}),
		{"op": "damage", "points": [["c1", 1]]})


func test_no_target_cancels_before_tapping_mana() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var terror := give_hand(0, "Terror")
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var referee := _referee()
	var pilot := Pilot.new()
	# THE INTENT IS UNCHANGED — no mana is tapped for a cast with nothing
	# to aim at. Since 2026-10-04 the referee says so before the pilot
	# reaches for it: an aimless Terror is not `castable`, so the pilot
	# never prepares it (it used to prepare and then cancel), and a forced
	# `prepare` is refused before any land is tapped
	# (SgDuelActions.spell_refusal).
	var view := referee.view(0)
	for row in view.presentation.cards:
		if row.id == referee._handle(0, terror): assert_false(row.castable, "no creature to destroy")
	assert_eq(pilot.choose(view, 0), {"op": "pass"}, "nothing offered, nothing prepared")
	assert_refused(referee.act(0, {"op": "prepare", "card": referee._handle(0, terror), "kind": "spell",
		"index": 0, "x": 0, "mode": 0}), "nothing to aim Terror at")
	assert_true(referee.actions.draft.is_empty())
	assert_eq(g.players[0].mana_pool.total(), 0)
	for land in g.players[0].battlefield: assert_false(land.tapped)
	assert_eq(terror.zone, Mtg.Zone.HAND)


func test_network_pilot_waits_for_mana_tap_triggers_and_reuses_floating_mana() -> void:
	# Eight-player campaign, draw seed 4250, semifinal game seed 4255:
	# "Giant Spider can only be cast in your main phase with an empty stack".
	# The local Wizard already waits here; the DTO-only test pilot did not.
	advance_to_step(Mtg.Step.MAIN1)
	var spider := give_hand(0, "Giant Spider")
	for i in 6: put_battlefield(0, "Forest")
	put_battlefield(1, "Manabarbs")
	var referee := _referee()
	var pilot := Pilot.new()
	assert_ok(referee.act(0, pilot.choose(referee.view(0), 0)))
	assert_ok(referee.act(0, pilot.choose(referee.view(0), 0)))
	assert_eq(g.stack.size(), 4)
	var decision: Dictionary = pilot.choose(referee.view(0), 0)
	assert_eq(decision.op, "cancel", "wait for the tap triggers before attempting a sorcery-speed cast")
	if decision.op != "cancel": return
	assert_ok(referee.act(0, decision))
	var turn := g.turn_number
	for i in 40:
		if spider.zone == Mtg.Zone.BATTLEFIELD: break
		var seat: int = referee.decision_state().actor
		var action: Dictionary = pilot.choose(referee.view(0), 0) if seat == 0 else {"op": "pass"}
		assert_ok(referee.act(seat, action))
	assert_eq(spider.zone, Mtg.Zone.BATTLEFIELD, "a temporary delay must not blacklist the spell for the whole phase")
	assert_eq(g.turn_number, turn)
	assert_eq(g.players[0].life, 16, "exactly four taps, with no duplicate payment")
	assert_eq(g.players[0].battlefield.filter(func(card: CardInstance) -> bool: return card.is_land() and not card.tapped).size(), 2)


func test_network_pilot_can_still_submit_an_instant_over_mana_tap_triggers() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	give_hand(0, "Lightning Bolt")
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Manabarbs")
	var referee := _referee()
	var pilot := Pilot.new()
	assert_ok(referee.act(0, pilot.choose(referee.view(0), 0)))
	assert_ok(referee.act(0, pilot.choose(referee.view(0), 0)))
	assert_eq(g.stack.size(), 1)
	var decision: Dictionary = pilot.choose(referee.view(0), 0)
	assert_eq(decision.op, "submit", "instant timing is still legal over the trigger")
	assert_ok(referee.act(0, decision))
	assert_eq(g.stack.size(), 2)


func test_public_oracle_normalizes_handles_but_detects_target_changes() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	# Give seat zero an extra private capability before shared ones are issued.
	give_hand(0, "Black Lotus")
	var referee := _referee()
	var first := put_battlefield(1, "Grizzly Bears")
	var second := put_battlefield(1, "Grizzly Bears")
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.card(first)]))
	var a := referee.view(0)
	var b := referee.view(1)
	assert_ne(a.players[1].battlefield[0].id, b.players[1].battlefield[0].id)
	assert_eq(Pilot.public_table(a), Pilot.public_table(b))
	b.presentation.chain[0].refs[0].id = referee._handle(1, second)
	assert_ne(Pilot.public_table(a), Pilot.public_table(b),
		"same card name, different target is still a divergence")
	b = referee.view(1)
	b.players[1].life -= 1
	assert_ne(Pilot.public_table(a), Pilot.public_table(b))
