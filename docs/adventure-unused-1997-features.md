# The 1997 adventure's designed, never-used features

The owner's ruling for the creatures and their duels (2026-10-23): *"1997 as
played but fix clear slips to what was obviously meant. Each fix marked. But
document abundantly all designed features, world magic life bonuses,
strength-based hand sizes, creature names on the map, and all other hidden
not used features so they can be implemented later. Comment also how each of
these features can change the game!"*

So the game plays as 1997 played. This page lists everything the 1997 program
**computed, loaded or laid out but never let take effect** — features its
designers built and the shipped game never showed — so each can be switched
on later, on purpose, knowing what it would do. The clear *slips* (a wrong
colour, a lost card on Escape) are not here: they are fixed and listed in
`docs/adventure-implementation-notes.md`.

Sources are cited by file and function in the 1.3 decompilation
(`src/shandalar/src/` and `src/magic/src/`), with the retail build where it
agrees; the decompilations are described, never copied. "Ours" names where the
feature would be switched on in this project's code.

Each entry: **What 1997 computed** · **Why it never took effect** · **What it
would change** · **How to switch it on**.

---

## 1. The hero's life: a base of 10 and the World Magics' bonuses

- **What 1997 computed.** `play_duel`'s Shandalar branch (duel.c:2205-2226,
  retail Kimpic.c:19685-19697) starts the hero's life at 10, adds 2 for
  Haggler's Coin, 3 for Ring of the Guardian and 5 for Fruit of Sustenance —
  and then **assigns** the life again from the mana links: linked, unruled
  towns and cities, plus the next-duel bonuses.
- **Why it never took effect.** The second assignment overwrites the first; in
  both builds.
- **What it would change.** Every duel would start 10 life higher (more with
  the World Magics), so the mana links would matter far less: losing a town
  to a siege would still cost one life, but out of a far larger total; the
  early game would be much easier (a new hero with 10 links would start at 20, not 10), and the
  three World Magics would become life items — Fruit of Sustenance and Ring of
  the Guardian especially would be bought for duels, not only for food and
  sieges. The 1997 manual's descriptions of these World Magics should be read
  before choosing whether to switch it on.
- **How to switch it on.** One place: the hero's starting life for an
  adventure duel (the meeting's hand-off, `CreatureMeeting.hero_life`) adds
  the base and the bonuses before the links. A setting, off by default.

## 2. Hand sizes by the creature's strength

- **What 1997 computed.** The opening hand size from the creature's strength
  and the hand modifier (duel.c:2289-2300; retail Kimpic.c:19750-19751).
- **Why it never took effect.** Both sides' hand sizes are overwritten with 7.
- **What it would change.** Strong creatures would draw more cards than the
  hero and weak ones fewer; with the modifier `−clamp(3 − wins/3, 0, 3)`, a
  new hero would face smaller opening hands from the creatures until their
  wins mount — a gentle opening curve that hardens as the hero grows.
- **How to switch it on.** The meeting's duel set-up passes a hand size per
  seat to the duel (a DuelConfig field) instead of 7.

## 3. The first move by difficulty

- **What 1997 computed.** A first player chosen by the difficulty before the
  duel (duel.c:2302-2325; the choice itself at 2307-2314): on Apprentice the
  hero moves first, on every other level a fair `rand(2)`.
- **Why it never took effect.** `coin_flip` throws it away and tosses a fair
  coin (`rand() % 2`, duel_engine_coin_flip.c).
- **What it would change.** An Apprentice would always move first (a tempo
  edge worth roughly a card); the other levels would play as they do now.
- **How to switch it on.** The meeting's duel set-up forces `first_player`
  by the difficulty table instead of leaving the toss.

## 4. The hero moving first against a creature that starts with a card

- **What 1997 computed.** When the creature starts its duel with its reward
  card in play, the code marks the hero to move first (duel.c:2502-2526).
- **Why it never took effect.** It is set after the first player was already
  decided.
- **What it would change.** The creature's head start (its card in play) would
  be balanced by the hero's first turn.
- **How to switch it on.** In the meeting's set-up, `first_player = hero` when
  the creature has a card in play.

## 5. Creature names on the map

- **What 1997 computed.** In eight ticks of every 32, slot by slot, the
  drawing copies the creature's name into the message buffer (adventureWorldUi.c:2280-2284); creatures with
  the DISGUISE flag (0x002: Necromancer, Shapeshifter, Summoner) cycle the
  name shown through the rows below their own (`row − ((T >> 5) & 3)`,
  every 32 ticks): a Necromancer (row 6) would read as Necromancer, Nether
  Fiend, VampireLord, Warlock in turn; a Shapeshifter (19) as Shapeshifter,
  Sea Dragon, Conjurer, Merfolk Shaman; a Summoner (27) as Summoner,
  Beastmaster, Forest Dragon, Enchantress.
- **Why it never took effect.** Nothing draws that buffer.
- **What it would change.** The player would know which creature approaches
  before meeting it — and the three disguised ones would deceive: a
  Shapeshifter announced as a Conjurer. Knowing the creature lets the player
  flee strong ones or seek the quest's.
- **How to switch it on.** The world screen's place-name tip already follows
  the pointer; a creature under the pointer (or near the hero) would show its
  name — the disguised row's name for the three DISGUISE creatures. Also the
  lurk test of §7 reads the disguised row.

## 6. The creatures' range and speed

- **What 1997 computed.** Per creature kind a "range" (32/48/64/96 × 3/2,
  doubled for flag 0x200, halved unless it is the nearest creature) and a
  "speed" — doubled once for every halving of the distance needed to bring
  the creature inside its range (so a far creature would hurry,
  world_lair_monster_slots.c:709-713), halved on the terrains its flags name
  (§7; 770-780) — (636-714; retail glue_adventure.c 1251-1352), and the
  nearest-slot search feeding them (361-375).
- **Why it never took effect.** Neither value is read: every creature steers
  at the hero every tick at its fixed stride (1, or 2 when fast or a flyer).
- **What it would change.** Creatures would only notice the hero within their
  range — a wanderer far off would keep wandering — far ones would close in
  fast, and some would be slowed on certain lands (§7): the world would have
  quiet stretches and dangerous ones, and outrunning a creature would depend
  on the land, not only the road.
- **How to switch it on.** `WorldCreatures`' movement step: steer at the hero
  only inside the kind's range, wander otherwise; scale the stride by the
  terrain speed.

## 7. Slow on some lands (flags 0x008–0x080) and flag 0x200

- **What 1997 computed.** Flag bits tested against the land's colours
  (`flags & (tile_mask << 3)`, world_lair_monster_slots.c:770-780): the speed
  halved on land of the colours they name — mostly NOT the creature's own:
  Merfolk Shaman black land, Sedge Beast green, Elementalist black and green,
  Centaur Shaman blue (its 0x08 bit matches no terrain), Centaur Warchief red
  (its own), Ape Lord blue (no land it may stand on is blue, so never). And
  0x200 doubling the range (Undead Knight, Crusader, Sea Dragon, Elvish Magi,
  Forest Dragon, Hydra, Centaur Warchief, Lord of Fate, the five dragons).
- **Why it never took effect.** They only change the dead `speed`/`range`
  of §6.
- **What it would change.** With §6 on: these creatures would be slowed on the
  lands named above (a Merfolk Shaman wading black swamps, a Sedge Beast in
  green forest), or wider-ranging, giving each its own feel.
- **How to switch it on.** With §6, in `WorldCreatures`' step.

## 8. The rules filter of the creature decks (.vFAST, .vLARGE, .vDIRECT, .vARTIFACT)

- **What 1997 computed.** The deck loader understands speed sections
  (.vFAST/.vLARGE/.vDIRECT/.vARTIFACT → speeds 0/1/2/6), the encounter learns
  the hero's "speed" after a win (`rand(128/(d+1)) < strength`,
  world_lair_monster_encounter.c:2638-2645) and passes it to the loader.
- **Why it never took effect.** No shipped deck file has a speed section, and
  the learned speed is never saved.
- **What it would change.** Creature decks could carry answers to the hero's
  style (fast aggro, big creatures, direct damage, artifacts) and learn them,
  as they learn the hero's colours.
- **How to switch it on.** Speed sections in the deck data (`CreatureDeck`),
  the learned speed saved beside the learned colours.

## 9. Pre-duel flag 0x020 (Thought Invoker) and byte 0x0e of the creature table

- **What 1997 computed.** Thought Invoker's pre-duel flags carry 0x020; every
  row has a byte at offset 0x0e (values 01–80 on nineteen rows).
- **Why it never took effect.** No reader in 1.3 or retail.
- **What it would change.** Unknown — they look like reserved hooks (another
  pre-duel event; a per-creature setting). Kept as data.
- **How to switch it on.** Give them a meaning first.

## 10. The "%s ANTE" caption

- **What 1997 computed.** @ENCOUNTER_PREDUEL[2] "%s ANTE" formatted for the
  meeting screen (world_lair_monster_encounter.c).
- **Why it never took effect.** Overwritten before it is drawn; the plaques say
  "Opponent Ante" and "Your Ante".
- **What it would change.** The creature's plaque would name it ("Witch ANTE").
- **How to switch it on.** The meeting pane's plaque text.

## 11. The duplicate reward in the random reward

- **What 1997 computed.** A creature with no reward of its own, on a special
  meeting with no amulet won, gives `(1 << rand(12)) & 0x1A19` — a mask that
  holds the duplicate reward (0x1000: a copy of one of your own cards)
  (world_lair_monster_encounter.c:2416-2454).
- **Why it never took effect.** `1 << rand(12)` reaches bit 11 at most;
  0x1000 is bit 12.
- **What it would change.** One random reward in six would be a copy of a
  card of your choosing — the strongest of them, so a little more power from
  ordinary meetings.
- **How to switch it on.** Draw `rand(13)` for the random reward
  (`CreatureBook.REWARD_RANDOM`, the spoils' random reward).

## 12. The henchmen's and the castle wizards' spoils

- **What 1997 computed.** The henchmen (Necromancer, High Priest, Thought
  Invoker, Summoner, War Mage) and the castle wizards carry reward flags and
  reward cards in the creature table (Necromancer: an artifact; Summoner: a
  card in play next duel; the castle wizards: any card).
- **Why it never took effect.** The spoils are paid only to kinds below 11
  (the reward block is skipped for henchmen and castle wizards).
- **What it would change.** Beating a wizard's most trusted servant would pay
  like any other creature's defeat — and more, since their strength would
  count; the castle wizards would add a card of the hero's choice.
- **How to switch it on.** Let the spoils run for kinds 11 and 12
  (`CreatureBook.gives_spoils`).

## 13. The creature decks' .vNone section

- **What 1997 computed.** Every creature deck file marks a `.vNone` section
  (cards played when the deck is read with filter bit 0x01).
- **Why it never took effect in the adventure.** No meeting reads with bit
  0x01: only the title screen's demo duels did. A creature plays its maindeck
  and, once it has learned the hero's colours, those colours' sections
  (owner ruling: exact 1997).
- **What it would change.** Creatures would carry two to five more cards from
  the start — their decks a little stronger and more varied before they learn
  the hero's colours.
- **How to switch it on.** `CreatureDeck.for_meeting` keeping bit 0x01.

## 14. A deck line counting "the difficulty"

- **What 1997 computed.** A creature deck line with a count of 0 means "as
  many as the difficulty" (the deck loader, visitLocation.c:2320-2526).
- **Why it never took effect.** No shipped deck file has a count of 0 — and
  both builds store the 0 into the library before the difficulty is put in
  its place (1.3 `ParseDeckFileIntoInitialLibrary`; retail database.c
  1233-1237); the difficulty only feeds the basic-land trim, so even a deck
  file using it would load no copies.
- **What it would change.** Deck designers could make creatures stronger on
  the harder levels card by card.
- **How to switch it on.** `CreatureDeck`'s parser storing the difficulty
  for a count of 0 (and a deck file that uses it).

## 15. A bribe paid with one amulet

- **What 1997 laid out.** @ENCOUNTER_PREDUEL[14] " Pay 1 %s." — a meeting's
  option to pay the creature one amulet (of its colour) instead of gold.
- **Why it never took effect.** No line of 1.3 reads it: the meeting offers
  only Pay %d gold (world_lair_monster_encounter.c:1815).
- **What it would change.** Amulets would buy a way past a creature when gold
  runs short — amulets would become a currency for safe travel, not only for
  trades and the wise man.
- **How to switch it on.** `CreatureMeeting` (`PAY_AMULET`): offer the
  option beside Pay gold when the hero holds an amulet of the creature's
  colour; paying takes it and ends the meeting.

## 16. Gendered words for the wizards and their creatures

- **What 1997 laid out.** The ruled town's lines (`@VISIT` 2–7), the
  meeting's (`@ENCOUNTER_PREDUEL`), the news flashes' (`@NEWSFLASH` 2/3,
  4/5), the end's (`@QUESTFAILED` 2/3) and the quest rewards' (`@VISIT`
  21/22, 26/27) come in pairs, one chosen by the wizard's gender
  (`IsWizardColorFeminine`), one by the creature's
  (`IsCreatureTypeFeminine`).
- **Why it never took effect.** Each pair holds the same words: the choice
  is made and changes nothing.
- **What it would change.** The towns and creatures would speak of the
  wizard and the creature as the people they are ("…duel this Witch, she
  …") — flavour, no rule.
- **How to switch it on.** Give the pairs their second, feminine wording
  (`RuledTowns.RULED_WORDS` / `FREE_WORDS`, the meeting's words), chosen by
  `CreatureMeeting.wizard_feminine` and `CreatureBook.feminine`.

## 17. The ruled town's guardian in roaming slot 6

- **What 1997 computed.** As a ruled town's duel is chosen, 1997 writes the
  creature's row and the wizard's colour into roaming slot 6
  (visitLocation.c:4312–4313).
- **Why it never took effect.** The duel does not read them; the slot has no
  place on the map — its stale place is (0, 0), the sea, so the slot loop
  (world_lair_monster_slots.c:382) empties it on the next tick.
- **What it would change.** Perhaps the beaten guardian was to roam out of the
  freed town, or count as a roaming win (towards tributes and the creatures'
  fear of the hero).
- **How to switch it on.** Give slot 6 a place (the town's tile) and a
  meaning in `WorldCreatures`; or log the town's duel as a victory.

## 18. The duel's strength and colour for lair and town duels

- **What 1997 computed.** Lair and ruled-town duels set the creature's
  strength (3) and colour, and every caller passes the creature's signature
  card id to the deck loader.
- **Why it never took effect.** The strength feeds only the dead hand size
  (§2); the loader ignores the signature card id.
- **What it would change.** With §2 on, these duels' opening hands would
  follow that strength.
- **How to switch it on.** With §2, in `LairDuels` / `RuledTowns`
  `duel_config`.

## 19. A town's creature-quest reward counted in cards

- **What 1997 computed.** At a town or city, the creature quest's reward is
  counted as a village's is — `tier / 7 + 1` (1 to 3) — (visitLocation.c
  4495).
- **Why it never took effect.** A village pays that many amulets; a town or
  city gives one card of its wares whatever the count.
- **What it would change.** Hard creature quests from towns would pay two or
  three cards of the town's wares — towns' quests worth as much as villages'.
- **How to switch it on.** `Quests.complete_at`: open the town's free pick
  that many times (`Quests.reward_amulets` already counts it).

## 20. A seventh roaming creature on the harder levels

- **What 1997 laid out.** The roaming spawn's Apprentice gate
  (world_lair_monster_slots.c:522-523) names slot 6 — for Apprentice and
  Magician — inside a branch only slots 0–5 ever reach.
- **Why it never took effect.** Slot 6 is never refilled: the loop fills only
  slots 0–5 (6 is the ruled town's scratch, §17; 7 the siege's).
- **What it would change.** Read as meant, Sorcerer and Wizard would have a
  seventh creature roaming round the hero — more meetings, a harder road.
- **How to switch it on.** `WorldCreatures`' refill over slots 0–6 on
  Sorcerer and Wizard, slot 6 gated off below (and §17's scratch moved).

---

*This page grows as the creatures, their duels, the castles and the dungeons
are built: each builder adds what it meets.*
