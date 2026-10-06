# Bug pass — the Tempest block, 2026-10-06

The owner, once Pack 9 was complete: *"First do one bug find & bug fix pass
over the new mechanics. Then Commit and push!"* Six read-only hunters
covered the new mechanics by area — shadow and combat requirements; buyback
and payment rows; licids and special actions; layers, Humility and the
stack; the new costs, targets and the engine-wide changes (state-based
actions on priority, hand-size recalculation); the block's signature cards
and the fair AI. Every finding was reproduced by a probe that failed on it
(42 findings: 3 high, 25 medium, 14 low). Six fixers then worked test-first
on disjoint files, each turning its probes into permanent regression tests.

New regression scripts:
`tests/unit/test_tempest_bugpass_fix_engine_humility.gd`,
`tests/unit/test_tempest_bugpass_fix_engine_copy_entry.gd`,
`tests/unit/test_tempest_bugpass_fix_engine_actions.gd`,
`tests/unit/test_tempest_bugpass_fix_licid_copies.gd`,
`tests/cards/test_tempest_bugpass_fix_licid_heartstone.gd`,
`tests/cards/test_tempest_bugpass_fix_licid_pandemonium.gd`,
`tests/cards/test_tempest_bugpass_fix_licid_uncounterable.gd`,
`tests/unit/test_tempest_bugpass_fix_combat_requirements.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_1_rows.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_1_heartstone.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_1_licids.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_1_city.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_1_spined.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_2_combat.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_2_licids.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_2_payment.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_2_casts.gd`,
`tests/ai/test_tempest_bugpass_fix_ai_2_abilities.gd`,
`tests/ui/test_tempest_bugpass_fix_ui_net_table.gd`,
`tests/ui/test_tempest_bugpass_fix_ui_net_rows.gd`,
`tests/unit/test_tempest_bugpass_lead_entry.gd`.

## The worst of what was found

- **No legal block declaration.** Two block requirements that needed the
  same menace partner (Watchdog, Provoke, Invasion Plans against a menace
  attacker) left no declaration the engine would accept: a human seat could
  never leave declare-blockers and the AI defender conceded. Block
  requirements are now counted over the whole declaration in one place
  (`CombatDeclaration.must_block_error`) and the declaration must obey as
  many as any legal one could (CR 509.1c), by a bounded search; the AI's
  repair runs the same search. The same rewrite fixed a narrowed Lure
  binding every blocker, a plain Lure being narrowed by an earlier one
  (`cur_must_be_blocked_by_all`), and a full blocker cap excusing every
  requirement.
- **A network seat disconnected by a token.** A token Sabertooth Cobra or
  Nafs Asp (an Echo Chamber copy) left its ransom row naming an object that
  had ceased to exist; the host's own view check failed and the bitten seat
  was sent "Connection stopped". No handle is now ever given out for an
  object the game no longer has.
- **A silenced creature's printed death trigger fired.** A creature that
  died or left after losing all its abilities (Humility, Titania's Song,
  face down) still fired its printed "when this dies" trigger — Personal
  Incarnation under Humility halved its owner's life. A departing permanent
  now hears its own departure with what it had as it left (CR 603.10a),
  which also makes a GRANTED "when this dies" trigger heard.

## Rules fixes

- **Entering without abilities (CR 614.12).** A permanent that would have no
  abilities as it would exist on the battlefield applies none of its OWN
  entry replacements: a Spike under Humility enters a 1/1 with no counters,
  Dracoplasm sacrifices nothing, Clone copies nothing, a nonbasic land that
  enters tapped enters untapped under Blood Moon, Lotus Vale under Blood
  Moon asks nothing (`MtgGame._enters_without_abilities`). Copy Artifact
  entering as a copy of Mox Diamond now chooses the copy first and then
  pays Mox Diamond's land discard.
- **Humility and timestamps:** "you may choose not to untap" is ignored for
  a permanent with no abilities (a humbled Coffin Queen untaps and loses
  her creature); a durationless grant made after Humility (Cocoon's flying,
  Rainbow Knights' protection) survives it.
- **Licids:** a licid Aura stays an Aura when a later copy or graveyard-text
  effect rewrites the card (Unstable Shapeshifter, Vesuvan Doppelganger,
  Volrath's Shapeshifter) — the values under the effect change, the effect
  does not (CR 611.2c); a stealing Aura's control lasts only while its text
  still steals.
- **Costs and timing:** Heartstone no longer discounts abilities of creature
  cards in the graveyard (Carrionette, Necrosavant; CR 109.2); a library-top
  or exile-from-hand cost refreshes hand-size statics (Maro dies); paying a
  ransom is an action that resets passes; Volrath's Curse's ignore ends at
  the cleanup step; a granted row that forces X to 0 is not offered for an
  "X can't be 0" spell; Pandemonium asks the creature's controller on
  resolution.
- **Can't be countered:** two older counterspell overrides (Ice Age's
  colour-checked counters, Burnout) no longer read a Scragnoth as
  counterable.

## The AI and the screens

- **The fair AI** — every self-harm and blind spot the hunters proved, fixed behind the
  existing `forecasts_tactics` gate with a null arm and a hidden-information
  permutation: free Aluren/Dream Halls rows under its own Medallion;
  creature abilities priced at what the engine charges under Heartstone (no
  more mana burn); never sacrificing the creature Volrath's Curse was
  ignored for; Nurturing Licid regenerating instead of ending, Dominating
  Licid keeping a creature dying for it; City of Traitors kept; Spined
  Sliver read in block planning; shadow read by the surprise-blocker logic
  and in "gains shadow" pricing; Soltari Guerrillas never redirecting a
  lethal attack; Trumpeting Armodon ordering once; the Oaths, Jinxed Idol,
  Ensnaring Bridge, Furnace of Rath and Spike Cannibal cast only when they
  help their caster; Hibernation Sliver's bounce answering only real
  removal; Coffin Queen, Recurring Nightmare and Volrath's Stronghold now
  used. Roles on triggers and statics are carried as object metadata
  (`set_meta(&"ai_role", …)`, read by `TempestSpells.ability_role`) — the
  ability classes have no typed role field.
- **The duel screen and SGManalink:** the X window prices the engine's real
  bill (Heartstone; a buyback row's extra cost); under Aluren at instant
  speed the printed row is greyed; the referee no longer publishes an
  impossible X budget for a row that forces X to 0. Protocol stays **28**.

## Left open

- Block requirements are maximised by a bounded search (ROADMAP row): a
  board beyond its budget accepts the declaration in hand.
- One end cost is kept per licid (two licid effects from different licid
  abilities on one object share the first's cost).
- The AI never activates abilities with a discard cost outside Fallen
  Empires and Ice Age (Ephemeron, Thalakos Scout); a Sliver lord is cast
  without weighing the opponent's Slivers.
- Unconfirmed by any probe, so not changed: a trigger raised while paying a
  cost names its targets before the new state-based check; Circles of
  Protection bind their shield to the source's id, not its timestamp.

## Verification

- Every probe failed before its fix and passes after it; the probes
  (`tests/_hunt/`, never tracked) were then deleted.
- **Gate** (`SHARDS=4 SUITE_TIMEOUT=3600 ./run_tests.sh`): 758 scripts,
  **12,410 tests, 559,259 asserts**, every shard exit 0 — the 21 new
  regression scripts above add 212 tests to the pack's own gate (737 /
  12,198).
- **Deck Lab** after the fixes, Spikes v Licids (seed 98100, 200 games an
  arm): −0.5 ± 7.0, inside its margin; the control replayed
  byte-identically.
- Python and the exported-build probe: see `docs/pack-9-tempest-block.md`
  (acceptance record).
