# Packs + SGManalink integration — 2026-09-16

This records the initial integration at `10295ee`. The subsequent
[bug campaign](integration-bug-campaign-2026-09-16.md) adds six repairs,
updates the verification totals and advances the rules fingerprint to
`sgmanalink-packs-2026-09-16-2`; the historical results below are retained.

## Scope and merge basis

Dedicated branch `integration/packs-sgmanalink` combines `main` at
`6a52c6a` (0.30.0) with `feature/pack-1-dotp-complete` at `30a348c`.
The original checkouts remain untouched. This work is not a release and does
not merge into `main`. (2026-10-27: it did merge later — the packs and
SGManalink both live on `main`, the only branch now.) Generated card packs and downloaded artwork stay local.

The main version commit arrived after the initial integration began. The
unmodified trial merge was aborted and restarted from that commit. Version
0.30.0 satisfies all five existing ZIP minimum-version contracts without
rewriting their manifests or weakening validation.

## Merge resolution

- Retain both draft provenance and required-pack metadata in deck models,
  import parsing, copies and Clear. Preserve explicit/blank sideboard rules.
- Keep the live SGManalink lobby plus the stacked pack badges and live counts.
- Keep the two branches' CODE_MAP additions and completed pack roadmap entries;
  retain main's LAN/draft status and parked internet/MElo scope.
- Consolidate the identical revealed-hand conditions. The automatic merge
  introduced two `MtgPlayer.hand_revealed` declarations despite no text conflict;
  the first import failed to parse MtgPlayer and its dependencies. Keep the
  documented main declaration only.
- Use a separate `Shandalar Integration Tests` macOS profile. Player settings
  are not an integration-test fixture.

## Reproduced boundary defects

The first focused run had **6 failing tests, 69/86 assertions passing**:

- Cached compatibility stamp survived a pack toggle: the enabled and disabled
  catalogues compared equal. Recompute after registry invalidation; the portable
  hash includes content, never the process-local reload counter.
- Force of Will's alternate announcement demanded printed `{3}{U}{U}` instead
  of `{0}`. Pass both the selected mode and real instance through payment,
  potential-mana estimates, auto-payment and X budgeting. Include alternative
  payment modes in host-authored response hints; the engine still validates
  costs/targets and holds private pitch choices atomically.
- Ashen Ghoul exposed its graveyard ability on the battlefield, then refused
  it from the graveyard with `This action is unavailable.` Filter announcements
  by their declared activation zone.
- Elkin Bottle's land was refused with `Card unavailable.` Carry a bounded
  viewer-specific exile-play permission and validate the action again on the
  host. Ordinary land-drop limits, including extra drops, remain authoritative.
- Private exile returned `Face-down card` to its authorized viewer. Reveal
  only to the permitted seat; opponents still receive masked properties.
- Melee's actor/projection were `1` where the engine chooser was `0`.
  Use the actual chooser and the defender's creatures, not an assumption that
  chooser and defender are the same seat. Reject the non-choosing seat.

After those fixes the focused run passed **6 tests / 91 assertions**.

A follow-up reproduced Elvish Spirit Guide's missing hand-mana menu and its
incorrect battlefield entry (**2 failed assertions**). Mana options now honor
their activation zone too. Real shared-screen tests exercise the pile menus,
Spirit Guide and Melee through detached views, not direct local-screen casts.

The draft boundary exposed an additional data integration failure: pack-only
names had no `DeckStats` rarity and were silently absent from the selector;
the default all-pack deal returned null. Registry printing metadata now exposes
enabled-pack rarities as a fallback without changing base canonical rarities.
Snow-covered basics use their printed common sheet, not recipe v1's fixed
five-name land sheet. The frozen SHA-256 dealer is unchanged. Saved deck
metadata carries both the recipe and required packs through native save, paste,
file import, copying and Clear. Raw recipe replay still works while packs are
disabled; the playable-pool audit deliberately continues to reject unavailable
identities until their packs are enabled.

The session-lifetime reproduction had **3 failing tests, 7/14 assertions**:
hosting allowed a pack switch/rescan; clients used construction-time catalogue
stamps; stopping a host did not preserve an independent client's catalogue.
Live/connecting/resumable clients and listeners now hold independent weak-owner
pack locks, released by Forget/Stop. A new connection obtains its current
fingerprint. Options explains why switches/rescan are unavailable. Deck Builder
source filters remain cosmetic and do not unload the catalogue.

Wire protocol/subprotocol advance together to **12** for the new explicitly
validated exile permission. Rules revision is
`sgmanalink-packs-2026-09-16-1`. Older peers must use the same integrated build
and enabled packs; old tournament fingerprints are deliberately incompatible.

## Verification record

- Python tooling: **256 tests**, one existing skip, exit 0.
- Focused mechanics: **6 tests / 91 assertions**, exit 0.
- LAN regression gate before the final Spirit Guide/draft additions:
  **196 tests / 36,760 assertions / 21 scripts**, 240.411 seconds, exit 0.
- Expanded pack integration (referee + actual shared screen + session locks):
  **16 tests / 3,395 assertions**, 13.155 seconds, exit 0; this includes all
  **1,608 identities** through the strict card DTO and disabled-pack checkpoint
  rejection followed by successful restore with the original pool.
- Final full gameplay/network gate, including all 21 new integration tests:
  **7,144/7,144 tests / 321,964 assertions / 439 scripts**, 567.573 seconds,
  strict wrapper exit **0**. This includes the combined draft/deck metadata,
  network bot's Melee decision, detached UI and catalogue-lock regressions.
  GUT reports one compatibility warning and two deprecations; this is not a
  claim of warning-free third-party tooling.
- Stock-deck live-screen soak: **12 complete duels**, six each under modern
  and Fifth Edition rules, seeds **1000, 1037, 1074** in both demo and
  automated human-seat modes. Renderer-free execution; both strict wrappers
  exit **0**, with no errors, warnings or stalls.
- Expansion AI smoke campaign: **54 complete Wizard-v-Wizard duels**,
  18 each for Ice Age, Homelands and Alliances, nine themed matchups per
  ruleset. Default base seeds **43000, 54000, 57000** respectively (Fifth
  Edition adds 100000). All three tools exit **0** without errors, warnings
  or stalls. Logs record actual casts/activations, including Force of Will,
  Contagion, Bounty of the Hunt, Ashen Ghoul and Giant Oyster. This bounded
  regression campaign is not a new statistical AI-strength claim.
- Fresh universal macOS debug export: build and clean smoke boot pass.
  The actual exported binary passes each real local ZIP's resource probe:
  Pack 1's 746 set-art paths and four dormant scripts; Pack 2's 102 scripts,
  204 decoded images and seven UI textures; Pack 3's 346 dormant scripts,
  746 decoded images and three textures; Pack 4's 115 scripts, 230 decoded
  images and three textures; Pack 5's 144 scripts, 288 decoded images and
  three textures. Executable pack probes pass, not just ZIP inspection.
- Exported binary without packs: **897 identities**, all **157 original
  decks** load, a default draft deals, and a real-socket local handshake and
  room creation succeed. With all packs: **1,608 identities / 2,004 set
  entries**, original decks, draft and real-socket checks succeed again.
- Real rendered viewport captures from the exported Mac binary verify the
  menu at **1280×800** and **800×600**, the centered six-row Extras panel,
  and the SGManalink lobby. These are native Godot viewport captures while
  the desktop is locked, not reconstructed screenshots.
- Linux and Windows debug exports and the Web release export succeed with
  no script/export errors. Vendored GUT resource-UID fallback warnings are
  present. Native Linux/Windows execution was not performed. The browser
  smoke attempt stalled while loading and is **not a passing runtime check**;
  its console also recorded missing optional skin/art ZIP warnings.

The ignored export presets are independent copies in this worktree, with JSON
metadata includes applied to every platform. Neither the original main presets
nor the source-only pack distribution policy is changed.

## Reproduction and evidence

From the integration checkout:

```sh
./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
SOAK_HEADLESS=1 ./duel_soak.sh --rules modern
SOAK_HEADLESS=1 ./duel_soak.sh --rules fifth
./build_release.sh --macos --out ../shandalar-build/packs-sgmanalink-integration/macos
```

For the expansion audit tools, source `tools/runtime.sh`, call
`shandalar_find_godot`, `shandalar_find_timeout` and `shandalar_test_profile`,
and set `SHANDALAR_PACK_3`, `SHANDALAR_PACK_4`, `SHANDALAR_PACK_5` to the locally
built ZIPs. Run each `tools/pack_N_duel_audit.gd` with the discovered Godot,
`--headless --path . --script`, `-- --rounds 1`, and a bounded 600-second GNU
timeout. Send output and `--log-file` to files, inspect exit status, and refuse
errors/warnings/stalls. Do not run different campaigns against the same test
profile concurrently.

Local evidence is outside Git in
`../shandalar-build/packs-sgmanalink-integration/`: `full-gut-1.log`,
`python.log`, `soak-modern.log`, `soak-fifth.log`, `pack-{3,4,5}-ai.log`,
`build-macos.log`, `real-pack-{1,2,3,4,5}.log`, `export-none-2.log`,
`export-{linux,windows,web}.log`, and `export-*.png`. Earlier red reproductions
are retained separately and are not counted as acceptance runs.

Temporary export-profile/probe files are removed after verification; the
Mac app's ad-hoc signature is rechecked. No player settings, source checkout,
generated ZIP, artwork archive, published release or Deck Lab rating is
changed by the integration pass.

## Merge recommendation and remaining limits

The dedicated integration is ready for source review and a merge into main;
it is **not** a cross-platform release certification. Review this branch
against main, preserving both parents' history. If main still points to
`6a52c6a`, it can fast-forward to the integration tip after approval. If main
advances, merge the new main into this branch and repeat the relevant gates
before merging. Do not replay only the feature tip and lose these boundary
fixes.

LAN peers must use this same integrated build and enabled card pool. The
protocol/rules revision intentionally rejects older peers and tournament
checkpoints; this pass does not migrate old checkpoints. Pack selection is
locked while hosting, connected or waiting to reconnect; close/forget the
session before changing it. Cosmetic Deck Builder filters remain available.

Before a new release, still perform Web gameplay in a supported browser,
native Windows/Linux playtests, and a physical multi-machine LAN smoke check.
The automated socket tests run locally and do not establish real-network
discovery/firewall behavior. Continue distributing only pack construction
tools and trusted source metadata, never the locally built pack/art ZIPs.
