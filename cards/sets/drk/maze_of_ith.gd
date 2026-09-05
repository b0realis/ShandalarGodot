extends CardScript
## Maze of Ith — Land — (drk, uncommon)
## Oracle: {T}: Untap target attacking creature. Prevent all combat damage
##         that would be dealt to and dealt by that creature this turn.
##
## Implementation: the untap plus BOTH prevention directions, through the
## same floating combat-damage shield Gaseous Form and Lady Evangela use —
## so the creature stays in combat (it is still an attacker, and still
## blocked) but nothing it meets that turn takes or deals a point.


static func _is_attacking(game: MtgGame, inst: CardInstance) -> bool:
	return game.combat.attackers.has(inst.id)


func build() -> CardData:
	var spec := TargetSpec.creature("target attacking creature")
	spec.with_game_filter(_is_attacking)
	return CardData.new("Maze of Ith", "", Mtg.CardType.LAND) \
		.activated(ActivatedAbility.new("", true, [MazeEffect.new(spec)],
			"{T}: Untap target attacking creature. Prevent all combat damage that would be dealt to and dealt by that creature this turn.")) \
		.oracle("{T}: Untap target attacking creature. Prevent all combat damage that would be dealt to and dealt by that creature this turn.")


class MazeEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var lost := game.find_instance(target.instance_id)
		if lost == null or lost.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.untap_permanent(lost)
		game.continuous.add_until_eot_combat_prevention(lost.id, true, true)
		game.recalculate()

	func describe() -> String:
		return "untaps target attacking creature and calls off its fight"
