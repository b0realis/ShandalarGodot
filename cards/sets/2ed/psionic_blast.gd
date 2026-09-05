extends CardScript
## Psionic Blast — {2}{U} — Instant (2ed, uncommon)
## Oracle: Psionic Blast deals 4 damage to any target and 2 damage to you.
##
## Implementation: card-local two-packet effect (see orcish_artillery.gd
## for the pattern) — 4 to the chosen target, 2 recoil to the caster, both
## real blue-source damage. Blue's famous rules-breaking burn spell.


func build() -> CardData:
	return CardData.new("Psionic Blast", "{2}{U}", Mtg.CardType.INSTANT) \
		.spell(BlastEffect.new()) \
		.oracle("Psionic Blast deals 4 damage to any target and 2 damage to you.")


class BlastEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.any_target()

	func resolve(game: MtgGame, source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		game.deal_damage(source, target, 4)
		game.deal_damage(source, TargetRef.player(controller), 2)

	func describe() -> String:
		return "deals 4 damage to any target and 2 damage to you"
