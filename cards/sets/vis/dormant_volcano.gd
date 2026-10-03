extends CardScript
## Dormant Volcano —  — Land (uncommon, vis).
## Oracle: This land enters tapped.
##         When this land enters, sacrifice it unless you return an untapped Mountain you control to its owner's hand.
##         {T}: Add {C}{R}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Dormant Volcano", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\nWhen this land enters, sacrifice it unless you return an untapped Mountain you control to its owner's hand.\n{T}: Add {C}{R}.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
