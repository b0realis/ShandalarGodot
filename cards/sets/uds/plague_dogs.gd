extends CardScript
## Plague Dogs — {4}{B} — Creature — Phyrexian Zombie Dog (uncommon, uds).
## Oracle: When this creature dies, all creatures get -1/-1 until end of turn.
##         {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plague Dogs", "{4}{B}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["phyrexian","zombie","dog"])
	c.oracle("When this creature dies, all creatures get -1/-1 until end of turn.\n{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
