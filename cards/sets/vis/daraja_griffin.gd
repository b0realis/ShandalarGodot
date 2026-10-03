extends CardScript
## Daraja Griffin — {3}{W} — Creature — Griffin (uncommon, vis).
## Oracle: Flying
##         Sacrifice this creature: Destroy target black creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Daraja Griffin", "{3}{W}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["griffin"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\nSacrifice this creature: Destroy target black creature.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
