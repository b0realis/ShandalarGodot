extends CardScript
## Abu Ja'far — {W} — Creature — Human — 0/1 — (arn, uncommon)
## Oracle: When this creature dies, destroy all creatures blocking or
##         blocked by it. They can't be regenerated.
##
## Implementation: a DIES trigger reading the live combat map for every
## creature paired with Abu Ja'far and destroying them with
## can_regenerate = false. A one-mana 0/1 that eats anything that touches
## it — the reason nobody ever attacked into it.


func build() -> CardData:
	return CardData.new("Abu Ja'far", "{W}", Mtg.CardType.CREATURE) \
		.pt(0, 1) \
		.with_subtypes(["human"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DIES, _curse,
			"When Abu Ja'far dies, destroy all creatures blocking or blocked by it. "
			+ "They can't be regenerated.",
			_is_self)) \
		.oracle("When this creature dies, destroy all creatures blocking or blocked "
			+ "by it. They can't be regenerated.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _curse(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	var doomed: Array[int] = []
	# Both directions, and every one of them: a creature may block more
	# than one attacker (CR 509.1b), so "blocking or blocked by" is two
	# lists rather than two comparisons.
	for id in game.combat.attackers_blocked_by(source.id):
		doomed.append(int(id))
	for id in game.combat.blockers_of(source.id):
		if not doomed.has(int(id)):
			doomed.append(int(id))
	for id in doomed:
		var victim := game.find_instance(id)
		if victim != null and victim.zone == Mtg.Zone.BATTLEFIELD:
			game.destroy(victim, false)
