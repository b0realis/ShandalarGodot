extends CardScript
## Glyph of Destruction — {R} — Instant — (leg, common)
## Oracle: Target blocking Wall you control gets +10/+0 until end of
##         combat. Prevent all damage that would be dealt to it this turn.
##         Destroy it at the beginning of the next end step.
##
## Implementation: three floating effects on one target — an until-end-of-
## COMBAT pump (CR 700.5), a this-turn "prevent all damage dealt to it"
## shield (the wave-48 cur_prevent_all_damage_taken flag), and the delayed
## end-step destruction the engine already uses for Berserk. The Wall kills
## what it blocks and then dies itself, exactly as printed.


static func _blocking_wall_you_control(game: MtgGame, source: CardInstance,
		inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall") \
		and inst.controller_id == source.controller_id \
		and game.combat.blocks.has(inst.id)


func build() -> CardData:
	var spec := TargetSpec.creature("target blocking Wall you control").only_walls()
	spec.with_source_filter(_blocking_wall_you_control)
	return CardData.new("Glyph of Destruction", "{R}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfDestructionEffect.new(spec)) \
		.oracle("Target blocking Wall you control gets +10/+0 until end of combat. Prevent all damage that would be dealt to it this turn. Destroy it at the beginning of the next end step.")


class GlyphOfDestructionEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var wall := game.find_instance(target.instance_id)
		if wall == null or wall.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.continuous.add_until_eot_pump(wall.id, 10, 0, [], true)
		game.continuous.add_until_eot_combat_prevention(
			wall.id, false, false, false, false, true)
		game.doom_at_next_end_step(wall)
		game.recalculate()

	func describe() -> String:
		return "target blocking Wall you control gets +10/+0, is indestructible to damage this turn, and dies at end of turn"
