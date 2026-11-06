extends CardScript
## Fiery Mantle — {1}{R} — Enchantment — Aura (common, usg).
## Oracle: Enchant creature
##         {R}: Enchanted creature gets +1/+0 until end of turn.
##         When this Aura is put into a graveyard from the battlefield, return it to its owner's hand.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Fiery Mantle", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\n{R}: Enchanted creature gets +1/+0 until end of turn.\nWhen this Aura is put into a graveyard from the battlefield, return it to its owner's hand.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
