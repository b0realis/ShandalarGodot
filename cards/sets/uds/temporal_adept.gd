extends CardScript
## Temporal Adept — {1}{U}{U} — Creature — Human Wizard (rare, uds).
## Oracle: {U}{U}{U}, {T}: Return target permanent to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Temporal Adept", "{1}{U}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.oracle("{U}{U}{U}, {T}: Return target permanent to its owner's hand.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
