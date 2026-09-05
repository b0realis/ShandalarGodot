class_name StarterDecks
extends RefCounted
## The v1 hotseat starter decks — 40 cards each, built EXCLUSIVELY from the
## implemented pool (every name here must be registered, or MtgGame.setup
## errors loudly; the duel smoke test guards this).
##
## These are placeholders shaped like the original's starting decks (see
## the lore doc's difficulty table); M3 replaces this file with data-driven
## deck lists (the original's .dck format and s30's rogue TOMLs are the
## references).

## "Knights of Alsadim" — white weenie with protection tech.
const WHITE_KNIGHTS: Array[String] = [
	"Savannah Lions", "Savannah Lions", "Savannah Lions", "Savannah Lions",
	"White Knight", "White Knight", "White Knight", "White Knight",
	"Serra Angel", "Serra Angel",
	"Holy Strength", "Holy Strength", "Holy Strength",
	"Swords to Plowshares", "Swords to Plowshares",
	"Disenchant", "Disenchant",
	"Crusade",
	"Wrath of God",
	"Castle", "Castle",
	"Circle of Protection: Red",
	"Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
	"Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
	"Plains", "Plains", "Plains", "Plains", "Plains", "Plains",
]

## "Slan's Raiders" — black-red aggro with the classic Ritual-Specter curve.
const BLACK_RED_RAIDERS: Array[String] = [
	"Erg Raiders", "Erg Raiders", "Erg Raiders", "Erg Raiders",
	"Hypnotic Specter", "Hypnotic Specter", "Hypnotic Specter",
	"Drudge Skeletons", "Drudge Skeletons",
	"Scathe Zombies", "Scathe Zombies",
	"Bog Wraith", "Bog Wraith",
	"Lightning Bolt", "Lightning Bolt", "Lightning Bolt",
	"Terror", "Terror",
	"Dark Ritual", "Dark Ritual",
	"Bad Moon",
	"Fireball",
	"Shivan Dragon",
	"Swamp", "Swamp", "Swamp", "Swamp", "Swamp",
	"Swamp", "Swamp", "Swamp", "Swamp",
	"Mountain", "Mountain", "Mountain", "Mountain",
	"Mountain", "Mountain", "Mountain", "Mountain",
]
