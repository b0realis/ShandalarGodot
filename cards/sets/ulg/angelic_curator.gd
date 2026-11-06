extends CardScript
## Angelic Curator — {1}{W} — Creature — Angel Spirit (common, ulg).
## Oracle: Flying, protection from artifacts
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Angelic Curator", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["angel","spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying, protection from artifacts")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
