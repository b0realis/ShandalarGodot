extends CardScript
## Venomous Fangs — {2}{G} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Whenever enchanted creature deals damage to a creature, destroy the other creature.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Venomous Fangs", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhenever enchanted creature deals damage to a creature, destroy the other creature.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
