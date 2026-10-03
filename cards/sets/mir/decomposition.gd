extends CardScript
## Decomposition — {1}{G} — Enchantment — Aura (uncommon, mir).
## Oracle: Enchant black creature
##         Enchanted creature has "Cumulative upkeep—Pay 1 life." (At the beginning of its controller's upkeep, that player puts an age counter on it, then sacrifices it unless they pay its upkeep cost for each age counter on it.)
##         When enchanted creature dies, its controller loses 2 life.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Decomposition", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant black creature\nEnchanted creature has \"Cumulative upkeep—Pay 1 life.\" (At the beginning of its controller's upkeep, that player puts an age counter on it, then sacrifices it unless they pay its upkeep cost for each age counter on it.)\nWhen enchanted creature dies, its controller loses 2 life.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
