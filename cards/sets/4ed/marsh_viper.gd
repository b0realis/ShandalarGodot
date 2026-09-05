extends CardScript
## Marsh Viper — {3}{G} — Creature — Snake — 1/2 — (4ed, common)
## Oracle: Whenever this creature deals damage to a player, that player
##         gets two poison counters. (A player with ten or more poison
##         counters loses the game.)
##
## Implementation: Pit Scorpion with a bigger dose — five connections and
## the poison clock runs out.


func build() -> CardData:
	return CardData.new("Marsh Viper", "{3}{G}", Mtg.CardType.CREATURE) \
		.pt(1, 2) \
		.with_subtypes(["snake"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _bite,
			"Whenever this creature deals damage to a player, that player gets two poison counters.",
			_my_damage_to_a_player)) \
		.oracle("Whenever this creature deals damage to a player, that player gets two poison counters. (A player with ten or more poison counters loses the game.)")


static func _my_damage_to_a_player(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("source") == source and event.data.has("to_player")


static func _bite(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.add_poison(int(event.data["to_player"]), 2)
