extends CardScript
## Vigilant Drake — {4}{U} — Creature — Drake (common, ulg).
## Oracle: Flying
##         {2}{U}: Untap this creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vigilant Drake", "{4}{U}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["drake"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{2}{U}: Untap this creature.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
