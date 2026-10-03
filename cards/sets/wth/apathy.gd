extends CardScript
## Apathy — {U} — Enchantment — Aura (common, wth).
## Oracle: Enchant creature
##         Enchanted creature doesn't untap during its controller's untap step.
##         At the beginning of the upkeep of enchanted creature's controller, that player may discard a card at random. If the player does, untap that creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Apathy", "{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature doesn't untap during its controller's untap step.\nAt the beginning of the upkeep of enchanted creature's controller, that player may discard a card at random. If the player does, untap that creature.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
