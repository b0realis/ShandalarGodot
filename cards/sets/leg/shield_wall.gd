extends CardScript
## Shield Wall — {1}{W} — Instant — (leg, uncommon)
## Oracle: Creatures you control get +0/+2 until end of turn.
##
## Implementation: MassPumpEffect scoped with .yours_only(), so control at
## RESOLUTION decides who benefits. (mage-go's Shield Wall boosts every
## permanent on the battlefield — a bug on their side; ours follows the
## printed "creatures you control".)


func build() -> CardData:
	return CardData.new("Shield Wall", "{1}{W}", Mtg.CardType.INSTANT) \
		.spell(MassPumpEffect.new(0, 2, "creatures you control").yours_only()) \
		.oracle("Creatures you control get +0/+2 until end of turn.")
