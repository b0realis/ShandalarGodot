extends CardScript
## White Mana Battery — {4} — Artifact — (4ed, rare)
## Oracle: {2}, {T}: Put a charge counter on this artifact.
##         {T}, Remove any number of charge counters from this artifact:
##         Add {W}, then add an additional {W} for each charge counter
##         removed this way.
##
## Implementation: one ordinary activated ability to charge and one MANA
## ability to discharge. The discharge is ManaAbility's "remove ANY
## NUMBER of counters" cost (with_any_number_of_counters): HOW MANY is
## the controller's call, asked by MtgGame.tap_for_mana as the battery is
## tapped (CR 601.2b) with the original's own question — `@MANABATTERY`,
## Program/prompts.txt:566: "How many counters do you wish to spend for
## additional mana? (max: %d)" — through the same hold that asks a human
## which body a sacrifice cost eats, and each counter removed adds one
## more mana. The heuristic spends them all: the battery is discharged
## only when the mana is wanted. Both abilities tap, so the battery either
## charges or fires each turn, never both.


func build() -> CardData:
	return CardData.new("White Mana Battery", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true, [ChargeEffect.new()],
			"{2}, {T}: Put a charge counter on White Mana Battery.")) \
		.mana(ManaAbility.new(Mtg.ManaColor.W).with_any_number_of_counters("charge")) \
		.oracle("{2}, {T}: Put a charge counter on this artifact.\n{T}, Remove any "
			+ "number of charge counters from this artifact: Add {W}, then add an "
			+ "additional {W} for each charge counter removed this way.")


class ChargeEffect extends EffectBase:
	func resolve(game: MtgGame, source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		if source.zone == Mtg.Zone.BATTLEFIELD:
			game.add_counters(source, "charge", 1)

	func describe() -> String:
		return "puts a charge counter on this artifact"
