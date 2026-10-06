extends CardScript
## Spinal Graft — {1}{B} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         Enchanted creature gets +3/+3.
##         When enchanted creature becomes the target of a spell or ability, destroy that creature. It can't be regenerated.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Spinal Graft", "{1}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +3/+3.\nWhen enchanted creature becomes the target of a spell or ability, destroy that creature. It can't be regenerated.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
