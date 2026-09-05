extends CardScript
## Glyph of Doom — {B} — Instant — (leg, common)
## Oracle: Choose target Wall creature. At this turn's next end of combat,
##         destroy all creatures that were blocked by that creature this
##         turn.
##
## Implementation: a delayed END-OF-COMBAT action
## (MtgGame.schedule_end_of_combat_action) reading the Wall's block history
## when it fires — so creatures that become blocked AFTER the Glyph
## resolves are caught too, which is what "were blocked by that creature
## this turn" means. The action outlives the Glyph and the Wall alike
## (CR 603.7a).


static func _is_wall(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall")


func build() -> CardData:
	return CardData.new("Glyph of Doom", "{B}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfDoomEffect.new(
			TargetSpec.creature("target Wall creature", _is_wall).only_walls(), _doom)) \
		.oracle("Choose target Wall creature. At this turn's next end of combat, destroy all creatures that were blocked by that creature this turn.")


## The delayed action: bury everything the Wall stopped this turn.
static func _doom(game: MtgGame, wall_id: int) -> void:
	var wall := game.find_instance(wall_id)
	if wall == null:
		return
	for attacker_id in wall.blocked_ids_this_turn:
		var victim := game.find_instance(attacker_id)
		if victim != null and victim.zone == Mtg.Zone.BATTLEFIELD:
			game.destroy(victim)


class GlyphOfDoomEffect extends EffectBase:
	var doom_action: Callable

	func _init(spec: TargetSpec, action: Callable) -> void:
		target_spec = spec
		doom_action = action

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var wall := game.find_instance(target.instance_id)
		if wall == null or wall.zone != Mtg.Zone.BATTLEFIELD:
			return
		game.schedule_end_of_combat_action(doom_action.bind(wall.id))

	func describe() -> String:
		return "destroys everything target Wall blocked this turn, at end of combat"
