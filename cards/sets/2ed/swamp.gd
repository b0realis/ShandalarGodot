extends CardScript
## Swamp — Basic Land — Swamp
## Oracle: ({T}: Add {B}.)
##
## Implementation: intrinsic black mana ability. See plains.gd for notes
## common to all basics.


func build() -> CardData:
	return CardData.new("Swamp", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.BASIC) \
		.with_subtypes(["swamp"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.oracle("({T}: Add {B}.)")
