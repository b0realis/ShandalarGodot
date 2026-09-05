extends CardScript
## Infernal Medusa — {3}{B}{B} — Creature — Gorgon — 2/4 — (leg, uncommon)
## Oracle: Whenever this creature blocks a creature, destroy that creature
##         at end of combat.
##         Whenever this creature becomes blocked by a non-Wall creature,
##         destroy that creature at end of combat.
##
## Implementation: a BLOCKED trigger (one event per declared pair) that
## reads which side the Medusa is on and condemns the other creature with
## MtgGame.doom_at_end_of_combat — regeneration applies, since the gaze
## is a destruction. Non-Wall only on the attacking side, exactly as
## printed.


func build() -> CardData:
	return CardData.new("Infernal Medusa", "{3}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 4) \
		.with_subtypes(["gorgon"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKED, _gaze,
			"Whenever Infernal Medusa blocks a creature (or becomes blocked by a "
			+ "non-Wall creature), destroy that creature at end of combat.",
			_involved)) \
		.oracle("Whenever this creature blocks a creature, destroy that creature at "
			+ "end of combat.\nWhenever this creature becomes blocked by a non-Wall "
			+ "creature, destroy that creature at end of combat.")


static func _involved(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	if event.data.get("blocker") == source:
		return true
	if event.data.get("attacker") == source:
		var blocker: CardInstance = event.data.get("blocker")
		return blocker != null and not blocker.has_subtype("wall")
	return false


static func _gaze(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var victim: CardInstance = event.data.get("attacker") \
		if event.data.get("blocker") == source else event.data.get("blocker")
	if victim != null and victim.zone == Mtg.Zone.BATTLEFIELD:
		game.doom_at_end_of_combat(victim)
