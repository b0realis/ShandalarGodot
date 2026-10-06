extends CardScript
## Precognition — {4}{U} — Enchantment (rare, tmp).
## Oracle: At the beginning of your upkeep, you may look at the top card of target opponent's library. If you do, you may put that card on the bottom of that player's library.
## Trusted optional Pack 9 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Precognition", "{4}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("At the beginning of your upkeep, you may look at the top card of target opponent's library. If you do, you may put that card on the bottom of that player's library.")
	return load("res://cards/sets/tmp/_rules.gd").apply(c)
