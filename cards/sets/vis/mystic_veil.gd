extends CardScript
## Mystic Veil — {1}{U} — Enchantment — Aura (common, vis).
## Oracle: You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.
##         Enchant creature
##         Enchanted creature has shroud. (It can't be the target of spells or abilities.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mystic Veil", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.\nEnchant creature\nEnchanted creature has shroud. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
