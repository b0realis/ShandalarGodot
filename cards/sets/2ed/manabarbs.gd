extends CardScript
## Manabarbs — {3}{R} — Enchantment (2ed, rare)
## Oracle: Whenever a player taps a land for mana, Manabarbs deals 1
##         damage to that player.
##
## Implementation: a NORMAL (stacked) trigger on TAPPED_FOR_MANA — unlike
## Mana Flare's off-stack mana trigger, the damage rightly waits its turn
## on the stack. Symmetric pain: every land anyone taps costs a point.
## Manabarbs + Mana Flare on the same table is the era's little joke.
##
## "THAT PLAYER" IS THE HAND THAT TAPPED, so this reads the event's
## `player` key, not `controller` (2026-09-10 — the event carries both;
## Gauntlet of Might and Wild Growth say "its controller" and read the
## other one). The two are the same seat at today's only dispatch site,
## which is why nothing changed here.


func build() -> CardData:
	return CardData.new("Manabarbs", "{3}{R}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.TAPPED_FOR_MANA, _barb,
			"Whenever a player taps a land for mana, Manabarbs deals 1 damage to that player.")) \
		.oracle("Whenever a player taps a land for mana, Manabarbs deals 1 damage to that player.")


static func _barb(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(event.data["player"]), 1)
