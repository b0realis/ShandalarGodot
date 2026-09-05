extends CardScript
## The Wretched — {3}{B}{B} — Creature — Demon — 2/5 — (leg, rare)
## Oracle: At end of combat, gain control of all creatures blocking this
##         creature for as long as you control this creature.
##
## Implementation: an END_OF_COMBAT trigger — which fires while blocking
## assignments still stand — leashing every surviving blocker to The
## Wretched. A 2/5 body that turns every chump block into a permanent
## trade in its controller's favour.


func build() -> CardData:
	return CardData.new("The Wretched", "{3}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 5) \
		.with_subtypes(["demon"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.END_OF_COMBAT, _collect,
			"At end of combat, gain control of all creatures blocking The Wretched "
			+ "for as long as you control it.",
			_was_blocked)) \
		.oracle("At end of combat, gain control of all creatures blocking this "
			+ "creature for as long as you control this creature.")


static func _was_blocked(game: MtgGame, source: CardInstance, _event: GameEvent) -> bool:
	return not game.combat.blockers_of(source.id).is_empty()


static func _collect(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var prizes := game.combat.blockers_of(source.id)
	for id in prizes:
		var blocker := game.find_instance(id)
		if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(blocker, source, false)
