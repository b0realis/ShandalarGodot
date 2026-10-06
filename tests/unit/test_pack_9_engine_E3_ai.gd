extends GameTest
## Pack 9 engine package E3 — THE FAIR AI'S MINIMUM FOR A LICID
## (engine/ai/tempest_tactics.gd `licid_option`, reached through the Mirage
## module's activation arm; gated by [member AiProfile.forecasts_tactics]).
##
## In our first main phase the pilot hangs a licid on one of its own
## creatures when the attack it would declare this turn is worth more for
## it by at least the main phase's bar — asked of its own attack planner
## under the search journal. Pinned: a flying gift to a big ground
## creature a ground wall would stop is taken; a gift the host already has,
## and a "can't attack" Aura half, are not; the null arm (gate off) never
## activates; the decision does not move when the opponent's hidden hand
## and library change (docs/fair-play.md).


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func _ai(on := true) -> AiPlayer:
	var p := AiProfile.wizard()
	p.develops_late = false
	p.mistake_chance = 0.0
	p.forecasts_tactics = on
	var ai := AiPlayer.new(0, p)
	g.set_agent(0, ai)
	return ai


## A blue 2/2 licid whose Aura half grants flying ("Gliding Licid"'s shape).
static func _gliding() -> CardData:
	return CardData.new("Synthetic Gliding Licid", "{2}{U}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{U}", "{U}") \
		.static_ability(StaticAbility.new(_host_flies, "Enchanted creature has flying.").changing_abilities()) \
		.oracle("{U}, {T}: ... You may pay {U} to end this effect.\nEnchanted creature has flying.")


## A white 2/2 licid whose Aura half stops its host attacking ("Calming
## Licid"'s shape) — an Aura for THEIR creature, never ours.
static func _calming() -> CardData:
	return CardData.new("Synthetic Calming Licid", "{2}{W}", Mtg.CardType.CREATURE).pt(2, 2) \
		.with_subtypes(["licid"]).as_licid("{W}", "{W}") \
		.static_ability(StaticAbility.new(_host_stays, "Enchanted creature can't attack.")) \
		.oracle("{W}, {T}: ... You may pay {W} to end this effect.\nEnchanted creature can't attack.")


static func _host_flies(game: MtgGame, s: CardInstance) -> void:
	var h := game.find_instance(s.attached_to)
	if s.attached_to != -1 and game.is_present(h) and not h.cur_keywords.has(Mtg.Keyword.FLYING):
		h.cur_keywords.append(Mtg.Keyword.FLYING)


static func _host_stays(game: MtgGame, s: CardInstance) -> void:
	var h := game.find_instance(s.attached_to)
	if s.attached_to != -1 and game.is_present(h):
		h.cur_cant_attack = true


static func _brute(flying := false) -> CardData:
	var d := CardData.new("Synthetic Brute", "{4}{G}", Mtg.CardType.CREATURE).pt(5, 5)
	if flying:
		d.with_keywords([Mtg.Keyword.FLYING])
	return d


func _board(licid: CardData, flying_brute := false) -> Array:
	var lic := put_synthetic(0, licid)
	var brute := put_synthetic(0, _brute(flying_brute))
	put_battlefield(0, "Island")
	put_battlefield(0, "Plains")
	put_battlefield(1, "Wall of Stone")   # 0/8: the ground is shut
	put_battlefield(1, "Grizzly Bears")
	return [lic, brute]


func test_the_licid_flies_the_big_attacker_over_their_wall() -> void:
	var ai := _ai()
	var pair := _board(_gliding())
	var licid: CardInstance = pair[0]
	var brute: CardInstance = pair[1]
	assert_eq(ai.act(g), "activated Synthetic Gliding Licid")
	resolve_stack()
	assert_true(g.is_licid_aura(licid))
	assert_eq(licid.attached_to, brute.id)
	assert_true(brute.has_keyword(Mtg.Keyword.FLYING))


func test_the_null_arm_never_activates_a_licid() -> void:
	var ai := _ai(false)
	var pair := _board(_gliding())
	var licid: CardInstance = pair[0]
	assert_ne(ai.act(g), "activated Synthetic Gliding Licid")
	resolve_stack()
	assert_false(g.is_licid_aura(licid))
	assert_false(licid.tapped)


func test_a_gift_the_host_already_has_is_not_bought() -> void:
	var ai := _ai()
	var pair := _board(_gliding(), true)
	var licid: CardInstance = pair[0]
	assert_ne(ai.act(g), "activated Synthetic Gliding Licid")
	assert_false(licid.tapped)
	assert_false(g.is_licid_aura(licid))


func test_a_hostile_aura_half_is_never_hung_on_our_own_creature() -> void:
	var ai := _ai()
	var pair := _board(_calming())
	var licid: CardInstance = pair[0]
	assert_ne(ai.act(g), "activated Synthetic Calming Licid")
	assert_false(licid.tapped)
	assert_false(g.is_licid_aura(licid))


func test_not_on_their_turn_nor_after_combat() -> void:
	var ai := _ai()
	var pair := _board(_gliding())
	var licid: CardInstance = pair[0]
	advance_to_step(Mtg.Step.MAIN2)
	g.priority_player = 0
	assert_ne(ai.act(g), "activated Synthetic Gliding Licid")
	assert_false(g.is_licid_aura(licid))


func test_the_decision_ignores_the_opponents_hidden_cards() -> void:
	var picks: Array = []
	for hand in [["Lightning Bolt", "Giant Growth"], ["Forest"], []]:
		before_each()
		var ai := _ai()
		var pair := _board(_gliding())
		for name in hand:
			give_hand(1, name)
		g.players[1].library.shuffle()
		var did := ai.act(g)
		resolve_stack()
		picks.append([did, (pair[0] as CardInstance).attached_to == (pair[1] as CardInstance).id])
	assert_eq(picks[0], picks[1])
	assert_eq(picks[1], picks[2])
	assert_eq(picks[0], ["activated Synthetic Gliding Licid", true])
