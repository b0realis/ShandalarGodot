extends CardScript
## Rootwalla — {2}{G} — Creature — Lizard (common, tmp).
## Oracle: {1}{G}: This creature gets +2/+2 until end of turn. Activate only once each turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rootwalla", "{2}{G}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["lizard"])
	c.oracle("{1}{G}: This creature gets +2/+2 until end of turn. Activate only once each turn.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
