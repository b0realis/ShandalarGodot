extends CardScript
## Mana Clash — {R} — Sorcery — (4ed, rare)
## Oracle: You and target opponent each flip a coin. Mana Clash deals 1
##         damage to each player whose coin comes up tails. Repeat this
##         process until both players' coins come up heads on the same flip.
##
## Implementation: a card-local loop over MtgGame.flip_coin for both
## players, repeating until BOTH come up heads in the same round. The
## loop is guarded at 100 rounds — with a fair coin the chance of getting
## that far is about 1 in 10^12, and the guard keeps a pathological RNG
## from hanging a headless test.


func build() -> CardData:
	return CardData.new("Mana Clash", "{R}", Mtg.CardType.SORCERY) \
		.spell(ClashEffect.new()) \
		.oracle("You and target opponent each flip a coin. Mana Clash deals 1 damage "
			+ "to each player whose coin comes up tails. Repeat this process until "
			+ "both players' coins come up heads on the same flip.")


class ClashEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var guard := 0
		while guard < 100 and not game.game_over:
			guard += 1
			var mine := game.flip_coin(controller)
			var theirs := game.flip_coin(target.player_id)
			if not mine:
				game.deal_damage(source, TargetRef.player(controller), 1)
			if not theirs:
				game.deal_damage(source, TargetRef.player(target.player_id), 1)
			if mine and theirs:
				return

	func describe() -> String:
		return "both players flip until two heads, taking 1 damage per tails"
