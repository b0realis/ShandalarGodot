extends CardScript
## Scavenger Folk — {G} — Creature — Human — 1/1 (drk, common)
## Oracle: {G}, {T}, Sacrifice this creature: Destroy target artifact.
##
## Implementation: mana + tap + SACRIFICE cost (the Strip Mine machinery
## on a creature) delivering Disenchant's artifact half. Green's throwaway
## answer to the Disk before it turns.


func build() -> CardData:
	var artifact_spec := TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact",
		func(inst: CardInstance) -> bool: return inst.is_type(Mtg.CardType.ARTIFACT))
	return CardData.new("Scavenger Folk", "{G}", Mtg.CardType.CREATURE) \
		.pt(1, 1) \
		.with_subtypes(["human"]) \
		.activated(ActivatedAbility.new(
			"{G}", true,
			[DestroyEffect.new(artifact_spec)],
			"{G}, {T}, Sacrifice this creature: Destroy target artifact.").with_sacrifice_cost()) \
		.oracle("{G}, {T}, Sacrifice this creature: Destroy target artifact.")
