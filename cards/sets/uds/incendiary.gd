extends CardScript
## Incendiary — {R} — Enchantment — Aura (uncommon, uds).
## Oracle: Enchant creature
##         At the beginning of your upkeep, you may put a fuse counter on this Aura.
##         When enchanted creature dies, this Aura deals X damage to any target, where X is the number of fuse counters on this Aura.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Incendiary", "{R}", Mtg.CardType.ENCHANTMENT)
	c.with_subtypes(["aura"])
	c.oracle("Enchant creature\nAt the beginning of your upkeep, you may put a fuse counter on this Aura.\nWhen enchanted creature dies, this Aura deals X damage to any target, where X is the number of fuse counters on this Aura.")
	return load("res://cards/sets/uds/_rules.gd").apply(c)
