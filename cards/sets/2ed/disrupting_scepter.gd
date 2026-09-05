extends CardScript
## Disrupting Scepter — {3} — Artifact (2ed, rare)
## Oracle: {3}, {T}: Target player discards a card. Activate only during
##         your turn.
##
## Implementation: the OPPONENT-CHOOSES pattern — the TARGET player's
## DecisionAgent picks which card they discard (as the rules say), via a
## card-local effect. "Activate only during your turn" is the engine's own
## `your_turn_only()` rider, refused before any cost is paid.


func build() -> CardData:
	return CardData.new("Disrupting Scepter", "{3}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true,
			[ScepterEffect.new()],
			"{3}, {T}: Target player discards a card. Activate only during your turn.") \
			.your_turn_only()) \
		.oracle("{3}, {T}: Target player discards a card. Activate only during your turn.")


class ScepterEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		if game.players[pid].hand.is_empty():
			return
		var chosen := game.agents[pid].choose_discard(game, pid, 1)
		game.discard_cards(pid, chosen)

	func describe() -> String:
		return "target player discards a card (their choice)"
