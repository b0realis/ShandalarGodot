#!/usr/bin/env python3
"""Package a verified Godot export, with and without an original skin.

No export, signing, installation, card-art generation or upload is performed.
Only platform payloads and explicitly selected player documents are included.
"""
from __future__ import annotations

import argparse
import hashlib
import os
from pathlib import Path, PurePosixPath
import re
import shutil
import stat
import zipfile

import tool_banner
import pack_1_dotp_complete as pack_one

ROOT = Path(__file__).resolve().parents[1]
PLATFORMS = ("linux64", "windows64", "macos", "macos-arm64", "macos-intel",
             "raspberry-pi5-arm64", "steam-deck", "arkos-rk3326-experimental", "web",
             "meta-quest")
MAC_PLATFORMS = ("macos", "macos-arm64", "macos-intel")
LINUX_BINARIES = {"linux64": "Shandalar.x86_64", "raspberry-pi5-arm64": "Shandalar.arm64",
                  "steam-deck": "Shandalar.x86_64",
                  "arkos-rk3326-experimental": "Shandalar.arm64"}
HANDHELD_FILES = {
    "steam-deck": {"run.sh": "packaging/handhelds/steam-deck.sh",
                   "HANDHELD.md": "docs/handhelds.md"},
    "arkos-rk3326-experimental": {
        "shandalar.gptk": "packaging/handhelds/shandalar.gptk",
        "HANDHELD.md": "docs/handhelds.md"},
    # One signed APK and the instructions; no launcher can run there.
    "meta-quest": {"HANDHELD.md": "docs/handhelds.md"},
}
QUEST_PACKAGE = "com.b0realis.shandalar"
QUEST_FILES = f"/sdcard/Android/data/{QUEST_PACKAGE}/files"
ARKOS_LAUNCHER = "packaging/handhelds/arkos.sh"
PACK_BUILDERS = ("pack_1_dotp_complete", "pack_2_fallen_empires", "pack_3_ice_age",
                 "pack_4_homelands", "pack_5_alliances", "pack_6_portal", "pack_7_fifth_edition")
# THE ONE DOOR of a release (2026-09-27), after the launcher prefix: the
# repo's shandalar.sh with the release's own targets. POSIX sh, like the
# prefix it follows. A verb it does not know is refused the way every
# tool refuses, one JSON line on stdout and exit 2.
DISPATCHER = """verb="${1:-}"
case "$verb" in
	"" | -h | --help)
		printf '%s\\n' \\
			'shandalar.sh lab|autodeck|check|packs|cards|referee|play|mcp ARGS...' \\
			'  lab       the Deck Lab (deck_lab.sh)' \\
			'  autodeck  the AutoDeck CLI (auto_deck.sh)' \\
			'  check     is this deck playable, and why not (lab_query.sh)' \\
			'  packs     every card pack: found, on, why not' \\
			'  cards     a card record' \\
			'  referee   one duel through a pipe, a program in a seat (referee.sh)' \\
			'  play      the game itself (run.sh)' \\
			'  mcp       the tools as an MCP server on stdio (tools/shandalar_mcp.py)' \\
			'VERB --help is that tool manual; -V the version; AGENTS.md is the contract page.'
		exit 0 ;;
	-V | --version) echo "shandalar.sh — Shandalar @VERSION@"; exit 0 ;;
esac
shift
case "$verb" in
	lab) exec ./deck_lab.sh "$@" ;;
	autodeck) exec ./auto_deck.sh "$@" ;;
	check | packs | cards) exec ./lab_query.sh "$verb" "$@" ;;
	query) exec ./lab_query.sh "$@" ;;
	referee) exec ./referee.sh "$@" ;;
	play) exec ./run.sh "$@" ;;
	mcp) exec python3 tools/shandalar_mcp.py "$@" ;;
esac
# Every control byte, DEL, `"` and `\\` out, and every byte past ASCII
# too unless the verb is valid UTF-8 — what is left is a JSON string
# (2026-10-03; the repo door shandalar.sh does the same).
safe="$(printf '%s' "$verb" | LC_ALL=C tr -d '\\000-\\037\\177"\\\\')"
printf '%s' "$safe" | iconv -f UTF-8 -t UTF-8 >/dev/null 2>&1 \\
	|| safe="$(printf '%s' "$safe" | LC_ALL=C tr -d '\\200-\\377')"
printf '{"error":{"tool":"shandalar","exit":2,"kind":"option","message":"unknown verb %s - the verbs are lab, autodeck, check, packs, cards, referee, play, mcp","verb":"%s"}}\\n' \\
	"'$safe'" "$safe"
echo "shandalar.sh: unknown verb '$verb' - try ./shandalar.sh --help" >&2
exit 2
"""

TOOLS = ("mtg_assets.py", "import_original.py", "fetch_card_art.py",
         "skin_catalogue.py", "tool_banner.py", "fetch_cards.py", "gen_cards.py",
         "shandalar_mcp.py",
         *(name + ".py" for name in PACK_BUILDERS))
# Explicit metadata allowlist: never recurse into a download/art cache.
PACK_DATA = {
    PACK_BUILDERS[0]: ("README.txt", "manifest.json", "missing_cards.json"),
    PACK_BUILDERS[1]: ("README.txt", "manifest.json", "cards.json", "set.json"),
    **{name: ("README.txt", "manifest.json", "cards.json", "set.json", "reprint_names.json")
       for name in PACK_BUILDERS[2:]},
}
PACK_DATA["pack_6_portal"] += ("cards_p02.json", "set_p02.json")
PACK_DATA["pack_7_fifth_edition"] += ("shared_names.json",)
BUILDER_DATA = tuple(f"cards/data/{code}.json" for code in pack_one.SET_ORDER) + tuple(
    f"packaging/card_packs/{pack}/{name}" for pack, names in PACK_DATA.items() for name in names)
BASE_ASSIGNMENTS = "packaging/card_packs/pack_1_dotp_complete/base_assignments.json"
DECK_MANIFEST = "packaging/bundled_decks.txt"
LOCAL_PACK = "Pack-1-DotP-complete.zip"
WORDMARK = ("┌─┐┌─┐┌─┐┬┌─", "├─┘├─┤│  ├┴┐", "┴  ┴ ┴└─┘┴ ┴")
START = {
    "linux64": "Linux x86-64: extract the whole folder and run ./run.sh.\n"
               "If your extractor dropped permissions: chmod +x run.sh Shandalar.x86_64\n"
               "This is not an ARM Linux binary.",
    "windows64": "Windows x86-64: extract the whole folder, then open Shandalar.exe.\n"
                 "Keep Shandalar.pck beside it. The executable is unsigned.\n"
                 "Shandalar.console.exe is the optional terminal launcher.",
    "macos": "macOS: extract the whole folder, then open Shandalar.app.\n"
             "Universal: Apple Silicon and Intel. Ad-hoc signed, not notarized.\n"
             "macOS may require explicit approval to open a downloaded app.\n"
             "Only approve software you trust; do not disable system-wide security.\n"
             "Keep skin/ BESIDE Shandalar.app, never inside its signed Contents.",
    "web": "Web: serve this folder over HTTP(S), not file://. For a local server:\n"
           "    python3 -m http.server 8000\n"
           "Then open http://localhost:8000/. No COOP/COEP headers are required.\n"
           "Browser storage belongs to this site's address. Export important decks\n"
           "before clearing it. The web build has no command-line Deck Lab.",
}
START["macos-arm64"] = START["macos"].replace(
    "Universal: Apple Silicon and Intel.", "Apple Silicon (arm64) only; macOS 13 or newer.")
START["macos-intel"] = START["macos"].replace(
    "Universal: Apple Silicon and Intel.",
    "Legacy Intel (x86-64) only; macOS 11 or newer with OpenGL 3.3.\n"
    "Older Intel hardware/OS versions still require on-device testing.")
START["raspberry-pi5-arm64"] = (
    "Raspberry Pi 5 / compatible newer ARM64 Linux: use a 64-bit desktop OS\n"
    "with working OpenGL 3.3 or OpenGL ES 3.0 graphics drivers.\n"
    "Extract the whole folder and run ./run.sh in a graphical desktop session.\n"
    "If needed: chmod +x run.sh Shandalar.arm64\n"
    "Not a 32-bit Raspberry Pi OS binary. Performance needs on-device testing.")
START["steam-deck"] = (
    "Steam Deck / SteamOS: native Linux x86-64, no Proton required.\n"
    "Extract the whole folder in Desktop Mode and add run.sh as a Non-Steam Game.\n"
    "Choose the Gamepad with Mouse Trackpad layout: the game's own pad pointer\n"
    "plays the table, the right trackpad is the mouse and RT/LT click where it\n"
    "points. A keyboard/mouse layout works too. See HANDHELD.md for the bindings.\n"
    "Local test package, not hardware-validated or Steam Deck Verified.")
START["arkos-rk3326-experimental"] = (
    "EXPERIMENTAL: RK3326 / R36 Ultra with 64-bit ArkOS and current PortMaster.\n"
    "Copy Shandalar.sh and the shandalar folder together into your ports folder.\n"
    "Launch Shandalar from Ports. WestonPack 0.2.6+ is required.\n"
    "See HANDHELD.md for controls, setup, saves and troubleshooting.\n"
    "Not hardware-validated; performance and small-screen readability are unproven.")
START["meta-quest"] = (
    "Meta Quest 3 (also Quest 2 / Pro): a flat panel app for the headset, installed\n"
    "over USB with adb (Linux: apt install adb, or the android-tools package; see\n"
    "HANDHELD.md for the udev rule). Turn on Developer Mode in the Meta Horizon\n"
    "phone app, connect the headset, allow USB debugging on it, put your own\n"
    "cardart.zip in this folder's skin/ (no package carries one), then:\n"
    "  ./push_to_quest.sh\n"
    "It installs the APK, starts the game once so the game makes its own folders\n"
    "in its files corner, and pushes skin/*.zip and cardpacks/ into them:\n"
    f"  {QUEST_FILES}/skin/       original_skin.zip, cardart.zip\n"
    f"  {QUEST_FILES}/cardpacks/  Pack-N zips; portraits/ and music/ beside it\n"
    "Never make those folders with adb shell mkdir: a folder made from the shell\n"
    "is the shell's and the game cannot enter it. The game is under Library >\n"
    "Unknown Sources; it reads the corner at every start (the first start after a\n"
    "push checks every card picture once, later starts are quick) and writes what\n"
    "it saw, the start's length and how the laser reaches it into the corner:\n"
    f"  adb pull {QUEST_FILES}/start_report.txt\n"
    "The controller's pointer is the mouse and the trigger clicks. See HANDHELD.md.\n"
    "Local test package, not hardware-validated or store-reviewed.")

# The headset's install-and-push script, shipped in the meta-quest package
# (docs/handhelds.md, "Meta Quest 3"). The order is the whole point: the
# game's folders in its shared-storage corner must be the GAME'S — a folder
# made with `adb shell mkdir` is the shell's (`rwxrws--- shell`) and the
# game, another user, cannot enter it — so the APK is installed, the game is
# started once to make them, and only then are the zips pushed into them.
QUEST_PUSH = f"""#!/bin/sh
# Shandalar on a Meta Quest: install the APK over adb and push the zips into
# the game's shared-storage corner. The game makes its folders there at its
# first start, and they must be ITS folders: one made from the shell
# (adb shell mkdir) is the shell's, and the game may not enter it.
set -eu
cd -- "$(dirname -- "$0")"
P={QUEST_PACKAGE}
F={QUEST_FILES}
adb install -r Shandalar.apk
if ! adb shell test -d "$F/skin"; then
  echo "starting the game once so it makes its folders..."
  adb shell monkey -p "$P" -c android.intent.category.LAUNCHER 1 > /dev/null 2>&1 || true
  n=0
  while [ "$n" -lt 30 ] && ! adb shell test -d "$F/cardpacks"; do sleep 1; n=$((n + 1)); done
  adb shell am force-stop "$P"
fi
# A folder made from the shell before this script existed: open it up.
adb shell chmod 775 "$F/skin" "$F/cardpacks" "$F/portraits" "$F/music" 2> /dev/null || true
for zip in skin/original_skin.zip skin/cardart.zip; do
  if [ -f "$zip" ]; then adb push "$zip" "$F/skin/"; fi
done
if [ -d cardpacks ]; then adb push cardpacks/. "$F/cardpacks/"; fi
adb shell ls -ld "$F/skin" "$F/cardpacks"
echo "done: start Shandalar from Library > Unknown Sources"
"""


def digest(path: Path) -> str:
    result = hashlib.sha256()
    with path.open("rb") as source:
        for block in iter(lambda: source.read(1024 * 1024), b""):
            result.update(block)
    return result.hexdigest()


def check_skin(path: Path) -> None:
    """Never publish a mislabelled card pack, unsafe paths or corrupt ZIP."""
    with zipfile.ZipFile(path) as archive:
        if not archive.infolist():
            raise ValueError("Empty skin archive")
        for entry in archive.infolist():
            parts = PurePosixPath(entry.filename).parts
            if (not parts or parts[0] != "skin" or ".." in parts
                    or "\\" in entry.filename or "cardart" in entry.filename.lower()
                    or stat.S_ISLNK(entry.external_attr >> 16)):
                raise ValueError("Skin contains unsafe entries or card pictures")
        if archive.testzip() is not None:
            raise ValueError("Corrupt skin archive")


def payload(folder: Path, platform: str) -> dict[str, Path]:
    family = "macos" if platform in MAC_PLATFORMS else platform
    if platform == "steam-deck":
        family = "linux64"
    elif platform == "arkos-rk3326-experimental":
        family = "raspberry-pi5-arm64"
    required = {
        "meta-quest": ("Shandalar.apk",),
        "linux64": ("Shandalar.x86_64", "Shandalar.pck"),
        "raspberry-pi5-arm64": ("Shandalar.arm64", "Shandalar.pck"),
        "windows64": ("Shandalar.exe", "Shandalar.console.exe", "Shandalar.pck"),
        "macos": ("Shandalar.app/Contents/MacOS/Shandalar",
                  "Shandalar.app/Contents/Resources/Shandalar.pck",
                  "Shandalar.app/Contents/Info.plist"),
        "web": ("index.html", "index.js", "index.wasm", "index.pck"),
    }[family]
    for name in required:
        if not (folder / name).is_file() or (folder / name).stat().st_size == 0:
            raise ValueError(f"Missing or empty export: {name}")
    if platform in MAC_PLATFORMS:
        files = [p for p in (folder / "Shandalar.app").rglob("*") if not p.is_dir()]
    elif platform == "web":
        files = [p for p in folder.glob("index.*") if p.is_file()]
    else:
        files = [folder / name for name in required]
    result = {}
    for path in files:
        name = path.relative_to(folder).as_posix()
        if re.fullmatch(r"Pack-[0-9]+-.+\.zip", path.name):
            raise ValueError(f"Local card-pack artifact must not be released: {name}")
        if path.suffix == ".zip":
            # NO ARCHIVE RIDES INSIDE A PAYLOAD. An export is an engine, a
            # .pck and the bundle around them; a ZIP among them is art or a
            # skin someone dropped where the README says not to ("Keep skin/
            # BESIDE Shandalar.app"). `cardart.zip` is the one file this
            # project never publishes, and the macOS payload — the only one
            # gathered by rglob — carried it into both release ZIPs and
            # their SHA256SUMS.
            raise ValueError(f"An archive inside the export must not be released: {name}")
        if path.is_symlink() or any(part.startswith(".") for part in Path(name).parts):
            raise ValueError(f"Unexpected link or hidden export file: {name}")
        if path.name == "override.cfg" or path.suffix in (".log", ".pdb"):
            raise ValueError(f"Unexpected diagnostic export file: {name}")
        result[name] = path
    return result


## The bytes a path component is made of. A home followed by one of these
## is a LONGER name ("/home/ann" inside "/home/anna"), not the home.
_NAME_CHARS = b"A-Za-z0-9._-"


def private_patterns(home: str | None = None) -> list[tuple[bytes, re.Pattern]]:
    """(literal, pattern) pairs for every spelling of the builder's home.

    A PATH, NOT A SUBSTRING (bug pass 2026-10-03). The needle used to be
    `$HOME` as bare bytes, so HOME=/root (a Docker build) refused the
    stock Godot template — "/root" is its scene tree's root node — and
    HOME=/ refused every file there is; while the same home spelt as a
    Windows binary or a JSON file spells it went through. So: "" and "/"
    are no home at all; a home of one component (/root) counts only with
    a separator after it, where it is a path into that folder; a deeper
    one (/home/ann) counts at any boundary but a longer name. Each is
    looked for with forward slashes, backslashes and JSON's escaped `\\/`,
    in UTF-8 and both UTF-16s. The literal is the cheap test a block must
    pass before the pattern is run on it."""
    home = (str(Path.home()) if home is None else home).rstrip("/\\")
    login = home.replace("\\", "/").rsplit("/", 1)[-1]
    roots = [home] if home else []
    if login and login not in (".", ".."):
        roots += [f"/home/{login}", f"/Users/{login}"]
    follows = {"utf-8": b"[%s]" % _NAME_CHARS,
               "utf-16-le": b"[%s]\x00" % _NAME_CHARS,
               "utf-16-be": b"\x00[%s]" % _NAME_CHARS}
    out = []
    for root in dict.fromkeys(roots):
        deep = root.count("/") >= 2
        for sep in ("/", "\\", "\\/"):
            form = root.replace("/", sep)
            for codec, follow in follows.items():
                if deep:
                    literal = form.encode(codec)
                    pattern = re.escape(literal) + b"(?!" + follow + b")"
                else:
                    literal = (form + sep).encode(codec)
                    pattern = re.escape(literal)
                out.append((literal, re.compile(pattern)))
    return out


def guard_private(paths: list[Path], home: str | None = None) -> None:
    patterns = private_patterns(home)
    for path in paths:
        with path.open("rb") as source:
            _guard_stream(source, path.name, patterns)
        # AN APK IS A ZIP OF DEFLATED FILES (bug pass 2026-10-03): 4,866 of
        # the Quest APK's 4,940 entries are compressed, so its raw bytes
        # never show a path written inside one — every member is read too.
        if path.suffix.lower() == ".apk":
            if not zipfile.is_zipfile(path):
                raise ValueError(f"{path.name} is not an APK (not a zip archive)")
            with zipfile.ZipFile(path) as archive:
                for info in archive.infolist():
                    if not info.is_dir():
                        with archive.open(info) as source:
                            _guard_stream(source, f"{path.name}:{info.filename}", patterns)


def _guard_stream(source, label: str, patterns) -> None:
    tail = b""
    for block in iter(lambda: source.read(1024 * 1024), b""):
        data = tail + block
        if any(literal in data and pattern.search(data)
               for literal, pattern in patterns):
            raise ValueError(f"Personal home path in {label}")
        tail = data[-512:]


def member(archive: zipfile.ZipFile, name: str, content: Path | bytes, executable=False):
    # Explicit metadata avoids UID/GID, extended attributes and home paths.
    info = zipfile.ZipInfo(name, (2026, 1, 1, 0, 0, 0))
    info.create_system = 3
    info.external_attr = (stat.S_IFREG | (0o755 if executable else 0o644)) << 16
    info.compress_type = zipfile.ZIP_STORED if name.endswith(".zip") else zipfile.ZIP_DEFLATED
    with archive.open(info, "w") as target:
        if isinstance(content, bytes):
            target.write(content)
        else:
            with content.open("rb") as source:
                shutil.copyfileobj(source, target, 1024 * 1024)


def bundled_deck_files(root: Path = ROOT) -> dict[str, Path]:
    """Public, reviewable allowlist; no workspace decks, ratings or directory crawl.

    Mirror the PCK's deck text for engine-free MCP browsing in extracted releases.
    A tracked manifest also works from git-archive source trees without .git.
    """
    files = {}
    for line in (root / DECK_MANIFEST).read_text(encoding="utf-8").splitlines():
        name = line.strip()
        if not name or name.startswith("#"):
            continue
        path = PurePosixPath(name)
        if (path.is_absolute() or len(path.parts) < 2 or path.parts[0] != "decks"
                or any(p.startswith(".") for p in path.parts) or "\\" in name
                or path.as_posix() != name or path.suffix.lower() not in (".deck", ".dec", ".dck")
                or name in files):
            raise ValueError(f"Invalid bundled deck entry: {name}")
        source = root / name
        if (not source.is_file() or source.is_symlink()
                or any(p.is_symlink() for p in source.parents if p != root and root in p.parents)):
            raise ValueError(f"Missing or linked bundled deck: {name}")
        files[name] = source
    if not files:
        raise ValueError("The bundled deck allowlist is empty")
    return files


def player_tool_files(root: Path = ROOT) -> dict[str, Path]:
    files = {"tools/" + name: root / "tools" / name for name in TOOLS}
    files.update({name: root / name for name in BUILDER_DATA})
    files["CARD-ART-AND-PACKS.md"] = root / "docs/card-art-and-packs.md"
    files["agentic-playgude-mtg.md"] = root / "agentic-playgude-mtg.md"
    files.update(bundled_deck_files(root))
    return files


def stage_player_tools(folder: Path, root: Path = ROOT) -> None:
    """Also serve build_release.sh's older Linux/web staging path.

    Existing identical tools are harmless; never replace different content.
    The destination is a fresh build staging directory, not a player profile.
    """
    files = player_tool_files(root)
    guard_private(list(files.values()))
    contents = {name: path.read_bytes() for name, path in files.items()}
    contents[BASE_ASSIGNMENTS] = pack_one.json_bytes(sorted(pack_one.assigned_pairs(root)))
    for name, content in contents.items():
        dest = folder / name
        if dest.is_symlink() or (dest.exists() and dest.read_bytes() != content):
            raise ValueError(f"Refusing to overwrite different staged tool data: {name}")
    for name, content in contents.items():
        dest = folder / name
        if not dest.exists():
            dest.parent.mkdir(parents=True, exist_ok=True)
            dest.write_bytes(content)
    readme = folder / "README.txt"
    previous = readme.read_text(encoding="utf-8") if readme.exists() else ""
    guide = contents["CARD-ART-AND-PACKS.md"].decode("utf-8")
    if guide not in previous:
        readme.write_text(previous + "\n\n" + guide, encoding="utf-8")


def package(folder: Path, out: Path, platform: str, skin: Path, revision: str,
            root: Path = ROOT) -> list[Path]:
    version = tool_banner.project_version(root)
    if not version or not re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+(?:-[A-Za-z0-9.-]+)?", version):
        raise ValueError("Invalid project version")
    if not re.fullmatch(r"[0-9a-f]{40}", revision):
        raise ValueError("A complete source commit hash is required")
    check_skin(skin)
    files = payload(folder, platform)
    files.update(player_tool_files(root))
    base_assignments = pack_one.json_bytes(sorted(pack_one.assigned_pairs(root)))
    asset_guide = root / "docs/card-art-and-packs.md"
    files.update({"LICENSE.txt": root / "LICENSE",
                  "setup.txt": root / "docs" / "setup.txt",
                  "skin/SKIN.txt": root / "docs" / "skin-catalogue.txt",
                  "RELEASE_NOTES.md": root / "docs" / "releases" / f"{version}.md",
                  "DECKLAB.md": root / "DeckLab" / "README.md",
                  "AGENTS.md": root / "AGENTS.md",
                  "CARD-ART-AND-PACKS.md": asset_guide,
                  "icon.png": root / "game" / "icon.png"})
    if platform == "web":
        files["setup-web.txt"] = root / "docs" / "setup-web.txt"
    files.update({name: root / source for name, source in HANDHELD_FILES.get(platform, {}).items()})
    if platform == "arkos-rk3326-experimental":
        guard_private([root / ARKOS_LAUNCHER])
    guard_private(list(files.values()))
    name = f"Shandalar-{version}-{platform}"
    outputs = [out / f"{name}{suffix}.zip" for suffix in ("", "-with-skin")]
    if any(p.exists() or p.with_suffix(".part").exists() for p in outputs):
        raise ValueError("Refusing to overwrite an existing package or partial file")
    out.mkdir(parents=True, exist_ok=True)
    for output, included in zip(outputs, (False, True)):
        extra = {BASE_ASSIGNMENTS: base_assignments, "VERSION.txt": (version + "\n").encode()}
        readme = (f"SHANDALAR {version}\nGame source commit: {revision}\n\n{START[platform]}\n\n"
                  "Duels, Deck Builder, Booster Draft and LAN SGManalink are included.\n"
                  "Adventure and public Internet play are not included.\n"
                  "Use matching builds and enabled packs for LAN play. See RELEASE_NOTES.md.\n\n"
                  + ("Original skin included in skin/original_skin.zip. Leave it zipped.\n"
                     if included else "Original skin not included. The fallback appearance is fully playable.\n")
                  + "Card pictures are NOT included. Import your own cardart.zip in Options > Skin.\n"
                  "On desktop it can also go in skin/ beside the game.\n"
                  "For a public web server, never include your personal card pack.\n\n"
                  "Four standard difficulties use fair information. The separate,\n"
                  "opt-in Unfair challenge sees the opposing current hand and is unrated.\n\n"
                  f"Source: https://github.com/b0realis/ShandalarGodot/tree/{revision}\n"
                  "Source licence: GPL-3.0 (LICENSE.txt). The original skin is separate.\n"
                  "Godot Engine is MIT-licensed; copyright and third-party notices:\n"
                  "https://godotengine.org/license/\n")
        extra["README.txt"] = readme.encode()
        if platform == "web" and included:
            extra["README.txt"] += (
                "\nWeb skin setup: keep skin/original_skin.zip beside index.html.\n"
                "The game fetches it into browser storage on the first load.\n"
                "You can also import the ZIP manually through Options > Skin.\n").encode()
        extra["README.txt"] += ("\n\n" + asset_guide.read_text(encoding="utf-8")).encode()
        if platform in LINUX_BINARIES or platform in MAC_PLATFORMS:
            binary = "./" + LINUX_BINARIES[platform] if platform in LINUX_BINARIES else "./Shandalar.app/Contents/MacOS/Shandalar"
            prefix = '#!/bin/sh\nset -eu\ncd -- "$(dirname -- "$0")"\n'
            extra["run.sh"] = (prefix + f'exec "{binary}" "$@"\n').encode()
            extra["deck_lab.sh"] = (prefix + f'exec "{binary}" --headless --no-header -- --deck-lab "$@"\n').encode()
            extra["auto_deck.sh"] = (prefix + f'exec "{binary}" --headless --no-header -- --auto-deck "$@"\n').encode()
            extra["lab_query.sh"] = (prefix + f'exec "{binary}" --headless --no-header -- --lab-query "$@"\n').encode()
            extra["referee.sh"] = (prefix + f'exec "{binary}" --headless --no-header -- --referee "$@"\n').encode()
            extra["shandalar.sh"] = (prefix + DISPATCHER.replace("@VERSION@", version)).encode()
            if platform == "raspberry-pi5-arm64":
                extra["run.sh"] = (prefix +
                    'exec "./Shandalar.arm64" --rendering-method gl_compatibility '
                    '--rendering-driver opengl3_es --max-fps 60 "$@"\n').encode()
        elif platform == "windows64":
            extra["README.txt"] += (
                "\nAgent play (MCP): install Python 3.10 or newer, then point your MCP client at\n"
                "python tools/shandalar_mcp.py (use the full script path from other folders).\n"
                "The server finds Shandalar.console.exe automatically; Bash is not required.\n"
                "Keep VERSION.txt and the whole extracted release together. See AGENTS.md.\n").encode()
            extra["deck_lab.bat"] = ("@echo off\r\ncd /d \"%~dp0\"\r\n"
                                     "Shandalar.console.exe --headless --no-header -- --deck-lab %*\r\n").encode()
            extra["auto_deck.bat"] = ("@echo off\r\ncd /d \"%~dp0\"\r\n"
                                      "Shandalar.console.exe --headless --no-header -- --auto-deck %*\r\n").encode()
            extra["lab_query.bat"] = ("@echo off\r\ncd /d \"%~dp0\"\r\n"
                                      "Shandalar.console.exe --headless --no-header -- --lab-query %*\r\n").encode()
            extra["referee.bat"] = ("@echo off\r\ncd /d \"%~dp0\"\r\n"
                                    "Shandalar.console.exe --headless --no-header -- --referee %*\r\n").encode()
        if platform == "steam-deck":
            # Use the reviewed launcher rather than the generic Linux one.
            extra.pop("run.sh")
        elif platform == "meta-quest":
            extra["push_to_quest.sh"] = QUEST_PUSH.encode()
        elif platform == "arkos-rk3326-experimental":
            extra["run.sh"] = (prefix + 'exec bash ../Shandalar.sh "$@"\n').encode()
        selected = dict(files)
        if included:
            selected["skin/original_skin.zip"] = skin
        if platform == "arkos-rk3326-experimental":
            # PortMaster wants one entry script beside a stable game directory.
            # Keep the outer versioned ZIP folder for safe manual extraction.
            selected = {"shandalar/" + key: value for key, value in selected.items()}
            extra = {"shandalar/" + key: value for key, value in extra.items()}
            selected["Shandalar.sh"] = root / ARKOS_LAUNCHER
        checksums = [f"{digest(path)}  {key}" for key, path in sorted(selected.items())]
        checksums.extend(f"{hashlib.sha256(data).hexdigest()}  {key}" for key, data in sorted(extra.items()))
        extra["SHA256SUMS"] = ("\n".join(checksums) + "\n").encode()
        temporary = output.with_suffix(".part")
        try:
            with zipfile.ZipFile(temporary, "x", compression=zipfile.ZIP_DEFLATED) as archive:
                for key, value in sorted({**selected, **extra}.items()):
                    executable = key.endswith((".sh", ".x86_64", ".arm64")) or "/Contents/MacOS/" in key
                    member(archive, f"{name}/{key}", value, executable)
            with zipfile.ZipFile(temporary) as archive:
                if archive.testzip() is not None:
                    raise ValueError("Package integrity check failed")
            os.rename(temporary, output)
        finally:
            if temporary.exists():
                temporary.unlink()
    return outputs


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, epilog=tool_banner.BANNER_HELP,
                                     formatter_class=argparse.RawDescriptionHelpFormatter)
    tool_banner.add_version_flag(parser, "package_release.py", __file__)
    parser.add_argument("--platform", choices=PLATFORMS, required=True)
    parser.add_argument("--input", type=Path, required=True, help="Verified export folder")
    parser.add_argument("--out", type=Path, required=True, help="New ZIPs are written here")
    parser.add_argument("--skin-zip", type=Path, required=True, help="Original skin only; never a card pack")
    parser.add_argument("--commit", required=True, help="Full source commit hash")
    tool_banner.show(WORDMARK, ("Shandalar · release packages", "standalone + original skin"), __file__)
    args = parser.parse_args()
    try:
        for output in package(args.input, args.out, args.platform, args.skin_zip, args.commit):
            print(f"{digest(output)}  {output.name}")
    except (OSError, ValueError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Package refused: {error}\n")


if __name__ == "__main__":
    main()
