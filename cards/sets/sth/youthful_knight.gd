extends CardScript
## Youthful Knight — {1}{W} — Creature — Human Knight (common, sth).
## Oracle: First strike
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Youthful Knight", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["human","knight"])
	c.with_keywords([Mtg.Keyword.FIRST_STRIKE])
	c.oracle("First strike")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
