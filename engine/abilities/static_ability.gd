class_name StaticAbility
extends RefCounted
## A static ability contributing a continuous effect while its source is on
## the battlefield — e.g. Holy Strength's "Enchanted creature gets +1/+2",
## or Crusade's "White creatures get +1/+1".
##
## Static abilities do not resolve; they simply ARE. On every
## ContinuousEffects.recalculate() pass the engine calls [member apply] for
## each battlefield permanent's static abilities, letting it mutate the
## cur_* characteristics of whatever it affects:
## [code]func(game: MtgGame, source: CardInstance) -> void[/code]
##
## Ordering: ContinuousEffects runs statics in three passes that stand in
## for the CR 613 layers — first the ones that change TYPES (layer 4, tagged
## with [method changing_types]), then the base-P/T SETTERS (layer 7a/7b,
## [method setting_base_pt]), then everything else (layer 7c and the rest).
## Within a pass, battlefield timestamp order decides. Anything a card does
## not tag lands in the last pass, which is right for the additive majority.
##
## Two floating (until-end-of-turn) passes are interleaved between those
## three, and a static must expect to be on the losing side of both: the
## layer-7b base-P/T SETS (Island of Wak-Wak) run right after the setter
## pass and therefore beat a characteristic-defining static, and the layer-5
## COLOUR changes (Dwarven Song) run right after those, so the last pass of
## statics — the anthems — already sees the repainted colours.
##
## A source whose abilities were silenced (Titania's Song, a layer-6 effect
## applied in the first pass) contributes nothing in the later passes — the
## pipeline skips it, so a static never has to check whether it still exists.
##
## The remaining approximations (no full dependency analysis beyond the two
## layer-4 rounds, CR 613.8) are documented in docs/ROADMAP.md.

## func(game, source) -> void; adjust cur_power/cur_toughness/cur_keywords
## of affected instances. Runs on every recalculation, always from printed
## base values — never accumulate.
var apply: Callable

## Card-English text, for UI and logs.
var text: String = ""

## Does this static SET a base power/toughness rather than modify one?
## Characteristic-defining abilities ("Nightmare's power and toughness are
## each equal to the number of Swamps you control") and animations ("each
## Swamp is a 1/1 creature") live in CR 613 sublayer 7b and must run
## BEFORE additive boosts in 7c (Crusade, Bad Moon) whatever their
## timestamps — otherwise an anthem that entered first is silently
## overwritten and the answer depends on play order. ContinuousEffects
## runs the setters in their own pass; within each pass timestamp order
## still decides. Mark such an ability with [method setting_base_pt].
var sets_base_pt: bool = false

## Fluent: mark this static as a CR 613 layer-7b base-P/T setter.
func setting_base_pt() -> StaticAbility:
	sets_base_pt = true
	return self


## Does this static change what an object IS — its card types or subtypes
## (CR 613 layer 4)? "Nonbasic lands are Mountains" (Blood Moon),
## "enchanted land is a Swamp" (Evil Presence), "all Swamps are 1/1
## creatures" (Kormus Bell), "all artifacts are creatures" (Titania's
## Song). Layer 4 precedes every P/T layer, so these run in their own
## FIRST pass: otherwise a P/T ability that counts Swamps (Nightmare) or
## animates them reads the board before the retuning happened, and the
## answer depends on which permanent entered first. An ability that both
## retypes and sets P/T (Kormus Bell) belongs here — its P/T write is
## still ahead of every 7c anthem.
var changes_types: bool = false

## Fluent: mark this static as a CR 613 layer-4 type changer.
func changing_types() -> StaticAbility:
	changes_types = true
	return self


## Does this static RETYPE lands — replace their basic land types
## ("nonbasic lands are Mountains", "enchanted land is a Swamp")? These run
## BEFORE the other layer-4 statics, because everything that animates or
## counts land types (Kormus Bell, Living Lands, Nightmare) has to see the
## retuned board: that ordering is the CR 613.8 dependency between the two,
## resolved by construction instead of by analysis.
var changes_land_types: bool = false

## Fluent: mark this static as a land RETYPER (implies [member changes_types]).
func changing_land_types() -> StaticAbility:
	changes_land_types = true
	changes_types = true
	return self


## Does this static REMOVE abilities (CR 613 layer 6 — Titania's Song's
## "each noncreature artifact loses all abilities")? Layer 6 precedes every
## P/T layer, and an ability that has been removed contributes nothing in
## ANY layer, so these run FIRST and every later pass skips a source whose
## abilities are gone.
var silences_abilities: bool = false

## Fluent: mark this static as an ability remover.
func silencing_abilities() -> StaticAbility:
	silences_abilities = true
	return self


## Mtg.EventType values of the TRIGGERED abilities this static grants to
## other permanents (Energy Flux's upkeep tax on every artifact). The
## dispatcher's early-out index is rebuilt from the printed lists when the
## battlefield changes — before the grants of that recalculation exist —
## so a granting static declares what it hands out and the index counts
## it while the source is on the battlefield.
var grants_trigger_types: Array[int] = []

## Fluent: declare the event types of the triggers this static grants.
func granting_triggers(event_types: Array) -> StaticAbility:
	for t in event_types:
		grants_trigger_types.append(int(t))
	return self


func _init(p_apply: Callable, p_text: String = "") -> void:
	apply = p_apply
	text = p_text


func _to_string() -> String:
	return text if text != "" else "static ability"
