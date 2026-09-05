extends CardScript
## Underworld Dreams — {B}{B}{B} — Enchantment — (leg, uncommon)
## Oracle: Whenever an opponent draws a card, this enchantment deals 1
##         damage to that player.
##
## Implementation: a CARD_DRAWN trigger gated on the drawer being an
## opponent of the enchantment's controller. It fires once per CARD, so
## a Braingeyser for five is five triggers. Paired with Howling Mine it
## is the pool's cleanest lock.


func build() -> CardData:
	return CardData.new("Underworld Dreams", "{B}{B}{B}", Mtg.CardType.ENCHANTMENT) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.CARD_DRAWN, _bleed,
			"Whenever an opponent draws a card, Underworld Dreams deals 1 damage "
			+ "to that player.",
			_is_opponent)) \
		.oracle("Whenever an opponent draws a card, this enchantment deals 1 damage "
			+ "to that player.")


static func _is_opponent(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return int(event.data["player"]) != source.controller_id


static func _bleed(game: MtgGame, source: CardInstance, event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(int(event.data["player"])), 1)
