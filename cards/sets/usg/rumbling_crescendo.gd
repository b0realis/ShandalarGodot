extends CardScript
## Rumbling Crescendo — {3}{R}{R} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {R}, Sacrifice this enchantment: Destroy up to X target lands, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Rumbling Crescendo", "{3}{R}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{R}, Sacrifice this enchantment: Destroy up to X target lands, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
