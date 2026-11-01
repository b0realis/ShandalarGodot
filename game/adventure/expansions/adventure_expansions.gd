class_name AdventureExpansions
extends RefCounted
## Lightweight expansion directory. Paths, IDs and small metadata only: no
## preloaded art, generated maps, card definitions or quest controllers.
## Add a descriptor and content provider for another land; core callers stay put.

const CATALOGUE := {
	"refuge": {"pack": "pack-2", "title": "The Last Refuge", "salt": 0x46454D, "palette": "last_refuge",
		"provider": "res://game/adventure/expansions/refuge_content.gd",
		"required_markers": ["port", "castle"], "required_sites": [1, 2, 3, 4, 5], "pledges": 5, "mana_links": false, "progress_schema": {"quests": 5, "max_stage": 2, "max_pending": 60},
		"castle_name": "Ebon Crown", "generator": "Last Refuge (32x32 from 1997 terrain)",
		"pictures": {"refuge_harbor": "res://game/adventure/expansions/art/refuge_harbor.png", "refuge_castle": "res://game/adventure/expansions/art/refuge_castle.png"},
		"sprites": {"port": ["res://game/adventure/expansions/art/refuge_port_map.png", 160.0], "castle": ["res://game/adventure/expansions/art/refuge_castle_map.png", 192.0]}}
}
static var _development := {}
static var _providers := {}
static var _hooked := false
static var revision := 0
static var _places_key := []
static var _places: Array[Dictionary] = []
static var _trims := {}

static func definition(id: String) -> Dictionary:
	return _development.get(id, CATALOGUE.get(id, {}))

static func packs() -> Node:
	var loop := Engine.get_main_loop()
	var node: Node = (loop as SceneTree).root.get_node_or_null("CardPacks") if loop is SceneTree else null
	if node != null and not _hooked:
		node.connect(&"changed", refresh)
		node.connect(&"rescanned", refresh)
		_hooked = true
	return node

static func enabled(id: String) -> bool:
	if _development.has(id): return bool(_development[id].get("enabled", true))
	var service := packs()
	return service != null and service.is_enabled(String(definition(id).get("pack", "")))

static func refresh(_pack := "", _enabled := false) -> void:
	revision += 1
	_places_key.clear()
	# Scripts contain no preloaded textures; release dormant providers too.
	_providers.clear()
	_trims.clear()

static func provider(id: String) -> Script:
	var info := definition(id)
	if info.is_empty(): return null
	if not _providers.has(id): _providers[id] = load(info["provider"])
	return _providers[id]

static func active(player: AdventurePlayer, method: String, args := [], fallback: Variant = null) -> Variant:
	if player == null or AdventureRegions.mainland(player): return fallback
	var content := provider(AdventureRegions.id(player.world))
	return content.callv(method, [player] + args) if content != null and content.has_method(method) else fallback

static func initialize(player: AdventurePlayer) -> void:
	if player == null or player.world == null or not AdventureRegions.mainland(player): return
	var entries: Dictionary = player.world.expansion.get("entries", {})
	if player.world.expansion.has("port") and not entries.has("refuge"):
		entries["refuge"] = player.world.expansion["port"]
	for id in definitions():
		if not enabled(id): continue
		if not entries.has(id):
			var tile := RegionGeography.entry_for(player.world, player.world.start_tile(), entries.values())
			if tile.x < 0: continue
			entries[id] = [tile.x, tile.y]
		if not player.expansions.has(id):
			player.expansions[id] = definition(id).get("initial_progress", {"quests": [], "pending": [], "liberated": false}).duplicate(true)
	if not entries.is_empty():
		player.world.expansion["entries"] = entries
		player.world.expansion["region"] = AdventureRegions.MAINLAND
		# Preserve old chart/tool coordinates without making them a second place.
		if entries.has("refuge"): player.world.expansion["port"] = entries["refuge"]
	_places_key.clear()

static func release_inactive(active: String) -> void:
	for key in _providers.keys():
		if key != active: _providers.erase(key)

static func entered(player: AdventurePlayer) -> void:
	# Keep only the active region's script. Unvisited content has no runtime state.
	var id := AdventureRegions.id(player.world)
	for key in _providers.keys():
		if key != id: _providers.erase(key)
	_places_key.clear()
	active(player, "entered")

static func mana_links_allowed(world: ShandalarWorld) -> bool:
	var id := AdventureRegions.id(world)
	return id == AdventureRegions.MAINLAND or bool(definition(id).get("mana_links", false))

static func progress(player: AdventurePlayer, id: String) -> Dictionary:
	return player.expansions.get(id, {})

static func label(id: String) -> String:
	return "Shandalar" if id == AdventureRegions.MAINLAND else String(definition(id).get("title", id.capitalize()))

static func places(world: ShandalarWorld) -> Array[Dictionary]:
	if world == null: return []
	if not _hooked: packs()
	var key := [world.get_instance_id(), world.appearance_revision, revision]
	if key == _places_key: return _places
	_places_key = key
	_places = []
	var id := AdventureRegions.id(world)
	if id == AdventureRegions.MAINLAND:
		var entries: Dictionary = world.expansion.get("entries", {}).duplicate()
		if world.expansion.has("port") and not entries.has("refuge"): entries["refuge"] = world.expansion["port"]
		for entry in entries:
			if enabled(entry) and AdventureRegions.valid_point(entries[entry]):
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
	var content := provider(mark.get_slice(":", 0))
	return content.call("describe", player, tile) if content != null else {}

static func departure_place(destinations: Array) -> Dictionary:
	var actions: Array = []
	for id in destinations: actions.append(["region_visit:" + id, label(id), true])
	actions.append(["leave", "Leave the anchorage", true])
	return {"departure": true, "kind": "expansion_port", "slot": -1, "name": "Coastal Anchorage", "subtitle": "Choose a voyage", "picture": "visit_city", "lines": ["Ships at this anchorage sail to several lands. Speak to a captain before choosing your destination."], "actions": actions}

static func decorate_town(player: AdventurePlayer, slot: int, place: Dictionary) -> Dictionary:
	return active(player, "decorate_town", [slot, place], place)

static func ordinary_quests(player: AdventurePlayer, slot: int) -> bool:
	return active(player, "ordinary_quests", [slot], true)

static func is_action(action: String) -> bool:
	if action.begins_with("region_visit:"): return definitions().has(action.get_slice(":", 1))
	for id in definitions():
		if action.begins_with(id + "_"): return true
	return false

static func act(screen: WorldScreen, action: String, place: Dictionary) -> bool:
	if action.begins_with("region_visit:"):
		var id := action.get_slice(":", 1)
		if enabled(id):
			var visit: Dictionary = provider(id).call("describe", screen.player, screen.player.tile())
			if not visit.is_empty(): show_place(screen, visit)
		return true
	for id in definitions():
		if action.begins_with(id + "_"):
			var content := provider(id)
			return content.call("act", screen, action, place)
	return false

static func show_place(screen: WorldScreen, place: Dictionary) -> VisitPane:
	var pane := VisitPane.new()
	pane.player = screen.player
	pane.place = place
	pane.k = WorldHud.BIG if screen.hud.big else 1.0
	screen._visit = pane
	screen.add_child(pane)
	pane.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	pane.grow_horizontal = Control.GROW_DIRECTION_BOTH
	pane.grow_vertical = Control.GROW_DIRECTION_BOTH
	pane.left.connect(screen._left_place, WorldScreen.CLOSING)
	screen._hold()
	return pane

static func add_stock(player: AdventurePlayer, base: Array[Dictionary]) -> Array[Dictionary]:
	if player == null: return base
	var out := base
	for id in definitions():
		if not enabled(id) or not (AdventureRegions.id(player.world) == id or bool(progress(player, id).get("liberated", false))): continue
		out = provider(id).call("add_stock", player, out)
	return out

static func status_lines(player: AdventurePlayer) -> Array[String]:
	return active(player, "status_lines", [], [] as Array[String])

static func targets(player: AdventurePlayer) -> Array[Dictionary]:
	return active(player, "targets", [], [] as Array[Dictionary])

static func picture(key: String) -> Texture2D:
	for info in definitions().values():
		if info.get("pictures", {}).has(key): return load(info["pictures"][key])
	return GameSkin.texture(key)

static func map_op(mark: String) -> Array:
	var sprite: Array = definition(mark.get_slice(":", 0)).get("sprites", {}).get(mark.get_slice(":", 1), [])
	if sprite.is_empty(): return []
	var texture: Texture2D = load(sprite[0])
	if not _trims.has(sprite[0]): _trims[sprite[0]] = Rect2(texture.get_image().get_used_rect())
	var source: Rect2 = _trims[sprite[0]]
	var width: float = sprite[1]
	var height := width * source.size.y / maxf(1.0, source.size.x)
	return [texture, Rect2(Vector2(64.0 - width / 2.0, 24.0 - height), Vector2(width, height)), source]

static func valid_progress(id: String, state: Dictionary) -> bool:
	return ExpansionContract.valid_progress(definition(id), state)

static func definitions() -> Dictionary:
	var out := CATALOGUE.duplicate()
	out.merge(_development)
	return out

## Development fixtures are explicitly installed by tools/tests, never on boot.
static func register_development(id: String, descriptor: Dictionary) -> bool:
	if CATALOGUE.has(id) or not ExpansionContract.valid_descriptor(descriptor): return false
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
