extends CardScript
## Righteous War — {1}{W}{B} — Enchantment (rare, vis).
## Oracle: White creatures you control have protection from black.
##         Black creatures you control have protection from white.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Righteous War", "{1}{W}{B}", Mtg.CardType.ENCHANTMENT)
	c.oracle("White creatures you control have protection from black.\nBlack creatures you control have protection from white.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
