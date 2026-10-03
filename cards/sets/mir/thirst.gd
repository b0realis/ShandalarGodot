extends CardScript
## Thirst — {2}{U} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature
##         When this Aura enters, tap enchanted creature.
##         Enchanted creature doesn't untap during its controller's untap step.
##         At the beginning of your upkeep, sacrifice this Aura unless you pay {U}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Thirst", "{2}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, tap enchanted creature.\nEnchanted creature doesn't untap during its controller's untap step.\nAt the beginning of your upkeep, sacrifice this Aura unless you pay {U}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
