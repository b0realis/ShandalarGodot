class_name EffectIntent
extends RefCounted
## What a spell's or an activated ability's effect list DOES, read once and
## summed into a handful of numbers the AI can reason about: "3 damage to
## the target and 2 to me", "draws a card", "taps something", "+3/+3".
##
## Ported from mage-go's `intrinsicAbilityQuality` and `bestXValue`
## (`mage-go/pkg/mage/interactive/ai/heuristic/heuristic.go:1074-1232`),
## which classify an ability by what its effects do rather than by which
## card it is on — the reason s30's AI activates a Rod of Ruin it has never
## seen a special case for. Here the classification is by EFFECT CLASS, so
## every card built from the shared effect vocabulary (docs/adding-cards.md)
## is understood for free, and the two tables of card-local effects below
## cover the shapes the shared vocabulary cannot express.
##
## Read-only: nothing here mutates the game, and nothing here holds a
## CardInstance beyond the call that built it.

## Fixed damage to the chosen target (0 = the effects deal none).
var damage: int = 0

## The damage is the spell's X (Fireball, Disintegrate, Rod-of-Ruin-with-X).
var damage_uses_x: bool = false

## Damage SPLIT among the targets (Fireball) rather than dealt to each.
var damage_divided: bool = false

## Damage the CASTER takes as a side effect (Orcish Artillery 3, Psionic
## Blast 2). The price mage-go's `lifeCost*15/life` term charges.
var self_damage: int = 0

## Targeted destroy / exile / "removal-shaped" card-local effect.
var removes: bool = false

## The removal says "can't be regenerated" (Terror) — a shield is no answer.
var removal_ignores_regeneration: bool = false

## Targeted bounce (Unsummon).
var bounces: bool = false

## Targeted tap (Icy Manipulator, Twiddle's main use).
var taps: bool = false

## Targeted untap.
var untaps: bool = false

## Cards drawn (0 = none); [member draws_use_x] when the count is X.
var draws: int = 0
var draws_use_x: bool = false

## Targeted or self pump. [member pump_self] for the firebreathing shape;
## [member pump_uses_x] when the power bonus is the spell's X (Howl from
## Beyond) — [member pump_power] then holds only the printed part.
var pump_power: int = 0
var pump_toughness: int = 0
var pump_self: bool = false
var pumps: bool = false
var pump_uses_x: bool = false

## Every keyword the pumps grant (Teleport's UNBLOCKABLE, Jump's FLYING),
## summed the way the stat bonuses are. A pump that grants a keyword and
## no stats is invisible to every reading of [member pump_power] and
## [member pump_toughness]; this is where such a card says what it does.
var pump_keywords: Array[int] = []

## Regeneration shield (Drudge Skeletons, Death Ward).
var regenerates: bool = false

## Life gained by the controller.
var life_gain: int = 0

## Mana produced by a SPELL (Dark Ritual) — worth nothing on its own.
var adds_mana: bool = false

## Counters a spell.
var counters: bool = false

## A whole-combat Fog.
var fogs: bool = false

## A sweeper effect (Wrath of God, Earthquake, Nevinyrral's Disk), kept
## whole because its worth is a board calculation, not a number.
var sweeper: EffectBase = null

## "This permanent becomes an N/N creature" (Mishra's Factory, Jade
## Statue), kept whole for the same reason a sweeper is: its worth is a
## COMBAT calculation — what the body would do this turn — not a number
## that can be summed here.
var animates: AnimateSelfEffect = null

## Cards the TARGET player is made to discard (Disrupting Scepter's one,
## Rag Man's one at random). -1 means the count is the spell's X (Mind
## Twist, Nebuchadnezzar). See [method _aimed_discard] for why this is
## read the way it is.
var discards: int = 0

## Something the reader has no model for (a card-local effect outside the
## table). The AI treats an unknown TARGETED effect as removal-shaped —
## the common case in this pool — and an unknown untargeted one as a
## card worth its cost.
var unknown: bool = false

## The first targeting effect's spec (null when nothing targets).
var target_spec: TargetSpec = null

## THE WINDOW SHAPES — what a spell whose rider keeps it out of its
## caster's own main phase DOES in the moment the rider names, for the
## card-local effects of that kind (see [constant WINDOW_SHAPES]). NONE
## for everything else, including every window card the AI has no board
## reading for. (`Shape` rather than `Window`: that name is a Node class.)
enum Shape {
	NONE,
	STOPS_ATTACKS,      ## Festival: no creature attacks this turn
	FORCES_ATTACKS,     ## Siren's Call: theirs attack this turn or die
	UNTAPS_LANDS,       ## Reset: every land we control untaps
	STEALS_ATTACKER,    ## Disharmony: their attacker leaves combat and is ours for the turn
	CONSCRIPTS_BLOCKER, ## Blaze of Glory: one defender blocks every attacker it can
	PULLS_BLOCKER,      ## False Orders: a defender leaves combat and re-blocks where we say
}
var window: int = Shape.NONE


# ---------------------------------------------------------------- the table --
# Card-local effects (`class X extends EffectBase` inside a card file) that
# the effect vocabulary cannot express and that this pool's shipped decks
# actually cast. Keyed by CARD NAME because the classes are card-local and
# have no global name to test against; each row states what the reader
# would have read had the card used the shared effects. Adding a card here
# is a one-line change; a card missing from it is simply treated as
# removal-shaped (targeted) or as a plain spell (untargeted), never wrong,
# only imprecise.
const CARD_LOCAL := {
	"Orcish Artillery": {"damage": 2, "self_damage": 3},
	"Psionic Blast": {"damage": 4, "self_damage": 2},
	"Fireball": {"damage_x": true, "divided": true},
	"Chain Lightning": {"damage": 3},
	"Swords to Plowshares": {"removes": true, "ignores_regeneration": true},
	"Drain Life": {"damage_x": true},
	"Disintegrate": {"damage_x": true, "ignores_regeneration": true},
	# "You may tap OR untap target ..." — the mode is chosen on resolution,
	# so the reader records both and the AI's tap policy decides which
	# reading it is buying ([method AiPlayer._size_tap]). Without this row
	# Twiddle read as `unknown`, which the picker treats as removal-shaped
	# and aims at the enemy's most valuable permanent — tapped or not.
	"Twiddle": {"taps": true, "untaps": true},
}

# THE WINDOW TABLE (2026-09-06). The cards whose "Cast this spell only ..."
# rider leaves them NO legal moment in their caster's own main phase —
# the dead-card sweep's class 1 (docs/ROADMAP.md) — are card-local
# effects to a card, and the question the AI has to answer about them is
# not "what does it do to its target" but "what does it do to THE COMBAT
# it is cast into", which no flag above expresses. Each row names that
# shape; [method AiPlayer._window_worth] prices the shape from the board
# it is looking at and never the name.
#
# A SECOND TABLE rather than a "window" key in the one above, because a
# row in CARD_LOCAL makes the reader stop calling the effect `unknown`,
# and these effects ARE unknown to every reading that word gates — the
# harm reading, the target picker, the card's plain worth. Only the
# window caster reads this column, and it must be the only thing that
# changes when a card is added here.
#
# Camouflage is deliberately absent: what it does is a coin flip the
# defender half-controls (they choose the piles, the deal is random), and
# a one-ply board reading cannot price a coin flip honestly — the same
# rule that keeps Orcish Catapult in hand. Teleport is not a row
# either: it is a PumpEffect that grants UNBLOCKABLE and no stats, so the
# reader sees it structurally through [member pump_keywords].
const WINDOW_SHAPES := {
	"Festival": Shape.STOPS_ATTACKS,
	"Siren's Call": Shape.FORCES_ATTACKS,
	"Reset": Shape.UNTAPS_LANDS,
	"Disharmony": Shape.STEALS_ATTACKER,
	"Blaze of Glory": Shape.CONSCRIPTS_BLOCKER,
	"False Orders": Shape.PULLS_BLOCKER,
}


## Read [param effects] (a spell's spell_effects, one mode's effects, or an
## ability's effects) into an intent. [param card_name] keys the
## card-local table.
static func read(effects: Array, card_name: String = "") -> EffectIntent:
	var intent := EffectIntent.new()
	var note: Dictionary = CARD_LOCAL.get(card_name, {})
	intent.window = int(WINDOW_SHAPES.get(card_name, Shape.NONE))
	for e in effects:
		if intent.target_spec == null and e.target_spec != null:
			intent.target_spec = e.target_spec
		if e is DamageEffect:
			if e.controller_mode:
				intent.self_damage += e.amount
			elif e.use_x:
				intent.damage_uses_x = true
			else:
				intent.damage += e.amount
		elif e is DestroyEffect or e is ExileEffect:
			intent.removes = true
			if e is DestroyEffect and not e.can_regenerate:
				intent.removal_ignores_regeneration = true
			if e is ExileEffect:
				intent.removal_ignores_regeneration = true
		elif e is ReturnToHandEffect:
			intent.bounces = true
		elif e is TapEffect:
			intent.taps = true
		elif e is UntapEffect:
			intent.untaps = true
		elif e is DrawEffect:
			if e.use_x:
				intent.draws_use_x = true
			else:
				intent.draws += e.count
		elif e is PumpEffect:
			intent.pumps = true
			intent.pump_power += e.power
			intent.pump_toughness += e.toughness
			if e.self_mode:
				intent.pump_self = true
			if e.use_x_power:
				intent.pump_uses_x = true
			for keyword in e.granted_keywords:
				if not intent.pump_keywords.has(keyword):
					intent.pump_keywords.append(keyword)
		elif e is RegenerateEffect:
			intent.regenerates = true
		elif e is GainLifeEffect:
			intent.life_gain += e.amount
		elif e is AddManaEffect:
			intent.adds_mana = true
		elif e is CounterEffect:
			intent.counters = true
		elif e is PreventCombatDamageEffect:
			intent.fogs = true
		elif e is DestroyAllEffect or e is DamageAllEffect:
			intent.sweeper = e
		elif e is AnimateSelfEffect:
			intent.animates = e
		elif e is MassPumpEffect or e is SearchLibraryEffect \
				or e is ReturnFromGraveyardEffect or e is PreventDamageEffect \
				or e is PreventDamageShieldEffect or e is MillEffect:
			pass   # priced elsewhere (card_value); nothing here to sum
		elif note.is_empty():
			intent.unknown = true
			# ...but an AIMED DISCARD says so in its own description, and
			# an unknown effect that says so is still read for that one
			# fact. `unknown` deliberately STAYS set: the harm reading and
			# the target picker keep the behaviour they already had, and
			# only the ability scorer consults [member discards].
			var stripped := _aimed_discard(e)
			if stripped != 0:
				intent.discards = -1 if stripped < 0 or intent.discards < 0 \
					else intent.discards + stripped
	# The table overrides what the reader could not see.
	if not note.is_empty():
		intent.damage += int(note.get("damage", 0))
		intent.self_damage += int(note.get("self_damage", 0))
		if bool(note.get("damage_x", false)):
			intent.damage_uses_x = true
		if bool(note.get("divided", false)):
			intent.damage_divided = true
		if bool(note.get("removes", false)):
			intent.removes = true
		if bool(note.get("ignores_regeneration", false)):
			intent.removal_ignores_regeneration = true
		if bool(note.get("taps", false)):
			intent.taps = true
		if bool(note.get("untaps", false)):
			intent.untaps = true
	return intent


## THE AIMED DISCARD, read from the effect's own one-line description.
##
## There is no shared `DiscardEffect` in this vocabulary — every discard in
## the pool is a `class X extends EffectBase` inside its own card file — so
## the reader has nothing to test `is` against, exactly the situation
## [constant CARD_LOCAL] exists for. What it has instead is a signal every
## effect already provides: [method EffectBase.describe] is part of the
## effect contract, the duel log and the UI both read it, and the seven
## aimed discards in this pool all state themselves the same way. Reading
## the card's own line is the precedent [method AiPlayer._is_counterspell]
## set, for the same reason and with the same limits.
##
## THE "TARGET PLAYER" PREFIX IS LOAD-BEARING, not decoration. It is what
## separates an aimed discard (Disrupting Scepter, Rag Man, Gwendlyn Di
## Corci, Wand of Ith, Nebuchadnezzar, Mind Twist, Amnesia) from a
## SYMMETRICAL one (Wheel of Fortune, Mind Bomb — "each player discards")
## and from one WE pay for (Contract from Below's "discards your hand",
## Recall's "discards X cards and recalls that many"). Getting that wrong
## would have the AI emptying its own hand every turn, so the test is
## deliberately narrow: an effect that does not announce a target player
## is simply not read, and stays the plain `unknown` it always was.
##
## Returns the number of cards, -1 when the count is the spell's X, or 0
## when this is not an aimed discard.
static func _aimed_discard(e: EffectBase) -> int:
	if e.target_spec == null or e.target_spec.kind != TargetSpec.Kind.PLAYER:
		return 0
	var line := e.describe().to_lower()
	if not (line.begins_with("target player") or line.begins_with("target opponent")):
		return 0
	if not line.contains("discard"):
		return 0
	return -1 if line.contains(" x ") else 1


## Does this intent hurt what it targets? Mirrors the classification
## [method AiPlayer._is_harmful] has always used, from the summed reading.
func is_harmful() -> bool:
	if damage > 0 or damage_uses_x or removes or bounces or taps:
		return true
	if draws > 0 or draws_use_x or pumps or life_gain > 0 or untaps or regenerates:
		return false
	return unknown   # removal-shaped by default


## Damage this intent would deal to one target at X = [param x_value]
## (0 when it deals none).
func damage_at(x_value: int) -> int:
	if damage_uses_x:
		return x_value + damage
	return damage


## Would the damage at X = [param x_value] finish [param victim] as it
## stands now (marked damage counted, live toughness read)? Protection and
## prevention are the target spec's business, not this reader's.
func kills(victim: CardInstance, x_value: int) -> bool:
	if victim == null or not victim.is_creature():
		return false
	var needed: int = victim.cur_toughness - victim.damage
	if damage_at(x_value) >= needed and needed > 0:
		return true
	if removes or bounces:
		return true
	return false


## A creature-answering shape — what "removal" means to the response
## logic: kills a creature outright, or removes it from the board.
func answers_creatures() -> bool:
	return removes or bounces or damage > 0 or damage_uses_x


## Is this effect's WHOLE job to tap (or untap) what it hits — Twiddle,
## Word of Binding, an Icy Manipulator's ability?
##
## Such an effect has no value of its own. Two identical casts differ by an
## order of magnitude depending on WHOSE permanent it hits and WHAT STATE
## that permanent is in: tapping an untapped blocker before we swing wins a
## race, tapping a permanent that is already tapped does nothing at all,
## and untapping the enemy's creature is a gift. Everything else the AI
## targets can be priced by the victim's worth alone; this cannot, so the
## picker routes it through the tap policy instead
## ([method AiPlayer._tap_denies_something], [method AiPlayer._size_tap]).
func is_tap_utility() -> bool:
	if not taps or target_spec == null:
		return false
	return damage == 0 and not damage_uses_x and self_damage == 0 \
		and not removes and not bounces and draws == 0 and not draws_use_x \
		and not pumps and not regenerates and life_gain == 0 \
		and not adds_mana and not counters and not fogs and sweeper == null


# ------------------------------------------------------------ aura aim --
#
# WHICH SIDE OF THE TABLE AN AURA BELONGS ON.
#
# An Aura is the one card shape whose target side cannot be read off its
# effects, because an Aura HAS no spell effects: it is cast at a spec, it
# enters attached, and everything it does lives in Callables — a
# StaticAbility's `apply`, a TriggeredAbility's handler — that this reader
# cannot look inside. Until 2026-09-04 the AI answered the question with a
# four-name list inlined in `AiPlayer._is_harmful` ("Weakness", "Paralyze",
# "Warp Artifact", "Wanderlust"); every one of the OTHER 73 auras in the
# pool therefore counted as helpful and was aimed at the AI's own board.
# That is why an AI enchanted its own Island with Psychic Venom and then
# took 2 damage every time it tapped for mana.
#
# So the aim is stated here, as data, in one place, with the same contract
# CARD_LOCAL has: structural signals first (a card that already SAYS it
# steals, reanimates or grants protection needs no row), then the explicit
# hostile set. `tests/ai/test_ai_targeting_2026_09_04.gd` walks the whole
# registry and fails on any aura it does not recognise, so a new aura
# cannot slip in unclassified the way these 73 did.

## Which side of the table an aura's host should be on.
enum Aim {
	FRIENDLY,   ## enchant one of OURS (a pump, a ward, an evasion grant)
	HOSTILE,    ## enchant one of THEIRS (a curse, a tax, a steal)
}

## Auras whose host's controller is the VICTIM. Everything not named here
## and not settled structurally is a friendly aura — the safe default for
## the shape that dominates the pool (pumps, keyword grants, wards), and
## the one the coverage test keeps honest.
##
## Three of these deserve their reason on the record, because they read the
## other way at a glance:
##  * "Creature Bond" is a Fling on our own creature and a delayed Lava Axe
##    on theirs. A one-ply AI cannot plan the sacrifice half, so it takes
##    the half that needs no plan.
##  * "Gaseous Form" prevents combat damage BOTH ways. On our creature that
##    is a wall that cannot hit back; on their best creature it is that
##    creature removed from combat entirely, which is strictly the better
##    of the two.
##  * "Immolation" (+2/-2) looks like a red pump and is a red removal spell.
##    Aimed at our own board it can KILL what it enchants outright (a 2/2
##    becomes a 4/0 and the toughness SBA sweeps it, CR 704.5f); aimed at
##    theirs the worst case is a bigger, more fragile enemy creature. The
##    downside is not symmetric, so it points across the table.
const AURA_HOSTILE := {
	"Artifact Possession": true,   # 2 damage to the artifact's controller
	"Backfire": true,              # their creature's damage rebounds on them
	"Blight": true,                # destroys the land it enchants
	"Brainwash": true,             # can't attack unless its controller pays {3}
	"Creature Bond": true,         # damage to the dead creature's controller
	"Curse Artifact": true,        # 2 a turn unless they sacrifice it
	"Cursed Land": true,           # 1 damage each of their upkeeps
	"Demonic Torment": true,       # can't attack, deals no combat damage
	"Earthbind": true,             # 2 damage and no more flying
	"Erosion": true,               # destroys the land unless they pay
	"Evil Presence": true,         # colour screw
	"Feedback": true,              # 1 damage each of their upkeeps
	"Gaseous Form": true,          # see the note above
	"Immolation": true,            # see the note above
	"Imprison": true,              # taxes their taps and their attacks
	"Kudzu": true,                 # destroys the land when it is tapped
	"Paralyze": true,              # taps it and holds it down
	"Phantasmal Terrain": true,    # colour screw
	"Power Leak": true,            # 2 a turn unless they pay
	"Psychic Venom": true,         # 2 damage every time the land taps
	"Relic Bind": true,            # its own spec says "an opponent controls"
	"Spirit Shackle": true,        # -0/-2 every time it taps
	"Takklemaggot": true,          # -0/-1 a turn, then moves on
	"Tangle Kelp": true,           # holds an attacker down
	"Venarian Gold": true,         # taps it and holds it down for X turns
	"Wanderlust": true,            # 1 damage each of their upkeeps
	"Warp Artifact": true,         # 1 damage each of their upkeeps
	"Weakness": true,              # -2/-1
}


## Which side of the table [param data]'s host should be on. Not a
## question about legality — the spec still has the last word — only about
## which battlefield the picker should shop on first.
static func aura_aim(data: CardData) -> int:
	if data == null or not data.is_aura():
		return Aim.FRIENDLY
	# Structural signals: a card that already states this about itself
	# never needs a row in the table.
	if data.aura_steals:
		return Aim.HOSTILE          # Control Magic, Steal Artifact
	if data.aura_reanimates:
		return Aim.FRIENDLY         # Animate Dead — the host is in a graveyard
	if data.aura_grants_protection != 0:
		return Aim.FRIENDLY         # the ward cycle
	return Aim.HOSTILE if AURA_HOSTILE.has(data.card_name) else Aim.FRIENDLY


## Is [param data] an aura this reader has an opinion about, rather than
## one that merely fell through to the friendly default? The coverage test
## uses this; nothing in the AI's hot path does.
static func aura_is_classified(data: CardData) -> bool:
	if data == null or not data.is_aura():
		return false
	return data.aura_steals or data.aura_reanimates \
		or data.aura_grants_protection != 0 or AURA_HOSTILE.has(data.card_name)
