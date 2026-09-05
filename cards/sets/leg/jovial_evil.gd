extends CardScript
## Jovial Evil — {2}{B} — Sorcery — (leg, rare)
## Oracle: Jovial Evil deals X damage to target opponent, where X is twice
##         the number of white creatures that player controls.
##
## Implementation: card-local effect on a TargetSpec.opponent() — the
## engine refuses to aim it at yourself. The count is taken at RESOLUTION
## (CR 608.2h); colour reads the printed mana cost, the pool-wide
## convention (docs/audit-vs-mage-go.md).


func build() -> CardData:
	return CardData.new("Jovial Evil", "{2}{B}", Mtg.CardType.SORCERY) \
		.spell(JovialEvilEffect.new()) \
		.oracle("Jovial Evil deals X damage to target opponent, where X is twice the "
			+ "number of white creatures that player controls.")


class JovialEvilEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var whites := 0
		for inst in game.all_battlefield():
			if inst.controller_id == target.player_id and inst.is_creature() \
					and (inst.cur_colors & Mtg.ManaColor.W) != 0:
				whites += 1
		if whites > 0:
			game.deal_damage(source, target, whites * 2)

	func describe() -> String:
		return "deals twice their white-creature count to target opponent"
