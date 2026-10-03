extends CardScript
## Mangara's Equity — {1}{W}{W} — Enchantment (uncommon, mir).
## Oracle: As this enchantment enters, choose black or red.
##         At the beginning of your upkeep, sacrifice this enchantment unless you pay {1}{W}.
##         Whenever a creature of the chosen color deals damage to you or a white creature you control, this enchantment deals that much damage to that creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mangara's Equity", "{1}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("As this enchantment enters, choose black or red.\nAt the beginning of your upkeep, sacrifice this enchantment unless you pay {1}{W}.\nWhenever a creature of the chosen color deals damage to you or a white creature you control, this enchantment deals that much damage to that creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
