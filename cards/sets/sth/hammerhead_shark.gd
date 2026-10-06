extends CardScript
## Hammerhead Shark — {1}{U} — Creature — Shark (common, sth).
## Oracle: This creature can't attack unless defending player controls an Island.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Hammerhead Shark", "{1}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 3)
	c.with_subtypes(["shark"])
	c.oracle("This creature can't attack unless defending player controls an Island.")
	return load("res://cards/sets/sth/_rules.gd").apply(c)
