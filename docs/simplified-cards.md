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

| Card | What's simplified | Needs | Who benefits |
|---|---|---|---|
| Aswan Jaguar | The random creature type is rolled over the opponent's library, hand, battlefield AND graveyard; the printed card reads their DECK only. **Re-reasoned 2026-09-01:** the 1997 FAQ that ships inside s30 (`s30/shandalar-faq.txt`, Dana Huyler 5/7/97 — secondary, but contemporaneous) describes it as *"pick a random type of creature that the player has in deck or graveyard"*, so the GRAVEYARD half may be the original's own behaviour and only the hand and battlefield are ours. Read that before narrowing the helper | Narrowing `RandomEffects.creature_type_of` to library (+ graveyard?), shipped with the wave-45 test that pins today's behaviour | Usually the Jaguar's controller — a type they can already see in play is rollable |
| ~~Blaze of Glory, Two-Headed Giant of Foriys~~ **LIFTED 2026-09-02** | The engine used to assign ONE attacker per blocker, so *"can block any number of creatures"* and *"can block an additional creature"* both became one block | Built: `CombatState.extra_blocks` + `CardData.extra_blocks` / `CardInstance.extra_blocks_this_turn` (CR 509.1b), pinned by `tests/unit/test_one_to_many_blocks.gd`. **The HUMAN half is not there**: `duel_screen.gd`'s block picker still points one blocker at one attacker, so a human cannot declare the second block a rules engine now accepts — see docs/ROADMAP.md | — |
| Illusionary Mask | The masked creature goes straight onto the battlefield face down instead of being CAST as a face-down spell (WHICH creature is masked is the controller's own choice, asked on resolution) | Face-down casting | Nobody — nothing in the pool can counter the difference |
| Nebuchadnezzar | The names that may be chosen are the DISTINCT CARD NAMES IN THE TARGET OPPONENT'S LIBRARY, GRAVEYARD, BATTLEFIELD AND EXILE — their deck minus the one zone it would be cheating to read. Their HAND is excluded on purpose, which is the anti-cheat guarantee; the cost is that a name whose every copy is already in hand cannot be said. Same bound as Petra Sphinx, aimed the other way | Free-text card naming, and a UI that can take one | The victim, in the one case where they hold every copy of a card |
| Petra Sphinx | The names that may be chosen are the DISTINCT CARD NAMES IN THE CHOOSER'S OWN LIBRARY, not any name in Magic. Naming a card that cannot be there is never a play and a player already knows their own decklist, so this is a bound rather than an information change — but a name that is genuinely absent (a bluff, or an opponent's card) cannot be said | Free-text card naming, and a UI that can take one | Nobody — the option list is a superset of every name worth saying |
| Power Leak | The amount of mana that may be paid is capped at {2} — the printed card allows any amount, and the third mana onward prevents nothing. The cap is the original's own wording (*"That player may pay up to {2}"*, Duel.hlp) and is invisible except under the optional 1997 MANA BURN rule, where dumping a bigger floating pool into the Aura would dodge the burn | An unbounded number prompt | The victim, and only with mana burn switched on and mana already floating |
| Text changes (Magical Hack, Sleight of Mind) | A text change reaches SUBTYPES, landwalk types, protection colours and a basic land's mana — not arbitrary rules text, which this engine stores as behaviour rather than words. (The pair of words IS the caster's: two prompts on resolution, `@MAGICAL_HACK` / `@SLEIGHT_OF_MIND` — lifted 2026-09-02.) **Narrower than the 1997 ruling (noted 2026-09-02):** Duel.hlp lets either target ANY spell or permanent, colour words or not, and edits every occurrence in the text box — so Sleight of Mind re-pointing a Circle of Protection: Red to blue, or a Karma to Islands under Magical Hack, are printed use cases this engine cannot do; ours only offers targets carrying a word it models (a protection colour, a land subtype / landwalk) and refuses the rest | Rules text as data | The Circles of Protection, Karma, the Elemental Blasts, Flashfires / Tsunami and every other card whose colour or land word is behaviour here — the classic Sleight/Hack tricks on them are simply not available |
