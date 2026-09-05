extends CardScript
## Natural Selection — {G} — Instant — (2ed, rare)
## Oracle: Look at the top three cards of target player's library, then put
##         them back in any order. You may have that player shuffle.
##
## Implementation: the caster names the new order card by card, top first
## (DecisionAgent.choose_card over what is left of the three, with the
## original's own line — `@NATURAL_SELECTION`, Program/promptsX1.txt:274:
## "Select card order or DONE to shuffle."), and declining at any point is
## the printed "you may have that player shuffle": the cards go back and
## the library is shuffled (MtgGame.shuffle_library). The order itself is
## put back through MtgGame.reorder_top_of_library, which is journaled, so
## an AI search can unmake it.
##
## The list is offered in the heuristic's order and the heuristic takes
## the first each time: cheapest first on your OWN library (so the next
## draw is castable), priciest first on an opponent's (so their next draw
## is a brick). It never shuffles — the reorder is strictly better.


func build() -> CardData:
	return CardData.new("Natural Selection", "{G}", Mtg.CardType.INSTANT) \
		.spell(NaturalSelectionEffect.new()) \
		.oracle("Look at the top three cards of target player's library, then put them back in any order. You may have that player shuffle.")


class NaturalSelectionEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.player()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var pile: Array[CardInstance] = game.players[target.player_id].library
		if pile.is_empty():
			return
		var left: Array[CardInstance] = []
		for i in mini(3, pile.size()):
			left.append(pile[pile.size() - 1 - i])
		# The first card named ends on top.
		if target.player_id == controller:
			left.sort_custom(NaturalSelectionEffect._cheaper_first)
		else:
			left.sort_custom(NaturalSelectionEffect._pricier_first)
		var ordered: Array[CardInstance] = []
		var shuffle := false
		while not left.is_empty():
			var pick := game.agents[controller].choose_card(game, controller,
				left, "Select card order or DONE to shuffle.", true, false, true)
			if pick == null or not left.has(pick):
				shuffle = true
				break
			left.erase(pick)
			ordered.append(pick)
		var victim := game.players[target.player_id].player_name
		if shuffle:
			game.shuffle_library(target.player_id)
			return
		game.reorder_top_of_library(target.player_id, ordered)
		game.log_line("Natural Selection restacks %s's library" % victim)

	static func _cheaper_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() < b.data.cost.mana_value()

	static func _pricier_first(a: CardInstance, b: CardInstance) -> bool:
		return a.data.cost.mana_value() > b.data.cost.mana_value()

	func describe() -> String:
		return "restacks the top three cards of target player's library"
