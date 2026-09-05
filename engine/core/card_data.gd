class_name CardData
extends RefCounted
## The immutable, printed definition of a card — name, cost, types, stats,
## rules text, and its attached behavior (effects and abilities).
##
## One CardData exists per card NAME (created once by that card's file in
## cards/sets/ and stored in the CardRegistry). Runtime copies of a card in
## a game are CardInstance objects, which point back at their CardData and
## never mutate it.
##
## Card files build a CardData with the fluent builder methods below, e.g.:
## [codeblock]
## func build() -> CardData:
##     return CardData.new("Lightning Bolt", "{R}", Mtg.CardType.INSTANT) \
##         .spell(DamageEffect.new(3).any_target()) \
##         .oracle("Lightning Bolt deals 3 damage to any target.")
## [/codeblock]
## Every builder method returns [code]self[/code] so calls chain. See
## docs/adding-cards.md for the full card-authoring guide.

## Card name — the registry key. Must exactly match the printed name.
var card_name: String

## Parsed mana cost. Lands have an empty cost (they are played, not cast).
var cost: ManaCost

## Bitmask of Mtg.CardType flags.
var types: int = 0

## Bitmask of Mtg.Supertype flags (BASIC, LEGENDARY).
var supertypes: int = 0

## Subtype strings, lowercase ("angel", "aura", "plains"...). Used by
## effects that filter on creature type and by basic-land identification.
var subtypes: Array[String] = []

## Printed power/toughness (creatures only; 0/0 otherwise).
var power: int = 0
var toughness: int = 0

## Printed keyword abilities (Array of Mtg.Keyword values).
var keywords: Array[int] = []

## Oracle rules text — REQUIRED on every card. Shown by UIs and used as
## living documentation: tests compare behavior against this text.
var oracle_text: String = ""

## Set code of the FOLDER this card's file lives in — a Scryfall code
## ("2ed", "4ed", "arn", "atq", "leg", "drk", "past", "phpr"), filled in by
## the CardRegistry loader. It is NOT the card's original printing: ask
## CardRegistry.originally_printed_in() for that (Millstone is an
## Antiquities card that ships in cards/sets/4ed/).
var set_code: String = ""

## THE ILLUSTRATOR, as the printed card credits them: `Duel.hlp`'s "Parts
## of the Card" topic numbers the twelve labelled parts of the enlarged
## card and **part 6 is `Artist`**, which the card face itself prints in
## its bottom-left corner as `Illus. <name>`.
##
## Like [member set_code] it is filled in by the `CardRegistry` loader from
## the Scryfall snapshot in `cards/data/`, NOT written into the card files
## — a credit is metadata about a printing, not behaviour, and putting it
## in `build()` would mean touching every card in the pool to record
## something no rule ever reads.
##
## EMPTY IS LEGAL and must render as nothing at all (never `Illus. `): an
## older `cards/data/` snapshot has no artists in it, and a card the
## snapshot does not name gets no credit rather than a broken one.
var artist: String = ""

## For instants/sorceries: the effects that run, in order, when the spell
## resolves. Each effect may demand targets (see EffectBase.target_spec).
var spell_effects: Array[EffectBase] = []

## Activated abilities usable while the card is on the battlefield.
var activated_abilities: Array[ActivatedAbility] = []

## Triggered abilities that listen for events while on the battlefield.
var triggered_abilities: Array[TriggeredAbility] = []

## Static abilities contributing continuous effects while on the battlefield.
var static_abilities: Array[StaticAbility] = []

## Triggered abilities that listen while this card is in a GRAVEYARD
## (Nether Shadow's upkeep crawl). Only the turn-based events —
## UPKEEP_START and END_STEP_START — reach graveyard cards, which is every
## timing the 1997 pool uses and keeps the dispatcher's hot path untouched.
var graveyard_triggers: Array[TriggeredAbility] = []

## Triggered abilities that listen while this card is in EXILE — the
## sibling of [member graveyard_triggers], and reached by the same
## turn-based crawl (UPKEEP_START / END_STEP_START only), so the
## dispatcher's hot path is untouched. All Hallow's Eve, which exiles
## ITSELF with counters and ticks them down from there, is the pool's only
## user.
var exile_triggers: Array[TriggeredAbility] = []

## Fluent: add an ability that listens from EXILE.
func with_exile_trigger(ability: TriggeredAbility) -> CardData:
	exile_triggers.append(ability)
	return self

## Append a graveyard-listening triggered ability.
func with_graveyard_trigger(ability: TriggeredAbility) -> CardData:
	graveyard_triggers.append(ability)
	return self

## Mana abilities (tap for mana). Kept separate from activated_abilities
## because mana abilities do not use the stack (CR 605.3b).
var mana_abilities: Array[ManaAbility] = []

## For Auras: what the aura may enchant. Non-null marks the card as an aura;
## it is cast targeting this spec and enters attached to that target.
var aura_target: TargetSpec = null

## Control-Magic-style aura: while attached, the AURA's controller
## controls the host (control changes on attach, reverts to the owner
## when the aura leaves — both handled engine-side in MtgGame).
var aura_steals: bool = false

## MODAL spell: choose-one modes, each {label: String, effects: Array}.
## Non-empty marks the card modal; spell_effects is then unused. The mode
## index travels with the cast (MtgGame.cast_spell's mode argument).
var modes: Array = []

## AI's mode chooser for modal cards: Callable(game, pid) -> int.
## Unset = mode 0. Cards ship their own judgment (see red_elemental_blast).
var ai_mode_picker: Callable = Callable()

## COST MODIFIERS this permanent radiates while on the battlefield
## (Gloom's tax, Mana Matrix's discount). Optional keys:
##   "spell":   Callable(game, caster_pid, data: CardData,
##                       modifier: CardInstance) -> int
##   "ability": Callable(game, caster_pid, source: CardInstance,
##                       modifier: CardInstance) -> int
## Each returns extra GENERIC mana added to the cost (negative reduces it).
## MtgGame sums across every battlefield permanent that carries one at
## cast/activation time, passing each callback ITS OWN source as
## [code]modifier[/code] — that is how "spells YOU cast cost less" knows
## whose spells it means, and why two opposing Matrices no longer discount
## each other's.
var cost_modifier: Dictionary = {}

## Animate-Dead-style aura: it targets a creature card in a GRAVEYARD;
## resolving returns that card to the battlefield under the aura
## controller's control and attaches; when the aura leaves, the creature
## is destroyed (the modern oracle's behavior). Engine-side in MtgGame.
var aura_reanimates: bool = false

## For protection-granting auras (the Wards): the colors THIS aura grants
## its host protection from. The aura-vs-protection state-based action
## ignores these colors for this aura only — the printed "This effect
## doesn't remove this Aura" rider (White Ward survives its own grant;
## any OTHER pro-white source still evicts it, CR 702.16d). Set by
## [method grants_host_protection], which also installs the granting
## static ability.
var aura_grants_protection: int = 0

## Protection from colors, as an Mtg.ManaColor bitmask (0 = none).
## Grants the full DEBT bundle (CR 702.16): can't be Damaged by, Enchanted
## by, Blocked by, or Targeted by sources of these colors. Enforced in
## MtgGame.deal_damage, check_state_based_actions, CombatState, and
## TargetSpec.is_legal respectively.
var protection_from: int = 0

## Landwalk land types (lowercase subtype strings, e.g. ["swamp"]).
## A creature with landwalk can't be blocked while the defending player
## controls a land of that type (CR 702.14) — checked in CombatState.
var landwalk: Array[String] = []

## Subtypes that can't block this creature (Juggernaut's "can't be blocked
## by Walls" → ["wall"]). Checked in CombatState.block_illegality.
var cant_be_blocked_by: Array[String] = []

## "This creature can't block creatures with power N or greater"
## (Ironclaw Orcs → 2). 0 = no restriction. CombatState checks the
## attacker's LIVE power against it.
var cant_block_power_ge: int = 0

## "This creature can't be blocked by creatures with power N or greater"
## (Amrou Kithkin → 3). 0 = no restriction. CombatState checks the
## blocker's LIVE power against it.
var cant_be_blocked_by_power_ge: int = 0

## "This creature can block an ADDITIONAL creature each combat"
## (Two-Headed Giant of Foriys → 1). 0 = the one attacker every blocker
## may block (CR 509.1b); -1 = any number. MtgGame.declare_blockers checks
## the LIVE value ([member CardInstance.cur_extra_blocks]).
var extra_blocks: int = 0

## "This creature can't be the target of Aura spells" (Bartel Runeaxe,
## Tetsuo Umezawa). Checked by TargetSpec.is_legal when the targeting
## source is an Aura spell on the stack — abilities and non-aura spells
## are unaffected.
var cant_be_aura_target: bool = false

## RAMPAGE N (CR 702.23, Legends' signature keyword): "Whenever this
## creature becomes blocked, it gets +N/+N until end of turn for each
## creature blocking it beyond the first." 0 = no rampage. Applied by
## MtgGame right after blockers are declared, as an until-end-of-turn
## pump — so a second combat this turn (extra-turn shenanigans aside)
## keeps the bonus, exactly as printed.
var rampage: int = 0

## "If this creature would die, return it to its owner's hand instead"
## (Firestorm Phoenix). A REPLACEMENT effect: MtgGame bounces it and no
## dies-trigger fires.
var dies_returns_to_hand: bool = false

## The rider on the line above: "Until that player's next turn, that
## player plays with that card revealed in their hand and can't play it"
## (Firestorm Phoenix). MtgGame stamps CardInstance.hand_lock_turn /
## revealed_in_hand on the returned card.
var dies_to_hand_locks: bool = false

## "You may choose not to untap this permanent during your untap step"
## (Rubinia Soulsinger, Old Man of the Sea, Preacher, Phyrexian Gremlins,
## Ashnod's Battle Gear). The controller is asked in their untap step
## (MtgGame._untap_step, `@ISLAND_FISH_JASCONIUS`'s "Untap <name>." /
## "Don't untap."); the heuristic keeps the permanent tapped while it is
## sustaining something (a control leash or a remembered "for as long as
## this remains tapped" effect) and untaps it otherwise.
var may_skip_untap: bool = false

## "If you would begin your turn while this artifact is tapped, you may
## skip that turn instead. If you do, untap this artifact." (Time Vault.)
## A CR 614.10 replacement of the turn's BEGINNING: MtgGame._begin_turn
## asks its controller before the untap step (`@TIME_VAULT`: "Play this
## turn." / "Skip this turn to untap."), and a skipped turn is proceeded
## past as though it did not exist (CR 500.9) — no untap, upkeep, draw or
## cleanup step. One skipped turn untaps ONE such permanent (CR 616.1).
var skips_turn_to_untap: bool = false

## "This permanent enters with N <kind> counters on it" (Triskelion's
## three +1/+1, Clockwork Beast's seven +1/+0, Rasputin's seven dream
## counters). Kind -> count; applied by MtgGame as the permanent enters.
var enters_with_counters: Dictionary = {}

## "This permanent enters the battlefield tapped." (Nevinyrral's Disk.)
var enters_tapped: bool = false

## "Can't attack unless defending player controls a [land type]"
## (Sea Serpent's island clause). Lowercase land subtype, "" = no clause.
var attack_needs_defender_land: String = ""

## "When you control no [land type], sacrifice this" (Sea Serpent,
## Pirate Ship, Dandan, Merchant Ship). Lowercase land subtype,
## "" = no clause. Enforced as a state-based action in MtgGame — the
## printed wording is a state trigger, and in this engine the two are
## indistinguishable (both fire the moment the condition becomes true).
var sacrifice_if_no_land_type: String = ""

## "Cast this spell only ..." — a TIMING rider on a spell (Reset's "only
## during an opponent's turn after their upkeep step", Berserk's "only
## before the combat damage step", Teleport's "only during the declare
## attackers step"). A predicate
## [code]func(game: MtgGame, pid: int) -> String[/code] returning "" when
## the cast is legal, or a human-readable refusal. Checked by
## MtgGame.cast_spell before any cost is paid — and consulted by the AI,
## so it never plans a cast the engine will bounce. Unset = the ordinary
## instant/sorcery timing rules only. Set it with [method castable_only_when].
var cast_condition: Callable = Callable()

## Fluent: attach a "Cast this spell only ..." rider.
func castable_only_when(cb: Callable) -> CardData:
	cast_condition = cb
	return self


## The general form of the clause above: "When <condition>, sacrifice
## this permanent" (Jihad's "when the chosen player controls no nontoken
## permanents of the chosen color"). A predicate
## [code]func(game: MtgGame, source: CardInstance) -> bool[/code] that
## returns true when the permanent must go. Unset = no such clause.
## Enforced as a state-based action in MtgGame, like its land-typed
## sibling; set it with [method sacrifices_when].
var sacrifice_condition: Callable = Callable()

## Fluent: attach a "sacrifice this when <condition>" clause.
func sacrifices_when(cb: Callable) -> CardData:
	sacrifice_condition = cb
	return self


func _init(p_name: String = "", p_cost: String = "", p_types: int = 0) -> void:
	card_name = p_name
	cost = ManaCost.parse(p_cost)
	types = p_types


# ---------------------------------------------------------------- builders --

## Set printed power/toughness. Creatures only.
func pt(p_power: int, p_toughness: int) -> CardData:
	power = p_power
	toughness = p_toughness
	return self

## Add printed keywords, e.g. .with_keywords([Mtg.Keyword.FLYING]).
func with_keywords(list: Array) -> CardData:
	for k in list:
		keywords.append(k)
	return self

## Add supertypes (Mtg.Supertype flags OR'd together).
func with_supertypes(mask: int) -> CardData:
	supertypes |= mask
	return self

## Add subtype strings (stored lowercase).
func with_subtypes(list: Array) -> CardData:
	for s in list:
		subtypes.append(String(s).to_lower())
	return self

## Set the oracle text. Required — the registry warns on cards without it.
func oracle(text: String) -> CardData:
	oracle_text = text
	return self

## Append a resolution effect (instants/sorceries).
func spell(effect: EffectBase) -> CardData:
	spell_effects.append(effect)
	return self

## Append an activated ability.
func activated(ability: ActivatedAbility) -> CardData:
	activated_abilities.append(ability)
	return self

## Append a triggered ability.
func triggered(ability: TriggeredAbility) -> CardData:
	triggered_abilities.append(ability)
	return self

## Append a static ability.
func static_ability(ability: StaticAbility) -> CardData:
	static_abilities.append(ability)
	return self

## Append a mana ability (tap-for-mana).
func mana(ability: ManaAbility) -> CardData:
	mana_abilities.append(ability)
	return self

## Mark this card as an Aura enchanting [param spec] (also adds the "aura"
## subtype so filters can find it).
func enchants(spec: TargetSpec) -> CardData:
	aura_target = spec
	if not subtypes.has("aura"):
		subtypes.append("aura")
	return self

## Grant protection from the colors in [param color_mask] (Mtg.ManaColor
## flags OR'd together).
func with_protection_from(color_mask: int) -> CardData:
	protection_from |= color_mask
	return self

## Grant landwalk of the given land types (lowercase strings).
func with_landwalk(land_types: Array) -> CardData:
	for t in land_types:
		landwalk.append(String(t).to_lower())
	return self

## Declare subtypes that can't block this creature (lowercase strings).
func with_cant_be_blocked_by(subtype_list: Array) -> CardData:
	for t in subtype_list:
		cant_be_blocked_by.append(String(t).to_lower())
	return self

## "Can't block creatures with power [threshold] or greater" (Ironclaw Orcs).
func with_cant_block_power_ge(threshold: int) -> CardData:
	cant_block_power_ge = threshold
	return self

## "Can't be blocked by creatures with power [threshold] or greater"
## (Amrou Kithkin).
func with_cant_be_blocked_by_power_ge(threshold: int) -> CardData:
	cant_be_blocked_by_power_ge = threshold
	return self

## Fluent: this creature may block [param n] attackers beyond the first
## (-1 = any number). Two-Headed Giant of Foriys.
func with_extra_blocks(n: int) -> CardData:
	extra_blocks = n
	return self

## Mark the card as untargetable by Aura spells.
func with_no_aura_targeting() -> CardData:
	cant_be_aura_target = true
	return self

## Grant rampage [param n] (see [member rampage]).
func with_rampage(n: int) -> CardData:
	rampage = n
	return self

## Mark the card as returning to hand instead of dying. With
## [param locked_until_next_turn] the returned card is also revealed in
## its owner's hand and can't be played until that player's next turn
## (Firestorm Phoenix's full text).
func with_dies_to_hand(locked_until_next_turn := false) -> CardData:
	dies_returns_to_hand = true
	dies_to_hand_locks = locked_until_next_turn
	return self

## Mark the card as "you may choose not to untap this permanent".
func with_may_skip_untap() -> CardData:
	may_skip_untap = true
	return self

## Mark the card as "if you would begin your turn while this is tapped, you
## may skip that turn instead. If you do, untap this" (Time Vault).
func with_skip_turn_to_untap() -> CardData:
	skips_turn_to_untap = true
	return self

## Add an "enters with N <kind> counters" clause.
func with_enters_counters(kind: String, count: int) -> CardData:
	enters_with_counters[kind] = count
	return self

## Mark the card as entering the battlefield tapped.
func with_enters_tapped() -> CardData:
	enters_tapped = true
	return self

## Add a "can't attack unless defender controls a <land type>" clause.
func with_attack_needs_defender_land(land_type: String) -> CardData:
	attack_needs_defender_land = land_type.to_lower()
	return self

## "When you control a <creature subtype>, sacrifice this" (Goblins of
## the Flarg's Dwarf clause). Lowercase subtype, "" = no clause;
## enforced as a state-based action in MtgGame.
var sacrifice_if_you_control_subtype: String = ""

## Add a "when you control a <subtype>, sacrifice this" clause.
func with_sacrifice_if_you_control(subtype: String) -> CardData:
	sacrifice_if_you_control_subtype = subtype.to_lower()
	return self

## "You may have this permanent enter as a copy of ..." (Clone, Copy
## Artifact, Vesuvan Doppelganger). A REPLACEMENT effect, applied by
## MtgGame as the permanent enters — before state-based actions, so a 0/0
## Clone never dies on the way in. Keys:
##   "filter":          Callable(inst: CardInstance) -> bool (what may be copied)
##   "desc":            String (agent prompt / refusal text)
##   "extra_types":     int   (Copy Artifact's "...in addition")
##   "keep_own_colors": bool  (Vesuvan Doppelganger)
var enters_as_copy: Dictionary = {}

## Mark this card as entering as a copy (see [member enters_as_copy]).
## [param transform] optionally rewrites the copied definition before it is
## adopted — Vesuvan Doppelganger's "and it has this ability".
func with_enters_as_copy(filter: Callable, desc: String,
		extra_types := 0, keep_own_colors := false,
		transform := Callable()) -> CardData:
	enters_as_copy = {
		"filter": filter, "desc": desc,
		"extra_types": extra_types, "keep_own_colors": keep_own_colors,
		"transform": transform,
	}
	return self


## "As this permanent enters, <choose / pay / sacrifice>" — a REPLACEMENT
## effect (CR 614.1c), not a triggered ability:
## [code]func(game: MtgGame, inst: CardInstance, controller: int) -> void[/code].
## MtgGame runs it as the permanent arrives — once it is on the battlefield,
## so the callback may sacrifice, pay life or ask its controller something
## through the usual funnel, but BEFORE state-based actions or any
## ENTERS_BATTLEFIELD trigger has seen it. That window is what lets a */*
## body settle its size before the 0/0 check could kill it (Wood Elemental,
## Nameless Race) and what makes the choice unobservable, exactly as a
## replacement effect should be.
##
## What was decided belongs in [member CardInstance.memory], where the
## card's own characteristic-defining static reads it and which the engine
## clears when the permanent leaves (CR 400.7).
var as_enters: Callable = Callable()

## Fluent: install an "as this enters" replacement (see [member as_enters]).
func as_it_enters(cb: Callable) -> CardData:
	as_enters = cb
	return self


## "If this enchantment leaves the battlefield, this effect continues until
## end of turn" (Titania's Song) — the IMMEDIATE half of leaving the
## battlefield, and the twin of [member as_enters].
##
## Neither a replacement nor a trigger. A trigger cannot express this: it
## goes on the stack and resolves after [method ContinuousEffects.recalculate]
## has already recomputed the world WITHOUT the departing permanent's
## statics, and by then there is nothing left to continue. MtgGame calls
## this at the instant the permanent leaves, from every exit the
## battlefield has — graveyard, exile, hand and ante — after the
## leave-triggers are on the stack and after this object's own floating
## effects are dropped (CR 400.7), but BEFORE the recalculation. So the
## callback sees the board exactly as this permanent left it, and may
## register floating effects of its own with a duration
## ([ContinuousEffects.Duration], CR 611.2b).
##
## [code]func(game: MtgGame, inst: CardInstance, controller: int,
## parting_memory: Dictionary) -> void[/code] — `controller` is who
## controlled it as it left, which is not necessarily its owner (Control
## Magic), and `parting_memory` is the snapshot of [member
## CardInstance.memory] taken before the battlefield-state wipe, the same
## one the LEAVES_BATTLEFIELD event carries (Oubliette's prisoner).
var as_leaves: Callable = Callable()

## Fluent: install an immediate leave hook (see [member as_leaves]).
func as_it_leaves(cb: Callable) -> CardData:
	as_leaves = cb
	return self


## A SHALLOW copy of this definition — same name, same cost, same effect and
## ability objects. Used to build the modified definition a copy adopts
## ("except it has this ability" — Vesuvan Doppelganger); CardData is
## immutable in practice, so sharing the inner objects is safe.
## Copies every script variable, so new fields are picked up automatically.
func shallow_copy() -> CardData:
	var out := CardData.new(card_name, cost.text, types)
	for prop in get_property_list():
		if (prop.usage & PROPERTY_USAGE_SCRIPT_VARIABLE) != 0:
			out.set(prop.name, get(prop.name))
	return out


## A shallow copy of this definition carrying one EXTRA triggered ability.
func with_extra_trigger(trigger: TriggeredAbility) -> CardData:
	var out := shallow_copy()
	var triggers: Array[TriggeredAbility] = []
	triggers.append_array(triggered_abilities)
	triggers.append(trigger)
	out.triggered_abilities = triggers
	return out


## Add a "when you control no <land type>, sacrifice this" clause.
func with_sacrifice_if_no_land(land_type: String) -> CardData:
	sacrifice_if_no_land_type = land_type.to_lower()
	return self

## PLAY BAN this permanent radiates while on the battlefield ("players
## can't cast spells or play lands with a name originally printed in the
## Arabian Nights expansion" — City in a Bottle).
## [code]Callable(game, pid, data: CardData) -> bool[/code]; returning true
## forbids the cast or land drop. MtgGame checks every battlefield
## permanent at cast/play time.
## "When a spell or ability an opponent controls causes you to discard this
## card, ..." — a trigger that fires while the card is in a HAND, which is
## the one zone no ability list reaches. Called by MtgGame.discard_cards /
## discard_random as the card leaves:
## [code]func(game: MtgGame, inst: CardInstance, pid: int,
## cause_pid: int) -> void[/code], where cause_pid is the controller of the
## spell or ability that caused it ([method MtgGame.current_resolution_controller])
## or -1 for a discard nobody caused (the cleanup discard). Psychic Purge is
## the pool's only user.
var on_discarded: Callable = Callable()

## Fluent: attach a discard trigger (see [member on_discarded]).
func triggers_when_discarded(cb: Callable) -> CardData:
	on_discarded = cb
	return self


## "If a player would draw a card, instead ..." — a REPLACEMENT effect
## (CR 614) that applies for as long as this permanent is on the
## battlefield. Signature:
## [code]func(game: MtgGame, source: CardInstance, pid: int,
## ctx: Dictionary) -> bool[/code]; return TRUE when the draw was replaced
## (no card is drawn), FALSE to let it happen. [code]ctx[/code] carries
## `player`, `in_draw_step` and `draw_number` (1-based within the current
## step). Applied by MtgGame._replace_draw, which is the only caller.
## Island Sanctuary, Chains of Mephistopheles.
var draw_replacement: Callable = Callable()

## Fluent: attach a draw replacement (see [member draw_replacement]).
func replaces_draws(cb: Callable) -> CardData:
	draw_replacement = cb
	return self


## "If you would begin your draw step, you may skip that step instead"
## (Fasting) — the same CR 614 replacement applied to a turn-based action
## rather than to a draw. [code]func(game: MtgGame, source: CardInstance,
## pid: int) -> bool[/code]; TRUE skips the whole step, so no draw happens,
## no DRAW_STEP event fires and nobody gets priority in it.
var draw_step_replacement: Callable = Callable()

## Fluent: attach a draw-step replacement (see [member draw_step_replacement]).
func replaces_draw_step(cb: Callable) -> CardData:
	draw_step_replacement = cb
	return self


var play_ban: Callable = Callable()

## Fluent: radiate a play ban (see [member play_ban]).
func bans_playing(cb: Callable) -> CardData:
	play_ban = cb
	return self


## "Artifacts, creatures and lands your opponents control ENTER TAPPED"
## (Kismet) — a REPLACEMENT effect (CR 614.1c), not a trigger: the
## permanent is never untapped, so nothing that watches for a permanent
## becoming tapped (Psychic Venom, Powerleech, Haunting Wind) ever fires.
## [code]func(game: MtgGame, source: CardInstance, entering: CardInstance,
## controller: int) -> bool[/code], asked of every battlefield permanent as
## something arrives; TRUE means it arrives tapped.
var enters_tapped_rule: Callable = Callable()

## Fluent: radiate an enters-tapped replacement (see
## [member enters_tapped_rule]).
func taps_permanents_entering(cb: Callable) -> CardData:
	enters_tapped_rule = cb
	return self


## "Lands can't enter the battlefield" (Worms of the Earth) — the REFUSAL
## twin of [member enters_tapped_rule]. Same shape, same question, asked of
## every permanent already on the battlefield as something arrives; the
## difference is the answer, because this one has to deny an arrival rather
## than modify one. TRUE means the object does not enter at all, so no
## enters-the-battlefield trigger fires and — since it never entered —
## neither does any leave- or dies-trigger.
## [code]func(game: MtgGame, source: CardInstance, entering: CardInstance,
## controller: int) -> bool[/code]
var enters_ban_rule: Callable = Callable()

## Fluent: radiate an enters-the-battlefield ban (see
## [member enters_ban_rule]).
func bans_permanents_entering(cb: Callable) -> CardData:
	enters_ban_rule = cb
	return self


## "If you can't, put this creature into its owner's graveyard INSTEAD OF
## onto the battlefield" (Frankenstein's Monster) — a card's veto on its
## OWN arrival, the self-scoped half of [member enters_ban_rule]. Asked
## before the permanent touches the battlefield, which is the whole point
## of the printed wording: a Monster that cannot be assembled never enters,
## so nothing ever sees it on the battlefield and nothing sees it die.
## [code]func(game: MtgGame, inst: CardInstance, controller: int) -> String[/code]
## — "" to enter, otherwise the reason it cannot.
var entry_condition: Callable = Callable()

## Fluent: install an arrival veto (see [member entry_condition]).
func enters_only_if(cb: Callable) -> CardData:
	entry_condition = cb
	return self


## ADDITIONAL COST: "As an additional cost to cast this spell, sacrifice a
## <desc>" (Metamorphosis). {"desc": String, "filter": Callable(inst) -> bool}
## or empty. MtgGame picks a body through the caster's DecisionAgent, refuses
## the cast when there is none, and sacrifices it as the spell is put on the
## stack (CR 601.2h) — recording its mana value in the spell's own memory so
## the resolving effect can read it.
var additional_sacrifice: Dictionary = {}

## Add an "as an additional cost, sacrifice a <desc>" clause.
func with_additional_sacrifice(desc: String, filter: Callable) -> CardData:
	additional_sacrifice = {"desc": desc, "filter": filter}
	return self


## "This spell costs {N} more to cast for each target beyond the first"
## (Fireball). 0 = no such clause. MtgGame adds it as generic mana once the
## targets are known (CR 601.2f).
var extra_cost_per_target: int = 0

## Add the "costs {n} more for each target beyond the first" clause.
func with_extra_cost_per_target(n: int) -> CardData:
	extra_cost_per_target = n
	return self

## "Spend only black mana on X" (Drain Life) — the spell's X is paid in
## COLOURED mana of this Mtg.ManaColor instead of generic. 0 = the usual
## generic X. The 1997 exe charged Drain Life's X as black
## (`charge_mana(player, COLOR_BLACK, -1)`, routine 0x41E9B0). The
## ability-side twin is [member ActivatedAbility.x_color].
var x_color: int = 0

## Fluent: make this spell's X a coloured payment (see [member x_color]).
func with_colored_x(color: int) -> CardData:
	x_color = color
	return self

## The cost actually paid for a cast with [param x_value]: the printed
## cost, plus X coloured pips per printed {X} when [member x_color] is set
## (the {X} itself drops out — see [method ManaCost.plus_colored]).
func cost_for(x_value: int) -> ManaCost:
	if x_color == 0 or x_value <= 0:
		return cost
	return cost.plus_colored(x_color, x_value * maxi(cost.x_count, 1))

## Ward-style aura: enchanted permanent has protection from the colors in
## [param color_mask], and this aura is exempt from being removed by its
## OWN grant ("This effect doesn't remove this Aura"). Installs both the
## granting static and the exemption in one call.
func grants_host_protection(color_mask: int, text := "") -> CardData:
	aura_grants_protection |= color_mask
	static_abilities.append(StaticAbility.new(
		CardData._apply_host_protection.bind(color_mask),
		text if text != "" else "Enchanted creature has protection."))
	return self


static func _apply_host_protection(game: MtgGame, source: CardInstance, mask: int) -> void:
	if source.attached_to == -1:
		return
	var host := game.find_instance(source.attached_to)
	if host != null and host.zone == Mtg.Zone.BATTLEFIELD:
		host.cur_protection |= mask


## Mark this aura as taking control of its host (Control Magic).
func steals_control() -> CardData:
	aura_steals = true
	return self

## Mark this aura as reanimating its graveyard target (Animate Dead).
func reanimates() -> CardData:
	aura_reanimates = true
	return self

## Add one mode to a modal spell ("Choose one —").
func mode(label: String, effects: Array) -> CardData:
	var effect_list: Array = []
	for e in effects:
		effect_list.append(e)
	modes.append({"label": label, "effects": effect_list})
	return self

## Give the AI a mode chooser for this modal card.
func with_ai_mode(picker: Callable) -> CardData:
	ai_mode_picker = picker
	return self

## Attach cost modifiers (see [member cost_modifier]).
func with_cost_modifier(spell_cb: Callable, ability_cb := Callable()) -> CardData:
	if spell_cb.is_valid():
		cost_modifier["spell"] = spell_cb
	if ability_cb.is_valid():
		cost_modifier["ability"] = ability_cb
	return self

## True when this card has "Choose one —" modes.
func is_modal() -> bool:
	return not modes.is_empty()


# ------------------------------------------------------------------ queries --

## Does the PRINTED type mask contain [param type_flag]? Rules code about
## a battlefield object asks the INSTANCE instead (its types can change).
func is_type(type_flag: int) -> bool:
	return (types & type_flag) != 0

## Printed creature-ness (see [method is_type] for the live caveat).
func is_creature() -> bool:
	return is_type(Mtg.CardType.CREATURE)

## Printed land-ness.
func is_land() -> bool:
	return is_type(Mtg.CardType.LAND)

## True when this card is an Aura — i.e. it declared what it enchants.
func is_aura() -> bool:
	return aura_target != null

## Instants and sorceries go to the graveyard on resolution; everything
## else becomes a permanent on the battlefield.
func is_permanent_type() -> bool:
	return not (is_type(Mtg.CardType.INSTANT) or is_type(Mtg.CardType.SORCERY))

## PRINTED COLOUR when it is NOT the one its mana cost implies: the three
## Legends Kobolds cost {0} and are red anyway (a colour indicator in modern
## terms, CR 105.2b). -1 = derive the colour from the cost, which is right
## for every other card in the pool.
var printed_colors: int = -1

## Fluent: give this card a printed colour its cost does not imply.
func with_colors(color_mask_value: int) -> CardData:
	printed_colors = color_mask_value
	return self

## The card's color mask: its printed colour when it has one, else the
## colours of its mana cost (CR 105.2).
func color_mask() -> int:
	return printed_colors if printed_colors >= 0 else cost.color_mask()

## Printed keyword check. Rules code reads CardInstance.cur_keywords.
func has_keyword(keyword: int) -> bool:
	return keywords.has(keyword)


func _to_string() -> String:
	return card_name
