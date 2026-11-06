extends CardScript
## Carnival of Souls — {1}{B} — Enchantment (rare, uds).
## Oracle: Whenever a creature enters, you lose 1 life and add {B}.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Carnival of Souls", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a creature enters, you lose 1 life and add {B}.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
