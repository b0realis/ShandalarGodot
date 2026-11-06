extends CardScript
## Yawgmoth's Bargain — {4}{B}{B} — Enchantment (rare, uds).
## Oracle: Skip your draw step.
##         Pay 1 life: Draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Yawgmoth's Bargain", "{4}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Skip your draw step.\nPay 1 life: Draw a card.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
