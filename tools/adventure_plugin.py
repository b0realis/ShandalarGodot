#!/usr/bin/env python3
"""adventure_plugin.py — make, check and package Shandalar adventure plugins.

An adventure plugin is DATA ONLY: JSON, text, PNG/JPEG/WebP pictures and
Ogg Vorbis music, as a folder or a .zip with one top folder. The game reads
it from its `expanded_adventure/` folder and never runs anything in it.

    adventure_plugin.py new FOLDER --id ID --name NAME [--author NAME] [--kind island|sites]
        a minimal plugin that loads and plays: one quest, two foes, a port
        and a castle with small placeholder map pictures; with --kind
        sites, a sites plugin (API 2) of one place, its pane picture and
        map sprite small placeholders.
    adventure_plugin.py validate PLUGIN [--json]
        the game's own checks, in the game's order: the package, the
        manifest, its files list, the content (card names included); and
        for a sites plugin warnings that never refuse: what loads but is
        not finished, or would surprise its players.
    adventure_plugin.py export FOLDER [--out DIR]
        validate, then write DIR/FOLDER.zip (DIR: dist/ in the current
        folder unless named; never the folder that holds FOLDER, where the
        zip would hide the folder from the game) — deterministic: sorted
        entries, fixed times, one top folder, deflated — with the SHA-256 of
        every file in the zip's plugin.json; the zip is validated again.
    adventure_plugin.py info PLUGIN [--json]
        the manifest and what the plugin holds.
    adventure_plugin.py compat OLD NEW
        every change in NEW that makes saves made with OLD unusable (for a
        sites plugin: every change that loses saved progress).
    adventure_plugin.py add-place FOLDER --id KEY --name NAME [--where mainland,islands]
            [--recipe lore|gift|healer|toll|gambler|riddle|collector|duelist|shop|quest|traveler|teacher]
            [--set NAME=VALUE]...
            [--service effects|copy|none] [--prices 100,200 | --free]
        add a place to a sites plugin folder: with --recipe a whole place
        of that kind, its sentences plain ones to rewrite (--list-recipes
        prints the twelve); with --service one button; its words, a stand-in
        pane picture and map sprite.
    adventure_plugin.py add-action FOLDER --place KEY --id ID [--do effects|talk|duel|copy|buy|sell]
            [--prices 100,200] [--effect K=V]... [--needs K=V]... [--when K=V]... [--label WORDS] [--result WORDS]
        add a button to a place: what it costs, what it does, what it says.
    adventure_plugin.py add-pane FOLDER --place KEY [--id ID] [--when K=V]... --line WORDS...
        add a pane: with an id, one a talk button opens; with a when, one
        shown while it holds.
    adventure_plugin.py add-flag FOLDER NAME / add-counter FOLDER NAME
        declare a flag or a counter.
    adventure_plugin.py add-foe FOLDER --id KEY --name NAME --deck FILE [--life 20] [--face 3]
        add a duel opponent, its deck read from a text file ("4 Lightning Bolt" a line).
    adventure_plugin.py set-text FOLDER KEY WORDS / set-info FOLDER [--description ...] [--license ...] ...
        write one sentence of text.json; set plugin.json's own words.
    adventure_plugin.py remove-place FOLDER --id KEY
        take a place out again, with what only it used.
    adventure_plugin.py add-dungeon FOLDER --id KEY --name NAME --cards "A,B,C" [--color random]
            [--size small|large] [--rules ...] [--min 6 --max 24] [--place KEY --action ID --price N]
        add a dungeon to a sites plugin folder; with --place, a button of
        that place raises it, with panes for it open and cleared.
    adventure_plugin.py walk PLUGIN [--site KEY] [--gold N] [--press a,b,c] [--both] [--win|--lose] [--roll N] [--json]
        a sites plugin's places played as text, without the game: each
        pane, each button pressed in turn, each dungeon raised and cleared,
        every roll's outcomes, and what the walk never reached (walk --help
        lists what its hero can be given).
    adventure_plugin.py preview PLUGIN [--site KEY] [--out DIR] [--open]
        one HTML page (DIR: preview/ unless named) that shows every pane of
        a sites plugin's places as the game lays it out: picture, words,
        each when in plain words, each button and what it does.
    adventure_plugin.py wizard [FOLDER] [--answers FILE]
        make a place by answering questions: a new plugin, or one more
        place in FOLDER. Nothing is written before the last answer.
    adventure_plugin.py art PLUGIN [--json]
        advice on the pane pictures and map sprites (never a refusal).
    adventure_plugin.py guide [--out DIR] [--check]
        write the guide's reference page and the places' cheat sheet
        (GUIDE/reference.html, GUIDE/cheatsheet.html) from
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
import shutil
import stat
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

## API 2 (2026-11-21) brings the sites plugins (KIND_SITES): places of their
## own on the mainland and on other plugins' islands; every API 1 plugin
## reads as before.
API_VERSION = 3
## A plugin's kind (the manifest's `kind`, API 2): an island reached by ship
## (the default and API 1's only kind), or places that stand on the lands a
## campaign has.
KIND_ISLAND = "island"
KIND_SITES = "sites"
KINDS = [KIND_ISLAND, KIND_SITES]
## The first API a sites plugin may declare.
SITES_API = 2
## The API whose words a place may use from 2026-11-22 on: counters, foes,
## tasks, named panes, and more conditions, effects and actions. A plugin
## that uses one declares api_version 3.
SITES_WORDS_API = 3
## The first game version that reads plugin API 3: what a plugin of API 3
## names as its minimum_game_version.
SITES_WORDS_GAME = "0.70.7"
PLUGIN_FORMAT = 1
FOLDER_NAME = "expanded_adventure"
ID_PATTERN = "^[a-z][a-z0-9_]{0,39}$"
RESERVED_IDS = ["mainland"]
## `region` is required of an island alone (manifest_problems).
REQUIRED_FIELDS = ["plugin_format", "api_version", "id", "name", "version", "authors", "description", "region"]
FIELDS = ["plugin_format", "api_version", "kind", "id", "name", "version", "minimum_game_version", "authors",
          "license", "description", "learning_note", "requires", "region", "files"]
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
                "percent", "left", "color", "cards", "hero", "region", "price", "uses_left", "gold", "card", "dungeon",
                "food", "amulets", "day", "life_bonus"]
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
    "site.leave": "Leave",
    "site.back": "Return",
    "site.pay": "Pay {price} gold",
    "site.pick_title": "Pick a card",
    "site.pick_line": "A copy of it for {price} gold.",
    "site.no_gold": "You need {price} gold for this; you carry {gold}.",
    "site.bag_full": "Your bag is full; make room in it first.",
    "site.no_cards": "You have no card that may be copied.",
    "site.no_room": "No place on this land can hold a new dungeon.",
    "site.done": "It is done.",
    "site.copied": "A copy of {card} is yours.",
    "site.copied_log": "{card} copied for {price} gold.",
    "site.dungeon_open": "{dungeon} still waits for you; there is nothing new to tell.",
    "site.talk": "Ask",
    "site.give": "Give {card} (it leaves your decks)",
    "site.needs_card": "You need {card} for this; you hold none.",
    "site.needs_amulets": "You need {count} {color} amulets for this.",
    "site.needs_any_amulets": "You need {count} amulets for this; you carry {amulets}.",
    "site.needs_food": "You need {count} food for this; you carry {food}.",
    "site.card_limit": "You may hold no more copies of {card}.",
    "site.gift_waiting": "A gift for your next duel already waits; fight that duel first.",
    "site.duel": "Duel {foe}",
    "site.duel_won": "You have defeated {foe}.",
    "site.duel_lost": "{foe} has defeated you.",
    "site.duel_won_log": "Defeated {foe}.",
    "site.duel_lost_log": "Lost to {foe}.",
    "site.duel_leave_question": "Return to the main menu? This unfinished duel is not saved. Your adventure resumes with the stake paid.",
    "site.buy": "Buy a card",
    "site.sell": "Sell a card",
    "site.buy_title": "Buy a card",
    "site.buy_line": "The number beside each card is its price in gold.",
    "site.sell_title": "Sell a card",
    "site.sell_line": "The number beside each card is the gold paid for it.",
    "site.no_stock": "Nothing here is for sale to you now.",
    "site.nothing_to_sell": "You hold no card that is wanted here.",
    "site.bought": "{card} is yours for {price} gold.",
    "site.sold": "You sell {card} for {price} gold.",
    "site.bought_log": "{card} bought for {price} gold.",
    "site.sold_log": "{card} sold for {price} gold.",
    "site.no_way": "There is no way there from here.",
    "site.magic_owned": "{title} is yours already.",
    "site.no_link": "No town of this land can be linked now.",
    "site.life_full": "No place can add to your life any more.",
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
               ("sites.html", "Places: sites plugins"), ("cheatsheet.html", "Places cheat sheet"),
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


## PluginPackage.MAX_RATIO: the most deflate can make of a byte, and so the
## most an entry's listed size may be of its packed size.
MAX_RATIO = 1032
SIG_LOCAL, SIG_ROW, SIG_END, SIG_END64, SIG_LOCATOR64 = 0x04034B50, 0x02014B50, 0x06054B50, 0x06064B50, 0x07064B50


def _no_entries(problem: str) -> dict:
    return {"entries": [], "problem": problem, "length": 0, "directory": 0}


def zip_entries(path: str) -> dict:
    """PluginPackage.zip_entries, line for line: the central directory, read
    before anything is inflated — the one list of files a zip has (no second
    end record, no zip64 list, one disk, rows that fill it exactly)."""
    name = get_file(path)
    try:
        source = open(path, "rb")
    except OSError:
        return _no_entries("%s: the zip could not be opened." % name)
    with source:
        length = os.fstat(source.fileno()).st_size
        if length > MAX_TOTAL:
            return _no_entries("%s is bigger than 32 MiB." % name)
        if length < 22:
            return _no_entries("%s is not a whole zip." % name)
        tail_size = min(65557, length)
        source.seek(length - tail_size)
        tail = source.read(tail_size)
        if len(tail) != tail_size:
            return _no_entries("%s: the zip could not be read." % name)

        def u16(at: int) -> int:
            return struct.unpack_from("<H", tail, at)[0]

        def u32(at: int) -> int:
            return struct.unpack_from("<I", tail, at)[0]

        # The last end mark of the file, wherever it sits.
        last = tail.rfind(struct.pack("<I", SIG_END))
        if last < 0:
            return _no_entries("%s is not a whole zip (its list of files is missing)." % name)
        end = last
        if end + 22 > len(tail) or end + 22 + u16(end + 20) != len(tail):
            # Not the record a zip ends with. An earlier whole one makes this
            # a zip of two lists; none, a cut or padded file.
            end = min(last - 1, len(tail) - 22)
            while end >= 0:
                if u32(end) == SIG_END and end + 22 + u16(end + 20) == len(tail):
                    return _no_entries("%s holds a second end record after its list of files; save it as a plain zip."
                                       % name)
                end -= 1
            return _no_entries("%s is not a whole zip (its list of files is missing)." % name)
        # A zip64 locator that leads to a zip64 end record: another list.
        at64 = tail.find(struct.pack("<I", SIG_LOCATOR64))
        while at64 >= 0:
            if at64 + 16 <= len(tail):
                where = struct.unpack_from("<q", tail, at64 + 8)[0]
                if 0 <= where and where + 4 <= length:
                    source.seek(where)
                    mark = source.read(4)
                    if len(mark) == 4 and struct.unpack("<I", mark)[0] == SIG_END64:
                        return _no_entries("%s: a zip64 or damaged zip; save it as a plain zip." % name)
            at64 = tail.find(struct.pack("<I", SIG_LOCATOR64), at64 + 1)
        count = u16(end + 10)
        directory_size = u32(end + 12)
        offset = u32(end + 16)
        directory_end = length - tail_size + end
        if count == 0xFFFF or offset == 0xFFFFFFFF or offset + directory_size != directory_end \
                or u16(end + 4) != 0 or u16(end + 6) != 0 or u16(end + 8) != count:
            return _no_entries("%s: a zip64 or damaged zip; save it as a plain zip." % name)
        source.seek(offset)
        directory = source.read(directory_size)
    entries = []
    at = 0
    for _ in range(count):
        if at + 46 > len(directory) or struct.unpack_from("<I", directory, at)[0] != SIG_ROW:
            return _no_entries("%s is damaged (its list of files)." % name)
        made_by, _, flags, method = struct.unpack_from("<HHHH", directory, at + 4)
        crc, packed, size, name_length, extra_length, comment_length, disk = struct.unpack_from("<IIIHHHH", directory, at + 16)
        external, local = struct.unpack_from("<II", directory, at + 38)
        skip = name_length + extra_length + comment_length
        if at + 46 + skip > len(directory):
            return _no_entries("%s is damaged (its list of files)." % name)
        raw = directory[at + 46:at + 46 + name_length]
        entry_name = utf8_string(raw) if is_utf8(raw) else ""
        link = (made_by >> 8) == 3 and ((external >> 16) & 0xF000) == 0xA000
        entries.append({"name": entry_name, "raw": raw, "size": size, "packed": packed, "method": method,
                        "flags": flags, "link": link, "crc": crc, "offset": local, "disk": disk})
        at += 46 + skip
        if len(entries) > MAX_FILES + MAX_FOLDERS:
            return _no_entries("%s holds more than %d files." % (name, MAX_FILES))
    # The list is its rows and nothing else: no room for a second one.
    if at != len(directory):
        return _no_entries("%s is damaged (its list of files)." % name)
    return {"entries": entries, "problem": "", "length": length, "directory": offset}


def entry_bytes(source, listed: dict, entry: dict, cap: int) -> bytes | None:
    """PluginPackage.entry_bytes: an entry's bytes, exactly the size the
    list names — its own header agreeing with the list on its name, method,
    sizes and CRC-32, its data lying before the list — or None."""
    size, packed, method, flags, offset = entry["size"], entry["packed"], entry["method"], entry["flags"], entry["offset"]
    directory = listed["directory"]
    if entry.get("disk", 0) != 0 or flags & 1 or method not in (0, 8) or entry["link"] \
            or size > cap or size > MAX_TOTAL or packed > directory:
        return None
    if (method == 0 and packed != size) or (method == 8 and size > packed * MAX_RATIO + 64):
        return None
    raw = entry["raw"]
    if offset + 30 + len(raw) + packed > directory:
        return None
    try:
        source.seek(offset)
        local = source.read(30)
        if len(local) != 30 or struct.unpack_from("<I", local, 0)[0] != SIG_LOCAL \
                or struct.unpack_from("<H", local, 8)[0] != method or struct.unpack_from("<H", local, 6)[0] & 1 \
                or struct.unpack_from("<H", local, 26)[0] != len(raw):
            return None
        # A streamed entry (flag bit 3) leaves its sizes for after its data:
        # zeros here. Any other header names what the list names.
        streamed = bool(struct.unpack_from("<H", local, 6)[0] & 8)
        for at, wanted in ((14, entry["crc"]), (18, packed), (22, size)):
            value = struct.unpack_from("<I", local, at)[0]
            if value != wanted and not (streamed and value == 0):
                return None
        if source.read(len(raw)) != raw:
            return None
        data_at = offset + 30 + len(raw) + struct.unpack_from("<H", local, 28)[0]
        if data_at + packed > directory:
            return None
        if size == 0:
            return b""
        source.seek(data_at)
        data = source.read(packed)
        if len(data) != packed:
            return None
        if method == 0:
            return data
        # Deflated: unpacked into exactly the room the list names, the
        # stream ended, its CRC-32 the list's (the game dresses it as gzip).
        unpacker = zlib.decompressobj(-15)
        out = unpacker.decompress(data, size + 1)
        if len(out) != size or not unpacker.eof or zlib.crc32(out) & 0xFFFFFFFF != entry["crc"]:
            return None
        return out
    except (OSError, zlib.error, struct.error):
        return None


def engine_agrees(path: str, entries: list) -> bool:
    """PluginPackage.engine_agrees: a second reader of the zip (the game's
    is the engine's ZIPReader, the tool's Python's zipfile) lists the same
    entries, name for name."""
    try:
        with zipfile.ZipFile(path) as archive:
            listed = archive.infolist()
    except (zipfile.BadZipFile, OSError, ValueError, NotImplementedError, struct.error):
        return False
    if len(listed) != len(entries):
        return False
    for info, entry in zip(listed, entries):
        try:
            raw = info.orig_filename.encode("utf-8" if info.flag_bits & 0x800 else "cp437")
        except UnicodeError:
            return False
        if entry["name"] != "" and raw != entry["raw"] and info.orig_filename != entry["name"]:
            return False
    return True
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
    # Nothing is unpacked from a zip a second reader lists otherwise.
    if not engine_agrees(path, listed["entries"]):
        problems.append("%s: a zip64 or damaged zip; save it as a plain zip." % get_file(path))
        return out
    with open(path, "rb") as source:
        for rel, entry in keep:
            data = entry_bytes(source, listed, entry, entry["size"])
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
    sites = isinstance(manifest.get("kind"), str) and manifest["kind"] == KIND_SITES
    for key in REQUIRED_FIELDS:
        if key not in manifest and not (sites and key == "region"):
            out.append("plugin.json: the field \"%s\" is missing." % key)
    if out:
        return out
    if "kind" in manifest and (not isinstance(manifest["kind"], str) or manifest["kind"] not in KINDS):
        out.append("plugin.json: kind must be one of %s." % ", ".join(KINDS))
    if sites:
        if "region" in manifest:
            out.append("plugin.json: a sites plugin has no region; its places are described in sites.json.")
        if whole(manifest["api_version"]) and int(manifest["api_version"]) < SITES_API:
            out.append("plugin.json: a sites plugin needs api_version %d or newer." % SITES_API)
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
    if not sites:
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


def manifest_kind(manifest: dict) -> str:
    """AdventurePlugins.manifest_kind: the kind [manifest] declares; an
    island when it names none (or none of KINDS)."""
    kind = manifest.get("kind", KIND_ISLAND)
    return kind if isinstance(kind, str) and kind in KINDS else KIND_ISLAND


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


# ------------------------------------------- a place's parts, walked --

def _effect_lists(effects: list, at: str):
    """[effects] and every list a roll nests in it, each with its path."""
    yield at, effects
    for e, effect in enumerate(effects):
        if isinstance(effect, dict) and isinstance(effect.get("roll"), dict):
            for o, outcome in enumerate(effect["roll"].get("outcomes", [])):
                yield from _effect_lists(outcome.get("effects", []), "%s[%d].roll.outcomes[%d].effects" % (at, e, o))


def action_effect_lists(action: dict, at: str):
    """Every effects list of an action: its own, a duel's win and lose, a
    roll's outcomes — (path, list)."""
    yield from _effect_lists(action.get("effects", []), at + ".effects")
    for side in ("win", "lose"):
        yield from _effect_lists(action.get(side, {}).get("effects", []), "%s.%s.effects" % (at, side))


def action_line_lists(action: dict, at: str):
    """Every list of lines an action may show: its result, a duel's win and
    lose, a roll's outcomes — (path, list)."""
    yield at + ".result", action.get("result", [])
    for side in ("win", "lose"):
        yield "%s.%s.result" % (at, side), action.get(side, {}).get("result", [])
    for where, effects in action_effect_lists(action, at):
        for e, effect in enumerate(effects):
            if isinstance(effect.get("roll"), dict):
                for o, outcome in enumerate(effect["roll"].get("outcomes", [])):
                    yield "%s[%d].roll.outcomes[%d].result" % (where, e, o), outcome.get("result", [])


def action_effects(action: dict) -> list:
    """Every effect an action may apply, the nested ones too, flat."""
    return [effect for _, effects in action_effect_lists(action, "") for effect in effects]


def _flat_conditions(conditions: list) -> list:
    out = []
    for condition in conditions:
        out.append(condition)
        if "any" in condition:
            out.extend(condition["any"])
    return out


def site_condition_lists(file: dict):
    """Every list of conditions of a sites.json (normalized): (path, site
    key or "", list) — panes, lines, actions, results and tasks."""
    def of_lines(lines, at, key):
        for l, line in enumerate(lines):
            if isinstance(line, dict):
                yield "%s[%d].when" % (at, l), key, line.get("when", [])
    for key, site in file["sites"].items():
        for p, pane in enumerate(site["panes"]):
            here = "sites.%s.panes[%d]" % (key, p)
            yield here + ".when", key, pane.get("when", [])
            yield from of_lines(pane.get("lines", []), here + ".lines", key)
            for a, action in enumerate(pane.get("actions", [])):
                spot = "%s.actions[%d]" % (here, a)
                yield spot + ".when", key, action.get("when", [])
                for where, lines in action_line_lists(action, spot):
                    yield from of_lines(lines, where, key)
    for key, task in file.get("tasks", {}).items():
        for part in ("when", "done_when"):
            yield "tasks.%s.%s" % (key, part), "", task.get(part, [])


def site_actions_all(file: dict):
    """(site key, pane index, action) for every action as written, repeats too."""
    for key, site in file["sites"].items():
        for p, pane in enumerate(site["panes"]):
            for action in pane.get("actions", []):
                yield key, p, action


class Content:
    """PluginSchema.read: the content files checked against schema_v1.json
    and against each other, normalized as the game normalizes them."""

    def __init__(self, game: Game):
        self.game = game
        self.schema = game.schema()
        self.notes: list[str] = []
        ## The words of API 3 a sites plugin uses, (word, where), as found.
        self.api_words: list = []

    @staticmethod
    def _refs() -> dict:
        return {"text": [], "card": [], "picture": [], "file": []}

    def read(self, manifest: dict, files: dict) -> dict:
        problems: list[str] = []
        spec = self.schema
        ident = str(manifest.get("id", "")) if isinstance(manifest.get("id", ""), str) else ""
        refs = self._refs()
        content = {}
        sites = manifest_kind(manifest) == KIND_SITES
        listed = spec["site_files"] if sites else spec["files"]
        for name, rule in listed.items():
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
        if sites:
            return self._read_sites(manifest, content, refs)
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
        self._check_words(data["text"], refs, problems)
        self._check_pictures(data["id"], "places.json", data["places"]["pictures"], refs, problems)
        self._check_cards(data["packs"], refs, problems)
        self._check_world(data["world"], problems)
        self._check_quests(data, problems)
        self._check_foes(data, problems)

    def _check_words(self, words: dict, refs: dict, problems: list) -> None:
        """PluginSchema._check_words: every text names placeholders of the
        closed list, and every text key named is text.json's (or a default's)."""
        for key, template in words.items():
            unknown = unknown_placeholders(str(template))
            if unknown:
                problems.append("text.json: %s: unknown placeholder %s (the list: %s)."
                                % (key, ", ".join("{" + w + "}" for w in unknown), ", ".join(PLACEHOLDERS)))
        for key, path in refs["text"]:
            if key not in words and key not in TEXT_DEFAULTS:
                problems.append("%s: text.json has no %s." % (path, key))
                self.notes.extend(text_hints(path, key, words))

    def _check_pictures(self, ident: str, file: str, pictures: dict, refs: dict, problems: list) -> None:
        """PluginSchema._check_pictures: picture keys begin with the plugin's
        id; every picture named is one of [pictures] (listed in [file]) or a skin's."""
        for key in pictures:
            if not str(key).startswith(ident + "_"):
                problems.append("%s: pictures.%s: a picture key begins with the plugin id and _ (%s_…)." % (file, key, ident))
        skin = self.schema["skin_pictures"]
        for key, path in refs["picture"]:
            if key not in pictures and key not in skin:
                problems.append("%s: %s is neither a picture of %s nor a skin picture (%s)." % (path, key, file, ", ".join(skin)))

    def _check_cards(self, packs: list, refs: dict, problems: list) -> None:
        """PluginSchema._check_cards (and the tool's note when it holds no card lists)."""
        if not self.game.has_cards and refs["card"]:
            self.notes.append("Card names were not checked (%d named): %s holds no card lists. Run the tool in a "
                              "game checkout or a release folder, or name one with --game DIR."
                              % (len(refs["card"]), self.game.describe()))
        for card, path in refs["card"]:
            if not self.game.card_known(card, packs):
                problems.append("%s: %s is not a card of the base game or of a required pack (%s)."
                                % (path, card, ", ".join(packs) if packs else "none"))
                self.notes.extend(card_hints(self.game, path, str(card), packs))

    # ------------------------------------------------------ a sites plugin --

    def _read_sites(self, manifest: dict, content: dict, refs: dict) -> dict:
        """PluginSchema._read_sites: a sites plugin's content (API 2), {id,
        kind, manifest, sites, text, packs}, and its cross checks — the
        words, the pictures, the cards, the flags, the actions and the
        dungeons named."""
        problems: list[str] = []
        ident = str(manifest.get("id", "")) if isinstance(manifest.get("id", ""), str) else ""
        data = {"id": ident, "kind": KIND_SITES, "manifest": manifest, "sites": content["sites.json"],
                "text": content["text.json"], "packs": packs_of(manifest)}
        self._check_words(data["text"], refs, problems)
        self._check_pictures(ident, "sites.json", data["sites"]["pictures"], refs, problems)
        self._check_cards(data["packs"], refs, problems)
        self._check_sites(data["sites"], problems, int(manifest.get("api_version", SITES_API)))
        if problems:
            return {"data": {}, "problems": problems}
        return {"data": data, "problems": problems}

    def _v3(self, group: str) -> list:
        return self.schema.get("v3_words", {}).get(group, [])

    def _check_sites(self, file: dict, problems: list, api: int = 3) -> None:
        """PluginSchema._check_sites, line for line: the flags, counters,
        dungeons, foes, panes and places named exist, an action's id is its
        site's once, every place has a pane to open on and every pane a way
        out, each field stands where it means something, and a word of API 3
        needs api_version 3 (the words found are kept in api_words)."""
        dungeons = file["dungeons"]
        foes = file.get("foes", {})
        words: list = []
        self.api_words = words
        for part in ("counters", "foes", "tasks"):
            if file.get(part):
                words.append((part, "sites.json: " + part))
        counters = file.get("counters", [])
        for i, name in enumerate(counters):
            if counters.index(name) != i:
                problems.append("sites.json: counters[%d]: %s is named twice." % (i, name))
        for key, dungeon in dungeons.items():
            distance = dungeon["distance"]
            if int(distance["min"]) > int(distance["max"]):
                problems.append("sites.json: dungeons.%s.distance: min %d is more than max %d."
                                % (key, int(distance["min"]), int(distance["max"])))
        for name, foe in foes.items():
            self._check_foe(foe, "sites.json: foes.%s" % name, problems)
        # Every site's actions first: a condition may name another site's.
        every: dict = {}
        for key, site in file["sites"].items():
            actions: dict = {}
            for p, pane in enumerate(site["panes"]):
                for a, action in enumerate(pane["actions"]):
                    name = str(action["id"])
                    if name in actions and actions[name] != action:
                        problems.append("sites.json: sites.%s.panes[%d].actions[%d].id: %s names another action of this site; an id is "
                                        "one action (the same action may stand in several panes)." % (key, p, a, name))
                    elif name not in actions:
                        actions[name] = action
            every[key] = actions
        known = {"flags": file["flags"], "counters": counters, "dungeons": dungeons, "sites": every, "words": words}
        for key, site in file["sites"].items():
            at = "sites.json: sites.%s" % key
            actions = every[key]
            known["site"] = key
            panes: dict = {}
            opening = -1
            for p, pane in enumerate(site["panes"]):
                if "id" in pane:
                    words.append(("id", "%s.panes[%d].id" % (at, p)))
                    if pane["id"] in panes:
                        problems.append("%s.panes[%d].id: %s is another pane's id; a pane's id is its site's once." % (at, p, pane["id"]))
                    panes[pane["id"]] = True
                else:
                    opening = p
            # A WAY IN AND A WAY OUT: without them the place showed an empty
            # pane with no button.
            if opening < 0:
                problems.append("%s.panes: every pane has an id, so none opens by itself; the place needs a pane without an id to open on." % at)
            elif site["panes"][opening]["when"]:
                problems.append("%s.panes[%d].when: the last pane without an id must have no when, so the place always has a pane to show; add one more pane without a when after it." % (at, opening))
            for p, pane in enumerate(site["panes"]):
                here = "%s.panes[%d]" % (at, p)
                self._check_site_conditions(pane["when"], here + ".when", known, actions, problems)
                self._check_site_lines(pane["lines"], here + ".lines", known, actions, problems)
                way_out = False
                for a, action in enumerate(pane["actions"]):
                    spot = "%s.actions[%d]" % (here, a)
                    if str(action["do"]) == "leave" and not action["when"]:
                        way_out = True
                    self._check_site_conditions(action["when"], spot + ".when", known, actions, problems)
                    self._check_site_lines(action["result"], spot + ".result", known, actions, problems)
                    self._check_site_action(action, spot, known, actions, panes, foes, problems)
                if not way_out:
                    problems.append("%s.actions: a pane needs an action that does \"leave\" and has no when, so the hero can always walk away." % here)
        for name, task in file.get("tasks", {}).items():
            at = "sites.json: tasks.%s" % name
            target = str(task.get("at", ""))
            actions = {}
            placed = target.startswith("place:")
            if placed:
                if target[len("place:"):] not in every:
                    problems.append("%s.at: no place %s in sites.json sites." % (at, target[len("place:"):]))
                else:
                    actions = every[target[len("place:"):]]
            elif target.startswith("dungeon:") and target[len("dungeon:"):] not in dungeons:
                problems.append("%s.at: no dungeon %s in sites.json dungeons." % (at, target[len("dungeon:"):]))
            for part in ("when", "done_when"):
                if not placed:
                    for word in ("used", "used_up"):
                        if any(word in condition for condition in _flat_conditions(task[part])):
                            problems.append("%s.%s: %s reads the place a task is at; give the task \"at\": \"place:…\", or use site_used." % (at, part, word))
                            task[part] = []
                self._check_site_conditions(task[part], "%s.%s" % (at, part), known, actions, problems)
        self._check_api(words, api, problems)

    @staticmethod
    def _check_api(words: list, api: int, problems: list) -> None:
        if api >= 3:
            return
        named: dict = {}
        for word, where in words:
            if word in named:
                continue
            named[word] = True
            problems.append("%s: \"%s\" is a word of plugin API 3, and plugin.json declares api_version %d. Set \"api_version\": 3 there (the plugin then needs a game that reads API 3)." % (where, word, api))

    @staticmethod
    def _check_foe(foe: dict, at: str, problems: list) -> None:
        cards = sum(int(n) for n in foe["deck"].values())
        if cards < 1 or cards > 250:
            problems.append("%s.deck holds %d cards; 1 to 250 are allowed." % (at, cards))
        face = int(foe["face"])
        if not (0 <= face < CREATURE_ROWS) or face == LAIR:
            problems.append("%s.face: %d is not a creature row." % (at, face))

    def _check_site_lines(self, lines: list, at: str, known: dict, actions: dict, problems: list) -> None:
        for l, line in enumerate(lines):
            if not isinstance(line, dict):
                continue
            if "one_of" in line:
                known["words"].append(("one_of", "%s[%d]" % (at, l)))
            self._check_site_conditions(line["when"], "%s[%d].when" % (at, l), known, actions, problems)

    def _check_site_action(self, action: dict, spot: str, known: dict, actions: dict, panes: dict, foes: dict,
                           problems: list) -> None:
        kind = str(action["do"])
        words = known["words"]
        if kind in self._v3("do"):
            words.append((kind, spot + ".do"))
        # Each field where it means something: a field that would be silently
        # ignored is a mistake the author should hear of.
        allowed = {"effects": ["effects", "talk"], "prices": ["effects", "talk", "copy_card", "duel"],
                   "needs": ["effects", "talk", "copy_card", "duel"],
                   "result": ["effects", "copy_card", "buy_card", "sell_card"], "to": ["talk"], "foe": ["duel"],
                   "win": ["duel"], "lose": ["duel"], "cards": ["buy_card", "sell_card"],
                   "stock": ["buy_card", "sell_card"]}
        for field, kinds in allowed.items():
            value = action.get(field)
            given = value is not None and not (isinstance(value, (list, dict)) and not value)
            if field in ("win", "lose"):
                given = isinstance(value, dict) and bool(value["effects"] or value["result"])
            if not given:
                continue
            if field in self._v3("action"):
                words.append((field, "%s.%s" % (spot, field)))
            if kind not in kinds:
                problems.append("%s.%s: only an action that does %s has %s." % (spot, field, " or ".join(kinds), field))
        if str(action.get("count", "press")) != "press":
            words.append(("count", spot + ".count"))
            if kind != "duel":
                problems.append("%s.count: only an action that does duel has count." % spot)
        if kind == "talk":
            if "to" not in action:
                problems.append("%s: a talk needs \"to\": the id of the pane to open." % spot)
            elif action["to"] not in panes:
                problems.append("%s.to: this site has no pane with the id %s." % (spot, action["to"]))
        elif kind == "duel":
            if "foe" not in action:
                problems.append("%s: a duel needs \"foe\": a key of sites.json foes." % spot)
            elif action["foe"] not in foes:
                problems.append("%s.foe: no foe %s in sites.json foes." % (spot, action["foe"]))
        elif kind in ("buy_card", "sell_card"):
            if not action["cards"]:
                problems.append("%s: %s needs \"cards\": each card and its price." % (spot, kind))
        priced = bool(action["prices"]) or bool(action["needs"])
        self._check_site_effects(action["effects"], spot + ".effects", known, actions, priced, 0, problems, kind)
        for branch in ("win", "lose"):
            self._check_site_effects(action[branch]["effects"], "%s.%s.effects" % (spot, branch), known, actions, priced,
                                     2, problems)
            self._check_site_lines(action[branch]["result"], "%s.%s.result" % (spot, branch), known, actions, problems)

    def _check_site_effects(self, effects: list, at: str, known: dict, actions: dict, priced: bool, inside: int,
                            problems: list, kind: str = "effects") -> None:
        rolls = 0
        for e, effect in enumerate(effects):
            name = next(iter(effect))
            value = effect[name]
            spot = "%s[%d].%s" % (at, e, name)
            if name in self._v3("effect"):
                known["words"].append((name, spot))
            if name in ("set_flag", "clear_flag"):
                if value not in known["flags"]:
                    problems.append("%s: no flag %s in sites.json flags." % (spot, value))
            elif name == "spawn_dungeon":
                if value not in known["dungeons"]:
                    problems.append("%s: no dungeon %s in sites.json dungeons." % (spot, value))
            elif name == "counter":
                if value["name"] not in known["counters"]:
                    problems.append("%s: no counter %s in sites.json counters." % (spot, value["name"]))
                if ("add" in value) == ("set" in value):
                    problems.append("%s: one of add or set is needed, not both." % spot)
            elif name == "amulet":
                if int(value["count"]) == 0:
                    problems.append("%s: count 0 gives nothing." % spot)
                elif int(value["count"]) > 0 and not priced:
                    problems.append("%s: amulets are given without end; give the action prices (a ladder that ends) or needs." % spot)
            elif name == "give_card":
                if not priced:
                    problems.append("%s: a card is given without end; give the action prices (a ladder that ends) or needs." % spot)
            elif name == "next_duel":
                gifts = sum(1 for gift in ("life", "first_move", "card") if gift in value)
                if gifts != 1:
                    problems.append("%s: exactly one of life, first_move or card is needed (one gift waits at a time)." % spot)
                elif "first_move" in value and not bool(value["first_move"]):
                    problems.append("%s: first_move is true, or left out." % spot)
            elif name == "reveal_map":
                around = str(value["around"])
                if around.startswith("dungeon:") and around[len("dungeon:"):] not in known["dungeons"]:
                    problems.append("%s.around: no dungeon %s in sites.json dungeons." % (spot, around[len("dungeon:"):]))
            elif name in ("world_magic", "mana_link", "life_bonus"):
                if not priced:
                    problems.append("%s: this is given without end; give the action prices (a ladder that ends) or needs." % spot)
            elif name == "teleport":
                to = str(value["to"])
                if inside != 0 or kind != "effects":
                    problems.append("%s: a teleport stands in the effects of an action that does effects, not in a roll, a duel or a talk." % spot)
                elif e != len(effects) - 1:
                    problems.append("%s: a teleport is the action's last effect; the pane closes with it." % spot)
                if to.startswith("place:"):
                    if to[len("place:"):] not in known["sites"]:
                        problems.append("%s.to: no place %s in sites.json sites." % (spot, to[len("place:"):]))
                    elif to[len("place:"):] == str(known.get("site", "")):
                        problems.append("%s.to: %s is this place itself." % (spot, to[len("place:"):]))
                elif to.startswith("dungeon:") and to[len("dungeon:"):] not in known["dungeons"]:
                    problems.append("%s.to: no dungeon %s in sites.json dungeons." % (spot, to[len("dungeon:"):]))
            elif name == "roll":
                rolls += 1
                if inside == 1:
                    problems.append("%s: no roll inside a roll's outcome." % spot)
                elif inside == 2:
                    problems.append("%s: no roll in a duel's win or lose; the duel is the gamble." % spot)
                elif rolls > 1:
                    problems.append("%s: one roll an action; put every outcome in it." % spot)
                for o, outcome in enumerate(value["outcomes"]):
                    self._check_site_effects(outcome["effects"], "%s.outcomes[%d].effects" % (spot, o), known, actions,
                                             priced, 1, problems)
                    self._check_site_lines(outcome["result"], "%s.outcomes[%d].result" % (spot, o), known, actions,
                                           problems)

    def _check_site_conditions(self, conditions: list, at: str, known: dict, actions: dict, problems: list,
                               inside: bool = False) -> None:
        for i, condition in enumerate(conditions):
            name = next(iter(condition))
            value = condition[name]
            if name in self._v3("condition"):
                known["words"].append((name, "%s[%d].%s" % (at, i, name)))
            if name in ("flag", "not_flag"):
                if value not in known["flags"]:
                    problems.append("%s[%d].%s: no flag %s in sites.json flags." % (at, i, name, value))
            elif name == "used":
                if value["action"] not in actions:
                    problems.append("%s[%d].used: this site has no action %s." % (at, i, value["action"]))
            elif name == "used_up":
                if value not in actions:
                    problems.append("%s[%d].used_up: this site has no action %s." % (at, i, value))
                elif not actions[value]["prices"]:
                    problems.append("%s[%d].used_up: the action %s has no prices, so it is never used up." % (at, i, value))
            elif name == "dungeon":
                if value["dungeon"] not in known["dungeons"]:
                    problems.append("%s[%d].dungeon: no dungeon %s in sites.json dungeons." % (at, i, value["dungeon"]))
            elif name == "counter":
                if value["name"] not in known["counters"]:
                    problems.append("%s[%d].counter: no counter %s in sites.json counters." % (at, i, value["name"]))
                if int(value["min"]) > int(value["max"]):
                    problems.append("%s[%d].counter: min %d is more than max %d." % (at, i, int(value["min"]), int(value["max"])))
            elif name == "difficulty":
                if int(value["min"]) > int(value["max"]):
                    problems.append("%s[%d].difficulty: min %d is more than max %d." % (at, i, int(value["min"]), int(value["max"])))
            elif name == "site_used":
                if value["site"] not in known["sites"]:
                    problems.append("%s[%d].site_used: no place %s in sites.json sites." % (at, i, value["site"]))
                elif value["action"] not in known["sites"][value["site"]]:
                    problems.append("%s[%d].site_used: the place %s has no action %s." % (at, i, value["site"], value["action"]))
            elif name == "any":
                if inside:
                    problems.append("%s[%d].any: no any inside an any; list its conditions in the outer one." % (at, i))
                else:
                    self._check_site_conditions(value, "%s[%d].any" % (at, i), known, actions, problems, True)
    # ---------------------------------------------------- an island's checks --

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


def site_descriptor(manifest: dict, data: dict) -> dict:
    """PluginSchema.site_descriptor with AdventurePlugins._site_descriptor's
    defaults: what the game's AdventureSites reads of a valid sites plugin
    — id, plugin, kind, version, name, pack, packs, salt, pictures, sprites
    ({site: [file, width]}) and sites ({site: {name, where, gap}})."""
    if not data:
        return {}
    file = data["sites"]
    packs = list(data.get("packs", []))
    return {"id": str(manifest.get("id", data.get("id", ""))), "plugin": True, "kind": KIND_SITES,
            "version": str(manifest.get("version", "")), "name": str(manifest.get("name", "")),
            "pack": packs[0] if packs else "", "packs": packs, "salt": int(file["salt"]),
            "pictures": dict(file["pictures"]),
            "sprites": {key: [str(site["sprite"]["file"]), float(site["sprite"]["width"])]
                        for key, site in file["sites"].items()},
            "sites": {key: {"name": str(site["name"]), "where": list(site["where"]), "gap": int(site["gap"])}
                      for key, site in file["sites"].items()}}


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
    out = {"valid": False, "stage": stage, "problems": problems, "notes": [], "warnings": [], "kind": read["kind"],
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
    out["schema"] = reader.schema
    out["api_words"] = list(dict.fromkeys(word for word, _ in reader.api_words))
    if out["data"].get("kind") == KIND_SITES:
        out["warnings"] = site_warnings(manifest, out["data"], files)
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


## The API an island skeleton (new) declares: the first, every island's.
ISLAND_API = 1


def skeleton(ident: str, name: str, author: str, game_version: str) -> dict:
    """The files of a minimal plugin: {rel: bytes}."""
    salt = int.from_bytes(hashlib.sha256(ident.encode("utf-8")).digest()[:4], "big") & 0x7FFFFFFF
    # An island needs nothing past API 1, so a game that reads only API 1 reads it too.
    manifest = {"plugin_format": PLUGIN_FORMAT, "api_version": ISLAND_API, "id": ident, "name": name,
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


## A sites skeleton's map sprite, 32 x 32 pixel art: a wayside shrine with
## a lantern, its foot on the bottom rows. Each letter one pixel of
## SPRITE_COLORS (and SHRINE_COLORS).
SHRINE_ROWS = [
    "................................",
    "................................",
    "................................",
    "................................",
    "...............##...............",
    "..............#rr#..............",
    ".............#rrrr#.............",
    "............#rrrrrr#............",
    "...........#rrrrrrrr#...........",
    "..........#rrrrrrrrrr#..........",
    ".........##############.........",
    "..........#ssssssssss#..........",
    "..........#ss######ss#..........",
    "..........#s#llllll#s#..........",
    "..........#s#llyyll#s#..........",
    "..........#s#lyyyyl#s#..........",
    "..........#s#llyyll#s#..........",
    "..........#s#llllll#s#..........",
    "..........#ss######ss#..........",
    "..........#ssssssssss#..........",
    "..........#ssssssssss#..........",
    "..........#ssssssssss#..........",
    ".........##############.........",
    "........#gggggggggggggg#........",
    "........################........",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
    "................................",
]
SHRINE_COLORS = dict(SPRITE_COLORS, r=(140, 62, 44, 255), l=(52, 40, 30, 255))


def _site_picture(sprite_rows: list, colors: dict) -> bytes:
    """A small pane picture for a sites skeleton, 128 x 70 (the pane's shape,
    about 1.83 to 1): an evening sky over a meadow, the sprite drawn twice
    its size in the middle."""
    width, height, horizon = 128, 70, 46
    pixels = []
    for y in range(height):
        row = []
        for x in range(width):
            if y < horizon:
                t = y / horizon
                row.append((int(70 + 150 * t), int(92 + 90 * t), int(150 + 40 * t), 255))
            else:
                t = (y - horizon) / (height - horizon)
                row.append((int(96 - 40 * t), int(126 - 50 * t), int(64 - 24 * t), 255))
        pixels.append(row)
    left, top = (width - 2 * len(sprite_rows[0])) // 2, horizon + 4 - 2 * 24
    for sy, line in enumerate(sprite_rows):
        for sx, letter in enumerate(line):
            color = colors[letter]
            if color[3] == 0:
                continue
            for dy in (0, 1):
                for dx in (0, 1):
                    y, x = top + 2 * sy + dy, left + 2 * sx + dx
                    if 0 <= y < height and 0 <= x < width:
                        pixels[y][x] = color
    return png_bytes(width, height, pixels)


def site_skeleton(ident: str, name: str, author: str, game_version: str) -> dict:
    """The files of a minimal sites plugin (API 2): {rel: bytes} — one place,
    a wayside shrine on the mainland and on every island, whose service
    costs 20, 40 and 80 gold and is then used up."""
    salt = int.from_bytes(hashlib.sha256(ident.encode("utf-8")).digest()[:4], "big") & 0x7FFFFFFF
    manifest = {"plugin_format": PLUGIN_FORMAT, "api_version": SITES_API, "kind": KIND_SITES, "id": ident,
                "name": name, "version": "0.1.0"}
    if game_version:
        manifest["minimum_game_version"] = game_version
    manifest.update({
        "authors": [author],
        "license": "Name the license of your plugin here, and put its text in LICENSE.txt.",
        "description": "One line for the plugin list: what the hero finds at this place.",
        "requires": {"card_packs": []},
    })
    picture = "%s_shrine" % ident
    sites = {
        "salt": salt,
        "flags": [],
        "pictures": {picture: "art/%s_shrine.png" % ident},
        "dungeons": {},
        "sites": {
            "shrine": {
                "name": "Wayside Shrine",
                "where": ["mainland", "islands"],
                "picture": picture,
                "sprite": {"file": "art/%s_shrine_map.png" % ident, "width": 80},
                "gap": 3,
                "panes": [
                    {"when": [{"used_up": "bless"}], "subtitle": "shrine.subtitle",
                     "lines": ["shrine.intro", "shrine.spent"],
                     "actions": [{"id": "leave", "do": "leave", "label": "shrine.leave"}]},
                    {"subtitle": "shrine.subtitle",
                     "lines": ["shrine.intro", "shrine.offer",
                               {"text": "shrine.again", "when": [{"used": {"action": "bless", "min": 1}}]}],
                     "actions": [
                         {"id": "bless", "do": "effects", "label": "shrine.bless", "prices": [20, 40, 80],
                          "effects": [{"food": 6}, {"log_event": {"event": "shrine", "text": "shrine.log"}}],
                          "result": ["shrine.blessed"]},
                         {"id": "leave", "do": "leave", "label": "shrine.leave"}]},
                ],
            },
        },
    }
    text = {
        "shrine.subtitle": "A shrine by the road",
        "shrine.intro": "A small stone shrine stands by the road. A lantern burns in it, though no keeper is near.",
        "shrine.offer": "Travelers leave gold in its bowl, and find their packs heavier with food when they move on.",
        "shrine.again": "The lantern flares as you come near, as if it knows you.",
        "shrine.bless": "Leave {price} gold in the bowl ({uses_left} left)",
        "shrine.blessed": "You leave {price} gold in the bowl. When you lift your pack, it is heavier: six days of food.",
        "shrine.spent": "The lantern has gone out. The bowl is cold and empty.",
        "shrine.log": "Left {price} gold at the wayside shrine.",
        "shrine.leave": "Leave",
    }
    readme = ("%s\n%s\n\nA sites plugin for Shandalar (plugin API 2), made with tools/adventure_plugin.py new\n"
              "--kind sites: one place, a wayside shrine on the mainland and on every island.\n\n"
              "Edit the JSON files, then check and package the plugin:\n"
              "    python3 tools/adventure_plugin.py validate %s\n"
              "    python3 tools/adventure_plugin.py export %s --out dist\n"
              "Put the zip (or this folder) in the game's expanded_adventure/ folder and tick it\n"
              "in the Embark window's plugin list. The guide in expanded_adventure/GUIDE/\n"
              "(sites.html) explains every file and field.\n") % (name, "=" * min(len(name), 72), ident, ident)

    def encode(value) -> bytes:
        return (json.dumps(value, indent="\t", ensure_ascii=False) + "\n").encode("utf-8")

    return {
        "plugin.json": encode(manifest), "sites.json": encode(sites), "text.json": encode(text),
        "README.txt": readme.encode("utf-8"),
        "art/%s_shrine.png" % ident: _site_picture(SHRINE_ROWS, SHRINE_COLORS),
        "art/%s_shrine_map.png" % ident: _sprite(SHRINE_ROWS, SHRINE_COLORS),
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
    files = (site_skeleton if args.kind == KIND_SITES else skeleton)(args.id, name, author, game.version)
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
    quoted = _quoted(folder)
    if args.kind == KIND_SITES:
        print("Next, in any order (each command says what it did and what comes next):\n"
              "    python3 tools/adventure_plugin.py add-place %s --list-recipes\n"
              "    python3 tools/adventure_plugin.py add-place %s --id inn --name \"The Inn\" --recipe lore\n"
              "    python3 tools/adventure_plugin.py set-text %s shrine.intro \"Your own words.\"\n"
              "    python3 tools/adventure_plugin.py walk %s\n"
              "    python3 tools/adventure_plugin.py art %s\n"
              "    python3 tools/adventure_plugin.py validate %s\n"
              "    python3 tools/adventure_plugin.py export %s --out dist\n"
              "More: add-action, add-pane, add-flag, add-counter, add-foe, add-dungeon, remove-place, set-info; the guide's "
              "sites.html and cheatsheet.html explain every word." % ((quoted,) * 7))
        return 0
    print("Next: edit its JSON files, then\n    python3 tools/adventure_plugin.py validate %s\n"
          "    python3 tools/adventure_plugin.py export %s --out dist" % (quoted, quoted))
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
            "problems": result["problems"], "notes": result["notes"], "warnings": result.get("warnings", []),
            "kind": result["kind"], "plugin_kind": manifest_kind(manifest),
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
        for warning in result["warnings"]:
            print("warning: " + warning)
        print("%s: valid (plugin %s %s)." % (args.plugin, manifest["id"], manifest["version"]))
        if result["warnings"]:
            print("%d warning%s: the game loads the plugin as it is; look at %s before you share it."
                  % (len(result["warnings"]), "" if len(result["warnings"]) == 1 else "s",
                     "it" if len(result["warnings"]) == 1 else "them"))
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
    out = {"path": result["path"], "kind": result["kind"], "plugin_kind": manifest_kind(manifest),
           "valid": result["valid"], "stage": result["stage"], "problems": result["problems"], "notes": result["notes"],
           "manifest": {key: _plain(manifest[key]) for key in FIELDS if key in manifest and key != "files"},
           "hashes": len(manifest.get("files", {})) if isinstance(manifest.get("files"), dict) else 0,
           "files": len(files), "bytes": sum(len(b) for b in files.values()), "by_kind": kinds}
    data = result["data"]
    if data and data.get("kind") == KIND_SITES:
        out["content"] = {"sites": {key: {"name": site["name"], "where": site["where"], "gap": site["gap"],
                                          "panes": len(site["panes"]),
                                          "actions": sorted({str(a["id"]) for pane in site["panes"]
                                                             for a in pane["actions"]})}
                                    for key, site in data["sites"]["sites"].items()},
                          "dungeons": {key: {"name": d["name"], "cards": d["cards"]}
                                       for key, d in data["sites"]["dungeons"].items()},
                          "flags": data["sites"]["flags"], "counters": data["sites"].get("counters", []),
                          "foes": {key: {"name": foe["name"], "life": foe["life"],
                                         "cards": sum(int(n) for n in foe["deck"].values())}
                                   for key, foe in data["sites"].get("foes", {}).items()},
                          "tasks": {key: {"at": task.get("at", "")} for key, task in data["sites"].get("tasks", {}).items()},
                          "api_3_words": result.get("api_words", []),
                          "warnings": result.get("warnings", []),
                          "pictures": len(data["sites"]["pictures"]),
                          "texts": len(data["text"]), "descriptor": site_descriptor(manifest, data)}
    elif data:
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
    for key in ("id", "name", "version", "api_version", "kind", "minimum_game_version", "description",
                "learning_note", "license"):
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
    if "content" in facts and facts["plugin_kind"] == KIND_SITES:
        c = facts["content"]
        lines.append("  %-21s %d place%s, %d dungeon%s, %d flag%s, %d picture%s; %d texts" % (
            "content:", len(c["sites"]), "" if len(c["sites"]) == 1 else "s", len(c["dungeons"]),
            "" if len(c["dungeons"]) == 1 else "s", len(c["flags"]), "" if len(c["flags"]) == 1 else "s",
            c["pictures"], "" if c["pictures"] == 1 else "s", c["texts"]))
        for key, site in c["sites"].items():
            lines.append("  %-21s %s, on %s, gap %d; %d pane%s; actions %s" % (
                "place " + key + ":", site["name"], " and ".join(site["where"]), site["gap"], site["panes"],
                "" if site["panes"] == 1 else "s", ", ".join(site["actions"]) if site["actions"] else "none"))
        for key, dungeon in c["dungeons"].items():
            lines.append("  %-21s %s, holding %s" % ("dungeon " + key + ":", dungeon["name"], ", ".join(dungeon["cards"])))
        for key, foe in c["foes"].items():
            lines.append("  %-21s %s, %d life, a deck of %d cards" % ("foe " + key + ":", foe["name"], foe["life"], foe["cards"]))
        for key, task in c["tasks"].items():
            lines.append("  %-21s %s" % ("task " + key + ":", "at " + task["at"] if task["at"] else "no map target"))
        if c["counters"]:
            lines.append("  %-21s %s" % ("counters:", ", ".join(c["counters"])))
        lines.append("  %-21s %s" % ("words of API 3:", ", ".join(c["api_3_words"]) if c["api_3_words"]
                                     else "none (a game that reads API 2 plays it)"))
        if c["warnings"]:
            lines.append("  %-21s %d (validate lists them)" % ("warnings:", len(c["warnings"])))
    elif "content" in facts:
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
    # Written under its own name in a dotted folder of its own, and judged
    # there: a zip already in --out is replaced only by one the game takes.
    staging = Path(tempfile.mkdtemp(prefix="." + top + ".", suffix=".part", dir=str(out)))
    try:
        fresh = staging / target.name
        fresh.write_bytes(data)
        os.chmod(fresh, 0o644)
        check = judge(str(fresh), game)
        if check["valid"]:
            os.replace(fresh, target)
    finally:
        shutil.rmtree(staging, ignore_errors=True)
    if not check["valid"]:
        for problem in check["problems"]:
            print(problem)
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
    old_kind, new_kind = old.get("kind", KIND_ISLAND), new.get("kind", KIND_ISLAND)
    if old_kind != new_kind:
        warnings.append("The kind changed (%s -> %s): saves keep an island's land and a sites plugin's progress "
                        "apart, so nothing a save holds of the old version is read by the new one."
                        % (old_kind, new_kind))
        return warnings, notes
    if new_kind == KIND_SITES:
        site_compatibility(old, new, warnings, notes)
        return warnings, notes
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


def _site_actions(site: dict) -> dict:
    """A place's actions by id, each as its first pane gives it."""
    out: dict = {}
    for pane in site["panes"]:
        for action in pane["actions"]:
            out.setdefault(str(action["id"]), action)
    return out


def site_compatibility(old: dict, new: dict, warnings: list, notes: list) -> None:
    """What a new version of a sites plugin does to saves made with the old
    one. A save keeps, by the plugin's id (DataSites, AdventureSites): each
    place's tile by its key (`world.expansion.sites`, "<plugin>:<site>"),
    each action's uses by "<site>.<action>", the flags set by name, and each
    dungeon raised by "<land>:<dungeon key>". A key or id gone loses what
    was kept under it (warnings); the rest reaches saves without harm (notes)."""
    before, after = old["sites"], new["sites"]
    old_sites, new_sites = before["sites"], after["sites"]
    by_name = {str(site["name"]): key for key, site in new_sites.items()}
    for key, site in old_sites.items():
        if key in new_sites:
            continue
        renamed = by_name.get(str(site["name"]))
        if renamed is not None and renamed not in old_sites:
            warnings.append("sites.json sites: %s (%s) was renamed to %s: saves keep its tile and its actions' uses "
                            "by its key, so the old place is hidden, the new one is placed again and starts with "
                            "none used." % (key, site["name"], renamed))
        else:
            warnings.append("sites.json sites: %s (%s) was removed: saves keep its tile and its actions' uses, which "
                            "nothing reads now." % (key, site["name"]))
    renamed_to = {by_name.get(str(site["name"])) for key, site in old_sites.items() if key not in new_sites}
    for key, site in new_sites.items():
        if key not in old_sites and key not in renamed_to:
            notes.append("sites.json sites: %s (%s) was added: it is placed on each land its where names the next "
                         "time a save is loaded or the hero lands there." % (key, site["name"]))
    for key, site in old_sites.items():
        if key not in new_sites:
            continue
        old_actions, new_actions = _site_actions(site), _site_actions(new_sites[key])
        for action, entry in old_actions.items():
            if action not in new_actions:
                # A leave is never counted; every other action's uses are.
                if str(entry["do"]) != "leave":
                    warnings.append("sites.json sites.%s: the action %s was removed or renamed: saves count its uses "
                                    "by its id (%s.%s), so a renamed action starts again from none used, at its first "
                                    "price." % (key, action, key, action))
                continue
            was, now = list(entry["prices"]), list(new_actions[action]["prices"])
            if was != now and now and not was and str(entry["do"]) != "leave":
                # A free action's uses are counted too (DataSites._count),
                # so a save may hold more uses than the new list has prices.
                warnings.append("sites.json sites.%s: the action %s was free and now has prices (%s): saves counted "
                                "its free uses by its id (%s.%s), so a save that used it %d time%s or more finds it "
                                "used up, and one that used it less starts further down the list."
                                % (key, action, ", ".join(str(p) for p in now), key, action, len(now),
                                   "" if len(now) == 1 else "s"))
            elif was != now and now and len(now) < len(was):
                warnings.append("sites.json sites.%s: the action %s's prices changed (%s -> %s): a save's uses so far "
                                "are kept, so a save that used more than the new list holds finds it used up."
                                % (key, action, ", ".join(str(p) for p in was), ", ".join(str(p) for p in now)))
            elif was != now and (was or now):
                notes.append("sites.json sites.%s: the action %s's prices changed (%s -> %s): a save's uses so far "
                             "are kept, and its next use costs the new list's price at that place."
                             % (key, action, ", ".join(str(p) for p in was) or "free", ", ".join(str(p) for p in now)
                                or "free"))
        old_where, new_where = list(site["where"]), list(new_sites[key]["where"])
        for land in old_where:
            if land not in new_where:
                notes.append("sites.json sites.%s: where no longer names %s: a place already standing there in a "
                             "save stays, and lands not yet visited get none." % (key, land))
        if int(site["gap"]) != int(new_sites[key]["gap"]):
            notes.append("sites.json sites.%s: gap changed (%d -> %d): a place already standing keeps its tile; "
                         "only lands where it is not placed yet use the new gap."
                         % (key, int(site["gap"]), int(new_sites[key]["gap"])))
    old_dungeons, new_dungeons = before["dungeons"], after["dungeons"]
    for key, dungeon in old_dungeons.items():
        if key not in new_dungeons:
            warnings.append("sites.json dungeons: %s (%s) was removed or renamed: saves keep a raised one by its key "
                            "(\"<land>:%s\"); it stays an ordinary dungeon of its land, which the plugin no longer "
                            "knows as its own." % (key, dungeon["name"], key))
        elif new_dungeons[key] != dungeon:
            changed = [field for field in ("name", "color", "size", "rules", "cards", "distance")
                       if new_dungeons[key].get(field) != dungeon.get(field)]
            notes.append("sites.json dungeons: %s changed (%s): one already raised in a save keeps its name, "
                         "creatures, rules and cards; only those raised from now on are the new ones."
                         % (key, ", ".join(changed)))
    for flag in before["flags"]:
        if flag not in after["flags"]:
            notes.append("sites.json flags: %s was renamed or removed: old saves keep it set under the old name, and "
                         "the new version starts without it." % flag)
    for name in before.get("counters", []):
        if name not in after.get("counters", []):
            warnings.append("sites.json counters: %s was renamed or removed: saves keep what it counted under the "
                            "old name, which nothing reads now; a counter of the new name starts at 0." % name)
    for key, site in old_sites.items():
        if key not in new_sites:
            continue
        old_actions, new_actions = _site_actions(site), _site_actions(new_sites[key])
        for action, entry in old_actions.items():
            if action not in new_actions:
                continue
            now = new_actions[action]
            if str(entry["do"]) != str(now["do"]):
                notes.append("sites.json sites.%s: the action %s did %s and now does %s: a save's uses so far are "
                             "kept under its id and count toward the new action's prices."
                             % (key, action, entry["do"], now["do"]))
            was_land = bool(entry["prices"]) and bool(SiteWalk.spawned(entry))
            now_land = bool(now["prices"]) and bool(SiteWalk.spawned(now))
            if now_land and not was_land and len(new_sites[key]["where"]) > 1:
                notes.append("sites.json sites.%s: the action %s now raises a dungeon for a price at a place on the "
                             "mainland and on islands: from now on its uses are counted on each land by itself, and "
                             "a save's uses so far count on the land where its dungeon was raised." % (key, action))
            if "stock" in now and ("stock" not in entry or int(now["stock"]) < int(entry["stock"])):
                notes.append("sites.json sites.%s: the action %s's stock is now %d: a save that traded more of a "
                             "card finds none of it left." % (key, action, int(now["stock"])))
    if int(before["salt"]) != int(after["salt"]):
        notes.append("sites.json salt changed (%d -> %d): places already standing in a save keep their tiles; only "
                     "lands where they are not placed yet, and dungeons raised from now on, draw new ones."
                     % (int(before["salt"]), int(after["salt"])))


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
    if warnings and old["data"].get("kind") == KIND_SITES == new["data"].get("kind"):
        print("%d change%s lose%s progress that saves of %s %s keep, with %s %s." % (
            len(warnings), "" if len(warnings) == 1 else "s", "s" if len(warnings) == 1 else "", old["data"]["id"],
            old["manifest"]["version"], new["data"]["id"], new["manifest"]["version"]))
        return 1
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
                parts.append("a picture key of places.json or sites.json, or a skin picture")
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
        site_files = {name: rule for name, rule in schema.get("site_files", {}).items()
                      if not (name in files and files[name].get("type") == rule.get("type"))}
        shared = [name for name in schema.get("site_files", {}) if name not in site_files]
        mini = ['<li><a href="#manifest">plugin.json</a></li>']
        mini += ['<li><a href="#file-%s">%s</a></li>' % (_e(n.replace(".", "-")), _e(n)) for n in files]
        mini += ['<li><a href="#file-%s">%s</a> (sites)</li>' % (_e(n.replace(".", "-")), _e(n)) for n in site_files]
        mini += ['<li><a href="#types">Named types</a></li>', '<li><a href="#type-condition">Conditions</a></li>',
                 '<li><a href="#type-effect">Effects</a></li>']
        if "sites_condition" in self.types:
            mini += ['<li><a href="#type-sites_condition">Site conditions</a></li>',
                     '<li><a href="#type-sites_effect">Site effects</a></li>']
        mini += ['<li><a href="#placeholders">Placeholders</a></li>',
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
        for name, rule in list(files.items()) + list(site_files.items()):
            spec = self.types[rule["type"]]
            anchor = "file-" + name.replace(".", "-")
            body.append('<section class="ref-file" id="%s-section">' % _e(anchor))
            body.append('<h2 id="%s">%s</h2>' % (_e(anchor), _e(name)))
            if name in site_files:
                body.append("<p>A file of a sites plugin (<code>\"kind\": \"sites\"</code>, API %d), whose "
                            "content is %s and none of an island’s files.%s</p>" % (SITES_API, " and ".join(
                                "<code>%s</code>" % _e(n) for n in schema["site_files"]), "".join(
                                " Its <code>%s</code> is the same file as an island’s: <a href=\"#file-%s\">%s</a>."
                                % (_e(n), _e(n.replace(".", "-")), _e(n)) for n in shared)))
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
        pager = ('<footer class="pager"><a class="prev" href="cheatsheet.html"><span>Previous</span>Places cheat sheet'
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
            ("api_version", "int", True, "", "from 1; this game reads API %d; a sites plugin %d or newer"
             % (API_VERSION, SITES_API),
             "The plugin API it is written for; a newer one than the game reads refuses it."),
            ("kind", "enum", False, "", "%s (the default) or %s" % (KIND_ISLAND, KIND_SITES),
             "What the plugin adds: an island reached by ship, or places that stand on the lands (API %d; a "
             "sites plugin has no region, and its content is sites.json and text.json)." % SITES_API),
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
            ("region", "object", KIND_ISLAND, "", "title (required), castle_name, salt (0 to 2147483647), mana_links, "
             "palette",
             "The island: its title, the castle's name, the salt that makes its island its own, whether mana links "
             "work there, its palette (%s, or a palette object). A sites plugin has none." % ", ".join(PALETTES)),
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
                             _e(n), kind(k), '<span class="req">required</span>' if r is True
                             else '<span class="req">required</span> of an %s' % _e(r) if r else "optional",
                             _e(lim), _e(doc))
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


def guide_frame(guide_dir: Path, page: str) -> tuple[str, str]:
    """(masthead, toc) for the written page [page], copied from the guide's index.html."""
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
            '<li><a href="%s">%s</a></li>' % (name, _e(title)) for name, title in GUIDE_PAGES)
    toc = re.sub(r'\s*aria-current="page"', "", toc)
    toc = re.sub(r'(<a\b[^>]*href="%s")' % re.escape(page), r'\1 aria-current="page"', toc, count=1)
    return masthead, toc


def guide_html(schema: dict, guide_dir: Path) -> str:
    """reference.html, its masthead and toc copied from the guide's index.html."""
    return Reference(schema).page(*guide_frame(guide_dir, "reference.html"))


def command_guide(args, game: Game) -> int:
    schema = game.schema()
    if args.out:
        out = Path(args.out)
    elif game.root is not None:
        out = game.root / FOLDER_NAME / "GUIDE"
    else:
        raise UsageError("Name the guide's folder with --out DIR.")
    pages = {"reference.html": guide_html(schema, out),
             "cheatsheet.html": cheatsheet_html(game, *guide_frame(out, "cheatsheet.html"))}
    stale = 0
    for name, page in pages.items():
        target = out / name
        if args.check:
            current = target.read_text(encoding="utf-8") if target.is_file() else ""
            if current != page:
                print("%s is not what guide writes from the schema now; run: python3 tools/adventure_plugin.py guide"
                      % target)
                stale += 1
            else:
                print("%s is up to date." % target)
            continue
        out.mkdir(parents=True, exist_ok=True)
        target.write_text(page, encoding="utf-8")
        print("Wrote %s (%d bytes)." % (target, len(page.encode("utf-8"))))
    return 1 if stale else 0


# --------------------------------------------------------------------------
# TOOLS FOR PLACES — add-place, add-dungeon (a sites plugin's folder edited),
# walk (its places played without the game), art (its pictures looked at)
# --------------------------------------------------------------------------

## A place's and an action's key (schema_v1.json's sites_key), a dungeon's (id).
SITES_KEY_PATTERN = "^[a-z][a-z0-9_]{0,31}$"
DUNGEON_COLORS = ["black", "blue", "green", "red", "white", "random"]
DUNGEON_SIZES = ["small", "large"]
DUNGEON_RULES = ["no_color", "no_artifacts", "no_instants", "life_carries", "life_adds"]


def _read_json_file(path: Path):
    """A plugin's JSON file as the game reads it, whole numbers kept whole."""
    value, _, message = parse_json(utf8_string(path.read_bytes()).lstrip("﻿"), ints=True)
    if message is not None or not isinstance(value, dict):
        raise UsageError("%s could not be read as one JSON object." % path)
    return value


def _json_bytes(value) -> bytes:
    return (json.dumps(value, indent="\t", ensure_ascii=False) + "\n").encode("utf-8")


def _sites_folder(folder: str, game: Game, command: str) -> tuple[Path, dict, dict, dict]:
    """The valid sites plugin folder [folder] for an editing command:
    (path, manifest, sites.json, text.json), the two files as written."""
    path = Path(_existing(folder))
    if not path.is_dir():
        raise UsageError("%s: %s edits a plugin folder (unzip a zip first)." % (folder, command))
    result = judge(str(path), game)
    if not result["valid"]:
        raise UsageError("%s is refused at the %s stage (%s): make it valid first; see validate."
                         % (folder, result["stage"], result["problems"][0]))
    if manifest_kind(result["manifest"]) != KIND_SITES:
        raise UsageError("%s is an island plugin: %s works on a sites plugin (new --kind sites makes one)."
                         % (folder, command))
    return path, result["manifest"], _read_json_file(path / "sites.json"), _read_json_file(path / "text.json")


def _commit_edit(path: Path, game: Game, writes: dict) -> list:
    """[writes] ({rel: bytes, or None for a file to remove}) written into
    plugin folder [path] and the folder judged; a refused result puts every file back as it was (a new
    one removed) and returns its problems, [] when the plugin is valid."""
    before = {rel: (path / rel).read_bytes() if (path / rel).is_file() else None for rel in writes}
    made = [folder for folder in sorted({(path / rel).parent for rel in writes}) if not folder.exists()]

    def put_back() -> None:
        for rel, data in before.items():
            try:
                if data is None:
                    (path / rel).unlink(missing_ok=True)
                elif not (path / rel).is_file() or (path / rel).read_bytes() != data:
                    _write_whole(path / rel, data)
            except OSError as error:
                print("%s could not be put back: %s" % (path / rel, error), file=sys.stderr)
        for folder in reversed(made):
            try:
                folder.rmdir()
            except OSError:
                pass

    # Anything that stops the edit — a file that cannot be written, a
    # judgement that fails, Ctrl-C — puts every file back before it is
    # passed on: the folder is the old plugin or the new one, never between.
    try:
        for rel, data in writes.items():
            if data is None:
                (path / rel).unlink(missing_ok=True)
                continue
            (path / rel).parent.mkdir(parents=True, exist_ok=True)
            _write_whole(path / rel, data)
        result = judge(str(path), game)
    except OSError as error:
        put_back()
        raise UsageError("%s could not be edited (%s); nothing was changed." % (path, error)) from error
    except BaseException:
        put_back()
        raise
    for note in result["notes"]:
        print("note: " + note, file=sys.stderr)
    if result["valid"]:
        return []
    put_back()
    return result["problems"]


def _write_whole(target: Path, data: bytes) -> None:
    """[data] as [target], whole or not at all: written beside it under a
    dotted name (which a plugin never reads) and moved over it."""
    if target.exists() and not os.access(target, os.W_OK):
        raise PermissionError("%s is read-only" % target.name)
    handle, temporary = tempfile.mkstemp(prefix="." + target.name + ".", suffix=".part", dir=str(target.parent))
    try:
        with os.fdopen(handle, "wb") as sink:
            sink.write(data)
        # A file already there keeps its own permissions; a new one is plain.
        os.chmod(temporary, stat.S_IMODE(os.stat(target).st_mode) if target.exists() else 0o644)
        os.replace(temporary, target)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def _new_texts(text: dict, words: dict) -> None:
    for key in words:
        if key in text:
            raise UsageError("text.json already has %s: choose another id, or remove that text first." % key)
    text.update(words)


def _int_list(value: str, option: str, low: int, high: int) -> list:
    out = []
    for part in value.split(","):
        part = part.strip()
        if not is_valid_int(part) or not low <= int(part) <= high:
            raise UsageError("%s takes whole numbers from %d to %d, joined by commas." % (option, low, high))
        out.append(int(part))
    return out


def _word_list(value: str, option: str, allowed: list) -> list:
    out = []
    for part in value.split(","):
        part = part.strip()
        if part not in allowed:
            raise UsageError("%s takes %s, joined by commas." % (option, ", ".join(allowed)))
        if part not in out:
            out.append(part)
    return out


# ------------------------------------------------ the stand-in looks --

def _look(draw) -> list:
    grid = [["."] * 32 for _ in range(32)]

    def box(x0: int, y0: int, x1: int, y1: int, fill: str, edge: str = "#") -> None:
        for y in range(y0, y1 + 1):
            for x in range(x0, x1 + 1):
                grid[y][x] = edge if x in (x0, x1) or y in (y0, y1) else fill

    draw(grid, box)
    return ["".join(row) for row in grid]


def _tent(grid, box) -> None:
    for y in range(7, 23):
        half = (y - 6) * 11 // 16
        for x in range(15 - half, 17 + half):
            edge = x in (15 - half, 16 + half) or y == 22
            grid[y][x] = "#" if edge else "r" if (x // 3) % 2 == 0 else "w"
    for y in range(16, 22):
        for x in range(14, 18):
            grid[y][x] = "d"
    for y in range(3, 7):
        grid[y][15] = "|"
    grid[3][16] = grid[4][16] = grid[4][17] = "y"


def _stone(grid, box) -> None:
    for y in range(5, 23):
        half = 3 if y in (5, 6) else 4 if y < 10 else 5
        for x in range(16 - half, 16 + half):
            grid[y][x] = "#" if x in (16 - half, 15 + half) or y in (5, 22) else "s"
    for x, y in ((14, 9), (15, 10), (16, 9), (17, 10), (15, 13), (16, 13), (14, 16), (15, 17), (16, 16), (17, 17)):
        grid[y][x] = "d"
    for x in range(8, 24):
        if grid[22][x] == ".":
            grid[22][x] = "g"


def _gate(grid, box) -> None:
    box(6, 8, 10, 22, "s")
    box(21, 8, 25, 22, "s")
    box(5, 5, 26, 8, "s")
    for y in range(9, 22):
        for x in range(11, 21):
            grid[y][x] = "d" if y < 12 else "."
    grid[11][15] = grid[11][16] = "y"
    for x in range(4, 28):
        if grid[22][x] == ".":
            grid[22][x] = "g"


def _ring(grid, box) -> None:
    for x in (5, 12, 19, 26):
        for y in range(14, 23):
            grid[y][x] = "|"
        grid[13][x] = "#"
    for x in range(5, 27):
        for y in (15, 19):
            if grid[y][x] == ".":
                grid[y][x] = "b"
    for y in range(4, 14):
        grid[y][16] = "#"
    for y in range(4, 9):
        for x in range(17, 17 + (9 - y)):
            grid[y][x] = "r"
    for x in range(4, 28):
        if grid[22][x] == ".":
            grid[22][x] = "g"


## The pictures the tool draws for a new place, by name: (sprite rows, colors).
## Each is a small stand-in to paint over; validate says so until it is.
PLACE_LOOKS = {"shrine": (SHRINE_ROWS, SHRINE_COLORS), "tent": (_look(_tent), SHRINE_COLORS),
               "stone": (_look(_stone), SHRINE_COLORS), "gate": (_look(_gate), SHRINE_COLORS),
               "ring": (_look(_ring), SHRINE_COLORS)}


# ----------------------------------------------------------- recipes --

## add-place --recipe: each a whole place that validates and walks, its
## sentences plain ones for the author to rewrite. (name, the look it wears,
## one line for --list-recipes.)
RECIPES = {
    "lore": ("shrine", "a place that tells: a rumor that changes by the day, and a tale behind a talk button"),
    "gift": ("shrine", "a gift given once: food and an amulet, or a card with --card"),
    "healer": ("tent", "a blessing for the next duel behind three prices, and food for gold"),
    "toll": ("gate", "a gate that opens for gold, for an amulet, or for a hero of one color (--color)"),
    "gambler": ("tent", "five throws of the dice at 50 gold: a roll of three outcomes and a counter of plays"),
    "riddle": ("stone", "a riddle with three answers: talk panes, a counter of wrong tries, gold for the right one"),
    "collector": ("tent", "someone who wants a card (--card) and pays for each copy the hero hands over"),
    "duelist": ("ring", "a duel for a wager of gold against the place's own champion, and a counter of wins"),
    "shop": ("tent", "a stall that sells a few cards and buys one"),
    "quest": ("shrine", "an errand: accept it, bring a card (--card), be paid; with a row in the Tasks list"),
    "traveler": ("gate", "a ride for a fare: the hero is carried to the nearest town, or to where the journey began"),
    "teacher": ("stone", "a World Magic taught once for a price, and three lessons that each add a life to every duel"),
}
## What --service named before the recipes: the same three, kept as written.
SERVICES = ["effects", "copy", "none"]
RECIPE_CARD = {"gift": "", "collector": "Llanowar Elves", "quest": "Healing Salve", "shop": "Jayemdae Tome"}
CHAMPION_DECK = {"Mountain": 16, "Lightning Bolt": 4, "Mons's Goblin Raiders": 4, "Ironclaw Orcs": 4, "Gray Ogre": 4,
                 "Hill Giant": 4, "Disintegrate": 2, "Fireball": 2}
## Five plain decks of the base game's cards, 40 each, for a recipe's
## opponent (and the wizard's small menu): one a color.
STOCK_DECKS = {
    "red": CHAMPION_DECK,
    "green": {"Forest": 16, "Llanowar Elves": 4, "Grizzly Bears": 4, "Scryb Sprites": 4, "Giant Growth": 4,
              "War Mammoth": 4, "Craw Wurm": 2, "Giant Spider": 2},
    "white": {"Plains": 16, "Savannah Lions": 4, "Benalish Hero": 4, "White Knight": 4, "Pearled Unicorn": 4,
              "Mesa Pegasus": 4, "Serra Angel": 2, "Swords to Plowshares": 2},
    "blue": {"Island": 16, "Merfolk of the Pearl Trident": 4, "Phantom Monster": 4, "Wall of Air": 4,
             "Unsummon": 4, "Water Elemental": 4, "Air Elemental": 2, "Counterspell": 2},
    "black": {"Swamp": 16, "Drudge Skeletons": 4, "Scathe Zombies": 4, "Black Knight": 4, "Bog Wraith": 4,
              "Terror": 4, "Sengir Vampire": 2, "Dark Ritual": 2},
}
## A recipe's numbers and names: (name, kind, its default, the wizard's
## question). add-place --set NAME=VALUE sets one; the wizard asks each.
RECIPE_OPTIONS = {
    "gift": [("card", "card", "", "A card to give (Enter: five days of food and a white amulet instead)")],
    "healer": [("prices", "prices", [40, 60, 90], "The price of each blessing in gold, in turn, joined by commas")],
    "toll": [("price", "int", 100, "The toll in gold"), ("color", "color", "green", "The hero's color that passes free")],
    "gambler": [("price", "int", 50, "The gold a throw costs"), ("throws", "count", 5, "How many throws before he packs up")],
    "riddle": [("reward", "int", 100, "The gold the right answer pays")],
    "collector": [("card", "card", "Llanowar Elves", "The card the collector wants"),
                  ("pay", "int", 150, "The gold paid for each copy"), ("copies", "count", 3, "How many copies are wanted")],
    "duelist": [("foe", "text", "The Champion", "The opponent's name"),
                ("deck", "deck", "red", "The opponent's deck"), ("life", "life", 20, "The opponent's life (1 to 99)"),
                ("wager", "int", 50, "The gold wagered on each duel"), ("prize", "int", 100, "The gold a win pays"),
                ("bouts", "count", 3, "How many duels before the ring closes")],
    "shop": [("card", "card", "Jayemdae Tome", "A card the stall sells"), ("price", "int", 300, "Its price in gold")],
    "quest": [("card", "card", "Healing Salve", "The card the hero is asked to bring"),
              ("reward", "int", 200, "The gold paid for it")],
}
RECIPE_OPTIONS.update({
    "traveler": [("fare", "int", 100, "The fare in gold"), ("to", "choice", "nearest_town", "Where the ride goes")],
    "teacher": [("magic", "magic", "Dwarven Pick", "The World Magic taught"), ("price", "int", 800, "Its price in gold"),
                ("lesson", "int", 300, "The price of each life lesson in gold")],
})
RECIPE_CHOICES: dict = {"to": {"nearest_town": "the nearest town or city", "start": "where the journey began"}}


def recipe_options(recipe: str, given: dict | None = None) -> dict:
    """A recipe's numbers and names: its own (RECIPE_OPTIONS), with [given]
    laid over them, each checked as its kind asks."""
    out = {}
    known = RECIPE_OPTIONS.get(recipe, [])
    given = dict(given or {})
    for name, kind, default, _ in known:
        value = given.pop(name, default)
        if kind == "int":
            if not is_valid_int(str(value)) or not 0 <= int(value) <= 100000:
                raise UsageError("%s=%s: a whole number from 0 to 100000 is needed." % (name, value))
            value = int(value)
        elif kind == "count":
            if not is_valid_int(str(value)) or not 1 <= int(value) <= 16:
                raise UsageError("%s=%s: a whole number from 1 to 16 is needed." % (name, value))
            value = int(value)
        elif kind == "life":
            if not is_valid_int(str(value)) or not 1 <= int(value) <= 99:
                raise UsageError("%s=%s: a whole number from 1 to 99 is needed." % (name, value))
            value = int(value)
        elif kind == "prices":
            value = _int_list(str(value), name, 0, 1000000) if not isinstance(value, list) else value
        elif kind == "color" and value not in AMULET_COLORS:
            raise UsageError("%s=%s: one of %s is needed." % (name, value, ", ".join(AMULET_COLORS)))
        elif kind == "deck" and value not in STOCK_DECKS:
            raise UsageError("%s=%s: one of %s is needed." % (name, value, ", ".join(STOCK_DECKS)))
        elif kind == "choice" and value not in RECIPE_CHOICES[name]:
            raise UsageError("%s=%s: one of %s is needed." % (name, value, ", ".join(RECIPE_CHOICES[name])))
        elif kind in ("text", "card", "magic"):
            value = strip_edges(str(value))
            if kind != "card" and (not value or len(value) > 60):
                raise UsageError("%s: non-empty text of at most 60 characters is needed." % name)
        out[name] = value
    if given:
        raise UsageError("The recipe %s has no %s (it has: %s)." % (recipe, ", ".join(given),
                                                                    ", ".join(n for n, _, _, _ in known) or "nothing to set"))
    return out


def place_recipe(recipe: str, key: str, name: str, card: str = "", color: str = "green",
                 options: dict | None = None) -> dict:
    """The parts of a recipe's place: {panes, words, flags, counters, foes,
    tasks}; every text key begins with the place's key, every flag and
    counter too. [options]: the recipe's numbers and names (RECIPE_OPTIONS)."""
    given = dict(options or {})
    names = [n for n, _, _, _ in RECIPE_OPTIONS.get(recipe, [])]
    if card and "card" in names:
        given.setdefault("card", card)
    if color and "color" in names:
        given.setdefault("color", color)
    o = recipe_options(recipe, given)
    card, color = o.get("card", card), o.get("color", color)
    k = key + "."
    leave = {"id": "leave", "do": "leave", "label": k + "leave"}
    words = {k + "leave": "Leave"}
    out = {"panes": [], "words": words, "flags": [], "counters": [], "foes": {}, "tasks": {}}

    def named(suffix: str) -> str:
        return (key[:39 - len(suffix)] + "_" + suffix)

    if recipe == "lore":
        told = named("told")
        out["flags"] = [told]
        out["panes"] = [
            {"lines": [k + "intro", {"one_of": [k + "rumor1", k + "rumor2", k + "rumor3"], "by": "day"},
                       {"text": k + "again", "when": [{"flag": told}]}],
             "actions": [{"id": "ask", "do": "talk", "to": "tale", "label": k + "ask",
                          "effects": [{"set_flag": told}, {"log_clue": {"text": k + "clue"}}]}, dict(leave)]},
            {"id": "tale", "lines": [k + "tale1", k + "tale2"], "actions": [dict(leave)]}]
        words.update({
            k + "intro": "%s. An old keeper sits by the door and nods as you come near." % name,
            k + "rumor1": "\"They say the roads east of here are quiet this week,\" the keeper says.",
            k + "rumor2": "\"A merchant came through yesterday, pale as milk. He would not say what he saw.\"",
            k + "rumor3": "\"The wind has turned. The old folk say that means a wizard is on the move.\"",
            k + "again": "The keeper smiles. \"Back for more tales? I have told you my best one.\"",
            k + "ask": "Ask about this place",
            k + "tale1": "\"This place is older than the towns,\" the keeper says. \"It stood here before the five "
                         "wizards raised their castles.\"",
            k + "tale2": "\"Whoever built it left no name. But travelers who rest here say they dream of a road "
                         "that is on no map.\"",
            k + "clue": "The keeper of %s told you its tale." % name})
    elif recipe == "gift":
        gift = [{"give_card": card}] if card else [{"food": 5}, {"amulet": {"color": "white", "count": 1}}]
        out["panes"] = [
            {"when": [{"used_up": "gift"}], "lines": [k + "intro", k + "spent"], "actions": [dict(leave)]},
            {"lines": [k + "intro", k + "offer"],
             "actions": [{"id": "gift", "do": "effects", "label": k + "take", "prices": [0], "effects": gift,
                          "result": [k + "given"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. Someone has left a bundle here, tied with a ribbon, and a note beside it." % name,
            k + "offer": "The note reads: \"For the traveler who needs it. Take it, and remember us kindly.\"",
            k + "take": "Take the bundle",
            k + "given": "You untie the ribbon. Inside: %s." % ("a card, {card}" if card else
                                                               "five days of food, and a white amulet"),
            k + "spent": "The bundle is gone, and so is the note. Only the ribbon is left."})
    elif recipe == "healer":
        out["panes"] = [
            {"lines": [k + "intro", k + "offer", {"text": k + "waiting", "when": [{"gift_waiting": True}]},
                       {"text": k + "spent", "when": [{"used_up": "bless"}]}],
             "actions": [{"id": "bless", "do": "effects", "label": k + "bless", "prices": list(o["prices"]),
                          "when": [{"gift_waiting": False}], "effects": [{"next_duel": {"life": 5}}],
                          "result": [k + "blessed"]},
                         {"id": "bread", "do": "effects", "label": k + "bread", "when": [{"gold_at_least": 10}],
                          "effects": [{"gold": -10}, {"food": 3}], "result": [k + "fed"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. A healer in a gray cloak looks up from her herbs." % name,
            k + "offer": "\"I can lay a blessing on you for your next duel,\" she says, \"or sell you bread for "
                         "the road. You carry {food} days of food.\"",
            k + "waiting": "\"A blessing already rests on you. Fight your duel first; then come back.\"",
            k + "spent": "\"I have no more blessings for you. One traveler may carry only so many from here.\"",
            k + "bless": "Ask for a blessing ({price} gold, {uses_left} left)",
            k + "blessed": "She lays a hand on your brow. You will begin your next duel with five more life.",
            k + "bread": "Buy bread for three days (10 gold)",
            k + "fed": "You pay 10 gold. The bread is still warm. You now carry {food} days of food."})
    elif recipe == "toll":
        opened = named("open")
        out["flags"] = [opened]
        passing = {"effects": [{"set_flag": opened}], "result": [k + "passed"]}
        out["panes"] = [
            {"when": [{"flag": opened}], "lines": [k + "open"],
             "actions": [{"id": "look", "do": "effects", "label": k + "look", "prices": [0],
                          "effects": [{"reveal_map": {"around": "place", "radius": 4}}], "result": [k + "shown"]},
                         dict(leave)]},
            {"lines": [k + "intro", k + "terms", {"text": k + "kin", "when": [{"hero_color": color}]},
                       {"text": k + "late", "when": [{"day_at_least": 30}]}],
             "actions": [dict({"id": "pay", "do": "effects", "label": k + "pay", "prices": [o["price"]]}, **passing),
                         dict({"id": "amulet", "do": "effects", "label": k + "amulet",
                               "needs": [{"amulets": {"color": "any", "count": 1}}],
                               "when": [{"amulets": {"color": "any", "min": 1}}, {"not_flag": opened}]}, **passing),
                         dict({"id": "kin", "do": "effects", "label": k + "kin_pass",
                               "when": [{"hero_color": color}, {"not_flag": opened}]}, **passing), dict(leave)]}]
        words.update({
            k + "intro": "%s. A keeper with a halberd bars the way." % name,
            k + "terms": "\"%d gold opens the gate,\" the keeper says, \"or one amulet. You carry {amulets}.\"" % o["price"],
            k + "kin": "The keeper looks at your colors and lowers the halberd. \"A %s mage? Your kind pass free.\"" % color,
            k + "late": "\"Day {day} of your journey, and you are still on the road? Few last so long.\"",
            k + "pay": "Pay the toll ({price} gold)",
            k + "amulet": "Give one amulet",
            k + "kin_pass": "Pass as kin",
            k + "passed": "The keeper steps aside and the gate swings open.",
            k + "open": "The gate stands open for you now. The keeper nods you through.",
            k + "look": "Climb the gate tower and look around",
            k + "shown": "From the tower you see the land for miles around, and mark it on your map."})
    elif recipe == "gambler":
        plays = named("plays")
        # The house never loses: on average a throw pays back its price.
        small, big = o["price"] * 3 // 2, o["price"] * 3
        out["counters"] = [plays]
        out["panes"] = [
            {"when": [{"used_up": "bet"}], "lines": [k + "intro", k + "spent"], "actions": [dict(leave)]},
            {"lines": [k + "intro", k + "offer", {"text": k + "count", "when": [{"counter": {"name": plays, "min": 1}}]}],
             "actions": [{"id": "bet", "do": "effects", "label": k + "bet", "prices": [o["price"]] * o["throws"],
                          "effects": [{"counter": {"name": plays, "add": 1}},
                                      {"roll": {"outcomes": [
                                          {"weight": 3, "effects": [], "result": [k + "lost"]},
                                          {"weight": 2, "effects": [{"gold": small}], "result": [k + "won"]},
                                          {"weight": 1, "effects": [{"gold": big}], "result": [k + "jackpot"]}]}}],
                          "result": [k + "rolled"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. A man with quick hands rattles three bone dice in a cup." % name,
            k + "offer": "\"%d gold a throw,\" he says. \"Three ways to fall: nothing, %d, or %d. %d throws, and "
                         "then I pack up.\"" % (o["price"], small, big, o["throws"]),
            k + "count": "You have thrown {count} times.",
            k + "bet": "Throw the dice ({price} gold, {uses_left} left)",
            k + "rolled": "You put down {price} gold. The dice rattle and fall.",
            k + "lost": "Low numbers. He sweeps your gold away with a shrug.",
            k + "won": "A fair throw! He counts out %d gold." % small,
            k + "jackpot": "Three sixes! He pays out %d gold and looks at the dice twice." % big,
            k + "spent": "The gambler has packed his cup and dice. \"%d throws, I said. Luck needs its rest.\"" % o["throws"]})
    elif recipe == "riddle":
        solved, tries = named("solved"), named("tries")
        out["flags"], out["counters"] = [solved], [tries]
        wrong = {"do": "talk", "to": "wrong", "effects": [{"counter": {"name": tries, "add": 1}}]}
        out["panes"] = [
            {"when": [{"flag": solved}], "lines": [k + "intro", k + "silent"], "actions": [dict(leave)]},
            {"lines": [k + "intro", k + "riddle", {"text": k + "tries", "when": [{"counter": {"name": tries, "min": 1}}]}],
             "actions": [dict(wrong, id="answer_a", label=k + "answer_a"),
                         {"id": "answer_b", "do": "talk", "to": "right", "label": k + "answer_b",
                          "when": [{"not_flag": solved}], "effects": [{"set_flag": solved}, {"gold": o["reward"]}]},
                         dict(wrong, id="answer_c", label=k + "answer_c"), dict(leave)]},
            {"id": "wrong", "lines": [k + "wrong"], "actions": [dict(leave)]},
            {"id": "right", "lines": [k + "right"], "actions": [dict(leave)]}]
        words.update({
            k + "intro": "%s. Words are cut deep into the rock, and they seem to wait for you." % name,
            k + "riddle": "\"I have cities but no houses, forests but no trees, rivers but no water. What am I?\"",
            k + "tries": "You have answered wrongly {count} times.",
            k + "answer_a": "\"A dream.\"",
            k + "answer_b": "\"A map.\"",
            k + "answer_c": "\"A painting.\"",
            k + "wrong": "The rock stays cold and still. That was not the answer. Come back and try again.",
            k + "right": "The words glow, and a hollow opens in the rock: %d gold lies inside, yours for the answer." % o["reward"],
            k + "silent": "The words have faded. The rock has told its riddle and keeps no other."})
    elif recipe == "collector":
        trades = named("trades")
        out["counters"] = [trades]
        out["panes"] = [
            {"when": [{"used_up": "trade"}], "lines": [k + "intro", k + "spent"], "actions": [dict(leave)]},
            {"lines": [k + "intro", k + "wants", {"text": k + "have", "when": [{"has_card": {"card": card, "min": 1}}]},
                       {"text": k + "count", "when": [{"counter": {"name": trades, "min": 1}}]}],
             "actions": [{"id": "trade", "do": "effects", "label": k + "trade", "prices": [0] * o["copies"],
                          "needs": [{"card": card}], "when": [{"has_card": {"card": card, "min": 1}}],
                          "effects": [{"gold": o["pay"]}, {"counter": {"name": trades, "add": 1}}],
                          "result": [k + "traded"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. A traveler sits among open chests, every one full of cards sorted by color." % name,
            k + "wants": "\"I am looking for %s,\" the collector says. \"I pay %d gold for each copy, and I "
                         "need %d.\"" % (card, o["pay"], o["copies"]),
            k + "have": "The collector's eyes light up. \"You have one! I can see it in your bag.\"",
            k + "count": "You have sold the collector {count} so far.",
            k + "trade": "Hand over {card} for %d gold ({uses_left} left)" % o["pay"],
            k + "traded": "The collector takes {card} with both hands and counts out %d gold." % o["pay"],
            k + "spent": "\"Every copy I wished for. My set is whole,\" the collector says, and closes the chests."})
    elif recipe == "duelist":
        wins, foe = named("wins"), named("champ")
        out["counters"] = [wins]
        out["foes"] = {foe: {"name": o["foe"], "deck_name": "%s's Deck" % o["foe"], "life": o["life"], "face": 3,
                             "deck": dict(STOCK_DECKS[o["deck"]])}}
        out["panes"] = [
            {"when": [{"used_up": "duel"}], "lines": [k + "intro", k + "spent"], "actions": [dict(leave)]},
            {"lines": [k + "intro", k + "offer", {"text": k + "wins", "when": [{"counter": {"name": wins, "min": 1}}]}],
             "actions": [{"id": "duel", "do": "duel", "foe": foe, "label": k + "duel", "prices": [o["wager"]] * o["bouts"],
                          "win": {"effects": [{"gold": o["prize"]}, {"counter": {"name": wins, "add": 1}}],
                                  "result": [k + "won"]},
                          "lose": {"effects": [], "result": [k + "lost"]}}, dict(leave)]}]
        words.update({
            k + "intro": "%s. Ropes mark a square of trampled grass, and a crowd waits around it." % name,
            k + "offer": "The champion leans on the ropes. \"%d gold says you cannot beat me. Win, and you take "
                         "%d. %d bouts, no more.\"" % (o["wager"], o["prize"], o["bouts"]),
            k + "wins": "You have won {count} bouts here.",
            k + "duel": "Wager {price} gold against {foe} ({uses_left} left)",
            k + "won": "The crowd roars. {foe} pays you %d gold without a word." % o["prize"],
            k + "lost": "{foe} pockets your wager. \"Come back when you have learned something.\"",
            k + "spent": "The ropes are down and the crowd has gone home. The champion has no more bouts in him."})
    elif recipe == "shop":
        out["panes"] = [
            {"lines": [k + "intro", k + "offer"],
             "actions": [{"id": "buy", "do": "buy_card", "label": k + "buy", "cards": {card: o["price"], "Rod of Ruin": 200} if card != "Rod of Ruin" else {card: o["price"]},
                          "stock": 1, "result": [k + "bought"]},
                         {"id": "sell", "do": "sell_card", "label": k + "sell", "cards": {"Glasses of Urza": 60},
                          "result": [k + "sold"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. A trader has spread a blanket by the road, a few cards laid out on it under stones." % name,
            k + "offer": "\"One of each, and when they are gone they are gone,\" the trader says. \"And if you carry "
                         "a pair of Glasses of Urza, I pay 60 gold for it.\"",
            k + "buy": "Look at the cards for sale",
            k + "sell": "Sell a card",
            k + "bought": "You pay {price} gold, and {card} is yours.",
            k + "sold": "The trader counts out {price} gold for {card}."})
    elif recipe == "quest":
        asked, done, task = named("asked"), named("done"), named("errand")
        out["flags"] = [asked, done]
        out["tasks"] = {task: {"title": k + "task_title", "text": k + "task_text", "done": k + "task_done",
                               "at": "place:" + key, "when": [{"flag": asked}], "done_when": [{"flag": done}]}}
        out["panes"] = [
            {"when": [{"flag": done}], "lines": [k + "intro", k + "thanks"], "actions": [dict(leave)]},
            {"when": [{"flag": asked}],
             "lines": [k + "intro", k + "waiting", {"text": k + "have", "when": [{"has_card": {"card": card, "min": 1}}]}],
             "actions": [{"id": "give", "do": "effects", "label": k + "give", "prices": [0], "needs": [{"card": card}],
                          "when": [{"has_card": {"card": card, "min": 1}}],
                          "effects": [{"set_flag": done}, {"gold": o["reward"]},
                                      {"log_event": {"event": key, "text": k + "done_log", "done": True}}],
                          "result": [k + "reward"]}, dict(leave)]},
            {"lines": [k + "intro", k + "plea"],
             "actions": [{"id": "accept", "do": "talk", "to": "errand", "label": k + "accept",
                          "effects": [{"set_flag": asked}, {"log_clue": {"text": k + "clue"}}]}, dict(leave)]},
            {"id": "errand", "lines": [k + "errand"], "actions": [dict(leave)]}]
        words.update({
            k + "intro": "%s. A woman waits here, turning a ring on her finger again and again." % name,
            k + "plea": "\"My brother lies sick, and no herb helps,\" she says. \"Only %s could cure him. Will "
                        "you find one for me?\"" % card,
            k + "accept": "Promise to bring it",
            k + "errand": "\"Thank you. Any shop or dungeon may hold one. I will wait here, however long it takes.\"",
            k + "waiting": "\"Have you found %s yet? He grows weaker.\"" % card,
            k + "have": "She sees the card in your bag and catches her breath.",
            k + "give": "Give her {card}",
            k + "reward": "She presses %d gold into your hands. \"It is all we have. He will live, because of you.\"" % o["reward"],
            k + "thanks": "\"He is walking again,\" she says, and for the first time her hands are still.",
            k + "clue": "A woman at %s asked you to bring her %s." % (name, card),
            k + "done_log": "Brought %s to %s." % (card, name),
            k + "task_title": "An errand for %s" % name,
            k + "task_text": "Bring %s to %s." % (card, name),
            k + "task_done": "Done: %s was brought to %s." % (card, name)})
    elif recipe == "traveler":
        town = o["to"] == "nearest_town"
        out["panes"] = [
            {"lines": [k + "intro", k + "offer"],
             "actions": [{"id": "ride", "do": "effects", "label": k + "ride", "when": [{"gold_at_least": o["fare"]}],
                          "effects": [{"gold": -o["fare"]}, {"teleport": {"to": o["to"]}}]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. A carter waits beside a cart with high wheels, the mule already in harness." % name,
            k + "offer": "\"%d gold, and I take you %s,\" the carter says. \"No questions, no stops. You carry {gold}.\""
                         % (o["fare"], "to {town}" if town else "back to where your road began"),
            k + "ride": "Ride to %s (%d gold)" % ("{town}" if town else "where your journey began", o["fare"])})
        if town:
            # {town} is the action's own: the pane's line names no town.
            words[k + "offer"] = "\"%d gold, and I take you to the nearest town,\" the carter says. \"No questions, " \
                                 "no stops. You carry {gold}.\"" % o["fare"]
    elif recipe == "teacher":
        out["panes"] = [
            {"lines": [k + "intro", k + "offer", {"text": k + "known", "when": [{"owns_magic": o["magic"]}]},
                       {"text": k + "lessons", "when": [{"life_bonus_below": MOST_LIFE_BONUS}]}],
             "actions": [{"id": "learn", "do": "effects", "label": k + "learn", "prices": [o["price"]],
                          "effects": [{"world_magic": o["magic"]}], "result": [k + "learned"]},
                         {"id": "lesson", "do": "effects", "label": k + "lesson", "prices": [o["lesson"]] * 3,
                          "when": [{"life_bonus_below": MOST_LIFE_BONUS}], "effects": [{"life_bonus": 1}],
                          "result": [k + "stronger"]}, dict(leave)]}]
        words.update({
            k + "intro": "%s. An old mage sits cross-legged on a flat rock, eyes closed, and speaks before you do." % name,
            k + "offer": "\"I teach one thing that can be carried, and one that cannot,\" the mage says. \"%s, for "
                         "%d gold. And the long breath, which adds to your life in every duel.\"" % (o["magic"], o["price"]),
            k + "known": "The mage opens one eye. \"%s is yours already. That lesson is done.\"" % o["magic"],
            k + "lessons": "\"The long breath has given you {life_bonus} more life so far. No one learns more than ten.\"",
            k + "learn": "Learn {title} ({price} gold)",
            k + "learned": "The mage speaks for an hour, and draws one sign in the dust. {title} is yours.",
            k + "lesson": "Take a lesson in the long breath ({price} gold, {uses_left} left)",
            k + "stronger": "You breathe as you are told until the stars come out. You will begin every duel with "
                            "{life_bonus} more life than before you met the mage."})
    return out


def _quoted(path) -> str:
    """A path as a shell takes it: quoted when it holds a space or the like."""
    import shlex
    return shlex.quote(str(path))


def _finish_edit(args, path: Path, game: Game, manifest: dict, sites: dict, text: dict, files: dict,
                 what: str) -> list:
    """An editing command's last step: sites.json and text.json written with
    [files] ({rel: bytes, or None for a file to remove}), plugin.json given
    api_version 3 when the edit brings a word of API 3, the folder judged,
    and everything put back when the game would refuse it. [] when done;
    else the problems, already printed with [what] was not done."""
    files = dict(files)
    files.update({"sites.json": _json_bytes(sites), "text.json": _json_bytes(text)})
    after = dict(read_package(str(path))["files"])
    for rel, data in files.items():
        if data is None:
            after.pop(rel, None)
        else:
            after[rel] = data
    words = api_words_of(game, manifest, after)
    raised = bool(words) and whole(manifest.get("api_version")) and int(manifest["api_version"]) < SITES_WORDS_API
    older = False
    if raised:
        raw = _read_json_file(path / MANIFEST)
        raw["api_version"] = SITES_WORDS_API
        older = not valid_version(str(raw.get("minimum_game_version", ""))) \
            or compare_versions(str(raw["minimum_game_version"]), SITES_WORDS_GAME) < 0
        if older:
            raw["minimum_game_version"] = SITES_WORDS_GAME
        files[MANIFEST] = _json_bytes(raw)
    problems = _commit_edit(path, game, files)
    if problems:
        for problem in problems:
            print(problem)
        print("%s: %s; nothing was changed." % (args.folder, what), file=sys.stderr)
        return problems
    if raised:
        print("plugin.json: api_version is now %d, because the plugin now uses %s: it needs a game that reads "
              "API %d (an older game refuses it in one line and plays on without it)."
              % (SITES_WORDS_API, words[0], SITES_WORDS_API))
        if older:
            print("plugin.json: minimum_game_version is now %s, the first game that reads API %d."
                  % (SITES_WORDS_GAME, SITES_WORDS_API))
    return []


def _place_of(sites: dict, folder: str, key: str) -> dict:
    place = sites.get("sites", {}).get(key)
    if not isinstance(place, dict):
        raise UsageError("%s has no place %s (its places: %s)." % (folder, key, ", ".join(sites.get("sites", {}))))
    return place


def _home_pane(place: dict) -> dict:
    """The pane a place shows when nothing else holds: its last without an id."""
    plain = [pane for pane in place["panes"] if "id" not in pane]
    return plain[-1] if plain else place["panes"][-1]


def _leave_of(place: dict) -> dict:
    return next((dict(action) for pane in place["panes"] for action in pane.get("actions", [])
                 if action.get("do") == "leave"), {"id": "leave", "do": "leave"})


def _free_key(text: dict, stem: str) -> str:
    """[stem], or stem2, stem3 … — the first text.json does not hold."""
    key, n = stem, 1
    while key in text:
        n += 1
        key = "%s%d" % (stem, n)
    if re.search("^[a-z0-9_.]{1,64}$", key) is None:
        raise UsageError("The text key %s would be too long (64 characters are the most): choose shorter ids." % key)
    return key


def _say(text: dict, stem: str, words: str) -> str:
    """[words] put into text.json under a new key from [stem]; the key."""
    words = strip_edges(words)
    if not words or len(words) > MAX_TEXT:
        raise UsageError("A sentence must be non-empty text of at most %d characters." % MAX_TEXT)
    key = _free_key(text, stem)
    text[key] = words
    return key


def _range(value: str, option: str) -> tuple:
    """"3" -> (3, None); "3-5" -> (3, 5)."""
    low, dash, high = value.partition("-")
    if not is_valid_int(low.strip()) or (dash and not is_valid_int(high.strip())):
        raise UsageError("%s: %s is not a number or a range like 1-3." % (option, value))
    return int(low), int(high) if dash else None


def _truth(value: str, option: str) -> bool:
    if value.strip().lower() in ("true", "yes", "1", ""):
        return True
    if value.strip().lower() in ("false", "no", "0"):
        return False
    raise UsageError("%s takes true or false." % option)


def parse_condition(words: str, game: Game) -> dict:
    """One --when: "flag=told", "counter=wins:3", "has_card=Black Lotus",
    "used=bless:1-2", "dungeon=vault:open", "site_used=hut.secret"; several
    joined by " | " make an any (one of them holds)."""
    if " | " in words:
        return {"any": [parse_condition(part, game) for part in words.split(" | ")]}
    name, sign, value = words.partition("=")
    name, value = name.strip(), value.strip()
    options = game.schema()["types"]["sites_condition"]["options"]
    if name not in options or name == "any":
        raise UsageError("--when %s: no such condition (the conditions: %s)." % (words, ", ".join(o for o in options if o != "any")))
    spec = options[name]
    while spec.get("kind") == "ref":
        spec = game.schema()["types"][spec["type"]]
    kind = spec.get("kind")
    option = "--when " + name
    if kind == "bool":
        return {name: _truth(value, option)}
    if not sign or not value:
        raise UsageError("%s needs a value, like --when %s=%s." % (option, name, "5" if kind == "int" else "name"))
    if kind == "int":
        if not is_valid_int(value):
            raise UsageError("%s takes a whole number." % option)
        return {name: int(value)}
    if kind != "object":
        return {name: value}
    head, colon, tail = value.rpartition(":") if name == "has_card" and value.rpartition(":")[2].strip().isdigit() \
        else value.partition(":") if name != "has_card" else (value, "", "")
    head, tail = (head if colon else value).strip(), tail.strip()
    if name == "has_card":
        return {name: dict({"card": head}, **({"min": int(tail)} if tail else {}))}
    if name == "amulets":
        return {name: dict({"color": head}, **({"min": _range(tail, option)[0]} if tail else {}))}
    if name == "dungeon":
        return {name: {"dungeon": head, "state": tail or "open"}}
    if name == "difficulty":
        low, high = _range(value, option)
        return {name: {"min": low, "max": low if high is None else high}}
    out: dict = {}
    if name == "site_used":
        site, dot, action = head.partition(".")
        if not dot:
            raise UsageError("%s names a place and its action: --when site_used=PLACE.ACTION." % option)
        out = {"site": site, "action": action}
    elif name == "used":
        out = {"action": head}
    elif name == "counter":
        out = {"name": head}
    else:
        raise UsageError("%s cannot be written on the command line; write it in sites.json." % option)
    if tail:
        low, high = _range(tail, option)
        out["min"] = low
        if high is not None:
            out["max"] = high
    elif name in ("used", "counter"):
        out["min"] = 1
    return {name: out}


def parse_effect(words: str, game: Game, text: dict, stem: str) -> dict:
    """One --effect: "gold=50", "food=6", "set_flag=told", "counter=wins+1",
    "counter=wins:0" (set), "amulet=red", "amulet=red:2", "give_card=Shivan
    Dragon", "next_duel=life:5", "next_duel=first_move", "next_duel=card:King
    Suleiman", "spawn_dungeon=vault", "reveal_map=place:4", "log_clue=the
    words", "log_event=the words"."""
    name, sign, value = words.partition("=")
    name, value = name.strip(), value.strip()
    options = game.schema()["types"]["sites_effect"]["options"]
    if name not in options or name == "roll":
        raise UsageError("--effect %s: no such effect (the effects: %s; a roll is made of --outcome)."
                         % (words, ", ".join(o for o in options if o != "roll")))
    option = "--effect " + name
    if not sign or not value:
        raise UsageError("%s needs a value, like --effect %s=..." % (option, name))
    if name in ("gold", "food"):
        if not is_valid_int(value.lstrip("+")):
            raise UsageError("%s takes a whole number, like %s=50 or %s=-10." % (option, name, name))
        return {name: int(value.lstrip("+"))}
    if name == "counter":
        found = re.search(r"^([a-z][a-z0-9_]*)\s*([+\-:])\s*(\d+)$", value)
        if found is None:
            raise UsageError("%s takes NAME+N, NAME-N or NAME:N (set to N), like counter=wins+1." % option)
        amount = int(found.group(3))
        return {name: {"name": found.group(1), "set": amount} if found.group(2) == ":" else
                {"name": found.group(1), "add": amount if found.group(2) == "+" else -amount}}
    if name == "amulet":
        color, colon, count = value.partition(":")
        if colon and not is_valid_int(count.strip()):
            raise UsageError("%s takes COLOR or COLOR:N, like amulet=red:2." % option)
        return {name: {"color": color.strip(), "count": int(count) if colon else 1}}
    if name == "next_duel":
        kind, _, rest = value.partition(":")
        kind, rest = kind.strip(), rest.strip()
        if kind == "life" and is_valid_int(rest):
            return {name: {"life": int(rest)}}
        if kind == "first_move":
            return {name: {"first_move": True}}
        if kind == "card" and rest:
            return {name: {"card": rest}}
        raise UsageError("%s takes life:N, first_move or card:NAME." % option)
    if name == "reveal_map":
        around, colon, radius = value.rpartition(":") if value.rpartition(":")[2].strip().isdigit() else (value, "", "")
        around = (around if colon else value).strip()
        return {name: dict({"around": around}, **({"radius": int(radius)} if colon else {}))}
    if name == "life_bonus":
        if not is_valid_int(value):
            raise UsageError("%s takes a whole number, like life_bonus=1." % option)
        return {name: int(value)}
    if name == "teleport":
        return {name: {"to": value}}
    if name == "log_clue":
        return {name: {"text": _say(text, stem + "_clue", value)}}
    if name == "log_event":
        return {name: {"event": stem.split(".")[0], "text": _say(text, stem + "_log", value)}}
    return {name: value}


def parse_need(words: str) -> dict:
    """One --needs: "card=Black Lotus", "amulets=any:3", "amulets=red", "food=5"."""
    name, sign, value = words.partition("=")
    name, value = name.strip(), value.strip()
    if name == "card" and value:
        return {"card": value}
    if name == "food" and is_valid_int(value):
        return {"food": int(value)}
    if name == "amulets" and value:
        color, colon, count = value.partition(":")
        if not colon or is_valid_int(count.strip()):
            return {"amulets": {"color": color.strip(), "count": int(count) if colon else 1}}
    raise UsageError("--needs %s: a need is card=NAME, amulets=COLOR:N (COLOR may be any) or food=N." % words)


def parse_card_prices(words: str, option: str) -> dict:
    """--cards "Shivan Dragon=400; Rod of Ruin=200" as {card: price}."""
    out = {}
    for part in words.split(";"):
        card, sign, price = part.rpartition("=")
        if not part.strip():
            continue
        if not sign or not card.strip() or not is_valid_int(price.strip()):
            raise UsageError("%s takes cards and prices joined by ;, like \"Shivan Dragon=400; Rod of Ruin=200\"." % option)
        out[card.strip()] = int(price)
    if not out:
        raise UsageError("%s names at least one card and its price." % option)
    return out


ACTION_KINDS = {"effects": "effects", "talk": "talk", "duel": "duel", "copy": "copy_card", "copy_card": "copy_card",
                "buy": "buy_card", "buy_card": "buy_card", "sell": "sell_card", "sell_card": "sell_card",
                "leave": "leave"}


def command_add_action(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "add-action")
    place = _place_of(sites, args.folder, args.place)
    name = args.id
    if re.search(SITES_KEY_PATTERN, name) is None:
        raise UsageError("--id must be 1 to 32 lower-case letters, digits or _, a letter first.")
    if name in _site_actions(place):
        raise UsageError("The place %s already has an action %s (its actions: %s)."
                         % (args.place, name, ", ".join(_site_actions(place))))
    do = ACTION_KINDS[args.do]
    if args.prices and args.free:
        raise UsageError("--prices and --free: an action has prices or is free; name one.")
    stem = "%s.%s" % (args.place, name)
    action: dict = {"id": name, "do": do}
    if args.label:
        action["label"] = _say(text, stem, args.label)
    elif do == "effects" and not args.prices:
        action["label"] = _say(text, stem, name.replace("_", " ").capitalize())
    if args.when:
        action["when"] = [parse_condition(words, game) for words in args.when]
    if args.prices:
        action["prices"] = _int_list(args.prices, "--prices", 0, 1000000)
    if args.needs:
        action["needs"] = [parse_need(words) for words in args.needs]
    effects = [parse_effect(words, game, text, stem) for words in args.effect]
    if args.outcome:
        outcomes = []
        for n, words in enumerate(args.outcome):
            parts = [part.strip() for part in words.split("|")]
            if len(parts) != 3 or not is_valid_int(parts[0]):
                raise UsageError("--outcome takes \"WEIGHT | EFFECTS | WORDS\", like --outcome \"2 | gold=75 | A fair "
                                 "throw!\" (effects joined by ;, or none).")
            outcome = {"weight": int(parts[0]),
                       "effects": [parse_effect(part, game, text, "%s_roll%d" % (stem, n + 1))
                                   for part in parts[1].split(";") if part.strip()]}
            if parts[2]:
                outcome["result"] = [_say(text, "%s_roll%d" % (stem, n + 1), parts[2])]
            outcomes.append(outcome)
        effects.append({"roll": {"outcomes": outcomes}})
    if effects:
        action["effects"] = effects
    if args.result:
        action["result"] = [_say(text, stem + "_done", args.result)]
    if do == "talk":
        if not args.to:
            raise UsageError("--do talk needs --to: the id of the pane it opens (add-pane --id makes one).")
        action["to"] = args.to
    elif args.to:
        raise UsageError("--to belongs to --do talk.")
    if do == "duel":
        if not args.foe:
            raise UsageError("--do duel needs --foe: a foe of sites.json foes (add-foe makes one).")
        action["foe"] = args.foe
        for side, effect_words, said in (("win", args.win_effect, args.win), ("lose", args.lose_effect, args.lose)):
            branch: dict = {}
            if effect_words:
                branch["effects"] = [parse_effect(words, game, text, "%s_%s" % (stem, side)) for words in effect_words]
            if said:
                branch["result"] = [_say(text, "%s_%s" % (stem, "won" if side == "win" else "lost"), said)]
            if branch:
                action[side] = branch
        if args.count:
            action["count"] = args.count
    elif args.foe or args.win or args.lose or args.win_effect or args.lose_effect or args.count:
        raise UsageError("--foe, --win, --lose, --win-effect, --lose-effect and --count belong to --do duel.")
    if do in ("buy_card", "sell_card"):
        if not args.cards:
            raise UsageError("--do %s needs --cards \"NAME=PRICE; NAME=PRICE\"." % args.do)
        action["cards"] = parse_card_prices(args.cards, "--cards")
        if args.stock is not None:
            action["stock"] = args.stock
    elif args.cards or args.stock is not None:
        raise UsageError("--cards and --stock belong to --do buy and --do sell.")
    panes = place["panes"]
    everywhere = args.pane == "all"
    if everywhere:
        target = _home_pane(place)
    elif args.pane:
        target = next((pane for pane in panes if pane.get("id") == args.pane), None)
        if target is None and is_valid_int(args.pane) and 0 <= int(args.pane) < len(panes):
            target = panes[int(args.pane)]
        if target is None:
            raise UsageError("--pane %s: the place %s has no such pane (by number 0 to %d%s)."
                             % (args.pane, args.place, len(panes) - 1,
                                "".join(", or by id " + str(p["id"]) for p in panes if "id" in p)))
    else:
        target = _home_pane(place)
    # --pane all: in every pane the place shows by itself, so a pane with a
    # when (a service used up, a dungeon open) does not hide the button.
    for pane in ([p for p in panes if "id" not in p] if everywhere else [target]):
        buttons = pane.setdefault("actions", [])
        at = next((i for i, entry in enumerate(buttons) if entry.get("do") == "leave"), len(buttons))
        buttons.insert(at, dict(action))
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the action was not added"):
        return 1
    print("Added the action %s (%s) to the place %s, in %s: %s." % (
        name, do, args.place, "every pane without an id" if everywhere else "pane %d%s" % (
            panes.index(target), " (id %s)" % target["id"] if "id" in target else ""),
        "for %s gold" % ", ".join(str(p) for p in action["prices"]) if action.get("prices") else "free, never used up"))
    print("Next: see it played\n    python3 tools/adventure_plugin.py walk %s --site %s" % (_quoted(args.folder), args.place))
    return 0


def command_add_pane(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "add-pane")
    place = _place_of(sites, args.folder, args.place)
    if not args.id and not args.when:
        raise UsageError("A new pane needs --id (a talk action opens it) or --when (it is shown while that holds): "
                         "a second pane with neither would never be shown.")
    if args.id and re.search(SITES_KEY_PATTERN, args.id) is None:
        raise UsageError("--id must be 1 to 32 lower-case letters, digits or _, a letter first.")
    if args.id and any(pane.get("id") == args.id for pane in place["panes"]):
        raise UsageError("The place %s already has a pane with the id %s." % (args.place, args.id))
    if not args.line:
        raise UsageError("A pane needs at least one --line \"words\".")
    stem = "%s.%s" % (args.place, args.id if args.id else "pane%d" % (len(place["panes"]) + 1))
    pane: dict = {}
    if args.id:
        pane["id"] = args.id
    if args.when:
        pane["when"] = [parse_condition(words, game) for words in args.when]
    if args.title:
        pane["title"] = _say(text, stem + "_title", args.title)
    if args.subtitle:
        pane["subtitle"] = _say(text, stem + "_subtitle", args.subtitle)
    pane["lines"] = [_say(text, "%s_line%d" % (stem, n + 1), words) for n, words in enumerate(args.line)]
    pane["actions"] = [_leave_of(place)]
    panes = place["panes"]
    if args.when and not args.id:
        # Before the pane without a when: the first pane whose when holds is shown.
        panes.insert(panes.index(_home_pane(place)), pane)
    else:
        panes.append(pane)
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the pane was not added"):
        return 1
    print("Added pane %d to the place %s%s: %d line%s (%s_line*), and its Leave." % (
        panes.index(pane), args.place, ", id %s" % args.id if args.id else ", shown while its when holds",
        len(pane["lines"]), "" if len(pane["lines"]) == 1 else "s", stem))
    if args.id:
        print("Next: a button that opens it\n    python3 tools/adventure_plugin.py add-action %s --place %s --id ask "
              "--do talk --to %s --label \"Ask\"" % (_quoted(args.folder), args.place, args.id))
    return 0


def _command_add_name(args, game: Game, part: str, command: str) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, command)
    if re.search(ID_PATTERN, args.name) is None:
        raise UsageError("A %s's name is 1 to 40 lower-case letters, digits or _, a letter first." % part[:-1])
    names = sites.setdefault(part, [])
    if args.name in names:
        raise UsageError("%s already has the %s %s." % (args.folder, part[:-1], args.name))
    names.append(args.name)
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the %s was not added" % part[:-1]):
        return 1
    if part == "flags":
        print("Added the flag %s to %s: off at the start of a campaign. Set it with --effect set_flag=%s, read it "
              "with --when flag=%s or --when not_flag=%s." % (args.name, args.folder, args.name, args.name, args.name))
    else:
        print("Added the counter %s to %s: 0 at the start of a campaign. Change it with --effect counter=%s+1, read "
              "it with --when counter=%s:3 (3 or more), show it with {count}."
              % (args.name, args.folder, args.name, args.name))
    return 0


def command_add_flag(args, game: Game) -> int:
    return _command_add_name(args, game, "flags", "add-flag")


def command_add_counter(args, game: Game) -> int:
    return _command_add_name(args, game, "counters", "add-counter")


def read_deck_list(path: Path) -> dict:
    """A deck list file, one card a line — "4 Lightning Bolt", "4x Lightning
    Bolt" or "Lightning Bolt" (one); empty lines and lines beginning with #
    or // are passed over — as {card: copies}."""
    try:
        lines = utf8_string(path.read_bytes()).lstrip("﻿").splitlines()
    except OSError as error:
        raise UsageError("%s could not be read (%s)." % (path, error)) from error
    deck: dict = {}
    for number, line in enumerate(lines, 1):
        line = line.strip()
        if not line or line.startswith("#") or line.startswith("//"):
            continue
        found = re.search(r"^(\d+)\s*[xX]?\s+(.+)$", line)
        copies, card = (int(found.group(1)), found.group(2).strip()) if found else (1, line)
        if copies < 1 or copies > 40:
            raise UsageError("%s line %d: %d copies; 1 to 40 of a card are allowed." % (path, number, copies))
        deck[card] = deck.get(card, 0) + copies
    if not deck:
        raise UsageError("%s holds no cards: write one card a line, like \"4 Lightning Bolt\"." % path)
    return deck


def command_add_foe(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "add-foe")
    if re.search(ID_PATTERN, args.id) is None:
        raise UsageError("--id must be 1 to 40 lower-case letters, digits or _, a letter first.")
    if args.id in sites.get("foes", {}) and not args.replace:
        raise UsageError("%s already has a foe %s (--replace gives that foe this name, life and deck)."
                         % (args.folder, args.id))
    name = strip_edges(args.name)
    if not name or len(name) > 60:
        raise UsageError("--name must be non-empty text of at most 60 characters.")
    deck = read_deck_list(Path(args.deck))
    foe = {"name": name, "life": args.life, "face": args.face, "deck": deck}
    if args.deck_name:
        foe["deck_name"] = strip_edges(args.deck_name)
    replaced = args.id in sites.get("foes", {})
    sites.setdefault("foes", {})[args.id] = foe
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the foe was not added"):
        return 1
    print("%s the foe %s (%s) %s %s: %d life, a deck of %d cards (%d different), the face of creature row %d."
          % ("Replaced" if replaced else "Added", args.id, name, "of" if replaced else "to", args.folder, args.life,
             sum(deck.values()), len(deck), args.face))
    print("Next: a button that fights it\n    python3 tools/adventure_plugin.py add-action %s --place PLACE --id duel "
          "--do duel --foe %s --prices 50 --win-effect gold=100 --win \"You win.\" --lose \"You lose.\""
          % (_quoted(args.folder), args.id))
    return 0


def command_set_text(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "set-text")
    if re.search("^[a-z0-9_.]{1,64}$", args.key) is None:
        raise UsageError("A text key is 1 to 64 of a-z, 0-9, _ and . (like shrine.intro); %s is not." % args.key)
    words = strip_edges(args.words)
    if not words or len(words) > MAX_TEXT:
        raise UsageError("The words must be non-empty text of at most %d characters." % MAX_TEXT)
    was = text.get(args.key)
    text[args.key] = words
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the text was not set"):
        return 1
    if was is None:
        print("Set the new text %s in %s%s." % (args.key, args.folder, "" if args.key in TEXT_DEFAULTS else
                                                 "; name it in a pane's lines or an action to show it"))
    else:
        print("Changed the text %s in %s (it was: %s)." % (args.key, args.folder, was))
    if args.key in TEXT_DEFAULTS and was is None:
        print("It replaces the game's own sentence (\"%s\") in this plugin's places." % TEXT_DEFAULTS[args.key])
    return 0


def command_set_info(args, game: Game) -> int:
    """plugin.json's own words — name, description, license, authors,
    version, learning note — set without opening the file."""
    path = Path(_existing(args.folder))
    if not path.is_dir():
        raise UsageError("%s: set-info edits a plugin folder (unzip a zip first)." % args.folder)
    result = judge(str(path), game)
    if not result["valid"]:
        raise UsageError("%s is refused at the %s stage (%s): make it valid first; see validate."
                         % (args.folder, result["stage"], result["problems"][0]))
    raw = _read_json_file(path / MANIFEST)
    changed = []
    for field, value in (("name", args.name), ("description", args.description), ("license", args.license),
                         ("version", args.plugin_version), ("learning_note", args.note)):
        if value:
            raw[field] = strip_edges(value)
            changed.append(field)
    if args.author:
        raw["authors"] = [strip_edges(author) for author in args.author]
        changed.append("authors")
    if not changed:
        raise UsageError("set-info needs something to set: --name, --description, --license, --author, --version "
                         "or --note.")
    problems = _commit_edit(path, game, {MANIFEST: _json_bytes(raw)})
    if problems:
        for problem in problems:
            print(problem)
        print("%s: plugin.json was not changed." % args.folder, file=sys.stderr)
        return 1
    print("Set %s in %s's plugin.json." % (", ".join(changed), args.folder))
    if "version" in changed:
        print("A new version of a plugin players already have: see what it does to their saves with compat OLD NEW.")
    return 0


def command_remove_place(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "remove-place")
    place = _place_of(sites, args.folder, args.id)
    if len(sites["sites"]) == 1:
        raise UsageError("%s is the plugin's only place, and a sites plugin has at least one: add another first."
                         % args.id)
    del sites["sites"][args.id]
    rest = json.dumps(sites, ensure_ascii=False)
    files: dict = {}
    gone = []
    pictures = sites.get("pictures", {})
    for key in {str(place.get("picture", ""))} | {str(pane.get("picture", "")) for pane in place["panes"]}:
        if key in pictures and '"%s"' % key not in rest.replace('"%s": ' % key, ""):
            rel = pictures.pop(key)
            if rel not in pictures.values():
                files[rel] = None
                gone.append(rel)
    sprite = str(place.get("sprite", {}).get("file", ""))
    rest = json.dumps(sites, ensure_ascii=False)
    if sprite and '"%s"' % sprite not in rest:
        files[sprite] = None
        gone.append(sprite)
    was = json.dumps(place, ensure_ascii=False)
    also = []
    for entry, task in list(sites.get("tasks", {}).items()):
        if task.get("at") == "place:" + args.id:
            del sites["tasks"][entry]
            also.append("the task %s" % entry)
    for entry in list(sites.get("foes", {})):
        if '"foe": "%s"' % entry in was and '"foe": "%s"' % entry not in rest:
            del sites["foes"][entry]
            also.append("the foe %s" % entry)
    rest = json.dumps(sites, ensure_ascii=False)
    for group in ("flags", "counters"):
        for entry in list(sites.get(group, [])):
            # Named by the place, and by nothing that is left (its own
            # declaration is the one mention [rest] still holds).
            if '"%s"' % entry in was and rest.count('"%s"' % entry) <= 1:
                sites[group].remove(entry)
                also.append("the %s %s" % (group[:-1], entry))
    rest = json.dumps(sites, ensure_ascii=False)
    dropped = [key for key in text if key.startswith(args.id + ".") and '"%s"' % key not in rest]
    for key in dropped:
        del text[key]
    if _finish_edit(args, path, game, manifest, sites, text, files, "the place was not removed"):
        return 1
    print("Removed the place %s (%s) from %s: %d text%s (%s.*) and %s." % (
        args.id, place.get("name", ""), args.folder, len(dropped), "" if len(dropped) == 1 else "s", args.id,
        ", ".join(gone) if gone else "no picture file"))
    if also:
        print("Removed with it, since nothing else used them: %s." % ", ".join(also))
    print("Its dungeons stay in sites.json; validate names what nothing uses now. Saves made with the place keep "
          "its tile and uses, which nothing reads now (see compat).")
    return 0


def command_add_place(args, game: Game) -> int:
    if args.list_recipes:
        for recipe, (_, line) in RECIPES.items():
            print("%-10s %s" % (recipe, line))
        return 0
    if not args.folder or not args.id or not args.name:
        raise UsageError("add-place needs a plugin folder, --id and --name (or --list-recipes alone).")
    path, manifest, sites, text = _sites_folder(args.folder, game, "add-place")
    ident, key = str(manifest["id"]), args.id
    if re.search(SITES_KEY_PATTERN, key) is None:
        raise UsageError("--id must be 1 to 32 lower-case letters, digits or _, a letter first.")
    if key in sites.get("sites", {}):
        raise UsageError("%s already has a place %s." % (args.folder, key))
    name = strip_edges(args.name)
    if not name or len(name) > 60:
        raise UsageError("--name must be non-empty text of at most 60 characters.")
    where = _word_list(args.where, "--where", ["mainland", "islands"])
    if args.recipe and args.service:
        raise UsageError("--recipe and --service: a place is made from one; name one.")
    if args.recipe and (args.prices or args.free):
        raise UsageError("--prices and --free belong to --service; a recipe sets its own prices (edit them in "
                         "sites.json).")
    service = args.service or "effects"
    if service == "none" and (args.prices or args.free):
        raise UsageError("--prices needs a service: --service effects or --service copy.")
    if args.prices and args.free:
        raise UsageError("--prices and --free: a service has prices or is free; name one.")
    prices = _int_list(args.prices, "--prices", 0, 1000000) if args.prices else \
        [] if args.free else {"effects": [100], "copy": [500], "none": []}[service]
    picture = "%s_%s" % (ident, key)
    if re.search(ID_PATTERN, picture) is None:
        # Its picture's key is the plugin's id, _ and the place's id, and a
        # picture key is at most 40 characters (the schema's id).
        raise UsageError("--id %s is too long for this plugin: with the plugin's id (%s) its picture key would be "
                         "%d characters, and 40 are the most%s."
                         % (key, ident, len(picture), "; choose an id of at most %d characters" % (39 - len(ident))
                            if len(ident) < 39 else "; this plugin's id leaves no room for one"))
    look = args.look or (RECIPES[args.recipe][0] if args.recipe else "shrine")
    rows, colors = PLACE_LOOKS[look]
    files = {"art/%s.png" % picture: _site_picture(rows, colors), "art/%s_map.png" % picture: _sprite(rows, colors)}
    if picture in sites.get("pictures", {}):
        raise UsageError("sites.json already has a picture %s." % picture)
    for rel in files:
        if (path / rel).exists():
            raise UsageError("%s already exists in %s." % (rel, args.folder))
    made = ""
    if args.recipe:
        card = strip_edges(args.card)
        if args.card and args.recipe not in RECIPE_CARD:
            raise UsageError("--card belongs to the recipes %s." % ", ".join(RECIPE_CARD))
        if args.color and args.recipe != "toll":
            raise UsageError("--color belongs to the recipe toll.")
        chosen = dict(getattr(args, "recipe_options", None) or {})
        for words in args.set:
            option, sign, value = words.partition("=")
            if not sign:
                raise UsageError("--set takes NAME=VALUE, like --set price=75.")
            chosen[option.strip()] = value.strip()
        parts = place_recipe(args.recipe, key, name, card if args.card else "", args.color, chosen)
        panes, words = parts["panes"], parts["words"]
        for group in ("flags", "counters"):
            for entry in parts[group]:
                if entry in sites.get(group, []):
                    raise UsageError("sites.json already has the %s %s: choose another --id." % (group[:-1], entry))
                sites.setdefault(group, []).append(entry)
        for group in ("foes", "tasks"):
            for entry, value in parts[group].items():
                if entry in sites.get(group, {}):
                    raise UsageError("sites.json already has %s.%s: choose another --id." % (group, entry))
                sites.setdefault(group, {})[entry] = value
        made = "the recipe %s (%s)" % (args.recipe, RECIPES[args.recipe][1])
    else:
        leave = {"id": "leave", "do": "leave", "label": key + ".leave"}
        words = {key + ".intro": "%s. Write here what the hero sees on arriving." % name, key + ".leave": "Leave"}
        panes = [{"lines": [key + ".intro"], "actions": [leave]}]
        if service == "effects":
            action = {"id": "service", "do": "effects", "label": key + ".pay", "prices": prices,
                      "effects": [{"log_event": {"event": key, "text": key + ".log"}}], "result": [key + ".done"]}
            words.update({key + ".offer": "Write here what this place offers, and for how much.",
                          key + ".pay": "Pay {price} gold ({uses_left} left)",
                          key + ".done": "You pay {price} gold. Write here what the hero gets for it.",
                          key + ".log": "Paid {price} gold at %s." % name})
        elif service == "copy":
            action = {"id": "copy", "do": "copy_card", "label": key + ".copy", "prices": prices,
                      "pick_title": key + ".pick_title", "pick_line": key + ".pick_line", "result": [key + ".copied"]}
            words.update({key + ".offer": "Write here who copies a card of the hero's, and for how much.",
                          key + ".copy": "Copy a card ({price} gold, {uses_left} left)",
                          key + ".pick_title": "Pick a card to copy",
                          key + ".pick_line": "A copy of it for {price} gold.",
                          key + ".copied": "A copy of {card} is yours, for {price} gold."})
        if service != "none":
            panes = [{"lines": [key + ".intro", key + ".offer"], "actions": [action, leave]}]
            if prices:
                words[key + ".spent"] = "Write here what the place says once its service is used up."
                panes.insert(0, {"when": [{"used_up": action["id"]}], "lines": [key + ".intro", key + ".spent"],
                                 "actions": [leave]})
            else:
                # No prices (--free): free, and never used up; its words count nothing.
                del action["prices"]
                words[action["label"]] = "Use the service" if service == "effects" else "Copy a card"
                if service == "effects":
                    words.update({key + ".done": "Write here what the hero gets.", key + ".log": "Visited %s." % name})
                else:
                    words.update({key + ".pick_line": "A copy of it, free.", key + ".copied": "A copy of {card} is yours."})
        made = "no service" if service == "none" else "%s %s service%s" % (
            "an" if service == "effects" else "a", service,
            " for %s gold" % ", ".join(str(p) for p in prices) if prices else ", free")
    _new_texts(text, words)
    sites.setdefault("pictures", {})[picture] = "art/%s.png" % picture
    sites.setdefault("sites", {})[key] = {
        "name": name, "where": where, "picture": picture,
        "sprite": {"file": "art/%s_map.png" % picture, "width": 80}, "gap": 3, "panes": panes}
    if _finish_edit(args, path, game, manifest, sites, text, files, "the place was not added"):
        return 1
    print("Added the place %s (%s) to %s: on %s, %s; %d texts (%s.*), art/%s.png and art/%s_map.png "
          "(stand-ins to paint over)." % (key, name, args.folder, " and ".join(where), made, len(words), key,
                                          picture, picture))
    print("Next: see it played, then write its words in text.json (or with set-text)\n"
          "    python3 tools/adventure_plugin.py walk %s --site %s\n"
          "    python3 tools/adventure_plugin.py set-text %s %s.intro \"...\""
          % (_quoted(args.folder), key, _quoted(args.folder), key))
    return 0
def command_add_dungeon(args, game: Game) -> int:
    path, manifest, sites, text = _sites_folder(args.folder, game, "add-dungeon")
    key = args.id
    if re.search(ID_PATTERN, key) is None:
        raise UsageError("--id must be 1 to 40 lower-case letters, digits or _, a letter first.")
    if key in sites.get("dungeons", {}):
        raise UsageError("%s already has a dungeon %s." % (args.folder, key))
    name = strip_edges(args.name)
    if not name or len(name) > 60:
        raise UsageError("--name must be non-empty text of at most 60 characters.")
    cards = [strip_edges(card) for card in args.cards.split(",") if strip_edges(card)]
    if not 1 <= len(cards) <= 6:
        raise UsageError("--cards takes 1 to 6 card names, joined by commas.")
    if args.min > args.max:
        raise UsageError("--min %d is more than --max %d." % (args.min, args.max))
    if not args.place and (args.action or args.price is not None):
        raise UsageError("--action and --price need --place: the place whose button raises the dungeon.")
    recipe = {"name": name, "color": args.color, "size": args.size,
              "rules": _word_list(args.rules, "--rules", DUNGEON_RULES) if args.rules else [],
              "cards": cards, "distance": {"min": args.min, "max": args.max}}
    sites.setdefault("dungeons", {})[key] = recipe
    said = "Added the dungeon %s (%s) to %s: %s, %s, holding %s, %d to %d tiles from its place." % (
        key, name, args.folder, args.color, args.size, ", ".join(cards), args.min, args.max)
    if args.place:
        place = sites.get("sites", {}).get(args.place)
        if not isinstance(place, dict):
            raise UsageError("%s has no place %s (its places: %s)." % (args.folder, args.place,
                                                                       ", ".join(sites.get("sites", {}))))
        action_id = args.action or key[:32]
        if re.search(SITES_KEY_PATTERN, action_id) is None:
            raise UsageError("--action must be 1 to 32 lower-case letters, digits or _, a letter first.")
        panes = place["panes"]
        found = [action for pane in panes for action in pane.get("actions", []) if action.get("id") == action_id]
        leave = next((dict(action) for pane in panes for action in pane.get("actions", [])
                      if action.get("do") == "leave"), {"id": "leave", "do": "leave"})
        home = _home_pane(place)
        # THE PLACE'S OTHER BUTTONS STAY (finding 1.2, 2026-11-22): the
        # dungeon's two panes come first and so hide every pane after them
        # while it is open or cleared, and a pane of the place's own with a
        # when (a service used up) hid the dungeon's button. So the two new
        # panes carry the place's other buttons, and every pane of the
        # place's own that is chosen by itself carries the dungeon's.
        others = [dict(action) for action in home.get("actions", [])
                  if action.get("do") != "leave" and action.get("id") != action_id]
        # The dungeon's own name, written out: {dungeon} is the last dungeon
        # the plugin raised on the land (DataSites.values), another one's
        # name as soon as a plugin has two.
        words = {key + ".open": "The way to %s is known to you. Write here what the place says while it waits." % name,
                 key + ".cleared": "You have cleared %s. Write here what the place says then." % name}
        if found:
            if any(action.get("do") != "effects" for action in found):
                raise UsageError("The action %s of %s does %s; only an effects action can raise a dungeon."
                                 % (action_id, args.place, found[0].get("do")))
            for action in found:
                action["effects"] = [{"spawn_dungeon": key}] + list(action.get("effects", []))
                if args.price is not None and not action.get("prices"):
                    action["prices"] = [args.price]
            how = "the action %s now raises it" % action_id
        else:
            price = 1000 if args.price is None else args.price
            words.update({key + ".pay": "Pay {price} gold for the way to the dungeon",
                          key + ".told": "The way to %s is marked on your map." % name,
                          key + ".clue": "You were told where %s lies." % name})
            action = {"id": action_id, "do": "effects", "label": key + ".pay", "prices": [price],
                      "effects": [{"spawn_dungeon": key}, {"log_clue": {"text": key + ".clue"}}],
                      "result": [key + ".told"]}
            merged = 0
            for pane in panes:
                if "id" in pane:
                    continue
                buttons = pane.setdefault("actions", [])
                at = next((i for i, entry in enumerate(buttons) if entry.get("do") == "leave"), len(buttons))
                buttons.insert(at, dict(action))
                merged += pane is not home
            how = "a new action %s raises it for %d gold%s" % (
                action_id, price, " (the button stands in %d more pane%s of the place, so a service used up does "
                "not hide it)" % (merged, "" if merged == 1 else "s") if merged else "")
        # Two panes before the place's own: cleared, open (the Hut's three).
        for state in ("open", "cleared"):
            pane = {"when": [{"dungeon": {"dungeon": key, "state": state}}]}
            for field in ("title", "subtitle", "picture"):
                if field in home:
                    pane[field] = home[field]
            pane["lines"] = ["%s.%s" % (key, state)]
            pane["actions"] = [dict(other) for other in others] + [dict(leave)]
            panes.insert(0, pane)
        _new_texts(text, words)
        said += " At %s %s; two panes added before its others (cleared, open)%s; %d texts (%s.*)." % (
            args.place, how, ", each with the place's other button%s (%s)" % (
                "" if len(others) == 1 else "s", ", ".join(str(o["id"]) for o in others)) if others else "",
            len(words), key)
    if _finish_edit(args, path, game, manifest, sites, text, {}, "the dungeon was not added"):
        return 1
    print(said)
    if not args.place:
        print("No place raises it yet: name one with --place, or add {\"spawn_dungeon\": \"%s\"} to an action's effects." % key)
    return 0


# ---------------------------------------------------------------- walk --

## DataSites.MOST_USES: the most an action is counted.
MOST_USES = 1000
## The card a walk's hero carries to be copied, and what the walk calls the hero.
WALK_CARD = "Stand-in Card"
WALK_HERO = "Hero"


class SiteWalk:
    """DataSites, mirrored (game/adventure/plugins/data_sites.gd): a place's
    pane choice, conditions, prices, costs and effects on a hero of the
    tool's own — gold, food, amulets, cards, the uses counted, the flags
    set, the counters, each dungeon none, open or cleared — with no world:
    a dungeon raised always finds room, the hero's bag always has room and
    the campaign's card rules allow every card, a duel ends as the walk is
    told, a roll falls as the walk is told, and a card is traded at the
    price the plugin names (the game never sells one for less, nor buys one
    for more, than the most a town pays for it)."""

    def __init__(self, data: dict, gold: int, mainland: bool = True):
        self.data, self.file, self.words = data, data["sites"], data["text"]
        self.gold, self.food, self.mainland = gold, 0, mainland
        self.uses: dict = {}
        self.flags: list = []
        self.counters: dict = {}
        ## The dungeons of each land the walk visits; `dungeons` is this land's.
        self.lands: dict = {True: {}, False: {}}
        self.journal: list = []
        self.copies: list = []
        self.cards: list = [WALK_CARD]
        self.amulets: dict = {color: 0 for color in AMULET_COLORS}
        self.color = "white"
        self.magics: list = []
        self.day = 0
        self.wizards = 0
        self.peace = False
        self.difficulty = 0
        self.plugins: list = [str(data.get("id", ""))]
        self.gift = ""
        ## API 3's later words: the life the places have added, whether the
        ## nearest town is mana-linked (and whether one can be), and where a
        ## teleport has carried the hero.
        self.life_bonus = 0
        self.linked = False
        self.can_link = True
        self.carried = ""
        ## How a duel ends ("win" or "lose") and which outcome a roll takes
        ## (0: the likeliest; n: the n-th).
        self.duel_outcome = "win"
        self.roll_choice = 0

    @property
    def dungeons(self) -> dict:
        return self.lands[self.mainland]

    @dungeons.setter
    def dungeons(self, value: dict) -> None:
        self.lands[self.mainland] = value

    def land(self) -> str:
        return "mainland" if self.mainland else "island"

    def say(self, key: str, values: dict | None = None) -> str:
        """PluginText.say: the plugin's words, else the engine's, filled."""
        if key == "":
            return ""
        out = str(self.words.get(key, TEXT_DEFAULTS.get(key, "")))
        for name, value in (values or {}).items():
            out = out.replace("{" + str(name) + "}", str(value))
        return out

    def site(self, key: str) -> dict:
        return self.file["sites"].get(key, {})

    def action_of(self, site: str, action: str) -> dict:
        for pane in self.site(site).get("panes", []):
            for entry in pane.get("actions", []):
                if str(entry["id"]) == action:
                    return entry
        return {}

    @staticmethod
    def all_effects(entry: dict) -> list:
        """DataSites.all_effects: an action's effects, its duel branches' and
        its rolls' outcomes', flat (a roll itself is not one of them)."""
        out = []
        lists = [entry.get("effects", [])]
        for branch in ("win", "lose"):
            if isinstance(entry.get(branch), dict):
                lists.append(entry[branch].get("effects", []))
        for effects in lists:
            for effect in effects:
                if "roll" in effect:
                    for outcome in effect["roll"].get("outcomes", []):
                        out.extend(outcome.get("effects", []))
                else:
                    out.append(effect)
        return out

    @staticmethod
    def spawned(entry: dict) -> list:
        out = []
        for effect in SiteWalk.all_effects(entry):
            if "spawn_dungeon" in effect and str(effect["spawn_dungeon"]) not in out:
                out.append(str(effect["spawn_dungeon"]))
        return out

    def per_land(self, site: str, action: str) -> bool:
        """DataSites.per_land: an action with prices that raises a dungeon
        is counted on each land by itself (finding 1.1 of 2026-11-22)."""
        entry = self.action_of(site, action)
        return bool(entry.get("prices")) and bool(self.spawned(entry))

    def used(self, site: str, action: str) -> int:
        key = site + "." + action
        return int(self.uses.get(key + "@" + self.land() if self.per_land(site, action) else key, 0))

    def site_uses(self, site: str) -> int:
        return sum(int(n) for key, n in self.uses.items() if key.startswith(site + ".") and "#" not in key)

    def price(self, site: str, action: dict) -> int:
        """Its next price, 0 when it has none, -1 when every price is paid."""
        prices = action.get("prices", [])
        if not prices:
            return 0
        done = self.used(site, str(action["id"]))
        return int(prices[done]) if done < len(prices) else -1

    def used_up(self, site: str, action: dict) -> bool:
        return self.price(site, action) < 0

    def uses_left(self, site: str, action: dict) -> int:
        prices = action.get("prices", [])
        if not prices:
            return -1
        return max(0, len(prices) - self.used(site, str(action["id"])))

    def dungeon_state(self, key: str) -> str:
        return self.dungeons.get(key, "none")

    def amulet_count(self, color: str = "any") -> int:
        return sum(self.amulets.values()) if color == "any" else int(self.amulets.get(color, 0))

    def counter(self, name: str) -> int:
        return max(0, min(MOST_USES, int(self.counters.get(name, 0))))

    def holds(self, site: str, conditions: list) -> bool:
        return all(self._holds(site, condition) for condition in conditions)

    def _holds(self, site: str, condition: dict) -> bool:
        key = next(iter(condition))
        value = condition[key]
        if key == "flag":
            return value in self.flags
        if key == "not_flag":
            return value not in self.flags
        if key == "gold_at_least":
            return self.gold >= int(value)
        if key == "on_mainland":
            return self.mainland == bool(value)
        if key == "used":
            done = self.used(site, str(value["action"]))
            return int(value.get("min", 0)) <= done <= int(value.get("max", MOST_USES))
        if key == "used_up":
            return self.used_up(site, self.action_of(site, str(value)))
        if key == "dungeon":
            return self.dungeon_state(str(value["dungeon"])) == str(value["state"])
        if key == "has_card":
            return self.cards.count(str(value["card"])) >= int(value.get("min", 1))
        if key == "amulets":
            return self.amulet_count(str(value.get("color", "any"))) >= int(value.get("min", 1))
        if key == "hero_color":
            return self.color == str(value)
        if key == "owns_magic":
            return str(value) in self.magics
        if key == "food_at_least":
            return self.food >= int(value)
        if key == "gold_below":
            return self.gold < int(value)
        if key == "day_at_least":
            return self.day >= int(value)
        if key == "wizards_defeated":
            return self.wizards >= int(value)
        if key == "at_peace":
            return self.peace == bool(value)
        if key == "difficulty":
            return int(value.get("min", 0)) <= self.difficulty <= int(value.get("max", 3))
        if key == "plugin_on":
            return str(value) in self.plugins
        if key == "counter":
            return int(value.get("min", 0)) <= self.counter(str(value["name"])) <= int(value.get("max", MOST_USES))
        if key == "site_used":
            done = self.used(str(value["site"]), str(value["action"]))
            return int(value.get("min", 1)) <= done <= int(value.get("max", MOST_USES))
        if key == "gift_waiting":
            return (self.gift != "") == bool(value)
        if key == "any":
            return any(self._holds(site, inner) for inner in value)
        if key == "life_bonus_below":
            return self.life_bonus < int(value)
        if key == "town_linked":
            return self.linked
        return False

    @staticmethod
    def named_condition(conditions: list, word: str):
        """DataSites._named_condition: the first condition [word] of the
        list, an any's too; None when there is none."""
        for condition in conditions:
            if word in condition:
                return condition[word]
            if "any" in condition:
                inside = SiteWalk.named_condition(condition["any"], word)
                if inside is not None:
                    return inside
        return None

    def dungeon_about(self, action: dict, pane: dict | None = None, fallback: bool = True) -> str:
        """DataSites.dungeon_about: the dungeon {dungeon} names — the one
        the action raises, or its when asks about, or the pane's; else the
        plugin's first."""
        for source in (action, pane or {}):
            if not source:
                continue
            raised = self.spawned(source)
            if raised:
                return raised[0]
            asked = self.named_condition(source.get("when", []), "dungeon")
            if isinstance(asked, dict):
                return str(asked["dungeon"])
            for entry in source.get("actions", []):
                theirs = self.spawned(entry)
                if theirs:
                    return theirs[0]
        every = self.file.get("dungeons", {})
        return str(next(iter(every))) if every and fallback else ""

    def counter_about(self, action: dict, pane: dict | None = None, fallback: bool = True) -> str:
        """DataSites.counter_about: the counter {count} shows."""
        for source in (action, pane or {}):
            if not source:
                continue
            for effect in self.all_effects(source):
                if "counter" in effect:
                    return str(effect["counter"]["name"])
            asked = self.named_condition(source.get("when", []), "counter")
            if isinstance(asked, dict):
                return str(asked["name"])
        every = self.file.get("counters", [])
        return str(every[0]) if every and fallback else ""

    @staticmethod
    def card_about(action: dict) -> str:
        for need in action.get("needs", []):
            if "card" in need:
                return str(need["card"])
        for effect in SiteWalk.all_effects(action):
            if "give_card" in effect:
                return str(effect["give_card"])
        return ""

    def values(self, site: str, action: dict | None = None, more: dict | None = None,
               pane: dict | None = None) -> dict:
        action = action or {}
        out = {"hero": WALK_HERO, "gold": self.gold, "region": "Shandalar" if self.mainland else "the island",
               "food": self.food, "amulets": self.amulet_count(), "day": self.day, "life_bonus": self.life_bonus}
        about = self.dungeon_about(action, pane)
        if about:
            out["dungeon"] = str(self.file["dungeons"].get(about, {}).get("name", about))
        counted = self.counter_about(action, pane)
        if counted:
            out["count"] = self.counter(counted)
        if action:
            out["price"] = max(0, self.price(site, action))
            left = self.uses_left(site, action)
            out["uses_left"] = left if left >= 0 else ""
            foe = self.file.get("foes", {}).get(str(action.get("foe", "")))
            if foe:
                out["foe"], out["life"] = str(foe.get("name", "")), int(foe.get("life", 20))
            card = self.card_about(action)
            if card:
                out["card"] = card
            # {town}: the town a link would be made with, or a journey's;
            # {title}: the World Magic given.
            for effect in self.all_effects(action):
                if "mana_link" in effect or ("teleport" in effect and str(effect["teleport"].get("to", "")) == "nearest_town"):
                    out["town"] = WALK_TOWN
                elif "world_magic" in effect:
                    out["title"] = str(effect["world_magic"])
        out.update(more or {})
        return out

    def lines(self, site: str, entries: list, filled: dict) -> list:
        out = []
        for entry in entries:
            if isinstance(entry, str):
                out.append(self.say(entry, filled))
                continue
            if not self.holds(site, entry.get("when", [])):
                continue
            # A line that asks about a counter shows that one as {count}.
            own = filled
            asked = self.named_condition(entry.get("when", []), "counter")
            if isinstance(asked, dict):
                own = dict(filled, count=self.counter(str(asked["name"])))
            if "one_of" in entry:
                # In turn, by the day or by the place's uses: no dice.
                turn = self.day if str(entry.get("by", "day")) == "day" else self.site_uses(site)
                out.append(self.say(str(entry["one_of"][turn % len(entry["one_of"])]), own))
            else:
                out.append(self.say(str(entry["text"]), own))
        return out

    def pane_of(self, site: str, pane_id: str = "") -> dict:
        """DataSites.pane_of: the pane a talk named (while its when holds),
        else the first without an id whose when holds."""
        panes = self.site(site).get("panes", [])
        if pane_id:
            for pane in panes:
                if str(pane.get("id", "")) == pane_id and self.holds(site, pane.get("when", [])):
                    return pane
        for pane in panes:
            if "id" not in pane and self.holds(site, pane.get("when", [])):
                return pane
        return {}

    @staticmethod
    def label_key(action: dict) -> str:
        if "label" in action:
            return str(action["label"])
        if str(action["do"]) in DEFAULT_LABELS:
            return DEFAULT_LABELS[str(action["do"])]
        if any("card" in need for need in action.get("needs", [])):
            return "site.give"
        return "site.pay"

    def describe(self, site: str, pane_id: str = "") -> dict:
        """The pane shown; its buttons {id, do, label, ready, why}."""
        place = self.site(site)
        pane = self.pane_of(site, pane_id)
        filled = self.values(site, None, None, pane)
        buttons = []
        for action in pane.get("actions", []):
            if not self.holds(site, action.get("when", [])):
                continue
            do = str(action["do"])
            if do == "leave":
                buttons.append({"id": str(action["id"]), "do": "leave", "ready": True, "why": "",
                                "label": self.say(str(action.get("label", "site.leave")))})
                continue
            if self.used_up(site, action):
                continue
            why = self.refusal(site, action)
            if not why and do == "buy_card":
                # The game asks for the gold once a card is picked.
                offer = self.offer(site, action)
                if self.gold < offer[1]:
                    why = self.say("site.no_gold", {"price": offer[1], "gold": self.gold})
            buttons.append({"id": str(action["id"]), "do": do, "ready": why == "", "why": why,
                            "label": self.say(self.label_key(action), self.values(site, action))})
        return {"pane": place["panes"].index(pane) if pane else -1, "pane_id": str(pane.get("id", "")),
                "title": self.say(str(pane["title"]), filled) if "title" in pane else str(place["name"]),
                "subtitle": self.say(str(pane["subtitle"]), filled) if "subtitle" in pane
                else str(self.data["manifest"].get("name", self.data["id"])),
                "picture": str(pane.get("picture", place["picture"])),
                "lines": self.lines(site, pane.get("lines", []), filled), "buttons": buttons}

    def lacks(self, action: dict) -> str:
        """DataSites._needs_problem: the first of its needs the hero lacks
        (needs of one kind are added up), said; "" when none."""
        cards: dict = {}
        amulets = dict(self.amulets)
        food = self.food
        for need in action.get("needs", []):
            if "card" in need:
                card = str(need["card"])
                cards[card] = cards.get(card, 0) + 1
                if self.cards.count(card) < cards[card]:
                    return self.say("site.needs_card", {"card": card})
            elif "amulets" in need:
                color, count = str(need["amulets"].get("color", "any")), int(need["amulets"].get("count", 1))
                if not self.take_amulets(amulets, color, count):
                    if color == "any":
                        return self.say("site.needs_any_amulets", {"count": count, "amulets": self.amulet_count()})
                    return self.say("site.needs_amulets", {"count": count, "color": color})
            elif "food" in need:
                food -= int(need["food"])
                if food < 0:
                    return self.say("site.needs_food", {"count": int(need["food"]), "food": self.food})
        return ""

    @staticmethod
    def take_amulets(amulets: dict, color: str, count: int) -> bool:
        """DataSites._take_amulets: of a color, or of the color the hero has
        most of, one at a time."""
        if color != "any":
            if int(amulets.get(color, 0)) < count:
                return False
            amulets[color] = int(amulets.get(color, 0)) - count
            return True
        for _ in range(count):
            best = ""
            for hue in AMULET_COLORS:
                if int(amulets.get(hue, 0)) > (int(amulets.get(best, 0)) if best else 0):
                    best = hue
            if not best:
                return False
            amulets[best] = int(amulets[best]) - 1
        return True

    def effects_now(self, entry: dict) -> dict:
        """DataSites.effects_now: the effects this press applies, a roll's
        outcome among them, and the outcome's result lines; `rolls` is what
        the walk shows of each roll."""
        out = {"effects": [], "result": [], "rolls": []}
        for effect in entry.get("effects", []):
            if "roll" not in effect:
                out["effects"].append(effect)
                continue
            outcomes = effect["roll"].get("outcomes", [])
            weights = [max(1, int(o.get("weight", 1))) for o in outcomes]
            chosen = self.roll_choice - 1 if 1 <= self.roll_choice <= len(outcomes) else weights.index(max(weights))
            out["effects"].extend(outcomes[chosen].get("effects", []))
            out["result"].extend(outcomes[chosen].get("result", []))
            out["rolls"].append({"weights": weights, "chosen": chosen,
                                 "gold": [self.gold_of(o.get("effects", [])) for o in outcomes],
                                 "expected_gold": self.gold_of([effect]),
                                 "says": [[self.say(line if isinstance(line, str) else str(line.get("text", "")))
                                           for line in o.get("result", [])] for o in outcomes]})
        return out

    def effects_problem(self, action: dict, effects: list) -> str:
        """DataSites._effects_problem, as far as a walk can tell: nothing is
        paid for a dungeon that is open already (finding 1.7), nor for a
        gift while one waits."""
        for effect in effects:
            if "spawn_dungeon" in effect and action.get("prices") \
                    and self.dungeon_state(str(effect["spawn_dungeon"])) == "open":
                key = str(effect["spawn_dungeon"])
                return self.say("site.dungeon_open", {"dungeon": self.file["dungeons"].get(key, {}).get("name", key)})
            if "next_duel" in effect and self.gift:
                return self.say("site.gift_waiting")
            if "world_magic" in effect and str(effect["world_magic"]) in self.magics:
                return self.say("site.magic_owned", {"title": effect["world_magic"]})
            if "mana_link" in effect and (self.linked or not self.can_link):
                return self.say("site.no_link")
            if "life_bonus" in effect and self.life_bonus >= MOST_LIFE_BONUS:
                return self.say("site.life_full")
            if "teleport" in effect:
                to = str(effect["teleport"].get("to", ""))
                kind, _, name = to.partition(":")
                # A walk has no map: a place of the plugin is there when it
                # stands on this land, a dungeon once it is raised.
                if (kind == "place" and ("mainland" if self.mainland else "islands") not in self.site(name).get("where", [])) \
                        or (kind == "dungeon" and self.dungeon_state(name) == "none"):
                    return self.say("site.no_way")
        return ""

    def refusal(self, site: str, action: dict) -> str:
        if not action or not self.holds(site, action.get("when", [])) or self.used_up(site, action):
            return self.say("site.done")
        cost = self.price(site, action)
        if self.gold < cost:
            return self.say("site.no_gold", {"price": cost, "gold": self.gold})
        lack = self.lacks(action)
        if lack:
            return lack
        do = str(action["do"])
        if do in ("effects", "talk"):
            return self.effects_problem(action, self.effects_now(action)["effects"])
        if do == "duel":
            for branch in ("win", "lose"):
                why = self.effects_problem(action, action.get(branch, {}).get("effects", []))
                if why:
                    return why
        elif do == "buy_card":
            if not self.offer(site, action):
                return self.say("site.no_stock")
        elif do == "sell_card":
            if not self.offer(site, action):
                return self.say("site.nothing_to_sell")
        return ""

    def stock_left(self, site: str, action: dict, card: str) -> int:
        if "stock" not in action:
            return -1
        return max(0, int(action["stock"]) - int(self.uses.get("%s.%s#%s" % (site, action["id"], card), 0)))

    def offer(self, site: str, action: dict):
        """The card a walk trades at a buy_card or sell_card action, and its
        price: the first it sells that is in stock, the first it buys that
        the hero holds; None when there is none."""
        for card, price in action.get("cards", {}).items():
            if self.stock_left(site, action, card) == 0:
                continue
            if str(action["do"]) == "sell_card" and card not in self.cards:
                continue
            return str(card), int(price)
        return None

    def result(self, lines: list) -> dict:
        return {"lines": lines, "buttons": [self.say("site.back"), self.say("site.leave")]}

    def pay(self, action: dict, cost: int) -> list:
        """DataSites._pay: the gold and the needs taken; the needs, in words."""
        self.gold -= cost
        taken = []
        for need in action.get("needs", []):
            if "card" in need:
                self.cards.remove(str(need["card"]))
                taken.append(str(need["card"]))
            elif "amulets" in need:
                color, count = str(need["amulets"].get("color", "any")), int(need["amulets"].get("count", 1))
                self.take_amulets(self.amulets, color, count)
                taken.append("%d %s amulet%s" % (count, color, "" if count == 1 else "s"))
            elif "food" in need:
                self.food = max(0, self.food - int(need["food"]))
                taken.append("%d food" % int(need["food"]))
        return taken

    @staticmethod
    def gold_of(effects: list) -> float:
        """The gold a list of effects brings, a roll's as its average."""
        total = 0.0
        for effect in effects:
            if "gold" in effect:
                total += int(effect["gold"])
            elif "roll" in effect:
                outcomes = effect["roll"]["outcomes"]
                weight = sum(max(1, int(o.get("weight", 1))) for o in outcomes)
                total += sum(max(1, int(o.get("weight", 1))) * SiteWalk.gold_of(o.get("effects", []))
                             for o in outcomes) / weight
        return total

    def apply(self, site: str, effects: list, out: dict, filled: dict) -> None:
        """DataSites.apply: [effects] in order."""
        for effect in effects:
            key = next(iter(effect))
            value = effect[key]
            if key == "set_flag":
                if value not in self.flags:
                    self.flags.append(str(value))
            elif key == "clear_flag":
                if value in self.flags:
                    self.flags.remove(value)
            elif key == "gold":
                self.gold = max(0, self.gold + int(value))
            elif key == "food":
                self.food = max(0, self.food + int(value))
            elif key == "spawn_dungeon":
                if self.dungeon_state(str(value)) != "open":
                    self.dungeons[str(value)] = "open"
                    out["raised"].append(str(value))
            elif key in ("log_clue", "log_event"):
                self.journal.append(self.say(str(value["text"]), self.values(site, None, filled)))
            elif key == "counter":
                now = int(value["set"]) if "set" in value else self.counter(str(value["name"])) + int(value.get("add", 0))
                self.counters[str(value["name"])] = max(0, min(MOST_USES, now))
            elif key == "amulet":
                color, count = str(value["color"]), int(value.get("count", 1))
                have = int(self.amulets.get(color, 0))
                # Never over the cap by this gift, never under what is carried.
                self.amulets[color] = max(have, min(MOST_AMULETS, have + count)) if count > 0 else max(0, have + count)
            elif key == "give_card":
                self.cards.append(str(value))
                out["given"].append(str(value))
            elif key == "next_duel":
                if not self.gift:
                    self.gift = "%d more life" % max(1, min(20, int(value["life"]))) if "life" in value else \
                        "the first move" if value.get("first_move") else "%s in play" % value.get("card", "")
                    out["gift"] = self.gift
            elif key == "world_magic":
                if str(value) not in self.magics:
                    self.magics.append(str(value))
                    out["learned"].append(str(value))
                    self.journal.append("Bought WM: %s" % value)
            elif key == "mana_link":
                if not self.linked and self.can_link:
                    self.linked = True
                    out["linked"] = WALK_TOWN
            elif key == "life_bonus":
                self.life_bonus = max(0, min(MOST_LIFE_BONUS, self.life_bonus + int(value)))
                out["life_bonus"] = self.life_bonus
            elif key == "teleport":
                to = str(value.get("to", ""))
                kind, _, name = to.partition(":")
                self.carried = WALK_TOWN if to == "nearest_town" else "where the journey began" if to == "start" \
                    else str(self.site(name).get("name", name)) if kind == "place" \
                    else str(self.file["dungeons"].get(name, {}).get("name", name))
                out["carried"] = self.carried
            elif key == "reveal_map":
                around = str(value.get("around", "place"))
                if around.startswith("dungeon:") and self.dungeon_state(around[len("dungeon:"):]) == "none":
                    continue
                out["revealed"].append("%d tiles around %s" % (int(value.get("radius", 4)),
                                                               "the place" if around == "place" else around[len("dungeon:"):]))

    def press(self, site: str, name: str) -> dict:
        """DataSites.do_effects, copy_card, duel_begin and duel_end,
        buy_card and sell_card: {paid, lines, buttons, raised, journal,
        copied, refused, …}; `to` is the pane a talk opens."""
        entry = self.action_of(site, name)
        out = {"action": name, "do": str(entry.get("do", "")), "paid": 0, "raised": [], "journal": [], "copied": "",
               "refused": "", "to": "", "taken": [], "given": [], "gift": "", "revealed": [], "rolls": [], "duel": "",
               "traded": "", "earned": 0, "learned": [], "linked": "", "life_bonus": 0, "carried": ""}
        why = self.refusal(site, entry)
        do = out["do"]
        if not why and do == "buy_card" and self.gold < self.offer(site, entry)[1]:
            why = self.say("site.no_gold", {"price": self.offer(site, entry)[1], "gold": self.gold})
        if why:
            out.update(self.result([why]), refused=why)
            return out
        cost = self.price(site, entry)
        marks = len(self.journal)
        if do == "copy_card":
            out["taken"] = self.pay(entry, cost)
            self._count(site, name)
            self.copies.append(WALK_CARD)
            filled = self.values(site, None, {"price": cost, "card": WALK_CARD})
            self.journal.append(self.say("site.copied_log", filled))
            lines = self.lines(site, entry.get("result", []), filled) or [self.say("site.copied", filled)]
            out.update(self.result(lines), paid=cost, copied=WALK_CARD, journal=self.journal[marks:])
            return out
        if do in ("buy_card", "sell_card"):
            card, price = self.offer(site, entry)
            buying = do == "buy_card"
            if buying:
                self.gold -= price
                self.cards.append(card)
            else:
                self.gold += price
                self.cards.remove(card)
            self._count(site, name)
            if "stock" in entry:
                key = "%s.%s#%s" % (site, name, card)
                self.uses[key] = int(self.uses.get(key, 0)) + 1
            filled = self.values(site, None, {"price": price, "card": card})
            self.journal.append(self.say("site.bought_log" if buying else "site.sold_log", filled))
            lines = self.lines(site, entry.get("result", []), filled) or \
                [self.say("site.bought" if buying else "site.sold", filled)]
            out.update(self.result(lines), paid=price if buying else 0, earned=0 if buying else price, traded=card,
                       journal=self.journal[marks:])
            return out
        if do == "duel":
            won = self.duel_outcome == "win"
            out["taken"] = self.pay(entry, cost)
            by_win = str(entry.get("count", "press")) == "win"
            if not by_win:
                self._count(site, name)
            filled = self.values(site, entry, {"price": cost})
            if won and by_win:
                self._count(site, name)
            branch = entry.get("win" if won else "lose", {})
            self.apply(site, branch.get("effects", []), out, filled)
            self.journal.append(self.say("site.duel_won_log" if won else "site.duel_lost_log", filled))
            # The gift for the next duel is spent in it, whoever wins.
            self.gift = out["gift"]
            after = self.values(site, entry, {"price": cost})
            lines = self.lines(site, branch.get("result", []), after) or \
                [self.say("site.duel_won" if won else "site.duel_lost", after)]
            out.update(self.result(lines), paid=cost, duel="won" if won else "lost", journal=self.journal[marks:])
            return out
        talk = do == "talk"
        if talk and not entry.get("prices") and not entry.get("effects") and not entry.get("needs"):
            # A plain talk only turns the page: nothing paid, nothing counted.
            out.update(to=str(entry.get("to", "")), lines=[], buttons=[], plain=True)
            return out
        # Drawn before the use is counted: the roll is this use's.
        now = self.effects_now(entry)
        filled = self.values(site, entry)
        out["taken"] = self.pay(entry, cost)
        self._count(site, name)
        self.apply(site, now["effects"], out, filled)
        out.update(paid=cost, journal=self.journal[marks:], rolls=now["rolls"])
        lines = list(entry.get("result", [])) + now["result"]
        if talk:
            out.update(to=str(entry.get("to", "")), lines=[], buttons=[])
        elif lines:
            out.update(self.result(self.lines(site, lines, self.values(site, entry, {"price": cost}))))
        else:
            out.update(lines=[], buttons=[])
        return out

    def _count(self, site: str, action: str) -> None:
        key = site + "." + action + ("@" + self.land() if self.per_land(site, action) else "")
        self.uses[key] = min(MOST_USES, int(self.uses.get(key, 0)) + 1)

    def state(self) -> dict:
        out = {"gold": self.gold, "food": self.food,
               "uses": {key: n for key, n in self.uses.items() if "#" not in key}, "flags": list(self.flags),
               "dungeons": dict(self.dungeons)}
        if any(self.counters.values()):
            out["counters"] = {name: n for name, n in self.counters.items() if n}
        if any(self.amulets.values()):
            out["amulets"] = {color: n for color, n in self.amulets.items() if n}
        if self.cards != [WALK_CARD]:
            out["cards"] = list(self.cards)
        if self.gift:
            out["gift"] = self.gift
        if self.life_bonus:
            out["life_bonus"] = self.life_bonus
        if self.linked:
            out["linked"] = True
        if self.magics:
            out["magics"] = list(self.magics)
        return out


## AdventurePlayer.LIFE_BONUS_MOST: the most life all places together add.
MOST_LIFE_BONUS = 10
## What a walk calls the nearest town.
WALK_TOWN = "the nearest town"
## DataSites.MOST_AMULETS: the most amulets of one color a gift leaves the hero with.
MOST_AMULETS = 99
## The colors of the amulets, and the button a kind of action wears when it names none.
AMULET_COLORS = ["black", "blue", "green", "red", "white"]
DEFAULT_LABELS = {"talk": "site.talk", "duel": "site.duel", "buy_card": "site.buy", "sell_card": "site.sell"}


def walk_lands(data: dict, site: str) -> list:
    """The lands place [site] stands on, each walked on its own: "mainland"
    and "island", the mainland first, as its `where` names them."""
    where = data["sites"]["sites"][site]["where"]
    return [land for land, named in (("mainland", "mainland"), ("island", "islands")) if named in where]


def walk_hero(data: dict, gold: int = 0, options: dict | None = None) -> SiteWalk:
    """A walk's hero, made as [options] say: {food, flags, counters, cards,
    amulets, color, magics, day, wizards, peace, difficulty, plugins, gift,
    outcome, roll}."""
    options = options or {}
    walk = SiteWalk(data, gold)
    walk.food = int(options.get("food", 0))
    walk.flags = list(options.get("flags", []))
    walk.counters = dict(options.get("counters", {}))
    walk.cards = [WALK_CARD] + list(options.get("cards", []))
    walk.amulets.update(options.get("amulets", {}))
    walk.color = str(options.get("color", walk.color))
    walk.magics = list(options.get("magics", []))
    walk.day = int(options.get("day", 0))
    walk.wizards = int(options.get("wizards", 0))
    walk.peace = bool(options.get("peace", False))
    walk.difficulty = int(options.get("difficulty", 0))
    walk.plugins += list(options.get("plugins", []))
    walk.gift = "a gift" if options.get("gift") else ""
    walk.life_bonus = int(options.get("life_bonus", 0))
    walk.linked = bool(options.get("linked", False))
    walk.duel_outcome = str(options.get("outcome", "win"))
    walk.roll_choice = int(options.get("roll", 0))
    return walk


def walk_site(data: dict, site: str, gold: int, land: str = "", options: dict | None = None,
              hero: SiteWalk | None = None, press: list | None = None) -> dict:
    """One place walked on one land: {site, name, land, steps, seen}. A step
    is a pane (as shown), a press (what it did, and the pane after), or a
    clear (an open dungeon cleared by the hero, away from the place).
    [land]: "mainland" or "island"; none named, the first of [walk_lands] —
    a place on both is walked once for each (command_walk), since a pane or
    a button behind on_mainland shows on one of them only. [hero]: a hero
    who walked before (one hero across lands), else a new one made of
    [options]. [press]: the buttons to press, in turn (an action's id;
    "leave": step out and in again; "clear": clear the open dungeon); none:
    every button that can be pressed, each price paid, a free one twice
    (a duel won, then lost)."""
    place = data["sites"]["sites"][site]
    mainland = (land or walk_lands(data, site)[0]) == "mainland"
    walk = hero or walk_hero(data, 0, options)
    walk.mainland = mainland
    began = walk.gold
    fixed = bool((options or {}).get("outcome"))
    steps = []
    seen = {"panes": set(), "ready": set(), "shown": {}, "pressed": set()}

    def show(pane_id: str, note: str = "") -> dict:
        pane = walk.describe(site, pane_id)
        steps.append(dict(pane, kind="pane", note=note, state=walk.state()))
        seen["panes"].add(pane["pane"])
        for button in pane["buttons"]:
            if button["ready"]:
                seen["ready"].add(button["id"])
            else:
                seen["shown"][button["id"]] = button["why"]
        return pane

    def push(name: str, label: str) -> dict:
        done = walk.press(site, name)
        steps.append(dict(done, kind="press", label=label, state=walk.state()))
        if not done["refused"]:
            seen["pressed"].add(name)
        return done

    def clear() -> bool:
        opened = [key for key, state in walk.dungeons.items() if state == "open"]
        if not opened:
            return False
        walk.dungeons[opened[0]] = "cleared"
        steps.append({"kind": "clear", "dungeon": opened[0], "name": str(data["sites"]["dungeons"][opened[0]]["name"]),
                      "state": walk.state()})
        return True

    if hero is None and press is None:
        poor = walk.describe(site)
        if any(not button["ready"] for button in poor["buttons"]):
            steps.append(dict(poor, kind="pane", note="with no gold", state=walk.state()))
    if hero is None:
        walk.gold = gold
    at = ""
    if press is not None:
        for name in press:
            pane = show(at)
            if name == "leave":
                at = ""
                continue
            if name == "clear":
                if not clear():
                    steps.append({"kind": "note", "text": "clear: no dungeon is open.", "state": walk.state()})
                continue
            button = next((b for b in pane["buttons"] if b["id"] == name), None)
            if button is None:
                steps.append({"kind": "note", "state": walk.state(),
                              "text": "%s: this pane shows no such button (its buttons: %s)."
                                      % (name, ", ".join(b["id"] for b in pane["buttons"]) or "none")})
                continue
            done = push(name, button["label"])
            at = done["to"] if done["to"] else ""
        show(at)
    else:
        pressed: dict = {}
        for _ in range(96):
            pane = show(at)
            choice = None
            for button in pane["buttons"]:
                if button["do"] == "leave" or not button["ready"]:
                    continue
                action = walk.action_of(site, button["id"])
                prices = action.get("prices", [])
                most = len(prices) if prices else 1 if button["do"] == "talk" else 2
                if pressed.get(button["id"], 0) >= most:
                    continue
                # A talk that only turns the page is looked at first: it
                # changes nothing, and the buttons after it may close the pane.
                plain = button["do"] == "talk" and not (action.get("prices") or action.get("effects") or action.get("needs"))
                if plain:
                    choice = button
                    break
                if choice is None:
                    choice = button
            if choice is not None:
                pressed[choice["id"]] = pressed.get(choice["id"], 0) + 1
                if choice["do"] == "duel" and not fixed:
                    walk.duel_outcome = "win" if pressed[choice["id"]] % 2 == 1 else "lose"
                done = push(choice["id"], choice["label"])
                at = done["to"] if done["to"] else ""
                continue
            if at:
                at = ""
                continue
            if not clear():
                break
    return {"site": site, "name": str(place["name"]), "land": "mainland" if mainland else "island",
            "gold": gold if hero is None else began, "steps": steps, "seen": {"panes": sorted(seen["panes"]), "ready": sorted(seen["ready"]),
                                     "shown": dict(seen["shown"]), "pressed": sorted(seen["pressed"])}}


def never_reached(data: dict, site: str, runs: list) -> list:
    """What the walks of place [site] never came to: each pane never shown
    and each button never pressed, with what stands in its way."""
    place = data["sites"]["sites"][site]
    panes, pressed, shown, ready = set(), set(), {}, set()
    for run in runs:
        panes.update(run["seen"]["panes"])
        pressed.update(run["seen"]["pressed"])
        shown.update(run["seen"]["shown"])
        ready.update(run["seen"]["ready"])
    out = []
    for p, pane in enumerate(place["panes"]):
        if p not in panes:
            out.append("pane %d%s was never shown%s" % (
                p, " (id %s)" % pane["id"] if "id" in pane else "",
                ": no talk pressed leads to it" if "id" in pane else
                ": its when is %s%s" % (json.dumps(pane["when"], ensure_ascii=False), walk_hint(pane["when"]))
                if pane.get("when") else ""))
    for name, action in _site_actions(place).items():
        if str(action["do"]) == "leave" or name in pressed:
            continue
        if name in ready:
            out.append("the button %s was ready, but this walk went another way first (--press %s presses it)"
                       % (name, name))
        elif name in shown:
            out.append("the button %s was shown but never ready: %s%s" % (name, shown[name], walk_hint(
                [{"has_card": {"card": need["card"]}} if "card" in need else
                 {"amulets": {"color": need["amulets"].get("color", "any"), "min": need["amulets"].get("count", 1)}}
                 if "amulets" in need else {"food_at_least": need["food"]} for need in action.get("needs", [])])))
        else:
            out.append("the button %s was never shown%s" % (
                name, ": its when is %s%s" % (json.dumps(action["when"], ensure_ascii=False), walk_hint(action["when"]))
                if action.get("when") else " (its pane was never shown)"))
    return out


def walk_hint(conditions: list) -> str:
    """The walk options that make [conditions] hold, as far as options can."""
    options = []
    for condition in _flat_conditions(conditions):
        name = next(iter(condition))
        value = condition[name]
        if name == "flag":
            options.append("--flag %s" % value)
        elif name == "has_card":
            options.append("--cards \"%s\"" % ", ".join([str(value["card"])] * int(value.get("min", 1))))
        elif name == "amulets":
            options.append("--amulets %s=%d" % ("white" if value.get("color", "any") == "any" else value["color"],
                                                max(1, int(value.get("min", 1)))))
        elif name == "hero_color":
            options.append("--color %s" % value)
        elif name == "owns_magic":
            options.append("--magic \"%s\"" % value)
        elif name == "food_at_least":
            options.append("--food %d" % int(value))
        elif name == "day_at_least":
            options.append("--day %d" % int(value))
        elif name == "wizards_defeated":
            options.append("--wizards %d" % int(value))
        elif name == "at_peace" and value:
            options.append("--peace")
        elif name == "gift_waiting" and value:
            options.append("--gift")
        elif name == "plugin_on":
            options.append("--plugin %s" % value)
        elif name == "counter" and int(value.get("min", 0)) > 0:
            options.append("--counter %s=%d" % (value["name"], int(value["min"])))
        elif name == "gold_below":
            options.append("--gold %d" % max(0, int(value) - 1))
        elif name == "difficulty" and int(value.get("min", 0)) > 0:
            options.append("--difficulty %d" % int(value["min"]))
        elif name == "on_mainland":
            options.append("--land %s" % ("mainland" if value else "island"))
        elif name == "town_linked":
            options.append("--linked")
    return " (try %s)" % " ".join(dict.fromkeys(options)) if options else ""


def _walk_text(run: dict) -> list:
    out = ["%s (%s), on %s, the hero carrying %d gold" % (run["name"], run["site"], "the mainland"
                                                         if run["land"] == "mainland" else "an island", run["gold"])]

    def pane(step: dict, pad: str) -> None:
        out.append("%s[%s | %s]  picture %s" % (pad, step["title"], step["subtitle"], step["picture"]))
        for line in step["lines"]:
            out.append("%s  %s" % (pad, line))
        for button in step["buttons"]:
            out.append("%s  (%s) %s%s" % (pad, "x" if button["ready"] else " ", button["label"],
                                          "" if button["ready"] else "   not ready: " + button["why"]))

    count = 0
    for step in run["steps"]:
        if step["kind"] == "pane":
            count += 1
            out.append("  %d. The pane%s (pane %d of sites.json%s; %d gold)" % (
                count, ", " + step["note"] if step["note"] else "", step["pane"],
                ", id %s" % step["pane_id"] if step.get("pane_id") else "", step["state"]["gold"]))
            pane(step, "     ")
        elif step["kind"] == "press":
            count += 1
            used = step["state"]["uses"].get(run["site"] + "." + step["action"], step["state"]["uses"].get(
                "%s.%s@%s" % (run["site"], step["action"], run["land"]), 0))
            if step.get("plain"):
                out.append("  %d. Press \"%s\": a talk, nothing paid or counted" % (count, step["label"]))
            elif step["refused"]:
                out.append("  %d. Press \"%s\": refused, nothing paid" % (count, step["label"]))
            elif step["earned"]:
                out.append("  %d. Press \"%s\": %d gold earned, %d now; %s used %d time%s" % (
                    count, step["label"], step["earned"], step["state"]["gold"], step["action"], used,
                    "" if used == 1 else "s"))
            else:
                out.append("  %d. Press \"%s\": %d gold paid, %d left; %s used %d time%s" % (
                    count, step["label"], step["paid"], step["state"]["gold"], step["action"], used,
                    "" if used == 1 else "s"))
            if step["taken"]:
                out.append("     taken: %s" % ", ".join(step["taken"]))
            if step["duel"]:
                out.append("     the duel is %s (a walk fights none: --win or --lose chooses)" % step["duel"])
            for roll in step["rolls"]:
                total = sum(roll["weights"])
                out.append("     a roll of %d outcomes; this walk takes outcome %d (--roll N chooses); on average %s gold"
                           % (len(roll["weights"]), roll["chosen"] + 1, fmt_num(round(roll["expected_gold"], 2))))
                for o, weight in enumerate(roll["weights"]):
                    out.append("       %s outcome %d: %d in %d, %s gold%s" % (
                        ">" if o == roll["chosen"] else " ", o + 1, weight, total, fmt_num(roll["gold"][o]),
                        ": " + " ".join(roll["says"][o]) if roll["says"][o] else ""))
            for key in step["raised"]:
                out.append("     dungeon raised: %s (open)" % key)
            if step["copied"]:
                out.append("     card copied: %s" % step["copied"])
            if step["traded"]:
                out.append("     card %s: %s" % ("sold" if step["earned"] else "bought", step["traded"]))
            for card in step["given"]:
                out.append("     card given: %s" % card)
            if step["gift"]:
                out.append("     for the next duel: %s" % step["gift"])
            for patch in step["revealed"]:
                out.append("     map uncovered: %s" % patch)
            for magic in step["learned"]:
                out.append("     World Magic learned: %s" % magic)
            if step["linked"]:
                out.append("     mana link made with %s" % step["linked"])
            if step["life_bonus"]:
                out.append("     life at the start of every duel: +%d now" % step["life_bonus"])
            if step["carried"]:
                out.append("     the pane closes; the hero is carried to %s (the walk steps back in)" % step["carried"])
            for line in step["journal"]:
                out.append("     journal: %s" % line)
            for line in step["lines"]:
                out.append("       %s" % line)
            if step["to"]:
                out.append("       (a talk: the pane %s is shown)" % step["to"])
            elif step["buttons"]:
                out.append("       %s" % "  ".join("(x) " + label for label in step["buttons"]))
            else:
                out.append("       (no result lines: the place's pane again)")
        elif step["kind"] == "note":
            out.append("     " + step["text"])
        else:
            count += 1
            out.append("  %d. The hero clears %s (%s): cleared" % (count, step["name"], step["dungeon"]))
    last = run["steps"][-1]["state"]
    other = "island" if run["land"] == "mainland" else "mainland"
    more = ""
    if last.get("counters"):
        more += "; counters %s" % ", ".join("%s %d" % pair for pair in last["counters"].items())
    if last.get("food"):
        more += "; food %d" % last["food"]
    if last.get("amulets"):
        more += "; amulets %s" % ", ".join("%s %d" % pair for pair in last["amulets"].items())
    if last.get("cards"):
        more += "; cards %s" % ", ".join(last["cards"][1:] or ["none of the walk's own"])
    if last.get("magics"):
        more += "; World Magics %s" % ", ".join(last["magics"])
    if last.get("life_bonus"):
        more += "; life bonus +%d" % last["life_bonus"]
    if last.get("linked"):
        more += "; the nearest town linked"
    out.append("  End: %d gold; uses %s; flags %s; dungeons %s%s." % (
        last["gold"], ", ".join("%s %d" % (key.replace("@" + run["land"], ""), n) if not key.endswith("@" + other)
                                else "%s %d on %s" % (key.replace("@" + other, ""), n, "the mainland" if other == "mainland"
                                                      else "an island") for key, n in last["uses"].items()) or "none",
        ", ".join(last["flags"]) or "none", ", ".join("%s %s" % pair for pair in last["dungeons"].items()) or "none",
        more))
    return out


def _pairs(values: list, option: str, number: bool = True) -> dict:
    """--counter wins=3 --counter tries=1 (or "red=2,blue=1") as a dict."""
    out = {}
    for value in values:
        for part in str(value).split(","):
            name, sign, amount = part.strip().partition("=")
            if not sign or not name or (number and not is_valid_int(amount.strip())):
                raise UsageError("%s takes name=number, like %s wins=3." % (option, option))
            out[name.strip()] = int(amount) if number else amount.strip()
    return out


def _names(values: list) -> list:
    return [part.strip() for value in values for part in str(value).split(",") if part.strip()]


def walk_options(args, data: dict) -> dict:
    """The hero a walk's options describe, checked against the plugin."""
    file = data["sites"]
    flags = _names(args.flag)
    for flag in flags:
        if flag not in file["flags"]:
            raise UsageError("--flag %s: sites.json flags has no %s (its flags: %s)."
                             % (flag, flag, ", ".join(file["flags"]) or "none"))
    counters = _pairs(args.counter, "--counter")
    for name in counters:
        if name not in file.get("counters", []):
            raise UsageError("--counter %s: sites.json counters has no %s (its counters: %s)."
                             % (name, name, ", ".join(file.get("counters", [])) or "none"))
    amulets = _pairs(args.amulets, "--amulets")
    for color in amulets:
        if color not in AMULET_COLORS:
            raise UsageError("--amulets takes color=number with a color of %s." % ", ".join(AMULET_COLORS))
    if args.color and args.color not in AMULET_COLORS:
        raise UsageError("--color takes one of %s." % ", ".join(AMULET_COLORS))
    if args.win and args.lose:
        raise UsageError("--win and --lose: a duel ends one way; name one.")
    out = {"food": args.food, "flags": flags, "counters": counters, "cards": _names(args.cards), "amulets": amulets,
           "magics": _names(args.magic) + _names(args.magics), "day": args.day, "wizards": args.wizards, "peace": args.peace,
           "difficulty": args.difficulty, "plugins": _names(args.plugin), "gift": args.gift, "roll": args.roll,
           "life_bonus": args.life_bonus, "linked": args.linked}
    if args.color:
        out["color"] = args.color
    if args.win or args.lose:
        out["outcome"] = "win" if args.win else "lose"
    return out


def command_walk(args, game: Game) -> int:
    result = judge(_existing(args.plugin), game)
    if result["valid"] and manifest_kind(result["manifest"]) != KIND_SITES:
        raise UsageError("%s is an island plugin: walk plays a sites plugin's places." % args.plugin)
    if result["valid"] and args.site and args.site not in result["data"]["sites"]["sites"]:
        raise UsageError("%s has no place %s (its places: %s)." % (args.plugin, args.site,
                                                                   ", ".join(result["data"]["sites"]["sites"])))
    if args.gold < 0:
        raise UsageError("--gold must be 0 or more.")
    if args.land and args.both:
        raise UsageError("--land walks one land and --both walks both with one hero; name one.")
    runs = []
    unreached: dict = {}
    if result["valid"]:
        data = result["data"]
        options = walk_options(args, data)
        places = [args.site] if args.site else list(data["sites"]["sites"])
        press = _names([args.press]) if args.press else None
        if press is not None:
            if len(places) != 1:
                raise UsageError("--press presses one place's buttons: name the place with --site (the places: %s)."
                                 % ", ".join(places))
            known = list(_site_actions(data["sites"]["sites"][places[0]])) + ["leave", "clear"]
            for name in press:
                if name not in known:
                    raise UsageError("--press %s: the place %s has no such button (its buttons: %s; and leave, clear)."
                                     % (name, places[0], ", ".join(known[:-2])))
        for site in places:
            lands = walk_lands(data, site)
            if args.land:
                if args.land not in lands:
                    if args.site:
                        raise UsageError("--land %s: the place %s stands on %s only." % (args.land, site, " and ".join(lands)))
                    continue
                lands = [args.land]
            hero = walk_hero(data, args.gold, options) if args.both else None
            mine = []
            for land in lands:
                mine.append(walk_site(data, site, args.gold, land, options, hero, press))
            runs.extend(mine)
            if press is None and args.both and len(mine) > 1:
                # One hero: what the second land shows depends on the first.
                for run in mine:
                    unreached["%s on %s" % (site, "the mainland" if run["land"] == "mainland" else "an island")] = \
                        never_reached(data, site, [run])
            elif press is None:
                unreached[site] = never_reached(data, site, mine)
    if args.json:
        print(json.dumps(dict(report(result), sites=runs, never_reached=unreached), ensure_ascii=False, indent="\t"))
        return 0 if result["valid"] else 1
    if not result["valid"]:
        for problem in result["problems"]:
            print(problem)
        print("%s: refused at the %s stage; a walk needs a valid plugin." % (args.plugin, result["stage"]), file=sys.stderr)
        return 1
    print("A walk without the game: every dungeon finds room, the hero holds one card to copy (%s), "
          "(x) is a button that can be pressed." % WALK_CARD)
    for run in runs:
        print("\n" + "\n".join(_walk_text(run)))
    missed = [(site, lines) for site, lines in unreached.items() if lines]
    if missed:
        print("\nNever reached in this walk (walk --help lists what a walk's hero can be given):")
        for site, lines in missed:
            for line in lines:
                print("  %s: %s" % (site, line))
    elif press is None and runs:
        print("\nEvery pane was shown and every button pressed.")
    return 0
# ----------------------------------------------------------------- art --

def close_names(name: str, names, most: int = 3) -> list:
    """The names of [names] nearest to [name] (a typing slip's cure)."""
    import difflib
    lowered: dict = {}
    for known in names:
        lowered.setdefault(str(known).lower(), str(known))
    return [lowered[hit] for hit in difflib.get_close_matches(name.lower(), list(lowered), n=most, cutoff=0.72)]


def suggested_key(path: str) -> str:
    """A text key for the sentence found at [path] of sites.json, like shrine.line1."""
    site = re.search(r"\.sites\.([a-z][a-z0-9_]*)", path)
    stem = site.group(1) if site else "place"
    action = re.search(r"actions\[(\d+)\]", path)
    tail = "line"
    for part in ("label", "result", "title", "subtitle", "pick_title", "pick_line", "text"):
        if "." + part in path:
            tail = part
    index = re.findall(r"\[(\d+)\]", path)
    return "%s.%s%s%d" % (stem, "action%s_" % action.group(1) if action else "", tail, int(index[-1]) + 1 if index else 1)
def text_hints(path: str, key: str, words: dict) -> list:
    """What to do about a text key text.json lacks: a sentence written
    where a key belongs, or a key mistyped."""
    if re.search("^[a-z0-9_.]{1,64}$", key) is None:
        return ["%s holds a sentence, and a line holds a text key: put the sentence in text.json under a key, like "
                "\"%s\", and write that key here (set-text does the first half: set-text FOLDER %s \"...\")."
                % (path, suggested_key(path), suggested_key(path))]
    near = close_names(key, list(words))
    return ["%s: text.json's nearest keys to %s: %s." % (path, key, ", ".join(near))] if near else []


def card_hints(game: Game, path: str, card: str, packs: list) -> list:
    """What to do about an unknown card: the nearest names, and the pack
    that holds it when the plugin does not require that pack."""
    known = set(game.base or ())
    for pack in packs:
        known.update(game.packs.get(pack, ()))
    out = []
    near = close_names(card, known)
    if near:
        out.append("%s: the nearest card names to %s: %s." % (path, card, ", ".join(near)))
    elsewhere = sorted(pack for pack, cards in game.packs.items() if card in cards and pack not in packs)
    if elsewhere:
        out.append("%s: %s is a card of %s: name that pack in plugin.json requires.card_packs to use it."
                   % (path, card, ", ".join(elsewhere)))
    return out


def api_words_of(game: Game, manifest: dict, files: dict) -> list:
    """The words of API 3 the sites plugin made of [files] uses, each once
    ([] too when its content is refused for another reason)."""
    reader = Content(game)
    reader.read(dict(manifest, api_version=API_VERSION), files)
    return list(dict.fromkeys(word for word, _ in reader.api_words))


# --------------------------------------------------------------------------
# WARNINGS — what validate says of a sites plugin that loads but is not
# finished or will surprise its players. A warning never refuses: the game
# has no such check, and the corpus's verdicts stay the game's.
# --------------------------------------------------------------------------

## What new and add-place write for an author to replace.
STAND_IN_LICENSE = "Name the license of your plugin here, and put its text in LICENSE.txt."
STAND_IN_DESCRIPTION = "One line for the plugin list: what the hero finds at this place."
STAND_IN_MARK = "Write here"
## The placeholders an island plugin's texts fill and a place's never do.
ISLAND_PLACEHOLDERS = ["pledges", "quests_total", "target", "town", "title", "total", "required", "percent", "left",
                       "cards"]
## A pane does not scroll: past this many lines or characters its buttons
## may leave the screen (the picture shrinks first).
PANE_LINES, PANE_CHARS = 10, 1200


def _about_dungeon(conditions: list, effects: list) -> bool:
    return any("spawn_dungeon" in e for e in effects) or SiteWalk.named_condition(conditions, "dungeon") is not None


def _about_counter(conditions: list, effects: list) -> bool:
    return any("counter" in e for e in effects) or SiteWalk.named_condition(conditions, "counter") is not None


def placeholders_in(template: str) -> list:
    return [word for word in re.findall(r"\{([a-z0-9_]{1,40})\}", str(template)) if word in PLACEHOLDERS]


def _stand_in_pictures() -> set:
    """The SHA-256 of every picture the tool itself draws for a place."""
    out = set()
    for rows, colors in PLACE_LOOKS.values():
        out.add(sha256(_site_picture(rows, colors)))
        out.add(sha256(_sprite(rows, colors)))
    return out


def site_warnings(manifest: dict, data: dict, files: dict) -> list:
    """Every warning for a valid sites plugin, one sentence each."""
    file, text = data["sites"], data["text"]
    out: list = []
    always = {"hero", "gold", "region", "food", "amulets", "day", "life_bonus"}
    uses: dict = {}     # text key -> [(where, allowed placeholders)]

    def use(key, where: str, allowed: set) -> None:
        if isinstance(key, str):
            uses.setdefault(key, []).append((where, allowed))

    def use_lines(lines: list, where: str, allowed: set) -> None:
        for line in lines:
            if isinstance(line, str):
                use(line, where, allowed)
            elif "one_of" in line:
                for key in line["one_of"]:
                    use(key, where, allowed)
            else:
                use(line.get("text"), where, allowed)

    several = {"dungeon": len(file["dungeons"]) > 1, "count": len(file.get("counters", [])) > 1}

    def about(conditions: list, effects: list) -> set:
        """{dungeon} and {count} are filled wherever the plugin has a
        dungeon or a counter: the one the action or the pane is about, else
        the plugin's first."""
        more = set()
        if file["dungeons"]:
            more.add("dungeon" if _about_dungeon(conditions, effects) or not several["dungeon"] else "dungeon?")
        if file.get("counters"):
            more.add("count" if _about_counter(conditions, effects) or not several["count"] else "count?")
        return more

    read_flags, set_flags, read_counters, set_counters = set(), set(), set(), set()
    spawned, fought, talked, pictures_used = set(), set(), {}, set()
    for where, _, conditions in site_condition_lists(file):
        for condition in _flat_conditions(conditions):
            name = next(iter(condition))
            if name in ("flag", "not_flag"):
                read_flags.add(condition[name])
            elif name == "counter":
                read_counters.add(condition[name]["name"])
    for key, site in file["sites"].items():
        both = len(site["where"]) > 1
        pictures_used.add(site["picture"])
        plain_seen_last = False
        for p, pane in enumerate(site["panes"]):
            here = "sites.%s.panes[%d]" % (key, p)
            if "picture" in pane:
                pictures_used.add(pane["picture"])
            conditions = list(pane["when"])
            for line in pane["lines"]:
                if isinstance(line, dict):
                    conditions += line.get("when", [])
            allowed = always | about(conditions, [effect for action in pane["actions"]
                                                  for effect in action_effects(action) if "spawn_dungeon" in effect])
            use(pane.get("title"), here + ".title", allowed)
            use(pane.get("subtitle"), here + ".subtitle", allowed)
            use_lines(pane["lines"], here + ".lines", allowed)
            if "id" not in pane:
                if plain_seen_last:
                    out.append("sites.json: %s is never shown: a pane before it has no when, and the first pane whose "
                               "when holds is the one shown. Put the pane without a when last." % here)
                plain_seen_last = plain_seen_last or not pane["when"]
            size = sum(len(str(text.get(k, ""))) for k in
                       [l if isinstance(l, str) else l.get("text", (l.get("one_of") or [""])[0]) for l in pane["lines"]])
            if len(pane["lines"]) > PANE_LINES or size > PANE_CHARS:
                out.append("sites.json: %s is long (%d lines, about %d characters): a pane does not scroll, so past "
                           "about %d lines or %d characters its buttons may leave the screen. Split it with a talk "
                           "action and a pane with an id." % (here, len(pane["lines"]), size, PANE_LINES, PANE_CHARS))
        seen_actions = set()
        for p, pane in enumerate(site["panes"]):
            for a, action in enumerate(pane["actions"]):
                if action["id"] in seen_actions:
                    continue
                seen_actions.add(action["id"])
                spot = "sites.%s.panes[%d].actions[%d]" % (key, p, a)
                do = str(action["do"])
                effects = action_effects(action)
                priced = bool(action.get("prices"))
                mine = always | about(action["when"], effects)
                if priced:
                    mine |= {"price", "uses_left"}
                if do == "duel":
                    mine |= {"foe", "life"}
                    fought.add(action.get("foe"))
                if do == "talk":
                    talked[action.get("to")] = True
                gives_card = any("give_card" in e for e in effects) or any("card" in n for n in action.get("needs", []))
                if gives_card:
                    mine.add("card")
                if any("world_magic" in e for e in effects):
                    mine.add("title")
                if any("mana_link" in e or ("teleport" in e and e["teleport"].get("to") == "nearest_town") for e in effects):
                    mine.add("town")
                if "label" in action:
                    use(action["label"], spot + ".label", mine)
                    if not priced and do != "leave":
                        for word in ("price", "uses_left"):
                            if "{%s}" % word in str(text.get(action["label"], "")):
                                out.append("text.json: %s: {%s} in the label of %s, which has no prices: a free "
                                           "action's label shows %s. Give the action prices, or take {%s} out."
                                           % (action["label"], word, spot, "0 gold" if word == "price" else "nothing "
                                              "there (\"( left)\")", word))
                after = mine | {"price"} | ({"card"} if do in ("copy_card", "buy_card", "sell_card") else set())
                for where, lines in action_line_lists(action, spot):
                    use_lines(lines, where, after)
                for word in ("pick_title", "pick_line"):
                    use(action.get(word), "%s.%s" % (spot, word), mine | {"price", "uses_left"})
                for effect in effects:
                    name = next(iter(effect))
                    value = effect[name]
                    if name in ("log_clue", "log_event"):
                        use(value["text"], "%s (%s)" % (spot, name), after)
                    elif name == "set_flag":
                        set_flags.add(value)
                    elif name == "counter":
                        set_counters.add(value["name"])
                    elif name == "spawn_dungeon":
                        spawned.add(value)
                        if both and priced and int(manifest.get("api_version", 2)) < SITES_WORDS_API:
                            out.append("sites.json: %s raises the dungeon %s for a price at a place that stands on "
                                       "the mainland and on islands: this game counts the payment on each land by "
                                       "itself, but a game from before plugin API 3 counts it once for all lands, "
                                       "and there the button is gone on the second land. Keep the place on one "
                                       "land, or set api_version 3 so that only a game with the fix reads the "
                                       "plugin." % (spot, value))
                # Gold, amulets or cards for nothing, without end.
                endless = not priced and not action.get("needs") and do in ("effects", "talk", "duel")
                gain = SiteWalk.gold_of(action.get("effects", []))
                if do == "duel":
                    gain = SiteWalk.gold_of(action.get("win", {}).get("effects", []))
                limited = any(next(iter(c)) in ("not_flag", "counter", "used", "gold_below", "site_used", "dungeon")
                              for c in _flat_conditions(action["when"]))
                if endless and gain > 0 and not limited:
                    out.append("sites.json: %s gives %s gold each time, has no prices and no needs, and nothing in its "
                               "when ends it: a hero can press it without end. Give it prices (a list of 0s limits a "
                               "free gift), a need, or a when with not_flag or counter."
                               % (spot, fmt_num(round(gain, 2))))
                if priced and any("roll" in e for e in action.get("effects", [])):
                    least = min(int(n) for n in action["prices"])
                    if gain > least:
                        out.append("sites.json: %s: its roll pays %s gold on average and its cheapest price is %d: "
                                   "the hero wins gold by playing on. Lower a prize or its weight, or raise the "
                                   "price." % (spot, fmt_num(round(gain, 2)), least))
        for p, pane in enumerate(site["panes"]):
            if "id" in pane and pane["id"] not in talked:
                out.append("sites.json: sites.%s.panes[%d] (id %s) is never shown: no talk action leads to it (to: \"%s\")."
                           % (key, p, pane["id"], pane["id"]))
        talked.clear()
    for key, task in file.get("tasks", {}).items():
        for part in ("title", "text", "done"):
            use(task.get(part), "tasks.%s.%s" % (key, part), always | about([], []))
    for flag in file["flags"]:
        if flag not in read_flags or flag not in set_flags:
            out.append("sites.json: the flag %s is %s." % (flag, "never used" if flag not in read_flags | set_flags else
                                                           "set, but no when reads it" if flag in set_flags else
                                                           "read by a when, but no effect sets it"))
    for name in file.get("counters", []):
        if name not in set_counters:
            out.append("sites.json: the counter %s is %s." % (name, "never used" if name not in read_counters else
                                                              "read by a when, but no effect changes it"))
    for key in file["dungeons"]:
        if key not in spawned:
            out.append("sites.json: no action raises the dungeon %s (an effect {\"spawn_dungeon\": \"%s\"}; "
                       "add-dungeon --place adds the button)." % (key, key))
    for key in file.get("foes", {}):
        if key not in fought:
            out.append("sites.json: no duel action names the foe %s." % key)
    for key in file["pictures"]:
        if key not in pictures_used:
            out.append("sites.json: the picture %s is used by no place and no pane." % key)
    for key, template in text.items():
        found = placeholders_in(template)
        if STAND_IN_MARK in str(template):
            out.append("text.json: %s still holds the tool's stand-in words (\"%s...\"): write your own "
                       "(set-text %s \"...\")." % (key, STAND_IN_MARK, key))
        if key not in uses:
            if key not in TEXT_DEFAULTS:
                out.append("text.json: %s is used nowhere in sites.json." % key)
            continue
        for word in found:
            if word in ISLAND_PLACEHOLDERS and not any(word in allowed for _, allowed in uses[key]):
                out.append("text.json: %s: {%s} is filled in an island plugin's texts only; a place shows it as "
                           "it is written." % (key, word))
                continue
            guessed = [where for where, allowed in uses[key] if word + "?" in allowed]
            if guessed:
                first = next(iter(file["dungeons"])) if word == "dungeon" else file["counters"][0]
                out.append("text.json: %s: {%s} at %s is the plugin's first %s (%s): nothing there says which of "
                           "its %ss is meant. %s" % (key, word, guessed[0], "dungeon" if word == "dungeon" else "counter",
                                                    first, "dungeon" if word == "dungeon" else "counter",
                                                    PLACEHOLDER_HOMES[word]))
                continue
            wrong = [where for where, allowed in uses[key] if word not in allowed]
            if wrong:
                out.append("text.json: %s: {%s} cannot be filled at %s%s: %s" % (
                    key, word, wrong[0], " (and %d more)" % (len(wrong) - 1) if len(wrong) > 1 else "",
                    PLACEHOLDER_HOMES.get(word, "it is not filled there.")))
    if str(manifest.get("license", "")) == STAND_IN_LICENSE:
        out.append("plugin.json: license still holds the tool's stand-in words: name your plugin's license.")
    if str(manifest.get("description", "")) == STAND_IN_DESCRIPTION:
        out.append("plugin.json: description still holds the tool's stand-in words: say in one line what the hero "
                   "finds.")
    drawn = _stand_in_pictures()
    stand_ins = sorted(rel for rel in list(file["pictures"].values()) +
                       [site["sprite"]["file"] for site in file["sites"].values()]
                       if rel in files and sha256(files[rel]) in drawn)
    if stand_ins:
        out.append("art: %d picture%s the tool's stand-in%s to paint over: %s (art PLUGIN gives advice on sizes)."
                   % (len(stand_ins), " is" if len(stand_ins) == 1 else "s are", "" if len(stand_ins) == 1 else "s",
                      ", ".join(stand_ins)))
    return out


## Where a placeholder is filled, said when a text uses it elsewhere.
PLACEHOLDER_HOMES = {
    "town": "{town} is filled in an action that teleports to the nearest town or makes a mana link.",
    "title": "{title} is filled in an action that teaches a World Magic.",
    "price": "{price} is filled in the label, the result and the journal lines of an action with prices, not in a "
             "pane's own lines.",
    "uses_left": "{uses_left} is filled in the label of an action with prices.",
    "card": "{card} is filled in the result of a copy, a trade, a give_card or a need of a card.",
    "dungeon": "{dungeon} is the dungeon its action raises or its when asks about (a pane's: its own when, or a "
               "button's of the pane); elsewhere write the dungeon's name out.",
    "count": "{count} is the counter its action changes or its when asks about (a line's own when first).",
    "foe": "{foe} is filled in a duel action's label and result.",
    "life": "{life} is filled in a duel action's label and result.",
    "color": "{color} is filled in the game's own sentence for missing amulets.",
}
# --------------------------------------------------------------------------
# guide — GUIDE/cheatsheet.html: every word a place may use, one line each,
# from schema_v1.json (the words, their order and what each does are the
# schema's; the examples below are checked against it by the tests, and a
# word the schema gains gets an example made from its shape until one is
# written here)
# --------------------------------------------------------------------------

## A condition as add-action --when and add-pane --when take it.
CHEAT_WHEN = {
    "flag": "flag=told", "not_flag": "not_flag=told", "gold_at_least": "gold_at_least=500", "on_mainland": "on_mainland=true",
    "used": "used=bless:1-2", "used_up": "used_up=bless", "dungeon": "dungeon=vault:open",
    "has_card": "has_card=Black Lotus", "amulets": "amulets=red:2", "hero_color": "hero_color=red",
    "owns_magic": "owns_magic=Dwarven Pick", "food_at_least": "food_at_least=10", "gold_below": "gold_below=100",
    "day_at_least": "day_at_least=30", "wizards_defeated": "wizards_defeated=2", "at_peace": "at_peace=true",
    "difficulty": "difficulty=0-1", "plugin_on": "plugin_on=old_hut", "counter": "counter=wins:3",
    "site_used": "site_used=hut.secret", "gift_waiting": "gift_waiting=false", "any": "flag=told | gold_at_least=500",
    "life_bonus_below": "life_bonus_below=10", "town_linked": "town_linked=nearest_town"}
## An effect as add-action --effect takes it.
CHEAT_EFFECT = {
    "set_flag": "set_flag=told", "clear_flag": "clear_flag=told", "gold": "gold=-100", "food": "food=6",
    "spawn_dungeon": "spawn_dungeon=vault", "log_clue": "log_clue=The old man told you of a vault.",
    "log_event": "log_event=Paid at the shrine.", "counter": "counter=wins+1", "amulet": "amulet=red",
    "give_card": "give_card=Shivan Dragon", "next_duel": "next_duel=life:5", "reveal_map": "reveal_map=place:4",
    "world_magic": "world_magic=Dwarven Pick", "mana_link": "mana_link=nearest_town", "life_bonus": "life_bonus=1",
    "teleport": "teleport=nearest_town"}
CHEAT_NEED = {"card": "card=Black Lotus", "amulets": "amulets=any:3", "food": "food=5"}
## An action of each kind, as it stands in sites.json, and the command that writes one like it.
CHEAT_DO = {
    "effects": ({"id": "bless", "do": "effects", "label": "shrine.bless", "prices": [20, 40],
                 "effects": [{"food": 6}], "result": ["shrine.blessed"]},
                "add-action FOLDER --place shrine --id bless --prices 20,40 --effect food=6 --label \"Leave {price} gold\" "
                "--result \"Your pack is heavier.\""),
    "copy_card": ({"id": "copy", "do": "copy_card", "prices": [500, 1000], "result": ["tower.copied"]},
                  "add-action FOLDER --place tower --id copy --do copy --prices 500,1000 --result \"A copy of {card} is yours.\""),
    "leave": ({"id": "leave", "do": "leave", "label": "shrine.leave"}, "(every pane the tool writes has one)"),
    "talk": ({"id": "ask", "do": "talk", "to": "rumors", "label": "inn.ask"},
             "add-pane FOLDER --place inn --id rumors --line \"They say...\"; add-action FOLDER --place inn --id ask "
             "--do talk --to rumors --label \"Ask for rumors\""),
    "duel": ({"id": "duel", "do": "duel", "foe": "champion", "prices": [50, 50],
              "win": {"effects": [{"gold": 100}], "result": ["ring.won"]}, "lose": {"result": ["ring.lost"]}},
             "add-foe FOLDER --id champion --name \"The Champion\" --deck deck.txt; add-action FOLDER --place ring "
             "--id duel --do duel --foe champion --prices 50,50 --win-effect gold=100 --win \"You win.\" --lose \"You lose.\""),
    "buy_card": ({"id": "buy", "do": "buy_card", "cards": {"Shivan Dragon": 400}, "stock": 1},
                 "add-action FOLDER --place stall --id buy --do buy --cards \"Shivan Dragon=400\" --stock 1"),
    "sell_card": ({"id": "sell", "do": "sell_card", "cards": {"Black Lotus": 900}},
                  "add-action FOLDER --place stall --id sell --do sell --cards \"Black Lotus=900\"")}
CHEAT_ROLL = {"roll": {"outcomes": [{"weight": 3, "result": ["den.lost"]},
                                    {"weight": 1, "effects": [{"gold": 150}], "result": ["den.won"]}]}}
CHEAT_LINES = [("a text key", "shrine.intro", "The sentence of text.json under that key."),
               ("a line with a when", {"text": "shrine.again", "when": [{"used": {"action": "bless", "min": 1}}]},
                "Shown only while its conditions hold."),
               ("one_of", {"one_of": ["inn.rumor1", "inn.rumor2", "inn.rumor3"], "by": "day"},
                "One of the texts, in turn: the next one each day, or with \"by\": \"uses\" each time an action of "
                "the place is done. No dice.")]
## A sentence that uses each placeholder a place fills, and where it is filled.
CHEAT_PLACEHOLDERS = {
    "hero": ("Welcome back, {hero}.", "everywhere"),
    "gold": ("You carry {gold} gold.", "everywhere"),
    "region": ("The finest inn of {region}.", "everywhere"),
    "food": ("You carry {food} days of food.", "everywhere"),
    "amulets": ("You carry {amulets} amulets.", "everywhere"),
    "day": ("Day {day} of your journey.", "everywhere"),
    "life_bonus": ("The places have added {life_bonus} life to your duels.", "everywhere"),
    "town": ("Ride to {town} (100 gold)", "an action that teleports to the nearest town or makes a mana link"),
    "title": ("Learn {title} ({price} gold)", "an action that teaches a World Magic"),
    "price": ("Pay {price} gold", "an action with prices: its label, result and journal lines"),
    "uses_left": ("Pay {price} gold ({uses_left} left)", "the label of an action with prices"),
    "card": ("A copy of {card} is yours.", "the result of a copy or a trade; an action that gives or needs a card"),
    "dungeon": ("The way to {dungeon} is marked on your map.",
                "the dungeon an action raises or a when asks about; else the plugin's first"),
    "count": ("You have won {count} bouts.", "the counter an action changes or a when asks about; else the plugin's first"),
    "foe": ("Wager {price} gold against {foe}", "a duel action's label and result"),
    "life": ("{foe} has {life} life.", "a duel action's label and result"),
    "color": ("You need {count} {color} amulets for this.", "the game's own sentence site.needs_amulets")}


def example_of(schema: dict, spec: dict):
    """A small value of [spec]'s shape, for a word no example is written for."""
    kind = spec.get("kind")
    if kind == "ref":
        return example_of(schema, schema["types"][spec["type"]])
    if kind in ("int", "number"):
        return max(1, int(spec.get("min", 1)))
    if kind == "bool":
        return True
    if kind == "enum":
        return spec["values"][0]
    if kind == "card":
        return "Lightning Bolt"
    if kind == "text":
        return "place.words"
    if kind == "array":
        return [example_of(schema, spec["items"]) for _ in range(max(1, int(spec.get("min", 1))))]
    if kind == "object":
        return {key: example_of(schema, field) for key, field in spec.get("fields", {}).items()
                if field.get("required")}
    if kind == "single":
        key = next(iter(spec["options"]))
        return {key: example_of(schema, spec["options"][key])}
    if kind == "oneof":
        return example_of(schema, spec["options"][0])
    if kind == "map":
        return {"key": example_of(schema, spec["values"])}
    return "name"


def cheat_rows(game: Game) -> dict:
    """The cheat sheet's rows, by section: (word, JSON example, the command
    line's form or "", what it does). The words and their order are the
    schema's."""
    schema = game.schema()
    types = schema["types"]
    v3 = schema.get("v3_words", {})

    def doc(spec: dict) -> str:
        while spec.get("kind") == "ref" and "doc" not in spec:
            spec = types[spec["type"]]
        return str(spec.get("doc", "")).replace("API 3. ", "")

    def api(group: str, word: str) -> str:
        return "3" if word in v3.get(group, []) else "2"

    out = {"conditions": [], "effects": [], "actions": [], "needs": [], "lines": [], "fields": [], "placeholders": []}
    for name, spec in types["sites_condition"]["options"].items():
        short = CHEAT_WHEN.get(name, "")
        value = parse_condition(short, game) if short else {name: example_of(schema, spec)}
        out["conditions"].append((name, value, "--when \"%s\"" % short if short else "", doc(spec), api("condition", name)))
    for name, spec in types["sites_effect"]["options"].items():
        short = CHEAT_EFFECT.get(name, "")
        if name == "roll":
            value, shown = CHEAT_ROLL, "--outcome \"3 |  | You lose.\" --outcome \"1 | gold=150 | You win!\""
        elif short:
            value, shown = parse_effect(short, game, {}, "shrine.bless"), "--effect \"%s\"" % short
        else:
            value, shown = {name: example_of(schema, spec)}, ""
        out["effects"].append((name, value, shown, doc(spec), api("effect", name)))
    for name in types["sites_action"]["fields"]["do"]["values"]:
        value, shown = CHEAT_DO.get(name, ({"id": "act", "do": name}, ""))
        out["actions"].append((name, value, shown, "", api("do", name)))
    for name, spec in types.get("sites_need", {"options": {}})["options"].items():
        short = CHEAT_NEED.get(name, "")
        value = parse_need(short) if short else {name: example_of(schema, spec)}
        out["needs"].append((name, value, "--needs \"%s\"" % short if short else "", doc(spec), "3"))
    for name, value, words in CHEAT_LINES:
        out["lines"].append((name, value, "", words, "3" if name == "one_of" else "2"))
    for group, type_name, label in (("file", "sites_file", "sites.json"), ("pane", "sites_pane", "a pane"),
                                    ("action", "sites_action", "an action")):
        for name, spec in types[type_name]["fields"].items():
            out["fields"].append((name, label, doc(spec), api(group, name)))
    for name, words in schema["placeholders"].items():
        if name in ("town", "title"):
            words = {"town": "the nearest town or city, in an action that goes there or links it",
                     "title": "the World Magic an action teaches"}[name]
        if name in CHEAT_PLACEHOLDERS:
            out["placeholders"].append((name, CHEAT_PLACEHOLDERS[name][0], CHEAT_PLACEHOLDERS[name][1], words))
        elif name not in ISLAND_PLACEHOLDERS:
            out["placeholders"].append((name, "... {%s} ..." % name, "", words))
    # {town} and {title} are an island's words that a place fills in two kinds of action.
    order = list(schema["placeholders"])
    out["placeholders"].sort(key=lambda row: order.index(row[0]))
    return out


def cheatsheet_html(game: Game, masthead: str, toc: str) -> str:
    rows = cheat_rows(game)
    schema = game.schema()

    def js(value) -> str:
        return _e(json.dumps(value, ensure_ascii=False))

    def table(group: str, first: str, with_command: bool = True) -> str:
        body = []
        for name, value, shown, words, api in rows[group]:
            body.append("<tr><td data-label=\"%s\"><code>%s</code>%s</td><td data-label=\"In sites.json\"><code class=\"ex\">%s</code></td>%s"
                        "<td class=\"doc\" data-label=\"What it does\">%s</td></tr>" % (
                            _e(first), _e(name), " <span class=\"api\">API 3</span>" if api == "3" else "", js(value),
                            "<td data-label=\"On the command line\">%s</td>" % ("<code class=\"ex\">%s</code>" % _e(shown) if shown else "")
                            if with_command else "", _e(words)))
        return ('<div class="table-wrap"><table class="fields cheat"><thead><tr><th>%s</th><th>In sites.json</th>%s'
                '<th>What it does</th></tr></thead><tbody>\n%s\n</tbody></table></div>' % (
                    _e(first), "<th>On the command line</th>" if with_command else "", "\n".join(body)))

    do_doc = str(schema["types"]["sites_action"]["fields"]["do"].get("doc", ""))
    body = ['<h1>Places: the cheat sheet</h1>',
            '<p class="lede">Every word a place of a sites plugin may use, one line each: what to write in '
            '<code>sites.json</code>, how the tool\'s commands take it, and what it does. '
            '<a href="sites.html">Places: sites plugins</a> explains them at length; <a href="reference.html">'
            'Reference</a> gives every limit.</p>',
            '<p class="generated">Written by <code>tools/adventure_plugin.py guide</code> from '
            '<code>game/adventure/plugins/schema_v1.json</code>. Words marked <span class="api">API 3</span> need '
            '<code>"api_version": 3</code> in <code>plugin.json</code>; the tool\'s commands set it by themselves.</p>',
            '<nav class="mini-toc" aria-label="On this page"><ol><li><a href="#cheat-conditions">Conditions</a></li>'
            '<li><a href="#cheat-effects">Effects</a></li><li><a href="#cheat-actions">Actions</a></li>'
            '<li><a href="#cheat-costs">Costs</a></li><li><a href="#cheat-lines">Lines</a></li>'
            '<li><a href="#cheat-placeholders">Placeholders</a></li><li><a href="#cheat-fields">Fields</a></li>'
            '<li><a href="#cheat-recipes">Recipes</a></li><li><a href="#cheat-commands">Commands</a></li></ol></nav>',
            '<section id="cheat-conditions"><h2>Conditions</h2><p>A <code>when</code> is a list; all of it must '
            'hold. It may stand on a pane, a line, an action, a result line and a task. On the command line, '
            'repeat <code>--when</code> for each.</p>%s</section>' % table("conditions", "Condition"),
            '<section id="cheat-effects"><h2>Effects</h2><p>The <code>effects</code> of an action that does '
            '<code>effects</code> or <code>talk</code>, of a duel\'s <code>win</code> and <code>lose</code>, and of '
            'a roll\'s outcomes, applied in order once the price is paid.</p>%s</section>' % table("effects", "Effect"),
            '<section id="cheat-actions"><h2>Actions</h2><p>A button of a pane. Its <code>do</code> says what it '
            'does: %s</p>%s</section>' % (_e(do_doc), table("actions", "do")),
            '<section id="cheat-costs"><h2>Costs</h2><p><code>"prices": [20, 40, 80]</code>: the gold each use '
            'costs, in turn; after the last price the button is gone. <code>"prices": [0]</code>: free, once. No '
            '<code>prices</code>: free, and never used up. <code>needs</code> is what the action takes besides '
            'gold, each time; the button is refused, and nothing paid, while the hero lacks one.</p>%s</section>'
            % table("needs", "Need"),
            '<section id="cheat-lines"><h2>Lines</h2><p>The <code>lines</code> of a pane and the <code>result</code> '
            'of an action are lists of these.</p>%s</section>' % table("lines", "Line", False),
            '<section id="cheat-placeholders"><h2>Placeholders</h2><p>Words in braces that the game fills in a '
            'text of <code>text.json</code>. <code>validate</code> warns when one stands where it is not filled.</p>'
            '<div class="table-wrap"><table class="fields cheat"><thead><tr><th>Placeholder</th><th>For example'
            '</th><th>Filled</th><th>What it says</th></tr></thead><tbody>\n%s\n</tbody></table></div></section>'
            % "\n".join("<tr><td data-label=\"Placeholder\"><code>{%s}</code></td><td data-label=\"For example\">%s</td>"
                        "<td data-label=\"Filled\">%s</td><td class=\"doc\" data-label=\"What it says\">%s</td></tr>"
                        % (_e(name), _e(sample), _e(where), _e(words)) for name, sample, where, words in rows["placeholders"]),
            '<section id="cheat-fields"><h2>Fields</h2><p>Every field of <code>sites.json</code>, of a pane and of '
            'an action.</p><div class="table-wrap"><table class="fields cheat"><thead><tr><th>Field</th><th>Of</th>'
            '<th>What it is</th></tr></thead><tbody>\n%s\n</tbody></table></div></section>'
            % "\n".join("<tr><td data-label=\"Field\"><code>%s</code>%s</td><td data-label=\"Of\">%s</td>"
                        "<td class=\"doc\" data-label=\"What it is\">%s</td></tr>"
                        % (_e(name), " <span class=\"api\">API 3</span>" if api == "3" else "", _e(of), _e(words))
                        for name, of, words, api in rows["fields"]),
            '<section id="cheat-recipes"><h2>Recipes</h2><p>A whole place, valid and walkable, whose sentences '
            'you then rewrite: <code>python3 tools/adventure_plugin.py add-place FOLDER --id KEY --name NAME '
            '--recipe RECIPE</code>.</p><div class="table-wrap"><table class="fields cheat"><thead><tr><th>Recipe'
            '</th><th>What it makes</th></tr></thead><tbody>\n%s\n</tbody></table></div></section>'
            % "\n".join("<tr><td data-label=\"Recipe\"><code>%s</code></td><td class=\"doc\" data-label=\"What it makes\">%s</td></tr>"
                        % (_e(name), _e(line)) for name, (_, line) in RECIPES.items()),
            '<section id="cheat-commands"><h2>Commands</h2><div class="table-wrap"><table class="fields cheat">'
            '<thead><tr><th>Command</th><th>For example</th></tr></thead><tbody>\n%s\n</tbody></table></div></section>'
            % "\n".join("<tr><td data-label=\"Command\"><code>%s</code></td><td data-label=\"For example\"><code class=\"ex\">python3 tools/adventure_plugin.py %s</code></td></tr>"
                        % (_e(name), _e(line)) for name, line in COMMAND_EXAMPLES)]
    pager = ('<footer class="pager"><a class="prev" href="sites.html"><span>Previous</span>Places: sites plugins'
             '</a><a class="next" href="reference.html"><span>Next</span>Reference</a></footer>')
    return ("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" "
            "content=\"width=device-width, initial-scale=1\">\n<title>Places cheat sheet · Adventure plugin guide</title>\n"
            "<link rel=\"stylesheet\" href=\"guide.css\">\n</head>\n<body>\n<!-- guide:masthead -->\n%s\n"
            "<!-- /guide:masthead -->\n<div class=\"layout\">\n<!-- guide:toc -->\n%s\n<!-- /guide:toc -->\n"
            "<main class=\"page\" id=\"top\">\n%s\n</main>\n</div>\n%s\n</body>\n</html>\n"
            % (masthead, toc, "\n".join(body), pager))


## Every command of a place's making, with one line that works (the guide's
## cheat sheet and the tests run on this list).
COMMAND_EXAMPLES = [
    ("new", "new My_Places --id my_places --name \"My Places\" --kind sites"),
    ("add-place", "add-place My_Places --id den --name \"The Gambler's Den\" --recipe gambler"),
    ("add-place", "add-place My_Places --list-recipes"),
    ("add-place", "add-place My_Places --id ring --name \"The Ring\" --recipe duelist --set \"foe=Big Olaf\" --set deck=green --set wager=75"),
    ("add-place", "add-place My_Places --id well --name \"The Old Well\" --service effects --free --where mainland,islands"),
    ("add-pane", "add-pane My_Places --place well --id depths --line \"Far below, something glitters.\""),
    ("add-action", "add-action My_Places --place well --id look --do talk --to depths --label \"Look down the well\""),
    ("add-flag", "add-flag My_Places wished"),
    ("add-counter", "add-counter My_Places coins"),
    ("add-action", "add-action My_Places --place well --id wish --prices 5,5,5 --effect counter=coins+1 --effect food=2 "
                   "--label \"Throw in {price} gold ({uses_left} left)\" --result \"You have thrown {count} coins.\""),
    ("add-foe", "add-foe My_Places --id guard --name \"The Well Guard\" --life 12 --deck deck.txt"),
    ("add-action", "add-action My_Places --place well --id duel --do duel --foe guard --prices 30 --win-effect gold=80 "
                   "--win \"The guard pays up.\" --lose \"The guard keeps your gold.\""),
    ("add-dungeon", "add-dungeon My_Places --id cistern --name \"The Dry Cistern\" --cards \"Sol Ring\" --place well --price 400"),
    ("set-text", "set-text My_Places well.intro \"A well older than the road. Its rope is new.\""),
    ("remove-place", "remove-place My_Places --id shrine"),
    ("set-info", "set-info My_Places --description \"A well, a den and a ring by the road.\" --license \"CC BY 4.0\" --version 1.0.0"),
    ("wizard", "wizard My_Places --answers answers.txt"),
    ("preview", "preview My_Places"),
    ("walk", "walk My_Places"),
    ("walk", "walk My_Places --site well --press wish,wish,look --gold 50"),
    ("walk", "walk My_Places --site den --roll 3"),
    ("walk", "walk My_Places --site well --both --lose"),
    ("art", "art My_Places"),
    ("validate", "validate My_Places"),
    ("info", "info My_Places"),
    ("export", "export My_Places --out dist"),
    ("compat", "compat dist/My_Places.zip My_Places"),
    ("guide", "guide --check"),
]
## The 1997 pane's picture frame, and a tile's width in world pixels.
PANE_WIDTH, PANE_HEIGHT, TILE_WIDTH = 512, 280, 128
## The most pixels art decodes (a bigger PNG is measured by its header alone).
ART_MOST_PIXELS = 4096 * 4096


def png_alpha(data: bytes):
    """A PNG's alpha, row by row, decoded with zlib and the five filters:
    (width, height, rows) with rows a list of bytes (one alpha a pixel), rows
    None for a PNG with no alpha at all; or a string saying why it was not
    checked (interlaced, 16-bit, a bit depth under 8, damaged)."""
    if picture_kind(data) != "png" or len(data) < 33 or data[12:16] != b"IHDR":
        return "not a PNG"
    width, height, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", data[16:29])
    if interlace:
        return "an interlaced PNG"
    if depth != 8:
        return "a %d-bit PNG" % depth
    if color not in (0, 2, 3, 4, 6) or width * height > ART_MOST_PIXELS or width == 0 or height == 0:
        return "a PNG of a kind not read here"
    packed, table, at = [], None, 8
    while at + 8 <= len(data):
        size = _be32(data, at)
        kind = data[at + 4:at + 8]
        body = data[at + 8:at + 8 + size]
        if kind == b"IDAT":
            packed.append(body)
        elif kind == b"tRNS":
            table = body
        elif kind == b"IEND":
            break
        at += 12 + size
    if color in (0, 2):
        return "a PNG with one transparent color" if table is not None else (width, height, None)
    if color == 3 and table is None:
        return width, height, None
    bpp = {3: 1, 4: 2, 6: 4}[color]
    stride = width * bpp
    # Inflated no further than the header's own size: a small file that
    # would unpack to gigabytes is never unpacked past its picture.
    needed = (stride + 1) * height
    try:
        raw = zlib.decompressobj().decompress(b"".join(packed), needed)
    except zlib.error:
        return "a damaged PNG"
    if len(raw) < needed:
        return "a damaged PNG"
    lookup = (table + b"\xff" * 256)[:256] if color == 3 else None
    rows, prev = [], bytes(stride)
    for y in range(height):
        start = y * (stride + 1)
        kind, line = raw[start], bytearray(raw[start + 1:start + 1 + stride])
        if kind == 1:
            for i in range(bpp, stride):
                line[i] = (line[i] + line[i - bpp]) & 255
        elif kind == 2:
            line = bytearray((a + b) & 255 for a, b in zip(line, prev))
        elif kind == 3:
            for i in range(stride):
                line[i] = (line[i] + (((line[i - bpp] if i >= bpp else 0) + prev[i]) >> 1)) & 255
        elif kind == 4:
            for i in range(stride):
                a = line[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                line[i] = (line[i] + (a if pa <= pb and pa <= pc else b if pb <= pc else c)) & 255
        elif kind != 0:
            return "a damaged PNG"
        prev = bytes(line)
        rows.append(prev.translate(lookup) if lookup else prev[bpp - 1::bpp])
    return width, height, rows


def pane_picture_advice(rel: str, data: bytes) -> dict:
    """A pane picture's size and shape against the pane's 512 x 280 frame."""
    width, height = picture_size(data)
    out = {"file": rel, "width": width, "height": height, "aspect": round(width / height, 2) if height else 0,
           "warnings": []}
    wanted = PANE_WIDTH / PANE_HEIGHT
    if height and abs(width / height - wanted) / wanted > 0.10:
        out["warnings"].append("its shape is %.2f : 1; the pane's frame is %d x %d, about %.2f : 1, and the picture "
                               "is cropped to fill it (the %s are cut)." % (
                                   width / height, PANE_WIDTH, PANE_HEIGHT, wanted,
                                   "sides" if width / height > wanted else "top and bottom"))
    if width < PANE_WIDTH:
        out["warnings"].append("it is %d pixels wide; under %d it is stretched and looks soft (768 x 420 or more "
                               "stays sharp in the largest pane)." % (width, PANE_WIDTH))
    return out


def sprite_advice(rel: str, data: bytes, drawn: float) -> dict:
    """A map sprite as the game draws it: its alpha, the rectangle used once
    its transparent margins are trimmed, its scale at [drawn] world pixels,
    and where its foot stands."""
    width, height = picture_size(data)
    out = {"file": rel, "width": width, "height": height, "drawn_width": _plain(float(drawn)), "checked": True,
           "warnings": [], "notes": []}
    if drawn > TILE_WIDTH:
        out["warnings"].append("it is drawn %s world pixels wide; a tile is %d x %d, so it overlaps the tiles "
                               "beside it: right for a landmark, crowded for a small place."
                               % (fmt_num(drawn), TILE_WIDTH, TILE_WIDTH // 2))
    decoded = png_alpha(data) if picture_kind(data) == "png" else "a %s picture" % picture_kind(data).upper()
    if isinstance(decoded, str):
        out["checked"] = False
        out["notes"].append("its transparency was not checked (%s)." % decoded)
        if picture_kind(data) == "jpg":
            out["warnings"].append("a JPEG has no transparency: the sprite is drawn as a block. Use a PNG or WebP.")
        return out
    _, _, rows = decoded
    if rows is None:
        out.update(transparent=0.0, used=[0, 0, width, height])
        out["warnings"].append("it has no transparency: its background is drawn as a block on the map. Save it "
                               "as a PNG with a transparent background.")
        rows = [b"\xff" * width] * height
    else:
        clear = sum(row.count(0) for row in rows)
        out["transparent"] = round(clear / float(width * height), 3)
        if clear == 0:
            out["warnings"].append("no pixel is transparent: its background is drawn as a block on the map.")
    spans = [(y, len(row) - len(row.lstrip(b"\x00")), len(row.rstrip(b"\x00"))) for y, row in enumerate(rows)
             if row.strip(b"\x00")]
    if not spans:
        out["warnings"].append("every pixel is transparent: nothing is drawn.")
        return out
    left, right = min(s[1] for s in spans), max(s[2] for s in spans)
    top, bottom = spans[0][0], spans[-1][0] + 1
    used_w, used_h = right - left, bottom - top
    out["used"] = [left, top, used_w, used_h]
    scale = used_w / float(drawn)
    out["scale"] = round(scale, 3)
    out["drawn_height"] = round(drawn * used_h / float(used_w), 1)
    whole = round(scale)
    grown = round(1.0 / scale)
    if scale < 1 and abs(1.0 / scale - grown) < 0.02:
        out["notes"].append("each source pixel is drawn %d world pixels wide: a whole number, so pixel art stays "
                            "crisp." % grown)
    elif whole >= 1 and abs(scale - whole) < 0.02:
        out["notes"].append("%d source pixel%s to a world pixel: a whole number, so pixel art stays crisp." % (
            whole, "" if whole == 1 else "s"))
    else:
        near = sorted({max(1, int(scale)), int(scale) + 1})
        out["notes"].append("%.2f source pixels to a world pixel; a whole number keeps pixel art crisp (width %s)."
                            % (scale, " or ".join(fmt_num(round(used_w / float(n), 1)) for n in reversed(near))))
    # The foot: the solid pixels of the lowest rows, against the middle of
    # the trimmed picture's bottom edge (which stands on the tile).
    depth = max(1, min(8, used_h // 25))
    solid = [x for row in rows[bottom - depth:bottom] for x in range(left, right) if row[x] >= 128]
    if solid:
        foot = (min(solid) + max(solid) + 1) / 2.0
        off = foot - (left + used_w / 2.0)
        out["foot_offset"] = round(off / scale, 1)
        if abs(off) > 0.10 * used_w:
            out["warnings"].append("its foot stands %s world pixels to the %s of the middle of its bottom edge, the "
                                   "point that stands on the tile: the building will look off its tile." % (
                                       fmt_num(round(abs(off) / scale, 1)), "right" if off > 0 else "left"))
    return out


def art_report(result: dict) -> list:
    """The pictures of a valid plugin, place by place: [{place, name,
    picture, sprite}] — a sites plugin's places, an island's two markers."""
    data, files = result["data"], result["files"]
    if data.get("kind") == KIND_SITES:
        pictures = data["sites"]["pictures"]
        places = [(key, site) for key, site in data["sites"]["sites"].items()]
    else:
        pictures = data["places"]["pictures"]
        places = [(kind, data["places"]["markers"][kind]) for kind in MARKERS]
    out = []
    for key, place in places:
        row = {"place": key, "name": str(place["name"]), "picture": None, "sprite": None}
        picture = str(place["picture"])
        if picture in pictures:
            row["picture"] = dict(pane_picture_advice(str(pictures[picture]), files[str(pictures[picture])]), key=picture)
        else:
            row["picture"] = {"key": picture, "skin": True, "warnings": []}
        sprite = place.get("sprite")
        if isinstance(sprite, dict):
            row["sprite"] = sprite_advice(str(sprite["file"]), files[str(sprite["file"])], float(sprite["width"]))
        out.append(row)
    return out


def command_art(args, game: Game) -> int:
    result = judge(_existing(args.plugin), game)
    rows = art_report(result) if result["valid"] else []
    warnings = sum(len(part["warnings"]) for row in rows for part in (row["picture"], row["sprite"]) if part)
    if args.json:
        print(json.dumps(dict(report(result), art=rows, warnings=warnings), ensure_ascii=False, indent="\t"))
        return 0 if result["valid"] else 1
    if not result["valid"]:
        for problem in result["problems"]:
            print(problem)
        print("%s: refused at the %s stage; art looks at a valid plugin's pictures." % (args.plugin, result["stage"]),
              file=sys.stderr)
        return 1
    for row in rows:
        print("%s (%s)" % (row["name"], row["place"]))
        picture = row["picture"]
        if picture.get("skin"):
            print("  pane picture  %s, a skin picture: each player's own skin draws it." % picture["key"])
        else:
            print("  pane picture  %s: %d x %d, %.2f : 1 (the pane's frame is %d x %d, %.2f : 1)" % (
                picture["file"], picture["width"], picture["height"], picture["aspect"], PANE_WIDTH, PANE_HEIGHT,
                PANE_WIDTH / PANE_HEIGHT))
        for warning in picture["warnings"]:
            print("    advice: " + warning)
        sprite = row["sprite"]
        if sprite is None:
            print("  map sprite    none: the place has no picture on the map.")
            continue
        print("  map sprite    %s: %d x %d, drawn %s world pixels wide (a tile is %d x %d)" % (
            sprite["file"], sprite["width"], sprite["height"], fmt_num(sprite["drawn_width"]), TILE_WIDTH,
            TILE_WIDTH // 2))
        if "used" in sprite and "scale" in sprite:
            print("    trimmed to %d x %d at %d, %d (%d%% of the picture transparent); drawn %s x %s; its foot %s" % (
                sprite["used"][2], sprite["used"][3], sprite["used"][0], sprite["used"][1],
                round(100 * sprite.get("transparent", 0.0)), fmt_num(sprite["drawn_width"]),
                fmt_num(sprite["drawn_height"]),
                "in the middle" if abs(sprite.get("foot_offset", 0.0)) < 0.05 else "%s world pixel%s %s of the middle" % (
                    fmt_num(abs(sprite["foot_offset"])), "" if abs(sprite["foot_offset"]) == 1 else "s",
                    "right" if sprite["foot_offset"] > 0 else "left")))
        for note in sprite["notes"]:
            print("    " + note)
        for warning in sprite["warnings"]:
            print("    advice: " + warning)
    print("%d piece%s of advice. Advice only: art never refuses a plugin (validate does that)." % (
        warnings, "" if warnings == 1 else "s"))
    return 0


# --------------------------------------------------------------------------
# the command line
# --------------------------------------------------------------------------

# --------------------------------------------------------------------------
# preview — a sites plugin's places as one page to look at: every pane as
# the game lays it out, every button with what it does in plain words
# --------------------------------------------------------------------------

## A picture up to this size is put into the page itself; a bigger one is
## named by its path beside the page (a folder) or left as a frame (a zip).
PREVIEW_EMBED = 400 * 1024
## The hero a preview fills the words with.
PREVIEW_HERO = {"gold": 1000, "food": 10, "amulets": {"red": 1, "white": 1}, "day": 12}
PREVIEW_CSS = """
:root { --bg: #1b1712; --panel: #262018; --ink: #efe6d2; --muted: #b3a68b; --line: #4a3f2e; --gold: #e0b45c;
  --accent: #7fc3d4; --ok: #9fcf8a; --warn: #e79a7a; --font: Georgia, "Iowan Old Style", "Times New Roman", serif;
  --mono: ui-monospace, "SF Mono", Menlo, Consolas, monospace; }
* { box-sizing: border-box; }
body { margin: 0; background: var(--bg); color: var(--ink); font: 16px/1.5 var(--font); }
main { max-width: 60rem; margin: 0 auto; padding: 1.5rem 1rem 4rem; }
h1 { font-size: 1.9rem; margin: 0 0 0.2rem; color: var(--gold); }
h2 { font-size: 1.45rem; margin: 2.6rem 0 0.4rem; padding-top: 1rem; border-top: 1px solid var(--line); color: var(--gold); }
h3 { font-size: 1.05rem; margin: 1.6rem 0 0.5rem; color: var(--accent); font-family: var(--mono); font-weight: 600; }
p { margin: 0.4rem 0; }
code { font: 0.88em var(--mono); background: #322a1f; border-radius: 4px; padding: 0.05em 0.3em; }
.lede, .note { color: var(--muted); }
.cap { display: block; font: 0.78rem/1.4 var(--mono); color: var(--muted); margin: 0.1rem 0 0.25rem; }
.cap b { color: var(--accent); font-weight: 600; }
.pane { background: var(--panel); border: 1px solid var(--line); border-radius: 10px; max-width: 34rem; overflow: hidden; }
.pane .frame { aspect-ratio: 512 / 280; background: #120f0b; display: flex; align-items: center; justify-content: center;
  color: var(--muted); font: 0.85rem var(--mono); text-align: center; }
.pane .frame img { width: 100%; height: 100%; object-fit: cover; display: block; image-rendering: pixelated; }
.pane .head { padding: 0.7rem 1rem 0; }
.pane .title { font-size: 1.25rem; color: var(--gold); margin: 0; }
.pane .subtitle { color: var(--muted); margin: 0; font-style: italic; }
.pane .lines { padding: 0.5rem 1rem 0.2rem; }
.pane .lines p { margin: 0.45rem 0; }
.pane ul.turns { margin: 0.2rem 0 0.5rem 1.2rem; padding: 0; }
.buttons { padding: 0.4rem 1rem 1rem; display: grid; gap: 0.7rem; }
.button .face { display: inline-block; border: 1px solid var(--gold); color: var(--gold); border-radius: 6px;
  padding: 0.3rem 0.8rem; background: #2f271b; }
.button .does { display: block; font-size: 0.92rem; color: var(--ink); margin-top: 0.25rem; }
.button .says { display: block; font-size: 0.92rem; color: var(--muted); margin-top: 0.15rem; }
table { border-collapse: collapse; margin: 0.5rem 0; }
td, th { border: 1px solid var(--line); padding: 0.3rem 0.6rem; text-align: left; vertical-align: top; }
th { color: var(--muted); font-weight: 600; }
.warn { color: var(--warn); }
@media (max-width: 560px) { main { padding: 1rem 0.6rem 3rem; } }
"""


def _join_words(parts: list, last: str = "and") -> str:
    parts = [part for part in parts if part]
    if len(parts) <= 1:
        return "".join(parts)
    return "%s %s %s" % (", ".join(parts[:-1]), last, parts[-1])


def _between_words(value: dict, low_default: int, what: str) -> str:
    low, high = int(value.get("min", low_default)), int(value.get("max", MOST_USES))
    if high >= MOST_USES:
        return "%s %d or more" % (what, low) if low > 0 else "%s anything" % what
    return "%s %d" % (what, low) if low == high else "%s %d to %d" % (what, low, high)


def condition_words(condition: dict) -> str:
    """A condition in plain words: "flag told", "gold ≥ 500"."""
    name = next(iter(condition))
    value = condition[name]
    if name == "flag":
        return "flag %s" % value
    if name == "not_flag":
        return "not flag %s" % value
    if name == "gold_at_least":
        return "gold ≥ %d" % int(value)
    if name == "gold_below":
        return "gold < %d" % int(value)
    if name == "food_at_least":
        return "food ≥ %d" % int(value)
    if name == "day_at_least":
        return "day ≥ %d" % int(value)
    if name == "wizards_defeated":
        return "wizards defeated ≥ %d" % int(value)
    if name == "on_mainland":
        return "on the mainland" if value else "on an island"
    if name == "at_peace":
        return "at peace" if value else "not yet at peace"
    if name == "gift_waiting":
        return "a gift waits for the next duel" if value else "no gift waits for the next duel"
    if name == "used":
        return _between_words(value, 0, "%s done" % value["action"])
    if name == "used_up":
        return "%s used up" % value
    if name == "dungeon":
        return "dungeon %s %s" % (value["dungeon"], "not raised" if value["state"] == "none" else value["state"])
    if name == "has_card":
        return "holds %s%s" % ("%d × " % int(value["min"]) if int(value.get("min", 1)) > 1 else "", value["card"])
    if name == "amulets":
        color = str(value.get("color", "any"))
        return "amulets%s ≥ %d" % ("" if color == "any" else " (%s)" % color, int(value.get("min", 1)))
    if name == "hero_color":
        return "the hero is %s" % value
    if name == "owns_magic":
        return "owns %s" % value
    if name == "difficulty":
        return "difficulty %d to %d" % (int(value.get("min", 0)), int(value.get("max", 3)))
    if name == "plugin_on":
        return "plugin %s is on" % value
    if name == "counter":
        return _between_words(value, 0, "counter %s is" % value["name"])
    if name == "site_used":
        return _between_words(value, 1, "%s.%s done" % (value["site"], value["action"]))
    if name == "life_bonus_below":
        return "life bonus < %d" % int(value)
    if name == "town_linked":
        return "the nearest town is mana-linked" if value else "the nearest town is not mana-linked"
    if name == "any":
        return "one of (%s)" % "; ".join(condition_words(inner) for inner in value)
    return "%s %s" % (name, json.dumps(value, ensure_ascii=False))


def when_words(conditions: list) -> str:
    return ", ".join(condition_words(condition) for condition in conditions)


def _gold_words(amount: int) -> str:
    return "%s%d gold" % ("+" if amount >= 0 else "−", abs(amount))


def effect_words(effect: dict, file: dict, say) -> str:
    """An effect in plain words; [say] gives a text key's words."""
    name = next(iter(effect))
    value = effect[name]
    if name == "gold":
        return _gold_words(int(value))
    if name == "food":
        return "%s%d food" % ("+" if int(value) >= 0 else "−", abs(int(value)))
    if name == "set_flag":
        return "sets flag %s" % value
    if name == "clear_flag":
        return "clears flag %s" % value
    if name == "counter":
        if "set" in value:
            return "counter %s = %d" % (value["name"], int(value["set"]))
        return "counter %s %s%d" % (value["name"], "+" if int(value.get("add", 0)) >= 0 else "−", abs(int(value.get("add", 0))))
    if name == "amulet":
        count = int(value.get("count", 1))
        return "%s%d %s amulet%s" % ("+" if count >= 0 else "−", abs(count), value["color"], "" if abs(count) == 1 else "s")
    if name == "give_card":
        return "gives the card %s" % value
    if name == "next_duel":
        return "for the next duel: %s" % ("%d more life" % int(value["life"]) if "life" in value else
                                         "the first move" if value.get("first_move") else "%s in play" % value.get("card", ""))
    if name == "spawn_dungeon":
        return "raises the dungeon %s" % file["dungeons"].get(value, {}).get("name", value)
    if name == "reveal_map":
        around = str(value.get("around", "place"))
        return "uncovers the map %d tiles around %s" % (int(value.get("radius", 4)), "the place" if around == "place" else
                                                       file["dungeons"].get(around.partition(":")[2], {}).get("name", around))
    if name == "log_clue":
        return "a clue in the journal (“%s”)" % say(value["text"])
    if name == "log_event":
        return "a line in the journal (“%s”)" % say(value["text"])
    if name == "teleport":
        to = str(value.get("to", "")) if isinstance(value, dict) else str(value)
        kind, _, key = to.partition(":")
        return "carries the hero to %s" % ("the nearest town" if to == "nearest_town" else "where the journey began" if to == "start"
                                           else file["sites"].get(key, {}).get("name", key) if kind == "place"
                                           else file["dungeons"].get(key, {}).get("name", key))
    if name == "world_magic":
        return "teaches the World Magic %s" % value
    if name == "mana_link":
        return "links the nearest town's mana to the hero"
    if name == "life_bonus":
        return "+%d life in every duel from now on" % int(value)
    if name == "roll":
        outcomes = value.get("outcomes", [])
        total = sum(max(1, int(o.get("weight", 1))) for o in outcomes)
        return "rolls: " + ", ".join("%d in %d %s" % (max(1, int(o.get("weight", 1))), total,
                                                      effects_words(o.get("effects", []), file, say) or "nothing")
                                     for o in outcomes)
    return "%s %s" % (name, json.dumps(value, ensure_ascii=False))


def effects_words(effects: list, file: dict, say) -> str:
    return ", ".join(effect_words(effect, file, say) for effect in effects)


def action_words(action: dict, file: dict, say) -> str:
    """What a button does, in one plain sentence."""
    do = str(action["do"])
    if do == "leave":
        return "closes the pane"
    parts = []
    prices = [int(p) for p in action.get("prices", [])]
    if prices:
        ladder = ("%d gold" % prices[0] if len(set(prices)) == 1 else "%s gold in turn" % ", ".join(str(p) for p in prices)) \
            if any(prices) else "nothing"
        parts.append("%s %s, %s" % ("stakes" if do == "duel" else "pays", ladder,
                                    "once" if len(prices) == 1 else "%d times in all" % len(prices)))
    elif do not in ("buy_card", "sell_card"):
        parts.append("free, any number of times")
    needs = []
    for need in action.get("needs", []):
        if "card" in need:
            needs.append("the card %s" % need["card"])
        elif "amulets" in need:
            count, color = int(need["amulets"].get("count", 1)), str(need["amulets"].get("color", "any"))
            needs.append("%d %samulet%s" % (count, "" if color == "any" else color + " ", "" if count == 1 else "s"))
        elif "food" in need:
            needs.append("%d food" % int(need["food"]))
    if needs:
        parts.append("takes " + _join_words(needs))
    if do == "copy_card":
        parts.append("copies a card the hero picks")
    elif do in ("buy_card", "sell_card"):
        cards = ", ".join("%s for %d gold" % (card, int(price)) for card, price in action.get("cards", {}).items())
        parts.append("%s: %s%s" % ("sells the hero a card" if do == "buy_card" else "buys a card the hero holds", cards,
                                   "; %d of each" % int(action["stock"]) if "stock" in action else ""))
    elif do == "duel":
        foe = file.get("foes", {}).get(str(action.get("foe", "")), {})
        parts.append("duel %s (%d life)" % (foe.get("name", action.get("foe", "")), int(foe.get("life", 20))))
        for side in ("win", "lose"):
            parts.append("%s: %s" % (side, effects_words(action.get(side, {}).get("effects", []), file, say) or "nothing"))
        if str(action.get("count", "press")) == "win":
            parts.append("counted when won")
    else:
        done = effects_words(action.get("effects", []), file, say)
        if done:
            parts.append(done)
        if do == "talk":
            parts.append("opens the pane %s" % action.get("to", ""))
    return "; ".join(parts)


def preview_html(result: dict, only: str = "", page_dir: Path | None = None) -> str:
    """The preview page of the valid sites plugin [result] (a judgement):
    one self-contained HTML document, the same bytes for the same plugin.
    Every word of the plugin is escaped: a plugin's text is never markup."""
    data, files, manifest = result["data"], result["files"], result["manifest"]
    file = data["sites"]
    hero = walk_hero(data, PREVIEW_HERO["gold"], {"food": PREVIEW_HERO["food"], "amulets": PREVIEW_HERO["amulets"],
                                                 "day": PREVIEW_HERO["day"]})
    e = lambda value: html.escape(str(value), quote=True)

    def say(key) -> str:
        return hero.say(str(key))

    def cap(label: str, words: str) -> str:
        return '<span class="cap"><b>%s</b> %s</span>' % (e(label), e(words)) if words else ""

    def picture(key: str) -> str:
        rel = file["pictures"].get(key)
        if rel is None:
            return '<div class="frame">the player’s skin draws %s</div>' % e(key)
        blob = files.get(rel, b"")
        kind = picture_kind(blob)
        if kind and len(blob) <= PREVIEW_EMBED:
            import base64
            mime = {"png": "image/png", "jpg": "image/jpeg", "webp": "image/webp"}.get(kind, "image/" + kind)
            return '<div class="frame"><img alt="%s" src="data:%s;base64,%s"></div>' % (
                e(rel), mime, base64.b64encode(blob).decode("ascii"))
        if result["kind"] == "folder" and page_dir is not None:
            link = os.path.relpath(Path(result["path"]).resolve() / rel, page_dir.resolve()).replace(os.sep, "/")
            from urllib.parse import quote
            return '<div class="frame"><img alt="%s" src="%s"></div>' % (e(rel), e(quote(link)))
        return '<div class="frame">%s (%s; too big to put into this page)</div>' % (e(rel), e(_bytes_text(len(blob))))

    def lines_html(site: str, lines: list, filled: dict) -> str:
        out = []
        for line in lines:
            if isinstance(line, str):
                out.append("<p>%s</p>" % e(hero.say(line, filled)))
                continue
            own = filled
            asked = SiteWalk.named_condition(line.get("when", []), "counter")
            if isinstance(asked, dict):
                own = dict(filled, count=hero.counter(str(asked["name"])))
            when = cap("shown when:", when_words(line.get("when", [])))
            if "one_of" in line:
                out.append('%s<span class="cap"><b>one of these, in turn</b> %s</span><ul class="turns">%s</ul>' % (
                    when, e("the next one each day" if str(line.get("by", "day")) == "day"
                            else "the next one each time a button of the place is used"),
                    "".join("<li>%s</li>" % e(hero.say(str(key), own)) for key in line["one_of"])))
            else:
                out.append("%s<p>%s</p>" % (when, e(hero.say(str(line["text"]), own))))
        return "".join(out)

    body = ["<h1>%s</h1>" % e(manifest.get("name", data["id"])),
            '<p class="lede">%s</p>' % e(manifest.get("description", "")),
            '<p class="note">A preview written by <code>%s preview</code>: every pane of every place, as the game lays '
            'it out. The words are filled for a hero named %s who carries %d gold, %d food and %d amulets on day %d, '
            'with every counter at 0; a price shown is the first of its list. Plugin <code>%s</code> %s, plugin API %d.</p>'
            % (e(TOOL), e(WALK_HERO), PREVIEW_HERO["gold"], PREVIEW_HERO["food"], sum(PREVIEW_HERO["amulets"].values()),
               PREVIEW_HERO["day"], e(data["id"]), e(manifest.get("version", "")), int(manifest.get("api_version", 1)))]
    for key, site in file["sites"].items():
        if only and key != only:
            continue
        body.append('<section class="place" id="place-%s"><h2>%s</h2>' % (e(key), e(site["name"])))
        body.append('<p class="note">Place <code>%s</code>, on %s; it keeps %d tiles from towns, dungeons and other '
                    'places.</p>' % (e(key), e(_join_words(["the mainland" if land == "mainland" else "every island"
                                                           for land in site["where"]])), int(site["gap"])))
        plain = [pane for pane in site["panes"] if "id" not in pane]
        for p, pane in enumerate(site["panes"]):
            if "id" in pane:
                opened = [str(a["id"]) for a in _site_actions(site).values() if a.get("to") == pane["id"]]
                how = "opened by the button%s %s" % ("" if len(opened) == 1 else "s", _join_words(opened)) if opened \
                    else "no button opens it"
                if pane.get("when"):
                    how += ", while: " + when_words(pane["when"])
            elif pane.get("when"):
                how = "shown when: " + when_words(pane["when"])
            else:
                how = "shown otherwise" if len(plain) > 1 else "always shown"
            filled = hero.values(key, None, None, pane)
            body.append('<h3 id="pane-%s-%d">pane %d%s</h3>' % (e(key), p, p, " · id %s" % e(pane["id"]) if "id" in pane else ""))
            body.append('<span class="cap">%s</span>' % e(how))
            body.append('<div class="pane">%s<div class="head"><p class="title">%s</p><p class="subtitle">%s</p></div>'
                        % (picture(str(pane.get("picture", site["picture"]))),
                           e(hero.say(str(pane["title"]), filled) if "title" in pane else site["name"]),
                           e(hero.say(str(pane["subtitle"]), filled) if "subtitle" in pane
                             else manifest.get("name", data["id"]))))
            body.append('<div class="lines">%s</div><div class="buttons">' % lines_html(key, pane["lines"], filled))
            for action in pane["actions"]:
                words = hero.values(key, action)
                label = hero.say(str(action.get("label", "site.leave")) if str(action["do"]) == "leave"
                                 else SiteWalk.label_key(action), words)
                body.append('<div class="button">%s<span class="face">%s</span><span class="does">%s</span>' % (
                    cap("shown when:", when_words(action["when"])), e(label), e(action_words(action, file, say))))
                after = dict(words, price=words.get("price", 0))
                for where, lines in action_line_lists(action, ""):
                    if not lines:
                        continue
                    tag = "win" if where.startswith(".win") else "lose" if where.startswith(".lose") else \
                        "outcome %d" % (int(re.findall(r"outcomes\[(\d+)\]", where)[-1]) + 1) if "outcomes[" in where else ""
                    body.append('<span class="says"><b>%s</b> %s</span>' % (
                        e("then says%s:" % (" (%s)" % tag if tag else "")),
                        " ".join(e(hero.say(line if isinstance(line, str) else str(line.get("text", (line.get("one_of") or [""])[0])),
                                            dict(after, card=after.get("card", "the card")))) for line in lines)))
                body.append("</div>")
            body.append("</div></div>")
        body.append("</section>")
    if not only:
        if file["dungeons"]:
            body.append('<section id="dungeons"><h2>Dungeons</h2><table><tr><th>Dungeon</th><th>Creatures</th><th>Rules</th>'
                        '<th>Treasure</th><th>From its place</th></tr>')
            for key, dungeon in file["dungeons"].items():
                body.append("<tr><td>%s <code>%s</code></td><td>%s, %s</td><td>%s</td><td>%s</td><td>%d to %d tiles</td></tr>" % (
                    e(dungeon["name"]), e(key), e(dungeon["color"]), e(dungeon["size"]), e(", ".join(dungeon["rules"]) or "none"),
                    e(", ".join(dungeon["cards"])), int(dungeon["distance"]["min"]), int(dungeon["distance"]["max"])))
            body.append("</table></section>")
        if file.get("foes"):
            body.append('<section id="foes"><h2>Opponents</h2><table><tr><th>Opponent</th><th>Life</th><th>Deck</th></tr>')
            for key, foe in file["foes"].items():
                body.append("<tr><td>%s <code>%s</code></td><td>%d</td><td>%s%d cards: %s</td></tr>" % (
                    e(foe["name"]), e(key), int(foe["life"]), e(foe["deck_name"] + ", ") if "deck_name" in foe else "",
                    sum(int(n) for n in foe["deck"].values()),
                    e(", ".join("%d %s" % (int(n), card) for card, n in foe["deck"].items()))))
            body.append("</table></section>")
        if file.get("tasks"):
            body.append('<section id="tasks"><h2>Tasks rows</h2><table><tr><th>Title</th><th>While open</th><th>Once done</th>'
                        '<th>Guides to</th><th>Listed when</th><th>Done when</th></tr>')
            for key, task in file["tasks"].items():
                at = str(task.get("at", ""))
                kind, _, name = at.partition(":")
                body.append("<tr><td>%s <code>%s</code></td><td>%s</td><td>%s</td><td>%s</td><td>%s</td><td>%s</td></tr>" % (
                    e(say(task["title"])), e(key), e(say(task["text"])), e(say(task.get("done", task["text"]))),
                    e(file["sites"].get(name, {}).get("name", name) if kind == "place" else
                      file["dungeons"].get(name, {}).get("name", name) if kind == "dungeon" else "nowhere"),
                    e(when_words(task.get("when", [])) or "always"), e(when_words(task.get("done_when", [])) or "never")))
            body.append("</table></section>")
        if file["flags"] or file.get("counters"):
            body.append('<section id="names"><h2>Flags and counters</h2><p>Flags: %s. Counters: %s.</p></section>' % (
                e(", ".join(file["flags"]) or "none"), e(", ".join(file.get("counters", [])) or "none")))
        if result.get("warnings"):
            body.append('<section id="warnings"><h2>Warnings</h2>%s</section>' % "".join(
                '<p class="warn">%s</p>' % e(warning) for warning in result["warnings"]))
    return ("<!DOCTYPE html>\n<html lang=\"en\">\n<head>\n<meta charset=\"utf-8\">\n<meta name=\"viewport\" "
            "content=\"width=device-width, initial-scale=1\">\n<title>%s · preview</title>\n<style>%s</style>\n</head>\n"
            "<body>\n<main>\n%s\n</main>\n</body>\n</html>\n"
            % (e(manifest.get("name", data["id"])), PREVIEW_CSS, "\n".join(body)))


def command_preview(args, game: Game) -> int:
    result = judge(_existing(args.plugin), game)
    if result["valid"] and manifest_kind(result["manifest"]) != KIND_SITES:
        raise UsageError("%s is an island plugin: preview shows a sites plugin's places." % args.plugin)
    if not result["valid"]:
        for problem in result["problems"]:
            print(problem)
        print("%s: refused at the %s stage; a preview needs a valid plugin." % (args.plugin, result["stage"]), file=sys.stderr)
        return 1
    if args.site and args.site not in result["data"]["sites"]["sites"]:
        raise UsageError("%s has no place %s (its places: %s)." % (args.plugin, args.site,
                                                                   ", ".join(result["data"]["sites"]["sites"])))
    out = Path(args.out if args.out else "preview")
    if out.exists() and not out.is_dir():
        raise UsageError("--out %s is not a folder." % out)
    source = Path(result["path"]).resolve()
    if result["kind"] == "folder" and (out.resolve() == source or source in out.resolve().parents):
        raise UsageError("--out must be outside the plugin folder: an .html file inside it would refuse the plugin.")
    out.mkdir(parents=True, exist_ok=True)
    target = out / ("%s%s.html" % (result["data"]["id"], "_" + args.site if args.site else ""))
    page = preview_html(result, args.site, out)
    _write_whole(target, page.encode("utf-8"))
    places = [args.site] if args.site else list(result["data"]["sites"]["sites"])
    print("Wrote %s (%s): %d place%s, %d pane%s. Open it in a browser; nothing in it asks the network for anything."
          % (target, _bytes_text(len(page.encode("utf-8"))), len(places), "" if len(places) == 1 else "s",
             sum(len(result["data"]["sites"]["sites"][key]["panes"]) for key in places),
             "" if sum(len(result["data"]["sites"]["sites"][key]["panes"]) for key in places) == 1 else "s"))
    if args.open:
        import webbrowser
        webbrowser.open(target.resolve().as_uri())
    return 0


# --------------------------------------------------------------------------
# wizard — a place made by answering questions
# --------------------------------------------------------------------------

class _Quit(Exception):
    """The wizard was left before it wrote anything."""


class _Asker:
    """The wizard's questions: read from a terminal, or from a file of
    answers (one a line; an empty line, or the file's end, takes the
    default). "q" leaves at any question."""

    def __init__(self, answers: list | None):
        self.answers = answers
        self.at = 0

    def read(self) -> str:
        if self.answers is None:
            try:
                return input("> ")
            except EOFError as error:
                raise _Quit() from error
        line = self.answers[self.at] if self.at < len(self.answers) else ""
        self.at += 1
        print("> " + line)
        return line

    def ask(self, question: str, default: str = "", choices: list | None = None, check=None) -> str:
        """[choices]: [(value, words)], answered by number or by value.
        [check]: a function that raises UsageError for a wrong answer."""
        for _ in range(100):
            print()
            print(question + (" [%s]" % default if default != "" and not choices else ""))
            for n, (value, words) in enumerate(choices or [], 1):
                print("  %2d. %-10s %s%s" % (n, value, words, "   (Enter)" if value == default else ""))
            answer = strip_edges(self.read())
            if answer.lower() in ("q", "quit"):
                raise _Quit()
            if answer == "":
                answer = default
            elif choices and is_valid_int(answer) and 1 <= int(answer) <= len(choices):
                answer = choices[int(answer) - 1][0]
            problem = ""
            if choices and answer not in [value for value, _ in choices]:
                problem = "Answer with a number from 1 to %d." % len(choices)
            elif check is not None:
                try:
                    check(answer)
                except UsageError as error:
                    problem = str(error)
            if not problem:
                return answer
            if self.answers is not None:
                raise UsageError("wizard: answer %d (%s) does not fit \"%s\": %s" % (self.at, answer, question, problem))
            print(problem)
        raise _Quit()


def _slug(name: str, most: int) -> str:
    out = re.sub(r"[^a-z0-9]+", "_", name.lower()).strip("_")
    out = re.sub(r"^(the|a|an)_", "", out)
    if not out or not out[0].isalpha():
        out = "p_" + out
    return out[:most].rstrip("_") or "place"


def _run_quiet(argv: list, game: Game) -> tuple:
    """A command of this tool run inside the tool: (exit code, what it printed)."""
    import contextlib
    args = parser().parse_args(argv)
    said, erred = io.StringIO(), io.StringIO()
    with contextlib.redirect_stdout(said), contextlib.redirect_stderr(erred):
        code = COMMANDS[args.command](args, game)
    return code, said.getvalue() + erred.getvalue()


def command_wizard(args, game: Game) -> int:
    answers = None
    if args.answers:
        try:
            answers = utf8_string(Path(args.answers).read_bytes()).lstrip("﻿").splitlines()
        except OSError as error:
            raise UsageError("--answers %s could not be read (%s)." % (args.answers, error)) from error
    elif not sys.stdin.isatty():
        raise UsageError("wizard asks its questions at a terminal, and this is none: run it in a terminal window, or "
                         "give it the answers with --answers FILE (one answer a line; an empty line takes the default).")
    game.schema()
    asker = _Asker(answers)
    folder = Path(args.folder) if args.folder else None
    adding = folder is not None and folder.is_dir() and any(folder.iterdir())
    try:
        print("A place for Shandalar, made by answering a few questions. Enter takes the answer in [brackets] or "
              "marked (Enter); q leaves, and nothing is written until the last question is answered.")
        if adding:
            _, manifest, sites, _ = _sites_folder(str(folder), game, "wizard")
            print("\nAdding a place to %s (plugin %s, its places: %s)." % (folder, manifest["id"], ", ".join(sites["sites"])))
            if len(sites["sites"]) >= 8:
                raise UsageError("%s already has eight places, the most a sites plugin holds." % folder)
            ident, taken = str(manifest["id"]), set(sites["sites"])
        else:
            def name_check(value: str) -> None:
                if not value or len(value) > MAX_NAME:
                    raise UsageError("A name is 1 to %d characters." % MAX_NAME)
            plugin_name = asker.ask("What is your plugin called? (its name in the game's plugin list)", "My Places", None, name_check)
            author = asker.ask("Who made it? (your name, as its author)", "Unnamed author", None, name_check)
            ident = _slug(plugin_name, 30)
            if not valid_id(ident):
                ident = "my_" + ident[:27]
            if folder is None:
                folder = Path(re.sub(r"[^A-Za-z0-9]+", "_", plugin_name).strip("_") or "My_Places")
            if folder.exists() and (not folder.is_dir() or any(folder.iterdir())):
                raise UsageError("%s already exists and is not a sites plugin folder; name another folder: wizard FOLDER." % folder)
            taken = set()

        def place_check(value: str) -> None:
            if not value or len(value) > 60:
                raise UsageError("A place's name is 1 to 60 characters.")
        place_name = asker.ask("What is the place called? (its name on the map)", "The Old Inn", None, place_check)
        key = _slug(place_name, max(1, min(24, 39 - len(ident))))
        stem, n = key, 1
        while key in taken:
            n += 1
            key = "%s%d" % (stem, n)
        recipe = asker.ask("What kind of place is it?", "lore", [(name, line) for name, (_, line) in RECIPES.items()])
        chosen = {}
        for name, kind, default, question in RECIPE_OPTIONS.get(recipe, []):
            shown = ",".join(str(v) for v in default) if isinstance(default, list) else str(default)
            choices = None
            if kind == "deck":
                choices = [(deck, "%d cards: %s" % (sum(cards.values()), ", ".join(list(cards)[1:4]) + ", ..."))
                           for deck, cards in STOCK_DECKS.items()]
            elif kind == "color":
                choices = [(color, "") for color in AMULET_COLORS]
            elif kind == "choice":
                choices = [(value, words) for value, words in RECIPE_CHOICES[name].items()]
            elif kind == "magic":
                choices = [(value, "") for value in game.schema()["types"]["sites_condition"]["options"]["owns_magic"]["values"]]

            def check(value: str, name=name, kind=kind) -> None:
                recipe_options(recipe, dict(chosen, **{name: value}))
                if kind == "card" and value and not game.card_known(value, []):
                    near = close_names(value, game.base or ())
                    raise UsageError("%s is not a card of the base game%s." % (value, "; did you mean %s?" % ", ".join(near) if near else ""))
            chosen[name] = asker.ask(question + ("" if choices else "."), shown, choices, check)
        where = asker.ask("Where does it stand?", "mainland", [("mainland", "once, on Shandalar's mainland"),
                                                              ("islands", "once on every island plugin's island"),
                                                              ("both", "on the mainland and on every island")])
        go = asker.ask("Write it now?", "yes", [("yes", "write the %s" % ("place into %s" % folder if adding else "plugin into %s" % folder)),
                                               ("no", "leave, and write nothing")])
        if go != "yes":
            raise _Quit()
    except (_Quit, KeyboardInterrupt):
        print("\nLeft the wizard; nothing was written.")
        return 1
    place_args = ["add-place", "FOLDER", "--id", key, "--name", place_name, "--recipe", recipe,
                  "--where", "mainland,islands" if where == "both" else where]
    for name, value in chosen.items():
        default = next(d for n, _, d, _ in RECIPE_OPTIONS[recipe] if n == name)
        if str(value) != (",".join(str(v) for v in default) if isinstance(default, list) else str(default)):
            place_args += ["--set", "%s=%s" % (name, value)]
    steps = [place_args] if adding else [["new", "FOLDER", "--id", ident, "--name", plugin_name, "--author", author, "--kind", "sites"],
                                         place_args, ["remove-place", "FOLDER", "--id", "shrine"]]
    # ALL OR NOTHING: a new plugin is built in a folder of its own beside
    # the one asked for and moved there whole; a place added to a plugin is
    # one add-place, which puts every file back when it is refused.
    target = folder
    work = target if adding else Path(tempfile.mkdtemp(prefix="." + target.name + ".", suffix=".part",
                                                       dir=str(target.resolve().parent)))
    build = work if adding else work / target.name
    try:
        for step in steps:
            code, said = _run_quiet([str(build) if part == "FOLDER" else part for part in step], game)
            if code != 0:
                print(said.strip())
                print("\nThe wizard could not write the %s; nothing was written." % ("place" if adding else "plugin"), file=sys.stderr)
                return 1
        if not adding:
            if target.exists():
                target.rmdir()
            os.replace(build, target)
    except KeyboardInterrupt:
        print("\nLeft the wizard; nothing was written.")
        return 1
    finally:
        if not adding:
            shutil.rmtree(work, ignore_errors=True)
    result = judge(str(target), game)
    quoted = _quoted(target)
    print("\nDone: %s %s. The place %s (%s) is the recipe %s, on %s." % (
        "added to" if adding else "wrote", target, key, place_name, recipe,
        "the mainland and every island" if where == "both" else "the mainland" if where == "mainland" else "every island"))
    print("The same, as commands:")
    for step in steps:
        print("    python3 tools/%s %s" % (TOOL, " ".join(quoted if part == "FOLDER" else _quoted(part) for part in step)))
    print("\nChecked as the game checks it: %s%s." % (
        "valid" if result["valid"] else "REFUSED: " + (result["problems"] or ["?"])[0],
        ", with %d warning%s (its stand-in pictures and words to make your own; validate lists them)"
        % (len(result["warnings"]), "" if len(result["warnings"]) == 1 else "s") if result.get("warnings") else ""))
    if result["valid"]:
        run = walk_site(result["data"], key, 100000, "island" if where == "islands" else "mainland")
        missed = never_reached(result["data"], key, [run])
        presses = [step for step in run["steps"] if step["kind"] == "press"]
        print("Walked without the game: %d pane%s shown, %d button%s pressed%s." % (
            len(run["seen"]["panes"]), "" if len(run["seen"]["panes"]) == 1 else "s", len(presses),
            "" if len(presses) == 1 else "s",
            "; %d thing%s not reached by a plain hero (walk says how)" % (len(missed), "" if len(missed) == 1 else "s")
            if missed else "; everything reached"))
    print("\nNext:\n"
          "    python3 tools/%s preview %s            see every pane as a page (open preview/%s.html)\n"
          "    python3 tools/%s walk %s --site %s     play it as text\n"
          "    python3 tools/%s set-text %s %s.intro \"Your own words.\"\n"
          "    python3 tools/%s art %s                advice for your own pictures in %s/art/\n"
          "    python3 tools/%s set-info %s --description \"...\" --license \"...\"\n"
          "    python3 tools/%s export %s --out dist  pack it; put the zip into the game's expanded_adventure folder\n"
          "    python3 tools/%s wizard %s             add another place"
          % (TOOL, quoted, ident, TOOL, quoted, key, TOOL, quoted, key, TOOL, quoted, quoted, TOOL, quoted, TOOL, quoted,
             TOOL, quoted))
    return 0 if result["valid"] else 1
def version_line(game: Game) -> str:
    return "%s — Shandalar %s (adventure plugin API %d)" % (TOOL, game.version or "version unknown", API_VERSION)


class _Parser(argparse.ArgumentParser):
    def error(self, message):
        raise UsageError(message)


def parser() -> argparse.ArgumentParser:
    top = _Parser(prog=TOOL, description=__doc__.split("\n\n")[0],
                  epilog="The short way to a place: wizard, then preview. Step by step: new --kind sites, add-place --recipe, add-action, add-pane, set-text, "
                         "add-dungeon, walk, art, validate, export. "
                         "Exit codes: 0 done or valid or compatible; 1 refused or incompatible; 2 a usage error.",
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
    made.add_argument("--kind", choices=KINDS, default=KIND_ISLAND,
                      help="island (the default): an island reached by ship; sites: places on the lands (API 2)")
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
    place = commands.add_parser("add-place", parents=[common], help="add a place to a sites plugin folder")
    place.add_argument("folder", nargs="?", default="")
    place.add_argument("--id", default="", help="the place's key: a-z, 0-9 and _, a letter first, up to 32")
    place.add_argument("--name", default="", help="its name on the map, up to 60 characters")
    place.add_argument("--where", default="mainland", help="mainland, islands or mainland,islands (default mainland)")
    place.add_argument("--recipe", choices=list(RECIPES), default="",
                       help="a whole place to rewrite: " + ", ".join(RECIPES) + " (see --list-recipes)")
    place.add_argument("--list-recipes", action="store_true", help="print the recipes, one line each, and exit")
    place.add_argument("--card", default="", help="with --recipe gift, collector, quest or shop: the card it is about")
    place.add_argument("--set", action="append", default=[], metavar="NAME=VALUE",
                       help="with --recipe: one of its numbers or names, like --set price=75 (the wizard asks for each; "
                            "a wrong name lists the recipe's own)")
    place.add_argument("--color", default="", choices=[""] + AMULET_COLORS,
                       help="with --recipe toll: the hero's color that passes free (default green)")
    place.add_argument("--look", default="", choices=[""] + list(PLACE_LOOKS),
                       help="its stand-in pictures: " + ", ".join(PLACE_LOOKS) + " (default: the recipe's own, else shrine)")
    place.add_argument("--service", choices=SERVICES, default="",
                       help="without --recipe, its one button: effects (pay, then effects), copy (copy a card) or "
                            "none (default effects)")
    place.add_argument("--prices", default="", help="the service's prices in gold, in turn, like 100,200")
    place.add_argument("--free", action="store_true", help="the service costs nothing and is never used up")
    act = commands.add_parser("add-action", parents=[common], help="add a button to a place of a sites plugin folder")
    act.add_argument("folder")
    act.add_argument("--place", required=True, help="the place's key")
    act.add_argument("--id", required=True, help="the action's own name in its place: a-z, 0-9 and _, up to 32")
    act.add_argument("--do", choices=list(ACTION_KINDS), default="effects",
                     help="effects (the default), talk, duel, copy, buy, sell or leave")
    act.add_argument("--label", default="", help="the button's words (may hold {price}, {uses_left})")
    act.add_argument("--prices", default="", help="the gold each use costs, in turn, like 100,200; then it is used up")
    act.add_argument("--free", action="store_true", help="no prices: free, and never used up (the default)")
    act.add_argument("--effect", action="append", default=[], metavar="K=V",
                     help="an effect, like gold=50, food=6, set_flag=told, counter=wins+1, amulet=red, "
                          "give_card=NAME, next_duel=life:5, spawn_dungeon=KEY, reveal_map=place:4, log_clue=WORDS "
                          "(may repeat)")
    act.add_argument("--outcome", action="append", default=[], metavar="\"W | EFFECTS | WORDS\"",
                     help="an outcome of a roll: its weight, its effects joined by ;, its words (repeat 2 to 6 times)")
    act.add_argument("--needs", action="append", default=[], metavar="K=V",
                     help="what it takes besides gold: card=NAME, amulets=any:2, food=5 (may repeat)")
    act.add_argument("--when", action="append", default=[], metavar="K=V",
                     help="shown while this holds, like flag=told, not_flag=told, counter=wins:3, has_card=NAME, "
                          "gold_at_least=50, hero_color=red; \"A | B\": one of them (may repeat: all hold)")
    act.add_argument("--result", default="", help="the words shown once it is done")
    act.add_argument("--pane", default="", help="the pane it stands in: a number, a pane's id, or all (every pane "
                                                "without an id); default: the place's own pane, the last without an id")
    act.add_argument("--to", default="", help="--do talk: the id of the pane it opens")
    act.add_argument("--foe", default="", help="--do duel: the foe's key")
    act.add_argument("--win", default="", help="--do duel: the words after a win")
    act.add_argument("--lose", default="", help="--do duel: the words after a loss")
    act.add_argument("--win-effect", action="append", default=[], metavar="K=V", help="--do duel: an effect of a win")
    act.add_argument("--lose-effect", action="append", default=[], metavar="K=V", help="--do duel: an effect of a loss")
    act.add_argument("--count", default="", choices=["", "press", "win"],
                     help="--do duel: a use is counted at each press (the default) or at each win")
    act.add_argument("--cards", default="", help="--do buy or sell: \"NAME=PRICE; NAME=PRICE\"")
    act.add_argument("--stock", type=int, default=None, help="--do buy or sell: how many of each card are traded")
    pane = commands.add_parser("add-pane", parents=[common], help="add a pane to a place of a sites plugin folder")
    pane.add_argument("folder")
    pane.add_argument("--place", required=True, help="the place's key")
    pane.add_argument("--id", default="", help="the pane's id: a talk action opens it by its --to")
    pane.add_argument("--when", action="append", default=[], metavar="K=V",
                      help="the pane is shown while this holds (see add-action --when)")
    pane.add_argument("--line", action="append", default=[], metavar="WORDS", help="a line of the pane (may repeat)")
    pane.add_argument("--title", default="", help="its title (default: the place's name)")
    pane.add_argument("--subtitle", default="", help="its subtitle (default: the plugin's name)")
    flag = commands.add_parser("add-flag", parents=[common], help="declare a flag in a sites plugin folder")
    flag.add_argument("folder")
    flag.add_argument("name", help="the flag: a-z, 0-9 and _, a letter first, up to 40")
    counter = commands.add_parser("add-counter", parents=[common], help="declare a counter in a sites plugin folder")
    counter.add_argument("folder")
    counter.add_argument("name", help="the counter: a-z, 0-9 and _, a letter first, up to 40")
    foe = commands.add_parser("add-foe", parents=[common], help="add a duel opponent to a sites plugin folder")
    foe.add_argument("folder")
    foe.add_argument("--id", required=True, help="the foe's key: a-z, 0-9 and _, a letter first, up to 40")
    foe.add_argument("--name", required=True, help="the foe's name, up to 60 characters")
    foe.add_argument("--life", type=int, default=20, help="the foe's life (default 20)")
    foe.add_argument("--deck", required=True, metavar="FILE",
                     help="a text file, one card a line, like \"4 Lightning Bolt\"")
    foe.add_argument("--face", type=int, default=3, help="the creature row whose face the foe wears (default 3)")
    foe.add_argument("--deck-name", default="", help="the deck's name on the duel screen")
    foe.add_argument("--replace", action="store_true", help="give a foe that is already there this name, life and deck")
    words = commands.add_parser("set-text", parents=[common], help="write or change one sentence of text.json")
    words.add_argument("folder")
    words.add_argument("key", help="the text's key, like shrine.intro")
    words.add_argument("words", help="the sentence, in quotes")
    about_it = commands.add_parser("set-info", parents=[common], help="set plugin.json's name, description, license, authors, version")
    about_it.add_argument("folder")
    about_it.add_argument("--name", default="", help="the name in the plugin list")
    about_it.add_argument("--description", default="", help="one line for the plugin list")
    about_it.add_argument("--license", default="", help="the plugin's license, in a line")
    about_it.add_argument("--author", action="append", default=[], help="an author (may repeat; replaces the list)")
    about_it.add_argument("--version", dest="plugin_version", default="", help="the plugin's version, like 1.0.0")
    about_it.add_argument("--note", default="", help="the learning note shown with the plugin")
    gone = commands.add_parser("remove-place", parents=[common], help="remove a place from a sites plugin folder")
    gone.add_argument("folder")
    gone.add_argument("--id", required=True, help="the place's key")
    vault = commands.add_parser("add-dungeon", parents=[common], help="add a dungeon to a sites plugin folder")
    vault.add_argument("folder")
    vault.add_argument("--id", required=True, help="the dungeon's key: a-z, 0-9 and _, a letter first, up to 40")
    vault.add_argument("--name", required=True, help="its name, up to 60 characters")
    vault.add_argument("--cards", required=True, help="its treasure: 1 to 6 card names, joined by commas")
    vault.add_argument("--color", choices=DUNGEON_COLORS, default="random")
    vault.add_argument("--size", choices=DUNGEON_SIZES, default="small")
    vault.add_argument("--rules", default="", help="any of %s, joined by commas" % ", ".join(DUNGEON_RULES))
    vault.add_argument("--min", type=int, default=6, help="nearest, in tiles from its place (default 6)")
    vault.add_argument("--max", type=int, default=24, help="farthest, in tiles (default 24)")
    vault.add_argument("--place", default="", help="a place whose button raises it (two panes are added: open, cleared)")
    vault.add_argument("--action", default="", help="with --place: the action's id (an existing effects action is extended)")
    vault.add_argument("--price", type=int, default=None, help="with --place: the gold it costs (default 1000)")
    walk = commands.add_parser("walk", parents=[common], help="play a sites plugin's places as text, without the game")
    walk.add_argument("plugin", help="a sites plugin folder or .zip")
    walk.add_argument("--site", default="", help="one place only")
    walk.add_argument("--gold", type=int, default=100000, help="the gold the hero carries (default 100000)")
    walk.add_argument("--food", type=int, default=0, help="the food the hero carries (default 0)")
    walk.add_argument("--press", default="", metavar="A,B,C",
                      help="with --site: press these buttons in turn (an action's id; leave: step out and in again; "
                           "clear: clear the open dungeon) instead of every button")
    walk.add_argument("--flag", action="append", default=[], metavar="NAME", help="a flag already set (may repeat)")
    walk.add_argument("--counter", action="append", default=[], metavar="NAME=N", help="a counter's start (may repeat)")
    walk.add_argument("--cards", action="append", default=[], metavar="\"A,B\"", help="cards the hero holds")
    walk.add_argument("--amulets", action="append", default=[], metavar="COLOR=N", help="amulets the hero carries, like red=2")
    walk.add_argument("--color", default="", help="the hero's color (default white)")
    walk.add_argument("--magic", action="append", default=[], metavar="NAME", help="a World Magic the hero owns")
    walk.add_argument("--magics", action="append", default=[], metavar="\"A,B\"", help="World Magics the hero owns")
    walk.add_argument("--life-bonus", type=int, default=0, metavar="N",
                      help="the life the places have added to the hero's start already, 0 to 10 (default 0)")
    walk.add_argument("--linked", action="store_true", help="the nearest town is mana-linked already")
    walk.add_argument("--day", type=int, default=0, help="the day of the journey (default 0, its first)")
    walk.add_argument("--wizards", type=int, default=0, help="wizards defeated (default 0)")
    walk.add_argument("--peace", action="store_true", help="the land is at peace (at_peace holds)")
    walk.add_argument("--difficulty", type=int, default=0, help="the campaign's difficulty, 0 to 3 (default 0)")
    walk.add_argument("--plugin", action="append", default=[], metavar="ID", help="another plugin that is on (plugin_on)")
    walk.add_argument("--gift", action="store_true", help="a gift for the next duel already waits")
    walk.add_argument("--land", choices=["mainland", "island"], default="", help="one land only")
    walk.add_argument("--both", action="store_true",
                      help="one hero walks the mainland and then an island, keeping gold, flags, uses and counters")
    walk.add_argument("--win", action="store_true", help="every duel is won (default: a free duel won, then lost)")
    walk.add_argument("--lose", action="store_true", help="every duel is lost")
    walk.add_argument("--roll", type=int, default=0, metavar="N",
                      help="every roll takes its N-th outcome (default: the likeliest)")
    walk.add_argument("--json", action="store_true")
    art = commands.add_parser("art", parents=[common], help="advice on a plugin's pane pictures and map sprites")
    art.add_argument("plugin", help="a plugin folder or .zip")
    art.add_argument("--json", action="store_true")
    look = commands.add_parser("preview", parents=[common],
                               help="write one HTML page that shows every pane of a sites plugin's places")
    look.add_argument("plugin", help="a sites plugin folder or .zip")
    look.add_argument("--site", default="", help="one place only")
    look.add_argument("--out", metavar="DIR", help="where the page goes (default: preview/ in the current folder)")
    look.add_argument("--open", action="store_true", help="open the page in the browser once written")
    wiz = commands.add_parser("wizard", parents=[common],
                              help="make a place by answering questions (a new plugin, or one more place in FOLDER)")
    wiz.add_argument("folder", nargs="?", default="", help="the plugin's folder (default: named after the plugin)")
    wiz.add_argument("--answers", metavar="FILE", default="",
                     help="the answers, one a line, instead of asking (an empty line takes the default)")
    guide = commands.add_parser("guide", parents=[common],
                                help="write GUIDE/reference.html and GUIDE/cheatsheet.html from the schema")
    guide.add_argument("--out", metavar="DIR", help="the guide's folder (default: expanded_adventure/GUIDE)")
    guide.add_argument("--check", action="store_true", help="exit 1 when a written page is not up to date")
    return top


COMMANDS = {"new": command_new, "validate": command_validate, "export": command_export, "info": command_info,
            "compat": command_compat, "guide": command_guide, "add-place": command_add_place,
            "add-dungeon": command_add_dungeon, "walk": command_walk, "art": command_art,
            "add-action": command_add_action, "add-pane": command_add_pane, "add-flag": command_add_flag,
            "add-counter": command_add_counter, "add-foe": command_add_foe, "set-text": command_set_text,
            "remove-place": command_remove_place, "set-info": command_set_info,
            "preview": command_preview, "wizard": command_wizard}


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
        return COMMANDS[args.command](args, game)
    except UsageError as error:
        print("%s: %s" % (TOOL, error), file=sys.stderr)
        if "--json" in argv:
            print(json.dumps({"error": {"tool": TOOL, "exit": 2, "message": str(error)}}))
        return 2


if __name__ == "__main__":
    sys.exit(main())
