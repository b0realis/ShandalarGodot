# Magic Public Notation (MPN) 0.1 — implementer's specification

Status: **draft**, 21 October 2026. Format identifier: `MPN/0.1`.

MPN is a small, text-based interchange format for the **public history of a
two-player Magic game**. It records what happened, not instructions for making
it happen again. A reader needs a JSON parser and a state-patch applicator;
it does not need Godot, ShandalarGodot, a card database, artwork or a rules engine.
This is a proposed community format, not an official Magic standard.

This document defines the portable contract independently of the first
implementation. The [player guide](mpn-v0.1.md) describes that implementation's
menus and storage. [Examples](mpn-examples/) are complete, importable files.

## Contents

1. [Scope and conformance](#1-scope-and-conformance)
2. [Encoding and grammar](#2-encoding-and-grammar)
3. [Headers](#3-headers)
4. [Identity and visibility](#4-identity-and-visibility)
5. [Public state](#5-public-state)
6. [Event vocabulary](#6-event-vocabulary)
7. [Ordering and reconstruction](#7-ordering-and-reconstruction)
8. [Implementing a writer](#8-implementing-a-writer)
9. [Implementing a reader](#9-implementing-a-reader)
10. [Limits, errors and trust](#10-limits-errors-and-trust)
11. [Compatibility and extensions](#11-compatibility-and-extensions)
12. [Conformance checklist](#12-conformance-checklist)
13. [Reference implementation and gaps](#13-reference-implementation-and-gaps)

## 1. Scope and conformance

**MUST / MUST NOT** indicate requirements of this draft. **SHOULD / SHOULD NOT**
indicate recommendations that may have a documented reason for an exception.
**MAY** indicates an option. A *writer* produces files; a *reader* reconstructs
and presents them; a *validator* additionally checks their structure and
cross-record consistency. Passing a parser is not proof of conformance or privacy.

One `.mpn` file contains one game (one duel), not an entire best-of match.
Separate files can share match metadata. The supported coverage is
`public-observations`: selected public events and successive public-table
observations. Observations may begin after the game has started. An initial
snapshot is mandatory; reconstructing unrecorded earlier actions is forbidden.

MPN 0.1 does **not** promise every public choice or intermediate rules state.
It cannot resume a live game, reproduce private decisions or random outcomes,
prove legal play, or determine whether two engines implement the same rules.
It has no command zone, multiplayer seats, team model or comprehensive modern
card-characteristic schema. Do not force unsupported information into an
incorrect zone or pretend it is covered. Supporting all Magic formats requires
a later revision. A finished result means the outcome was recorded, not that
the history is complete.

## 2. Encoding and grammar

Use UTF-8, without a byte-order mark. Writers MUST terminate each physical
line with LF. Readers MUST also accept CRLF and a final syntactically complete
line without a newline. Invalid UTF-8 is an error, not replacement-character
input. A blank line separates headers and events in writer output.

```text
file         = header-lines, blank-line, record-lines
header-line  = "[", key, SP, json-value, "]", LF
record-line  = serial, SP, kind, SP, json-object, LF
key          = ASCII letter, { ASCII letter | digit | "." | "_" | "-" }
serial       = nonzero decimal digit, { decimal digit }
SP           = one ASCII space
```

This is descriptive grammar: `json-value` and `json-object` use JSON syntax,
and MUST occupy one physical line. Embedded newlines, quotes and backslashes
in names or comments are JSON-escaped, never interpolated into the line.
Writers use canonical decimal serials (`1`, not `01` or `+1`). Records are
numbered consecutively from 1, counting **all** kinds, not turns or actions.
Keywords, header keys, field names and IDs are case-sensitive.

Readers ignore blank lines and lines whose first non-whitespace character is
`#`. Such comments do not consume a serial and are not part of the timeline.
There are no trailing inline comments. Readers MAY accept surrounding spaces
on a line; writers SHOULD NOT emit them. Headers MUST all precede record 1;
header order and JSON object-key order have no meaning. Array order does.

Duplicate header keys and duplicate JSON object keys MUST be rejected by a
strict validator. JSON numbers MUST be finite. Integer fields have mathematical
integer values; readers MAY accept `2.0` as 2, but writers SHOULD emit `2`.
Do not confuse booleans with integers. Strings are Unicode text; preserve
their content, without case-folding or silently normalizing player names.
The size and numeric bounds in section 10 apply throughout.

## 3. Headers

| Header | Type / requirement | Meaning |
|---|---|---|
| `Notation` | Required string, exactly `"MPN/0.1"` | Selects this format, not the game's version. |
| `Visibility` | Required string, exactly `"public"` | Neutral-observer disclosure boundary. |
| `Coverage` | Required string, exactly `"public-observations"` | No complete-replay claim. |
| `Started` | Required timestamp string | Start of this game's recording. |
| `Match` | Required nonempty string | Opaque, public identifier grouping games of one match. |
| `Player.P1`, `Player.P2` | Required nonempty strings | Public display names of the two seats. |
| `MatchStarted` | Recommended timestamp string | Match start, when known; do not guess an earlier start. |
| `Game` | Recommended positive integer | Game number within the match, starting at 1. |
| `RulesProfile` | Recommended string | Human-readable rules description, not a universal ruleset ID. |
| `RulesOptions` | Optional object of boolean values | Named rule switches; vocabulary is defined by the producer. |
| `CardPool` | Recommended array of strings | Publicly enabled/allowed set identifiers, **not** sets secretly present in decks. |
| `Format` | Optional string | Public format label, such as `"Unrestricted"`. |
| `Mode` | Optional string | Public mode label, such as `"local"` or `"lan-host"`. |
| `Recorder` | Recommended string | Product/version, such as `"ExampleEngine/1.0"`. |
| `Comments` | Optional array of strings | Public, human-authored annotations. |

Timestamps use `YYYY-MM-DDTHH:MM:SSZ` in UTC; fractional seconds before `Z`
are allowed. A reader SHOULD support numeric timezone offsets as well.
Timestamps are descriptive wall-clock information; record serials determine
order. A producer without a reliable clock SHOULD disclose that in `Comments`.
`Started` is not a file modification time. Use `MatchStarted` for a known
earlier match start when recording begins late, and explain late attachment
in a comment. There are no required per-event timestamps in 0.1.

Generate `Match` independently of game RNG and private identifiers. It is
neither a seed, an authentication token nor a player identity. Preserve seat
assignments across a grouped match, even when the starting player changes.
`Match` plus `Game` groups records; it is not a cryptographic uniqueness proof.
If `Game` is absent, the game number is unknown, not implicitly 1.

`CardPool` lists the public available pool, not a census of cards drawn or
played. Set codes, rule-option names, `Format` and `Mode` are descriptive
vocabularies, not globally registered identifiers. Document your vocabulary;
readers MUST NOT require a particular producer's set catalogue or switches.
Missing optional metadata means unspecified, not an empty pool or default rules.

Unknown header keys MAY carry bounded JSON data. Readers MUST accept them
without interpreting them as executable instructions; preserving them is
recommended. Custom keys SHOULD use `X.ProducerName.Field`. This is the
extension point for public metadata, not a route around privacy requirements.

## 4. Identity and visibility

### Seats and public handles

| Representation | Meaning |
|---|---|
| `P1`, `P2` | Seats in event payloads and player-target selectors. |
| `0`, `1` | The same seats in `active`, `owner`, `controller`, and `players` array indexes. |
| `o1`, `o2`, … | Public object handles: cards, permanents, tokens or spell objects. |
| `s1`, `s2`, … | Stack-item handles; distinct from public object handles. |
| `""` | Unavailable/unidentified reference, only where explicitly allowed below. |

Seats never depend on top/bottom screen placement, turn ownership or viewer
perspective. A spell can have both an object handle and a stack-item handle;
several abilities from one permanent have distinct stack-item handles.

Allocate handles from separate, increasing positive counters in each file.
They MUST NOT expose engine instance numbers, memory addresses, hidden-card
positions or RNG-derived identifiers. Do not allocate them for unseen cards.
Suffixes have no leading zeros, signs or separators and MUST fit a positive
signed 64-bit integer. Treat IDs as strings, not JSON floating-point numbers.

An object keeps its handle while it remains the same continuously public
object. Changing controller, tapping, acquiring damage, or turning face up
without becoming a new game object does not allocate another handle.
Phasing preserves the handle. An ordinary zone change creates a fresh handle,
including a public-to-public move such as stack to graveyard. If an object
ceases to be publicly identifiable, remove it from public state and retire its
handle. Any later public appearance gets a fresh handle. Never reuse retired IDs.
Transient hidden-zone visits MUST also retire handles, even between snapshots.

Historical records retain their old handles and names. This is not permission
to track a presently hidden card. Version 0.1 has no explicit old-to-new object
link: equal names or adjacent records do not prove the same physical card.
Stack handles last for one stack entry; leaving and re-entering is a new entry.

### Neutral-observer boundary

The audience is what a neutral observer is entitled to know under the game's
rules, **not** everything visible in an omniscient spectator UI. Writers MUST
exclude hidden hand contents, secret library order, unrevealed decklists and
sideboard choices, private looks, RNG seeds/state, search branches, rejected
actions, unannounced choices, credentials and machine-specific paths.

Hands and libraries normally contribute only counts. A rule-public hand or
top library card may be represented as an object while that disclosure lasts.
A temporary reveal can use `reveal` with card names only; it does not create
persistent hidden-card IDs. A private look by one player is not a public reveal.
Array order MUST NOT disclose secret library/hand ordering. Public hand and
library object rows contain no position field in this version.

Face-down rows use the exact name `"Face-down card"`. They MUST omit
`definition_set`, `printing`, `rules_text`, `types`, `subtypes` and `keywords`.
On the battlefield/stack, record only their publicly defined characteristics,
never the printed card underneath. For a masked face-down card elsewhere,
use zero power/toughness/damage, false `tapped`/`creature`/`token`, and empty
`counters`, rather than leaking hidden characteristics. These placeholders
mean *masked*, not proof that the hidden card is a noncreature with zero power.

Metadata, counters, captions and annotations need the same privacy review as
card rows. A free-text field can leak a secret just as easily as a card ID.
Neither a `Visibility` header nor successful parsing certifies an external
file's privacy. Player names and comments may themselves contain personal data.

## 5. Public state

A `state` record contains a **patch**, not commands. Record 1 MUST be a `state`
containing all seven initial fields: `turn`, `step`, `active`, `players`,
`objects`, `stack`, `combat`. Empty arrays are valid. Initial `removed` MUST
be absent or empty. Subsequent patches contain only sections being updated.

| Field | Type | Meaning / update rule |
|---|---|---|
| `turn` | Nonnegative integer | Global turn number; 0 is pregame. Replaces the previous number. |
| `step` | String | Current step; replaces the previous value. |
| `active` | Integer 0 or 1 | Active seat, **not** priority holder. |
| `players` | Array of exactly two player rows | Complete replacement, P1 then P2. |
| `objects` | Array of complete object rows | Upsert by `id`; does not replace the entire object collection. |
| `removed` | Array of object handles | Remove those handles from the current public collection. |
| `stack` | Array of stack-item rows | Complete replacement, bottom first, top last. |
| `combat` | Combat object | Complete replacement. |

No other top-level patch fields are defined. Missing fields mean unchanged;
`null` never means deletion. `objects: []` does **not** clear the table;
`stack: []` does clear the stack. To clear public objects, list their IDs in
`removed`. Each upsert replaces the **whole row**, so omitted optional fields
from its old version disappear. Never recursively merge an object's fields.
IDs MUST be unique within `objects` and within `removed`; a patch MUST NOT
both remove and upsert the same ID. Repeated stack IDs are invalid.

Step tokens are `pregame`, `untap`, `upkeep`, `draw`, `main1`, `combat_begin`,
`declare_attackers`, `declare_blockers`, `first_strike_damage`, `combat_damage`,
`combat_end`, `main2`, `end`, `cleanup`. Readers SHOULD display unfamiliar step
strings as labels rather than interpreting them as game commands. Step order
is observed, not inferred: extra turns/combat phases and skipped steps exist.
In pregame `active` may be a provisional seat, not the coin-toss winner.

### Player row

Required fields: `life` (signed integer), `hand` and `library` (nonnegative
counts), `mana` (object). Optional: `poison` (nonnegative integer).
No other player-row fields are defined. A missing `poison` means unreported;
writers SHOULD supply it, including zero.

`mana` maps any subset of `W`, `U`, `B`, `R`, `G`, `C` to nonnegative integer
amounts. An omitted color means zero; `{}` means an empty pool. `C` is colorless
mana, not a generic payment requirement. Spending restrictions, snow provenance
and source attribution are not represented. Hand/library counts include their
publicly revealed members; do not add visible objects to those totals again.

### Object row

| Field | Required? / type | Meaning |
|---|---|---|
| `id` | Yes; object handle | Identity for this public lifetime. |
| `name` | Yes; string | Public card/object name; exact face-down label when masked. |
| `zone` | Yes; string | `battlefield`, `graveyard`, `stack`, `exile`, `ante`, `hand`, `library`, `phased_out`. |
| `owner`, `controller` | Yes; 0 or 1 | Owner and attributed controller seat. Outside zones with a controller, writers SHOULD use owner; this field does not grant control there. |
| `power`, `toughness` | Yes; signed integers | Observed effective values; zero placeholders when inapplicable/masked. |
| `damage` | Yes; nonnegative integer | Marked damage, not damage received over the whole game. |
| `tapped`, `face_down`, `creature` | Yes; booleans | Observed public status. `creature` governs whether P/T is applicable. |
| `counters` | Yes; object | Public counter labels mapped to nonnegative integer counts; `{}` for none. |
| `attached_to` | No; object handle or `""` | Public attachment host, empty if none or unavailable. |
| `token` | No; boolean | Whether this is a token, when reportable. |
| `definition_set` | No; string | Producer's source set for the card definition; not necessarily the physical printing. |
| `printing` | No; string | Public printing/variant identifier, in the producer's vocabulary; empty when unspecified. |
| `rules_text` | No; string | Public definition text, not a complete encoding of current continuous effects. |
| `types`, `subtypes`, `keywords` | No; arrays of strings | Public descriptive characteristics; not executable rules. |

No other object fields are defined. Optional absent data is unspecified.
Writers SHOULD use recognizable card names and readable characteristic labels.
Readers MUST NOT require globally recognized set/printing/keyword identifiers
or use these fields to load code. A token may have no catalogue entry. Equal
names never collapse distinct IDs. No field records the position of a card
within its zone; object-array ordering is not a zone-order contract.

### Stack-item row

Required fields are `id` (stack handle), `name` (string), and `targets` (array).
Recommended optional fields: `kind` (`spell`, `ability`, `trigger`),
`controller` (0 or 1), and `source` (object handle or `""`). Further optional
fields: `x` (nonnegative integer, announced X), `mode` (integer, producer's
announced mode index). `ability` means activated ability; `trigger` means
triggered ability. Mode indexes are not a portable rules definition and MUST
NOT be used to execute an ability in another engine. An absent X/mode is
unreported, not necessarily zero. A stack item's `name` is a display label;
it may be the source card's name or `"Ability"`, not complete ability text.

Each target is an object containing **exactly one** selector plus optional
`amount` (nonnegative integer):

```json
{"player":"P2","amount":1}
{"object":"o3","amount":2}
{"stack":"s1","amount":1}
{"damage":"pending","amount":1}
```

Player selectors accept `P1`/`P2`. Object/stack selectors accept their handle
or `""` when unavailable. `damage` accepts only `"pending"`: it identifies
the category, **not** a particular damage packet. `amount` is a publicly
announced divided share when relevant; for a non-divided effect it has no
damage meaning. The prototype commonly emits 1 for such effects. Missing
`amount` is unspecified. Array order is preserved but has no universal
target-slot interpretation. Unannounced choices MUST NOT appear.
`targets: []` can mean no targets or no reportable targets yet; 0.1 does not
distinguish those cases. Never infer an otherwise hidden target.

### Combat object

Required fields: `attackers` (array of object handles) and `blocks` (array
of pairs `[blocker_handle, attacker_handle]`). No other fields are defined.
Both arrays may be empty. A blocker MUST NOT silently acquire a guessed
attacker; pair order is blocker first. Several pairs may share an attacker.
These pairs do not encode damage-assignment order or bands. Defending
planeswalkers/battles and multi-defender combat are outside this draft.

Current combat and attachment references SHOULD identify current public
objects. Stack targets and historical annotations can reference an earlier
public object that has since left; retain its last recorded description for
display, without restoring it to current state. Writers MUST NOT manufacture
a never-public ID just to fill a reference. Readers should show unavailable
references honestly, never resolve them by looking into a hidden engine zone.

## 6. Event vocabulary

Only `state` changes reconstructed table state. Every other kind is a timeline
annotation or an end marker. Optional common fields on action annotations
are `player` (`P1`/`P2`) and `object` (a known public object handle). Omit these
when unavailable; do not guess an actor or leak a private identity. They are
permitted on `land` through `mana_burn` below, including `reveal`.

| Kind | Additional payload | Meaning |
|---|---|---|
| `state` | Patch from section 5 | Public observation. |
| `land` | None | Land played, not merely entering the battlefield. |
| `cast` | None | Spell cast/announced; does not mean it resolved. |
| `activate` | None | Ability activated, not necessarily put on the stack. |
| `draw` | Required `count`: positive integer | Cards drawn. Normally no `object`: the drawn identity is private. |
| `discard` | None | Card discarded; public object reference when available. |
| `enter` | None | Object entered the battlefield. |
| `leave` | None | Object left the battlefield; destination is not encoded here. |
| `die` | None | Creature died. Do not infer this solely from a missing object. |
| `mana` | None | Observed mana-production action; exact pool is in `state`. |
| `attack` | Required `objects`: array of object handles | Declared attackers; may be empty. |
| `block` | Required `attacker`, `blocker`: object handles or `""` | One declared blocking relationship. |
| `damage` | Required `amount`: nonnegative integer; `source`: object handle or `""`; `target`: object handle, `P1`, `P2`, or `""` | Damage actually dealt, not merely assigned. |
| `tap`, `untap` | None | Observed tap/untap. |
| `regenerate` | None | Regeneration replacement applied, not merely a shield created. |
| `reveal` | Required `cards`: array of strings | Card names revealed publicly; no persistent identity/order claim. |
| `mana_burn` | Required `amount`: nonnegative integer | Life lost to mana burn, not damage. |
| `result` | Required `result`: string; optional `ended`: timestamp | Final game outcome; see below. |
| `close` | Required `reason`: string | Recording stopped; not a result. |
| `comment` | Required `text`: string | Human annotation, not authoritative game state. |

There are no other portable action fields in 0.1. A validator SHOULD flag
unexpected fields; a tolerant reader MAY preserve them as uninterpreted data
with a warning, but MUST NOT give them game-state semantics. Empty basic
annotations such as `cast {}` are permitted when details were not observable.
More informative records are preferred, but no identity is better than a leak.

A single action can produce several annotations (`cast`, `enter`, etc.). These
are not additional copies of the action. Repeated `damage` records may describe
separate damage packets. No simultaneity group, unique packet ID, combat flag,
prevention ordering or causal link is encoded; readers MUST NOT invent one.
Changes in life do not necessarily mean damage, and an empty stack does not
prove resolution rather than countering. Use recorded events, not deductions
from state differences, to label those outcomes.

`result.result` is exactly `"1-0"` (P1 won), `"0-1"` (P2 won), or
`"1/2-1/2"` (draw). There is at most one result. It is the game outcome, not
match score; a concession may have a result without a player's life reaching
zero. `ended` is the observed completion time in the header timestamp format.
After `result`, only `comment` and an optional `close` may follow. After `close`,
no further numbered records are permitted. Line comments/blank lines may remain.

Without `result`, the game outcome is **unknown** even if the last state appears
decisive. `close {"reason":"recording-stopped"}` explicitly ends a recording
without claiming a winner. EOF after a complete record is a valid incomplete
history; malformed/truncated JSON is not. There is no `"*"` result token.

## 7. Ordering and reconstruction

The serial is observation order. It does not order simultaneous Magic events
or imply a player had priority. For each record, apply its patch if it is
`state`, then display the timeline at that serial. Never apply action payloads
as additional mutations: subtracting damage after applying the corresponding
life update would count it twice.

Writers SHOULD emit changed public state before its descriptive action event
when the engine's observation boundary permits. Readers MUST NOT require
adjacency or a fixed state/event pairing. A `reveal` may precede the next state,
one state may reflect several events, or intermediate states may exist.
The state at serial N is exactly the fold of `state` records through N.

```text
apply(state, patch):
    out = deep_copy(state)
    if out has no objects: out.objects = {}       # map, unlike wire array
    for each (key, value) in patch:
        if key is neither objects nor removed:
            out[key] = deep_copy(value)          # whole-section replacement
    for id in patch.removed or []:
        delete out.objects[id] if present
    for row in patch.objects or []:
        out.objects[row.id] = deep_copy(row)      # whole-row replacement
    return out
```

Removing an already absent ID is a no-op for reconstruction; validators SHOULD
warn. A reader may retain retired rows in a separate historical lookup, but
must not display them as currently visible objects. Seeking backwards requires
folding from the initial state or an immutable checkpoint, not reversing event
captions. Checkpoints are a viewer cache, not another file record kind.

The [finished-game example](mpn-examples/finished-game.mpn) starts at an already
observed main phase: a Mountain produces mana, a spell targets P2, damage is
dealt, and P2 concedes. The [stopped-game example](mpn-examples/stopped-game.mpn)
has a recorded draw and no result. Both are illustrative histories, not
proofs that all earlier play or every intervening priority pass was recorded.

## 8. Implementing a writer

Attach a recorder to committed engine events and public-state transitions;
do not scrape localized UI text or export a saved-game object. Keep the public
projection separate from either player's private view and from diagnostic logs.

```text
start(public_metadata):
    validate metadata; write headers
    next_serial = 1
    public_handles = empty registries
    previous_projection = none
    observe()                                   # emits complete initial state

observe():
    if engine is speculating or rolling back a rejected action: return
    process committed visibility/object-lifetime transitions
    now = copy_neutral_public_projection(engine, public_handles)
    patch = full_initial_or_difference(previous_projection, now)
    if patch is not empty: append("state", patch)
    previous_projection = deep_copy(now)

on_committed_public_event(event):
    observe()
    annotation = translate_and_redact(event)     # never serialize raw event
    if supported and reportable: append(kind, annotation)

on_game_finished(outcome):
    observe(); append("result", public_outcome_and_time); stop

append(kind, data):
    validate schema, privacy, size and remaining budget
    serialize ONE complete line with the next serial
    write and flush; report any storage failure
    increment next_serial only for a written record
```

Capture private-to-public transitions at the engine boundary so an object
that leaves and returns between snapshots cannot retain a hidden identity
link. Keep copied values, not live engine objects. The recorder MUST NOT
consume gameplay RNG, change rules state, affect turn decisions or record
speculative search. Recording errors should stop recording visibly, not alter
the duel or manufacture a result. Use independent randomness for archive IDs.

Before recording a reveal, determine its audience explicitly. A boolean
"visible to the local player" is insufficient. For online play, the referee
can distribute one neutral file to both seats; each may save it independently.
Transport authentication, chunking, storage paths and UI are outside MPN.
Do not merge two seat-private logs and call the union public.

## 9. Implementing a reader

Validate version, required headers, size limits, record numbering and payloads
before presenting an archive as valid. Parse structured data; never use `eval`,
execute replay commands, load script paths from metadata, or fetch resources
automatically from names/printing fields. Escape all displayed text for your
UI toolkit. Do not trust a name/comment as a filename or markup fragment.

```text
read(bytes):
    enforce byte limit; decode UTF-8 strictly
    parse headers and consecutive records with a JSON parser
    validate version, schemas, identities and terminal ordering
    require first record to contain every initial-state section
    state = {}
    for record in order:
        if record.kind == state: state = apply(state, record.payload)
        expose immutable observation and annotation to viewer
    outcome = recorded result, otherwise unknown
```

A minimal viewer shows names, life, hand/library counts, public objects,
stack, combat and the chronological captions. It can offer first/previous/next/
last and seek without simulating Magic. Missing artwork or unrecognized card
names are not parse errors. A richer reader may use an optional local database
for pictures, but recorded facts take precedence over current database rules
text or characteristics. Public recording is not a licence to reconstruct
unknown hidden information from a player's later choices.

A graphical reader can reuse its engine's card widgets without executing
game actions. Apply snapshots to detached display values, not live rules
objects. Damage events annotate the history; do not apply them again to life
totals already supplied by a `state` record. Seeking backward must clear
later card previews, attachments and inspection windows. Unknown combat
decisions, prevention effects and other absent details MUST NOT be invented.
Recorded attackers, blocking pairs and marked damage suffice for a useful
combat picture without reconstructing a full damage-assignment interface.

## 10. Limits, errors and trust

These are the 0.1 interoperability limits, chosen to match the prototype's
bounded reader. Writers MUST stay within them or stop with a visible warning.
Readers MAY impose smaller resource budgets if they report the limitation
clearly instead of presenting a silently truncated history.

| Limit | Value |
|---|---|
| Whole file | 33,554,432 UTF-8 bytes (32 MiB), including comments and newlines. |
| Physical line | 1,048,576 UTF-8 bytes (1 MiB), excluding its line terminator. |
| Numbered records | 100,000. |
| Decoded JSON string value | 8,192 Unicode code points. |
| Decoded JSON object key | 128 Unicode code points. |
| Entries per JSON array/object | 4,096; also applies to the collected header object. |
| JSON depth | At most 12 edges from payload/header-map root to any value, including scalar leaves. |
| State integers | Absolute value at most 1,000,000; counts and damage nonnegative; seats only 0/1. |

For portability, writers SHOULD keep event counts/amounts, X/mode and game
numbers within the same million-value numeric bound, with mode allowed to
use an implementation-specific negative sentinel. IDs instead use the signed
64-bit suffix bound in section 4. Unknown metadata numbers must be finite;
large exact identifiers belong in strings, not floating-point JSON numbers.

A file that ends between records can be a valid incomplete history. A
truncated/malformed record must fail validation; do not silently repair JSON
or skip a numbered line. An explicit recovery tool MAY save a valid prefix
to a **different file**, reporting which tail was dropped and preserving the
original. Never invent a result during recovery. Line flushing reduces lost
history but is not a guarantee against disk failure or a cut mid-write.

Plain text can be edited. No username, result, hash or shared download proves
the host honest, the player authenticated, or the game legal. Checksums can
detect transfer changes only when compared with a trusted expected checksum.
Signatures and tournament attestations need a separately designed trust layer.
There is no canonical byte serialization for signing in 0.1; signing raw bytes
means whitespace or newline changes change the signature.

## 11. Compatibility and extensions

Readers MUST reject unsupported `Notation`, `Visibility`, `Coverage`, unknown
record kinds and unknown state/object/player fields rather than silently
misrepresenting a newer state model. Preserve unfamiliar public metadata and
descriptive labels. No arbitrary executable extension hooks are allowed.
Version 0.1 is a draft: claiming to support its syntax does not imply support
for a future version or complete Magic rules coverage.

Adding a typed event, required field, zone, seat model, or stronger coverage
promise requires a new version/defined profile and accompanying migration
rules. Do not emit a future event under `MPN/0.1`. A `comment` may describe an
unsupported public action in prose, but it MUST NOT be presented as a typed,
machine-replayable event. Optional metadata must not change patch semantics.

Useful later work includes public object-transition links, explicit targets
and mode descriptions, damage-packet identity/simultaneity, public costs and
resolution choices, replacement/prevention order, complete public effects,
coin-flip outcomes, more zones and multiplayer. None requires publishing
private hands or RNG. Even a complete public history would remain distinct
from a private saved-game/resumption format.

## 12. Conformance checklist

Use the supplied examples as positive fixtures, then test these boundaries:

| Test | Required behavior |
|---|---|
| Unicode name, quotes and an escaped newline | One intact JSON string, no injected record. |
| CRLF or no final newline after complete JSON | Same parsed history. |
| Duplicate header/JSON key, missing initial section, serial gap | Reject in strict validation. |
| Unknown version/kind/zone, invalid seat or reference syntax | Reject, not guessed compatibility. |
| Partial `players` array or partial object upsert | Reject; these are replacement rows/sections. |
| Empty `objects` vs explicit `removed` | First retains objects; second removes specified objects. |
| Same-name cards, control change, phasing, zone change | Distinct handles; keep on control/phasing, renew on zone change. |
| Public card enters a hidden zone and later returns | Retire old handle; do not link hidden lifetime. |
| Hidden round trip between observations | Still retire the old handle. |
| Change only hidden cards/order/seed/internal IDs | Public output unchanged for the same public facts (excluding independent metadata IDs/times). |
| Private look, omniscient UI, search branch, rejected action | No private/speculative facts recorded. |
| Face-down object | No printed identity, set, text or characteristic leakage. |
| Public reveal ends | Historical reveal remains; current hidden identity disappears. |
| Life state update plus `damage` annotation | Life changes once, not twice. |
| Backwards seek and forward playback | Same states as a fresh fold from record 1. |
| `close` without result or clean EOF without result | Outcome unknown. |
| Records after `close`, or gameplay after `result` | Reject. |
| Cut mid-JSON, excessive line/file/depth/collection | Explicit bounded failure, not partial success. |
| Recording enabled vs disabled | Same gameplay and gameplay RNG state. |

Also test historical references after removal, optional-field deletion on
upsert, counter dictionaries, stack order, multiple blockers, missing artwork,
stale target references, and storage failure. Cross-engine testing should
compare the reconstructed public observations and declared coverage, not
require identical event granularity or byte-for-byte files from different
engines.

## 13. Reference implementation and gaps

The ShandalarGodot prototype is a useful interoperability target, not a full
conformance oracle. `engine/records/mpn_codec.gd` parses and applies patches;
`engine/records/mpn_recorder.gd` produces neutral observations;
`game/records/mpn_archive.gd` adds metadata and storage. Its reader uses the
algorithms above without invoking the game engine. The examples alongside
this document are checked against that parser.

Known differences from a full strict validator: its JSON parser does not
explicitly reject duplicate object keys; serial parsing is permissive; it
accepts more whitespace/header-key forms; it does not validate timestamp
syntax, most annotation schemas, every optional object/stack field, counter
values, or global reference lifetimes. It accepts signed `damage` values
within the numeric range even though writers should never use negative marked
damage. Its per-line bound is checked after trimming and after skipping line
comments. Passing this parser is therefore weaker than passing this draft's
strict checks. Its writer enforces file/record budgets but does not prevalidate
every schema/line/collection bound before writing.

The recorder follows existing coarse state callbacks and selected typed
events. It does not capture every public choice, cost, pass, mana-production
fast path, replacement order or temporary effect. It detects observed hidden
intervals and common zone/lifetime changes, but an unobserved hidden round
trip is not a general guaranteed boundary. LAN recording starts after the
opening deal; it records counts rather than inventing the missing draws.
`definition_set` identifies the definition source, `rules_text` contains that
definition's text, and keyword/mode values are producer-specific. Tournament
games currently do not carry a shared tournament-series grouping.

These are documented implementation gaps, not permission for new producers
to weaken the public-information boundary or claim complete replay. This
specification does not change the wire version or silently upgrade the
prototype's coverage. An independent implementation should publish its own
coverage limitations and strict-validation behavior just as explicitly.
