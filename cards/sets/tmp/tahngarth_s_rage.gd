extends CardScript
## Tahngarth's Rage — {R} — Enchantment — Aura (uncommon, tmp).
## Oracle: Enchant creature
##         Enchanted creature gets +3/+0 as long as it's attacking. Otherwise, it gets -2/-1.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Tahngarth's Rage", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nEnchanted creature gets +3/+0 as long as it's attacking. Otherwise, it gets -2/-1.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
