extends CardScript
## Mongrel Pack — {3}{G} — Creature — Dog (rare, tmp).
## Oracle: When this creature dies during combat, create four 1/1 green Dog creature tokens.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mongrel Pack", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 1)
	c.with_subtypes(["dog"])
	c.oracle("When this creature dies during combat, create four 1/1 green Dog creature tokens.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
