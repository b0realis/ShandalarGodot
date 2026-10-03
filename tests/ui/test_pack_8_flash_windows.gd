extends GutTest
## FLASH FOR A HUMAN SEAT, AND THE CLEANUP STEP'S PRIORITY WINDOW (Pack 8).
##
## Until the Mirage block every spell a seat could cast at instant speed
## was an instant, so the duel screen's three "has a fast effect"
## predicates asked `is_type(INSTANT)` of the hand. Mirage brought FLASH
## (King Cheetah), the flash RIDER ("you may cast this spell as though it
## had flash … sacrifices it at the beginning of the next cleanup step" —
## Armor of Thorns) and a seat permission (Winding Canyons). The screen now
## asks the engine's own `MtgGame.casts_at_instant_speed` over
## `MtgGame.playable_cards`, so the automatic pass HOLDS a window a flash
## card could answer, Done stops for one, and the yellow name lights a
## flash card — and not the plain creature beside it — on the opponent's
## turn.
##
## The rider's sacrifice, and Bounty of the Hunt's counter removal, are now
## triggers on the stack in the CLEANUP step (CR 514.3a — the step holds
## priority only when one is put there). These drive the human seat
## through that window: the screen shows the step (the Discard Phase icon,
## slot 6), lets the player answer or pass, and the turn moves on with no
## stall.

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the opponent
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()
	screen.game.players[0].hand.clear()
	screen.game.players[1].hand.clear()


func after_each() -> void:
	CardPacks.set_enabled("pack-5", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


# ---------------------------------------------------------------- fixture --

static func _cheetah() -> CardData:
	return CardData.new("Test Cheetah", "{G}", Mtg.CardType.CREATURE).pt(3, 2) \
		.with_keywords([Mtg.Keyword.FLASH])


static func _bear() -> CardData:
	return CardData.new("Test Bear", "{G}", Mtg.CardType.CREATURE).pt(2, 2)


static func _pump(game: MtgGame, source: CardInstance) -> void:
	var host := game.find_instance(source.attached_to)
	if host != null and game.is_present(host):
		host.cur_power += 2
		host.cur_toughness += 2


## A Mirage flash-rider Aura (Armor of Thorns' shape).
static func _armor() -> CardData:
	return CardData.new("Test Armor", "{G}", Mtg.CardType.ENCHANTMENT) \
		.enchants(TargetSpec.creature()) \
		.static_ability(StaticAbility.new(_pump, "Enchanted creature gets +2/+2.")) \
		.with_flash_rider()


static func _giant_growth() -> CardData:
	return CardData.new("Test Growth", "{G}", Mtg.CardType.INSTANT) \
		.spell(PumpEffect.new(3, 3))


static func _is_creature(_g: MtgGame, inst: CardInstance) -> bool:
	return inst.is_creature()


func _put(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, pid)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _forest(pid := 0) -> CardInstance:
	return _put(pid, CardRegistry.get_card("Forest"))


func _give(pid: int, data: CardData) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(data, g._next_instance_id, pid)
	g._next_instance_id += 1
	g._instances[inst.id] = inst
	inst.zone = Mtg.Zone.HAND
	g.players[pid].hand.append(inst)
	return inst


## The fast-effects round of [param step] in [param active]'s turn, the
## human (seat 0) holding priority with every declaration made.
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


## The opponent's Gray Ogre, attacking — after [method _window].
func _their_attack() -> CardInstance:
	var ogre := _put(1, CardRegistry.get_card("Gray Ogre"))
	screen.game.combat.attackers[ogre.id] = true
	ogre.tapped = true
	return ogre


## Let the duel run: the AI seat acts on its own, the human's windows go
## through the screen's own refresh (the automatic pass).
## With [param press_done], a window the screen HOLDS for the human (a
## response in hand) is passed with the Situation Bar's Done, as a player
## who decides not to answer would.
func _drive(steps: int, until: Callable = Callable(), press_done := false) -> void:
	for _i in steps:
		if screen.game.game_over:
			return
		if until.is_valid() and bool(until.call()):
			return
		var acting := screen._ai_seat_to_act()
		if acting != -1:
			screen._ais[acting].act(screen.game)
		elif press_done and screen.game.priority_player == 0 \
				and screen.mode == DuelScreen.Mode.NORMAL \
				and not screen._auto_pass_applies():
			screen._on_pass()
		else:
			screen._refresh()


# ================================================== flash for the human --

func test_a_flash_creature_holds_the_opponents_attack_window() -> void:
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_their_attack()
	_forest()
	var cheetah := _give(0, _cheetah())
	assert_true(g.casts_at_instant_speed(0, cheetah))
	assert_eq(screen._instant_window_reason(), "attackers are declared")
	assert_true(screen._could_respond(0), "a flash creature is a response")
	assert_false(screen._auto_pass_applies(), "so the window is held for it")
	assert_eq(screen._highlight_for(cheetah), MiniCard.Highlight.OPTIONAL,
		"and its name is yellow")
	# Cast it through the screen: the click, then the Forest for its mana.
	screen._click_hand_card(cheetah)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "waiting for its {G}")
	var forest: CardInstance = g.players[0].battlefield.filter(
		func(c: CardInstance) -> bool: return c.data.card_name == "Forest")[0]
	screen._on_card_clicked(forest)
	assert_eq(g.stack.size(), 1, "cast in the opponent's combat")
	assert_eq(g.stack.back().card, cheetah)


func test_the_plain_creature_beside_it_neither_holds_nor_lights() -> void:
	var g := _window(1, Mtg.Step.DECLARE_ATTACKERS)
	_their_attack()
	_forest()
	var bear := _give(0, _bear())
	assert_false(g.casts_at_instant_speed(0, bear))
	assert_false(screen._could_respond(0))
	assert_true(screen._auto_pass_applies(), "nothing to answer with: it passes itself")
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.NONE,
		"affordable, but the step forbids it — no yellow promise")
	# ...and in the human's own main phase the same card lights as always.
	_window(0, Mtg.Step.MAIN1)
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.OPTIONAL)


func test_a_flash_rider_aura_is_a_response_only_with_a_creature_to_enchant() -> void:
	var g := _window(1, Mtg.Step.END)
	_forest()
	var armor := _give(0, _armor())
	assert_true(g.casts_at_instant_speed(0, armor), "the rider: as though it had flash")
	assert_false(screen._has_something_to_aim_at(armor),
		"with no creature on the table the Aura has nothing to be cast at")
	assert_false(screen._could_respond(0))
	_put(1, CardRegistry.get_card("Gray Ogre"))
	assert_true(screen._has_something_to_aim_at(armor))
	assert_true(screen._could_respond(0), "the Ogre is a creature to enchant")
	assert_false(screen._auto_pass_applies(), "their end step holds for it")
	assert_eq(screen._highlight_for(armor), MiniCard.Highlight.OPTIONAL)


func test_winding_canyons_makes_creature_spells_fast_effects() -> void:
	var g := _window(1, Mtg.Step.END)
	_forest()
	var bear := _give(0, _bear())
	assert_false(screen._could_respond(0), "control: a creature at their end step")
	g.grant_flash(0, _is_creature, "creature spells this turn")
	assert_true(g.casts_at_instant_speed(0, bear))
	assert_eq(screen._instant_window_reason(), "their turn is ending")
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies(), "the end-step window holds for it")
	assert_eq(screen._highlight_for(bear), MiniCard.Highlight.OPTIONAL)


func test_done_stops_for_a_flash_spell_the_floating_pool_pays() -> void:
	var g := _window(1, Mtg.Step.UPKEEP)
	var cheetah := _give(0, _cheetah())
	assert_false(screen._has_affordable_fast_effect(0), "nothing floating yet")
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	assert_true(screen._has_affordable_fast_effect(0),
		"Done's third condition: a fast effect handy and the mana for it")
	g.players[0].hand.erase(cheetah)
	_give(0, _bear())
	assert_false(screen._has_affordable_fast_effect(0), "control: a plain creature is not one")


# ============================================ the cleanup step's window --

## The human's own turn: a creature, the rider Aura cast on it in combat
## through the screen (so the engine schedules the cleanup sacrifice).
func _armor_cast_in_combat() -> Array:
	var g := _window(0, Mtg.Step.DECLARE_BLOCKERS)
	var bear := _put(0, _bear())
	var armor := _give(0, _armor())
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 1)
	screen._click_hand_card(armor)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	screen._on_card_clicked(bear)
	assert_eq(g.stack.size(), 1, "the Aura is on the chain")
	assert_true(bool(armor.memory.get("flash_cast", false)),
		"cast when a sorcery could not have been")
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_eq(armor.zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(armor.attached_to, bear.id)
	return [bear, armor]


func test_the_rider_sacrifice_opens_a_cleanup_window_the_human_answers() -> void:
	var cast := _armor_cast_in_combat()
	var bear: CardInstance = cast[0]
	var armor: CardInstance = cast[1]
	var g: MtgGame = screen.game
	# A response in hand and the mana for it, so the window holds for us.
	var growth := _give(0, _giant_growth())
	_forest()
	var turn := g.turn_number
	_drive(80, func() -> bool:
		return g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty())
	assert_eq(g.current_step(), Mtg.Step.CLEANUP, "the cleanup step holds priority")
	assert_eq(g.turn_number, turn)
	if g.current_step() != Mtg.Step.CLEANUP:
		return
	assert_eq(g.stack.size(), 1)
	assert_string_contains(g.stack.back().description.to_lower(), "sacrifice")
	assert_eq(g.priority_player, 0, "the active player first (CR 514.3a)")
	screen._refresh()
	assert_eq(DuelScreen._phase_icon_slot(g.current_step()), 6,
		"the Discard Phase icon is the lit one")
	assert_eq(screen._phase_key()[2], 6)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_false(screen._auto_pass_applies(), "a response is in hand: held")
	assert_eq(screen._highlight_for(growth), MiniCard.Highlight.OPTIONAL)
	# Answer it: the instant on the bear, through the screen.
	screen._click_hand_card(growth)
	screen._on_card_clicked(bear)
	if screen.mode == DuelScreen.Mode.PAYING:
		screen._on_card_clicked(g.players[0].battlefield.filter(
			func(c: CardInstance) -> bool: return c.data.card_name == "Forest" and not c.tapped)[0])
	assert_eq(g.stack.size(), 2, "a spell cast in the cleanup step")
	# Then pass, and the duel finishes the turn on its own.
	_drive(80, func() -> bool: return g.turn_number != turn)
	assert_ne(g.turn_number, turn, "the turn ended: no stall in Cleanup")
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD, "sacrificed at cleanup")
	assert_eq(bear.zone, Mtg.Zone.BATTLEFIELD)
	assert_false(g.awaiting_discard)


func test_with_nothing_to_answer_the_cleanup_window_passes_itself() -> void:
	var cast := _armor_cast_in_combat()
	var armor: CardInstance = cast[1]
	var g: MtgGame = screen.game
	var turn := g.turn_number
	var seen_cleanup_priority := [false]
	g.log_appended.connect(func(line: String, _meta: Dictionary) -> void:
		if line.contains("Cleanup: priority"): seen_cleanup_priority[0] = true)
	_drive(120, func() -> bool: return g.turn_number != turn)
	assert_true(seen_cleanup_priority[0], "the step did hold priority")
	assert_ne(g.turn_number, turn, "and the screen walked through it")
	assert_eq(armor.zone, Mtg.Zone.GRAVEYARD)
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_bounty_of_the_hunt_removes_its_counters_in_a_cleanup_window() -> void:
	CardPacks.set_enabled("pack-5", true)
	# The second main phase: the bear has no attack to be asked about on
	# the way to the cleanup step.
	var g := _window(0, Mtg.Step.MAIN2)
	var bear := _put(0, _bear())
	var bounty := _give(0, CardRegistry.get_card("Bounty of the Hunt"))
	g.players[0].mana_pool.add(Mtg.ManaColor.G, 5)
	screen._click_hand_card(bounty)
	assert_not_null(screen._mode_overlay, "the payment rows: mana or a green card")
	screen._on_mode_chosen(0)
	assert_eq(screen.mode, DuelScreen.Mode.TARGETING)
	for i in 3:
		screen._on_card_clicked(bear)   # one click per counter (the dial)
	assert_eq(g.stack.size(), 1, "three counters dialled, cast")
	_drive(20, func() -> bool: return g.stack.is_empty())
	assert_eq(int(bear.counters.get("+1/+1", 0)), 3)
	assert_eq(bear.cur_power, 5)
	var growth := _give(0, _giant_growth())
	_forest()
	var turn := g.turn_number
	_drive(120, func() -> bool:
		return g.current_step() == Mtg.Step.CLEANUP and not g.stack.is_empty())
	assert_eq(g.current_step(), Mtg.Step.CLEANUP)
	if g.current_step() != Mtg.Step.CLEANUP:
		return
	assert_eq(int(bear.counters.get("+1/+1", 0)), 3, "still on until the trigger resolves")
	assert_false(screen._auto_pass_applies(), "held: the Growth could answer")
	# Done, once per item the window holds for (one removal per counter).
	_drive(80, func() -> bool: return g.turn_number != turn, true)
	assert_ne(g.turn_number, turn, "the turn passed")
	assert_eq(int(bear.counters.get("+1/+1", 0)), 0, "the counters came off at cleanup")
	assert_eq(growth.zone, Mtg.Zone.HAND)
