extends GameTest
## Pack 10 engine packages E8/E9 — EVERY NEW QUESTION REACHES BOTH FRONT
## ENDS. The questions are the engine's existing kinds (OPTION, COLOR,
## CARD), held on the existing pending actions ("mana", "untap",
## "special"), so the local duel screen lists them with its own static
## readers ([method DuelScreen.choice_options]) and the SGManalink referee
## (`SgDuelActions.choice_view` / `answer`, the "mana", "special" and
## "choice" ops) puts and answers them — no new action kind on the wire.
##  * Metalworker's "how many artifact cards?" and "which?" (E8);
##  * a mana trigger's colour asked before the tap (Fertile Ground's COLOR,
##    Mana Flare's OPTION among the types made) (E8);
##  * Storage Matrix's "Artifact / Creature / Land" in the untap step (E9);
##  * Damping Engine's "Sacrifice a permanent: ignore ..." special action
##    and its sacrifice (E9).
## The opponent sees the names Metalworker reveals.


func before_each() -> void:
	super()
	advance_to_step(Mtg.Step.MAIN1)


func after_each() -> void:
	g = null


func referee() -> SgPracticeMatch:
	var duel := SgPracticeMatch.new(42)
	duel.game = g
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())
	g.interactive_choices = true
	duel.view(0)
	return duel


static func _artifact_card(card: CardInstance) -> bool:
	return card.data.is_type(Mtg.CardType.ARTIFACT)


static func _metalworker() -> CardData:
	return CardData.new("Test Metalworker", "{3}", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE).pt(1, 2) \
		.mana(ManaAbility.new(Mtg.ManaColor.C, 0).with_reveal_from_hand(_artifact_card, "artifact", 2)) \
		.oracle("{T}: Reveal any number of artifact cards in your hand. Add {C}{C} for each card revealed this way.")


static func _host_tapped(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	var land: CardInstance = e.data.get("instance")
	return land != null and land.id == s.attached_to


static func _fertile() -> CardData:
	var bonus := TriggeredAbility.new(Mtg.EventType.TAPPED_FOR_MANA, _fertile_mana,
		"Whenever enchanted land is tapped for mana, its controller adds an additional one mana of any color.",
		_host_tapped).as_mana_trigger()
	bonus.mana_bonus_subtype = ManaPlanner.BONUS_ENCHANTED_LAND
	bonus.mana_bonus_color = ManaPlanner.BONUS_ANY_COLOR
	bonus.mana_bonus_amount = 1
	return CardData.new("Test Fertile", "{1}{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land)) \
		.triggered(bonus).oracle("Enchant land")


static func _is_land(inst: CardInstance) -> bool:
	return inst.is_land()


static func _fertile_mana(g: MtgGame, s: CardInstance, e: GameEvent) -> void:
	var pid := int(e.data.get("controller", -1))
	var color := int((e.data.get("bonus_colors", {}) as Dictionary).get(s.id, Mtg.ManaColor.G))
	g.players[pid].mana_pool.add(color, 1)


static func _two_type_land() -> CardData:
	return CardData.new("Test Confluence", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).and_also(Mtg.ManaColor.U)).oracle("{T}: Add {W}{U}.")


static func _matrix() -> CardData:
	return CardData.new("Test Matrix", "{3}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(_restrict, "Storage Matrix's text.")).oracle("")


static func _restrict(g: MtgGame, s: CardInstance) -> void:
	if not s.tapped:
		g.restrict_untap_to_chosen_kind(s)


static func _damping() -> CardData:
	return CardData.new("Test Damping Engine", "{4}", Mtg.CardType.ARTIFACT) \
		.bans_playing(_ban).ignorable_by_sacrifice("permanent", Callable(), _most) \
		.oracle("Damping Engine's text.")


static func _most(g: MtgGame, _s: CardInstance) -> int:
	var a := g.players[0].battlefield.size()
	var b := g.players[1].battlefield.size()
	return 0 if a > b else (1 if b > a else -1)


static func _ban(g: MtgGame, pid: int, data: CardData, s: CardInstance) -> bool:
	return _most(g, s) == pid and not g.effect_ignored_by(s, pid) and data.is_land()


# ------------------------------------------------------------- Metalworker --

func test_metalworkers_questions_at_both_front_ends() -> void:
	var duel := referee()
	var worker := put_synthetic(0, _metalworker())
	var ring := give_hand(0, "Sol Ring")
	var thopter := give_hand(0, "Ornithopter")
	assert_ok(duel.act(0, {"op": "mana", "card": duel._handle(0, worker), "index": 0}))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked)
	assert_eq(DuelScreen.choice_options(asked), ["0", "1", "2"], "the local overlay's lines")
	var view: Dictionary = duel.actions.choice_view(0)
	assert_eq(view.get("options"), ["0", "1", "2"], "the networked seat's lines")
	assert_true(bool(view.get("cancel")), "the tap may be withdrawn")
	assert_eq(duel.actions.choice_view(1), {}, "never the other seat")
	assert_ok(duel.act(0, {"op": "choice", "picks": [1]}))
	asked = g.awaiting_choice
	assert_not_null(asked, "which card")
	assert_eq(DuelScreen.choice_options(asked).size(), 2)
	view = duel.actions.choice_view(0)
	var lines: Array = view.get("options")
	assert_eq(lines.size(), 2)
	var pick := -1
	for i in lines.size():
		if String(lines[i]).begins_with("Ornithopter"): pick = i
	assert_ne(pick, -1, "the hand card is named on the seat's own screen")
	assert_ok(duel.act(0, {"op": "choice", "picks": [pick]}))
	assert_null(g.awaiting_choice)
	assert_true(worker.tapped)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.C), 2)
	assert_eq(ring.zone, Mtg.Zone.HAND)
	assert_eq(thopter.zone, Mtg.Zone.HAND, "revealed, not moved")
	var shown: Array = duel.actions.information[1]
	assert_false(shown.is_empty(), "the opponent was shown the reveal")
	assert_true((shown[-1].cards as Array).has("Ornithopter"))
	assert_false((shown[-1].cards as Array).has("Sol Ring"), "only the card revealed")


# --------------------------------------------- a mana trigger's colour --

func test_a_mana_triggers_colour_at_both_front_ends() -> void:
	var duel := referee()
	var forest := put_battlefield(0, "Forest")
	var aura := give_synthetic(0, _fertile())
	g.attach_aura_from_anywhere(aura, forest, 0)
	g.recalculate()
	assert_ok(duel.act(0, {"op": "tap", "card": duel._handle(0, forest)}))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked)
	assert_eq(DuelScreen.choice_options(asked), ["White", "Blue", "Black", "Red", "Green"])
	assert_eq(DuelScreen.choice_question(asked), "Test Fertile: What kind of mana?")
	var view: Dictionary = duel.actions.choice_view(0)
	assert_eq(view.get("options"), ["White", "Blue", "Black", "Red", "Green"])
	assert_eq(String(view.get("prompt")), "Test Fertile: What kind of mana?")
	assert_ok(duel.act(0, {"op": "choice", "picks": [3]}))
	assert_null(g.awaiting_choice)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.R), 1)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)


func test_mana_flares_type_at_both_front_ends() -> void:
	var duel := referee()
	put_battlefield(1, "Mana Flare")
	var land := put_synthetic(0, _two_type_land())
	assert_ok(duel.act(0, {"op": "tap", "card": duel._handle(0, land)}))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked)
	assert_eq(DuelScreen.choice_options(asked), ["White", "Blue"])
	assert_eq(duel.actions.choice_view(0).get("options"), ["White", "Blue"])
	assert_ok(duel.act(0, {"op": "choice", "picks": [0]}))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.W), 2)
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


# ----------------------------------------------------------- Storage Matrix --

func test_storage_matrixs_kind_at_both_front_ends() -> void:
	var duel := referee()
	put_synthetic(1, _matrix())
	var forest := put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	forest.tapped = true
	bears.tapped = true
	g.set_agent(1, DecisionAgent.new())   # the other seat plays its own turn
	var guard := 0
	while g.awaiting_choice == null and not g.game_over and guard < 800:
		_advance_once()
		guard += 1
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "seat 0's untap step holds")
	assert_eq(asked.pid, 0)
	assert_eq(DuelScreen.choice_options(asked), ["Artifact", "Creature", "Land"])
	var view: Dictionary = duel.actions.choice_view(0)
	assert_eq(view.get("options"), ["Artifact", "Creature", "Land"])
	assert_false(bool(view.get("cancel")), "a turn-based question must be answered")
	assert_ok(duel.act(0, {"op": "choice", "picks": [1]}))
	assert_null(g.awaiting_choice)
	assert_false(bears.tapped)
	assert_true(forest.tapped)


# ----------------------------------------------------------- Damping Engine --

func test_damping_engines_ignore_at_both_front_ends() -> void:
	var duel := referee()
	var engine := put_synthetic(1, _damping())
	put_battlefield(0, "Forest")
	var bears := put_battlefield(0, "Grizzly Bears")
	g.recalculate()
	var labels: Array = duel.actions.specials(0)
	var at := labels.find("Sacrifice a permanent: ignore Test Damping Engine this turn")
	assert_ne(at, -1, "the networked seat is offered the special action")
	assert_eq(duel.actions.specials(1).find("Sacrifice a permanent: ignore Test Damping Engine this turn"), -1)
	assert_ok(duel.act(0, {"op": "special", "index": at}))
	var asked: PlayerChoice = g.awaiting_choice
	assert_not_null(asked, "held on the sacrifice")
	var lines: Array = duel.actions.choice_view(0).get("options")
	assert_eq(lines.size(), 2)
	var pick := -1
	for i in lines.size():
		if String(lines[i]).begins_with("Grizzly Bears"): pick = i
	assert_ne(pick, -1)
	assert_ok(duel.act(0, {"op": "choice", "picks": [pick]}))
	assert_eq(bears.zone, Mtg.Zone.GRAVEYARD)
	assert_true(g.effect_ignored_by(engine, 0))
