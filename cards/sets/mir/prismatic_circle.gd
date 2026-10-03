extends CardScript
## Prismatic Circle — {2}{W} — Enchantment (common, mir).
## Oracle: Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         As this enchantment enters, choose a color.
##         {1}: The next time a source of your choice of the chosen color would deal damage to you this turn, prevent that damage.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Prismatic Circle", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nAs this enchantment enters, choose a color.\n{1}: The next time a source of your choice of the chosen color would deal damage to you this turn, prevent that damage.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
