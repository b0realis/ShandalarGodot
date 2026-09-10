extends CardScript
## Hammerheim — Legendary Land — (leg, uncommon)
## Oracle: {T}: Add {R}.
##         {T}: Target creature loses all landwalk abilities until end of
##         turn.
##
## Implementation: a red mana ability plus LoseAbilityEffect.and_landwalk()
## — the continuous pipeline clears cur_landwalk for the rest of the turn.
## A printed swampwalk and a grant made EARLIER this turn both go; a grant
## made after it stands, because layer 6 applies in timestamp order
## (CR 613.7).


func build() -> CardData:
	return CardData.new("Hammerheim", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.mana(ManaAbility.new(Mtg.ManaColor.R)) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([], "all landwalk abilities").and_landwalk()],
			"{T}: Target creature loses all landwalk abilities until end of turn.")) \
		.oracle("{T}: Add {R}.\n{T}: Target creature loses all landwalk abilities until end of turn.")
