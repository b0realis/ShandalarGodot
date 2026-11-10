extends GutTest
## GITHUB ISSUE #7 (a player's report of 2026-11-07): *"Here I am casting a
## Whirling Dervish (2 green) and I tap Pendelhaven for a green mana, and
## also want to tap my Savannah for green — and it makes me choose. I think
## it should automatically select what I need ... Same for many other mana
## sources, like Birds of Paradise."* Issue #8 asked the same at its end.
##
## While a cast waits for its mana ([constant DuelScreen.Mode.PAYING]) a
## click on a source with several mana abilities taps the colour the bill
## needs when the choice is clear ([method ManaPlanner.payment_pick]); the
## menu stays for a real choice, and a click outside a payment floats mana
## through the menu as before.

var screen: DuelScreen
var _next_id := 94010


func before_each() -> void:
	screen = load("res://game/duel/duel_screen.tscn").instantiate()
	add_child_autofree(screen)
	await get_tree().process_frame
	_next_id = 94010


func after_each() -> void:
	if screen != null and screen._ability_menu != null:
		screen._ability_menu.hide()


## A clean main phase for seat 0 with [param spell] in hand (a card name or
## a [CardData]) and [param mine] on the table (names or CardData).
func _stage(spell: Variant, mine: Array) -> CardInstance:
	var g: MtgGame = screen.game
	g.active_player = 0
	g._enter_step(Mtg.STEP_ORDER.find(Mtg.Step.MAIN1))
	g.priority_player = 0
	g.players[0].hand.clear()
	g.players[0].mana_pool.clear()
	g.players[0].battlefield.clear()
	g.players[1].battlefield.clear()
	screen.mode = DuelScreen.Mode.NORMAL
	var inst := CardInstance.new(_data(spell), 94001, 0)
	inst.zone = Mtg.Zone.HAND
	g._instances[inst.id] = inst
	g.players[0].hand.append(inst)
	for entry in mine:
		var c := CardInstance.new(_data(entry), _next_id, 0)
		_next_id += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, 0)
		c.summoning_sick = false
	screen._refresh()
	return inst


func _data(entry: Variant) -> CardData:
	return entry if entry is CardData else CardRegistry.get_card(String(entry))


func _on_table(card_name: String, nth := 0) -> CardInstance:
	var seen := 0
	for c in screen.game.players[0].battlefield:
		if c.data.card_name == card_name:
			if seen == nth:
				return c
			seen += 1
	return null


## A synthetic creature costing [param cost], for bills no printed card in
## the default pool has ({G}{W}).
func _spell(cost: String) -> CardData:
	return CardData.new("Test %s" % cost, cost, Mtg.CardType.CREATURE).pt(1, 1)


func _menu_open() -> bool:
	return screen._ability_menu.visible


# ===================================================== the player's case --

func test_the_savannah_taps_for_the_green_the_dervish_still_needs() -> void:
	var g: MtgGame = screen.game
	var dervish := _stage("Whirling Dervish", ["Pendelhaven", "Savannah"])
	screen._on_card_clicked(dervish)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_on_table("Pendelhaven"))
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	screen._on_card_clicked(_on_table("Savannah"))
	assert_false(_menu_open(), "no Green-or-White menu: only green pays the {G} still owed")
	assert_true(_on_table("Savannah").tapped)
	assert_eq(g.stack.size(), 1, "the Dervish is cast")
	if g.stack.size() == 1:
		assert_eq(g.stack[0].card, dervish)
	assert_eq(g.players[0].mana_pool.total(), 0, "nothing white left floating")
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)


func test_the_savannah_taps_for_white_when_white_is_owed() -> void:
	# White is the land's SECOND ability: the first is not simply taken.
	var g: MtgGame = screen.game
	var lions := _stage("Savannah Lions", ["Savannah"])
	screen._on_card_clicked(lions)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_on_table("Savannah"))
	assert_false(_menu_open())
	assert_eq(g.stack.size(), 1, "Savannah Lions cast from the Savannah's white")
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_birds_of_paradise_make_the_colour_that_is_owed() -> void:
	var g: MtgGame = screen.game
	var dervish := _stage("Whirling Dervish", ["Forest", "Birds of Paradise"])
	screen._on_card_clicked(dervish)
	screen._on_card_clicked(_on_table("Forest"))
	screen._on_card_clicked(_on_table("Birds of Paradise"))
	assert_false(_menu_open(), "five colours on offer, one owed")
	assert_true(_on_table("Birds of Paradise").tapped)
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_city_of_brass_pays_the_pip_and_still_deals_its_damage() -> void:
	# Five painful abilities alike: the pain is no difference between them.
	var g: MtgGame = screen.game
	var lions := _stage("Savannah Lions", ["City of Brass"])
	screen._on_card_clicked(lions)
	screen._on_card_clicked(_on_table("City of Brass"))
	assert_false(_menu_open())
	assert_true(_on_table("City of Brass").tapped)
	assert_eq(g.stack.size(), 2, "the Lions, and the City's damage above them (CR 601.2h)")
	assert_true(g.stack.any(func(item: StackItem) -> bool: return item.card == lions))
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_the_generic_left_takes_the_first_colour() -> void:
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Savannah"])
	screen._on_card_clicked(bears)
	screen._on_card_clicked(_on_table("Forest"))
	assert_eq(screen._prompt_label.text, "CASTING: Grizzly Bears, Tap {1}")
	screen._on_card_clicked(_on_table("Savannah"))
	assert_false(_menu_open(), "any colour pays {1}, and the two differ in nothing else")
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].mana_pool.total(), 0)


# ============================================ the rest of the bill decides --

func test_both_colours_owed_the_other_sources_decide() -> void:
	# {G}{W} from a Savannah and a lone Plains: white would strand the {G}.
	var g: MtgGame = screen.game
	var spell := _stage(_spell("{G}{W}"), ["Savannah", "Plains"])
	screen._on_card_clicked(spell)
	assert_eq(screen.mode, DuelScreen.Mode.PAYING)
	screen._on_card_clicked(_on_table("Savannah"))
	assert_false(_menu_open(), "the Plains can pay only the {W}, so the Savannah is green")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1)
	assert_eq(screen._prompt_label.text, "CASTING: Test {G}{W}, Tap {W}")
	screen._on_card_clicked(_on_table("Plains"))
	assert_eq(g.stack.size(), 1)


func test_both_colours_owed_and_either_works_keeps_the_menu() -> void:
	var g: MtgGame = screen.game
	var spell := _stage(_spell("{G}{W}"), ["Savannah", "Savannah"])
	screen._on_card_clicked(spell)
	screen._on_card_clicked(_on_table("Savannah"))
	assert_true(_menu_open(), "green or white both leave the other Savannah to pay: a real choice")
	assert_false(_on_table("Savannah").tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)
	assert_eq(screen._ability_menu.item_count, 2)


func test_more_mana_than_the_generic_owed_keeps_the_menu() -> void:
	# Black Lotus for a {1}: two would float, and their colour is the player's.
	var g: MtgGame = screen.game
	var bears := _stage("Grizzly Bears", ["Forest", "Black Lotus"])
	screen._on_card_clicked(bears)
	screen._on_card_clicked(_on_table("Forest"))
	screen._on_card_clicked(_on_table("Black Lotus"))
	assert_true(_menu_open())
	assert_eq(_on_table("Black Lotus").zone, Mtg.Zone.BATTLEFIELD)
	assert_eq(g.stack.size(), 0)


func test_black_lotus_makes_the_owed_colour() -> void:
	var g: MtgGame = screen.game
	var dervish := _stage("Whirling Dervish", ["Black Lotus"])
	screen._on_card_clicked(dervish)
	screen._on_card_clicked(g.players[0].battlefield[0])
	assert_false(_menu_open())
	assert_eq(g.stack.size(), 1, "three green: the {G}{G} paid")
	assert_eq(g.players[0].mana_pool.amount_of(Mtg.ManaColor.G), 1, "one green floats")


func test_the_menus_choice_opens_the_announcement_bracket_too() -> void:
	# A City of Brass facing {G}{W} beside a Savannah: either colour leaves
	# the other to the Savannah, so the City asks. Chosen from the menu, its
	# ping still waits above the cast (campaign w7-5, CR 601.2h); the
	# Savannah then pays the {W} left without one.
	var g: MtgGame = screen.game
	var spell := _stage(_spell("{G}{W}"), ["City of Brass", "Savannah"])
	screen._on_card_clicked(spell)
	screen._on_card_clicked(_on_table("City of Brass"))
	assert_true(_menu_open(), "green or white: the player's choice")
	screen._ability_menu.hide()
	screen._on_ability_chosen(4)                     # {G}
	assert_true(g.stack.is_empty(), "the ping waits for the cast")
	assert_true(g.announcement_open(0), "the bracket is open")
	screen._on_card_clicked(_on_table("Savannah"))
	assert_false(_menu_open(), "only white is owed now")
	assert_eq(g.stack.size(), 2, "the spell, and the City's ping above it")
	if g.stack.size() == 2:
		assert_eq(g.stack[0].card, spell)
		assert_eq(g.stack[1].kind, Mtg.StackKind.TRIGGER)


# ==================================================== differences beyond colour --

## Adarkar Wastes' shape, written out: a painless {C} and a painful {W}.
func _pain_land() -> CardData:
	return CardData.new("Test Painland", "", Mtg.CardType.LAND) \
		.mana(ManaAbility.new(Mtg.ManaColor.C)) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).hurting(1).with_side_effect(_sting))


static func _sting(game: MtgGame, source: CardInstance, controller: int) -> void:
	game.deal_damage(source, TargetRef.player(controller), 1)


func test_a_painland_taps_for_the_one_colour_that_pays() -> void:
	var g: MtgGame = screen.game
	var lions := _stage("Savannah Lions", [_pain_land()])
	screen._on_card_clicked(lions)
	screen._on_card_clicked(_on_table("Test Painland"))
	assert_false(_menu_open(), "{C} pays nothing of a {W}")
	assert_eq(g.stack.size(), 1)
	assert_eq(g.players[0].life, 19, "the white tap's pain")


func test_a_painland_with_generic_and_a_pip_owed_keeps_the_menu() -> void:
	# {C} pays the {1} painlessly, {W} the pip with a life: the player says.
	var g: MtgGame = screen.game
	var spell := _stage(_spell("{1}{W}"), [_pain_land(), "Plains"])
	screen._on_card_clicked(spell)
	screen._on_card_clicked(_on_table("Test Painland"))
	assert_true(_menu_open())
	assert_false(_on_table("Test Painland").tapped)
	assert_eq(g.players[0].life, 20)


# ============================================================== unchanged --

func test_a_click_outside_a_payment_still_opens_the_menu() -> void:
	var g: MtgGame = screen.game
	_stage("Grizzly Bears", ["Savannah"])
	assert_eq(screen.mode, DuelScreen.Mode.NORMAL)
	screen._on_card_clicked(_on_table("Savannah"))
	assert_true(_menu_open(), "floating mana is the player's own colour")
	assert_false(_on_table("Savannah").tapped)
	assert_eq(g.players[0].mana_pool.total(), 0)


func test_a_fellwar_stone_still_asks_its_colour() -> void:
	# The owner's rule of 2026-09-17 (tests/ui/test_fellwar_stone_auto_tap.gd).
	var g: MtgGame = screen.game
	var lions := _stage("Savannah Lions", ["Fellwar Stone"])
	for land in ["Plains", "Island"]:
		var c := CardInstance.new(CardRegistry.get_card(land), _next_id, 1)
		_next_id += 1
		g._instances[c.id] = c
		g._put_on_battlefield(c, 1)
	screen._refresh()
	screen._on_card_clicked(lions)
	screen._on_card_clicked(_on_table("Fellwar Stone"))
	assert_not_null(g.awaiting_choice, "What kind of mana? is still the player's")
	assert_eq(g.cancel_choice(), "")
