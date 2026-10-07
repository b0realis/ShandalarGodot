extends GutTest
## THE ANNOUNCEMENT BRACKET AT THE LOCAL SCREEN (whole-game campaign,
## fix-ui, w7-5 — the engine half is fix-engine's
## `MtgGame.begin_announcement`).
##
## Paying an announced spell with City of Brass put its "becomes tapped"
## trigger on the stack at once, and the cast was then refused ("main phase
## with an empty stack") — CR 601.2g-h, 603.3: nobody receives priority
## between the announcement and the object being on the stack, so what the
## payment triggers waits and goes on the stack ABOVE the object. The
## screen opens the bracket before every tap it makes or takes for the
## pending cast — the double-click's plan, a land clicked while the cast
## waits for its mana, a mana ability chosen from the menu there — and
## closes it when the cast is abandoned.

var screen: DuelScreen
var _id := 933000


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)          # a hotseat: nobody passes for anyone
	await get_tree().process_frame


func _stage() -> MtgGame:
	var g: MtgGame = screen.game
	g._probing = true
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.stack.clear()
	for p in g.players:
		p.hand.clear()
		p.battlefield.clear()
		p.mana_pool.clear()
	g._probing = false
	screen.mode = DuelScreen.Mode.NORMAL
	return g


func _bf(card_name: String, seat: int) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _id, seat)
	_id += 1
	g._probing = true
	g._instances[inst.id] = inst
	g._put_on_battlefield(inst, seat)
	inst.summoning_sick = false
	g.recalculate()
	g._probing = false
	return inst


func _hand(card_name: String) -> CardInstance:
	var g: MtgGame = screen.game
	var inst := CardInstance.new(CardRegistry.get_card(card_name), _id, 0)
	_id += 1
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	return inst


func _assert_cast_under_the_ping(g: MtgGame, bears: CardInstance, how: String) -> void:
	assert_eq(g.stack.size(), 2, "%s: the Bears and the City's ping (prompt: %s)"
		% [how, screen._prompt_label.text])
	if g.stack.size() != 2:
		return
	assert_eq(g.stack[0].card, bears, "%s: the Bears at the bottom" % how)
	assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER, "%s: the ping above it" % how)
	assert_null(screen._pending_card, "%s: nothing left pending" % how)


func test_a_double_click_paid_with_city_of_brass_casts_under_its_ping() -> void:
	var g := _stage()
	_bf("City of Brass", 0)
	_bf("Forest", 0)
	var bears := _hand("Grizzly Bears")
	screen._refresh()
	screen._auto_cast(bears)
	_assert_cast_under_the_ping(g, bears, "double-click")


func test_city_of_brass_tapped_by_hand_for_a_waiting_cast_casts_under_its_ping() -> void:
	var g := _stage()
	var city := _bf("City of Brass", 0)
	var forest := _bf("Forest", 0)
	var bears := _hand("Grizzly Bears")
	screen._refresh()
	screen._on_card_clicked(bears)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING, "the cast waits for its mana")
	screen._on_card_clicked(city)                    # five colours: the menu
	screen._ability_menu.hide()
	screen._on_ability_chosen(4)                     # {G}
	assert_true(g.stack.is_empty(), "the ping waits for the cast")
	assert_true(g.announcement_open(0), "the bracket is open")
	screen._on_card_clicked(forest)
	_assert_cast_under_the_ping(g, bears, "by hand")


func test_an_abandoned_cast_lets_the_ping_go_on() -> void:
	var g := _stage()
	var city := _bf("City of Brass", 0)
	_bf("Forest", 0)
	var bears := _hand("Grizzly Bears")
	screen._refresh()
	screen._on_card_clicked(bears)
	screen._on_card_clicked(city)
	screen._ability_menu.hide()
	screen._on_ability_chosen(0)                     # {W}: not enough for the Bears
	assert_true(g.stack.is_empty(), "control: the ping waits")
	screen._on_cancel()
	assert_false(g.announcement_open(0), "Cancel closes the bracket")
	assert_eq(g.stack.size(), 1, "and the ping goes on the stack")
	if g.stack.size() == 1:
		assert_eq(g.stack[0].kind, Mtg.StackKind.TRIGGER)
	assert_eq(g.priority_player, 0, "the seat keeps priority (CR 117.3c)")
