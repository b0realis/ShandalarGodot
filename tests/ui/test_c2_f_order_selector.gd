extends GutTest
## THE PERSON CHOOSES THE ORDER OF THE DAMAGE EFFECTS — on the duel screen
## (the owner's ruling of 2026-10-12, campaign 2026-10-12 f-order).
##
## Under the modern rules (CR 616.1) the player the damage would hit picks
## which effect applies first. The computer's Lightning Bolt at the human,
## who holds a Forethought Amulet ("3 or more ... deals 2 instead"), with
## the computer's Furnace of Rath ("double that damage") on the table: the
## duel holds on the question, the overlay's lines name both effects and
## the question names the damage, and taking the Furnace first lands 2 —
## not the fixed order's 4. Under the 1997 rules nobody is asked.
##
## The choice overlay is not built headless (DuelScreen._open_choice_overlay),
## so the held question is answered the way the overlay answers it —
## `DuelScreen._on_choice_option` — and read through
## `DuelScreen.choice_question` / `choice_options`, which is what it shows.

var screen: DuelScreen
var _saved_stops: Variant = null
var _next_id := 941000


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)
	CardRegistry.ensure_loaded()
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	var config := DuelConfig.hotseat_default()
	config.pilots = [null, AiProfile.wizard()]   # seat 1 is the computer
	config.pace = 0.0
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	screen.config = config
	add_child_autofree(screen)
	await get_tree().process_frame
	screen.stops.clear_all()


func after_each() -> void:
	CardPacks.set_enabled("pack-9", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


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
	g.stack.clear()
	for p in g.players:
		p.battlefield.clear()
		p.hand.clear()
		p.mana_pool.clear()
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	screen._ai_pending = true    # the computer's beat waits on the test
	return g


func _summon(card_name: String, seat: int) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _next_id, seat)
	_next_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, seat)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _hold(card_name: String, seat := 0) -> CardInstance:
	var g: MtgGame = screen.game
	var data := CardRegistry.get_card(card_name)
	assert_not_null(data, "%s is in the pool" % card_name)
	var inst := CardInstance.new(data, _next_id, seat)
	_next_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[seat].hand.append(inst)
	return inst


## The computer bolts the human under [param preset]: walk the engine until
## the duel holds on a question or the Bolt (and any 1997 prevention step)
## is over. The screen's own drivers are held while it is walked.
func _bolt_the_human(preset: String) -> MtgGame:
	var g := _window(1, Mtg.Step.MAIN1)
	g.rules.set_preset(preset)
	_summon("Forethought Amulet", 0)
	_summon("Furnace of Rath", 1)
	var bolt := _hold("Lightning Bolt", 1)
	g.priority_player = 1
	g.players[1].mana_pool.add(Mtg.ManaColor.R, 1)
	screen._advancing = true
	assert_eq(g.cast_spell(1, bolt, [TargetRef.player(0)]), "")
	_walk(g)
	screen._advancing = false
	return g


func _walk(g: MtgGame) -> void:
	for _i in 12:
		if g.awaiting_choice != null or g.game_over:
			return
		if g.stack.is_empty() and not g.awaiting_damage_prevention \
				and not g.awaiting_regeneration:
			return
		g.pass_priority(g.priority_player)


## Every ordering question P0 was put, held or decided for them.
static func _order_questions(g: MtgGame) -> Array:
	var out := []
	for choice in g.choice_log:
		if choice.prompt.begins_with("Which applies first"):
			out.append(choice)
	if g.awaiting_choice != null and g.awaiting_choice.prompt.begins_with("Which applies first"):
		out.append(g.awaiting_choice)
	return out


# ================================================================ tests --

func test_modern_the_human_picks_the_furnace_first_and_takes_2() -> void:
	var g := _bolt_the_human("modern_mana_burn")
	var held: PlayerChoice = g.awaiting_choice
	assert_not_null(held, "the duel holds on the question")
	if held == null:
		return
	assert_eq(held.kind, PlayerChoice.Kind.OPTION)
	assert_eq(held.pid, 0, "put to the player the damage would hit")
	assert_eq(DuelScreen.choice_question(held),
		"Which applies first to the 3 damage from Lightning Bolt?")
	var lines := DuelScreen.choice_options(held)
	assert_eq(lines, ["Forethought Amulet", "Furnace of Rath: the damage is doubled"])
	screen._on_choice_option(lines.find("Furnace of Rath: the damage is doubled"))
	screen._advancing = true
	_walk(g)
	screen._advancing = false
	assert_null(g.awaiting_choice, "one question, answered")
	assert_true(g.stack.is_empty())
	assert_eq(g.players[0].life, 18, "doubled to 6, then the Amulet: 2")
	assert_eq(g.unanswered_choices.size(), 0, "nothing decided for the player")


func test_modern_the_human_may_keep_the_fixed_order() -> void:
	var g := _bolt_the_human("modern")
	assert_not_null(g.awaiting_choice)
	if g.awaiting_choice == null:
		return
	screen._on_choice_option(0)
	screen._advancing = true
	_walk(g)
	screen._advancing = false
	assert_eq(g.players[0].life, 16, "the Amulet first (2), then doubled: 4")


func test_1997_the_human_is_not_asked() -> void:
	var g := _bolt_the_human("fifth")
	assert_null(g.awaiting_choice, "no question under the 1997 rules")
	assert_eq(_order_questions(g).size(), 0, "nor one decided for them")
	assert_true(g.stack.is_empty())
	assert_false(g.awaiting_damage_prevention, "the prevention step is over")
	assert_eq(g.players[0].life, 16, "the fixed order: the Amulet, then the Furnace")
