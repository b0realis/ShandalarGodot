extends CardScript
## Mirror Universe — {6} — Artifact — (leg, rare)
## Oracle: {T}, Sacrifice this artifact: Exchange life totals with target
##         opponent. Activate only during your upkeep.
##
## Implementation: tap-and-sacrifice, restricted to its controller's
## upkeep, swapping the two life totals through MtgGame.adjust_life (so
## every life-change hook still fires). The classic "durdle at 3 life,
## then win" artifact — and the reason Legends decks ran a Fireball.


func build() -> CardData:
	return CardData.new("Mirror Universe", "{6}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"", true, [SwapEffect.new()],
			"{T}, Sacrifice Mirror Universe: Exchange life totals with target "
			+ "opponent. Activate only during your upkeep.") \
			.with_sacrifice_cost() \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("{T}, Sacrifice this artifact: Exchange life totals with target "
			+ "opponent. Activate only during your upkeep.")


class SwapEffect extends EffectBase:
	func _init() -> void:
		target_spec = TargetSpec.opponent()

	func resolve(game: MtgGame, _source: CardInstance, controller: int,
			target: TargetRef, _x_value: int = 0) -> void:
		var mine := game.players[controller].life
		var theirs := game.players[target.player_id].life
		game.adjust_life(controller, theirs - mine)
		game.adjust_life(target.player_id, mine - theirs)

	func describe() -> String:
		return "exchange life totals with target opponent"
