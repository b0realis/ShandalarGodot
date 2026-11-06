extends CardScript
## Cave Tiger — {2}{G} — Creature — Cat (common, usg).
## Oracle: Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cave Tiger", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["cat"])
	c.oracle("Whenever this creature becomes blocked by a creature, this creature gets +1/+1 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
