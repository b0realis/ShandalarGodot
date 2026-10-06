extends CardScript
## Equilibrium — {1}{U}{U} — Enchantment (rare, exo).
## Oracle: Whenever you cast a creature spell, you may pay {1}. If you do, return target creature to its owner's hand.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Equilibrium", "{1}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever you cast a creature spell, you may pay {1}. If you do, return target creature to its owner's hand.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
