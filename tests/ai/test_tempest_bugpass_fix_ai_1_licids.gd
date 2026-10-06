extends GameTest
## Pack 9 bug pass (h3-2, h3-8): two self-harms of the fair AI around a
## creature an Aura holds.
##
## h3-2 ([member AiProfile.forecasts_tactics]): Volrath's Curse's "sacrifice
## a permanent to ignore this effect" is a COST question, and
## [method AiPlayer.answer_card] paid it with the cheapest body of all —
## the cursed creature itself, the attacker the ignore was bought for. It
## now never gives up the creature the cost frees while another candidate
## can pay ([method AiPlayer._freed_by_cost]).
##
## h3-8 (every rung): "{G}: Regenerate enchanted creature" shields its host
## or nothing. A Nurturing Licid that is still a creature enchants nothing,
## and the null arm paid {G} for a shield on no one
## ([method AiPlayer._effects_regenerate]).


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	super()


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


## Seat 1's main phase, seat 1 holding priority.
func _their_main() -> void:
	var guard := 0
	while not (g.active_player == 1 and g.current_step() == Mtg.Step.MAIN1) \
			and not g.game_over and guard < 400:
		_advance_once()
		guard += 1
	assert_lt(guard, 400)


func _cursed(pid: int, name: String) -> Array:
	var body := put_battlefield(pid, name)
	var curse := give_hand(1 - pid, "Volrath's Curse")
	g.attach_aura_from_anywhere(curse, body, 1 - pid)
	g.recalculate()
	assert_true(body.cur_cant_attack)
	return [body, curse]


# ------------------------------------------------- h3-2: the Curse's price --

func _curse_scenario(on: bool, their_hand: Array = []) -> Dictionary:
	var ai := _ai(on)
	var pair := _cursed(0, "Savannah Lions")
	var plains := put_battlefield(0, "Plains")
	g.players[1].life = 2
	for card_name in their_hand: give_hand(1, card_name)
	advance_to_step(Mtg.Step.MAIN1)
	var line := ai.act(g)
	return {"line": line, "lions": pair[0], "plains": plains}


func test_the_curse_is_ignored_with_the_plains_not_the_lions() -> void:
	var out := _curse_scenario(true)
	assert_string_contains(out["line"], "ignores Volrath's Curse")
	assert_eq((out["lions"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD,
		"the attacker the ignore was bought for is not its price")
	assert_eq((out["plains"] as CardInstance).zone, Mtg.Zone.GRAVEYARD, "the Plains paid")


func test_the_freed_lions_attack_for_the_game() -> void:
	var out := _curse_scenario(true)
	var ai := g.agents[0] as AiPlayer
	var lions: CardInstance = out["lions"]
	var turn := g.turn_number
	var guard := 0
	while not g.game_over and g.turn_number == turn and guard < 200:
		if (g.awaiting_attackers and g.active_player == 0) or (g.priority_player == 0
				and not g.awaiting_attackers and not g.awaiting_blockers):
			ai.act(g)
		else:
			_advance_once()
		guard += 1
	assert_eq(lions.zone, Mtg.Zone.BATTLEFIELD)
	assert_true(g.game_over, "two life, a 2/1 freed to attack")
	assert_eq(g.players[1].life, 0)


func test_gate_off_never_ignores_the_curse() -> void:
	var out := _curse_scenario(false)
	assert_false(String(out["line"]).contains("ignores Volrath's Curse"), "gate off: as before")
	assert_eq((out["lions"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)
	assert_eq((out["plains"] as CardInstance).zone, Mtg.Zone.BATTLEFIELD)


func test_the_curse_price_ignores_their_hidden_hand() -> void:
	var zones: Array = []
	for hand in [["Counterspell", "Lightning Bolt"], ["Island"], []]:
		g = null
		before_each()
		var out := _curse_scenario(true, hand)
		zones.append([(out["lions"] as CardInstance).zone, (out["plains"] as CardInstance).zone])
	assert_eq(zones, [[Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD],
		[Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD], [Mtg.Zone.BATTLEFIELD, Mtg.Zone.GRAVEYARD]])


## The cursed body is still the price when it is the ONLY permanent that
## can pay: the cost question has one answer, and it is not refused here.
func test_the_cursed_body_alone_still_answers_the_cost_question() -> void:
	var ai := _ai(true)
	var pair := _cursed(0, "Savannah Lions")
	var lions: CardInstance = pair[0]
	var choice := PlayerChoice.new(PlayerChoice.Kind.CARD, 0, "sacrifice")
	choice.source = "Volrath's Curse"
	choice.is_cost = true
	ai._current_choice = choice
	var only: Array[CardInstance] = [lions]
	assert_eq(ai.answer_card(g, 0, only, "Sacrifice a permanent"), lions)
	var plains := put_battlefield(0, "Plains")
	var both: Array[CardInstance] = [lions, plains]
	assert_eq(ai.answer_card(g, 0, both, "Sacrifice a permanent"), plains)


# ------------------------------------ h3-8: the regeneration of no one --

func test_null_arm_pays_nothing_for_a_hostless_nurturing_regeneration() -> void:
	var ai := _ai(false)
	var licid := put_battlefield(0, "Nurturing Licid")
	var forest := put_battlefield(0, "Forest")
	_their_main()
	var bolt := give_hand(1, "Lightning Bolt")
	add_mana(1, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(1, bolt, [TargetRef.card(licid)]))
	assert_ok(g.pass_priority(1))
	assert_eq(g.priority_player, 0)
	var line := ai.act(g)
	assert_false(forest.tapped,
		"{G}: Regenerate enchanted creature shields nothing while the licid enchants nothing (line: %s)" % line)


func test_gate_on_reads_no_shield_for_a_hostless_nurturing_licid() -> void:
	var ai := _ai(true)
	var licid := put_battlefield(0, "Nurturing Licid")
	put_battlefield(0, "Forest")
	for ability in licid.cur_activated_abilities:
		assert_false(ai._effects_regenerate(g, ability.effects, licid, licid),
			"no host, no shield")


func test_an_attached_nurturing_licid_still_shields_its_host() -> void:
	var ai := _ai(true)
	var giant := put_battlefield(0, "Hill Giant")
	var licid := put_battlefield(0, "Nurturing Licid")
	assert_true(g.become_licid_aura(licid, giant))
	var shields := false
	for ability in licid.cur_activated_abilities:
		if ai._effects_regenerate(g, ability.effects, giant, licid):
			shields = true
	assert_true(shields, "the host is shielded")
	for ability in licid.cur_activated_abilities:
		assert_false(ai._effects_regenerate(g, ability.effects, licid, licid),
			"and the licid itself never is")
