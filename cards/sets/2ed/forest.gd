extends CardScript
## Forest — Basic Land — Forest
## Oracle: ({T}: Add {G}.)
##
## Implementation: intrinsic green mana ability. See plains.gd for notes
## common to all basics.


func build() -> CardData:
	return CardData.new("Forest", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.BASIC) \
		.with_subtypes(["forest"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("({T}: Add {G}.)")
