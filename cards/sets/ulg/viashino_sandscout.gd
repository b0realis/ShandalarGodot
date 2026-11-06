extends CardScript
## Viashino Sandscout — {1}{R} — Creature — Lizard Scout (common, ulg).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)
##         At the beginning of the end step, return this creature to its owner's hand. (Return it only if it's on the battlefield.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Sandscout", "{1}{R}", Mtg.CardType.CREATURE)
	c.pt(2, 1)
	c.with_subtypes(["lizard","scout"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)\nAt the beginning of the end step, return this creature to its owner's hand. (Return it only if it's on the battlefield.)")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
