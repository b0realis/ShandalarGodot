# The 1997 decks, ported — `decks/1997/`, `decks/tournament/`, `decks/community/`, `decks/extended_community/`

**2026-09-02.** The preconstructed decks of MicroProse's 1997 *Magic: The
Gathering* — every group the mtg.wiki page
[*Magic: The Gathering (MicroProse) Preconstructed Decks*](https://mtg.wiki/page/Magic:_The_Gathering_(MicroProse)_Preconstructed_Decks)
lists — shipped as `.deck` files this project can load, pick, duel, gauntlet
and Deck-Lab, plus three groups that are NOT MicroProse's: the period's
**tournament** lists (Worlds 1994–97, the 1996 Pro Tours), the
**community**'s own decks (The Deck's versions, Necro, Sligh… and the
Shandalar community's re-tuned enemies), and the **extended community**
lists (Old School 93/94 archetype references that lean on cards outside
the pool). Ported, never invented: every list is a transcription of a named
source, every file says which, and every place a source disagreed with
another is written down here.

The brief's rules, kept: **local 1997 files outrank the web** for the card
lists; **the wiki page is the authority for the grouping**, its names and
its partition; nothing was dropped silently — a card the pool does not hold
goes through the loader's proxy path and is listed below; **no card was
implemented** for this; `cards/` and `engine/` are untouched; the five
starter decks in `decks/*.deck` are untouched.

## The groups, the counts, and where each came from

| Folder | Heading (`# group:`) | Decks | Source of the lists | Cross-check |
|---|---|---|---|---|
| `decks/1997/originals/` | `1997 originals` | **55** | `../s30/assets/configs/rogues/<enemy>.toml` (`main_cards`, `sideboard_cards`, `level`) [Tier 3]; `../shandalar-src/Decks.zip:Decks/<id>.dck` — the **1997 prefix only** and its `.vNone`/`.v<Colour>` sections [Tier 3, see *Decks.zip* below]; `../mage-go/rogue_dck/<enemy>.dck` [Tier 3] | The three local copies agree 55/55. mtg.wiki `Shandalar_Enemy_Decks_(<tier>)` "Original": maindeck agrees 55/55, sideboard 53/55 (see *Sideboards*) |
| `decks/1997/ancients/` | `Spells of the Ancients` | **55** | `../shandalar-src/Program/decks/<id>.dck` — the *Spells of the Ancients* (1997) enemy files the Manalink tree carries in the 1997 `Program/` directory [Tier 1 carrier, Tier 3 tree] | mtg.wiki "(Spells of the Ancients)": 54/55 agree; Warlock differs (local wins, see below); Merfolk Shaman `0150.dck` is a Manalink replacement, so that one list is the wiki's |
| `decks/1997/duels/` | `Duels of the Planeswalkers` | **25** | mtg.wiki `Shandalar_Enemy_Decks_(<tier>)` "(Duels of the Planeswalkers)" [Tier-web] — **no local copy of the Duels enemy files exists** in `../shandalar-src`, `../s30` or `../mage-go` | files.mtg.wiki `.DCK` screenshots for Sorceress, Cleric and Arzakon |
| `decks/1997/coyote_tex/` | `Coyote Tex's decks` | **5** | `../mage-go/data/preconstructed_decks.yaml` `shandalar.player_decks.coyote_tex` [Tier 3] | mtg.wiki `Shandalar_Player_Decks_(Coyote_Tex)`: 5/5 agree card for card |
| `decks/1997/kevin_bane/` | `Kevin Bane's decks` | **8** | same yaml, `player_decks.kevin_bane` [Tier 3] | mtg.wiki `Shandalar_Player_Decks_(Kevin_Bane)`: 8/8 agree; 7 of the 22 play decks also have a `.DCK` screenshot on files.mtg.wiki |
| `decks/1997/other/` | `Other MicroProse decks` | **9** | same yaml, `player_decks.other` [Tier 3] | mtg.wiki `Shandalar_Player_Decks_(Other)`: 9/9 agree |
| `decks/tournament/` | `Tournament decks` | **76** | mtg.wiki event pages (Worlds 1994 Top 4 + Other, Worlds 1995 Top 8, Worlds 1996 Standard + Classic, Worlds 1997 Standard + Extended, PT New York 1996 Standard, PT Dallas 1996 Standard, Pro Tour Collector Set, Tommi Hovi) [Tier-web]; Stephen Menendian's *Old School Magic* chapters on vintagemagic.com for PT Dallas 1996 Classic, Origins 1995, Sorcerer's Open 1995 and the four Old School community-event decks [Tier-web] — no local copy exists for any of them | 8 Pro Tour Collector Set decks also in the yaml (`pro_tour_collector_set.decks`): 6/8 agree, 2 differ (see below); Menendian's Dolan 1994, Lestrée 1994 and Weissman 1996 lists agree with the wiki card for card |
| `decks/community/` | `Community decks` | **64** | mtg.wiki archetype pages (5) [Tier-web]; Menendian chapters 1, 2, 3, 11 (20) [Tier-web]; Abe Sargent's *Kitchen Table* #278/279/280/281/289/296 on StarCityGames, the "Modified" list of each Shandalar enemy deck (39) [Tier-web] | Sargent's "Initial" lists checked against `decks/1997/originals/` card for card; each file's `# base:` names the original it re-tunes |
| `decks/extended_community/` | `Extended community decks` | **15** | Menendian chapters 2, 3, 5, 6, 7, 9, 11, 12 (14) and mtg.wiki The Deck (Weissman's 2018 Old School version) [Tier-web] | — |
| | | **312** | | |

The 22 "Play Deck" decks (Coyote Tex, Kevin Bane, Other) are player decks
*Duels of the Planeswalkers* installed in its `Play Deck` folder but never
offered in-game — the precon page: *"users would need to open the game's
files and move them into a different directory"*. The wiki is the authority
for the partition into three designers, so they are three headings.

The whole port is pinned by `tests/unit/test_decks_1997.gd`: the counts
above, every file through the real loader (`DeckList.load_file`, lenient,
no parse errors; `DeckStore.load_deck`), sizes within the duel's limits,
every MicroProse deck strict-loadable and gauntlet-legal, and the three
non-MicroProse groups proxied exactly as the tables below say — which of
their files are proxy-free (the gauntlet deals those) and, per name the
pool does not hold, how many decks want it.

### What a deck file carries

Every file opens with comment lines the loader skips (`DeckList.parse`
ignores `#` lines): the deck's original name and its place; `# tier:` /
`# enemy:` / `# variant:` for an enemy deck; `# designer:`; one
`# source:` line per source with its provenance tier; `# cross-check:`
lines; then the `# group:` declaration `DeckGroups` reads, `name:`, the
cards, and `SB:` lines for the sideboard. The non-MicroProse files open
with `TOURNAMENT DECK`, `COMMUNITY / PERIOD DECK` or `EXTENDED COMMUNITY
DECK — not a MicroProse deck`, carry `# archetype:`, `# pilot:` /
`# event:` / `# year:` / `# place:` (tournament) or `# designer:` /
`# year:` (the other two), a `# caveat:` line for anything the reader
should know (an odd maindeck size, a missing sideboard, a list the wiki
marks unconfirmed or reconstructed, a community event that was not
DCI-sanctioned), and a `# base:` line on the Shandalar community decks
naming the original they re-tune. What ships is the LIST — names and
counts in this project's own format — not the original `.dck` files.

## The enemy tiers (the wiki's table, `# tier:` in each file)

| Tier | Heading | Life | Bribe | Enemies |
|---|---|---|---|---|
| 1 | Weak enemies | 10 | 40 gold | Cleric, Druid, Seer, Sorceress, Witch |
| 2 | Aggro enemies | 12 | 40 gold | Elvish Magi, Merfolk Shaman, Priestess, Sorcerer, Undead Knight |
| 3 | Typical enemies | 14 | 60 gold | Conjurer, Crusader, Enchantress, Troll Shaman, Warlock |
| 4 | Two-color Lesser enemies | 16 | 70 gold | Elementalist, Fungus Master, Guardian of the Tusk, Mind Stealer, Sedge Beast |
| 5 | Intermediate enemies | 18 | 80 gold | Forest Dragon, Goblin Warlord, Paladin, Sea Drake, Vampire Lord |
| 6 | The Genies | 19 | 80 gold | Aga Galneer, Alt-A-Kesh, Queltosh, Saltrem Tor |
| 7 | Two-color greater enemies | 20 | 100 gold | Ape Lord, Centaur Shaman, Centaur Warchief, Lord of Fate, Winged Stallion |
| 8 | Strong enemies | 22 | 100 gold | Arch Angel, Beast Master, Crag Hydra, Nether Fiend, Shapeshifter |
| 9 | The Dragons | 24 | 110 gold | Dracur, Kiska-Ra, Mandurang, Prismat, Whim |
| 10 | The Henchmen | up to 27 | can't be bribed | High Priest, Necromancer, Summoner, Thought Invoker, War Mage |
| 11 | The Guildlords | 35 to 45 | can't be bribed | Astral Visionary, Azaar - Lichlord, Great Druid, Kzzy'n - The Dragon Lord, Sainted One |
| 12 | Arzakon | set by the difficulty | can't be bribed | Arzakon |

Designer of every enemy deck: Coyote Tex, MicroProse designer/producer
(precon page, ref. 2). The 25 enemies with a *Duels of the Planeswalkers*
variant on the wiki: Arch Angel, Arzakon, Beast Master, Centaur Warchief,
Cleric, Dracur, Druid, Elementalist, Elvish Magi, Goblin Warlord, Great
Druid, Mandurang, Merfolk Shaman, Mind Stealer, Nether Fiend, Paladin,
Priestess, Queltosh, Saltrem Tor, Shapeshifter, Sorceress, Summoner, Undead
Knight, War Mage, Warlock.

## How the 1997 sideboards were folded

A 1997 enemy `.dck` has a maindeck and then colour-keyed sections —
`.vNone` (always in), `.vBlack` / `.vBlue` / `.vGreen` / `.vRed` /
`.vWhite` (swapped in against a player of that colour). Our format has one
sideboard. The fold: **main = the 1997 maindeck + `.vNone`**; **`SB:` = per
card name, the largest count it has in any of the five colour sections,
less its `.vNone` count**. The file's tail comment reproduces the section
table so the original swap logic is not lost. This differs from the wiki's
"Sideboard" on two decks — Sainted One (wiki 2 Disenchant, ours 1) and
Forest Dragon (wiki 2 Wall of Brambles, ours 1) — because the wiki adds
sections up where ours takes the maximum; the file's own sections are the
record, and each file notes the difference.

The expansion decks (`ancients/`, `duels/`) and the play decks have no
colour sections (the wiki says the expansion decks used none), so they
ship without `SB:` lines.

## Discrepancies — every one, with the choice made

Rule: the local 1997 file wins over the web; between local copies, the one
closest to 1997 wins; the loser is written down.

- **`../shandalar-src/Decks.zip` is a 2016 Manalink artefact, not a 1997
  file.** Its entries are dated 2016-02-15. Each `Decks/<id>.dck` is the
  1997 maindeck as a PREFIX (it equals s30's `main_cards` line for line)
  followed by a modern deck Manalink appended — 60 or so cards of
  Modern-era names. Only the prefix is shipped (`main`); the tail is
  recorded per file as the count of lines not taken. Before this was
  noticed, the "Original" lists agreed with the wiki 0/55; after it,
  55/55. `Decks/0150.dck` (Merfolk Shaman) is a full replacement with no
  1997 prefix, so its Original list is s30's (which mage-go matches).
  `Provenance.md` records the demotion.
- **`Program/decks/0150.DCK` (Merfolk Shaman, *Spells of the Ancients*)
  is likewise a Manalink replacement** (Tundra, Triton Shorestalker,
  Master of the Pearl Trident… a *Type 1* header over a modern deck).
  That one SotA list is the wiki's, flagged in the file header.
- **Warlock, *Spells of the Ancients*: the local file lists `4 Fear`
  twice** — 64 cards, 8 Fear. The wiki gives 60 cards with one `4 Fear`.
  Local wins: the file ships 64 cards with `8 Fear` (the loader sums
  duplicate lines) and its tail comment says so.
- **Arzakon, Original: 138 cards.** The wiki's prose says "107". The
  138 is what the local files hold (s30, Decks.zip prefix, mage-go all
  agree, and the wiki's own list adds up to it). The SotA Arzakon is 66,
  the Duels Arzakon 137.
- **Sizes are not all 60.** The originals run 60-66 (21 decks over 60);
  SotA 56-68 (Elvish Magi 56, Kzzy'n 58, Astral Visionary 58, Sorceress
  59); Duels 59-63 (Nether Fiend 59); play decks 60-64. The
  non-MicroProse lists run 40-66 as their sources print them — two 1993-94
  lists are forty cards (legal then), Menendian prints several of
  Weissman's versions at 58 or 59 — and every size that is not 60 is
  flagged in the file's `# caveat:` line. Shipped as the sources have them.
- **Enemy names.** s30's `Advstrings.txt` `@CREATURENAMES` (the 1997
  in-game names) differ from the s30 config / Decks.zip / wiki names for
  seven enemies: Sea Drake (1997 *Sea Dragon*), Crag Hydra (*Hydra*),
  Guardian of the Tusk (*Tusk Guardian*), Beast Master (*Beastmaster*),
  Goblin Warlord (*Goblin Lord*), Azaar - Lichlord (*Greater Lich*),
  Kzzy'n - The Dragon Lord (*Dragon Lord*). The deck's `name:` is the
  wiki's (the grouping authority); the `# enemy:` line carries the 1997
  in-game name. Alt-A-Kesh is spelled as the wiki's enemy page and
  `Advstrings.txt` spell it (the precon page writes *Alt-a-Kesh*).
- **SotA file headers name three enemies differently:** `Great Hydra`
  for Crag Hydra, `Kiska Ra` for Kiska-Ra, and `Climatic Battle` for
  Arzakon's deck. The files ship under the file's own name with the
  wiki's suffix — `Climatic Battle (Spells of the Ancients)` — and the
  `# enemy:` line says whose it is.
- **Duels of the Planeswalkers: 25 of 55.** The wiki lists a Duels
  variant for 25 enemies only, and no local source has any. 25 is the
  true count; nothing was invented for the other 30.
- **Pro Tour Collector Set, yaml vs wiki.** Loconto: yaml 63 cards =
  wiki 62 +2 Plains −1 Island. Tam: yaml 59 = wiki 60 −1 Plains. The
  wiki list is shipped (the yaml is a transcription of the same
  source); both files record the diff.
- **Wiki `The Thought Invoker`** is the enemy `Thought Invoker` — a
  leading "the" the matching strips.
- **Card-name spellings** the sources use that the pool spells
  otherwise were mapped, never dropped: `Will-o-wisp` → Will-o'-the-Wisp,
  `T.Island` / `V.Island` → Tropical / Volcanic Island, `Wizard's
  School` → Wizards' School, and the like. After the mapping every
  MicroProse deck is proxy-free.

## What could not be sourced

The precon page's community section names archetypes whose wiki pages
carry **no decklist**: Erhnamgeddon (as an archetype page — two PTCS
Erhnamgeddon decks ARE shipped), Prison, Zoo, Land Tax, Millstone,
Counterpost. Fetched, read, nothing usable, nothing invented. The Reddit
thread on the precon decks was a pointer only; nothing was taken from it.
No true 1997 enemy `.dck` file exists anywhere locally — what exists is
the 1997 lists carried inside Manalink's, s30's and mage-go's files.

When the non-MicroProse groups were widened (2026-09-02, the owner's
follow-up: "13 decks is thin"), these were looked for and NOT shipped,
each for the reason given — a deck goes in only with a citable list:

- **Worlds 1995 Schildt and Wang** — the wiki page gives their
  sideboards only. **PT Dallas 1996 Thornburg and Kröger** — partial
  lists on the page.
- **Limited events** (PT Los Angeles, Atlanta and Columbus 1996, PT New
  York 1997, Chalice's 1996 draft deck) — draft decks, not constructed
  lists anyone would pick.
- **PT Chicago, Paris and Mainz 1997, Worlds 1998** (Rubin, Hacker,
  Selden, Buehler's Draw-Go) and **Weissman's 1998+ versions** — outside
  the 1994–97 window the brief set.
- **Deadguy Ale** — the wiki's list is from 2005; the 1997 original is
  described, not listed. **The Sligh page's later lists** — post-1997.
- **Old School archetypes with no citable text list anywhere fetched**:
  Atog Aggro, Troll Disco, Lion Dib Lift, Old School White Weenie, Mono
  Black, Parfait, Titania's Song combo, Distress. (Ernhamgeddon and Tax
  Edge are covered by period tournament decks; Power Monolith, Robots,
  Electric Eel, UR Burn / Underworld Dreams, Zoo, The Deck, Prison and
  Reanimator by the extended group.) oldschool-mtg.blogspot and Eternal
  Central print their lists as images; Menendian's *History of Vintage*
  is paywalled; neither was transcribed.
- **Shandalar / Manalink community favourites**: the Slightly Magic
  forum's "Shandalar Strategies" thread gives approximate lists ("6 or 7
  Tundra", "not verbatim"); reddit refused scripted access (an
  interstitial on both old.reddit and the `.json` endpoint); Manalink's
  `Decks.zip` tails are unattributed replacements. Nothing taken from any
  of them. Sargent's 2009 series is the one Shandalar-community source
  that prints lists, and it is shipped whole.
- **Sargent's "Updated" lists** (modern cards) and his **"Initial"**
  lists (the 1997 originals themselves, used only as a cross-check) are
  not shipped; he printed no Modified **Warlock**.

## `decks/tournament/` — Tournament decks (76)

Real event lists with a pilot, an event and a year: the World Championship
1994–97 pages, Pro Tour New York 1996 (the eight Pro Tour Collector Set
decks among them) and Pro Tour Dallas 1996 on mtg.wiki, plus the few
other sanctioned-event lists Menendian's *Old School Magic* chapters print
(Pro Tour Dallas 1996 Type I Classic, Origins 1995, the 1995 Sorcerer's
Open) and one from the wiki's Tommi Hovi page (Finnish Nationals 1996).
Per the owner's tie-break rule, an Old School 93/94 list that was ALSO an
event deck is filed here with its archetype in the header — the last four
rows are Old School community events (n00bcon, Eternal Weekend, Eternal
Central), NOT DCI-sanctioned tournaments, and their `# caveat:` line says
so; move them if that reads wrong. Placings are stated only where the
source states them; "competitor" means the page lists the deck without a
finish. The lists ship as the source prints them (maindeck sizes 56–66,
each odd size flagged in a `# caveat:` line).

| File | Pilot | Place | Event | Year | Archetype | Source | Proxies | Notes |
|---|---|---|---|---|---|---|---|---|
| `ptcs_loconto.deck` | Michael Loconto | 1st (champion) | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | U/W Millstone control | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 13 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_lestree.deck` | Bertrand Lestrée | 2nd (finalist) | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | Erhnamgeddon (G/W) | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 9 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_poulter.deck` | Preston Poulter | semifinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | Erhnamgeddon (G/W) | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 9 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_lindback.deck` | Leon Lindback | semifinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | Necropotence (mono-black) | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 13 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_baxter.deck` | George Baxter | quarterfinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | B/R/G Necro-Erhnam | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 11 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_tam.deck` | Eric Tam | quarterfinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | R/G/W Erhnam control | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 16 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_regnier.deck` | Shawn "Hammer" Regnier | quarterfinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | U/W Millstone control | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 9 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptcs_justice.deck` | Mark Justice | quarterfinalist | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | R/W Winter Orb / Howling Mine prison | [mtg.wiki PTCS](https://mtg.wiki/page/Pro_Tour_Collector_Set) | 12 | Pro Tour Collector Set (1996) printing of the Top 8 deck |
| `ptny1996_tatomer.deck` | Graham Tatomer | competitor | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | Necropotence (mono-black) | [mtg.wiki PT NY 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks) | 6 |  |
| `ptny1996_sclafani.deck` | Ross Sclafani | competitor | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | R/W control | [mtg.wiki PT NY 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks) | 7 | the wiki marks this list a RECONSTRUCTION; no sideboard given |
| `ptny1996_suver.deck` | Max Suver | competitor | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | R/W Land Tax / Winter Orb ("Tax-Bind") | [mtg.wiki PT NY 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks) | 12 |  |
| `ptny1996_kline.deck` | Aaron Kline | competitor | Pro Tour New York (Pro Tour 1), February 1996 — Standard | 1996 | White Weenie | [mtg.wiki PT NY 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks) | 7 | 57-card maindeck as the wiki lists it |
| `wc1994_dolan.deck` | Zak Dolan | 1st (champion) | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | U/W Stasis control (Serra Angel, Old Man of the Sea, Stasis, Kismet) | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 1 |  |
| `wc1994_lestree.deck` | Bertrand Lestrée | 2nd (finalist) | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | proto-Zoo (Kird Ape, Serendib Efreet, Channel-Fireball) | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 1 | 61-card maindeck as the wiki lists it |
| `wc1994_symens.deck` | Dominic Symens | Top 4 | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | U/W/g control | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 1 |  |
| `wc1994_defoucaud.deck` | Cyrille de Foucaud | Top 4 | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | G/W/u midrange | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 1 | 66-card maindeck as the wiki lists it |
| `wc1994_rosewater.deck` | Mark Rosewater | competitor | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | U/G small-creature aggro ("Mark's little deck") | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 0 |  |
| `wc1994_bulmahn.deck` | Jason Bulmahn | competitor | World Championship 1994 (Gen Con, Milwaukee), August 1994 | 1994 | B/R aggro | [mtg.wiki Worlds 1994 Top 4](https://mtg.wiki/page/1994_World_Championships/Top_4_Decks) | 0 |  |
| `wc1995_blumke.deck` | Alexander Blumke | 1st (champion) | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | B/W Hymn–Hypnotic Specter / Land Tax control | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 9 | 63-card maindeck as the wiki lists it |
| `wc1995_hernandez.deck` | Marc Hernandez | 2nd (finalist) | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | U/W/r Millstone control | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 4 | 62-card maindeck as the wiki lists it |
| `wc1995_justice.deck` | Mark Justice | Top 8 (semifinalist) | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | R/G Erhnam–Armageddon | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 10 | the wiki marks this list UNCONFIRMED; 64-card maindeck as the wiki lists it |
| `wc1995_stern.deck` | Henry Stern | Top 8 (semifinalist — Menendian, ch. 1) | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | R/G Black Vise aggro | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 12 | 63-card maindeck as the wiki lists it |
| `wc1995_curina.deck` | Ivan Curina | Top 8 | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | G/W/u midrange | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 7 | 62-card maindeck as the wiki lists it |
| `wc1995_redi.deck` | Andrea Redi | Top 8 | World Championship 1995 (Seattle), August 1995 — Type 2 | 1995 | R/x aggro-burn | [mtg.wiki Worlds 1995 Top 8](https://mtg.wiki/page/1995_World_Championships/Top_8_decks) | 10 |  |
| `wc1996_chanpheng.deck` | Tom Chanpheng | 1st (champion) | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | White Weenie | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 12 |  |
| `wc1996_justice.deck` | Mark Justice | 2nd (finalist) | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Necropotence | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 13 |  |
| `wc1996_rade.deck` | Olle Råde | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Erhnamgeddon | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 8 |  |
| `wc1996_place.deck` | Matt Place | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Erhnamgeddon | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 7 |  |
| `wc1996_tam.deck` | Eric Tam | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Erhnamgeddon / burn ("Ernham Burn'em") | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 14 |  |
| `wc1996_stern.deck` | Henry Stern | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Necropotence | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 12 |  |
| `wc1996_johns.deck` | Scott Johns | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Necropotence | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 11 |  |
| `wc1996_hovi.deck` | Tommi Hovi | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | Turbo Stasis | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 12 |  |
| `wc1996_ekebom.deck` | Erno Ekebom | competitor | World Championship 1996 (Seattle), August 1996 — Standard | 1996 | U/x aggro-control | [mtg.wiki Worlds 1996 Standard](https://mtg.wiki/page/1996_World_Championships/Standard_decks) | 9 |  |
| `wc1996_classic_johns.deck` | Scott Johns | competitor | World Championship 1996 (Seattle), August 1996 — Classic Restricted (Type 1) portion | 1996 | R/W/u aggro-burn ("Star Spangled Slaughter") | [mtg.wiki Worlds 1996 Other](https://mtg.wiki/page/1996_World_Championships/Other_decks) | 8 | 56-card maindeck as the wiki lists it |
| `wc1996_classic_toszegi.deck` | Tószegi Szabolcz | competitor | World Championship 1996 (Seattle), August 1996 — Classic Restricted (Type 1) portion | 1996 | W/x weenie ("Surprise....you're Dead!") | [mtg.wiki Worlds 1996 Other](https://mtg.wiki/page/1996_World_Championships/Other_decks) | 4 | 61-card maindeck as the wiki lists it; no sideboard given |
| `wc1997_slemr.deck` | Jakub Šlemr | 1st (champion) | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Five-Color Black | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 21 |  |
| `wc1997_kuhn.deck` | Janosch Kühn | 2nd (finalist) | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | U/R tempo ("Speed Control") | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 13 |  |
| `wc1997_maher.deck` | Bob Maher | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Four-Color Black | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 24 |  |
| `wc1997_mccabe.deck` | Paul McCabe | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | U/R tempo ("Canadian Beatdown") | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 20 |  |
| `wc1997_geertsen.deck` | Svend Geertsen | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Stompy (mono-green) | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 13 |  |
| `wc1997_kim.deck` | Kim Ju-Neon | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Sligh | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 16 |  |
| `wc1997_donais.deck` | Jeff Donais | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Sligh ("Gamma World" Forsaken Sligh) | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 15 |  |
| `wc1997_kearney.deck` | Dave Kearney | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | CounterPost | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 13 |  |
| `wc1997_wong.deck` | Ivan Wong | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | CounterPost | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 14 |  |
| `wc1997_hovi.deck` | Tommi Hovi | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Stasis / Jokulhaups control ("SqStasis'Haups") | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 14 |  |
| `wc1997_chinnock.deck` | John Chinnock | competitor | World Championship 1997 (Seattle), August 1997 — Standard | 1997 | Necropotence (beatdown) | [mtg.wiki Worlds 1997 Standard](https://mtg.wiki/page/1997_World_Championships/Standard_decks) | 14 |  |
| `wc1997_ext_slemr.deck` | Jakub Šlemr | 1st (champion of the event; this is his Extended deck) | World Championship 1997 (Seattle), August 1997 — Extended | 1997 | White Weenie ("Czech Gun") | [mtg.wiki Worlds 1997 Extended](https://mtg.wiki/page/1997_World_Championships/Extended_decks) | 15 |  |
| `wc1997_ext_wong.deck` | Ivan Wong | competitor | World Championship 1997 (Seattle), August 1997 — Extended | 1997 | White Weenie (R/U/W) | [mtg.wiki Worlds 1997 Extended](https://mtg.wiki/page/1997_World_Championships/Extended_decks) | 8 |  |
| `wc1997_ext_tsang.deck` | Gabriel Tsang | competitor | World Championship 1997 (Seattle), August 1997 — Extended | 1997 | CounterPost | [mtg.wiki Worlds 1997 Extended](https://mtg.wiki/page/1997_World_Championships/Extended_decks) | 11 |  |
| `wc1997_ext_justice.deck` | Mark Justice | competitor | World Championship 1997 (Seattle), August 1997 — Extended | 1997 | Tax-Edge (Land Tax / Land's Edge) — the Old School "Tax Edge" archetype | [mtg.wiki Worlds 1997 Extended](https://mtg.wiki/page/1997_World_Championships/Extended_decks) | 12 |  |
| `wc1997_ext_kuhn.deck` | Janosch Kühn | 2nd (finalist of the event; this is his Extended deck) | World Championship 1997 (Seattle), August 1997 — Extended | 1997 | U/R/w Counter-Burn (Abeyance) | [mtg.wiki Worlds 1997 Extended](https://mtg.wiki/page/1997_World_Championships/Extended_decks) | 10 |  |
| `ptdallas1996_mccabe.deck` | Paul McCabe | 1st (champion) | Pro Tour Dallas, November 1996 — Standard | 1996 | Necropotence | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 15 |  |
| `ptdallas1996_tao.deck` | Yubin Tao | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Counter-Post | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 11 | 61-card maindeck as the wiki lists it |
| `ptdallas1996_moungey.deck` | Jason Moungey | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Green midrange | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 13 |  |
| `ptdallas1996_falcone.deck` | Vinnie Falcone | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Green midrange | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 12 |  |
| `ptdallas1996_jansen.deck` | Adam Jansen | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Green midrange | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 13 | 64-card maindeck as the wiki lists it |
| `ptdallas1996_tan.deck` | Joseph Tan | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Green midrange ("Budgee") | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 12 | 63-card maindeck as the wiki lists it |
| `ptdallas1996_simoneau.deck` | Jeff Simoneau | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Necropotence | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 12 |  |
| `ptdallas1996_hacker.deck` | Brian Hacker | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Necropotence / mono-black aggro | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 10 |  |
| `ptdallas1996_pikula.deck` | Chris Pikula (with Worth Wollpert) | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Necropotence ("Pikulapotence") | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 12 |  |
| `ptdallas1996_radonjic.deck` | Peter Radonjic | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Necropotence ("Canadian Style") | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 14 |  |
| `ptdallas1996_zila.deck` | Jason Zila | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Prison (Winter Orb / Icy Manipulator) | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 13 | 61-card maindeck as the wiki lists it |
| `ptdallas1996_schneider.deck` | Justin Schneider | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Prison (Winter Orb / Icy Manipulator) | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 14 | 62-card maindeck as the wiki lists it |
| `ptdallas1996_baca.deck` | Jeremy Baca (with George Baxter) | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Prison / white control ("White Trash") | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 7 | 61-card maindeck as the wiki lists it |
| `ptdallas1996_chapin.deck` | Patrick Chapin | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Sligh | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 11 |  |
| `ptdallas1996_genestreti.deck` | Stefano Genestreti | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | Sligh (R/G "Green Geeba") | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 16 | 61-card maindeck as the wiki lists it |
| `ptdallas1996_rade.deck` | Olle Råde | competitor | Pro Tour Dallas, November 1996 — Standard | 1996 | U/R counter-burn | [mtg.wiki PT Dallas 1996 Standard](https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks) | 14 |  |
| `ptdallas1996_classic_johns.deck` | Scott Johns | 1st | Pro Tour Dallas, November 1996 — the Classic (Type 1) tournament | 1996 | Zoo ("Turbo Zoo") — the Old School Zoo archetype | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 6 | 58-card maindeck as Menendian prints it |
| `ptdallas1996_classic_shwe.deck` | Huei-Saint Shwe | 2nd | Pro Tour Dallas, November 1996 — the Classic (Type 1) tournament | 1996 | Zoo — the Old School Zoo archetype | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 14 | 65-card maindeck as Menendian prints it |
| `finnats1996_hovi.deck` | Tommi Hovi | as the wiki's Tommi Hovi page lists it (no placing given) | Finnish National Championship 1996 | 1996 | Turbo Stasis | [mtg.wiki Tommi Hovi](https://mtg.wiki/page/Tommi_Hovi) | 4 |  |
| `origins1995_justice.deck` | Mark Justice | 1st (Menendian: "Origins '95 Type I winner") | Origins 1995 Type I tournament | 1995 | Prison control (Winter Orb / Icy Manipulator) — the Old School Prison archetype | [Menendian, Old School ch. 12](https://www.vintagemagic.com/blog/old-school-magic-chapter-12-building-a-stronger-prison/) | 1 |  |
| `sorcerers_open1995_hogan.deck` | Chip Hogan | 1st (Menendian: "1995 Sorcerer's Open winning decklist") | "Sorcerer's Open" 1995 (Type I) | 1995 | Blue Prison — the Old School Prison archetype | [Menendian, Old School ch. 12](https://www.vintagemagic.com/blog/old-school-magic-chapter-12-building-a-stronger-prison/) | 1 |  |
| `noobcon2014_stalin.deck` | "Stalin" | 1st | n00bcon 2014 (Old School 93/94 community championship, Gothenburg) | 2014 | Electric Eel / UR aggro — the Old School "Electric Eel" archetype (93/94 format) | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 0 | Old School 93/94 community event, not a DCI-sanctioned tournament |
| `noobcon2016_berlin.deck` | Martin Berlin | 1st | n00bcon 2016 (Old School 93/94 community championship, Gothenburg) | 2016 | The Deck (Old School 93/94) | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 0 | Old School 93/94 community event, not a DCI-sanctioned tournament; 58-card maindeck as Menendian prints it |
| `ew2016_menendian.deck` | Stephen Menendian | 2nd | Eternal Central Old School tournament at Eternal Weekend, October 2016 | 2016 | UR Aggro-Control (Old School 93/94) | [Menendian, Old School ch. 8](https://www.vintagemagic.com/blog/old-school-magic-chapter-8-2nd-place-at-eternal-weekend-2016-with-blue-red-aggro-control/) | 1 | Old School 93/94 community event, not a DCI-sanctioned tournament |
| `ec2015_beckert.deck` | Justin Beckert | as Menendian prints it (he calls the performance "remarkable"; no placing given) | Eternal Central Old School event, 2015 | 2015 | Underworld Dreams / Winds of Change combo (Old School 93/94) | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 0 | Old School 93/94 community event, not a DCI-sanctioned tournament |

## `decks/community/` — Community decks (64)

Period decks that were not event lists: the five archetype lists the
wiki gives (The Deck 1996, Necro 1996, Sligh "Geeba", Turbo Stasis, Señor
Stompy), the eight dated versions of Brian Weissman's The Deck that
Menendian's chapter 2 prints (April 1994 to February 1997), the period
lists his chapters 1, 3 and 11 print with a designer and a date (Wright,
Montesanti, Robaina, Edwards, Merritt, Justice, Baxter, Dolan, Chalice,
Hyra), and the Shandalar community's own: Abe Sargent's 39 "Modified"
enemy decks from his 2009 StarCityGames *Kitchen Table* series (#278–281,
#289, #296), each a re-tune of one 1997 enemy deck for the game's own card
pool — every one proxy-free, and each file's `# base:` line names the
`decks/1997/originals/` deck it re-tunes (Sargent's "Initial" lists were
checked against those originals card for card; where his enemy name is
the s30 name — Azaar, Morgane, Hydra, Kyzz'n, Sea Dragon, Tusk Guardian —
the header says which shipped original it is). Sargent printed no
Modified Warlock, so there is none. Where an archetype list is
unattributed (Necro, Turbo Stasis, Stompy) the designer column says so.

| File | Deck | Designer | Year | Archetype | Source | Proxies | Notes |
|---|---|---|---|---|---|---|---|
| `the_deck_weissman_1996.deck` | The Deck (Weissman, 1996) | Brian Weissman | 1996 | control ("The Deck") | [mtg.wiki The Deck](https://mtg.wiki/page/The_Deck) | 1 |  |
| `necropotence_1996.deck` | Necropotence (1996 Type 2) | the Necro-summer of 1996 (list as the wiki gives it) | 1996 | Necro (mono-black Necropotence) | [mtg.wiki Necropotence deck](https://mtg.wiki/page/Necropotence_deck) | 6 |  |
| `sligh_geeba_1996.deck` | Sligh (Geeba, 1996) | Jay Schneider (piloted by Paul Sligh) | 1996 | Sligh (mono-red curve aggro) | [mtg.wiki Sligh](https://mtg.wiki/page/Sligh) | 9 |  |
| `turbo_stasis.deck` | Turbo Stasis (1996) | the 1996 Type 2 metagame (list as the wiki gives it) | 1996 | Stasis / prison | [mtg.wiki Turbo Stasis](https://mtg.wiki/page/Turbo_Stasis) | 9 |  |
| `senor_stompy.deck` | Señor Stompy (1997) | the 1997 Type 2 metagame (list as the wiki gives it) | 1997 | Stompy (mono-green aggro) | [mtg.wiki Stompy](https://mtg.wiki/page/Stompy) | 10 |  |
| `the_deck_weissman_1994_04.deck` | The Deck (Weissman, April 1994) | Brian Weissman | April 1994 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 1 |  |
| `the_deck_weissman_1994_fall.deck` | The Deck (Weissman, Fall 1994 — "Protection deck") | Brian Weissman | Fall 1994 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 0 | 59-card maindeck as Menendian prints it |
| `the_deck_weissman_1994_95_winter.deck` | The Deck (Weissman, Winter 1994–95) | Brian Weissman | Winter 1994–95 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 0 |  |
| `the_deck_weissman_1995_05.deck` | The Deck (Weissman, May 1995) | Brian Weissman | May 1995 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 1 |  |
| `the_deck_weissman_1996_02.deck` | The Deck (Weissman, February 1996) | Brian Weissman | February 1996 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 0 | 59-card maindeck as Menendian prints it |
| `the_deck_weissman_1996_summer.deck` | The Deck (Weissman, Summer 1996) | Brian Weissman | Summer 1996 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 0 | 58-card maindeck as Menendian prints it |
| `the_deck_weissman_1996_11.deck` | The Deck (Weissman, November 1996) | Brian Weissman | November 1996 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 6 |  |
| `the_deck_weissman_1997_02.deck` | The Deck (Weissman, February 1997) | Brian Weissman | February 1997 | The Deck — Brian Weissman's control deck, the version he published for that date (Menendian, "The History of The Deck") | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 8 |  |
| `explosion_wright_1994.deck` | Explosion (Granville Wright, October 1994) | Granville Wright | October 1994 | Channel-Fireball / burn ("Granville's Explosion Deck") | [Menendian, Old School ch. 1](https://www.vintagemagic.com/blog/back-to-the-future-an-introduction-to-old-school-magic/) | 0 | 59-card maindeck as Menendian prints it |
| `necro_montesanti_1996.deck` | Type I Necro (Paul Montesanti, Summer 1996) | Paul Montesanti | Summer 1996 | Necropotence (Type I) | [Menendian, Old School ch. 1](https://www.vintagemagic.com/blog/back-to-the-future-an-introduction-to-old-school-magic/) | 1 |  |
| `monkey_robaina_1996.deck` | The Monkey Deck (Mario Robaina, 1996) | Mario Robaina | 1996 | Zoo (Kird Ape) — "The Monkey Deck" | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 4 |  |
| `proto_zoo_edwards.deck` | Proto-Zoo (Rudy Edwards, 1993–94) | Rudy Edwards | 1993–94 (Menendian: "the era of Wild Magic") | Zoo (Kird Ape) — a 40-card "Wild Magic"-era list | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 0 | 40-card deck as Menendian prints it (40-card decks were legal in 1993–94) |
| `twist_of_fire_merritt_1993.deck` | Twist of Fire (Steven Merritt, 1993) | Steven Merritt | 1993 | Fireball / Twiddle-Basalt Monolith combo | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 0 | 40-card deck as Menendian prints it |
| `winds_of_chains_justice.deck` | Winds of Chains (Mark Justice, mid-1990s) | Mark Justice | mid-1990s (Menendian: "the heyday of Type 1"; no exact date given) | Underworld Dreams / Winds of Change combo | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 3 |  |
| `lich_baxter_1995.deck` | Charles' Lich Deck (George Baxter, 1995) | George Baxter | 1995 | Lich / Mirror Universe combo | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 0 |  |
| `looping_dolan_1996.deck` | The Looping Deck (Zak Dolan, May 1996) | Zak Dolan | May 1996 | recursion combo (The Duelist #10) | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 | 61-card maindeck as Menendian prints it; no sideboard given |
| `churning_dolan_1996.deck` | The Churning Deck (Zak Dolan, May 1996) | Zak Dolan | May 1996 | recursion / sacrifice combo (The Duelist #10) | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 | 57-card maindeck as Menendian prints it; no sideboard given |
| `fork_recursion_chalice_1995.deck` | Fork Recursion (Mark Chalice, c. February 1995) | Mark Chalice | c. February 1995 | Fork / recursion combo | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 | no sideboard given |
| `vercursion_chalice_1995.deck` | Vercursion (Mark Chalice, Fall 1995) | Mark Chalice | Fall 1995 | Verduran Enchantress recursion combo | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 3 | no sideboard given |
| `turn_one_terror_hyra_1995.deck` | Turn One Terror (Matt Hyra, 1994–95) | Matt Hyra | 1994–95 (won "a string of local tournaments" in the Seattle area — Menendian) | Dark Ritual / Juzám Djinn aggro | [Menendian, Old School ch. 1](https://www.vintagemagic.com/blog/back-to-the-future-an-introduction-to-old-school-magic/) | 0 | 56-card deck as Menendian prints it; no sideboard given |
| `sargent_2009_witch.deck` | Witch (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Witch" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/witch.deck` |
| `sargent_2009_vampire_lord.deck` | Vampire Lord (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Vampire Lord" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/vampire_lord.deck` |
| `sargent_2009_undead_knight.deck` | Undead Knight (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Undead Knight" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/undead_knight.deck` |
| `sargent_2009_nether_fiend.deck` | Nether Fiend (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Nether Fiend" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/nether_fiend.deck` |
| `sargent_2009_necromancer.deck` | Necromancer (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Necromancer" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/necromancer.deck` |
| `sargent_2009_azaar.deck` | Azaar (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Azaar" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #280](https://articles.starcitygames.com/articles/the-kitchen-table-280-black-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/azaar_lichlord.deck` |
| `sargent_2009_druid.deck` | Druid (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Druid" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/druid.deck` |
| `sargent_2009_enchantress.deck` | Enchantress (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Enchantress" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/enchantress.deck` |
| `sargent_2009_forest_dragon.deck` | Forest Dragon (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Forest Dragon" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/forest_dragon.deck` |
| `sargent_2009_elvish_magi.deck` | Elvish Magi (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Elvish Magi" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/elvish_magi.deck` |
| `sargent_2009_beast_master.deck` | Beast Master (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Beast Master" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/beast_master.deck` |
| `sargent_2009_summoner.deck` | Summoner (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Summoner" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/summoner.deck` |
| `sargent_2009_morgane.deck` | Morgane (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Morgane" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #278](https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/) | 0 | re-tunes `decks/1997/originals/great_druid.deck` |
| `sargent_2009_sorceress.deck` | Sorceress (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Sorceress" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/sorceress.deck` |
| `sargent_2009_goblin_warlord.deck` | Goblin Warlord (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Goblin Warlord" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/goblin_warlord.deck` |
| `sargent_2009_sorcerer.deck` | Sorcerer (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Sorcerer" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/sorcerer.deck` |
| `sargent_2009_troll_shaman.deck` | Troll Shaman (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Troll Shaman" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/troll_shaman.deck` |
| `sargent_2009_hydra.deck` | Hydra (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Hydra" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/crag_hydra.deck` |
| `sargent_2009_war_mage.deck` | War Mage (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "War Mage" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/war_mage.deck` |
| `sargent_2009_kyzzn.deck` | Kyzz'n (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Kyzz'n" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #279](https://articles.starcitygames.com/articles/the-kitchen-table-279-red-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/kzzy_n_the_dragon_lord.deck` |
| `sargent_2009_conjurer.deck` | Conjurer (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Conjurer" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/conjurer.deck` |
| `sargent_2009_seer.deck` | Seer (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Seer" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/seer.deck` |
| `sargent_2009_merfolk_shaman.deck` | Merfolk Shaman (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Merfolk Shaman" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/merfolk_shaman.deck` |
| `sargent_2009_sea_dragon.deck` | Sea Dragon (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Sea Dragon" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/sea_drake.deck` |
| `sargent_2009_shapeshifter.deck` | Shapeshifter (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Shapeshifter" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/shapeshifter.deck` |
| `sargent_2009_thought_invoker.deck` | Thought Invoker (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Thought Invoker" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/thought_invoker.deck` |
| `sargent_2009_astral_visionary.deck` | Astral Visionary (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Astral Visionary" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #281](https://articles.starcitygames.com/articles/the-kitchen-table-281-blue-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/astral_visionary.deck` |
| `sargent_2009_priestess.deck` | Priestess (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Priestess" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/priestess.deck` |
| `sargent_2009_cleric.deck` | Cleric (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Cleric" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/cleric.deck` |
| `sargent_2009_paladin.deck` | Paladin (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Paladin" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/paladin.deck` |
| `sargent_2009_crusader.deck` | Crusader (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Crusader" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/crusader.deck` |
| `sargent_2009_arch_angel.deck` | Arch Angel (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Arch Angel" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/arch_angel.deck` |
| `sargent_2009_high_priest.deck` | High Priest (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "High Priest" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/high_priest.deck` |
| `sargent_2009_sainted_one.deck` | Sainted One (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Sainted One" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #289](https://articles.starcitygames.com/articles/the-kitchen-table-289-white-shandalar-decks/) | 0 | re-tunes `decks/1997/originals/sainted_one.deck` |
| `sargent_2009_tusk_guardian.deck` | Tusk Guardian (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Tusk Guardian" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #296](https://articles.starcitygames.com/articles/the-kitchen-table-296-shandalar-allied-multicolor-decks/) | 0 | re-tunes `decks/1997/originals/guardian_of_the_tusk.deck` |
| `sargent_2009_ape_lord.deck` | Ape Lord (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Ape Lord" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #296](https://articles.starcitygames.com/articles/the-kitchen-table-296-shandalar-allied-multicolor-decks/) | 0 | re-tunes `decks/1997/originals/ape_lord.deck` |
| `sargent_2009_sedge_beast.deck` | Sedge Beast (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Sedge Beast" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #296](https://articles.starcitygames.com/articles/the-kitchen-table-296-shandalar-allied-multicolor-decks/) | 0 | re-tunes `decks/1997/originals/sedge_beast.deck` |
| `sargent_2009_mind_stealer.deck` | Mind Stealer (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Mind Stealer" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #296](https://articles.starcitygames.com/articles/the-kitchen-table-296-shandalar-allied-multicolor-decks/) | 0 | re-tunes `decks/1997/originals/mind_stealer.deck` |
| `sargent_2009_winged_stallion.deck` | Winged Stallion (Sargent, 2009) | Abe Sargent | 2009 | the Shandalar enemy "Winged Stallion" deck, re-tuned within the Shandalar card pool | [Sargent, Kitchen Table #296](https://articles.starcitygames.com/articles/the-kitchen-table-296-shandalar-allied-multicolor-decks/) | 0 | re-tunes `decks/1997/originals/winged_stallion.deck` |

## `decks/extended_community/` — Extended community decks (15)

Old School 93/94 archetype reference lists — the archetypes the owner
named for which a citable list exists only as a modern (2014–18) Old
School reconstruction — and two Reanimator lists that lean on cards
outside the pool. Zoo, The Deck (Buehler's and Weissman's 2018 version),
Tinker/Transmute control, Big Blue Artifacts, Workshop aggro ("Robots"),
UR Aggro-Control ("Electric Eel"), Reanimator, Dreams combo, Power
Artifact ("Power Monolith"), Time Vault prison, Recursion combo, Prison
and Blue Prison. They are what the archetype looks like with the 93/94
pool; a duel with them needs cards this project does not have, hence the
group.

| File | Deck | Designer | Year | Archetype | Source | Proxies | Notes |
|---|---|---|---|---|---|---|---|
| `os_zoo_menendian_2016.deck` | Old School Zoo (Menendian, May 2016) | Stephen Menendian | May 2016 | Zoo — Old School 93/94 reference list | [Menendian, Old School ch. 3](https://www.vintagemagic.com/blog/old-school-magic-chapter-3-a-visit-to-the-zoo/) | 1 |  |
| `os_the_deck_buehler_2015.deck` | The Deck (Randy Buehler, August 2015) | Randy Buehler | August 2015 | The Deck — Old School 93/94 reference list | [Menendian, Old School ch. 2](https://www.vintagemagic.com/blog/old-school-magic-chapter-2-the-history-of-the-deck/) | 1 |  |
| `os_the_deck_weissman_2018.deck` | The Deck (Weissman, 2018 Old School) | Brian Weissman | 2018 | The Deck — Old School 93/94 reference list | [mtg.wiki The Deck](https://mtg.wiki/page/The_Deck) | 2 |  |
| `os_tinker_the_deck_menendian_2014.deck` | The Tinker The Deck (Menendian, May 2014) | Stephen Menendian | May 2014 | Transmute / Tinker control ("The Weissman Tinker Deck") — Old School 93/94 reference list | [Menendian, Old School ch. 5](https://www.vintagemagic.com/blog/old-school-magic-chapter-5-new-strategies-for-the-old-school-the-transmute-control-deck/) | 1 |  |
| `os_big_blue_artifacts_christiansen.deck` | Big Blue Artifacts (Blaine Christiansen) | Blaine Christiansen | c. 2014–15 (undated in the article; chapter 5) | Transmute Artifact control ("Big Blue") — Old School 93/94 reference list | [Menendian, Old School ch. 5](https://www.vintagemagic.com/blog/old-school-magic-chapter-5-new-strategies-for-the-old-school-the-transmute-control-deck/) | 1 |  |
| `os_workshop_aggro_menendian.deck` | Mono Brown Workshop Aggro (Menendian) | Stephen Menendian | c. 2016 (undated in the article; chapter 6) | Mishra's Workshop artifacts ("Robots") — Old School 93/94 reference list | [Menendian, Old School ch. 6](https://www.vintagemagic.com/blog/old-school-magic-chapter-6-banning-and-restricting-in-old-school/) | 0 | 61-card maindeck as Menendian prints it; no sideboard given |
| `os_ur_aggro_control_menendian_2015.deck` | UR Aggro-Control (Menendian, August 2015) | Stephen Menendian | August 2015 | Electric Eel / UR aggro-control — Old School 93/94 reference list | [Menendian, Old School ch. 7](https://www.vintagemagic.com/blog/old-school-magic-chapter-7-new-strategies-for-the-old-school-blue-red-aggro-control/) | 1 |  |
| `reanimator_comer_1997.deck` | The Re-Animator (Alan Comer, August 1997) | Alan Comer | August 1997 | Reanimator — the USENET post that named the archetype (period list, 9 cards outside our pool) | [Menendian, Old School ch. 9](https://www.vintagemagic.com/blog/old-school-magic-chapter-9-reanimator-rises-to-the-top/) | 9 | 63-card maindeck as Menendian prints it |
| `os_reanimator_1995_menendian.deck` | "1995" Reanimator (Menendian) | Stephen Menendian | c. 2016 (undated in the article; chapter 9) | Reanimator — Old School 93/94 reference list | [Menendian, Old School ch. 9](https://www.vintagemagic.com/blog/old-school-magic-chapter-9-reanimator-rises-to-the-top/) | 8 | 61-card maindeck as Menendian prints it |
| `os_dreams_combo_menendian_2015.deck` | Dreams Combo (Menendian, September 2015) | Stephen Menendian | September 2015 | Underworld Dreams combo — Old School 93/94 reference list | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 |  |
| `os_power_artifact_menendian_2016.deck` | Power Artifact Combo (Menendian, February 2016) | Stephen Menendian | February 2016 | Power Monolith (Power Artifact / Basalt Monolith) combo — Old School 93/94 reference list | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 | 59-card maindeck as Menendian prints it |
| `os_time_vault_prison_menendian_2015.deck` | Time Vault Prison (Menendian, October 2015) | Stephen Menendian | October 2015 | Time Vault / Stasis prison combo — Old School 93/94 reference list | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 1 | no sideboard given |
| `os_recursion_combo_menendian_2017.deck` | Recursion Combo (Menendian, March 2017) | Stephen Menendian | March 2017 | Verduran Enchantress / Forgotten Lore recursion combo — Old School 93/94 reference list | [Menendian, Old School ch. 11](https://www.vintagemagic.com/blog/old-school-magic-chapter-11-the-untold-history-of-combo-in-old-school/) | 6 | 59-card maindeck as Menendian prints it |
| `os_prison_menendian.deck` | Prison (Menendian) | Stephen Menendian | c. 2017 (undated in the article; chapter 12) | Prison (Winter Orb / Icy Manipulator / Relic Barrier) — Old School 93/94 reference list | [Menendian, Old School ch. 12](https://www.vintagemagic.com/blog/old-school-magic-chapter-12-building-a-stronger-prison/) | 1 |  |
| `os_blue_prison_menendian_2017.deck` | Blue Prison (Menendian, 2017) | Stephen Menendian | 2017 | Blue Prison — Old School 93/94 reference list | [Menendian, Old School ch. 12](https://www.vintagemagic.com/blog/old-school-magic-chapter-12-building-a-stronger-prison/) | 1 |  |

## Proxied cards, per group

Every MicroProse group — originals, ancients, duels, coyote_tex,
kevin_bane, other — is **proxy-free: 0 cards** across 157 decks (the
loader test pins it). The three non-MicroProse groups are pinned by name
and count in `tests/unit/test_decks_1997.gd` (`PROXY_FREE`, `PROXIED`):
implement one of these cards and the test fails, which is the moment to
strike it here and there, and to move any deck that just became
proxy-free into the proxy-free list. The Old School lists proxy mostly
one name, Chaos Orb, which the pool does not hold.

### Tournament decks: 198 distinct names, 749 deck-mentions, 71 of 76 decks affected

Proxy-free (the gauntlet deals these): `wc1994_rosewater.deck`, `wc1994_bulmahn.deck`, `noobcon2014_stalin.deck`, `noobcon2016_berlin.deck`, `ec2015_beckert.deck`.

| Card | Decks |
|---|---|
| Zuran Orb | 42 |
| Serrated Arrows | 29 |
| Incinerate | 24 |
| Pyroblast | 22 |
| Adarkar Wastes | 13 |
| Kjeldoran Outpost | 13 |
| Hymn to Tourach | 12 |
| Karplusan Forest | 12 |
| Thawing Glaciers | 12 |
| Anarchy | 11 |
| Dystopia | 11 |
| Hydroblast | 11 |
| Necropotence | 11 |
| Brushland | 10 |
| Contagion | 10 |
| Force of Will | 10 |
| Jester's Cap | 10 |
| Knight of Stromgald | 10 |
| Stormbind | 10 |
| Demonic Consultation | 9 |
| Infernal Darkness | 9 |
| Hammer of Bogardan | 8 |
| Order of Leitbur | 8 |
| Pillage | 8 |
| Pyroclasm | 8 |
| Ruins of Trokair | 8 |
| Arcane Denial | 7 |
| Chaos Orb | 7 |
| Dark Banishing | 7 |
| Order of the Ebon Hand | 7 |
| Political Trickery | 7 |
| Undiscovered Paradise | 7 |
| Abeyance | 6 |
| Deadly Insect | 6 |
| Dissipate | 6 |
| Enlightened Tutor | 6 |
| Fyndhorn Elves | 6 |
| Lhurgoyf | 6 |
| Mystical Tutor | 6 |
| Order of the White Shield | 6 |
| Orgg | 6 |
| Sulfurous Springs | 6 |
| Wildfire Emissary | 6 |
| Aeolipile | 5 |
| Autumn Willow | 5 |
| Blinking Spirit | 5 |
| Guerrilla Tactics | 5 |
| Ihsan's Shade | 5 |
| Jokulhaups | 5 |
| Marble Diamond | 5 |
| Phyrexian Furnace | 5 |
| Spectral Bears | 5 |
| Choking Sands | 4 |
| Despotic Scepter | 4 |
| Dwarven Ruins | 4 |
| Energy Storm | 4 |
| Forsaken Wastes | 4 |
| Gorilla Shaman | 4 |
| Honorable Passage | 4 |
| Impulse | 4 |
| Lodestone Bauble | 4 |
| Pyrokinesis | 4 |
| Quicksand | 4 |
| Underground River | 4 |
| Abbey Gargoyles | 3 |
| Dance of the Dead | 3 |
| Elkin Bottle | 3 |
| Eron the Relentless | 3 |
| Exile | 3 |
| Fireblast | 3 |
| Frenetic Efreet | 3 |
| Gemstone Mine | 3 |
| Havenwood Battleground | 3 |
| Icequake | 3 |
| Jolrael's Centaur | 3 |
| Kaervek's Torch | 3 |
| Lake of the Dead | 3 |
| Lava Tubes | 3 |
| Man-o'-War | 3 |
| Nekrataal | 3 |
| Sea Sprite | 3 |
| Soul Burn | 3 |
| Stupor | 3 |
| Suq'Ata Lancer | 3 |
| Tithe | 3 |
| Tranquil Domain | 3 |
| Apocalypse Chime | 2 |
| Arenson's Aura | 2 |
| Binding Grasp | 2 |
| Brainstorm | 2 |
| City of Solitude | 2 |
| Dwarven Catapult | 2 |
| Dwarven Miner | 2 |
| Ebon Stronghold | 2 |
| Emerald Charm | 2 |
| Essence Filter | 2 |
| Fallen Askari | 2 |
| Hallowed Ground | 2 |
| Knight of the Mists | 2 |
| Land Cap | 2 |
| Mind Warp | 2 |
| Moss Diamond | 2 |
| Necratog | 2 |
| Orcish Librarian | 2 |
| Phyrexian War Beast | 2 |
| Rainbow Efreet | 2 |
| Sand Golem | 2 |
| Seeds of Innocence | 2 |
| Serenity | 2 |
| Shadow Guildmage | 2 |
| Sky Diamond | 2 |
| Stromgald Cabal | 2 |
| Svyelunite Temple | 2 |
| Uktabi Orangutan | 2 |
| Viashino Sandstalker | 2 |
| Abduction | 1 |
| An-Zerrin Ruins | 1 |
| Aura of Silence | 1 |
| Aysen Bureaucrats | 1 |
| Balduvian Trading Post | 1 |
| Barbed Sextant | 1 |
| Bottomless Vault | 1 |
| Bounty of the Hunt | 1 |
| Cloud Elemental | 1 |
| Coercion | 1 |
| Crypt Rats | 1 |
| Death Spark | 1 |
| Death Speakers | 1 |
| Deflection | 1 |
| Diminishing Returns | 1 |
| Disrupt | 1 |
| Dwarven Hold | 1 |
| Dwarven Soldier | 1 |
| Ebony Charm | 1 |
| Empyrial Armor | 1 |
| Equipoise | 1 |
| Fire Diamond | 1 |
| Gerrard's Wisdom | 1 |
| Glacial Crevasses | 1 |
| Goblin Mutant | 1 |
| Goblin Tinkerer | 1 |
| Goblin Vandal | 1 |
| Granger Guildmage | 1 |
| Grassland | 1 |
| Hall of Gemstone | 1 |
| Harvest Wurm | 1 |
| Heart of Yavimaya | 1 |
| Icatian Town | 1 |
| Illumination | 1 |
| Jeweled Amulet | 1 |
| Johtull Wurm | 1 |
| Kaervek's Spite | 1 |
| Lava Hounds | 1 |
| Lim-Dûl's Vault | 1 |
| Mangara's Blessing | 1 |
| Martyrdom | 1 |
| Memory Lapse | 1 |
| Mind Bend | 1 |
| Mind Stone | 1 |
| Mountain Valley | 1 |
| Ophidian | 1 |
| Orcish Cannoneers | 1 |
| Orcish Lumberjack | 1 |
| Orcish Spy | 1 |
| Pacifism | 1 |
| Pale Bears | 1 |
| Primitive Justice | 1 |
| Prismatic Ward | 1 |
| Pygmy Allosaurus | 1 |
| Quirion Ranger | 1 |
| Ray of Command | 1 |
| Reinforcements | 1 |
| Reprisal | 1 |
| Ring of Renewal | 1 |
| River Boa | 1 |
| River Delta | 1 |
| Rogue Elephant | 1 |
| Sheltered Valley | 1 |
| Snow-Covered Mountain | 1 |
| Snow-Covered Plains | 1 |
| Snow-Covered Swamp | 1 |
| Soldevi Digger | 1 |
| Soldevi Excavations | 1 |
| Soul Echo | 1 |
| Squandered Resources | 1 |
| Steel Golem | 1 |
| Stench of Decay | 1 |
| Storm Shaman | 1 |
| Straw Golem | 1 |
| Sunstone | 1 |
| Tidal Wave | 1 |
| Timberline Ridge | 1 |
| Torture | 1 |
| Truce | 1 |
| Withering Wisps | 1 |
| Wizards' School | 1 |
| Woolly Spider | 1 |
| Zur's Weirding | 1 |

### Community decks: 44 distinct names, 65 deck-mentions, 16 of 64 decks affected

Proxy-free (the gauntlet deals these): `the_deck_weissman_1994_fall.deck`, `the_deck_weissman_1994_95_winter.deck`, `the_deck_weissman_1996_02.deck`, `the_deck_weissman_1996_summer.deck`, `explosion_wright_1994.deck`, `proto_zoo_edwards.deck`, `twist_of_fire_merritt_1993.deck`, `lich_baxter_1995.deck`, `turn_one_terror_hyra_1995.deck`, `sargent_2009_witch.deck`, `sargent_2009_vampire_lord.deck`, `sargent_2009_undead_knight.deck`, `sargent_2009_nether_fiend.deck`, `sargent_2009_necromancer.deck`, `sargent_2009_azaar.deck`, `sargent_2009_druid.deck`, `sargent_2009_enchantress.deck`, `sargent_2009_forest_dragon.deck`, `sargent_2009_elvish_magi.deck`, `sargent_2009_beast_master.deck`, `sargent_2009_summoner.deck`, `sargent_2009_morgane.deck`, `sargent_2009_sorceress.deck`, `sargent_2009_goblin_warlord.deck`, `sargent_2009_sorcerer.deck`, `sargent_2009_troll_shaman.deck`, `sargent_2009_hydra.deck`, `sargent_2009_war_mage.deck`, `sargent_2009_kyzzn.deck`, `sargent_2009_conjurer.deck`, `sargent_2009_seer.deck`, `sargent_2009_merfolk_shaman.deck`, `sargent_2009_sea_dragon.deck`, `sargent_2009_shapeshifter.deck`, `sargent_2009_thought_invoker.deck`, `sargent_2009_astral_visionary.deck`, `sargent_2009_priestess.deck`, `sargent_2009_cleric.deck`, `sargent_2009_paladin.deck`, `sargent_2009_crusader.deck`, `sargent_2009_arch_angel.deck`, `sargent_2009_high_priest.deck`, `sargent_2009_sainted_one.deck`, `sargent_2009_tusk_guardian.deck`, `sargent_2009_ape_lord.deck`, `sargent_2009_sedge_beast.deck`, `sargent_2009_mind_stealer.deck`, `sargent_2009_winged_stallion.deck`.

| Card | Decks |
|---|---|
| Zuran Orb | 9 |
| Pyroblast | 4 |
| Chaos Orb | 3 |
| Force of Will | 3 |
| Hydroblast | 3 |
| Gorilla Shaman | 2 |
| Hymn to Tourach | 2 |
| Mystical Tutor | 2 |
| Necropotence | 2 |
| Adarkar Wastes | 1 |
| An-Zerrin Ruins | 1 |
| Arcane Denial | 1 |
| Bounty of the Hunt | 1 |
| Dark Banishing | 1 |
| Despotic Scepter | 1 |
| Dwarven Lieutenant | 1 |
| Dwarven Miner | 1 |
| Dwarven Ruins | 1 |
| Dwarven Trader | 1 |
| Forgotten Lore | 1 |
| Fyndhorn Elves | 1 |
| Harvest Wurm | 1 |
| Heart of Yavimaya | 1 |
| Icequake | 1 |
| Ihsan's Shade | 1 |
| Incinerate | 1 |
| Jester's Cap | 1 |
| Jolrael's Centaur | 1 |
| Lhurgoyf | 1 |
| Lim-Dûl's Vault | 1 |
| Lodestone Bauble | 1 |
| Merchant Scroll | 1 |
| Mesmeric Trance | 1 |
| Orcish Cannoneers | 1 |
| Orcish Librarian | 1 |
| Order of the Ebon Hand | 1 |
| Quirion Ranger | 1 |
| Rogue Elephant | 1 |
| Sand Golem | 1 |
| Serrated Arrows | 1 |
| Spectral Bears | 1 |
| Uktabi Orangutan | 1 |
| Underground River | 1 |
| Vampiric Tutor | 1 |

### Extended community decks: 21 distinct names, 35 deck-mentions, 14 of 15 decks affected

Proxy-free (the gauntlet deals these): `os_workshop_aggro_menendian.deck`.

| Card | Decks |
|---|---|
| Chaos Orb | 13 |
| Ashen Ghoul | 2 |
| Deep Spawn | 2 |
| Crimson Hellkite | 1 |
| Dance of the Dead | 1 |
| Demonic Consultation | 1 |
| Forgotten Lore | 1 |
| Glacial Chasm | 1 |
| Hydroblast | 1 |
| Hymn to Tourach | 1 |
| Incinerate | 1 |
| Jester's Cap | 1 |
| Krovikan Horror | 1 |
| Necromancy | 1 |
| Polar Kraken | 1 |
| Pyroblast | 1 |
| Shallow Grave | 1 |
| Underground River | 1 |
| Vampiric Tutor | 1 |
| Zur's Weirding | 1 |
| Zuran Orb | 1 |
## Where they are wired

- **`DeckStore.all_deck_paths()`** walks the shipped subfolders after the
  five top-level starters (`shipped_subfolder_paths`, `subfolders_of`), so
  `all_deck_paths()[0]` is still `big_green.deck` and `deck_paths_in
  (SHIPPED_DIR)` still means the starters. `user://decks` is never walked
  below its top level.
- **`DeckGroups`** grew from four headings to eleven — `ANCIENTS`,
  `COYOTE_TEX`, `KEVIN_BANE`, `OTHER`, then `TOURNAMENT`, `COMMUNITY`,
  `EXTENDED_COMMUNITY` — in `ORDER`. Each file declares its heading with
  `# group:`; the pickers and the Deck Lab read `ORDER`, so the three
  headings appeared in all of them without a line of picker code.
- **Battle setup screen** (`game/setup_screen.gd`): the picker shows each
  deck under its group's separator using the deck's own `name:`
  (`_deck_titles`); a proxy deck is listed "(N proxy)" and refused, as
  before.
- **Gauntlet** (`game/duel/gauntlet_screen.gd`): the default roster is
  `default_roster()` — every deck the store sees that a round would not
  refuse (strict load, `GauntletState.opponent_deck_problem`). **[QoL]**
  The 1997 rule is "every `.dck` in the directory"; ours also holds 101
  always-proxy decks in the three non-MicroProse groups, and dealt blind
  they ended most twenty-round runs on a deck nobody chose. The roster is
  216: the five starters, the 157 MicroProse decks and the 54 proxy-free
  non-MicroProse decks (five tournament, 48 community — the 39 Sargent
  decks among them — one extended). An explicit roster is taken as
  given. The Gauntlet Options `Your deck` picker is grouped like the
  setup screen's.
- **Deck Builder** `Load Deck` list: a heading row per group. And, since
  2026-09-04, **the ported decks cannot be written over or shadowed**:
  saving under one of their names becomes a save-as. That is the manual's
  own rule (p.148, *"If you load and change one of the creature decks used
  in the full game, you must save your version of the deck under a new
  name."*), and it is what keeps this whole document's work meaningful —
  a `Cleric` in `user://decks` beside `decks/1997/originals/cleric.deck`
  would leave the sources in that file's header attached to a deck that is
  no longer the one they describe. The guard reads BOTH the file name and
  the `name:` title, because 233 of the 317 files carry a title that does
  not slugify to their file name (`wc1996_rade.deck` is *"Råde — Worlds
  1996 (Erhnamgeddon)"*) and the list shows the title.
  `game/deck_builder/deck_store.gd` ("provenance: the shipped decks"),
  pinned by `tests/ui/test_deck_provenance.gd`.
- **Deck Lab** (`tools/simulate.gd`, `docs/deck-lab.md`): `--group` takes
  all eleven headings (`tournament`, `community`, `extended_community`
  among them); with `--group` a DIR is walked into its subfolders
  (`--gauntlet decks/ --group originals` is the 55, `--group community`
  the 48 proxy-free community decks); without it a DIR is its own files,
  so the default field is still the five starters. A DIR deck with
  proxies is skipped with a stderr note.

## Web sources (registered as Tier-web in `Provenance.md`)

- https://mtg.wiki/page/Magic:_The_Gathering_(MicroProse)_Preconstructed_Decks — the grouping authority
- https://mtg.wiki/page/Shandalar_Enemy_Decks_(Weak) … `(Aggro)`, `(Typical)`, `(Lesser)`, `(Intermediate)`, `(Genies)`, `(Greater)`, `(Strong)`, `(Dragons)`, `(Henchmen)`, `(Guildlords)`, `(Arzakon)` — Original / SotA / Duels lists per enemy
- https://mtg.wiki/page/Shandalar_Player_Decks_(Coyote_Tex), `(Kevin_Bane)`, `(Other)`
- https://mtg.wiki/page/The_Deck, https://mtg.wiki/page/Necropotence_deck, https://mtg.wiki/page/Sligh, https://mtg.wiki/page/Turbo_Stasis, https://mtg.wiki/page/Stompy, https://mtg.wiki/page/Pro_Tour_Collector_Set
- https://mtg.wiki/page/1994_World_Championships/Top_4_Decks, https://mtg.wiki/page/1995_World_Championships/Top_8_decks, https://mtg.wiki/page/1996_World_Championships/Standard_decks, https://mtg.wiki/page/1996_World_Championships/Other_decks, https://mtg.wiki/page/1997_World_Championships/Standard_decks, https://mtg.wiki/page/1997_World_Championships/Extended_decks, https://mtg.wiki/page/1996_Pro_Tour_New_York/Standard_decks, https://mtg.wiki/page/1996_Pro_Tour_Dallas/Standard_decks, https://mtg.wiki/page/Tommi_Hovi — the tournament lists
- Stephen Menendian, *Old School Magic* (vintagemagic.com, 2015–17): chapter 1 https://www.vintagemagic.com/blog/back-to-the-future-an-introduction-to-old-school-magic/, ch. 2 …/old-school-magic-chapter-2-the-history-of-the-deck/, ch. 3 …/chapter-3-a-visit-to-the-zoo/, ch. 5 …/chapter-5-new-strategies-for-the-old-school-the-transmute-control-deck/, ch. 6 …/chapter-6-banning-and-restricting-in-old-school/, ch. 7 …/chapter-7-new-strategies-for-the-old-school-blue-red-aggro-control/, ch. 8 …/chapter-8-2nd-place-at-eternal-weekend-2016-with-blue-red-aggro-control/, ch. 9 …/chapter-9-reanimator-rises-to-the-top/, ch. 11 …/chapter-11-the-untold-history-of-combo-in-old-school/, ch. 12 …/chapter-12-building-a-stronger-prison/ (each file carries its full URL)
- Abe Sargent, *The Kitchen Table* (StarCityGames, 2009): https://articles.starcitygames.com/articles/the-kitchen-table-278-shandalar-green-decks/, …-279-red-shandalar-decks/, …-280-black-shandalar-decks/, …-281-blue-shandalar-decks/, …-289-white-shandalar-decks/, …-296-shandalar-allied-multicolor-decks/ — the 39 "Modified" Shandalar enemy decks
- files.mtg.wiki `.DCK` screenshots (Sorceress, Cleric, Arzakon; seven play decks) — corroboration only
