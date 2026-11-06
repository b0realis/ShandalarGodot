extends CardScript
## King Crab — {4}{U}{U} — Creature — Crab (uncommon, ulg).
## Oracle: {1}{U}, {T}: Put target green creature on top of its owner's library.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("King Crab", "{4}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(4, 5)
	c.with_subtypes(["crab"])
	c.oracle("{1}{U}, {T}: Put target green creature on top of its owner's library.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
