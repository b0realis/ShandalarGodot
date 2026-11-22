extends RefCounted
## A SITES PLUGIN OF API 3 FOR THE TESTS (the places campaign of
## 2026-11-22): an inn with every new word — counters, a talk pane, a
## one_of line, a roll, needs, a gift, a duel, a card trade and a task —
## written into a folder as a player's own plugin would be.

const ID := "inn"


static func manifest(api := 3, id := ID) -> Dictionary:
	return {"plugin_format": 1, "api_version": api, "kind": "sites", "id": id, "name": "The Inn",
		"version": "1.0.0", "authors": ["A Tester"], "description": "An inn for the tests."}


static func leave() -> Dictionary:
	return {"id": "leave", "do": "leave"}


static func text() -> Dictionary:
	return {"inn.hello": "Welcome, {hero}. Day {day}; you carry {food} food and {amulets} amulets.",
		"inn.cellar": "The way to {dungeon} is yours.", "inn.cellar_label": "The way to {dungeon} ({price} gold)",
		"r.a": "Rumor A.", "r.b": "Rumor B.", "r.c": "Rumor C.", "r.count": "You asked {count} times.",
		"g.win": "You win.", "g.lose": "You lose.", "d.win": "Well fought; {count} wins.",
		"inn.log": "A night at the inn.", "task.title": "Visit the inn", "task.text": "Ask for rumors at the inn.",
		"task.done": "You heard the rumors.", "task.cellar": "Find {dungeon}."}


static func sites() -> Dictionary:
	return {
		"salt": 4711,
		"flags": ["told"],
		"counters": ["visits", "wins"],
		"dungeons": {"cellar": {"name": "The Cellar", "cards": ["Grizzly Bears"]}},
		"foes": {"champion": {"name": "The Champion", "life": 12, "face": 1, "deck": {"Forest": 10, "Grizzly Bears": 10}}},
		"tasks": {
			"go_inn": {"title": "task.title", "text": "task.text", "done": "task.done", "at": "place:inn",
				"done_when": [{"counter": {"name": "visits", "min": 1}}]},
			"cellar": {"title": "task.cellar", "text": "task.cellar", "at": "dungeon:cellar",
				"when": [{"dungeon": {"dungeon": "cellar", "state": "open"}}]}},
		"sites": {"inn": {
			"name": "The Inn", "where": ["mainland", "islands"], "picture": "visit_city",
			"sprite": {"file": "art/inn.png", "width": 96},
			"panes": [
				{"id": "rumors", "lines": [{"one_of": ["r.a", "r.b", "r.c"], "by": "uses"},
						{"text": "r.count", "when": [{"counter": {"name": "visits", "min": 0}}]}],
					"actions": [leave()]},
				{"id": "games", "actions": [
					{"id": "gamble", "do": "effects", "prices": [10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10, 10],
						"effects": [{"roll": {"outcomes": [{"weight": 3, "effects": [{"gold": 30}], "result": ["g.win"]},
							{"weight": 1, "result": ["g.lose"]}]}}]},
					{"id": "bless", "do": "effects", "prices": [50, 50], "effects": [{"next_duel": {"life": 5}}]},
					{"id": "map", "do": "effects", "effects": [{"reveal_map": {"radius": 3}}]},
					{"id": "duel", "do": "duel", "foe": "champion", "prices": [100], "count": "win",
						"win": {"effects": [{"gold": 300}, {"counter": {"name": "wins", "add": 1}}], "result": ["d.win"]}},
					leave()]},
				{"id": "shop", "actions": [
					{"id": "buy", "do": "buy_card", "cards": {"Grizzly Bears": 1, "Black Lotus": 5000}, "stock": 1},
					{"id": "sell", "do": "sell_card", "cards": {"Forest": 100000}},
					leave()]},
				{"lines": ["inn.hello"], "actions": [
					{"id": "ask", "do": "talk", "to": "rumors"},
					{"id": "paid_talk", "do": "talk", "to": "rumors", "prices": [5, 5, 5], "effects": [{"counter": {"name": "visits", "add": 1}}]},
					{"id": "cellar", "do": "effects", "label": "inn.cellar_label", "prices": [100], "effects": [{"spawn_dungeon": "cellar"}], "result": ["inn.cellar"]},
					{"id": "gift", "do": "effects", "prices": [0], "effects": [{"give_card": "Grizzly Bears"},
						{"amulet": {"color": "red", "count": 2}}, {"counter": {"name": "wins", "set": 5}}]},
					{"id": "trade", "do": "effects", "needs": [{"card": "Forest"}, {"amulets": {"color": "any", "count": 2}}, {"food": 3}],
						"effects": [{"gold": 40}]},
					{"id": "gated", "do": "effects", "when": [{"any": [{"hero_color": "red"}, {"has_card": {"card": "Black Lotus"}}]}],
						"effects": [{"set_flag": "told"}, {"log_event": {"event": "duel", "text": "inn.log"}}]},
					{"id": "games", "do": "talk", "to": "games"},
					leave()]}]}}}


## [method sites] with a guild pane of round 3's words: a journey, a World
## Magic, a mana link and a life bonus, and the texts they speak with.
static func sites_r3() -> Dictionary:
	var content := sites()
	(content["sites"]["inn"]["panes"] as Array).insert(0, {"id": "guild", "actions": [
		{"id": "travel", "do": "effects", "effects": [{"gold": 1}, {"teleport": {"to": "nearest_town"}}], "result": ["inn.hello"]},
		{"id": "to_cellar", "do": "effects", "prices": [5, 5], "effects": [{"teleport": {"to": "dungeon:cellar"}}]},
		{"id": "magic", "do": "effects", "prices": [300, 300], "effects": [{"world_magic": "Dwarven Pick"}]},
		{"id": "link", "do": "effects", "prices": [200, 200, 200], "effects": [{"mana_link": "nearest_town"}]},
		{"id": "vigor", "do": "effects", "prices": [100, 100, 100, 100, 100], "effects": [{"life_bonus": 3}]},
		leave()]})
	return content


static func picture() -> PackedByteArray:
	var image := Image.create(48, 40, false, Image.FORMAT_RGBA8)
	image.fill(Color(0, 0, 0, 0))
	image.fill_rect(Rect2i(8, 6, 32, 30), Color(0.5, 0.4, 0.3))
	return image.save_png_to_buffer()


## The plugin's files as the loader reads them, `{rel: bytes}`.
static func files(content: Dictionary, words: Dictionary) -> Dictionary:
	return {"sites.json": JSON.stringify(content).to_utf8_buffer(), "text.json": JSON.stringify(words).to_utf8_buffer(),
		"art/inn.png": picture()}


## What the game's checker says of [param content] under [param api].
static func problems(content: Dictionary, api := 3, words := {}) -> Array:
	var said: Dictionary = text() if words.is_empty() else words
	return PluginSchema.read(manifest(api), files(content, said))["problems"]


## The plugin written under [param root] (a folder of plugins).
static func install(root: String, content: Dictionary, api := 3, id := ID) -> void:
	var to := root.path_join("The_Inn_" + id)
	DirAccess.make_dir_recursive_absolute(to.path_join("art"))
	var all := files(content, text())
	all["plugin.json"] = JSON.stringify(manifest(api, id)).to_utf8_buffer()
	for rel: String in all:
		var file := FileAccess.open(to.path_join(rel), FileAccess.WRITE)
		file.store_buffer(all[rel])
		file.close()


static func remove(path: String) -> void:
	var dir := DirAccess.open(path)
	if dir == null:
		return
	for name in dir.get_files():
		dir.remove(name)
	for name in dir.get_directories():
		remove(path.path_join(name))
	DirAccess.remove_absolute(path)
