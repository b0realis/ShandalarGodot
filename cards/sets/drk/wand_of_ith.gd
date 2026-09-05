extends CardScript
## Wand of Ith — {4} — Artifact — (drk, uncommon)
## Oracle: {3}, {T}: Target player reveals a card at random from their hand.
##         If it's a land card, that player discards it unless they pay 1
##         life. If it isn't a land card, the player discards it unless they
##         pay life equal to its mana value. Activate only during your turn.
##
## Implementation: a repeatable Mind Twist priced in life. The card is
## drawn from the hand through the game RNG (RandomEffects.pick, so a seed
## reproduces the pick), and the ransom is that card's own mana value —
## 1 for a land, its printed cost for anything else, which is what makes
## the Wand hurt most against the expensive cards it is most likely to hit.
##
## The ransom is the VICTIM's choice, so the offer goes to their agent;
## the engine's default keeps the card while the life is not lethal.


func build() -> CardData:
	return CardData.new("Wand of Ith", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true, [WandEffect.new()],
			"{3}, {T}: Target player reveals a card at random from their hand and discards it unless they pay life equal to its mana value (1 for a land). Activate only during your turn.") \
			.your_turn_only()) \
		.oracle("{3}, {T}: Target player reveals a card at random from their hand. If it's "
			+ "a land card, that player discards it unless they pay 1 life. If it isn't a "
			+ "land card, the player discards it unless they pay life equal to its mana "
			+ "value. Activate only during your turn.")


class WandEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pid := target.player_id
		var hand := game.players[pid].hand
		if hand.is_empty():
			return
		var revealed: CardInstance = RandomEffects.pick(game, hand)
		if revealed == null:
			return
		var toll := 1 if revealed.data.is_land() else revealed.data.cost.mana_value()
		game.log_line("%s reveals %s to %s" % [
			game.players[pid].player_name, revealed.data.card_name,
			source.data.card_name])
		# The engine's default: keep the card while the life can be spared.
		var hint: bool = game.players[pid].life > toll + 2
		if toll < game.players[pid].life and game.agents[pid].choose_yes_no(
				game, pid, "Pay %d life to keep %s?" % [toll, revealed.data.card_name],
				hint):
			game.adjust_life(pid, -toll)
			return
		game.discard_cards(pid, [revealed])

	func describe() -> String:
		return "target player reveals a random card and discards it unless they pay life"
