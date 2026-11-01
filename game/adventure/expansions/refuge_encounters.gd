class_name RefugeEncounters
extends RefCounted
## Fixed regional opposition: stronger decks and lives, never hidden information
## or a response to the hero's collection. Rewards are a separate card selection.
const LIVES := [26, 28, 28, 26, 30, 36]
const FACES := [11, 18, 4, 32, 25, 6]
const LISTS := [
	{"Plains": 16, "Icatian Javelineers": 4, "Order of Leitbur": 4, "Icatian Infantry": 4, "Icatian Priest": 3, "Farrel's Zealot": 3, "Swords to Plowshares": 2, "Crusade": 2, "Righteousness": 2},
	{"Island": 18, "Vodalian Soldiers": 4, "Vodalian Mage": 2, "Homarid": 2, "Homarid Warrior": 2, "High Tide": 3, "Deep Spawn": 2, "Counterspell": 3, "Merseine": 2, "Unsummon": 2},
	{"Swamp": 16, "Order of the Ebon Hand": 4, "Hymn to Tourach": 4, "Basal Thrull": 4, "Armor Thrull": 3, "Soul Exchange": 2, "Thrull Retainer": 2, "Terror": 2, "Drain Life": 2, "Thrull Champion": 1},
	{"Mountain": 16, "Goblin Chirurgeon": 4, "Goblin Balloon Brigade": 4, "Goblins of the Flarg": 4, "Goblin King": 2, "Goblin Grenade": 4, "Goblin War Drums": 2, "Lightning Bolt": 2, "Goblin Warrens": 1, "Dwarven Soldier": 1},
	{"Forest": 16, "Thallid": 4, "Thorn Thallid": 3, "Elvish Farmer": 3, "Spore Flower": 2, "Elvish Hunter": 2, "Feral Thallid": 2, "Thallid Devourer": 2, "Giant Growth": 3, "Regrowth": 2, "Hurricane": 1},
	{"Swamp": 16, "Basal Thrull": 4, "Armor Thrull": 3, "Mindstab Thrull": 3, "Thrull Champion": 2, "Soul Exchange": 3, "Order of the Ebon Hand": 3, "Hymn to Tourach": 2, "Terror": 2, "Dark Ritual": 2},
]

static func deck(quest: int) -> Array:
	var out: Array = []
	for card in LISTS[quest if quest >= 0 else 5]:
		for copy in LISTS[quest if quest >= 0 else 5][card]: out.append(card)
	return out

static func roaming_tier(tier: int) -> int:
	# Tier 12 exists in all five colors. Leave lairs and stronger creatures alone.
	return maxi(12, tier) if tier > 0 else 0

const ROAMING_NAMES := ["Icatian Patrol", "Vodalian Expedition", "Ebon Remnant", "Goblin Tribute-Raiders", "Havenwood Spores"]

## Stable world/slot choice, never hero strength, cards or concealed information.
## Retain the creature identity and its announced 1997 gifts; only roaming
## encounters receive these decks. Named hunts and special encounters stay exact.
static func roaming(player: AdventurePlayer, meeting: Dictionary) -> void:
	if not RefugeCampaign.available() or bool(meeting.get("quest", false)) or meeting.has("town"): return
	if CreatureBook.preduel_flags(int(meeting["row"])) & (CreatureBook.PRE_SUMMON | CreatureBook.PRE_SWAP) != 0: return
	var slot := int(meeting.get("slot", -1))
	if slot < 1 or slot == CreatureMeeting.SIEGE_SLOT: return
	if posmod(player.world.seed + slot * 17 + int(meeting["row"]), 3) == 0: return
	var index: int = [2, 1, 4, 3, 0][clampi(int(meeting["color"]), 1, 5) - 1]
	meeting["regional_deck"] = deck(index)
	meeting["regional_name"] = ROAMING_NAMES[index]
	meeting["regional_life"] = LIVES[index]
	var candidates: Array = meeting["regional_deck"].filter(func(card: String) -> bool: return card not in CreatureDeck.BASICS)
	if not candidates.is_empty():
		var dice := MsvcRandom.new(player.dice)
		meeting["creature_ante"] = [candidates[dice.below(candidates.size())]] as Array[String]
		player.dice = dice.state
