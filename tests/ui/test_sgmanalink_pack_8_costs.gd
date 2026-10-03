extends GameTest
## PACK 8 COSTS AT AN SGMANALINK TABLE — the Mirage block's new ways to PAY,
## played through the referee (`SgPracticeMatch`, `SgDuelActions`) and the
## real networked screen (`SgDuelView`), with the same synthetic shapes the
## local pins use (tests/ui/test_pack_8_choice_flows.gd) and a few printed
## Pack 8 cards where the client reads the card's own definition.
##
##  * ALTERNATIVE payment rows (Fireblast, Spinning Darkness) are payment
##    "modes": the castable light must ask the row's OBJECT costs, and a
##    free row must not hold every window as "floating" mana does (the
##    local screen's `_has_affordable_fast_effect` rule).
##  * OBJECT costs (a returned Forest, a card exiled from hand for mana, the
##    top of a graveyard) are held questions the referee asks the seat.
##  * An X that counts OBJECTS (Haunting Misery) costs no mana: the X
##    window's bound is the objects (`AdditionalObjectCosts.max_x`), never
##    a mana budget, and a double-click never decides it.
##  * Divided prevention (Remedy) is a divided slot like Fireball's.
##  * Kaervek's Torch's "{2} more" for a spell that targets it: the light
##    asks the floor (`targeting_surcharge_floor`), and once the target is
##    named the referee's own payment and auto-tap include it.

const OC := preload("res://engine/additional_object_costs.gd")

var referee: SgPracticeMatch
var revision := 1
var commands: Array = []
var refusals: Array = []


func before_each() -> void:
	CardPacks.set_enabled("pack-8", true)
	super.before_each()
	referee = SgPracticeMatch.new(42)
	referee.game = g
	revision = 1
	commands.clear()
	refusals.clear()
	g.interactive_choices = true
	g.set_agent(0, HumanAgent.new())
	g.set_agent(1, HumanAgent.new())


func after_each() -> void:
	referee = null
	CardPacks.set_enabled("pack-8", false)


# ---------------------------------------------------------------- fixture --

func _room(seat := 0) -> Dictionary:
	return {"id": "r1", "name": "Pack eight", "seat": seat,
		"names": ["Azure Fox", "Amber Owl"], "revision": revision,
		"ready": [true, true], "connected": [true, true], "game": referee.view(seat),
		"deck_names": referee.deck_names.duplicate(), "deck": {}}


func _screen(seat := 0) -> SgDuelView:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(960, 600)
	add_child_autofree(viewport)
	var screen := SgDuelView.new()
	screen.stops.from_masks(PackedInt32Array([255, 255, 255, 255]))
	viewport.add_child(screen)
	screen.action_requested.connect(_act.bind(screen, seat))
	screen.present(_room(seat), true, false)
	return screen


func _act(action: Dictionary, screen: SgDuelView, seat: int) -> void:
	commands.append(action.duplicate(true))
	var error := referee.act(seat, action)
	if not error.is_empty():
		refusals.append(error)
		screen.show_notice(error)
	else: revision += 1
	screen.present.call_deferred(_room(seat), true, false)


func _pump() -> void:
	for i in 8: await get_tree().process_frame


func _local(screen: SgDuelView, card: CardInstance) -> CardInstance:
	return screen.game.find_instance(screen.projection.local_id(referee._handle(int(screen._room.seat), card)))


func _row(view: Dictionary, card: CardInstance, viewer := 0) -> Dictionary:
	var handle := referee._handle(viewer, card)
	for row in view.presentation.cards:
		if row.id == handle: return row
	return {}


## Answer every question the referee holds for seat 0 with its first line,
## through the networked screen's own overlay handler.
func _answer_first_lines(screen: SgDuelView, most := 10) -> int:
	var answered := 0
	while g.awaiting_choice != null and g.awaiting_choice.pid == 0 and answered < most:
		screen._on_choice_option(0)
		await _pump()
		answered += 1
	return answered


static func _is_land(i: CardInstance) -> bool:
	return i.is_land()

static func _is_forest(i: CardInstance) -> bool:
	return i.has_subtype("forest")

static func _ranger() -> CardData:
	return CardData.new("Test Ranger", "{G}", Mtg.CardType.CREATURE).pt(1, 1) \
		.activated(ActivatedAbility.new("", false, [PumpEffect.new(1, 1)],
			"Return a Forest you control to its owner's hand: Target creature gets +1/+1 until end of turn.")
			.with_object_cost(OC.returning("a Forest you control", _is_forest)))


static func _bloom() -> CardData:
	return CardData.new("Test Bloom", "{3}{B}{G}", Mtg.CardType.ENCHANTMENT) \
		.mana(ManaAbility.new(Mtg.ManaColor.B, 2).without_tap()
			.with_object_cost(OC.exiling(Mtg.Zone.HAND, "a card")))


static func _scavenger() -> CardData:
	return CardData.new("Test Scavenger", "{B}", Mtg.CardType.CREATURE).pt(1, 1) \
		.activated(ActivatedAbility.new("", false, [PumpEffect.new(1, 1).self_buff()],
			"Exile the top card of your graveyard: This creature gets +1/+1 until end of turn.")
			.with_object_cost(OC.exiling_top("card")))


static func _remedy() -> CardData:
	return CardData.new("Test Remedy", "{W}", Mtg.CardType.INSTANT) \
		.spell(PreventDamageEffect.new(0).divided(5))


static func _bear(card_name := "Test Bear") -> CardData:
	return CardData.new(card_name, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2)


func _to_graveyard(pid: int, data: CardData) -> CardInstance:
	var inst := give_synthetic(pid, data)
	g.card_to_graveyard_from_anywhere(inst)
	return inst


# ============================================ alternative payment rows --

func test_fireblast_lights_only_with_two_mountains_and_is_no_floating_mana() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var blast := give_hand(0, "Fireblast")
	var view := referee.view(0)
	assert_false(_row(view, blast).castable, "no mana and no Mountains: nothing to pay with")
	assert_false(view.presentation.respond)
	for i in 2: put_battlefield(0, "Mountain")
	view = referee.view(0)
	assert_true(_row(view, blast).castable, "two Mountains pay the alternative row")
	assert_true(view.presentation.respond, "an instant the seat can pay and aim")
	assert_false(view.presentation.floating,
		"a free row is no floating mana: it would hold every window (local _has_affordable_fast_effect)")


func test_fireblast_is_cast_for_two_mountains_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var mountains: Array = []
	for i in 3: mountains.append(put_battlefield(0, "Mountain"))
	var blast := give_hand(0, "Fireblast")
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, blast))
	assert_not_null(screen._mode_overlay, "the two payment rows are offered")
	screen._on_mode_chosen(1)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_life_clicked(1)
	await _pump()
	assert_eq(refusals, [])
	assert_not_null(g.awaiting_choice, "which Mountains is the seat's to say")
	assert_true(screen.projection.view.choice.get("cancel", false), "a cost may be backed out of")
	var answered: int = await _answer_first_lines(screen)
	assert_gte(answered, 1)
	assert_eq(refusals, [])
	assert_eq(g.stack.size(), 1, "cast for two Mountains")
	var gone := mountains.filter(func(m: CardInstance) -> bool: return m.zone == Mtg.Zone.GRAVEYARD)
	assert_eq(gone.size(), 2)
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided for the player")


func test_spinning_darkness_row_takes_the_top_three_unasked() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var corpses: Array = []
	for i in 3:
		corpses.append(_to_graveyard(0, CardData.new("Test Shade", "{B}", Mtg.CardType.CREATURE).pt(1, 1)))
	var victim := put_synthetic(1, _bear("Their Bear"))
	var darkness := give_hand(0, "Spinning Darkness")
	assert_true(_row(referee.view(0), darkness).castable)
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, darkness))
	screen._on_mode_chosen(1)
	await _pump()
	screen._on_card_clicked(_local(screen, victim))
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice, "positional: nobody is asked which")
	assert_eq(g.stack.size(), 1)
	for c in corpses:
		assert_eq(c.zone, Mtg.Zone.EXILE)


# ========================================================= object costs --

func test_a_returned_forest_is_chosen_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var ranger := put_synthetic(0, _ranger())
	var forest := put_battlefield(0, "Forest")
	var screen := _screen()
	await _pump()
	screen._click_permanent(_local(screen, ranger))
	assert_eq(screen._ability_menu.item_count, 1)
	screen._on_ability_chosen(0)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_card_clicked(_local(screen, ranger))
	await _pump()
	assert_eq(refusals, [])
	assert_not_null(g.awaiting_choice, "which Forest is the seat's to say")
	await _answer_first_lines(screen)
	assert_eq(refusals, [])
	assert_eq(forest.zone, Mtg.Zone.HAND, "returned as the cost")
	assert_eq(g.stack.size(), 1)


func test_a_card_exiled_from_hand_pays_for_mana_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bloom := put_synthetic(0, _bloom())
	var fodder := give_synthetic(0, _bear("Test Fodder"))
	var screen := _screen()
	await _pump()
	screen._click_permanent(_local(screen, bloom))
	await _pump()
	assert_eq(refusals, [])
	assert_not_null(g.awaiting_choice, "which card goes is the seat's to say")
	if g.awaiting_choice != null:
		assert_eq(screen.projection.view.choice.options, ["Test Fodder"])
	await _answer_first_lines(screen)
	assert_eq(refusals, [])
	assert_eq(fodder.zone, Mtg.Zone.EXILE)
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.B), 2)


func test_the_top_of_the_graveyard_is_paid_without_a_question() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var scavenger := put_synthetic(0, _scavenger())
	var top := _to_graveyard(0, _bear("Test Corpse"))
	var screen := _screen()
	await _pump()
	screen._click_permanent(_local(screen, scavenger))
	screen._on_ability_chosen(0)
	await _pump()
	assert_eq(refusals, [])
	assert_null(g.awaiting_choice)
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(g.stack.size(), 1)


func test_an_object_counted_x_is_bounded_by_the_objects_and_asked() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	for i in 2: _to_graveyard(0, _bear("Test Corpse %d" % i))
	_to_graveyard(0, CardData.new("Test Charm", "{G}", Mtg.CardType.INSTANT))
	var misery := give_hand(0, "Haunting Misery")
	add_mana(0, Mtg.ManaColor.B, 3)
	var view := referee.view(0)
	var budget := -1
	for ability in _row(view, misery).abilities:
		if ability.kind == "spell": budget = int(ability.budget)
	assert_eq(budget, 2, "X counts creature cards, not mana")
	assert_refused(referee.act(0, {"op": "autoprepare", "card": referee._handle(0, misery),
		"kind": "spell", "index": 0, "mode": 0, "excluded": [], "count": 1}), "Choose X")
	var screen := _screen()
	await _pump()
	var local := _local(screen, misery)
	screen._click_hand_card(local)
	assert_not_null(screen._x_dialog, "X is asked")
	if screen._x_dialog == null: return
	assert_eq(int(screen._x_spin.max_value), 2)
	assert_eq(int(screen._x_spin.value), 0, "never pre-filled with objects")
	screen._auto_cast(local)
	assert_not_null(screen._x_dialog, "a double-click never decides an object-counted X")
	screen._x_spin.value = 2
	screen._on_x_confirmed()
	await _pump()
	assert_eq(refusals, [])
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_life_clicked(1)
	await _pump()
	await _answer_first_lines(screen)
	assert_eq(refusals, [])
	assert_eq(g.stack.size(), 1, "cast with X = 2")
	resolve_stack()
	assert_eq(g.players[1].life, 18)


func test_kaervek_s_spite_sacrifices_and_discards_without_a_question() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var spite := give_hand(0, "Kaervek's Spite")
	give_synthetic(0, _bear("Test Fodder"))
	var bear := put_synthetic(0, _bear())
	add_mana(0, Mtg.ManaColor.B, 3)
	assert_ok(referee.act(0, {"op": "prepare", "card": referee._handle(0, spite),
		"kind": "spell", "index": 0, "x": 0, "mode": 0}))
	var slots: Array = referee.view(0).announcement.slots
	assert_eq(slots.size(), 1)
	var opponent := ""
	for candidate in slots[0].targets:
		if candidate.label == "Opponent": opponent = candidate.id
	assert_ok(referee.act(0, {"op": "submit", "targets": [[opponent, 0]]}))
	assert_null(g.awaiting_choice)
	assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(g.players[0].hand.size(), 0)
	resolve_stack()
	assert_eq(g.players[1].life, 15)


# ================================================== divided prevention --

func test_remedy_divides_five_points_over_the_network() -> void:
	advance_to_step(Mtg.Step.MAIN1)
	var bear := put_synthetic(0, _bear())
	var remedy := give_synthetic(0, _remedy())
	add_mana(0, Mtg.ManaColor.W)
	var screen := _screen()
	await _pump()
	screen._click_hand_card(_local(screen, remedy))
	await _pump()
	var slot: Dictionary = screen.projection.view.announcement.slots[0]
	assert_eq(int(slot.divided), 5)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	for i in 3: screen._on_card_clicked(_local(screen, bear))
	screen._on_life_clicked(0)
	screen._on_life_clicked(0)
	await _pump()
	assert_eq(refusals, [])
	assert_eq(g.stack.size(), 1, "the fifth point submits the cast")
	var shares := {}
	for ref in g.stack.back().targets:
		shares["me" if ref.is_player else ref.instance_id] = ref.amount
	assert_eq(shares, {bear.id: 3, "me": 2})
	resolve_stack()
	assert_eq(bear.prevention, 3)
	assert_eq(g.players[0].damage_prevention, 2)


# ================================================== Kaervek's Torch --

func _torch_on_the_chain(islands: int) -> Array:
	for i in islands: put_battlefield(0, "Island")
	var counter := give_hand(0, "Counterspell")
	var torch := give_hand(1, "Kaervek's Torch")
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	g.players[1].mana_pool.add(Mtg.ManaColor.R, 2)
	assert_ok(g.cast_spell(1, torch, [TargetRef.player(0)], 1))
	g.priority_player = 0
	g._probing = false
	return [counter, torch]


func test_two_islands_do_not_light_a_counterspell_aimed_at_the_torch() -> void:
	var cast := _torch_on_the_chain(2)
	var view := referee.view(0)
	assert_false(_row(view, cast[0]).castable, "{U}{U} cannot pay {2}{U}{U}")
	assert_false(view.presentation.respond, "and it is no response to wait for")


func test_four_islands_light_it_and_the_network_cast_pays_the_extra_two() -> void:
	var cast := _torch_on_the_chain(4)
	var counter: CardInstance = cast[0]
	var torch: CardInstance = cast[1]
	var view := referee.view(0)
	assert_true(_row(view, counter).castable)
	assert_true(view.presentation.respond)
	var screen := _screen()
	await _pump()
	var local := _local(screen, counter)
	screen._click_hand_card(local)
	await _pump()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "the lone enemy spell is the target; mana is owed")
	assert_string_contains(screen._prompt_label.text, "{2} more for its target")
	screen._auto_cast(local)
	await _pump()
	await _pump()
	assert_eq(g.stack.size(), 2, "Counterspell on the chain above the Torch")
	assert_eq(g.stack.back().card, counter)
	assert_eq(g.stack.back().targets[0].instance_id, torch.id)
	var tapped := g.players[0].battlefield.filter(func(c: CardInstance) -> bool: return c.tapped)
	assert_eq(tapped.size(), 4, "the double-click tapped all four Islands")
