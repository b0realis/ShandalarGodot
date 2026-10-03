extends CardScript
## Ward of Lights — {W}{W} — Enchantment — Aura (common, mir).
## Oracle: You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.
##         Enchant creature
##         As this Aura enters, choose a color.
##         Enchanted creature has protection from the chosen color. This effect doesn't remove this Aura.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ward of Lights", "{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.\nEnchant creature\nAs this Aura enters, choose a color.\nEnchanted creature has protection from the chosen color. This effect doesn't remove this Aura.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
