extends CardScript
## The Wretched — {3}{B}{B} — Creature — Demon — 2/5 — (leg, rare)
## Oracle: At end of combat, gain control of all creatures blocking this
##         creature for as long as you control this creature.
##
## Implementation: an END_OF_COMBAT trigger — which fires while blocking
## assignments still stand — leashing every surviving blocker to The
## Wretched. A 2/5 body that turns every chump block into a permanent
## trade in its controller's favour.
##
## "Blocking this creature" is BAND-WIDE (CR 702.22h): banded with a
## Benalish Hero, The Wretched is blocked by whatever blocks the Hero. And
## a Wretched that has LEFT combat (regenerated, removed) is blocked by
## nothing (CR 506.4), though its blockers' entries still name it. Until
## the bug hunt of 2026-10-21 it read only the blocks declared at it.


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
	return not _blockers(game, source).is_empty()


## Every creature blocking The Wretched now: the blockers of its band, while
## it is still in combat.
static func _blockers(game: MtgGame, source: CardInstance) -> Array[int]:
	var none: Array[int] = []
	if not game.combat.attackers.has(source.id):
		return none
	return game.combat.blockers_of_band(game.combat.band_of(source.id))


static func _collect(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	if source.zone != Mtg.Zone.BATTLEFIELD:
		return
	var prizes := _blockers(game, source)
	for id in prizes:
		var blocker := game.find_instance(id)
		if blocker != null and blocker.zone == Mtg.Zone.BATTLEFIELD:
			game.gain_control_leashed(blocker, source, false)
