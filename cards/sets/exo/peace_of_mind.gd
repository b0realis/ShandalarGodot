extends CardScript
## Peace of Mind — {1}{W} — Enchantment (uncommon, exo).
## Oracle: {W}, Discard a card: You gain 3 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Peace of Mind", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{W}, Discard a card: You gain 3 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
