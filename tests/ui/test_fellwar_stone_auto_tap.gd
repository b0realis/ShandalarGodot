extends GutTest
## FELLWAR STONE (and Reflecting Pool) UNDER THE DOUBLE-CLICK AND THE
## PAYMENT CLICK.
##
## THE OWNER, 2026-11-11, replacing the rule of 2026-09-17: *"Yes make them
## auto select"* — asked which, the owner chose the cards WITHOUT the mark:
## a Stone or Pool the player has not marked `Don't auto tap this card`
## makes the colour the cost still needs, under the double-click and on a
## click while a cast waits for its mana; one they marked keeps the 1997
## question, *"Fellwar Stone: What kind of mana?"*, every time it is tapped
## (and the double-click never touches a marked card at all).
##
## 2026-09-17's playtest still stands behind the model: [method
## ManaPlanner.sources] lists the Stone once per colour on offer and a
## plan step carries the colour it priced ([method ManaPlanner.step_of]),
## so a plan can never make "the wrong colour"; [method
## MtgGame.tap_for_mana] asks nothing for ONE colour on offer, or for the
## colour a plan or a click hands it. What changed is that the gesture now
## plans over that full list ([method ManaPlanner.sources]) instead of a
## collapsed generic-only one, and the payment click asks [method
## ManaPlanner.payment_pick] for the Stone's colour as it does for a dual
## land's.

var screen: DuelScreen


func before_each() -> void:
	CardPacks.set_enabled("pack-9", true)   # Reflecting Pool (Tempest)
	CardRegistry.ensure_loaded()
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame


func after_each() -> void:
	CardPacks.set_enabled("pack-9", false)


## A clean main phase for seat 0: [param card_name] in hand, [param mine]
## on seat 0's table, [param theirs] on seat 1's, nothing floating.
func _stage(card_name: String, mine: Array, theirs: Array) -> CardInstance:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.players[0].hand.clear()
	g.players[0].mana_pool.clear()
	g.players[0].battlefield.clear()
	g.players[1].battlefield.clear()
	screen.mode = DuelScreen.Mode.NORMAL
	var inst := CardInstance.new(CardRegistry.get_card(card_name), 93001, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	var next := 93010
	for name in mine:
		var c := CardInstance.new(CardRegistry.get_card(name), next, 0)
		next += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, 0)
	for name in theirs:
		var c := CardInstance.new(CardRegistry.get_card(name), next, 1)
		next += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, 1)
	screen._refresh()
	return inst


func _tapped() -> Array:
	var out: Array = []
	for p in screen.game.players[0].battlefield:
		if p.tapped:
			out.append(p.data.card_name)
	return out


func _double_click(inst: CardInstance) -> void:
	screen._on_card_clicked(inst)      # the first click of the pair
	screen._auto_cast(inst)            # the second


func _mark(inst: CardInstance) -> void:
	screen._no_auto_tap[inst.id] = true


func _stone() -> CardInstance:
	for p in screen.game.players[0].battlefield:
		if p.data.card_name == "Fellwar Stone":
			return p
	return null


# ------------------------------- several colours, NOT marked: the colour owed --

func test_the_double_click_makes_the_stone_pay_without_a_question() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Fellwar Stone"], ["Island", "Mountain"])
	_double_click(bears)
	assert_null(g.awaiting_choice, "no What kind of mana? for an unmarked Stone")
	assert_eq(g.stack.size(), 1, "cast in one gesture")
	assert_eq(g.stack[0].card, bears)
	assert_eq(_tapped(), ["Forest", "Fellwar Stone"], "the Forest paid {G}, the Stone the {1}")
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing left floating")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	assert_false(screen._auto_resume)


func test_a_generic_only_cost_uses_the_stone_without_asking() -> void:
	var g: MtgGame = screen.game
	var stone_spell := _stage("Fellwar Stone", ["Forest", "Fellwar Stone"], ["Island", "Mountain"])
	_double_click(stone_spell)
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1)
	assert_eq(_tapped(), ["Forest", "Fellwar Stone"])
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_the_double_click_makes_the_colour_a_pip_needs() -> void:
	# {R} with only the Stone, facing an Island and a Mountain: the plan
	# prices the Stone's red row, and the tap makes red.
	var g: MtgGame = screen.game
	var raiders := _stage("Mons's Goblin Raiders", ["Fellwar Stone"], ["Island", "Mountain"])
	assert_eq(screen._highlight_for(raiders), MiniCard.Highlight.CASTABLE,
		"the Stone can make red, so the name is yellow")
	_double_click(raiders)
	assert_null(g.awaiting_choice)
	assert_eq(g.stack.size(), 1, "cast in one gesture")
	assert_eq(_tapped(), ["Fellwar Stone"])
	assert_eq(g.players[0].mana_pool.total(), 0, "the red was spent: it was the colour owed")


func test_a_payment_click_on_the_stone_makes_the_pip_owed() -> void:
	var g: MtgGame = screen.game
	var raiders := _stage("Mons's Goblin Raiders", ["Fellwar Stone"], ["Island", "Mountain"])
	screen._on_card_clicked(raiders)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_stone())
	assert_null(g.awaiting_choice, "the bill names red: nothing to ask")
	screen._refresh()
	assert_eq(g.stack.size(), 1, "the waiting cast took the red")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_payment_click_for_generic_takes_the_first_colour() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Fellwar Stone"], ["Island", "Mountain"])
	screen._on_card_clicked(bears)
	screen._on_card_clicked(g.players[0].battlefield[0])   # the Forest: {G}
	screen._refresh()
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "{1} still owed")
	screen._on_card_clicked(_stone())
	assert_null(g.awaiting_choice, "any colour pays the {1}: nothing to ask")
	screen._refresh()
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_click_outside_a_payment_still_asks() -> void:
	# Floating mana is the player's own colour, as with a dual land's menu.
	var g: MtgGame = screen.game
	_stage("Grizzly Bears", ["Fellwar Stone"], ["Island", "Mountain"])
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	screen._on_card_clicked(_stone())
	assert_not_null(g.awaiting_choice)
	assert_eq((g.awaiting_choice as PlayerChoice).prompt, "Fellwar Stone: What kind of mana?")
	assert_eq(g.answer_choice(Mtg.ManaColor.U), "")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


func test_the_gesture_prefers_lands_that_ask_nothing() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Fellwar Stone", "Forest"], ["Island", "Mountain"])
	_double_click(bears)
	assert_eq(g.stack.size(), 1, "cast in one gesture")
	assert_eq(_tapped(), ["Forest", "Forest"], "two Forests, the Stone untouched")
	assert_null(g.awaiting_choice, "and no question")


# --------------------------- MARKED Don't auto tap: the 1997 question, always --

func test_a_marked_stone_is_left_out_of_the_double_click() -> void:
	var g: MtgGame = screen.game
	var raiders := _stage("Mons's Goblin Raiders", ["Fellwar Stone"], ["Island", "Mountain"])
	_mark(_stone())
	_double_click(raiders)
	assert_eq(g.stack.size(), 0)
	assert_eq(_tapped(), [], "the marked Stone is the player's to tap")
	assert_null(g.awaiting_choice)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "the player finishes it by hand")
	assert_eq(screen._pending_card, raiders)


func test_a_marked_stone_asks_its_colour_on_a_payment_click() -> void:
	var g: MtgGame = screen.game
	var raiders := _stage("Mons's Goblin Raiders", ["Fellwar Stone"], ["Island", "Mountain"])
	_mark(_stone())
	screen._on_card_clicked(raiders)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_stone())
	assert_not_null(g.awaiting_choice, "the mark keeps What kind of mana?")
	assert_eq((g.awaiting_choice as PlayerChoice).prompt, "Fellwar Stone: What kind of mana?")
	assert_eq(g.answer_choice(Mtg.ManaColor.R), "")
	screen._refresh()
	assert_eq(g.stack.size(), 1, "the answer paid, and the retry cast it")


func test_cancelling_a_marked_stones_question_keeps_the_cast_waiting() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Fellwar Stone"], ["Island", "Mountain"])
	_mark(_stone())
	_double_click(bears)
	assert_eq(_tapped(), [], "without the marked Stone there is no whole plan to tap")
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(g.players[0].battlefield[0])   # the Forest, by hand
	screen._refresh()
	assert_eq(_tapped(), ["Forest"])
	screen._on_card_clicked(_stone())
	assert_not_null(g.awaiting_choice)
	assert_eq(g.cancel_choice(), "")
	screen._refresh()
	assert_eq(g.stack.size(), 0)
	assert_eq(screen._pending_card, bears, "the cast is kept")
	assert_false(_stone().tapped)
	screen._on_card_clicked(_stone())
	assert_eq(g.answer_choice(Mtg.ManaColor.U), "")
	screen._refresh()
	assert_eq(g.stack.size(), 1)


# --------------------------------------------- ONE colour: known, no question --

func test_a_stone_with_one_colour_on_offer_auto_taps_without_asking() -> void:
	# 2026-09-17: *"...or if we know the opponent only has land of the
	# colour we know."*
	var g: MtgGame = screen.game
	var merfolk := _stage("Merfolk of the Pearl Trident", ["Fellwar Stone"], ["Island"])
	assert_eq(screen._highlight_for(merfolk), MiniCard.Highlight.CASTABLE)
	_double_click(merfolk)
	assert_null(g.awaiting_choice, "one colour is no choice")
	assert_eq(g.stack.size(), 1, "cast in one gesture")
	assert_eq(_tapped(), ["Fellwar Stone"])
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_stone_with_one_colour_asks_nothing_by_hand_either() -> void:
	var g: MtgGame = screen.game
	_stage("Merfolk of the Pearl Trident", ["Fellwar Stone"], ["Island"])
	_mark(_stone())
	screen._on_card_clicked(_stone())
	assert_null(g.awaiting_choice, "no one-button question, marked or not")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.U), 1)


# ------------------------------------------------------- Reflecting Pool --

## A Pool beside a tapped Forest and a tapped Island (a tapped land still
## "could produce", its ruling): blue or green on offer.
func _pool_stage() -> Array:
	var g: MtgGame = screen.game
	var merfolk := _stage("Merfolk of the Pearl Trident", ["Reflecting Pool", "Forest", "Island"], [])
	var pool: CardInstance = null
	for p in g.players[0].battlefield:
		if p.data.card_name == "Reflecting Pool":
			pool = p
		else:
			g.tap_permanent(p)
	screen._refresh()
	return [merfolk, pool]


func test_a_reflecting_pool_pays_the_pip_owed() -> void:
	var g: MtgGame = screen.game
	var staged := _pool_stage()
	screen._on_card_clicked(staged[0])
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(staged[1])
	assert_null(g.awaiting_choice, "the bill names blue")
	screen._refresh()
	assert_eq(g.stack.size(), 1)


func test_a_marked_reflecting_pool_asks() -> void:
	var g: MtgGame = screen.game
	var staged := _pool_stage()
	_mark(staged[1])
	screen._on_card_clicked(staged[0])
	screen._on_card_clicked(staged[1])
	assert_not_null(g.awaiting_choice, "marked: the player names the type")
	assert_eq(g.cancel_choice(), "")


# ------------------------------------------------- the model behind it --

func test_the_planner_lists_the_stone_once_per_colour_for_every_seat() -> void:
	var g: MtgGame = screen.game
	_stage("Grizzly Bears", ["Fellwar Stone"], ["Island", "Mountain"])
	var colors: Array = []
	for row in ManaPlanner.sources(g, 0):
		colors.append(int(row[2]))
	assert_eq(colors, [Mtg.ManaColor.U, Mtg.ManaColor.R], "one row per colour on offer")
	assert_true(g.could_afford(0, CardRegistry.get_card("Mons's Goblin Raiders")))
	var plan := ManaPlanner.plan_from(ManaPlanner.sources(g, 0), ManaCost.parse("{R}"), 0)
	assert_eq(plan.size(), 1)
	assert_eq(ManaPlanner.step_of(plan[0]).size(), 3, "the step names its colour")
	assert_eq(int(ManaPlanner.step_of(plan[0])[2]), Mtg.ManaColor.R)
