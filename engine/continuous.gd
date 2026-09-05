class_name ContinuousEffects
extends RefCounted
## The continuous-effects pipeline: computes every permanent's CURRENT
## characteristics from its printed values plus all active modifiers.
##
## Three modifier sources exist:
## 1. Static abilities of battlefield permanents (incl. auras) — re-applied
##    from scratch every pass.
## 1b. FLOATING statics ([method add_floating_static]) — the same abilities,
##    kept running after their source has left the battlefield because the
##    card says so ("this effect continues until end of turn", Titania's
##    Song). Same layers, same callbacks, a duration instead of a source.
## 2. Floating until-end-of-turn effects (Giant Growth) — registered by
##    resolving effects via [method add_until_eot_pump], expired by the
##    cleanup step via [method expire_until_eot], and dropped early by
##    [method forget_instance] when their object leaves the battlefield
##    (CR 400.7 — what comes back is a new object).
##
## The pipeline ([method recalculate]) is intentionally "recompute the
## world": reset every permanent to printed values, then apply everything in
## CR 613 LAYER order, timestamps deciding within a layer:
## [codeblock]
##   reset to printed             (and CR 613 layer 3 text changes)
##   animations                   layer 4, floating   (Mishra's Factory)
##   type-changing statics        layer 4             (Blood Moon, Kormus Bell)
##   floating statics             the same layers     (Titania's Song, once gone)
##   base-P/T statics             layer 7a/7b         (Nightmare, Keldon Warlord)
##   floating base-P/T sets       layer 7b, later ts  (Island of Wak-Wak)
##   colour changes               layer 5             (Touch of Darkness)
##   the remaining statics        layer 7c and misc.  (Crusade, Bad Moon)
##   counters                     layer 7d            (any "+A/+B" kind)
##   floating pumps               layer 7c, floating  (Giant Growth)
##   landwalk grants, block restrictions
##   ability losses               layer 6             (Hammerheim)
##   combat-damage shields
##   P/T switches                 layer 7e            (Transmutation)
## [/codeblock]
## Recomputing from scratch after every change is exactly how XMage/mage-go
## stay correct, and at duel scale (tens of permanents) the cost is
## irrelevant — see docs/audit-2026-09.md for the measurements that decided
## which parts of it to make cheaper. What is still simplified: no
## dependency analysis (CR 613.8) beyond running the layer-4 pass twice, and
## an ability LOSS beats a later grant regardless of timestamps
## (docs/ROADMAP.md).

## How long a floating effect lasts (CR 611.2b — a one-shot effect that
## creates a continuous effect states its own duration).
##
## [constant Duration.END_OF_TURN] and [constant Duration.END_OF_COMBAT]
## are the pair this pipeline has always had; the latter still rides on
## each entry's `until_combat` flag, which is what
## [method expire_end_of_combat] reads. The two below it are the durations
## the 1997 pool actually asks for and this pipeline used to approximate
## with end-of-turn:
##
## - [constant Duration.UNTIL_UPKEEP_OF] — "until your next upkeep"
##   (Xenic Poltergeist, Erhnam Djinn). Ends at the BEGINNING of that
##   player's upkeep step, before its triggers are put on the stack, so a
##   creature that stops being animated cannot also trigger off the upkeep.
## - [constant Duration.INDEFINITE] — no duration at all. Brine Hag's
##   reminder text says it outright: *"(This effect lasts indefinitely.)"*
##   Only the object leaving the battlefield ends it
##   ([method forget_instance], CR 400.7).
## - [constant Duration.UNTIL_END_OF_UPKEEP_OF] — "until the end of your
##   next upkeep" (Halfdane). Ends as that player's NEXT upkeep step ends
##   ([method expire_end_of_upkeep_of], called by MtgGame on leaving the
##   step) — "next" meaning an upkeep that BEGAN after the effect did, so
##   an effect created during your upkeep of turn N lasts through your
##   upkeep of turn N+2. The entry stamps the turn it was created on
##   (`lasts_turn`) to tell the two apart.
##
## An entry carries `lasts` (one of these) and, for the two upkeep
## durations, `lasts_pid` (plus `lasts_turn` for the second). Absent, all
## default to END_OF_TURN, which is why every existing caller keeps
## working untouched.
enum Duration { END_OF_TURN, END_OF_COMBAT, UNTIL_UPKEEP_OF, INDEFINITE,
	UNTIL_END_OF_UPKEEP_OF }

## Active until-end-of-turn pumps:
## {instance_id, power, toughness, keywords: Array[int]}
var _floating: Array[Dictionary] = []

## Active ANIMATIONS (Mishra's Factory): the object gains types/subtypes
## and its base P/T is SET before pumps apply. Most last until end of
## turn; `until_combat` entries (Jade Statue) expire when the combat
## phase ends instead (CR 700.5).
## {instance_id, add_types: int, set_power, set_toughness, add_subtypes,
##  until_combat: bool}
var _animations: Array[Dictionary] = []

## Active "has base power/toughness N until end of turn" effects (Island
## of Wak-Wak, Singing Tree, Sorceress Queen), as
## {instance_id, set_power: bool, power: int, set_toughness: bool,
##  toughness: int, until_combat: bool}. Applied in CR 613 layer 7b —
## right after animations and before counters and pumps, so a later Giant
## Growth still adds on top.
var _base_pt: Array[Dictionary] = []

## Active until-end-of-turn LANDWALK grants (Scarwood Hag, Wormwood
## Treefolk, War Barge), as {instance_id, types: Array, until_combat}.
## Applied with the other keyword grants, before ability losses.
var _landwalk_grants: Array[Dictionary] = []

## Active until-end-of-turn RAMPAGE grants (Rapid Fire), as
## {instance_id, amount: int, until_combat}. Applied with the other keyword
## grants; the LARGEST grant wins rather than stacking, because rampage is
## a parameterized keyword and CR 702.23b counts each instance separately —
## nothing in this pool ever grants two, so taking the maximum keeps the
## single case exact without pretending to handle a stack.
var _rampage_grants: Array[Dictionary] = []

## Active "loses <ability> until end of turn" effects (Hammerheim strips
## landwalk, Urborg strips first strike, Wall of Wonder drops its own
## defender), as {instance_id, keywords: Array[int], landwalk: bool,
## landwalk_types: Array[String], until_combat: bool} — `landwalk` is
## Hammerheim's "all landwalk abilities", `landwalk_types` Urborg's
## "swampwalk" / Scarwood Hag's "forestwalk", one type each and no other.
## Applied after the granting passes, so a keyword
## granted earlier this turn is removed too — a timestamp simplification
## in the spirit of the rest of this pipeline (CR 613 layer 6 proper).
var _losses: Array[Dictionary] = []

## Active until-end-of-turn DAMAGE IMMUNITIES ("if a spell or ability that
## targets that creature would cause a source to deal damage to it this
## turn, prevent that damage" — Silhouette), as {instance_id, desc, filter,
## until_combat}. Applied into the same CardInstance.cur_damage_immunity
## list the statics write.
var _damage_immunities: Array[Dictionary] = []

## Active until-end-of-turn PROTECTION grants ("gains protection from
## white until end of turn" — Goblin Wizard), as {instance_id,
## colors: int, until_combat: bool}. Applied in layer 6 with the keyword
## grants; the durationless kind rides on CardInstance.added_protection.
var _protection_grants: Array[Dictionary] = []

## Active GRANTED ACTIVATED ABILITIES ("that creature gains 'Remove a
## matrix counter from this creature: Regenerate this creature'" — Life
## Matrix), as {instance_id, ability: ActivatedAbility, until_combat,
## lasts, lasts_pid}. Applied in CR 613 layer 6 with the keyword grants.
##
## This is the list a durationless grant needs: CR 611.2b says an effect
## that names no duration lasts INDEFINITELY, so a granted ability must
## outlive the permanent that granted it. A static of the granting source
## cannot do that — it is re-derived every recalculation and vanishes with
## its source — which is why Life Matrix wanted a registry rather than a
## static.
var _ability_grants: Array[Dictionary] = []

## Active FLOATING STATICS — a static ability that outlives the permanent
## that printed it, as {instance_id: -1, source: CardInstance,
## ability: StaticAbility, until_combat, lasts, lasts_pid}.
##
## Titania's Song is the pool's example: *"If this enchantment leaves the
## battlefield, this effect continues until end of turn."* That rider is an
## exception to CR 611.3b (a static's effect applies while its source is on
## the battlefield) and to nothing else — CR 611.3a still holds, so the
## effect is NOT locked in to the objects it was affecting and keeps
## applying to whatever its text indicates, including an artifact that
## arrives after the Song has gone.
##
## Which is why this list holds the ABILITY rather than its results: the
## same `apply` callback, run in the same five sub-passes of
## [method recalculate] and in the same layer order as if the source were
## still on the table, with only the source's presence lifted. `source` is
## the departed permanent, passed to the callback exactly as a live one
## would be (a static that reads its own source can therefore still read
## last known information, CR 608.2h).
##
## `instance_id` is -1 on purpose: [method forget_instance] keys on it, and
## an effect that is meant to outlive its source must not be dropped when
## that source leaves. Duration is the only thing that ends one.
var _floating_statics: Array[Dictionary] = []


## Active until-end-of-turn / until-end-of-combat KEYWORD GRANTS ("gains
## banding until end of combat" — Battering Ram), as {instance_id,
## keywords: Array[int], until_combat: bool}. Applied in CR 613 layer 6
## BEFORE the losses, so a later "loses flying" still beats an earlier
## grant, exactly as the landwalk grants do.
var _keyword_grants: Array[Dictionary] = []

## Active until-end-of-turn COMBAT-damage preventions (Lady Evangela,
## Horn of Deafening, Subdue), as {instance_id, dealt: bool, taken: bool,
## until_combat: bool}. Applied as instance flags that MtgGame.deal_damage
## honours for combat damage only.
var _combat_prevention: Array[Dictionary] = []

## Active "becomes <colour> until end of turn" effects (Dwarven Song,
## Heaven's Gate, Sea Kings' Blessing, Sylvan Paradise, Touch of Darkness),
## as {instance_id, colors: int, until_combat: bool}. CR 613 layer 5, which
## nothing else in this pipeline depends on, so they apply in creation
## order right after the statics — the last one cast wins.
var _color_changes: Array[Dictionary] = []

## Active "switch power and toughness until end of turn" effects
## (Transmutation), as {instance_id, until_combat: bool}. Applied LAST —
## CR 613.4e puts P/T switching in the final sublayer, after every other
## power/toughness change. Two switches on the same creature cancel out,
## which falls out of applying them in order.
var _switches: Array[Dictionary] = []


## Register "+P/+T (and keywords) until end of turn" on an instance.
## [param until_end_of_combat]: expire when the combat phase ends instead
## (Murk Dwellers' "until end of combat").
## THE SEARCH JOURNAL, or null. [method MtgGame.make_mark] hands it over and
## [method MtgGame.end_search] takes it back. Card scripts append to the
## floating lists through `game.continuous.add_*` DIRECTLY — this object
## is the helper surface for them — so the "record the old list" call has
## to live here rather than in MtgGame. One null test per add.
var journal: UndoLog = null


## Note [param list_name]'s current contents before an add disturbs it.
func _rec(list_name: StringName) -> void:
	if journal != null:
		journal.record(self, list_name, get(list_name))


## Note EVERY floating list — for the passes that may touch any of them
## ([method forget_instance], the expiries).
func record_all() -> void:
	if journal == null:
		return
	for list_name in LIST_NAMES:
		journal.record(self, list_name, get(list_name))


func add_until_eot_pump(instance_id: int, power: int, toughness: int,
		keywords: Array[int] = [], until_end_of_combat := false) -> void:
	_rec(&"_floating")
	_floating.append({
		"instance_id": instance_id,
		"power": power, "toughness": toughness,
		"keywords": keywords.duplicate(),
		"until_combat": until_end_of_combat,
	})


## Register "becomes an X/Y [types] until end of turn" on an instance
## (CR 613 layers 4 and 7b, hoisted into this simplified pipeline).
## [param until_end_of_combat]: expire when the combat phase ends instead
## of at cleanup (Jade Statue's "until end of combat").
## [param lasts] / [param lasts_pid]: a longer duration than end of turn —
## Xenic Poltergeist's "until your next upkeep" (see [enum Duration]).
func add_until_eot_animation(instance_id: int, add_types: int,
		set_power: int, set_toughness: int, add_subtypes: Array = [],
		until_end_of_combat := false, lasts := Duration.END_OF_TURN,
		lasts_pid := -1) -> void:
	_rec(&"_animations")
	_animations.append({
		"instance_id": instance_id, "add_types": add_types,
		"set_power": set_power, "set_toughness": set_toughness,
		"add_subtypes": add_subtypes.duplicate(),
		"until_combat": until_end_of_combat,
		"lasts": lasts, "lasts_pid": lasts_pid,
	})


## Register "has base power/toughness N until end of turn". Pass -1 for a
## half you do not want to change (Island of Wak-Wak sets power only) —
## unless [param exact] is true, in which case BOTH halves are set even
## when negative: Halfdane copying a Wall of Wood that a Weakness left at
## -2/2 becomes -2/2 itself (a negative power is a value like any other,
## CR 107.1b).
## [param lasts] / [param lasts_pid]: a longer duration than end of turn —
## Brine Hag's indefinite 0/2 curse (see [enum Duration]); [param
## lasts_turn] is the turn the effect is created on, which
## UNTIL_END_OF_UPKEEP_OF needs (Halfdane's borrowed body).
func add_until_eot_base_pt(instance_id: int, power: int, toughness: int,
		until_end_of_combat := false, lasts := Duration.END_OF_TURN,
		lasts_pid := -1, lasts_turn := -1, exact := false) -> void:
	_rec(&"_base_pt")
	_base_pt.append({
		"instance_id": instance_id,
		"set_power": power >= 0 or exact, "power": power,
		"set_toughness": toughness >= 0 or exact, "toughness": toughness,
		"until_combat": until_end_of_combat,
		"lasts": lasts, "lasts_pid": lasts_pid, "lasts_turn": lasts_turn,
	})


## Register "gains <type>walk until end of turn" on an instance.
## [param lasts] / [param lasts_pid]: a longer duration than end of turn —
## Erhnam Djinn's "until your next upkeep" (see [enum Duration]).
func add_until_eot_landwalk(instance_id: int, types: Array,
		until_end_of_combat := false, lasts := Duration.END_OF_TURN,
		lasts_pid := -1) -> void:
	_rec(&"_landwalk_grants")
	_landwalk_grants.append({
		"instance_id": instance_id, "types": types.duplicate(),
		"until_combat": until_end_of_combat,
		"lasts": lasts, "lasts_pid": lasts_pid,
	})


## Register "gains rampage N until end of turn" on an instance (Rapid Fire).
func add_until_eot_rampage(instance_id: int, amount: int,
		until_end_of_combat := false) -> void:
	_rec(&"_rampage_grants")
	_rampage_grants.append({
		"instance_id": instance_id, "amount": amount,
		"until_combat": until_end_of_combat,
	})


## Register "prevent all damage that <filter> would deal to this creature
## this turn". [param filter] is func(game: MtgGame, source: CardInstance)
## -> bool — the same shape CardInstance.cur_damage_immunity takes.
func add_until_eot_damage_immunity(instance_id: int, desc: String,
		filter: Callable, until_end_of_combat := false) -> void:
	_rec(&"_damage_immunities")
	_damage_immunities.append({
		"instance_id": instance_id, "desc": desc, "filter": filter,
		"until_combat": until_end_of_combat,
	})


## Register "gains protection from [param colors] until end of turn".
func add_until_eot_protection(instance_id: int, colors: int,
		until_end_of_combat := false) -> void:
	_rec(&"_protection_grants")
	_protection_grants.append({
		"instance_id": instance_id, "colors": colors,
		"until_combat": until_end_of_combat,
	})


## Register "gains [param keywords] until end of turn (or end of combat)"
## on an instance. See [member _keyword_grants].
func add_until_eot_keywords(instance_id: int, keywords: Array,
		until_end_of_combat := false) -> void:
	var list: Array[int] = []
	for k in keywords:
		list.append(int(k))
	_rec(&"_keyword_grants")
	_keyword_grants.append({
		"instance_id": instance_id, "keywords": list,
		"until_combat": until_end_of_combat,
	})


## Register [param ability] as a FLOATING static — one that goes on
## applying after [param source] has left the battlefield (Titania's Song).
## See [member _floating_statics]. [param lasts] defaults to END_OF_TURN,
## which is the duration the pool's only user prints.
func add_floating_static(source: CardInstance, ability: StaticAbility,
		lasts := Duration.END_OF_TURN, lasts_pid := -1,
		until_end_of_combat := false) -> void:
	_rec(&"_floating_statics")
	_floating_statics.append({
		"instance_id": -1, "source": source, "ability": ability,
		"until_combat": until_end_of_combat,
		"lasts": lasts, "lasts_pid": lasts_pid,
	})


## Register "[param instance_id] gains [param ability]" (Life Matrix).
## [param lasts] defaults to INDEFINITE because that is what a grant with
## no stated duration means (CR 611.2b) — and the durations the other
## adders take are available for a grant that does state one.
##
## A grant the instance already carries is DROPPED rather than duplicated.
## That is not a shortcut: two copies of an identical ability, each paid
## for out of the same counter pile, are indistinguishable in play from one
## copy activated twice — and one entry keeps the card menu readable.
func add_granted_activated_ability(instance_id: int, ability: ActivatedAbility,
		lasts := Duration.INDEFINITE, lasts_pid := -1,
		until_end_of_combat := false) -> void:
	for entry in _ability_grants:
		if int(entry["instance_id"]) == instance_id \
				and String(entry["ability"].text) == String(ability.text):
			return
	_rec(&"_ability_grants")
	_ability_grants.append({
		"instance_id": instance_id, "ability": ability,
		"until_combat": until_end_of_combat,
		"lasts": lasts, "lasts_pid": lasts_pid,
	})


## Register "loses [param keywords] (and/or all landwalk, and/or the
## landwalk of [param landwalk_types] — "swamp", "forest"...) until end of
## turn" on an instance. See [member _losses].
func add_until_eot_loss(instance_id: int, keywords: Array[int] = [],
		lose_landwalk := false, until_end_of_combat := false,
		landwalk_types: Array = []) -> void:
	_rec(&"_losses")
	var types: Array[String] = []
	for t in landwalk_types:
		types.append(String(t))
	_losses.append({
		"instance_id": instance_id,
		"keywords": keywords.duplicate(),
		"landwalk": lose_landwalk,
		"landwalk_types": types,
		"until_combat": until_end_of_combat,
	})


## Register "prevent all combat damage that would be dealt by (and/or to)
## this creature this turn".
func add_until_eot_combat_prevention(instance_id: int, prevent_dealt: bool,
		prevent_taken: bool, until_end_of_combat := false,
		prevent_all_damage_dealt := false,
		prevent_all_damage_taken := false) -> void:
	_rec(&"_combat_prevention")
	_combat_prevention.append({
		"instance_id": instance_id, "dealt": prevent_dealt,
		"taken": prevent_taken, "until_combat": until_end_of_combat,
		"all_damage": prevent_all_damage_dealt,
		"all_damage_taken": prevent_all_damage_taken,
	})


## Active until-end-of-turn BLOCK RESTRICTIONS ("can't be blocked by Walls
## this turn" — Tower of Coireall), as {instance_id, desc, filter,
## until_combat}. Applied alongside the static restrictions the same
## CombatState check reads.
var _block_restrictions: Array[Dictionary] = []


## Register "can't be blocked except by <desc>" on an instance until end of
## turn. [param filter] is func(blocker: CardInstance) -> bool.
func add_until_eot_block_restriction(instance_id: int, desc: String,
		filter: Callable, until_end_of_combat := false) -> void:
	_rec(&"_block_restrictions")
	_block_restrictions.append({
		"instance_id": instance_id, "desc": desc, "filter": filter,
		"until_combat": until_end_of_combat,
	})


## Register "becomes <colours> until end of turn" on an instance. Pass an
## Mtg.ManaColor bitmask; 0 makes the object colourless.
func add_until_eot_color(instance_id: int, colors: int,
		until_end_of_combat := false) -> void:
	_rec(&"_color_changes")
	_color_changes.append({
		"instance_id": instance_id, "colors": colors,
		"until_combat": until_end_of_combat,
	})


## Register "switch this creature's power and toughness until end of turn"
## (Transmutation). See [member _switches] for the layer note.
func add_until_eot_pt_switch(instance_id: int, until_end_of_combat := false) -> void:
	_rec(&"_switches")
	_switches.append({"instance_id": instance_id, "until_combat": until_end_of_combat})


## Drop every floating effect keyed to [param instance_id]. Called by
## MtgGame when that object LEAVES the battlefield: whatever comes back is a
## new object (CR 400.7), so a Giant Growth cast on a creature that is then
## bounced must not follow the card back onto the battlefield. Phasing is
## deliberately NOT a caller — a phased-out permanent never changed zones
## (CR 702.25), so its until-end-of-turn effects survive.
func forget_instance(instance_id: int) -> void:
	record_all()
	for list in _all_lists():
		for i in range(list.size() - 1, -1, -1):
			if int(list[i]["instance_id"]) == instance_id:
				list.remove_at(i)


## Every floating list, so the expiry passes do not have to name them
## twice and a new one cannot be forgotten by half of them.
func _all_lists() -> Array:
	return [_floating, _animations, _switches, _losses, _keyword_grants,
		_protection_grants, _damage_immunities, _base_pt, _combat_prevention,
		_landwalk_grants, _rampage_grants, _color_changes, _block_restrictions,
		_ability_grants, _floating_statics]


## The same lists BY NAME, for the journal ([method record_all]) — kept
## beside [method _all_lists] so the two cannot drift apart unnoticed.
const LIST_NAMES: Array[StringName] = [&"_floating", &"_animations",
	&"_switches", &"_losses", &"_keyword_grants", &"_protection_grants",
	&"_damage_immunities", &"_base_pt", &"_combat_prevention",
	&"_landwalk_grants", &"_rampage_grants", &"_color_changes",
	&"_block_restrictions", &"_ability_grants", &"_floating_statics"]


## Drop all until-end-of-turn effects (cleanup step, CR 514.2).
##
## Entries carrying a LONGER duration survive: an "until your next upkeep"
## effect is meant to cross the cleanup step (that is the whole difference
## between the two), and an indefinite one never ends here at all. Both are
## still dropped by [method forget_instance] when their object leaves the
## battlefield, so nothing can outlive the permanent it is written on.
func expire_until_eot() -> void:
	record_all()
	for list in _all_lists():
		for i in range(list.size() - 1, -1, -1):
			if int(list[i].get("lasts", Duration.END_OF_TURN)) \
					== Duration.END_OF_TURN:
				list.remove_at(i)


## Drop the "until [param pid]'s next upkeep" effects (CR 611.2b). Called
## by MtgGame as the upkeep step begins, BEFORE its triggers go on the
## stack: an artifact that stops being a creature must already be one
## again when anything looks.
func expire_upkeep_of(pid: int) -> void:
	record_all()
	for list in _all_lists():
		for i in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[i]
			if int(entry.get("lasts", Duration.END_OF_TURN)) \
					== Duration.UNTIL_UPKEEP_OF \
					and int(entry.get("lasts_pid", -1)) == pid:
				list.remove_at(i)


## Drop the "until the end of [param pid]'s next upkeep" effects (CR
## 611.2b) that were created BEFORE turn [param turn] — called by MtgGame
## as that player's upkeep step ends. An effect created during this very
## upkeep is not "next": it stays. Returns whether anything ended.
func expire_end_of_upkeep_of(pid: int, turn: int) -> bool:
	record_all()
	var dropped := false
	for list in _all_lists():
		for i in range(list.size() - 1, -1, -1):
			var entry: Dictionary = list[i]
			if int(entry.get("lasts", Duration.END_OF_TURN)) \
					== Duration.UNTIL_END_OF_UPKEEP_OF \
					and int(entry.get("lasts_pid", -1)) == pid \
					and int(entry.get("lasts_turn", -1)) < turn:
				list.remove_at(i)
				dropped = true
	return dropped


## Drop "until end of combat" effects — called by MtgGame when the combat
## phase ends (CR 700.5). Everything else keeps floating until cleanup.
func expire_end_of_combat() -> void:
	record_all()
	for list in _all_lists():
		for i in range(list.size() - 1, -1, -1):
			if list[i].get("until_combat", false):
				list.remove_at(i)


## Parse a P/T counter name like "+1/+1", "-0/-2" or "+1/+0" into its
## power/toughness delta. Non-P/T counters (dream, storage, mire...)
## return ZERO and are ignored by the characteristics pipeline.
static func _parse_pt_counter(kind: String) -> Vector2i:
	var halves := kind.split("/")
	if halves.size() != 2:
		return Vector2i.ZERO
	if not (halves[0].begins_with("+") or halves[0].begins_with("-")):
		return Vector2i.ZERO
	if not (halves[1].begins_with("+") or halves[1].begins_with("-")):
		return Vector2i.ZERO
	if not halves[0].substr(1).is_valid_int() or not halves[1].substr(1).is_valid_int():
		return Vector2i.ZERO
	return Vector2i(int(halves[0]), int(halves[1]))


## The five sub-passes [method recalculate] runs the static abilities in,
## named so [method _floating_statics_pass] can be asked for one of them.
## The order is CR 613's layer order as this pipeline resolves it: ability
## removal (layer 6) before the two layer-4 retypers, then the layer-7a/7b
## setters, then everything else.
enum _StaticPass { SILENCE, LAND_TYPES, TYPES, BASE_PT, REST }


## Run the FLOATING statics ([member _floating_statics]) that belong to
## sub-pass [param which], right after the battlefield's own statics of the
## same sub-pass. Later within the layer is the right timestamp: a floating
## static is created by an event — its source leaving — that happened after
## every permanent still on the table arrived.
##
## The conditions below MIRROR the sub-pass conditions in
## [method recalculate] exactly, so a floating static runs in the same
## layer it would have run in while its source was on the battlefield.
## What is deliberately NOT mirrored is the two skips: a source that has
## left the battlefield can be neither silenced nor tap-suspended.
func _floating_statics_pass(game: MtgGame, which: int) -> void:
	if _floating_statics.is_empty():
		return
	for entry in _floating_statics:
		var ability: StaticAbility = entry["ability"]
		var runs := false
		match which:
			_StaticPass.SILENCE:
				runs = ability.silences_abilities
			_StaticPass.LAND_TYPES:
				runs = ability.changes_land_types
			_StaticPass.TYPES:
				runs = ability.changes_types and not ability.changes_land_types \
					and not ability.silences_abilities
			_StaticPass.BASE_PT:
				runs = ability.sets_base_pt and not ability.changes_types \
					and not ability.silences_abilities
			_StaticPass.REST:
				runs = not ability.sets_base_pt and not ability.changes_types \
					and not ability.silences_abilities
		if runs:
			ability.apply.call(game, entry["source"])


## Rebuild cur_* characteristics of every battlefield permanent.
## MtgGame calls this after every state change; it must stay idempotent.
func recalculate(game: MtgGame) -> void:
	var battlefield: Array[CardInstance] = game.all_battlefield()

	# Pass 1: reset to printed values; ANIMATIONS then rewrite the base
	# (type grants + P/T SETTING, CR 613 layers 4/7b).
	game.nullified_landwalk.clear()   # rebuilt by statics in pass 2
	game.max_attackers = 0
	game.max_blockers = 0
	game.untap_caps.clear()
	game.untap_cap_sources.clear()
	game.unlimited_land_plays.clear()
	for p in game.players:
		p.mana_substitutions.clear()   # Sunglasses of Urza rebuilds it
		p.cant_lose_to_life = false    # Lich rebuilds both of these
		p.life_gain_becomes_draw = false
		p.max_hand_size = 7
		p.top_card_revealed = false   # Field of Dreams rebuilds it
		p.discard_to_library_top = false   # Library of Leng rebuilds both
		p.min_life_from_damage = 0
		p.artifact_damage_redirect = -1
		p.combat_damage_redirect = -1   # Veteran Bodyguard rebuilds it
		p.damage_caps.clear()           # Forethought Amulet rebuilds it
	for inst in battlefield:
		inst.reset_characteristics()
	for animation in _animations:
		var inst := game.find_instance(animation.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.phased_out:
			continue
		inst.cur_types |= animation.add_types
		inst.cur_power = animation.set_power
		inst.cur_toughness = animation.set_toughness
		for subtype in animation.add_subtypes:
			if not inst.cur_subtypes.has(subtype):
				inst.cur_subtypes.append(subtype)
	# 1997 RULE (manual p.124), when switched on: a TAPPED artifact's
	# continuous effects cease — artifact creatures excepted. Marking the
	# source here means every static sub-pass below skips it, so the rule
	# holds in all CR 613 layers rather than only the one we remembered.
	# AFTER the animations, not before: the exemption is for artifact
	# CREATURES, and Jade Statue and Xenic Poltergeist both animate through
	# the registry above. Judged before it, this read pass-1 types and
	# suspended a Cursed Rack the Poltergeist had just made a creature —
	# while the comment here claimed the opposite. What it still misses is
	# a permanent animated by a STATIC in pass 2a, which has not run yet.
	if game.rules.tapped_artifacts_stop:
		for inst in battlefield:
			if inst.tapped and inst.is_type(Mtg.CardType.ARTIFACT) \
					and not inst.is_creature():
				inst.cur_statics_suspended = true

	# Pass 2: static abilities, in battlefield order (entry order — our
	# arrays append on entry, so iteration order IS timestamp order).
	# THREE sub-passes, because CR 613.1 orders layers before timestamps:
	#   2a — layer 4: statics that change TYPES or subtypes (Blood Moon,
	#        Evil Presence, Kormus Bell, Titania's Song). Everything that
	#        counts land types or animates must see the retuned board.
	#   2b — layer 7a/7b: statics that SET a base P/T (Nightmare's
	#        characteristic-defining ability, Keldon Warlord).
	#   2c — everything else, notably the layer-7c anthems (Crusade, Bad
	#        Moon) that add ON TOP of a set base whatever entered first.
	# Only the permanents that CARRY a static are worth walking (the game
	# keeps that short list beside its battlefield cache).
	# "Loses all abilities" (Titania's Song) is itself a layer-6 effect, so
	# a source silenced in 2a contributes nothing in 2b or 2c.
	var static_sources := game.battlefield_with_statics()
	var type_sources := game.battlefield_with_type_statics()
	# 2a-0 — LAYER 6, the part that must come first: an ability that has
	# been REMOVED (Titania's Song) contributes nothing in any layer, so
	# every pass below skips a silenced source.
	for inst in type_sources:
		if inst.cur_statics_suspended:
			continue
		for ability in inst.data.static_abilities:
			if ability.silences_abilities:
				ability.apply.call(game, inst)
	_floating_statics_pass(game, _StaticPass.SILENCE)
	# 2a-1 — LAYER 4, retypers first: "nonbasic lands are Mountains"
	# and "enchanted land is a Swamp" REPLACE a land's basic types, and
	# everything that animates or counts those types has to see the
	# result. That dependency (CR 613.8) is resolved by construction —
	# retype, then read — rather than by analysis.
	for inst in type_sources:
		if inst.cur_abilities_silenced or inst.cur_statics_suspended:
			continue
		for ability in inst.data.static_abilities:
			if ability.changes_land_types:
				ability.apply.call(game, inst)
	_floating_statics_pass(game, _StaticPass.LAND_TYPES)
	# 2a-2 — LAYER 4, the rest: animations that ADD a type ("all Swamps
	# are 1/1 creatures"), reading the board the retypers just settled.
	for inst in type_sources:
		if inst.cur_abilities_silenced or inst.cur_statics_suspended:
			continue
		for ability in inst.data.static_abilities:
			if ability.changes_types and not ability.changes_land_types \
					and not ability.silences_abilities:
				ability.apply.call(game, inst)
	_floating_statics_pass(game, _StaticPass.TYPES)
	for inst in static_sources:
		if inst.cur_abilities_silenced or inst.cur_statics_suspended:
			continue
		for ability in inst.data.static_abilities:
			# A silencer already ran on the layer-6 pass, whatever else it is.
			if ability.sets_base_pt and not ability.changes_types \
					and not ability.silences_abilities:
				ability.apply.call(game, inst)
	_floating_statics_pass(game, _StaticPass.BASE_PT)

	# Pass 2b2: floating BASE P/T SETS (CR 613 layer 7b) — Island of
	# Wak-Wak, Singing Tree, Sorceress Queen. They are one-shot effects with
	# a LATER timestamp than any static in the same sublayer, so they run
	# after the setters above: "has base power 0" really does ground a
	# Nightmare whose own ability says otherwise.
	for entry in _base_pt:
		var target := game.find_instance(entry.instance_id)
		if target == null or target.zone != Mtg.Zone.BATTLEFIELD or target.phased_out:
			continue
		if entry.set_power:
			target.cur_power = entry.power
		if entry.set_toughness:
			target.cur_toughness = entry.toughness

	# Pass 2b3: COLOUR changes (CR 613 layer 5) — after the type-changing
	# statics (whose animations paint their own colour, Kormus Bell's black)
	# and before the anthems, which read colour (Bad Moon must see a
	# Touch-of-Darkness'd bear). INDEFINITE changes ride on
	# CardInstance.color_override and were already restored in pass 1; these
	# are the floating until-end-of-turn ones, applied in creation order so
	# the last spell cast wins.
	for change in _color_changes:
		var painted := game.find_instance(change.instance_id)
		if painted == null or painted.zone != Mtg.Zone.BATTLEFIELD or painted.phased_out:
			continue
		painted.cur_colors = change.colors

	# Pass 2c: COUNTERS (layer 7d) — BEFORE the general statics, because a
	# static that READS power (Meekstone's "creatures with power 3 or
	# greater") must see the counters a Clockwork Beast entered with. The
	# 7b setters already ran, so nothing can wipe them, and the layer-7c
	# anthems below are additive and commute with them.
	# Counter KINDS are parsed from their names ("+1/+1", "-0/-2",
	# "+1/+0"), so any P/T counter a card invents just works.
	for inst in battlefield:
		for kind in inst.counters:
			var delta := _parse_pt_counter(kind)
			if delta == Vector2i.ZERO:
				continue
			var n: int = inst.counters[kind]
			inst.cur_power += delta.x * n
			inst.cur_toughness += delta.y * n

	for inst in static_sources:
		if inst.cur_abilities_silenced or inst.cur_statics_suspended:
			continue   # Titania's Song silenced it in an earlier pass
		for ability in inst.data.static_abilities:
			# The silencers ran first, in 2a-0; they do not run again here.
			if not ability.sets_base_pt and not ability.changes_types \
					and not ability.silences_abilities:
				ability.apply.call(game, inst)
	_floating_statics_pass(game, _StaticPass.REST)

	# Pass 3: floating until-EOT effects, in creation order.
	for fx in _floating:
		var inst := game.find_instance(fx.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.phased_out:
			continue  # target left the battlefield; effect does nothing
		inst.cur_power += fx.power
		inst.cur_toughness += fx.toughness
		for k in fx.keywords:
			if not inst.cur_keywords.has(k):
				inst.cur_keywords.append(k)

	# Pass 3a2: floating LANDWALK grants (Scarwood Hag, Wormwood Treefolk).
	for grant in _landwalk_grants:
		var walker := game.find_instance(grant.instance_id)
		if walker == null or walker.zone != Mtg.Zone.BATTLEFIELD or walker.phased_out:
			continue
		for t in grant.types:
			if not walker.cur_landwalk.has(t):
				walker.cur_landwalk.append(t)

	# Pass 3a2b: floating RAMPAGE grants (Rapid Fire). The biggest wins —
	# see [member _rampage_grants] — and a printed rampage is never
	# lowered by one.
	for grant in _rampage_grants:
		var rager := game.find_instance(grant.instance_id)
		if rager == null or rager.zone != Mtg.Zone.BATTLEFIELD or rager.phased_out:
			continue
		rager.cur_rampage = maxi(rager.cur_rampage, int(grant.amount))

	# Pass 3a3: floating BLOCK RESTRICTIONS (Tower of Coireall) — the same
	# list the static "can't be blocked except by …" effects write into.
	for restriction in _block_restrictions:
		var restricted := game.find_instance(restriction.instance_id)
		if restricted == null or restricted.zone != Mtg.Zone.BATTLEFIELD or restricted.phased_out:
			continue
		restricted.cur_block_restrictions.append({
			"desc": restriction.desc, "filter": restriction.filter,
		})

	# Pass 3a2: floating KEYWORD GRANTS (CR 613 layer 6) — before the
	# losses below, so "loses flying" still wins.
	for grant in _keyword_grants:
		var gains := game.find_instance(grant.instance_id)
		if gains == null or gains.zone != Mtg.Zone.BATTLEFIELD or gains.phased_out:
			continue
		for k in grant.keywords:
			if not gains.cur_keywords.has(k):
				gains.cur_keywords.append(k)

	# Pass 3a2b: GRANTED ACTIVATED ABILITIES (CR 613 layer 6), mostly
	# durationless (Life Matrix). Appended to the live list the same way a
	# static grant would, so a granted ability is activated, paid for and
	# silenced exactly like a printed one.
	for grant in _ability_grants:
		var armed := game.find_instance(grant.instance_id)
		if armed == null or armed.zone != Mtg.Zone.BATTLEFIELD \
				or armed.phased_out or armed.cur_abilities_silenced:
			continue
		armed.cur_activated_abilities.append(grant.ability)

	# Pass 3a3: floating PROTECTION grants (CR 613 layer 6).
	for shield in _protection_grants:
		var warded := game.find_instance(shield.instance_id)
		if warded == null or warded.zone != Mtg.Zone.BATTLEFIELD \
				or warded.phased_out:
			continue
		warded.cur_protection |= int(shield.colors)

	# Pass 3a4: floating DAMAGE IMMUNITIES (Silhouette) — into the same
	# per-instance list the statics write (Argothian Pixies, Wall of Vapor).
	for immunity in _damage_immunities:
		var guarded := game.find_instance(immunity.instance_id)
		if guarded == null or guarded.zone != Mtg.Zone.BATTLEFIELD \
				or guarded.phased_out:
			continue
		guarded.cur_damage_immunity.append({
			"desc": immunity.desc, "filter": immunity.filter,
		})

	# Pass 3b: ABILITY LOSSES (CR 613 layer 6) — applied after every
	# granting pass so "loses flying" beats a Flight cast earlier this turn.
	for loss in _losses:
		var victim := game.find_instance(loss.instance_id)
		if victim == null or victim.zone != Mtg.Zone.BATTLEFIELD or victim.phased_out:
			continue
		for k in loss.keywords:
			victim.cur_keywords.erase(k)
		if loss.keywords.has(Mtg.Keyword.BANDING):
			# CR 702.22b: losing banding loses every "bands with other" too.
			victim.cur_bands_with.clear()
		if loss.landwalk:
			victim.cur_landwalk.clear()
		for t in loss.get("landwalk_types", []):
			victim.cur_landwalk.erase(t)   # "loses swampwalk": that one only

	# Pass 3c: floating COMBAT-damage preventions (Lady Evangela, Horn of
	# Deafening) — the same instance flags Gaseous Form's static sets.
	for shield in _combat_prevention:
		var shielded := game.find_instance(shield.instance_id)
		if shielded == null or shielded.zone != Mtg.Zone.BATTLEFIELD or shielded.phased_out:
			continue
		if shield.dealt:
			shielded.cur_prevent_combat_damage_dealt = true
		if shield.taken:
			shielded.cur_prevent_combat_damage_taken = true
		if shield.get("all_damage", false):
			shielded.cur_prevent_all_damage_dealt = true
		if shield.get("all_damage_taken", false):
			shielded.cur_prevent_all_damage_taken = true

	# Pass 4: P/T SWITCHES (CR 613.4e) — the last sublayer, applied after
	# every other power/toughness modification, in creation order.
	for sw in _switches:
		var inst := game.find_instance(sw.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD or inst.phased_out:
			continue
		var p := inst.cur_power
		inst.cur_power = inst.cur_toughness
		inst.cur_toughness = p
