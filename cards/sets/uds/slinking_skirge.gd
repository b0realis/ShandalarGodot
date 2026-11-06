extends CardScript
## Slinking Skirge — {3}{B} — Creature — Phyrexian Imp (common, uds).
## Oracle: Flying
##         {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Slinking Skirge", "{3}{B}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["phyrexian","imp"])
	c.with_keywords([Mtg.Keyword.FLYING])
	c.oracle("Flying\n{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
