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

`grep -rl SIMPLIFIED cards/sets/ cards/optional/` must always agree with this table: every
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
Nebuchadnezzar from the target opponent's; both rows lifted 2026-09-07;
Demonic Consultation from one's own — corrected 2026-09-17, it had offered
every name in the pool with the decklist as a default), and
a text change picks from the words the engine models (the Text changes row
below stays, and says so). Do not re-litigate either.

| Card | What's simplified | Needs | Who benefits |
|---|---|---|---|
| Fatal Lore; Library of Lat-Nam; Misfortune (Pack 5) | The opponent chooses the mode on resolution, not during announcement. Fatal Lore also chooses its zero-to-two opposing creature targets on resolution, respecting targeting restrictions, before its destruction and optional draw. | A held announcement-time opponent-mode choice that then returns control to the caster for targets before costs are paid. | The opponent can choose using later board information; both players lose the normal opportunity to respond knowing the chosen mode and Fatal Lore targets. These differences are printed on the cards. |
| Balduvian Shaman (Pack 3) | Color-word rewriting targets only the five colored Circles of Protection you control, provided the Circle is white and has no cumulative upkeep. Choose another color; the Circle gains the full cumulative upkeep {1}. Other white enchantments are not eligible. | General behavior-aware rewriting of arbitrary rules text. The limited-list adaptation is shown in the card's rules text. | Both players: the controller loses non-Circle combinations, and the opponent can see the restricted target list and increasing upkeep cost. |
| Chaos Orb | The physical one-foot flip, full turn-over check and every nontoken permanent physically touched are replaced by a 50% coin flip; a win destroys one uniformly random nontoken permanent controlled by the chosen opponent. The Orb still must remain on the battlefield to do anything and destroys itself after either result. | Intentionally remains digital. A faithful physical-dexterity simulation has no stable or accessible meaning on a 2D rules board. | Depends on the physical layout and dexterity the tabletop card would have tested. The digital result can remove one valuable permanent, but misses half the time and can never remove several. |
| Debt of Loyalty; Matopi Golem (Pack 8); Skeleton Scavengers (Pack 9) | "If/when it regenerates THIS WAY": when the creature carries other regeneration shields too, its controller is not asked which one applies (CR 616.1) — any shield without the rider is spent first, and the rider (the control change, the -1/-1 counter) applies only when the shield it rode on is the one left. Skeleton Scavengers' rider is a gain (a +1/+1 counter), so the opposite order is taken: while one of its own shields is pending, the next regeneration is taken to have used it (oldest first). | Regeneration shields that carry their source, and a choice among them at destruction time (engine shields are interchangeable counts). | The creature's controller, always: spending the rider-free shield first is their dominant choice (no -1/-1 counter on their Golem, no creature handed to the Debt's caster). For Skeleton Scavengers the counter is always taken, though a controller could prefer to keep its next regeneration cheaper. |
| Falling Star | The physical one-foot flip, turn-over check and touched area are replaced by one or two creatures the caster chooses, each with an independent 50% hit. A hit still deals 3 damage and taps a survivor. | Intentionally remains digital for the same accessibility and reproducibility reason as Chaos Orb. | The caster chooses only desirable creatures and can never clip their own board; the two-target cap represents a bounded footprint and every chosen creature has a 50% miss chance. |
| Game of Chaos (Pack 3) | A resolution stops after 30 flips even if the last winner would choose to continue. Earlier flips, optional continuation, doubled stakes and life transfers are unchanged. | Arbitrary-precision life/stake arithmetic and a user-safe unbounded interaction. | Only games that would continue past the thirtieth flip differ; the boundary favors whichever player is ahead at that point. The limit is printed in the digital rules text. |
| Illusionary Mask | The masked creature goes straight onto the battlefield face down instead of being CAST as a face-down spell (WHICH creature is masked is the controller's own choice, asked on resolution); and the creature masked is any creature card of mana value ≤ X — the colours of the mana spent on {X} are not checked (five colourless can mask a Serra Angel; campaign 2026-10, w1-8) | Face-down casting — a face-down 2/2 creature spell on the stack, an engine mechanic rather than a prompt. Left 2026-09-07 in the spirit of the owner's ruling above (simple, reuse what exists); no cheap path. The colour check needs a per-activation record of which mana paid {X}, which the engine does not keep | An opponent holding Counterspell, Remove Soul or the like: a face-down creature SPELL could be countered, a creature put straight onto the battlefield cannot (corrected 2026-09-07 — the row used to say nobody); the colour check favours the Mask's controller (artifact mana masks a coloured creature) |
| Living Death (Pack 9) | The cards it returns enter one after another in APNAP order instead of at the same instant, so a returned "whenever another creature enters" ability (Soul Warden) sees only the creatures that enter after it (CR 603.6a). | An engine helper that puts several cards onto the battlefield together and announces their entry afterwards. | Rarely matters; either player. |
| Shahrazad | No nested Magic game is created. One coin is flipped; the losing player loses half their life, rounded up. | A complete re-entrant duel state, nested UI, nested decisions and a safe return into the parent stack resolution. Deliberately deferred unless subgames become a project-level feature. | The player who would have lost the subgame may instead win the coin flip; the reverse is equally possible. The shortcut removes all deck-building and play-skill advantage inside the subgame. |
| Text changes (Magical Hack, Sleight of Mind, Mind Bend; Whim of Volrath, Pack 9) | A text change reaches SUBTYPES, landwalk types, protection colours and a basic land's mana — not arbitrary rules text, which this engine stores as behaviour rather than words. Mind Bend (Mirage, Pack 8) offers either kind of word from the same list, and only to permanents carrying one. (The pair of words IS the caster's: two prompts on resolution, `@MAGICAL_HACK` / `@SLEIGHT_OF_MIND` — lifted 2026-09-02.) **Narrower than the 1997 ruling (noted 2026-09-02):** Duel.hlp lets either target ANY spell or permanent, colour words or not, and edits every occurrence in the text box — so Sleight of Mind re-pointing a Circle of Protection: Red to blue, or a Karma to Islands under Magical Hack, are printed use cases this engine cannot do; ours only offers targets carrying a word it models (a protection colour, a land subtype / landwalk) and refuses the rest Whim of Volrath (Pack 9) has Mind Bend's word list and target limit (only permanents carrying a protection colour, land type or landwalk), and its change lasts until end of turn. | **Nothing — ruled, 2026-09-07.** The owner: *"When you can rewrite the card text - the same - you should be presented with a limited list so make things as simple as possible."* The limited word list IS the design; the row stays so the gap is on record, not as a queue item | The Circles of Protection, Karma, the Elemental Blasts, Flashfires / Tsunami and every other card whose colour or land word is behaviour here — the classic Sleight/Hack tricks on them are simply not available |
| Timmerian Fiends (Pack 4) | Only nontoken cards can participate in its ownership exchange; token copies cannot activate it, and artifact tokens are not legal targets. Ordinary cards retain the artifact owner's ante choice, ownership exchange and movement from anywhere to the new owners' graveyards. | Token ownership and collection-settlement semantics, including vanished token sources. The limitation is printed in the digital rules text. | Players whose artifact tokens would be targeted; the Fiends' controller loses token-copy combinations. |
| Word of Command | The controller sees the target opponent's eligible nonland cards and chooses one to discard. They do not control that opponent, make the opponent play the chosen card, restrict the opponent's mana abilities, or control a chosen spell through its resolution; lands are not eligible in the adaptation. | Controlled-player actions, temporary authority over another seat's decisions, restricted mana activation during a nested cast, and controller handoff for the resulting spell. | Usually the caster: the adaptation is guaranteed hand disruption when an eligible card exists, although it cannot obtain the much larger value of forcing the opponent to cast a harmful card. |
