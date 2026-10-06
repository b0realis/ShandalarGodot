extends CardScript
## Revenant — {4}{B} — Creature — Spirit (rare, sth).
## Oracle: Flying
##         Revenant's power and toughness are each equal to the number of creature cards in your graveyard.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Revenant", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["spirit"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nRevenant's power and toughness are each equal to the number of creature cards in your graveyard.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
