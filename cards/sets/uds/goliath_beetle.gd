extends CardScript
## Goliath Beetle — {2}{G} — Creature — Insect (common, uds).
## Oracle: Trample
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goliath Beetle", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 1)
	c.with_subtypes(["insect"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
