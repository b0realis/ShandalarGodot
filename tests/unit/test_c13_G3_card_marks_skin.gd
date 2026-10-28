extends GutTest
## Needs the imported 1997 skin: reads the 1997 program's card table
## (`adventure_cards.json`). Part C stage C3: what the table says and what
## a game without it reads off the cards agree —
##  - h6-1: Power Struggle and Rainbow Knights are the table's "Power
##    Junction" and "Knights of the Rainbow Vale" (0x801): never traded,
##    never a castle's pick (they fell to derived facts and were offered);
##  - h6-2, h6-3: the marks a game without the table gives by name are the
##    table's own: 0x100 on exactly its 28 treasures, 0x800 on exactly the
##    cards it kept back — so the trades and the castles' picks differ only
##    where 1997 coloured a card otherwise (Celestial Prism, the Mana
##    Batteries: colourless as printed, coloured in its table).

## The cards the table colours and the printed card does not.
const COLOURED_IN_1997 := ["Celestial Prism", "Black Mana Battery", "Blue Mana Battery",
	"Green Mana Battery", "Red Mana Battery", "White Mana Battery"]

var player: AdventurePlayer


func before_each() -> void:
	var setup := AdventureSetup.new()
	setup.player_name = "Goya"
	setup.color = "red"
	setup.difficulty = 1
	setup.walker = "male"
	setup.seed_text = "12345"
	var record := setup.resolve({})
	player = AdventurePlayer.begin(record, AdventureSetup.make_world(record))
	_forget()
	CardRegistry.ensure_loaded()


func after_each() -> void:
	_forget()


func _forget() -> void:
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	CardHints.forget()
	LairEvent.forget()


## The table set aside: every card read off itself.
func _without_table() -> void:
	_forget()
	CardValue._imported_read = true
	CardValue._imported = {}


func _traded() -> Array[String]:
	var out: Array[String] = []
	for row in CardTrade.catalogue():
		out.append(String(row["name"]))
	return out


func test_power_struggle_and_rainbow_knights_are_read_from_the_table() -> void:
	for card_name in ["Power Struggle", "Rainbow Knights"]:
		var own := CardValue.original(card_name)
		assert_false(own.is_empty(), card_name + ": the table's row")
		assert_eq(int(own.get("extra", 0)), 0x801, card_name)
		assert_false(bool(CardValue.facts(CardRegistry.get_card(card_name))["derived"]), card_name)
		assert_false(card_name in _traded(), card_name + ": never traded")
	assert_false("Power Struggle" in CastleWin.offered(player, [], 2), "blue")
	assert_false("Rainbow Knights" in CastleWin.offered(player, [], 5), "white")


func test_the_marks_read_off_a_card_are_the_table_s() -> void:
	var checked := 0
	for card_name in CardRegistry.all_names():
		var name_text := String(card_name)
		if not CardTrade.in_adventure(name_text):
			continue
		var own := CardValue.original(name_text)
		if own.is_empty():
			continue
		var derived := CardValue.derive(CardRegistry.get_card(name_text))
		assert_eq(int(derived["extra"]) & 0x900, int(own.get("extra", 0)) & 0x900, name_text)
		checked += 1
	assert_gt(checked, 600, "every card of the table")


func test_trades_and_castle_picks_agree_with_the_table_or_without() -> void:
	var with_table: Array[String] = _traded()
	var picks := {}
	for color in range(1, 6):
		picks[color] = CastleWin.offered(player, [], color)
	_without_table()
	var without: Array[String] = _traded()
	for card_name in with_table:
		assert_true(card_name in without, "traded only with the table: " + card_name)
	for card_name in without:
		assert_true(card_name in with_table, "traded only without: " + card_name)
	for color in range(1, 6):
		var bare := CastleWin.offered(player, [], color)
		for card_name in picks[color]:
			assert_true(card_name in bare or card_name in COLOURED_IN_1997, "%d with the table: %s" % [color, card_name])
		for card_name in bare:
			assert_true(card_name in picks[color] or card_name in COLOURED_IN_1997, "%d without: %s" % [color, card_name])
