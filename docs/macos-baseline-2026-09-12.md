# macOS local baseline — 2026-09-12

The imported Ubuntu working tree is recorded at
`59dc81b4022bcbe07513b6d0c496a827bd3b0ba1` (version `0.20.0-dev`).
The local branch `baseline/macos-2026-09-12` points there; changes are on
`local/macos-baseline`. `main` and the existing `origin` configuration were
left in place; no fetch, push or remote-access setup was performed.
The tracked starting tree was clean. Historical Git worktree registrations
still refer to the old Ubuntu paths; they were not used or repaired as part
of this setup.

## Installed locally

- Godot `4.7.2.stable.official.ed1daf0bf`, universal macOS app, in
  `../tools/Godot.app`. The existing `../tools/godot` remains the Ubuntu ELF.
- Matching `templates/macos.zip`, extracted from the official export archive
  into `../tools/export_templates/4.7.2.stable/`.
- GNU coreutils through Homebrew, providing `timeout` and `gtimeout`.

The engine and template archives were checked against the official
[Godot 4.7.2 checksums](https://github.com/godotengine/godot-builds/releases/download/4.7.2-stable/SHA512-SUMS.txt).
They and the checksum file are retained in `../tools/`, outside Git.

## Reproduce

From the checkout:

```sh
./run_tests.sh
python3 -m unittest discover -s tools -p 'test_*.py'
./tools/duel_soak.sh
./tools/duel_soak.sh --rules fifth
./build_release.sh --macos
open ../shandalar-build/macos/Shandalar.app
```

Run the test gate and soak sequentially: they share an isolated profile.
All wrappers honor an explicit `GODOT`, prefer the sibling `.app` on Mac,
and fail with exit 3 if the selected executable is missing. GNU `timeout`
is used when available, falling back to Homebrew's `gtimeout`.

Copy `export_presets.cfg.example` to `export_presets.cfg` on a new machine
and adjust template paths. The Mac preset expects the sibling template
location above. The local preset is ignored by Git; the example is tracked.
The Mac build uses the debug template and a local ad-hoc signature. It is
a local app build, with no publishing or notarization. Linux packaging and
web builds retain their existing workflows. Import the owner's art through
Options > Skin; the app itself includes no original art or card pictures.

The project enables ETC2/ASTC imports as required by Apple's ARM64 exporter.
The Compatibility renderer is unchanged. The macOS app includes both ARM64
and x86_64 binaries; only ARM64 is exercised on this M4 Mac.

## Profile isolation

The starting scripts' `XDG_DATA_HOME` protection worked on Ubuntu but did not
apply to Mac. A separate scratch project reproduced this before the fix
(home-directory username redacted below):

```text
PROFILE_PROBE user_dir=/Users/<user>/Library/Application Support/Godot/app_userdata/Shandalar Profile Probe
PROFILE_PROBE xdg=/private/tmp/shandalar-profile-probe
```

This agrees with Godot's [platform data-path documentation](https://docs.godotengine.org/en/4.7/tutorials/io/data_paths.html).
The wrappers now set `GODOT_EDITOR_CUSTOM_FEATURES=shandalar_test` on Mac,
which selects the `config/name.shandalar_test` override before autoloads
read settings. The resulting profile was verified on disk:
`~/Library/Application Support/Godot/app_userdata/Shandalar Tests/`.
Linux continues to use `SHANDALAR_TEST_DATA_HOME`/XDG. On Mac that variable
controls wrapper log locations; it does not move the test profile.

The exported app's boot check temporarily uses an `override.cfg` alongside
its pack to select `Shandalar Build Smoke`, then removes it on exit. The
resulting app passes `codesign --verify --deep --strict`. An editor runtime
feature does not isolate an exported template, and official Mac templates
refuse `--main-pack`; both differences were checked rather than assumed.

## Baseline evidence and fixes

Logs are retained in `../shandalar-build/macos-baseline/`.

- The original test wrapper could not start: `timeout: command not found`,
  followed by `SUITE IS NOT GREEN: GUT printed no summary at all.`
- With only the Mac launch prerequisites in place, the complete GUT gate
  passed: **6085 tests, 156340 assertions, 353 scripts, 194.887 seconds,
  exit 0** (`gut-baseline.log`). No game rules or cards had been edited.
- The original Python gate failed seven real-terminal assertions, also
  outside the execution sandbox. macOS drops unread PTY output when its
  last slave handle closes. Keeping the parent slave alive until the output
  is drained fixed all seven: **217 tests, OK, one Linux-specific skip**.
- The first live soak completed **six duels**, demo and human modes,
  seeds **1000, 1037, 1074**, with no errors, warnings or stalls
  (`soak-modern.log`).
- `GamePaths.is_own()` accepted parent escapes based only on a `user://`
  prefix. A regression failed three assertions (`paths-before.log`);
  normalized containment and symlink rejection now protect the deletion list.
- `DeckStore.is_user_deck()` had the same issue plus a missing directory
  boundary. `delete_deck()` returned an empty success string and actually
  removed a disposable `user://decks_guard_probe_….deck` sibling outside
  `user://decks`. The two regression tests failed six assertions
  (`deck-paths-before.log`). They now pass, along with real symlink checks:
  **12 tests, 65 assertions** (`paths-after.log`).
- A failed Godot launch during `duel_soak.sh --help` used to return success;
  the wrapper now preserves the process exit status. Wrapper contract tests
  cover this and missing explicit engine paths across all five tools.
- An actual exported duel boot created `Contents/MacOS/duel_log.txt`
  (464 bytes) inside its app bundle. `GamePaths.executable_dir()` now locates
  portable files beside the `.app`; both the running log and portable skin
  lookup use it. A path-contract test covers macOS bundles, ordinary binaries
  and misleading non-bundle directory names.

Review concentrated on launch/export boundaries, settings/profile ownership,
skin archive import and deletion, deck persistence, and the rules engine's
public casting, mana and priority validation. No new rules or AI behavior
has been changed. This was a focused audit, not a claim that every card or
every branch of the rules engine is defect-free.

The first final-state GUT run passed 6090 tests / 156436 assertions, but its
wrapper exited 2: a help-text edit while the shell was still running changed
the script's read offsets. `bash -n` passed on the resulting file. That run
(`gut-verified.log`) is **not** counted as a green gate; the unchanged script
completed the fresh green run below before the local commit.

## Final quality gates

- `./run_tests.sh`: **6090/6090 tests, 156436 assertions, 353 scripts,
  200.869 seconds, exit 0** (`gut-release.log`). GUT reports one warning
  and two deprecations; the strict wrapper found no failing/risky/pending
  tests, load failures, engine ERROR lines or shutdown leaks.
- Python: **219 tests, OK, one Linux-specific skip, exit 0**
  (`python-verified.log`).
- Post-fix native live soak: **six duels finished, exit 0**, both demo and
  human modes, seeds 1000/1037/1074, no errors/warnings/stalls
  (`soak-verified.log`). The earlier explicit fifth-edition run also
  completed all six (`soak-fifth.log`).
- Final `./build_release.sh --macos`: **exit 0**, 186 MB universal app,
  boot smoke clean with both local art packs mounted
  (`build-macos-final.log`, `../macos/smoke.log`). Bundle signature checked
  successfully after smoke cleanup; no override or duel log remained inside.
- `bash -n` on all five wrappers and `tools/runtime.sh`, plus
  `git diff --check`: **exit 0**. `decks/ratings.txt` remains unchanged.

## Packaged-runtime verification

The native app's Deck Lab and the editor wrapper both played Big Green versus
Black-Red Raiders with `--games 10 --seed 4242 --jobs 1 --procs 1 --no-elo
--no-svg`. Both finished **4–6 with zero stalls**. Their `results.json`
`matchups` data matched exactly; this compares aggregate results, not a
per-action replay. Evidence: `packaged-lab.log`, `editor-lab.log` and their
similarly named result folders. The tracked `decks/ratings.txt` was unchanged.

Repeating the exported duel probe after the bundle-path fix wrote a 462-byte
`duel_log.txt` **beside** the probe app, with none in `Contents/MacOS`.
Removing the temporary scene/profile override restored a clean
`codesign --verify --deep --strict` check. The disposable probe app was
removed after verification; its logs are retained.

For local play, `../shandalar-build/macos/skin/` links the owner's existing
`../../pkg/original_skin.zip` and `../../local/cardart.zip`. A native boot
mounted **240 skin files and 1794 card-art files** without errors
(`skinned-native.log`). These links and the art remain outside Git and are
not a distribution package.

The final app was opened with macOS Launch Services and its native process
was verified running at `../shandalar-build/macos/Shandalar.app`.

Direct visual inspection could not proceed while macOS was locked. Native
windowed automated duels and packaged headless checks exercised the runtime;
they are not a claim of manual visual approval. The existing Ubuntu binary
and Linux workflow were preserved, but a fresh Linux or Intel-Mac run was
not performed on this ARM64 host.
