extends CardScript
## Rocket Launcher — {4} — Artifact — (atq, uncommon)
## Oracle: {2}: This artifact deals 1 damage to any target. Destroy this
##         artifact at the beginning of the next end step. Activate only
##         if you've controlled this artifact continuously since the
##         beginning of your most recent turn.
##
## Implementation: a repeatable {2} ping whose resolution also condemns
## the Launcher with MtgGame.doom_at_next_end_step — so it fires as many
## times as you can pay for, once, and then dies. The "controlled since
## your most recent turn" clause reuses the engine's summoning-sickness
## flag, which means exactly that.


func build() -> CardData:
	return CardData.new("Rocket Launcher", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[DamageEffect.new(1).any_target(), SelfDoomEffect.new()],
			"{2}: Rocket Launcher deals 1 damage to any target. Destroy it at the "
			+ "beginning of the next end step.") \
			.only_if(_settled_in)) \
		.oracle("{2}: This artifact deals 1 damage to any target. Destroy this "
			+ "artifact at the beginning of the next end step. Activate only if you've "
			+ "controlled this artifact continuously since the beginning of your most "
			+ "recent turn.")


static func _settled_in(_game: MtgGame, source: CardInstance) -> String:
	return "" if not source.summoning_sick \
		else "you haven't controlled it since your most recent turn began"


class SelfDoomEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.doom_at_next_end_step(source)

	func describe() -> String:
		return "destroy this artifact at the beginning of the next end step"
