class_name AdventureTasks
extends RefCounted
## Live objectives are derived from campaign state, separate from the historical
## journal. Saved map metadata suffices; listing tasks never instantiates worlds.

static func world_data(player: AdventurePlayer, region: String) -> Dictionary:
	if region == AdventureRegions.id(player.world):
		return {"sites": player.world.sites, "encounters": player.world.encounters, "expansion": player.world.expansion}
	return player.regions.get(region, {}).get("world", {})

static func row(id: String, region: String, title: String, text: String, tile := Vector2i(-1, -1), kind := "quest") -> Dictionary:
	return {"id": region + "/" + id, "region": region, "title": title, "text": text, "tile": tile, "kind": kind, "name": title}

static var _key := []
static var _rows: Array[Dictionary] = []

static func rows(player: AdventurePlayer) -> Array[Dictionary]:
	if player == null or player.world == null: return []
	var key: Array = [player.get_instance_id(), player.world.get_instance_id(), AdventureExpansions.revision,
		player.expanded_adventure, player.packs, player.quest, player.quest_timer, player.expansions, player.defeated_wizards, player.portal,
		player.world.sites, player.world.encounters, player.world.expansion, player.siege_timer, player.siege_count, player.ended, player.task_sequence, WorldStatus.siege_town(player)]
	for region in player.regions:
		var saved: Dictionary = player.regions[region]
		var data: Dictionary = saved.get("world", {})
		key.append([region, saved.get("record", {}).get("quest", {}), saved.get("clocks", {}).get("quest_timer", 0), data.get("sites", []), data.get("encounters", []), data.get("expansion", {})])
	if key != _key:
		_key = key.duplicate(true)
		_rows = _history(player, _build(player))
	return _rows

static func _build(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	if player == null or player.world == null: return out
	var active := AdventureRegions.id(player.world)
	var regions: Array = [active]
	for id in player.regions:
		if id != active: regions.append(id)
	for region in regions:
		var data := world_data(player, region)
		if region != AdventureRegions.MAINLAND and not AdventureExpansions.launch_enabled:
			var port: Array = data.get("expansion", {}).get("port", [])
			if region == active and port.size() == 2:
				out.append(row("return", region, "Return to Shandalar", "Free passage home is always available.", Vector2i(port[0], port[1]), "navigation"))
			continue
		var creatures: Array = player.monsters if region == active else data.get("monsters", [])
		for creature in creatures:
			if int(creature.get("slot", -1)) != Sieges.SLOT or not creature.has("town"): continue
			var town := int(creature["town"])
			var task := row("siege:%d:%d" % [town, player.siege_count], region, "Lift the siege at " + RegionObjectives.site_name(data, town), "Defeat the besieger before the town falls.", RegionObjectives.tile(data, town), "siege")
			var clock := player.siege_timer if region == active else int(player.regions[region].get("clocks", {}).get("siege_timer", 0))
			task["timer_steps"] = posmod(Sieges.RESOLVE_AT - (clock & 63), 64)
			task["timer_unit"] = "siege steps"
			task["paused"] = region != active
			out.append(task)
		var quest: Dictionary = player.quest if region == active else player.regions[region].get("record", {}).get("quest", {})
		if not quest.is_empty():
			var type := int(quest.get("type", 0))
			var destination := int(quest.get("giver", -1)) if type < Quests.DEFEATED else int(quest.get("destination", -1))
			var place := RegionObjectives.site_name(data, destination)
			var text := "Return to " + place if type < Quests.DEFEATED else "Deliver to " + place
			var tile := RegionObjectives.tile(data, destination)
			if type < 0 and type >= Quests.DEFEATED:
				text = "Find and defeat " + CreatureBook.name_of(-type) + ". The challenger roams this region."
				tile = Vector2i(-1, -1)
			elif type == Quests.CARD: text = "Bring %s to %s." % [Quests.spell_name(int(quest.get("color", 1)), int(quest.get("destination", 0))), place]
			var description := text
			var clock := player.quest_timer if region == active else int(player.regions[region].get("clocks", {}).get("quest_timer", 0))
			var left := int(quest.get("deadline", 0)) - clock
			var days := left / WorldStatus.DAY + 1 if left > 0 else 0
			text += " %d day%s left%s." % [days, "" if days == 1 else "s", " (paused while away)" if region != active else ""]
			var task := row(errand_id(quest), region, "Town errand", text, tile)
			task["description"] = description
			task["timer_steps"] = maxi(0, left)
			task["timer_unit"] = "days"
			task["paused"] = region != active
			out.append(task)
		if region != AdventureRegions.MAINLAND:
			var content := AdventureExpansions.provider(region)
			if content != null and content.has_method("task_rows"):
				out.append_array(content.call("task_rows", data, AdventureExpansions.progress(player, region)))
			var point: Array = data.get("expansion", {}).get("port", [])
			if region == active and point.size() == 2: out.append(row("return", region, "Return to Shandalar", "Free passage home is always available.", Vector2i(point[0], point[1]), "navigation"))
		else:
			for color in 5:
				var castle: Dictionary = data.get("encounters", [])[color] if data.get("encounters", []).size() > color else {}
				if not castle.is_empty():
					var task := row("wizard:%d" % color, region, WorldNames.WIZARDS[color], "Defeat this wizard in their castle.", Vector2i(castle.get("x", -1), castle.get("y", -1)))
					if AdventurePlayer.COLORS[color] in player.defeated_wizards: completed(task, "This wizard has been defeated.")
					out.append(task)
			var portal := FinalBattle.portal_tile_of(player) if not player.portal.is_empty() else Vector2i(-1, -1)
			if player.portal.get("state", "") == FinalBattle.PORTAL_OPEN or player.ended == AdventurePlayer.ENDED_WON:
				var task := row("finale", region, "Arzakon's portal", "Enter the final challenge when you are prepared.", portal, "portal")
				if player.ended == AdventurePlayer.ENDED_WON: completed(task, "Arzakon has been banished.")
				out.append(task)
			for id in AdventureExpansions.definitions():
				if not AdventureExpansions.launch_enabled: continue
				var visited: bool = player.regions.has(id) or id == active
				if not visited and not AdventureExpansions.enabled_for(player, id): continue
				var point: Array = data.get("expansion", {}).get("entries", {}).get(id, [])
				if point.size() == 2:
					var task := row("voyage:" + id, region, "Visit " + AdventureExpansions.label(id), "Speak to the captain about this optional expedition.", Vector2i(point[0], point[1]))
					if visited: completed(task, "You have reached this region. Further voyages remain available.")
					out.append(task)
		var encounters: Array = data.get("encounters", [])
		for slot in range(5, encounters.size()):
			var dungeon: Dictionary = encounters[slot]
			if int(dungeon.get("clues", 0)) & WorldClues.LOCATION == 0: continue
			# The region's own name, else the 1997 name the clues and the visit
			# pane give it (0.60.13 bug campaign, h2-4: "Dungeon 1" before).
			var title: String = data.get("expansion", {}).get("dungeon_names", {}).get(str(slot), WorldNames.dungeon_name(slot))
			if title == "": title = "Dungeon %d" % (slot - 4)
			var task := row("dungeon:%d" % slot, region, title, "Find and enter this known dungeon. Its clues remain below.", Vector2i(dungeon.get("x", -1), dungeon.get("y", -1)), "clue")
			if int(dungeon.get("entered", 0)) > 0: completed(task, "Dungeon visited. You can return to explore its remaining rooms.")
			out.append(task)
	# Do not retain inactive providers just because the Tasks page inspected them.
	AdventureExpansions.release_inactive(active)
	return out

## [QoL] THE TASKS THAT GUIDE THE ARROWS (the owner's ruling of 2026-11-03:
## *"In tasks a user can choose multiple arrows"*): several tasks at once, an
## arrow each; none chosen is Automatic guidance, the default. Each chosen
## task's history entry carries [constant GUIDED], so the choice is saved
## with the history. The old single string ([member AdventurePlayer.tracked_task],
## saved as "selected") names the choice when it is one task and is empty
## when it is several: 0.60.12 and older read several as Automatic guidance.
## A choice made in that string alone (a save from 0.60.12 or older, a direct
## assignment) replaces the flags.
const GUIDED := "guided"

## The tasks chosen to guide. A task hidden for now (its region's tasks out
## of this launch, its pack off) stays chosen (0.60.13 bug campaign, h2-7).
static func tracked(player: AdventurePlayer) -> Array[String]:
	var out: Array[String] = []
	if player == null: return out
	rows(player) # the history up to date: a finished task is chosen no more
	for id in player.task_history:
		var entry: Dictionary = player.task_history[id]
		var guided: Variant = entry.get(GUIDED, false)
		if guided is bool and guided and entry.get("status") == "active": out.append(id)
	if player.tracked_task == (out[0] if out.size() == 1 else ""): return out
	for id in out: player.task_history[id].erase(GUIDED)
	out.clear()
	if player.task_history.get(player.tracked_task, {}).get("status", "") == "active":
		player.task_history[player.tracked_task][GUIDED] = true
		out.append(player.tracked_task)
	else: player.tracked_task = ""
	return out

## Guide the arrows to [param id] alone, or "" for Automatic guidance.
static func select(player: AdventurePlayer, id: String) -> bool:
	if id != "" and not _choosable(player, id): return false
	for chosen in tracked(player): player.task_history[chosen].erase(GUIDED)
	if id != "": player.task_history[id][GUIDED] = true
	player.tracked_task = id
	return true

## [QoL] Add [param id]'s arrow to the others, or take it away (the ruling of
## 2026-11-03).
static func toggle(player: AdventurePlayer, id: String) -> bool:
	if not _choosable(player, id): return false
	var chosen := tracked(player)
	if chosen.has(id):
		player.task_history[id].erase(GUIDED)
		chosen.erase(id)
	else:
		player.task_history[id][GUIDED] = true
		chosen.append(id)
	player.tracked_task = chosen[0] if chosen.size() == 1 else ""
	return true

static func _choosable(player: AdventurePlayer, id: String) -> bool:
	var live := rows(player).any(func(task: Dictionary) -> bool: return task["id"] == id and task.get("status", "active") == "active")
	return live and player.task_history.has(id)

## Whether [param target] ([method WorldStatus.targets]) is Arzakon's portal,
## open or petrified.
static func portal(target: Dictionary) -> bool:
	return String(target.get("kind", "")) in [FinalBattle.PORTAL_KIND, FinalBattle.MONUMENT_KIND]

## THE ARROWS: one for each chosen task (a task in another region: the ship
## there), else the first of [param ordinary] ([method WorldStatus.targets])
## that is not the portal; and Arzakon's portal whenever it is a target,
## last so it is drawn over the others and marked `overlay` — the Tasks
## tab's switch hides that one ([method WorldGuides.drawn]; the ruling of
## 2026-11-03). When no chosen task can be reached (its region's pack off,
## or hidden this launch) the automatic guidance takes over (0.60.13 bug
## campaign, h1-4), and nothing is unchosen (h2-7).
static func guide(player: AdventurePlayer, ordinary: Array[Dictionary]) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var chosen := tracked(player)
	var following := false
	if not chosen.is_empty():
		for task in rows(player):
			if not chosen.has(task["id"]) or task.get("status", "active") != "active": continue
			var target := _toward(player, task)
			if target.is_empty(): continue
			following = true
			if target["tile"].x >= 0 and not _pointed(out, target["tile"]): out.append(target)
	if not following:
		for target in ordinary:
			if not portal(target):
				out.append(target)
				break
	for target in ordinary:
		if portal(target) and not _pointed(out, target["tile"]):
			var mark := target.duplicate()
			mark["overlay"] = true
			out.append(mark)
	return out

## Where [param task]'s arrow points: the task itself in this region, the
## ship toward its region from another; {} when the way is shut.
static func _toward(player: AdventurePlayer, task: Dictionary) -> Dictionary:
	var active := AdventureRegions.id(player.world)
	if task["region"] == active: return task
	var point: Array = player.world.expansion.get("port", [])
	if active == AdventureRegions.MAINLAND:
		if not AdventureExpansions.enabled_for(player, task["region"]): return {}
		point = player.world.expansion.get("entries", {}).get(task["region"], [])
	if point.size() != 2: return {}
	var ship := task.duplicate()
	ship["tile"] = Vector2i(point[0], point[1])
	ship["name"] = "Ship toward " + AdventureExpansions.label(task["region"])
	return ship

## One arrow to a place: two chosen tasks there (two ships to one region)
## share it.
static func _pointed(out: Array[Dictionary], tile: Vector2i) -> bool:
	return out.any(func(target: Dictionary) -> bool: return target["tile"] == tile)

static func remember(player: AdventurePlayer, text: String, kind: String) -> void:
	var region := AdventureRegions.id(player.world)
	for clue in player.known_clues:
		if clue["region"] == region and clue["text"] == text and clue["kind"] == kind: return
	player.known_clues.append({"region": region, "text": text, "kind": kind, "day": WorldStatus.days_on_road(player)})

static func read(player: AdventurePlayer, saved: Variant) -> void:
	var data: Dictionary = saved if saved is Dictionary else {}
	player.tracked_task = String(data.get("selected", "")) if data.get("selected", "") is String else ""
	player.task_history = {}
	player.task_sequence = 0
	player.known_clues = []
	_key.clear()
	var history: Variant = data.get("history", {})
	if history is Dictionary:
		for id in history:
			var entry: Variant = history[id]
			if not id is String or id.length() > 200 or not entry is Dictionary: continue
			var valid := true
			for field in ["title", "text", "region", "kind", "status"]:
				if not entry.get(field) is String or entry[field].length() > 4096: valid = false
			if not valid or entry["status"] not in ["active", "completed", "expired", "failed"]: continue
			if not AdventurePlayer._is_number(entry.get("order")) or entry["order"] < 0 or entry["order"] > 1000000000: continue
			var kept: Dictionary = entry.duplicate(true)
			if not kept.get(GUIDED, false) is bool: kept.erase(GUIDED)
			# An errand's id floated in 0.60.12 after a load ("errand:8.0:63.0",
			# h2-3): mended, its twin dropped, its tracking moved.
			var whole := _whole_errand(id)
			if whole != id:
				if player.tracked_task == id: player.tracked_task = whole
				if history.has(whole): continue
			player.task_history[whole] = kept
			player.task_sequence = maxi(player.task_sequence, int(entry["order"]))
	var clues: Variant = data.get("clues", [])
	if clues is Array:
		for clue in clues:
			if not clue is Dictionary or not clue.get("region") is String or not clue.get("text") is String: continue
			if clue["text"].length() > 4096 or clue["region"].length() > 100: continue
			if not clue.get("kind", "clue") is String or not AdventurePlayer._is_number(clue.get("day", 0)): continue
			player.known_clues.append({"region": clue["region"], "text": clue["text"], "kind": String(clue.get("kind", "clue")), "day": int(clue.get("day", 0))})
	if not data.has("clues"):
		for entry in player.journal:
			if entry.get("event", "") in ["clue", "quest_clue"]:
				player.known_clues.append({"region": entry.get("region", "mainland"), "text": entry.get("text", ""), "kind": entry["event"], "day": entry.get("day", 0)})


## Whole numbers: a region saved away is read back from JSON as floats
## (0.60.13 bug campaign, h2-3).
static func errand_id(quest: Dictionary) -> String:
	return "errand:%d:%d" % [int(quest.get("giver", -1)), int(quest.get("deadline", 0))]

static func _whole_errand(id: String) -> String:
	var at := id.find("/errand:")
	if at < 0 or not id.contains("."): return id
	var parts := id.substr(at + 8).split(":")
	if parts.size() != 2 or not parts[0].is_valid_float() or not parts[1].is_valid_float(): return id
	return id.substr(0, at) + "/errand:%d:%d" % [int(float(parts[0])), int(float(parts[1]))]

static func completed(task: Dictionary, description: String) -> void:
	task["status"] = "completed"
	task["text"] = description

## Archive only explicit outcomes. A task vanishing is not proof of victory.
static func finish(player: AdventurePlayer, local_id: String, status := "completed") -> void:
	var id := AdventureRegions.id(player.world) + "/" + local_id
	rows(player) # remember even a quest never opened in the Tasks pane
	if player.task_history.has(id):
		player.task_history[id]["status"] = status
		player.task_sequence += 1
		player.task_history[id]["order"] = player.task_sequence
		player.task_history[id]["text"] = "Task completed." if status == "completed" else "The deadline expired." if status == "expired" else "The objective was not achieved."
	_key.clear()

static func _history(player: AdventurePlayer, live: Array[Dictionary]) -> Array[Dictionary]:
	var found := {}
	var batch := player.task_sequence + 1
	for task in live:
		var id: String = task["id"]
		found[id] = true
		var status: String = task.get("status", "active")
		var entry: Dictionary = player.task_history.get(id, {})
		if entry.is_empty() or entry.get("status") != status:
			entry = {"order": batch}
			player.task_sequence = batch
		for field in ["title", "text", "region", "kind"]: entry[field] = task[field]
		entry["status"] = status
		player.task_history[id] = entry
		task["status"] = status
		task["order"] = entry["order"]
	for id in player.task_history:
		var entry: Dictionary = player.task_history[id]
		if found.has(id) or entry["status"] == "active" or entry["kind"] == "navigation": continue
		var task := row("", entry["region"], entry["title"], entry["text"], Vector2i(-1, -1), entry["kind"])
		task["id"] = id
		task["status"] = entry["status"]
		task["order"] = entry["order"]
		live.append(task)
	live.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		var a_done: bool = a["status"] != "active"
		var b_done: bool = b["status"] != "active"
		if a_done != b_done: return not a_done
		if a["order"] != b["order"]: return a["order"] > b["order"]
		return a["id"] < b["id"])
	return live

static func timer_text(task: Dictionary) -> String:
	if task.get("status", "active") != "active" or not task.has("timer_steps"): return ""
	var steps := int(task["timer_steps"])
	var text: String
	if task["timer_unit"] == "days":
		var days := float(steps) / WorldStatus.DAY
		text = "Time left: %.1f campaign days" % days if days >= 1 else "Time left: less than a campaign day" if steps > 0 else "Time left: expired"
	else: text = "Siege countdown: %d clock steps" % steps
	return text + (" · PAUSED while away" if task.get("paused", false) else "")

static func timer_color(task: Dictionary) -> Color:
	if task.get("paused", false): return Color("9bd8ef")
	var steps := int(task.get("timer_steps", 0))
	var critical := WorldStatus.DAY if task.get("timer_unit") == "days" else 4
	return Color("ff9494") if steps <= critical else Color("f1c46c") if steps <= critical * 2 else Color("a8d7a0")
