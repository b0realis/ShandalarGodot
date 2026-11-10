class_name AdventureExpansions
extends RefCounted
## THE OPTIONAL LANDS' DIRECTORY: paths, ids and small metadata only — no
## preloaded art, generated maps, card definitions or quest controllers.
##
## ADVENTURE PLUGINS (2026-11-10; the owner: *"The expanded adventure …
## will be a small package players can download and plugin to the vanilla
## shandalar adventure game"*): the lands are the valid plugins
## [AdventurePlugins] finds — data only, each answered by its own instance
## of the res:// interpreter [DataRegion] ([method provider]) — and the
## development fixtures a tool or test registers ([method register_development],
## a res:// script). No launch flag: a land is on for a campaign when it was
## ticked at the Embark ([member AdventurePlayer.adventures]), is installed
## and valid, and its card packs are the campaign's and enabled ([method
## enabled_for]). A card pack's cards never wait for a land (§0.2).
##
## A LAND MISSING MID-CAMPAIGN (§0.5): its progress and saved map are kept
## as they are ([method ExpansionContract.opaque_progress]); a hero on its
## island finds the game's own "Ship home" pane at its port and a "Leave"
## pane at its castle ([method stranded_place]); reinstalled, it goes on.

## The game's own actions at an optional land's places: the anchorage's
## voyage to a land ([method departure_place]), and a missing plugin's ship
## home and leave ([method stranded_place]).
const VISIT_ACTION := "region_visit:"
const HOME_ACTION := "region_home"
const LEAVE_ACTION := "region_leave"

static var _development := {}
static var _providers := {}
static var _hooked := false
static var revision := 0
static var _places_key := []
static var _places: Array[Dictionary] = []
static var _trims := {}


static func definition(id: String) -> Dictionary:
	if _development.has(id):
		return _development[id]
	return AdventurePlugins.descriptor(id)


## Every land this game knows now: the valid plugins in the order found,
## then the development fixtures.
static func definitions() -> Dictionary:
	var out := {}
	for id in AdventurePlugins.ids():
		out[id] = AdventurePlugins.descriptor(id)
	for id in _development:
		out[id] = _development[id]
	return out


## Whether [param id] is a land this game can describe now.
static func known(id: String) -> bool:
	return not definition(id).is_empty()


static func packs() -> Node:
	var loop := Engine.get_main_loop()
	var node: Node = (loop as SceneTree).root.get_node_or_null("CardPacks") if loop is SceneTree else null
	if node != null and not _hooked:
		node.connect(&"changed", refresh)
		node.connect(&"rescanned", refresh)
		_hooked = true
	return node


## The card packs land [param id] needs, by id ([] for one with none, or
## one this game does not know now).
static func pack_ids(id: String) -> Array[String]:
	var info := definition(id)
	var out: Array[String] = []
	var listed: Variant = info.get("packs")
	if listed is Array:
		for pack: Variant in listed:
			if pack is String and pack != "" and not pack in out:
				out.append(pack)
	elif String(info.get("pack", "")) != "":
		out.append(String(info["pack"]))
	return out


## The first card pack land [param id] needs that is installed but older than
## its plugin asks ([method AdventurePlugins.pack_status]), {} for none.
static func pack_too_old(id: String) -> Dictionary:
	for need: Dictionary in AdventurePlugins.pack_status(id):
		if bool(need["installed"]) and not bool(need["new_enough"]):
			return need
	return {}


## Installed, valid, and every card pack it needs enabled on this computer
## and as new as its plugin asks.
static func enabled(id: String) -> bool:
	var info := definition(id)
	if info.is_empty():
		return false
	if _development.has(id) and not bool(info.get("enabled", true)):
		return false
	var needs := pack_ids(id)
	if needs.is_empty():
		return true
	var service := packs()
	if service == null:
		return false
	for pack in needs:
		if not service.is_enabled(pack):
			return false
	return pack_too_old(id).is_empty()


## Whether [param player]'s campaign ticked land [param id] at the Embark.
static func ticked(player: AdventurePlayer, id: String) -> bool:
	return player != null and player.adventures.any(func(row: Variant) -> bool:
		return row is Dictionary and row.get("id", "") == id)


## A LAND HELD (adventure plugins, 2026-11-10; the lead's rule on the guide
## writer's finding): [param player]'s land [param id] whose saved map or
## progress the plugin's installed version cannot read — a town moved, a
## quest taken out ([method AdventureRegions.saved_state]). Treated exactly
## as a missing plugin's land: carried as it was saved, its ships not
## sailing ([method enabled_for]), its content never asked ([method
## provider_for]), a hero on it given the game's own Ship home ([method
## stranded_place]); the old version put back reads it again on the next load.
static func held(player: AdventurePlayer, id: String) -> bool:
	return player != null and player.held_lands.has(id)


## The version of land [param id] [param player]'s campaign last read
## ([member AdventurePlayer.adventures]), "" when it does not say.
static func saved_version(player: AdventurePlayer, id: String) -> String:
	if player == null:
		return ""
	for row: Variant in player.adventures:
		if row is Dictionary and row.get("id") == id and row.get("version") is String:
			return String(row["version"])
	return ""


## [param player]'s ticked plugins as the installed versions read them: each
## row's version and name those of the version that read its land now — not
## a held one's, nor a missing one's, which keep the words they were saved
## with.
static func note_versions(player: AdventurePlayer) -> void:
	if player == null:
		return
	for row: Variant in player.adventures:
		if not row is Dictionary or not row.get("id") is String:
			continue
		var id := String(row["id"])
		if not AdventurePlugins.valid(id) or held(player, id):
			continue
		var installed := AdventurePlugins.row(id)
		row["version"] = String(installed.get("version", row.get("version", "")))
		row["name"] = String(installed.get("name", row.get("name", "")))
		row["title"] = label(id)


## Available globally is separate from selected in this campaign: ticked,
## and every card pack it needs one of the campaign's.
static func chosen(player: AdventurePlayer, id: String) -> bool:
	if not ticked(player, id):
		return false
	for pack in pack_ids(id):
		if not AdventurePacks.selected(player, pack):
			return false
	return true


static func enabled_for(player: AdventurePlayer, id: String) -> bool:
	return chosen(player, id) and enabled(id) and not held(player, id)


static func enabled_in(world: ShandalarWorld, id: String) -> bool:
	return world != null and id in world.expansion.get("adventures", []) and enabled(id)


## Map renderers need only these IDs, never the hero or an adventure provider.
static func sync_choices(player: AdventurePlayer) -> void:
	if player == null or player.world == null: return
	var ids: Array[String] = []
	for id in definitions():
		if enabled_for(player, id): ids.append(id)
	# Leave an ordinary mainland's metadata empty when there are no expeditions.
	if not ids.is_empty() or player.world.expansion.has("adventures"):
		player.world.expansion["adventures"] = ids
	_places_key.clear()


static func refresh(_pack := "", _enabled := false) -> void:
	revision += 1
	_places_key.clear()
	# Scripts contain no preloaded textures; release dormant providers too.
	_providers.clear()
	_trims.clear()


## THE LAND'S CONTENT: [param id]'s own [DataRegion] for a plugin, made
## once and kept while its land is the active one; a development fixture's
## res:// script. Null for a land this game cannot describe now.
static func provider(id: String) -> Object:
	if _providers.has(id):
		return _providers[id]
	var info := definition(id)
	if info.is_empty():
		return null
	var made: Object = null
	if bool(info.get("plugin", false)):
		made = DataRegion.new(id)
	elif info.get("provider") is String and String(info["provider"]).begins_with("res://"):
		made = load(info["provider"])
	if made != null:
		_providers[id] = made
	return made


## [param player]'s content of land [param id]: [method provider]'s, null
## for a land held ([method held]).
static func provider_for(player: AdventurePlayer, id: String) -> Object:
	return null if held(player, id) else provider(id)


static func active(player: AdventurePlayer, method: String, args := [], fallback: Variant = null) -> Variant:
	if player == null or AdventureRegions.mainland(player): return fallback
	var content := provider_for(player, AdventureRegions.id(player.world))
	return content.callv(method, [player] + args) if content != null and content.has_method(method) else fallback


static func initialize(player: AdventurePlayer) -> void:
	if player == null or player.world == null: return
	sync_choices(player)
	release_inactive(AdventureRegions.id(player.world))
	if not AdventureRegions.mainland(player): return
	var entries: Dictionary = player.world.expansion.get("entries", {})
	for id in definitions():
		if not enabled_for(player, id): continue
		if not entries.has(id):
			var tile := RegionGeography.entry_for(player.world, player.world.start_tile(), entries.values())
			if tile.x < 0: continue
			entries[id] = [tile.x, tile.y]
		if not player.expansions.has(id):
			player.expansions[id] = (definition(id).get("initial_progress", {}) as Dictionary).duplicate(true)
	if not entries.is_empty():
		player.world.expansion["entries"] = entries
		player.world.expansion["region"] = AdventureRegions.MAINLAND
	_places_key.clear()


static func release_inactive(active: String) -> void:
	for key in _providers.keys():
		if key != active: _providers.erase(key)


static func entered(player: AdventurePlayer) -> void:
	sync_choices(player)
	# Keep only the active region's script. Unvisited content has no runtime state.
	var id := AdventureRegions.id(player.world)
	for key in _providers.keys():
		if key != id: _providers.erase(key)
	_places_key.clear()
	active(player, "entered")


## THE VOYAGE (adventure plugins): [param player] sails to land [param
## destination] from the mainland — made from the mainland's seed the first
## time ([method generate]), its saved map after — or home ([constant
## AdventureRegions.MAINLAND]), which is always allowed. False when the ship
## does not sail: the land not on for this campaign, or the hero already
## there. The clues and the journal's words are the land's own to add.
static func voyage(player: AdventurePlayer, destination: String) -> bool:
	if player == null or player.world == null:
		return false
	initialize(player)
	var leaving := AdventureRegions.id(player.world)
	if destination == leaving:
		return false
	if destination != AdventureRegions.MAINLAND and (leaving != AdventureRegions.MAINLAND or not enabled_for(player, destination)):
		return false
	var seed_value := player.world.seed
	var color := player.world.color
	var difficulty := player.difficulty
	var make := func() -> ShandalarWorld: return generate(destination, seed_value, color, difficulty)
	return AdventureRegions.travel(player, destination, make)


static func mana_links_allowed(world: ShandalarWorld) -> bool:
	var id := AdventureRegions.id(world)
	return id == AdventureRegions.MAINLAND or bool(definition(id).get("mana_links", false))


## [QoL] WHY A TICKED LAND'S SHIPS DO NOT SAIL (the lead's ruling of
## 2026-11-10, after the owner's of 2026-11-03 for the retired flag): one
## sentence a land, said once a launch on the mainland — its plugin not
## installed, refused, or a card pack it needs not the campaign's or not
## enabled. "" when every ticked land sails, the hero is off the mainland
## (its harbor says it there), or none is ticked.
static func mainland_note(player: AdventurePlayer) -> String:
	if player == null or player.world == null or not AdventureRegions.mainland(player):
		return ""
	var lines: Array[String] = []
	for row: Variant in player.adventures:
		if row is Dictionary and row.get("id") is String:
			var why := sail_refusal(player, String(row["id"]))
			if why != "":
				lines.append(why)
	return " ".join(lines)


## WHY [param player]'S SHIPS TO TICKED LAND [param id] DO NOT SAIL, one
## sentence ([method mainland_note]'s, the Tasks tab's — RV2-4): its plugin
## not installed, refused, unable to read the saved land, or a card pack it
## needs not the campaign's, off, or older than it asks. "" when they sail.
static func sail_refusal(player: AdventurePlayer, id: String) -> String:
	if player == null or not ticked(player, id) or enabled_for(player, id):
		return ""
	var name := plugin_name(id, player)
	var title := label(id, player)
	if not known(id):
		if AdventurePlugins.row(id).is_empty():
			return "Ships to %s do not sail: the plugin %s is not installed." % [title, name]
		return "Ships to %s do not sail: the plugin %s is refused." % [title, name]
	if held(player, id):
		return "Ships to %s do not sail: this adventure was saved with %s of the plugin %s, and the installed version %s cannot read it." % [
			title, _version_words(saved_version(player, id)), name, String(AdventurePlugins.row(id).get("version", "?"))]
	var service := packs()
	for pack in pack_ids(id):
		if not AdventurePacks.selected(player, pack) or service == null or not service.is_enabled(pack):
			return "Ships to %s do not sail: the plugin %s needs %s." % [title, name, AdventurePacks.title(pack)]
	var old := pack_too_old(id)
	if not old.is_empty():
		return "Ships to %s do not sail: the plugin %s needs %s %s or newer (installed %s)." % [
			title, name, String(old["title"]), String(old["min_version"]), String(old["version"])]
	return ""


## "version 1.0.0", or "another version" when the save does not say.
static func _version_words(version: String) -> String:
	return "version " + version if version != "" else "another version"


static func progress(player: AdventurePlayer, id: String) -> Dictionary:
	return player.expansions.get(id, {})


## A land's title ("Shandalar" for the mainland): its descriptor's, else
## the title [param player]'s campaign saved for it (RV2-7: a missing
## plugin's land keeps its own), else the plugin's name saved, else its id.
static func label(id: String, player: AdventurePlayer = null) -> String:
	if id == AdventureRegions.MAINLAND:
		return "Shandalar"
	var info := definition(id)
	if info.get("title") is String:
		return String(info["title"])
	var saved := _saved_word(id, player, "title")
	if saved == "":
		saved = _saved_name(id, player)
	return saved if saved != "" else id.capitalize()


## A plugin's own name (its manifest's), else the name [param player]'s
## campaign saved for it, else its id.
static func plugin_name(id: String, player: AdventurePlayer = null) -> String:
	var row := AdventurePlugins.row(id)
	if String(row.get("name", "")) != "" and String(row.get("id", "")) == id:
		return String(row["name"])
	var info := definition(id)
	if info.get("name") is String:
		return String(info["name"])
	var saved := _saved_name(id, player)
	return saved if saved != "" else id


static func _saved_name(id: String, player: AdventurePlayer) -> String:
	return _saved_word(id, player, "name")


static func _saved_word(id: String, player: AdventurePlayer, key: String) -> String:
	if player == null:
		return ""
	for row: Variant in player.adventures:
		if row is Dictionary and row.get("id") == id and row.get(key) is String:
			return String(row[key])
	return ""


static func places(world: ShandalarWorld) -> Array[Dictionary]:
	if world == null: return []
	if not _hooked: packs()
	var key := [world.get_instance_id(), world.appearance_revision, revision, world.expansion.get("adventures", [])]
	if key == _places_key: return _places
	_places_key = key
	_places = []
	var id := AdventureRegions.id(world)
	if id == AdventureRegions.MAINLAND:
		var entries: Dictionary = world.expansion.get("entries", {})
		for entry in entries:
			if enabled_in(world, entry) and AdventureRegions.valid_point(entries[entry]):
				var shared := false
				for place in _places:
					if place["point"] == entries[entry]:
						place["destinations"].append(entry)
						place["name"] = "Ships: %d destinations" % place["destinations"].size()
						shared = true
						break
				if not shared: _places.append({"id": entry, "kind": "port", "point": entries[entry], "destinations": [entry], "name": "Ship: " + label(entry)})
	else:
		# Returning is independent of pack availability. Never strand a saved hero.
		for kind in ["port", "castle"]:
			var point: Variant = world.expansion.get(kind)
			if AdventureRegions.valid_point(point):
				_places.append({"id": id, "kind": kind, "point": point, "name": "Ship" if kind == "port" else String(definition(id).get("castle_name", "Castle"))})
	return _places


static func places_visible(world: ShandalarWorld) -> bool:
	return not places(world).is_empty()


static func marker(world: ShandalarWorld, tile: Vector2i) -> String:
	for place in places(world):
		if tile == Vector2i(int(place["point"][0]), int(place["point"][1])): return place["id"] + ":" + place["kind"]
	return ""


static func describe(player: AdventurePlayer, tile: Vector2i) -> Dictionary:
	var mark := marker(player.world, tile)
	if mark == "": return {}
	for place in places(player.world):
		if tile == Vector2i(place["point"][0], place["point"][1]) and place.get("destinations", []).size() > 1:
			return departure_place(place["destinations"])
	var content := provider_for(player, mark.get_slice(":", 0))
	if content == null:
		return stranded_place(player, mark.get_slice(":", 1))
	return content.call("describe", player, tile)


static func departure_place(destinations: Array) -> Dictionary:
	var actions: Array = []
	for id in destinations: actions.append([VISIT_ACTION + id, label(id), true])
	actions.append(["leave", "Leave the anchorage", true])
	return {"departure": true, "kind": "expansion_port", "slot": -1, "name": "Coastal Anchorage", "subtitle": "Choose a voyage", "picture": "visit_city", "lines": ["Ships at this anchorage sail to several lands. Speak to a captain before choosing your destination."], "actions": actions}


## THE GAME'S OWN PANE AT A LAND WHOSE PLUGIN IS MISSING (§0.5): at its
## port ([param kind] "port") a ship home, at its castle the way out — the
## hero is never stranded, and nothing of the land is changed.
static func stranded_place(player: AdventurePlayer, kind: String) -> Dictionary:
	var id := AdventureRegions.id(player.world)
	var title := label(id, player)
	var lines: Array = ["The adventure plugin %s is not installed or cannot be read, so %s rests as you left it." % [plugin_name(id, player), title],
		"Your progress here is kept. Put the plugin back in the expanded_adventure folder to go on."]
	if held(player, id):
		var saved := saved_version(player, id)
		lines = ["This land was saved with %s of the plugin %s, and the installed version %s cannot read it, so %s rests as you left it." % [
				_version_words(saved), plugin_name(id, player), String(AdventurePlugins.row(id).get("version", "?")), title],
			"Your progress here is kept. Put %s back in the expanded_adventure folder to go on." % (
				"version " + saved if saved != "" else "the version it was saved with")]
	if kind == "port":
		lines.append("The ship can always take you home.")
		return {"kind": "region_port", "expansion": id, "slot": -1, "name": "Ship home", "subtitle": title,
			"picture": "visit_city", "lines": lines,
			"actions": [[HOME_ACTION, "Sail to Shandalar", true], [LEAVE_ACTION, "Leave", true]]}
	return {"kind": "region_castle", "expansion": id, "slot": -1, "name": "Leave", "subtitle": title,
		"picture": "visit_city", "lines": lines, "actions": [[LEAVE_ACTION, "Leave the castle", true]]}


static func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary:
	return active(player, "decorate_town", [slot, place], place)


static func ordinary_quests(player: AdventurePlayer, slot: int) -> bool:
	return active(player, "ordinary_quests", [slot], true)


## The land whose actions [param action] is one of: the longest id it
## begins with followed by `_` ("" for none).
static func action_owner(action: String) -> String:
	var best := ""
	for id: String in definitions():
		if action.begins_with(id + "_") and id.length() > best.length():
			best = id
	return best


static func is_action(action: String) -> bool:
	if action == HOME_ACTION or action == LEAVE_ACTION: return true
	if action.begins_with(VISIT_ACTION): return definitions().has(action.get_slice(":", 1))
	return action_owner(action) != ""


## THE SCREEN ARRIVES UNTYPED (0.60.13 bug campaign, h5-1). This directory
## is model-side: AdventurePlayer reaches it, and through AdventurePlayer
## every `--script` tool (Deck Lab, AutoDeck, lab_query). Naming
## WorldScreen, VisitPane or WorldHud here compiled the whole world UI in
## those tools, and that UI names autoloads, which a `--script` is compiled
## before (CONTRIBUTING, Gotchas). The screen builds its own pane
## ([method WorldScreen.open_place]); tools/test_script_entry_points.py
## follows the references so the chain cannot come back.
static func act(screen: Node, action: String, place: Dictionary) -> bool:
	if action.begins_with(VISIT_ACTION):
		var id := action.get_slice(":", 1)
		if enabled_for(screen.player, id):
			var visit: Dictionary = provider(id).call("describe", screen.player, screen.player.tile())
			if not visit.is_empty(): show_place(screen, visit)
		return true
	if action == HOME_ACTION:
		var player: AdventurePlayer = screen.player
		if voyage(player, AdventureRegions.MAINLAND):
			player.log_event("voyage", "Returned to Shandalar's mainland.")
			screen._visit_tile = Vector2i(-1, -1)
			screen.show_player(player)
			screen.autosave()
			var arrival := describe(player, player.tile())
			if not arrival.is_empty():
				show_place(screen, arrival)
			else:
				screen._after_leaving()
		screen._sync_rest()
		return true
	if action == LEAVE_ACTION:
		screen._visit_tile = Vector2i(-1, -1)
		screen._after_leaving()
		screen._sync_rest()
		return true
	var owner := action_owner(action)
	if owner != "":
		var content := provider_for(screen.player, owner)
		return content.call("act", screen, action, place) if content != null else true
	return false


static func show_place(screen: Node, place: Dictionary) -> Control:
	return screen.open_place(place)


static func status_lines(player: AdventurePlayer) -> Array[String]:
	return active(player, "status_lines", [], [] as Array[String])


static func targets(player: AdventurePlayer) -> Array[Dictionary]:
	return active(player, "targets", [], [] as Array[Dictionary])


## THE ACTIVE LAND'S OWN WORLD TRACK ([method DataRegion.music]), while the
## hero walks there; null on the mainland, or for a land with none.
static func music(player: AdventurePlayer) -> AudioStream:
	if player == null or player.world == null or AdventureRegions.mainland(player):
		return null
	var content := provider_for(player, AdventureRegions.id(player.world))
	if content == null or not content.has_method("music"):
		return null
	var tune: Variant = content.call("music")
	return tune if tune is AudioStream else null


## A picture an optional land names by [param key] ([method DataRegion]'s
## panes put it in `place["picture"]`): a plugin's from its own bytes
## ([method AdventurePlugins.texture]), a development fixture's from its
## res:// path; else the skin's.
static func picture(key: String) -> Texture2D:
	var definitions_now := definitions()
	for id: String in definitions_now:
		var info: Dictionary = definitions_now[id]
		var pictures: Variant = info.get("pictures", {})
		if pictures is Dictionary and (pictures as Dictionary).has(key):
			return _texture(id, info, String(pictures[key]))
	return GameSkin.texture(key)


static func _texture(id: String, info: Dictionary, path: String) -> Texture2D:
	if bool(info.get("plugin", false)):
		return AdventurePlugins.texture(id, path)
	if not path.begins_with("res://") or not ResourceLoader.exists(path):
		return null
	return load(path) as Texture2D


## A land's marker on the world ([param mark] `<id>:port` / `<id>:castle`):
## `[texture, destination, source]`, its foot on the tile's middle, its
## width the descriptor's in world pixels; [] when it has no sprite.
static func map_op(mark: String) -> Array:
	var id := mark.get_slice(":", 0)
	var info := definition(id)
	var sprites: Variant = info.get("sprites", {})
	var sprite: Variant = (sprites as Dictionary).get(mark.get_slice(":", 1), []) if sprites is Dictionary else []
	if not sprite is Array or (sprite as Array).size() < 2 or not AdventurePlayer._is_number(sprite[1]):
		return []
	var texture := _texture(id, info, String(sprite[0]))
	if texture == null: return []
	var trim := id + ":" + String(sprite[0])
	if not _trims.has(trim): _trims[trim] = Rect2(texture.get_image().get_used_rect())
	var source: Rect2 = _trims[trim]
	var width := float(sprite[1])
	var height := width * source.size.y / maxf(1.0, source.size.x)
	return [texture, Rect2(Vector2(64.0 - width / 2.0, 24.0 - height), Vector2(width, height)), source]


static func valid_progress(id: String, state: Dictionary) -> bool:
	return ExpansionContract.valid_progress(definition(id), state)


## Development fixtures are explicitly installed by tools/tests, never on boot.
static func register_development(id: String, descriptor: Dictionary) -> bool:
	if (definitions().has(id) and not _development.has(id)) or not ExpansionContract.valid_descriptor(descriptor): return false
	_development[id] = descriptor.duplicate(true)
	refresh()
	return true


static func clear_development() -> void:
	_development.clear()
	refresh()


static func generate(id: String, mainland_seed: int, color: int, difficulty: int) -> ShandalarWorld:
	var content := provider(id)
	if content == null or not content.has_method("generate"): return null
	return content.call("generate", mainland_seed ^ int(definition(id).get("salt", 0)), color, difficulty)
