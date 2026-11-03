# Adventure card economy: original game and card packs

Review, 2026-11-01; card packs 2–9 in campaigns, 2026-11-03 (0.60.14).
The aim is to preserve Shandalar's loop: explore, risk cards in duels, earn
or buy particular cards, improve a limited collection, and challenge stronger
opponents. Installing a set must not turn the campaign into the unrestricted
Deck Builder.

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
   with a 36-card starter can find pack cards in shops. The initial audit
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
campaign settings, but can change card-pack selections.
**As 1997** resets only these nine settings: shipped card
counting, 500-card hold, original traders, accelerating sieges, Hunt, links-only
life, normal food use, reload allowed and the inactive 1998 list. It leaves
selected card packs unchanged. Card selection does not replace copy rules.

The menu descriptions now distinguish acquisition, deck legality, collection
capacity and content unlocks. Option names and defaults remain unchanged.

## Card packs and the main game

Campaign selection is separate from global installation. Since 0.60.14 (the
owner's pack rulings of 2026-11-03) every installed pack from Pack 2 to Pack 9
can be ticked on Embark, any number at once; Pack 1 is never offered
(`AdventureSetup.IGNORED_PACKS`). Ticked packs add cards to this hero's
mainland shops, trades and rewards; ordinary acquisition and copy rules still
apply, the non-base spoil halving included. The first deck and the fixed 1997
decks (creatures, castle wizards, ruled towns, dungeons, Arzakon) stay base
cards. Setting out enables a ticked pack in Options › Card Packs as well.

| Rule | Meaning |
| --- | --- |
| Own cards | A ticked pack adds the identities it introduced. Its reprint of another pack's card comes only when that pack is ticked too. Exception: Pack 7 (Fifth Edition) adds its 147 Fallen Empires, Ice Age and Homelands reprints as Fifth Edition printings. |
| Fixed rarity | A pack card's rarity (hence its price, shop place and amulet cost) is its original printing in the trusted catalogue that ships in the game; for Pack 7's reprints, the Fifth Edition rarity unless the original pack is ticked too, then the original's. It never depends on which packs are switched on in Options. |
| Ante cards | Pack cards made for ante (Amulet of Quoz, Timmerian Fiends) are never in a shop's places; elsewhere they are treated as the base pool's ante cards are. |
| Strong cards | One list, `CardValue.STRONG_PACK_CARDS` (21 names), gives pack cards the power mark: special like the base pool's power cards — never in a shop place, four amulets in trades, the special budget in spoils. It holds the pack cards on the adventure's restricted and banned names (`ClassicBans`: Brainstorm, Demonic Consultation, Flash, Lion's Eye Diamond, Lotus Petal, Merchant Scroll, Mystical Tutor, Necropotence, Vampiric Tutor), the owner's names those lists miss (Ancient Tomb, City of Traitors, Force of Will, Hymn to Tourach, Mox Diamond, Survival of the Fittest, Wasteland) and the other pack Tutors (Cruel, Enlightened, Personal, Sylvan, Worldly). The banned ante cards follow the ante rule instead; Demonic Tutor is a base card, decided by the 1997 marks. |
| Pack share | In every random draw (shop places; duel spoils: cards won and the artifact for the next duel; lair rewards: treasure, rares, thieves, Pyramids and the lair duel's hoard) each ticked pack's share is min(20%, 60% / N) and all packs' together min(20% × N, 60%); the rest are base cards. When one side has no eligible card for the place's color, type or rarity, the draw takes the other side, so no place is left empty. |
| No packs | A campaign with no ticked pack draws exactly as before: the same seed gives the same cards. |
| Choice lists | Trades, the castle win's pick, "any card of your choice" and quest rewards still list every eligible card, base and pack alike. |
| Old saves | Saves of 0.50.48–0.50.60 that carry Packs 3–9 keep them and follow these rules; nothing they own is taken. |

Measured (0.60.14, seeded): shop places 19.6% with one pack, 39.8% with two, 60.1% with three and with all eight (7.1–8.0% each); cards won 20.3% / 59.8% with one / three packs; the artifact for the next duel, a rare of any kind, the lair's rare and the treasure 59.5–62.2% with three packs. A campaign with no packs draws exactly as before (digests of shops, spoils and lairs unchanged).

| Packs ticked | Each pack | All packs | Base cards |
| --- | --- | --- | --- |
| none | — | 0% | 100% (as before) |
| 1 | 20% | 20% | 80% |
| 2 | 20% | 40% | 60% |
| 3 | 20% | 60% | 40% |
| 4 | 15% | 60% | 40% |
| 8 (Packs 2–9) | 7.5% | 60% | 40% |

Selection works over identities: Pack 2 adds **102 identities, not 187
independent lottery entries** (its trusted catalogue classifies 36 common,
30 uncommon and 36 rare identities); alternate illustrations do not multiply
draw chances. Reprints must not reintroduce a core card withheld by a
particular source.

Ice Age's Snow-Covered basics are basic lands (0.60.15): a shop's land place
only, in Ice Age's own share of it (other packs' shares give ordinary basic
lands — Portal, Fifth Edition, Mirage and Tempest print the same Plains…Forest);
four for one amulet; no copy limit. A deck under 40 cards wins one only in
place of a basic land: a land-type pick, within Ice Age's own share (measured
3.2% of a small deck's spoils with Ice Age alone, 1.3% with all eight packs;
19.8% / 7.5% of land places).

Packs switched on at setting out or resuming go on in one rebuild, compiled
on a thread behind the hourglass, and the campaign's pack cards are priced on
a worker as the world opens (`AdventurePacks.warm`); the trader's list
follows its name box after a short pause and fills long lists in slices
(0.60.15, measured against the 0.60.13 baseline).

Per-pack weights beyond the share, discounts, free collections, scaling
opponents or automatic deck replacements would be separate balance decisions.

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
card values and campaign state. No selected script was skipped; the runner
exited successfully. The tracked-tree/privacy check passed all 12 checks, and
the whitespace check was clean.

This is acquisition-flow coverage, not a full campaign balance certification.

The Embark follow-up passed **103 tests / 15,726 assertions across ten scripts**:
the actual settings window and Embark controls, setup records, original/Classic
copy policies, card-hold limits, the revised economy regressions, campaign pack
modes and regional availability. Its runner exited 0 with no selected scripts
skipped. The separate tracked-tree/privacy check passed all 12 checks.

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
check passed all twelve checks.
