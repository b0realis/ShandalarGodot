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
##
## THE HISTORY OUTLIVES THE WALL (bug hunt 2026-10-21; the bug campaign
## c12, h3-7). A Wall that dies loses its block history with the rest of
## its battlefield state, so the card's main use — a 0/3 Wall trading with
## the Hill Giant it blocked — used to kill nothing. The trigger now reads
## the turn's block pairs ([member MtgGame.combat_pair_history]), which are
## kept with both creatures' timestamps and outlive deaths, bounces and the
## end of combat: every creature that Wall — the object the Glyph targeted
## (CR 400.7) — blocked this turn, before or after the Glyph resolved,
## whether or not the Wall is still there. A blocked creature that has
## since left the battlefield and come back is a new object and is spared.
## Until c12 a Glyph cast BEFORE the blocks on a Wall that then died killed
## nothing (the history it kept was taken as it resolved).


static func _is_wall(inst: CardInstance) -> bool:
	return inst.is_creature() and inst.has_subtype("wall")


func build() -> CardData:
	return CardData.new("Glyph of Doom", "{B}", Mtg.CardType.INSTANT) \
		.spell(GlyphOfDoomEffect.new(
			TargetSpec.creature("target Wall creature", _is_wall).only_walls(), _doom)) \
		.oracle("Choose target Wall creature. At this turn's next end of combat, destroy all creatures that were blocked by that creature this turn.")


## The delayed trigger's resolution: bury everything the Wall stopped this
## turn — every block pair whose blocker is that Wall (id + timestamp), a
## band's every member included (CR 702.22h: blocking one member blocks
## the band; the ledger holds one pair per member).
static func _doom(game: MtgGame, _source: CardInstance, _event: GameEvent,
		wall_id: int, wall_stamp: int) -> void:
	var stopped := {}   # attacker id -> its timestamp when it was blocked
	for pair in game.combat_pair_history:
		if int(pair.blocker) == wall_id and int(pair.blocker_stamp) == wall_stamp:
			stopped[int(pair.attacker)] = int(pair.attacker_stamp)
	var doomed: Array[CardInstance] = []
	for attacker_id in stopped:
		var victim := game.find_instance(int(attacker_id))
		if game.is_present(victim) and victim.layer_timestamp == int(stopped[attacker_id]):
			doomed.append(victim)
	# ONE RESOLUTION, ONE DEPARTURE (CR 704.3, 2026-09-10; c12, h3-3): the
	# delayed action buries everything the Wall stopped at once, each as the
	# board stood before any of them left.
	game.depart_together(doomed, func(victim: CardInstance) -> void: game.destroy(victim))


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
			doom_action.bind(wall.id, wall.layer_timestamp),
			"At this turn's next end of combat, destroy all creatures that were blocked by that Wall this turn.")
		var entry := game.schedule_delayed_trigger(trigger, controller, source)
		entry["expires_turn"] = game.turn_number

	func describe() -> String:
		return "destroys everything target Wall blocked this turn, at end of combat"
