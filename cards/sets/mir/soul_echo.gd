extends CardScript
## Soul Echo — {X}{W}{W} — Enchantment (rare, mir).
## Oracle: This enchantment enters with X echo counters on it.
##         You don't lose the game for having 0 or less life.
##         At the beginning of your upkeep, sacrifice this enchantment if there are no echo counters on it. Otherwise, target opponent may choose that for each 1 damage that would be dealt to you until your next upkeep, you remove an echo counter from this enchantment instead.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Soul Echo", "{X}{W}{W}", Mtg.CardType.ENCHANTMENT)
	c.oracle("This enchantment enters with X echo counters on it.\nYou don't lose the game for having 0 or less life.\nAt the beginning of your upkeep, sacrifice this enchantment if there are no echo counters on it. Otherwise, target opponent may choose that for each 1 damage that would be dealt to you until your next upkeep, you remove an echo counter from this enchantment instead.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
