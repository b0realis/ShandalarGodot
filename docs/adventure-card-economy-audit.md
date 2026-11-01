# Adventure card economy: original game and Pack 2

Review of `2nd_pack`, 2026-11-01. The aim is to preserve Shandalar's loop:
explore, risk cards in duels, earn or buy particular cards, improve a limited
collection, and challenge stronger opponents. Installing a set must not turn
the campaign into the unrestricted Deck Builder.

## Evidence and limits

The primary behavioral reference is the matching **version 1.3** decompilation
at [`fda3230621eb17e1361fd15f44d86637b9b47dce`](https://github.com/rlerrr/shandalar-decomp/tree/fda3230621eb17e1361fd15f44d86637b9b47dce):

| Reference | What was inspected |
| --- | --- |
| [`adventure_new_game.c`](https://github.com/rlerrr/shandalar-decomp/blob/fda3230621eb17e1361fd15f44d86637b9b47dce/src/shandalar/src/adventure_new_game.c) | `InitializeNewGameState` (004bdd0a), `AddRandomStarterDeckCards` (004be0bf), `GetRemainingAllowedCardCopies` (004bb1cf) |
| [`visitLocation.c`](https://github.com/rlerrr/shandalar-decomp/blob/fda3230621eb17e1361fd15f44d86637b9b47dce/src/shandalar/src/visitLocation.c) | `RunTownServicesMenu` (004ef1ea), `CalculateCardShopPrice` (004f1cce), `SellPrice` (004f1bcc), card browser and `BuyAnyCardFromTown` (00530b90) |
| [`world_lair_monster_encounter.c`](https://github.com/rlerrr/shandalar-decomp/blob/fda3230621eb17e1361fd15f44d86637b9b47dce/src/shandalar/src/world_lair_monster_encounter.c) | Lair candidate selection, rarity/type/color checks, duel reward budget and opponent ante overrides |

The imported `adventure_cards` table provides the original card-specific
economic facts. Without it, `CardValue` derives facts from card definitions,
printing metadata and the original named exclusion marks. The price formula
is preserved; derived prices are approximations of hand-tuned original values.
The larger core catalogue and optional sets are not a claim to reproduce the
retail catalogue exactly. This review does not replace the existing rules and
card-mechanics tests with evidence from a later community remake.

## What the original did, and what we retain

| Source | Acquisition rule |
| --- | --- |
| First deck | Difficulty/color quotas; basic lands; alternating common/up-to-uncommon slots; artifact or enchantment spells; creatures and a rare/special slot. Base expansion flags `0xC1`, exclusion flags `0x900`. The original extra creature on shares without a rare remains in the original modes. |
| Town shop | Four/five/six offers in village/town/city, plus Haggler's Coin. Terrain colors, slot rarity and alternating artifact restrictions; limited copies. Original core stock excludes `0x980` marks. A purchased slot waits for normal restocking and a different-town visit. |
| Amulet trade | The settlement's color/type category, rarity-based price; four basic lands per amulet. Under the original modes a dimmed name is still tradable: the copy allowance is advisory here. |
| Bazaar / Diamond Mine | The broader eligible trade catalogue, paid in gold / amulets. These do not become free access merely because the pack is installed. |
| Ordinary quest choice | The giver's category and reward exclusions. The optional setting offering all original cards at paid traders does not apply to free rewards. |
| Creature victory | Creature-strength budget, color/type selection, acquisition copy limits and rarity/favored cost. Actual opponent ante can replace the first reward picks; it is not silently swapped for an unlocked catalogue card. |
| Lairs and riddles | Different checks for different events. A random rare is not the same pool as a treasure; the lair's prepared rare accepts zero remaining copies, whereas ordinary spoils require a positive remainder. Riddle clues keep their original vocabulary. |
| Dungeon / wizard | Fixed named dungeon treasures keep their identity. Wizard victory choices use the eligible reward catalogue with their color/category rules. |
| Owned cards | A shared collection, membership in the hero's decks, selling and paid copying. Ownership and permission to generate new stock are separate. |

The adventure's acquisition allowance and the Deck Builder's duplicate rule
are separate original behaviors. Acquisition starts at one copy below forty
active-deck cards, two from forty, three from sixty, plus the Tome. Ordinary
spoils halve that allowance for non-base cards (integer division); marked
treasures use the difficulty exception; basic lands are unlimited. Shops
retain their existing slot allowance, without the non-base spoil reduction. **As shipped** preserves
the original ineffective owned-copy count. **As intended** counts cards in
the active deck. **Classic MTG** uses its own owned-card limits and ban list.
These modes must not be collapsed into one new expansion rule.

Existing explicit conveniences remain: safe refusal of paid purchases with a
full bag, same-town resale capped at that town's purchase price, and the
optional all-original-cards trader setting. Cross-town trading remains possible.

## Confirmed corrections

1. **Starter eligibility and slot classification.** The older Unlimited-or-
   Fourth-Edition shortcut admitted Icy Manipulator and Basalt Monolith and
   missed eligible Astral/promotional cards. It also treated Ironclaw Orcs as
   common instead of the original special mark, and excluded artifact creatures
   such as Ornithopter from artifact spell slots. The starter now uses the
   shared adventure facts and keeps overlapping artifact/creature membership.
   Optional packs still do not join the starter. Existing saved decks stay intact.
2. **Shared reward checks.** Spoils, lair checks and trade-list dimming now
   share `CardShop.remaining_copies` / `copies_left`, keeping each caller's
   original comparison. Classic limits remain independent. Shops retain
   their existing slot allowance for both base and optional cards: a hero
   with a 36-card starter can find Fallen Empires in shops. The initial audit
   extended the non-base spoil reduction to shops, but that was a new balance
   restriction, not a demonstrated original shop bug; it has been withdrawn.
   Existing shelves are not rerolled or confiscated.
3. **Stale trade confirmation.** A cached trade could charge for a card after
   pack removal, beyond the Classic copy limit, or outside the campaign's current
   unlock. Paid and free confirmations now recheck availability and limits
   before changing cards, currency or reward state. The pane drops an invalid
   selection and can offer it again when the pack returns.
4. **Cache lifetime.** Starter facts now follow registry revisions. Skin-table
   replacement also clears starter and optional-stock caches, alongside the
   existing pricing/shop/trade caches.

## Embark campaign-settings audit

The existing **Card rule** choice covers acquisition-copy policy. No fourth
mode or separate minimum-deck-size setting is needed. The three choices are:

| Card rule | Offers and deck building |
| --- | --- |
| As intended (default) | Shops count active-deck copies, with the size-based allowance above. Ordinary spoils retain the additional original set restrictions. Paid trades remain possible even when dimmed. The builder uses its separate original duplicate rule. |
| No limit / as shipped | Owned copies do not block original shop/spoil offers. Other original reward restrictions remain, including the non-base spoil reduction; this is not unrestricted acquisition from every source. The builder still uses its original duplicate rule. |
| Classic MTG rules | Offers count the whole collection: normally four, restricted one (four with Tome), banned none, basics unlimited. The chosen ban list applies to deck building too. No forty-card acquisition threshold or non-base halving; actual ante won is kept. |

The modal's nine settings and fresh-profile defaults are:

| Setting | Default | Scope |
| --- | --- | --- |
| Final battle | Reload allowed | Retry policy at Arzakon's final battle; alternative One life ends the campaign on loss or abandonment. |
| Card rule | As intended | The three policies above. |
| Ban list | 1998 + modern | Only active under Classic. “Modern” means the included Vintage list, not the Modern format; it is not downloaded live. |
| All cards offered by traders | Off | Broadens original paid-trader special/treasure eligibility; keeps town categories, Classic limits, selected packs and regional unlocks. Does not broaden shops or free rewards. |
| Card hold | 500 | Collection capacity only; Unlimited does not change duplicate rules or pack availability. |
| Sieges | Steady | As 1997 / Steady / Rare / None. |
| Creatures | Notice | Nearby detection instead of Hunt's continuous pursuit. |
| Starting life | Links only | Alternative Base 10 + links also includes its World Magic bonuses. |
| Eat half as much | Off | Food consumption only. |

The screen, setup record and hero save carry the choices. Randomize preserves
campaign settings and story mode, but can change card-pack selections.
**As 1997** resets only these nine settings: shipped card
counting, 500-card hold, original traders, accelerating sieges, Hunt, links-only
life, normal food use, reload allowed and the inactive 1998 list. It leaves
selected packs and **Expanded adventure** unchanged. Those separate outer
controls select the card pool and story content; they do not replace copy rules.

The menu descriptions now distinguish acquisition, deck legality, collection
capacity and content unlocks. Option names and defaults remain unchanged.

## Pack 2 and the main game

The [availability matrix](refuge-card-audit.md) distinguishes campaign
selection from global installation, and cards-only play from expanded play.
Pack 2 adds **102 identities, not 187 independent lottery entries**. Its
trusted catalogue classifies 36 common, 30 uncommon and 36 rare identities;
alternate illustrations do not multiply draw chances. Reprints must not
reintroduce a core card withheld by a particular source.

Expanded play retains all five pledges and at least 50% Fallen Empires
**nonland copies in the active deck** for the lord. The island does not award
mana links or replace the mainland victory condition. Liberation opens new
mainland offers, without refreshing every existing shelf. Cards earned before
liberation can already be brought home, played, sold or copied. Global settings
and another hero's progress cannot unlock this hero's shops.

The original mainland remains mechanically recognizable, but balance cannot
be identical after adding new cards and another region. Six cards per pledge,
shared gold/food, retained amulets/life/World Magics and the island dungeon can
strengthen the hero before liberation. Those retained rewards are intentional;
only mana links were removed by the chosen design. Mainland clocks pause while
away, although cumulative journey time remains recorded. These are explicit
expansion differences, not original-game features.

More sets also dilute individual-card draw chances because the original
selection works over eligible card identities. Do not silently add per-pack
weights, price discounts, free collections, scaling enemies or automatic
mainland deck replacements. Those would be separate balance decisions. The
next useful playtest measurements are time to the first usable regional deck,
cost of acquiring the lord's required cards, and mainland power after returning.

## Verification

The initial regressions reproduced the starter, artifact-slot and stale-trade
failures before their fixes. An initial shop test enforced the proposed
non-base reduction; the follow-up audit replaced it with coverage of the
existing shop behavior in all three campaign modes. The first corrected targeted run
passed **89 tests / 20,166 assertions** across eight scripts: starters, shops,
trades, spoils, lair rares, campaign card modules and Pack 2 availability.
Before the Embark follow-up, the targeted run passed **116 tests / 23,678 assertions across 14
scripts**, including the imported-table/fallback eligibility comparison,
disabled-pack trade confirmation through the real pane, same-town resale,
card values and island progression. No selected script was skipped; the runner
exited successfully. The tracked-tree/privacy check passed all 12 checks, and
the whitespace check was clean. The local expansion playbook and plan template
were updated and remain untracked, as does the lore file.

This is acquisition-flow coverage, not a full campaign balance certification.

The Embark follow-up passed **103 tests / 15,726 assertions across ten scripts**:
the actual settings window and Embark controls, setup records, original/Classic
copy policies, card-hold limits, the revised economy regressions, campaign pack
modes and regional availability. Its runner exited 0 with no selected scripts
skipped. The separate tracked-tree/privacy check passed all 12 checks.

### Pack 2 gameplay smoke, 2026-11-01

`tests/ui/test_refuge_card_rule_gameplay.gd` plays one complete ordinary
regional encounter per card rule. Each begins with a real 36-card green
Apprentice starter, buys generated Fallen Empires shop stock, trades for a
Thallid through the trader pane, adds it through the adventure builder, saves
and loads on the island, plays the 37-card deck against the Icatian Patrol,
settles the actual ante/spoils, saves and loads again, then returns home.
Cards-only mainland availability is checked separately from the expanded
campaign's liberation gate. Travel preserves both collection and mana links.

| Rule | Shop purchase | Duel result | Turns |
| --- | --- | --- | --- |
| As intended | Icatian Infantry | Won | 21 |
| As shipped | Spirit Shield | Won | 23 |
| Classic | Farrel's Zealot | Won | 29 |

The three gameplay cases and twelve existing journey UI cases passed. The
creature suite passed all thirteen tests, including walking up to a stationary
creature under Notice and Hunt, contact with wanderers/fleeing creatures, and
the tribute menu's Duel Anyway option. Its initial tribute fixture had only a
basic land, so no valid ante; supplying a spell corrected the test setup.
No creature behavior change was needed. The privacy checker passed twelve
checks.

These are automated smoke runs, not three completed human campaigns or a
balance study. Shop funds are supplied by the fixture; the generated decks,
prices, life totals, opponent, ante and rewards use the real campaign code.
The duel engine runs headless with a fair Wizard stand-in for the human seat
and the campaign's configured opponent. No outcome is forced.

### Card-rule hover reference and final bug pass, 0.60.8

Every card-rule choice explains acquisition separately from deck legality:
active-deck versus whole-collection counting, the 40/60-card offer thresholds,
the original builder's 59-card threshold, non-base reward halving, the Tome,
paid trades, ante exceptions, Classic bans and duel-only basic-land padding.
Small saved decks remain playable and do not gain acquisition privileges from
that temporary padding. The same reference appears on the selected choice, its
summary and each dropdown entry, so modes can be compared before selecting one.

The presentation checks found two tooltip problems: measurement before theme
inheritance and clipping dropdown help to the menu's short viewport. Tooltips
now measure their actual font at readiness and use the containing game viewport
for dropdown items. The card-rule references use a compact, opaque reading panel;
other hints retain their existing styling. Regressions require the entire text
at 640×480 and 1280×800, including dropdown items, without an ellipsis.

The final targeted campaign run passed **158 tests / 27,676 assertions across
17 scripts**, exit 0. It includes the three completed Pack 2 encounter duels,
starter eligibility, source-specific reward limits, stale trade refusals,
cache invalidation, regional availability, creature contact, settings and hover
layout. Boundary cases distinguish 39/40 and 58/59/60 cards with and without the
Tome. No campaign copy-policy defaults or new minimum deck size were introduced.

After the panel styling, the six tooltip regressions passed again (**633
assertions**, exit 0). Native macOS viewport captures verified all three
references and the open dropdown's item help with the original skin: every
paragraph was visible, with no clipped final line. These were source-scene
checks, not exported release builds. The tracked-tree privacy and code-map
check passed all twelve checks; local design documents remain excluded.
