extends CardScript
## Midsummer Revel — {3}{G}{G} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {G}, Sacrifice this enchantment: Create X 3/3 green Beast creature tokens, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Midsummer Revel", "{3}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{G}, Sacrifice this enchantment: Create X 3/3 green Beast creature tokens, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
