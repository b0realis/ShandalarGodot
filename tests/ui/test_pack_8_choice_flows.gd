extends GutTest
## EVERY NEW PACK 8 CHOICE, COMPLETED BY A HUMAN SEAT ON THE DUEL SCREEN.
##
## The Mirage block's engine packages (E3, E5, E6, E9, E1) added questions a
## human must answer: a trigger with two target SLOTS (Goblin Grenadiers),
## prevention DIVIDED among targets (Remedy), ALTERNATIVE cost rows chosen
## at cast (Fireblast, Spinning Darkness), HELD cost choices — a permanent
## returned to hand (Quirion Ranger), a card exiled from hand for mana
## (Cadaverous Bloom), the top of a graveyard (Alms), an X that counts
## objects (Haunting Misery) — the colour chosen as an Aura enters (Ward of
## Lights), a LIFE tax on blocking (Heat Wave) and a "can't phase out"
## activation paid in life (Spatial Binding). Each is driven here through
## the screen's own handlers on synthetic cards built with the very
## builders the card files use, so the flow is pinned whatever state the
## card waves are in; where the rules let the player back out, the test
## backs out too and checks nothing was paid.
##
## The choice overlay is not built headless (DuelScreen._open_choice_overlay),
## so a held question is answered the way the overlay answers it — through
## `DuelScreen._on_choice_option` / `_withdraw_choice` — and its lines are
## read through `DuelScreen.choice_options`, which is what it would show.

const OC := preload("res://engine/additional_object_costs.gd")

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ------------------------------------------------------------- synthetics --

## A one-line effect for the cards below (the card files' own `Action`).
class Act extends EffectBase:
	var callback: Callable
	var line: String
	func _init(cb: Callable, description: String, spec: TargetSpec = null) -> void:
		callback = cb
		line = description
		target_spec = spec
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, x_value := 0) -> void:
		callback.call(game, source, controller, target, x_value)
	func describe() -> String:
		return line


static func _is_self(_g: MtgGame, s: CardInstance, e: GameEvent) -> bool:
	return e.data.get("instance") == s

static func _is_land(i: CardInstance) -> bool:
	return i.is_land()

static func _is_forest(i: CardInstance) -> bool:
	return i.has_subtype("forest")

static func _is_mountain(i: CardInstance) -> bool:
	return i.has_subtype("mountain")

static func _is_black(c: CardInstance) -> bool:
	return c.has_color(Mtg.ManaColor.B)

static func _is_creature_card(c: CardInstance) -> bool:
	return c.data.is_type(Mtg.CardType.CREATURE)

static func _enemy_first(_g: MtgGame, source: CardInstance, a: TargetRef, b: TargetRef) -> bool:
	return a.instance_id != source.id and b.instance_id == source.id


static func _grenade(game: MtgGame, _source: CardInstance, _e: GameEvent) -> void:
	for slot in 2:
		var ref := game.current_trigger_target(slot)
		if ref != null:
			game.destroy(game.find_instance(ref.instance_id))


## Goblin Grenadiers' shape on an ETB: two target slots.
static func _grenadier() -> CardData:
	return CardData.new("Test Grenadier", "{R}", Mtg.CardType.CREATURE).pt(2, 2) \
		.triggered(TriggeredAbility.new(Mtg.EventType.ENTERS_BATTLEFIELD, _grenade,
			"When this creature enters, destroy target creature and target land.", _is_self)
			.targeting(TargetSpec.creature(), _enemy_first, "Select target creature.")
			.and_targeting(TargetSpec.new(TargetSpec.Kind.PERMANENT, "target land", _is_land),
				_enemy_first, "Select target land."))


static func _remedy() -> CardData:
	return CardData.new("Test Remedy", "{W}", Mtg.CardType.INSTANT) \
		.spell(PreventDamageEffect.new(0).divided(5))


static func _fireblast() -> CardData:
	return CardData.new("Test Fireblast", "{4}{R}{R}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(4).any_target()) \
		.with_alternative_cost("Sacrifice two Mountains",
			{"object_costs": [OC.sacrificing("a Mountain", _is_mountain, 2)]})


static func _spinning_darkness() -> CardData:
	return CardData.new("Test Darkness", "{4}{B}{B}", Mtg.CardType.INSTANT) \
		.spell(DamageEffect.new(3).target_creature()) \
		.with_alternative_cost("Exile the top three black cards of your graveyard",
			{"object_costs": [OC.exiling_top("black card", _is_black, 3)]})


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


static func _misery() -> CardData:
	return CardData.new("Test Misery", "{1}{B}", Mtg.CardType.SORCERY) \
		.spell(DamageEffect.new(0).x_damage().any_target()) \
		.with_object_cost(OC.times_x(OC.exiling(Mtg.Zone.GRAVEYARD, "a creature card",
			_is_creature_card)))


static func _choose_ward(g: MtgGame, s: CardInstance, pid: int) -> void:
	g._rec(s, &"memory")
	s.memory["ward_color"] = g.agents[pid].choose_color(g, pid,
		"Test Ward: choose a color", Mtg.ManaColor.R)


static func _ward() -> CardData:
	return CardData.new("Test Ward", "{W}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.grants_host_protection_from_chosen("ward_color",
			"Enchanted creature has protection from the chosen color.") \
		.as_it_enters(_choose_ward)


static func _nonblue(blocker: CardInstance) -> bool:
	return not blocker.has_color(Mtg.ManaColor.U)


static func _heat(game: MtgGame, source: CardInstance) -> void:
	for inst in game.players[source.controller_id].battlefield:
		if not inst.is_creature():
			continue
		inst.cur_block_restrictions.append({"desc": "nonblue creatures", "filter": _nonblue})
		CombatState.add_block_life_tax(inst, source, 1, _nonblue, "pay 1 life")


static func _heat_wave() -> CardData:
	return CardData.new("Test Heat Wave", "{2}{R}", Mtg.CardType.ENCHANTMENT) \
		.static_ability(StaticAbility.new(_heat, "Blue creatures can't block creatures you control. Nonblue creatures can't block creatures you control unless their controller pays 1 life for each blocking creature they control."))


static func _bind(game: MtgGame, source: CardInstance, controller: int,
		target: TargetRef, _x: int) -> void:
	game.forbid_phasing_out(game.find_instance(target.instance_id), controller, source)


static func _binding() -> CardData:
	return CardData.new("Test Binding", "{U}{B}", Mtg.CardType.ENCHANTMENT) \
		.activated(ActivatedAbility.new("", false,
			[Act.new(_bind, "Until your next upkeep, target permanent can't phase out.",
				TargetSpec.new(TargetSpec.Kind.PERMANENT, "target permanent"))],
			"Pay 1 life: Until your next upkeep, target permanent can't phase out.")
			.with_life_cost(1))


# ---------------------------------------------------------------- fixture --

func _window(active: int, step: int) -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = active
	g._enter_step(Mtg.STEP_ORDER.find(step))
	g.awaiting_attackers = false
	g.awaiting_blockers = false
	g.priority_player = 0
	g._passes = 0 if active == 0 else 1
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


## A Stop where the duel stands: the player is acting here on purpose.
func _stop_here() -> void:
	var here: Array = screen._phase_key()
	screen.stops.set_marked(here[0], here[1], here[2], true)


func _make(pid: int, data: CardData, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	match zone:
		Mtg.Zone.HAND:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
		Mtg.Zone.GRAVEYARD:
			inst.zone = Mtg.Zone.HAND
			g.players[pid].hand.append(inst)
			g.card_to_graveyard_from_anywhere(inst)
		Mtg.Zone.BATTLEFIELD:
			g._put_on_battlefield(inst, pid)
			inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _land(pid: int, card_name: String) -> CardInstance:
	return _make(pid, CardRegistry.get_card(card_name), Mtg.Zone.BATTLEFIELD)


## Pass (Done) for the human and let the AI act, until [param until].
func _drive(steps: int, until: Callable) -> void:
	for _i in steps:
		if screen.game.game_over or bool(until.call()):
			return
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(screen.game)
		elif screen.game.priority_player == 0 and screen.mode == DuelScreen.Mode.NORMAL \
				and screen.game.awaiting_choice == null:
			screen._on_pass()
		else:
			screen._refresh()


## The overlay line whose answer is [param inst] (a permanent, by id) or,
## for a card in a hidden zone or a graveyard, the line with its name.
func _line_for(choice: PlayerChoice, inst: CardInstance) -> int:
	var lines := DuelScreen.choice_card_lines(choice)
	for i in lines.size():
		var answer: Variant = lines[i]["answer"]
		if (answer is int and int(answer) == inst.id) \
				or (answer is String and String(answer) == inst.data.card_name):
			return i
	return -1


## Answer every held COST question with its first line.
func _answer_costs_with_first_lines() -> int:
	var answered := 0
	var g: MtgGame = screen.game
	while g.awaiting_choice != null and g.awaiting_choice.is_cost and answered < 10:
		screen._on_choice_option(0)
		answered += 1
	return answered


# ============================================ a trigger with two targets --

func test_a_two_slot_trigger_is_answered_slot_by_slot() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var their_bear := _make(1, CardData.new("Their Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.BATTLEFIELD)
	var their_land := _land(1, "Forest")
	var my_land := _land(0, "Mountain")
	var grenadier := _make(0, _grenadier(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._click_hand_card(grenadier)
	assert_eq(g.stack.size(), 1, "cast")
	_drive(20, func() -> bool: return g.awaiting_choice != null)
	var first: PlayerChoice = g.awaiting_choice
	assert_not_null(first, "the trigger's first slot is put to the player")
	if first == null:
		return
	assert_eq(first.pid, 0)
	assert_eq(DuelScreen.choice_question(first), "Select target creature.")
	assert_false(screen._choice_withdrawable(), "a trigger's targets must be named")
	var pick := _line_for(first, their_bear)
	assert_gte(pick, 0, "their creature is a line")
	screen._on_choice_option(pick)
	var second: PlayerChoice = g.awaiting_choice
	assert_not_null(second, "then the second slot")
	if second == null:
		return
	assert_eq(DuelScreen.choice_question(second), "Select target land.")
	assert_gte(_line_for(second, my_land), 0, "every legal land is offered")
	screen._on_choice_option(_line_for(second, their_land))
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1, "the trigger is on the chain")
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_eq(their_bear.zone, Mtg.Zone.GRAVEYARD, "slot 1's pick")
	assert_eq(their_land.zone, Mtg.Zone.GRAVEYARD, "slot 2's pick")
	assert_eq(my_land.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided for the player")


# ================================================ divided prevention --

func test_remedy_divides_five_points_one_click_each_and_can_be_cancelled() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var bear := _make(0, CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.BATTLEFIELD)
	var remedy := _make(0, _remedy(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	screen._click_hand_card(remedy)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	assert_string_contains(screen._prompt_label.text, "(1st of 5)")
	screen._on_card_clicked(bear)
	screen._on_card_clicked(bear)
	assert_string_contains(screen._prompt_label.text, "(3rd of 5)")
	# Cancel is legal mid-division: nothing is cast, nothing is paid.
	screen._on_cancel()
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_true(g.stack.is_empty())
	assert_eq(remedy.zone, Mtg.Zone.HAND)
	assert_eq(g.players[0].mana_pool.total(), 1)
	# Again, to the end: three on the bear, two on me.
	screen._click_hand_card(remedy)
	for i in 3:
		screen._on_card_clicked(bear)
	screen._on_life_clicked(0)
	screen._on_life_clicked(0)
	assert_eq(g.stack.size(), 1, "the fifth point submits the cast")
	var shares := {}
	for ref in g.stack.back().targets:
		shares["me" if ref.is_player else ref.instance_id] = ref.amount
	assert_eq(shares, {bear.id: 3, "me": 2})
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_eq(bear.prevention, 3)
	assert_eq(g.players[0].damage_prevention, 2)


# =========================================== alternative cost rows --

func test_fireblast_row_holds_the_sacrifice_choice_and_cancels_unpaid() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var mountains: Array[CardInstance] = []
	for i in 3:
		mountains.append(_land(0, "Mountain"))
	var blast := _make(0, _fireblast(), Mtg.Zone.HAND)
	screen._click_hand_card(blast)
	assert_not_null(screen._mode_overlay, "the two payment rows are offered at cast")
	assert_eq(blast.data.modes.size(), 2)
	assert_eq(String(blast.data.modes[1]["label"]), "Sacrifice two Mountains")
	screen._on_mode_chosen(1)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_life_clicked(1)
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "which Mountains is the player's to say")
	if held == null:
		return
	assert_true(held.is_cost)
	assert_true(screen._choice_withdrawable(), "a cost question can be backed out of")
	screen._withdraw_choice()
	assert_null(g.awaiting_choice)
	assert_true(g.stack.is_empty(), "withdrawn: nothing cast")
	assert_eq(blast.zone, Mtg.Zone.HAND)
	for m in mountains:
		assert_eq(m.zone, Mtg.Zone.BATTLEFIELD, "and nothing paid")
	# Again, answered.
	screen._click_hand_card(blast)
	screen._on_mode_chosen(1)
	screen._on_life_clicked(1)
	var answers := _answer_costs_with_first_lines()
	assert_gte(answers, 1)
	assert_eq(g.stack.size(), 1, "cast for two Mountains")
	var gone := 0
	for m in mountains:
		if m.zone == Mtg.Zone.GRAVEYARD:
			gone += 1
	assert_eq(gone, 2)
	assert_eq(g.unanswered_choices.size(), 0)


func test_spinning_darkness_row_takes_the_top_three_black_cards_unasked() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var black := CardData.new("Test Shade", "{B}", Mtg.CardType.CREATURE).pt(1, 1)
	var corpses: Array[CardInstance] = []
	for i in 3:
		corpses.append(_make(0, black, Mtg.Zone.GRAVEYARD))
	_make(0, CardData.new("Test Elf", "{G}", Mtg.CardType.CREATURE).pt(1, 1), Mtg.Zone.GRAVEYARD)
	var victim := _make(1, CardData.new("Their Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.BATTLEFIELD)
	var darkness := _make(0, _spinning_darkness(), Mtg.Zone.HAND)
	screen._click_hand_card(darkness)
	screen._on_mode_chosen(1)
	screen._on_card_clicked(victim)
	assert_null(g.awaiting_choice, "positional: nobody is asked which")
	assert_eq(g.stack.size(), 1)
	for c in corpses:
		assert_eq(c.zone, Mtg.Zone.EXILE)


# ================================================== held cost choices --

func test_a_returned_forest_is_chosen_and_the_activation_can_be_withdrawn() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var ranger := _make(0, _ranger(), Mtg.Zone.BATTLEFIELD)
	var forests := [_land(0, "Forest"), _land(0, "Forest")]
	screen._on_card_clicked(ranger)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_card_clicked(ranger)
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "two Forests: which one is asked")
	if held == null:
		return
	assert_eq(held.kind, PlayerChoice.Kind.CARD)
	assert_true(screen._choice_withdrawable())
	screen._withdraw_choice()
	assert_true(g.stack.is_empty())
	for f in forests:
		assert_eq(f.zone, Mtg.Zone.BATTLEFIELD)
	# Again, the second Forest.
	screen._on_card_clicked(ranger)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	screen._on_card_clicked(ranger)
	screen._on_choice_option(_line_for(g.awaiting_choice, forests[1]))
	assert_eq(g.stack.size(), 1)
	assert_eq(forests[1].zone, Mtg.Zone.HAND, "returned to its owner's hand")
	assert_eq(forests[0].zone, Mtg.Zone.BATTLEFIELD)


func test_a_card_exiled_from_hand_pays_for_mana_and_can_be_withdrawn() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var bloom := _make(0, _bloom(), Mtg.Zone.BATTLEFIELD)
	var a := _make(0, CardData.new("Card A", "{1}", Mtg.CardType.ARTIFACT), Mtg.Zone.HAND)
	var b := _make(0, CardData.new("Card B", "{2}", Mtg.CardType.ARTIFACT), Mtg.Zone.HAND)
	screen._on_card_clicked(bloom)
	if screen._ability_menu.visible:
		screen._ability_menu.hide()
		screen._on_ability_chosen(0)
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "which card to exile is asked")
	if held == null:
		return
	assert_true(screen._choice_withdrawable(), "a mana ability's cost can be withdrawn")
	screen._withdraw_choice()
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(a.zone, Mtg.Zone.HAND)
	assert_eq(b.zone, Mtg.Zone.HAND)
	screen._on_card_clicked(bloom)
	if screen._ability_menu.visible:
		screen._ability_menu.hide()
		screen._on_ability_chosen(0)
	screen._on_choice_option(_line_for(g.awaiting_choice, b))
	assert_eq(g.players[0].mana_pool.total_of(Mtg.ManaColor.B), 2, "{B}{B}")
	assert_eq(b.zone, Mtg.Zone.EXILE)
	assert_eq(a.zone, Mtg.Zone.HAND)


func test_the_top_of_the_graveyard_is_paid_without_a_question() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var scavenger := _make(0, _scavenger(), Mtg.Zone.BATTLEFIELD)
	var under := _make(0, CardData.new("Under", "{1}", Mtg.CardType.ARTIFACT), Mtg.Zone.GRAVEYARD)
	var top := _make(0, CardData.new("Top", "{1}", Mtg.CardType.ARTIFACT), Mtg.Zone.GRAVEYARD)
	screen._on_card_clicked(scavenger)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_null(g.awaiting_choice, "positional: no question")
	assert_eq(g.stack.size(), 1)
	assert_eq(top.zone, Mtg.Zone.EXILE)
	assert_eq(under.zone, Mtg.Zone.GRAVEYARD)


func test_an_object_counted_x_asks_how_many_then_which() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var dead: Array[CardInstance] = []
	for i in 3:
		dead.append(_make(0, CardData.new("Corpse %d" % i, "{1}", Mtg.CardType.CREATURE).pt(1, 1),
			Mtg.Zone.GRAVEYARD))
	var misery := _make(0, _misery(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.B, 2)
	screen._click_hand_card(misery)
	assert_not_null(screen._x_dialog, "X is announced first")
	if screen._x_dialog == null:
		return
	assert_eq(int(screen._x_spin.max_value), 3,
		"bounded by the creature cards to exile, not by the mana")
	assert_eq(int(screen._x_spin.value), 0)
	assert_eq(DuelScreen.object_x_prompt(misery.data.object_costs),
		"X — Exile a creature card for each:")
	screen._x_spin.value = 2
	screen._on_x_confirmed()
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_life_clicked(1)
	var asked := _answer_costs_with_first_lines()
	assert_gte(asked, 1, "which creature cards is the player's choice")
	assert_eq(g.stack.size(), 1)
	var exiled := 0
	for c in dead:
		if c.zone == Mtg.Zone.EXILE:
			exiled += 1
	assert_eq(exiled, 2, "X = 2 cards")
	var life: int = g.players[1].life
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_eq(g.players[1].life, life - 2)


# ================================================ the chosen colour --

func test_ward_of_lights_asks_its_colour_as_it_enters() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var bear := _make(0, CardData.new("Test Bear", "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2),
		Mtg.Zone.BATTLEFIELD)
	var ward := _make(0, _ward(), Mtg.Zone.HAND)
	g.players[0].mana_pool.add(Mtg.ManaColor.W, 1)
	screen._click_hand_card(ward)
	screen._on_card_clicked(bear)
	assert_eq(g.stack.size(), 1)
	_drive(20, func() -> bool: return g.awaiting_choice != null or g.stack.is_empty())
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "the resolution is held for the colour")
	if held == null:
		return
	assert_eq(held.kind, PlayerChoice.Kind.COLOR)
	assert_eq(DuelScreen.choice_options(held), ["White", "Blue", "Black", "Red", "Green"])
	assert_false(screen._choice_withdrawable(), "a resolution's question must be answered")
	screen._on_choice_option(2)
	assert_null(g.awaiting_choice)
	assert_eq(ward.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(int(ward.memory.get("ward_color", 0)), Mtg.ManaColor.B, "the colour clicked")
	assert_true(g.choice_log.back().answered_by_player)


# ==================================================== a life tax to block --

func _their_attack_into_blocks(heat_waves: int, my_life: int, blockers: int) -> Array:
	var g: MtgGame = screen.game
	for i in heat_waves:
		_make(1, _heat_wave(), Mtg.Zone.BATTLEFIELD)
	var ogre := _make(1, CardRegistry.get_card("Gray Ogre"), Mtg.Zone.BATTLEFIELD)
	var mine: Array[CardInstance] = []
	for i in blockers:
		mine.append(_make(0, CardData.new("Test Bear %d" % i, "{1}{G}", Mtg.CardType.CREATURE).pt(2, 2),
			Mtg.Zone.BATTLEFIELD))
	g._probing = true
	g.players[0].life = my_life
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_ATTACKERS))
	g.awaiting_attackers = true
	assert_eq(g.declare_attackers(1, [ogre.id]), "")
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.DECLARE_BLOCKERS))
	g.awaiting_blockers = true
	g._probing = false
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.BLOCKERS)
	return [ogre, mine]


func test_heat_waves_tax_is_shown_and_paid_with_the_declaration() -> void:
	var setup := _their_attack_into_blocks(1, 20, 1)
	var ogre: CardInstance = setup[0]
	var bear: CardInstance = setup[1][0]
	var g: MtgGame = screen.game
	screen._pick_block(bear)
	screen._pick_block(ogre)
	assert_string_contains(screen._prompt_label.text, "(Blocking costs 1 life.)")
	screen._on_confirm()
	assert_false(g.awaiting_blockers, "declared")
	assert_eq(g.combat.blocks.get(bear.id), ogre.id)
	assert_eq(g.players[0].life, 19, "one life for the one blocking creature")


func test_a_block_the_player_cannot_pay_for_is_refused_as_it_is_pencilled() -> void:
	var setup := _their_attack_into_blocks(1, 1, 2)
	var ogre: CardInstance = setup[0]
	var bears: Array = setup[1]
	var g: MtgGame = screen.game
	screen._pick_block(bears[0])
	screen._pick_block(ogre)
	assert_true(screen._block_map.has(bears[0].id), "1 life pays for one blocker")
	screen._pick_block(bears[1])
	screen._pick_block(ogre)
	assert_false(screen._block_map.has(bears[1].id), "a second would cost 2 life")
	assert_string_contains(screen._prompt_label.text,
		"not enough life for all blocking costs (2 life)")
	assert_eq(screen._selected_blocker, bears[1].id,
		"still in hand: the player may aim it elsewhere or put it down")
	screen._on_confirm()   # the first Done puts the held creature down
	if g.awaiting_blockers:
		screen._on_confirm()
	assert_false(g.awaiting_blockers)
	assert_eq(g.combat.blocks.get(bears[0].id), ogre.id)
	assert_false(g.combat.blocks.has(bears[1].id))
	assert_eq(g.players[0].life, 0, "1 life may pay 1 (CR 119.4)")


# ============================================== "can't phase out" --

func test_a_life_paid_binding_makes_a_phaser_stay_and_says_so() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var binding := _make(0, _binding(), Mtg.Zone.BATTLEFIELD)
	var raider := _make(0, CardData.new("Test Raider", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 3)
		.with_keywords([Mtg.Keyword.PHASING]), Mtg.Zone.BATTLEFIELD)
	screen._on_card_clicked(binding)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_card_clicked(raider)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].life, 19, "paid 1 life")
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_true(raider.cur_cant_phase_out)
	screen._refresh()
	var shown: MiniCard = null
	var walk: Array = [screen]
	while not walk.is_empty():
		var node: Node = walk.pop_back()
		if node is MiniCard and (node as MiniCard).instance == raider \
				and not node.is_queued_for_deletion():
			shown = node
		walk.append_array(node.get_children())
	assert_not_null(shown)
	if shown != null:
		assert_string_contains(shown.tooltip_text, "Can't phase out")
	assert_false(g.phase_out(raider), "and the engine agrees")


# ===================== the yellow name for an ALTERNATIVE payment row --
#
# The castable highlight asked the PRINTED mana cost only, so a Fireblast
# with two Mountains on the table — or a Force of Will with a blue card in
# hand — read as uncastable although the cast went through. It now asks
# whether ANY payment row could be paid (DuelScreen._payable_now).

static func _will() -> CardData:
	return CardData.new("Test Will", "{3}{U}{U}", Mtg.CardType.INSTANT) \
		.spell(DrawEffect.new(1)).with_pitch_cost(Mtg.ManaColor.U, 1)


func test_two_mountains_light_fireblast_and_none_do_not() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var blast := _make(0, _fireblast(), Mtg.Zone.HAND)
	assert_eq(screen._highlight_for(blast), MiniCard.Highlight.NONE,
		"no Mountains, no mana: nothing pays for it")
	_land(0, "Mountain")
	assert_eq(screen._highlight_for(blast), MiniCard.Highlight.NONE, "one Mountain is not two")
	_land(0, "Mountain")
	assert_false(g.could_afford(0, blast.data, {}, blast), "control: the printed {4}{R}{R} is out of reach")
	assert_eq(screen._highlight_for(blast), MiniCard.Highlight.OPTIONAL,
		"two Mountains pay the alternative row")
	# ...and on their turn it is a response the window waits for.
	_window(1, Mtg.Step.END)
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies())


func test_a_pitch_spell_lights_with_a_card_to_pitch() -> void:
	var g := _window(0, Mtg.Step.MAIN1)
	_stop_here()
	var will := _make(0, _will(), Mtg.Zone.HAND)
	assert_eq(screen._highlight_for(will), MiniCard.Highlight.NONE, "nothing blue to exile")
	_make(0, CardData.new("Test Drake", "{1}{U}", Mtg.CardType.CREATURE).pt(1, 1), Mtg.Zone.HAND)
	assert_eq(screen._highlight_for(will), MiniCard.Highlight.OPTIONAL,
		"a blue card and 1 life pay the pitch row")
	g.players[0].life = 0
	assert_eq(screen._highlight_for(will), MiniCard.Highlight.NONE, "no life to pay")
