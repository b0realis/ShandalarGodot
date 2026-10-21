"""The two rules about the TRACKED TREE itself, as a test.

Both are written down in CONTRIBUTING.md and neither had anything holding
it: `docs/CODE_MAP.md` says *"Every file in the project and what lives in
it"* (hard rule 6: a new file gets a row), and the Publication section says
*"Keep personal home paths, private email addresses and local tooling
metadata out of tracked files"*. The release tooling already refuses a
staged package that names the builder's home (`package_release.guard_private`,
`build_release.sh`'s `guard_stage`) — that is the last door before an
upload, and this is the same check one step earlier, on everything that is
committed rather than on what is about to be zipped.

Found on 2026-09-17 by the first run: eight source files had no row.

ANYONE'S HOME, AND EVERY FILE (review of 2026-10-21, nettools-5). The home
check was the release guard alone, which knows the home of the machine it
runs on: on CI (the runner's own home) it guarded nothing of the owner's, and a
path written on the second build machine, or anyone else's, went through.
And all three checks read only the files without a NUL byte, so no PNG,
JPG, TTF or WAV was ever opened — a screenshot whose metadata names
`/Users/<login>/Desktop` would have been published. Now any login's home
is looked for in every spelling a file carries it, in every tracked file:
its bytes, the UTF-16 text a binary holds, and a PNG's compressed text
chunks (`views`).
"""
import codecs
import re
import struct
import subprocess
import unittest
import zlib
from pathlib import Path

import package_release

ROOT = Path(__file__).resolve().parents[1]

## The map documents these folders file by file. `cards/sets/`,
## `cards/optional/` and `cards/todo/` are deliberately NOT here: the map
## describes each of them as a folder, one paragraph for 900-odd card
## files, which is the only readable way to write it down.
MAPPED_DIRS = ("engine/", "game/", "tools/", "DeckLab/")
MAPPED_SUFFIXES = (".gd", ".py", ".sh", ".tscn")

## Vendored third party (the GUT addon and the fonts it ships). Its
## licence file carries the font author's own address, which is the point
## of a licence file; this project's Publication rule is about what this
## project writes.
VENDORED = ("addons/",)

## Tool-vendor names this project may never carry (CONTRIBUTING.md keeps
## "local tooling metadata out of tracked files"). Word-bounded and
## case-insensitive. Three words that would look at home in the list are
## deliberately absent, and each cost a false failure on the first run or
## would have: "cursor" is the mouse pointer in three dozen UI files,
## "llm" only ever turns up inside a PNG's compressed bytes, and "Llama"
## is a Magic creature type (engine/core/creature_types.gd).
## The names themselves are stored rot13'd: spelled out, this file would
## be the one tracked file that carries them, and the pre-commit grep
## would flag it. Read as bytes, binary files included (2026-10-21).
_TOOL_NAMES = codecs.decode("pynhqr|naguebcvp|pungtcg|bcra ?nv|pbcvybg|pbqrk|trzvav", "rot13")
FORBIDDEN_TOOLS = re.compile(rb"(?i)\b(" + _TOOL_NAMES.encode() + rb")\b")
## One of them, for the guard's own test.
TOOL_NAME = _TOOL_NAMES.split("|")[0]

## An address, anywhere. The project's own author identity is a GitHub
## noreply, which is the one form that is not private.
EMAIL = re.compile(rb"[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}")
## In a binary file, an address as one is written — two characters or
## more each side of the @, a lowercase top-level domain — since the loose
## form turns up in a picture's compressed bytes (a digit, an @, a
## letter, a dot and two letters in branding/logo.png, 2026-10-21).
BINARY_EMAIL = re.compile(rb"(?<![A-Za-z0-9._%+-])[A-Za-z0-9._%+-]{2,}"
                          rb"@(?:[A-Za-z0-9-]{2,}\.)+[a-z]{2,24}(?![A-Za-z0-9])")
## A picture's scale suffix is a file name, not an address:
## `title_background@2x.png`, the 2x skin's naming (tools/upscale_skin.py).
ALLOWED_EMAIL = re.compile(r"(?i)@users\.noreply\.github\.com$"
                           r"|^[^@]+@[0-9]+x\.(?:png|jpe?g|webp)$")

## A HOME FOLDER, ANYONE'S (2026-10-21): `/home/<login>`, `/Users/<login>`
## and `<drive>:\Users\<login>`, with forward slashes, backslashes, the
## doubled backslashes of a string literal and JSON's escaped `\/`. Only at
## the start of a path: `forge/screens/home/PlayerPanel.java` names a
## folder called home, not anybody's. The login is captured to be checked
## against [ALLOWED_HOMES].
HOME_PATH = re.compile(
    rb"(?<![A-Za-z0-9._-])(?:/|\\/)(?:home|Users)(?:/|\\/)([A-Za-z0-9._-]+)"
    rb"|\b[A-Za-z]:(?:\\\\|\\|/)(?i:users)(?:\\\\|\\|/)([A-Za-z0-9._-]+)")
## The logins a tracked file may name, each a placeholder nobody lives at.
ALLOWED_HOMES = {
    # The release guard's own fixtures: tools/package_release.py's doc,
    # tools/test_package_release.py and the release notes that told of it.
    "ann", "anna", "builder", "builders", "builder_old", "buildery",
    # Examples in the player's guides and fixtures in the GUT tests:
    # pages/index.html's `cd /Users/you/...`, tests/unit/test_skin_pack.gd,
    # tests/unit/test_game_paths.gd's `C:/Users/Deck Tester`.
    "me", "you", "somebody", "zz", "Deck",
    # GitHub Actions' runner (its home is the runner login's): a CI log
    # quoted in a note names a machine, not a person. Never write that home
    # out whole in this file: on CI it IS this machine's home, which the
    # release guard (test_no_tracked_file_names_this_machines_home) refuses everywhere, this file included.
    "runner",
}

## A PNG's text chunks: `tEXt` is plain and read with the file's bytes;
## `zTXt` is always compressed and `iTXt` may be. GIMP keeps the EXIF
## block in a zTXt "Raw profile type exif", as hex digits.
PNG_SIGNATURE = b"\x89PNG\r\n\x1a\n"


def tracked_files() -> list[str]:
    """Every path git would commit after `git add -A`: the index plus the
    untracked files no ignore rule hides. Checking those too means a new
    file is caught BEFORE it is staged, and a CODE_MAP row written in the
    same sitting as its file does not fail until `git add`. [] when this
    is no checkout."""
    try:
        done = subprocess.run(["git", "ls-files", "--cached", "--others",
                               "--exclude-standard"], cwd=str(ROOT),
                              capture_output=True, text=True, timeout=120)
    except (OSError, subprocess.SubprocessError):
        return []
    if done.returncode != 0:
        return []
    return [line for line in done.stdout.split("\n") if line]


def published_files() -> list[str]:
    """Every tracked file this project wrote, binaries included: until
    2026-10-21 a NUL byte in the first block left a file out, and with it
    every picture, font and sound in the tree."""
    return [name for name in tracked_files()
            if (ROOT / name).is_file() and not name.startswith(VENDORED)]


def views(data: bytes) -> list[bytes]:
    """What a reader could find in a file: its bytes; for a binary one
    (a NUL in it) also the text every second byte spells, which is UTF-16
    either way round — a font's name table, a Windows resource; and for a
    PNG the text of its compressed chunks, a raw profile's hex read as the
    bytes it spells."""
    out = [data]
    if b"\0" in data:
        out += [data[0::2], data[1::2]]
    if data.startswith(PNG_SIGNATURE):
        out += png_texts(data)
    return out


def png_texts(data: bytes) -> list[bytes]:
    out = []
    at = len(PNG_SIGNATURE)
    while at + 8 <= len(data):
        length, kind = struct.unpack(">I4s", data[at:at + 8])
        body = data[at + 8:at + 8 + length]
        at += 12 + length
        keyword, _, rest = body.partition(b"\0")
        if kind == b"zTXt":
            text = _inflate(rest[1:])
        elif kind == b"iTXt" and len(rest) >= 2:
            compressed, rest = rest[0], rest[2:]
            text = rest.split(b"\0", 2)[-1]       # past the language and translated keyword
            if compressed:
                text = _inflate(text)
        else:
            continue
        out.append(text)
        if keyword.startswith(b"Raw profile type"):
            digits = b"".join(text.split(b"\n")[3:])
            try:
                out.append(bytes.fromhex(digits.decode("ascii", "ignore")))
            except ValueError:
                pass
    return out


def _inflate(data: bytes) -> bytes:
    try:
        return zlib.decompress(data)
    except zlib.error:
        return b""


def foreign_homes(view: bytes) -> list[str]:
    """The logins of every home path in [view] not in [ALLOWED_HOMES]."""
    out = []
    for found in HOME_PATH.finditer(view):
        login = (found.group(1) or found.group(2)).decode("ascii")
        if login not in ALLOWED_HOMES:
            out.append(login)
    return out


def machine_homes(view: bytes) -> bool:
    """This machine's own home, in any spelling the release guard knows —
    which also covers a home outside /home and /Users (/root, /var/home)."""
    return any(literal in view and pattern.search(view)
               for literal, pattern in package_release.private_patterns())


def private_addresses(view: bytes, binary: bool = False) -> list[str]:
    out = []
    for found in (BINARY_EMAIL if binary else EMAIL).findall(view):
        address = found.decode("ascii")
        if not ALLOWED_EMAIL.search(address):
            out.append(address)
    return out


def assistant_names(view: bytes) -> list[str]:
    return [found.decode("ascii") for found in FORBIDDEN_TOOLS.findall(view)]


class CodeMapTest(unittest.TestCase):
    """EVERY SOURCE FILE HAS A ROW — the map's own opening sentence."""

    @classmethod
    def setUpClass(cls):
        cls.tracked = tracked_files()
        if not cls.tracked:
            raise unittest.SkipTest("not a git checkout")
        cls.map_text = (ROOT / "docs/CODE_MAP.md").read_text(encoding="utf-8")

    def mentioned(self, name: str) -> bool:
        # A row names either the whole path or the file, and the map's
        # shorthand for a screen that is a script plus its scene is
        # `foo.gd/.tscn` — one row for the pair, so the scene's own name
        # never appears on its own.
        base = Path(name).name
        if name in self.map_text or base in self.map_text:
            return True
        stem, suffix = base.rsplit(".", 1)
        return suffix == "tscn" and "%s.gd/.tscn" % stem in self.map_text

    def test_every_source_file_outside_the_card_folders_has_a_row(self):
        missing = [name for name in self.tracked
                   if name.startswith(MAPPED_DIRS)
                   and name.endswith(MAPPED_SUFFIXES)
                   and not self.mentioned(name)]
        self.assertEqual(missing, [], "add a docs/CODE_MAP.md row for these")

    def test_the_root_shell_entry_points_have_a_row(self):
        missing = [name for name in self.tracked
                   if "/" not in name and name.endswith(".sh")
                   and not self.mentioned(name)]
        self.assertEqual(missing, [])

    def test_no_row_points_at_a_file_that_is_gone(self):
        # Only the rows that spell a whole path; a bare file name in a
        # sentence ("...and `test_ai_unfair.gd` pin the refinements") is
        # prose about a row above it, not a row of its own. A row that
        # covers a folder with a glob (`cards/sets/ice/*.gd`) names no
        # single file, and `foo.gd/.tscn` is the shorthand for a screen's
        # script and its scene together.
        tracked = set(self.tracked)
        stale = []
        for quoted in re.findall(r"`([^`\n]+)`", self.map_text):
            named = quoted[:-len("/.tscn")] if quoted.endswith(".gd/.tscn") \
                else quoted
            if "/" not in named or not named.endswith(MAPPED_SUFFIXES):
                continue
            if "*" in named or named.startswith(("res://", "../", "user://")):
                continue
            if named not in tracked:
                stale.append(quoted)
        self.assertEqual(sorted(set(stale)), [])


class PublicationTest(unittest.TestCase):
    """NOTHING OF THIS MACHINE, AND NOBODY'S NAME, IN A TRACKED FILE."""

    @classmethod
    def setUpClass(cls):
        names = published_files()
        if not names:
            raise unittest.SkipTest("not a git checkout")
        cls.files = {name: views((ROOT / name).read_bytes()) for name in names}
        cls.binary = {name for name, seen in cls.files.items() if b"\0" in seen[0]}

    def test_no_tracked_file_names_this_machines_home(self):
        # The release guard itself, pointed at the tree instead of at a
        # staged package, so the two can never answer differently — and
        # its patterns over what a picture's compressed chunks say.
        offenders = []
        for name, seen in self.files.items():
            try:
                package_release.guard_private([ROOT / name])
            except ValueError:
                offenders.append(name)
                continue
            if any(machine_homes(view) for view in seen[1:]):
                offenders.append(name)
        self.assertEqual(offenders, [])

    def test_no_tracked_file_names_anyones_home(self):
        offenders = set()
        for name, seen in self.files.items():
            for view in seen:
                offenders.update("%s: %s" % (name, login) for login in foreign_homes(view))
        self.assertEqual(sorted(offenders), [],
                         "a placeholder that belongs in the tree goes in ALLOWED_HOMES")

    def test_no_tracked_file_carries_a_private_address(self):
        offenders = set()
        for name, seen in self.files.items():
            for view in seen:
                offenders.update("%s: %s" % (name, found)
                                 for found in private_addresses(view, name in self.binary))
        self.assertEqual(sorted(offenders), [])

    def test_no_tracked_file_names_an_assistant(self):
        offenders = set()
        for name, seen in self.files.items():
            for view in seen:
                offenders.update("%s: %s" % (name, found) for found in assistant_names(view))
        self.assertEqual(sorted(offenders), [])


class AnyonesHomeTest(unittest.TestCase):
    """THE GUARD ITSELF (review of 2026-10-21, nettools-5): it knew only the
    home of the machine it ran on, and never opened a binary file. The
    fixtures say `{who}` where a login goes and are filled in at run time,
    so this file never carries the paths and the address it plants."""

    WHO = b"zoe"

    def plant(self, data: bytes) -> bytes:
        return data.replace(b"{who}", self.WHO)

    def found(self, data: bytes) -> list[str]:
        out = []
        for view in views(self.plant(data)):
            out += foreign_homes(view)
        return out

    def test_a_home_of_any_login_is_found_in_every_spelling(self):
        for text in (b"/home/{who}/skins", b"/Users/{who}/Desktop/shot.png",
                     b'"C:\\Users\\{who}\\Music"', b'"C:\\\\Users\\\\{who}\\\\Music"',
                     b'{"path": "\\/home\\/{who}\\/x"}', b"d:/users/{who}/", b"file:///home/{who}"):
            with self.subTest(text=text):
                self.assertEqual(self.found(text), ["zoe"])

    def test_placeholders_and_other_folders_named_home_pass(self):
        for text in (b"/home/me/Downloads/my_skin.zip", b"cd /Users/you/Documents",
                     b"C:/Users/Deck Tester/Music", b"/home/" + b"runner/work",
                     b"forge/screens/home/PlayerPanel.java", b"/home/{login}",
                     b"Home/End keys", b"/home/ and /Users/ are home folders"):
            with self.subTest(text=text):
                self.assertEqual(self.found(text), [])

    def test_a_binary_file_is_read_in_utf16_too(self):
        # A font's name table, a Windows resource: two bytes a letter.
        for codec in ("utf-16-le", "utf-16-be"):
            with self.subTest(codec=codec):
                path = self.plant(b"C:\\Users\\{who}\\font").decode()
                blob = b"\x00\x01\x00\x00" + path.encode(codec) + b"\x00" * 9
                self.assertEqual(self.found(blob), ["zoe"])

    def test_a_pictures_text_chunks_are_read_compressed_or_not(self):
        def chunk(kind: bytes, body: bytes) -> bytes:
            return (struct.pack(">I", len(body)) + kind + body
                    + struct.pack(">I", zlib.crc32(kind + body)))
        made_in = self.plant(b"made in /Users/{who}/Pictures")
        exif = b"\nexif\n      %d\n%s\n" % (len(made_in), made_in.hex().encode())
        png = (b"\x89PNG\r\n\x1a\n"
               + chunk(b"tEXt", self.plant(b"Comment\x00/home/{who}/a.png"))
               + chunk(b"zTXt", b"Comment\x00\x00" + zlib.compress(self.plant(b"by {who}@example.org")))
               + chunk(b"iTXt", b"XML:com.adobe.xmp\x00\x01\x00\x00\x00"
                       + zlib.compress(TOOL_NAME.encode()))
               + chunk(b"zTXt", b"Raw profile type exif\x00\x00" + zlib.compress(exif))
               + chunk(b"IEND", b""))
        homes, addresses, tools = [], [], []
        for view in views(png):
            homes += foreign_homes(view)
            addresses += private_addresses(view, binary=True)
            tools += assistant_names(view)
        self.assertEqual(sorted(homes), ["zoe", "zoe"],
                         "the plain chunk, and the hex of a raw profile read as its bytes")
        self.assertEqual(addresses, [self.plant(b"{who}").decode() + "@example.org"])
        self.assertEqual([name.lower() for name in tools], [TOOL_NAME.lower()])

    def test_the_tree_scan_reads_the_binary_files(self):
        if not tracked_files():
            self.skipTest("not a git checkout")
        files = published_files()
        self.assertIn("game/icon.png", files)
        self.assertTrue(any(name.endswith(".ttf") for name in files))


if __name__ == "__main__":
    unittest.main()
