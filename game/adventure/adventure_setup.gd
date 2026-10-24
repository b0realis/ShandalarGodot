class_name AdventureSetup
extends RefCounted
## A NEW ADVENTURE, DECIDED — every choice the Embark screen
## ([EmbarkScreen]) offers, held where a test, the MCP server or a decision
## model can make them without a screen ("headless first",
## `docs/adventure-implementation-notes.md`).
##
## THE CHOICES (owner design, 2026-10-04, put on one screen 2026-10-22):
## the hero's face, their name, the figure that walks the map, the colour
## of their magic, their playmat, the card packs that join, and the
## difficulty. The 1997 game asked three of these on three screens
## (difficulty, colour, face); version 1.3 designed the face and typed the
## name; the rest is ours, and every row below says which it is.
##
## [method resolve] turns the choices into the record the world will be
## made from: what was chosen, what the seed decided, and what the hero
## starts with. Nothing here makes a world — the generator is the next
## piece of M5 and takes this record as its input.

## `@DIFFICULTYLEVELS` (`Advstrings.txt`), the same four words as the duel
## AI's levels. The index is the 1997 one, 0 to 3.
const DIFFICULTIES: Array[String] = ["Apprentice", "Magician", "Sorcerer", "Wizard"]

## WHAT EACH LEVEL IS, in plain words (the owner, 2026-10-22: *"it is not
## immediately apparent how difficult it is"*) — the four names are titles
## of rank, not of difficulty, so the screen says it beside them.
const DIFFICULTY_WORDS: Array[String] = ["Training game", "Easy game", "Normal game", "Hard game"]


## "a training game", "an easy game" — the level's word with its article.
static func difficulty_phrase(level: int) -> String:
	var word := DIFFICULTY_WORDS[clampi(level, 0, DIFFICULTY_WORDS.size() - 1)].to_lower()
	return ("an " if word.left(1) in ["a", "e", "i", "o", "u"] else "a ") + word

## THE FIVE COLOURS, white first as everywhere else in this game. Each
## row carries what the 1997 sources tie to the colour:
##  - `number`: the game's own colour number (Black 1, Blue 2, Green 3,
##    Red 4, White 5 — `g_color_menu_selection_to_deck_color`, 1.3).
##  - `world_magic`: the one world magic a new hero of this colour owns
##    from the start — the first of the colour's pair, `colour × 2` in the
##    `@WORLDMAGIC_NAMES` order (`InitializeNewGameState`, 1.3 and retail
##    alike).
##  - `flavor`: the colour menu's line (`Advbuttons.txt`
##    `[colorMenuFlavor]`), with its one misspelling mended.
##  - `symbol`: the colour's cell in `stat_buttons` (`Statbutt.spr`): the
##    skull, the drop, the tree, the fire and the sun, 48 px apart.
const COLORS: Array[Dictionary] = [
	{"key": "white", "name": "White", "number": 5, "symbol": 4,
		"world_magic": "Sword of Resistance",
		"flavor": "The focus of white magic is on Healing, Protection and the Chivalrous arts of war."},
	{"key": "blue", "name": "Blue", "number": 2, "symbol": 1,
		"world_magic": "Leap of Fate",
		"flavor": "Blue magic thrives on mental energy, artifice and illusion."},
	{"key": "black", "name": "Black", "number": 1, "symbol": 0,
		"world_magic": "Conjurer's Will",
		"flavor": "Black magic's power comes from death and decay."},
	{"key": "red", "name": "Red", "number": 4, "symbol": 3,
		"world_magic": "Staff of Thunder",
		"flavor": "Red Magicians specialize in the violence of Chaos and Combat."},
	{"key": "green", "name": "Green", "number": 3, "symbol": 2,
		"world_magic": "Quickening",
		"flavor": "Like nature, Green magic can bring both soothing serenity and thunderous destruction."},
]

## THE FOURTEEN HEROES of the 1997 character screen: `16faces.spr` in
## frame order, imported under these ids (`tools/import_original.py`,
## PORTRAIT_NAMES), each with its `@PLAYERNAMES` name as the game spelled
## it and the figure the game walked it as (`gender_map`, 1.3's
## `adventure_main_menu.c`: 1 is the female walker).
const HEROES: Array[Dictionary] = [
	{"id": "melody_whisp", "name": "Melody Whisp", "walker": "female"},
	{"id": "sir_van_popple", "name": "Sir Van Popple", "walker": "male"},
	{"id": "muriallisa", "name": "Muriallisa", "walker": "female"},
	{"id": "goya", "name": "Goya", "walker": "male"},
	{"id": "lady_dragetta", "name": "Lady Dragetta", "walker": "female"},
	{"id": "ali_of_willoshire", "name": "Ali of Willoshire", "walker": "male"},
	{"id": "snow_blight", "name": "Snow Blight", "walker": "female"},
	{"id": "baba_bue", "name": "Baba Bue", "walker": "male"},
	{"id": "dina_bin-barq", "name": "Dina bin-Barq", "walker": "female"},
	{"id": "inniscor", "name": "Inniscor", "walker": "male"},
	{"id": "gauldron", "name": "Gauldron", "walker": "male"},
	{"id": "agnosia", "name": "Agnosia", "walker": "female"},
	{"id": "wu_wei", "name": "Wu Wei", "walker": "male"},
	{"id": "keleena", "name": "Keleena", "walker": "female"},
]

## THE FIGURE ON THE MAP. The original has two walkers, `Ego_M.spr` and
## `Ego_F.spr`; `other` [QoL] is one of the two, drawn by the world's
## seed ([method resolve]), so a hero need not be either.
const WALKERS: Array[String] = ["male", "female", "other"]
const WALKER_LABELS: Array[String] = ["Male", "Female", "Other"]

## THE PACKS AN ADVENTURE NEVER OFFERS (the owner, 2026-10-22: *"Pack
## one is just a couple of problem cards and should always be ignored"*).
## Pack 1 completes the 1997 base set with the few cards the original left
## out; the base cards are always there, so an adventure takes only the
## expansions, Packs 2 onwards, each as a world of its own.
const IGNORED_PACKS: Array[String] = ["pack-1"]


## The installed packs an adventure may take: [param installed] without
## [constant IGNORED_PACKS].
static func offered_packs(installed: Array[String]) -> Array[String]:
	var out: Array[String] = []
	for id in installed:
		if not id in IGNORED_PACKS:
			out.append(id)
	return out


## THE PLAYMAT: any of the fifteen grounds the duel has — a colour and
## one of [constant DuelOptions.TERRITORY_TYPES]. `""` for the colour is
## the hero's own; [constant RANDOM_TYPE] is 1.3's choice, one of the
## colour's three at random (`RunAdventureSession`).
const RANDOM_TYPE := "Random"

## 1.3's name field: 25 characters (`ApplyNameEntryKey`). 1.3 took only
## letters, digits and spaces, which refused one of its own heroes
## (`Dina bin-Barq`); any printable character goes here [QoL].
const NAME_MAX := 25


## NAMES FOR RANDOMIZE (the owner, 2026-10-22: *"a set of wonderful
## (sometimes funny) 100 magical names and 100 magical surname
## combinations"*): ours, made for this game; any first name with any
## surname, ten thousand heroes, each within [constant NAME_MAX].
const FIRST_NAMES: Array[String] = [
	"Aldric", "Belisande", "Corvin", "Dulcibel", "Elowen", "Fizzwick", "Grimwald", "Hesperine",
	"Ignatius", "Jinx", "Kestrel", "Lucan", "Morwenna", "Nim", "Orrin", "Pipwick", "Quillon",
	"Rowena", "Sable", "Thaddeus", "Ulric", "Vesper", "Wendeline", "Xandor", "Ysolde",
	"Zephyrine", "Alaric", "Bramble", "Cassius", "Dorabella", "Eldritch", "Fennimore",
	"Gwendolyn", "Hobb", "Isolde", "Jasper", "Kitterick", "Lumina", "Mungo", "Nettle", "Ozwald",
	"Prudence", "Quincy", "Ravenna", "Silas", "Tamsin", "Umber", "Valerian", "Wilhelmina",
	"Xenia", "Yarrow", "Zebedee", "Ambrose", "Bartholomew", "Cressida", "Drusilla", "Ebenezer",
	"Florian", "Griselda", "Horatio", "Ivy", "Jonquil", "Kasimir", "Lavender", "Merriwether",
	"Nicodemus", "Ophelia", "Percival", "Querida", "Rufus", "Seraphina", "Tobias", "Ursula",
	"Vivienne", "Wolfram", "Xavier", "Yseult", "Zinnia", "Archibald", "Bellamy", "Clementine",
	"Desmond", "Esmeralda", "Fergus", "Gideon", "Hyacinth", "Ingrid", "Jethro", "Kittredge",
	"Lysander", "Mirabel", "Norbert", "Odette", "Phineas", "Rosalind", "Sprocket", "Theodora",
	"Wimble", "Ysmay", "Zoltan",
]
const SURNAMES: Array[String] = [
	"Ashwhisper", "Bramblecloak", "Cinderwhisk", "Dewdrop", "Emberquill", "Frostwhistle",
	"Gloomsbury", "Hornswoggle", "Inkpot", "Jinglebottom", "Kettlewhistle", "Lanternjaw",
	"Moonbottle", "Nightshade", "Owlfeather", "Puddlefoot", "Quicksilver", "Ravensbane",
	"Stormbrew", "Thistledown", "Umbervale", "Vexmoor", "Wormwood", "Yarrowby", "Zephyrwind",
	"Applecrumble", "Bogsworth", "Crumplehorn", "Dragonsbreath", "Everdusk", "Fiddlesticks",
	"Grimthorne", "Hexley", "Ironquill", "Jumbleweed", "Knucklebone", "Lichwood", "Mandrake",
	"Nettlebeard", "Oddsocks", "Pumpernickel", "Quagmire", "Rattlebones", "Spellbinder",
	"Tumbledown", "Underbough", "Vinegarth", "Wandsworth", "Wizzleton", "Yawnsley", "Ziggurat",
	"Ashgrove", "Blackthorn", "Candlewick", "Darkwater", "Elderberry", "Featherstone",
	"Goblinsbane", "Hollowmere", "Icewhisper", "Jackdaw", "Kindlewood", "Larkspur", "Mistwalker",
	"Nimbletoe", "Oakenbarrow", "Pennywhistle", "Quillfeather", "Runecaster", "Silvermane",
	"Toadstool", "Umbrage", "Velvetpaw", "Willowisp", "Wobblewand", "Yellowtooth", "Zanzibar",
	"Brambleworth", "Cauldronby", "Dimwitty", "Earwig", "Fogbottom", "Gobbleshank", "Hearthwick",
	"Inglenook", "Jabberwick", "Kraken", "Leafwhistle", "Mugwort", "Nackerby", "Owlhollow",
	"Picklewand", "Quibble", "Rumbleguts", "Starfall", "Sneezewort", "Trollbridge", "Wizzlewhip",
	"Snapdragon", "Bumblesnout",
]


## A first name and a surname drawn from [constant FIRST_NAMES] and
## [constant SURNAMES].
static func random_name(rng: RandomNumberGenerator) -> String:
	return "%s %s" % [FIRST_NAMES[rng.randi_range(0, FIRST_NAMES.size() - 1)],
		SURNAMES[rng.randi_range(0, SURNAMES.size() - 1)]]

## THE WORLD'S SEED: the dice's state as the world begins
## ([WorldGenerator]). The 1997 game seeded its dice from the clock, once,
## as it started — `srand(GetTickCount())` in 1.3 (`shandalar.c`), the
## milliseconds Windows had been running — and never showed the number;
## here the Embark screen fills it in from the clock, as a time of day
## ([method time_seed_text]), and any number or word may be typed, so a
## world can be made again [QoL]: a number up to [constant SEED_MAX] is the
## seed itself, anything else is turned into one ([method text_seed]).
const SEED_MAX := 0xFFFFFFFF
## The most a typed seed holds.
const SEED_LENGTH := 24

## The record's own version, for the day a world is saved from it.
const RECORD_VERSION := 1

## Where the choices are remembered between visits ([method remember]).
## The seed is not: a seed is one world's identity, the same rule the
## battle-setup screen keeps for a duel's.
const KEY_PREFIX := "adventure_"

var portrait := ""
var player_name := ""
## `""` until the player picks one: then the hero's own figure is used
## ([method walker_shown]), so choosing Melody Whisp walks her as herself.
var walker := ""
var color := "white"
var playmat_color := ""
var playmat_type := RANDOM_TYPE
var packs: Array[String] = []
var difficulty := 0
## The card rule of the adventure ([member AdventurePlayer.card_rule]): as
## 1997 meant it, as 1997 shipped it, or the classic MTG rules.
var card_rule := AdventurePlayer.RULE_MEANT
## The card rule as the on/off copy limit it began as (on "as intended", off
## "as shipped").
var copy_limit: bool:
	get:
		return card_rule == AdventurePlayer.RULE_MEANT
	set(on):
		card_rule = AdventurePlayer.RULE_MEANT if on else AdventurePlayer.RULE_SHIPPED
var seed_text := ""
## The walking figure's colours, `{part: key}` ([HeroColors]); a part not
## named keeps its 1997 colour.
var figure_colors := {}


## The hero row for portrait id [param id], or `{}` for any other face.
static func hero(id: String) -> Dictionary:
	for row in HEROES:
		if row["id"] == id:
			return row
	return {}


## The colour row for [param key], or `{}`.
static func color_row(key: String) -> Dictionary:
	for row in COLORS:
		if row["key"] == key:
			return row
	return {}


## The name the field suggests for portrait [param id]: a hero's own,
## else the face's title, as 1.3 started from the face set's name.
static func suggested_name(id: String) -> String:
	var row := hero(id)
	if not row.is_empty():
		return String(row["name"])
	return clean_name(PortraitLibrary.title_of(id))


## [param text] as a name: no control or direction-override characters,
## runs of spaces made one, trimmed, at most [constant NAME_MAX] long.
static func clean_name(text: String) -> String:
	var kept := ""
	for i in text.length():
		var code := text.unicode_at(i)
		if code < 32 or code == 127 or (code >= 0x80 and code <= 0x9f) \
				or (code >= 0x200b and code <= 0x200f) \
				or (code >= 0x202a and code <= 0x202e) \
				or (code >= 0x2066 and code <= 0x2069):
			kept += " " if code == 9 else ""
			continue
		kept += text[i]
	var words := kept.split(" ", false)
	return " ".join(words).left(NAME_MAX).strip_edges()


## Why the chosen name cannot be used, or `""`.
func name_refusal() -> String:
	if clean_name(player_name) == "":
		return "Your hero needs a name."
	return ""


## The figure the screen shows as chosen: the player's own pick, or the
## hero's, or `other` for a face that is no hero's.
func walker_shown() -> String:
	if walker in WALKERS:
		return walker
	var row := hero(portrait)
	return String(row["walker"]) if not row.is_empty() else "other"


## The colour the playmat wears: its own, or the hero's.
func playmat_color_shown() -> String:
	return playmat_color if not color_row(playmat_color).is_empty() else color


## WHAT A NEW HERO STARTS WITH at [param level], from the sources
## (`docs/adventure-implementation-notes.md`, "New game in the sources"):
## gold `(5 − difficulty) × 50` and 50 food (`RunAdventureSession`,
## `g_food`), one amulet of the hero's colour and `3 − difficulty` of
## random colours, and the starting deck's size and colours as the
## retail game counts them.
static func starting_resources(level: int) -> Dictionary:
	var d := clampi(level, 0, DIFFICULTIES.size() - 1)
	return {
		"gold": (5 - d) * 50,
		"food": 50,
		"amulets": 4 - d,
		"deck_cards": [36, 39, 44, 45][d],
		"deck_colors": [1, 2, 3, 5][d],
	}


## The seed the field names, or 0 for "roll one" when it is empty. Digits
## alone that make 1 to [constant SEED_MAX] are the seed as they read;
## anything else typed — a word, a name, a longer number — is a seed too
## ([method text_seed]).
static func parse_seed(text: String) -> int:
	var typed := clean_seed(text)
	if typed == "":
		return 0
	var digits_only := typed.length() <= 10
	for i in typed.length():
		if typed.unicode_at(i) < 48 or typed.unicode_at(i) > 57:
			digits_only = false
	if digits_only and int(typed) >= 1 and int(typed) <= SEED_MAX:
		return int(typed)
	return text_seed(typed)


## A typed seed as it is kept and shown: its ends trimmed, no control
## characters, at most [constant SEED_LENGTH].
static func clean_seed(text: String) -> String:
	var kept := ""
	for i in text.length():
		if text.unicode_at(i) >= 32 and text.unicode_at(i) != 127:
			kept += text[i]
	return kept.strip_edges().left(SEED_LENGTH)


## A WORD AS A SEED: the 32-bit FNV-1a hash of its lower-case UTF-8 bytes,
## so `Marko` and `marko` make one world, the same on every machine. Never 0.
static func text_seed(text: String) -> int:
	var value := 2166136261
	for byte in text.to_lower().to_utf8_buffer():
		value = ((value ^ byte) * 16777619) & 0xFFFFFFFF
	return maxi(1, value)


## A SEED FROM THE CLOCK, as the 1997 game seeded its dice from the clock,
## written as the time of day so it reads as one (the owner, 2026-10-22):
## hours, minutes and seconds on the 24-hour clock, 14:35:07 → `143507`.
## Midnight is `240000`, as 0 is no seed.
static func time_seed_text() -> String:
	var now := Time.get_time_dict_from_system()
	var text := "%02d%02d%02d" % [int(now["hour"]), int(now["minute"]), int(now["second"])]
	return "240000" if text == "000000" else text


## THE RECORD A WORLD IS MADE FROM. [param pack_versions] maps each pack
## id to the version installed (the campaign resumes on the same pack or
## a newer one — the owner's ruling of 2026-10-04); a selected pack that
## is missing there is left out. [param rolled] is the seed to use when
## the field is empty; 0 takes one from the clock ([method time_seed_text]).
##
## ONE STREAM, IN ONE ORDER: the world's seed seeds it, and it draws the
## walker for `other` first, then the playmat style for `Random`. The
## world generator will go on drawing from the same seed, so a world and
## everything chosen for it replays from the one number.
func resolve(pack_versions: Dictionary, rolled := 0) -> Dictionary:
	var world_seed := parse_seed(seed_text)
	var shown_seed := clean_seed(seed_text)
	if world_seed == 0:
		shown_seed = str(rolled) if rolled > 0 else time_seed_text()
		world_seed = parse_seed(shown_seed)
	var rng := RandomNumberGenerator.new()
	rng.seed = world_seed
	var figure := walker_shown()
	if figure == "other":
		figure = "male" if rng.randi_range(0, 1) == 0 else "female"
	var style := playmat_type
	var labels: Array[String] = []
	for entry in DuelOptions.TERRITORY_TYPES:
		labels.append(String(entry["label"]))
	if not style in labels:
		style = labels[rng.randi_range(0, labels.size() - 1)]
	var chosen_packs: Array[Dictionary] = []
	for id in packs:
		if pack_versions.has(id) and not id in IGNORED_PACKS:
			chosen_packs.append({"id": id, "version": String(pack_versions[id])})
	var row := color_row(color)
	var start := starting_resources(difficulty)
	start["world_magic"] = String(row.get("world_magic", ""))
	start["amulet_color"] = color
	return {
		"version": RECORD_VERSION,
		"game_version": String(ProjectSettings.get_setting("application/config/version", "")),
		"seed": world_seed,
		"seed_text": shown_seed,
		"slot_start": slot_start_for(world_seed),
		"hero": {"portrait": portrait, "name": clean_name(player_name),
			"walker": figure, "walker_choice": walker_shown(),
			"figure_colors": HeroColors.cleaned(figure_colors)},
		"color": color,
		"difficulty": clampi(difficulty, 0, DIFFICULTIES.size() - 1),
		"card_rule": card_rule,
		"copy_limit": card_rule != AdventurePlayer.RULE_SHIPPED,
		"playmat": {"color": playmat_color_shown(), "type": style},
		"packs": chosen_packs,
		"start": start,
	}


## THE SITE PLACEMENT'S FIRST SLOT, 0–127. The original took it from its
## clock (`clock() % 128` in `GenerateWorldTownSlots`), no dice; here it
## follows the world's seed, so the seed alone names the world
## ([WorldGenerator]).
static func slot_start_for(world_seed: int) -> int:
	return posmod(world_seed, 128)


## The hero's colour as the original numbers it: 1 black, 2 blue, 3 green,
## 4 red, 5 white.
static func color_number(key: String) -> int:
	return int(color_row(key).get("number", 5))


## THE WORLD THE RECORD NAMES, made ([WorldGenerator]).
static func make_world(record: Dictionary) -> ShandalarWorld:
	return WorldGenerator.generate(int(record["seed"]), int(record.get("slot_start",
		slot_start_for(int(record["seed"])))), color_number(String(record["color"])),
		int(record["difficulty"]))


## WRITTEN WHEN THE PLAYER EMBARKS, and read back the next time the
## screen opens, so a second visit opens on the hero of the first.
func remember() -> void:
	Settings.set_value(KEY_PREFIX + "portrait", portrait, false)
	Settings.set_value(KEY_PREFIX + "name", clean_name(player_name), false)
	Settings.set_value(KEY_PREFIX + "walker", walker, false)
	Settings.set_value(KEY_PREFIX + "color", color, false)
	Settings.set_value(KEY_PREFIX + "playmat_color", playmat_color, false)
	Settings.set_value(KEY_PREFIX + "playmat_type", playmat_type, false)
	Settings.set_value(KEY_PREFIX + "packs", ",".join(packs), false)
	Settings.set_value(KEY_PREFIX + "figure_colors", HeroColors.to_text(figure_colors), false)
	Settings.set_value(KEY_PREFIX + "card_rule", card_rule, false)
	Settings.set_value(KEY_PREFIX + "difficulty", difficulty)


## The choices remembered by [method remember], each checked: a colour,
## figure, style or difficulty that is not one, or a pack not in
## [param installed], falls back rather than reaching a world.
static func restore(installed: Array[String]) -> AdventureSetup:
	var setup := AdventureSetup.new()
	setup.portrait = String(Settings.get_value(KEY_PREFIX + "portrait", ""))
	setup.player_name = clean_name(String(Settings.get_value(KEY_PREFIX + "name", "")))
	var figure := String(Settings.get_value(KEY_PREFIX + "walker", ""))
	setup.walker = figure if figure in WALKERS else ""
	var key := String(Settings.get_value(KEY_PREFIX + "color", "white"))
	setup.color = key if not color_row(key).is_empty() else "white"
	var mat := String(Settings.get_value(KEY_PREFIX + "playmat_color", ""))
	setup.playmat_color = mat if not color_row(mat).is_empty() else ""
	var style := String(Settings.get_value(KEY_PREFIX + "playmat_type", RANDOM_TYPE))
	setup.playmat_type = style if style == RANDOM_TYPE or _is_style(style) else RANDOM_TYPE
	for id in String(Settings.get_value(KEY_PREFIX + "packs", "")).split(",", false):
		if id in offered_packs(installed) and not id in setup.packs:
			setup.packs.append(id)
	setup.difficulty = clampi(int(Settings.get_value(KEY_PREFIX + "difficulty", 0)),
		0, DIFFICULTIES.size() - 1)
	# The rule remembered, else the on/off copy limit remembered before the
	# third rule.
	setup.card_rule = AdventurePlayer.card_rule_of(Settings.get_value(KEY_PREFIX + "card_rule", null),
		Settings.get_value(KEY_PREFIX + "copy_limit", true))
	setup.figure_colors = HeroColors.from_text(String(Settings.get_value(KEY_PREFIX + "figure_colors", "")))
	return setup


## Every remembered choice, by its key's tail ([constant KEY_PREFIX]).
const REMEMBERED: Array[String] = ["portrait", "name", "walker", "color",
	"playmat_color", "playmat_type", "packs", "difficulty", "figure_colors", "card_rule", "copy_limit"]


## Forget the remembered hero, so the screen opens on the defaults.
static func forget() -> void:
	for key in REMEMBERED:
		Settings.clear_value(KEY_PREFIX + key)


static func _is_style(label: String) -> bool:
	for entry in DuelOptions.TERRITORY_TYPES:
		if String(entry["label"]) == label:
			return true
	return false
