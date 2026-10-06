extends CardScript
## Convalescence — {1}{W} — Enchantment (rare, exo).
## Oracle: At the beginning of your upkeep, if you have 10 or less life, you gain 1 life.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Convalescence", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if you have 10 or less life, you gain 1 life.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
