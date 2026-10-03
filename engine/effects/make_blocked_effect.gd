class_name MakeBlockedEffect
extends EffectBase
## "Target unblocked attacking creature BECOMES BLOCKED" (Dazzling Beauty)
## and "X target attacking creatures become blocked. Choking Vines deals 1
## damage to each of those creatures" (Choking Vines) — CR 509.1h: an
## effect may make an attacking creature a blocked creature with no
## creature blocking it. See [method MtgGame.make_blocked] for what that
## means at the damage step (nothing, unless it tramples — CR 702.19e),
## for banding (the whole band, 702.22i) and for which triggers hear it
## (BECOMES_BLOCKED yes; flanking and other "blocked by a creature"
## triggers no, CR 509.3d).
##
## It works on a creature that "can't be blocked" — that ability restricts
## DECLARING blockers (CR 509.1b), not this — and it is targeted, so
## shroud and protection still refuse the target.
##
## Build:
##   MakeBlockedEffect.new()                      # "target unblocked attacking creature"
##   MakeBlockedEffect.attacking().x_targets()    # "X target attacking creatures"
##   ....then_damage(1)                           # "...deals 1 damage to each of those"
## The "cast only during the declare blockers step" half is the card's
## (`CardData.castable_only_when`).

## Damage the effect's SOURCE deals to each of its targets after making it
## blocked ("Choking Vines deals 1 damage to each of those creatures").
## 0 = none.
var damage_each: int = 0


func _init(spec: TargetSpec = null) -> void:
	target_spec = spec if spec != null else unblocked_attacker_spec()


## "target attacking creature" — blocked or not (Choking Vines). Making an
## already-blocked creature blocked changes nothing, but it is a legal
## target and still takes the rider's damage.
static func attacking() -> MakeBlockedEffect:
	return MakeBlockedEffect.new(attacker_spec())


## The spec "target unblocked attacking creature" (Dazzling Beauty).
static func unblocked_attacker_spec() -> TargetSpec:
	return TargetSpec.creature("target unblocked attacking creature") \
		.with_game_filter(_is_unblocked_attacker).because("blocked")


## The spec "target attacking creature".
static func attacker_spec() -> TargetSpec:
	return TargetSpec.creature("target attacking creature") \
		.with_game_filter(_is_attacker).because("attacking")


static func _is_attacker(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)


static func _is_unblocked_attacker(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id) \
		and not game.combat.was_blocked(game.combat.band_of(inst.id))


## Fluent: "...deals [param amount] damage to each of those creatures".
func then_damage(amount: int) -> MakeBlockedEffect:
	damage_each = amount
	return self


func resolve(game: MtgGame, source: CardInstance, _controller: int,
		target: TargetRef, _x_value: int = 0) -> void:
	if target == null or target.is_player:
		return
	var attacker := game.find_instance(target.instance_id)
	if attacker == null or attacker.zone != Mtg.Zone.BATTLEFIELD:
		return
	game.make_blocked(attacker)
	if damage_each > 0:
		game.deal_damage(source, target, damage_each)


func describe() -> String:
	var line := "%s becomes blocked" % target_spec.description
	if damage_each > 0:
		line += "; %d damage to each" % damage_each
	return line
