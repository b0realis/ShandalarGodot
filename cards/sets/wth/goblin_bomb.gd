extends CardScript
## Goblin Bomb — {1}{R} — Enchantment (rare, wth).
## Oracle: At the beginning of your upkeep, you may flip a coin. If you win the flip, put a fuse counter on this enchantment. If you lose the flip, remove a fuse counter from this enchantment.
##         Remove five fuse counters from this enchantment and sacrifice it: It deals 20 damage to target player or planeswalker.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Goblin Bomb", "{1}{R}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may flip a coin. If you win the flip, put a fuse counter on this enchantment. If you lose the flip, remove a fuse counter from this enchantment.\nRemove five fuse counters from this enchantment and sacrifice it: It deals 20 damage to target player or planeswalker.")
	return load("res://cards/sets/wth/_rules.gd").apply(c)
