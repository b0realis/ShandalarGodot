extends CardScript
## Serra's Embrace — {2}{W}{W} — Enchantment — Aura (uncommon, usg).
## Oracle: Enchant creature
##         Enchanted creature gets +2/+2 and has flying and vigilance. (Attacking doesn't cause it to tap.)
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra's Embrace", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +2/+2 and has flying and vigilance. (Attacking doesn't cause it to tap.)")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
