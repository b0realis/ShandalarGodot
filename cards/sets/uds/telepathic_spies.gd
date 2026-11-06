extends CardScript
## Telepathic Spies — {2}{U} — Creature — Human Wizard (common, uds).
## Oracle: When this creature enters, look at target opponent's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Telepathic Spies", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(2, 2)
	c.with_subtypes(["human","wizard"])
	c.oracle("When this creature enters, look at target opponent's hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
