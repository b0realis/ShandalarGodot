class_name AdventurePacks
extends RefCounted
## Campaign-local card modules, independent of their optional adventure providers.
## CardPacks owns installation and card rules; this layer owns campaign eligibility.
## An adventure is linked by its descriptor's pack ID, never by a special-case shop.

static var _stock := {}
static var _revision := -1

static func forget() -> void:
	_stock.clear()
	_revision = -1

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
		if not service.has_pack(id): return "Install %s in Options › Card Packs before setting out." % title(id)
		if not service.is_enabled(id) and service.change_refusal() != "": return service.change_refusal()
	for id in ids:
		if not service.is_enabled(id) and not service.set_enabled(id, true):
			return "Could not enable %s. Check Options › Card Packs." % title(id)
	return ""

## A pack as the Embark lists it, "Pack 2 · Fallen Empires"; one not installed
## by its file, "Pack 2 (Pack-2-Fallen-Empires.zip)"; one this build does not
## know by its number alone.
static func title(id: String) -> String:
	var service := AdventureExpansions.packs()
	var label := "Pack " + id.trim_prefix("pack-")
	if service == null: return label
	var info: Dictionary = service.info(id)
	if info.has("name"): return "%s · %s" % [label, info["name"]]
	return "%s (%s)" % [label, service.file_name_for(id)] if id in service.known_ids() else label

## A SAVED CAMPAIGN'S PACKS, AS IT IS TAKEN UP AGAIN (0.60.13 bug campaign,
## h3-1; the owner, 2026-10-28: "resume with a notice (a missing pack
## refuses and says which)"). Before, a campaign resumed silently without
## its pack: the pack's cards dropped out of every duel with errors, and the
## hero could still stake and lose them. A pack not installed refuses the
## load and is named; one installed but switched off is enabled, as setting
## out does ([method activate]), and named in the notice. `{refusal,
## enabled}`: the refusal "" when the campaign may resume; the packs enabled
## now, by [method title]. Pack 1 is never a campaign's (AdventureSetup).
static func resume(player: AdventurePlayer) -> Dictionary:
	var enabled: Array[String] = []
	var ids: Array[String] = []
	for row in player.packs:
		var id: String = row["id"] if row is Dictionary and row.get("id") is String else ""
		if id != "" and not id in AdventureSetup.IGNORED_PACKS and not id in ids: ids.append(id)
	var service := AdventureExpansions.packs()
	var missing: Array[String] = []
	for id in ids:
		if service == null or not service.has_pack(id): missing.append(title(id))
	if not missing.is_empty():
		var one := missing.size() == 1
		return {"refusal": "This adventure needs the card %s %s. Add %s in Options › Card Packs, then resume." % [
			"pack" if one else "packs", " and ".join(missing), "it" if one else "them"], "enabled": enabled}
	for id in ids:
		if service.is_enabled(id): continue
		if service.change_refusal() != "":
			return {"refusal": "This adventure needs %s enabled. %s" % [title(id), service.change_refusal()], "enabled": enabled}
		if not service.set_enabled(id, true):
			return {"refusal": "Could not enable %s. Check Options › Card Packs." % title(id), "enabled": enabled}
		enabled.append(title(id))
	if not enabled.is_empty(): AdventureExpansions.sync_choices(player)
	return {"refusal": "", "enabled": enabled}

## The pack [param card_name] comes in, by the packs this build knows,
## installed or not; "" for none (a base card, or a name no pack has).
static func card_pack(card_name: String) -> String:
	var service := AdventureExpansions.packs()
	if service == null: return ""
	var names: Array[String] = [card_name]
	var ids: Array[String] = service.packs_required_by(names)
	return ids[0] if not ids.is_empty() else ""

## Why a card the game does not know now cannot be bought, naming its pack
## (the owner's polish of 2026-11-03, [method CardShop._mark_unavailable]).
static func card_refusal(card_name: String) -> String:
	var pack := card_pack(card_name)
	if pack == "": return "Enable this card's pack to buy it."
	var service := AdventureExpansions.packs()
	return "%s this card's pack, %s, to buy it." % ["Enable" if service.has_pack(pack) else "Install", title(pack)]

## The notice of [method resume]'s packs enabled, "" for none.
static func enabled_notice(titles: Array[String]) -> String:
	if titles.is_empty(): return ""
	return "Card %s enabled for this adventure: %s." % ["pack" if titles.size() == 1 else "packs", ", ".join(titles)]

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
