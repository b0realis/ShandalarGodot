extends CardScript
## Talon Sliver — {1}{W} — Creature — Sliver (common, tmp).
## Oracle: All Sliver creatures have first strike.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Talon Sliver", "{1}{W}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures have first strike.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
