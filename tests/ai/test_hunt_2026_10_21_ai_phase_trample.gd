extends GameTest
## PHASING OUT OF A CHUMP BLOCK ON A TRAMPLER (bug hunt 2026-10-21, ai).
##
## The combat save ([method MirageTactics.save_from_combat]) phases a
## creature of ours that dies in the coming damage out of the combat: the
## attacker it blocked stays blocked and "deals nothing to us" — unless it
## has TRAMPLE, which then assigns all its damage to the player (CR
## 702.19e). At 8 life, chump-blocking a Crash of Rhinos (8/4 trample) with
## a Rainbow Efreet (7 through, 1 life left), the Wizard spent {U}{U} to
## phase the Efreet out — and took all eight.
##
## The spill ([method MirageTactics.trample_spill]) is now paid in life,
## and a save that leaves us dead is never made. A blocker of an attacker
## without trample is still saved (the control).

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


## Our Rainbow Efreet and two Islands at [param life]; their [param
## attacker] attacks, the Efreet blocks it, seat 0 holds priority in the
## declare blockers step. What the combat save does.
func _chump(attacker_name: String, life: int) -> String:
	var ai := AiPlayer.new(0, AiProfile.wizard())
	g.set_agent(0, ai)
	var efreet := put_battlefield(0, "Rainbow Efreet")
	for n in 2: put_battlefield(0, "Island")
	var attacker := put_battlefield(1, attacker_name)
	g.players[0].life = life
	var guard := 0
	while not (g.active_player == 1 and g.awaiting_attackers) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.declare_attackers(1, [attacker.id]))
	guard = 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(0, {efreet.id: attacker.id}))
	guard = 0
	while g.priority_player != 0 and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	return M.save_from_combat(g, ai)


func test_no_phasing_out_of_a_lethal_trample_spill() -> void:
	assert_eq(_chump("Crash of Rhinos", 8), "", "the eighth point would kill us")
	resolve_stack()
	advance_to_step(Mtg.Step.COMBAT_END)
	assert_false(g.game_over, "the chump absorbed one: we live at 1")
	assert_eq(g.players[0].life, 1)


func test_the_spill_is_one_point_more() -> void:
	_chump("Crash of Rhinos", 20)
	var efreet: CardInstance = g.players[0].battlefield.filter(
		func(c: CardInstance) -> bool: return c.data.card_name == "Rainbow Efreet")[0]
	assert_eq(M.trample_spill(g, efreet), 1, "8 power: 7 through blocked, 8 through unblocked")


## THE CONTROL: a Hill Giant without trample stays blocked and deals
## nothing — the Efreet is still phased out of the trade it loses.
func test_a_non_trampler_still_meets_no_one() -> void:
	assert_string_contains(_chump("Hill Giant", 8), "phases out Rainbow Efreet")
