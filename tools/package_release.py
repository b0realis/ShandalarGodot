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
             "raspberry-pi5-arm64", "web")
MAC_PLATFORMS = ("macos", "macos-arm64", "macos-intel")
LINUX_BINARIES = {"linux64": "Shandalar.x86_64", "raspberry-pi5-arm64": "Shandalar.arm64"}
PACK_BUILDERS = ("pack_1_dotp_complete", "pack_2_fallen_empires", "pack_3_ice_age",
                 "pack_4_homelands", "pack_5_alliances", "pack_6_portal")
TOOLS = ("mtg_assets.py", "import_original.py", "fetch_card_art.py",
         "skin_catalogue.py", "tool_banner.py", "fetch_cards.py", "gen_cards.py",
         *(name + ".py" for name in PACK_BUILDERS))
# Explicit metadata allowlist: never recurse into a download/art cache.
PACK_DATA = {
    PACK_BUILDERS[0]: ("README.txt", "manifest.json", "missing_cards.json"),
    PACK_BUILDERS[1]: ("README.txt", "manifest.json", "cards.json", "set.json"),
    **{name: ("README.txt", "manifest.json", "cards.json", "set.json", "reprint_names.json")
       for name in PACK_BUILDERS[2:]},
}
BUILDER_DATA = tuple(f"cards/data/{code}.json" for code in pack_one.SET_ORDER) + tuple(
    f"packaging/card_packs/{pack}/{name}" for pack, names in PACK_DATA.items() for name in names)
BASE_ASSIGNMENTS = "packaging/card_packs/pack_1_dotp_complete/base_assignments.json"
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
    required = {
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


def guard_private(paths: list[Path]) -> None:
    needles = [str(Path.home()).encode()]
    login = Path.home().name
    needles.extend(p.encode() for p in (f"/Users/{login}/", f"/home/{login}/"))
    for path in paths:
        tail = b""
        with path.open("rb") as source:
            for block in iter(lambda: source.read(1024 * 1024), b""):
                data = tail + block
                if any(needle in data for needle in needles):
                    raise ValueError(f"Personal home path in {path.name}")
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


def player_tool_files(root: Path = ROOT) -> dict[str, Path]:
    files = {"tools/" + name: root / "tools" / name for name in TOOLS}
    files.update({name: root / name for name in BUILDER_DATA})
    files["CARD-ART-AND-PACKS.md"] = root / "docs/card-art-and-packs.md"
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
                  "CARD-ART-AND-PACKS.md": asset_guide,
                  "icon.png": root / "game" / "icon.png"})
    if platform == "web":
        files["setup-web.txt"] = root / "docs" / "setup-web.txt"
    guard_private(list(files.values()))
    name = f"Shandalar-{version}-{platform}"
    outputs = [out / f"{name}{suffix}.zip" for suffix in ("", "-with-skin")]
    if any(p.exists() or p.with_suffix(".part").exists() for p in outputs):
        raise ValueError("Refusing to overwrite an existing package or partial file")
    out.mkdir(parents=True, exist_ok=True)
    for output, included in zip(outputs, (False, True)):
        extra = {BASE_ASSIGNMENTS: base_assignments}
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
            if platform == "raspberry-pi5-arm64":
                extra["run.sh"] = (prefix +
                    'exec "./Shandalar.arm64" --rendering-method gl_compatibility '
                    '--rendering-driver opengl3_es --max-fps 60 "$@"\n').encode()
        elif platform == "windows64":
            extra["deck_lab.bat"] = ("@echo off\r\ncd /d \"%~dp0\"\r\n"
                                     "Shandalar.console.exe --headless --no-header -- --deck-lab %*\r\n").encode()
        selected = dict(files)
        if included:
            selected["skin/original_skin.zip"] = skin
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
