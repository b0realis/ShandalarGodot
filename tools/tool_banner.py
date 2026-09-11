#!/usr/bin/env python3
"""THE FAMILY BANNER — the wordmark, the version line and the colour rules
every command-line tool in this repository shares.

This is the Python side of `DeckLab/lab_console.gd`, and it keeps that
file's discipline rather than inventing its own. Read that header first;
the three rules it argues for are repeated here because breaking any one
of them is a bug, not a style disagreement.

WHY THE DECORATION LIVES ON stderr, AND ONLY ON A TERMINAL
----------------------------------------------------------
Every tool here is a MEASURING OR BUILDING INSTRUMENT before it is a nice
experience, and several have a stdout that something else reads:
`skin_catalogue.py --stdout` IS the catalogue, `build_release.sh`'s stdout
names the files a release is made of, and `run_tests.sh`/`duel_soak.sh`
are read line by line by their own gates. So stdout is the instrument's
channel and stderr is the human's — the banner goes to stderr, and ONLY
when stderr is a terminal.

The consequence is the one that matters: `tool.py > run.log` keeps the
artwork on screen and the log clean, and `tool.py > run.log 2>&1` — what
a script or an agent writes — gets no decoration at all without anyone
having to remember a flag.

THE OPT-OUT, for anyone who runs a hundred invocations a day: export
`SHANDALAR_NO_BANNER=1` and no tool in the family
ever draws it again. `NO_COLOR` (https://no-color.org) drops the colour
and keeps the shape. The Deck Lab keeps its own older `DECK_LAB_NO_BANNER`
as well, and `DeckLab/deck_lab.sh` maps the family variable onto it, so
one export covers all twelve tools.

ONE SOURCE FOR THE VERSION, AND NO GUESSING. `project.godot`'s
`config/version=` is the only version string this project has;
`project_version()` walks up from the tool's own file to find it and
returns None when there is no checkout to read — which is what a tool
shipped beside the packaged game sees, and it says "version unknown"
rather than inventing a number.

THE MINI-HELP UNDER THE BANNER (2026-09-11) is the same decoration and
rides the SAME THREE GUARDS — stderr, a terminal, and the opt-out. Two or
three lines of the invocations somebody actually types, and a last line
naming `-h`, which is where the manual is. It is drawn only for a BARE
command line: somebody who typed flags has already said what they want,
and the tool that is told what to do gets on with it. Before this, a bare
run drew the wordmark and then simply ACTED — `fetch_cards.py` started
hitting Scryfall, `gen_cards.py` started rewriting card files — with no
reminder of what was about to happen. The lines themselves belong to each
tool (its `HINT`), quoted out of its own examples block so the two cannot
drift; `tools/test_tool_banner.py` pins that they are quoted rather than
rewritten. The Deck Lab did this first, as usual (`DeckLab/simulate.gd`,
`_usage_hint`), and keeps its own.

Standard library only, and nothing here may raise: a decoration that can
break a build is worse than no decoration. Every public function is
unit-tested in tools/test_tool_banner.py.
"""

from __future__ import annotations

import os
import re
import sys
from pathlib import Path

## Export this to 1 to never see a banner from any of these tools again.
NO_BANNER_ENV = "SHANDALAR_NO_BANNER"
## The one file that holds the project's version, and the line in it.
PROJECT_FILE = "project.godot"
VERSION_RE = re.compile(r'^config/version="(.*)"\s*$', re.MULTILINE)
## What the banner and --version say when there is no checkout to read.
UNKNOWN = "version unknown"

# ANSI SGR codes, the basic sixteen only — every terminal that has colour
# at all has these, and everything degrades to plain text when `colour` is
# false rather than needing a second code path. Same set, same names as
# DeckLab/lab_console.gd.
ESC = "\x1b"
RESET = "\x1b[0m"
BOLD = "\x1b[1m"
DIM = "\x1b[2m"
AMBER = "\x1b[33m"

## The five colours of Magic, in WUBRG order, for the banner's signature
## line. Black is grey because black on black is nothing.
MANA = (("W", "\x1b[97m"), ("U", "\x1b[94m"), ("B", "\x1b[90m"),
        ("R", "\x1b[91m"), ("G", "\x1b[92m"))

## The line every tool's `-h` ends with, so the opt-out is discoverable
## from the tool itself rather than from this file.
## WRAPPED ALREADY, on purpose: every tool below hands it to argparse's
## RawDescriptionHelpFormatter, which does not fold a long line.
BANNER_HELP = (
    "The banner goes to stderr and only to a terminal, so a redirected run\n"
    "is clean. Export %s=1 to switch it off for every tool here,\n"
    "NO_COLOR=1 to keep the shape without the colour." % NO_BANNER_ENV
)


def project_version(start: str | Path | None = None) -> str | None:
    """The `config/version` of the nearest `project.godot` at or above
    `start` (default: this file's own directory), or None.

    Walks UP rather than guessing a depth: a tool is run from the repo
    root, from `tools/`, and — for the four that ship with the game —
    from a folder that has no `project.godot` at all. None is the honest
    answer for the last one; nothing here ever invents a number.
    """
    here = Path(start).resolve() if start is not None else Path(__file__).resolve()
    if here.is_file():
        here = here.parent
    for folder in [here, *here.parents]:
        candidate = folder / PROJECT_FILE
        try:
            if not candidate.is_file():
                continue
            match = VERSION_RE.search(candidate.read_text(encoding="utf-8",
                                                          errors="replace"))
        except OSError:
            continue
        if match:
            return match.group(1)
    return None


def version_text(start: str | Path | None = None) -> str:
    """The version for display — the number, or UNKNOWN."""
    return project_version(start) or UNKNOWN


def version_report(tool: str, start: str | Path | None = None) -> str:
    """The whole `--version` line. When there IS no project.godot it says
    where it looked instead of printing a number nobody can trust."""
    found = project_version(start)
    if found is None:
        return ("%s — Shandalar %s: no %s above %s (run it from a checkout)"
                % (tool, UNKNOWN, PROJECT_FILE, _start_dir(start)))
    return "%s — Shandalar %s" % (tool, found)


def _start_dir(start: str | Path | None) -> str:
    here = Path(start).resolve() if start is not None else Path(__file__).resolve()
    return str(here.parent if here.is_file() else here)


def paint(text: str, code: str, colour: bool) -> str:
    """`text` wrapped in an SGR code, or untouched when `colour`
    is false. EVERY colour here goes through this, so "degrades to
    plain text" is one line of code rather than a discipline."""
    if not colour or not code:
        return text
    return code + text + RESET


def banner_lines(wordmark, caption, version: str, colour: bool) -> list[str]:
    """The banner, as lines: the wordmark with its two-line caption beside
    it, and the five mana pips signing the last row with the version.

    THREE LINES AND NO MORE, for DeckLab/lab_console.gd's reason: a banner
    somebody has to scroll past is a banner that gets switched off.
    `wordmark` is the tool's name in the same half-height
    box-drawing face the Deck Lab uses, EVERY ROW PADDED TO ONE WIDTH so
    the caption keeps its column.
    """
    pips = " ".join(paint(letter, code, colour) for letter, code in MANA)
    signature = pips + "   " + paint(version, DIM, colour)
    lines: list[str] = []
    for i, row in enumerate(wordmark):
        beside = signature if i == len(wordmark) - 1 else paint(
            caption[i] if i < len(caption) else "", DIM, colour)
        line = "  " + paint(row, AMBER + BOLD, colour)
        if beside:
            line += "   " + beside
        lines.append(line)
    return lines


def banner(wordmark, caption, version: str, colour: bool) -> str:
    return "\n".join(banner_lines(wordmark, caption, version, colour))


def hint_lines(hint, colour: bool) -> list[str]:
    """THE MINI-HELP, as lines: the invocations in `hint`, indented under
    the wordmark, with the `# note` after each dimmed so the command
    itself is what the eye lands on.

    TWO OR THREE LINES AND NO MORE, for the banner's own reason: this is
    a reminder for somebody who has just typed the command, not a manual,
    and a mini-help that scrolls is a failed mini-help. The last line
    always names `-h` — the manual is one flag away and should say so.
    """
    out: list[str] = []
    for row in hint:
        text = str(row).rstrip()
        if not text:
            continue
        note = text.find("#")
        if note > 0:
            text = text[:note] + paint(text[note:], DIM, colour)
        out.append("  " + text)
    return out


def here_prefix(script: str | Path | None = None) -> str:
    """The path an example has to carry to be a line somebody can copy:
    `tools/` in a checkout, nothing at all beside a packaged game.

    FOUR OF THESE TOOLS SHIP (build_release.sh copies mtg_assets.py,
    import_original.py, fetch_card_art.py and skin_catalogue.py into one
    flat folder beside the binary), so every example in them is wrong in
    one of the two places unless it is ASKED rather than assumed —
    `python3 tools/import_original.py` is "No such file or directory" for
    a player, and `python3 import_original.py` is the same thing for
    anyone standing in the repo root, which is where the README's
    examples are typed. Answered from the tool's own location: a file in
    a `tools/` folder with a project.godot above it is in a checkout.
    """
    path = Path(script).resolve() if script is not None else Path(__file__).resolve()
    folder = path.parent if path.is_file() else path
    try:
        if folder.name == "tools" and (folder.parent / PROJECT_FILE).is_file():
            return "tools/"
    except OSError:
        pass
    return ""


def examples(hint) -> str:
    """A tool's `HINT` as an argparse epilog block — every line but the
    last, indented four.

    The last one is dropped because it points at the `-h` whoever is
    reading this already typed. Tools whose examples block is longer than
    the mini-help quote the same lines instead of calling this; either
    way the invocation text has ONE source, which is what
    tools/test_tool_banner.py pins.
    """
    return "\n".join("    " + str(row) for row in list(hint)[:-1])


def wanted(stream=None) -> bool:
    """Whether to draw anything at all: a terminal on the far end, and no
    opt-out. Anything that is not a terminal — a pipe, a file, a CI log —
    gets nothing."""
    stream = sys.stderr if stream is None else stream
    if os.environ.get(NO_BANNER_ENV, "") not in ("", "0"):
        return False
    try:
        return bool(stream.isatty())
    except Exception:
        # A stream that cannot even answer is not a terminal. Decoration
        # never raises.
        return False


def use_colour(stream=None) -> bool:
    """Colour is a terminal thing, and `NO_COLOR` (any value) turns it
    off — the convention every modern CLI honours."""
    return wanted(stream) and os.environ.get("NO_COLOR", "") == ""


def show(wordmark, caption, script: str | Path | None = None,
         stream=None, hint=(), argv=None) -> None:
    """Draw the banner on stderr if there is a human there to read it,
    and `hint` — the mini-help — under it when the command line was bare.

    Called once at the top of a tool's main(). Silent — and harmless —
    whenever stderr is not a terminal, the opt-out is set, or anything at
    all goes wrong: a tool must never fail because of its own artwork.

    `argv` is the tool's OWN arguments, which is how the mini-help tells
    a bare command from one that already knows what it wants; None means
    `sys.argv[1:]`, and a main() that takes an argv passes it through so
    that an in-process call is judged by what it was handed rather than
    by what started the interpreter.
    """
    stream = sys.stderr if stream is None else stream
    try:
        if not wanted(stream):
            return
        colour = use_colour(stream)
        stream.write(banner(wordmark, caption, version_text(script),
                            colour) + "\n\n")
        # THE MINI-HELP IS A SECOND WRITE, after the wordmark has already
        # reached the stream: a `hint` that is somehow not a list of
        # lines must not be able to take the banner down with it.
        given = sys.argv[1:] if argv is None else list(argv)
        if hint and not given:
            stream.write("\n".join(hint_lines(hint, colour)) + "\n\n")
    except Exception:
        pass
    try:
        stream.flush()
    except Exception:
        pass


def add_version_flag(parser, tool: str, script: str | Path | None = None):
    """`-V` / `--version` on an argparse parser, reading the one source.

    argparse's own `version=` action wants the string at PARSE-BUILD time;
    this reads the file when the flag is actually used, so a tool that is
    imported (build_card_packs imports two others) never touches the disk
    for a version nobody asked for.
    """
    import argparse

    class _Version(argparse.Action):
        def __init__(self, option_strings, dest, **kwargs):
            super().__init__(option_strings, dest, nargs=0, **kwargs)

        def __call__(self, _parser, _namespace, _values, _option=None):
            print(version_report(tool, script))
            _parser.exit()

    parser.add_argument("-V", "--version", action=_Version,
                        help="print the Shandalar version and exit")
    return parser
