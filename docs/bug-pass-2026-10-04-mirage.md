# Bug pass — the Mirage block, 2026-10-04

The owner, right after 0.50.11 shipped Pack 8: *"Then do one pass over
Mirage block and find bugs and fix them!"* Started from clean `f202623`
(0.50.11) with the gate green (635 scripts, 10,205 tests). Eight
read-only hunters covered the pack by area — Mirage creatures and combat;
Mirage spells and triggers; Mirage Auras, artifacts, costs, rules cards and
phasing; all of Visions; all of Weatherlight; the new engine mechanisms;
the fair AI; the duel screen, SGManalink and the pack infrastructure. Every
finding below was reproduced by a probe that failed on it. Eight fixers
then worked test-first on disjoint files: each regression failed for the
reported reason before its fix (engine fixer A ran its file against a
`git archive` copy of `f202623` to prove it).

New regression scripts:
`tests/unit/test_mirage_bugpass_engine_a.gd`,
`tests/unit/test_mirage_bugpass_engine_b1.gd`,
`tests/unit/test_mirage_bugpass_engine_b2.gd`,
`tests/unit/test_mirage_bugpass_engine_c.gd`,
`tests/cards/test_mirage_bugpass_cards.gd`,
`tests/ai/test_ai_mirage_bugpass.gd`,
`tests/ui/test_mirage_bugpass_ui.gd`,
`tests/ui/test_sgmanalink_mirage_bugpass.gd`,
`tests/unit/test_gain_life_text_2026_10_04.gd`.

`SgCompatibility.RULES_REVISION` moved to
`sgmanalink-mirage-bugpass-2026-10-04`; the SGManalink protocol is **27**
(Heat Wave's block-tax rows changed shape).

## The worst of what was found

- **The AI killed itself** with three cards: Final Fortune cast like Time
  Walk (it now carries Last Chance's role, at every difficulty), Infernal
  Contract at low life, Reign of Terror into its own life loss. Under the
  1997 rules it also took Pygmy Hippo's mana and burned to death, and it
  burned its last life on a Karoo's spare mana.
- **Cumulative upkeep resolved for a phased-out permanent** (CR 702.24a's
  intervening "if", 702.26b): Psychic Vortex drew for free and Heart of
  Bogardan blasted the opponent.
- **A human could not choose a land's entry payment** (Lotus Vale,
  Scorched Ruins, the Alliances entry lands): the question was asked
  outside any hold, so the heuristic sacrificed the first two lands. The
  land drop now waits on the question; declining puts the land into its
  owner's graveyard as printed, withdrawing keeps it in hand, and the
  decline line says so on both screens.
- **Sabertooth Cobra's ransom could not be paid on the local screen** (only
  the AI and network players could pay it). The territory menu now carries
  the ransom, Channel's life-for-mana and Guardian Angel's paid prevention.
- **The tutor picker showed a human their library's order** and let them
  cancel: it lists names alphabetically now.

## Rules fixes

Phasing: control Auras keep their timestamp place; a phased-out source no
longer satisfies "if it's still on the battlefield" (`F._same_trigger_source`
uses `is_present`; `F._same_trigger_object` keeps the old reading for the
last-known-information switches); Teferi's Isle stops phasing under
Celestial Dawn (CR 305.7). Peace Talks covers the turn that actually comes
next. An end-step "sacrifice it" made by a spell or an activation no longer
makes a thief sacrifice what they stole (Tidal Wave, Soulshriek, Pyric
Salamander, Dragon Whelp, Nalathni Dragon, Krovikan Elementalist); cards
that print "its controller sacrifices it" (Celestial Sword, Goblin Ski
Patrol) keep that reading. Teferi's Veil, Glyph of Doom, Infinite Authority and Time
Elemental use real stack triggers at end of combat. Activation bans and cost
modifiers stop while their source is tapped under the 1997 rule or silenced
(Null Rod, Cursed Totem, Helm of Awakening, Mana Matrix …). Hall of Gemstone
leaves colourless mana alone. Ward of Lights exempts only its own protection.
Chaosphere reads flying after layer 6. Land-type changes apply in timestamp
order. +1/+1 and -1/-1 counters annihilate under the modern presets (CR
704.5q; derived from the 1997 damage-window fork). "Whenever ~ is dealt
damage" fires once per damage event for the total (a new `WAS_DEALT_DAMAGE`
event: Binding Agony, Mortal Wound, Fungusaur, Living Artifact, Lich). A spell
cast from a graveyard is a spell for targeting (Dense Foliage) and cannot
target itself. A face-down or silenced creature loses Gravebane Zombie's and
Firestorm Phoenix's replacements. Psychic Transfer exchanges nothing when a
player can't gain life. Sirocco and Lure of Prey read live colours.
`settle_delayed_trigger` no longer breaks when a listener advances the game
mid-payment.

## The AI and the screens

The AI: card choices that lose a card now say so (Stampeding Wildebeests,
Shrieking Drake, Preferred Selection, Flash, Sealed Fate, Dream Cache);
Spinning Darkness books only a payment it can make; Three Wishes is cast in
our main phase; Grave Servitude and Coils of the Medusa are not hung on a
1-toughness body; Torrent of Lava's X beats the shields it grants; Hope
Charm's pick is respected; Waiting in the Weeds, Tidal Wave, Zombie Mob,
Phyrexian Dreadnought and Goblin Grenadiers are not thrown away; Pillar Tombs
takes a small creature before 5 of 8 life. The matched Deck Lab studies are
unchanged (Flash / Costs −0.5 ± 8.9, Shields / Knights +5.0 ± 6.3, controls
byte-identical).

The screens: spells with an unpayable additional cost are not lit; Circling
Vultures can't be discarded while its own cast waits; the graveyard ring
shows only what can be played now; X for "X targets" is capped by the legal
targets; Heat Wave's note survives a take-back. SGManalink: Heat Wave's tax
rows no longer overflow the view (one row per tax), a view the host's own
check refuses is reported instead of dropped, and the same Vultures, X and
ring fixes apply over the network.

Text: tokens carry their keywords' rules text; ability menus name every
non-mana cost and state an activation limit exactly once; "you gain 1 life";
Help's Heart of Bogardan and shared-reprint wording.

## Left open

- "Whenever ~ deals damage" (the dealer's side: Spirit Link, El-Hajjâj,
  Zebra Unicorn, Emberwilde Caliph) still triggers once per damage packet;
  the totals are the same.
- Pack 8's `README.txt` still says the shared reprints "first appeared in"
  the older packs; it is checksummed inside every built ZIP, so the wording
  waits for a deliberate pack revision.
- Energy Vortex's {X} is never activated by the AI (like Ventifact Bottle);
  Preferred Selection's payment is never taken.
- `tests/_hunt/h1/probe_h1_1.gd` expected an engine prompt for the Cobra's
  ransom; a screen action is the faithful model ("before that step").

## Verification

Final full GUT gate: **10,409/10,409 tests / 479,524 asserts / 644
scripts**, six shards, strict wrapper exit 0, no parse error, skipped
script, failing test or leak line (204 tests more than 0.50.11). Python: 508
tests, eight platform skips. `git diff --check` clean. The hunters' probes
lived in a git-excluded `tests/_hunt/` and were deleted before the gate.

`tools/pack_8_duel_audit.gd --rounds 10 --seed 87000`: **180/180 full
duels**, 11–56 turns, no stall, no engine error; 138 of the 141 Mirage-block
names in the decks were cast or played. The real-screen soaks
(`tools/pack_8_ui_soak.gd` and `tools/duel_soak.gd`, modern and fifth, demo
and fuzzed human, seeds 1000/1037/1074): **24/24 duels**, nothing beyond
Xvfb's V-Sync and input-method notices. The network fixer's soak: 20 duels,
no invalid view, no refusal; `tools/lan_smoke.sh` clean on protocol 27. A
fresh Linux export passed `--verify-pack-8` against the real ZIP (1,549
identities, 652/652 scripts, 1,368/1,368 pictures, 9/9 textures, 0 rules
pending). Evidence is local under `../shandalar-build/pack-8-work/bugpass/`.
