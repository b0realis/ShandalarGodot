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
| Leitbur's Rest — The Bread Road | Defeat the Ebon Crown Tithe-Collector | Open the harvest road; white community pledge. |
| Vodalian Haven — A Harbor for Both Peoples | Defeat the Blockade Captain | Restore shared channels; blue community pledge. |
| Freehold of the Hand — No More Masters | Defeat the Pit Overseer | Defend free thrulls; black community pledge. |
| Dwarven Hearth — The Mountain Road | Defeat the Tribute-Raider | Reopen the shared pass; red community pledge. |
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
  five pledges. JSON round-trips preserve valid maps. Inactive mana links are
  counted from actual settlement statuses rather than a cached total.
- Empty reserved site slots no longer count as valid ordinary quest destinations.
- Battle results name the opponent, distinguish new awards from already-held
  rewards and restore adventure music. Losses and draws grant no pledge or loot.
- The expansion's pack service is resolved at runtime. Its direct autoload
  reference previously caused compile errors when standalone tools such as
  DeckLab loaded adventure types before autoload identifiers existed.

## Verification

The targeted GUT run passed **87 tests across 10 scripts**, with **9,410
assertions**. It includes all four adventure difficulty settings, next-duel
gifts, no ante, missing packs/cards, all five pledges in a different order,
repeat claims, full bags, sixty pending reward cards, region travel, JSON saves,
malformed saves, ordinary deliveries, geography, the optional dungeon and the
existing mainland quest/lair reward regressions. A real `WorldDuels` UI host was
started and its win/loss/draw reports were exercised; these result tests do not
pretend to play the combat itself.

Native macOS viewport captures checked all five petition panels, the harbor,
castle before and after liberation, and dungeon introduction. Original-skin
panels at 960 × 640 and 2×-skin panels at 800 × 600 stayed within the viewport,
with readable text and accessible controls. These are source-scene checks,
not rebuilt release binaries.

A clean standalone DeckLab run played **12 complete games**, two against each
of the five petition decks and the lord's deck, with Wizard pilots on both
sides and no ratings updates. The lists came from the actual encounter
configuration. Big Green was the common opponent, seed 48271; the lord kept
25 life, the others 20. There were **zero stalled games or script errors**.
The CLI's Paris mulligan was enabled, so this is an engine/deck smoke check,
not an exact replay of the adventure's 1997 mulligan or a balance estimate.
The earlier run with startup compile errors was discarded.

`git diff --check` and all twelve tracked-tree/code-map/privacy checks passed,
including the new, not-yet-staged files.

Future playtesting should measure quest difficulty and pacing across real
campaign collections. The five pledges remain single-duel assignments;
multi-stage objectives and additional wandering stories are future work.
