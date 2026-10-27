# The MPN move list — a readable rendering of an MPN 0.1 record

Status: **draft**, 24 October 2026. Applies to records in
[MPN 0.1](mpn-specification.md) (`[Notation "MPN/0.1"]`).

An MPN record is written for programs: numbered events with JSON payloads and
snapshots of the public table. The **move list** is the same game told for
people, as a chess game is told in its move list:

```text
Turn 3 · White Wizard
  main 1   Plains
           Holy Strength → Savannah Lions ×2
  combat   ⚔ Savannah Lions → B 16
```

The move list is a **reading** of a record, not a second file format: it is
made from the record alone, needs no rules engine and no card database, and
adds nothing the record does not say. It names only public information,
since the record holds nothing else. This document fixes the reading
exactly, so that two implementations render one record to the same text,
byte for byte; [two worked examples](#9-conformance-the-examples) are the
acceptance test.

The reference implementation is `engine/records/mpn_move_list.gd`
(`MpnMoveList.text`) in this project.

## Contents

1. [The text](#1-the-text)
2. [The symbols](#2-the-symbols)
3. [Reading the record](#3-reading-the-record)
4. [Actions](#4-actions)
5. [Cards leaving play](#5-cards-leaving-play)
6. [Lives](#6-lives)
7. [Turns, phases and lines](#7-turns-phases-and-lines)
8. [What is not told](#8-what-is-not-told)
9. [Conformance: the examples](#9-conformance-the-examples)
10. [Notes for implementers](#10-notes-for-implementers)

## 1. The text

UTF-8, LF line ends, a final LF. In order:

1. **The tags**, chess-style, one a line: `[<P1's tag> "<P1's name>"]`,
   `[<P2's tag> "<P2's name>"]`, `[Date "<first 10 characters of Started>"]`
   (left out when `Started` is shorter), `[Result "<result, or *>"]`. In a
   tag's value `\` is written `\\` and `"` is written `\"`. A blank line.
2. **The symbols**: the line `Symbols`, then one line per entry of
   [section 2](#2-the-symbols) — two spaces, the symbol padded with spaces to
   16 characters, its meaning — then two spaces and
   `Taps, untaps, mana and each turn's first draw are not told.`, and a
   blank line.
3. **The turns**, each a heading line then its lines
   ([section 7](#7-turns-phases-and-lines)).
4. A blank line, then the **result** line: `1-0`, `0-1`, `½-½`, or
   `* (unfinished)` when the record has no `result` event.

**Clean text.** Every value written — names, steps, card names, comments,
revealed cards — is taken only when it is a JSON string (a number is written
as its digits; anything else counts as missing), with every control
character (U+0000–U+001F, U+007F) turned into a space and the whole trimmed.
A line break in a record can never start a line of the move list.

**The players' tags.** For each player's name (`Player.P1` / `Player.P2`,
cleaned): its first letter — the first character with an upper case and a
lower case — upper-cased. When either name has no letter, or the two letters
are the same, the tags are `P1` and `P2`, and every turn heading then adds
the seat: `Turn 3 · Great Druid (P2)`.

Padding counts characters (Unicode code points), not bytes.

## 2. The symbols

Every move list opens with this table, in this order, word for word:

| Symbol | Meaning |
|---|---|
| `Plains` | a land played |
| `Savannah Lions` | a spell cast (it resolved unless told otherwise) |
| `→` | its targets; after damage, the life the player has left (→ B 12) |
| `uses` | an activated ability (uses Prodigal Sorcerer → B) |
| `X=5` | the X a spell was cast with |
| `⚔` | attacks; "Wall blocks Knight" a block |
| `Egg deals 2` | damage from a permanent or a trigger, not a spell |
| `†` | died, or went to its owner's graveyard |
| `✕` | exiled (removed from the game) |
| `↩` | returned to its owner's hand |
| `↧` | put into a library |
| `⇥` | left play out of sight (to a hand or a library), or a token gone |
| `+Serra Angel` | put into play without being cast or played |
| `W +4 → 24` | a life change no damage tells (a gain, a loss) |
| `burns 1 → W 19` | mana burn: life lost for mana left unused |
| `#` | the life that ended the game, as chess's mate |
| `×2` | two of one name (⚔ Goblin ×2), or the same line twice in a row |
| `[B]` | an action by the player whose turn it is not |
| `{…}` | a comment written in the record |
| `—` | a turn in which nothing public happened |

The symbols are written as shown, whatever the players' tags.

## 3. Reading the record

Read the records in order. A field of the wrong JSON type reads as missing
(a handle that is not a string is no handle, a count that is not a number
is the default); nothing in a record that parses is an error. Keep:

- **the table**: the public objects by handle, folded from `state` patches
  as MPN 0.1 §7 folds them: `removed` deletes handles, then each row of
  `objects` replaces whole the row with its `id`;
- **a history**: every row a `removed` deleted, by handle, kept for its name
  (MPN 0.1 §7 allows a reader this "separate historical lookup");
- **the permanents just removed**: the names of the rows of zone
  `battlefield` the latest non-empty `removed` deleted, in order;
- **the stack entries** by their `source` handle (the latest seen wins);
- **each player's life** as last seen (`players[i].life`, a number);
- **the pending life changes**: per player, `[life before, life after, phase]`
  for a change not yet told ([section 6](#6-lives));
- **the active player** (`active`, 0 or 1, kept from patch to patch: a patch
  that leaves it out keeps the last one), **the current turn** and **the
  current phase**.

A card's **name** is its row's `name` in the table, else in the history,
else the handle itself (`?` for none).

**A `state` patch**, in this order:

1. `active`, when present, becomes the active player;
2. when `turn` is present and differs from the current turn's number (or no
   turn has begun): tell the pending life changes ([section 6](#6-lives)),
   then begin that turn with the active player and no lines. When `turn` is
   absent or the same and `active` is present, the current turn's player
   becomes the active player. (A writer may repeat the whole state in every
   record; only a new number begins a turn.)
3. `step`, when present: the current phase becomes its phase
   ([section 7](#7-turns-phases-and-lines));
4. fold `removed` (keeping the history and the permanents just removed),
   then `objects`, and record the `stack` entries by source;
5. for each of the two players with a numeric `life`: if a life was seen
   before and this one differs, that player's pending change becomes
   `[the pending "before" if there is one, else the previous life; this
   life; the current phase]`; then remember this life.

**Other records**:

- `damage`, `mana_burn`: [section 6](#6-lives);
- `die`, `leave`: [section 5](#5-cards-leaving-play);
- `tap`, `untap`, `mana`, `close`: nothing;
- any other kind: first tell the pending life changes, then
  [section 4](#4-actions).

Nothing is told before the first turn begins. **The actor** of an event is
its `player` (`"P1"` → 0, `"P2"` → 1, anything else none); an action whose
actor is the player whose turn it is not opens with `[<their tag>] `.

## 4. Actions

Each action becomes one **item** in the current phase of the current turn.
An item remembers the handles it names (the event's `object`; an attack's
attackers): the latest item naming a handle is that handle's **owner** for
the turn ([section 6](#6-lives)). Its words:

| Event | Words |
|---|---|
| `land` | the object's name — or, when an item `+<name>` of this turn entered with that object ([`enter`](#4-actions)), that item's words become the name (a land seen entering, then played) |
| `cast` | the stack entry's `name` (the entry whose `source` is the event's `object`), else the object's name |
| `activate` | `uses ` + the same name |
| … the entry's `x` > 0 | + ` X=<x>` |
| … the entry's `targets` | + ` → ` + the targets joined by `, `: a target with `player` `P1`/`P2` is that player's tag, else the name of its `object` |
| `attack` | `⚔ ` + the attackers' names, [counted](#counted-names); none tells nothing |
| `block` | `<blocker> blocks <attacker>`; a block right after a block of **the same attacker handle** in the same phase joins it: `<blockers, counted> block <attacker>`; no blocker tells nothing |
| `enter` | a row whose `types` holds `land`: nothing when an item of this turn already names that object (its play), else `+<name>`, remembered as a land entering. Another row: nothing when its name was cast this turn and not yet crossed off (cross it off once), else `+<name>` |
| `discard` | `discards <name>` |
| `draw` | nothing for the turn's first draw — count 1, in the `draw` phase, by the active player or no player; else `draws <count>` (default 1) |
| `reveal` | `reveals ` + the `cards` (strings) joined by `, ` |
| `regenerate` | `<name> regenerates` |
| `comment` | `{<text>}` |
| `result` | sets the result: `1-0`, `0-1`, `1/2-1/2` → `½-½` |

A cast's stack name is crossed off by the `enter` of a permanent of that
name, which is not told; the permanent's own entry would repeat the cast.

### Counted names

A list of names is written in order with each run of equal neighbours as
`<name> ×<n>`: `["Wall", "Wall", "Ogre"]` → `Wall ×2, Ogre`.

## 5. Cards leaving play

`leave` and `die` mark the latest item of the current turn **when it is in
the current phase and is not a life change of its own line**; otherwise they
make a new item with empty words, which the mark fills (`† Bog Imp`).

- **The card**: the event's `object`; when it has none, the first of the
  permanents just removed (a `die` without an object crosses it off). With
  neither, nothing is told.
- **The mark** of a `die`: `†`. Of a `leave`, by the zone of the card's row
  **in the table**: `graveyard` `†`, `exile` `✕`, `hand` `↩`, `library` `↧`,
  `battlefield` nothing at all; a card not in the table (gone out of sight,
  or a token gone): `⇥`.
- A `die` of a card that item already marks `⇥` replaces that mark, and a
  `die` the item already tells is not told twice.

**Writing the marks** on an item, by mark in the order first met: the first
time a mark's cards include the one the item's words end with, the mark
follows the words (`Lightning Bolt → White Knight †`) and that card is
crossed off. Every mark's remaining cards then follow, each group as
`<mark> <counted names>`, after `; ` (`Giant Growth → Timber Wolves; †
Prismatic Dragon`) — or alone, for an item with no words (`† Island ×2`).
Marks come after the words and before the lives.

## 6. Lives

Each life change is told once: on the item that caused it, or on a line of
its own.

**Damage to a player** (`damage` with `target` `P1`/`P2`) takes that
player's pending change, if any, and tells its "after" as the player's life
on an item:

1. **an attacker's damage** (the `source` is an attacker of this turn's
   attacks): on its attack, or on the last `blocks` item right after it,
   when that is the turn's latest item; otherwise on an item with empty
   words at the end of the turn (one already there in the same phase, with
   no marks, is used again);
2. else on the source's owner item for the turn;
3. else, for a source handle: a new item `<source's name> deals <amount>`
   (the amount, at least 0), whose actor is the source row's `controller` —
   a permanent's or a trigger's damage;
4. else on the latest item.

The item keeps `[tag, life]`; a second change for the same tag on that item
replaces the number.

**Mana burn** (`mana_burn`): tell the other player's pending change first,
then make the item `burns <amount> → <tag>` (the actor the burner), with
the burner's pending change as its life.

**Changes no damage told** are told when [section 3](#3-reading-the-record)
says: each a line of its own in the phase it happened in,
`<tag> +<n> → <after>` or `<tag> −<n> → <after>` (the minus U+2212).

**Writing the lives** on an item: ` → `, then `<tag> <life>` for each, joined
by `, `. When the item has one life, no marks, and its words end with
` → <that tag>` (a spell aimed at the player it hurt), that ending is dropped
first: `Lightning Bolt → G 17`, not `Lightning Bolt → G → G 17`. An item
with empty words is its lives alone: `→ B 5`.

**The mate `#`.** When the record has a result, the losing player — P2 for
`1-0`, P1 for `0-1`, both for a draw — has `#` after the **last** life of
theirs the move list tells (on an item, or a line of its own), if that life
is 0 or less. No other life carries it: a player at 0 may still come back.

## 7. Turns, phases and lines

**Phases**, by the record's `step`:

| `step` | Phase |
|---|---|
| `untap` | `untap` |
| `upkeep` | `upkeep` |
| `draw` | `draw` |
| `main1` | `main 1` |
| `combat_begin`, `declare_attackers`, `declare_blockers`, `first_strike_damage`, `combat_damage`, `combat_end` | `combat` |
| `main2` | `main 2` |
| `end`, `cleanup` | `end` |
| any other | the step, cleaned |

**A turn's heading**: `Turn <n> · <player>`, or `Before the game · <player>`
for a turn number of 0 or less; the player is the active player's name (their
tag when the name is empty), with ` (<tag>)` after it when the tags are `P1`
and `P2`.

**A turn's lines.** Its items in order, each written as `[<tag>] ` (when not
the active player's) + its words, marks and lives; an item that writes as
nothing is left out. An item that writes the same as the line before it in
the same phase is not a new line: that line's **repeat count** goes up by
one, written ` ×<count>` at its end when above 1
(`Holy Strength → Savannah Lions ×2`). The count is kept apart from the words:
`⚔ Goblin ×2` then `⚔ Goblin` are two lines.

Each line is two spaces, the phase padded to 9 characters — the phase only on
its first line, spaces after — then the words. A turn with no lines is the
line `  —`.

## 8. What is not told

Taps, untaps, mana produced, and each turn's first draw: these fill a record
and tell a reader nothing. The table's snapshots are read, never written
out. Hidden cards are never named: the record holds none. The result line
tells the recorded result only; an unfinished record says so.

## 9. Conformance: the examples

Each pair is a real recorded game and its move list. An implementation
conforms when it renders each `.mpn` to its `.txt` byte for byte.

| Record | Move list | What it shows |
|---|---|---|
| [`knights-and-raiders.mpn`](mpn-examples/knights-and-raiders.mpn) | [`knights-and-raiders.txt`](mpn-examples/knights-and-raiders.txt) | a short game: lands, spells, an aura cast twice (`×2`), attacks, a response on the attacker's turn (`[B] … †`) with the combat's damage after it on its own line (`→ B 8`), an empty turn (`—`), the mate (`→ B 0#`) |
| [`mandurang-and-hydra.mpn`](mpn-examples/mandurang-and-hydra.mpn) | [`mandurang-and-hydra.txt`](mpn-examples/mandurang-and-hydra.txt) | most of the notation: an aura falling with its creature (`†; †`), exile (`✕`), a life gain, a trigger's damage by its controller (`[H] Power Surge deals 1 → M 19`), mana burn, an X spell, blocks, abilities repeated (`uses Shivan Dragon ×6`) with the combat's damage after them (`→ M 5`), regeneration, extra draws, a spell hitting both players at the end (`→ M -5#, H 7`) |

The MPN 0.1 examples ([`finished-game.mpn`](mpn-examples/finished-game.mpn),
[`stopped-game.mpn`](mpn-examples/stopped-game.mpn)) render too; the first:

```text
Turn 1 · Red Wizard
  main 1   Lightning Bolt → G 17
           {Green Wizard concedes. This annotation explains the outcome; it is not an executable action.}
```

## 10. Notes for implementers

- **Handles change with zones.** A spell is cast as one handle (on the stack)
  and enters play as another; a creature dying gets a new handle in the
  graveyard. Never join handles by name to "track" a card: name what each
  event names.
- **States come before their events** in the reference recorder (MPN 0.1 §7
  permits it): the life a damage caused is usually already in the table when
  the `damage` event arrives. That is why changes are held pending and handed
  to the damage that explains them, and told on their own line otherwise.
- **Records written before 24 October 2026** may have `leave` and `die`
  events without an `object` when the card went out of sight (a token
  ceasing, a card returned to a hand); [section 5](#5-cards-leaving-play)'s
  permanents just removed name them.
- **Build the text in one pass** (a list of lines joined once): a record may
  hold 100,000 events.
- **Nothing here changes the record.** The move list is derived; keep MPN 0.1
  as the file you write and exchange.
