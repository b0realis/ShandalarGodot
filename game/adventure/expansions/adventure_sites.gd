class_name AdventureSites
extends RefCounted
## THE SITES PLUGINS' PLACES (adventure plugin API 2, 2026-11-21; the owner:
## *"Is it possible to add a new type of town or interaction place as a
## plugin? ... one would supply an icon and rules"*, then *"this separate
## plugin can be placed on other islands or on mainland if used"*).
##
## A sites plugin ([constant AdventurePlugins.KIND_SITES]) is no land: it
## has no voyage, no port and no quests. Its places — each a picture, a map
## sprite and panes of buttons the plugin's data describes ([DataSites]) —
## stand on the lands a campaign has: on Shandalar's mainland and on the
## islands of the island plugins it sails to, as each place's `where` says.
## A place stands on a tile found once ([method place_here]) and kept in
## that land's `world.expansion.sites`, `{"<plugin>:<site>": [x, y]}`.
##
## THE DICE ARE THE PLUGIN'S OWN: a place's tile (and a dungeon one raises,
## [method DataSites.spawn]) is drawn on dice seeded from the land's seed,
## the plugin's salt and the place's key ([method dice_for]) — never the
## adventure's dice or the world's, so a campaign without sites plugins, and
## every 1997 draw of one with them, is the same as before.
##
## A PLUGIN MISSING OR REFUSED: its places hide (they are drawn and visited
## only while it is valid and its card packs are on); their tiles are kept,
## and a dungeon one raised stays an ordinary dungeon of the land.

## The key in `world.expansion` that holds a land's places.
const KEY := "sites"
## A place's buttons: `<plugin>_act:<site>:<action>`, `<plugin>_back:<site>`
## (the place's pane again), `<plugin>_leave`.
const ACT := "_act:"
const BACK := "_back:"
const LEAVE := "_leave"
## The most places one land keeps (a damaged save's longer list is cut).
const MOST_PLACES := 64
## The pane kind of a place ([member VisitPane.place]).
const PANE_KIND := "site"

static var _providers := {}


## Sites plugin [param id]'s descriptor ([method PluginSchema.site_descriptor]),
## {} for one this game does not hold valid as a sites plugin.
static func definition(id: String) -> Dictionary:
	if AdventurePlugins.kind(id) != AdventurePlugins.KIND_SITES:
		return {}
	return AdventurePlugins.descriptor(id)


## Whether [param id] is a sites plugin this game holds valid.
static func known(id: String) -> bool:
	return not definition(id).is_empty()


## The card packs sites plugin [param id] needs.
static func pack_ids(id: String) -> Array[String]:
	var out: Array[String] = []
	for pack: Variant in definition(id).get("packs", []):
		if pack is String and pack != "" and not pack in out:
			out.append(pack)
	return out


## Installed and valid, every card pack it needs enabled on this computer
## and as new as it asks: its places may be drawn and visited.
static func enabled(id: String) -> bool:
	if not known(id):
		return false
	for need: Dictionary in AdventurePlugins.pack_status(id):
		if not bool(need["enabled"]) or not bool(need["new_enough"]):
			return false
	return true


## Whether sites plugin [param id] is on for [param player]'s campaign:
## ticked at the Embark, every pack it needs one of the campaign's, enabled.
static func on(player: AdventurePlayer, id: String) -> bool:
	if not AdventureExpansions.ticked(player, id) or not enabled(id):
		return false
	for pack in pack_ids(id):
		if not AdventurePacks.selected(player, pack):
			return false
	return true


## The sites plugins on for [param player]'s campaign, in the order found.
static func on_ids(player: AdventurePlayer) -> Array[String]:
	var out: Array[String] = []
	for id in AdventurePlugins.site_ids():
		if on(player, id):
			out.append(id)
	return out


## Plugin [param id]'s interpreter ([DataSites]), made once a scan.
static func provider(id: String) -> DataSites:
	if not known(id):
		return null
	if not _providers.has(id) or (_providers[id] as DataSites).revision != AdventurePlugins.revision:
		_providers[id] = DataSites.new(id)
	return _providers[id]


static func refresh() -> void:
	_providers.clear()


# ------------------------------------------------------------ placing --

## THE PLACES OF [param player]'s LAND PUT ON IT, the first time: each place
## of each sites plugin on for the campaign whose `where` names this kind of
## land (the mainland, or an island) and that has no tile here yet gets one
## ([method spot]). Nothing is written when there is nothing to place, so a
## land no place stands on keeps its `expansion` as it was.
static func place_here(player: AdventurePlayer) -> void:
	if player == null or player.world == null:
		return
	var world := player.world
	var mainland := AdventureRegions.mainland(player)
	var placed := _placed(world)
	var added := false
	var blocked := blocked_tiles(player)
	for id in on_ids(player):
		var info := definition(id)
		var salt := int(info.get("salt", 0))
		var sites: Dictionary = info.get("sites", {})
		for site: String in sites:
			var where: Array = sites[site].get("where", ["mainland"])
			if not ("mainland" if mainland else "islands") in where:
				continue
			var key := id + ":" + site
			if placed.has(key) or placed.size() >= MOST_PLACES:
				continue
			var tile := spot(world, key, salt, int(sites[site].get("gap", 3)), placed.values(), blocked)
			if tile.x < 0:
				continue
			placed[key] = [tile.x, tile.y]
			added = true
	if added:
		world.expansion[KEY] = placed
		AdventureExpansions.forget_places()


## The places kept on [param world], `{key: [x, y]}` — only well-formed
## rows ([method AdventureRegions.valid_point]) of a key `<plugin>:<site>`.
static func _placed(world: ShandalarWorld) -> Dictionary:
	var out := {}
	var saved: Variant = world.expansion.get(KEY, {}) if world != null else {}
	if not saved is Dictionary:
		return out
	for key: Variant in saved:
		if out.size() >= MOST_PLACES:
			break
		if key is String and String(key).get_slice_count(":") == 2 and AdventureRegions.valid_point(saved[key]):
			out[key] = [int(saved[key][0]), int(saved[key][1])]
	return out


## THE TILES OF [param player]'s LAND NO NEW PLACE TAKES though they carry
## no flag (the review of 2026-11-21): the hero's own, Arzakon's portal's
## ([method FinalBattle.portal_tile_of]) and every lair's. A place put on a
## land later than its first day — a plugin's new version with one more
## place, a card pack turned on again — stood under the hero, under the
## portal (whose pane is asked first, so the place was never visited) or
## on a lair. A new campaign has none of them on a tile [method spot]
## would draw from (the hero stands on the start), so its draws are the same.
static func blocked_tiles(player: AdventurePlayer) -> Array[Vector2i]:
	var out: Array[Vector2i] = []
	if player == null:
		return out
	out.append(player.tile())
	var portal := FinalBattle.portal_tile_of(player)
	if portal.x >= 0:
		out.append(portal)
	for creature: Variant in player.monsters:
		if creature is Dictionary and String(creature.get("kind", "")) == "lair" \
				and AdventurePlayer._is_number(creature.get("x")) and AdventurePlayer._is_number(creature.get("y")):
			out.append(Vector2i(int(creature["x"]) / 32, int(creature["y"]) / 32))
	return out


## Every tile a place of [param world] keeps, shown or not (a moved
## dungeon never stands on one, [method DungeonDoors.expansion_place]).
static func points(world: ShandalarWorld) -> Array:
	return _placed(world).values()


## THE TILE A PLACE STANDS ON ([param key] `<plugin>:<site>`): a land tile
## of the start's land — no site, road or dungeon on it, no other place —
## [param gap] tiles or more from every town, castle, dungeon and place
## ([param taken] those placed already), never one of [param blocked]
## ([method blocked_tiles]), next to a road when one such is
## (the hero walks by it), drawn on [method dice_for]'s dice. (−1, −1) when
## no tile fits.
static func spot(world: ShandalarWorld, key: String, salt: int, gap: int, taken: Array,
		blocked: Array[Vector2i] = []) -> Vector2i:
	var start := world.start_tile()
	var near_road: Array[Vector2i] = []
	var anywhere: Array[Vector2i] = []
	var others: Array[Vector2i] = []
	for site in world.sites:
		if int(site["type"]) > 0:
			others.append(Vector2i(int(site["x"]), int(site["y"])))
	for slot in world.encounters:
		if world.is_land(int(slot.get("x", 0)), int(slot.get("y", 0))):
			others.append(Vector2i(int(slot.get("x", 0)), int(slot.get("y", 0))))
	for point: Variant in taken + _expansion_points(world):
		if AdventureRegions.valid_point(point):
			others.append(Vector2i(int(point[0]), int(point[1])))
	for tile in RegionGeography.component(world, start):
		if tile == start or world.tile_flags(tile.x, tile.y) & (ShandalarWorld.SITE | ShandalarWorld.ROAD | ShandalarWorld.DUNGEON) != 0:
			continue
		if tile in blocked:
			continue
		var clear := true
		for other in others:
			if tile.distance_to(other) < float(gap):
				clear = false
				break
		if not clear:
			continue
		anywhere.append(tile)
		if _by_road(world, tile):
			near_road.append(tile)
	var pool := near_road if not near_road.is_empty() else anywhere
	if pool.is_empty():
		return Vector2i(-1, -1)
	return pool[dice_for(world, salt, key).below(pool.size())]


## The anchorages, the island's harbor and castle of [param world].
static func _expansion_points(world: ShandalarWorld) -> Array:
	var out: Array = []
	var entries: Variant = world.expansion.get("entries", {})
	if entries is Dictionary:
		out.append_array((entries as Dictionary).values())
	for mark in ["port", "castle"]:
		if world.expansion.has(mark):
			out.append(world.expansion[mark])
	return out


static func _by_road(world: ShandalarWorld, tile: Vector2i) -> bool:
	for d in range(1, 9):
		if world.tile_flags(tile.x + ShandalarWorld.DX[d], tile.y + ShandalarWorld.DY[d]) & ShandalarWorld.ROAD != 0:
			return true
	return false


## A SITES PLUGIN'S OWN DICE for [param key] on [param world]: seeded from
## the land's seed, the plugin's [param salt] and the key's FNV-1a hash — the
## same on every computer and every run, never the adventure's dice.
static func dice_for(world: ShandalarWorld, salt: int, key: String) -> MsvcRandom:
	var seed_value := (int(world.seed) ^ salt ^ fnv(key)) & 0x7FFFFFFF
	return MsvcRandom.new(seed_value if seed_value != 0 else 1)


## The 32-bit FNV-1a hash of [param text]'s UTF-8 bytes.
static func fnv(text: String) -> int:
	var hash := 0x811C9DC5
	for byte in text.to_utf8_buffer():
		hash = ((hash ^ byte) * 0x01000193) & 0xFFFFFFFF
	return hash


# ----------------------------------------------------------- the map --

## The places [param world] shows: each kept place whose plugin is valid
## and enabled ([method enabled]), `{id, kind, point, name, site: true}` —
## `kind` the site's key, so its marker is `<plugin>:<site>`.
static func places(world: ShandalarWorld) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var placed := _placed(world)
	for key: String in placed:
		var id := key.get_slice(":", 0)
		var site := key.get_slice(":", 1)
		if not enabled(id):
			continue
		var sites: Dictionary = definition(id).get("sites", {})
		if not sites.has(site):
			continue
		out.append({"id": id, "kind": site, "point": placed[key], "name": String(sites[site].get("name", site)), "site": true})
	return out


## Whether marker [param mark] (`<id>:<kind>`) is a sites plugin's place.
static func owns(mark: String) -> bool:
	return mark != "" and known(mark.get_slice(":", 0))


## The pane of the place at [param tile] for [param player], {} for none.
static func describe(player: AdventurePlayer, tile: Vector2i) -> Dictionary:
	for place in places(player.world):
		if Vector2i(int(place["point"][0]), int(place["point"][1])) == tile:
			var content := provider(String(place["id"]))
			return content.describe(player, String(place["kind"])) if content != null else {}
	return {}


## The sites plugin whose button [param action] is: the longest id it
## begins with followed by `_` ("" for none).
static func action_owner(action: String) -> String:
	var best := ""
	for id in AdventurePlugins.site_ids():
		if action.begins_with(id + "_") and id.length() > best.length():
			best = id
	return best


## A place's button pressed on [param screen] (untyped, the h5-1 rule:
## [method AdventureExpansions.act]).
static func act(screen: Node, action: String, place: Dictionary) -> bool:
	var owner := action_owner(action)
	if owner == "":
		return false
	var content := provider(owner)
	if content == null:
		# The plugin went missing under the open pane: the place is left.
		screen._visit_tile = Vector2i(-1, -1)
		screen._after_leaving()
		screen._sync_rest()
		return true
	return content.act(screen, action, place)


## A picture a sites plugin names by [param key], null when none does.
static func picture(key: String) -> Texture2D:
	for id in AdventurePlugins.site_ids():
		var pictures: Variant = definition(id).get("pictures", {})
		if pictures is Dictionary and (pictures as Dictionary).has(key):
			return AdventurePlugins.texture(id, String(pictures[key]))
	return null


static var _trims := {}


## Place [param mark]'s sprite on the world, as [method
## AdventureExpansions.map_op] draws a land's: `[texture, destination,
## source]`, [] when it has none.
static func map_op(mark: String) -> Array:
	var id := mark.get_slice(":", 0)
	var sprites: Variant = definition(id).get("sprites", {})
	var sprite: Variant = (sprites as Dictionary).get(mark.get_slice(":", 1), []) if sprites is Dictionary else []
	if not sprite is Array or (sprite as Array).size() < 2 or not AdventurePlayer._is_number(sprite[1]):
		return []
	var texture := AdventurePlugins.texture(id, String(sprite[0]))
	if texture == null:
		return []
	var trim := id + ":" + String(sprite[0]) + ":" + str(AdventurePlugins.revision)
	if not _trims.has(trim):
		# Measured as it was decoded ([method AdventurePlugins.texture]): no
		# read-back off the graphics card here.
		_trims[trim] = texture.get_meta(AdventurePlugins.USED_RECT) if texture.has_meta(AdventurePlugins.USED_RECT) \
			else Rect2(texture.get_image().get_used_rect())
	var source: Rect2 = _trims[trim]
	var width := float(sprite[1])
	var height := width * source.size.y / maxf(1.0, source.size.x)
	return [texture, Rect2(Vector2(64.0 - width / 2.0, 24.0 - height), Vector2(width, height)), source]
