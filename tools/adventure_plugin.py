#!/usr/bin/env python3
"""adventure_plugin.py — make, check and package Shandalar adventure plugins.

An adventure plugin is DATA ONLY: JSON, text, PNG/JPEG/WebP pictures and
Ogg Vorbis music, as a folder or a .zip with one top folder. The game reads
it from its `expanded_adventure/` folder and never runs anything in it.

    adventure_plugin.py new FOLDER --id ID --name NAME [--author NAME]
        a minimal plugin that loads and plays: one quest, two foes, a port
        and a castle with small placeholder map pictures.
    adventure_plugin.py validate PLUGIN [--json]
        the game's own checks, in the game's order: the package, the
        manifest, its files list, the content (card names included).
    adventure_plugin.py export FOLDER [--out DIR]
        validate, then write DIR/FOLDER.zip (DIR: dist/ in the current
        folder unless named; never the folder that holds FOLDER, where the
        zip would hide the folder from the game) — deterministic: sorted
        entries, fixed times, one top folder, deflated — with the SHA-256 of
        every file in the zip's plugin.json; the zip is validated again.
    adventure_plugin.py info PLUGIN [--json]
        the manifest and what the plugin holds.
    adventure_plugin.py compat OLD NEW
        every change in NEW that makes saves made with OLD unusable.
    adventure_plugin.py guide [--out DIR] [--check]
        write the guide's reference page (GUIDE/reference.html) from
        game/adventure/plugins/schema_v1.json.

Run it from a game checkout or a release folder (python3
tools/adventure_plugin.py ...), or name one with --game DIR: the schema and
the game's card lists are read from there. Without card lists the card
names are not checked, and the tool says so.

Exit codes: 0 done (the plugin is valid; compatible); 1 refused (problems
listed one per line; incompatible); 2 a usage error (an unknown option, a
missing file, no schema found).
"""
from __future__ import annotations

import argparse
import hashlib
import html
import io
import json
import os
import re
import struct
import sys
import tempfile
import zipfile
import zlib
from pathlib import Path

TOOL = "adventure_plugin.py"
HERE = Path(__file__).resolve().parent

# --------------------------------------------------------------------------
# THE GAME'S RULES, twinned. Every constant below is the game's own, read
# from its GDScript by tools/test_adventure_plugin.py (DriftTest), which
# fails the moment one of them drifts: game/adventure/plugins/
# adventure_plugins.gd (the registry and the manifest), plugin_package.gd
# (the package), plugin_schema.gd and plugin_text.gd (the content),
# game/adventure/world/world_terrain_palette.gd (palettes),
# game/adventure/adventure_setup.gd (Pack 1), game/adventure/creature_book.gd
# (the faces). The content's shapes are not twinned: they are read from
# schema_v1.json, the one file the game and this tool share.
# --------------------------------------------------------------------------

API_VERSION = 1
PLUGIN_FORMAT = 1
FOLDER_NAME = "expanded_adventure"
ID_PATTERN = "^[a-z][a-z0-9_]{0,39}$"
RESERVED_IDS = ["mainland"]
REQUIRED_FIELDS = ["plugin_format", "api_version", "id", "name", "version", "authors", "description", "region"]
FIELDS = ["plugin_format", "api_version", "id", "name", "version", "minimum_game_version", "authors", "license",
          "description", "learning_note", "requires", "region", "files"]
REGION_FIELDS = ["title", "castle_name", "salt", "mana_links", "palette"]
MAX_NAME = 100
MAX_LINE = 300
MAX_TEXT = 4000
MAX_AUTHORS = 16
MAX_PACKS = 16

ALLOWED = ["json", "txt", "md", "png", "jpg", "jpeg", "webp", "ogg"]
PICTURES = ["png", "jpg", "jpeg", "webp"]
TEXTS = ["json", "txt", "md"]
MAX_TOTAL = 32 * 1024 * 1024
MAX_FILES = 512
MAX_JSON = 1024 * 1024
MAX_OGG = 16 * 1024 * 1024
MAX_SIDE = 4096
MAX_PATH = 200
MAX_DEPTH = 32
MAX_FOLDERS = 256
MANIFEST = "plugin.json"
LITTER = ["thumbs.db", "desktop.ini"]
LITTER_FOLDER = "__macosx"

RESERVED_FLAGS = ["region", "layout_version", "port", "castle", "town_names", "dungeon_names", "objectives",
                  "banners", "freed_communities", "entries", "adventures", "appearance", "quests", "pending",
                  "stages", "reward_choices", "expansion", "plugin"]
MARKERS = ["port", "castle"]

PLACEHOLDERS = ["pledges", "quests_total", "target", "town", "title", "foe", "life", "count", "total", "required",
                "percent", "left", "color", "cards", "hero", "region"]
## The engine's own sentences, said when a plugin's text.json leaves them out.
TEXT_DEFAULTS = {
    "region.subtitle": "",
    "voyage.out": "",
    "voyage.home": "",
    "port.sail_out": "Sail to the island",
    "port.sail_home": "Sail home",
    "port.leave": "Leave",
    "castle.leave": "Leave",
    "guide.petition": "{title}: hear the petition at {target}.",
    "guide.duel": "{title}: return to {target} and defeat {foe}.",
    "guide.done": "{title}: done.",
    "quest.reward_line": "",
    "quest.retry_line": "No ante is staked. A loss or draw lets you retry. Enemy life: {life}.",
    "quest.secure": "This quest is done.",
    "quest.accept": "Accept",
    "quest.fight": "Duel: {foe}",
    "quest.back": "Return",
    "quest.done_log": "{title} completed.",
    "rewards.choose": "Choose reward cards ({count})",
    "rewards.claim": "Collect waiting cards ({count})",
    "rewards.title": "Rewards",
    "rewards.intro": "Choose one bundle for each reward owed. Cards that do not fit your bag are kept safely.",
    "rewards.offer": "{color}: {cards}",
    "rewards.rules": "Copy limits and bans apply.",
    "rewards.later": "Choose later",
    "rewards.pending_line": "{count} reward cards are waiting; make room in your bag to collect them.",
    "rewards.collected": "Collected {count} cards. {left} remain safely held for you.",
    "deck.no_pack": "Enable this adventure's card packs in Options to begin this battle.",
    "deck.empty": "Choose a deck in a town's deck builder before beginning this battle.",
    "deck.unknown": "Your deck contains unavailable cards. Enable their packs or edit the deck in town.",
    "duel.leave_question": "Return to the main menu? This unfinished battle is not saved. Your adventure resumes before the challenge.",
    "duel.over": "The battle is over. You may prepare and try again; no cards were staked.",
    "duel.won_reward": "",
    "duel.won_again": "",
    "duel.won_log": "Defeated {foe}.",
    "duel.lost_log": "Lost to {foe}.",
    "duel.title": "{region}",
    "duel.victory": "Victory",
    "duel.ended": "The battle ends",
    "duel.continue": "Continue",
    "target.none": "the island",
    "task.petition": "Hear the petition at {town}.",
    "task.duel": "Defeat {foe} at {target}.",
    "task.done": "Done at {town}.",
    "talk.will_you": "Will you...",
}

PALETTES = ["shandalar", "last_refuge"]
PALETTE_LAYERS = ["ground", "objects", "roads"]
PALETTE_PREFIX = "plugin:"
IGNORED_PACKS = ["pack-1"]
## CreatureBook.ROWS.size(); row 0 is the lair, never a face.
CREATURE_ROWS = 57
LAIR = 0

## The base game's card folders, in the registry's order (CardRegistry.SET_ORDER).
SET_ORDER = ["2ed", "arn", "atq", "leg", "drk", "4ed", "past", "phpr"]
SCHEMA_REL = "game/adventure/plugins/schema_v1.json"
## The card lists a release carries beside this tool (package_release.py writes it).
CARDS_FILE = "adventure_plugin_cards.json"
## The guide's page order (its toc), for the reference page's fallback toc and pager.
GUIDE_PAGES = [("index.html", "Start here"), ("first-plugin.html", "Your first plugin"),
               ("world.html", "The world"), ("quests.html", "Quests and steps"),
               ("foes-rewards.html", "Foes and rewards"), ("text.html", "Text and placeholders"),
               ("art-music.html", "Art and music"), ("saves.html", "Saves and compatibility"),
               ("testing.html", "Testing"), ("refuge.html", "The Refuge walkthrough"),
               ("reference.html", "Reference"), ("faq.html", "FAQ")]


class UsageError(Exception):
    """Exit 2: the command line, not the plugin, is wrong."""


# --------------------------------------------------------------------------
# GODOT'S OWN WAYS WITH STRINGS, where the game's messages depend on them.
# --------------------------------------------------------------------------

def get_extension(path: str) -> str:
    """String.get_extension(): after the last '.', unless a '/' or '\\' follows it."""
    pos = path.rfind(".")
    if pos < 0 or pos < max(path.rfind("/"), path.rfind("\\")):
        return ""
    return path[pos + 1:]


def get_file(path: str) -> str:
    """String.get_file(): after the last '/' or '\\'."""
    sep = max(path.rfind("/"), path.rfind("\\"))
    return path[sep + 1:] if sep >= 0 else path


def strip_edges(text: str) -> str:
    """String.strip_edges(): characters up to U+0020 off both ends."""
    start, end = 0, len(text)
    while start < end and ord(text[start]) <= 32:
        start += 1
    while end > start and ord(text[end - 1]) <= 32:
        end -= 1
    return text[start:end]


def c_escape(text: str) -> str:
    """String.c_escape()."""
    for old, new in (("\\", "\\\\"), ("\a", "\\a"), ("\b", "\\b"), ("\f", "\\f"), ("\n", "\\n"), ("\r", "\\r"),
                     ("\t", "\\t"), ("\v", "\\v"), ("'", "\\'"), ("?", "\\?"), ('"', '\\"')):
        text = text.replace(old, new)
    return text


def is_valid_hex_number(text: str) -> bool:
    """String.is_valid_hex_number(): hex digits, a sign allowed in front."""
    if not text:
        return False
    start = 1 if len(text) != 1 and text[0] in "+-" else 0
    return all(c in "0123456789abcdefABCDEF" for c in text[start:])


def is_valid_int(text: str) -> bool:
    """String.is_valid_int(): ASCII digits, a sign allowed in front."""
    if not text:
        return False
    start = 1 if len(text) != 1 and text[0] in "+-" else 0
    return all(c in "0123456789" for c in text[start:])


def utf8_string(raw: bytes) -> str:
    """PackedByteArray.get_string_from_utf8(): a byte-order mark skipped,
    the text ending at the first NUL (the bytes are UTF-8 already)."""
    if raw[:3] == b"\xef\xbb\xbf":
        raw = raw[3:]
    cut = raw.find(b"\x00")
    if cut >= 0:
        raw = raw[:cut]
    return raw.decode("utf-8", errors="replace")


def is_number(value) -> bool:
    """A JSON number as GDScript sees one (never true/false)."""
    return isinstance(value, (int, float)) and not isinstance(value, bool)


def whole(value) -> bool:
    """AdventurePlugins._whole: a whole number as JSON reads one."""
    if isinstance(value, bool):
        return False
    if isinstance(value, int):
        return True
    return isinstance(value, float) and value == value and abs(value) != float("inf") \
        and value == round(value) and abs(value) < 9.0e15


def fmt_num(value) -> str:
    """PluginSchema._num."""
    if value is None:
        return "?"
    number = float(value)
    return str(int(number)) if number == int(number) else str(value)


class _JsonError(Exception):
    def __init__(self, message: str, line: int):
        super().__init__(message)
        self.message, self.line = message, line


class GodotJson:
    """JSON as the game's [JSON] parser reads it (core/io/json.cpp), not as
    Python's does: every number a float; a comma before a closing bracket
    allowed; any character up to U+0020 taken as space; a number read as
    the engine reads one (leading zeros, a bare trailing point); raw control
    characters allowed inside strings; its own words for a problem, and its
    line counted as the engine counts it, from 0 (a problem sentence adds
    1, as the game's do). A plugin the game reads, the tool reads; one it
    refuses, the tool refuses, saying the same."""

    MAX_DEPTH = 1024

    def __init__(self, text: str, ints: bool = False):
        # The engine counts lines from 0 (JSON.get_error_line()). [ints]:
        # a number with no point or exponent read as a whole number — for
        # export, which writes the manifest back as the author wrote it.
        self.text, self.at, self.line, self.ints = text, 0, 0, ints

    def fail(self, message: str):
        raise _JsonError(message, self.line)

    def token(self):
        text, size = self.text, len(self.text)
        while self.at < size:
            c = text[self.at]
            if c == "\n":
                self.line += 1
                self.at += 1
            elif c in "{}[]:,":
                self.at += 1
                return c, None
            elif c == '"':
                return "string", self.string()
            elif ord(c) <= 32:
                self.at += 1
            elif c == "-" or "0" <= c <= "9":
                return "number", self.number()
            elif "a" <= c <= "z" or "A" <= c <= "Z":
                start = self.at
                while self.at < size and ("a" <= text[self.at] <= "z" or "A" <= text[self.at] <= "Z"):
                    self.at += 1
                return "identifier", text[start:self.at]
            else:
                self.fail("Unexpected character.")
        return "eof", None

    def string(self) -> str:
        text, size = self.text, len(self.text)
        self.at += 1
        out = []
        escapes = {"b": "\b", "f": "\f", "n": "\n", "r": "\r", "t": "\t", '"': '"', "\\": "\\", "/": "/"}
        while True:
            if self.at >= size:
                self.fail("Unterminated string")
            c = text[self.at]
            if c == '"':
                self.at += 1
                return "".join(out)
            if c == "\\":
                self.at += 1
                following = text[self.at] if self.at < size else ""
                if following == "u":
                    code = self.hex4()
                    if 0xD800 <= code <= 0xDBFF:
                        if text[self.at + 1:self.at + 3] != "\\u":
                            self.fail("Invalid UTF-16 sequence in string, unpaired lead surrogate")
                        self.at += 2
                        trail = self.hex4()
                        if not 0xDC00 <= trail <= 0xDFFF:
                            self.fail("Invalid UTF-16 sequence in string, unpaired lead surrogate")
                        code = 0x10000 + ((code - 0xD800) << 10) + (trail - 0xDC00)
                    elif 0xDC00 <= code <= 0xDFFF:
                        self.fail("Invalid UTF-16 sequence in string, unpaired trail surrogate")
                    out.append(chr(code))
                elif following in escapes:
                    out.append(escapes[following])
                else:
                    self.fail("Invalid escape sequence.")
            else:
                if c == "\n":
                    self.line += 1
                out.append(c)
            self.at += 1

    def hex4(self) -> int:
        digits = self.text[self.at + 1:self.at + 5]
        if len(digits) != 4 or any(d not in "0123456789abcdefABCDEF" for d in digits):
            self.fail("Malformed hex constant in string")
        self.at += 4
        return int(digits, 16)

    def number(self) -> float:
        text, size, start = self.text, len(self.text), self.at
        if text[self.at] == "-":
            self.at += 1
        point = False
        digits = 0
        while self.at < size and ("0" <= text[self.at] <= "9" or (text[self.at] == "." and not point)):
            point = point or text[self.at] == "."
            digits += text[self.at] != "."
            self.at += 1
        if digits == 0:
            self.at = start + 1
            return 0.0
        mantissa = text[start:self.at]
        exponent = re.match(r"[eE][+-]?[0-9]+", text[self.at:self.at + 400])
        if exponent:
            self.at += exponent.end()
        if self.ints and not exponent and "." not in mantissa:
            return int(mantissa)
        try:
            return float(mantissa + (exponent.group(0) if exponent else ""))
        except (ValueError, OverflowError):
            return float("inf")

    def value(self, kind, word, depth: int):
        if depth > self.MAX_DEPTH:
            self.fail("JSON structure is too deep. Bailing.")
        if kind == "{":
            return self.object(depth)
        if kind == "[":
            return self.array(depth)
        if kind == "identifier":
            if word in ("true", "false", "null"):
                return {"true": True, "false": False, "null": None}[word]
            self.fail("Expected 'true', 'false' or 'null', got '%s'." % word)
        if kind in ("number", "string"):
            return word
        self.fail("Expected value, got '%s'." % ("EOF" if kind == "eof" else kind))

    def array(self, depth: int) -> list:
        out, comma = [], False
        while True:
            kind, word = self.token()
            if kind == "eof":
                self.fail("Expected ']'")
            if kind == "]":
                return out
            if comma:
                if kind != ",":
                    self.fail("Expected ','")
                comma = False
                continue
            out.append(self.value(kind, word, depth + 1))
            comma = True

    def object(self, depth: int) -> dict:
        out, comma = {}, False
        while True:
            kind, word = self.token()
            if kind == "eof":
                self.fail("Expected '}'")
            if kind == "}":
                return out
            if comma:
                if kind != ",":
                    self.fail("Expected '}' or ','")
                comma = False
                continue
            if kind != "string":
                self.fail("Expected key")
            key = word
            if self.token()[0] != ":":
                self.fail("Expected ':'")
            kind, word = self.token()
            out[key] = self.value(kind, word, depth + 1)
            comma = True

    def parse(self):
        kind, word = self.token()
        result = self.value(kind, word, 0)
        if self.at < len(self.text) and self.token()[0] != "eof":
            self.fail("Expected 'EOF'")
        return result


def parse_json(text: str, ints: bool = False):
    """JSON as the game parses it ([GodotJson]). Returns (value,
    problem_line, problem_message); the message is None when it parsed."""
    limit = sys.getrecursionlimit()
    sys.setrecursionlimit(max(limit, 4 * GodotJson.MAX_DEPTH + 200))
    try:
        return GodotJson(text, ints).parse(), 0, None
    except _JsonError as error:
        return None, error.line, error.message
    except RecursionError:
        return None, 0, "JSON structure is too deep. Bailing."
    finally:
        sys.setrecursionlimit(limit)


def depth(value, limit: int = MAX_DEPTH + 1) -> int:
    """PluginPackage.depth: a plain value 0, [] or {} 1."""
    if limit <= 0:
        return 0
    if isinstance(value, list):
        return 1 + max((depth(item, limit - 1) for item in value), default=0)
    if isinstance(value, dict):
        return 1 + max((depth(item, limit - 1) for item in value.values()), default=0)
    return 0


def sha256(data: bytes) -> str:
    return hashlib.sha256(data).hexdigest()


# --------------------------------------------------------------------------
# STAGE 1 — THE PACKAGE (PluginPackage, game/adventure/plugins/plugin_package.gd)
# --------------------------------------------------------------------------

def ignored(name: str) -> bool:
    lower = name.lower()
    return (name.startswith(".") and name not in (".", "..")) or lower == LITTER_FOLDER or lower in LITTER


def path_problem(rel: str) -> str:
    if len(rel) > MAX_PATH:
        return "%s: the path is longer than %d characters." % (rel[:60] + "...", MAX_PATH)
    if rel.startswith("/") or "\\" in rel or ":" in rel:
        return "%s: the path must be relative and use / only (no \\ or :)." % rel
    for character in rel:
        if ord(character) < 32 or ord(character) == 127:
            return "%s: the path holds a control character." % c_escape(rel)
    for part in rel.split("/"):
        if part in ("", ".", ".."):
            return "%s: the path has an empty, . or .. part." % rel
    return ""


def kind_problem(rel: str) -> str:
    if get_extension(rel).lower() in ALLOWED:
        return ""
    return "%s: this kind of file is not allowed in a plugin (only %s)." % (rel, " ".join("." + e for e in ALLOWED))


def _bytes_text(size: int) -> str:
    if size >= 1024 * 1024:
        return "%.1f MiB" % (size / 1048576.0)
    return "%d bytes" % size


def size_problem(rel: str, size: int) -> str:
    extension = get_extension(rel).lower()
    if extension in TEXTS and size > MAX_JSON:
        return "%s: %s is bigger than the 1 MiB a text or JSON file may be." % (rel, _bytes_text(size))
    if extension == "ogg" and size > MAX_OGG:
        return "%s: %s is bigger than the 16 MiB a music file may be." % (rel, _bytes_text(size))
    return ""


def picture_kind(data: bytes) -> str:
    if len(data) >= 8 and data[:8] == b"\x89PNG\r\n\x1a\n":
        return "png"
    if len(data) >= 3 and data[0] == 0xFF and data[1] == 0xD8 and data[2] == 0xFF:
        return "jpg"
    if len(data) >= 12 and data[:4] == b"RIFF" and data[8:12] == b"WEBP":
        return "webp"
    return ""


def _be16(data: bytes, at: int) -> int:
    return (data[at] << 8) | data[at + 1]


def _be32(data: bytes, at: int) -> int:
    return (data[at] << 24) | (data[at + 1] << 16) | (data[at + 2] << 8) | data[at + 3]


def _jpeg_size(data: bytes) -> tuple[int, int]:
    at = 2
    while at + 3 < len(data):
        if data[at] != 0xFF:
            return 0, 0
        marker = data[at + 1]
        if marker == 0xFF:
            at += 1
            continue
        if marker == 0xD8 or marker == 0x01 or 0xD0 <= marker <= 0xD7:
            at += 2
            continue
        if marker in (0xD9, 0xDA):
            return 0, 0
        length = _be16(data, at + 2)
        if length < 2:
            return 0, 0
        if 0xC0 <= marker <= 0xCF and marker not in (0xC4, 0xC8, 0xCC):
            if at + 9 > len(data):
                return 0, 0
            return _be16(data, at + 7), _be16(data, at + 5)
        at += 2 + length
    return 0, 0


def _webp_size(data: bytes) -> tuple[int, int]:
    if len(data) < 30:
        return 0, 0
    chunk = data[12:16]
    if chunk == b"VP8 ":
        if data[23] != 0x9D or data[24] != 0x01 or data[25] != 0x2A:
            return 0, 0
        return struct.unpack_from("<H", data, 26)[0] & 0x3FFF, struct.unpack_from("<H", data, 28)[0] & 0x3FFF
    if chunk == b"VP8L":
        if data[20] != 0x2F:
            return 0, 0
        bits = struct.unpack_from("<I", data, 21)[0]
        return (bits & 0x3FFF) + 1, ((bits >> 14) & 0x3FFF) + 1
    if chunk == b"VP8X":
        return (data[24] | (data[25] << 8) | (data[26] << 16)) + 1, (data[27] | (data[28] << 8) | (data[29] << 16)) + 1
    return 0, 0


def picture_size(data: bytes) -> tuple[int, int]:
    kind = picture_kind(data)
    if kind == "png":
        if len(data) < 24 or data[12:16] != b"IHDR":
            return 0, 0
        return _be32(data, 16), _be32(data, 20)
    if kind == "jpg":
        return _jpeg_size(data)
    if kind == "webp":
        return _webp_size(data)
    return 0, 0


def is_vorbis(data: bytes) -> bool:
    if len(data) < 28 or data[:4] != b"OggS":
        return False
    at = 27 + data[26]
    return at + 7 <= len(data) and data[at] == 0x01 and data[at + 1:at + 7] == b"vorbis"


def is_utf8(data: bytes) -> bool:
    """PluginPackage.is_utf8: no overlong form, no surrogate, nothing past U+10FFFF."""
    if not data or max(data) < 0x80:
        return True
    at, size = 0, len(data)
    while at < size:
        lead = data[at]
        if lead < 0x80:
            at += 1
            continue
        if 0xC2 <= lead <= 0xDF:
            more, least = 1, 0x80
        elif 0xE0 <= lead <= 0xEF:
            more, least = 2, 0x800
        elif 0xF0 <= lead <= 0xF4:
            more, least = 3, 0x10000
        else:
            return False
        if at + more >= size:
            return False
        code = lead & (0x3F >> more)
        for n in range(more):
            following = data[at + 1 + n]
            if following & 0xC0 != 0x80:
                return False
            code = (code << 6) | (following & 0x3F)
        if code < least or code > 0x10FFFF or 0xD800 <= code <= 0xDFFF:
            return False
        at += 1 + more
    return True


def content_problem(rel: str, data: bytes) -> str:
    extension = get_extension(rel).lower()
    if extension in PICTURES:
        width, height = picture_size(data)
        wanted = "jpg" if extension == "jpeg" else extension
        if width <= 0 or picture_kind(data) != wanted:
            return "%s: not a %s picture (its first bytes say otherwise)." % (rel, extension.upper())
        if width > MAX_SIDE or height > MAX_SIDE:
            return "%s: the picture is %d x %d pixels; %d is the most a side may be." % (rel, width, height, MAX_SIDE)
        return ""
    if extension == "ogg":
        return "" if is_vorbis(data) else "%s: not Ogg Vorbis music." % rel
    if extension in TEXTS and not is_utf8(data):
        return "%s: the text is not UTF-8." % rel
    return ""


def json_file(rel: str, data: bytes) -> dict:
    """PluginPackage.json: {value, problem}."""
    if len(data) > MAX_JSON:
        return {"value": None, "problem": size_problem(rel, len(data))}
    if not is_utf8(data):
        return {"value": None, "problem": "%s: the text is not UTF-8." % rel}
    text = utf8_string(data)
    if text.startswith("\ufeff"):
        text = text[1:]
    value, line, message = parse_json(text)
    if message is not None:
        # "FILE: line N: MESSAGE", the content files' shape, a line as
        # authors count them, from 1 (the lead's ruling on RV2).
        return {"value": None, "problem": "%s: line %d: %s" % (rel, line + 1, message)}
    if depth(value) > MAX_DEPTH:
        return {"value": None, "problem": "%s: nested deeper than %d levels." % (rel, MAX_DEPTH)}
    return {"value": value, "problem": ""}


def _empty(kind: str) -> dict:
    return {"files": {}, "problems": [], "kind": kind, "top": ""}


def read_package(path: str) -> dict:
    """PluginPackage.read: {files: {rel: bytes}, problems, kind, top}."""
    if os.path.isdir(path):
        return _read_folder(path)
    if get_extension(path).lower() == "zip" and os.path.isfile(path):
        return _read_zip(path)
    out = _empty("folder")
    out["problems"].append("%s: not a .zip file or a folder." % get_file(path))
    return out


def _join(under: str, name: str) -> str:
    return under + "/" + name if under else name


def _take(out: dict, rel: str, data: bytes) -> None:
    problem = content_problem(rel, data)
    if problem:
        out["problems"].append(problem)
        return
    out["files"][rel] = data


def _read_folder(path: str) -> dict:
    out = _empty("folder")
    problems = out["problems"]
    found: list[str] = []
    folders = 0
    pending = [""]
    while pending:
        under = pending.pop(0)
        folders += 1
        if folders > MAX_FOLDERS:
            problems.append("The plugin holds more than %d folders." % MAX_FOLDERS)
            break
        try:
            with os.scandir(os.path.join(path, under) if under else path) as listing:
                entries = list(listing)
        except OSError:
            problems.append("%s: the folder could not be read." % (under if under else get_file(path)))
            continue

        def is_dir(entry) -> bool:
            try:
                return entry.is_dir()
            except OSError:
                return False

        for name in sorted(e.name for e in entries if is_dir(e)):
            if ignored(name):
                continue
            rel = _join(under, name)
            if os.path.islink(os.path.join(path, rel)):
                problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % rel)
                continue
            pending.append(rel)
        for name in sorted(e.name for e in entries if not is_dir(e)):
            if ignored(name):
                continue
            rel = _join(under, name)
            if os.path.islink(os.path.join(path, rel)):
                problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % rel)
                continue
            found.append(rel)
        if len(found) > MAX_FILES:
            break
    if len(found) > MAX_FILES:
        problems.append("The plugin holds more than %d files." % MAX_FILES)
        return out
    if MANIFEST not in found:
        problems.append("%s is missing from the plugin's top folder." % MANIFEST)
    total = 0
    for rel in found:
        problem = path_problem(rel) or kind_problem(rel)
        if problem:
            problems.append(problem)
            continue
        try:
            with open(os.path.join(path, rel), "rb") as source:
                size = os.fstat(source.fileno()).st_size
                total += size
                if total > MAX_TOTAL:
                    problems.append("The plugin is bigger than 32 MiB.")
                    return out
                problem = size_problem(rel, size)
                if problem:
                    problems.append(problem)
                    continue
                data = source.read(size)
        except OSError:
            problems.append("%s: the file could not be read." % rel)
            continue
        _take(out, rel, data)
    return out


def zip_entries(path: str) -> dict:
    """PluginPackage.zip_entries: the central directory, read before anything is inflated."""
    name = get_file(path)
    try:
        source = open(path, "rb")
    except OSError:
        return {"entries": [], "problem": "%s: the zip could not be opened." % name}
    with source:
        length = os.fstat(source.fileno()).st_size
        if length > MAX_TOTAL:
            return {"entries": [], "problem": "%s is bigger than 32 MiB." % name}
        if length < 22:
            return {"entries": [], "problem": "%s is not a whole zip." % name}
        tail_size = min(65557, length)
        source.seek(length - tail_size)
        tail = source.read(tail_size)
        end = len(tail) - 22
        while end >= 0:
            if struct.unpack_from("<I", tail, end)[0] == 0x06054B50 \
                    and end + 22 + struct.unpack_from("<H", tail, end + 20)[0] == len(tail):
                break
            end -= 1
        if end < 0:
            return {"entries": [], "problem": "%s is not a whole zip (its list of files is missing)." % name}
        count = struct.unpack_from("<H", tail, end + 10)[0]
        directory_size = struct.unpack_from("<I", tail, end + 12)[0]
        offset = struct.unpack_from("<I", tail, end + 16)[0]
        directory_end = length - tail_size + end
        if count == 0xFFFF or offset == 0xFFFFFFFF or offset + directory_size != directory_end:
            return {"entries": [], "problem": "%s: a zip64 or damaged zip; save it as a plain zip." % name}
        source.seek(offset)
        directory = source.read(directory_size)
    entries = []
    at = 0
    for _ in range(count):
        if at + 46 > len(directory) or struct.unpack_from("<I", directory, at)[0] != 0x02014B50:
            return {"entries": [], "problem": "%s is damaged (its list of files)." % name}
        made_by, _, flags, method = struct.unpack_from("<HHHH", directory, at + 4)
        packed, size, name_length, extra_length, comment_length = struct.unpack_from("<IIHHH", directory, at + 20)
        external, local = struct.unpack_from("<II", directory, at + 38)
        skip = name_length + extra_length + comment_length
        if at + 46 + skip > len(directory):
            return {"entries": [], "problem": "%s is damaged (its list of files)." % name}
        raw = directory[at + 46:at + 46 + name_length]
        entry_name = utf8_string(raw) if is_utf8(raw) else ""
        link = (made_by >> 8) == 3 and ((external >> 16) & 0xF000) == 0xA000
        entries.append({"name": entry_name, "raw": raw, "size": size, "packed": packed, "method": method,
                        "flags": flags, "link": link, "local": local})
        at += 46 + skip
        if len(entries) > MAX_FILES + MAX_FOLDERS:
            return {"entries": [], "problem": "%s holds more than %d files." % (name, MAX_FILES)}
    return {"entries": entries, "problem": ""}


def _inflate(source, entry: dict) -> bytes | None:
    """An entry's bytes as the game's ZIPReader gives them: the declared
    size, or None when they cannot be read whole."""
    try:
        source.seek(entry["local"])
        header = source.read(30)
        if len(header) < 30 or struct.unpack_from("<I", header, 0)[0] != 0x04034B50:
            return None
        name_length, extra_length = struct.unpack_from("<HH", header, 26)
        source.seek(entry["local"] + 30 + name_length + extra_length)
        packed = source.read(entry["packed"])
        if entry["method"] == 0:
            data = packed[:entry["size"]]
        else:
            data = zlib.decompressobj(-15).decompress(packed, entry["size"])
    except (OSError, zlib.error, struct.error):
        return None
    return data if len(data) == entry["size"] else None


def _read_zip(path: str) -> dict:
    out = _empty("zip")
    problems = out["problems"]
    listed = zip_entries(path)
    if listed["problem"]:
        problems.append(listed["problem"])
        return out
    keep = []
    tops: dict[str, bool] = {}
    seen: set[str] = set()
    total = 0
    for entry in listed["entries"]:
        name = entry["name"]
        if name == "":
            problems.append("An entry's name is not UTF-8 (%s)." % entry["raw"].hex()[:40])
            continue
        problem = path_problem(name[:-1] if name.endswith("/") else name)
        if problem:
            problems.append(problem)
            continue
        parts = name.split("/")
        if any(part != "" and ignored(part) for part in parts):
            continue
        if name.endswith("/") and not entry["link"]:
            continue
        if entry["link"]:
            problems.append("%s: a symbolic link; a plugin holds only plain files and folders." % name)
            continue
        if entry["flags"] & 1:
            problems.append("%s: encrypted; a plugin's zip is never locked." % name)
            continue
        if entry["method"] not in (0, 8):
            problems.append("%s: packed in a way this game does not read (only stored or deflated)." % name)
            continue
        if name.lower() in seen:
            problems.append("%s: two entries have this name." % name)
            continue
        seen.add(name.lower())
        if len(parts) < 2:
            problems.append("%s: every file of a plugin's zip goes inside one top folder." % name)
            continue
        tops[parts[0]] = True
        rel = name[len(parts[0]) + 1:]
        problem = kind_problem(rel)
        if problem:
            problems.append(problem)
            continue
        total += entry["size"]
        problem = size_problem(rel, entry["size"])
        if problem:
            problems.append(problem)
            continue
        keep.append((rel, entry))
    if len(tops) > 1:
        problems.append("Every file of a plugin's zip goes inside ONE top folder; found %d (%s)."
                        % (len(tops), ", ".join(list(tops)[:4])))
    if len(keep) > MAX_FILES:
        problems.append("The plugin holds more than %d files." % MAX_FILES)
    if total > MAX_TOTAL:
        problems.append("The plugin is bigger than 32 MiB unpacked.")
    if not any(rel == MANIFEST for rel, _ in keep):
        problems.append("%s is missing from the plugin's top folder." % MANIFEST)
    if len(tops) == 1:
        out["top"] = next(iter(tops))
    if len(tops) > 1 or len(keep) > MAX_FILES or total > MAX_TOTAL:
        return out
    with open(path, "rb") as source:
        for rel, entry in keep:
            data = _inflate(source, entry)
            if data is None:
                problems.append("%s: could not be read whole." % rel)
                continue
            _take(out, rel, data)
    return out


# --------------------------------------------------------------------------
# THE GAME'S LISTS: card names, card packs, the game's version. From a
# checkout's own sources, or the list a release carries (CARDS_FILE).
# --------------------------------------------------------------------------

class Game:
    """Where the schema and the card lists come from: a checkout, a release
    folder, or nowhere (the card names then go unchecked, and say so)."""

    def __init__(self, root: Path | None = None, kind: str = "none", version: str = "",
                 base: set | None = None, packs: dict | None = None, known_packs: list | None = None):
        self.root = root
        self.kind = kind
        self.version = version
        self.base = base
        self.packs = packs or {}
        self.known_packs = known_packs
        self._schema = None

    @property
    def has_cards(self) -> bool:
        return self.base is not None

    def schema_path(self) -> Path | None:
        if self.root is not None and (self.root / SCHEMA_REL).is_file():
            return self.root / SCHEMA_REL
        return None

    def schema(self) -> dict:
        if self._schema is None:
            where = self.schema_path()
            if where is None:
                raise UsageError("The plugin schema (%s) was not found: run this tool from a game checkout or a "
                                 "release folder, or name one with --game DIR." % SCHEMA_REL)
            value, _, message = parse_json(where.read_text(encoding="utf-8"))
            if message is not None or not isinstance(value, dict):
                raise UsageError("%s is not valid JSON." % where)
            self._schema = value
        return self._schema

    def card_known(self, card: str, packs: list) -> bool:
        """PluginSchema.card_known: a card of a required pack's trusted list, or of the base game."""
        if self.base is None:
            return True
        for pack in packs:
            if card in self.packs.get(pack, ()):
                return True
        return card in self.base

    def describe(self) -> str:
        if self.kind == "checkout":
            return "the game checkout at %s" % self.root
        if self.kind == "release":
            return "the release folder at %s" % self.root
        return "no game folder"


def _project_version(root: Path) -> str:
    try:
        found = re.search(r'^config/version="(.*)"\s*$', (root / "project.godot").read_text(encoding="utf-8"), re.M)
    except OSError:
        return ""
    return found.group(1) if found else ""


def base_card_names(root: Path) -> set[str]:
    """The base game's cards as CardRegistry registers them: each script of
    the SET_ORDER folders (not `_` helpers), named by build()'s CardData."""
    names = set()
    for code in SET_ORDER:
        for script in sorted((root / "cards" / "sets" / code).glob("*.gd")):
            if script.name.startswith("_"):
                continue
            text = script.read_text(encoding="utf-8")
            built = text.find("func build(")
            found = re.search(r'CardData\.new\(\s*"((?:[^"\\]|\\.)*)"', text[built:] if built >= 0 else text)
            if found:
                names.add(json.loads('"%s"' % found.group(1)))
    return names


def pack_card_lists(root: Path) -> tuple[dict, set, list]:
    """Every numbered pack's trusted card names (its contract's names(): the
    records of its cards*.json files), the names some pack introduced
    (AdventurePacks.owner_of: Pack 2's names, every later pack's names but
    its reprint_names.json), and the pack ids this game knows."""
    packs, owned, known = {}, set(), []
    for folder in sorted((root / "packaging" / "card_packs").glob("pack_*")):
        try:
            manifest = json.loads((folder / "manifest.json").read_text(encoding="utf-8"))
        except (OSError, ValueError):
            continue
        pack = str(manifest.get("id", ""))
        if not pack:
            continue
        known.append(pack)
        names = set()
        for cards in sorted(folder.glob("cards*.json")):
            for row in json.loads(cards.read_text(encoding="utf-8")):
                if isinstance(row, dict) and isinstance(row.get("name"), str):
                    names.add(row["name"])
        if pack in IGNORED_PACKS:
            continue
        packs[pack] = names
        reprints = folder / "reprint_names.json"
        own = set(names)
        if reprints.is_file():
            own -= set(json.loads(reprints.read_text(encoding="utf-8")))
        owned |= own
    known.sort(key=lambda p: int(p.split("-")[1]) if p.split("-")[-1].isdigit() else 999)
    return packs, owned, known


def checkout_catalogue(root: Path) -> dict:
    """The card lists a release carries (CARDS_FILE), from a checkout."""
    packs, owned, known = pack_card_lists(root)
    base = base_card_names(root) - owned
    return {"format": 1, "about": "Card names only (never card text or art): what adventure_plugin.py validate "
            "checks a plugin's cards against in a release folder. Written by tools/package_release.py.",
            "version": _project_version(root), "known_packs": known, "base": sorted(base),
            "packs": {pack: sorted(names) for pack, names in packs.items()}}


def catalogue_bytes(root: Path) -> bytes:
    return (json.dumps(checkout_catalogue(root), indent="\t", ensure_ascii=False) + "\n").encode("utf-8")


def find_game(explicit: str | None = None) -> Game:
    """The game around this tool (or [explicit]): a checkout (project.godot
    and the card scripts), a release folder (CARDS_FILE in its tools/), or none."""
    candidates = [Path(explicit).resolve()] if explicit else [HERE.parent]
    for root in candidates:
        if (root / "project.godot").is_file() and (root / "cards" / "sets").is_dir():
            packs, owned, known = pack_card_lists(root)
            return Game(root, "checkout", _project_version(root), base_card_names(root) - owned, packs, known)
        listed = root / "tools" / CARDS_FILE
        if listed.is_file():
            try:
                data = json.loads(listed.read_text(encoding="utf-8"))
            except (OSError, ValueError):
                raise UsageError("%s is not valid JSON." % listed)
            version = str(data.get("version", ""))
            if not version and (root / "VERSION.txt").is_file():
                version = (root / "VERSION.txt").read_text(encoding="utf-8").strip()
            return Game(root, "release", version, set(data.get("base", [])),
                        {k: set(v) for k, v in data.get("packs", {}).items()}, list(data.get("known_packs", [])))
        if explicit:
            if (root / SCHEMA_REL).is_file():
                return Game(root, "none", "")
            raise UsageError("%s is neither a game checkout nor a release folder." % root)
    root = HERE.parent
    return Game(root if (root / SCHEMA_REL).is_file() else None, "none", "")


# --------------------------------------------------------------------------
# STAGE 2 — THE MANIFEST (AdventurePlugins.manifest_problems)
# --------------------------------------------------------------------------

def valid_id(text: str) -> bool:
    return text not in RESERVED_IDS and re.search(ID_PATTERN, text) is not None


def valid_version(text: str) -> bool:
    parts = text.split(".")
    if len(text) > 24 or len(parts) > 4:
        return False
    return all(part != "" and is_valid_int(part) and part[0] not in "+-" for part in parts)


def compare_versions(a: str, b: str) -> int:
    left, right = a.split("."), b.split(".")
    for i in range(max(len(left), len(right))):
        x = int(left[i]) if i < len(left) and is_valid_int(left[i]) else 0
        y = int(right[i]) if i < len(right) and is_valid_int(right[i]) else 0
        if x != y:
            return -1 if x < y else 1
    return 0


def _text_problem(out: list, manifest: dict, key: str, most: int, needed: bool) -> None:
    if key not in manifest:
        return
    value = manifest[key]
    if not isinstance(value, str) or len(value) > most or (needed and strip_edges(value) == ""):
        out.append("plugin.json: %s must be %stext of at most %d characters." % (key, "non-empty " if needed else "", most))


def _requires_problems(value, game: Game) -> list:
    out = []
    if not isinstance(value, dict):
        out.append("plugin.json: requires must be an object.")
        return out
    for key in value:
        if key != "card_packs":
            out.append("plugin.json: requires: unknown field \"%s\"." % key)
    packs = value.get("card_packs", [])
    if not isinstance(packs, list) or len(packs) > MAX_PACKS:
        out.append("plugin.json: requires.card_packs must be a list of at most %d packs." % MAX_PACKS)
        return out
    seen = set()
    for need in packs:
        if not isinstance(need, dict) or not isinstance(need.get("id"), str):
            out.append("plugin.json: each of requires.card_packs is {\"id\": \"pack-N\", \"min_version\": \"1.0\"}.")
            continue
        for key in need:
            if key not in ("id", "min_version"):
                out.append("plugin.json: requires.card_packs: unknown field \"%s\"." % key)
        pack = need["id"]
        if pack in IGNORED_PACKS:
            out.append("plugin.json: %s is never part of an adventure." % pack)
        elif game.known_packs is not None and pack not in game.known_packs:
            out.append("plugin.json: this game knows no card pack \"%s\"." % pack)
        if pack in seen:
            out.append("plugin.json: %s is named twice in requires.card_packs." % pack)
        seen.add(pack)
        if "min_version" in need and (not isinstance(need["min_version"], str) or not valid_version(need["min_version"])):
            out.append("plugin.json: %s's min_version must be numbers and dots, like \"1.0\"." % pack)
    return out


def _region_problems(value) -> list:
    out = []
    if not isinstance(value, dict):
        out.append("plugin.json: region must be an object.")
        return out
    for key in value:
        if key not in REGION_FIELDS:
            out.append("plugin.json: region: unknown field \"%s\"." % key)
    title = value.get("title")
    if not isinstance(title, str) or strip_edges(title) == "" or len(title) > MAX_NAME:
        out.append("plugin.json: region.title must be non-empty text of at most %d characters." % MAX_NAME)
    if "castle_name" in value and (not isinstance(value["castle_name"], str) or len(value["castle_name"]) > MAX_NAME):
        out.append("plugin.json: region.castle_name must be text of at most %d characters." % MAX_NAME)
    if "salt" in value and (not whole(value["salt"]) or int(value["salt"]) < 0 or int(value["salt"]) > 0x7FFFFFFF):
        out.append("plugin.json: region.salt must be a whole number from 0 to 2147483647.")
    if "mana_links" in value and not isinstance(value["mana_links"], bool):
        out.append("plugin.json: region.mana_links must be true or false.")
    if "palette" in value:
        palette = value["palette"]
        if isinstance(palette, str):
            if palette not in PALETTES:
                out.append("plugin.json: region.palette \"%s\" is not one of the game's palettes (%s), nor a palette object."
                           % (palette, ", ".join(PALETTES)))
        elif not isinstance(palette, dict):
            out.append("plugin.json: region.palette must be a palette's name or a palette object.")
    return out


def manifest_problems(value, game: Game) -> list:
    out = []
    if not isinstance(value, dict):
        out.append("plugin.json: must be one JSON object { ... }.")
        return out
    manifest = value
    for key in manifest:
        if key not in FIELDS:
            out.append("plugin.json: unknown field \"%s\"." % key)
    for key in REQUIRED_FIELDS:
        if key not in manifest:
            out.append("plugin.json: the field \"%s\" is missing." % key)
    if out:
        return out
    if not whole(manifest["plugin_format"]) or int(manifest["plugin_format"]) != PLUGIN_FORMAT:
        out.append("plugin.json: plugin_format must be %d." % PLUGIN_FORMAT)
    if not whole(manifest["api_version"]) or int(manifest["api_version"]) < 1:
        out.append("plugin.json: api_version must be a whole number from 1.")
    elif int(manifest["api_version"]) > API_VERSION:
        out.append("This plugin needs plugin API %d; this game reads API %d. A newer game is needed."
                   % (int(manifest["api_version"]), API_VERSION))
    if not isinstance(manifest["id"], str) or not valid_id(manifest["id"]):
        out.append("plugin.json: id must be 1 to 40 lower-case letters, digits or _, a letter first (not \"mainland\").")
    _text_problem(out, manifest, "name", MAX_NAME, True)
    _text_problem(out, manifest, "description", MAX_LINE, False)
    _text_problem(out, manifest, "license", MAX_TEXT, False)
    _text_problem(out, manifest, "learning_note", MAX_TEXT, False)
    if not isinstance(manifest["version"], str) or not valid_version(manifest["version"]):
        out.append("plugin.json: version must be numbers and dots, like \"1.0.0\".")
    if "minimum_game_version" in manifest:
        least = manifest["minimum_game_version"]
        if not isinstance(least, str) or not valid_version(least):
            out.append("plugin.json: minimum_game_version must be numbers and dots, like \"0.60.19\".")
        elif game.version and compare_versions(least, game.version) > 0:
            out.append("This plugin needs game version %s or newer; this is %s." % (least, game.version))
    authors = manifest["authors"]
    if not isinstance(authors, list) or not authors or len(authors) > MAX_AUTHORS or not all(
            isinstance(a, str) and strip_edges(a) != "" and len(a) <= MAX_NAME for a in authors):
        out.append("plugin.json: authors must be a list of 1 to %d names." % MAX_AUTHORS)
    if "requires" in manifest:
        out.extend(_requires_problems(manifest["requires"], game))
    out.extend(_region_problems(manifest["region"]))
    if "files" in manifest:
        files = manifest["files"]
        if not isinstance(files, dict):
            out.append("plugin.json: files must be an object of file -> SHA-256.")
        else:
            for rel, digest in files.items():
                if not isinstance(digest, str) or len(digest) != 64 or not is_valid_hex_number(digest) \
                        or digest != digest.lower():
                    out.append("plugin.json: files: \"%s\" needs its SHA-256 as 64 lower-case hex digits." % rel)
    return out


# --------------------------------------------------------------------------
# STAGE 3 — THE FILES LIST (AdventurePlugins.integrity_problems)
# --------------------------------------------------------------------------

def integrity_problems(manifest: dict, files: dict) -> list:
    out = []
    if "files" not in manifest:
        return out
    listed = manifest["files"]
    for rel in sorted(listed):
        if rel not in files:
            out.append("%s: listed in plugin.json's files but not in the plugin." % rel)
        elif sha256(files[rel]) != listed[rel]:
            out.append("%s: its SHA-256 is not the one plugin.json's files list gives (the file changed after export)." % rel)
    for rel in sorted(files):
        if rel != MANIFEST and rel not in listed:
            out.append("%s: not in plugin.json's files list." % rel)
    return out


# --------------------------------------------------------------------------
# STAGE 4 — THE CONTENT (PluginSchema.read, PluginText, WorldTerrainPalette)
# --------------------------------------------------------------------------

def unknown_placeholders(template: str) -> list:
    out = []
    at = template.find("{")
    while at >= 0:
        close = template.find("}", at)
        if close < 0:
            break
        word = template[at + 1:close]
        if 0 < len(word) <= 40 and all(c in "abcdefghijklmnopqrstuvwxyz0123456789_" for c in word) \
                and word not in PLACEHOLDERS and word not in out:
            out.append(word)
        at = template.find("{", at + 1)
    return out


def _hex_color(value) -> bool:
    if not isinstance(value, str):
        return False
    digits = value[1:] if value.startswith("#") else value
    return len(digits) == 6 and is_valid_hex_number(digits)


def _known_preset(name) -> bool:
    if isinstance(name, str) and name in PALETTES:
        return True
    if not isinstance(name, str) or not name.startswith(PALETTE_PREFIX):
        return False
    return re.search(ID_PATTERN, name[len(PALETTE_PREFIX):]) is not None


def _valid_style(style) -> bool:
    if not isinstance(style, dict):
        return False
    for key, layer in style.items():
        if key == "preset":
            if not _known_preset(layer):
                return False
        elif key in PALETTE_LAYERS:
            if not isinstance(layer, dict) or len(layer) != 2:
                return False
            tint, strength = layer.get("tint"), layer.get("strength")
            if not isinstance(tint, str) or len(tint) != 7 or not tint.startswith("#"):
                return False
            if any(digit not in "0123456789abcdefABCDEF" for digit in tint[1:]):
                return False
            if not is_number(strength) or strength != strength or abs(strength) == float("inf") \
                    or strength < 0 or strength > 1:
                return False
        else:
            return False
    return True


def palette_problem(value) -> str:
    """WorldTerrainPalette.profile_problem."""
    if not isinstance(value, dict):
        return "a palette object is needed."
    for key in value:
        if key not in ("name", "grass", "foliage", "water", "plain", "tints"):
            return "unknown field %s." % key
    if "name" in value and (not isinstance(value["name"], str) or len(value["name"]) > 60):
        return "name: up to 60 characters."
    for recipe in ("grass", "foliage", "water"):
        if recipe not in value:
            continue
        numbers = value[recipe]
        wrong = "%s: four numbers (hue 0-1, saturation and brightness 0-4, strength 0-1)." % recipe
        if not isinstance(numbers, list) or len(numbers) != 4:
            return wrong
        for i, n in enumerate(numbers):
            if not is_number(n) or n != n or abs(n) == float("inf") or n < 0 or n > (1 if i in (0, 3) else 4):
                return wrong
    if "plain" in value:
        plain = value["plain"]
        if not isinstance(plain, dict) or len(plain) > 16:
            return "plain: terrain codes to colors."
        for key, color in plain.items():
            if not is_valid_int(key) or int(key) < 0 or int(key) > 15 or str(int(key)) != key:
                return "plain: %s is not a terrain code 0-15." % key
            if not _hex_color(color):
                return "plain.%s: a color like #c6af78 is needed." % key
    if "tints" in value:
        tints = value["tints"]
        if not isinstance(tints, dict):
            return "tints: layer settings are needed."
        for layer in tints:
            if layer not in PALETTE_LAYERS or not _valid_style({layer: tints[layer]}):
                return "tints.%s: {\"tint\": \"#rrggbb\", \"strength\": 0-1} per layer (ground, objects, roads)." % layer
    return ""


class Content:
    """PluginSchema.read: the content files checked against schema_v1.json
    and against each other, normalized as the game normalizes them."""

    def __init__(self, game: Game):
        self.game = game
        self.schema = game.schema()
        self.notes: list[str] = []

    @staticmethod
    def _refs() -> dict:
        return {"text": [], "card": [], "picture": [], "file": []}

    def read(self, manifest: dict, files: dict) -> dict:
        problems: list[str] = []
        spec = self.schema
        ident = str(manifest.get("id", "")) if isinstance(manifest.get("id", ""), str) else ""
        refs = self._refs()
        content = {}
        for name, rule in spec["files"].items():
            if name not in files:
                if rule.get("required", False):
                    problems.append("%s is missing." % name)
                continue
            parsed = self._parse(name, files[name], problems)
            if parsed is None:
                continue
            errors: list[str] = []
            value = self.check(parsed, {"kind": "ref", "type": rule["type"]}, name, errors, refs, files)
            problems.extend(errors)
            content[name] = value
        if problems:
            return {"data": {}, "problems": problems}
        data = {"id": ident, "manifest": manifest, "world": content["world.json"], "places": content["places.json"],
                "quests": content["quests.json"], "foes": content["foes.json"],
                "rewards": content.get("rewards.json", {"count": 6, "bundles": []}), "text": content["text.json"],
                "packs": packs_of(manifest)}
        data["world"]["region"] = ident
        self._cross_check(data, refs, problems)
        self._check_palette(manifest, problems)
        if problems:
            return {"data": {}, "problems": problems}
        return {"data": data, "problems": problems}

    def _parse(self, name: str, data, problems: list):
        limits = self.schema["limits"]
        if len(data) > int(limits["json_bytes"]):
            problems.append("%s is larger than %d bytes." % (name, int(limits["json_bytes"])))
            return None
        value, line, message = parse_json(utf8_string(data))
        if message is not None:
            # A line as authors count them, from 1 (the lead's ruling on RV2).
            problems.append("%s: line %d: %s" % (name, line + 1, message))
            return None
        if depth(value, 10 ** 6) > int(limits["json_depth"]):
            problems.append("%s nests deeper than %d." % (name, int(limits["json_depth"])))
            return None
        if not isinstance(value, dict):
            problems.append("%s must hold one object." % name)
            return None
        return value

    # ------------------------------------------------------------ shapes --

    def check(self, value, spec: dict, path: str, problems: list, refs: dict, files: dict):
        kind = str(spec.get("kind", ""))
        if kind == "ref":
            named = self.schema["types"].get(str(spec["type"]))
            if not isinstance(named, dict):
                problems.append("%s: the schema has no type %s." % (path, spec["type"]))
                return None
            return self.check(value, named, path, problems, refs, files)
        if kind == "int":
            if not is_number(value) or value != value or abs(value) == float("inf") or float(value) != float(int(value)):
                problems.append("%s: a whole number is needed." % path)
                return None
            if ("min" in spec and value < float(spec["min"])) or ("max" in spec and value > float(spec["max"])):
                problems.append("%s: %s is outside %s..%s." % (path, str(int(value)), fmt_num(spec.get("min")), fmt_num(spec.get("max"))))
                return None
            return int(value)
        if kind == "number":
            if not is_number(value) or value != value or abs(value) == float("inf"):
                problems.append("%s: a number is needed." % path)
                return None
            if ("min" in spec and value < float(spec["min"])) or ("max" in spec and value > float(spec["max"])):
                problems.append("%s: %s is outside %s..%s." % (path, str(value), fmt_num(spec.get("min")), fmt_num(spec.get("max"))))
                return None
            return float(value)
        if kind == "bool":
            if not isinstance(value, bool):
                problems.append("%s: true or false is needed." % path)
                return None
            return value
        if kind in ("string", "text", "card", "hex", "file", "picture"):
            return self._check_string(value, spec, kind, path, problems, refs, files)
        if kind == "enum":
            for option in spec["values"]:
                if is_number(option) and is_number(value) and float(option) == float(value):
                    return int(option)
                if isinstance(option, str) and isinstance(value, str) and option == value:
                    return value
            problems.append("%s: one of %s is needed." % (path, ", ".join(fmt_num(v) if is_number(v) else str(v) for v in spec["values"])))
            return None
        if kind == "array":
            if not isinstance(value, list):
                problems.append("%s: a list is needed." % path)
                return None
            low, high = int(spec.get("min", 0)), int(spec.get("max", 512))
            if len(value) < low or len(value) > high:
                problems.append("%s: %d entries; %d to %d are allowed." % (path, len(value), low, high))
                return None
            return [self.check(item, spec["items"], "%s[%d]" % (path, i), problems, refs, files) for i, item in enumerate(value)]
        if kind == "map":
            if not isinstance(value, dict):
                problems.append("%s: an object is needed." % path)
                return None
            low, high = int(spec.get("min", 0)), int(spec.get("max", 512))
            if len(value) < low or len(value) > high:
                problems.append("%s: %d entries; %d to %d are allowed." % (path, len(value), low, high))
                return None
            out = {}
            for key, item in value.items():
                errors: list[str] = []
                self.check(key, spec["keys"], "%s key %s" % (path, key), errors, refs, files)
                if errors:
                    problems.extend(errors)
                    continue
                out[key] = self.check(item, spec["values"], "%s.%s" % (path, key), problems, refs, files)
            return out
        if kind == "object":
            if not isinstance(value, dict):
                problems.append("%s: an object is needed." % path)
                return None
            fields = spec.get("fields", {})
            out = {}
            for key in value:
                if key not in fields:
                    problems.append("%s: unknown field %s." % (path, key))
            for key, field in fields.items():
                at = "%s.%s" % (path, key) if path != "" else key
                if key in value:
                    out[key] = self.check(value[key], field, at, problems, refs, files)
                elif "default" in field:
                    out[key] = self.check(field["default"], field, at, problems, self._refs(), files)
                elif field.get("required", False):
                    problems.append("%s: %s is required." % (path, key))
            return out
        if kind == "oneof":
            tries = []
            for option in spec["options"]:
                errors: list[str] = []
                found = self._refs()
                out = self.check(value, option, path, errors, found, files)
                if not errors:
                    for group in found:
                        refs[group].extend(found[group])
                    return out
                tries.append(errors[0])
            problems.append("%s: none of its forms fits (%s)." % (path, "; ".join(tries)))
            return None
        if kind == "single":
            options = spec["options"]
            if not isinstance(value, dict) or len(value) != 1:
                problems.append("%s: an object with one of %s is needed." % (path, ", ".join(options)))
                return None
            key = next(iter(value))
            if key not in options:
                problems.append("%s: %s is not one of %s." % (path, key, ", ".join(options)))
                return None
            return {key: self.check(value[key], options[key], "%s.%s" % (path, key), problems, refs, files)}
        problems.append("%s: the schema's kind %s is unknown." % (path, kind))
        return None

    def _check_string(self, value, spec, kind, path, problems, refs, files):
        if not isinstance(value, str):
            problems.append("%s: text in quotes is needed." % path)
            return None
        limit = int(spec.get("max", self.schema["limits"]["text_chars"]))
        if len(value) < int(spec.get("min", 1 if kind != "string" else 0)) or len(value) > limit:
            problems.append("%s: %d characters; at most %d are allowed." % (path, len(value), limit))
            return None
        if "pattern" in spec and re.search(str(spec["pattern"]), value) is None:
            problems.append("%s: %s does not fit %s." % (path, value, spec["pattern"]))
            return None
        if kind == "hex":
            if len(value) != 6 or not is_valid_hex_number(value):
                problems.append("%s: six hex digits are needed (like e0bc60)." % path)
                return None
        elif kind == "file":
            classes = self.schema["extensions"]
            allowed = classes.get(str(spec.get("class", "")), classes["allowed"])
            if "." + get_extension(value).lower() not in allowed:
                problems.append("%s: %s must end in %s." % (path, value, ", ".join(allowed)))
                return None
            if value not in files:
                problems.append("%s: the plugin has no file %s." % (path, value))
                return None
            refs["file"].append(value)
        elif kind in ("text", "card", "picture"):
            refs[kind].append((value, path))
        return value

    # ------------------------------------------------------ cross checks --

    def _cross_check(self, data: dict, refs: dict, problems: list) -> None:
        ident = data["id"]
        words = data["text"]
        for key, template in words.items():
            unknown = unknown_placeholders(str(template))
            if unknown:
                problems.append("text.json: %s: unknown placeholder %s (the list: %s)."
                                % (key, ", ".join("{" + w + "}" for w in unknown), ", ".join(PLACEHOLDERS)))
        for key, path in refs["text"]:
            if key not in words and key not in TEXT_DEFAULTS:
                problems.append("%s: text.json has no %s." % (path, key))
        pictures = data["places"]["pictures"]
        for key in pictures:
            if not str(key).startswith(ident + "_"):
                problems.append("places.json: pictures.%s: a picture key begins with the plugin id and _ (%s_…)." % (key, ident))
        skin = self.schema["skin_pictures"]
        for key, path in refs["picture"]:
            if key not in pictures and key not in skin:
                problems.append("%s: %s is neither a picture of places.json nor a skin picture (%s)." % (path, key, ", ".join(skin)))
        packs = data["packs"]
        if not self.game.has_cards and refs["card"]:
            self.notes.append("Card names were not checked (%d named): %s holds no card lists. Run the tool in a "
                              "game checkout or a release folder, or name one with --game DIR."
                              % (len(refs["card"]), self.game.describe()))
        for card, path in refs["card"]:
            if not self.game.card_known(card, packs):
                problems.append("%s: %s is not a card of the base game or of a required pack (%s)."
                                % (path, card, ", ".join(packs) if packs else "none"))
        self._check_world(data["world"], problems)
        self._check_quests(data, problems)
        self._check_foes(data, problems)

    @staticmethod
    def _claim_slot(slots: dict, slot: int, part: str, problems: list) -> None:
        if slot in slots:
            problems.append("world.json: slot %d is taken twice (%s and %s)." % (slot, slots[slot], part))
        else:
            slots[slot] = part

    def _check_world(self, world: dict, problems: list) -> None:
        if int(world["offset"]) + int(world["side"]) > 64:
            problems.append("world.json: offset + side is %d; the map is 64 tiles." % (int(world["offset"]) + int(world["side"])))
        if (int(world["side"]) - 1) * int(world["step"]) >= 64:
            problems.append("world.json: side x step reads past the 64-tile source map.")
        if int(world["dungeon"]["from"]) + int(world["dungeon"]["choices"]) > 15:
            problems.append("world.json: dungeon.from + dungeon.choices reaches past the source's 15 dungeons.")
        slots: dict = {}
        for town in world["towns"]["list"]:
            self._claim_slot(slots, int(town["slot"]), "towns", problems)
        for place in world["places"]["list"]:
            self._claim_slot(slots, int(place["slot"]), "places", problems)
        villages = world["villages"]
        low, high = int(villages["count"][0]), int(villages["count"][1])
        if high < low:
            problems.append("world.json: villages.count must read least, most.")
        if len(villages["names"]) < high:
            problems.append("world.json: villages.names holds %d names for up to %d villages." % (len(villages["names"]), high))
        for i in range(high):
            slot = (i + 1) * int(villages["slot_step"])
            if slot > 127:
                problems.append("world.json: village %d would take slot %d; slots end at 127." % (i + 1, slot))
            else:
                self._claim_slot(slots, slot, "villages", problems)

    @staticmethod
    def _target_uses(target, uses: dict) -> None:
        if isinstance(target, dict):
            if "objective" in target:
                uses["objectives"].append(target["objective"])
            if "site" in target:
                uses["sites"].append(int(target["site"]))

    def _condition_uses(self, conditions: list, uses: dict) -> None:
        for condition in conditions:
            key = next(iter(condition))
            value = condition[key]
            if key in ("flag", "not_flag"):
                uses["flags"].append(value)
            elif key == "stage":
                uses["quests"].append(int(value["quest"]))
            elif key == "quest_done":
                uses["quests"].append(int(value))
            elif key == "deck_share":
                uses["packs"].append(value["pack"])
            elif key == "here":
                self._target_uses(value, uses)

    @staticmethod
    def _effect_uses(effects: list, uses: dict) -> None:
        for effect in effects:
            key = next(iter(effect))
            if key == "set_flag":
                uses["flags"].append(effect[key])
            elif key == "set_stage":
                uses["quests"].append(int(effect[key]["quest"]))
            elif key == "reward_choice" and effect[key]:
                uses["rewards"] = True

    def _check_quests(self, data: dict, problems: list) -> None:
        quests = data["quests"]
        world = data["world"]
        flags = quests["flags"]
        for flag in flags:
            if flag in RESERVED_FLAGS:
                problems.append("quests.json: flags: %s is a reserved name." % flag)
        traders = {int(town["slot"]) for town in world["towns"]["list"]}
        traders |= {int(place["slot"]) for place in world["places"]["list"] if str(place["kind"]) != "village"}
        foes = data["foes"]["foes"]
        givers: dict = {}
        count = len(quests["quests"])
        uses = {"flags": [], "quests": [], "objectives": [], "sites": [], "packs": [], "rewards": False}
        for index, quest in enumerate(quests["quests"]):
            at = "quests.json: quests[%d]" % index
            giver = int(quest["giver"])
            if giver not in traders:
                problems.append("%s.giver: slot %d is not a town or place of world.json." % (at, giver))
            if giver in givers:
                problems.append("%s.giver: slot %d already gives quest %d." % (at, giver, givers[giver]))
            givers[giver] = index
            if quest["foe"] not in foes:
                problems.append("%s.foe: foes.json has no %s." % (at, quest["foe"]))
            steps = quest["steps"]
            for s, step in enumerate(steps):
                where = "%s.steps[%d]" % (at, s)
                kind = str(step["do"])
                if kind == "accept":
                    if s != 0:
                        problems.append("%s: only a quest's first step may be accept." % where)
                elif kind == "go":
                    for field in ("to", "action", "guidance", "task"):
                        if field not in step:
                            problems.append("%s: a go step needs %s." % (where, field))
                    if "to" in step:
                        self._target_uses(step["to"], uses)
                elif kind == "duel":
                    if "at" in step:
                        self._target_uses(step["at"], uses)
                if kind == "duel" and s != len(steps) - 1:
                    problems.append("%s: the duel ends the quest; it must be the last step." % where)
            if str(steps[-1]["do"]) != "duel":
                problems.append("%s.steps: the last step must be the duel." % at)
            done = quest["complete"]
            if isinstance(done, str):
                if done not in quests["completions"]:
                    problems.append("%s.complete: quests.json completions has no %s." % (at, done))
                else:
                    quest["complete"] = json.loads(json.dumps(quests["completions"][done]))
            if isinstance(quest["complete"], list):
                self._effect_uses(quest["complete"], uses)
                self._check_effects(quest["complete"], "%s.complete" % at, quests, problems, False)
        finale = quests["finale"]
        self._check_effects(finale["effects"], "quests.json: finale.effects", quests, problems, True)
        if finale["foe"] not in foes:
            problems.append("quests.json: finale.foe: foes.json has no %s." % finale["foe"])
        uses["flags"].append(finale["done_flag"])
        self._condition_uses(finale["conditions"], uses)
        self._effect_uses(finale["effects"], uses)
        for kind in MARKERS:
            marker = data["places"]["markers"][kind]
            if "banner" in marker:
                uses["flags"].append(marker["banner"]["flag"])
            for pane in marker["panes"]:
                self._condition_uses(pane["when"], uses)
                for line in pane["lines"]:
                    if isinstance(line, dict):
                        self._condition_uses(line.get("when", []), uses)
                for action in pane["actions"]:
                    self._condition_uses(action["when"], uses)
        talk = quests["talk"]
        for group in (quests["status"], talk.get("news", []), talk.get("applause", []), talk.get("roaming", []),
                      talk.get("tribute", [])):
            for line in group:
                if isinstance(line, dict):
                    self._condition_uses(line.get("when", []), uses)
        for flag in uses["flags"]:
            if flag not in flags:
                problems.append("quests.json: the flag %s is not declared in flags." % flag)
        for quest in uses["quests"]:
            if quest >= count:
                problems.append("quests.json: quest %d is named; there are %d." % (quest, count))
        for name in uses["objectives"]:
            if name not in world["objectives"]:
                problems.append("quests.json: the objective %s is not in world.json objectives." % name)
        for slot in uses["sites"]:
            if slot not in traders:
                problems.append("quests.json: site %d is not a town or place of world.json." % slot)
        for pack in uses["packs"]:
            if pack not in data["packs"]:
                problems.append("quests.json: deck_share names %s, which the manifest does not require." % pack)
        if uses["rewards"] and not data["rewards"]["bundles"]:
            problems.append("quests.json: a reward_choice needs rewards.json bundles.")

    @staticmethod
    def _check_effects(effects: list, at: str, quests: dict, problems: list, finale: bool) -> None:
        """PluginSchema._check_effects: effects that would write progress a
        save could not carry — a second reward choice for one quest, one
        owed by the finale, a stage past its quest's steps, the finale's
        flag set by anything but the finale."""
        choices = 0
        count = len(quests["quests"])
        done_flag = str(quests["finale"]["done_flag"])
        for effect in effects:
            key = next(iter(effect))
            value = effect[key]
            if key == "reward_choice":
                if not value:
                    continue
                if finale:
                    problems.append("%s: a reward_choice belongs to a quest's completion, not the finale." % at)
                else:
                    choices += 1
            elif key == "set_stage":
                quest = int(value["quest"])
                if quest >= count:
                    continue
                most = len(quests["quests"][quest]["steps"]) - 1
                if int(value["value"]) > most:
                    problems.append("%s: set_stage: quest %d has %d step%s; its stage goes up to %d."
                                    % (at, quest, most + 1, "" if most == 0 else "s", most))
            elif key == "set_flag":
                if not finale and str(value) == done_flag:
                    problems.append("%s: set_flag: %s is the finale's flag; only the finale's effects set it." % (at, value))
        if choices > 1:
            problems.append("%s: one reward_choice at most; a quest owes one reward choice." % at)

    @staticmethod
    def _check_foes(data: dict, problems: list) -> None:
        foes = data["foes"]["foes"]
        for name, foe in foes.items():
            cards = sum(int(n) for n in foe["deck"].values())
            if cards < 1 or cards > 250:
                problems.append("foes.json: foes.%s.deck holds %d cards; 1 to 250 are allowed." % (name, cards))
            face = int(foe["face"])
            if not (0 <= face < CREATURE_ROWS) or face == LAIR:
                problems.append("foes.json: foes.%s.face: %d is not a creature row." % (name, face))
        roaming = data["foes"].get("roaming")
        if isinstance(roaming, dict):
            for i, deck in enumerate(roaming["decks"]):
                if deck["foe"] not in foes:
                    problems.append("foes.json: roaming.decks[%d].foe: no foe %s." % (i, deck["foe"]))

    @staticmethod
    def _check_palette(manifest: dict, problems: list) -> None:
        region = manifest.get("region", {})
        if not isinstance(region, dict):
            return
        palette = region.get("palette")
        if palette is None:
            return
        if isinstance(palette, str):
            if palette not in PALETTES:
                problems.append("plugin.json: region.palette: %s is not a built-in palette." % palette)
        elif isinstance(palette, dict):
            why = palette_problem(palette)
            if why:
                problems.append("plugin.json: region.palette: " + why)
        else:
            problems.append("plugin.json: region.palette: a palette name or a palette object is needed.")


def packs_of(manifest: dict) -> list:
    out = []
    requires = manifest.get("requires", {})
    if not isinstance(requires, dict) or not isinstance(requires.get("card_packs"), list):
        return out
    for row in requires["card_packs"]:
        if isinstance(row, dict) and isinstance(row.get("id"), str) and row["id"] not in out:
            out.append(row["id"])
    return out


# --------------------------------------------------------------------------
# THE STAGES, in the game's order (AdventurePlugins._add)
# --------------------------------------------------------------------------

def without_files_list(files: dict) -> None:
    """[files]' plugin.json without its `files` list, when it has one (an
    export writes a fresh list; a folder being edited needs none)."""
    data = files.get(MANIFEST)
    if data is None or not is_utf8(data):
        return
    value, _, message = parse_json(utf8_string(data).lstrip("\ufeff"), ints=True)
    if message is None and isinstance(value, dict) and "files" in value:
        del value["files"]
        files[MANIFEST] = (json.dumps(value, indent="\t", ensure_ascii=False) + "\n").encode("utf-8")


def judge(path: str, game: Game, drop_files_list: bool = False) -> dict:
    """Every check the game runs on the plugin at [path], in its stages;
    the first stage with a problem is the last one run. {valid, stage,
    problems, notes, kind, top, files, manifest, data}. [drop_files_list]:
    its plugin.json's `files` list set aside first (export's own reading)."""
    read = read_package(path)
    if drop_files_list:
        without_files_list(read["files"])
    problems: list[str] = []
    files = read["files"]
    parsed = None
    stage = "package"
    if MANIFEST in files:
        loaded = json_file(MANIFEST, files[MANIFEST])
        parsed = loaded["value"]
        if loaded["problem"] and not read["problems"]:
            problems.append(loaded["problem"])
            stage = "manifest"
    manifest = parsed if isinstance(parsed, dict) else {}
    out = {"valid": False, "stage": stage, "problems": problems, "notes": [], "kind": read["kind"],
           "top": read["top"], "files": files, "manifest": manifest, "data": {}, "path": str(path)}
    problems.extend(read["problems"])
    if problems:
        return out
    out["stage"] = "manifest"
    if parsed is None:
        problems.append("%s could not be read." % MANIFEST)
        return out
    problems.extend(manifest_problems(parsed, game))
    if problems:
        return out
    if not game.version and "minimum_game_version" in manifest:
        out["notes"].append("minimum_game_version was not checked: %s gives no game version." % game.describe())
    out["stage"] = "files"
    problems.extend(integrity_problems(manifest, files))
    if problems:
        if read["kind"] == "folder":
            out["notes"].append("remove the files list from plugin.json (it is written by export): a folder you "
                                "edit needs none, and export writes a fresh one into the zip.")
        return out
    out["stage"] = "content"
    reader = Content(game)
    content = reader.read(manifest, files)
    out["notes"].extend(reader.notes)
    problems.extend(content["problems"])
    if problems:
        return out
    out["data"] = content["data"]
    out["valid"] = True
    out["stage"] = "valid"
    return out


# --------------------------------------------------------------------------
# new — the skeleton
# --------------------------------------------------------------------------

def png_bytes(width: int, height: int, pixels: list) -> bytes:
    """A PNG (8-bit RGBA) of [pixels]: rows of (r, g, b, a) tuples."""
    raw = b"".join(b"\x00" + bytes(channel for pixel in row for channel in pixel) for row in pixels)

    def chunk(kind: bytes, body: bytes) -> bytes:
        return struct.pack(">I", len(body)) + kind + body + struct.pack(">I", zlib.crc32(kind + body) & 0xFFFFFFFF)

    return (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", struct.pack(">IIBBBBB", width, height, 8, 6, 0, 0, 0))
            + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b""))


def _sprite(rows: list, palette: dict) -> bytes:
    pixels = [[palette[c] for c in row] for row in rows]
    return png_bytes(len(rows[0]), len(rows), pixels)


## Two placeholder map pictures, 32 x 32 pixel art: a castle keep and a
## harbor's pier with a sail. Each letter is one pixel of the palette below.
CASTLE_ROWS = [
    "................................",
    "................................",
    "...............##...............",
    "..............#yy#..............",
    "..............#y##..............",
    "..............#|................",
    "......##.##...#|..##.##.........",
    "......#s##s#..#|..#s##s#........",
    "......#ssss#.###..#ssss#........",
    "......#ssss#.#ss#.#ssss#........",
    "......#ssss###ss###ssss#........",
    "......#ssssssssssssssss#........",
    "......#sssdssssssssdsss#........",
    "......#sssdssssssssdsss#........",
    "......#ssssssssssssssss#........",
    "......#ssssss####ssssss#........",
    "......#sssss#dddd#sssss#........",
    "......#ssss#dddddd#ssss#........",
    "......#ssss#dddddd#ssss#........",
    "......#ssss#dddddd#ssss#........",
    ".....##ssss#dddddd#ssss##.......",
    "....#gggggg#dddddd#gggggg#......",
    "....######################......",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]
PORT_ROWS = [
    "................................",
    "................................",
    "................................",
    "...............#................",
    "..............#y#...............",
    "...............|................",
    "...............|#...............",
    "...............|w#..............",
    "...............|ww#.............",
    "...............|www#............",
    "...............|wwww#...........",
    "...............|wwwww#..........",
    "...............|wwwwww#.........",
    "...............|#######.........",
    "...............|................",
    "........#######|#######.........",
    "........#bbbbbbbbbbbbb#.........",
    ".........#bbbbbbbbbbb#..........",
    "..........###########...........",
    "...pppppppppp...................",
    "...p#..#..#.p...................",
    "...p#..#..#.p...................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]
SPRITE_COLORS = {".": (0, 0, 0, 0), "#": (38, 32, 28, 255), "s": (150, 146, 136, 255), "d": (74, 56, 40, 255),
                 "g": (96, 120, 64, 255), "y": (214, 170, 60, 255), "|": (112, 82, 50, 255),
                 "w": (236, 230, 214, 255), "b": (128, 88, 52, 255), "p": (150, 112, 70, 255)}


def skeleton(ident: str, name: str, author: str, game_version: str) -> dict:
    """The files of a minimal plugin: {rel: bytes}."""
    salt = int.from_bytes(hashlib.sha256(ident.encode("utf-8")).digest()[:4], "big") & 0x7FFFFFFF
    manifest = {"plugin_format": PLUGIN_FORMAT, "api_version": API_VERSION, "id": ident, "name": name,
                "version": "0.1.0"}
    if game_version:
        manifest["minimum_game_version"] = game_version
    manifest.update({
        "authors": [author],
        "license": "Name the license of your plugin here, and put its text in LICENSE.txt.",
        "description": "One line for the plugin list: what awaits the hero on this island.",
        "learning_note": "",
        "requires": {"card_packs": []},
        "region": {"title": name[:MAX_NAME], "castle_name": "The Old Keep", "salt": salt, "mana_links": False,
                   "palette": "shandalar"},
    })
    world = {
        "generator": "island",
        "layout_version": 1,
        "towns": {"list": [
            {"slot": 1, "name": "Harborwatch", "terrain": 6, "aim": [-9, -8]},
            {"slot": 2, "name": "Mossford", "terrain": 2, "aim": [9, 3]}]},
        "villages": {"names": ["Reedholm", "Tidecross", "Stonebrook"], "count": [2, 3]},
        "dungeon": {"name": "The Drowned Cellars"},
    }
    places = {
        "pictures": {},
        "voyage": {"arrive_clues": [{"text": "voyage.arrive", "quest": True}],
                   "out_log": "voyage.out", "home_log": "voyage.home"},
        "markers": {
            "port": {
                "name": "Island Harbor", "mainland_name": "Island Ferry", "picture": "visit_city",
                "sprite": {"file": "art/%s_port_map.png" % ident, "width": 96},
                "panes": [
                    {"when": [{"on_region": True}], "lines": ["port.island", {"show": "pending"}],
                     "actions": [{"do": "sail", "label": "port.sail_home"}, {"do": "leave", "label": "port.leave"}]},
                    {"lines": ["port.mainland"],
                     "actions": [{"do": "sail", "label": "port.sail_out"}, {"do": "leave", "label": "port.leave"}]}]},
            "castle": {
                "name": "The Old Keep", "picture": "visit_castle_black",
                "sprite": {"file": "art/%s_castle_map.png" % ident, "width": 112},
                "banner": {"flag": "freed", "color": "e0bc60"},
                "panes": [
                    {"when": [{"flag": "freed"}], "lines": ["castle.freed"],
                     "actions": [{"do": "leave", "label": "castle.leave"}]},
                    {"lines": ["castle.intro", "castle.count"],
                     "actions": [{"do": "boss", "label": "castle.challenge"}, {"do": "leave", "label": "castle.leave"}]}]},
        },
    }
    quests = {
        "flags": ["freed"],
        "errands_off": [1],
        "town": {"line": "town.petition", "action": "town.hear", "thanks": "town.thanks"},
        "quests": [{
            "giver": 1, "title": "quest.lantern.title", "petition": "quest.lantern.petition",
            "epilogue": "quest.lantern.epilogue", "banner": "6a9c57", "foe": "smuggler",
            "steps": [
                {"do": "accept"},
                {"do": "go", "to": {"site": 2}, "action": "quest.lantern.ask", "guidance": "quest.lantern.guide",
                 "task": "quest.lantern.task", "line": "quest.lantern.line"},
                {"do": "duel", "at": "giver"}],
            "complete": [{"gold": 30}, {"food": 4}, {"refresh_appearance": True},
                         {"log_event": {"event": "quest", "text": "quest.done_log", "done": True}}],
        }],
        "finale": {
            "at": "castle", "foe": "warden",
            "conditions": [{"quests_done": "all"}, {"not_flag": "freed"}],
            "effects": [{"set_flag": "freed"}, {"refresh_appearance": True},
                        {"log_event": {"event": "freed", "text": "finale.log"}}],
            "done_flag": "freed", "won": "finale.won", "already": "finale.already", "unmet": "finale.unmet"},
        "targets": {"after_quests": "castle", "after_finale": "port"},
        "status": ["status.quests", {"text": "status.freed", "when": [{"flag": "freed"}]}],
        "tasks": {"finale": {"title": "task.finale.title", "text": "task.finale.text", "done": "task.finale.done"},
                  "rewards": {"title": "task.rewards.title", "text": "task.rewards.text", "done": "task.rewards.done"}},
        "talk": {"news": [{"text": "talk.news.freed", "when": [{"flag": "freed"}]}, "talk.news"],
                 "tales": [{"title": "tale.keep.title", "text": "tale.keep"}]},
    }
    foes = {"foes": {
        "smuggler": {"name": "The Lantern Smuggler", "life": 16, "face": 32, "deck": {
            "Mountain": 17, "Mons's Goblin Raiders": 4, "Goblin Balloon Brigade": 3, "Gray Ogre": 4, "Hill Giant": 3,
            "Dwarven Warriors": 2, "Lightning Bolt": 4, "Shatter": 1, "Firebreathing": 2}},
        "warden": {"name": "The Warden of the Old Keep", "deck_name": "The Old Keep", "life": 22, "face": 6, "deck": {
            "Swamp": 17, "Scathe Zombies": 4, "Black Knight": 3, "Bog Wraith": 3, "Hypnotic Specter": 2,
            "Sengir Vampire": 1, "Dark Ritual": 3, "Terror": 3, "Drain Life": 2, "Unholy Strength": 2}},
    }}
    text = {
        "region.subtitle": name[:MAX_TEXT],
        "voyage.arrive": "The harbor master waves you ashore. A lantern-keeper in Harborwatch is asking for help.",
        "voyage.out": "Sailed to the island.",
        "voyage.home": "Returned to Shandalar's mainland.",
        "port.sail_out": "Sail to the island",
        "port.sail_home": "Sail home to Shandalar",
        "port.leave": "Leave the harbor",
        "port.island": "The ferry waits to take you home. Your work here keeps until you return.",
        "port.mainland": "A small ferry crosses to a quiet island. The passage is free both ways.",
        "castle.leave": "Leave",
        "castle.challenge": "Challenge the Warden",
        "castle.intro": "The Warden of the Old Keep holds the island's roads. Help its people first.",
        "castle.count": "Quests done: {pledges} of {quests_total}.",
        "castle.freed": "The Old Keep stands open. The island's roads are free.",
        "town.petition": "The lantern-keeper of {town} has a request.",
        "town.hear": "Hear the request",
        "town.thanks": "Visit the lantern-keeper",
        "quest.lantern.title": "The Harbor Lantern",
        "quest.lantern.petition": "Smugglers stole the harbor lantern. Ask in Mossford where they went, then come back and face their leader.",
        "quest.lantern.epilogue": "The lantern burns again over Harborwatch. Ships find the harbor at night.",
        "quest.lantern.ask": "Ask about the smugglers",
        "quest.lantern.guide": "{title}: ask in {target} about the smugglers.",
        "quest.lantern.task": "Ask in {target} about the smugglers.",
        "quest.lantern.line": "Fishers here saw the smugglers' boat. Their leader waits near Harborwatch.",
        "finale.won": "The Warden is beaten. The Old Keep opens its gates.",
        "finale.already": "The Old Keep is already free.",
        "finale.unmet": "Finish every quest on the island before you challenge the Warden.",
        "finale.log": "Freed the Old Keep.",
        "status.quests": "Island quests: {pledges} of {quests_total}.",
        "status.freed": "The Old Keep is free.",
        "task.finale.title": "The Old Keep",
        "task.finale.text": "Challenge the Warden of the Old Keep.",
        "task.finale.done": "The Old Keep is free.",
        "task.rewards.title": "Island rewards",
        "task.rewards.text": "Collect the island's reward cards.",
        "task.rewards.done": "No rewards are waiting.",
        "talk.news": "They say the Warden of the Old Keep taxes every road on the island.",
        "talk.news.freed": "They say the island's roads are free again.",
        "tale.keep.title": "The Old Keep",
        "tale.keep": "The keep was built to guard the harbor. Its last lord never left it.",
    }
    readme = ("%s\n%s\n\nAn adventure plugin for Shandalar, made with tools/adventure_plugin.py new.\n\n"
              "Edit the JSON files, then check and package the plugin:\n"
              "    python3 tools/adventure_plugin.py validate %s\n"
              "    python3 tools/adventure_plugin.py export %s --out dist\n"
              "Put the zip (or this folder) in the game's expanded_adventure/ folder and tick it\n"
              "in the Embark window's plugin list. The guide in expanded_adventure/GUIDE/\n"
              "explains every file and field.\n") % (name, "=" * min(len(name), 72), ident, ident)

    def encode(value) -> bytes:
        return (json.dumps(value, indent="\t", ensure_ascii=False) + "\n").encode("utf-8")

    if not manifest["learning_note"]:
        del manifest["learning_note"]
    return {
        "plugin.json": encode(manifest), "world.json": encode(world), "places.json": encode(places),
        "quests.json": encode(quests), "foes.json": encode(foes), "text.json": encode(text),
        "README.txt": readme.encode("utf-8"),
        "art/%s_port_map.png" % ident: _sprite(PORT_ROWS, SPRITE_COLORS),
        "art/%s_castle_map.png" % ident: _sprite(CASTLE_ROWS, SPRITE_COLORS),
    }


def command_new(args, game: Game) -> int:
    folder = Path(args.folder)
    if not valid_id(args.id):
        raise UsageError("--id must be 1 to 40 lower-case letters, digits or _, a letter first (not \"mainland\").")
    name = strip_edges(args.name)
    if not name or len(name) > MAX_NAME:
        raise UsageError("--name must be non-empty text of at most %d characters." % MAX_NAME)
    author = strip_edges(args.author)
    if not author or len(author) > MAX_NAME:
        raise UsageError("--author must be non-empty text of at most %d characters." % MAX_NAME)
    if folder.exists() and (not folder.is_dir() or any(folder.iterdir())):
        raise UsageError("%s already exists; new writes a new folder." % folder)
    game.schema()   # the plugin is checked once written: no schema, nothing written
    files = skeleton(args.id, name, author, game.version)
    for rel, data in sorted(files.items()):
        target = folder / rel
        target.parent.mkdir(parents=True, exist_ok=True)
        target.write_bytes(data)
    result = judge(str(folder), game)
    print("Made %s: plugin %s, %d files." % (folder, args.id, len(files)))
    for note in result["notes"]:
        print("note: " + note)
    if not result["valid"]:
        for problem in result["problems"]:
            print(problem)
        return 1
    print("Next: edit its JSON files, then\n    python3 tools/adventure_plugin.py validate %s\n"
          "    python3 tools/adventure_plugin.py export %s --out dist" % (folder, folder))
    return 0


# --------------------------------------------------------------------------
# validate, info
# --------------------------------------------------------------------------

def _existing(path: str) -> str:
    if not os.path.lexists(path):
        raise UsageError("%s: no such file or folder." % path)
    return path


def report(result: dict) -> dict:
    manifest = result["manifest"]
    return {"path": result["path"], "valid": result["valid"], "stage": result["stage"],
            "problems": result["problems"], "notes": result["notes"], "kind": result["kind"],
            "id": manifest.get("id") if isinstance(manifest.get("id"), str) else "",
            "name": manifest.get("name") if isinstance(manifest.get("name"), str) else "",
            "version": manifest.get("version") if isinstance(manifest.get("version"), str) else ""}


def command_validate(args, game: Game) -> int:
    result = judge(_existing(args.plugin), game)
    if args.json:
        print(json.dumps(report(result), ensure_ascii=False))
        return 0 if result["valid"] else 1
    for problem in result["problems"]:
        print(problem)
    for note in result["notes"]:
        print("note: " + note, file=sys.stderr)
    if result["valid"]:
        manifest = result["manifest"]
        print("%s: valid (plugin %s %s)." % (args.plugin, manifest["id"], manifest["version"]))
        return 0
    print("%s: refused at the %s stage (%d problem%s)." % (args.plugin, result["stage"], len(result["problems"]),
                                                           "" if len(result["problems"]) == 1 else "s"), file=sys.stderr)
    return 1


def summary(result: dict) -> dict:
    manifest = result["manifest"]
    files = result["files"]
    kinds = {"json": 0, "text": 0, "pictures": 0, "music": 0}
    for rel in files:
        extension = get_extension(rel).lower()
        kinds["json" if extension == "json" else "pictures" if extension in PICTURES
              else "music" if extension == "ogg" else "text"] += 1
    out = {"path": result["path"], "kind": result["kind"], "valid": result["valid"], "stage": result["stage"],
           "problems": result["problems"], "notes": result["notes"],
           "manifest": {key: _plain(manifest[key]) for key in FIELDS if key in manifest and key != "files"},
           "hashes": len(manifest.get("files", {})) if isinstance(manifest.get("files"), dict) else 0,
           "files": len(files), "bytes": sum(len(b) for b in files.values()), "by_kind": kinds}
    data = result["data"]
    if data:
        out["content"] = {"towns": len(data["world"]["towns"]["list"]), "places": len(data["world"]["places"]["list"]),
                          "villages": data["world"]["villages"]["count"], "quests": len(data["quests"]["quests"]),
                          "flags": data["quests"]["flags"], "foes": len(data["foes"]["foes"]),
                          "reward_bundles": len(data["rewards"]["bundles"]), "texts": len(data["text"]),
                          "music": data["world"].get("music", "")}
    return out


def command_info(args, game: Game) -> int:
    facts = summary(judge(_existing(args.plugin), game))
    if args.json:
        print(json.dumps(facts, ensure_ascii=False, indent="\t"))
        return 0 if facts["valid"] else 1
    manifest = facts["manifest"]
    lines = ["%s (%s)" % (facts["path"], facts["kind"])]
    for key in ("id", "name", "version", "api_version", "minimum_game_version", "description", "learning_note",
                "license"):
        if key in manifest:
            lines.append("  %-21s %s" % (key + ":", _plain(manifest[key])))
    if isinstance(manifest.get("authors"), list):
        lines.append("  %-21s %s" % ("authors:", ", ".join(str(a) for a in manifest["authors"])))
    packs = packs_of(manifest)
    lines.append("  %-21s %s" % ("card packs needed:", ", ".join(packs) if packs else "none"))
    if isinstance(manifest.get("region"), dict):
        lines.append("  %-21s %s" % ("region:", manifest["region"].get("title", "")))
    by = facts["by_kind"]
    lines.append("  %-21s %d (%d JSON, %d text, %d pictures, %d music), %s; %s" % (
        "files:", facts["files"], by["json"], by["text"], by["pictures"], by["music"], _bytes_text(facts["bytes"]),
        "%d hashed in plugin.json" % facts["hashes"] if facts["hashes"] else "no files list (a folder in the works)"))
    if "content" in facts:
        c = facts["content"]
        lines.append("  %-21s %d towns, %d places, %d-%d villages; %d quests; %d foes; %d reward bundles; %d texts%s" % (
            "content:", c["towns"], c["places"], c["villages"][0], c["villages"][1], c["quests"], c["foes"],
            c["reward_bundles"], c["texts"], "; music " + c["music"] if c["music"] else ""))
    lines.append("  %-21s %s" % ("verdict:", "valid" if facts["valid"] else "refused at the %s stage" % facts["stage"]))
    for problem in facts["problems"]:
        lines.append("    " + problem)
    for note in facts["notes"]:
        lines.append("  note: " + note)
    print("\n".join(lines))
    return 0 if facts["valid"] else 1


# --------------------------------------------------------------------------
# export — the deterministic zip
# --------------------------------------------------------------------------

## Every entry's time in an exported zip (a fixed one: the same folder makes the same bytes).
ZIP_TIME = (2026, 1, 1, 0, 0, 0)


def export_bytes(folder: str, game: Game) -> tuple[bytes, str, dict]:
    """The zip of plugin [folder]: (bytes, its top folder's name, the judgement of the folder)."""
    result = judge(folder, game, drop_files_list=True)
    if not result["valid"]:
        return b"", "", result
    top = Path(folder).resolve().name
    files = result["files"]
    manifest = parse_json(utf8_string(files[MANIFEST]).lstrip("\ufeff"), ints=True)[0]
    manifest.pop("files", None)
    manifest["files"] = {rel: sha256(files[rel]) for rel in sorted(files) if rel != MANIFEST}
    entries = dict(files)
    entries[MANIFEST] = (json.dumps(manifest, indent="\t", ensure_ascii=False) + "\n").encode("utf-8")
    buffer = io.BytesIO()
    with zipfile.ZipFile(buffer, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
        for rel in sorted(entries):
            info = zipfile.ZipInfo(top + "/" + rel, ZIP_TIME)
            info.create_system = 3
            info.external_attr = 0o100644 << 16
            info.compress_type = zipfile.ZIP_DEFLATED
            archive.writestr(info, entries[rel], compress_type=zipfile.ZIP_DEFLATED, compresslevel=9)
    return buffer.getvalue(), top, result


def command_export(args, game: Game) -> int:
    folder = _existing(args.folder)
    if not os.path.isdir(folder):
        raise UsageError("%s: export packages a plugin folder (a zip is already packaged)." % folder)
    data, top, result = export_bytes(folder, game)
    for note in result["notes"]:
        print("note: " + note, file=sys.stderr)
    if not data:
        for problem in result["problems"]:
            print(problem)
        print("%s: not exported; it is refused at the %s stage." % (folder, result["stage"]), file=sys.stderr)
        return 1
    out = Path(args.out if args.out else "dist")
    if out.exists() and not out.is_dir():
        raise UsageError("--out %s is not a folder." % out)
    source = Path(folder).resolve()
    target = out.resolve() / (top + ".zip")
    if source in target.parents:
        raise UsageError("--out must be outside the plugin folder: a zip inside it would be refused.")
    if target.parent == source.parent:
        raise UsageError("--out %s holds %s itself: in a plugins folder the game reads the zip first and passes "
                         "over the folder you are editing (one id, the first copy wins). Name another folder, "
                         "like --out dist." % (out, source.name))
    out.mkdir(parents=True, exist_ok=True)
    handle, temporary = tempfile.mkstemp(prefix="." + top + ".", suffix=".part", dir=str(out))
    try:
        with os.fdopen(handle, "wb") as sink:
            sink.write(data)
        os.chmod(temporary, 0o644)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)
    check = judge(str(target), game)
    if not check["valid"]:
        for problem in check["problems"]:
            print(problem)
        target.unlink()
        print("%s: the exported zip was refused; nothing was written." % folder, file=sys.stderr)
        return 1
    print("%s  %s (%s, %d files)" % (sha256(data), target, _bytes_text(len(data)), len(check["files"])))
    return 0


# --------------------------------------------------------------------------
# compat — what a new version does to old saves
# --------------------------------------------------------------------------

## The world.json fields the island generator reads (every one, but the music).
RECIPE_FIELDS = ["generator", "layout_version", "side", "offset", "step", "slot_start", "dice_salt", "spacing",
                 "castle", "port", "towns", "places", "villages", "trade", "world_magic", "roads", "dungeon"]


def compatibility(old: dict, new: dict) -> tuple[list, list]:
    """(warnings, notes) for saves made with plugin [old] (normalized data) under [new]."""
    warnings, notes = [], []
    if old["id"] != new["id"]:
        warnings.append("The id changed (%s -> %s): saves name the plugin by its id, so to them the new version is "
                        "another plugin and the old one is missing." % (old["id"], new["id"]))
    # A town is a site a visited island must have (the schema's
    # required_sites); a place, never required, is a note.
    for part in ("towns", "places"):
        said = warnings if part == "towns" else notes
        before = {int(row["slot"]): row["name"] for row in old["world"][part]["list"]}
        after = {int(row["slot"]): row["name"] for row in new["world"][part]["list"]}
        by_name = {name: slot for slot, name in after.items()}
        for slot, name in sorted(before.items()):
            if slot not in after:
                moved = by_name.get(name)
                if moved is not None:
                    said.append("world.json %s: %s moved from slot %d to slot %d: saved quests and visited "
                                    "islands know it by its slot." % (part, name, slot, moved))
                else:
                    said.append("world.json %s: slot %d (%s) was removed: saved quests and visited islands "
                                    "still point at it." % (part, slot, name))
        for slot, name in sorted(after.items()):
            if slot not in before and name not in before.values():
                said.append("world.json %s: slot %d (%s) was added: a visited island keeps its sites as saved "
                                "and has no such %s." % (part, slot, name, part[:-1]))
    old_quests, new_quests = old["quests"]["quests"], new["quests"]["quests"]

    def identity(quest: dict) -> tuple:
        return int(quest["giver"]), str(quest["title"])

    def title(quest: dict, words: dict) -> str:
        return str(words.get(quest["title"], quest["title"]))

    new_ids = [identity(q) for q in new_quests]
    for index, quest in enumerate(old_quests):
        mine = identity(quest)
        if index < len(new_quests) and new_ids[index] == mine:
            steps_old, steps_new = len(quest["steps"]), len(new_quests[index]["steps"])
            if steps_new < steps_old:
                warnings.append("quests.json quests[%d] (%s): its steps were shortened from %d to %d; a save "
                                "partway through it holds a stage the new version does not have."
                                % (index, title(quest, old["text"]), steps_old, steps_new))
            elif [s["do"] for s in quest["steps"]] != [s["do"] for s in new_quests[index]["steps"][:steps_old]]:
                notes.append("quests.json quests[%d] (%s): its steps changed kind; a saved stage now means the "
                             "new step at that place." % (index, title(quest, old["text"])))
        elif mine in new_ids:
            warnings.append("quests.json quests[%d] (%s) moved to quests[%d]: saves record quests by their place in "
                            "the list." % (index, title(quest, old["text"]), new_ids.index(mine)))
        else:
            warnings.append("quests.json quests[%d] (%s) was removed or replaced: saves record quests by their "
                            "place in the list." % (index, title(quest, old["text"])))
    finale_all = any(c.get("quests_done") == "all" for c in new["quests"]["finale"]["conditions"])
    if len(new_quests) > len(old_quests) and finale_all:
        warnings.append("quests.json: %d quest%s appended while the finale needs every quest: a save that already "
                        "won the finale holds %s with a quest open, and the game holds that land, its ships not "
                        "sailing, until the old version is back." % (len(new_quests) - len(old_quests), "" if len(new_quests) - len(old_quests) == 1
                                      else "s", new["quests"]["finale"]["done_flag"]))
    for flag in old["quests"]["flags"]:
        if flag not in new["quests"]["flags"]:
            notes.append("quests.json flags: %s was renamed or removed: old saves keep its value under the old name, "
                         "and the new version starts without it." % flag)
    if list(old["places"]["markers"]) != list(new["places"]["markers"]):
        warnings.append("places.json markers changed (%s -> %s)." % (", ".join(old["places"]["markers"]),
                                                                    ", ".join(new["places"]["markers"])))
    changed = [key for key in RECIPE_FIELDS if old["world"].get(key) != new["world"].get(key)]
    old_salt = old["manifest"].get("region", {}).get("salt", 0)
    new_salt = new["manifest"].get("region", {}).get("salt", 0)
    if old_salt != new_salt:
        changed.append("plugin.json region.salt")
    if changed:
        notes.append("The island recipe changed (%s): every island not visited yet comes out different; a visited "
                     "island is kept as it was saved." % ", ".join(changed))
    return warnings, notes


def command_compat(args, game: Game) -> int:
    old = judge(_existing(args.old), game)
    new = judge(_existing(args.new), game)
    refused = False
    for label, result in (("old", old), ("new", new)):
        if not result["valid"]:
            print("The %s plugin %s is refused at the %s stage: %s" % (label, result["path"], result["stage"],
                                                                   result["problems"][0]))
            refused = True
    if refused:
        return 1
    warnings, notes = compatibility(old["data"], new["data"])
    for line in warnings:
        print(line)
    for line in notes:
        print("note: " + line)
    if warnings:
        print("%d change%s make%s saves of %s %s unusable with %s %s." % (
            len(warnings), "" if len(warnings) == 1 else "s", "s" if len(warnings) == 1 else "", old["data"]["id"],
            old["manifest"]["version"], new["data"]["id"], new["manifest"]["version"]))
        return 1
    print("Compatible: saves made with %s %s keep working with %s." % (old["data"]["id"], old["manifest"]["version"],
                                                                       new["manifest"]["version"]))
    return 0


# --------------------------------------------------------------------------
# guide — GUIDE/reference.html from schema_v1.json
# --------------------------------------------------------------------------

def _e(text) -> str:
    return html.escape(str(text), quote=True)


def _code(value) -> str:
    return "<code>%s</code>" % _e(json.dumps(_plain(value), ensure_ascii=False))


def _plain(value):
    """A schema value as an author writes it: whole numbers without .0."""
    if isinstance(value, float) and value == int(value):
        return int(value)
    if isinstance(value, list):
        return [_plain(v) for v in value]
    if isinstance(value, dict):
        return {k: _plain(v) for k, v in value.items()}
    return value




class Reference:
    """The reference page's HTML, from the schema."""

    def __init__(self, schema: dict):
        self.schema = schema
        self.types = schema["types"]

    def kind(self, spec: dict) -> str:
        kind = spec.get("kind", "")
        if kind == "ref":
            return '<a class="kind" href="#type-%s">%s</a>' % (_e(spec["type"]), _e(spec["type"]))
        if kind == "array":
            return '<span class="kind">list of</span> ' + self.kind(spec["items"])
        if kind == "map":
            return '<span class="kind">map</span> %s → %s' % (self.kind(spec["keys"]), self.kind(spec["values"]))
        if kind == "oneof":
            return '<span class="kind">one of</span> ' + " | ".join(self.kind(o) for o in spec["options"])
        return '<span class="kind">%s</span>' % _e(kind)

    def resolved(self, spec: dict) -> dict:
        """A ref's named type (and its type's, on through), else [spec]."""
        seen = 0
        while spec.get("kind") == "ref" and seen < 8 and isinstance(self.types.get(spec.get("type")), dict):
            spec = self.types[spec["type"]]
            seen += 1
        return spec

    def limits(self, spec: dict) -> str:
        if spec.get("kind") == "ref":
            named = self.resolved(spec)
            return self.limits(named) if named.get("kind") not in ("object", "single", "oneof", "ref") else "—"
        if spec.get("kind") == "oneof":
            told = [self.limits(o) for o in spec["options"]]
            return " or ".join(told) if any(x != "—" for x in told) else "—"
        kind = spec.get("kind", "")
        parts = []
        low, high = spec.get("min"), spec.get("max")
        if kind in ("int", "number"):
            if low is not None and high is not None:
                parts.append("%s to %s" % (fmt_num(low), fmt_num(high)))
            elif low is not None:
                parts.append("at least %s" % fmt_num(low))
            elif high is not None:
                parts.append("at most %s" % fmt_num(high))
        elif kind in ("array", "map"):
            if low is not None and int(low) > 0:
                parts.append("%s to %s entries" % (fmt_num(low), fmt_num(high if high is not None else 512)))
            else:
                parts.append("up to %s entries" % fmt_num(high if high is not None else 512))
        elif kind in ("string", "text", "card", "file", "picture"):
            if high is not None:
                parts.append("%s to %s characters" % (fmt_num(low if low is not None else (0 if kind == "string" else 1)),
                                                      fmt_num(high)))
            if kind == "file":
                parts.append("%s in the plugin" % ", ".join(self.schema["extensions"].get(spec.get("class", ""),
                                                                                         self.schema["extensions"]["allowed"])))
            if kind == "text":
                parts.append("a key of text.json")
            if kind == "picture":
                parts.append("a places.json picture key or a skin picture")
            if kind == "card":
                parts.append("base game or a required pack")
        elif kind == "enum":
            parts.append('<ul class="chips">%s</ul>' % "".join("<li>%s</li>" % _code(v) for v in spec["values"]))
        if "pattern" in spec:
            parts.append("matches <code>%s</code>" % _e(spec["pattern"]))
        return "; ".join(p if p.startswith("<ul") else _e(p) if "<code>" not in p else p for p in parts) or "—"

    ## A default longer than this is given in the explanation instead (a
    ## code in a table cell does not wrap).
    SHORT_DEFAULT = 16

    def requirement(self, spec: dict) -> tuple[str, str]:
        """The Required / default cell, and what the explanation adds."""
        if spec.get("required", False):
            return '<span class="req">required</span>', ""
        if "default" in spec:
            shown = json.dumps(_plain(spec["default"]), ensure_ascii=False)
            if len(shown) <= self.SHORT_DEFAULT:
                return '<span class="def">%s</span>' % _code(spec["default"]), ""
            return "optional", " Default: %s." % _code(spec["default"])
        return "optional", ""

    def rows(self, fields: dict, prefix: str = "", columns: int = 5) -> list:
        out = []
        for name, spec in fields.items():
            label = prefix + name
            cell, more = self.requirement(spec)
            doc = spec.get("doc", "") or self.resolved(spec).get("doc", "")
            if columns == 4:
                limits = self.limits(spec)
                both = cell if limits == "—" else limits if cell == "optional" else cell + "; " + limits
                out.append("<tr><td data-label=\"Key\"><code>%s</code></td><td data-label=\"Value\">%s</td>"
                           "<td data-label=\"Limits\">%s</td><td class=\"doc\" data-label=\"What it does\">%s%s</td></tr>"
                           % (_e(label), self.kind(spec), both, _e(doc), more))
            else:
                out.append("<tr><td data-label=\"Field\"><code>%s</code></td><td data-label=\"Kind\">%s</td>"
                           "<td data-label=\"Required / default\">%s</td><td data-label=\"Limits\">%s</td>"
                           "<td class=\"doc\" data-label=\"What it is\">%s%s</td></tr>"
                           % (_e(label), self.kind(spec), cell, self.limits(spec), _e(doc), more))
            inner = spec
            while inner.get("kind") == "array" and isinstance(inner.get("items"), dict):
                inner = inner["items"]
                label += "[]"
            if inner.get("kind") == "object" and inner.get("fields"):
                out.extend(self.rows(inner["fields"], label + ".", columns))
        return out

    def table(self, fields: dict) -> str:
        return ('<div class="table-wrap"><table class="fields"><thead><tr><th>Field</th><th>Kind</th>'
                '<th>Required / default</th><th>Limits</th><th>What it is</th></tr></thead><tbody>\n%s\n'
                '</tbody></table></div>' % "\n".join(self.rows(fields)))

    def type_body(self, name: str, spec: dict) -> str:
        kind = spec.get("kind", "")
        parts = []
        if spec.get("doc"):
            parts.append("<p>%s</p>" % _e(spec["doc"]))
        if kind == "object":
            parts.append(self.table(spec.get("fields", {})))
        elif kind == "single":
            parts.append("<p>An object with exactly one of these keys:</p>")
            rows = []
            for key, option in spec["options"].items():
                rows.append("<tr><td data-label=\"Key\"><code>%s</code></td><td data-label=\"Value\">%s</td>"
                            "<td data-label=\"Limits\">%s</td><td class=\"doc\" data-label=\"What it does\">%s</td></tr>"
                            % (_e(key), self.kind(option), self.limits(option), _e(option.get("doc", ""))))
                if option.get("kind") == "object":
                    rows.extend(self.rows(option.get("fields", {}), key + ".", 4))
            parts.append('<div class="table-wrap"><table class="fields"><thead><tr><th>Key</th><th>Value</th>'
                         '<th>Limits</th><th>What it does</th></tr></thead><tbody>\n%s\n</tbody></table></div>'
                         % "\n".join(rows))
        elif kind == "oneof":
            items = []
            for option in spec["options"]:
                if option.get("kind") == "object":
                    items.append("<li>an object: %s</li>" % ", ".join(
                        "<code>%s</code>%s" % (_e(k), " (required)" if f.get("required") else "")
                        for k, f in option.get("fields", {}).items()))
                else:
                    items.append("<li>%s %s</li>" % (self.kind(option), self.limits(option)
                                                     if self.limits(option) != "—" else ""))
            parts.append("<p>Any one of these forms:</p><ul>%s</ul>" % "".join(items))
            for option in spec["options"]:
                if option.get("kind") == "object":
                    parts.append(self.table(option.get("fields", {})))
        else:
            parts.append('<dl class="limits"><dt>Kind</dt><dd>%s</dd><dt>Limits</dt><dd>%s</dd></dl>'
                         % (self.kind(spec), self.limits(spec)))
        return "\n".join(parts)

    def page(self, masthead: str, toc: str) -> str:
        schema = self.schema
        limits = schema["limits"]
        files = schema["files"]
        mini = ['<li><a href="#manifest">plugin.json</a></li>']
        mini += ['<li><a href="#file-%s">%s</a></li>' % (_e(n.replace(".", "-")), _e(n)) for n in files]
        mini += ['<li><a href="#types">Named types</a></li>', '<li><a href="#type-condition">Conditions</a></li>',
                 '<li><a href="#type-effect">Effects</a></li>', '<li><a href="#placeholders">Placeholders</a></li>',
                 '<li><a href="#text-defaults">Built-in texts</a></li>', '<li><a href="#limits">Limits</a></li>',
                 '<li><a href="#extensions">Files allowed</a></li>', '<li><a href="#skin-pictures">Skin pictures</a></li>']
        body = []
        body.append('<h1>Reference</h1>')
        body.append('<p class="lede">Every file, field, kind, limit, condition, effect and placeholder of adventure '
                    'plugin API %d, as the game reads it. The game and the authoring tool read the same schema, so '
                    'what this page says is what <code>validate</code> checks.</p>' % int(schema["api_version"]))
        body.append('<p class="generated">Written by <code>tools/adventure_plugin.py guide</code> from '
                    '<code>game/adventure/plugins/schema_v1.json</code>.</p>')
        body.append('<nav class="mini-toc" aria-label="On this page"><ol>%s</ol></nav>' % "".join(mini))
        body.append(self.manifest_section())
        for name, rule in files.items():
            spec = self.types[rule["type"]]
            anchor = "file-" + name.replace(".", "-")
            body.append('<section class="ref-file" id="%s-section">' % _e(anchor))
            body.append('<h2 id="%s">%s</h2>' % (_e(anchor), _e(name)))
            body.append("<p>%s %s Its shape is the type <a class=\"kind\" href=\"#type-%s\">%s</a>.</p>" % (
                _e(rule.get("doc", "")), "Required." if rule.get("required") else "Optional.",
                _e(rule["type"]), _e(rule["type"])))
            if spec.get("kind") == "object":
                body.append(self.table(spec.get("fields", {})))
            elif spec.get("kind") == "map":
                body.append('<dl class="limits"><dt>Keys</dt><dd>%s</dd><dt>Values</dt><dd>%s</dd>'
                            '<dt>Entries</dt><dd>%s</dd></dl>' % (self.limits(spec["keys"]), self.limits(spec["values"]),
                                                                  self.limits(spec)))
            body.append("</section>")
        body.append('<section id="types"><h2>Named types</h2><p>The types the files above name, in the schema\'s '
                    'order. A field whose kind links here takes that type\'s shape.</p>')
        for name, spec in self.types.items():
            body.append('<section class="ref-type"><h3 id="type-%s">%s</h3>\n%s\n</section>' % (
                _e(name), _e(name), self.type_body(name, spec)))
        body.append("</section>")
        body.append('<section id="placeholders"><h2>Placeholders</h2><p>A text of text.json may hold these, in '
                    'braces; the game fills them in. Any other <code>{word}</code> refuses the plugin.</p>'
                    '<div class="table-wrap"><table class="fields"><thead><tr><th>Placeholder</th><th>What it says'
                    '</th></tr></thead><tbody>%s</tbody></table></div></section>' % "".join(
                        "<tr><td data-label=\"Placeholder\"><code>{%s}</code></td><td class=\"doc\" data-label=\"What it says\">%s</td></tr>" % (_e(k), _e(v))
                        for k, v in schema["placeholders"].items()))
        body.append('<section id="text-defaults"><h2>Built-in texts</h2><p>The game\'s own words for these text '
                    'keys. A plugin may use the key without writing it in text.json; writing it replaces the '
                    'default.</p><div class="table-wrap"><table class="fields"><thead><tr><th>Key</th><th>Default'
                    '</th></tr></thead><tbody>%s</tbody></table></div></section>' % "".join(
                        "<tr><td data-label=\"Key\"><code>%s</code></td><td class=\"doc\" data-label=\"Default\">%s</td></tr>" % (_e(k), _e(v) if v else "<em>(empty)</em>")
                        for k, v in TEXT_DEFAULTS.items()))
        names = {"plugin_bytes": "A plugin, in all", "files": "Files in a plugin", "json_bytes": "A JSON or text file",
                 "json_depth": "JSON nesting", "picture_side": "A picture's side", "ogg_bytes": "An OGG file",
                 "text_chars": "A text", "id_pattern": "An id", "reserved_ids": "Ids never allowed",
                 "path_chars": "A path inside the plugin"}

        def limit_value(key, value):
            if key.endswith("_bytes"):
                return "%s (%d bytes)" % (_bytes_text(int(value)), int(value))
            if key == "picture_side":
                return "%d pixels" % int(value)
            if key in ("text_chars", "path_chars"):
                return "%d characters" % int(value)
            if key == "json_depth":
                return "%d levels" % int(value)
            if key == "files":
                return "%d" % int(value)
            if isinstance(value, list):
                return ", ".join(str(v) for v in value)
            return str(value)

        body.append('<section id="limits"><h2>Limits</h2><dl class="limits">%s<dt>Folders in an unpacked plugin</dt>'
                    '<dd>%d</dd><dt>Manifest name, region title, castle name, an author</dt><dd>%d characters</dd>'
                    '<dt>Manifest description</dt><dd>%d characters</dd><dt>Authors</dt><dd>%d</dd>'
                    '<dt>Card packs required</dt><dd>%d</dd></dl></section>' % (
                        "".join("<dt>%s</dt><dd>%s</dd>" % (_e(names.get(k, k)), _e(limit_value(k, v)))
                                for k, v in limits.items()), MAX_FOLDERS, MAX_NAME, MAX_LINE, MAX_AUTHORS, MAX_PACKS))
        body.append('<section id="extensions"><h2>Files allowed</h2><p>Only these kinds of file, by extension '
                    '(letter case ignored). Any other file refuses the plugin; a picture\'s first bytes must say '
                    'what its extension says, and an OGG must be Ogg Vorbis. The litter other systems leave is '
                    'passed over: names beginning with <code>.</code>, <code>__MACOSX</code>, '
                    '<code>Thumbs.db</code>, <code>desktop.ini</code>.</p><ul class="chips">%s</ul></section>'
                    % "".join("<li><code>%s</code></li>" % _e(x) for x in schema["extensions"]["allowed"]))
        body.append('<section id="skin-pictures"><h2>Skin pictures</h2><p>A picture key may name one of the game '
                    'skin\'s own pictures instead of a picture of the plugin.</p><ul class="chips">%s</ul></section>'
                    % "".join("<li><code>%s</code></li>" % _e(x) for x in schema["skin_pictures"]))
        pager = ('<footer class="pager"><a class="prev" href="refuge.html"><span>Previous</span>The Refuge walkthrough'
                 '</a><a class="next" href="faq.html"><span>Next</span>FAQ</a></footer>')
        return ("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" "
                "content=\"width=device-width, initial-scale=1\">\n<title>Reference · Adventure plugin guide</title>\n"
                "<link rel=\"stylesheet\" href=\"guide.css\">\n</head>\n<body>\n<!-- guide:masthead -->\n%s\n"
                "<!-- /guide:masthead -->\n<div class=\"layout\">\n<!-- guide:toc -->\n%s\n<!-- /guide:toc -->\n"
                "<main class=\"page\" id=\"top\">\n%s\n</main>\n</div>\n%s\n</body>\n</html>\n"
                % (masthead, toc, "\n".join(body), pager))

    def manifest_section(self) -> str:
        rows = [
            ("plugin_format", "int", True, "", "always %d" % PLUGIN_FORMAT, "The manifest's own format."),
            ("api_version", "int", True, "", "from 1; this game reads API %d" % API_VERSION,
             "The plugin API it is written for; a newer one than the game reads refuses it."),
            ("id", "string", True, "", "matches %s; never %s" % (ID_PATTERN, ", ".join(RESERVED_IDS)),
             "The plugin's identity: saves name it, picture keys begin with it. Never change it."),
            ("name", "string", True, "", "1 to %d characters" % MAX_NAME, "The name in the plugin list."),
            ("version", "string", True, "", "1 to 4 numbers joined by dots", "The plugin's version, like 1.0.0."),
            ("minimum_game_version", "string", False, "", "numbers and dots",
             "The oldest game version that reads it; an older game refuses it."),
            ("authors", "list of string", True, "", "1 to %d names, each up to %d characters" % (MAX_AUTHORS, MAX_NAME),
             "Who made it."),
            ("license", "string", False, "", "up to %d characters" % MAX_TEXT, "Its license, in a few words."),
            ("description", "string", True, "", "up to %d characters" % MAX_LINE, "One line for the plugin list."),
            ("learning_note", "string", False, "", "up to %d characters" % MAX_TEXT,
             "A dimmer line under the description (the prototype says it is a learning demo)."),
            ("requires", "object", False, "", "card_packs: up to %d of {\"id\": \"pack-N\", \"min_version\": \"1.0\"}"
             % MAX_PACKS, "The card packs it needs; never Pack 1. A plugin never withholds or unlocks their cards."),
            ("region", "object", True, "", "title (required), castle_name, salt (0 to 2147483647), mana_links, palette",
             "The island: its title, the castle's name, the salt that makes its island its own, whether mana links "
             "work there, its palette (%s, or a palette object)." % ", ".join(PALETTES)),
            ("files", "map", False, "", "file -> 64 lower-case hex digits",
             "Written by export: the SHA-256 of every other file; any change after export refuses the plugin."),
        ]
        def kind(word: str) -> str:
            if word.startswith("list of "):
                return '<span class="kind">list of</span> ' + kind(word[len("list of "):])
            return '<span class="kind">%s</span>' % _e(word)

        body = "\n".join("<tr><td data-label=\"Field\"><code>%s</code></td><td data-label=\"Kind\">%s</td>"
                         "<td data-label=\"Required / default\">%s</td><td data-label=\"Limits\">%s</td>"
                         "<td class=\"doc\" data-label=\"What it is\">%s</td></tr>" % (
                             _e(n), kind(k), '<span class="req">required</span>' if r else "optional", _e(lim), _e(doc))
                         for n, k, r, _, lim, doc in rows)
        return ('<section class="ref-file" id="manifest-section"><h2 id="manifest">plugin.json</h2><p>The manifest. '
                'Any field not listed here refuses the plugin, so a misspelled field is named, not ignored.</p>'
                '<div class="table-wrap"><table class="fields"><thead><tr><th>Field</th><th>Kind</th><th>Required / '
                'default</th><th>Limits</th><th>What it is</th></tr></thead><tbody>\n%s\n</tbody></table></div>'
                '</section>' % body)


def _between(text: str, start: str, end: str) -> str | None:
    at = text.find(start)
    stop = text.find(end, at + len(start)) if at >= 0 else -1
    if at < 0 or stop < 0:
        return None
    return text[at + len(start):stop].strip("\n")


def guide_html(schema: dict, guide_dir: Path) -> str:
    """reference.html, its masthead and toc copied from the guide's index.html."""
    masthead = toc = None
    index = guide_dir / "index.html"
    if index.is_file():
        text = index.read_text(encoding="utf-8")
        masthead = _between(text, "<!-- guide:masthead -->", "<!-- /guide:masthead -->")
        toc = _between(text, "<!-- guide:toc -->", "<!-- /guide:toc -->")
    if masthead is None:
        masthead = '<header class="masthead"><p>Adventure plugin guide</p></header>'
    if toc is None:
        toc = '<nav class="toc" aria-label="Guide pages"><ol>\n%s\n</ol></nav>' % "\n".join(
            '<li><a href="%s">%s</a></li>' % (page, _e(title)) for page, title in GUIDE_PAGES)
    toc = re.sub(r'\s*aria-current="page"', "", toc)
    toc = re.sub(r'(<a\b[^>]*href="reference\.html")', r'\1 aria-current="page"', toc, count=1)
    return Reference(schema).page(masthead, toc)


def command_guide(args, game: Game) -> int:
    schema = game.schema()
    if args.out:
        out = Path(args.out)
    elif game.root is not None:
        out = game.root / FOLDER_NAME / "GUIDE"
    else:
        raise UsageError("Name the guide's folder with --out DIR.")
    page = guide_html(schema, out)
    target = out / "reference.html"
    if args.check:
        current = target.read_text(encoding="utf-8") if target.is_file() else ""
        if current != page:
            print("%s is not what guide writes from the schema now; run: python3 tools/adventure_plugin.py guide"
                  % target)
            return 1
        print("%s is up to date." % target)
        return 0
    out.mkdir(parents=True, exist_ok=True)
    target.write_text(page, encoding="utf-8")
    print("Wrote %s (%d bytes)." % (target, len(page.encode("utf-8"))))
    return 0


# --------------------------------------------------------------------------
# the command line
# --------------------------------------------------------------------------

def version_line(game: Game) -> str:
    return "%s — Shandalar %s (adventure plugin API %d)" % (TOOL, game.version or "version unknown", API_VERSION)


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def parser() -> argparse.ArgumentParser:
    top = _Parser(prog=TOOL, description=__doc__.split("\n\n")[0],
                  epilog="Exit codes: 0 done or valid or compatible; 1 refused or incompatible; 2 a usage error.",
                  formatter_class=argparse.RawDescriptionHelpFormatter)
    top.add_argument("-V", "--version", action="store_true", help="print the game version and plugin API, and exit")
    top.add_argument("--game", metavar="DIR", help="a game checkout or release folder (default: the one around this tool)")
    # --game after the command too (`validate --game DIR PLUGIN`): each
    # command takes it, and only sets it when given.
    common = argparse.ArgumentParser(add_help=False)
    common.add_argument("--game", metavar="DIR", default=argparse.SUPPRESS,
                        help="a game checkout or release folder (default: the one around this tool)")
    commands = top.add_subparsers(dest="command", parser_class=_Parser)
    made = commands.add_parser("new", parents=[common], help="write a minimal plugin that loads and plays")
    made.add_argument("folder")
    made.add_argument("--id", required=True, help="the plugin id: a-z, 0-9 and _, a letter first, up to 40")
    made.add_argument("--name", required=True, help="the name in the plugin list")
    made.add_argument("--author", default="Unnamed author", help="the author's name")
    check = commands.add_parser("validate", parents=[common], help="the game's own checks; problems one per line")
    check.add_argument("plugin", help="a plugin folder or .zip")
    check.add_argument("--json", action="store_true", help="one JSON object on stdout")
    pack = commands.add_parser("export", parents=[common], help="write the plugin's deterministic zip, its files hashed")
    pack.add_argument("folder")
    pack.add_argument("--out", metavar="DIR", help="where the zip goes (default: dist/ in the current folder)")
    about = commands.add_parser("info", parents=[common], help="the manifest and what the plugin holds")
    about.add_argument("plugin")
    about.add_argument("--json", action="store_true")
    compat = commands.add_parser("compat", parents=[common], help="what a new version does to saves made with an old one")
    compat.add_argument("old")
    compat.add_argument("new")
    guide = commands.add_parser("guide", parents=[common], help="write GUIDE/reference.html from the schema")
    guide.add_argument("--out", metavar="DIR", help="the guide's folder (default: expanded_adventure/GUIDE)")
    guide.add_argument("--check", action="store_true", help="exit 1 when reference.html is not up to date")
    return top


def main(argv: list | None = None) -> int:
    argv = sys.argv[1:] if argv is None else argv
    # A plugin's words may hold any character; a console that cannot show
    # one gets an escape, never a crash (a Windows pipe is cp1252).
    for stream in (sys.stdout, sys.stderr):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(errors="backslashreplace")
    try:
        args = parser().parse_args(argv)
        game = find_game(args.game)
        if args.version:
            print(version_line(game))
            return 0
        if args.command is None:
            parser().print_help()
            return 2
        return {"new": command_new, "validate": command_validate, "export": command_export, "info": command_info,
                "compat": command_compat, "guide": command_guide}[args.command](args, game)
    except UsageError as error:
        print("%s: %s" % (TOOL, error), file=sys.stderr)
        if "--json" in argv:
            print(json.dumps({"error": {"tool": TOOL, "exit": 2, "message": str(error)}}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
