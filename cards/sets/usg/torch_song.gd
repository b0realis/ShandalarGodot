extends CardScript
## Torch Song — {2}{R} — Enchantment (uncommon, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         {2}{R}, Sacrifice this enchantment: It deals X damage to any target, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Torch Song", "{2}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\n{2}{R}, Sacrifice this enchantment: It deals X damage to any target, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
