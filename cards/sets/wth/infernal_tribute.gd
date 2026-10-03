extends CardScript
## Infernal Tribute — {B}{B}{B} — Enchantment (rare, wth).
## Oracle: {2}, Sacrifice a nontoken permanent: Draw a card.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Infernal Tribute", "{B}{B}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{2}, Sacrifice a nontoken permanent: Draw a card.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
