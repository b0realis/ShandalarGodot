# Last Refuge quest and lore audit

Branch: `2nd_pack`. Scope: the island's reachable stories, assignments,
rewards and transitions, including the shared Shandalar encounters it reuses.
This is a prototype audit, not a release or a full campaign balance study.

## Lore boundary

Fallen Empires describes Sarpadia on Dominaria. The faction conflicts are
grounded in Wizards' [Faction Packed](https://magic.wizards.com/en/news/making-magic/faction-packed-2018-10-15).
The Last Refuge, its crossing, communities and Ebon Crown are original game
fiction. The ship sails between two places on Shandalar; it does not sail to
Dominaria or through the Great Barrier. The optional dungeon holds keepsakes,
not a working portal. The imagined crossing is undated and predates the Barrier.

The five petitions explore alternatives to the old conflicts: bread without
zealotry, a shared coast, freedom for thrulls, a shared mountain road, and a
tended boundary between elves and thallids. Each has a distinct aftermath.
The green antagonist is now a sporekeeper, matching the fungus deck actually
played, instead of a firekeeper with no fire spells.

## Reachable content

| Place or encounter | Assignment or story | Completion and relationship to the island quest |
| --- | --- | --- |
| Sarpadian Anchorage / Refuge Harbor | Refugees' history, the voyage and current progress | Free travel both ways; pending rewards remain safe; post-liberation dialogue recognizes the victory. |
| Leitbur's Rest — The Bread Road | Deliver the grain warrant to Refuge Harbor, then defeat the collector | Open the harvest road; white community pledge. |
| Vodalian Haven — A Harbor for Both Peoples | Survey the shared channel, then defeat the captain | Restore shared channels; blue community pledge. |
| Freehold of the Hand — No More Masters | Defeat the Pit Overseer | Defend free thrulls; black community pledge. |
| Dwarven Hearth — The Mountain Road | Seek and defeat the raider in an island village | Reopen the shared pass; red community pledge. |
| Havenwood — Room to Grow | Defeat the Crown's Sporekeeper | Restore the living border; green community pledge. |
| Castle of the Ebon Crown | Five pledges and at least 50% Fallen Empires nonland copies in the main deck | Defeat the lord to unlock Fallen Empires mainland stock, trades and ordinary rewards. Does not finish Shandalar's main quest. |
| Vaults of the First Crossing | Optional dungeon, with rooms, riddles, treasure, duels and clues | No pledge; no prerequisite for the lord. Its entrance can move when leaving. |
| Villages, towns and cities | Letters for links or amulets, card deliveries and creature hunts | Ordinary local rewards and deadlines; no pledge. These errands remain separate from mainland errands. |
| Wise men | Seven regional tales, community news, local links and World Magic sellers | Existing gifts: tales, clues, life/food, deck information, a companion or a card copy. |
| Roaming creatures | Challenges, tribute, clues and ordinary hunt targets | Independent of mainland wizard-castle allegiances. Danger remains after liberation. |
| Treasure sites | A basic land or a card of the site's color/colorless | Fallen Empires cards join the eligible regional pool. |
| Ruined Tower / Loremaster's Tower | A local dungeon clue or a card riddle | Existing clue and riddle rewards, without a nonexistent island wizard castle. |
| Thieves Hideout / Lost City of El'Akram | Luck or theft; gold, amulets and rare cards | Existing risk/reward rules. |
| Nomad's Bazaar / Gemcutter's Guild / Diamond Mine | Cards for gold, gold for amulets, cards for amulets | Existing shops and trades, respecting the regional card pool. |
| Abandoned Shrine / Dragon's Lair / Hall of the Sultan / Spectral Arena | Optional lair battles | Existing battle effects and hoards; no pledge. |
| Pyramids of Aska-tet / Guardian's Ghost / Oasis of Muldoon | Riddle, deck knowledge, or a card traded for next-duel life | Existing services; no pledge. |

The fourteen random lairs retain the original game's names and mechanics.
They are familiar encounters on this new map, not assertions that those named
places were part of historical Sarpadia. Friendly services exist in settlements
and lairs; dedicated friendly roaming characters have not been added.

## Corrections

- Island wise men previously reused mainland wizard news and praise. They now
  have seven local tales, Crown/progress news and regional gift dialogue.
  Roaming encounters also stop claiming allegiance to mainland strongholds.
- Community and castle panels explain stakes, retries and rewards. Only the
  lord requires a Fallen Empires deck; pledges have no deadline or percentage
  requirement. The liberated castle no longer displays an unmet challenge gate.
- Pledge battles now use the adventure's temporary basic-land padding. Empty
  decks, missing cards and a disabled Pack 2 receive a reason instead of an
  unusable challenge. Existing next-duel gifts and playmats carry through.
- The blue encounter now has eighteen lands and two Deep Spawn, instead of
  sixteen lands and four eight-mana finishers.
- Ordinary treasure and lair rare/hoard draws now include the regional Fallen
  Empires pool. A shared cache cannot leak that unlock into another campaign.
- Damaged regional saves are rejected if the active/inactive region identities
  disagree, the harbor/castle or a community is missing, or liberation lacks its
  five pledges. JSON round-trips preserve valid maps. Inactive mainland mana links are
  counted from actual settlement statuses rather than a cached total. Island
  links, including old prototype flags, do not contribute life.
- Empty reserved site slots no longer count as valid ordinary quest destinations.
- Battle results name the opponent, distinguish new awards from already-held
  rewards and restore adventure music. Losses and draws grant no pledge or loot.
- The expansion's pack service is resolved at runtime. Its direct autoload
  reference previously caused compile errors when standalone tools such as
  DeckLab loaded adventure types before autoload identifiers existed.

## Modular-region revision

Shared travel now separates active and saved maps from expansion progress.
Quickening, cumulative days, lairs and siege totals travel with the hero;
regional deadlines and restock clocks stay local. First-entry treasures pass the
same ban filter as reloaded treasures. Save version 4 counters migrate once to
version 5. JSON pledge numbers are normalized before membership checks.

Bread Road now includes a harbor delivery, the harbor pact a channel survey,
and Mountain Road a confrontation in a village. The other two petitions remain
local duels. All five can progress independently. Map guidance follows their
current stages, and short colored journal clues preserve the directions.

Pledge rewards are now 6 cards of a chosen color, 40 gold and 8 food,
once per pledge. No island reward grants a mana link. Five victories provide 30 chosen cards, 200 gold and 40
food; older promised cards remain owed. The final 50% nonland gate is unchanged.
New maps have three World Magic sellers; existing layouts are preserved. Early
five-community islands use the harbor for the channel survey and Dwarven Hearth
for the raider, so every pledge remains reachable without regenerating the map.

Opposition uses fixed curated lists independent of reward bundles. The red
list has twelve cheap goblins for four Grenades and one Warrens. Commanders
have 26–30 life and the lord 36. Roamers below tier 12 become tier 12, except
an ordinary hunt's named creature. All four standard profiles remain fair.

## Verification

The earlier 12-game Big Green smoke run covered the previous encounter lists;
it is not evidence of the new lists' balance. The current revision is checked
with focused save, travel, availability, progression and UI tests and a separate
bounded encounter study. The shared regression run passed 145 tests / 23,164
assertions across twelve scripts. The final UI run passed all 14 tests / 119
assertions with no errors or orphan controls; the subsequent legacy-objective
and journey check passed 17 tests / 423 assertions. Two games through the live
duel screen also finished cleanly (demo and simulated human seat, seed 48271).
Native source-scene captures checked the original skin at 960×640 and the
upscaled skin at 800×600. Region tests include nine saved
maps, nine coastal entry requests, shared anchorages, pack loss, JSON migration,
first-entry bans and unchanged mainland state. This tests reusable capacity;
only the Last Refuge is currently implemented as playable expansion content.

The encounter study played 144 complete games with fair Wizard pilots, the
adventure opening and mulligan, and the modern rules with mana burn. Each hero
example faced all five commanders and the lord for eight games apiece, using
seeds 48271–48278. There were no stalls or script errors.

| Hero example | Starting life | Wins across 48 games |
| --- | ---: | ---: |
| Generated green Wizard starter, seed 48271, 46 cards | 10 | 6 |
| Bundled Big Green, 40 cards | 20 | 32 |
| Prepared white deck, 40 cards, 12 of 24 nonlands from Fallen Empires | 30 | 46 |

The prepared list was 16 Plains; four each of Order of Leitbur, Icatian
Javelineers and Icatian Infantry; three each of Serra Angel, Swords to
Plowshares, Crusade and Disenchant. That earlier sample combined changes in deck and life, so it cannot separate
their contributions and is not a general win-rate estimate. No rating data was changed.
Human campaign playtesting remains necessary to judge travel pacing and
difficulty over an entire adventure.


## Tasks and development-tool revision

The Tasks tab derives active goals separately from journal history and saves
its selected ID. Stage changes move its guide; other-region goals point toward
the ship. Known clue facts survive journal trimming. No direction is invented
for a roaming hunt. Deadline text refreshes on the quest's own boundary.
Channel surveys select a coastal settlement outside the five communities;
raiders use a road village near mountains. Old five-town islands fall back to
the harbor and Dwarven Hearth without moving saved geography.

Only mana links are removed from island rewards. World Magics, amulets, other
rewards, gold, food and trade retain their behavior. Old link errands become
amulet rewards. Ordinary card and hunt rewards cannot create links either.
Community pennants and the liberated castle's gold flag are cached map marks;
no new animation loop or illustration pack is required.

Regional roaming decks use fixed world/slot choices. Their ante and tribute
spells match the actual deck. Named hunts, summoners and deck-swap meetings
retain their original decks. The lord's revised deck emphasizes thrull
sacrifice and Soul Exchange. The standard difficulty profiles stay fair.

A second, opt-in development island has three beacons and no castle, pledge
schema or artwork. It exercises the same descriptors, travel, tasks and saves.
The new `expansion_lab.sh` checks both regions on seeds 5, 37 and 48271: five
round trips per scenario, including disabled-pack returns, completed without
failures. It records save size, elapsed time and live-fixture memory delta;
the latter is a measurement with the current fixture still alive, not a leak
test. Normal gameplay never registers this island.

The crossed battle baseline ran 72 complete games: two hero decks, each at
10, 20 and 30 life, against all five commanders and the lord, twice each.
Fair Wizard pilots used modern rules with mana burn and the adventure mulligan.
Hero deck and starting life were varied independently. No games stalled and
no rating ledger was written. These isolated duels do not simulate campaign
travel, reward acquisition or the final deck gate.

| Hero deck | 10 life | 20 life | 30 life |
| --- | ---: | ---: | ---: |
| Green baseline | 4/12 | 6/12 | 8/12 |
| Tuned white | 6/12 | 8/12 | 10/12 |

The small sample gives a useful playtest baseline, not a precise balance
estimate. The toolkit preserves seeds and per-game outcomes for repeat studies.

Verification for this revision: 95 distinct targeted tests across nine scripts
passed (the last affected subset: 28/28); both live-screen duel modes finished
on seed 48271. Native source-scene captures at 1280×800 verified Tasks and
victory markers in original and 2× skins. These are staged fixtures, not an
exported build or a claim of a completed human campaign playtest.
