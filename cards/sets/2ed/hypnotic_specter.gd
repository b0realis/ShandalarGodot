extends CardScript
## Hypnotic Specter — {1}{B}{B} — Creature — Specter — 2/2 (2ed, uncommon)
## Oracle: Flying
##         Whenever this creature deals damage to an opponent, that player
##         discards a card at random.
##
## Implementation: flying + a triggered ability listening for DAMAGE_DEALT.
## The condition narrows to "this specter, to a player, and that player is
## an opponent of its controller" — so it fires on combat damage AND any
## other damage it deals. The random discard uses the game RNG
## (deterministic under a seed). "Hyppie" — the backbone of the dos486
## reference deck; the AI will meet it often.


func build() -> CardData:
	return CardData.new("Hypnotic Specter", "{1}{B}{B}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["specter"]) \
		.with_keywords([Mtg.Keyword.FLYING]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT,
			_on_damage,
			"Whenever this creature deals damage to an opponent, that player discards a card at random.",
			_is_my_damage_to_opponent)) \
		.oracle("Flying\nWhenever this creature deals damage to an opponent, that player discards a card at random.")


static func _is_my_damage_to_opponent(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("source") == source \
		and event.data.has("to_player") \
		and event.data["to_player"] != source.controller_id


static func _on_damage(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.discard_random(event.data["to_player"])
