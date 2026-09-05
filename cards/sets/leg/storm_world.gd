extends CardScript
## Storm World — {R} — World Enchantment — (leg, rare)
## Oracle: At the beginning of each player's upkeep, this enchantment
##         deals X damage to that player, where X is 4 minus the number of
##         cards in their hand.
##
## Implementation: an UPKEEP_START trigger reading the player's hand size
## at RESOLUTION. X is clamped at zero — a player holding five cards
## takes nothing (the printed text never heals). Symmetric, and brutal
## against the empty-handed aggro deck that plays it. A WORLD permanent.


func build() -> CardData:
	return CardData.new("Storm World", "{R}", Mtg.CardType.ENCHANTMENT) \
		.with_supertypes(Mtg.Supertype.WORLD) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _burn,
			"At the beginning of each player's upkeep, Storm World deals X damage to "
			+ "that player, where X is 4 minus the number of cards in their hand.")) \
		.oracle("At the beginning of each player's upkeep, this enchantment deals X "
			+ "damage to that player, where X is 4 minus the number of cards in their hand.")


static func _burn(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var x := 4 - game.players[pid].hand.size()
	if x > 0:
		game.deal_damage(source, TargetRef.player(pid), x)
