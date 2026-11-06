# Bug pass — the Urza block, 2026-11-06

The owner, once Pack 10 was committed (0.60.19): *"Ok do one bug pass and
bug fix campaign over new features. Commit push!"* Nine read-only hunters
covered everything 0.60.19 added: echo, cycling and the draw step; layers
and cards arriving together; zones, events and control; mana, untapping,
artifacts and combat; the fair AI; every Urza's Saga card and every Urza's
Legacy and Destiny card against its Oracle text; the duel screen, LAN and
the referee; saves, the adventure and packaging. Every finding was proved
by a probe that failed on it (37 distinct findings — two hunters met the
same two high ones from different sides: 2 high, 10 medium, 25 low).
Seven fixers then worked test-first on disjoint files, each turning its
probes into permanent regression tests. The version stays 0.60.19 (not yet
released).

New regression scripts (`test_urza_bugpass_<fixer>_*.gd`):
`tests/unit/test_urza_bugpass_x1_payments.gd`,
`tests/cards/test_urza_bugpass_x2_aperture.gd`,
`tests/cards/test_urza_bugpass_x2_show_and_tell.gd`,
`tests/cards/test_urza_bugpass_x2_cards.gd`,
`tests/cards/test_urza_bugpass_x3_worship.gd`,
`tests/unit/test_urza_bugpass_x3_layers.gd`,
`tests/unit/test_urza_bugpass_x3_arrivals.gd`,
`tests/cards/test_urza_bugpass_x4_cards.gd`,
`tests/ai/test_urza_bugpass_x5_fair_ai.gd`,
`tests/unit/test_urza_bugpass_x6_transfer.gd`,
`tests/ui/test_urza_bugpass_x6_menu.gd`,
`tests/ui/test_urza_bugpass_x6_help.gd`,
`tests/ui/test_urza_bugpass_x7_trample_register.gd`,
`tests/cards/test_urza_bugpass_x7_negator_counts.gd`.

## The worst of what was found

- **A payment the engine makes for a human seat failed when a mana source
  asked a question.** E8's new questions asked while a source is tapped —
  Metalworker's reveal, Fertile Ground's color, Mana Flare on a land of two
  types — were opened again inside the resolution that was paying: echo
  answered "pay" sacrificed the creature anyway, Power Taint's {2} was
  paid and the life lost too, Propaganda's tax refused the attack, and the
  mana floated (and burned under the 1997 rules). Older cards were hit
  through Mana Flare (Iron Star's "pay {1}"). While the engine pays for a human seat a tap now takes the answer
  its plan priced (`MtgGame._engine_paying`, `_plan_answers`), nothing is
  held, and a question asked inside a resolution is answered on the ledger.
- **Temporal Aperture named hidden library cards.** Its reveal was a flag
  refreshed only when the board was recalculated, and nothing recalculates
  inside a resolution: after a draw, a cycle, a mill, a shuffle or a tutor
  in the Aperture's turn the log announced the NEW top card — to both
  seats — and the AI's observation read it. The reveal now names its one
  card and is judged live (`MtgGame.revealed_top_card`), and the offer ends
  for good once the library's top moves (`MtgPlayer.library_top_epoch`).
- **Worship prevented the damage instead of limiting the life lost.** A
  life floor ran as a prevention gate, so damage to a Worship player at 1
  was never dealt: Corrupt gained less, Hypnotic Specter and Order of
  Yawgmoth made no discard, Antagonism hit its own controller. The damage
  is now dealt in full and only the life it costs is limited
  (`MtgGame.damage_life_loss`; the same for Ali from Cairo).

## Rules fixes

- Lands that make no mana (an empty Gaea's Cradle, Tolarian Academy or
  Serra's Sanctum) no longer count as tapped for mana: no Mana Flare or
  Fertile Ground bonus, no Manabarbs, no color question — and Contamination
  makes nothing from them (CR 106.12a–b; the provisional E8 pin is
  inverted).
- Metalworker reveals only the cards a planned payment needs (it revealed
  every artifact card and burned the rest under the 1997 rules), and a held
  tap replays with the colour its plan chose.
- Show and Tell's choices stay hidden until both players have chosen (CR
  101.4a), then both are revealed and arrive together.
- Interdict can't target a cycling ability (CR 109.2: "an artifact,
  creature, enchantment, or land" is a permanent), and its ban ends when the
  permanent leaves the battlefield (CR 400.7).
- Thran Turbine adds its mana even if it left before its trigger resolved
  (CR 113.7a).
- Cards arriving together: each seat orders the timestamps of its own
  arrivals when that order changes the board — Replenish returning
  Opalescence and Humility asks (CR 613.7m); worlds arriving at one moment
  tie and all go (CR 704.5k); Kismet and Root Maze judge an arrival as it
  would exist on the battlefield (CR 614.12), so an enchantment entering as
  a creature under Opalescence enters tapped.
- Ashnod's Transmogrant's artifact type is a timestamped type change (CR
  613.7), so it survives an older Opal animation.
- Cards: Remembrance searches for the name the creature died with (a Clone
  copying Grizzly Bears); Opal Titan and Veiled Sentry read the spell as it
  is while it is on the stack; Attrition, Fodder Cannon and Phyrexian Tower
  may sacrifice themselves once they are creatures; Disappear returns the
  creature it enchants as the ability resolves; Phyrexian Negator's prompts
  count against one total.

## The AI, the screens and the saves

- The fair AI no longer sacrifices for Damping Engine's ignore without the
  play it was for (the body is priced gone first; its own Engine is the
  body), counts each mana source once (a dual land was two mana, a City of
  Brass one per color — Masticore pings it could not finish, Yawgmoth's Will
  cast with nothing left), casts its own Damping Engine only when it binds
  the opponent, prices Veiled Sentry's wake by the spell it chooses and never
  into a lethal swing, and leaves Splintering Wind to its older reader.
  Duel audit after the fixes (seed 456000, both pilots): 108 duels a rules
  set, no stall, error or refusal; the ignores fell from 14 to 5, each
  followed by its play.
- Defensive Formation: the defender assigning a trampler's excess clicks
  their own life register (it used to be the attacker's, and the point hurt
  the defender), on the local screen and as a LAN guest; the referee's view
  names it "You".
- Saves: Save / Load always opens the list, so Import works on a device
  with nothing saved yet; a zip with null fields no longer stops Import
  with a script error; a copy cut short reads "damaged or incomplete", not
  "bigger than an exported adventure can be"; saves the list shows from
  their `.bak` export. The Quest's fresh install says it deletes the saved
  adventures and offers to copy them to the computer first.
- Help: Opalescence's Glorious Anthem is a 4/4, Temporal Aperture's offer
  ends on any shuffle, Damping Engine's own sacrifice, echo on copies,
  tapped artifact creatures, Serra Avatar's owner, Show and Tell's hidden
  choices.

## Left open

- Opal Titan reads a spell countered before its trigger resolves as it was
  cast (`docs/simplified-cards.md`, "Opal Titan"): the engine keeps last
  known information only for permanents.
- Pre-Pack 10, not changed here: some heuristic target orderings read a
  face-down permanent's mana value (Illusionary Mask); Field of Dreams
  leaving mid-resolution leaves its top-card flag set until the next
  recalculation; `AiPlayer._their_open_mana` counts a dual land's rows
  twice; Torch Song's verse counters are not in the AI's valuation.
- Abundance asks a person one question per revealed card for the bottom
  order (correct, many clicks); `PumpEffect.describe()` errors on
  self-pumps, which the AI never asks for.
- The AI may spend a lump source under the 1997 rules where no exact
  payment exists (Tolarian Academy for Snap, a Grim Monolith for {2}) and
  burn the rest: its pricing of mana burn, not the planner.

## Verification

- Every probe failed before its fix and passes after it; each fixer ran
  every existing suite that touches its files (the largest runs: 209
  scripts for the payments, 110 for the library top, 73 for damage, layers
  and arrivals). The probes (`tests/_hunt/`, never tracked) were deleted.
- **Gate** (`SHARDS=2 SUITE_TIMEOUT=7200 ./run_tests.sh`, the desk's
  gamepad hidden from the process): 1,353 scripts, **18,382 tests, 812,183
  asserts**; one failure — a test that fills a library with empty
  placeholders tripped the new top-card check, which now skips an empty
  slot (`MtgGame.revealed_top_card`) — and that script with the Aperture,
  B13 stack, zone-play and LAN table suites then passed, 88 of 88.
- **Python**: 953 tests, 15 skipped, OK. `git diff --check` clean.
- **Duel audit** after the AI's fixes (`tools/pack_10_duel_audit.gd
  --rounds 6 --seed 456000 --pilots both`): 108 complete duels in each rules
  set, no stall, error or refusal.
