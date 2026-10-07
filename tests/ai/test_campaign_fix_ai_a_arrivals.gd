extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-a: THE ARRIVAL THAT CAN ONLY HIT US
## (w6-4, 2026-10-07). A permanent whose "when this enters, <harm> target
## creature" trigger is MANDATORY (CR 603.3d: a target is chosen as it
## goes on the stack) is not cast when every legal target would be ours —
## Fire Imp killing our Bears, Nekrataal destroying our own creature,
## Oubliette phasing ours out, Man-o'-War bouncing itself and being cast
## again in the same main phase. Each beside the gate's null arm
## ([member AiProfile.forecasts_tactics] off) and a control with a target
## of theirs on the table; and a hidden-hand permutation (fair play: the
## opponent's unrevealed hand never moves the answer).


func before_each() -> void:
	CardPacks.set_enabled("pack-6", true)   # Portal: Fire Imp, Man-o'-War
	CardPacks.set_enabled("pack-8", true)   # Visions: Nekrataal
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-6", false)
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _main_until_pass(ai: AiPlayer, limit := 16) -> Array:
	var did: Array = []
	for i in limit:
		if g.game_over or g.current_step() != Mtg.Step.MAIN1:
			break
		var a := ai.act(g)
		did.append(a)
		if a == "pass" or a == "":
			break
		resolve_stack()
	return did


func _casts(did: Array, card_name: String) -> int:
	var n := 0
	for a in did:
		if String(a).contains("cast " + card_name):
			n += 1
	return n


func test_fire_imp_waits_when_only_our_bears_could_be_hit() -> void:
	var ai := _ai()
	for i in 3: put_battlefield(0, "Mountain")
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Fire Imp")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "Fire Imp killed our own Bears: %s" % str(did))
	assert_eq(_casts(did, "Fire Imp"), 0)


## Control: with a creature of theirs on the table the Imp is cast and hits it.
func test_fire_imp_is_cast_with_a_target_of_theirs() -> void:
	var ai := _ai()
	for i in 3: put_battlefield(0, "Mountain")
	var bears := put_battlefield(0, "Grizzly Bears")
	var elves := put_battlefield(1, "Llanowar Elves")
	give_hand(0, "Fire Imp")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(_casts(did, "Fire Imp"), 1, str(did))
	assert_eq(elves.zone, Mtg.Zone.GRAVEYARD, "the Imp's 2 damage went at their Elves")
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD)


## The null arm: the pilot as it was casts the Imp into its own Bears.
func test_gate_off_casts_the_imp_into_our_own_bears() -> void:
	var ai := _ai(_null())
	for i in 3: put_battlefield(0, "Mountain")
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Fire Imp")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(_casts(did, "Fire Imp"), 1, "gate off: the old cast (%s)" % str(did))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)


func test_man_o_war_is_not_cast_to_bounce_itself() -> void:
	var ai := _ai()
	for i in 9: put_battlefield(0, "Island")
	var mow := give_hand(0, "Man-o'-War")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(_casts(did, "Man-o'-War"), 0, "nothing of theirs to bounce: %s" % str(did))
	assert_eq(mow.zone, Mtg.Zone.HAND)


func test_man_o_war_bounces_their_creature() -> void:
	var ai := _ai()
	for i in 3: put_battlefield(0, "Island")
	var ogre := put_battlefield(1, "Gray Ogre")
	give_hand(0, "Man-o'-War")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(_casts(did, "Man-o'-War"), 1, str(did))
	assert_eq(ogre.zone, Mtg.Zone.HAND)


func test_oubliette_waits_when_only_ours_could_be_imprisoned() -> void:
	var ai := _ai()
	for i in 4: put_battlefield(0, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Oubliette")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_false(bears.phased_out, "Oubliette phased out our own Bears: %s" % str(did))


func test_nekrataal_waits_when_only_ours_could_die() -> void:
	var ai := _ai()
	for i in 4: put_battlefield(0, "Swamp")
	var bears := put_battlefield(0, "Grizzly Bears")
	give_hand(0, "Nekrataal")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(bears.zone, Mtg.Zone.BATTLEFIELD, "Nekrataal destroyed our own Bears: %s" % str(did))


## Nekrataal with no legal target at all (only black creatures about) is a
## plain body: its trigger is removed from the stack, nothing is hurt.
func test_nekrataal_with_no_legal_target_is_a_body() -> void:
	var ai := _ai()
	for i in 4: put_battlefield(0, "Swamp")
	give_hand(0, "Nekrataal")
	advance_to_step(Mtg.Step.MAIN1)
	var did := _main_until_pass(ai)
	assert_eq(_casts(did, "Nekrataal"), 1, str(did))


## Fair play: what they hold in hand (unrevealed) does not change the cast.
func test_their_hidden_hand_does_not_change_the_arrival_reading() -> void:
	var lines: Array = []
	for their_hand in [[], ["Grizzly Bears"], ["Llanowar Elves", "Giant Growth"]]:
		before_each()
		var ai := _ai()
		for i in 3: put_battlefield(0, "Mountain")
		put_battlefield(0, "Grizzly Bears")
		give_hand(0, "Fire Imp")
		for card_name in their_hand:
			give_hand(1, String(card_name))
		advance_to_step(Mtg.Step.MAIN1)
		lines.append(ai.act(g))
	assert_eq(lines[0], lines[1])
	assert_eq(lines[0], lines[2])
	assert_false(String(lines[0]).contains("Fire Imp"))
