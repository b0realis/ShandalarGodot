extends CardScript
## Sacrifice — {B} — Instant — (2ed, uncommon)
## Oracle: As an additional cost to cast this spell, sacrifice a creature.
##         Add an amount of {B} equal to the sacrificed creature's mana value.
##
## Implementation: the sacrifice is a real additional cost, paid as the
## spell goes on the stack (CR 601.2h) with the eaten creature's mana value
## recorded on the spell's own memory — so the black mana that comes out is
## exactly what the body was worth.
##
## The creature eaten is an ADDITIONAL COST, so the engine's cost hold asks
## for it (CR 601.2h — after every refusal check and before any mutation);
## a human seat answers it through the same overlay as any other question.


static func _any_creature(inst: CardInstance) -> bool:
	return inst.is_creature()


func build() -> CardData:
	return CardData.new("Sacrifice", "{B}", Mtg.CardType.INSTANT) \
		.with_additional_sacrifice("creature", _any_creature) \
		.spell(SacrificeEffect.new()) \
		.oracle("As an additional cost to cast this spell, sacrifice a creature.\nAdd an amount of {B} equal to the sacrificed creature's mana value.")


class SacrificeEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var worth := int(source.memory.get("sacrificed_mv", 0))
		if worth > 0:
			game.players[controller].mana_pool.add(Mtg.ManaColor.B, worth)
			game.log_line("Sacrifice adds %d black mana" % worth)

	func describe() -> String:
		return "adds black mana equal to the sacrificed creature's mana value"
