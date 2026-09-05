extends CardScript
## Plains — Basic Land — Plains
## Oracle: ({T}: Add {W}.)
##
## Implementation: intrinsic white mana ability. Basic supertype enables
## the "any number of copies in a deck" rule (deck validation, later) and
## exempts it from ante in the 1997 rules.


func build() -> CardData:
	return CardData.new("Plains", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.BASIC) \
		.with_subtypes(["plains"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.W)) \
		.oracle("({T}: Add {W}.)")
