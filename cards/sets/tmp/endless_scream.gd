extends CardScript
## Endless Scream — {X}{B} — Enchantment — Aura (common, tmp).
## Oracle: Enchant creature
##         This Aura enters with X scream counters on it.
##         Enchanted creature gets +1/+0 for each scream counter on this Aura.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Endless Scream", "{X}{B}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nThis Aura enters with X scream counters on it.\nEnchanted creature gets +1/+0 for each scream counter on this Aura.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
