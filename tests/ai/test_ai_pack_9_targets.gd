extends GameTest
## "BECOMES THE TARGET", READ BY THE FAIR AI (Pack 9, 2026-10-06;
## [member AiProfile.forecasts_tactics]).
##
## [method MirageTactics.dies_when_targeted] read only the creature's OWN
## trigger ("sacrifice it" — Skulking Ghost). Pack 9 adds two shapes:
##  * Spinal Graft — the trigger is on the AURA: "When enchanted creature
##    becomes the target of a spell or ability, destroy that creature";
##  * Segmented Wurm — "put a -1/-1 counter on it": fatal only to a body
##    one toughness from death.
## Pinned through the activation arm that turns any targeted ability into
## removal against such a creature of theirs (a Prodigal Sorcerer's ping
## kills a 5/5 under a Graft). The null arm (gate off) pings the face as
## before; the opponent's hidden hand does not move the choice.


const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)


func _ai(on := true, seat := 0) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _graft(host: CardInstance) -> CardInstance:
	var graft := give_hand(host.controller_id, "Spinal Graft")
	g.attach_aura_from_anywhere(graft, host, host.controller_id)
	g.recalculate()
	return graft


# ------------------------------------------------------------ the reading --

func test_a_grafted_creature_dies_when_targeted() -> void:
	var bears := put_battlefield(1, "Grizzly Bears")
	_graft(bears)
	assert_eq(bears.cur_power, 5, "+3/+3")
	assert_true(M.dies_when_targeted(bears, g), "the Aura's trigger destroys it")
	assert_false(M.dies_when_targeted(put_battlefield(1, "Grizzly Bears"), g))


func test_a_segmented_wurm_dies_when_targeted_only_at_its_last_point() -> void:
	var wurm := put_battlefield(1, "Segmented Wurm")
	assert_false(M.dies_when_targeted(wurm, g), "a 5/5 shrinks to 4/4")
	wurm.damage = 4
	assert_true(M.dies_when_targeted(wurm, g), "a -1/-1 counter on its last point")


# --------------------------------------------------------- the activation --

func test_the_sorcerer_pings_the_grafted_creature() -> void:
	var ai := _ai()
	put_battlefield(0, "Prodigal Sorcerer")
	var bears := put_battlefield(1, "Grizzly Bears")
	_graft(bears)
	assert_string_contains(ai.act(g), "Prodigal Sorcerer")
	assert_eq(g.stack[0].targets[0].instance_id, bears.id, "the ping is removal against a 5/5")
	assert_eq(g.stack.size(), 2, "the Graft's trigger answers the target")
	resolve_stack()
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_the_null_arm_does_not_see_the_graft() -> void:
	var ai := _ai(false)
	put_battlefield(0, "Prodigal Sorcerer")
	var bears := put_battlefield(1, "Grizzly Bears")
	_graft(bears)
	ai.act(g)
	for item in g.stack:
		for t in item.targets:
			assert_ne(t.instance_id if not t.is_player else -1, bears.id, "gate off: a 5/5 is no ping target")


func test_the_ping_ignores_their_hidden_cards() -> void:
	var answers: Array = []
	for variant in 2:
		before_each()
		var ai := _ai()
		put_battlefield(0, "Prodigal Sorcerer")
		var bears := put_battlefield(1, "Grizzly Bears")
		_graft(bears)
		give_hand(1, "Giant Growth" if variant == 0 else "Counterspell")
		g.players[1].library.reverse()
		var line := ai.act(g)
		answers.append(line + str(not g.stack.is_empty() and g.stack[0].targets[0].instance_id == bears.id))
	assert_eq(answers[0], answers[1], "hidden cards changed the decision")
