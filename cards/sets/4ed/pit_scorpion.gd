extends CardScript
## Pit Scorpion — {2}{B} — Creature — Scorpion — 1/1 — (4ed, common)
## Oracle: Whenever this creature deals damage to a player, that player
##         gets a poison counter. (A player with ten or more poison
##         counters loses the game.)
##
## Implementation: a DAMAGE_DEALT trigger scoped to damage this creature
## dealt to a PLAYER — combat or otherwise. Poison lives on MtgPlayer and
## kills at ten as a state-based action (CR 704.5c).


func build() -> CardData:
	return CardData.new("Pit Scorpion", "{2}{B}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["scorpion"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _sting,
			"Whenever this creature deals damage to a player, that player gets a poison counter.",
			_my_damage_to_a_player)) \
		.oracle("Whenever this creature deals damage to a player, that player gets a poison counter. (A player with ten or more poison counters loses the game.)")


static func _my_damage_to_a_player(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("source") == source and event.data.has("to_player")


static func _sting(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.add_poison(int(event.data["to_player"]), 1)
