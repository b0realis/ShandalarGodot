extends CardScript
## Dream Prowler — {2}{U}{U} — Creature — Illusion (common, sth).
## Oracle: This creature can't be blocked as long as it's attacking alone.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dream Prowler", "{2}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 5)
	c.with_subtypes(["illusion"])
	c.oracle("This creature can't be blocked as long as it's attacking alone.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
