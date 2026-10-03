extends CardScript
## Wind Shear — {2}{G} — Instant (uncommon, vis).
## Oracle: Attacking creatures with flying get -2/-2 and lose flying until end of turn.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Wind Shear", "{2}{G}", Mtg.CardType.INSTANT)
	c.oracle("Attacking creatures with flying get -2/-2 and lose flying until end of turn.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
