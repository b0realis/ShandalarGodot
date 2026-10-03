extends CardScript
## Time and Tide — {U}{U} — Instant (uncommon, vis).
## Oracle: Simultaneously, all phased-out creatures phase in and all creatures with phasing phase out.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Time and Tide", "{U}{U}", Mtg.CardType.INSTANT)
	c.oracle("Simultaneously, all phased-out creatures phase in and all creatures with phasing phase out.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
