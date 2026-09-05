class_name LoseAbilityEffect
extends EffectBase
## "Target creature loses [ability] until end of turn." — Hammerheim
## (all landwalk), Urborg (first strike / swampwalk), Tolaria (banding),
## and Wall of Wonder's self-targeting "as though it didn't have defender".
##
## Registers a floating loss in game.continuous, applied after every
## ability-GRANTING pass, so it also strips a keyword an aura or an
## earlier pump handed out this turn.

## Keywords (Mtg.Keyword values) removed while the effect lasts.
var keywords: Array[int] = []

## When true the creature loses ALL landwalk abilities (Hammerheim).
var all_landwalk: bool = false

## The landwalk TYPES the creature loses ("swamp" for Urborg's "loses
## swampwalk", "forest" for Scarwood Hag's) — that one landwalk and no
## other, so an islandwalking victim keeps its islandwalk.
var landwalk_types: Array[String] = []

## When true the loss lands on the effect's SOURCE instead of a target
## (Wall of Wonder shedding its own defender).
var self_mode: bool = false

## Card-English name of what is lost, for logs and describe().
var what: String = "its abilities"


func _init(p_keywords: Array = [], p_what := "", p_spec: TargetSpec = null) -> void:
	for k in p_keywords:
		keywords.append(k)
	if p_what != "":
		what = p_what
	target_spec = p_spec if p_spec != null else TargetSpec.creature()


## Fluent: also (or instead) strip every landwalk ability.
func and_landwalk() -> LoseAbilityEffect:
	all_landwalk = true
	return self


## Fluent: also (or instead) strip the landwalk of [param types] only —
## `["swamp"]` is "loses swampwalk".
func and_landwalk_of(types: Array) -> LoseAbilityEffect:
	for t in types:
		landwalk_types.append(String(t))
	return self


## Fluent: apply to the effect's own source, with no target.
func to_source() -> LoseAbilityEffect:
	self_mode = true
	target_spec = null
	return self


## Registers the loss with game.continuous
## ([method ContinuousEffects.add_until_eot_loss]) and recalculates, which
## strips the keywords from the victim's live cur_keywords / cur_landwalk.
## Nothing on the CardData is touched — the printed ability comes back at
## cleanup, and a second copy of the card is unaffected.
func resolve(game: MtgGame, source: CardInstance, _controller: int, target: TargetRef,
		_x_value: int = 0) -> void:
	var affected := source if self_mode else game.find_instance(target.instance_id)
	if affected == null or affected.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.continuous.add_until_eot_loss(affected.id, keywords, all_landwalk,
		false, landwalk_types)
	game.log_line("%s loses %s until end of turn" % [affected.data.card_name, what])
	game.recalculate()


## One-line log/UI text.
func describe() -> String:
	if self_mode:
		return "loses %s until end of turn" % what
	return "%s loses %s until end of turn" % [target_spec.description, what]
