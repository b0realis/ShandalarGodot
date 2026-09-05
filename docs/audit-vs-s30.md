# Scrutiny audit — the 897-card pool vs the 30th-anniversary remake (s30)

Date: 2026-09-01. Scope: **all 897 implemented cards**, read one by one
against the oracle text each card's header carries, against the `../s30`
remake, and against the 1997 artefacts. Written the day the pool was
declared complete, to ask whether "implemented" means "correct".

Pins for every fix live in `tests/cards/test_audit_vs_s30.gd`. Each one
FAILED before its fix and passes after; the failure output is quoted in
this document wherever the finding is subtle.

Suite at the end of this pass: **164 scripts / 2829 tests / 0 failing /
0 risky, `./run_tests.sh` exit 0.** (Baseline at the start of the pass was
162 / 2767. Another agent was lifting `SIMPLIFIED:` markers in the same
tree throughout, so the counts include their work as well as this one's.)

---

## 0. The first finding: **s30 has no card rules of its own**

This is the result that shapes everything below, and it is worth stating
before any card.

`s30/go.mod` requires `github.com/benprew/mage-go v1.0.0`, and
`s30/game/screens/duel/duel.go:17-23` imports `mage-go/cards` (for its
registration side effects), `mage-go/pkg/mage`, `.../core`,
`.../interactive` and the two AI packages. A search of the whole s30 tree
for a card constructor —

```
grep -rln "NewCreature\|NewArtifact\|NewEnchantment\|NewInstant\|NewSorcery" --include="*.go" .
```

— returns **nothing**, and so does a search for `AddReplacementEffect`,
`RegisterCard`, or any rules-option override. s30's 9 760 lines under
`game/screens/duel/` are a *presentation and adventure* layer: the board,
targeting UI, ante screen, X dialog, damage assignment, autopass, quests.

**So "audit against s30" is, for card behaviour, "audit against mage-go".**
That is the same reference `docs/audit-vs-mage-go.md` (2026-08-30, 255
cards) and `docs/audit-2026-09.md` (2026-08-31, 788 cards) used. What is
new here is (a) the remaining ~109 cards, (b) a second reading of the
whole pool with the error patterns those two audits established, and (c)
two evidence sources neither of them used: the **1997 per-card prompt
tables** and the **1997 community FAQ that ships inside s30**.

There is consequently **no `[s30]` card-behaviour divergence to report**:
s30 adds no card behaviour to diverge with. The one place s30 makes a
card-level decision of its own is its POOL, and that is §5.

### Caveat on the reference version

s30 pins mage-go `v1.0.0` from the module proxy; no Go toolchain and no
module cache exist on this machine, so the comparison used the working
clone at `../mage-go` (HEAD `d70ac51`). Where a mage-go behaviour is cited
below it is that clone's.

---

## 1. How the two pools were matched, and what "compared" means here

**Name-keyed, then hand-checked.** Every card in our registry was dumped
with its printed characteristics (a throwaway `SceneTree` script over
`CardRegistry`, deleted afterwards) and matched to mage-go by the exact
string inside `Register("<name>")`. mage-go builds some cards in loops
(the duals, the Circles, the Moxen), so the final membership test was "does
this name appear as a string literal in any non-test `.go` file under
`../mage-go/cards/`".

| Question | Answer |
|---|---|
| Cards in our pool | **897** |
| Cards mage-go (= s30's engine) implements or mentions | **809** of ours |
| Cards with **no** counterpart anywhere in mage-go | **88** — almost all of The Dark, plus Maze of Ith, Time Vault, Preacher, Season of the Witch, Worms of the Earth … |
| Cards s30 SHIPS in its own pool (`assets/card_info/scryfall_cards.json.zst`) | **555**, from `2ed,4ed,arn,atq,past,phpr` |
| Our base-set pool for those same six sets | **556** — identical but for Nalathni Dragon (§5) |
| Our pool beyond s30's | Legends (254 files) + The Dark (87 files) — the *Duels of the Planeswalkers* expansion, which s30 does not ship |
| mage-go's coverage of The Dark | **one card** (Blood Moon) |

**Compared vs inferred.** All **897** card files were opened and read
clause by clause against their own oracle text; that part is a real sweep,
not a sample, and it was done in seven slices by seven agents each
reporting file:line. Of those, the **809** with a mage-go counterpart were
also read against that counterpart. **301** of the 897 have a 1997 prompt
entry (§4) and were checked against it. Nothing in this document is
inferred: every "fixed" row has a test in `tests/cards/test_audit_vs_s30.gd`
that fails without the fix, and every "recorded" row names the file and line
that a reader can check in a minute.

**Printed characteristics were machine-diffed, again.** All 897 cards'
cost, types, supertypes, subtypes, power, toughness, keywords and oracle
text were diffed against the Scryfall snapshot in `cards/data/`. **Zero real
mismatches** (the only hits are lands printing `{0}` where Scryfall prints
nothing, the five Astral cards whose `Summon Jaguar`-style type line the
diff script cannot parse, and 38 known-cosmetic oracle rewordings). The
2026-09 audit's machine diff is confirmed and extended from 788 to 897.

---

## 2. Findings — fixed

Every row is pinned by a test in `tests/cards/test_audit_vs_s30.gd`.

| Card(s) | Divergence | Adjudication | Severity | Resolution |
|---|---|---|---|---|
| **Ydwen Efreet** (`arn`) | "Creatures it was blocking that had become blocked by only this creature this combat become unblocked" — the printed EXCEPTION to CR 509.1h. The card called `MtgGame.remove_from_combat(source)` with the default `unblock_solo_attackers = false`, so a lost coin flip left the attacker BLOCKED with no blockers: it dealt its damage to nobody. The Efreet was a Fog. `remove_from_combat`'s own doc comment names Ydwen Efreet and describes the flag it was not being passed | **We were wrong.** Oracle, CR 509.1h and mage-go (`RemoveFromCombatGathered` + `RevokeKeyword(AttrCanBlock)`, `arabian/creatures.go:559`) all agree | HIGH | Pass `true`. `tests/cards/test_pool_wave38.gd::test_ydwen_efreet_may_fizzle_its_own_block` had been written to enshrine the old behaviour and was corrected with it |
| **Pyramids** (`arn`) | "Destroy target Aura attached to A LAND" — the filter checked only that the target was an Aura with a host, never that the host was a land. Any Aura at all was a legal target. The card's own doc comment claimed the check it did not make | **We were wrong**, and three sources agree: the oracle, mage-go's `IsAuraOnLand` (`arabian/artifacts.go:334`), and the card's own 1997 prompt `@PYRAMIDS` (`Program/promptsX1.txt`), whose four strings include *"Illegal target (not enchanting a land)."* | MEDIUM | Host-type check moved into the TargetSpec as a game-aware filter, copying Savaen Elves' `_aura_on_a_land` — the other three "Aura attached to X" cards (Savaen Elves, Miracle Worker, Enchantment Alteration) were already right |
| **Soul Net** (`2ed`), **Tablet of Epityr** (`atq`) | "Whenever a CREATURE dies" / "Whenever an ARTIFACT you control is put into a graveyard" read the PRINTED type mask of a permanent that had already left the battlefield. An animated Mishra's Factory was not a creature dying; a creature Ashnod's Transmogrant had made an artifact was not an artifact dying | **We were wrong.** CR 608.2h; the engine snapshots exactly this into `CardInstance.last_types` and uses it five lines above the DIES dispatch. `docs/audit-2026-09.md` names Soul Net in the row that introduced `last_types` — the engine half landed, the card's own predicate did not | MEDIUM | Both read `last_types` now. A sweep of all 17 DIES-trigger cards found no third case |
| **Remove Enchantments** (`leg`) | Group 1 is "all enchantments you both own and control" — and an Aura IS an enchantment (CR 303.4). The predicate branched on `is_aura()` first, so an Aura was only ever tested against groups 2 and 3 (host you control / host is an attacking creature). Your own Psychic Venom or Paralyze on the opponent's non-attacking permanent was left on the battlefield | **We were wrong**; groups 2 and 3 say nothing about CONTROL precisely because they exist to reach Auras you own but do not control | MEDIUM | "Any enchantment you control" now runs first, Auras included |
| **Dwarven Demolition Team** (`2ed`), **Tunnel** (`2ed`), **Goblin Digging Team** (`drk`) | Three of the pool's seven Wall-targeting effects never called `TargetSpec.only_walls()`, so Wall of Shadows' printed third line — "can't be the target of spells that can target only Walls or of abilities that can target only Walls" — did not stop them. Animate Wall, Ali Baba and the three Glyphs all declare it | **We were wrong.** Wall of Shadows' oracle, and the mechanism the 2026-09 audit built for it | MEDIUM | `.only_walls()` on all three |
| **Howling Mine** (`2ed`) | "if this artifact is untapped" was supplied only as the trigger CONDITION, checked when the ability went on the stack. Tapping the Mine in response (Icy Manipulator, Relic Barrier — both in this pool) still handed the opponent the extra card | **We were wrong.** CR 603.4: an intervening "if" is checked when the ability would trigger AND again as it resolves. Land Tax (`4ed/land_tax.gd`) is the in-repo model. mage-go omits the condition entirely — already recorded as a mage-go deviation | MEDIUM | Re-checked on resolution, with a log line when it fails |
| **Ghazbán Ogre** (`arn`) | The mirror image: "if a player has more life than each other player" was checked ONLY at resolution. With the life totals tied — the opening position of every game — the ability still went on the stack, so any life change while it sat there (a Juzám Djinn upkeep bite, a Sengir trigger) made it defect | **We were wrong**, same CR 603.4, other half. mage-go has the same shape and its own `TODO` on it | MEDIUM | The leader test is now in both places |
| **Circle of Protection: Artifacts** (`4ed`) | The shield's source predicate read `source.data.is_type(ARTIFACT)`. A creature Ashnod's Transmogrant (same era, same pool) had made an artifact sailed straight through | **We were wrong.** CONTRIBUTING.md rule 5; CR 109.5. mage-go filters live (`FilterBattlefield(IsArtifact)`) and is right; the sibling shield in `drk/scarecrow.gd` already reads live | MEDIUM | Reads `source.is_type(...)` |
| **Sylvan Library** (`4ed`) | `_dig` opened with `if source.zone != BATTLEFIELD: return`, three lines under a comment citing CR 603.6 for the opposite. Disenchanting the Library in response to its own draw-step trigger refunded both cards | **We were wrong.** CR 603.6 / 608.2h — and nothing in the effect refers back to the enchantment. mage-go has Sylvan Library as a vanilla enchantment with an `XXX:` stub, so it adjudicates nothing | MEDIUM | Guard removed |
| **Spell Blast** (`2ed`), **In the Eye of Chaos** (`leg`) | Both compute "its mana value" with `ManaCost.mana_value()`, which counts an unresolved `{X}` as 0 — correct for a permanent, wrong for the only kind of object either card can ever look at, a spell ON THE STACK. A Spell Blast for 4 could not name a Fireball cast for X=3; a Spell Blast for 1 could counter any X spell in the game. In the Eye of Chaos charged {2} for an Alabaster Potion cast for X=3 instead of {5} | **We were wrong.** CR 202.3b. Two cards in the same folders already do it right — `leg/invoke_prejudice.gd` and `leg/mana_drain.gd`. mage-go shares the gap (and Spell Blast's `X >= CMC` was already recorded as a mage-go deviation) | MEDIUM | Both read `memory["x_value"] * cost.x_count` on top of the printed value, matching the house idiom |
| **Land Equilibrium** (`leg`) | "If an opponent who controls AT LEAST AS MANY lands as you do WOULD PUT a land onto the battlefield" — the applicability test of a replacement effect, asked before the land arrives. The count was taken after, so with four lands to their three, their fourth land was taxed. The card locked the opponent one land early and held them permanently BELOW parity instead of AT it | **We were wrong.** CR 614.1: the printed ORDER really is enter-then-sacrifice (which is why the arrival trigger is a fair model), but the printed CONDITION is not. mage-go does not implement the card | MEDIUM | The entrant is discounted from the comparison; it stays in the pool of lands that may be sacrificed |
| **Kudzu** (`2ed`) | "That land's controller may attach this Aura to A LAND OF THEIR CHOICE" — the candidate list was `players[victim].battlefield`, so the victim could never hand the vine back to the Kudzu player's own land, which is the card's entire defensive line | **We were wrong.** No ownership qualifier in the oracle, none in the 1997 prompt (`@KUDZU`: *"Kudzu triggering...Select target land."*), and mage-go scans the whole battlefield and then asks the host's controller | MEDIUM | Candidates come from `all_battlefield()` |
| **Token mana values** — Minor Demon (Boris Devilboon), Stangg Twin, Rukh (Rukh Egg), Wolves of the Hunt (Master of the Hunt), Spawn of Azar (Necropolis of Azar) | Five tokens were given a real MANA COST purely to make them the right colour, which also gave them a mana value of 1-2. A token has no mana cost (CR 111.4 / 202.3a), so its mana value is 0 — and four cards in this pool read that number: Great Defender, Subdue and Kry Shield ("+0/+X, where X is its mana value") and Juxtapose, whose own header states the correct rule ("a token … counts as 0") that the pool then contradicted | **We were wrong.** CR 111.4; `CardData.with_colors()` exists for exactly this and `leg/crimson_kobolds.gd` already uses it | MEDIUM | All five now carry `""` plus `.with_colors(...)`. **Sand Warrior (Hazezon Tamar) has the same defect and was NOT touched** — that file carries a `SIMPLIFIED:` marker and belongs to the ledger pass (§6) |
| **Spitting Slug** (`drk`) | "Whenever this creature blocks or BECOMES BLOCKED" — with no "by a creature", becoming blocked is ONE event however many creatures block (CR 509.1h). The engine dispatches `BLOCKED` once per declared PAIR, so a double block charged the {1}{G} rent twice; the second payment failed and the "otherwise" clause then handed first strike to every blocker, after the first payment had already bought it | **We were wrong.** A sweep of all sixteen `BLOCKED` listeners found Spitting Slug is the ONLY one with the bare wording — Cockatrice, Venom, Thicket Basilisk, Abomination, Giant Shark, Infinite Authority and Aisling Leprechaun all print "by a … creature" and are correctly per-blocker | MEDIUM | The attacking side counts only the first blocker's dispatch (`combat.blockers_of(...)[0]`); the blocking side needs no guard, since a blocker is assigned to one attacker here |
| **Dark Sphere** (`drk`) | "The next time A SOURCE OF YOUR CHOICE would deal damage to you" — the candidate list was the OPPONENT's permanents plus the stack. Your own City of Brass, Mana Crypt, Electric Eel, Elves of Deep Shadow and Wormwood Treefolk — all in this pool, all sources that deal damage to you — could not be named at all | **We were wrong.** No controller restriction in the oracle | LOW | Candidates come from `all_battlefield()` |
| **Wormwood Treefolk** (`drk`) | "{G}{G}: This creature gains forestwalk until end of turn AND DEALS 2 DAMAGE TO YOU" bailed out entirely if the Treefolk had died in response, so killing it in response made the ability free | **We were wrong.** CR 608.2h — only the landwalk grant has nothing to attach to. `drk/electric_eel.gd` has the same clause with no such bail | LOW | The grant is guarded; the damage is not |

## 3. Findings — recorded, not fixed

### 3a. Engine territory (`engine/mtg_game.gd` — owned elsewhere this session)

| Area | Finding | Severity |
|---|---|---|
| **Cost-payment records are per-PERMANENT, not per-ACTIVATION** | `activate_ability` writes what a cost ate into the SOURCE's memory: `_sacrificed_power` / `_sacrificed_toughness` (mtg_game.gd:1393-1394), `_exiled_mana_value` / `_exiled_name` (:1397, :1404), `_discarded_types` / `_discarded_name` (:1383). Every one of those is a single slot. Any card whose ability is cheap enough to stack two copies before either resolves reads the WRONG record: **Life Chisel** and **Diamond Valley** (free sacrifice outlets — sacrifice a 1/1 then a 5/5 and gain 5+5 instead of 1+5), **Necropolis** (`drk`, free exile-a-corpse — +0/+10 instead of +0/+7), **Land's Edge** (free, and *either player may activate it*: two land discards deal 2 damage instead of 4, and the top item erases the slot the bottom one needed). The value is last known information about ONE activation (CR 608.2h) and belongs on the `StackItem` | **HIGH** |
| **Personal Incarnation** | "{0}: The next **1** damage that would be dealt to this creature this turn is dealt to its owner instead" is implemented with Jade Monolith's whole-event redirect (`damage_redirect_to` + `damage_redirects`), and no amount cap exists anywhere in the field, the effect, or `_land_damage`. One free activation moves an entire Shivan Dragon hit. The card has no `SIMPLIFIED:` marker and no ledger row, and the deviation is currently PINNED by `tests/cards/test_pool_wave73.gd:295` (`assert_eq(avatar.damage, 0, "the whole packet was redirected")`). The 1997 prompt is the tell: `@PERSONAL_INCARNATION` (`Program/prompts.txt`) is *"Select damage to redirect."* / *"How much damage to redirect to you?"* — the original asked for an amount | **HIGH** |
| **Martyrs of Korlis / Reverse Polarity** | Both "by ARTIFACTS" clauses are implemented in `deal_damage` as `source.data.is_type(ARTIFACT)` (mtg_game.gd:1896, :1944) — printed types. Five lines above, the same function reads `source.is_creature()` and `source.cur_colors` live, so this is an inconsistency inside one function. A Transmogranted creature's combat damage is artifact damage; neither card sees it | MEDIUM |
| **Whippoorwill** (`drk`) | Its "damage … can't be prevented or dealt instead to another permanent or player" is enforced from mtg_game.gd:2004 downward, but two replacement gates run ABOVE it — Blood of the Martyr's redirect (:1963) and Rock Hydra's counter-eating prevention (:1975). Both cards are in this pool | MEDIUM |
| **"Prevent all COMBAT damage" has no combat flag** | **Enchanted Being** and **Marble Priest** (both `leg`) print "prevent all COMBAT damage … by X"; both are implemented with `cur_damage_immunity`, which `_creature_damage` applies to every packet. mage-go gets Enchanted Being right with an explicit `WithCombatOnly()` (`legends/creatures.go:143`) — **this is a place where the reference is ahead of us.** Currently unobservable for Marble Priest (no Wall in the pool deals non-combat damage) but live for Enchanted Being: an enchanted Prodigal Sorcerer's ping is wrongly prevented | MEDIUM |
| **Lich** (`2ed`) | "When this enchantment is put into a graveyard from the battlefield, you lose the game" listens on `LEAVES_BATTLEFIELD`, which four engine paths dispatch — graveyard, bounce, exile and ante. Bouncing your own Lich in response to lethal damage (Boomerang and Obelisk of Undoing are both in the pool) currently loses you the game. `DIES` is the correct hook and is dispatched only from `_move_to_graveyard`. mage-go uses a dedicated put-into-graveyard trigger and is right. *(Card carries a `SIMPLIFIED:` marker — ledger territory, see §6)* | HIGH |
| **Living Plane** (`leg`) | "All lands are 1/1 creatures" skips a land another effect already animated, because `continuous.gd` runs the floating animations in pass 1 before this static. Layer 7b is decided by TIMESTAMP, not specificity (CR 613.4/613.7), so a Mishra's Factory animated before Living Plane resolved should shrink to 1/1 | LOW |
| **Gravity Sphere** (`leg`) | "All creatures lose flying" runs in the static pass, but until-EOT keyword GRANTS run later (`continuous.gd:609`), so a Jump or a Flying Carpet always beats a Sphere that entered afterwards, whatever the timestamps. `ContinuousEffects` has a `_losses` pass built for this and the card does not use it | LOW |
| **Anti-Magic Aura** (`leg`) | "can't be enchanted by other Auras" is enforced only on the TARGETING path, so Enchantment Alteration can `move_aura` one onto the host anyway | LOW |
| **Sentinel** (`leg`) | "target creature blocking or blocked by this creature" reads `combat.blocks` directly and so misses band-mates' blockers, where the identical clause on `leg/lesser_werewolf.gd` correctly uses `band_of()` / `blockers_of_band()` | LOW |
| **Runesword** (`drk`) | "When THAT creature leaves the battlefield this turn, sacrifice this artifact" keeps one `memory["bearer"]` slot, so only the last creature armed this turn can break the sword; each activation makes its own delayed trigger (CR 603.7a). `drk/war_barge.gd` keeps a turn-stamped LIST and is the model | LOW |
| **Tangle Kelp** (`drk`) | A static ("doesn't untap … if it attacked") is compressed into a one-shot `skip_next_untap` written at the end step, and nothing clears it if the Aura then leaves | LOW |
| **Eater of the Dead** (`drk`) | "{0}: IF this creature is tapped, …" is installed as `.only_if()`, i.e. an ACTIVATION refusal, where the printed "if" is part of the effect. Activating while untapped and being tapped in response should work. **Deliberately not changed:** the ability is free and repeatable, and turning an activation refusal into a do-nothing resolution is exactly the shape that can make an AI loop; it wants an engine-side guard, not a card edit | LOW |
| **Dingus Egg** (`2ed`) | "Whenever a LAND is put into a graveyard" reads the printed type where the house idiom is `last_types`. No card in this pool grants or removes the land type, so no divergence is reachable today — recorded as latent | LOW |
| **Visions** (`4ed`) | `game._shuffle(library)` is the only call to a private `MtgGame` method anywhere under `cards/` (CONTRIBUTING.md rule 2). Behaviourally correct; it emits no log line or state signal | LOW |

### 3b. Ledger territory — cards carrying a `SIMPLIFIED:` marker, or named in `docs/simplified-cards.md`

These were found by this pass but belong to the fidelity-ledger agent. Each
is a deviation the card's EXISTING ledger row does not cover.

| Card | Finding not covered by its ledger row |
|---|---|
| **Takklemaggot** (`leg`) | "that creature's controller chooses a creature THIS CARD COULD ENCHANT" — the candidate list is `players[victim].battlefield` only, so the plague can never jump onto a creature the Maggot's controller controls, which is what the victim would choose. The row covers only the non-Aura fallback |
| **Nova Pentacle** (`leg`), **Preacher** (`drk`) | Nova Pentacle's "a source of your choice" is narrowed to the opponent's permanents (same defect as Dark Sphere, fixed above). Preacher's ability TARGETS the player, not the creature, so it can be activated with no legal creature at all, hands over creatures with shroud or protection, and never fizzles — the exact deviation Arena has its own ledger row for |
| **Primal Clay** (`4ed`) | "AS this creature enters" is a TRIGGER, not the engine's `as_it_enters` replacement (CR 614.1c), so the Clay sits on the battlefield as a 3/3 with priority passing before the shape is locked in. Its header claims the opposite in as many words. Shapeshifter, Rock Hydra, Wood Elemental and Nameless Race all use the replacement hook |
| **Clone / Copy Artifact** (`2ed`) | "YOU MAY have this enter as a copy" cannot be declined — `_apply_enters_as_copy` falls back to `candidates[0]`. Being forced to copy an opponent's Lord of the Pit or Ankh of Mishra is strictly worse than entering as a 0/0. The "copy choices" row covers WHICH, not WHETHER |
| **Demonic Hordes** (`2ed`) | The upkeep tithe bails out if the Hordes has left, so sacrificing it in response refunds the land. Force of Nature in the same set documents the correct rule and has no such guard (CR 603.6) |
| **Mana Vault** (`2ed`) | "if this artifact is tapped" — the same intervening-"if" gap as Howling Mine, in the other direction: an untapped Vault triggers anyway, and tapping it in response then burns for 1 |
| **Power Artifact** (`atq`) | "enchanted artifact's ACTIVATED abilities cost {2} less" rewrites only `cur_activated_abilities`; mana abilities live in `cur_mana_abilities` and are untouched, though a mana ability IS an activated ability (CR 605.1a). Celestial Prism's five `{2}` mana abilities are in this pool and are not discounted |
| **Urza's Miter** (`atq`) | Same printed-vs-`last_types` read as Tablet of Epityr, fixed above |
| **Glyph of Reincarnation** (`leg`) | The reanimation choice is asked of the GRAVEYARD's owner rather than the spell's controller (CR 609.3), so the opponent picks their best creature where the Glyph's controller would pick their worst |
| **Frankenstein's Monster** (`drk`) | "put this creature into its owner's graveyard" is implemented as `sacrifice_permanent`, which sets the `sacrificed` flag other cards read (CR 701.17) |
| **Goblin Polka Band** (`past`) | **Fixed 2026-09-02** with the "Astral random targeting" lift (`TargetSpec.at_random`): every creature is a candidate, the Band itself included, and a rolled creature that is already tapped wastes its {R}. Was: the random victims are rolled over UNTAPPED creatures only, so every {R} is guaranteed to tap something; printed, a tapped creature can be picked and the mana wasted. mage-go rolls over all creatures and skips tapped ones inside the effect. The row covers WHEN the roll happens, not the candidate set |
| **Hazezon Tamar** (`leg`) | Sand Warrior carries the token-mana-value defect fixed for the other five tokens above |
| **Aswan Jaguar** (`past`) | Its row says the printed card reads their DECK only; the 1997 FAQ (§4) says *"pick a random type of creature that the player has in deck or graveyard"* — so the graveyard half may be original behaviour and only hand + battlefield are ours. Worth reading before the row is actioned |
| **Land Tax** (`4ed`) | Its row calls "up to three always fetches three" a simplification. The 1997 prompt `@LANDTAX` has FOUR strings — *"Pick up to 3 basic lands."* / *"Pick up to 2 more basic lands."* / *"Pick up to 1 more basic land."* / *"Opponent chose these basic lands:"* — i.e. the original really did ask, three times. The row is correct and now has its Tier 1 citation |

---

## 4. Two evidence sources this audit added

### 4a. The 1997 per-card prompt tables

`../shandalar-src/Program/prompts.txt`, `promptsX1.txt` and `promptsX2.txt`
hold **350 tagged prompt groups**, of which **301 map one-to-one onto a card
in our pool** by name. They are Tier 1: they are what the 1997 game put in
front of the player, and several of them state a targeting restriction
outright. The complete set of restriction lines is small enough to quote:

```
@ALI_FROM_CAIRO      Illegal target (prevent damage to controller of Ali).
@ANIMATE_DEAD        Illegal Target (not a creature).
@ARGIVIAN_BLACKSMITH Illegal damage card (damage on artifact creatures only).
                     Illegal damage card (must be same as first target).
@CHANNEL             Illegal amount (must be between 0 and life).
@COPY_ARTIFACT       Illegal target (didn't enter play as an artifact).
@CYCLOPEAN_TOMB      Illegal target land (type).
@DEATH_WARD          Illegal target (not dying).
@ELEPHANT_GRAVEYARD  Illegal target (not dying). / (not a pachyderm).
@FIREBALL            Illegal target (may only target once).
@GUARDIAN_EFFECT     Illegal target (damage must be on target of Guardian Angel).
@HEALING_SALVE       Illegal target (prevent damage to ONE target).
@MIRACLE_WORKER      Illegal target (not enchanting a creature).
                     Illegal target (not enchanting controller's creature).
@OASIS               Illegal target (damage type).
@PYRAMIDS            Illegal target (not dying). / (not enchanting a land).
@RECONSTRUCTION      Illegal target (type).
@ROCK_HYDRA          Illegal target (damage must be on Rock Hydra).
@SAVAEN_ELVES        Illegal target (not enchanting a land).
@TETRAVITE           Illegal target (tetravite not related to tetravus).
                     Illegal target (only one move per turn).
```

`@PYRAMIDS` is what turned the Pyramids finding from "the doc comment
disagrees with the code" into a settled one. `@MIRACLE_WORKER` and
`@SAVAEN_ELVES` confirm two cards we already had right, including the
"controller's creature" half. `@FIREBALL`'s *"may only target once"* is
Tier 1 confirmation of the CR 601.2c no-duplicate-targets rule the
2026-08 audit added. `@TETRAVITE`'s two lines describe restrictions
(a Tetravite belongs to ONE Tetravus; one move per turn) worth checking
when Tetravus's ledger row is next opened.

**Where the prompts disagree with the modern oracle, the project's standing
policy still applies: the Scryfall oracle wins** (the Jump ruling,
`docs/audit-vs-mage-go.md`). Three cases were found and NOT actioned:
`@ERHNAM_DJINN` *"Select opponent non-wall creature."* (oracle has no Wall
exclusion), `@ALADDIN` *"Select target opponent artifact."* (oracle has no
opponent restriction), and `@EARTH_BIND` *"Select target creature with
flying."* alongside the plain `@EARTHBIND` (the modern Earthbind may
enchant anything). Each is a 1997/oracle fork, not a bug.

### 4b. The 1997 FAQ that ships inside s30

`s30/shandalar-faq.txt` is Dana Huyler's *MicroProse Magic: The Gathering
FAQ v1.2, 5/7/97* — a contemporaneous community document, so secondary,
but it is the only prose description of the twelve **Astral** cards, whose
"oracle text" is itself a reconstruction of a set that was never printed on
cardboard. Read against our twelve `past/` implementations it agrees
everywhere it is specific, with one apparent conflict — it calls Orcish
Catapult's counters "-1/0" where our card (and Scryfall) say -0/-1. The
conflict resolves in our favour: `Program/Cards.dat` also reads
`Randomly distribute |X -0/-1 counters …`.

Its §5.4 is the more valuable half. It lists the 1997 game's own card-id
ranges, which is a direct statement of the original's pool:

```
cards 0-291   Alpha/Beta/Unlimited (fixed for 5th edition)
292-390       The Dark
391-465       Arabian Nights
466-550       Antiquities
551-859       Legends
860-871       the 12 Astral cards
893-898       cards from the 'book' expansion
```

Those id ranges are the same id space as `cards/data/dck_ids.txt`, the 370
ids this project harvested from an original install (Air Elemental = 0, the
Astral cards at 860-871). **The 'book' expansion range holds six ids** —
which is the six HarperPrism book promos, Nalathni Dragon included. See §5.

---

## 5. The one place s30 makes a card decision of its own: the pool

s30 builds its pool with `utils/update_cards_json.py`, whose defaults are:

```python
DEFAULT_EXCLUDED_NAMES: set[str] = {"Chaos Orb", "Shahrazad", "Word of Command"}
--sets   default: 2ed,4ed,arn,atq,past,phpr
```

Two results:

1. **The three excluded names are not in our pool either**, so there is
   nothing to reconcile — but the exclusion is worth knowing about as an
   `[s30]` decision, and it is a deliberate one (Chaos Orb is unplayable
   in software, Shahrazad needs a subgame, Word of Command needs to drive
   the opponent's turn).
2. **s30's shipped pool is 555 cards and ours is 556 for the same six
   sets. The difference is Nalathni Dragon**, and it is an artefact of the
   set filter rather than a decision: Nalathni Dragon is a 1994 DragonCon
   promo that Scryfall files outside the `phpr` book-promo set, so
   `--sets …,phpr` never sees it. **The 1997 game had six book-expansion
   cards** (FAQ §5.4, ids 893-898) and the six HarperPrism promos are
   Arena, Giant Badger, Mana Crypt, Nalathni Dragon, Sewers of Estark and
   Windseeker Centaur. **Our pool is right; s30's is one card short.** No
   change on our side; recorded so nobody "fixes" our pool to match.

s30 also does not ship Legends or The Dark at all — the *Duels of the
Planeswalkers* expansion, 341 of our files. That is a scope difference,
not a divergence.

---

## 6. A provenance correction

**`../shandalar-src/Program/Cards.dat` is NOT a 1997 artefact**, despite
living in `Program/` beside the genuine string tables. It contains
Necropotence, Force of Will, Brainstorm, Jester's Cap and Ice Floe, and its
rules text is modern oracle wording ("enters the battlefield", "converted
mana cost"), where the 1997 game printed "Summon", "comes into play" and
"bury". It is a **Manalink 3** card database — Tier 3.

`Provenance.md`'s standing rule is *"always the `Program/` copies of the
string tables"*; that rule is about `UIStrings.txt`, `prompts*.txt` and
`Text.res`, and it does not extend to `Cards.dat`. Recorded here so the
next reader does not cite it as evidence about 1997. (It is still useful as
a second Tier 3 opinion — that is how the Orcish Catapult question in §4b
was settled.)

---

## 7. Verified clean

Recorded so the next pass need not redo it.

- **Printed characteristics of all 897 cards** against the Scryfall
  snapshot: cost, types, supertypes, subtypes, P/T, keywords. Zero real
  mismatches (§1).
- **Every card's `.oracle()` string** against `cards/data/*.json`: no card
  in the pool is missing a printed sentence from its header. The only
  differences are deliberate older phrasings and reminder text.
- **The other three "Aura attached to X" cards** — Savaen Elves, Miracle
  Worker (including its "creature YOU control" half, which the 1997 prompt
  independently confirms) and Enchantment Alteration.
- **All seventeen `DIES` listeners** for the printed-vs-last-known-
  information read: only Soul Net and Dingus Egg were wrong.
- **All sixteen `BLOCKED` listeners** for trigger multiplicity: only
  Spitting Slug has the bare "becomes blocked" wording.
- **Time Elemental** ("target permanent that isn't enchanted" — the 1997
  prompt says the same and we enforce it), **Xenic Poltergeist**
  ("noncreature artifact"), **Drop of Honey** (live power, the tie broken by
  the controller's agent, no regeneration), **Stone Giant**, **Seeker**,
  **Elephant Graveyard**, **Royal Assassin**, **Grapeshot Catapult**,
  **Island of Wak-Wak**, **King Suleiman**, **Dwarven Warriors**,
  **Primal Clay**'s three shapes and **Urza's Avenger**'s four keywords —
  all checked against their 1997 prompts and correct.
- The seven per-slice sweeps additionally cleared, by name: Balance's APNAP
  passes, Berserk, Black Vise's locked-in victim, Clockwork Beast's counter
  cap, Creature Bond's LKI toughness, Darkpact's ante exchange, Drain Life's
  post-prevention cap, Fireball's division and surcharge, Forcefield,
  Gloom's live-colour tax, Island Sanctuary, Keldon Warlord, the
  land-retyping pass order (Kormus Bell / Evil Presence / Conversion /
  Cyclopean Tomb / Gaea's Liege), Titania's Song's layer position, Cursed
  Rack, Ashes to Ashes' distinct targets, Armageddon Clock's two ability
  copies, Abu Ja'far's post-mortem sweep, Damping Field's untap cap,
  Rocket Launcher's sickness gate, Transmute Artifact's empty search, and
  every per-turn flag's cleanup reset.

---

## 8. Ledger rows this pass would add (for the owner to merge)

`docs/simplified-cards.md` is owned by the fidelity-ledger agent right now,
so these are collected here rather than written into it. **This pass added
no new simplification** — every fix restored the printed behaviour — so
there is nothing to ADD. What §3b lists are AMENDMENTS to rows that already
exist, plus two cards that currently have neither marker nor row and
deserve one if they are not fixed:

| Card | Proposed row |
|---|---|
| Personal Incarnation | The `{0}` redirect moves the WHOLE damage event to the owner instead of the printed 1 point, because the engine's `damage_redirects` counter has no amount cap. Needs: a per-shield amount on the redirect. Benefits: the Incarnation's controller enormously — one free activation soaks any single hit |
| Enchanted Being | "Prevent all COMBAT damage … by enchanted creatures" is implemented as all damage, because `cur_damage_immunity` has no combat flag. Needs: a combat-only flag on the immunity list (mage-go has `WithCombatOnly()`). Benefits: the Being's controller, against an enchanted pinger |
