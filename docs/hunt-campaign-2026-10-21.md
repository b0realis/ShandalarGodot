# Three rulings and the second hunt — 2026-10-21

After the whole-project review of the same day (0.50.42–0.50.43,
`docs/whole-project-review-2026-10-21.md`) the owner ruled on the three
questions it had left open, then: *"go bug hunt and bug fix in code segment
the last reviewers didn't get! Go baby"*.

Seven agents worked at once on disjoint files: one carried out the rulings,
six hunted where the review's reviewers had said they did not read — the
rules engine's inside, every card script of the original sets, every card
script of Packs 2–9, the AI's per-set and search modules, the duel screen's
widgets and the deck builder's panels, and the LAN views, the MPN game
history added that afternoon and the tools. Each defect was proven by a probe
that failed on the code as it stood before it was fixed, and each fix carries
that probe as a permanent test. What a hunter could not fix in its own files
it handed over; the lead applied those last.

New regression scripts are listed in `docs/CODE_MAP.md` under "The second
hunt (2026-10-21)".

## The three rulings

- **Ante off — no ante used.** The owner: *"fix ante off (only back side of
  mtg cards shown instead of ante, no ante used!)"*, then, on Contract from
  Below in three shipped decks: *"Leave them. Message player - ante must be
  on for this card!"*. In a duel not played for ante the nine cards that
  print *"Remove this card from your deck before playing if you're not
  playing for ante."* (Contract from Below, Darkpact, Demonic Attorney,
  Jeweled Bird, Bronze Tablet, Rebirth, Tempest Efreet, Timmerian Fiends,
  Amulet of Quoz) can't be cast and their abilities can't be activated:
  *"Ante must be on for <card>: this duel is not played for ante"*, the same
  answer for the duel screen, SGManalink and the AI
  (`MtgGame.not_for_ante_refusal`). Nothing ever reaches the ante
  (`ante_top_of_library`, `move_to_ante` refuse), so the opening window shows
  card backs. Without it Contract from Below was a {B} draw-seven and Amulet
  of Quoz a coin flip that lost the opponent the game. Duels played for ante
  are unchanged. Tests: `tests/unit/test_ruling_2026_10_21_ante_off.gd`.
- **Fireball crushes empty space.** The owner: *"it is ignored if target
  dissapears - the spell crushes empty space :)"*. X is divided evenly,
  rounded down, among ALL the targets chosen as the spell is cast; a target
  gone on resolution loses its share, and with every target gone the spell
  does nothing (`MtgGame.chosen_target_count`, `cards/sets/2ed/fireball.gd`).
  Every other spell that divides damage already fixed each share at casting
  and is now pinned too. This departs from the modern ruling (divide among
  the targets still legal) on purpose. Tests:
  `tests/unit/test_ruling_2026_10_21_divided_damage.gd`.
- **The 1997 legend rule and a copy.** The owner: *"rule as per 1997 and
  document it"*. "First in time, first in right" counts from when a permanent
  BECAME that legend: a Vesuvan Doppelganger that turns into a copy of a
  legend already in play is the one buried, whichever entered first (until
  now the original was); so are a Clone or Doppelganger entering as a copy,
  Unstable Shapeshifter, Volrath's Shapeshifter and a face-down legend turned
  face up. Sources: Pojo's Judge's Corner of 22 April 2002 on rule 420.5e,
  for exactly this case — *"The Vesuvan Doppelganger will be put into the
  graveyard … as it will be the legend with the same name that has been a
  legend a shorter time than the other legend"* — and the MTG wiki's history
  of the legend rule. The 1997 decompilations hold no legends (Legends came
  with the 1998 expansion). `MtgGame.legend_since`, `note_identity_change`;
  the computer no longer shifts its Doppelganger into a legend. Documented
  in `docs/mechanics.md` and `docs/glossary-1997.md`. Tests:
  `tests/unit/test_ruling_2026_10_21_legend_copy.gd`.

## What the hunt found and fixed

### The rules engine

What the review had not read: `continuous.gd`'s layers, `damage_replacements.gd`,
the effects, banding and flanking, phasing, copies and face-down objects, the
deck readers. Recalculating the layers twice on 1,000 random boards (every
pack, both rule sets) gave the same board every time, and every static that
writes abilities, types or colours declares its layer.

- **A discounted cost showed its printed cost.** Under Power Artifact,
  Basalt Monolith's untap costs {1}, but the refusal, the log and the badge
  said {3}. `ManaCost.minus_generic` now spells the new cost.
- **A deck list could grow without limit.** 4,000 lines of `500 Forest`
  became two million cards. `DeckList` stops at 100,000 (`MAX_TOTAL`) with
  one error line.
- Volrath's Shapeshifter follows the legend ruling (`continuous.gd`
  `_graveyard_top_copies`).

### The cards of the original sets

All 887 scripts outside the rulings' own cards read against their Oracle
text, and all 897 checked mechanically against the card data.

- **Glyph of Doom** destroyed nothing when its Wall died in the fight —
  its main use. It keeps the Wall's blocks now.
- **Stasis** froze permanents but still ran each untap step, using up "next
  untap step" locks and phasing; it now skips the step. **Island Sanctuary**
  ends at its owner's upkeep, so a skipped untap step no longer keeps it up
  for good.
- **Equinox** countered spells aimed at your creatures and ignored a Volcanic
  Eruption aimed at your Mountain; it reads the real targets.
- **Enchantment Alteration** could move an Aura where it then fell off (a
  one-mana Aura removal); it and **Kudzu** skip what can't be enchanted.
- **Drain Power** at yourself emptied your own pool; **Berserk** could be cast
  after first-strike damage; **The Fallen** hit its own controller;
  **Plague Rats** counted a face-down card; **Illusionary Mask**'s "you may"
  was forced; **Clockwork Beast / Avian** lost counters for combats they sat
  out; **Tetravus** tokens had no creature type.
- **Regeneration and The Brute** left a free shield on the real creature
  after an AI search tried them.
- **Titania's Song** with an earlier Humility made a 1/1 where a 4/4 is right:
  its size is now a layer-7b static of its own, ordered by timestamp.

### The cards of Packs 2–9

All 2,245 names checked mechanically; 2,180 of 2,192 scripts read (the twelve
left are the rulings' cards).

- **Bands:** Coils of the Medusa, Elvish Berserker and Wall of Nets saw only
  the band member the block was declared on.
- **Attackers that left combat** (regenerated, Reconnaissance) were still
  destroyed, paralysed, shrunk or exiled by the creature that had blocked
  them — Kjeldoran Frostbeast, Dread Wight, Greater Werewolf, Wall of Nets —
  and Goblin Snowman, Tinder Wall, Wall of Corpses, Whip Vine and Sworn
  Defender could still target them.
- **Seeds of Innocence** gave no life for an artifact Forbidden Crypt exiled;
  a stolen **Purgatory** returned cards to their owner; **Blood Frenzy** could
  be cast after first-strike damage.

### The computer opponent

- **It read hidden cards** (CONTRIBUTING.md rule 8): CARD-COMBOS, Tariff,
  Plaguebearer, Apocalypse Chime and Echo Chamber all looked under an
  Illusionary Mask.
- **Blunders:** Ancestral Recall discarded at cleanup instead of cast; Final
  Fortune cast on the opponent's turn; Cold Storage answering sweepers that
  would not kill, or would destroy the Storage; Reins of Power cast into its
  own blocker; Corpse Dance raising a Wall; phasing a blocker out of a
  trampler's way and dying; two chump blockers on Stalking Tiger; Phelddagrif
  and Urza's Engine paying for nothing; divided damage (Pyrotechnics) read as
  no damage; Soul Warden chump-blocking a Craw Wurm at 20 life; a hand whose
  only mana was Mox Diamond kept; the match memory counting our card as
  theirs; Part Water giving the opponent landwalk.
- **Ante off:** it discards its dead ante cards first and mulligans hands
  that lean on them.
- **Deck Lab** accepted probabilities out of range (`mistake_chance=2`).
- The 239 cells of `docs/ai-difficulty.md`'s knob table match the presets.

### The screens

- **Leftovers after the duel:** a question still open could resolve a spell
  after the verdict; the aim and the Concede question stayed up. A question
  drew over the Pause window while Pause took the clicks.
- **Leaving during the opening** read as "Play first" and a keep, started the
  abandoned duel and hit script errors.
- **A phased-out face-down card** was revealed by a click.
- **Rarity:** Fourth Edition's rarity won for 47 cards (Hurr Jackal shown
  rare) in the filters, stats and Sealed/Draft sheets.
- **The table:** an Aura's band dragged snapped back and a slip on a chain
  card moved a permanent; an Aura on a front-row land was cut off; piled
  cards ignored Winter Orb.
- **Test hands' Clear all**, Magic Battle sliding 8 px sideways at 1280x800,
  **deck notes** losing blank lines, **duel_log.txt** emptied while it was
  trimmed, the quit question over the splash vanishing, the play/draw and
  mulligan questions deaf to Return, AutoDeck with a hand-edited setting,
  touch sliders inside scrolling pages, the on-screen keyboard and the
  D-pad, a pad connecting mid-press, hotseat wording, Booster Draft deaf to
  Escape, the big card unclickable over an open pile.
- **Colour or colours:** the duel screen can now tick several colours for a
  question that allows them (Dream Coat, Prismatic Lace).

### LAN, the game history and the tools

- **MPN game history** (new that afternoon): a recording from another program
  broke Watch duel; invalid text was shown instead of refused (spec §2, §9);
  the Past Games seek bar replayed from the first record on every step (two
  seconds on a long game; 10–27 ms now). No hidden information or personal
  path reaches a record.
- **LAN:** about 6,200 mutated room views put to the guest's duel view broke
  nothing.
- **Tools:** `upscale_skin.py` could write over the skin it read and let a
  drive letter through; `mtg_assets.py` replaced a good zip with a half one;
  the Manalink and 1997 importers stopped on one bad frame, movie or palette;
  Pack 1's verifier took forged metadata; `build_card_packs.py`'s cache
  broke on a cut file; `skin_catalogue.py` lost its size table in a release;
  the release guard missed a JSON-escaped Windows home; the decision tools
  forgot a cast's targets after a payment question, called an unanswered
  submission "cast", activated {X} abilities at X=0 and hung on a `null`.
- **Scripts:** `quest_fresh_install.sh` took "yes" for no; `build_release.sh`
  never checked the Quest APK's package name and said nothing when the Mac
  smoke boot failed; `arkos.sh` lost the handheld name through `sudo`.

### Handed over and applied last

Thirteen fixes the hunters proved but could not make in their own files,
applied together once they had finished, each test-first.

- **Illusionary Mask.** A masked creature stayed face down when it attacked,
  regenerated, paid a {T} cost or tapped for mana, so a masked Shivan Dragon
  attacked for 2; it now turns face up as it taps
  (`MtgGame._turn_face_up_quietly`). A masked blocker dealt 2 where a Craw
  Wurm deals 6: every face-down creature that will assign combat damage turns
  up first (`_assigns_combat_damage`).
- **Vesuvan Doppelganger** kept a colour painted on it (Celestial Dawn) for
  good, and a Clone of its new shape took the shape's colour; it now keeps its
  own blue, and so does the Clone (`become_copy`).
- **Consecrate Land and Anti-Magic Aura** stopped new Auras but left the ones
  already attached, Animate Dead included; they now fall off
  (`CardInstance.cur_other_auras_barred_by`, `MtgGame.aura_barred_by_another`).
  Guardian Beast keeps them, as printed.
- **False Orders, Ydwen Efreet, Imprison:** an attacker two creatures blocked
  went unblocked once the first blocker was gone (`remove_from_combat`,
  `_blocked_by_another_this_combat`).
- **Disintegrate** on a token let it die, its death triggers firing; it is
  exiled now, and the same for Runesword.
- **"Must block … if able"** against a band refused a block on another member
  of that band (Crashing Boars, Lure in a band) (`CombatDeclaration`).
- **Abu Ja'far, The Wretched, Spitting Slug, Wall of Caltrops and Feint** read
  only the creature a block was declared on, and still counted an attacker that
  had left combat.
- **Plaguebearer, Apocalypse Chime, Echo Chamber and Crown of the Ages** read
  the card under an Illusionary Mask; a face-down creature now has mana value 0
  and no name for them.
- **"The color or colors of your choice":** Dream Coat, Prismatic Lace and
  Shyft took one colour; they now take one to five, on the duel screen and at a
  network table (the host sends five colours and `Done.`; the wire is
  unchanged, protocol 30), and the decision tools understand it
  (`DecisionAgent.choose_color(several)`).
- **A finished network duel** could still open a question.
- `AGENTS.md`'s MCP notes now say what the tools fixed in this hunt do.

### A slip

One hunter started the game once without the scratch profile, so Godot's
own log rotation pushed the oldest file out of the player's `user://logs`
folder. Nothing else of the profile was touched, and every later run was
isolated.

## Still open

What the hunt saw and did not fix, with what the review left open and this
hunt did not close (`docs/whole-project-review-2026-10-21.md`, "Left
open", marks what 0.50.45 closed). "Suspected" means seen while reading and
not proven by a probe; each needs one before it is fixed.

### For the owner

- The MCP server's `read_deck` / `find_deck` read any path, where the write
  tools are fenced inside the deck folders; the tool's own description says
  "under decks/".
- An open LAN host: any peer can hold up to `MAX_SESSIONS` roomless
  sessions, so "Host is full" turns real players away.
- Island Sanctuary, Fasting and Breathstealer's Crypt ask their question
  from the draw step, where a human seat's question cannot be held open (the
  heuristic answers): the engine-wide row "A draw replacement asks OUTSIDE a
  resolution" in `docs/ROADMAP.md`.
- A Clone or Doppelganger's arrival question may still offer a legend in
  play, which the ruling then buries.

### Not yet tried (from the review)

Add pack... on a real Android phone; the Windows rename paths
(`SkinPack.copy_whole`, `Settings.write_atomically`).

### Suspected — rules and cards

- Whimsy and Faerie Dragon's random targets ignore protection and shroud.
- Word of Command's discard log says the hand is revealed but shows only the
  eligible cards; `choose_number` from 0 to a life total lists every number.
- A 20-digit number in an MPN record, a duel position or a deck list prints
  an engine `ERROR` while being read.
- An AI probe that runs combat damage or a tap can turn an opponent's masked
  creature face up inside the probe and read it.
- Two "other Auras" bans on one host shed one Aura per state-based check;
  both should go at once (reachable only by attaching an Aura from anywhere).
- Unjournaled flags an AI search cannot undo: `regeneration_banned_this_turn`
  and `exile_instead_of_dying` (Disintegrate, Runesword, Clergy of the Holy
  Nimbus, Hurr Jackal, the random creature effect table).
- A creature phasing in tapped while face down; `tap_picks` tapping through
  `tap_permanent` mid-payment.
- Firestorm Phoenix and Gravebane Zombie skip tokens.
- Original sets: Land Equilibrium as a trigger, Lich at negative life,
  Psychic Allergy's colour as an arrival trigger, Goblin Rock Sled, Sengir
  Vampire's victims of a copy, Glyph of Reincarnation, Glyph of Doom cast
  before blockers on a Wall that then dies; Chaoslace and Deathlace on a
  permanent, Veteran Bodyguard outside combat, Siren's Call in 1997,
  Paralyze's {4} only while tapped, Hyperion Blacksmith, Floral Spuzzem.
- Packs 2–9: Lead Golem's controller fixed at resolution, Sand Golem's
  counter after entering, a stolen Cycle of Life, Dizzying Gaze's host
  timestamp, Cannibalize with one target, Elkin Lair's permission never
  expiring, Winds of Rath and Extinction not simultaneous, `PumpEffect.describe`
  for a +X/+X self pump.
- Not reached: `mana_planner.gd`, additional costs beyond payment, the
  insides of the draw-replacement cards, flanking in bands, phasing beyond a
  read.

### Suspected — the computer

Hermit Druid milling itself out; the combo runner's casts counting toward
the runaway guard's cap; a second Ashnod's Altar with combos off; Sylvan
Library then Wheel of Fortune; Mana Flare burn; face-down attackers in the
sweeper reading (`_ground_the_sweep_opens`); face-down names in the licid
twin key and toll; Part Water's X priced ×1.5; `matchups.csv` without a
drawn column; the referee's handshake file readable by other local users.

### Suspected — the screens

- Two-human Test hands: seat 1 read as seat 0 in places
  (`duel_screen.gd` `_viewing_seat`).
- Private hotseat: a face-down card exiled is shown before Show hand.
- An auto-skipped combat rests in Main 2; Pause does not stop the opening
  splash countdown or the coin.
- Mana analysis counts X as 0; the draft pool's All freezes later packs, and
  All/None ignore the search; the mini card's mana colours for Gem Bazaar,
  Fellwar Stone and Reflecting Pool; a card back's size limit is bytes, not
  pixels; a deep chain runs off screen at 1280x800.
- From the review: Options › Card back and Skin in the browser wait for a
  "cancel" a browser may never send.

### Suspected — LAN, the game history and the tools

`SgTournamentStore.available()` (not reproduced on 4.7.2); `mpn_files`'
`export_bytes` not atomic; the recorder's 0.5 ms an event; MPN handles keyed
by zone and timestamp; `valid_patch` accepting a repeated id; the duel
view's Export MPN shown when the host has no record;
`package_release.private_patterns` and a lowercase `c:\users`; the Mac JDK
message of `build_release.sh`; Python tracebacks on a huge image, a corrupt
zip or a manifest that is a list; replacing a mounted zip under the same
name; Open Folder offered on Android and the Quest; the offline Web
package's sizes not measured.

### Limits of the review's fixes

Unchanged; see the review record.

### Tests that fail under load

`tools/test_lan_smoke_launcher.py` and `tools/test_c3_fx_scripts_shell.py`
wait 20–30 seconds for a Godot to stop and time out beside other Godot
runs; alone and on CI they pass (and beside nothing but the desk's other
work, in this campaign's run, they passed too). The four timing tests this
campaign tripped over are repaired (see Verification).

### Stale lines found on the way

`docs/card-states.md` §5.1 on a masked attacker tapped in combat, and
`AGENTS.md`'s LAN protocol number, were corrected in 0.50.45.

## Verification

Targeted (the owner's test-scope policy), on a desk carrying another
project's work the whole time (a load of 56–71 on 22 cores), in three
chains of `./run_tests.sh -gselect=…`, each with its own test data folder:

- **The cards** — `test_pack_1` … `test_pack_9`, `test_pool_wave`,
  `test_original_pool`, `test_2ed_cards`: 12 groups, 252 scripts, 4884
  tests, every one exit 0 with no `ERROR:` line.
- **The computer, the network, the earlier bug passes** — `test_ai_`,
  `test_card_combos`, `test_c2_f`, `test_campaign_fix`,
  `test_bug_pass_2026_10_03`, `test_tempest_bugpass_fix`,
  `test_mirage_bugpass`, `test_audit`, `test_fidelity_2026_09`: 9 groups,
  293 scripts, 3670 tests, no `ERROR:` line; one timing failure (below),
  repaired and run again.
- **The rulings, the hunt and the screens** — `test_ruling_2026_10_21`,
  `test_hunt_2026_10_21`, `test_review_2026_10_21`, `test_duel_`,
  `test_combat`, `test_face_down`, `test_attack_bands`, `test_ante`,
  `test_phasing`, `test_deck_builder`, `test_sgmanalink`, `test_mpn_`,
  `test_help`, the Options, gauntlet, match, draft, hotseat, touch, pad,
  deck and title screens and the rest: 36 groups, 176 scripts, 2438 tests,
  every one exit 0 with no `ERROR:` line. (Two more names asked for,
  `test_bands` and `test_legend`, match no script; the banding and legend
  tests are in the hunt, ruling, attack-bands, campaign-fix and fidelity
  groups.)
- **The soaks** — `./duel_soak.sh` and `./duel_soak.sh --rules fifth`,
  isolated: six duels each finished, exit 0, no `ERROR:` line.
- **The tools** — `python3.12 -m unittest discover` in `tools/`: 821
  tests, one failure (below), repaired; `test_shandalar_mcp` again: 92
  tests, OK (10 skipped without a Godot).
- **The tracked tree** — `tools/test_tracked_tree.py`, with the desk's
  home and with the build machine's: OK.

Four tests that measured the machine more than the game, repaired:

- `tests/unit/test_c2_f_net_wire.gd` — the guest's decode and the host's
  check of a late state, 16 ms each, read 25–53 ms: each state is timed
  best of three, and the frame is stretched by how much slower the old
  byte loop runs right now than on the quiet desk — never shrunk.
- `tests/ai/test_campaign_fix_ai_b_licid_budget.gd` — seven Licids decided
  within a second: best of two fresh games.
- `tests/ui/test_c2_f_net_sockets.gd` — one discovery pump under a UDP
  flood within 8 ms read 10.2 ms once in 288 pumps whose mean was 0.72 ms:
  judged on the 95th percentile (0.67 ms on the re-run, whose worst was
  11.9 ms); every pump follows the same burst, so a pump that decodes what
  it should skip is slow every time.
- `tools/test_shandalar_mcp.py` — a kept game's transcript read right after
  `referee_stop`: the referee sends each line to its client before it
  writes it to the transcript, so the stop's answer can come a moment
  before the file has the line. The test now waits for it (a fake referee
  slowed half a second between the two fails the old read and passes the
  new one).
