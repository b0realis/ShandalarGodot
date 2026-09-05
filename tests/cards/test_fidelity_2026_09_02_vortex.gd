extends GameTest
## Fidelity lift of 2026-09-02: Mana Vortex's "When you cast this spell,
## counter it unless you sacrifice a land" is a CAST TRIGGER (CR 603.2,
## 601.2h is not involved): the spell is cast, the trigger goes on the
## stack above it, both players may respond, and only its resolution
## asks for the land or counters the Vortex. A spell on the stack now
## hears its own SPELL_CAST event (MtgGame.cast_spell's also_listen).


class Miser extends DecisionAgent:
	## Declines every optional card choice.
	func answer_card(_game: MtgGame, _pid: int, _candidates: Array[CardInstance],
			_prompt: String) -> CardInstance:
		return null


func _cast_vortex() -> CardInstance:
	var vortex := give_hand(0, "Mana Vortex")
	advance_to_step(Mtg.Step.MAIN1)
	add_mana(0, Mtg.ManaColor.U, 2)
	add_mana(0, Mtg.ManaColor.C)
	assert_ok(g.cast_spell(0, vortex, []))
	return vortex


func test_casting_with_no_land_is_allowed_and_the_trigger_counters_it() -> void:
	var vortex := _cast_vortex()
	assert_eq(vortex.zone, Mtg.Zone.STACK, "it IS cast — it used to be refused outright")
	assert_eq(g.stack.size(), 2, "the spell and its cast trigger")
	assert_eq(g.stack[-1].kind, Mtg.StackKind.TRIGGER)
	assert_eq(g.stack[-1].card, vortex, "the trigger belongs to the spell")
	assert_eq(g.stack[-1].controller, 0)
	resolve_stack()
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD, "countered: no land to sacrifice")
	assert_null(g.find_on_battlefield(0, "Mana Vortex"))


func test_sacrificing_a_land_lets_the_vortex_resolve() -> void:
	var forest := put_battlefield(0, "Forest")
	put_battlefield(1, "Forest")   # so the board is not dry once ours is gone
	var vortex := _cast_vortex()
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.GRAVEYARD, "the land was sacrificed as the trigger resolved")
	assert_eq(vortex.zone, Mtg.Zone.BATTLEFIELD)


func test_declining_the_sacrifice_counters_the_vortex() -> void:
	g.set_agent(0, Miser.new())
	var forest := put_battlefield(0, "Forest")
	var vortex := _cast_vortex()
	resolve_stack()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "kept")
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD, "so the spell is countered")


func test_the_land_is_only_sacrificed_when_the_trigger_resolves() -> void:
	# Both players get priority with the trigger on the stack and the land
	# still on the battlefield — the whole point of a trigger over a cost.
	var forest := put_battlefield(0, "Forest")
	_cast_vortex()
	assert_eq(forest.zone, Mtg.Zone.BATTLEFIELD, "nothing is paid at cast time")
	assert_eq(g.priority_player, 0, "the caster keeps priority (CR 117.3c)")
	assert_ok(g.pass_priority(0))
	assert_eq(g.priority_player, 1, "the opponent may respond to the trigger")


func test_a_land_removed_in_response_leaves_the_vortex_countered() -> void:
	var forest := put_battlefield(0, "Forest")
	var vortex := _cast_vortex()
	g.destroy(forest, false)   # "in response"
	resolve_stack()
	assert_eq(vortex.zone, Mtg.Zone.GRAVEYARD)
