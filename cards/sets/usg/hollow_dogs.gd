extends CardScript
## Hollow Dogs — {4}{B} — Creature — Phyrexian Zombie Dog (common, usg).
## Oracle: Whenever this creature attacks, it gets +2/+0 until end of turn.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hollow Dogs", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","zombie","dog"])
	c.oracle("Whenever this creature attacks, it gets +2/+0 until end of turn.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
