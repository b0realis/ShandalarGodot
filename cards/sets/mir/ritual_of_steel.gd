extends CardScript
## Ritual of Steel — {2}{W} — Enchantment — Aura (common, mir).
## Oracle: Enchant creature
##         When this Aura enters, draw a card at the beginning of the next turn's upkeep.
##         Enchanted creature gets +0/+2.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Ritual of Steel", "{2}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nWhen this Aura enters, draw a card at the beginning of the next turn's upkeep.\nEnchanted creature gets +0/+2.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
