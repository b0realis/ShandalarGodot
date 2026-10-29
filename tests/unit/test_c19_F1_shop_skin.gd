extends GutTest
## Needs the imported 1997 skin: reads the 1997 program's card table
## (`adventure_cards.json`). The 0.50.65 bug campaign, k6-2: what a game
## without the table reads off a card is the table's own for every mark a
## shop reads — the base sets (`expansion` & 0xC1), the marks that keep a
## card out (`extra_ability` & 0x980) and a land of no colour — so a town's
## stock is the same card for card with the table or without it.

## The cards 1997 coloured otherwise than they are printed (the C3 stage's
## Celestial Prism and Mana Batteries; Fellwar Stone, of no colour in the
## table): the only shop cards whose colour differs.
const COLOURED_IN_1997 := ["Celestial Prism", "Black Mana Battery", "Blue Mana Battery",
	"Green Mana Battery", "Red Mana Battery", "White Mana Battery", "Fellwar Stone"]


func before_each() -> void:
	CardRegistry.ensure_loaded()
	_forget()


func after_each() -> void:
	_forget()


func _forget() -> void:
	CardValue.forget()
	CardShop.forget()


func _without_table() -> void:
	_forget()
	CardValue._imported = {}
	CardValue._imported_read = true
	CardValue._read_at = CardRegistry.revision


func _stock() -> Dictionary:
	var out := {}
	for row in CardShop.stock():
		out[String(row["name"])] = int((row["facts"] as Dictionary).get("color", 0))
	return out


func test_the_marks_a_shop_reads_are_the_table_s() -> void:
	var checked := 0
	for card_name in CardRegistry.all_names():
		var name_text := String(card_name)
		if not CardTrade.in_adventure(name_text):
			continue
		var own := CardValue.original(name_text)
		if own.is_empty():
			continue
		var data := CardRegistry.get_card(name_text)
		var derived := CardValue.derive(data)
		assert_eq(int(derived["exp"]) & 0xC1 != 0, int(own["exp"]) & 0xC1 != 0, name_text + ": the base sets")
		assert_eq(int(derived["extra"]) & 0x980, int(own["extra"]) & 0x980, name_text + ": the marks")
		# Gem Bazaar makes mana of a colour that changes: no colour in the
		# table too (a card it kept back — no shop, trade or pick has it).
		if data.is_land() and name_text != "Gem Bazaar":
			assert_eq(int(derived["color"]) == 0, int(own["color"]) == 0, name_text + ": a land of no colour")
		checked += 1
	assert_gt(checked, 600, "every card of the table")


func test_a_shop_stocks_the_same_cards_with_the_table_or_without() -> void:
	assert_false(CardValue.original("Mishra's Factory").is_empty(), "control: the table is here")
	var with_table := _stock()
	_without_table()
	var without := _stock()
	assert_gt(with_table.size(), 300)
	for card_name in with_table:
		assert_true(without.has(card_name), "only with the table: " + card_name)
	for card_name in without:
		assert_true(with_table.has(card_name), "only without: " + card_name)
		if with_table.has(card_name) and not card_name in COLOURED_IN_1997:
			assert_eq(without[card_name], with_table[card_name], card_name + ": its colour")
