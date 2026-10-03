extends CardScript
## Serenity — {1}{W} — Enchantment (rare, wth).
## Oracle: At the beginning of your upkeep, destroy all artifacts and enchantments. They can't be regenerated.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serenity", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, destroy all artifacts and enchantments. They can't be regenerated.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
