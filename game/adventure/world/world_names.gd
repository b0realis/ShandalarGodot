class_name WorldNames
extends RefCounted
## THE NAMES OF SHANDALAR'S PLACES, as the 1997 game gave them: the
## adventure's string table (`Advstrings.txt`, registered in
## `Provenance.md`) and the 1.3 functions that put them together.
##  - A town or city is named by its site slot (`BuildTownDisplayName`,
##    00550220): `@CITYNAMES_FIRSTHALF` [(slot / 8) mod 16] and
##    `@CITYNAMES_SECONDHALF` [slot mod 16], "%1 %2"; a village is
##    "%1 Village" (`@CITYNAMES_FORMAT`).
##  - A wizard's castle is its colour's (`@CITYNAME_MANACASTLE`).
##  - The fifteen castle and dungeon slots are named by their index
##    (`GetDungeonName`, 005081e0, `@DUNGEON_NAMES`).

const FIRST_HALVES: Array[String] = ["Amanaxis", "Andor's", "Bloodsand", "Celestine",
	"Coldsnap", "Eloren", "Hornwall", "Kraag", "Mardrake", "Nevermoor", "Pyrenian",
	"Sahrmal's", "Shalecliff", "Unicorn's", "Windlass", "Zephyr"]
const SECOND_HALVES: Array[String] = ["Tower", "Keep", "Glade", "Forge", "Tavern",
	"Steading", "Temple", "Mill", "Spire", "Hall", "Bazaar", "Oasis", "Shrine",
	"Haven", "Hold", "Sanctum"]
## The castles and the dungeons, slot by slot: 0–4 the wizards' castles
## (black, blue, green, red, white), 5–14 the dungeons.
const DUNGEONS: Array[String] = ["Castle Necris", "Mysthold", "Wildwood Steading",
	"Dragon Mount", "Citadel of the Sun", "The Paths of Chronus", "Ruins of Su-Chan",
	"Mound of the Warrior Kings", "Azar's Crypt", "Soulchant Monastery",
	"Cave of the Ice Worm", "Dungeons of Graaz Keep", "Tower of Whim",
	"Arjonot's Tomb", "Altar of the Cyclops"]
## The castles' and the wizards' names by colour, black to white
## (`@CITYNAME_MANACASTLE`, `@WIZARDNAMES`).
const CASTLES: Array[String] = ["Black Castle", "Blue Castle", "Green Castle",
	"Red Castle", "White Castle"]
const WIZARDS: Array[String] = ["Black Wizard", "Blue Wizardess", "Green Wizard",
	"Red Wizardess", "White Wizard"]
## `@DIRECTIONS`.
const DIRECTIONS: Array[String] = ["North", "East", "South", "West"]


## The name of the site in [param slot] of [param world]: its town's or
## village's, or its castle's.
static func site_name(world: ShandalarWorld, slot: int) -> String:
	if world == null or slot < 0 or slot >= world.sites.size():
		return ""
	var kind := int(world.sites[slot]["type"])
	if kind >= ShandalarWorld.CASTLE:
		var castle := castle_of_site(world, slot)
		return CASTLES[castle] if castle >= 0 else "Castle"
	var first := FIRST_HALVES[clampi((slot / 8) % 16, 0, 15)]
	if kind == ShandalarWorld.VILLAGE:
		return "%s Village" % first
	return "%s %s" % [first, SECOND_HALVES[clampi(slot % 16, 0, 15)]]


## Which wizard's castle (0 black … 4 white) stands on site [param slot],
## or -1: the castle slots keep their tile.
static func castle_of_site(world: ShandalarWorld, slot: int) -> int:
	var site: Dictionary = world.sites[slot]
	for i in mini(5, world.encounters.size()):
		var castle: Dictionary = world.encounters[i]
		if int(castle.get("x", -1)) == int(site["x"]) and int(castle.get("y", -1)) == int(site["y"]):
			return i
	return -1


## The name of castle or dungeon slot [param index].
static func dungeon_name(index: int) -> String:
	return DUNGEONS[index] if index >= 0 and index < DUNGEONS.size() else ""
