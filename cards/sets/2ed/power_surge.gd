extends CardScript
## Power Surge — {R}{R} — Enchantment — (2ed, rare)
## Oracle: At the beginning of each player's upkeep, this enchantment deals
##         X damage to that player, where X is the number of untapped lands
##         they controlled at the beginning of this turn.
##
## Implementation: the untap step records how many untapped lands each
## player has as their turn begins (MtgPlayer.untapped_lands_at_turn_start),
## which is exactly the number the card asks for — counting at upkeep
## instead would let a player tap out in response.


func build() -> CardData:
	return CardData.new("Power Surge", "{R}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.UPKEEP_START, _surge,
			"At the beginning of each player's upkeep, this enchantment deals X damage to that player, where X is the number of untapped lands they controlled at the beginning of this turn.")) \
		.oracle("At the beginning of each player's upkeep, this enchantment deals X damage to that player, where X is the number of untapped lands they controlled at the beginning of this turn.")


static func _surge(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	var pid := int(event.data["player"])
	var lands := game.players[pid].untapped_lands_at_turn_start
	if lands > 0:
		game.deal_damage(source, TargetRef.player(pid), lands)
