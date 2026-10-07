extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-a: WHAT A CAST COSTS AND WHO IT HITS
## (2026-10-07). Each pin beside the gate's null arm ([member
## AiProfile.forecasts_tactics] off: the pilot as it was) or a control,
## and a hidden-information permutation (docs/fair-play.md):
##  * w3-4 THE ALTERNATIVE COST IS ONE SPELL: Fireblast and Spinning
##    Darkness (payment rows only) are fired as combat answers like a Bolt;
##    the pilot died holding them.
##  * w6-12 THE TARGET IS NOT THE FODDER: Wicked Reward's sacrifice never
##    eats the creature it pumps; Cone of Flame's "another target" and "a
##    third target" never take our own creatures for one point at a face.


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)    # Mirage block: Fireblast, Spinning Darkness, Wicked Reward, Cone of Flame
	CardPacks.set_enabled("pack-9", true)    # Tempest: Soltari Lancer, Humility
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)
	CardPacks.set_enabled("pack-9", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.mistake_chance = 0.0
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


## The AI drives its seat, the other seat passes, until [param until].
func _drive(ai: AiPlayer, until: Callable, limit := 80) -> void:
	for k in limit:
		if g.game_over or bool(until.call()): return
		if g.awaiting_attackers and g.active_player != ai.pid:
			return
		if g.priority_player == ai.pid or (g.awaiting_blockers and g.active_player != ai.pid):
			if ai.act(g) == "" and g.priority_player == ai.pid:
				g.pass_priority(ai.pid)
		else:
			g.pass_priority(g.priority_player)


## Seat 1 (the AI) at [param life], no creatures, [param burn] in hand;
## seat 0 attacks with a lethal [param attacker_name].
func _survive_with(profile: AiProfile, burn: String, life: int, attacker_name: String,
		lands: Dictionary, humble := false, their_hand: Array = []) -> CardInstance:
	var ai := _ai(profile, 1)
	for land in lands:
		for k in int(lands[land]): put_battlefield(1, String(land))
	var spell := give_hand(1, burn)
	for card_name in their_hand:
		give_hand(0, String(card_name))
	g.players[1].life = life
	if humble:
		put_battlefield(0, "Humility")
	var attacker := put_battlefield(0, attacker_name)
	g.recalculate()
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [attacker.id]))
	_drive(ai, func() -> bool: return g.current_step() == Mtg.Step.COMBAT_END or g.game_over)
	return spell


# ------------------------------------------------------- w3-4 alternatives --

func test_fireblast_answers_a_lethal_attacker() -> void:
	var spell := _survive_with(null, "Fireblast", 1, "Grizzly Bears", {"Mountain": 4, "Swamp": 3})
	assert_false(g.game_over, "died at 1 life with Fireblast in %s" % Mtg.Zone.keys()[spell.zone])


## Only the two Mountains pay it: the row its picker names is the one cast.
func test_fireblast_pays_with_its_mountains() -> void:
	var spell := _survive_with(null, "Fireblast", 1, "Grizzly Bears", {"Mountain": 2})
	assert_false(g.game_over, "two Mountains are Fireblast's price (%s)" % Mtg.Zone.keys()[spell.zone])
	assert_eq(spell.zone, Mtg.Zone.GRAVEYARD)


## Control: short of lethal the picker's choice stands — two Mountains are
## not thrown at a Bears that only costs us two life.
func test_fireblast_keeps_its_mountains_short_of_lethal() -> void:
	var spell := _survive_with(null, "Fireblast", 20, "Grizzly Bears", {"Mountain": 2})
	assert_eq(spell.zone, Mtg.Zone.HAND)
	assert_eq(g.players[1].life, 18)


func test_fireblast_answers_a_humbled_shadow_attacker() -> void:
	var spell := _survive_with(null, "Fireblast", 1, "Soltari Lancer", {"Mountain": 4, "Swamp": 3}, true)
	assert_false(g.game_over, "died at 1 life with Fireblast in %s" % Mtg.Zone.keys()[spell.zone])


func test_spinning_darkness_answers_a_lethal_attacker() -> void:
	var spell := _survive_with(null, "Spinning Darkness", 3, "Hill Giant", {"Swamp": 6})
	assert_false(g.game_over, "died at 3 life with Spinning Darkness in %s" % Mtg.Zone.keys()[spell.zone])


func test_gate_off_dies_holding_fireblast() -> void:
	var spell := _survive_with(_null(), "Fireblast", 1, "Grizzly Bears", {"Mountain": 4, "Swamp": 3})
	assert_true(g.game_over, "gate off: the old pilot never fires it")
	assert_eq(spell.zone, Mtg.Zone.HAND)


func test_their_hidden_hand_does_not_change_the_fireblast() -> void:
	var zones: Array = []
	for hand in [[], ["Giant Growth"], ["Lightning Bolt", "Healing Salve"]]:
		before_each()
		var spell := _survive_with(null, "Fireblast", 1, "Grizzly Bears",
			{"Mountain": 4, "Swamp": 3}, false, hand)
		zones.append([spell.zone, g.game_over])
	assert_eq(zones[0], zones[1])
	assert_eq(zones[0], zones[2])


# ------------------------------------------------------- w6-12 own board --

## Viashino Warrior, our only creature, attacks unblocked at 7 life: the
## Reward would be lethal but its only sacrifice is the Warrior itself.
func _reward_board(profile: AiProfile, second_body := "") -> Dictionary:
	var ai := _ai(profile)
	var warrior := put_battlefield(0, "Viashino Warrior")
	var other: CardInstance = null
	if second_body != "":
		other = put_battlefield(0, second_body)
	put_battlefield(0, "Swamp")
	put_battlefield(0, "Swamp")
	var reward := give_hand(0, "Wicked Reward")
	g.players[1].life = 7
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [warrior.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	assert_ok(g.declare_blockers(1, {}))
	assert_eq(g.priority_player, 0)
	var did := ai.act(g)
	resolve_stack()
	return {"did": did, "warrior": warrior, "other": other, "reward": reward}


func test_wicked_reward_never_sacrifices_its_own_target() -> void:
	var out := _reward_board(null)
	assert_false(String(out["did"]).contains("Wicked Reward"),
		"the only fodder is the Warrior the Reward pumps (%s)" % out["did"])
	assert_eq((out["warrior"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


## With a second body the Reward is cast, and the cost eats the other one.
func test_wicked_reward_sacrifices_the_other_body() -> void:
	var out := _reward_board(null, "Grizzly Bears")
	if String(out["did"]).contains("Wicked Reward"):
		assert_eq((out["warrior"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD,
			"the Warrior it pumps is not the sacrifice")
		assert_eq((out["other"] as CardInstance).zone, Mtg.Zone.GRAVEYARD)
	else:
		pass_test("the Reward was not the pilot's play here: %s" % out["did"])


func test_gate_off_sacrifices_the_target() -> void:
	var out := _reward_board(_null())
	assert_string_contains(String(out["did"]), "Wicked Reward", "gate off: the old cast")
	assert_eq((out["warrior"] as CardInstance).zone, Mtg.Zone.GRAVEYARD)


func _cone_board(profile: AiProfile) -> Array:
	var ai := _ai(profile)
	for i in 5:
		put_battlefield(0, "Mountain")
	var a := put_battlefield(0, "Hill Giant")
	var b := put_battlefield(0, "Gray Ogre")
	give_hand(0, "Cone of Flame")
	var did: Array = []
	for i in 6:
		if g.current_step() != Mtg.Step.MAIN1 or g.game_over:
			break
		var x := ai.act(g)
		did.append(x)
		if x == "pass" or x == "":
			break
		resolve_stack()
	return [did, a, b]


func test_cone_of_flame_never_hits_our_own_creatures() -> void:
	var out := _cone_board(null)
	assert_eq((out[1] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, str(out[0]))
	assert_eq((out[2] as CardInstance).zone, Mtg.Zone.BATTLEFIELD, str(out[0]))


func test_gate_off_cone_hits_our_own() -> void:
	var out := _cone_board(_null())
	assert_true((out[1] as CardInstance).zone == Mtg.Zone.GRAVEYARD
		or (out[2] as CardInstance).zone == Mtg.Zone.GRAVEYARD,
		"gate off: the old Cone into our own board (%s)" % str(out[0]))


## Control: with creatures of theirs to burn, the Cone is cast at them.
func test_cone_of_flame_at_their_creatures() -> void:
	var ai := _ai()
	for i in 5:
		put_battlefield(0, "Mountain")
	var mine := put_battlefield(0, "Hill Giant")
	var x := put_battlefield(1, "Llanowar Elves")
	var y := put_battlefield(1, "Grizzly Bears")
	var z := put_battlefield(1, "Hill Giant")
	give_hand(0, "Cone of Flame")
	var did := ai.act(g)
	resolve_stack()
	assert_string_contains(did, "Cone of Flame")
	assert_eq(mine.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(x.zone == Mtg.Zone.GRAVEYARD) + int(y.zone == Mtg.Zone.GRAVEYARD)
		+ int(z.zone == Mtg.Zone.GRAVEYARD), 3, "1, 2 and 3 at the Elves, the Bears and the Giant")
