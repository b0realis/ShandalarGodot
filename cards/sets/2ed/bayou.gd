extends CardScript
## Bayou — Land — Swamp Forest (2ed, rare)
## Oracle: ({T}: Add {B} or {G}.)
##
## Implementation: a DUAL land — two ManaAbility options chosen by the
## ability_index argument of MtgGame.tap_for_mana, plus BOTH basic land
## SUBTYPES. The subtypes are rules-relevant: swampwalk and forestwalk see
## this land (CombatState checks land subtypes, not names), and future
## type-based effects will too. Not Basic — the 4-copy deck rule applies.
## One of ten: see the other dual land files.


func build() -> CardData:
	return CardData.new("Bayou", "", Mtg.CardType.LAND) \
		.with_subtypes(["swamp", "forest"]) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.mana(ManaAbility.new(Mtg.ManaColor.G)) \
		.oracle("({T}: Add {B} or {G}.)")
