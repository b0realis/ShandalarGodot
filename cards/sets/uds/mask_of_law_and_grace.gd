extends CardScript
## Mask of Law and Grace — {W} — Enchantment — Aura (common, uds).
## Oracle: Enchant creature
##         Enchanted creature has protection from black and from red.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Mask of Law and Grace", "{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature has protection from black and from red.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
