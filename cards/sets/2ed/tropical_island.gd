extends CardScript
## Tropical Island — Land — Forest Island (2ed, rare)
## Oracle: ({T}: Add {G} or {U}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: forestwalk and islandwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Tropical Island", "", Mtg.CardType.LAND) \
		.with_subtypes(["forest", "island"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.oracle("({T}: Add {G} or {U}.)")
