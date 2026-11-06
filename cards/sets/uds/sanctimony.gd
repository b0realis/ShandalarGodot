extends CardScript
## Sanctimony — {1}{W} — Enchantment (uncommon, uds).
## Oracle: Whenever an opponent taps a Mountain for mana, you may gain 1 life.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sanctimony", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever an opponent taps a Mountain for mana, you may gain 1 life.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
