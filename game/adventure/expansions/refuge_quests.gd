class_name RefugeQuests
extends RefCounted
## PROTOTYPE GAME DESIGN TEST: petitions and task stages are experiments in
## clear goals, lore-driven choices and reusable quest progression, not final
## content commitments. Preserve saved progress while refining the design.
## Persistent petitions with different journeys. Numeric stages, no live nodes;
## old completed pledges and waiting card rewards remain valid without migration.
const GOLD := 40
const FOOD := 8
const REWARD_COUNT := 6
const COLORS := ["White", "Blue", "Black", "Red", "Green"]
const BUNDLES := [
	["Order of Leitbur", "Icatian Javelineers", "Icatian Infantry", "Icatian Priest", "Farrel's Zealot", "Combat Medic"],
	["Vodalian Soldiers", "Vodalian Mage", "Merseine", "Homarid Warrior", "High Tide", "Deep Spawn"],
	["Order of the Ebon Hand", "Hymn to Tourach", "Basal Thrull", "Armor Thrull", "Soul Exchange", "Thrull Retainer"],
	["Goblin Chirurgeon", "Goblin Grenade", "Goblin War Drums", "Dwarven Soldier", "Orcish Veteran", "Goblin Warrens"],
	["Thallid", "Thorn Thallid", "Elvish Farmer", "Thallid Devourer", "Spore Flower", "Feral Thallid"],
]

static func stage(player: AdventurePlayer, index: int) -> int:
	return int(player.refuge.get("stages", {}).get(str(index), 0))

static func set_stage(player: AdventurePlayer, index: int, value: int) -> void:
	var stages: Dictionary = player.refuge.get("stages", {})
	stages[str(index)] = value
	player.refuge["stages"] = stages
	player.log_clue(guidance(player, index), "quest_clue")

static func start(player: AdventurePlayer, index: int) -> bool:
	if not RefugeCampaign.on_island(player) or index not in [0, 1, 3] or stage(player, index) != 0 or RefugeCampaign.completed(player, index): return false
	set_stage(player, index, 1)
	return true

static func ready(player: AdventurePlayer, index: int) -> bool:
	return (stage(player, index) >= 2 if index in [0, 1] else stage(player, index) >= 1 if index == 3 else true) and not RefugeCampaign.completed(player, index)

## First prototype islands have only the five communities. Never invent a
## destination at an empty (0,0) slot or regenerate a player's visited map.
static func ensure_objectives(player: AdventurePlayer) -> void:
	if not RefugeCampaign.on_island(player): return
	var world := player.world
	var saved: Variant = world.expansion.get("objectives")
	if saved is Dictionary and saved.has("channel") and saved.has("raider"):
		var valid := true
		for key in ["channel", "raider"]:
			var value: Variant = saved[key]
			if not AdventurePlayer._is_number(value) or int(value) != value or value < -1 or value >= world.sites.size(): valid = false
			elif value >= 0 and int(world.sites[int(value)].get("type", 0)) not in [ShandalarWorld.TOWN, ShandalarWorld.CITY, ShandalarWorld.VILLAGE]: valid = false
		if valid: return
	world.expansion["objectives"] = {
		"channel": RegionObjectives.site(world, {"coastal": true, "exclude": [1, 2, 3, 4, 5], "types": [ShandalarWorld.TOWN, ShandalarWorld.CITY]}, 22),
		"raider": RegionObjectives.site(world, {"near_terrain": 5, "radius": 2, "road": true, "types": [ShandalarWorld.VILLAGE]}, 8)}

static func destination_slot(player: AdventurePlayer, index: int) -> int:
	ensure_objectives(player)
	var sites: Dictionary = player.world.expansion.get("objectives", {})
	if index == 1: return int(sites.get("channel", -1))
	if index == 3:
		var found := int(sites.get("raider", -1))
		return found if found >= 0 else 4
	return -1

static func refresh_appearance(player: AdventurePlayer) -> void:
	player.world.expansion["freed_communities"] = player.refuge.get("quests", []).duplicate()
	player.world.expansion["liberated"] = bool(player.refuge.get("liberated", false))
	var banners: Array = []
	var colors := ["eee5c1", "458cbe", "886e9c", "be664b", "6a9c57"]
	for index in player.refuge.get("quests", []):
		var tile := Quests.site_tile(player.world, int(index) + 1)
		banners.append({"point": [tile.x, tile.y], "color": colors[int(index)]})
	if player.refuge.get("liberated", false): banners.append({"point": player.world.expansion["castle"].duplicate(), "color": "e0bc60", "anchor": [86, -104], "size": [24, 32]})
	player.world.expansion["banners"] = banners
	player.world.appearance_revision += 1
	player.world.appearance_changed.emit()

static func destination(player: AdventurePlayer, index: int) -> Dictionary:
	if stage(player, index) == 1:
		if index == 0 or (index == 1 and destination_slot(player, index) < 0):
			var port: Array = player.world.expansion["port"]
			return {"tile": Vector2i(port[0], port[1]), "name": "Refuge Harbor"}
		if index in [1, 3]:
			var slot := destination_slot(player, index)
			return {"tile": Quests.site_tile(player.world, slot), "name": WorldNames.site_name(player.world, slot)}
	return {"tile": Quests.site_tile(player.world, index + 1), "name": RefugeWorld.TOWNS[index]}

static func guidance(player: AdventurePlayer, index: int) -> String:
	var where := destination(player, index)
	if RefugeCampaign.completed(player, index): return "%s: pledge earned." % RefugeCampaign.QUESTS[index][1]
	if stage(player, index) == 1:
		if index == 0: return "Bread Road: carry the grain warrant to Refuge Harbor. The community provides the cargo."
		if index == 1: return "Harbor pact: survey the shared channel at %s, then return to Vodalian Haven." % where["name"]
		if index == 3: return "Mountain Road: confront the tribute-raider at %s." % where["name"]
	if stage(player, index) == 2: return "%s: return to %s and defeat %s." % [RefugeCampaign.QUESTS[index][1], where["name"], RefugeCampaign.QUESTS[index][3]]
	return "%s: hear the petition at %s." % [RefugeCampaign.QUESTS[index][1], where["name"]]

static func deliver(player: AdventurePlayer, index: int) -> bool:
	if not RefugeCampaign.on_island(player) or index not in [0, 1] or stage(player, index) != 1 or player.tile() != destination(player, index)["tile"]: return false
	set_stage(player, index, 2)
	return true

static func reward_options(player: AdventurePlayer, color: int) -> Array[String]:
	var out: Array[String] = []
	if color < 0 or color >= BUNDLES.size() or not RefugeCampaign.available(): return out
	var rule := CardShop.classic_rule(player).duplicate(true)
	# Include cards held for a full bag when deciding which copies may be offered.
	if not rule.is_empty():
		for card in player.refuge.get("pending", []): rule["owned"][card] = int(rule["owned"].get(card, 0)) + 1
	for round_index in REWARD_COUNT:
		for card in BUNDLES[color]:
			if out.size() == REWARD_COUNT: return out
			if CardRegistry.has_card(card) and CardShop.classic_allows(rule, card):
				out.append(card)
				if not rule.is_empty(): rule["owned"][card] = int(rule["owned"].get(card, 0)) + 1
	return out

static func choose_reward(player: AdventurePlayer, color: int) -> bool:
	var choices: Array = player.refuge.get("reward_choices", [])
	if choices.is_empty(): return false
	var cards := reward_options(player, color)
	if cards.size() != REWARD_COUNT: return false
	choices.pop_front()
	player.refuge["reward_choices"] = choices
	var pending: Array = player.refuge.get("pending", [])
	pending.append_array(cards)
	player.refuge["pending"] = pending
	RefugeCampaign.claim(player)
	return true

## Tasks can inspect inactive islands from metadata alone.
static func task_rows(data: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var extra: Dictionary = data.get("expansion", {})
	for index in 5:
		var done: bool = index in progress.get("quests", [])
		var stage := int(progress.get("stages", {}).get(str(index), 0))
		var slot := index + 1
		var title: String = RefugeCampaign.QUESTS[index][1]
		var objective: String = "Hear the petition at " + RefugeWorld.TOWNS[index] + "."
		if stage == 1:
			if index == 0: slot = -1
			if index == 1: slot = int(extra.get("objectives", {}).get("channel", -1))
			if index == 3: slot = int(extra.get("objectives", {}).get("raider", 4))
			if index == 3 and slot < 0: slot = 4
			var named := "Refuge Harbor" if slot < 0 else RegionObjectives.site_name(data, slot)
			objective = ("Carry the grain warrant to " if index == 0 else "Survey the shared channel at " if index == 1 else "Confront the tribute-raider at ") + named + "."
		elif stage == 2 or index in [2, 4]:
			objective = "Defeat %s at %s." % [RefugeCampaign.QUESTS[index][3], RefugeWorld.TOWNS[index]]
		var point: Array = extra.get("port", [-1, -1])
		var tile := Vector2i(point[0], point[1]) if slot < 0 else RegionObjectives.tile(data, slot)
		var task := AdventureTasks.row("pledge:%d" % index, "refuge", title, objective, tile)
		if done: AdventureTasks.completed(task, "Pledge earned at " + RefugeWorld.TOWNS[index] + ".")
		out.append(task)
	var point: Array = extra.get("castle", [-1, -1])
	var task := AdventureTasks.row("lord", "refuge", "Liberate the Last Refuge", "%d/5 pledges. The final deck needs at least 50%% Fallen Empires nonlands." % progress.get("quests", []).size(), Vector2i(point[0], point[1]))
	if progress.get("liberated", false): AdventureTasks.completed(task, "The island is free. Fallen Empires cards now reach the mainland.")
	out.append(task)
	if not progress.get("quests", []).is_empty():
		var reward := AdventureTasks.row("rewards", "refuge", "Collect pledge rewards", "Choose or collect your earned cards at a community or the castle.", Vector2i(point[0], point[1]))
		if progress.get("reward_choices", []).is_empty() and progress.get("pending", []).is_empty(): AdventureTasks.completed(reward, "All currently earned pledge rewards have been collected.")
		out.append(reward)
	return out
