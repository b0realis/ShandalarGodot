extends CardScript
## Paroxysm — {1}{R} — Enchantment — Aura (uncommon, exo).
## Oracle: Enchant creature
##         At the beginning of the upkeep of enchanted creature's controller, that player reveals the top card of their library. If that card is a land card, destroy that creature. Otherwise, it gets +3/+3 until end of turn.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Paroxysm", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of the upkeep of enchanted creature's controller, that player reveals the top card of their library. If that card is a land card, destroy that creature. Otherwise, it gets +3/+3 until end of turn.")
	return load("res://cards/sets/exo/_rules.gd").apply(c)
