extends CardScript
## Merchant Ship — {U} — Creature — Human — 0/2 — (arn, uncommon)
## Oracle: This creature can't attack unless defending player controls an
##         Island.
##         Whenever this creature attacks and isn't blocked, you gain 2 life.
##         When you control no Islands, sacrifice this creature.
##
## Implementation: Dandân's two Island clauses plus Murk Dwellers'
## BLOCKERS_DECLARED trigger for the lifegain. A 0/2 that deals no damage
## and gains two life a turn — the era's most patient clock.


func build() -> CardData:
	return CardData.new("Merchant Ship", "{U}", Mtg.CardType.CREATURE) \
		.pt(0, 2) \
		.with_subtypes(["human"]) \
		.with_attack_needs_defender_land("island") \
		.with_sacrifice_if_no_land("island") \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.BLOCKERS_DECLARED, _profit,
			"Whenever Merchant Ship attacks and isn't blocked, you gain 2 life.",
			_attacking_unblocked)) \
		.oracle("This creature can't attack unless defending player controls an Island.\n"
			+ "Whenever this creature attacks and isn't blocked, you gain 2 life.\n"
			+ "When you control no Islands, sacrifice this creature.")


static func _attacking_unblocked(game: MtgGame, source: CardInstance,
		_event: GameEvent) -> bool:
	return game.combat.attackers.has(source.id) \
		and game.combat.blockers_of_band(game.combat.band_of(source.id)).is_empty()


static func _profit(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.adjust_life(source.controller_id, 2)
