extends CardScript
## Urborg — Legendary Land — (leg, uncommon)
## Oracle: {T}: Add {B}.
##         {T}: Target creature loses first strike or swampwalk until end
##         of turn.
##
## Implementation: the printed "or" is a choice the activating player
## makes, so Urborg ships TWO activated abilities — index 0 strips first
## strike, index 1 strips swampwalk — and the caller picks by index. That
## is exactly the choice the oracle grants, expressed without a modal-
## ability system. mage-go asks its agent for the same two-way choice.
##
## "Loses swampwalk" is that one landwalk and no other
## (LoseAbilityEffect.and_landwalk_of(["swamp"]) — the floating loss
## carries a land-type list next to Hammerheim's all-landwalk flag), so a
## creature with a second landwalk type keeps it.


func build() -> CardData:
	return CardData.new("Urborg", "", Mtg.CardType.LAND) \
		.with_supertypes(Mtg.Supertype.LEGENDARY) \
		.mana(ManaAbility.new(Mtg.ManaColor.B)) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([Mtg.Keyword.FIRST_STRIKE], "first strike")],
			"{T}: Target creature loses first strike until end of turn.")) \
		.activated(ActivatedAbility.new(
			"", true,
			[LoseAbilityEffect.new([], "swampwalk").and_landwalk_of(["swamp"])],
			"{T}: Target creature loses swampwalk until end of turn.")) \
		.oracle("{T}: Add {B}.\n{T}: Target creature loses first strike or swampwalk until end of turn.")
