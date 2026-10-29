# Whole-project review — 2026-10-21

The owner, on 0.50.41: a review of the whole project as it stands, not of a
diff. Then, on the ranked list: *"All! engine-3:as separate phases!
Document each fix"*.

Five read-only reviewers took one area each — the rules engine, the cards
and packs, the computer opponent and Deck Lab, the duel screen and menus,
and the network, saves and tools (the new Android and offline-Web code
included). A skeptic per area then tried to refute every finding, re-running
the reviewer's probe or writing its own. **27 findings, 25 real (5 medium,
20 low), 2 refuted**: Man-o'-War held for an Aluren with no green source is
the pinned design (`test_the_card_a_loop_casts_is_held_for_it`), and Options
› Card back › Remove deleting a picture put there by hand is what it is for
(`test_card_back.gd`). Four fixers then worked on disjoint files, each
turning its findings into tests that failed before the fix.

What held: 300 seeded AI-against-AI duels with 156 decks under all three
rule presets broke no game invariant; the mana planner paid exactly on 600
random boards (one wasted mana, below); random-player, held-question and
search-journal fuzzing came back clean apart from Gem Bazaar (engine-4).

New regression scripts (10 GUT, plus new Python cases) are listed in
`docs/CODE_MAP.md` under "The whole-project review (2026-10-21)".

## The rules engine

### engine-1 — a target that left play and came back (medium)

**Was.** A spell or an activated ability whose target left the battlefield
and came back still hit it, though the card that came back is a new object
(CR 400.7). The AI's own Aluren loop made it real: Terror at a Shrieking
Drake, the Drake bounced and recast through Aluren in response, and Terror
destroyed the NEW Drake. A Lightning Bolt or a Prodigal Sorcerer ping killed
a creature that had blinked; Holy Strength attached to one. A card keeps its
instance id across zones, and only triggers recorded which incarnation they
aimed at.

**Fix.** `StackItem.target_incarnations` records the incarnation of every
card a spell or ability targets as it goes on the stack
(`MtgGame._pin_target_incarnations`), with the same reading triggers use.
A redirection records its new target (`_pin_new_target`, from
`retarget_spell`, `retarget_stack_item`, `offer_new_targets`); a copy that
keeps the original's targets keeps its record; Ertai's Meddling prefers the
record taken at cast. Every resolution check asks `_target_still_chosen` —
`_all_targets_illegal`, the fizzle loop in `_resolve_spell` and the
per-target filter in `_run_effects_impl`. The record is journaled, and
snapshots copy it. `docs/mechanics.md` (Fizzling, Partial illegality).

**Tests.** `tests/unit/test_review_2026_10_21_engine_stale_targets.gd` (12):
Bolt, Aura, a graveyard card, a two-target Fireball, both redirections, a
copy, a Sorcerer ping, an AI search that blinks and unmakes, the real
Aluren + Drake + Terror line, and two that must still hit (a control
change, a ping at a creature that stayed).

**Left.** A card script that reads `current_targets()` by hand for an
untargeted rider still sees the raw list. A card countered and recast while
targeted on the stack counts as the same object (rare).

### engine-2 — a spell cast from the opponent's library

**Was.** A card cast with Grinning Totem stayed its owner's while it was a
spell: "target opponent" meant its own caster (Mana Clash could be aimed at
the caster, not at the opponent), and Reflect Damage and Eye for an Eye
answered the owner.

**Fix.** `cast_spell` makes the caster the card's controller as it goes on
the stack (journaled), and the target checks before that see the caster
too (`_propose_caster` / `_withdraw_caster` in `_cast_checks`, the adverse
and random target fills, and the helpers the duel screen, SGManalink and the
AI ask: `target_legal_at`, `legal_targets_at`, `target_refusal_at`). The
card goes back to its owner whenever it leaves the stack other than onto the
battlefield (`_spell_goes_home`). The fizzle check judges from the spell's
controller. `docs/mechanics.md` ("A spell's controller").

**Tests.** `tests/unit/test_review_2026_10_21_engine_spell_controller.gd`
(12), among them the real Grinning Totem + Mana Clash line, Reflect Damage,
Eye for an Eye, going home after resolving, a counter and a fizzle, and a
search that unmakes.

**Left.** Under the 1997 damage-prevention window, a stolen spell's damage
waits until after the card has gone home, so Reflect Damage used in that
window still names the owner (Fifth Edition rules, a human seat and Grinning
Totem together).

### engine-3 — the 1997 upkeep and draw are phases of their own (ruling)

**Was.** Under the 1997 rules the mana pool empties and life is checked at
the end of each PHASE, but the engine used the modern phase map, which
makes untap, upkeep and draw ONE beginning phase. Mana floated in the
upkeep survived unburned into the draw step, and a player at −2 after the
upkeep was not checked until the draw ended. The manual names six phases
(p.60, `docs/glossary-1997.md` §3): Untap, Upkeep, Draw, Main, Discard,
Cleanup. The owner: *"as separate phases!"*

**Fix.** `Mtg.Phase1997` and `Mtg.phase_of_1997` — untap, upkeep and draw a
phase each, main in its three parts with combat one of them, end step and
cleanup one — and `MtgGame._phase_ends_now` reads it. Only the two 1997
forks read that function, so the modern presets are unchanged. The Options
text of "1997 mana-pool timing" says so, and Help's mana page.

**Tests.** `tests/unit/test_review_2026_10_21_engine_fifth_phases.gd` (8):
burn at the end of the upkeep and of the draw, life lost in the upkeep,
life regained in time, combat still one phase, both modern presets
unchanged, the map itself. The test that pinned the old reading in
`tests/unit/test_fifth_edition.gd` is now
`test_the_1997_upkeep_is_a_phase_and_burns_as_it_ends`, with the ruling.

### engine-4 — Gem Bazaar changed colour after the computer thought

**Was.** A mana ability's side effect was not journaled. When an AI search
tapped Gem Bazaar and undid it, the tap and the random stream came back but
the Bazaar's new colour stayed: the real Bazaar then showed, and made, a
different colour without having been tapped.

**Fix.** `MtgGame._rec_mana_side_effect`, called from `tap_for_mana` before
any mana-ability side effect runs, records the source card whole and the
per-turn tables, as a resolving spell's are — only during a search. A
general fix, not a patch on the card: a sweep over the 30 or so side-effect
mana abilities found only Gem Bazaar drifting, and none can now.

**Tests.** `tests/unit/test_review_2026_10_21_engine_mana_side_effects.gd`
(4), the sweep among them.

### engine-5 — an instant on the table in Test hands

**Was.** Test hands put an instant or a sorcery "On the table" as a
permanent, for the whole duel, where "destroy target permanent" could see
it.

**Fix.** The picker offers only permanents for the table
(`TestHandsScreen._fill_picker`, through `DuelPosition.fits_on_table`);
`DuelPosition.refusal` names any non-permanent a saved or hand-edited test
puts there — *"Seat 1 puts Lightning Bolt on the table, but an instant or a
sorcery is never a permanent. Put it in the hand, the graveyard or on top of
the library."* — and `MtgGame._place_from_position` never places one even if
asked (it stays in the library, CR 304.4). Help's Test hands page.

**Tests.** `tests/unit/test_review_2026_10_21_engine_test_position.gd` (6),
`tests/ui/test_review_2026_10_21_table_picker.gd` (3).

## The computer opponent

### ai-1 — a combo's mana for cards it was not going to cast (medium)

**Was.** CARD-COMBOS sized its "mana for the hand" loop by the mana value of
every card in hand — Counterspells held for a response, a Serra Angel with
no white source, cards the cast gates refuse — and the mana burned: 6 life
in a probe, 3 twice in one Deck Lab game.

**Fix.** `CardCombos._mana_for_the_hand` counts only what the main-phase
ranking would really cast now (`_hand_casts`: past the same gates,
`AiPlayer._ranking_gates_refuse`, worth casting, coloured costs payable
from our own lands). Under mana burn the loop never makes more colourless
than those cards' generic costs use, its opening mana included, and keeps
the lands their colours need out of the opening. Without mana burn it still
makes mana for the whole countable hand. The same Deck Lab lab (Power
Artifact against The Deck, 12 games) went from 5 such loops and 2 burns to
none. `docs/ai-difficulty.md`.

**Tests.** In `tests/ai/test_review_2026_10_21_ai_pilot.gd`: held
Counterspells, a colour with no source, never past what the hand spends;
controls that must still pay for the hand.

**Left.** `_ranking_gates_refuse` repeats the gate list of `_try_cast_best`;
X spells are not counted (the lethal-X step is apart).

### ai-2 — small creatures held from an unfed Goblin Bombardment (medium)

**Was.** The Wizard's cast veto counted Goblin Bombardment and Orcish
Mechanics as free removal even when their controller had nothing to
sacrifice, and held every small creature: Soul Warden from turn 5 to
turn 21 in one Lab game.

**Fix.** `AiPlayer._answered_on_arrival` passes over every ability whose
cost is more than mana — sacrificing another permanent, exiling,
discarding, removing counters, other object costs — as its own comment
always said ("fewer vetoes, never more") and as `_cheapest_pump_of` does.

**Tests.** An unfed Bombardment and Savannah Lions, unfed Mechanics and
Grizzly Bears; a mana pinger still answers a 1-toughness body.

### ai-3 — Shrieking Drake cast to return itself

**Was.** Every AI level cast Shrieking Drake only for it to return itself,
once per blue source each turn.

**Fix.** `_try_cast_best` asks `_returns_itself`: the Drake is cast when a
creature of ours is worth returning (`_rebuy_pick` — one whose arrival hits
something of theirs again, like a Man-o'-War with a creature to bounce, or a
liability) or when our table pays out on each arrival (`_arrival_paid_out`:
Soul Warden, Pandemonium — the Aluren loops), and `answer_card` then returns
that creature. Otherwise it keeps the Drake.

**Tests.** A lone Drake on all four levels with combos on and off, a Drake
beside a plain creature, the Drake returning a Man-o'-War; the Pandemonium
and Aluren loops still run. `tests/unit/test_loop_limit.gd` reaches the
limit with a Soul Warden on the table now, since the pointless self-return
loop it used is gone.

### ai-4 — Mana Drain's payout burned

**Was.** The Wizard drained a harmless 6-mana Book of Rass and lost 6 life
to mana burn at its next main phase.

**Fix.** Under the mana-burn rules `_try_counter` prices the payout
(`_payout_burns`, `_payout_spend`): the colourless the hand cannot spend
next turn is added, as life at `_burn_price`'s rate, to what the countered
spell must be worth (`_counter_clears_bar`'s new optional parameter). Spells
it always counters are still drained; a burn that would kill it never is.

**Tests.** A harmless six-drop is not drained into six burn; a real threat
is; without mana burn the payout is free; a payout the hand spends is no
burn.

**Left.** Next turn's spending is guessed from the hand alone.

### ai-5 — a second copy of a combo piece counted as progress

**Was.** A second Power Artifact was rated as completing the loop and aimed
at the Monolith that already wore one, even beside a bare Monolith; a second
Ashnod's Altar was "progress".

**Fix.** `CardCombos.spell_choice` passes over a non-Aura piece whose slot
is already on our table, and `_aura_host` over a host already wearing that
Aura (`_wears`).

**Tests.** Four, among them the second Power Artifact going on the bare
Monolith.

## The duel screen and the settings

### ui-1 — leaving a Gauntlet or match duel threw the run away (medium)

**Was.** In a Gauntlet round, or any duel of a best-of match, the opening
screen's "Reconfigure duel" and Pause › Exit duel went straight to Magic
Battle without a word. A Gauntlet run (up to twenty opponents, never saved)
or a match record was gone.

**Fix.** A duel can be held by another screen
(`DuelScreen.leave_title`, `leave_question`, `leave_label`,
`leave_confirmed`): a held duel asks, in the Concede question's window and
words (`_ask_to_leave`, Cancel focused), and never changes scene itself.
- **Gauntlet:** the opening screen's button reads "Quit Gauntlet"; it and
  Exit duel ask *"Quit the gauntlet? Your run ends here, in round N, and you
  go back to Gauntlet Options."* Yes ends the run and brings back Gauntlet
  Options with the run's settings, as the 1997 game ended every run
  (`GauntletScreen._quit_from_duel`); a new run takes a new, logged seed.
- **A best-of match from Magic Battle:** the button still reads
  "Reconfigure duel"; both doors ask *"Quit this match? Its record so far is
  lost, and you go back to Magic Battle."*
- Pressing the button stops the opening screen's countdown; Esc cancels; the
  question closes if the duel ends. Plain duels and Test hands are as they
  were. `docs/gauntlet-design.md` §13, Help's matches page.

**Tests.** `tests/ui/test_review_2026_10_21_leaving_a_held_duel.gd` (10; 12 with the rulings below).

**The owner's rulings, the same day (0.50.43).** Pause › Return to main
menu asks too — *"Yes."* (`DuelScreen.menu_question`, `menu_confirmed`; a
match's own words: *"Quit this match? Its record so far is lost, and you go
back to the main menu."*) — and *"Quit gauntlet goes to title, quit duel
goes to title."*: every door out of a Gauntlet duel now ends the run at the
title, as the round window's own Quit Gauntlet always did, not at Gauntlet
Options.

### ui-2, ui-3, ui-4 — hand-edited settings of the wrong kind

**Was.** `docs/player-files.md` promises that a value of the wrong kind
"reads as meant where it can … and as the default where it cannot". Three
readers broke it with script errors: a number in `enabled_card_packs`
switched every pack off; a number for a name in `test_hands_saved` stopped
the Saved tests list; `"yes"` in `deck_builder_extras` or a number in
`sealed_sets` broke the Deck Builder, which then wrote all-on over the
player's switches.

**Fix.** Each reads through `Settings.coerce`: `Settings.enabled_card_packs`
skips what is not text; `TestHandsScreen.saved_tests` reads a number name
as its digits and drops other kinds (the next Save or Delete writes text);
`DeckBuilderScreen._restore_extras` reads yes/no/on/off/true/false/1/0 as
meant and anything else as on, and `_sealed_sets` skips what is not text.

**Tests.** `tests/ui/test_review_2026_10_21_wrong_kinds.gd` (8).

### cards-1 — "manifest mismatch" where a version was meant

**Was.** Packs 2–9 compared a zip's manifest key by key with the trusted
one BEFORE asking about versions, so their "requires game version" refusal
could never be reached: a pack built for a newer game, or another build of
the same pack, was refused as "Pack N manifest mismatch: version" (or
"…: minimum_game_version"). A version written as a number was a script
error in all eight.

**Fix.** Two helpers in `game/portal_pack.gd` that all eight contracts call:
`version_refusal` asks first, as Pack 1 does — *"requires game version X or
newer (this is Y)"*, or *"this is Pack N version V, and this game needs
version W: rebuild Pack-….zip with this release's tools/pack_N_….py"* — and
`manifest_mismatch` compares the rest, kinds first. The refusal itself is
unchanged. `docs/adding-card-packs.md`.

**Tests.** `tests/unit/test_review_2026_10_21_pack_versions.gd` (6), each
over all eight packs.

## Saves, packages and tools

### nettools-1 — the Android guide's way to add card packs (medium)

**Was.** `ANDROID.md` (`docs/android-experimental.md`) said finished card
packs are imported through the game's chooser; that chooser (Options ›
Skin) takes skins only and refuses every numbered pack.

**Fix.** The guide says what the chooser takes (a skin or `cardart.zip`)
and gives the way that works today: start the game once so it makes
`Android/data/com.b0realis.shandalar.android/files/cardpacks/`, copy the
pack there with adb (into Download, then `cp`), and Rescan. An in-game way
to add a pack would be a new button — the owner's pick, from mockups.

**Tests.** `tools/test_build_android.py`,
`test_the_guide_sends_numbered_packs_to_the_card_folder`.

**Then (0.50.43).** The owner picked the in-game way from three mockups —
*"Yes A is the leanest"*: **Options › Card Packs › Add pack...**, beside Open
Folder and Rescan (`CardPacks.add_pack`; `tests/ui/test_card_packs_add_pack.gd`).
The guide now gives it first and keeps adb for a device whose file box
cannot reach Downloads (not yet tried on a real device).

### nettools-2 — the Web README promised LAN play

**Was.** Every package's README said "LAN SGManalink are included". The
browser build cannot host or join a table (a web page may not open the TCP
and UDP sockets LAN play uses; its Host and Find buttons are off).

**Fix.** `tools/package_release.py` (`PLAY`, `WEB_PLAY`): the two Web
READMEs say LAN play needs an installed build;
`tools/package_web_offline.py` drops the old line from a 0.50.41-or-older
Web ZIP it wraps; `docs/setup-web.txt` says the same.

**Tests.** `test_the_web_readmes_say_the_browser_has_no_lan_play`,
`test_an_older_web_readme_loses_its_lan_promise`.

### nettools-3 — the offline packer took a threaded export

**Was.** `package_web_offline.py` refused a threaded export by markers Godot
4.7 no longer writes, so `--refresh` gave a real threaded export a service
worker.

**Fix.** `THREADED_PAGE` (`GODOT_THREADS_ENABLED = true`, `threads: true`,
`"threads": true`) and `THREADED_ENGINE` (Emscripten's `PThread` in the
engine script, or an `index.worker.js`), checked against the local 4.7
templates: both threaded ones match, both single-threaded ones do not.

**Tests.** `test_threaded_input_refused` (rewritten for the real 4.7 page
and engine), `test_the_single_threaded_47_page_is_accepted`.

### nettools-4 — the service worker's test ran nowhere

**Was.** `tools/test_web_offline.cjs`, the one test of the offline cache
(updates that wait, corrupt updates refused, eviction repaired), ran neither
in CI nor in the release recipe.

**Fix.** A `web-offline` job in `.github/workflows/gate.yml` (Node 24.21.0,
Playwright 1.63.0, Chromium only; `--channel chromium`, a new option of the
test); "The offline Web package" in `docs/release-builds.md`, building both
offline ZIPs and running the test against one; the test named in
`DEVELOPMENT.md`.

**Left.** The job has not run yet: Playwright is not installed on the desk
the fixes were made on. Its first CI run is its test.

### nettools-5 — the privacy check knew only one home folder

**Was.** `tools/test_tracked_tree.py` looked for the current machine's own
home folder only, and skipped every binary file — a path in a picture's
metadata, or another machine's login, passed.

**Fix.** Any user's home in any spelling (`/home/<name>`, `/Users/<name>`,
`C:\Users\<name>`, doubled and JSON-escaped backslashes), with a short
allow-list of the placeholders the docs use, each with its reason; every
tracked file is read, binaries included (UTF-16 text such as a font's name
table, PNG text chunks, an editor's hex EXIF block). The current tree is
clean. `CONTRIBUTING.md`.

**Tests.** `AnyonesHomeTest` (5) in the same file.

### nettools-6 — choosing a new skin or card back could break the old one

**Was.** Options › Skin › Choose (and a card-art zip) and Options › Card
back › Choose wrote over the kept file in place: a full disk or a crash
part-way left a broken file where the working one was.

**Fix.** `SkinPack.copy_whole` writes the copy beside the kept zip, checks
it, and renames it into place (on Windows, where a mounted zip stays open,
a refused rename falls back to the old copy); `SkinPack._take` no longer
deletes the kept zip before its rename; `CardBack.adopt_bytes` goes through
`Settings.write_atomically`. `docs/player-files.md`.

**Tests.** `tests/unit/test_review_2026_10_21_atomic_adopt.gd` (5).

## Found on the way

- **The Options test that took the wrong list.**
  `tests/ui/test_c2_f_sac_rules_option.gd` found the rules preset list as the
  first four-row dropdown on Options; 0.50.40's Situation Bar frame list has
  four rows too. It now also checks the Custom row, as
  `test_options_rules.gd` already did.

- **The privacy check refused itself on CI (0.50.43).** The first CI run of
  0.50.42 failed one test: `tools/test_tracked_tree.py` wrote the CI
  runner's home out whole (two comments and an allow-list case), and on CI
  that path IS the machine's home, which the release guard refuses in every
  file. The file now never spells it whole; the test passes with HOME set to
  the runner's and to the desk's. The new `web-offline` job passed on its
  first run.

## Left open (as of 0.50.43)

Everything this review knows of and did not fix, in one place. "Unchecked"
means a reviewer saw it while working on something else and nobody has
reproduced it yet; each needs a probe before it is fixed.

0.50.45 (`docs/hunt-campaign-2026-10-21.md`) settled the three rulings and
fixed the items marked *fixed in 0.50.45* below; what is still open is
carried forward in that record's "Still open".

### Waiting on the owner's ruling

All three ruled on 2026-10-21 and carried out in 0.50.45.

- **Ante cards with Ante off.** Contract from Below, Jeweled Bird, Darkpact
  and Demonic Attorney still use the ante zone in a duel played without
  ante (`MtgGame.ante_enabled` false). Should they do nothing, be refused
  from such decks, or stay as they are?
- **Fireball's X when a target is gone.** Fireball (`cards/sets/2ed/
  fireball.gd`) divides X among the targets still legal on resolution, so
  one target dropping out doubles the damage to the other. Which reading,
  the 1997 one or the modern one?
- **The 1997 legend rule and a Vesuvan Doppelganger** that becomes a copy of
  a newer legend: the newer-entered one goes, which would bury the original.
  The 1997 ruling for this was not found.

### Not yet tried

- **Add pack... on a real Android phone** — in particular whether the
  phone's file box can open Downloads and hand the game a path it can read.
  The adb route stays in `docs/android-experimental.md` as the fallback.
  Nothing else of the Android build has been tried on a device either.
- **Windows:** the fallback in `SkinPack.copy_whole` (a refused rename over
  a mounted zip copies in place) and `Settings.write_atomically`'s rename
  there (suspected: if Windows' rename removes the target first, a failed
  move could take the pending file with it). The read-only-folder case of
  `test_review_2026_10_21_atomic_adopt.gd` skips itself when run as root.

### Limits of the fixes

- **engine-1:** a card script that reads `current_targets()` by hand for an
  untargeted rider still sees the raw list; a card countered and recast
  while targeted on the stack counts as the same object.
- **engine-2:** under the 1997 damage-prevention window, a stolen spell's
  damage waits until after the card has gone home, so Reflect Damage used in
  that window still names the owner (Fifth Edition rules, a human seat and
  Grinning Totem together). Fixing it means changing how waiting damage
  remembers its source. *(2026-10-27: lifted by the bug campaign c12, h3-6
  — the packet records its source's controller,
  `MtgGame.packet_source_controller`; Reflect Damage, Eye for an Eye and the
  Visions rider read it.)*
- **engine-4:** each side-effect mana tap inside a search now records about
  170 journal rows (roughly 20 µs); not measured in a deck run.
- **ai-1:** `AiPlayer._ranking_gates_refuse` repeats the gate list of
  `_try_cast_best` and can drift from it; X spells are not counted; under
  mana burn only the first 8 eligible cards are weighed.
- **ai-3:** Shrieking Drake's trigger is recognised by its printed text;
  only arrivals that harm an opponent's target count as worth repeating
  (a draw or life-gain arrival does not).
- **ai-4:** next turn's spending is guessed from the hand alone (no draw, no
  ability sinks such as Jayemdae Tome). Some Drains in the Lab still burned;
  they were judged real threats and were not traced one by one.
- **cards-1:** the private `_version_less` functions in Packs 2–5 and 7 are
  unused now.
- **ui-1:** the leave question does not pause the computer, as the Concede
  question does not.
- **nettools-5:** `tools/test_tracked_tree.py` now catches a JSON-escaped
  Windows home in the tree, but the release guard on a staged package
  (`package_release.private_patterns`) still does not; it matters only for
  a Windows builder. *Fixed in 0.50.45.*

### Seen by the reviewers, unchecked

Rules engine:
- The mana planner floats one extra mana for {W}{R}{R} from Plateau +
  Volcanic Island + Black Lotus (1 burn under mana burn); the other 599 of
  600 random boards were exact.
- `draw_cards` returns as soon as the library runs out, skipping the "draws
  N cards" line and the screen update for the cards already drawn in that
  call (the player loses anyway).
- `_cleanup_triggers` sees a state-based action only by zone counts, so one
  that moves no card (the modern +1/+1 and -1/-1 counters cancelling) gives
  no priority in that cleanup (CR 514.3a).
- `declare_attackers` ignores `try_pay`'s answer for the combined attack tax
  after paying the non-mana attack costs first; the board ends the same.
- A discounted cost keeps its printed text (`ManaCost.minus_generic`): a
  refusal, the log and the mini card's badge show "{3}" for a Power
  Artifact-ed Basalt Monolith untap that costs {1}. *Fixed in 0.50.45.*
- `DeckList.parse` caps each line at 500 copies but not the total, so a
  pasted list of many such lines grows into millions of entries. *Fixed in
  0.50.45.*
- After the loop limit stops a step, a state trigger that keeps triggering
  logs "not put on the stack" at every state-based check for the rest of
  the step (log noise).

Cards and packs:
- `game/card_packs.gd` runs `String()` on a pack catalogue's JSON entries
  (around its lines 423 and 437): a crafted pack with a number there is a
  script error, not a clean refusal.
- Packs 8 and 9's README say "the 43 / 42 cards the game already has";
  the manifests count 48 / 47 (the five basic lands). Wording only.

The computer opponent:
- It discarded Ancestral Recall at cleanup instead of casting it
  (`_fire_surplus_instants` skips draw instants; it is priced 2.5). *Fixed
  in 0.50.45.*
- It paid 4 life to Sylvan Library to keep a card, then cast Wheel of
  Fortune in the same main phase and discarded it. *Fixed in 0.50.65: no
  life is paid for a card a wheel castable this turn would throw away.*
- The combo runner's casts count toward the runaway guard's cast cap: after
  a 20-round Man-o'-War loop, Man-o'-War cannot be cast again that turn to
  bounce a real threat.
- With combos off, the Wizard casts a second, useless Ashnod's Altar ahead
  of a Hill Giant (0.50.42 fixed the combo pilot's side only). *Fixed in
  0.50.65: a second copy of a mana ability one copy already repeats is no
  second source.*
- It chump-blocked a Craw Wurm with Soul Warden at 20 life. *Fixed in
  0.50.45.*
- Mana Flare boards: both pilots burn 1–2 life most turns. *Measured in
  0.50.65: the burn is arithmetic (odd costs against doubled mana), left to
  the AI package.*
- Possible hidden information: CARD-COMBOS reads the names of the
  opponent's permanents, which would identify a face-down (Illusionary
  Mask) combo piece. *Fixed in 0.50.45.*
- Deck Lab accepts profile knobs out of range (`wizard:mistake_chance=2`).
  *Fixed in 0.50.45.*
- The unfair player assumes two seats (`1 - pid`); not probed for
  SGManalink. Not a defect: `1 - pid` is the engine's own `opponent_of` for
  the two seats every duel has (0.50.45).

The screens:
- Test hands' **Clear all**, after **Edit test**, resets each life to the
  last test's lives, not to Magic Battle's starting lives as its tooltip
  says. *Fixed in 0.50.45.*
- Magic Battle's page is 8 pixels wider than its scroll area, so bringing
  the Test hands row into view clips its left edge by about 8 pixels.
  *Fixed in 0.50.45.*
- Deck notes lose blank lines and leading spaces on save and load
  (`DeckModel.to_text`). *Fixed in 0.50.45.*
- `DuelLogFile._trim` rewrites `duel_log.txt` in place: a crash or a full
  disk mid-trim loses the running log. *Fixed in 0.50.45.*
- A card back's size limit is 64 MB of file, not pixels: a small,
  highly compressed picture of huge size is decoded whole at every start.
- In the browser, Options › Card back and Options › Skin wait for the file
  box's "cancel" event; a browser that never sends it leaves the button
  dead for the session.

LAN, saves and tools *(2026-10-27: the read fence, the open host, the
mounted zip, Open Folder on Android and the browser's file boxes are fixed
by the bug campaign c12)*:
- The MCP server's `read_deck` / `find_deck` read any path, absolute or
  `../`, where the write tools are fenced inside the deck folders.
- An open LAN host: any peer on the network can read the advertised code
  and hold up to `MAX_SESSIONS` roomless sessions, so "Host is full" turns
  real players away.
- Replacing a mounted zip under the same name (`SkinPack.adopt`, `_take`)
  may leave stale entries until a restart (suspected).
- Options › Card Packs offers **Open Folder** on Android and the Quest,
  where it cannot open the game's folder (**Add pack...** is the way in
  there now).
- `SgTournamentStore.available()` asks the modified time of a primary file
  that may be gone (only its `.bak` left), which prints an engine error on
  some Godot versions; recovery still works. Not reproduced on 4.7.2
  (0.50.45).
- A tournament's revision is capped at 1,000,000 on the wire; not reachable
  in play.
- The offline Web package's sizes in its setup text (50 MiB, 131 MiB with
  the skin) were not measured.

### Not reviewed

What the reviewers named as outside what they read. The second hunt of
0.50.45 read all of it but what its record lists as not reached:
- Rules: the inside of `continuous.gd`'s layers, most of `damage_replacements.gd`
  and `effects/*.gd`, banding and flanking, phasing, copy and face-down
  objects, ante, the draw replacements, `proxy_card.gd`, `deck_printings.gd`.
- Cards: an exhaustive read of the card scripts; the fuzzers check for
  crashes and effects that linger, not that each card does what it says.
- AI: most per-set tactics modules, `combat_search.gd` and
  `combat_study.gd` (only timed), `effect_intent.gd`, the match memory, most
  of the sideboarding, `auto_deck_cli.gd`, the referee and the Elo ledger.
- Screens: most of the duel screen's 12,000 lines beyond the parts named
  above, the deck builder's filter, stats and auto-deck, draft, the touch
  keyboard and gestures, music.
- LAN and tools: the lobby and LAN duel views, the client-side protocol
  checks, tournaments beyond their commands, the MCP referee, the original
  and Manalink importers, the pack builders, and the Quest, macOS, ArkOS
  and Steam Deck scripts.

### Tests that fail under load

`tools/test_lan_smoke_launcher.py` (two Ctrl-C tests) and
`tools/test_c3_fx_scripts_shell.py` (two soak Ctrl-C tests) wait 20–30
seconds for a Godot to stop. Run beside two Godot test chains on the desk
they timed out; alone they pass (24 of 24), and on CI they pass. They want
a wait that does not depend on how busy the machine is. Still open after
0.50.45, which repaired four timing tests of its own (listed in
`docs/hunt-campaign-2026-10-21.md`, Verification). (2026-10-28: fixed in
0.50.61, and the cause was not the load: a runner started as a background
job of a script inherits SIGINT ignored, a shell cannot trap a signal
ignored on entry, so the Ctrl-C did nothing and the test waited out its
timeout. The children now get the default SIGINT back before they start —
`default_sigint` in `tools/test_lan_smoke_launcher.py`, the `preexec_fn` in
`tools/test_c3_fx_scripts_shell.py`.)

## Verification

Targeted, after all four fixers had finished (the owner's test-scope
policy), in three chains of `./run_tests.sh -gselect=…`, every one exit 0
with no `ERROR:` line:

- Rules: the 11 new review scripts (95 tests), `test_c2_f` (63 scripts,
  510), `test_fifth_edition`, `test_loop_limit`, `test_target`,
  `test_turn_and_stack`, `test_undo_log`, `test_mana_burn`,
  `test_fidelity_2026_09` (379), `test_campaign_fix` (423),
  `test_bug_pass_2026_10_03` (114), `test_damage`, `test_delayed_triggers`,
  `test_exile_audit`, `test_engine_sweep`, `test_2ed_cards`,
  `test_original_pool`, `test_pool_wave` (74 scripts, 1,254),
  `test_player_protection`, `test_simplified_ledger`.
- AI and cards: `test_ai_` (129 scripts, 1,702), `test_card_combos`,
  `test_mirage_bugpass_cards`, `test_cost_choice_contract`, `test_pack_`
  (180 scripts, 3,630).
- Screens and LAN: `test_duel_` (219), `test_gauntlet` (89),
  `test_match_screen`, `test_test_hands`, `test_deck_builder` (235),
  `test_options_`, `test_original_dialog`, `test_situation_bar`,
  `test_bar_frame`, `test_card_back`, `test_skin_pack`, `test_card_packs`,
  `test_help`, `test_sgmanalink` (38 scripts, 386), `test_android`.

`./duel_soak.sh` and `./duel_soak.sh --rules fifth`: exit 0, 6 duels each
(the demo and the human seat) through the live duel screen. Python:
`python3 -m unittest discover -s tools -p 'test_*.py'`, 797 tests OK (15
skipped). The version bump to 0.50.42 also moves the Android preset's
`version/code` to 50042 (`packaging/android/export-preset.cfg`,
`export_presets.cfg.example`), which `tools/build_android.py` checks.
