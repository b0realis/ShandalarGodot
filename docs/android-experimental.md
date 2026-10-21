# Android ARM64 — experimental

A native, sideloaded APK for Android tablets, handhelds and phones. This is
**not** the Meta Quest build and is not a Play Store release. The initial
support target is Android 10 or newer, a **64-bit Android OS** and working
OpenGL ES 3 graphics. A 64-bit processor running a 32-bit OS is insufficient.
Start with a landscape tablet or handheld; small-phone readability and the
wide range of mobile GPUs still need community testing. 4 GB RAM is a
provisional recommendation, not a measured minimum. There is no x86 APK.

## Install and play

1. Extract the Android release ZIP and open `Shandalar.apk` on the device.
   Allow installation from that particular browser/file manager when Android
   asks. Only install files you trust; revoke that permission afterwards.
2. Open **Shandalar (Experimental)**. The plain appearance is playable without
   downloading anything else. Landscape orientation is recommended.
3. For the classic appearance, leave `skin/original_skin.zip` zipped, copy it
   to the device's Downloads, then choose it in **Options → Skin**. Restart
   the game when prompted. The `-with-skin` ZIP includes this file; installing
   its APK alone does **not** install the skin.
4. Card pictures and completed optional card packs are not distributed.
   Prepare them on a desktop with the included tools (see
   `CARD-ART-AND-PACKS.md`). The card-picture ZIP (`cardart.zip`) goes in
   like the skin: copy it to Downloads and choose it in **Options → Skin**.
   That chooser takes only skin and card-picture ZIPs; it refuses the
   numbered packs (`Pack-1-DotP-complete.zip` … `Pack-9-Tempest-Block.zip`).
5. A numbered pack goes in the game's own folder,
   `Android/data/com.b0realis.shandalar.android/files/cardpacks/`, which a
   file manager on modern Android cannot write. Start the game once so it
   makes that folder, then copy each pack from a computer with `adb` (USB
   debugging on), through Downloads, under its exact name:

   ```sh
   adb push Pack-1-DotP-complete.zip /sdcard/Download/
   adb shell cp /sdcard/Download/Pack-1-DotP-complete.zip /sdcard/Android/data/com.b0realis.shandalar.android/files/cardpacks/
   ```

   Restart the game (or **Options → Card Packs → Rescan**) and enable the
   pack there. Never make that folder yourself with `adb shell mkdir`: the
   game cannot open a folder the shell made.

Touch plays the game. Enable the fullscreen large-card reader in Options
for a small display; the Android Back button/gesture acts as Escape. The
existing handheld controls and battery-saving options apply. Desktop Python
tools in this archive are for a computer, not a promise of a phone CLI.

The package ID is `com.b0realis.shandalar.android`; Quest keeps
`com.b0realis.shandalar`. The two installations and their saves are separate.
Update by installing a newer APK with the same signing certificate over the
old one. Do not uninstall first: uninstalling or clearing app data can erase
decks, settings and imported packs. Export important decks before updates.
No account, ranking service or store subscription is required. LAN play is
still local-network only; use matching game versions and enabled card packs.

Please report device model, Android version, RAM, graphics issues, whether
touch and file import work, and the steps to reproduce a problem. Emulator
checks do not establish physical-device compatibility, battery life or speed.

## Reproducible target recipe

Use the game commit named in the package README. The Android export adds a
platform preset and packaging instructions, not different duel/rules code.
The public `android-export-preset.cfg` included with this archive is the
preset used to produce this target; append it with an unused preset number
to the checkout's ignored `export_presets.cfg`.

Install Godot **4.7.2**, its official `android_release.apk` template,
OpenJDK 17 and Android SDK Platform Tools / Build Tools 36.0.0. Configure
Godot Editor Settings → Export → Android with the SDK and Java SDK paths.
Adjust only the template paths to the local installation. This target uses
the Compatibility renderer and the ordinary non-Gradle release template.
It retains that template's minimum/target SDK values: **Android 10+ is the
support target, not an installer-enforced minimum**. Do not set the
Gradle-only Min SDK field and assume it changed the non-Gradle manifest.

Create a private release keystore **outside the checkout**, with certificate
subject `CN=b0realis` (no real name, email or address). Back up the key and
password securely: future updates must use the same key. Never ship them.
Set `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`GODOT_ANDROID_KEYSTORE_RELEASE_USER` and
`GODOT_ANDROID_KEYSTORE_RELEASE_PASSWORD` in the build environment. Keep
credentials out of command histories, export presets, logs and source.
The version name comes from `project.godot`; set `version/code` to
`major * 1000000 + minor * 1000 + patch` (each latter component below 1000).

```sh
python3 tools/build_android.py --godot /path/to/godot \
  --sdk /path/to/android-sdk --out /path/to/android-arm64-experimental
```

The wrapper refuses test features, stale version codes, export errors,
unexpected package IDs/permissions, debug APKs, non-ARM64 libraries,
incompatible 16 KiB library alignment, invalid signatures and private home
paths. It neither installs nor uploads. For a checkout predating the wrapper,
the export itself is:

```sh
gtimeout -k 5 1800 godot --headless --path . --export-release \
  'Android Experimental' /path/to/android-arm64-experimental/Shandalar.apk
```

Before packaging, verify with SDK `apksigner verify --verbose --print-certs`,
`aapt dump badging`, `zipalign -c -P 16 4`, and
`python3 tools/package_release.py --guard /path/to/Shandalar.apk`.
Smoke-test installation, title, deck builder, a duel, touch, file import and
an in-place update. No temporary overrides or debug settings may ship.

```sh
python3 tools/package_release.py --platform android-arm64-experimental \
  --input /path/to/android-arm64-experimental --out /path/to/downloads \
  --skin-zip /path/to/original_skin.zip --commit FULL_GAME_COMMIT
```

Reuse the release's existing skin byte-for-byte. Add both ZIP hashes to its
SHA256SUMS and notes without replacing other targets or changing the tag.
Publication requires the owner's explicit request. Quest presets, signing
keys, installers and existing downloads remain untouched.
