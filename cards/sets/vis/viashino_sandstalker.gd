extends CardScript
## Viashino Sandstalker — {1}{R}{R} — Creature — Lizard Warrior (uncommon, vis).
## Oracle: Haste (This creature can attack and {T} as soon as it comes under your control.)
##         At the beginning of the end step, return this creature to its owner's hand. (Return it only if it's on the battlefield.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Viashino Sandstalker", "{1}{R}{R}", Mtg.CardType.CREATURE)
	c.pt(4, 2)
	c.with_subtypes(["lizard","warrior"])
	c.with_keywords([Mtg.Keyword.HASTE])
	c.oracle("Haste (This creature can attack and {T} as soon as it comes under your control.)\nAt the beginning of the end step, return this creature to its owner's hand. (Return it only if it's on the battlefield.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
