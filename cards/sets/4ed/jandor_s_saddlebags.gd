extends CardScript
## Jandor's Saddlebags — {2} — Artifact — (4ed, rare)
## Oracle: {3}, {T}: Untap target creature.
##
## Implementation: activated UntapEffect on a creature target — vigilance
## on retainer, or a second tap-ability activation for someone else's
## Prodigal Sorcerer.


func build() -> CardData:
	return CardData.new("Jandor's Saddlebags", "{2}", Mtg.CardType.ARTIFACT) \
		.activated(ActivatedAbility.new(
			"{3}", true,
			[UntapEffect.new(TargetSpec.creature())],
			"{3}, {T}: Untap target creature.")) \
		.oracle("{3}, {T}: Untap target creature.")
