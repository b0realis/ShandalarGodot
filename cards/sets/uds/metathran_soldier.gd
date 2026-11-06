extends CardScript
## Metathran Soldier — {1}{U} — Creature — Metathran Soldier (common, uds).
## Oracle: This creature can't be blocked.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Metathran Soldier", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["metathran","soldier"])
	c.oracle("This creature can't be blocked.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
