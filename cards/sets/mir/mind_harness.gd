extends CardScript
## Mind Harness — {U} — Enchantment — Aura (uncommon, mir).
## Oracle: Enchant red or green creature
##         Cumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)
##         You control enchanted creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mind Harness", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant red or green creature\nCumulative upkeep {1} (At the beginning of your upkeep, put an age counter on this permanent, then sacrifice it unless you pay its upkeep cost for each age counter on it.)\nYou control enchanted creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
