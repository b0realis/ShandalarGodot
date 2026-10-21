# Magic Public Notation — MPN 0.1 prototype

**A record of what happened, not a recipe for making it happen again.**

MPN is a proposed, implementation-independent, UTF-8 text notation for the
public history of a Magic game. It is not an official Magic standard. The
first ShandalarGodot implementation records public observations and selected
events, and includes a read-only viewer. It deliberately does **not** claim
complete rules coverage or deterministic game resumption.

Implementing MPN in another engine? See the standalone
[MPN 0.1 implementer's specification](mpn-specification.md) for the grammar,
field schemas, public-information boundary, reconstruction algorithms and
conformance checklist, with [importable examples](mpn-examples/). This page
remains the player guide and overview of the ShandalarGodot prototype.

## Using the prototype

At the end of a duel, choose **Export MPN** on the left of the
win/loss popup's bottom row and save the `.mpn` file. **OK** is on the right and
remains the main action. In **Options → View past-played games**, choose a file
and press **View**, or **Cancel** to return. The history viewer offers
previous/next, first/last, a seek bar and automatic playback. Click a public
card tile for its recorded rules text; **Info** shows the metadata. No card
pack, card-art download or simulation is required to read an archive.

Choose **Watch duel** to see the recording on the familiar duel table, with
your installed skin and card art. It shows recorded life, mana, public cards,
tapped states, counters, damage, the spell chain and recorded block/target
arrows. Hidden hands remain counts; their public cards can be inspected.
There are previous/next-turn buttons, playback speed and a seek bar. Left/
Right step, Space plays/pauses, Home/End jump, and **History** or Escape
returns to the same point in the text view. Inspecting a pile pauses progress.

This is a read-only reconstruction, **not a playable resumed duel**. Detailed
damage assignment, prevention shields, choices, effects and timing that were
not recorded are omitted. Combat participants stay on the battlefield; the
viewer does not invent a live combat decision window. Artwork and printed
mana costs may come from your current local catalogue, but recorded public
state and rules text take precedence. Missing art/cards still have text.
Unknown information is not filled in from a later observation.

Local duels also keep their recordings under `user://records`. The optional
`records_folder` key in the `[options]` section of `settings.cfg` can point to
another folder. Each duel has its own file; games in a local best-of match
share a `Match` identifier and have separate `Game` numbers. This prototype
exports **one duel at a time**, not a combined best-of-match container.
Test hands and automated test/lab runs do not create player archives.
There is no automatic deletion or retention quota across files yet.

**Online/LAN:** either player can use Export MPN at the result screen, before
leaving the table. The host supplies the **same neutral record** to both
seats, in bounded chunks. It does not export either player's private view.
Save before closing the host or advancing away from the finished table. A
lost transfer can be retried after reconnecting. This requires protocol 30
on both ends. The host retains a local archive too. Tournament duels are
exported separately; cross-round tournament grouping is not implemented.

In the Web build, export uses the browser's download action; opening a file
reads it locally, without uploading it. Browser storage is not a backup:
save the downloaded file somewhere durable. The desktop file dialogs and
Web picker have separate paths; device testing remains necessary on mobile.

The older `duel_log.txt`, per-seat LAN journal and DeckLab diagnostic logs
remain unchanged. They can contain private information and must **not** be
renamed to `.mpn` or presented as neutral archives. Missing history cannot be
recovered from those logs reliably.

## The audience boundary

Public means what a neutral observer is entitled to know under the game
rules, not everything a spectator UI happens to display. Thus demo mode,
hotseat Show Hand, and the optional Unfair opponent do not open hidden hands
to this recorder.

Record public player names, life/poison/mana totals, hand/library counts,
public objects, declared targets, combat, damage and public reveals.
Never record private hand contents, library order, unrevealed decklists or
sideboard swaps, shuffle seeds/RNG state, speculative search branches,
private choice candidates, connection credentials, machine paths, or
engine instance IDs. Names and comments supplied by people are public
metadata: review them before sharing if they contain personal information.

A private look by one player is **not** a public reveal. Face-down cards
have the label `Face-down card`, no printed identity, printing or rules text.
Face-down exile does not disclose the underlying card's type or stats. A
rule-revealed hand or top library card may be shown while that revelation
applies. A one-off reveal records names without inventing persistent hidden
identities. Previously revealed names remain in history; they are not
retroactively erased when the cards become hidden.

The recorder observes signals and reads allowlisted values only. It never
serializes an engine object, raw log line, agent, memory dictionary, or
seat-specific network projection. Archive identifiers use independent
entropy and do not consume or reveal the game's RNG.

## Text structure

One game per file. UTF-8, LF recommended; CRLF is accepted. Blank lines and
lines beginning with `#` are ignored. Metadata precedes every event:

```text
[Notation "MPN/0.1"]
[Visibility "public"]
[Coverage "public-observations"]
[Started "2026-10-21T18:30:00Z"]
[MatchStarted "2026-10-21T18:30:00Z"]
[Match "friendly-series-01"]
[Game 1]
[Player.P1 "Green Wizard"]
[Player.P2 "Red Wizard"]
[RulesProfile "Modern rules, mana burn on"]
[RulesOptions {"mana_burn":true}]
[CardPool ["2ed","arn","atq","leg","drk","4ed","past","phpr"]]
[Format "Unrestricted"]
[Comments ["A friendly game."]]

1 state {"turn":0,"step":"pregame","active":0,"players":[{"life":20,"poison":0,"hand":0,"library":60,"mana":{}},{"life":20,"poison":0,"hand":0,"library":60,"mana":{}}],"objects":[],"stack":[],"combat":{"attackers":[],"blocks":[]}}
2 state {"players":[{"life":20,"poison":0,"hand":1,"library":59,"mana":{}},{"life":20,"poison":0,"hand":0,"library":60,"mana":{}}]}
3 draw {"player":"P1","count":1}
4 close {"reason":"recording-stopped"}
```

That short example is intentionally an **unfinished** record, not a played
game. A real writer emits every implemented rules fork in `RulesOptions`;
the label alone is not a rules specification. `CardPool` describes the
enabled public set catalogue, not the unseen sets in someone's deck.
`definition_set` on a visible card identifies its rules definition;
`printing` identifies a selected printing when supplied. They are different.
`Recorder` and `Mode` are optional provenance labels, never dependencies.
`Started` is the game recording's start; `MatchStarted` groups the series.
Timestamps should be RFC 3339 with a timezone; this writer uses UTC `Z`.

The grammar is deliberately small:

```text
header = "[" key " " JSON-value "]"
record = positive-sequence-number " " verb " " JSON-object
```

The JSON value occupies one physical line. Quotes, backslashes and embedded
newlines use JSON escaping, including in names and comments. Metadata keys
are unique. Event numbers begin at 1 and increase by exactly 1. No embedded
scripts, resource paths, serialized objects or executable commands exist.
An interleaved `comment {"text":"..."}` is annotation, not a game event.

Required headers are `Notation`, `Visibility`, `Coverage`, `Started`, `Match`
and both player names. Unknown metadata can be retained. Unknown versions
or event verbs are refused by this viewer rather than silently skipped;
future extensions must negotiate another version/coverage profile.

## Public state and identities

`P1` and `P2` are seats in the record, independent of which client was below
or above on screen. Player arrays and `owner`, `controller`, `active` values
use zero-based indexes: 0 is P1, 1 is P2. Result `1-0` means P1 won, `0-1`
means P2 won, and `1/2-1/2` means a drawn game.

Public objects get sequential handles `o1`, `o2`, …; stack items get `s1`,
`s2`, …. Two copies of the same card must have different handles. An object
returning from a hidden zone gets a fresh handle, even if the engine knows
which physical card it was. Public zone changes likewise allocate a new
object handle; this prototype does not yet emit explicit old→new links.
Phasing keeps the handle while reporting the phased-out location.

The first record is a complete `state` observation containing `turn`,
`step`, `active`, `players`, `objects`, `stack` and `combat`. Later `state`
records are patches: absent fields are unchanged; `players`, `stack` and
`combat` replace those whole sections. `objects` upserts complete public
object rows by handle; `removed` deletes handles from the *current* view.
Nothing removes earlier history. Every event after a patch sees that patch.

Player rows carry life, poison, hand count, library count and available mana
counts under `W`, `U`, `B`, `R`, `G`, `C`. Object rows carry name, zone,
owner/controller, public P/T, marked damage, tapped/face-down/creature flags,
counters and public attachment links. Face-up rows may also carry rules
text, types, subtypes, keywords and printing metadata. Current supported
zones are battlefield, graveyard, exile, ante, stack, revealed hand,
revealed library top and phased_out. Hidden hand/library cards have counts,
not numbered placeholders that can be tracked through a shuffle.

Stack rows, in bottom-to-top order, carry kind, controller, source handle,
name and targets. Announced X and mode are included when not provisional.
Targets reference a player, public object or stack handle, with `amount`
for divided assignments. A target without a public handle stays anonymous.
Damage-window targets currently say `pending` rather than identifying a
specific damage packet. Combat contains attacker handles and pairs in
`[blocker, attacker]` order.

## Event vocabulary and coverage

| Verb | Public fact |
| --- | --- |
| `state` | Initial observation or public-state patch |
| `land`, `cast`, `activate` | The observed public play/announcement |
| `draw` | Player and count, never a hidden card's identity |
| `discard`, `enter`, `leave`, `die` | Observed zone/lifetime event |
| `tap`, `untap`, `mana`, `regenerate` | Observed permanent event |
| `attack`, `block` | Declared combat participants |
| `damage` | Applied amount, public source and recipient |
| `mana_burn` | Player and life lost to mana burn, not damage |
| `reveal` | Explicitly public card names |
| `result` | Final result; never inferred from a stopped recording |
| `close` | Recording stopped without necessarily finishing the game |
| `comment` | Human annotation, not authoritative state |

Object events use `object`; acting seats use `player`. `attack` carries
`objects`; `block` carries `attacker` and `blocker`. `damage` carries
`amount`, `source` and `target`. Source handles may be empty if no longer
publicly identifiable. Exact payload fields are documented in the
[implementer's specification](mpn-specification.md#6-event-vocabulary);
this remains a draft vocabulary.
The archive writer adds the UTC `ended` timestamp to the final result.

**Coverage is explicitly `public-observations`, not full replay.** The
prototype follows existing typed engine events and coarse state signals.
It captures many intermediate public transitions, but it does not encode
every pass, complete ability text, resolution choice, cost component,
replacement/prevention ordering, coin flip, revealed-card relationship or
temporary effect. Mana restrictions and some derived characteristics are
not yet represented. A final result does not upgrade coverage to complete.
The LAN writer attaches after the initial deal, so its first observation
shows opening hand counts rather than inventing missing draw events.

The viewer applies recorded state patches and presents event captions. Its
graphical adapter supplies detached display values to existing duel widgets;
it never starts or advances the rules engine. It does not infer a hidden card, validate historical legality,
resume a duel or regenerate random outcomes. Future versions should add
typed public events at the missing engine boundaries, explicit public
object-transition links, full public effects/choices, and coverage tests
before promising complete public-table reproduction. Even then, private
state resumption and proof of private legality require a different format.

## Reliability and trust

The writer flushes each line and never truncates an old game to make room
for a new one. A complete prefix without a `result` is visibly incomplete.
A malformed/truncated line is refused; the viewer never guesses missing
JSON or a winner. Recovering a crash-cut last line is a possible future
repair tool, not a silent import behavior.

Prototype limits are 32 MiB per file, 100,000 records, 1 MiB per physical
line, bounded JSON nesting and collection sizes. Reaching a write limit
keeps the already written prefix. Native write failures are reported.
The parser checks the sequence and public-state shape; it is not a full
semantic validator or a privacy certificate for files authored elsewhere.
The graphical table limits an observation to 512 public objects and 512
stack items; larger observations remain available in the history view with
an explicit explanation rather than a silently incomplete table.

LAN downloads are limited to authenticated, current participants in their
own finished table. Requests contain no filesystem paths. Each 16 KiB chunk
is checked against its offset, total size and record identity. A timeout,
disconnect, malformed chunk or changed game aborts the transfer; it cannot
silently join parts from different matches. Normal game commands and their
acknowledgements are independent of the read-only download channel.

Plain text can be edited. Neither identical downloads nor a checksum proves
that the host was honest, a named player authenticated, or an event legal.
Signing and tournament attestation would be separate optional layers.
