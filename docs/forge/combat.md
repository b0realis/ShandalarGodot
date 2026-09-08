# Forge's combat and card evaluation, read for the Wizard rung

An engineering note. It reads the Forge AI (GPLv3, shallow clone at commit
`b09a3d3f`, checked out at `forge/`) for what it knows about attacking,
blocking and pricing creatures, sets it beside what `shandalar/engine/ai/`
does today, and proposes what is worth carrying over as measured knobs on
`AiProfile`. Every pointer is `path:line` against those two trees; the
Forge paths are relative to the clone root (`forge/forge-ai/...`), ours to
the project root (`shandalar/engine/...`). Where a formula matters the code
is quoted verbatim.

Two scales appear throughout. Forge prices a creature in integer "points"
(a vanilla 2/2 for two is 160); ours prices it in "stat points"
(`Evaluator.permanent_value`, the same 2/2 is 4.0). The ratio is about 40:1
at the bottom of the curve and drifts to 30:1 or lower for evasive and
defensive creatures, which is one of the findings.

Contents

1. MAP — how Forge decides an attack and a block
2. EVALUATION — `CreatureEvaluator` and what consumes it
3. SIDE BY SIDE — ours against Forge, seam by seam
4. PROPOSALS — ranked knobs for the ladder, each with a measurement plan
5. DO NOT COPY
6. LICENCE AND PROVENANCE

---

## 1. MAP — how Forge decides an attack and a block

### 1.1 Entry points and data

The engine asks the controller; the controller delegates to one of two
one-shot objects that are built per decision and thrown away.

- Attack: `PlayerControllerAi.declareAttackers` →
  `AiController.declareAttackers`
  (`forge/forge-ai/src/main/java/forge/ai/PlayerControllerAi.java:821-823`,
  `forge/forge-ai/src/main/java/forge/ai/AiController.java:1307-1330`).
  The controller news an `AiAttackController(player)`, calls
  `declareAttackers(combat)` and keeps its return value as
  `lastAttackAggression`, then runs `reinforceWithBanding(combat)` and
  `removeUnpayableAttackers(combat)`, and finally validates: if the engine
  rejects the declaration it falls back to the legal set, then to the
  mandatory set (`AiController.java:1315-1329`).
- Block: `PlayerControllerAi.declareBlockers` →
  `AiController.declareBlockersFor` →
  `new AiBlockController(defender, defender != player).assignBlockersForCombat(combat)`
  (`PlayerControllerAi.java:826-828`, `AiController.java:1301-1305`). The
  boolean is `checkingOther`: the same controller is run on the opponent's
  behalf when Forge predicts what a human would block with, and that flag
  is what stops it from reading a hand it may not see (1.9 below).
- Damage order and assignment: `PlayerControllerAi.orderBlockers` /
  `orderAttackers` → `AiBlockController.orderBlockers/orderAttackers`
  (`PlayerControllerAi.java:484-495`,
  `forge/forge-ai/src/main/java/forge/ai/AiBlockController.java:1176-1197`);
  `PlayerControllerAi.assignCombatDamage` →
  `ComputerUtilCombat.distributeAIDamage`
  (`PlayerControllerAi.java:219-220`,
  `forge/forge-ai/src/main/java/forge/ai/ComputerUtilCombat.java:2010-2112`).
- A mock declaration for everything that wants to know "what will attack
  if I do this now": `AiController.getPredictedCombat` /
  `getPredictedCombatNextTurn` (`AiController.java:141-158`) build a
  throw-away `Combat`, run the attack controller on it and cache it. This
  is what `ComputerUtilCard.doesCreatureAttackAI` (`ComputerUtilCard.java:830-833`)
  answers with, and it is why a sorcery-speed pump or an aura can be aimed
  at the creature that is actually going to swing.

The working state is a handful of lists on the controller objects:
`attackers`, `blockers`, `oppList`, `myList` on the attack side
(`forge/forge-ai/src/main/java/forge/ai/AiAttackController.java:71-82`);
`attackers`, `attackersLeft`, `blockedButUnkilled`, `blockersLeft`, `diff`,
`lifeInDanger` on the block side (`AiBlockController.java:60-74`). The
`Combat` object from the rules engine is mutated directly
(`combat.addBlocker`, `combat.removeFromCombat`), so a "pass" that changes
its mind starts by calling `clearBlockers`.

Profile values reach both through `AiProps`
(`forge/forge-ai/src/main/java/forge/ai/AiProps.java:26-150`) and
`AiProfileUtil.getIntProperty/getBoolProperty`
(`forge/forge-ai/src/main/java/forge/ai/AiProfileUtil.java:117-131`);
the four shipped profiles are `forge/forge-gui/res/ai/{Default,Reckless,Cautious,Experimental}.ai`
(table in 1.11).

### 1.2 The attack, step by step (`AiAttackController.declareAttackers`, 803-1337)

1. Construction. `getOpponentCreatures` (130-177) builds the blocker list
   from the defender's untapped creatures **plus any land or artifact
   that can animate itself for the mana the defender has open** — a
   Mishra's Factory with `{1}` up is counted as a 2/2 blocker before the
   attack is priced. `sortAttackers` (237-257) puts creatures with
   attack triggers first so they get the good slots.
2. Profile reads (856-865): `PLAY_AGGRO`, `CHANCE_TO_ATTACK_INTO_TRADE`,
   `ATTACK_INTO_TRADE_WHEN_TAPPED_OUT`,
   `RANDOMLY_ATKTRADE_ONLY_ON_LOWER_LIFE_PRESSURE`,
   `CHANCE_TO_ATKTRADE_WHEN_OPP_HAS_MANA`.
3. Forced attackers (878-953): anything with "attacks each combat if
   able", a must-attack requirement, or a `MustAttack` static is added
   first and never reconsidered. (Ours: `_must_attack`,
   `shandalar/engine/ai/ai_player.gd:3288`.)
4. `doAssault()` (573-760): lethal on board → everything attacks (972-988).
   Detail in 1.6.
5. Held tricks (991-999): a creature remembered in
   `AiCardMemory.MemorySet.TRICK_ATTACKERS` attacks regardless — it is the
   bait for a pump the AI reserved mana for (1.10).
6. Exalted → aggression 6 (1001-1029); an attack cap from statics
   (1031-1045).
7. Force evaluation (1064-1136), attrition simulation (1144-1173),
   unblockable-race clock (1181-1218), then the aggression ladder
   (1226-1260). Verbatim in 1.3.
8. `notNeededAsBlockers` (341-492) — the set of creatures it can afford to
   tap. Verbatim in 1.5.
9. Per-attacker loop (1272-1334): skip a creature whose only reason to
   attack is first strike against a first-striking blocker (1286-1289);
   otherwise `shouldAttack(attacker, blockers, combat, defender)`
   (1459-1552) decides by the ladder level and a bundle of per-creature
   flags (`SpellAbilityFactors`, 1339-1444). Verbatim in 1.4.
10. Back in `AiController`: `reinforceWithBanding` (494-571) attaches a
    band-mate to an attacker that would otherwise die; the evasion list
    it refuses to band across is literal keyword text
    (`AiAttackController.java:524-525`, "Flying", "Horsemanship",
    "Landwalk:Plains"...). `removeUnpayableAttackers` drops attackers
    whose attack cost cannot be paid.

### 1.3 The force evaluation and the aggression ladder (verbatim)

The ratio block (`AiAttackController.java:1117-1136`):

```java
aiLifeToPlayerDamageRatio = (double) ai.getLife() / candidateCounterAttackDamage;
...
humanLifeToDamageRatio = (double) (defendingOpponent.getLife() - ComputerUtil.possibleNonCombatDamage(ai, defendingOpponent)) / candidateUnblockedDamage;
...
final int outNumber = computerForces - humanForces;
for (Card blocker : this.blockers) {
    if (blocker.canBlockAny()) {
        aiLifeToPlayerDamageRatio--;
    }
}
final double ratioDiff = aiLifeToPlayerDamageRatio - humanLifeToDamageRatio;
```

`candidateCounterAttackDamage` is the sum of what every opposing creature
that could attack next turn would deal unblocked; `candidateUnblockedDamage`
the same for ours this turn (1064-1115). `computerForces` and `humanForces`
count creatures, and `possibleNonCombatDamage` (`ComputerUtil.java:1544+`)
adds the burn it can see on the battlefield (a Prodigal Sorcerer, a
Cursed Scroll) to the opponent's effective life. Note the `--` per
opposing blocker: every body they can block with knocks a whole point off
"how many turns of their counter-swing can I take", which is a crude but
deliberate way of saying blockers are also attackers next turn.

The attrition simulation (1144-1173):

```java
CardLists.sortByPowerAsc(this.attackers);
int humanLife = defendingOpponent.getLife();
final List<Card> attritionalAttackers = new ArrayList<>();
for (int x = 0; x < (this.attackers.size() - humanForces); x++) {
    attritionalAttackers.add(this.attackers.get(x));
}
int attackRounds = 1;
while (!attritionalAttackers.isEmpty() && humanLife > 0 && attackRounds < 99) {
    int damageThisRound = 0;
    for (Card attritionalAttacker : attritionalAttackers) {
        damageThisRound += attritionalAttacker.getNetCombatDamage();
    }
    humanLife -= damageThisRound;
    for (int z = 0; z < humanForcesForAttritionalAttack; z++) {
        if (!attritionalAttackers.isEmpty()) {
            attritionalAttackers.remove(attritionalAttackers.size() - 1);
        }
    }
    attackRounds++;
    doAttritionalAttack = humanLife <= 0;
}
```

It asks: if we attack with everything every turn, they block and kill one
attacker per blocker each turn, and nothing else ever changes — do they
die before we run out? No evaluation of who wins the blocks; the smallest
attackers are the ones assumed to get through (sorted ascending, the
surplus over their blocker count).

The unblockable clock (1181-1218):

```java
turnsUntilDeathByUnblockable = 1 + (defendingOpponent.getLife() - unblockableDamage) / nextUnblockableDamage;
```

where `unblockableDamage` is this turn's damage from attackers none of
their blockers can legally block, and `nextUnblockableDamage` the same for
what could attack next turn.

The ladder itself (1226-1260), quoted in full because every clause is a
design decision:

```java
if (ratioDiff > 0 && doAttritionalAttack) {
    aiAggression = 5; // attack at all costs
} else if ((ratioDiff >= 1 && this.attackers.size() > 1 && (humanLifeToDamageRatio < 2 || outNumber > 0))
        || (playAggro && MyRandom.percentTrue(chanceToAttackToTrade) && humanLifeToDamageRatio > 1)) {
    aiAggression = 4; // attack expecting to trade or damage player.
} else if (MyRandom.percentTrue(chanceToAttackToTrade) && humanLifeToDamageRatio > 1
        && defendingOpponent != null
        && ComputerUtil.countUsefulCreatures(ai) > ComputerUtil.countUsefulCreatures(defendingOpponent)
        && ai.getLife() > defendingOpponent.getLife()
        && !ComputerUtilCombat.lifeInDanger(ai, combat)
        && (ComputerUtilMana.getAvailableManaEstimate(ai) > 0 || tradeIfTappedOut)
        && (ComputerUtilMana.getAvailableManaEstimate(defendingOpponent) == 0
                || MyRandom.percentTrue(extraChanceIfOppHasMana))
        && (!tradeIfLowerLifePressure || (ai.getLifeLostLastTurn() + ai.getLifeLostThisTurn() <
        defendingOpponent.getLifeLostLastTurn() + defendingOpponent.getLifeLostThisTurn()))) {
    aiAggression = 4; // random (chance-based) attack expecting to trade or damage player.
} else if (ratioDiff >= 0 && this.attackers.size() > 1) {
    aiAggression = 3; // attack expecting to make good trades or damage player.
} else if (ratioDiff + outNumber >= -1 || aiLifeToPlayerDamageRatio > 1
        || ratioDiff * -1 < turnsUntilDeathByUnblockable) {
    aiAggression = 2; // attack expecting to destroy creatures/be unblockable
} else if (doUnblockableAttack) {
    aiAggression = 1;
} else {
    aiAggression = 0;
} // stay at home to block
```

Level 6 is set earlier for exalted boards (1001-1029). The second
"level 4" branch is the only place the opponent's open mana enters the
attack decision at all, and it enters as a *dice roll*
(`extraChanceIfOppHasMana` at 1242, `CHANCE_TO_ATKTRADE_WHEN_OPP_HAS_MANA`, 30 in
Default, 100 in Reckless, 0 in Cautious) — not as a prediction of what the
mana could do.

### 1.4 `shouldAttack` — one creature against the ladder (1459-1552)

First the per-creature flags, computed once per attacker in
`SpellAbilityFactors` (1339-1444). The ones the switch reads:

| flag | meaning | how it is computed |
|---|---|---|
| `canBeKilledByOne` | one blocker alone kills it | `ComputerUtilCombat.canDestroyAttacker` per blocker (1390) |
| `isWorthLessThanAllKillers` | every blocker that kills it is worth *more* than it | `evaluateCreature(blocker) <= evaluateCreature(attacker)` clears it (1395-1398) |
| `canKillAll` | it kills every single blocker | `!canDestroyBlocker` clears it (1402-1404) |
| `canKillAllDangerous` | same, restricted to blockers with wither/infect | (1405-1409) |
| `canBeKilled` | some block (single or gang) kills it | via `canBeBlockedProfitably` (1439-1441) |
| `numberOfPossibleBlockers`, `defPower` | count and total power of legal blockers | (1381-1389) |
| `hasAttackEffect` / `hasCombatEffect` | card-script hints `HasAttackEffect`, `HasCombatEffect` | SVars (1364-1367) |
| `canBeBlocked()` | at least one legal block exists | (1357-1361) |

The `TRY_TO_AVOID_ATTACKING_INTO_CERTAIN_BLOCK` clause inside it
(1415-1424) clears `canKillAllDangerous` when

```java
boolean attackerWillDie = defPower >= attacker.getNetToughness();
boolean uselessAttack = !hasCombatEffect && !hasAttackEffect;
boolean noContributionToAttack = attackers.size() <= defenders.size() || attacker.getNetPower() <= 0;
```

all hold — a head count, not a valuation: "we do not outnumber them, this
creature has no trigger, and their total power would kill it".

Then the switch (1504-1550):

```java
case 6: // Exalted
    if ((saf.canKillAll && saf.isWorthLessThanAllKillers) || !saf.canBeBlocked()) return true;
case 5: // all out attacking
    return true;
case 4: // expecting to at least trade with something, or can attack "for free"
    if (saf.canKillAll || (saf.dangerousBlockersPresent && saf.canKillAllDangerous && !saf.canBeKilledByOne) || !saf.canBeBlocked()
            || saf.defPower == 0) return true;
case 3: // expecting to at least kill a creature of equal value or not be blocked
    if ((saf.canKillAll && saf.isWorthLessThanAllKillers)
            || (((saf.dangerousBlockersPresent && saf.canKillAllDangerous) || saf.hasAttackEffect || saf.hasCombatEffect) && !saf.canBeKilledByOne)
            || !saf.canBeBlocked()) return true;
case 2: // attack expecting to attract a group block or destroying a single blocker and surviving
    if (!saf.canBeBlocked() || ((saf.canKillAll || saf.hasAttackEffect || saf.hasCombatEffect) && !saf.canBeKilledByOne &&
            ((saf.dangerousBlockersPresent && saf.canKillAllDangerous) || !saf.canBeKilled))) return true;
case 1: // unblockable creatures only
    if (!saf.canBeBlocked() || (saf.numberOfPossibleBlockers == 1 && saf.canKillAll && !saf.canBeKilledByOne)) return true;
```

(`break` and logging lines elided; each case falls to `return false`.)
Read as a ladder: at 4 a creature attacks if it *trades* with anything;
at 3 only if the trade is up or even in points; at 2 only if it survives
any single block; at 1 only if it cannot be blocked. There is no group
valuation anywhere — the group is the union of creatures that pass
individually, which is why level 3 and 4 also require
`attackers.size() > 1`.

### 1.5 What stays home: `notNeededAsBlockers` and the mock counter-attack

`notNeededAsBlockers` (`AiAttackController.java:341-492`) decides how many
bodies are free to tap. Early exits: it is our turn again next (an extra
turn) → everything attacks (343-345); a Fog effect is being held for next
turn (`CHOSEN_FOG_EFFECT`) → everything but the Fog source attacks
(347-357). Then the loop (412-450):

```java
CardLists.sortByPowerDesc(blockers);
for (Card c : blockers) {
    if (vigilantes.contains(c)) { continue; }
    notNeededAsBlockers.add(c);
    int currentBaselineLife = ComputerUtil.predictNextCombatsRemainingLife(ai, playAggro, pilotsNonAggroDeck, 0, notNeededAsBlockers);
    if (currentBaselineLife == Integer.MIN_VALUE) {
        notNeededAsBlockers.remove(c);
        break;
    }
    if (pilotsNonAggroDeck) {
        int ownAttackerDmg = c.getNetCombatDamage();
        ... // + predicted pump, ×2 for double strike, + thresholdMod
        if (Math.abs(currentBaselineLife - lastAcceptableBaselineLife) > ownAttackerDmg) {
            notNeededAsBlockers.remove(c);
            continue;
        }
        lastAcceptableBaselineLife = currentBaselineLife;
    }
}
```

`predictNextCombatsRemainingLife` (`ComputerUtil.java:3175-3226`) is the
crack-back oracle: it builds a `Combat` in which every opposing creature
that `canAttackNextTurn` attacks us, runs **our own** block controller on
it with the tapped candidates excluded
(`new AiBlockController(ai, false).assignBlockersForCombat(combat, excludedBlockers)`),
and returns `Integer.MIN_VALUE` if `lifeInSeriousDanger` (aggro) or
`lifeInDanger` (non-aggro) holds, else the worst `lifeThatWouldRemain`.
So the attacker is released greedily, biggest first, until the next
counter-swing would be dangerous — and, for a deck flagged non-aggro, until
the *extra* life the counter-swing would cost exceeds the damage the
attacker itself would add. The aggro/non-aggro flag comes from
`PlayerControllerAi.setupAutoProfile`:

```java
pilotsNonAggroDeck = deck.getName().contains("Control") || deck.getAverageCMC() > 3;
```

(`PlayerControllerAi.java:73`).

### 1.6 Lethal: `doAssault` (573-760)

Sort attackers by power descending; every blocker that `canBlockAny()`
removes the *first* attacker it can legally block from the unblocked set
(`remainingAttackers`, 676-686 — the comment at 688 says "presumes the
Human will block"); tramplers that were assigned a blocker still count
their overflow; if the unblocked sum plus trample overflow reaches the
defender's life (adjusted for prevention it can see), attack with
everything. With `COMBAT_ASSAULT_ATTACK_EVASION_PREDICTION` (617; true in
all four profiles) the blocker-to-attacker assignment respects evasion
categories (`ComputerUtilCombat.categorizeAttackersByEvasion`,
`ComputerUtilCombat.java:2367-2393`). This is the same one-blocker-per-
attacker lethal test as our `_damage_through_blocks`
(`ai_player.gd:3330-3360`), with one difference: Forge assumes they block
the *biggest* attacker each blocker can reach, ours assigns blocks by what
the defender gains.

### 1.7 The block, step by step (`AiBlockController.assignBlockers`, 1043-1174)

```java
diff = (ai.getLife() * 2) - 5; // This is the minimal gain for an unnecessary trade
if (diff > 0 && AiProfileUtil.getBoolProperty(ai, AiProps.PLAY_AGGRO)) {
    diff = 0;
}
```

(1050-1053). `diff` is in evaluator points: at 20 life a voluntary trade
must gain 35 points (a bear is 160, a 3/3 is 190 — so a 2/2 does *not*
trade for a 3/3 at 20 life; it does at 17 or below); at 2 life `diff` is
−1 and it trades down freely. A profile with `PLAY_AGGRO` trades at parity
from the start.

Then, in order, on the untapped blockers sorted by power ascending
(1075-1148):

1. `makeGoodBlocks` — blocks that are free or clearly up (187-325).
2. `makeGangBlocks` — two or three blockers to kill one attacker (368-548).
3. `lifeInDanger = ComputerUtilCombat.lifeInDanger(ai, combat)` unless
   `hasAFogEffect` says a Fog is available (1082-1083) — see 1.9 for what
   that call reads.
4. `makeTradeBlocks` — even trades, only when in danger or when the
   random-trade roll says so (599-632).
5. `makeChumpBlocks` if still in danger (635-706).
6. `reinforceBlockersAgainstTrample` if still in danger (739-792);
   otherwise `reinforceBlockersToKill` (795-858).
7. `removeUnpayableBlocks` (1358-1377) and a re-check.
8. **Pass 2** if `lifeInDanger`: `clearBlockers`, then trade → good →
   chump → trample reinforcement → gang → reinforce-to-kill (1105-1122).
9. **Pass 3** if `lifeInSeriousDanger`: `clearBlockers`, chump first, then
   trade, trample reinforcement, good, gang, reinforce (1125-1148).
10. `makeRequiredBlocks` — lure / must-block (953-985); planeswalker
    chumps; menace non-lethal gangs; validity sweep (1152-1173).

The rungs inside `makeGoodBlocks` (187-325), per attacker, best first:

1. a **safe killing** blocker — survives and kills — the *worst* such
   creature by `evaluateCreature` (`getWorstCreatureAI(killingBlockers)`,
   203-208);
2. a **safe** blocker — survives, does not kill — again the worst one; for
   a trampler it first checks that the blocker would not soak more of a
   *different* attacker (209-233), and records the attacker in
   `blockedButUnkilled` so the reinforce pass can finish it;
3. with no safe blocker: a killing blocker that has an upside in dying
   (undying, `SacMe`, vanishing/fading, leaves at end of turn — none in
   the pool) (238-259);
4. a killing blocker worth less than the attacker by the margin:

```java
if (ComputerUtilCard.evaluateCreature(worst) + diff < value) {
    blocker = worst;
}
```

   (287-289), where `value` is the attacker's evaluation plus 50 if it has
   an on-damage or on-unblocked trigger (266-286) — a structural read of
   the trigger list, not a card name (a Hypnotic Specter gets the +50 from
   its `DamageDone` trigger).

`makeTradeBlocks` (599-632): the worst killing blocker, taken if
`lifeInDanger || wouldLikeToRandomlyTrade(...)`. The random-trade chance
(1316-1319):

```java
int numSteps = Math.max(1, ai.getStartingLife() - 5);
float chanceStep = (maxRandomTradeChance - minRandomTradeChance) / numSteps;
int chance = (int)Math.max(minRandomTradeChance, (maxRandomTradeChance - (Math.max(5, ai.getLife() - 5)) * chanceStep));
```

gated (1341-1355) by power parity (`blocker.getNetPower() <= attacker.getNetPower()`),
creature-count parity within `MAX_DIFF_IN_CREATURE_COUNT_TO_TRADE`, and
`evalBlk <= evalAtk + 1` on the CMC-less evaluation.

`makeChumpBlocks` (635-706): recursion over the attackers largest first;
for each, the **worst creature** among legal blockers is thrown, with two
trample refinements — a blocker that dies before damage soaks nothing
(`shieldDamage == 0` filter, 674-679) and a chump against a trampler is
redirected to a non-trampler of at least the absorbed power (681-698).
There is no price on the chump: if `lifeInDanger` holds, the cheapest
body goes, whatever it stops. `makeMultiChumpBlocks` (708-737) adds more
bodies to one attacker when a single one cannot make it non-lethal.

`makeGangBlocks` (368-548). First, first-strikers ganging on a
non-first-striker (373-420). Then the general case: usable blockers are
those that are in danger, random-trade eligible, or `evaluateCreature(c) + diff < evaluateCreature(attacker)`,
and not killed before dealing damage (`canDestroyBlockerBeforeFirstStrike`)
(422-443); the leader is the *best* usable creature; a second blocker is
added when the pair's damage reaches the attacker's toughness plus
predicted pumps and one of three holds (467-475):

```java
&& (absorbedDamage2 + absorbedDamage > attacker.getNetCombatDamage()
// only one blocker can be killed
|| currentValue + addedValue - 50 <= evalAttackerValue
// or attacker is worth more
|| (lifeInDanger && ComputerUtilCombat.lifeInDanger(ai, combat)))
```

A triple block is tried only if no double was found (490-548, same shape).
Attackers with rampage-like triggers are filtered out of gang and reinforce
consideration wholesale (`rampagesOrNeedsManyToBlock`, 369 and 798).

`reinforceBlockersToKill` (795-858): for every attacker in
`blockedButUnkilled`, first add **safe** extra blockers whose damage
closes the gap to `getDamageToKill(attacker) + predictToughnessBonusOfAttacker`
(816-828); then add non-safe ones only when the added blocker completes
the kill exactly and is cheaper than the attacker by `diff`
(838-856), never a blocker that dies before dealing damage. This is the
pass ours has no equivalent of (3.2).

`reinforceBlockersAgainstTrample` (739-792): when in danger, add safe
blockers to a blocked trampler in the order of the lethal damage they
absorb, until the overflow no longer endangers.

`makeRequiredBlocks` (953-985): every blocker that must block (lure,
"blocks each combat if able") is assigned to the attacker it is required
against, after the voluntary plan — the comment at 951 admits the ordering
sometimes breaks a good voluntary block.

`orderBlockers` (1176-1197): kill in order — first the blockers the
attacker can kill, best first (`sortByEvaluateCreature`), then the rest.
No knapsack; a 5-power attacker blocked by a 2/2, a 2/2 and a 4/4 kills
the 4/4 first.

### 1.8 The predictors (`ComputerUtilCombat`)

`lifeThatWouldRemain` (297-322): life minus unblocked attackers minus
trample overflow (`getAttack(attacker) - totalShieldDamage(attacker, blockers)`).

`lifeInDanger` (389-454), the threshold made a random walk:

```java
int threshold = AiProfileUtil.getIntProperty(ai, AiProps.AI_IN_DANGER_THRESHOLD);
int maxTreshold = AiProfileUtil.getIntProperty(ai, AiProps.AI_IN_DANGER_MAX_THRESHOLD) - threshold;
int chance = MyRandom.getRandom().nextInt(80) + 5;
while (maxTreshold > 0) {
    if (MyRandom.getRandom().nextInt(100) < chance) {
        threshold++;
    }
    maxTreshold--;
}
return !ai.cantLoseForZeroOrLessLife() && lifeThatWouldRemain(ai, combat) - payment < Math.min(threshold, ai.getLife());
```

Default and Reckless: 4..4 (deterministic 4); Cautious 4..6;
Experimental 3..12. `lifeInSeriousDanger` (465-497) is the same test
against `< 1`. Both also return true for an unblocked attacker whose script
carries `MustBeBlocked` (a card hint) and for poison.

`canDestroyAttacker` (1644-1761) and `canDestroyBlocker` (1874-1993) are
the kill oracles, and they are where Forge predicts the *other side's*
resources:

- indestructible / regeneration first
  (`ComputerUtil.canRegenerate(ai, attacker)`, 1672; `ComputerUtil.java:989-1033`
  checks the creature's own regeneration abilities against its
  controller's payable mana and any regeneration shield already there);
- blocker's power plus `predictPowerBonusOfBlocker` (868-994): static
  bonuses, blocking triggers (bushido, flanking, rampage-like on the
  attacker side), and then **every activated pump the controller can pay
  for right now** (955-991):

```java
for (SpellAbility ability : blocker.getAllSpellAbilities()) {
    if (!ability.isActivatedAbility()) continue;
    if (ability.hasParam("ActivationPhases") || ability.hasParam("SorcerySpeed") || ability.hasParam("ActivationZone")) continue;
    ...
    if (ability.getApi() == ApiType.Pump) {
        if (!ability.hasParam("NumAtt")) continue;
        pBonus = AbilityUtils.calculateAmount(ability.getHostCard(), ability.getParam("NumAtt"), ability);
    } ...
    if (pBonus > 0 && ComputerUtilCost.canPayCost(ability, blocker.getController(), false)) {
        power += pBonus;
    }
}
```

  (one activation only — a Shade with three Swamps open is predicted at
  +1/+1, not +3/+3; the toughness twin `predictToughnessBonusOfBlocker`
  does the same for `NumDef`);
- `predictPowerBonusOfAttacker` (1138-1322) mirrors it for the attacker
  and adds "whenever attacks" and "becomes blocked" triggers (1193+) —
  Rampage is a `K:` keyword in the card script
  (`forge/forge-gui/res/cardsfolder/c/craw_giant.txt:6`, `K:Rampage:2`)
  whose trigger the predictor reads generically;
- damage prevention (`ComputerUtil.possibleDamagePrevention`,
  `ComputerUtil.java:1035+`) and protection (`predictDamageTo`,
  `isCombatDamagePrevented`);
- first strike ordering: the attacker's first strike kills the blocker
  before it deals damage unless the blocker also strikes first
  (1743-1752), and the closing line is simply

```java
return defenderDamage >= attackerLife;
```

  (1758).

`canDestroyAttackerBeforeFirstStrike` (1546-1592) is the Cockatrice
reader: it scans every trigger on the battlefield for one that fires on
this block and whose ability is `ApiType.Destroy` aimed at
`TriggeredAttacker` (1561-1590). It is consulted before any damage maths
(1651), so no attacker is ever sent into a Basilisk expecting to survive,
and `shieldDamage` (639-662) returns 0 for a blocker that would die before
damage — a chump that soaks nothing.

Trample: `shieldDamage` (639-662) is the blocker's lethal damage after
flanking and bushido; `totalShieldDamage` sums it; `distributeAIDamage`
(2010-2112) assigns lethal to each blocker in order and the rest to the
player, and prefers to kill the blocker over pushing damage through unless
the overflow is lethal to the player. `getEnoughDamageToKill` (2147-2171)
accounts for regeneration and prevention when deciding what "lethal" is.

Evasion: `CombatUtil.canBlock` (forge-game) is the legality oracle
everywhere, so flying, landwalk, fear, protection and "can't be blocked
except by" are all one predicate — the same design as our
`CombatState.block_illegality` (`shandalar/engine/combat.gd:383`).

### 1.9 Hidden information in the block controller

`ComputerUtil.hasAFogEffect(defender, ai, checkingOther)`
(`ComputerUtil.java:1500-1542`):

```java
final CardCollection all = new CardCollection(defender.getCardsIn(ZoneType.Battlefield));
all.addAll(defender.getCardsActivatableInExternalZones(true));
// TODO check if cards can be viewed instead
if (!checkingOther) {
    all.addAll(defender.getCardsIn(ZoneType.Hand));
}
```

When the AI is asking about *itself* (`checkingOther == false`) this is
its own hand, which it may read. `assignBlockers` calls it as
`hasAFogEffect(ai, ai, checkingOther)` (1082), so on its own blocks the
hand read is legitimate; `doAssault` calls it for the *opponent* with
`checkingOther = true` (593) and stays honest. But `AiBlockController` is
constructed with `checkingOther = (defender != player)` and the mock
counter-attack in `predictNextCombatsRemainingLife` constructs it with
`false` for the AI itself (3208) — so the attack-side prediction of our own
blocks reads our own hand, which is fine. The one leak is in
`ComputerUtilCard.shouldPumpCard` and its neighbours, where the opponent's
open mana is read as an estimate (`ComputerUtilMana.getAvailableManaEstimate(defendingOpponent)`,
`AiAttackController.java:1241`) — public information — and the memory set
`REVEALED_CARDS` (`forge/forge-ai/src/main/java/forge/ai/AiCardMemory.java:53-66`)
keeps what was legitimately revealed. Forge's discipline here is a
convention, not a rule: nothing pins it. Ours is a rule
(`docs/ROADMAP.md:3073`, "Hidden information is a fairness rule here") with
tests.

### 1.10 Combat tricks: `shouldPumpCard` (`ComputerUtilCard.java:1470-1862`)

The pump decision is one function with phase-dependent branches:

- **before attackers** (main 1, or the pump is a sorcery): pump only a
  creature that `doesCreatureAttackAI` says will attack (1519-1525), and
  only if the pump changes a kill/survive outcome.
- **hold the trick** (1593-1607): a pure `NumAtt` pump instant in hand,
  castable, target has power > 0, and its keyword grants are at most
  Trample / First Strike / Double Strike →

```java
if (AiCardMemory.isMemorySetEmpty(ai, AiCardMemory.MemorySet.TRICK_ATTACKERS)) {
    boolean reserved = ((PlayerControllerAi) ai.getController()).getAi().reserveManaSources(sa, PhaseType.COMBAT_DECLARE_BLOCKERS, false);
    if (reserved) {
        AiCardMemory.rememberCard(ai, c, AiCardMemory.MemorySet.TRICK_ATTACKERS);
        return false;
    }
}
```

  (1840-1853): the mana is reserved until declare blockers, the creature
  is remembered, and `declareAttackers` sends it in unconditionally
  (991-999). One bait per turn.
- **at declare blockers** (1645-1800): pump to save a combatant that would
  die (1677), to make a combatant kill what it is fighting (1685), to push
  a blocked-but-surviving attacker over (1710), lifelink races (1786), and
  to make blockers survive a trampler when life is in danger (1795).
- the tail:

```java
return simAI || MyRandom.getRandom().nextFloat() < chance;
```

  (1862) — even a correct pump is cast with probability `chance`
  (profile-dependent) outside the simulation AI.

Memory sets that carry state between decisions (`AiCardMemory.java:53-66`):
`TRICK_ATTACKERS`, `HELD_MANA_SOURCES_FOR_DECLBLK`,
`HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK`, `HELD_MANA_SOURCES_FOR_MAIN2`,
`CHOSEN_FOG_EFFECT`, `REVEALED_CARDS`, `PAYS_TAP_COST`, `PAYS_SAC_COST`.
Ours has the same shape in `_main2_reserve` (`ai_player.gd:2909-3010`
uses it for firebreathing) but no per-turn memory of a bait attacker.

### 1.11 The profile knobs that touch combat

| property (`AiProps.java`) | Default | Reckless | Cautious | Experimental | read at |
|---|---|---|---|---|---|
| `PLAY_AGGRO` | false | true | false | false | `AiAttackController.java:858`, `AiBlockController.java:1051` |
| `CHANCE_TO_ATTACK_INTO_TRADE` | 0 | 100 | 0 | 0 | read 859; ladder level 4 (1231, 1233) |
| `ATTACK_INTO_TRADE_WHEN_TAPPED_OUT` | false | true | false | false | 860, 1238 |
| `RANDOMLY_ATKTRADE_ONLY_ON_LOWER_LIFE_PRESSURE` | true | false | true | true | 862, 1243 |
| `CHANCE_TO_ATKTRADE_WHEN_OPP_HAS_MANA` | 30 | 100 | 0 | 30 | 861, 1242 |
| `TRY_TO_AVOID_ATTACKING_INTO_CERTAIN_BLOCK` | true | true | false | true | 1415 |
| `TRY_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` | true | true | false | true | `ComputerUtilCard.java:1493` |
| `CHANCE_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` | 65 | 65 | 75 | 75 | 1494 |
| `ENABLE_RANDOM_FAVORABLE_TRADES_ON_BLOCK` | true | true | true | true | `AiBlockController.java:1288` |
| `MIN/MAX_CHANCE_TO_RANDOMLY_TRADE_ON_BLOCK` | 30/70 | 0/50 | 40/65 | 30/70 | 1291-1292 |
| `MAX_DIFF_IN_CREATURE_COUNT_TO_TRADE` | 1 | 0 | 0 | 1 | 1294 |
| `ALSO_TRADE_WHEN_HAVE_A_REPLACEMENT_CREAT` | true | true | false | true | 1290 |
| `AI_IN_DANGER_THRESHOLD` / `_MAX_THRESHOLD` | 4/4 | 4/4 | 4/6 | 3/12 | `ComputerUtilCombat.java:443-444` |
| `COMBAT_ASSAULT_ATTACK_EVASION_PREDICTION` | true | true | true | true | `AiAttackController.java:617` |
| `COMBAT_ATTRITION_ATTACK_EVASION_PREDICTION` | true | true | true | true | 863 |

Everything that distinguishes Reckless from Cautious is a probability or a
"trade at parity" switch; none of the four changes what the AI *sees*.
That is the opposite of our ladder, where rungs differ by capabilities and
`mistake_chance` and every decision below the mistake is deterministic
(`docs/ai-difficulty.md:38-51`).

---

## 2. EVALUATION — `CreatureEvaluator` and what consumes it

### 2.1 The scoring, term by term (`forge/forge-ai/src/main/java/forge/ai/CreatureEvaluator.java:29-294`)

`evaluateCreature(c, considerPT, considerCMC)`; the default call is
`(true, true)`. `power` is `getNetCombatDamage()` (zeroed for "prevent all
damage dealt by" creatures, 43-49), `toughness` is `getNetToughness()`.
Terms in source order, with the pool-relevant ones marked (*):

| term | value | line |
|---|---|---|
| base (*) | `80` | 33 |
| non-token (*) | `+20` | 35 |
| power (*) | `+ power * 15` | 52 |
| toughness (*) | `+ toughness * 10` | 54 |
| converted cost (*) | `+ cmc * 5` when `considerCMC` | 62 |
| flying (*) | `+ power * 10` | 67 |
| horsemanship | `+ power * 10` | 70 |
| unblockable (*) | `+ power * 10` | 74 |
| assigns damage as unblocked / fear (*) / intimidate / menace / skulk | `power * 6 / 6 / 6 / 4 / 3` | 76-92 |
| double strike | `+ 10 + power * 15` | 98 |
| first strike (*) | `+ 10 + power * 5` | 100 |
| deathtouch | `+25` | 103 |
| lifelink | `+ power * 10` | 106 |
| trample (*) | `+ (power - 1) * 5` when power > 1 | 109 |
| vigilance (*) | `+ power * 5 + toughness * 5` | 112 |
| infect / wither | `power * 15 / 10` | 115-118 |
| toxic, afflict, rampage (*) | `magnitude * 5 / 5 / 1` | 119-121 |
| annihilator, absorb, outlast, bushido, flanking, exalted, melee, prowess | 50/11/10/16/15/15/18/5 per magnitude | 124-135 |
| reach (*) | `+5` | 139 |
| indestructible / shield counters | `+70` / `+20` each | 145-148 |
| prevent all damage to it | `+60` (any) / `+50` (combat) | 150-153 |
| hexproof / shroud / ward | `+35 / +30 / +10` | 155-160 |
| protection (*) | `+20` flat | 162 |
| paired, encoded, undying/persist | `+14 / +24 / +30` | 167-176 |
| **defender (*)** | `- (power * 9 + 40)` | 180 |
| detained / "can't attack or block" | value reset to `50 + cmc * 5` | 185-187 |
| can't block / goaded / must attack (*) | `-10 / -5 / -10` | 189-198 |
| `DestroyWhenDamaged` hint | `- (toughness - 1) * 9` | 204 |
| untapped (*) | `+1` | 211 |
| doesn't untap / tapped and stuck | `-50` / reset to `50 + cmc * 5` | 215-220 |
| each activated ability (*) | `+10` default; `-10` if the cost is sacrifice-self; scaled for energy pumps | 226-228, 296-322 |
| mana ability (*) | `+10` | 233 |
| phasing (*) | `- max(20, value / 2)` | 238 |
| upkeep triggers (*) | cumulative upkeep `-30`; echo `-10`; upkeep damage to you `-20`; sacrifice-unless `-20`; fading/vanishing scaled | 246-282 |
| card hint `AIEvaluationModifier` | added last | 288-290 |

Worked values on 1995 cards, Forge default call (untapped `+1` omitted),
beside `Evaluator.permanent_value` (`shandalar/engine/ai/evaluator.gd:43-57`):

| card | Forge | ours | ratio |
|---|---|---|---|
| vanilla 2/2 for {1}{G} | 80+20+30+20+10 = **160** | 4.0 | 40 |
| vanilla 3/3 for {2}{G} | **190** | 6.0 | 32 |
| Llanowar Elves 1/1 | 80+20+15+10+5+10 mana = **140** | 2.0 | 70 |
| Drudge Skeletons 1/1, regenerates | 80+20+15+10+10+10 ability = **145** | 2.0 (+0.5 per shield up) | 72 |
| White Knight 2/2 first strike, pro-black | 160 + (10+10) + 20 = **200** | 4+1+1 = 6.0 | 33 |
| Hypnotic Specter 2/2 flying | 80+20+30+20+15+20 = **185** | 5.5 | 34 |
| Wall of Stone 0/8 defender | 80+20+0+80+15 −40 = **155** | 7.0 | 22 |
| Craw Wurm 6/4 | 80+20+90+40+30 = **260** | 10.0 | 26 |
| Serra Angel 4/4 flying vigilance | 80+20+60+40+25+40+40 = **305** | 10.0 | 30 |
| Shivan Dragon 5/5 flying, firebreathing | 80+20+75+50+30+50+10 = **315** | 11.5 | 27 |

Three things the table shows. (a) Forge's base of 100 makes *every* creature
worth at least a body: the gap between a 1/1 and a 2/2 is 25 points on 140,
where ours is 2 on 2 — Forge's "worst creature" choices for chumps are
much flatter than ours, and a Llanowar Elves is nearly a bear. (b) Forge
punishes defender hard (−40 −9/power) and rewards vigilance hard
(+5/point on both stats — Serra's vigilance is worth as much as her
flying); ours has −1.0 and +0.5. On our scale a Wall of Stone (7.0) is
worth more than a Hypnotic Specter (5.5) or a White Knight (6.0); on
Forge's it is worth less than either. Every consumer of
`permanent_value` that has to *pick* — a Terror, a Control Magic, the
chump rung, `_cohort_value`'s trade sums — inherits that ranking. (c)
Forge scales evasion with power (flying +10/power; a 5/5 flyer gets +50,
a 1/1 flyer +10); ours is flat 1.5 (`evaluator.gd:13`). At bear size the
two agree (20 ≈ 0.5 stat points × 40); at dragon size Forge says flying is
worth 5 toughness points and ours says 1.5.

The CMC term is optional, and Forge itself turns it off where it would
mislead: `wouldLikeToRandomlyTrade` compares
`evaluateCreature(attacker, true, false)` against the blocker
(`AiBlockController.java:1323`, 1338) — a trade is about what is on the
table, not what it cost.

`ComputerUtilCard.evaluateCreature` wraps the class through a
`creatureEvaluator` singleton (`forge/forge-ai/src/main/java/forge/ai/ComputerUtilCard.java:96-98`
sorts by it), and the simulation AI subclasses it
(`forge/forge-ai/src/main/java/forge/ai/simulation/GameStateEvaluator.java:323-331`)
to strip the +1 untapped term so that two game copies compare equal.

### 2.2 Best, worst and useless (`ComputerUtilCard.java`)

```java
public static Card getBestCreatureAI(final Iterable<Card> list) {
    ...
    return Aggregates.itemWithMax(IterableUtil.filter(list, CardPredicates.CREATURES), ComputerUtilCard.creatureEvaluator);
}
public static Card getWorstCreatureAI(final Iterable<Card> list) {
    ...
    return Aggregates.itemWithMin(IterableUtil.filter(list, CardPredicates.CREATURES), ComputerUtilCard.creatureEvaluator);
}
```

(622-627, 650-655). Every "which blocker" question in `AiBlockController`
is one of these two: `getWorstCreatureAI(killingBlockers)` for a safe
kill (block with the cheapest thing that does the job),
`getWorstCreatureAI(chumpBlockers)` for a chump, `getBestCreatureAI(usableBlockers)`
to lead a gang. The ordering is total, so ties fall to list order.

`evaluateRemovalTargetPriority` (592-614): a creature's evaluation, a
non-creature's `50 + 30 * cmc`, tokens +30 (gone for good), and for an
opposing permanent `+ evaluateBoardPosition(ai, controller) / 4` — the
stronger their position, the more any removal on them is worth.
`isUselessCreature` (2035-2055): detained, "can't attack or block", stolen
from us, or tapped and stuck.

`ComputerUtil.countUsefulCreatures` (`ComputerUtil.java:3084-3094`) is the
head count the ladder and the trade gate use — creatures minus the
useless ones.

### 2.3 The board score (`ComputerUtil.evaluateBoardPosition`, 2922-2960)

```java
rating += opponent.getCardsIn(ZoneType.Hand).size() * 15;
rating += opponent.getLandsInPlay().size() * 8;
if (opponent.getCardsIn(ZoneType.Library).size() < 3) { rating /= 5; }
for (final Card c : opponent.getCardsIn(ZoneType.Battlefield)) {
    if (c.isCreature())            { rating += ComputerUtilCard.evaluateCreature(c) / 2; }
    else if (c.isPlaneswalker())   { rating += 50 + c.getCMC() * 20 + c.getCounters(CounterEnumType.LOYALTY) * 10; }
    else if (!c.isLand())          { rating += 25 + c.getCMC() * 15; }
}
if (ai == null) { rating += opponent.getLife() * 3; }
else {
    int remainingLife = predictNextCombatsRemainingLife(ai, true, true, 0 , null, List.of(opponent));
    if (remainingLife < ai.getLife()) {
        int lifeLoss = Math.abs(ai.getLife() - Math.max(-20, remainingLife));
        rating += lifeLoss * lifeLoss;
    }
}
```

It is one-sided ("how threatening is *that* player") and its life term is
not their life but *our* predicted loss to their next swing, squared. Our
`Evaluator.position_score` (`evaluator.gd:121-138`) is two-sided and
linear: `(life diff) * 1 + (board diff) * 2 + (hand diff) * 1.5 + (land diff) * 1`,
with a creature counted at its full `permanent_value` where Forge halves
it. Forge's hand term (15 per card ≈ 0.4 stat points at 40:1 against
ours 1.5) says a card in hand is a tenth of a bear; ours says it is more
than a third of one. (Cards in hand are public in *number*, so both are
fair reads.)

### 2.4 The simulation evaluator (`GameStateEvaluator`)

The simulation AI (`AiController.usesFullSimulation`, `AiController.java:114`, off in all four
shipped profiles) scores a state by copying the game, advancing the copy
through combat damage, and reading the result:
`simulateUpcomingCombatThisTurn` (`GameStateEvaluator.java:39-58`),
`getScoreForGameState` (102-116). The score is life ± creatures ±
cards, with a non-creature permanent at

```java
return 50 + 30 * card.getCMC();
```

(`evalCard`, 253-274; opposing hand cards −4 each, own +1 and +4 more per
"full value" card, 118+). Forge's own journal on cost is the
`GameCopier` machinery it needs; ours measured that a copied whole turn
costs as much as a flat snapshot and built `CombatSearch` on arrays
instead (`shandalar/engine/ai/combat_search.gd:62-77`). The two
approaches sit at opposite ends of the same trade: Forge's copy sees every
trigger and static for free and pays in time; ours sees only what
`_build_combat_model` precomputed (`ai_player.gd:3450-3528`) and pays
nothing per node.

### 2.5 Where the evaluation feeds combat

| consumer | what it asks | pointer |
|---|---|---|
| `SpellAbilityFactors.isWorthLessThanAllKillers` | is every blocker that kills me worth more than me | `AiAttackController.java:1395-1398` |
| `makeGoodBlocks` rung 5 | `evaluateCreature(worst) + diff < value(attacker)` | `AiBlockController.java:287` |
| `makeTradeBlocks` / `wouldLikeToRandomlyTrade` | `evalBlk <= evalAtk + 1` (no CMC) | 1323, 1338, 1352 |
| `makeGangBlocks` | usable if cheaper than the attacker by `diff`; leader is the best; add if `currentValue + addedValue - 50 <= evalAttackerValue` | 441, 448, 472 |
| `reinforceBlockersToKill` | add if `evaluateCreature(blocker) + diff < evaluateCreature(attacker)` | 850 |
| `makeChumpBlocks` | throw `getWorstCreatureAI(chumpBlockers)` | 678 |
| `orderBlockers` | kill best first | 1176-1197 |
| `orderAttackers` | same on the other side | 1245 |
| `notNeededAsBlockers` | none — it releases by *power* descending (412) and checks life, not value | 412 |
| the ladder | none — ratios of life to damage and head counts only | 1117-1136 |
| `evaluateBoardPosition` → `evaluateRemovalTargetPriority` | removal targets | `ComputerUtil.java:2939`, `ComputerUtilCard.java:611` |

So the evaluation decides *which body* in every block rung and gates the
trade rungs; it never decides *whether to attack at all* — that is the
ratios' job — and inside `shouldAttack` it appears only as
`isWorthLessThanAllKillers`. The attack side is therefore evaluator-
insensitive except for the "worth" flag, which is a useful property when
the evaluator is crude.

---

## 3. SIDE BY SIDE — ours against Forge, seam by seam

Ours is `shandalar/engine/ai/ai_player.gd` (attack 3158-3706, block
3708-3990, responses 2808-3010, damage order 4873-4933),
`shandalar/engine/ai/combat_search.gd` (the crack-back search) and
`shandalar/engine/ai/evaluator.gd`. Verdict column: **ours** = ours is
stronger, **=** equivalent, **Forge** = Forge sees something ours cannot
(with the seam named).

| topic | ours | Forge | verdict |
|---|---|---|---|
| Lethal push | `_damage_through_blocks` ≥ life → all in (`ai_player.gd:3173-3180`); blocks assigned by the defender's gain | `doAssault` (573-760); blocks assigned biggest-attacker-first | = (ours models the defender better; Forge adds trample overflow of *blocked* tramplers, ours counts it inside `_damage_through_blocks` too) |
| Per-creature attack risk | `_attack_risk` (3362-3380): worst single-blocker outcome in stat points — my value if killed-and-survives, `max(trade, 0)` for a trade-down, −1 if unblockable | `SpellAbilityFactors` (1339-1444): booleans `canBeKilledByOne`, `canKillAll`, `isWorthLessThanAllKillers`, `canBeBlocked` | **ours** — a priced continuum against a set of flags |
| Group decision | `_choose_attack_cohort` (3659-3706): base = risk ≤ tolerance; grow by risk order; keep the best prefix by `_cohort_value` (3595-3657), which prices damage through, kills and losses under a one-blocker-per-attacker defender | none — the group is the union of creatures that pass `shouldAttack` individually; the ladder's `attackers.size() > 1` and `outNumber` are the only group terms | **ours** |
| Whether to attack at all | `_combat_tolerance` (3545-3549): `(aggression - 0.5) * 6 + posture`, posture = 1.0 when `position_score > 5` | the ratio block and ladder (1117-1260): `ratioDiff`, `outNumber`, attrition loop, unblockable clock, `humanLifeToDamageRatio < 2` | **Forge** — it reads the *race*; ours reads a constant and a coarse position bit. Seam: `_combat_tolerance` |
| What stays home | `_search_hold_back` (3397-3447): alpha-beta over our attack subsets × their crack-back × our best defence, `CombatSearch.best_attack` (`combat_search.gd:410`), gated on `reach >= life` | `notNeededAsBlockers` (341-492): release by power, mock counter-attack through the *real* block controller, stop at `lifeInDanger`; non-aggro decks also stop when the extra life lost exceeds the attacker's own damage | mixed — ours is exact where it runs (`docs/ROADMAP.md:1313-1330`), Forge runs always. Seam: the gate `if reach < game.players[pid].life: return chosen` (3407) |
| Their blockers | untapped creatures only (`ai_player.gd:3166-3169`); `_build_combat_model` theirs = creatures (3450+) | `getOpponentCreatures` (130-177) adds lands/artifacts that can animate for the mana they have open | **Forge** — Mishra's Factory. Seam: the blocker list in `_declare_attacks` and `_build_combat_model` |
| Their pumps | none; `_dies_to` (2605-2613) knows indestructible, first strike (`_damage_from` 2560-2570), prevention/protection (`_damage_after_prevention` 2584-2602) and regeneration reach (`_shieldable` 2617-2640, counts their open sources against the cheapest shield) | `predictPowerBonusOfBlocker/Attacker` (868-994, 1138-1322): every instant-speed activated pump the controller can pay for, one activation; blocking/attacking triggers; `canRegenerate` | **Forge** — firebreathing, Shades, Pump Knights, Frozen Shade. Seam: `_shieldable` is the pattern; `_dies_to` the site |
| Destroy-on-block | none — Cockatrice / Thicket Basilisk are `TriggeredAbility(BLOCKED, ...)` on the card (`shandalar/cards/sets/2ed/cockatrice.gd`), not read by `_dies_to` | `canDestroyAttackerBeforeFirstStrike` (1546-1592), consulted first in `canDestroyAttacker` (1651); `shieldDamage` = 0 for a blocker that dies first (640-642) | **Forge**. Seam: `_dies_to`, `_attack_risk` |
| Rampage | engine applies `cur_rampage` (`shandalar/engine/core/card_instance.gd:433`, `shandalar/engine/mtg_game.gd:2706-2714`); the AI's gang rung (3) and `CombatSearch.resolve_block` do not add it | read as a trigger in `predictPowerBonusOfAttacker`; rampagers excluded from gang/reinforce (`rampagesOrNeedsManyToBlock`, 369, 798) | **Forge**. Seam: `_best_block_for` rung 3, `combat_search.gd:263` |
| Tap-to-destroy on attack | none in `_attack_risk`; `_defensive_combat_response` uses *our* Royal Assassin (2808-2907) | `canBeKilledByRoyalAssassin` (`ComputerUtilCard.java:911-938`): any opposing `Destroy` ability payable now that can target the creature only when tapped | **Forge**. Seam: `_attack_risk` (a structural read: untapped, payable, targets tapped) |
| Trade threshold on blocks | rung 2 of `_best_block_for` (3949-3953): `permanent_value(blocker) <= attacker_value + 0.5`, at any life | `diff = life * 2 - 5` (1050): 35 points at 20 life, 0 at ≤ 2, 0 always under `PLAY_AGGRO` | different, not better — ours trades a bear for a bear at 20 life, Forge does not until 17. Seam: the constant `0.5` |
| Safe block, then finish | rung 1.5/1.7 return the first survivor (3928-3947) and stop | `makeGoodBlocks` records `blockedButUnkilled`; `reinforceBlockersToKill` (795-858) adds safe bodies until the attacker dies | **Forge** — the double block that kills a Craw Wurm with a Wall of Stone plus a 3/3. Seam: `_best_block_for` rungs 1.5/1.7 (a second pass over `used`) |
| Gang blocks | rung 3: pairs only, `price <= attacker_value * 1.5 or desperate`, attacker not shieldable/indestructible; `CombatSearch` gangs up to `GANG_LIMIT` 3 from `GANG_POOL` 6 (`combat_search.gd:122-129`) inside the crack-back | doubles and triples, best leader, `currentValue + addedValue - 50 <= evalAttackerValue`; first-striker gangs (373-420) | = (Forge's triple is a chump-plus-kill; our search already prices three) |
| Chump | rung 4: cheapest body, and **only if `_face_damage_value(stopped) >= permanent_value(cheapest)`** unless lethal (3966-3990); 49 of 92 chumps were wasted before this (`docs/ROADMAP.md:551-640`) | `makeChumpBlocks` (635-706): worst creature, unpriced, whenever `lifeInDanger` | **ours** |
| Trample chump | rung 4 prices what the body actually soaks (`stopped = min(power, toughness - damage)`, 3979-3981) | `shieldDamage == 0` filter and redirect to a non-trampler (674-698); `reinforceBlockersAgainstTrample` | = |
| Panic line | `desperate = life - through <= chump_threshold` on the residue after value blocks (3729-3733); `chump_threshold` 3/4/5/6 up the ladder | `lifeInDanger`: `lifeThatWouldRemain < min(threshold, life)`, threshold 4 plus a random walk up to `AI_IN_DANGER_MAX_THRESHOLD` (443-453) | = (ours is deterministic; Forge's ladder direction is the other way — Cautious/Experimental panic *earlier*) |
| Lure / must-block | `_conscript_blocks` (3819-3872): every able body onto a lured attacker, Blaze of Glory, blocker cap | `makeRequiredBlocks` (953-985) after the voluntary plan | = |
| Must-attack | `_must_attack` (3288) conscripts before the mistake and the cap | forced attackers first (878-953) | = |
| Damage order | `order_blockers` (4873-4933): knapsack over ≤ 8 blockers, band budget | `orderBlockers` (1176-1197): killable first, best first | **ours** |
| Damage assignment (trample) | `CombatSearch._damage_order` (318) knapsack ≤ 6 for the search; engine assignment via `_packet_worth`/`order_blockers` | `distributeAIDamage` (2010-2112): lethal to each in order, rest to the player unless the player is lethal | = |
| Combat tricks, defence | `_defensive_combat_response` (2808-2907): Fog **by name** when unblocked ≥ `min(life, 7)`, instant removal on the attacker, tap-destroy, Giant Growth on a blocker worth ≥ 3.0 | `shouldPumpCard` at declare blockers (1645-1800): save / kill / survive-trample; Fog via `hasAFogEffect` and `CHOSEN_FOG_EFFECT` | = in reach; ours has a card-name seam already logged (`docs/ROADMAP.md`, dead-card class 1) |
| Combat tricks, offence | `_offensive_combat_response` (2909-3010): pump to lethal, `_find_x_power_pump`, pump/removal to win a block when `blocker + attacker value >= 5.0`, firebreathing with `_main2_reserve` (3011) | same branches; plus the **held trick** — reserve mana, remember one bait attacker, send it (1593-1607, 1837-1858, `AiAttackController.java:991-999`) | **Forge** on the bait. Seam: `_declare_attacks` counts the pump for one extra attacker (3184-3201) but does not reserve the mana or remember the bait |
| Fog worth | `_worth_stopping_attacks` (2041-2054): `through >= min(life, 7)` | `hasAFogEffect` → skip `lifeInDanger`; `CHOSEN_FOG_EFFECT` keeps the source home | = |
| Hidden information | rule: never read cards the seat may not see (`docs/ROADMAP.md:3073`); `_shieldable` counts *their open mana* (public) | convention: `checkingOther` flag; `hasAFogEffect` reads a hand when `!checkingOther` (1505-1507) | **ours** (a rule with tests against a convention) |
| Determinism | engine RNG only, mistakes only via `mistake_chance` (`CONTRIBUTING.md:197`, `docs/ai-difficulty.md:41-51`) | `MyRandom` in the ladder, the trade gate, the danger threshold and the pump tail | **ours** for measurement; see 5 |
| Creature worth | `permanent_value`: P+T, flat keyword bonuses, protection +1, landwalk +0.5, shields +0.5, defender −1 | `evaluateCreature`: base 100, P×15, T×10, evasion × power, vigilance × both, defender −(9P+40), +10 per ability | **Forge** on the defender discount and the ability bonus (2.1). Seam: `evaluator.gd:12-21, 43-57` |
| Position | `position_score` two-sided linear | `evaluateBoardPosition` one-sided, life loss squared | = (different jobs) |
| Where the profile enters | `aggression` (tolerance), `chump_threshold` (panic line and `_packet_worth`), `combat_search_nodes` (budget), `mistake_chance` (drop an attacker / a block), `holds_instants` | probabilities and the `PLAY_AGGRO` parity switch (1.11) | **ours** as a ladder; Forge as personalities |

### 3.1 What ours does that Forge cannot

The crack-back search. `CombatSearch.best_attack` (`combat_search.gd:410-441`)
enumerates our attack subsets (powerset up to `FULL_SUBSET_LIMIT` 5,
best-defender-first chain beyond), for each takes their greedy blocks
(`_after_our_attack`, 493), then their best counter-swing over subsets of
their untapped board (`_crack_back`, 581, `_their_subsets`, 613) against
our best defence including gangs (`_our_best_defence`, 633, `_assign`,
661, `_gangs_of`, 720), with `LOSS` for any line that ends us. Forge's
`notNeededAsBlockers` runs one greedy release with one mock defence and
stops at the first danger; it never asks "what if they attack with a
subset". The ROADMAP records that two cheaper approximations of the same
question failed measurement (`docs/ROADMAP.md:1313-1330`) before the
search passed — the reason to keep the exact form rather than port
Forge's.

The priced chump. Forge's `makeChumpBlocks` throws its worst creature
whenever `lifeInDanger` holds, and `lifeInDanger` is four points of life
by default. Ours refuses a chump that buys less life than the body is
worth unless the swing is lethal (`_best_block_for` 3966-3990). The block
audit that motivated it counted 49 wasted chumps in 92
(`docs/ROADMAP.md:551-640`). Forge would lose the same Llanowar Elves.

The cohort. `_cohort_value` prices the *group* — it knows that five 2/2s
into two 3/3s is a fine attack even though each 2/2 alone "can be killed
by one" — where Forge's ladder needs level 4 and the `outNumber > 0`
clause to reach the same answer, and reaches it by a dice roll at level 3
(`CHANCE_TO_ATTACK_INTO_TRADE`).

### 3.2 What Forge sees that ours cannot, and the seam for each

1. **The race.** Forge's `ratioDiff` compares how many of *their*
   counter-swings we can take with how many of *ours* they can take, and
   `turnsUntilDeathByUnblockable` counts a flyer's clock. Ours has
   `_combat_tolerance = (aggression - 0.5) * 6 + posture`: at Wizard
   (`aggression` 0.5) the tolerance is 0.0 or 1.0 — the same at 20 life
   facing nothing as at 4 life facing a 4/4 — and the clock enters only as
   `_face_damage_value`'s super-linear term. Seam: `_combat_tolerance`
   (3545-3549), which already takes `game`.
2. **Their open mana as a pump.** `_shieldable` proves the pattern is
   allowed (their untapped sources counted against a cost on a creature
   they control, all public); nothing does it for `PumpEffect` abilities.
   A Shivan Dragon with four Mountains open is a 5/5 to `_dies_to`. Seam:
   `_dies_to` (2605-2613), its `hitter_bonus`/`victim_bonus` parameters
   are already there for exactly this shape.
3. **Destroy-on-block and rampage.** Both are on the card as engine
   objects (`TriggeredAbility(Mtg.EventType.BLOCKED, ...)`, `cur_rampage`)
   and neither reaches `_dies_to`, `_attack_risk`, rung 3 or
   `CombatSearch.resolve_block`. Seam: `_build_combat_model` (3450-3528)
   is where every predicate is precomputed into matrices; a "dies when
   blocked by" bit and a per-attacker rampage bonus fit that table.
4. **The manland.** Seam: the two blocker lists (3166-3169, 3450+).
5. **Reinforce to kill.** Seam: `_best_block_for` returns on rung 1.5/1.7
   with one blocker and `used` marks it; a second pass over the remaining
   `free` for attackers that were blocked-but-not-killed is the shape.
6. **The held trick.** Seam: `_declare_attacks` 3184-3201 already finds
   the pump and picks the one body it makes reasonable; what is missing
   is the mana reservation until declare blockers (the `_main2_reserve`
   mechanism, 3011) and the memory that this body is the bait so
   `_offensive_combat_response` spends the pump on it first.
7. **The defender discount and the ability bonus** in the evaluator.
   Seam: `evaluator.gd:19-20, 43-57`.

### 3.3 Equivalent and not worth touching

First strike (both sides), trample overflow, protection and prevention,
regeneration shields, evasion legality through one predicate, lure and
must-block conscription, must-attack, Fog worth, the lethal push, the
panic line. Where the numbers differ (`chump_threshold` 5 vs `threshold`
4; Fog at `min(life, 7)`) they are within the noise a 1,000-game sweep can
see.

---

## 4. PROPOSALS — ranked knobs for the ladder

Ranked by expected effect on "plays like a competent human at the table",
which is a different order from "biggest win-rate delta": a human notices
the AI swinging a Craw Wurm into a Cockatrice once and never trusts it
again, whereas a two-point race improvement is invisible to them and
visible only to the Lab.

Ground rules every proposal obeys (`docs/ai-difficulty.md:38-51`): it is
a knob on `AiProfile` (`shandalar/engine/ai/ai_profile.gd`), off in
`apprentice()`/`magician()` and on from the rung named, monotone, no
strength dial of its own, no card name in the decision, nothing read that
the seat may not see. Each is measured with the Lab's sweep
(`shandalar/DeckLab/README.md:295-368`): a CANDIDATE pair where the knob
fires, its NULL, and a CONTROL pair where the knob cannot fire and must
replay the null byte for byte (exit 4 otherwise). "No harm" throughout
means: on every starter matchup of the five-deck gauntlet
(`decks/big_green.deck`, `white_knights.deck`, `mountain_artillery.deck`,
`blue_skies.deck`, `black_red_raiders.deck`) plus the 1997 originals under
`decks/1997/originals/`, the candidate's delta against its null is not
below the negative interval (−4.4 points at 1,000 games per arm; −3.1 at
2,000), the control PASSES, and no deck that lost to an earlier rejected
approximation (Mountain Artillery −2.3, Big Green −1.1 —
`docs/ROADMAP.md:1313-1330`) loses again. A knob that lifts one deck by
hurting another by more does not ship; it goes in the ROADMAP as a
measured "no".

### P1. The race read — `reads_race` (Sorcerer, Wizard) — size M

**Design.** `_combat_tolerance` (`ai_player.gd:3545-3549`) is today
`(aggression - 0.5) * 6 + posture`: at Wizard it is 0 or 1 regardless of
the clocks. Forge's contribution is the *shape* of the question, not its
constants: how many of their counter-swings can we take
(`aiLifeToPlayerDamageRatio`), how many of ours can they take
(`humanLifeToDamageRatio`), and does the difference favour attacking
(`ratioDiff`, 1117-1136) — plus the unblockable clock
(`turnsUntilDeathByUnblockable`, 1214). The port in our units: from public
numbers only — our life, their life, the sum of power of their creatures
that could attack next turn (`_could_attack_next_turn`, 3530), the sum of
power of our candidates, and what of ours nothing of theirs can block —
compute `our_clock = ceil(their_life / our_reach)` and
`their_clock = ceil(our_life / their_reach)` (∞ when a reach is 0), and let
the tolerance move by `clamp(their_clock - our_clock, -2, +2)` stat
points: when we kill faster we accept a worse single-creature risk (we
are the beatdown); when they kill faster we accept less and keep blockers
(we are the control). The posture term stays. The unblockable clock adds
+1 when an evasive attacker of ours would win the race alone within
`their_clock` turns. Do **not** port the `--` per blocker or the
attrition loop: the crack-back search already prices what the
counter-swing costs, and the two earlier brakes that assumed "they swing
with everything" were the pessimism that failed
(`docs/ROADMAP.md:1313-1330`).

**Knob.** `reads_race: bool`. Off → today's tolerance; the null is
byte-identical.

**Defensive half (measured separately).** Forge's
`diff = life * 2 - 5` (`AiBlockController.java:1050`) says a *voluntary*
trade must gain more the healthier you are. Our rung 2
(`_best_block_for`, 3949-3953) trades at `<= attacker_value + 0.5` at any
life. Under the same knob, tighten rung 2 by the same clock difference
(demand a gain when `their_clock > our_clock + 1`, allow a small loss
when the reverse). Sweep it as its own arm by setting the offensive half
on in the null (`--null` with the tolerance change, candidate with both).

**Risk.** Medium: a tolerance that moves is the first thing the two
rejected approximations were, and both were rejected because they moved
the wrong deck. The asymmetry protects it here — it *raises* tolerance
for the deck ahead on the clock — but Mountain Artillery (burn plus small
bodies) is the deck whose reach is most often mispriced.

**Lab.** `--sweep reads_race=on,off --gauntlet` over the five starters and
the originals, 2,000 games per arm; then the tournament pair
`decks/variants/the_deck_playable.deck` vs `decks/community/sligh_geeba_1996.deck`
(the archetypal control-vs-beatdown race) at 2,000. Control pair: the
two all-land decks from the mulligans sweep (`DeckLab/README.md:410-413`)
— no creature, no tolerance ever read — which must PASS. No harm as
above; the canaries are Mountain Artillery and Big Green.

### P2. Their pumps are public — `reads_pumps` (Sorcerer, Wizard) — size M

**Design.** Forge's kill oracles add to a combatant's power "every
activated pump its controller can pay for right now"
(`predictPowerBonusOfBlocker`, `ComputerUtilCombat.java:955-991`;
attacker twin 1138-1322), gated by `ComputerUtilCost.canPayCost`. Ours
already does exactly this for regeneration (`_shieldable`, 2617-2640,
counts their open untapped sources against the cheapest shield) and for
nothing else, so a Shivan Dragon with Mountains up is a 5/5 to `_dies_to`
and a Frozen Shade with four Swamps is a 0/1. Add `_pump_reach(game, inst)
-> Vector2i`: for a creature they control, the cheapest self-targeting
`PumpEffect` activated ability without a tap cost, times
`floor(open_sources / cost)` activations, capped at the smallest number
that changes a kill/survive answer (Forge counts one activation, which
under-reads a Shade; counting all is the honest read of public mana).
Feed it through the `hitter_bonus`/`victim_bonus` parameters `_dies_to`
already has, from `_attack_risk` (3362-3380), rung 1/2/3 of
`_best_block_for`, and the precomputed matrices in `_build_combat_model`
(3450-3528). Only the kill test reads it, never the face damage: a pump
that does not change who dies is still their mana to spend.

**Knob.** `reads_pumps: bool`. Null byte-identical where no opposing
creature has a pump ability.

**Risk.** Medium-low. The over-read is "they always have mana for the
pump", which turns a Shade deck's untapped Swamps into a wall; the
mitigation is that the read applies to the kill test only, and the
cohort still prices damage through. Also interacts with `holds_instants`
on *their* side only in that open mana is now doubly feared — measure
against a deck with both.

**Lab.** Candidate pair: a list that fields pumpable creatures against
Big Green — check the decklist first (`grep -l "Frozen Shade\|Shivan Dragon\|Knight of Stromgald\|Order of the Ebon Hand" decks/**/*.deck`),
the community Necropotence list is the likely one — 2,000 games; then
the five-starter gauntlet. Control pair: `big_green.deck` vs
`white_knights.deck` (neither has an activated pump on a creature;
Giant Growth is a spell and is not read) — must PASS. No harm as above.

### P3. Read the gaze, the rampage and the assassin — `reads_gaze` (Sorcerer, Wizard; candidate for every rung) — size S

**Design.** Three structural reads Forge makes and ours does not, each a
few lines at the seam:

1. *Destroy-on-block.* Forge scans the battlefield for a trigger that
   fires on this block whose ability is `Destroy` on the attacker
   (`canDestroyAttackerBeforeFirstStrike`, 1561-1590) and consults it
   before any damage maths (1651). Ours: a `TriggeredAbility` on
   `Mtg.EventType.BLOCKED` whose effects destroy the blocked creature
   (Cockatrice, Thicket Basilisk — `shandalar/cards/sets/2ed/cockatrice.gd`)
   becomes a bit in `_build_combat_model` and a clause in `_dies_to`:
   the attacker dies to that blocker whatever the numbers, and (Forge's
   `shieldDamage == 0`) it dies *before* dealing damage only if the
   trigger says so — Cockatrice's is end of combat, so the blocker still
   takes the hit; read the timing off the ability, do not assume.
2. *Rampage.* `cur_rampage` (`card_instance.gd:433`) is applied by the
   engine (`mtg_game.gd:2706-2714`) and ignored by rung 3 and
   `CombatSearch.resolve_block` (`combat_search.gd:263`). Add
   `rampage * (blockers - 1)` to the attacker's power in both.
3. *Tap-to-destroy.* Forge's `canBeKilledByRoyalAssassin`
   (`ComputerUtilCard.java:911-938`) is a shape test — an opposing
   `Destroy` ability, payable now, that can target the creature only when
   tapped — with no card name in it. In `_attack_risk`, an attacker that
   would tap into such an ability carries its full `permanent_value` as
   risk (non-vigilant only).

**Knob.** `reads_gaze: bool`. These are reads of the board, not
strength; the owner's ramp ruling (`docs/ai-difficulty.md:53-56`) decides
whether Apprentice and Magician get them. Measure it at every rung and
let the numbers argue.

**Risk.** Low. Null byte-identical unless one of the three cards is on
the table.

**Lab.** Candidate pair: a list with Cockatrice/Thicket Basilisk/Royal
Assassin/Craw Giant on seat B (grep the 1997 originals; the Ancients and
Coyote Tex directories carry the Legends cards) vs Big Green, 1,000
games per rung. Control: `big_green.deck` vs `white_knights.deck`. No
harm as above; expect the candidate delta to be small and positive and
the visible effect to be in the game log, not the win rate.

### P4. Safe block, then finish it — `reinforces_blocks` (Sorcerer, Wizard) — size S–M

**Design.** Forge's `makeGoodBlocks` takes a safe non-killing block and
records the attacker in `blockedButUnkilled`; `reinforceBlockersToKill`
(`AiBlockController.java:795-858`) then adds *safe* extra blockers until
the attacker dies, and unsafe ones only when one body completes the kill
exactly and is cheaper than the prize by `diff`. Ours returns on rung
1.5/1.7 with one survivor and never revisits. Add a second pass after
`_plan_blocks` (3764): for every attacker blocked by a survivor that does
not kill it, from the still-free legal blockers, add first a body that
also survives and closes the damage gap, else the cheapest body that
closes it exactly and is worth less than the attacker — the rung 3 price
rule (`price <= attacker_value * 1.5`) applied to the pair, and never
against an attacker that `_shieldable`/indestructible/`reads_gaze` says
cannot die. This is the Wall of Stone plus Grizzly Bears kill on a Craw
Wurm.

**Knob.** `reinforces_blocks: bool`.

**Risk.** Medium-low: the second body is exposed to a combat trick on the
attacker (Giant Growth makes the Wurm kill both). Forge accepts that
exposure; the price rule bounds it. The crack-back search already gangs
on defence (`gang_defence`, `combat_search.gd:146`), so the two must agree
— use the same price rule.

**Lab.** Candidate: `big_green.deck` vs `white_knights.deck` (fatties
into small first-strikers and walls) both ways, 2,000 games; gauntlet.
Control: the all-land pair (blocks are declared in every creature game,
so only a creatureless pair cannot fire it). No harm as above.

### P5. The held trick — `holds_tricks` (Wizard) — size M

**Design.** Forge reserves the mana for one pump instant until declare
blockers, remembers one bait attacker in `TRICK_ATTACKERS`, and sends it
(`ComputerUtilCard.java:1593-1607, 1837-1858`;
`AiAttackController.java:991-999`). Ours already picks the one body a pump
in hand makes reasonable (`_declare_attacks` 3184-3201) and already
spends the pump when blocked (`_offensive_combat_response` 2909-3010,
"win the block"); what is missing is that main 1 may spend the mana
first, and that the response does not know which attacker was sent *on
the strength of* the pump. Add: when the rider chooses a body, reserve the
pump's cost through the `_main2_reserve` mechanism (3011) until declare
blockers, and remember the body's id for the turn so the offensive
response prefers it. Deterministic — no `chance`; Forge's 65% roll is a
personality, not a capability.

**Knob.** `holds_tricks: bool`, Wizard only: a bluff layer is the last
rung of the ramp. Interacts with `holds_instants` (already Magician+):
the reservation is a subset of what `holds_instants` may already keep
open — check the null replays byte-identically when both are on and no
pump is in hand.

**Risk.** Medium: reserving mana costs development on the turn the bait is
sent; the measured cost of `holds_instants` is the precedent to read
first.

**Lab.** Candidate: `big_green.deck` (Giant Growth) vs `white_knights.deck`
and vs `mountain_artillery.deck`, 2,000 games each; gauntlet. Control: a
pair without pump instants (grep for `Giant Growth`, `Berserk`,
`Blood Lust`, `Howl from Beyond` in both lists before choosing). No harm
as above.

### P6. The defender discount and the ability bonus in the evaluator — no knob, a constant change — size L

**Design.** `permanent_value` (`evaluator.gd:43-57`) prices a Wall of
Stone at 7.0, above a Hypnotic Specter (5.5) and a White Knight (6.0);
Forge's −(9·power + 40) (`CreatureEvaluator.java:180`) puts it below
both, and its +10 per activated ability (226-228) and +10 for a mana
ability (233) put a Prodigal Sorcerer or Llanowar Elves above a vanilla
1/1. Every consumer that *picks* — removal targets, Control Magic, the
chump rung's "cheapest", `_cohort_value`'s trade sums, `counter_threshold`
— inherits the ranking. Proposed: `DEFENDER: -1.0` → a discount that
scales with toughness (a 0/8 wall is a fine blocker but never a threat:
`-(toughness * 0.4 + 1.0)` keeps Wall of Stone at 2.8, below a bear), and
`+0.5` per activated non-mana ability, `+0.5` for a mana ability. Keep
evasion flat: at the pool's sizes Forge's power-scaling and our flat 1.5
agree within a point until 5 power, and the big flyers in the pool
(Serra, Shivan, Mahamoti) are priced high by their stats already.

**Knob.** None — the evaluator is shared by every rung and every
consumer, so this is a global constant with a `mistake_chance=0` sweep
at *every* preset, not a capability. It is here because Forge's table is
the evidence for the change, and because the visible symptom (Terror on
the Wall, not the Specter) is a "not a competent human" tell.

**Risk.** High surface: the block audit, the chump price, the crack-back
search's `a_val`/`d_val`, and `counter_threshold`'s stat-point scale all
read `permanent_value`. Any of them can move. Size L for the measurement,
not the edit.

**Lab.** No knob to sweep, so two full runs of the starter gauntlet and
the originals at each preset with the constant changed vs. unchanged
(`--profile-a`/`--profile-b` both at the preset, 2,000 games per
matchup), and a third run pairing each preset against the *old* evaluator
(the null build kept in a worktree). No harm: no matchup at any preset
below −interval; the measured ladder (`docs/ai-difficulty.md`,
15.8/37.6/45.1/51.7 on Big Green) must stay monotone. Control: the
all-land pair.

### P7. The manland is a blocker — `reads_manlands` (Sorcerer, Wizard) — size S

**Design.** Forge's `getOpponentCreatures` (130-177) adds any opposing
land or artifact that can animate itself for the mana its controller has
open. Ours lists untapped creatures only (3166-3169) and `_build_combat_model`
the same (3450+), so a Mishra's Factory with `{1}` up is invisible to the
attack and to the crack-back. Add: an opposing untapped land whose
activated ability's effect makes it a creature (an `EffectIntent` read —
no name) with the cost payable from their *other* open sources, entered
as a blocker with the animated stats. Public information throughout.

**Knob.** `reads_manlands: bool`.

**Risk.** Low. The Factory is rare in the 1997 lists and common in the
tournament ones (`decks/tournament/`, `decks/variants/the_deck_playable.deck`).

**Lab.** Candidate: `decks/variants/the_deck_playable.deck` (Factories)
vs `big_green.deck` and vs `sligh_geeba_1996.deck`, 2,000 games. Control:
`big_green.deck` vs `white_knights.deck`. No harm as above.

### P8. A sub-lethal crack-back gate — `crack_back_margin` (Wizard) — size S

**Design.** `_search_hold_back` runs only when
`reach >= game.players[pid].life` (3407): the search is asked whether an
attack *loses the game* to the counter-swing, never whether it costs us
eight life for a point of damage. Forge's `notNeededAsBlockers` weighs
every sub-lethal counter-swing (a non-aggro deck stops releasing when the
extra life lost exceeds the attacker's own damage, 430-448). The search
already prices life (`_fdv`, `combat_search.gd:744`), so the change is
the gate alone: run when `reach >= life - crack_back_margin`. The
budget-slicing (`MIN_SLICE`, 116) bounds the cost; the ROADMAP's cost
table says what a declaration costs at 3,000 nodes.

**Knob.** `crack_back_margin: int`, 0 today (= the current gate), Wizard
at `chump_threshold` (6) — the panic line the block side already uses.
Numeric, like `chump_threshold`; the null is the seat's own value.

**Risk.** Medium: this is the third attempt at the question the two
brakes failed, and it runs the search more often. The difference from the
brakes — the search prices, it does not threshold — is the argument; the
Lab is the proof.

**Lab.** `--sweep crack_back_margin=0,6,10` on the five-starter gauntlet
at Wizard, 2,000 games per arm; Mountain Artillery and Big Green are the
canaries. Control: the all-land pair. No harm as above, plus a cost
budget: the per-declaration time in the Lab's timing column must not
exceed twice today's.

### P9. Attack triggers first, and the "effective attacker" — not proposed

Forge sorts attackers with attack triggers to the front (`sortAttackers`,
237-257) and skips 0-power attackers without an effect
(`isEffectiveAttacker`, 271-317). Ours skips `cur_power <= 0` unless
must-attack (3179, 3667) and the pool's attack triggers (Hypnotic Specter's
is on damage, not on attack) are priced by `_cohort_value`'s damage term.
Nothing to carry.

### Ranking summary

| # | knob | rung | size | why this rank |
|---|---|---|---|---|
| 1 | `reads_race` | Sorcerer, Wizard | M | racing is the thing a human does that ours does not |
| 2 | `reads_pumps` | Sorcerer, Wizard | M | attacking a bear into a Shade with mana up is the tell |
| 3 | `reads_gaze` | Sorcerer, Wizard (measure lower) | S | attacking into a Cockatrice is the other tell |
| 4 | `reinforces_blocks` | Sorcerer, Wizard | S–M | the double block that kills the fatty |
| 5 | `holds_tricks` | Wizard | M | the bait; last rung of the ramp |
| 6 | evaluator constants | all (no knob) | L | Terror the Specter, not the Wall |
| 7 | `reads_manlands` | Sorcerer, Wizard | S | rare in 1997 lists, common in tournament ones |
| 8 | `crack_back_margin` | Wizard | S | third attempt at the sub-lethal question, this time priced |


---

## 5. DO NOT COPY

Things in Forge's combat code that are wrong for an 897-card 1995 pool
(Unlimited, 4th Edition, Arabian Nights, Antiquities, Legends, The Dark,
Astral, promos) or for this architecture, with the pointer so nobody
rediscovers them.

1. **The hand read in `hasAFogEffect`**
   (`forge/forge-ai/src/main/java/forge/ai/ComputerUtil.java:1505-1507`).
   `if (!checkingOther) { all.addAll(defender.getCardsIn(ZoneType.Hand)); }`
   is correct when the defender is the AI itself and a leak the moment
   the function is called on the opponent with the flag wrong. Ours has
   a rule and tests (`docs/ROADMAP.md:3073`); the rule stays and any
   ported helper takes the seat's own hand only.

2. **Randomness as difficulty.** `lifeInDanger`'s random walk on the
   threshold (`ComputerUtilCombat.java:443-453`), `wouldLikeToRandomlyTrade`
   (`AiBlockController.java:1269-1356`), the level-3/4 dice in the ladder
   (`AiAttackController.java:1231-1247`), and the pump tail
   `return simAI || MyRandom.getRandom().nextFloat() < chance;`
   (`ComputerUtilCard.java:1862`). Ours is deterministic below the
   `mistake_chance` roll (`CONTRIBUTING.md:197`; `docs/ai-difficulty.md:41-51`),
   which is what makes a control pair replay byte for byte and a
   1,000-game sweep a measurement. Every Forge probability ports as a
   *deterministic* condition or not at all.

3. **`pilotsNonAggroDeck` by deck name**
   (`PlayerControllerAi.java:73`: `deck.getName().contains("Control") || deck.getAverageCMC() > 3`).
   A string match on the deck's title deciding how the AI attacks is a
   card-named decision one level up. If the beatdown/control split is
   wanted it is the race read (P1), computed from the board.

4. **Card-script hints as decisions.** `HasAttackEffect`, `HasCombatEffect`,
   `MustBeBlocked`, `SacMe`, `NonCombatPriority`, `DestroyWhenDamaged`,
   `AIEvaluationModifier` (`AiAttackController.java:1364-1367, 1461`;
   `ComputerUtilCombat.java:406-427`; `CreatureEvaluator.java:204, 288-290`)
   are per-card annotations the AI reads to know what a card does. Ours
   forbids card-named decisions and prices from `EffectIntent` and the
   engine's own ability objects (`docs/ai-difficulty.md:47-51`); every
   read in P3 is structural for that reason. The `Worship` and
   `Elderscale Wurm` name checks in `lifeInDanger` (401-407) are the same
   thing by another route.

5. **Post-1995 machinery.** Planeswalkers (`makeChumpBlocksToSavePW`,
   `chanceToTradeToSaveWalker`), menace (`makeGangNonLethalBlocks`),
   exalted (aggression 6 and `countExaltedBonus`), infect/wither/poison
   (`resultingPoison`, `canKillAllDangerous`, `dangerousBlockersPresent`),
   double strike, horsemanship, shadow, annihilator, daybound, morph,
   embalm, undying/persist, energy, stun and shield counters, afflict,
   bushido, flanking, crew (`maxBlockersAfterCrew`), commander damage.
   None exists in the pool; every one is a branch our code would carry
   for nothing. `FEAR` does exist (`shandalar/engine/core/mtg.gd:106`)
   and is already a legality predicate.

6. **The full game-copy simulation** (`GameStateEvaluator`,
   `AiController.usesFullSimulation`). Off in all four shipped profiles;
   ours measured the same idea (`combat_search.gd:62-75`: a copied turn
   is 0.8–1.1× a snapshot, ~4 ms a node, twelve seconds per declaration
   at a 3,000-node budget) and built the array model instead. Not a
   direction.

7. **Kill-in-order damage assignment** (`AiBlockController.orderBlockers`,
   1176-1197). Ours is a knapsack (`order_blockers`, `ai_player.gd:4873-4933`)
   and better; do not "simplify" toward Forge.

8. **Unpriced chumps** (`makeChumpBlocks`, 635-706). The block audit that
   priced ours (`docs/ROADMAP.md:551-640`) is the measured reason.

9. **Forge's evaluator constants as a unit.** The base of 100 and the
   +10-per-ability make every creature a body and flatten the bottom of
   the curve; the vigilance term (+5 per point of both stats) values
   Serra's vigilance as much as her flying. P6 takes the *shape* of two
   terms (defender, abilities), not the table.

10. **Literal keyword strings** — `"Landwalk:Plains"` in the banding
    evasion list (`AiAttackController.java:524-525`), the
    `"Prevent all combat damage that would be dealt by CARDNAME."` text
    matches in the evaluator (43-49, 150-153). Ours has `Mtg.Keyword` and
    prevention shields on the instance (`_damage_after_prevention`,
    2584-2602); text matching is the wrong seam.

11. **One-activation pump prediction** (`ComputerUtilCombat.java:955-991`
    adds `pBonus` once). Right for a Pump Knight, wrong for a Shade, a
    firebreather, or a Frozen Shade with the mana to pump thrice. P2
    counts activations.

---

## 6. LICENCE AND PROVENANCE

Forge is GPLv3 (`forge/LICENSE`, `forge/README.md`); the ShandalarGodot
engine is GPLv3 too, so carrying logic across is licence-compatible in
both directions. Compatibility is not attribution: the obligations are
to keep the notice and to say what came from where. In this project's
own terms, Forge is a **Tier 3** source — a reimplementation, "useful as
a guide, never as proof" (`shandalar/Provenance.md:49-55`) — beside
Manalink, s30 and mage-go, and gets the same treatment those get.

**Two words, defined for the ledger.**

- **Ported** — a function, formula or algorithm carried over so that a
  reader with both files open can match them line for line, even after
  translation to GDScript and renaming to our conventions. Examples if
  they land: the `ratioDiff` shape of P1, the `canDestroyAttackerBeforeFirstStrike`
  scan of P3, the `reinforceBlockersToKill` pass of P4, the held-trick
  reservation of P5. A port is GPL-derived code and carries a marker at
  the site (below) and a row in `Provenance.md`.
- **Inspired by** — an idea taken, the code written from our own
  primitives so that no line matches: "count their open mana against the
  cheapest pump" (P2 — the *pattern* is already ours in `_shieldable`;
  Forge is the reason to extend it), "a defender is not a threat" (P6),
  "a manland is a blocker" (P7). No line-for-line marker is owed;
  the design note in the ROADMAP names Forge as the source, as it names
  mage-go today (`shandalar/engine/ai/evaluator.gd:6`, `ai_player.gd:7`,
  `ai_profile.gd:7, 24`).

The test is whether the reader could reconstruct Forge's code from ours.
If yes, it is a port. When in doubt, mark it — the marker costs a line
and the omission costs the ledger's credibility.

**The `Provenance.md` row** (Tier 3 table, `shandalar/Provenance.md:450-458`,
same format as the s30 and mage-go rows):

```
| **Forge** — an open-source Magic engine and AI in Java, GPLv3 | `../forge`, `github.com/Card-Forge/forge.git`, commit `b09a3d3f` | The AI's combat and creature-evaluation code (`forge-ai/src/main/java/forge/ai/`). Read as a guide for the ladder's Sorcerer and Wizard capabilities (`docs/ai-difficulty.md`); every function ported line for line carries a `[forge]` marker at the site and a row below; ideas taken without code carry a note in the ROADMAP. Its profiles (`forge-gui/res/ai/*.ai`) are personalities with dice in them, not a difficulty ladder — read for the knob list, never for the values. |
```

and, under it, one line per port when a port lands, of the form
`[forge] AiBlockController.reinforceBlockersToKill (795-858) → ai_player.gd _reinforce_blocks` —
so the ledger says *which* function came from *where*, not that "some
AI code came from Forge".

**The marker at the site.** The project's convention is the tagged
comment (`[s30]` in `docs/duel-todo.md`, `Provenance.md:52-54`); the same
form for Forge, on the function's doc comment, with the source path and
line range at the commit read:

```gdscript
## [forge] Ported from forge-ai/src/main/java/forge/ai/AiBlockController.java:795-858
## (reinforceBlockersToKill) at b09a3d3f, GPLv3. The price rule is ours.
func _reinforce_blocks(...)
```

The commit hash matters: Forge moves, line numbers drift, and a future
reader must be able to check the claim against the file as it was read.

**What must not happen.** No Forge *resource* file — card scripts under
`forge-gui/res/cardsfolder/`, the `.ai` profiles, deck lists, images —
ships or is copied into the repository; they are data, some of it
carrying other people's rights, and `Provenance.md`'s "What ships, and
what does not" rule covers them exactly as it covers Manalink's. Reading
`craw_giant.txt` to learn how Rampage is keyed (as this note did) is
research; copying it is not.

**This note.** It quotes Forge source under GPLv3 for the purpose of
study and quotes our own; it may be quoted into `docs/` as an
engineering note with the pointers intact.
