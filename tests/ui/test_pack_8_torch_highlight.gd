extends GutTest
## KAERVEK'S TORCH AND THE YELLOW NAME (Pack 8): "As long as Kaervek's Torch
## is on the stack, spells that target it cost {2} more to cast." A castable
## check is made before any target is chosen, so the screen hands the CARD
## to `MtgGame.can_afford` / `could_afford`, which add
## `MtgGame.targeting_surcharge_floor` — {2} when every legal target of a
## required slot is a taxing spell. A Counterspell with only {U}{U} to tap
## is therefore NOT yellow (and is no response the automatic pass waits
## for); with {2}{U}{U} it is, and the cast it starts waits for — and the
## double-click taps — the extra {2} (`spell_payment(..., targets)`).

var screen: DuelScreen
var _saved_stops: Variant = null


func before_each() -> void:
	_saved_stops = Settings.get_value(PhaseStops.SETTING_KEY, null) \
		if Settings.has_value(PhaseStops.SETTING_KEY) else null
	CardPacks.set_enabled("pack-8", true)
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
	CardPacks.set_enabled("pack-8", false)
	if _saved_stops == null:
		Settings.clear_value(PhaseStops.SETTING_KEY)
	else:
		Settings.set_value(PhaseStops.SETTING_KEY, _saved_stops)


func _make(pid: int, card_name: String, zone: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), g._next_instance_id, pid)
	g._next_instance_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	if zone == Mtg.Zone.HAND:
		inst.zone = Mtg.Zone.HAND
		g.players[pid].hand.append(inst)
	else:
		g._put_on_battlefield(inst, pid)
		inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


## The opponent's main phase: their Kaervek's Torch (X = 1, at me) on the
## chain, my priority, [param islands] untapped Islands and a Counterspell.
func _torch_on_the_chain(islands: int) -> Array:
	var g: MtgGame = screen.game
	for i in islands:
		_make(0, "Island", Mtg.Zone.BATTLEFIELD)
	var counter := _make(0, "Counterspell", Mtg.Zone.HAND)
	var torch := _make(1, "Kaervek's Torch", Mtg.Zone.HAND)
	g._probing = true
	g.active_player = 1
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 1
	g.players[1].mana_pool.add(Mtg.ManaColor.R, 2)
	assert_eq(g.cast_spell(1, torch, [TargetRef.player(0)], 1), "", "the Torch is cast")
	g.priority_player = 0
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return [counter, torch]


func test_two_islands_do_not_light_a_counterspell_aimed_at_the_torch() -> void:
	var g: MtgGame = screen.game
	var cast := _torch_on_the_chain(2)
	var counter: CardInstance = cast[0]
	assert_eq(g.targeting_surcharge_floor(0, counter.data, counter), 2,
		"its only target is the Torch: {2} more")
	assert_false(g.could_afford(0, counter.data, {}, counter))
	assert_eq(screen._highlight_for(counter), MiniCard.Highlight.NONE,
		"{U}{U} cannot pay {2}{U}{U}: no yellow promise")
	assert_false(screen._could_respond(0), "and it is no response to wait for")


func test_four_islands_light_it_and_the_cast_pays_the_extra_two() -> void:
	var g: MtgGame = screen.game
	var cast := _torch_on_the_chain(4)
	var counter: CardInstance = cast[0]
	var torch: CardInstance = cast[1]
	assert_eq(screen._highlight_for(counter), MiniCard.Highlight.OPTIONAL)
	assert_true(screen._could_respond(0))
	assert_false(screen._auto_pass_applies(), "the Torch permits a response: held")
	# Click it: the lone enemy spell is taken as the target, and the cast
	# waits for {2}{U}{U}, saying where the {2} comes from.
	screen._click_hand_card(counter)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	assert_string_contains(screen._prompt_label.text, "{2} more for its target")
	for island in g.players[0].battlefield.duplicate():
		if g.stack.size() > 1:
			break
		screen._on_card_clicked(island)
	assert_eq(g.stack.size(), 2, "Counterspell on the chain above the Torch")
	assert_eq(g.stack.back().card, counter)
	assert_eq(g.stack.back().targets[0].instance_id, torch.id)
	var tapped := g.players[0].battlefield.filter(func(c: CardInstance) -> bool: return c.tapped)
	assert_eq(tapped.size(), 4, "all four Islands paid")
