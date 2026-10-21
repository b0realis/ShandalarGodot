#!/usr/bin/env python3
"""Add background offline support to an existing single-threaded Web release.

The game's Wasm, pack and JavaScript stay byte-for-byte identical. No
Godot export, skin generation, card-art download or source checkout needed.
Example: python3 tools/package_web_offline.py --input Shandalar-VERSION-web.zip --out downloads
After changing hosted files: python3 tools/package_web_offline.py --refresh EXTRACTED_FOLDER
"""
from __future__ import annotations

import argparse
import hashlib
import json
import re
import stat
import struct
import sys
import tempfile
import zipfile
from pathlib import Path, PurePosixPath

sys.path.insert(0, str(Path(__file__).resolve().parent))
import tool_banner

TEMPLATES = Path(__file__).with_name("web_offline")
REQUIRED = ("index.js", "index.wasm", "index.pck", "index.icon.png",
            "index.apple-touch-icon.png")
OPTIONAL = ("index.png", "index.audio.worklet.js", "index.audio.position.worklet.js")
GENERATED = ("index.html", "offline.js", "offline-sw.js", "manifest.webmanifest")
HTML_ADDON = '\n<!-- SHANDALAR OFFLINE BEGIN -->\n<link rel="manifest" href="manifest.webmanifest">\n<meta name="theme-color" content="#000000">\n<meta name="apple-mobile-web-app-capable" content="yes">\n<script src="offline.js" defer></script>\n<!-- SHANDALAR OFFLINE END -->\n'


def original_html(html: str) -> str:
    return re.sub(r'\n<!-- SHANDALAR OFFLINE BEGIN -->.*?<!-- SHANDALAR OFFLINE END -->\n',
                  '', html, flags=re.DOTALL)


def digest(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


def write_sums(folder: Path) -> None:
    lines = []
    for path in sorted(folder.rglob("*")):
        if path.is_file() and path != folder / "SHA256SUMS":
            lines.append(f"{digest(path.read_bytes())}  {path.relative_to(folder).as_posix()}\n")
    (folder / "SHA256SUMS").write_text("".join(lines), encoding="utf-8")


def prepare(folder: Path) -> dict:
    """Refresh one extracted offline package, including locally supplied art.

    Only known runtime files enter the browser cache. Documentation, decks,
    source scripts and unrelated host files are not fetched or cached.
    """
    version = (folder / "VERSION.txt").read_text(encoding="utf-8").strip()
    if not re.fullmatch(r"\d+\.\d+\.\d+", version):
        raise ValueError("VERSION.txt must contain the game's numeric release version")
    for name in ("index.html", *REQUIRED):
        if not (folder / name).is_file() or (folder / name).is_symlink():
            raise ValueError(f"Missing or unsafe runtime file: {name}")
    if re.search(r'"(?:threads|threadsEnabled)"\s*:\s*true',
                 (folder / "index.html").read_text(encoding="utf-8")):
        raise ValueError("Use the single-threaded Web release")
    if (folder / "index.worker.js").exists():
        raise ValueError("A threaded export cannot become this offline package")
    icon = (folder / "index.icon.png").read_bytes()
    if icon[:8] != b"\x89PNG\r\n\x1a\n" or len(icon) < 24:
        raise ValueError("The Web app icon must be a PNG")
    width, height = struct.unpack(">II", icon[16:24])
    manifest = {
        "id": "./", "name": "Shandalar", "short_name": "Shandalar",
        "description": "Classic Magic duels and deck building, ready to play offline.",
        "start_url": "./", "scope": "./", "display": "standalone",
        "orientation": "landscape", "background_color": "#171b1a",
        "theme_color": "#171b1a",
        "icons": [{"src": "index.icon.png", "sizes": f"{width}x{height}", "type": "image/png"}],
    }
    (folder / "manifest.webmanifest").write_text(json.dumps(manifest, indent=2) + "\n", encoding="utf-8")
    html = original_html((folder / "index.html").read_text(encoding="utf-8"))
    if html.count('</head>') != 1:
        raise ValueError("The Web export must have exactly one closing head tag")
    (folder / "index.html").write_text(html.replace('</head>', HTML_ADDON + '</head>'), encoding="utf-8")
    (folder / "offline.js").write_bytes((TEMPLATES / "background.js").read_bytes())
    (folder / "OFFLINE-SETUP.txt").write_bytes((TEMPLATES / "setup.txt").read_bytes())
    names = {"index.html", "offline.js", "manifest.webmanifest", "OFFLINE-SETUP.txt"}
    names.update(REQUIRED)
    names.update(name for name in OPTIONAL if (folder / name).is_file())
    # The release carries at most the original skin. An owner may refresh a
    # PRIVATE host after adding their own cardart.zip; it is never packaged.
    for name in ("skin/original_skin.zip", "skin/cardart.zip"):
        if (folder / name).is_file():
            names.add(name)
    files = []
    for name in sorted(names):
        path = folder / name
        if path.is_symlink() or not path.resolve().is_relative_to(folder.resolve()):
            raise ValueError(f"Runtime file escapes the folder: {name}")
        data = path.read_bytes()
        files.append({"url": name, "bytes": len(data), "sha256": digest(data)})
    worker = ((TEMPLATES / "sha256.js").read_text(encoding="utf-8") + "\n"
              + (TEMPLATES / "service-worker.js").read_text(encoding="utf-8"))
    config = {"version": version, "files": files, "bytes": sum(f["bytes"] for f in files)}
    config["build"] = digest((json.dumps(config, sort_keys=True) + worker).encode())[:24]
    (folder / "offline-sw.js").write_text(
        worker.replace("/*@@CONFIG@@*/", json.dumps(config, separators=(",", ":"))), encoding="utf-8")
    write_sums(folder)
    return config


def package(source: Path, out: Path) -> Path:
    match = re.fullmatch(r"Shandalar-(\d+\.\d+\.\d+)-web(-with-skin)?\.zip", source.name)
    if not match:
        raise ValueError("Input must be a Shandalar-VERSION-web[-with-skin].zip release")
    version, skin = match.groups()
    old_root = f"Shandalar-{version}-web"
    new_root = f"Shandalar-{version}-web-offline"
    target = out / f"{new_root}{skin or ''}.zip"
    if target.exists():
        raise ValueError(f"Output already exists: {target.name}")
    with tempfile.TemporaryDirectory(prefix="shandalar-offline-") as temp:
        folder = Path(temp) / new_root
        folder.mkdir()
        with zipfile.ZipFile(source) as archive:
            names = set()
            for entry in archive.infolist():
                path = PurePosixPath(entry.filename)
                if (entry.filename in names or path.is_absolute() or ".." in path.parts
                        or "\\" in entry.filename or not path.parts
                        or path.parts[0] != old_root or len(path.parts) < 2
                        or stat.S_ISLNK(entry.external_attr >> 16)):
                    raise ValueError("Unsafe or duplicate release archive member")
                names.add(entry.filename)
                if entry.is_dir():
                    continue
                name = PurePosixPath(*path.parts[1:]).as_posix()
                if name.endswith(".zip") and name != "skin/original_skin.zip":
                    raise ValueError("A release must not contain personal card art or card packs")
                if name == "override.cfg" or name in GENERATED[1:]:
                    raise ValueError("Input is not an unmodified single-threaded Web release")
                dest = folder / name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(archive.read(entry))
            # Refuse a corrupt or locally changed input, including unlisted files.
            expected = {}
            for line in (folder / "SHA256SUMS").read_text(encoding="utf-8").splitlines():
                value, name = line.split("  ", 1)
                if name in expected or not re.fullmatch(r"[0-9a-f]{64}", value):
                    raise ValueError("Invalid input checksums")
                expected[name] = value
            actual = {p.relative_to(folder).as_posix(): digest(p.read_bytes())
                      for p in folder.rglob("*") if p.is_file() and p != folder / "SHA256SUMS"}
            if actual != expected:
                raise ValueError("Input files do not match their SHA256SUMS")
        if (folder / "VERSION.txt").read_text().strip() != version:
            raise ValueError("Archive name and VERSION.txt disagree")
        if (folder / "skin/original_skin.zip").exists() != bool(skin):
            raise ValueError("Archive name and included skin disagree")
        readme = (folder / "README.txt").read_text(encoding="utf-8")
        readme = readme.replace("Duels, Deck Builder, Booster Draft and LAN SGManalink are included.",
                                "Duels, Deck Builder and Booster Draft are included; Web has no LAN play.")
        (folder / "README.txt").write_text(
            "OFFLINE WEB EDITION — read OFFLINE-SETUP.txt first.\n"
            "The original game opens directly; offline caching runs in the background.\n"
            "No extra start screen, update button or gameplay changes.\n"
            "Game and engine files come from the original release package:\n"
            f"{source.name}\nSHA-256: {digest(source.read_bytes())}\n\n" + readme, encoding="utf-8")
        for name in ("package_web_offline.py", "tool_banner.py"):
            (folder / "tools" / name).write_bytes(Path(__file__).with_name(name).read_bytes())
        for path in TEMPLATES.iterdir():
            if path.is_file():
                dest = folder / "tools/web_offline" / path.name
                dest.parent.mkdir(parents=True, exist_ok=True)
                dest.write_bytes(path.read_bytes())
        prepare(folder)
        out.mkdir(parents=True, exist_ok=True)
        try:
            with zipfile.ZipFile(target, "x", compression=zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
                for path in sorted(folder.rglob("*")):
                    if path.is_file():
                        info = zipfile.ZipInfo(f"{new_root}/{path.relative_to(folder).as_posix()}")
                        info.external_attr = 0o100644 << 16
                        info.compress_type = zipfile.ZIP_DEFLATED
                        archive.writestr(info, path.read_bytes())
        except Exception:
            target.unlink(missing_ok=True)
            raise
    return target


def main() -> None:
    parser = argparse.ArgumentParser(description=__doc__, epilog=tool_banner.BANNER_HELP)
    tool_banner.add_version_flag(parser, "package_web_offline.py", __file__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument("--input", type=Path, help="Verified single-threaded release ZIP")
    group.add_argument("--refresh", type=Path, help="Refresh cache metadata after changing a PRIVATE extracted host")
    parser.add_argument("--out", type=Path, help="New ZIP destination (with --input)")
    args = parser.parse_args()
    tool_banner.show(("SHANDALAR OFFLINE",), ("Offline Web packages",), __file__)
    try:
        if args.input:
            if not args.out:
                parser.error("--input requires --out")
            print(package(args.input, args.out))
        else:
            if args.out:
                parser.error("--out is only used with --input")
            print(json.dumps(prepare(args.refresh), indent=2))
    except (ValueError, OSError, zipfile.BadZipFile) as error:
        parser.exit(1, f"Cannot prepare offline Web package: {error}\n")


if __name__ == "__main__":
    main()
