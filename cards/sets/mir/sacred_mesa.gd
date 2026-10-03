extends CardScript
## Sacred Mesa — {2}{W} — Enchantment (rare, mir).
## Oracle: At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a Pegasus.
##         {1}{W}: Create a 1/1 white Pegasus creature token with flying.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Sacred Mesa", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, sacrifice this enchantment unless you sacrifice a Pegasus.\n{1}{W}: Create a 1/1 white Pegasus creature token with flying.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
