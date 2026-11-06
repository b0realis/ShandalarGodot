extends CardScript
## Brink of Madness — {2}{B}{B} — Enchantment (rare, ulg).
## Oracle: At the beginning of your upkeep, if you have no cards in hand, sacrifice this enchantment and target opponent discards their hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brink of Madness", "{2}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if you have no cards in hand, sacrifice this enchantment and target opponent discards their hand.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
