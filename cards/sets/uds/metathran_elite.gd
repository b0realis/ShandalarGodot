extends CardScript
## Metathran Elite — {1}{U}{U} — Creature — Metathran Soldier (uncommon, uds).
## Oracle: This creature can't be blocked as long as it's enchanted.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Metathran Elite", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["metathran","soldier"])
	c.oracle("This creature can't be blocked as long as it's enchanted.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
