class_name DataRegion
extends RefCounted
## ADVENTURE PLUGINS — the interpreter. One instance per plugin, answering
## every hook [AdventureExpansions] dispatches (the hooks the built-in Last
## Refuge provider answered until 0.60.19) from the plugin's validated data
## ([PluginSchema]). Nothing of a plugin is ever run: its quests are a stage
## machine read from `quests.json`, its panes are built from `places.json`,
## its words come from `text.json`, its island from `world.json`
## ([IslandGenerator]), its foes and rewards from `foes.json` and
## `rewards.json`.
##
## THE STAGE MACHINE. A quest is an ordered list of steps — `accept` (at
## the giver), `go` (to a target, with a button there), `duel` (the quest's
## foe at a target; always the last step). The stage saved in the progress
## record is the number of steps done; the quest is done when its duel is
## won. So the Last Refuge's saved stages keep their meaning: the Bread
## Road's 0, 1, 2 are "hear the petition", "carry the warrant", "defeat the
## tithe-collector".
##
## THE PROGRESS RECORD stays the one the built-in Refuge saved:
## `{quests, pending, stages, reward_choices}` plus each declared flag.
##
## MODEL SIDE (the h5-1 rule): this file names no screen, pane, HUD nor
## autoload. The panes' buttons and the duels live in
## `plugin_journey.gd`, reached by [method _journey] at run time only.

const JOURNEY := "res://game/adventure/plugins/plugin_journey.gd"
const SITE_TYPES := [ShandalarWorld.TOWN, ShandalarWorld.CITY, ShandalarWorld.VILLAGE]

var id := ""
var _given := {}
var _data := {}
var _seen := -1
static var _ui: Script = null


## [param plugin_id]'s interpreter. [param given] supplies the data
## directly (tests and tools); otherwise it is [method AdventurePlugins.data].
func _init(plugin_id: String, given := {}) -> void:
	id = plugin_id
	_given = given


## The plugin's normalized data ({} when it is not a valid plugin).
func data() -> Dictionary:
	if not _given.is_empty(): return _given
	if _seen != AdventurePlugins.revision or _data.is_empty():
		_data = AdventurePlugins.data(id)
		_seen = AdventurePlugins.revision
	return _data


static func _journey() -> Script:
	if _ui == null: _ui = load(JOURNEY)
	return _ui


# --------------------------------------------------------- the content --

func _part(name: String) -> Dictionary:
	var part: Variant = data().get(name, {})
	return part if part is Dictionary else {}


func quests() -> Array:
	return _part("quests").get("quests", [])


func quest_count() -> int:
	return quests().size()


func _quest(index: int) -> Dictionary:
	var all := quests()
	return all[index] if index >= 0 and index < all.size() else {}


func _finale() -> Dictionary:
	return _part("quests").get("finale", {})


func _marker(kind: String) -> Dictionary:
	return _part("places").get("markers", {}).get(kind, {})


func _flags() -> Array:
	return _part("quests").get("flags", [])


## [param key]'s words with [param values] ([PluginText]).
func say(key: String, values := {}) -> String:
	return PluginText.say(_part("text"), key, values)


## The region's title (the manifest's `region.title`).
func title() -> String:
	var region: Variant = data().get("manifest", {}).get("region", {})
	return String(region.get("title", id)) if region is Dictionary else id


func subtitle() -> String:
	var words := say("region.subtitle")
	return words if words != "" else title()


## The name of quest [param index]'s giver town.
func giver_name(index: int) -> String:
	var slot := int(_quest(index).get("giver", -1))
	for part in ["towns", "places"]:
		for row in _part("world").get(part, {}).get("list", []):
			if int(row["slot"]) == slot: return String(row["name"])
	return ""


## The quest given at town [param slot], -1 for none.
func quest_at(slot: int) -> int:
	var all := quests()
	for index in all.size():
		if int(all[index]["giver"]) == slot: return index
	return -1


## Quest [param quest]'s foe, or the finale's for -1: `{name, life, face,
## deck, deck_name?}`.
func foe_for(quest: int) -> Dictionary:
	var name := String(_quest(quest).get("foe", "")) if quest >= 0 else String(_finale().get("foe", ""))
	return _part("foes").get("foes", {}).get(name, {})


## [param foe]'s deck as a list of card names, in its file's order.
static func deck_of(foe: Dictionary) -> Array:
	var out: Array = []
	var cards: Dictionary = foe.get("deck", {})
	for card in cards:
		for copy in int(cards[card]): out.append(card)
	return out


# ----------------------------------------------------------- progress --

func initial_progress() -> Dictionary:
	var out := {"quests": [], "pending": []}
	for flag in _flags(): out[flag] = false
	return out


## The live progress record, {} when there is none.
func progress(player: AdventurePlayer) -> Dictionary:
	return AdventureExpansions.progress(player, id) if player != null else {}


## The live progress record, made when absent.
func _state(player: AdventurePlayer) -> Dictionary:
	if not player.expansions.has(id) or not player.expansions[id] is Dictionary:
		player.expansions[id] = initial_progress()
	return player.expansions[id]


func flag(player: AdventurePlayer, name: String) -> bool:
	return bool(progress(player).get(name, false))


func on_island(player: AdventurePlayer) -> bool:
	return player != null and player.world != null and AdventureRegions.id(player.world) == id


## The plugin is valid and its card packs are on ([method AdventureExpansions.enabled]).
func available() -> bool:
	return AdventureExpansions.enabled(id)


func completed(player: AdventurePlayer, quest: int) -> bool:
	return quest in progress(player).get("quests", [])


func done_count(player: AdventurePlayer) -> int:
	return progress(player).get("quests", []).size()


func stage(player: AdventurePlayer, index: int) -> int:
	return int(progress(player).get("stages", {}).get(str(index), 0))


func set_stage(player: AdventurePlayer, index: int, value: int) -> void:
	var state := _state(player)
	var stages: Dictionary = state.get("stages", {})
	stages[str(index)] = value
	state["stages"] = stages
	player.log_clue(guidance(player, index), "quest_clue")


## Quest [param index]'s current step (its last once all are done).
func step(player: AdventurePlayer, index: int) -> Dictionary:
	var steps: Array = _quest(index).get("steps", [])
	if steps.is_empty(): return {}
	return steps[clampi(stage(player, index), 0, steps.size() - 1)]


## Accept quest [param index]'s petition: its first step is `accept`.
func start(player: AdventurePlayer, index: int) -> bool:
	var steps: Array = _quest(index).get("steps", [])
	if not on_island(player) or steps.is_empty() or String(steps[0]["do"]) != "accept" or stage(player, index) != 0 or completed(player, index): return false
	set_stage(player, index, 1)
	return true


## Its duel is the current step and it is not done.
func ready(player: AdventurePlayer, index: int) -> bool:
	var steps: Array = _quest(index).get("steps", [])
	return not steps.is_empty() and stage(player, index) >= steps.size() - 1 and not completed(player, index)


## Finish the current `go` step where it leads.
func deliver(player: AdventurePlayer, index: int) -> bool:
	var steps: Array = _quest(index).get("steps", [])
	var at := stage(player, index)
	if not on_island(player) or at >= steps.size() or String(steps[at]["do"]) != "go" or completed(player, index): return false
	if player.tile() != destination(player, index)["tile"]: return false
	set_stage(player, index, at + 1)
	return true


# ------------------------------------------------------------ targets --

## Where quest [param index]'s current step leads: `{tile, name, slot}`
## (slot -1 at a marker).
func destination(player: AdventurePlayer, index: int) -> Dictionary:
	var now := step(player, index)
	var target: Variant = "giver"
	match String(now.get("do", "accept")):
		"go": target = now.get("to", "giver")
		"duel": target = now.get("at", "giver")
	return _resolve(player, target, index)


## The site an objective or a site step of quest [param index] leads to,
## whatever its stage (-1 when it leads to a marker or the giver only).
func destination_slot(player: AdventurePlayer, index: int) -> int:
	for now in _quest(index).get("steps", []):
		var target: Variant = now.get("to", now.get("at", "giver"))
		if target is Dictionary:
			var found := _resolve(player, target, index)
			return int(found["slot"])
	return -1


func _resolve(player: AdventurePlayer, target: Variant, index: int) -> Dictionary:
	var world := player.world
	if target is Dictionary:
		if target.has("site"):
			var slot := int(target["site"])
			return {"tile": Quests.site_tile(world, slot), "name": WorldNames.site_name(world, slot), "slot": slot}
		if target.has("objective"):
			var slot := int(objectives(player).get(String(target["objective"]), -1))
			if slot >= 0: return {"tile": Quests.site_tile(world, slot), "name": WorldNames.site_name(world, slot), "slot": slot}
			return _resolve(player, String(target.get("else", "giver")), index)
	var kind := String(target)
	if kind in PluginSchema.MARKERS:
		var point: Array = world.expansion.get(kind, [-1, -1])
		return {"tile": Vector2i(int(point[0]), int(point[1])), "name": String(_marker(kind).get("name", kind)), "slot": -1}
	var giver := int(_quest(index).get("giver", -1))
	return {"tile": Quests.site_tile(world, giver), "name": giver_name(index), "slot": giver}


## The same targets read from a saved region (`data` is its world, as
## [method task_rows] gets it): `{tile, name}`.
func _saved_target(data: Dictionary, target: Variant, index: int) -> Dictionary:
	var extra: Dictionary = data.get("expansion", {})
	if target is Dictionary:
		if target.has("site"):
			var slot := int(target["site"])
			return {"tile": RegionObjectives.tile(data, slot), "name": RegionObjectives.site_name(data, slot)}
		if target.has("objective"):
			var slot := int(extra.get("objectives", {}).get(String(target["objective"]), -1))
			if slot >= 0: return {"tile": RegionObjectives.tile(data, slot), "name": RegionObjectives.site_name(data, slot)}
			return _saved_target(data, String(target.get("else", "giver")), index)
	var kind := String(target)
	if kind in PluginSchema.MARKERS:
		var point: Array = extra.get(kind, [-1, -1])
		return {"tile": Vector2i(int(point[0]), int(point[1])), "name": String(_marker(kind).get("name", kind))}
	var giver := int(_quest(index).get("giver", -1))
	return {"tile": RegionObjectives.tile(data, giver), "name": giver_name(index)}


## The objectives of the world.json recipe, chosen once on the island and
## kept ([IslandGenerator.objectives]); a saved, still valid choice stays.
func ensure_objectives(player: AdventurePlayer) -> void:
	if not on_island(player): return
	var recipe := _part("world")
	var names: Dictionary = recipe.get("objectives", {})
	if names.is_empty(): return
	var world := player.world
	var saved: Variant = world.expansion.get("objectives")
	if saved is Dictionary:
		var valid := true
		for key in names:
			if not saved.has(key):
				valid = false
				continue
			var value: Variant = saved[key]
			if not AdventurePlayer._is_number(value) or int(value) != value or value < -1 or value >= world.sites.size(): valid = false
			elif value >= 0 and int(world.sites[int(value)].get("type", 0)) not in SITE_TYPES: valid = false
		if valid: return
	world.expansion["objectives"] = IslandGenerator.objectives(world, recipe)


func objectives(player: AdventurePlayer) -> Dictionary:
	ensure_objectives(player)
	return player.world.expansion.get("objectives", {})


## The next place to go: the first open quest's destination, then the
## finale's marker, then (once its flag is set) the after-finale marker.
func next_target(player: AdventurePlayer) -> Dictionary:
	if not on_island(player): return {}
	for index in quest_count():
		if not completed(player, index):
			var target := destination(player, index)
			target["kind"] = "quest"
			target.erase("slot")
			return target
	var targets: Dictionary = _part("quests").get("targets", {})
	var key := String(targets.get("after_finale", "port")) if flag(player, String(_finale().get("done_flag", ""))) \
		else String(targets.get("after_quests", "castle"))
	var point: Array = player.world.expansion.get(key, [])
	return {"tile": Vector2i(point[0], point[1]), "kind": "quest", "name": String(_marker(key).get("name", key))} if point.size() == 2 else {}


func guidance(player: AdventurePlayer, index: int) -> String:
	var quest := _quest(index)
	var values := _quest_values(player, index)
	if completed(player, index): return say("guide.done", values)
	var now := step(player, index)
	var key := String(now.get("guidance", ""))
	if key == "": key = "guide.duel" if String(now.get("do", "")) == "duel" else "guide.petition"
	values["target"] = destination(player, index)["name"]
	return say(key, values) if not quest.is_empty() else ""


func _quest_values(player: AdventurePlayer, index: int) -> Dictionary:
	var foe := foe_for(index)
	return {"title": say(String(_quest(index).get("title", ""))), "town": giver_name(index), "foe": String(foe.get("name", "")),
		"life": int(foe.get("life", 0)), "pledges": done_count(player), "quests_total": quest_count(), "region": title(),
		"hero": player.name if player != null else ""}


func _values(player: AdventurePlayer) -> Dictionary:
	var gate := deck_gate(player) if player != null else {"count": 0, "total": 0, "required": 1}
	var target := next_target(player)
	return {"pledges": done_count(player), "quests_total": quest_count(), "region": title(), "hero": player.name if player != null else "",
		"target": String(target.get("name", say("target.none"))), "count": gate["count"], "total": gate["total"],
		"required": gate["required"], "percent": int(_deck_share().get("percent", 0))}


# ---------------------------------------------------------- conditions --

## Whether every condition of [param conditions] holds for [param player].
func holds(player: AdventurePlayer, conditions: Array) -> bool:
	for condition in conditions:
		if not _holds(player, condition): return false
	return true


func _holds(player: AdventurePlayer, condition: Dictionary) -> bool:
	var key: String = condition.keys()[0]
	var value: Variant = condition[key]
	var state := progress(player)
	match key:
		"flag": return bool(state.get(value, false))
		"not_flag": return not bool(state.get(value, false))
		"stage":
			var now := stage(player, int(value["quest"]))
			return now >= int(value.get("min", 0)) and now <= int(value.get("max", 8))
		"quest_done": return completed(player, int(value))
		"quests_done":
			return done_count(player) >= (quest_count() if value is String else int(value))
		"deck_share": return bool(gate_for_cards(player.deck_cards(true), value)["ready"])
		"on_region": return on_island(player) == bool(value)
		"here": return on_island(player) and player.tile() == _resolve(player, value, -1)["tile"]
		"rewards_owed": return state.get("reward_choices", []).is_empty() != bool(value)
		"cards_pending": return state.get("pending", []).is_empty() != bool(value)
	return false


# ------------------------------------------------------------- effects --

## Apply [param effects] in order; [param quest] is the quest they finish
## (a reward choice is owed for it), -1 for the finale.
func apply(player: AdventurePlayer, effects: Array, quest := -1) -> void:
	for effect in effects:
		var key: String = effect.keys()[0]
		var value: Variant = effect[key]
		var state := _state(player)
		match key:
			"set_stage": set_stage(player, int(value["quest"]), int(value["value"]))
			"set_flag": state[String(value)] = true
			"gold": player.gold = maxi(0, player.gold + int(value))
			"food": player.food = maxi(0, player.food + int(value))
			"reward_choice":
				# One choice owed a quest, however its effects ask: two
				# would make the save unreadable (the review of 2026-11-10, RV2-1).
				var choices: Array = state.get("reward_choices", [])
				if bool(value) and quest >= 0 and not quest in choices:
					choices.append(quest)
					state["reward_choices"] = choices
			"claim_cards": if bool(value): claim(player)
			"log_clue": player.log_clue(say(String(value["text"]), _quest_values(player, quest)), "quest_clue" if bool(value.get("quest", false)) else "clue")
			"log_event":
				var words := say(String(value["text"]), _quest_values(player, quest))
				if bool(value.get("done", false)): player.log_event(String(value["event"]), words, {"done": true})
				else: player.log_event(String(value["event"]), words)
			"refresh_appearance": if bool(value): refresh_appearance(player)


## Quest [param quest] won: done once, its completion effects applied.
func finish_quest(player: AdventurePlayer, quest: int) -> bool:
	if not on_island(player) or quest < 0 or quest >= quest_count() or completed(player, quest):
		return false
	var state := _state(player)
	var done: Array = state.get("quests", [])
	done.append(quest)
	state["quests"] = done
	apply(player, _quest(quest).get("complete", []), quest)
	return true


## The finale won: its effects, when its conditions held.
func win_finale(player: AdventurePlayer) -> bool:
	if not can_challenge(player): return false
	apply(player, _finale().get("effects", []), -1)
	return true


func can_challenge(player: AdventurePlayer) -> bool:
	return on_island(player) and available() and holds(player, _finale().get("conditions", []))


## Why no duel may begin now, "" when one may.
func deck_problem(player: AdventurePlayer) -> String:
	if not available():
		# Installed and on but older than this plugin asks: never "enable"
		# a pack that is enabled (the review of 2026-11-10, RV2-4).
		var service := AdventureExpansions.packs()
		for pack in AdventureExpansions.pack_ids(id):
			if service == null or not service.is_enabled(pack): return say("deck.no_pack")
		var old := AdventureExpansions.pack_too_old(id)
		if not old.is_empty():
			var name := String(data().get("manifest", {}).get("name", id))
			return "The plugin %s needs %s %s or newer (installed %s)." % [name, String(old["title"]), String(old["min_version"]), String(old["version"])]
		return say("deck.no_pack")
	var cards := player.deck_cards(true)
	if cards.is_empty(): return say("deck.empty")
	for card in cards:
		if not CardRegistry.has_card(card): return say("deck.unknown")
	return ""


## Pennants for the quests done and each marker whose flag is set; the
## done quests and each flag mirrored into the region's metadata.
func refresh_appearance(player: AdventurePlayer) -> void:
	var world := player.world
	var state := progress(player)
	world.expansion["freed_communities"] = state.get("quests", []).duplicate()
	for name in _flags(): world.expansion[name] = bool(state.get(name, false))
	var banners: Array = []
	for index in state.get("quests", []):
		var color := String(_quest(int(index)).get("banner", ""))
		if color == "": continue
		var tile := Quests.site_tile(world, int(_quest(int(index))["giver"]))
		banners.append({"point": [tile.x, tile.y], "color": color})
	for kind in PluginSchema.MARKERS:
		var banner: Variant = _marker(kind).get("banner")
		if banner is Dictionary and bool(state.get(String(banner["flag"]), false)) and world.expansion.get(kind) is Array:
			banners.append({"point": world.expansion[kind].duplicate(), "color": String(banner["color"]),
				"anchor": banner["anchor"].duplicate(), "size": banner["size"].duplicate()})
	world.expansion["banners"] = banners
	world.appearance_revision += 1
	world.appearance_changed.emit()


# ------------------------------------------------------------- rewards --

## Move waiting cards into the bag while it has room and the game knows them.
func claim(player: AdventurePlayer) -> int:
	var state := _state(player)
	var pending: Array = state.get("pending", [])
	var taken := 0
	while not pending.is_empty() and player.bag_room() > 0 and CardRegistry.has_card(String(pending[0])):
		player.add_card(String(pending.pop_front()))
		taken += 1
	state["pending"] = pending
	return taken


func _rewards() -> Dictionary:
	return _part("rewards")


## The cards bundle [param bundle] offers now: the reward count, the
## Classic rule's copy limits and bans obeyed (cards already waiting count).
func reward_options(player: AdventurePlayer, bundle: int) -> Array[String]:
	var out: Array[String] = []
	var bundles: Array = _rewards().get("bundles", [])
	var count := int(_rewards().get("count", 6))
	if bundle < 0 or bundle >= bundles.size() or not available(): return out
	var rule := CardShop.classic_rule(player).duplicate(true)
	if not rule.is_empty():
		for card in progress(player).get("pending", []): rule["owned"][card] = int(rule["owned"].get(card, 0)) + 1
	for round_index in count:
		for card in bundles[bundle]["cards"]:
			if out.size() == count: return out
			if CardRegistry.has_card(card) and CardShop.classic_allows(rule, card):
				out.append(card)
				if not rule.is_empty(): rule["owned"][card] = int(rule["owned"].get(card, 0)) + 1
	return out


## Spend one owed reward choice on [param bundle].
func choose_reward(player: AdventurePlayer, bundle: int) -> bool:
	var choices: Array = progress(player).get("reward_choices", [])
	if choices.is_empty(): return false
	var cards := reward_options(player, bundle)
	if cards.size() != int(_rewards().get("count", 6)): return false
	var state := _state(player)
	choices.pop_front()
	state["reward_choices"] = choices
	var pending: Array = state.get("pending", [])
	pending.append_array(cards)
	state["pending"] = pending
	claim(player)
	return true


# ------------------------------------------------------------ the gate --

func _deck_share() -> Dictionary:
	for condition in _finale().get("conditions", []):
		if condition.has("deck_share"): return condition["deck_share"]
	return {}


func deck_gate(player: AdventurePlayer) -> Dictionary:
	# Cards the game does not know cannot qualify (0.60.13 bug campaign,
	# h3-1: deck_cards() leaves them out of every duel).
	return gate_for_cards(player.deck_cards(true))


## The deck share of [param cards]: `{count, total, ready, required}` —
## its nonland cards from the share's pack against all its nonland cards.
func gate_for_cards(cards: Array, share := {}) -> Dictionary:
	if share.is_empty(): share = _deck_share()
	var names := PluginSchema.pack_cards(String(share.get("pack", "")))
	var percent := int(share.get("percent", 0))
	var count := 0
	var total := 0
	var known := true
	for card in cards:
		if not CardRegistry.has_card(card):
			known = false
			continue
		if CardRegistry.get_card(card).is_land():
			continue
		total += 1
		if card in names:
			count += 1
	var ready := known and total > 0 and count * 100 >= total * percent
	return {"count": count, "total": total, "ready": ready, "required": maxi(1, (total * percent + 99) / 100)}


# ------------------------------------------------------------- the hooks --

func initialize(player: AdventurePlayer) -> void:
	AdventureExpansions.initialize(player)


## Sail between this region and the mainland; the voyage's clues and log.
func travel(player: AdventurePlayer) -> bool:
	var returning := on_island(player)
	if not AdventureExpansions.voyage(player, AdventureRegions.MAINLAND if returning else id): return false
	var voyage: Dictionary = _part("places").get("voyage", {})
	if not returning:
		for clue in voyage.get("arrive_clues", []):
			if bool(clue.get("quest", false)): player.log_clue(say(String(clue["text"])), "quest_clue")
			else: player.log_clue(say(String(clue["text"])))
	var words := say(String(voyage.get("home_log" if returning else "out_log", "")))
	if words != "": player.log_event("voyage", words)
	return true


## The marker [param tile] shows in [param world]: "port", "castle" or "".
## A mainland anchorage two lands share answers for each of them (its
## place names the first; its destinations, all — the review of
## 2026-11-10, RV2-3).
func marker(world: ShandalarWorld, tile: Vector2i) -> String:
	for place in AdventureExpansions.places(world):
		if tile != Vector2i(int(place["point"][0]), int(place["point"][1])): continue
		if String(place["id"]) == id or id in place.get("destinations", []): return String(place["kind"])
	return ""


## The pane of the port or castle at [param tile].
func describe(player: AdventurePlayer, tile: Vector2i) -> Dictionary:
	var kind := marker(player.world, tile)
	if kind == "" or data().is_empty(): return {}
	var island := on_island(player)
	var spot := _marker(kind)
	var pane := {}
	for option in spot.get("panes", []):
		if holds(player, option.get("when", [])):
			pane = option
			break
	var lines := _lines(player, pane.get("lines", []))
	var actions: Array = []
	for action in pane.get("actions", []):
		if holds(player, action.get("when", [])): actions.append_array(_action(player, action, island))
	if island:
		for index in quest_count():
			if completed(player, index): continue
			var now := step(player, index)
			if not String(now.get("do", "")) in ["go", "duel"] or destination(player, index)["tile"] != tile: continue
			if String(now["do"]) == "go":
				lines.append(guidance(player, index))
				actions.push_front([id + "_deliver_%d" % index, say(String(now["action"])), available()])
			elif now.has("approach"):
				if now["approach"].has("line"): lines.append(say(String(now["approach"]["line"])))
				actions.push_front([id + "_petition_%d" % index, say(String(now["approach"]["action"])), true])
	var name := say(String(pane["title"])) if pane.has("title") else String(spot.get("name", "") if island else spot.get("mainland_name", spot.get("name", "")))
	var picture := String(pane.get("picture", spot.get("picture", "visit_city")))
	return {"expansion": id, "kind": "region_" + kind, "slot": -1, "name": name,
		"subtitle": say(String(pane["subtitle"])) if pane.has("subtitle") else subtitle(),
		"picture": picture, "lines": lines, "actions": actions}


func _lines(player: AdventurePlayer, entries: Array) -> Array:
	var out: Array = []
	var values := _values(player)
	for entry in entries:
		if entry is String:
			out.append(say(entry, values))
			continue
		if not holds(player, entry.get("when", [])): continue
		if entry.has("text"):
			out.append(say(String(entry["text"]), values))
			continue
		match String(entry.get("show", "")):
			"news": out.append(news(player))
			"pending":
				var pending: Array = progress(player).get("pending", [])
				if not pending.is_empty(): out.append(say("rewards.pending_line", {"count": pending.size()}))
			"deck_problem":
				var problem := deck_problem(player)
				if problem != "": out.append(problem)
	return out


func _action(player: AdventurePlayer, action: Dictionary, island: bool) -> Array:
	var label := say(String(action.get("label", "")))
	match String(action["do"]):
		"sail": return [[id + "_sail", label, island or AdventureExpansions.enabled_for(player, id)]]
		"leave": return [[id + "_leave", label, true]]
		"boss": return [[id + "_boss", label, can_challenge(player) and deck_problem(player) == ""]]
		"rewards": return reward_actions(player)
	return []


func reward_actions(player: AdventurePlayer) -> Array:
	if _rewards().get("bundles", []).is_empty(): return []
	var state := progress(player)
	var choices: Array = state.get("reward_choices", [])
	var pending: Array = state.get("pending", [])
	return [[id + "_reward", say("rewards.choose", {"count": choices.size()}), available() and not choices.is_empty()],
		[id + "_claim", say("rewards.claim", {"count": pending.size()}), available() and not pending.is_empty()]]


## The reward bundles' pane.
func reward_place(player: AdventurePlayer) -> Dictionary:
	var actions: Array = []
	var lines: Array = [say("rewards.intro")]
	var count := int(_rewards().get("count", 6))
	var owed: bool = not progress(player).get("reward_choices", []).is_empty()
	var bundles: Array = _rewards().get("bundles", [])
	for bundle in bundles.size():
		var cards := reward_options(player, bundle)
		var label := say(String(bundles[bundle]["label"]))
		lines.append(say("rewards.offer", {"color": label, "cards": ", ".join(cards)}))
		actions.append([id + "_reward_%d" % bundle, label, cards.size() == count and owed])
	lines.append(say("rewards.rules"))
	actions.append([id + "_back", say("rewards.later"), true])
	return {"expansion": id, "kind": "region_reward", "slot": -1, "name": say("rewards.title"), "subtitle": subtitle(),
		"picture": String(_part("quests").get("pictures", {}).get("rewards", "visit_city")), "lines": lines, "actions": actions}


## Quest [param index]'s pane at its giver.
func quest_place(player: AdventurePlayer, index: int) -> Dictionary:
	var quest := _quest(index)
	var complete := completed(player, index)
	var values := _quest_values(player, index)
	var lines: Array = [say(String(quest["epilogue"] if complete else quest["petition"]), values)]
	var actions: Array = []
	if not complete:
		var reward := say("quest.reward_line", values)
		if reward != "": lines.append(reward)
		lines.append(guidance(player, index))
		lines.append(say("quest.retry_line", values))
		var problem := deck_problem(player)
		if problem != "": lines.append(problem)
		var now := step(player, index)
		if String(now["do"]) == "accept" and stage(player, index) == 0:
			actions.append([id + "_accept_%d" % index, say(String(now.get("action", "quest.accept")), values), available()])
		else:
			var here: bool = player.tile() == destination(player, index)["tile"]
			actions.append([id + "_fight", say("quest.fight", values), ready(player, index) and here and problem == ""])
	else:
		lines.append(say("quest.secure", values))
	actions.append_array(reward_actions(player))
	actions.append([id + "_back", say("quest.back"), true])
	return {"expansion": id, "kind": "region_quest", "slot": int(quest["giver"]), "quest": index, "name": values["title"],
		"subtitle": giver_name(index), "picture": String(_part("quests").get("pictures", {}).get("quest", "visit_city")),
		"lines": lines, "actions": actions}


func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary:
	if not on_island(player) or data().is_empty(): return place
	var town: Dictionary = _part("quests").get("town", {})
	var index := quest_at(slot)
	if index >= 0:
		var done := completed(player, index)
		place["lines"] = [say(String(_quest(index)["epilogue"])) if done else say(String(town.get("line", "")), _quest_values(player, index))]
		# The wise man's action is replaced by identity; shared services stay.
		var action := [id + "_quest", say(String(town.get("thanks" if done else "action", ""))), true]
		var replaced := false
		for i in place["actions"].size():
			if place["actions"][i][0] == "wiseman":
				place["actions"][i] = action
				replaced = true
				break
		if not replaced: place["actions"].insert(mini(3, place["actions"].size()), action)
	for quest in quest_count():
		if completed(player, quest): continue
		var now := step(player, quest)
		if not String(now.get("do", "")) in ["go", "duel"]: continue
		var where := destination(player, quest)
		if int(where["slot"]) != slot: continue
		if String(now["do"]) == "go":
			place["lines"].append(say(String(now["line"])) if now.has("line") else guidance(player, quest))
			place["actions"].push_front([id + "_deliver_%d" % quest, say(String(now["action"])), available()])
		elif now.has("approach"):
			if now["approach"].has("line"): place["lines"].append(say(String(now["approach"]["line"])))
			place["actions"].push_front([id + "_petition_%d" % quest, say(String(now["approach"]["action"])), true])
	return place


func ordinary_quests(_player: AdventurePlayer, slot: int) -> bool:
	return not slot in _part("quests").get("errands_off", [])


## The panes' buttons (UI side, [code]plugin_journey.gd[/code]).
func act(screen: Node, action: String, place: Dictionary) -> bool:
	if not action.begins_with(id + "_"): return false
	return bool(_journey().call("act", self, screen, action, place))


## A quest's (or the finale's, -1) duel ([code]plugin_journey.gd[/code]).
func duel_config(player: AdventurePlayer, quest: int) -> DuelConfig:
	return _journey().call("duel_config", self, player, quest)


func status_lines(player: AdventurePlayer) -> Array[String]:
	var out: Array[String] = []
	if not on_island(player): return out
	out.assign(_lines(player, _part("quests").get("status", [])))
	return out


func targets(player: AdventurePlayer) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	for index in quest_count():
		if completed(player, index): continue
		var target := destination(player, index)
		target.erase("slot")
		target["kind"] = "quest"
		out.append(target)
	if out.is_empty():
		var next := next_target(player)
		if not next.is_empty(): out.append(next)
	return out


func deck_line(player: AdventurePlayer, cards: Array) -> String:
	var key := String(_part("quests").get("deck_line", ""))
	if key == "": return ""
	var gate := gate_for_cards(cards)
	return say(key, {"count": gate["count"], "total": gate["total"], "required": gate["required"],
		"percent": int(_deck_share().get("percent", 0)), "pledges": done_count(player), "quests_total": quest_count(), "region": title()})


func roaming_tier(_player: AdventurePlayer, tier: int) -> int:
	var roaming: Variant = _part("foes").get("roaming")
	if not roaming is Dictionary: return tier
	# The least tier exists in all five colors; lairs and stronger creatures stay.
	return maxi(int(roaming.get("min_tier", 0)), tier) if tier > 0 else 0


func tales(_player: AdventurePlayer) -> Array:
	var out: Array = []
	for tale in _part("quests").get("talk", {}).get("tales", []):
		out.append([say(String(tale["title"])), say(String(tale["text"]))])
	return out


func news(player: AdventurePlayer) -> String:
	var lines := _lines(player, _part("quests").get("talk", {}).get("news", []))
	return String(lines[0]) if not lines.is_empty() else ""


func applause(player: AdventurePlayer) -> String:
	var lines := _lines(player, _part("quests").get("talk", {}).get("applause", []))
	return String(lines[0]) if not lines.is_empty() else ""


func roaming_words(player: AdventurePlayer, wins: int) -> Array[String]:
	var talk: Dictionary = _part("quests").get("talk", {})
	var out: Array[String] = []
	out.assign(_lines(player, talk.get("tribute", []) if wins >= CreatureMeeting.TRIBUTE_WINS else talk.get("roaming", [])))
	return out


func dungeon_words(_player: AdventurePlayer) -> String:
	return say(String(_part("quests").get("talk", {}).get("dungeon", "")))


func entered(player: AdventurePlayer) -> void:
	ensure_objectives(player)
	refresh_appearance(player)


## The region's task rows, read from its saved world [param data] and
## [param progress] alone (an inactive region has no live world).
func task_rows(data: Dictionary, progress: Dictionary) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var extra: Dictionary = data.get("expansion", {})
	var tasks: Dictionary = _part("quests").get("tasks", {})
	for index in quest_count():
		var quest := _quest(index)
		var steps: Array = quest["steps"]
		var at := clampi(int(progress.get("stages", {}).get(str(index), 0)), 0, steps.size() - 1)
		var now: Dictionary = steps[at]
		var target: Variant = now.get("to", "giver") if String(now["do"]) == "go" else now.get("at", "giver") if String(now["do"]) == "duel" else "giver"
		var where := _saved_target(data, target, index)
		var values := _quest_values(null, index)
		values["target"] = where["name"]
		var key := String(now.get("task", "task.duel" if String(now["do"]) == "duel" else "task.petition"))
		var task := AdventureTasks.row("pledge:%d" % index, id, values["title"], say(key, values), where["tile"])
		if index in progress.get("quests", []): AdventureTasks.completed(task, say("task.done", values))
		out.append(task)
	var finale := _finale()
	var point: Array = extra.get(String(finale.get("at", "castle")), [-1, -1])
	var gate_values := {"pledges": progress.get("quests", []).size(), "quests_total": quest_count(),
		"percent": int(_deck_share().get("percent", 0)), "region": title()}
	var lord: Dictionary = tasks.get("finale", {})
	var task := AdventureTasks.row("lord", id, say(String(lord.get("title", "")), gate_values), say(String(lord.get("text", "")), gate_values), Vector2i(point[0], point[1]))
	if bool(progress.get(String(finale.get("done_flag", "")), false)): AdventureTasks.completed(task, say(String(lord.get("done", "")), gate_values))
	out.append(task)
	if not progress.get("quests", []).is_empty() and not _rewards().get("bundles", []).is_empty():
		var rewards: Dictionary = tasks.get("rewards", {})
		var reward := AdventureTasks.row("rewards", id, say(String(rewards.get("title", ""))), say(String(rewards.get("text", ""))), Vector2i(point[0], point[1]))
		if progress.get("reward_choices", []).is_empty() and progress.get("pending", []).is_empty():
			AdventureTasks.completed(reward, say(String(rewards.get("done", ""))))
		out.append(reward)
	return out


func generate(seed_value: int, color: int, difficulty: int) -> ShandalarWorld:
	var recipe := _part("world")
	return IslandGenerator.generate(recipe, seed_value, color, difficulty) if not recipe.is_empty() else null


## Stable world/slot choice, never hero strength, cards or concealed
## information. The creature keeps its identity and its announced 1997
## gifts; only roaming encounters take these decks. Named hunts and
## special encounters stay exact.
func roaming_encounter(player: AdventurePlayer, meeting: Dictionary) -> void:
	var roaming: Variant = _part("foes").get("roaming")
	if not roaming is Dictionary or roaming.get("decks", []).is_empty(): return
	if not available() or bool(meeting.get("quest", false)) or meeting.has("town"): return
	if CreatureBook.preduel_flags(int(meeting["row"])) & (CreatureBook.PRE_SUMMON | CreatureBook.PRE_SWAP) != 0: return
	var slot := int(meeting.get("slot", -1))
	if slot < 1 or slot == CreatureMeeting.SIEGE_SLOT: return
	var skip: Dictionary = roaming.get("skip", {})
	var every := int(skip.get("every", 0))
	if every > 0 and posmod(player.world.seed * int(skip.get("seed", 1)) + slot * int(skip.get("slot", 17)) + int(meeting["row"]) * int(skip.get("row", 1)), every) == 0: return
	var color: String = AdventurePlayer.COLORS[clampi(int(meeting["color"]), 1, 5) - 1]
	var chosen := {}
	for entry in roaming["decks"]:
		if color in entry["colors"]:
			chosen = entry
			break
	if chosen.is_empty(): return
	var foe: Dictionary = _part("foes")["foes"].get(chosen["foe"], {})
	meeting["regional_deck"] = deck_of(foe)
	meeting["regional_name"] = String(chosen["name"])
	meeting["regional_life"] = int(chosen.get("life", foe.get("life", 20)))
	if String(roaming.get("ante", "random_nonbasic")) != "random_nonbasic": return
	var candidates: Array = meeting["regional_deck"].filter(func(card: String) -> bool: return card not in CreatureDeck.BASICS)
	if not candidates.is_empty():
		var dice := MsvcRandom.new(player.dice)
		meeting["creature_ante"] = [candidates[dice.below(candidates.size())]] as Array[String]
		player.dice = dice.state


## The region's decks for the expansion lab: each roaming deck, then the
## finale's foe under the castle's name.
func study_decks() -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var roaming: Variant = _part("foes").get("roaming")
	if roaming is Dictionary:
		for entry in roaming.get("decks", []):
			var foe: Dictionary = _part("foes")["foes"].get(entry["foe"], {})
			out.append({"name": String(entry["name"]), "life": int(entry.get("life", foe.get("life", 20))), "deck": deck_of(foe)})
	var lord := foe_for(-1)
	var region: Variant = data().get("manifest", {}).get("region", {})
	out.append({"name": String(region.get("castle_name", lord.get("name", ""))) if region is Dictionary else String(lord.get("name", "")),
		"life": int(lord.get("life", 20)), "deck": deck_of(lord)})
	return out


## The region's world music, null for the mainland's.
func music() -> AudioStream:
	var track := String(_part("world").get("music", ""))
	return AdventurePlugins.stream(id, track) if track != "" else null
