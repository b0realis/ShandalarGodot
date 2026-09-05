extends CardScript
## Recall — {X}{X}{U} — Sorcery — (leg, rare)
## Oracle: Discard X cards, then return a card from your graveyard to your
##         hand for each card discarded this way. Exile Recall.
##
## Implementation: the doubled {X}{X} really charges twice
## (ManaCost.x_count), the discard comes first (so a card discarded this
## way can itself be recalled), and Recall exiles itself instead of resting
## in the graveyard where it could be recurred.
##
## The choice on resolution is the acting seat's own, asked through their
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself. The value the card
## computes is only the HINT, and the candidates are pre-sorted for it.


func build() -> CardData:
	return CardData.new("Recall", "{X}{X}{U}", Mtg.CardType.SORCERY) \
		.spell(RecallEffect.new()) \
		.oracle("Discard X cards, then return a card from your graveyard to your hand for each card discarded this way. Exile Recall.")


class RecallEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, x_value: int = 0) -> void:
		var spent := 0
		if x_value > 0:
			var chosen := game.agents[controller].choose_discard(game, controller,
				mini(x_value, game.players[controller].hand.size()))
			spent = chosen.size()
			game.discard_cards(controller, chosen)
		for _i in spent:
			var pile: Array[CardInstance] = []
			for card in game.players[controller].graveyard:
				if card != source:
					pile.append(card)
			if pile.is_empty():
				break
			pile.sort_custom(RecallEffect._pricier_first)
			var back := game.agents[controller].choose_card(game, controller, pile,
				"Return a card from your graveyard to your hand")
			if back == null or not pile.has(back):
				back = pile[0]
			game.return_from_graveyard_to_hand(back)
		# "Exile Recall" — it never rests in the graveyard, so it can't be
		# recurred by a later Recall.
		source.exile_after_resolution = true

	static func _pricier_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value()

	func describe() -> String:
		return "discards X cards and recalls that many from your graveyard"
