# The gap review — 2026-11-10

The owner, after the bugfix round of the same day: *"fire off agents to
review items on this list (it is bit older list so somethings may have
changed!; previous review don't tackle these)"*. The list was what the
reviews of October had left open (`docs/whole-project-review-2026-10-21.md`,
"Left open"; `docs/hunt-campaign-2026-10-21.md`, "Still open"): most of the
per-set AI tactics, the inner layers of continuous effects, much of the
duel screen, the LAN lobby, several pack-building tools, four Ctrl-C tests
said to fail under load, and five smaller items.

Seven reviewers read those areas without changing a file, each finding
proven by a check that failed on the code as it stood. They found 42
defects — one serious, 13 medium, 28 small — and one cost. The owner ruled
on the questions (below) and said: fix all. Seven fixers then worked at
once on disjoint files; every fix carries its failing check as a permanent
test, run red before the fix and green after, and every existing suite
touching a fixer's files was run again. New test files are listed in
`docs/CODE_MAP.md` under "The gap review (2026-11-10)".

## What had changed since the list

- **Already fixed:** the five duel-screen suspicions of the hunt (the bug
  campaign c12 of 2026-10-27 and the polish pass after it); the open LAN
  host (c12); the MCP `read_deck` fence for named decks (c12); the four
  Ctrl-C tests (0.50.61 — the cause was a SIGINT inherited as ignored, not
  the load); every one of the five smaller items (Test hands' Clear all
  resets the seats to Magic Battle's lives, deck notes keep their blank
  lines, "Ante must be on" holds, Fireball's division is fixed at cast,
  the duel log is trimmed by writing beside and renaming).
- **Timestamps** in the layers are sound since 0.50.45, Pack 9, c12 and
  Pack 10.
- **Still open, and found here:** what follows.

## The owner's rulings

- **The layers follow the Comprehensive Rules (CR 613).** An effect that
  removes abilities (Titania's Song, Humility) no longer switches off the
  type, color and size effects of the cards it silences: they apply in the
  earlier layers first. Kormus Bell under Titania's Song: the Swamps are
  still 1/1 black creatures. The 2026-09 audit had ruled the other way on
  purpose (`docs/audit-2026-09.md`, row 33); that row is lifted.
- **Illusionary Mask refuses ante cards with Ante off** — its text casts
  the creature it hides. Effects that put a card into play without casting
  it are not bound (the card arrives; its abilities stay refused).
- **The developer tool server writes only into its workspace** and the
  Deck Lab's default ratings ledger.
- **Defaults the owner may still change:** an Animate Artifact older than
  Titania's Song wins by timestamp (CR 613.8b); the controller of a
  face-down permanent may look at it in their own question and the
  Showcase (CR 708.5), never another seat; the computer waits while a
  human seat's X question, tutor picker or mode menu is open; deck names
  stay public at LAN tables; an armed "Declare X winner" disarms when its
  pairing changes; the pack builders' quick help lists `fetch` last, as a
  developer step; the computer pays Aether Storm's 4 life only for
  creatures worth more, and winds up a Clockwork creature only when it is
  not attacking that turn.

## The AI, first half — Fallen Empires, Ice Age, Homelands, Alliances

- Vodalian War Machine no longer pumps a Machine that dies anyway (the
  Merfolk tapped for it died too).
- Tourach's Gate no longer kills its own blocked attacker.
- Phelddagrif's flying and trample are bought only when they push damage
  past every blocker, and its gifts (a Hippo, 2 life) are charged.
- A retarget's ranking and Deflection's question no longer read a card
  under Illusionary Mask (hidden information; at every difficulty).
- Kjeldoran Royal Guard and the Mercenaries' shield wait for blocks.
- Melee is never cast when it throws away lethal damage.
- Aether Storm and the Clockwork creatures, as ruled above.

Three pack duel audits with new seeds (Packs 3, 4, 5): 36 full duels each,
clean.

## The AI, second half — Portal, Mirage, Tempest

- The computer answered a lethal spell with a Portal or Second Age answer
  (Diabolic Edict, Exile, Ray of Command, Broken Visage) ahead of its
  Counterspell, and died with the counter in hand. The counter now comes
  before every per-set answer — and a redirect that wins comes first of
  all: holding Counterspell and Deflection against a lethal Fireball, the
  computer deflects it into its opponent.
- A divided spell is read by each target's share: Pyrotechnics' single
  point no longer cashes out a Spike, sends a Serra Angel to Cold Storage
  or wastes Mystic Veil, and a Fireball split four ways is a quarter of X
  at each (`EffectIntent.damage_from`, `kills_from`, `divided_evenly`) —
  in the Mirage and Tempest readers, the Alliances bounce, Force of Will's
  lethal check and three readers of the AI's own.
- Relentless Assault is cast after an attack, not before the first combat.
- A Licid's twin key no longer reads the card under Illusionary Mask.
- Last Chance is not bought when this turn's attack already wins.

Pack duel audits on the review's seeds (Packs 6, 8, 9): 28, 36 and 72 full
duels, clean.

## The layers

- **The ruling.** "Loses all abilities" (Titania's Song, Humility) now
  runs after layers 4 and 5, so the type and color effects of the cards it
  silences apply first: Kormus Bell under the Song still makes the Swamps
  1/1 black creatures, a Humility does not stop a creature's color effect,
  Darkest Hour under Opalescence and Humility still paints. An effect's
  later halves reach what its first half reached (CR 613.6,
  `ContinuousEffects.lock_in`). Titania's Song is three statics now — its
  type in layer 4, its ability removal in layer 6, its size in 7b — and,
  older than an Animate Artifact, loses to it by timestamp (CR 613.8b).
- The Song lingering after it leaves keeps its own timestamp.
- Kormus Bell paints black in layer 5, so a Chaoslace cast after it wins.
- Kormus Bell, Living Lands and Living Plane set their 1/1 in layer 7b, so
  a newer one beats an older Verdant Touch; Living Plane no longer skips a
  land that is already a creature.
- Under the 1997 rule that a tapped artifact's effects stop, an artifact a
  static made a creature (Animate Artifact) is excepted, as artifact
  creatures are.
- Sleight of Mind and Mind Bend rewrite only the protection a card's text
  prints, never one another effect granted (CR 612.3), and Sleight of Mind
  offers only those words.
- The definition pass off the battlefield walks only the cards that carry
  one, not every library card: about 44% of a quiet board's recalculation.

`docs/audit-2026-09.md` rows 33 and 81 are marked lifted;
`docs/mechanics.md` rows 3a–4 say the new order.

## The duel screen

- At a private hotseat a click acts only for the seat deciding: it can no
  longer tap the other seat's lands (which mana-burned them) or start their
  abilities. Piracy's lands and "any player may" abilities still answer.
- A Clone or Doppelganger question no longer names a face-down creature;
  the controller's own reads `Name (face down) #id`, another's `Face-down
  creature #id`.
- The X question and the tutor picker close when the duel ends.
- At a two-human table a seat's own end step is no longer "their turn is
  ending".
- At a UI scale of 130% or 150% the duel log stops above the Situation
  Bar, so its newest lines show.

## The LAN lobby

- A refused automatic pass can no longer spin the table into a crash, and
  a closing connection counts as offline.
- A guest whose seat ended gets the tabs and Disconnect back; a host that
  closed is not retried; the table's banner says why and offers Leave
  table instead of "Reconnecting…".
- Escape and a pad's B close the lobby's own popups first; B closes
  sub-windows and leaves pages.
- A table picked at one host no longer seats the player at another's; the
  deck sizes read "8–250 cards (40+ advised)"; long deck names are trimmed
  in the Game Browser; the Master Panel takes the keyboard focus; the deck
  picker drops "Connection lost" once reconnected; the waiting room no
  longer rebuilds when another table changes; a computer seat's hidden
  deck is not added.

## The tools

- The developer tool server's raw Lab and AutoDeck switches are fenced
  like its named decks; `user://` paths and the Lab's internal `--worker`
  are refused; writes as ruled above.
- `duel_soak.sh` and `run_tests.sh` set their Ctrl-C traps before they
  start Godot; the LAN smoke test waits for a pid to be written, cleans up
  after itself, and stretches its bounds by a measured start time, the
  measurement and the load in its failure messages.
- A `.tar.gz` skin stores linked pictures as pictures, and no user or
  group names.
- Pack builders 1–10 verify and rebuild byte for byte; their quick help
  lists `fetch` last.

## The smaller items

- A deck's notes keep the first line's indent.
- The running duel log's trim no longer drops a whole long duel.
- Illusionary Mask and ante cards, as ruled above.

## Still open

- At an SGManalink table a seat cannot look at its own face-down
  permanent (the referee sends no identity; a protocol change).
- ~~A Clockwork creature wound up in its controller's upkeep stays tapped
  and cannot block; the computer weighs only the attack.~~ Ruled
  2026-11-11, the owner: *"Yes, oldschool!"* — it stays as it is.
