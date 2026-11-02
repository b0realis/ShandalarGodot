# Post-integration bug campaign — 2026-09-16

Follow-up to the [packs + SGManalink integration](packs-sgmanalink-integration.md),
starting at `10295ee` on `integration/packs-sgmanalink`. This is a bounded
reproduce-first campaign, not a declaration that every interaction is bug-free.
Main remains at `6a52c6a`; no release or generated pack/art ZIP is published.

## Six reproduced defects and repairs

1. **Taste of Paradise's repeated payment was missing in LAN play.** The host
   advertised only printed X costs as variable, rejecting two additional
   payments with `Invalid mode or X.` The shared screen opened no count dialog.
   Announcements, budgeting and auto-payment now include repeated additional
   costs and use the engine's existing payment calculation. The dialog names
   the additional cost. Manual and double-click casts buy two repetitions with
   eight suitable mana; reserved Forests are not tapped to increase the count.
2. **Fire Covenant's LAN chooser treated life as mana.** With 17 life it
   advertised a maximum of 1,000, and double-click dismissed the explicit choice.
   The host now bounds the choice by current life and refuses automatic life
   selection. The dialog says `Life to pay (X):`, starts at zero, and survives
   double-click. A positive control explicitly chooses three life and three
   damage points, then verifies the actual payment and killed creature. The
   engine remains responsible for final legality; the old invalid estimate
   was not evidence of the engine allowing payment of nonexistent life.
3. **Same-total mana conversion left a cast waiting forever.** Both local and
   detached LAN screens watched only the floating total. Agent of Stromgald
   changed one red mana into one black, but the waiting Dark Ritual never
   retried. The screen now snapshots the pool's colors and restrictions, with
   copied values rather than retained card objects. Actual click-path tests
   cast the Ritual after conversion in both screens.
4. **LAN payment estimates ignored floating-mana permissions.** Sunglasses of
   Urza plus five white mana reported Disintegrate's maximum X as zero instead
   of four. Budget/reachability now use the referee's substitution permissions.
   A North Star control accepts floating green mana for a spell but not Frozen
   Shade's ability, and estimation does not consume the permission. This repairs
   floating-pool checks; it does not extend ManaPlanner's search to every
   untapped-source substitution combination. Mana can still be produced manually.
5. **Saving a draft pool erased disabled-pack choices.** Toggling a pack alone
   preserved its remembered cards, but editing and saving the visible pool did
   not. Save now retains known pack identities absent from the current selector.
   Re-enabling Pack 5 restores a previously selected Force of Will alongside
   the newly chosen Island. Unchecking Force of Will while visible still removes
   it deliberately. The selector explains this behavior.
6. **Required-pack deck loading offered activation during a catalogue lock.**
   Options respected an active LAN host, but the deck-load popup displayed an
   enabled button that silently failed. It now disables activation and explains
   that connections/hosting must close first. A stale activation callback also
   reports the lock refusal. Loading as proxies remains available.

The four existing regression scripts gained **13 tests** and a stronger actual
right-click path for Elvish Spirit Guide. Focused final checks total **35 tests /
3,636 assertions**, all strict wrapper exits zero. Initial failing reproductions
are retained separately from acceptance logs; an incorrect popup-node name in
one test was corrected and is not counted as a product defect.

Wire protocol remains **12**. The rules fingerprint advances to
`sgmanalink-packs-2026-09-16-2`, deliberately requiring matching updated peers
and enabled catalogues. Old integration checkpoints/fingerprints are not
migrated. The game version remains **0.30.0**; pack manifests are unchanged.

## Final verification

- **Full GUT gate:** 7,157/7,157 tests, 322,040 assertions, 439 scripts,
  576.881 seconds, strict wrapper exit **0**. No failing/skipped/risky tests,
  runtime errors or exit-time object leaks accepted. Vendored font-UID fallback
  warnings, GUT's compatibility warning and two deprecations remain; this is
  not a warning-free tooling claim.
- **Python tooling:** 256 tests, one existing platform skip, exit **0**.
- **Expansion AI campaign:** 162 complete Wizard-v-Wizard duels, 54 each for
  Ice Age, Homelands and Alliances. Three rounds of nine themed matchups under
  each ruleset; fresh base seeds 43100, 54100 and 57100, with 100000 added for
  Fifth Edition. Every tool exits **0**, with no errors/warnings/stalls/leaks.
  Actual-use logs include 13 Taste of Paradise casts, 18 Force of Will casts,
  13 Contagion casts, 20 Necropotence casts, two Ashen Ghoul activations and
  38 Giant Oyster activations. This is completion/use coverage, not an AI-strength
  comparison; no new AI strategy or Deck Lab rating was installed.
- **Live-screen logic:** 24 complete duels, twelve stock and twelve Alliances,
  split equally between modern and Fifth Edition and between demo/automated
  human-seat modes. Stock seeds 8100, 8137, 8174; Alliances seeds 58000, 58037,
  58074. All four gates exit **0**, with no errors/warnings/stalls/leaks.
  These renderer-free runs exercise the real DuelScreen, not native visual QA.
- **Fresh macOS debug export:** build/smoke boot and all five actual local-ZIP
  probes pass. Pack 1 checks 746 set-art paths and its dormant scripts; Pack 2
  checks 102 scripts, 204 decoded pictures and seven textures; Pack 3 checks
  346 dormant scripts, 746 pictures and three textures; Pack 4 checks 115
  scripts, 230 pictures and three textures; Pack 5 checks 144 scripts, 288
  pictures and three textures. These run in the exported executable, not the
  source editor. Its temporary profile override is removed and strict ad-hoc
  signature verification passes again.

Source runs use the separate `Shandalar Integration Tests` profile. Export
smoke/probes use named test profiles. The player's settings remain byte-identical,
and both original main and pack-branch checkouts remain clean and untouched.

## Repeat and inspect

From the integration checkout:

```sh
./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
SOAK_HEADLESS=1 ./tools/duel_soak.sh --rules modern --seeds 8100,8137,8174
SOAK_HEADLESS=1 ./tools/duel_soak.sh --rules fifth --seeds 8100,8137,8174
./build_release.sh --macos --out ../shandalar-build/integration-bug-campaign-2026-09-16/macos
```

For expansion audits, use the isolation/runtime setup documented in the
[integration report](packs-sgmanalink-integration.md#reproduction-and-evidence).
Run each `tools/pack_N_duel_audit.gd` with `--rounds 3 --seed BASE` and its
real local ZIP, under a direct 600-second GNU timeout. For the Alliances UI
checks, run `tools/pack_5_ui_soak.gd` with `--rules modern` then `--rules fifth`,
`--seeds 58000,58037,58074`, and a direct 900-second timeout. Require exit zero,
the expected completion count, and no error/warning/stall/leak lines. Never
run independent source campaigns concurrently against the same test profile.

Local evidence is outside Git in
`../shandalar-build/integration-bug-campaign-2026-09-16/`: `full-gut.log`,
`python.log`, `controls-test_*.log`, `green-test_pack_5_integration.log`,
`pack-{3,4,5}-ai.log`, `soak-{modern,fifth}.log`,
`pack-5-ui-{modern,fifth}.log`, `build-macos.log` and
`real-pack-{1,2,3,4,5}-final.log`. Earlier red/setup logs are not acceptance
results. In particular, the first export probe used a relative engine-log path
that the native app could not open; the final probes use absolute log paths
and pass the strict scan. That was probe setup, not a seventh game defect.

No new browser, native Windows/Linux, native screenshot or physical
multi-computer LAN check was performed in this campaign. The earlier
integration report's release-playtest limits still apply. Review/merge remains
separate from publishing a release; continue distributing pack construction
tools and source metadata only, never the locally built artwork ZIPs.
