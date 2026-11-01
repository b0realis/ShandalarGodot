class_name RefugeStories
extends RefCounted
## [QoL] Original Last Refuge fiction. Sarpadia belongs to Dominaria;
## these communities preserve its traditions on a different plane.

const ORIGIN := "The captain tells of Sarpadia, a distant continent on Dominaria. Refugees carried its traditions to Shandalar before the Great Barrier. Their descendants call this island the Last Refuge; it is not the lost Sarpadia."
const VOYAGE := "This ship crosses only Shandalar's sea. Help five communities resist the Ebon Crown, then challenge its lord. Passage home is always free."
const DANGER := "This is a dangerous land for experienced adventurers. Its roaming creatures are strong; the Crown's commanders have 26–30 life and its lord has 36. Build your deck and life on the mainland first if needed. Their strength does not follow yours."
const GATE := "The final challenge needs all five pledges and at least half of your main deck's nonland cards from Fallen Empires. Lands and sideboard do not count. Community rewards can help build one or two colors."
const EPILOGUES := [
	"The grain wagons roll again. Leitbur's Rest pledges its aid, and its keepers agree that neither the Crown nor a zealot may decide who deserves bread.",
	"The blockade is broken. Vodalian fishers and homarids mark shared channels through the harbor. Their pledge begins with safe passage for both peoples.",
	"The overseer's bonds are broken. Free thrulls and those who rejected the Ebon Hand stand together: no life made by magic belongs to its maker.",
	"The tribute barriers come down. Dwarven smiths and goblin traders reopen their common road. Their pledge protects travelers, whatever their ancestry.",
	"The sporekeeper retreats. Havenwood's elves and thallids can tend their border again, giving both woodland and fungus room to live. They offer you their pledge.",
]
const TALES := [
	["Memories of Sarpadia", "Our ancestors named Icatia, Vodalia, the Ebon Hand, the dwarven holds and Havenwood. Their histories tell of peoples divided against their neighbors and themselves. We keep those stories here so that a refuge need not become another fallen empire."],
	["The First Crossing", "The oldest account tells of a passage to Shandalar, before its Great Barrier. It names neither a surviving gateway nor a way to reopen it. The Vaults hold the travelers' keepsakes; the ship at our harbor sails only between this island and the mainland."],
	["Bread and Belief", "The Icatian traditions carried both protectors and zealots. Leitbur's Rest remembers the danger of letting fear decide who may share a harvest. Its people ask for an open road, not a new ruler."],
	["A Shared Coast", "Vodalian and homarid stories remember old wars. Here their descendants must live with the same tides. The harbor pact is new, fragile, and theirs to make; it does not change what happened in Sarpadia."],
	["The Freehold", "The Order of the Ebon Hand made thrulls to serve it. The free thrulls of this island reject that inheritance, alongside people who turned away from the Order. The Crown would restore the old bondage in the name of tradition."],
	["The Mountain Road", "The dwarves' tales remember wars with orcs and goblins. The traders of this island have chosen another bargain: shared work and passage through the mountains. The Crown profits when they distrust one another."],
	["Room for Two Forests", "Havenwood's stories warn of elves losing control of the thallids they cultivated. Here the border is tended with care. The Crown's sporekeeper spreads unchecked growth to break that peace, then offers the lord's protection at a price."],
]
const VAULT := "The first travelers hid their keepsakes in these vaults. No passage to Dominaria remains here. Explore for treasure and clues; this dungeon grants no pledge and is not required to challenge the Ebon Crown."

static func news(player: AdventurePlayer) -> String:
	if bool(player.refuge.get("liberated", false)):
		return "The Ebon Crown has fallen. The communities keep their own councils. Their spells now reach mainland traders and newly stocked shops; Refuge Harbor still offers free passage."
	var target := RefugeCampaign.next_target(player)
	return "The Ebon Crown rules from the island's central castle. You hold %d of 5 pledges. Seek %s. The five petitions have no time limit; ordinary town errands keep their own deadlines." % [player.refuge.get("quests", []).size(), target.get("name", "the communities")]

static func applause(player: AdventurePlayer) -> String:
	return "The wise man says:\n“The people thank you for freeing the Last Refuge.\n\n" if bool(player.refuge.get("liberated", false)) else "The wise man says:\n“The people welcome your help against the Ebon Crown.\n\n"

static func roaming_words(player: AdventurePlayer, wins: int) -> Array[String]:
	if wins >= CreatureMeeting.TRIBUTE_WINS:
		return ["Your victories are known on this island.", "The creature offers tribute. Will you..."] as Array[String]
	return ["The Ebon Crown is broken, but danger remains on the island." if bool(player.refuge.get("liberated", false)) else "A roaming challenger bars your way on the Last Refuge.", "Will you..."] as Array[String]
