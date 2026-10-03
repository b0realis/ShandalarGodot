extends CardScript
## Karoo —  — Land (uncommon, vis).
## Oracle: This land enters tapped.
##         When this land enters, sacrifice it unless you return an untapped Plains you control to its owner's hand.
##         {T}: Add {C}{W}.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Karoo", "", Mtg.CardType.LAND)
	c.oracle("This land enters tapped.\nWhen this land enters, sacrifice it unless you return an untapped Plains you control to its owner's hand.\n{T}: Add {C}{W}.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
