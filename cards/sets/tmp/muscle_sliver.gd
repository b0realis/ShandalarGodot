extends CardScript
## Muscle Sliver — {1}{G} — Creature — Sliver (common, tmp).
## Oracle: All Sliver creatures get +1/+1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Muscle Sliver", "{1}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures get +1/+1.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
