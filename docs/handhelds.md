# Handheld test packages

These packages contain the same game as the corresponding desktop release,
with handheld launchers and instructions. They do not alter rules, decks,
the card pool or the existing desktop layout. Both plain and original-skin
variants are available. Card pictures remain separate: copy your own card
packs into `skin/` beside the executable, or import them through Options.

Neither target has been tested on physical hardware yet. This is not a claim
of Steam Deck Verified status or membership of the PortMaster catalogue. The
controller pointer described below is verified only by the test suite's
synthetic pad events, not by a pad in a hand.

## Handheld defaults

Both launchers export `SHANDALAR_HANDHELD` (`steam-deck` or `arkos`) before
starting the game. Under that word, three settings that you have **never
changed** open on a handheld's defaults instead of the desktop's: **Full
screen** on, **Full-screen card on click** on, and **Power saver** on. A
choice you make in Options is written and always wins — a handheld that you
set to windowed stays windowed — and nothing is written until you choose.
Starting the executable directly, without the launcher, gives the desktop's
defaults.

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

While a mini-menu is open the D-pad walks its entries and A picks one. RB,
X, B, Y, Start and Back can be rebound in Options → Controls; A, LB, the
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
| L2 / R2 | Page Up / Page Down where supported |
| L3 | Backspace: remove selected card in Deck Builder |
| R3 | Duel log |
| Start | Escape: cancel / pause |
| PortMaster hotkey + Start | Emergency exit; may interrupt unsaved work |

Use a USB keyboard for text entry. The mapping is editable in
`shandalar/shandalar.gptk`; logical A/B positions depend on PortMaster's device
mapping. Physical-pad actions are suppressed in the game process so a mapped
mouse click cannot also pass the turn — the game sees no controller here, so
its own pad pointer stays off and gptokeyb is the pointer. Other applications
are unaffected. The launcher names the device (`SHANDALAR_HANDHELD=arkos`), so
an unwritten settings file opens full screen with the card reader and the
power saver on; its own `--fullscreen` is respected by the game's boot.

If launch fails, keep `shandalar/portmaster.log` and
`shandalar/portmaster.previous.log`. Report the exact device/board, ArkOS build,
PortMaster version and screen size. A launch test must check pointer movement,
dragging, no double actions, text readability, a complete duel, save/restart
and returning to Ports. Until those pass, treat this as a porting test build.

## Build and validation

Package verified Linux x86-64 exports with `--platform steam-deck`, and Linux
ARM64 exports with `--platform arkos-rk3326-experimental`, using
`tools/package_release.py` as described in [release-builds.md](release-builds.md).
The existing Linux and Raspberry Pi export presets supply those payloads;
no different engine version or separate game fork is needed. Run the package
and handheld-launcher tests before distributing them. Verify ZIP checksums,
then from the extracted versioned directory run `sha256sum -c SHA256SUMS`.
Launcher simulation tests are not substitutes for target-hardware testing.

Integration references:

- [PortMaster porting guide](https://portmaster.games/porting.html)
- [WestonPack Godot 4 integration](https://github.com/binarycounter/Westonpack/wiki/Godot-4-Example)
- [PortMaster input mapping](https://portmaster.games/gptokeyb-documentation.html)
- [SDL controller allowlist](https://wiki.libsdl.org/SDL3/SDL_HINT_GAMECONTROLLER_IGNORE_DEVICES_EXCEPT)
- [Steam Deck development](https://partner.steamgames.com/doc/steamdeck)
