extends CardScript
## Taiga — Land — Mountain Forest (2ed, rare)
## Oracle: ({T}: Add {R} or {G}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: mountainwalk and forestwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Taiga", "", Mtg.CardType.LAND) \
		.with_subtypes(["mountain", "forest"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("({T}: Add {R} or {G}.)")
