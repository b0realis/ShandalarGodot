extends CardScript
## Serra's Liturgy — {2}{W}{W} — Enchantment (rare, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {W}, Sacrifice this enchantment: Destroy up to X target artifacts and/or enchantments, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Serra's Liturgy", "{2}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{W}, Sacrifice this enchantment: Destroy up to X target artifacts and/or enchantments, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
