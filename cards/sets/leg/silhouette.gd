extends CardScript
## Silhouette — {1}{U} — Instant — (leg, uncommon)
## Oracle: Choose target creature. If a spell or ability that targets that
##         creature would cause a source to deal damage to that creature
##         this turn, prevent that damage.
##
## Implementation: a floating until-end-of-turn DAMAGE IMMUNITY
## (ContinuousEffects.add_until_eot_damage_immunity, new) applied into the
## same CardInstance.cur_damage_immunity list the statics write — so the
## check runs on the ordinary damage path and nothing card-specific reaches
## into MtgGame.
##
## The filter is the interesting half, and it is two questions: is the
## source a SPELL or an ABILITY currently resolving, and does the resolving
## object's own target list name this creature (MtgGame.current_targets)?
## A Lightning Bolt aimed at it is prevented; an Earthquake, which targets
## nothing, is not; and combat damage, which no spell or ability caused, is
## not either. That is the whole card: it answers removal, not blockers.


func build() -> CardData:
	return CardData.new("Silhouette", "{1}{U}", Mtg.CardType.INSTANT) \
		.spell(SilhouetteEffect.new()) \
		.oracle("Choose target creature. If a spell or ability that targets that "
			+ "creature would cause a source to deal damage to that creature this "
			+ "turn, prevent that damage.")


class SilhouetteEffect extends EffectBase:
	func _init() -> void:
		is_damage_prevention = true   # legal in the 1997 window (§6.8)
		target_spec = TargetSpec.creature()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var inst := game.find_instance(target.instance_id)
		if inst == null or inst.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_damage_immunity(inst.id,
			"spells and abilities that target it",
			SilhouetteEffect._aimed_at.bind(inst.id))
		game.recalculate()
		game.log_line("%s fades to a silhouette" % inst.data.card_name)

	## Damage caused by a spell or ability that NAMED this creature as one
	## of its targets. Combat damage and untargeted sweepers get through.
	static func _aimed_at(game: MtgGame, damage_source: CardInstance,
			guarded_id: int) -> bool:
		var targets := game.current_targets()
		if targets.is_empty():
			return false   # nothing is resolving, or it targets nothing
		if damage_source == null:
			return false
		for ref in targets:
			if not ref.is_player and not ref.is_damage and not ref.is_ability \
					and ref.instance_id == guarded_id:
				return true
		return false

	func describe() -> String:
		return "prevents damage from spells and abilities that target it"
