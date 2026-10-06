extends CardScript
## Smite — {W} — Instant (common, sth).
## Oracle: Destroy target blocked creature.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Smite", "{W}", Mtg.CardType.INSTANT)
	c.oracle("Destroy target blocked creature.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
