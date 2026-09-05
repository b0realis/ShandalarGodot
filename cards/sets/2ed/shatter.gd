extends CardScript
## Shatter — {1}{R} — Instant (2ed, common)
## Oracle: Destroy target artifact.
##
## Implementation: DestroyEffect, artifact-filtered. Red's Disenchant half.


func build() -> CardData:
	var spec := TargetSpec.new(TargetSpec.Kind.PERMANENT, "target artifact", _is_artifact)
	return CardData.new("Shatter", "{1}{R}", Mtg.CardType.INSTANT) \
		.spell(DestroyEffect.new(spec)) \
		.oracle("Destroy target artifact.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
