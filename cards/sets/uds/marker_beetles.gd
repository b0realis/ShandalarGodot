extends CardScript
## Marker Beetles — {1}{G}{G} — Creature — Insect (common, uds).
## Oracle: When this creature dies, target creature gets +1/+1 until end of turn.
##         {2}, Sacrifice this creature: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Marker Beetles", "{1}{G}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["insect"])
	c.oracle("When this creature dies, target creature gets +1/+1 until end of turn.\n{2}, Sacrifice this creature: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
