extends CardScript
## Glyph of Doom — {B} — Instant — (leg, common)
## Oracle: Choose target Wall creature. At this turn's next end of combat,
##         destroy all creatures that were blocked by that creature this
##         turn.
##
## Implementation: a delayed END-OF-COMBAT trigger (CR 603.7,
## MtgGame.schedule_delayed_trigger) controlled by the Glyph's caster
## (603.7d), reading the Wall's block history when it resolves — so
## creatures that become blocked AFTER the Glyph resolves are caught too,
## which is what "were blocked by that creature this turn" means. It goes
## on the stack with the step's other end-of-combat triggers in APNAP
## order (CR 603.3b) — players may respond to it — and it outlives the
## Glyph and the Wall alike (CR 603.7a). "This turn's next end of combat":
## it expires with the turn, so a Glyph cast after combat does nothing.


static func _is_wall(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall")


func build() -> CardData:
	return CardData.new("Glyph of Doom", "{B}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfDoomEffect.new(
			TargetSpec.creature("target Wall creature", _is_wall).only_walls(), _doom)) \
		.oracle("Choose target Wall creature. At this turn's next end of combat, destroy all creatures that were blocked by that creature this turn.")


## The delayed trigger's resolution: bury everything the Wall stopped this
## turn.
static func _doom(game: MtgGame, _source: CardInstance, _event: GameEvent,
		wall_id: int) -> void:
	var wall := game.find_instance(wall_id)
	if wall == null:
		return
	# ONE RESOLUTION, ONE BRACKET (CR 704.3, 2026-09-10): the delayed action
	# buries everything the Wall stopped in one go. Nothing may return
	# between the two calls — a deferral left open freezes state-based
	# actions for the rest of the game.
	game.begin_simultaneous()
	for attacker_id in wall.blocked_ids_this_turn:
		var victim := game.find_instance(attacker_id)
		if victim != null and victim.zone == Mtg.Zone.BATTLEFIELD:
			game.destroy(victim)
	game.end_simultaneous()


class GlyphOfDoomEffect extends EffectBase:
	var doom_action: Callable

	func _init(spec: TargetSpec, action: Callable) -> void:
		target_spec = spec
		doom_action = action

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var wall := game.find_instance(target.instance_id)
		if wall == null or wall.zone != Mtg.Zone.BATTLEFIELD:
			return
		var trigger := TriggeredAbility.new(Mtg.EventType.END_OF_COMBAT,
			doom_action.bind(wall.id),
			"At this turn's next end of combat, destroy all creatures that were blocked by that Wall this turn.")
		var entry := game.schedule_delayed_trigger(trigger, controller, source)
		entry["expires_turn"] = game.turn_number

	func describe() -> String:
		return "destroys everything target Wall blocked this turn, at end of combat"
