extends CardScript
## Cockatrice — {3}{G}{G} — Creature — Cockatrice — 2/4 — (2ed, rare)
## Oracle: Flying
##         Whenever this creature blocks or becomes blocked by a non-Wall
##         creature, destroy that creature at end of combat.
##
## Implementation: Thicket Basilisk with wings (see thicket_basilisk.gd
## for the gaze pattern) — it can block flyers and petrify them too.


func build() -> CardData:
	return CardData.new("Cockatrice", "{3}{G}{G}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["cockatrice"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gaze,
			"Whenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.",
			_meets_non_wall)) \
		.oracle("Flying\nWhenever this creature blocks or becomes blocked by a non-Wall creature, destroy that creature at end of combat.")


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
