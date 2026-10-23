class_name CardHints
extends RefCounted
## THE CARD SELLER'S HINTS (the owner, 2026-10-23: *"Build all trade
## features"*) — 1.3's `LoadTownHintMetadata` (004184d2),
## `FindHintPairIndexForOfferCard` (0041879d) and `ShowTownHintTextPopup`
## (0041905e). `Hints.txt` pairs two cards that work together, by
## difficulty, with a line on what they do; the player's own copy is
## imported into the skin (`adventure_hints.json`,
## `tools/import_original.py`) — without it the seller says nothing.
##
## On a visit to a town, once its cards are drawn, each card on offer is
## matched to the hints of the difficulty played: the card is one of a
## pair whose other card the hero owns, the two not both owned already. One
## card with a hint is drawn, and one of its hints: the button reads "Buy
## Cards/Card Hints" and the shop shows "The card seller suggests: “If you
## combine this Fungusaur with the Prodigal Sorcerer you already have, you
## can: …”". [Ours, three 1.3 slips mended: its two hints for a single card
## (the seller "notes" what the card does, when the hero owns a land of its
## colour) were found and then lost, never shown; the hint stayed after its
## card was bought; and a second visit to the same town in a row gave none.]

const SUGGESTS := "The card seller suggests: “If you combine this %s with the %s you already have, you can: %s”"
const NOTES := "The card seller notes: “If you buy this %s, you can: %s”"

static var _hints: Array = []
static var _read := false


## The hints imported: `{first, second, levels, text}` (`second` "" for a
## single card; `levels` the difficulties, bit 0 Apprentice … bit 3
## Wizard).
static func hints() -> Array:
	if not _read:
		_read = true
		_hints = []
		for hint in GameSkin.metadata("adventure_hints").get("hints", []):
			var first := CardValue.engine_name(String((hint as Dictionary).get("first", "")))
			var second := String((hint as Dictionary).get("second", ""))
			if second != "":
				second = CardValue.engine_name(second)
				if second == "":
					continue
			if first != "":
				_hints.append({"first": first, "second": second,
					"levels": int(hint.get("levels", 0)), "text": String(hint.get("text", ""))})
	return _hints


## Forget the hints (a skin imported again, a test).
static func forget() -> void:
	_hints = []
	_read = false


## THE HINT FOR THIS VISIT to town [param slot], drawn from its cards on
## offer ([method CardShop.offers]) and kept with the shop (`hint`: `{card,
## text}`), or none.
static func arrive(player: AdventurePlayer, slot: int) -> void:
	var shop: Dictionary = player.shops.get(str(slot), {})
	shop.erase("hint")
	if hints().is_empty():
		return
	var offers := CardShop.offers(player, slot)
	shop = player.shops[str(slot)]
	var owned := {}
	for card in player.cards:
		owned[String((card as Dictionary).get("card", ""))] = true
	var level := 1 << clampi(player.difficulty, 0, 3)
	var found: Array[Array] = []
	for card_name in offers:
		if card_name == "":
			continue
		var told: Array[String] = []
		for hint in hints():
			var line := _hint_for(hint as Dictionary, card_name, owned, level)
			if line != "":
				told.append(line)
		if not told.is_empty():
			found.append([card_name, told])
	if found.is_empty():
		return
	var dice := MsvcRandom.new(player.dice)
	var pick: Array = found[dice.below(found.size())]
	var lines: Array = pick[1]
	shop["hint"] = {"card": pick[0], "text": lines[dice.below(lines.size())]}
	player.dice = dice.state


## The seller's words on [param card_name] from [param hint], or "".
static func _hint_for(hint: Dictionary, card_name: String, owned: Dictionary, level: int) -> String:
	if int(hint.get("levels", 0)) & level == 0:
		return ""
	var first := String(hint.get("first", ""))
	var second := String(hint.get("second", ""))
	var text := String(hint.get("text", ""))
	if second == "":
		if card_name != first or owned.has(first) or not _owns_land_of(card_name, owned):
			return ""
		return NOTES % [first, text]
	if owned.has(first) and owned.has(second):
		return ""
	if card_name == first and owned.has(second):
		return SUGGESTS % [first, second, text]
	if card_name == second and owned.has(first):
		return SUGGESTS % [second, first, text]
	return ""


## Whether the hero owns a basic land of a colour of [param card_name].
static func _owns_land_of(card_name: String, owned: Dictionary) -> bool:
	if not CardRegistry.has_card(card_name):
		return false
	var bits := int(CardValue.facts(CardRegistry.get_card(card_name)).get("color", CardValue.COLORLESS))
	for i in CardShop.COLOR_BITS.size():
		if bits & CardShop.COLOR_BITS[i] != 0 and owned.has(CardShop.LANDS[i]):
			return true
	return false


## Town [param slot]'s hint this visit, `{card, text}` or `{}`.
static func current(player: AdventurePlayer, slot: int) -> Dictionary:
	return (player.shops.get(str(slot), {}) as Dictionary).get("hint", {})


## Card [param card_name] is bought at town [param slot]: its hint is told.
static func bought(player: AdventurePlayer, slot: int, card_name: String) -> void:
	var shop: Dictionary = player.shops.get(str(slot), {})
	if String((shop.get("hint", {}) as Dictionary).get("card", "")) == card_name:
		shop.erase("hint")
