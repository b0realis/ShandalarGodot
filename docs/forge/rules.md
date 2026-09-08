# Forge as a reference for the rules engine — an engineering note

Scope: the rules engine and the card-definition model of Forge (Java, GPLv3,
shallow clone at commit b09a3d3f under `forge/`), read against
`shandalar/engine/` (GDScript, one card = one file, headless-testable) for the
897-card 1997 pool. Every claim carries a `file:line` pointer into one tree or
the other; line numbers are those of the trees as checked out on 2026-09-08.
Paths are abbreviated: `forge/forge-game/src/main/java/forge/game/` is written
`fg/`, `forge/forge-ai/src/main/java/forge/ai/` is `fai/`,
`forge/forge-gui/res/cardsfolder/` is `cards/`, and `shandalar/engine/` is `se/`.

Contents

1. MAP — Forge's engine as a flow
2. THE CARD MODEL — the script DSL and what each line becomes
3. SIDE BY SIDE — ours against Forge, concept by concept, and every ledger row
4. PATTERNS WORTH ADOPTING
5. PATTERNS TO AVOID
6. THE SIMULATION COPY
7. LICENCE AND PROVENANCE

---

## 1. MAP — Forge's engine as a flow

Forge's engine is three Maven modules: `forge-core` (card database and the
script line parser), `forge-game` (rules), `forge-ai` (the AI, including the
simulation copier). A `Game` owns a `PhaseHandler`, a `MagicStack`, a
`TriggerHandler`, a `ReplacementHandler`, `StaticEffects`, a `GameAction`
(zone moves, SBAs, static application) and the players; each `Player` owns a
`ManaPool` and sixteen `PlayerZone`s (`fg/player/Player.java:76-79`).

### 1.1 Casting a spell / activating an ability → resolution

Entry point: `fg/player/PlaySpellAbility.java:581` `playAbility(mayChooseTargets, isFree, skipStack)`.
The order, as the code runs it:

1. Modes first. A Charm (modal) ability chooses its modes before anything
   else, and X if the mode count depends on X — `PlaySpellAbility.java:592-606`
   (`CharmEffect.makeChoices(ability)`; the comment cites CR 603.3c). Mode
   selection itself is `fg/ability/effects/CharmEffect.java:208-260`: it
   resets the sub-ability chain, builds the option list, honours
   `CharmNum`/`MinCharmNum`/`CanRepeatModes`/`Optional`/`Random`, and chains the
   chosen `AbilitySub`s.
2. The card moves to the stack zone before costs are paid —
   `PlaySpellAbility.java:619-626` (`moveToStack`, remembering `fromZone` and
   `zonePosition` for rollback).
3. A `CostPayment` is built from the ability's `Cost` — `PlaySpellAbility.java:637-638`.
4. Pre-cost requisites in one short-circuit expression — `PlaySpellAbility.java:675-679`:
   ```java
   boolean preCostRequisites = announceType() && announceValuesLikeX() &&
       ability.checkRestrictions(player) &&
       (!mayChooseTargets || ability.setupTargets()) &&
       ability.canCastTiming(player) &&
       ability.isLegalAfterStack();
   ```
   X is announced by `announceValuesLikeX` (`PlaySpellAbility.java:736-760`,
   reading the `Announce` parameter and `getAnnouncementBounds`).
5. The stack is frozen (triggers queue instead of firing) and the cost is
   paid — `PlaySpellAbility.java:681-683`:
   ```java
   game.getStack().freezeStack(skipStack ? null : ability);
   final boolean prerequisitesMet = preCostRequisites && (isFree || payment.payCost(...));
   ```
6. Failure rolls back: `GameActionUtil.rollbackAbility(ability, fromZone, zonePosition, payment, c)`
   or `payment.refundPayment()` — `PlaySpellAbility.java:687-713`.
7. Success: `game.getStack().addAndUnfreeze(ability)` — `PlaySpellAbility.java:727`
   (or `AbilityUtils.resolve(ability)` immediately when `skipStack`,
   `PlaySpellAbility.java:720`).

Cost payment: `fg/cost/CostPayment.java:136-176` `payCost`. It adjusts the cost
(`CostAdjustment.adjust` — reductions and surcharges), lets the player order
the parts when there is more than one (`orderCosts`, line 141-143), then for
each `CostPart` pushes it on `game.costPaymentStack`, asks the decision maker
(`part.accept(decisionMaker)` → `PaymentDecision`) and pays as decided
(`part.payAsDecided`, line 158). Cost parts are one class per kind under
`fg/cost/` (CostTap, CostSacrifice, CostPayLife, CostDiscard, CostExile,
CostRemoveCounter, CostReturn, CostReveal, CostTapType, CostUntap, …);
`fg/cost/Cost.java:290` `parseCostPart` maps the script tokens (`T`,
`PayLife<1>`, `Sac<1/Creature>`, `Discard<1/Random>` …) to them.

Mana abilities never touch the stack: `fg/zone/MagicStack.java:271-305` —
`if (sp.isManaAbility())` runs `checkStaticAbilities`, fires
`SpellAbilityCast`/`AbilityCast` triggers, `AbilityUtils.resolve(sp)`, then
`AbilityResolves`, and returns before the stack is touched. Triggers raised
during a cost payment are held (`collectTriggerForWaiting`, line 302-303).

Stack entry: `MagicStack.java:250` `add(SpellAbility, SpellAbilityStackInstance, id)`;
a stack over 999 items is declared a draw (line 261-267).

Resolution: `MagicStack.java:567-645` `resolveStack`:
freeze, `resetPriority` (active player gets priority after resolution, line
582), `hasFizzled` (all targets illegal → fizzle, line 587), `copyLastState`
(LKI), then `AbilityUtils.resolve(sa)` for API-based abilities (line 616)
followed by `TriggerType.AbilityResolves`; then `checkStaticAbilities`
(line 636) and `finishResolving` (line 647-661: remove from stack, unfreeze,
`PhaseHandler.onStackResolved`). Effects are dispatched by
`fg/ability/AbilityUtils.java` `resolve` → `resolveApiAbility`: it checks
conditions (`sa.metConditions()`), handles `UnlessCost` (see §2.3), and walks
`SubAbility` chains (`AbilityUtils.java:1391-1400`). The effect class is
looked up from the `ApiType` enum: `fg/ability/ApiType.java:245`
`getSpellEffect()`; 205 effect classes live under `fg/ability/effects/`.

### 1.2 Triggers → stack

`fg/trigger/TriggerHandler.java:243-262` `runTrigger(mode, runParams, holdTrigger)`:
"Always" triggers run as state triggers; while the stack is frozen (cost
payment, resolution, SBAs) the event is parked in `waitingTriggers`
(line 257-258, never for `TapsForMana`/`ManaAdded`); otherwise it runs at once.
`runWaitingTriggers` (line 272-285) drains the queue.
A matched trigger becomes a `WrappedAbility` around the ability named by its
`Execute$` SVar (`TriggerHandler.java:456-470`), and is placed in the stack's
*simultaneous entry* list, not on the stack —
`TriggerHandler.java:530` `game.getStack().addSimultaneousStackEntry(wrapperAbility)`.
The list is flushed in APNAP order when a player would receive priority:
`fg/zone/MagicStack.java:826-850` `addAllTriggeredAbilitiesToStack` walks
`game.getPlayersInTurnOrder(playerTurn)` twice (non-"AbilityTriggered" first),
each player ordering their own (`chooseOrderOfSimultaneousStackEntry`,
line 852). Optional triggers ask through `OptionalDecider`
(`TriggerHandler.java:456-545`). There are 142 trigger classes under
`fg/trigger/` (one per `TriggerType`). Delayed triggers are a list on the
handler (`TriggerHandler.java:48` `delayedTriggers`) registered by
`DelayedTriggerEffect` (`fg/ability/effects/DelayedTriggerEffect.java`, 97 lines).

### 1.3 Replacement effects

`fg/replacement/ReplacementHandler.java:187-208` `run(event, runParams)`:
the decider is the affected player, or the affected card's controller
(line 193-197); then every `ReplacementLayer` is tried in enum order —
`fg/replacement/ReplacementLayer.java`: `CantHappen` (614.17), `Control`
(616.1b), `Copy` (616.1c), `Transform` (616.1d), `Other`. Within a layer
(`ReplacementHandler.java:210-283`) the decider chooses one of the applicable
effects (`chooseSingleReplacementEffect`, line 222; "can't" effects are
never a choice, line 218-219), it is executed, and a result of `Updated`
re-runs the whole event with the modified parameters (line 244-268, citing
CR 614.16). `fg/replacement/ReplacementType.java` has 41 event kinds
(AddCounter, DamageDone, Destroy, Draw, Moved, Tap, Untap, BeginPhase,
DeclareBlocker, LoseMana, GameLoss …), ~47 classes under `fg/replacement/`.
Prevention shields are replacement effects on Effect cards in the command
zone (see §2.3); `ReplacementHandler.java:886-911`
`getTotalPreventionShieldAmount` sums them by looking for `DamageDone`
replacements carrying `PreventionEffect`.

### 1.4 Static (continuous) effects — layers, timestamps, dependency

`fg/staticability/StaticAbilityLayer.java`: `COPY, CONTROL, TEXT, TYPE,
COLOR, ABILITIES, CHARACTERISTIC (7a), SETPT (7b), MODIFYPT (7c), RULES (8)`,
plus a `CONTINUOUS_LAYERS_WITH_DEPENDENCY` subset (the layer 7d switch is
commented out). Application is `fg/GameAction.java:1076-1200`
`checkStaticAbilities`:

```java
game.getStaticEffects().clearStaticEffects(affectedCards, affectedPerLayer);   // :1088
...
staticAbilities.sort(effectOrder);                                              // :1116
for (final StaticAbilityLayer layer : StaticAbilityLayer.CONTINUOUS_LAYERS) {  // :1119
    ...
    while (!staticsForLayer.isEmpty()) {
        StaticAbility stAb = staticsForLayer.get(0);
        if (!stAb.isCharacteristicDefining()) {
            stAb = findStaticAbilityToApply(layer, staticsForLayer, preList, affectedPerAbility, dependencies);
```
`effectOrder` (`GameAction.java:82-83`) is "characteristic-defining first,
then timestamp". Every recalculation starts from the printed state
(`clearStaticEffects`) and re-applies everything, layer by layer.

Dependency (CR 613.8) is real: `GameAction.java:1273-1390`
`findStaticAbilityToApply` trial-applies each pair, records an edge when
applying one changes what the other affects, builds a JGraphT
`DefaultDirectedGraph`, deletes cycles with `SzwarcfiterLauerSimpleCycles`
(line 1364-1371, "CR 613.8b"), removes every vertex that still depends on
another, and returns the earliest timestamp among what is left
(line 1381-1387). The whole graph is only built when the earliest effect has
a dependency (line 1355-1360 "when lucky…").

A static's "as long as" condition is generic: `fg/staticability/StaticAbility.java:362-470`
`checkConditions` evaluates `IsPresent`/`PresentCompare`/`PresentZone`,
`CheckSVar`/`SVarCompare`, `GameStage`, `ClassLevel`, and (further down)
player/phase conditions. Sixty-four `StaticAbility*` classes under
`fg/staticability/` implement the non-continuous modes (CantTarget,
CantAttackBlock, ReduceCost, CantBeCast, MustBlock, ManaConvert …).

### 1.5 State-based actions

`fg/GameAction.java:1397-1648` `checkStateEffects(runEvents, affectedCards)`.
It checks game-over first (line 1402), freezes the stack, then loops up to
nine times (`for (int q = 0; q < 9; q++)`, line 1417) while anything
changed. Each pass: `checkStaticAbilities` (line 1421); for every permanent —
toughness ≤ 0 → `noRegCreats` (704.5f, line 1455-1457), lethal damage or
deathtouch → `desCreats` (704.5g/h, line 1473-1479), aura not attached →
`noRegCreats` (line 1509-1513), +1/+1 and -1/-1 annihilation (704.5q,
line 1490); per player the legend rule (`handleLegendRule`, line 1535) and
planeswalkers; the world rule (line 1560-1561); then ordering of
simultaneous deaths by owner (`orderCardsByTheirOwners`, line 1567-1580),
the graveyard moves, and a final `checkGameOverCondition` (line 1627).
Triggers collected during the pass are queued and run after it
(`collectTriggerForWaiting` / `runWaitingTriggers`). The legend rule is the
MODERN one only — `GameAction.java:2006-2060` `handleLegendRule` indexes
legendaries by name and lets the controller `chooseSingleEntityForEffect`
"the one to stay on battlefield" (line 2043-2045); there is no 1995
"newest is buried" variant anywhere in the tree.

### 1.6 Turn, phase and priority loop

`fg/phase/PhaseHandler.java:1039-1160` `mainLoopStep`. With priority
enabled, it loops: SBAs and triggers (`checkStateBasedEffects`, line 1051,
defined at 1162-1180 — `checkStateEffects` then
`addAllTriggeredAbilitiesToStack`, repeated while triggers keep landing),
`game.stashGameState()`, then `chooseSpellAbilityToPlay()` of the priority
player (line 1057). When a player passes, the pass bookkeeping is CR 117.3c
shaped — `pFirstPriority` is the player who last acted; when the pass
returns to them (`pFirstPriority == nextPlayer`, line 1131) and the stack is
empty the step ends (`onPhaseEnd`, `advanceToNextPhase`, `onPhaseBegin`,
line 1139-1142), otherwise the top of the stack resolves
(`resolveStack`, line 1145). `onPhaseBegin` (line 240-420) performs the
turn-based actions per step: untap (`game.getUntap().executeUntil/executeAt`,
line 260-263 — phasing runs from `fg/phase/Untap.java:73` → `doPhasing`
198-225), upkeep, draw, `COMBAT_BEGIN` creates `new Combat(playerTurn)`
(line 300), `COMBAT_DECLARE_ATTACKERS` / `COMBAT_DECLARE_BLOCKERS` freeze the
stack around the declaration (line 305-318),
`COMBAT_FIRST_STRIKE_DAMAGE` runs only if `combat.assignCombatDamage(true)`
found a first striker, otherwise the step is skipped
(line 321-331), `COMBAT_DAMAGE` (line 334-343), `COMBAT_END` runs
`onEndOfCombat` on every permanent (line 345-352). `onPhaseEnd`
(line 453-470) empties every mana pool and charges mana burn when
`ManaPool.hasBurn()` (line 458-466, `loseLife(burn, false, true, null)`).

### 1.7 Combat

Declaration legality lives in `fg/combat/CombatUtil.java` (1039 lines):
`canAttack` (line 133-195), `canBlock(attacker, blocker, nextTurn)`
(line 988-1018 — shadow, then `StaticAbilityCantAttackBlock.cantBlockBy`;
flying, landwalk, protection, "can't be blocked by" are all `CantBlockBy`
statics, see §2.2), `canBeBlocked` (516, 568), `validateBlocks` (638-760:
must-block, lure, "blocks each combat if able", minimum blocker counts).
Bands: `fg/combat/AttackingBand.java:29-55` `isValidBand(band, shareDamage)` —
starting a band needs all but one member to have banding, sharing damage
needs one; `BANDSWITH` keywords are matched by their `Valid` filter.
Damage: `fg/combat/Combat.java:761-830` `assignAttackersDamage` — the
assigning player is the attacker's controller, or the first blocker's
controller when the blockers form a valid band (`isValidBand(orderedBlockers, true)`,
line 801-803); "Defensive Formation" flips it (line 798-800); trample at
line 818. Blocker order is the attacker's choice
(`orderBlockersForDamageAssignment`, line 466-500) and attacker order the
defender's (`orderAttackersForDamageAssignment`, line 540-547).
`dealDamageThisPhase` (line 906-916) decides who deals damage in the
first-strike step (double or first strike) and the regular step (double
strike, or anyone who has not dealt first-strike damage);
`assignCombatDamage` (918-926) and `dealAssignedDamage` (928-940 →
`GameAction.dealDamage`, one `CardDamageTable` so replacement and prevention
see the whole wave). `fg/GameRules.java` carries `orderCombatants` and
`manaBurn` as match options (lines 1-60).

### 1.8 Mana pool and mana abilities

`fg/mana/ManaPool.java:51` — `ArrayListMultimap<Byte, Mana> floatingMana`:
each unit of mana is a `Mana` object that remembers its source card, the
mana part that produced it and its restrictions (`fg/mana/Mana.java:77`);
payment (`payManaFromAbility` 209, `tryPayCostWithColor` 228,
`payManaCostFromPool` 337) matches units to shards, `refundMana` (308) puts
them back on a rollback. `hasBurn()` (`ManaPool.java:111-114`) is
`GameRules.hasManaBurn() || StaticAbilityUnspentMana.hasManaBurn(owner)`;
`clearPool` (117) runs the `LoseMana` replacement. Mana abilities are
`SpellAbility`s whose `AbilityManaPart` produces mana; they resolve inside
`MagicStack.add` as shown in §1.1 and can be invoked from inside a cost
payment (`fg/player/HumanPlay`-style controllers call them while paying).

---

## 2. The card model

### 2.1 The script format

A Forge card is a UTF-8 text file in `cards/<initial>/<name>.txt`. Each line
is `Key:Value`; the keys that matter for rules are `Name`, `ManaCost`,
`Types`, `PT`, `K:` (keyword), `A:` (ability), `T:` (trigger), `R:`
(replacement), `S:` (static), `SVar:` (named string variable) and `Oracle`
(`forge/docs/Card-scripting-API/Card-scripting-API.md:24-43`). Lines are
parsed in `forge/forge-core/src/main/java/forge/card/CardRules.java`
(the `switch` on the first character: `'A'` 713, `'K'` 772, `ManaCost` 794,
`Name` 802, `Oracle` 809, `PT` 815, `'R'` 820, `'S'` 826, `SVar` 841, `'T'`
854, `Types` 857). `AI:`, `DeckHints:`, `DeckHas:` and `SVar:PlayMain1`-style
lines are deck-builder and AI hints kept in the same file.

Four whole scripts from the 1997 pool:

**A creature with keywords** — `cards/s/serra_angel.txt`:
```
Name:Serra Angel
ManaCost:3 W W
Types:Creature Angel
PT:4/4
K:Flying
K:Vigilance
Oracle:Flying, vigilance
```

**A spell with X and a variable number of targets** — `cards/f/fireball.txt`:
```
Name:Fireball
ManaCost:X R
Types:Sorcery
S:Mode$ RaiseCost | ValidCard$ Card.Self | Type$ Spell | Amount$ IncreaseCost | Relative$ True | EffectZone$ All | Description$ This spell costs {1} more to cast for each target beyond the first.
A:SP$ DealDamage | ValidTgts$ Any | NumDmg$ X | TargetMin$ 0 | TargetMax$ MaxTargets | DivideEvenly$ RoundedDown | SpellDescription$ CARDNAME deals X damage divided evenly, rounded down, among any number of targets.
SVar:X:Count$xPaid
SVar:MaxTargets:SVar$MaxPlayers/Plus.MaxPermanents
SVar:MaxPlayers:PlayerCountPlayers$Amount
SVar:MaxPermanents:Count$Valid Any
SVar:IncreaseCost:TargetedObjects$Amount/Minus.1
Oracle:...
```

**A card with a trigger, a replacement and a counter-driven upkeep** —
`cards/c/cocoon.txt` (comment line and hints included as they appear):
```
Name:Cocoon
ManaCost:G
Types:Enchantment Aura
K:Enchant:Creature.YouCtrl:creature you control
SVar:AttachAILogic:Pump
T:Mode$ ChangesZone | Origin$ Any | Destination$ Battlefield | ValidCard$ Card.Self | Execute$ TrigTap | TriggerDescription$ When this Aura enters, tap enchanted creature and put three pupa counters on this Aura.
SVar:TrigTap:DB$ Tap | Defined$ Enchanted | SubAbility$ DBPutCounter
SVar:DBPutCounter:DB$ PutCounter | CounterType$ PUPA | CounterNum$ 3
R:Event$ Untap | ActiveZones$ Battlefield | ValidCard$ Creature.AttachedBy | ValidStepTurnToController$ You | Layer$ CantHappen | IsPresent$ Card.Self+counters_GE1_PUPA | Description$ Enchanted creature doesn't untap during your untap step if this Aura has a pupa counter on it.
T:Mode$ Phase | Phase$ Upkeep | ValidPlayer$ You | TriggerZones$ Battlefield | Execute$ TrigRemoveCounter | TriggerDescription$ At the beginning of your upkeep, remove a pupa counter from this Aura. If you can't, sacrifice it, put a +1/+1 counter on enchanted creature, and that creature gains flying. (This effect lasts indefinitely.)
SVar:TrigRemoveCounter:DB$ RemoveCounter | Defined$ Self | CounterType$ PUPA | CounterNum$ 1 | RememberRemoved$ True | SubAbility$ TrigPutCounter
# TODO: need EnchantedLKI because it isn't enchanted anymore if this is sacrificed
SVar:TrigPutCounter:DB$ PutCounter | Defined$ Enchanted | CounterType$ P1P1 | CounterNum$ 1 | ConditionCheckSVar$ X | ConditionSVarCompare$ LE0 | SubAbility$ TrigPump
SVar:TrigPump:DB$ Pump | Defined$ Enchanted | KW$ Flying | Duration$ Permanent | ConditionCheckSVar$ X | ConditionSVarCompare$ LE0 | SubAbility$ TrigSac
SVar:TrigSac:DB$ Sacrifice | ConditionCheckSVar$ X | ConditionSVarCompare$ LE0 | SubAbility$ DBCleanup
SVar:DBCleanup:DB$ Cleanup | ClearRemembered$ True
SVar:X:Count$RememberedSize
AI:RemoveDeck:Random
DeckHas:Ability$Counters
Oracle:...
```
(The `# TODO` is Forge's own: the sacrifice runs before the +1/+1 counter
and the flying grant, and the Aura is no longer attached at that point.
Ours, `shandalar/cards/sets/leg/cocoon.gd:85-96`, reads the host first,
then sacrifices, then puts the counter and grants flying — the order the
card text asks for.)

**An enchantment with a static** — `cards/c/crusade.txt`:
```
Name:Crusade
ManaCost:W W
Types:Enchantment
S:Mode$ Continuous | Affected$ Creature.White | AddPower$ 1 | AddToughness$ 1 | Description$ White creatures get +1/+1.
SVar:PlayMain1:TRUE
SVar:NeedsToPlayVar:CountOpps LTCountMe
SVar:CountOpps:Count$Valid Creature.OppCtrl+White/LimitMax.5
SVar:CountMe:Count$Valid Creature.YouCtrl+White
Oracle:White creatures get +1/+1.
```

### 2.2 How a line becomes a runtime object

1. **File → `CardRules`** (forge-core, no game knowledge). `CardRules.java`
   keeps the lines as strings; `A:`/`T:`/`R:`/`S:` go into per-face string
   lists, `K:` into a keyword list, `SVar:` into a map (pointers in §2.1).
2. **`CardRules` → `Card`**: `fg/card/CardFactory.readCardFace` 346-412. Lines
   380-412 do, in order: `setSVar` for every SVar, `ReplacementHandler.
   parseReplacement` for each `R:`, `addStaticAbility` for each `S:`,
   `TriggerHandler.parseTrigger` for each `T:`, `addIntrinsicKeywords` for
   each `K:`.
3. **Keywords → traits**: `fg/card/CardFactoryUtil.java` (4147 lines) turns
   a keyword into the statics, triggers and replacements that implement it
   (table in §2.3). This is the step our engine does not have: our keywords
   are enum flags checked by the rules code directly (`se/core/mtg.gd:106`
   `enum Keyword { FLYING, REACH, VIGILANCE, HASTE, TRAMPLE, DEFENDER,
   FIRST_STRIKE, MUST_ATTACK, BANDING, UNBLOCKABLE, FEAR }`).
4. **`A:` → `SpellAbility`**: `CardFactoryUtil.addAbilityFactoryAbilities`
   → `fg/ability/AbilityFactory.getAbility` 135-162 / 200-260. The prefix
   picks the class: `SP$` = spell, `AB$` = activated ability (with a `Cost$`),
   `DB$` = drawback (a sub-ability chained by `SubAbility$`), `ST$` = static
   ability's sub-effect. `ValidTgts$` builds a `TargetRestrictions`
   (`readTarget`); `Cost$` goes through `fg/cost/Cost.parseCostPart` 290.
5. **The `ApiType` word → effect class**: `fg/ability/ApiType.java:245`
   `getSpellEffect()`; each of the 205 enum entries names a class in
   `fg/ability/effects/` — `DealDamage` → `DamageDealEffect` (303 lines),
   `PutCounter` → `CountersPutEffect` (805), `Pump` → `PumpEffect` (508),
   `ChangeZone` → `ChangeZoneEffect` (1705), `Destroy` → `DestroyEffect`
   (107), `Clone` → `CloneEffect` (207), `CopyPermanent` →
   `CopyPermanentEffect` (328), `GainControl` → `ControlGainEffect` (281),
   `Animate` → `AnimateEffect` (353), `Phases` → `PhasesEffect` (126).
6. **`SVar` lookups** happen at resolution time, by string:
   `AbilityUtils.xCount` 1566 (`Count$` 1587-1589, `SVar$` 1591-1594,
   `/Plus.`/`/Minus.`/`/LimitMax.` suffixes via `doXMath`). `SVar:X:Count$xPaid`
   is how Fireball's X reaches `NumDmg$ X`; the announced value was stamped
   on the spell by `PlaySpellAbility.announceValuesLikeX` 736-760.

So for Serra Angel: two `K:` lines → `Keyword.FLYING`/`VIGILANCE` in the
intrinsic keyword list → `CardFactoryUtil` expands `Flying` into
`S:Mode$ CantBlockBy | ValidBlocker$ Creature.withoutFlying+withoutReach`
(3910-3913) and `Vigilance` into `S:Mode$ AttackVigilance` (4026-4028); the
rest is the generic creature-spell `PermanentCreature` API. Ours:
`shandalar/cards/sets/2ed/serra_angel.gd:15`
`.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])`, checked in
`se/mtg_game.gd` combat code directly.

For Fireball: `S:Mode$ RaiseCost` becomes a `StaticAbility` in the cost
adjustment pass (`CostAdjustment.adjust`, called from `CostPayment.payCost`
141); `A:SP$ DealDamage` becomes a `Spell` whose effect is `DamageDealEffect`
with `DivideEvenly$` handled inside it; the five `SVar` lines are strings
evaluated by `xCount`. Ours: `2ed/fireball.gd:18`
`.with_extra_cost_per_target(1)` (a builder flag read by `cast_spell`,
`se/mtg_game.gd:1880`) and a 12-line `FireballEffect` subclass whose
`resolve_multi` (`2ed/fireball.gd:28`) divides by integer division.

For Cocoon: the `T:Mode$ ChangesZone` line becomes a `TriggerChangesZone`
object; `Execute$ TrigTap` is resolved at trigger time by looking the SVar
up and building a `WrappedAbility` (`TriggerHandler.runSingleTriggerInternal`
456-545); `R:Event$ Untap ... Layer$ CantHappen` becomes a `ReplaceUntap`
in the `CantHappen` layer consulted from `Card.canUntap` 4683; `T:Mode$ Phase
| Phase$ Upkeep | ValidPlayer$ You` becomes a `TriggerPhase`
(`fg/trigger/TriggerPhase.java:49-57`). Ours: `leg/cocoon.gd:30-40` builds a
`StaticAbility` (`_lock` sets `host.cur_skips_untap = true`, line 65),
an ETB `TriggeredAbility` (`_spin`, 72-78) and an `UPKEEP_START`
`TriggeredAbility` with a condition (`_own_upkeep`/`_hatch`, 81-96).

For Crusade: one `S:` line → `StaticAbilityContinuous` applied in layer 7c
each time `checkStaticAbilities` runs (§1.4). Ours: `2ed/crusade.gd:14`
`StaticAbility.new(_apply, "White creatures get +1/+1.")` where `_apply`
(18-21) loops `game.all_battlefield()` and adds +1/+1 to white creatures
during `ContinuousEffects.recalculate` (`se/continuous.gd:605`).

### 2.3 Keyword table (1997 pool)

`fg/keyword/Keyword.java` has 203 entries; the ones the 1997 pool needs:

| Keyword | Keyword.java | Implemented as | Where |
|---|---|---|---|
| Flying | 89 | static `CantBlockBy | ValidBlocker$ Creature.withoutFlying+withoutReach` | CardFactoryUtil 3910-3913 |
| First strike / Double strike | 85 | native: `Card.hasFirstStrike` 1693-1700; two damage steps `Combat.dealDamageThisPhase` 906-916; step skipped unless `combat.assignCombatDamage(true)` PhaseHandler 321-331 | rules code |
| Trample | 195 | native: `Combat.assignAttackersDamage` 818 | rules code |
| Vigilance | 206 | static `Mode$ AttackVigilance` | CardFactoryUtil 4026-4028 |
| Haste | 100 | native: `Card.hasSickness` 3636 | rules code |
| Protection | 148 | one replacement (`Event$ DamageDone | Prevent$ True`, 2582-2591) + three statics (`CantBlockBy` 3956-3964, `CantTarget` 3965-3972, `CantAttach` 3973-3988) | CardFactoryUtil |
| Landwalk | 116 | static `CantBlockBy | ValidDefender$ Player.controls<type>` | CardFactoryUtil 3943-3945 |
| Banding / "bands with other" | 23, 24 | native: `fg/combat/AttackingBand.isValidBand` 29-55; damage assigned by the band's controller `Combat.assignAttackersDamage` 801-803 | rules code |
| Rampage N | 153 | trigger `AttackerBlocked` → `DB$ Pump` | CardFactoryUtil 1622-1640 |
| Flanking | 86 | trigger | CardFactoryUtil 1096 |
| Cumulative upkeep | 45 | upkeep trigger + counter + `UnlessCost` | CardFactoryUtil 860-877 |
| Phasing | 145 | native: `fg/phase/Untap.doPhasing` 198-225 | rules code |
| Shadow (Tempest, not in pool) | — | `CombatUtil.canBlock` 997-1010 | rules code |

Ours: `Mtg.Keyword` flags for the native ones; builder methods for the rest
(`se/core/card_data.gd`: `with_protection_from` 356, `with_landwalk` 361,
`with_cant_be_blocked_by` 367, `with_rampage` 395, `with_extra_blocks` 385,
`with_skip_turn_to_untap` 415, `with_enters_counters` 420,
`with_sacrifice_if_you_control` 440, `with_enters_as_copy` 457,
`with_extra_cost_per_target` 679, `with_colored_x` 691,
`with_cost_modifier` 747). Both engines implement the combat keywords
natively; the difference is that Forge also routes Flying, Vigilance,
Landwalk, Protection and Rampage through the generic static/trigger/
replacement machinery so that "loses all abilities" and "gains flying until
end of turn" fall out for free. Ours keeps them as flags in
`ContinuousEffects` (`se/continuous.gd:331` `_keywords`, 286 `_landwalk`,
298 `_rampage`, 320 `_protection`) recalculated per layer, which gives the
same result for the pool without a string round-trip.

### 2.4 Mechanic by mechanic — does Forge have it, and where

| Mechanic | Forge | Ours |
|---|---|---|
| "As long as ..." | condition parameters on the static: `IsPresent$`/`PresentCompare$`/`PresentZone$`, `CheckSVar$`/`SVarCompare$`, evaluated in `StaticAbility.checkConditions` 362-470 every `checkStaticAbilities`. E.g. `cards/w/winter_orb.txt` `S:Mode$ Continuous | ... | IsPresent$ Card.Self+untapped` | the static's `apply` Callable tests the condition itself before adding anything (`se/abilities/static_ability.gd:37`), re-run on every `recalculate` |
| "Until end of turn" | `Duration$` parameter; absent = end of turn. `PumpEffect` 94-122 registers a `GameCommand` via `SpellAbilityEffect.addUntilCommand` 948-1003 (`UntilEndOfCombat`, `UntilYourNextUpkeep`, `UntilYourNextTurn`, `UntilHostLeavesPlay`, `Permanent`...); commands run from `PhaseHandler` cleanup 400-408 `getEndOfTurn().executeUntil()` | `ContinuousEffects.add_until_eot_pump` 229, `add_until_eot_loss` 385, `expire_until_eot` 491, `expire_upkeep_of` 504, `expire_end_of_upkeep_of` 519, `expire_end_of_combat` 536 |
| "At the beginning of your upkeep" | `T:Mode$ Phase | Phase$ Upkeep | ValidPlayer$ You` → `TriggerPhase` 49-57 | `TriggeredAbility.new(Mtg.EventType.UPKEEP_START, ...)` with a condition Callable (`leg/cocoon.gd:36-40`) |
| "You may pay {X}. If you don't, ..." | `UnlessCost$` on the effect; `AbilityUtils.handleUnlessCost` 1403-1441 (`UnlessPayer$`, default `TargetedController`; `UnlessSwitched$`) e.g. `cards/f/force_of_nature.txt` `UnlessCost$ G G G G | UnlessPayer$ You` | per-card: the effect asks `game.try_pay` / a `PlayerChoice` (`se/mtg_game.gd:5418`) |
| "Choose one —" | `Charm` API; modes chosen at cast in `PlaySpellAbility.playAbility` 592-606 (CR 603.3c) via `CharmEffect.makeChoices` 208-260 | `CardData.with_ai_mode` 742 + a mode `PlayerChoice` at cast |
| Counters | `PutCounter`/`RemoveCounter` → `CountersPutEffect` (805 lines; `Optional$` 183), `Card.addCounter`; any string is a counter type | `add_counters` 7195 / `remove_counters` 7210, string-keyed per instance |
| Copy | `Clone` → `CloneEffect` 207; `CopyPermanent` → `CopyPermanentEffect` 328; `K:ETBReplacement:Copy:DBCopy:Optional`; copied characteristics live in per-layer `TreeBasedTable`s on `Card` 126-132 | `become_copy` 4545, `copy_spell_on_stack` 4633, `with_enters_as_copy` 457 → `_apply_enters_as_copy` 6703 |
| Control change | `GainControl` → `ControlGainEffect` 281 (`addTempController` 166); `Card.getController` 3685-3699 takes the latest timestamp in `tempControllers` | `change_control` 7110, `gain_control_until_eot` 7097, `gain_control_leashed` 7563 |
| Phasing | `Untap.doPhasing` 198-225; `Card.isPhasedOut` checked at 658, 1715, 1726, 3966 | `phase_out` 4455 / `phase_in` 4479, `CardInstance.phased_out` (`se/core/card_instance.gd:218`) |
| Banding | `AttackingBand` 29-55; band damage assignment `Combat` 801-803 | `CombatState.bands` (`se/combat.gd:48`), `assign_combat_damage` 9129 |
| Ante | `ZoneType.Ante` (`fg/zone/ZoneType.java:24`); `GameRules.playForAnte` 13 with `matchAnteRarity` 14 and `anteIncludeBasicLands` 15; `Match.java` 82-89 chooses, 360-424 moves ownership; `cards/c/contract_from_below.txt` `Destination$ Ante` | `Mtg.Zone.ANTE` (`se/core/mtg.gd:55`), `all_ante` 4827, `move_to_ante` 4836, `stake_ante` 4922 |
| Regeneration | `Regenerate` → `RegenerateEffect.createRegenerationEffect` 66-100 creates an Effect card in the command zone carrying `R:Event$ Destroy | ValidCard$ Card.IsRemembered | Regeneration$ True`; the destroy path consults `ReplaceDestroy.canReplace` 46-52; the shield count is on `Card` 3465-3497; `RegenerationEffect` 38-52 heals, taps, removes from combat | `CardInstance.regeneration_shields` (137), consumed in `destroy` 3924-3960 with the same three actions; `regeneration_banned_this_turn` 142 for Hurr Jackal |
| Damage prevention shields | `DamagePreventEffect.addPreventNextDamage` 122-150: Effect card with `R:Event$ DamageDone | PreventionEffect$ NextN` and `DB$ ReplaceDamage | Amount$ ShieldAmount`; total via `ReplacementHandler.getTotalPreventionShieldAmount` 886-911 | `MtgPlayer.prevention_shields` 174 / `prevention_shield_filters` 184 / `damage_replacements` 220, consumed in `_plan_damage` 2869 and `_land_damage_impl` 2911; the 1997 prevention window `damage_prevention_request` 3539 |
| Protection | DEBT expansion in §2.3 | `_protection` 320 in `continuous.gd`; `_apply_host_protection` `card_data.gd:715` |
| Legend rule | modern only: `GameAction.handleLegendRule` 2006-2060, the controller chooses (`chooseSingleEntityForEffect` 2043-2045); no option for the 1995 "newest is buried" rule | `check_state_based_actions` 7320 slow pass `_newest_duplicate_legend` — the 1997 rule; the world rule at Forge `GameAction` 2068-2095 has the same shape as ours |
| Mana burn | `GameRules.manaBurn` 8 → `ManaPool.hasBurn` 111-114 → `PhaseHandler.onPhaseEnd` 458-466 `loseLife(burn, false, true, null)` (life loss, not damage) | `RulesOptions.mana_burn` and `_advance_step` 8357 |
| Text change (Magical Hack) | `ChangeText` → `ChangeTextEffect` 233 lines; a real word substitution stored in the text layer of `Card` | `2ed/magical_hack.gd` with a bounded word list (docs/simplified-cards.md row 2) |

Two things Forge does not have that the 1997 game needs:
**the 1995 legend rule** (see row) and **the damage prevention step** — there
is no step in `PhaseType` and no `GameRules` switch; prevention is resolved
by replacement effects the moment damage is dealt. `GameRules.java` 6-27 has
`manaBurn`, `orderCombatants`, `poisonCountersToLose = 10`, `playForAnte`,
`matchAnteRarity`, `anteIncludeBasicLands` and nothing else old-rules
related. Our `RulesOptions.IMPLEMENTED` (`se/rules_options.gd:31-33`) —
`mana_burn`, `attackers_revocable`, `tapped_artifacts_stop`,
`life_checked_at_phase_end`, `pool_empties_on_attack`,
`free_damage_assignment`, `damage_prevention_window` — is a strictly larger
set of old-rules switches than Forge offers.

---

## 3. Side by side

### 3.1 Concept by concept

| Concept | Forge | Ours | Verdict for a 1995 pool |
|---|---|---|---|
| **Stack object** | `SpellAbilityStackInstance` wrapping a `SpellAbility` on a `MagicStack` (`fg/zone/MagicStack.java`); the card itself moves to `ZoneType.Stack` (`addAndUnfreeze` 128-154); resolution in `resolveStack` 567-645 | `StackItem` (`se/stack_item.gd`) with `cost_paid`, targets and a resolver; `pass_priority` 2354 → `_resolve_top` 5681 with a `_preflight` (5799) that rewinds through `GameSnapshot` on an illegal resolution | Equivalent. Ours has the pre-flight rewind Forge lacks (Forge relies on `hasFizzled` 587 and LKI copies). |
| **Freeze during casting** | `freezeStack` 120-126 while costs are paid; `addAndUnfreeze` 128-154 puts the object on the stack, then `unfreezeStack` 155-167 pops `frozenStack` and `runWaitingTriggers` | none: `cast_spell` 1858 pays, appends, and `dispatch_event` runs triggers as they come (ROADMAP row 2679 — "triggers that fire while a cost is being paid go on the stack BELOW the object") | Forge is more correct here (CR 603.3: triggers wait until a player would receive priority). See §4.1. |
| **Triggers** | `TriggerHandler.runTrigger` 243-262 with a `waitingTriggers` queue when frozen; `runSingleTriggerInternal` 456-545 builds a `WrappedAbility`; `MagicStack.addAllTriggeredAbilitiesToStack` 826-850 orders APNAP via `getPlayersInTurnOrder`; 142 trigger classes; `delayedTriggers` TriggerHandler:48 | `dispatch_event` 7711 with `_trigger_index`, APNAP seats `[active_player, opponent_of(active_player)]`, `cur_abilities_silenced`, mana triggers immediate (CR 605.1b); `_push_trigger` 7808 with `_arm_trigger_targets` 7848 (CR 603.3d); `schedule_delayed_trigger` 6884 | Equivalent in reach; ours does the graveyard/exile listeners by zone at `UPKEEP_START`/`END_STEP_START` (Nether Shadow) where Forge uses `TriggerZones$ Graveyard`. |
| **Replacement** | one mechanism: `ReplacementHandler.run` 187-283, 41 `ReplacementType`s, five `ReplacementLayer`s, the affected player/controller decides among several (193-197, 222), `Updated` results re-run the event (244-268, CR 614.16) | per-kind hooks: draws `_replace_draw` 3846 (one-shots then statics in timestamp order), entering `entry_refused` 6618 + `_apply_enters_as_copy` 6703, destruction `destroy` 3924 (indestructible → `destruction_shields` → `regeneration_shields`), damage `_plan_damage` 2869 / `_land_damage_impl` 2911 with `MtgPlayer.prevention_shields` 174, `prevention_shield_filters` 184, `damage_replacements` 220 | Ours covers every replacement the pool has, as code paths. What is missing is the *chooser*: ROADMAP row 2672 (two draw replacements in a fixed order). See §4.2. |
| **Layers** | `StaticAbilityLayer` ten layers; `GameAction.checkStaticAbilities` 1076-1200 clears and re-applies everything in `effectOrder` (CDA first, then timestamp, 82-83); `findStaticAbilityToApply` 1273-1387 builds a JGraphT dependency graph per layer and breaks cycles (CR 613.8b at 1364) | `ContinuousEffects.recalculate` 605-884, "by construction" ordering per layer with no dependency analysis; ROADMAP rows 2666, 2680, 2682 | For 897 cards the only CR 613.8 cases are of the "Conversion + a white creature lord" / "Blood Moon + Urborg" kind, none of which exist in this pool; a limited check is §4.4 (S). |
| **SBAs** | `checkStateEffects` 1397-1648: `for (int q = 0; q < 9; q++)` loop (1417), `checkStaticAbilities` inside (1421), ordered lists per rule, legend rule modern only (2006-2060), world rule (2068-2095) | `check_state_based_actions` 7320: fast pass (toughness ≤ 0, lethal damage, control leashes), slow pass `_sba_watch`, 1997 legend rule `_newest_duplicate_legend` | Ours is the one that matches the 1997 game (the newest legend is buried). Forge cannot be configured to do it. |
| **Turn / priority** | `PhaseHandler.mainLoopStep` 1039-1160, `onPhaseBegin` 240-420, `onPhaseEnd` 453-470 (mana burn), `Untap.doPhasing` 198-225; no damage-prevention step | `_advance_step` 8348 (mana burn 8357), `_untap_step` 8547, `phase_out`/`phase_in` 4455/4479; `RulesOptions` with seven old-rules switches (`se/rules_options.gd:31-33`) including `damage_prevention_window` and `life_checked_at_phase_end` | Ours is ahead: Forge has three of our seven switches (`manaBurn`, `orderCombatants`, ante). |
| **Combat: declaration legality** | `CombatUtil.validateAttackers` 83, `canAttack` 133/159/192, `canBlock` 420-1018 (shadow at 997-1010, then `StaticAbilityCantAttackBlock.cantBlockBy`), `canBeBlocked` 516/568, `validateBlocks` 638-760 | `declare_attackers` 2386, `declare_blockers` 2547 with `_block_restriction` (`se/continuous.gd:425`), `with_cant_block_power_ge`, Lure (`cur_must_be_blocked`), Camouflage map `_camouflage_block_map` 2768 | Equivalent for the pool. |
| **Combat: ordering and damage** | `orderBlockersForDamageAssignment` 466-500 / `orderAttackersForDamageAssignment` 540-547; `assignAttackersDamage` 761-830 (Defensive Formation 798-800, band controller assigns 801-803, trample 818); `dealDamageThisPhase` 906-916 first strike then regular; `dealAssignedDamage` 928-940 fills one `CardDamageTable` and hands it to `GameAction.dealDamage` | `CombatState.damage_order` (`se/combat.gd:88`), `assign_combat_damage` 9129, `_combat_damage_step` 8833, `_has_first_strike_damage` 8867, `_collect_damage_requests` 8889 → `DamagePacket`s, `_after_combat_damage` 9252; `RulesOptions.free_damage_assignment` | Equivalent; ours already has the "one wave" shape (`_collect_damage_requests`). Ours has defensive banding done the 1997 way; Forge has it too (801-803). |
| **Costs** | `Cost` = list of `CostPart`s parsed by `Cost.parseCostPart` 290; `CostPayment.payCost` 136-176 orders the parts, each `part.accept(decisionMaker)`; `CostAdjustment.adjust` for statics like `RaiseCost`/`ReduceCost`; refund on abort `rollbackAbility` 687-713 | `ActivatedAbility` declarative fields (`se/abilities/activated_ability.gd`: `cost` 28, `tap_cost` 31, `sacrifice_cost` 35, `life_cost` 39, `exile_cost` 51, `discard_cost` 293, `counter_cost_kind` 352 …); `can_afford_cost` 5409, `try_pay` 5418, `could_afford` 5573; `CardData.with_cost_modifier` 747 | Equivalent for the pool. Forge's `UnlessCost$` is one generic path where ours writes a `PlayerChoice` per card. |
| **Mana** | `ManaPool` keyed by colour byte (`ArrayListMultimap<Byte, Mana>` :51), each `Mana` remembers its source and restrictions (`Mana.java:77`); `payManaFromAbility` 209, `tryPayCostWithColor` 228, `refundMana` 308, `payManaCostFromPool` 337; mana abilities resolve inside `MagicStack.add` 271-305 | `ManaPool` (`se/core/mana_pool.gd`: `_mana` 26, `_restricted` 29, `can_pay` 102, `pay` 136, `clear` 183); `tap_for_mana` 1347; `ManaPlanner` (`se/mana_planner.gd`) for automatic tapping | Equivalent. Forge has no auto-tap planner in the rules layer — the human controller taps by hand and the AI has `ComputerUtilMana`. Our `try_pay` greedy pick (ROADMAP row 2668) is a planner problem, not a rules one. |
| **Copy** | `CloneEffect` 207 / `CopyPermanentEffect` 328 / `CardCopyService`; copiable values are per-layer timestamped tables on `Card` 126-132; `K:ETBReplacement:Copy:...` for Clone's "as it enters" | `become_copy` 4545, `copy_spell_on_stack` 4633, `with_enters_as_copy` 457 / `_apply_enters_as_copy` 6703; `2ed/clone.gd` is 28 lines | Equivalent (Clone, Vesuvan Doppelganger, Copy Artifact, Fork are the pool's copy cards). |
| **Control** | `ControlGainEffect` 281; `tempControllers` is a timestamp map on `Card` 304, `getController` 3685-3699 takes the latest; `ControlledByPlayer` on the stack item for Word of Command (`MagicStack.resolveStack` 594-596 / 627-632) | `change_control` 7110, `gain_control_until_eot` 7097, `gain_control_leashed` 7563, control leashes in SBA; no "control a player" | Equivalent for permanents. Word of Command is §3.3. |
| **Zones** | `ZoneType` (`fg/zone/ZoneType.java:15-35`): Hand, Library, Graveyard, Battlefield, Exile, Flashback, Command, Stack, Sideboard, Ante, Merged, SchemeDeck, PlanarDeck, AttractionDeck, Junkyard, ContraptionDeck, Subgame, ExtraHand, None; `Zone`/`PlayerZone` objects; LKI copies of leaving cards; layer-6 keyword changes are a timestamped table on `Card` 135 (`changedCardKeywords`) | `Mtg.Zone` (`se/core/mtg.gd:55`) incl. `ANTE`; `CardInstance.zone`; the `LEAVES_BATTLEFIELD` event carries a `memory` snapshot of the departing permanent (`mtg.gd:112-116`, CR 400.7) | Equivalent. Forge's `Command` zone as a home for Effect cards is §4.3. |
| **Undo / copy of state** | `GameCopier` (fai) re-parses every card; `GameSnapshot` (fg) experimental, `Game.EXPERIMENTAL_RESTORE_SNAPSHOT` `Game.java:104` | `GameSnapshot` take+restore 3.44 ms (`se/game_snapshot.gd:51-52`) for the resolution pre-flight; `UndoLog` 0.13 us/field (`se/undo_log.gd:35-36`) behind `make_mark` 661 / `unmake_to` 685 / `end_search` 701 for search nodes; the combat search uses a model of its own (`se/ai/combat_search.gd:62-76`) | Ours is far cheaper (§6). |

Where ours is equivalent or better for this pool: the stack with pre-flight
rewind, the 1997 legend rule, the damage prevention window, life checked at
phase end, revocable attackers, tapped artifacts, the pool emptying on
attack, the whole `RulesOptions` set, the undo journal, and every card being
one GDScript file that a test can load headless. Where Forge handles a case
ours simplifies: the waiting-trigger queue, the replacement chooser, the
layer dependency check, and a single `UnlessCost` path. Each is discussed
in §4.

### 3.2 The fidelity ledger — `docs/simplified-cards.md`

Two rows remain (`shandalar/docs/simplified-cards.md:76-79`).

**Illusionary Mask** (row 78: "goes straight onto the battlefield face down
instead of being CAST as a face-down spell"). Forge script
`cards/i/illusionary_mask.txt`:
```
A:AB$ Play | Cost$ X | Valid$ Card.Creature+YouOwn+CanPayManaCost | ValidZone$ Hand | WithoutManaCost$ True | Amount$ 1 | Controller$ You | Optional$ True | CastFaceDown$ True | ReplaceIlluMask$ True | SorcerySpeed$ True | ...
SVar:X:Count$xPaid
```
`PlayEffect` (562 lines): `CastFaceDown$` at 318-320 swaps the card's spell
for `CardFactoryUtil.abilityCastFaceDown(state, false, "Morph")`
(`CardFactoryUtil.java:80`), i.e. the morph machinery casts a 2/2 face-down
creature spell that really goes on the stack; `ReplaceIlluMask$` at 449-450
calls `addIllusionaryMaskReplace` 529-561 which creates an Effect card in
the command zone with three replacements — `Event$ AssignDealDamage`,
`Event$ DealtDamage`, `Event$ Tap`, each `ValidCard$ Card.IsRemembered+
faceDown` with the overriding ability `DB$ SetState | Defined$ ReplacedCard
| Mode$ TurnFaceUp` and `ReplacementResult Updated` — so the event is
re-run against the face-up card (CR 614.16). Ours
(`shandalar/cards/sets/2ed/illusionary_mask.gd`, 72 lines) has the
face-down permanent (`turn_face_down` 4509 / `turn_face_up` 4521 in
`se/mtg_game.gd`) and the three turn-up moments in the engine; what it
lacks is the spell on the stack. What it would take: a `StackItem` whose
resolver is `_put_on_battlefield` of a face-down `CardInstance` — the
`Counterspell` interaction and the SPELL_CAST event are the only observable
differences. Small (S) once the stack item can carry "resolve as a 2/2
face-down creature" instead of the card's own spell; Forge's morph reuse
shows the shape but drags in morph's up-cost, which the pool does not have.

**Text changes** (row 79: Magical Hack, Sleight of Mind reach subtypes,
landwalk types, protection colours and a basic land's mana, not arbitrary
rules text). Forge `cards/m/magical_hack.txt`: `SP$ ChangeText |
ChangeTypeWord$ ChooseBasicLandType ChooseBasicLandType | Duration$
Permanent`; `ChangeTextEffect` (233 lines) performs a real word
substitution over the card's text and re-parses the affected abilities,
which works because Forge's abilities *are* strings until they are parsed.
Ours stores behaviour as code, so a substitution has nowhere to act; the
bounded word list (owner's ruling 2026-09-07, `simplified-cards.md:62`) is
the right form for this engine. The gap versus Forge is nil for the pool's
actual targets (Forge's own `ChangeTypeWord$` is also limited to what the
type-word grammar recognises); the row stays as a ruling, not a debt.

### 3.3 The someday file — `docs/difficult_cards.someday`

Every card, with Forge's script and effect class, and what it would take
here.

| Card | Forge | Ours today | What it would take |
|---|---|---|---|
| **Chaos Orb** (excluded, `difficult_cards.someday:80-103`, 242) | `FlipOntoBattlefieldEffect` 134 lines; a randomised flip with fixed success chances (0.85 / 0.70 / 0.20 by count of targets) — a software invention, not the physical card | excluded from the pool (`tools/fetch_cards.py`) | Any software Orb is `[QoL]`; Forge's version is one more precedent beside Manalink's "Silly Orb Thing" (someday:99). Not a rules-engine matter. |
| **Falling Star** (excluded, 243) | same effect class, same dice | excluded | same |
| **City in a Bottle** (105-119) | `T:Mode$ Always | IsPresent$ Permanent.!token+setARN+Other` (state trigger, sacrifice) + `CantPlayLand`/`CantBeCast` statics keyed on the set code | `cards/sets/arn/city_in_a_bottle.gd` (65 lines): `CardRegistry.originally_printed_in(name, "arn")` (lines 35, 46, 54) | done; both key on the printing set |
| **Golgothian Sylex** (121-128) | `AB$ SacrificeAll | ValidCards$ Permanent.!token+setATQ` | `cards/sets/atq/golgothian_sylex.gd` (34 lines) | done |
| **Wood Elemental** (130-137) | `K:ETBReplacement:Other:TrigSac` + `SVar:X:Remembered$Amount` + a CDA `SetPower$ X` | `cards/sets/leg/wood_elemental.gd` (104 lines): `.as_it_enters(_feed)` (line 39) with a sacrifice prompt (`PlayerChoice.sacrifice_prompt`, line 87) and a `setting_base_pt()` static (line 43) reading the count | done; Forge's "remembered" list is our per-instance memory |
| **Cocoon** (139-144) | script quoted in §2.1; Forge's own `# TODO` on the sacrifice order | `cards/sets/leg/cocoon.gd` (96 lines), correct order | done |
| **Metamorphosis** (146-152) | `SP$ Mana | Cost$ G Sac<1/Creature> | RestrictValid$ Spell.Creature` — restricted mana in the pool | `cards/sets/arn/metamorphosis.gd` (58 lines): `mana_pool.add_restricted(color, amount, "creature")` (line 37) over `ManaPool._restricted` (`se/core/mana_pool.gd:29`) | done, same shape |
| **Power Artifact** (154-160) | `S:Mode$ ReduceCost | Type$ Ability | Amount$ 2 | MinMana$ 1` — a cost-adjustment static applied by `CostAdjustment` | `cards/sets/atq/power_artifact.gd` (53 lines) via `ActivatedAbility.discounted(2, 1)` (line 48) — a cheaper copy of each ability with a one-mana floor | done |
| **Transmutation** (162-169) | `SP$ Pump | KW$ HIDDEN CARDNAME's power and toughness are switched` — a hidden keyword read by `Card.getNetPower` 4443-4448 in the last P/T layer | `cards/sets/leg/transmutation.gd` (14 lines) via `SwitchPowerToughnessEffect` and `_pt_switch` (`se/continuous.gd:447`, CR 613.4e) | done; ours is the cleaner representation (a layer entry, not a keyword string) |
| **Word of Command** (183, 245) | script in `cards/w/word_of_command.txt`: `RevealHand` → `ChooseCard` (`Choices$ Card.IsRemembered | ChoiceZone$ Hand`) → an Effect card with a `CantBeActivated` static limiting mana abilities → `DB$ Play | Defined$ ChosenCard | Controller$ TargetedPlayer | ControlledByPlayer$ You`; `PlayEffect` 455-459 stamps `setControlledByPlayer` on the spell, `MagicStack.resolveStack` 594-596 / 627-632 swaps the deciding controller for the duration of that resolution; `ControlPlayerEffect` is 48 lines | not implemented | The bounded list form the owner ruled for (someday:245) plus a "decider" field on `StackItem` that `_resolve_top` honours when it asks `PlayerChoice`s: every choice during that resolution goes to the caster's agent. M — the choice plumbing already routes by seat; the new part is a per-item override and the mana restriction ("only lands, only for that spell"). |
| **Camouflage** (183) | `SP$ Effect | ReplacementEffects$ RDeclareBlocker` with `R:Event$ DeclareBlocker | ValidPlayer$ Opponent | ReplaceWith$ DBCamouflage` → `CamouflageEffect` 107 lines (`randomizeBlockers` 21; for the AI "just let it declare blockers normally, then randomize it later" 65) | `cards/sets/2ed/camouflage.gd` (50 lines): sets `camouflage_this_turn` (`mtg_game.gd:239`), `declare_blockers` 2563 runs `_camouflage_block_map` 2768 with the piles built by the defender through `PlayerChoice`s | done; ours asks the defender to build the piles, Forge's AI path skips the piles |
| **False Orders** (183) | `SP$ RemoveFromCombat | UnblockCreaturesBlockedOnlyBy$ Targeted` → `ChooseCard` (`Choices$ Creature.attacking`) → `DB$ Block | DefinedAttacker$ ChosenCard | DefinedBlocker$ ParentTarget`; `RemoveFromCombatEffect` 74, `BlockEffect` 125 | `cards/sets/2ed/false_orders.gd` (96 lines) with `remove_from_combat(inst, unblock_solo_attackers)` 7056 | done; identical decomposition |
| **Illusionary Mask** (183) | §3.2 | §3.2 | S once the stack item can resolve a face-down 2/2 |
| **Shahrazad** (185, 244) | `SP$ Subgame | RememberPlayers$ NotWin` → `SubgameEffect` 248 lines: `new Game(players, maingame.getRules(), maingame.getMatch(), maingame, startingLife)` at :38, decks = current libraries, then `RepeatEach` over the losers with `LoseLife | LifeAmount$ X` where `SVar:X:PlayerCountRemembered$LifeTotal/HalfUp` | excluded (someday:244: "needs a second MtgGame on the same seats") | Engine side: an `MtgGame.new()` fed the two libraries as decks, the same two `DecisionAgent`s, run to game over, then `lose_life(half, rounded up)` on the losers — the engine is a `RefCounted` with no scene dependency so this is L only because of the screen (someday:244 says the same). Forge's `SubgameEffect` confirms the decomposition. |

Everything in the eight-hidden list and in the Manalink-2009 list except
Word of Command, Shahrazad and the two dexterity cards is implemented here,
and each of those implementations has the same decomposition Forge uses.

### 3.4 The engine rows in `docs/ROADMAP.md` (2656-2685) against Forge

| Row | Forge | Note |
|---|---|---|
| 2660 greedy prevention pool across packets | Forge has no pool: each shield is its own replacement with `PreventionEffect$ NextN`, and `ReplacementHandler.run` asks the affected player which applies first (222) — spreading Healing Salve over three packets falls out of that choice | our `damage_prevention_request` 3539 window already asks; the pool is a representation choice, see §4.2 |
| 2662 "X target creatures" takes as many as exist | `TargetMin$`/`TargetMax$` are checked at cast in `setupTargets` (`PlaySpellAbility` 675-679); a smaller X must be announced first (`announceValuesLikeX` 736-760, CR 601.2c order: X before targets) | same fix as the row proposes: announce X, then validate `target_range` (`se/effects/effect_base.gd:144`) |
| 2666 simplified layers, 2682 no dependency analysis | `findStaticAbilityToApply` 1273-1387 | §4.4 |
| 2668 `try_pay` auto-taps lands greedily | Forge's rules layer never auto-taps; the AI has `ComputerUtilMana` (fai) | not a rules problem; our `ManaPlanner` is the right home |
| 2671 draw replacement asked outside a resolution | Forge's `ReplacementHandler.run` runs synchronously inside the draw (`Player.drawCards` → `ReplacementType.Draw`), asking through the controller at that moment | ours asks the same way but records it as a turn-based question; nothing to port |
| 2672 two draw replacements in fixed order | `ReplacementHandler.run` 193-197 + `chooseSingleReplacementEffect` 222: the affected player chooses among the applicable ones (CR 616.1) | §4.2 |
| 2678 delayed triggers | `delayedTriggers` in `TriggerHandler` 48 + `DelayedTriggerEffect` (97 lines); each is a real trigger with a `Mode$` | ours narrowed to `schedule_delayed_trigger` 6884; equivalent |
| 2679 triggers during cost payment | `freezeStack` / `waitingTriggers` / `unfreezeStack` (§3.1) | §4.1 |
| 2680 until-EOT loss beats later grant | Forge: keyword changes in layer 6 are a timestamped table (`Card.java:135` `changedCardKeywords`, `TreeBasedTable` keyed by timestamp); a later grant beats an earlier loss | §4.4 (the same S change) |
| 2684 `could_afford` under-reports for Sunglasses of Urza / North Star | `ManaPool` colour substitution is per-`Mana` (`Mana.java:77` restrictions) and `ComputerUtilMana` searches sources; Forge's AI would also mis-price these two | no help from Forge |
| 2685 AI forward combat one blocker per attacker | `AiBlockController` (fai) does multi-block; out of scope for the rules slice | — |

---

## 4. Patterns worth adopting

Each entry: what Forge does, what it fixes here, size, and the risk to an
engine that is pure GDScript, headless-testable, and keeps one card per
file.

### 4.1 A waiting-trigger queue with a single APNAP flush — **S**

Forge: `TriggerHandler.runTrigger` 243-262 parks a trigger in
`waitingTriggers` while the stack is frozen; `MagicStack.freezeStack`
120-126 is set before costs are paid (`PlaySpellAbility.playAbility`
681-683) and `addAndUnfreeze` 128-154 puts the spell on the stack *then*
calls `unfreezeStack` 155-167, which runs `runWaitingTriggers` 272-285 →
`addAllTriggeredAbilitiesToStack` 826-850 in APNAP order.

Fixes: ROADMAP row 2679. In `se/mtg_game.gd` `cast_spell`, the additional
sacrifice at ~1948 (`sacrifice_permanent(extra_sacrifice)`) and the mana
payment at ~1942 happen before `stack.append(item)` at 1990, so a DIES or
TAPPED trigger raised by paying the cost is appended by `_push_trigger`
(`stack.append` 7816) *below* the spell. Under CR 603.3 it goes above.

Shape here: a `_stack_frozen: bool` and `_waiting_triggers: Array` on
`MtgGame`; `_push_trigger` appends to the waiting list when frozen;
`cast_spell` / `activate_ability` set the flag before paying and clear it
after `stack.append`, then flush the list through the existing APNAP path
in `dispatch_event`. Ordering inside the flush is already what
`dispatch_event` does for simultaneous triggers.

Risk: low. The flag and list are two fields for `GameSnapshot.STATE_CLASSES`
and two `_rec` calls for `UndoLog`; a headless test is "cast a spell with a
sacrifice cost while a dies-trigger is on the board; assert the trigger is
on top". Mana triggers must bypass the queue exactly as Forge's
`TapsForMana`/`ManaAdded` do (TriggerHandler 243-262) — ours already
resolves those immediately (`dispatch_event` 7711, CR 605.1b).

### 4.2 The affected player chooses among applicable replacements — **S/M**

Forge: `ReplacementHandler.run` 187-283 collects every replacement that
applies to the event, picks the decider at 193-197 (the affected player,
or the affected card's controller), and calls
`chooseSingleReplacementEffect` 222 when more than one remains; the
`CantHappen` layer skips the choice (218-219) because the order cannot
matter.

Fixes: ROADMAP row 2672 (two draw replacements in a fixed order) and the
greedy prevention pool of row 2660, which is the same problem in another
event: with two shields applicable to one packet the affected player should
pick which one applies first (CR 616.1).

Shape here: `_replace_draw` 3846 already builds the candidate list
(one-shots, then `_battlefield_draw_replacements`); when it holds more than
one entry, ask a `PlayerChoice` of the drawing seat before running the
first. For damage, `_land_damage_impl` 2911 walks
`prevention_shields`/`prevention_shield_filters`/`damage_replacements`
in a fixed order; the same "if more than one applies, ask" gate goes in
front of the walk. The 1997 prevention window (`damage_prevention_request`
3539) is a different question (which spells to cast) and stays as it is.

Risk: low for draws (a rare prompt: Island Sanctuary plus a one-shot). For
damage the prompt fires only with two applicable shields on one packet; the
AI's `DecisionAgent` needs a default (largest shield first is what the code
does today). Do not port Forge's generic `ReplacementHandler`: our
event-specific hooks are why a card is one file and a test can read the
path top to bottom.

### 4.3 Duration objects that outlive their source — **M**

Forge: `SpellAbilityEffect.createEffect` 653-690 makes a card of
`GamePieceType.EFFECT` in the command zone; `RegenerateEffect` 66-100,
`DamagePreventEffect` 122-150 and `PlayEffect.addIllusionaryMaskReplace`
529-561 all hang their replacements and statics on such a card, with
`addExileOnMovedTrigger` / `addUntilCommand` (948-1003) cleaning it up.

What it fixes: nothing that is broken today — ours keeps shields as
integers on the instance (`CardInstance.regeneration_shields` 137,
`destruction_shields` 173) and on the player (`MtgPlayer.prevention_shields`
174), and floating statics in `ContinuousEffects.add_floating_static` 347
with a `lasts` duration. The one thing the Forge shape buys is a single
answer to "which effects are on this object and until when" for the UI and
for `_has_window_effect` 3669. Not worth a port; worth knowing when a card
needs an effect with its own replacement and its own expiry (the pool's
"the next time X would be destroyed this turn" cards are already
integers).

Risk if adopted: a new state class for `GameSnapshot.STATE_CLASSES`, a new
zone, and every `_rec` site touching shields. Medium for no fidelity gain.

### 4.4 A bounded dependency check for layer statics — **S**

Forge: `GameAction.findStaticAbilityToApply` 1273-1387 builds a directed
graph of "A changes what B looks at" per layer, runs
`SzwarcfiterLauerSimpleCycles` (1364, CR 613.8b) and otherwise applies in
timestamp order (1381-1387), with a shortcut when nothing depends on
anything (1355-1360).

Fixes: ROADMAP rows 2666/2682 in the only form the pool needs. Layer 4
(types) and layer 6 (abilities) are where dependency matters; for 897 cards
the layer-4 statics are a handful (`changes_types` on
`se/abilities/static_ability.gd:69`, `changes_land_types` 83) and layer-6
grants/losses are the `_keywords`/`_losses` lists in `continuous.gd`.
The S version: (a) within a layer apply in timestamp order — which also
retires the "loss beats later grant" rule of row 2680, since `Card.java:135`
shows Forge just timestamps both; (b) a static flagged `changes_types` is
applied before any static whose filter reads a type, and the pass re-runs
once if a type changed (what the code does today, "runs twice", is this
rule without the flag). No graph library; the pool has no cycle.

Risk: the by-construction order in `recalculate` 605-884 is documented and
tested; changing it means re-running the layer tests (Transmutation,
Conversion, Blood Lust + Weakness, Sleight of Mind + protection). Small
and self-contained in one method, as the ROADMAP row already says.

### 4.5 One generic "unless a player pays" path — **S**

Forge: `AbilityUtils.handleUnlessCost` 1403-1441 — `UnlessCost$`,
`UnlessPayer$` (default the targeted controller), `UnlessSwitched$`, with
`payCostToPreventEffect` asking the payer and `sa.resolve()` on the
matching branch.

Fixes: every "unless a player pays" card in the pool (Force of Nature,
Phantasmal Forces, Sea Serpent, Demonic Hordes, Pirate Ship, Conversion,
Stasis, Cyclone, Dandan, Hasran Ogress, Merchant Ship, Sunken City —
`grep -l unless cards/sets/*/*.gd`) writes its own `try_pay` +
`PlayerChoice` pair. A `EffectBase.unless_paid(cost, payer)`
wrapper that asks the payer, calls `try_pay` 5418, and resolves the inner
effect on refusal removes the duplication and gives the AI one place to
decide.

Risk: none to the architecture; it is a helper on `EffectBase`
(`se/effects/effect_base.gd`) beside `optional_target` 73 and
`divided_among` 134.

### 4.6 A resolution-time decider on the stack item — **M**

Forge: `SpellAbility.setControlledByPlayer` (stamped in `PlayEffect`
455-459), honoured in `MagicStack.resolveStack` 594-596 / 627-632 so every
choice during that resolution is made by another player;
`ControlPlayerEffect` 48 lines.

Fixes: Word of Command (someday:245) in the owner's bounded form. Our
`_resolve_top` 5681 routes every `PlayerChoice` by seat; a `decider` field
on `StackItem` (default the controller) that `_run_effects` 6478 consults
when it asks makes the caster answer the opponent's choices while the
forced spell resolves. The mana restriction ("only lands") is a
`ManaPool`/`try_pay` filter for that one payment.

Risk: medium — the choice plumbing has 109 call sites (ROADMAP 2673 row)
and each must ask through one accessor for the override to hold (ROADMAP
row 2670 counts 103 of 109 inside a resolution). Worth it only if Word of
Command is wanted; the field itself is harmless.

### 4.7 A subgame as a second `MtgGame` — **L (screen), S (engine)**

Forge: `SubgameEffect` 248 lines, `new Game(players, maingame.getRules(),
maingame.getMatch(), maingame, startingLife)` at :38, libraries as decks,
`ZoneType.Subgame` (`ZoneType.java:32`) to park the main game's cards.
Ours: `MtgGame` is a `RefCounted` with no nodes, so `MtgGame.new()` with the
two libraries as decklists and the same two agents runs headless today;
someday:244 says the screen cannot host it. Forge confirms the engine
decomposition is the whole story: nothing in the rules layer needs to know
it is inside a subgame except the life stake at the end.

### 4.8 A single damage wave — already ours

Forge's `Combat.dealAssignedDamage` 928-940 fills one `CardDamageTable`
and hands it to `GameAction.dealDamage` so that simultaneous damage is one
event with one set of triggers; ours does the same with
`_collect_damage_requests` 8889 → `DamagePacket`s → `deal_damage` 2842.
Nothing to port; recorded because the ROADMAP's prevention-pool discussion
(2690+) touches the same code.

### 4.9 A rules-options object — already ours, and larger

`GameRules.java` 6-27 is the same idea as `se/rules_options.gd`; ours has
seven implemented switches to Forge's three old-rules ones. The one thing
Forge does that ours could copy is threading the object through the
`Match` so that a whole gauntlet shares one instance (`Match.java` 82-89
reads `useAnte` from it); ours already passes `RulesOptions` into
`MtgGame`, so this is a note, not a proposal.

---

## 5. Patterns to avoid

### 5.1 The string-keyed SVar DSL

`SVar:X:Count$xPaid`, `SVar:MaxTargets:SVar$MaxPlayers/Plus.MaxPermanents`,
`ConditionCheckSVar$ X | ConditionSVarCompare$ LE0` (Fireball and Cocoon in
§2.1) are strings resolved at run time by `AbilityUtils.xCount` 1566 and
its 3953-line host. A typo is a silent zero; a card's behaviour is spread
over a script, `CardFactoryUtil`, `AbilityFactory`, and the effect class;
and the only test is playing the card. Ours writes the same logic as typed
GDScript in the card file (`2ed/fireball.gd:28` `resolve_multi`), where the
parser catches the typo and a headless test can call the function. Keep
that. The DSL earns its keep at 30 000 cards with volunteer scripters; at
897 with one author it is pure cost.

### 5.2 The size and shape of `CardFactoryUtil`

4147 lines that turn keywords into strings that are then re-parsed into
objects (`Protection` → four strings at 2582-2591 and 3956-3988;
`Rampage` → a trigger string at 1622-1640). Every keyword is expanded
twice — once to text, once from text — and the expansion is the only
place the keyword's meaning lives, so a rules question ("does protection
stop a non-targeting aura?") is answered by reading generated DSL. Our
`Mtg.Keyword` flags and `ContinuousEffects` lists (`_protection` 320,
`_landwalk` 286) are checked in the rules code that needs them, which is
where a reader looks.

### 5.3 Re-parsing cards to copy a game

`GameCopier.createCardCopy` 299-317 calls `CardFactory.getCard(c.getPaperCard()
…)` for every card on every copy; the file's own comment at 318-321 calls
it "very expensive and accounts for the vast majority of GameCopier
execution time". This is a consequence of §5.1: a card's runtime object is
built from strings, so cloning means re-parsing. Ours never needs this
(§6).

### 5.4 Modern-rules machinery a 1995 pool does not need

Planeswalkers and loyalty (`handlePlaneswalkerRule` 1992, called from
`checkStateEffects` 1554), the +1/+1 vs -1/-1 counter annihilation at 1490
(CR 704.5q), the modern legend rule (2006-2060) with no 1995 variant,
`Merged`/`Mutate`, `Bestow`, `Morph` (which is what `CastFaceDown$` reuses
for Illusionary Mask), `Adventure`, `Foretell`, `Saga` chapters,
`Attraction`/`Contraption` decks and the `ExtraHand` zone, and 203
keywords of which the pool uses about a dozen (§2.3). None of it is wrong; all of it is weight in every loop
(`checkStateEffects` runs nine passes, 1417).

### 5.5 JGraphT dependency ordering for a pool without cycles

`findStaticAbilityToApply` 1273-1387 is correct and general; it is also a
graph library, a cycle enumerator, and a per-pass rebuild for a situation
that does not arise among 897 cards. §4.4 is the bounded version.

### 5.6 AI hints inside card scripts

`AILogic$ Evasion`, `SVar:AttachAILogic:Pump`, `SVar:PlayMain1:TRUE`,
`SVar:NeedsToPlayVar:CountOpps LTCountMe`, `AI:RemoveDeck:Random`,
`DeckHas:Ability$Counters` (Cocoon, Crusade, Camouflage in §2.1 and §3.3)
live in the same file as the rules. It is convenient and it means the
rules file changes when the AI changes. Ours keeps the AI in `se/ai/` and
lets a card offer at most a `with_ai_mode` picker (`card_data.gd:742`);
keep that separation.

### 5.7 The `Updated` re-run and the `frozenStack` special cases

`ReplacementHandler.run` 244-268 re-runs an event after an `Updated`
replacement and `MagicStack.clearFrozen` 169-173 carries a `TODO: frozen
triggered abilities and undoable costs have nasty consequences`. Both are
general-mechanism costs; ours handles the pool's re-run cases (a face-down
creature turned up by damage) inline in the event's own code and pays
nothing for the generality.

---

## 6. The simulation copy

### 6.1 What Forge copies, and how

`fai/simulation/GameCopier.java` is the copy used by the simulation AI.
`makeCopy` 76-100 creates a fresh `Match` and `Game` (84-85), marks it
`setNoGUIUser`, copies the timestamp (`dangerouslySetTimestamp`), and
copies each player's scalar fields by hand (life, poison, counters,
land-plays, spells cast). The zone walk (`ZONES` 37-46: Battlefield, Hand,
Graveyard, Library, Exile, Stack, Command) calls `createCardCopy` 299-317,
which — for every non-token card — re-parses the card from its paper
definition:

```java
newCard = CardFactory.getCard(c.getPaperCard(), newOwner, c.getId(), newGame);
```
(`:314`) followed at 318-321 by the file's own admission:
```java
// TODO: The above is very expensive and accounts for the vast majority of GameCopier execution time.
```
Battlefield permanents then get their mutable overlays copied field by
field in `addCard` 347-447 (tapped, damage, counters, attachments, P/T
boosts, keyword changes — the list is hand-maintained; the comment at :354
says "everything the CreatureEvaluator checks must be set here" and :356
is a TODO for the controller timestamps). After the walk, `:175-179` run `checkStateEffects(true)`,
`resetActiveTriggers`, and copy the stack only when
`GameSimulator.COPY_STACK` is true — it is `false` at `GameSimulator.java:19`.

What the copy leaves out, by its own TODOs (`:73, :115, :181, :215, :233,
:255, :289, :292, :308, :352, :357, :371, :528`): stack instances by
default, delayed triggers, until-end-of-turn commands, replacement-handler
state, `ExiledWith`, controller history, this-turn counters. Static
effects are recomputed rather than copied.

`fg/GameSnapshot.java` (581 lines, `makeCopy` 42-60, `restoreGameState`
63-70, `CardCopyService` at 446) is a newer in-place restore behind
`Game.EXPERIMENTAL_RESTORE_SNAPSHOT` (`Game.java:104`); `GameCopier`
delegates to it only under that flag.

### 6.2 What it is used for, and what it costs

`GameSimulator` (`fai/simulation/GameSimulator.java`): one copier per
simulator (45-48), `origScore` 55, `simulateSpellAbility` 179-243 plays one
candidate on the copy, resolves, and scores. `SpellAbilityPicker` builds
the candidate list and recurses; `SimulationController.DEFAULT_MAX_DEPTH
= 3` (`:15`, bound at :60). `GameStateEvaluator.getScoreForGameState`
45-110 scores a state as `+2·life`, `+cards`, `+4·fullValueCards`,
`−4·opponent cards`, plus creature values from `CreatureEvaluator`
(`fai/CreatureEvaluator.java:29-62`: base 80, +20 non-token, +15/power,
+10/toughness, +5/cmc, evasion and keyword bonuses); and it makes *another*
copy at 52-55 to advance to `COMBAT_DAMAGE` and see the combat outcome.

So one AI decision costs: (candidates × target tuples × modes) rebuilds at
each of up to three levels, plus one rebuild per evaluation, each rebuild
re-parsing every card in seven zones. There is no wall-clock budget on this
path and no timing instrumentation beyond a `currentTimeMillis` print in
`SpellAbilityPicker` 166/188-189.

The simulation AI is opt-in per lobby seat: `AIOption` `{USE_HYBRID_SIMULATION,
USE_FULL_SIMULATION}` (`fai/AIOption.java:3-6`), `AiController.
setUseSimulation` 117; every non-lobby constructor (quest, gauntlet,
adventure, network) passes `null`. The AI most players meet is the
heuristic one, which never copies.

### 6.3 Could `MtgGame` be copied the same way?

In principle yes, and more cheaply than Forge: `MtgGame` is a `RefCounted`
with no nodes; `GameSnapshot.STATE_CLASSES` (`se/game_snapshot.gd:84-98`
— `MtgGame`, `MtgPlayer`, `CardInstance`, `ManaPool`, `CombatState`,
`ContinuousEffects`, `StackItem`, `GameEvent`, `TargetRef`, `TargetPlan`,
`DamagePacket`, `PlayerChoice`, `RulesOptions`) is already the closed list
of mutable classes, and `CardData`/`CardScript`/abilities/effects are
immutable definitions shared by every copy (`game_snapshot.gd:30-36`) — the
thing Forge has to rebuild is the thing ours never touches. A fork would be
`_capture` 138 with fresh objects instead of the same ones plus an
instance-id remap for every `TargetRef`, `_trigger_index` entry, and
`Callable` bound to an instance; the last is the only real work, since a
card-file `Callable` captured against the old instance would write to the
old game.

In practice it is not needed. The engine already has two cheaper shapes
that Forge lacks:

- `GameSnapshot.take` 132 / `restore` 186 — an in-place rewind at
  ~23 us per object, 3.44 ms on a 127-object board (51-52), one live at a
  time, used by the resolution pre-flight (`_preflight` 5799).
- `UndoLog` — a journal at 0.13 us per recorded field and 0.14 us to write
  back (`se/undo_log.gd:35-36`), typed parallel arrays (79-81), `mark` 149
  saving `rng.state`; exposed as `MtgGame.make_mark` 661 / `unmake_to` 685
  / `end_search` 701. A move costs what it changes, not what the board
  holds; the derived layer (`cur_*`) is recomputed by `recalculate` on
  unwind rather than journaled (685-699).

A look-ahead search here is a depth-first walk on the one live game with
`make_mark`/`unmake_to` at every node — which is what Forge's
`GameSnapshot.restoreGameState` is trying to become. The measured limit is
the one `combat_search.gd:62-76` records: a node that spans a whole turn is
no cheaper than a snapshot because untap and cleanup touch every permanent;
a node of one step or a few is 11-19× cheaper. Forge's design gives no help
past that point; its evaluator (`CreatureEvaluator`) is the one reusable
piece, and it is an ordinary function.

---

## 7. Licence and provenance

Both projects are GPL-3.0: `shandalar/LICENSE` and `forge/LICENSE` are the
same text (GNU General Public License, Version 3, 29 June 2007); Forge's
`README.md:97` states it and every Java file carries the header
(`GameAction.java:3-15`, "Copyright (C) 2011 Forge Team"). Forge's card
scripts are in the same repository under the same licence; the Oracle text
inside them is Wizards of the Coast's, as it is in ours. The clone examined
is `github.com/Card-Forge/forge` at commit
`b09a3d3f0093b7ba26a0debc82d80996b8826b37` (2026-09-08).

Compatible licences mean a port is *permitted*; the project's own rule is
that it is *recorded*. `Provenance.md` ranks reimplementations as Tier 3
("Excellent engineering and often the fastest way to understand a system,
but every one of them has made changes of its own. Useful as a guide, never
as proof", `Provenance.md:49-53`) and lists them in the table at 450-457
(s30, mage-go, Manalink, the deck files). Forge belongs in that table as a
row of the same shape as mage-go's ("The reference implementation for
tricky cards and rules. Search its `cards/` by card name", 455):

```
| **Forge** — a Magic rules engine in Java, GPL-3.0 | `../forge`, `github.com/Card-Forge/forge.git` (b09a3d3f) | A second reference for engine mechanisms and card decompositions; scripts in `forge-gui/res/cardsfolder/`, effects in `forge-game/.../ability/effects/`. Its rules are modern-only (no 1995 legend rule, no prevention step) and its AI hints live in the card scripts; take the decomposition, never the DSL. |
```

Two words to keep apart:

- **Ported** — code, an algorithm with its constants, a table, or a
  decomposition carried over closely enough that a reader of the Forge
  file would recognise it. That needs the Provenance row above *and* a
  marker at the site naming the Forge file and lines, in the style the
  repository already uses for `[s30]`/`[1997]`/`[QoL]`, e.g.
  `# [forge] after fg/zone/MagicStack.java:155-167 (unfreezeStack)`. The
  GPL header obligations are already met by the repository licence; the
  marker is for the reader, and for the day the Forge line moves.
- **Inspired by** — the idea only, implemented from the rules text in the
  engine's own shape. Every proposal in §4 is of this kind if done as
  described (the waiting queue, the replacement chooser, the decider field,
  the bounded dependency check, the `unless_paid` helper): a sentence in
  the ROADMAP row or the function's doc comment pointing at this note is
  enough, and a marker is recommended when the Forge pointer is what a
  future reader would want.

Nothing in this note was ported; every quotation is attributed by file and
line so that either path can be taken later with the pointer already in
hand.
