extends CardScript
## Eureka — {2}{G}{G} — Sorcery — (leg, rare)
## Oracle: Starting with you, each player may put a permanent card from
##         their hand onto the battlefield. Repeat this process until no one
##         puts a card onto the battlefield.
##
## Implementation: the round-robin is literal — starting with the caster,
## each player in turn is offered ONE permanent card, and the whole circuit
## repeats until a full lap goes by with nothing played. The cards arrive
## through MtgGame.put_from_hand_into_play, so they enter the battlefield
## properly: ETB triggers fire, they are summoning-sick, and an Aura with no
## legal host is swept by the state-based actions.
##
## Symmetric, and the opponent gets the last word — Eureka empties both
## hands, which is exactly why it was banned.
##
## Both halves of each player's turn in the circuit — whether to put a card
## down and WHICH one — are asked of that player's own DecisionAgent, so a
## human seat is held open on each in turn (docs/duel-todo.md §1.3) and
## every other seat answers for itself. The default answer is "yes, the
## biggest one"; the candidates are pre-sorted for it.


func build() -> CardData:
	return CardData.new("Eureka", "{2}{G}{G}", Mtg.CardType.SORCERY) \
		.spell(EurekaEffect.new()) \
		.oracle("Starting with you, each player may put a permanent card from their hand "
			+ "onto the battlefield. Repeat this process until no one puts a card onto the "
			+ "battlefield.")


class EurekaEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var order: Array[int] = [controller, game.opponent_of(controller)]
		var guard := 0
		var anyone_played := true
		while anyone_played and guard < 100 and not game.game_over:
			anyone_played = false
			for pid in order:
				guard += 1
				if _offer(game, pid):
					anyone_played = true

	## One player's turn in the circuit; true when they put a card down.
	static func _offer(game: MtgGame, pid: int) -> bool:
		if game.players[pid].has_lost:
			return false
		var candidates: Array[CardInstance] = []
		for card in game.players[pid].hand:
			if card.data.is_permanent_type():
				candidates.append(card)
		if candidates.is_empty():
			return false
		if not game.agents[pid].choose_yes_no(game, pid,
				"Put a permanent card onto the battlefield with Eureka?", true):
			return false
		candidates.sort_custom(func(a: CardInstance, b: CardInstance) -> bool:
			return a.data.cost.mana_value() > b.data.cost.mana_value())
		var pick := game.agents[pid].choose_card(game, pid, candidates,
			"Choose a permanent card to put onto the battlefield")
		if pick == null or not candidates.has(pick):
			pick = candidates[0]
		game.put_from_hand_into_play(pick, pid)
		return true

	func describe() -> String:
		return "each player empties their hand of permanents onto the battlefield"
