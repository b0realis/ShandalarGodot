extends CardScript
## Rabid Wolverines — {3}{G}{G} — Creature — Wolverine (common, exo).
## Oracle: Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rabid Wolverines", "{3}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["wolverine"])
	c.oracle("Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
