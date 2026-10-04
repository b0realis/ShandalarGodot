#!/usr/bin/env python3
"""Shandalar for DECISION MODELS (2026-10-04) — a numbered-choice door to
one duel, for programs that choose moves rather than chat: a small local
model, a scripted bot, a reinforcement-learning policy, a decision tool.

Every decision is a compact observation and a numbered menu of complete
legal actions; the model returns one number (or the item's id) and this
bridge turns it into the referee's wire ops and returns the next
decision. `tools/decision_menu.py` holds the menus, the observation and
the sequencing; this file runs the referee — through the same door as
the MCP server, `shandalar.sh referee` (a Windows release's console
executable directly) — and offers it three ways:

  * A PYTHON API:

        from shandalar_decide import Env
        with Env("decks/big_green.deck", "decks/white_knights.deck",
                 opponent="wizard", seed=7) as env:
            obs = env.reset()
            while not env.done:
                menu = env.menu()            # [{"id", "label", ...}]
                obs, reward, done, info = env.step(0)
            print(env.result)

  * JSON LINES ON STDIO, for any language: one line out per decision,
    `{"n", "obs", "menu": [{"id", "label"}...]}`, one line in — an index
    (`3`), an id (`"cast:c12->opp"`) or `{"pick": 3}`; a line that names
    no item is answered `{"error": ...}` and the same decision again; the
    last line out is `{"result": ..., "summary": ...}`.

        python3 tools/shandalar_decide.py --deck-a D --deck-b D \\
            [--opponent wizard] [--seed N] [--packs 8]

  * BUILT-IN POLICIES (`--policy random|first|greedy`) — baselines, and
    examples of a policy — with `--episodes N` for a quick evaluation:
    one line per game and a summary (wins, decisions a game, refusals,
    seconds a decision).

Exit codes: 0 played (whatever the result), 2 a line that could not be
run (a flag, a deck — the referee's own envelope on stdout), 1 the run
broke (the referee went away without a result), 3 no Godot to run.
"""

from __future__ import annotations

import argparse
import json
import os
import queue
import random
import subprocess
import sys
import tempfile
import threading
import time
import urllib.request
from pathlib import Path

HERE = Path(__file__).resolve().parent
sys.path.insert(0, str(HERE))
import decision_menu as dm  # noqa: E402
import shandalar_mcp as mcp  # noqa: E402
import tool_banner  # noqa: E402

WORDMARK = ("┌┬┐┌─┐┌─┐┬┌┬┐┌─┐", " ││├┤ │  │ ││├┤ ", "─┴┘└─┘└─┘┴─┴┘└─┘")
CAPTION = ("Shandalar · decisions as numbered menus", "for decision models and bots")
HINT = ("python3 tools/shandalar_decide.py --deck-a A --deck-b B   # JSON lines on stdio",
        "python3 tools/shandalar_decide.py --deck-a A --deck-b B --policy random --episodes 10",
        "python3 tools/shandalar_decide.py -h                      # the rest")
OPPONENTS = ("apprentice", "magician", "sorcerer", "wizard", "unfair", "self")
POLICIES = ("random", "first", "greedy", "systemone")
TIMEOUT = 120.0


class RefereeError(RuntimeError):
    """The referee could not be run, refused the line (its envelope is
    `envelope`), or went away without a result."""

    def __init__(self, message: str, envelope: dict | None = None, exit_code: int = 1):
        super().__init__(message)
        self.envelope = envelope or {"message": message}
        self.exit_code = exit_code


# --- the door ----------------------------------------------------------------

def find_door(spoken: str | None = None) -> Path:
    """`shandalar.sh` (or a Windows release's console executable) beside
    this script's folder — the checkout's root or a release folder — or
    the one `--door` names. RefereeError when there is none."""
    if spoken:
        door = Path(spoken)
        if not door.is_file():
            raise RefereeError(f"no door at {door}", exit_code=2)
        return door
    names = (mcp.WINDOWS_DOOR, mcp.DOOR_NAME) if os.name == "nt" else (mcp.DOOR_NAME, mcp.WINDOWS_DOOR)
    for folder in (HERE.parent, HERE):
        for name in names:
            if (folder / name).is_file():
                return folder / name
    raise RefereeError(f"no {mcp.DOOR_NAME} or {mcp.WINDOWS_DOOR} beside {HERE} — extract the whole "
                       "release folder or give --door", exit_code=2)


def referee_command(door: Path, argv: list[str]) -> list[str]:
    """The referee's command line through the MCP server's own route (the
    door's `referee` verb; the console executable's `--referee`)."""
    return mcp.Server(door, Path(mcp.WORKSPACE)).command("referee", argv)


def referee_argv(deck_a: str, deck_b: str, opponent: str = "wizard", seat: int = 0, seed=None,
                 packs=None, turns=None, rules=None, log=None) -> list[str]:
    if opponent not in OPPONENTS:
        raise RefereeError(f"opponent is one of {', '.join(OPPONENTS)}, not '{opponent}'", exit_code=2)
    if seat not in (0, 1):
        raise RefereeError("seat is 0 (deck A) or 1 (deck B)", exit_code=2)
    other = "agent" if opponent == "self" else opponent
    seats = ["agent", other] if seat == 0 else [other, "agent"]
    argv = ["--deck-a", str(deck_a), "--deck-b", str(deck_b), "--seat-a", seats[0], "--seat-b", seats[1]]
    if seed is not None:
        argv += ["--seed", str(int(seed))]
    if packs not in (None, ""):
        argv += ["--packs", str(packs)]
    if turns is not None:
        argv += ["--turns", str(int(turns))]
    if rules not in (None, ""):
        # The referee's own presets (modern, modern_mana_burn — the standard
        # table, its default — or fifth, the 1997 rules); it judges the word
        # and reports the one played in hello.rules. A word it does not know
        # is refused with its envelope, and that refusal is the answer.
        argv += ["--rules", str(rules)]
    if log:
        argv += ["--log", str(log)]
    return argv


class RefereeProcess:
    """One referee on a pipe: lines out read on a thread (so a read can
    time out), lines in written as JSON."""

    def __init__(self, command: list[str], cwd: Path, env: dict | None = None):
        environment = dict(os.environ if env is None else env)
        environment["SHANDALAR_NO_BANNER"] = "1"
        environment["NO_COLOR"] = "1"
        self.stderr = tempfile.TemporaryFile(mode="w+", encoding="utf-8")
        try:
            self.proc = subprocess.Popen(command, cwd=str(cwd), stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                                         stderr=self.stderr, text=True, bufsize=1, encoding="utf-8",
                                         errors="replace", env=environment, **mcp.own_group())
        except OSError as exc:
            self.stderr.close()
            raise RefereeError(f"the referee would not start: {exc}", exit_code=3)
        self.lines: queue.Queue = queue.Queue()
        self.reader = threading.Thread(target=self._pump, daemon=True)
        self.reader.start()

    def _pump(self) -> None:
        try:
            for line in self.proc.stdout:
                self.lines.put(line)
        except (OSError, ValueError):
            pass
        finally:
            self.lines.put(None)

    def send(self, action: dict) -> None:
        try:
            self.proc.stdin.write(json.dumps(action) + "\n")
            self.proc.stdin.flush()
        except (BrokenPipeError, OSError, ValueError) as exc:
            raise RefereeError(f"the referee's pipe closed: {exc}")

    def receive(self, timeout: float = TIMEOUT) -> dict | None:
        deadline = time.monotonic() + timeout
        while True:
            left = deadline - time.monotonic()
            if left <= 0:
                raise RefereeError(f"the referee said nothing for {timeout:.0f} s")
            try:
                line = self.lines.get(timeout=left)
            except queue.Empty:
                continue
            if line is None:
                return None
            text = line.strip()
            if not text:
                continue
            try:
                record = json.loads(text)
            except ValueError:
                continue
            if isinstance(record, dict):
                return record

    def stderr_tail(self, count: int = 12) -> list[str]:
        try:
            self.stderr.flush()
            self.stderr.seek(0)
            return self.stderr.read().splitlines()[-count:]
        except (OSError, ValueError):
            return []

    def close(self, grace: float = 10.0) -> None:
        try:
            self.proc.stdin.close()
        except (OSError, ValueError):
            pass
        try:
            self.proc.wait(timeout=grace)
        except subprocess.TimeoutExpired:
            mcp.stop_tree(self.proc, drain=False)
        self.reader.join(timeout=2)
        for stream in ((self.proc.stdout,) if not self.reader.is_alive() else ()) + (self.stderr,):
            try:
                stream.close()
            except OSError:
                pass


# --- the environment ---------------------------------------------------------

class Env:
    """One duel at a time as a decision model sees it.

    `Env(deck_a, deck_b, opponent="wizard", seed=None, packs=None,
    rules=None)` — the decks as the referee takes them (as typed, then
    under `decks/`), the computer player in the other chair (`self`: the
    model plays both seats), the shuffle, the card packs (`8`, `all`), the
    rules preset (`modern`, `modern_mana_burn` — the referee's default — or
    `fifth`; `hello["rules"]` says which was played). `seat` is the
    model's chair (0 = deck A). `probe`
    (default on) reads each aimed spell's announcement so the menu lists
    `cast S → target T` flat; `skip_forced` (default on) answers a
    decision with one legal item by itself; `features` adds the numeric
    vector to each observation.

    `reset()` starts a duel and returns the first observation; `menu()`
    is the numbered list; `step(choice)` applies one item and returns
    `(obs, reward, done, info)` — reward +1/-1 at a won/lost end, else 0;
    `done` and `result` say when and how it ended."""

    def __init__(self, deck_a: str, deck_b: str, opponent: str = "wizard", seed=None, packs=None,
                 rules=None, seat: int = 0, turns=None, door=None, probe: bool = True,
                 skip_forced: bool = True, features: bool = True, timeout: float = TIMEOUT,
                 env: dict | None = None, log=None):
        self.deck_a = deck_a
        self.deck_b = deck_b
        self.opponent = opponent
        self.seed = seed
        self.packs = packs
        self.rules = rules
        self.seat = seat
        self.turns = turns
        self.log = log
        self.probe = probe
        self.skip_forced = skip_forced
        self.features = features
        self.timeout = timeout
        self.environment = env
        self.door = find_door(door) if not isinstance(door, Path) else door
        referee_argv(deck_a, deck_b, opponent, seat, seed, packs, turns, rules)   # checks the words now
        self.process: RefereeProcess | None = None
        self.driver: dm.Driver | None = None
        self.started = 0.0
        self.boot = 0.0
        self.elapsed = 0.0

    # ----- a duel -----

    def reset(self, seed=None) -> dict:
        """Start a duel (closing one still open) and return its first
        observation. `seed` replaces the constructor's for this duel."""
        self.close()
        if seed is not None:
            self.seed = seed
        argv = referee_argv(self.deck_a, self.deck_b, self.opponent, self.seat, self.seed, self.packs,
                            self.turns, self.rules, self.log)
        self.process = RefereeProcess(referee_command(self.door, argv), self.door.parent, self.environment)
        process = self.process
        seats = None if self.opponent == "self" else {self.seat}
        self.driver = dm.Driver(process.send, lambda: process.receive(self.timeout), probe=self.probe,
                                skip_forced=self.skip_forced, features=self.features, seats=seats)
        self.started = time.monotonic()
        self.driver.start()
        self.boot = time.monotonic() - self.started
        self.elapsed = 0.0
        if self.driver.error is not None and self.driver.hello is None:
            error = dict(self.driver.error)
            if error.get("kind") == "eof":
                try:
                    returned = process.proc.wait(timeout=15)
                except subprocess.TimeoutExpired:
                    returned = None
                error["stderr"] = process.stderr_tail()
                error["exit"] = returned
                code = 3 if returned == 3 else 1
            else:
                code = int(error.get("exit", 2)) if str(error.get("exit", "")).isdigit() else 2
            self.close()
            raise RefereeError(str(error.get("message", "the referee refused the line")), error, code)
        return self.observe()

    def observe(self) -> dict:
        self._need()
        return self.driver.observe()

    def menu(self, rich: bool = True) -> list[dict]:
        """The numbered list: `id`, `label` (and with `rich`, the default
        here, `kind`, `info`, `ops`)."""
        self._need()
        return dm.public_menu(self.driver.menu(), rich)

    def step(self, choice) -> tuple[dict, float, bool, dict]:
        self._need()
        if self.driver.done:
            raise RuntimeError("the duel is over — reset() starts another")
        began = time.monotonic()
        info = self.driver.pick(choice)
        self.elapsed += time.monotonic() - began
        done = self.driver.done
        return self.observe(), self.reward() if done else 0.0, done, info

    def reward(self) -> float:
        result = self.result
        if not result or result.get("winner") in (None, -1) or self.opponent == "self":
            return 0.0
        return 1.0 if int(result["winner"]) == self.seat else -1.0

    @property
    def done(self) -> bool:
        return self.driver is not None and self.driver.done

    @property
    def result(self) -> dict | None:
        if self.driver is None:
            return None
        if self.driver.result is not None:
            return self.driver.result
        if self.driver.error is not None:
            return {"type": "result", "error": self.driver.error, "winner": -1}
        return None

    @property
    def decision(self) -> dict | None:
        """The referee's own pending decision line (for a policy that
        reads the whole view)."""
        return self.driver.decision if self.driver is not None else None

    @property
    def hello(self) -> dict | None:
        """The referee's `hello` line: the seats, the seed, the toss and
        `rules` — the preset the duel plays under."""
        return self.driver.hello if self.driver is not None else None

    def stats(self) -> dict:
        out = dict(self.driver.stats) if self.driver is not None else {}
        out["seconds"] = round(self.elapsed, 3)
        out["boot_seconds"] = round(self.boot, 3)
        if (self.hello or {}).get("rules"):
            out["rules"] = self.hello["rules"]
        return out

    def _need(self) -> None:
        if self.driver is None:
            raise RuntimeError("reset() starts the duel first")

    def close(self) -> None:
        if self.process is not None:
            self.process.close(grace=10)
            self.process = None

    def __enter__(self):
        return self

    def __exit__(self, *exc):
        self.close()
        return False


# --- the policies -------------------------------------------------------------

HARM = ("damage", "destroy", "bury", "exile target", "-1/-1", "-2/-2", "-3/-3", "tap target",
        "return target", "can't block", "can't attack", "counter target", "loses", "discard",
        "sacrifice", "gain control")


def policy_first(obs: dict, menu: list, rng: random.Random) -> int:
    """Always item 0 — the mode's "do nothing" (pass, no attack, keep):
    the passive baseline."""
    return 0


def policy_random(obs: dict, menu: list, rng: random.Random) -> int:
    """A uniform pick among the items."""
    return rng.randrange(len(menu))


def _harmful(info: dict) -> bool:
    text = str(info.get("text") or "").lower()
    return any(word in text for word in HARM)


def _target_score(item: dict) -> float:
    info = item.get("info") or {}
    target = info.get("target")
    if not target:
        return 0.0
    hostile = target.get("side") == "opp"
    good = hostile if _harmful(info) else not hostile
    score = 1.0 if good else -2.0
    if target.get("kind") == "card":
        score += 0.1 * float(target.get("power") or 0) + 0.05 * float(target.get("toughness") or 0)
    return score


def _pt(text) -> tuple[int, int]:
    try:
        power, toughness = str(text).split("/")
        return int(power), int(toughness)
    except ValueError:
        return 0, 0


def policy_greedy(obs: dict, menu: list, rng: random.Random) -> int:
    """A one-ply heuristic, an example more than an opponent: play a land,
    cast the most expensive spell aimed sensibly (harm at the opponent,
    help at itself), never pay life; attack when the opponent has nothing
    ready that survives the hit; block only when the blocker lives;
    discard the dearest card; answer a question with its first option."""
    mode = obs.get("mode")
    ids = [item["id"] for item in menu]

    def find(prefix: str):
        return next((i for i, ident in enumerate(ids) if ident.startswith(prefix)), None)

    if mode == "opening":
        hand = obs.get("hand") or []
        lands = sum(1 for c in hand if "land" in str(c.get("type", "")))
        mulligan = find("mulligan")
        if mulligan is not None and len(hand) >= 6 and (lands < 2 or lands > 5):
            return mulligan
        return 0
    if mode == "priority":
        land = find("play:")
        if land is not None:
            return land
        own_main = obs.get("active") == "me" and obs.get("step") in dm.OWN_MAIN and not obs.get("stack")
        attacking = {c.get("id") for c in (obs.get("me") or {}).get("battlefield") or [] if c.get("attacking")}
        best, best_score = 0, 0.0
        for i, item in enumerate(menu):
            kind = item.get("kind")
            info = item.get("info") or {}
            target = info.get("target") or {}
            pump = "instant" in str(info.get("type", "")) and not _harmful(info)
            if kind == "cast" and own_main and not pump:
                if "x" in info and not info["x"]:
                    continue   # an X spell for X = 0 does nothing
                score = 1.0 + float(info.get("mv") or 0) + _target_score(item)
                if target and _target_score(item) < 0:
                    continue
            elif kind == "cast" and pump and obs.get("active") == "me" and obs.get("step") == "DECLARE_BLOCKERS" \
                    and target.get("side") == "me" and target.get("id") in attacking:
                score = 1.0 + _target_score(item)   # a trick on an attacker once the blocks are known
            elif kind == "act" and info.get("target") and _target_score(item) > 0 and \
                    (own_main or obs.get("active") == "opp" and obs.get("step") == "END"):
                score = 0.5 + _target_score(item)
            else:
                continue
            if score > best_score:
                best, best_score = i, score
        return best
    if mode == "targets":
        done = find("target:done")
        if done is not None:
            return done
        scored = [(_target_score(item), i) for i, item in enumerate(menu) if item.get("kind") == "target"]
        if scored:
            score, index = max(scored)
            if score > -1:
                return index
        return len(menu) - 1 if menu[-1]["id"] == "cancel" else 0
    if mode == "attack":
        opp = obs.get("opp") or {}
        ready = [c for c in opp.get("battlefield") or [] if c.get("pt") and not c.get("tapped")]
        biggest = max((_pt(c["pt"])[0] for c in ready), default=0)
        tough = max((_pt(c["pt"])[1] for c in ready), default=0)
        for i, item in enumerate(menu):
            info = item.get("info") or {}
            if item.get("kind") == "attack_add":
                power, toughness = int(info.get("power") or 0), int(info.get("toughness") or 0)
                if power > 0 and (not ready or toughness > biggest or power > tough):
                    return i
        return 0
    if mode == "block":
        me = obs.get("me") or {}
        incoming = sum(_pt(c.get("pt"))[0] for c in (obs.get("opp") or {}).get("battlefield") or []
                       if c.get("attacking"))
        desperate = incoming >= int(me.get("life") or 0)
        best, best_score = 0, 0.0
        for i, item in enumerate(menu):
            if item.get("kind") != "block_pair":
                continue
            info = item.get("info") or {}
            target = info.get("target") or {}
            power, toughness = int(info.get("power") or 0), int(info.get("toughness") or 0)
            apower, atough = int(target.get("power") or 0), int(target.get("toughness") or 0)
            if toughness > apower:
                score = 2.0 + (1.0 if power >= atough else 0.0)
            elif desperate:
                score = 1.0
            else:
                continue
            if score > best_score:
                best, best_score = i, score
        return best
    if mode == "discard":
        return max(range(len(menu)), key=lambda i: (float((menu[i].get("info") or {}).get("mv") or 0),
                                                     not (menu[i].get("info") or {}).get("land")))
    if mode == "damage":
        return 0
    if mode == "choice":
        for i, item in enumerate(menu):
            if item.get("kind") != "cancel":
                return i
    return 0


POLICY = {"random": policy_random, "first": policy_first, "greedy": policy_greedy}


# ----- typed decision models: Laya, Jev and the like (2026-10-04) -----------
#
# Laya (convaiinnovations/laya, run locally with `laya-serve`) and Jev
# (jevmodel.net) read the same request — a `state` and typed `questions`,
# POST /v1/systemone — and answer a `choice` question with the option it
# picks and a probability for each. The adaptor is just the menu said that
# way: the compact observation as the state, every item's readable label as
# an option, and the model's choice read back as the pick. Deliberately the
# smallest thing that works; tuning the state for a model's context is the
# model user's to take further.

SYSTEMONE_QUESTION = "Which action should this player take now?"


def systemone_request(obs: dict, menu: list, model: str | None = None) -> dict:
    """One decision as a typed-decision request: `state` is the compact
    observation (without the numeric vector and the journal), the one
    `choice` question names each menu item by its readable label."""
    criteria: dict = {}
    for item in menu:
        label = str(item.get("label") or item.get("id") or "?")
        name, again = label, 2
        while name in criteria:          # labels are read; names stay unique
            name, again = f"{label} ({again})", again + 1
        criteria[name] = label
    request = {"state": {k: v for k, v in obs.items() if k not in ("features", "journal")},
               "questions": {"action": {"type": "choice", "instructions": SYSTEMONE_QUESTION,
                                        "criteria": criteria}}}
    if model:
        request["model"] = model
    return request


def systemone_pick(answer: dict, request: dict) -> int:
    """The menu index the model's answer names: its `choice`, or else the
    option it gave the highest probability."""
    names = list(request["questions"]["action"]["criteria"])
    reply = ((answer or {}).get("answers") or {}).get("action") or {}
    choice = reply.get("choice")
    odds = reply.get("probabilities")
    if choice not in names and isinstance(odds, dict) and odds:
        choice = max(odds, key=lambda name: odds[name] if name in names else -1.0)
    if choice not in names:
        raise ValueError(f"the model answered {choice!r}, not one of the {len(names)} options")
    return names.index(choice)


def systemone_policy(url: str, model: str | None = None, key_env: str = "SYSTEMONE_API_KEY",
                     timeout: float = 60.0):
    """A policy that asks a typed-decision model over HTTP each decision
    (`Authorization: Bearer $SYSTEMONE_API_KEY` when that is set, as Jev's
    hosted API wants; a local `laya-serve` needs none)."""
    def policy(obs: dict, menu: list, rng: random.Random) -> int:
        request = systemone_request(obs, menu, model)
        headers = {"Content-Type": "application/json"}
        if os.environ.get(key_env):
            headers["Authorization"] = f"Bearer {os.environ[key_env]}"
        call = urllib.request.Request(url, json.dumps(request).encode("utf-8"), headers, method="POST")
        with urllib.request.urlopen(call, timeout=timeout) as reply:
            return systemone_pick(json.loads(reply.read().decode("utf-8")), request)
    return policy


def play(env: Env, policy, rng: random.Random, seed=None, trace=None) -> dict:
    """One duel with `policy(obs, menu, rng) -> index`; the game's line."""
    began = time.monotonic()
    obs = env.reset(seed)
    while not env.done:
        menu = env.menu()
        if not menu:
            break
        index = policy(obs, menu, rng)
        if trace is not None:
            trace({"n": env.driver.stats["decisions"], "obs": obs, "menu": dm.public_menu(env.driver.menu()),
                   "pick": index, "id": menu[index]["id"]})
        obs, _reward, _done, _info = env.step(index)
    result = env.result or {}
    stats = env.stats()
    seconds = time.monotonic() - began
    decisions = stats.get("decisions", 0)
    line = {"seed": (env.hello or {}).get("seed", env.seed), "rules": (env.hello or {}).get("rules"),
            "winner": result.get("winner", -1), "won": env.reward() > 0, "lost": env.reward() < 0,
            "turns": result.get("turns"), "reason": result.get("reason") or (result.get("error") or {}).get("kind"),
            "decisions": decisions, "forced": stats.get("forced", 0),
            "wire_decisions": stats.get("wire_decisions", 0), "probes": stats.get("probes", 0),
            "refusals": stats.get("refusals", 0), "referee_refusals": result.get("refusals"),
            "seconds": round(seconds, 2), "boot_seconds": stats.get("boot_seconds"),
            "seconds_per_decision": round(stats.get("seconds", 0) / decisions, 4) if decisions else None}
    if env.driver and env.driver.refused:
        line["refused"] = [{k: r.get(k) for k in ("reason", "action")} for r in env.driver.refused[:5]]
    return line


def summarize(games: list[dict], policy: str, opponent: str) -> dict:
    count = len(games)
    decisions = sum(g["decisions"] for g in games)
    seconds = sum((g.get("seconds_per_decision") or 0) * g["decisions"] for g in games)
    return {"policy": policy, "opponent": opponent, "games": count,
            "wins": sum(1 for g in games if g["won"]), "losses": sum(1 for g in games if g["lost"]),
            "draws": sum(1 for g in games if not g["won"] and not g["lost"]),
            "decisions_per_game": round(decisions / count, 1) if count else 0,
            "forced_per_game": round(sum(g["forced"] for g in games) / count, 1) if count else 0,
            "turns_per_game": round(sum(g.get("turns") or 0 for g in games) / count, 1) if count else 0,
            "refusals": sum(g["refusals"] for g in games),
            "seconds_per_decision": round(seconds / decisions, 4) if decisions else None,
            "seconds_per_game": round(sum(g["seconds"] for g in games) / count, 2) if count else 0}


# --- the command line ---------------------------------------------------------

def describe() -> dict:
    """What a model is handed, field by field: the observation's numeric
    vector (`obs.features`), one menu item's (`decision_menu.item_features`)
    and the item kinds."""
    return {"features": [{"index": i, "name": n, "means": d} for i, (n, d) in enumerate(dm.FEATURES)],
            "item_features": [{"index": i, "name": n, "means": d} for i, (n, d) in enumerate(dm.ITEM_FEATURES)],
            "kinds": list(dm.KINDS), "modes": list(dm.MODES), "policies": list(POLICIES),
            "opponents": list(OPPONENTS)}


def emit(record: dict) -> None:
    sys.stdout.write(json.dumps(record, ensure_ascii=False, default=str) + "\n")
    sys.stdout.flush()


def parse_pick(line: str):
    text = line.strip()
    if not text:
        return None
    try:
        return json.loads(text)
    except ValueError:
        return text


def interactive(env: Env, rich: bool, source=None, systemone: bool = False) -> int:
    """The JSON-lines protocol: a decision out, a pick in, to the result."""
    source = source or sys.stdin
    obs = env.reset()
    while not env.done:
        menu = env.menu(rich)
        if not menu:
            break
        record = {"n": env.driver.stats["decisions"], "obs": obs, "menu": menu}
        if systemone:
            record["systemone"] = systemone_request(obs, menu)
        emit(record)
        while True:
            line = source.readline()
            if line == "":
                env.close()
                emit({"result": env.result, "summary": env.stats(), "note": "the input closed: the seat left"})
                return 0
            pick = parse_pick(line)
            if pick is None:
                continue
            try:
                if isinstance(pick, dict) and "answers" in pick:      # a Laya/Jev answer object
                    pick = systemone_pick(pick, systemone_request(obs, menu))
                obs, _reward, _done, info = env.step(pick)
            except ValueError as exc:
                emit({"n": env.driver.stats["decisions"], "error": str(exc), "menu_size": len(menu)})
                emit({"n": env.driver.stats["decisions"], "obs": obs, "menu": menu})
                continue
            break
    emit({"result": env.result, "summary": env.stats()})
    return 0 if env.result and "error" not in env.result else 1


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        prog="shandalar_decide.py",
        description="One duel as numbered menus for a decision model: each decision is a compact "
                    "observation and a menu of complete legal actions; answer with an index or an id.",
        epilog=tool_banner.BANNER_HELP, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument("--deck-a", help="seat 0's deck (as typed, then under decks/) — required to play")
    parser.add_argument("--deck-b", help="seat 1's deck — required to play")
    parser.add_argument("--opponent", default="wizard", choices=OPPONENTS,
                        help="the computer player in the other chair (self: the model plays both)")
    parser.add_argument("--seat", type=int, default=0, choices=(0, 1), help="the model's chair (0 = deck A)")
    parser.add_argument("--seed", type=int, help="the shuffle (unset: drawn by the referee); "
                        "with --episodes, game i plays seed+i")
    parser.add_argument("--packs", help="the card packs in play: all, none, or ids like 8 or 3,8")
    parser.add_argument("--turns", type=int, help="the duel is a draw past this turn (200)")
    parser.add_argument("--rules", help="the rules preset: modern, modern_mana_burn (the standard table, "
                        "the referee's default) or fifth (the 1997 Fifth Edition rules)")
    parser.add_argument("--policy", choices=POLICIES, help="play with a built-in policy instead of stdin "
                        "(systemone: ask a typed-decision model such as Laya or Jev at --url)")
    parser.add_argument("--url", help="with --policy systemone: the model's endpoint, e.g. "
                        "http://localhost:8000/v1/systemone (laya-serve) or https://jevmodel.net/v1/systemone")
    parser.add_argument("--model", help="with --policy systemone: the request's `model` (e.g. jev-latest)")
    parser.add_argument("--systemone", action="store_true",
                        help="on stdin/stdout: add each decision's typed-decision request to its record "
                             "(an answer object with `answers.action.choice` is accepted as the pick)")
    parser.add_argument("--episodes", type=int, default=1, help="with --policy: how many games (default 1)")
    parser.add_argument("--policy-seed", type=int, default=0, help="the policy's own random seed")
    parser.add_argument("--trace", action="store_true", help="with --policy: print every decision and pick")
    parser.add_argument("--rich", action="store_true", help="menu items carry kind, info and ops too")
    parser.add_argument("--no-features", action="store_true", help="leave the numeric vector out of obs")
    parser.add_argument("--no-probe", action="store_true",
                        help="do not read announcements ahead: aimed spells get a target sub-menu")
    parser.add_argument("--no-skip-forced", action="store_true",
                        help="show decisions with a single legal item too")
    parser.add_argument("--door", help="shandalar.sh or Shandalar.console.exe (default: beside tools/)")
    parser.add_argument("--describe", action="store_true",
                        help="print the observation's numeric fields, the menu item fields and kinds as JSON, "
                             "and exit (no referee)")
    parser.add_argument("--timeout", type=float, default=TIMEOUT, help="seconds to wait for one referee line")
    tool_banner.add_version_flag(parser, "shandalar_decide.py", __file__)
    return parser


def main(argv: list[str] | None = None) -> int:
    argv = sys.argv[1:] if argv is None else list(argv)
    tool_banner.show(WORDMARK, CAPTION, __file__, hint=HINT, argv=argv)
    parser = build_parser()
    try:
        args = parser.parse_args(argv)
    except SystemExit as exc:
        return int(exc.code or 0)
    for stream in (sys.stdin, sys.stdout):
        if hasattr(stream, "reconfigure"):
            stream.reconfigure(encoding="utf-8")
    if args.describe:
        emit(describe())
        return 0
    missing = [flag for flag, value in (("--deck-a", args.deck_a), ("--deck-b", args.deck_b)) if not value]
    if missing:
        emit({"error": {"tool": "shandalar_decide", "exit": 2, "kind": "option",
                        "message": f"{' and '.join(missing)} name the two decks to play", "flag": missing[0]}})
        return 2
    if args.episodes < 1:
        emit({"error": {"tool": "shandalar_decide", "exit": 2, "kind": "option",
                        "message": "--episodes is at least 1", "flag": "--episodes"}})
        return 2
    try:
        env = Env(args.deck_a, args.deck_b, opponent=args.opponent, seed=args.seed, packs=args.packs,
                  rules=args.rules, seat=args.seat, turns=args.turns, door=args.door,
                  probe=not args.no_probe, skip_forced=not args.no_skip_forced,
                  features=not args.no_features, timeout=args.timeout)
    except RefereeError as exc:
        emit({"error": {"tool": "shandalar_decide", "exit": exc.exit_code, "kind": "option", **exc.envelope}})
        return exc.exit_code
    try:
        if args.policy is None:
            return interactive(env, args.rich, systemone=args.systemone)
        if args.policy == "systemone" and not args.url:
            emit({"error": {"tool": "shandalar_decide", "exit": 2, "kind": "option",
                            "message": "--policy systemone needs --url (the model's /v1/systemone endpoint)",
                            "flag": "--url"}})
            return 2
        chosen = systemone_policy(args.url, args.model) if args.policy == "systemone" else POLICY[args.policy]
        rng = random.Random(args.policy_seed)
        games = []
        for i in range(args.episodes):
            seed = None if args.seed is None else args.seed + i
            line = play(env, chosen, rng, seed, emit if args.trace else None)
            line["game"] = i + 1
            games.append(line)
            emit(line)
        emit({"summary": summarize(games, args.policy, args.opponent)})
        return 0 if all(g["reason"] not in (None, "eof", "run") for g in games) else 1
    except RefereeError as exc:
        emit({"error": {"tool": "referee", "exit": exc.exit_code, **exc.envelope}})
        return exc.exit_code
    finally:
        env.close()


if __name__ == "__main__":
    sys.exit(main())
