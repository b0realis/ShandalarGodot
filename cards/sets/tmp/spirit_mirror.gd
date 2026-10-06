extends CardScript
## Spirit Mirror — {2}{W}{W} — Enchantment (rare, tmp).
## Oracle: At the beginning of your upkeep, if there are no Reflection tokens on the battlefield, create a 2/2 white Reflection creature token.
##         {0}: Destroy target Reflection.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spirit Mirror", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, if there are no Reflection tokens on the battlefield, create a 2/2 white Reflection creature token.\n{0}: Destroy target Reflection.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
