extends CardScript
## Rogue Elephant — {G} — Creature — Elephant (common, wth).
## Oracle: When this creature enters, sacrifice it unless you sacrifice a Forest.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rogue Elephant", "{G}", Mtg.CardType.CREATURE)
	c.pt(3, 3)
	c.with_subtypes(["elephant"])
	c.oracle("When this creature enters, sacrifice it unless you sacrifice a Forest.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
