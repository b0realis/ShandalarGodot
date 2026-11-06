extends CardScript
## Congregate — {3}{W} — Instant (common, usg).
## Oracle: Target player gains 2 life for each creature on the battlefield.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Congregate", "{3}{W}", Mtg.CardType.INSTANT)
	c.oracle("Target player gains 2 life for each creature on the battlefield.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
