class_name AdventurePacks
extends RefCounted
## Campaign-local card modules, independent of their optional adventure providers.
## CardPacks owns installation and card rules; this layer owns campaign eligibility.
## An adventure is linked by its descriptor's pack ID, never by a special-case shop.

static var _stock := {}
static var _revision := -1

static func selected(player: AdventurePlayer, pack: String) -> bool:
	return player != null and player.packs.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id", "") == pack)

static func adventures(pack: String) -> Array[String]:
	var out: Array[String] = []
	for id in AdventureExpansions.definitions():
		if AdventureExpansions.definition(id).get("pack", "") == pack: out.append(id)
	return out

## Selecting cards on Embark enables their installed rules once, when setting out.
## Other packs' duel settings are left alone; they do not join this campaign.
static func activate(ids: Array[String]) -> String:
	if ids.is_empty(): return ""
	var service := AdventureExpansions.packs()
	if service == null: return "Card packs are unavailable."
	for id in ids:
		if not service.has_pack(id): return "Install %s in Options › Card Packs before setting out." % id
		if not service.is_enabled(id) and service.change_refusal() != "": return service.change_refusal()
	for id in ids:
		if not service.is_enabled(id) and not service.set_enabled(id, true):
			return "Could not enable %s. Check Options › Card Packs." % id
	return ""

static func offers_cards(player: AdventurePlayer, pack: String) -> bool:
	if not selected(player, pack): return false
	var service := AdventureExpansions.packs()
	if service == null or not service.is_enabled(pack): return false
	if not player.expanded_adventure: return true
	var lands := adventures(pack)
	# Packs without an adventure are still complete card modules.
	if lands.is_empty(): return true
	for id in lands:
		var field: String = AdventureExpansions.definition(id).get("cards_unlock", "liberated")
		if AdventureRegions.id(player.world) == id or bool(AdventureExpansions.progress(player, id).get(field, false)):
			return true
	return false

static func add_stock(player: AdventurePlayer, base: Array[Dictionary]) -> Array[Dictionary]:
	if player == null or player.packs.is_empty(): return base
	var out := base.duplicate()
	var held := {}
	for row in base: held[row["name"]] = true
	for pack in player.packs:
		if not pack is Dictionary or not pack.get("id") is String: continue
		var id: String = pack["id"]
		if not offers_cards(player, id): continue
		for row in card_stock(id):
			if held.has(row["name"]): continue
			held[row["name"]] = true
			out.append(row)
	return out

## Cache values only, never CardData or artwork. Printing variants count once.
static func card_stock(id: String) -> Array[Dictionary]:
	CardRegistry.ensure_loaded()
	if _revision != CardRegistry.revision:
		_stock.clear()
		_revision = CardRegistry.revision
	if _stock.has(id): return _stock[id]
	var rows: Array[Dictionary] = []
	var service := AdventureExpansions.packs()
	if service == null: return rows
	var seen := {}
	for record in service.entry_records(id):
		var card: String = record.get("name", "")
		if seen.has(card) or not CardRegistry.has_card(card): continue
		seen[card] = true
		# A reprint must not bypass a core trader's treasure/withheld-card rules.
		if CardTrade.in_adventure(card): continue
		rows.append({"name": card, "facts": CardValue.facts(CardRegistry.get_card(card))})
	_stock[id] = rows
	return rows

## Earlier expedition saves predate the independent checkbox. Preserve only
## adventures evidenced by saved entries/progress/regions, not global settings.
static func migrate(player: AdventurePlayer, version: int) -> void:
	if version >= 7: return
	var lands := {}
	for id in player.expansions: lands[id] = true
	for id in player.regions: lands[id] = true
	lands[AdventureRegions.id(player.world)] = true
	var extra := player.world.expansion
	for id in extra.get("entries", {}): lands[id] = true
	if extra.has("port") and AdventureRegions.mainland(player): lands["refuge"] = true
	lands.erase(AdventureRegions.MAINLAND)
	player.expanded_adventure = not lands.is_empty()
	for id in lands:
		var pack: String = AdventureExpansions.definition(id).get("pack", "")
		if pack == "" or selected(player, pack): continue
		var service := AdventureExpansions.packs()
		var info: Dictionary = service.info(pack) if service != null else {}
		player.packs.append({"id": pack, "version": str(info.get("version", ""))})
