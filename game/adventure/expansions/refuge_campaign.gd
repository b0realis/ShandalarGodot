class_name RefugeCampaign
extends RefCounted
## The Last Refuge: new game fiction about descendants of Sarpadian
## refugees. The island is in Shandalar; the ship crosses no planar barrier.

const MAINLAND := "mainland"
const ISLAND := "refuge"
const LOCAL_RECORD := ["quest", "quest_offer", "last_town", "town_quests", "wise_man", "links_taken", "lairs_explored"]
const QUESTS := [
	["white", "The Bread Road", "Leitbur's Rest remembers Icatia's soldiers and its divisive zealots. The Crown's tithe-collector now uses those traditions to seize the harvest. Defeat his soldiers so grain can reach the harbor.", "Ebon Crown Tithe-Collector"],
	["blue", "A Harbor for Both Peoples", "Vodalian fishers and homarids have made a new harbor pact, despite their ancestors' wars. The Crown's captain commands sea magic to blockade them. Defeat the captain to reopen their shared channels.", "The Blockade Captain"],
	["black", "No More Masters", "Free thrulls live here beside people who rejected the Ebon Hand. The Crown's overseer would drag them back into breeding pits. Defeat him and defend their freedom.", "The Pit Overseer"],
	["red", "The Mountain Road", "Dwarven smiths and goblin traders refuse to repeat their ancestors' wars. They share a mountain pass, but the Crown's raiders demand tribute. Defeat the raider who bars the road.", "The Tribute-Raider"],
	["green", "Room to Grow", "Havenwood's elves and thallids tend an uneasy border. The Crown's sporekeeper spreads unchecked growth to drive them apart. Defeat the sporekeeper and protect the grove's balance.", "The Crown's Sporekeeper"],
]
const SPELLS := [
	["Icatian Javelineers", "Order of Leitbur", "Icatian Infantry", "Icatian Priest", "Farrel's Zealot", "Combat Medic"],
	["Vodalian Soldiers", "Vodalian Mage", "Homarid", "Homarid Warrior", "High Tide", "Deep Spawn"],
	["Basal Thrull", "Armor Thrull", "Order of the Ebon Hand", "Hymn to Tourach", "Thrull Retainer", "Soul Exchange"],
	["Dwarven Soldier", "Goblin Chirurgeon", "Goblin War Drums", "Goblin Grenade", "Orcish Veteran", "Goblin Warrens"],
	["Thallid", "Thorn Thallid", "Elvish Farmer", "Elvish Hunter", "Feral Thallid", "Spore Flower"],
]
const LANDS := ["Plains", "Island", "Swamp", "Mountain", "Forest"]

static func on_island(player: AdventurePlayer) -> bool:
	return player != null and player.world != null and player.world.expansion.get("region", MAINLAND) == ISLAND

static func available() -> bool:
	var packs := _packs()
	return packs != null and packs.is_enabled(FallenEmpiresPack.ID)

## AdventurePlayer is also compiled by standalone tools before autoload
## identifiers exist. Resolve the pack service only when it is needed.
static func _packs() -> Node:
	var loop := Engine.get_main_loop()
	return (loop as SceneTree).root.get_node_or_null("CardPacks") if loop is SceneTree else null

static func initialize(player: AdventurePlayer) -> void:
	if player.world == null or on_island(player):
		return
	if not player.world.expansion.has("port"):
		var tile := RefugeWorld.port_for(player.world, player.world.start_tile())
		if tile.x >= 0:
			player.world.expansion["port"] = [tile.x, tile.y]
			player.world.expansion["region"] = MAINLAND
	# A chart on the map makes the new coast discoverable without replacing
	# a town, a dungeon, a quest destination, or a tile of the original map.
	if player.refuge.is_empty():
		player.refuge = {"regions": {}, "quests": [], "pending": [], "liberated": false}

static func marker(world: ShandalarWorld, tile: Vector2i) -> String:
	for key in ["port", "castle"]:
		var point: Array = world.expansion.get(key, [])
		if point.size() == 2 and tile == Vector2i(int(point[0]), int(point[1])):
			return key
	return ""

static func snapshot(player: AdventurePlayer) -> Dictionary:
	var saved := player.to_dict(false)
	var record := {}
	for key in LOCAL_RECORD:
		record[key] = saved["record"][key]
	return {"world": saved["world"], "where": saved["where"], "clocks": saved["clocks"],
		"record": record, "links": TownStatus.mana_links(player.world)}.duplicate(true)

static func restore(player: AdventurePlayer, region: Dictionary) -> void:
	var saved_world: Dictionary = region["world"]
	player.world = AdventurePlayer._world_from(saved_world, Vector2i.ZERO)
	AdventurePlayer._read_where(player, region["where"])
	AdventurePlayer._read_clocks(player, region["clocks"])
	var record: Dictionary = player.to_dict(false)["record"]
	for key in LOCAL_RECORD:
		record[key] = region["record"].get(key, record[key])
	AdventurePlayer._read_record(player, record)
	player.world_seed_text = str(saved_world.get("seed_text", player.world.seed))
	player.made_fingerprint = str(saved_world.get("made_fingerprint", ""))
	player.dice = int(saved_world.get("dice", player.world.rand_state))
	player.monsters = AdventurePlayer._cleaned_monsters(saved_world.get("monsters"), player.world)
	player.shops = AdventurePlayer._cleaned_shops(saved_world.get("shops"), player.world)
	player.step = 0

static func travel(player: AdventurePlayer) -> bool:
	initialize(player)
	var leaving := ISLAND if on_island(player) else MAINLAND
	var entering := MAINLAND if leaving == ISLAND else ISLAND
	if entering == ISLAND and not available():
		return false
	var regions: Dictionary = player.refuge.get("regions", {})
	if entering == MAINLAND and not regions.has(MAINLAND):
		return false
	if entering == ISLAND:
		var has_record := false
		for pack in player.packs:
			if pack.get("id", "") == FallenEmpiresPack.ID:
				has_record = true
		if not has_record:
			player.packs.append({"id": FallenEmpiresPack.ID, "version": str(_packs().info(FallenEmpiresPack.ID).get("version", "1"))})
	regions[leaving] = snapshot(player)
	if regions.has(entering):
		restore(player, regions[entering])
		regions.erase(entering)
	else:
		var made := RefugeWorld.generate(player.world.seed ^ 0x46454D, player.world.color, player.difficulty)
		var fresh := AdventurePlayer.new()
		fresh.world = made
		fresh.position = made.start
		fresh.dice = made.rand_state
		fresh.made_fingerprint = made.fingerprint()
		restore(player, snapshot(fresh))
	player.refuge["regions"] = regions
	player.entered_tile = player.tile()
	player.log_event("voyage", "Sailed to the Last Refuge." if entering == ISLAND else "Returned to Shandalar's mainland.")
	return true

static func valid_saved(data: Dictionary) -> bool:
	var state: Variant = data.get("refuge", {})
	if not state is Dictionary:
		return false
	var regions: Variant = state.get("regions", {})
	if not regions is Dictionary:
		return false
	var done: Variant = state.get("quests", [])
	var pending: Variant = state.get("pending", [])
	if not done is Array or not pending is Array or not state.get("liberated", false) is bool:
		return false
	if done.size() > 5 or pending.size() > 60:
		return false
	var unique := {}
	for index in done:
		if not AdventurePlayer._is_number(index) or int(index) != index or index < 0 or index > 4 or unique.has(int(index)):
			return false
		unique[int(index)] = true
	for card in pending:
		if not card is String or not card in FallenEmpiresPack.names():
			return false
	if bool(state.get("liberated", false)) and done.size() != 5:
		return false
	var extra: Variant = data.get("world", {}).get("expansion", {})
	if not valid_places(extra) or not _valid_island(data.get("world", {})):
		return false
	var active: String = extra.get("region", MAINLAND)
	for key in regions:
		if not key in [MAINLAND, ISLAND] or key == active or not regions[key] is Dictionary:
			return false
		var region: Dictionary = regions[key]
		for part in ["world", "where", "clocks", "record"]:
			if not region.get(part) is Dictionary:
				return false
		if not AdventurePlayer._grid_whole(region["world"].get("grid")):
			return false
		if not valid_places(region["world"].get("expansion", {})):
			return false
		if region["world"].get("expansion", {}).get("region", MAINLAND) != key or not _valid_island(region["world"]):
			return false
	return extra.get("region", MAINLAND) != ISLAND or regions.has(MAINLAND)

## A saved island must still contain its return harbor and five communities.
## Reject damaged records before travel can strand the hero or index a void.
static func _valid_island(saved: Dictionary) -> bool:
	var extra: Dictionary = saved.get("expansion", {})
	if extra.get("region", MAINLAND) != ISLAND: return true
	var sites: Variant = saved.get("sites", [])
	if not sites is Array or sites.size() < 6: return false
	var used := {}
	for key in ["port", "castle"]:
		var point: Array = extra[key]
		var tile := Vector2i(int(point[0]), int(point[1]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0: return false
		used[tile] = true
	for index in range(1, 6):
		if not sites[index] is Dictionary: return false
		var site: Dictionary = sites[index]
		var kind: Variant = site.get("type")
		if not AdventurePlayer._is_number(kind) or int(kind) != kind \
				or int(kind) not in [ShandalarWorld.TOWN, ShandalarWorld.CITY]: return false
		for axis in ["x", "y"]:
			var at: Variant = site.get(axis)
			if not AdventurePlayer._is_number(at) or int(at) != at or at < 0 or at >= 64: return false
		var tile := Vector2i(int(site["x"]), int(site["y"]))
		if used.has(tile) or String(saved["grid"][tile.y]).hex_decode()[tile.x] & 15 == 0: return false
		used[tile] = true
	return true

static func valid_places(extra: Variant) -> bool:
	if not extra is Dictionary or not extra.get("region", MAINLAND) in [MAINLAND, ISLAND]:
		return false
	if not WorldTerrainPalette.valid_appearance(extra.get("appearance", {})):
		return false
	for key in ["town_names", "dungeon_names"]:
		if not extra.get(key, {}) is Dictionary:
			return false
		for name in extra.get(key, {}).values():
			if not name is String:
				return false
	for key in ["port", "castle"]:
		if not extra.has(key):
			if extra.get("region", MAINLAND) == ISLAND:
				return false
			continue
		var point: Variant = extra[key]
		if not point is Array or point.size() != 2:
			return false
		for axis in point:
			if not AdventurePlayer._is_number(axis) or int(axis) != axis or axis < 0 or axis >= 64:
				return false
	return true

static func extra_links(player: AdventurePlayer) -> int:
	var count := 0
	for region in player.refuge.get("regions", {}).values():
		# Sites are authoritative, as on the active map. The cached count
		# in an older snapshot may be stale or malformed.
		for site in region.get("world", {}).get("sites", []):
			if site is Dictionary and AdventurePlayer._is_number(site.get("status")) \
					and int(site["status"]) & TownStatus.LINKED != 0:
				count += 1
	return count

static func next_target(player: AdventurePlayer) -> Dictionary:
	if not on_island(player):
		return {}
	for index in 5:
		if not completed(player, index):
			var site: Dictionary = player.world.sites[index + 1]
			return {"tile": Vector2i(site["x"], site["y"]), "kind": "quest", "name": RefugeWorld.TOWNS[index]}
	var key := "port" if bool(player.refuge.get("liberated", false)) else "castle"
	var point: Array = player.world.expansion.get(key, [])
	return {"tile": Vector2i(point[0], point[1]), "kind": "quest", "name": "Refuge Harbor" if key == "port" else "Castle of the Ebon Crown"} if point.size() == 2 else {}

static func status_lines(player: AdventurePlayer) -> Array[String]:
	if not on_island(player):
		return []
	var target := next_target(player)
	return ["The Last Refuge: %d / 5 pledges" % player.refuge.get("quests", []).size(),
		"The island is free. Fallen Empires spells reach the mainland." if bool(player.refuge.get("liberated", false)) else "Seek %s." % target.get("name", "the five communities"),
		"The ship at Refuge Harbor always offers a free voyage home."]

static func offers_cards(player: AdventurePlayer) -> bool:
	return available() and (on_island(player) or bool(player.refuge.get("liberated", false)))

static func add_stock(player: AdventurePlayer, base: Array[Dictionary]) -> Array[Dictionary]:
	if not offers_cards(player):
		return base
	var out := base.duplicate()
	var held := {}
	for row in out:
		held[String(row["name"])] = true
	for name in FallenEmpiresPack.names():
		if not held.has(name) and CardRegistry.has_card(name):
			out.append({"name": name, "facts": CardValue.facts(CardRegistry.get_card(name))})
	return out

static func deck_gate(player: AdventurePlayer) -> Dictionary:
	var cards := player.deck_cards()
	var count := 0
	var total := 0
	var known := true
	var names := FallenEmpiresPack.names()
	for card in cards:
		if not CardRegistry.has_card(card):
			known = false
			continue
		if CardRegistry.get_card(card).is_land():
			continue
		total += 1
		if card in names:
			count += 1
	return {"count": count, "total": total, "ready": known and total > 0 and count * 2 >= total}

static func completed(player: AdventurePlayer, quest: int) -> bool:
	return quest in player.refuge.get("quests", [])

static func finish_quest(player: AdventurePlayer, quest: int) -> bool:
	if not on_island(player) or quest < 0 or quest >= QUESTS.size() or completed(player, quest):
		return false
	var done: Array = player.refuge.get("quests", [])
	done.append(quest)
	player.refuge["quests"] = done
	var pending: Array = player.refuge.get("pending", [])
	for card in SPELLS[quest]:
		for copy in 2:
			pending.append(card)
	player.refuge["pending"] = pending
	player.gold += 100
	player.food += 20
	player.log_event("quest", "The Last Refuge: %s completed." % QUESTS[quest][1], {"done": true})
	claim(player)
	return true

static func claim(player: AdventurePlayer) -> int:
	var pending: Array = player.refuge.get("pending", [])
	var taken := 0
	while not pending.is_empty() and player.bag_room() > 0 and CardRegistry.has_card(String(pending[0])):
		player.add_card(String(pending.pop_front()))
		taken += 1
	player.refuge["pending"] = pending
	return taken

static func can_challenge(player: AdventurePlayer) -> bool:
	return on_island(player) and available() and player.refuge.get("quests", []).size() == 5 \
		and not bool(player.refuge.get("liberated", false)) and bool(deck_gate(player)["ready"])

static func deck_problem(player: AdventurePlayer) -> String:
	if not available(): return "Enable Pack 2: Fallen Empires in Options to begin this battle."
	if player.deck_cards().is_empty(): return "Choose a deck in a town's deck builder before beginning this battle."
	for card in player.deck_cards():
		if not CardRegistry.has_card(card): return "Your deck contains unavailable cards. Enable their packs or edit the deck in town."
	return ""

static func liberate(player: AdventurePlayer) -> bool:
	if not can_challenge(player):
		return false
	player.refuge["liberated"] = true
	# Existing shop stock can now draw from the expanded pool on restock.
	player.log_event("freed", "The Last Refuge is free. Fallen Empires spells now reach the mainland.")
	return true

static func duel_config(player: AdventurePlayer, quest: int) -> DuelConfig:
	var config := DuelConfig.new()
	var index := quest if quest >= 0 else 2
	var deck: Array = []
	for card in SPELLS[index]:
		for copy in 4:
			deck.append(card)
	for copy in 16:
		deck.append(LANDS[index])
	if quest == 1:
		# Deep Spawn costs eight mana: two finishers and eighteen lands.
		for copy in 2:
			deck.erase("Deep Spawn")
			deck.append("Island")
	if quest < 0:
		# A coherent black deck led by the old cult's successors.
		deck = ["Order of the Ebon Hand", "Order of the Ebon Hand", "Order of the Ebon Hand", "Order of the Ebon Hand",
			"Hymn to Tourach", "Hymn to Tourach", "Hymn to Tourach", "Hymn to Tourach", "Thrull Champion", "Thrull Champion",
			"Basal Thrull", "Basal Thrull", "Basal Thrull", "Basal Thrull", "Armor Thrull", "Armor Thrull", "Armor Thrull", "Armor Thrull",
			"Dark Ritual", "Dark Ritual", "Terror", "Terror", "Drain Life", "Drain Life"]
		for copy in 16:
			deck.append("Swamp")
	config.decks = [CreatureMeeting.padded_deck(player, player.deck_cards()), deck]
	config.player_names = [player.name if player.name != "" else "Adventurer", String(QUESTS[index][3]) if quest >= 0 else "Lord of the Ebon Crown"]
	var deck_name := player.deck_names[player.current_deck] if player.current_deck < player.deck_names.size() else ""
	config.deck_names = [deck_name if deck_name != "" else "Deck %d" % (player.current_deck + 1), String(QUESTS[index][1]) if quest >= 0 else "The Ebon Crown"]
	config.portraits = [player.portrait, CreatureBook.face_id(1)]
	config.lives = [CreatureMeeting.hero_life(player), 20 if quest >= 0 else 25]
	config.pilots = [null, CreatureMeeting.ai_for(player.difficulty)]
	config.mulligan_rule = MtgGame.MULLIGAN_1997
	config.ai_random_play_or_draw = true
	config.pace = Settings.ai_pace()
	config.rng_seed = randi() | 1
	if player.next_duel_first_move:
		config.first_player = 0
	if player.next_duel_card != "":
		config.start_in_play = [[player.next_duel_card], []]
	config.apply_deck_colors()
	CreatureMeeting.hero_playmat(config, player)
	return config
