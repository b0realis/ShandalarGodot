extends CardScript
## Dust to Dust — {1}{W}{W} — Sorcery — (drk, common)
## Oracle: Exile two target artifacts.
##
## Implementation: two artifact-filtered ExileEffect slots (the engine
## enforces two DIFFERENT targets, CR 601.2c) — Disenchant's bigger,
## regeneration-proof sibling.


func build() -> CardData:
	return CardData.new("Dust to Dust", "{1}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact", _is_artifact))) \
		.spell(ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
			"target artifact", _is_artifact))) \
		.oracle("Exile two target artifacts.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
