extends CardScript
## Mana Chains — {U} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature has "Cumulative upkeep {1}." (At the beginning of its controller's upkeep, that player puts an age counter on it, then sacrifices it unless they pay its upkeep cost for each age counter on it.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mana Chains", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has \"Cumulative upkeep {1}.\" (At the beginning of its controller's upkeep, that player puts an age counter on it, then sacrifices it unless they pay its upkeep cost for each age counter on it.)")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
