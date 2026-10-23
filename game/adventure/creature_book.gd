class_name CreatureBook
extends RefCounted
## THE CREATURES OF SHANDALAR — the 57 rows of the 1997 game's creature
## table (`g_shandalar_monster_definitions`, 1.3 `creature_names_init.inc`,
## its fields in `global_other.h`; the names, articles and plurals are
## `Advstrings.txt`'s `@CREATURENAMES`, `@CREATURENAME_ARTICLES` and
## `@CREATURENAMES_PLURAL`), written here as our own data. Row 0 is the
## lair, rows 55 and 56 Arzakon (56 the copy the Spectral Arena overwrites).
##
## Each row: article, name, plural, gender ("m" or "f"), tier (the
## creature's strength class, 4 … 20, Arzakon 100), base strength (1–3, its
## bribe and reward weight), kind (the encounter type: 0 lair, 1 male
## wizard, 2 female wizard, 3 knight, 4 lord, 5 djinn, 6 troll, 7 wyrm,
## 8 dragon, 9 flyer, 10 archmage, 11 henchman, 12 castle wizard,
## 13 Arzakon), colours (1997 colour bits: 0x02 black … 0x20 white, 0x01
## colourless), the 1997 deck number (`Decks/0NNN.dck`), its movement flags
## (`flags_0a`), its pre-duel flags, its reward flags, its reward card (the
## 1997 card id) and our deck file in `decks/1997/originals/` (each file
## names the 1997 deck it is). What the flags do is read where they are
## used (the encounters, [WorldLairs]).

const ARTICLE := 0
const NAME := 1
const PLURAL := 2
const GENDER := 3
const TIER := 4
const STRENGTH := 5
const KIND := 6
const COLORS := 7
const DECK_NUMBER := 8
const MOVE_FLAGS := 9
const PREDUEL_FLAGS := 10
const REWARD_FLAGS := 11
const REWARD_CARD := 12
const DECK_FILE := 13
## The encounter kinds the rows name.
const LAIR := 0
const CASTLE_WIZARD := 12
const ARZAKON := 13
const DECKS_FOLDER := "res://decks/1997/originals"

const ROWS: Array[Array] = [
	["a", "Lair", "Lairs", "m", 0, 1, 0, 0xFF, 0, 0x000, 0x000, 0x0000, 0, ""],  # 0
	["a", "Witch", "Witches", "f", 4, 2, 2, 0x02, 56, 0x000, 0x100, 0x0000, 0, "witch"],  # 1
	["an", "Undead Knight", "Undead Knights", "m", 6, 1, 3, 0x02, 16, 0x200, 0x008, 0x0010, 0, "undead_knight"],  # 2
	["a", "Warlock", "Warlocks", "m", 8, 3, 1, 0x02, 55, 0x000, 0x000, 0x0004, 55, "warlock"],  # 3
	["a", "VampireLord", "VampireLords", "m", 12, 2, 4, 0x02, 220, 0x000, 0x000, 0x0001, 0, "vampire_lord"],  # 4
	["a", "Nether Fiend", "Nether Fiends", "m", 16, 2, 9, 0x02, 151, 0x001, 0x000, 0x0010, 0, "nether_fiend"],  # 5
	["a", "Necromancer", "Necromancers", "m", 11, 2, 11, 0x02, 291, 0x002, 0x001, 0x0100, 286, "necromancer"],  # 6
	["a", "Greater Lich", "Greater Liches", "m", 20, 2, 12, 0x02, 141, 0x000, 0x040, 0x0040, 8, "azaar_lichlord"],  # 7
	["a", "Cleric", "Clerics", "m", 4, 2, 1, 0x20, 211, 0x000, 0x000, 0x0000, 0, "cleric"],  # 8
	["a", "Priestess", "Priestesses", "f", 6, 3, 2, 0x20, 204, 0x000, 0x002, 0x0800, 0, "priestess"],  # 9
	["a", "Crusader", "Crusaders", "m", 8, 2, 3, 0x20, 283, 0x200, 0x008, 0x0020, 283, "crusader"],  # 10
	["a", "Paladin", "Paladins", "m", 12, 2, 4, 0x20, 175, 0x000, 0x000, 0x0004, 128, "paladin"],  # 11
	["an", "Arch Angel", "Arch Angels", "f", 16, 2, 10, 0x20, 221, 0x001, 0x000, 0x0800, 0, "arch_angel"],  # 12
	["a", "High Priest", "High Priests", "m", 11, 2, 11, 0x20, 203, 0x000, 0x004, 0x0000, 0, "high_priest"],  # 13
	["a", "Sainted One", "Sainted Ones", "m", 20, 2, 12, 0x20, 21, 0x000, 0x040, 0x0040, 28, "sainted_one"],  # 14
	["a", "Seer", "Seers", "f", 4, 2, 2, 0x04, 69, 0x000, 0x100, 0x0000, 0, "seer"],  # 15
	["a", "Merfolk Shaman", "Merfolk Shamen", "m", 6, 1, 6, 0x04, 150, 0x010, 0x000, 0x0020, 160, "merfolk_shaman"],  # 16
	["a", "Conjurer", "Conjurers", "m", 8, 3, 1, 0x04, 260, 0x100, 0x004, 0x1000, 0, "conjurer"],  # 17
	["a", "Sea Dragon", "Sea Dragons", "m", 12, 2, 7, 0x04, 218, 0x200, 0x000, 0x0200, 0, "sea_drake"],  # 18
	["a", "Shapeshifter", "Shapeshifters", "f", 16, 2, 10, 0x04, 263, 0x002, 0x080, 0x0004, 525, "shapeshifter"],  # 19
	["a", "Thought Invoker", "Thought Invokers", "f", 11, 2, 11, 0x04, 232, 0x000, 0x020, 0x0080, 0, "thought_invoker"],  # 20
	["an", "Astral Visionary", "Astral Visionaries", "f", 20, 2, 12, 0x04, 245, 0x000, 0x080, 0x0040, 140, "astral_visionary"],  # 21
	["a", "Druid", "Druids", "m", 4, 2, 1, 0x08, 139, 0x000, 0x000, 0x0800, 0, "druid"],  # 22
	["an", "Elvish Magi", "Elvish Maguses", "m", 6, 1, 3, 0x08, 76, 0x200, 0x000, 0x0020, 149, "elvish_magi"],  # 23
	["an", "Enchantress", "Enchantresses", "f", 8, 3, 2, 0x08, 262, 0x000, 0x100, 0x0080, 0, "enchantress"],  # 24
	["a", "Forest Dragon", "Forest Dragons", "m", 12, 2, 7, 0x08, 49, 0x200, 0x000, 0x0200, 0, "forest_dragon"],  # 25
	["a", "Beastmaster", "Beastmasters", "m", 16, 2, 4, 0x08, 170, 0x000, 0x001, 0x0020, 247, "beast_master"],  # 26
	["a", "Summoner", "Summoners", "f", 11, 2, 11, 0x08, 30, 0x002, 0x001, 0x0020, 262, "summoner"],  # 27
	["a", "Great Druid", "Great Druids", "m", 20, 2, 12, 0x08, 95, 0x000, 0x040, 0x0040, 147, "great_druid"],  # 28
	["a", "Sorceress", "Sorceresses", "f", 4, 2, 2, 0x10, 74, 0x000, 0x100, 0x0004, 145, "sorceress"],  # 29
	["a", "Sorcerer", "Sorcerers", "m", 6, 3, 1, 0x10, 192, 0x000, 0x000, 0x1000, 0, "sorcerer"],  # 30
	["a", "Troll Shaman", "Troll Shamen", "m", 8, 1, 6, 0x10, 261, 0x100, 0x000, 0x0001, 0, "troll_shaman"],  # 31
	["a", "Goblin Lord", "Goblin Lords", "m", 12, 2, 4, 0x10, 102, 0x000, 0x001, 0x0020, 163, "goblin_warlord"],  # 32
	["a", "Hydra", "Hydrae", "m", 16, 2, 7, 0x10, 207, 0x200, 0x000, 0x0010, 0, "crag_hydra"],  # 33
	["a", "War Mage", "War Mages", "m", 11, 2, 11, 0x10, 229, 0x004, 0x000, 0x0000, 0, "war_mage"],  # 34
	["a", "Dragon Lord", "Dragon Lords", "f", 20, 2, 12, 0x10, 135, 0x000, 0x080, 0x0040, 492, "kzzy_n_the_dragon_lord"],  # 35
	["a", "Tusk Guardian", "Tusk Guardians", "m", 10, 2, 4, 0x28, 414, 0x000, 0x000, 0x0004, 503, "guardian_of_the_tusk"],  # 36
	["a", "Sedge Beast", "Sedge Beasts", "m", 10, 2, 6, 0x12, 219, 0x040, 0x000, 0x0008, 0, "sedge_beast"],  # 37
	["an", "Ape Lord", "Ape Lords", "m", 14, 2, 4, 0x18, 437, 0x020, 0x000, 0x0020, 15, "ape_lord"],  # 38
	["a", "Centaur Shaman", "Centaur Shamen", "m", 14, 3, 8, 0x0A, 179, 0x028, 0x000, 0x0100, 0, "centaur_shaman"],  # 39
	["a", "Winged Stallion", "Winged Stallions", "m", 14, 2, 9, 0x24, 127, 0x001, 0x000, 0x0400, 0, "winged_stallion"],  # 40
	["a", "Fungus Master", "Fungus Masters", "m", 10, 3, 1, 0x0C, 94, 0x000, 0x001, 0x0020, 275, "fungus_master"],  # 41
	["a", "Centaur Warchief", "Centaur Warchiefs", "m", 14, 2, 8, 0x30, 897, 0x280, 0x000, 0x0004, 240, "centaur_warchief"],  # 42
	["a", "Mind Stealer", "Mind Stealers", "m", 10, 3, 4, 0x06, 289, 0x004, 0x002, 0x1000, 0, "mind_stealer"],  # 43
	["a", "Lord of Fate", "Lords of Fate", "m", 14, 2, 3, 0x22, 10, 0x200, 0x001, 0x0040, 16, "lord_of_fate"],  # 44
	["an", "Elementalist", "Elementalists", "f", 10, 3, 2, 0x14, 399, 0x050, 0x000, 0x1000, 0, "elementalist"],  # 45
	["an", "Aga Galneer", "Aga Galneers", "m", 13, 2, 5, 0x02, 434, 0x004, 0x000, 0x0004, 433, "aga_galneer"],  # 46
	["an", "Alt-A-Kesh", "Alt-A-Keshes", "m", 13, 2, 5, 0x08, 426, 0x004, 0x000, 0x0004, 400, "alt_a_kesh"],  # 47
	["a", "Queltosh", "Queltoshes", "m", 13, 2, 5, 0x10, 442, 0x004, 0x000, 0x0004, 810, "queltosh"],  # 48
	["a", "Saltrem Tor", "Saltrem Tors", "m", 13, 2, 5, 0x04, 456, 0x004, 0x000, 0x0004, 154, "saltrem_tor"],  # 49
	["a", "Mandurang", "Mandurangs", "m", 18, 2, 8, 0x02, 990, 0x200, 0x040, 0x0004, 871, "mandurang"],  # 50
	["a", "Whim", "Whims", "m", 18, 2, 8, 0x04, 991, 0x200, 0x004, 0x0004, 867, "whim"],  # 51
	["a", "Prismat", "Prismats", "m", 18, 2, 8, 0x08, 992, 0x200, 0x001, 0x0004, 865, "prismat"],  # 52
	["a", "Dracur", "Dracurs", "m", 18, 2, 8, 0x10, 993, 0x200, 0x001, 0x0004, 866, "dracur"],  # 53
	["a", "Kiska-Ra", "Kiska-Rae", "m", 18, 2, 8, 0x20, 994, 0x200, 0x080, 0x0004, 863, "kiska_ra"],  # 54
	["an", "Arzakon", "Arzakon", "m", 100, 3, 13, 0x01, 999, 0x000, 0x080, 0x0000, 29, "arzakon"],  # 55
	["an", "Arzakon", "Arzakon", "m", 100, 3, 13, 0x01, 999, 0x000, 0x080, 0x0000, 29, "arzakon"],  # 56
]


## How many rows: 57.
static func size() -> int:
	return ROWS.size()


## Whether [param index] is a row of the table.
static func is_row(index: int) -> bool:
	return index >= 0 and index < ROWS.size()


## The creature's name: "Witch".
static func name_of(index: int) -> String:
	return String(ROWS[index][NAME]) if is_row(index) else ""


## With its article: "a Witch", "an Undead Knight".
static func called(index: int) -> String:
	if not is_row(index):
		return ""
	return "%s %s" % [String(ROWS[index][ARTICLE]), String(ROWS[index][NAME])]


## Whether creature [param index] is of colour [param color] (1 black …
## 5 white).
static func is_of(index: int, color: int) -> bool:
	return is_row(index) and int(ROWS[index][COLORS]) & (1 << color) != 0


## THE CREATURES OF COLOUR [param color] (1 black … 5 white) whose decks
## can be seen — the Guardian's Ghost's and the wise man's list ("Whose
## deck would you like to see?", `@LAIR` 17): every creature with that
## colour among its own, the lair and Arzakon left out, in the table's
## order.
static func of_color(color: int) -> Array[int]:
	var out: Array[int] = []
	for index in ROWS.size():
		var kind := int(ROWS[index][KIND])
		if kind == LAIR or kind == ARZAKON or String(ROWS[index][DECK_FILE]) == "":
			continue
		if is_of(index, color):
			out.append(index)
	return out


## The path of creature [param index]'s deck, "" for none.
static func deck_path(index: int) -> String:
	var file := String(ROWS[index][DECK_FILE]) if is_row(index) else ""
	return DECKS_FOLDER.path_join(file + ".deck") if file != "" else ""


## Creature [param index]'s deck, as the 1997 game showed it to the hero
## (its base cards; the colour-keyed swaps left out), or null.
static func deck(index: int) -> DeckList:
	var path := deck_path(index)
	if path == "" or not FileAccess.file_exists(path):
		return null
	return DeckList.load_file(path, false)
