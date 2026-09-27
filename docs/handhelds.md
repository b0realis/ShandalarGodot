# Handheld test packages

These packages contain the same game as the corresponding desktop release,
with handheld launchers and instructions. They do not alter rules, decks,
the card pool or the existing desktop layout. Both plain and original-skin
variants are available. Card pictures remain separate: copy your own card
packs into `skin/` beside the executable, or import them through Options.

Neither target has been tested on physical hardware yet. This is not a claim
of Steam Deck Verified status or membership of the PortMaster catalogue.

For small screens, enable **Options → Display → Full-screen card on click**.
Click or tap the large preview in a duel or Deck Builder to fit the card to
the screen; click again, Escape or controller Cancel closes it. The setting
is off by default and remembered. Local computer play waits while reading;
a network opponent and host keep playing. The normal sidebar layout is unchanged.

## Steam Deck

1. In Desktop Mode, extract the whole Steam Deck ZIP into a writable folder.
2. Add `run.sh` as a Non-Steam Game in Steam. Keep `Shandalar.x86_64` and
   `Shandalar.pck` beside it. If permissions were lost, run
   `chmod +x run.sh Shandalar.x86_64` from that folder.
3. Leave forced Proton compatibility off: this is a native Linux executable.
4. Configure Steam Input as keyboard and mouse, then launch from Gaming Mode.
   Right trackpad: mouse; R2: left click; L2: right click; A: Space;
   X: Enter; B: Escape; Y: H; D-pad: arrow keys. Map a rear button to
   Backspace for removing a selected card in Deck Builder. Use Steam's
   on-screen keyboard for names/searches, or connect a keyboard.

Use only one keyboard/mouse binding per button, without an additional gamepad
output on that same button, to avoid duplicate actions. Drag with the trackpad
while holding R2. The launcher requests 1280x800 and caps rendering at 60 FPS.
It does not overwrite your Options or controller bindings. Full screen can
be selected in Options; Gaming Mode also controls the outer game window.

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
| Y | Show/hide hand in duel |
| D-pad | Arrow keys; left/right browse cards in Deck Builder |
| L2 / R2 | Page Up / Page Down where supported |
| L3 | Backspace: remove selected card in Deck Builder |
| R3 | Duel log |
| Start | Escape: cancel / pause |
| PortMaster hotkey + Start | Emergency exit; may interrupt unsaved work |

Use a USB keyboard for text entry. The mapping is editable in
`shandalar/shandalar.gptk`; logical A/B positions depend on PortMaster's device
mapping. Physical-pad actions are suppressed in the game process so a mapped
mouse click cannot also pass the turn. Other applications are unaffected.

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
