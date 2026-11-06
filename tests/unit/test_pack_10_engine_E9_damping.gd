extends GameTest
## Pack 10 engine package E9 (part 2) — A NON-AURA "SACRIFICE A PERMANENT TO
## IGNORE THIS EFFECT" (Damping Engine: "A player who controls more
## permanents than each other player can't play lands or cast artifact,
## creature, or enchantment spells. That player may sacrifice a permanent
## of their choice for that player to ignore this effect until end of
## turn." — CR 116.2d special action, 601.3, 305.2).
##
## Pack 9's ignore action (Volrath's Curse) offered itself only to "the
## controller of the permanent it enchants". Two seams make it general:
##  * [method CardData.ignorable_by_sacrifice] takes a PAYER —
##    `func(game: MtgGame, source: CardInstance) -> int`, the one seat the
##    action is offered to right now (-1 none); the default stays the
##    enchanted permanent's controller. [method MtgGame.special_actions]
##    lists it for that seat and [method MtgGame.ignore_static_effect]
##    takes it (the sacrifice held for a human as a cost question).
##  * [method MtgGame.play_banned] hands a ban callback that takes FOUR
##    arguments the radiating permanent as the fourth, so the card can ask
##    [method MtgGame.effect_ignored_by] for itself. Three-argument bans
##    (Arcane Laboratory, City in a Bottle) are called as before.
## A tapped noncreature artifact under the 1997 rule radiates nothing and
## offers nothing.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


static func _damping() -> CardData:
	return CardData.new("Test Damping Engine", "{4}", Mtg.CardType.ARTIFACT) \
		.bans_playing(_ban) \
		.ignorable_by_sacrifice("permanent", Callable(), _most_permanents) \
		.oracle("A player who controls more permanents than each other player can't play lands or cast artifact, creature, or enchantment spells. That player may sacrifice a permanent of their choice for that player to ignore this effect until end of turn.")


## "A player who controls more permanents than each other player".
static func _most_permanents(g: MtgGame, _source: CardInstance) -> int:
	var mine := g.players[0].battlefield.size()
	var theirs := g.players[1].battlefield.size()
	return 0 if mine > theirs else (1 if theirs > mine else -1)


static func _ban(g: MtgGame, pid: int, data: CardData, source: CardInstance) -> bool:
	if _most_permanents(g, source) != pid or g.effect_ignored_by(source, pid):
		return false
	return data.is_land() or data.is_creature() \
		or data.is_type(Mtg.CardType.ARTIFACT) or data.is_type(Mtg.CardType.ENCHANTMENT)


## A three-argument ban, as every card before Pack 10 wrote it.
static func _old_lab() -> CardData:
	return CardData.new("Test Old Lab", "{2}{U}", Mtg.CardType.ENCHANTMENT) \
		.bans_playing(_no_creatures).oracle("Players can't cast creature spells.")


static func _no_creatures(_g: MtgGame, _pid: int, data: CardData) -> bool:
	return data.is_creature()


func _human_seat(pid := 0) -> HumanAgent:
	var human := HumanAgent.new()
	g.agents[pid] = human
	g.interactive_choices = true
	return human


func _ignore_rows(pid: int) -> Array:
	var out: Array = []
	for row in g.special_actions(pid):
		if String(row["kind"]) == "ignore_effect":
			out.append(row)
	return out


func _crowded() -> CardInstance:
	# Seat 1's Engine; seat 0 controls three permanents to its one.
	var engine := put_synthetic(1, _damping())
	put_battlefield(0, "Forest")
	put_battlefield(0, "Forest")
	put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	return engine


# --------------------------------------------------------------------------

func test_the_player_with_more_permanents_is_banned() -> void:
	_crowded()
	var data := CardRegistry.get_card("Grizzly Bears")
	assert_eq(g.play_banned(0, data), "Test Damping Engine")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "Test Damping Engine", "lands too")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Sol Ring")), "Test Damping Engine", "artifacts too")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Lightning Bolt")), "", "an instant is not")
	assert_eq(g.play_banned(1, data), "", "the other player is not")
	var land := give_hand(0, "Forest")
	assert_refused(g.play_land(0, land), "Test Damping Engine")
	var bears := give_hand(0, "Grizzly Bears")
	add_mana(0, Mtg.ManaColor.G, 2)
	assert_refused(g.cast_spell(0, bears, []))
	var bolt := give_hand(0, "Lightning Bolt")
	add_mana(0, Mtg.ManaColor.R)
	assert_ok(g.cast_spell(0, bolt, [TargetRef.player(1)]))


func test_equal_counts_ban_nobody() -> void:
	put_synthetic(1, _damping())
	put_battlefield(0, "Forest")
	g.recalculate()
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "")
	assert_eq(g.play_banned(1, CardRegistry.get_card("Forest")), "")
	assert_true(_ignore_rows(0).is_empty() and _ignore_rows(1).is_empty(), "nothing to ignore")


func test_the_ban_follows_the_counts_live() -> void:
	_crowded()
	assert_ne(g.play_banned(0, CardRegistry.get_card("Forest")), "")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	put_battlefield(1, "Island")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "", "seat 0 no longer has the most")
	assert_eq(g.play_banned(1, CardRegistry.get_card("Forest")), "Test Damping Engine", "seat 1 has")


func test_the_ignore_action_is_offered_to_that_player_only() -> void:
	var engine := _crowded()
	var rows := _ignore_rows(0)
	assert_eq(rows.size(), 1)
	assert_eq(int(rows[0]["id"]), engine.id)
	assert_eq(String(rows[0]["label"]), "Sacrifice a permanent: ignore Test Damping Engine this turn")
	assert_eq(g.special_action_refusal(0, rows[0]), "")
	assert_true(_ignore_rows(1).is_empty(), "the Engine's controller has fewer permanents")


func test_sacrificing_lifts_the_ban_until_end_of_turn() -> void:
	var engine := _crowded()
	var before := g.players[0].battlefield.size()
	assert_ok(g.take_special_action(0, _ignore_rows(0)[0]))
	assert_eq(g.players[0].battlefield.size(), before - 1, "a permanent was sacrificed")
	assert_true(g.effect_ignored_by(engine, 0))
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "",
		"ignored this turn, though seat 0 still has the most")
	assert_true(_ignore_rows(0).is_empty(), "taken once a turn")
	var land := give_hand(0, "Forest")
	assert_ok(g.play_land(0, land))
	advance_to_next_turn()
	assert_false(g.effect_ignored_by(engine, 0), "until end of turn only")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Grizzly Bears")), "Test Damping Engine",
		"a new turn binds again")


func test_a_human_is_held_on_which_permanent() -> void:
	var engine := _crowded()
	_human_seat(0)
	var bears := g.find_on_battlefield(0, "Grizzly Bears")
	assert_ok(g.take_special_action(0, _ignore_rows(0)[0]))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "held on the sacrifice")
	assert_eq(asked.kind, PlayerChoice.Kind.CARD)
	assert_true(asked.is_cost)
	assert_eq(asked.source, "Test Damping Engine")
	assert_eq(asked.candidates.size(), 3, "any permanent of theirs")
	assert_ok(g.answer_choice(bears.id))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD, "the one they picked")
	assert_true(g.effect_ignored_by(engine, 0))


func test_the_engines_own_controller_may_sacrifice_the_engine() -> void:
	var engine := put_synthetic(0, _damping())
	put_battlefield(0, "Forest")
	g.recalculate()
	_human_seat(0)
	assert_ok(g.take_special_action(0, _ignore_rows(0)[0]))
	assert_ok(g.answer_choice(engine.id))
	assert_eq(engine.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "", "no Engine, no ban")


func test_a_tapped_engine_under_1997_rules_does_nothing() -> void:
	var engine := _crowded()
	g.rules.tapped_artifacts_stop = true
	engine.tapped = true
	g.recalculate()
	assert_true(engine.cur_statics_suspended)
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "")
	assert_true(_ignore_rows(0).is_empty(), "no effect left to ignore")


func test_a_silenced_engine_offers_nothing() -> void:
	var engine := _crowded()
	engine.cur_abilities_silenced = true
	assert_eq(g._ignore_payer(engine), -1)


func test_three_argument_bans_are_called_as_before() -> void:
	put_synthetic(1, _old_lab())
	g.recalculate()
	assert_eq(g.play_banned(0, CardRegistry.get_card("Grizzly Bears")), "Test Old Lab")
	assert_eq(g.play_banned(0, CardRegistry.get_card("Forest")), "")


func test_the_aura_default_payer_is_unchanged() -> void:
	# Volrath's Curse's shape: no payer — the enchanted permanent's controller.
	var curse_data := CardData.new("Test Curse", "{1}{U}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()).ignorable_by_sacrifice("permanent") \
		.oracle("Enchant creature")
	assert_false(curse_data.ignore_effect_sacrifice.get("payer", Callable()).is_valid())
	var curse := give_synthetic(1, curse_data)
	var bear := put_battlefield(0, "Grizzly Bears")
	g.priority_player = 1
	g.attach_aura_from_anywhere(curse, bear, 1)
	g.priority_player = 0
	assert_eq(g._ignore_payer(curse), 0)
	assert_eq(_ignore_rows(0).size(), 1)
