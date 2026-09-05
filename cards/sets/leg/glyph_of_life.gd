extends CardScript
## Glyph of Life — {W} — Instant — (leg, common)
## Oracle: Choose target Wall creature. Whenever that creature is dealt
##         damage by an attacking creature this turn, you gain that much
##         life.
##
## Implementation: a floating DAMAGE WATCH on the chosen Wall
## (MtgGame.watch_damage_for_life, attackers only), cleared at cleanup —
## so it keeps paying even after the Glyph itself is in the graveyard, and
## it pays for every attacker that gets through, not just the first.


static func _is_wall(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall")


func build() -> CardData:
	return CardData.new("Glyph of Life", "{W}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfLifeEffect.new(TargetSpec.creature("target Wall creature", _is_wall).only_walls())) \
		.oracle("Choose target Wall creature. Whenever that creature is dealt damage by an attacking creature this turn, you gain that much life.")


class GlyphOfLifeEffect extends EffectBase:
	func _init(spec: TargetSpec) -> void:
		target_spec = spec

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var wall := game.find_instance(target.instance_id)
		if wall == null or wall.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.watch_damage_for_life(wall, controller, true)

	func describe() -> String:
		return "you gain life equal to the damage attackers deal to target Wall this turn"
