extends CardScript
## Shimmer — {2}{U}{U} — Enchantment (rare, mir).
## Oracle: As this enchantment enters, choose a land type.
##         Each land of the chosen type has phasing. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Shimmer", "{2}{U}{U}", Mtg.CardType.ENCHANTMENT)
	c.oracle("As this enchantment enters, choose a land type.\nEach land of the chosen type has phasing. (It phases in or out before its controller untaps during each of their untap steps. While it's phased out, it's treated as though it doesn't exist.)")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
