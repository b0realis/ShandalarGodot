extends CardScript
## El-Hajjâj — {1}{B}{B} — Creature — Human Wizard — 1/1 — (4ed, rare)
## Oracle: Whenever this creature deals damage, you gain that much life.
##
## Implementation: a SOURCE_DEALT_DAMAGE trigger conditioned on the source
## being itself — combat and noncombat damage alike; the gain equals the
## event's post-prevention amount, exactly what was dealt. One trigger for
## all the damage it deals at once (CR 510.2, 603.2c), as 1997's own
## El-Hajjâj gathered every damage card of the event and resolved once
## (the bug campaign c12, h3-8: it triggered once per damage packet, so a
## double-blocked El-Hajjâj triggered twice).


func build() -> CardData:
	return CardData.new("El-Hajjâj", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "wizard"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.SOURCE_DEALT_DAMAGE, _drink,
			"Whenever this creature deals damage, you gain that much life.",
			_dealt_by_self)) \
		.oracle("Whenever this creature deals damage, you gain that much life.")


static func _dealt_by_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["source"] == source


static func _drink(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.adjust_life(source.controller_id, event.data["amount"])
