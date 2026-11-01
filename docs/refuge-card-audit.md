# Fallen Empires cards in the adventure

Pack 2 contains **102 distinct cards, with 187 printings**. Its trusted card
scripts ship with the game; the optional pack supplies metadata and artwork.
Enable Pack 2 in Options before taking the coastal ship to the Last Refuge.

## Availability

| Campaign state | Newly offered Fallen Empires cards | Cards already owned |
| --- | --- | --- |
| Mainland, before defeating the island lord | No | Keep, play, sell or copy them normally |
| Last Refuge, before defeating the lord | Yes | Available in the shared collection |
| Last Refuge, after defeating the lord | Yes | Available in the shared collection |
| Mainland, after defeating the lord | Yes, permanently for this campaign while the pack is enabled | Available in the shared collection |

The unlock covers town shops, town trades, the Nomad's Bazaar, Diamond Mines,
free town quest choices, wandering-creature spoils, choose-any-card rewards,
random artifact gifts, lair treasures and mainland wizard victory choices.
Every one of the 102 cards enters the regional pools. A particular offer still
obeys its color, type, rarity, budget and campaign copy/ban restrictions.
The eleven island trade categories provide access to every card type.

Visiting the island alone does not unlock new mainland stock. Completing a
community pledge grants its twelve Fallen Empires cards once, before the final
battle; these cards can be brought home immediately. All five pledges and a
main deck containing at least 50% Fallen Empires **nonland copies** qualify the
hero to challenge the lord. Lands contribute to neither side of that ratio.
Victory records the permanent unlock; a loss does not.

Existing shelves do not reroll on victory. New shops and normal restocks use
the larger pool. Stock, collection and the liberation flag survive travel and
save/load, without unlocking a different hero's campaign. The setting that
offers all original trader cards does not bypass island progression.

Several original rules remain deliberate:

- Starting decks use the original base-card pool. Enabling Pack 2 changes no
  starter deal. Normal, non-campaign Deck Builder browsing remains independent
  of campaign progress.
- A roaming opponent's deck and named ante remain that opponent's own cards;
  expansion availability does not rewrite existing creature decks. The island's
  five pledge decks and lord's deck explicitly use Fallen Empires cards.
- Fixed dungeon treasures and fixed named gifts retain their identities. The
  island dungeon uses the existing dungeon treasure rules. Card-riddle clues
  retain their original base-card vocabulary; their random rare prize follows
  the regional pool.
- Under the original adventure copy rules, random duel spoils halve the allowed
  copies of non-base cards. With fewer than forty main-deck cards this rounds
  down to zero; shops, trades and pledge rewards provide other sources. Classic
  MTG campaign limits use their separate configured rules.

Disabling a pack never substitutes another card for a missing saved card. A
shop keeps its saved stock but cannot sell an unavailable definition, and
explains that the pack is needed. Re-enabling it restores the same offer. A
hero on the island can still sail home with Pack 2 disabled; island challenges
and outward voyages require it.

## Corrections in this audit

The shared Fallen Empires rules and prior mechanics audit were reviewed with
the regional campaign paths. The existing mechanics suites cover token and
counter engines, unusual costs, mana, control, combat, triggers, object
identity and computer-player decisions.

Merseine now distinguishes a creature with no mana cost from one with a printed
zero cost. Its escape ability cannot be paid for an ordinary Saproling token,
but can be paid for Ornithopter or a token copying a creature's printed mana
cost. The ability description also makes an unpayable escape clear.

Temporary shroud from Deep Spawn, Homarid Warrior and Svyelunite Priest now
participates in the ability layer. A later Humility removes an earlier grant;
a grant resolving after Humility applies until its normal expiry. These follow
[Comprehensive Rules 118.6, 202.1b and 613](https://media.wizards.com/2026/downloads/MagicCompRules%2020260819.txt).

Choose-any-card rewards, random artifact gifts and wizard victory choices were
still using only the original pool. They now share the regional reward pool,
including the wizard reward browser's type filters. A direct choose-any-card
request is checked against that same pool before its reward is spent.

Saved stock from a disabled pack could previously be bought for zero gold and
added as an unavailable card. The purchase is refused without changing stock,
gold or collection; the shop also refreshes correctly when the pack returns.

## Verification

The new focused regressions passed **15 tests / 9,875 assertions**, including
all 102 names across four states, actual deterministic shop/spoil/artifact
draws, separate campaigns, cached stock, pack removal/restoration, save/load,
real reward panes and both timestamp orders for shroud. The mechanics were
reproduced as failing tests before correction.

The combined targeted run passed **192 tests / 16,278 assertions** across
twelve scripts: the three existing Pack 2 mechanics/integration/computer-player
suites, the three new suites, card trades, duel spoils, wizard victories and
their pane, shops and regional campaign progression. No selected script was
skipped. A separate metadata comparison found all 102 scripts present with
matching mana costs, Oracle text and creature power/toughness against the
187-printing trusted catalogue.

These checks establish the tested paths; they are not an exhaustive proof of
every possible interaction among the game's optional packs. The preceding
[quest audit](refuge-quest-audit.md) records the twelve completed live duels
against all five community decks and the lord.
