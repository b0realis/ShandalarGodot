extends CardScript
## Badlands — Land — Swamp Mountain (2ed, rare)
## Oracle: ({T}: Add {B} or {R}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: swampwalk and mountainwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Badlands", "", Mtg.CardType.LAND) \
		.with_subtypes(["swamp", "mountain"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.oracle("({T}: Add {B} or {R}.)")
