extends CardScript
## Electric Eel — {U} — Creature — Fish — 1/1 — (drk, uncommon)
## Oracle: When this creature enters, it deals 1 damage to you.
##         {R}{R}: This creature gets +2/+0 until end of turn and deals 1
##         damage to you.
##
## Implementation: an ENTERS_BATTLEFIELD trigger for the arrival sting
## plus an activated ability pairing a self PumpEffect with a card-local
## self-burn. A one-mana 3/1 attacker if you have the red mana and the
## life to spare.


func build() -> CardData:
	return CardData.new("Electric Eel", "{U}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["fish"]) \
		.triggered(TriggeredAbility.new(
			Mtg.EventType.ENTERS_BATTLEFIELD, _arrival,
			"When Electric Eel enters, it deals 1 damage to you.",
			_is_self)) \
		.activated(ActivatedAbility.new(
			"{R}{R}", false,
			[PumpEffect.new(2, 0).self_buff(), ShockEffect.new()],
			"{R}{R}: Electric Eel gets +2/+0 until end of turn and deals 1 damage to you.")) \
		.oracle("When this creature enters, it deals 1 damage to you.\n{R}{R}: This "
			+ "creature gets +2/+0 until end of turn and deals 1 damage to you.")


static func _is_self(_game: MtgGame, source: CardInstance, event: GameEvent) -> bool:
	return event.data.get("instance") == source


static func _arrival(game: MtgGame, source: CardInstance, _event: GameEvent) -> void:
	game.deal_damage(source, TargetRef.player(source.controller_id), 1)


class ShockEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.deal_damage(source, TargetRef.player(controller), 1)

	func describe() -> String:
		return "deals 1 damage to you"
