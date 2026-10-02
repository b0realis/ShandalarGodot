# Handheld test packages

These packages contain the same game as the corresponding desktop release,
with handheld launchers and instructions. They do not alter rules, decks,
the card pool or the existing desktop layout. Both plain and original-skin
variants are available. Card pictures remain separate: copy your own card
packs into `skin/` beside the executable, or import them through Options.

The Steam Deck package has been through three owner playtests; the ArkOS
package has not been on physical hardware, and the Meta Quest APK below is
new. This is not a claim of Steam Deck Verified status, membership of the
PortMaster catalogue or a Horizon Store review. The controller pointer
described below is verified by the test suite's synthetic pad events and,
on the Deck, by a pad in a hand.

## Handheld defaults

Both launchers export `SHANDALAR_HANDHELD` (`steam-deck` or `arkos`) before
starting the game; an Android build has no launcher and is the handheld
itself, so its word is `android` unless the variable says otherwise. Under
that word, three settings that you have **never changed** open on a
handheld's defaults instead of the desktop's: **Full screen** on,
**Full-screen card on click** on, and **Power saver** on. A choice you make
in Options is written and always wins — a handheld that you set to windowed
stays windowed — and nothing is written until you choose. Starting the
executable directly, without the launcher, gives the desktop's defaults.

**Full-screen card on click**: click or tap the large preview in a duel or
Deck Builder to fit the card to the screen; click again, Escape or controller
Cancel closes it. Local computer play waits while reading; a network opponent
and host keep playing. The normal sidebar layout is unchanged.

**Power saver** (Options → Display) puts the engine into its low-processor
mode: the screen is redrawn only when something changes and the process rests
between frames. A card table is still most of the time, so this is the
battery's biggest saving; it costs a still screen nothing and takes effect at
once. Off by default on a desktop.

## Controller pointer

The game's own pad pointer (**Options → Display → Pad pointer**) turns a
controller into the mouse the 1997 screens were written for. `Auto`, the
default, is on whenever a controller is connected and off otherwise; a real
mouse motion always takes the pointer back, so a trackpad and a stick can be
used in turn without a switch.

| Control | Action |
| --- | --- |
| Left stick | Pointer (fine near the centre, fast at full tilt) |
| D-pad | Hop to the nearest card, button or pile in that direction |
| A | Left click; hold and move for a drag; two quick presses to auto-cast |
| LB | Right click: the card, territory and life-box mini-menus |
| RT | Left click too, pulled past half way — for a trackpad under the same hand |
| LT | Right click too, the same way |
| Right stick | Scroll wheel |
| RB | The one button: advances the duel (Space) |
| X | Done (Enter) |
| B | Cancel (Escape); closes a mini-menu |
| Y | Fold the hand to name bands and unfold it (the hand's title shows `[+]` while folded) |
| Start | Pause menu |
| Back | Duel log |
| Right stick press (R3) | Read the card: the sidebar's card full-size; the same press closes it |

While a mini-menu is open the D-pad walks its entries and A picks one. RB,
X, B, Y, Start, Back and R3 can be rebound in Options → Controls; A, LB, the
triggers, the D-pad and the sticks belong to the pointer while it is on.
With the pointer off, the D-pad and the left stick move the engine's focus
ring over the menus' buttons and A presses the focused one; the shell,
Options, the battle setup and the gauntlet's startup window each start the
ring on their first button, for the keyboard too.

A pad click lands where the pointer is: on the button that has the focus
when the pad alone is in use, or wherever a mouse or trackpad last put the
pointer — so on a Deck the right trackpad can point and RT click, like a
mouse with its button under the other finger. A window taller than the
screen (a pool with many sets in AutoDeck) keeps its buttons on the screen
and scrolls its body: the right stick, or a hop, reaches every line.

A hop lands on the part of a card that is actually showing. In the hand
window the cards stand in a stack, each showing a band of its top edge
under the next: up and down walk the stack one card at a time, landing on
each card's band, and left and right leave the stack for whatever stands
beside it — a card on the table, a button in the Situation Bar, the
graveyard and exile plates, which are hop targets like any button. A hop
never lands on what is already under the pointer, so pressing the same
direction again always moves on. An open graveyard or exile view stays
over every duel window and under the Situation Bar, whose Cancel still
works over it; its cards are hop targets, a **Done** button under the
shelves closes it, and a double click on the plate leaves it open.

## Reading a card

**Read the card** (`R` on a keyboard, the right stick's press on a pad,
R2 on ArkOS; Options → Controls) brings the sidebar's card — the one the
duel or the Deck Builder is showing large — up full-size to read, whether
or not *Full-screen card on click* is on, and the same key closes it
again; so does Escape, controller Cancel, or a click or tap on the card.
Nothing else happens while the card is up: Space does not pass the turn
and Enter does not press Done. The key waits under a pause menu, a
dialog or the Deck Builder's menu. It was asked for by a tester on a
3.5-inch screen, where the sidebar card is too small to read and the
table at a glance is still fine.

## On-screen keyboard

A handheld with a pointer and no keys cannot name a deck, a table or a
seed, or type into the Deck Builder's search. **Options → Display →
On-screen keyboard** puts a board of keys across the window whenever a
text field takes the focus: point and click to type, `Shift` holds for
one key, `Enter` submits a one-line field and puts the board away (it is
a new line in a notes box), `Done` puts it away without submitting, and
a click on the field brings it back. The keys never take the focus, so a
physical keyboard beside the board still works. `Auto`, the default,
shows the board on a handheld the launcher named — ArkOS, or a Steam
Deck, where Steam's own keyboard is not always within reach of a game
started outside Steam — and never at a desk; an Android build has the
system's keyboard and never sees this one. `On` shows it wherever a
field takes the focus, `Off` never. The board docks at the
bottom, or at the top when the field is down there, and takes at most
two fifths of the window.

## Steam Deck

1. In Desktop Mode, extract the whole Steam Deck ZIP into a writable folder.
2. Add `run.sh` as a Non-Steam Game in Steam. Keep `Shandalar.x86_64` and
   `Shandalar.pck` beside it. If permissions were lost, run
   `chmod +x run.sh Shandalar.x86_64` from that folder.
3. Leave forced Proton compatibility off: this is a native Linux executable.
4. Choose a Steam Input layout, then launch from Gaming Mode. Either works;
   do not mix the two on one button.
   - **Gamepad layout** — the recommended template is **Gamepad with Mouse
     Trackpad**: the game sees the controller and its pad pointer plays the
     table with the buttons listed under *Controller pointer* above, the
     right trackpad is the mouse and takes the pointer whenever it is
     touched, and RT and LT click where it points. Leave the triggers as
     the gamepad's own triggers in the layout; the game makes them the
     mouse buttons itself. (The plain *Gamepad* template works too, with
     the left stick as the pointer and no trackpad.)
   - **Keyboard and mouse layout**: the game sees no controller and Steam
     Input is the pointer. Right trackpad: mouse; R2: left click; L2: right
     click; A: Space; X: Enter; B: Escape; Y: H; D-pad: arrow keys. Map a
     rear button to Backspace for removing a selected card in Deck Builder.
     Drag with the trackpad while holding R2.

   Use Steam's on-screen keyboard for names/searches, or connect a keyboard.

Use only one keyboard/mouse binding per button, without an additional gamepad
output on that same button, to avoid duplicate actions: a button that sends
both the pad's B and an Escape key would open the Pause menu and close it
again in the same instant, and one that sends both the pad's A and a mouse
click would open a graveyard with one and close it with the other. The game
guards against both — the duel drops the second of two identical actions
from different devices within a tenth of a second, the pad pointer treats a
mouse click within that of its own click (either order) as the same press,
a second controller reporting a button already down is not a second press,
and a graveyard or exile view ignores a click on its dim for a quarter of a
second after opening — but a layout should not rely on that. The launcher requests
1280x800, caps rendering at 60 FPS and names the device (`SHANDALAR_HANDHELD`,
see *Handheld defaults*). It does not overwrite your Options or controller
bindings. Gaming Mode also controls the outer game window.

Saves/settings use the normal Linux `~/.local/share/godot/app_userdata/Shandalar`
location (or the `XDG_DATA_HOME` location if you deliberately set one). No
Steam account integration or cloud saves are installed by this package.

## RK3326 / R36 Ultra on ArkOS — experimental

Use an already working, **64-bit ArkOS installation** with a current PortMaster.
R36 Ultra-labelled devices and firmware forks vary; this package does not
flash firmware or promise compatibility with every board sold under that name.
Do not substitute the Raspberry Pi desktop launcher or a Godot 3 FRT runtime.

1. Extract the ZIP on your computer. Inside the versioned folder are
   `Shandalar.sh`, `shandalar/` and `SHA256SUMS`.
2. Copy the script and game folder together to the SD card's active `ports/`
   directory (usually `/roms/ports` or `/roms2/ports` on the running device).
3. Launch Shandalar from Ports. The launcher uses PortMaster's runtime manager
   to request `weston_pkg_0.2.squashfs` if absent; first setup needs connectivity.
   WestonPack 0.2.6 or newer is required. Its dependencies are not bundled here.
   Once installed, ordinary local duels do not need an Internet connection.
4. Keep existing `shandalar/conf/` when updating: it contains your profile at
   `conf/godot/app_userdata/Shandalar/`. Keep your added card packs too.

The launcher supplies the matching Godot 4 ARM64 executable, selects OpenGL ES
3 through WestonPack, requests PortMaster's reported display size and limits
rendering to 30 FPS. Missing display metadata falls back to 720x720, so update
PortMaster/device metadata if your screen is different. That cap is not a
performance guarantee. No CPU governor, overclock, swap or firmware change is
made. On a four-inch square screen, the desktop card table may be too small to
read comfortably; there is no dedicated small-screen reflow in this package.

| Control | Action |
| --- | --- |
| Left stick | Mouse pointer |
| Hold L1 | Slow pointer for precise selections |
| A / B | Left / right mouse click |
| X | Enter: Done in duel; add selected card in Deck Builder |
| R1 | Space: situation-bar action |
| Y | Fold/unfold the hand in duel |
| D-pad | Arrow keys; left/right browse cards in Deck Builder |
| L2 | Duel log |
| R2 | Read the card: the sidebar's card full-size; the same button, A, B or Start closes it |
| Right stick up / down | Page Up / Page Down where supported |
| L3 | Backspace: remove selected card in Deck Builder |
| R3 | Mute for this session |
| Start | Escape: cancel / pause |
| PortMaster hotkey + Start | Emergency exit; may interrupt unsaved work |

Text entry uses the game's own **on-screen keyboard** (see above): a board
of keys appears whenever a deck name, a table name or the Deck Builder's
search takes the focus, and the pointer presses them; the launcher's
`SHANDALAR_HANDHELD=arkos` turns it on for an unwritten settings file.
A USB keyboard works too. The mapping is editable in
`shandalar/shandalar.gptk`; logical A/B positions depend on PortMaster's device
mapping. Physical-pad actions are suppressed in the game process so a mapped
mouse click cannot also pass the turn — the game sees no controller here, so
its own pad pointer stays off and gptokeyb is the pointer. Other applications
are unaffected. The launcher names the device (`SHANDALAR_HANDHELD=arkos`), so
an unwritten settings file opens full screen with the card reader and the
power saver on; its own `--fullscreen` is respected by the game's boot.

The launcher keeps every temporary file **beside the game**, under
`shandalar/tmp/` (removed on exit) and the cache under `shandalar/conf/cache/`,
and only ever reads the system drive. A tester's R36 Ultra (2026-10-02) had
its 11 GB system partition completely full: the shell could not write the
temporary files PortMaster's own scripts need, `control.txt` came up
half-read and the launcher blamed a missing controller mapper
(`controller mapper unavailable`) although `gptokeyb` was installed. The
launcher now word-splits PortMaster's commands without temporary files,
runs an installed `gptokeyb` even when `control.txt` could not export it,
and writes a line to `portmaster.log` when `/tmp` has under a megabyte
free. The game then runs — but free the system drive anyway: PortMaster's
own dialogs and device detection fail the same way while it is full.

If launch fails, keep `shandalar/portmaster.log` and
`shandalar/portmaster.previous.log`. Report the exact device/board, ArkOS build,
PortMaster version and screen size. A launch test must check pointer movement,
dragging, no double actions, text readability, a complete duel, save/restart
and returning to Ports. Until those pass, treat this as a porting test build.

## Meta Quest 3

The Quest package is one Android APK: the same game as a **flat 2D panel**
in the headset's home, the way a browser or a 2D store app opens — not a
VR scene, no XR mode, no hand tracking. The headset's controller casts a
laser that the game sees as the mouse: point to hover, pull the trigger
to click, hold it to drag. The touch controls made for the Deck's screen
work the same on the panel. Quest 2 and Quest Pro run the same APK.

It is **sideloaded**, never installed from the Horizon Store. Tested on
a Quest 3 (2026-09-29): the panel, the skin, the card packs, the music
and the laser's hover all work once the files are in the right folders,
and the folders are the whole story (below). The third report — the
Magic Battle deck list's menu opening and closing under one click — was
the touch layer's own release landing in a menu taller than the panel,
fixed in 0.40.51 inside the layer (`TouchControls`), nothing on the
headset's side.

**adb on a Linux machine.** `adb` is the Android debug bridge, one small
program; the Meta Quest Developer Hub that wraps it is Windows/macOS
only, and it is not needed.

```sh
sudo apt install adb                 # Debian, Ubuntu, Mint
sudo dnf install android-tools       # Fedora
sudo pacman -S android-tools         # Arch
```

The headset must be allowed to talk to a non-root user. Most
distributions' `android-tools` packages ship the udev rule; if
`adb devices` prints the headset as `no permissions`, write one:

```sh
printf 'SUBSYSTEM=="usb", ATTR{idVendor}=="2833", MODE="0660", GROUP="plugdev", TAG+="uaccess"\n' \
  | sudo tee /etc/udev/rules.d/51-oculus.rules
sudo udevadm control --reload-rules && sudo udevadm trigger
sudo usermod -aG plugdev "$USER"     # then log out and in once
adb kill-server
```

(`2833` is the Oculus/Meta USB vendor id.) `unauthorized` is another thing: the headset has not yet been
told to trust this computer — put it on and answer the prompt.

**Install and push.**

1. Turn on **Developer Mode** for the headset in the Meta Horizon phone
   app (this needs a developer account, which Meta grants on request).
2. Connect the headset over USB, put it on and **Allow USB debugging**
   when it asks. `adb devices` on the computer then lists it as
   `device`.
3. Put your own `cardart.zip` — the card pictures, which no package
   carries ([card-art-and-packs.md](card-art-and-packs.md)) — in the
   extracted package's `skin/` beside `original_skin.zip`, and the card
   packs (`Pack-1-DotP-complete.zip` and the others) in a `cardpacks/`
   folder beside it. Then, from the extracted package:

   ```sh
   ./push_to_quest.sh
   ```

   It installs the APK, starts the game once when its folders are not
   there yet so that **the game makes them**, then pushes `skin/*.zip`
   and `cardpacks/` into them and lists the two folders. Your own faces
   go in `portraits/` and your own tunes in `music/` the same way
   (`adb push my_face.png /sdcard/Android/data/com.b0realis.shandalar/files/portraits/`);
   the sixteen faces the game ships are in the APK already and need no
   push.
4. In the headset, the game is under **Library > Unknown Sources**. The
   first start after a push checks every card picture once (a minute on
   the headset for seven packs); every later start is quick — the packs
   are sealed by their zip table and the pictures are not read again
   until the file changes (`PackSeal`).

By hand, the same three steps in the same order — install, start the
game once, push into the folders it made:

```sh
adb install -r Shandalar.apk
adb shell monkey -p com.b0realis.shandalar -c android.intent.category.LAUNCHER 1
adb shell am force-stop com.b0realis.shandalar
adb push skin/original_skin.zip /sdcard/Android/data/com.b0realis.shandalar/files/skin/
adb push skin/cardart.zip /sdcard/Android/data/com.b0realis.shandalar/files/skin/
adb push cardpacks/. /sdcard/Android/data/com.b0realis.shandalar/files/cardpacks/
```

**The folders must be the game's own.** This is what the first headset
test found: `adb push` into a folder that does not exist makes it, and
`adb shell mkdir` makes one too — as the **shell's** folder,
`drwxrws--- shell ext_data_rw`, and the game (its own Android user,
not of that group) may not enter it. The game then sees an empty corner
— no skin, no cards, no music — and logs one engine error from the
listing that would not open, while the files inside are readable all
along. A folder the game made is `drwxrws--- u0_a21 ext_data_rw` (the
user number varies) and works. So the game makes its four folders at
every start (`AndroidCorner`, from `Lifecycle`, before the autoloads
that read them), with a README in each, and the script starts it once
before pushing. If you made a folder from the shell, either open it up
(`adb shell chmod 775 <folder>`) or delete it (`adb shell rm -rf
<folder>`), start the game once, and push again. Never `adb shell
mkdir` in the corner.

**What the game says.** At every start the game writes its report of
the start into its corner, line by line as it goes, and the file is
the last start's:

```sh
adb pull /sdcard/Android/data/com.b0realis.shandalar/files/start_report.txt
```

```
android: Shandalar 0.40.50, started 2026-09-29 18:10:52
android: corner /storage/emulated/0/Android/data/com.b0realis.shandalar/files
android: skin /storage/.../files/skin: ok, 3 entries (README.txt, cardart.zip, original_skin.zip)
android: cardpacks /storage/.../files/cardpacks: ok, 8 entries (...)
android: portraits /storage/.../files/portraits: ok, 1 entries (README.txt)
android: music /storage/.../files/music: ok, 1 entries (README.txt)
android: tree ready after 4210 ms
android: window <w>x<h>, touchscreen yes, handheld android, pads []
skin pack: mounted /storage/.../files/skin/original_skin.zip (skin, 312 files)
card pack: found /storage/.../cardpacks/Pack-1-DotP-complete.zip (sealed, 40 ms)
android: first InputEventScreenTouch: device 0, finger 1 down at 907,456
android: first InputEventMouseButton: device -1 (mouse emulated from a touch), button 1 down at 907,456
```

`missing` and `NOT LISTABLE` on a folder line name the cure; `sealed`
after a pack is a start that did not read its pictures, `hashed` one
that did, and the milliseconds are what it cost. `card pool: N cards
in M ms (background)` (0.40.53) is the thread that compiled every card
script while the title stood — the title no longer waits for it, nor
for the SGManalink scripts its own script used to pull in; the 0.40.52
report's 9,071 ms to the tree were 3.2 s of engine boot, 1.2 s of
folders and seals and 4.6 s of those two compiles. A press on Magic
Battle, Gauntlet or the Deck Builder made before that line waits on
the title (0.40.54): the button reads `Loading cards…` until the pool
is in and the screen opens that frame — the title keeps drawing, the
press never freezes it. Options and Help open at once. The `first <event
class>` lines say, once per class, how the headset's laser reaches the
game — a touch, a mouse, a pad — which is what the pointer work turns
on; they stop after ten classes. (On the Quest 3 the laser's click is a
touch: `InputEventScreenTouch` from device 0, and the engine's mouse
button emulated from it.)

The same lines go to Android's log, but read that live: `adb logcat -c`,
then `adb logcat -v time -s godot Godot > quest.log` *before* the game
starts, and stop it after. `adb logcat -d` after the fact shows only
what is still in the main log buffer, a ring the headset's shell fills
in minutes — the second headset report lost the whole start that way
and kept the first click. `adb logcat | grep -iE "godot|shandalar"`
shows the shell's side of the app too (the panel, the window's size,
the focus), which the file does not.

**Where the files live.** On Android the game's private `user://` folder
(`/data/data/com.b0realis.shandalar/files`) holds `settings.cfg`, the
decks and the tournament checkpoints — the files the game writes — and
nothing outside the app can write into it. The three folders **you** fill
therefore sit in the app's own corner of the shared storage,
`/sdcard/Android/data/com.b0realis.shandalar/files/`, where `adb push`
writes and the app reads without any permission: `cardpacks/`,
`portraits/`, `music/` and `skin/` under it, the desktop play copy's
layout one level down. The `cardpacks_folder`, `portraits_folder` and
`music_folder` keys in `settings.cfg` still move them (`GamePaths`).
"Forget my zips" in Options empties only the game's private folder and so
does nothing there: what you pushed is yours to remove with `adb shell rm`.
Uninstalling the app removes both folders.

The on-screen keyboard opens for a name or a search field. The headset's
Android back gesture is Escape. The three handheld defaults above apply
(the word is `android`). Not hardware-validated: this is a local test
package, built and signed on the developer's machine (the signing key is
never in the repository) and not reviewed by any store.

## Build and validation

Package verified Linux x86-64 exports with `--platform steam-deck`, Linux
ARM64 exports with `--platform arkos-rk3326-experimental`, and the signed
APK of `./build_release.sh --quest` with `--platform meta-quest`, using
`tools/package_release.py` as described in [release-builds.md](release-builds.md).
The existing Linux and Raspberry Pi export presets supply the first two
payloads; the `Android Quest` preset (one arm64 APK on the prebuilt
template, no gradle build, `package/unique_name` `com.b0realis.shandalar`)
the third — the release keystore and its password live in
`../shandalar-build/keys/release.env` as `GODOT_ANDROID_KEYSTORE_RELEASE_PATH`,
`_USER` and `_PASSWORD`, outside the repository, and the editor settings
name a JDK 17 and an Android SDK with build-tools. No different engine
version or separate game fork is needed. Run the package and
handheld-launcher tests before distributing them. Verify ZIP checksums,
then from the extracted versioned directory run `sha256sum -c SHA256SUMS`.
Launcher simulation tests are not substitutes for target-hardware testing.

Integration references:

- [PortMaster porting guide](https://portmaster.games/porting.html)
- [WestonPack Godot 4 integration](https://github.com/binarycounter/Westonpack/wiki/Godot-4-Example)
- [PortMaster input mapping](https://portmaster.games/gptokeyb-documentation.html)
- [SDL controller allowlist](https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT)
- [Steam Deck development](https://partner.steamgames.com/doc/steamdeck)
