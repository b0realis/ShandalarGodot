class_name CreatureBook
extends RefCounted
## THE CREATURES OF SHANDALAR — the 57 rows of the 1997 game's creature
## table (`g_shandalar_monster_definitions`, 1.3 `creature_names_init.inc`,
## its fields in `global_other.h`; the names, articles and plurals are
## `Advstrings.txt`'s `@CREATURENAMES`, `@CREATURENAME_ARTICLES` and
## `@CREATURENAMES_PLURAL`), written here as our own data. Row 0 is the
## lair, rows 55 and 56 Arzakon (56 the copy the Spectral Arena overwrites).
## Both local `Shandalar.exe` builds hold the same 57 rows (file offset
## 0x18fe08); every field kept here was checked against them (part B,
## 2026-10-23).
##
## Each row: article, name, plural, gender ("m" or "f"), tier (the
## creature's strength class, 4 … 20, Arzakon 100), base strength (1–3, its
## bribe and reward weight), kind (the encounter type: 0 lair, 1 male
## wizard, 2 female wizard, 3 knight, 4 lord, 5 djinn, 6 troll, 7 wyrm,
## 8 dragon, 9 flyer, 10 archmage, 11 henchman, 12 castle wizard,
## 13 Arzakon), colours (1997 colour bits: 0x02 black … 0x20 white, 0x01
## colourless), the 1997 deck number (`Decks/0NNN.dck`; it is also the 1997
## card id of the creature's SIGNATURE card, the one it never antes), its
## movement flags (`flags_0a`), its pre-duel flags, its reward flags, its
## reward card (the 1997 card id; [constant CARDS_1997] names it) and our
## deck file in `decks/1997/originals/` (each file names the 1997 deck it
## is; [CreatureDeck] reads it).
##
## WHAT READS THE TABLE, and where each 1997 formula lives here:
##  - [method pick], `PickRandomCreatureTypeForWizardTier` (visitLocation.c
##    2303): a creature of a tier and colour, on the adventure's dice.
##  - [method strength] and [method bribe] (world_lair_monster_encounter.c
##    1557–1563, 1712; retail magic_all.c 57112): base + tier / 2, ten gold a
##    point.
##  - [method duel_life] (duel.c 2227–2287; retail Kimpic.c 19702–19745).
##  - [method stride], [method shown_row] and the MOVE_ flags: the map's
##    walk (world_lair_monster_slots.c 641–955).
##  - the PRE_ flags: what a special meeting does before the duel
##    (world_lair_monster_encounter.c 2145–2224); the REWARD_ flags: what a
##    special meeting gives after a win (2416–2632).
##  - [method cry_key], [method sprite_keys], [method face_id],
##    [method duel_name]: the creature's voice, map figure, face and duel name.
##  - [constant MINIONS]: the wizards' three minion cards.
##
## FIXED [ours: 1997 slips, each marked where it is fixed]:
##  - the flyer's cry asked for `flyer.wav`, which no install has: it plays
##    `Flying.wav`, the file that was obviously meant ([method cry_key]);
##  - the castle wizard of a colour was looked up as row colour · 7, right
##    only for black (visitLocation.c 2784): [method castle_row];
##  - a castle wizard's life counted the towns whose ruler equalled a loop
##    index, not its own towns (duel.c 2260–2268, retail the same): the towns
##    it rules ([method duel_life], as [method WiseMan.castle_life]).
##
## DESIGNED, NEVER USED — the table carries features the 1997 program
## computed or laid out and never let take effect. They stay dead here, as
## data, each documented with how it would change the game and how to switch
## it on (and in `docs/adventure-unused-1997-features.md`):
##  - SLOW ON SOME LANDS, flags 0x008–0x080 ([constant MOVE_TERRAIN]), tested
##    against the land's colours (`flags & (tile_mask << 3)`, slots.c
##    770–780) — mostly NOT the creature's own: Merfolk Shaman black land,
##    Sedge Beast green, Elementalist black and green, Centaur Shaman blue
##    (its 0x08 matches no terrain), Centaur Warchief red (its own), Ape Lord
##    blue (no land it may stand on) — and THE WIDE RANGE, flag 0x200
##    ([constant MOVE_WIDE_RANGE]: Undead Knight, Crusader, Sea Dragon, Elvish
##    Magi, Forest Dragon, Hydra, Centaur Warchief, Lord of Fate, the five
##    dragons). 1997 folds them into a per-creature `speed` and `range`
##    (world_lair_monster_slots.c 636–714, 770–780; retail glue_adventure.c
##    1251–1352) that nothing reads: every creature steers at the hero every
##    tick at its fixed [method stride]. Switched on, these creatures would
##    walk slower over the lands named (a Merfolk Shaman in black swamps, a
##    Sedge Beast in green forest) and notice the hero from twice as far — the world would
##    have quiet stretches and dangerous ones, and outrunning a creature would
##    depend on the land. To switch on: `WorldCreatures`' step scales the
##    stride by the terrain under the creature for these bits and steers at
##    the hero only inside the kind's range (doubled by 0x200).
##  - CREATURE NAMES ON THE MAP. While a creature is drawn, the drawing
##    copies its name — for the three DISGUISE creatures the name of
##    [method shown_row], which steps a row down every 32 ticks — into a
##    label nothing draws (adventureWorldUi.c 2280–2284). Switched on, the player would know what
##    approaches before meeting it, and the Necromancer, the Shapeshifter and
##    the Summoner would come disguised as weaker creatures — a Shapeshifter
##    announced as a Conjurer. To switch on: the world screen's pointer tip
##    names a creature under the pointer by [method name_of] of
##    [method shown_row]. (The disguise itself is live: it moves the lurk
##    test of [constant MOVE_HIDDEN].)
##  - PRE-DUEL FLAG 0x020 ([constant PRE_UNREAD], Thought Invoker) and THE
##    TABLE'S BYTE 0x0E ([constant UNREAD_BYTE_0E], nineteen rows): no reader
##    in 1.3 or retail. Reserved hooks — another pre-duel event, a
##    per-creature setting — kept as data; they need a meaning before they
##    can be switched on.
##  - THE SPOILS OF HENCHMEN AND CASTLE WIZARDS. The reward flags of kinds 11
##    and 12 (the Necromancer's and Thought Invoker's random artifact, the
##    Summoner's card in play next duel, every castle wizard's "any card")
##    are never read: kinds 11 and up skip the whole reward block
##    (world_lair_monster_encounter.c 2271). Switched on ([method
##    gives_spoils] true for them), beating a henchman would pay as a roaming
##    creature does and a castle wizard would let the hero pick any card.
##  - THE DUPLICATE AS A RANDOM REWARD. A special meeting with no reward of
##    its own draws `(1 << rand(12)) & 0x1A19` ([constant REWARD_RANDOM]);
##    the mask names 0x1000 (copy one of your own cards), which `rand(12)`
##    (0 … 11) never reaches. Switched on (`rand(13)`), one random reward in
##    thirteen would be a copy of a card of the hero's choice. To switch on:
##    the spoils' random draw.
##  - HAND SIZES BY STRENGTH. `play_duel` computes the CREATURE's opening
##    hand (the hero's is always 7) as `clamp(base strength + difficulty +
##    4, 0, 99)` (7 at Wizard), plus the meeting's hand modifier
##    `−clamp(3 − wins / 3, 0, 3)`, at least 3 — and then sets 7 (duel.c
##    2289–2300, the hands drawn 2373–2392; retail Kimpic.c 19750–19751).
##    Switched on, a creature would open with 5 to 9 cards by its strength
##    and the difficulty, 3 fewer while the hero has few wins (none fewer
##    from 9 wins, or on Wizard) — a new hero would face weak opening hands
##    and the strong creatures of the harder levels big ones, a curve that
##    hardens as the hero grows. To switch on: the meeting's duel set-up
##    passes that size for the creature's seat to the duel instead of 7
##    ([method base_strength] is its input).
##  - THE DRAGON LORD'S MAP FIGURE. The figure loader gives row 35 the War
##    Mage's sheets (world_lair_monster_slots.c, case 0x23) though a castle
##    wizard never walks the map; kept in [method sprite_keys], never drawn.
##  - ROW 56. The Spectral Arena copies a random creature 1–54 into row 56 at
##    tier 16 (world_lair_monster_encounter.c 1171–1185), but the duel's pick
##    then rejects rows of 55 and up, so the copy is never fought. [Ours: the
##    lead's ruling of 2026-10-23 — the Arena fights that creature as a
##    Spectre, its own deck and face, at tier-16 life — 16 + 2d,
##    [method LairDuels.life]; this table is never changed.]

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
## The encounter kinds the rows name (`encounter_type`).
const LAIR := 0
const MALE_WIZARD := 1
const FEMALE_WIZARD := 2
const KNIGHT := 3
const LORD := 4
const DJINN := 5
const TROLL := 6
const WYRM := 7
const DRAGON := 8
const FLYER := 9
const ARCHMAGE := 10
## A wizard's henchman: no bribe, no ante of its own, no spoils.
const HENCHMAN := 11
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


# -------------------------------------------------- the flags, by name --

## MOVEMENT FLAGS (`flags_0a`, [constant MOVE_FLAGS]), read on the map
## (`UpdateWorldLairAndMonsterSlots`, world_lair_monster_slots.c 641–955;
## retail magic_all.c 100250–100460 the same).
## FAST: a stride of 2 units a tick, as a flyer (Nether Fiend, Arch Angel,
## Winged Stallion) — [method stride].
const MOVE_FAST := 0x001
## DISGUISE: the row shown cycles through the three below its own
## (Necromancer, Shapeshifter, Summoner) — [method shown_row].
const MOVE_DISGUISE := 0x002
## BLINK: every 64 ticks a jump of 32 units in a random straight way (War
## Mage, Mind Stealer, the four djinn).
const MOVE_BLINK := 0x004
## DESIGNED, NEVER USED: slow on these terrains (see the class doc).
const MOVE_TERRAIN := 0x0F8
## HIDDEN, the lurkers: not drawn while further than 256 page pixels from the
## screen's centre (adventureWorldUi.c 2236; Conjurer, Troll Shaman).
const MOVE_HIDDEN := 0x100
## DESIGNED, NEVER USED: twice the range (see the class doc).
const MOVE_WIDE_RANGE := 0x200

## PRE-DUEL FLAGS ([constant PREDUEL_FLAGS]), read only on a "special"
## meeting (`(monster_timer >> 2) % 3 == 0`, world_lair_monster_encounter.c
## 2145–2224).
## CARD: the creature starts with its reward card in play — when the hand
## modifier is not below 0. Bits 0x01, 0x40 and 0x80 do the same everywhere
## 1997 reads them.
const PRE_CARD := 0x0C1
## MIND CONTROL: the creature plays a shuffled copy of the hero's library
## and hand (Priestess, Mind Stealer).
const PRE_MIND := 0x002
## TRY THIS DECK: one time in three the hero plays a random creature's deck
## (Conjurer, High Priest, Whim).
const PRE_SWAP := 0x004
## FIRST STRIKE: the creature moves first (Undead Knight, Crusader).
const PRE_FIRST := 0x008
## DESIGNED, NEVER USED: Thought Invoker's bit no code reads.
const PRE_UNREAD := 0x020
## SUMMONS: one time in three the creature becomes one 1–3 rows on (Witch,
## Seer, Enchantress, Sorceress; 0x010 is tested too and set on no row).
const PRE_SUMMON := 0x110

## REWARD FLAGS ([constant REWARD_FLAGS]), given after a win on a special
## meeting, kinds below 11 only (world_lair_monster_encounter.c 2416–2632;
## `@ENCOUNTER_POSTDUEL` 16–26).
## The life the hero ended the duel with, less what they began with, is
## carried to the next duel (may be negative).
const REWARD_LIFE_CARRIED := 0x0001
## Teleported to a random land tile (0x002 and 0x400 alike).
const REWARD_TELEPORT := 0x0402
## The reward card joins the hero's cards.
const REWARD_WON_CARD := 0x0004
## 100 gold.
const REWARD_GOLD := 0x0008
## The first move in the next duel.
const REWARD_FIRST_MOVE := 0x0010
## The reward card in play at the start of the next duel.
const REWARD_CARD_NEXT := 0x0020
## Any card, picked from every card.
const REWARD_ANY_CARD := 0x0040
## A random non-creature artifact in play at the start of the next duel
## (0x080 and 0x100 alike).
const REWARD_ARTIFACT_NEXT := 0x0180
## 20–49 food.
const REWARD_FOOD := 0x0200
## 1–4 more lives in the next duel.
const REWARD_LIVES := 0x0800
## A copy of one of the hero's own cards.
const REWARD_DUPLICATE := 0x1000
## A special meeting with neither an amulet won nor a reward of its own
## gives `(1 << rand(12)) & REWARD_RANDOM`: 0x1, 0x8, 0x10, 0x200 or 0x800,
## each one time in twelve. DESIGNED, NEVER USED: its 0x1000 (see the class
## doc).
const REWARD_RANDOM := 0x1A19

## Each field's bits by name, for [method flag_names] (a reader, a test, a
## log line): `[mask, name]`, the dead ones so marked.
const FLAG_NAMES := {
	MOVE_FLAGS: [[MOVE_FAST, "fast"], [MOVE_DISGUISE, "disguise"], [MOVE_BLINK, "blink"],
		[0x008, "terrain 0x008 (never used)"], [0x010, "terrain 0x010 (never used)"],
		[0x020, "terrain 0x020 (never used)"], [0x040, "terrain 0x040 (never used)"],
		[0x080, "terrain 0x080 (never used)"], [MOVE_HIDDEN, "hidden"],
		[MOVE_WIDE_RANGE, "wide range (never used)"]],
	PREDUEL_FLAGS: [[PRE_CARD, "card in play"], [PRE_MIND, "mind control"],
		[PRE_SWAP, "try this deck"], [PRE_FIRST, "first strike"],
		[PRE_UNREAD, "unread 0x020 (never used)"], [PRE_SUMMON, "summons"]],
	REWARD_FLAGS: [[REWARD_LIFE_CARRIED, "life carried"], [REWARD_TELEPORT, "teleport"],
		[REWARD_WON_CARD, "card"], [REWARD_GOLD, "gold"], [REWARD_FIRST_MOVE, "first move"],
		[REWARD_CARD_NEXT, "card in play next"], [REWARD_ANY_CARD, "any card"],
		[REWARD_ARTIFACT_NEXT, "artifact in play next"], [REWARD_FOOD, "food"],
		[REWARD_LIVES, "lives"], [REWARD_DUPLICATE, "duplicate"]],
}

## DESIGNED, NEVER USED: the table's byte 0x0e, by row (zero on the rest);
## no reader in 1.3 or retail (see the class doc).
const UNREAD_BYTE_0E := {1: 0x04, 3: 0x01, 8: 0x10, 11: 0x08, 13: 0x01, 15: 0x04, 16: 0x01,
	17: 0x80, 23: 0x01, 27: 0x08, 29: 0x01, 30: 0x08, 31: 0x20, 34: 0x40, 37: 0x20,
	38: 0x80, 39: 0x04, 41: 0x01, 42: 0x01}


# ------------------------------------------- the cards, the faces, the voice --

## THE 1997 CARD IDS THE TABLE NAMES — the reward cards ([constant
## REWARD_CARD]) and the signature cards ([constant DECK_NUMBER]) — as the
## engine spells them (`Info.csv` and the program's own table by id; our
## `cards/data/dck_ids.txt` agrees, in the 1997 spellings). Deck numbers
## 990–994 and 999 name no card ("Blank Slot", "Player Card"): the dragons
## and Arzakon have no signature card. Word of Command (Mind Stealer's) is a
## card of the optional pack 1 only.
const CARDS_1997 := {
	8: "Bad Moon", 10: "Balance", 15: "Birds of Paradise", 16: "Black Knight", 21: "Blessing",
	28: "Castle", 29: "Celestial Prism", 30: "Channel", 49: "Craw Wurm", 55: "Dark Ritual",
	56: "Darkpact", 69: "Drain Power", 74: "Earthbind", 76: "Elvish Archers", 94: "Fungusaur",
	95: "Gaea's Liege", 102: "Goblin King", 127: "Island Sanctuary", 128: "Ivory Cup",
	135: "Keldon Warlord", 139: "Ley Druid", 140: "Library of Leng", 141: "Lich",
	145: "Lightning Bolt", 147: "Living Lands", 149: "Llanowar Elves", 150: "Lord of Atlantis",
	151: "Lord of the Pit", 154: "Mahamoti Djinn", 160: "Merfolk of the Pearl Trident",
	163: "Mons's Goblin Raiders", 170: "Natural Selection", 175: "Northern Paladin",
	179: "Paralyze", 192: "Power Surge", 203: "Resurrection", 204: "Reverse Damage",
	207: "Rock Hydra", 211: "Samite Healer", 218: "Sea Serpent", 219: "Sedge Troll",
	220: "Sengir Vampire", 221: "Serra Angel", 229: "Smoke", 232: "Spell Blast",
	240: "Swords to Plowshares", 245: "Thoughtlace", 247: "Timber Wolves", 260: "Unsummon",
	261: "Uthden Troll", 262: "Verduran Enchantress", 263: "Vesuvan Doppelganger",
	275: "Wall of Wood", 283: "White Knight", 286: "Will-o'-the-Wisp", 289: "Word of Command",
	291: "Zombie Master", 399: "Bird Maiden", 400: "Bottle of Suleiman", 414: "Elephant Graveyard",
	426: "Ifh-Bíff Efreet", 433: "Junún Efreet", 434: "Juzám Djinn", 437: "Kird Ape",
	442: "Mijae Djinn", 456: "Serendib Efreet", 492: "Dragon Engine", 503: "Ivory Tower",
	525: "Shapeshifter", 810: "Tempest Efreet", 863: "Pandora's Box", 865: "Faerie Dragon",
	866: "Goblin Polka Band", 867: "Power Struggle", 871: "Necropolis of Azar",
	897: "Windseeker Centaur"}

## THE WIZARDS' MINIONS, by colour (1 black … 5 white): the three cards a
## ruled town's creature starts one of in play (`rand(3)`), and the castle
## monsters' by strength (1.3 `g_dungeon_monster_duel_music_csvids`,
## dungeonEncounter.c 182, ids 835 589 117 / 160 859 456 / 222 149 94 /
## 163 304 320 / 13 161 463).
const MINIONS := {
	1: ["Vampire Bats", "Carrion Ants", "Hypnotic Specter"],
	2: ["Merfolk of the Pearl Trident", "Zephyr Falcon", "Serendib Efreet"],
	3: ["Shanodin Dryads", "Llanowar Elves", "Fungusaur"],
	4: ["Mons's Goblin Raiders", "Brothers of Fire", "Fire Drake"],
	5: ["Benalish Hero", "Mesa Pegasus", "War Elephant"],
}

## THE CASTLE WIZARD OF EACH COLOUR (1 black … 5 white): the rows go in
## sevens black, white, blue, green, red. [Ours: 1997 slip — visitLocation.c
## 2784 took colour · 7, right only for black.]
const CASTLE_ROWS := {1: 7, 2: 21, 3: 28, 4: 35, 5: 14}

## The creatures' faces: `Faces/001.pic` … `055.pic` as the importer names
## them, `rogue_` + `@DECKFACES` (Menus.txt 78) in its own spelling
## (`tools/import_original.py` `ROGUE_NAMES`); row 56 wears row 55's.
const FACE_PREFIX := "rogue_"
const FACES: Array[String] = [
	"witch", "undead_knight", "warlock", "vampirelord", "nether_fiend",
	"necromancer", "greater_lich", "cleric", "priestess", "crusader",
	"paladin", "arch_angel", "high_priest", "sainted_one", "seer",
	"merfolk_shaman", "conjurer", "sea_dragon", "shapeshifter",
	"thought_invoker", "astral_visionary", "druid", "elvish_magi",
	"enchantress", "forest_dragon", "beastmaster", "summoner",
	"great_druid", "sorceress", "sorcerer", "troll_shaman", "goblin_lord",
	"hydra", "war_mage", "dragon_lord", "tusk_guardian", "sedge_beast",
	"ape_lord", "centaur_shaman", "winged_stallion", "fungus_master",
	"centaur_warchief", "mind_stealer", "lord_of_fate", "elementalist",
	"aga_galneer", "alt-a-kesh", "queltosh", "saltrem_tor", "mandurang",
	"whim", "prismat", "dracur", "kiska-ra", "uber_villain",
]
## The opponent's name in a duel: `Menus.txt` `@DECKFACES` by row − 1
## (duel_engine.c 798–804) — "Vampirelord", and Arzakon is "Uber Villain".
const DUEL_NAMES: Array[String] = [
	"Witch", "Undead Knight", "Warlock", "Vampirelord", "Nether Fiend", "Necromancer",
	"Greater Lich", "Cleric", "Priestess", "Crusader", "Paladin", "Arch Angel",
	"High Priest", "Sainted One", "Seer", "Merfolk Shaman", "Conjurer", "Sea Dragon",
	"Shapeshifter", "Thought Invoker", "Astral Visionary", "Druid", "Elvish Magi",
	"Enchantress", "Forest Dragon", "Beastmaster", "Summoner", "Great Druid", "Sorceress",
	"Sorcerer", "Troll Shaman", "Goblin Lord", "Hydra", "War Mage", "Dragon Lord",
	"Tusk Guardian", "Sedge Beast", "Ape Lord", "Centaur Shaman", "Winged Stallion",
	"Fungus Master", "Centaur Warchief", "Mind Stealer", "Lord of Fate", "Elementalist",
	"Aga Galneer", "Alt-A-Kesh", "Queltosh", "Saltrem Tor", "Mandurang", "Whim", "Prismat",
	"Dracur", "Kiska-Ra", "Uber Villain",
]

## THE CRIES, by kind: the 1997 sound file each kind 1–10 calls with on the
## map (`PlayCreatureEncounterSound`, world_lair_monster_slots.c 282–325);
## henchmen, castle wizards and Arzakon have none. The skin's key is
## `sfx_cry_` + the file's stem in lower case ([method cry_key]; the
## importer makes them under the same rule). [Ours: 1997
## slip — the flyer asked for `flyer.wav`, which no install ships; the file
## is `Flying.wav`, so the flyers were silent.]
const CRY_PREFIX := "sfx_cry_"
const CRIES: Array[String] = ["", "malewiz", "fewiz", "knight", "lord", "djinn", "troll",
	"wyrm", "dragon", "flying", "archmage"]

## THE MAP FIGURES, by row: the body and shadow sheets 1997 loads
## (`LoadCreatureEncounterSprites`, world_lair_monster_slots.c 38–279, `.SPR`
## file stems as 1997 wrote them); "" for none (the lair, the castle wizards
## but the Dragon Lord, Arzakon). Each is 40 frames of 8 directions × 5
## steps, the same layout as the hero's sheet. The skin's key is
## `world_creature_` + the stem in lower case ([method sprite_keys]). The
## centaurs' shadows are crossed in 1997 (each wears the other's); the two
## are near the same, kept as 1997 had them.
const SPRITE_PREFIX := "world_creature_"
const SPRITES: Array[Array] = [
	["", ""], ["BK_FWZ", "SFWZ"], ["BK_KHT", "SB_KHT"], ["BK_MWZ", "SMWZ"],  # 0–3
	["BK_LRD", "SB_LRD"], ["BK_WG", "SBK_WG"], ["BK_AMG", "SB_AMG"], ["", ""],  # 4–7
	["W_MWZ", "SW_MWZ"], ["W_FWZ", "SFWZ"], ["W_KHT", "SKHT"], ["W_LRD", "SW_LRD"],  # 8–11
	["W_WG", "SW_WG"], ["W_AMG", "SW_AMG"], ["", ""], ["BU_FWZ", "SFWZ"],  # 12–15
	["BU_LRD", "SU_LRD"], ["BU_MWZ", "SMWZ"], ["BU_WRM", "SWRM"], ["B_SFR", "SB_SFT"],  # 16–19
	["BU_AMG", "SU_AMG"], ["", ""], ["G_MWZ", "SMWZ"], ["G_KHT", "SKHT"],  # 20–23
	["G_FWZ", "SFWZ"], ["G_WRM", "SWRM"], ["G_LRD", "SG_LRD"], ["G_AMG", "SG_AMG"],  # 24–27
	["", ""], ["R_FWZ", "SR_FWZ"], ["R_MWZ", "SMWZ"], ["TROLL", "STRL"],  # 28–31
	["R_LRD", "SR_LRD"], ["R_WRM", "SR_WRM"], ["R_AMG", "SR_AMG"], ["R_AMG", "SR_AMG"],  # 32–35
	["M_TSK", "SM_TSK"], ["M_TRL", "SM_TRL"], ["M_APE", "SM_APE"], ["M_CEN2", "SM_CEN"],  # 36–39
	["M_WG", "SM_WG"], ["M_FNG", "SM_FNG"], ["M_CEN", "SM_CEN2"], ["M_LRD", "SM_LRD"],  # 40–43
	["M_KHT", "SKHT"], ["M_FWZ", "SFWZ"], ["BK_DJN", "SDJN"], ["G_DJN", "SDJN"],  # 44–47
	["R_DJN", "SDJN"], ["BU_DJN", "SDJN"], ["DG_BRU", "S_DG"], ["DG_UWB", "S_DG"],  # 48–51
	["DG_GWR", "S_DG"], ["DG_RBG", "S_DG"], ["DG_WUG", "S_DG"], ["", ""], ["", ""],  # 52–56
]

## The draws [method pick] makes before it gives up.
const PICK_TRIES := 999


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


## The first row named [param creature_name] ("Witch"), −1 for none.
static func row_named(creature_name: String) -> int:
	for index in ROWS.size():
		if String(ROWS[index][NAME]) == creature_name:
			return index
	return -1


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
		var kind_here := int(ROWS[index][KIND])
		if kind_here == LAIR or kind_here == ARZAKON or String(ROWS[index][DECK_FILE]) == "":
			continue
		if is_of(index, color):
			out.append(index)
	return out


## The path of creature [param index]'s deck, "" for none.
static func deck_path(index: int) -> String:
	var file := String(ROWS[index][DECK_FILE]) if is_row(index) else ""
	return DECKS_FOLDER.path_join(file + ".deck") if file != "" else ""


## Creature [param index]'s deck as the 1997 game showed it to the hero and
## played it with no colour learned — its MAINDECK, the colour sections left
## out ([method CreatureDeck.for_meeting] with filter 0: the Guardian's
## Ghost, the wise man, the lair duels) — or null for none. [Ours, part B:
## until 2026-10-23 this was the file's main list, which folds the `.vNone`
## section in; 1997 never played `.vNone` in the adventure.]
static func deck(index: int) -> DeckList:
	if not is_row(index) or String(ROWS[index][DECK_FILE]) == "" \
			or not FileAccess.file_exists(deck_path(index)):
		return null
	var out := DeckList.new()
	out.deck_name = name_of(index)
	out.cards = CreatureDeck.for_meeting(index, 0)
	return out


# ----------------------------------------------------------- the numbers --

## The creature's kind (`encounter_type`: [constant LAIR] … [constant
## ARZAKON]), −1 for no row.
static func kind(index: int) -> int:
	return int(ROWS[index][KIND]) if is_row(index) else -1


## The creature's tier (4 … 20, Arzakon 100), 0 for no row.
static func tier(index: int) -> int:
	return int(ROWS[index][TIER]) if is_row(index) else 0


## The table's base strength (1–3), 0 for no row.
static func base_strength(index: int) -> int:
	return int(ROWS[index][STRENGTH]) if is_row(index) else 0


## THE CREATURE'S STRENGTH — its bribe, its reward points, the odds of an
## amulet and of its colour learning the hero's deck: base strength + tier / 2,
## and 0 for henchmen, castle wizards and Arzakon (kinds 11 and up)
## (world_lair_monster_encounter.c 1557–1563; retail magic_all.c 57112).
## After a summons 1997 sets it again to the SUMMONER's base strength + the
## new creature's tier / 2, with no test of the kind (2187) — the meeting
## computes that from [method base_strength] and [method tier].
static func strength(index: int) -> int:
	if not is_row(index) or kind(index) >= HENCHMAN:
		return 0
	return base_strength(index) + tier(index) / 2


## THE BRIBE: ten gold a point of strength (`clamp(10·S, 10, 50·S)`, 1712),
## 0 where none is offered (the lair; kinds 11 and up). Whether it is offered
## at a meeting (gold enough, not near its castle, not besieging, fewer than
## five wins) is the meeting's.
static func bribe(index: int) -> int:
	if kind(index) <= LAIR or kind(index) >= HENCHMAN:
		return 0
	return strength(index) * 10


## THE CREATURE'S LIFE in a duel at [param difficulty] (0 Apprentice … 3
## Wizard), as `play_duel` sets it (duel.c 2227–2287; retail Kimpic.c
## 19702–19745): its tier, then
##  - + 5 a difficulty step for the castle wizards (rows 7, 14, 21, 28, 35:
##    row ≤ 36 and a multiple of 7), + 50 for Arzakon's rows (55, 56), + 2
##    for every other;
##  - a henchman (kind 11): + 1 for each World Magic the hero owns among the
##    first ten (bits 0–9: Sword of Resistance and Ring of the Guardian do
##    not count) — [param extras] `world_magics`, the names owned;
##  - a castle wizard (kind 12): + 10, − the hero's wins against its colour
##    (`wins`), + a difficulty step for each town it rules (`towns`), never
##    under 20 and 5 a step. [Ours: 1997 slip — it counted the towns whose
##    ruler matched a loop index (2260–2268, retail the same); the wizard's
##    own towns here, as [method WiseMan.castle_life].]
##  - Arzakon (kind 13): 100 and 100 a step, whatever else.
## `extras.tier` stands for the row's tier: the Spectral Arena's creature
## fights at tier 16 [ours, see the class doc].
static func duel_life(index: int, difficulty: int, extras := {}) -> int:
	var d := clampi(difficulty, 0, 3)
	var life := int(extras.get("tier", tier(index)))
	if index <= 36 and index % 7 == 0:
		life += 5 * d
	elif index >= 55:
		life += 50 * d
	else:
		life += 2 * d
	match kind(index):
		HENCHMAN:
			var owned: Array = extras.get("world_magics", [])
			for bit in 10:
				if AdventurePlayer.WORLD_MAGICS[bit] in owned:
					life += 1
		CASTLE_WIZARD:
			life += 10 - int(extras.get("wins", 0)) + int(extras.get("towns", 0)) * d
			life = maxi(life, 5 * d + 20)
		ARZAKON:
			life = 100 * d + 100
	return life


## Whether a win over creature [param index] pays spoils — cards, an amulet,
## the reward flags, the colour learning: kinds 1–10 only (the reward block
## is skipped for 11 and up, world_lair_monster_encounter.c 2271).
static func gives_spoils(index: int) -> bool:
	return kind(index) > LAIR and kind(index) < HENCHMAN


## Whether the creature is a woman (`IsCreatureTypeFeminine`,
## visitLocation.c 674): the texts' she and her.
static func feminine(index: int) -> bool:
	return is_row(index) and String(ROWS[index][GENDER]) == "f"


## The castle wizard's row of colour [param color] (1 black … 5 white), 0
## for none ([constant CASTLE_ROWS]).
static func castle_row(color: int) -> int:
	return int(CASTLE_ROWS.get(color, 0))


# --------------------------------------------------------------- the flags --

## The row's movement flags ([constant MOVE_FLAGS]).
static func move_flags(index: int) -> int:
	return int(ROWS[index][MOVE_FLAGS]) if is_row(index) else 0


## The row's pre-duel flags ([constant PREDUEL_FLAGS]).
static func preduel_flags(index: int) -> int:
	return int(ROWS[index][PREDUEL_FLAGS]) if is_row(index) else 0


## The row's reward flags ([constant REWARD_FLAGS]) — read by 1997 only
## when [method gives_spoils].
static func reward_flags(index: int) -> int:
	return int(ROWS[index][REWARD_FLAGS]) if is_row(index) else 0


## THE NAMES OF THE BITS of [param bits] in the table's field [param field]
## ([constant MOVE_FLAGS], [constant PREDUEL_FLAGS] or [constant
## REWARD_FLAGS]): `["fast", "blink"]`; a bit no name covers as its hex.
static func flag_names(field: int, bits: int) -> Array[String]:
	var out: Array[String] = []
	var left := bits
	for pair in FLAG_NAMES.get(field, []):
		if bits & int(pair[0]) != 0:
			out.append(String(pair[1]))
			left &= ~int(pair[0])
	for bit in 16:
		if left & (1 << bit) != 0:
			out.append("0x%03x" % (1 << bit))
	return out


## THE STRIDE on the map, world units a tick: 0 for the lair, 2 for a flyer
## or a FAST creature, else 1 (world_lair_monster_slots.c 641–697, 736–739).
static func stride(index: int) -> int:
	if kind(index) == LAIR:
		return 0
	return 2 if kind(index) == FLYER or move_flags(index) & MOVE_FAST != 0 else 1


## THE ROW SHOWN on the map at the world's clock [param timer]: a DISGUISE
## creature's cycles through itself and the three rows below
## (`row − ((timer >> 5) & 3)`, world_lair_monster_slots.c; the lurk test of
## [constant MOVE_HIDDEN] reads it); any other is itself.
static func shown_row(index: int, timer: int) -> int:
	if move_flags(index) & MOVE_DISGUISE == 0:
		return index
	return index - ((timer >> 5) & 3)


# -------------------------------------------- the cards, faces and voices --

## The engine's name of the creature's reward card — the card a CARD
## pre-duel puts in play and the CARD rewards give — "" for none.
static func reward_card(index: int) -> String:
	return String(CARDS_1997.get(int(ROWS[index][REWARD_CARD]), "")) if is_row(index) else ""


## The engine's name of the creature's SIGNATURE card, the card of 1997 id
## its deck number — never its ante (world_lair_monster_encounter.c 1588:
## the Warlock never antes Dark Ritual) — "" for none.
static func signature_card(index: int) -> String:
	return String(CARDS_1997.get(int(ROWS[index][DECK_NUMBER]), "")) if is_row(index) else ""


## The creature's face, a portrait id (`rogue_witch`; the importer's
## `portraits/rogue_<@DECKFACES>.png` of `Faces/NNN.pic`, which the 1997
## meeting and duel screens show by row): row 56 wears row 55's, the lair
## none ("").
static func face_id(index: int) -> String:
	if not is_row(index) or index == LAIR:
		return ""
	return FACE_PREFIX + FACES[mini(index, FACES.size()) - 1]


## The opponent's name in the duel ([constant DUEL_NAMES]): "Vampirelord",
## "Uber Villain"; the lair none.
static func duel_name(index: int) -> String:
	if not is_row(index) or index == LAIR:
		return ""
	return DUEL_NAMES[mini(index, DUEL_NAMES.size()) - 1]


## THE CRY'S SOUND KEY in the skin for creature [param index]
## (`sfx_cry_malewiz` …; [constant CRIES]), "" for a creature with no
## cry (the lair, kinds 11 and up).
static func cry_key(index: int) -> String:
	var k := kind(index)
	if k <= LAIR or k >= CRIES.size():
		return ""
	return CRY_PREFIX + CRIES[k]


## THE MAP FIGURE'S SKIN KEYS, `{body, shadow}`: `world_creature_` + the
## 1997 sheet's stem in lower case (`world_creature_bk_fwz`,
## `world_creature_sfwz`) — the importer makes them under the same rule —;
## both "" for a row with no figure ([constant SPRITES]).
static func sprite_keys(index: int) -> Dictionary:
	var stems: Array = SPRITES[index] if is_row(index) else ["", ""]
	var out := {}
	for i in 2:
		var stem := String(stems[i])
		out["body" if i == 0 else "shadow"] = SPRITE_PREFIX + stem.to_lower() if stem != "" else ""
	return out


# ------------------------------------------------------------- the pick --

## A CREATURE OF TIER [param wanted_tier] AND COLOUR [param color] (1 black …
## 5 white; 0 any), drawn on the adventure's [param dice] exactly as 1997's
## `PickRandomCreatureTypeForWizardTier` (visitLocation.c 2303): a row
## `rand(56) + 1` (1–56) drawn again until its tier is the one wanted and,
## for a colour, its colours hold it — at most [constant PICK_TRIES] draws,
## after which the LAIR (0) comes back, even when the last draw was right.
## So a tier no creature of that colour has (white 13) gives the lair, after
## 999 draws of the dice. Every draw consumes the dice; the callers give
## them back to [member AdventurePlayer.dice].
static func pick(dice: MsvcRandom, color: int, wanted_tier: int) -> int:
	var tries := 0
	var row := 0
	while true:
		row = dice.below(ROWS.size() - 1) + 1
		tries += 1
		var fits := tier(row) == wanted_tier and (color == 0 or _mask(row) & (1 << color) != 0)
		if tries >= PICK_TRIES or fits:
			break
	return LAIR if tries == PICK_TRIES else row


## The row's colours as 1997 reads the byte, a signed char: the lair's 0xFF
## is every colour.
static func _mask(index: int) -> int:
	var bits := int(ROWS[index][COLORS])
	return -1 if bits == 0xFF else bits
