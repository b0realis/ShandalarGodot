extends CardScript
## Lilting Refrain — {1}{U} — Enchantment (uncommon, usg).
## Oracle: At the beginning of your upkeep, you may put a verse counter on this enchantment.
##         Sacrifice this enchantment: Counter target spell unless its controller pays {X}, where X is the number of verse counters on this enchantment.
## Trusted optional Pack 10 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Lilting Refrain", "{1}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may put a verse counter on this enchantment.\nSacrifice this enchantment: Counter target spell unless its controller pays {X}, where X is the number of verse counters on this enchantment.")
	return load("res://cards/sets/usg/_rules.gd").apply(c)
