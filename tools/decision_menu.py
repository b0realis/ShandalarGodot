#!/usr/bin/env python3
"""Numbered-choice menus for DECISION MODELS (2026-10-04) — programs that
choose moves rather than chat: a small local model, a scripted bot, a
reinforcement-learning policy, a decision tool. Each referee decision
becomes a compact OBSERVATION and a MENU of complete legal actions; the
model answers with one number (or the item's id) and the `Driver` here
turns it into the wire's ops — prepare/autopay/submit, the attack and
block lists, the choice picks — and reads on to the next decision. No
MTG wire knowledge is needed by the model.

Pure: no process, no socket, no file. `Driver` does the sequencing over
two callables it is handed (`send(action)` and `receive() -> record`),
so the same code runs behind `tools/shandalar_decide.py` (a pipe to the
referee) and inside the MCP server (a `Game`'s pipe or socket).

THE MENU (`build_menu`). Item 0 is the "do nothing" answer wherever the
mode has one — pass, no attack, no blocks, keep, play first, damage in
order — so a baseline that always picks 0 is the passive one (a discard,
a choice or a target pick has no such answer: item 0 is its first
option). Every item is complete: picking it
needs no further knowledge, and the ids are stable across identical
states (`cast:c12->c18` is the card handle `c12` aimed at `c18`):

  opening   order:play, order:draw (the toss winner, once), then keep,
            mulligan.
  priority  pass; play:<land>; cast:<card>[:m<mode>][:x<X>][-><target>]
            — one item per legal target of a one-target spell (read from
            the referee's own announcement, `probe_actions`; at most
            MAX_FLAT_TARGETS, else one item and a target sub-menu);
            act:<card>:<index>[:x<X>][-><target>] for an activated
            ability; special:<i> (Channel, paid prevention, a delayed
            trigger to settle). A modal spell is offered in the modes
            its `usable_modes` lists (all of them from an older referee),
            the id keeping the mode's index. Mana abilities are not items: the
            auto-pay taps for every cast. Identical hand cards (and
            identical permanents' abilities) are listed once.
  targets   a cast whose targets did not fit one flat list (two slots,
            "up to N", divided damage, an X spell, too many candidates):
            target:<t> per candidate, target:none / target:done when the
            slot may stop, cancel. Divided amounts are split evenly, the
            remainder to the first target named.
  attack    attack:none, attack:all, attack:add:<card> one creature at a
            time, then attack:declare — no subset explosion. A creature
            that must attack is already in the selection.
  block     block:none, block:<blocker>-><attacker> one pair at a time
            (several blockers may share an attacker), block:declare.
  discard   discard:<card>, one pick at a time until the count is met.
  damage    damage:ordered (lethal to each in the order given, the rest
            to the last), damage:upto:<id> (lethal to those before it,
            the rest to it), damage:all:<id> (only when the table's
            rules let damage be assigned freely).
  choice    choice:<i> per option (a multi-pick question one pick at a
            time), choice:cancel when the question is a cost that may be
            withdrawn.

A sub-menu step (attack:add, block pairs, discard and choice picks, the
target picks) changes nothing on the wire until the last pick; then the
whole answer is sent.

THE GUARD. A cast is sent as `prepare`, `autopay` (only once the
announcement says the payment is reachable — nothing is tapped for a
cast that cannot be paid), `submit`. Should the referee refuse any step,
the announcement is cancelled at once (never left half-announced) and
that action is dropped from the menu until the turn, step or stack
changes; the refusal is counted in `Driver.stats`.

THE OBSERVATION (`encode_observation`): the decision from the deciding
seat's side — `me`/`opp` (life, hand and library counts, mana, poison,
battlefield with flags, phased-out permanents, graveyard and exile
names), this seat's hand with costs and castable marks, the stack, the
open prompt, the sub-menu selection so far, the journal lines since the
model last chose — plus `features`, a fixed-size numeric vector whose
every field is named in FEATURES (and `item_features` / ITEM_FEATURES
for one menu item).
"""

from __future__ import annotations

import hashlib
import json
import re

# --- the tables the encoder and the menu read --------------------------------

STEPS = ("UNTAP", "UPKEEP", "DRAW", "MAIN1", "COMBAT_BEGIN", "DECLARE_ATTACKERS",
         "DECLARE_BLOCKERS", "FIRST_STRIKE_DAMAGE", "COMBAT_DAMAGE", "COMBAT_END",
         "MAIN2", "END", "CLEANUP")
MODES = ("opening", "priority", "attack", "block", "discard", "damage", "choice", "targets")
# engine/core/mtg.gd: CardType bits and the Keyword enum, as the view carries them.
TYPE_BITS = ((1, "land"), (2, "creature"), (4, "artifact"), (8, "enchantment"),
             (16, "instant"), (32, "sorcery"))
KEYWORDS = ("flying", "reach", "vigilance", "haste", "trample", "defender", "first strike",
            "must attack", "banding", "unblockable", "fear", "flash", "phasing", "flanking")
KW_FLYING = 0
KW_MUST_ATTACK = 7
OWN_MAIN = ("MAIN1", "MAIN2")

# The flat list of one spell's targets stops here; past it, a sub-menu.
MAX_FLAT_TARGETS = 16
# An X spell offers at most this many values of X (spread from 1 to the budget).
MAX_X_CHOICES = 6
# Words of a rules text that say a spell or ability may have targets — a
# spell without them needs no probe (its announcement has no slot).
AIMS = re.compile(r"\btarget|\benchant\b", re.IGNORECASE)
# A slot whose description asks for a target different from its siblings'.
DISTINCT = re.compile(r"\b(another|other|second|third|fourth|different)\b", re.IGNORECASE)
# The item kinds, in the order ITEM_FEATURES one-hot encodes them.
KINDS = ("pass", "play", "cast", "act", "special", "attack_none", "attack_all", "attack_add",
         "attack_declare", "block_none", "block_pair", "block_declare", "discard", "damage",
         "choice", "keep", "mulligan", "order", "target", "cancel")


# --- reading the view ------------------------------------------------------

def _seat(decision: dict) -> int:
    try:
        return int(decision.get("seat", 0))
    except (TypeError, ValueError):
        return 0


def _view(decision: dict) -> dict:
    view = decision.get("view")
    return view if isinstance(view, dict) else {}


def _options(decision: dict) -> dict:
    options = decision.get("options")
    return options if isinstance(options, dict) else {}


def mode_of(decision: dict) -> str:
    return str(decision.get("mode") or _options(decision).get("mode") or "")


def _player(view: dict, seat: int) -> dict:
    for player in view.get("players") or []:
        if isinstance(player, dict) and player.get("seat") == seat:
            return player
    players = view.get("players") or []
    return players[seat] if 0 <= seat < len(players) and isinstance(players[seat], dict) else {}


def _presentation(view: dict) -> dict:
    presentation = view.get("presentation")
    return presentation if isinstance(presentation, dict) else {}


def card_index(view: dict, seat: int) -> dict:
    """Every card the view shows, by handle: `{handle: (card, zone, side)}`
    — zone `hand|battlefield|graveyard|exile|revealed|phased_out`, side
    `me|opp` from `seat`'s chair."""
    out: dict = {}
    for card in view.get("hand") or []:
        if isinstance(card, dict) and card.get("id"):
            out[card["id"]] = (card, "hand", "me")
    for player in view.get("players") or []:
        if not isinstance(player, dict):
            continue
        side = "me" if player.get("seat") == seat else "opp"
        for zone in ("battlefield", "phased_out", "graveyard", "exile", "revealed"):
            for card in player.get(zone) or []:
                if isinstance(card, dict) and card.get("id") and card["id"] not in out:
                    owner = side if zone != "battlefield" else (
                        "me" if card.get("controller", player.get("seat")) == seat else "opp")
                    out[card["id"]] = (card, zone, owner)
    return out


def presentation_rows(view: dict) -> dict:
    return {row.get("id"): row for row in _presentation(view).get("cards") or [] if isinstance(row, dict)}


def spell_cost(row: dict | None) -> str:
    for option in (row or {}).get("abilities") or []:
        if isinstance(option, dict) and option.get("kind") == "spell":
            return str(option.get("cost") or "")
    return ""


def mana_value(cost: str) -> int:
    """`{3}{W}{W}` → 5; X counts 0 (CR 202.3e)."""
    total = 0
    for symbol in re.findall(r"\{([^}]*)\}", cost or ""):
        if symbol.isdigit():
            total += int(symbol)
        elif symbol.upper() in ("X", "Y", "Z", "T", "Q", ""):
            continue
        else:
            total += 1
    return total


def type_words(card: dict) -> list[str]:
    bits = card.get("types")
    if not isinstance(bits, int):
        return ["creature"] if card.get("creature") else (["land"] if card.get("land") else [])
    return [word for bit, word in TYPE_BITS if bits & bit]


def keyword_words(card: dict) -> list[str]:
    out = []
    for value in card.get("keywords") or []:
        if isinstance(value, int) and 0 <= value < len(KEYWORDS):
            out.append(KEYWORDS[value])
        elif isinstance(value, str):
            out.append(value)
    return out


def _is_creature(card: dict) -> bool:
    return bool(card.get("creature")) or (isinstance(card.get("types"), int) and card["types"] & 2 != 0)


def _is_land(card: dict) -> bool:
    return bool(card.get("land")) or (isinstance(card.get("types"), int) and card["types"] & 1 != 0)


def _signature(card: dict, zone: str) -> str:
    """What makes two cards interchangeable as an action's source: the name
    and every public state that could change what the action does."""
    keys = ("name", "tapped", "sick", "damage", "counters", "attached", "power", "toughness",
            "attacking", "blocking", "keywords", "chosen", "controller")
    return json.dumps([zone] + [card.get(k) for k in keys], sort_keys=True, default=str)


def card_brief(card: dict, zone: str = "battlefield") -> dict:
    """One card, compact: id, name, type words, P/T for a creature, the
    flags that are set."""
    out: dict = {"id": card.get("id", ""), "name": card.get("name", "")}
    words = type_words(card)
    if words:
        out["type"] = " ".join(words)
    if _is_creature(card):
        out["pt"] = f"{card.get('power', 0)}/{card.get('toughness', 0)}"
    keywords = keyword_words(card)
    if keywords:
        out["keywords"] = keywords
    for flag in ("tapped", "sick", "attacking"):
        if card.get(flag):
            out[flag] = True
    for key in ("blocking", "attached", "damage", "counters", "chosen"):
        if card.get(key):
            out[key] = card[key]
    if zone == "phased_out":
        out["phased_out"] = True
    return out


# --- the observation ---------------------------------------------------------

def _side(view: dict, seat: int, rows: dict) -> dict:
    player = _player(view, seat)
    pres = (_presentation(view).get("players") or [{}, {}])
    pres_row = pres[seat] if 0 <= seat < len(pres) and isinstance(pres[seat], dict) else {}
    out: dict = {"life": player.get("life"), "hand": player.get("hand_count"),
                 "library": player.get("library_count"),
                 "battlefield": [card_brief(c) for c in player.get("battlefield") or [] if isinstance(c, dict)]}
    if player.get("phased_out"):
        out["phased_out"] = [card_brief(c, "phased_out") for c in player["phased_out"] if isinstance(c, dict)]
    if player.get("mana"):
        out["mana"] = player["mana"]
    if pres_row.get("poison"):
        out["poison"] = pres_row["poison"]
    for zone in ("graveyard", "exile", "revealed"):
        if player.get(zone):
            out[zone] = [c.get("name", "") if isinstance(c, dict) else str(c) for c in player[zone]]
    return out


def encode_observation(decision: dict, sub: dict | None = None, journal: list | None = None,
                       menu: list | None = None, features: bool = True) -> dict:
    """The decision as the deciding seat sees it — compact JSON (a tenth
    of the wire's view or less), and `features` (FEATURES, field by
    field) unless `features` is false."""
    view = _view(decision)
    seat = _seat(decision)
    rows = presentation_rows(view)
    active = view.get("active")
    sub = sub if isinstance(sub, dict) else None
    mode = "targets" if sub and sub.get("kind") == "targets" else mode_of(decision)
    if mode == "priority" and _options(decision).get("announcement") and not sub:
        mode = "targets"
    out: dict = {"mode": mode, "turn": view.get("turn", decision.get("turn")),
                 "step": view.get("step", decision.get("step")),
                 "active": "me" if active == seat else "opp", "seat": seat,
                 "me": _side(view, seat, rows), "opp": _side(view, 1 - seat, rows)}
    hand = []
    for card in view.get("hand") or []:
        if not isinstance(card, dict):
            continue
        row = rows.get(card.get("id"), {})
        brief = card_brief(card, "hand")
        cost = spell_cost(row)
        if cost:
            brief["cost"] = cost
        if row.get("castable") or card.get("playable"):
            brief["castable"] = True
        hand.append(brief)
    out["hand"] = hand
    stack = []
    for item in view.get("stack") or []:
        if isinstance(item, dict):
            entry = {"name": item.get("name", ""), "controller": "me" if item.get("controller") == seat else "opp"}
            if item.get("targets"):
                entry["targets"] = item["targets"]
            if item.get("x"):
                entry["x"] = item["x"]
            stack.append(entry)
    if stack:
        out["stack"] = stack
    prompt = _prompt(decision, sub)
    if prompt:
        out["prompt"] = prompt
    if sub:
        out["selection"] = _selection(sub)
    out["journal"] = [e.get("text", "") if isinstance(e, dict) else str(e) for e in (journal or [])]
    if features:
        out["features"] = feature_vector(decision, sub, menu)
    return out


def _selection(sub: dict) -> dict:
    """The sub-menu state as the model is shown it: what is picked so far."""
    out = {k: v for k, v in sub.items() if k in ("kind", "selected", "pairs", "picked", "slot", "card", "name")}
    if sub.get("kind") == "targets":
        out["picked"] = [{k: v for k, v in t.items() if k in ("id", "label", "slot")} for t in sub.get("picked") or []]
    return out


def _prompt(decision: dict, sub: dict | None) -> dict:
    options = _options(decision)
    view = _view(decision)
    mode = mode_of(decision)
    if sub and sub.get("kind") == "targets":
        slots = sub.get("slots") or []
        slot = slots[sub.get("slot", 0)] if sub.get("slot", 0) < len(slots) else {}
        return {"casting": sub.get("name", ""), "slot": slot.get("label", ""),
                "min": slot.get("min", 0), "max": slot.get("max", 0)}
    if mode == "choice":
        choice = options.get("choice") or {}
        return {k: choice.get(k) for k in ("prompt", "source", "options", "count") if choice.get(k) not in (None, "")}
    if mode == "discard":
        return {"discard": (options.get("discard") or {}).get("count", view.get("discard_count", 0))}
    if mode == "damage":
        return {"damage": (options.get("damage") or {}).get("request") or view.get("damage_request") or {}}
    if mode == "priority" and options.get("announcement"):
        return {"announcement": options["announcement"]}
    return {}


# FEATURES: the numeric vector, one row a field — (name, what it is). The
# order IS the vector's; `feature_vector` fills it, and the test pins the
# length to this table.
_SIDE_FEATURES = (
    ("life", "life / 20"),
    ("hand", "cards in hand / 7"),
    ("library", "cards in library / 60"),
    ("graveyard", "cards in graveyard / 30"),
    ("exile", "cards in exile / 30"),
    ("poison", "poison counters / 10"),
    ("mana_pool", "floating mana / 10"),
    ("lands", "lands on the battlefield / 10"),
    ("lands_untapped", "untapped lands / 10"),
    ("creatures", "creatures / 10"),
    ("creatures_ready", "untapped creatures without summoning sickness / 10"),
    ("power", "total creature power / 20"),
    ("toughness", "total creature toughness / 20"),
    ("flyers", "creatures with flying / 10"),
    ("other_permanents", "non-land, non-creature permanents / 10"),
    ("phased_out", "phased-out permanents / 10"),
    ("attacking", "attacking creatures / 10"),
    ("blocking", "blocking creatures / 10"),
)
FEATURES = (
    (("turn", "turn number / 30, capped at 1"),
     ("my_turn", "1 when the deciding seat is the active player")) +
    tuple((f"step_{s.lower()}", f"1 when the step is {s}") for s in STEPS) +
    tuple((f"mode_{m}", f"1 when the decision is {m}") for m in MODES) +
    tuple((f"me_{n}", d) for n, d in _SIDE_FEATURES) +
    tuple((f"opp_{n}", d) for n, d in _SIDE_FEATURES) +
    (("stack", "objects on the stack / 5"),
     ("stack_top_mine", "1 when the top of the stack is the deciding seat's"),
     ("stack_top_theirs", "1 when the top of the stack is the opponent's"),
     ("hand_castable", "castable cards in hand / 7"),
     ("hand_lands", "lands in hand / 7"),
     ("hand_mana_value", "mean mana value of the hand's non-land cards / 7"),
     ("menu_size", "menu items / 50, capped at 1"))
)
ITEM_FEATURES = (
    tuple((f"kind_{k}", f"1 when the item is {k}") for k in KINDS) +
    (("mana_value", "mana value of the card cast or the ability's mana cost / 10"),
     ("power", "the source card's power / 10 (0 if not a creature)"),
     ("toughness", "the source card's toughness / 10"),
     ("x", "the X chosen / 10"),
     ("target_opp_player", "1 when the item aims at the opponent"),
     ("target_my_player", "1 when the item aims at the deciding seat itself"),
     ("target_opp_card", "1 when the item aims at an opponent's card"),
     ("target_my_card", "1 when the item aims at the deciding seat's card"),
     ("target_power", "the targeted card's power / 10"),
     ("target_toughness", "the targeted card's toughness / 10"))
)


def _clip(value: float) -> float:
    return round(max(-1.0, min(1.0, value)), 4)


def _side_numbers(view: dict, seat: int) -> list[float]:
    player = _player(view, seat)
    pres = _presentation(view).get("players") or []
    pres_row = pres[seat] if 0 <= seat < len(pres) and isinstance(pres[seat], dict) else {}
    field = [c for c in player.get("battlefield") or [] if isinstance(c, dict)]
    lands = [c for c in field if _is_land(c)]
    creatures = [c for c in field if _is_creature(c)]
    others = [c for c in field if not _is_land(c) and not _is_creature(c)]
    num = lambda v: v if isinstance(v, (int, float)) and not isinstance(v, bool) else 0  # noqa: E731
    return [
        num(player.get("life")) / 20, num(player.get("hand_count")) / 7,
        num(player.get("library_count")) / 60, len(player.get("graveyard") or []) / 30,
        len(player.get("exile") or []) / 30, num(pres_row.get("poison")) / 10,
        num(player.get("mana")) / 10, len(lands) / 10,
        sum(1 for c in lands if not c.get("tapped")) / 10, len(creatures) / 10,
        sum(1 for c in creatures if not c.get("tapped") and not c.get("sick")) / 10,
        sum(num(c.get("power")) for c in creatures) / 20,
        sum(num(c.get("toughness")) for c in creatures) / 20,
        sum(1 for c in creatures if KW_FLYING in (c.get("keywords") or [])) / 10,
        len(others) / 10, len(player.get("phased_out") or []) / 10,
        sum(1 for c in creatures if c.get("attacking")) / 10,
        sum(1 for c in creatures if c.get("blocking")) / 10,
    ]


def feature_vector(decision: dict, sub: dict | None = None, menu: list | None = None) -> list[float]:
    """FEATURES, in order, as floats clipped to [-1, 1]."""
    view = _view(decision)
    seat = _seat(decision)
    rows = presentation_rows(view)
    turn = view.get("turn", decision.get("turn")) or 0
    step = str(view.get("step", decision.get("step")) or "")
    mode = "targets" if (sub and sub.get("kind") == "targets") or (
        mode_of(decision) == "priority" and _options(decision).get("announcement")) else mode_of(decision)
    out = [min(1.0, float(turn) / 30), 1.0 if view.get("active") == seat else 0.0]
    out += [1.0 if step == s else 0.0 for s in STEPS]
    out += [1.0 if mode == m else 0.0 for m in MODES]
    out += _side_numbers(view, seat)
    out += _side_numbers(view, 1 - seat)
    stack = [s for s in view.get("stack") or [] if isinstance(s, dict)]
    out += [len(stack) / 5, 1.0 if stack and stack[-1].get("controller") == seat else 0.0,
            1.0 if stack and stack[-1].get("controller") != seat else 0.0]
    hand = [c for c in view.get("hand") or [] if isinstance(c, dict)]
    spells = [c for c in hand if not _is_land(c)]
    values = [mana_value(spell_cost(rows.get(c.get("id")))) for c in spells]
    out += [sum(1 for c in hand if rows.get(c.get("id"), {}).get("castable") or c.get("playable")) / 7,
            sum(1 for c in hand if _is_land(c)) / 7,
            (sum(values) / len(values) / 7) if values else 0.0,
            min(1.0, len(menu or []) / 50)]
    return [_clip(v) for v in out]


def item_features(item: dict) -> list[float]:
    """ITEM_FEATURES, in order, for one menu item."""
    info = item.get("info") or {}
    kind = item.get("kind", "")
    out = [1.0 if kind == k else 0.0 for k in KINDS]
    target = info.get("target") or {}
    num = lambda v: v if isinstance(v, (int, float)) and not isinstance(v, bool) else 0  # noqa: E731
    out += [num(info.get("mv")) / 10, num(info.get("power")) / 10, num(info.get("toughness")) / 10,
            num(info.get("x")) / 10,
            1.0 if target.get("kind") == "player" and target.get("side") == "opp" else 0.0,
            1.0 if target.get("kind") == "player" and target.get("side") == "me" else 0.0,
            1.0 if target.get("kind") == "card" and target.get("side") == "opp" else 0.0,
            1.0 if target.get("kind") == "card" and target.get("side") == "me" else 0.0,
            num(target.get("power")) / 10, num(target.get("toughness")) / 10]
    return [_clip(v) for v in out]


# --- the menu ----------------------------------------------------------------

def fingerprint(decision: dict) -> str:
    """The decision's state without its counter and its news (n, the
    journal, the presentation's cues and events): two decisions with one
    fingerprint offer the same announcements, so a probe is reused."""
    view = dict(_view(decision))
    view.pop("journal", None)
    pres = dict(_presentation(view))
    for key in ("cues", "events"):
        pres.pop(key, None)
    view["presentation"] = pres
    body = {k: v for k, v in decision.items() if k not in ("n", "view", "type")}
    body["view"] = view
    return hashlib.sha1(json.dumps(body, sort_keys=True, default=str).encode("utf-8")).hexdigest()


def block_scope(decision: dict) -> tuple:
    """How long a refused action stays off the menu: this seat, turn, step
    and stack height — or, past them, as long as `board_signature` holds
    (a Zuran Orb with no land to sacrifice stays refused next turn too)."""
    view = _view(decision)
    return (_seat(decision), view.get("turn"), view.get("step"), len(view.get("stack") or []))


def board_signature(decision: dict) -> str:
    """The public board a refusal was read against: the step, the stack
    height, both battlefields (ids, tapped, counters), this seat's hand,
    graveyard size and life. A refused action is offered again once any of
    it moves."""
    view = _view(decision)
    seat = _seat(decision)
    sides = []
    for number in (seat, 1 - seat):
        player = _player(view, number)
        sides.append([[c.get("id"), bool(c.get("tapped")), c.get("counters"), c.get("attached")]
                      for c in player.get("battlefield") or [] if isinstance(c, dict)])
    me = _player(view, seat)
    body = [seat, view.get("step"), len(view.get("stack") or []), sides,
            [c.get("id") for c in view.get("hand") or [] if isinstance(c, dict)],
            len(me.get("graveyard") or []), me.get("life"), me.get("mana")]
    return hashlib.sha1(json.dumps(body, sort_keys=True, default=str).encode("utf-8")).hexdigest()


def _dedupe_key(index: dict, handle: str, extra: str) -> str:
    card, zone, _side_ = index.get(handle, ({}, "", ""))
    if zone == "hand":
        return json.dumps(["hand", card.get("name"), extra])
    return _signature(card, zone) + extra if card else handle + extra


def _casts(decision: dict, blocked: set | frozenset = frozenset()) -> list[dict]:
    """The priority decision's cast and ability actions, one row each
    (deduplicated, modes and X expanded): `{key, kind, card, name, index,
    mode, x, aims, label, mv}` with `key` the id's stem."""
    options = _options(decision)
    view = _view(decision)
    seat = _seat(decision)
    index = card_index(view, seat)
    rows = presentation_rows(view)
    prepare = options.get("prepare") or {}
    out: list[dict] = []
    seen: set = set()
    for kind, entries in (("spell", prepare.get("casts") or []), ("ability", prepare.get("abilities") or [])):
        for entry in entries:
            if not isinstance(entry, dict) or not entry.get("card"):
                continue
            handle = entry["card"]
            card = index.get(handle, ({}, "", ""))[0]
            rules = str(card.get("rules") or "")
            if kind == "spell":
                cost = spell_cost(rows.get(handle))
                has_x = bool(entry.get("x"))
                text = rules
            else:
                cost = str(entry.get("cost") or "")
                has_x = "{X}" in cost.upper()
                text = str(entry.get("label") or "")
            labels = list(entry.get("modes") or []) if kind == "spell" else []
            modes = usable_modes(entry, labels)
            open_rows = mode_rows(rows.get(handle)) if labels else {}
            ability_index = int(entry.get("index") or 0)
            for mode in modes:
                mode_row = open_rows.get(mode) or {}
                budget = int(mode_row.get("budget", entry.get("budget") or 0) or 0)
                mode_cost = str(mode_row.get("cost") or cost)
                for x in (x_values(budget) if has_x else [0]):
                    stem = (f"cast:{handle}" if kind == "spell" else f"act:{handle}:{ability_index}")
                    if labels:
                        stem += f":m{mode}"
                    if has_x:
                        stem += f":x{x}"
                    dedupe = _dedupe_key(index, handle, f"|{kind}|{ability_index}|{mode}|{x}")
                    if dedupe in seen or stem in blocked:
                        continue
                    seen.add(dedupe)
                    name = entry.get("name") or card.get("name") or handle
                    if kind == "spell":
                        label = f"Cast {name}"
                    else:
                        label = f"{name}: {entry.get('label', 'ability')}"
                    if labels:
                        label += f" — {labels[mode]}"
                    if has_x:
                        label += f" (X={x})"
                    out.append({"key": stem, "kind": kind, "card": handle, "name": name,
                                "index": ability_index, "mode": mode, "x": x, "has_x": has_x,
                                "aims": bool(AIMS.search(text)) or kind == "ability",
                                "label": label, "mv": mana_value(mode_cost) + x, "text": text,
                                "power": card.get("power") if _is_creature(card) else None,
                                "toughness": card.get("toughness") if _is_creature(card) else None,
                                "type": " ".join(type_words(card))})
    return out


def usable_modes(entry: dict, labels: list) -> list[int]:
    """The modes a cast entry may be cast in now: the referee's
    `usable_modes` (the mode indices whose payment the seat can make —
    Fireblast's "sacrifice two Mountains" only with two Mountains), every
    labelled mode from a referee that does not send the key, [0] for a
    spell without modes. The ids keep the mode's own index."""
    if not labels:
        return [0]
    every = list(range(len(labels)))
    usable = entry.get("usable_modes")
    if not isinstance(usable, list):
        return every
    allowed = {int(m) for m in usable if isinstance(m, int) and not isinstance(m, bool)}
    return [m for m in every if m in allowed]


def mode_rows(row: dict | None) -> dict:
    """A modal spell's open modes as its presentation row lists them: the
    spell rows after the first (the printed cost), by `index` — the mode —
    each with its `cost` and X `budget`; {} from an older referee."""
    spells = [a for a in (row or {}).get("abilities") or [] if isinstance(a, dict) and a.get("kind") == "spell"]
    return {option["index"]: option for option in spells[1:] if isinstance(option.get("index"), int)}


def x_values(budget: int) -> list[int]:
    """The X values offered for a budget: 0 when nothing more is
    affordable, else 1..budget — spread over MAX_X_CHOICES values,
    always the largest — when there are more."""
    if budget <= 0:
        return [0]
    if budget <= MAX_X_CHOICES:
        return list(range(1, budget + 1))
    step = (budget - 1) / (MAX_X_CHOICES - 1)
    values = sorted({1 + round(i * step) for i in range(MAX_X_CHOICES)} | {budget})
    return values


def prepare_action(row: dict) -> dict:
    return {"op": "prepare", "card": row["card"], "kind": row["kind"], "index": row["index"],
            "x": row["x"], "mode": row["mode"]}


def probe_actions(decision: dict, blocked: set | frozenset = frozenset()) -> list[dict]:
    """The `prepare` actions whose announcements the flat menu reads — one
    per cast or ability that may have targets (or whose payment the menu
    must check), X spells excepted (their targets are a sub-menu). The
    caller sends each, records the decision that answers it (`announcement`,
    `draft.reachable`, `presentation.targets`) under the row's `key`, and
    cancels; `build_menu(..., probes=...)` reads the records."""
    if mode_of(decision) != "priority" or _options(decision).get("announcement") \
            or "pass" not in _options(decision):
        return []
    return [{"key": row["key"], "action": prepare_action(row)}
            for row in _casts(decision, blocked) if row["aims"] and not row["has_x"]]


def probe_record(answer: dict | None, refusal: str = "") -> dict:
    """What a probe learned from the decision that answered its prepare."""
    if refusal or not isinstance(answer, dict):
        return {"refused": refusal or "no answer"}
    options = _options(answer)
    view = _view(answer)
    draft = options.get("draft") or _presentation(view).get("draft") or {}
    return {"announcement": options.get("announcement") or {},
            "reachable": bool(draft.get("reachable", True)),
            "targets": list(_presentation(view).get("targets") or [])}


def _ref_of(token: str, refs: list) -> dict:
    for row in refs or []:
        if isinstance(row, dict) and row.get("token") == token:
            ref = row.get("ref")
            return ref if isinstance(ref, dict) else {}
    return {}


def _ref_key(ref) -> tuple:
    ref = ref if isinstance(ref, dict) else {}
    return (str(ref.get("kind") or ""), str(ref.get("id") or ""))


def target_info(token: str, label: str, refs: list, view: dict, seat: int) -> dict:
    """One announced candidate as the menu names it: `id` (`opp`, `you`, a
    card handle, or `<kind><id>`), `kind`, `side`, the label, the token it
    had when it was read, and a card's power/toughness."""
    ref = _ref_of(token, refs)
    kind = str(ref.get("kind") or "")
    raw = str(ref.get("id") or "")
    out: dict = {"token": token, "label": label, "ref": ref}
    if kind == "player":
        mine = raw == str(seat)
        out.update({"id": "you" if mine else "opp", "kind": "player", "side": "me" if mine else "opp"})
    elif kind == "card" and raw:
        card, zone, side = card_index(view, seat).get(raw, ({}, "", ""))
        out.update({"id": raw, "kind": "card", "side": side or ("me" if "yours" in label else "opp")})
        if card and _is_creature(card):
            out["power"] = card.get("power")
            out["toughness"] = card.get("toughness")
        if zone:
            out["zone"] = zone
    elif kind:
        out.update({"id": f"{kind}{raw}", "kind": kind, "side": "opp" if "opponent" in label.lower() else "me"})
    else:
        out.update({"id": token, "kind": "", "side": ""})
    return out


def _flat_targets(announcement: dict, refs: list, view: dict, seat: int):
    """The flat target lists of an announcement: a list of target lists
    (each one complete submit), [] when nothing legal, None when the
    announcement needs the sub-menu."""
    slots = [s for s in announcement.get("slots") or [] if isinstance(s, dict)]
    if not slots:
        return [[]]
    for slot in slots:
        if len(slot.get("targets") or []) < int(slot.get("min", 0)):
            return []
    if len(slots) == 1 and int(slots[0].get("max", 1)) == 1:
        slot = slots[0]
        candidates = slot.get("targets") or []
        if len(candidates) > MAX_FLAT_TARGETS:
            return None
        divided = int(slot.get("divided", 0))
        out = []
        if int(slot.get("min", 0)) == 0:
            out.append([])
        for target in candidates:
            info = target_info(str(target.get("id")), str(target.get("label", "")), refs, view, seat)
            info["amount"] = divided
            info["slot"] = 0
            out.append([info])
        return out
    # Every slot fully forced (min == max == its candidate count): one list.
    forced = []
    for number, slot in enumerate(slots):
        candidates = slot.get("targets") or []
        if not (int(slot.get("min", 0)) == int(slot.get("max", -1)) == len(candidates)):
            return None
        amounts = split(int(slot.get("divided", 0)), len(candidates))
        for target, amount in zip(candidates, amounts):
            info = target_info(str(target.get("id")), str(target.get("label", "")), refs, view, seat)
            info.update({"amount": amount, "slot": number})
            forced.append(info)
    return [forced]


def split(total: int, count: int) -> list[int]:
    """`total` divided over `count` targets, evenly, the remainder to the
    first ones (a slot that divides nothing gives every target 0)."""
    if count <= 0:
        return []
    if total <= 0:
        return [0] * count
    base, rest = divmod(total, count)
    return [base + (1 if i < rest else 0) for i in range(count)]


def _item(ident: str, label: str, kind: str, plan: dict, info: dict | None = None,
          ops: list | None = None) -> dict:
    item = {"id": ident, "label": label, "kind": kind, "plan": plan, "info": info or {}}
    item["ops"] = ops if ops is not None else list(plan.get("send") or [])
    return item


def _target_suffix(targets: list) -> str:
    return "" if not targets else "->" + "+".join(t["id"] for t in targets)


def _target_label(targets: list) -> str:
    if not targets:
        return ""
    return " → " + ", ".join(t["label"] + (f" ({t['amount']})" if t.get("amount") and len(targets) > 1 else "")
                             for t in targets)


def _cast_ops(row: dict, targets: list | None) -> list:
    count = max(1, len(targets or []))
    ops = [prepare_action(row), {"op": "autopay", "excluded": [], "count": count}]
    if targets is not None:
        ops.append({"op": "submit", "targets": [[t["token"], t.get("amount", 0)] for t in targets]})
    return ops


def priority_items(decision: dict, probes: dict | None, blocked) -> list[dict]:
    options = _options(decision)
    view = _view(decision)
    seat = _seat(decision)
    index = card_index(view, seat)
    items = [_item("pass", "Pass priority", "pass", {"send": [{"op": "pass"}]})]
    seen = set()
    for land in (options.get("play") or {}).get("lands") or []:
        if not isinstance(land, dict) or not land.get("card"):
            continue
        ident = f"play:{land['card']}"
        dedupe = _dedupe_key(index, land["card"], "|play")
        if dedupe in seen:
            continue
        seen.add(dedupe)
        items.append(_item(ident, f"Play {land.get('name', land['card'])}", "play",
                           {"send": [{"op": "play", "card": land["card"]}]},
                           {"card": land["card"], "name": land.get("name", "")}))
    for row in _casts(decision, blocked):
        info = {"card": row["card"], "name": row["name"], "mv": row["mv"], "kind": row["kind"],
                "type": row["type"], "text": row["text"], "power": row["power"], "toughness": row["toughness"]}
        if row["has_x"]:
            info["x"] = row["x"]
        if row["mode"] or row["key"].count(":m"):
            info["mode"] = row["mode"]
        kind = "cast" if row["kind"] == "spell" else "act"
        record = (probes or {}).get(row["key"]) if row["aims"] and not row["has_x"] else None
        if row["aims"] and not row["has_x"] and probes is not None and record is None:
            continue   # not probed (dropped by the caller): offered when it is
        if record is not None:
            if record.get("refused") or not record.get("reachable", True):
                continue
            lists = _flat_targets(record.get("announcement") or {}, record.get("targets") or [], view, seat)
        elif row["aims"] or row["has_x"]:
            lists = None
        else:
            lists = [[]]
        plan_base = {"cast": prepare_action(row), "key": row["key"], "name": row["name"], "text": row["text"],
                     "mv": row["mv"]}
        if lists is None:
            items.append(_item(row["key"], row["label"] + " (choose targets)" if row["aims"] else row["label"],
                               kind, {**plan_base, "targets": None}, info, _cast_ops(row, None)))
            continue
        for targets in lists:
            ident = row["key"] + _target_suffix(targets)
            item_info = dict(info)
            if targets:
                item_info["target"] = {k: v for k, v in targets[0].items() if k not in ("ref", "token")}
                if len(targets) > 1:
                    item_info["targets"] = [{k: v for k, v in t.items() if k not in ("ref", "token")} for t in targets]
            items.append(_item(ident, row["label"] + _target_label(targets), kind,
                               {**plan_base, "targets": targets}, item_info, _cast_ops(row, targets)))
    for special in (options.get("special") or {}).get("specials") or []:
        if not isinstance(special, dict):
            continue
        ident = f"special:{special.get('index', 0)}"
        items.append(_item(ident, str(special.get("label", "special action")), "special",
                           {"send": [{"op": "special", "index": int(special.get("index", 0))}]}))
    return items


def targets_sub(decision: dict, plan: dict | None = None) -> dict:
    """A fresh target sub-menu over the decision's open announcement."""
    options = _options(decision)
    view = _view(decision)
    announcement = options.get("announcement") or {}
    draft = options.get("draft") or _presentation(view).get("draft") or {}
    text = (plan or {}).get("text")
    if text is None:
        card = card_index(view, _seat(decision)).get(draft.get("card"), ({}, "", ""))[0]
        text = str(card.get("rules") or "")
    return {"kind": "targets", "n": decision.get("n"), "card": draft.get("card"),
            "name": announcement.get("name", ""), "slot": 0, "picked": [],
            "slots": [s for s in announcement.get("slots") or [] if isinstance(s, dict)],
            "key": (plan or {}).get("key", f"draft:{draft.get('card')}"), "text": text}


def target_items(decision: dict, sub: dict) -> list[dict]:
    """The target sub-menu: candidates of the slot being filled, the stop
    when the slot has enough, cancel last."""
    view = _view(decision)
    seat = _seat(decision)
    refs = list(_presentation(view).get("targets") or [])
    slots = sub.get("slots") or []
    picked = [dict(p) for p in sub.get("picked") or []]
    number = int(sub.get("slot", 0))
    cancel = _item("cancel", f"Cancel {sub.get('name', 'the cast')}", "cancel", {"cancel": True},
                   ops=[{"op": "cancel"}])
    if number >= len(slots):
        return [_item("target:done", "Cast it", "target", {"final": picked}), cancel]
    slot = slots[number]
    mine = [t for t in picked if t.get("slot") == number]
    taken = {t["token"] for t in mine}
    if DISTINCT.search(str(slot.get("label", ""))):
        # "another target", "a third target" (Cone of Flame): the referee
        # filters a slot's candidates alone, not against its siblings, so
        # what an earlier slot named is left out here (CR 115.3: one object
        # may be several targets unless the text says otherwise).
        earlier = {_ref_key(t.get("ref")) for t in picked if t.get("ref")}
        taken |= {str(c.get("id")) for c in slot.get("targets") or []
                  if _ref_key(_ref_of(str(c.get("id")), refs)) in earlier}
    minimum = int(slot.get("min", 0))
    maximum = int(slot.get("max", 1))
    if maximum < 0:
        maximum = len(slot.get("targets") or [])
    if int(slot.get("divided", 0)) > 0:
        maximum = min(maximum, int(slot["divided"]))   # each target is dealt at least 1
    items = []
    if len(mine) >= minimum:
        stop = "target:none" if not mine else "target:done"
        label = (f"No target for {slot.get('label', 'this slot')}" if not mine else
                 f"Done choosing {slot.get('label', 'targets')}")
        items.append(_finish_item(stop, label, sub, picked, number))
    for target in slot.get("targets") or []:
        token = str(target.get("id"))
        if token in taken:
            continue
        info = target_info(token, str(target.get("label", "")), refs, view, seat)
        info["slot"] = number
        chosen = picked + [info]
        ident = f"target:{info['id']}"
        brief = {k: v for k, v in info.items() if k not in ("ref", "token")}
        if len(mine) + 1 >= maximum:
            item = _finish_item(ident, f"Target {info['label']}", sub, chosen, number)
        else:
            item = _item(ident, f"Target {info['label']}", "target",
                         {"sub": {**sub, "picked": chosen}}, {"target": brief})
        item["info"]["target"] = brief
        item["info"]["text"] = sub.get("text", "")
        items.append(item)
    items.append(cancel)
    return items


def _finish_item(ident: str, label: str, sub: dict, picked: list, number: int) -> dict:
    """The pick that completes slot `number`: the next slot's sub-menu, or
    — after the last slot — the cast itself, divided amounts split."""
    slots = sub.get("slots") or []
    if number + 1 < len(slots):
        return _item(ident, label, "target", {"sub": {**sub, "picked": picked, "slot": number + 1}})
    final = []
    for slot_number, slot in enumerate(slots):
        group = [dict(t) for t in picked if t.get("slot") == slot_number]
        for target, amount in zip(group, split(int(slot.get("divided", 0)), len(group))):
            target["amount"] = amount
            final.append(target)
    return _item(ident, label, "target", {"final": final},
                 ops=[{"op": "autopay", "excluded": [], "count": max(1, len(final))},
                      {"op": "submit", "targets": [[t["token"], t.get("amount", 0)] for t in final]}])


def _attackable(decision: dict) -> list[dict]:
    return [c for c in ((_options(decision).get("attack") or {}).get("attackable") or [])
            if isinstance(c, dict) and c.get("card")]


def must_attack(decision: dict) -> list[str]:
    """Attackable creatures that attack each combat if able (the keyword,
    or the presentation's must-attack-this-turn flag)."""
    view = _view(decision)
    index = card_index(view, _seat(decision))
    rows = presentation_rows(view)
    out = []
    for entry in _attackable(decision):
        card = index.get(entry["card"], ({}, "", ""))[0]
        flags = (rows.get(entry["card"]) or {}).get("flags") or {}
        if KW_MUST_ATTACK in (card.get("keywords") or []) or flags.get("must_attack_this_turn"):
            out.append(entry["card"])
    return out


def attack_items(decision: dict, sub: dict | None, blocked) -> list[dict]:
    view = _view(decision)
    index = card_index(view, _seat(decision))
    attackable = _attackable(decision)
    required = must_attack(decision)
    selected = list((sub or {}).get("selected") or required)
    everyone = [c["card"] for c in attackable]
    names = {c["card"]: c.get("name", c["card"]) for c in attackable}
    items = []
    declare = {"send": [{"op": "attack", "cards": selected}]}
    if not selected:
        items.append(_item("attack:none", "No attack", "attack_none", declare))
    else:
        items.append(_item("attack:declare", "Attack with " + ", ".join(names.get(c, c) for c in selected),
                           "attack_declare", declare, {"cards": selected}))
    if len(everyone) > 1 and set(selected) != set(everyone) and not (sub or {}).get("selected"):
        items.append(_item("attack:all", f"Attack with all {len(everyone)}", "attack_all",
                           {"send": [{"op": "attack", "cards": everyone}]}, {"cards": everyone}))
    for handle in everyone:
        if handle in selected:
            continue
        card = index.get(handle, ({}, "", ""))[0]
        pt = f" ({card.get('power', 0)}/{card.get('toughness', 0)})" if card else ""
        items.append(_item(f"attack:add:{handle}", f"Add attacker {names[handle]}{pt}", "attack_add",
                           {"sub": {"kind": "attack", "n": decision.get("n"), "selected": selected + [handle]}},
                           {"card": handle, "name": names[handle], "power": card.get("power"),
                            "toughness": card.get("toughness")}))
    return items


def blocked_key(item: dict) -> str:
    """The key a refused item is kept off the menu by: a cast's id stem
    (every target of a refused cast goes), else the id plus the exact
    answer it sends (another attack set is another answer)."""
    plan = item.get("plan") or {}
    if plan.get("key"):
        return plan["key"]
    if plan.get("send"):
        return item["id"] + "|" + json.dumps(plan["send"], sort_keys=True)
    return item["id"]


def block_items(decision: dict, sub: dict | None, blocked) -> list[dict]:
    view = _view(decision)
    index = card_index(view, _seat(decision))
    rows = [r for r in ((_options(decision).get("block") or {}).get("blockable") or [])
            if isinstance(r, dict) and r.get("blocker")]
    pairs = [list(p) for p in (sub or {}).get("pairs") or []]
    used = {p[0] for p in pairs}
    items = []
    declare = {"send": [{"op": "block", "pairs": pairs}]}
    if not pairs:
        items.append(_item("block:none", "No blocks", "block_none", declare))
    else:
        label = ", ".join(f"{_name(index, b)} blocks {_name(index, a)}" for b, a in pairs)
        items.append(_item("block:declare", "Declare blocks: " + label, "block_declare", declare,
                           {"pairs": pairs}))
    for row in rows:
        blocker = row["blocker"]
        if blocker in used:
            continue
        bcard = index.get(blocker, ({}, "", ""))[0]
        for attacker in row.get("attackers") or []:
            handle = attacker.get("card") if isinstance(attacker, dict) else attacker
            if not handle:
                continue
            acard = index.get(handle, ({}, "", ""))[0]
            items.append(_item(f"block:{blocker}->{handle}",
                               f"{row.get('name', blocker)} ({bcard.get('power', 0)}/{bcard.get('toughness', 0)}) "
                               f"blocks {_name(index, handle)} ({acard.get('power', 0)}/{acard.get('toughness', 0)})",
                               "block_pair",
                               {"sub": {"kind": "block", "n": decision.get("n"), "pairs": pairs + [[blocker, handle]]}},
                               {"card": blocker, "power": bcard.get("power"), "toughness": bcard.get("toughness"),
                                "target": {"kind": "card", "side": "opp", "id": handle,
                                           "power": acard.get("power"), "toughness": acard.get("toughness")}}))
    return items


def _name(index: dict, handle: str) -> str:
    card = index.get(handle, ({}, "", ""))[0]
    return str(card.get("name") or handle)


def discard_items(decision: dict, sub: dict | None, blocked) -> list[dict]:
    want = _options(decision).get("discard") or {}
    count = int(want.get("count", 0) or 0)
    hand = [c for c in want.get("hand") or [] if isinstance(c, dict) and c.get("card")]
    picked = list((sub or {}).get("picked") or [])
    index = card_index(_view(decision), _seat(decision))
    rows = presentation_rows(_view(decision))
    items = []
    seen = set()
    for entry in hand:
        handle = entry["card"]
        if handle in picked:
            continue
        dedupe = _dedupe_key(index, handle, "|discard")
        if dedupe in seen:
            continue
        seen.add(dedupe)
        chosen = picked + [handle]
        card = index.get(handle, ({}, "", ""))[0]
        info = {"card": handle, "name": entry.get("name", ""), "mv": mana_value(spell_cost(rows.get(handle))),
                "land": _is_land(card)}
        if len(chosen) >= count:
            items.append(_item(f"discard:{handle}", f"Discard {entry.get('name', handle)}", "discard",
                               {"send": [{"op": "discard", "cards": chosen}]}, info))
        else:
            items.append(_item(f"discard:{handle}", f"Discard {entry.get('name', handle)} "
                               f"({len(chosen)} of {count})", "discard",
                               {"sub": {"kind": "discard", "n": decision.get("n"), "picked": chosen}}, info))
    if count <= 0:
        items = [_item("discard:none", "Discard nothing", "discard", {"send": [{"op": "discard", "cards": []}]})]
    return items


def damage_items(decision: dict, blocked) -> list[dict]:
    view = _view(decision)
    request = (_options(decision).get("damage") or {}).get("request") or view.get("damage_request") or {}
    amount = int(request.get("amount", 0) or 0)
    targets = [t for t in request.get("targets") or [] if isinstance(t, dict) and t.get("id")]
    free = bool((_presentation(view).get("rules") or {}).get("free_damage_assignment", False))
    items = []
    if not targets:
        return [_item("damage:none", "Assign no damage", "damage", {"send": [{"op": "damage", "points": []}]})]

    def upto(stop: int) -> list:
        left = amount
        points = []
        for i, target in enumerate(targets[:stop + 1]):
            share = left if i == stop else min(left, int(target.get("lethal", left) or 0))
            if share > 0:
                points.append([target["id"], share])
                left -= share
        return points

    last = len(targets) - 1
    items.append(_item("damage:ordered", f"Assign {amount} in order: lethal to each, the rest to "
                       f"{targets[last].get('name', targets[last]['id'])}", "damage",
                       {"send": [{"op": "damage", "points": upto(last)}]}))
    for i, target in enumerate(targets[:-1]):
        items.append(_item(f"damage:upto:{target['id']}", f"Lethal to those before "
                           f"{target.get('name', target['id'])}, the rest to it", "damage",
                           {"send": [{"op": "damage", "points": upto(i)}]}))
    if free and len(targets) > 1:
        for target in targets:
            items.append(_item(f"damage:all:{target['id']}", f"All {amount} to {target.get('name', target['id'])}",
                               "damage", {"send": [{"op": "damage", "points": [[target["id"], amount]]}]}))
    unique = []
    seen = set()
    for item in items:
        key = json.dumps(item["plan"]["send"], sort_keys=True)
        if key in seen:
            continue
        seen.add(key)
        unique.append(item)
    return unique


def choice_items(decision: dict, sub: dict | None, blocked) -> list[dict]:
    options = _options(decision)
    choice = options.get("choice") or {}
    labels = list(choice.get("options") or [])
    raw = choice.get("count", 1)
    count = int(raw) if isinstance(raw, int) and not isinstance(raw, bool) else 1
    picked = list((sub or {}).get("picked") or [])
    items = []
    if count <= 0 or not labels:
        # A question that takes no pick (a discard of nothing): the answer is [].
        items.append(_item("choice:none", "Choose nothing (there is nothing to choose)", "choice",
                           {"send": [{"op": "choice", "picks": []}]}))
    for i, label in enumerate(labels if count > 0 else []):
        if i in picked:
            continue
        chosen = picked + [i]
        if len(chosen) >= min(count, len(labels)):
            items.append(_item(f"choice:{i}", str(label), "choice", {"send": [{"op": "choice", "picks": chosen}]},
                               {"index": i}))
        else:
            items.append(_item(f"choice:{i}", f"{label} ({len(chosen)} of {count})", "choice",
                               {"sub": {"kind": "choice", "n": decision.get("n"), "picked": chosen}}, {"index": i}))
    if "cancel" in options:
        items.append(_item("choice:cancel", "Withdraw (cancel the cost)", "cancel", {"send": [{"op": "cancel"}]}))
    return items


def opening_items(decision: dict, blocked) -> list[dict]:
    options = _options(decision)
    if "order" in options:
        items = [_item("order:play", "Play first", "order", {"send": [{"op": "order", "play": True}]}),
                 _item("order:draw", "Draw first", "order", {"send": [{"op": "order", "play": False}]})]
    else:
        items = [_item("keep", "Keep this hand", "keep", {"send": [{"op": "keep"}]})]
        if "mulligan" in options:
            items.append(_item("mulligan", f"Mulligan (hand of {(options.get('mulligan') or {}).get('hand', '?')})",
                               "mulligan", {"send": [{"op": "mulligan"}]}))
    return items


def build_menu(decision: dict, sub: dict | None = None, probes: dict | None = None,
               blocked: set | frozenset = frozenset()) -> list[dict]:
    """The menu of complete legal answers to `decision`.

    `sub` is the sub-menu state the last pick left (an attack selection,
    block pairs, discard or choice picks, target picks) — ignored when it
    belongs to another decision. `probes` maps a cast row's key to
    `probe_record(...)` (None: nothing was probed, every aimed cast
    becomes a target sub-menu after it is prepared). `blocked` holds the
    ids (and declare keys) the referee refused in this scope. Each item:
    `id`, `label`, `kind`, `info` (card, name, mana value, P/T, target),
    `ops` (the op sequence it expands to) and `plan` (what `Driver`
    executes)."""
    if not isinstance(decision, dict) or decision.get("type", "decision") != "decision":
        return []
    options = _options(decision)
    if options.get("waiting"):
        return []
    mode = mode_of(decision)
    kind = (sub or {}).get("kind")
    if kind == "targets":
        draft = options.get("draft") or _presentation(_view(decision)).get("draft") or {}
        if not options.get("announcement") or sub.get("card") != draft.get("card"):
            sub = None
    elif sub is not None and sub.get("n") != decision.get("n"):
        sub = None
    kind = (sub or {}).get("kind")
    if mode == "priority" and options.get("announcement"):
        items = target_items(decision, sub if kind == "targets" else targets_sub(decision))
    elif mode == "priority":
        items = priority_items(decision, probes, blocked)
    elif mode == "attack":
        items = attack_items(decision, sub if kind == "attack" else None, blocked)
    elif mode == "block":
        items = block_items(decision, sub if kind == "block" else None, blocked)
    elif mode == "discard":
        items = discard_items(decision, sub if kind == "discard" else None, blocked)
    elif mode == "damage":
        items = damage_items(decision, blocked)
    elif mode == "choice":
        items = choice_items(decision, sub if kind == "choice" else None, blocked)
    elif mode == "opening":
        items = opening_items(decision, blocked)
    else:
        items = []
    return [item for item in items if blocked_key(item) not in blocked]


def public_menu(menu: list, rich: bool = False) -> list[dict]:
    """The menu as a model is shown it: `id` and `label` (with `rich`, the
    `kind`, `info` and `ops` too)."""
    out = []
    for item in menu:
        row = {"id": item["id"], "label": item["label"]}
        if rich:
            row["kind"] = item.get("kind")
            row["info"] = item.get("info") or {}
            row["ops"] = item.get("ops") or []
        out.append(row)
    return out


def resolve_pick(menu: list, pick) -> dict:
    """The item a model's answer names: an index (int or digit string), an
    id, or `{"pick": index-or-id}`. ValueError says why not."""
    if isinstance(pick, dict):
        if "pick" not in pick:
            raise ValueError("an object answer is {\"pick\": INDEX or ID}")
        pick = pick["pick"]
    if isinstance(pick, bool):
        raise ValueError("a pick is an index or an id, not a boolean")
    if isinstance(pick, str) and re.fullmatch(r"\s*-?\d+\s*", pick):
        pick = int(pick)
    if isinstance(pick, int):
        if 0 <= pick < len(menu):
            return menu[pick]
        raise ValueError(f"pick {pick} is not on the menu (0..{len(menu) - 1})")
    if isinstance(pick, str):
        for item in menu:
            if item["id"] == pick.strip():
                return item
        raise ValueError(f"no menu item has the id '{pick}'")
    raise ValueError("a pick is an index, an id, or {\"pick\": ...}")


def fallback_action(decision: dict) -> dict:
    """The quiet answer when no menu item is left (every one refused):
    cancel or pass, attack and block nothing, the first choice, the first
    cards to discard, damage in order."""
    options = _options(decision)
    mode = mode_of(decision)
    if mode == "priority":
        return {"op": "cancel"} if options.get("announcement") else {"op": "pass"}
    if mode == "attack":
        return {"op": "attack", "cards": must_attack(decision)}
    if mode == "block":
        return {"op": "block", "pairs": []}
    if mode == "choice":
        choice = options.get("choice") or {}
        count = choice.get("count", 1) if isinstance(choice.get("count", 1), int) else 1
        return {"op": "choice", "picks": list(range(min(count, len(choice.get("options") or []))))}
    if mode == "discard":
        want = options.get("discard") or {}
        hand = [c["card"] for c in want.get("hand") or [] if isinstance(c, dict) and c.get("card")]
        return {"op": "discard", "cards": hand[:int(want.get("count", 0) or 0)]}
    if mode == "damage":
        items = damage_items(decision, frozenset())
        return items[0]["plan"]["send"][0]
    if mode == "opening":
        return {"op": "keep"}
    return {"op": "concede"}


# --- the driver: a menu pick to the wire and back ------------------------------


class DriverError(RuntimeError):
    """The referee answered in a way the Driver cannot go on from (a
    probe's cancel refused with the announcement still open)."""


class Driver:
    """Plays decisions through `send(action)` and `receive()`.

    `receive()` returns the referee's next record — a `hello`, `decision`,
    `refused` or `result` line as a dict, `{"error": ...}`, or None when
    the line closed. The Driver probes casts (`probe`), keeps the
    sub-menu state, executes a pick's ops with the guard, answers a
    decision whose menu has one item by itself (`skip_forced`) and keeps
    the journal of every decision it read for the next observation.
    `seats` limits the decisions it settles (None: every seat on the
    pipe — both, when a program plays itself)."""

    def __init__(self, send, receive, probe: bool = True, skip_forced: bool = True,
                 features: bool = True, seats=None):
        self._send = send
        self._receive = receive
        self.probe = probe
        self.skip_forced = skip_forced
        self.features = features
        self.seats = None if seats is None else set(seats)
        self.hello: dict | None = None
        self.decision: dict | None = None
        self.result: dict | None = None
        self.error: dict | None = None
        self.sub: dict | None = None
        self.plan: dict | None = None
        self.blocked: dict = {}
        self.journal: list = []
        self.refused: list = []
        self._menu: list | None = None
        self._probes: dict = {}
        self.stats = {"decisions": 0, "forced": 0, "wire_decisions": 0, "refusals": 0,
                      "probes": 0, "probe_hits": 0, "sent": 0}

    # ----- the wire -----

    def send(self, action: dict) -> None:
        action = dict(action)
        if self.decision is not None:
            action.setdefault("seat", self.decision.get("seat"))
        self.stats["sent"] += 1
        self._send(action)

    def advance(self) -> list:
        """Read until a decision, a result or an error; returns the
        refusals read on the way. Each decision's journal is kept."""
        refusals = []
        self._menu = None
        while True:
            record = self._receive()
            if record is None:
                if self.result is None and self.error is None:
                    self.error = {"kind": "eof", "message": "the referee closed the line without a result"}
                self.decision = None
                return refusals
            if not isinstance(record, dict):
                continue
            if "error" in record and record.get("type") is None:
                error = record["error"]
                self.error = error if isinstance(error, dict) else {"message": str(error)}
                self.decision = None
                return refusals
            kind = record.get("type")
            if kind == "hello":
                self.hello = record
            elif kind == "refused":
                refusals.append(record)
                self.refused.append(record)
                self.stats["refusals"] += 1
            elif kind == "decision":
                self.stats["wire_decisions"] += 1
                self.journal += list(_view(record).get("journal") or [])
                self.decision = record
                return refusals
            elif kind == "result":
                self.result = record
                self.decision = None
                return refusals

    def start(self) -> None:
        """Read the hello and on to the first decision the model faces."""
        self.advance()
        self._settle()

    @property
    def done(self) -> bool:
        return self.result is not None or self.error is not None

    # ----- what the model sees -----

    def _blocked_now(self) -> set:
        if self.decision is None:
            return set()
        return (self.blocked.get(block_scope(self.decision), set())
                | self.blocked.get(board_signature(self.decision), set()))

    def _block(self, key: str, decision: dict | None = None) -> None:
        decision = decision or self.decision
        if decision is not None:
            if len(self.blocked) > 512:
                self.blocked = {}
            for scope in (block_scope(decision), board_signature(decision)):
                self.blocked.setdefault(scope, set()).add(key)
        self._menu = None

    def menu(self) -> list:
        """The current decision's menu (probing the casts first when
        `probe` is on); [] once the game is over."""
        if self.decision is None or self.done:
            return []
        if self._menu is not None:
            return self._menu
        probes = None
        if self.probe:
            probes = self._run_probes()
            if self.decision is None:
                return []
        self._menu = build_menu(self.decision, self.sub, probes, self._blocked_now())
        return self._menu

    def observe(self) -> dict:
        if self.decision is None:
            out: dict = {"mode": "finished" if self.done else "waiting",
                         "journal": [e.get("text", "") if isinstance(e, dict) else str(e) for e in self.journal]}
            if self.result is not None:
                out["result"] = self.result
            if self.error is not None:
                out["error"] = self.error
            return out
        menu = self.menu()
        if self.decision is None:
            return self.observe()
        return encode_observation(self.decision, self.sub, self.journal, menu, self.features)

    def _run_probes(self) -> dict:
        """Prepare, read and cancel each aimed cast of the decision, once
        per state (`fingerprint`): the announcements the flat menu reads."""
        decision = self.decision
        requests = probe_actions(decision, self._blocked_now())
        if not requests:
            return {}
        base = fingerprint(decision)
        out = {}
        for request in requests:
            cached = self._probes.get((base, request["key"]))
            if cached is not None:
                self.stats["probe_hits"] += 1
                out[request["key"]] = cached
                continue
            self.stats["probes"] += 1
            refusals = self._send_one(request["action"])
            if self.decision is None:
                return out
            if refusals or not _options(self.decision).get("announcement"):
                reason = refusals[-1].get("reason", "refused") if refusals else "no announcement opened"
                record = probe_record(None, str(reason))
                self._block(request["key"], decision)
                if _options(self.decision).get("announcement"):
                    self._send_one({"op": "cancel"})
            else:
                record = probe_record(self.decision)
                if self._send_one({"op": "cancel"}) and self.decision is not None \
                        and _options(self.decision).get("announcement"):
                    raise DriverError("a probe's cancel was refused; the announcement is still open")
            if self.decision is None:
                return out
            self._probes[(base, request["key"])] = record
            out[request["key"]] = record
        if len(self._probes) > 4096:
            self._probes.clear()
        self._menu = None
        return out

    # ----- what a pick does -----

    def pick(self, choice, until=None) -> dict:
        """Apply the menu item `choice` names (an index, an id, or
        {"pick": ...}) and read on to the next decision the model faces.
        `until` — a callable(decision) returning a reason to stop, "" to
        pass — then passes priority while it says pass (the MCP server's
        pass-until). Returns `{item, refused}` and, with `until`, `stop`
        and `passed`."""
        menu = self.menu()
        item = resolve_pick(menu, choice)
        self.stats["decisions"] += 1
        self.journal = []
        before = len(self.refused)
        self._apply(item)
        self._settle()
        out: dict = {"item": {"id": item["id"], "label": item["label"]}}
        if until is not None:
            out.update(self._pass_until(until))
        out["refused"] = self.refused[before:]
        return out

    def _apply(self, item: dict) -> None:
        plan = item.get("plan") or {}
        decision = self.decision
        self._menu = None
        if "sub" in plan:
            self.sub = plan["sub"]
            return
        if plan.get("cancel"):
            self.sub = None
            self.plan = None
            self._send_one({"op": "cancel"})
            return
        if "final" in plan:
            key = (self.sub or {}).get("key") or item["id"]
            self.sub = None
            self._pay_and_submit(plan["final"], key)
            return
        if "cast" in plan:
            self.sub = None
            self._cast(plan)
            return
        self.sub = None
        for action in plan.get("send") or []:
            if self._send_one(action):
                self._block(blocked_key(item), decision)
                return

    def _send_one(self, action: dict) -> list:
        self.send(action)
        return self.advance()

    def _cast(self, plan: dict) -> None:
        key = plan["key"]
        decision = self.decision
        refusals = self._send_one(plan["cast"])
        if self.decision is None:
            return
        if refusals or not _options(self.decision).get("announcement"):
            if _options(self.decision).get("announcement"):
                self._send_one({"op": "cancel"})
            self._block(key, decision)
            return
        self.plan = {"key": key, "card": plan["cast"]["card"], "seat": _seat(decision), "stage": "prepared",
                     "mv": int(plan.get("mv") or 0)}
        draft = _options(self.decision).get("draft") or {}
        if not draft.get("reachable", True):
            self._withdraw(key)   # no way to pay: withdrawn before a target is asked for
            return
        targets = plan.get("targets")
        if targets is None:
            view = _view(self.decision)
            lists = _flat_targets(_options(self.decision).get("announcement") or {},
                                  list(_presentation(view).get("targets") or []), view, _seat(self.decision))
            if lists == []:
                self._withdraw(key)
                return
            if lists is not None and len(lists) == 1:
                targets = lists[0]
            else:
                self.sub = targets_sub(self.decision, plan)
                return
        self._pay_and_submit(targets, key)

    def _live_tokens(self, targets: list) -> list | None:
        """The planned targets as the open announcement's tokens, each read
        again by what it stands for (a card handle, a player); the planned
        token when the announcement does not say. None when one is gone."""
        view = _view(self.decision)
        refs = list(_presentation(view).get("targets") or [])
        slots = (_options(self.decision).get("announcement") or {}).get("slots") or []
        pairs = []
        for target in targets:
            want = target.get("ref") or {}
            number = int(target.get("slot", 0))
            candidates = (slots[number].get("targets") or []) if number < len(slots) else []
            token = None
            for candidate in candidates:
                ref = _ref_of(str(candidate.get("id")), refs)
                if want and ref.get("kind") == want.get("kind") and str(ref.get("id")) == str(want.get("id")):
                    token = str(candidate.get("id"))
                    break
            if token is None:
                if not want and any(str(c.get("id")) == target.get("token") for c in candidates):
                    token = target["token"]
                else:
                    return None
            pairs.append([token, int(target.get("amount", 0) or 0)])
        return pairs

    def _withdraw(self, key: str) -> None:
        """Cancel the open announcement and keep `key` off the menu."""
        scope = self.decision
        self.plan = None
        self.sub = None
        if self.decision is not None and _options(self.decision).get("announcement"):
            self._send_one({"op": "cancel"})
        self._block(key, scope)

    def _pay_and_submit(self, targets: list, key: str) -> None:
        if self.decision is None:
            return
        options = _options(self.decision)
        if not options.get("announcement"):
            self.plan = None
            return
        draft = options.get("draft") or _presentation(_view(self.decision)).get("draft") or {}
        if self.plan is None:
            self.plan = {"key": key, "card": draft.get("card"), "seat": _seat(self.decision), "stage": "prepared"}
        self.plan["targets"] = targets
        pairs = self._live_tokens(targets)
        if pairs is None or not draft.get("reachable", True):
            self._withdraw(key)   # nothing tapped for a cast that cannot go
            return
        self.plan["stage"] = "paying"
        before = self._mana_state()
        stack = len(_view(self.decision).get("stack") or [])
        refusals = self._send_one({"op": "autopay", "excluded": [], "count": max(1, len(pairs))})
        if self.decision is None:
            return
        if refusals:
            self._withdraw(key)
            return
        if not self._at_plan():
            return   # the payment asks a question (a colour, a land to return): the model answers it
        if self._trigger_in_the_way(stack):
            self._withdraw(key)
            return
        if len(pairs) > 1 and self._mana_state() == before and int(self.plan.get("mv") or 0) > before[0]:
            # The announcement's `reachable` priced ONE target; the auto-pay
            # plans all or nothing, so nothing tapped and too little floating
            # means the targets beyond the first cannot be paid for (Fireball's
            # {1} a target after the first): withdrawn, not submitted.
            self._withdraw(key)
            return
        self._submit()

    def _trigger_in_the_way(self, stack_before: int) -> bool:
        """The payment's tap put a trigger on the stack (City of Brass,
        Manabarbs) and the spell can no longer be cast over it — a sorcery,
        a creature: withdraw, let the trigger resolve, and the cast is
        offered again from the floating mana once the stack has changed."""
        view = _view(self.decision)
        if len(view.get("stack") or []) <= stack_before:
            return False
        draft = _options(self.decision).get("draft") or _presentation(view).get("draft") or {}
        if draft.get("kind", "spell") != "spell":
            return False
        return not presentation_rows(view).get(draft.get("card"), {}).get("castable", True)

    def _mana_state(self) -> tuple:
        """The deciding seat's floating mana and tapped permanents — what an
        auto-pay that found a way to pay changes."""
        view = _view(self.decision) if self.decision is not None else {}
        player = _player(view, _seat(self.decision)) if self.decision is not None else {}
        mana = player.get("mana") if isinstance(player.get("mana"), int) else 0
        tapped = sorted(str(c.get("id")) for c in player.get("battlefield") or []
                        if isinstance(c, dict) and c.get("tapped"))
        return (mana, tapped)

    def _at_plan(self) -> bool:
        """Is the current decision the plan's announcement, back with its
        seat at priority?"""
        if self.plan is None or self.decision is None:
            return False
        options = _options(self.decision)
        draft = options.get("draft") or _presentation(_view(self.decision)).get("draft") or {}
        return (mode_of(self.decision) == "priority" and bool(options.get("announcement"))
                and _seat(self.decision) == self.plan["seat"] and draft.get("card") == self.plan["card"])

    def _submit(self) -> None:
        key = self.plan["key"]
        pairs = self._live_tokens(self.plan.get("targets") or [])
        if pairs is None:
            self._withdraw(key)
            return
        self.plan["stage"] = "submitted"
        if self._send_one({"op": "submit", "targets": pairs}):
            self._withdraw(key)
            return
        self.plan = None

    def _settle(self) -> None:
        """Carry on to a decision the model must answer: a cast whose
        payment question was answered is submitted; a menu of one item is
        answered (`skip_forced`); another seat's decision is left."""
        guard = 0
        while self.decision is not None and not self.done:
            guard += 1
            if guard > 20000:
                raise DriverError("twenty thousand steps without a decision for the model")
            if self.seats is not None and _seat(self.decision) not in self.seats:
                return
            if self.plan is not None:
                if self._at_plan():
                    if self.plan.get("stage") == "paying":
                        self._submit()
                        continue
                elif mode_of(self.decision) == "priority" and not _options(self.decision).get("announcement"):
                    self.plan = None   # the cast went through, or was withdrawn
            menu = self.menu()
            if self.decision is None:
                return
            if not menu:
                # Every item refused: the quiet answer, then a cancel, and only
                # then the seat concedes (the referee would after 20 refusals).
                self.stats["forced"] += 1
                for action in (fallback_action(self.decision), {"op": "cancel"}, {"op": "concede"}):
                    if not self._send_one(action) or self.decision is None:
                        break
                continue
            if self.skip_forced and len(menu) == 1:
                self.stats["forced"] += 1
                self._apply(menu[0])
                continue
            return

    def _pass_until(self, stop) -> dict:
        """Pass priority while `stop(decision)` says "" — at most 400 times,
        never over a decision that is not a plain priority."""
        passes = 0
        reason = ""
        while self.decision is not None and not self.done:
            if mode_of(self.decision) != "priority" or _options(self.decision).get("announcement") \
                    or "pass" not in _options(self.decision) or self.sub is not None:
                reason = f"decision: {self.sub.get('kind') if self.sub else mode_of(self.decision)}"
                break
            reason = stop(self.decision) or ""
            if reason:
                break
            if passes >= 400:
                reason = "400 decisions passed"
                break
            self._send_one({"op": "pass"})
            passes += 1
            self._settle()
        if self.done:
            reason = "the game is over"
        return {"stop": reason, "passed": passes}

    def resync(self, decision: dict | None) -> None:
        """Take up `decision` as the current one — the line moved on without
        this Driver (another tool answered the decision it was showing):
        the sub-menu, the cast plan and the cached menu are dropped."""
        if decision is self.decision:
            return
        if decision is not None and self.decision is not None and decision.get("n") == self.decision.get("n") \
                and decision.get("seat") == self.decision.get("seat"):
            self.decision = decision
            return
        self.decision = decision
        self.sub = None
        self.plan = None
        self._menu = None


# --- the MCP server's link -------------------------------------------------------

def attach_game(game, timeout: float = 120.0, **options) -> Driver:
    """The Driver of an MCP server `Game` — the link `referee_menu` and
    `referee_pick` use (tools/shandalar_mcp.py; duck-typed: `send(action)`,
    `advance(timeout, render=False) -> state`, `pending`, `result`,
    `error`, `memory`). Kept in `game.memory["decide"]`, so a sub-menu
    and the probe cache last from one call to the next; taken up again
    from `game.pending` when another tool answered meanwhile. A read that
    times out raises DriverError (the referee answers in milliseconds; a
    silence is a broken game). `options` are Driver's (`probe`,
    `skip_forced`, `features`) and apply when the Driver is made."""
    driver = game.memory.get("decide") if isinstance(getattr(game, "memory", None), dict) else None
    buffer: list = []

    def receive():
        if buffer:
            return buffer.pop(0)
        state = game.advance(timeout, render=False)
        if state.get("pending"):
            raise DriverError(f"the referee said nothing for {timeout:.0f} s")
        for record in state.get("refused") or []:
            buffer.append({**record, "type": "refused"})
        if game.pending is not None:
            buffer.append(game.pending)
        elif game.result is not None:
            buffer.append(game.result)
        elif game.error is not None:
            buffer.append({"error": game.error})
        return buffer.pop(0) if buffer else None

    def send(action: dict) -> None:
        game.send(action)
        _hand_over_journal(game)   # the Driver keeps every line it reads

    if driver is None:
        driver = Driver(send, receive, **options)
        game.memory["decide"] = driver
        driver.result = game.result
        driver.error = game.error
        _take_up(driver, game)
        driver._settle()
    else:
        driver._receive = receive
        driver._send = send
        if driver.decision is not game.pending:
            _take_up(driver, game)
        driver.result = game.result if game.result is not None else driver.result
    return driver


def _hand_over_journal(game) -> list:
    """The lines the MCP `Game` kept for its next shown decision (the
    decisions passed over), handed to the Driver instead."""
    lines = list(getattr(game, "passed_journal", None) or [])
    if hasattr(game, "passed_journal"):
        game.passed_journal = []
    if hasattr(game, "fresh"):
        game.fresh = False
    return lines


def _take_up(driver: Driver, game) -> None:
    driver.resync(game.pending)
    driver.journal = _hand_over_journal(game) + list(((game.pending or {}).get("view") or {}).get("journal") or [])


def menu_state(driver: Driver, rich: bool = False) -> dict:
    """One decision as `referee_menu` and `referee_pick` answer it: `n`
    (the model's decisions so far), `obs`, `menu` (`id`, `label`; with
    `rich`, `kind`, `info`, `ops`), `stats`, and `result` (or `error`)
    once the game is over."""
    obs = driver.observe()
    out = {"n": driver.stats["decisions"], "obs": obs, "menu": public_menu(driver.menu(), rich),
           "stats": dict(driver.stats)}
    if driver.result is not None:
        out["result"] = driver.result
    if driver.error is not None:
        out["error"] = driver.error
    return out
