# Code Map

Every file in the project and what lives in it. Keep this current: **any PR
that adds/moves a file updates this map** (the review checklist enforces it).

Conventions: engine classes use `class_name` (globally visible, no imports
needed); card files have NO class_name (they register by name instead);
`snake_case.gd` filenames throughout; tabs for indentation (Godot default).

```
shandalar/
├── project.godot            Godot 4.7 project config; main scene = game/main.tscn
│                              (and nothing ahead of it — the boot splash is
│                              held by the ENGINE, boot_splash/
│                              minimum_display_time=1000 ms since 2026-09-04,
│                              not by a scene)
├── export_presets.cfg       Export presets. "Linux 64" (x86_64, GL
│                              compatibility): the release template is named
│                              by PATH because this machine's templates are
│                              4.7.stable and the pinned engine is 4.7.2.
│                              Ships scripts, cards/data/ and every .deck;
│                              ships NO art (see build_release.sh)
├── run_tests.sh             Headless test runner (uses ../tools/godot, GUT CLI);
│                              times out (SUITE_TIMEOUT), fails on any ERROR:
│                              line, a risky test or a leak — header says why
├── .gitignore               Ignores .godot/ cache, *.import, assets/cardart/,
│                              packs/ (build_card_packs.py --out packs)
│
├── engine/                  ← THE RULES ENGINE (pure, headless, no Node)
│   ├── core/                Data model & vocabulary
│   │   ├── mtg.gd           class Mtg — ALL shared enums/constants:
│   │   │                      ManaColor (bitmask; "Color" is reserved by
│   │   │                      Godot), CardType, Supertype (BASIC/
│   │   │                      LEGENDARY/WORLD), Zone, Step +
│   │   │                      STEP_ORDER + PRIORITY_STEPS, Keyword,
│   │   │                      EventType (+ per-event data keys; incl.
│   │   │                      BECAME_TAPPED, BLOCKED, BLOCKERS_DECLARED,
│   │   │                      END_OF_COMBAT, ABILITY_ACTIVATED),
│   │   │                      StackKind,
│   │   │                      step_name()/is_main_step()/is_combat_step()
│   │   ├── mana_cost.gd     class ManaCost — parse "{2}{W}{W}"; mana_value(),
│   │   │                      color_mask(), has_x
│   │   ├── mana_pool.gd     class ManaPool — floating mana; can_pay()/pay()
│   │   │                      (documented greedy generic-payment algorithm),
│   │   │                      clear() at step ends; RESTRICTED mana in a
│   │   │                      second keyed pool ("spend only to cast
│   │   │                      artifact spells", CR 106.6), colour
│   │   │                      substitutions and an any-type wildcard
│   │   ├── card_data.gd     class CardData — immutable printed card + its
│   │   │                      behavior lists; fluent builder API used by
│   │   │                      card files (.pt/.spell/.activated/.triggered/
│   │   │                      .static_ability/.mana/.enchants/.oracle).
│   │   │                      set_code and artist are PRINTING metadata,
│   │   │                      filled in by the registry loader rather than
│   │   │                      by build() — no rule reads either.
│   │   │                      Rules flags: protection_from, landwalk,
│   │   │                      cant_be_blocked_by, enters_tapped, rampage
│   │   │                      (CR 702.23), cant_be_aura_target,
│   │   │                      attack_needs_defender_land,
│   │   │                      sacrifice_if_no_land_type,
│   │   │                      sacrifice_if_you_control_subtype,
│   │   │                      .sacrifices_when() (the general "when
│   │   │                      <condition>, sacrifice this" — Jihad) and
│   │   │                      .castable_only_when() ("Cast this spell
│   │   │                      only ..." — Reset, Berserk, Teleport) and
│   │   │                      .as_it_enters() (the general "As this
│   │   │                      permanent enters, ..." REPLACEMENT, CR
│   │   │                      614.1c — Shapeshifter, Wood Elemental,
│   │   │                      Nameless Race) and .as_it_leaves() (its
│   │   │                      twin: the IMMEDIATE leaves-the-battlefield
│   │   │                      hook, run before the world is recomputed —
│   │   │                      Titania's Song's until-EOT rider,
│   │   │                      Oubliette's phase-in). ARRIVAL BANS:
│   │   │                      .bans_permanents_entering() radiates
│   │   │                      "lands can't enter the battlefield"
│   │   │                      (Worms of the Earth) and .enters_only_if()
│   │   │                      is a card's veto on its own arrival
│   │   │                      (Frankenstein's Monster) — both read by
│   │   │                      MtgGame.entry_refused. .with_dies_to_hand(
│   │   │                      locked_until_next_turn) — the death
│   │   │                      replacement, and with `true` its rider
│   │   │                      (dies_to_hand_locks: Firestorm Phoenix's
│   │   │                      "revealed in hand and can't be played
│   │   │                      until your next turn").
│   │   │                      .with_skip_turn_to_untap() — "if you would
│   │   │                      begin your turn while this is tapped, you
│   │   │                      may skip that turn instead" (Time Vault),
│   │   │                      read by MtgGame._begin_turn
│   │   │                      .with_colored_x(color) / x_color /
│   │   │                      cost_for(x) — a SPELL whose X must be paid
│   │   │                      in one colour ("Spend only black mana on
│   │   │                      X" — Drain Life); cast_spell pays
│   │   │                      cost_for(x) with x_paid = 0, mirroring
│   │   │                      ActivatedAbility.with_colored_x
│   │   ├── card_instance.gd class CardInstance — one copy in one game: zone,
│   │   │                      tapped/damage/sickness/attachments, and CURRENT
│   │   │                      characteristics cur_power/cur_toughness/
│   │   │                      cur_keywords (always read these, never
│   │   │                      printed); cur_damage_immunity (source-
│   │   │                      filtered prevention), cur_block_restrictions,
│   │   │                      cur_bands_with + grant_bands_with(desc,
│   │   │                      filter) ("bands with other [quality]", CR
│   │   │                      702.22c's second form — NOT the banding
│   │   │                      keyword; the Legends banding lands grant it
│   │   │                      to their colour's legends and Master of the
│   │   │                      Hunt's Wolves grant it to themselves;
│   │   │                      losing banding clears it, CR 702.22b),
│   │   │                      cur_mana_abilities / cur_activated_abilities
│   │   │                      / cur_triggered_abilities (LIVE ability
│   │   │                      lists — Evil Presence retunes a land, Zombie
│   │   │                      Master grants an activated ability, Energy
│   │   │                      Flux grants every artifact its own upkeep
│   │   │                      trigger; dispatch_event reads the live
│   │   │                      triggered list),
│   │   │                      cur_rampage (LIVE rampage N — printed,
│   │   │                      granted by a static, or floating until EOT),
│   │   │                      memory (card-local choices), is_token,
│   │   │                      controlled_via (control leashes),
│   │   │                      skip_untaps, blocked_this_turn,
│   │   │                      damaged_players_this_turn,
│   │   │                      regeneration_banned_this_turn, cur_shroud,
│   │   │                      cur_must_be_blocked,
│   │   │                      cur_attacks_as_if_hasty (Instill Energy —
│   │   │                      attacking only, never {T} costs),
│   │   │                      cur_abilities_silenced (Titania's Song and
│   │   │                      every face-down permanent, CR 708.2),
│   │   │                      cur_target_bans (source-filtered "can't be
│   │   │                      the target of ..." — Artifact Ward, whose
│   │   │                      filter tells an artifact's ABILITY from an
│   │   │                      artifact SPELL by where the source is),
│   │   │                      HAND-SCOPED state hand_lock_turn /
│   │   │                      revealed_in_hand (Firestorm Phoenix's
│   │   │                      rider; the `zone` setter wipes both as the
│   │   │                      card leaves the hand, CR 400.7),
│   │   │                      lost_enchant + is_aura() (an Aura that came
│   │   │                      back "as a non-Aura enchantment" —
│   │   │                      Takklemaggot; the orphan SBA asks the
│   │   │                      instance, not the printed card),
│   │   │                      could_attack_this_turn (the census
│   │   │                      declare_attackers takes of the active
│   │   │                      player's creatures, attack or no attack —
│   │   │                      Season of the Witch's "couldn't attack"),
│   │   │                      cur_immune_to_wall_only (Wall of Shadows),
│   │   │                      cur_cant_change_control (Guardian Beast),
│   │   │                      damage_eats_counters (Rock Hydra's heads),
│   │   │                      damage_all_redirect_to (Reverberation),
│   │   │                      damage_redirect_to / damage_redirects /
│   │   │                      damage_redirect_sources (Jade Monolith's
│   │   │                      one-shots, each bound to the source it
│   │   │                      named; empty = any source),
│   │   │                      damage_point_redirect_to /
│   │   │                      damage_point_redirects (Personal
│   │   │                      Incarnation's METERED points — one point of
│   │   │                      an event each, the rest lands),
│   │   │                      cur_attack_costs (CR 508.1g — Brainwash,
│   │   │                      Leviathan), damage_unpreventable_this_turn
│   │   │                      (Whippoorwill), destruction_shields
│   │   │                      (Pyramids' non-regeneration replacement),
│   │   │                      last_power/last_toughness/last_types/
│   │   │                      last_colors/last_subtypes (CR 608.2h last
│   │   │                      known information, snapshotted by the zone
│   │   │                      change for Creature Bond, Soul Net,
│   │   │                      Necropolis of Azar & co.);
│   │   │                      restore_printed_identity() ends a copy AFTER
│   │   │                      its own dies-trigger is heard (CR 707.2)
│   │   ├── target.gd        class TargetSpec — what may be targeted (kind +
│   │   │                      filter Callable + card-English description);
│   │   │                      Kind.ABILITY names an ACTIVATED ability on
│   │   │                      the stack; with_player_filter narrows a
│   │   │                      PLAYER target ("who attacked this turn");
│   │   │                      is_legal() used at cast AND at resolution —
│   │   │                      and it is refusal_reason() asked for a yes
│   │   │                      or no: WHY (@PROMPT_ILLEGALTARGETWHY's 29
│   │   │                      words) + .because() name what a filtered
│   │   │                      refusal reports, and one set of checks
│   │   │                      serves both (duel-todo §6.10);
│   │   │                      TargetSpec.opponent() for "target opponent";
│   │   │                      .with_game_filter()/.with_source_filter()/
│   │   │                      .with_damage_filter() (a predicate on a
│   │   │                      DamagePacket — the Circles' "a green
│   │   │                      source"; Kind.DAMAGE is the 1997 damage
│   │   │                      marker, §6.8)/
│   │   │                      .only_walls() (a spec that can only ever name
│   │   │                      a Wall — the Glyph cycle, so Wall of Shadows
│   │   │                      can duck it); .legal_targets() — the
│   │   │                      legal-target census; can_attach_to() — the
│   │   │                      CR 704.5m question ("could this Aura still
│   │   │                      enchant that?"), which deliberately ignores
│   │   │                      every targeting restriction;
│   │   │                      .at_random(count_too) — "random target
│   │   │                      creature(s)": a target the GAME rolls on
│   │   │                      MtgGame.rng as the spell/ability is put on
│   │   │                      the stack (Faerie Dragon, Goblin Polka
│   │   │                      Band, Orcish Catapult — the count rolled
│   │   │                      too); is_supplied_by_caster() = neither
│   │   │                      opponent-chosen nor rolled
│   │   ├── target_ref.gd    class TargetRef — a chosen target as a value
│   │   │                      object (player id, instance id, or a
│   │   │                      DamagePacket id — never a pointer);
│   │   │                      .amount = its share of a DIVIDED effect's
│   │   │                      total; same_object() is the ONE place the
│   │   │                      three-arm union is compared for identity
│   │   ├── damage_packet.gd class DamagePacket — ONE damage event as an
│   │   │                      object (source, victim, amount, prevented,
│   │   │                      redirected, is_combat, from_redirect, id):
│   │   │                      what a 1997 prevention effect targets ("a
│   │   │                      damage marker", Duel.hlp Using Land).
│   │   │                      remaining()/prevent()/divert() (the metered
│   │   │                      split, Personal Incarnation);
│   │   │                      matches()/absorb() are the Manabarbs merge
│   │   │                      rule — same source + same victim is ONE
│   │   │                      packet (duel-todo §6.8)
│   │   ├── target_plan.gd   class TargetPlan — groups a flat TargetRef list
│   │   │                      per targeting effect (variable counts, divided
│   │   │                      amounts) and validates legality + CR 601.2c/d;
│   │   │                      random_groups/random_spans/random_totals
│   │   │                      record the slots a rolled spec leaves empty
│   │   │                      for MtgGame._fill_random_targets
│   │   └── game_event.gd    class GameEvent — type + data payload; currency
│   │                          of the trigger system and the UI event signal
│   │
│   ├── effects/             One-shot effects (what spells DO on resolution)
│   │   ├── effect_base.gd   class EffectBase — contract: resolve(game,
│   │   │                      source, controller, target, x_value) and
│   │   │                      resolve_multi(...targets: Array...) for
│   │   │                      variable-count effects; one_or_more(),
│   │   │                      x_targets(), divided_among(),
│   │   │                      optional_target() (a target that may be
│   │   │                      declined, the effect still resolving);
│   │   │                      is_damage_prevention / is_regeneration —
│   │   │                      the DATA FLAGS that say what may be used
│   │   │                      inside the 1997 damage-prevention and
│   │   │                      regeneration windows (§6.8)
│   │   ├── damage_effect.gd class DamageEffect — N or X damage; fluent
│   │   │                      .any_target()/.target_creature()/.x_damage()
│   │   ├── draw_effect.gd   class DrawEffect — draw N or X; .target_player()
│   │   ├── destroy_effect.gd class DestroyEffect — destroy target;
│   │   │                      can_regenerate honored by MtgGame.destroy
│   │   ├── pump_effect.gd   class PumpEffect — +P/+T (+keywords) until EOT;
│   │   │                      .self_buff() for firebreathing-style pumps
│   │   ├── destroy_all_effect.gd class DestroyAllEffect — Wrath of God
│   │   ├── damage_all_effect.gd  class DamageAllEffect — Earthquake ("each")
│   │   ├── grant_landwalk_effect.gd class GrantLandwalkEffect — "gains
│   │   │                      <type>walk until end of turn" (Part Water)
│   │   ├── change_color_effect.gd class ChangeColorEffect — "becomes
│   │   │                      <colour>" indefinitely (the Laces) or until
│   │   │                      end of turn (the Legends colour cycle)
│   │   ├── random_effect_table.gd class RandomEffectTable — Whimsy's
│   │   │                      grab-bag: the 1997 list of 17 fast effects
│   │   │                      (`@WHIMSY_MESSAGES` order, each announced
│   │   │                      with its 1997 line, fizzling on the record
│   │   │                      when it finds no target)
│   │   ├── random_creature_effect_table.gd class RandomCreatureEffectTable
│   │   │                      — Faerie Dragon's grab-bag: the 1997 list of
│   │   │                      20 creature effects (`@FAERIEDRAGON_MESSAGES`
│   │   │                      order, from the decompiled 0x4735C0), played
│   │   │                      on the creature the ability rolled
│   │   ├── gain_life_effect.gd   class GainLifeEffect — life gain/loss, X
│   │   ├── add_mana_effect.gd    class AddManaEffect — Dark Ritual
│   │   ├── counter_effect.gd     class CounterEffect — Counterspell
│   │   ├── counter_ability_effect.gd class CounterAbilityEffect —
│   │   │                      "counter target activated ability", with an
│   │   │                      optional "unless its controller pays" ransom
│   │   │                      (Rust, Ayesha Tanaka)
│   │   ├── return_to_hand_effect.gd class ReturnToHandEffect — Unsummon
│   │   ├── regenerate_effect.gd  class RegenerateEffect — shield builder;
│   │   │                      .target_creature() for Death Ward
│   │   ├── tap_effect.gd / untap_effect.gd — Icy Manipulator, Ley Druid
│   │   ├── prevent_damage_shield_effect.gd — Circles of Protection;
│   │   │                      .from_sources() keys a shield on a source
│   │   │                      PREDICATE (CoP: Artifacts). TWO SHAPES: an
│   │   │                      OPTIONAL Kind.DAMAGE target names one
│   │   │                      waiting packet (the 1997 form, §6.8),
│   │   │                      and with no window open no target is taken
│   │   │                      and the controller NAMES ONE SOURCE of the
│   │   │                      colour (choose_card over
│   │   │                      MtgGame.damage_sources, the modern "of your
│   │   │                      choice") — an id-bound one-shot in
│   │   │                      MtgPlayer.prevention_shield_filters; with
│   │   │                      no source in sight nothing is shielded
│   │   ├── prevent_damage_effect.gd — amount-based prevention pools
│   │   │                      (Healing Salve, Samite Healer); .x_amount()
│   │   │                      and .to_controller() variants (wave 8);
│   │   │                      .with_paid_rider() grants Guardian Angel's
│   │   │                      "pay {1} any time for 1 more" on the seat
│   │   │                      (MtgGame.grant_paid_prevention)
│   │   ├── animate_self_effect.gd — until-EOT type change ("becomes a
│   │   │                      2/2 creature") — Mishra's Factory
│   │   ├── exile_effect.gd       — Ashes to Ashes (no regen, no dies-trigger)
│   │   ├── extra_turn_effect.gd  — Time Walk
│   │   ├── return_from_graveyard_effect.gd — Raise Dead / Regrowth
│   │   ├── mill_effect.gd        — Millstone
│   │   ├── search_library_effect.gd — Demonic Tutor (agent-choosing)
│   │   ├── mass_pump_effect.gd   class MassPumpEffect — "all/your creatures
│   │   │                      get +P/+T until EOT" (Hell Swarm, Shield Wall,
│   │   │                      Marsh Gas, Bone Flute); .yours_only(),
│   │   │                      .with_filter(), .excluding_source()
│   │   │                      ("OTHER Orc creatures" — Orc General)
│   │   ├── prevent_combat_damage_effect.gd class PreventCombatDamageEffect
│   │   │                      — the Fog effect (Fog, Holy Day, Darkness,
│   │   │                      Angus Mackenzie) via
│   │   │                      MtgGame.combat_damage_prevented;
│   │   │                      .by_target_creature() for the one-creature
│   │   │                      version (Lady Evangela, Horn of Deafening)
│   │   ├── switch_pt_effect.gd   class SwitchPowerToughnessEffect —
│   │   │                      Transmutation; registers a CR 613.4e switch
│   │   │                      in ContinuousEffects (wave 20)
│   │   ├── lose_ability_effect.gd class LoseAbilityEffect — "loses
│   │   │                      <keyword>/all landwalk/ONE landwalk type
│   │   │                      until end of turn" (Hammerheim, Urborg,
│   │   │                      Scarwood Hag, Wall of Wonder);
│   │   │                      .and_landwalk(), .and_landwalk_of(["swamp"])
│   │   │                      (ContinuousEffects.add_until_eot_loss's
│   │   │                      landwalk_types list), .to_source() (wave 21)
│   │   └── set_base_pt_effect.gd class SetBasePowerToughnessEffect —
│   │                          "has base power/toughness N until end of
│   │                          turn" in CR 613 layer 7b (Island of
│   │                          Wak-Wak, Singing Tree, Sorceress Queen)
│   │
│   ├── abilities/           Ability objects composed into CardData
│   │   ├── mana_ability.gd  class ManaAbility — {T}: add mana; STACKLESS by
│   │   │                      design (CR 605.3); produces list; .and_also();
│   │   │                      .with_mana_cost()/.with_sacrifice()/
│   │   │                      .without_tap()/.with_sacrifice_of()/
│   │   │                      .scaling_with_sacrifice() (Ashnod's Altar);
│   │   │                      .with_dynamic_color() COMPUTES a colour
│   │   │                      (Gem Bazaar) while .with_color_choice()
│   │   │                      supplies the CENSUS and lets tap_for_mana
│   │   │                      ASK for it (Fellwar Stone), and
│   │   │                      .with_any_number_of_counters(kind[, bonus])
│   │   │                      (any_number_counter_kind / bonus_per_counter)
│   │   │                      lets tap_for_mana ask HOW MANY to spend for
│   │   │                      +bonus each (the five Mana Batteries; a
│   │   │                      separate field from counter_cost_kind
│   │   │                      because zero is legal and the AI's planner
│   │   │                      skips fixed counter costs) — the only
│   │   │                      places a mana ability's question can hold
│   │   │                      the duel open (§1.3, the COST hold)
│   │   ├── activated_ability.gd class ActivatedAbility — mana/tap cost +
│   │   │                      effects + text; uses the stack; sickness rules
│   │   │                      enforced by MtgGame. Riders:
│   │   │                      .with_sacrifice_cost()/.with_life_cost()/
│   │   │                      .with_sacrifice_of()/.per_turn()/
│   │   │                      .combat_only()/.during_step()/
│   │   │                      .your_turn_only()/.opponents_turn_only()/
│   │   │                      .with_counter_cost() ("Remove N <kind>
│   │   │                      counters" as a real cost — Triskelion,
│   │   │                      Osai Vultures, Scavenging Ghoul),
│   │   │                      .with_discard_cost() (the payer picks —
│   │   │                      Land's Edge) and
│   │   │                      .with_discard_last_drawn_cost() ("Discard
│   │   │                      the last card you drew this turn" — Jandor's
│   │   │                      Ring: the last entry of drawn_this_turn,
│   │   │                      payable only while it is still in hand)
│   │   ├── triggered_ability.gd class TriggeredAbility — event_type +
│   │   │                      optional condition + on_resolve(game, source,
│   │   │                      event) Callable; APNAP stacking in MtgGame
│   │   └── static_ability.gd class StaticAbility — apply(game, source)
│   │                          Callable run every recalculation pass;
│   │                          .changing_types() marks a CR 613 LAYER-4
│   │                          type changer (Blood Moon, Evil Presence,
│   │                          Kormus Bell, Titania's Song) and
│   │                          .setting_base_pt() a layer-7a/7b P/T SETTER;
│   │                          ContinuousEffects runs them in that order,
│   │                          then everything else (the 7c anthems).
│   │                          .granting_triggers(event_types) declares
│   │                          the triggered abilities a static hands to
│   │                          other permanents (Energy Flux), so the
│   │                          dispatcher's early-out index counts them
│   │
│   ├── mana_planner.gd      class ManaPlanner (static only) — THE MANA
│   │                          PLANNER: "which sources do I tap to pay for
│   │                          this?", asked by the AI seat AND by the
│   │                          human's 1997 auto-cast. sources() /
│   │                          plan_from() / plan() / plan_and_pay() /
│   │                          run_plan() / max_affordable_x(), all taking
│   │                          a pid. Moved out of AiPlayer 2026-09-03 so
│   │                          one planner serves both seats; AiPlayer's
│   │                          _mana_sources / _plan_taps* are now thin
│   │                          seat-bound wrappers. Knows restricted mana
│   │                          (Mishra's Workshop keys), floating mana as
│   │                          a zero-cost source, live mana abilities
│   │                          only, and the `Don't auto tap this card`
│   │                          exclusion set. Carries the decompilation
│   │                          evidence that 1997 auto-tapped at all
│   ├── mtg_game.gd          class MtgGame — THE ORCHESTRATOR. Public API:
│   │                          setup/start, play_land, tap_for_mana,
│   │                          cast_spell, activate_ability, pass_priority,
│   │                          declare_attackers/blockers (declare_attackers
│   │                          also takes the could_attack_this_turn census
│   │                          of every creature the active player
│   │                          controls, CR 508.1a).
│   │                          all_battlefield() is CACHED (rebuilt only on
│   │                          a battlefield change, always into a NEW
│   │                          array so iterators keep a stable snapshot);
│   │                          the same rebuild derives the trigger-type
│   │                          index dispatch_event early-outs on (and
│   │                          has_trigger_listener() exposes, so a hot
│   │                          path can skip BUILDING an unheard event),
│   │                          battlefield_with_statics() for the
│   │                          continuous pipeline, the cost-modifier list
│   │                          for the surcharges, and the SBA watch list.
│   │                          Mutation helpers:
│   │                          deal_damage (is_combat flag; returns the
│   │                          amount actually dealt; optional
│   │                          after: Callable(dealt) for a caller that
│   │                          needs the answer after a prevention window
│   │                          has moved it into the future — Drain Life).
│   │                          Two halves since §6.8: _plan_damage builds
│   │                          the DamagePacket, _land_damage runs it
│   │                          through the eight prevention gates,
│   │                          draw_cards, destroy, adjust_life,
│   │                          sacrifice_permanent, exile_from_graveyard,
│   │                          doom_at_end_of_combat (basilisk gazes),
│   │                          top_of_library_to_hand (put, NOT draw —
│   │                          CR 121.8, Petra Sphinx),
│   │                          remove_keyword_permanently /
│   │                          grant_keyword_permanently (durationless
│   │                          keyword losses and grants — Elder Land
│   │                          Wurm, Cocoon), move_aura (re-attach an
│   │                          Aura with no zone change, CR 701.3 —
│   │                          Kudzu), put_from_hand_into_play (put a
│   │                          card onto the battlefield without casting
│   │                          it — Eureka, Gaea's Touch). Triggered
│   │                          payments: try_pay/can_afford_cost (pool
│   │                          first, then auto-tapped lands — charms,
│   │                          upkeep rents; limits in ROADMAP).
│   │                          Per-turn bookkeeping other cards read:
│   │                          creatures_died_this_turn,
│   │                          spells_cast_this_turn (Ichneumon Druid);
│   │                          per-instance damaged_players_this_turn
│   │                          (Whirling Dervish). Also: create_token,
│   │                          schedule_end_step_token, flip_coin (all
│   │                          RNG through game.rng), remove_from_combat,
│   │                          gain_control_leashed, doom_at_next_end_step,
│   │                          shuffle_graveyard_into_library,
│   │                          shuffle_library / reorder_top_of_library
│   │                          (journaled; Natural Selection's DONE and
│   │                          its order), remove_counters (the journaled
│   │                          twin of add_counters). TAPPED_FOR_MANA
│   │                          carries {instance, controller, color,
│   │                          colors} — every type the tap made, for
│   │                          Mana Flare's "any type that land produced".
│   │                          _ask_cost_option is the OPTION twin of
│   │                          _ask_cost_color for the cost hold.
│   │                          DELAYED TRIGGERS (CR
│   │                          603.7): delayed_triggers is a queue of
│   │                          entries {id, trigger, controller, source,
│   │                          repeats, memory, desc[, settle_cost,
│   │                          settle_by]} filed by
│   │                          schedule_delayed_trigger; dispatch_event
│   │                          fires them per seat, APNAP, after that
│   │                          seat's battlefield triggers, as TRIGGER
│   │                          items that outlive their source (once-only
│   │                          entries leave the queue as they stack,
│   │                          603.7c; repeating ones stay until
│   │                          retire_delayed_trigger); current_delayed()
│   │                          is the resolving effect's live entry;
│   │                          settle_delayed_trigger /
│   │                          settleable_delayed_triggers let the named
│   │                          player pay one off early (Nafs Asp).
│   │                          CAST TRIGGERS: cast_spell hands a spell
│   │                          whose printed triggers include SPELL_CAST
│   │                          to dispatch_event as also_listen, so "When
│   │                          you cast this spell" (Mana Vortex) is heard
│   │                          by the spell on the stack, with its
│   │                          controller's seat. Static
│   │                          fields statics rebuild each recalculation:
│   │                          nullified_landwalk, max_attackers/
│   │                          max_blockers, untap_caps,
│   │                          unlimited_land_plays.
│   │                          THE X A SPELL IS BEING CAST FOR (2026-09-05):
│   │                          casting_x(inst) is the ONE reader a
│   │                          targeting restriction that names its own X
│   │                          uses ("target artifact/spell with mana
│   │                          value X" — Detonate, Spell Blast). It
│   │                          answers with the X a planner has PROPOSED
│   │                          while trying one on and with the one
│   │                          cast_spell stamped otherwise, so the same
│   │                          filter gives the same answer at plan time,
│   │                          at announcement and at resolution;
│   │                          target_legal_at / legal_targets_at are the
│   │                          prospective twins of TargetSpec.is_legal /
│   │                          .legal_targets that scope that proposal
│   │                          (push/pop around one query, never
│   │                          observable outside it, so no undo record).
│   │                          cast_refusal(pid, inst, targets, x, mode)
│   │                          is cast_spell's whole validation half run
│   │                          as a DRY RUN — _cast_checks, which
│   │                          cast_spell itself calls, so the two cannot
│   │                          drift: zone/priority/timing, the mode, the
│   │                          damage window, the target plan at THIS X
│   │                          and the additional sacrifice, with nothing
│   │                          paid, nothing moved, no roll consumed and
│   │                          no question asked. "" means only the mana
│   │                          is left to find. The X stamp moved BELOW
│   │                          those checks, so a refused announcement now
│   │                          leaves memory as it was (CR 601.2h).
│   │                          THE PRE-FLIGHT (§1.3): with
│   │                          interactive_choices on, _resolve_top first
│   │                          runs _preflight — the item resolves once
│   │                          over a GameSnapshot (is_probing() true: log,
│   │                          events, state signals and the choice ledger
│   │                          all silenced) purely to find what it ASKS,
│   │                          then rewinds. An unanswered question goes on
│   │                          awaiting_choice and HOLDS the resolution,
│   │                          like awaiting_attackers/discard/damage,
│   │                          until answer_choice(value).
│   │                          Internals: stack resolution + fizzling
│   │                          (CR 608.2b/c), APNAP trigger dispatch, SBAs
│   │                          (CR 704, incl. the 1997 legend rule and the
│   │                          world rule 704.5k), turn/step machine,
│   │                          combat damage
│   │                          incl. trample, cleanup. Signals for UIs:
│   │                          event_occurred, log_appended, state_changed,
│   │                          game_ended. Actions return "" or a refusal.
│   │                          THE DAMAGE-PREVENTION WINDOW (§6.8, a
│   │                          RulesOptions fork, default OFF): packets
│   │                          queue in damage_pending instead of landing;
│   │                          awaiting_damage_prevention then
│   │                          awaiting_regeneration hold priority open
│   │                          with a RESTRICTED ALLOW (only
│   │                          EffectBase.is_damage_prevention, then only
│   │                          .is_regeneration); damage_prevention_request
│   │                          says which and what for;
│   │                          end_damage_prevention(pid) is the 1997 verb;
│   │                          find_packet(id) is find_instance's mirror.
│   │                          Opt-in per seat via
│   │                          DecisionAgent.wants_damage_prevention_window
│   │                          POISON: add_poison + the 10-counter loss
│   │                          PHASING: phase_out/phase_in (CR 702.25)
│   │                          FACE DOWN: turn_face_down/turn_face_up,
│   │                          put_from_hand_face_down, exile_top_of_library
│   │                          DRAW: draw_game + is_draw (CR 104.4)
│   │                          CONCEDE: concede (CR 104.3a, "at any time")
│   │                          COMBAT REACH-INS: set_block,
│   │                          gain_control_until_eot, camouflage_this_turn
│   │                          (+ _camouflage_block_map: the defender's
│   │                          piles, one turn-based OPTION question per
│   │                          creature through the cost hold, replayed as
│   │                          the "blockers" action; the deal on rng),
│   │                          no_attacks_this_turn
│   │                          LIBRARY/EXILE MOVES: pick_from_library,
│   │                          put_into_play, put_into_graveyard,
│   │                          return_from_exile_to_play/_to_hand/_to_graveyard,
│   │                          take_from_outside_the_game
│   │                          ARRIVALS: entry_refused(inst, controller)
│   │                          answers "why may this not enter the
│   │                          battlefield" — a radiated ban
│   │                          (CardData.enters_ban_rule) or the card's
│   │                          own veto (CardData.entry_condition), both
│   │                          CR 614.1c-shaped. _put_on_battlefield(inst,
│   │                          controller, host) — an AURA enters
│   │                          ATTACHED (CR 303.4a): the host is bound
│   │                          before the first recalculation, as_enters
│   │                          and the ENTERS_BATTLEFIELD event, so an
│   │                          Aura's own arrival trigger sees it
│   │                          (Earthbind's intervening if) —
│   │                          returns bool and _arrival_refused puts the
│   │                          object back where it came from (library +
│   │                          shuffle, hand, graveyard, exile; a
│   │                          permanent spell to its owner's graveyard;
│   │                          a token ceases to exist, CR 111.7).
│   │                          return_aura_unattached(aura, controller)
│   │                          puts an Aura card onto the battlefield "as
│   │                          a non-Aura enchantment" — attached to
│   │                          nothing, CardInstance.lost_enchant set, so
│   │                          the orphan SBA (CR 704.5m) never sweeps
│   │                          it (Takklemaggot's second clause)
│   │                          DEPARTURES: _run_leave_hook runs
│   │                          CardData.as_leaves at the INSTANT a
│   │                          permanent leaves — all four exits
│   │                          (graveyard, exile, hand, ante), after the
│   │                          leave-triggers are stacked and
│   │                          forget_instance has run, before
│   │                          recalculate() — with the parting memory
│   │                          snapshot. The only moment at which "this
│   │                          effect continues until end of turn" can
│   │                          still see what the effect was doing
│   │                          TEXT CHANGES: change_text (CR 613 layer 3)
│   │                          MANA: mana_usage_keys (which restricted mana
│   │                          a given spell may spend)
│   │                          DELAYED: schedule_end_of_combat_action,
│   │                          watch_damage_for_life (the Glyph cycle)
│   │                          COPYING: become_copy (CR 707 — repoints
│   │                          CardInstance.data), copy_spell_on_stack
│   │                          (reads the original's item, or
│   │                          _resolving_item for a spell copying ITSELF
│   │                          as it resolves — Chain Lightning),
│   │                          offer_new_targets ("you may choose new
│   │                          targets for the copy", CR 707.10c — one
│   │                          ordered CARD/OPTION question per slot,
│   │                          hint: a preferred player's face, else the
│   │                          old target; Fork, Chain Lightning),
│   │                          find_stack_item, _apply_enters_as_copy
│   │                          (the enters-as-a-copy replacement)
│   │                          "A SOURCE OF YOUR CHOICE" (CR 609.7):
│   │                          damage_sources (every permanent and every
│   │                          spell on the stack, filtered) and
│   │                          rank_damage_sources (a spell/ability on
│   │                          the stack aimed at the victim first, then
│   │                          the creature it is fighting, then the
│   │                          other side's creatures by power) — the
│   │                          Circles, Reverse Damage, Jade Monolith,
│   │                          Nova Pentacle all name ONE source
│   │                          DRAW REPLACEMENTS (CR 614): draw_cards runs
│   │                          every draw past _replace_draw, which applies
│   │                          the ONE-SHOTs registered by
│   │                          replace_next_draw (Aladdin's Lamp; cleared at
│   │                          cleanup) and then the STATIC ones indexed off
│   │                          CardData.draw_replacement (Island Sanctuary,
│   │                          Chains of Mephistopheles). A re-entry guard
│   │                          keeps a replacement out of its own jaws
│   │                          (CR 614.5). _draw_step_skipped is the same
│   │                          idea for the STEP (CardData.draw_step_
│   │                          replacement — Fasting). Both scans read
│   │                          battlefield-index lists, so a duel with no
│   │                          replacement pays one is_empty() per draw.
│   │                          Companions: put_from_hand_on_top_of_library
│   │                          (Sylvan Library) and put_on_bottom_of_library
│   │                          DISCARDS: discard_cards / discard_random /
│   │                          discard_hand take by_effect (default true;
│   │                          a COST discard and the cleanup step pass
│   │                          false) and route each card past
│   │                          _discard_to_library_instead — Library of
│   │                          Leng's "on top of your library instead", a
│   │                          per-card yes/no for the discarder; the card
│   │                          is still discarded (on_discarded fires).
│   │                          search_library(..., shuffle_after) lets a
│   │                          repeated search shuffle once at the end
│   │                          HAND LOCKS: _lock_in_hand stamps a card
│   │                          returned under "can't play it until your
│   │                          next turn" (Firestorm Phoenix),
│   │                          hand_lock_reason(inst) is the refusal
│   │                          cast_spell/play_land return, and
│   │                          _release_hand_locks lifts them in
│   │                          _begin_turn as the owner's next turn
│   │                          actually begins (a skipped turn never does).
│   │                          THE TURN'S BEGINNING: _begin_turn asks each
│   │                          tapped Time Vault's `@TIME_VAULT` question
│   │                          ("Play this turn." / "Skip this turn to
│   │                          untap.") through the turn-based hold
│   │                          before the untap step (CR 614.10); _skip_turn
│   │                          proceeds past a skipped turn whole (CR
│   │                          500.9 — no untap/upkeep/draw/cleanup, no
│   │                          Arboria roll-over) into _next_turn, the
│   │                          hand-over _end_turn shares (extra turns
│   │                          first, CR 500.7).
│   │                          REVEALED TOPS: revealed_top_card(pid) is
│   │                          the one read for a public library top
│   │                          (Field of Dreams; null when hidden or the
│   │                          library is empty); _announce_revealed_tops
│   │                          logs each new top from _emit_state, once
│   │                          (Land Tax → shuffle_library).
│   │                          ABILITIES ON THE STACK: every StackItem now
│   │                          carries an id, so an ACTIVATED ability is a
│   │                          targetable object (CR 113.3b) —
│   │                          find_stack_ability + counter_ability, with
│   │                          TargetSpec.Kind.ABILITY and TargetRef.ability
│   │                          naming it. retarget_spell rewrites one target
│   │                          slot of a spell already on the stack.
│   │                          DELAYED ACTIONS that outlive their source:
│   │                          schedule_end_step_action,
│   │                          schedule_next_main_phase_action, plus the
│   │                          floating watches watch_death and
│   │                          watch_damage_dealt (all per-turn, cleared at
│   │                          cleanup). damage_dealt_this_turn is the
│   │                          per-SOURCE damage total the old
│   │                          damaged_by_this_turn could not give.
│   │                          MANA: pay_life_for_mana (Channel's
│   │                          player-level source, gated on
│   │                          MtgPlayer.life_for_mana). PAID PREVENTION:
│   │                          grant_paid_prevention / paid_prevention_for
│   │                          / pay_for_prevention — Guardian Angel's
│   │                          "{1}: prevent 1 more" as a stackless seat
│   │                          action at priority (the 1997 prevention
│   │                          step included), dropped by the leave seam
│   │                          when its permanent goes (CR 400.7) and
│   │                          counted by _has_window_effect. METERED
│   │                          REDIRECT: add_point_redirect books "the
│   │                          next 1 damage ... is dealt to its owner
│   │                          instead" points on a creature (Personal
│   │                          Incarnation); _divert_damage_points splits
│   │                          that many off a landing packet into a new
│   │                          one aimed at the seat — landed now, or
│   │                          queued as Duel.hlp's "second prevention
│   │                          step" under the window — and
│   │                          _land_damage_rest (the creature branch's
│   │                          tail: the remaining gates + marking) takes
│   │                          the rest.
│   │                          CONTROL: change_control (one permanent) and
│   │                          exchange_control (CR 701.10 — a PAIR, all or
│   │                          nothing per 701.10c, swapped inside a
│   │                          begin_simultaneous bracket; Juxtapose,
│   │                          Gauntlets of Chaos, Power Struggle)
│   │                          SIBLING TARGET SLOTS: current_targets() —
│   │                          every target of the object being resolved,
│   │                          flat and in slot order, so a card whose two
│   │                          slots take DIFFERENT specs can read the other
│   │                          one (mage-go's EffectContext.Targets;
│   │                          Gauntlets of Chaos)
│   │                          LAYER INDEX: battlefield_with_type_statics()
│   │                          (CR 613 layer 4) beside battlefield_with_
│   │                          statics(); _recalculate_for_tap_change()
│   │                          skips the whole pipeline when no static is
│   │                          on the board (see docs/audit-2026-09.md)
│   │                          ANTE: stake_ante (the OPENING stake, §6.19
│   │                          — called between setup() and
│   │                          deal_opening_hands(), OPT-IN via
│   │                          DuelConfig.ante so start() and the Deck Lab
│   │                          keep their exact shuffle), ante_enabled,
│   │                          all_ante/move_to_ante/
│   │                          ante_top_of_library/remove_from_ante and
│   │                          change_owner — the permanent ownership
│   │                          transfer the 1997 ante rule (and
│   │                          Shandalar's card economy) runs on
│   ├── mtg_player.gd        class MtgPlayer — seat: life, library/hand/
│   │                          battlefield/graveyard/ante/phased_out/
│   │                          outside_the_game, ManaPool, poison,
│   │                          per-turn
│   │                          flags; prevention_shields (+ predicate
│   │                          shields — the Circles' id-bound one-shots),
│   │                          reverse_damage_sources (Reverse Damage's
│   │                          named sources), max_hand_size,
│   │                          discard_to_library_top (Library of Leng's
│   │                          second half), top_card_revealed (Field of
│   │                          Dreams), min_life_from_damage
│   │                          (Ali from Cairo), artifact_damage_redirect
│   │                          (Martyrs of Korlis), artifact_damage_this_turn,
│   │                          damage_replacements (the one-shot/all-turn
│   │                          "the next time a source of your choice would
│   │                          deal damage to you this turn" family — see
│   │                          the field's own header for the entry
│   │                          contract), may_take_creature_damage (Blood of
│   │                          the Martyr),
│   │                          drawn_this_turn (the CARDS, not a count —
│   │                          Sylvan Library) and draws_this_step (would-be
│   │                          draws, reset every step — Chains of
│   │                          Mephistopheles' "first draw in each draw step"),
│   │                          attacked_this_turn (Fire and Brimstone),
│   │                          acted_this_turn / acted_last_turn (Arboria),
│   │                          damage_caps (Forethought Amulet's
│   │                          replacement), life_for_mana (Channel),
│   │                          paid_prevention (Guardian Angel's rider:
│   │                          {"target", "desc"} per resolution) and
│   │                          land_mana_becomes (Deep Water)
│   ├── stack_item.gd        class StackItem — SPELL/ABILITY/TRIGGER data.
│   │                          cost_paid holds WHAT THIS ACTIVATION'S COST
│   │                          ATE (_sacrificed_toughness,
│   │                          _exiled_mana_value, _discarded_types) — on
│   │                          the ITEM, not on the permanent, which has
│   │                          one slot and let two stacked free
│   │                          activations of Life Chisel / Diamond Valley
│   │                          / Necropolis / Land's Edge read each
│   │                          other's record. Cards ask
│   │                          MtgGame.cost_paid(). `delayed` is the
│   │                          queue entry behind a delayed trigger
│   │                          (read via MtgGame.current_delayed)
│   ├── continuous.gd        class ContinuousEffects — recalculation pipeline
│   │                          in CR 613 layer order: reset → animations
│   │                          (layer 4) → type-changing statics (layer 4,
│   │                          run twice when two share the board, a
│   │                          one-level stand-in for CR 613.8 dependency)
│   │                          → base-P/T statics (7a/7b) → floating base-P/T
│   │                          sets (7b, later timestamp) → colour changes
│   │                          (layer 5) → the remaining statics (7c) →
│   │                          counters (7d, any "+A/+B"-named kind) →
│   │                          floating until-EOT pumps → landwalk grants →
│   │                          rampage grants (largest wins, not stacked) →
│   │                          block restrictions → ability losses (layer 6)
│   │                          → combat-damage shields → P/T switches
│   │                          (CR 613.4e); FLOATING STATICS
│   │                          (add_floating_static) are a StaticAbility
│   │                          that outlives its source — run in the same
│   │                          five sub-passes and layer order as a live
│   │                          one, keyed to instance_id -1 so
│   │                          forget_instance cannot drop them, ended
│   │                          only by their Duration (Titania's Song's
│   │                          "this effect continues until end of turn",
│   │                          CR 611.3a: not locked in);
│   │                          forget_instance() drops every
│   │                          floating effect keyed to an object that LEFT
│   │                          the battlefield (CR 400.7);
│   │                          it also resets the per-recalculation game
│   │                          fields statics rebuild (nullified_landwalk,
│   │                          max_attackers/max_blockers);
│   │                          simplified CR 613,
│   │                          upgrade path documented in the file header
│   ├── random_effects.gd    class RandomEffects — the Astral set's random
│   │                          CHOOSERS (random permanent / creature /
│   │                          spell-or-permanent / damage target / player /
│   │                          colour / graveyard card / library card /
│   │                          creature type; sample N different elements;
│   │                          distribute N at random), all
│   │                          rolled through MtgGame.rng
│   ├── combat.gd            class CombatState — attacker/blocker declarations
│   │                          + legality (flying/reach/vigilance/defender/
│   │                          sickness); blocked_attackers + was_blocked()
│   │                          keep an attacker BLOCKED once it became
│   │                          blocked, whatever happens to its blockers
│   │                          (CR 509.1h); remove_from_bands() and
│   │                          forget() take a creature out of combat
│   │                          properly (506.4) — forget() is also what
│   │                          the zone-change helpers call, so an exiled
│   │                          attacker stops attacking and a card that
│   │                          comes back mid-combat is a new object;
│   │                          damage_order + ordered_blockers_of_band are
│   │                          the attacker's announced damage assignment
│   │                          order (CR 509.2); extra_blocks is the
│   │                          ONE-TO-MANY block map (CR 509.1b — a blocker
│   │                          assigned to several attackers: Two-Headed
│   │                          Giant of Foriys, Blaze of Glory), with
│   │                          `blocks` keeping one entry per blocker so
│   │                          `blocks.has(id)` still means "is it
│   │                          blocking"; band_illegality also reads
│   │                          "bands with other [quality]" through
│   │                          shared_bands_with / bands_with_offered (the
│   │                          quality every member must have, and the
│   │                          refusal text), and bands_with_among tells
│   │                          the damage collector when two such blockers
│   │                          hand the attacker's division to the
│   │                          defender (CR 702.22c, 702.22j); ask
│   │                          is_blocking() /
│   │                          attackers_blocked_by() /
│   │                          opposing_attackers() rather than comparing
│   │                          a `blocks` value; damage math lives in
│   │                          MtgGame
│   ├── deck_list.gd         class DeckList — .deck/.dec/.dck parser and
│   │                          validator, maindeck + `SB:` sideboard (the
│   │                          Deck Lab, the setup screen and the Deck
│   │                          Builder all read it). `strict` carries the
│   │                          whole proxy boundary: strict makes an unknown
│   │                          name an ERROR (every duel door loads that
│   │                          way), lenient keeps it and lists it in
│   │                          `proxies` (Import and the converter do)
│   ├── proxy_card.gd        class ProxyCard — **[QoL]** THE PROXY, a paper
│   │                          stand-in for a card this game does not
│   │                          implement. Definition: a card NAME the
│   │                          CardRegistry does not know — no marker in the
│   │                          file, so it round-trips through all three
│   │                          formats for free and GRADUATES by itself the
│   │                          day the card is built. `data_for` builds a
│   │                          CardData and NEVER registers it (the registry
│   │                          is the set of things that can be PLAYED, and
│   │                          test_registry_loaded_the_pool pins its size);
│   │                          `refusal_for` is the one call every duel door
│   │                          makes first — setup_screen's live note and
│   │                          its `Go!` gate, the Deck Lab's loader — with
│   │                          DeckList's strict mode as the floor under
│   │                          them. tests/unit/test_proxy_card.gd pins each
│   │                          door and would fail if a proxy could play
│   ├── deck_format.gd       class DeckFormat — THE FIVE 1997 FORMATS
│   │                          (Unrestricted / Wild / Restricted (Type 1) /
│   │                          Tournament (Type 1.5) / Highlander,
│   │                          @SHELLPAGE_MULTIDUEL). legal() refuses with
│   │                          a reason; classify() reproduces the game's
│   │                          own check_deck_type() (deckdll.cpp:2908).
│   │                          Both take an optional SIDEBOARD and count it
│   │                          with the maindeck: until 2026-09-01 they did
│   │                          not, so a banned or restricted card could
│   │                          hide in `SB:` lines and pass the setup screen
│   │                          and the Deck Lab's --format. Counting both
│   │                          piles is MODERN Magic's rule, not 1997's —
│   │                          the original's Deck Builder had no sideboard
│   │                          at all — and it is marked as such.
│   │                          The restricted/banned lists began as the
│   │                          GAME'S OWN data, which is the MODERN Vintage
│   │                          list — no 1997 one survives — on the
│   │                          reasoning that the 1997 card pool would do
│   │                          the historical filtering. **THAT REASONING
│   │                          WAS WRONG AND WAS CORRECTED 2026-09-01**: it
│   │                          filters cards ADDED to the list since 1997
│   │                          but cannot restore the eleven REMOVED from
│   │                          it, all of which are in our pool and were
│   │                          going unflagged (Braingeyser, Mind Twist,
│   │                          Regrowth, Recall, Fork, Berserk, Black Vise,
│   │                          Ivory Tower, Maze of Ith, Mirror Universe,
│   │                          Underworld Dreams). The list is now the UNION
│   │                          of that table and the DCI's own Classic
│   │                          (Type 1) list as printed in *The Duelist* #22
│   │                          (1 Jan 1998). `offences()` is the same three
│   │                          rules asked all at once (four-of, restricted,
│   │                          banned) for the Deck Builder's analysis and
│   │                          its save-time warning; `offences_of()` is the
│   │                          same over name->count dictionaries, which is
│   │                          what keeps the legality line O(distinct) on
│   │                          every card click. PROXIES are counted like
│   │                          any other card — a proxy Black Lotus is
│   │                          restricted — but never made playable
│   ├── decision_agent.gd    class DecisionAgent — per-seat interface for
│   │                          mid-resolution choices (discard picks,
│   │                          yes/no costs, library searches, colour
│   │                          choices); heuristic defaults; the AI
│   │                          overrides it. choose_* is the FUNNEL that
│   │                          files every question on the game as a
│   │                          PlayerChoice; subclasses override answer_*.
│   │                          Also the three "hold the turn open for the
│   │                          player" switches — wants_to_choose_discard
│   │                          (§1.1), wants_to_assign_combat_damage and
│   │                          order_blockers/assign_combat_damage (§1.4),
│   │                          choose_mulligan (§1.5) — and accept_answer,
│   │                          how the engine hands back an answer to a
│   │                          question it held a resolution open on (§1.3).
│   │                          choose_option/answer_option is the fifth
│   │                          primitive ("choose one of these labelled
│   │                          things", answered by INDEX), with
│   │                          choose_number as sugar over it; can_answer
│   │                          says which PlayerChoice.Kinds a seat can be
│   │                          SHOWN, so the pre-flight never holds a duel
│   │                          open on a question its front end cannot
│   │                          render
│   ├── player_choice.gd     class PlayerChoice — ONE mid-resolution
│   │                          question (kind/pid/prompt/source/step/
│   │                          hint/answer, plus candidates + optional for
│   │                          the CARD and DISCARD kinds, options for
│   │                          the OPTION kind — labelled things answered
│   │                          by index — and colors for a COLOR question
│   │                          that offers fewer than five). is_cost marks
│   │                          a question asked while a COST is assembled
│   │                          (CR 601.2h) rather than while something
│   │                          resolves: a different hold, different 1997
│   │                          words. sacrifice_prompt/mana_color_prompt
│   │                          are those words. Announced on
│   │                          MtgGame.choice_requested, kept in
│   │                          choice_log + unanswered_choices, and
│   │                          remembered per card in choice_history. What
│   │                          MtgGame.awaiting_choice holds and
│   │                          answer_choice answers (docs/duel-todo.md
│   │                          §1.3)
│   ├── game_snapshot.gd     class GameSnapshot — a REWIND POINT for the
│   │                          whole engine. take(game) reads every script
│   │                          variable of every mutable state object
│   │                          reachable from the game (STATE_CLASSES +
│   │                          every DecisionAgent) into a copy; restore()
│   │                          writes them back ONTO THE SAME OBJECTS, so
│   │                          held references survive and anything the
│   │                          run created becomes unreferenced. Reflective
│   │                          (get_property_list), so new fields are
│   │                          covered for free. Card definitions are NOT
│   │                          walked — they are never written to. Powers
│   │                          the pre-flight probe (§1.3); the rewind is
│   │                          pinned by "a probed duel is the same duel"
│   ├── undo_log.gd          class UndoLog — the MAKE/UNMAKE JOURNAL the
│   │                          search uses instead of a snapshot (M4 phase
│   │                          3). Three parallel typed arrays of (object,
│   │                          property, old value); MtgGame.make_mark()
│   │                          opens a node and unmake_to() replays it
│   │                          backwards. PRIMARY STATE ONLY — cur_*, the
│   │                          player-level static flags and the
│   │                          battlefield caches are rebuilt by
│   │                          recalculate(), which is why the 97 card
│   │                          scripts that write them needed no
│   │                          instrumentation. Records rng.state, so
│   │                          exploring cannot move the real game's
│   │                          random stream (rule 7). NULL by default:
│   │                          a duel that never searches pays one inline
│   │                          null test per instrumented write, measured
│   │                          byte-identical and inside the noise on the
│   │                          Deck Lab. 21x a snapshot node on an early
│   │                          board, 5x on a wide one (docs/ROADMAP.md M4
│   │                          phase 3); pinned by tests/ai/test_undo_log.gd
│   │                          diffing a make/unmake round trip against
│   │                          GameSnapshot itself
│   ├── ai/                  THE AI OPPONENT (pure engine, headless)
│   │   ├── ai_profile.gd    class AiProfile — the difficulty surface:
│   │   │                      mistake_chance / aggression / the PANIC LINE
│   │   │                      (chump_threshold — the chump-block trigger
│   │   │                      AND the bar at which waiting damage is worth
│   │   │                      a prevention effect) / holds_instants (the
│   │   │                      whole reactive game, the 1997 damage windows
│   │   │                      included) / counter_threshold; presets named
│   │   │                      after the original's difficulties
│   │   │                      (Apprentice → Wizard). ALL tuning lives
│   │   │                      here. sideboard_swaps says how many cards a
│   │   │                      profile may move between duels (Apprentice
│   │   │                      0 — it does not sideboard at all).
│   │   ├── ai_match_memory.gd
│   │   │                    class AiMatchMemory — WHAT ONE SEAT SAW, and
│   │   │                      the only thing AiSideboard may read. Watches
│   │   │                      MtgGame.event_occurred for the opponent's
│   │   │                      casts, land drops and battlefield arrivals
│   │   │                      (tokens excluded, one instance counted once)
│   │   │                      plus damage taken per COLOUR; copies are
│   │   │                      kept at the per-duel MAXIMUM, never summed.
│   │   │                      Never reads the opponent's decklist — that
│   │   │                      would be cheating and the original does not
│   │   ├── ai_sideboard.gd  class AiSideboard — the between-duels swap
│   │   │                      (M4 phase 2.x). tallies() turns the memory
│   │   │                      into what a sideboard card can answer;
│   │   │                      answers() reads a card's answer profile off
│   │   │                      its oracle text (nonX / "without X" stripped
│   │   │                      first, or Terror reads as artifact hate);
│   │   │                      score() puts both piles on one scale
│   │   │                      (damped card value + matchup bonus − a
│   │   │                      penalty for a narrow answer with nothing to
│   │   │                      answer); sideboard() swaps best-in for
│   │   │                      worst-out one for one, never cutting a land
│   │   │                      and never boarding in a card the deck's own
│   │   │                      mana cannot cast. Three invariants: deck
│   │   │                      size fixed, copy limit counted across BOTH
│   │   │                      piles, format still legal
│   │   ├── evaluator.gd     class Evaluator — permanent/card values,
│   │   │                      keyword worth, weighted position score
│   │   │                      (mage-go's eval package, GDScript scale)
│   │   ├── effect_intent.gd class EffectIntent — WHAT AN EFFECT LIST DOES,
│   │   │                      read once into numbers the AI reasons with
│   │   │                      (damage / X damage / self-damage / removes /
│   │   │                      bounces / taps / draws / pumps / regenerates
│   │   │                      / adds mana / sweeper kept whole), by EFFECT
│   │   │                      CLASS so every card built from the shared
│   │   │                      vocabulary is understood for free, plus the
│   │   │                      ONE table of card-local effects (Orcish
│   │   │                      Artillery, Fireball, Swords, Twiddle's
│   │   │                      tap-or-untap, ...). The port of mage-go's
│   │   │                      intrinsicAbilityQuality / bestXValue
│   │   │                      (heuristic.go:1074-1232). Also THE AURA AIM
│   │   │                      (aura_aim / AURA_HOSTILE, 2026-09-04):
│   │   │                      which side of the table an aura's host
│   │   │                      belongs on, stated as DATA because an aura
│   │   │                      has no spell effects to read — structural
│   │   │                      signals first (steals / reanimates /
│   │   │                      grants protection), then the 28-name
│   │   │                      hostile set, friendly by default, the
│   │   │                      whole pool pinned by a coverage test
│   │   └── ai_player.gd     class AiPlayer extends DecisionAgent — one
│   │                          act() per call through the PUBLIC API:
│   │                          colour-aware land drops, mana tap planning
│   │                          (floating mana included), value-ranked
│   │                          casting with intent-classified targeting
│   │                          (an AURA's side of the table comes from
│   │                          EffectIntent.aura_aim, and a TAP from the
│   │                          tap policy, not from the victim's value),
│   │                          X SIZED to the job (exact toughness, exact
│   │                          lethal, never a plink at twenty), sweepers
│   │                          only when the board they clear beats ours,
│   │                          Dark Ritual only for a spell it enables;
│   │                          ONE SCORER FOR EVERY ACTIVATED ABILITY
│   │                          (_try_activate, three moments: our main at
│   │                          quality >= 3, their upkeep for tap effects,
│   │                          their end step as the mana sink); HELD
│   │                          INSTANTS (removal, draw, tricks) kept for
│   │                          their combat / their end step with mana
│   │                          reserved for them (mage-go's
│   │                          canCastWhileReserving); THE TAP POLICY
│   │                          (_tap_denies_something, _size_tap,
│   │                          _fire_tap_instant, 2026-09-04) — a tap has
│   │                          no value of its own, so a tap SPELL buys
│   │                          one of exactly two readings: their best
│   │                          untapped creature at THEIR UPKEEP (it
│   │                          cannot attack, then cannot block), or the
│   │                          blocker in the way in OUR PRECOMBAT MAIN
│   │                          with an attack ready; never a land, never
│   │                          one of ours, never one already tapped,
│   │                          never below a card's worth; combat maths with
│   │                          first strike, regeneration shields and
│   │                          trample (_dies_to, _damage_through_blocks),
│   │                          ATTACKS DECIDED AS A GROUP
│   │                          (_choose_attack_cohort, _cohort_value,
│   │                          _face_damage_value, 2026-09-04): the
│   │                          per-creature risk read (_attack_risk,
│   │                          _attack_is_reasonable, _combat_tolerance)
│   │                          is the floor, then the bodies it rejected
│   │                          are offered cheapest-risk first and the
│   │                          longest prefix whose WHOLE-GROUP exchange
│   │                          pays is kept — so one 3/3 no longer blanks
│   │                          four 2/2s it can only eat one of, and face
│   │                          damage is finally priced against the
│   │                          defender's REMAINING life (the clock)
│   │                          rather than not at all (+lethal push,
│   │                          +one more attacker for a pump in hand),
│   │                          kill/absorb/shield/safe/trade/gang/chump
│   │                          blocks, combat responses on both sides
│   │                          (removal scored by what it saves, Giant
│   │                          Growth to win or to finish, firebreathing
│   │                          only with mana main phase 2 does not need,
│   │                          Gargoyle toughness pumps to survive a block,
│   │                          Unsummon on our own Djinn under a Terror),
│   │                          seeded mistake injection; play_out() soak
│   │                          driver. THE TWO 1997 DAMAGE WINDOWS
│   │                          (_window_action, §6.8): answer the worst
│   │                          packet it can actually reach with the
│   │                          CHEAPEST effect that covers it, and
│   │                          regenerate only what is already dying —
│   │                          all four decisions scaled off AiProfile
│   │                          alone (holds_instants gates it, so the
│   │                          Apprentice never uses it). Guardian
│   │                          Angel's rider is bought all-or-nothing
│   │                          (_buy_prevention, _points_to_save): the
│   │                          points that keep a doomed blocker alive
│   │                          after blocks, or the cheapest cover of a
│   │                          window packet; _uncovered discounts a pool
│   │                          already on the victim. Coloured-X
│   │                          spells: _max_affordable_x(x_color) grows X
│   │                          against cost.plus_colored, _generic_x
│   │                          gives the generic part (0 when coloured).
│   │                          THE PLAN IS PUT TO THE ENGINE BEFORE A LAND
│   │                          IS TAPPED (2026-09-05, class 4 of the
│   │                          dead-card sweep): _try_cast_best and
│   │                          _cast_response — between them every cast
│   │                          this file makes — end with
│   │                          MtgGame.cast_refusal, so a legality the
│   │                          planner did not mirror is no longer
│   │                          discovered AFTER the mana is spent. The
│   │                          picker learned the three it was missing:
│   │                          a PLAYER slot is legality-checked instead
│   │                          of handed over ("target player who attacked
│   │                          this turn"), a slot the GAME rolls or the
│   │                          OPPONENT names is left empty because it is
│   │                          not ours to fill (and a roll that can land
│   │                          on our own board is not fired blind), and
│   │                          every legality question is asked at the X
│   │                          being considered (MtgGame.target_legal_at).
│   │                          _targets_depend_on_x spots a card whose
│   │                          targeting moves with its X and
│   │                          _size_and_aim then TRIES EACH AFFORDABLE X
│   │                          ON, cheapest first, keeping the best aim —
│   │                          which is how Detonate is sized to the
│   │                          artifact it wants; _x_that_makes_legal is
│   │                          the same search for one known target, and
│   │                          it is what fires Spell Blast for exactly
│   │                          the mana value on the stack.
│   │                          _find_x_power_pump is the +X/+0 FINISHER
│   │                          (Howl from Beyond), deliberately kept apart
│   │                          from _find_pump_instant (whose three
│   │                          callers all read a fixed power/toughness)
│   │                          and offered only when the swing is lethal,
│   │                          for X = the shortfall exactly.
│   │                          Upgrade path: cloning + minimax
│   │                          (mage-go search/) behind the same act()
│   ├── card_script.gd       class CardScript — base for card files; override
│   │                          build() -> CardData
│   └── card_registry.gd     class CardRegistry — static name→CardData store;
│                              scans cards/sets/<set>/*.gd (folder = set code,
│                              one file = one card); duplicate names error.
│                              originally_printed_in(name, set) answers "a
│                              name originally printed in the <expansion>"
│                              (Golgothian Sylex, City in a Bottle) from the
│                              Scryfall snapshot in SET_ORDER printing
│                              order — NOT from the folder a card file
│                              happens to live in. artist_of(name, set)
│                              reads the same snapshot for the ILLUSTRATOR
│                              credit and hangs it on CardData.artist next
│                              to set_code, so no card file records it
│
├── cards/
│   ├── data/                Scryfall-derived card database, one JSON per set
│   │                          (2ed/4ed/arn/atq/leg/drk/past/phpr.json) —
│   │                          refreshed by tools/fetch_cards.py; the future
│   │                          deck-builder/economy read their card facts here
│   │   └── sets.json        The SETS themselves: name, release date, printed
│   │                          size and a short history each, from the
│   │                          Scryfall set objects in the local card packs.
│   │                          SetBadges.describe() turns one into the popup
│   │                          a title-screen badge opens; the count for THIS
│   │                          pool is counted from the registry, never stored
│   ├── sets/                LOADED BY THE REGISTRY — implemented cards only
│   │   │                      (788 as of 2026-08-31), folders named by
│   │   │                      Scryfall set code. The folder is where the
│   │   │                      FILE lives, not the card's original printing
│   │   │                      — ask CardRegistry.originally_printed_in()
│   │   │                      for that (32 Antiquities and 24 Arabian
│   │   │                      cards ship in other folders):
│   │   ├── 2ed/  279        Unlimited, the base game (basics, the vanilla
│   │   │                      and keyword creatures, and most of the
│   │   │                      showcase mechanics: Lightning Bolt, Giant
│   │   │                      Growth, Terror, Prodigal Sorcerer, Sol Ring,
│   │   │                      Ankh of Mishra, Holy Strength)
│   │   ├── 4ed/  137        Fourth Edition (an all-reprint set)
│   │   ├── leg/  211        Legends — the legend rule, the world rule,
│   │   │                      banding cycles, the Glyphs, the Elder Dragons
│   │   ├── drk/   58        The Dark
│   │   ├── atq/   45        Antiquities — the artifact set
│   │   ├── arn/   43        Arabian Nights — ante, Oubliette's phasing
│   │   ├── past/  12        Astral (the 1997 game's own cards): the random
│   │   │                      effect tables, Aswan Jaguar, Gem Bazaar
│   │   └── phpr/   3        Promos
│   │                        76 of the 788 files carry the AUTOGENERATED
│   │                        marker (stats-and-keyword creatures regenerated
│   │                        by tools/gen_cards.py — don't hand-edit in
│   │                        place; remove the marker to adopt one)
│   └── todo/                NOT loaded — 108 documented stubs, one per
│                              unimplemented pool card, with exact oracle
│                              text. Implementing = write test, fill build(),
│                              MOVE file into cards/sets/<set>/
│
├── tools/                   Pipelines (Python 3, stdlib only)
│   ├── fetch_cards.py       Scryfall → cards/data/<set>.json for the 8-set
│   │                          pool (base game + Duels of the Planeswalkers);
│   │                          excludes Chaos Orb/Falling Star/Shahrazad/
│   │                          Word of Command (s30 precedent). KEEP_FIELDS
│   │                          is the whole contract — `artist` joined it in
│   │                          the fortieth pass for the `Illus.` credit.
│   │                          EXTRA_PRINTINGS fetches a NAMED card from
│   │                          another Scryfall set and files it under one
│   │                          of ours: the 1997 game's sixth promo,
│   │                          Nalathni Dragon, is a DragonCon 1994 card
│   │                          (`pdrc`) that no whole-set query in this
│   │                          pool would ever return, and its record keeps
│   │                          `printed_in` so the origin is not lost.
│   │                          THE ONE Scryfall client: scryfall_get()
│   │                          (User-Agent, ≥100 ms pause), fetch_set_raw()
│   │                          / fetch_one_raw() (full records), trim() →
│   │                          KEEP_FIELDS; build_card_packs.py imports
│   │                          these instead of carrying its own
│   ├── gen_cards.py         data → GDScript: auto-implements vanilla &
│   │                          supported-keyword creatures into cards/sets/,
│   │                          stubs everything else into cards/todo/;
│   │                          idempotent, never touches hand-written files
│   ├── mtg_assets.py       THE PLAYER'S FRONT DOOR to the art (2026-09-04).
│   │                          Three jobs in one script: say what kind of
│   │                          1997 install is needed, --check one and
│   │                          report on six groups of files separately,
│   │                          and --install it into ONE zip whose inner
│   │                          folder is `skin/` so it unpacks beside the
│   │                          binary with no path to type. --from-skin
│   │                          archives an already-imported folder (how
│   │                          shandalar-art-1997.zip was built). Wraps
│   │                          import_original.py, which must sit beside
│   │                          it; reads the install, never writes to it.
│   ├── import_original.py   1997 skin importer: copies original art/fonts
│   │                          from the USER'S OWN game copy into
│   │                          assets/original/ (gitignored) per its
│   │                          MANIFEST; pairs with game/skin.gd. Its
│   │                          comments carry the PROVENANCE RULES and the
│   │                          PIL survey behind every key — including the
│   │                          third rule, found in the deck-builder pass:
│   │                          every file in a Manalink install's
│   │                          Program/DBArt/ is a PNG wearing a .pic
│   │                          extension, so check the magic bytes, not
│   │                          the extension.
│   │                          IT ALSO DECODES BOTH 1997 ART FORMATS with
│   │                          the standard library: decode_spr (.SPR) and,
│   │                          since 2026-09-03, decode_pic (.PIC — LZW
│   │                          around RLE, fixed code-width schedule,
│   │                          dictionary base 257) + split_image_mask,
│   │                          whose polarity is MEASURED off the border
│   │                          because Faces/*.pic and Face.pic disagree.
│   │                          import_portraits writes SEVENTY faces —
│   │                          14 player (@PLAYERNAMES), 55 rogue
│   │                          (@DECKFACES, one-based, rogue_ prefix) and
│   │                          the Facemaker face; PIC_SCREENS decodes
│   │                          Advfac64.pic to a skin key nothing reads yet
│   ├── fetch_card_art.py    Scryfall art_crop → assets/cardart/ (gitignored,
│   │                          s30's card-image approach pre-downloaded);
│   │                          resume-safe, --force re-fetches, --out DIR
│   │                          aims it anywhere. RUNS STANDALONE beside a
│   │                          shipped binary too: there is no cards/data/
│   │                          to read there (it is inside the .pck), so
│   │                          the pool is asked of Scryfall instead — one
│   │                          paged search per 1997 set, 900 names against
│   │                          our 897 (three we do not implement, whose
│   │                          art is downloaded and never used). Read by
│   │                          GameSkin.card_art for the enlarged preview.
│   │                          snake() is GameSkin._snake exactly (ASCII-
│   │                          only: "Dandân" → dand_n — it kept accents
│   │                          until 2026-09-02, so eight Arabian Nights
│   │                          pictures were files the game never looked
│   │                          up; legacy_snake() names the old spelling);
│   │                          targets_for() / fetch_missing_art() are the
│   │                          per-card pieces build_card_packs.py reuses
│   ├── build_card_packs.py  THE PACK BUILDER (2026-09-02) — freezes each
│   │                          cards/data set as ../shandalar-packs/
│   │                          <code>.tar.gz (set.json, enriched cards.json,
│   │                          rarity/colour/land lists, printings.tsv,
│   │                          icon.svg + PNG, art/ + index, README) and the
│   │                          eight-set purist pool as dotp-1997.tar.gz
│   │                          (merged 897-name pool, flat art/, sets/<code>/
│   │                          without art); index.json with sha256;
│   │                          <out>/cache/ makes rebuilds offline;
│   │                          --offline reports instead of fetching,
│   │                          --force refetches, --max-art-fetch caps art
│   │                          downloads (it is not the bulk art fetcher).
│   │                          Layout: docs/set-packages-plan.md
│   │                          "Implemented: pack format v1"
│   ├── test_import_original.py  unittest for the raw 1997 decoders (no
│   │                          original bytes: every fixture is built by
│   │                          encoder helpers that invert the decoder).
│   │                          Pins the LZW bit packing and its width
│   │                          schedule by absolute number, the 257
│   │                          dictionary base, the RLE cases, decode_pic
│   │                          round-trips, MEASURED mask polarity both
│   │                          ways, the @DECKFACES names and one-based
│   │                          slots, and that every step reports rather
│   │                          than raises on junk. Run: python3 -m
│   │                          unittest discover -s tools -p 'test_*.py'
│   ├── test_build_card_packs.py  unittest for the builder (no network,
│   │                          temp fixture with an accented name stored
│   │                          under the legacy spelling, a reprint, a
│   │                          gold card, a card without art): naming,
│   │                          lists, POOL-order merge, enrichment, an
│   │                          offline build of set + bundle archives and
│   │                          index.json. Run: python3 -m unittest
│   │                          discover -s tools -p 'test_*.py'
│   ├── simulate.gd          THE DECK LAB (SceneTree script) — headless
│   │                          AI-vs-AI deck testing: duel & gauntlet
│   │                          modes, WorkerThreadPool parallelism,
│   │                          report/JSON/CSV/SVG output. Entry point:
│   │                          ./deck_lab.sh; manual: docs/deck-lab.md
│   ├── deck_convert.gd      Deck-format converter (community .deck/.dec ⇄
│   │                          the original MicroProse .dck); entry point
│   │                          ./deck_convert.sh
│   ├── elo_ledger.gd        class EloLedger — decks/ratings.txt, the Deck
│   │                          Lab's running Elo (K=8 per matchup)
│   ├── bench_probe.gd       THE PROBE COST CURVE (SceneTree script) —
│   │                          GameSnapshot take/restore and a whole
│   │                          MtgGame._preflight timed against board size,
│   │                          because the number in GameSnapshot's header
│   │                          rots as CardInstance grows fields. Run:
│   │                          ../tools/godot --headless --path . -s
│   │                          res://tools/bench_probe.gd
│   ├── bench_undo.gd        THE PHASE-3 MEASUREMENT (SceneTree script) —
│   │                          where the 3 ms of a rewind goes (snapshot vs
│   │                          recalculate vs the move), what a move
│   │                          actually changes, what a journal record
│   │                          costs, whether the journal is SOUND (it
│   │                          diffs a make/unmake against GameSnapshot and
│   │                          names any field MtgGame fails to record),
│   │                          nodes/second journal vs snapshot, and the
│   │                          REAL branching factor of a main phase, an
│   │                          attack and a block measured over gauntlet
│   │                          duels. Run: ../tools/godot --headless
│   │                          --path . -s res://tools/bench_undo.gd
│   ├── screenshot_tour.gd   Screenshot tour of the UI (main session's tool;
│   │   screenshot_tour.tscn   off limits to engine passes)
│   ├── duel_soak.gd         THE DUEL SOAK — whole duels through the LIVE
│   │                          DuelScreen under Xvfb (AI vs AI, and a human
│   │                          seat fuzzed by its HumanClicker), Godot's
│   │                          errors counted; `--rules fifth|modern` instead
│   │                          of user://settings.cfg; run via ./duel_soak.sh
│   ├── sim_stats.gd         class SimStats — Wilson 95% CIs, matchup
│   │                          summaries, play/draw splits (unit-tested)
│   └── svg_charts.gd        class SvgCharts — dependency-free SVG charts
│                              (win-rate bars + CI whiskers, turn
│                              histograms)
├── deck_lab.sh              Deck Lab entry point (see --help)
├── duel_soak.sh             Duel-soak entry point: wraps tools/duel_soak.gd
│                              in the safe Xvfb recipe and FAILS on any
│                              ERROR/WARNING/STALL line; exit 2 stall, 3 bad
│                              argument, 124 timeout (manual in the file)
├── deck_convert.sh          Deck-format converter entry point
├── build_release.sh         Release build: exports the "Linux 64" preset with
│                              the pinned Godot, then smoke-boots the result
│                              and fails on an error line. --out DIR, --skin
│                              (links assets/ into user://original_skin so an
│                              exported build looks like a dev checkout).
│                              Default output ../shandalar-build/linux64/
├── decks/                   Shipped five-style gauntlet (.deck files —
│   │                          format in docs/deck-lab.md); a CI test
│   │                          keeps every deck valid vs the card pool.
│   │                          The Deck Builder writes to user://decks/
│   │                          instead (res:// is read-only in an export);
│   │                          DeckStore lists both and so both are
│   │                          loadable in the battle-setup screen. The
│   │                          five starter decks sit at the top level;
│   │                          the 312 ported decks below are in one
│   │                          subfolder per provenance group
│   │                          (docs/decks-1997.md), each file declaring
│   │                          its `# group:` heading
│   ├── 1997/originals/      The 55 enemy decks of the 1997 game, folded
│   │                          from the colour-keyed .dck sections (s30
│   │                          tomls, Decks.zip's 1997 prefix, mage-go)
│   ├── 1997/ancients/       The 55 Spells of the Ancients enemy decks
│   │                          (Program/decks/*.dck; Merfolk Shaman from
│   │                          the wiki, Warlock's 8 Fear as the file has it)
│   ├── 1997/duels/          The 25 Duels of the Planeswalkers enemy
│   │                          variants the wiki lists (no local copy exists)
│   ├── 1997/coyote_tex/     5 "Play Deck" folder decks by Coyote Tex
│   ├── 1997/kevin_bane/     8 by Kevin Bane
│   ├── 1997/other/          9 by other MicroProse hands
│   ├── tournament/          76 real event lists, NOT MicroProse's —
│   │                          Worlds 1994-97, PT New York 1996 (the eight
│   │                          Pro Tour Collector Set decks among them),
│   │                          PT Dallas 1996, and the few other sanctioned
│   │                          events with a pilot/event/year; 71 carry
│   │                          proxies (Ice Age / FE / Homelands /
│   │                          Alliances / Mirage names the pool lacks)
│   ├── community/           64 period decks that were not event lists —
│   │                          The Deck 1994-97 by version, Necro, Sligh,
│   │                          Turbo Stasis, Señor Stompy, the 1993-96
│   │                          combo and aggro lists Menendian dates, and
│   │                          Abe Sargent's 39 re-tuned Shandalar enemy
│   │                          decks (2009) — 48 proxy-free, so the
│   │                          gauntlet deals them
│   ├── extended_community/  15 Old School 93/94 archetype reference
│   │                          lists (2014-18) and two Reanimator lists
│   │                          that lean on cards outside the pool; one
│   │                          proxy-free
│   └── ratings.txt          The Deck Lab's Elo ledger (tools/elo_ledger.gd)
├── sim_results/             Deck Lab output, run_<stamp>/ per run; not
│                              source. Carries a .gdignore (and the tool
│                              writes one into any run directory inside
│                              the project) so the editor's import pass
│                              never reads a matchups.csv as a
│                              translation table
│
├── tests/                   GUT suite — 3671 tests / ~84 200 asserts, ~135 s
│   ├── game_test.gd         class GameTest — the test DSL (see
│   │                          ARCHITECTURE.md "Testing"): put_battlefield,
│   │                          give_hand, put_synthetic (a permanent
│   │                          built from a CardData the test wrote —
│   │                          for engine tests that pin a HOOK rather
│   │                          than a card), add_mana, resolve_stack,
│   │                          advance_to_step/next_turn, run_combat,
│   │                          assert_ok/assert_refused
│   ├── unit/
│   │   ├── test_mana.gd     ManaCost parsing, ManaPool payment edge cases
│   │   ├── test_colors.gd   live colours: the Laces, colour changes, and
│   │   │                      every consumer that must read cur_colors
│   │   ├── test_targeting.gd TargetSpec/TargetPlan: legality, the
│   │   │                      no-duplicate rule (CR 601.2c), divided
│   │   │                      amounts (601.2d), variable counts
│   │   ├── test_review_engine_2026_08.gd  engine pins from the 2026-08
│   │   │                      code review (docs/code-review-2026-08.md)
│   │   ├── test_audit_2026_09.gd  engine pins from the 2026-09 full audit
│   │   │                      (docs/audit-2026-09.md)
│   │   ├── test_review_2026_09.gd  engine pins from the 2026-09-01 code
│   │   │                      review (docs/code-review-2026-09.md): the
│   │   │                      CardRegistry printing-index race, dual-land
│   │   │                      text changes, face-down block restrictions,
│   │   │                      the tapped-artifact/animation order
│   │   ├── test_exile_audit.gd  the EXILE zone's whole surface: what a
│   │   │                      card loses on the way out, what can no
│   │   │                      longer reach it, and that what comes back
│   │   │                      is a new object — including CR 506.4, an
│   │   │                      exiled attacker returned mid-combat
│   │   ├── test_turn_and_stack.gd  turn structure, first-draw skip, land
│   │   │                      rule, timing, priority, LIFO stack, fizzle,
│   │   │                      until-EOT expiry, pool emptying
│   │   ├── test_combat.gd   attack/block legality, vigilance, flying/reach,
│   │   │                      trample math, simultaneous damage, lethality
│   │   ├── test_combat_evasion_2026_09_04.gd  THE DEFENDING PLAYER'S
│   │   │                      LIFE after a block — the invariant the
│   │   │                      playtest defect of 2026-09-04 broke on
│   │   │                      screen: every evasion keyword against
│   │   │                      every blocker shape that may stop it,
│   │   │                      every damage-assignment path (one blocker,
│   │   │                      several, trample, first strike, the 1997
│   │   │                      free-division fork, an agent that answers
│   │   │                      with face damage), and every way a blocker
│   │   │                      can leave between the declaration and the
│   │   │                      damage (CR 509.1h)
│   │   ├── test_mechanics.gd  wave-1 mechanics: first strike waves,
│   │   │                      protection DEBT, regeneration, landwalk,
│   │   │                      must-attack, wall bans, counterspell wars,
│   │   │                      X-spells, Lotus sacrifice, dual lands
│   │   ├── test_first_strike_step.gd  §1.6: FIRST_STRIKE_DAMAGE is its
│   │   │                      own step with a priority window, skipped
│   │   │                      when nobody has first strike (CR 510.5)
│   │   ├── test_discard_phase.gd  §1.1: the cleanup step holds open for
│   │   │                      a seat that wants to pick its own discard
│   │   ├── test_damage_assignment.gd  §1.4: the attacker orders and
│   │   │                      divides its combat damage; the modern
│   │   │                      order vs the 1997 free-division fork
│   │   ├── test_mulligan.gd  §1.5: the Shandalar mulligan — no-land or
│   │   │                      all-land only, seven for seven, once each,
│   │   │                      and the opponent may follow
│   │   ├── test_ante.gd      §6.19: the OPENING STAKE — one card each off
│   │   │                      the deck before the deal, deterministic on
│   │   │                      game.rng, Shandalar's basic-land exemption
│   │   │                      for the player's own stake, and the
│   │   │                      guarantee that a duel which did not ask for
│   │   │                      an ante loses neither a card nor an RNG
│   │   │                      draw (what keeps the Deck Lab reproducible)
│   │   ├── test_player_choices.gd  §1.3: every mid-resolution question
│   │   │                      is a PlayerChoice, on the record, and
│   │   │                      answerable in advance
│   │   ├── test_choice_preflight.gd  §1.3: the GameSnapshot rewind (state,
│   │   │                      rng, object identity), the resolution HELD
│   │   │                      OPEN on the FIRST ask, answering it either
│   │   │                      way, the opt-in flag — and the one that
│   │   │                      guards the whole design, "a probed duel is
│   │   │                      the same duel", eight turns compared line
│   │   │                      for line against an unprobed one
│   │   ├── test_snapshot_audit.gd  ADVERSARIAL audit of that rewind: a
│   │   │                      reflective FINGERPRINT of every script
│   │   │                      variable of every scripted object the game
│   │   │                      reaches — definitions included, since
│   │   │                      CardRegistry is static — plus the rng, taken
│   │   │                      before and after a rewind, a probe, and a
│   │   │                      probe held under all four other holds.
│   │   │                      Includes the meta-test that the fingerprint
│   │   │                      would notice a miss at all
│   │   ├── test_cost_choice_contract.gd  CR 601.2h from the ledger's
│   │   │                      side: a REFUSED cast/activation files no
│   │   │                      PlayerChoice and writes no "(decided for)"
│   │   │                      line — plus the two §1.3 rows that were
│   │   │                      never fall-throughs (the Clone copy pick,
│   │   │                      the cleanup discard)
│   │   ├── test_simultaneous_loss.gd  CR 104.4b: an Earthquake lethal to
│   │   │                      both duelists is a DRAW, under both the
│   │   │                      modern and the 1997 phase-end life check
│   │   └── test_engine_additions.gd  engine mechanics added while
│   │                          graduating the pool (waves 19+): MassPump,
│   │                          CR 613.4e P/T switch, "target opponent",
│   │                          the world rule, LoseAbilityEffect,
│   │                          non-tapping/sacrifice mana abilities,
│   │                          PreventCombatDamage
│   └── cards/
│       ├── test_2ed_cards.gd      per-card behavior for the hand-written
│       │                            showcase cards + registry count
│       ├── test_generated_pool.gd registry-wide sanity invariants + spot
│       │                            integration proving generated cards
│       │                            play identically to hand-written ones
│       ├── test_pool_wave1.gd     wave-1 graduations: Hyppie discards, Erg
│       │                            Raiders punishment, Crusade/Bad Moon,
│       │                            self-pumps, Swords/Wrath/Earthquake/
│       │                            Weakness/Unsummon, Ritual curve,
│       │                            Braingeyser, Birds, Moxen
│       ├── test_pool_wave2.gd     wave-2: CoP shields, Icy, Time Walk,
│       │                            Fog, Mana Flare/Wild Growth, Disk,
│       │                            Howling Mine, Raise Dead, Wheel,
│       │                            Timetwister, Assassin, Nightmare,
│       │                            Pestilence, Drain Life, Flight,
│       │                            Castle, Armageddon, Disenchant
│       │   (waves 3-74 continue the same pattern, one file per wave)
│       └── test_audit_fixes.gd    card pins from the mage-go scrutiny
│                                    audit (docs/audit-vs-mage-go.md):
│                                    Regeneration cost, Drain Life caps,
│                                    Animate Dead sacrifice, Ankh on
│                                    fetched lands, Factory self-pump,
│                                    distinct multi-targets, Land Tax
│                                    intervening-if, became-tapped stings
│   (tests/unit/test_audit_fixes.gd holds the ENGINE pins from the same
│    audit: ability self-targeting, regen tap recalc, counter layering)
│   (tests/{unit,cards}/test_review_2026_08.gd — pins from the 2026-08
│    code review, docs/code-review-2026-08.md: live-ability mana plans,
│    aura detach on bounce, land-drop priority, CR 613 7b-before-7c,
│    last known information, counter costs, cast-timing riders)
│   (tests/{unit,cards}/test_audit_2026_09*.gd — pins from the 2026-09 full
│    audit, docs/audit-2026-09.md: the CR 613 layer passes, CR 305.7 land
│    retyping, tokens ceasing to exist, until-EOT effects not following a
│    bounced card, blocked-status persistence, control changes leaving
│    combat, requirement-vs-restriction, Lure, single blocker packets,
│    ability fizzling, Aura legality, source-filtered targeting bans,
│    original-printing set membership, cost-modifier scoping, X-aware cost
│    reductions, and ~45 card fixes across the _a/_b/_c files)
│   (tests/cards/test_audit_vs_s30.gd — pins from the 2026-09-01 audit
│    against the 30th-anniversary remake, docs/audit-vs-s30.md: Pyramids'
│    aura-on-a-land filter, Soul Net / Tablet of Epityr last known
│    information, Remove Enchantments group 1, Ydwen Efreet's unblock
│    exception, the Wall-only targeting ban (Dwarven Demolition Team,
│    Tunnel, Goblin Digging Team), Howling Mine and Ghazbán Ogre
│    intervening-ifs, CoP: Artifacts live types, Sylvan Library outliving
│    its source, X on the stack (Spell Blast, In the Eye of Chaos), Land
│    Equilibrium's before-count, Kudzu's unrestricted hop, token mana
│    values, Spitting Slug's once-per-combat block, Dark Sphere's source
│    pool, Wormwood Treefolk's unconditional self-burn)
│   (tests/test_simplified_ledger.gd — CONTRIBUTING.md RULE 6, PINNED both ways:
│    every card file carrying the word SIMPLIFIED is named in
│    docs/simplified-cards.md, and every card a ledger row names carries
│    the word — registry names matched as whole words, longest first, so
│    `Mountain Stronghold` does not name `Mountain`; struck-through LIFTED
│    rows are history. Its first run found two unmarked members of group
│    rows.)
│   (also tests/ui/test_duel_screen.gd — duel screen boots real games,
│    mode machine engages with the engine, fast-forward survives turns,
│    and the BORDER STATE MACHINE: an activatable permanent is yellow, a
│    must-attack creature and a must-be-blocked attacker are orange, a
│    declared attacker is green, and the two targeting cue states are
│    pushed down to the small card;
│    tests/ui/test_card_dimensions.gd — ONE CARD SIZE, EVERYWHERE, the
│    owner's standing rule, MEASURED on real widgets after a real layout
│    pass: the whole table (a lone Crusade beside a five-card pile, an
│    untapped creature beside a tapped one, a card wearing an aura), the
│    hand stack, the fan, and the graveyard/exile shelves. Also that no
│    widget declares a card size of its own, and that a tapped card turns
│    exactly 90° about its own centre while its HOLDER takes the swapped
│    footprint. It catches the failure no constant can show: a container
│    STRETCHING a SIZE_FILL card to its line height (140 or 174 instead of
│    106 — the fortieth pass);
│    tests/ui/test_card_preview.gd — THE ENLARGED CARD'S LETTERING (the
│    owner's 2026-09-04 playtest: "card text, type, illustrator,
│    power/defense are hardly readable in black"). Pins the finding that
│    the GROUND was the bug — four of the five strings ride the card's own
│    body, which the 1997 Cardbk frames paint at luma 19-114 on five of
│    six colours — so white-with-outline on the body and 1997's dark
│    47,47,47 on the light rules plate; that every size is the ported
│    ratio of the card's height and none is anywhere near what was
│    reported; that the rules box holds the original's SIX lines and no
│    seventh; that Expand shows the whole text of EVERY card in the pool
│    (measured on the real Label, not on arithmetic about it) and grows
│    the box only when a card needs it; and that a grown box carries the
│    frame's own plate rather than leaving dark text on bare art. Since
│    2026-09-04 it also pins the INLINE MANA SYMBOLS: that the pool sweep
│    did not regress (688 of 897 cards at the full size unexpanded where
│    the braces managed 685, 812 with Expand where they managed 810, and
│    still not one card losing a line), that the symbols step down with
│    the ladder, and that with no imported sheet the braces come back;
│    tests/ui/test_mana_text.gd — THE SYMBOLS THEMSELVES. Carries the
│    evidence that the 1997 game set them inline in the rules text
│    (Master.csv, Tier 1, 1997-08-14 — 204 of its 338 tagged rows carry
│    `|T`, and tap is never part of a cost) and pins the contract the
│    enlarged card's fitting arithmetic rests on: the split is lossless
│    over all 897 oracle texts, `{C}` is the ONLY code the nineteen-cell
│    sheet cannot draw and it falls back to readable braces, a symbol is
│    3/4 of the line box it stands in and never makes that line taller,
│    a run of abutting symbols never breaks across a line, and with no
│    skin the paragraph measures as the plain string it used to be;
│    tests/ui/test_mini_card.gd — THE SMALL CARD: the 1997 state
│    vocabulary verbatim (@CUECARD_SMALLCARD) and one test per state it
│    can answer; the P/T split (LIVE on the table, PRINTED in the
│    Showcase — manual p.114/118) with the anti-s30 pin that damage is a
│    marker and not a subtraction; the pump/weaken colouring; the
│    badges — regeneration (15), protection from artifacts (10), dedup,
│    in-play only, the transparent-corner keying pin, and that cell 17
│    stays blank; and THE TAP TURN — square before a frame is drawn,
│    clockwise, monotone, resumed on a rebuild, already-turned when the
│    tap is old, retargeted rather than stacked, and forgotten on untap;
│    and THE THREE TAP CUES — every tapped permanent turns AND darkens its
│    title bar AND letters it (T) (the owner, 2026-09-04), the whole cue
│    fits the 17px a covered pile row shows, the cue no longer asks whether
│    the card turns, the status line never carries the mark again, the name
│    gives the room back on untap, and neither a card in hand nor a
│    face-down one is ever marked;
│    tests/ui/test_card_pile.gd — THE PILE AND ITS CASCADE: a flat pile is
│    laid out exactly as it always was and agrees with pile_height; a
│    tapped row turns where it stands (centre pivot, one card size, the
│    MiniCard tween resumed rather than a second one); a turned row wears
│    the wash and the letters too; a hand pile never turns; battlefield
│    rows are whole unclipped cards z-ordered front-over-back while hidden
│    and collapsed piles stay strips; the stack steps along each card's own
│    title edge; an all-tapped pile is the flat pile transposed; over all
│    32 arrangements of five cards NO ROW IS EVER HIDDEN, nothing starts at
│    a negative offset and the footprint is bounded at 200x132 / 132x200;
│    and the mouse is pinned structurally — the drag hook still finds a
│    MiniCard as the DIRECT child of every holder Button, the pile PASSes,
│    the holder STOPs, the card IGNOREs, and turn_holder takes no mouse;
│    tests/ui/test_death_mark.gd — THE DYING MARK: a destroyed creature
│    leaves one on the square it stood on, at the one card size, wearing
│    the decoded Dying.pic cracks over the small card's own art region;
│    Dying.pic is 194x97 = one 97x97 frame beside its mask, so it does not
│    animate; a REGENERATED creature gets none (and drops the live overlay
│    too), a SACRIFICED one gets none, a card with no board under it or
│    one nobody can see raises nothing, the ghost hears no events of its
│    own, and the mark fades and frees itself;
│    tests/ui/test_graveyard_view.gd — §1.2: a pile opens and closes, the
│    section titles are the 1997 table's, and Raise Dead is castable
│    end to end through the screen; [QoL] the shelf costs what full-size
│    cards cost (784 for five, 504 for three), every card renders at
│    MiniCard.SIZE unscaled, the centre card carries "N / total", the
│    arrows page a whole shelf and clamp at both ends, and a pile opened
│    while targeting lands on the page holding the first legal card
│    tests/ui/test_exile_pile.gd — the pile right of the graveyard: it
│    shows its top card or its plate, opens the same viewer, and its
│    DERIVED plate borrows the 1997 grave plate's size, border and palette
│    tests/ui/test_zone_column.gd — the library/graveyard/exile row and
│    what stands beside it (owner's ask, 2026-09-03): every count is a
│    child of the pile it counts and sits in that pile's bottom-right
│    corner, none floats loose in the row (the stray white graveyard
│    number the owner photographed), all three wear the life numeral's
│    yellow over a hard black outline, an empty pile stays quiet, and the
│    seat's CHOSEN portrait (through DuelIntro.portrait_for) stands right
│    of the exile plate with its name above it for the player and below it
│    for the opponent, ellipsized so a long name never widens the sidebar
│    tests/ui/test_opening_hand.gd — §1.5: the play-or-draw and mulligan
│    sequence and every @DIALOG_PLAYORDRAW / @DIALOG_MULLIGAN string;
│    §6.19's window — its measured ground, that two full-size cards fit at
│    both supported resolutions, the ante captions, and the whole opening
│    running inside that one panel
│    tests/ui/test_duel_prompts.gd — §1.1/§1.3/§1.4 through the screen:
│    the discard phase, the `%d points left` click loop, and the choice
│    overlay — the first ask reaching the player, the option labels for
│    all four kinds, and the fact that it cannot be escaped
│    tests/ui/test_target_arrows.gd — arrowhead geometry and which arrows
│    the live state produces;
│    tests/ui/test_damage_marker.gd — §6.20b: one marker per waiting
│    packet, named by its SOURCE and showing what is still coming; a card
│    size and never rescaled; the two @CUECARD_SMALLCARD damage cues; the
│    marker hanging off its own victim; and the whole click path — two
│    packets now OPEN targeting with `Select damage card.` instead of
│    giving up, the lone packet is still auto-taken (§3.3), a packet this
│    Circle cannot answer wears the circle-slash and refuses the click,
│    and with no window open the Circle still puts up its colour shield;
│    tests/ui/test_original_dialog.gd — the 1997 popup chrome, including
│    the MEASURED bevel pixels of the original button art, so a re-import
│    from a different copy of the game cannot change the look silently;
│    tests/ui/test_combat_bar.gd — the Combat Bar's seven icons, their
│    1997 cue cards, the sheet geometry measured off Winbk_Phasecombat,
│    the per-seat gold/blue halves, the black-keyed grounds, the
│    step→icon map, and (2026-09-03) shows_attack: the bar appears
│    "during an ATTACK", so declaring none puts the Phase Bar back;
│    tests/ui/test_opponent_turn.gd — AN UNSTOPPED PHASE RUNS ITSELF
│    (2026-09-03): the human's priority windows are passed for them on
│    EITHER seat's turn, and every place 1997 says the duel must stop
│    instead — a required action, something on the chain you can answer
│    (_could_respond, 2026-09-04: "permits a response" means you have
│    one), a Stop, an
│    affordable fast effect, an action of your own in progress, the phase
│    an order came to rest in — plus your own turn's safety cases pinned
│    on an entirely unmarked bar (combat, discard, a held question, the
│    damage windows) and the one scope left: never a hotseat duel;
│    tests/ui/test_duel_pause.gd — THE PAUSE WINDOW (2026-09-03, [QoL]):
│    the title and the five entries, the buttons fitting the marble, the
│    Esc precedence in all three states (open -> close, something to
│    cancel -> cancel, nothing pending -> open), Q unconditional, no key
│    reaching the table under it, and the promise the word makes — the
│    auto-pass off, the AI's dwell neither armed nor fired, no clock of
│    its own — plus Concede asking the original's own question first;
│    tests/ui/test_casting_flow.gd — the 1997 casting flow: click the
│    spell then tap the lands (Mode.PAYING and its `Tap %s` prompt, the
│    sources lighting, Done refusing to pass priority under a waiting
│    cast, Cancel leaving the mana floating), the yellow name meaning
│    could_afford, and the double-click AUTO-CAST including X funnelling
│    and `Don't auto tap this card`;
│    tests/ui/test_card_placement.gd — MOVING A CARD BY HAND: the free
│    layer over each half, placements in half coordinates and clamped
│    inside it, the last-moved card drawn on top, a press that never
│    moves still being a click, a card leaving the table dropping its
│    seat, and Arrange straightening a moved card back into its row —
│    plus (2026-09-03) THE BOARD CASE the first pass never drove: a card
│    in a CardPile is a mouse-transparent picture inside a holder Button,
│    so lands and artifacts (which pile the moment there are two) could
│    not be dragged at all. The holder now carries the gesture, on the
│    ROW rather than the pile, clamped by a whole card rather than a
│    17px title strip;
│    tests/unit/test_mana_planner.gd — the moved planner (sources,
│    colour-first plans, restricted mana, `Don't auto tap`, max X), the
│    AI still answering through it, and the engine queries the auto-cast
│    needed: could_afford, spell_payment / ability_payment, and
│    is_unpaid_refusal;
│    tests/ui/test_phase_stops.gd — STOPS and RUN TO: the per-half/per-bar
│    model and its persistence, THE THREE DEFAULT STOPS a fresh profile
│    starts with and the settings contract behind them (absence of a row
│    means the defaults; a STAMPED four zeroes is a decision and is
│    stored; an UNSTAMPED row is a leftover from a build that shipped no
│    defaults, which is the 2026-09-04 defect — the owner's own
│    PackedInt32Array(0, 0, 8, 0), pinned by what the BAR draws), that
│    the middle default sits on a slot the Combat Bar answers for, the
│    1997 default set recorded beside ours, the four @MENU_PHASEBAR
│    entries with the two Help ones disabled and Mark as a toggle, the
│    red dot marking Stops rather than the current phase, and the driver — a run arriving,
│    a run pausing at a Stop and forgetting its destination, a Stop you
│    are standing in not trapping the order, and Done stopping for an
│    affordable fast effect;
│    tests/ui/test_combat_window.gd — the Combat window's title, when it
│    opens, which lane each side lines up in, that a creature in combat
│    leaves its territory, and minimise/restore via the Phase Bar icon;
│    tests/unit/test_board_order.gd — ARRANGE CARDS' three orders against
│    s30's own golden fixtures, the live-P/T correction, non-mutation,
│    and stability across repeated arranges;
│    tests/ui/test_arrange_cards.gd — the toggle: where it lives, the
│    1997 command name it carries, that untoggling restores the exact
│    play order (including for a card that arrived while arranged), and
│    that a click on an arranged card still operates THAT card;
│    tests/ui/test_cancel_contract.gd — §3.1/§3.2/§6.11 as one contract:
│    taking a target back, Escape peeling one layer at a time (graveyard
│    → overlays → the X question → the picks → the spell), the two
│    Situation Bar buttons appearing "depending on the situation", and
│    the Esc/Return/Spacebar rules verbatim from Duel.hlp, and — the
│    fifty-first pass — that Escape does NOT walk around
│    `attackers_revocable = false` (it used to clear every declared
│    attacker, which is a bigger take-back than the single one
│    `_toggle_attacker` refuses) while a half-made BLOCK stays cancellable;
│    tests/ui/test_territory_menu.gd — @MENU_TERRITORY: the fourteen
│    `Go to:` strings verbatim, that each names a real icon, the greyed
│    remainder, Save Game's deliberate absence, `Go to: next phase`
│    stopping at exactly one phase, and `Duel Options...` opening §6.4's
│    panel;
│    tests/ui/test_situation_bar.gd — the bar and its buttons: when Done
│    is lit (Duel.hlp's "a Done button, a Cancel button, or both,
│    depending on the situation", which Manalink's allow_cancel states as
│    a two-bit spec), a refusal being RED and expiring on its own, the
│    targeting prompt in the original's own `Select target X.` /
│    `(N so far)` wording, and which of @PROMPT_FASTEFFECTS' three frames
│    the chain's top chooses;
│    tests/ui/test_auto_target.gd — the lone counter-target: a counter
│    aimed at the opponent's only chain object casts without opening
│    targeting, two or more do not, and an ordinary removal spell with one
│    legal creature still asks;
│    tests/ui/test_showcase.gd — what fills the big card: the card you
│    just DREW (Duel.hlp, "Showcase"), the top of the chain when nothing
│    is hovered, and the two 1997 right-button gestures that look at a
│    card without playing it;
│    tests/ui/test_duel_sound.gd — the 1997 sound table: a spell sounds
│    like its card TYPE, a land like the COLOURS IT MAKES, a five-colour
│    land is silent, and no spell may ever borrow a land sound again;
│    tests/ui/test_land_art.gd — a land retuned to a basic type wears that
│    land's art (Blood Moon, Evil Presence) and gets its own back when the
│    effect goes;
│    tests/ui/test_life_countdown.gd — the dying total falling over s30's
│    900ms + 500ms, only for a death by damage, idempotently, and one
│    repaint behind the engine so it knows where to count from;
│    tests/ui/test_squeeze_row.gd — a board row shrinking its pitch
│    instead of wrapping, including mixed widths and the last card always
│    showing in full;
│    tests/ui/test_card_menus.gd — the rest of the @MENU_ family (§6.12)
│    and the last live entries of @MENU_TERRITORY (§6.3): every table
│    verbatim and complete, `Count library cards`, `Expand text box`, the
│    three display toggles (ID tags on the card, `all cards'` summoning
│    sickness reaching non-creatures), and Concede asking before it gives
│    up;
│    tests/ui/test_x_dialog.gd — @DIALOG_FIREBALL: the seven strings, the
│    arithmetic that splits one pot of generic between X and the
│    additional-target surcharge, and the bug it fixes (a full-value
│    Fireball at three targets used to be refused);
│    tests/ui/test_spell_flight.gd — the spell-cast animation: what the
│    chain diff decides to fly, that abilities do not, s30's
│    spellIsAnimating board-skip, and that a headless run samples nothing;
│    tests/ui/test_pacing.gd — the three dwell tiers as s30's own ratios,
│    what counts as the board being "stirred", that DuelConfig.pace still
│    means what it meant for the demo and for vs-AI, and that
│    _maybe_schedule_ai still creates exactly one timer;
│    tests/unit/test_damage_packet.gd — damage as an OBJECT (§6.8 slice 1):
│    every DAMAGE_DEALT event carries its DamagePacket, a packet records
│    how much was PREVENTED as well as dealt, ids are never reused, and
│    the Manabarbs merge rule (same source + same victim is one packet);
│    tests/unit/test_damage_window.gd — the 1997 prevention and
│    regeneration steps (§6.8 slice 2), BOTH sides of the fork: damage
│    waiting instead of landing, the restricted allow ("No other kind of
│    fast effects or spells are permitted"), one Circle answering a merged
│    packet, regeneration bought at the moment a creature is about to go
│    to the graveyard, and nothing pausing when the fork is off or no seat
│    asked for the window;
│    tests/unit/test_damage_target.gd — damage as a TARGET (§6.8 slice 3):
│    TargetRef.same_object telling two packets apart, Kind.DAMAGE legal
│    only inside a window, and the Circle of Protection in both rulesets —
│    naming one packet under the fork, putting up its colour shield
│    without it;
│    tests/ai/test_ai_prevention.gd — the AI inside those two windows
│    (§6.8, the ROADMAP row it closed): the Apprentice never opens one and
│    every reactive profile does; the Circle spent on the damage that
│    would KILL it and never on a scratch; the worst packet it can
│    actually REACH rather than the worst packet; the cheapest effect that
│    covers it, so the {1} activation beats the card in hand; a Fog left
│    in hand because it cannot touch a packet already on the table; a
│    Circle refusing a packet aimed at a creature ("to you"); regeneration
│    only for what is already dying, most valuable first; a fumbled window
│    declined; and two seeded duels playing the same windows line for line
│    tests/ai/test_effect_intent.gd — the effect reader on real cards:
│    fixed and X damage, self-damage riders (Artillery, Psionic Blast),
│    removal and whether regeneration answers it (Terror / Swords /
│    Disenchant), the helpful shapes, utility abilities, sweepers kept
│    whole, kills() reading live toughness and marked damage, and an
│    unknown card-local effect treated as removal-shaped;
│    tests/ai/test_ai_capabilities.gd — WHAT THE AI DOES WITH ITS CARDS
│    (2026-09-02, one test per weakness fixed): Rod of Ruin at the X/1,
│    Artillery holding fire at an empty board and shooting a creature it
│    kills, Icy Manipulator in their upkeep, the Tome as the end-step
│    mana sink, Terror held and fired at their end step, the lethal Bolt
│    now, mana kept open for the held removal (and not when nothing needs
│    answering), Skeletons shielding a block but not against Swords,
│    first strike on both sides of combat, the all-in that counts the
│    blocks, the pump in hand sending one more attacker, the Bolt that
│    stops the lethal swing, the pump for exact lethal, removal on the
│    blocker that would eat the Angel, Fireball exactly lethal / exactly
│    the toughness / waiting at twenty, Wrath waiting while our board is
│    bigger, Dark Ritual only into the Specter, the land drop the hand is
│    short of, a land-light hand discarding the spell, the Gargoyle's
│    +0/+1 to survive a block, Unsummon on our own Djinn, and
│    firebreathing that leaves the second main phase its mana unless the
│    breaths are lethal;
│    tests/ai/test_ai_sideboard.gd — AI SIDEBOARDING (M4 phase 2.x): what
│    the memory sees (the opponent's casts, land drops and battlefield
│    arrivals, never our own cards, never a token, copies kept at the
│    per-duel MAXIMUM, damage recorded by colour), how a card's answer
│    profile is read off its oracle text (Terror is not artifact hate,
│    Earthquake is not flying hate, a Serra Angel answers nothing), and
│    THE THREE INVARIANTS by name — the deck's size never moves, the copy
│    limit is counted across both piles, a required format is still legal
│    — plus the profile allowance, the Apprentice's zero, the castability
│    gate, the never-cut-a-land rule and determinism under one seed;
│    tests/ai/test_undo_log.gd — THE SEARCH JOURNAL (M4 phase 3): a
│    make/unmake round trip leaves NOTHING behind, checked against
│    GameSnapshot itself so a field MtgGame fails to record fails by name
│    — one cast, one land, one tap, one attack declaration, a three-move
│    line unwound to its root, a nested mark that must not disturb the
│    move outside it, and THE MOVE MENU: one round trip per kind of move
│    a search makes (pump, burn that kills and burn that does not, burn
│    to the face, a ping, X spells, bounce, exile, destroy, an enchantment
│    and a land leaving, a ritual, a counterspell, recursion, draws, a
│    prevention shield used up, Pestilence, a token, a death trigger);
│    plus the two determinism guards (exploring must not
│    move game.rng, and a game that searched must draw exactly what one
│    that did not draws) and the promise the other 3,000 tests rest on —
│    a duel that never searches never allocates a journal;
│    tests/ai/test_ai_sweep_2026_09_02.gd — THE 2026-09-02 AI BUG SWEEP,
│    one test per finding that FAILED before its fix: the combat
│    REQUIREMENTS the AI never mirrored and wedged the declare steps on
│    (Lure takes every able blocker, a Nettling Imp's order is obeyed,
│    Blaze of Glory's conscript blocks every attacker, the Caverns of
│    Despair caps trim attacks and blocks, and the ladder concedes rather
│    than spins); a Fallen Angel that no longer eats its own board (the
│    free ability gate, the cost ask picking the LEAST valuable body, a
│    sacrifice spell waiting for fodder worth less than itself);
│    Workshop mana never planned for a creature but spent on an artifact;
│    a City in a Bottle ban and a hand lock keeping the lands untapped;
│    protection in the combat maths (a White Knight blocks the black
│    raider for free); colour-aware firebreathing reach; the free
│    untapped ability that no longer fires forever at the sink; Jandor's
│    Ring waiting for a draw; the Artillery keeping its recoil off our
│    own face at the sink; a main-phase activation respecting the held
│    reserve; EffectIntent reading an X pump; a refused cast memoised for
│    the step; one regeneration shield per creature while the first sits
│    on the stack; the counter-hold counting LIVE blue sources under a
│    Phantasmal Terrain;
│    tests/ai/test_ai_targeting_2026_09_04.gd — THE TARGETING AUDIT:
│    WHICH SIDE OF THE TABLE a card is aimed at, and whether a tap is
│    worth buying at all. An AURA has no spell effects, so `_is_harmful`
│    answered from a FOUR-NAME list inlined in itself and the pool's
│    other 73 auras counted as helpful and were aimed at the AI's OWN
│    board — Psychic Venom on its own Island, and 27 more curses nobody
│    had watched yet. The aim is now data (EffectIntent.AURA_HOSTILE) and
│    one test walks the whole registry so a new aura cannot slip in
│    unclassified. A TAP has no value of its own, so a tap SPELL (Twiddle,
│    Word of Binding) now goes through the tap POLICY the AI already had
│    for tap ABILITIES: their untapped creature only, at their upkeep or
│    before our own attack, never a land, never one of ours, never one
│    already tapped, and never for a prize worth less than the card;
│    tests/ai/test_ai_attacks_2026_09_04.gd — WHEN THE AI ATTACKS: the
│    boards, not the win rate. Attack selection was a per-creature RISK
│    filter with no reward term and no idea how many blockers the
│    defender had, so each of four 2/2s asked "does that 3/3 beat you?",
│    heard yes, and the whole team stayed home against a blocker that
│    can eat exactly one of them. One file states the situation and the
│    number of attackers a competent player declares: the empty board,
│    the board whose every creature is tapped, a 0/8 that threatens
│    nobody, the swarm past one blocker and the SAME pair declining when
│    only two of them came, two blockers against three bears (declined)
│    and against eight (declared), fliers over a ground blocker, lethal
│    pushed through a block, a summoning-sick body, a Juggernaut's
│    requirement into a hopeless board, a Giant Growth counted only when
│    the mana is there, their open mana inventing no blockers, and the
│    profile ladder (aggression may only widen an attack, mistakes still
│    leave a body home);
│    tests/ai/test_ai_blocks_2026_09_04.gd — WHAT THE AI SPENDS TO BLOCK,
│    the companion to the same day's attack audit and found the same way:
│    120 whole AI-vs-AI games instrumented, every block decision written
│    out with its board, 1,022 records mined offline. The mining killed
│    three theories (over 98 combats whose unblocked damage was lethal the
│    AI NEVER once had an idle body that could legally have blocked; the
│    tier ladder's first-in-list blocker choice cost exactly one exchange)
│    and named two real faults: the panic line was asked BEFORE the blocks
│    (`life - total attacker power <= chump_threshold`, so a Wizard at 7
│    life facing three power called itself desperate) and the chump rung
│    had no price (49 of the 92 bodies it sacrificed died in a combat it
│    would have survived untouched — a Hypnotic Specter under an Ironroot
│    Treefolk to save 3 life). Both readings now come from numbers the AI
│    already had. The file also pins the attacking half of the same
│    combat: CR 509.2's damage assignment order, which `AiPlayer` never
│    overrode, so a gang block was divided in the DEFENDER's declaration
│    order;
│    tests/ai/test_ai_dead_cards_2026_09_04.gd — THE CARDS THE AI NEVER
│    CAST. Three had never been cast in a logged game; the whole pool was
│    swept instead (all 851 non-land cards offered to the real
│    `_try_cast_best` on a maximally favourable board) and SEVENTY-TWO
│    came back, 39 of them uncastable on any board, in six structural
│    classes (docs/ROADMAP.md). Three classes are closed and pinned here:
│    a `*/*` creature prints 0/0 and was worth 0.0 in hand (or negative,
│    as a `0/*` Wall) against a ranking bar that starts at 0.0; an
│    unclassified card-local effect is ASSUMED removal-shaped and its
│    target picker therefore shopped the wrong side of the table; and a
│    counterspell built from a card-local effect was not recognised as one
│    at all — Power Sink, Mana Drain, Spell Blast and Force Spike, dead
│    cards in hand in a third of the shipped deck pool;
│    tests/ai/test_ai_x_seam_2026_09_05.gd — THE X A SPELL IS BEING CAST
│    FOR, AND THE MANA THE PLANNER USED TO LEAK. Class 4 of the
│    2026-09-04 sweep was a live bug, not just silence: the planner taps
│    its lands and THEN calls cast_spell, so every legality it did not
│    mirror was paid for before it was discovered. The file reproduces the
│    leak on all three cards (Fire and Brimstone's player filter,
│    Detonate's X-dependent target, Orcish Catapult's rolled slot) —
│    untapped lands before and after, and the end-to-end symptom: the pool
│    empties at the step boundary with the card still in hand — then pins
│    the seam that closes it (MtgGame.casting_x answering for a PROPOSED
│    X, target_legal_at / legal_targets_at, cast_refusal agreeing with
│    cast_spell and leaving memory untouched on a refusal, CR 601.2h) and
│    what it makes newly castable: Detonate sized to the artifact it
│    wants, Spell Blast sized to the spell it answers, Howl from Beyond
│    fired as a finisher for the shortfall exactly — with the Apprentice
│    still never countering, so the ladder is untouched;
│    tests/unit/test_fifth_edition.gd — THE 1997 RULESET AS A WHOLE
│    (`rules.set_edition("fifth")` and nothing else, the 2026-09-02
│    audit): mana burn killing on the boundary it is charged on (the
│    defect two forks made together and no single-fork test could see),
│    both seats burning out as a draw, life gained inside a phase still
│    saving a player, a pool that survives a step and burns at the phase,
│    and lethal combat damage answered — or not — inside the window.
│    THE INTERACTIONS, pair by pair (the 2026-09-02 levelling pass, 8
│    tests -> 20): mana floated in combat paying for the prevention
│    window and burning at the end of it, a burn and an unanswered
│    lethal on one boundary as a DRAW, a prevention shield doing nothing
│    about a burn, the free 2/4 split modern rules refuse being exactly
│    what the window holds, trample's own rule under the whole preset, a
│    tapped Gauntlet of Might losing its anthem and keeping its trigger,
│    an Icy'd Forcefield still answering the window (activated abilities
│    are not suspended), first strike's sixth combat step charged once,
│    poison outranking a queued burn, and the finding that
│    `attackers_revocable` has no engine branch at all;
│    tests/unit/test_layer_six_first.gd — LAYER ORDER FOR A PURE SILENCER:
│    a static that silences abilities but changes no type still runs on
│    the early (layer 6) pass, before a base-P/T setter, and is on the
│    battlefield_with_type_statics() index that pass reads;
│    tests/unit/test_cost_records.gd — WHAT A COST ATE, PER ACTIVATION
│    (StackItem.cost_paid): two Life Chisels, two Necropolis feedings and
│    two Land's Edge activations on the stack together, each reading its
│    own payment rather than the last one written;
│    tests/unit/test_one_to_many_blocks.gd — ONE CREATURE BLOCKING SEVERAL
│    ATTACKERS (CR 509.1b): the permission refused where no effect grants
│    it and read live (a face-down Giant loses it), both attackers hitting
│    the one blocker, the blocker dealing its power ONCE across them,
│    Blaze of Glory ordering every block it can make, and the combat
│    collections forgetting a multi-block from either end;
│    tests/unit/test_engine_sweep_2026_09_02.gd — THE 2026-09-02 ENGINE
│    SWEEP, one test per finding, each failing against the code as found:
│    Blaze of Glory's "any number" grant expiring at cleanup; a block
│    declaration, a re-pointed block (set_block) and a removal from
│    combat round-tripping through the search journal, diffed against
│    GameSnapshot the way tests/ai/test_undo_log.gd does; a refused
│    must-block declaration writing no blocks (rule 3);
│    put_from_hand_into_play and pick_from_library (found and fruitless)
│    unwinding hand, library and shuffle; Time Vault's one-in-five rolled
│    once and only after the human seat's hold (rule 7);
│    tests/ui/test_block_picker.gd — the block GESTURE, ordinary and
│    one-to-many: pick-then-aim unchanged for a creature that may block
│    one, a multi-blocker kept in hand for its second attacker, the third
│    refused, and the map the screen builds accepted by the engine;
│    tests/ui/test_block_declaration_2026_09_04.gd — THE BLOCK THAT WAS
│    NEVER DECLARED: a creature picked up and never aimed stands in the
│    Combat window's shield lane looking like a blocker, so Done must put
│    it DOWN and say so rather than declare no blockers (keeping the
│    blocks already made); a creature that can block nothing — a tapped
│    one, a ground creature facing only flyers — is refused at the
│    pick-up instead of being lifted there at all; and the three
│    sentences @PROMPT_DEFENDWHOM speaks (`Block which attacker?`,
│    `Illegal block.`, `That isn't an attacker.`);
│    tests/ui/test_ability_target.gd — CLICKING AN ABILITY ON THE CHAIN
│    (TargetSpec.Kind.ABILITY, which the picker had no case for): the
│    click naming the ACTIVATION and not its source permanent, the
│    counter actually landing, the board widget still being a permanent,
│    and the entry being highlighted only when it is a legal target;
│    tests/unit/test_draw_replacement.gd — the CR 614 draw-replacement
│    subsystem on its own: a one-shot eating exactly one draw and
│    expiring at cleanup, a replaced draw moving no card, firing no
│    CARD_DRAWN and not killing an empty library, the static kind reading
│    its context, the 614.5 re-entry guard that keeps Chains of
│    Mephistopheles terminating, a skipped draw STEP firing no DRAW_STEP
│    at all, and the two bookkeeping fields the cards read
│    (drawn_this_turn, draws_this_step);
│    tests/unit/test_illegal_target.gd — @PROMPT_ILLEGALTARGETWHY's 29
│    reasons verbatim, ONE of them per refusal (the item said they
│    concatenate; every failure site in the 1997 validator is a `goto`),
│    the word each of our own checks reports, that is_legal and
│    refusal_reason can never drift, and MtgGame.concede;
│    tests/ui/test_options_sliders.gd — the Options screen's three sliders
│    write user://settings.cfg ONCE per drag: a tick applies in memory
│    (and reaches the audio bus at once), the file is written when the
│    handle is let go, when focus leaves, or when the screen does;
│    tests/ui/test_options_music.gd — the MUSIC SYSTEM and the PHASE CUE,
│    both from the owner's 2026-09-03 playtest: the original has 27
│    loopable beds and not one, a player file in user://music replaces an
│    imported track of the same name and keeps its readable name, the
│    playlist is whole tracks that loop and CROSSFADE (a single choice is
│    listed twice so its wrap has a seam to fade across), it is capped at
│    8 resident tracks, the window MOVES so a second duel is not the first
│    one again, and nothing imported is silence rather than an error;
│    tests/ui/test_duel_options.gd — @DIALOG_DUELOPTIONS' nineteen strings
│    verbatim, the original's registry key names, and what each switch
│    actually governs (badges, P/T, cue-card tooltips, the coin flip, the
│    end-of-duel next draws, the territory ground);
│    tests/ui/test_coin_toss.gd — the opening toss's three presentations:
│    the 1997 checkbox and the [QoL] three-way are ONE stored value (and a
│    1997 registry 0/1 still reads into it), each mode selects its own
│    path, the video DEGRADES to our animation when the footage is not
│    imported and says why, the movie's frame clock is pure and plays
│    once, the instant badge points at the winning seat's half and names
│    it, the coin lands where the engine decided, and the whole file
│    carries no randomness of its own;
│    tests/ui/test_territory_ground.gd — `Your territory background`, the
│    art half: all nine choices resolve to their own skin key and all
│    fifteen grounds exist WITHOUT the 1997 art and are pairwise
│    different, the three styles are drawn as three different things
│    (tiled / nine-patched / covered), the setting round-trips through
│    Settings, the Duel Options panel and the battle-setup screen's [QoL]
│    pair are two views of ONE value, and only your own half answers to
│    it (Duel.hlp: "You cannot do anything to change the background in
│    your opponent's territory");
│    tests/ui/test_deck_sound.gd — the Deck Builder's bed and its grind:
│    "the first song" is the LIBRARY's order and stable across calls (the
│    random LocMus it replaced would pass a weaker test), an Options track
│    choice still wins, one bed is one looping AudioStreamPlaylist of two
│    entries; the SHIPPED stone_grind.wav is read out of its own RIFF
│    header (mono 22 050 Hz 16-bit, 0.15-0.35 s, first and last frame
│    silent, a real peak between the fades) and loads as a resource from
│    inside the pack; a filter press grinds and the sort button does not;
│    and the switch PRECEDENCE — global off beats screen-on, the two
│    defaults are ON and absent from settings.cfg, unticking either takes
│    effect on the next press;
│    tests/ui/test_title_screen.gd — THE FRONT DOOR, both halves of the
│    2026-09-04 playtest: the shell loops ONE bed (play_one, an
│    AudioStreamPlaylist of the same stream twice so the wrap
│    crossfades), the bed is MENU_BEDS' own head and not the Deck
│    Builder's LocMus1, an Options track choice outranks it, the GLOBAL
│    music switch silences it while the builder's screen-scoped one does
│    not, a partial import falls back down the list in order, an empty
│    library is silence, leaving the screen stops the tune AND drops the
│    PCM, and a headless run makes no voice; plus the splash route pinned
│    as numbers — minimum_display_time is 1000 ms, is <= the ceiling that
│    keeps the game reachable in about two seconds, the image is still
│    the owner's on black, and run/main_scene is still main.tscn (no
│    scene was added ahead of the title screen);
│    tests/ui/test_deck_scroll.gd — the two scroll arrows and the corner
│    count: an arrow at each end running the full height, the bar and the
│    cards both INSIDE them, the triangle MOUSE_FILTER_IGNORE, one press
│    = one step, held = many (and none before ARROW_DELAY), released =
│    none, never past the end, each arrow dead at its own end with its
│    triangle greyed; and the count sized by TALLY_FONT_RATIO x the card,
│    >= 24px, outlined >= 4, and still fitting TALLY_W at 897 cards;
│    tests/ui/test_deck_menu.gd — the Q/Esc menu: the owner's four entries
│    plus the harmless first one, all seven lines inside the slab, one
│    modal blocker under it, and the THREE key transitions kept
│    apart as three tests (Q toggles, Esc closes it, Esc cancels a dialog
│    or the type-ahead FIRST and only then opens it) plus Q over an open
│    dialog and a held key that must not flicker it. Every way out asks
│    about every unsaved slot; the two boxes tick in place and take effect
│    at once. Since 2026-09-04 it also pins the GROUND and the INK
│    TOGETHER — `Winbk_Options` sandstone (the main menu's own texture,
│    not the blue knot it shipped on), UiChrome.INK on UiChrome.SEAT with
│    no outline, ACCENT under the pointer and on the heading — because
│    moving one without the other is how it was unreadable;
│    tests/ui/test_deck_provenance.gd — THE GAME'S OWN DECKS ARE NOT
│    WRITABLE AND NOT SHADOWABLE (manual p.148, *"you must save your
│    version of the deck under a new name"*): every shipped file name AND
│    title is a name the guard knows, case and punctuation cannot slip one
│    past it, and every door that can reach a write refuses it — `Save
│    deck`, the Q/Esc menu's entry, Ctrl+S, `@SAVE` on the way out, and
│    `DeckStore.save` itself as the belt under them. The save becomes a
│    SAVE-AS: the manual's sentence and its page in the dialog, "My
│    Cleric" already in the field, and the saved copy files under
│    DeckGroups.USER while the 1997 file keeps ORIGINALS. Closed with an
│    md5 of all 317 shipped files before and after every door, plus the
│    two doors that are NOT writes (Delete refuses; Export is allowed and
│    lands where no picker looks) and the ROADMAP one-liner that `Import
│    deck` must ask before it replaces the surface;
│    tests/ui/test_deck_filter.gd — the Filter groups' 1997 contract,
│    quoted from the manual: every button starts depressed, additive
│    within a group and exclusive between groups, lands and colourless
│    cards exempt from colour, plus the mini-menus (@LAND's three modes,
│    @ARTIFACT's two toggles) and the @POWER/@TOUGHNESS filters;
│    tests/ui/test_deck_model.gd — the deck's counts, the 1997 limits and
│    Shandalar's duplicate table, the Stats matrix, and the round trip
│    through the .deck format that keeps a saved deck playable — one
│    helper (`_assert_survives`) holds the shipped decks and a
│    PROXY-carrying deck to the same field-by-field yardstick, and the
│    three export formats each round-trip a proxy;
│    tests/unit/test_proxy_card.gd — THE PROXY BOUNDARY, door by door: a
│    proxy never enters the CardRegistry, a strict load refuses it in all
│    three formats and in a sideboard, the Deck Lab refuses a proxy deck
│    by name, and the copy rules DO apply to it (five proxies break the
│    four-of, a proxy Contract from Below is still banned). Also the two
│    ProxyFace sizes and that it is paper rather than a coloured frame;
│    tests/ui/test_deck_builder.gd — the screen: every region and every
│    @DECKSURFACE_STANDALONE command present, add/remove, the paged
│    Inventory, Clear/Restore, Stats, Load, Save, and that the main
│    menu's Deck Builder entry points at a scene that exists; and the
│    audit pass's own bugs — the scroll surviving a card going into the
│    deck, bar and wheel landing on the same page, the window resize,
│    Escape closing a dialog rather than the screen, the @SAVE prompt, a
│    deck naming cards we have not built, and the two efficiency
│    contracts the screen now depends on. **[QoL]** the proxy pass's own:
│    Import (file, pasted list, sniffed .dck, refusals), `Add proxy card`,
│    that the deck area draws a ProxyFace beside a MiniCard, that the
│    Showcase enlarges one — and the SAVE-TIME LEGALITY WARNING, whose
│    first test is that the file is written anyway;
│    tests/ui/test_help_screen.gd — the paged reference: every page
│    renders and shows its title, titles are unique, every QUOTE cites a
│    source, paging cannot run off either end by button or key, the Help
│    button sits DIRECTLY ABOVE Exit, the ShandalarGodot wordmark mirrors
│    the version tag, and — the one that matters most — EVERY ICON ENTRY
│    RESOLVES TO A REAL TEXTURE whenever the 1997 skin is imported, with
│    the badge/filter inventories checked against MiniCard.BADGE_SLOT,
│    PROTECTION_SLOT and FilterBar's own cell maps so a moved cell fails
│    here too;
│    tests/ui/test_set_badges.gd — the title screen's set row: a badge per
│    CardRegistry.SET_ORDER entry in printing order, each tooltipped with
│    its 1997 cue-card name; the SHIPPED lettered row spelled out in full
│    (2nd ARN ATQ LEG DRK 4th Astral PR) with the icons switched off, so
│    the fallback is tested on a machine that HAS the skin; a badge
│    showing its symbol OR its letters and never both (Astral's word
│    yielding to its comet, forced through the symbol cache so it reads
│    the same skinned or not); nothing inside a badge shadowing its own
│    click — the 2026-09-04 dead-letters defect, pinned as the filter
│    invariant because headless Godot has no GUI picking to route a real
│    one through; the raised ordinal proven
│    raised, smaller and inside its own measured box; and the Cardsets
│    slot map cut against a SYNTHETIC 330x15 strip — five differently
│    tinted slots, so a mis-read slot cannot pass — plus a wrong-sized
│    sheet refused and the three symbol-less sets kept off the icon path);
│    tests/unit/test_gauntlet_state.gd — THE RUN, with no screen and no
│    duel: the twenty cap, the `Num opponents` floor, the original's own
│    `(start + round) % n` wrap and that it meets every deck exactly once,
│    a lost match ending the run and the last one won completing it, the
│    session record surviving the match that zeroes the match's own, the
│    ten @GAUNTLET strings verbatim, the four end-of-duel branches, the
│    three next-opponent announcements and which round earns which, the
│    four @GAUNTLETERRORS opponent-deck refusals (and that the
│    wrong-version one can never be chosen), and one seed being one run;
│    tests/ui/test_gauntlet_screen.gd — THE RUN ON SCREEN: a match per
│    round with the Match Size reaching it, the opponent named by its own
│    deck, MatchScreen.match_finished handed up (and a standalone match
│    still ending on its own terms), the session record folded in as each
│    match ends, the round window's lines and its two buttons — ABSENT,
│    not greyed, once the run is over — the Gauntlet Options window
│    against @DIALOG_GAUNTLETOPTIONS entry for entry with no opponent
│    picker anywhere on it plus `Create Deck...` between `Run the
│    gauntlet` and `Exit`, the next-opponent window and that its OK is
│    what puts the match up, an unreadable opponent deck ending the run,
│    YOUR deck refused in @GAUNTLETERRORS' `Player's deck %s is invalid.`
│    words rather than silently swapped for the default (unreadable, a
│    proxy, under forty cards), `<random deck>` drawing only from decks
│    that pass and earning entry 1 when none do, the [QoL] difficulty
│    formula and its five bands, and the title screen's own Gauntlet entry;
│    tests/unit/test_decks_1997.gd — THE 1997 DECKS, PORTED
│    (docs/decks-1997.md): the per-group counts 55/55/25/5/8/9 and
│    76/64/15 pinned, every ported file through the real loader with no
│    parse error and a size inside the duel's limits, its `# group:`
│    matching its folder, its provenance header (source, designer or
│    pilot/event/place, year, tier/enemy/variant), every MicroProse deck
│    strict-loadable and gauntlet-legal, the three non-MicroProse groups'
│    proxy SNAPSHOT — which files are proxy-free and, per name the pool
│    lacks, how many decks want it (meant to fail when one of those cards
│    is implemented) — and the defaults unmoved — all_deck_paths()[0]
│    still Big Green, the pickers' headings in ORDER, the gauntlet's
│    default roster exactly the strict-loadable decks (216), the Deck
│    Lab's default field still five decks and a `--group` reaching into
│    the subfolders for only the proxy-free
│   (tests/unit/test_targeted_triggers.gd, test_delayed_triggers.gd,
│    test_untap_step_choices.gd, test_sibling_targets.gd — the ENGINE
│    features the 2026-09-02 fidelity pass built to lift the ledger:
│    TriggeredAbility.targeting / .modal (a trigger's own target and mode,
│    chosen as it stacks, CR 603.3c-d, fizzling and the no-legal-target
│    removal), the CR 603.7 delayed-trigger queue (fires once or repeats,
│    survives its source and a control change, APNAP slot, journaled
│    memory under a search rewind, pre-flight probe filing one entry,
│    early settlement and its refusals), the untap-step "may choose not
│    to untap" and cap_untaps questions, and EffectBase.helpful()'s
│    sibling-target filter;
│    tests/cards/test_fidelity_2026_09_02_{costs,misc,adverse_targets,
│    sibling_targets,targeted_triggers,delayed_triggers,choices,sources,
│    draws,landwalk,permanents,witch,maggot,flux,vortex,vault}.gd — the CARD
│    pins of the same pass, one file per lifted ledger row group: Sword
│    of the Ages (costs — any number of creatures parked on the hold),
│    Tawnos's Coffin (misc), Arena / Preacher / Cuombajj Witches / Nova
│    Pentacle (targets an OPPONENT chooses), Drafna's Restoration /
│    Gauntlets of Chaos / Glyph of Delusion (sibling targets), the eight
│    triggers that pick their own victim (Oubliette, Halfdane, Dance of
│    Many, Blazing Effigy, Axelrod, Floral Spuzzem, Relic Bind, Erhnam
│    Djinn), Hazezon Tamar / Nafs Asp / Cyclopean Tomb on the
│    delayed-trigger queue, and the choice-funnel lifts (choices: Erosion's
│    "{1} or 1 life", Twiddle's mode, WHICH Tetravites / Forests Tetravus
│    and Wood Elemental take, Natural Selection's order and DONE, the Mana
│    Batteries' "any number" on the cost hold, Mana Flare's type, Magical
│    Hack's and Sleight of Mind's word pairs, Worms of the Earth's "any
│    player" APNAP offer, Mana Vault's CR 504.1 draw order), and the
│    "source of your choice" / "new targets for the copy" lifts (sources:
│    the Circles, Reverse Damage and Jade Monolith naming ONE source and
│    shielding only it, the shared threat ranking, Fork's and Chain
│    Lightning's copies re-aimed slot by slot), the per-type landwalk
│    loss (landwalk: Urborg's swampwalk, Scarwood Hag's forestwalk, Hammerheim
│    still all), and the draw/discard lifts
│    (draws: Jandor's Ring's last-card-drawn cost, Land Tax's single
│    shuffle and `@LANDTAX` prompts, Library of Leng's discard-to-library
│    for an effect's discard only — cost discards untouched, Psychic
│    Purge still bites, Leng + Wheel keeps a hand — and Ring of Ma'rûf
│    replacing the next draw), and the permanents batch (permanents:
│    Earthbind's intervening if on an Aura that enters attached,
│    Artifact Ward letting an artifact SPELL through, Field of Dreams'
│    public library tops and their log lines, Firestorm Phoenix's
│    revealed-and-locked hand card through both turn orders), Season of
│    the Witch's declare-attackers census (witch), Takklemaggot's
│    victim-chosen jumps and non-Aura return (maggot), Energy Flux's
│    per-artifact granted upkeep trigger (flux), Mana Vortex's own cast
│    trigger and optional land (vortex), and Time Vault's skip-the-turn
│    question as the turn begins with the turn skipped whole (vault); the
│    untap locks and "may choose not to untap" cards are pinned in
│    tests/unit/test_untap_step_choices.gd;
│    tests/cards/test_fidelity_2026_09_02_{astral,bands_with_other,
│    combat_rearrangement,drain_life,guardian_angel,personal_incarnation}.gd
│    — the later rows of the same pass: the ASTRAL set's random targets and
│    random effects (TargetSpec.at_random, rolled as the spell stacks),
│    "bands with other [quality]" (CR 702.22c's second form — the five
│    Legends banding lands granting their colour's legends, and Master of
│    the Hunt's Wolves granting themselves, where both used to be plain
│    BANDING; the band a keyword could not make, the Wolf that is only
│    somebody else's one keywordless member, and the CR 702.22j blocking
│    division), Camouflage / False Orders / Raging River as the PLAYERS'
│    choices, Drain Life's black-only X (CardData.with_colored_x), Guardian
│    Angel's paid prevention on the seat (MtgGame.pay_for_prevention) and
│    Personal Incarnation's metered one-point redirect;
│    tests/cards/test_fidelity_2026_09_02_sweep.gd — the 2026-09-02
│    read-only bug sweep's fixes: Lesser Werewolf re-checking its power as
│    each held activation RESOLVES (CR 608.2c), the three "for as long as
│    this remains tapped" cards (Ashnod's Battle Gear, Tawnos's Weaponry,
│    Phyrexian Gremlins) whose effect ends for good on the first untap
│    and never resumes on a later tap (CR 611.2b), Tawnos's Coffin's one
│    record per activation (re-activated in response to its own release,
│    releasing the FIRST prisoner, everyone on leaving, one release per
│    untap — CR 603.7b), Fork's copy carrying the original's cast-time
│    memory and cost record (a forked Sacrifice adds the same six black,
│    CR 707.10), Halfdane borrowing a NEGATIVE power (the `exact` switch
│    on ContinuousEffects.add_until_eot_base_pt), Spitting Slug blocking
│    two attackers under Blaze of Glory hearing "blocks" once (CR
│    509.1h), and the Scryfall reminder text pinned on Scarwood Hag and
│    Master of the Hunt)
│
├── game/                    ← PRESENTATION LAYER (playable duels, 3 modes)
│   ├── main.tscn / main.gd  Title: 6 stone buttons center-right over the
│   │                          original title art — Magic Battle /
│   │                          Gauntlet / Deck Builder / Options / Help /
│   │                          Exit (Gauntlet is @SHELLSCREEN_DUEL entry
│   │                          2, directly under `1Solo &Duel`, carrying
│   │                          that entry's own description as its
│   │                          tooltip; the Deck Builder entry is
│   │                          @SHELLSCREEN_TOOLS's own label; Help opens
│   │                          game/help/ and sits directly above Exit). Two matched CORNER
│   │                          LABELS share _corner_label(): the
│   │                          `ShandalarGodot` wordmark bottom-left and
│   │                          the version/card-count tag bottom-right,
│   │                          same parchment ink and 1px shadow, both
│   │                          anchored so they follow the window. The
│   │                          SET BADGES sit UNDER the wordmark in that
│   │                          same bottom-left column, on a UiChrome stone
│   │                          plaque. MUSIC since 2026-09-04 (the owner's
│   │                          playtest, "a suitable soothing music at the
│   │                          main menu"): a MusicPlayer child looping ONE
│   │                          bed via play_one, MENU_BEDS-headed by
│   │                          music_location_15. [QoL] — the 1997 shell
│   │                          played NO music (Provenance.md, "The shell
│   │                          screen's audio"); the bed was chosen by
│   │                          MEASURING all 27 (transients/s, spread,
│   │                          zero-crossing rate) because nobody here can
│   │                          hear it, and it is ONE LINE to change. Not the
│   │                          Deck Builder's LocMus1, so crossing between
│   │                          the two screens is not the same tune
│   │                          restarting. Respects the global music switch;
│   │                          _exit_tree and _open both stop it, so the next
│   │                          screen starts against silence
│   ├── set_badges.gd        class SetBadges — THE CARD POOL, said in one
│   │                          row, and since 2026-09-03 each badge is
│   │                          CLICKABLE: `set_clicked` carries the code to
│   │                          the shell, which opens the set's own window
│   │                          (facts_for/describe/cards_here, data in
│   │                          cards/data/sets.json).
│   │                          A badge per CardRegistry.SET_ORDER
│   │                          entry, a 1997 expansion symbol where the
│   │                          original drew one and LETTERS where it did
│   │                          not. The letters are what ships (no
│   │                          original art is in this repo), so the
│   │                          skinless row reads `2nd ARN ATQ LEG DRK
│   │                          4th Astral PR` — short forms from
│   │                          GameSkin.set_label, full names from
│   │                          DeckFilter.SET_LABELS in the tooltips, and
│   │                          Astral NAMED because `PAST` is a code, not
│   │                          a word — a FALLBACK only: a badge shows a
│   │                          symbol or letters, never both, so a
│   │                          skinned Astral is the comet alone
│   │                          (2026-09-04). Symbols come from the
│   │                          original's own Cardsets strip (330x15, five
│   │                          66-wide slots, each a 33x15 image half and
│   │                          its mask; drk/leg/arn/atq/past left to
│   │                          right) and fall back to the DBArt
│   │                          set_icon_<code> medallions; both are
│   │                          cropped to their ink so the row weighs
│   │                          evenly. Inner Glyph and Lettered draw
│   │                          themselves — Lettered asks the FONT for its
│   │                          baseline so `4th`'s ordinal rides the cap
│   │                          line in any face without clipping, and both
│   │                          are MOUSE_FILTER_IGNORE so the click
│   │                          reaches the badge that listens for it (a
│   │                          bare Control defaults to STOP, which is
│   │                          what killed the lettered badges until
│   │                          2026-09-04)
│   ├── setup_screen.gd/.tscn  Battle setup — the whole of the original's
│   │                          own pre-duel screen (@SHELLPAGE_MULTIDUEL,
│   │                          Text.res:2852): mode (hotseat / vs AI /
│   │                          AI-vs-AI demo), per-seat deck / name / life
│   │                          / difficulty, demo pace, and the 1997
│   │                          parameters — `<random deck>` (:2866) as the
│   │                          deck list's first row, the five FORMATS
│   │                          (DeckFormat) with the Options screen's
│   │                          tooltip+`?` pattern, `Match parameters`
│   │                          (:2860) = `&Ante` / `&Free play` vs
│   │                          `&Best of:` / `Side&board between duels`.
│   │                          Each seat shows its DUELIST'S FACE, the
│   │                          same 120x88 portrait the duel's life
│   │                          register flips to. [QoL] a SEED box (blank
│   │                          = roll one) — ours; 1997 had none. [QoL]
│   │                          `Your territory background` — the Duel
│   │                          Options panel's own two lists (colour x
│   │                          style) with a live preview at the board
│   │                          half's aspect, in a place the original had
│   │                          none; ONE control for both seats and ONE
│   │                          value with the panel, via DuelOptions
│   │                          Builds a DuelConfig; free play goes to the
│   │                          duel screen, a match to MatchScreen.
│   │                          Scans DeckStore.all_deck_paths(), so decks
│   │                          saved in the Deck Builder are playable, and
│   │                          groups the list by DeckGroups
│   ├── deck_groups.gd       class DeckGroups — WHERE A DECK CAME FROM,
│   │                          the heading it appears under in the deck
│   │                          list. `User-created` is DERIVED from the
│   │                          path (a file may not claim to be a 1997
│   │                          original); the rest DECLARE themselves with
│   │                          a `# group:` line, which rides as a comment
│   │                          DeckList already skips — so every deck file
│   │                          written before this still loads. Four
│   │                          groups at first: the owner's three plus
│   │                          `Starter decks`, because this project's own
│   │                          five are neither 1997's nor the
│   │                          expansion's; eleven since 2026-09-02 —
│   │                          Spells of the Ancients, the three "Play
│   │                          Deck" designers, one per wiki group, then
│   │                          `Tournament decks`, `Community decks` and
│   │                          `Extended community decks`, the
│   │                          non-MicroProse decks split three ways
│   │                          (docs/decks-1997.md).
│   │                          `raw_in` returns the declaration VERBATIM
│   │                          (recognised or not) for the one caller that
│   │                          must not judge — the Deck Builder carries the
│   │                          line through a load and a save untouched;
│   │                          `declared_in` is what MEANS something
│   ├── match_screen.gd/.tscn  class MatchScreen — `&Best of:` running: one
│   │                          DuelScreen per duel, MatchState keeping the
│   │                          record, and the original's between-duels
│   │                          window (@DIALOG_ENDEXP1DUEL* —
│   │                          `Side&board...`, `&Edit deck...` greyed,
│   │                          `&Continue match`, `&Quit match`). Each
│   │                          duel's seed is drawn from the match's, so a
│   │                          match replays whole. The Sideboard... window
│   │                          swaps between deck and `SB:` pile with the
│   │                          deck size preserved (OUR rule — no source
│   │                          states one; marked in the file).
│   │                          `match_finished` + `reports_to_owner` let a
│   │                          GauntletScreen take the match's last word —
│   │                          the only change the gauntlet needed here
│   ├── audio.gd             class GameAudio — THE MIXER: the "Music" and
│   │                          "SFX" audio buses and the settings behind
│   │                          them. Volume/mute live on a BUS, not on a
│   │                          player, so an Options slider reaches a duel
│   │                          already running. set_hushed() is the duel's
│   │                          `M` key — a session silence that never
│   │                          writes a preference. Faithful shape: the
│   │                          1997 mixer was per-sound-ID single-voice
│   │                          and polyphonic ACROSS ids (MAGSND.DLL's
│   │                          IsSndLoaded/GetLRUSnd slot table). Carries
│   │                          the "NOT A PHASE CUE" ruling: a phase
│   │                          change is SILENT and every sound must be
│   │                          traceable to an ACTION, so EndPhase.wav
│   │                          (WAV_ENDPHASE, a real 1997 file) is
│   │                          deliberately not imported
│   ├── music_library.gd     class MusicLibrary — EVERY TUNE THE GAME CAN
│   │                          PLAY. The original's 27 loopable beds
│   │                          (Dueltune, LocMus0..19, Tmplmus1, five
│   │                          castles) plus user://music/*.{wav,ogg,mp3},
│   │                          the player's own — same search order and
│   │                          same byte-level loading as PortraitLibrary,
│   │                          and it writes the README that documents the
│   │                          format. Owns `music_choice` (shuffle / the
│   │                          1997 single bed / one named track).
│   │                          Deliberately UNCACHED: 27 tracks are 76 MB.
│   │                          `single_for(candidates)` is the answer for a
│   │                          screen that loops ONE bed (the Deck Builder,
│   │                          2026-09-04): the player's chosen track when
│   │                          they picked one, else the first candidate
│   │                          they actually have IN THIS LIBRARY'S OWN
│   │                          ORDER — stable across runs, which a
│   │                          shuffle's first track is not.
│   │                          `deck_builder_beds()` is LocMus1..19,
│   │                          deckdll.cpp:2047's own inclusive range
│   ├── music_player.gd      class MusicPlayer — THE PLAYLIST on the Music
│   │                          bus. Whole tracks through an
│   │                          AudioStreamPlaylist (loop + crossfade, so
│   │                          the seam cannot click), capped at
│   │                          MAX_TRACKS=8 resident; the shuffle and the
│   │                          place in it are STATIC, so a duel ending
│   │                          does not restart the music. Replaced one
│   │                          10-second WAV with LOOP_FORWARD patched on
│   │                          (2026-09-03, the owner's playtest). Silent
│   │                          headless. `play_one(id)` is the SINGLE-BED
│   │                          mode the Deck Builder uses: one track, keyed
│   │                          like play_key so re-applying a switch does
│   │                          not restart it, listed twice inside the
│   │                          playlist so even a one-track loop wraps on a
│   │                          crossfade instead of a click
│   ├── options_screen.gd/.tscn  Options ([QoL] — 1997 had no options
│   │                          screen): Music and Sound Effects switches
│   │                          (the deck builder's mini-menu carries the
│   │                          same two keys), music/sfx volume sliders
│   │                          (ours — 1997 had no volume anywhere), the
│   │                          MUSIC picker (MusicLibrary: shuffle, the
│   │                          1997 single bed, or one named track — and
│   │                          it creates user://music/ with its README),
│   │                          hand
│   │                          display, the rules forks, AI pace — an
│   │                          AGGREGATOR over Settings, never a copy
│   ├── settings.gd          class Settings — user://settings.cfg wrapper;
│   │                          saved on every set, except set_value(...,
│   │                          false) + flush() for a slider's drag
│   ├── ui_chrome.gd         class UiChrome — the original sandstone panel
│   │                          (Winbk_Options 9-patch) + era buttons/labels;
│   │                          ONE place for the game's window look
│   │                          (player-facing summary of every path:
│   │                          docs/player-files.md)
│   ├── portrait_library.gd  class PortraitLibrary — THE PLAYER'S OWN FACE
│   │                          (the duelist above it is DERIVED from the
│   │                          deck's colour; this one is CHOSEN). Scans
│   │                          user://portraits, then the imported skin's
│   │                          portraits/, then res://assets/original/
│   │                          portraits/ — first wins, so a player's own
│   │                          file replaces an imported one. Reads bytes
│   │                          (Image.load_from_file), so art dropped in
│   │                          after shipping works in an export; writes
│   │                          the README that documents the format.
│   │                          Chosen per seat in setup_screen, stored BY
│   │                          ID; nothing in a duel reads it yet (M5)
│   ├── duel/versus_panel.gd class VersusPanel — THE MARBLE VERSUS BOARD,
│   │                          and the one copy of it: Winbk_Versus
│   │                          (500x400, wells 162x192 at (50,59)/(281,59)
│   │                          — measured), a portrait in each well, "vs."
│   │                          between, the pale seat lettering, an
│   │                          optional title in the 59px band above the
│   │                          wells, and portrait_for (chosen portrait,
│   │                          else the deck-coloured duelist face). NO
│   │                          clock lives here — see DuelPause
│   ├── duel/duel_intro.gd   class DuelIntro — THE PRE-DUEL SPLASH, between
│   │                          "Go" and the coin toss as the original has
│   │                          it: a VersusPanel with both duelists'
│   │                          "playing with <deck>" lines. Leaves on Go!,
│   │                          on Reconfigure duel (back to the setup
│   │                          screen) or after 5 s, which is what keeps an
│   │                          AI demo moving
│   ├── duel/duel_pause.gd   class DuelPause — THE PAUSE WINDOW (Q / Esc),
│   │                          [QoL] 2026-09-03: the same VersusPanel
│   │                          marble titled "Pause", with Return to game /
│   │                          Concede duel / Exit duel / Return to main
│   │                          menu / Exit game across the band below the
│   │                          wells. Reports the choice and does none of
│   │                          it; DuelScreen acts. NO timer — and while it
│   │                          is up the duel really stands still (it
│   │                          counts as a modal, and the AI's pacing
│   │                          dwell neither arms nor fires)
│   ├── skin.gd              class GameSkin — runtime loader for the
│   │                          original-graphics skin (user://original_skin
│   │                          then res://assets/original); every accessor
│   │                          null-falls-back to the clean built-in look.
│   │                          region(key, Rect2i) is the generic cached
│   │                          sheet cutter for the sheets that have no
│   │                          decoder of their own (the Phase/Combat Bars'
│   │                          published active_region, Target.pic's frame
│   │                          strip) — added for the Help screen, which
│   │                          must not reach into another screen's
│   │                          private art code.
│   │                          card_art (and card_scan through it)
│   │                          GENERATES MIPMAPS since 2026-09-04: a
│   │                          ~582x467 Scryfall crop drawn at ~110px is a
│   │                          5:1 minification and moiréd without a chain
│   │                          (card-states.md §5.6). +33% memory per art
│   │                          actually drawn; MiniCard._art is the only
│   │                          thing that asks for the chain
│   │                          (TEXTURE_FILTER_LINEAR_WITH_MIPMAPS), so
│   │                          every other user still draws mip 0. The
│   │                          1997 SHEETS deliberately get none — they
│   │                          are sliced by pixel and drawn near native
│   ├── help/                THE HELP SCREEN — the main menu's Help button
│   │   │                      (directly above Exit). The 1997 game had a
│   │   │                      printed manual and a context-sensitive
│   │   │                      "Dueling Help" reached by right-clicking the
│   │   │                      table (manual p.14/112); we have neither, so
│   │   │                      this is the front door for both
│   │   ├── help_screen.gd/.tscn  class HelpScreen — the RENDERER: 24 pages
│   │   │                      on the menu's own UiChrome stone panel,
│   │   │                      turned with ◀/▶, Left/Right, PageUp/PageDown
│   │   │                      and Home/End (read in _input and marked
│   │   │                      handled, so a focused button's arrow-key
│   │   │                      navigation cannot eat a page turn), clamped
│   │   │                      at both ends, Escape back to the menu. The
│   │   │                      body is centred and capped at
│   │   │                      MAX_TEXT_WIDTH; the ground is `Menubak.pic`
│   │   └── help_pages.gd    class HelpPages — the CONTENT, as pure data
│   │                          (title + blocks; TEXT / QUOTE / HEADING /
│   │                          ICONS), so it is testable without a scene.
│   │                          Every QUOTE names its source — the 1997
│   │                          manual by printed page, a `Duel.hlp` topic,
│   │                          or a `@CUECARD_*` string — and unquoted
│   │                          prose is ours. Every ICON entry resolves its
│   │                          texture through THE SAME accessor the screen
│   │                          it documents draws with (ManaIcons.symbol,
│   │                          MiniCard.badge_from_slot/stripe_texture/
│   │                          masked_sprite, PhaseBar/CombatBar
│   │                          active_region, FilterBar.sheet_cell,
│   │                          GameSkin.set_icon), so a cell map that
│   │                          drifts fails the help test at the same
│   │                          moment it breaks that screen. The word
│   │                          "interrupt" is banned here per
│   │                          glossary-1997.md §5 and a test enforces it
│   ├── deck_builder/        THE DECK BUILDER (@SHELLSCREEN_TOOLS: "Deck
│   │   │                      Builder: Build or Modify decks."). The 1997
│   │   │                      original was its own module (Deckdll.dll), so
│   │   │                      the sources are its ART (tools/
│   │   │                      import_original.py), its STRING TABLES and
│   │   │                      the manual's ch.10 "Building Your Decks";
│   │   │                      s30's game/screens/edit_deck.go is the
│   │   │                      structural reference. Full rationale is in
│   │   │                      deck_builder_screen.gd's header
│   │   ├── deck_builder_screen.gd/.tscn  class DeckBuilderScreen — the
│   │   │                      screen, STYLED TO THE OWNER'S 1997
│   │   │                      SCREENSHOT (duel-screen-design.md,
│   │   │                      thirty-fourth pass): navy Dektile4 ground
│   │   │                      everywhere, Deck Header on Dektit1, Showcase
│   │   │                      = a docked CardPreview over a pale status
│   │   │                      bar, the quilted Deck area, the command bar
│   │   │                      along the BOTTOM of that area (Stats (N
│   │   │                      cards) | Deck | Deck1/2/3 | Done), one row of
│   │   │                      filter medallions, Inventory on Dekbar1.
│   │   │                      @DECKSURFACE_STANDALONE is the deck
│   │   │                      surface's right-click mini-menu, which the
│   │   │                      `Deck` button also opens. Every region is
│   │   │                      laid out from the current size, so the
│   │   │                      screen follows the window; Escape closes the
│   │   │                      front-most dialog before it closes the
│   │   │                      screen; @SAVE asks before New deck / Load
│   │   │                      deck / Exit throw a modified deck away; the
│   │   │                      Load list offers Delete on the player's own
│   │   │                      decks (never on the ones the game ships).
│   │   │                      **[QoL]**, all marked as such in the file and
│   │   │                      in the mini-menu: three in-memory DECK SLOTS
│   │   │                      behind the screenshot's Deck1/2/3, one-step
│   │   │                      UNDO, ADD BASIC LAND, DECK NOTES, EXPORT to
│   │   │                      .dec/.dck, the Stats window's colour / type /
│   │   │                      land graphs and average cost, and Ctrl-key
│   │   │                      shortcuts. SECOND AUDIT PASS: every dialog is
│   │   │                      now one-at-a-time and MODAL (`_show_dialog`
│   │   │                      puts a full-screen blocker under it — clicks
│   │   │                      that missed the panel used to reach the
│   │   │                      cards); `Save deck` takes a continuation and
│   │   │                      runs it only once the file is written (@SAVE's
│   │   │                      "Yes" used to discard the deck before
│   │   │                      @DECKEXISTS was answered); Exit walks EVERY
│   │   │                      slot with unsaved work. Two 1997 commands
│   │   │                      recovered from the tags beside
│   │   │                      @DECKSURFACE_STANDALONE: `Extra Cards`
│   │   │                      (@EXTRACARDSDIALOG — "Remove Extra Cards" cuts
│   │   │                      every stack to Shandalar's allowance) and
│   │   │                      `Move by color out of deck`
│   │   │                      (@DECKSURFACE_ADVENTURE + @GROUPMOVE's
│   │   │                      picker). More **[QoL]**: `Filters`
│   │   │                      (@LONGLIST's Select All / Clear All),
│   │   │                      `Copy deck to` (fork a slot), a CLICKABLE
│   │   │                      legality line that opens whichever dialog
│   │   │                      answers it, and Escape clearing the type-ahead
│   │   │                      before it leaves the screen. THIRD AUDIT
│   │   │                      PASS: a **[QoL]** SIDEBOARD STRIP — a third
│   │   │                      CardArea carved out of the deck area's bottom
│   │   │                      (7x5 -> 7x4 slots at 1280x800), on the
│   │   │                      Inventory's teal field, named `Sideboard (N)`
│   │   │                      on its own bar row, every tile wearing an
│   │   │                      `SB` plate. Cards cross by SHIFT-click or by
│   │   │                      drag in either direction (`_dropped_on_*`
│   │   │                      routes by the payload's source), each move is
│   │   │                      one undo step, and the mini-menu's
│   │   │                      `Sideboard` entry says how and moves the pile
│   │   │                      in bulk. The Stats window gained the deck
│   │   │                      TYPE the 1997 title bar showed (ManaLink 1.3
│   │   │                      Readme) and the sideboard listing.
│   │   │                      THE 2026-09-04 PLAYTEST added five things,
│   │   │                      all **[QoL]**: the bed is now ONE track
│   │   │                      looped (MusicLibrary.single_for over
│   │   │                      deck_builder_beds() — the library's own
│   │   │                      first, never the shuffle's, and an Options
│   │   │                      track choice still wins) instead of a random
│   │   │                      LocMus through play_key; a `Load` button on
│   │   │                      the command bar, and a `From disk…` door out
│   │   │                      of the Load list to any file on the machine
│   │   │                      (`_open_deck_file_browser`, shared with
│   │   │                      Import) that refuses in a WINDOW naming the
│   │   │                      parser's own reasons (`_refuse_file`) and
│   │   │                      treats a file with no cards in it as a
│   │   │                      refusal rather than a silent wipe; the Q/Esc
│   │   │                      MENU on MENU_PANEL (`panel_stone`, the main
│   │   │                      menu's own `Winbk_Options` sandstone)
│   │   │                      (MENU_ENTRIES + MENU_SWITCHES, modelled on
│   │   │                      DuelPause down to the harmless first entry
│   │   │                      holding focus) — Esc cancels a dialog or the
│   │   │                      type-ahead FIRST and only opens the menu with
│   │   │                      nothing pending, Q toggles unconditionally on
│   │   │                      a layer of its own (210/209), and both ways
│   │   │                      out walk `_confirm_discard_all`; and this
│   │   │                      screen's own SFX/music boxes on that menu
│   │   │                      (see deck_audio.gd). `_slab_line` letters it
│   │   │                      in UiChrome.INK on its pale seat, ACCENT
│   │   │                      under the pointer, and `_menu_heading` puts
│   │   │                      the title in the BODY because
│   │   │                      OriginalDialog.create's own title is the
│   │   │                      PALE voice. It shipped 2026-09-04 on
│   │   │                      `panel_knot`, lettered pale-with-an-outline
│   │   │                      to survive the pattern, and the owner still
│   │   │                      could not read it — the ground was wrong,
│   │   │                      not the ink. `_seat_on_sandstone` keeps the
│   │   │                      SKINLESS fallback light too, since
│   │   │                      OriginalDialog's own is near-black.
│   │   │                      **PROVENANCE**: `_save_deck` sends a shipped
│   │   │                      NAME to `_save_under_a_new_name` — the
│   │   │                      manual's p.148 rule, the refusal, and a
│   │   │                      working name pre-filled in Deck Info (which
│   │   │                      now takes a `reason` and a `suggested`);
│   │   │                      `_open_import_dialog` asks `_confirm_discard`
│   │   │                      first, the last door that could lose a deck
│   │   ├── deck_audio.gd    class DeckAudio — **THE DECK BUILDER'S OWN
│   │   │                      SOUND**, and the two switches that silence
│   │   │                      it. The 1997 deck surface loaded five
│   │   │                      MAGSND slots and no more (deckdll.cpp:2040-
│   │   │                      2056: music 1, Draw 2, Discard 3, Button 4,
│   │   │                      a cancel cue 5 that has no file in either
│   │   │                      sound folder and is therefore not played) —
│   │   │                      so CUE_ADD/CUE_REMOVE/CUE_BUTTON are those
│   │   │                      three, fired from `_add_one`, `_remove_one`
│   │   │                      and `_run_command`. CUE_FILTER is OURS:
│   │   │                      stone_grind.wav, played by FilterBar on the
│   │   │                      medallion PRESS (not on `changed`, which the
│   │   │                      sort menu also emits). A four-voice pool
│   │   │                      grown lazily, `recent` as the device-free
│   │   │                      test seam, silent headless. `deck_builder_sfx`
│   │   │                      / `deck_builder_music` are SCREEN-scoped and
│   │   │                      ANDed with the global switches — global off
│   │   │                      always wins — and `_store` CLEARS a key that
│   │   │                      goes back to its default instead of writing
│   │   │                      the default in
│   │   ├── stone_grind.wav  the filter buttons' cue: 0.250 s, 22 050 Hz,
│   │   │                      mono, 16-bit PCM, trimmed and faded from the
│   │   │                      owner's own sample. **The only sound this
│   │   │                      project ships** — it goes under game/ (like
│   │   │                      boot_splash.png) because assets/ is excluded
│   │   │                      from the .pck. Source, licence and the exact
│   │   │                      transform: Provenance.md, "Our own assets"
│   │   ├── deck_model.gd    class DeckModel — the deck under construction:
│   │   │                      name->count, add/remove refusals, the 1997
│   │   │                      limits (@TOOFEWCARDS 40, @TOOMANYCARDS
│   │   │                      200 unique/500 total), Shandalar's
│   │   │                      size-scaled duplicate allowance as ADVICE
│   │   │                      (the Deck Builder never enforced a four-of
│   │   │                      rule), the @STATSSCREEN matrix + mana curve,
│   │   │                      Sort-deck order and the .deck text it saves.
│   │   │                      **[QoL]** `notes` (free text, written as
│   │   │                      `# note:` lines that DeckList already skips,
│   │   │                      so a noted deck loads in every older reader),
│   │   │                      `to_dec_text` / `to_dck_text` (the two export
│   │   │                      formats) and `average_cost` / `type_counts` /
│   │   │                      `land_ratio` (what the Stats window graphs).
│   │   │                      `extra_copies` / `trim_duplicates` are
│   │   │                      @EXTRACARDSDIALOG's list and its action;
│   │   │                      `remove_by_color` is @GROUPMOVE's. `names()`
│   │   │                      decorates before it sorts (4.2 ms -> 0.5 ms on
│   │   │                      200 unique cards, and refresh() pays it on
│   │   │                      every card click). THIRD AUDIT PASS: the
│   │   │                      SIDEBOARD (`sideboard`, a second name->count
│   │   │                      pile with add_side/remove_side/to_sideboard/
│   │   │                      to_deck) and the carried `group` line, and
│   │   │                      `to_text` writes BOTH — until then it wrote
│   │   │                      neither, so loading a deck with a sideboard
│   │   │                      or a `# group:` heading and saving it
│   │   │                      destroyed them (tests/ui/test_deck_model.gd
│   │   │                      round-trips a shipped deck field by field).
│   │   │                      Copies are counted across BOTH piles
│   │   │                      (`copies_of`), so the duplicate advice and
│   │   │                      `trim_duplicates` see a card the sideboard
│   │   │                      alone pushes over; `SIDEBOARD_SIZE` = 15 is
│   │   │                      **modern Magic's convention, not a 1997
│   │   │                      rule**, and is advice (`sideboard_advice`)
│   │   │                      rather than a refusal
│   │   ├── deck_filter.gd   class DeckFilter — the four Filter groups'
│   │   │                      logic, ported from s30's collectionFilter
│   │   │                      with the ORIGINAL's polarity (every button
│   │   │                      starts DEPRESSED = on); additive within a
│   │   │                      group, exclusive between groups, lands and
│   │   │                      colourless cards exempt from colour. Also
│   │   │                      the mini-menus the string table spells out:
│   │   │                      @LAND (Land and Mana / Land only / Mana
│   │   │                      only — the Land button reaches every mana
│   │   │                      source, not just lands), @ARTIFACT (All
│   │   │                      Creatures / All Non-Creatures), @GOLD,
│   │   │                      @CASTCOST, and the @POWER / @TOUGHNESS
│   │   │                      filters. `revision` counts real changes so
│   │   │                      the screen re-walks 800 cards only when the
│   │   │                      filter moved; `OWED` lists the sub-filters
│   │   │                      our card data cannot answer yet.
│   │   │                      `select_all` / `clear_all` are @LONGLIST's own
│   │   │                      two, and the way back from twenty-three
│   │   │                      toggles. `_facts_for` caches each card's
│   │   │                      folded name, colour mask and four sort ranks
│   │   │                      for the life of the process and the colour /
│   │   │                      type groups match on BIT MASKS rebuilt with
│   │   │                      `revision`: filtering the pool went 4.0 ms ->
│   │   │                      2.2 ms and `apply` 6.4 -> 3.5. The pool is
│   │   │                      sorted ONCE per sort order and kept
│   │   │                      (`_pool_in_order`), so `apply` splits the
│   │   │                      survivors instead of sorting them (3.5 ->
│   │   │                      2.3 ms); the `sort_key` the old comparator
│   │   │                      used was left behind unused by that change
│   │   │                      and has been deleted
│   │   ├── filter_bar.gd    class FilterBar — those groups as the 1997
│   │   │                      screenshot draws them: ONE unlabelled row of
│   │   │                      sprite_sheet medallions (colours, sets,
│   │   │                      types, Gold, Casting Cost, Power, Toughness),
│   │   │                      groups told apart by a wider gap and named
│   │   │                      through `group_names()` and the cue cards.
│   │   │                      ON is the plain medallion, OFF the dark
│   │   │                      `_pressed` one — no tint — and those two are
│   │   │                      bound to `normal`/`pressed` ONCE, which is
│   │   │                      what gives a held toggle its press sprite:
│   │   │                      Godot draws a latched button in the box of
│   │   │                      the state it is about to become. A
│   │   │                      right-click on a button that has one emits
│   │   │                      menu_requested and
│   │   │                      the screen puts up the mini-menu. TYPE_CELL's
│   │   │                      header records how the screenshot moved
│   │   │                      Enchantments to (1,3) and Sorceries back to
│   │   │                      (2,6), and why the gold ring is the
│   │   │                      discriminator. **[QoL]** the tail of the row
│   │   │                      carries the type-ahead, a switch that lets it
│   │   │                      read card TEXT, and the Inventory's Sort. A
│   │   │                      medallion with NO sub-menu of its own answers
│   │   │                      a right-click with @LONGLIST's Select All /
│   │   │                      Clear All (`open_all_menu`)
│   │   ├── card_area.gd     class CardArea — the Deck area and the
│   │   │                      Inventory area, one widget twice: a PAGED
│   │   │                      grid of MiniCards (s30's ScrollableList
│   │   │                      renders only its visible window, and so does
│   │   │                      this — 788 MiniCards at once would be ten
│   │   │                      thousand nodes), count badges, hover feeds
│   │   │                      the Showcase, drag-and-drop between
│   │   │                      surfaces. The page's widgets are REBOUND as
│   │   │                      it scrolls, never rebuilt, and `_rotate_cells`
│   │   │                      then SLIDES them along so only the cards that
│   │   │                      are actually new get a MiniCard.refresh (a
│   │   │                      deck-area wheel notch: 11.8 ms -> 5.9,
│   │   │                      the Inventory's 1.3 -> 0.3); the flow follows
│   │   │                      the scroll bar (rows down the side, columns
│   │   │                      along the bottom) and both bars count whole
│   │   │                      steps, so wheel, bar and keyboard always
│   │   │                      agree. `slot_plaques` lays the 1997 carved
│   │   │                      mana watermarks under the Deck area's grid
│   │   │                      (drawn in _draw, so the quilt costs no
│   │   │                      nodes). EVERY surface is 1:1 — the deck
│   │   │                      area's 0.85 `card_scale` came out in the
│   │   │                      third audit pass (MiniCard.SIZE is the
│   │   │                      project's only card dimension), and this row
│   │   │                      still described it until that pass's own
│   │   │                      docs were finished. **[QoL]** `count_source`
│   │   │                      + `badge_min` let the Inventory badge how
│   │   │                      many copies are already in the deck, read per
│   │   │                      VISIBLE CELL so the deck changing never
│   │   │                      re-walks the pool; `title` names a
│   │   │                      bottom-bar surface ON its bar row (so naming
│   │   │                      one costs no card height), `corner_tag` puts
│   │   │                      a plate on every tile of an area — the
│   │   │                      sideboard's `SB`, bottom-left with an
│   │   │                      explicit z_index because MiniCard's name
│   │   │                      label is z 2 — and, since 2026-09-04,
│   │   │                      `scroll_arrows` flanks a bottom-barred
│   │   │                      surface with a stone arrow at each end
│   │   │                      (full height, so they are beside the bar as
│   │   │                      well as the cards; the row gives up ARROW_W
│   │   │                      at each end for them). Held down they REPEAT
│   │   │                      (`press_arrow`/`release_arrow` + `_process`,
│   │   │                      ARROW_DELAY then ARROW_REPEAT; the frame
│   │   │                      handler is off at every other moment) and
│   │   │                      each one is DISABLED at its own end of the
│   │   │                      list, triangle greyed with it. The triangle
│   │   │                      is drawn (class Arrow) rather than a glyph,
│   │   │                      and is MOUSE_FILTER_IGNORE — a bare Control
│   │   │                      defaults to STOP and would eat its button's
│   │   │                      own click. `tally` letters HOW MANY
│   │   │                      CARDS a surface holds into its own
│   │   │                      BOTTOM-RIGHT corner, the far end of the same
│   │   │                      bar row (the scroll bar gives up TALLY_W for
│   │   │                      it); the Inventory is the one surface that
│   │   │                      asks, and the number it sets is the whole
│   │   │                      FILTERED list, never the page. Its SIZE is a
│   │   │                      RATIO of the card it stands on
│   │   │                      (TALLY_FONT_RATIO * MiniCard.SIZE.y = 27px,
│   │   │                      up from 14 on 2026-09-04 — "make much
│   │   │                      bigger, as it is not seen now"), so it can
│   │   │                      never drift from the one card size this game
│   │   │                      has; TALLY_W is the same card's width x1.3,
│   │   │                      for the same reason. And
│   │   │                      `card_shifted` is the SHIFT-click that sends
│   │   │                      a card to the other pile
│   │   ├── proxy_face.gd    class ProxyFace — **[QoL]** THE PROXY CARD,
│   │   │                      DRAWN: a card-shaped, card-sized piece of
│   │   │                      plain paper carrying the name and the word
│   │   │                      `proxy`. NOT a MiniCard, for the reason
│   │   │                      DamageMarker is not one — there is no
│   │   │                      CardInstance behind it, so every question the
│   │   │                      small card exists to answer is one you cannot
│   │   │                      ask — but it IS the one card size, MiniCard.
│   │   │                      SIZE small and CardPreview.SIZE large, never
│   │   │                      rescaled. Geometry is the 1997 frame's own
│   │   │                      measured regions; the palette is
│   │   │                      Cardbk_White's pale stone with the colour
│   │   │                      taken out, because a proxy has no colour to
│   │   │                      claim. THE ORIGINAL SHIPS NO BLANK CARD —
│   │   │                      surveyed and recorded in
│   │   │                      tools/import_original.py's manifest notes.
│   │   │                      Every Button state gets the paper, `disabled`
│   │   │                      INCLUDED: both users disable it so the holder
│   │   │                      takes the click, and with only `normal`
│   │   │                      overridden the card body vanished and only
│   │   │                      the two windows drew (caught by a screenshot;
│   │   │                      no test could see it)
│   │   └── deck_store.gd    class DeckStore — where decks live
│   │                          (res://decks + user://decks) and the 1997
│   │                          save/load messages; setup_screen.gd scans
│   │                          the same list. Since 2026-09-02
│   │                          `all_deck_paths` also walks res://decks'
│   │                          SUBFOLDERS (the ported groups) after the
│   │                          top-level starters, so [0] is still Big
│   │                          Green; `deck_paths_in` stays one folder.
│   │                          Loading is LENIENT: a deck
│   │                          file naming a card we have not built opens
│   │                          with every card intact, the unknown names
│   │                          kept as PROXIES (until 2026-09-01 they were
│   │                          DROPPED, so opening a deck and saving it
│   │                          silently shortened it). The duel's own loader
│   │                          stays strict, so nothing unplayable gets
│   │                          through. **[QoL]** `import_file` /
│   │                          `import_text` are the two IMPORT doors — a
│   │                          file the player points at (routed by
│   │                          extension) and a pasted decklist (format
│   │                          sniffed by `looks_like_dck`) — and both end
│   │                          in the same `_fold` as `load_deck`.
│   │                          **[QoL]** `describe()` gives the Load list a
│   │                          deck's own title and card count instead of a
│   │                          bare file name (`40 + 15` when there is a
│   │                          sideboard). `load_deck` reads the SIDEBOARD
│   │                          and the `# group:` line back as well as the
│   │                          notes — one `read_text` for all three — so
│   │                          the builder's round trip loses nothing.
│   │                          **PROVENANCE (2026-09-04)**: `save()` also
│   │                          refuses a name the game SHIPPED —
│   │                          `is_shipped_name` over `shipped_stems()`,
│   │                          which is every shipped FILE name and every
│   │                          shipped TITLE run through `file_stem`, so
│   │                          `Cleric`/`cleric`/`Cleric!` are one name.
│   │                          Saving into `user://decks` could never
│   │                          overwrite `res://decks`; what it COULD do
│   │                          was SHADOW it, two decks with one name and
│   │                          the 1997 one's provenance muddled. The
│   │                          manual's own rule (p.148) is quoted
│   │                          verbatim as `NEW_NAME_RULE` and shown to
│   │                          the player; `suggest_name` offers "My
│   │                          Cleric". `export_deck` is deliberately NOT
│   │                          guarded — `user://decks/export/` is never
│   │                          listed, so it can shadow nothing
│   └── duel/                The duel screen — design decisions in
│       │                      docs/duel-screen-design.md (READ FIRST)
│       ├── duel_screen.tscn Thin root scene (layout is code-built)
│       ├── duel_screen.gd   class DuelScreen — mode machine (NORMAL/
│       │                      TARGETING/ATTACKERS/BLOCKERS/DISCARD/
│       │                      DAMAGE — the last two are the moments the
│       │                      engine holds open, §1.1 and §1.4), engine
│       │                      wiring via public API only, full-rebuild
│       │                      refresh, X dialog, ability menu, mode menu
│       │                      (modal spells), library picker (tutors),
│       │                      keyboard shortcuts, fast-forward.
│       │                      THE CHOICE OVERLAY (§1.3): one dim + Primal
│       │                      Clay window for all four question kinds,
│       │                      raised from _refresh whenever
│       │                      MtgGame.awaiting_choice is set (so any
│       │                      driver reaches it). choice_options() /
│       │                      choice_question() / yes_no_labels() are
│       │                      static and hold the 1997 wording; s30's
│       │                      "%d. %s" lines and number keys 1-9; the one
│       │                      popup with no Cancel.
│       │                      THE BLOCK GESTURE (2026-09-04): _pick_block
│       │                      speaks all three of @PROMPT_DEFENDWHOM's
│       │                      sentences, refuses to LIFT a creature that
│       │                      can legally block none of the attackers
│       │                      (_cannot_block_anything), and _on_confirm
│       │                      puts a still-held blocker DOWN instead of
│       │                      declaring without it — a half-made gesture
│       │                      used to read on screen as a finished block
│       │                      and be thrown away by Done (ROADMAP, "THE
│       │                      BLOCK THAT WAS NEVER DECLARED").
│       │                      THE ZONE COLUMN (owner's ask, 2026-09-03):
│       │                      _pile_count_label puts every pile's count in
│       │                      that pile's own bottom-right corner in
│       │                      PILE_COUNT_INK over a black outline (the
│       │                      graveyard's used to float loose in the row),
│       │                      and _seat_portrait_block fills the gap that
│       │                      frees with the seat's chosen portrait —
│       │                      DuelIntro.portrait_for, so the duel and the
│       │                      pre-duel splash cannot disagree — under
│       │                      (player) or over (opponent) an ellipsized
│       │                      name. The four columns spend the row's 185
│       │                      exactly (50+5+40+5+40+5+40), and the deck
│       │                      is redrawn as a STACK whose depth tracks
│       │                      the library — LIBRARY_STEPS /
│       │                      library_thickness / _dress_deck_stack, the
│       │                      "inexact" readout Duel.hlp describes.
│       │                      tests/ui/test_zone_column.gd
│       │                      THE PLAYFIELD BOUNDARY (owner, 2026-09-04):
│       │                      a card moved by hand must end WHOLLY inside
│       │                      the visible table of its OWN half.
│       │                      _placement_bounds (the half inset as its
│       │                      rows are, and NOTHING subtracted for
│       │                      chrome) x _placement_span (the union of
│       │                      upright 132x106 and turned 114x140, plus
│       │                      the aura fan's upward overflow) ->
│       │                      _clamp_in_half, applied while the drag
│       │                      moves, at the drop, on every
│       │                      _rebuild_placed and from each half's OWN
│       │                      `resized` (_reclamp_placements) — and from
│       │                      nothing else: the hand window used to fire
│       │                      it as it was dragged and shoved every
│       │                      placement it crossed (2026-09-04).
│       │                      tests/ui/test_card_placement.gd
│       │                      THE AUTO-CAST ON THE STACK HAND (owner,
│       │                      2026-09-04): _auto_cast used to be reachable
│       │                      only from _on_card_look, i.e. from a
│       │                      MiniCard's own gui_input — the battlefield
│       │                      and the FAN hand. The DEFAULT hand is a
│       │                      StackHand, whose rows are CardPile holder
│       │                      Buttons carrying `pressed` and nothing else,
│       │                      so the double-click could not fire at all.
│       │                      _arm_hand_auto_cast / _arm_hand_row /
│       │                      _on_hand_card_input arm it off the pile's
│       │                      child_entered_tree (the first click rebuilds
│       │                      the board and frees the row the second lands
│       │                      on). tests/ui/test_casting_flow.gd
│       ├── human_agent.gd   class HumanAgent — DecisionAgent for human
│       │                      seats: pre-selection mailbox the UI fills
│       │                      BEFORE casting (tutor picks) plus park(),
│       │                      the per-resolution mailbox keyed by the
│       │                      CARD that will ask, which accept_answer
│       │                      fills from MtgGame.answer_choice (§1.3);
│       │                      says yes to choosing its own discard and
│       │                      dividing its own combat damage; heuristic
│       │                      fallback for anything the pre-flight cannot
│       │                      reach (costs, statics, replacements)
│       ├── graveyard_view.gd class GraveyardView — the graveyard, exile
│       │                      and ante laid out full-screen and CLICKABLE
│       │                      (@MENU_GRAVEYARD's own three views; s30
│       │                      drawGraveyardView). Without it the engine's
│       │                      four graveyard target kinds had nothing to
│       │                      point at and Raise Dead / Animate Dead /
│       │                      Resurrection were uncastable
│       │                      (docs/duel-todo.md §1.2).
│       │                      [QoL] each pile is a SHELF of plain
│       │                      MiniCards at their TRUE size — five across
│       │                      (cards_across(): three if a board that
│       │                      narrow ever appears; a card is never
│       │                      scaled), ◀ ▶ page_size() buttons in the
│       │                      1997 button art, and the whole-pile
│       │                      position ("7 / 23") on the CENTRE card.
│       │                      Hover fills the duel's own docked
│       │                      CardPreview; the shelves lay out over
│       │                      board_area so they keep off that sidebar
│       ├── exile_plate.gd   class ExilePlate — the EMPTY-EXILE plate for
│       │                      the pile right of the graveyard. DERIVED
│       │                      art: the 1997 game drew no exile pile at
│       │                      all (@MENU_GRAVEYARD reached the zone from
│       │                      the graveyard's own menu), so this one is
│       │                      painted at the grave plate's size and
│       │                      geometry (61x91, 1px white border) out of
│       │                      that seat's grave-plate PALETTE — a card
│       │                      dissolving into the void. No skin, no
│       │                      plate: the two piles come and go together
│       ├── opening_hand.gd  class OpeningHand — play-or-draw and the
│       │                      SHANDALAR mulligan (Duel.hlp topics "Play
│       │                      or Draw Rule" and "Mulligan"): seven for
│       │                      seven, only a no-land or all-land hand, one
│       │                      chance each, and the opponent may follow.
│       │                      Owns every @DIALOG_PLAYORDRAW and
│       │                      @DIALOG_MULLIGAN string (§1.5, §6.2), the
│       │                      ante captions included. The SEQUENCER only:
│       │                      every question is asked through one
│       │                      OpeningWindow, which is what the 1997
│       │                      table's twelve entries describe
│       ├── opening_window.gd class OpeningWindow — THE START-OF-DUEL
│       │                      WINDOW (§6.19): one panel on
│       │                      Winbk_Startduel.pic (versus_background)
│       │                      carrying who takes the first turn, the
│       │                      opponent's mulligan status, BOTH ANTES as
│       │                      full CardPreviews, and the window's own
│       │                      button row. Sized to the cards (which are
│       │                      never rescaled) and then to the ground's
│       │                      own aspect: 977x584, which fits 1280x800
│       │                      and 1280x720 alike
│       ├── mana_icons.gd    class ManaIcons — the mana-symbol glyphs the
│       │                      mini cards and the preview draw
│       ├── mana_text.gd     class ManaText — WRAPPED RULES TEXT WITH THE
│       │                      SYMBOLS SET INLINE, wherever the oracle
│       │                      text writes {R}/{T}/{2}/{X}. The 1997 game
│       │                      did this and its own card database proves
│       │                      it: Master.csv (Tier 1, 1997-08-14) stores
│       │                      the rules text pipe-escaped — `|T: to add
│       │                      |2 to pool` — and Magic.exe imports
│       │                      DrawManaText/CalcDrawManaText by name.
│       │                      Built on a TextParagraph rather than a
│       │                      RichTextLabel because the enlarged card
│       │                      picks its type size SYNCHRONOUSLY: measure
│       │                      and render are the same object, so they
│       │                      cannot disagree (1997 solved it the same
│       │                      way — CalcDrawManaText is DrawManaText with
│       │                      the pen off). Symbol = 3/4 of the line box
│       │                      in an 85% advance cell (drawmanatext.c:296)
│       │                      so it scales with the type and never grows
│       │                      the line; a run of abutting symbols is ONE
│       │                      inline object, which is how the original
│       │                      keeps {B}{B}{B} whole. No skin, or a code
│       │                      off the nineteen-cell sheet ({C}), falls
│       │                      back PER TOKEN to the literal braces
│       ├── card_pile.gd     class CardPile — the original's universal
│       │                      grouping device: a stack of WHOLE MiniCards,
│       │                      each covered one OCCLUDED by the card in
│       │                      front of it rather than clipped (1997's own
│       │                      mechanism, windows.c:1108-1178); hand pile +
│       │                      battlefield land/permanent groups.
│       │                      THE CASCADE (layout_boxes, pure and
│       │                      testable): the stack steps along each card's
│       │                      own TITLE EDGE — 17px down from a flat card,
│       │                      17px LEFT from a turned one — so a tapped
│       │                      row TURNS where it stands and an all-tapped
│       │                      pile is the flat pile transposed. Hidden and
│       │                      collapsed piles stay clipped 17px strips.
│       │                      SHRINKS in its row (see MiniCard._init) so a
│       │                      short pile is neither stretched nor stranded
│       │                      at the top of a tall row
│       ├── stack_hand.gd    class StackHand — the ORIGINAL's draggable
│       │                      hand window (s30 drawHandPanel): the whole
│       │                      Hand_* window NINE-PATCHED round a CardPile
│       │                      (window_texture rebuilds the .pic's missing
│       │                      left border by mirroring); ▲ collapses,
│       │                      ▼ expands. Default hand style. It FLOATS
│       │                      FREE: the board reserves nothing for it and
│       │                      listens to none of its signals (2026-09-04
│       │                      — the owner: "the hand stack can be present
│       │                      anywhere, only cast mini-cards are bound to
│       │                      the playfield").
│       │                      title_plate() is THE SAME WINDOW WITH NO
│       │                      LIST — the opponent's hand, which manual
│       │                      p.114 shows as its title bar alone; same
│       │                      nine-patch, same margins, arrows left to
│       │                      the texture (fortieth pass).
│       ├── card_preview.gd  class CardPreview — the enlarged card, docked
│       │                      in the sidebar (s30 cardPreviewX/Y); frame
│       │                      fraction-anchored to the 1997 Cardbk frames;
│       │                      art via GameSkin.card_art. THE SHOWCASE
│       │                      SHOWS PRINTED P/T, always (manual p.114/118:
│       │                      changes are noted on the card IN PLAY).
│       │                      Bottom border carries both printed marks:
│       │                      `Illus. <name>` left (@ARTISTLINE,
│       │                      UIStrings.txt:251 — "Illus. %s"; Duel.hlp
│       │                      "Parts of the Card" part 6), P/T right; an
│       │                      unknown artist draws nothing at all.
│       │                      LETTERING (2026-09-04): white + hard black
│       │                      outline on the card BODY, 1997's 47,47,47
│       │                      on the rules plate; every size a ported
│       │                      ratio of the card's height; the box grows
│       │                      only WHEN NECESSARY under Expand and takes
│       │                      the frame's own plate with it. THE RULES
│       │                      TEXT IS A ManaText (2026-09-04), so the
│       │                      {R}/{T} codes are set as the 1997 sheet's
│       │                      own symbols; _wrapped_height now MEASURES
│       │                      the paragraph that will be drawn instead
│       │                      of reconstructing a line count for it.
│       ├── mini_card.gd     class MiniCard — THE SMALL CARD, the one
│       │                      generator for every card on the table.
│       │                      SIZE (132x106) IS THE ONLY CARD SIZE IN THE
│       │                      GAME — never rescaled, only ROTATED 90° when
│       │                      tapped; _init shrinks on both axes so no
│       │                      container can stretch one (the fortieth
│       │                      pass's bug) and no caller can forget.
│       │                      OWNS THE TAP TURN (2026-09-03):
│       │                      tap_turn()/turn_angle()/turn_holder() and
│       │                      the static _turn_book (ints only) drive the
│       │                      0.22s ease-out sweep to 90°, resume it
│       │                      across the board's rebuilds, kill rather
│       │                      than stack a running one, and LAND IT AT
│       │                      ONCE headless, where no frame is drawn.
│       │                      A parent opts a card in by giving it a
│       │                      CENTRE PIVOT; a clipped CardPile row has
│       │                      none and stays flat.
│       │                      AND A FLAT ONE IS LETTERED INSTEAD
│       │                      (2026-09-03, [QoL]): shows_tap_mark() is
│       │                      the either/or — a card that cannot turn
│       │                      darkens its title bar (TAPPED_WASH, over
│       │                      the mana slashes, under the name) and puts
│       │                      TAPPED_MARK "(T)" in front of the name,
│       │                      which is the only cue a 17px covered pile
│       │                      row can carry. The status line keeps the
│       │                      letters for a card that DOES turn, so the
│       │                      mark is never on a card twice.
│       │                      Draws:
│       │                      frame-texture border + title bar, art,
│       │                      name (yellow=castable / white), mana
│       │                      stripes, P/T (LIVE, and lettered green when
│       │                      pumped / red when weakened vs the printed
│       │                      values — s30 duel.go:3402-3416).
│       │                      PT_FONT_SIZE / PT_BOX / PT_INSET are s30's
│       │                      measured SHARE of a card rather than a
│       │                      pixel count (20 on its 100x83 card = 0.241
│       │                      of the height; 25 on our 106) — the 1997
│       │                      card has no fixed size at all, it is
│       │                      mainwindow_width/8. OUTLINED, not shadowed,
│       │                      for the reason the zone column found on the
│       │                      pile counts: the numbers stand on card ART.
│       │                      The bottom-right corner's stacking order is
│       │                      DECIDED: damage dagger + count above the
│       │                      pair (offsets derived from PT_BOX), badges
│       │                      bottom-left in a row CLIPPED at the pair's
│       │                      left edge, and the pair at z 1 so the Dying
│       │                      cracks pass under it.
│       │                      enum State = @CUECARD_SMALLCARD's ten small-
│       │                      card states; STATE_CUE the verbatim 1997
│       │                      strings, STATE_SPRITE the skin key of each
│       │                      one's art. Eight are drawn (spiral, dagger,
│       │                      Dying cracks, WillUntap arrow, Target
│       │                      crosshair, CantTarget slash, a lettered
│       │                      "stolen"); `Damage to player` belongs to the
│       │                      DAMAGE MARKER, not to a card and not to the
│       │                      life register (2026-09-01 correction — see
│       │                      damage_marker.gd), and `Phased` cannot reach
│       │                      a widget — see active_states().
│       │                      enum Highlight = the border state machine:
│       │                      OPTIONAL yellow / MANDATORY orange (manual
│       │                      p.128) / COMMITTED green / TARGET_LEGAL /
│       │                      TARGET_CHOSEN (width 3, s30's one width
│       │                      distinction).
│       │                      THE WIDTH IS DRAWN TWICE OVER (2026-09-04):
│       │                      a StyleBoxTexture has NO border width, so
│       │                      the skinned frame could carry only the
│       │                      colour and COMMITTED and TARGET_CHOSEN
│       │                      rendered BYTE-IDENTICALLY (card-states.md
│       │                      §5.2). _highlight_ring draws the width as a
│       │                      ring OVER the frame — a lazily built
│       │                      MOUSE_FILTER_IGNORE Panel (a Panel defaults
│       │                      to STOP) in the state's own colour and
│       │                      width, on the TEXTURED frame only. NONE
│       │                      builds no node at all, so a resting card
│       │                      renders the same bytes it always did.
│       │                      face_down IS CARRIED FROM THE ENGINE
│       │                      (2026-09-04, §5.1): DuelScreen._make_card,
│       │                      CardPile._make_card and GraveyardView._card
│       │                      copy CardInstance.face_down, so an
│       │                      Illusionary Mask creature and a Knowledge
│       │                      Vault exile wear Cardback.pic instead of
│       │                      their name, art, tooltip and mana stripes —
│       │                      to EVERY seat, because engine/ has no
│       │                      per-seat visibility model to ask and that is
│       │                      the only reading that cannot leak. Still
│       │                      clickable on the battlefield: a face-down
│       │                      permanent attacks, blocks and is targeted.
│       │                      Badge slots: BADGE_SLOT +
│       │                      PROTECTION_SLOT + REGENERATION_SLOT 15
│       │                      (predicate regenerates_itself — there is no
│       │                      regeneration KEYWORD) + ARTIFACT_PROTECTION_
│       │                      SLOT 10 (predicate warded_from_artifacts —
│       │                      cur_protection is a colour bitmask). Cells
│       │                      are masked to their inscribed circle;
│       │                      cell 17 is blank and is never drawn
│       ├── death_mark.gd    class DeathMark — THE DYING MARK: the 1997
│       │                      `Dying` state (@CUECARD_SMALLCARD entry 8),
│       │                      held for a beat over the square a DESTROYED
│       │                      permanent has just left. The original's own
│       │                      predicate is `kill_code == KILL_DESTROY` —
│       │                      marked to be destroyed and not reaped yet
│       │                      (windows.c:724, the small card's tooltip
│       │                      handler; the same predicate regeneration
│       │                      targets, refused with `Illegal target (not
│       │                      dying).`; Duel.hlp Regeneration: "ONLY at
│       │                      the time when a creature is about to go to
│       │                      the graveyard"). Raised by MiniCard from
│       │                      Mtg.EventType.DIES — off the DEATH, not off
│       │                      the damage, so a REGENERATED creature can
│       │                      never wear it and a SACRIFICED one does not
│       │                      (1997 keeps the kill codes apart and the
│       │                      event carries `sacrificed`). It is a whole
│       │                      MiniCard ghost wearing force_dying, not bare
│       │                      cracks: the board re-flows the instant a
│       │                      creature leaves it, and cracks alone would
│       │                      end up on a LIVE neighbour. HOLD+FADE are
│       │                      [QoL] — 1997's regeneration step is as long
│       │                      as the player takes to pass it
│       ├── target_arrows.gd class TargetArrows — the arrow overlay above
│       │                      the board (s30 duel.go:3449-3554): RED from
│       │                      each blocker's top-centre to its attacker's
│       │                      bottom-centre, AMBER from the caster's hand
│       │                      window to every target on the stack (and to
│       │                      the targets picked so far while aiming);
│       │                      a targeted PLAYER terminates on their life
│       │                      panel. Positions resolve at DRAW time, from
│       │                      the MiniCards each _refresh() rebuilds
│       ├── damage_marker.gd class DamageMarker — THE DAMAGE MARKER, one
│       │                      waiting DamagePacket drawn as the 1997
│       │                      game's yellow "card" (manual p.119; Duel.hlp
│       │                      says "a card, a damage marker, or whatever"
│       │                      in three topics; @CIRCLE_OF_PROTECTION's own
│       │                      prompt is `Select damage card.`). SOURCE on
│       │                      the title bar and the REMAINING amount over
│       │                      the art, because telling two packets apart
│       │                      IS the decision. MiniCard.SIZE, never
│       │                      rescaled, but not a MiniCard — no
│       │                      CardInstance behind it. Carries
│       │                      @CUECARD_SMALLCARD's two damage entries:
│       │                      `Damage: %d` and `Damage to player`, which
│       │                      is the marker's cue and NOT the life
│       │                      register's (@CUECARD_LIFE's eight entries
│       │                      do not include it — duel-todo §2.10's
│       │                      correction). set_target_state() wears the
│       │                      CantTarget circle-slash when the open slot
│       │                      refuses this packet
│       ├── damage_marker_layer.gd
│       │                    class DamageMarkerLayer — the overlay that
│       │                      puts each marker ON OR NEAR its victim
│       │                      (manual p.119): a creature's own widget, or
│       │                      that seat's life register for damage to a
│       │                      player. Shaped after TargetArrows — the
│       │                      screen feeds it state once per _refresh and
│       │                      it resolves screen positions itself, every
│       │                      frame, because containers lay out after a
│       │                      rebuild returns. Markers exist only while
│       │                      MtgGame.damage_pending does, so closing the
│       │                      window clears them with no teardown
│       ├── board_order.gd   class BoardOrder — ARRANGE CARDS: the order
│       │                      the table falls into when the player asks
│       │                      for it. Static, non-mutating comparators
│       │                      over the LIVE characteristics — hand (lands
│       │                      by name, then WUBRG / mana value / name),
│       │                      creatures (power desc, toughness desc,
│       │                      name), lands (name, untapped first); other
│       │                      permanents keep play order. Every key ends
│       │                      on the instance id, because sort_custom is
│       │                      not stable and this runs every refresh. The
│       │                      COMMAND is 1997 (@MENU_TERRITORY "Arrange
│       │                      your cards"), the ORDER is s30's
│       │                      (duel.go:1438-1544)
│       ├── arrange_button.gd class ArrangeButton — the arrange TOGGLE and
│       │                      the first tenant of the sidebar's QoL
│       │                      reserve. Its icon is drawn, not imported
│       │                      (the 1997 command lived in a text menu and
│       │                      had no icon): three cards askew, three
│       │                      squared up. Owner's design — click sorts,
│       │                      click again restores, and restoring is free
│       │                      because the engine's own zone arrays are
│       │                      the unarranged order
│       ├── duel_options.gd  class DuelOptions — @DIALOG_DUELOPTIONS
│       │                      (UIStrings.txt:598), the 1997 duel's own
│       │                      preferences window: nineteen strings, the
│       │                      panel that shows them, and the settings
│       │                      behind them. Keys are the ORIGINAL's
│       │                      registry names (ShowCueCards, Layout,
│       │                      PlayerTerritoryColor...). Opened from
│       │                      `Duel Options...`, entry 17 of
│       │                      @MENU_TERRITORY; every control writes on
│       │                      the spot — "These settings are retained for
│       │                      future duels" (Duel.hlp). `Your territory
│       │                      background` is TWO lists (colour x style),
│       │                      which is what the two registry values and
│       │                      Duel.hlp's "Select one option from each"
│       │                      both say; ground_key maps the nine choices
│       │                      onto duel_<style>_<colour> and is PURE, so
│       │                      it answers the same headless. SIMPLIFIED:
│       │                      Advanced layout is greyed
│       ├── coin_toss.gd     class CoinToss — THE OPENING TOSS and its
│       │                      three presentations (duel-todo §6.4).
│       │                      THE 1997 COIN WAS A MOVIE, not an
│       │                      animation: `MCIWndCreateA` on
│       │                      COINTOSS_Heads.AVI / COINTOSS_Tails.AVI
│       │                      (DUEL.EXE's dialog proc at entry
│       │                      004492ad), which Magic.exe's own string
│       │                      table corroborates — DIALOG_COINFLIP and
│       │                      the two filenames sit adjacent in it — and
│       │                      which is why no coin art exists to import.
│       │                      Three modes behind ONE stored value: the
│       │                      original's video (transcoded to a sprite
│       │                      sheet by import_original.py, since the
│       │                      files are Indeo Video 4.1 and Godot plays
│       │                      only Theora), our own turning coin, or the
│       │                      instant result — a struck coin in the
│       │                      winner's colour, a DRAWN chevron aimed at
│       │                      that seat's half of the table, and the
│       │                      seat's name. `ShowCoinFlips` is the 1997
│       │                      boolean VIEW of that three-way and still
│       │                      reads a 1997 registry 0/1. Reports the
│       │                      toss, never decides it: the winner comes
│       │                      off game.rng in DuelScreen._new_game and
│       │                      every function here takes it as an
│       │                      argument. Headless builds nothing
│       ├── territory_ground.gd
│       │                      class TerritoryGround — the picture behind
│       │                      `Your territory background` (duel-todo
│       │                      §6.4), one node per territory and never
│       │                      null. The three 1997 styles are three
│       │                      different kinds of file and are drawn as
│       │                      such: `patt` is a FRAMED panel, so a
│       │                      NinePatchRect keeps its 8px (black: 20px)
│       │                      border at native size and TILES the field;
│       │                      `mana` is a borderless wallpaper and just
│       │                      tiles; `pict` is one picture and is COVERED
│       │                      so it is never squashed. Without the 1997
│       │                      skin all fifteen grounds are PAINTED here —
│       │                      a lozenge lattice, a medallion quilt and
│       │                      one outlined emblem, over a Bayer-dithered
│       │                      stone in the seat's colour
│       ├── squeeze_row.gd    class SqueezeRow — a battlefield row that
│       │                      NEVER WRAPS (duel-todo §2.13). Over its
│       │                      natural width the pitch becomes
│       │                      (available - last width) / (n-1) and the
│       │                      cards slide under one another, which is
│       │                      s30's duel.go:1424-1434 generalised to our
│       │                      mixed-width children (a CardPile is wider
│       │                      than a MiniCard). A wrapped row would break
│       │                      the three-row reading order §2.3 and §4.2
│       │                      are both about
│       ├── territory_menu.gd class TerritoryMenu — @MENU_TERRITORY
│       │                      (UIStrings.txt:908), the 25-entry mini-menu
│       │                      a right-click on either territory opens.
│       │                      Carries the fourteen `Go to:` destinations
│       │                      resolved onto our two bars — the half of
│       │                      the 1997 fast-forward that Run to did not
│       │                      cover — plus the rest of the table, live or
│       │                      greyed, and the `Concede` / `Yes, I'm sure`
│       │                      confirmation. Only `Show invisible effects`
│       │                      and `Help...` are still dark.
│       │                      `Save game...` is deliberately absent
│       │                      (manual p.112: Duel only)
│       ├── card_menu.gd     class CardMenu — the OTHER `@MENU_*` tables
│       │                      (duel-todo §6.12): @MENU_SMALLCARD,
│       │                      @MENU_LIBRARY, @MENU_HAND, @MENU_MANAPOOL,
│       │                      @MENU_FULLCARD, and the four WINDOW menus
│       │                      the item's own table omitted (@MENU_ATTACK
│       │                      / @MENU_MINIMIZEDATTACK, @MENU_SPELLCHAIN /
│       │                      @MENU_MINIMIZEDSPELLCHAIN). Every table
│       │                      verbatim and complete, `live` per entry,
│       │                      because the original greys what it cannot
│       │                      offer rather than shortening its menu.
│       │                      `build()` fills a PopupMenu, turning a row
│       │                      with a `toggle` key into a check item over
│       │                      DuelOptions.MENU_TOGGLES
│       ├── fireball_dialog.gd class FireballDialog — @DIALOG_FIREBALL
│       │                      (UIStrings.txt:657), the X dialog, named
│       │                      after the card that needs all seven of its
│       │                      strings. Entries 1-2 are the whole window
│       │                      for an ordinary {X} spell; the other five
│       │                      appear when the spell also buys TARGETS
│       │                      with the same mana (extra_cost_per_target),
│       │                      and `plan()` is the arithmetic that splits
│       │                      one pot of generic between X and the
│       │                      additional-target surcharge. NOT the
│       │                      divided-damage dial — that is @PYROTECHNICS
│       │                      and it is a click loop (duel-todo §6.14)
│       ├── duel_audio.gd    class DuelAudio — THE DUEL'S SOUND: the 1997
│       │                      cue vocabulary (cue_for(GameEvent), pure and
│       │                      testable without a screen), a pool of up to
│       │                      8 voices on the SFX bus, and the duel's one
│       │                      tune. One voice per CUE per frame, so a
│       │                      five-way combat is one Damage.wav and the
│       │                      opening deal one Draw.wav, while different
│       │                      cues layer. Moved out of duel_screen.gd on
│       │                      2026-09-02 with three timing corrections —
│       │                      see docs/duel-todo.md §3.8
│       ├── spell_flight.gd  class SpellFlight — THE SPELL-CAST
│       │                      ANIMATION (duel-todo §2.4): a ghost
│       │                      MiniCard tweens from the hand slot to the
│       │                      Spell Chain window when a spell is cast,
│       │                      and on to its battlefield slot or its
│       │                      owner's graveyard when it leaves the chain.
│       │                      s30's duel_spell_animation.go with the
│       │                      1997 DESTINATION (s30 flies to its
│       │                      magnifier only because it has no chain
│       │                      window) and no size interpolation (the
│       │                      original has one card size). is_flying()
│       │                      is s30's spellIsAnimating: the board skips
│       │                      a card a ghost is carrying. Off entirely
│       │                      without a display
│       ├── phase_stops.gd    class PhaseStops — THE STOPS (manual
│       │                      p.116-117, Duel.hlp topic "Stop"): which
│       │                      phases the player has marked "do not pass",
│       │                      per half of the bar (yours / the opponent's)
│       │                      and per bar (the Phase Bar's 8 icons, the
│       │                      Combat Bar's 7) — the original's own
│       │                      option_PhaseStoppers[2][38] shape. Carries
│       │                      the four @MENU_PHASEBAR strings, and
│       │                      persists through Settings because a Stop is
│       │                      "a lasting instruction" — with a fifth int,
│       │                      DEFAULTS_GENERATION, so a row written by a
│       │                      build that had no defaults is not mistaken
│       │                      for an opt-out from them (2026-09-04)
│       ├── phase_bar.gd      class PhaseBar — THE PHASE BAR, "the central
│       │                      control for the progress of the duel"
│       │                      (manual p.116). Winbk_Phase.pic's 16 icons,
│       │                      8 per half (opponent on top from y=2, yours
│       │                      from y=431), each with its @CUECARD_PHASEBAR
│       │                      cue card. The CURRENT phase is the sheet's
│       │                      white-ground highlighted cell; the RED DOTS
│       │                      are the Stop markers, several at a time.
│       │                      Left-click emits slot_pressed (Run to),
│       │                      right-click slot_context (the mini-menu)
│       ├── combat_bar.gd     class CombatBar — THE COMBAT BAR (manual
│       │                      p.117/125, Duel.hlp topic "Combat Bar"): the
│       │                      miniature Phase Bar that REPLACES the Phase
│       │                      Bar for the length of an attack. SEVEN icons
│       │                      off Winbk_Phasecombat.pic (164x760 = the
│       │                      Phase Bar's own [normal|active] pair twice,
│       │                      gold for the opponent's attack, blue for
│       │                      yours), each carrying its @CUECARD_PHASEBAR
│       │                      cue card; slot_for_step maps our steps onto
│       │                      them. keyed_texture() keys the sheet's white
│       │                      cell grounds to BLACK and leaves the lit one
│       │                      white, which is what Winbk_Phase already
│       │                      draws. A click is Done during a declaration
│       │                      and Run to otherwise; Stops get red dots
│       ├── combat_window.gd  class CombatWindow — THE COMBAT WINDOW
│       │                      (manual p.126), titled `Your attack` /
│       │                      `%s Attack` (@WINDOWTITLES). Opens on the
│       │                      first attacker; the attacking seat's lineup
│       │                      takes ITS OWN side of the window and the
│       │                      blockers face it, marked by the 1997 sword
│       │                      and shield sprites over the Winbk_Attack
│       │                      skull ground and its bone-strip floor. A
│       │                      creature in combat leaves its territory for
│       │                      the window (DuelScreen._rebuild_field), so
│       │                      the blocker arrows run between the lanes.
│       │                      Minimises from its upper-right corner into
│       │                      the WINDOW ICON in the Phase Bar's centre
│       │                      band (Winbk_Attackmin, 39x70)
│       ├── original_dialog.gd  class OriginalDialog — THE 1997 POPUP:
│       │                      one component for every centre dialog,
│       │                      message box and button in the duel, so the
│       │                      chrome cannot drift popup by popup. PANELS
│       │                      carries each 1997 ground's own MEASURED
│       │                      bevel width as a 9-patch margin;
│       │                      bar_style() rules the Situation Bar's
│       │                      borderless Telluser stone; button() is the
│       │                      era's three-state art (Winbk_Startduel-
│       │                      button*, a DOUBLE bevel rule) 9-patched;
│       │                      label()/ink_label() are the era's two text
│       │                      voices; choice_line() and field() its list
│       │                      lines and numeric boxes. Wording comes from
│       │                      docs/glossary-1997.md. Worn by: the
│       │                      Situation Bar + Done, the modal-choice
│       │                      dialog, the X question, the library picker,
│       │                      the ability mini-menu, the end-of-duel
│       │                      window and the opening coin toss
│       ├── decks.gd         class StarterDecks — default 40-card decks
│       ├── duel_config.gd   class DuelConfig — everything the setup
│       │                      screen decides (seats/pilots/decks/lives/
│       │                      pace/panel colors); hidden_seats() policy;
│       │                      `ante` is the original's &Ante match
│       │                      parameter (0 = not for ante, which is what
│       │                      a bare config means so nothing
│       │                      programmatic loses a card); `best_of` /
│       │                      `sideboard_between_duels` / `sideboards`
│       │                      are the other match parameters, and
│       │                      `deck_format` records which of the five the
│       │                      decks were required to meet. Every one
│       │                      defaults to the single-duel value
│       ├── duelist_face.gd  class DuelistFace — THE LIFE REGISTER'S OTHER
│       │                      SIDE and the words that turn it over:
│       │                      @MENU_LIFE / @MENU_FACE (two tables
│       │                      differing in one entry) plus the two 120x88
│       │                      grounds, `life_panel_<colour>` (the
│       │                      wallpaper the life total is written on) and
│       │                      `duelist_face_<colour>` (the portrait).
│       │                      `Duel.hlp`'s "Duelist's Face" topic is the
│       │                      whole spec and is quoted in the file
│       ├── match_state.gd   class MatchState — `&Best of:` arithmetic and
│       │                      the 1997 record sentences
│       │                      (@DIALOG_ENDEXP1DUEL_MATCHPROGRESS). 0 =
│       │                      `&Free play` ([QoL] — Manalink's word, not
│       │                      1997's); LENGTHS is 1, 3, 5 — 3 and 5 are
│       │                      the only lengths the original's record
│       │                      sentence can narrate, and 1 is the
│       │                      gauntlet's `Best of &One`
│       │                      (@DIALOG_GAUNTLETOPTIONS). last_winner is
│       │                      kept for the gauntlet's round window
│       ├── gauntlet_state.gd  class GauntletState — THE RUN: the shuffled
│       │                      opponent order and its twenty cap, the
│       │                      random start offset and its wraparound, the
│       │                      1-based round counter, the SESSION record
│       │                      (duels won/lost/tied, which is not the
│       │                      match's), and the ten @GAUNTLET + four
│       │                      @DIALOG_GAUNTLETENDDUEL + three
│       │                      @DIALOG_STARTEXP1MATCH_GAUNTLET + four
│       │                      @GAUNTLETERRORS strings.
│       │                      end_of_duel_lines() composes the round
│       │                      window's message in the 1997 driver's own
│       │                      order (DUEL.EXE 0x4420a1); announcement()
│       │                      picks the first/nth/final next-opponent
│       │                      line; opponent_deck_problem() picks the
│       │                      @GAUNTLETERRORS refusal (three of the four
│       │                      — DECK_WRONG_VERSION is unreachable and its
│       │                      doc comment says why). Pure RefCounted,
│       │                      seeded — docs/gauntlet-design.md
│       ├── gauntlet_options.gd class GauntletOptions — the run's
│       │                      parameters and their window:
│       │                      @DIALOG_GAUNTLETOPTIONS entry for entry
│       │                      (Match Size = Best of Three/One, Ante, the
│       │                      four Enemy Levels) plus the shell page's
│       │                      `&Num opponents:` and `Side&board between
│       │                      duels` and the startup screen's
│       │                      `&Create Deck...`, and the [QoL] five-band
│       │                      `Gauntlet difficulty: %3d (%s)` readout
│       ├── gauntlet_screen.gd/.tscn  class GauntletScreen — THE OUTER
│       │                      LOOP: owns one MatchScreen per round the
│       │                      way MatchScreen owns DuelScreens, takes
│       │                      MatchScreen.match_finished, and puts up the
│       │                      round window (@DIALOG_GAUNTLETENDDUEL —
│       │                      both buttons ABSENT, not greyed, once the
│       │                      run is over) and the next-opponent window
│       │                      before each match
│       │                      (@DIALOG_STARTEXP1MATCH_GAUNTLET). One seed
│       │                      per run, split per match; headless plays
│       │                      straight through, raising neither window.
│       │                      Your own deck is checked on `Run the
│       │                      gauntlet` (GauntletState.your_deck_problem)
│       │                      and a refusal puts the options window back
│       └── fan_hand.gd      class FanHand — the 1997 fanned hand: arc,
│                              tilt, overlap, hover-raise (plain Control —
│                              containers reset child rotation). CARD_SIZE
│                              is an ALIAS of MiniCard.SIZE, never a size
│                              of its own (it carried 96x120 until the
│                              fortieth pass); when a row will not fit the
│                              COUNT gives — a second row BEHIND the first.
│
├── addons/gut/              Vendored GUT 9.6.1 test framework (unmodified)
└── docs/
    ├── ARCHITECTURE.md      Design decisions & layer model — READ FIRST
    ├── CODE_MAP.md          This file
    ├── adding-cards.md      The card-authoring pipeline + checklist
    ├── audit-vs-mage-go.md  Scrutiny audit vs the mage-go reference:
    │                          per-card/system discrepancy table, what was
    │                          fixed, what's deferred, where mage-go itself
    │                          deviates from oracle
    ├── code-review-2026-08.md  Code-review / bug-hunt / optimization pass
    │                          (2026-08): findings table with the test that
    │                          pins each fix, plus the Deck Lab before/after
    │                          performance measurements
    ├── code-review-2026-09.md  Code review (2026-09-01) after the day the
    │                          pool went 837 -> 897 and seven subsystems
    │                          landed: orphan-node investigation, a
    │                          reproduced WorkerThreadPool data race, the
    │                          Deck Lab's draw accounting, and the UI
    │                          lifecycle sweep — each row with its pin
    ├── audit-2026-09.md     THE FULL AUDIT (2026-09): all 788 cards vs the
    │                          oracle snapshot and mage-go, every engine
    │                          subsystem line by line, the layer-pipeline
    │                          rework, the combat-status rework, and the
    │                          measured optimization pass
    ├── audit-vs-s30.md      Scrutiny audit vs the 30th-anniversary remake
    │                          (2026-09-01): all 897 cards read clause by
    │                          clause. Opens with the finding that shapes
    │                          it — s30 has NO card rules of its own, its
    │                          duel engine IS mage-go — then the 24 fixes,
    │                          the engine and ledger findings left for
    │                          their owners, the 1997 per-card prompt
    │                          tables as evidence, the pool-membership
    │                          question (Nalathni Dragon), and the
    │                          provenance correction that Program/Cards.dat
    │                          is a Manalink file, not a 1997 one
    ├── mechanics.md         THE MECHANICS CATALOGUE — every mechanic the
    │                          engine implements, its CR rule, the class
    │                          that implements it, an example card and any
    │                          simplification. Read this to learn what the
    │                          engine can do
    ├── simplified-cards.md  THE FIDELITY LEDGER — every card-scoped
    │                          SIMPLIFIED deviation, one row each
    ├── duel-todo.md         THE DUEL WORK LIST — prioritized, every item
    │                          traceable to the 1997 manual/Duel.hlp/string
    │                          tables, to s30's Go, or to mage-go, and each
    │                          labelled [1997] faithful / [s30] divergence /
    │                          [QoL] ours so nothing mixes silently
    ├── tier2-plan.md        THE TIER 2 IMPLEMENTATION PLAN — duel-todo.md
    │                          §2's fifteen items re-verified against the
    │                          live code, each with its reference (s30
    │                          file:line, manual page, @TAG), the component
    │                          that does the work, its tests, its place in
    │                          the recommended wave order, and its risk.
    │                          Opens with a done/part-done/stale table and
    │                          the corrections duel-todo.md should absorb
    │                          (2.2 superseded by the Combat window; 2.8
    │                          done; 2.3/2.4/2.10/2.15 re-tagged; 2.9's
    │                          premise reversed by manual p.114)
    ├── set-packages-plan.md  THE SET-PACKAGES PLAN (2026-09-02; the
    │                          gating/loader is not built, the PACK FORMAT
    │                          is — see its "Implemented: pack format v1"
    │                          section, tools/build_card_packs.py and the
    │                          sibling ../shandalar-packs/) — how a
    │                          toggleable "classic
    │                          expansions" pack (Fallen Empires, Ice Age,
    │                          Homelands, Alliances; 5ed/Chronicles/Revised
    │                          add no new names) would be gated in
    │                          CardRegistry, filtered in the deck builder,
    │                          fetched (cards AND art) through the existing
    │                          Scryfall tools, tested, and priced: per-set
    │                          census, the engine gaps (cumulative upkeep,
    │                          snow, pitch costs…), a phased estimate and
    │                          the open decisions
    ├── decks-1997.md        THE 1997 DECKS, PORTED (2026-09-02) — every
    │                          deck group the mtg.wiki preconstructed-decks
    │                          page lists (55 originals, 55 Spells of the
    │                          Ancients, 25 Duels of the Planeswalkers, the
    │                          22 "Play Deck" decks by designer) plus the
    │                          three non-MicroProse groups — 76 tournament
    │                          lists, 64 community decks, 15 extended
    │                          community lists, a table each with
    │                          pilot/designer, event, year, source and
    │                          proxy count: the source of every
    │                          list with its provenance tier, the enemy
    │                          tier table, the sideboard fold rule, every
    │                          discrepancy (Decks.zip is a 2016 Manalink
    │                          artefact; two Manalink-replaced Merfolk
    │                          Shaman files; Warlock's 64 cards; Arzakon's
    │                          138), the per-group proxied-card table, the
    │                          unsourced archetypes, and where it is wired
    ├── gauntlet-design.md   THE GAUNTLET DESIGN (2026-09-02, BUILT the
    │                          same day; §9 records what building proved) —
    │                          the 1997 mode we never had, established from
    │                          the string tables, the printed manual and the
    │                          FIRST survey of the Tier 2 decompilation:
    │                          the run loop, the opponent shuffle, the two
    │                          Match Sizes, the 20-opponent cap. Four build
    │                          slices, and every place the sources run out
    │                          with the [QoL] choice made instead. Opens
    │                          with the provenance correction that
    │                          Program/Text.res is Manalink 3's table, not a
    │                          1997 superset, and that s30's Uistrings.txt is
    │                          the cleaner 1997 copy
    ├── card-states.md       WHAT A SMALL CARD CAN WEAR (2026-09-04) — the
    │                          complete visual vocabulary of a MiniCard:
    │                          every mark, badge, glyph, overlay, tint and
    │                          letter, what each MEANS, when it appears and
    │                          goes, which code draws it, and whether the
    │                          art is 1997's (named file -> skin key) or
    │                          ours. Opens with the comparison that matters
    │                          — @CUECARD_SMALLCARD's ten states against
    │                          what we draw (nine of ten; `Phased` cannot
    │                          be asked) — then says plainly what is
    │                          UNREACHABLE in play (the face-down small
    │                          card; the live `Dying` predicate and the
    │                          whole damage marker, both behind the
    │                          Fifth-Edition damage-prevention fork) and
    │                          the six defects the pass found. Pictures:
    │                          ../shandalar-build/shots/card_states/
    ├── glossary-1997.md     THE NAMING REFERENCE — the original's own word
    │                          for every duel thing (Territory, Showcase,
    │                          Situation Bar, Combat Bar, Stop, fast effect,
    │                          Life Register...), what we call it today, and
    │                          the 1997↔modern phase mapping. Read before
    │                          naming any new duel control or prompt
    └── ROADMAP.md           v0.1 simplifications & milestone plan
```

Sibling directories at the repo-parent level (reference material, not part of
the game): `../s30/` (Go remake), `../shandalar-src/` (Manalink snapshot),
`../tools/godot` (pinned Godot 4.7.2 binary), `../docs/SHANDALAR_LORE.md`
(game-design/lore reference), `../shandalar-packs/` (output of
tools/build_card_packs.py: one .tar.gz per downloaded set plus the
dotp-1997 purist bundle, index.json and a Scryfall cache — outside res://
so Godot never imports it, outside git because it carries Scryfall art).
