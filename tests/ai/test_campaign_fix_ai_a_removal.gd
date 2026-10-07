extends GameTest
## THE WHOLE-GAME CAMPAIGN, fix-ai-a: REMOVAL AIMED WHERE IT WORKS
## (2026-10-07). Pins for four hunt findings, each beside the gate's null
## arm ([member AiProfile.forecasts_tactics] off: the pilot as it was) or
## a control, and a hidden-information permutation (docs/fair-play.md):
##  * w6-11 / w2-3 THE ESCAPE ON DEMAND: Blinking Spirit's "{0}: return
##    this to its owner's hand" answers any removal for free; Swords and
##    Bolt were aimed at it and fizzled (28 of 28 fizzles in 256 Lab games).
##    A self-bounce they cannot pay for is no escape.
##  * w1-4 THE SHIELD THEY CAN STILL BUY: X burn into a Will-o'-the-Wisp
##    with {B} open behind it, a Bolt into Drudge Skeletons — both presets.
##  * w6-8 THE ANSWER ALREADY ON THE STACK: a second Bolt at a pumping
##    Killer Bees the first Bolt (under a pump) already kills.


func before_each() -> void:
	CardPacks.set_enabled("pack-3", true)   # Ice Age: Blinking Spirit, Foul Familiar
	super()


func after_each() -> void:
	g = null
	CardPacks.set_enabled("pack-3", false)


func _ai(profile: AiProfile = null, seat := 0) -> AiPlayer:
	var p := profile if profile != null else AiProfile.wizard()
	p.develops_late = false
	var ai := AiPlayer.new(seat, p)
	g.set_agent(seat, ai)
	return ai


func _null() -> AiProfile:
	var p := AiProfile.wizard()
	p.forecasts_tactics = false
	return p


func _to_their_end_step() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.END) and guard < 400:
		_advance_once()
		guard += 1
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)


# ------------------------------------------------- w6-11 / w2-3 the escape --

func _swords_at_end_step(profile: AiProfile, victim_name: String,
		their_hand: Array = [], their_lands: Array = []) -> String:
	var ai := _ai(profile)
	put_battlefield(0, "Plains")
	give_hand(0, "Swords to Plowshares")
	put_battlefield(1, victim_name)
	for land in their_lands:
		put_battlefield(1, String(land))
	for card_name in their_hand:
		give_hand(1, String(card_name))
	_to_their_end_step()
	return ai.act(g)


func test_no_swords_at_a_blinking_spirit() -> void:
	var did := _swords_at_end_step(null, "Blinking Spirit")
	assert_false(did.contains("Swords to Plowshares"),
		"the Spirit returns to hand for {0} in response (did '%s')" % did)


func test_gate_off_swords_the_blinking_spirit() -> void:
	var did := _swords_at_end_step(_null(), "Blinking Spirit")
	assert_string_contains(did, "Swords to Plowshares", "gate off: the old aim")


## Control: a creature with no escape is still removed at their end step.
func test_swords_a_creature_that_cannot_escape() -> void:
	var did := _swords_at_end_step(null, "Serra Angel")
	assert_string_contains(did, "Swords to Plowshares")


## Foul Familiar's escape costs {B} and a life: with no black mana open
## on their side it is no escape, and the Swords goes in.
func test_an_escape_they_cannot_pay_is_no_escape() -> void:
	var unpaid := _swords_at_end_step(null, "Foul Familiar", [], ["Forest"])
	before_each()
	var paid := _swords_at_end_step(null, "Foul Familiar", [], ["Swamp"])
	assert_false(paid.contains("Swords"), "{B} open: the Familiar bounces in response (%s)" % paid)
	# The Familiar is a 3/1: worth the Swords when it cannot get away.
	assert_string_contains(unpaid, "Swords to Plowshares",
		"no {B} open: the escape cannot be paid, the Swords goes in")


func test_no_bolt_at_a_blinking_spirit() -> void:
	var ai := _ai()
	put_battlefield(1, "Blinking Spirit")
	give_hand(0, "Lightning Bolt")
	for n in 2: put_battlefield(0, "Mountain")
	_to_their_end_step()
	var did := ai.act(g)
	assert_false(did.contains("Lightning Bolt"), did)


## Fair play: their hidden hand does not move the reading.
func test_their_hidden_hand_does_not_change_the_escape_reading() -> void:
	var lines: Array = []
	for hand in [[], ["Swords to Plowshares"], ["Giant Growth", "Counterspell"]]:
		before_each()
		lines.append(_swords_at_end_step(null, "Blinking Spirit", hand))
	assert_eq(lines[0], lines[1])
	assert_eq(lines[0], lines[2])


# ------------------------------------------------------ w1-4 regeneration --

func _wisp_board(fifth: bool, swamp_tapped := false) -> AiPlayer:
	if fifth:
		g.rules.set_edition("fifth")
	var ai := _ai()
	g.set_agent(1, AiPlayer.new(1, AiProfile.wizard()))
	for _i in 4:
		put_battlefield(0, "Mountain")
	var wisp := put_battlefield(1, "Will-o'-the-Wisp")
	var unholy := _make_instance(1, "Unholy Strength")
	g.attach_aura_from_anywhere(unholy, wisp, 1)
	var swamp := put_battlefield(1, "Swamp")
	swamp.tapped = swamp_tapped
	g.players[0].life = 8
	give_hand(0, "Fireball")
	advance_to_step(Mtg.Step.MAIN1)
	return ai


func _fireball_target(ai: AiPlayer) -> String:
	var did := ai.act(g)
	if g.stack.is_empty():
		return "none (%s)" % did
	var top: StackItem = g.stack.back()
	if top.targets.is_empty() or top.targets[0].is_player:
		return "player"
	return g.find_instance(top.targets[0].instance_id).data.card_name


func test_no_fireball_into_a_regenerating_wisp_modern() -> void:
	var ai := _wisp_board(false)
	assert_ne(_fireball_target(ai), "Will-o'-the-Wisp")


func test_no_fireball_into_a_regenerating_wisp_fifth() -> void:
	var ai := _wisp_board(true)
	assert_ne(_fireball_target(ai), "Will-o'-the-Wisp")


## Control: the Swamp tapped, no shield can be bought — the Wisp burns.
func test_fireball_the_wisp_when_its_swamp_is_tapped() -> void:
	var ai := _wisp_board(false, true)
	assert_eq(_fireball_target(ai), "Will-o'-the-Wisp")


func test_gate_off_fireballs_the_regenerating_wisp() -> void:
	var ai := _wisp_board(false)
	ai.profile.forecasts_tactics = false
	assert_eq(_fireball_target(ai), "Will-o'-the-Wisp", "gate off: the old aim")


func test_no_bolt_into_drudge_skeletons_with_b_open() -> void:
	var ai := _ai()
	put_battlefield(0, "Mountain")
	put_battlefield(1, "Drudge Skeletons")
	put_battlefield(1, "Swamp")
	give_hand(0, "Lightning Bolt")
	_to_their_end_step()
	var did := ai.act(g)
	assert_false(did.contains("Lightning Bolt"), did)


## INCINERATE'S RIDER (wave 2): "a creature dealt damage this way can't be
## regenerated this turn" — the reader's row (EffectIntent.CARD_LOCAL)
## makes the open {2} behind a Clay Statue no reason to hold it, where a
## Bolt (no rider) waits.
func _statue_at_end_step(profile: AiProfile, burn: String) -> Dictionary:
	var ai := _ai(profile)
	for n in 2: put_battlefield(0, "Mountain")
	var spell := give_hand(0, burn)
	var statue := put_battlefield(1, "Clay Statue")
	for n in 2: put_battlefield(1, "Mountain")
	_to_their_end_step()
	return {"did": ai.act(g), "spell": spell, "statue": statue}


func test_the_reader_knows_incinerate_ignores_regeneration() -> void:
	var data := CardRegistry.get_card("Incinerate")
	var intent := EffectIntent.read(data.spell_effects, data.card_name)
	assert_eq(intent.damage, 3)
	assert_true(intent.removal_ignores_regeneration)
	assert_false(intent.unknown)


func test_incinerate_burns_a_regenerator_through_its_open_mana() -> void:
	var out := _statue_at_end_step(null, "Incinerate")
	assert_string_contains(String(out["did"]), "Incinerate")
	resolve_stack()
	assert_eq((out["statue"] as CardInstance).zone, Mtg.Zone.GRAVEYARD,
		"no regeneration: the Statue is gone")


func test_bolt_waits_for_the_same_regenerator() -> void:
	var out := _statue_at_end_step(null, "Lightning Bolt")
	assert_false(String(out["did"]).contains("Lightning Bolt"),
		"{2} open regenerates the Statue: the Bolt waits (%s)" % out["did"])


func test_gate_off_bolts_the_regenerator() -> void:
	var out := _statue_at_end_step(_null(), "Lightning Bolt")
	assert_string_contains(String(out["did"]), "Lightning Bolt", "gate off: the old aim")


# ------------------------------------------------- w6-8 the double removal --

## The duel's own order (w6 harness seed 2, turn 12): pump A resolves, the
## AI Bolts with pump B on the stack, pump C goes on top of the Bolt. Bolt
## 1 meets a 2/3 Bees and kills it; a second Bolt is a card thrown away.
func _bees_duel(profile: AiProfile) -> Dictionary:
	var ai := _ai(profile, 1)
	g.players[1].life = 10
	var bees := put_battlefield(0, "Killer Bees")
	put_battlefield(1, "Mountain")
	put_battlefield(1, "Mountain")
	give_hand(1, "Lightning Bolt")
	give_hand(1, "Lightning Bolt")
	advance_to_step(Mtg.Step.DECLARE_ATTACKERS)
	assert_ok(g.declare_attackers(0, [bees.id]))
	var guard := 0
	while not g.awaiting_blockers and guard < 20:
		assert_ok(g.pass_priority(g.priority_player))
		guard += 1
	ai.act(g)
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, bees, 0, []))
	assert_ok(g.pass_priority(0))
	var first := ai.act(g)
	if first == "pass":
		add_mana(0, Mtg.ManaColor.G)
		assert_ok(g.activate_ability(0, bees, 0, []))
		assert_ok(g.pass_priority(0))
		first = ai.act(g)
	if not first.contains("Lightning Bolt"):
		return {"first": first, "second": ""}
	assert_ok(g.pass_priority(1))
	add_mana(0, Mtg.ManaColor.G)
	assert_ok(g.activate_ability(0, bees, 0, []))
	assert_ok(g.pass_priority(0))
	return {"first": first, "second": ai.act(g), "bees": bees}


func test_no_second_bolt_at_bees_the_first_bolt_kills() -> void:
	var out := _bees_duel(null)
	assert_string_contains(String(out["first"]), "Lightning Bolt")
	assert_false(String(out["second"]).contains("Lightning Bolt"),
		"Bolt 1 meets a 2/3 Bees: the second is wasted (%s)" % out["second"])
	resolve_stack()
	assert_eq((out["bees"] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "the first Bolt did kill it")


func test_gate_off_fires_the_second_bolt() -> void:
	var out := _bees_duel(_null())
	assert_string_contains(String(out["second"]), "Lightning Bolt", "gate off: the old double answer")
