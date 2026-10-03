extends CardScript
## Teferi's Isle —  — Legendary Land (rare, mir).
## Oracle: Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)
##         Teferi's Isle enters tapped.
##         {T}: Add {U}{U}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Teferi's Isle", "", Mtg.CardType.LAND)
	c.supertypes |= Mtg.Supertype.LEGENDARY
	c.oracle("Phasing (This phases in or out before you untap during each of your untap steps. While it's phased out, it's treated as though it doesn't exist.)\nTeferi's Isle enters tapped.\n{T}: Add {U}{U}.")
	return load("res://cards/sets/mir/_rules.gd").apply(c)
