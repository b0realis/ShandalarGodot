# Simplified cards — the fidelity ledger

Every implemented card that deviates from its printed behavior in ANY way
is listed here, one row per card. This is the project's promise that no
shortcut is silent: the card file carries a `SIMPLIFIED:` comment at the
exact spot, and this ledger is the queue for future fidelity passes.

Rules of the ledger:

- **Adding a card with a shortcut?** Mark the site `SIMPLIFIED:`, add a
  row here, and say who benefits (a deviation that's invisible in play is
  still a deviation).
- **Lifting a simplification?** Delete the row, delete the marker, pin the
  full behavior with a test. (Jade Statue's end-of-combat expiry was the
  first lift — wave 8.)
- Engine-wide simplifications (combat damage ordering, the layer system,
  mulligans...) stay in `docs/ROADMAP.md` — this file is card-scoped only.
- Keep the table sorted by card name.

`grep -rl SIMPLIFIED cards/sets/` must always agree with this table: every
marked card's NAME appears somewhere in it, either as its own row or named
inside a GROUP row (several cards share one deviation — the banding lands,
the mana batteries, the text-changing spells). Spell names out in group
rows so the check stays greppable.

## "It needs a prompt" is not a deviation — read this before adding one

**Corrected 2026-09-01, after twenty-one rows turned out to rest on it.** A
long family of rows said a decision was "the DecisionAgent's answer rather
than a prompt" and named *the await-based human prompt* as what they
needed. That prompt was CONSIDERED AND REJECTED (docs/ROADMAP.md — a
GDScript coroutine does not propagate through `Callable.call()`), and what
shipped instead in its place, §1.3, already answers these rows: a question
asked through the `DecisionAgent` funnel (`choose_yes_no`, `choose_card`,
`choose_color`, `choose_discard`, `choose_option`/`choose_number`) from
inside a stack resolution IS the human seat's prompt. `MtgGame._preflight`
runs the resolution over a rewind point, finds the question, holds the duel
open on `awaiting_choice`, and `answer_choice` feeds the answer back;
`HumanAgent.can_answer` takes all five kinds and the duel overlay has a
case for each. Every other seat answering its own question is not a
shortcut — it is what an agent is.

So the test is not "does a prompt exist" but **"is the decision delegated?"**:

- The card calls `game.agents[pid].choose_*` from a resolution, and the
  value it computes is only the `hint` → **no row.** Pin it with a seat
  that answers against the hint (`tests/cards/test_fidelity_2026_09.gd`
  has the pattern).
- The card computes the answer and never asks → **a real row**, and
  usually a small fix rather than a row: route it through the funnel.
- The ask is made from a TURN-BASED ACTION rather than a resolution (the
  untap step, the draw step) → it needs the TURN-BASED HOLD, not the
  pre-flight, which only wraps stack resolutions. The untap step has it
  since 2026-09-02 (`MtgGame._untap_step`: Smoke's "Select creature to
  untap.", the "may choose not to untap" permanents' "Don't untap."), so
  a question asked from there is a prompt like any other; an ask from a
  turn-based action that does NOT yet hold is still a real row.
- The engine narrows what may be answered (a capped count, a bounded name
  list, a floor the rules do not impose) → **a real row**; the bound is
  the deviation, not the asking.

## Naming a card, rewriting a card — the owner's ruling (2026-09-07)

Neither gets a free-text box or a list of every name in the pool. The
owner, 2026-09-07: *"Many of these cards have player input window that we
can reuse. When you have name a card: you should probably only display
selection of cards from opponents deck (as you can see the deck beforehand
in real mtg). When you can rewrite the card text - the same - you should be
presented with a limited list so make things as simple as possible."* So a
card is NAMED from a DECKLIST — `MtgPlayer.deck_names`, what a player
brought to the duel, never a scan of zones (Petra Sphinx from one's own,
Nebuchadnezzar from the target opponent's; both rows lifted 2026-09-07), and
a text change picks from the words the engine models (the Text changes row
below stays, and says so). Do not re-litigate either.

| Card | What's simplified | Needs | Who benefits |
|---|---|---|---|
| Illusionary Mask | The masked creature goes straight onto the battlefield face down instead of being CAST as a face-down spell (WHICH creature is masked is the controller's own choice, asked on resolution) | Face-down casting — a face-down 2/2 creature spell on the stack, an engine mechanic rather than a prompt. Left 2026-09-07 in the spirit of the owner's ruling above (simple, reuse what exists); no cheap path | An opponent holding Counterspell, Remove Soul or the like: a face-down creature SPELL could be countered, a creature put straight onto the battlefield cannot (corrected 2026-09-07 — the row used to say nobody) |
| Text changes (Magical Hack, Sleight of Mind) | A text change reaches SUBTYPES, landwalk types, protection colours and a basic land's mana — not arbitrary rules text, which this engine stores as behaviour rather than words. (The pair of words IS the caster's: two prompts on resolution, `@MAGICAL_HACK` / `@SLEIGHT_OF_MIND` — lifted 2026-09-02.) **Narrower than the 1997 ruling (noted 2026-09-02):** Duel.hlp lets either target ANY spell or permanent, colour words or not, and edits every occurrence in the text box — so Sleight of Mind re-pointing a Circle of Protection: Red to blue, or a Karma to Islands under Magical Hack, are printed use cases this engine cannot do; ours only offers targets carrying a word it models (a protection colour, a land subtype / landwalk) and refuses the rest | **Nothing — ruled, 2026-09-07.** The owner: *"When you can rewrite the card text - the same - you should be presented with a limited list so make things as simple as possible."* The limited word list IS the design; the row stays so the gap is on record, not as a queue item | The Circles of Protection, Karma, the Elemental Blasts, Flashfires / Tsunami and every other card whose colour or land word is behaviour here — the classic Sleight/Hack tricks on them are simply not available |
