extends CardScript
## Treasure Trove — {2}{U}{U} — Enchantment (uncommon, exo).
## Oracle: {2}{U}{U}: Draw a card.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Treasure Trove", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}{U}{U}: Draw a card.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
