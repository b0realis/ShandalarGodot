extends CardScript
## Burst of Energy — {W} — Instant (common, ulg).
## Oracle: Untap target permanent.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Burst of Energy", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Untap target permanent.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
