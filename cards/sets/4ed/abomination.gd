extends CardScript
## Abomination — {3}{B}{B} — Creature — Horror — 2/6 — (4ed, uncommon)
## Oracle: Whenever this creature blocks or becomes blocked by a green or
##         white creature, destroy that creature at end of combat.
##
## Implementation: the basilisk-gaze pattern (thicket_basilisk.gd) with a
## COLOR condition instead of the non-Wall clause — green and white
## creatures die at end of combat; everything else just bounces off the
## 2/6 frame.


func build() -> CardData:
	return CardData.new("Abomination", "{3}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 6) \
		.with_subtypes(["horror"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gaze,
			"Whenever this creature blocks or becomes blocked by a green or white creature, destroy that creature at end of combat.",
			_meets_green_or_white)) \
		.oracle("Whenever this creature blocks or becomes blocked by a green or white creature, destroy that creature at end of combat.")


static func _other(source: CardInstance, event: GameEvent) -> CardInstance:
	var attacker: CardInstance = event.data["attacker"]
	var blocker: CardInstance = event.data["blocker"]
	if attacker == source:
		return blocker
	if blocker == source:
		return attacker
	return null


static func _meets_green_or_white(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	var other := _other(source, event)
	return other != null \
		and (other.cur_colors & (Mtg.ManaColor.G | Mtg.ManaColor.W)) != 0


static func _gaze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var other := _other(source, event)
	if other != null and other.zone == Mtg.Zone.BATTLEFIELD:
		game.doom_at_end_of_combat(other)
