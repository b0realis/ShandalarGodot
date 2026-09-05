extends CardScript
## Thicket Basilisk — {3}{G}{G} — Creature — Basilisk — 2/4 — (2ed, uncommon)
## Oracle: Whenever this creature blocks or becomes blocked by a non-Wall
##         creature, destroy that creature at end of combat.
##
## Implementation: the BASILISK-GAZE pattern — a BLOCKED trigger matching
## either direction (self as blocker OR as attacker) whose victim is the
## other, non-Wall creature; the kill is queued in the engine's
## end-of-combat doom list (regeneration applies — it's a destruction).


func build() -> CardData:
	return CardData.new("Thicket Basilisk", "{3}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["basilisk"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gaze,
			"Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.",
			_meets_non_wall)) \
		.oracle("Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.")


static func _other(source: CardInstance, event: GameEvent) -> CardInstance:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	if attacker == source:
		return blocker
	if blocker == source:
		return attacker
	return null


static func _meets_non_wall(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var other := _other(source, event)
	return other != null and not other.has_subtype("wall")


static func _gaze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var other := _other(source, event)
	if other != null and other.zone == Mtg.Zone.BATTLEFIELD:
		game.doom_at_end_of_combat(other)
