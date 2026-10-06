extends CardScript
## Legacy's Allure — {U}{U} — Enchantment (uncommon, tmp).
## Oracle: At the beginning of your upkeep, you may put a treasure counter on this enchantment.
##         Sacrifice this enchantment: Gain control of target creature with power less than or equal to the number of treasure counters on this enchantment. (This effect lasts indefinitely.)
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Legacy's Allure", "{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a treasure counter on this enchantment.\nSacrifice this enchantment: Gain control of target creature with power less than or equal to the number of treasure counters on this enchantment. (This effect lasts indefinitely.)")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
