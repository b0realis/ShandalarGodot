extends CardScript
## Brilliant Halo — {1}{W} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+2.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Brilliant Halo", "{1}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+2.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
