# Portal starter decks and Help

The two **1997 Portal 2-Player Starter Set** lists are preserved at 35
cards in `decks/portal/`, under **Portal 1997 starters** in the Deck Builder.
They are not MicroProse enemy decks. Both have 20 singleton nonland cards
and 15 lands, without sideboards. File order is not the starter's scripted
demonstration order; the engine shuffles normally.

Both originals can be played unchanged in casual duels. Two clearly
labelled **40-card play versions** also ship under **Playable variants**
in `decks/variants/`. They retain every original card and add five:

| Deck | Add one of each |
| --- | --- |
| Starter A (white/red/green) | Plains, Mountain, Armored Pegasus, Grizzly Bears, Volcanic Hammer |
| Starter B (blue/black/green) | Island, Swamp, Coral Eel, Snapping Drake, Hand of Death |

Each adaptation has 17 lands and 23 nonlands. These are this project's
adaptations, not official published decks or a claim of competitive balance.
All four lists declare Pack 6 and prefer Portal artwork, including reprinted
cards and large-mana-symbol lands. They use regular set printings, not the
starter-only alternate reminder-text faces. One printing per card name is
the existing deck format's limit; exact physical-product land art is not claimed.

## In-game guidance

**Help → Contents → Portal starter decks** opens two illustrated guides.
They explain each deck's plan, key cards, timing and precise five-card
additions. The prose is original guidance for this game's implemented card
rules, not copied or paraphrased from an unread official strategy book.
Sources remain here, not in player-facing help. Disabled-pack pages retain
their explanations without requesting missing card definitions.

The contents page is generated from the same chapter list as the pages,
so every page has a working link without a second hand-maintained index.
Contents and Home return to the index; arrows and Page Up/Down still turn
pages. Topic buttons wrap and their grid responds to the available width.

## Historical sources and official teaching material

- [Magic Librarities: Portal alternate-text cards](https://www.magiclibrarities.net/129-rarities-portal-alternate-text-cards-english-cards-index.html)
  documents the physical starter, its two fixed decks and demonstration
  play guide. Card counts are checked against the product lists there.
- [Starter deck 1](https://mtg.wtf/deck/por/preconstructed-deck-1) and
  [starter deck 2](https://mtg.wtf/deck/por/preconstructed-deck-2) provide a
  second transcription. Basic-land printings vary between archival lists;
  the card-name counts agree.
- Beth Moursund, *Magic: The Gathering — The Official Guide to Portal*
  (1997), ISBN 1-56025-152-2, is a published official guide covering cards,
  strategy and deck construction. See the
  [bibliographic record](https://search.worldcat.org/title/39339824) and
  [guide overview](https://mtg.fandom.com/wiki/Portal/Official_Guide).
  Its full text was not inspected and is not redistributed.

## Deck size

The engine does not depend on a 40-card library: setup shuffles the supplied
cards, deals normally, and a failed draw loses the game. Casual local duels
(human/computer, hotseat and demo) and friendly LAN tables accept **8–39
cards**, with an advisory in the Deck Builder and deck selection. Eight is
the safety floor for seven opening cards plus the optional single ante.
Decks are never padded automatically. Smaller decks increase consistency
and decking risk; an eight-card deck with ante can run out on its first draw.

**Gauntlets and LAN tournaments retain 40 cards**, including fixed decks,
host-approved selections and bot seats. Format/copy rules still apply
independently. LAN validation separates casual and tournament policies and
the compatibility stamp changes so an older host cannot silently disagree.
Historical starter rules are not an alternative engine ruleset.

## Verification — 2026-09-24

367 focused GUT tests passed across Portal starters, Help, DeckModel,
local setup, shipped-deck provenance, LAN open tables, tournaments, bots,
Gauntlets and booster drafting. Six tracked-tree/privacy checks passed.
The socket test exercises 35-card own-deck, fixed-deck and casual bot
tables; tournament rejection and the eight-card ante/opening floor are
separately pinned. No full-suite run or export was performed for this change.

Eight complete Wizard-v-Wizard engine games covered both starter sizes,
both rulesets and swapped seats (seeds 240900–240907), finishing in 15–31
turns. The unmodified 35-card lists also completed a native macOS UI soak
at seed 240917 under fifth-edition rules: demo finished in 21 turns and
the fuzzed human seat in 14 turns with 148 UI clicks. Both logs were clean;
these are smoke checks, not a statistical balance claim.

Native source-scene screenshots verified the original stone skin's contents
page and illustrated guides at 1280×800 and 960×720, including the scrolled
end of Starter B. The contents contains 44 topic links across five chapters.
