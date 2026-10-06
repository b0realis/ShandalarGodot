extends CardScript
## Monstrous Hound — {3}{R} — Creature — Dog (rare, exo).
## Oracle: This creature can't attack unless you control more lands than defending player.
##         This creature can't block unless you control more lands than attacking player.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Monstrous Hound", "{3}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["dog"])
	c.oracle("This creature can't attack unless you control more lands than defending player.\nThis creature can't block unless you control more lands than attacking player.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
