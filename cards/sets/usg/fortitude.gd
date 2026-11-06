extends CardScript
## Fortitude — {1}{G} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Sacrifice a Forest: Regenerate enchanted creature.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fortitude", "{1}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nSacrifice a Forest: Regenerate enchanted creature.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
