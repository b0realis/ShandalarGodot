extends CardScript
## Pendrell Drake — {3}{U} — Creature — Drake (common, usg).
## Oracle: Flying
##         Cycling {2} ({2}, Discard this card: Draw a card.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pendrell Drake", "{3}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nCycling {2} ({2}, Discard this card: Draw a card.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
