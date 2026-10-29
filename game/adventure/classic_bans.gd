class_name ClassicBans
extends RefCounted
## THE ADVENTURE'S BAN LISTS — the banned and restricted cards the
## adventure's "Classic MTG rules" card rule reads ([member
## AdventurePlayer.card_rule], [method DeckModel.classic_allowance]), one of
## three chosen at the Embark (the owner, 2026-10-28: "an Embark setting
## (Embark only) with three lists — '1998 (the original game's)', '1998 +
## modern', 'modern'; default: the list as today (the nearest: 1998 +
## modern)") and kept in the adventure ([member AdventurePlayer.ban_list]).
## [ours]
##
## EMBARK ONLY: Magic Battle's five formats keep [DeckFormat]'s own lists,
## untouched ([constant DeckFormat.BANNED], [constant DeckFormat.RESTRICTED]
## — the union of the modern table and the 1998 list, the "list as today"
## the owner named); nothing here is read outside the adventure's Classic
## rule. Each list is kept whole by NAME, as DeckFormat's are, so a card
## that joins the pool later arrives already listed; a name outside the pool
## never matches.
##
##  - [constant OLD] "1998 (the original game's)": the DCI's Classic (Type 1)
##    lists as printed in _The Duelist_ #22 (1 January 1998; DeckFormat's
##    class doc and docs/ROADMAP.md, "THE ERA-CORRECT RESTRICTED LIST",
##    for the source and why it ranks where it does), with Strip Mine, whose
##    restriction the DCI announced on 3 December 1997 EFFECTIVE 1 January
##    1998 — the issue went to press with the old list. Mind Twist, Channel
##    and Divine Intervention BANNED there (DeckFormat restricts the first
##    two and leaves the third alone); Mana Crypt, Mana Vault and Time Vault
##    NOT restricted (ROADMAP's three findings for the owner).
##  - [constant MODERN] "Modern": today's Vintage lists (read off
##    magic.wizards.com/en/banned-restricted-list on 2026-10-28): the 52
##    restricted cards; banned the nine ante cards, Chaos Orb, Falling Star,
##    Shahrazad and the seven cards banned in every format on 10 June 2020
##    (Crusade, Cleanse, Imprison, Invoke Prejudice, Jihad, Pradesh Gypsies,
##    Stone-Throwing Devils — all seven in our pool). The Conspiracy,
##    sticker and Attraction cards Vintage also bans are no cards a deck
##    here can hold.
##  - [constant BOTH] "1998 + modern" (the default): never looser than
##    either — a card banned by either is banned, one restricted by either
##    and banned by neither is restricted. The nearest to the list as it
##    stood before the choice: DeckFormat's lists with the 1998 bans (and
##    the 2020 ones) added.

## The three lists, by the key an adventure keeps ([member
## AdventurePlayer.ban_list]); [constant BOTH] by default and for an
## adventure saved before the choice.
const OLD := "1998"
const BOTH := "1998 + modern"
const MODERN := "modern"
const LISTS: Array[String] = [OLD, BOTH, MODERN]
const DEFAULT := BOTH

## _The Duelist_ #22's Classic (Type 1) restricted list — the twenty-five
## cards (all in our pool; tests/unit/test_deck_format.gd's
## `ERA_RESTRICTED_IN_POOL`) — and Strip Mine, restricted from the day the
## list was printed for (see the class doc).
const RESTRICTED_1998: Array[String] = [
	"Ancestral Recall", "Balance", "Berserk", "Black Lotus", "Black Vise",
	"Braingeyser", "Demonic Tutor", "Fastbond", "Fork", "Ivory Tower",
	"Library of Alexandria", "Maze of Ith", "Mirror Universe",
	"Mox Emerald", "Mox Jet", "Mox Pearl", "Mox Ruby", "Mox Sapphire",
	"Recall", "Regrowth", "Sol Ring", "Time Walk", "Timetwister",
	"Underworld Dreams", "Wheel of Fortune",
	"Strip Mine",
]
## _The Duelist_ #22's Classic (Type 1) banned list: the ante cards, the
## dexterity cards and the sub-game, and Channel, Divine Intervention and
## Mind Twist.
const BANNED_1998: Array[String] = [
	"Amulet of Quoz", "Bronze Tablet", "Contract from Below", "Darkpact",
	"Demonic Attorney", "Jeweled Bird", "Rebirth", "Tempest Efreet", "Timmerian Fiends",
	"Chaos Orb", "Falling Star", "Shahrazad",
	"Channel", "Divine Intervention", "Mind Twist",
]

## Today's Vintage restricted list, whole (2026-10-28).
const RESTRICTED_MODERN: Array[String] = [
	"Ancestral Recall", "Balance", "Black Lotus", "Brainstorm",
	"Chalice of the Void", "Channel", "Demonic Consultation", "Demonic Tutor",
	"Dig Through Time", "Flash", "Gitaxian Probe", "Golgari Grave-Troll", "Gush",
	"Imperial Seal", "Karn, the Great Creator", "Library of Alexandria",
	"Lion's Eye Diamond", "Lodestone Golem", "Lotus Petal", "Mana Crypt",
	"Mana Vault", "Memory Jar", "Mental Misstep", "Merchant Scroll",
	"Mind's Desire", "Monastery Mentor", "Mox Emerald", "Mox Jet", "Mox Pearl",
	"Mox Ruby", "Mox Sapphire", "Mystic Forge", "Mystical Tutor",
	"Narset, Parter of Veils", "Necropotence", "Sol Ring", "Strip Mine",
	"The Fantasticar", "Thorn of Amethyst", "Time Vault", "Time Walk",
	"Timetwister", "Tinker", "Tolarian Academy", "Treasure Cruise",
	"Trinisphere", "Urza's Saga", "Vampiric Tutor", "Vexing Bauble",
	"Wheel of Fortune", "Windfall", "Yawgmoth's Will",
]
## Today's Vintage banned list as it applies to cards a deck here can hold.
const BANNED_MODERN: Array[String] = [
	"Amulet of Quoz", "Bronze Tablet", "Contract from Below", "Darkpact",
	"Demonic Attorney", "Jeweled Bird", "Rebirth", "Tempest Efreet", "Timmerian Fiends",
	"Chaos Orb", "Falling Star", "Shahrazad",
	"Cleanse", "Crusade", "Imprison", "Invoke Prejudice", "Jihad",
	"Pradesh Gypsies", "Stone-Throwing Devils",
]

## Each list as two name sets, `{banned, restricted}` (names only — no card
## is kept here), built on the first ask.
static var _sets := {}


## The list [param value] names ([constant LISTS]), else [constant DEFAULT]
## (an adventure saved before the choice, or a word that is no list).
static func key_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in LISTS else DEFAULT


## Whether list [param key] bans [param card_name].
static func is_banned(card_name: String, key: String) -> bool:
	return (_of(key)["banned"] as Dictionary).has(card_name)


## Whether list [param key] restricts [param card_name] (and does not ban it).
static func is_restricted(card_name: String, key: String) -> bool:
	return (_of(key)["restricted"] as Dictionary).has(card_name)


## Every name list [param key] bans, sorted.
static func banned(key: String) -> Array[String]:
	return _names(_of(key)["banned"])


## Every name list [param key] restricts, sorted.
static func restricted(key: String) -> Array[String]:
	return _names(_of(key)["restricted"])


static func _of(key: String) -> Dictionary:
	var list := key_of(key)
	if _sets.has(list):
		return _sets[list]
	var bans := {}
	var limits := {}
	if list != MODERN:
		for card_name in BANNED_1998:
			bans[card_name] = true
		for card_name in RESTRICTED_1998:
			limits[card_name] = true
	if list != OLD:
		for card_name in BANNED_MODERN:
			bans[card_name] = true
		for card_name in RESTRICTED_MODERN:
			limits[card_name] = true
	for card_name in bans:
		limits.erase(card_name)
	_sets[list] = {"banned": bans, "restricted": limits}
	return _sets[list]


static func _names(names: Dictionary) -> Array[String]:
	var out: Array[String] = []
	for card_name in names:
		out.append(String(card_name))
	out.sort()
	return out
