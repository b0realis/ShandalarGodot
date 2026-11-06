extends CardScript
## Blanchwood Armor — {2}{G} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +1/+1 for each Forest you control.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Blanchwood Armor", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +1/+1 for each Forest you control.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
