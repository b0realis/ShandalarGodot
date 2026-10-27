# Bringing MPN to another Magic game — a brief for an implementing agent

This brief can be handed as it is to a person or a coding agent working in
another Magic: The Gathering engine (an open-source client, a simulator, a
tournament tool). It asks for three things — record games as MPN, read them,
and show them as a move list — and says how the work is accepted.

MPN (Magic Public Notation) is a proposed open format for the **public
history of a two-player Magic game**: what both players and any onlooker at
the table could see, never a hidden card. It is independent of any engine.
Questions and reports: an issue at
<https://github.com/b0realis/ShandalarGodot/issues> with "MPN" in the title.

## What to read

1. [`mpn-specification.md`](mpn-specification.md) — MPN 0.1, the file
   format: headers, the public state, handles, the events, ordering, limits
   and the conformance checklist (§12).
2. [`mpn-move-list.md`](mpn-move-list.md) — the move list: how a record is
   told for people, exactly.
3. [`mpn-examples/`](mpn-examples/) — four records and two expected move
   lists, the acceptance tests.

The reference implementation is this project (GDScript, Godot 4):
`engine/records/mpn_codec.gd` (read and validate), `engine/records/mpn_recorder.gd`
(write), `engine/records/mpn_move_list.gd` (the move list). Read them for
orientation; write your own in your engine's language and idiom.

## The task

### 1. Record a game as MPN 0.1 (the writer)

Observe the game as a **third party at the table** and write one `.mpn` file
per game:

- the headers (`Notation "MPN/0.1"`, `Visibility "public"`,
  `Coverage "public-observations"`, `Started`, `Match`, `Game`, the two
  players' names, and the recommended ones);
- an initial `state` with every required section, then a `state` patch
  whenever the public table changes and an event for each public action
  (`land`, `cast`, `activate`, `attack`, `block`, `damage`, `enter`,
  `leave`, `die`, `discard`, `draw` with a count, `reveal`, `regenerate`,
  `mana_burn`, `result`, and the rest the spec lists);
- **public handles** (`o1`, `o2`, …) for public objects only: a new handle at
  every zone change, retired when a card leaves public view, never reused;
  stack handles (`s1`, …) for stack entries;
- **never** a hidden card: no hand contents, no library order, no face-down
  identity, no RNG state, no private choice. Revealed cards are public only
  as long as the rules say so.

Two lessons from the reference implementation:

- Write a `state` patch **before** the event that describes it, where your
  engine lets you; readers must not depend on it, but the move list reads
  best that way.
- When a card leaves play for a place no one sees (a token ceasing, a card
  returned to a hand or a library), its handle is retired — but the `leave`
  and `die` events should still name it, **by the handle it had** (MPN 0.1
  §4: historical records keep their handles). A reader names it from its
  history; without the handle it can only guess.

### 2. Read MPN 0.1 (the reader)

Parse and validate as §9–§10 require (fail closed: a malformed record is an
error, not a partial game), fold `state` patches into the public table at any
serial, and never execute anything a record says.

### 3. Show the move list

Implement [`mpn-move-list.md`](mpn-move-list.md) exactly — the tags, the
symbols block, each turn under its player, one action a line under its phase,
the result — and offer it where your players look at past games, with a way
to copy it and save it as text.

## Acceptance

Your implementation is accepted when:

1. **The move lists match byte for byte**: your renderer turns
   `mpn-examples/knights-and-raiders.mpn` into exactly
   `mpn-examples/knights-and-raiders.txt`, and
   `mpn-examples/mandurang-and-hydra.mpn` into exactly
   `mpn-examples/mandurang-and-hydra.txt` (UTF-8, LF, a final LF).
2. **Your reader accepts all four example records** and rejects broken ones
   (a truncated line, a wrong serial, an unknown event kind, events after the
   result) with an error.
3. **Your writer's records pass your reader**, and a game you record renders
   to a move list in which every land, spell, ability and attack of the game
   appears in its turn, and each player's last life in a turn equals the
   life the record shows at that turn's end.
4. **Privacy**: two games identical in public play but different in hidden
   cards (hands, library order) produce identical records apart from the
   headers' times and IDs.

## Pitfalls

- **One card, many handles.** A spell is one handle on the stack and another
  once it resolves into play; never join handles by name.
- **Lives arrive before the damage that explains them**, in the reference
  recorder. Hold a life change pending until a `damage` (or `mana_burn`)
  claims it; tell it on its own line otherwise.
- **Combat damage belongs to the combat**, not to a pump or a spell cast
  between the attack and the damage: the move list's §6 says where it goes.
- **Characters, not bytes**, when padding the phase and symbol columns —
  `⚔`, `†`, `→` are one character each.
- **The minus in a life loss line is U+2212** (`W −2 → 18`), the plus ASCII.
