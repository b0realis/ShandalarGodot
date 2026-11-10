"""Self-test: the adventure plugin authors' guide says what the game does.

Run from the repo root:
    python3 -m unittest discover -s tools -p 'test_*.py'

`expanded_adventure/GUIDE/` is local documentation for plugin authors,
shipped in every desktop release beside the prototype plugin (the owner,
2026-11-10: *"a html visual and code guide for the future authors (not
published but as local documentation)"*). It is hand-written, so these
tests hold it to the code and the prototype instead of trusting it:

- it is a guide that works from `file://` with nothing from elsewhere: every
  page links `guide.css`, no page or the stylesheet names another site or a
  script, every picture is one of the prototype's own four (never card art
  or a skin's), every link and `#anchor` lands;
- every page carries the same masthead and page list, marking itself;
- every quoted prototype file (`<figure class="quote" data-file
  data-pointer>`) is the real file's value at that place, every quoted text
  (`<q data-text>`) the real `text.json` words, every list drawn from the
  schema (`data-schema`) or from a GDScript constant (`data-gd`) the real
  list, every limit (`data-limit`) the schema's;
- `docs/adventure-plugins.md`'s table of hooks names only methods
  `DataRegion` has, and every hook it has.
No network, no Godot.
"""

import html
import json
import re
import unittest
from html.parser import HTMLParser
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
GUIDE = ROOT / "expanded_adventure" / "GUIDE"
PROTO = ROOT / "expanded_adventure" / "Fallen_Empires_Refuge_prototype"
SCHEMA_PATH = ROOT / "game" / "adventure" / "plugins" / "schema_v1.json"
DATA_REGION = ROOT / "game" / "adventure" / "plugins" / "data_region.gd"
DEV_DOC = ROOT / "docs" / "adventure-plugins.md"

## The prototype's own pictures, made small for the guide: the only
## pictures it may show (no card art, no 1997 or skin picture).
PICTURES = {"img/refuge_harbor.jpg", "img/refuge_castle.jpg",
            "img/refuge_port_map.webp", "img/refuge_castle_map.webp"}
## Pages every guide page lists, in order; reference.html is written by
## `tools/adventure_plugin.py guide`.
PAGES = ["index.html", "first-plugin.html", "world.html", "quests.html", "foes-rewards.html",
         "text.html", "art-music.html", "saves.html", "testing.html", "refuge.html",
         "reference.html", "faq.html"]
EXTERNAL = re.compile(r"^(?:[a-z][a-z0-9+.-]*:|//)", re.I)


class Page(HTMLParser):
    """One page's links, ids, pictures and checked blocks."""

    def __init__(self) -> None:
        super().__init__(convert_charrefs=True)
        self.ids: set[str] = set()
        self.links: list[str] = []
        self.sources: list[str] = []
        self.scripts = 0
        self.stylesheets: list[str] = []
        self.lang = ""
        self.charset = False
        self.viewport = False
        self.title = ""
        self.quotes: list[dict] = []
        self.lists: list[dict] = []
        self.limits: list[dict] = []
        self.texts: list[dict] = []
        self.tables: list[dict] = []
        self._stack: list[tuple[str, dict]] = []
        self._in_title = False

    # Open blocks being collected: (tag that closes it, record, key of its text).
    def handle_starttag(self, tag, attrs):
        a = dict(attrs)
        if "id" in a:
            self.ids.add(a["id"])
        if tag == "html":
            self.lang = a.get("lang", "")
        if tag == "meta" and "charset" in a:
            self.charset = a["charset"].lower() == "utf-8"
        if tag == "meta" and a.get("name") == "viewport":
            self.viewport = True
        if tag == "title":
            self._in_title = True
        if tag == "script":
            self.scripts += 1
        if tag == "link" and a.get("rel") == "stylesheet":
            self.stylesheets.append(a.get("href", ""))
        for key in ("href", "src"):
            if key in a and tag != "link":
                (self.links if key == "href" else self.sources).append(a[key])
        if tag == "link" and "href" in a:
            self.sources.append(a["href"])
        if tag == "figure" and "data-file" in a:
            self._stack.append(("figure", {"file": a["data-file"], "pointer": a.get("data-pointer", ""),
                                           "keys": a.get("data-keys"), "text": "", "on": False}))
        elif tag == "pre" and self._stack and self._stack[-1][0] == "figure":
            self._stack[-1][1]["on"] = True
        elif tag == "ul" and ("data-schema" in a or "data-gd" in a):
            self._stack.append(("ul", {"schema": a.get("data-schema"), "gd": a.get("data-gd"), "items": [], "code": None}))
        elif tag == "code" and self._stack and self._stack[-1][0] == "ul":
            self._stack[-1][1]["code"] = ""
        elif tag == "span" and "data-limit" in a:
            self._stack.append(("span", {"limit": a["data-limit"], "text": ""}))
        elif tag == "q" and "data-text" in a:
            self._stack.append(("q", {"key": a["data-text"], "text": ""}))
        elif tag == "table" and "data-schema-table" in a:
            self._stack.append(("table", {"schema": a["data-schema-table"], "codes": [], "code": None}))
        elif tag == "code" and self._stack and self._stack[-1][0] == "table":
            self._stack[-1][1]["code"] = ""

    def handle_endtag(self, tag):
        if tag == "title":
            self._in_title = False
        if not self._stack:
            return
        kind, record = self._stack[-1]
        if tag == "code" and kind in ("ul", "table") and record["code"] is not None:
            (record["items"] if kind == "ul" else record["codes"]).append(record["code"])
            record["code"] = None
            return
        if tag == "pre" and kind == "figure":
            record["on"] = False
            return
        if tag != kind:
            return
        self._stack.pop()
        {"figure": self.quotes, "ul": self.lists, "span": self.limits, "q": self.texts, "table": self.tables}[kind].append(record)

    def handle_data(self, data):
        if self._in_title:
            self.title += data
        if not self._stack:
            return
        kind, record = self._stack[-1]
        if kind == "figure" and record["on"]:
            record["text"] += data
        elif kind in ("ul", "table") and record["code"] is not None:
            record["code"] += data
        elif kind in ("span", "q"):
            record["text"] += data


def read_page(name: str) -> tuple[str, Page]:
    text = (GUIDE / name).read_text(encoding="utf-8")
    page = Page()
    page.feed(text)
    page.close()
    return text, page


def schema() -> dict:
    return json.loads(SCHEMA_PATH.read_text(encoding="utf-8"))


def schema_values(key: str) -> list:
    spec = schema()
    types = spec["types"]
    return {
        "placeholders": lambda: list(spec["placeholders"]),
        "conditions": lambda: list(types["condition"]["options"]),
        "effects": lambda: list(types["effect"]["options"]),
        "steps": lambda: types["step"]["fields"]["do"]["values"],
        "actions": lambda: types["action"]["fields"]["do"]["values"],
        "shows": lambda: types["line"]["options"][2]["fields"]["show"]["values"],
        "extensions": lambda: spec["extensions"]["allowed"],
        "skin_pictures": lambda: spec["skin_pictures"],
        "terrains": lambda: types["terrain"]["values"],
        "files": lambda: list(spec["files"]),
        "site_kinds": lambda: types["site_kind"]["values"],
        "roaming_colors": lambda: types["roaming_deck"]["fields"]["colors"]["items"]["values"],
        "trade": lambda: types["world"]["fields"]["trade"]["items"]["values"],
        "ante": lambda: types["foes"]["fields"]["roaming"]["fields"]["ante"]["values"],
    }[key]()


def gd_constant(spec: str) -> list[str]:
    """The text literals of a GDScript constant, `path.gd:NAME`: an
    array's items, or a dictionary's keys."""
    file, name = spec.split(":")
    source = (ROOT / file).read_text(encoding="utf-8")
    found = re.search(r"^const " + re.escape(name) + r"\b[^=\n]*=\s*", source, re.M)
    if found is None:
        raise AssertionError(f"{file} has no const {name}")
    body = source[found.end():]
    opener = body[0]
    closer = {"[": "]", "{": "}"}[opener]
    depth = 0
    for i, character in enumerate(body):
        depth += character == opener
        depth -= character == closer
        if depth == 0:
            literal = body[: i + 1]
            break
    if opener == "[":
        return re.findall(r'"([^"]*)"', literal)
    return re.findall(r'^\s*"([^"]+)"\s*:', literal, re.M)


def at_pointer(document, pointer: str):
    if pointer in ("", "/"):
        return document
    for part in pointer.lstrip("/").split("/"):
        part = part.replace("~1", "/").replace("~0", "~")
        document = document[int(part)] if isinstance(document, list) else document[part]
    return document


def limit_words(value: int) -> str:
    if value >= 1048576 and value % 1048576 == 0:
        return f"{value // 1048576} MiB"
    return f"{value:,}"


def between(text: str, start: str, end: str) -> str:
    at = text.find(start)
    stop = text.find(end, at)
    return text[at:stop] if at >= 0 and stop >= 0 else ""


def hand_pages() -> list[str]:
    """The guide's own pages (reference.html is the tool's)."""
    return [name for name in PAGES if name != "reference.html"]


class TheGuideStandsAlone(unittest.TestCase):
    def test_every_page_of_the_list_is_there_and_nothing_else(self):
        found = sorted(p.name for p in GUIDE.glob("*.html"))
        self.assertEqual(found, sorted(PAGES))

    def test_each_page_is_a_whole_page_in_the_one_stylesheet(self):
        for name in PAGES:
            with self.subTest(page=name):
                _, page = read_page(name)
                self.assertEqual(page.lang, "en")
                self.assertTrue(page.charset, "utf-8")
                self.assertTrue(page.viewport, "phone width")
                self.assertIn("Adventure plugin guide", page.title)
                self.assertEqual(page.stylesheets, ["guide.css"])
                self.assertEqual(page.scripts, 0, "no scripts")

    def test_nothing_is_asked_of_another_place(self):
        for name in PAGES:
            with self.subTest(page=name):
                text, page = read_page(name)
                for address in page.links + page.sources:
                    self.assertIsNone(EXTERNAL.match(address), f"{name} names {address}")
                self.assertNotRegex(text, r"(?i)@import|url\(\s*['\"]?(?:https?:)?//")
        css = (GUIDE / "guide.css").read_text(encoding="utf-8")
        self.assertNotRegex(css, r"(?i)@import|url\(|https?:")
        self.assertIn("prefers-color-scheme: dark", css)

    def test_every_picture_is_one_of_the_prototypes_own(self):
        shown = set()
        for name in PAGES:
            _, page = read_page(name)
            for source in page.sources:
                if source != "guide.css":
                    self.assertIn(source, PICTURES, f"{name} shows {source}")
                    shown.add(source)
        self.assertEqual(shown, PICTURES)
        on_disk = {f"img/{p.name}" for p in (GUIDE / "img").iterdir()}
        self.assertEqual(on_disk, PICTURES, "img/ holds the four pictures and nothing else")

    def test_every_link_and_anchor_lands(self):
        ids = {name: read_page(name)[1].ids for name in PAGES}
        for name in PAGES:
            _, page = read_page(name)
            for link in page.links:
                with self.subTest(page=name, link=link):
                    target, _, anchor = link.partition("#")
                    target = target or name
                    self.assertIn(target, PAGES, f"{name} links {link}")
                    if anchor:
                        self.assertIn(anchor, ids[target], f"{name} links {link}")

    def test_every_page_carries_the_same_masthead_and_list(self):
        first, _ = read_page("index.html")
        masthead = between(first, "<!-- guide:masthead -->", "<!-- /guide:masthead -->")
        toc = between(first, "<!-- guide:toc -->", "<!-- /guide:toc -->")
        self.assertTrue(masthead and toc)
        self.assertEqual(re.findall(r'href="([^"#]+\.html)"', toc), PAGES)
        for name in PAGES:
            with self.subTest(page=name):
                text, _ = read_page(name)
                self.assertEqual(between(text, "<!-- guide:masthead -->", "<!-- /guide:masthead -->"), masthead)
                own = between(text, "<!-- guide:toc -->", "<!-- /guide:toc -->")
                self.assertEqual(re.findall(r'href="([^"]+)" aria-current="page"', own), [name])
                self.assertEqual(own.replace(' aria-current="page"', ""), toc.replace(' aria-current="page"', ""))


class TheGuideSaysWhatTheGameDoes(unittest.TestCase):
    def test_every_quoted_file_is_the_real_file(self):
        count = 0
        for name in hand_pages():
            _, page = read_page(name)
            for quote in page.quotes:
                with self.subTest(page=name, file=quote["file"], pointer=quote["pointer"]):
                    real = json.loads((PROTO / quote["file"]).read_text(encoding="utf-8"))
                    value = at_pointer(real, quote["pointer"])
                    if quote["keys"]:
                        value = {key: value[key] for key in quote["keys"].split(",")}
                    self.assertEqual(json.loads(html.unescape(quote["text"])), value)
                    count += 1
        self.assertGreater(count, 30, "the walkthrough quotes the prototype")

    def test_every_quoted_sentence_is_the_real_words(self):
        words = json.loads((PROTO / "text.json").read_text(encoding="utf-8"))
        for name in hand_pages():
            _, page = read_page(name)
            for quote in page.texts:
                with self.subTest(page=name, key=quote["key"]):
                    self.assertEqual(quote["text"], words[quote["key"]])

    def test_every_list_is_the_schemas_or_the_codes(self):
        seen = set()
        for name in hand_pages():
            _, page = read_page(name)
            for listed in page.lists:
                with self.subTest(page=name, schema=listed["schema"], gd=listed["gd"]):
                    if listed["schema"]:
                        real = [str(v) for v in schema_values(listed["schema"])]
                        seen.add(listed["schema"])
                    else:
                        real = gd_constant(listed["gd"])
                        seen.add(listed["gd"])
                    self.assertEqual(listed["items"], real)
        for needed in ("placeholders", "conditions", "effects", "steps", "extensions",
                       "game/adventure/plugins/plugin_text.gd:DEFAULTS",
                       "game/adventure/plugins/plugin_schema.gd:RESERVED_FLAGS"):
            self.assertIn(needed, seen)

    def test_every_table_of_codes_is_the_schemas(self):
        for name in hand_pages():
            _, page = read_page(name)
            for table in page.tables:
                with self.subTest(page=name, schema=table["schema"]):
                    real = sorted(str(v) for v in schema_values(table["schema"]))
                    self.assertEqual(sorted(table["codes"]), real)

    def test_every_limit_is_the_schemas(self):
        limits = schema()["limits"]
        count = 0
        for name in hand_pages():
            _, page = read_page(name)
            for limit in page.limits:
                with self.subTest(page=name, limit=limit["limit"]):
                    self.assertEqual(limit["text"], limit_words(limits[limit["limit"]]))
                    count += 1
        self.assertGreater(count, 5)

    def test_the_package_rules_are_the_loaders(self):
        # The words the pages give for what a plugin may hold, against the
        # loader's own constants.
        source = (ROOT / "game/adventure/plugins/plugin_package.gd").read_text(encoding="utf-8")
        testing, _ = read_page("testing.html")
        for literal in gd_constant("game/adventure/plugins/plugin_package.gd:LITTER"):
            self.assertIn(literal.lower(), testing.lower())
        self.assertIn('LITTER_FOLDER := "__macosx"', source)
        self.assertIn("__MACOSX", testing)
        self.assertIn("MAX_PATH := 200", source)
        self.assertIn("at most 200 characters", testing)

    def test_the_commands_are_the_tools(self):
        tool = (ROOT / "tools" / "adventure_plugin.py").read_text(encoding="utf-8")
        named = set()
        for name in hand_pages():
            text, _ = read_page(name)
            plain = html.unescape(re.sub(r"<[^>]+>", "", text))
            named.update(re.findall(r"python3 tools/adventure_plugin\.py (\w+)", plain))
        self.assertTrue({"new", "validate", "export", "compat"} <= named, named)
        for command in named:
            self.assertRegex(tool, r'add_parser\(\s*"' + command + '"', command)
        # The options the pages use.
        for option in ("--id", "--name", "--out", "--json", "--game"):
            self.assertIn('"' + option + '"', tool, option)


class TheDeveloperReference(unittest.TestCase):
    def test_the_hook_table_is_data_regions(self):
        doc = DEV_DOC.read_text(encoding="utf-8")
        table = between(doc, "<!-- hooks -->", "<!-- /hooks -->")
        listed = re.findall(r"^\| `(\w+)\(", table, re.M)
        self.assertTrue(listed, "docs/adventure-plugins.md lists the hooks")
        source = DATA_REGION.read_text(encoding="utf-8")
        for hook in listed:
            self.assertRegex(source, r"(?m)^func " + hook + r"\(", hook)
        for hook in ("initialize", "describe", "decorate_town", "ordinary_quests", "act", "status_lines",
                     "targets", "deck_line", "roaming_tier", "tales", "news", "applause", "roaming_words",
                     "dungeon_words", "entered", "task_rows", "generate", "roaming_encounter",
                     "study_decks", "music"):
            self.assertIn(hook, listed, "the §4 hook list")

    def test_the_conditions_and_effects_named_are_the_schemas(self):
        doc = DEV_DOC.read_text(encoding="utf-8")
        for group in ("conditions", "effects"):
            line = between(doc, f"<!-- {group} -->", f"<!-- /{group} -->")
            self.assertEqual(re.findall(r"`(\w+)`", line), schema_values(group), group)


if __name__ == "__main__":
    unittest.main()
