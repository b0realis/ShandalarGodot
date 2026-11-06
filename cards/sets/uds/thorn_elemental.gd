extends CardScript
## Thorn Elemental — {5}{G}{G} — Creature — Elemental (rare, uds).
## Oracle: You may have this creature assign its combat damage as though it weren't blocked.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thorn Elemental", "{5}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(7, 7)
	c.with_subtypes(["elemental"])
	c.oracle("You may have this creature assign its combat damage as though it weren't blocked.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
