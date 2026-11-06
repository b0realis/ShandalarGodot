extends CardScript
## Phyrexian Ghoul — {2}{B} — Creature — Phyrexian Zombie (common, usg).
## Oracle: Sacrifice a creature: This creature gets +2/+2 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Phyrexian Ghoul", "{2}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["phyrexian","zombie"])
	c.oracle("Sacrifice a creature: This creature gets +2/+2 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
