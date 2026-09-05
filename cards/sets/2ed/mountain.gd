extends CardScript
## Mountain — Basic Land — Mountain
## Oracle: ({T}: Add {R}.)
##
## Implementation: intrinsic red mana ability. See plains.gd for notes
## common to all basics.


func build() -> CardData:
	return CardData.new("Mountain", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.BASIC) \
		.with_subtypes(["mountain"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.oracle("({T}: Add {R}.)")
