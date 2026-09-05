extends CardScript
## Sandstorm — {G} — Instant — (4ed, common)
## Oracle: Sandstorm deals 1 damage to each attacking creature.
##
## Implementation: card-local "each attacker" sweep — no targets, just
## every declared attacker still on the battlefield when it resolves.
## Green's one-mana answer to a Savannah Lions rush.


func build() -> CardData:
	return CardData.new("Sandstorm", "{G}", Mtg.CardType.INSTANT) \
		.spell(SandstormEffect.new()) \
		.oracle("Sandstorm deals 1 damage to each attacking creature.")


class SandstormEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		for attacker_id in game.combat.attackers.keys():
			var inst := game.find_instance(attacker_id)
			if inst != null and inst.zone == Mtg.Zone.BATTLEFIELD:
				game.deal_damage(source, TargetRef.card(inst), 1)

	func describe() -> String:
		return "deals 1 damage to each attacking creature"
