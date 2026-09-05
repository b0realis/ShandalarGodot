extends CardScript
## Tempest Efreet — {1}{R}{R}{R} — Creature — Efreet — 3/3 — (4ed, rare)
## Oracle: Remove this card from your deck before playing if you're not
##         playing for ante.
##         {T}, Sacrifice this creature: Target opponent may pay 10 life.
##         If that player doesn't, they reveal a card at random from their
##         hand. Exchange ownership of the revealed card and Tempest
##         Efreet. Put the revealed card into your hand and Tempest Efreet
##         from anywhere into that player's graveyard. This change in
##         ownership is permanent.
##
## The ransom is a real QUESTION, put to the victim through their own
## DecisionAgent: a human seat is held open on it (docs/duel-todo.md
## §1.3) and every other seat answers for itself.
##
## Implementation: the Efreet is already in its owner's graveyard when the
## ability resolves (sacrifice is a cost, CR 601.2h), which is exactly where
## the printed card wants it — it only has to change owner. The ransom goes
## through the victim's DecisionAgent; refusing costs them a RANDOM card
## from hand, chosen with game.rng.


func build() -> CardData:
	return CardData.new("Tempest Efreet", "{1}{R}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(3, 3) \
		.with_subtypes(["efreet"]) \
		.activated(ActivatedAbility.new("", true, [EfreetEffect.new()],
			"{T}, Sacrifice this creature: Target opponent may pay 10 life, or lose a random card from their hand to you.") \
			.with_sacrifice_cost()) \
		.oracle("Remove this card from your deck before playing if you're not playing for ante.\n{T}, Sacrifice this creature: Target opponent may pay 10 life. If that player doesn't, they reveal a card at random from their hand. Exchange ownership of the revealed card and Tempest Efreet. Put the revealed card into your hand and Tempest Efreet from anywhere into that player's graveyard. This change in ownership is permanent.")


class EfreetEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var victim := target.player_id
		var hint: bool = game.players[victim].life > 10
		if game.agents[victim].choose_yes_no(game, victim,
				"Pay 10 life to Tempest Efreet?", hint) \
				and game.players[victim].life >= 10:
			game.adjust_life(victim, -10)
			return
		var hand: Array = game.players[victim].hand
		if hand.is_empty():
			return
		var taken: Variant = RandomEffects.pick(game, hand)
		game.log_line("%s reveals %s at random" % [
			game.players[victim].player_name, taken.data.card_name])
		# Exchange ownership: the revealed card becomes ours (and lands in
		# our hand), the Efreet becomes theirs (in their graveyard).
		# change_owner moves the card into the NEW owner's copy of its
		# current zone, so the revealed card lands in our hand by itself.
		game.change_owner(taken, controller)
		game.change_owner(source, victim)

	func describe() -> String:
		return "target opponent pays 10 life or hands you a random card from their hand"
