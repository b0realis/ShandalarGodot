extends CardScript
## Barbed Sliver — {2}{R} — Creature — Sliver (uncommon, tmp).
## Oracle: All Sliver creatures have "{2}: This creature gets +1/+0 until end of turn."
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Barbed Sliver", "{2}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["sliver"])
	c.oracle("All Sliver creatures have \"{2}: This creature gets +1/+0 until end of turn.\"")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
