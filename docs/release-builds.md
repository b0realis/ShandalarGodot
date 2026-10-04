# Cross-platform release packages

Release packaging does not change the duel layout or rules. Godot 4.7.2
can cross-export the eight local test targets (Android Quest the eighth); verify the official template archive's
checksum and extract only the needed templates. Set local custom-template
paths in the ignored `export_presets.cfg`, using the example as a guide.
Separate Mac presets target Apple Silicon and Intel (the universal preset
remains available). Windows and desktop Linux target x86-64; Raspberry Pi
uses Linux ARM64 with both desktop and mobile texture imports.

Use the debug export template for desktop releases, as documented in
CONTRIBUTING.md. Web defaults to the non-threaded release template; the
separate `Web Threaded` preset uses `web_release.zip` and requires HTTPS
and COOP/COEP response headers (see `setup-web.txt`). No test-profile
feature may be enabled during export. Run each command with GNU timeout
(gtimeout on macOS), close stdin, and write output to its own log file.
Inspect the exit status and log for export errors.

```sh
godot --headless --path . --export-debug 'Windows 64' /path/to/windows64/Shandalar.exe
godot --headless --path . --export-debug 'Linux 64' /path/to/linux64/Shandalar.x86_64
godot --headless --path . --export-debug macOS /path/to/macos/Shandalar.app
godot --headless --path . --export-debug 'macOS Apple Silicon' /path/to/macos-arm64/Shandalar.app
godot --headless --path . --export-debug 'macOS Intel' /path/to/macos-intel/Shandalar.app
godot --headless --path . --export-debug 'Raspberry Pi 5 ARM64' /path/to/raspberry-pi5-arm64/Shandalar.arm64
godot --headless --path . --export-release Web /path/to/web/index.html
godot --headless --path . --export-release 'Web Threaded' /path/to/web-threaded/index.html
```

Check macOS signing after export and after unpacking its ZIP. Run all
available native boot/duel checks and test the web export through a local
HTTP server in a browser. Isolate test profiles; remove any temporary
`override.cfg` before signing or packaging. Clearly disclose targets that
could only be cross-exported and not natively tested. A PCK smoke test
on another OS does not establish native binary compatibility.

Once the source revision is committed, package each verified export:

```sh
python3 tools/package_release.py --platform windows64 \
  --input /path/to/windows64 --out /path/to/release-downloads \
  --skin-zip /path/to/original_skin.zip --commit FULL_COMMIT_HASH
```

Repeat with `linux64`, `macos-arm64`, `macos-intel`, `raspberry-pi5-arm64`,
`web` and `web-threaded` (`macos` still packages a universal app). The version comes only from
`project.godot`. The packager never exports, uploads, overwrites an existing
package, copies the whole build directory, or builds a card pack. It streams
the approved files into two ZIPs, checks their integrity, preserves launcher
permissions and app signatures, and writes no UID/GID or extended metadata.
All packages carry tools under `tools/`, a README and per-file SHA256SUMS.
They also carry `VERSION.txt`, generated from `project.godot` for the Windows
MCP server. Check the extracted Windows server with Python's `--catalogue`
and `--version` before testing engine calls on a Windows machine; the server
discovers `Shandalar.console.exe` without Bash. Those two metadata checks on
another OS do not establish native Windows runtime compatibility.
`packaging/bundled_decks.txt` explicitly lists the public deck files mirrored
under `decks/` for engine-free MCP listing/reading. Update it when adding or
removing a shipped deck; tests compare it with the tracked library. Never
replace this allowlist with a recursive copy of a local decks directory.
The packager rejects missing, duplicate, hidden, traversing or linked entries.
Verify listing and reading in the extracted package, then check and play a
returned deck path with the packaged engine.
The seven numbered-pack builders and their Python dependencies are bundled,
alongside explicitly allowlisted `cards/data/` and `packaging/card_packs/`
metadata. Pack 1's base assignments are generated from the source registry
at packaging time, avoiding a dependency on the checkout's card scripts.
`CARD-ART-AND-PACKS.md` is also embedded in the package README. Verify the
extracted builders from outside the source tree, not just their presence.
Never include artwork caches or generated numbered ZIPs in this tool bundle.
The older `build_release.sh --package` Linux/web paths use the same staging
helper, so they also carry the full construction toolkit and README instructions.
Only `-with-skin` includes `skin/original_skin.zip`; no package carries card
pictures. Validate the supplied skin with `tools/skin_catalogue.py --check`.

The seven-target local matrix consists of fourteen game ZIPs, the same
`original_skin.zip` as a separate download, and `SHA256SUMS` covering those
fifteen assets. Adding both handheld targets below brings this to eighteen game
ZIPs plus the separate skin (nineteen ZIPs). Keep a local verification report separate from the game
archives, describing native versus cross-export checks. The web game fetches
the bundled skin ZIP from its server on first load; manual import also works.
The Pi launcher selects OpenGL ES 3 and caps rendering at 60 FPS; this is not
a performance guarantee. The Mac minimum versions are declared in the
generated app's Info.plist, not inferred from generic Godot documentation.
Verify actual Mach-O slices (do not assume an export option thins the binary).

Optional handheld packages reuse these verified exports: `--platform steam-deck`
uses the Linux x86-64 payload; `--platform arkos-rk3326-experimental` uses the
Linux ARM64 payload; `--platform meta-quest` takes the signed APK that
`./build_release.sh --quest` exports from the `Android Quest` preset (the
release key lives outside the repository, see handhelds.md). Each produces
plain and skin ZIPs. See [handhelds.md](handhelds.md) for install, controls,
runtime dependencies and hardware-test requirements. ArkOS archives contain
a `Shandalar.sh` entry beside a stable `shandalar/` directory, inside the
versioned extraction folder. These are local test targets, not a claim of
Steam Deck verification, PortMaster catalogue inclusion or a store review.
Do not silently add them to a public release.

The official Mac template contains only `godot_macos_debug.universal` and
`godot_macos_release.universal`. Architecture-specific presets need derived
template ZIPs, not merely a changed architecture dropdown. Extract `macos.zip`
into a temporary directory. For each of `arm64` and `x86_64`, use `lipo -thin`
on both universal binaries, naming the outputs `godot_macos_debug.ARCH` and
`godot_macos_release.ARCH`. Archive the unchanged `macos_template.app` structure
with only that architecture's two executables, excluding the universal and
other architecture's binaries. Save as `macos-arm64.zip` / `macos-x86_64.zip`
beside the original template (preserve the original). Godot signs the final
exported apps. Verify both the Mach-O slice and final app signature.

For a later, explicitly authorised public release, publish
only this explicit list, never a wildcard over the build or local-art folder.
Create the release as a draft, upload and verify all assets against local
checksums, then publish. Keep personal paths and author details out of
notes, binaries, archives, tags and commits; use the configured pseudonym
and GitHub noreply address. Publication is always a separate, explicit
owner request, not the automatic tail of a local build.

## A release from two machines (2026-10-04)

One release may collect targets built on two machines — the Linux machine
(linux64, Raspberry Pi 5, Steam Deck, ArkOS, Meta Quest) and a Mac (the Mac
apps, and Windows and Web if wanted). Every package of a release must come
from the **same pushed commit** (its README links that commit), carry the
**same** `original_skin.zip` (compare its SHA-256) and name itself from the
same `project.godot` version. An explicit owner-approved platform hotfix may
be added later: preserve its actual version and commit in filenames and
README, and disclose the mixed revisions in the release notes rather than
relabelling it as the older build. The 0.50.13 release's 0.50.14 Web fix is
such an exception (2026-10-04).

1. **First machine:** build and package its targets, write `SHA256SUMS`
   over the ZIPs and the skin, and create the release as a **draft** whose
   tag targets the release commit:
   `gh release create vX.Y.Z --draft --target FULL_COMMIT --title "..." --notes-file RELEASE_NOTES.md <files>`.
   A draft stays invisible to players and its tag is created on publish.
2. **Second machine:** `git fetch && git checkout FULL_COMMIT` (a detached
   checkout is fine; `./build_release.sh -V` must print the version), take
   the skin from the draft — `gh release download vX.Y.Z --pattern original_skin.zip`
   — and check its SHA-256 against the draft's `SHA256SUMS`. Export and
   package as above, e.g. for the Mac apps:
   ```sh
   godot --headless --path . --export-debug macOS DIR/macos/Shandalar.app
   godot --headless --path . --export-debug 'macOS Apple Silicon' DIR/macos-arm64/Shandalar.app
   godot --headless --path . --export-debug 'macOS Intel' DIR/macos-intel/Shandalar.app
   python3 tools/package_release.py --platform macos-arm64 --input DIR/macos-arm64 \
     --out DOWNLOADS --skin-zip original_skin.zip --commit FULL_COMMIT
   ```
   (repeat the packager for `macos` and `macos-intel`; `windows64` and
   `web` likewise if built there). Check `codesign --verify --deep --strict`
   on each app and `lipo -info` on its binary, and smoke-boot each app.
3. **Merge the checksums:** `gh release download vX.Y.Z --pattern SHA256SUMS`,
   add the new ZIPs' lines (`shasum -a 256 Shandalar-X.Y.Z-*.zip`), sort by
   file name, and run `shasum -a 256 -c SHA256SUMS` over every file you hold.
   Upload: `gh release upload vX.Y.Z <new zips> SHA256SUMS --clobber`.
4. **Finish the notes:** `gh release view vX.Y.Z --json body -q .body > notes.md`,
   add the new targets to the download list and setup lines and their
   lines to the checksum block, then `gh release edit vX.Y.Z --notes-file notes.md`.
5. **Publish** only on the owner's word: `gh release edit vX.Y.Z --draft=false --latest`,
   then download one ZIP per machine and `shasum -a 256 -c` it.
