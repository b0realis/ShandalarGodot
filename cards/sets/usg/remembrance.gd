extends CardScript
## Remembrance — {3}{W} — Enchantment (rare, usg).
## Oracle: Whenever a nontoken creature you control dies, you may search your library for a card with the same name as that creature, reveal it, put it into your hand, then shuffle.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Remembrance", "{3}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Whenever a nontoken creature you control dies, you may search your library for a card with the same name as that creature, reveal it, put it into your hand, then shuffle.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
