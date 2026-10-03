extends CardScript
## Parapet — {1}{W} — Enchantment (common, vis).
## Oracle: You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.
##         Creatures you control get +0/+1.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Parapet", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("You may cast this spell as though it had flash. If you cast it any time a sorcery couldn't have been cast, the controller of the permanent it becomes sacrifices it at the beginning of the next cleanup step.\nCreatures you control get +0/+1.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
