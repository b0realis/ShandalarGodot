# Scrutiny audit — cards & engine vs the mage-go reference

Date: 2026-08-30. Scope: every implemented card (178 hand-written + 77
generated at audit time) cross-checked against its mage-go reference
implementation (`../mage-go/cards/`) AND the printed oracle text carried in
each card's header; engine mechanics (combat waves, banding, protection
DEBT, regeneration, prevention pools, cost modifiers, the 1997 legend rule,
modal spells, targeting) checked against mage-go's `pkg/mage/` systems.

Authority rule used throughout: **the oracle text (project Scryfall
snapshot in `cards/data/`) wins**; mage-go is the mechanics reference.
Where mage-go itself deviates from oracle and we match oracle, the finding
is recorded as "mage-go deviates" and nothing changes on our side.

Pins for every fix live in `tests/unit/test_audit_fixes.gd` (engine) and
`tests/cards/test_audit_fixes.gd` (cards).

## Findings — fixed

| Card / system | Discrepancy | Severity | Resolution |
|---|---|---|---|
| Targeting engine (`target.gd`) | Blanket "nothing targets itself" ban wrongly stopped ABILITIES from targeting their own source — Samite Healer couldn't shield itself, an animated Mishra's Factory couldn't pump itself, Kei Takahashi couldn't save himself | HIGH | Self-reference now blocked only while the source is a spell on the stack (CR 114.4); abilities may target their source |
| Regeneration | Cost was {G}; the printed card is {1}{G} (Scryfall + mage-go agree) — one mana too cheap every game | HIGH | Cost corrected |
| Animate Dead | Departing aura DESTROYED the reanimated host, so a regeneration shield kept it alive forever; oracle says the controller SACRIFICES it | MEDIUM | New `MtgGame.sacrifice_permanent()` (CR 701.17 — dies, can't regenerate); aura path and sacrifice costs use it |
| Drain Life | Life gain was computed before damage: prevention (Samite Healer, CoP) still fed the caster full life, and a player target's remaining-life cap was missing | MEDIUM | `deal_damage` now returns the amount actually dealt; gain = min(dealt, victim's toughness / life before damage). Ledger row shrunk to the spend-only-black-on-X point |
| Ashes to Ashes / multi-target spells | The same creature could fill both "two target nonartifact creatures" slots (castable with one creature, exiling once for full price) | MEDIUM | `cast_spell` refuses duplicate permanents across target slots (CR 601.2c) |
| Ankh of Mishra | Triggered on LAND_PLAYED only — lands FETCHED onto the battlefield (Untamed Wilds, since wave 9) slipped past | MEDIUM | Now an ENTERS_BATTLEFIELD trigger gated on the entrant being a land |
| City of Brass | Pain trigger fired only on taps for mana — Icy Manipulator tapped it painlessly (ledger row) | MEDIUM | New universal `BECAME_TAPPED` event (mirrors mage-go's EvtTapped): dispatched on tap-for-mana, tap costs, tap effects, attacking, regenerating — never on entering tapped. Ledger row lifted |
| Psychic Venom | Same taps-for-mana-only gap (ledger row) | MEDIUM | Listens to `BECAME_TAPPED`; ledger row lifted |
| Land Tax | Intervening "if" (opponent controls more lands) checked only when the trigger fired, not again on resolution (CR 603.4) | LOW | Condition re-checked at resolution |
| Continuous pipeline (`continuous.gd`) | +1/+1 / -1/-1 counters were applied BEFORE static abilities, so dynamic-P/T statics that SET power (Nightmare, Keldon Warlord — layer 7b) wiped counters (layer 7d) | LOW | Counters now applied after statics; additive statics commute so nothing else moves |
| Regeneration mechanic (`destroy`) | The regeneration tap didn't recalculate, leaving tap-conditional statics (Castle) stale until the next state change; the tap also fired no became-tapped event | LOW | `recalculate()` + `BECAME_TAPPED` dispatch in the regeneration branch |
| Paralyze | The {4}-payment simplification was stricter than its ledger row admitted (requires 4 untapped LANDS specifically; engine picks which) | LOW | SIMPLIFIED comment + ledger row rewritten to tell the truth; mechanics unchanged (payment rework still queued) |

## Findings — deliberate / deferred (no code change)

| Card / system | Note |
|---|---|
| Jump ({U}) | Flagged as "should be {1}{U} (1997 printing)" — REJECTED: the project's authority is the Scryfall oracle snapshot (`cards/data/2ed.json` says {U}, the M10 oracle cost), consistent with every other card in the pool (Ankh's "a land enters", Black Vise's "choose an opponent" are the same modern-oracle policy) |
| Black Vise / The Rack | Implement the pre-errata "each opponent" wording instead of the modern "choose an opponent" ETB choice — identical in a two-player duel, which is all this engine plays. Header-documented; not ledger-worthy since no observable deviation exists in 2P |
| Terror (and all protection/color checks) | Color filters read printed color (`data.color_mask()`), not a live color — no color-changing effect exists in the pool; becomes real work only if one is ever added (note also in ROADMAP) |
| Timetwister / Wheel of Fortune | Resolve per player sequentially instead of all-discard-then-all-draw — interleaving unobservable in this pool |
| Both players at 0 life simultaneously | First-found loses; the engine has no draw concept (engine-wide, ROADMAP) |
| Blood Lust | `mini(4, toughness-1)` formula verified algebraically identical to the printed two-branch text for all toughness ≥ 1 |

## mage-go deviations found (ours correct — recorded for reference)

- Blue/Red Elemental Blast: mage-go implements only the counter mode,
  dropping the destroy-permanent mode; ours is properly modal.
- Active Volcano / Flash Flood / Alabaster Potion: mage-go drops per-mode
  target filters (blue permanent / Island etc.); ours enforce them.
- Firebreathing / Holy Armor / Regeneration: mage-go grants the activated
  ability to the enchanted CREATURE (wrong activator when enchanting an
  opponent's creature); ours keep it on the aura.
- Howling Mine: mage-go omits the "if untapped" condition (Icy matters).
- Gloom: mage-go self-admits missing the white-enchantment-abilities tax.
- ~~Erg Raiders: mage-go has cost {1}{B}; printed is {B}{B} (ours).~~
  **RETRACTED 2026-08-31** — this row was backwards. Both `cards/data/4ed.json`
  and `cards/data/arn.json` say `{1}{B}`, and mage-go agrees; OUR card was the
  one at `{B}{B}`. Fixed in the 2026-08 code review
  (docs/code-review-2026-08.md), pinned by
  `tests/cards/test_review_2026_08.gd::test_erg_raiders_costs_one_generic_and_one_black`.
- Mind Twist: mage-go discards by choice, oracle (and ours) at random.
- Goblin King grants mountainwalk possibly including itself ("Other
  Goblins" is printed); ours excludes itself.

## Engine systems verified clean against mage-go

First-strike two-wave combat (packet collection = simultaneity within a
wave), trample lethal-first spillover, blocked-attacker-with-dead-blockers
rules (only trample punches through), banding attack-band pooling, landwalk
live-type checks, protection DEBT enforcement points, CoP one-shot color
shields + point prevention pool ordering (shields → pools → damage), mana
triggers off-stack (CR 605.1b), APNAP trigger stacking, dying creatures
hearing their own dies-triggers (603.6b), 1997 newest-duplicate legend
rule, modal target-spec plumbing, cost-modifier surcharges on both spells
and abilities, aura fizzle/orphan SBAs, Fog, extra turns, X-spells.
