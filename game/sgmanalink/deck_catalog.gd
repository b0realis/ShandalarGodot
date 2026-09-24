class_name SgDeckCatalog
extends RefCounted
## [QoL] Local deck files become bounded card-name lists, never remote paths.
## The referee validates names again. Sideboards are retained privately for
## review; a friendly single duel does not have a between-games sideboard step.

static func validate(cards: Array, sideboard: Array = []) -> String:
	if cards.size() < DeckModel.MIN_CARDS or cards.size() > 250 or sideboard.size() > 250:
		return "Choose a deck with %d-250 cards and at most 250 sideboard cards." % DeckModel.MIN_CARDS
	CardRegistry.ensure_loaded()
	for card_name in cards + sideboard:
		if not CardRegistry.has_card(card_name):
			return "The host does not implement one or more cards in this deck."
	return ""


static func available() -> Array:
	var result: Array = []
	for path in DeckStore.all_deck_paths():
		var deck := DeckList.load_file(path)
		if not deck.errors.is_empty() or not validate(deck.cards, deck.sideboard).is_empty():
			continue
		result.append(payload({"name": deck.deck_name, "cards": Array(deck.cards),
			"sideboard": Array(deck.sideboard), "printings": deck.printings}).merged({"group": _group(path)}))
	return result


static func payload(deck: Dictionary) -> Dictionary:
	var out := {"name": deck.name, "cards": deck.cards.duplicate(), "sideboard": deck.sideboard.duplicate()}
	var printings := DeckPrintings.keep_present(deck.get("printings", {}), deck.cards + deck.sideboard)
	if not printings.is_empty(): out.printings = printings
	return out


## The lobby's tooltip for a deck row: the shelf under the shipped decks
## (`/1997`, `/tournament`…) or the player's own folder as they see it.
## The user directory kept the literal `user://decks` before this: only
## the shipped prefix was trimmed, whichever directory the file came from.
static func _group(path: String) -> String:
	if path.begins_with(DeckStore.SHIPPED_DIR):
		return path.get_base_dir().trim_prefix(DeckStore.SHIPPED_DIR)
	return GamePaths.shown(path.get_base_dir())
