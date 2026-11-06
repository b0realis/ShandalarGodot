extends CardScript
## Rayne, Academy Chancellor — {2}{U} — Legendary Creature — Human Wizard (rare, uds).
## Oracle: Whenever you or a permanent you control becomes the target of a spell or ability an opponent controls, you may draw a card. You may draw an additional card if Rayne is enchanted.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rayne, Academy Chancellor", "{2}{U}", Mtg.CardType.CREATURE)
	c.pt(1, 1)
	c.with_subtypes(["human","wizard"])
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Whenever you or a permanent you control becomes the target of a spell or ability an opponent controls, you may draw a card. You may draw an additional card if Rayne is enchanted.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
