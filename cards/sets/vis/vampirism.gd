extends CardScript
## Vampirism — {1}{B} — Enchantment — Aura (uncommon, vis).
## Oracle: Enchant creature
##         When this Aura enters, draw a card at the beginning of the next turn's upkeep.
##         Enchanted creature gets +1/+1 for each other creature you control.
##         Other creatures you control get -1/-1.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Vampirism", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, draw a card at the beginning of the next turn's upkeep.\nEnchanted creature gets +1/+1 for each other creature you control.\nOther creatures you control get -1/-1.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
