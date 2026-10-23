class_name WorldClues
extends RefCounted
## THE DUNGEON & CASTLE CLUES (F4, the frame's gate) — 1.3's
## `ShowDungeonCluesScreen` (00509244) and `ShowDungeonClueDetailScreen`
## (0050caa0), in the words of `Advstrings.txt` (`@CAVELIST`,
## `@CAVE_SHOWCLUES`, `@COLORCARDS`). A castle or dungeon is listed once
## the hero has learned anything of it (its slot's `clues`; a dungeon only
## while it holds cards), with what is known:
##  - 2, its creatures: "-Contains large black creatures." for a castle,
##    small for a dungeon, in the slot's colour;
##  - 4, its rules, a line for each (`rules`) and the card in effect;
##  - 1, where it lies: "-East of Kraag Forge.", the way from the town it
##    was placed by (`town`) — 1997's four ways are the screen's diagonals.
## The 1997 list showed nothing when nothing was known; ours says how
## clues are found [QoL]. Clues come from the wise men, ruined towers and
## beaten creatures (`RevealRandomCastleDungeonClue`), not made yet.

const LOCATION := 1
const CREATURES := 2
const RULES := 4
## `@COLORCARDS`, by the slot's colour (0 colourless, 1 black … 5 white).
const COLOR_CARDS: Array[String] = ["Colorless cards", "Black cards", "Blue cards",
	"Green cards", "Red cards", "White cards"]
const COLOR_WORDS: Array[String] = ["", "black", "blue", "green", "red", "white"]
## The cards a castle or dungeon plays under, by their 1.3 card id
## (`find_internal_card_id_by_csv_id`; the ids in [WorldGenerator]'s
## tables), as the 1.3 card table names them.
const EFFECT_CARDS := {8: "Bad Moon", 867: "Power Struggle", 939: "Marsh Viper",
	178: "Orcish Oriflamme", 51: "Crusade", 159: "Meekstone", 287: "Winter Orb",
	63: "Dingus Egg", 114: "Howling Mine", 229: "Smoke", 5: "Ankh of Mishra",
	246: "Throne of Bone", 100: "Gloom", 208: "Rod of Ruin", 661: "Greed",
	52: "Crystal Rod", 494: "Energy Flux", 935: "Flood", 340: "Leviathan",
	288: "Wooden Sphere", 15: "Birds of Paradise", 262: "Verduran Enchantress",
	803: "Sylvan Library", 123: "Iron Star", 439: "Magnetic Mountain",
	192: "Power Surge", 155: "Mana Flare", 128: "Ivory Cup", 134: "Karma",
	28: "Castle", 620: "Elder Land Wurm"}
const NONE_YET := "No clues yet. The wise men in the villages, ruined towers and the creatures you beat tell of the castles and the dungeons, and of the cards they hold."


## The slots (0–4 castles, 5–14 dungeons) the hero knows something of.
static func known(world: ShandalarWorld) -> Array[int]:
	var out: Array[int] = []
	if world == null:
		return out
	for i in world.encounters.size():
		var slot: Dictionary = world.encounters[i]
		if int(slot.get("clues", 0)) == 0:
			continue
		if i >= 5 and (slot.get("cards", []) as Array).is_empty():
			continue
		out.append(i)
	return out


## The slot's name in the list: "Castle Necris (Black Castle)", or the
## dungeon's.
static func title(index: int) -> String:
	if index < 5:
		return "%s (%s)" % [WorldNames.dungeon_name(index), WorldNames.CASTLES[index]]
	return WorldNames.dungeon_name(index)


## What is known of slot [param index], a line each, as the detail screen
## words it.
static func lines(world: ShandalarWorld, index: int) -> Array[String]:
	var out: Array[String] = []
	var slot: Dictionary = world.encounters[index]
	var clues := int(slot.get("clues", 0))
	var color := clampi(int(slot.get("color", 0)), 0, 5)
	var cards: Array[String] = []
	for card in slot.get("cards", []):
		cards.append(String(ShandalarWorld.DUNGEON_CARDS[int(card)][1]))
	if not cards.is_empty():
		out.append("Treasure: " + ", ".join(cards))
	if clues & CREATURES != 0:
		out.append("Creatures:")
		out.append("-Contains %s %s creatures." % ["large" if index < 5 else "small", COLOR_WORDS[color]])
	if clues & RULES != 0:
		out.append("Dungeon Rules:")
		var rules := int(slot.get("rules", 0))
		if rules & 0x10 != 0:
			out.append("-No %s allowed." % COLOR_CARDS[color])
		if rules & 0x20 != 0:
			out.append("-One deck for all duels.")
		if rules & 0x40 != 0:
			out.append("-No artifacts allowed.")
		if rules & 0x80 != 0:
			out.append("-No instants or interrupts allowed.")
		if rules & 0x01 != 0:
			out.append("-Life losses carried over.")
		if rules & 0x02 != 0:
			out.append("-Remaining life added to next duel.")
		var effect := int(slot.get("card_in_effect", -1))
		if effect != -1:
			out.append("-%s permanently in effect." % String(EFFECT_CARDS.get(effect, "A card")))
		elif rules == 0:
			out.append("-No special rules.")
	if clues & LOCATION != 0:
		out.append("Location:")
		var town := int(slot.get("town", -1))
		if town >= 0 and town < world.sites.size():
			var dx := int(slot["x"]) - int(world.sites[town]["x"])
			var dy := int(slot["y"]) - int(world.sites[town]["y"])
			var way := (1 if dx > 0 else 2) if dy > 0 else (0 if dx > 0 else 3)
			out.append("-%s of %s." % [WorldNames.DIRECTIONS[way], WorldNames.site_name(world, town)])
	return out
