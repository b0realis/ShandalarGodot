extends CardScript
## Weatherseed Faeries — {2}{U} — Creature — Faerie (common, ulg).
## Oracle: Flying, protection from red
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Weatherseed Faeries", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["faerie"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.with_protection_from(Mtg.ManaColor.R)
	c.oracle("Flying, protection from red")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
