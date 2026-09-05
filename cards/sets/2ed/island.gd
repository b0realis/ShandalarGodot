extends CardScript
## Island — Basic Land — Island
## Oracle: ({T}: Add {U}.)
##
## Implementation: intrinsic blue mana ability. See plains.gd for notes
## common to all basics.


func build() -> CardData:
	return CardData.new("Island", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.BASIC) \
		.with_subtypes(["island"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.oracle("({T}: Add {U}.)")
