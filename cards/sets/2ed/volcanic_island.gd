extends CardScript
## Volcanic Island — Land — Island Mountain (2ed, rare)
## Oracle: ({T}: Add {U} or {R}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: islandwalk and mountainwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Volcanic Island", "", Mtg.CardType.LAND) \
		.with_subtypes(["island", "mountain"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.U)) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.oracle("({T}: Add {U} or {R}.)")
