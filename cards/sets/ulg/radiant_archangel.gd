extends CardScript
## Radiant, Archangel — {3}{W}{W} — Legendary Creature — Angel (rare, ulg).
## Oracle: Flying, vigilance
##         Radiant gets +1/+1 for each other creature on the battlefield with flying.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Radiant, Archangel", "{3}{W}{W}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["angel"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance\nRadiant gets +1/+1 for each other creature on the battlefield with flying.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
