extends CardScript
## Savannah — Land — Forest Plains (2ed, rare)
## Oracle: ({T}: Add {G} or {W}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: forestwalk and plainswalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Savannah", "", Mtg.CardType.LAND) \
		.with_subtypes(["forest", "plains"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.mana(ManaAbility.new(Mtg.ManaColor.W)) \
		.oracle("({T}: Add {G} or {W}.)")
