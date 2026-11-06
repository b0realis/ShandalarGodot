# Pack 10 — The Urza Block

`Pack-10-Urza-Block.zip` brings the whole Urza block as one optional,
independent expansion: **Urza's Saga** (October 1998), **Urza's Legacy**
(February 1999) and **Urza's Destiny** (June 1999) — the block of echo,
cycling, the Tolarian Academy and the free spells that untap the lands that
paid for them. Three Scryfall sets in one pack, as Packs 8 and 9 hold the
Mirage and Tempest blocks:

| Set | Code | Printings | Names | Reprints | New identities |
|---|---|---|---|---|---|
| Urza's Saga | `usg` | 350 | 335 | 5 basics + 21 | 309 |
| Urza's Legacy | `ulg` | 143 | 143 | 3 | 140 |
| Urza's Destiny | `uds` | 143 | 143 | 1 | 142 |
| **Pack 10** | | **636** | **621** | **30** | **591** |

No name repeats across the three sets. Urza's Saga's seven star-numbered
variants (Scryfall's `119s` … `187s`, not original English printings) are
left out, as Tempest's were. Core + Pack 10 is 1,518 set entries / 1,506
unique cards (the 897 of the core, 591 new identities and the 18 shared
reprints Pack 10 provides on its own); all ten packs have **4,704 set
entries / 3,684 unique cards**, 591 more than nine.

Only the construction source, reviewed metadata and rules and original UI
symbols are distributed. The generated ZIP and downloaded card pictures
remain local. The pack requires **Shandalar 0.60.19 or later**.

## Construct and install

From the project root (or the extracted game folder), with Python 3.10+,
network access and source matching the game version you will run:

```sh
python3 tools/pack_10_urza_block.py fetch-art
python3 tools/pack_10_urza_block.py build
python3 tools/pack_10_urza_block.py verify
```

`python3 tools/pack_10_urza_block.py fetch` is the maintainer's
catalogue-refresh command. It rewrites the trusted source metadata
(`cards.json`, `cards_ulg.json`, `cards_uds.json` and the three `set*.json`
files): review any upstream Oracle or data changes and rebuild the matching
game, rather than refreshing that snapshot under an older installed
executable. Ordinary local construction uses the checked-in snapshot and
does not require `fetch`.

The default ZIP is `../shandalar-packs/Pack-10-Urza-Block.zip`; the
resumable art cache is `../shandalar-packs/cache/pack_10_art/` (one folder
per set, about 128 MB; the first fetch takes about twelve minutes at
Scryfall's pace). Supply a positional output path and `--art-dir` to change
those locations — for a portable game,
`build cardpacks/Pack-10-Urza-Block.zip`. Every one of the 636 printings
is pinned by Scryfall ID and fetched as an **art crop and a full-card
scan**: 1,272 pictures under the pack's own `art/usg/`, `art/ulg/` and
`art/uds/` namespaces, plus `skin/cardart/` fallbacks (1,218 files) for the
591 new identities and the 18 shared names, so those cards draw a picture
with no other pack installed. With the four metadata files the archive
holds **2,494 entries**, never a script. Two image forms do not mean two
playable copies of a card.

Use **Options → Card Packs → Open Folder** (or **Add pack…**), put the
exact-named ZIP there, then **Rescan** and enable Pack 10. Development runs
may instead set `SHANDALAR_PACK_10` to the absolute ZIP path. No other pack
is required. On Windows `py -3` may replace `python3`; on Mac `cardpacks/`
belongs beside the app, not inside it; the web build offers no import path
for numbered packs (see [card-art-and-packs](card-art-and-packs.md)).

The main menu shows **10-USG**. Deck Builder → **Extras** has a separate
On/Off row for each set — *Urza's Saga Pack 10*, *Urza's Legacy Pack 10*
and *Urza's Destiny Pack 10*. Turn the other sources off to browse exactly
a set's names (335, 143 and 143). These visibility filters do not unload a
globally enabled pack or edit an existing deck. Urza's Saga has four
illustrations for each basic land, chosen as `usg:<number>` variants
(331–350) through the **Card variant** medallion below the Deck Builder's
preview; every other name has one printing. Decks stay name-based and
record required packs; loading while disabled offers the enable flow.

Pack 10 is the first **two-digit** pack. Pack ids are compared as numbers
(`CardPacks.number_of`, `sort_ids`): a string sort had put Pack 10 before
Pack 2 in the title's badges, the Embark list, a saved deck's required
packs and the LAN lobby's "Packs 2, 10". `SHANDALAR_PACK_10`, a file named
`Pack-1-…` against `Pack-10-…`, `--packs 1,10`, the Add pack refusal
("Pack-1 to Pack-10"), the release guard's pattern and the 72-pixel badge
were checked the same way.

The emblems are our own drawings, each following its set's own mark
redrawn as our own geometry: Urza's Saga two **gears** side by side, eight
broad teeth each; Urza's Legacy a smith's **hammer** lying tilted; Urza's
Destiny a conical **flask** with a slim highlight along the glass.
`tools/draw_our_art.gd` (`_gears`, `_hammer`, `_flask`) draws each in the
gold card relief and the lit/dim carved-stone medallions; the hashes are in
`game/art/README.md`.

## Rules, reprints and providers

Every new identity has one trusted file, `cards/sets/<set>/<snake_case>.gd`,
whose header carries the exact Oracle text of the snapshot. Each set's
`_rules.gd` is a fail-closed dispatcher that asks its family modules in a
fixed order — `_basic`, `_spells`, `_creatures`, `_auras`, `_enchantments`,
`_opal`, `_artifacts`, `_lands_mana`, `_combat`, `_triggers`, `_choices`,
`_costs`, `_echo`, `_cycling`, `_untap`, `_misc` — and puts a `_pending`
cast guard ("Urza block rules integration is not yet complete for this
card") on any card no module claims. A pending card is in the pool,
visible and deck-buildable, but cannot be cast.
`tests/cards/test_pack_10_catalogue.gd` ends with the catalogue gate that
refuses any remaining guard.

The 30 reprints keep their existing scripts; no competing script is
written. Twelve are in the 1997 pool (Dark Ritual, Disenchant, Healing
Salve, Pestilence, Power Sink, Enchantment Alteration, Presence of the
Master and the five basic lands) and need no pack. The other 18 live only
in an optional pack — Portal (10: Anaconda, Blessed Reversal, Bog Raiders,
Bull Hippo, Exhaustion, Gorilla Warrior, Lava Axe, Path of Peace, Rain of
Salt, Seasoned Marshal), Portal Second Age (6: Goblin Matron, Goblin
Raider, Jagged Lightning, Lone Wolf, Ravenous Rats, Wildfire), the Mirage
block (Pacifism) and Ice Age (Pit Trap) — and are keyed to the folder of
their script in `packaging/card_packs/pack_10_urza_block/shared_names.json`,
exactly as Fifth Edition's and the Mirage and Tempest blocks' reprints are.
`UrzaBlockPack.scripts()` loads them with the block set they were printed
in; `CardPacks._configure_registry` walks the earlier packs first, so their
script and symbol win when both are on. A deck that uses a shared card
needs **any one** enabled provider (`CardPacks._shared_provider`): the
original pack first, then Portal, Fifth Edition, the Mirage block, the
Tempest block and the Urza block — Pacifism has three (Packs 8, 9 and 10).

## Archive contract

The loader (`game/urza_block_pack.gd`) checks the exact inventory, trusted
metadata, minimum version and SHA-256 hashes, with the central directory's
declared sizes checked before reading a member (`PortalPack.bounded_zip`):
8 MiB per member, 2,494 entries at most, and a **384 MiB** budget like
Packs 8 and 9. The real archive measured 240.4 MiB of members
(252,062,325 bytes; 251,532,917 bytes on disk, 2026-11-06), 93.9% of the
256 MiB the first seven packs allow — too close to that bound to share it.
Builds are staged, verified and atomically replaced; identical inputs
produce identical ZIP bytes. Metadata-only archives are accepted solely
under the isolated test feature, never as player packs.

## Engine review

Every one of the 591 names is implemented: no card carries the pending
guard (`test_pack_10_catalogue.gd`'s gate). A read-only inventory first
sorted every Oracle clause — 921 of them — into capabilities the engine
already had (176, each cited by file and symbol with a precedent card) and
ones it lacked: 468 cards were buildable on the existing engine, 123 needed
24 missing capabilities. Those were built as reusable engine mechanisms —
nine packages and the two optional ones, E1–E11
(`tests/unit/test_pack_10_engine_*.gd`) — before or alongside the cards
that use them; thirteen card batches then filled the family modules, each
with its own test scripts (`tests/cards/test_pack_10_B*_*.gd`; the 25
vanilla and keyword-only creatures came with the scaffolds).

Much of the block needed no new engine: cumulative-upkeep-shaped payments
and "unless you discard / sacrifice" (Masticore, Endless Wurm), the
Monoliths and paid untaps, Defense Grid and Arcane Laboratory, Gaea's
Cradle, Tolarian Academy and Serra's Sanctum's counted mana, Lotus
Blossom, Thran Lens and Darkest Hour, Humble, Donate, Brand and Treachery,
Memory Jar, Exploration, Rancor's return, Mobile Fort, Wall of Glare's
"any number" block, the Scour family's same-name search, protection from
artifacts, and the Seers' and Scents' "reveal any number of cards" (asked
how many, then which, each held for a person, the names shown to both
seats). The batches added one shared card helper, Urza's Saga's
`UntapUpToEffect` ("untap up to N lands": your own lands first, any
player's legal, both questions held for a person). The block's rules-legal
loops stay finite per action: Voltaic Key + Time Vault takes one extra
turn per activation, and Grim Monolith + Power Artifact and Palinchron +
High Tide are cut by the loop limit.

**New engine mechanisms** (`docs/mechanics.md` has a row for each):

- **Echo** (CR 702.30a, E1): one printed upkeep trigger with its
  intervening "if", checked as the upkeep begins and again on resolution.
  "Came under your control since your last upkeep" is a clock — the
  upkeeps a seat has begun against the count stamped as the permanent
  came under its control (`EchoAbility`, `MtgPlayer.upkeeps_begun`,
  `CardInstance.control_upkeep_mark`) — so a stolen, exchanged or
  borrowed-and-returned permanent owes echo again, phasing does not reset
  it, a copy has it and Humility silences it. A Test hands position can
  mark a permanent `echo_due`.
- **Cycling and other abilities from the hand** (CR 702.29a, E2): an
  ability that works only in its owner's hand, any time they could cast
  an instant, on the stack; the card is discarded as a cost (Megrim
  hears it, Library of Leng has no say), no land drop is spent, and a
  cycling land played as a land has none. Fluctuator's "cycling abilities
  cost {2} less" is a floored reduction; Lurking Evil's "pay half your
  life, rounded up" is worked out as it is paid; Archery Training's
  granted shot names its own Aura, so two Trainings give two shots, each
  reading its own arrow counters (live while the same Aura remains, else
  as it was when activated).
- **Layers** (E3): a type change that SETS a card type ("becomes a 2/2
  Soldier creature", "becomes an enchantment") replaces the types, on one
  timestamp clock with the other type writers; a static that chooses whom
  it affects by card type (Opalescence) applies after every other layer-4
  writer; and one printed ability's halves stay together across layers
  (CR 613.6) — Humility made a creature by Opalescence humbles itself and
  still applies, the two size setters then going by timestamp, the rules'
  own example in both orders; two Opalescences with Humility kill nothing.
  Durations that end on an event (Soul Sculptor's "until a player casts a
  creature spell") end as the spell becomes cast; a size read from a life
  total (Serra Avatar) is recalculated as the life changes, before the
  state-based check.
- **Events** (E4): "put into a graveyard from anywhere" is one event per
  card at every door — resolution, fizzle, counter, discard, mill, death,
  the legend rule, exile, the ante, an owner change — never for a token, a
  copy or a card exiled instead (Planar Void, Energy Field, Compost, Serra
  Avatar's shuffle); "a spell is countered" names its caster and where the
  card went (Multani's Presence); and a trigger may still resolve when its
  target becomes illegal (Gilded Drake: no exchange, so it is sacrificed).
- **Playing from another zone** (E5): Yawgmoth's Will's lands played from
  the graveyard as the turn's land drop and its spells cast from there,
  and Temporal Aperture's revealed library top played without paying its
  mana cost (a free payment row; X is 0, buyback still payable). The duel
  screen rings a playable land in the graveyard view and plays a permitted
  top card from a left click on the library pile.
- **Combat** (E6): the defending player assigns the attackers' damage
  (Defensive Formation — the defensive-banding request, a trampler's
  excess the defender's to place); "can't attack / block unless a creature
  with greater power also does" (Okk), judged as declared and not even
  offered when no creature could go with it; and damage assigned as though
  unblocked with no choice (Outmaneuver).
- **A divided total the source decides** (E7): "prevent the next X damage
  divided as you choose, where X is the number of verse counters on this"
  — X read as the ability is announced, before the sacrifice, the shares
  locked on the targets (Serra's Hymn).
- **Mana** (E8): mana that can't be spent to cast spells (Thran Turbine);
  land mana of a fixed type AND amount (Contamination: a Karoo, a Gaea's
  Cradle or a Tolarian Academy makes one {B}); a mana ability that asks
  which cards to reveal (Metalworker); and a mana trigger's color asked
  before the tap is paid, so a person is asked Fertile Ground's color
  and Mana Flare's type instead of a guess.
- **Untap kind and an ignorable ban** (E9): each player chooses artifact,
  creature or land in their untap step and untaps only that kind (Storage
  Matrix); Damping Engine's "sacrifice a permanent to ignore this effect"
  is offered to the player it binds, with the ban standing aside for them.
- **Arriving together** (E10): "put those cards onto the battlefield" is
  one moment — every choice made APNAP first with none of the batch on the
  battlefield (Auras choose their hosts among what was already there),
  then all enter, so each "whenever another creature enters" sees all the
  others: Show and Tell, Replenish, Exhume, Planar Birth, Victimize,
  Defense of the Heart, and Pack 9's Living Death.
- **The draw step's questions** (E11): a draw replacement's question in
  the draw step (Island Sanctuary, Fasting, Abundance, Breathstealer's
  Crypt, and the order between two of them) holds a person's seat the way
  the untap step's questions do, instead of a logged guess.

**Rulings recorded on the way:** Falter's "can't block this turn" is not
a locked set — a creature without flying that arrives later can't block
either; Gilded Drake is sacrificed only when its controller still controls
the same Drake; Okk under Humility has no restriction and may attack
alone; Contamination makes Gaea's Cradle tap for one {B} even with no
creatures (the literal "instead of any other type and amount"); an Opal
Acrolith under Opalescence is 3/3 only when the Opalescence is newer than
its trigger; a spell that fizzles is not countered under either rules
preset, so Multani's Presence draws nothing for it; Temporal Aperture's
card stays playable while it remains on top: not drawn since and the
library not shuffled since, even by a shuffle that leaves it on top, as
Forge's does (`MtgPlayer.library_shuffles`); Witch Engine's
targeted ability is not a mana ability (CR 605.1a); Masticore's upkeep
discard is a payment (Megrim hears it, Library of Leng has no say);
Memory Jar's cards are exiled face down and nobody may look at them.

**Engine-wide fixes found on the way:** `MtgGame.discard_hand` now fires
the cards' own "when you discard this" abilities, so Psychic Purge
punishes a Wheel of Fortune; Gloom's tax and the Cursed Totem and Null Rod
bans read permanents only (CR 109.2), so a card in a hand — a Rune of
Protection cycled, Elvish Spirit Guide's mana under Cursed Totem — is not
touched; a graveyard card whose entry payment fails goes back to the
graveyard; the ante → graveyard and an owner change pass the one graveyard
door (a new object; Forbidden Crypt applies); mana burn at a step's end
recalculates a life-reading size before its state-based check. Two
generated card headers were corrected on the way: Walking Sponge and
Thran Golem had been given a printed first strike that the first only
takes away and the second has only while enchanted.

### Explicit digital adaptations

None. Pack 10 adds no row to `docs/simplified-cards.md` and no engine-wide
simplification, and no Pack 10 card file carries a `SIMPLIFIED` marker.
The inventory's candidates — Show and Tell, Replenish and Exhume arriving
one after another, Temporal Aperture cast from the hand, Outmaneuver's
optional bypass, Archery Training reading the first Training, Abundance's
guessed draw-step answer — were all avoided by building E2, E5, E6, E10
and E11; Veiled Serpent keeps only a wording gap (Known engine limits).
E10 also lifted Pack 9's *Living Death* row: its returned cards now arrive
at the same moment, so a returned Soul Warden sees all the others.

Help → Abilities has nine "Abilities — Urza block …" pages after the
Tempest block's: echo and cycling; the enchantments that become creatures,
with Opalescence and Humility in both orders and Soul Sculptor; untapping and
mana (untap up to N, paid untaps, Voltaic Key and the loop limit, Tolarian
Academy, Gaea's Cradle and Serra's Sanctum, Storage Matrix, Thran Turbine
and Contamination); counters to cash in (the verse cards, Serra's Hymn,
Archery Training); cards put onto the battlefield together (Show and Tell,
Auras put onto the battlefield, Sneak Attack and Academy Rector); other
zones and revealed cards (Yawgmoth's Will, Temporal Aperture and its
clicks, the reveals, Abundance, Memory Jar); graveyards and counterspells
(Serra Avatar, Multani's Presence, the returning Auras); combat (Defensive
Formation, Okk, Outmaneuver, Wall of Glare, Phyrexian Colossus); and the
notable cards (Gilded Drake, Donate and Treachery, Masticore, Phyrexian
Processor, Thran Weaponry, Defense Grid and Thran Lens, Damping Engine).
Living Death's entry is rewritten for its new arrival.

## AI review

Two modules teach the fair AI the block's new shapes, both behind the
existing `forecasts_tactics` capability (no new difficulty scale; with the
gate off the AI plays exactly as before Pack 10): `engine/ai/urza_spells.gd`
(casting and resolution answers, hooked from `AiPlayer`) and
`engine/ai/urza_tactics.gd` (board, combat and activations, reached
through `engine/ai/mirage_tactics.gd`). Policies read the public board and
the AI's own hand only.

- `engine/ai/urza_spells.gd` (casts and the questions put while they
  resolve): symmetric spells (Sunder, Hibernation, Catastrophe, Harmonic
  Convergence, Exhume, Opalescence…) priced by what each side loses or
  gains; the hand spells by our own cards and the opponent's hand SIZE
  (Windfall, Ill-Gotten Gains, Show and Tell); counted spells off the board
  (Corrupt's Swamps, the Scents' revealed cards); the gifts (Sleeper Agent,
  Gilded Drake, Donate); Yawgmoth's Will only with a graveyard worth
  replaying; an untap card cast first when the lands it hands back pay for
  the next cast; a creature held behind a noncreature card while the
  opponent's dormant Opal would wake; echo paid or let go by what the
  permanent is worth against the cast it would cost; Masticore's discard;
  cycling (dead cards, a Rune whose color the opponent never showed, free
  cycles under Fluctuator); Temporal Aperture as the main phase's mana
  sink, its revealed card cast through the free row.
- `engine/ai/urza_tactics.gd` (board, combat, activations): verse, page and
  fuse counters cashed only when X covers the board or the permanent is
  about to go; Serra's Hymn's prevention only against damage the stack or a
  blocked combat shows coming, on our own creature; no gift of itself
  (Witch Engine); Auras sold for a card only as their host leaves; Lurking
  Evil priced by the life it really costs; cheated-in creatures (Sneak
  Attack, Apprentice Necromancer) only for a lethal or half-the-game
  attack; Monoliths and the Voltaic Key untapped with spare end-step mana;
  Masticore's pings only when the mana finishes the kill; Opal Acrolith's
  dodge; Damping Engine's ignore; Goblin Cadets and Phyrexian Negator kept
  out of losing fights; the block's loops in the combo catalogue.

The duel audit (`tools/pack_10_duel_audit.gd`, nine themed 60-card decks —
Echo, Cycling, Enchantress, Opal, Artifacts, Graveyard, Burn, White Weenie,
Tricks — `--rounds 12 --seed 99000 --pilots both`, the real ZIP): **432
complete duels**, 216 per rules profile (108 Wizard v Wizard and 108 Wizard
v Apprentice), no stall, no error, no refused try; the Apprentice won 39
(modern) and 44 (fifth) of its 108. 161 of the decks' 164 block names were
cast or played; the other three are in the limits below. The pool with Pack
10 alone is 1,506 cards, as the catalogue pins.

| Mechanic played | modern | fifth |
|---|---:|---:|
| Echo paid / let go | 309 / 48 | 270 / 32 |
| Cycles (lands cycled; free under Fluctuator) | 49 (2; 23) | 64 (9; 17) |
| Lands handed back by an untap spell or ability | 558 | 492 |
| Other permanents untapped by an ability | 60 | 41 |
| Opal, Veiled and Hidden enchantments turned creature | 239 | 260 |
| Verse, page and fuse counters cashed (any at 0) | 35 (0) | 36 (0) |
| Cards entering together | 79 | 70 |
| Show and Tell picks | 38 | 52 |
| Plays from the graveyard under Yawgmoth's Will | 13 | 20 |
| Temporal Aperture activations / plays off the top | 87 / 43 | 61 / 38 |
| Attacks into Defensive Formation | 63 | 44 |
| Metalworker reveals (artifacts revealed) | 11 (17) | 11 (24) |
| Storage Matrix choices | 126 | 165 |
| Damping Engine ignored | 13 | 34 |
| Masticore upkeeps paid | 22 | 36 |

The audit caught two defects the unit tests missed, each fixed with a
regression test, its gate-off arm and a hidden-information permutation:

- **Serra's Hymn** read its divided prevention as "destroy up to X" removal:
  the AI sacrificed it in its main phase to shield the opponent's creatures
  a point each, and when the points did not add up to X the engine refused
  it (8 refusals in modern seed 99070, "divided amounts must add up to 6
  (got 2)"). Now `UrzaTactics.hymn_cash` cashes it only against damage the
  board shows coming, burn on the stack or a combat once blocks are known,
  with the whole X on the one creature of ours it saves most
  (`tests/ai/test_ai_pack_10_study_hymn.gd`).
- **Temporal Aperture**'s worth less the activation's price never cleared
  the main-phase bar: cast 80 times, activated never. It is now a mana sink
  at the end of our main phase, worth an average card, and the revealed card
  is cast free (`UrzaSpells.aperture`,
  `tests/ai/test_ai_pack_10_study_aperture.gd`); in the final audit, 148
  activations played 81 cards off the top.

Deck Lab, matched candidate/null/control arms (`--sweep
forecasts_tactics=on,off`, Wizard v Wizard, 200 games an arm, Pack 10 only,
`--no-elo`), after both fixes. Big Green v White Knights is no longer a
clean control for this gate: an older reading of it, the cleanup discard
(`AiPlayer._discard_worth`, before Pack 10), moves one or two games in a
hundred, and Blue Skies v Mountain Artillery about a third. The study used
two plain decks no `forecasts_tactics` policy reads, which replayed
byte-identically, 200 of 200, in every arm of all six runs:

- **Control Vanilla White**: 17 Plains, 4 Savannah Lions, 4 Squire,
  4 Pearled Unicorn, 4 Keepers of the Faith, 4 Moorish Cavalry, 3 Thunder
  Spirit.
- **Control Vanilla Green**: 17 Forest, 4 Grizzly Bears, 4 Barbary Apes,
  4 Scryb Sprites, 4 War Mammoth, 4 Durkwood Boars, 3 Ironroot Treefolk.

| Study (seat A gets the knob) | Seed | Null/off | On | Delta, 95% margin |
|---|---:|---:|---:|---:|
| Graveyard v Burn | 99100 | 64.0% | 63.0% | −1.0 ± 9.4 |
| Artifacts v White Weenie | 99200 | 8.0% | 11.5% | +3.5 ± 5.8 |
| Echo v Enchantress | 99300 | 71.5% | 71.0% | −0.5 ± 8.8 |
| Tricks v Cycling | 99400 | 31.0% | 62.0% | +31.0 ± 9.2 |
| White Weenie v Opal | 99500 | 53.0% | 63.5% | +10.5 ± 9.5 |
| Burn v Graveyard | 99600 | 31.5% | 35.5% | +4.0 ± 9.2 |

No pairing is significantly worse; Tricks v Cycling and White Weenie v Opal
clear their margins, the other four sit inside them. The Artifacts deck is
badly outmatched by White Weenie, so its row says little. The AI agents'
own runs at 100 games an arm (black-red v green-white +19.0 ± 12.4,
green-white v black-red +13.0 ± 13.5) used the old control, which moved one
or two games in a hundred, so they are indicative only.

**Known AI limits** (rules complete; the AI simply does not use these
well): Fend Off is only cycled, never cast as a combat trick; Outmaneuver
is never cast and Okk never blocks (the combat planner reads neither, nor
Defensive Formation's gang blocks, Wall of Glare, Taunting Elf, Viashino
Bey, Angel's Trumpet, Crawlspace, Walking Sponge, Thorn Elemental or the
block pumps); Serra's Hymn's prevention is never split between creatures;
Donate gives away only a permanent that hurts its controller (the Tricks
deck holds none, so it was never cast there); many Temporal Aperture
reveals go unplayed (lands after the land drop, modal and X cards the
free-row reader refuses); Rain of Filth and Bubbling Muck are never cast;
Repopulate is only cycled; Multani's Presence is not weighed by the counter
planners; Scent of Brine and Brine Seer use the generic counter reader;
Scent of Ivy and Ivy Seer are not combat pumps; Memory Jar is cracked only
with an almost empty hand and three spare mana; Gamble's tutor is the
generic one; Reprocess eats only what its own hint names; Last-Ditch Effort
is never a combat response; Show and Tell prices the opponent's choice as
an average permanent and Ill-Gotten Gains their unseen cards as average
cards; echo is priced against this turn's cast only; Witch Engine, Goblin
Welder, Soul Sculptor, Temporal Adept, King Crab, Carrion Beetles, Thran
Weaponry, Extruder, Mana Leech and Argothian Elder are never activated;
Molten Hydra, Pyromancy and the X of Chimeric Staff and Citanul Flute are
not sized; the sacrifice outlets (Greater Good, Phyrexian Ghoul, Bloodshot
Cyclops, Barrin, Martyr's Cause, Plaguelord; Tinker, Crop Rotation and
Raze's costs) take the generic pick, and Storage Matrix, Thran Turbine,
Smokestack, Powder Keg's fuse, Body Snatcher, Karmic Guide, Academy Rector,
Iridescent Drake, Goblin Lackey, Hidden Stag and Argothian Wurm answer
with the card's defaults.

## Known engine limits

- A "from anywhere" listener among a sweep's victims hears the ones moved
  before it: a mass removal moves its victims one at a time, so a Planar
  Void destroyed by Tranquility with other enchantments exiles the ones
  processed before it (CR 603.10 says only objects present after the
  event see it).
- `MtgGame.add_static_damage_effect` writes `points` 0, so every static
  prevention entry prevents the whole event; Urza's Armor's "prevent 1" is
  built as a replacement entry instead, and the AI's burn forecast reads
  any static entry as "no damage".
- Contamination overwrites Hall of Gemstone's color: the land's
  controller is not offered the order with Hall applied last (CR 616.1),
  as it is for Deep Water.
- Over SGManalink, Okk's restriction is judged only by the referee: a
  networked seat may declare Okk alone and is refused, with the reason.
- Veiled Serpent's granted Island clause is exact, but its refusal reads
  as a plain "can't attack" without naming the Island.

## Verification

- `python3 tools/test_pack_10_urza_block.py`: offline builder tests
  (exact three-set inventory and counts, reprint and shared lists against
  the core and every earlier pack, deterministic art archive,
  metadata-only refusal, injected/duplicate entries, failed-build
  preservation, size bound).
- The catalogue (`tests/cards/test_pack_10_catalogue.gd` — no pending
  card), the basic, integration, Help and verify-probe scripts, the engine
  scripts (`tests/unit/test_pack_10_engine_*.gd`, the E2 hand menu and E7
  dial in `tests/ui/`, `tests/ui/test_pack_10_zone_play.gd`), the thirteen
  batches' (`tests/cards/test_pack_10_B*_*.gd`,
  `test_pack_10_E10_together_cards.gd`), the AI's
  (`tests/ai/test_ai_pack_10_*.gd`, each with a null arm) and the SGManalink
  scripts (`tests/unit/test_sgmanalink_pack_10_*.gd`), all inside the gate
  below.
- The gate (`SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh`): 1,339 scripts,
  18,246 tests, 808,581 asserts. Ten failed, in two groups. Three were the
  damage-gate surveys' reading-pins the pack changes, re-taken with the new
  writers named: prevention pools 29 → 32 (Sanctum Custodian, Serra's
  Hymn, Field Surgeon and Master Healer), source-filtered immunities 14 →
  15 (Angelic Curator and Yavimaya Scion), combat shields 15 → 16 (Redeem)
  and the Circle family 13 → 14 (the Runes of Protection). Seven
  (`test_pad_controls.gd` ×6, `test_fullscreen_card_text_2026_10_10.gd`
  ×1) fail only because a physical gamepad was plugged into the machine
  (`PadControls.is_active` follows the hardware). Those four scripts were
  re-run with the gamepad hidden from the process (`bwrap --dev-bind / /
  --tmpfs /dev/input --tmpfs /run/udev`): 66 of 66.
- Python (`python3 -m unittest discover -s tools -p 'test_*.py'`): 949
  tests, 15 skipped, OK. `git diff --check` clean.
- The duel audit: 432 complete duels, no stall, error or refused try (see
  "AI review"). The soaks, every run exit 0 with no error or warning line:
  `tools/pack_10_ui_soak.gd --count 5 --mode both` in each rules profile
  (10 duels each), 15 human-seat seeds per profile, and the stock
  `tools/duel_soak.sh` both ways (6 duels each). Over the human seat's
  duels the screen took up 102 cycles, 11 library-top plays, 2 graveyard
  plays, 4 gang blocks and 4 damage divisions under Defensive Formation, 9
  Serra's Hymns with verses and 70 divided-target picks; the graveyard play
  and the Formation division are the thinnest flows.
- The export probe: `./build_release.sh` exported and smoke-booted the
  Linux build; with the real ZIP and an isolated profile it printed `PACK
  10 EXPORT RESOURCES OK — 1506 identities; 609/609 dormant scripts loaded;
  1272/1272 artwork pictures and 1218/1218 skin fallbacks decoded; 9/9 UI
  textures; 0 rules pending`, and `--verify-pack-9` still `PACK 9 EXPORT
  RESOURCES OK — 1498 identities`.

## Reproduce the checks

Use the repository's isolated profile, never the player's settings or
decks (an absolute `SHANDALAR_TEST_DATA_HOME`; a relative one is ignored):

```sh
SHANDALAR_TEST_DATA_HOME="$PWD/../shandalar-build/pack-10-work/gate-testdata" \
  SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
git diff --check

. tools/runtime.sh
shandalar_find_godot
shandalar_find_timeout
shandalar_test_profile
export SHANDALAR_PACK_10="$PWD/../shandalar-packs/Pack-10-Urza-Block.zip"
"$SHANDALAR_TIMEOUT" -k 5 5400 "$GODOT" --headless --path . \
  --script res://tools/pack_10_duel_audit.gd -- --rounds 12 --seed 99000 --pilots both
xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 1500 "$GODOT" --path . \
  -s res://tools/pack_10_ui_soak.gd -- --rules modern --count 5 --mode both --pace 0
xvfb-run -a "$SHANDALAR_TIMEOUT" -k 5 2400 "$GODOT" --path . \
  -s res://tools/pack_10_ui_soak.gd -- --rules modern --mode human --pace 0 \
  --seeds 2000,2037,2074,2111,2148,2185,2222,2259,2296,2333,2370,2407,2444,2481,2518
# Repeat both with --rules fifth; also ./tools/duel_soak.sh --rules modern
# and --rules fifth.

DeckLab/deck_lab.sh --deck-a p10_graveyard.deck --deck-b p10_burn.deck --packs 10 \
  --games 200 --seed 99100 --sweep forecasts_tactics=on,off \
  --control-deck-a control_vanilla_white.deck --control-deck-b control_vanilla_green.deck \
  --no-elo --out ../shandalar-build/pack-10-work/lab-graveyard
# And p10_artifacts v p10_white_weenie (99200), p10_echo v p10_enchantress
# (99300), p10_tricks v p10_cycling (99400), p10_white_weenie v p10_opal
# (99500), p10_burn v p10_graveyard (99600).

./build_release.sh --out ../shandalar-build/pack-10-work/linux64
# With the real ZIP in SHANDALAR_PACK_10 and an isolated XDG_DATA_HOME:
../shandalar-build/pack-10-work/linux64/Shandalar.x86_64 --headless -- --verify-pack-10
```

The audit's nine themed decks are the `DECKS` table of
`tools/pack_10_duel_audit.gd`; the study's `p10_*.deck` files are those
lists, and the two `control_vanilla_*.deck` files the lists under "AI
review", written one `count name` per line. With four shards the suite
needs a longer per-shard guard than the default 30 minutes
(`SUITE_TIMEOUT=3600`).

## Acceptance record — 2026-11-06

- **Gate** (`SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh`): 1,339 scripts,
  18,246 tests, 808,581 asserts; the three survey re-takes and the seven
  gamepad-only failures under "Verification", their four scripts then 66 of
  66.
- **Python**: 949 tests, 15 skipped, OK.
- **Duel audit**: 432 complete duels, no stall, error or refused try, after
  the Serra's Hymn and Temporal Aperture fixes.
- **Deck Lab**: the six study rows under "AI review", none significantly
  worse; the Control Vanilla pair byte-identical in every arm.
- **Export probe**: `PACK 10 EXPORT RESOURCES OK — 1506 identities`, and
  Pack 9's probe unchanged.
- **Counts**: core + Pack 10 1,518 set entries / 1,506 unique cards; all
  ten packs 4,704 / 3,684 (pinned in `test_pack_10_catalogue.gd` and
  `test_sgmanalink_packs.gd`).
- **SGManalink**: protocol 31 (a permitted library top card is a card of
  the view, `library_top`; a face says when a zone permission covers it,
  `zone_playable`), `RULES_REVISION` `sgmanalink-urza-block-2026-11-06`.
- **Version**: 0.60.19; the pack's `minimum_game_version` is 0.60.19.
