# Robustness and bug-hunt campaign — 2026-10-12

The owner, after 0.50.19: *"Lets do a robustness campaign and then a bug
hunt and bug fix campaign. After fixes commit and push 0.50.20 and then we
will rebuild."*

Eleven read-only hunters. Five tried to make the game FAIL — long play (over
1,100 headless games, about 1,170 Deck Lab games and 180 live-screen duels
with all nine packs), about 120,000 fuzzed input steps over every screen and
eight window sizes, hostile files and interrupted writes, a hostile network
and agent seat, the shipped packages on odd paths and long sessions. Six
hunted for wrong behaviour — a review of everything since 0.50.16, the deck
flows, rules interactions across the packs, the 558 card scripts no test
named, the computer opponent over about 1,450 measured duels, and the duel
screen and the words the game says. Every finding was reproduced by a probe
that failed on it: **105 findings (9 high)**; a few were the same defect seen
from two sides (the NUL constant four times, the long deck title twice, the
timing log in tool runs twice). Eleven fixers then worked on disjoint files
— two engine owners, two AI owners, the duel screen, menus and input,
settings, the deck flows, packs and skins, handhelds and the timing log, the
network and the agent tools — each turning its findings into permanent tests,
with the lead relaying the handovers between them.

New regression scripts (52 GUT, 3 Python) are listed in `docs/CODE_MAP.md`
under "The robustness campaign (2026-10-12)".

## The worst of what was found (the nine high)

- **One AI action rebuilt the whole duel screen once per engine change.** A
  big X spell tapping 25 lands rebuilt the board about 50 times inside one
  frame — 1.5 s and 430 MB held until the frame ended, an out-of-memory risk
  on a 1 GB handheld and a real source of the R36 stutter. The screen now
  redraws once per frame (55 ms and 8 MB for the same action).
- **The game deleted a player's own skin zip at start** when it refused it (a
  hand-made zip with one extra file, a half-finished copy) — written for the
  web build's fetched files. It is kept now, and Options › Skin says why it
  is not worn.
- **Pack card pictures were cached without a limit.** Browsing the Deck
  Builder with packs on climbed from 1.0 to 1.7 GB and never came back. They
  share the skin art's 256-picture limit now.
- **The AI's what-if preview corrupted the real game** when a move it tried
  made an Aura fall off (9 of about 1,600 stress duels): the Aura then went to
  the graveyard when its creature phased out.
- **Damage missed effects that applied only after another effect changed
  it** (CR 616.1e): Ali from Cairo at 4 life with Furnace of Rath out died to
  a Lightning Bolt instead of ending at 1.
- **The AI held back its creatures for a counterspell it could not pay** —
  Merfolk on one Island behind Counterspell, 274 turn-ends in 900 duels. The
  counter decks win about 3 points more often now.
- **A private hotseat's territory-menu Concede conceded the half that was
  right-clicked**, so Player 2 could give Player 1 the loss.
- **One bad character locked the MCP server.** Half an emoji in a tool call
  killed its worker; every later call went unanswered while `ping` still said
  it was alive.
- **A closing host never told its guests.** At the end of every duel the
  agent hosted, the person's game said "reconnecting…" forever. It now reads
  "The host closed its tables."

## Robustness: what holds now

- **Long play:** no stall, script error or leak in any soak; the slowest AI
  decision 96 ms headless. The refresh storm above was the one real failure;
  linked-target spells (Cannibalize) and abilities with no legal target no
  longer open a dead end.
- **Screens and input:** popups keep and hand back the keyboard/pad focus;
  Escape and the back button work on Help, Options, Card Packs and Magic
  Battle; the Controls page is no longer a trap with the pad pointer on; a pad
  unplugged mid-press is let go; the full-size card works with the
  controller pointer; overlays re-fit when the window changes size; the
  launch no longer prints "Unicode parsing error" (a NUL in a constant).
- **Files:** a settings value of the wrong type reads as meant or as its
  default; a broken or unsaveable settings file is said on the title and in
  Options; saves follow links, refuse read-only files and keep permissions;
  two copies of the game on one profile no longer undo each other; the Deck
  Lab's ratings file is written whole; a damaged pack copy can no longer pass
  as checked and is not re-read every start.
- **Network and agent tools:** malformed or hostile connections are shed in
  about a second and cost the host nothing; a UDP flood at discovery costs
  under a millisecond a frame; each network update costs a half to a quarter
  of what it did; a dead engine's end reaches the MCP client; invitation
  secrets stay off the command line and out of saved files.
- **Packages and handhelds:** the Quest scripts never leave half a zip, say
  "out of space", ignore a second adb device and name misnamed packs; the
  ArkOS launcher says why it stopped; the timing log stays out of the tools'
  output, counts nested work honestly and can be switched on on the Quest; a
  desktop whose V-Sync is refused is capped at the screen's rate.

## Rules fixes

- CR 616.1e / 614.5: the damage gates are rebuilt after each one applies.
- CR 609.7a: "a source of your choice" can name a source that has left play
  while its ability waits; such a source is read as it last existed (colour,
  types, controller) — Reflect Damage, Eye for an Eye and Honorable Passage
  hit the thief who sacrificed a stolen source.
- Mass removal and the state-based death batch judge every victim on the
  board as it stood before any left (`MtgGame.depart_together`).
- A creature that stops being a creature leaves combat (CR 506.4).
- A held trigger with one legal target per slot is not asked; a trampler
  that cannot get past its one blocker is not a damage question.
- Withering Wisps' activation limit; Fyndhorn Druid's "was blocked"; counter
  removals on Venarian Gold, Living Artifact, Cocoon and Tetravus.

## The AI

The counter reserve keyed to the cheapest payable counter and dropped under
board pressure; Dark Ritual only into a cast; a paid first strike read when
blocking; life gain by need; a Karoo's two mana spent where they fit (also
the human's auto-tap); cumulative-upkeep burn priced; Dream Halls and Aluren
held when they would help the opponent; big licid boards decided about twice
as fast; Gangrenous Zombies, Time Bomb, Goblin Lyre, Spoils of Evil, Forgotten
Lore and Gorilla War Cry used.

## Deck flows and the duel screen

Random decks in Magic Battle respect the format; a timed Booster Draft shows
every dealt card and its Card pool lists whole sets; Save after Load updates
the file opened; imports read MTG Arena, Moxfield/MTGO and Forge lists; long
titles save; the Gauntlet's music stops under its duels and its duels show the
chosen portrait. Number questions answer with the number pressed; the pause
key (Q, F10 — the ArkOS Select, pad Start) opens the pause menu under a
question, over the full-size card and during the coin toss; Situation Bar
notes stay readable; failed saves say so. On ArkOS, Select now sends F10, so
it opens the menu even after typing in the Deck Builder's search.

## Left open

- **For the owner:**
  - When Forethought Amulet and Furnace of Rath both apply from the start,
    the default order (which the AI takes) applies the Amulet first: 4 damage
    instead of 2. Applying increases first would always favour the damaged
    player but changes the documented order — left as it is.
  - An AutoDeck card-list pool in the ordinary Deck Builder is still
    filtered by the remembered Extras switches (they are on screen there;
    only the draft's hidden trap was fixed).
- **Kept as is, documented:** "Sacrifice when you control no Islands" stays a
  state-based action under every preset — the 1997 reading; under the modern
  presets the only difference is the missing response window (SIMPLIFIED,
  `docs/ROADMAP.md`). "Help..." in the duel's menus stays greyed (Help closes
  to the title; it would need to be an overlay).
- **To verify on hardware:** the Quest scripts' rename of a `.part` file over
  a zip in the game's folder (fails safe if refused) and the Quest timing-log
  marker; whether a desktop window manager says "not responding" during a
  long first-start pack check (the check pumps no window events; doing so
  before the first frame is unsafe).
- **Known gaps:** a copy that keeps the old file's modification time (`cp -p`)
  over the same name inherits its seal; about 45 card scripts' own sweepers
  could move to `depart_together` for the same simultaneity.
- **Hunter probes that still fail by design:** the refresh-storm probe counts
  engine signals (still 51 for the Fireball — the redraws are what changed);
  a Cannibalize cast is now refused at the click instead of opening; probes
  asserting the old Help or legality wording; the ArkOS probe that presses
  `q` (still a letter for desk players); Godot's own TLS and HTTP lines for
  hostile connections; the zip library's own lines for a damaged entry.

## Verification

- Gate: `SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh` — **850 scripts, 13,259
  tests, 578,366 asserts**, exit 0. (The first run had one failure: the new
  socket test's own client polled a TLS stream the host had already shed,
  and counted Godot's line for it against the host under the shards' load;
  the test now stops polling a stream once it has sent.)
- Python: `python3 -m unittest discover -s tools -p 'test_*.py'` — 676 tests,
  OK (15 skipped).
- Boot smoke clean; `./duel_soak.sh` and `./duel_soak.sh --rules fifth` — 6
  duels each, no ERROR, WARNING or STALL.
- Each fixer's own runs: the related existing scripts for every change (for
  example 326 scripts / 6,208 tests around the state-based actions, 185 duel
  scripts / 2,878 tests around the screen, 128 AI scripts / 1,695 tests twice,
  39 SGManalink scripts), invariant soaks of about 1,400 AI duels over all
  three presets, the Deck Lab measurements quoted above, and the hunters'
  probes (archived in the lead's scratch, not in the tree).
