extends CardScript
## Pyromancy — {2}{R}{R} — Enchantment (rare, ulg).
## Oracle: {3}, Discard a card at random: This enchantment deals damage to any target equal to the mana value of the discarded card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Pyromancy", "{2}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{3}, Discard a card at random: This enchantment deals damage to any target equal to the mana value of the discarded card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
