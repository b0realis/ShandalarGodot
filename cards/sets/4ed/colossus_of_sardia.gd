extends CardScript
## Colossus of Sardia — {9} — Artifact Creature — Golem — 9/9 — (4ed, rare)
## Oracle: Trample
##         This creature doesn't untap during your untap step.
##         {9}: Untap this creature. Activate only during your upkeep.
##
## Implementation: printed trample plus a static that keeps
## cur_skips_untap raised on itself, and a nine-mana untap ability
## restricted to its controller's upkeep. Attacking with it costs
## eighteen mana over two turns — which is why it never saw play.


func build() -> CardData:
	return CardData.new("Colossus of Sardia", "{9}",
			Mtg.CardType.ARTIFACT | Mtg.CardType.CREATURE) \
		.pt(9, 9) \
		.with_subtypes(["golem"]) \
		.with_keywords([Mtg.Keyword.TRAMPLE]) \
		.static_ability(StaticAbility.new(
			_apply, "Colossus of Sardia doesn't untap during your untap step.")) \
		.activated(ActivatedAbility.new(
			"{9}", false, [UntapSelfEffect.new()],
			"{9}: Untap Colossus of Sardia. Activate only during your upkeep.") \
			.during_step(Mtg.Step.UPKEEP).your_turn_only()) \
		.oracle("Trample (This creature can deal excess combat damage to the player "
			+ "or planeswalker it's attacking.)\nThis creature doesn't untap during "
			+ "your untap step.\n{9}: Untap this creature. Activate only during your upkeep.")


static func _apply(_game: MtgGame, source: CardInstance) -> void:
	source.cur_skips_untap = true


class UntapSelfEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.untap_permanent(source)

	func describe() -> String:
		return "untaps this creature"
