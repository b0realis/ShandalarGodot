extends CardScript
## Tormented Angel — {3}{W} — Creature — Angel (common, uds).
## Oracle: Flying
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tormented Angel", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 5)
	c.with_subtypes(["angel"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
