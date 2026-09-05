# Adding Cards

The card pipeline is designed so that adding a card (or a whole set) touches
exactly two files — the card and its test — and zero engine code, as long as
the mechanics already exist. This mirrors mage-go's set pipeline, which our
local clone shows scaling to ~900 cards.

## The rules

1. **One card per file.** `cards/sets/<set>/<snake_case_name>.gd`. The folder
   name is the set code; dropping the file in the folder ships the card (the
   registry scans folders — there is no list to update).
2. **Every card file documents itself.** The header doc comment carries: name
   line with cost/type/rarity, exact oracle text, implementation notes, and
   any simplification (with a row in docs/simplified-cards.md).
3. **Test-first, always.** A card without a test in `tests/cards/` does not
   merge (vanilla creatures may share the set's generic tests).
4. **Cards never touch engine internals.** They compose effects and abilities
   through the CardData builder. If a card needs a mechanic the engine lacks,
   the mechanic is added to `engine/` first — as its own class, with its own
   engine test — then the card file stays declarative.

## Walkthrough: a vanilla creature

`cards/sets/2ed/grizzly_bears.gd`:

```gdscript
extends CardScript
## Grizzly Bears — {1}{G} — Creature — Bear — 2/2 (Alpha, common)
## Oracle: (no rules text — vanilla creature)

func build() -> CardData:
    return CardData.new("Grizzly Bears", "{1}{G}", Mtg.CardType.CREATURE) \
        .pt(2, 2) \
        .with_subtypes(["bear"]) \
        .oracle("")
```

## Walkthrough: a targeted spell

```gdscript
extends CardScript
## Lightning Bolt — {R} — Instant (Alpha, common)
## Oracle: Lightning Bolt deals 3 damage to any target.

func build() -> CardData:
    return CardData.new("Lightning Bolt", "{R}", Mtg.CardType.INSTANT) \
        .spell(DamageEffect.new(3).any_target()) \
        .oracle("Lightning Bolt deals 3 damage to any target.")
```

Multi-sentence cards chain `.spell(...)` calls — one effect per sentence, in
order. Each targeting effect contributes one target slot; at cast time the
caller supplies one `TargetRef` per slot, in the same order.

## The toolbox

| You need | Reach for | Example file |
|---|---|---|
| Deal damage | `DamageEffect` | lightning_bolt.gd |
| Draw cards | `DrawEffect` (`.target_player()` to aim it) | ancestral_recall.gd |
| Destroy | `DestroyEffect` + `TargetSpec.creature(desc, filter)` | terror.gd |
| +P/+T until EOT | `PumpEffect` | giant_growth.gd |
| Filtered targets | a `static func` predicate in the card file | terror.gd |
| "{cost}: effect" | `ActivatedAbility` | prodigal_sorcerer.gd |
| Tap for mana | `ManaAbility` (stackless, CR 605.3) | sol_ring.gd, forest.gd |
| "Whenever X..." | `TriggeredAbility` + `Mtg.EventType` | ankh_of_mishra.gd |
| Aura | `.enchants(spec)` + `StaticAbility` | holy_strength.gd |
| Keywords | `.with_keywords([Mtg.Keyword.FLYING, ...])` | serra_angel.gd |
| "Choose one —" | `.mode(label, [effects])` per mode (+ `.with_ai_mode`) | healing_salve.gd |
| Taxing other cards | `.with_cost_modifier(spell_cb, ability_cb)` | gloom.gd |
| Prevent N damage | `PreventDamageEffect` (+`.x_amount()`/`.to_controller()`) | samite_healer.gd, conservator.gd |
| "Activate only during combat" | `ActivatedAbility...combat_only()` | jade_statue.gd |
| "Becomes a creature" | `AnimateSelfEffect` (+`.until_end_of_combat()`) | mishra_s_factory.gd, jade_statue.gd |
| Exile a permanent | `ExileEffect` | ashes_to_ashes.gd |
| Fetch a land to play | `SearchLibraryEffect...to_battlefield()` | untamed_wilds.gd |
| "Can't attack" statics | set `cur_cant_attack` in a `StaticAbility` | moat.gd |
| Regenerate (self/target) | `RegenerateEffect` (+`.target_creature()`) | uthden_troll.gd, death_ward.gd |
| "Lands are Mountains" etc. | `StaticAbility(...).changing_types()` + `CardInstance.become_basic_land_type` (CR 305.7 strips the land's other abilities) | blood_moon.gd, evil_presence.gd |
| A characteristic-defining P/T | `StaticAbility(...).setting_base_pt()` | nightmare.gd, keldon_warlord.gd |
| "Can't be the target of <source kind>" | append to `CardInstance.cur_target_bans` in a static | artifact_ward.gd |
| A spec that can only name Walls | `TargetSpec...only_walls()` | glyph_of_doom.gd |
| "Remove N counters" as a COST | `ActivatedAbility...with_counter_cost(kind, n)` | triskelion.gd, necropolis_of_azar.gd |
| "Sacrifice this at the next end step" | `MtgGame.doom_at_next_end_step(inst, false, false, true)` | dragon_whelp.gd |
| Something that must outlive its source | `MtgGame.schedule_end_of_combat_action` / `schedule_end_step_token`, or a graveyard trigger | glyph_of_doom.gd, hazezon_tamar.gd |
| "Originally printed in <expansion>" | `CardRegistry.originally_printed_in(name, code)` — NEVER `data.set_code` | city_in_a_bottle.gd, golgothian_sylex.gd |
| A colour its mana cost does not imply | `.with_colors(Mtg.ManaColor.R)` | crimson_kobolds.gd |
| Last known information about a dead permanent | `last_power` / `last_toughness` / `last_types` / `last_colors` (CR 608.2h) | creature_bond.gd, necropolis_of_azar.gd |
| "As this enters, ..." (a replacement) | `.as_it_enters(cb)` | wood_elemental.gd, frankenstein_s_monster.gd |
| "...instead of onto the battlefield" | `.enters_only_if(cb)` — the card's veto on its own arrival | frankenstein_s_monster.gd |
| "<things> can't enter the battlefield" | `.bans_permanents_entering(cb)` | worms_of_the_earth.gd |
| Something that must happen the INSTANT this leaves | `.as_it_leaves(cb)` — not a trigger; runs before the board is recomputed | titania_s_song.gd, oubliette.gd |
| "...this effect continues until end of turn" | `ContinuousEffects.add_floating_static` from that hook | titania_s_song.gd |

## Writing the test

Extend `GameTest` (tests/game_test.gd) and describe the card's behavior in
game terms. Setup helpers (`put_battlefield`, `give_hand`, `add_mana`) may
cheat; the action under test must use the real API:

```gdscript
func test_bolt_kills_a_bear() -> void:
    var bear := put_battlefield(1, "Grizzly Bears")
    var bolt := give_hand(0, "Lightning Bolt")
    add_mana(0, Mtg.ManaColor.R)
    assert_ok(g.cast_spell(0, bolt, [TargetRef.card(bear)]))
    resolve_stack()
    assert_eq(bear.zone, Mtg.Zone.GRAVEYARD)
```

Test the card's *edges*, not just its happy path: illegal targets refused,
fizzling when the target disappears, timing restrictions, interactions named
in its oracle text. `tests/cards/test_2ed_cards.gd` shows the expected depth.

The 2026-09 audit (docs/audit-2026-09.md) found the same handful of mistakes
over and over. Read your card's oracle text once more and ask:

- Does a clause say **"this turn"**? Then the bookkeeping has to expire with
  the turn — card memory does not (Dragon Whelp counted breaths forever).
- Does it say **"sacrifice"** where the code destroys, or the other way
  round? A sacrifice ignores regeneration and indestructible (CR 701.17).
- Does it say **"you may"**? Then it must be declinable through
  `game.agents[pid].choose_yes_no(...)`.
- Does a trigger's condition depend on something that could change before it
  resolves? Intervening "if" is checked twice (CR 603.4).
- Does the effect bail out when its own source has left the battlefield? A
  triggered ability resolves anyway (CR 603.6 / 608.2h).
- Whose CHOICE is it? "of an opponent's choice", "that player chooses",
  "defending player controls" — ask the right agent, and sort the candidates
  from THEIR point of view.
- Does a filter read `data.` anything? Rules code reads the live `cur_*`
  values (CONTRIBUTING.md rule 5) — and last known information for a permanent
  that has already left.
- Is a restriction part of TARGETING ("target artifact with mana value X")?
  Then it belongs in the TargetSpec, not in `resolve()`.

## Checklist (copy into the PR description)

- [ ] One file, `cards/sets/<set>/<name>.gd`, filename matches card name
- [ ] Header doc: cost/type/P/T line, exact oracle text, implementation notes
- [ ] Any simplification documented in the header AND in docs/simplified-cards.md
- [ ] Test(s) in `tests/cards/`, covering edges, passing: `./run_tests.sh`
- [ ] Pool count bumped in `test_registry_loaded_the_pool` (tests/cards/test_2ed_cards.gd)
- [ ] No engine changes — or engine changes shipped separately with engine tests
- [ ] docs/CODE_MAP.md updated if a new mechanic/class was added
- [ ] docs/mechanics.md updated if the card taught the engine a new mechanic

## The pool pipeline (tools/)

The full 1997 pool — base game (2ed, 4ed, arn, atq, past, phpr) plus the
Duels of the Planeswalkers expansion (leg, drk), 897 unique cards — is
already downloaded and stubbed:

```sh
python3 tools/fetch_cards.py   # refresh cards/data/<set>.json from Scryfall
python3 tools/gen_cards.py    # regenerate auto cards + TODO stubs
```

The generator auto-implements only what is mechanically safe (vanilla and
supported-keyword creatures) into `cards/sets/<set>/`; every other card is a
**documented stub in `cards/todo/<set>/`** carrying its exact oracle text.
Stubs are not loaded by the registry.

**Implementing a stubbed card ("graduating" it):**
1. Read the stub's oracle text; check the mage-go clone for the reference
   implementation (`grep -ri "<card name>" ../mage-go/cards/` style search).
2. Write the test in `tests/cards/`.
3. Replace the stub's body with a real `build()` (delete the AUTOGENERATED
   marker line), and MOVE the file to `cards/sets/<set>/`.
4. Bump the count in `test_registry_loaded_the_pool`
   (tests/cards/test_2ed_cards.gd) and run `./run_tests.sh`.

If the card needs a missing mechanic (first strike, protection, regeneration,
banding...), the mechanic lands in `engine/` first — check docs/ROADMAP.md,
implement it with engine tests, then graduate every stub it unblocks.

## Future card packs (design policy)

The pool's identity is the original game + its expansion. Community
mini-packs are welcome later under new set folders, with one hard rule
inherited from the project owner: **added cards must not change the balance
of the original game** — no new tournament staples into rogue decks, no
power-level creep; think flavor, variety, and filling curve gaps. Pack
proposals should state their balance reasoning in the set folder's README.
