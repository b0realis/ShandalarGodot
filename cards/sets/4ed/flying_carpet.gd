extends CardScript
## Flying Carpet — {4} — Artifact — (4ed, rare)
## Oracle: {2}, {T}: Target creature gains flying until end of turn.
##
## Implementation: activated keyword grant — a zero-stat PumpEffect
## carrying FLYING until end of turn.


func build() -> CardData:
	var lift := PumpEffect.new(0, 0, [Mtg.Keyword.FLYING])
	return CardData.new("Flying Carpet", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", true,
			[lift],
			"{2}, {T}: Target creature gains flying until end of turn.")) \
		.oracle("{2}, {T}: Target creature gains flying until end of turn.")
