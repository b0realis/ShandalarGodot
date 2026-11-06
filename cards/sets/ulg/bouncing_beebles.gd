extends CardScript
## Bouncing Beebles — {2}{U} — Creature — Beeble (common, ulg).
## Oracle: This creature can't be blocked as long as defending player controls an artifact.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bouncing Beebles", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["beeble"])
	c.oracle("This creature can't be blocked as long as defending player controls an artifact.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
