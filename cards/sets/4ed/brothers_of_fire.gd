extends CardScript
## Brothers of Fire — {1}{R}{R} — Creature — Human Shaman — 2/2 — (4ed, common)
## Oracle: {1}{R}{R}: This creature deals 1 damage to any target and 1
##         damage to you.
##
## Implementation: two effects in one ability — a targeted DamageEffect
## and a card-local self-burn. Both halves happen on resolution, so the
## drawback is unavoidable: three mana for one damage each way, repeatable
## as long as you can afford your own life total.


func build() -> CardData:
	return CardData.new("Brothers of Fire", "{1}{R}{R}", Mtg.CardType.CREATURE) \
		.pt(2, 2) \
		.with_subtypes(["human", "shaman"]) \
		.activated(ActivatedAbility.new(
			"{1}{R}{R}", false,
			[DamageEffect.new(1).any_target(), BackfireEffect.new()],
			"{1}{R}{R}: Brothers of Fire deals 1 damage to any target and 1 damage to you.")) \
		.oracle("{1}{R}{R}: This creature deals 1 damage to any target and 1 damage to you.")


class BackfireEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		game.deal_damage(source, TargetRef.player(controller), 1)

	func describe() -> String:
		return "deals 1 damage to you"
