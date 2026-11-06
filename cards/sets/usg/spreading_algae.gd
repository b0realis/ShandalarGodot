extends CardScript
## Spreading Algae — {G} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant Swamp
##         When enchanted land becomes tapped, destroy it.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spreading Algae", "{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant Swamp\nWhen enchanted land becomes tapped, destroy it.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
