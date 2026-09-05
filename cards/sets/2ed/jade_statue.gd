extends CardScript
## Jade Statue — {4} — Artifact — (2ed, uncommon)
## Oracle: {2}: This artifact becomes a 3/6 Golem artifact creature until
##         end of combat. Activate only during combat.
##
## Implementation: AnimateSelfEffect (CREATURE added — it is already an
## artifact) with the until-end-of-combat duration, behind the combat-only
## activation gate. The animation expires the moment the combat phase ends
## (CR 700.5), so in the second main phase the Statue is a plain artifact
## again — safe from Terror, invisible to creature counts.


func build() -> CardData:
	return CardData.new("Jade Statue", "{4}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{2}", false,
			[AnimateSelfEffect.new(Mtg.CardType.CREATURE, 3, 6, ["golem"])
				.until_end_of_combat()],
			"{2}: Becomes a 3/6 Golem artifact creature until end of combat.").combat_only()) \
		.oracle("{2}: This artifact becomes a 3/6 Golem artifact creature until end of combat. Activate only during combat.")
