extends CardScript
## Relic Ward — {1}{W} — Enchantment — Aura (uncommon, vis).
## Oracle: You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.
##         Enchant artifact
##         Enchanted artifact has shroud. (It can't be the target of spells or abilities.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Relic Ward", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.\nEnchant artifact\nEnchanted artifact has shroud. (It can't be the target of spells or abilities.)")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
