extends CardScript
## Ovinomancer — {2}{U} — Creature — Human Wizard (uncommon, vis).
## Oracle: When this creature enters, sacrifice it unless you return three basic lands you control to their owner's hand.
##         {T}, Return this creature to its owner's hand: Destroy target creature. It can't be regenerated. That creature's controller creates a 0/1 green Sheep creature token.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ovinomancer", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(0, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, sacrifice it unless you return three basic lands you control to their owner's hand.\n{T}, Return this creature to its owner's hand: Destroy target creature. It can't be regenerated. That creature's controller creates a 0/1 green Sheep creature token.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
