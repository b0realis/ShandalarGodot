extends CardScript
## Momentum — {2}{G} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         At the beginning of your upkeep, you may put a growth counter on this Aura.
##         Enchanted creature gets +1/+1 for each growth counter on this Aura.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Momentum", "{2}{G}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of your upkeep, you may put a growth counter on this Aura.\nEnchanted creature gets +1/+1 for each growth counter on this Aura.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
