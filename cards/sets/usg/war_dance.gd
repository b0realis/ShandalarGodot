extends CardScript
## War Dance — {G} — Enchantment (uncommon, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         Sacrifice this enchantment: Target creature gets +X/+X until end of turn, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("War Dance", "{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\nSacrifice this enchantment: Target creature gets +X/+X until end of turn, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
