extends CardScript
## Multani's Presence — {G} — Enchantment (uncommon, ulg).
## Oracle: Whenever a spell you've cast is countered, draw a card.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Multani's Presence", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a spell you've cast is countered, draw a card.")
	return load("res://cards/sets/ulg/_rules.gd").apply(c)
