extends CardScript
## Dust to Dust — {1}{W}{W} — Sorcery — (drk, common)
## Oracle: Exile two target artifacts.
##
## Implementation: ONE artifact-filtered ExileEffect taking exactly two
## targets — "two target" is one instance of the word, so the engine keeps
## them DIFFERENT (CR 601.2c, checked per instance since 2026-10-03, which
## is why this is no longer two one-target slots). Disenchant's bigger,
## regeneration-proof sibling.


func build() -> CardData:
	var exile := ExileEffect.new(TargetSpec.new(TargetSpec.Kind.PERMANENT,
		"target artifact", _is_artifact))
	exile.target_min = 2
	exile.target_max = 2
	return CardData.new("Dust to Dust", "{1}{W}{W}", Mtg.CardType.SORCERY) \
		.spell(exile) \
		.oracle("Exile two target artifacts.")


static func _is_artifact(inst: CardInstance) -> bool:
	return inst.is_type(Mtg.CardType.ARTIFACT)
