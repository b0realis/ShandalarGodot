extends CardScript
## Call from the Grave — {2}{B} — Sorcery — (past, common)
## Oracle: Put a random creature from a random graveyard into play under
##         your control. Call from the Grave deals to you an amount of
##         damage equal to that creature's casting cost.
##
## Implementation: the graveyard is rolled first, then a creature card
## inside it (so an empty graveyard really can waste the spell — that is
## what "random graveyard" means). The reanimated creature arrives under
## the CASTER's control, and the damage is its mana value.


static func _is_creature_card(inst: CardInstance) -> bool:
	return inst.data.is_creature()


func build() -> CardData:
	return CardData.new("Call from the Grave", "{2}{B}", Mtg.CardType.SORCERY) \
		.spell(CallEffect.new(_is_creature_card)) \
		.oracle("Put a random creature from a random graveyard into play under your control. Call from the Grave deals to you an amount of damage equal to that creature's casting cost.")


class CallEffect extends EffectBase:
	var creature_filter: Callable

	func _init(filter: Callable) -> void:
		creature_filter = filter

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var owner := RandomEffects.player(game)
		if owner < 0:
			return
		var raised := RandomEffects.card_in_graveyard(game, owner, creature_filter)
		if raised == null:
			game.log_line("Call from the Grave finds nothing in that graveyard")
			return
		var toll := raised.data.cost.mana_value()
		game.reanimate(raised, controller)
		game.deal_damage(source, TargetRef.player(controller), toll)

	func describe() -> String:
		return "puts a random creature from a random graveyard onto the battlefield under your control"
