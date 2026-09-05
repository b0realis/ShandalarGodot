# Mechanics — what the engine can do

A catalogue of every rules mechanic `engine/` implements today, grouped by
area. Each row names the mechanic in Magic terms, says what it does, cites the
Comprehensive Rules number the code follows, points at the exact class /
method / field that implements it, and names one card from this pool that
exercises it. Read it to answer "does the engine already do X?" without
reading 10 000 lines of GDScript; when the answer is yes, the engine column
tells you where to hook in.

Two ledgers hold the deviations, and this document only cross-references them:

- **`docs/simplified-cards.md`** — card-scoped deviations, one row per card.
- **`docs/ROADMAP.md`** — engine-wide simplifications ("Engine simplifications
  still to lift") and the milestone plan.

If a mechanic is missing here, check the last section — it lists what the
engine deliberately does not do. Everything below was verified against the
code, not against older prose: where a header comment elsewhere disagrees with
this file, the code (and this file) is right.

Conventions: `cur_*` fields are LIVE characteristics rebuilt by the continuous
pipeline; `data.*` is what is printed. Rules code always reads the live ones.

---

## 1. Turn structure & priority

The turn is a flat list of steps (`Mtg.STEP_ORDER`) walked by
`MtgGame._enter_step` / `MtgGame._advance_step`. Phases are implicit: the
combat phase is `COMBAT_BEGIN..COMBAT_END`, and `Mtg.is_combat_step()` /
`Mtg.is_main_step()` are the only phase questions the engine asks. The game is
strictly two-player (`MtgGame.opponent_of` is `1 - pid`).

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Step machine | Walks UNTAP → UPKEEP → DRAW → MAIN1 → 5 combat steps → MAIN2 → END → CLEANUP, then hands the turn over. | 500 | `Mtg.STEP_ORDER` (six combat steps once FIRST_STRIKE_DAMAGE is counted; it is skipped when nobody has first strike), `MtgGame._enter_step`, `MtgGame._advance_step`, `MtgGame.current_step` | — |
| Priority | After a step's turn-based actions the active player gets priority; both players passing in succession resolves the top of the stack, or advances the step when the stack is empty. | 117.3a-b, 117.4 | `MtgGame._open_priority`, `MtgGame.pass_priority`, `MtgGame._passes` | — |
| Caster keeps priority | Casting or activating does not pass priority. | 117.3c | tail of `MtgGame.cast_spell` / `activate_ability` (`priority_player = pid`) | — |
| Steps without priority | Untap grants none and auto-advances; cleanup grants none either. | 502.4, 514.1 | `MtgGame._enter_step` (UNTAP branch calls `_advance_step`), `MtgGame._cleanup_step` | — |
| Untap turn-based actions | Untaps the active player's permanents, clears summoning sickness, resets the land drop, ages the "can't attack next turn" ban, clears `attacked_this_turn` for BOTH players, snapshots untapped lands. | 502 | `MtgGame._enter_step` UNTAP branch; `MtgPlayer.untapped_lands_at_turn_start` | Power Surge (`cards/sets/2ed/power_surge.gd`) |
| Untap denial | Per-permanent: one-shot (`skip_next_untap`), N-turn (`skip_untaps`), static (`cur_skips_untap`), "you may choose not to untap" (`may_skip_untap` + `_is_sustaining`), glyph counters. Per-player CAPS limit how many of a kind untap. | 502.1-2 | `CardInstance.skip_next_untap` / `skip_untaps` / `cur_skips_untap`, `CardData.may_skip_untap`, `MtgGame._is_sustaining`, `MtgGame.untap_caps`, `MtgGame._untap_kinds` | Winter Orb (`2ed/winter_orb.gd`), Meekstone (`2ed/meekstone.gd`) |
| First-turn draw skip | The starting player skips turn 1's draw. | 103 | `MtgGame._skip_first_draw` | — |
| Post-draw hook | `DRAW_STEP` fires after the normal draw, which is where extra-card effects hang. | 504.1 | `Mtg.EventType.DRAW_STEP` | Howling Mine (`2ed/howling_mine.gd`) |
| Sorcery timing | Non-instants may only be cast by the active player, in a main step, with an empty stack. | 307.1 | `MtgGame.cast_spell` timing branch | any sorcery |
| Land drop | One land per turn as a special action (no stack), main phase, empty stack, holding priority. | 305.1 | `MtgGame.play_land`, `MtgPlayer.lands_played_this_turn`, `MtgGame.unlimited_land_plays` | Fastbond (`2ed/fastbond.gd`) |
| Combat skip | With no attackers declared, the blockers and damage steps are skipped. | 508.8 | `MtgGame._advance_step` | — |
| End step | Runs the delayed "destroy at the beginning of the next end step" queue and delayed token creation, then fires `END_STEP_START`. | 513.1 | `MtgGame._enter_step` END branch, `_end_step_doom*`, `_end_step_tokens` | Berserk (`2ed/berserk.gd`), Rukh Egg (`arn/rukh_egg.gd`) |
| Cleanup | Discard to hand size, wipe damage and every per-turn flag, return until-EOT control changes, expire until-EOT continuous effects. The DISCARD is either answered by the seat's `DecisionAgent` or — for a seat that asked to choose, i.e. the human — the step HOLDS OPEN as the original's own Discard Phase (`awaiting_discard` / `discard_to_hand_size`). | 514.1-2 | `MtgGame._cleanup_step`, `_finish_cleanup`, `ContinuousEffects.expire_until_eot` | Cursed Rack (`4ed/cursed_rack.gd`) sets `max_hand_size` |
| Mana empties each step | Both pools clear at every step boundary. No mana burn. | 500.4 | `MtgGame._advance_step` → `ManaPool.clear` | — |
| Extra turns | Queued by id; drained before the turn would pass normally. | 500.7 | `MtgGame.extra_turns`, `ExtraTurnEffect`, `MtgGame._end_turn` | Time Walk (`2ed/time_walk.gd`) |
| Skip a turn | "If you would begin your turn while this artifact is tapped, you may skip that turn instead" — asked as the turn begins, before its untap step, through the turn-based hold (`@TIME_VAULT`: "Play this turn." / "Skip this turn to untap."); a skipped turn is proceeded past as though it did not exist: no untap, upkeep, draw or cleanup step, no "last turn" bookkeeping. One skipped turn untaps one such permanent. | 614.10, 500.9, 616.1 | `CardData.skips_turn_to_untap` / `with_skip_turn_to_untap`, `MtgGame._begin_turn` / `_skip_turn` / `_next_turn` | Time Vault (`2ed/time_vault.gd`) |

**The opening hand.** `MtgGame.deal_opening_hands` deals both sevens and
opens the SHANDALAR mulligan — `may_mulligan` / `take_mulligan` /
`decline_mulligan` — and `start_duel` begins turn 1 with the chosen first
player, who skips their first draw. Only a hand with NO land or ALL land may
redraw; the redraw is seven for seven; each player gets one chance; and a
redraw by either player opens the offer to the other (`Duel.hlp`, topic
"Mulligan"). `MtgGame.start` still does deal-and-begin in one call for tools
and tests.

**Simplifications here:** the cleanup step grants no priority (marked
`SIMPLIFIED:` in `_cleanup_step`); untap-cap choice is "first N in timestamp
order" (simplified-cards, *untap locks*).

---

## 2. The stack, casting and activation

`MtgGame.stack` is an `Array[StackItem]`; the last element is the top.
`MtgGame._resolve_top` pops one object per double pass.

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| The stack | LIFO resolution of spells, activated abilities and triggers. | 405, 608.1 | `MtgGame.stack`, `StackItem`, `MtgGame._resolve_top` | Counterspell (`2ed/counterspell.gd`) |
| Casting | Validates timing, bans, modes, targets and additional costs, pays mana, moves the card to the stack, fires `SPELL_CAST`. | 601.2 | `MtgGame.cast_spell` | every non-land |
| Activating | Same shape for activated abilities, off the LIVE ability list. | 602.2 | `MtgGame.activate_ability`, `CardInstance.cur_activated_abilities` | Prodigal Sorcerer (`2ed/prodigal_sorcerer.gd`) |
| Live ability lists | Statics may replace or append abilities, and activation reads the live list — a retuned land really taps for the new colour, a granted ability is really activatable. | 613 layer 6 | `CardInstance.cur_mana_abilities` / `cur_activated_abilities` | Zombie Master (`2ed/zombie_master.gd`), Evil Presence (`2ed/evil_presence.gd`) |
| Mana abilities | Do not use the stack, cannot be responded to, usable mid-payment; need no priority. | 605.3 | `ManaAbility`, `MtgGame.tap_for_mana` | Sol Ring (`2ed/sol_ring.gd`) |
| Triggered mana abilities | Resolve immediately instead of going on the stack, so their mana is usable mid-payment. | 605.1b | `TriggeredAbility.is_mana_trigger` / `as_mana_trigger()` | Mana Flare (`2ed/mana_flare.gd`), Wild Growth (`2ed/wild_growth.gd`) |
| Summoning sickness | Blocks `{T}` costs of creatures (mana and non-mana alike) and attacking; haste lifts both, `cur_attacks_as_if_hasty` lifts only attacking. | 302.6, 602.5g | `CardInstance.summoning_sick`, checks in `tap_for_mana` / `activate_ability` / `CombatState.attack_illegality` | Instill Energy (`2ed/instill_energy.gd`) |
| Activation timing riders | "Only during combat / during step N / before step N / your turn / an opponent's turn", plus an arbitrary predicate and a per-turn cap. | 602.5 | `ActivatedAbility.combat_only` / `during_step` / `before_step` / `your_turn_only` / `opponents_turn_only` / `only_if` / `per_turn` | Jade Statue (`2ed/jade_statue.gd`) |
| Who may activate | Normally the controller; an ability may be handed to the opponents only, or to anyone. | 602.1 | `ActivatedAbility.opponent_activated` / `anyone_activated` | Clergy of the Holy Nimbus (`leg/clergy_of_the_holy_nimbus.gd`) |
| Cast-timing riders | "Cast this spell only …" as a predicate checked before any cost is paid (and consulted by the AI). | 601.2 | `CardData.castable_only_when` / `cast_condition` | Berserk (`2ed/berserk.gd`) |
| Play bans | A battlefield permanent may forbid casting/playing whole classes of card. | 601.3 | `CardData.bans_playing` / `play_ban`, `MtgGame.play_banned` | City in a Bottle (`arn/city_in_a_bottle.gd`) |
| "Originally printed in <set>" | Answered from the Scryfall snapshot in printing order, not from the folder a card happens to live in. | 201 | `CardRegistry.originally_printed_in`, `CardRegistry.SET_ORDER` | Golgothian Sylex (`atq/golgothian_sylex.gd`) |
| Modal spells | The mode is chosen while casting and travels with the stack item. | 601.2b, 700.2 | `CardData.mode()` / `modes` / `is_modal`, `MtgGame.cast_spell(mode)`, `StackItem.mode` | Healing Salve (`2ed/healing_salve.gd`) |
| Resolution | Permanents enter the battlefield; instants/sorceries run their effects and go to the graveyard. | 608.3, 608.2m | `MtgGame._resolve_spell`, `_run_effects`, `_spell_to_graveyard` | — |
| Fizzling | A spell or ability whose targets are ALL illegal on resolution is countered — nothing happens, not even its untargeted riders. | 608.2b | `MtgGame._all_targets_illegal`, `_resolve_spell` | Lightning Bolt at a dead creature |
| Partial illegality | An individually illegal target drops out of its group; the rest of the effect still happens. | 608.2c | `MtgGame._run_effects` | Pyrotechnics (`4ed/pyrotechnics.gd`) |
| Countering | Removes the stack item and puts the card in its owner's graveyard. | 701.5a | `MtgGame.counter_spell`, `CounterEffect` | Counterspell |
| Spell copies | A copy is put on the stack with the original's mode, X and (re-grouped) targets; it ceases to exist instead of hitting a graveyard. | 707.10a, 707.10c | `MtgGame.copy_spell_on_stack`, `find_stack_item`, `CardInstance.is_copy` | Fork (`2ed/fork.gd`) |
| Self-exiling spells | "Exile this spell" as part of its own resolution. | 608.2m | `CardInstance.exile_after_resolution` | Recall (`leg/recall.gd`) |

---

## 3. Costs and mana

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Mana costs | Parses `{W}{U}{B}{R}{G}{C}`, generic numbers and `{X}`. Hybrid/Phyrexian/snow are out of scope. | 107.4, 202 | `ManaCost.parse`, `.colored`, `.generic`, `.has_x`, `.x_count`, `.mana_value`, `.color_mask` | — |
| Doubled X | `{X}{X}{U}` charges the chosen X once per printed `{X}`. | 107.3 | `ManaCost.x_count`, `x_paid` in `MtgGame.cast_spell` | Part Water (`leg/part_water.gd`) |
| Mana pool | Floating mana per colour; documented greedy payment (colours first with exact matches, then substitutions; generic from restricted → colorless → most abundant colour). | 106.4, 500.4 | `ManaPool.add` / `can_pay` / `pay` / `clear` / `_take` | — |
| Restricted mana | "Spend this mana only to cast artifact/creature spells" lives in a second keyed pool and is spent FIRST. | 106.6 | `ManaPool.add_restricted` / `_spendable`, `ManaAbility.with_restriction`, `MtgGame.mana_usage_keys` | Mishra's Workshop (`atq/mishra_s_workshop.gd`) |
| Mana substitutions | "You may spend white mana as though it were red." Rebuilt every recalculation. | 106.6 | `MtgPlayer.mana_substitutions`, `substitutions` argument of `ManaPool.can_pay`/`pay` | Sunglasses of Urza (`2ed/sunglasses_of_urza.gd`) |
| Any-type wildcard | One spell this turn may be paid with mana of any type; the charge is consumed only by a cast that actually needs it. | 106.6 | `MtgPlayer.any_color_spells`, `any_color` argument of `ManaPool.pay` | North Star (`leg/north_star.gd`) |
| Cost modifiers | Battlefield permanents tax or discount spells and abilities; a discount is clamped so it can never eat a coloured pip. | 601.2f | `CardData.with_cost_modifier` / `cost_modifier`, `MtgGame.spell_surcharge` / `ability_surcharge` | Gloom (`2ed/gloom.gd`), Mana Matrix (`leg/mana_matrix.gd`) |
| Per-target surcharge | "Costs {1} more for each target beyond the first", priced once the target group is known. | 601.2f | `CardData.extra_cost_per_target` | Fireball (`2ed/fireball.gd`) |
| Ability discounts | An effect may rewrite a permanent's LIVE activated abilities with cheaper copies. | 601.2f | `ActivatedAbility.shallow_copy` / `discounted`, `ManaCost.minus_generic` | Power Artifact (`atq/power_artifact.gd`) |
| Additional cost: sacrifice a spell's fodder | Paid as the spell goes on the stack; the eaten permanent's mana value is recorded in the spell's own memory. | 601.2h | `CardData.with_additional_sacrifice` / `additional_sacrifice`, `CardInstance.memory["sacrificed_mv"]` | Metamorphosis (`arn/metamorphosis.gd`) |
| Ability cost riders | Tap, sacrifice self, sacrifice another `<filter>`, pay life, exile self, random discard, remove N counters. Every part is checked before any part is paid. | 601.2h, 118.4 | `ActivatedAbility.tap_cost` / `with_sacrifice_cost` / `with_sacrifice_of` / `with_life_cost` / `with_exile_cost` / `with_random_discard_cost` / `with_counter_cost` | Triskelion (`4ed/triskelion.gd`), Feldon's Cane (`atq/feldon_s_cane.gd`, the exile-self cost) |
| Mana-ability cost riders | Own mana cost, no `{T}`, sacrifice self, sacrifice another, life, counter removal, dynamic amount, dynamic colour, a colour the ACTIVATING PLAYER picks, restriction, side effect, scale-with-sacrifice. `with_dynamic_color` computes a colour; `with_color_choice` supplies the CENSUS of colours on offer and lets `MtgGame.tap_for_mana` ask — which is the only place a mana ability's question can hold the duel open, since it never uses the stack (docs/duel-todo.md §1.3). | 605.1a | `ManaAbility.with_mana_cost` / `without_tap` / `with_sacrifice` / `with_sacrifice_of` / `with_life_cost` / `with_counter_cost` / `with_dynamic_amount` / `with_dynamic_color` / `with_color_choice` / `with_restriction` / `with_side_effect` / `scaling_with_sacrifice` | Ashnod's Altar (`atq/ashnod_s_altar.gd`), Gem Bazaar (`past/gem_bazaar.gd`), Fellwar Stone (`4ed/fellwar_stone.gd`), Rasputin Dreamweaver (`leg/rasputin_dreamweaver.gd`) |
| X spells | X is chosen at cast, stamped on the card before targets are validated (so "target with mana value X" filters see it), then multiplied by `x_count` and paid as generic. | 107.3, 115.4, 601.2b | `MtgGame.cast_spell(x_value)`, `CardInstance.memory["x_value"]`, `StackItem.x_value` | Fireball, Frankenstein's Monster (`drk/frankenstein_s_monster.gd`) |
| X in abilities | Generic by default; `with_colored_x` makes it a coloured payment. | 107.3 | `ActivatedAbility.x_color` / `with_colored_x` / `cost_for`, `ManaCost.plus_colored` | Goblin Polka Band (`past/goblin_polka_band.gd`) |
| Coloured X on spells | "Spend only black mana on X": `CardData.with_colored_x` makes `cast_spell` pay `cost_for(x)` (X copies of that colour) with no generic X share; the AI sizes X against the coloured cost. | 107.3, 601.2f | `CardData.x_color` / `with_colored_x` / `cost_for`, `MtgGame.cast_spell`, `AiPlayer._max_affordable_x` | Drain Life (`2ed/drain_life.gd`) |
| Mid-trigger payments | "Unless you pay {N}" resolved inside a trigger: floating mana first, then auto-tapped LANDS. | 601.2h | `MtgGame.try_pay`, `can_afford_cost`, `_payment_plan` | Stasis (`2ed/stasis.gd`) |

**A COST THAT IS REFUSED ASKS NOTHING** (CR 601.2h — "if the total cost
can't be paid, the casting is illegal and the game returns to the moment
before"). Where a cost needs a choice from the seat — "sacrifice a
`<filter>`" in `cast_spell`, `activate_ability` and `tap_for_mana` — the
LEGALITY of the requirement is settled where the cost is assembled ("no
creature to sacrifice" is still the first refusal), but WHICH permanent goes
is asked only once no refusal is left. Asking earlier filed a `PlayerChoice`
in `choice_log`, an entry in `unanswered_choices` and a
`(decided for P0) Sacrifice a creature — …` line in the game log for a cast
the engine then turned down. Pinned by
`tests/unit/test_cost_choice_contract.gd`.

**Simplifications here:** `try_pay` auto-taps lands only (never Sol Ring) and
picks them greedily — ROADMAP. Power Artifact's floor is "generic can't go
below zero" rather than "not less than one mana" — simplified-cards.

---

## 4. Targeting

`TargetSpec` says what may be targeted; `TargetRef` is the chosen target as a
value object (id, never a pointer); `TargetPlan` groups a flat ref list per
targeting effect and validates the whole choice at once.

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Target kinds | ANY, CREATURE, PLAYER, PERMANENT, SPELL, SPELL_OR_PERMANENT, four graveyard kinds, CARD_IN_ANTE. | 115.1 | `TargetSpec.Kind` | Counterspell (SPELL), Darkpact (`2ed/darkpact.gd`, ANTE) |
| "Target opponent" | A player other than the source's controller. | 109.5 | `TargetSpec.opponent()` / `opponent_only` | Jovial Evil (`leg/jovial_evil.gd`) |
| Filters | Three predicate slots: on the instance, game-aware, and source-aware. Every spec carries card-English text used verbatim in refusals. | 115.4 | `TargetSpec.filter`, `.with_game_filter`, `.with_source_filter`, `.description` | Terror (`2ed/terror.gd`), Righteousness (`2ed/righteousness.gd`) |
| Validation twice | Targets are checked at cast/activation and again on resolution. | 601.2c, 608.2b | `TargetSpec.is_legal` | — |
| Spell can't target itself | A source on the STACK is not a legal target for itself; an ABILITY may target its own source. | — | `TargetSpec.is_legal` self-reference branch | Samite Healer shielding itself |
| Protection (T of DEBT) | Can't be targeted by sources of the protected colours. | 702.16 | `CardInstance.cur_protection` vs `source.cur_colors` in `TargetSpec.is_legal` | White Knight |
| Shroud | Nothing may target it, not even its controller. | 702.18 | `CardInstance.cur_shroud` | Spectral Cloak (`leg/spectral_cloak.gd`) |
| "Can't be the target of spells" | Abilities still work — the check asks where the source IS (hand or stack = a spell). | 115 | `CardInstance.cur_cant_be_spell_target` | Lurker (`drk/lurker.gd`) |
| "Can't be the target of Aura spells" | Printed flag and a static-granted flag ("can't be enchanted by other Auras"). | 303.4 | `CardData.cant_be_aura_target`, `CardInstance.cur_cant_be_aura_target` | Bartel Runeaxe (`leg/bartel_runeaxe.gd`), Anti-Magic Aura (`leg/anti_magic_aura.gd`) |
| Source-filtered bans | "Can't be the target of abilities from artifact sources." | 115 | `CardInstance.cur_target_bans` | Artifact Ward (`atq/artifact_ward.gd`) |
| Wall-only specs | A spec that can only ever target Walls declares itself; a creature may be immune to exactly those. | 115 | `TargetSpec.only_walls()` / `wall_only`, `CardInstance.cur_immune_to_wall_only` | Wall of Shadows (`leg/wall_of_shadows.gd`) |
| Phased-out permanents | Treated as though they don't exist; never legal targets. | 702.25a | `CardInstance.phased_out` checks in `TargetSpec.is_legal` | Oubliette (`arn/oubliette.gd`) |
| "Your graveyard" | Means the ABILITY's controller's graveyard, so a stolen digger digs in the thief's. | 109.5 | `TargetSpec.is_legal` graveyard branch | Adun Oakenshield (`leg/adun_oakenshield.gd`) |
| Legal-target census | Enumerates every currently legal target, used by variable-count targeting and by the AI. | 601.2c | `TargetSpec.legal_targets` | — |
| Multi-target | "One or more target creatures" and "X target creatures". | 601.2c | `EffectBase.one_or_more()` / `x_targets()` / `target_min` / `target_max` / `target_count_is_x`, `TargetPlan._build` | Word of Binding (`4ed/word_of_binding.gd`), Sea Kings' Blessing (`leg/sea_kings_blessing.gd`) |
| Divided amounts | "N damage divided as you choose"; each chosen target gets at least 1 and the shares must sum to the total, locked in at cast. | 601.2d | `EffectBase.divided_among()` / `divided_amount`, `TargetRef.amount`, `TargetPlan._validate` | Pyrotechnics (`4ed/pyrotechnics.gd`) |
| Sibling target slots | Two slots with DIFFERENT specs on one object: one targeting effect per slot, and the effect that does the work reads the other slot off the resolving object. | 601.2c | `MtgGame.current_targets()` | Gauntlets of Chaos (`leg/gauntlets_of_chaos.gd`) |
| Draw replacements | "If you would draw a card, instead …" applied inside the one helper every draw passes through. Static ones ride on a permanent, one-shot ones are registered by a resolving effect and consumed by the next draw. A replaced draw moves no card, fires no CARD_DRAWN and cannot kill an empty library. | 614.1, 614.5 (a replacement applies once per event) | `CardData.draw_replacement` / `replaces_draws`, `MtgGame.replace_next_draw` / `_replace_draw` | Island Sanctuary (`2ed/island_sanctuary.gd`), Chains of Mephistopheles (`leg/chains_of_mephistopheles.gd`), Aladdin's Lamp (`4ed/aladdin_s_lamp.gd`) |
| Draw-STEP replacement | "If you would begin your draw step, you may skip that step instead" — the step happens not at all: no draw, no DRAW_STEP event, no priority in it. | 614.1 applied to a turn-based action, 500.9 | `CardData.draw_step_replacement` / `replaces_draw_step`, `MtgGame._draw_step_skipped` | Fasting (`drk/fasting.gd`) |
| "Cards drawn this turn" | The CARDS, not a count — the set a card can ask you to choose from. | — | `MtgPlayer.drawn_this_turn` | Sylvan Library (`4ed/sylvan_library.gd`) |
| Countering an ACTIVATED ABILITY | An ability on the stack is an object with an id of its own, targetable and counterable; countering it puts no card anywhere and refunds nothing. A mana ability never reaches the stack, so the printed "(Mana abilities can't be targeted.)" needs no code. | 113.3b, 701.5a, 605.3a | `TargetSpec.Kind.ABILITY`, `TargetRef.ability`, `StackItem.id`, `MtgGame.find_stack_ability` / `counter_ability`, `CounterAbilityEffect` | Rust (`leg/rust.gd`), Ayesha Tanaka (`leg/ayesha_tanaka.gd`) |
| Retargeting a spell | Replace one target slot of a spell already on the stack, in both the flat list and the per-effect group. | 701.30 | `MtgGame.retarget_spell` | Reflecting Mirror (`drk/reflecting_mirror.gd`) |
| ATTACK COSTS | "Can't attack unless its controller pays {3}" / "unless you sacrifice two Islands": every declared attacker's costs are checked before any is paid, so a refused declaration spends nothing (CR 508.1g). | 508.1g | `CardInstance.cur_attack_costs`, enforced in `MtgGame.declare_attackers` | Brainwash (`4ed/brainwash.gd`), Leviathan (`4ed/leviathan.gd`) |
| Attacking without tapping | A whole seat's creatures attack untapped for one combat. | 508.1f | `MtgGame.attacks_without_tapping` | Johan (`leg/johan.gd`) |
| Beginning of combat | The step before attackers are declared, as an event. | 507.1 | `Mtg.EventType.COMBAT_START` | Battering Ram (`4ed/battering_ram.gd`), Johan |
| Costs that eat a card | "Exile a creature you control", "Exile a creature card from your graveyard", "Discard a card" — all paid in `activate_ability` with the mana (CR 601.2h), all chosen by the paying player, and what went is left on the source's memory. | 601.2h | `ActivatedAbility.with_exile_of` / `with_exile_from_graveyard` / `with_discard_cost` | City of Shadows (`drk/city_of_shadows.gd`), Necropolis (`drk/necropolis.gd`), Land's Edge (`leg/land_s_edge.gd`) |
| Unpreventable damage | "Damage ... can't be prevented or dealt instead to another permanent or player" — every prevention and redirection gate is skipped, protection included (CR 702.16e makes protection prevent damage). | 615.6-adjacent | `CardInstance.damage_unpreventable_this_turn` | Whippoorwill (`drk/whippoorwill.gd`) |
| Damage CAPS | "If a source would deal 3 or more damage to you, it deals 2 instead" — a replacement applied before any prevention. | 614.1 | `MtgPlayer.damage_caps` | Forethought Amulet (`leg/forethought_amulet.gd`) |
| Seat-level damage REPLACEMENTS | The whole "the next time a source of your choice would deal damage to you this turn, instead ..." family, as one list applied before every prevention gate. A handler returns -1 ("carry on with what is left") or >= 0 ("the event ends here, that much was dealt"); an entry is one-shot unless it says `all_turn`. | 614, 616 | `MtgPlayer.damage_replacements`, applied in `MtgGame._land_damage_impl` | Forcefield (`2ed/forcefield.gd`), Dark Sphere (`drk/dark_sphere.gd`), Eye for an Eye (`4ed/eye_for_an_eye.gd`), Nova Pentacle (`leg/nova_pentacle.gd`), Shimian Night Stalker (`leg/shimian_night_stalker.gd`) |
| Taking a creature's damage yourself | "If damage would be dealt to any creature, you MAY have that damage dealt to you instead" — offered per packet, redirected as the same damage. | 614.1 | `MtgPlayer.may_take_creature_damage` | Blood of the Martyr (`drk/blood_of_the_martyr.gd`) |
| Counter-eating armour | "For each 1 damage that would be dealt to this creature, if it has a +1/+1 counter, remove one and prevent that 1 damage" — point for point, before every prevention gate. | 614.1 | `CardInstance.damage_eats_counters` | Rock Hydra (`2ed/rock_hydra.gd`) |
| Metered redirect | "The next 1 damage that would be dealt to this creature this turn is dealt to its owner instead" — each activation books ONE point; when damage lands that many points split off as a new packet to the owner and the rest is marked on the creature (`Duel.hlp`: "may redirect any amount of damage from it"; the 1997 "How much?" prompt = N activations). Under the 1997 window the moved part gets its own second prevention step. | 614.1c, 615 | `MtgGame.add_point_redirect` / `_divert_damage_points`, `DamagePacket.divert` / `redirected`, `CardInstance.damage_point_redirects` | Personal Incarnation (`2ed/personal_incarnation.gd`) |
| A source whose damage all goes elsewhere | "All damage that would be dealt this turn by target sorcery spell is dealt to that spell's controller instead" — a replacement on the SOURCE, applied before anything about the victim. | 614.1 | `CardInstance.damage_all_redirect_to` | Reverberation (`leg/reverberation.gd`) |
| Floating damage immunities | The until-end-of-turn form of `cur_damage_immunity`, so a one-shot spell can hang a source-filtered prevention on a creature. | 615 | `ContinuousEffects.add_until_eot_damage_immunity` | Silhouette (`leg/silhouette.gd`) |
| "Only its OWNER may activate" | Ownership, not control, gates the ability — a stolen permanent still answers to the player whose card it is. | 108.3, 602.2 | `ActivatedAbility.owner_only()` | Personal Incarnation (`2ed/personal_incarnation.gd`) |
| Destruction shields | "The next time it would be destroyed this turn, remove all damage marked on it instead" — regeneration's shape without regeneration's tap and removal from combat, so "can't be regenerated" does not stop it. | 614.1, cf. 701.15 | `CardInstance.destruction_shields`, applied in `MtgGame.destroy` | Pyramids (`arn/pyramids.gd`) |
| Delayed actions | "At the beginning of the next end step, ..." and "at the beginning of your next main phase, ..." as turn-based actions that outlive their source. | 603.7a (stood in for) | `MtgGame.schedule_end_step_action`, `schedule_next_main_phase_action` | Rakalite (`atq/rakalite.gd`), Mana Drain (`leg/mana_drain.gd`) |
| Floating watches | "When that creature dies this turn, ..." and "whenever this creature deals damage to a creature this turn, ..." — per-turn watches that outlive whatever placed them. | 603.7a (stood in for) | `MtgGame.watch_death`, `watch_damage_dealt` | Reincarnation (`leg/reincarnation.gd`), Runesword (`drk/runesword.gd`) |
| Damage AMOUNTS per source | How much each source has dealt this turn, not just which sources dealt some. | — | `MtgGame.damage_dealt_this_turn` | Backdraft (`leg/backdraft.gd`) |
| Discard triggers from HAND | "When a spell or ability an opponent controls causes you to discard this card, ..." — the one zone no ability list reaches. | 603.2 | `CardData.on_discarded`, `MtgGame.current_resolution_controller` | Psychic Purge (`leg/psychic_purge.gd`) |
| Triggers that listen from EXILE | The sibling of the graveyard crawl, reached by the same turn-based pass. | 603.6 | `CardData.exile_triggers` | All Hallow's Eve (`leg/all_hallow_s_eve.gd`) |
| Life for mana | A player-level mana source rather than a permanent's ability. | 605.3a | `MtgPlayer.life_for_mana`, `MtgGame.pay_life_for_mana` | Channel (`2ed/channel.gd`) |
| Paid prevention on the seat | "Until end of turn, you may pay {1} any time you could cast an instant. If you do, prevent the next 1 damage that would be dealt to that permanent or player this turn" — a permission on the seat, spent at priority without the stack, one point into the target's prevention pool per {1}; gone at cleanup or when the permanent leaves (CR 400.7). | 117.1a, 615, 400.7 | `MtgPlayer.paid_prevention`, `MtgGame.grant_paid_prevention` / `pay_for_prevention` / `paid_prevention_for`, `PreventDamageEffect.with_paid_rider` | Guardian Angel (`2ed/guardian_angel.gd`) |
| Recoloured land mana | "If you tap a land you control for mana, it produces {U} instead of any other type" — the colour changes, the amount does not. | 106.1b | `MtgPlayer.land_mana_becomes`, applied in `MtgGame.tap_for_mana` | Deep Water (`drk/deep_water.gd`) |
| Until-EOT keyword and protection grants | "Gains banding until end of combat", "gains protection from white until end of turn" — CR 613 layer 6, applied before the losses so a loss still wins. | 613 layer 6 | `ContinuousEffects.add_until_eot_keywords` / `add_until_eot_protection` | Battering Ram, Goblin Wizard (`drk/goblin_wizard.gd`) |
| Player-target predicates | "Target player who attacked this turn" — a targeting restriction on a PLAYER. | 115.4 | `TargetSpec.with_player_filter`, `MtgPlayer.attacked_this_turn` | Fire and Brimstone (`drk/fire_and_brimstone.gd`) |
| "Acted on their last turn" | Whether a seat cast a spell or put a nontoken permanent onto the battlefield during a turn of THEIRS. | — | `MtgPlayer.acted_this_turn` / `acted_last_turn` | Arboria (`leg/arboria.gd`) |
| No duplicate targets | "Two target creatures" means two different ones — enforced across the whole spell. | 601.2c | `TargetPlan._validate` | — |
| Grouping to resolution | The plan's per-effect groups travel on the stack item so resolution knows which refs belong to which effect. | 608.2 | `StackItem.target_groups`, `EffectBase.resolve_multi` | — |
| Aura attachment legality | Asks only what the host IS (kind + filters), never whether it could be targeted — so a host that gained shroud keeps its Aura. | 704.5m | `TargetSpec.can_attach_to` | Spectral Cloak |

**Simplification here:** "X target creatures" takes as many as exist when
fewer than X are legal instead of forcing a smaller X — marked `SIMPLIFIED:`
in `target_plan.gd`, ROADMAP.

---

## 5. Combat

`CombatState` owns declarations and legality; all damage arithmetic lives in
`MtgGame`'s damage-step machinery so life/damage mutation stays in one file.

### Declaration and legality

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Attack legality | Must be an untapped creature without defender, not summoning-sick (or hasty), not under an attack ban, and satisfying "can't attack unless the defender controls a `<land type>`". | 508.1 | `CombatState.attack_illegality`, `CardData.attack_needs_defender_land` | Sea Serpent (`2ed/sea_serpent.gd`) |
| Attacking taps | Unless vigilance; the tap is a real `BECAME_TAPPED` event. | 508.1f | `MtgGame.declare_attackers` | Serra Angel |
| Attack requirements | "Attacks each combat if able" (keyword) and per-turn conscription (instance flag). Both are excused by a blanket ban or an attacker cap, so the step can always be left. | 508.1d | `Mtg.Keyword.MUST_ATTACK`, `CardInstance.must_attack_this_turn`, `MtgGame.declare_attackers` | Juggernaut (`2ed/juggernaut.gd`), Nettling Imp (`2ed/nettling_imp.gd`) |
| Attack bans | Game-level ("creatures can't attack this turn"), static (`cur_cant_attack`), and per-creature ("can't attack during your next turn"). | 508.1a | `MtgGame.no_attacks_this_turn`, `CardInstance.cur_cant_attack`, `cant_attack_next_turn` / `cant_attack_this_turn` | Festival (`drk/festival.gd`), Moat (`leg/moat.gd`), Giant Turtle (`leg/giant_turtle.gd`) |
| Attacker / blocker caps | "No more than N creatures may attack/block each combat", rebuilt by the continuous pipeline. | 508.1a, 509.1b | `MtgGame.max_attackers` / `max_blockers` | Caverns of Despair (`leg/caverns_of_despair.gd`) |
| Banding (offensive) | Creatures may be declared in bands; at most one member may lack banding. | 702.22c | `CombatState.bands`, `band_illegality`, `band_of`, `all_bands` | Benalish Hero (`2ed/benalish_hero.gd`), Helm of Chatzuk (`2ed/helm_of_chatzuk.gd`) |
| "Bands with other <quality>" | The SECOND form of CR 702.22c, and not the banding keyword: a creature may be given "bands with other [quality]" on its own (each grant is a description plus a filter). A band is legal when some member offers a quality EVERY member has — so any number of them attack together, where plain banding allows only one member without the keyword — and a creature holding only this is just that one keywordless member of somebody else's band. Losing banding loses these as well (702.22b, Tolaria). | 702.22b-c | `CardInstance.cur_bands_with` / `grant_bands_with`, `CombatState.shared_bands_with` / `bands_with_offered` | the five Legends banding lands (`leg/adventurers_guildhouse.gd`, `leg/cathedral_of_serra.gd`, `leg/mountain_stronghold.gd`, `leg/seafarer_s_quay.gd`, `leg/unholy_citadel.gd`), Master of the Hunt's Wolves (`leg/master_of_the_hunt.gd`) |
| Banding (defensive) | If any creature blocking an attacker has banding — or two blockers are paired by one of them holding "bands with other [quality]" the other has — the DEFENDING player divides that attacker's combat damage among its blockers, and divides it FREELY (510.1c's lethal-first order does not apply), so a trampler spills nothing. | 702.22f-j | `CombatState.bands_with_among`, the `assigner` / `free_order` flags of `MtgGame._collect_damage_requests`, `_split_illegality`, `default_damage_split` | Benalish Hero, Fortified Area (`4ed/fortified_area.gd`), Wall of Caltrops (`leg/wall_of_caltrops.gd`), Cathedral of Serra (`leg/cathedral_of_serra.gd`) |
| Block legality | Untapped defending creature; unblockable, flying vs flying/reach, protection's B, landwalk (live types, honouring nullifiers), blocker-subtype bans, both power thresholds, fear, and arbitrary "can't be blocked except by …" restrictions. | 509.1 | `CombatState.block_illegality` | Juggernaut, Invisibility (`2ed/invisibility.gd`), Ironclaw Orcs (`2ed/ironclaw_orcs.gd`), Amrou Kithkin (`4ed/amrou_kithkin.gd`) |
| Landwalk | Unblockable while the defender controls a land of that type — read off LIVE landwalk, so granted walks count. | 702.14 | `CardInstance.cur_landwalk`, `CombatState._controls_land_of_type` | Goblin King (`2ed/goblin_king.gd`) |
| Landwalk nullifiers | "May be blocked as though it didn't have landwalk" — a blocking-rule change, deliberately NOT an ability loss. | 702.14 | `MtgGame.nullified_landwalk` | Undertow (`leg/undertow.gd`), Gosta Dirk (`leg/gosta_dirk.gd`) |
| Multi-block | Any number of blockers may gang up on one attacker. | 509.1, 509.2 | `CombatState.blocks`, `blockers_of`, `blockers_of_band` | — |
| Forced blocking | "All creatures able to block it do so", optionally narrowed to a subset of would-be blockers; excused by a blocker cap. | 509.1c | `CardInstance.cur_must_be_blocked`, `cur_must_be_blocked_filter` | Lure (`2ed/lure.gd`) |
| Ordered to block | "It blocks each attacking creature this turn if able." | 509.1c | `CardInstance.must_block_this_turn` | Blaze of Glory (`2ed/blaze_of_glory.gd`) |
| Piles instead of blocks | "Instead of declaring blockers", the defender divides any number of their creatures into one pile per attacker (one turn-based OPTION question per creature that could block at all, "No pile" / "Pile 1" … "Pile N", held for a human seat and replayed as the `"blockers"` cost action), the piles are dealt to the attackers at random on `game.rng`, and a pile member that can legally block its attacker does so. Lure's and Blaze of Glory's requirements do not apply to the spell's procedure. | 509.1 | `MtgGame.camouflage_this_turn`, `_camouflage_block_map`, `declare_blockers` | Camouflage (`2ed/camouflage.gd`) |
| Rampage | +N/+N per blocker beyond the first, applied as an until-EOT pump right after blockers are declared and before the blockers-declared event. Combat reads the LIVE value, so rampage can be GRANTED — by a static (Gabriel Angelfire's upkeep choice) or as a floating until-EOT grant (Rapid Fire); the largest grant wins rather than stacking. | 702.23 | `CardInstance.cur_rampage` (printed source: `CardData.rampage` / `with_rampage`), `ContinuousEffects.add_until_eot_rampage`, `MtgGame.declare_blockers` | Frost Giant (`leg/frost_giant.gd`), Gabriel Angelfire (`leg/gabriel_angelfire.gd`), Rapid Fire (`leg/rapid_fire.gd`) |
| Once blocked, stays blocked | Killing or bouncing the blocker does not let the attacker through — only trample does. | 509.1h, 510.1c | `CombatState.blocked_attackers`, `was_blocked` | — |
| Block history | Every creature a blocker blocked this turn, mapped to the controller it had at that moment. | — | `CardInstance.blocked_ids_this_turn`, `blocked_this_turn` | Glyph of Reincarnation (`leg/glyph_of_reincarnation.gd`) |
| Combat re-arrangement | Re-point an existing blocker mid-combat (the caster picks the attacker — an OPTION per attacker plus "Don't block"); remove a creature from combat; borrow a permanent until cleanup. Raging River's banks are the players' choices too: the defender sorts each non-flyer ("left bank" / "right bank"), then the attacking player labels each attacker (`@RAGING_RIVER` "attack on left bank." / "attack on right bank."), riding `cur_block_restrictions`. | 506.4 | `MtgGame.set_block`, `remove_from_combat`, `gain_control_until_eot` | False Orders (`2ed/false_orders.gd`), Raging River (`2ed/raging_river.gd`), Disharmony (`leg/disharmony.gd`) |
| Removed from combat on control change | A stolen attacker stops attacking; a stolen blocker stops blocking. | 506.4 | `MtgGame.change_control` | Control Magic (`2ed/control_magic.gd`) |
| Removed from combat when exiled, and when arriving | An exiled attacker stops attacking (nothing can block it any more) and an exiled blocker stops blocking; anything that ENTERS the battlefield drops the stale combat entries under its instance id, so a card exiled and returned in the same combat (Tawnos's Coffin untapped mid-combat) does not strike twice. | 506.4, 400.7 | `CombatState.forget`, `MtgGame.exile_permanent` / `_put_on_battlefield` | Tawnos's Coffin (`atq/tawnos_s_coffin.gd`) |
| Combat state ends with the PHASE | "Attacking"/"blocking" status and until-end-of-combat effects survive into the end-of-combat step and end when the phase does. | 506.4, 511.3, 700.5 | `MtgGame._advance_step` COMBAT_END branch, `ContinuousEffects.expire_end_of_combat` | Desert (`arn/desert.gd`) |

### Damage assignment

| Mechanic | What it does | CR | Engine |
|---|---|---|---|
| Two STEPS | First-strike creatures deal damage in `Mtg.Step.FIRST_STRIKE_DAMAGE`, everyone else in `COMBAT_DAMAGE`, with a full PRIORITY ROUND between them — which is when you finish off the survivor or pump the creature that has yet to strike. The step does not exist at all unless someone in combat has first strike, and membership is frozen when it begins, so a creature that loses first strike between the steps does not strike twice. There is no double strike. | 510.4, 510.5 | `MtgGame._combat_damage_step`, `_has_first_strike_damage`, `_first_strike_ids` |
| Simultaneous within a step | Every division is planned and answered BEFORE anything is dealt, then applied with state-based actions deferred, so trades kill both and a dying creature still hears its own damage triggers. | 510.4, 704.3 | `MtgGame._apply_damage_requests`, `_defer_state_based_actions` |
| The ATTACKER assigns | The attacking player announces the damage assignment ORDER as blockers are declared (`DecisionAgent.order_blockers` → `CombatState.damage_order`) and DIVIDES the damage at the damage step (`assign_combat_damage`), lethal to each blocker before the next. A seat that wants to decide for itself holds the step open (`awaiting_damage_assignment`) and answers through `MtgGame.assign_combat_damage`; every other seat answers through its agent, whose default is the engine's old lethal-first spread (`default_damage_split`). | 509.2, 510.1c | `MtgGame._collect_damage_requests`, `_resume_damage_assignment`, `_split_illegality` |
| Trample | Excess over the blockers' lethal may go to the defending player, and only once EVERY blocker has lethal (the `MtgGame.DAMAGE_TO_PLAYER` key of a division); without trample the excess is wasted. | 702.19, 510.1c-d | `default_damage_split`, `_split_illegality` |
| Band damage | A blocker that blocks any band member fights the whole band: its damage is divided across members (through the same agent hook) lethal-first in band order, leftovers joining the last member. | 702.22j, 510.1d | `_collect_damage_requests` blocker side, `spill_to_last` |
| Fog | A game-level flag, checked per damage STEP, so a Fog cast in the first-strike priority window still stops the normal damage; non-combat damage is untouched. | 615 | `MtgGame.combat_damage_prevented`, `PreventCombatDamageEffect` |

**Simplifications here:** the BAND spread (a blocker facing several band
members, CR 702.22j) goes through the same agent hook but is credited to the
BLOCKER's controller rather than the attacking player, and its leftover joins
the last band member — ROADMAP. Everything else on this list has been lifted:
defensive banding divides freely for the defender (2026-09-01), one blocker
may be assigned to several attackers (`CombatState.extra_blocks`, 2026-09-02
— what is still missing is the HUMAN half, `duel_screen.gd`'s block picker,
see ROADMAP), and "bands with other [quality]" is a real per-quality
restriction rather than plain banding (2026-09-02).

---

## 6. Damage and prevention

`MtgGame.deal_damage(source, target, amount, is_combat, after)` is the single
entry point. It returns the amount ACTUALLY dealt after prevention (Drain Life
reads it) and checks state-based actions on the way out. `is_combat` is set only
by the combat-damage waves, which is what lets Gaseous Form stop a creature's
combat damage while leaving its ping ability alone.

Internally it is TWO halves (docs/duel-todo.md §6.8): `_plan_damage` builds a
**`DamagePacket`** — damage as an OBJECT, with a source, a victim, an amount,
how much of it has been `prevented`, and an id a `TargetRef` can name — and
`_land_damage` runs that packet through the gates below and applies what
survives. With no damage-prevention window open the two run back to back and
this is the same function it always was; every `DAMAGE_DEALT` event carries its
packet. The optional `after: Callable(dealt)` is for callers that need the
amount that ACTUALLY landed even when a window has moved the answer into the
future ("you gain life equal to the damage dealt this way").

**The 1997 DAMAGE-PREVENTION WINDOW** (`RulesOptions.damage_prevention_window`,
default off — modern Magic has no such step) turns the gates from an automatic
order into a player's choice. Packets queue in `MtgGame.damage_pending` instead
of landing; `awaiting_damage_prevention` opens where a player would next receive
priority; only effects flagged `EffectBase.is_damage_prevention` may be used;
`end_damage_prevention(pid)` closes it and every packet lands AT ONCE. A
redirect makes a second window; then `awaiting_regeneration` opens over whatever
holds lethal damage, with state-based actions still deferred, and only
`EffectBase.is_regeneration` effects are legal there. The window is opt-in per
seat (`DecisionAgent.wants_damage_prevention_window`), so an AI-only duel and
every headless test never pause even with the fork on.

Damage to a **player** is filtered in this order:

1. source has "prevent all damage it would deal" (`cur_prevent_all_damage_dealt`);
2. combat-only version of the same (`cur_prevent_combat_damage_dealt`);
3. reverse-to-life shields (`MtgPlayer.reverse_damage_shields`) — Reverse Damage;
4. unblocked-attacker redirection (`MtgPlayer.combat_damage_redirect`) — Veteran Bodyguard;
5. artifact-source redirection (`MtgPlayer.artifact_damage_redirect`) — Martyrs of Korlis;
6. colour-matched one-shot shields (`MtgPlayer.prevention_shields`) — the Circles of Protection;
7. predicate one-shot shields (`MtgPlayer.prevention_shield_filters`) — CoP: Artifacts;
8. the amount-based prevention pool (`MtgPlayer.damage_prevention`) — Healing Salve;
9. the life floor (`MtgPlayer.min_life_from_damage`) — Ali from Cairo;
10. life is lost, bookkeeping updated, `DAMAGE_DEALT` fires.

Damage to a **creature**:

1. protection from the source's colours (the D of DEBT, `cur_protection`);
2. "prevent all damage from creatures" (`cur_prevent_damage_from_creatures`);
3. one-shot redirection to a player (`damage_redirect_to` / `damage_redirects`) — Jade Monolith; then the METERED one (`damage_point_redirect_to` / `damage_point_redirects`, one point per activation, the rest of the event carries on down this list) — Personal Incarnation;
4. a face-down permanent is turned face up first;
5. "prevent all damage taken" (`cur_prevent_all_damage_taken`);
6. combat-only version (`cur_prevent_combat_damage_taken`);
7. source-filtered immunities (`cur_damage_immunity`) — Camel (`arn/camel.gd`), Argothian Pixies (`atq/argothian_pixies.gd`);
8. the amount-based pool (`CardInstance.prevention`);
9. damage is marked, life-on-damage watchers pay out, `DAMAGE_DEALT` fires.

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Protection | The full DEBT bundle: can't be Damaged, Enchanted, Blocked or Targeted by those colours. | 702.16 | `CardData.protection_from`, `CardInstance.cur_protection` / `added_protection`; enforced in `deal_damage`, SBAs, `CombatState`, `TargetSpec` | White Knight (`2ed/white_knight.gd`), Rainbow Knights (`past/rainbow_knights.gd`) |
| Ward auras | Grant the host protection and exempt themselves from the resulting eviction. | 702.16d | `CardData.grants_host_protection` / `aura_grants_protection` | White Ward (`2ed/white_ward.gd`) |
| Prevention pools | Amount-based, per-turn, consumed point for point. | 615 | `CardInstance.prevention`, `MtgPlayer.damage_prevention`, `PreventDamageEffect` | Samite Healer (`2ed/samite_healer.gd`) |
| One-shot shields | Whole-event shields keyed on a colour or on a source predicate — or, under the 1997 window, a target on ONE waiting packet. | 615 | `PreventDamageShieldEffect`, `.from_sources()`, `TargetSpec.Kind.DAMAGE` | Circle of Protection: Artifacts (`4ed/circle_of_protection_artifacts.gd`) |
| Damage as an object | One damage event, reified: source, victim, amount, prevented, id. Two with the same source and victim MERGE (the Manabarbs ruling). Targetable while a prevention window holds it. | 609.7a | `DamagePacket`, `MtgGame.damage_pending` / `find_packet`, `TargetRef.damage()` | Circle of Protection: Green (`2ed/circle_of_protection_green.gd`) |
| The damage-prevention step | A real priority window after damage is dealt, in which only prevention/healing/redirection may be used; then a second one in which only regeneration may be. A RULES FORK — modern Magic has neither. | — (Fifth Edition; `Duel.hlp` Damage Dealing) | `RulesOptions.damage_prevention_window`, `MtgGame.awaiting_damage_prevention` / `awaiting_regeneration` / `end_damage_prevention`, `EffectBase.is_damage_prevention` / `is_regeneration` | Healing Salve (`2ed/healing_salve.gd`), Drudge Skeletons (`2ed/drudge_skeletons.gd`) |
| Combat-damage prevention | Per-creature "dealt by" and/or "dealt to", as static flags or until-EOT floats. | 615 | `ContinuousEffects.add_until_eot_combat_prevention`, `cur_prevent_combat_damage_dealt` / `_taken` | Gaseous Form (`4ed/gaseous_form.gd`), Lady Evangela (`leg/lady_evangela.gd`) |
| Damage-to-life watches | "Whenever that creature is dealt damage this turn, you gain that much life" — a floating watch that outlives its source. | 603.7a | `MtgGame.watch_damage_for_life`, `life_on_damage_watchers` | Glyph of Life (`leg/glyph_of_life.gd`) |
| Regeneration | A shield replaces the next destruction with tap + clear damage + remove from combat. Shields expire at cleanup; "can't be regenerated" ignores them. | 701.15 | `CardInstance.regeneration_shields` / `regeneration_banned_this_turn`, `MtgGame.destroy`, `RegenerateEffect` | Drudge Skeletons (`2ed/drudge_skeletons.gd`), Terror |
| Indestructible | Destruction and lethal damage both do nothing. | 700.4 | `CardInstance.cur_indestructible` | Consecrate Land (`2ed/consecrate_land.gd`) |
| Poison | Ten or more poison counters loses the game as a state-based action. | 704.5c | `MtgPlayer.poison`, `MtgGame.add_poison` | Marsh Viper (`4ed/marsh_viper.gd`), Pit Scorpion (`4ed/pit_scorpion.gd`) |
| Life gain / loss | Outside damage, so no prevention applies; a replacement may turn life gain into draws. | 119.3, 614 | `MtgGame.adjust_life`, `MtgPlayer.life_gain_becomes_draw`, `GainLifeEffect` | Lich (`2ed/lich.gd`) |
| Damage bookkeeping | Who damaged this creature, which players this permanent damaged, and per-player totals this turn. | — | `CardInstance.damaged_by_this_turn` / `damaged_players_this_turn`, `MtgPlayer.damage_taken_this_turn` / `artifact_damage_this_turn` | Sengir Vampire (`2ed/sengir_vampire.gd`), Whirling Dervish (`4ed/whirling_dervish.gd`), Reverse Polarity (`atq/reverse_polarity.gd`) |

---

## 7. Continuous effects — the CR 613 passes as they exist today

`ContinuousEffects.recalculate(game)` recomputes every battlefield permanent's
current characteristics from scratch after every state change. It is
idempotent by contract, and this is the ONE method the full layer system would
be built inside. What it does today, in order:

| # | Pass | Layer it stands for | Code |
|---|---|---|---|
| 0 | Reset the per-recalculation game/player fields the statics rebuild (`nullified_landwalk`, `max_attackers`/`max_blockers`, `untap_caps`, `unlimited_land_plays`, `mana_substitutions`, `max_hand_size`, `min_life_from_damage`, both damage-redirect slots, `cant_lose_to_life`, `life_gain_becomes_draw`). | — | top of `recalculate` |
| 1 | Reset each permanent to printed values, re-applying instance-level permanent modifiers (`added_types`, `removed_keywords`, `added_protection`, `color_override`) and TEXT CHANGES, then the face-down override. | 613 layer 1 + layer 3 | `CardInstance.reset_characteristics`, `_apply_text_changes` |
| 2 | Until-EOT ANIMATIONS: add types/subtypes and SET base P/T. | layers 4 + 7b | `_animations` |
| 3 | Type-changing STATICS, in timestamp order, run TWICE when more than one is on the board (a crude stand-in for dependency analysis). | layer 4 | `battlefield_with_type_statics()`, `StaticAbility.changing_types` |
| 4 | Base-P/T-SETTING statics (characteristic-defining abilities). | layers 7a/7b | `StaticAbility.setting_base_pt` |
| 5 | Floating "has base power/toughness N until end of turn" sets — later timestamp than any setter above. | layer 7b | `_base_pt` |
| 6 | Until-EOT COLOUR changes, in creation order (last cast wins). | layer 5 | `_color_changes` |
| 7 | All remaining statics (the anthems and everything untagged), in timestamp order. | layers 6, 7c, and the rest | `battlefield_with_statics()` |
| 7b | FLOATING STATICS — a `StaticAbility` whose source has left the battlefield — run at the tail of each of the five static sub-passes above, in the same layer order. | the same layers, later timestamp | `_floating_statics`, `_floating_statics_pass` |
| 8 | COUNTERS: any counter whose NAME parses as `+A/+B` moves P/T by that delta times its count. | layer 7d | `_parse_pt_counter` |
| 9 | Floating until-EOT PUMPS and granted keywords, in creation order. | layer 7c | `_floating` |
| 10 | Floating LANDWALK grants. | layer 6 | `_landwalk_grants` |
| 11 | Floating BLOCK RESTRICTIONS (the same list statics write into). | layer 6 | `_block_restrictions` |
| 12 | ABILITY LOSSES (keywords and/or all landwalk), applied after every granting pass. | layer 6 | `_losses` |
| 13 | Floating COMBAT-DAMAGE shields (and their all-damage variants). | layer 6 | `_combat_prevention` |
| 14 | P/T SWITCHES, last, in creation order — two switches cancel out. | 613.4e | `_switches` |

Registration and expiry:

| Mechanic | What it does | Engine | Example |
|---|---|---|---|
| Until-EOT registries | Nine floating lists, each with an `until_end_of_combat` variant. | `add_until_eot_pump`, `add_until_eot_animation`, `add_until_eot_base_pt`, `add_until_eot_landwalk`, `add_until_eot_loss`, `add_until_eot_combat_prevention`, `add_until_eot_block_restriction`, `add_until_eot_color`, `add_until_eot_pt_switch` | Giant Growth, Mishra's Factory (`4ed/mishra_s_factory.gd`), Island of Wak-Wak (`arn/island_of_wak_wak.gd`), Scarwood Hag (`drk/scarwood_hag.gd`), Hammerheim (`leg/hammerheim.gd`), Transmutation (`leg/transmutation.gd`) |
| Expiry at cleanup (CR 514.2) | Everything floating whose `lasts` is END_OF_TURN is dropped; the longer durations below survive it. | `ContinuousEffects.expire_until_eot` | — |
| Expiry at end of combat (CR 700.5) | Only entries flagged `until_combat`. | `ContinuousEffects.expire_end_of_combat` | Jade Statue (`2ed/jade_statue.gd`) |
| Longer durations (CR 611.2b) | Every floating entry carries a `lasts`: END_OF_TURN, END_OF_COMBAT, **UNTIL_UPKEEP_OF** a named player (ended as that upkeep step opens, before its triggers stack) and **INDEFINITE** (only the zone change ends it). | `ContinuousEffects.Duration`, `expire_upkeep_of` | Xenic Poltergeist (`4ed/xenic_poltergeist.gd`), Erhnam Djinn (`arn/erhnam_djinn.gd`), Brine Hag (`leg/brine_hag.gd`) |
| Granted ACTIVATED abilities | "That creature gains '&lt;cost&gt;: &lt;effect&gt;'" — a registry entry on the creature, INDEFINITE by default because a grant with no stated duration has none, so it outlives the permanent that granted it. | `ContinuousEffects.add_granted_activated_ability` | Life Matrix (`leg/life_matrix.gd`) |
| Zone change forgets (CR 400.7) | Every float keyed to the departing id is dropped — whatever comes back is a new object. Phasing deliberately does NOT call this. | `ContinuousEffects.forget_instance` | — |
| Static abilities | A `Callable(game, source)` run every pass; tag it `.changing_types()` or `.setting_base_pt()` to move it into an earlier pass. | `StaticAbility` | Crusade (`2ed/crusade.gd`), Nightmare (`2ed/nightmare.gd`), Blood Moon (`drk/blood_moon.gd`) |
| A static that OUTLIVES its source | "If this enchantment leaves the battlefield, this effect continues until end of turn": the same `StaticAbility` is registered as a floating one and keeps running for its stated duration. CR 611.3a still applies — the effect is NOT locked in to the objects it was affecting, so something that arrives afterwards is affected too. The entry carries `instance_id` -1 so `forget_instance` (which fires on exactly the departure that created it) cannot drop it. | `ContinuousEffects.add_floating_static`, registered from `CardData.as_it_leaves` | Titania's Song (`4ed/titania_s_song.gd`) |
| "Loses all abilities" | Live mana/activated lists are cleared and a flag suppresses the triggered and static ones for the dispatcher and the pipeline. | `CardInstance.cur_abilities_silenced` | Titania's Song (`4ed/titania_s_song.gd`) |
| Durationless keyword grants and losses | "That creature gains flying" with NO duration lasts while the permanent stays on the battlefield (CR 611.2) — an instance-level list re-applied on every characteristics reset, grants first, losses after, cleared on the zone change. | `CardInstance.added_keywords` / `removed_keywords`, `MtgGame.grant_keyword_permanently` / `remove_keyword_permanently` | Cocoon (`leg/cocoon.gd`), Elder Land Wurm (`4ed/elder_land_wurm.gd`) |
| Basic-land retyping | Changing a land's subtype to a basic type replaces its mana ability and drops its rules-text abilities. | `CardInstance.become_basic_land_type` (CR 305.7) | Evil Presence (`2ed/evil_presence.gd`) |
| Text changes | Indefinite layer-3 changes reaching subtypes, landwalk types, protection colours, and a basic land's mana. | `CardInstance.text_changes`, `MtgGame.change_text`, `Mtg.BASIC_LAND_COLORS` | Magical Hack (`2ed/magical_hack.gd`), Sleight of Mind (`2ed/sleight_of_mind.gd`), Quarum Trench Gnomes (`leg/quarum_trench_gnomes.gd`) |
| Live colours | `cur_colors` is what every rules check reads; indefinite changes ride on `color_override` (and survive a spell resolving into a permanent), until-EOT ones float. | `MtgGame.set_color`, `ChangeColorEffect`, `CardInstance.has_color` / `is_colorless` | Thoughtlace (`2ed/thoughtlace.gd`) |

**Simplification here:** this is a simplified CR 613 — there is no general
timestamp ordering across layers, no dependency analysis beyond the two-round
type pass (CR 613.8), and no "indefinite" duration for base-P/T sets. All of
it is contained in `recalculate` — ROADMAP; the card-visible consequences are
in simplified-cards (*Brine Hag*, *Wall of Tombstones*).

---

## 8. State-based actions

`MtgGame.check_state_based_actions()` runs after every mutation and whenever a
player would receive priority, looping until nothing more applies. A "fast
pass" walks every permanent for two comparisons; a "slow pass" walks only
`_sba_watch` — the permanents that actually carry a rare clause.

| Check | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Life ≤ 0 | That player loses, unless a replacement says otherwise. | 704.5a | `check_state_based_actions`, `MtgPlayer.cant_lose_to_life` | Lich |
| Ten poison counters | That player loses. | 704.5c | `MtgPlayer.poison` | Marsh Viper |
| BOTH seats losing at once | The game is a DRAW: `winner` stays -1 and `is_draw` records why. The loss checks are COLLECTED in one pass and only then acted on, because CR 704.4 performs every applicable action simultaneously. | 704.4, 104.4b | `check_state_based_actions`, `_check_lethal_life`, `MtgGame.draw_game` | Earthquake (`2ed/earthquake.gd`) for lethal to both |
| Toughness ≤ 0 | The creature dies; NOT destruction, so regeneration can't save it. | 704.5f | `_move_to_graveyard(inst, true)` | Weakness (`2ed/weakness.gd`) on a 1/1 |
| Lethal damage | The creature is destroyed, so regeneration shields apply; indestructible skips both this and the previous check. | 704.5g, 700.4 | `MtgGame.destroy` | — |
| Aura with no host | Falls into the graveyard. | 704.5m | aura branch of the slow pass | Holy Strength (`2ed/holy_strength.gd`) |
| Aura on an illegal host | Checked with `can_attach_to`; Animate-Dead-style auras are exempt. | 704.5m | `TargetSpec.can_attach_to` | Firebreathing (`2ed/firebreathing.gd`) on an expired Mishra's Factory |
| Aura on a protected host | The host gaining protection from the aura's colour sheds it, except the protection that very aura grants. | 702.16d | slow pass, `aura_grants_protection` mask | White Ward |
| The legend rule (1997 flavour) | While two or more legendary permanents share a NAME, the NEWEST is buried — the era's "first in time, first in right", not the modern controller's choice. | 704.5j (era variant) | `_newest_duplicate_legend` | Jacques le Vert (`leg/jacques_le_vert.gd`) |
| The world rule | While two or more WORLD permanents are on the battlefield, all but the newest are put into their owners' graveyards — across names, not just per name. | 704.5k | `_superseded_world_permanent`, `Mtg.Supertype.WORLD` | The Abyss (`leg/the_abyss.gd`), Living Plane (`leg/living_plane.gd`) |
| "Sacrifice this when you control no `<land type>`" | Printed as a state trigger; indistinguishable from an SBA here. | 704.3 | `CardData.sacrifice_if_no_land_type` | Dandân (`arn/dandan.gd`), Merchant Ship (`arn/merchant_ship.gd`) |
| "Sacrifice this when you control a `<subtype>`" | The mirror clause. | 704.3 | `CardData.sacrifice_if_you_control_subtype` | Goblins of the Flarg (`drk/goblins_of_the_flarg.gd`) |
| General "sacrifice this when `<condition>`" | An arbitrary predicate on the card. | 704.3 | `CardData.sacrifices_when` / `sacrifice_condition` | Jihad (`arn/jihad.gd`) |
| Control leashes | "For as long as you control X" / "for as long as X remains tapped": the permanent goes home the instant the condition fails. | — (engine construct for 611.2b durations) | `CardInstance.controlled_via` / `leash_needs_tapped`, `MtgGame.gain_control_leashed` | Old Man of the Sea (`arn/old_man_of_the_sea.gd`), Rubinia Soulsinger (`leg/rubinia_soulsinger.gd`) |
| Drawing from an empty library | Loses the game — checked at draw time rather than as an SBA. Milling out is not a loss. | 104.3c, 120.3 | `MtgGame.draw_cards`, `MtgGame.mill` | Millstone (`4ed/millstone.gd`) |
| Tokens cease to exist | Handled by the zone-change helpers rather than the SBA loop. | 704.5e, 111.7 | `return_to_hand`, `exile_permanent`, `_move_to_graveyard` | The Hive (`2ed/the_hive.gd`) |

**SIMULTANEITY.** CR 704.3 checks state-based actions when a player WOULD
receive priority, never in the middle of one effect. An effect that hits
several things at once brackets itself with
`MtgGame.begin_simultaneous()` / `end_simultaneous()` (nesting; only the
outermost sweeps), so nothing leaves the board until all of it has landed.
Two users today: the combat-damage wave (CR 510.4 — a creature that dies to
the first packet still deals its own damage and still hears its damage
triggers) and `DamageAllEffect` (CR 704.4 — an Earthquake lethal to both
duelists kills them together, which is a draw and not a win for whichever
seat the loop reached second).

---

## 9. Zones and zone changes

Zones are `Mtg.Zone`: LIBRARY, HAND, BATTLEFIELD, GRAVEYARD, STACK, EXILE,
ANTE. Two more piles live on `MtgPlayer` without being zone values:
`phased_out` and `outside_the_game`. The library's top is the END of the array
(`draw_cards` pops the back).

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Entering the battlefield | Applies the enters-as-copy replacement, marks EVERY permanent summoning-sick, applies `enters_tapped` and `enters_with_counters`, appends to the timestamp order, recalculates, runs the card's own "as this enters" replacement, recalculates again, fires `ENTERS_BATTLEFIELD`. | 614.1c, 302.6 | `MtgGame._put_on_battlefield` | Nevinyrral's Disk (`2ed/nevinyrral_s_disk.gd`), Triskelion |
| "As this enters, ..." | A card-supplied REPLACEMENT run with the permanent already on the battlefield (so it may pay, sacrifice or ask) but before state-based actions or any trigger has seen it — which is how a `*/*` body settles its size before the 0/0 sweep. What it decides goes in `CardInstance.memory`, published by a `setting_base_pt` static. NOT reachable by the choice pre-flight (docs/duel-todo.md §1.3), like every other as-enters replacement. | 614.1c | `CardData.as_it_enters` / `as_enters` | Shapeshifter (`4ed/shapeshifter.gd`), Wood Elemental (`leg/wood_elemental.gd`), Nameless Race (`drk/nameless_race.gd`) |
| Leaving the battlefield | Detaches a departing aura and settles its host's fate, wipes battlefield state (snapshotting last known information first), fires the leave/dies event WITH a memory snapshot, forgets floating effects, restores the printed identity. | 400.7, 603.6b-d | `_move_to_graveyard`, `return_to_hand`, `exile_permanent`, `move_to_ante` | Animate Dead (`2ed/animate_dead.gd`), Control Magic |
| Being REFUSED the battlefield | "Lands can't enter the battlefield" (radiated at every arrival) and "...put this creature into its owner's graveyard instead of onto the battlefield" (a card's veto on its own arrival). Asked at the top of `_put_on_battlefield`, before anything about the arrival has happened, so nothing sees the object enter, leave or die. A refused object stays where it came from — a search puts it back in the library it shuffles, a hand keeps it and `play_land` refuses in words — while a permanent SPELL goes to its owner's graveyard and a token ceases to exist. | 614.1c, 111.7 | `MtgGame.entry_refused` / `_arrival_refused`, `CardData.enters_ban_rule` / `entry_condition` | Worms of the Earth (`drk/worms_of_the_earth.gd`), Frankenstein's Monster (`drk/frankenstein_s_monster.gd`) |
| "As this LEAVES, ..." | The immediate twin of the as-enters replacement, and the only hook that runs at the INSTANT a permanent leaves: after its leave-triggers are on the stack and its own floating effects are forgotten, but before `recalculate()` un-applies its statics. A trigger cannot do this work — it resolves after the world has already been recomputed without the departing permanent. Receives the same parting `memory` snapshot the leave event carries, because the live one is wiped on the way out. | 611.3b (and what lifts it), 702.25f | `CardData.as_it_leaves` / `as_leaves`, `MtgGame._run_leave_hook` | Titania's Song (`4ed/titania_s_song.gd`), Oubliette (`arn/oubliette.gd`) |
| Destroy vs sacrifice vs exile vs bounce | Destroy honours regeneration and indestructible; sacrifice does not but still dies; exile and bounce are neither destruction nor a death. | 701.15, 701.17 | `MtgGame.destroy`, `sacrifice_permanent`, `exile_permanent`, `return_to_hand` | Terror, Strip Mine (`4ed/strip_mine.gd`), Swords to Plowshares (`2ed/swords_to_plowshares.gd`), Unsummon (`2ed/unsummon.gd`) |
| Death replacements | "Return it to its owner's hand instead" (with Firestorm Phoenix's rider: revealed in hand and unplayable until the owner's next turn) and "exile it instead", both suppressing the dies-trigger. | 614.1 | `CardData.dies_returns_to_hand` / `dies_to_hand_locks`, `CardInstance.hand_lock_turn` / `revealed_in_hand`, `CardInstance.exile_instead_of_dying` | Firestorm Phoenix (`leg/firestorm_phoenix.gd`), Disintegrate (`2ed/disintegrate.gd`) |
| Tokens | Ordinary `CardInstance`s with `is_token`: full ETB, sickness and dies-triggers, but they cease to exist on leaving and are dropped from the instance table. | 111.7, 704.5e | `MtgGame.create_token`, `schedule_end_step_token` | The Hive, Rukh Egg |
| Copies | Copying repoints `CardInstance.data`; the object keeps its id, counters, damage and controller. `printed_data` restores it the moment it leaves the battlefield — after its own leave/dies triggers were offered. | 707.2 | `MtgGame.become_copy`, `CardInstance.printed_data` / `restore_printed_identity`, `CardData.shallow_copy` / `with_extra_trigger` | Clone (`2ed/clone.gd`), Copy Artifact (`2ed/copy_artifact.gd`), Vesuvan Doppelganger (`2ed/vesuvan_doppelganger.gd`) |
| Enters-as-a-copy | A real replacement effect applied inside `_put_on_battlefield`, so a 0/0 Clone is never on the battlefield for SBAs to bury. | 614.1c | `CardData.with_enters_as_copy` / `enters_as_copy`, `MtgGame._apply_enters_as_copy` | Clone |
| Last known information | The live P/T, types, colours and subtypes at the moment of leaving, snapshotted before the wipe. `last_types` is why an animated land counts as a creature dying. | 608.2h | `CardInstance.last_power` / `last_toughness` / `last_types` / `last_colors` / `last_subtypes` | Creature Bond (`2ed/creature_bond.gd`), Diamond Valley (`arn/diamond_valley.gd`) |
| Control changes | Move between battlefield lists, keep the timestamp, pick up summoning sickness, and are removed from combat. | 302.6, 506.4 | `MtgGame.change_control` | Control Magic (`2ed/control_magic.gd`) |
| Leashed control | Held only while a condition holds; the SBA loop hands it back. | — | `MtgGame.gain_control_leashed`, `CardInstance.controlled_via` | Old Man of the Sea (`arn/old_man_of_the_sea.gd`) |
| Until-EOT control | Goes home at cleanup even if the effect that took it is gone. | 611.2b | `MtgGame.gain_control_until_eot`, `_control_until_eot` | Disharmony |
| Control EXCHANGE | Two permanents trade controllers as ONE action: all or nothing (both must still be on the battlefield, under different players), swapped inside a `begin_simultaneous` bracket so Auras and the legend rule judge the finished board. | 701.10 | `MtgGame.exchange_control` | Juxtapose (`leg/juxtapose.gd`), Gauntlets of Chaos (`leg/gauntlets_of_chaos.gd`), Power Struggle (`past/power_struggle.gd`) |
| Control-change ban | "Other players can't gain control of it" — one gate in the single door every control change goes through, so leashes, until-EOT borrows and exchanges are all covered. | — (611.2b-adjacent) | `CardInstance.cur_cant_change_control`, checked in `MtgGame.change_control` and `exchange_control` | Guardian Beast (`arn/guardian_beast.gd`) |
| Phasing | Lifts the permanent (and everything attached) out of the battlefield arrays so no query, static, trigger, SBA or target check sees it — without a zone change, so nothing triggers either way and its until-EOT effects survive. | 702.25 | `MtgGame.phase_out` / `phase_in`, `CardInstance.phased_out`, `MtgPlayer.phased_out` | Oubliette |
| Face down | A 2/2 colourless creature with no name, no other types and no abilities. Dealing damage, being dealt damage and becoming tapped all turn it up. | 708.2, 708.4 | `CardInstance.face_down`, `MtgGame.turn_face_down` / `turn_face_up` / `put_from_hand_face_down` / `exile_top_of_library` | Illusionary Mask (`2ed/illusionary_mask.gd`), Knowledge Vault (`leg/knowledge_vault.gd`) |
| Ante | A public zone holding each player's stake, with cards sitting in their OWNER's array. **The OPENING stake is `stake_ante(pid, count, exclude_basic_lands)`** — `count` uniformly-random cards lifted out of the library between `setup()` and `deal_opening_hands()`, which is the manual's own order (p.118: the minimum-deck padding goes in *"after the ante but before the shuffle"*). OPT-IN (`DuelConfig.ante`, the original's `&Ante` match parameter): `start()` never stakes, so nothing that did not ask for one loses a card or an RNG draw. The player's stake spares BASIC lands and the opponent's does not (Shandalar FAQ 1.9). SETTLING it at the end of the duel is adventure-layer and deliberately absent (`docs/duel-todo.md` §7). | 407 | `MtgGame.stake_ante` / `ante_enabled` / `all_ante` / `move_to_ante` / `ante_top_of_library` / `remove_from_ante`, `MtgPlayer.ante` | Contract from Below (`2ed/contract_from_below.gd`), Jeweled Bird (`arn/jeweled_bird.gd`) |
| Ownership transfer | The one change that outlives a duel: the card physically moves into the new owner's copy of its current zone. | 108.3 | `MtgGame.change_owner` | Bronze Tablet (`4ed/bronze_tablet.gd`), Tempest Efreet (`4ed/tempest_efreet.gd`) |
| Outside the game | Empty in a plain duel; the adventure layer will fill it. | 400 | `MtgPlayer.outside_the_game`, `MtgGame.take_from_outside_the_game` | Ring of Ma'rûf (`arn/ring_of_ma_ruf.gd`) |
| Putting a card from HAND onto the battlefield | Without casting it: the card leaves the hand and enters properly (ETB, summoning sickness, SBAs). Never a land drop. | 701.19 | `MtgGame.put_from_hand_into_play` | Eureka (`leg/eureka.gd`), Gaea's Touch (`drk/gaea_s_touch.gd`), Triassic Egg (`leg/triassic_egg.gd`) |
| Library and graveyard moves | Search-and-take, put into play, put into graveyard, return to hand / library top, reanimate, exile from graveyard, mill, shuffle hand and/or graveyard back in, return from exile to play / hand / graveyard. | 701.19 | `pick_from_library`, `search_library`, `put_into_play`, `put_into_graveyard`, `return_from_graveyard_to_hand`, `return_from_graveyard_to_library_top`, `reanimate`, `exile_from_graveyard`, `mill`, `shuffle_graveyard_into_library`, `shuffle_hand_into_library`, `shuffle_hand_and_graveyard_into_library`, `return_from_exile_to_play` / `_to_hand` / `_to_graveyard` | Demonic Tutor (`2ed/demonic_tutor.gd`), Timetwister (`2ed/timetwister.gd`), Feldon's Cane (`atq/feldon_s_cane.gd`) |
| Counters | Any kind by name; the pipeline reads the P/T ones by parsing the name, so a card may invent `-0/-2` or `+1/+0` and it just works. Counters vanish with the zone change. | 121.2 | `CardInstance.counters`, `MtgGame.add_counters`, `ContinuousEffects._parse_pt_counter` | Clockwork Beast (`2ed/clockwork_beast.gd`) |
| Auras | Cast targeting what they enchant; attach on resolution; steal or reanimate the host if flagged; detach and settle the host on any exit. | 303.4a | `CardData.enchants` / `aura_steals` / `reanimates`, `MtgGame._detach_departing_aura`, `attach_aura_from_anywhere` | Control Magic, Animate Dead, Takklemaggot (`leg/takklemaggot.gd`) |
| Moving an Aura | Re-attach an Aura already on the battlefield to a new host. NOT a zone change: nothing triggers, counters and floats survive, the timestamp does not move; refused when the new host is not something that Aura could enchant. | 701.3, 701.3d | `MtgGame.move_aura` | Kudzu (`2ed/kudzu.gd`) |
| Game end | A player loses (life, poison, empty draw, or a card saying so); a DRAW leaves `winner` at -1. | 104.2-4 | `MtgGame._lose`, `lose_game`, `draw_game`, `is_draw`, signal `game_ended` | Divine Intervention (`leg/divine_intervention.gd`) |

---

## 10. Triggers and delayed triggers

| Mechanic | What it does | CR | Engine | Example |
|---|---|---|---|---|
| Triggered abilities | `event_type` + optional `condition` + `on_resolve(game, source, event)`. The resolve callable receives the ORIGINAL event, so context is read from `event.data` rather than global state. | 603.1 | `TriggeredAbility`, `CardData.triggered` | Ankh of Mishra (`2ed/ankh_of_mishra.gd`) |
| Dispatch | Every event is offered to every battlefield permanent and mirrored on the `event_occurred` signal. | 603.2 | `MtgGame.dispatch_event`, `GameEvent` | — |
| APNAP ordering | The active player's triggers go on the stack first, so the non-active player's resolve first. | 603.3b | `dispatch_event` listener order | — |
| Trigger index | The battlefield cache derives which event types anyone listens for, so an unlistened event costs one dictionary probe. | — | `MtgGame._trigger_index`, `_rebuild_battlefield_index` | — |
| Departing card hears its own trigger | A dying or leaving permanent is added to the listener list for that one event. | 603.6b, 603.6d | `dispatch_event(..., also_listen)` | Su-Chi (`atq/su_chi.gd`), Sengir Vampire |
| Memory snapshots on leaving | Leave/dies events carry a copy of the departing permanent's card-local `memory`, because battlefield state is wiped first. | 400.7, 608.2h | `"memory"` key of `LEAVES_BATTLEFIELD` / `DIES` | Dance of Many (`drk/dance_of_many.gd`), Jihad |
| Graveyard triggers | Abilities that listen while their card is in a GRAVEYARD. Only `UPKEEP_START` and `END_STEP_START` reach them, so the hot dispatch path is untouched. | — | `CardData.graveyard_triggers` / `with_graveyard_trigger` | Nether Shadow (`2ed/nether_shadow.gd`) |
| Silenced abilities | A permanent that lost all abilities is skipped by the dispatcher. | 613 layer 6 | `CardInstance.cur_abilities_silenced` | Titania's Song |
| Ability-activated event | `ABILITY_ACTIVATED` names the permanent, its controller, the ACTIVATOR, the ability and whether {T} was in the cost. Dispatched after the ability is on the stack, so the trigger sits above it; mana abilities announce it too (they are activated abilities), gated on `has_trigger_listener` because that path runs for every land every turn. | 602.2b, 603.3b, 605.1a | `MtgGame.activate_ability`, `MtgGame.tap_for_mana`, `MtgGame.has_trigger_listener` | Artifact Possession (`atq/artifact_possession.gd`), Powerleech, Haunting Wind |

The event catalogue (`Mtg.EventType`, with its data keys documented on the
enum): `ENTERS_BATTLEFIELD`, `LEAVES_BATTLEFIELD`, `DIES`, `SPELL_CAST`,
`CARD_DRAWN`, `DAMAGE_DEALT`, `UPKEEP_START`, `END_STEP_START`,
`DECLARED_ATTACKERS`, `LAND_PLAYED`, `TAPPED_FOR_MANA`, `BECAME_TAPPED`,
`BECAME_UNTAPPED`, `DRAW_STEP`, `BLOCKED`, `END_OF_COMBAT`,
`BLOCKERS_DECLARED`, `ABILITY_ACTIVATED`.

Delayed and floating effects — all independent of the source that made them
(CR 603.7a), all cleared at the moment their window closes:

| Effect | Fires when | Engine | Example |
|---|---|---|---|
| "Destroy it at the beginning of the next end step" | END step | `MtgGame.doom_at_next_end_step`, `_end_step_doom` | Stone Giant (`2ed/stone_giant.gd`) |
| …only if it attacked / only if it did NOT attack | END step, condition checked then | `_end_step_doom_if_attacked`, `doom_at_next_end_step_if_it_did_not_attack` | Berserk, Nettling Imp |
| …as a sacrifice rather than a destruction | END step | `_end_step_doom_sacrifice` | Dragon Whelp (`2ed/dragon_whelp.gd`) |
| Delayed token creation | END step | `MtgGame.schedule_end_step_token`, `_end_step_tokens` | Rukh Egg |
| "Destroy that creature at end of combat" | COMBAT_END step | `MtgGame.doom_at_end_of_combat`, `_end_of_combat_doom` | Thicket Basilisk (`2ed/thicket_basilisk.gd`), Cockatrice (`2ed/cockatrice.gd`) |
| Arbitrary delayed end-of-combat action | COMBAT_END step | `MtgGame.schedule_end_of_combat_action` | Glyph of Doom (`leg/glyph_of_doom.gd`) |
| Damage-to-life watch | On any damage to the watched creature | `MtgGame.watch_damage_for_life` | Glyph of Life |
| Until-EOT control lease | Cleanup | `MtgGame.gain_control_until_eot` | Disharmony |
| Extra turn | When the turn would pass | `MtgGame.extra_turns` | Time Walk |

**Simplification here:** triggers cannot target (`TriggeredAbility` has no
target specs), so cards whose triggers should choose a target use the
`DecisionAgent`'s judgment instead — ROADMAP, plus the affected cards in
simplified-cards (*Oubliette*, *Halfdane*, *Copy choices*).

---

## 11. The card-authoring vocabulary

A card file is one `.gd` under `cards/sets/<set>/`, extends `CardScript`, and
returns a `CardData` from `build()`. The folder name becomes the set code; the
registry scans folders, so there is no manifest. See `docs/adding-cards.md`
for the checklist. 828 cards are implemented today; 68 documented stubs are
parked (unloaded) in `cards/todo/`.

**`CardData` builders** — `.pt`, `.with_keywords`, `.with_supertypes`,
`.with_subtypes`, `.oracle`, `.spell`, `.activated`, `.triggered`,
`.static_ability`, `.mana`, `.with_graveyard_trigger`, `.enchants`,
`.steals_control`, `.reanimates`, `.grants_host_protection`,
`.with_protection_from`, `.with_landwalk`, `.with_cant_be_blocked_by`,
`.with_cant_block_power_ge`, `.with_cant_be_blocked_by_power_ge`,
`.with_no_aura_targeting`, `.with_rampage`, `.with_dies_to_hand`,
`.with_may_skip_untap`, `.with_enters_counters`, `.with_enters_tapped`,
`.with_attack_needs_defender_land`, `.with_sacrifice_if_no_land`,
`.with_sacrifice_if_you_control`, `.sacrifices_when`, `.castable_only_when`,
`.bans_playing`, `.with_additional_sacrifice`, `.with_extra_cost_per_target`,
`.with_cost_modifier`, `.with_enters_as_copy`, `.mode`, `.with_ai_mode`,
`.shallow_copy`, `.with_extra_trigger`. Every one returns `self` so calls
chain.

**`EffectBase` subclasses** (one-shot resolution effects, all in
`engine/effects/`):

| Class | What it does |
|---|---|
| `DamageEffect` | N or X damage; `.any_target()`, `.target_creature()`, `.x_damage()`, `.to_controller()`, `.divided()` |
| `DamageAllEffect` | "N damage to each `<filter>` creature (and each player)" |
| `DestroyEffect` / `DestroyAllEffect` | Targeted and mass destruction, with a "can't be regenerated" flag |
| `ExileEffect` | Exile a target permanent |
| `ReturnToHandEffect` | Bounce |
| `ReturnFromGraveyardEffect` | To hand, or `.to_battlefield()`; `.any_card()` widens it past creatures |
| `DrawEffect` / `MillEffect` | Draw N or X (optionally targeted); mill N |
| `GainLifeEffect` | Life gain, or loss with a negative amount |
| `PumpEffect` / `MassPumpEffect` | +P/+T (+keywords) until EOT, to a target/self/all with `.yours_only()`, `.with_filter()`, `.excluding_source()` |
| `SetBasePowerToughnessEffect` / `SwitchPowerToughnessEffect` | Layer-7b base sets; the CR 613.4e switch |
| `AnimateSelfEffect` | "Becomes an N/N creature until end of turn / combat" |
| `GrantLandwalkEffect` / `LoseAbilityEffect` | Grant a walk; lose keywords and/or all landwalk (`.and_landwalk()`, `.to_source()`) |
| `ChangeColorEffect` | "Becomes `<colour>`", indefinitely or until EOT |
| `RegenerateEffect` | Build a regeneration shield on the source or a target |
| `PreventDamageEffect` / `PreventDamageShieldEffect` / `PreventCombatDamageEffect` | Amount pools; one-shot colour/predicate shields; the Fog and its per-creature variants |
| `CounterEffect` | Counter target spell |
| `TapEffect` / `UntapEffect` | Tap or untap targets (multi-target for free through `resolve_multi`) |
| `AddManaEffect` | Spell-produced mana (Dark Ritual) |
| `SearchLibraryEffect` | Tutor to hand or `.to_battlefield()` |
| `ExtraTurnEffect` | Queue an extra turn |
| `RandomEffectTable` / `RandomCreatureEffectTable` | The Astral grab-bags: Whimsy's 17 fast effects and Faerie Dragon's 20 creature effects (the 1997 lists), rolled through the game RNG |

Effects that need the whole target group at once override `resolve_multi`; the
default repeats `resolve` once per target. Variable counts and division are
declared with `.one_or_more()`, `.x_targets()` and `.divided_among()`; a slot
the GAME rolls ("random target creatures") with `TargetSpec.at_random()`.

**Ability classes** (`engine/abilities/`): `ActivatedAbility` (cost → effects,
uses the stack), `TriggeredAbility` (event match → resolve callable, uses the
stack unless it is a mana trigger), `StaticAbility` (a `Callable` re-run every
recalculation; tag it `.changing_types()` or `.setting_base_pt()` to move it
into an earlier pass), `ManaAbility` (stackless by design, CR 605.3).

Card-local scratch state lives in `CardInstance.memory`; the engine owns only
`x_value`, `sacrificed_mv`, `_sacrificed_power` and `_sacrificed_toughness`,
and clears the whole dictionary when the permanent leaves the battlefield.

---

## 12. Randomness and determinism

Every random decision goes through `MtgGame.rng`, so a seed plus a sequence of
API calls reproduces a game exactly — the basis of bug reports, the Deck Lab's
seed-stable parallelism, and AI self-play.

| Mechanic | Engine | Notes |
|---|---|---|
| Seeding | `MtgGame.setup(..., seed_value)` | `0` is an ordinary seed; pass `-1` for a deliberately random game |
| Shuffling | `MtgGame._shuffle` | Fisher–Yates on `rng`; never `Array.shuffle()`, which uses the global RNG |
| Coin flips | `MtgGame.flip_coin` (CR 705) | true = the flipping player won; Mijae Djinn (`arn/mijae_djinn.gd`) |
| Random discard | `MtgGame.discard_random` | Hypnotic Specter (`2ed/hypnotic_specter.gd`) |
| Random choosers | `RandomEffects.roll` / `pick` / `permanent` / `creature` / `spell_or_permanent` / `damage_target` / `player` / `color` / `card_in_graveyard` / `card_in_libraries` / `creature_type_of` / `distribute` | Pure choosers — they never mutate; callers act through `MtgGame` |
| Random effect tables | `RandomEffectTable.play` / `play_random`, `COUNT = 17` (`MESSAGES` = `@WHIMSY_MESSAGES`); `RandomCreatureEffectTable.play(game, source, controller, which, target)`, `COUNT = 20` (`@FAERIEDRAGON_MESSAGES`) | Whimsy (`past/whimsy.gd`), Faerie Dragon (`past/faerie_dragon.gd`) |
| Random targets | `TargetSpec.at_random(count_too)` — the slot is the GAME's to fill: `MtgGame._random_targets_refusal` (no candidate and one required → can't be cast) then `_fill_random_targets` (how many, which, the divided shares — CR 601.2c/d) as the spell/ability is put on the stack, logged "X's random target(s): …"; an empty slot is no target (CR 115.5) so it never fizzles for one | Faerie Dragon, Goblin Polka Band (`x_targets()`), Orcish Catapult (`at_random(true)` + `divided_among(-1)`) |
| The deal of Camouflage's piles | `MtgGame._camouflage_block_map` (the piles themselves are the defender's choice) | Camouflage |
| AI mistakes | `AiProfile.mistake_chance` rolled on `game.rng` | Seeded AI games replay line for line |

**A PROBE DOES NOT MOVE THE STREAM.** The §1.3 pre-flight resolves the top
of the stack once over a `GameSnapshot` and rewinds it; `rng.state` is saved
and restored with everything else, so a probed coin flip flips the same way
for real and a probed shuffle deals the same card.
`tests/unit/test_snapshot_audit.gd` pins that against a reflective
FINGERPRINT of every script variable of every scripted object reachable from
the game — definitions included, since `CardRegistry` is process-global —
plus the RNG, which has no script for the walk to find.

---

## 13. The AI and the DecisionAgent hooks

`DecisionAgent` is the engine's interface for MID-RESOLUTION choices — the
ones that cannot be supplied upfront with the targets. One agent per seat
(`MtgGame.agents`, replaceable with `MtgGame.set_agent`). Agents read state
freely and never mutate; the engine acts on what they return.

Each hook is TWO methods: `choose_*` is the FUNNEL (it builds a
[PlayerChoice], files it on the game, and asks the agent), `answer_*` is the
EXTENSION POINT subclasses override. Overriding a `choose_*` takes the
question off the record and is a bug.

| Hook | Asked for | Base default | Call sites (2026-08-31) |
|---|---|---|---|
| `choose_discard(game, pid, count)` | Cleanup and forced discards | Highest mana value first | 8 — `MtgGame._cleanup_step` + 7 in cards |
| `choose_card(game, pid, candidates, prompt, optional)` | Library searches, sacrifice-a-`<filter>` costs, enters-as-copy picks | The first candidate (callers pre-sort); `optional` marks where declining is legal | 28 — `pick_from_library`, `search_library`, `_apply_enters_as_copy`, the sacrifice-cost paths + cards |
| `choose_yes_no(game, pid, prompt, hint)` | Optional costs and "unless you pay" ransoms | Follows the caller's computed hint | 68, all in cards |
| `choose_color(game, pid, prompt, hint)` | "A colour of your choice"; a mana source's "what kind of mana?" | Follows the hint | 5 — 4 in cards + `MtgGame._ask_cost_color` (Fellwar Stone, via `ManaAbility.color_options`) |
| `choose_option(game, pid, options, prompt, hint)` | "Choose one of these labelled things", answered by INDEX — a number in a range (`choose_number` is sugar over it), an ability off a list, a card NAME | Follows the hint (clamped into range) | 8 — Shapeshifter, Wood Elemental, Nameless Race, Tetravus ×2, Power Leak, Petra Sphinx |

**THE PLAYER IS ASKED (docs/duel-todo.md §1.3).** ALL of them, by two
mechanisms. 103 of the 109 asks happen inside a stack resolution, and the
engine PRE-FLIGHTS every
resolution for a seat that says `wants_to_be_asked()`: it runs the item once
over a [GameSnapshot] rewind point purely to learn what it asks
(`MtgGame.is_probing()` silences the log, the events, the state signals and
the ledger for the duration), rewinds, and then HOLDS the resolution open on
`MtgGame.awaiting_choice` until `answer_choice(value)` — the same contract as
`awaiting_attackers` / `awaiting_discard` / `awaiting_damage_assignment`. The
answer is parked on the seat's agent (`accept_answer`) and the item resolves
for real. Off by default (`MtgGame.interactive_choices`), so the AI and every
headless test are unchanged.

**WHAT A PROBE CANNOT REACH IS 4, NOT 6** (re-measured 2026-09-01). Two of
the six rows §1.3 listed were never fall-throughs: the enters-as-copy pick
(Clone, Copy Artifact, Vesuvan Doppelganger) IS inside a resolution, because a
Clone reaches the battlefield by RESOLVING, so the hold works and the player
picks the body; and the cleanup discard has held the turn open on
`awaiting_discard` since §1.1 for any seat that says
`wants_to_choose_discard()`. Both are pinned in
`tests/unit/test_cost_choice_contract.gd`.

**AND THOSE FOUR ARE NOW CLOSED TOO — WITHOUT A SNAPSHOT (2026-09-01).** They
are all COST PAYMENTS made outside the stack: `tap_for_mana`'s sacrifice pick
and Fellwar Stone's colour (a mana ability never uses the stack, CR 605.3a),
and the sacrifice picks in `cast_spell` and `activate_ability` (paid at
cast/activation time, before the spell or ability is on the stack, CR
601.2h). There is no stack item to probe — and none is needed, because every
one of them asks AFTER every refusal check (see §3), at a point where nothing
has been mutated yet. So the hold is a PENDING-ACTION RECORD, not a rewind
point:

| | The PRE-FLIGHT (a resolution) | The COST HOLD (a payment) |
|---|---|---|
| What is re-run | the stack item, over a `GameSnapshot` | the whole ACTION (`cast_spell` / `activate_ability` / `tap_for_mana`) |
| What is saved | every mutable object reachable from the game | `MtgGame._pending_action` — which action, which seat, which card, which targets, which X |
| Why that is enough | the probe mutated, so it must be undone | nothing was mutated, so there is nothing to undo |
| Where the question is built | by the probe, inside the card | by the engine, at the payment site |

Both raise the same `MtgGame.awaiting_choice` and are answered by the same
`answer_choice(value)`, which parks the answer on the seat's agent and then
either resolves the item or re-issues the action. `PlayerChoice.is_cost` is
what tells them apart — for the front end (a cost question wears different
1997 words) and for `answer_choice` itself. Two counters,
`MtgGame._cost_answers` / `_cost_asked`, make a replayed action serve the
answers it already has and stop on the NEXT question, so an action with two
cost questions stops twice instead of looping. `tap_for_mana` skips
`_act_precheck` on purpose (CR 605.3a) and therefore carries its own
`awaiting_choice` refusal.

Fellwar Stone's colour moved with it. "Add one mana of any color that a land
an opponent controls could produce" used to ask from inside the card's
`ManaAbility.dynamic_color`, which runs after the source is already tapped —
and ran TWICE per activation, once for the mana trigger's colour and once
inside `produce_into_for`. The card now only takes the CENSUS
(`ManaAbility.color_options` returns the flags on offer) and `tap_for_mana`
does the asking, once, before anything is paid, and hands the answer to
`produce_into_for(..., forced_color)`.

Every card using `CardData.as_it_enters` is still outside all of this, for
the same reason as ever.

A seat is only ever HELD OPEN on a question it can actually be shown:
`DecisionAgent.can_answer(choice)` gates the pre-flight by
`PlayerChoice.Kind`. The BASE default is the four kinds every front end has
a `match` case for, so a front end that does not know a kind gets the
heuristic — ledgered, not silent — rather than a dialog with no buttons and
no Cancel. `HumanAgent` widens it to five: the duel overlay grew its
`OPTION` case on 2026-09-01, so Shapeshifter's number, Gabriel Angelfire's
ability and Petra Sphinx's card name are the player's again.

`AiPlayer extends DecisionAgent` drives a whole seat through the same public
API a human's clicks use:

| Piece | What it does | Engine |
|---|---|---|
| One action per call | Land drop → value-ranked cast → ability activation → pass; returns a short description for logs | `AiPlayer.act` |
| Soak driver | Alternates two AIs until the game ends; used by the test suite and the Deck Lab | `AiPlayer.play_out` |
| Casting | Ranks castable cards by value, plans the mana taps off the LIVE mana abilities, picks targets by intent (harmful → enemy's best, helpful → own best) | `_try_cast_best`, `_plan_taps`, `_mana_sources`, `_choose_targets`, `_pick_for_spec`, `_extra_targets` |
| X spells | Pays the biggest X it can afford | `_max_affordable_x` |
| Modal spells | Uses the card's own `ai_mode_picker`, else mode 0 | `_pick_mode`, `CardData.with_ai_mode` |
| Attacks | Per-attacker favourable-trade analysis with a lethal-push override, and it DOES declare attack bands | `_declare_attacks`, `_attack_is_reasonable` |
| Blocks | Kill-and-survive, value trades, chump blocks under the profile's life threshold, two-creature gangs | `_declare_blocks`, `_best_block_for` |
| Instant-speed responses | Counters threats past a per-profile bar, Fogs real damage once blocks are known, aims removal down the attacker list, casts pump tricks on both sides of a block; never responds over its own stack object | `_respond_action`, `_try_counter`, `_defensive_combat_response`, `_offensive_combat_response` |
| Difficulty | Mistake injection, aggression tilt, chump threshold, whether it holds instants at all, counter threshold | `AiProfile` presets `apprentice()` / `magician()` / `sorcerer()` / `wizard()` |
| Evaluation | Permanent and card values, keyword worth, weighted position score | `Evaluator.permanent_value` / `card_value` / `position_score` |

The AI is greedy-heuristic with no lookahead; game cloning plus minimax plugs
in behind the same `act()` surface (ROADMAP M4 phase 3). Note that
`ai_player.gd`'s own header still lists "does not hold instants, does not
declare bands" as limits — that comment predates the phase-2 work and the code
below it does both.

---

## 14. What the engine deliberately does not do

Nothing in this list is half-built; each is an explicit gap. Engine-wide items
are tracked in `docs/ROADMAP.md`, card-visible consequences in
`docs/simplified-cards.md`.

- **Mana burn.** Pools empty silently at each step boundary; no life is lost.
- **Damage on the stack.** Damage is dealt immediately by `deal_damage`; there
  is no damage-on-the-stack era rule and no way to respond to it.
- **A general replacement-effect system.** The replacements that exist are
  hardcoded shapes: enters-as-copy, dies-to-hand, exile-instead-of-dying,
  life-gain-becomes-draw, reverse-damage, the two damage redirections. A real
  "if you would draw" hook is what the remaining draw-step cards wait on
  (ROADMAP).
- **A blocker declared against several attackers by a HUMAN.** The engine
  takes the block (`CombatState.extra_blocks`, CR 509.1b — Two-Headed Giant
  of Foriys, Blaze of Glory), but `duel_screen.gd`'s block picker still
  points one blocker at one attacker, so only an AI seat can make it
  (ROADMAP).
- **The full CR 613 layer system.** No cross-layer timestamps, no dependency
  analysis beyond the two-round type pass, no indefinite duration for base-P/T
  sets. Contained inside `ContinuousEffects.recalculate`.
- ~~**Targeted triggers.**~~ **DONE 2026-09-02** — `TriggeredAbility.targeting`
  declares one target spec, chosen as the trigger goes on the stack
  (CR 603.3d, `MtgGame._arm_trigger_targets`); a trigger with no legal
  target never goes on, an illegal one fizzles. `modal` announces the mode
  first (CR 603.3c). The one spec is shared by every mode.
- **Await-based human prompts.** Every mid-resolution choice is synchronous;
  a human seat gets the `DecisionAgent` heuristic for anything the UI could
  not pre-select.
- **Planeswalkers, sideboarding, double strike, hybrid/Phyrexian/snow mana,
  more than two players.** None of these exist in the 1997 pool or the engine.
- **Priority during cleanup**, and a second cleanup step when something
  happened during the first.
- **Chaos Orb, Falling Star, Shahrazad and Word of Command** are excluded from
  the pool outright (same exclusions as s30), not simplified.
