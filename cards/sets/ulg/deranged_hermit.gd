extends CardScript
## Deranged Hermit — {3}{G}{G} — Creature — Elf (rare, ulg).
## Oracle: Echo {3}{G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)
##         When this creature enters, create four 1/1 green Squirrel creature tokens.
##         Squirrel creatures get +1/+1.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Deranged Hermit", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["elf"])
	c.oracle("Echo {3}{G}{G} (At the beginning of your upkeep, if this came under your control since the beginning of your last upkeep, sacrifice it unless you pay its echo cost.)\nWhen this creature enters, create four 1/1 green Squirrel creature tokens.\nSquirrel creatures get +1/+1.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
