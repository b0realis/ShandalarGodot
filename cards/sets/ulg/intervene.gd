extends CardScript
## Intervene — {U} — Instant (common, ulg).
## Oracle: Counter target spell that targets a creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Intervene", "{U}", Mtg.CardType.INSTANT)
	c.oracle("Counter target spell that targets a creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
