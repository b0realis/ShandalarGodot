extends CardScript
## Winged Sliver — {1}{U} — Creature — Sliver (common, tmp).
## Oracle: All Sliver creatures have flying.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Winged Sliver", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures have flying.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
