extends CardScript
## Argothian Swine — {3}{G} — Creature — Boar (common, usg).
## Oracle: Trample
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Argothian Swine", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["boar"])
	c.with_keywords([Mtg.Keyword.TRAMPLE])
	c.oracle("Trample")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
