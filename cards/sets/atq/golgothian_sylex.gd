extends CardScript
## Golgothian Sylex — {4} — Artifact — (atq, rare)
## Oracle: {1}, {T}: Each nontoken permanent with a name originally printed
##         in the Antiquities expansion is sacrificed by its controller.
##
## Implementation: "originally printed in Antiquities" is a fact about the
## card NAME, answered by CardRegistry.originally_printed_in() against the
## Scryfall snapshot — NOT by which folder our implementation lives in.
## Thirty-two Antiquities cards (Millstone, Mishra's Factory, Triskelion,
## Strip Mine, The Rack ...) ship in other set folders, and all of them are
## swept. The sweep includes the Sylex itself, as printed.


func build() -> CardData:
	return CardData.new("Golgothian Sylex", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new("{1}", true, [SylexEffect.new()],
			"{1}, {T}: Each nontoken permanent with a name originally printed in the Antiquities expansion is sacrificed by its controller.")) \
		.oracle("{1}, {T}: Each nontoken permanent with a name originally printed in the Antiquities expansion is sacrificed by its controller.")


class SylexEffect extends EffectBase:
	func resolve(game: MtgGame, _source: CardInstance, _controller: int,
			_target: TargetRef, _x_value: int = 0) -> void:
		var doomed: Array[CardInstance] = []
		for inst in game.all_battlefield():
			if not inst.is_token and CardRegistry.originally_printed_in(
					inst.data.card_name, "atq"):
				doomed.append(inst)
		for inst in doomed:
			if inst.zone == Mtg.Zone.BATTLEFIELD:
				game.sacrifice_permanent(inst)

	func describe() -> String:
		return "sacrifices every nontoken Antiquities permanent"
