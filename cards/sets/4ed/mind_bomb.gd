extends CardScript
## Mind Bomb — {U} — Sorcery — (4ed, uncommon)
## Oracle: Each player may discard up to three cards. Mind Bomb deals
##         damage to each player equal to 3 minus the number of cards they
##         discarded this way.
##
## Implementation: symmetric — the caster pays too. Each player's
## DecisionAgent decides how much of the hand to spend, and whatever is not
## discarded is taken as damage.
##
## HOW MANY each player discards is their own choice, asked through their
## DecisionAgent as a number between 0 and three; the hint is "empty up to
## three at 4 life or less, otherwise take the burn". WHICH cards go is the
## same seat's `choose_discard`.


func build() -> CardData:
	return CardData.new("Mind Bomb", "{U}", Mtg.CardType.SORCERY) \
		.spell(MindBombEffect.new()) \
		.oracle("Each player may discard up to three cards. Mind Bomb deals damage to each player equal to 3 minus the number of cards they discarded this way.")


class MindBombEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for pid in [controller, game.opponent_of(controller)]:
			var p := game.players[pid]
			if p.has_lost:
				continue
			var most: int = mini(3, p.hand.size())
			var hint := most if p.life <= 4 else 0
			var spend := game.agents[pid].choose_number(game, pid, 0, most,
				"Discard how many cards to Mind Bomb?", hint)
			if spend > 0:
				var chosen := game.agents[pid].choose_discard(game, pid, spend)
				game.discard_cards(pid, chosen)
				spend = mini(spend, chosen.size())
			var burn: int = 3 - spend
			if burn > 0:
				game.deal_damage(source, TargetRef.player(pid), burn)

	func describe() -> String:
		return "each player discards up to three cards or takes the difference in damage"
