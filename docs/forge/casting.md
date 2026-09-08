# Forge's spell and ability decisions, read against ours

An engineering note on `forge-ai` (Forge, GPLv3, shallow clone at commit
`b09a3d3f0093b7ba26a0debc82d80996b8826b37`, dated 2026-09-08, in
`../forge`) — the slice that decides WHAT TO CAST, WHEN, and WHAT TO KEEP
OPEN — with our own `engine/ai/` beside it function by function, and a
ranked list of what the Wizard could take from it. Every claim carries a
file:line pointer into the clone (`forge/...`) or into this repository
(`engine/...`, `docs/...`); the line numbers are those of the commit above.
Where a threshold matters the code is quoted.

The pool is the 897 cards of the 1997 game; nothing printed after 1995 is
considered, and Forge's machinery for later mechanics (planeswalkers,
energy, storm, foretell, plot, blitz, backup …) is mentioned only where it
sits in the path a 1995 spell takes.

Contents: 1 Map · 2 Holding and reserving · 3 The ability AIs · 4 Profiles
and memory · 5 The mulligan · 6 The simulation AI · 7 The cards · 8 Side by
side · 9 Proposals · 10 Do not copy · 11 Licence and provenance.

---

## 1. MAP — the decision loop, with real names

### 1.1 Who asks, how often

The rules engine asks the priority player's controller for ONE spell or
ability at a time and plays it, then asks again with priority still held,
until the controller returns nothing (a pass). The loop is
`PhaseHandler.mainLoopStep`
(`forge/forge-game/src/main/java/forge/game/phase/PhaseHandler.java:1039-1103`):
`chosenSa = pPlayerPriority.getController().chooseSpellAbilityToPlay();`
(`:1056`), repeated `while (loopCount < 999 || !...isAI())` (`:1102`) — an
AI seat is cut off after 999 plays in one priority window (`:1104`). So
Forge, like ours, is ONE ACTION PER CALL and greedy across calls; nothing
in the heuristic path plans a sequence of two plays (the one exception is
the "chain two damage spells" reservation, §2.4).

### 1.2 `AiController.chooseSpellAbilityToPlay` — the top of the AI

`forge/forge-ai/src/main/java/forge/ai/AiController.java:1355-1402`, in
order:

1. `AiCache.clear()` and forget `HELD_MANA_SOURCES_FOR_NEXT_SPELL`
   (`:1364`) — a "next spell" reservation lives for one decision only.
2. `if (usesFullSimulation()) return singleSpellAbilityList(simPicker.chooseSpellAbilityToPlay(null));`
   (`:1366-1368`) — the simulation picker replaces everything below (§6).
3. Cards with `SVar:PlayBeforeLandDrop` are tried first (`:1370-1380`).
4. THE LAND DROP: `chooseBestLandToPlay` (`:474-688`, filtered by
   `filterLandsToPlay` `:411-472`), played now unless it is Main 1 and
   `isSafeToHoldLandDropForMain2(land)` says to keep it for Main 2 (`:1388`;
   the hold rule is §1.7).
5. `return singleSpellAbilityList(getSpellAbilityToPlay());` (`:1401`).

### 1.3 `getSpellAbilityToPlay` — the playable set and the stack check

`AiController.java:1518-1588`:

- Playable cards are gathered by `ComputerUtilAbility.getAvailableCards`
  (`forge/forge-ai/src/main/java/forge/ai/ComputerUtilAbility.java:67-80`):
  hand, battlefield, and the other zones a card can be played from.
- If the top of the stack is the AI's own spell it returns null (pass) —
  unless a copy spell is available (`:1544-1552`). The AI never responds to
  itself.
- If the stack is not empty, COUNTERS ARE TRIED FIRST:
  `SpellAbility counter = chooseCounterSpell(getPlayableCounters(cards)); if (counter != null) return counter;`
  then ETB-counters (`:1556-1562`). `chooseCounterSpell` (`:691-717`) takes
  the counter with the highest `ComputerUtil.counterSpellRestriction`
  score (§1.9). Only then does the general picker run, with counters
  skipped (`skipCounter`).
- Land abilities and `RemAIDeck` cards are removed from the list
  (`:1568-1572`); the rest goes to `chooseSpellAbilityToPlayFromList(saList, true)` (`:1581`).

### 1.4 `chooseSpellAbilityToPlayFromList` — ordering and the first WillPlay

`AiController.java:1590-1729`:

```java
Collections.sort(all, ComputerUtilAbility.saEvaluator); // put best spells first
ComputerUtilAbility.sortCreatureSpells(all);
```
(`:1595-1596`), then inside a `FutureTask` bounded by the game's AI
timeout (`:1606`, `future.get(game.getAITimeout(), TimeUnit.SECONDS)` `:1697`;
`Game.java:101-102` sets 5 s), the loop:

```java
if (skipCounter && sa.getApi() == ApiType.Counter) continue;          // :1611-1613
...
AiPlayDecision opinion = canPlayAndPayFor(sa);                          // :1670
if (opinion != AiPlayDecision.WillPlay) continue;                       // :1679-1681
// TODO could continue to try find another with higher rating (weighted by priority ordering)
return sa;                                                              // :1683
```

So the ORDER is the decision: the list is sorted once by
`ComputerUtilAbility.compareEvaluator` (`ComputerUtilAbility.java:245-338`;
`saEvaluator` at `:240`) — mana value first, highest first, with the
priority modifiers of `getSpellAbilityPriority` (`:340-451`): creature +1,
`RemAIDeck` −10, `SVar:AIPriorityModifier`, `EndOfTurnLeavePlay` +1
(`:366`), a bonus when the hand is over size, equipment with nothing to
carry −9, cards playable from the graveyard +50,
`PRIORITY_REDUCTION_FOR_STORM_SPELLS` (`:392`), `DestroyAll` +4, mana
abilities −9, `ManaRitual` +9 — and `sortCreatureSpells` (`:454-470`)
moves creatures ahead within equal cost. The first candidate whose
ability-AI says `WillPlay` is cast; the rating in `AiAbilityDecision` is
never compared across candidates. Forge's own comment admits it.

### 1.5 `canPlayAndPayFor` / `canPlaySa` — the AiPlayDecision reasons

`canPlayAndPayFor` (`AiController.java:814-843`) is "can the ability-AI
justify it, then can the mana be paid". `canPlaySa` (`:875-964`) produces
the reasons, in this order:

| check | reason |
|---|---|
| `checkAiSpecificRestrictions` fails | `CantPlayAi` |
| `!sa.canCastTiming(player)` (`:884`) | `TimingRestrictions` |
| `TRY_TO_PRESERVE_BUYBACK_SPELLS` and this would be the last copy (`:890`) | `NeedsToPlayCriteriaNotMet` |
| `SpellApiToAi.Converter.get(sa).canPlayWithSubs(player, sa).willingToPlay()` false (`:903`) | `CantPlayAi` |
| non-API spell whose X cannot be paid (`:917-920`) | `CantAffordX` |
| plot / foretell / suspend before Main 2 (`:933`) | `WaitForMain2` |
| `!sa.isLegalAfterStack()` (`:939`) | `AnotherTime` |
| `checkRestrictions` fails (`:949`) | `AnotherTime` |
| targeting cannot be completed (`:952-957`) | `TargetingFailed` |
| `saSideEffects` (`:966-1002`): hybrid-sim veto → `HybridSimRejected`; `SVar:NonStackingEffect` already active → `DoesntImpactGame` (`:975`); damage/ETB would kill the AI → `CurseEffects`/`BadEtbEffects` (`:985-999`); `NeedsToPlay`/`NeedsToPlayVar` SVar unmet → `MissingNeededCards`/`NeedsToPlayCriteriaNotMet` (`:1001` → `ComputerUtilCard.java:2137-2200`) | |

`AiPlayDecision` (`forge/forge-ai/src/main/java/forge/ai/AiPlayDecision.java`,
53 lines) has a `willingToPlay()` set — `WillPlay, MandatoryPlay,
PlayToEmptyHand, AddBoardPresence, ImpactCombat, ResponseToStackResolve,
Removal, Tempo, CardAdvantage` — but `canPlaySa` folds all of them into
`WillPlay` (`:903`), so the picker only ever sees `WillPlay` or a refusal.
The refusal names are for the debug log; nothing weighs them.

### 1.6 The ability-AI gate — one class per `ApiType`

`SpellApiToAi.Converter` maps every `ApiType` to a `SpellAbilityAi`
subclass. The chain, in `forge/forge-ai/src/main/java/forge/ai/SpellAbilityAi.java`:
`canPlayWithSubs` (`:56-67`, the main ability then each sub-ability's
`chkDrawback`) → `canPlay` (`:72-79`) → `canPlayWithoutRestrict`
(`:81-120`): `checkAiLogic` (the card's `AILogic$` string, `:171-180`) →
`checkPhaseRestrictions` → `checkApiLogic` → `willPayCosts`
(`:377-391`, life costs refused below 4 life unless the profile says
otherwise). The DEFAULT `checkApiLogic` (`:185-192`) is

```java
return activations == 0 || MyRandom.getRandom().nextFloat() < .8f
```

— an ability with no specialised AI is played the first time and then 80 %
of the time. Fifty-odd subclasses override it; the ones a 1995 pool meets
are §3.

### 1.7 Land drops, Main 1 vs Main 2

THE LAND: always before spells (§1.2), and held to Main 2 only by
`isSafeToHoldLandDropForMain2` (`AiController.java:1404-1516`):

```java
if (!MyRandom.percentTrue(getIntProperty(AiProps.HOLD_LAND_DROP_FOR_MAIN2_IF_UNUSED))) return false;   // :1411
if (game.getPhaseHandler().getTurn() <= 2) return false; // too obvious                                  // :1415-1418
```
then `HOLD_LAND_DROP_ONLY_IF_HAVE_OTHER_PERMS` (`:1423`), a tapland test,
and the arithmetic (`:1443-1444`, `:1504-1512`):

```java
canCastWithLandDrop = (predictedMana + 1 >= minCMCInHand) && minCMCInHand > 0 && !isTapLand;
cantCastAnythingNow = predictedMana < minCMCInHand;
...
if (!canCastWithLandDrop && cantCastAnythingNow && !hasLandBasedEffect && (!hasRelevantAbsOTB || isTapLand)) return true;
if ((predictedMana <= totalCMCInHand && canCastWithLandDrop) || (hasRelevantAbsOTB && !isTapLand) || hasLandBasedEffect) return false;
return true;
```
i.e. a land that changes nothing castable this turn is kept until after
combat, to give the opponent less to read. It is a bluff, priced by a
profile percentage (Default 100, Reckless 30).

PERMANENTS WAIT FOR MAIN 2 by default.
`forge/forge-ai/src/main/java/forge/ai/ability/PermanentAi.java:38`:

```java
return !ph.is(PhaseType.MAIN1) || !ph.isPlayerTurn(ai) || sa.hasParam("WithoutManaCost") || ComputerUtil.castPermanentInMain1(ai, sa);
```

and `ComputerUtil.castPermanentInMain1`
(`forge/forge-ai/src/main/java/forge/ai/ComputerUtil.java:1141-1297`) is
the list of exceptions: `SVar:PlayMain1` (`ALWAYS`, or `TRUE` when the AI
has creatures, or `OPPONENTCREATURES`) (`:1144-1155`); a zero mana cost
(`:1181`); floating mana that would be lost (`:1191-1205`); a creature
with haste or a haste-giver on the board (`:1217-1220`); equipment with a
creature to carry (`:1222`); `BuffedBy`/`AntiBuffedBy` SVar relations
(`:1237-1290`); `return false;` (`:1296`). In a 1995 pool this means every
creature, artifact and enchantment without haste is cast AFTER combat,
the Moxen and Sol Ring before it (Mox scripts carry `PlayMain1:TRUE`).
Non-permanent spells have the parallel `castSpellInMain1` (`:1299-1361`):
`PlayMain1:ALWAYS`, pump effects with creatures, `BuffedBy`, prowess,
threshold; else false — and it is consulted by fifteen ability-AIs
(`DrawAi.java:171`, `MillAi.java:54`, `TokenAi.java:114`, `LifeGainAi.java:108`,
`DigAi.java:58`, `ChangeZoneAi.java:1070`, `EffectAi.java:573`, …) which all
read "before Main 2 and not a Main-1 spell → wait".

`PermanentAi.checkApiLogic` (`PermanentAi.java:45-110`) adds the two refusals
ours calls `holds_duplicates`: a legend already in play →
`AiPlayDecision.WouldDestroyLegend` (unless `SVar:AILegendaryException`),
a World enchantment when one is already on the AI's side →
`WouldDestroyWorldEnchantment`; then X sizing (`setMaxXValue`, `xPay <= 0`
→ `CantAffordX`).

Creatures have their own timing class, `PermanentCreatureAi.java:60-130`:
`EndOfTurnLeavePlay` creatures (Ball Lightning) only on the AI's own turn
before attackers; flash creatures held for the opponent's declare-attackers
or end step when `FLASH_ENABLE_ADVANCED_LOGIC` (`doAdvancedFlashLogic`:
EOT before own turn, own declare-blockers, opponent's declare-attackers,
respond-to-stack unless a sweeper is on top, `AmbushAI`, "valuable
blocker" = more attackers than useful untapped blockers).

### 1.8 End-of-turn instants and reusable abilities

There is no "end of their turn" moment as a concept; each ability-AI
tests the phase itself. The shared helpers:

- `SpellAbilityAi.playReusable` (`SpellAbilityAi.java:479-501`): a
  reusable-cost ability (tap, no card lost) is fired at the opponent's
  `END_OF_TURN` when the next turn is the AI's; `isSorcerySpeed` and
  `AtOppEOT` (`:149`, `:160-166`) — the `AILogic$ AtOppEOT` hint (Millstone,
  Basalt Monolith's untap) gates an ability to exactly that step.
- `DrawAi.checkPhaseRestrictions` (`DrawAi.java:196-201`): an instant draw
  waits for the opponent's end step when the AI holds more than one card;
  sorcery-speed draws wait for Main 2 (`:168-172`).
- `PumpAi.checkPhaseRestrictions` (`PumpAi.java:108-113`): with an empty
  stack, outside combat, "save tricks until last moment" — only
  sorcery-speed pumps and curses are cast.
- `AnimateAi.checkPhaseRestrictions` (`AnimateAi.java:114-127`): instant
  animation only at the AI's `COMBAT_BEGIN`, or the opponent's
  declare-attackers with attackers present; never in Main 2 unless permanent.
- `ChangeZoneAi` tutors (`ChangeZoneAi.java:412-422`): before Main 2 only
  to hand or battlefield, and to hand only when the hand holds ≤1 card.
- `DiscardAi` (`DiscardAi.java:117-121`): never before Main 2.

### 1.9 Response logic — counters, and everything else

COUNTERS: `chooseCounterSpell` (`AiController.java:691-717`) scores each
playable counter with `ComputerUtil.counterSpellRestriction`
(`ComputerUtil.java:160-214`) and takes the maximum:

```java
if (hasDiscardHandCost(cost)) restrict -= ai.getCardsIn(ZoneType.Hand).size() * 20;   // Null Brooch
if (sa.isActivatedAbility()) restrict += 40;   // Abilities before Spells (card advantage)
if (tgt.getSAValidTargeting() != null) restrict += 35;
// UnlessCost (Power Sink, Mana Leak):
usableManaSources = ComputerUtilMana.getAvailableManaSources(<top-of-stack activator>, true).size();
if (amount > usableManaSources) restrict += 20 - (2 * amount); else restrict -= (10 - (2 * amount));
if (validTgts.length != 1 || !validTgts[0].equals("Card")) restrict += 10;   // narrow counters first
restrict -= 5 * tgtType.split(",").length;
```

Whether a counter is worth using at all is `CounterAi` (§3.1). The whole
response path runs BEFORE the ordinary picker, and `dealDamageChooseTgtC`
still carries the old "wait until stack is empty (prevents duplicate
kills)" guard as a commented-out `return null` (`DamageDealAi.java:326-334`).

EVERYTHING ELSE responds through the same picker with the stack non-empty:
`canPlaySa` requires `sa.isLegalAfterStack()`, and the ability-AIs read the
top of the stack — `ComputerUtilCard.canPumpAgainstRemoval`
(`ComputerUtilCard.java:1998-2030`, `ResponseToStackResolve` when
`ComputerUtil.predictThreatenedObjects` names one of the AI's creatures);
`useRemovalNow` "interrupt 4" (`:1312-1318`: kill the creature the opponent
is pumping); `AnimateAi` animating a land in response to a sacrifice
effect (`AnimateAi.java:89-111`); `FogAi` at declare-blockers; the
prevention windows via `ChooseSourceAi`. There is no general "what does the
spell on the stack do to me" reading; each class looks for its own case.

### 1.10 Ours, for the map's sake

`engine/ai/ai_player.gd:77-108` (`act`): attackers/blockers declarations
first; a prevention or regeneration window answered by `_window_action`;
with priority in one's own main step and an empty stack →
`_main_phase_action` (`:135-150`: land, then a `mistake_chance` roll, then
`_try_cast_best`, then `_try_activate`); otherwise, when
`profile.holds_instants`, `_respond_action` (`:1791-1842`: never answer
one's own spell; `_try_counter`, `_save_from_the_stack`, combat
regeneration and pumps, the defensive/offensive combat responses, upkeep
tap-instants, `_end_of_their_turn`, and finally `_cast_in_window`). Both
seats are one action per call, greedy, with no plan across calls.

The one structural difference in the map: ours has NO Main-1/Main-2
distinction. `_try_cast_best` (`ai_player.gd:217-343`) casts the best
affordable spell whenever `act` reaches a main step, and the first main
step it reaches is Main 1 — so a creature is cast before combat unless a
reserve rule holds it back. `_main2_reserve` (`:3011-3028`) exists only
inside combat, to stop firebreathing from spending the mana that Main 2's
best cast needs. §8 and proposal P1 return to this.

---

## 2. HOLDING AND RESERVING — how Forge keeps mana open

### 2.1 The mechanism: memory sets, consulted at tap time

Reservation is not a plan; it is a per-card mark. `AiCardMemory`
(`forge/forge-ai/src/main/java/forge/ai/AiCardMemory.java:45-68`) keeps
named sets per AI player, four of which are mana holds:
`HELD_MANA_SOURCES_FOR_MAIN2`, `HELD_MANA_SOURCES_FOR_DECLBLK`,
`HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK`, `HELD_MANA_SOURCES_FOR_NEXT_SPELL`.
`AiController.reserveManaSources` (`AiController.java:759-812`) fills one
of them: it asks `ComputerUtilMana.getManaSourcesToPayCost` for a concrete
set of sources that could pay the reserved spell (excluding one spell's own
payment when `exceptForThisSa` is given) and remembers those cards.

The mana payer honours the marks in `ComputerUtilMana.isManaSourceReserved`
(`forge/forge-ai/src/main/java/forge/ai/ComputerUtilMana.java:1044-1086`),
quoted whole because the clearing rules are the design:

```java
// For now, only AI players are supported
if (!ai.getController().isAI()) return false;
if (sa == null) return false;
if (AiCardMemory.isRememberedCard(ai, card, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_NEXT_SPELL)) {
    return true;
}
AiController aic = ((PlayerControllerAi)ai.getController()).getAi();
PhaseType curPhase = ai.getGame().getPhaseHandler().getPhase();
// Mana reserved for the combat trick / emergency use
if (curPhase == PhaseType.COMBAT_DECLARE_BLOCKERS || curPhase == PhaseType.CLEANUP) {
    if (ai.getGame().getPhaseHandler().isPlayerTurn(ai)) {
        AiCardMemory.clearMemorySet(ai, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_DECLBLK);
    } else {
        AiCardMemory.clearMemorySet(ai, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK);
        AiCardMemory.clearMemorySet(ai, AiCardMemory.MemorySet.CHOSEN_FOG_EFFECT);
    }
} else {
    if (AiCardMemory.isRememberedCard(ai, card, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_DECLBLK)
     || AiCardMemory.isRememberedCard(ai, card, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK)) {
        // This mana source is held elsewhere for a combat trick.
        return true;
    }
}
// Mana reserved for Main 2
int chanceToReserve = aic.getIntProperty(AiProps.RESERVE_MANA_FOR_MAIN2_CHANCE);
// TODO use Math.min(100 - AiAbilityDecision.rating(), chanceToReserve)
if (chanceToReserve == 0 || !MyRandom.percentTrue(chanceToReserve)) return false;
if (curPhase == PhaseType.MAIN2 || curPhase == PhaseType.CLEANUP) {
    AiCardMemory.clearMemorySet(ai, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_MAIN2);
} else {
    if (AiCardMemory.isRememberedCard(ai, card, AiCardMemory.MemorySet.HELD_MANA_SOURCES_FOR_MAIN2)) {
        // This mana source is held elsewhere for a Main 2 spell.
        return true;
    }
}
return false;
```

A held source is simply invisible to every later payment until the step
that the hold was for arrives, at which point the set is emptied. The
holds are "for this phase", never "for the opponent's next spell".

### 2.2 Who makes a hold, and for what

| hold | made by | for |
|---|---|---|
| `HELD_MANA_SOURCES_FOR_DECLBLK` | `ComputerUtilCard.shouldPumpCard` → `holdCombatTricks` (`ComputerUtilCard.java:1830-1860`, the call at `:1848`) | a pump instant in hand, held until the opponent has declared blockers; the attacker it is held for is remembered in `TRICK_ATTACKERS`; requires `TRY_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` and a `CHANCE_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` roll (`:1489-1496`) |
| `HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK` | `AiAttackController` (`AiAttackController.java:1225-1250`), `FogAi` (`FogAi.java:98-108`) | a Fog or a trick for the opponent's combat |
| `HELD_MANA_SOURCES_FOR_MAIN2` | `AiController.predictSpellToCastInMain2` (`AiController.java:722-757`, gated by `PREDICT_SPELLS_FOR_MAIN2`, `:723`; permanents that would not be cast in Main 1 are skipped at `:752`) called from `AttachAi.java:1376` and `EffectAi.java:172`; `AnimateAi.holdAnimatedTillMain2` (`AnimateAi.java:609-611`) | the best sorcery-speed spell the AI expects to cast after combat, so that a Main-1 aura or a pre-combat animation does not eat its mana |
| `HELD_MANA_SOURCES_FOR_NEXT_SPELL` | `DamageDealAi` (`DamageDealAi.java:272`, `reserveManaSourcesForNextSpell`) from `getDamagingSAToChain` (`:1027-1115`) | the second half of a two-burn kill: when one damage spell is cast, mana for a second one that can be paid alongside it is held for the very next decision (`CHANCE_TO_CHAIN_TWO_DAMAGE_SPELLS`; forced to 100 when `aiLifeInDanger`, `:1048-1050`) |

`ComputerUtilCard.java:1510-1520` shows an earlier "hold for Main 2"
in `shouldPumpCard` commented out — the design moved to
`predictSpellToCastInMain2`.

### 2.3 What Forge will not tap — source ordering

Which source pays is `ComputerUtilMana`'s ordering, not a reservation:
`SpellAbility.calculateScoreForManaAbility`
(`forge/forge-game/src/main/java/forge/game/spellability/SpellAbility.java:2411+`)
ranks a source's mana ability — a non-undoable ability +50, one that
sacrifices another permanent +40 — so lands are tapped before a Black
Lotus, and `SpecialCardAi.BlackLotus.consider` (`SpecialCardAi.java:125`,
called from `ComputerUtilMana.java:705`) allows the Lotus only for a
spell of mana value ≥4, ≥3 in a low-curve deck, or 3 when fewer than 3
other sources exist. `AIManaPref$` on an ability (`ComputerUtilMana.java:229,286,316`;
Basalt Monolith's `NotSameCard`) steers which source pays which pip. The
colour a generic pip takes is chosen against the deck's own pip statistics
(`AiDeckStatistics.fromCards(hand)`, `ComputerUtilMana.java:160-170`) — the
AI keeps open the colours its hand needs. `ComputerUtil.getCardPreference`
(`ComputerUtil.java:277-390`) refuses to sacrifice Black Lotus, the Moxen
and Lotus Petal to a `SacCost` (`:353`).

### 2.4 How a card asks for it

There is no SVar that says "reserve mana for me". A script reaches the
holds only through an `AILogic$` that a class understands: `ManaRitual`
(Dark Ritual: `ManaAi.java:132-250` fires the ritual only when a specific
spell in hand becomes castable this main phase — own main phases only,
`:74`; non-haste permanents skipped in Main 1), `AtOppEOT`, `Berserk`,
`PreventCombatDamage` (Maze of Ith), `NeedsPrevention` (the Circles).
Everything else is the class's own reading.

### 2.5 No counterspell reservation — three TODOs

Forge does NOT hold mana for a Counterspell. The idea exists only as
comments: `ComputerUtil.java:3167` ("holding mana for Spike Weaver or
Counterspell" as a use for `aiLifeInDanger`), `GameStateEvaluator.java:177`
(`// TODO evaluate holding mana open for counterspells`) and `ManaAi.java:96`
(`// TODO check if it would be worth it to keep mana open for opponents turn anyway`).
The Main-2 default for permanents (§1.7) keeps mana open THROUGH COMBAT as
a side effect, and the DECLBLK hold keeps it for a pump, but once Main 2
arrives every Forge profile taps out for the best permanent it can afford.
A Forge "Deck" pilot with Counterspell and a Serra in hand casts the Serra.

Ours, by contrast: `_held_reserve` (`engine/ai/ai_player.gd:420-462`)
prices the best held instant (a draw at `3.0 + _draw_need`, a removal at
`permanent_value(victim) + 1.0`, a decking draw at `LETHAL_WORTH`) and, when
`holds_instants`, prices every Counterspell in hand at
`profile.counter_threshold`; `_try_cast_best` then refuses a sorcery-speed
cast worth less than `reserve.value * 1.5` if the plan cannot pay both
(`:279-282`), and refuses any cast under 6.0 that would leave fewer than
two untapped blue sources while a counter is in hand (`:283-286`,
`_holding_counter` `:1295`, `_blue_after_plan` `:1303`). That is a real
counterspell reservation, keyed to the counter's own cost, and Forge has no
equivalent.


---

## 3. THE ABILITY AIs — rules and thresholds for a 1995 pool

Every ApiType has one class under `forge/forge-ai/src/main/java/forge/ai/ability/`
(file names below are relative to that directory). The shared gate is
`SpellAbilityAi.canPlayWithoutRestrict` (`SpellAbilityAi.java:81-124`):
`checkAiLogic` → `checkPhaseRestrictions` → `preventRunAwayActivations`
(`ComputerUtil.java:1363-1376`: never before ten activations, then
`nextFloat() >= 0.95^activations`) → `checkApiLogic` → `willPayCosts`
(`SpellAbilityAi.java:382-396`: life cost accepted only with a margin of 4,
`ComputerUtilCost.checkLifeCost(payer, cost, source, 4, sa)`). The default
`checkApiLogic` (`:174-181`) is
`if (sa.getActivationsThisTurn() == 0 || MyRandom.getRandom().nextFloat() < .8f)` —
play, with an 80 % roll on a repeat. What follows is what each class adds.

### 3.1 Burn — `DamageDealAi` and `DamageAiBase`

**Face or creature.** `damageChoosingTargets` (`DamageDealAi.java:488-760`)
takes the lowest-life targetable opponent as `enemy` (`:498-502`). When the
spell can hit both, it asks `shouldTgtP` FIRST (`:608`), and only if that
says no does it look for a creature. `shouldTgtP`
(`DamageAiBase.java:45-152`), in order:

```java
if (!sa.canTarget(enemy)) return false;
... // a DamageDone trigger aimed at the opponent → true
restDamage = ComputerUtilCombat.predictDamageTo(enemy, restDamage, hostcard, false);
if (restDamage == 0) return false;
if ((enemy.getLife() - restDamage) < 5) {
    // drop the human to less than 5 life
    return true;
}
```
(`:88-104`). Then, for spells only: at own end of turn or Main 2 with more
cards than the hand size allows → true (`:110-113`); otherwise, with more
than two cards in hand,

```java
float value = 0;
if (isSorcerySpeed) {
    if (own turn && MAIN2) value = 1.0f * restDamage / enemy.getLife();
} else if (their turn) {
    ... else if (END_OF_TURN) value = 1.5f * restDamage / enemy.getLife();
}
for (int i = 3; i < hand.size(); i++) value *= 1.1f;
if (value < 0.2f) return false;
return MyRandom.getRandom().nextFloat() < value;
```
(`:116-147`). Read: a Bolt goes to the face when it puts them under 5, and
otherwise only at THEIR end step (or own Main 2 for a sorcery), with a
probability of damage/life scaled up 10 % per card in hand beyond three,
never below 20 %. Two cards or fewer in hand → never to the face by this
path (the player fallback at `:680-705` still allows it at their EOT when
`shouldTgtP` agrees, or when the spell is already partly targeted).

**Which creature.** `dealDamageChooseTgtC` (`DamageDealAi.java:323-398`):
killables = creatures where `getEnoughDamageToKill ≤ d`, not regenerable,
without `SacMe`, without undying; creatures that will die this turn anyway
are filtered out (`filterCreaturesThatWillDieThisTurn`); the opponent's
best by `getBestRemovalTargetAI` wins (`ComputerUtilCard.java:585-614`:
creatures by `evaluateCreature`, other permanents `50 + 30*CMC`, tokens
+30, plus a quarter of `evaluateBoardPosition`). A single-target spell is
then gated by `ComputerUtilCard.useRemovalNow` (`:621-627`), §3.4.

**Burn efficiency** inside `useRemovalNow` (`ComputerUtilCard.java:1309-1322`):

```java
float valueBurn = 1.0f * c.getNetToughness() / dmg;
valueBurn *= valueBurn;
if (canTgtPlayer) valueBurn /= 2; //preserve option to burn to the face
if (valueBurn >= 0.8 && phaseType.isBefore(PhaseType.COMBAT_END)) return true;
```
A Bolt on a 3-toughness creature scores 1.0/2 = 0.5, on a 2-toughness
(2/3)²/2 = 0.22, on a 1-toughness 0.06 — so a face-capable burn spell is
rarely "efficient" and falls through to the tempo/threat roll (§3.4).

**X sizing and the hold rule** (`DamageDealAi.java:97-160`):

```java
dmg = ComputerUtilCost.setMaxXValue(sa, ai, sa.isTrigger());
int holdChance = AiProfileUtil.getIntProperty(ai, AiProps.HOLD_X_DAMAGE_SPELLS_FOR_MORE_DAMAGE_CHANCE);
if (MyRandom.percentTrue(holdChance)) {
    int threshold = AiProfileUtil.getIntProperty(ai, AiProps.HOLD_X_DAMAGE_SPELLS_THRESHOLD);
    boolean inDanger = ComputerUtil.aiLifeInDanger(ai, false, 0);
    boolean isLethal = sa.usesTargeting() && sa.getTargetRestrictions().canTgtPlayer()
            && dmg >= ai.getWeakestOpponent().getLife() && !...cantLoseForZeroOrLessLife();
    if (dmg < threshold && ai.getGame().getPhaseHandler().getTurn() / 2 < threshold
            && !inDanger && !isLethal) return CantPlayAi;
}
```
A Fireball for less than 5 (Default; Reckless 3, Cautious 6) is held while
the game is younger than turn 10 and nothing is on fire. X is otherwise
always the maximum (`setMaxXValue`, §3.14); Fireball's split is
`dmg = dmg * targets / (targets + 1)` under `DivideEvenly$ RoundedDown`
(`:616-618`).

**Chaining two burn spells** (`getDamagingSAToChain`, `DamageDealAi.java:1027-1110`;
disabled under full simulation): `chance = CHANCE_TO_CHAIN_TWO_DAMAGE_SPELLS`
(90/75/25/100), forced to 100 when `lifeInDanger`; it looks for a second
numeric-damage spell or ability in hand or on the battlefield with a pure
mana cost and the same target class, checks `canPayManaCost` for the
combined cost, and reserves the second spell's sources with
`aic.reserveManaSourcesForNextSpell(chainDmg.getKey(), sa)` (`:272`). This
is how two Bolts kill a Serra, and the only two-step plan in the
heuristic AI.

**Drain Life** (`AILogic$ XLifeDrain`, `doXLifeDrainLogic`
`DamageDealAi.java:970-1020`): X is the black mana available; refuse
`if (dmg < 3 && dmg < opponent.getLife())`; target a creature only if it
dies exactly (`toughness == dmg && toughness >= 3`) or has power ≥ 5;
otherwise the face, and always the face when lethal.

**Pestilence** (`AILogic$ DmgAllCreaturesAndPlayers`, `NeedsToPlay:Creature`)
is §3.3's `DamageAllAi` with the reusable-ability branch.

### 3.2 Counters — `CounterAi`

`checkApiLogic` (`CounterAi.java:30-224`): empty stack → `TargetingFailed`;
the top spell must be counterable and an opponent's; Power Sink / Mana
Drain-style `UnlessCost` first:

```java
tgtCMC = topSA.getPayCosts().getTotalMana().getCMC();
tgtCMC += topSA.getPayCosts().getTotalMana().countX() > 0 ? 3 : 0;   // X spells count +3
...
int usableManaSources = ComputerUtilMana.getAvailableManaEstimate(opp);
toPay = Math.min(setMaxXValue(...), usableManaSources + 1);   // for an X "unless" cost
if (toPay <= usableManaSources) {
    if (!playReusable(ai, sa)) return CantAfford;               // they could pay: only a free reusable counter tries
}
```
So a Power Sink is fired for X = (their open mana + 1) when it can, and not
at all when it cannot make them fail (a spell, not reusable). Then the
profile block:

```java
if (tgtCMC == 1 && !MyRandom.percentTrue(ctrChanceCMC1)) dontCounter = true;
else if (tgtCMC == 2 && !MyRandom.percentTrue(ctrChanceCMC2)) dontCounter = true;
else if (tgtCMC == 3 && !MyRandom.percentTrue(ctrChanceCMC3)) dontCounter = true;
if (tgtSA != null && tgtCMC < AiProfileUtil.getIntProperty(ai, AiProps.MIN_SPELL_CMC_TO_COUNTER)) {
    dontCounter = true;
    ...
    if ((tgtSource != null && tgtCMC == 0 && tgtSource.isPermanent() && !tgtSource.getManaAbilities().isEmpty() && ctrCmc0ManaPerms)
            || (tgtSA.getApi() == ApiType.DealDamage || tgtSA.getApi() == ApiType.LoseLife || tgtSA.getApi() == ApiType.DamageAll && ctrDamageSpells)
            || (tgtSA.getApi() == ApiType.Counter && ctrOtherCounters)
            || ((tgtSA.getApi() == ApiType.Pump || tgtSA.getApi() == ApiType.PumpAll) && ctrPumpSpells)
            || (tgtSA.getApi() == ApiType.Attach && ctrAuraSpells)
            || (tgtSA.getApi() == ApiType.Destroy || tgtSA.getApi() == ApiType.DestroyAll || tgtSA.getApi() == ApiType.Sacrifice
               || tgtSA.getApi() == ApiType.SacrificeAll && ctrRemovalSpells)) {
        dontCounter = false;
    }
}
// Should ALWAYS counter if it doesn't spend a card
if (sa.isAbility() && no Discard/Sacrifice/Exile cost) dontCounter = false;
return new AiAbilityDecision(100, WillPlay);
```
Default: CMC-1 spells 30 %, CMC-2 75 %, CMC-3 and up always
(`Default.ai:145-147`); Reckless 80/100/100; Cautious 0/50/100 with
`MIN_SPELL_CMC_TO_COUNTER=2`. The ALWAYS_COUNTER_* categories only run
inside the `MIN_SPELL_CMC_TO_COUNTER` branch, so for Default and Reckless
(threshold 0) they are dead code; and `&&` binds tighter than `||`, so
`DealDamage`/`LoseLife` and `Destroy`/`DestroyAll`/`Sacrifice` override the
threshold regardless of the flag. There is NO reading of what the spell
does beyond its ApiType and no reading of the AI's own hand: a
Counterspell held against a Serra is spent on a Savannah Lions 30 % of the
time, on a Hypnotic Specter 75 %, and on the first three-drop of any
kind always.

**Which counter** (`ComputerUtil.counterSpellRestriction`,
`ComputerUtil.java:160-214`) ranks the counters in hand: a hard counter
over an unless-cost one, a cheaper one over a dearer one, an ability over
a spell.

### 3.3 Sweepers — `DestroyAllAi`, `DamageAllAi`, `BalanceAi`

**Wrath / Armageddon / Disk** (`DestroyAllAi.java:1-207`). The lists
exclude indestructible, shield-countered and `SacMe` cards (`:20`);
`CREATURE_EVAL_THRESHOLD = 200 / (untargeted ? opponents : 1)` (`:57`).
At their declare-blockers, `lifeInSeriousDanger` → cast (`:103-106`);
`lifeInDanger && (evaluatePermanentList(ailist) - 6) >= evaluatePermanentList(opplist)`
→ cast (`:109-113`; `evaluatePermanentList` = Σ(CMC + 1),
`ComputerUtilCard.java:813-819`). Creatures only (Wrath, `:116-145`):

```java
if (evaluateCreatureList(ailist) + CREATURE_EVAL_THRESHOLD < evaluateCreatureList(opplist)) → WillPlay;
if (before MAIN2) → WaitForMain2;
// else: build the opponent's next-turn attack with every creature that can attack,
//       let AiBlockController assign blocks, and cast if lifeInSeriousDanger(ai, combat)
```
A Wrath is cast when their board is worth 200 creature-points (about one
good creature: a Serra evaluates near 250, a Bear near 130) more than
ours, or when their next attack would be lethal after our best blocks.
Lands only (Armageddon, `:146-163`): with a Crucible → cast; if they have
creatures and `evaluateCreatureList(ai) < evaluateCreatureList(opp) + 200`
→ no; `evaluatePermanentList(ailist) > evaluatePermanentList(opplist) + 1`
→ no (never when we would lose more land-value). Mixed (Disk, `:165-167`):
`(evaluatePermanentList(ailist) + 3) >= evaluatePermanentList(opplist)`
→ no, i.e. Disk fires when their permanents out-cost ours by more than
three mana-plus-one units. `willPayUnlessCost` (`:176-207`) refuses a
damage cost above 3 per creature saved.

**Earthquake / Hurricane / Pestilence** (`DamageAllAi.java:28-175`). For an
X spell the AI first tries `determineOppToKill` — the smallest X in 1..max
that kills an opponent without killing itself
(`aiLife <= predictDamageTo(ai)` refuses); otherwise it evaluates every X:

```java
value = evaluateCreatureList(humanKillable) - evaluateCreatureList(computerKillable) - minGain
```
with `minGain` 200 for a spell, 100 for a reusable ability with own
creatures, 10 for a reusable ability with none (the Pestilence case, where
the player-damage logic hurts the opponent only at their EOT, when the
damage would otherwise be zero, when they are under 10 life, or when
`opp.life <= 2*dmg`). It returns -1 when the X would kill the AI itself.
So an Earthquake needs their creatures to be worth 200 points more than
the ones we lose — the same bar as Wrath.

**Balance** (`BalanceAi.java:20-60`, the whole class):

```java
diff += oppLands - aiLands;
diff += 1.5 * (oppCreatures - aiCreatures);
if (diff < 0) return CantPlayAi;
diff += 0.5 * (humHand.size() - compHand.size());
boolean willPlay = diff > 2 && MyRandom.getRandom().nextInt(100) < diff * 10;
```
Land and creature counts, creatures weighted 1.5, hand 0.5; cast when
the count exceeds 2, with a probability of 10 % per point. Our
`levels_boards` (`engine/ai/ai_player.gd:1245`, `_level_value`) prices the
same three quantities on the evaluator's scale against `SWEEP_BAR`
(`:1360`), without the roll and with lands priced by `Evaluator.land_value`
rather than counted.

### 3.4 Targeted removal — `DestroyAi`, `ChangeZoneAi` (Swords, Unsummon), `useRemovalNow`

`DestroyAi.checkApiLogic` (`DestroyAi.java:107-299`): candidates are the
OPPONENTS' targetable permanents only (`:151`), never own; not
indestructible; for a one-shot spell (`!playReusable`) creatures with a
regeneration shield or a regeneration ability are dropped unless the
spell says `NoRegen` (`:188-191`); `filterCreaturesThatWillDieThisTurn`;
creatures by `getBestRemovalTargetAI`, lands by `getBestLandToRemoveAI`
plus the Strip Mine logic; then the gate:

```java
if (!sa.isTrigger() && sa.getMaxTargets() == 1) {
    if (choice == null || !ComputerUtilCard.useRemovalNow(sa, choice, 0, ZoneType.Graveyard)) return TargetingFailed;
}
```
(`:241-245`). Swords/Unsummon go through `ChangeZoneAi.isPreferredTarget`
(`ChangeZoneAi.java:869-1253`), which adds: on own turn before Main 2 with
no creatures of its own, no removal (`:1105-1109`); in combat only
attackers/blockers (`:1131-1136`); at their declare-blockers, remove the
blocker that would kill our attacker (`:961-999`); and the same
`useRemovalNow` gate (`:1186-1189`).

**`useRemovalNow`** (`ComputerUtilCard.java:1226-1442`) is the timing rule
for every single-target removal spell. Abilities → always (`:1236`). Own
Main 1 with `castSpellInMain1` → now. Four interrupts → now: removing a
blocker lets more attackers through in own Main 1 (`:1246-1259`); at their
declare-blockers the target blocks and kills our attacker (`:1262-1283`);
the target wears one of THEIR auras — "card advantage over tempo"
(`:1286-1297`); their pump spell on the stack targets it (`:1300-1306`).
Then burn efficiency (§3.1), then tempo:

```java
float valueTempo = Math.max(0.1f * costTarget / costRemoval, valueBurn);
// ×2 equipped, ×2 sorcery-speed removal, ×2 cannot otherwise be destroyed, /2 bounce of a non-token,
// land: += 0.5f / opp.getLandsInPlay().size()
if (!ph.isPlayerTurn(ai) && ph.getPhase().equals(PhaseType.END_OF_TURN)) valueTempo *= 2;
if (valueTempo >= 0.8 && phaseType.isBefore(PhaseType.COMBAT_END)) return true;
```
(`:1325-1351`), then threat (`:1357-1371`):

```java
threat += (-1 + 1.0f * evaluateCreature(c) / 100) / costRemoval;
if (canAttackNextTurn) threat += 1.0f * damageIfUnblocked / ai.getLife();
// ×0.1 on own turn after declare blockers, ×0.1 on their turn outside combat
```
artifacts/enchantments with an intrinsic static or trigger, or an
`AILogic$ Curse` aura, are threat 1.0 when
`ACTIVELY_DESTROY_ARTS_AND_NONAURA_ENCHS` (true everywhere; `:1374-1409`);
finally `valueNow = max(valueTempo, threat); if (valueNow < 0.2) return false; return chance < valueNow;`
(`:1436-1441`). Read: a Swords on a Serra (eval ≈ 250, cost 1) is
threat 1.5 → always; on a Bear (≈ 130) it is 0.3 → a 30 % roll each
priority pass, doubled at their end step. Disenchant on a Moat, a Vise or
a Howling Mine is threat 1.0 → always.

**Strip Mine** (`doLandForLandRemovalLogic`, `DestroyAi.java:428-496`):
`canManaLock = oppLandsOTB <= 3 && oppSkippedLandDrop`; `canColorLock`
when the target is their only basic of that type; priority ≥ 50 medium,
≥ 150 high (`AILandRemovalMinScore` on Maze of Ith = 170, so a Maze is
always high); the tempo check refuses to sacrifice a mana land with three
or fewer lands unless locking or high priority (`:479-483`); the profile
knobs `STRIPMINE_*` (`Default.ai`: min lands in hand 1, no-timing-check
9999, no-tempo-check at 6 lands, mana-lock attempt up to 3 lands).

### 3.5 Discard — `DiscardAi`

`DiscardAi.java:25-160`: refuse when no opponent has a hand; X (Mind Twist):

```java
cardsToDiscard = Math.min(setMaxXValue(...), weakestOpponent.hand.size());
if (cardsToDiscard < 1) return CantPlayAi;
setXManaCostPaid(cardsToDiscard);
```
— X is the smaller of the mana and the hand, never more. Then
`// Don't use discard abilities before main 2 if possible` — before Main 2
without `ActivationPhases` or an `AnyPhase` logic → `CantPlayAi`, so a
Disrupting Scepter ticks in Main 2 (after the attack, when the mana is
known to be spare) and a Mind Twist lands in Main 2 too; `waitForBlocking`
holds a tap-ability creature until blocks. The Rack and Black Vise choose
their player with `AILogic$ MostCardsInHand`.

### 3.6 Draw — `DrawAi`

Timing (`DrawAi.java:160-201`): sorcery-speed draws wait for Main 2 unless
`castSpellInMain1` (`:160-171`); an instant draw on their turn waits for
their END step while the AI has more than one card in hand:

```java
if ((!ph.getNextTurn().equals(ai) || ph.getPhase().isBefore(PhaseType.END_OF_TURN))
        && !sa.hasParam("PlayerTurn") && !isSorcerySpeed && ai.getCardsIn(ZoneType.Hand).size() > 1
        && !ComputerUtil.activateForCost(sa, ai)) return false;
```
(`:181-201`) — Ancestral Recall and a Tome tick both fire at the
opponent's end step. Sizing (`targetAI`, `:253-562`): for an X draw
(Braingeyser):

```java
numCards = setMaxXValue(...);
int safeDraw = Math.abs(Math.min(computerMaxHandSize - computerHandSize, computerLibrarySize - 3));
if (instant || sorcery) safeDraw++;
numCards = Math.min(numCards, safeDraw);
```
opponents are targeted when `numCards >= their library size` (the deck-out
kill); own library: `if (numCards >= computerLibrarySize - 3)` → for an X
spell draw `library - 1`, else refuse; a life-per-card cost is capped at
`life - 5`; on own turn, drawing past the hand size is refused for a
non-X spell and trimmed for an X one. Untargeted (Tome, Howling Mine,
`:500-560`): `numCards >= library - 3` → "Don't deck yourself";
`hand + numCards > maxHand` on own turn → no; `hand > maxHand` → no.
Our `counts_cards` and `paces_draws` (`engine/ai/ai_player.gd:1368-1466`,
`_hand_room` `:960`, `_library_slack` `:992`, `_decking_draw` `:1012`) do
the same sums, with one difference in our favour: ours refuses a draw that
would hand the OPPONENT the library race (Forge only protects its own last
three cards). The end-step timing is matched: with `holds_instants`,
`_is_held_instant` (`:1674-1690`) keeps an instant draw, a non-self pump
or a creature-removal instant out of `_try_cast_best` unless it is lethal
burn, and `_fire_held_instant` (`:1719`) spends it at their end step or in
their combat.

### 3.7 Pump — `PumpAi` and `shouldPumpCard`

`PumpAi.checkPhaseRestrictions` (`PumpAi.java:91-116`): with an empty
stack, a pump before combat or after blockers is refused unless it is a
curse, sorcery-speed or `Main1IfAble` — `// save tricks until last moment`.
`pumpTgtAI` (`:355-375`) refuses a non-immediate pump after declare
blockers unless it grants a non-combat keyword. `shouldPumpCard`
(`ComputerUtilCard.java:1474-1862`), the trick logic, at
COMBAT_DECLARE_BLOCKERS (`:1645-1805`): 1. save a combatant
(`combatantWouldBeDestroyed(ai, c, combat) && !pumpedWillDie`) → yes;
2. kill the creature it fights → yes; 3. buff an attacker: lethal
(`pumpedDmg >= opp.getLife()`) or total unblocked ≥ life → yes, a free
ability that adds unblocked damage → yes, else
`chance += (pumpedDmg − dmg) × power / CMC` (self-pump) or `/ opp.life`;
4. lifelink; 5. a blocker against a trampler when in danger. Before
blocks, with `TRY_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` (true; Cautious
false) and a `CHANCE_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK` roll (65/65/75/75),
a pure instant pump is HELD: `reserveManaSources(sa, PhaseType.COMBAT_DECLARE_BLOCKERS, false)`
(`:1848`) and the creature is remembered in `TRICK_ATTACKERS` so the
attack code sends it in to provoke a block. The end is a roll:
`return simAI || MyRandom.getRandom().nextFloat() < chance;` (`:1861`).
Berserk needs `USE_BERSERK_AGGRESSIVELY` (true; Cautious false) and
`AILogic$ Berserk`. `canPumpAgainstRemoval` (`:1998-2031`): a pump whose
target is in `predictThreatenedObjects` of the top of the stack →
`ResponseToStackResolve` (Giant Growth in response to a Bolt). Firebreathing
(`pump_self`, X) is sized by `setMaxXValue` inside the same combat test.

Ours: `_combat_self_pumps` (`engine/ai/ai_player.gd:2389`),
`_defensive_combat_response` (`:2808`), `_offensive_combat_response`
(`:2909`), `_save_from_the_stack` (`:2322`), `_pumps_are_lethal` (`:3032`)
— the same five cases, decided from the combat model rather than rolled;
what ours lacks is Forge's PRE-combat hold (`_main2_reserve` `:3011` is
consulted only for firebreathing during combat) and the "attack to
provoke a block" memory.

### 3.8 Animate — `AnimateAi` (Mishra's Factory)

`checkPhaseRestrictions` (`AnimateAi.java:86-143`): an instant-speed
animate on own turn only at COMBAT_BEGIN; on their turn only at
DECLARE_ATTACKERS when they have attackers; never in Main 2 unless it is
permanent; and never as an attacker when
`ai.getLife() < 6 && opponent.getLife() > 6 && opponent has creatures`.
`checkApiLogic` (`:145-230`): a Sacrifice effect on the stack → animate
the worst thing to feed it (`ResponseToStackResolve`, once per turn);
for the self-animating shape (Factory) the body must be untapped, not
summoning-sick (or hasty, or it is their turn), and then

```java
animatedCopy = becomeAnimated(c, sa);
if (own turn && !doesSpecifiedCreatureAttackAI(ai, animatedCopy)) return DoesntImpactCombat;
if (their turn && !doesSpecifiedCreatureBlock(ai, animatedCopy)) return DoesntImpactCombat;
```
— the Factory becomes a creature only when the attack or block code says
the 2/2 would actually attack or block. `ANIMATED_THIS_TURN` (`:601-607`)
stops a second activation; `holdAnimatedTillMain2` (`:609-615`) parks the
Factory's own mana in `HELD_MANA_SOURCES_FOR_MAIN2` so it is not tapped for
a spell after it has attacked. Ours: `_animation_value` (`:914`),
`_animation_payable` (`:856`) price the body's combat contribution the
same way, in `_try_activate`.

### 3.9 Tutors, Regrowth, bounce — `ChangeZoneAi`

Timing for a tutor to hand (`hiddenOriginCanPlayAI`, `ChangeZoneAi.java:412-423`):

```java
// don't use fetching to top of library/graveyard before main2
if (!destination.equals("Battlefield") && !destination.equals("Hand")) return CantPlayAi;
// Only tutor something in main1 if hand is almost empty
if (hand.size() > 1 && destination.equals("Hand") && !AnyMainPhase) return CantPlayAi;
```
Regrowth (`checkPhaseRestrictions` `:800-811`): never before Main 1; before
Main 2 only with one card in hand; never at hand size on own turn. What a
tutor fetches (`chooseCardToHiddenOriginChangeZone`, `:1504-1676`): the
deck's KEY CARDS first — `keyCards = player.getRegisteredPlayer().getDeck().getKeyCards()`
minus names already in hand or play (`:1508-1527`); then, for a
Demonic Tutor: `if (no land in hand && lands on battlefield < 4 && nothing castable in hand) → basicManaFixing`
(`:1641-1645`); all lands → best land; creatures preferred
(`chooseCreature`, `:630-656`: in danger → best castable now; turn ≤ 3 →
best with `CMC <= manaSources + 1`; else best); none → at life ≤ 5 the
dearest castable spell, else `getBestAI`. Regrowth's pick is the same
`chooseCreature`-then-best on the graveyard (`:1195-1218`). Bounce
(`canBouncePermanent`, `:1263-1367`): own threatened permanent first (an
Unsummon on our own Bolted creature), then their best non-land.
`considerRamp` (`:2104-2140`) chooses a land over a spell below four mana
sources.

### 3.10 Permanents — `PermanentAi`, `PermanentCreatureAi`

`PermanentAi.checkPhaseRestrictions` (`PermanentAi.java:38`):
`return !ph.is(PhaseType.MAIN1) || !ph.isPlayerTurn(ai) || sa.hasParam("WithoutManaCost") || ComputerUtil.castPermanentInMain1(ai, sa);`
— Main 2 by default (§1.7). Legend already in play → `WouldDestroyLegend`
(`:50-69`); own world enchantment already in play →
`WouldDestroyWorldEnchantment` (`:71-76`) — our `holds_duplicates`
(`_arrival_wasted`, `engine/ai/ai_player.gd:381`). X permanents take the
maximum X (`:78-95`). An upkeep that costs life refuses when
`ai.getLife() <= upkeepLifeLoss || aiLifeInDanger(ai, true, upkeepLifeLoss)`
(`:221-224`; Juzám Djinn at 2 life stays in hand); an upkeep with a
sacrifice-unless cost must be payable now (`:178-224`). `AICastPreference`
(`:227-321`) reads `MaxControlled$N`, `NumManaSources$N`,
`NeverCastIfLifeBelow$N` and friends from the script. Creatures whose
static toughness would be ≤ 0 are refused (`PermanentCreatureAi.java:204-215`;
Plague Rats alone is fine). Flash creatures follow `doAdvancedFlashLogic`
(`:89-178`): ambush at their declare-attackers, otherwise at the end step
before own turn.

### 3.11 Auras and steal — `AttachAi`

`checkApiLogic` (`AttachAi.java:47-88`): a second copy of a legendary aura
is refused; the target comes from `attachGeneralAI` (`:1419-1479`) by
`AttachAILogic`: `GainControl` (Control Magic) → `getBestAI` of their
permanents, then `acceptableChoice` (`:212-226`): a creature evaluated
under 130 is NOT worth a Control Magic (a Bear is about 130, so Control
Magic waits for something better); `Reanimate` (Animate Dead) → the best
creature in either graveyard that could legally be enchanted after the
statics apply (`:538-598`); `Pump` (Holy Strength, Lure) → own creature
(`:1047-1284`): safe from the stack, not already enchanted ("card
disadvantage"), able to attack next turn with power > 0, best by
`getBestAI`, or the WORST permanent when the aura only grants an ability
(`:1254-1256`); `Curse` (Paralyze, Weakness) → their creature by the
curse-preference logic. Nothing here is the Main-1/Main-2 rule; an aura is
a permanent and follows §3.10 (Main 2 unless `castPermanentInMain1`).
Ours: `fits_auras` (`EffectIntent.aura_fits`, `engine/ai/effect_intent.gd:566`)
and `AURA_HOSTILE` (`:438`) decide the same side-of-table and host questions.

### 3.12 Tap — `TapAi` (Icy Manipulator)

`TapAi.java:25-44`: on their turn only before DECLARE_ATTACKERS; on own
turn a sorcery-speed tap before COMBAT_BEGIN, before DECLARE_BLOCKERS only
with `PLAY_AGGRO`; otherwise `playReusable` (their end step). Target
(`TapAiBase.tapPrefTargeting`, `TapAiBase.java:101-204`): own turn → the
best potential blocker of our attackers; their turn → the best creature
that can attack us, else the most expensive permanent. Ours: `_size_tap`
(`:1578`), `_best_tap_victim` (`:1153`), `_fire_tap_instant` (`:1624`) with
`TAP_CARD_BAR` (`:1558`) — the same two moments (their upkeep for a land
or attacker, our precombat for a blocker).

### 3.13 Mana, Time Walk, Fog, life, Millstone, regeneration

- **Dark Ritual / Black Lotus** (`ManaAi.doManaRitualLogic`, `ManaAi.java:131-250`):
  `searchCMC = numManaSrcs - selfCost + manaReceived`; the ritual fires only
  when some spell in hand becomes castable (colour-checked, not a permanent
  without haste before Main 2, not an instant); a plain mana ability
  (Sol Ring, Mana Vault) is never "cast" as a spell, only tapped in
  payment (`:91-107`). Ours: `_mana_spell_enables` (`:1694`), value ≥ 3.
- **Time Walk** (`AddTurnAi.java:49-87`): untargeted, numeric `NumTurns` →
  `WillPlay`, no phase rule — cast whenever castable.
- **Fog** (`FogAi.java:30-136`): only at their COMBAT_DECLARE_BLOCKERS with
  a non-empty combat; `dmg = life - lifeThatWouldRemain`; cast if
  `fogs > 2 && dmg > 2` (many Fogs → spend one), else only
  `lifeInDanger(ai, combat)`; when `aiLifeInDanger` is seen on own turn the
  Fog's mana is reserved for DECLARE_BLOCKERS (`CHOSEN_FOG_EFFECT`,
  `:104-112`). Ours: `_worth_stopping_attacks` (`:2041`), `chump_threshold`.
- **Life gain** (`LifeGainAi.java:28-177`): `lifeCritical = life <= 5 || lifeInDanger`;
  not critical → wait for Main 2 / their end step; then
  `value = 0.9f * lifeAmount / life; if (value < 0.2f) no; play if nextFloat() < value`.
- **Millstone** (`MillAi.java:36-157`, `AILogic$ AtOppEOT`): their end step;
  pick the opponent whose library the mill empties, else the largest.
- **Regeneration** (`RegenerateAi.java:51-117`): with a stack, a creature
  in `predictThreatenedObjects` without a shield; at declare-blockers, the
  best creature that `combatantWouldBeDestroyed`. Ours: `_shield` (`:2645`),
  `_combat_regeneration` (`:2483`), and the 1997 regeneration window.
- **Circle of Protection** (`ChooseSourceAi`, `AILogic$ NeedsPrevention`):
  activated only for a source that is about to deal damage to the AI (a
  stack spell or an unblocked attacker). Ours: `_prevention_action` (`:4479`).

### 3.14 X in general — `ComputerUtilCost.setMaxXValue`

`ComputerUtilCost.java:671-732`: requires `Count$xPaid`;
`val = ComputerUtilMana.determineLeftoverMana(root, ai, effect)` (every
untapped source after the fixed part), capped by `AIXMax`, by the number
of legal targets when `MinTargets` is X, by `getMaxForNonManaX`, and by
sacrificeable cards for a sacrifice-X; `root.setXManaCostPaid(x)`. No
class sizes X below the maximum except DrawAi (§3.6), DiscardAi (§3.5),
DamageAllAi (§3.3) and `determineOppToKill` — Fireball is always for
everything, and the only thing that stops a 4-point Fireball at a Bear is
the hold rule of §3.1. Ours sizes X to the victim (`_size_x_burn`,
`engine/ai/ai_player.gd:1493-1513`: lethal → `max(life − damage, 1)`;
a victim worth ≥ 3 → `clamp(toughness − damage − base, 1, max_x)`; face
at `max_x` only when `them.life <= damage_at(max_x) * 2`), which is the
stronger rule for a pool where the burn spell is often the last card.

---

## 4. PROFILES AND MEMORY

### 4.1 The four profiles

`forge/forge-gui/res/ai/{Default,Reckless,Cautious,Experimental}.ai` are
flat `KEY=value` files read by `AiProfileUtil` into the `AiProps` enum
(`forge/forge-ai/src/main/java/forge/ai/AiProps.java`); a lobby picks one
per AI player (or "Random"). The comments in `Default.ai` are the only
documentation. Below, every key that matters for a 1995 pool, with the
four values in the order Default | Reckless | Cautious | Experimental.
Keys tied to post-1995 mechanics (planeswalkers, energy, storm, explore,
surveil, scry, blink, embalm, Momir, planar) are omitted.

**Casting and holding**

| key | D | R | C | E | read by |
|---|---|---|---|---|---|
| MULLIGAN_THRESHOLD | 4 | 3 | 4 | 4 | `ComputerUtil.scoreHand` (§5) |
| PLAY_AGGRO | false | true | false | false | attack logic; `TapAi` (own DECLARE_BLOCKERS) |
| RESERVE_MANA_FOR_MAIN2_CHANCE | 100 | 100 | 100 | 100 | `AiController.reserveManaSourcesForMain2` (§2) |
| PREDICT_SPELLS_FOR_MAIN2 | true | true | true | true | `AiController.predictSpellToCastInMain2` (§2.2) |
| HOLD_LAND_DROP_FOR_MAIN2_IF_UNUSED | 100 | 30 | 100 | 100 | `AiController.chooseBestLandToPlay` (§1.7) |
| HOLD_LAND_DROP_ONLY_IF_HAVE_OTHER_PERMS | true | true | true | true | same |
| HOLD_X_DAMAGE_SPELLS_FOR_MORE_DAMAGE_CHANCE | 100 | 85 | 100 | 100 | `DamageDealAi.canPlayAI` (§3.1) |
| HOLD_X_DAMAGE_SPELLS_THRESHOLD | 5 | 3 | 6 | 5 | same |
| CHANCE_TO_CHAIN_TWO_DAMAGE_SPELLS | 90 | 75 | 25 | 100 | `DamageDealAi.getDamagingSAToChain` (§3.1) |
| TRY_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK | true | true | false | true | `ComputerUtilCard.shouldPumpCard` (§3.7) |
| CHANCE_TO_HOLD_COMBAT_TRICKS_UNTIL_BLOCK | 65 | 65 | 75 | 75 | same |
| TRY_TO_PRESERVE_BUYBACK_SPELLS | true | false | true | true | post-1995 (buyback), irrelevant |
| USE_BERSERK_AGGRESSIVELY | true | true | false | true | `PumpAi` Berserk logic |
| TOKEN_GENERATION_ABILITY_CHANCE | 80 | 80 | 80 | 100 | `TokenAi` |
| TOKEN_GENERATION_ALWAYS_IF_OPP_ATTACKS | true | true | true | true | `TokenAi` |
| CHEAT_WITH_MANA_ON_SHUFFLE | true | true | true | true | `AiController.cheatShuffle` (§4.4) |

**Counters**

| key | D | R | C | E |
|---|---|---|---|---|
| MIN_SPELL_CMC_TO_COUNTER | 0 | 0 | 2 | 2 |
| CHANCE_TO_COUNTER_CMC_1 | 30 | 80 | 0 | 30 |
| CHANCE_TO_COUNTER_CMC_2 | 75 | 100 | 50 | 75 |
| CHANCE_TO_COUNTER_CMC_3 | 100 | 100 | 100 | 100 |
| ALWAYS_COUNTER_OTHER_COUNTERSPELLS | true | true | true | true |
| ALWAYS_COUNTER_DAMAGE_SPELLS | true | true | true | true |
| ALWAYS_COUNTER_CMC_0_MANA_MAKING_PERMS | true | true | true | true |
| ALWAYS_COUNTER_REMOVAL_SPELLS | true | true | true | true |
| ALWAYS_COUNTER_PUMP_SPELLS | true | true | false | true |
| ALWAYS_COUNTER_AURAS | true | true | true | true |
| ALWAYS_COUNTER_SPELLS_FROM_NAMED_CARDS | None | None | None | None |
| ALWAYS_COPY_SPELL_IF_CMC_DIFF | 2 | 1 | 4 | 2 |
| CHANCE_TO_COPY_OWN_SPELL_WHILE_ON_STACK | 30 | 50 | 0 | 30 |
| DONT_EVAL_KILLSPELLS_ON_STACK_WITH_PERMISSION | true | true | true | false |

(`ALWAYS_COUNTER_*` are live only when `MIN_SPELL_CMC_TO_COUNTER > 0`,
i.e. for Cautious and Experimental; see §3.2 for the precedence bug.
`DONT_EVAL_KILLSPELLS_ON_STACK_WITH_PERMISSION`, read at
`ComputerUtil.java:1998-2008` in `predictCreatureWillDieThisTurn`: when a
Counter is anywhere on the stack, a creature targeted by a kill spell
below it is NOT predicted dead — the flag stands in for the AI's inability
to evaluate a spell under a counter, as its TODO says.)

**Removal and tempo**

| key | D | R | C | E |
|---|---|---|---|---|
| ACTIVELY_DESTROY_ARTS_AND_NONAURA_ENCHS | true | true | true | true |
| ACTIVELY_DESTROY_IMMEDIATELY_UNBLOCKABLE | true | false | false | true |
| DESTROY_IMMEDIATELY_UNBLOCKABLE_THRESHOLD | 2 | 2 | 2 | 3 |
| DESTROY_IMMEDIATELY_UNBLOCKABLE_ONLY_IN_DNGR | true | true | true | false |
| DESTROY_IMMEDIATELY_UNBLOCKABLE_LIFE_IN_DNGR | 5 | 5 | 5 | 5 |
| ACTIVELY_PROTECT_VS_CURSE_AURAS | true | false | true | true |
| AVOID_TARGETING_CREATS_THAT_WILL_DIE | true | true | true | true |
| STRIPMINE_MIN_LANDS_IN_HAND_TO_ACTIVATE | 1 | 1 | 1 | 1 |
| STRIPMINE_MIN_LANDS_FOR_NO_TIMING_CHECK | 9999 | 3 | 9999 | 9999 |
| STRIPMINE_MIN_LANDS_OTB_FOR_NO_TEMPO_CHECK | 6 | 4 | 8 | 6 |
| STRIPMINE_MAX_LANDS_TO_ATTEMPT_MANALOCKING | 3 | 4 | 3 | 3 |
| STRIPMINE_HIGH_PRIORITY_ON_SKIPPED_LANDDROP | true | true | true | true |
| SACRIFICE_DEFAULT_PREF_ENABLE | false | false | false | true |
| SACRIFICE_DEFAULT_PREF_MIN_CMC / MAX_CMC | 0 / 2 | 0 / 3 | 0 / 1 | 0 / 1 |
| SACRIFICE_DEFAULT_PREF_MAX_CREATURE_EVAL | 135 | 135 | 135 | 135 |
| SACRIFICE_DEFAULT_PREF_ALLOW_TOKENS | true | true | true | true |
| SAC_TO_REATTACH_TARGET_EVAL_THRESHOLD | 400 | 300 | 500 | 350 |

**Danger and combat trades** (the attack/block side reads them; they also
gate the sweeper and Fog decisions of §3 through `aiLifeInDanger`)

| key | D | R | C | E |
|---|---|---|---|---|
| AI_IN_DANGER_THRESHOLD | 4 | 4 | 4 | 3 |
| AI_IN_DANGER_MAX_THRESHOLD | 4 | 4 | 6 | 12 |
| ENABLE_RANDOM_FAVORABLE_TRADES_ON_BLOCK | true | true | true | true |
| MIN/MAX_CHANCE_TO_RANDOMLY_TRADE_ON_BLOCK | 30/70 | 0/50 | 40/65 | 30/70 |
| RANDOMLY_TRADE_EVEN_WHEN_HAVE_LESS_CREATS | false | false | false | false |
| MAX_DIFF_IN_CREATURE_COUNT_TO_TRADE | 1 | 0 | 0 | 1 |
| ALSO_TRADE_WHEN_HAVE_A_REPLACEMENT_CREAT | true | true | false | true |
| MAX_DIFF_IN_CREATURE_COUNT_TO_TRADE_WITH_REPL | 1 | 1 | 0 | 1 |
| ATTACK_INTO_TRADE_WHEN_TAPPED_OUT | false | true | false | false |
| CHANCE_TO_ATTACK_INTO_TRADE | 0 | 100 | 0 | 0 |
| CHANCE_TO_ATKTRADE_WHEN_OPP_HAS_MANA | 30 | 100 | 0 | 30 |
| RANDOMLY_ATKTRADE_ONLY_ON_LOWER_LIFE_PRESSURE | true | false | true | true |
| TRY_TO_AVOID_ATTACKING_INTO_CERTAIN_BLOCK | true | true | false | true |
| COMBAT_ASSAULT_ATTACK_EVASION_PREDICTION | true | true | true | true |
| COMBAT_ATTRITION_ATTACK_EVASION_PREDICTION | true | true | true | true |

**Flash (post-1995 in name, but the 1995 pool has no flash creatures, so
these only reach the aura path)**: FLASH_ENABLE_ADVANCED_LOGIC true×4;
FLASH_CHANCE_TO_OBEY_AMBUSHAI / CAST_DUE_TO_ETB_EFFECTS /
CAST_AS_VALUABLE_BLOCKER / PROC_ETB_EFFECTS_WITH_SAC_COST 100×4;
FLASH_CHANCE_TO_CAST_FOR_ETB_BEFORE_MAIN1 10|30|0|20;
FLASH_CHANCE_TO_RESPOND_TO_STACK_WITH_ETB 0|10|0|15;
FLASH_BUFF_AURA_CHANCE_TO_CAST_EARLY 1|3|0|0;
FLASH_BUFF_AURA_CHANCE_CAST_AT_EOT 5|10|5|10;
FLASH_BUFF_AURA_CHANCE_TO_RESPOND_TO_STACK 0×4.

**Equipment and sideboarding** (no equipment in the pool; sideboarding is
`SIDEBOARDING_CHANCE_PER_CARD` 50|65|50|50, `SIDEBOARDING_CHANCE_ON_WIN`
0|0|0|25, `SIDEBOARDING_SHARED_TYPE_ONLY` false|false|true|true,
`SIDEBOARDING_IN_LIMITED_FORMATS` false×4 — a per-card coin flip on the
whole sideboard between games, not a matchup read; ours is
`sideboard_swaps` with the Deck Lab's `--sideboard`).

What the table says about the profiles: Reckless is Default with the
counter-chances and trade-chances turned up and the holds turned down
(land drop 30 %, X-burn threshold 3, chain 75 %); Cautious is Default with
the CMC-1 counter off, tricks not held, no attack-trades and a Strip Mine
that waits for eight lands; Experimental differs mainly in
`AI_IN_DANGER_MAX_THRESHOLD=12` (the danger margin is rolled between 3 and
12 each check) and the counter-category branch being live. None of the
four is a "control" profile: no key changes what is countered by what it
does, none changes Main-1/Main-2 timing, none changes how much mana is
held for instants. The only profile-driven "play style" knobs in the
casting path are the holds (X burn, tricks, land drop) and the counter
chances.

### 4.2 `AiProps` defaults

`AiProps.java` gives each key a string default used when a file omits it
(`CHEAT_WITH_MANA_ON_SHUFFLE("false")`, `MULLIGAN_THRESHOLD("4")` …); the
enum has no per-key documentation — every meaning is inferred from its
single reader, listed in the table above.

### 4.3 `AiCardMemory` — a per-turn scratch pad

`forge/forge-ai/src/main/java/forge/ai/AiCardMemory.java:53-68` defines the
sets:

```java
public enum MemorySet {
    MANDATORY_ATTACKERS, TRICK_ATTACKERS,
    HELD_MANA_SOURCES_FOR_MAIN2, HELD_MANA_SOURCES_FOR_DECLBLK,
    HELD_MANA_SOURCES_FOR_ENEMY_DECLBLK, HELD_MANA_SOURCES_FOR_NEXT_SPELL,
    ATTACHED_THIS_TURN, ANIMATED_THIS_TURN, BOUNCED_THIS_TURN, ACTIVATED_THIS_TURN,
    CHOSEN_FOG_EFFECT, MARKED_TO_AVOID_REENTERING_ATTACK, PAYS_TAP_COST, PAYS_SAC_COST,
    ... REVEALED_CARDS
}
public enum MemorySetMana { UNPAID_COSTS }
```
Every one of them is cleared at the end of every turn:
`PlayerControllerAi.resetAtEndOfTurn` (`PlayerControllerAi.java:1557-1560`)
calls `getAi().getCardMemory().clearAllRemembered()` with the comment
`// TODO - if card memory is ever used to remember something for longer than a turn, this needs to be changed`.
So Forge's "memory" is bookkeeping for the current turn: which sources are
held, which creature already animated, which Fog is planned. It remembers
nothing across turns — not what the opponent cast, not what colours they
showed, not that they held two cards through their own end step. The only
card-observation set, `REVEALED_CARDS`, is read by
`ComputerUtil.hasAFogEffect` (`ComputerUtil.java:1500-1530`) — and there
the attack side passes `true` for "check only revealed" while the blocking
side passes the AI's OWN hand; the opponent's revealed cards are only
those the game itself revealed (a Sylvan Library flip, a countered card
returned), and even those are forgotten at end of turn.

Ours: `AiMatchMemory` (`engine/ai/ai_match_memory.gd`) records, per duel,
the maximum copies of each name the opponent has cast or played and the
damage dealt by colour, persists across the games of a match, and is
governed by the fairness rule at its head — it never reads the opponent's
decklist. There is nothing to take from Forge here; ours is the stronger
design, and §9 builds on it.

### 4.4 The two places Forge cheats

`AiController.cheatShuffle` (`AiController.java:2114-2135`,
`// this is where the computer cheats`): when the profile has
`CHEAT_WITH_MANA_ON_SHUFFLE` (true in all four files) AND the match rules
allow it (`rules.isAllowCheatShuffle()`, off unless the user turns it on),
the AI's library is re-ordered after a shuffle so that lands come up on
schedule. And the simulation AI copies the game with
`GameCopier.PRUNE_HIDDEN_INFO = false` (§6), so a simulating AI plans
against the opponent's actual hand and library. Neither belongs in our
engine (§10); we have the fairness rule in `AiMatchMemory`, and the Deck
Lab measures both sides with the same information.

---

## 5. THE MULLIGAN

### 5.1 Forge — `ComputerUtil.scoreHand` / `wantMulligan`

`forge/forge-ai/src/main/java/forge/ai/ComputerUtil.java:2069-2149`:

```java
public static int scoreHand(CardCollectionView handList, Player ai, int cardsToReturn) {
    final AiController aic = ((PlayerControllerAi)ai.getController()).getAi();
    int currentHandSize = handList.size();
    int finalHandSize = currentHandSize - cardsToReturn;
    // don't mulligan when already too low
    if (finalHandSize < aic.getIntProperty(AiProps.MULLIGAN_THRESHOLD)) return finalHandSize;
    CardCollectionView library = ai.getCardsIn(ZoneType.Library);
    int landsInDeck = CardLists.count(library, CardPredicates.LANDS);
    // no land deck, can't do anything better
    if (landsInDeck == 0) return finalHandSize;
    final CardCollectionView lands = CardLists.filter(handList, c -> c.getManaCost().getCMC() <= 0
            && !c.hasSVar("NeedsToPlay") && (c.isLand() || c.isArtifact()));
    final int handSize = handList.size();
    final int landSize = lands.size();
    int score = handList.size();
    ... // Living End special case
    if (handSize/2 == landSize || handSize/2 == landSize +1) score += 10;
    final CardCollectionView castables = CardLists.filter(handList,
            c -> c.getManaCost().getCMC() <= 0 || c.getManaCost().getCMC() <= landSize);
    score += castables.size() * 2;
    // if at mulligan threshold, and we have any lands accept the hand
    if (handSize == aic.getIntProperty(AiProps.MULLIGAN_THRESHOLD) && landSize > 0) return score;
    // otherwise, reject bad hands or return score
    if (landSize < 2) {
        // BAD Hands, 0 or 1 lands
        if (landsInDeck == 0 || library.size()/landsInDeck > 6) return handSize;   // Heavy spell deck it's ok
        return 0;
    } else if (landSize == handSize) {
        if (library.size()/landsInDeck < 2) return handSize;                       // Heavy land deck/Momir Basic it's ok
        return 0;
    } else if (handSize >= 7 && landSize >= handSize-1) {
        // BAD Hands - Mana flooding
        if (library.size()/landsInDeck < 2) return handSize;
        return 0;
    }
    return score;
}
// Computer mulligans if there are no cards with converted mana cost of 0 in its hand
public static boolean wantMulligan(Player ai, int cardsToReturn) {
    final CardCollectionView handList = ai.getCardsIn(ZoneType.Hand);
    return !handList.isEmpty() && scoreHand(handList, ai, cardsToReturn) <= 0;
}
```

Read: mulligan when fewer than two lands (unless the deck has fewer than
one land in seven — a Channel deck could keep), when all lands, or when
seven cards hold six lands; keep everything else, and never go below
`MULLIGAN_THRESHOLD` (4; Reckless 3) — a four-card hand is kept sight
unseen. Moxen and Lotus count as lands (CMC 0 artifacts); colours are not
checked; "castable" is CMC ≤ land count, the same
approximation as ours. The `score += 10` line rewards 3-4 lands of 7 in
name only, because `score` is only compared to 0 — the whole function
collapses to the three `return … ? handSize : 0` lines.

Bottoming under the London rule (`PlayerControllerAi.tuckCardsViaMulligan`,
`PlayerControllerAi.java:777-816`): `numLandsDesired = (startingHandSize − cardsToReturn) / 2`;
with too many lands, bottom the worst land (non-mana-producing first,
`getWorstLand`); otherwise bottom the highest-CMC non-land
("assume the max CMC one is worse"); with nothing left, `getWorstAI`.
The 1997 game has no bottoming (Paris rule: seven becomes six), so only
`wantMulligan` is comparable.

### 5.2 Ours — `AiMulligan`

`engine/ai/ai_mulligan.gd` (114 lines): `FLOOR = 4`; `KEEP_LANDS`
`{7: [2, 5], 6: [2, 4], 5: [1, 4]}`; a hand keeps when its land count is
inside the band for its size AND `casts_a_spell` finds a spell whose
colours the lands in hand can pay — Forge's "castable" check with the
colour test Forge's TODO asks for. Both sides refuse to go below four; our
band [2,5] of seven is Forge's `landSize >= 2 && landSize < handSize − 1`
exactly, our six-card band [2,4] is one land tighter than Forge (which
keeps a 6-card 5-land hand), and ours has no "deck land ratio" escape for a
no-land hand (Forge keeps a one-land hand in a deck with fewer than one
land in seven — the ratio `library / landsInDeck > 6`). For the pool, the
one addition worth taking is that escape, sized to a Channel/Lotus deck
(§9, small); the colour check is ours and stays.

---

## 6. THE SIMULATION AI

Files: `forge/forge-ai/src/main/java/forge/ai/simulation/{SpellAbilityPicker,GameSimulator,GameStateEvaluator,SimulationController,Plan,GameCopier,OnePlaySafetyChecker}.java`.

### 6.1 What it is

When the lobby flag `AIOption.USE_SIMULATION` is set
(`forge/forge-ai/src/main/java/forge/ai/AIOption.java:3-6`;
`LobbyPlayerAi.java:38-40`; desktop only, a right-click item on the player
panel, `forge-gui-desktop/src/main/java/forge/screens/home/PlayerPanel.java:575-583`;
every non-lobby AI gets `null` options, `GamePlayerUtil.java:49-58`),
`AiController.chooseSpellAbilityToPlay` hands the main-phase decision to
`SpellAbilityPicker.chooseSpellAbilityToPlay` (`AiController.java:1355-1402`)
instead of the heuristic list of §1. The picker:

1. passes at once if its own spell is on top of the stack
   (`SpellAbilityPicker.java:83-105`);
2. builds the candidate list from every playable spell and ability
   (`:57-81`, `canPlayAndPayForSim` `:306-339`), dropping those the
   heuristic says should wait (`shouldWaitForLater` `:275-293`);
3. for each candidate, copies the whole game (`GameCopier`), plays the
   candidate on the copy for every legal target choice (`:354-366`), resolves
   the copy, and scores it with `GameStateEvaluator.getScoreForGameState`
   (candidate loop `:165-189`);
4. recurses into the copy — `SimulationController.shouldRecurse`
   (`SimulationController.java:59-61`) — to `DEFAULT_MAX_DEPTH = 3`
   (`:15`), i.e. up to three of its own plays in sequence within the same
   priority window, with a cache of "this play made things worse" to prune
   (`:23-31`, `:254-258`);
5. keeps the best sequence as a `Plan` (`Plan.java`; `createNewPlan`
   `SpellAbilityPicker.java:128-163`) and replays it step by step in the
   real game (`:208-241`), making a second plan at COMBAT_DECLARE_BLOCKERS
   ("Deciding to wait until after declare blockers." `:155`).

### 6.2 What the evaluator scores

`GameStateEvaluator.getScoreForGameState` (`GameStateEvaluator.java:81-200`),
after a combat preview on a copy (`:39-55`):

```java
private static final int GAME_OVER_TURN_PENALTY = 1000;      // :81
if (game.isGameOver()) return winner == aiPlayer ? Integer.MAX_VALUE - turn*1000 : Integer.MIN_VALUE + turn*1000;  // :96-99
// hand
for opponent: score -= 4 * cards;                                                              // :129-140
own: score += cards + 4 * fullValueCards;  (cards beyond max hand size count 1, not 5)
// life
score += 2 * teamLife / teamPlayers; score -= 2 * opponentLife / opponents;                   // :157-160
// battlefield
own creature summon-sick before MAIN2 → its value is not counted this turn                    // :180-196
// mana base
evalManaBase: lands 3 + 100/mana + 3/colour, +25 manland, +10 sac, +50 repeatable, +6/static  // :207-251, :276-321
// cards
evalCard: creature → ComputerUtilCard.evaluateCreature; land → evaluateLand; aura → 0; else 50 + 30*CMC   // :253-274
```
Weights, not fitted: a card in hand is worth 5 points, a life 2, a
vanilla 2/2 about 130, a Serra about 250, a Moat 0 (an aura or a global
enchantment has no evaluator beyond `50 + 30*CMC` — a Moat is 170 points
as "some permanent", the same as a Juzám). Nothing scores tempo, mana held,
threats in hand, or the opponent's likely plays: the copy is scored after
the AI's own sequence resolves and a combat preview, with the opponent
static.

### 6.3 Depth, cost, and information

- Depth 3, no wall-clock budget: `AI_TIMEOUT` (`AiController.java:1604-1618`)
  wraps only the heuristic path. A main phase with N candidates and K
  targets each performs ≥ 2N+1 full game copies at depth 1 alone, and
  `GameCopier.copyGame` re-parses every card from its script
  (`GameCopier.java:314`, `CardFactory.getCard`) — hundreds of milliseconds
  per copy in Java; the picker is visibly slow with a full board.
- `GameCopier.PRUNE_HIDDEN_INFO = false` (`GameCopier.java:296-298`): the
  copy carries the opponent's hand and library in order. The simulated
  combat preview and any counter the opponent "would" cast are therefore
  computed against real hidden information. This is a correctness cheat as
  much as a design choice, and one reason the feature is off by default.
- `OnePlaySafetyChecker` (`OnePlaySafetyChecker.java:23-30`, wired at
  `AiController.java:966-969`): a hybrid that runs the HEURISTIC picker,
  then simulates just that one play and vetoes it if the score drops. This
  one-ply veto is cheap (one copy per decision) and does not need depth.

### 6.4 Verdict for a pure-GDScript headless engine

Copy-the-game-and-replay is not a fit. Our `MtgGame` is a tree of
`CardInstance`s with effect objects and a static-layer cache; a deep copy
per candidate per target at 50-200 decisions per game would multiply the
Deck Lab's cost by two orders of magnitude and would need a copy path
that never touches the display layer. It would also need a hidden-zone
prune that Forge never wrote, or it inherits the cheat. What does fit:

1. **The one-ply veto**, à la `OnePlaySafetyChecker`, on a cheap position
   score — ours already has one: `Evaluator.position_score`
   (`engine/ai/evaluator.gd:121`) is exactly `GameStateEvaluator` without
   the copy: `W_LIFE 1.0`, `W_BOARD 2.0`, `W_HAND 1.5`, `W_LANDS 1.0`
   (`:28-39`) against Forge's 2 / 1 / 5 / evalManaBase. The gap is that
   `AiPlayer` prices a cast by `_cast_value` (card value + victim value)
   rather than by the position after it; a "would the position be worse
   after this resolves and their obvious answer resolves" check on a
   PROJECTED position (no copy: compute the deltas — creature dies, life
   changes, hand −1) is the form of simulation our engine can afford, and
   the sweeper (`_sweep_value`, `:1193`) and the level (`_level_value`,
   `:1245`) already do it for their own effect. §9 proposes extending it.
2. **The combat preview** as the evaluator's board term: our combat search
   (`combat_search_nodes`, `_declare_attacks` `:3158`) already projects
   the attack; Forge's picker gets the same from `:39-55`.
3. **Not** the depth-3 sequence search, and **not** the hand/library
   visibility.

---

## 7. THE CARDS

One line per pool card checked in `forge/forge-gui/res/cardsfolder/<letter>/<name>.txt`
(HEAD b09a3d3f). "none" means the script carries no AI hint of any kind and
the card is played by its ApiType class alone (§3). The hint vocabulary:
`AILogic$` selects a named branch inside the ability AI; `SVar:PlayMain1:TRUE`
lifts the Main-2 default (§1.7); `SVar:NeedsToPlay` / `NeedsToPlayVar`
are cast preconditions read by `ComputerUtilCard.checkNeedsToPlayReqs`
(`ComputerUtilCard.java:2137-2199`); `SVar:NonStackingEffect:True` stops
a second copy; `AI:RemoveDeck:Random|All` keeps the card out of AI-built
decks (Random: sometimes; All: always — a confession that the AI cannot
play it); `SacMe:N` / `DiscardMe:N` price the card as fodder;
`EndOfTurnLeavePlay` marks a Ball Lightning; `AttachAILogic` picks the
aura branch of §3.11; `AILandRemovalMinScore` raises a land's priority as
a Strip Mine target.

**Blue**
| card | hint | what it does to the AI |
|---|---|---|
| Ancestral Recall | none | DrawAi: their end step, capped by hand room and library−3 |
| Braingeyser | none | DrawAi: X = min(mana, hand room, library−3); at an opponent when ≥ their library |
| Counterspell / Spell Blast / Mana Drain / Power Sink | none | CounterAi §3.2; Power Sink X = their open mana + 1 |
| Time Walk | none | AddTurnAi: always cast |
| Timetwister | `AILogic$ Timetwister` | SpecialCardAi (`SpecialCardAi.java:1848-1870`): cast when own hand ≤ 3 (`HAND_SIZE_THRESHOLD`), never when it would deck itself or refill an opponent's larger hand |
| Control Magic | `AttachAILogic:GainControl` | AttachAi: best enemy permanent, creature eval ≥ 130 |
| Clone / Vesuvan Doppelganger / Copy Artifact | none / `AILogic$ CloneBestCreature` / none | CloneAi: copies the best creature on either side |
| Unsummon / Boomerang / Hurkyl's Recall | none | ChangeZoneAi bounce: own threatened permanent first, else their best non-land |
| Psionic Blast | none | DamageDealAi (4 damage, self-damage cost checked by `willPayCosts`) |
| Serendib Efreet / Mahamoti Djinn / Wall of Air | none | PermanentCreatureAi, Main 2 |
| Sorceress Queen | none | PumpAi curse branch (−X/−Y on their best creature at their combat) |
| Mana Short | `AI:RemoveDeck:All` | the AI does not know when to cast it (ManaAi drain branch, their end step) |
| Jayemdae Tome | none | DrawAi ability: their end step, with hand room |
| Millstone | `AILogic$ AtOppEOT` | MillAi at their end step; player whose library empties first |
| Howling Mine | none | PermanentAi (no evaluator for a symmetric enchantment: cast in Main 2 whenever castable) |
| Circle of Protection: Blue | `AILogic$ NeedsPrevention`, NonStackingEffect, RemoveDeck:Random | ChooseSourceAi: only against a damaging blue source |

**Black**
| card | hint | what it does to the AI |
|---|---|---|
| Dark Ritual | `AILogic$ ManaRitual`, `AINoRecursiveCheck$ True` | ManaAi §3.13: only when it enables a spell in hand |
| Demonic Tutor | `AI:RemoveDeck:Random` | ChangeZoneAi tutor: deck key cards → land fixing → creature → best |
| Mind Twist | none | DiscardAi: X = min(mana, their hand); Main 2 |
| Hymn to Tourach | none | DiscardAi, Main 2 |
| Hypnotic Specter / Juzám Djinn / Sengir Vampire / Royal Assassin / Nether Shadow | none / none / none / none / `DiscardMe:2 SacMe:2` | PermanentCreatureAi; Juzám's upkeep refused when `life <= 1` or in danger (§3.10); Assassin via TapAi/DestroyAi at their combat |
| Drain Life | `AILogic$ XLifeDrain` | §3.1: refuse under 3, creature only on an exact kill or power ≥ 5, else face |
| Pestilence | `AILogic$ DmgAllCreaturesAndPlayers`, `NeedsToPlay:Creature`, NonStackingEffect | DamageAllAi reusable branch; cast only with a creature on the battlefield |
| Animate Dead | `AttachAILogic:Reanimate` | best creature in either graveyard |
| Terror / Sinkhole | none | DestroyAi with `useRemovalNow`; Sinkhole through the land-removal logic |
| Underworld Dreams / The Abyss / Deathgrip / Gloom | none / RemoveDeck:Random / NonStackingEffect+RemoveDeck:Random / RemoveDeck:Random | PermanentAi; Main 2 |
| The Rack | `AILogic$ MostCardsInHand` (ChoosePlayer) | picks the opponent with the fullest hand |

**Red**
| card | hint | what it does to the AI |
|---|---|---|
| Lightning Bolt / Chain Lightning | none (Chain's copy sub `AILogic$ Always`) | DamageDealAi §3.1 |
| Fireball / Disintegrate | none / sub `AILogic$ CantRegenerate` | X = all mana; HOLD_X rule; Fireball split `DivideEvenly` |
| Earthquake | none | DamageAllAi: smallest lethal X, else 200-point creature margin |
| Wheel of Fortune | `NeedsToPlayVar:Y LE2` (`Y:Count$ValidHand Card.YouOwn+!namedWheel of Fortune`) | cast only with ≤ 2 other cards in hand |
| Channel | `AI:RemoveDeck:All` | the AI never builds with it; if dealt, ManaAi treats it as a ritual whose cost is life |
| Ball Lightning | `EndOfTurnLeavePlay`, `PlayMain1:TRUE` | Main 1, attacks, not counted as a permanent to keep |
| Shivan Dragon / Kird Ape | none | PermanentCreatureAi; firebreathing by PumpAi X |
| Stone Rain / Flashfires / Tsunami | none / RemoveDeck:Random / RemoveDeck:Random | DestroyAi land branch / DestroyAllAi lands |
| Red Elemental Blast / Blue Elemental Blast | RemoveDeck:Random | CounterAi or DestroyAi by mode; never built into a deck |
| Blood Moon / Mana Flare / Manabarbs | NonStackingEffect+RemoveDeck:Random / none / RemoveDeck:Random | PermanentAi; Main 2 |
| Chaos Orb | `AILogic$ Always` | activated on the first legal chance |
| Mirror Universe | NonStackingEffect | `LifeExchangeAi.java:48-53`: `myLife < 5 && hLife > myLife` → always; else `hLife > myLife + 8` |

**Green**
| card | hint | what it does to the AI |
|---|---|---|
| Regrowth | none | ChangeZoneAi §3.9: never before Main 1, before Main 2 only with one card in hand; pick = creature then best |
| Giant Growth | none | PumpAi §3.7; held for blocks 65 % |
| Berserk | `AILogic$ Berserk` | unblocked attacker for lethal, or with `USE_BERSERK_AGGRESSIVELY` |
| Hurricane | none | DamageAllAi over fliers |
| Erhnam Djinn / Llanowar Elves / Elvish Archers | none | PermanentCreatureAi |
| Fog | none | FogAi §3.13 |
| Lure | `AttachAILogic:Pump` | on own best attacker (avoids already-enchanted hosts) |
| Sylvan Library | `AILogic$ WorstCard`, `AI:RemoveDeck:All` | keeps the worst card on top; never built with |
| Tranquility | none | DestroyAllAi enchantments branch |

**White**
| card | hint | what it does to the AI |
|---|---|---|
| Swords to Plowshares | none | ChangeZoneAi exile with `useRemovalNow`; not before Main 2 on own turn with no own creatures |
| Disenchant | none | DestroyAi; artifacts/enchantments with a static or trigger are threat 1.0 (§3.4) |
| Wrath of God | none | DestroyAllAi: 200-point creature margin or next attack lethal |
| Armageddon | none | DestroyAllAi lands branch: only when creatures are ≥ their creatures + 200 and land value not worse |
| Balance | `AILogic$ BalanceCreaturesAndLands` | BalanceAi §3.3 |
| Serra Angel / Savannah Lions / White Knight | none | PermanentCreatureAi |
| Moat | `AI:RemoveDeck:Random` | PermanentAi; no evaluator — cast in Main 2 like any enchantment |
| Crusade | `PlayMain1:TRUE`, `NeedsToPlayVar:CountOpps LTCountMe` | cast in Main 1, only with more white creatures than the opponents |
| Land Tax | none | PermanentAi; its trigger fetches basics when behind on lands |
| Circle of Protection: Red / White | `AILogic$ NeedsPrevention`, NonStackingEffect, RemoveDeck:Random | ChooseSourceAi against a damaging source of that colour |
| Karakas | none (`DeckHints:Type$Legendary`) | ChangeZoneAi bounce of a legendary creature (own threatened first, else theirs) |

**Artifacts and lands**
| card | hint | what it does to the AI |
|---|---|---|
| Black Lotus | `AILogic$ BlackLotus` | `doManaRitualLogic`: cracked only to enable a spell in hand |
| Moxen | `PlayMain1:TRUE` | cast at once |
| Sol Ring / Mana Vault / Basalt Monolith | none / RemoveDeck:Random / `Untap AILogic$ AtOppEOT`, `AIManaPref$ NotSameCard`, RemoveDeck:Random | tapped in payment; Monolith untapped at their end step, never to pay its own untap |
| Icy Manipulator | none | TapAi §3.12 |
| Disrupting Scepter | none | DiscardAi ability, Main 2 |
| Jayemdae Tome, Howling Mine — see Blue | | |
| Black Vise | `AILogic$ MostCardsInHand` | picks the opponent with the fullest hand |
| Ivory Tower / Fellwar Stone / Zuran Orb (Ice Age, not in the pool) | none / none / `AILogic$ CriticalOnly` | PermanentAi |
| Winter Orb / Stasis | NonStackingEffect, RemoveDeck:Random | PermanentAi; the AI has no lock logic |
| Nevinyrral's Disk | NonStackingEffect | DestroyAllAi mixed branch: fires when their permanents out-value ours by > 3 |
| Forcefield | `AILogic$ NeedsPrevention` (ChooseCard), NonStackingEffect | only against an unblocked attacker |
| Energy Flux | `NeedsToPlayVar:CountOpps GTCountMe`, RemoveDeck:Random | cast only when they have more artifacts |
| Relic Barrier | RemoveDeck:Random | TapAi |
| Mishra's Factory | none | AnimateAi §3.8 |
| Strip Mine | none | DestroyAi land-for-land logic §3.4 |
| Maze of Ith | `Untap … AILogic$ PreventCombatDamage`, RemoveDeck:Random, `AILandRemovalMinScore:170` | UntapAi on an attacker; high-priority Strip Mine target |
| Library of Alexandria | none | `A:AB$ Draw | Cost$ T | PresentZone$ Hand | IsPresent$ Card.YouOwn | PresentCompare$ EQ7`: DrawAi fires when the hand happens to be seven; nothing holds the hand at seven for it |
| City of Brass | none | ManaAi; the pain is priced by `ComputerUtilMana` land ordering |

The pattern: of the ninety-odd pool cards checked, twenty-seven carry a
hint, and half of those hints are `RemoveDeck` — the card is kept away
from AI decks rather than taught. The 1995 control pilot's tools
(Counterspell, Mana Drain, Swords, Disenchant, Moat, Wrath, Balance, Tome,
Ancestral, Braingeyser, Regrowth, Time Walk, Mind Twist) carry no card
knowledge at all except Balance's logic and Timetwister's threshold; they
are played by the generic classes of §3.

---

## 8. SIDE BY SIDE — ours against Forge, function by function

Ours is `engine/ai/ai_player.gd` (AiPlayer), `engine/ai/ai_profile.gd`
(AiProfile), `engine/ai/effect_intent.gd` (EffectIntent),
`engine/ai/evaluator.gd` (Evaluator), `engine/ai/ai_mulligan.gd`,
`engine/ai/ai_match_memory.gd`. "Seam" names the place in ours where the
Forge behaviour would attach: an EffectIntent field, an AiProfile knob, or
an AiPlayer method. Verdicts: **ours** = ours is stronger or already does
it; **equal** = same rule in different clothes; **Forge** = Forge sees
something ours cannot.

| decision | ours | Forge | verdict, seam |
|---|---|---|---|
| Who acts, how often | `act` `:77-117`, one action per priority, greedy, no plan across calls | `chooseSpellAbilityToPlay` loop, first `WillPlay` wins (§1.4); a Plan only under simulation | equal |
| Land drop timing | `_try_play_land` `:152-175`: first thing in the main step, best colour shortfall | Main 2 when no spell in hand needs it and other permanents exist (`HOLD_LAND_DROP_FOR_MAIN2_IF_UNUSED` 100 %, §1.7) | **Forge**: information hiding; seam `_try_play_land` + a knob |
| Which land | colour shortfall of the deepest single card, mana-less land last | `chooseBestLandToPlay`: same shortfall idea, plus "hold the Factory/Maze until needed" | equal |
| Main 1 vs Main 2 | none: `_try_cast_best` fires in the first main step reached (§1.10) | permanents, draw, discard, tutor-to-hand, Regrowth, lifegain wait for Main 2 unless `castPermanentInMain1` (§1.7, §3.5, §3.6, §3.9) | **Forge**: seam `act` `:102-106` / `_main_phase_action` `:135`; new knob |
| Counterspell mana held open | `_held_reserve` `:420`, `_holding_counter` `:1295`, `_blue_after_plan` `:1303`: a marginal cast (value < 6) that taps below {U}{U} waits | none — three TODOs (§2.5) | **ours** |
| Mana held for an instant with a job | `_held_reserve`: a sorcery-speed cast must be worth 1.5× the held instant's job | `reserveManaSourcesForNextSpell`, `HELD_MANA_SOURCES_FOR_DECLBLK` (§2) | equal |
| Mana held for Main 2 after combat | `_main2_reserve` `:3011` (firebreathing only) | `reserveManaSourcesForMain2` + `predictSpellToCastInMain2` (§2.2), consulted by every combat pump and animate | **Forge** in scope, but moot while ours has no Main 2 (see above) |
| What to counter | `_try_counter` `:2739-2806`: `Evaluator.card_value(top) >= counter_threshold` (5.0 Wizard, 5.5 Sorcerer, 7 Magician); a counter aimed at our spell is judged by that spell's value | CMC-bucket rolls + ApiType categories (§3.2); no reading of own hand | **ours** for the threat side; **Forge** for the category side (a damage spell, a removal spell, another counter are countered on TYPE) — seam: EffectIntent already carries `damage`, `removes`, `counters`, `sweeper`; missing fields for an extra turn, a wheel, a graveyard return |
| Which counter | first legal counter in hand order | `counterSpellRestriction`: hard > unless, cheap > dear, ability > spell (§3.2) | **Forge**: seam `_try_counter`'s hand loop, sort before cast (size S) |
| Power Sink's X | `max_x` — all our mana (`:2792`) | `min(maxX, theirOpenMana + 1)`, refuse when they can pay (§3.2) | **Forge**: seam `_try_counter`'s `x = max_x` branch; needs "their untapped mana" which `_mana_sources` can give for the opponent |
| Burn: face or creature | `_size_and_aim` / `_fire_held_instant` `:1747-1769`: creature worth ≥ 3 first; face when lethal or `life <= dmg*2` | face first when `life − dmg < 5`, else hand-weighted roll at their EOT (§3.1) | equal (thresholds 6 vs 7 for a Bolt); ours deterministic |
| Burn: X sizing | `_size_x_burn` `:1493`: exact kill / lethal / face at `life <= dmg(max)*2` | max X always; `HOLD_X` threshold 5 before turn 10 (§3.1, §3.14) | **ours** for sizing; **Forge** for the hold (a 4-point Fireball at a Bear is a card wasted) — seam `_size_x_burn`'s creature branch: refuse when `x < hold_x && victim worth < …` |
| Two burn spells at one creature | none | `getDamagingSAToChain` + `NEXT_SPELL` reservation (§3.1) | **Forge**: seam `_size_and_aim` (intent.damage) + `_held_reserve` (size M) |
| Removal timing | instants held for their combat/EOT (`_is_held_instant` `:1674`); sorceries at once; victim by `_victim_value` `:1063` | `useRemovalNow` (§3.4): four interrupts, burn efficiency, tempo, threat with rolls | equal on the interrupts (ours: `_defensive_combat_response` `:2808`, `_save_from_the_stack` `:2322`); **Forge** on "their aura on it → now" and "keep the Bolt for the face" (efficiency ≥ 0.8) — seam `_victim_value` |
| Sweeper | `_sweep_value` `:1193` vs `SWEEP_BAR` 3.0: net board value | 200-point creature margin, or their next attack lethal after our blocks (§3.3) | equal on the margin; **Forge** on the lethal-attack test — seam `_sweep_value` can call the block planner (size M) |
| Balance | `_level_value` `:1245` (`levels_boards`) | `BalanceAi` diff with a 10 %/point roll | **ours** |
| Discard X | sized to the target's hand (`_size_and_aim` `:1423-1432`) | `min(maxX, theirHand)` (§3.5) | equal |
| Own draw sizing | `_hand_room` `:960`, `_library_slack` `:992`, `PACE_HORIZON` 20 (`counts_cards`, `paces_draws`) | hand room, `library − 3` (§3.6) | **ours** (ours also refuses the opponent's race) |
| Draw at the opponent (decking) | `_decking_draw` `:1012`: aimed when it empties their library | `numCards >= their library` (§3.6) | equal |
| Symmetric draw (Timetwister, Wheel) | `EffectIntent` reads neither; `_aimed_discard` `:322` explicitly refuses "each player discards" → `unknown` → cast by `card_value` alone | Timetwister: `HAND_SIZE_THRESHOLD = 3`, never into a bigger enemy hand (§7); Wheel: `NeedsToPlayVar:Y LE2` | **Forge**: seam — a new EffectIntent field `wheels` (cards each player draws/discards) sized by both hands, §9 P5 |
| Extra turn | no field; Time Walk priced by `card_value` 3.0 (`docs/arzakon.strategy` §5) | `AddTurnAi`: always cast (§3.13) | equal in play; **ours could be Forge** on the counter side — seam EffectIntent `extra_turns` (§9 P2) |
| Regrowth pick | `_choose_targets` `:4277-4297`: best `card_value` in the graveyard, refused under 2.5 (a land only when `_land_light`) | creature castable now, then best (§3.9); timing Main 2 with ≤ 1 card in hand | equal on the pick; **Forge** on the timing |
| Tutor pick | `answer_card` `:4957-4976`: highest `card_value` in the library | key cards → mana fixing (< 4 lands, nothing castable) → castable creature → best (§3.9) | **Forge**: seam `answer_card` for a search prompt — castability and land-shortage first (size S) |
| Ritual (Dark Ritual, Lotus) | `_mana_spell_enables` `:1694` | `doManaRitualLogic` (§3.13) | equal |
| Pump / trick | `_combat_self_pumps` `:2389`, `_defensive/_offensive_combat_response`, `_save_from_the_stack` | `shouldPumpCard`, held until blocks 65 % with `TRICK_ATTACKERS` (§3.7) | equal on the cases; **Forge** on "attack with the trick's target to provoke a block" — seam `_declare_attacks` `:3158` (size M) |
| Regeneration / prevention | `_shield` `:2645`, `_combat_regeneration` `:2483`, `_prevention_action` `:4479` | `RegenerateAi`, `ChooseSourceAi NeedsPrevention` | equal |
| Fog | `_worth_stopping_attacks` `:2041`, `chump_threshold` | `FogAi` lifeInDanger / `fogs > 2 && dmg > 2` | equal |
| Animate (Factory) | `_animation_value` `:914` | attack/block test on the animated copy (§3.8) | equal |
| Tap (Icy) | `_size_tap` `:1578`, `_best_tap_victim` `:1153`, `TAP_CARD_BAR` 4.0 | `TapAiBase.tapPrefTargeting` (§3.12) | equal |
| Auras and steal | `EffectIntent.aura_fits` `:566`, `AURA_HOSTILE` `:438` (`fits_auras`) | `AttachAi` pump preference; Control Magic `eval < 130` refused (§3.11) | equal; Forge's "not on an already-enchanted host" is in ours as `aura_fits` |
| Second legend / world | `_arrival_wasted` `:381` (`holds_duplicates`) | `WouldDestroyLegend` / `WouldDestroyWorldEnchantment` (§3.10) | equal |
| Upkeep-cost creatures at low life | `_life_price` `:1146`, `minds_pain` | `PermanentAi` upkeep refusal `life <= loss || inDanger` (§3.10) | equal |
| Mulligan | `AiMulligan` FLOOR 4, KEEP_LANDS bands, colour check (§5.2) | `scoreHand` (§5.1) | **ours** (colour); Forge's low-land-deck escape is a seam (size S) |
| Card memory | `AiMatchMemory`: per-duel max copies seen, damage by colour, across a match; never the decklist | per-turn scratch sets, cleared at end of turn (§4.3) | **ours** |
| Profiles | 4 presets, 17 knobs, capability knobs on/off by rung, `apply_overrides` from the command line | 4 files, ~100 keys, mostly chances (§4.1) | **ours** in design; Forge has three holds worth a knob each (land drop, X burn, trick-until-block) |
| Difficulty by randomness | `mistake_chance` (one roll per main step) | rolls inside nearly every decision (§10) | **ours** |
| Position score | `Evaluator.position_score` `:121`: W_LIFE 1, W_BOARD 2, W_HAND 1.5, W_LANDS 1 | `GameStateEvaluator` 2 / creature eval / 5 per card / evalManaBase (§6.2) | equal in shape; Forge weights the hand 2.5× more than life per point — worth a sweep (§9 P10) |
| One-ply safety | none: `_cast_value` prices the card and the victim | `OnePlaySafetyChecker` veto (§6.3) | **Forge** — seam `_try_cast_best` after `_size_and_aim` (§9 P8) |
| Wizard's information | `AiMatchMemory` fairness rule | `PRUNE_HIDDEN_INFO = false`, `cheatShuffle` (§4.4, §6.3) | **ours** |

Two points the table cannot show.

First, the four old loops of `docs/arzakon.strategy` §4. Forge knows NONE
of them. Channel-Fireball: Channel is `AI:RemoveDeck:All`, and if dealt
it is a ritual paid in life with a margin of 4 (`willPayCosts`), so a
Channel for 19 is never made and a Channel for 8 is made only when the
Fireball is already the thing enabled — and then `HOLD_X` refuses the
Fireball under 5 before turn 10. Time Walk / Regrowth / Timetwister: Time
Walk is always cast, Regrowth waits for a one-card hand, Timetwister for
a three-card hand; the three never see each other. Vise behind Moat: no
line in `DiscardAi`, `DrawAi` or `DamageDealAi` knows what Black Vise
does; the only Vise logic is which opponent to point it at. Decking:
`DrawAi` protects its own last three cards and aims a Braingeyser at an
empty library; `MillAi` picks the player closest to empty; nothing counts
turns. The material for §9's loop proposals is ours, not Forge's; what
Forge contributes is the demonstration that the generic classes cannot
express any of it.

Second, information. Forge's strength in the casting path is TIMING —
Main 2 by default, instants at the opponent's end step, tricks after
blocks, the land drop after the attack — and every one of those is a way
of not telling the opponent what is in hand until the last moment. Ours
has the instants (`holds_instants`) and not the rest. That is the biggest
single gap, and it is P1.

---

## 9. PROPOSALS — ranked by "feels like a competent human"

Conventions. Every proposal is a knob on `AiProfile` (`engine/ai/ai_profile.gd`),
on for the rungs named, off elsewhere, set from the Deck Lab with
`--profile-a wizard:KNOB=on|off` and swept with
`--sweep KNOB=on,off`. The Deck Lab conventions from `DeckLab/README.md`
apply to each plan: the sweep prints a candidate pair per value, a null
pair, and a CONTROL pair of decks on which the knob cannot fire, which must
replay the null run game for game (exit 4 otherwise); a proposal's
"no-harm" line is the five-starter matrix (`--matrix decks/ --games 200`)
run with the knob on and off at the same seed, and the rule is that no
matchup moves against the knob by more than the run's noise (at 1000 games
one standard deviation is ~1.6 points). The starter decks are
`decks/{big_green,black_red_raiders,blue_skies,mountain_artillery,white_knights}.deck`;
"The Deck" is any of `decks/community/the_deck_weissman_*.deck`
(`1995_05` carries Moat); the loop decks are named per proposal. Sizes:
S = a day, one function; M = a week, a new field or path with tests;
L = more.

### P1. Develop in Main 2 — `develops_late`

**Design.** Split `_main_phase_action` by main step. In Main 1 cast only
what Forge's `castPermanentInMain1` (`ComputerUtil.java:1141-1297`)
would: a haste creature, a creature that pumps this turn's attackers
(Crusade's `PlayMain1:TRUE`), a Mox (free), an aura or steal that changes
this combat, floating mana that would be lost, and — ours, not Forge's —
any sorcery-speed spell whose `_cast_value` clears a high bar (a Wrath
into a full board, a Mind Twist at a full hand, a lethal Fireball). Hold
the land drop with the same rule as `HOLD_LAND_DROP_FOR_MAIN2_IF_UNUSED`:
play it in Main 1 only when a spell in hand needs it this turn. Every
other permanent, draw spell, discard, tutor, Regrowth and land waits for
Main 2, where `_try_cast_best` runs as today. The instants already wait
(`holds_instants`). What the opponent gains from this is nothing; what
they lose is the knowledge, at their declare-blockers, of what we cast
after combat, and the certainty that our untapped lands mean an instant.
It is also what makes `_main2_reserve` (`ai_player.gd:3011`) meaningful
for more than firebreathing.
**Knob.** `develops_late` (bool). **Rung.** Sorcerer, Wizard (a Magician
develops in Main 1, as a learner does). **Size.** M. **Risk.** The act
loop must guarantee Main 2 is reached with the cast still legal (a
Winter Orb or a Kismet changes nothing here; a Stasis skips untap, not
Main 2). Combat planning must know the Main 2 cast is coming so it does
not spend the mana on a trick — `_main2_reserve` extended to the
predicted best cast, Forge's `predictSpellToCastInMain2`.
**Measurement.** `--sweep develops_late=on,off --profile-a wizard --deck-a decks/big_green.deck --deck-b decks/white_knights.deck --seed 11 --games 1000`
(creature decks, where the tricks are), then
`--deck-a decks/community/the_deck_weissman_1996.deck --deck-b decks/community/sligh_geeba_1996.deck`
and the same against `white_knights`. Control pair: a timing knob fires
on every deck with a permanent, so there is no honest pair of decks; run
the control as the null pair itself (`--null off`) and check `games.csv`
is byte-identical to the previous release's at the same seed. No-harm:
the five-starter matrix; the Deck mirror (`docs/ai-difficulty.md` §4
numbers) must not fall for Wizard.

### P2. Counter by what a spell does, and by what the hand can answer — `counters_by_shape`

**Design.** `_try_counter` (`ai_player.gd:2739`) compares one number,
`Evaluator.card_value`, with `counter_threshold`. Replace the test with a
shape reading from `EffectIntent` plus a hand reading. ALWAYS counter,
regardless of threshold: a sweeper (`intent.sweeper`) that would clear our
board; an X burn at our face that is lethal or within `FACE_URGENCY`; a
draw aimed at our library that decks us (`_decking_draw` from the
opponent's side); an extra turn (new field `extra_turns`); a wheel (new
field `wheels`, P5) when our hand is fuller; a counter aimed at our own
spell worth more than the counter (already there); a permanent-stealing
aura on our best creature. NEVER counter, regardless of threshold, when a
card in hand answers the spell later and cheaper — a creature we hold a
Swords or a Terror for (`intent.answers_creatures()` over the hand), an
enchantment we hold a Disenchant for — unless the counter is our last
card in hand or the spell is lethal: that is Weissman's rule, and it is
what `docs/ROADMAP.md` (~5945-5965) calls "a capability of a different
kind". Between the two, keep today's threshold. Forge's ApiType
categories (§3.2) are the demonstration that a type reading beats a cost
reading; its CMC buckets are not to be copied (§10).
**Knob.** `counters_by_shape` (bool) alongside `counter_threshold`.
**Rung.** Wizard; Sorcerer for the ALWAYS half only if the sweep says so.
**Size.** M (two EffectIntent fields, one function). **Risk.** The
"answer later" rule lets a Hypnotic Specter resolve when the Terror in
hand is the wrong colour of mana this turn; the rule must check
`_plan_taps` for the answer at the opponent's next end step, not just its
presence. **Measurement.** The Deck (`1996`) vs `sligh_geeba_1996`,
`white_knights`, `necropotence_1996` (`--sweep counters_by_shape=on,off --profile-a wizard --games 1000`);
then vs `decks/1997/duels/arzakon.deck` at `--lives 400,400` for the loop
half (Time Walk, Timetwister, Wheel, Braingeyser in that list). Control
pair: `big_green` vs `white_knights` — no counterspell in either. No-harm:
the five-starter matrix with `blue_skies` in seat A.

### P3. The decking count — `counts_the_race` (loop 4 of `docs/arzakon.strategy` §4)

**Design.** `counts_cards` and `paces_draws` already keep OUR library
safe (`_library_slack`, `_decking_draw`, `PACE_HORIZON`). The loop is the
other direction: when the opponent's plan is to deck us — a Millstone on
their board, a Braingeyser aimed at us, a Timetwister that refills THEIR
Twister — the count of turns-to-empty for both libraries becomes the
clock, ahead of life. Add `_race_clock(game)`: our library ÷ (1 + their
repeatable mill per turn + our own draw effects) against theirs; when
ours is the shorter, (a) `_size_and_aim` refuses every own draw spell that
is not lethal at their library, (b) `_try_counter` counts a draw-at-us or
a Millstone activation as ALWAYS (P2's field), (c) `_best_victim` and the
Disenchant path price the Millstone as `LETHAL_WORTH / turns_left`, and
(d) a Timetwister of ours is refused when their library is the smaller
(Forge's `Timetwister` logic has the first half of this: never into an
opponent's larger hand, never decking itself, `SpecialCardAi.java:1848-1870`).
**Knob.** `counts_the_race` (bool), extending `counts_cards`.
**Rung.** Sorcerer, Wizard. **Size.** S-M. **Risk.** A false clock —
counting a Howling Mine as a mill — makes a control deck stop drawing;
count only effects aimed at us or symmetric ones whose net is against
us. **Measurement.** The Deck (`1996`, which has Braingeyser and
Timetwister) vs `decks/tournament/ptcs_regnier.deck`, `ptcs_loconto.deck`,
`wc1995_redi.deck` (Millstone decks); The Deck vs `arzakon.deck` at
`--lives 400,400` (the Braingeyser/Timetwister race with life out of the
picture). Control pair: `mountain_artillery` vs `black_red_raiders` — no
draw or mill on either side. No-harm: the five-starter matrix.

### P4. The Vise hand — `minds_the_vise` (loop 3)

**Design.** Nothing in `EffectIntent` or `AiPlayer` reads Black Vise, The
Rack or a Moat, and by the rules of `docs/ai-difficulty.md` §1 nothing
card-named may. The reading that is not card-named: an opposing permanent
whose upkeep trigger deals damage scaled by our hand size (`Evaluator`
can see the trigger's effect class and its count source), and an
opposing static that stops our creatures attacking. With such a
permanent on their side: (a) `_draw_need` returns 0 above four cards and
`_hand_room` returns 0 — no Ancestral, no Tome tick, no Wheel
(`wheels`, P5) into it; (b) `_cast_value` adds `hand_size − 4` to every
sorcery-speed cast so the hand empties — a land is played, a creature is
cast even under a Moat; (c) `_victim_value` prices the Vise at the damage
it will deal over `PACE_HORIZON` turns and the Moat at the attack it
stops, so the one Disenchant goes to the right card (Forge's
`ACTIVELY_DESTROY_ARTS_AND_NONAURA_ENCHS` treats every static
enchantment as threat 1.0 — the same instinct, unpriced); (d) with the
Moat but no Vise, a Wall or a Bear is not cast, the hand is spent on the
Disenchant and the fliers. The Rack shares (a)-(c) with the threshold at
three.
**Knob.** `minds_the_vise` (bool). **Rung.** Sorcerer, Wizard.
**Size.** M (the trigger reading is the new piece; the rest is pricing).
**Risk.** Over-emptying the hand into a Wrath; keep (b) capped at a
one-point bonus per card past four. **Measurement.** The Deck
(`1995_05`, Moat) in seat A vs `sligh_geeba_1996` and `necro_montesanti_1996`
(Vise decks) — the pilot under the Vise is seat A's opponent, so run both
seatings; then `ptcs_justice.deck` vs The Deck. Control pair:
`big_green` vs `white_knights`. No-harm: the five-starter matrix; check
`mountain_artillery` (Vise-free burn) does not lose from seat B.

### P5. The wheel field and the three-card loop — `runs_loops` (loop 2)

**Design.** Two EffectIntent fields, both read from the effect classes and
never from names: `wheels` = cards each player discards-and-draws
(Timetwister, Wheel of Fortune; today `_aimed_discard` `:322` deliberately
refuses "each player discards" and the card is priced by `card_value`
alone), and `extra_turns` (Time Walk). Then the three readings: a wheel is
worth `(7 − our_hand) − (7 − their_hand)` cards, refused when negative,
refused when it decks either side against us (P3), refused under a Vise
(P4) — Forge's `HAND_SIZE_THRESHOLD = 3` is the one-sided version. An
extra turn is worth a draw plus a land drop plus an untap, so
`_cast_value` prices Time Walk at `W_HAND + land_value + the board's
attack` rather than the flat 3.0 `docs/arzakon.strategy` §5 complains of.
And the loop: with Regrowth in hand and Time Walk in the graveyard (or
the reverse), Regrowth's `_choose_targets` (`:4277-4297`) pick is Time
Walk when the extra turn is worth more than the best creature, and Time
Walk is cast BEFORE the Regrowth in the same main step so the Regrowth
can take it back in the next turn; a Timetwister with both in the
graveyard and fewer than four cards in hand is the reshuffle that
restarts it. None of this is card-named: it is "extra turn", "return a
card", "shuffle graveyards in".
**Knob.** `runs_loops` (bool), building on `counts_cards`.
**Rung.** Wizard only. **Size.** M. **Risk.** Timetwister refills the
opponent too; the wheel arithmetic must include their graveyard's best
cards when they have a Regrowth of their own. **Measurement.**
`looping_dolan_1996` and `churning_dolan_1996` piloted by Wizard vs
`white_knights` and `sligh_geeba_1996`; `arzakon.deck` (Time Walk,
Timetwister, Regrowth, Wheel) vs The Deck at `--lives 400,400` — the
measure is the median turn at which the loop first runs (from
`games.csv`), not only the win rate. Control pair: `big_green` vs
`white_knights`. No-harm: the five-starter matrix (no wheel or extra
turn in any starter, so this is the determinism check).

### P6. Channel-Fireball and "X equals my life" — `reads_lethal_x` (loop 1, and rule 5)

**Design.** Two halves. The pilot's half: a life-payment mana effect
(Channel: `adds_mana` with a life price — new EffectIntent field
`mana_for_life`) is cast only in the same step as an X spell whose
`_lethal_burn` becomes true with the extra mana; `_mana_spell_enables`
(`:1694`) is the seam, with the enabled spell required to be lethal
rather than merely castable, and the life paid capped at `life − 1 −
their unblocked attack`. Forge never gets here: Channel is
`AI:RemoveDeck:All` and `willPayCosts` keeps a margin of 4 (§8). The
defender's half: an opposing X spell on the stack whose X equals or
exceeds our life is lethal — `_try_counter` counts it as ALWAYS (P2), a
Fog is not the answer but a Power Sink is, and a Circle of Protection is
activated in the prevention window against it (`_prevention_action`
`:4479` already answers a stack spell). The reading "X equals my life"
is `intent.damage_at(x) >= life`, which `_lethal_burn` already computes
for our own spells.
**Knob.** `reads_lethal_x` (bool). **Rung.** Sorcerer, Wizard.
**Size.** S. **Risk.** Channel into a Counterspell: the pilot's half must
respect `_held_reserve` on the OPPONENT's side — with two blue open
across the table and a Sink in their colours, hold. **Measurement.**
`decks/tournament/wc1994_lestree.deck` (Channel, 4 Fireball) and
`decks/community/fork_recursion_chalice_1995.deck` piloted by Wizard vs
`white_knights` and `big_green`; the defender's half: The Deck vs
`wc1994_lestree`. Control pair: `white_knights` vs `big_green`. No-harm:
`mountain_artillery` (Fireball, no Channel) must not lose its X sizing.

### P7. Hold the X burn, chain the second — `holds_x_burn`

**Design.** Forge's `HOLD_X_DAMAGE_SPELLS_THRESHOLD` (§3.1): a Fireball or
Disintegrate for fewer than N is held while the game is young, nothing is
on fire and it is not lethal — because the same card is the finisher in
ten turns. Ours sizes X to the victim (`_size_x_burn` `:1493`), which is
better, but then fires a 2-point Disintegrate at a Bear on turn 3. Add
the hold to `_size_x_burn`'s creature branch: refuse when
`x < hold_x_threshold && turn < 2*hold_x_threshold && !in_danger && !lethal`
with the threshold a number knob (5 Wizard, 3 Sorcerer, as Forge's
Default and Reckless). The second half is Forge's chain
(`getDamagingSAToChain`): when one burn spell in hand does not kill the
victim but two do, `_size_and_aim` sizes the first for its share and
`_held_reserve` books the second's cost so the main-phase cast does not
tap it away.
**Knob.** `holds_x_burn` (int threshold; 0 = off). **Rung.** Sorcerer 3,
Wizard 5. **Size.** S (hold), M (chain). **Risk.** Holding the Fireball
against a Serra that then kills us; `in_danger` must include their
board's clock (`CLOCK_WEIGHT` `:3573`). **Measurement.**
`mountain_artillery` vs `white_knights` and `big_green`
(`--sweep holds_x_burn=0,3,5`); `sligh_geeba_1996` vs The Deck. Control
pair: `blue_skies` vs `white_knights` — no X burn. No-harm: the matrix.

### P8. The one-ply veto — `checks_before_casting`

**Design.** Forge's `OnePlaySafetyChecker` (§6.3) on our
`Evaluator.position_score` (`evaluator.gd:121`), without a game copy:
before `_try_cast_best` commits, project the position after the cast
resolves (hand −1, victim gone, life changed, our creature added, mana
tapped) and after the opponent's OBVIOUS answer — the largest damage
their untapped creatures can deal next turn, a held-instant guess of one
Bolt when they have {R} open and cards in hand — and refuse the cast when
the projected score is below the score of passing. The sweeper and the
level already do a projection of their own (`_sweep_value`,
`_level_value`); this is the same projection for every cast, and it is
the form of "simulation" a headless GDScript engine can afford: no copy,
one score per candidate.
**Knob.** `checks_before_casting` (bool). **Rung.** Wizard. **Size.** M.
**Risk.** A pessimistic projection that never casts into open red mana;
the answer guess must be one card, and only when `AiMatchMemory.copies_seen`
has shown that colour deals damage (`damage_from`). **Measurement.**
The Deck vs `sligh_geeba_1996` and `mountain_artillery` (the decks whose
open mana means a Bolt); `big_green` vs `black_red_raiders`. Control
pair: none can be honest (every cast is checked); use the null pair and
the determinism check as in P1. No-harm: the matrix, plus the average
game length from `games.csv` — a veto that lengthens games by more than
a turn is refusing too much.

### P9. The tutor's pick — `tutors_for_the_turn`

**Design.** `answer_card` (`ai_player.gd:4957`) takes the highest
`card_value` from the library for a Demonic Tutor. Forge's order
(§3.9): a land when short and nothing in hand is castable; otherwise the
best card CASTABLE with the mana we will have next turn (turn ≤ 3:
`CMC <= sources + 1`); otherwise the best. Add the two front steps, and
Forge's third — the deck's key cards — as "the card whose value on THIS
board is highest": a Wrath when their board out-values ours
(`_sweep_value`), a Moat when their creatures are ground-bound, the
finisher when the board is ours. The library search prompt is the seam;
`_land_light` (`:202`) is the land test.
**Knob.** `tutors_for_the_turn` (bool). **Rung.** Sorcerer, Wizard.
**Size.** S. **Risk.** None beyond a worse pick. **Measurement.** The
Deck (Demonic Tutor) vs `white_knights`, `sligh_geeba_1996`; `necropotence_1996`
vs The Deck. Control pair: `big_green` vs `white_knights` (no tutor).

### P10. The counter's own order, and Power Sink's X — inside `holds_instants`

**Design.** Two small Forge rules for `_try_counter`: (a) sort the
counters in hand before firing — hard before unless-cost, cheap before
dear, so a Mana Drain is spent on the Serra and a Power Sink on the
Bear, not the first in hand order (`counterSpellRestriction`, §3.2);
(b) Power Sink's X is `their untapped mana + 1` when we can pay it, and
the Sink is not cast at all when they can pay it and a hard counter is in
hand (Forge's `toPay <= usableManaSources → CantAfford`). Both are
deterministic and need no knob of their own; they belong to
`holds_instants`.
**Rung.** Magician and up (it is part of the existing capability).
**Size.** S. **Risk.** None. **Measurement.** `blue_skies` vs
`white_knights`, The Deck vs `sligh_geeba_1996`; the null run is the
same knob off. Control pair: `big_green` vs `mountain_artillery`.

### P11. The evaluator's hand weight — a sweep, not a knob

**Design.** Forge weights a card in hand at 5 points against 2 per life
and ~130 per vanilla 2/2 (§6.2); ours `W_HAND 1.5`, `W_LIFE 1.0`,
`W_BOARD 2.0` per `permanent_value` unit (`evaluator.gd:28-39`). The
ratio hand:life is 2.5 in Forge and 1.5 in ours. `position_score` is
read by the combat planners and the sweeper; a sweep of `W_HAND` over
{1.5, 2.0, 2.5} is the cheapest experiment in this list and may move the
Deck mirror more than any proposal above. It needs `W_HAND` exposed as a
profile number for the run (`apply_overrides` handles numbers).
**Size.** S. **Measurement.** The Deck mirror (`1996` vs `1996_02`), The
Deck vs `sligh_geeba_1996`, `big_green` vs `white_knights`
(`--sweep w_hand=1.5,2.0,2.5`). Control pair: none (every game is
scored); determinism at 1.5.

### P12. The mulligan's low-land deck — `AiMulligan`

**Design.** Forge's one escape (§5.1): with fewer than two lands, keep
when the LIBRARY has fewer than one land in seven
(`library.size()/landsInDeck > 6`). Ours mulligans every one-land hand.
For the pool this matters only to a Channel/Lotus/Mox deck, but those
exist (`wc1994_lestree`, `fork_recursion_chalice_1995`), and the Deck
Lab's `--mulligan on` is off by default, so the rule is untested at scale.
Add the escape to `KEEP_LANDS` as a deck-ratio branch; keep the colour
check.
**Size.** S. **Rung.** all (`mulligans` is on everywhere).
**Measurement.** `--mulligan on --sweep mulligans=on,off` for
`wc1994_lestree` vs `white_knights` and `big_green` vs `white_knights`;
control pair: none needed (the knob fires only before turn 1; the
determinism check at `off` suffices).

### P13. Attack to provoke the block — `holds_tricks`

**Design.** Forge holds a Giant Growth until blockers 65 % of the time,
books its mana (`HELD_MANA_SOURCES_FOR_DECLBLK`) and remembers the
creature it is for in `TRICK_ATTACKERS`, so the attack code sends that
creature in when a block would otherwise be bad (§3.7). Ours holds the
trick (`_is_held_instant`) and answers a block (`_offensive_combat_response`)
but `_declare_attacks` does not know the trick exists: a 2/2 with a
Giant Growth behind it stays home against a 3/3. The seam is the combat
model (`_build_combat_model` `:3450`): add the held pump's bonus to the
attacker's projected stats for the "will it die" test, and book the mana
in `_main2_reserve`. Deterministic, no roll.
**Knob.** `holds_tricks` (bool). **Rung.** Sorcerer, Wizard.
**Size.** M. **Risk.** Attacking into a Bolt; only when the trick's mana
is open AND the attacker survives the block after the pump.
**Measurement.** `big_green` vs `white_knights` and `black_red_raiders`;
`senor_stompy` vs `white_knights`. Control pair: `blue_skies` vs
`mountain_artillery` (no pump instant). No-harm: the matrix.

### P14. The sweeper's next-attack test — inside `levels_boards`

**Design.** `_sweep_value` (`:1193`) casts a Wrath on net board value
against `SWEEP_BAR`. Forge's second gate (§3.3) is "their next attack
would be lethal after our best blocks" — a Wrath at a board we are
losing 3-to-2 but cannot survive. Ours has the block planner; call it
from `_sweep_value` with their creatures as attackers and add
`LETHAL_WORTH` when the projected damage reaches our life. Also the
lands branch: Armageddon only when our creatures out-value theirs and
our land value is not the greater (Forge's `evaluatePermanentList`
comparison) — ours prices Armageddon by `Evaluator.land_value` already;
the creature condition is the addition.
**Size.** S. **Rung.** with `levels_boards` (Sorcerer, Wizard).
**Measurement.** The Deck vs `sligh_geeba_1996` and `white_knights`;
`decks/1997/originals` gauntlet for a white deck with Wrath (`--gauntlet decks/ --group originals`
with The Deck in seat A). Control pair: `big_green` vs `mountain_artillery`.

### Ranking, and what to do first

By the owner's measure — a competent tournament player piloting The Deck
— the order is P1 (timing is the thing a human notices first), P2
(Weissman's rule is what The Deck IS), P3–P6 (the four loops; each is
small once P2's fields exist, and P5's `wheels`/`extra_turns` fields are
prerequisites for P2's ALWAYS list, so build P5's fields first and P5's
loop last), P7, P13 (the two holds that make a creature deck feel
played), P8 (the veto, which catches the class of error none of the
others names), P9, P10, P14, P12, P11. The cheapest first day is P10 +
P12 + P11's sweep; the first week is P1.

---

## 10. DO NOT COPY

1. **Random rolls inside decisions.** `MyRandom.percentTrue` /
   `nextFloat()` appear in the default `checkApiLogic` (80 % on a repeat,
   `SpellAbilityAi.java:174-181`), in `shouldTgtP` (§3.1), `useRemovalNow`
   (§3.4), `shouldPumpCard` (§3.7), `BalanceAi` (§3.3), `LifeGainAi`,
   `ChangeZoneAllAi`'s final 80 % roll, `preventRunAwayActivations`, the
   counter chances, the trick hold, the land-drop hold, the chain. They
   make Forge's AI non-reproducible game for game and are its difficulty
   mechanism by accident. Ours has one roll, `mistake_chance`, at one
   place (`_main_phase_action`), and the Deck Lab's determinism check
   depends on it staying that way.
2. **CMC-bucket counter chances** (`CHANCE_TO_COUNTER_CMC_1/2/3`). A cost
   is not a threat; ours reads the card. Take the category idea (P2), not
   the buckets.
3. **The `CounterAi` category block as written** — the operator-precedence
   bug (§3.2) means `ALWAYS_COUNTER_DAMAGE_SPELLS` and
   `ALWAYS_COUNTER_REMOVAL_SPELLS` cannot be turned off, and the whole
   block is dead when `MIN_SPELL_CMC_TO_COUNTER` is 0. Reimplement the
   idea on `EffectIntent`; do not transcribe.
4. **Card-name hard-coding.** `SpecialCardAi` (Timetwister, Black Lotus,
   Chaos Orb, …), `AILogic$ <Name>` and `SVar:PlayMain1` are per-card
   knowledge kept in the card script and a 2,000-line switch. Our rule
   (`docs/ai-difficulty.md` §1) is "nothing card-named"; the equivalent
   knowledge belongs in `EffectIntent` readings of effect classes
   (`LEVELLERS` and `WINDOW_SHAPES` are the two sanctioned exceptions).
5. **`AI:RemoveDeck`.** Keeping a card out of AI decks because the AI
   cannot play it is a confession, not a strategy; the 1997 game's decks
   are fixed and the Wizard must play Channel, Mana Short, Sylvan Library
   and Winter Orb as dealt.
6. **The simulation AI as a whole** (§6): sees the opponent's hand and
   library (`PRUNE_HIDDEN_INFO = false`), re-parses every card per copy,
   has no time budget, and is off by default in Forge itself. Take the
   one-ply veto (P8) on a projected score, nothing more.
7. **`CHEAT_WITH_MANA_ON_SHUFFLE`** (§4.4). Never.
8. **Per-turn memory** (`AiCardMemory`, cleared at end of turn). Ours
   persists across a match by design; do not regress to Forge's model
   when adding hold-sets — add them as fields on `AiPlayer` scoped to the
   turn, and keep `AiMatchMemory` for what crosses turns.
9. **First-`WillPlay`-wins picking** (`chooseSpellAbilityToPlayFromList`,
   §1.4): the candidate list is sorted by evaluation once, and the first
   playable one is cast without comparing alternatives. Ours ranks by
   `_cast_value` across the whole hand; keep that.
10. **`willPayCosts`' flat life margin of 4** and `HOLD_X`'s "turn/2 <
    threshold" clock: both are constants standing in for a board reading
    (`CLOCK_WEIGHT`, `_life_price`) that ours already has.
11. **The `score += 10` mulligan line** and the rest of `scoreHand`'s
    dead scoring (§5.1): only the three zero-returns matter; do not port
    the shape.
12. **`preventRunAwayActivations`**: a random brake on repeat activations
    instead of a value reading. Ours prices each activation
    (`ABILITY_BAR_*`, `_ability_option`).
13. **Profile files as ~100 flat chances.** Ours has seventeen knobs,
    each with one reader and one measurement; a Forge-style profile
    would be unmeasurable in the Deck Lab.

---

## 11. LICENCE AND PROVENANCE

Forge is GPL-3.0 (`forge/LICENSE`; the root `README.md` says so); this
project is GPL-3.0 (`LICENSE`, `README.md:312`). Logic taken from Forge
can therefore be redistributed here, provided the copy is acknowledged
and the derived file stays under the same licence — which every file in
`engine/ai/` already is.

The project's convention for reimplemented sources is Tier 3 of
`Provenance.md` (rows 450-458: `s30`, `mage-go`, `Manalink`, `Decks.zip`,
`Text.res`, in a `| Source | Where | Used for |` table), with a marker at
the site of use in the style already in the tree — the `mage-go` comments
at `engine/ai/ai_player.gd:7, 15, 149, 226, 511` and the header of
`engine/ai/effect_intent.gd` ("Ported from mage-go's
intrinsicAbilityQuality and bestXValue"). For Forge:

- Add one Tier 3 row: `| Forge (GPL-3.0, HEAD b09a3d3f0093b7ba26a0debc82d80996b8826b37, 2026-09-08) | engine/ai/ai_player.gd, engine/ai/effect_intent.gd, engine/ai/ai_mulligan.gd | AI casting heuristics: … |`
  listing the functions actually taken.
- At each site, a comment naming the Forge file and line range
  (`forge-ai/src/main/java/forge/ai/ability/DamageDealAi.java:97-160`
  style, HEAD pinned), and the word **ported** or **inspired by**.

The distinction matters, and the report keeps it:

- **Ported** = the logic is transcribed, thresholds and branch order
  included, and a reader could diff the two. In this report that is:
  `BalanceAi`'s diff formula (if ever preferred to `_level_value`);
  `HOLD_X_DAMAGE_SPELLS_THRESHOLD` and its guard (P7); `scoreHand`'s
  low-land-deck escape (P12); `counterSpellRestriction`'s ordering and
  Power Sink's `usableManaSources + 1` (P10); `castPermanentInMain1`'s
  exception list (P1); the tutor order of `chooseCardToHiddenOriginChangeZone`
  (P9); `DestroyAllAi`'s next-attack test (P14). Each gets a marker and
  the Provenance row names it.
- **Inspired by** = the idea is taken and rebuilt on `EffectIntent` and
  `Evaluator`, with different inputs and no shared constants: the
  Main-2 default (P1's structure), counter-by-type (P2), the one-ply veto
  (P8), the trick-provoking attack (P13), the position-score weights
  (P11). A marker still names the Forge class it answers, so a later
  reader can compare, but no Provenance row is owed for an idea.

Nothing in this report is copied text; the quoted blocks are citations
for the engineering argument, and a port into the tree would be a
rewrite in GDScript with the marker described above.
