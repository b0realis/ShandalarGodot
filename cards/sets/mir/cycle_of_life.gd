extends CardScript
## Cycle of Life — {1}{G}{G} — Enchantment (rare, mir).
## Oracle: Return this enchantment to its owner's hand: Target creature you cast this turn has base power and toughness 0/1 until your next upkeep. At the beginning of your next upkeep, put a +1/+1 counter on that creature.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Cycle of Life", "{1}{G}{G}", Mtg.CardType.ENCHANTMENT)
	c.oracle("Return this enchantment to its owner's hand: Target creature you cast this turn has base power and toughness 0/1 until your next upkeep. At the beginning of your next upkeep, put a +1/+1 counter on that creature.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
