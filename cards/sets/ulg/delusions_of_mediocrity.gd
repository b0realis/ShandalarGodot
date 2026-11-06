extends CardScript
## Delusions of Mediocrity — {3}{U} — Enchantment (rare, ulg).
## Oracle: When this enchantment enters, you gain 10 life.
##         When this enchantment leaves the battlefield, you lose 10 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Delusions of Mediocrity", "{3}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("When this enchantment enters, you gain 10 life.\nWhen this enchantment leaves the battlefield, you lose 10 life.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
