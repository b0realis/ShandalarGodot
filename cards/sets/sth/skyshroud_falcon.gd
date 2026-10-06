extends CardScript
## Skyshroud Falcon — {1}{W} — Creature — Bird (common, sth).
## Oracle: Flying, vigilance
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Skyshroud Falcon", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["bird"])
	c.with_keywords([Mtg.Keyword.FLYING, Mtg.Keyword.VIGILANCE])
	c.oracle("Flying, vigilance")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
