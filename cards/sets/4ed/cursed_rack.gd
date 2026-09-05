extends CardScript
## Cursed Rack — {4} — Artifact — (4ed, uncommon)
## Oracle: As this artifact enters, choose an opponent.
##         The chosen player's maximum hand size is four.
##
## Implementation: an ETB trigger remembering the chosen opponent in the
## Rack's card-local memory (in a duel there is exactly one, so the
## choice makes itself) plus a static writing that player's
## MtgPlayer.max_hand_size, which the cleanup step enforces.


func build() -> CardData:
	return CardData.new("Cursed Rack", "{4}", Mtg.CardType.ARTIFACT) \
		.static_ability(StaticAbility.new(
			_apply, "The chosen player's maximum hand size is four.")) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _choose,
			"As Cursed Rack enters, choose an opponent.",
			_is_self)) \
		.oracle("As this artifact enters, choose an opponent.\nThe chosen player's "
			+ "maximum hand size is four.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _choose(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	source.memory["victim"] = game.opponent_of(source.controller_id)
	game.recalculate()


static func _apply(game: MtgGame, source: CardInstance) -> void:
	var victim: int = int(source.memory.get("victim",
		game.opponent_of(source.controller_id)))
	game.players[victim].max_hand_size = 4
