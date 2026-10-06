extends CardScript
## Plated Rootwalla — {4}{G} — Creature — Lizard (common, exo).
## Oracle: {2}{G}: This creature gets +3/+3 until end of turn. Activate only once each turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Plated Rootwalla", "{4}{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["lizard"])
	c.oracle("{2}{G}: This creature gets +3/+3 until end of turn. Activate only once each turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
