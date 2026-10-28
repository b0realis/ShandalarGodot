extends GutTest
## 1997'S MARKS WITHOUT ITS CARD TABLE (part C stage C3; the owner,
## 2026-10-28: without the table, trades and castle picks "follow 1997's
## own marks"). Every test here reads the cards as a game without the
## imported 1997 program does ([method CardValue.derive]):
##  - h6-1: two Astral cards the 1997 lists name otherwise — "Power
##    Junction" our Power Struggle, "Knights of the Rainbow Vale" our
##    Rainbow Knights — are read under those names;
##  - h6-2: the 28 dungeon treasures carry 1997's 0x100 — special in a
##    shop (×8, at least 200), "Acquired spell" when found, rares in a
##    lair's pool — and no restricted card that is no treasure does;
##  - h6-3: the 22 cards 1997 marked 0x800 carry it and are never traded
##    nor picked at a castle, while the ante cards, Channel and Fastbond
##    are, as with the table — the catalogue reads the marks, not the
##    restricted and banned lists.

## The 1997 table's 0x800 rows (its 23 but Blank Slot 13), by our names.
const KEPT_BACK := ["Bottle of Suleiman", "Call from the Grave", "Diamond Valley",
	"Elephant Graveyard", "Gem Bazaar", "Ifh-Bíff Efreet", "Junún Efreet", "Juzám Djinn",
	"King Suleiman", "Mana Crypt", "Mijae Djinn", "Nalathni Dragon", "Necropolis of Azar",
	"Orcish Catapult", "Pandora's Box", "Power Struggle", "Prismatic Dragon",
	"Rainbow Knights", "Serendib Djinn", "Serendib Efreet", "Windseeker Centaur",
	"Ydwen Efreet"]
## What 1997 traded that the restricted and banned lists kept out.
const TRADED := ["Channel", "Fastbond", "Contract from Below", "Darkpact",
	"Demonic Attorney", "Rebirth", "Tempest Efreet"]
## Restricted cards that are no treasure: never special for it (Channel
## 0x1000, Fastbond 0, Black Vise 0x200, Mana Vault 0x1001 in 1997's table).
const RESTRICTED_PLAIN := ["Channel", "Fastbond", "Black Vise", "Mana Vault"]

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
	CardValue._imported_read = true
	CardValue._imported = {}


func after_each() -> void:
	_forget()


func _forget() -> void:
	CardValue.forget()
	CardShop.forget()
	CardTrade.forget()
	CardHints.forget()
	LairEvent.forget()


func _treasures() -> Array[String]:
	var out: Array[String] = []
	for row in ShandalarWorld.DUNGEON_CARDS:
		out.append(String(row[1]))
	return out


func _traded() -> Array[String]:
	var out: Array[String] = []
	for row in CardTrade.catalogue():
		out.append(String(row["name"]))
	return out


func _facts(card_name: String) -> Dictionary:
	return CardValue.facts(CardRegistry.get_card(card_name))


# ---------------------------------------------------------------- h6-1 --

func test_two_astral_cards_are_read_under_their_1997_names() -> void:
	assert_eq(CardValue.engine_name("Power Junction"), "Power Struggle")
	assert_eq(CardValue.engine_name("Knights of the Rainbow Vale"), "Rainbow Knights")


# ---------------------------------------------------------------- h6-2 --

func test_every_treasure_is_special_without_the_table() -> void:
	var treasures := _treasures()
	assert_eq(treasures.size(), 28)
	for card_name in treasures:
		var f := _facts(card_name)
		assert_true(bool(f["derived"]), card_name + ": read off the card")
		assert_eq(int(f["extra"]) & 0x100, 0x100, card_name + ": 0x100")
		assert_eq(CardShop.shop_rarity(f), 4, card_name + ": special")
		assert_gte(CardValue.price_of(f), 200, card_name + ": a special card's price")
	for card_name in ["Regrowth", "Sol Ring", "Berserk", "Demonic Tutor"]:
		assert_eq(AdventurePlayer._rarity(card_name), 4, card_name)
	# Measured by h6 without the table: Berserk 120, Regrowth 100.
	assert_gt(CardValue.base_price(CardRegistry.get_card("Berserk")), 120)
	assert_gt(CardValue.base_price(CardRegistry.get_card("Regrowth")), 100)


func test_a_treasure_found_is_written_in_the_journal() -> void:
	for card_name in _treasures():
		var before := player.journal.size()
		assert_true(player.add_card(card_name))
		assert_eq(player.journal.size(), before + 1, card_name + ": \"Acquired spell\"")
		player.cards.pop_back()


func test_the_lairs_rare_of_any_kind_may_be_any_treasure() -> void:
	var rares: Array[String] = []
	for row in LairEvent._cards():
		if CardShop.shop_rarity(row["facts"]) >= 3:
			rares.append(String(row["name"]))
	for card_name in _treasures():
		assert_true(card_name in rares, card_name)


func test_a_restricted_card_is_not_special_for_being_restricted() -> void:
	for card_name in RESTRICTED_PLAIN:
		if not CardRegistry.has_card(card_name):
			continue
		assert_eq(int(_facts(card_name)["extra"]) & 0x180, 0, card_name)
		assert_true(card_name in DeckFormat.RESTRICTED, card_name + " is restricted")


# ---------------------------------------------------------------- h6-3 --

func test_the_cards_1997_kept_back_carry_its_mark_and_are_never_traded() -> void:
	# Read off the script, so this file compiles against a CardValue
	# without the list (the red run).
	var kept := []
	for card_name in (CardValue as Script).get_script_constant_map().get("KEPT_BACK_1997", []):
		kept.append(card_name)
	kept.sort()
	var expected := KEPT_BACK.duplicate()
	expected.sort()
	assert_eq(kept, expected, "the 1997 table's 0x800 rows")
	var traded := _traded()
	for card_name in KEPT_BACK:
		assert_true(CardRegistry.has_card(card_name), card_name)
		assert_eq(int(_facts(card_name)["extra"]) & 0x800, 0x800, card_name)
		assert_false(card_name in traded, card_name + ": never traded")
	for card_name in _treasures():
		assert_false(card_name in traded, card_name + ": a treasure is never traded")


func test_the_ante_cards_channel_and_fastbond_are_traded_as_1997_traded_them() -> void:
	var traded := _traded()
	for card_name in TRADED:
		assert_true(card_name in traded, card_name)


func test_a_castle_s_picks_follow_the_marks() -> void:
	var picks := {}
	for color in range(1, 6):
		picks[color] = CastleWin.offered(player, [], color)
	for card_name in ["Juzám Djinn", "Junún Efreet", "Call from the Grave", "Necropolis of Azar"]:
		assert_false(card_name in picks[1], "black: " + card_name)
	for card_name in ["Contract from Below", "Darkpact", "Demonic Attorney"]:
		assert_true(card_name in picks[1], "black: " + card_name)
	for card_name in ["Serendib Djinn", "Serendib Efreet", "Power Struggle"]:
		assert_false(card_name in picks[2], "blue: " + card_name)
	assert_false("Ifh-Bíff Efreet" in picks[3], "green: Ifh-Bíff Efreet")
	for card_name in ["Channel", "Fastbond", "Rebirth"]:
		assert_true(card_name in picks[3], "green: " + card_name)
	for card_name in ["Mijae Djinn", "Nalathni Dragon", "Orcish Catapult", "Windseeker Centaur",
			"Ydwen Efreet"]:
		assert_false(card_name in picks[4], "red: " + card_name)
	assert_true("Tempest Efreet" in picks[4], "red: Tempest Efreet")
	for card_name in ["King Suleiman", "Prismatic Dragon", "Rainbow Knights"]:
		assert_false(card_name in picks[5], "white: " + card_name)
