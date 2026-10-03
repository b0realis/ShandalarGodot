extends CardScript
## Undiscovered Paradise —  — Land (rare, vis).
## Oracle: {T}: Add one mana of any color. During your next untap step, as you untap your permanents, return this land to its owner's hand.
## Trusted optional Pack 8 implementation; ZIPs never provide scripts.

func build() -> CardData:
	var c := CardData.new("Undiscovered Paradise", "", Mtg.CardType.LAND)
	c.oracle("{T}: Add one mana of any color. During your next untap step, as you untap your permanents, return this land to its owner's hand.")
	return load("res://cards/sets/vis/_rules.gd").apply(c)
