extends CardScript
## Horned Sliver — {2}{G} — Creature — Sliver (uncommon, tmp).
## Oracle: All Sliver creatures have trample.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Horned Sliver", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures have trample.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
