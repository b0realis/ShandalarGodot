extends CardScript
## Serpent Generator — {6} — Artifact — (leg, rare)
## Oracle: {4}, {T}: Create a 1/1 colorless Snake artifact creature token.
##         It has "Whenever this creature deals damage to a player, that
##         player gets a poison counter." (A player with ten or more poison
##         counters loses the game.)
##
## Implementation: the token carries the poison trigger itself, so a Snake
## that outlives the Generator keeps poisoning. Its CardData is built once
## and shared by every Snake, like every other token in the pool.


static func _snake_data() -> CardData:
	return CardData.new("Snake", "", Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["snake"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.DAMAGE_DEALT, _sting,
			"Whenever this creature deals damage to a player, that player gets a poison counter.",
			_my_damage_to_a_player)) \
		.oracle("Whenever this creature deals damage to a player, that player gets a poison counter.")


static func _my_damage_to_a_player(_game: MtgGame, source: CardInstance,
		event: GameEvent) -> bool:
	return event.data.get("source") == source and event.data.has("to_player")


static func _sting(game: MtgGame, _source: CardInstance, event: GameEvent) -> void:
	game.add_poison(int(event.data["to_player"]), 1)


func build() -> CardData:
	return CardData.new("Serpent Generator", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{4}", true, [MakeSnakeEffect.new(_snake_data())],
			"{4}, {T}: Create a 1/1 colorless Snake artifact creature token with a poison trigger.")) \
		.oracle("{4}, {T}: Create a 1/1 colorless Snake artifact creature token. It has \"Whenever this creature deals damage to a player, that player gets a poison counter.\" (A player with ten or more poison counters loses the game.)")


class MakeSnakeEffect extends EffectBase:
	var snake: CardData

	func _init(p_snake: CardData) -> void:
		snake = p_snake

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.create_token(controller, snake)

	func describe() -> String:
		return "creates a 1/1 Snake artifact creature token"
