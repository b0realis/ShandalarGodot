extends CardScript
## Manabarbs — {3}{R} — Enchantment (2ed, rare)
## Oracle: Whenever a player taps a land for mana, Manabarbs deals 1
##         damage to that player.
##
## Implementation: a NORMAL (stacked) trigger on TAPPED_FOR_MANA — unlike
## Mana Flare's off-stack mana trigger, the damage rightly waits its turn
## on the stack. Symmetric pain: every land anyone taps costs a point.
## Manabarbs + Mana Flare on the same table is the era's little joke.


func build() -> CardData:
	return CardData.new("Manabarbs", "{3}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.TAPPED_FOR_MANA, _barb,
			"Whenever a player taps a land for mana, Manabarbs deals 1 damage to that player.")) \
		.oracle("Whenever a player taps a land for mana, Manabarbs deals 1 damage to that player.")


static func _barb(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["controller"]), 1)
