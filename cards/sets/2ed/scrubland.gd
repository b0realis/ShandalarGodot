extends CardScript
## Scrubland — Land — Plains Swamp (2ed, rare)
## Oracle: ({T}: Add {W} or {B}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: plainswalk and swampwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Scrubland", "", Mtg.CardType.LAND) \
		.with_subtypes(["plains", "swamp"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.W)) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.oracle("({T}: Add {W} or {B}.)")
