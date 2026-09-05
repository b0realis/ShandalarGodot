extends CardScript
## El-Hajjâj — {1}{B}{B} — Creature — Human Wizard — 1/1 — (4ed, rare)
## Oracle: Whenever this creature deals damage, you gain that much life.
##
## Implementation: a DAMAGE_DEALT trigger conditioned on the source being
## itself — combat and noncombat damage alike; the gain equals the event's
## post-prevention amount, exactly what was dealt.


func build() -> CardData:
	return CardData.new("El-Hajjâj", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human", "wizard"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _drink,
			"Whenever this creature deals damage, you gain that much life.",
			_dealt_by_self)) \
		.oracle("Whenever this creature deals damage, you gain that much life.")


static func _dealt_by_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data["source"] == source


static func _drink(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.adjust_life(source.controller_id, event.data["amount"])
