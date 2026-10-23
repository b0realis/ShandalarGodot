class_name AdventurePlayer
extends RefCounted
## THE ADVENTURER AND THEIR WORLD — everything one game of Shandalar keeps,
## in one place (the owner, 2026-10-22: *"a structured commented and human
## readable AdventurePlayer class where all current player data is recorded
## along with all items and stats and current world state"*).
##
## WHAT IS KEPT is what the 1997 game keeps in its save (`magicN.SVE`; the
## layout is in the 1.3 decompilation's `docs/shandalar_save_files.txt`,
## and each field below names its offset there), held our own way and
## saved as JSON a person can read. The parts no system uses yet — cards
## and decks, quests, the journal, roaming monsters, sieges — are here,
## empty, with their shape, so that each system fills its own part.
##
## ONE GAME, ONE FILE NAME: an adventure is named by its hero and a hash of
## the moment it began ([member adventure_id]), and its first save is
## written the moment its world is made ([method autosave]).

## The save's own name and version, first in every file.
const FORMAT := "shandalar-adventure"
const FORMAT_VERSION := 1
## Where the adventures are saved (tests point it elsewhere).
const SAVES_FOLDER := "user://adventures"
static var saves_folder := SAVES_FOLDER
const AUTOSAVE := "autosave"

## The five colours in the 1997 game's order (1 black … 5 white, as the
## amulets are kept, `g_amulet_inventory`).
const COLORS: Array[String] = ["black", "blue", "green", "red", "white"]

## THE TWELVE WORLD MAGICS, by their bit in the original's bitmap
## (0x22110–0x22111). Each colour's pair is bits 2c and 2c + 1 for colour c
## (1 black … 5 white): the first of the pair is the hero's from the start.
const WORLD_MAGICS: Array[String] = ["Sleight of Hand", "Haggler's Coin",
	"Conjurer's Will", "Amulet of Swampwalk", "Leap of Fate",
	"Tome of Enlightenment", "Quickening", "Fruit of Sustenance",
	"Staff of Thunder", "Dwarven Pick", "Sword of Resistance",
	"Ring of the Guardian"]

## The site types by name ([ShandalarWorld]).
const SITE_KINDS: Array[String] = ["none", "village", "town", "city", "castle", "ruined castle"]


# ------------------------------------------------------------ the game --

## `<name>-<hash>`: the hero's name made safe for a file, and eight hex
## digits of a hash of the name and the moment the adventure began.
var adventure_id := ""
## When the adventure began and when it was last saved (ISO, UTC).
var created := ""
var saved := ""
## The game version that saved it.
var game_version := ""


# -------------------------------------------------------- who the hero is --

var name := ""
## The face (a PortraitLibrary id) — ours; the 1997 hero was a face set.
var portrait := ""
## The figure on the map, `male` or `female` (gender, 0x224B4).
var walker := "male"
## The figure's colours, `{part: key}` ([HeroColors]) — ours.
var figure_colors := {}
## The hero's colour (starting colour, 0x224B8).
var color := "white"
## 0 Apprentice … 3 Wizard (0x1EA24).
var difficulty := 0
## The playmat of the hero's duels, `{color, type}` — ours.
var playmat := {}
## The card packs that join this adventure, `[{id, version}]` — ours.
var packs: Array = []


# --------------------------------------------------------------- where --

## The hero's place in world units, 32 to a tile (0x1EAEC, 0x1EAF0).
var position := Vector2i.ZERO
## The way the hero last walked, 1–8 (`g_neighbor_dx/dy`: 1 north … 8
## north-west), 0 before the first step.
var facing := 0
## The walking figure's step, 0 standing, 1–4 walking.
var step := 0


# ------------------------------------------------- what the hero carries --

var gold := 0                                   # 0x21D20
var food := 0                                   # 0x21D24
## Amulets of each colour (0x21D0C, five counts).
var amulets := {"black": 0, "blue": 0, "green": 0, "red": 0, "white": 0}
## The World Magics owned, by name ([constant WORLD_MAGICS]).
var world_magics: Array[String] = []
## Every card owned, `{card, decks}` — the card's name and which of the
## three decks it is in (0x1420); the first deck dealt by [StarterDeck].
var cards: Array = []
## The deck in use, 0–2 (0x224C4), and the colours it was last played in
## (0x1EA20).
var current_deck := 0
var deck_colors: Array[String] = []
## The three decks' names, "" for `Deck N`, and their notes — ours.
var deck_names: Array[String] = ["", "", ""]
var deck_notes: Array[String] = ["", "", ""]


# ------------------------------------------------------------ the duels --

## The towns and cities whose mana the hero has linked, by site slot: each
## adds a life in duels. (The 1997 save marks a link in the site's status,
## bit 1; but the world is made with that bit already set on ten towns,
## whose meaning there is not yet read, so the hero's links are kept here.)
var mana_links: Array[int] = []
## Lives added to (or taken from) the next duel (0x224BC, and the extra
## lives 1–5 the 1997 game kept in 0x224C0).
var next_duel_life := 0
## A card the next duel starts with in play, "" for none (0x224C0 above 5).
var next_duel_card := ""
## The first move in the next duel (0x224C0 = 0).
var next_duel_first_move := false
## Each duel won against a roaming creature: `{color, creature}`
## (0x21D28) — enough wins and they flee or pay tribute.
var duel_victories: Array = []
## The main colours of the last duel, the hero's and the enemy's (0x2A1D4).
var last_duel_colors := {}


# ---------------------------------------------------------- the record --

## What has happened, `{event, what, x, y, time}` (the journal, 0x224C8);
## the win and loss record is read from it.
var journal: Array = []
## The wizards beaten, by colour (0x221D4).
var defeated_wizards: Array[String] = []
## Lairs explored (0x224AC): the more, the fewer and the stronger the
## creatures met.
var lairs_explored := 0
## The quest under way, `{}` for none (0x21CF8; its fields in [WorldStatus]).
var quest := {}


# ------------------------------------------------------------ the clocks --

## The world's clock: one tick per 60 ms of the world screen (0x1EAF4).
var monster_timer := 0
## The quest and restocking clock (0x224B0), and the siege clock
## (0x224A8): both a step for every 32 ticks the hero walks.
var quest_timer := 0
var siege_timer := 0
var siege_active := false                       # 0x2A220
## Quickening's ticks left (`Scards[6].worldmagic_duration`): while it
## runs, every step goes a unit further ([WorldMagic]).
var quickening := 0


# ------------------------------------------------------------- the world --

## The world itself: terrain, sites, roads, encounters, what is explored.
var world: ShandalarWorld
## The seed as the player typed or was given it.
var world_seed_text := ""
## The world's fingerprint when it was made, before a tile was explored
## ([method ShandalarWorld.fingerprint]): the world can be checked against
## its recipe.
var made_fingerprint := ""
## The adventure's dice: they go on from where the world left them
## ([member ShandalarWorld.rand_state]).
var dice := 0
## The towns' card shops, by site slot (`"<slot>"`): `{cards, restock}` —
## the cards on offer ("" for a place sold), and when each sold place may
## be filled again on the quest clock ([CardShop]; 1997 kept them per
## town, `card_slots`, `card_restock_timers`).
var shops := {}
## The roaming creatures and lairs (0x1EA2C: six slots and a siege), none
## until they are made: `{slot, name, x, y, …}`, slots 0–5 roaming, 7 the
## creature besieging a city (`town`, its site slot) ([WorldMagic]).
var monsters: Array = []


# ------------------------------------------------------ a new adventure --

## A NEW ADVENTURE from the Embark screen's [param record]
## ([method AdventureSetup.resolve]) and the [param world] made from it:
## what the 1997 game gives a new hero (`InitializeNewGameState`, 1.3) —
## gold, food, an amulet of their colour and (3 − difficulty) more of
## colours drawn by the dice, their first deck ([StarterDeck]) and their
## colour's first World Magic — standing where the world puts them.
static func begin(record: Dictionary, made: ShandalarWorld) -> AdventurePlayer:
	var player := AdventurePlayer.new()
	var hero: Dictionary = record.get("hero", {})
	var start: Dictionary = record.get("start", {})
	player.name = String(hero.get("name", ""))
	player.portrait = String(hero.get("portrait", ""))
	player.walker = String(hero.get("walker", "male"))
	player.figure_colors = HeroColors.cleaned(hero.get("figure_colors", {}))
	player.color = String(record.get("color", "white"))
	player.difficulty = int(record.get("difficulty", 0))
	player.playmat = (record.get("playmat", {}) as Dictionary).duplicate(true)
	player.packs = (record.get("packs", []) as Array).duplicate(true)
	player.world_seed_text = String(record.get("seed_text", str(record.get("seed", 0))))
	player.game_version = String(ProjectSettings.get_setting("application/config/version", ""))
	var now := Time.get_unix_time_from_system()
	player.created = Time.get_datetime_string_from_unix_time(int(now), false) + "Z"
	player.adventure_id = make_id(player.name, int(now * 1000.0))
	player.world = made
	player.made_fingerprint = made.fingerprint()
	player.position = made.start
	player.gold = int(start.get("gold", 0))
	player.food = int(start.get("food", 0))
	# The amulets: one of the hero's colour, then the rest of colours drawn
	# with the original's `internal_rand(5) + 1`, on the adventure's dice.
	var rolls := MsvcRandom.new(made.rand_state)
	player.amulets[player.color] = 1
	for extra in maxi(int(start.get("amulets", 1)) - 1, 0):
		var drawn: String = COLORS[rolls.below(5)]
		player.amulets[drawn] = int(player.amulets[drawn]) + 1
	# The first deck (ours after the amulets; 1997 dealt it first), every
	# card in Deck 1 as `InitializeNewGameState` marks them.
	for card_name in StarterDeck.deal(player.color, player.difficulty, rolls):
		player.cards.append({"card": card_name, "decks": [0]})
	player.dice = rolls.state
	var own := AdventureSetup.color_number(player.color)
	player.world_magics.append(WORLD_MAGICS[own * 2])
	made.explore_around(made.start_tile())
	return player


## `<name>-<hash>` for [param hero_name] at [param unix_ms]: letters and
## digits of the name (others as `-`), and the 32-bit FNV-1a hash of the
## name and the moment, in hex.
static func make_id(hero_name: String, unix_ms: int) -> String:
	var slug := ""
	for i in hero_name.length():
		var c := hero_name.unicode_at(i)
		var plain := (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122)
		slug += hero_name[i] if plain else "-"
	while slug.contains("--"):
		slug = slug.replace("--", "-")
	slug = slug.strip_edges().trim_prefix("-").trim_suffix("-")
	if slug == "":
		slug = "hero"
	var value := 2166136261
	for byte in ("%s|%d" % [hero_name, unix_ms]).to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return "%s-%08x" % [slug, value]


# ------------------------------------------------------------ the stats --

## The difficulty by name.
func difficulty_name() -> String:
	return AdventureSetup.DIFFICULTIES[clampi(difficulty, 0, 3)]


## Whether the hero owns the World Magic [param magic_name].
func owns(magic_name: String) -> bool:
	return magic_name in world_magics


## Wins and losses, read from the journal (event 2, `won` true or false).
func duel_record() -> Dictionary:
	var won := 0
	var lost := 0
	for entry in journal:
		if String(entry.get("event", "")) == "duel":
			if bool(entry.get("won", false)):
				won += 1
			else:
				lost += 1
	return {"won": won, "lost": lost}


## A line for the journal: [param event] (`duel`, `magic`, `quest`,
## `saved`, `freed`, `treasure`, …), what happened in the 1997 game's
## words ([param text], `@LOGSTRINGS`), where and when (the world's clock
## and the day on the road), and [param more] ([HeroStats.record]).
func log_event(event: String, text: String, more := {}) -> void:
	var entry := {"event": event, "text": text, "x": position.x, "y": position.y, "time": monster_timer,
		"day": quest_timer / WorldStatus.DAY}
	entry.merge(more)
	journal.append(entry)


## The amulets in all.
func amulet_count() -> int:
	var count := 0
	for key in amulets:
		count += int(amulets[key])
	return count


## The hero's tile.
func tile() -> Vector2i:
	return Vector2i(position.x / 32, position.y / 32)


# ---------------------------------------------------------- the save --

## The adventure as a dictionary, every part named, for JSON.
func to_dict() -> Dictionary:
	var grid: Array[String] = []
	for y in ShandalarWorld.TILES * 2:
		grid.append(world.page.slice(y * ShandalarWorld.PAGE_WIDTH,
			y * ShandalarWorld.PAGE_WIDTH + ShandalarWorld.TILES).hex_encode())
	var sites: Array = []
	for slot in world.sites.size():
		var site: Dictionary = world.sites[slot]
		sites.append({"slot": slot, "kind": SITE_KINDS[clampi(int(site["type"]), 0, 5)],
			"type": int(site["type"]), "x": int(site["x"]), "y": int(site["y"]),
			"trade": int(site["trade"]), "status": int(site["status"])})
	return {
		"format": FORMAT,
		"version": FORMAT_VERSION,
		"about": "One adventure in the world of Shandalar: the hero, what they carry, their record, the clocks, and the world as it now stands. The world's grid is 128 rows of 64 tile bytes in hex: rows 0-63 the tiles (terrain in the low four bits; 0x10 a site, 0x20 a road, 0x40 a dungeon, 0x80 explored), rows 64-127 the roads leaving each tile, a bit per direction.",
		"adventure": {"id": adventure_id, "created": created, "saved": saved, "game_version": game_version},
		"hero": {"name": name, "portrait": portrait, "figure": walker,
			"figure_colors": figure_colors, "color": color,
			"difficulty": difficulty, "difficulty_name": difficulty_name(),
			"playmat": playmat, "packs": packs},
		"where": {"x": position.x, "y": position.y, "tile": [tile().x, tile().y],
			"facing": facing},
		"carried": {"gold": gold, "food": food, "amulets": amulets,
			"world_magics": world_magics, "cards": cards, "current_deck": current_deck,
			"deck_names": deck_names, "deck_notes": deck_notes, "deck_colors": deck_colors},
		"duels": {"next_duel_life": next_duel_life, "next_duel_card": next_duel_card,
			"next_duel_first_move": next_duel_first_move,
			"victories": duel_victories, "last_duel_colors": last_duel_colors,
			"mana_links": mana_links, "record": duel_record()},
		"record": {"journal": journal, "defeated_wizards": defeated_wizards,
			"lairs_explored": lairs_explored, "quest": quest},
		"clocks": {"monster_timer": monster_timer, "quest_timer": quest_timer,
			"siege_timer": siege_timer, "siege_active": siege_active,
			"quickening": quickening},
		"world": {
			"seed": world.seed, "seed_text": world_seed_text, "slot_start": world.slot_start,
			"color": world.color, "difficulty": world.difficulty, "generator": "1997 (1.3)",
			"made_fingerprint": made_fingerprint, "dice": dice,
			"start": [world.start.x, world.start.y],
			"grid": grid,
			"sites": sites,
			"world_magic_sites": world.world_magic_sites,
			"encounters": world.encounters,
			"lair_respawn": world.lair_respawn,
			"monsters": monsters,
			"shops": shops,
		},
	}


## THE ADVENTURE FROM A SAVE, or null when [param data] is not one this
## game can read (its [constant FORMAT] or a newer [constant FORMAT_VERSION]).
static func from_dict(data: Dictionary) -> AdventurePlayer:
	if String(data.get("format", "")) != FORMAT or int(data.get("version", 0)) < 1 \
			or int(data.get("version", 0)) > FORMAT_VERSION:
		return null
	var player := AdventurePlayer.new()
	var game: Dictionary = data.get("adventure", {})
	player.adventure_id = String(game.get("id", ""))
	player.created = String(game.get("created", ""))
	player.saved = String(game.get("saved", ""))
	player.game_version = String(game.get("game_version", ""))
	var hero: Dictionary = data.get("hero", {})
	player.name = String(hero.get("name", ""))
	player.portrait = String(hero.get("portrait", ""))
	player.walker = String(hero.get("figure", "male"))
	player.figure_colors = HeroColors.cleaned(hero.get("figure_colors", {}))
	player.color = String(hero.get("color", "white"))
	player.difficulty = int(hero.get("difficulty", 0))
	player.playmat = _whole(hero.get("playmat", {}))
	player.packs = _whole(hero.get("packs", []))
	var where: Dictionary = data.get("where", {})
	player.position = Vector2i(int(where.get("x", 0)), int(where.get("y", 0)))
	player.facing = int(where.get("facing", 0))
	var carried: Dictionary = data.get("carried", {})
	player.gold = int(carried.get("gold", 0))
	player.food = int(carried.get("food", 0))
	var amulets_saved: Dictionary = carried.get("amulets", {})
	for key in COLORS:
		player.amulets[key] = int(amulets_saved.get(key, 0))
	for magic in carried.get("world_magics", []):
		if String(magic) in WORLD_MAGICS:
			player.world_magics.append(String(magic))
	player.cards = _whole(carried.get("cards", []))
	player.current_deck = clampi(int(carried.get("current_deck", 0)), 0, 2)
	var titles: Array = carried.get("deck_names", [])
	for slot in mini(titles.size(), 3):
		player.deck_names[slot] = String(titles[slot])
	var notes: Array = carried.get("deck_notes", [])
	for slot in mini(notes.size(), 3):
		player.deck_notes[slot] = String(notes[slot])
	for key in carried.get("deck_colors", []):
		player.deck_colors.append(String(key))
	var duels: Dictionary = data.get("duels", {})
	for slot in duels.get("mana_links", []):
		player.mana_links.append(int(slot))
	player.next_duel_life = int(duels.get("next_duel_life", 0))
	player.next_duel_card = String(duels.get("next_duel_card", ""))
	player.next_duel_first_move = bool(duels.get("next_duel_first_move", false))
	player.duel_victories = _whole(duels.get("victories", []))
	player.last_duel_colors = _whole(duels.get("last_duel_colors", {}))
	var kept: Dictionary = data.get("record", {})
	player.journal = _whole(kept.get("journal", []))
	for key in kept.get("defeated_wizards", []):
		player.defeated_wizards.append(String(key))
	player.lairs_explored = int(kept.get("lairs_explored", 0))
	player.quest = _whole(kept.get("quest", {}))
	var clocks: Dictionary = data.get("clocks", {})
	player.monster_timer = int(clocks.get("monster_timer", 0))
	player.quest_timer = int(clocks.get("quest_timer", 0))
	player.siege_timer = int(clocks.get("siege_timer", 0))
	player.siege_active = bool(clocks.get("siege_active", false))
	player.quickening = int(clocks.get("quickening", 0))
	var saved_world: Dictionary = data.get("world", {})
	var made := _world_from(saved_world)
	if made == null:
		return null
	player.world = made
	player.world_seed_text = String(saved_world.get("seed_text", str(made.seed)))
	player.made_fingerprint = String(saved_world.get("made_fingerprint", ""))
	player.dice = int(saved_world.get("dice", made.rand_state))
	player.monsters = _whole(saved_world.get("monsters", []))
	player.shops = _whole(saved_world.get("shops", {}))
	return player


## [param value] with every whole number JSON read back as a float made an
## integer again, all the way down.
static func _whole(value: Variant) -> Variant:
	if value is float and is_equal_approx(value, roundf(value)) and absf(value) < 9.0e15:
		return int(value)
	if value is Array:
		var out: Array = []
		for item in value:
			out.append(_whole(item))
		return out
	if value is Dictionary:
		var out := {}
		for key in value:
			out[key] = _whole(value[key])
		return out
	return value


static func _world_from(saved_world: Dictionary) -> ShandalarWorld:
	var grid: Array = saved_world.get("grid", [])
	if grid.size() != ShandalarWorld.TILES * 2:
		return null
	var made := ShandalarWorld.new()
	made.seed = int(saved_world.get("seed", 0))
	made.slot_start = int(saved_world.get("slot_start", 0))
	made.color = int(saved_world.get("color", 1))
	made.difficulty = int(saved_world.get("difficulty", 0))
	made.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	for y in grid.size():
		var row := String(grid[y]).hex_decode()
		if row.size() != ShandalarWorld.TILES:
			return null
		for x in ShandalarWorld.TILES:
			made.page[y * ShandalarWorld.PAGE_WIDTH + x] = row[x]
	for site in saved_world.get("sites", []):
		made.sites.append({"x": int(site.get("x", 0)), "y": int(site.get("y", 0)),
			"type": int(site.get("type", 0)), "trade": int(site.get("trade", 0)),
			"status": int(site.get("status", 0))})
	for slot in saved_world.get("world_magic_sites", []):
		made.world_magic_sites.append(int(slot))
	for slot in saved_world.get("encounters", []):
		var encounter: Dictionary = (slot as Dictionary).duplicate(true)
		for key in ["x", "y", "town", "color", "monster_flags", "rules", "card_in_effect", "clues"]:
			if encounter.has(key):
				encounter[key] = int(encounter[key])
		var held: Array[int] = []
		for card in encounter.get("cards", []):
			held.append(int(card))
		encounter["cards"] = held
		made.encounters.append(encounter)
	for when in saved_world.get("lair_respawn", []):
		made.lair_respawn.append(int(when))
	var start: Array = saved_world.get("start", [0, 0])
	made.start = Vector2i(int(start[0]), int(start[1]))
	made.rand_state = int(saved_world.get("dice", 0))
	return made


## Whether the world still answers to its recipe: its fingerprint, with the
## explored marks taken off, is the one it was made with.
func world_intact() -> bool:
	var plain := ShandalarWorld.new()
	plain.page = world.page.duplicate()
	for y in ShandalarWorld.TILES:
		for x in ShandalarWorld.TILES:
			var at := y * ShandalarWorld.PAGE_WIDTH + x
			plain.page[at] = plain.page[at] & ~ShandalarWorld.EXPLORED & 0xFF
	return plain.fingerprint() == made_fingerprint


## The file [param kind] of this adventure is saved in.
func save_path(kind := AUTOSAVE) -> String:
	return saves_folder.path_join("%s.%s.json" % [adventure_id, kind])


## Write the adventure to [param path] (the autosave by default); the path
## written, or "" when it could not be.
func save(path := "") -> String:
	if path == "":
		path = save_path()
	DirAccess.make_dir_recursive_absolute(path.get_base_dir())
	saved = Time.get_datetime_string_from_system(true) + "Z"
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file == null:
		push_warning("AdventurePlayer: cannot write %s" % path)
		return ""
	file.store_string(JSON.stringify(to_dict(), "\t"))
	file.close()
	return path


## THE AUTOSAVE, written when the adventure begins.
func autosave() -> String:
	return save(save_path(AUTOSAVE))


## The adventure saved at [param path], or null.
static func load_from(path: String) -> AdventurePlayer:
	if not FileAccess.file_exists(path):
		return null
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if not parsed is Dictionary:
		return null
	return from_dict(parsed)


## The saved adventures, newest first: `{path, kind, id, name, color,
## difficulty, saved, seed_text}` read from each file's own fields; the
## kind (`autosave` or `save`) from its name.
static func list_saves(folder := "") -> Array[Dictionary]:
	if folder == "":
		folder = saves_folder
	var found: Array[Dictionary] = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return found
	for file_name in dir.get_files():
		if not file_name.ends_with(".json"):
			continue
		var path := folder.path_join(file_name)
		var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
		if not parsed is Dictionary or String((parsed as Dictionary).get("format", "")) != FORMAT:
			continue
		var data: Dictionary = parsed
		var hero: Dictionary = data.get("hero", {})
		var game: Dictionary = data.get("adventure", {})
		var saved_world: Dictionary = data.get("world", {})
		found.append({"path": path, "kind": file_name.get_basename().get_extension(),
			"id": String(game.get("id", "")),
			"name": String(hero.get("name", "")), "color": String(hero.get("color", "")),
			"difficulty": int(hero.get("difficulty", 0)), "saved": String(game.get("saved", "")),
			"seed_text": String(saved_world.get("seed_text", ""))})
	found.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["saved"]) > String(b["saved"]))
	return found
