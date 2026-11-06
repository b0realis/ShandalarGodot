extends CardScript
## Rack and Ruin — {2}{R} — Instant (uncommon, ulg).
## Oracle: Destroy two target artifacts.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rack and Ruin", "{2}{R}", Mtg.CardType.INSTANT)
	c.oracle("Destroy two target artifacts.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
