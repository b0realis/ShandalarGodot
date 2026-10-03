extends CardScript
## Flooded Shoreline — {U}{U} — Enchantment (rare, vis).
## Oracle: {U}{U}, Return two Islands you control to their owner's hand: Return target creature to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Flooded Shoreline", "{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("{U}{U}, Return two Islands you control to their owner's hand: Return target creature to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
