extends CardScript
## Heart Sliver — {1}{R} — Creature — Sliver (common, tmp).
## Oracle: All Sliver creatures have haste.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Heart Sliver", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures have haste.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
