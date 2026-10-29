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
## saved as JSON a person can read. The duels' own record (the victories,
## what each colour's creatures have learned of the hero's deck, the
## carried lives) is filled by the meetings and their spoils
## ([CreatureMeeting], [DuelSpoils]) through its helpers ([method
## log_victory], [method wins_against], [method learn_deck_colors],
## [method add_card]); the sieges' by [Sieges]; the end's (part C: how the
## adventure ended, the end's record, Arzakon's door and portal, the final
## battle's rule chosen at the Embark) by [FinalBattle].
##
## ONE GAME, ONE FILE NAME: an adventure is named by its hero and a hash of
## the moment it began ([member adventure_id]), and its first save is
## written the moment its world is made ([method autosave]).
##
## SAVED WHOLE, READ SAFELY (campaign of 2026-10-23): a save is written
## whole or not at all, with the last good one kept beside it ([method
## save]); a save is read field by field, so one wrong field costs that
## field and not the adventure ([method from_dict]); and the lists read a
## file only when its bytes changed ([method scan_saves]).

## The save's own name and version, first in every file. VERSION 2 (part C
## stage C3, h5-5): part C's end — the end's marks, "One life" — rides in
## every save, and a build that reads only version 1 kept a save of 2 as
## unreadable ("saved by a newer version") rather than taking it up and
## writing it back without them (a failed One-life adventure alive again,
## a won one's end lost). VERSION 3 (the 0.50.65 bug campaign, k6-3): the
## Embark's card hold, ban list and sieges' pace ([member card_hold],
## [member ban_list], [member sieges]) ride in the hero's record; 0.50.64
## read version 2 and wrote it back without them — an unlimited bag past
## 500 cards came back to the 1997 limit, every card source then refusing.
## Version 3 carries the rules of 2026-10-29 too — the creatures' way, the
## duels' starting life and the ascetic hero ([member creatures], [member
## life_start], [member ascetic]) in the hero's record, the ascetic's half
## meal ([member meal_half]) with the food and the links a siege took
## ([member links_taken]) in the record (0.50.65 is the version that
## brings 3, so one number covers them all).
## This game reads 1 to 3: 1 and 2 are saves from before.
const FORMAT := "shandalar-adventure"
const FORMAT_VERSION := 3
## Where the adventures are saved (tests point it elsewhere).
const SAVES_FOLDER := "user://adventures"
static var saves_folder := SAVES_FOLDER
const AUTOSAVE := "autosave"
## The tail of the copy kept of a save's last good version ([method save]).
const BACKUP_TAIL := ".bak"
## The five parts every save must hold as records to be read at all
## ([method readable]); the others may be missing.
const MAIN_PARTS: Array[String] = ["adventure", "hero", "carried", "clocks", "world"]
## The largest count a save is read with (gold, food, the clocks): the
## 1997 game kept them in 32-bit numbers.
const MOST := 0x7FFFFFFF
## THE JOURNAL'S LIMIT: 1997's `AddJournalEntry` (adventure_new_game.c,
## 0x004290e2) writes a line only while fewer than 2,000 are kept. [Ours,
## the owner 2026-10-23: "extend that".] Five times that here: every
## autosave writes the whole journal, measured at about 4 ms a thousand
## lines to save and 8 ms to load, so 10,000 lines cost ~42 ms on leaving a
## place, ~83 ms to load and a ~2 MB file; with no limit at all the saves
## would only ever grow. A full journal keeps its lines and writes no more —
## the record is counted from them ([method duel_record],
## [method HeroStats.record]), so dropping the oldest would take wins away.
const JOURNAL_MOST := 10000

## The five colours in the 1997 game's order (1 black … 5 white, as the
## amulets are kept, `g_amulet_inventory`).
const COLORS: Array[String] = ["black", "blue", "green", "red", "white"]

## THE VICTORY LOG'S LIMIT: 1997 keeps a win only while fewer than 1,000 are
## logged (`AppendDuelVictoryLogEntry`, world_lair_monster_encounter.c
## 326–338) — [method log_victory].
const VICTORIES_MOST := 1000
## THE MAGIC BAG: 1997 keeps at most 500 cards (`deck[500]`); a card won
## with the bag full is lost (`AddCardToDeckSorted`, duel.c 1859–1867) —
## [method add_card]. From 450 the spoils warn ("Your magic bag only holds
## 500 spells…", `@ENCOUNTER_POSTDUEL` 31; the pane's).
const BAG_MOST := 500
## Said when a card is refused for a full bag.
const BAG_FULL := "Your magic bag holds no more spells."
const BAG_WARN := 450
## THE CARD HOLD, chosen at the Embark (the owner, 2026-10-28: "A new
## Embark setting: card hold — '1997 card hold limit' / 'unlimited card
## hold'"; [member card_hold]): [constant HOLD_1997] keeps the bag at
## [constant BAG_MOST] as above — every place a card comes from refuses or
## loses it past that, the spoils warn from [constant BAG_WARN] and a
## dungeon's treasure offers the full bag's swap; [constant HOLD_UNLIMITED]
## takes the limit away everywhere ([method bag_room]), so no full-bag
## word, warning or swap ever comes. An adventure from before the choice:
## the 1997 limit. [ours]
const HOLD_1997 := "1997 limit"
const HOLD_UNLIMITED := "unlimited"
const CARD_HOLDS: Array[String] = [HOLD_1997, HOLD_UNLIMITED]
## THE SIEGES' PACE, chosen at the Embark [ours, the owner's ruling of
## 2026-10-28 on 1997's complaint, "creatures siege towns too much and they
## cannot explore": 1.3's clock came faster with every siege, to one every
## ~30 s of walking with ~15 s to lift it; [member sieges], [Sieges]):
## [constant SIEGES_1997] the clock exactly as 1997's; [constant
## SIEGES_STEADY] (a new adventure's default) the first siege's pace all
## game — the clock's jumps by the difficulty only; [constant SIEGES_RARE]
## the same jumps and the clock stepping half as often (every 64 walking
## ticks, not 32); [constant SIEGES_NONE] no siege ever begins — no town
## lost, no Dominion; the quest still the five castles and Arzakon. An
## adventure from before the choice: as 1997, as it was played.
const SIEGES_1997 := "as 1997"
const SIEGES_STEADY := "steady"
const SIEGES_RARE := "rare"
const SIEGES_NONE := "none"
const SIEGE_PACES: Array[String] = [SIEGES_1997, SIEGES_STEADY, SIEGES_RARE, SIEGES_NONE]
## THE CREATURES' WAY, chosen at the Embark [ours, the owner's ruling of
## 2026-10-29 on the choke points: "Add, default Notice (Recommended)";
## [member creatures], [WorldCreatures]): [constant CREATURES_HUNT] 1997 as
## shipped — every creature steers at the hero from anywhere, every tick;
## [constant CREATURES_NOTICE] (a new adventure's default) 1997's designed,
## never used range and speed switched on (docs/adventure-unused-1997-
## features.md §6–§7): a creature wanders its own lands until the hero
## comes within its range, then hurries at them; some are slowed on certain
## lands. An adventure from before the choice: Hunt, as it was played.
const CREATURES_HUNT := "hunt"
const CREATURES_NOTICE := "notice"
const CREATURE_WAYS: Array[String] = [CREATURES_HUNT, CREATURES_NOTICE]
## THE DUELS' STARTING LIFE, chosen at the Embark [ours, the owner's ruling
## of 2026-10-29: "Add, default off (Recommended)"; [member life_start],
## [method duel_start_life]): [constant START_LINKS] 1997 as shipped — a
## life for each mana link; [constant START_BASE] 1997's design (§1 of the
## unused features, duel.c 2205–2226, retail Kimpic.c 19685–19697, where
## the links' count then overwrote it): [constant LIFE_BASE], and [constant
## LIFE_BONUSES] for the three World Magics owned, then the links — every
## adventure duel 10 or more higher. An adventure from before the choice:
## links only, as it was played.
const START_LINKS := "links only"
const START_BASE := "base 10 + links"
const LIFE_STARTS: Array[String] = [START_LINKS, START_BASE]
## The base and the World Magics' bonuses `play_duel` set before the links
## overwrote them (duel.c 2209–2217: bits 0x002, 0x800 and 0x080).
const LIFE_BASE := 10
const LIFE_BONUSES := {"Haggler's Coin": 2, "Ring of the Guardian": 3, "Fruit of Sustenance": 5}
## THE MANA LINKS A SIEGE TOOK COME BACK when the town is freed — under the
## sieges' paces that are ours ([constant SIEGES_STEADY], [constant
## SIEGES_RARE], [constant SIEGES_NONE]); under [constant SIEGES_1997] they
## stay lost, as played [ours, the owner's ruling of 2026-10-29: "With
## Steady/Rare (Recommended)"; [member links_taken], [method restore_link]].
const LINKS_RETURN: Array[String] = [SIEGES_STEADY, SIEGES_RARE, SIEGES_NONE]
## "Your mana link here is restored." — said as a freed town's link comes
## back, in 1997's words for the loss ("Your mana tap here is lost.",
## `@NEWSFLASH` 10) turned round [ours].
const LINK_RESTORED := "Your mana link here is restored."

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
## The name of the save slot this was last saved into or taken up from
## ([SaveSlots]). Only a slot's own file carries it: the autosave is
## written with none ([method save]), as the load screen shows it as the
## autosave.
var slot_name := ""
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
## The three card rules ([member card_rule]).
const RULE_MEANT := "as intended"
const RULE_SHIPPED := "as shipped"
const RULE_CLASSIC := "classic"
const CARD_RULES: Array[String] = [RULE_MEANT, RULE_SHIPPED, RULE_CLASSIC]
## THE CARD RULE, chosen at the Embark (the owner, 2026-10-24: "an on off
## setting during shandalar embark construction", then "one more rule …
## classic MTG rules"; the names are the owner's):
##  - [constant RULE_MEANT] "Adventure limit of cards (as intended in 1997)":
##    the shops and the duel rewards offer no card the deck in use already
##    holds as many copies of as its size allows (1997's
##    `GetRemainingAllowedCardCopies`, [method CardShop.counted_copies]);
##  - [constant RULE_SHIPPED] "No limit (as shipped in 1997)": that rule's
##    count of copies matched no card the hero owned, so it refused none for
##    its copies (only its special and outside-the-base-sets cases stayed);
##  - [constant RULE_CLASSIC] "Classic MTG rules" [ours]: a deck holds four
##    of a card, one of a restricted card (four with Tome of Enlightenment),
##    none of a banned one, basic lands without end ([method
##    DeckModel.classic_allowance]); no one offers a card the hero already
##    owns as many copies of as that allows ([method CardShop.classic_allows]).
## The 1997 deck builder's rule judges the decks under the first two.
var card_rule := RULE_MEANT
## The card rule as the on/off copy limit it began as: on for "as intended",
## off for "as shipped" (setting it chooses one of those two).
var copy_limit: bool:
	get:
		return card_rule == RULE_MEANT
	set(on):
		card_rule = RULE_MEANT if on else RULE_SHIPPED
## The playmat of the hero's duels, `{color, type}` — ours.
var playmat := {}
## The card packs that join this adventure, `[{id, version}]` — ours.
var packs: Array = []
## THE FINAL BATTLE'S RULE, chosen at the Embark (the owner, 2026-10-27,
## round P3: "A setting at Embark"; the names are the owner's) — what a lost
## battle against Arzakon leaves ([FinalBattle]):
##  - [constant LIFE_RELOAD] "Reload allowed": the adventure is saved at
##    Arzakon's door as the battle begins ([member at_door]); after the
##    quest-failed end, loading it puts the hero back at the door, the
##    attempt lost written in the record ([member final_attempts], the
##    journal);
##  - [constant LIFE_ONE] "One life": the loss closes the adventure for
##    good, its save marked failed ([member ended]) — and so does leaving
##    or closing the game during the battle (the owner's ruling of
##    2026-10-27: *"True ironman: closing mid-battle ends the adventure as a
##    lost final battle; no way to retry."*; [method FinalBattle.on_load]).
## A win is the same under both. An adventure from before the choice:
## reload allowed. [ours]
const LIFE_RELOAD := "reload allowed"
const LIFE_ONE := "one life"
const LIFE_RULES: Array[String] = [LIFE_RELOAD, LIFE_ONE]
var life_rule := LIFE_RELOAD
## The card hold ([constant CARD_HOLDS]; [method bag_room]).
var card_hold := HOLD_1997
## THE BAN LIST the Classic MTG rules read ([constant RULE_CLASSIC];
## [ClassicBans], chosen at the Embark, the owner 2026-10-28): "1998 (the
## original game's)", "1998 + modern" or "modern" — kept under every card
## rule, read only under the Classic one ([method CardShop.classic_rule],
## [method AdventureBuilder._copy_rule], [method StarterDeck.deal]). An
## adventure from before the choice: "1998 + modern", the default.
var ban_list := ClassicBans.DEFAULT
## The sieges' pace ([constant SIEGE_PACES]; [Sieges]).
var sieges := SIEGES_1997
## The creatures' way ([constant CREATURE_WAYS]; [WorldCreatures]).
var creatures := CREATURES_HUNT
## The duels' starting life ([constant LIFE_STARTS]; [method
## duel_start_life]).
var life_start := START_LINKS
## THE ASCETIC HERO, chosen at the Embark [ours, the owner's ruling of
## 2026-10-29: "The option halves food consumption by the hero or other
## words lengthens the time hero can live with food by 2"; [method
## eats_this_step], [HeroWalk]]: off (1997 as shipped) a walking hero eats a
## food every clock step; on, every other step — the half step kept in
## [member meal_half] and saved, so a save and a load never skip or double
## a meal. Fruit of Sustenance's gift in the forests is as it was. An
## adventure from before the choice: off.
var ascetic := false


# --------------------------------------------------------------- where --

## The hero's place in world units, 32 to a tile (0x1EAEC, 0x1EAF0).
var position := Vector2i.ZERO
## The way the hero last walked, 1–8 (`g_neighbor_dx/dy`: 1 north … 8
## north-west), 0 before the first step.
var facing := 0
## The walking figure's step, 0 standing, 1–4 walking.
var step := 0
## THE ENTRY LATCH KEPT (the world screen's, [method WorldScreen.walk_to_tile]):
## the tile of the place the hero arrived at and still stands on, (−1, −1)
## for none — saved, so after a Resume or a Load a click on the town just
## left, or the one stood in as the window closed, opens it again and is no
## new arrival: no second "Visited", no quest, trade, hint or shop drawn
## again, no creature pushed back again (the bug campaign c12, h1-1, h1-2).
## Read only for the tile the hero stands on. [ours]
var entered_tile := Vector2i(-1, -1)


# ------------------------------------------------- what the hero carries --

var gold := 0                                   # 0x21D20
var food := 0                                   # 0x21D24
## The ascetic hero's half meal: 1 when the last clock step's food was
## skipped and the next eats ([member ascetic]); 0 otherwise — ours.
var meal_half := 0
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

## THE NEXT DUEL'S LIVES, kept as 1997 keeps them, in two fields that add
## up ([method next_duel_lives]): the extra lives a gift gives — 1997's 1–5
## in `g_next_duel_card_id` (0x224C0): a creature's reward 0x800, the wise
## man's, the Oasis's — …
var next_duel_life := 0
## … and the lives CARRIED from the last duel won with reward 0x1, the life
## the hero ended it with less what they began with — negative when they
## lost life (`g_next_duel_life_delta`, 0x224BC; `@ENCOUNTER_POSTDUEL` 16).
var next_duel_life_carried := 0
## A card the next duel starts with in play, "" for none (0x224C0 above 5).
var next_duel_card := ""
## The first move in the next duel (0x224C0 = 0).
var next_duel_first_move := false
## THE VICTORY LOG (0x21D28): each duel won against a roaming creature,
## `{color, kind, creature}` — the slot's colour (1 black … 5 white, 0 for
## none), the creature's kind ([method CreatureBook.kind]: −1 for an old
## record that named no creature) and its name. 1997 logs a byte `colour·16
## + kind`; the wins against a kind and colour make its creatures flee, stop
## coming, offer riddles and tribute ([method wins_against]), the wins
## against a colour weaken its castle wizard ([method wins_over_color]), and
## all of them the meeting's hand modifier ([method total_wins]).
var duel_victories: Array = []
## WHAT EACH COLOUR'S CREATURES HAVE LEARNED of the hero's deck: by colour
## (index colour − 1, 1 black … 5 white), the colour bits (0x02 black …
## 0x20 white) of the colour sections its creatures add to their decks
## ([CreatureDeck]); 0 until they learn, after a win, the hero's deck
## colours (`g_opponent_deck_color_filter_by_color`, saved, 0 at a new game).
var creature_deck_colors: Array[int] = [0, 0, 0, 0, 0]
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
## The quest under way, `{}` for none (0x21CF8; its fields in [Quests]).
var quest := {}
## The quest the last town visited offers, `{type, destination, color,
## at}` or `{}` (1997's pending offer, unsaved there) ([Quests]).
var quest_offer := {}
## The last town whose services the hero used: a town's quest and its wise
## man's first words are drawn only on a visit to another (1997's
## `g_last_town_services_town_index`, unsaved there).
var last_town := -1
## When each town last gave a quest, on the quest clock, by site slot
## (`"<slot>"`; the town's `quest_restock_timer`).
var town_quests := {}
## What the wise men last said: `{stage, tale, block, …}` ([WiseMan];
## 1997's globals, unsaved there).
var wise_man := {}
## THE LINKS A SIEGE TOOK: the site slots of the towns that were linked
## when a siege took them ([method Sieges.resolve]), until each is freed —
## then, under the paces of [constant LINKS_RETURN], the link comes back
## ([method restore_link]). Saved; a save from before it remembers none,
## so no link returns there. [ours]
var links_taken: Array[int] = []


# ------------------------------------------------------------- the end --
# Part C (the owner's rulings of 2026-10-27, "The end"): 1997 saved nothing
# from the fifth castle on and ended the program after the final battle,
# whatever its result. Ours keeps the end in the save, written by
# [FinalBattle].

## HOW THE ADVENTURE ENDED: "" while it goes on; [constant ENDED_WON] once
## Arzakon is beaten — the world is then at peace ([method at_peace]) and
## the hero may walk on in it (the owner's Q-SAVE: "Saved as won + walk
## on"); [constant ENDED_FAILED] once a final battle is lost under "One
## life" — such a save opens on its end, never the world. The load list
## shows it ([method save_at]).
const ENDED_WON := "won"
const ENDED_FAILED := "failed"
const ENDINGS: Array[String] = [ENDED_WON, ENDED_FAILED]
var ended := ""
## THE END'S RECORD, `{}` until the adventure ends ([method
## FinalBattle.settle]): `{result, score, base, years, lives_start,
## lives_end, difficulty, days, wins, date, attempts, life_rule}` — `result`
## "won" or "failed"; `score` the years Arzakon is banished, for a win
## only; `base` the battles' share before the final one ([method
## FinalBattle.score]); `years` the final battle's; the lives the battle
## began and ended with, `[hero, Arzakon]` (as [DuelReport] keeps them);
## the days on the road and the duels won; when (ISO, UTC); the final
## battles lost before it; the final battle's rule; `left` true when the
## battle was lost by leaving it under "One life" ([method
## FinalBattle.on_load]); `roamed` true once the hero chose to walk on
## after the win ([method FinalBattle.roam]).
var final := {}
## THE FINAL BATTLES LOST AND TAKEN UP AGAIN at Arzakon's door under
## "Reload allowed" — each also a journal line, "Lost to an Arzakon".
var final_attempts := 0
## THE HERO STANDS AT ARZAKON'S DOOR: set as the final battle begins
## ([method FinalBattle.door], the adventure saved then); cleared by a win
## and by the loss under "One life". Under "Reload allowed" a save that
## holds it opens at the door, the battle to fight again (part C's
## finale); under "One life" it means THE BATTLE HAS BEGUN — a save that
## holds it, taken up again, is a lost final battle ([method
## FinalBattle.on_load]).
var at_door := false
## ARZAKON'S PORTAL on the world (the owner's Q-PORTAL: "Return to
## Shandalar first" — "a portal stands on the world"; after the win "The
## Arzakon portal is shown as petrified monument!"; near the map's middle,
## [method FinalBattle.portal_tile]): `{x, y, state}` — the tile it stands
## on, [constant FinalBattle.PORTAL_OPEN] or [constant
## FinalBattle.PORTAL_PETRIFIED]; `{}` for none. Data only: the world
## screen draws it. [ours]
var portal := {}


# ------------------------------------------------------------ the clocks --

## The world's clock: one tick per 60 ms of the world screen (0x1EAF4).
var monster_timer := 0
## The quest and restocking clock (0x224B0), and the siege clock
## (0x224A8): both a step for every 32 ticks the hero walks.
var quest_timer := 0
var siege_timer := 0
var siege_active := false                       # 0x2A220
## Sieges begun and towns fallen, one each (`g_siege_count`): the end's
## score takes it off (dungeonEncounter.c 1856; [method FinalBattle.score]).
## [Ours: 1997 never saved it, so a game loaded counted from 0 again — the
## owner's "sieges counted all game", 2026-10-27.]
var siege_count := 0
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
## The roaming creatures and lairs (0x1EA2C, `ShandalarMonsterSlot`: six
## roaming slots and the besieger's), none until they are made — slots 0–5
## roaming ([WorldLairs], [WorldCreatures]), 7 the creature besieging a city
## ([WorldMagic]):
##  - a lair `{slot, kind: "lair", x, y, color}`;
##  - a creature `{slot, kind: "creature", creature, x, y, color, heading,
##    frame}` — its row of the creature book (1–54), its place in world
##    units, its slot's colour (1 black … 5 white), the way it last went
##    (0–8, 0 just come) and its walk's frame (0 standing, 1–4); the
##    besieger also `town`, the site it besieges.
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
	player.card_rule = card_rule_of(record.get("card_rule"), record.get("copy_limit", true))
	player.life_rule = life_rule_of(record.get("life_rule"))
	player.card_hold = card_hold_of(record.get("card_hold"))
	player.ban_list = ClassicBans.key_of(record.get("ban_list"))
	player.sieges = sieges_of(record.get("sieges"))
	player.creatures = creatures_of(record.get("creatures"))
	player.life_start = life_start_of(record.get("life_start"))
	player.ascetic = record.get("ascetic") is bool and bool(record.get("ascetic"))
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
	for card_name in StarterDeck.deal(player.color, player.difficulty, rolls,
			player.card_rule == RULE_CLASSIC, player.ban_list):
		player.cards.append({"card": card_name, "decks": [0]})
	player.dice = rolls.state
	var own := AdventureSetup.color_number(player.color)
	player.world_magics.append(WORLD_MAGICS[own * 2])
	made.explore_around(made.start_tile())
	player.treasures_by_the_ban_list()
	return player


## THE DUNGEONS' TREASURES UNDER THE BAN LIST [ours, the owner's ruling of
## 2026-10-28, "Skip it" — the 0.50.65 bug campaign]: under the Classic MTG
## rules ([constant RULE_CLASSIC]) a treasure of the 28 ([constant
## ShandalarWorld.DUNGEON_CARDS]) the adventure's list bans ([member
## ban_list], [method ClassicBans.is_banned] — Mind Twist under "1998" and
## "1998 + modern") is never placed in a dungeon: the dungeon holds another
## of the 28 instead — one the list allows and the dungeon does not hold
## yet — as every other card source gives another card. Drawn on the
## world's own generator (at [member ShandalarWorld.seed], dungeon by
## dungeon), never on the adventure's dice: the same world and list give
## the same dungeons, at the Embark ([method begin]) and on loading a save
## from before ([method from_dict]). Nothing changes when the list bans none
## of the 28 — under the other card rules, and under "Modern", which frees
## Mind Twist: 1997's placement.
func treasures_by_the_ban_list() -> void:
	if card_rule != RULE_CLASSIC or world == null:
		return
	var allowed: Array[int] = []
	for k in ShandalarWorld.DUNGEON_CARDS.size():
		if not ClassicBans.is_banned(String(ShandalarWorld.DUNGEON_CARDS[k][1]), ban_list):
			allowed.append(k)
	if allowed.size() == ShandalarWorld.DUNGEON_CARDS.size():
		return
	var dice := MsvcRandom.new(world.seed)
	for slot in world.encounters:
		var held: Array = (slot as Dictionary).get("cards", [])
		for i in held.size():
			if int(held[i]) in allowed:
				continue
			var choices: Array[int] = []
			for k in allowed:
				if not k in held:
					choices.append(k)
			held[i] = choices[dice.below(choices.size())] if not choices.is_empty() else -1
		while -1 in held:
			held.erase(-1)


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


## Whether a gift for the next duel already waits — extra lives, the
## first move or a card in play (1997's one `g_next_duel_card_id`): a new
## gift of that kind is not given while one waits. (The lives carried are
## another field of 1997's, and no gift.)
func duel_gift_waiting() -> bool:
	return next_duel_life != 0 or next_duel_first_move or next_duel_card != ""


## THE LIVES THE NEXT DUEL ADDS to the hero's (or takes): the gift's and the
## ones carried (`play_duel`, duel.c 2213–2221, adds both).
func next_duel_lives() -> int:
	return next_duel_life + next_duel_life_carried


## EVERY NEXT-DUEL BONUS SPENT, as 1997 clears them after any duel, won,
## lost or drawn (visitLocation.c 2196–2231; the carried lives already as
## the duel begins, duel.c 2223).
func clear_duel_gifts() -> void:
	next_duel_life = 0
	next_duel_life_carried = 0
	next_duel_card = ""
	next_duel_first_move = false


# ------------------------------------------------------------- the end --

## THE WORLD AT PEACE: Arzakon beaten and the hero walking on (the owner,
## 2026-10-27: *"If you return to roam you can still explore only other
## cretures do not hunt you always, some do not or are passive and do not
## cocer towns etc - the game is passive just letting you battle creatires
## or explore the unexplored."*): no siege begins or falls ([Sieges]), and
## the creatures of every colour walk again, each of its own temper — some
## hunt the hero, some wander, some stand ([WorldCreatures]). [ours]
func at_peace() -> bool:
	return ended == ENDED_WON


## THE SCORE SO FAR — the years the battles fought so far would banish
## Arzakon for, computed as the end computes it ([method FinalBattle.score];
## 1997 computed it only after the fifth wizard): for the hero's record
## page (the owner's Q-RANK, "the score so far shown on the hero's record
## page"). It may be below zero; the end shows no less than 0 ([method
## FinalBattle.shown]). [ours]
func score_so_far() -> int:
	return FinalBattle.score(self)


## The final battle's rule [param value] names ([constant LIFE_RULES]), else
## "Reload allowed" (an adventure from before the choice).
static func life_rule_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in LIFE_RULES else LIFE_RELOAD


## The card hold [param value] names ([constant CARD_HOLDS]), else the 1997
## limit (an adventure from before the choice).
static func card_hold_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in CARD_HOLDS else HOLD_1997


## The sieges' pace [param value] names ([constant SIEGE_PACES]), else as
## 1997 (an adventure from before the choice, or a value no pace has).
static func sieges_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in SIEGE_PACES else SIEGES_1997


## The creatures' way [param value] names ([constant CREATURE_WAYS]), else
## Hunt (an adventure from before the choice, or a value no way has).
static func creatures_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in CREATURE_WAYS else CREATURES_HUNT


## The duels' starting life [param value] names ([constant LIFE_STARTS]),
## else links only (an adventure from before the choice).
static func life_start_of(value: Variant) -> String:
	return String(value) if value is String and String(value) in LIFE_STARTS else START_LINKS


# ------------------------------------------- the Embark's rules, applied --

## THE LIFE BEFORE THE LINKS: 0 under "Links only"; under "Base 10 + links"
## [constant LIFE_BASE] and each [constant LIFE_BONUSES] World Magic owned
## (duel.c 2209–2217).
func life_base() -> int:
	if life_start != START_BASE:
		return 0
	var base := LIFE_BASE
	for magic in LIFE_BONUSES:
		if owns(String(magic)):
			base += int(LIFE_BONUSES[magic])
	return base


## THE LIFE EVERY ADVENTURE DUEL STARTS FROM, before the next duel's lives:
## [method life_base] and the mana links ([method mana_links]) — 1997's
## `CountDuelPoolEligibleTowns` under "Links only". THE ONE READER: a
## meeting's, a lair's, a ruled town's, a dungeon room's (its life pool
## counts from it), a castle's and the final battle's life
## ([method CreatureMeeting.hero_life], [method DungeonDuels.life_parts]),
## the carried lives' start ([DuelSpoils]) and the purse's life on the
## pre-duel screens ([method EncounterStage.purse]).
func duel_start_life() -> int:
	return life_base() + mana_links()


## Whether a link a siege took comes back with its town ([constant
## LINKS_RETURN]).
func links_return() -> bool:
	return sieges in LINKS_RETURN


## A SIEGE TOOK TOWN [param slot] while it was linked ([method
## Sieges.resolve]): remembered in [member links_taken].
func note_link_taken(slot: int) -> void:
	if slot >= 0 and not slot in links_taken:
		links_taken.append(slot)


## TOWN [param slot] FREED (its guard beaten, [method RuledTowns.settle];
## its wizard beaten, [method Sieges.free_all]): forgotten from [member
## links_taken], and its link set again when [method links_return]. True
## when the link came back.
func restore_link(slot: int) -> bool:
	if not slot in links_taken:
		return false
	links_taken.erase(slot)
	if not links_return() or world == null:
		return false
	TownStatus.put(world, slot, TownStatus.LINKED)
	return true


## WHETHER THIS CLOCK STEP'S FOOD IS EATEN ([HeroWalk], every 32nd tick a
## hero walks with food): always, unless the hero is ascetic ([member
## ascetic]) — then every other step, the half kept in [member meal_half].
func eats_this_step() -> bool:
	if not ascetic:
		return true
	meal_half = 1 - clampi(meal_half, 0, 1)
	return meal_half == 0


# ------------------------------------------------------- the duels' record --

## A WIN LOGGED over creature [param row] met as colour [param hue] (the
## slot's: 1 black … 5 white): its kind and name with it. False when the
## log is full ([constant VICTORIES_MOST]) — 1997 then logs no more.
func log_victory(row: int, hue: int) -> bool:
	if duel_victories.size() >= VICTORIES_MOST:
		return false
	duel_victories.append({"color": hue, "kind": CreatureBook.kind(row), "creature": CreatureBook.name_of(row)})
	return true


## The wins logged against creatures of kind [param creature_kind] met as
## colour [param hue] — 1997's count of the log's `colour·16 + kind`
## (world_lair_monster_encounter.c 1742–1752): kinds are shared across rows
## (beating Centaur Shamans on black land counts against black Mandurangs).
func wins_against(creature_kind: int, hue: int) -> int:
	var count := 0
	for win in duel_victories:
		if int(win.get("kind", -1)) == creature_kind and int(win.get("color", 0)) == hue:
			count += 1
	return count


## The wins logged against creatures met as colour [param hue], of any kind
## (a castle wizard's life, duel.c 2245–2256).
func wins_over_color(hue: int) -> int:
	var count := 0
	for win in duel_victories:
		if int(win.get("color", 0)) == hue:
			count += 1
	return count


## Every win logged (the meeting's hand modifier,
## world_lair_monster_encounter.c 2114–2121).
func total_wins() -> int:
	return duel_victories.size()


## The colour bits colour [param hue]'s creatures have learned of the hero's
## deck ([member creature_deck_colors]), 0 for none or no colour.
func learned_deck_colors(hue: int) -> int:
	return creature_deck_colors[hue - 1] if hue >= 1 and hue <= 5 else 0


## Colour [param hue]'s creatures learn [param bits], the hero's deck colours
## (0x02 black … 0x20 white; `.vNone`'s 0x01 is never learned).
func learn_deck_colors(hue: int, bits: int) -> void:
	if hue >= 1 and hue <= 5:
		creature_deck_colors[hue - 1] = bits & CreatureDeck.PLAYED_BITS


# --------------------------------------------------------------- the cards --

## The cards of the deck in use ([member current_deck]), by name.
func deck_cards() -> Array[String]:
	var out: Array[String] = []
	for card in cards:
		if (card.get("decks", []) as Array).has(current_deck):
			out.append(String(card["card"]))
	return out


## Whether the bag has a limit: the 1997 card hold ([member card_hold]).
func bag_limited() -> bool:
	return card_hold != HOLD_UNLIMITED


## The cards the bag still holds room for ([constant BAG_MOST]) — without
## end ([constant MOST]) under "Unlimited card hold". Every place that gives
## a card asks here or through [method add_card].
func bag_room() -> int:
	if not bag_limited():
		return MOST
	return maxi(BAG_MOST - cards.size(), 0)


## A CARD WON OR FOUND joins the hero's cards, in no deck, as 1997's
## `AddCardToDeckSorted` (duel.c 1837–1867) adds it: false, and the card
## lost, when the bag already holds [constant BAG_MOST] (under the 1997 card
## hold; never under "Unlimited card hold", [method bag_room]). A rare or special
## card (rarity 3 or more, `GetCardRarity`) is written in the journal,
## "Acquired spell: %s" (`@LOGSTRINGS` 11). [Ours: 1997 slip — it wrote the
## line before it found the bag full, for a card then lost; written here
## only for a card kept.]
func add_card(card_name: String) -> bool:
	if card_name == "" or bag_room() < 1:
		return false
	cards.append({"card": card_name, "decks": []})
	if _rarity(card_name) >= 3:
		log_event("card", "Acquired spell: %s" % card_name, {"card": card_name})
	return true


## A card's 1997 rarity (`GetCardRarity`: special 4 for the Astral cards and
## those made for ante, else the program's own; [method
## CardShop.shop_rarity]), 0 for a card the game does not know.
static func _rarity(card_name: String) -> int:
	if not CardRegistry.has_card(card_name):
		return 0
	return CardShop.shop_rarity(CardValue.facts(CardRegistry.get_card(card_name)))


## THE HERO'S MANA LINKS: the linked towns and cities no wizard holds, each
## a life in a duel ([method TownStatus.mana_links]; the sites keep them —
## a save's `mana_links` is that count, for a reader of the file).
func mana_links() -> int:
	return TownStatus.mana_links(world)


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
## and the day on the road), and [param more] ([HeroStats.record]). Not
## written when the journal is full ([constant JOURNAL_MOST]).
func log_event(event: String, text: String, more := {}) -> void:
	if journal.size() >= JOURNAL_MOST:
		return
	var entry :={"event": event, "text": text, "x": position.x, "y": position.y, "time": monster_timer,
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
		"adventure": {"id": adventure_id, "created": created, "saved": saved, "game_version": game_version,
			"slot_name": slot_name},
		"hero": {"name": name, "portrait": portrait, "figure": walker,
			"figure_colors": figure_colors, "color": color,
			"difficulty": difficulty, "difficulty_name": difficulty_name(),
			"card_rule": card_rule, "copy_limit": card_rule != RULE_SHIPPED, "life_rule": life_rule,
			"card_hold": card_hold, "ban_list": ban_list, "sieges": sieges,
			"creatures": creatures, "life_start": life_start, "ascetic": ascetic,
			"playmat": playmat, "packs": packs},
		"where": {"x": position.x, "y": position.y, "tile": [tile().x, tile().y],
			"facing": facing, "entered": [entered_tile.x, entered_tile.y]},
		"carried": {"gold": gold, "food": food, "meal_half": meal_half, "amulets": amulets,
			"world_magics": world_magics, "cards": cards, "current_deck": current_deck,
			"deck_names": deck_names, "deck_notes": deck_notes, "deck_colors": deck_colors},
		"duels": {"next_duel_life": next_duel_life, "next_duel_life_carried": next_duel_life_carried,
			"next_duel_card": next_duel_card,
			"next_duel_first_move": next_duel_first_move,
			"victories": duel_victories, "creature_deck_colors": _by_color(creature_deck_colors),
			"last_duel_colors": last_duel_colors,
			"mana_links": mana_links(), "record": duel_record()},
		"record": {"journal": journal, "defeated_wizards": defeated_wizards,
			"lairs_explored": lairs_explored, "quest": quest, "quest_offer": quest_offer,
			"last_town": last_town, "town_quests": town_quests, "wise_man": wise_man,
			"links_taken": links_taken},
		"clocks": {"monster_timer": monster_timer, "quest_timer": quest_timer,
			"siege_timer": siege_timer, "siege_active": siege_active,
			"siege_count": siege_count, "quickening": quickening},
		"end": {"ended": ended, "final": final, "final_attempts": final_attempts,
			"at_door": at_door, "portal": portal, "score_so_far": score_so_far()},
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
## game can read ([method readable]).
##
## READ FIELD BY FIELD (campaign of 2026-10-23): one wrongly typed field —
## a deck's names written as a word, the amulets as a list — made the
## whole save unreadable, while broken records (a creature that is not a
## record, a card without its name) loaded and then flooded the world with
## errors. Now each field is taken only when it is of its kind, its
## default otherwise; a record the world reads is kept only when it is
## whole; places and indices are held to the world; and the rest of the
## save is kept. A save from before a newer field reads that field's
## default, as it always did. [ours]
static func from_dict(data: Dictionary) -> AdventurePlayer:
	if not readable(data):
		return null
	var where := _object(data.get("where"))
	var saved_world: Dictionary = data["world"]
	var made := _world_from(saved_world, Vector2i(_number(where.get("x")), _number(where.get("y"))))
	var player := AdventurePlayer.new()
	player.world = made
	_read_game(player, data["adventure"])
	_read_hero(player, data["hero"])
	_read_where(player, where)
	_read_carried(player, data["carried"])
	_read_duels(player, _object(data.get("duels")))
	_read_record(player, _object(data.get("record")))
	_read_clocks(player, data["clocks"])
	_read_end(player, _object(data.get("end")))
	player.world_seed_text = _text(saved_world.get("seed_text"), str(made.seed))
	player.made_fingerprint = _text(saved_world.get("made_fingerprint"))
	player.dice = _number(saved_world.get("dice"), made.rand_state)
	player.monsters = _cleaned_monsters(saved_world.get("monsters"), made)
	player.shops = _cleaned_shops(saved_world.get("shops"), made)
	# A Classic adventure from before the ruling: a banned treasure still
	# in a dungeon replaced as the Embark now replaces it.
	player.treasures_by_the_ban_list()
	return player


## Whether [param data] is a save this game reads: its [constant FORMAT],
## a version from 1 to [constant FORMAT_VERSION], its [constant
## MAIN_PARTS] each a record, and its world's grid whole — 128 rows of 64
## bytes in hex. Anything else a save lacks or holds wrongly is read with
## its default ([method from_dict]).
static func readable(data: Variant) -> bool:
	if not data is Dictionary or _text(data.get("format")) != FORMAT:
		return false
	var version := _number(data.get("version"))
	if version < 1 or version > FORMAT_VERSION:
		return false
	for part in MAIN_PARTS:
		if not data.get(part) is Dictionary:
			return false
	return _grid_whole((data["world"] as Dictionary).get("grid"))


## Whether [param grid] is the world's grid: 128 rows of 128 hex digits.
static func _grid_whole(grid: Variant) -> bool:
	if not grid is Array or (grid as Array).size() != ShandalarWorld.TILES * 2:
		return false
	for row in grid:
		if not row is String or (row as String).length() != ShandalarWorld.TILES * 2 \
				or not (row as String).is_valid_hex_number() or (row as String)[0] in ["+", "-"]:
			return false
	return true


static func _read_game(player: AdventurePlayer, game: Dictionary) -> void:
	player.adventure_id = _text(game.get("id"))
	player.created = _text(game.get("created"))
	player.saved = _text(game.get("saved"))
	player.game_version = _text(game.get("game_version"))
	player.slot_name = _text(game.get("slot_name"))


static func _read_hero(player: AdventurePlayer, hero: Dictionary) -> void:
	player.name = _text(hero.get("name"))
	player.portrait = _text(hero.get("portrait"))
	player.walker = _text(hero.get("figure"), "male")
	player.figure_colors = HeroColors.cleaned(_object(hero.get("figure_colors")))
	var color := _text(hero.get("color"), "white")
	player.color = color if color in COLORS else "white"
	player.difficulty = clampi(_number(hero.get("difficulty")), 0, 3)
	# A save from before the choice was made at the Embark: the limit as
	# 1997 meant it, which those adventures played by; one from before the
	# third rule: the on/off copy limit it kept.
	player.card_rule = card_rule_of(hero.get("card_rule"), hero.get("copy_limit", true))
	player.life_rule = life_rule_of(hero.get("life_rule"))
	# A save from before the Embark's card hold and ban list (2026-10-28):
	# the 1997 limit it played by, and the default list.
	player.card_hold = card_hold_of(hero.get("card_hold"))
	player.ban_list = ClassicBans.key_of(hero.get("ban_list"))
	# A save from before the sieges' pace: as 1997, as it was played.
	player.sieges = sieges_of(hero.get("sieges"))
	# A save from before the creatures' way, the starting life and the
	# ascetic hero (2026-10-29): Hunt, links only, off — as it was played.
	player.creatures = creatures_of(hero.get("creatures"))
	player.life_start = life_start_of(hero.get("life_start"))
	player.ascetic = _flag(hero.get("ascetic"))
	player.playmat = _whole(_object(hero.get("playmat")))
	player.packs = _whole(_list(hero.get("packs")))


## The hero's place, on the map: where the world starts them when the save
## has none.
static func _read_where(player: AdventurePlayer, where: Dictionary) -> void:
	var start := player.world.start
	player.position = Vector2i(_on_map(_number(where.get("x"), start.x)), _on_map(_number(where.get("y"), start.y)))
	player.facing = clampi(_number(where.get("facing")), 0, 8)
	# The entry latch (c12, h1-1): kept only for the tile the hero stands
	# on; a save from before it, or one naming another tile, has none.
	var entered := _list(where.get("entered"))
	if entered.size() == 2 and _is_number(entered[0]) and _is_number(entered[1]) \
			and Vector2i(_number(entered[0]), _number(entered[1])) == player.tile():
		player.entered_tile = player.tile()


static func _read_carried(player: AdventurePlayer, carried: Dictionary) -> void:
	player.gold = _count(carried.get("gold"))
	player.food = _count(carried.get("food"))
	player.meal_half = clampi(_number(carried.get("meal_half")), 0, 1)
	var amulets_saved := _object(carried.get("amulets"))
	for key in COLORS:
		player.amulets[key] = _count(amulets_saved.get(key))
	player.world_magics = _texts(carried.get("world_magics"), WORLD_MAGICS)
	player.cards = _cleaned_cards(carried.get("cards"))
	player.current_deck = clampi(_number(carried.get("current_deck")), 0, 2)
	_read_three(player.deck_names, carried.get("deck_names"))
	_read_three(player.deck_notes, carried.get("deck_notes"))
	player.deck_colors = _texts(carried.get("deck_colors"))


static func _read_duels(player: AdventurePlayer, duels: Dictionary) -> void:
	player.next_duel_life = _number(duels.get("next_duel_life"))
	player.next_duel_life_carried = _number(duels.get("next_duel_life_carried"))
	player.next_duel_card = _text(duels.get("next_duel_card"))
	player.next_duel_first_move = _flag(duels.get("next_duel_first_move"))
	player.duel_victories = _victories(duels.get("victories"))
	var learned := _object(duels.get("creature_deck_colors"))
	for i in COLORS.size():
		player.creature_deck_colors[i] = _number(learned.get(COLORS[i])) & CreatureDeck.PLAYED_BITS
	player.last_duel_colors = _whole(_object(duels.get("last_duel_colors")))


static func _read_record(player: AdventurePlayer, kept: Dictionary) -> void:
	player.journal = _cleaned_journal(kept.get("journal"))
	for key in _texts(kept.get("defeated_wizards"), COLORS):
		if not key in player.defeated_wizards:
			player.defeated_wizards.append(key)
	player.lairs_explored = _count(kept.get("lairs_explored"))
	player.quest = _numbers_record(kept.get("quest"))
	player.quest_offer = _numbers_record(kept.get("quest_offer"))
	var town := _number(kept.get("last_town"), -1)
	player.last_town = town if _is_site(town, player.world) else -1
	player.town_quests = {}
	var given := _object(kept.get("town_quests"))
	for key in given:
		if _is_number(given[key]):
			player.town_quests[String(key)] = _number(given[key])
	player.wise_man = _wise_man_record(kept.get("wise_man"))
	# The links a siege took (2026-10-29): the towns of this world, each
	# once; a save from before remembers none.
	player.links_taken = [] as Array[int]
	for slot in _list(kept.get("links_taken")):
		if _is_number(slot) and _is_site(_number(slot), player.world) and not _number(slot) in player.links_taken:
			player.links_taken.append(_number(slot))


static func _read_clocks(player: AdventurePlayer, clocks: Dictionary) -> void:
	player.monster_timer = _count(clocks.get("monster_timer"))
	player.quest_timer = _count(clocks.get("quest_timer"))
	player.siege_timer = _count(clocks.get("siege_timer"))
	player.siege_active = _flag(clocks.get("siege_active"))
	player.siege_count = _count(clocks.get("siege_count"))
	player.quickening = _count(clocks.get("quickening"))


## THE END'S MARKS (part C): each kept only when it is of its kind — an
## ending one of [constant ENDINGS], the end's record by its fields
## ([method _final_record]), the portal a tile of the map in a state it
## can be in ([method _portal_record]). A save from before part C has
## none: the adventure goes on.
## MARKS THAT CONTRADICT ONE ANOTHER (a damaged save; part C stage C3,
## h5-6) are made to agree: a won adventure's portal is the petrified
## monument, any other's stands open (a petrified portal with the
## adventure not won could never be entered — the end out of reach); the
## hero stands at Arzakon's door only in an adventure going on with all
## five wizards beaten ([method door_mark]; under "One life" a false door
## would be a lost final battle). The wizards are read first.
static func _read_end(player: AdventurePlayer, end: Dictionary) -> void:
	var how := _text(end.get("ended"))
	player.ended = how if how in ENDINGS else ""
	player.final = _final_record(end.get("final"))
	player.final_attempts = _count(end.get("final_attempts"))
	player.at_door = door_mark(end.get("at_door"), player.ended, player.defeated_wizards.size())
	player.portal = _portal_record(end.get("portal"))
	if not player.portal.is_empty():
		player.portal["state"] = FinalBattle.PORTAL_PETRIFIED if player.ended == ENDED_WON \
			else FinalBattle.PORTAL_OPEN


## Whether a save's door mark [param saved] stands ([member at_door]): set,
## the adventure going on ([param how] ""), all five wizards beaten
## ([param beaten] of them).
static func door_mark(saved: Variant, how: String, beaten: int) -> bool:
	return _flag(saved) and how == "" and beaten >= FinalBattle.ALL_FIVE


## The end's record ([member final]): its numbers numbers, its words
## words, its two pairs of lives two numbers each; anything else let go.
static func _final_record(value: Variant) -> Dictionary:
	var saved := _object(value)
	var out := {}
	for key in ["score", "base", "years", "difficulty", "days", "wins", "attempts"]:
		if _is_number(saved.get(key)):
			out[key] = _number(saved[key])
	for key in ["result", "date", "life_rule"]:
		if saved.get(key) is String:
			out[key] = saved[key]
	for key in ["left", "roamed"]:
		if saved.get(key) is bool:
			out[key] = saved[key]
	for key in ["lives_start", "lives_end"]:
		var pair := _list(saved.get(key))
		if pair.size() == 2 and _is_number(pair[0]) and _is_number(pair[1]):
			out[key] = [_number(pair[0]), _number(pair[1])]
	return out


## Arzakon's portal ([member portal]): a tile of the map and a state of
## [constant FinalBattle.PORTAL_STATES]; `{}` otherwise. (A save from
## before the map's middle — its portal on the fifth castle's ruins, a
## `castle` beside — keeps its tile.)
static func _portal_record(value: Variant) -> Dictionary:
	var saved := _object(value)
	if not (_is_number(saved.get("x")) and _is_number(saved.get("y"))) \
			or not _text(saved.get("state")) in FinalBattle.PORTAL_STATES:
		return {}
	var x := _number(saved["x"])
	var y := _number(saved["y"])
	if x < 0 or y < 0 or x >= ShandalarWorld.TILES or y >= ShandalarWorld.TILES:
		return {}
	return {"x": x, "y": y, "state": String(saved["state"])}


## THE WORLD FROM ITS SAVE (whose grid [method readable] has checked):
## the sites and dungeons by slot — a misshapen one an empty one, so no
## other moves — and the World Magics' towns sites of this world, or none.
## [param fallback_start] is where the hero starts when the save does not
## say.
static func _world_from(saved_world: Dictionary, fallback_start: Vector2i) -> ShandalarWorld:
	var made := ShandalarWorld.new()
	made.seed = _number(saved_world.get("seed"))
	made.slot_start = _number(saved_world.get("slot_start"))
	made.color = clampi(_number(saved_world.get("color"), 1), 1, 5)
	made.difficulty = clampi(_number(saved_world.get("difficulty")), 0, 3)
	made.page.resize(ShandalarWorld.PAGE_WIDTH * ShandalarWorld.PAGE_HEIGHT)
	var grid: Array = saved_world["grid"]
	for y in grid.size():
		var row := String(grid[y]).hex_decode()
		for x in ShandalarWorld.TILES:
			made.page[y * ShandalarWorld.PAGE_WIDTH + x] = row[x]
	for site in _list(saved_world.get("sites")):
		made.sites.append(_cleaned_site(site))
	for slot in _list(saved_world.get("world_magic_sites")):
		var town := _number(slot)
		made.world_magic_sites.append(town if _is_site(town, made) else 0)
	for slot in _list(saved_world.get("encounters")):
		made.encounters.append(_cleaned_encounter(slot, made))
	for when in _list(saved_world.get("lair_respawn")):
		made.lair_respawn.append(_number(when))
	var start := _list(saved_world.get("start"))
	made.start = Vector2i(_on_map(_number(start[0])), _on_map(_number(start[1]))) \
		if start.size() == 2 and _is_number(start[0]) and _is_number(start[1]) \
		else Vector2i(_on_map(fallback_start.x), _on_map(fallback_start.y))
	made.rand_state = _number(saved_world.get("dice"))
	return made


## A site as the world keeps it, `{x, y, type, trade, status}`: a tile of
## the map and a type of [constant SITE_KINDS]; anything not a record an
## empty place (type 0, which nothing visits).
static func _cleaned_site(value: Variant) -> Dictionary:
	var site := _object(value)
	return {"x": clampi(_number(site.get("x")), 0, ShandalarWorld.TILES - 1),
		"y": clampi(_number(site.get("y")), 0, ShandalarWorld.TILES - 1),
		"type": clampi(_number(site.get("type")), 0, SITE_KINDS.size() - 1),
		"trade": _number(site.get("trade")), "status": _number(site.get("status"))}


## An encounter slot ([member ShandalarWorld.encounters]): its numbers
## numbers, its place a tile of the map, its town a site of the world, its
## cards dungeon cards of the table ([constant ShandalarWorld.DUNGEON_CARDS]),
## its attempts (`entered`, [DungeonDoors]; absent in a save from before
## them, which reads 0) a count, its cards put back in a full-bag swap
## ([constant WorldClues.LEFT_CARDS]) names.
static func _cleaned_encounter(value: Variant, made: ShandalarWorld) -> Dictionary:
	var encounter: Dictionary = _whole(_object(value))
	for key in ["town", "color", "monster_flags", "rules", "card_in_effect", "clues"]:
		if encounter.has(key):
			encounter[key] = _number(encounter[key])
	if encounter.has("entered"):
		encounter["entered"] = _count(encounter["entered"])
	for key in ["x", "y"]:
		encounter[key] = clampi(_number(encounter.get(key)), 0, ShandalarWorld.TILES - 1)
	if encounter.has("town") and not _is_site(int(encounter["town"]), made):
		encounter["town"] = 0
	var held: Array[int] = []
	for card in _list(encounter.get("cards")):
		var index := _number(card, -1)
		if index >= 0 and index < ShandalarWorld.DUNGEON_CARDS.size():
			held.append(index)
	encounter["cards"] = held
	if encounter.has(WorldClues.LEFT_CARDS):
		encounter[WorldClues.LEFT_CARDS] = WorldClues.left_cards(encounter)
	return encounter


## The roaming creatures and lairs worth keeping ([member monsters]):
## records with a slot (0–5 roaming, [constant WorldMagic.SIEGE_SLOT] the
## besieger), one to a slot, with their place in the world (x and y in world
## units, on the map); the besieger with a town of the world. A lair keeps
## its colour; a creature its row (1–54), colour, heading (0–8) and frame
## (0–4) as numbers. Any other is dropped and the world fills its slot again
## ([WorldLairs]) — so is a creature with no row of the map, which drops an
## older save's unseen "waiting" creature (part B: until the duels came, a
## creature's draw held its slot unpicked) — and a besieger with no row
## whose save names one (part B, the besieger is a creature like the rest).
static func _cleaned_monsters(value: Variant, made: ShandalarWorld) -> Array:
	var kept: Array = []
	var taken := {}
	for entry in _list(value):
		if not entry is Dictionary:
			continue
		var creature: Dictionary = _whole(entry)
		var slot := _number(creature.get("slot"), -1)
		var roaming := slot >= 0 and slot < WorldLairs.SLOTS
		if taken.has(slot) or not (roaming or slot == WorldMagic.SIEGE_SLOT):
			continue
		if not (_is_number(creature.get("x")) and _is_number(creature.get("y"))
				and _on_map(_number(creature["x"])) == _number(creature["x"])
				and _on_map(_number(creature["y"])) == _number(creature["y"])):
			continue
		if creature.has("town") and not _is_site(_number(creature["town"], -1), made):
			continue
		if not roaming and not creature.has("town"):
			continue
		var kind := _text(creature.get("kind"))
		if kind == "lair" and not roaming:
			continue
		if kind == "creature" or creature.has("creature"):
			var row := _number(creature.get("creature"), -1)
			if row < WorldCreatures.FIRST_ROW or row > WorldCreatures.LAST_ROW:
				continue
			creature["kind"] = "creature"
			creature["creature"] = row
			creature["heading"] = clampi(_number(creature.get("heading")), 0, 8)
			creature["frame"] = clampi(_number(creature.get("frame")), 0, 4)
			creature.erase("waiting")
			creature.erase("tier")
			# Its temper in a world at peace (part C, [WorldCreatures]): one of
			# the three, else none (drawn again on the next tick); a
			# wanderer's way 0–8.
			if creature.has("temper") and not _text(creature["temper"]) in WorldCreatures.TEMPERS:
				creature.erase("temper")
			if creature.has("wander"):
				creature["wander"] = clampi(_number(creature["wander"]), 0, 8)
		elif kind != "lair":
			continue
		for key in ["slot", "x", "y", "town", "color"]:
			if creature.has(key):
				creature[key] = _number(creature[key])
		creature["color"] = clampi(_number(creature.get("color")), 0, 5)
		taken[slot] = true
		kept.append(creature)
	return kept


## The towns' shops worth keeping ([CardShop]): by a site slot of the
## world, each a record whose `cards` are names ("" a place sold) with a
## `restock` time for each; a hint that is not `{card, text}` and a trade
## time that is not a number are let go (a new visit draws them again).
static func _cleaned_shops(value: Variant, made: ShandalarWorld) -> Dictionary:
	var kept := {}
	var saved := _object(value)
	for key in saved:
		var slot := String(key).to_int() if String(key).is_valid_int() else -1
		if not _is_site(slot, made) or not saved[key] is Dictionary:
			continue
		var shop: Dictionary = _whole(saved[key])
		var cards: Array = []
		for card in _list(shop.get("cards")):
			cards.append(_text(card))
		var restock: Array = []
		for at in _list(shop.get("restock")):
			restock.append(_number(at, CardShop.NEVER_FILLED))
		while restock.size() < cards.size():
			restock.append(CardShop.NEVER_FILLED)
		restock.resize(cards.size())
		shop["cards"] = cards
		shop["restock"] = restock
		if shop.has("hint"):
			var hint := _object(shop["hint"])
			if _text(hint.get("card")) == "":
				shop.erase("hint")
			else:
				hint["card"] = _text(hint["card"])
				hint["text"] = _text(hint.get("text"))
				shop["hint"] = hint
		if shop.has("traded"):
			if _is_number(shop["traded"]):
				shop["traded"] = _number(shop["traded"])
			else:
				shop.erase("traded")
		kept[str(slot)] = shop
	return kept


## The cards owned worth keeping: records with a card's name (one not in
## the packs worn is still the hero's), each in the decks 0–2 it names.
static func _cleaned_cards(value: Variant) -> Array:
	var kept: Array = []
	for entry in _list(value):
		if not entry is Dictionary or _text((entry as Dictionary).get("card")) == "":
			continue
		var card: Dictionary = _whole(entry)
		var decks: Array = []
		for deck in _list(card.get("decks")):
			var at := _number(deck, -1)
			if at >= 0 and at <= 2 and not at in decks:
				decks.append(at)
		card["decks"] = decks
		kept.append(card)
	return kept


## The journal's lines worth keeping: records, their words words, their
## place and times numbers, a duel's `won` and a quest's `done` yes or no.
static func _cleaned_journal(value: Variant) -> Array:
	var kept: Array = []
	for entry in _list(value):
		if not entry is Dictionary:
			continue
		var line: Dictionary = _whole(entry)
		for key in ["event", "text"]:
			if line.has(key):
				line[key] = _text(line[key])
		for key in ["x", "y", "time", "day"]:
			if line.has(key):
				line[key] = _number(line[key])
		for key in ["won", "done"]:
			if line.has(key):
				line[key] = _flag(line[key])
		kept.append(line)
	return kept


# ------------------------------------------------- a field of its kind --
# What [method from_dict] reads a field with: the field when it is of its
# kind, the default otherwise.

static func _object(value: Variant) -> Dictionary:
	return value if value is Dictionary else {}


static func _list(value: Variant) -> Array:
	return value if value is Array else []


static func _is_number(value: Variant) -> bool:
	return value is int or (value is float and is_finite(value))


## A whole number, or [param fallback]; one too large for a number of the
## game is held at the largest.
static func _number(value: Variant, fallback := 0) -> int:
	if value is int:
		return value
	if value is float and is_finite(value):
		return int(clampf(roundf(value), -9.0e15, 9.0e15))
	return fallback


## A count: a whole number from 0 to [constant MOST].
static func _count(value: Variant) -> int:
	return clampi(_number(value), 0, MOST)


static func _text(value: Variant, fallback := "") -> String:
	return value if value is String else fallback


## The card rule [param value] names ([constant CARD_RULES]), else the one
## the on/off [param copy_limit] of a record or a save from before the third
## rule meant (on, or missing: "as intended"; off: "as shipped"). The copy
## limit a save writes beside the rule keeps an older game's reading close:
## on for the classic rules too.
static func card_rule_of(value: Variant, copy_limit: Variant) -> String:
	if value is String and String(value) in CARD_RULES:
		return String(value)
	return RULE_MEANT if copy_limit == null or _flag(copy_limit) else RULE_SHIPPED


static func _flag(value: Variant) -> bool:
	if value is bool:
		return value
	return _is_number(value) and _number(value) != 0


## The words of [param value], those of [param allowed] only when it is
## given.
static func _texts(value: Variant, allowed: Array[String] = []) -> Array[String]:
	var out: Array[String] = []
	for item in _list(value):
		if item is String and (allowed.is_empty() or item in allowed):
			out.append(item)
	return out


## The records of [param value], whole.
## A record of numbers alone — a quest, a quest offered —, or empty when
## any field is not a number (the bug pass after the campaign, r3-4: a
## quest's colour saved as a word or a list made every tick's deadline
## check an error).
static func _numbers_record(value: Variant) -> Dictionary:
	var record := _object(value)
	for key in record:
		if not _is_number(record[key]):
			return {}
	return _whole(record)


## The wise man's word ([WiseMan]): its stage and tale as numbers, its
## news as words, its reminder as a yes or no — each kept only when it is
## of its kind (r3-4).
static func _wise_man_record(value: Variant) -> Dictionary:
	var saved := _object(value)
	var out := {}
	for key in ["stage", "tale"]:
		if _is_number(saved.get(key)):
			out[key] = _whole(saved[key])
	if saved.get("news") is String:
		out["news"] = saved["news"]
	if saved.get("remind") is bool:
		out["remind"] = saved["remind"]
	return out


## THE DUELS WON, each read as `{color, kind, creature}` ([member
## duel_victories]) — kept only when its colour is a number or a word (one
## with none, nothing, a list or a record there is dropped, r3-4). A
## colour as a word ("red", an older shape) is its number, an unknown word
## or a number outside 0–5 no colour (0); the creature a name (or a row, as
## a number); the kind a number, or — in a save from before part B,
## `{color, creature}` — the named creature's kind, −1 when it names none.
static func _victories(value: Variant) -> Array:
	var out: Array = []
	for win in _records(value):
		var hue: Variant = (win as Dictionary).get("color")
		if not (_is_number(hue) or hue is String):
			continue
		var hue_number := _number(hue) if _is_number(hue) else COLORS.find(String(hue)) + 1
		var named: Variant = (win as Dictionary).get("creature", "")
		var row := -1
		var creature := ""
		if _is_number(named) and CreatureBook.is_row(_number(named)):
			row = _number(named)
			creature = CreatureBook.name_of(row)
		elif named is String:
			creature = named
			row = CreatureBook.row_named(creature)
		var kind_saved: Variant = (win as Dictionary).get("kind")
		out.append({"color": hue_number if hue_number >= 0 and hue_number <= 5 else 0,
			"kind": _number(kind_saved) if _is_number(kind_saved) else CreatureBook.kind(row),
			"creature": creature})
	return out


## Five numbers by colour (index colour − 1) as a record by the colours'
## words, `{black, blue, green, red, white}`, for the save.
static func _by_color(values: Array[int]) -> Dictionary:
	var out := {}
	for i in COLORS.size():
		out[COLORS[i]] = values[i]
	return out


static func _records(value: Variant) -> Array:
	var out: Array = []
	for item in _list(value):
		if item is Dictionary:
			out.append(_whole(item))
	return out


## The first three words of [param value] into [param into] (a deck's
## names or notes), the rest left as they are.
static func _read_three(into: Array[String], value: Variant) -> void:
	var saved := _list(value)
	for slot in mini(saved.size(), 3):
		into[slot] = _text(saved[slot])


## [param units] (world units, 32 to a tile) held to the map.
static func _on_map(units: int) -> int:
	return clampi(units, 0, ShandalarWorld.TILES * 32 - 1)


static func _is_site(slot: int, made: ShandalarWorld) -> bool:
	return slot >= 0 and slot < made.sites.size()


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


# ----------------------------------------------------- the save's file --

## The file [param kind] of this adventure is saved in.
func save_path(kind := AUTOSAVE) -> String:
	return saves_folder.path_join("%s.%s.json" % [adventure_id, kind])


## The kind of save the file at [param path] is, from its name:
## `autosave`, `slot01` … `slot10` ([SaveSlots]).
static func kind_of(path: String) -> String:
	return path.get_file().get_basename().get_extension()


## The copy of the save at [param path] kept from before it was last
## written ([method save]).
static func backup_path(path: String) -> String:
	return path + BACKUP_TAIL


## WRITE THE ADVENTURE to [param path] (the autosave by default): the path
## written, or "" when it could not be — and then the last good save is
## still there, whole (the file itself, or its `.bak`).
##
## WHOLE OR NOT AT ALL (campaign of 2026-10-23): the save was written over
## in place and the write never checked, so a disk that filled, or a limit
## on a file's size, left a cut-off file that no longer loaded — and the
## game said it had saved. Now
## - the save there now, when it is one this game reads, is first kept as
##   `<path>.bak` ([method _keep_backup]) — a damaged one is not, so it
##   never takes the place of an older good copy;
## - the new save goes through [method Settings.write_atomically]: written
##   aside, checked, and only then renamed over the old one (where a
##   platform will not rename over a file, it takes the old one away first
##   — the `.bak` is the good copy in that moment);
## - and it is read back: unless the file holds exactly what was written,
##   the save failed.
## Loading and the lists fall back to the `.bak` when the file itself
## cannot be read ([method load_from], [method save_at]). Only a slot's
## own file carries the slot's name ([member slot_name]).
func save(path := "") -> String:
	if path == "":
		path = save_path()
	if not _folder_ready(path.get_base_dir()):
		push_warning("AdventurePlayer: cannot make the folder of %s" % path)
		return ""
	var before := saved
	saved = Time.get_datetime_string_from_system(true) + "Z"
	var data := to_dict()
	if SaveSlots.slot_of(kind_of(path)) == 0:
		(data["adventure"] as Dictionary)["slot_name"] = ""
	var bytes := JSON.stringify(data, "\t").to_utf8_buffer()
	_keep_backup(path)
	if Settings.write_atomically(path, bytes) != OK or _bytes_at(path) != bytes:
		saved = before
		push_warning("AdventurePlayer: cannot write %s" % path)
		return ""
	_remember(path, bytes, data)
	return path


## THE AUTOSAVE, written when the adventure begins.
func autosave() -> String:
	return save(save_path(AUTOSAVE))


## Whether [param folder] is there, or is made now. A file standing where
## a folder of the way should be fails it quietly (the engine prints an
## error for a folder it cannot make).
static func _folder_ready(folder: String) -> bool:
	var at := folder
	while not DirAccess.dir_exists_absolute(at):
		if FileAccess.file_exists(at):
			return false
		var up := at.get_base_dir()
		if up == at or up == "":
			break
		at = up
	return DirAccess.dir_exists_absolute(folder) or DirAccess.make_dir_recursive_absolute(folder) == OK


## The save at [param path] copied whole to its `.bak` ([method
## backup_path]) — when it is a save this game reads.
static func _keep_backup(path: String) -> void:
	var bytes := _bytes_at(path)
	if not _entry_of(path, bytes).is_empty():
		Settings.write_atomically(backup_path(path), bytes)


# ------------------------------------------------------ reading saves --

## How many save files have been parsed this session — for the tests that
## hold the lists to reading a file once ([method scan_saves]).
static var files_parsed := 0
## WHAT EACH SAVE FILE HOLDS, by path, with the bytes it was read from:
## `{stamp: [size, hash of the bytes], entry}` — its line in the lists
## ([method _summary]), `{}` when it could not be read. A file is parsed
## again only when its bytes changed (campaign of 2026-10-23: the lists
## parsed every save in full each time — the save list on opening, on
## picking a slot and on saving; 34 long saves, a tenth of a second a
## click). Reading and hashing a file costs a hundredth of parsing it.
static var _read := {}


## Forget what the save files held (a test; they are read again).
static func forget_saves() -> void:
	_read.clear()


## The adventure saved at [param path] — or, when that file cannot be read,
## at its `.bak` ([method save]) — or null.
static func load_from(path: String) -> AdventurePlayer:
	for candidate in [path, backup_path(path)]:
		var bytes := _bytes_at(candidate)
		var data := _data_of(bytes)
		if not data.is_empty():
			_remember(candidate, bytes, data)
			return from_dict(data)
	return null


## THE SAVE AT [param path] as the lists show it: `{path, kind, slot,
## slot_name, days, gold, id, name, color, difficulty, saved, seed_text,
## ended, score, life_rule, at_door}`
## — from its `.bak` when the file itself cannot be read; `{path,
## unreadable: true}` when neither can; `{}` when there is no save there.
static func save_at(path: String) -> Dictionary:
	var entry := _entry_of(path, _bytes_at(path))
	if entry.is_empty():
		entry = _entry_of(backup_path(path), _bytes_at(backup_path(path)))
	if entry.is_empty():
		if FileAccess.file_exists(path) or FileAccess.file_exists(backup_path(path)):
			return {"path": path, "unreadable": true}
		return {}
	var out := entry.duplicate()
	out.merge({"path": path, "kind": kind_of(path), "slot": SaveSlots.slot_of(kind_of(path))}, true)
	return out


## THE SAVES IN [param folder] ([member saves_folder] by default):
## `{saves, unreadable}` — the saves this game reads, newest first, as
## [method save_at] gives them, and how many save files could not be read
## (damaged, or from a newer version of the game).
##
## ONE ODD FILE HIDES NOTHING ELSE (campaign of 2026-10-23: a save whose
## hero was a word stopped the list with a script error, and every
## adventure vanished from the load screen). A save is `<id>.autosave.json`
## or `<id>.slot01.json` … `<id>.slot10.json` (with its `.bak`); any other
## file is not looked at. When two files claim one adventure's slot (a
## copy kept in the folder), the one by the adventure's own name is shown.
static func scan_saves(folder := "") -> Dictionary:
	if folder == "":
		folder = saves_folder
	var saves: Array[Dictionary] = []
	var unreadable := 0
	var dir := DirAccess.open(folder)
	if dir == null:
		return {"saves": saves, "unreadable": 0}
	var files := {}
	for file_name in dir.get_files():
		var main := file_name.trim_suffix(BACKUP_TAIL)
		if main.ends_with(".json") and (_kept_kind(kind_of(main)) or kind_of(main) == SaveSlots.LEGACY):
			files[main] = true
	var by_slot := {}
	for main: String in files:
		var save := save_at(folder.path_join(main))
		if save.get("unreadable", false):
			unreadable += 1
		elif not save.is_empty() and _kept_kind(String(save["kind"])):
			var key := "%s|%s" % [save["id"], save["kind"]]
			if not by_slot.has(key) or _shown_before(save, by_slot[key]):
				by_slot[key] = save
	for key in by_slot:
		saves.append(by_slot[key])
	saves.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return String(a["saved"]) > String(b["saved"]))
	return {"saves": saves, "unreadable": unreadable}


## The saved adventures, newest first ([method scan_saves]).
static func list_saves(folder := "") -> Array[Dictionary]:
	return scan_saves(folder)["saves"]


## Whether a file of kind [param file_kind] is a save the lists show: the
## autosave and the ten slots. (An older `save` waits for [method
## SaveSlots.migrate]; it is counted when it cannot be read.)
static func _kept_kind(file_kind: String) -> bool:
	return file_kind == AUTOSAVE or (file_kind.begins_with("slot")
		and SaveSlots.kind(SaveSlots.slot_of(file_kind)) == file_kind)


## Whether [param save] is shown rather than [param other], which claims
## the same adventure's slot: the file by the adventure's own name first,
## then the newer.
static func _shown_before(save: Dictionary, other: Dictionary) -> bool:
	var own := func(s: Dictionary) -> bool:
		return String(s["path"]).get_file() == "%s.%s.json" % [s["id"], s["kind"]]
	if own.call(save) != own.call(other):
		return own.call(save)
	return String(save["saved"]) > String(other["saved"])


## The line in the lists for [param bytes], the file at [param path] —
## known when its bytes are those last read, else parsed and kept.
static func _entry_of(path: String, bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		_read.erase(path)
		return {}
	var known: Dictionary = _read.get(path, {})
	if known.get("stamp", []) == [bytes.size(), hash(bytes)]:
		return known["entry"]
	return _remember(path, bytes, _data_of(bytes))


## Keep what the file at [param path] holds — [param data], read from
## [param bytes] — and give its line in the lists.
static func _remember(path: String, bytes: PackedByteArray, data: Dictionary) -> Dictionary:
	var entry := _summary(data) if not data.is_empty() else {}
	_read[path] = {"stamp": [bytes.size(), hash(bytes)], "entry": entry}
	return entry


## A save's line in the lists, from [param data] (a [method readable]
## save): `{slot_name, days, gold, id, name, color, difficulty, saved,
## seed_text, ended, score, life_rule, at_door}` — `ended` "" while the
## adventure goes on, "won" or "failed" ([member ended]); `score` a won
## adventure's years, else 0 (part C: the load list shows a won adventure
## with its score, a failed one as failed); `at_door` the door mark as the
## load reads it ([method door_mark]) — under "One life" a battle begun,
## which the load settles as lost (part C stage C3, h3-2).
static func _summary(data: Dictionary) -> Dictionary:
	var game: Dictionary = data["adventure"]
	var hero: Dictionary = data["hero"]
	var end := _object(data.get("end"))
	var how := _text(end.get("ended"))
	how = how if how in ENDINGS else ""
	var final_saved := _final_record(end.get("final"))
	var beaten := _texts(_object(data.get("record")).get("defeated_wizards"), COLORS)
	var wizards := {}
	for key in beaten:
		wizards[key] = true
	return {"slot_name": _text(game.get("slot_name")),
		"days": _count((data["clocks"] as Dictionary).get("quest_timer")) / WorldStatus.DAY,
		"gold": _count((data["carried"] as Dictionary).get("gold")),
		"id": _text(game.get("id")), "name": _text(hero.get("name")),
		"color": _text(hero.get("color")), "difficulty": clampi(_number(hero.get("difficulty")), 0, 3),
		"saved": _text(game.get("saved")),
		"seed_text": _text((data["world"] as Dictionary).get("seed_text")),
		"ended": how, "score": int(final_saved.get("score", 0)) if how == ENDED_WON else 0,
		"life_rule": life_rule_of(hero.get("life_rule")),
		"at_door": door_mark(end.get("at_door"), how, wizards.size())}


## The bytes of the file at [param path], empty when there is none.
static func _bytes_at(path: String) -> PackedByteArray:
	if not FileAccess.file_exists(path):
		return PackedByteArray()
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return PackedByteArray()
	var bytes := file.get_buffer(file.get_length())
	file.close()
	return bytes


## The save [param bytes] hold, `{}` when they are not one this game reads
## ([method readable]). Quietly: a damaged file is an answer here, not an
## error line.
static func _data_of(bytes: PackedByteArray) -> Dictionary:
	if bytes.is_empty():
		return {}
	files_parsed += 1
	var json := JSON.new()
	if json.parse(bytes.get_string_from_utf8()) != OK:
		return {}
	return json.data if readable(json.data) else {}


# ------------------------------------------------------- the save's time --

## [param utc] — a save's time as it is kept, `2026-10-23T09:07:00Z` — as
## the player's clock shows it, `2026-10-23 11:07` (campaign of
## 2026-10-23: the lists showed the UTC time as if it were the local one).
## Godot reads the zone's offset only as it stands now, so a save from the
## other side of a summer-time change shows an hour off.
static func local_time(utc: String) -> String:
	return time_at(utc, int(Time.get_time_zone_from_system().get("bias", 0)))


## [param utc] on a clock [param bias_minutes] ahead of UTC; a time not in
## the save's form as it is written, "" for "".
static func time_at(utc: String, bias_minutes: int) -> String:
	var plain := utc.trim_suffix("Z")
	if not _iso_time(plain):
		return plain.replace("T", " ").left(16)
	var unix := Time.get_unix_time_from_datetime_string(plain)
	return Time.get_datetime_string_from_unix_time(unix + bias_minutes * 60, true).left(16)


## Whether [param text] is `YYYY-MM-DDTHH:MM:SS`.
static func _iso_time(text: String) -> bool:
	if text.length() != 19 or text[4] != "-" or text[7] != "-" or text[10] != "T" \
			or text[13] != ":" or text[16] != ":":
		return false
	for at in [0, 5, 8, 11, 14, 17]:
		var digits := text.substr(at, 4 if at == 0 else 2)
		if not digits.is_valid_int() or digits.begins_with("-") or digits.begins_with("+"):
			return false
	return true
