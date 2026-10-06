extends CardScript
## Dracoplasm — {U}{R} — Creature — Shapeshifter (rare, tmp).
## Oracle: Flying
##         As this creature enters, sacrifice any number of creatures. This creature's power becomes the total power of those creatures and its toughness becomes their total toughness.
##         {R}: This creature gets +1/+0 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dracoplasm", "{U}{R}", Mtg.CardType.CREATURE)
	c.pt(0, 0)
	c.with_subtypes(["shapeshifter"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nAs this creature enters, sacrifice any number of creatures. This creature's power becomes the total power of those creatures and its toughness becomes their total toughness.\n{R}: This creature gets +1/+0 until end of turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
