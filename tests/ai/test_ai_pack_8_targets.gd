extends GameTest
## "WHEN THIS CREATURE BECOMES THE TARGET OF A SPELL OR ABILITY, SACRIFICE
## IT" (Pack 8, 2026-10-03; engine package E4's BECAME_TARGET; [member
## AiProfile.forecasts_tactics]).
##
## Skulking Ghost and Tar Pit Warrior die to ANY targeted effect — a pump,
## an aura, a ping, a Healer's prevention. Read off the printed trigger
## (mirage_tactics.gd `dies_when_targeted`, the BECAME_TARGET line that
## says "sacrifice it"), the pilot:
##  * never names its OWN such creature — not as the host of a friendly
##    aura, not for a pump, not as any target of anything it casts or
##    activates (the central guard [method AiPlayer._aims_at_own_fragile]);
##  * counts the opponent's as killable by any harmful spell, whatever its
##    damage — a Bolt kills a 3/4 Tar Pit Warrior — and spends a cheap
##    targeted ABILITY on it (a Prodigal Sorcerer's ping is removal).
## The trigger is public; nothing hidden is read.

const M := preload("res://engine/ai/mirage_tactics.gd")


func before_each() -> void:
	for id in CardPacks.available_ids(): CardPacks.set_enabled(id, false)
	CardPacks.set_enabled("pack-8", true)
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-8", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var ai := AiPlayer.new(seat, profile if profile != null else AiProfile.wizard())
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


## Advance into the OPPONENT's turn and hand seat 0 priority in [param step].
func _their_turn_at(step: int) -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == step) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------------------ the reading --

func test_the_reading_is_the_printed_trigger() -> void:
	var ghost := put_battlefield(0, "Skulking Ghost")
	var warrior := put_battlefield(1, "Tar Pit Warrior")
	var bears := put_battlefield(1, "Grizzly Bears")
	assert_true(M.dies_when_targeted(ghost))
	assert_true(M.dies_when_targeted(warrior))
	assert_false(M.dies_when_targeted(bears))


# ------------------------------------------------------------ our own ----

func test_no_friendly_aura_on_our_own_ghost() -> void:
	var ai := _ai()
	var ghost := put_battlefield(0, "Skulking Ghost")
	put_battlefield(0, "Plains")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	assert_eq(aura.zone, Mtg.Zone.HAND, "the aura would sacrifice the Ghost")
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD)


func test_the_aura_goes_on_the_other_creature() -> void:
	var ai := _ai()
	var ghost := put_battlefield(0, "Skulking Ghost")
	var bears := put_battlefield(0, "Grizzly Bears")
	put_battlefield(0, "Plains")
	var aura := give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	assert_string_contains(ai.act(g), "Holy Strength")
	resolve_stack()
	assert_eq(aura.attached_to, bears.id)
	assert_eq(ghost.zone, Mtg.Zone.BATTLEFIELD)


func test_null_arm_hangs_the_aura_on_the_ghost() -> void:
	var ai := _ai(_null())
	var ghost := put_battlefield(0, "Skulking Ghost")
	put_battlefield(0, "Plains")
	give_hand(0, "Holy Strength")
	advance_to_step(Mtg.Step.MAIN1)
	ai.act(g)
	resolve_stack()
	assert_eq(ghost.zone, Mtg.Zone.GRAVEYARD, "the pilot as it was: the Ghost is lost")


# ------------------------------------------------------------ theirs -----

func test_a_bolt_counts_as_a_kill_on_tar_pit_warrior() -> void:
	var ai := _ai()
	var warrior := put_battlefield(1, "Tar Pit Warrior")
	var bolt := give_hand(0, "Lightning Bolt")
	var spec: TargetSpec = bolt.data.spell_effects[0].target_spec
	var pick: TargetRef = ai._pick_for_spec(g, bolt, spec, bolt.data.spell_effects[0], 0)
	assert_not_null(pick)
	assert_false(pick.is_player, "the 3/4 dies to being named, not to three damage")
	assert_eq(pick.instance_id, warrior.id)


func test_the_sorcerer_pings_their_ghost() -> void:
	var ai := _ai()
	var sorcerer := put_battlefield(0, "Prodigal Sorcerer")
	var ghost := put_battlefield(1, "Skulking Ghost")
	var warrior := put_battlefield(1, "Tar Pit Warrior")
	_their_turn_at(Mtg.Step.END)
	assert_string_contains(ai.act(g), "Prodigal Sorcerer")
	resolve_stack()
	assert_true(sorcerer.tapped)
	assert_true(ghost.zone == Mtg.Zone.GRAVEYARD or warrior.zone == Mtg.Zone.GRAVEYARD,
		"the ping named one of them, and naming is enough")


func test_their_ghost_is_no_reason_to_target_our_own() -> void:
	# The Healer-shaped pick: a helpful ability is never pointed at our own
	# fragile creature, even when it is the only creature of ours.
	var ai := _ai()
	var ghost := put_battlefield(0, "Skulking Ghost")
	assert_false(ai._aims_at_own_fragile(g, [TargetRef.card(put_battlefield(1, "Grizzly Bears"))]))
	assert_true(ai._aims_at_own_fragile(g, [TargetRef.card(ghost)]))
