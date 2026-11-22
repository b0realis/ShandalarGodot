class_name DataSites
extends RefCounted
## ADVENTURE PLUGINS, API 2 — THE INTERPRETER OF A SITES PLUGIN, one
## instance per plugin ([method AdventureSites.provider]). Model side: it
## reads the plugin's normalized `sites.json` ([method PluginSchema.read])
## and builds its places' panes, holds their conditions, applies their
## effects, prices their services and raises their dungeons. What a button
## does on the world screen is [code]site_journey.gd[/code]'s, reached by
## `load()` only (the h5-1 rule, as [DataRegion] reaches its journey).
##
## A PLACE'S PROGRESS ([member AdventurePlayer.sites], keyed by the plugin's
## id): `{uses: {"<site>.<action>": n}, flags: [names on], dungeons:
## {"<land>:<dungeon key>": encounter slot}}` — the uses counted for the
## plugin as a whole (a guild's branches on two lands share one count).
##
## A SERVICE'S PRICES: the n-th use of an action costs its n-th price; once
## every price is paid the action is gone (the Conjuration Wizard Guild's
## 2000, 4000, 8000 and 12000 gold, and then no more). An action with no
## prices is free and never used up.

const JOURNEY := "res://game/adventure/plugins/site_journey.gd"
## The most an action is counted, and the most flags and dungeons a
## plugin's progress keeps (a damaged save's more are dropped).
const MOST_USES := 1000
## Dungeon rules (`rules` bits of an encounter slot, [WorldClues.lines]).
const RULE_BITS := {"no_color": 0x10, "no_artifacts": 0x40, "no_instants": 0x80,
	"life_carries": 0x01, "life_adds": 0x02}
const COLORS: Array[String] = ["black", "blue", "green", "red", "white"]

var id := ""
## The scan whose data this reads ([member AdventurePlugins.revision]).
var revision := 0
var _data := {}


func _init(plugin_id: String) -> void:
	id = plugin_id
	revision = AdventurePlugins.revision


func data() -> Dictionary:
	if _data.is_empty():
		_data = AdventurePlugins.data(id)
	return _data


static func _journey() -> Script:
	return load(JOURNEY) as Script


## The normalized `sites.json`.
func file() -> Dictionary:
	return data().get("sites", {})


func site(key: String) -> Dictionary:
	return file().get("sites", {}).get(key, {})


func dungeon(key: String) -> Dictionary:
	return file().get("dungeons", {}).get(key, {})


## [param key]'s words in the plugin's text.json (else the engine's),
## filled with [param values].
func say(key: String, values := {}) -> String:
	return PluginText.say(data().get("text", {}), key, values)


## The plugin's name, a pane's subtitle by default.
func plugin_name() -> String:
	return String(data().get("manifest", {}).get("name", id))


# ---------------------------------------------------------- progress --

## [param player]'s progress with this plugin, {} for none (read only).
func progress(player: AdventurePlayer) -> Dictionary:
	return player.sites.get(id, {}) if player != null else {}


## The record to write into, made when missing.
func _state(player: AdventurePlayer) -> Dictionary:
	if not player.sites.has(id) or not player.sites[id] is Dictionary:
		player.sites[id] = {"uses": {}, "flags": [], "dungeons": {}}
	var state: Dictionary = player.sites[id]
	for part in ["uses", "dungeons"]:
		if not state.get(part) is Dictionary:
			state[part] = {}
	if not state.get("flags") is Array:
		state["flags"] = []
	return state


## How often [param player] had [param site]'s action [param action] done.
func uses(player: AdventurePlayer, site_key: String, action: String) -> int:
	var counted: Variant = progress(player).get("uses", {})
	return int(counted.get(site_key + "." + action, 0)) if counted is Dictionary else 0


func flag(player: AdventurePlayer, name: String) -> bool:
	var on: Variant = progress(player).get("flags", [])
	return on is Array and name in on


## The action [param action] of [param site_key] (the first pane naming
## it), {} for none.
func action_of(site_key: String, action: String) -> Dictionary:
	for pane in site(site_key).get("panes", []):
		for entry in pane.get("actions", []):
			if String(entry["id"]) == action:
				return entry
	return {}


## What [param site_key]'s [param action] costs [param player] now: its
## next price, 0 when it has none, −1 when every price is paid.
func price(player: AdventurePlayer, site_key: String, action: Dictionary) -> int:
	var prices: Array = action.get("prices", [])
	if prices.is_empty():
		return 0
	var done := uses(player, site_key, String(action["id"]))
	return int(prices[done]) if done < prices.size() else -1


func used_up(player: AdventurePlayer, site_key: String, action: Dictionary) -> bool:
	return price(player, site_key, action) < 0


## How many more times [param action] can be done (−1: without end).
func uses_left(player: AdventurePlayer, site_key: String, action: Dictionary) -> int:
	var prices: Array = action.get("prices", [])
	if prices.is_empty():
		return -1
	return maxi(0, prices.size() - uses(player, site_key, String(action["id"])))


## The land [param player] stands on, its key in a dungeon record.
static func land(player: AdventurePlayer) -> String:
	return AdventureRegions.id(player.world)


## The encounter slot of dungeon [param key] this plugin raised on
## [param player]'s land, −1 for none.
func dungeon_index(player: AdventurePlayer, key: String) -> int:
	var raised: Variant = progress(player).get("dungeons", {})
	if not raised is Dictionary:
		return -1
	var saved: Variant = (raised as Dictionary).get(land(player) + ":" + key, -1)
	var index := int(saved) if AdventurePlayer._is_number(saved) else -1
	# Slots 0–4 are the castles' on every land: never a raised dungeon.
	if index < DungeonDoors.CASTLES or index >= mini(player.world.encounters.size(), WorldClues.MOST_SLOTS):
		return -1
	# THE SLOT MUST SAY IT IS THIS DUNGEON ([constant WorldClues.RAISED]; the
	# review of 2026-11-21): a damaged save's record pointed at a 1997
	# dungeon read "open" for good, and the place took its price for a
	# dungeon [method spawn] then never raised.
	var slot: Dictionary = player.world.encounters[index]
	var mark: Variant = slot.get(WorldClues.RAISED)
	if mark is String and String(mark) != "":
		return index if String(mark) == id + ":" + key else -1
	# A 0.70.4 save, from before the mark: its vault is found where only a
	# raised dungeon stands — past 1997's fifteen on the mainland; on another
	# land past the castles' slots and under the name this dungeon was given
	# (the land's own cave has the land's) — and marked from now on.
	var mainland := AdventureRegions.mainland(player)
	if mainland and index < WorldClues.SLOTS:
		return -1
	if not mainland and (dungeon(key).is_empty() or WorldNames.dungeon_name(index, player.world) != String(dungeon(key).get("name", key)) \
			or not _named(player.world, index)):
		return -1
	slot[WorldClues.RAISED] = id + ":" + key
	player.world.touch()
	return index


## Whether [param world] keeps a name of its own for slot [param index]
## (`expansion.dungeon_names`, as [method spawn] writes one).
static func _named(world: ShandalarWorld, index: int) -> bool:
	var names: Variant = world.expansion.get("dungeon_names", {})
	return names is Dictionary and (names as Dictionary).get(str(index)) is String


## "none", "open" (it still holds a card) or "cleared".
func dungeon_state(player: AdventurePlayer, key: String) -> String:
	var index := dungeon_index(player, key)
	if index < 0:
		return "none"
	return "open" if WorldClues.holds_cards(player.world.encounters[index]) else "cleared"


# -------------------------------------------------------- conditions --

func holds(player: AdventurePlayer, site_key: String, conditions: Array) -> bool:
	for condition in conditions:
		if not _holds(player, site_key, condition):
			return false
	return true


func _holds(player: AdventurePlayer, site_key: String, condition: Dictionary) -> bool:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	match key:
		"flag": return flag(player, String(value))
		"not_flag": return not flag(player, String(value))
		"gold_at_least": return player.gold >= int(value)
		"on_mainland": return AdventureRegions.mainland(player) == bool(value)
		"used":
			var done := uses(player, site_key, String(value["action"]))
			return done >= int(value.get("min", 0)) and done <= int(value.get("max", MOST_USES))
		"used_up": return used_up(player, site_key, action_of(site_key, String(value)))
		"dungeon": return dungeon_state(player, String(value["dungeon"])) == String(value["state"])
	return false


# --------------------------------------------------------------- panes --

## The placeholders' values for [param site_key]'s [param action] ({} for
## a pane's lines).
func values(player: AdventurePlayer, site_key: String, action := {}, more := {}) -> Dictionary:
	var out := {"hero": player.name if player != null else "", "gold": player.gold if player != null else 0,
		"region": AdventureExpansions.label(land(player), player) if player != null else ""}
	if not action.is_empty():
		out["price"] = maxi(0, price(player, site_key, action))
		var left := uses_left(player, site_key, action)
		out["uses_left"] = left if left >= 0 else ""
	for spawned in file().get("dungeons", {}):
		if dungeon_index(player, spawned) >= 0:
			out["dungeon"] = WorldNames.dungeon_name(dungeon_index(player, spawned), player.world)
	out.merge(more, true)
	return out


func _lines(player: AdventurePlayer, site_key: String, entries: Array, filled: Dictionary) -> Array:
	var out: Array = []
	for entry in entries:
		if entry is String:
			out.append(say(entry, filled))
		elif holds(player, site_key, entry.get("when", [])):
			out.append(say(String(entry["text"]), filled))
	return out


## THE PANE OF PLACE [param site_key] for [param player]: the first pane
## whose `when` holds — its lines, and each action whose `when` holds and
## that is not used up, `[button, words, ready]` (ready: the hero carries
## its price, and for a copy has a card to copy and room for it).
func describe(player: AdventurePlayer, site_key: String) -> Dictionary:
	var place := site(site_key)
	if place.is_empty():
		return {}
	var pane := {}
	for option in place.get("panes", []):
		if holds(player, site_key, option.get("when", [])):
			pane = option
			break
	var filled := values(player, site_key)
	var actions: Array = []
	for action in pane.get("actions", []):
		if not holds(player, site_key, action.get("when", [])):
			continue
		var name := String(action["id"])
		match String(action["do"]):
			"leave":
				actions.append([id + AdventureSites.LEAVE, say(String(action.get("label", "site.leave"))), true])
			_:
				if used_up(player, site_key, action):
					continue
				var words := values(player, site_key, action)
				actions.append([id + AdventureSites.ACT + site_key + ":" + name,
					say(String(action.get("label", "site.pay")), words), refusal(player, site_key, action) == ""])
	return {"expansion": id, "kind": AdventureSites.PANE_KIND, "site": site_key, "slot": -1,
		"name": say(String(pane["title"]), filled) if pane.has("title") else String(place.get("name", site_key)),
		"subtitle": say(String(pane["subtitle"]), filled) if pane.has("subtitle") else plugin_name(),
		"picture": String(pane.get("picture", place.get("picture", "visit_city"))),
		"lines": _lines(player, site_key, pane.get("lines", []), filled), "actions": actions}


## WHY [param site_key]'s [param action] cannot be done now, in the
## plugin's words; "" when it can: its conditions hold, it is not used up,
## the hero carries its price — and for a copy, a card may be copied and
## the bag has room.
func refusal(player: AdventurePlayer, site_key: String, action: Dictionary) -> String:
	if action.is_empty() or not holds(player, site_key, action.get("when", [])) or used_up(player, site_key, action):
		return say("site.done")
	var cost := price(player, site_key, action)
	if player.gold < cost:
		return say("site.no_gold", {"price": cost, "gold": player.gold})
	if String(action["do"]) == "copy_card":
		if player.bag_room() < 1:
			return say("site.bag_full")
		if copyable(player).is_empty():
			return say("site.no_cards")
	return ""


## The pane after an action, [param lines] (its `result`, else nothing to
## add) with a way back to the place and out.
func result_place(player: AdventurePlayer, site_key: String, lines: Array) -> Dictionary:
	var pane := describe(player, site_key)
	pane["lines"] = lines
	pane["actions"] = [[id + AdventureSites.BACK + site_key, say("site.back"), true], [id + AdventureSites.LEAVE, say("site.leave"), true]]
	return pane


# ------------------------------------------------------------ actions --

## A SERVICE DONE: [param site_key]'s effects action [param action] paid
## and its effects applied, its use counted. The pane to show next: its
## `result` lines (none: the place's pane again), or why it could not be
## done — nothing paid then.
func do_effects(player: AdventurePlayer, site_key: String, action: String) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "effects":
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	if why == "":
		why = _spawn_problem(player, entry, site_key)
	if why != "":
		return result_place(player, site_key, [why])
	var cost := price(player, site_key, entry)
	var filled := values(player, site_key, entry)
	player.gold -= cost
	_count(player, site_key, action)
	apply(player, site_key, entry.get("effects", []), filled)
	if (entry.get("result", []) as Array).is_empty():
		return describe(player, site_key)
	return result_place(player, site_key, _lines(player, site_key, entry["result"], values(player, site_key, {}, {"price": cost})))


## A COPY MADE: [param site_key]'s copy action [param action] paid and one
## more [param card] in the bag ([method AdventurePlayer.add_card]), its
## use counted — only a card the hero holds and may hold one more of
## ([method copyable]).
func copy_card(player: AdventurePlayer, site_key: String, action: String, card: String) -> Dictionary:
	var entry := action_of(site_key, action)
	if entry.is_empty() or String(entry["do"]) != "copy_card":
		return describe(player, site_key)
	var why := refusal(player, site_key, entry)
	if why == "" and not copyable(player).has(card):
		why = say("site.no_cards")
	if why != "":
		return result_place(player, site_key, [why])
	var cost := price(player, site_key, entry)
	if not player.add_card(card):
		return result_place(player, site_key, [say("site.bag_full")])
	player.gold -= cost
	_count(player, site_key, action)
	var filled := values(player, site_key, {}, {"price": cost, "card": card})
	player.log_event("site", say("site.copied_log", filled), {"card": card, "site": id + ":" + site_key})
	var lines := _lines(player, site_key, entry.get("result", []), filled)
	return result_place(player, site_key, lines if not lines.is_empty() else [say("site.copied", filled)])


func _count(player: AdventurePlayer, site_key: String, action: String) -> void:
	var counted: Dictionary = _state(player)["uses"]
	var key := site_key + "." + action
	counted[key] = mini(MOST_USES, int(counted.get(key, 0)) + 1)


## The hero's cards a copy may be made of, `{name: count}`: every card
## they hold, but under the Classic MTG rules none they hold every copy of
## the rules allow ([method CardShop.classic_rule]) — the wise man's rule
## for his copy.
static func copyable(player: AdventurePlayer) -> Dictionary:
	# Counted here, not by CardListPane.counted: this side never names the
	# world UI (the h5-1 rule).
	var counted := {}
	for row: Variant in player.cards:
		if row is Dictionary and String(row.get("card", "")) != "":
			counted[String(row["card"])] = int(counted.get(String(row["card"]), 0)) + 1
	var rule := CardShop.classic_rule(player)
	if rule.is_empty():
		return counted
	var out := {}
	for card_name in counted:
		if CardShop.classic_allows(rule, String(card_name)):
			out[card_name] = counted[card_name]
	return out


## Apply [param effects] in order for place [param site_key].
func apply(player: AdventurePlayer, site_key: String, effects: Array, filled := {}) -> void:
	for effect in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		var state := _state(player)
		match key:
			"set_flag":
				if not value in state["flags"]: (state["flags"] as Array).append(String(value))
			"clear_flag": (state["flags"] as Array).erase(String(value))
			"gold": player.gold = maxi(0, player.gold + int(value))
			"food": player.food = maxi(0, player.food + int(value))
			"spawn_dungeon": spawn(player, String(value), site_key)
			"log_clue": player.log_clue(say(String(value["text"]), values(player, site_key, {}, filled)), "clue")
			"log_event":
				var words := say(String(value["text"]), values(player, site_key, {}, filled))
				if bool(value.get("done", false)): player.log_event(String(value["event"]), words, {"done": true})
				else: player.log_event(String(value["event"]), words)


## Why the effects of [param entry] cannot be applied on this land, ""
## when they can: a dungeon to raise and no slot or tile left for it.
func _spawn_problem(player: AdventurePlayer, entry: Dictionary, site_key := "") -> String:
	for effect in entry.get("effects", []):
		if effect.keys()[0] != "spawn_dungeon":
			continue
		var key := String(effect["spawn_dungeon"])
		if dungeon_state(player, key) == "open":
			continue
		if player.world.encounters.size() >= WorldClues.MOST_SLOTS or _dungeon_tile(player, key, site_key).x < 0:
			return say("site.no_room")
	return ""


# ------------------------------------------------------------ dungeons --

## THE TILE PLACE [param site_key] STANDS ON in [param player]'s land
## ([member AdventureSites.KEY]), else the hero's — a dungeon it raises is
## measured from the place, wherever the hero stands.
func _here(player: AdventurePlayer, site_key := "") -> Vector2i:
	var placed: Variant = player.world.expansion.get(AdventureSites.KEY, {})
	var point: Variant = (placed as Dictionary).get(id + ":" + site_key) if placed is Dictionary else null
	if site_key != "" and AdventureRegions.valid_point(point):
		return Vector2i(int(point[0]), int(point[1]))
	return player.tile()


## The tile dungeon [param key] would rise on: land of the place's own
## land, one a moved dungeon could take ([method DungeonDoors.takes_dungeon])
## and away from every place ([method AdventureSites.points]), its distance
## from the place within the dungeon's `distance` (else the nearest such
## tile past `min`), drawn on the plugin's dice ([method
## AdventureSites.dice_for]) for this land, key and raising. (−1, −1) for none.
func _dungeon_tile(player: AdventurePlayer, key: String, site_key := "") -> Vector2i:
	var world := player.world
	var info := dungeon(key)
	var here := _here(player, site_key)
	var distance: Dictionary = info.get("distance", {})
	var least := float(distance.get("min", 6))
	var most := float(distance.get("max", 24))
	var portal := FinalBattle.portal_tile_of(player)
	# The tiles the land's places and anchorages keep, read once for every
	# tile asked (the review of 2026-11-21) — the places' own among them.
	var kept := DungeonDoors.kept_points(world)
	for point: Variant in AdventureSites.points(world):
		kept[Vector2i(int(point[0]), int(point[1]))] = true
	var inside: Array[Vector2i] = []
	var beyond: Array[Vector2i] = []
	for tile in RegionGeography.component(world, here):
		if kept.has(tile) or not DungeonDoors.takes_dungeon(world, tile, player.tile(), portal, kept):
			continue
		var far := tile.distance_to(here)
		if far < least:
			continue
		if far <= most:
			inside.append(tile)
		else:
			beyond.append(tile)
	if inside.is_empty() and not beyond.is_empty():
		beyond.sort_custom(func(a: Vector2i, b: Vector2i) -> bool: return a.distance_squared_to(here) < b.distance_squared_to(here))
		inside = beyond.slice(0, 8)
	if inside.is_empty():
		return Vector2i(-1, -1)
	var raised := int(_state(player)["uses"].get("dungeon:" + key, 0)) if player.sites.has(id) else 0
	var dice := AdventureSites.dice_for(world, int(file().get("salt", 0)), "%s:%s:%s:%d" % [id, land(player), key, raised])
	return inside[dice.below(inside.size())]


## DUNGEON [param key] RAISED on [param player]'s land — unless it is open
## there already: a new encounter slot (after the 1997 ones; [constant
## WorldClues.MOST_SLOTS] at most) on [method _dungeon_tile]'s tile, its
## color, size and rules the plugin's, its treasure the plugin's cards (by
## name, as cards put back in a dungeon are kept, [constant
## WorldClues.LEFT_CARDS]), everything about it known (where, its creatures,
## its rules), its name the plugin's ([method WorldNames.dungeon_name]). The
## slot, or −1 when none could be raised.
func spawn(player: AdventurePlayer, key: String, site_key := "") -> int:
	var info := dungeon(key)
	if info.is_empty() or player == null or player.world == null:
		return -1
	var open := dungeon_index(player, key)
	if open >= 0 and WorldClues.holds_cards(player.world.encounters[open]):
		return open
	var world := player.world
	if world.encounters.size() >= WorldClues.MOST_SLOTS:
		return -1
	var tile := _dungeon_tile(player, key, site_key)
	if tile.x < 0:
		return -1
	# Slots 0–4 are the wizards' castles on every land (an island keeps them
	# empty): a raised dungeon never takes one.
	while world.encounters.size() < DungeonDoors.CASTLES:
		world.encounters.append({"x": 0, "y": 0, "cards": [], "clues": 0})
	var state := _state(player)
	var raised := int(state["uses"].get("dungeon:" + key, 0))
	var dice := AdventureSites.dice_for(world, int(file().get("salt", 0)), "%s:%s:%s:%d:color" % [id, land(player), key, raised])
	var color_name := String(info.get("color", "random"))
	var color := COLORS.find(color_name) + 1 if color_name in COLORS else dice.below(5) + 1
	var rules := 0
	for rule in info.get("rules", []):
		rules |= int(RULE_BITS.get(String(rule), 0))
	var cards: Array[String] = []
	for card in info.get("cards", []):
		cards.append(String(card))
	var index := world.encounters.size()
	world.encounters.append({"x": tile.x, "y": tile.y, "town": _nearest_town(world, tile), "color": color,
		"monster_flags": DungeonBoard.LARGE if String(info.get("size", "small")) == "large" else 0,
		"rules": rules, "card_in_effect": -1, "cards": [], WorldClues.LEFT_CARDS: cards,
		"clues": WorldClues.LOCATION | WorldClues.CREATURES | WorldClues.RULES,
		WorldClues.RAISED: id + ":" + key})
	world.page[tile.y * ShandalarWorld.PAGE_WIDTH + tile.x] |= ShandalarWorld.DUNGEON
	world.touch_page()
	var names: Dictionary = world.expansion.get("dungeon_names", {}) if world.expansion.get("dungeon_names") is Dictionary else {}
	names[str(index)] = String(info.get("name", key))
	world.expansion["dungeon_names"] = names
	state["dungeons"][land(player) + ":" + key] = index
	state["uses"]["dungeon:" + key] = raised + 1
	world.appearance_revision += 1
	return index


## The town or city nearest [param tile] (a dungeon's clue says where it
## lies from one), 0 when the land has none.
static func _nearest_town(world: ShandalarWorld, tile: Vector2i) -> int:
	var best := 0
	var distance := INF
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		if int(site["type"]) < ShandalarWorld.VILLAGE or int(site["type"]) >= ShandalarWorld.CASTLE:
			continue
		var gap := tile.distance_squared_to(Vector2i(int(site["x"]), int(site["y"])))
		if gap < distance:
			distance = gap
			best = slot
	return best


## The panes' buttons (UI side, [code]site_journey.gd[/code]).
func act(screen: Node, action: String, place: Dictionary) -> bool:
	if not action.begins_with(id + "_"):
		return false
	return bool(_journey().call("act", self, screen, action, place))
