class_name CardPrintings
extends RefCounted
## Presentation-only printing choices; never changes CardData or game rules.
const META := &"card_printing"

static func service() -> Node:
	var tree := Engine.get_main_loop() as SceneTree
	return tree.root.get_node_or_null("CardPacks") if tree != null else null

static func choices(card_name: String) -> Array:
	var packs := service()
	return packs.printing_choices(card_name) if packs != null else []

static func resolve(card_name: String, id: String) -> Dictionary:
	if not DeckPrintings.valid_id(id): return {}
	for row in choices(card_name):
		if row.id == id or (not id.contains(":") and row.set == id): return row
	return {}

static func label(row: Dictionary) -> String:
	var title: String = DeckFilter.SET_LABELS.get(row.set, String(row.set).to_upper())
	if not String(row.get("number", "")).is_empty(): title += " · #" + String(row.number)
	if not String(row.get("artist", "")).is_empty(): title += " · " + String(row.artist)
	return title

static func texture(card_name: String, id: String, full_card := false) -> Texture2D:
	var row := resolve(card_name, id)
	var packs := service()
	if row.is_empty() or packs == null: return null
	return packs.art_texture(card_name, row.set, full_card, row.get("number", ""))

static func of(card: CardInstance) -> String:
	return "" if card == null or card.face_down else String(card.get_meta(META, ""))

static func apply_game(game: MtgGame, preferences: Array) -> void:
	# Only visual metadata on the original deck instances, after setup and
	# before dealing. Ownership/control changes do not change their artwork.
	for pid in mini(2, preferences.size()):
		if not preferences[pid] is Dictionary: continue
		for card in game.players[pid].library + game.players[pid].hand:
			var id: Variant = preferences[pid].get(card.data.card_name, "")
			if DeckPrintings.valid_id(id): card.set_meta(META, id)
