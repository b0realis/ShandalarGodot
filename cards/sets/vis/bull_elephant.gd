extends CardScript
## Bull Elephant — {3}{G} — Creature — Elephant (common, vis).
## Oracle: When this creature enters, sacrifice it unless you return two Forests you control to their owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Bull Elephant", "{3}{G}", Mtg.CardType.CREATURE)
	c.pt(4, 4)
	c.with_subtypes(["elephant"])
	c.oracle("When this creature enters, sacrifice it unless you return two Forests you control to their owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
